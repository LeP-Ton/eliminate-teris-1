import Cocoa
import QuartzCore
import XCTest
@testable import EliminateTeris1

final class HomeDashboardTests: AchievementTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    private func board(now: @escaping () -> Date) -> GameBoardController {
        GameBoardController(columns: 4, achievements: manager, now: now) { _ in
            let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
            let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
            let refill = Array(repeating: a, count: 27) + [c, d, c]
            var index = 0
            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
                defer { index += 1 }
                return refill[index]
            }
        }
    }

    func testCurrentRoundStatisticsResetWhileLifetimeCountsRemain() {
        let board = board(now: { self.date })
        XCTAssertFalse(board.snapshot().isRunning)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        board.startRound()
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 30)
        XCTAssertEqual(board.snapshot().clearedByKind[.orangeRicky], 30)
        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
        board.startRound()
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
        board.configure(mode: HomeGameMode.moves.gameMode)
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        XCTAssertFalse(board.snapshot().isRunning)
    }

    func testFixedModesFinishAtSixtySecondsAndThirtySwaps() {
        var now = date
        let board = board(now: { now })
        board.configure(mode: HomeGameMode.timed.gameMode)
        board.startRound()
        now = date.addingTimeInterval(59.9)
        board.tick()
        XCTAssertFalse(board.snapshot().isFinished)
        now = date.addingTimeInterval(60)
        board.tick()
        XCTAssertTrue(board.snapshot().isFinished)
        board.configure(mode: HomeGameMode.moves.gameMode)
        board.startRound()
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 30)
        XCTAssertEqual(board.snapshot().remainingSwaps, 29)
        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
        XCTAssertTrue(board.snapshot().isFinished)
        let final = board.snapshot().clearedByKind
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.snapshot().clearedByKind, final)
    }

    func testHomeButtonsUseFixedRulesAndLiveStats() throws {
        _ = NSApplication.shared
        var gameTime = date
        let board = board(now: { gameTime })
        let records = ModeRecordStore(defaults: defaults)
        var animationTime: TimeInterval = 0
        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false, startClock: { animationTime })
        controller.startSequence.reducesMotion = { false }
        let view = controller.view
        let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.style == .primary })
        let home = try XCTUnwrap(view as? HomeDashboardView)
        let puzzle = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == nil })
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertFalse(puzzle.isEnabled)
        puzzle.performClick(nil)
        XCTAssertFalse(board.snapshot().isRunning)
        start.performClick(nil)
        XCTAssertFalse(board.snapshot().isRunning, "开场动画不应消耗游戏时间")
        animationTime += 1; controller.startSequence.advanceAnimation()
        XCTAssertTrue(board.snapshot().isRunning)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
        puzzle.performClick(nil)
        XCTAssertTrue(board.snapshot().isRunning, "解谜入口不能切换或重置正在进行的游戏")
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
        let free = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .free })
        free.performClick(nil)
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30, "点击已选模式不应重置本局")
        let speed = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .moves })
        speed.performClick(nil)
        XCTAssertEqual(board.snapshot().remainingSwaps, 30)
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 0)
        XCTAssertFalse(home.challengeHUD.isHidden)
        XCTAssertFalse(board.snapshot().isRunning)
        start.performClick(nil)
        animationTime += 1; controller.startSequence.advanceAnimation()
        board.performSwap(from: 2, to: 3)
        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
        XCTAssertTrue(board.snapshot().isFinished)
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
        let finished = try XCTUnwrap(records.records(for: .moves, detailValue: 30).first)
        XCTAssertEqual(finished.elapsedTime, 0)
        for _ in 0..<3 { board.tick() }
        XCTAssertEqual(records.records(for: .moves, detailValue: 30).first?.id, finished.id)
        XCTAssertTrue(descendants(view).allSatisfy { !($0 is NSPopUpButton) })
        let score = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .timed })
        score.performClick(nil)
        XCTAssertEqual(board.snapshot().remainingTime, 60)
        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 0)
        XCTAssertFalse(home.challengeHUD.isHidden)
        XCTAssertEqual(home.challengeHUD.budgetText, "01:00")
        gameTime = gameTime.addingTimeInterval(90)
        board.tick()
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertFalse(board.snapshot().isFinished)
        XCTAssertEqual(home.challengeHUD.budgetText, "01:00", "等待开局期间保持完整时间限制")
    }

    private func openStatisticsTestWindow() throws -> (window: NSWindow, home: HomeDashboardView) {
        _ = NSApplication.shared
        let controller = GameViewController(achievements: manager, records: ModeRecordStore(defaults: defaults),
                                            board: board(now: { Date() }), audioEnabled: false)
        let home = try XCTUnwrap(controller.view as? HomeDashboardView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        home.modeHeader.reducesMotion = { false }
        home.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()
        // 先呈现初始大厅，再按模式按钮，避免把窗口首次显示的工作算进转场。
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
        return (window, home)
    }

    func testModeButtonsGiveStatisticsAssemblyItsFullVisibleDuration() throws {
        let (window, home) = try openStatisticsTestWindow()
        defer { window.close() }
        let hud = home.challengeHUD

        let onMode = try XCTUnwrap(home.onMode)
        home.onMode = { mode in
            onMode(mode)
            // 模拟首次切换仍在同步处理启动工作，窗口要等按钮动作返回才可继续绘制。
            if mode == .timed { Thread.sleep(forTimeInterval: 0.18) }
        }

        let duration = HomeModeHeaderView.previewDuration
        let animationClock = home.modeHeader.now
        var animationTicks: [TimeInterval] = []
        home.modeHeader.now = {
            let timestamp = animationClock()
            animationTicks.append(timestamp)
            return timestamp
        }
        func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
        for mode in [HomeGameMode.timed, .moves, .free] {
            let button = try XCTUnwrap(home.modePanel.subviews.compactMap { $0 as? HomeModeButton }.first { $0.mode == mode })
            animationTicks.removeAll(keepingCapacity: true)
            button.performClick(nil)
            let returnedAt = uptime()
            XCTAssertTrue(button.selected)
            XCTAssertEqual(hud.mode, mode)

            var sawProgress = false
            var halfwayOpacity: CGFloat?
            var settledAt: TimeInterval?
            // 让窗口自然绘制，采样过程不插入同步重绘。
            repeat {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.008))
                let sampledAt = uptime()
                let assembly = hud.plateAssembly
                if assembly != .settled {
                    sawProgress = true
                    if halfwayOpacity == nil && (0.30...0.75).contains(assembly.opacity) {
                        halfwayOpacity = assembly.opacity
                    }
                } else if sawProgress {
                    settledAt = sampledAt
                }
            } while settledAt == nil && uptime() < returnedAt + duration + 1

            let settled = try XCTUnwrap(settledAt, "模式 \(mode.key) 的统计卡应完成可见动画")
            let elapsed = settled - returnedAt
            let opacity = try XCTUnwrap(halfwayOpacity, "模式 \(mode.key) 的统计卡应绘制半透明帧")
            let firstTick = try XCTUnwrap(animationTicks.first)
            let lastTick = try XCTUnwrap(animationTicks.last)
            print(String(format: "统计卡模式切换 %@，按钮返回后 %.3f 秒到位，首个动画帧至完成 %.3f 秒，半透明帧不透明度 %.2f",
                         mode.key, elapsed, lastTick - firstTick, Double(opacity)))
            XCTAssertGreaterThanOrEqual(elapsed, duration - 0.04, "按钮动作中的同步工作不应缩短可见动画")
            XCTAssertGreaterThanOrEqual(lastTick - firstTick, duration, "两层卡片应该走完整个动画时段")
        }
    }

    func testStatisticsBudgetPixelsFadeInAgainWhenModeChangesDuringAssembly() throws {
        let (window, home) = try openStatisticsTestWindow()
        defer { window.close() }
        let hud = home.challengeHUD
        let buttons = home.modePanel.subviews.compactMap { $0 as? HomeModeButton }
        let timed = try XCTUnwrap(buttons.first { $0.mode == .timed })
        let moves = try XCTUnwrap(buttons.first { $0.mode == .moves })
        let duration = HomeModeHeaderView.previewDuration
        let animationClock = home.modeHeader.now
        var firstTick: TimeInterval?
        var latestTick: TimeInterval?
        home.modeHeader.now = {
            let timestamp = animationClock()
            if firstTick == nil { firstTick = timestamp }
            latestTick = timestamp
            return timestamp
        }

        func budgetOpacity() throws -> CGFloat {
            let track = try XCTUnwrap(hud.budgetTrackRect)
            let center = NSPoint(x: track.midX + hud.backingPlateOffset.x, y: track.midY + hud.backingPlateOffset.y)
            // 在轨道中线取一小段，限步轨道至少会命中一个实心分格。
            let rect = NSRect(x: center.x - 9, y: center.y - 2, width: 18, height: 4)
            let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: rect))
            hud.cacheDisplay(in: rect, to: bitmap)
            let row = bitmap.pixelsHigh / 2
            return (0..<bitmap.pixelsWide).compactMap { bitmap.colorAt(x: $0, y: row)?.alphaComponent }.max() ?? 0
        }

        func samplesThroughHalfOpacity() throws -> [(elapsed: TimeInterval, opacity: CGFloat)] {
            let deadline = ProcessInfo.processInfo.systemUptime + duration + 1
            var lastSampledTick: TimeInterval?
            var samples: [(elapsed: TimeInterval, opacity: CGFloat)] = []
            while ProcessInfo.processInfo.systemUptime < deadline {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
                guard let firstTick, let latestTick, latestTick != lastSampledTick else { continue }
                lastSampledTick = latestTick
                let opacity = try budgetOpacity()
                samples.append((latestTick - firstTick, opacity))
                if opacity >= 0.50 { break }
            }
            return samples
        }

        timed.performClick(nil)
        XCTAssertTrue(timed.selected)
        XCTAssertEqual(hud.mode, .timed)
        let initial = try budgetOpacity()
        let samples = try samplesThroughHalfOpacity()
        let early = try XCTUnwrap(samples.first { $0.opacity >= 0.10 })
        let halfway = try XCTUnwrap(samples.first { $0.opacity >= 0.50 })
        print(String(format: "限时统计轨道实测，初始 %.2f，首段 %.2f，至半透明 %.3f 秒，取样 %d 帧",
                     Double(initial), Double(early.opacity), halfway.elapsed, samples.count))
        XCTAssertLessThan(initial, 0.10, "首次切换从接近透明开始")
        XCTAssertLessThan(early.opacity + 0.15, halfway.opacity, "首段经过不同程度的半透明")
        for (previous, current) in zip(samples, samples.dropFirst()) {
            XCTAssertGreaterThanOrEqual(current.opacity + 0.03, previous.opacity, "可见像素逐步显现")
        }
        XCTAssertGreaterThanOrEqual(halfway.elapsed, duration * 0.30, "前段淡入为半透明状态保留足够时间")

        XCTAssertNotEqual(hud.plateAssembly, .settled, "在上一次动画完成前点击下一个模式")
        firstTick = nil
        latestTick = nil
        moves.performClick(nil)
        XCTAssertTrue(moves.selected)
        XCTAssertEqual(hud.mode, .moves)
        let restarted = try budgetOpacity()
        let movesSamples = try samplesThroughHalfOpacity()
        let movesHalfway = try XCTUnwrap(movesSamples.first { $0.opacity >= 0.50 })
        print(String(format: "限步统计轨道实测，中途切换后初始 %.2f，至半透明 %.3f 秒", Double(restarted), movesHalfway.elapsed))
        XCTAssertLessThan(restarted, 0.12, "中途切换时新轨道从接近透明重新淡入")
    }

    func testAchievementRowSpansBothColumnsAndStartAlignsWithContact() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        defaults.set(["version": 1, "unlocked": [1, 3, 4, 7, 17, 18], "metrics": [:]], forKey: AchievementsManager.storageKey)
        let progress = AchievementsManager(defaults: defaults)
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
        let snapshot = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 0, remainingTime: nil, remainingSwaps: 30,
                                    isRunning: false, isFinished: false)
        home.refresh(snapshot: snapshot, mode: .moves, manager: progress)
        let buttons = home.achievementPath.subviews.compactMap { $0 as? HomeButton }
        let badges = buttons.filter { $0.toolTip != nil }
        XCTAssertEqual(badges.count, AchievementDefinition.all.count)
        for (width, height, count) in [(960, 720, 5), (1180, 800, 5), (1440, 720, 7),
                                       (960, 1000, 5), (1600, 1000, 7), (1920, 1250, 9), (960, 720, 5)] {
            home.setFrameSize(NSSize(width: width, height: height))
            home.layoutSubtreeIfNeeded()
            let mode = home.modePanel.frame
            let path = home.achievementPath.frame
            let contact = home.contactPanel.frame
            XCTAssertEqual(home.startButton.frame.maxY, contact.maxY, accuracy: 0.1)
            XCTAssertGreaterThanOrEqual(contact.minY - mode.maxY, 27)
            XCTAssertLessThanOrEqual(contact.minY - mode.maxY, 52.1)
            XCTAssertGreaterThanOrEqual(mode.minX, contact.minX)
            XCTAssertEqual(contact.maxX, mode.maxX, accuracy: 0.1)
            XCTAssertTrue((110...165).contains(contact.height))
            XCTAssertGreaterThanOrEqual(path.minY - contact.maxY, 35)
            XCTAssertEqual(path.minX, home.bounds.maxX - path.maxX, accuracy: 0.1)
            XCTAssertEqual(path.maxX, contact.maxX, accuracy: 0.1)
            XCTAssertTrue(home.bounds.contains(path))

            let visible = badges.filter { !$0.isHidden }
            XCTAssertEqual(visible.count, count)
            XCTAssertEqual(Set(visible.map { $0.frame.minY }).count, 1)
            XCTAssertTrue(visible.allSatisfy { home.achievementPath.bounds.contains($0.frame) })
            XCTAssertEqual(try XCTUnwrap(visible.first).frame.minX, 0, accuracy: 0.1)
            XCTAssertEqual(try XCTUnwrap(visible.last).frame.maxX, path.width, accuracy: 0.1)
            if width == 1600 {
                let rep = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: home.bounds))
                home.cacheDisplay(in: home.bounds, to: rep)
                try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                    .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-achievement-grid.png"))
                // 6 / 32 的进度停在第二个分段中，比较两行黄色像素右端以捕捉垂直裁切回归。
                let crop = NSRect(x: 0, y: 18, width: path.width * 0.66, height: 24)
                let meter = try XCTUnwrap(home.achievementPath.bitmapImageRepForCachingDisplay(in: crop))
                home.achievementPath.cacheDisplay(in: crop, to: meter)
                let scale = CGFloat(meter.pixelsHigh) / crop.height
                func fillEnd(at y: CGFloat) throws -> CGFloat {
                    let row = Int((y - crop.minY) * scale)
                    let x = try XCTUnwrap((0..<meter.pixelsWide).last { x in
                        guard let color = meter.colorAt(x: x, y: row)?.usingColorSpace(.sRGB) else { return false }
                        return color.redComponent > 0.8 && color.greenComponent > 0.7 && color.blueComponent < 0.45
                    })
                    return CGFloat(x) / scale
                }
                XCTAssertEqual(try fillEnd(at: 26) - fillEnd(at: 33), HomeDashboardStyle.edgeOffset(for: 7), accuracy: 1)
            }
        }

        var openedAchievements: [Int?] = []
        home.onAchievement = { openedAchievements.append($0) }
        let badge = try XCTUnwrap(badges.first { !$0.isHidden })
        badge.performClick(nil)
        let all = try XCTUnwrap(buttons.first { $0.title.hasPrefix(AchievementText.string("achievement.view_all")) })
        all.performClick(nil)
        XCTAssertEqual(openedAchievements, [1, nil])
        var feedbackURL: URL?
        home.contactPanel.openURL = { feedbackURL = $0 }
        let feedback = try XCTUnwrap(home.contactPanel.subviews.compactMap { $0 as? HomeButton }.first)
        feedback.performClick(nil)
        XCTAssertEqual(feedback.title, "在 GitHub 反馈")
        XCTAssertEqual(feedbackURL?.absoluteString, "https://github.com/LeP-Ton/eliminate-teris-1/issues")
    }

    func testHomeRendersAllModesLanguagesAndWindowSizes() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        defaults.set(["version": 1, "unlocked": [1, 3, 4, 7], "metrics": [:]], forKey: AchievementsManager.storageKey)
        let progress = AchievementsManager(defaults: defaults)
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        let navigationPages = ["records", "rules", "settings"]
        let minimumBrandFont = NSFont.systemFont(ofSize: 16, weight: .black)
        var openedPages: [String] = []
        home.onNavigate = { openedPages.append($0) }
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            let brand = AchievementText.string("home.brand")
            let minimumBrandWidth = (brand as NSString).size(withAttributes: [.font: minimumBrandFont]).width
            XCTAssertEqual(brand, AchievementText.string("window.title"))
            if language == .chineseSimplified {
                XCTAssertEqual(brand, "消除俄罗斯方块")
            }
            for mode in HomeGameMode.allCases {
                let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: 12, remainingTime: mode == .timed ? 48 : nil,
                                            remainingSwaps: mode == .moves ? 18 : nil, isRunning: true, isFinished: false,
                                            clearedByKind: [.orangeRicky: 3, .blueRicky: 9, .clevelandZ: 6, .rhodeIslandZ: 3])
                for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1440, height: 940)] {
                    home.setFrameSize(size)
                    home.refresh(snapshot: snapshot, mode: mode, manager: progress)
                    home.layoutSubtreeIfNeeded()
                    XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 21)
                    let feedback = try XCTUnwrap(home.contactPanel.subviews.compactMap { $0 as? HomeButton }.first)
                    XCTAssertEqual(feedback.title, AchievementText.string("home.contact.action"))
                    XCTAssertTrue(home.contactPanel.bounds.contains(feedback.frame))
                    let visibleButtons = home.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden }
                    for button in visibleButtons {
                        XCTAssertTrue(home.bounds.contains(button.frame), "\(language.rawValue): \(button.frame)")
                        XCTAssertGreaterThan(button.frame.height, 30)
                    }
                    let navigationButtons = visibleButtons.filter { $0.style == .navigation }.sorted { $0.frame.minX < $1.frame.minX }
                    XCTAssertEqual(navigationButtons.map(\.title), navigationPages.map { AchievementText.string("panel.\($0)") })
                    let firstNavigationFrame = try XCTUnwrap(navigationButtons.first).frame
                    let brandX = max(29, size.width * 0.034) + 111
                    XCTAssertGreaterThanOrEqual(firstNavigationFrame.minX - brandX, minimumBrandWidth + 26, "\(language.rawValue): \(size.width)")
                    let navigationFont = NSFont.systemFont(ofSize: min(19, firstNavigationFrame.height * 0.44), weight: .bold)
                    for button in navigationButtons {
                        XCTAssertEqual(button.frame.height, firstNavigationFrame.height)
                        let titleWidth = (button.title as NSString).size(withAttributes: [.font: navigationFont]).width
                        XCTAssertGreaterThanOrEqual((button.frame.width - titleWidth) / 2, 24, button.title)
                    }
                    for (left, right) in zip(navigationButtons, navigationButtons.dropFirst()) {
                        XCTAssertEqual(right.frame.minX - left.frame.maxX, 19, accuracy: 0.01)
                    }
                    if language == .chineseSimplified, mode == .free, size.width == 960 {
                        navigationButtons.forEach { $0.performClick(nil) }
                        XCTAssertEqual(openedPages, navigationPages)
                    }
                    if language == .chineseSimplified, size.width == 1180 {
                        let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: home.bounds))
                        home.cacheDisplay(in: home.bounds, to: bitmap)
                        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        let path = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-\(mode.key).png")
                        try png.write(to: path)
                        print("首页预览：\(path.path)")
                        if mode == .free {
                            let hero = try XCTUnwrap(descendants(home).compactMap { $0 as? HomeHeroView }.first)
                            let artwork = try XCTUnwrap(hero.bitmapImageRepForCachingDisplay(in: hero.bounds))
                            hero.cacheDisplay(in: hero.bounds, to: artwork)
                            try XCTUnwrap(artwork.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-design-cutout-hero.png"))
                        }
                    }
                }
            }
        }
    }

    func testSettingsOnlyExposeLanguageAndVolumeAndNavigationPanelsRender() throws {
        _ = NSApplication.shared
        let store = ModeRecordStore(defaults: defaults)
        for page in ["settings", "rules", "records"] {
            let panel = HomeUtilityPanel(page: page, store: store)
            defer { panel.close() }
            panel.refresh(mode: .timed, volume: 0.4)
            let window = try XCTUnwrap(panel.window)
            XCTAssertFalse(window.canBecomeKey)
            let content = try XCTUnwrap(window.contentView)
            let popups = descendants(content).compactMap { $0 as? NSPopUpButton }
            if page == "settings" {
                XCTAssertEqual(popups.count, 1, "设置只提供语言菜单，不提供规则档位")
                let slider = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSlider }.first)
                var volume: Float = 0
                panel.onVolume = { volume = $0 }
                slider.doubleValue = 0.25
                slider.sendAction(slider.action, to: slider.target)
                XCTAssertEqual(volume, 0.25)
            } else { XCTAssertTrue(popups.isEmpty) }
            let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-\(page).png"))
        }
    }

    func testBundledHeroArtworkUsesOriginalDesignPixelsAndCorrectSilhouettes() throws {
        let bundle = try XCTUnwrap(GameResourceLocator.resourceBundle())
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: root.appendingPathComponent("docs/design/home-reference.png"))))
        let definitions: [(PieceKind, String, Int, Int, Int, Int, NSRect)] = [
            (.orangeRicky, "orange", 76, 450, 190, 150, NSRect(x: 28, y: 29, width: 138, height: 95)),
            (.blueRicky, "blue", 290, 450, 167, 150, NSRect(x: 18, y: 34, width: 133, height: 92)),
            (.clevelandZ, "green", 544, 435, 197, 165, NSRect(x: 17, y: 51, width: 134, height: 91)),
            (.rhodeIslandZ, "red", 744, 440, 207, 160, NSRect(x: 16, y: 46, width: 135, height: 91))
        ]
        for (kind, name, originX, originY, width, height, body) in definitions {
            let url = try XCTUnwrap(bundle.url(forResource: "home-design-\(name)", withExtension: "png"))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
            XCTAssertTrue(bitmap.hasAlpha)
            XCTAssertEqual(bitmap.pixelsWide, width)
            XCTAssertEqual(bitmap.pixelsHigh, height)
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.01)
            // 对比主体的全部不透明像素，证明使用原稿而非相似的重新生成素材。
            var maximumError: CGFloat = 0
            var opaqueCount = 0
            for y in 0..<height {
                for x in 0..<width {
                    let pixel = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    guard pixel.alphaComponent > 0.999 else { continue }
                    let original = try XCTUnwrap(source.colorAt(x: x + originX, y: y + originY)?.usingColorSpace(.sRGB))
                    maximumError = max(maximumError, abs(pixel.redComponent - original.redComponent),
                                       abs(pixel.greenComponent - original.greenComponent), abs(pixel.blueComponent - original.blueComponent))
                    opaqueCount += 1
                }
            }
            XCTAssertGreaterThan(opaqueCount, 5000)
            XCTAssertLessThanOrEqual(maximumError, 1.1 / 255, "\(name) 主体像素应与设计稿一致")
            for row in 0..<2 {
                for column in 0..<3 {
                    let x = Int(body.minX + (CGFloat(column) + 0.48) * body.width / 3)
                    let y = Int(body.minY + (CGFloat(row) + 0.5) * body.height / 2)
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                    let solid = color.alphaComponent > 0.7 && channels.max()! - channels.min()! > 0.3
                    XCTAssertEqual(solid, kind.blocks.contains(PieceBlock(x: column, y: 1 - row)), "\(kind.rawValue)：\(column),\(row)")
                }
            }
        }
        XCTAssertNotNil(bundle.url(forResource: "home-design-arrow", withExtension: "png"))
    }

}
