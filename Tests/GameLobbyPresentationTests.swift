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
        try XCTUnwrap(try image(view).representation(using: .png, properties: [:]))
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

    func testPieceCountsFillFourEqualColumnsAcrossStatWidths() throws {
        _ = NSApplication.shared
        let longCount = 123_456
        let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
        for mode in HomeGameMode.allCases {
            for width: CGFloat in [534, 1_360] {
                let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: width, height: 148))
                hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode, elapsedTime: 60,
                                                   remainingTime: mode == .timed ? 0 : nil,
                                                   remainingSwaps: mode == .moves ? 0 : nil,
                                                   isRunning: false, isFinished: true, clearedByKind: counts), mode: mode)
                let bitmap = try image(hud)
                let scale = CGFloat(bitmap.pixelsWide) / width
                var iconStarts: [CGFloat] = []
                var previousColoredX = -CGFloat.infinity
                // 结算后的进度条没有颜色。用彩色列测量四个图标实际位置，覆盖不同位数的数字。
                for x in 0..<bitmap.pixelsWide {
                    let containsArtwork = stride(from: 0, to: bitmap.pixelsHigh, by: 2).contains { y in
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
                let statsWidth = (hud.surfaceRect.width - 40) * (mode == .free ? 1 : 0.73)
                let columnWidth = statsWidth * 2 / 3 / CGFloat(PieceKind.allCases.count)
                XCTAssertEqual(iconStarts.count, PieceKind.allCases.count, "\(mode.key) / \(width)")
                let breakdownStart = hud.surfaceRect.maxX - 20 - statsWidth * 2 / 3
                for (index, start) in iconStarts.enumerated() {
                    XCTAssertEqual(start, breakdownStart + CGFloat(index) * columnWidth, accuracy: 1,
                                   "\(mode.key) / \(width)：方块图标应依等宽列左边缘排布")
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
                        XCTAssertEqual(home.challengeHUD.isHidden, !running && mode == .free)
                        if !running, mode == .free {
                            let intro = try XCTUnwrap(home.modeHeader.subviews.first { !$0.isHidden })
                            let labels = intro.subviews.compactMap { $0 as? NSTextField }.sorted { $0.frame.minY < $1.frame.minY }
                            XCTAssertEqual(labels.count, 2)
                            XCTAssertGreaterThanOrEqual(labels[1].frame.minY - labels[0].frame.maxY, 8,
                                                        "主标题和副标题之间保留独立排版空间")
                        }
                        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, running ? 42 : 0)
                        let hudRect = home.challengeHUD.convert(home.challengeHUD.bounds, to: home)
                        XCTAssertTrue(home.bounds.contains(hudRect))
                        let cards = home.modePanel.subviews.compactMap { $0 as? HomeModeButton }.sorted { $0.frame.minY < $1.frame.minY }
                        XCTAssertEqual(cards.map(\.mode), [.free, nil, .timed, .moves])
                        XCTAssertLessThan(hudRect.maxX, home.modePanel.frame.minX)
                        let surface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home)
                        XCTAssertEqual(surface.minY, home.modePanel.frame.minY, accuracy: 0.1)
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
                    }
                }
            }
        }
        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
        Localizer.shared.setLanguage(.chineseSimplified)
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

    func testChallengePreviewGrowsWithinScreenForOneSecondAndKeepsItsProgressOnRoundStart() throws {
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
        let intro = try XCTUnwrap(header.subviews.first { !$0.isHidden })
        let restingX = intro.frame.minX
        let restingWidth = intro.frame.width
        home.refresh(snapshot: timed, mode: .timed, manager: manager)
        let preview = home.challengeHUD
        XCTAssertGreaterThan(preview.frame.minX, restingX)
        XCTAssertLessThanOrEqual(preview.frame.minX, home.modePanel.frame.minX + 0.1)
        XCTAssertEqual(preview.frame.width, restingWidth * 0.20, accuracy: 0.1)
        XCTAssertLessThan(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height)
        try assertLaunchIsWithinScreen(preview, in: window)
        XCTAssertLessThan(preview.alphaValue, 0.2)

        let steps = 25
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-challenge-preview.gif")
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let duration = HomeModeHeaderView.previewDuration
        XCTAssertEqual(duration, 1)
        var previousWidth = preview.frame.width
        for step in 0...steps {
            clock = 100 + duration * Double(step) / Double(steps)
            header.advanceAnimation()
            XCTAssertGreaterThanOrEqual(preview.frame.width + 0.1, previousWidth)
            XCTAssertLessThanOrEqual(preview.frame.maxX, header.bounds.maxX + 0.1)
            previousWidth = preview.frame.width
            if step == steps / 2 {
                let position = preview.frame.minX
                XCTAssertGreaterThan(position, restingX)
                XCTAssertGreaterThan(preview.alphaValue, 0.2)
                home.refresh(snapshot: timed, mode: .timed, manager: manager)
                home.layoutSubtreeIfNeeded()
                XCTAssertEqual(preview.frame.minX, position, accuracy: 1, "重复刷新不能重启动画")
                try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview)
            }
            if step == steps * 3 / 4 { XCTAssertLessThan(intro.frame.minX, restingX, "卡片接触文案后将其向左推开") }
            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, home.modePanel.frame.minY, accuracy: 0.1)
            home.layoutSubtreeIfNeeded()
            let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
            home.cacheDisplay(in: header.frame, to: pixels)
            let frame = try XCTUnwrap(pixels.cgImage)
            if step == steps * 3 / 4 {
                try XCTUnwrap(pixels.representation(using: .png, properties: [:]))
                    .write(to: url.deletingLastPathComponent().appendingPathComponent("eliminate-challenge-preview-motion.png"))
            }
            let delay = step == steps ? 1.0 : duration / Double(steps)
            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
        XCTAssertEqual(preview.frame.minX, restingX, accuracy: 1)
        XCTAssertEqual(preview.frame.width, restingWidth, accuracy: 0.1)
        XCTAssertEqual(preview.alphaValue, 1)
        XCTAssertTrue(intro.isHidden)

        home.refresh(snapshot: moves, mode: .moves, manager: manager)
        XCTAssertEqual(home.challengeHUD.budgetText, "30")
        XCTAssertEqual(preview.mode, .timed, "离场卡保留原规则")
        clock += 0.7
        header.advanceAnimation()
        let frameDuringEntry = home.challengeHUD.frame
        let playing = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 1, remainingTime: nil, remainingSwaps: 29, isRunning: true, isFinished: false)
        home.refresh(snapshot: playing, mode: .moves, manager: manager)
        XCTAssertEqual(home.challengeHUD.frame, frameDuringEntry)
        XCTAssertEqual(home.challengeHUD.budgetText, "29")
        reduceMotion = true
        header.advanceAnimation()
        XCTAssertEqual(home.challengeHUD.frame.minX, restingX, accuracy: 1)
        XCTAssertTrue(preview.isHidden)
        home.refresh(snapshot: free, mode: .free, manager: manager)
        XCTAssertTrue(home.challengeHUD.isHidden)
        XCTAssertFalse(intro.isHidden)
    }

    private func assertLaunchIsWithinScreen(_ preview: HomeChallengeHUDView, in window: NSWindow) throws {
        XCTAssertLessThanOrEqual(preview.frame.maxX, try XCTUnwrap(preview.superview).bounds.maxX + 0.1)
        if let screen = window.screen {
            let right = preview.convert(preview.bounds, to: nil).maxX
            let launchRight = window.convertPoint(toScreen: NSPoint(x: right, y: 0)).x
            XCTAssertLessThanOrEqual(launchRight, screen.frame.maxX + 0.1)
        }
    }

    private func assertPreviewLaysOverGapAndBehindPanel(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
        let panel = home.modePanel.frame
        let surface = preview.convert(preview.surfaceRect, to: home)
        let gapPoint = NSPoint(x: panel.minX - 14, y: panel.minY + 43)
        let panelPoint = NSPoint(x: panel.minX + 10, y: gapPoint.y)
        XCTAssertTrue(surface.contains(gapPoint) && surface.contains(panelPoint))

        func color(at point: NSPoint) throws -> NSColor {
            let rect = NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: rect))
            home.cacheDisplay(in: rect, to: bitmap)
            return try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        }
        func difference(_ first: NSColor, _ second: NSColor) -> CGFloat {
            abs(first.redComponent - second.redComponent) + abs(first.greenComponent - second.greenComponent) + abs(first.blueComponent - second.blueComponent)
        }

        let visibleGap = try color(at: gapPoint)
        let visiblePanel = try color(at: panelPoint)
        preview.isHidden = true
        defer { preview.isHidden = false }
        XCTAssertGreaterThan(difference(visibleGap, try color(at: gapPoint)), 0.012, "超出左栏的卡面应进入两栏间隙")
        XCTAssertLessThan(difference(visiblePanel, try color(at: panelPoint)), 0.008, "右侧面板应在重叠处完整盖住统计卡")
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
        button.primary = true; button.title = "开始游戏"; button.symbolName = "play.fill"
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
    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
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
