import Cocoa
import ImageIO
import XCTest
@testable import EliminateTeris1

/// 验证新视觉反馈不会改变真实规则，预览全部使用隔离存档。
final class GameLobbyPresentationTests: AchievementTestCase {
    private func image(_ view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        let pixels = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: pixels)
        return pixels
    }
    private func export(_ view: NSView, name: String) throws {
        try export(image(view), name: name)
    }
    private func export(_ bitmap: NSBitmapImageRep, name: String) throws {
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-\(name).png"))
    }

    func testFeedbackReversalRefreshAndReducedMotionPreserveVisibleState() {
        var clock: TimeInterval = 100
        let effect = GameControlFeedback()
        effect.now = { clock }; effect.reducesMotion = { false }
        // 离屏初次展示直接到位；挂到窗口后再悬停不能使选中高光倒退。
        effect.update(hover: false, press: false, selected: true, animated: false)
        clock += 0.01
        effect.update(hover: true, press: false, selected: true, animated: true)
        XCTAssertEqual(effect.values.selection, 1)
        clock += GameControlFeedback.duration / 2
        effect.advance(at: clock)
        XCTAssertEqual(effect.values.hover, 0.5, accuracy: 0.001)
        effect.update(hover: true, press: false, selected: true, animated: true)
        clock += GameControlFeedback.duration / 2
        effect.advance(at: clock)
        XCTAssertEqual(effect.values.hover, 1, accuracy: 0.001, "重复刷新不能重新计时")
        effect.update(hover: false, press: false, selected: false, animated: true)
        clock += GameControlFeedback.duration / 2; effect.advance(at: clock)
        let halfway = effect.values
        effect.update(hover: true, press: true, selected: true, animated: true)
        XCTAssertEqual(effect.values, halfway, "快速反向从当前画面接续")
        effect.reducesMotion = { true }
        effect.advance(at: clock)
        XCTAssertEqual(effect.values, .init(hover: 1, press: 1, selection: 1))
    }

    func testChallengeBudgetUsesSnapshotAndClampsAtTheRuleBoundary() {
        let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: 500, height: 128))
        hud.refresh(snapshot: GameSnapshot(mode: .timed(duration: 60), elapsedTime: 0.1, remainingTime: 59.9,
                                          remainingSwaps: nil, isRunning: true, isFinished: false), mode: .timed)
        XCTAssertEqual(hud.budgetText, "01:00", "不提前跳过第一秒")
        XCTAssertEqual(hud.remainingFraction, CGFloat(59.9 / 60), accuracy: 0.001)
        hud.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 600, remainingTime: nil,
                                          remainingSwaps: 18, isRunning: true, isFinished: false), mode: .moves)
        XCTAssertEqual(hud.budgetText, "18")
        XCTAssertEqual(hud.remainingFraction, 0.6, accuracy: 0.001)
        hud.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 600, remainingTime: nil,
                                          remainingSwaps: 0, isRunning: false, isFinished: true), mode: .moves)
        XCTAssertEqual(hud.remainingFraction, 0)
        XCTAssertEqual(hud.budgetText, "0")
    }

    func testStatisticsPlateSlantsHaveEqualVisibleSpacing() throws {
        _ = NSApplication.shared
        for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196), NSSize(width: 1_360, height: 148)] {
            let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size))
            hud.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
                                              remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free)
            let bitmap = try image(hud)
            let scale = CGFloat(bitmap.pixelsWide) / size.width
            let surface = hud.surfaceRect
            let join = surface.minY + surface.height * 52 / 186

            func rimCenters(at y: CGFloat) -> [CGFloat] {
                let row = Int(y * scale)
                let bright = (0..<bitmap.pixelsWide).filter { x in
                    guard let color = bitmap.colorAt(x: x, y: row)?.usingColorSpace(.sRGB) else { return false }
                    return color.alphaComponent > 0.4 && color.redComponent > 0.26
                }
                var spans: [ClosedRange<Int>] = []
                for x in bright {
                    if let previous = spans.last, x == previous.upperBound + 1 {
                        spans[spans.count - 1] = previous.lowerBound...x
                    } else {
                        spans.append(x...x)
                    }
                }
                return spans.map { CGFloat($0.lowerBound + $0.upperBound) / (2 * scale) }
            }

            // 背板右线会在交界处被盖住，将交界上方的两根背板斜线投到同一测量高度。
            let rear = rimCenters(at: join - 4)
            let front = rimCenters(at: join + 4)
            XCTAssertEqual(rear.count, 2, "\(size)：交界上方应显示背板的两根斜边")
            XCTAssertEqual(front.count, 3, "\(size)：交界下方应显示背板左边和两根前板斜边")
            guard rear.count == 2, front.count == 3 else { continue }
            let shift = HomeDashboardStyle.edgeOffset(for: 8)
            let leftGap = front[1] - rear[0] + shift
            let rightGap = front[2] - rear[1] + shift
            XCTAssertGreaterThan(leftGap, 0)
            XCTAssertEqual(rightGap, leftGap, accuracy: 1.5, "\(size)：左右可见错位要等宽")
        }
    }

    func testStatisticsBackingRimContinuesDownRightSideAndFadesTowardLeft() throws {
        _ = NSApplication.shared
        let frame = NSRect(x: 0, y: 0, width: 336, height: 62)
        let hud = HomeChallengeHUDView(frame: frame)
        hud.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
                                          remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free)
        // 矮画布让错开后的背板底边高于前板，便于检查正常高度下会被盖住的描边。
        hud.positionPlates(in: frame, assembling: true)
        hud.plateAssembly = .init(backing: 0, front: 0, opacity: 1, highlight: 0)
        let bitmap = try image(hud)
        let bounds = hud.bounds
        let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
        let rest = hud.surfaceRect
        let frontTop = rest.minY + rest.height * 52 / 186
        let frontBottom = try XCTUnwrap(hud.breakdownCellRects.last).maxY
        let backing = NSRect(x: rest.minX + hud.backingPlateOffset.x, y: rest.minY + hud.backingPlateOffset.y,
                             width: rest.width, height: frontBottom - frontTop)
        XCTAssertLessThan(backing.maxY + 2, frontTop + hud.frontPlateOffset.y)

        func alpha(x: CGFloat, y: CGFloat) throws -> CGFloat {
            let pixelX = Int(floor((x - bounds.minX) * scaleX))
            let pixelY = Int(floor((y - bounds.minY) * scaleY))
            return try XCTUnwrap(bitmap.colorAt(x: pixelX, y: pixelY)).alphaComponent
        }

        let rightTopX = backing.minX + backing.width * 606 / 636
        for fraction: CGFloat in [0.55, 0.72, 0.88] {
            let y = backing.minY + backing.height * fraction
            let rightX = rightTopX - HomeDashboardStyle.edgeOffset(for: y - backing.minY)
            let peak = try [-1, 0, 1].map { try alpha(x: rightX + CGFloat($0), y: y) }.max() ?? 0
            let nearby = try max(alpha(x: rightX - 3, y: y), alpha(x: rightX + 3, y: y))
            XCTAssertGreaterThan(peak, nearby + 0.10, "背板右斜边延伸至下段，采样高度 \(fraction)")
        }

        let cut = HomeDashboardStyle.edgeOffset(for: backing.height)
        let leftBottomX = backing.minX + backing.width * 45 / 636 - cut
        let rightBottomX = rightTopX - cut
        func bottomX(at fraction: CGFloat) -> CGFloat { leftBottomX + (rightBottomX - leftBottomX) * fraction }
        func bottomAlpha(at fraction: CGFloat) throws -> CGFloat {
            let x = bottomX(at: fraction)
            return try [-1, 0, 1].map { try alpha(x: x, y: backing.maxY + CGFloat($0)) }.max() ?? 0
        }

        let faintLeft = try bottomAlpha(at: 0.05)
        let fade = try bottomAlpha(at: 0.25)
        let solid = try bottomAlpha(at: 0.68)
        XCTAssertLessThan(faintLeft, 0.15, "底边靠近左下角时接近透明")
        XCTAssertGreaterThan(fade, faintLeft + 0.07, "底边左段亮度沿宽度渐变")
        XCTAssertGreaterThan(solid, fade + 0.07, "底边右段保持清晰")
        XCTAssertLessThan(try alpha(x: bottomX(at: 0.68), y: backing.maxY + 2), 0.03,
                          "背板在与前板等高的描边下方保持透明")
    }

    func testChallengeBudgetTrackReplacesOnlyTheTopBandContent() throws {
        _ = NSApplication.shared
        for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196)] {
            let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size))
            func render(_ mode: HomeGameMode, remaining: Double) throws -> NSBitmapImageRep {
                hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode,
                    elapsedTime: (1 - remaining) * HomeGameMode.timedDuration,
                    remainingTime: mode == .timed ? remaining * HomeGameMode.timedDuration : nil,
                    remainingSwaps: mode == .moves ? Int(remaining * Double(HomeGameMode.moveLimit)) : nil,
                    isRunning: remaining > 0 && remaining < 1, isFinished: remaining == 0,
                    clearedByKind: [.orangeRicky: 21]), mode: mode)
                return try image(hud)
            }

            let free = try render(.free, remaining: 1)
            XCTAssertNil(hud.budgetTrackRect)
            let surface = hud.surfaceRect
            let scale = CGFloat(free.pixelsWide) / size.width
            func pixels(from start: CGFloat, to end: CGFloat) -> Range<Int> {
                Int(ceil(start * scale))..<Int(floor(end * scale))
            }
            func cyanColumns(in bitmap: NSBitmapImageRep, y: Int, x: Range<Int>) -> [Int] {
                x.filter { column in
                    guard let color = bitmap.colorAt(x: column, y: y)?.usingColorSpace(.sRGB),
                          color.alphaComponent > 0.8 else { return false }
                    return min(color.greenComponent, color.blueComponent) - color.redComponent > 0.45
                }
            }
            let headerBottom = surface.minY + surface.height * 52 / 186
            let headerRows = pixels(from: surface.minY, to: headerBottom)
            let headerColumns = pixels(from: 0, to: size.width)
            XCTAssertFalse(headerRows.contains { !cyanColumns(in: free, y: $0, x: headerColumns).isEmpty },
                           "自由模式的背板顶部不应残留青色标记或文字")

            var timedTrack: NSRect?
            for mode in [HomeGameMode.timed, .moves] {
                let full = try render(mode, remaining: 1)
                let track = try XCTUnwrap(hud.budgetTrackRect)
                if mode == .timed { timedTrack = track } else { XCTAssertEqual(track, timedTrack) }
                XCTAssertGreaterThan(track.minY, surface.minY)
                XCTAssertLessThan(track.maxY, headerBottom)
                XCTAssertEqual(track.midY, (surface.minY + headerBottom) / 2, accuracy: 0.1)
                XCTAssertEqual(track.minX, surface.minX + surface.width * 72 / 636, accuracy: 0.1)
                // 在轨道同一高度量两侧水平留白，斜边保持平行时整条轨道都等距。
                let plateOffset = HomeDashboardStyle.edgeOffset(for: track.midY - surface.minY)
                let trackOffset = HomeDashboardStyle.edgeOffset(for: track.height) / 2
                let left = surface.minX + surface.width * 45 / 636 - plateOffset
                let right = surface.minX + surface.width * 606 / 636 - plateOffset
                let leftGap = track.minX + trackOffset - left
                let rightGap = right - (track.maxX - trackOffset)
                XCTAssertGreaterThan(leftGap, 0)
                XCTAssertEqual(leftGap, rightGap, accuracy: 0.1)

                let row = Int(track.midY * scale)
                let columns = pixels(from: track.minX, to: track.maxX)
                let fullInk = cyanColumns(in: full, y: row, x: columns)
                XCTAssertGreaterThan(fullInk.count, columns.count / 2)
                func segmentCount(_ ink: [Int]) -> Int {
                    guard !ink.isEmpty else { return 0 }
                    return 1 + zip(ink, ink.dropFirst()).filter { left, right in right > left + 1 }.count
                }
                XCTAssertEqual(segmentCount(fullInk), mode == .moves ? 30 : 1)

                let partial = try render(mode, remaining: 0.5)
                let partialInk = cyanColumns(in: partial, y: row, x: columns)
                XCTAssertEqual(Double(partialInk.count) / Double(fullInk.count), 0.5, accuracy: 0.05)
                XCTAssertEqual(segmentCount(partialInk), mode == .moves ? 15 : 1)
                XCTAssertEqual(partialInk.first, fullInk.first)
                let empty = try render(mode, remaining: 0)
                XCTAssertEqual(hud.budgetTrackRect, track, "预算用尽后仍显示空轨道")
                XCTAssertTrue(cyanColumns(in: empty, y: row, x: columns).isEmpty)
                let first = try XCTUnwrap(fullInk.first)
                XCTAssertNotEqual(empty.colorAt(x: first, y: row), free.colorAt(x: first, y: row),
                                  "挑战归零后仍应绘制暗色轨道底板")

                let totalsRows = pixels(from: headerBottom, to: surface.minY + surface.height * 132 / 186)
                let totalsColumns = pixels(from: surface.minX + surface.width * 0.50,
                                           to: surface.minX + surface.width * 0.85)
                XCTAssertFalse(totalsRows.contains { !cyanColumns(in: full, y: $0, x: totalsColumns).isEmpty },
                               "统计区下方不得重复绘制进度轨道")
            }
        }
    }

    func testPieceCountsUseEqualCellsAndGapsAcrossStatWidths() throws {
        _ = NSApplication.shared
        let longCount = 123_456
        let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
        for mode in HomeGameMode.allCases {
            for width: CGFloat in [336, 534, 1_360] {
                let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: width, height: 148))
                hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode, elapsedTime: 60,
                                                   remainingTime: mode == .timed ? 0 : nil,
                                                   remainingSwaps: mode == .moves ? 0 : nil,
                                                   isRunning: false, isFinished: true, clearedByKind: counts), mode: mode)
                let bitmap = try image(hud)
                let scale = CGFloat(bitmap.pixelsWide) / width
                let cells = hud.breakdownCellRects
                XCTAssertEqual(cells.count, PieceKind.allCases.count)
                let first = try XCTUnwrap(cells.first)
                let cut = HomeDashboardStyle.edgeOffset(for: first.height)
                let flatWidth = first.width - cut
                let gaps = zip(cells, cells.dropFirst()).map { previous, next in
                    next.minX + cut - previous.maxX
                }
                let firstGap = try XCTUnwrap(gaps.first)
                XCTAssertGreaterThan(firstGap, 0)
                for cell in cells {
                    XCTAssertEqual(cell.minY, first.minY)
                    XCTAssertEqual(cell.width, first.width, "四类统计必须使用相同宽度")
                    XCTAssertEqual(cell.height, first.height)
                    XCTAssertTrue(hud.bounds.contains(cell))
                }
                for gap in gaps {
                    XCTAssertEqual(gap, firstGap, accuracy: 0.001, "四张卡之间的斜缝必须等宽")
                }

                let rowPixels = stride(from: Int(ceil(first.minY * scale)), to: Int(first.maxY * scale), by: 2)
                var iconStarts: [CGFloat] = []
                var previousColoredX = -CGFloat.infinity
                // 只在底部方块行检测彩色像素，避免把青色模式标题误当成方块。
                for x in 0..<bitmap.pixelsWide {
                    let containsArtwork = rowPixels.contains { y in
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                              color.alphaComponent > 0.9 else { return false }
                        let high = max(color.redComponent, color.greenComponent, color.blueComponent)
                        let low = min(color.redComponent, color.greenComponent, color.blueComponent)
                        return high - low > 0.4
                    }
                    guard containsArtwork else { continue }
                    let position = CGFloat(x) / scale
                    if position - previousColoredX > 3 { iconStarts.append(position) }
                    previousColoredX = position
                }
                // 从彩色像素验证实际绘制也遵循每个等宽格的左侧留白。
                let iconInset = cut / 2 + min(24, flatWidth * 0.18)
                XCTAssertEqual(iconStarts.count, cells.count, "\(mode.key) / \(width)")
                for (start, cell) in zip(iconStarts, cells) {
                    XCTAssertEqual(start, cell.minX + iconInset, accuracy: 3,
                                   "\(mode.key) / \(width)：方块应按分格对齐")
                }
                XCTAssertTrue(hud.toolTip?.contains("\(longCount)") == true, "长数字的完整值可通过提示查看")
                if mode == .moves, width == 534 { try export(hud, name: "hud-compact-long-counts") }
            }
        }
    }

    func testLobbyStatesAndFiveLanguagesExportRealViewsWithoutChangingAchievements() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            for mode in HomeGameMode.allCases {
                for running in [false, true] {
                    let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: running ? 42 : 0,
                        remainingTime: mode == .timed ? (running ? 18 : 60) : nil,
                        remainingSwaps: mode == .moves ? (running ? 12 : 30) : nil,
                        isRunning: running, isFinished: false,
                        clearedByKind: running ? [.orangeRicky: 15, .blueRicky: 9, .clevelandZ: 6, .rhodeIslandZ: 12] : [:])
                    for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1920, height: 1080)] {
                        home.setFrameSize(size); home.refresh(snapshot: snapshot, mode: mode, manager: manager)
                        _ = try image(home)
                        XCTAssertFalse(home.challengeHUD.isHidden)
                        let intro = try modeIntro(in: home.modeHeader)
                        let labels = intro.subviews.compactMap { $0 as? NSTextField }.sorted { $0.frame.minY < $1.frame.minY }
                        XCTAssertEqual(labels.map(\.stringValue), [AchievementText.string("home.hero.\(mode.key)"),
                                                                 AchievementText.string("home.subtitle.\(mode.key)")])
                        let heading = try XCTUnwrap(labels.first)
                        let subtitle = try XCTUnwrap(labels.last)
                        XCTAssertGreaterThanOrEqual(subtitle.frame.minY - heading.frame.maxY, 8)
                        let headerSurface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home.modeHeader)
                        XCTAssertLessThan(intro.frame.maxX, headerSurface.minX)
                        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, running ? 42 : 0)
                        let hudRect = home.challengeHUD.convert(home.challengeHUD.bounds, to: home)
                        XCTAssertTrue(home.bounds.contains(hudRect))
                        let cards = home.modePanel.subviews.compactMap { $0 as? HomeModeButton }.sorted { $0.frame.minY < $1.frame.minY }
                        XCTAssertEqual(cards.map(\.mode), [.free, nil, .timed, .moves])
                        XCTAssertLessThan(hudRect.maxX, home.modePanel.frame.minX)
                        let surface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home)
                        let topInset = min(19, size.height * 0.245 * 0.079)
                        XCTAssertEqual(surface.minY, home.modePanel.frame.minY + topInset, accuracy: 0.2)
                        XCTAssertFalse(cards[1].isEnabled)
                        let label = try XCTUnwrap(home.challengeHUD.accessibilityLabel())
                        XCTAssertEqual(label.components(separatedBy: AchievementText.string("home.cleared_title")).count, 2)
                        for kind in PieceKind.allCases {
                            XCTAssertTrue(label.contains(AchievementText.string(kind.titleKey) + ": \(snapshot.clearedByKind[kind, default: 0])"))
                        }
                        if mode == .free { XCTAssertTrue(home.challengeHUD.budgetText.isEmpty) }
                        if !running && mode != .free {
                            let key = mode == .timed ? "home.challenge.time_limit" : "home.challenge.move_limit"
                            XCTAssertTrue(label.contains(AchievementText.string(key)))
                        }
                        if running {
                            let visibleLabels = home.subviews.compactMap { $0 as? NSTextField }.filter { !$0.isHidden }.map(\.stringValue)
                            XCTAssertFalse(visibleLabels.contains(AchievementText.string("home.mode.\(mode.key)")))
                            XCTAssertFalse(visibleLabels.contains(AchievementText.string("home.mode_desc.\(mode.key)")))
                        }
                        if language == .chineseSimplified, size.width == 1180 {
                            try export(home, name: running ? "lobby-\(mode.key)" : "lobby-idle-\(mode.key)")
                        }
                        if language == .russian, size.width == 960, mode == .moves, !running {
                            try export(home, name: "lobby-compact-ru")
                        }
                        if language == .chineseSimplified, size.width == 960, mode == .moves, !running {
                            try export(home, name: "lobby-compact-zh-hans")
                        }
                    }
                }
            }
        }
        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
        Localizer.shared.setLanguage(.chineseSimplified)
        home.setFrameSize(NSSize(width: 1585, height: 992))
        home.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
            remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free, manager: manager)
        let referenceBitmap = try image(home)
        try assertRuleCardMatchesReference(home, bitmap: referenceBitmap)
        try export(referenceBitmap, name: "lobby-reference-size")
        home.setFrameSize(NSSize(width: 1180, height: 800))
        home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 150, remainingTime: nil,
            remainingSwaps: 3, isRunning: true, isFinished: false, clearedByKind: [.orangeRicky: 120]), mode: .moves, manager: manager)
        try export(home, name: "lobby-last-moves")
        home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 160, remainingTime: nil,
            remainingSwaps: 0, isRunning: false, isFinished: true, clearedByKind: [.orangeRicky: 126]), mode: .moves, manager: manager)
        XCTAssertFalse(home.challengeHUD.isHidden)
        XCTAssertEqual(home.challengeHUD.budgetText, "0")
        let finishedLabels = home.subviews.compactMap { $0 as? NSTextField }.filter { !$0.isHidden }.map(\.stringValue)
        XCTAssertTrue(finishedLabels.contains(AchievementText.string("home.round_finished")))
        XCTAssertFalse(finishedLabels.contains { $0.contains("126") }, "结果提示不应重复统计面板的总数")
        try export(home, name: "lobby-finished")
    }

    func testStatisticsPlatesAssembleInPlaceAndKeepProgressAcrossRefreshes() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        let window = NSWindow(contentRect: home.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = home
        defer { window.close() }
        let header = home.modeHeader
        var clock: TimeInterval = 100
        var reduceMotion = false
        header.now = { clock }
        header.reducesMotion = { reduceMotion }
        let free = GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil, remainingSwaps: nil, isRunning: false, isFinished: false)
        let timed = GameSnapshot(mode: .timed(duration: 60), elapsedTime: 0, remainingTime: 60, remainingSwaps: nil, isRunning: false, isFinished: false)
        let moves = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 0, remainingTime: nil, remainingSwaps: 30, isRunning: false, isFinished: false)
        home.refresh(snapshot: free, mode: .free, manager: manager)
        home.layoutSubtreeIfNeeded()
        let intro = try modeIntro(in: header)
        let introFrame = intro.frame
        let preview = home.challengeHUD
        let restingSurface = preview.convert(preview.surfaceRect, to: home)
        XCTAssertEqual(preview.plateAssembly, .settled)
        home.refresh(snapshot: timed, mode: .timed, manager: manager)
        XCTAssertTrue(home.challengeHUD === preview, "模式切换复用同一张统计卡")
        XCTAssertEqual(preview.plateAssembly, .separated)
        XCTAssertEqual(preview.backingPlateOffset.x, -24, accuracy: 0.1)
        XCTAssertEqual(preview.backingPlateOffset.y, -26, accuracy: 0.1)
        XCTAssertEqual(preview.frontPlateOffset.x, 8, accuracy: 0.1)
        XCTAssertEqual(preview.frontPlateOffset.y, 24, accuracy: 0.1)

        let steps = 25
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-plate-assembly.gif")
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let duration = HomeModeHeaderView.previewDuration
        XCTAssertEqual(duration, 1.20, accuracy: 0.001)
        clock += 0.35
        header.advanceAnimation()
        XCTAssertEqual(preview.plateAssembly, .separated, "首帧前的等待不应消耗可见动画时间")
        let firstFrameTime = clock
        var previous = preview.plateAssembly
        for step in 0...steps {
            clock = firstFrameTime + duration * Double(step) / Double(steps)
            if step == steps { clock += 0.001 }
            header.advanceAnimation()
            home.layoutSubtreeIfNeeded()
            let assembly = preview.plateAssembly
            XCTAssertGreaterThanOrEqual(assembly.backing, previous.backing)
            XCTAssertGreaterThanOrEqual(assembly.front, previous.front)
            XCTAssertGreaterThanOrEqual(assembly.opacity, previous.opacity, "两层叠合时整体逐帧淡入")
            previous = assembly
            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home), restingSurface, "两层移动时保留牌面的基准位置和尺寸")
            XCTAssertEqual(intro.frame, introFrame, "模式切换保留标题位置")
            assertStatisticsPlatesLeftOfModes(home, preview: preview)

            switch step {
            case 0:
                XCTAssertEqual(assembly.opacity, 0, accuracy: 0.001, "入场首帧完全透明")
            case 2:
                XCTAssertGreaterThan(assembly.backing, 0)
                XCTAssertEqual(assembly.front, 0, accuracy: 0.001, "前板延后启动")
            case 6:
                XCTAssertLessThan(preview.backingPlateOffset.y, -1)
                XCTAssertGreaterThan(preview.frontPlateOffset.y, 1)
                XCTAssertEqual(assembly.opacity, 0.31, accuracy: 0.02, "前段保留较浅的透明度")
                try assertAssemblingPlatesAreVisible(home, preview: preview)
            case 10:
                XCTAssertEqual(assembly.opacity, 0.51, accuracy: 0.02, "叠合经过半透明状态")
            case 12:
                XCTAssertGreaterThan(assembly.front, 0)
                XCTAssertLessThan(assembly.front, 1)
                home.refresh(snapshot: timed, mode: .timed, manager: manager)
                home.layoutSubtreeIfNeeded()
                XCTAssertEqual(preview.plateAssembly, assembly, "重复刷新保留统计卡组装进度")
            case 16:
                XCTAssertEqual(assembly.backing, 1, accuracy: 0.001)
                XCTAssertEqual(preview.backingPlateOffset, .zero)
                XCTAssertLessThan(assembly.front, 1, "背板先于前板到位")
                XCTAssertEqual(assembly.highlight, 0, accuracy: 0.001)
            case 22:
                XCTAssertEqual(assembly.front, 1, accuracy: 0.001)
                XCTAssertEqual(preview.frontPlateOffset, .zero)
                XCTAssertEqual(assembly.opacity, 1, accuracy: 0.001, "接缝高光出现时牌面已完全显现")
                XCTAssertGreaterThan(assembly.highlight, 0, "两层合拢后才播放高光")
                XCTAssertLessThan(assembly.highlight, 1)
            default:
                break
            }
            let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
            home.cacheDisplay(in: header.frame, to: pixels)
            let frame = try XCTUnwrap(pixels.cgImage)
            let delay = step == steps ? 1.0 : duration / Double(steps)
            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
        XCTAssertEqual(preview.plateAssembly, .settled)
        XCTAssertEqual(preview.backingPlateOffset, .zero)
        XCTAssertEqual(preview.frontPlateOffset, .zero)
        XCTAssertFalse(intro.isHidden)

        home.refresh(snapshot: moves, mode: .moves, manager: manager)
        XCTAssertEqual(preview.mode, .moves)
        XCTAssertEqual(preview.budgetText, "30")
        XCTAssertEqual(preview.plateAssembly, .separated)
        header.advanceAnimation()
        clock += duration * 0.32
        header.advanceAnimation()
        let assemblyDuringEntry = preview.plateAssembly
        XCTAssertGreaterThan(assemblyDuringEntry.front, 0)
        XCTAssertLessThan(assemblyDuringEntry.front, 1)
        home.refresh(snapshot: timed, mode: .timed, manager: manager)
        XCTAssertEqual(preview.mode, .timed)
        XCTAssertEqual(preview.plateAssembly, .separated, "快速切回也从透明起步")
        home.refresh(snapshot: moves, mode: .moves, manager: manager)
        XCTAssertEqual(preview.plateAssembly, .separated)
        header.advanceAnimation()
        clock += duration * 0.32
        header.advanceAnimation()
        let restartedAssembly = preview.plateAssembly
        XCTAssertEqual(restartedAssembly.opacity, assemblyDuringEntry.opacity, accuracy: 0.001)
        window.setContentSize(NSSize(width: 960, height: 720))
        home.layoutSubtreeIfNeeded()
        XCTAssertEqual(home.bounds.width, 960, accuracy: 0.1)
        XCTAssertEqual(preview.plateAssembly, restartedAssembly)
        assertStatisticsPlatesLeftOfModes(home, preview: preview)
        clock += duration * 0.08
        header.advanceAnimation()
        let assemblyAfterResize = preview.plateAssembly
        XCTAssertGreaterThan(assemblyAfterResize.front, assemblyDuringEntry.front)
        assertStatisticsPlatesLeftOfModes(home, preview: preview)
        let playing = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 1, remainingTime: nil, remainingSwaps: 29, isRunning: true, isFinished: false)
        home.refresh(snapshot: playing, mode: .moves, manager: manager)
        XCTAssertEqual(preview.plateAssembly, assemblyAfterResize, "开局更新数字时继续组装")
        XCTAssertEqual(preview.budgetText, "29")
        reduceMotion = true
        header.advanceAnimation()
        XCTAssertEqual(preview.plateAssembly, .settled)
        XCTAssertEqual(preview.backingPlateOffset, .zero)
        XCTAssertEqual(preview.frontPlateOffset, .zero)
        home.refresh(snapshot: free, mode: .free, manager: manager)
        XCTAssertTrue(home.challengeHUD === preview)
        XCTAssertEqual(preview.plateAssembly, .settled)
        XCTAssertFalse(preview.isHidden)
        XCTAssertFalse(intro.isHidden)
    }

    func testChallengeBudgetTrackFillsAfterAssemblyAndFollowsTheLiveBudget() throws {
        _ = NSApplication.shared
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        let window = NSWindow(contentRect: home.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = home
        defer { window.close() }
        let header = home.modeHeader
        let hud = home.challengeHUD
        var clock: TimeInterval = 0
        var transitionStartedAt = clock
        header.now = { clock }
        header.reducesMotion = { false }
        let assemblyDuration = HomeModeHeaderView.previewDuration
        let fillDuration = HomeModeHeaderView.budgetFillDuration
        XCTAssertEqual(fillDuration, 0.60, accuracy: 0.001)

        func refresh(_ mode: HomeGameMode, seconds: TimeInterval? = nil, swaps: Int? = nil, running: Bool = false) {
            let elapsed = seconds.map { HomeGameMode.timedDuration - $0 } ?? (running ? 1 : 0)
            let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: elapsed, remainingTime: seconds,
                                        remainingSwaps: swaps, isRunning: running, isFinished: false)
            home.refresh(snapshot: snapshot, mode: mode, manager: manager)
        }

        func beginTransition() {
            transitionStartedAt = clock
            header.advanceAnimation()
        }

        func advance(to elapsed: TimeInterval) {
            clock = transitionStartedAt + elapsed
            header.advanceAnimation()
        }

        func litColumns() throws -> [Int] {
            home.layoutSubtreeIfNeeded()
            let offset = hud.backingPlateOffset
            let local = try XCTUnwrap(hud.budgetTrackRect).offsetBy(dx: offset.x, dy: offset.y)
            let track = hud.convert(local, to: home)
            // 用与动图相同的统计区合成帧采样，按裁剪区域的原点换算像素坐标。
            let region = header.frame
            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: region))
            home.cacheDisplay(in: region, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / region.width
            let y = Int((track.midY - region.minY) * scale)
            let first = Int(ceil((track.minX - region.minX) * scale))
            let last = Int(floor((track.maxX - region.minX) * scale))
            return (first..<last).filter { x in
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                let cyan = min(color.greenComponent, color.blueComponent)
                return cyan > 0.62 && cyan - color.redComponent > 0.22
            }
        }

        func litSegments() throws -> Int {
            let columns = try litColumns()
            guard !columns.isEmpty else { return 0 }
            return 1 + zip(columns, columns.dropFirst()).filter { left, right in right > left + 1 }.count
        }

        refresh(.free)
        home.layoutSubtreeIfNeeded()
        XCTAssertNil(hud.budgetTrackRect)
        refresh(.timed, seconds: 60)
        beginTransition()
        advance(to: assemblyDuration * 0.96)
        XCTAssertNotEqual(hud.plateAssembly, .settled)
        XCTAssertEqual(hud.budgetFillProgress, 0)
        XCTAssertTrue(try litColumns().isEmpty, "叠合期间只绘制暗色轨道")

        let steps = 12
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-budget-fill.gif")
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var fillColumns: [[Int]] = []
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            advance(to: assemblyDuration + fillDuration * fraction + (step == steps ? 0.001 : 0))
            home.layoutSubtreeIfNeeded()
            XCTAssertEqual(hud.plateAssembly, .settled, "预算填充开始时两层已到位")
            XCTAssertEqual(hud.budgetFillProgress, CGFloat(fraction), accuracy: 0.001)
            XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(fraction), accuracy: 0.001)
            if step == 0 || step == steps / 4 || step == steps / 2 || step == steps {
                fillColumns.append(try litColumns())
            }
            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
            home.cacheDisplay(in: header.frame, to: bitmap)
            let frame = try XCTUnwrap(bitmap.cgImage)
            let delay = step == steps ? 1.0 : fillDuration / Double(steps)
            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
        XCTAssertEqual(fillColumns.count, 4)
        let full = try XCTUnwrap(fillColumns.last.flatMap { $0.isEmpty ? nil : $0 }, "未开局的限时模式填满整条轨道")
        XCTAssertTrue(try XCTUnwrap(fillColumns.first).isEmpty)
        for (columns, fraction) in zip(fillColumns.dropFirst().dropLast(), [0.25, 0.50]) {
            XCTAssertEqual(columns.first, full.first, "预算从轨道左端开始填充")
            XCTAssertEqual(Double(columns.count) / Double(full.count), fraction, accuracy: 0.05)
        }
        refresh(.timed, seconds: 48, running: true)
        XCTAssertEqual(hud.budgetFillProgress, 1, "已填满后更新剩余时间无需重新填充")
        XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.8, accuracy: 0.05)

        refresh(.moves, swaps: 30)
        XCTAssertEqual(hud.budgetFillProgress, 0)
        beginTransition()
        advance(to: assemblyDuration + fillDuration * 0.34)
        XCTAssertEqual(try litSegments(), 10, "限步只显示填满的整格")
        refresh(.moves, swaps: 30, running: true)
        XCTAssertEqual(hud.budgetFillProgress, 0.34, accuracy: 0.001, "填充期间开局保留当前进度")
        XCTAssertEqual(try litSegments(), 10)
        refresh(.moves, swaps: 13, running: true)
        XCTAssertEqual(hud.remainingFraction, CGFloat(13) / 30, accuracy: 0.001)
        XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(13) / 30 * 0.34, accuracy: 0.001)
        XCTAssertEqual(try litSegments(), 4, "按填充进度换算当前剩余交换次数")
        advance(to: assemblyDuration + fillDuration * 0.72)
        XCTAssertEqual(try litSegments(), 9)
        advance(to: assemblyDuration + fillDuration + 0.001)
        XCTAssertEqual(hud.budgetFillProgress, 1)
        XCTAssertEqual(try litSegments(), 13, "动画结束时准确显示实际剩余步数")

        refresh(.timed, seconds: 60)
        beginTransition()
        advance(to: assemblyDuration + fillDuration * 0.5)
        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
        refresh(.timed, seconds: 42, running: true)
        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.35, accuracy: 0.05, "限时开局后按当前剩余时间填充")
        refresh(.moves, swaps: 30)
        XCTAssertEqual(hud.plateAssembly, .separated)
        XCTAssertEqual(hud.budgetFillProgress, 0, "上一模式尚在填充时，切换后仍重回空轨")
    }

    private func modeIntro(in header: HomeModeHeaderView) throws -> NSView {
        try XCTUnwrap(header.subviews.first { !$0.isHidden && !($0 is HomeChallengeHUDView) })
    }

    private func assertRuleCardMatchesReference(_ home: HomeDashboardView, bitmap: NSBitmapImageRep) throws {
        let card = home.challengeHUD
        let surface = card.convert(card.surfaceRect, to: home)
        XCTAssertEqual(surface.minX, 410, accuracy: 2.5)
        XCTAssertEqual(surface.minY, 123, accuracy: 2.5)
        XCTAssertEqual(surface.maxX, 1046, accuracy: 2.5)
        XCTAssertEqual(surface.maxY, 309, accuracy: 2.5)
        let scale = CGFloat(bitmap.pixelsWide) / home.bounds.width

        func brightness(at point: NSPoint) throws -> CGFloat {
            let color = try XCTUnwrap(bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB))
            return (color.redComponent + color.greenComponent + color.blueComponent) / 3
        }

        func brightnessInReference(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
            try brightness(at: NSPoint(x: surface.minX + (x - 410) * surface.width / 636,
                                       y: surface.minY + (y - 123) * surface.height / 186))
        }

        let rim = try (173...176).map { try brightnessInReference(780, CGFloat($0)) }.max() ?? 0
        let rimNeighbors = try max(brightnessInReference(780, 170), brightnessInReference(780, 178))
        XCTAssertGreaterThan(rim, rimNeighbors + 0.09, "统计前板的上边缘应在两层深色面板之间清楚可见")

        func edgeBrightness(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
            try (-2...2).map { try brightness(at: NSPoint(x: x + CGFloat($0) / 2, y: y)) }.max() ?? 0
        }

        let cells = card.breakdownCellRects.map { card.convert($0, to: home) }
        // 从两个高度采样暗缝，两边的描线都必须贴合共用角度。
        for (left, right) in zip(cells, cells.dropFirst()) {
            for fraction: CGFloat in [0.25, 0.75] {
                let y = left.minY + left.height * fraction
                let leftX = left.maxX - HomeDashboardStyle.edgeOffset(for: y - left.minY)
                let rightX = right.minX + HomeDashboardStyle.edgeOffset(for: right.maxY - y)
                let leftRim = try edgeBrightness(leftX, y)
                let rightRim = try edgeBrightness(rightX, y)
                let gap = try brightness(at: NSPoint(x: (leftX + rightX) / 2, y: y))
                XCTAssertGreaterThan(min(leftRim, rightRim), gap + 0.05, "两张斜卡之间应保留可见间隔")
            }
        }
    }

    private func assertStatisticsPlatesLeftOfModes(_ home: HomeDashboardView, preview: HomeChallengeHUDView,
                                                   file: StaticString = #filePath, line: UInt = #line) {
        for offset in [preview.backingPlateOffset, preview.frontPlateOffset] {
            let shifted = preview.surfaceRect.offsetBy(dx: offset.x, dy: offset.y)
            XCTAssertTrue(preview.bounds.contains(shifted), "绘制范围为移动中的板面留足空间", file: file, line: line)
            let surface = preview.convert(shifted, to: home)
            XCTAssertLessThan(surface.maxX, home.modePanel.frame.minX, "移动中的板面与右栏保留间隔", file: file, line: line)
        }
    }

    private func assertAssemblingPlatesAreVisible(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
        let backing = preview.surfaceRect.offsetBy(dx: preview.backingPlateOffset.x, dy: preview.backingPlateOffset.y)
        let cell = try XCTUnwrap(preview.breakdownCellRects.last)
        let rimPoints = [-1.0, 0, 1].map { offset in
            preview.convert(NSPoint(x: backing.midX, y: backing.minY + CGFloat(offset)), to: home)
        }
        let cellPoint = preview.convert(NSPoint(x: cell.midX + preview.frontPlateOffset.x,
                                              y: cell.midY + preview.frontPlateOffset.y), to: home)

        func color(at point: NSPoint) throws -> NSColor {
            let rect = NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: rect))
            home.cacheDisplay(in: rect, to: bitmap)
            return try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        }
        func difference(_ first: NSColor, _ second: NSColor) -> CGFloat {
            abs(first.redComponent - second.redComponent) + abs(first.greenComponent - second.greenComponent) + abs(first.blueComponent - second.blueComponent)
        }

        let visibleRim = try rimPoints.map { try color(at: $0) }
        let visibleCell = try color(at: cellPoint)
        preview.isHidden = true
        defer { preview.isHidden = false }
        let rimContrast = try zip(visibleRim, rimPoints).map { colorWithCard, point in
            difference(colorWithCard, try color(at: point))
        }.max() ?? 0
        XCTAssertGreaterThan(rimContrast, 0.06, "组装时移动后的背板上缘可见")
        XCTAssertGreaterThan(difference(visibleCell, try color(at: cellPoint)), 0.012, "组装时移动后的末尾分类格可见")
    }

    func testModeArtworkKeepsTransparencyAndIdentityAtSmallAndWideSizes() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        var unique: Set<Data> = []
        for mode in HomeGameMode.allCases {
            unique.insert(try XCTUnwrap(GameModeArtwork.image(for: mode).tiffRepresentation))
            for size in [NSSize(width: 24, height: 24), NSSize(width: 64, height: 64), NSSize(width: 120, height: 64)] {
                let artwork = NSImage(size: size, flipped: true) { bounds in GameModeArtwork.draw(mode, in: bounds); return true }
                let pixels = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(artwork.tiffRepresentation)))
                XCTAssertLessThan(pixels.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.01)
                var colored = 0
                for y in 0..<pixels.pixelsHigh {
                    for x in 0..<pixels.pixelsWide {
                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.5 else { continue }
                        if max(color.redComponent, color.greenComponent, color.blueComponent) - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.2 { colored += 1 }
                    }
                }
                XCTAssertGreaterThan(colored, 25, "每种模式都应有独立彩色主体")
            }
        }
        XCTAssertEqual(unique.count, 3)
        try export(ModeArtworkPreview(frame: NSRect(x: 0, y: 0, width: 600, height: 200)), name: "mode-artwork")
    }

    func testExportActualSelectionAndButtonFeedbackAnimation() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let preview = LobbyFeedbackPreview(frame: NSRect(x: 0, y: 0, width: 340, height: 180))
        let mode = HomeModeButton(mode: .moves)
        mode.frame = NSRect(x: 10, y: 80, width: 320, height: 90); mode.selected = true
        let button = HomeButton(frame: NSRect(x: 23, y: 10, width: 294, height: 62))
        button.style = .primary; button.title = "开始游戏"; button.symbolName = "play.fill"
        preview.addSubview(mode); preview.addSubview(button)
        var clock: TimeInterval = 100
        for effect in [mode.feedback, button.feedback] { effect.now = { clock }; effect.reducesMotion = { false } }
        mode.feedback.update(hover: false, press: false, selected: false, animated: false)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-lobby-feedback.gif") as CFURL,
                                                                      "com.compuserve.gif" as CFString, 36, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<36 {
            if frame == 0 { mode.feedback.update(hover: false, press: false, selected: true, animated: true) }
            if frame == 10 { button.feedback.update(hover: true, press: false, animated: true) }
            if frame == 20 { button.feedback.update(hover: true, press: true, animated: true) }
            if frame == 27 { button.feedback.update(hover: false, press: false, animated: true) }
            mode.feedback.advance(at: clock); button.feedback.advance(at: clock)
            let pixels = try image(preview)
            CGImageDestinationAddImage(destination, try XCTUnwrap(pixels.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
            clock += 0.04
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

private final class LobbyFeedbackPreview: NSView {
    override func draw(_ dirtyRect: NSRect) { HomeDashboardStyle.backdrop(in: bounds) }
}

/// 仅测试 target 中的三枚图案总览，不增加正式页面入口。
private final class ModeArtworkPreview: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.background.setFill(); bounds.fill()
        for (index, mode) in HomeGameMode.allCases.enumerated() {
            let x = CGFloat(index) * 200
            GameModeArtwork.draw(mode, in: NSRect(x: x + 50, y: 18, width: 100, height: 100))
            HomeStyle.text(AchievementText.string("home.mode.\(mode.key)"), in: NSRect(x: x + 10, y: 130, width: 180, height: 26), size: 18, weight: .semibold, alignment: .center)
            GameModeArtwork.draw(mode, in: NSRect(x: x + 88, y: 166, width: 24, height: 24))
        }
    }
}
