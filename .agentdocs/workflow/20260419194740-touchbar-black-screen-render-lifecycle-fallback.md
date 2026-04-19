# 修复打包版 Touch Bar 概率黑屏的渲染时序与自动回退

## 背景与目标
- 用户反馈：当前测试 `dist` 中的 `.app` 与 `.dmg` 时，Touch Bar 仍有概率出现整条黑屏。
- 现有策略默认启用私有 modal Touch Bar，以维持最左贴边和隐藏 ESC 的布局效果，因此不能简单粗暴地永久回退到公开 `window.touchBar`。
- 本次目标是在保留私有 modal 优先级的前提下，修复“首帧刷新过早 + 后续未拿到有效重绘”导致的概率黑屏问题。

## 根因分析
- `GameViewController.viewDidAppear()` 里原先同步调用 `prepareForDisplay()`，但此时 Touch Bar 视图可能仍处于零尺寸或尚未完成系统容器 attach/sizing。
- `GameTouchBarView.draw(_:)` 会先画黑底；如果后续没有一次在有效 bounds 下触发重绘，就会停留在“只有黑底”的状态。
- 打包版更容易暴露该时序问题，因为私有 modal 展示链路在 release/手工组装 `.app` 中的挂载节奏更不稳定。

## 方案与约束
- 在 `GameTouchBarView` 中新增“尺寸变化必重绘”机制：零尺寸阶段先挂起刷新，等到 bounds 有效后补一帧。
- 在 `GameViewController` 中把首次 `prepareForDisplay()` 延后一轮 run loop，并额外做一次 `120ms` 二次刷新。
- 私有 modal 展示后做 `220ms` 健康检查；若仍未拿到有效 bounds 或未完成可见内容绘制，则自动回退到 `window.touchBar`。
- 保持 `ELIMINATE_TOUCHBAR_MODAL=0` 现有语义不变，本次不修改打包脚本与资源 Bundle 策略。

## 当前进展
- 已补齐 Touch Bar 视图的延后刷新、尺寸感知和渲染成功标记。
- 已补齐控制器层的异步双次刷新、健康检查、自动回退与代次失效机制。
- 已同步更新 `AGENTS.md` 与 `.agentdocs/index.md`，记录本次修复策略和读取入口。

## 代码变更
- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index ebc1a17..5153695 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260419194740-touchbar-black-screen-render-lifecycle-fallback.md` - 修复打包版 Touch Bar 概率黑屏：补齐尺寸变化重绘、异步双次预热、modal 健康检查与自动回退公开 Touch Bar。
 `workflow/20260418235435-fix-packaged-app-resource-bundle-crash.md` - 修复打包后启动即崩：绕开 `Bundle.module` 对手工 `.app` 的路径假设，兼容 `Contents/Resources` 资源布局。
 `workflow/20260418231251-universal-macos-package.md` - 打包脚本改为默认生成 `x86_64 + arm64` 通用 `.app`，解决发给 M1 机器后架构不匹配导致的崩溃风险。
 `workflow/20260301160231-touchbar-modal-and-black-screen-balance.md` - 同时兼顾左侧贴边与打包黑屏：默认私有 modal，增加显式回退开关与强制重绘预热。
@@ -44,6 +45,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要排查“打包版 Touch Bar 偶发黑屏，但又不想失去左贴边 modal 展示”时，优先读取 `20260419194740` 文档。
 - 需要排查“通用包已生成但 `.app` 启动仍意外退出”时，优先读取 `20260418235435` 文档。
 - 需要排查“压缩 `.app` 发给 M1 后应用意外退出/架构不匹配”时，优先读取 `20260418231251` 文档。
 - 需要同时处理“左侧空白间距 + 打包黑屏”时，优先读取 `20260301160231` 文档。
@@ -88,6 +90,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 打包版 Touch Bar 黑屏目前按“渲染时序”处理：`GameTouchBarView` 会把零尺寸阶段的刷新记为 pending，待 bounds 有效后补绘；`GameViewController` 会异步执行两次 `prepareForDisplay()`，并在私有 modal 下做 220ms 健康检查，失败时自动回退 `window.touchBar`。
 - 最新打包启动崩溃根因是资源 Bundle 路径：SwiftPM 生成的 `Bundle.module` 更适合直接从 `.build` 运行，手工组装 `.app` 时应显式兼容 `Bundle.main.resourceURL/Contents/Resources`。
 - 当前打包脚本默认输出通用二进制：分别构建 `x86_64` 与 `arm64`，再用 `lipo` 合成，最终 `file dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1` 应显示 `Mach-O universal binary with 2 architectures`。
 - Touch Bar 当前默认仍启用私有 modal（用于维持左侧贴边），但增加了 `ELIMINATE_TOUCHBAR_MODAL=0` 显式回退开关；挂载后会执行 `prepareForDisplay` 且开启 `onSetNeedsDisplay` 重绘策略，缓解打包版黑屏。
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 5aa1ae0..3485411 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -44,3 +44,4 @@
 - Touch Bar 展示策略已升级为“默认私有 modal + 可显式关闭”：默认启用私有 modal 保持左侧贴边，设置 `ELIMINATE_TOUCHBAR_MODAL=0` 可回退公开路径；同时在挂载后调用 `prepareForDisplay` 并开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`，降低打包版黑屏概率。
 - `package.sh` 现在默认构建 `x86_64 + arm64` 通用二进制，并通过 `lipo` 合成为单个 `.app`，用于同时兼容 Intel 与 Apple Silicon（M1/M2/M3）Mac；可用 `PACKAGE_ARCHS` 覆盖目标架构。
 - 打包后“应用意外退出”的最新根因已确认：不是通用二进制本身，而是 `Bundle.module` 在手工 `.app` 中查找资源 Bundle 的路径与 `Contents/Resources` 不一致；现已在 `Localization.swift` 中改为兼容开发态与打包态的多路径资源查找。
+- 打包版 Touch Bar 黑屏的最新修复策略是“双层兜底”：`GameTouchBarView` 会在尺寸从 0 变为有效值时强制补一次重绘，并记录 `hasDrawnVisibleContent/displayGeneration`；`GameViewController` 则把首次 `prepareForDisplay()` 延后一轮 run loop，再做一次 120ms 二次刷新与 220ms modal 健康检查，若仍未完成有效绘制则自动回退到 `window.touchBar`。
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 3fd64e0..ec7da6b 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -340,6 +340,13 @@ final class GameTouchBarView: NSView {
     private var transitionStartTime: TimeInterval = 0
     private var transitionProgress: CGFloat = 1
     private var transitionTimer: Timer?
+    // 记录上一次已知尺寸，用于识别“首次拿到有效 bounds”与后续尺寸变化。
+    private var lastKnownBoundsSize: CGSize = .zero
+    // 当 prepareForDisplay 发生在零尺寸阶段时，先挂起刷新，等真正拿到尺寸后再补绘。
+    private var pendingDisplayRefresh = false
+    // 仅在实际完成格子/方块绘制后才置为 true，避免把“纯黑底首帧”误判成成功渲染。
+    private(set) var hasDrawnVisibleContent = false
+    private(set) var displayGeneration = 0
 
     init(columnRange: Range<Int>, controller: GameBoardController, leadingCompensationX: CGFloat = 0) {
         precondition(!columnRange.isEmpty, "columnRange must contain at least one column")
@@ -359,7 +366,7 @@ final class GameTouchBarView: NSView {
         wantsRestingTouches = true
         setContentHuggingPriority(.defaultLow, for: .horizontal)
         setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
-        needsDisplay = true
+        requestDisplayRefresh()
 
         observerToken = controller.addObserver(owner: self) { [weak self] in
             self?.handleControllerChange()
@@ -385,12 +392,32 @@ final class GameTouchBarView: NSView {
         return true
     }
 
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        handleBoundsChangeIfNeeded()
+    }
+
+    override func layout() {
+        super.layout()
+        handleBoundsChangeIfNeeded()
+    }
+
+    override func setFrameSize(_ newSize: NSSize) {
+        super.setFrameSize(newSize)
+        handleBoundsChangeIfNeeded()
+    }
+
     override func draw(_ dirtyRect: NSRect) {
         super.draw(dirtyRect)
 
         NSColor.black.withAlphaComponent(0.9).setFill()
         bounds.fill()
 
+        guard canRenderVisibleCells else {
+            hasDrawnVisibleContent = false
+            return
+        }
+
         for localIndex in 0..<columnCount {
             let globalIndex = columnRange.lowerBound + localIndex
             let rect = cellRect(forLocalIndex: localIndex)
@@ -414,6 +441,7 @@ final class GameTouchBarView: NSView {
                     scale: 1
                 )
             }
+            hasDrawnVisibleContent = true
             return
         }
 
@@ -425,6 +453,7 @@ final class GameTouchBarView: NSView {
         for transition in visibleTransitions where transition.transitionKind == .remove {
             drawTransitionPiece(transition)
         }
+        hasDrawnVisibleContent = true
     }
 
     override func touchesBegan(with event: NSEvent) {
@@ -506,21 +535,27 @@ final class GameTouchBarView: NSView {
         controller.handleTap(at: index)
     }
 
-    func prepareForDisplay() {
+    @discardableResult
+    func prepareForDisplay() -> Int {
+        transitionTimer?.invalidate()
+        transitionTimer = nil
         renderedTiles = controller.tiles()
         pieceTransitions = []
         transitionPhases = []
         transitionPhaseIndex = 0
         transitionProgress = 1
         shouldPlayTransitionEffects = false
-        needsDisplay = true
+        hasDrawnVisibleContent = false
+        displayGeneration += 1
+        requestDisplayRefresh()
+        return displayGeneration
     }
 
     private func handleControllerChange() {
         let latestTiles = controller.tiles()
         let swapPair = controller.consumeLastSwapPair()
         if latestTiles == renderedTiles {
-            needsDisplay = true
+            requestDisplayRefresh()
             return
         }
 
@@ -727,7 +762,7 @@ final class GameTouchBarView: NSView {
             pieceTransitions = []
             transitionProgress = 1
             shouldPlayTransitionEffects = false
-            needsDisplay = true
+            requestDisplayRefresh()
             return
         }
 
@@ -764,14 +799,14 @@ final class GameTouchBarView: NSView {
         transitionStartTime = Date().timeIntervalSinceReferenceDate
         transitionProgress = 0
         playPhaseSoundEffectIfNeeded(transitions: phase.transitions)
-        needsDisplay = true
+        requestDisplayRefresh()
     }
 
     @objc private func handleTransitionTick() {
         let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
         let progress = min(1, max(0, elapsed / activePhaseDuration))
         transitionProgress = CGFloat(progress)
-        needsDisplay = true
+        requestDisplayRefresh()
 
         guard progress >= 1 else { return }
         if transitionPhaseIndex + 1 < transitionPhases.count {
@@ -999,4 +1034,43 @@ final class GameTouchBarView: NSView {
     private func isBoardIndex(_ index: Int) -> Bool {
         return index >= 0 && index < controller.columns
     }
+
+    private var canRenderVisibleCells: Bool {
+        guard columnCount > 0 else { return false }
+        guard bounds.width > 1, bounds.height > 1 else { return false }
+
+        let sampleRect = cellRect(forLocalIndex: 0)
+        let visibleWidth = sampleRect.width - Layout.tileOuterInsetX * 2
+        let visibleHeight = sampleRect.height - Layout.tileOuterInsetY * 2
+        return visibleWidth > 2 && visibleHeight > 2
+    }
+
+    private func requestDisplayRefresh() {
+        // Touch Bar 视图常见问题是“先收到刷新请求，后拿到尺寸”，这里统一把刷新请求延后兑现。
+        if bounds.width > 0.5, bounds.height > 0.5 {
+            pendingDisplayRefresh = false
+            needsDisplay = true
+            return
+        }
+
+        pendingDisplayRefresh = true
+    }
+
+    private func handleBoundsChangeIfNeeded() {
+        let currentSize = bounds.size
+        let widthChanged = abs(currentSize.width - lastKnownBoundsSize.width) > 0.5
+        let heightChanged = abs(currentSize.height - lastKnownBoundsSize.height) > 0.5
+        let sizeChanged = widthChanged || heightChanged
+        let previouslyRenderable = lastKnownBoundsSize.width > 0.5 && lastKnownBoundsSize.height > 0.5
+        let nowRenderable = currentSize.width > 0.5 && currentSize.height > 0.5
+
+        lastKnownBoundsSize = currentSize
+
+        // 只要这次尺寸有效，且之前有挂起刷新或尺寸真的变化了，就强制补一帧重绘。
+        guard nowRenderable else { return }
+        guard pendingDisplayRefresh || sizeChanged || !previouslyRenderable else { return }
+
+        pendingDisplayRefresh = false
+        needsDisplay = true
+    }
 }
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index f435a69..9750740 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -15,6 +15,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         case action = 3
     }
 
+    private enum TouchBarPresentationMode {
+        case systemModal
+        case windowAttached
+    }
+
     private enum BadgeTone {
         case ready
         case running
@@ -43,12 +48,19 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let speedRunTargets = [300, 600, 900]
     private let recordStore = ModeRecordStore.shared
     private let audioSystem = GameAudioSystem.shared
+    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
+    private let touchBarModalHealthCheckDelay: TimeInterval = 0.22
 
     private lazy var controller = GameBoardController(columns: columns)
     private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
 
     private var observerToken: UUID?
     private var isPresentingSystemModalTouchBar = false
+    private var activeTouchBarPresentationMode: TouchBarPresentationMode = .windowAttached
+    private var touchBarPresentationGeneration = 0
+    private var touchBarInitialRefreshWorkItem: DispatchWorkItem?
+    private var touchBarSecondaryRefreshWorkItem: DispatchWorkItem?
+    private var touchBarHealthCheckWorkItem: DispatchWorkItem?
     private var hudTimer: Timer?
     private var selectedScoreAttackIndex = 0
     private var selectedSpeedRunIndex = 0
@@ -520,6 +532,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         if let observerToken {
             controller.removeObserver(observerToken)
         }
+        cancelTouchBarPresentationWorkItems()
         dismissSystemModalTouchBarIfNeeded()
         hudTimer?.invalidate()
         audioSystem.stopBackgroundMusic()
@@ -531,22 +544,16 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     override func viewDidAppear() {
         super.viewDidAppear()
-        // 默认优先走私有 modal 路径，保持最左侧贴边显示；异常时可通过环境变量关闭。
-        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
-            view.window?.touchBar = nil
-            gameTouchBarView.prepareForDisplay()
-        } else {
-            view.window?.touchBar = gameTouchBar
-            gameTouchBarView.prepareForDisplay()
-        }
+        // 默认优先走私有 modal 路径，保持最左侧贴边显示；若本次挂载未完成有效渲染，再自动回退公开路径。
+        refreshTouchBarPresentationForCurrentWindow()
         view.window?.makeFirstResponder(self)
         view.window?.minSize = NSSize(width: 720, height: 450)
         updateWindowTitle()
     }
 
     override func viewDidDisappear() {
+        invalidateTouchBarPresentationLifecycle()
         super.viewDidDisappear()
-        dismissSystemModalTouchBarIfNeeded()
     }
 
     override func viewDidLayout() {
@@ -630,6 +637,106 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return true
     }
 
+    private func refreshTouchBarPresentationForCurrentWindow() {
+        guard isViewLoaded, view.window != nil else { return }
+
+        touchBarPresentationGeneration += 1
+        let generation = touchBarPresentationGeneration
+        cancelTouchBarPresentationWorkItems()
+
+        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
+            activeTouchBarPresentationMode = .systemModal
+            view.window?.touchBar = nil
+            scheduleTouchBarDisplayRefreshes(for: generation)
+            scheduleTouchBarModalHealthCheck(for: generation)
+            return
+        }
+
+        attachTouchBarToWindow(for: generation)
+    }
+
+    private func refreshTouchBarDisplayLifecycleIfNeeded() {
+        guard isViewLoaded, view.window != nil else { return }
+
+        touchBarPresentationGeneration += 1
+        let generation = touchBarPresentationGeneration
+        cancelTouchBarPresentationWorkItems()
+        scheduleTouchBarDisplayRefreshes(for: generation)
+
+        if activeTouchBarPresentationMode == .systemModal {
+            scheduleTouchBarModalHealthCheck(for: generation)
+        }
+    }
+
+    private func attachTouchBarToWindow(for generation: Int) {
+        dismissSystemModalTouchBarIfNeeded()
+        activeTouchBarPresentationMode = .windowAttached
+        view.window?.touchBar = gameTouchBar
+        scheduleTouchBarDisplayRefreshes(for: generation)
+    }
+
+    private func scheduleTouchBarDisplayRefreshes(for generation: Int) {
+        // 首次刷新改为下一轮 run loop，再补一次延迟刷新，尽量等系统容器完成 attach/sizing。
+        let initialRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            self.gameTouchBarView.prepareForDisplay()
+        }
+        touchBarInitialRefreshWorkItem = initialRefresh
+        DispatchQueue.main.async(execute: initialRefresh)
+
+        let secondaryRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            self.gameTouchBarView.prepareForDisplay()
+        }
+        touchBarSecondaryRefreshWorkItem = secondaryRefresh
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)
+    }
+
+    private func scheduleTouchBarModalHealthCheck(for generation: Int) {
+        let healthCheck = DispatchWorkItem { [weak self] in
+            self?.performTouchBarModalHealthCheck(for: generation)
+        }
+        touchBarHealthCheckWorkItem = healthCheck
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarModalHealthCheckDelay, execute: healthCheck)
+    }
+
+    private func performTouchBarModalHealthCheck(for generation: Int) {
+        guard touchBarPresentationGeneration == generation else { return }
+        guard activeTouchBarPresentationMode == .systemModal else { return }
+
+        let hasRenderableBounds = gameTouchBarView.bounds.width > 0.5 && gameTouchBarView.bounds.height > 0.5
+        let hasVisibleContent = gameTouchBarView.hasDrawnVisibleContent
+        // 私有 modal 优先保留左贴边，但一旦这次挂载没有真正画出内容，就立刻回退公开路径保底。
+        guard hasRenderableBounds, hasVisibleContent else {
+            fallbackTouchBarPresentationToWindow(for: generation)
+            return
+        }
+    }
+
+    private func fallbackTouchBarPresentationToWindow(for generation: Int) {
+        guard touchBarPresentationGeneration == generation else { return }
+
+        cancelTouchBarPresentationWorkItems()
+        attachTouchBarToWindow(for: generation)
+    }
+
+    private func invalidateTouchBarPresentationLifecycle() {
+        touchBarPresentationGeneration += 1
+        cancelTouchBarPresentationWorkItems()
+        dismissSystemModalTouchBarIfNeeded()
+        activeTouchBarPresentationMode = .windowAttached
+        view.window?.touchBar = nil
+    }
+
+    private func cancelTouchBarPresentationWorkItems() {
+        touchBarInitialRefreshWorkItem?.cancel()
+        touchBarSecondaryRefreshWorkItem?.cancel()
+        touchBarHealthCheckWorkItem?.cancel()
+        touchBarInitialRefreshWorkItem = nil
+        touchBarSecondaryRefreshWorkItem = nil
+        touchBarHealthCheckWorkItem = nil
+    }
+
     @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
         let index = max(0, sender.indexOfSelectedItem)
         let language = AppLanguage.allCases[min(index, AppLanguage.allCases.count - 1)]
@@ -688,6 +795,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         updateCompetitiveInfo()
         preserveWindowFrame(windowFrameBeforeUpdate)
         refreshRecordPanelAfterLayoutIfNeeded()
+        refreshTouchBarDisplayLifecycleIfNeeded()
     }
 
     private func configureLocalizedText() {
```

## 测试用例
### TC-001 Debug 构建验证
- 类型：构建测试
- 操作步骤：执行 `/bin/bash -c 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build'`
- 预期结果：调试构建成功，`GameTouchBarView.swift` 与 `GameViewController.swift` 无编译错误。
- 是否通过：已通过。

### TC-002 打包链路验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./package.sh`
- 预期结果：
- 成功完成 `x86_64` 与 `arm64` release 构建
- 成功生成通用 `.app`
- 当前环境若不能生成 DMG，则自动回退 ZIP，且流程不中断
- 是否通过：已通过。

### TC-003 Touch Bar 黑屏回归验证
- 类型：人工验证
- 操作步骤：
1. 冷启动开发版应用，观察 Touch Bar 首帧是否正常显示。
2. 冷启动 `dist/Eliminate Teris 1.app`，重复多次观察是否仍出现整条黑屏。
3. 若私有 modal 本次挂载失败，确认是否自动回退到公开 `window.touchBar` 而不是持续黑屏。
- 预期结果：
- 正常情况下继续保持左贴边 modal 展示
- 异常情况下自动回退为公开 Touch Bar，仍能看到 16 个方块而不是黑屏
- 是否通过：待用户在真机 Touch Bar 环境确认。
