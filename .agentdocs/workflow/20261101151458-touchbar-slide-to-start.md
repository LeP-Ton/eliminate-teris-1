# Touch Bar 滑动开局、自动开场与空格入口

## 背景与目标
- 对应会话-130，按会话-126 确定的方案 1 实现。
- 原先未开始时已经展示彩色棋盘，仅由控制器拒绝操作，容易让人误判状态。
- 待机展示左侧开局滑块及向右滑动提示；拖动时方块从左向右显现，未完成松手回弹。主窗口按钮和空格触发同一套自动开场。
- 基线为已提交并推送的 `176f0d8`。本轮未提交、未推送。

## 关键设计与边界
- `GameStartSequence` 管理等待、拖动、回弹、自动开场、游戏五种状态；动画时钟可注入，运行时按 60 Hz 更新。
- `GameBoardController.prepareRound` 生成棋盘并清零本局，但不计时、不接受交换；`beginPreparedRound` 沿用预览的 tile id，在开场完成后设置真正起始时间。原 `startRound` 保留立即开始语义供逻辑调用。
- 滑块只在按钮区域开始接管手势；轨道其他位置的触摸不会启动游戏。拖动进度到 98% 后吸附到终点，最后过渡约 0.12 秒；未完成回弹约 0.22 秒；主按钮/空格的完整自动开场约 0.45 秒。
- 开局指针使用独立消费集合，多指或中途新增的指针均需抬起，才允许下一次新触摸进入棋盘。开局释放不会被解释为选中或交换。
- 鼠标拖动与真实 NSTouch 事件使用同一输入适配路径；辅助功能激活也进入同一开场流程。
- 无修饰空格限定在主窗口，文本输入、菜单、辅助面板保留原生事件；长按与游戏中空格不会重复开局或触发原生重新开始按钮。部分滑动也可由空格或主按钮接续完成。
- 切换模式、应用失活和主窗口失焦会取消尚未完成的开场，旧动画不能在后台启动新局。正常游戏中沿用原有失活计时策略。
- 维持私有 system modal 展示链路；待机滑轨也作为健康检查的可见内容，首次/二次/三次挂载刷新不重置开场状态或进度。
- 正常游戏的 16 格绘制与三阶段消除动画沿用原实现。重复点击开始不会反复生成棋盘；手动再来一局继续正常保存新一局记录。
- 五种语言补齐待机、开场和触控栏提示；切换语言立即刷新触控栏文字和辅助功能标签。
- 系统减少动态效果开启时跳过自动过渡，仍保证计时边界与输入隔离。
- 根 `AGENTS.md` 已记录统一开局生命周期的核心认知；中文 README 与测试预览入口说明同步更新。

## 阶段与 TODO
- [x] 分离准备棋盘与正式开局，保留既有直接调用接口。
- [x] 接入三种入口与同一套可取消开场状态机。
- [x] 实现待机滑块、显现、回弹、触摸隔离与辅助功能。
- [x] 接入主窗口空格、长按保护、焦点与模式取消。
- [x] 验证私有 modal 刷新与待机健康检查兼容。
- [x] 补齐五语言，新增 11 项专项并更新旧首页断言。
- [x] 检查实际预览、完整回归及文档增量留痕。

## 测试方法与结果
- 编译：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`，通过。
- 完整回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，2026-11-01 15:10:21 完成，72 项通过，0 失败。
- 最后补充即时语言刷新后运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameStartSequenceTests|HomeDashboardTests|AchievementLocalizationTests'`，2026-11-01 15:12:05 完成，18 项通过，0 失败。
- 静态检查：`git diff --check`，通过；新增源码也检查尾部空格。

### TC-001 待机视觉
- 读取实际渲染像素，确认滑块右侧没有彩色棋盘；滑轨绘制可被健康检查认可。
- 结果：通过。

### TC-002 准备/计时边界
- 开场期间推进游戏时钟 20 秒，竞分仍为 60 秒；交换无效。
- 完成开场后 tile id 与预览一致，随后推进 5 秒才剩 55 秒；正式交换按原规则得 30 分。
- 结果：通过。

### TC-003 手势回弹与多指隔离
- 滑到半程松手、取消触摸均回到待机，不计局数；轨道外触摸不启动。
- 完成开场后继续移动或释放开局手指不交换，多指全部离开后新触摸才交给棋盘。
- 结果：通过。

### TC-004 入口接续与取消
- 主按钮可接续半程滑动；重复激活不生成新棋盘。
- 挂载刷新保留进度；取消开场或切模式后推进旧时钟不会开局；减少动态效果可即时完成。
- 结果：通过。

### TC-005 空格、鼠标及辅助功能
- 主窗口空格可以开局和接续部分滑动，长按不重复；游戏中不会被解释为重新开始。
- 修饰键、文本输入保留原生行为；鼠标事件完整驱动滑动，辅助功能不会重复启动。
- 结果：通过。

### TC-006 竞速再次结算
- 使用固定 300 分模式与确定性补位序列，两次通过滑动完成开场；每次在开场前等待 20 秒、正式游戏后 2 秒结算。
- 两条新记录均为 2 秒，保留独立记录 id，开场等待未计入竞速时间。
- 结果：通过。

### TC-007 五语言及真实预览
- 五语言、400/1085 两种宽度导出，辅助功能提示随语言更新。
- 使用真实 16 格 Touch Bar 视图导出 40 帧开场 GIF 和待机/半程/游戏三态 PNG；人工确认文字正向、滑块及棋盘显现。
- 测试不挂载真实硬件，真实手指的触控手感留作设备验收；状态机与同一输入路径均已自动验证。
- 结果：通过。

## 手工验收
1. `./run.sh` 启动，待机应只看到左侧金色滑块与提示，不展示彩色棋盘。
2. 从滑块开始拖动，半程松手确认回弹；滑到右端确认完整棋盘显现，并在开场完成后才开始计时。
3. 按住开局手指不抬起，尝试移动或新增触摸，棋盘不能交换；全部抬起后再次触摸可正常游戏。
4. 分别点击主窗口按钮、按空格，确认滑块自动到右端并开始；长按空格不重复启动，游戏中空格不重开。
5. 开场中切模式或切出应用，返回后应处于待机；重新启动开场正常。
6. 完成竞速后用滑块再来一局，检查新记录与计时；切换语言检查触控栏提示即时更新。

## 本轮全部增量 diff
- 以下为本轮开始工作区快照与最终状态的逐行差异；新文件以 `/dev/null` 为基线。

### `Sources/GameStartSequence.swift`

```diff
--- /dev/null
+++ b/Sources/GameStartSequence.swift
@@ -0,0 +1,135 @@
+import Cocoa
+
+/// 三种开局入口共用的过渡状态机；准备棋盘与正式计时分开，动画不占用游戏时间。
+final class GameStartSequence {
+    enum Phase { case waiting, dragging, returning, opening, playing }
+    private struct Observer {
+        weak var owner: AnyObject?
+        let callback: () -> Void
+    }
+    private struct Animation {
+        let start: TimeInterval
+        let from: Double
+        let to: Double
+        let duration: TimeInterval
+    }
+
+    private let board: GameBoardController
+    private let clock: () -> TimeInterval
+    private let automaticallyAnimates: Bool
+    private var observers: [UUID: Observer] = [:]
+    private var animation: Animation?
+    private var timer: Timer?
+    private var hasPreparedBoard = false
+    private(set) var phase = Phase.waiting
+    private(set) var progress: Double = 0
+    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
+    var isOpening: Bool { phase == .opening }
+
+    init(board: GameBoardController, clock: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate },
+         automaticallyAnimates: Bool = true) {
+        self.board = board; self.clock = clock; self.automaticallyAnimates = automaticallyAnimates
+    }
+    deinit { timer?.invalidate() }
+
+    @discardableResult
+    func requestAutomaticStart() -> Bool {
+        guard phase != .opening else { return false }
+        let needsPreparation = !hasPreparedBoard || phase == .playing
+        if phase == .playing { progress = 0 }
+        phase = .opening
+        if needsPreparation { prepareBoard() }
+        animate(to: 1, duration: max(0.12, 0.45 * (1 - progress)))
+        return true
+    }
+
+    @discardableResult
+    func beginDrag() -> Bool {
+        guard (phase == .waiting || phase == .returning), !board.snapshot().isRunning else { return false }
+        stopAnimation()
+        phase = .dragging
+        if !hasPreparedBoard { prepareBoard() }
+        notifyChange()
+        return true
+    }
+
+    func updateDrag(progress value: Double) {
+        guard phase == .dragging else { return }
+        progress = min(1, max(0, value))
+        if progress >= 0.98 {
+            phase = .opening
+            animate(to: 1, duration: 0.12)
+        } else { notifyChange() }
+    }
+
+    /// 松手未完成或触摸取消均回弹，不启动计时；已到终点的开场继续完成。
+    func endDrag() {
+        guard phase == .dragging else { return }
+        phase = .returning
+        animate(to: 0, duration: 0.22)
+    }
+
+    func reset(notify: Bool = true) {
+        stopAnimation()
+        phase = .waiting; progress = 0; hasPreparedBoard = false
+        if notify { notifyChange() }
+    }
+
+    func cancelPendingStart() {
+        guard phase != .playing else { return }
+        reset()
+    }
+
+    /// 外部重开与正常结算仍可驱动展示；开场期间的未运行快照不会重置滑动进度。
+    func synchronize(with snapshot: GameSnapshot) {
+        if snapshot.isRunning, phase != .playing {
+            stopAnimation(); phase = .playing; progress = 1; hasPreparedBoard = false
+            notifyChange()
+        } else if !snapshot.isRunning, phase == .playing { reset() }
+    }
+
+    /// 注入时钟用于确定性验证；运行时由同一方法按 60 Hz 推进动画。
+    func advanceAnimation() {
+        guard let animation else { return }
+        let t = min(1, max(0, (clock() - animation.start) / animation.duration))
+        let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
+        progress = animation.from + (animation.to - animation.from) * eased
+        if t >= 1 { finishAnimation(to: animation.to) }
+        else { notifyChange() }
+    }
+
+    func addObserver(owner: AnyObject, callback: @escaping () -> Void) -> UUID {
+        let id = UUID(); observers[id] = Observer(owner: owner, callback: callback); return id
+    }
+    func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
+
+    private func prepareBoard() {
+        hasPreparedBoard = true
+        board.prepareRound()
+    }
+    private func animate(to target: Double, duration: TimeInterval) {
+        stopAnimation()
+        if reducesMotion() { finishAnimation(to: target); return }
+        animation = Animation(start: clock(), from: progress, to: target, duration: duration)
+        notifyChange()
+        guard automaticallyAnimates else { return }
+        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
+        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
+    }
+    private func finishAnimation(to target: Double) {
+        stopAnimation(); progress = target
+        if target == 1 {
+            phase = .playing; hasPreparedBoard = false
+            board.beginPreparedRound()
+        } else { phase = .waiting }
+        notifyChange()
+    }
+    private func stopAnimation() { timer?.invalidate(); timer = nil; animation = nil }
+    private func notifyChange() {
+        let current = observers
+        for (id, observer) in current {
+            if observer.owner == nil { observers.removeValue(forKey: id) }
+            else { observer.callback() }
+        }
+    }
+}
```

### `Sources/GameTouchBarView.swift`

```diff
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -36,6 +36,7 @@
     private var stoppedElapsedTime: TimeInterval = 0
     private var isRunningRound = false
     private var isFinished = false
+    private var hasPreparedRound = false
     private var lastSwapPair: (Int, Int)?
 
     private var lockedIndices: Set<Int> = []
@@ -60,6 +61,7 @@
 
     func configure(mode: GameMode) {
         self.mode = mode
+        hasPreparedRound = false
         resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
         isRunningRound = false
@@ -68,10 +70,26 @@
     }
 
     func startRound() {
+        prepareRound()
+        beginPreparedRound()
+    }
+
+    /// 生成可预览棋盘但不开计时、不接受交换；开场完成时沿用同一组 tile id。
+    func prepareRound() {
         resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
+        isRunningRound = false
+        isFinished = false
+        hasPreparedRound = true
+        notifyChange()
+    }
+
+    func beginPreparedRound() {
+        guard hasPreparedRound, !isRunningRound else { return }
+        hasPreparedRound = false
+        roundStartDate = currentDate()
+        stoppedElapsedTime = 0
         isRunningRound = true
-        isFinished = false
         notifyChange()
     }
 
@@ -342,6 +360,11 @@
     }
 
     private let controller: GameBoardController
+    private let startSequence: GameStartSequence
+    private var startObserverToken: UUID?
+    private var consumedStartPointers: Set<AnyHashable> = []
+    private var startPointer: AnyHashable?
+    private var startGrabOffset: CGFloat = 0
     private let audioSystem = GameAudioSystem.shared
     private let columnRange: Range<Int>
     private let columnCount: Int
@@ -367,18 +390,19 @@
     private var lastKnownBoundsSize: CGSize = .zero
     // 当 prepareForDisplay 发生在零尺寸阶段时，先挂起刷新，等真正拿到尺寸后再补绘。
     private var pendingDisplayRefresh = false
-    // 仅在实际完成格子/方块绘制后才置为 true，避免把“纯黑底首帧”误判成成功渲染。
+    // 仅在实际绘制棋盘或开局滑轨后置为 true，避免把“纯黑底首帧”误判成成功渲染。
     private(set) var hasDrawnVisibleContent = false
     private(set) var displayGeneration = 0
     private var lastLoggedRenderState = ""
     private var lastLoggedVisibleGeneration = -1
 
-    init(columnRange: Range<Int>, controller: GameBoardController, leadingCompensationX: CGFloat = 0) {
+    init(columnRange: Range<Int>, controller: GameBoardController, startSequence: GameStartSequence, leadingCompensationX: CGFloat = 0) {
         precondition(!columnRange.isEmpty, "columnRange must contain at least one column")
 
         self.columnRange = columnRange
         self.columnCount = columnRange.count
         self.controller = controller
+        self.startSequence = startSequence
         self.leadingCompensationX = max(0, leadingCompensationX)
         self.renderedTiles = controller.tiles()
 
@@ -397,6 +421,9 @@
         observerToken = controller.addObserver(owner: self) { [weak self] in
             self?.handleControllerChange()
         }
+        startObserverToken = startSequence.addObserver(owner: self) { [weak self] in self?.handleStartSequenceChange() }
+        startSequence.synchronize(with: controller.snapshot())
+        handleStartSequenceChange()
     }
 
     required init?(coder: NSCoder) {
@@ -405,6 +432,7 @@
 
     deinit {
         transitionTimer?.invalidate()
+        if let startObserverToken { startSequence.removeObserver(startObserverToken) }
         if let observerToken {
             controller.removeObserver(observerToken)
         }
@@ -447,6 +475,13 @@
                 lastLoggedRenderState = renderState
                 logDiagnostics("跳过有效内容绘制，原因=尺寸不足，bounds=\(TouchBarDiagnostics.describe(rect: bounds))")
             }
+            return
+        }
+
+        if startSequence.phase != .playing {
+            drawStartPresentation()
+            hasDrawnVisibleContent = true
+            logVisibleContentIfNeeded(reason: "开局滑轨")
             return
         }
 
@@ -494,11 +529,12 @@
         let touches = event.touches(matching: .began, in: self)
         for touch in touches {
             let point = touch.location(in: self)
+            let id = ObjectIdentifier(touch.identity as AnyObject)
+            if beginStartInteraction(pointer: id, at: point) { continue }
             let index = indexForPoint(point)
             guard isValidIndex(index) else { continue }
             guard controller.lock(index) else { continue }
 
-            let id = ObjectIdentifier(touch.identity as AnyObject)
             activeTouches[id] = TouchState(startIndex: index, currentIndex: index)
         }
     }
@@ -507,6 +543,7 @@
         let touches = event.touches(matching: .touching, in: self)
         for touch in touches {
             let id = ObjectIdentifier(touch.identity as AnyObject)
+            if moveStartInteraction(pointer: id, to: touch.location(in: self)) { continue }
             guard var state = activeTouches[id] else { continue }
 
             let point = touch.location(in: self)
@@ -531,6 +568,7 @@
     private func handleTouchesEnded(_ touches: Set<NSTouch>) {
         for touch in touches {
             let id = ObjectIdentifier(touch.identity as AnyObject)
+            if endStartInteraction(pointer: id, at: touch.location(in: self)) { continue }
             guard let state = activeTouches[id] else { continue }
 
             let point = touch.location(in: self)
@@ -555,6 +593,7 @@
     private func handleTouchesCancelled(_ touches: Set<NSTouch>) {
         for touch in touches {
             let id = ObjectIdentifier(touch.identity as AnyObject)
+            if endStartInteraction(pointer: id, at: touch.location(in: self), cancelled: true) { continue }
             guard let state = activeTouches[id] else { continue }
 
             controller.unlock(state.startIndex)
@@ -564,9 +603,116 @@
 
     override func mouseDown(with event: NSEvent) {
         let point = convert(event.locationInWindow, from: nil)
+        if beginStartInteraction(pointer: "mouse", at: point) { return }
         let index = indexForPoint(point)
         guard isValidIndex(index) else { return }
         controller.handleTap(at: index)
+    }
+
+    override func mouseDragged(with event: NSEvent) {
+        _ = moveStartInteraction(pointer: "mouse", to: convert(event.locationInWindow, from: nil))
+    }
+
+    override func mouseUp(with event: NSEvent) {
+        _ = endStartInteraction(pointer: "mouse", at: convert(event.locationInWindow, from: nil))
+    }
+
+    /// 触摸与鼠标共用同一条输入路径；开局手指在抬起前始终不会进入棋盘操作。
+    @discardableResult
+    func beginStartInteraction(pointer: AnyHashable, at point: NSPoint) -> Bool {
+        guard startSequence.phase != .playing || !consumedStartPointers.isEmpty else { return false }
+        consumedStartPointers.insert(pointer)
+        let thumb = startThumbRect
+        if startPointer == nil, thumb.insetBy(dx: -4, dy: -4).contains(point), startSequence.beginDrag() {
+            startPointer = pointer
+            startGrabOffset = point.x - thumb.minX
+        }
+        return true
+    }
+
+    @discardableResult
+    func moveStartInteraction(pointer: AnyHashable, to point: NSPoint) -> Bool {
+        guard consumedStartPointers.contains(pointer) else { return false }
+        if startPointer == pointer { updateStartProgress(at: point) }
+        return true
+    }
+
+    @discardableResult
+    func endStartInteraction(pointer: AnyHashable, at point: NSPoint, cancelled: Bool = false) -> Bool {
+        guard consumedStartPointers.contains(pointer) else { return false }
+        if startPointer == pointer {
+            if !cancelled { updateStartProgress(at: point) }
+            startSequence.endDrag()
+            startPointer = nil
+        }
+        consumedStartPointers.remove(pointer)
+        return true
+    }
+
+    func cancelInteractions() {
+        startSequence.cancelPendingStart()
+        consumedStartPointers.removeAll(); startPointer = nil
+        let previous = activeTouches; activeTouches.removeAll()
+        for state in previous.values { controller.unlock(state.startIndex) }
+    }
+
+    func refreshLanguage() { handleStartSequenceChange() }
+
+    private func updateStartProgress(at point: NSPoint) {
+        let travel = max(1, bounds.width - 8 - startThumbRect.width)
+        startSequence.updateDrag(progress: Double((point.x - startGrabOffset - 4) / travel))
+    }
+
+    var startThumbRect: NSRect {
+        let width = min(44, max(0, bounds.width - 8))
+        return NSRect(x: 4 + CGFloat(startSequence.progress) * max(0, bounds.width - 8 - width),
+                      y: bounds.midY - 13, width: width, height: 26)
+    }
+
+    override func accessibilityPerformPress() -> Bool {
+        guard startSequence.phase != .playing else { return false }
+        return startSequence.requestAutomaticStart()
+    }
+
+    private func handleStartSequenceChange() {
+        if startSequence.phase != .playing {
+            let previous = activeTouches; activeTouches.removeAll()
+            consumedStartPointers.formUnion(previous.keys.map { AnyHashable($0) })
+            for state in previous.values { controller.unlock(state.startIndex) }
+        }
+        setAccessibilityElement(true)
+        setAccessibilityRole(startSequence.phase == .playing ? .group : .button)
+        setAccessibilityLabel(Localizer.shared.string(startSequence.phase == .playing ? "touchbar.board" : "touchbar.slide_start"))
+        requestDisplayRefresh()
+    }
+
+    private func drawStartPresentation() {
+        let track = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
+        NSColor(calibratedWhite: 0.11, alpha: 1).setFill(); track.fill()
+        NSColor.white.withAlphaComponent(0.12).setStroke(); track.lineWidth = 0.5; track.stroke()
+        let progress = CGFloat(startSequence.progress)
+        if progress > 0 {
+            NSGraphicsContext.saveGraphicsState()
+            NSBezierPath(rect: NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width * progress, height: bounds.height)).addClip()
+            for localIndex in 0..<columnCount {
+                let rect = cellRect(forLocalIndex: localIndex)
+                drawCellBackground(in: rect, globalIndex: columnRange.lowerBound + localIndex, highlighted: false)
+                drawPiece(controller.tile(at: columnRange.lowerBound + localIndex), in: rect, highlighted: false, alpha: 1, scale: 1)
+            }
+            NSGraphicsContext.restoreGraphicsState()
+        }
+        let title = Localizer.shared.string(controller.snapshot().isFinished ? "touchbar.slide_again" : "touchbar.slide_start")
+        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
+        let titleSize = (title as NSString).size(withAttributes: [.font: font])
+        let alpha = max(0, 1 - progress * 4)
+        if bounds.width > 180 {
+            (title as NSString).draw(at: NSPoint(x: bounds.midX - titleSize.width / 2, y: bounds.midY - titleSize.height / 2),
+                                     withAttributes: [.font: font, .foregroundColor: NSColor.white.withAlphaComponent(0.75 * alpha)])
+        }
+        let thumb = NSBezierPath(roundedRect: startThumbRect, xRadius: 7, yRadius: 7)
+        NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.9, blue: 0.42, alpha: 1), HomeStyle.yellow])?.draw(in: thumb, angle: 90)
+        NSColor.white.withAlphaComponent(0.45).setStroke(); thumb.lineWidth = 0.5; thumb.stroke()
+        HomeStyle.symbol("chevron.right", in: startThumbRect.insetBy(dx: 15, dy: 6), color: HomeStyle.ink)
     }
 
     @discardableResult
@@ -589,8 +735,16 @@
     }
 
     private func handleControllerChange() {
+        startSequence.synchronize(with: controller.snapshot())
         let latestTiles = controller.tiles()
         let swapPair = controller.consumeLastSwapPair()
+        if startSequence.phase != .playing {
+            transitionTimer?.invalidate(); transitionTimer = nil
+            pieceTransitions = []; transitionPhases = []; transitionProgress = 1
+            renderedTiles = latestTiles
+            handleStartSequenceChange()
+            return
+        }
         if latestTiles == renderedTiles {
             requestDisplayRefresh()
             return
```

### `Sources/GameViewController.swift`

```diff
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -8,6 +8,9 @@
     private let achievements: AchievementsManager
     private let audioEnabled: Bool
     private let controller: GameBoardController
+    let startSequence: GameStartSequence
+    private var startObserverToken: UUID?
+    private var startKeyMonitor: Any?
     private var selection: HomeGameMode = .free
     private var hasConfiguredMode = false
     private var hasSavedFinishedRecord = false
@@ -20,7 +23,7 @@
     private var achievementToasts: AchievementToastPresenter?
     private var hudTimer: Timer?
     private lazy var dashboard = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
+    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller, startSequence: startSequence)
     private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
     private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
     private let touchBarHealthCheckDelay: TimeInterval = 0.18
@@ -38,9 +41,12 @@
     private weak var observedTouchBarWindow: NSWindow?
 
     init(achievements: AchievementsManager = .shared, records: ModeRecordStore = .shared,
-         board: GameBoardController? = nil, audioEnabled: Bool = true) {
+         board: GameBoardController? = nil, audioEnabled: Bool = true,
+         startClock: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }) {
         self.achievements = achievements; self.recordStore = records; self.audioEnabled = audioEnabled
-        self.controller = board ?? GameBoardController(columns: 16, achievements: achievements)
+        let resolvedBoard = board ?? GameBoardController(columns: 16, achievements: achievements)
+        self.controller = resolvedBoard
+        self.startSequence = GameStartSequence(board: resolvedBoard, clock: startClock)
         super.init(nibName: nil, bundle: nil)
     }
     required init?(coder: NSCoder) { nil }
@@ -65,6 +71,7 @@
         dashboard.onNavigate = { [weak self] page in self?.presentUtility(page) }
         dashboard.onAchievement = { [weak self] id in self?.presentAchievements(detailID: id) }
         observerToken = controller.addObserver(owner: self) { [weak self] in self?.refresh() }
+        startObserverToken = startSequence.addObserver(owner: self) { [weak self] in self?.refresh() }
         achievementsChangeObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didChangeNotification, object: achievements, queue: .main) { [weak self] _ in self?.refreshAchievements() }
         achievementsUnlockObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: achievements, queue: .main) { [weak self] note in
             if let ids = note.userInfo?["ids"] as? [Int] { self?.achievementToasts?.enqueue(ids) }
@@ -77,6 +84,7 @@
         guard !hasConfiguredMode || mode != selection else { return }
         hasConfiguredMode = true
         selection = mode; hasSavedFinishedRecord = false
+        startSequence.reset(notify: false)
         controller.configure(mode: mode.gameMode)
         if audioEnabled { audioSystem.updateBackgroundMusic(for: mode.gameMode) }
         refresh()
@@ -84,20 +92,23 @@
     }
 
     func startRound() {
+        guard !startSequence.isOpening else { return }
         hasSavedFinishedRecord = false
-        controller.startRound()
+        startSequence.requestAutomaticStart()
         refresh()
     }
 
     private func refreshAchievements() {
-        dashboard.refresh(snapshot: controller.snapshot(), mode: selection, manager: achievements)
+        dashboard.refresh(snapshot: controller.snapshot(), mode: selection, manager: achievements, isStarting: startSequence.isOpening)
         if achievementsPanel?.window?.isVisible == true { achievementsPanel?.refresh() }
         achievementToasts?.refreshLanguage()
     }
 
     private func refresh() {
         let snapshot = controller.snapshot()
-        dashboard.refresh(snapshot: snapshot, mode: selection, manager: achievements)
+        startSequence.synchronize(with: snapshot)
+        dashboard.refresh(snapshot: snapshot, mode: selection, manager: achievements, isStarting: startSequence.isOpening)
+        if !snapshot.isFinished { hasSavedFinishedRecord = false }
         if snapshot.isFinished, !hasSavedFinishedRecord {
             hasSavedFinishedRecord = true
             if snapshot.score > 0 {
@@ -131,6 +142,7 @@
             panel.onLanguage = { [weak self] language in
                 self?.localizer.setLanguage(language)
                 self?.refresh(); self?.refreshAchievements()
+                self?.gameTouchBarView.refreshLanguage()
             }
             panel.onVolume = { [weak self] volume in self?.audioSystem.setMasterVolume(volume) }
             utilityPanels[page] = panel
@@ -141,6 +153,8 @@
 
     deinit {
         if let observerToken { controller.removeObserver(observerToken) }
+        if let startObserverToken { startSequence.removeObserver(startObserverToken) }
+        if let startKeyMonitor { NSEvent.removeMonitor(startKeyMonitor) }
         for observer in [achievementsChangeObserver, achievementsUnlockObserver].compactMap({ $0 }) { NotificationCenter.default.removeObserver(observer) }
         achievementsPanel?.close(); utilityPanels.values.forEach { $0.close() }
         removeTouchBarLifecycleObservers()
@@ -153,15 +167,40 @@
     override func viewDidAppear() {
         super.viewDidAppear()
         if let window = view.window { installTouchBarLifecycleObservers(for: window) }
+        if startKeyMonitor == nil {
+            startKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
+                self?.handleStartKeyEvent(event) == true ? nil : event
+            }
+        }
         synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
         view.window?.makeFirstResponder(self)
         view.window?.contentMinSize = NSSize(width: 960, height: 720)
         refresh()
     }
     override func viewDidDisappear() {
+        startSequence.cancelPendingStart()
+        if let startKeyMonitor { NSEvent.removeMonitor(startKeyMonitor); self.startKeyMonitor = nil }
         invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
         removeTouchBarLifecycleObservers()
         super.viewDidDisappear()
+    }
+
+    /// 仅主窗口的无修饰空格用于开局；辅助面板、菜单与文本输入保留原生键盘语义。
+    @discardableResult
+    func handleStartKeyEvent(_ event: NSEvent) -> Bool {
+        guard event.keyCode == 49,
+              event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
+              let window = view.window, window.isKeyWindow, event.window === window,
+              window.attachedSheet == nil, NSApp.modalWindow == nil else { return false }
+        if window.childWindows?.contains(where: { $0.isVisible }) == true {
+            return window.firstResponder === dashboard.startButton
+        }
+        if window.firstResponder is NSTextView || window.firstResponder is NSPopUpButton || window.firstResponder is NSSlider { return false }
+        if let button = window.firstResponder as? NSButton, button !== dashboard.startButton { return false }
+        // 游戏中也消费空格，避免焦点恰在“重新开始”按钮时被原生按钮意外激活。
+        if event.isARepeat || controller.snapshot().isRunning || startSequence.isOpening { return true }
+        startRound()
+        return true
     }
 
     func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
@@ -271,6 +310,8 @@
     }
 
     private func handleApplicationDidResignActive() {
+        startSequence.cancelPendingStart()
+        gameTouchBarView.cancelInteractions()
         logTouchBarDiagnostics("应用失活，准备关闭私有 modal Touch Bar")
         invalidateSystemModalTouchBarPresentation(reason: "applicationDidResignActive")
     }
@@ -281,6 +322,8 @@
     }
 
     private func handleWindowDidResignKey() {
+        startSequence.cancelPendingStart()
+        gameTouchBarView.cancelInteractions()
         logTouchBarDiagnostics("窗口失去 key，准备关闭私有 modal Touch Bar")
         invalidateSystemModalTouchBarPresentation(reason: "windowDidResignKey")
     }
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -217,12 +217,14 @@
     }
     required init?(coder: NSCoder) { nil }
 
-    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager) {
+    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager, isStarting: Bool = false) {
         selectedMode = mode
         stats.snapshot = snapshot
         heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
         subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
-        if snapshot.isFinished {
+        if isStarting {
+            hint.stringValue = AchievementText.string("home.starting_hint")
+        } else if snapshot.isFinished {
             hint.stringValue = mode == .speedRun
                 ? AchievementText.format("result.speed_run_finished", Self.clock(snapshot.elapsedTime))
                 : AchievementText.format("result.score_attack_finished", snapshot.score)
@@ -230,8 +232,9 @@
             hint.stringValue = mode == .scoreAttack
                 ? AchievementText.format("hud.score_attack", snapshot.score, Self.clock(snapshot.remainingTime ?? 0))
                 : AchievementText.format("hud.speed_run", snapshot.score, HomeGameMode.speedRunTarget, Self.clock(snapshot.elapsedTime))
-        } else { hint.stringValue = AchievementText.string("home.operation_hint") }
-        startButton.title = AchievementText.string(snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
+        } else { hint.stringValue = AchievementText.string(snapshot.isRunning ? "home.operation_hint" : "home.start_hint") }
+        startButton.title = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
+        startButton.isEnabled = !isStarting
         startButton.setAccessibilityLabel(startButton.title)
         records.title = AchievementText.string("panel.records")
         rules.title = AchievementText.string("panel.rules")
```

### `Tests/GameStartSequenceTests.swift`

```diff
--- /dev/null
+++ b/Tests/GameStartSequenceTests.swift
@@ -0,0 +1,314 @@
+import Cocoa
+import ImageIO
+import XCTest
+@testable import EliminateTeris1
+
+private final class StartKeyTestWindow: NSWindow {
+    // 不激活测试应用或挂载真实 Touch Bar，只模拟主窗口的键盘路由条件。
+    override var isKeyWindow: Bool { true }
+}
+
+final class GameStartSequenceTests: AchievementTestCase {
+    private var animationTime: TimeInterval = 0
+    private var gameTime = Date(timeIntervalSince1970: 1_000_000)
+
+    private func fixture(mode: GameMode = .scoreAttack(duration: 60), columns: Int = 4) -> (GameBoardController, GameStartSequence, GameTouchBarView) {
+        _ = NSApplication.shared
+        // 使用交替补位保证结算不会因无限同色补位而无法结束。
+        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+        let board = GameBoardController(columns: columns, achievements: manager, now: { self.gameTime }) { _ in
+            var index = 0
+            let fill = [c, d, c]
+            let tail = (0..<columns - 4).map { $0.isMultiple(of: 2) ? c : d }
+            return GameState(columns: columns, initialKinds: [a, a, b, a] + tail) {
+                defer { index += 1 }
+                return fill[index % fill.count]
+            }
+        }
+        board.configure(mode: mode)
+        let sequence = GameStartSequence(board: board, clock: { self.animationTime }, automaticallyAnimates: false)
+        sequence.reducesMotion = { false }
+        let view = GameTouchBarView(columnRange: 0..<columns, controller: board, startSequence: sequence)
+        view.frame = NSRect(x: 0, y: 0, width: 1085, height: 30)
+        return (board, sequence, view)
+    }
+
+    private func point(_ progress: CGFloat, in view: GameTouchBarView) -> NSPoint {
+        NSPoint(x: 4 + (view.bounds.width - 8 - view.startThumbRect.width) * progress + view.startThumbRect.width / 2, y: 15)
+    }
+    private func advance(_ sequence: GameStartSequence, by seconds: TimeInterval) {
+        animationTime += seconds; sequence.advanceAnimation()
+    }
+    private func image(_ view: NSView) throws -> NSBitmapImageRep {
+        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+        view.cacheDisplay(in: view.bounds, to: bitmap)
+        return bitmap
+    }
+
+    func testIdleRendersVisibleSliderWithoutPlayableTiles() throws {
+        let (board, sequence, view) = fixture()
+        let pixels = try image(view)
+        XCTAssertTrue(view.hasDrawnVisibleContent, "待机滑轨也是健康检查认可的有效内容")
+        XCTAssertEqual(sequence.phase, .waiting)
+        XCTAssertFalse(board.snapshot().isRunning)
+        let scale = CGFloat(pixels.pixelsWide) / view.bounds.width
+        var colored = 0
+        for y in stride(from: 0, to: pixels.pixelsHigh, by: 2) {
+            for x in stride(from: Int(65 * scale), to: pixels.pixelsWide, by: 2) {
+                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
+                if max(color.redComponent, color.greenComponent, color.blueComponent) - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.2 { colored += 1 }
+            }
+        }
+        XCTAssertEqual(colored, 0, "待机时滑块右侧不应提前展示彩色棋盘")
+    }
+
+    func testAutomaticOpeningPreservesPreviewAndStartsClockAtCompletion() {
+        let (board, sequence, _) = fixture()
+        XCTAssertTrue(sequence.requestAutomaticStart())
+        let preview = board.tiles()
+        XCTAssertFalse(sequence.requestAutomaticStart(), "重复开始不能重新生成棋盘")
+        gameTime = gameTime.addingTimeInterval(20)
+        advance(sequence, by: 0.2)
+        XCTAssertGreaterThan(sequence.progress, 0)
+        XCTAssertLessThan(sequence.progress, 1)
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertEqual(board.snapshot().remainingTime, 60)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.tiles(), preview)
+        advance(sequence, by: 0.3)
+        XCTAssertEqual(sequence.phase, .playing)
+        XCTAssertEqual(board.tiles(), preview, "显现的棋盘应与正式开局一致")
+        XCTAssertEqual(board.snapshot().elapsedTime, 0)
+        gameTime = gameTime.addingTimeInterval(5)
+        XCTAssertEqual(board.snapshot().remainingTime, 55)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().score, 30)
+    }
+
+    func testPartialDragAndCancellationReturnWithoutStarting() {
+        let (board, sequence, view) = fixture()
+        XCTAssertTrue(view.beginStartInteraction(pointer: "finger", at: point(0, in: view)))
+        _ = view.moveStartInteraction(pointer: "finger", to: point(0.5, in: view))
+        XCTAssertEqual(sequence.phase, .dragging)
+        XCTAssertEqual(sequence.progress, 0.5, accuracy: 0.001)
+        _ = view.endStartInteraction(pointer: "finger", at: point(0.5, in: view))
+        XCTAssertEqual(sequence.phase, .returning)
+        advance(sequence, by: 0.3)
+        XCTAssertEqual(sequence.phase, .waiting)
+        XCTAssertEqual(sequence.progress, 0)
+        XCTAssertFalse(board.snapshot().isRunning)
+        _ = view.beginStartInteraction(pointer: "finger", at: point(0, in: view))
+        _ = view.moveStartInteraction(pointer: "finger", to: point(0.6, in: view))
+        _ = view.endStartInteraction(pointer: "finger", at: point(1, in: view), cancelled: true)
+        advance(sequence, by: 0.3)
+        XCTAssertEqual(sequence.progress, 0)
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertEqual(manager.progress(for: AchievementDefinition.all[19]).current, 0)
+    }
+
+    func testLaunchTouchesStayConsumedUntilEveryFingerIsReleased() {
+        let (board, sequence, view) = fixture(mode: .free)
+        _ = view.beginStartInteraction(pointer: "first", at: point(0, in: view))
+        _ = view.beginStartInteraction(pointer: "second", at: point(0.3, in: view))
+        _ = view.moveStartInteraction(pointer: "first", to: point(1, in: view))
+        XCTAssertEqual(sequence.phase, .opening)
+        advance(sequence, by: 0.2)
+        let initial = board.tiles()
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertTrue(view.moveStartInteraction(pointer: "first", to: point(0.8, in: view)))
+        XCTAssertTrue(view.endStartInteraction(pointer: "first", at: point(0.8, in: view)))
+        XCTAssertTrue(view.beginStartInteraction(pointer: "third", at: point(0.5, in: view)), "仍有开局手指时，新触摸也不能穿透")
+        _ = view.endStartInteraction(pointer: "third", at: point(0.5, in: view))
+        _ = view.endStartInteraction(pointer: "second", at: point(0.3, in: view))
+        XCTAssertEqual(board.tiles(), initial)
+        XCTAssertFalse(view.beginStartInteraction(pointer: "fresh", at: point(0.5, in: view)), "全部抬手后，新的触摸才交给棋盘")
+        board.handleTap(at: 2); board.handleTap(at: 3)
+        XCTAssertEqual(board.snapshot().score, 30)
+    }
+
+    func testOutsideTouchesDoNotStartAndButtonContinuesPartialDrag() {
+        let (board, sequence, view) = fixture()
+        _ = view.beginStartInteraction(pointer: "outside", at: point(0.5, in: view))
+        _ = view.endStartInteraction(pointer: "outside", at: point(0, in: view))
+        XCTAssertEqual(sequence.phase, .waiting)
+        _ = view.beginStartInteraction(pointer: "drag", at: point(0, in: view))
+        _ = view.moveStartInteraction(pointer: "drag", to: point(0.4, in: view))
+        let preview = board.tiles()
+        XCTAssertTrue(sequence.requestAutomaticStart())
+        advance(sequence, by: 0.5)
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertEqual(board.tiles(), preview)
+        XCTAssertTrue(view.endStartInteraction(pointer: "drag", at: point(0.4, in: view)))
+        XCTAssertFalse(board.isSelected(0))
+    }
+
+    func testDisplayRefreshKeepsOpeningAndFocusLossCancelsIt() throws {
+        let (board, sequence, view) = fixture()
+        sequence.requestAutomaticStart(); advance(sequence, by: 0.2)
+        let progress = sequence.progress
+        view.prepareForDisplay()
+        XCTAssertEqual(sequence.progress, progress)
+        _ = try image(view)
+        XCTAssertTrue(view.hasDrawnVisibleContent)
+        view.cancelInteractions()
+        advance(sequence, by: 10)
+        XCTAssertEqual(sequence.phase, .waiting)
+        XCTAssertFalse(board.snapshot().isRunning)
+    }
+
+    func testModeChangeInvalidatesOldOpeningAndReducedMotionStartsImmediately() {
+        let (board, sequence, _) = fixture()
+        sequence.requestAutomaticStart()
+        sequence.reset(notify: false); board.configure(mode: .speedRun(targetScore: 300))
+        advance(sequence, by: 1)
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertEqual(sequence.phase, .waiting)
+        sequence.reducesMotion = { true }
+        sequence.requestAutomaticStart()
+        XCTAssertEqual(sequence.phase, .playing)
+        XCTAssertEqual(sequence.progress, 1)
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertEqual(board.snapshot().elapsedTime, 0)
+    }
+
+    func testSpeedRunIgnoresOpeningTimeAndManualRestartSavesEachRound() throws {
+        _ = NSApplication.shared
+        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+        let board = GameBoardController(columns: 4, achievements: manager, now: { self.gameTime }) { _ in
+            var index = 0
+            let fill = Array(repeating: a, count: 27) + [c, d, c]
+            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
+                defer { index += 1 }
+                return fill[index]
+            }
+        }
+        let records = ModeRecordStore(defaults: defaults)
+        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false,
+                                            startClock: { self.animationTime })
+        _ = controller.view
+        // 使用确定的连锁补位达到固定 300 分目标，不缩小正式规则阈值。
+        controller.selectMode(.speedRun)
+        controller.startSequence.reducesMotion = { false }
+        let baseline = Set(records.records(for: .speedRun, detailValue: 300).map(\.id))
+        for _ in 0..<2 {
+            XCTAssertTrue(controller.startSequence.beginDrag())
+            gameTime = gameTime.addingTimeInterval(20)
+            controller.startSequence.updateDrag(progress: 1)
+            advance(controller.startSequence, by: 0.2)
+            XCTAssertEqual(board.snapshot().elapsedTime, 0)
+            gameTime = gameTime.addingTimeInterval(2)
+            board.performSwap(from: 2, to: 3)
+            XCTAssertTrue(board.snapshot().isFinished)
+            XCTAssertEqual(board.snapshot().elapsedTime, 2)
+        }
+        let newEntries = records.records(for: .speedRun, detailValue: 300).filter { !baseline.contains($0.id) }
+        XCTAssertEqual(newEntries.count, 2, "滑动再来一局也应正常保存新的结算记录")
+        XCTAssertTrue(newEntries.allSatisfy { $0.elapsedTime == 2 })
+    }
+
+    func testMouseDragAndAccessibilityUseTheSameOpening() throws {
+        let (board, sequence, view) = fixture()
+        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1085, height: 30), styleMask: [], backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false; window.contentView = view
+        defer { window.close() }
+        func mouse(_ type: NSEvent.EventType, _ progress: CGFloat) throws -> NSEvent {
+            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: view.convert(point(progress, in: view), to: nil), modifierFlags: [],
+                                            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
+        }
+        view.mouseDown(with: try mouse(.leftMouseDown, 0))
+        view.mouseDragged(with: try mouse(.leftMouseDragged, 1))
+        advance(sequence, by: 0.2)
+        view.mouseUp(with: try mouse(.leftMouseUp, 1))
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertFalse((0..<4).contains { board.isSelected($0) })
+        sequence.reset(notify: false); board.configure(mode: .free)
+        XCTAssertTrue(view.accessibilityPerformPress())
+        XCTAssertFalse(view.accessibilityPerformPress(), "辅助功能重复激活不能重开动画")
+        advance(sequence, by: 0.5)
+        XCTAssertTrue(board.snapshot().isRunning)
+    }
+
+    func testSpaceOnlyStartsFromEligibleMainWindowAndDoesNotRestartRunningRound() throws {
+        _ = NSApplication.shared
+        let (board, _, _) = fixture()
+        let controller = GameViewController(achievements: manager, records: ModeRecordStore(defaults: defaults), board: board,
+                                            audioEnabled: false, startClock: { self.animationTime })
+        controller.startSequence.reducesMotion = { false }
+        let window = StartKeyTestWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false; window.contentView = controller.view
+        defer { window.close() }
+        func key(modifiers: NSEvent.ModifierFlags = [], repeatKey: Bool = false) throws -> NSEvent {
+            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
+                                          windowNumber: window.windowNumber, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeatKey, keyCode: 49))
+        }
+        XCTAssertFalse(controller.handleStartKeyEvent(try key(modifiers: .command)))
+        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
+        let preview = board.tiles()
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertTrue(controller.handleStartKeyEvent(try key(repeatKey: true)))
+        advance(controller.startSequence, by: 1)
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertTrue(controller.handleStartKeyEvent(try key()))
+        XCTAssertEqual(board.tiles(), preview)
+        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
+        controller.view.addSubview(editor); window.makeFirstResponder(editor)
+        XCTAssertFalse(controller.handleStartKeyEvent(try key()), "文字输入中的空格不能被开局快捷键截获")
+        window.makeFirstResponder(nil); editor.removeFromSuperview()
+        controller.selectMode(.speedRun)
+        XCTAssertTrue(controller.startSequence.beginDrag())
+        controller.startSequence.updateDrag(progress: 0.4)
+        let partialPreview = board.tiles()
+        XCTAssertTrue(controller.handleStartKeyEvent(try key()), "空格也能接续尚未完成的滑动")
+        advance(controller.startSequence, by: 1)
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertEqual(board.tiles(), partialPreview)
+    }
+
+    func testFiveLanguagesAndExportRealStartAnimation() throws {
+        let (_, sequence, view) = fixture(mode: .free, columns: 16)
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            XCTAssertNotEqual(Localizer.shared.string("touchbar.slide_start"), "touchbar.slide_start")
+            view.refreshLanguage()
+            XCTAssertEqual(view.accessibilityLabel(), Localizer.shared.string("touchbar.slide_start"))
+            for width: CGFloat in [400, 1085] { view.setFrameSize(NSSize(width: width, height: 30)); _ = try image(view) }
+        }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        view.setFrameSize(NSSize(width: 1085, height: 30))
+        let idle = try image(view)
+        try XCTUnwrap(idle.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start-idle.png"))
+        _ = view.beginStartInteraction(pointer: "preview", at: point(0, in: view))
+        _ = view.moveStartInteraction(pointer: "preview", to: point(0.5, in: view))
+        let half = try image(view)
+        _ = view.endStartInteraction(pointer: "preview", at: point(0.5, in: view))
+        advance(sequence, by: 0.3)
+        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start.gif")
+        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(destinationURL as CFURL, "com.compuserve.gif" as CFString, 40, nil))
+        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        for frame in 0..<40 {
+            if frame == 8 { sequence.requestAutomaticStart() }
+            if frame >= 8 { advance(sequence, by: 0.04) }
+            let cgImage = try XCTUnwrap(try image(view).cgImage)
+            CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(destination))
+        let playing = try image(view)
+        let samples = [("等待开始", idle), ("滑动显现", half), ("正式游戏", playing)]
+        let sheet = NSImage(size: NSSize(width: 1085, height: 180), flipped: true) { bounds in
+            HomeStyle.background.setFill(); bounds.fill()
+            for (index, sample) in samples.enumerated() {
+                let y = CGFloat(index) * 60
+                HomeStyle.text(sample.0, in: NSRect(x: 8, y: y + 4, width: 300, height: 18), size: 12, weight: .semibold)
+                if let cgImage = sample.1.cgImage {
+                    NSImage(cgImage: cgImage, size: NSSize(width: 1085, height: 30)).draw(in: NSRect(x: 0, y: y + 26, width: 1085, height: 30),
+                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+                }
+            }
+            return true
+        }
+        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(sheet.tiffRepresentation))?.representation(using: .png, properties: [:]))
+        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touchbar-start-states.png"))
+    }
+}
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -61,12 +61,16 @@
         _ = NSApplication.shared
         let board = board(now: { self.date })
         let records = ModeRecordStore(defaults: defaults)
-        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false)
+        var animationTime: TimeInterval = 0
+        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false, startClock: { animationTime })
+        controller.startSequence.reducesMotion = { false }
         let view = controller.view
         let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.primary })
         let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeSessionStatsView }.first)
         XCTAssertFalse(board.snapshot().isRunning)
         start.performClick(nil)
+        XCTAssertFalse(board.snapshot().isRunning, "开场动画不应消耗游戏时间")
+        animationTime += 1; controller.startSequence.advanceAnimation()
         XCTAssertTrue(board.snapshot().isRunning)
         board.performSwap(from: 2, to: 3)
         XCTAssertEqual(stats.snapshot?.totalCleared, 30)
@@ -78,6 +82,7 @@
         XCTAssertEqual(board.snapshot().targetScore, 300)
         XCTAssertEqual(stats.snapshot?.totalCleared, 0)
         start.performClick(nil)
+        animationTime += 1; controller.startSequence.advanceAnimation()
         board.performSwap(from: 2, to: 3)
         XCTAssertTrue(board.snapshot().isFinished)
         XCTAssertEqual(stats.snapshot?.totalCleared, 30)
```

### `Tests/AchievementLocalizationTests.swift`

```diff
--- a/Tests/AchievementLocalizationTests.swift
+++ b/Tests/AchievementLocalizationTests.swift
@@ -20,7 +20,7 @@
             }
         }
         let english = try XCTUnwrap(tables["en"])
-        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") || $0.hasPrefix("home.") }
+        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") || $0.hasPrefix("home.") || $0.hasPrefix("touchbar.") }
         for table in tables.values {
             for key in keys {
                 let value = try XCTUnwrap(table[key], key)
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -4,6 +4,11 @@
 - 项目为 macOS 12+ 原生 AppKit/Cocoa 游戏，使用 Swift 5.7+ 与 Swift Package Manager；桌面窗口负责设置和信息展示，16 格 Touch Bar 承载核心操作。
 - 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
 - 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
+
+## 2026-11-01（统一开局生命周期）
+- `GameStartSequence` 协调主窗口按钮、空格和 Touch Bar 滑动三个入口；开局过渡与真实游戏计时独立，未完成的手势可取消。
+- `GameBoardController.prepareRound` 生成可预览但不可交互的棋盘，`beginPreparedRound` 在开场完成后启用同一盘方块并开始计时；既有直接开局接口保留供逻辑调用。
+- Touch Bar 待机展示开局滑轨，已绘制的滑轨同样计入私有 modal 健康检查；挂载刷新不重置开局进度。开局触摸在抬起前由独立输入路径消费，避免进入棋盘交换。
 
 ## 2026-10-30（experiment/ui-refactor 探索分支）
 - 桌面首页由 `HomeDashboardView` 负责展示，`GameViewController` 负责事件协调、记录结算与既有 Touch Bar 展示生命周期；共用规则和浅色绘制位于 `GamePresentation`。
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261101151458-touchbar-slide-to-start.md` - 会话-130 起实现会话-126 的方案 1：待机开局滑块、拖动显现/回弹、按钮与空格自动开场；统一准备/计时边界，隔离开局触摸，含全部增量 diff、真实预览、72 项完整回归及最后 18 项专项。
 `workflow/20261101000207-center-achievement-content-without-status.md` - 会话-119 起更正居中范围：完成/锁定状态固定左侧，仅成就图案与名称按卡片中心对齐；含全部增量 diff、更新预览及 12 项回归，取代上一轮三者合并居中的设计。
 `workflow/20261031235319-center-fullscreen-achievement-labels.md` - 会话-113 起修复首页成就标签全屏时图文偏左：按状态图标、成就图案与最终可见文字整体居中，兼容长名称省略和宽度恢复；含全部增量 diff、真实标签图及 12 项回归。
 `workflow/20261031233928-polish-game-utility-panels.md` - 会话-106 起统一重构游戏设置、玩法说明与挑战记录：主题卡片、金色音量滑杆、三步图文教学、动画模式切换、个人最佳及金银铜排行；含全部增量 diff、五语言/小窗口截图与 60 项完整回归。
@@ -81,6 +82,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要了解滑动/按钮/空格开局、预览与正式计时的边界、触摸抬起隔离、开场取消或 Touch Bar 待机健康检查时，读取 `20261101151458-touchbar-slide-to-start.md`。
 - 需要确认成就标签居中范围、状态标记固定左侧及图案与名称单独居中的布局时，优先读取 `20261101000207-center-achievement-content-without-status.md`。
 - 需要修复首页成就标签全屏/宽窗口的图文居中、长名称截短或尺寸恢复时，读取 `20261031235319-center-fullscreen-achievement-labels.md`。
 - 需要调整设置控件、玩法教学卡片、挑战排行榜/空状态、辅助面板滚动与定位，或查看实际测试图时，读取 `20261031233928-polish-game-utility-panels.md`。
@@ -162,12 +164,13 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 开局由 `GameStartSequence` 统一管理；`prepareRound` 仅生成预览，`beginPreparedRound` 在开场结束后启用同一棋盘并开始计时。待机 Touch Bar 显示滑轨，开局指针全部抬起后才接受交换；私有 modal 刷新保持开场进度。
 - 成就筛选由 `AchievementFilterControl` 统一绘制一体式滑轨与数量，沿用 `NSSegmentedControl` 的真实选择值；黄色滑块由 Core Animation 移动，刷新列表不重置动画，减少动态效果时即时定位。测试动画及页面图位于 `docs/previews/achievement-filter.gif` 和 `achievement-panel.png`，正式应用无测试预览入口。
 - `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的透明背景彩色游戏图案，不绘制徽章外框或底板。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
 - 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
-- 探索分支三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
+- 探索分支三种模式通过按钮、空格或滑动触控栏显式开局；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
 - 顶部统计卡片使用统一“累计消除”标题，七段数字按方块高度绘制，长数量只横向压缩；图案和数字共用浮动位置，只有数量增长时数字额外跳动，首次加载/同值刷新不触发。
 - 成就现为 32 枚，新增编号 21—32 对应橙/蓝/绿/红四类方块的百/千/万累计里程碑；原编号 1—20 保持不变。
 - 类型累计值跨局、跨模式及重启保存；旧存档没有类型明细时从 0 开始，保留既有总数和解锁状态，不推测历史分布。顶部横幅与类型成就读取同一数据源。
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -1,6 +1,17 @@
 # 游戏界面测试图
 
 这些文件仅用于开发测试与评审，正式应用中没有图标预览按钮或图标预览页面。
+
+## 触控栏滑动开局
+
+- [查看开局动画](touchbar-start.gif)：待机滑轨与按钮触发的从左到右自动显现，使用真实 `GameTouchBarView` 导出。
+- [查看三种状态](touchbar-start-states.png)：等待开始、滑动半程、正式 16 格棋盘。
+- 开局动画结束后才计时；未完成松手回弹，开局手指抬起后才接受交换。减少动态效果开启时跳过自动过渡。
+- 测试使用独立存档和可控时钟，不挂载玩家的真实 Touch Bar。
+
+重新生成：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameStartSequenceTests`。
+
+将临时目录中的 `eliminate-touchbar-start.gif` 与 `eliminate-touchbar-start-states.png` 分别复制为本目录对应文件。
 
 ## 游戏设置、玩法说明与挑战记录
 
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -227,3 +227,11 @@
 "utility.records.result" = "成绩";
 "utility.records.date" = "挑战日期";
 "utility.records.empty_hint" = "完成一局挑战，写下你的第一条记录。";
+
+/* 滑动开局与主窗口快捷入口。 */
+"home.start_hint" = "点击、按空格，或滑动触控栏开始";
+"home.starting" = "准备开始…";
+"home.starting_hint" = "正在展开触控栏，完成后开始计时";
+"touchbar.slide_start" = "向右滑动开始游戏";
+"touchbar.slide_again" = "向右滑动再来一局";
+"touchbar.board" = "触控栏游戏棋盘";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -220,3 +220,11 @@
 "utility.records.result" = "記録";
 "utility.records.date" = "プレイ日";
 "utility.records.empty_hint" = "チャレンジを完了して最初の記録を残そう。";
+
+/* 滑动开局与主窗口快捷入口。 */
+"home.start_hint" = "クリック、スペース、または Touch Bar をスライドして開始";
+"home.starting" = "準備中…";
+"home.starting_hint" = "盤面が開いたら計測を開始します";
+"touchbar.slide_start" = "右にスライドして開始";
+"touchbar.slide_again" = "右にスライドしてもう一度";
+"touchbar.board" = "Touch Bar のゲーム盤面";
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -227,3 +227,11 @@
 "utility.records.result" = "Result";
 "utility.records.date" = "Played on";
 "utility.records.empty_hint" = "Finish a challenge to set your first record.";
+
+/* 滑动开局与主窗口快捷入口。 */
+"home.start_hint" = "Click, press Space, or slide the Touch Bar to start";
+"home.starting" = "Getting ready…";
+"home.starting_hint" = "Revealing the board. Timing begins when ready.";
+"touchbar.slide_start" = "Slide right to start";
+"touchbar.slide_again" = "Slide right to play again";
+"touchbar.board" = "Touch Bar game board";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -220,3 +220,11 @@
 "utility.records.result" = "기록";
 "utility.records.date" = "도전 날짜";
 "utility.records.empty_hint" = "도전을 완료하고 첫 기록을 남겨 보세요.";
+
+/* 滑动开局与主窗口快捷入口。 */
+"home.start_hint" = "클릭, 스페이스 또는 Touch Bar 슬라이드로 시작";
+"home.starting" = "준비 중…";
+"home.starting_hint" = "보드가 모두 나타나면 시간이 시작됩니다";
+"touchbar.slide_start" = "오른쪽으로 밀어서 시작";
+"touchbar.slide_again" = "오른쪽으로 밀어서 다시 시작";
+"touchbar.board" = "Touch Bar 게임 보드";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -220,3 +220,11 @@
 "utility.records.result" = "Результат";
 "utility.records.date" = "Дата игры";
 "utility.records.empty_hint" = "Завершите испытание, чтобы установить первый рекорд.";
+
+/* 滑动开局与主窗口快捷入口。 */
+"home.start_hint" = "Нажмите кнопку, пробел или проведите по Touch Bar";
+"home.starting" = "Подготовка…";
+"home.starting_hint" = "Открываем поле. Отсчёт начнётся после анимации.";
+"touchbar.slide_start" = "Сдвиньте вправо для старта";
+"touchbar.slide_again" = "Сдвиньте вправо, чтобы сыграть ещё";
+"touchbar.board" = "Игровое поле Touch Bar";
```

### `README.md`

```diff
--- a/README.md
+++ b/README.md
@@ -9,7 +9,7 @@
 
 把消除游戏搬进 MacBook Touch Bar 的一次认真尝试。
 
-> 当前为 `experiment/ui-refactor` 探索分支：桌面窗口采用浅色首页、模式卡片与本局实时统计；竞分固定 60 秒，竞速固定 300 分，全部模式点击“开始游戏”后开始。
+> 当前为 `experiment/ui-refactor` 探索分支：桌面窗口采用浅色首页、模式卡片与本局实时统计；竞分固定 60 秒，竞速固定 300 分。点击“开始游戏”、按空格或向右滑动触控栏均可开局，开场完成后才开始计时。
 
 `Eliminate Teris 1` 是一款为 macOS 与 Touch Bar 场景设计的轻量消除游戏：战场不在大屏幕中央，而是在键盘上方那条熟悉又常被忽视的细长区域里。你会在 16 格的一维棋盘上交换相邻方块、制造三连消除、追逐更高分数，也会在竞速与限时模式里，把每一次操作都压缩成更紧凑、更直接的节奏。
 
@@ -107,6 +107,7 @@
 桌面窗口按“左侧介绍与开始按钮、右侧模式与实时统计、底部成就”的结构展示：
 
 - **游戏模式**：直接选择自由、竞速、竞分，点击开始或重新开始；不提供时间和目标档位设置。
+- **滑动开局**：待机时触控栏显示滑块，拖至右侧逐步显现方块，未完成松手则回弹。点击开始或在主窗口待机时按空格，会自动播放同样的开场；触摸抬起后再接受棋盘操作。
 - **累计消除**：显示当前本局的总数量及四种类型明细，重开或切换模式清零；跨局成就进度独立保留。
 - **顶部导航**：挑战记录、玩法说明、游戏设置在独立辅助面板中打开；设置只提供语言和总音量。
 - **成就之路**：显示解锁数量、完成比例和五枚徽章，支持查看全部及单项详情。
```

### `docs/previews/touchbar-start.gif`

```diff
- 未提供滑动开局预览。
+ 新增真实 GameTouchBarView 导出的开场预览，仅用于开发评审。
```

- 字节数：325102
- SHA-256：`50db64614235afdfd937e9b0c23c81d6b97029e3f32749bdce7b729c1578e343`

### `docs/previews/touchbar-start-states.png`

```diff
- 未提供滑动开局预览。
+ 新增真实 GameTouchBarView 导出的开场预览，仅用于开发评审。
```

- 字节数：36478
- SHA-256：`3aedbdf464a1efc037517a047118a876fd6f3803d894991cb9a77bff416a18f0`
