import Cocoa
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
        board.configure(mode: HomeGameMode.speedRun.gameMode)
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        XCTAssertFalse(board.snapshot().isRunning)
    }

    func testFixedModesFinishAtSixtySecondsAndThreeHundredPoints() {
        var now = date
        let board = board(now: { now })
        board.configure(mode: HomeGameMode.scoreAttack.gameMode)
        board.startRound()
        now = date.addingTimeInterval(59.9)
        board.tick()
        XCTAssertFalse(board.snapshot().isFinished)
        now = date.addingTimeInterval(60)
        board.tick()
        XCTAssertTrue(board.snapshot().isFinished)
        board.configure(mode: HomeGameMode.speedRun.gameMode)
        board.startRound()
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().score, 300)
        XCTAssertTrue(board.snapshot().isFinished)
        let final = board.snapshot().clearedByKind
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.snapshot().clearedByKind, final)
    }

    func testHomeButtonsUseFixedRulesAndLiveStats() throws {
        _ = NSApplication.shared
        let board = board(now: { self.date })
        let records = ModeRecordStore(defaults: defaults)
        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false)
        let view = controller.view
        let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.primary })
        let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeSessionStatsView }.first)
        XCTAssertFalse(board.snapshot().isRunning)
        start.performClick(nil)
        XCTAssertTrue(board.snapshot().isRunning)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
        let free = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .free })
        free.performClick(nil)
        XCTAssertEqual(stats.snapshot?.totalCleared, 30, "点击已选模式不应重置本局")
        let speed = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .speedRun })
        speed.performClick(nil)
        XCTAssertEqual(board.snapshot().targetScore, 300)
        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
        start.performClick(nil)
        board.performSwap(from: 2, to: 3)
        XCTAssertTrue(board.snapshot().isFinished)
        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
        let finished = try XCTUnwrap(records.records(for: .speedRun, detailValue: 300).first)
        XCTAssertEqual(finished.elapsedTime, 0)
        for _ in 0..<3 { board.tick() }
        XCTAssertEqual(records.records(for: .speedRun, detailValue: 300).first?.id, finished.id)
        XCTAssertTrue(descendants(view).allSatisfy { !($0 is NSPopUpButton) })
        let score = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .scoreAttack })
        score.performClick(nil)
        XCTAssertEqual(board.snapshot().remainingTime, 60)
        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
    }

    func testHomeRendersAllModesLanguagesAndWindowSizes() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        defaults.set(["version": 1, "unlocked": [1, 3, 4, 7], "metrics": [:]], forKey: AchievementsManager.storageKey)
        let progress = AchievementsManager(defaults: defaults)
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            for mode in HomeGameMode.allCases {
                let snapshot = GameSnapshot(mode: mode.gameMode, score: 210, elapsedTime: 12, remainingTime: mode == .scoreAttack ? 48 : nil,
                                            targetScore: mode == .speedRun ? 300 : nil, isRunning: true, isFinished: false,
                                            clearedByKind: [.orangeRicky: 3, .blueRicky: 9, .clevelandZ: 6, .rhodeIslandZ: 3])
                for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1440, height: 940)] {
                    home.setFrameSize(size)
                    home.refresh(snapshot: snapshot, mode: mode, manager: progress)
                    home.layoutSubtreeIfNeeded()
                    XCTAssertEqual(home.stats.snapshot?.totalCleared, 21)
                    for button in home.subviews.compactMap({ $0 as? HomeButton }) {
                        XCTAssertTrue(home.bounds.contains(button.frame), "\(language.rawValue): \(button.frame)")
                        XCTAssertGreaterThan(button.frame.height, 30)
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
            panel.refresh(mode: .speedRun, volume: 0.4)
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
