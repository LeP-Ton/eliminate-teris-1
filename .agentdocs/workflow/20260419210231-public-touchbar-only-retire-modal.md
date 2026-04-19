# 回退为公开 Touch Bar 唯一路径，停用私有 modal

## 背景与目标
- 打包版 Touch Bar 在私有 `system modal` 路线上仍有概率黑屏，即便加入预热、健康检查与回退，也会引入明显的二段刷新观感。
- 本次目标改为“稳定优先”：正式停用私有 modal，统一回到公开 `window.touchBar` 唯一路径，保留公开路径首帧稳定性优化与诊断日志。

## 约束与原则
- 不再保留私有 modal 的运行时决策、晋升、健康检查与环境变量开关。
- 保留 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`，但日志只描述公开 `window.touchBar` 的挂载与绘制生命周期。
- 保留当前 16 列 Touch Bar 棋盘与 0 宽 `escape-placeholder` 占位，不额外改动棋盘交互与动画逻辑。

## 阶段与 TODO
- [x] 删除 `GameViewController` 中私有 modal 展示链路与状态机。
- [x] 保留公开 `window.touchBar` 的异步首刷与一次延迟刷新。
- [x] 同步更新 `AGENTS.md` 与 `.agentdocs/index.md` 的项目认知。
- [x] 重新构建并验证打包脚本仍可产出 `.app/.zip`。

## 关键风险
- 回退为公开路径后，Touch Bar 最左贴边效果可能不如私有 modal 理想。
- 公开路径下仍需依赖首帧尺寸与重绘时序，若后续再出现黑屏，需要继续围绕公开路径诊断，而不是回到私有 API。

## 当前进展
- `GameViewController` 已统一走公开 `window.touchBar`，并用展示代次 + 两次刷新避免旧任务误伤新生命周期。
- `AGENTS.md` 与 `.agentdocs/index.md` 已明确：私有 modal 属于历史废案，当前正式方案为公开 Touch Bar。
- 诊断日志仍可通过 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 开启，但内容已收敛到公开路径。

## 代码变更
- `Sources/GameViewController.swift`
```diff
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -1,5 +1,4 @@
-import ObjectiveC.runtime
@@ -43,12 +42,15 @@
-    private var isPresentingSystemModalTouchBar = false
+    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
+    private var touchBarPresentationGeneration = 0
+    private var touchBarInitialRefreshWorkItem: DispatchWorkItem?
+    private var touchBarSecondaryRefreshWorkItem: DispatchWorkItem?
@@ -520,7 +522,7 @@
-        dismissSystemModalTouchBarIfNeeded()
+        cancelTouchBarRefreshWorkItems()
@@ -531,22 +533,18 @@
-        // 默认优先走私有 modal 路径，保持最左侧贴边显示；异常时可通过环境变量关闭。
-        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
-            view.window?.touchBar = nil
-            gameTouchBarView.prepareForDisplay()
-        } else {
-            view.window?.touchBar = gameTouchBar
-            gameTouchBarView.prepareForDisplay()
-        }
+        logTouchBarDiagnostics("viewDidAppear，windowExists=\\(view.window != nil)")
+        refreshTouchBarPresentationForCurrentWindow()
@@ -544,7 +542,9 @@
-        dismissSystemModalTouchBarIfNeeded()
+        logTouchBarDiagnostics("viewDidDisappear，开始失效公开 Touch Bar 刷新链路")
+        invalidateTouchBarRefreshLifecycle()
@@ -584,50 +582,73 @@
-    private func presentSystemModalTouchBarIfPossible() -> Bool {
-        guard isPresentingSystemModalTouchBar == false else { return true }
-        let modernSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
-        if let modernMethod = class_getClassMethod(NSTouchBar.self, modernSelector) {
-            typealias PresentModernModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
-            let implementation = method_getImplementation(modernMethod)
-            let function = unsafeBitCast(implementation, to: PresentModernModalTouchBar.self)
-            function(NSTouchBar.self, modernSelector, gameTouchBar, nil)
-            isPresentingSystemModalTouchBar = true
-            return true
-        }
-        let fallbackSelector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
-        guard let fallbackMethod = class_getClassMethod(NSTouchBar.self, fallbackSelector) else { return false }
-        typealias PresentFallbackModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
-        let fallbackImplementation = method_getImplementation(fallbackMethod)
-        let fallbackFunction = unsafeBitCast(fallbackImplementation, to: PresentFallbackModalTouchBar.self)
-        fallbackFunction(NSTouchBar.self, fallbackSelector, gameTouchBar, 0, nil)
-        isPresentingSystemModalTouchBar = true
-        return true
-    }
-
+    private func refreshTouchBarPresentationForCurrentWindow() {
+        guard isViewLoaded, view.window != nil else { return }
+        touchBarPresentationGeneration += 1
+        let generation = touchBarPresentationGeneration
+        cancelTouchBarRefreshWorkItems()
+        view.window?.touchBar = gameTouchBar
+        logTouchBarDiagnostics("已挂载公开 window.touchBar，私有 modal 已停用，generation=\\(generation)")
+        scheduleTouchBarDisplayRefreshes(for: generation)
+    }
+
+    private func refreshTouchBarDisplayLifecycleIfNeeded() {
+        guard isViewLoaded, view.window != nil else { return }
+        touchBarPresentationGeneration += 1
+        let generation = touchBarPresentationGeneration
+        cancelTouchBarRefreshWorkItems()
+        view.window?.touchBar = gameTouchBar
+        logTouchBarDiagnostics("刷新公开 window.touchBar 生命周期，generation=\\(generation)")
+        scheduleTouchBarDisplayRefreshes(for: generation)
+    }
+
+    private func scheduleTouchBarDisplayRefreshes(for generation: Int) {
+        let initialRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
+            self.logTouchBarDiagnostics("公开 Touch Bar 首次异步刷新，presentationGeneration=\\(generation)，displayGeneration=\\(displayGeneration)，bounds=\\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))")
+        }
+        touchBarInitialRefreshWorkItem = initialRefresh
+        DispatchQueue.main.async(execute: initialRefresh)
+
+        let secondaryRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
+            self.logTouchBarDiagnostics("公开 Touch Bar 二次延迟刷新，presentationGeneration=\\(generation)，displayGeneration=\\(displayGeneration)，bounds=\\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))")
+        }
+        touchBarSecondaryRefreshWorkItem = secondaryRefresh
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)
+    }
+
+    private func invalidateTouchBarRefreshLifecycle() {
+        touchBarPresentationGeneration += 1
+        cancelTouchBarRefreshWorkItems()
+        view.window?.touchBar = nil
+    }
+
+    private func cancelTouchBarRefreshWorkItems() {
+        if touchBarInitialRefreshWorkItem != nil || touchBarSecondaryRefreshWorkItem != nil {
+            logTouchBarDiagnostics("取消待执行的公开 Touch Bar 刷新任务")
+        }
+        touchBarInitialRefreshWorkItem?.cancel()
+        touchBarSecondaryRefreshWorkItem?.cancel()
+        touchBarInitialRefreshWorkItem = nil
+        touchBarSecondaryRefreshWorkItem = nil
+    }
@@ -688,6 +709,7 @@
+        refreshTouchBarDisplayLifecycleIfNeeded()
```

- `AGENTS.md`
```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -31,8 +31,8 @@
- 已接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，当前策略改为“单槽位 16 列 + 系统级 modal 展示”，用于规避 ESC 预留留白与跨槽位缝隙并存问题。
- 私有 API 展示链路已升级为“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；`window.touchBar` 仅在私有调用不可用时启用，避免与系统级 modal 渲染冲突。
+ 历史上曾接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，并尝试通过 system modal 解决左贴边与 ESC 留白问题；该路线现已停用，仅作为历史排查背景保留在 workflow 文档中。
+ 历史上的私有 API 展示链路曾实现“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；当前正式代码已不再调用这条链路。
@@ -40,7 +40,10 @@
- 曾尝试以“release 默认公开路径”规避打包版 Touch Bar 黑屏（`ELIMINATE_TOUCHBAR_MODAL=1` 可强制私有 modal）；当前策略已迭代为默认私有 modal + 显式关闭开关。
- Touch Bar 展示策略已升级为“默认私有 modal + 可显式关闭”：默认启用私有 modal 保持左侧贴边，设置 `ELIMINATE_TOUCHBAR_MODAL=0` 可回退公开路径；同时在挂载后调用 `prepareForDisplay` 并开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`，降低打包版黑屏概率。
+ Touch Bar 当前正式方案为“单槽位 16 列 + 0 宽 `escape-placeholder` + 公开 `window.touchBar`”：优先保证打包版稳定显示，接受左侧贴边效果相较私有 modal 略有回退。
@@ -44,3 +47,6 @@
+ 已新增可开关的 Touch Bar 诊断日志：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 后，会通过 `NSLog` 输出公开 `window.touchBar` 挂载、刷新调度、尺寸变化与首帧有效绘制信息，日志前缀统一为 `[TouchBarDiag]`。
+ 当前正式方案已回退为“仅使用公开 `window.touchBar`”：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与公开→私有晋升链路均视为历史废案，不再参与运行时决策。
```

- `.agentdocs/index.md`
```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,10 @@
+`workflow/20260419210231-public-touchbar-only-retire-modal.md` - 正式回退为公开 `window.touchBar` 唯一路径，停用私有 modal 与相关状态机，优先保证打包版稳定显示。
@@ -44,6 +48,10 @@
+- 需要确认“当前正式方案是否已经彻底放弃私有 modal，只保留公开 Touch Bar”时，优先读取 `20260419210231` 文档。
@@ -88,10 +96,14 @@
- 当前正式 Touch Bar 方案已经统一为公开 `window.touchBar`：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与预热晋升链路都已停用并视为历史废案；启动时仅保留公开 Touch Bar 的异步首刷与一次延迟刷新。
- Touch Bar 最新启动策略不是“直接 present system modal”，而是先把 `window.touchBar` 挂上做首帧预热，再延迟 `0.28s` 尝试晋升私有 modal；若预热尚未就绪，则以 `0.12s` 间隔最多重试 3 次后保留公开 Touch Bar。
- Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，可用于观察 system modal 是否成功、异步双次刷新是否执行、健康检查是否触发 fallback，以及 `GameTouchBarView` 是否拿到了有效尺寸并完成首帧绘制。
+- 当前正式 Touch Bar 方案已经统一为公开 `window.touchBar`：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与预热晋升链路都已停用并视为历史废案；启动时仅保留公开 Touch Bar 的异步首刷与一次延迟刷新。
+- Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，主要观察公开 `window.touchBar` 的挂载、刷新调度、尺寸变化与有效首帧绘制。
```

## 测试用例
### TC-001 公开 Touch Bar 冷启动稳定显示
- 类型：功能测试
- 优先级：高
- 关联模块：`GameViewController`、`GameTouchBarView`
- 前置条件：已重新执行 `swift build` 或 `./package.sh`
- 操作步骤：
1. 连续冷启动开发态或 `dist/Eliminate Teris 1.app`
2. 观察 Touch Bar 首帧是否直接显示棋盘
- 预期结果：
- Touch Bar 不再走公开→私有二段切换
- 不出现概率黑屏
- 是否通过：已执行构建验证，真机冷启动待用户持续验证

### TC-002 公开路径诊断日志
- 类型：诊断测试
- 优先级：中
- 关联模块：`TouchBarDiagnostics`
- 前置条件：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`
- 操作步骤：
1. 使用环境变量启动应用
2. 查看控制台或日志文件中的 `[TouchBarDiag]`
- 预期结果：
- 日志只包含公开 `window.touchBar` 挂载、刷新调度、尺寸变化与有效绘制
- 不再出现 modal / promotion / fallback 相关词汇
- 是否通过：待验证
