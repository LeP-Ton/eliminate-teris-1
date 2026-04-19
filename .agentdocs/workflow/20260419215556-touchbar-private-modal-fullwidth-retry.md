# Touch Bar 恢复私有 modal 单路线，并加入自动重挂载

## 背景与目标
- 用户明确要求恢复私有 `system modal` Touch Bar 单路线，不再保留公开 `window.touchBar` 作为正式显示路径。
- 本次目标是尽量隐藏右侧常驻系统功能栏，让游戏内容全宽占满 Touch Bar，并在保留私有 modal 的前提下继续收敛概率黑屏。

## 约束与原则
- 运行时不再提供公开/私有双方案，也不做自动回退公开游戏 Touch Bar。
- 保留 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 诊断开关，但日志语义统一改回私有 modal 视角。
- 继续复用 `GameTouchBarView` 的尺寸感知和延迟补绘逻辑，只调整控制器展示链路。

## 当前进展
- `GameViewController` 已恢复私有 modal 的 present / dismiss 生命周期，并新增应用激活、应用失活、窗口成为 key、窗口失去 key 四类事件驱动。
- 私有 modal 挂载后会执行三段刷新与一次健康检查；健康检查失败时会自动 `dismiss -> re-present`，最多重试 3 轮。
- `AGENTS.md` 与 `.agentdocs/index.md` 已同步切回“私有 modal 为正式方案”的项目认知。

## 代码变更
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index fe5e8b2..8287b64 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,2 +3,3 @@
 ## 当前变更文档
+`workflow/20260419215556-touchbar-private-modal-fullwidth-retry.md` - 恢复私有 modal 为唯一正式方案，目标全宽占满 Touch Bar，并加入三段刷新 + 健康检查 + 自动重挂载修复黑屏。
 `workflow/20260419210231-public-touchbar-only-retire-modal.md` - 正式回退为公开 `window.touchBar` 唯一路径，停用私有 modal 与相关状态机，优先保证打包版稳定显示。
@@ -50,2 +51,3 @@
 ## 读取场景
+- 需要确认“当前正式方案是否已经恢复为私有 modal 单路线，并以全宽显示为目标”时，优先读取 `20260419215556` 文档。
 - 需要确认“当前正式方案是否已经彻底放弃私有 modal，只保留公开 Touch Bar”时，优先读取 `20260419210231` 文档。
@@ -98,10 +100,10 @@
 ## 关键记忆
-- 当前正式 Touch Bar 方案已经统一为公开 `window.touchBar`：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与预热晋升链路都已停用并视为历史废案；启动时仅保留公开 Touch Bar 的异步首刷与一次延迟刷新。
-- Touch Bar 当前启动策略为：先挂载公开 `window.touchBar`，再异步执行一次 `prepareForDisplay()` 并追加 120ms 的二次刷新，避免首帧发生在零尺寸阶段。
-- Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，主要用于观察公开 `window.touchBar` 的挂载、刷新调度、尺寸变化与有效首帧绘制。
-- 打包版 Touch Bar 黑屏当前按“公开路径渲染时序”处理：`GameTouchBarView` 会把零尺寸阶段的刷新记为 pending，待 bounds 有效后补绘；`GameViewController` 会异步执行两次 `prepareForDisplay()`，不再触发私有 modal 健康检查与自动晋升。
+- 当前正式 Touch Bar 方案已经恢复为私有 `system modal` 单路线：游戏内容不再通过公开 `window.touchBar` 显示，目标是尽量隐藏右侧常驻系统功能栏并全宽占满 Touch Bar。
+- Touch Bar 当前挂载策略为：每次私有 modal 展示后执行三段刷新（下一轮 run loop、120ms、260ms），并在 180ms 做健康检查；若未拿到有效尺寸或可见内容，则自动 `dismiss -> re-present`。
+- 私有 modal 自动重挂载最多重试 3 轮；超过次数后不会回退公开游戏 Touch Bar，而是关闭当前 modal，等待应用重新激活或窗口重新成为 key 时再次挂载。
+- Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，主要用于观察私有 modal 的 present、dismiss、刷新、健康检查与重挂载过程。
 - 最新打包启动崩溃根因是资源 Bundle 路径：SwiftPM 生成的 `Bundle.module` 更适合直接从 `.build` 运行，手工组装 `.app` 时应显式兼容 `Bundle.main.resourceURL/Contents/Resources`。
 - 当前打包脚本默认输出通用二进制：分别构建 `x86_64` 与 `arm64`，再用 `lipo` 合成，最终 `file dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1` 应显示 `Mach-O universal binary with 2 architectures`。
-- 当前正式方案不再提供 `ELIMINATE_TOUCHBAR_MODAL`：运行时固定使用公开 `window.touchBar`，避免公开→私有切换带来的黑屏与双段刷新副作用。
-- 打包版与开发态当前使用同一条公开 Touch Bar 路径：都依赖 `prepareForDisplay()` 的异步首刷与一次延迟刷新，不再区分“私有 modal 优先”策略。
+- 当前正式方案不再提供 `ELIMINATE_TOUCHBAR_MODAL`：运行时固定使用私有 `system modal` 显示游戏 Touch Bar，不再支持公开/私有双路线切换。
+- 打包版与开发态当前都以私有 modal 为唯一正式显示路径；公开 `window.touchBar` 仅保留在历史文档中作为已废弃方案。
 - 当前通过 `package.sh` 一键打包：`swift build -c release` 后组装 `.app`（含资源 Bundle + Info.plist + ad-hoc 签名），并尝试生成 DMG；若 DMG 不可用则自动回退为 ZIP。
@@ -113,4 +115,4 @@
 - Touch Bar 已接入过渡动画：共享 tile 使用位置插值，消除使用缩放淡出，新补位从左侧滑入；动画时长约 `0.22s`，曲线为 `easeOutCubic`。
-- 历史方案中，私有 API 曾采用双签名回退：优先调用 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，不可用时回退到 `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`；该链路现已停用。
-- 历史方案中曾接入 `presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，并以 system modal 规避公开 API 下 ESC 预留留白；当前正式实现已回退到公开 `window.touchBar`。
+- 私有 API 当前采用双签名兼容：优先调用 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，不可用时回退到 `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`，以提升全宽 modal 在不同系统版本上的可用率。
+- 当前正式实现已重新回到 `presentSystemModalTouchBar` / `dismissSystemModalTouchBar` 路线，并在应用失活、窗口失焦时主动 dismiss，避免影响其他应用的 Touch Bar。
 - 历史排查阶段曾尝试分槽位渲染：ESC 槽位承载第 0 列、主槽位承载 1...15，并对主槽位施加 `leadingCompensationX=8` 左移补偿；当前正式实现为单槽位 16 列 + 0 宽 ESC 占位。
diff --git a/AGENTS.md b/AGENTS.md
index 326f87e..22f54ee 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -33,4 +33,4 @@
 - 最新回调到分槽位方案：首列仍在 ESC 槽位、其余 1...15 在主棋盘槽位，但给主棋盘增加 `leadingCompensationX=8` 左移补偿以抵消跨槽位分隔，首列宽度继续按主棋盘单列宽度自适应同步。
-- 历史上曾接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，并尝试通过 system modal 解决左贴边与 ESC 留白问题；该路线现已停用，仅作为历史排查背景保留在 workflow 文档中。
-- 历史上的私有 API 展示链路曾实现“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；当前正式代码已不再调用这条链路。
+- 历史上曾接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，并尝试通过 system modal 解决左贴边与 ESC 留白问题；这条路线在公开单方案阶段曾短暂停用，现已恢复为正式方案。
+- 私有 API 展示链路当前重新采用“双签名兼容”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式，用于提升不同系统版本下的可用率。
 - 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
@@ -42,8 +42,9 @@
 - 已新增 `package.sh` 打包脚本：构建 release 后生成 `.app`，自动拷贝 SwiftPM 资源 Bundle、写入 `Info.plist`、执行 ad-hoc 签名，并优先输出 DMG（失败时自动回退 ZIP）。
-- 历史上曾尝试以“release 默认公开路径”或“公开预热后晋升私有 modal”规避打包版 Touch Bar 黑屏；这些方案现均已废弃，不再参与运行时决策。
-- Touch Bar 当前正式方案为“单槽位 16 列 + 0 宽 `escape-placeholder` + 公开 `window.touchBar`”：优先保证打包版稳定显示，接受左侧贴边效果相较私有 modal 略有回退。
+- 历史上曾尝试以“release 默认公开路径”或“公开预热后晋升私有 modal”规避打包版 Touch Bar 黑屏；这些公开路径方案现均已降级为历史废案。
+- Touch Bar 当前正式方案为“单槽位 16 列 + 0 宽 `escape-placeholder` + 私有 system modal”：目标是尽量隐藏右侧常驻系统功能栏，让游戏内容全宽占满 Touch Bar。
 - `package.sh` 现在默认构建 `x86_64 + arm64` 通用二进制，并通过 `lipo` 合成为单个 `.app`，用于同时兼容 Intel 与 Apple Silicon（M1/M2/M3）Mac；可用 `PACKAGE_ARCHS` 覆盖目标架构。
 - 打包后“应用意外退出”的最新根因已确认：不是通用二进制本身，而是 `Bundle.module` 在手工 `.app` 中查找资源 Bundle 的路径与 `Contents/Resources` 不一致；现已在 `Localization.swift` 中改为兼容开发态与打包态的多路径资源查找。
-- 打包版 Touch Bar 黑屏当前按“公开路径渲染时序”处理：`GameTouchBarView` 会把零尺寸阶段的刷新请求挂起，在尺寸有效时强制补绘并记录 `hasDrawnVisibleContent/displayGeneration`；`GameViewController` 则统一挂载 `window.touchBar`，执行异步首刷与 120ms 二次刷新。
-- 已新增可开关的 Touch Bar 诊断日志：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 后，会通过 `NSLog` 输出公开 `window.touchBar` 挂载、刷新调度、尺寸变化与首帧有效绘制信息，日志前缀统一为 `[TouchBarDiag]`。
-- 当前正式方案已回退为“仅使用公开 `window.touchBar`”：私有 modal、`ELIMINATE_TOUCHBAR_MODAL` 与公开→私有晋升链路均视为历史废案，不再参与运行时决策；现阶段优先保证打包版稳定显示与单段刷新观感。
+- 打包版 Touch Bar 黑屏当前按“私有 modal 渲染时序”处理：`GameTouchBarView` 继续负责零尺寸阶段的挂起刷新与有效尺寸补绘；`GameViewController` 则在每次 modal 挂载后执行三段刷新（即时、120ms、260ms）和 180ms 健康检查。
+- 私有 modal 挂载异常时，会自动执行 `dismiss -> re-present` 重挂载，最多重试 3 轮；若仍失败，则只关闭 modal 并等待下一次窗口重新激活/成为 key 时再次全量挂载，不回退公开游戏 Touch Bar。
+- 已新增可开关的 Touch Bar 诊断日志：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 后，会通过 `NSLog` 输出私有 modal 的 present、dismiss、三段刷新、健康检查与重挂载轮次，日志前缀统一为 `[TouchBarDiag]`。
+- 当前正式方案已恢复为“仅使用私有 system modal 显示游戏 Touch Bar”：`ELIMINATE_TOUCHBAR_MODAL` 与公开 `window.touchBar` 路径均视为历史废案，不再参与运行时决策。
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 2436db2..894c6e1 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -1,2 +1,3 @@
 import Cocoa
+import ObjectiveC.runtime
 
@@ -45,2 +46,5 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
+    private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
+    private let touchBarHealthCheckDelay: TimeInterval = 0.18
+    private let touchBarMaxReattachAttempts = 3
 
@@ -50,2 +54,3 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private var observerToken: UUID?
+    private var isPresentingSystemModalTouchBar = false
     private var touchBarPresentationGeneration = 0
@@ -53,2 +58,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private var touchBarSecondaryRefreshWorkItem: DispatchWorkItem?
+    private var touchBarTertiaryRefreshWorkItem: DispatchWorkItem?
+    private var touchBarHealthCheckWorkItem: DispatchWorkItem?
+    private var appDidBecomeActiveObserver: NSObjectProtocol?
+    private var appDidResignActiveObserver: NSObjectProtocol?
+    private var windowDidBecomeKeyObserver: NSObjectProtocol?
+    private var windowDidResignKeyObserver: NSObjectProtocol?
+    private weak var observedTouchBarWindow: NSWindow?
     private var hudTimer: Timer?
@@ -524,3 +536,4 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         }
-        cancelTouchBarRefreshWorkItems()
+        removeTouchBarLifecycleObservers()
+        invalidateSystemModalTouchBarPresentation(reason: "deinit")
         hudTimer?.invalidate()
@@ -530,3 +543,4 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     override func makeTouchBar() -> NSTouchBar? {
-        return gameTouchBar
+        // 当前正式方案固定使用私有 modal；不再通过公开 responder 链路提供游戏 Touch Bar。
+        return nil
     }
@@ -535,5 +549,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         super.viewDidAppear()
-        // 当前正式方案固定使用公开 window.touchBar，优先保证打包版稳定显示。
+        if let window = view.window {
+            installTouchBarLifecycleObservers(for: window)
+        }
+        // 当前正式方案固定使用私有 modal，目标是尽量隐藏右侧常驻系统功能栏并占满 Touch Bar。
         logTouchBarDiagnostics("viewDidAppear，windowExists=\(view.window != nil)")
-        refreshTouchBarPresentationForCurrentWindow()
+        synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
         view.window?.makeFirstResponder(self)
@@ -544,4 +561,5 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     override func viewDidDisappear() {
-        logTouchBarDiagnostics("viewDidDisappear，开始失效公开 Touch Bar 刷新链路")
-        invalidateTouchBarRefreshLifecycle()
+        logTouchBarDiagnostics("viewDidDisappear，开始失效私有 modal Touch Bar")
+        invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
+        removeTouchBarLifecycleObservers()
         super.viewDidDisappear()
@@ -584,4 +602,125 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
-    private func refreshTouchBarPresentationForCurrentWindow() {
-        guard isViewLoaded, view.window != nil else { return }
+    private func installTouchBarLifecycleObservers(for window: NSWindow) {
+        let notificationCenter = NotificationCenter.default
+
+        if appDidBecomeActiveObserver == nil {
+            appDidBecomeActiveObserver = notificationCenter.addObserver(
+                forName: NSApplication.didBecomeActiveNotification,
+                object: nil,
+                queue: .main
+            ) { [weak self] _ in
+                self?.handleApplicationDidBecomeActive()
+            }
+        }
+
+        if appDidResignActiveObserver == nil {
+            appDidResignActiveObserver = notificationCenter.addObserver(
+                forName: NSApplication.didResignActiveNotification,
+                object: nil,
+                queue: .main
+            ) { [weak self] _ in
+                self?.handleApplicationDidResignActive()
+            }
+        }
+
+        guard observedTouchBarWindow !== window else { return }
+        removeWindowTouchBarLifecycleObservers()
+        observedTouchBarWindow = window
+
+        windowDidBecomeKeyObserver = notificationCenter.addObserver(
+            forName: NSWindow.didBecomeKeyNotification,
+            object: window,
+            queue: .main
+        ) { [weak self] _ in
+            self?.handleWindowDidBecomeKey()
+        }
+
+        windowDidResignKeyObserver = notificationCenter.addObserver(
+            forName: NSWindow.didResignKeyNotification,
+            object: window,
+            queue: .main
+        ) { [weak self] _ in
+            self?.handleWindowDidResignKey()
+        }
+    }
+
+    private func removeTouchBarLifecycleObservers() {
+        let notificationCenter = NotificationCenter.default
+
+        if let appDidBecomeActiveObserver {
+            notificationCenter.removeObserver(appDidBecomeActiveObserver)
+            self.appDidBecomeActiveObserver = nil
+        }
+
+        if let appDidResignActiveObserver {
+            notificationCenter.removeObserver(appDidResignActiveObserver)
+            self.appDidResignActiveObserver = nil
+        }
+
+        removeWindowTouchBarLifecycleObservers()
+    }
+
+    private func removeWindowTouchBarLifecycleObservers() {
+        let notificationCenter = NotificationCenter.default
+
+        if let windowDidBecomeKeyObserver {
+            notificationCenter.removeObserver(windowDidBecomeKeyObserver)
+            self.windowDidBecomeKeyObserver = nil
+        }
+
+        if let windowDidResignKeyObserver {
+            notificationCenter.removeObserver(windowDidResignKeyObserver)
+            self.windowDidResignKeyObserver = nil
+        }
+
+        observedTouchBarWindow = nil
+    }
+
+    private func handleApplicationDidBecomeActive() {
+        logTouchBarDiagnostics("应用重新激活，准备恢复私有 modal Touch Bar")
+        synchronizeSystemModalTouchBarPresentation(trigger: "applicationDidBecomeActive")
+    }
+
+    private func handleApplicationDidResignActive() {
+        logTouchBarDiagnostics("应用失活，准备关闭私有 modal Touch Bar")
+        invalidateSystemModalTouchBarPresentation(reason: "applicationDidResignActive")
+    }
+
+    private func handleWindowDidBecomeKey() {
+        logTouchBarDiagnostics("窗口重新成为 key，准备恢复私有 modal Touch Bar")
+        synchronizeSystemModalTouchBarPresentation(trigger: "windowDidBecomeKey")
+    }
+
+    private func handleWindowDidResignKey() {
+        logTouchBarDiagnostics("窗口失去 key，准备关闭私有 modal Touch Bar")
+        invalidateSystemModalTouchBarPresentation(reason: "windowDidResignKey")
+    }
+
+    private var shouldPresentSystemModalTouchBar: Bool {
+        guard isViewLoaded, let window = view.window else { return false }
+        guard NSApp.isActive else { return false }
+        guard window.isVisible, window.isKeyWindow else { return false }
+        guard !window.isMiniaturized else { return false }
+        return true
+    }
+
+    private func synchronizeSystemModalTouchBarPresentation(trigger: String) {
+        guard shouldPresentSystemModalTouchBar else {
+            logTouchBarDiagnostics("跳过私有 modal 挂载，trigger=\(trigger)，reason=窗口或应用当前不可展示")
+            invalidateSystemModalTouchBarPresentation(reason: "\(trigger)-not-eligible", shouldAdvanceGeneration: false)
+            return
+        }
+
+        if isPresentingSystemModalTouchBar {
+            refreshPresentedSystemModalTouchBar(trigger: trigger)
+        } else {
+            beginSystemModalTouchBarPresentation(trigger: trigger, attempt: 0)
+        }
+    }
+
+    private func beginSystemModalTouchBarPresentation(trigger: String, attempt: Int) {
+        guard shouldPresentSystemModalTouchBar else {
+            logTouchBarDiagnostics("放弃私有 modal 挂载，trigger=\(trigger)，attempt=\(attempt)，reason=展示条件不满足")
+            return
+        }
 
@@ -590,9 +729,24 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         cancelTouchBarRefreshWorkItems()
-        view.window?.touchBar = gameTouchBar
-        logTouchBarDiagnostics("已挂载公开 window.touchBar，私有 modal 已停用，generation=\(generation)")
-        scheduleTouchBarDisplayRefreshes(for: generation)
+        view.window?.touchBar = nil
+
+        guard presentSystemModalTouchBarIfPossible() else {
+            logTouchBarDiagnostics("私有 modal 挂载失败，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)")
+            return
+        }
+
+        logTouchBarDiagnostics("已展示私有 modal Touch Bar，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)")
+        scheduleSystemModalDisplayRefreshes(
+            for: generation,
+            attempt: attempt,
+            trigger: trigger,
+            includeHealthCheck: true
+        )
     }
 
-    private func refreshTouchBarDisplayLifecycleIfNeeded() {
-        guard isViewLoaded, view.window != nil else { return }
+    private func refreshPresentedSystemModalTouchBar(trigger: String) {
+        guard shouldPresentSystemModalTouchBar else {
+            logTouchBarDiagnostics("私有 modal 已展示但当前不应继续保留，trigger=\(trigger)")
+            invalidateSystemModalTouchBarPresentation(reason: "\(trigger)-refresh-not-eligible")
+            return
+        }
 
@@ -601,9 +755,18 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         cancelTouchBarRefreshWorkItems()
-        view.window?.touchBar = gameTouchBar
-        logTouchBarDiagnostics("刷新公开 window.touchBar 生命周期，generation=\(generation)")
-        scheduleTouchBarDisplayRefreshes(for: generation)
+        view.window?.touchBar = nil
+        logTouchBarDiagnostics("刷新已展示的私有 modal Touch Bar，trigger=\(trigger)，generation=\(generation)")
+        scheduleSystemModalDisplayRefreshes(
+            for: generation,
+            attempt: 0,
+            trigger: trigger,
+            includeHealthCheck: false
+        )
     }
 
-    private func scheduleTouchBarDisplayRefreshes(for generation: Int) {
-        // 公开 Touch Bar 仍保留异步首刷与一次延迟刷新，确保首帧在有效 bounds 下稳定落地。
+    private func scheduleSystemModalDisplayRefreshes(
+        for generation: Int,
+        attempt: Int,
+        trigger: String,
+        includeHealthCheck: Bool
+    ) {
         let initialRefresh = DispatchWorkItem { [weak self] in
@@ -612,3 +775,3 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             self.logTouchBarDiagnostics(
-                "公开 Touch Bar 首次异步刷新，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
+                "私有 modal 首次异步刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
             )
@@ -622,3 +785,3 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             self.logTouchBarDiagnostics(
-                "公开 Touch Bar 二次延迟刷新，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
+                "私有 modal 二次刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
             )
@@ -626,11 +789,117 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         touchBarSecondaryRefreshWorkItem = secondaryRefresh
-        logTouchBarDiagnostics("已安排公开 Touch Bar 二次刷新，delay=\(touchBarSecondaryRefreshDelay)s，generation=\(generation)")
         DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)
+
+        let tertiaryRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
+            self.logTouchBarDiagnostics(
+                "私有 modal 三次刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
+            )
+        }
+        touchBarTertiaryRefreshWorkItem = tertiaryRefresh
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarTertiaryRefreshDelay, execute: tertiaryRefresh)
+
+        if includeHealthCheck {
+            let healthCheck = DispatchWorkItem { [weak self] in
+                guard let self, self.touchBarPresentationGeneration == generation else { return }
+                guard self.isPresentingSystemModalTouchBar else { return }
+
+                let bounds = self.gameTouchBarView.bounds
+                let hasRenderableBounds = bounds.width > 1 && bounds.height > 1
+                let hasVisibleContent = self.gameTouchBarView.hasDrawnVisibleContent
+
+                self.logTouchBarDiagnostics(
+                    "私有 modal 健康检查，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，bounds=\(TouchBarDiagnostics.describe(rect: bounds))，hasRenderableBounds=\(hasRenderableBounds)，hasVisibleContent=\(hasVisibleContent)，displayGeneration=\(self.gameTouchBarView.displayGeneration)"
+                )
+
+                guard hasRenderableBounds, hasVisibleContent else {
+                    self.handleSystemModalHealthCheckFailure(trigger: trigger, attempt: attempt)
+                    return
+                }
+            }
+            touchBarHealthCheckWorkItem = healthCheck
+            DispatchQueue.main.asyncAfter(deadline: .now() + touchBarHealthCheckDelay, execute: healthCheck)
+        }
+
+        logTouchBarDiagnostics(
+            "已安排私有 modal 刷新序列，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)，secondaryDelay=\(touchBarSecondaryRefreshDelay)s，healthDelay=\(touchBarHealthCheckDelay)s，tertiaryDelay=\(touchBarTertiaryRefreshDelay)s"
+        )
     }
 
-    private func invalidateTouchBarRefreshLifecycle() {
-        touchBarPresentationGeneration += 1
-        logTouchBarDiagnostics("失效公开 Touch Bar 刷新生命周期，newGeneration=\(touchBarPresentationGeneration)")
+    private func handleSystemModalHealthCheckFailure(trigger: String, attempt: Int) {
+        cancelTouchBarRefreshWorkItems()
+
+        if attempt < touchBarMaxReattachAttempts {
+            let nextAttempt = attempt + 1
+            logTouchBarDiagnostics("私有 modal 健康检查失败，准备重挂载，trigger=\(trigger)，currentAttempt=\(attempt)，nextAttempt=\(nextAttempt)")
+            dismissSystemModalTouchBarIfNeeded(reason: "health-check-failed-attempt-\(attempt)")
+            DispatchQueue.main.async { [weak self] in
+                guard let self else { return }
+                self.beginSystemModalTouchBarPresentation(trigger: "\(trigger)-reattach", attempt: nextAttempt)
+            }
+            return
+        }
+
+        logTouchBarDiagnostics("私有 modal 已达到最大重挂载次数，停止自动重试，trigger=\(trigger)，finalAttempt=\(attempt)")
+        dismissSystemModalTouchBarIfNeeded(reason: "health-check-final-failure")
+    }
+
+    private func presentSystemModalTouchBarIfPossible() -> Bool {
+        guard isPresentingSystemModalTouchBar == false else { return true }
+
+        let modernSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
+        if let modernMethod = class_getClassMethod(NSTouchBar.self, modernSelector) {
+            typealias PresentModernModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
+            let implementation = method_getImplementation(modernMethod)
+            let function = unsafeBitCast(implementation, to: PresentModernModalTouchBar.self)
+            function(NSTouchBar.self, modernSelector, gameTouchBar, nil)
+            isPresentingSystemModalTouchBar = true
+            logTouchBarDiagnostics("已通过现代私有 API 展示 system modal")
+            return true
+        }
+
+        let fallbackSelector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
+        if let fallbackMethod = class_getClassMethod(NSTouchBar.self, fallbackSelector) {
+            typealias PresentFallbackModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
+            let implementation = method_getImplementation(fallbackMethod)
+            let function = unsafeBitCast(implementation, to: PresentFallbackModalTouchBar.self)
+            function(NSTouchBar.self, fallbackSelector, gameTouchBar, 0, nil)
+            isPresentingSystemModalTouchBar = true
+            logTouchBarDiagnostics("已通过回退私有 API 展示 system modal")
+            return true
+        }
+
+        logTouchBarDiagnostics("当前系统不支持私有 modal API，无法展示全宽 Touch Bar")
+        return false
+    }
+
+    private func dismissSystemModalTouchBarIfNeeded(reason: String) {
+        guard isPresentingSystemModalTouchBar else { return }
+
+        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
+        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
+            isPresentingSystemModalTouchBar = false
+            logTouchBarDiagnostics("私有 modal dismiss API 不可用，已重置展示状态，reason=\(reason)")
+            return
+        }
+
+        typealias DismissModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
+        let implementation = method_getImplementation(method)
+        let function = unsafeBitCast(implementation, to: DismissModalTouchBar.self)
+        function(NSTouchBar.self, selector, gameTouchBar)
+        isPresentingSystemModalTouchBar = false
+        logTouchBarDiagnostics("已关闭私有 modal Touch Bar，reason=\(reason)")
+    }
+
+    private func invalidateSystemModalTouchBarPresentation(
+        reason: String,
+        shouldAdvanceGeneration: Bool = true
+    ) {
+        if shouldAdvanceGeneration {
+            touchBarPresentationGeneration += 1
+        }
+        logTouchBarDiagnostics("失效私有 modal Touch Bar，reason=\(reason)，newGeneration=\(touchBarPresentationGeneration)")
         cancelTouchBarRefreshWorkItems()
         view.window?.touchBar = nil
+        dismissSystemModalTouchBarIfNeeded(reason: reason)
     }
@@ -638,4 +907,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private func cancelTouchBarRefreshWorkItems() {
-        if touchBarInitialRefreshWorkItem != nil || touchBarSecondaryRefreshWorkItem != nil {
-            logTouchBarDiagnostics("取消待执行的公开 Touch Bar 刷新任务")
+        if touchBarInitialRefreshWorkItem != nil ||
+            touchBarSecondaryRefreshWorkItem != nil ||
+            touchBarTertiaryRefreshWorkItem != nil ||
+            touchBarHealthCheckWorkItem != nil {
+            logTouchBarDiagnostics("取消待执行的私有 modal 刷新与健康检查任务")
         }
@@ -643,4 +915,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         touchBarSecondaryRefreshWorkItem?.cancel()
+        touchBarTertiaryRefreshWorkItem?.cancel()
+        touchBarHealthCheckWorkItem?.cancel()
         touchBarInitialRefreshWorkItem = nil
         touchBarSecondaryRefreshWorkItem = nil
+        touchBarTertiaryRefreshWorkItem = nil
+        touchBarHealthCheckWorkItem = nil
     }
@@ -711,3 +987,3 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         refreshRecordPanelAfterLayoutIfNeeded()
-        refreshTouchBarDisplayLifecycleIfNeeded()
+        synchronizeSystemModalTouchBarPresentation(trigger: "modeSelectionChanged")
     }
```

## 测试用例
### TC-001 私有 modal 全宽显示
- 类型：功能测试
- 优先级：高
- 前置条件：应用正常启动且当前窗口为前台 key window
- 操作步骤：
1. 启动应用
2. 观察 Touch Bar
- 预期结果：
- 游戏内容通过私有 modal 显示
- 右侧常驻系统功能栏被隐藏或最大化压缩
- 16 个格子完整可见

### TC-002 黑屏自动重挂载
- 类型：稳定性测试
- 优先级：高
- 前置条件：设置 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`
- 操作步骤：
1. 连续冷启动开发态和打包态
2. 观察日志中的健康检查与重挂载信息
- 预期结果：
- 若首挂失败，日志会出现健康检查失败与自动重挂载
- 最多重试 3 轮
- 不会回退到公开游戏 Touch Bar

### TC-003 生命周期清理
- 类型：功能测试
- 优先级：中
- 操作步骤：
1. 启动应用后切换到后台
2. 再切回前台
3. 切换窗口焦点
4. 关闭窗口或退出应用
- 预期结果：
- 应用失活或窗口失焦时私有 modal 会 dismiss
- 恢复激活或重新成为 key 时会重新挂载
- 退出时不会残留黑色或卡死的 modal Touch Bar
