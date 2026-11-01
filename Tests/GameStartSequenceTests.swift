import Cocoa
import ImageIO
import XCTest
@testable import EliminateTeris1

private final class StartKeyTestWindow: NSWindow {
    // 不激活测试应用或挂载真实 Touch Bar，只模拟主窗口的键盘路由条件。
    override var isKeyWindow: Bool { true }
}

final class GameStartSequenceTests: AchievementTestCase {
    private var animationTime: TimeInterval = 0
    private var gameTime = Date(timeIntervalSince1970: 1_000_000)

    private func fixture(mode: GameMode = .timed(duration: 60), columns: Int = 4) -> (GameBoardController, GameStartSequence, GameTouchBarView) {
        _ = NSApplication.shared
        // 使用交替补位保证结算不会因无限同色补位而无法结束。
        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
        let board = GameBoardController(columns: columns, achievements: manager, now: { self.gameTime }) { _ in
            var index = 0
            let fill = [c, d, c]
            let tail = (0..<columns - 4).map { $0.isMultiple(of: 2) ? c : d }
            return GameState(columns: columns, initialKinds: [a, a, b, a] + tail) {
                defer { index += 1 }
                return fill[index % fill.count]
            }
        }
        board.configure(mode: mode)
        let sequence = GameStartSequence(board: board, clock: { self.animationTime }, automaticallyAnimates: false)
        sequence.reducesMotion = { false }
        let view = GameTouchBarView(columnRange: 0..<columns, controller: board, startSequence: sequence)
        view.frame = NSRect(x: 0, y: 0, width: 1085, height: 30)
        return (board, sequence, view)
    }

    private func point(_ progress: CGFloat, in view: GameTouchBarView) -> NSPoint {
        NSPoint(x: 4 + (view.bounds.width - 8 - view.startThumbRect.width) * progress + view.startThumbRect.width / 2, y: 15)
    }
    private func advance(_ sequence: GameStartSequence, by seconds: TimeInterval) {
        animationTime += seconds; sequence.advanceAnimation()
    }
    private func image(_ view: NSView) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    func testIdleRendersVisibleSliderWithoutPlayableTiles() throws {
        let (board, sequence, view) = fixture()
        let pixels = try image(view)
        XCTAssertTrue(view.hasDrawnVisibleContent, "待机滑轨也是健康检查认可的有效内容")
        XCTAssertEqual(sequence.phase, .waiting)
        XCTAssertFalse(board.snapshot().isRunning)
        let scale = CGFloat(pixels.pixelsWide) / view.bounds.width
        var colored = 0
        for y in stride(from: 0, to: pixels.pixelsHigh, by: 2) {
            for x in stride(from: Int(65 * scale), to: pixels.pixelsWide, by: 2) {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if max(color.redComponent, color.greenComponent, color.blueComponent) - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.2 { colored += 1 }
            }
        }
        XCTAssertEqual(colored, 0, "待机时滑块右侧不应提前展示彩色棋盘")
    }

    func testAutomaticOpeningPreservesPreviewAndStartsClockAtCompletion() {
        let (board, sequence, _) = fixture()
        XCTAssertTrue(sequence.requestAutomaticStart())
        let preview = board.tiles()
        XCTAssertFalse(sequence.requestAutomaticStart(), "重复开始不能重新生成棋盘")
        gameTime = gameTime.addingTimeInterval(20)
        advance(sequence, by: 0.2)
        XCTAssertGreaterThan(sequence.progress, 0)
        XCTAssertLessThan(sequence.progress, 1)
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertEqual(board.snapshot().remainingTime, 60)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.tiles(), preview)
        advance(sequence, by: 0.3)
        XCTAssertEqual(sequence.phase, .playing)
        XCTAssertEqual(board.tiles(), preview, "显现的棋盘应与正式开局一致")
        XCTAssertEqual(board.snapshot().elapsedTime, 0)
        gameTime = gameTime.addingTimeInterval(5)
        XCTAssertEqual(board.snapshot().remainingTime, 55)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 3)
    }

    func testPartialDragAndCancellationReturnWithoutStarting() {
        let (board, sequence, view) = fixture()
        XCTAssertTrue(view.beginStartInteraction(pointer: "finger", at: point(0, in: view)))
        _ = view.moveStartInteraction(pointer: "finger", to: point(0.5, in: view))
        XCTAssertEqual(sequence.phase, .dragging)
        XCTAssertEqual(sequence.progress, 0.5, accuracy: 0.001)
        _ = view.endStartInteraction(pointer: "finger", at: point(0.5, in: view))
        XCTAssertEqual(sequence.phase, .returning)
        advance(sequence, by: 0.3)
        XCTAssertEqual(sequence.phase, .waiting)
        XCTAssertEqual(sequence.progress, 0)
        XCTAssertFalse(board.snapshot().isRunning)
        _ = view.beginStartInteraction(pointer: "finger", at: point(0, in: view))
        _ = view.moveStartInteraction(pointer: "finger", to: point(0.6, in: view))
        _ = view.endStartInteraction(pointer: "finger", at: point(1, in: view), cancelled: true)
        advance(sequence, by: 0.3)
        XCTAssertEqual(sequence.progress, 0)
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertEqual(manager.progress(for: AchievementDefinition.all[19]).current, 0)
    }

    func testLaunchTouchesStayConsumedUntilEveryFingerIsReleased() {
        let (board, sequence, view) = fixture(mode: .free)
        _ = view.beginStartInteraction(pointer: "first", at: point(0, in: view))
        _ = view.beginStartInteraction(pointer: "second", at: point(0.3, in: view))
        _ = view.moveStartInteraction(pointer: "first", to: point(1, in: view))
        XCTAssertEqual(sequence.phase, .opening)
        advance(sequence, by: 0.2)
        let initial = board.tiles()
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertTrue(view.moveStartInteraction(pointer: "first", to: point(0.8, in: view)))
        XCTAssertTrue(view.endStartInteraction(pointer: "first", at: point(0.8, in: view)))
        XCTAssertTrue(view.beginStartInteraction(pointer: "third", at: point(0.5, in: view)), "仍有开局手指时，新触摸也不能穿透")
        _ = view.endStartInteraction(pointer: "third", at: point(0.5, in: view))
        _ = view.endStartInteraction(pointer: "second", at: point(0.3, in: view))
        XCTAssertEqual(board.tiles(), initial)
        XCTAssertFalse(view.beginStartInteraction(pointer: "fresh", at: point(0.5, in: view)), "全部抬手后，新的触摸才交给棋盘")
        board.handleTap(at: 2); board.handleTap(at: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 3)
    }

    func testOutsideTouchesDoNotStartAndButtonContinuesPartialDrag() {
        let (board, sequence, view) = fixture()
        _ = view.beginStartInteraction(pointer: "outside", at: point(0.5, in: view))
        _ = view.endStartInteraction(pointer: "outside", at: point(0, in: view))
        XCTAssertEqual(sequence.phase, .waiting)
        _ = view.beginStartInteraction(pointer: "drag", at: point(0, in: view))
        _ = view.moveStartInteraction(pointer: "drag", to: point(0.4, in: view))
        let preview = board.tiles()
        XCTAssertTrue(sequence.requestAutomaticStart())
        advance(sequence, by: 0.5)
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertEqual(board.tiles(), preview)
        XCTAssertTrue(view.endStartInteraction(pointer: "drag", at: point(0.4, in: view)))
        XCTAssertFalse(board.isSelected(0))
    }

    func testDisplayRefreshKeepsOpeningAndFocusLossCancelsIt() throws {
        let (board, sequence, view) = fixture()
        sequence.requestAutomaticStart(); advance(sequence, by: 0.2)
        let progress = sequence.progress
        view.prepareForDisplay()
        XCTAssertEqual(sequence.progress, progress)
        _ = try image(view)
        XCTAssertTrue(view.hasDrawnVisibleContent)
        view.cancelInteractions()
        advance(sequence, by: 10)
        XCTAssertEqual(sequence.phase, .waiting)
        XCTAssertFalse(board.snapshot().isRunning)
    }

    func testModeChangeInvalidatesOldOpeningAndReducedMotionStartsImmediately() {
        let (board, sequence, _) = fixture()
        sequence.requestAutomaticStart()
        sequence.reset(notify: false); board.configure(mode: .moves(limit: 30))
        advance(sequence, by: 1)
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertEqual(sequence.phase, .waiting)
        sequence.reducesMotion = { true }
        sequence.requestAutomaticStart()
        XCTAssertEqual(sequence.phase, .playing)
        XCTAssertEqual(sequence.progress, 1)
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertEqual(board.snapshot().elapsedTime, 0)
    }

    func testMoveChallengeIgnoresOpeningTimeAndManualRestartSavesEachRound() throws {
        _ = NSApplication.shared
        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
        let board = GameBoardController(columns: 4, achievements: manager, now: { self.gameTime }) { _ in
            var index = 0
            let fill = Array(repeating: a, count: 27) + [c, d, c]
            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
                defer { index += 1 }
                return fill[index]
            }
        }
        let records = ModeRecordStore(defaults: defaults)
        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false,
                                            startClock: { self.animationTime })
        _ = controller.view
        // 使用确定补位序列，完整用完 30 次交换，验证正式限步规则。
        controller.selectMode(.moves)
        controller.startSequence.reducesMotion = { false }
        let baseline = Set(records.records(for: .moves, detailValue: 30).map(\.id))
        for _ in 0..<2 {
            XCTAssertTrue(controller.startSequence.beginDrag())
            gameTime = gameTime.addingTimeInterval(20)
            controller.startSequence.updateDrag(progress: 1)
            advance(controller.startSequence, by: 0.2)
            XCTAssertEqual(board.snapshot().elapsedTime, 0)
            gameTime = gameTime.addingTimeInterval(2)
            board.performSwap(from: 2, to: 3)
            for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
            XCTAssertTrue(board.snapshot().isFinished)
            XCTAssertEqual(board.snapshot().elapsedTime, 2)
        }
        let newEntries = records.records(for: .moves, detailValue: 30).filter { !baseline.contains($0.id) }
        XCTAssertEqual(newEntries.count, 2, "滑动再来一局也应正常保存新的结算记录")
        XCTAssertTrue(newEntries.allSatisfy { $0.elapsedTime == 2 })
    }

    func testMouseDragAndAccessibilityUseTheSameOpening() throws {
        let (board, sequence, view) = fixture()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1085, height: 30), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        defer { window.close() }
        func mouse(_ type: NSEvent.EventType, _ progress: CGFloat) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: view.convert(point(progress, in: view), to: nil), modifierFlags: [],
                                            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try mouse(.leftMouseDown, 0))
        view.mouseDragged(with: try mouse(.leftMouseDragged, 1))
        advance(sequence, by: 0.2)
        view.mouseUp(with: try mouse(.leftMouseUp, 1))
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertFalse((0..<4).contains { board.isSelected($0) })
        sequence.reset(notify: false); board.configure(mode: .free)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertFalse(view.accessibilityPerformPress(), "辅助功能重复激活不能重开动画")
        advance(sequence, by: 0.5)
        XCTAssertTrue(board.snapshot().isRunning)
    }

    func testSpaceOnlyStartsFromEligibleMainWindowAndDoesNotRestartRunningRound() throws {
        _ = NSApplication.shared
        let (board, _, _) = fixture()
        let controller = GameViewController(achievements: manager, records: ModeRecordStore(defaults: defaults), board: board,
                                            audioEnabled: false, startClock: { self.animationTime })
        controller.startSequence.reducesMotion = { false }
        let window = StartKeyTestWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = controller.view
        defer { window.close() }
        func key(modifiers: NSEvent.ModifierFlags = [], repeatKey: Bool = false) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                                          windowNumber: window.windowNumber, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeatKey, keyCode: 49))
        }
        XCTAssertFalse(controller.handleStartKeyEvent(try key(modifiers: .command)))
        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
        let preview = board.tiles()
        XCTAssertFalse(board.snapshot().isRunning)
        XCTAssertTrue(controller.handleStartKeyEvent(try key(repeatKey: true)))
        advance(controller.startSequence, by: 1)
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
        XCTAssertEqual(board.tiles(), preview)
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        controller.view.addSubview(editor); window.makeFirstResponder(editor)
        XCTAssertFalse(controller.handleStartKeyEvent(try key()), "文字输入中的空格不能被开局快捷键截获")
        window.makeFirstResponder(nil); editor.removeFromSuperview()
        controller.selectMode(.moves)
        XCTAssertTrue(controller.startSequence.beginDrag())
        controller.startSequence.updateDrag(progress: 0.4)
        let partialPreview = board.tiles()
        XCTAssertTrue(controller.handleStartKeyEvent(try key()), "空格也能接续尚未完成的滑动")
        advance(controller.startSequence, by: 1)
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertEqual(board.tiles(), partialPreview)
    }

    func testFiveLanguagesAndExportRealStartAnimation() throws {
        let (_, sequence, view) = fixture(mode: .free, columns: 16)
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            XCTAssertNotEqual(Localizer.shared.string("touchbar.slide_start"), "touchbar.slide_start")
            view.refreshLanguage()
            XCTAssertEqual(view.accessibilityLabel(), Localizer.shared.string("touchbar.slide_start"))
            for width: CGFloat in [400, 1085] { view.setFrameSize(NSSize(width: width, height: 30)); _ = try image(view) }
        }
        Localizer.shared.setLanguage(.chineseSimplified)
        view.setFrameSize(NSSize(width: 1085, height: 30))
        let idle = try image(view)
        try XCTUnwrap(idle.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start-idle.png"))
        _ = view.beginStartInteraction(pointer: "preview", at: point(0, in: view))
        _ = view.moveStartInteraction(pointer: "preview", to: point(0.5, in: view))
        let half = try image(view)
        _ = view.endStartInteraction(pointer: "preview", at: point(0.5, in: view))
        advance(sequence, by: 0.3)
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start.gif")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(destinationURL as CFURL, "com.compuserve.gif" as CFString, 40, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<40 {
            if frame == 8 { sequence.requestAutomaticStart() }
            if frame >= 8 { advance(sequence, by: 0.04) }
            let cgImage = try XCTUnwrap(try image(view).cgImage)
            CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let playing = try image(view)
        let samples = [("等待开始", idle), ("滑动显现", half), ("正式游戏", playing)]
        let sheet = NSImage(size: NSSize(width: 1085, height: 180), flipped: true) { bounds in
            HomeStyle.background.setFill(); bounds.fill()
            for (index, sample) in samples.enumerated() {
                let y = CGFloat(index) * 60
                HomeStyle.text(sample.0, in: NSRect(x: 8, y: y + 4, width: 300, height: 18), size: 12, weight: .semibold)
                if let cgImage = sample.1.cgImage {
                    NSImage(cgImage: cgImage, size: NSSize(width: 1085, height: 30)).draw(in: NSRect(x: 0, y: y + 26, width: 1085, height: 30),
                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                }
            }
            return true
        }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(sheet.tiffRepresentation))?.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start-states.png"))
    }
}
