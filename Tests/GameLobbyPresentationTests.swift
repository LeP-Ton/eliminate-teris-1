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
                        XCTAssertEqual(home.challengeHUD.isHidden, !running || mode == .free)
                        XCTAssertEqual(home.stats.snapshot?.totalCleared, running ? 42 : 0)
                        XCTAssertTrue(home.bounds.contains(home.challengeHUD.frame))
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
        try export(home, name: "lobby-finished")
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
