# Touch Bar 启动改为“公开预热后再晋升私有 modal”

## 背景与目标
- 用户确认：即使已经加入渲染时序修复与诊断日志，打包版 `dist/Eliminate Teris 1.app` 仍然存在概率性 Touch Bar 黑屏。
- 结合用户回报与现有诊断日志，已经能确认有一类样本是“代码内部认为已经绘制成功，但私有 system modal 最终仍然黑屏”。
- 本次目标是不再在首帧阶段直接 `presentSystemModalTouchBar`，而是先让公开 `window.touchBar` 完成稳定首帧，再尝试晋升到私有 modal，以降低私有 modal 首挂载时的黑屏概率。

## 方案
- `GameViewController` 中新增“公开预热 → 私有晋升”的启动路径：
  1. 如果启用私有 modal，则先挂公开 `window.touchBar`
  2. 继续沿用首次异步刷新 + 二次延迟刷新，确保视图先完成一轮可见绘制
  3. 在 `0.28s` 后检查 `bounds` 与 `hasDrawnVisibleContent`
  4. 若预热就绪，再调用私有 API 晋升到 system modal
  5. 若仍未就绪，则按 `0.12s` 间隔最多重试 3 次
- 如果 3 次晋升检查后仍未就绪，则本轮保持公开 `window.touchBar`，避免强推私有 modal 导致黑屏。

## 当前进展
- 已把初始展示链路改为先公开预热，再延迟晋升私有 modal。
- 已为晋升链路补齐重试与日志，便于继续结合 `[TouchBarDiag]` 判断效果。
- 已同步更新 `AGENTS.md` 与 `.agentdocs/index.md`，记录当前最新 Touch Bar 启动策略。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index ac4836b..b1d0d0b 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -50,6 +50,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let audioSystem = GameAudioSystem.shared
     private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
     private let touchBarModalHealthCheckDelay: TimeInterval = 0.22
+    private let touchBarModalPromotionDelay: TimeInterval = 0.28
+    private let touchBarModalPromotionRetryDelay: TimeInterval = 0.12
+    private let touchBarModalPromotionMaxAttempts = 3
@@ -61,6 +64,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private var touchBarInitialRefreshWorkItem: DispatchWorkItem?
     private var touchBarSecondaryRefreshWorkItem: DispatchWorkItem?
     private var touchBarHealthCheckWorkItem: DispatchWorkItem?
+    private var touchBarModalPromotionWorkItem: DispatchWorkItem?
     private var hudTimer: Timer?
@@ -661,13 +665,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         cancelTouchBarPresentationWorkItems()
         logTouchBarDiagnostics("刷新 Touch Bar 展示链路，generation=\\(generation)，preferModal=\\(shouldUseSystemModalTouchBar())")
 
-        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
-            activeTouchBarPresentationMode = .systemModal
-            view.window?.touchBar = nil
-            logTouchBarDiagnostics("当前采用 system modal，window.touchBar 已置空")
-            scheduleTouchBarDisplayRefreshes(for: generation)
-            scheduleTouchBarModalHealthCheck(for: generation)
+        if shouldUseSystemModalTouchBar() {
+            warmupTouchBarForSystemModal(for: generation)
             return
         }
@@ -682,10 +682,31 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         cancelTouchBarPresentationWorkItems()
         logTouchBarDiagnostics("刷新当前展示生命周期，generation=\\(generation)，mode=\\(presentationModeDescription)")
 
-        scheduleTouchBarDisplayRefreshes(for: generation)
-
         if activeTouchBarPresentationMode == .systemModal {
+            scheduleTouchBarDisplayRefreshes(for: generation)
             scheduleTouchBarModalHealthCheck(for: generation)
+            return
+        }
+
+        if shouldUseSystemModalTouchBar() {
+            warmupTouchBarForSystemModal(for: generation)
+            return
+        }
+
+        attachTouchBarToWindow(for: generation)
+    }
+
+    private func warmupTouchBarForSystemModal(for generation: Int) {
+        activeTouchBarPresentationMode = .windowAttached
+        view.window?.touchBar = gameTouchBar
+        logTouchBarDiagnostics("先以公开 window.touchBar 预热，稍后尝试切换 system modal，generation=\\(generation)")
+        scheduleTouchBarDisplayRefreshes(for: generation)
+        scheduleTouchBarModalPromotion(for: generation, attempt: 1)
+    }
+
+    private func scheduleTouchBarModalPromotion(for generation: Int, attempt: Int) {
+        let delay = attempt == 1 ? touchBarModalPromotionDelay : touchBarModalPromotionRetryDelay
+        let promotion = DispatchWorkItem { [weak self] in
+            self?.promoteTouchBarToSystemModalIfReady(for: generation, attempt: attempt)
         }
@@ -719,6 +740,41 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         logTouchBarDiagnostics("已安排二次刷新，delay=\\(touchBarSecondaryRefreshDelay)s，generation=\\(generation)")
         DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)
     }
+
+    private func promoteTouchBarToSystemModalIfReady(for generation: Int, attempt: Int) {
+        touchBarModalPromotionWorkItem = nil
+        guard touchBarPresentationGeneration == generation else { return }
+        guard shouldUseSystemModalTouchBar() else { return }
+        guard activeTouchBarPresentationMode == .windowAttached else { return }
+
+        let hasRenderableBounds = gameTouchBarView.bounds.width > 0.5 && gameTouchBarView.bounds.height > 0.5
+        let hasVisibleContent = gameTouchBarView.hasDrawnVisibleContent
+        logTouchBarDiagnostics(
+            "执行 system modal 晋升检查，attempt=\\(attempt)，generation=\\(generation)，bounds=\\(TouchBarDiagnostics.describe(rect: gameTouchBarView.bounds))，hasRenderableBounds=\\(hasRenderableBounds)，hasVisibleContent=\\(hasVisibleContent)，displayGeneration=\\(gameTouchBarView.displayGeneration)"
+        )
+
+        guard hasRenderableBounds, hasVisibleContent else {
+            if attempt < touchBarModalPromotionMaxAttempts {
+                logTouchBarDiagnostics("预热仍未就绪，继续保持公开 window.touchBar 并稍后重试，nextAttempt=\\(attempt + 1)")
+                scheduleTouchBarModalPromotion(for: generation, attempt: attempt + 1)
+            } else {
+                logTouchBarDiagnostics("预热重试次数已耗尽，当前轮次保持公开 window.touchBar")
+            }
+            return
+        }
+
+        guard presentSystemModalTouchBarIfPossible() else {
+            logTouchBarDiagnostics("system modal 晋升失败，继续保持公开 window.touchBar")
+            return
+        }
+
+        activeTouchBarPresentationMode = .systemModal
+        view.window?.touchBar = nil
+        logTouchBarDiagnostics("预热完成，已切换到 system modal，attempt=\\(attempt)，generation=\\(generation)")
+        scheduleTouchBarDisplayRefreshes(for: generation)
+        scheduleTouchBarModalHealthCheck(for: generation)
+    }
@@ -767,12 +823,16 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             touchBarSecondaryRefreshWorkItem != nil ||
             touchBarHealthCheckWorkItem != nil ||
+            touchBarModalPromotionWorkItem != nil {
             logTouchBarDiagnostics("取消待执行的 Touch Bar 刷新/检查任务")
         }
         touchBarInitialRefreshWorkItem?.cancel()
         touchBarSecondaryRefreshWorkItem?.cancel()
         touchBarHealthCheckWorkItem?.cancel()
+        touchBarModalPromotionWorkItem?.cancel()
         touchBarInitialRefreshWorkItem = nil
         touchBarSecondaryRefreshWorkItem = nil
         touchBarHealthCheckWorkItem = nil
+        touchBarModalPromotionWorkItem = nil
     }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 12ed90f..7d3f5ea 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -46,3 +46,4 @@
 - 打包后“应用意外退出”的最新根因已确认：不是通用二进制本身，而是 `Bundle.module` 在手工 `.app` 中查找资源 Bundle 的路径与 `Contents/Resources` 不一致；现已在 `Localization.swift` 中改为兼容开发态与打包态的多路径资源查找。
 - 打包版 Touch Bar 黑屏的最新修复策略是“双层兜底”：`GameTouchBarView` 会在尺寸从 0 变为有效值时强制补一次重绘，并记录 `hasDrawnVisibleContent/displayGeneration`；`GameViewController` 则把首次 `prepareForDisplay()` 延后一轮 run loop，再做一次 120ms 二次刷新与 220ms modal 健康检查，若仍未完成有效绘制则自动回退到 `window.touchBar`。
 - 已新增可开关的 Touch Bar 诊断日志：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 后，会通过 `NSLog` 输出 system modal 挂载、异步刷新、健康检查、fallback、以及 `GameTouchBarView` 的尺寸变化与首帧有效绘制信息，日志前缀统一为 `[TouchBarDiag]`。
+- Touch Bar 启动链路已进一步改为“公开 Touch Bar 预热 → 私有 system modal 晋升”：先把 `window.touchBar` 挂上完成首帧绘制，再在 `0.28s` 后尝试晋升到私有 modal；若预热未完成则最多重试 3 次，以降低私有 modal 首挂载阶段的概率黑屏。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 366b2f9..d4962f3 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260419203037-touchbar-modal-warmup-promotion.md` - Touch Bar 启动改为先公开预热、再晋升私有 modal，降低 modal 首挂载阶段的概率黑屏。
 `workflow/20260419200923-touchbar-diagnostics-logging.md` - 新增可开关的 Touch Bar 诊断日志，覆盖 modal 挂载、异步刷新、健康检查、fallback 与视图首帧绘制。
 `workflow/20260419194740-touchbar-black-screen-render-lifecycle-fallback.md` - 修复打包版 Touch Bar 概率黑屏：补齐尺寸变化重绘、异步双次预热、modal 健康检查与自动回退公开 Touch Bar。
 `workflow/20260418235435-fix-packaged-app-resource-bundle-crash.md` - 修复打包后启动即崩：绕开 `Bundle.module` 对手工 `.app` 的路径假设，兼容 `Contents/Resources` 资源布局。
@@ -46,6 +47,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要处理“私有 modal 自身会偶发黑屏，但又不想彻底放弃左贴边效果”时，优先读取 `20260419203037` 文档。
 - 需要在真机上追踪“为什么这次启动仍然黑屏、是否触发了 fallback、首帧有没有真正画出来”时，优先读取 `20260419200923` 文档。
 - 需要排查“打包版 Touch Bar 偶发黑屏，但又不想失去左贴边 modal 展示”时，优先读取 `20260419194740` 文档。
 - 需要排查“通用包已生成但 `.app` 启动仍意外退出”时，优先读取 `20260418235435` 文档。
@@ -92,6 +94,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- Touch Bar 最新启动策略不是“直接 present system modal”，而是先把 `window.touchBar` 挂上做首帧预热，再延迟 `0.28s` 尝试晋升私有 modal；若预热尚未就绪，则以 `0.12s` 间隔最多重试 3 次后保留公开 Touch Bar。
 - Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，可用于观察 system modal 是否成功、异步双次刷新是否执行、健康检查是否触发 fallback，以及 `GameTouchBarView` 是否拿到了有效尺寸并完成首帧绘制。
 - 打包版 Touch Bar 黑屏目前按“渲染时序”处理：`GameTouchBarView` 会把零尺寸阶段的刷新记为 pending，待 bounds 有效后补绘；`GameViewController` 会异步执行两次 `prepareForDisplay()`，并在私有 modal 下做 220ms 健康检查，失败时自动回退 `window.touchBar`。
 - 最新打包启动崩溃根因是资源 Bundle 路径：SwiftPM 生成的 `Bundle.module` 更适合直接从 `.build` 运行，手工组装 `.app` 时应显式兼容 `Bundle.main.resourceURL/Contents/Resources`。
```

## 测试用例
### TC-001 Debug 构建验证
- 类型：构建测试
- 操作步骤：执行 `/bin/bash -c 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build'`
- 预期结果：`GameViewController.swift` 编译通过，新增预热晋升逻辑无语法错误。
- 是否通过：已通过。

### TC-002 诊断日志链路验证
- 类型：逻辑验证
- 操作步骤：启动应用并观察 `[TouchBarDiag]` 日志，确认是否先出现“公开预热”再出现“system modal 晋升检查/切换”。
- 预期结果：
- 私有 modal 开启时，日志先输出 `先以公开 window.touchBar 预热`
- 随后输出 `执行 system modal 晋升检查`
- 若预热成功，再输出 `预热完成，已切换到 system modal`
- 是否通过：待用户在真机环境确认。

### TC-003 打包产物回归验证
- 类型：发布验证
- 操作步骤：
1. 重新执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./package.sh`
2. 启动新的 `dist/Eliminate Teris 1.app`
3. 连续多次冷启动，观察黑屏概率是否下降
- 预期结果：
- 打包流程仍成功
- 新产物包含“公开预热 → modal 晋升”逻辑
- Touch Bar 黑屏概率低于之前版本
- 是否通过：待用户在真机环境确认。
