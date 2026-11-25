# 恢复空格开局与统计数字跳动

## 背景与目标

- 点击模式卡后，原生按钮保留键盘焦点，空格曾被按钮重复用于选择当前模式。辅助子窗口可见时，旧判断在开始按钮聚焦的分支也会吞掉快捷键。
- 恢复当前大厅统计数字的新消除反馈，沿用旧版的跳幅和节奏。

## 实现

- 主窗口的无修饰空格在已选模式或开始按钮聚焦时进入同一开局流程。事件仍按所属窗口分发，未选模式可以用空格选择，文本输入和各控件保留原有按键语义。
- 消除总数及真实增长的分类数字以单调时钟驱动独立跳动，在 0.42 秒内上移最多 6 点再回落。首次显示、重复快照、预算变化、换模式和重开归零按当前数值更新。
- 系统启用“减少动态效果”时显示静态数字。限时、限步两列统一为上方标签和下方数字留出跳动余量。

## 验证

- 开局测试使用 AppKit 原生焦点验证未选模式、已选模式、辅助窗口、文本输入、修饰键、长按及局中保护。
- 原生统计卡渲染验证真实增长的数字位移和回位，并在最小大厅对应的统计卡与 336 × 148 点尺寸验证限时及限步标签间距。
- 两种紧凑尺寸均通过五语言像素检查。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 全部 102 项通过。
- 手动验证可运行 `./run.sh`，点击限时或限步模式后按空格开始游戏，再交换方块形成三连并观察消除总数和对应分类数字。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 7bcb3c9daa82cdab45092bf76078e274324f40bd..ef986b032ae369a1cdf6fba36b5142f33d0653a9 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124223031-restore-space-start-and-stat-number-jumps.md` - 会话-38 起修复模式卡保留焦点时的空格开局，并恢复消除总数和变化分类数字的跳动。
 `workflow/20261124215116-raise-mode-card-icon-plates.md` - 会话-35 起给右侧四张游戏模式卡加入凸出上沿的斜面图标前层，含原生渲染与紧凑布局验证。
 `workflow/20261124212018-match-stat-plate-side-spacing.md` - 会话-32 起统一消除统计卡背板与前板左右斜边的水平错位，含原生像素回归及进度轨道留白校验。
 `workflow/20261124091725-animate-home-touch-bar-guide.md` - 会话-27 起将首页触控栏示意改为循环演示，包含竖直手指、蓝色滑动提示、相邻交换、三连消除和左侧补位。
@@ -106,6 +107,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对空格开局的主窗口焦点边界，或调整消除统计数字的跳动、归零及减少动态效果时，读取 `20261124223031-restore-space-start-and-stat-number-jumps.md`。
 - 需要调整右侧游戏模式卡的图标前层、立体侧沿、选中色或上沿留空时，读取 `20261124215116-raise-mode-card-icon-plates.md`。
 - 需要调整消除统计卡背板与前板的左右斜边间距或核对等距像素回归时，读取 `20261124212018-match-stat-plate-side-spacing.md`。
 - 需要调整首页触控栏演示的手势、交换、消除、补位、循环节奏或减少动态效果时，读取 `20261124091725-animate-home-touch-bar-guide.md`。
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index b539dd3b854532a920be0d4f59f2df6d9f8573c4..942f343566b7e32a830b3ff3d03d49c0c3edc857 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -192,11 +192,13 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
               event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
               let window = view.window, window.isKeyWindow, event.window === window,
               window.attachedSheet == nil, NSApp.modalWindow == nil else { return false }
-        if window.childWindows?.contains(where: { $0.isVisible }) == true {
-            return window.firstResponder === dashboard.startButton
+        let responder = window.firstResponder
+        // 点完模式后焦点还在卡上。已选卡的空格进入开局，未选卡仍可用空格选择。
+        let focusedStart = responder === dashboard.startButton || (responder as? HomeModeButton)?.selected == true
+        if !focusedStart {
+            if responder is NSTextView || responder is NSSlider || responder is NSButton { return false }
+            if window.childWindows?.contains(where: { $0.isVisible }) == true { return false }
         }
-        if window.firstResponder is NSTextView || window.firstResponder is NSPopUpButton || window.firstResponder is NSSlider { return false }
-        if let button = window.firstResponder as? NSButton, button !== dashboard.startButton { return false }
         // 游戏中也消费空格，避免焦点恰在“重新开始”按钮时被原生按钮意外激活。
         if event.isARepeat || controller.snapshot().isRunning || startSequence.isOpening { return true }
         startRound()
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 9b0b74fd5cfa698d6d72539ace2a35323f05598d..8e3d5b4829e6e0980ae8b36d0bf5ae3baf51f227 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -6,6 +6,7 @@ final class HomeChallengeHUDView: NSView {
     static let trailingInset: CGFloat = 3
     private static let rearOverhang: CGFloat = 0.08
     private static let rearTopInset: CGFloat = 45 / 636
+    private static let countJumpDuration: TimeInterval = 0.42
 
     static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
         max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
@@ -83,13 +84,27 @@ final class HomeChallengeHUDView: NSView {
     }
     private(set) var snapshot: GameSnapshot?
     private(set) var mode: HomeGameMode = .timed
+    private enum CountNumber: Hashable { case total, piece(PieceKind) }
+    private let animationClock: () -> TimeInterval
+    private let reducesMotion: () -> Bool
+    private var countJumpStarts: [CountNumber: TimeInterval] = [:]
+    private var countJumpTimer: Timer?
     var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
     override var isFlipped: Bool { true }
-    override init(frame: NSRect) {
+    init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
+         reducesMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
+        self.animationClock = clock
+        self.reducesMotion = reducesMotion
         super.init(frame: frame)
         setAccessibilityElement(true); setAccessibilityRole(.group)
     }
     required init?(coder: NSCoder) { nil }
+    deinit { countJumpTimer?.invalidate() }
+
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        if window == nil { stopCountAnimation() }
+    }
 
     private var showsBudget: Bool { mode != .free }
     private var budgetLabelKey: String {
@@ -114,6 +129,7 @@ final class HomeChallengeHUDView: NSView {
     }
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
+        updateCountAnimation(snapshot: snapshot, mode: mode)
         self.snapshot = snapshot; self.mode = mode
         var labels: [String] = []
         if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
@@ -126,6 +142,58 @@ final class HomeChallengeHUDView: NSView {
         needsDisplay = true
     }
 
+    /// 未传方块类型时读取总数的跳动偏移。
+    func numberJumpOffset(for kind: PieceKind? = nil) -> CGFloat {
+        let number = kind.map(CountNumber.piece) ?? .total
+        guard let start = countJumpStarts[number], !reducesMotion() else { return 0 }
+        let progress = (animationClock() - start) / Self.countJumpDuration
+        guard progress >= 0, progress < 1 else { return 0 }
+        return -6 * CGFloat(sin(.pi * progress))
+    }
+
+    private func updateCountAnimation(snapshot: GameSnapshot, mode: HomeGameMode) {
+        guard let previous = self.snapshot, self.mode == mode, previous.mode == snapshot.mode,
+              snapshot.isRunning || snapshot.isFinished, !(previous.isFinished && snapshot.isRunning),
+              snapshot.totalCleared >= previous.totalCleared, !reducesMotion() else {
+            stopCountAnimation()
+            return
+        }
+        let now = animationClock()
+        if snapshot.totalCleared > previous.totalCleared { countJumpStarts[.total] = now }
+        for kind in PieceKind.allCases {
+            let value = snapshot.clearedByKind[kind, default: 0]
+            let previousValue = previous.clearedByKind[kind, default: 0]
+            if value > previousValue {
+                countJumpStarts[.piece(kind)] = now
+            } else if value < previousValue {
+                countJumpStarts.removeValue(forKey: .piece(kind))
+            }
+        }
+        // 普通刷新仍更新快照，只有计数增长才设置新的跳动起点。
+        guard !countJumpStarts.isEmpty, countJumpTimer == nil, isCountAnimationVisible else { return }
+        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advanceCountAnimation() }
+        RunLoop.main.add(timer, forMode: .common)
+        countJumpTimer = timer
+    }
+
+    private var isCountAnimationVisible: Bool {
+        guard let window else { return false }
+        return window.isVisible && !window.isMiniaturized && !isHiddenOrHasHiddenAncestor
+    }
+
+    private func advanceCountAnimation() {
+        let now = animationClock()
+        countJumpStarts = countJumpStarts.filter { now - $0.value < Self.countJumpDuration }
+        if countJumpStarts.isEmpty || reducesMotion() || !isCountAnimationVisible { stopCountAnimation() }
+        needsDisplay = true
+    }
+
+    private func stopCountAnimation() {
+        countJumpStarts.removeAll()
+        countJumpTimer?.invalidate()
+        countJumpTimer = nil
+    }
+
     override func draw(_ dirtyRect: NSRect) {
         let surface = surfaceRect
         guard let snapshot, surface.width > 40, surface.height > 45 else { return }
@@ -189,7 +257,7 @@ final class HomeChallengeHUDView: NSView {
                               width: split - x - columnPadding, height: body.height, color: accent, alignment: .left)
             drawStackedMetric(String(snapshot.totalCleared), labelKey: "home.cleared_title", center: metricY,
                               x: split + columnPadding, width: right - split - columnPadding, height: body.height,
-                              color: HomeDashboardStyle.ink, alignment: .right)
+                              color: HomeDashboardStyle.ink, alignment: .right, numberOffset: numberJumpOffset())
             HomeDashboardStyle.line(from: NSPoint(x: split + separatorOffset, y: separatorTop),
                                     to: NSPoint(x: split - separatorOffset, y: separatorBottom), color: HomeDashboardStyle.border)
         } else {
@@ -201,21 +269,23 @@ final class HomeChallengeHUDView: NSView {
             let value = String(snapshot.totalCleared)
             let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth - 8,
                                                  preferred: max(24, 58 * face.typographyScale), minimum: 12, weight: .black)
-            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1, width: available - titleWidth, height: body.height),
+            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1 + numberJumpOffset(),
+                                    width: available - titleWidth, height: body.height),
                   size: size, weight: .black, alignment: .right)
         }
     }
 
     private func drawStackedMetric(_ value: String, labelKey: String, center: CGFloat, x: CGFloat, width: CGFloat,
-                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment) {
+                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment, numberOffset: CGFloat = 0) {
         let title = AchievementText.string(labelKey)
         let titleSize = GameLobbyStyle.fittedSize(title, width: width, preferred: min(13, height * 0.26),
                                                    minimum: 8, weight: .semibold)
         let valueSize = GameLobbyStyle.fittedSize(value, width: width, preferred: min(38, height * 0.59),
                                                    minimum: 11, weight: .heavy)
-        label(title, x: x, y: center - height * 0.24, width: width, size: titleSize, weight: .semibold,
+        // 两列使用相同的静止基线，给汇总数字的上跳留出间距。
+        label(title, x: x, y: center - height * 0.24 - 3, width: width, size: titleSize, weight: .semibold,
               color: HomeDashboardStyle.muted, alignment: alignment)
-        let number = NSRect(x: x, y: center - height * 0.39, width: width, height: height)
+        let number = NSRect(x: x, y: center - height * 0.39 + 3 + numberOffset, width: width, height: height)
         count(value, in: number, size: valueSize, weight: .heavy, color: color, alignment: alignment)
     }
 
@@ -236,7 +306,8 @@ final class HomeChallengeHUDView: NSView {
             HomeLobbyArtwork.drawPiece(kind, in: icon)
             let number = String(snapshot.clearedByKind[kind, default: 0])
             let numberX = icon.maxX + 12 * scale
-            let slot = NSRect(x: numberX, y: cell.minY, width: max(0, content.maxX - numberX), height: cell.height)
+            let slot = NSRect(x: numberX, y: cell.minY + numberJumpOffset(for: kind),
+                              width: max(0, content.maxX - numberX), height: cell.height)
             let size = GameLobbyStyle.fittedSize(number, width: slot.width, preferred: max(11, 21 * face.typographyScale),
                                                  minimum: 7, weight: .semibold)
             count(number, in: slot, size: size, weight: .semibold)
diff --git a/Tests/GameStartSequenceTests.swift b/Tests/GameStartSequenceTests.swift
index 4f31723d8210ce4736d7bae65ec7af5d329734f0..848f4354dce861eb4052304892ca6ef1f2f241d0 100644
--- a/Tests/GameStartSequenceTests.swift
+++ b/Tests/GameStartSequenceTests.swift
@@ -238,11 +238,20 @@ final class GameStartSequenceTests: AchievementTestCase {
         let window = StartKeyTestWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
         window.isReleasedWhenClosed = false; window.contentView = controller.view
         defer { window.close() }
-        func key(modifiers: NSEvent.ModifierFlags = [], repeatKey: Bool = false) throws -> NSEvent {
+        func key(modifiers: NSEvent.ModifierFlags = [], repeatKey: Bool = false, target: NSWindow? = nil) throws -> NSEvent {
             try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
-                                          windowNumber: window.windowNumber, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeatKey, keyCode: 49))
+                                          windowNumber: (target ?? window).windowNumber, context: nil,
+                                          characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeatKey, keyCode: 49))
         }
         XCTAssertFalse(controller.handleStartKeyEvent(try key(modifiers: .command)))
+        let dashboard = try XCTUnwrap(controller.view as? HomeDashboardView)
+        let timed = try XCTUnwrap(dashboard.modePanel.subviews.compactMap { $0 as? HomeModeButton }.first { $0.mode == .timed })
+        XCTAssertTrue(window.makeFirstResponder(timed))
+        XCTAssertTrue(window.firstResponder === timed)
+        XCTAssertFalse(controller.handleStartKeyEvent(try key()), "未选模式应保留原生空格选择")
+        timed.performClick(nil)
+        XCTAssertTrue(timed.selected)
+        XCTAssertTrue(window.firstResponder === timed)
         XCTAssertTrue(controller.handleStartKeyEvent(try key()))
         let preview = board.tiles()
         XCTAssertFalse(board.snapshot().isRunning)
@@ -255,7 +264,28 @@ final class GameStartSequenceTests: AchievementTestCase {
         controller.view.addSubview(editor); window.makeFirstResponder(editor)
         XCTAssertFalse(controller.handleStartKeyEvent(try key()), "文字输入中的空格不能被开局快捷键截获")
         window.makeFirstResponder(nil); editor.removeFromSuperview()
+
+        // 面板事件归面板处理，主窗口明确聚焦开局键或已选模式卡时仍可开局。
+        controller.selectMode(.free)
+        let rules = HomeUtilityPanel(page: "rules", store: ModeRecordStore(defaults: defaults))
+        let panel = try XCTUnwrap(rules.window)
+        rules.present(from: window)
+        XCTAssertTrue(panel.isVisible)
+        XCTAssertFalse(controller.handleStartKeyEvent(try key(target: panel)))
+        XCTAssertFalse(controller.handleStartKeyEvent(try key()))
+        XCTAssertTrue(window.makeFirstResponder(dashboard.startButton))
+        XCTAssertTrue(window.firstResponder === dashboard.startButton)
+        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
+        XCTAssertTrue(controller.startSequence.isOpening)
+        controller.selectMode(.timed)
+        XCTAssertTrue(window.makeFirstResponder(timed))
+        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
+        XCTAssertTrue(controller.startSequence.isOpening)
+        window.removeChildWindow(panel)
+        rules.close()
+
         controller.selectMode(.moves)
+        window.makeFirstResponder(nil)
         XCTAssertTrue(controller.startSequence.beginDrag())
         controller.startSequence.updateDrag(progress: 0.4)
         let partialPreview = board.tiles()
diff --git a/Tests/HomeChallengeHUDAnimationTests.swift b/Tests/HomeChallengeHUDAnimationTests.swift
new file mode 100644
index 0000000000000000000000000000000000000000..08e14640d0c80546c113ee0a4ae3915f1e7ecbb1
--- /dev/null
+++ b/Tests/HomeChallengeHUDAnimationTests.swift
@@ -0,0 +1,200 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class HomeChallengeHUDAnimationTests: XCTestCase {
+    func testTotalAndChangedClassificationsJumpInTheRenderedCard() throws {
+        _ = NSApplication.shared
+        var now: TimeInterval = 100
+        let hud = makeHUD(clock: { now })
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
+        now += 0.21
+        assertResting(hud)
+
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]), mode: .free)
+        let baseline = try image(of: hud)
+        now += 0.21
+        XCTAssertEqual(hud.numberJumpOffset(), -6, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), -6, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .clevelandZ), -6, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .blueRicky), 0)
+        XCTAssertEqual(hud.numberJumpOffset(for: .rhodeIslandZ), 0)
+        let peak = try image(of: hud)
+
+        let surface = hud.surfaceRect
+        let total = NSRect(x: surface.minX + surface.width * 0.73, y: surface.minY + surface.height * 53 / 186,
+                           width: surface.width * 0.18, height: surface.height * 78 / 186)
+        let cells = hud.breakdownCellRects
+        let typeScale = min(surface.width / 636, surface.height / 186)
+        let regions = cells.map { cell in
+            let cut = HomeDashboardStyle.edgeOffset(for: cell.height)
+            let padding = min(24, (cell.width - cut) * 0.18)
+            let numberX = cell.minX + cut / 2 + padding + 54 * typeScale
+            return NSRect(x: numberX, y: cell.minY + 2, width: cell.maxX - cut / 2 - padding - numberX, height: cell.height - 4)
+        }
+        let areas = [total] + regions
+        // 直接比较同一份数字的亮色像素，只允许总数和两类新消除方块上移。
+        for (index, area) in areas.enumerated() {
+            let before = try digitCenter(in: baseline, area: area, viewSize: hud.bounds.size)
+            let after = try digitCenter(in: peak, area: area, viewSize: hud.bounds.size)
+            let jump: CGFloat = [0, 1, 3].contains(index) ? -6 : 0
+            XCTAssertEqual(after - before, jump, accuracy: 0.75)
+        }
+
+        now += 0.23
+        assertResting(hud)
+        let settled = try image(of: hud)
+        for area in areas {
+            let before = try digitCenter(in: baseline, area: area, viewSize: hud.bounds.size)
+            XCTAssertEqual(try digitCenter(in: settled, area: area, viewSize: hud.bounds.size), before, accuracy: 0.01)
+        }
+    }
+
+    func testBudgetAndRepeatedRefreshesDoNotRestartJumps() {
+        var now: TimeInterval = 100
+        let hud = makeHUD(clock: { now })
+        hud.refresh(snapshot: snapshot(.moves, [:], movesLeft: 30), mode: .moves)
+        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 29), mode: .moves)
+        now += 0.12
+        let active = hud.numberJumpOffset()
+        XCTAssertLessThan(active, 0)
+        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 28), mode: .moves)
+        XCTAssertEqual(hud.budgetText, "28")
+        XCTAssertEqual(hud.numberJumpOffset(), active, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), active, accuracy: 0.001)
+
+        // 最后一手的实际消除也要显示；只有这次新增的数字会重新计时。
+        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3, .blueRicky: 3], movesLeft: 0, finished: true), mode: .moves)
+        XCTAssertEqual(hud.numberJumpOffset(), 0, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), active, accuracy: 0.001)
+        now += 0.21
+        XCTAssertEqual(hud.numberJumpOffset(), -6, accuracy: 0.001)
+        XCTAssertEqual(hud.numberJumpOffset(for: .blueRicky), -6, accuracy: 0.001)
+        now += 0.23
+        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3, .blueRicky: 3], movesLeft: 0, finished: true), mode: .moves)
+        assertResting(hud)
+
+        hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 59), mode: .timed)
+        hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 58), mode: .timed)
+        now += 0.21
+        XCTAssertEqual(hud.budgetText, "00:58")
+        assertResting(hud)
+    }
+
+    func testCompactChallengeTotalLeavesClearanceBelowItsLabelAtPeak() throws {
+        _ = NSApplication.shared
+        let language = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(language) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let lobby = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
+        lobby.layoutSubtreeIfNeeded()
+        for size in [lobby.challengeHUD.bounds.size, NSSize(width: 336, height: 148)] {
+            for mode in [HomeGameMode.timed, .moves] {
+                var now: TimeInterval = 100
+                let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size), clock: { now }, reducesMotion: { false })
+                hud.refresh(snapshot: snapshot(mode, [.orangeRicky: 12], movesLeft: 30, timeLeft: 43), mode: mode)
+                hud.refresh(snapshot: snapshot(mode, [.orangeRicky: 15], movesLeft: 29, timeLeft: 42), mode: mode)
+                let baseline = try image(of: hud)
+                now += 0.21
+                let peak = try image(of: hud)
+
+                let surface = hud.surfaceRect
+                let area = NSRect(x: surface.minX + surface.width * 0.55, y: surface.minY + surface.height * 53 / 186,
+                                  width: surface.width * 0.37, height: surface.height * 78 / 186)
+                func labelBottom(in bitmap: NSBitmapImageRep) throws -> CGFloat {
+                    // 标签的蓝灰笔画比近白的汇总数字色差更大。
+                    try XCTUnwrap(inkRows(in: bitmap, area: area, viewSize: size) { pixel in
+                        pixel.redComponent > 0.5 && pixel.greenComponent - pixel.redComponent > 0.04 &&
+                            pixel.blueComponent - pixel.greenComponent > 0.04
+                    }.max())
+                }
+                let baselineTop = try XCTUnwrap(inkRows(in: baseline, area: area, viewSize: size).min())
+                let peakTop = try XCTUnwrap(inkRows(in: peak, area: area, viewSize: size).min())
+                let label = try labelBottom(in: baseline)
+                XCTAssertEqual(try labelBottom(in: peak), label, accuracy: 0.01)
+                XCTAssertEqual(baselineTop - peakTop, 6, accuracy: 0.75)
+                XCTAssertGreaterThanOrEqual(peakTop - label, 2, "\(mode.key) ／ \(size) 的总数在跳峰处仍应与标签留有间距")
+            }
+        }
+    }
+
+    func testResetModeChangeAndReducedMotionKeepDigitsAtRest() {
+        var now: TimeInterval = 100
+        var reducedMotion = false
+        let hud = makeHUD(clock: { now }, reducesMotion: { reducedMotion })
+        hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
+        now += 0.21
+        XCTAssertLessThan(hud.numberJumpOffset(), 0)
+        hud.refresh(snapshot: snapshot(.free, [:], running: false), mode: .free)
+        XCTAssertEqual(hud.snapshot?.totalCleared, 0)
+        assertResting(hud)
+
+        hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
+        hud.refresh(snapshot: snapshot(.free, [.blueRicky: 3]), mode: .free)
+        now += 0.21
+        XCTAssertLessThan(hud.numberJumpOffset(for: .blueRicky), 0)
+        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 9]), mode: .timed)
+        now += 0.21
+        assertResting(hud)
+
+        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 12]), mode: .timed)
+        now += 0.12
+        XCTAssertLessThan(hud.numberJumpOffset(), 0)
+        reducedMotion = true
+        assertResting(hud)
+        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 15]), mode: .timed)
+        XCTAssertEqual(hud.snapshot?.totalCleared, 15)
+        now += 0.12
+        assertResting(hud)
+        reducedMotion = false
+        assertResting(hud)
+    }
+
+    private func snapshot(_ mode: HomeGameMode, _ counts: [PieceKind: Int], movesLeft: Int? = nil,
+                          timeLeft: TimeInterval? = nil, running: Bool = true, finished: Bool = false) -> GameSnapshot {
+        GameSnapshot(mode: mode.gameMode, elapsedTime: 0, remainingTime: timeLeft, remainingSwaps: movesLeft,
+                     isRunning: running && !finished, isFinished: finished, clearedByKind: counts)
+    }
+
+    private func makeHUD(clock: @escaping () -> TimeInterval, reducesMotion: @escaping () -> Bool = { false }) -> HomeChallengeHUDView {
+        HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: 692, height: 196), clock: clock, reducesMotion: reducesMotion)
+    }
+
+    private func assertResting(_ hud: HomeChallengeHUDView, file: StaticString = #filePath, line: UInt = #line) {
+        XCTAssertEqual(hud.numberJumpOffset(), 0, file: file, line: line)
+        for kind in PieceKind.allCases {
+            XCTAssertEqual(hud.numberJumpOffset(for: kind), 0, file: file, line: line)
+        }
+    }
+
+    private func image(of hud: HomeChallengeHUDView) throws -> NSBitmapImageRep {
+        hud.needsDisplay = true
+        let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: hud.bounds))
+        hud.cacheDisplay(in: hud.bounds, to: bitmap)
+        return bitmap
+    }
+
+    private func digitCenter(in bitmap: NSBitmapImageRep, area: NSRect, viewSize: NSSize) throws -> CGFloat {
+        let rows = inkRows(in: bitmap, area: area, viewSize: viewSize)
+        XCTAssertFalse(rows.isEmpty, "应能找到原生数字笔画")
+        return rows.reduce(0, +) / CGFloat(max(1, rows.count))
+    }
+
+    private func inkRows(in bitmap: NSBitmapImageRep, area: NSRect, viewSize: NSSize,
+                         matches: (NSColor) -> Bool = { min($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.75 }) -> [CGFloat] {
+        let scaleX = CGFloat(bitmap.pixelsWide) / viewSize.width
+        let scaleY = CGFloat(bitmap.pixelsHigh) / viewSize.height
+        let columns = Int(ceil(area.minX * scaleX))..<Int(floor(area.maxX * scaleX))
+        let rows = Int(ceil(area.minY * scaleY))..<Int(floor(area.maxY * scaleY))
+        var hits: [CGFloat] = []
+        for y in rows {
+            for x in columns {
+                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
+                      color.alphaComponent > 0.85, matches(color) else { continue }
+                hits.append(CGFloat(y) / scaleY)
+            }
+        }
+        return hits
+    }
+}
```
