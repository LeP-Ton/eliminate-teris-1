# 新增可开关的 Touch Bar 诊断日志

## 背景与目标
- 用户反馈：即使已经补过渲染时序与 fallback，自 `dist/Eliminate Teris 1.app` 启动时，Touch Bar 仍有概率黑屏。
- 当前缺少足够细粒度的运行时信息，无法判断具体是“私有 modal 挂载失败”“尺寸迟迟无效”“首帧没真正绘制出来”，还是“健康检查后 fallback 没接住”。
- 本次目标是新增一版默认关闭、按环境变量开启的诊断日志，帮助在真机上精准定位黑屏发生在哪个阶段。

## 方案
- 新增 `TouchBarDiagnostics` 辅助类型，统一解析环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS`，并通过 `NSLog` 输出日志。
- 在 `GameViewController` 中记录 Touch Bar 展示链路：`viewDidAppear`、私有 modal 挂载、公开 `window.touchBar` 回退、异步双次刷新、健康检查、dismiss 与任务取消。
- 在 `GameTouchBarView` 中记录视图链路：初始化、挂到 window、刷新被挂起/兑现、bounds 何时首次变为可渲染、首帧是否真正完成有效绘制。
- 日志前缀统一为 `[TouchBarDiag]`，便于在终端或 Console.app 中筛选。

## 使用方式
- 调试运行：
  - `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1 ./run.sh`
- 直接运行打包产物内的可执行文件：
  - `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1 'dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1'`
- 关键观察点：
  - 是否出现 `已通过现代私有 API 展示 system modal`
  - 是否执行 `首次异步刷新` 与 `二次延迟刷新`
  - `modal 健康检查` 时 `hasRenderableBounds` / `hasVisibleContent` 是否为 `true`
  - 是否出现 `system modal 判定异常，回退到公开 window.touchBar`
  - `GameTouchBarView` 是否出现 `检测到尺寸可渲染` 与 `已完成有效绘制`

## 当前进展
- 已新增诊断日志开关与公共日志工具。
- 已为控制器与 Touch Bar 视图补齐关键生命周期日志。
- 已同步更新 `AGENTS.md` 与 `.agentdocs/index.md`，记录本次诊断开关与读取场景。

## 代码变更
- Sources/TouchBarDiagnostics.swift
```diff
*** Begin Patch
*** Add File: Sources/TouchBarDiagnostics.swift
+import Foundation
+
+enum TouchBarDiagnostics {
+    static let environmentKey = "ELIMINATE_TOUCHBAR_DIAGNOSTICS"
+
+    static let isEnabled: Bool = {
+        let rawValue = ProcessInfo.processInfo.environment[environmentKey]?
+            .trimmingCharacters(in: .whitespacesAndNewlines)
+            .lowercased()
+
+        switch rawValue {
+        case "1", "true", "yes", "on", "debug":
+            return true
+        default:
+            return false
+        }
+    }()
+
+    static func log(
+        _ message: @autoclosure () -> String,
+        function: StaticString = #function
+    ) {
+        guard isEnabled else { return }
+        NSLog("[TouchBarDiag] \\(function): \\(message())")
+    }
+
+    static func describe(size: CGSize) -> String {
+        return String(format: "%.1fx%.1f", size.width, size.height)
+    }
+
+    static func describe(rect: CGRect) -> String {
+        return String(
+            format: "(x:%.1f,y:%.1f,w:%.1f,h:%.1f)",
+            rect.origin.x,
+            rect.origin.y,
+            rect.size.width,
+            rect.size.height
+        )
+    }
+}
*** End Patch
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 3fd64e0..82b4613 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -340,6 +340,15 @@ final class GameTouchBarView: NSView {
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
+    private var lastLoggedRenderState = ""
+    private var lastLoggedVisibleGeneration = -1
@@ -359,7 +368,8 @@ final class GameTouchBarView: NSView {
         wantsRestingTouches = true
         setContentHuggingPriority(.defaultLow, for: .horizontal)
         setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
-        needsDisplay = true
+        requestDisplayRefresh()
+        logDiagnostics("初始化完成，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
@@ -385,12 +395,38 @@ final class GameTouchBarView: NSView {
         return true
     }
 
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        logDiagnostics("已挂到 window，windowExists=\\(window != nil)，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
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
+            let renderState = "blocked-\\(TouchBarDiagnostics.describe(size: bounds.size))"
+            if lastLoggedRenderState != renderState {
+                lastLoggedRenderState = renderState
+                logDiagnostics("跳过有效内容绘制，原因=尺寸不足，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
+            }
+            return
+        }
+
         for localIndex in 0..<columnCount {
             let globalIndex = columnRange.lowerBound + localIndex
             let rect = cellRect(forLocalIndex: localIndex)
@@ -414,6 +450,8 @@ final class GameTouchBarView: NSView {
                     scale: 1
                 )
             }
+            hasDrawnVisibleContent = true
+            logVisibleContentIfNeeded(reason: "静态棋盘")
             return
         }
@@ -425,6 +463,8 @@ final class GameTouchBarView: NSView {
         for transition in visibleTransitions where transition.transitionKind == .remove {
             drawTransitionPiece(transition)
         }
+        hasDrawnVisibleContent = true
+        logVisibleContentIfNeeded(reason: "动画棋盘，transitions=\\(visibleTransitions.count)")
     }
@@ -506,21 +546,30 @@ final class GameTouchBarView: NSView {
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
+        lastLoggedVisibleGeneration = -1
+        lastLoggedRenderState = ""
+        requestDisplayRefresh()
+        logDiagnostics("prepareForDisplay，displayGeneration=\\(displayGeneration)，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
+        return displayGeneration
     }
@@ -999,4 +1048,66 @@ final class GameTouchBarView: NSView {
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
+            if pendingDisplayRefresh {
+                logDiagnostics("兑现挂起刷新，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
+            }
+            pendingDisplayRefresh = false
+            needsDisplay = true
+            return
+        }
+
+        if pendingDisplayRefresh == false {
+            logDiagnostics("刷新请求挂起，等待有效尺寸，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
+        }
+        pendingDisplayRefresh = true
+    }
+
+    private func handleBoundsChangeIfNeeded() {
+        let currentSize = bounds.size
+        let previousSize = lastKnownBoundsSize
+        let widthChanged = abs(currentSize.width - previousSize.width) > 0.5
+        let heightChanged = abs(currentSize.height - previousSize.height) > 0.5
+        let sizeChanged = widthChanged || heightChanged
+        let previouslyRenderable = previousSize.width > 0.5 && previousSize.height > 0.5
+        let nowRenderable = currentSize.width > 0.5 && currentSize.height > 0.5
+
+        lastKnownBoundsSize = currentSize
+
+        // 只要这次尺寸有效，且之前有挂起刷新或尺寸真的变化了，就强制补一帧重绘。
+        guard nowRenderable else { return }
+        guard pendingDisplayRefresh || sizeChanged || !previouslyRenderable else { return }
+
+        pendingDisplayRefresh = false
+        logDiagnostics(
+            "检测到尺寸可渲染，previous=\\(TouchBarDiagnostics.describe(size: previousSize)) current=\\(TouchBarDiagnostics.describe(size: currentSize)) sizeChanged=\\(sizeChanged)"
+        )
+        needsDisplay = true
+    }
+
+    private func logVisibleContentIfNeeded(reason: String) {
+        guard lastLoggedVisibleGeneration != displayGeneration else { return }
+        lastLoggedVisibleGeneration = displayGeneration
+        lastLoggedRenderState = "visible-\\(displayGeneration)"
+        logDiagnostics("\\(reason)，已完成有效绘制，bounds=\\(TouchBarDiagnostics.describe(rect: bounds))")
+    }
+
+    private func logDiagnostics(_ message: @autoclosure () -> String) {
+        TouchBarDiagnostics.log(
+            "GameTouchBarView[\\(columnRange.lowerBound)..<\\(columnRange.upperBound)] dg=\\(displayGeneration) \\(message())"
+        )
+    }
 }
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index f435a69..ac4836b 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -531,22 +544,18 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
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
+        logTouchBarDiagnostics("viewDidAppear，windowExists=\\(view.window != nil)")
+        refreshTouchBarPresentationForCurrentWindow()
         view.window?.makeFirstResponder(self)
         view.window?.minSize = NSSize(width: 720, height: 450)
         updateWindowTitle()
     }
@@ -595,31 +607,42 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             let function = unsafeBitCast(implementation, to: PresentModernModalTouchBar.self)
             function(NSTouchBar.self, modernSelector, gameTouchBar, nil)
             isPresentingSystemModalTouchBar = true
+            logTouchBarDiagnostics("已通过现代私有 API 展示 system modal")
             return true
         }
@@ -630,6 +653,141 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return true
     }
 
+    private func refreshTouchBarPresentationForCurrentWindow() {
+        guard isViewLoaded, view.window != nil else { return }
+
+        touchBarPresentationGeneration += 1
+        let generation = touchBarPresentationGeneration
+        cancelTouchBarPresentationWorkItems()
+        logTouchBarDiagnostics("刷新 Touch Bar 展示链路，generation=\\(generation)，preferModal=\\(shouldUseSystemModalTouchBar())")
+
+        if shouldUseSystemModalTouchBar(), presentSystemModalTouchBarIfPossible() {
+            activeTouchBarPresentationMode = .systemModal
+            view.window?.touchBar = nil
+            logTouchBarDiagnostics("当前采用 system modal，window.touchBar 已置空")
+            scheduleTouchBarDisplayRefreshes(for: generation)
+            scheduleTouchBarModalHealthCheck(for: generation)
+            return
+        }
+
+        attachTouchBarToWindow(for: generation)
+    }
+
+    private func scheduleTouchBarDisplayRefreshes(for generation: Int) {
+        // 首次刷新改为下一轮 run loop，再补一次延迟刷新，尽量等系统容器完成 attach/sizing。
+        let initialRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
+            self.logTouchBarDiagnostics(
+                "执行首次异步刷新，presentationGeneration=\\(generation)，displayGeneration=\\(displayGeneration)，bounds=\\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
+            )
+        }
+        touchBarInitialRefreshWorkItem = initialRefresh
+        DispatchQueue.main.async(execute: initialRefresh)
+
+        let secondaryRefresh = DispatchWorkItem { [weak self] in
+            guard let self, self.touchBarPresentationGeneration == generation else { return }
+            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
+            self.logTouchBarDiagnostics(
+                "执行二次延迟刷新，presentationGeneration=\\(generation)，displayGeneration=\\(displayGeneration)，bounds=\\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
+            )
+        }
+        touchBarSecondaryRefreshWorkItem = secondaryRefresh
+        logTouchBarDiagnostics("已安排二次刷新，delay=\\(touchBarSecondaryRefreshDelay)s，generation=\\(generation)")
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)
+    }
+
+    private func scheduleTouchBarModalHealthCheck(for generation: Int) {
+        let healthCheck = DispatchWorkItem { [weak self] in
+            self?.performTouchBarModalHealthCheck(for: generation)
+        }
+        touchBarHealthCheckWorkItem = healthCheck
+        logTouchBarDiagnostics("已安排 modal 健康检查，delay=\\(touchBarModalHealthCheckDelay)s，generation=\\(generation)")
+        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarModalHealthCheckDelay, execute: healthCheck)
+    }
+
+    private func performTouchBarModalHealthCheck(for generation: Int) {
+        guard touchBarPresentationGeneration == generation else { return }
+        guard activeTouchBarPresentationMode == .systemModal else { return }
+
+        let hasRenderableBounds = gameTouchBarView.bounds.width > 0.5 && gameTouchBarView.bounds.height > 0.5
+        let hasVisibleContent = gameTouchBarView.hasDrawnVisibleContent
+        logTouchBarDiagnostics(
+            "modal 健康检查，generation=\\(generation)，bounds=\\(TouchBarDiagnostics.describe(rect: gameTouchBarView.bounds))，hasRenderableBounds=\\(hasRenderableBounds)，hasVisibleContent=\\(hasVisibleContent)，displayGeneration=\\(gameTouchBarView.displayGeneration)"
+        )
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
+        logTouchBarDiagnostics("system modal 判定异常，回退到公开 window.touchBar，generation=\\(generation)")
+        cancelTouchBarPresentationWorkItems()
+        attachTouchBarToWindow(for: generation)
+    }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 3485411..12ed90f 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -45,3 +45,4 @@
 - `package.sh` 现在默认构建 `x86_64 + arm64` 通用二进制，并通过 `lipo` 合成为单个 `.app`，用于同时兼容 Intel 与 Apple Silicon（M1/M2/M3）Mac；可用 `PACKAGE_ARCHS` 覆盖目标架构。
 - 打包后“应用意外退出”的最新根因已确认：不是通用二进制本身，而是 `Bundle.module` 在手工 `.app` 中查找资源 Bundle 的路径与 `Contents/Resources` 不一致；现已在 `Localization.swift` 中改为兼容开发态与打包态的多路径资源查找。
 - 打包版 Touch Bar 黑屏的最新修复策略是“双层兜底”：`GameTouchBarView` 会在尺寸从 0 变为有效值时强制补一次重绘，并记录 `hasDrawnVisibleContent/displayGeneration`；`GameViewController` 则把首次 `prepareForDisplay()` 延后一轮 run loop，再做一次 120ms 二次刷新与 220ms modal 健康检查，若仍未完成有效绘制则自动回退到 `window.touchBar`。
+- 已新增可开关的 Touch Bar 诊断日志：设置环境变量 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1` 后，会通过 `NSLog` 输出 system modal 挂载、异步刷新、健康检查、fallback、以及 `GameTouchBarView` 的尺寸变化与首帧有效绘制信息，日志前缀统一为 `[TouchBarDiag]`。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 5153695..366b2f9 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260419200923-touchbar-diagnostics-logging.md` - 新增可开关的 Touch Bar 诊断日志，覆盖 modal 挂载、异步刷新、健康检查、fallback 与视图首帧绘制。
 `workflow/20260419194740-touchbar-black-screen-render-lifecycle-fallback.md` - 修复打包版 Touch Bar 概率黑屏：补齐尺寸变化重绘、异步双次预热、modal 健康检查与自动回退公开 Touch Bar。
 `workflow/20260418235435-fix-packaged-app-resource-bundle-crash.md` - 修复打包后启动即崩：绕开 `Bundle.module` 对手工 `.app` 的路径假设，兼容 `Contents/Resources` 资源布局。
 `workflow/20260418231251-universal-macos-package.md` - 打包脚本改为默认生成 `x86_64 + arm64` 通用 `.app`，解决发给 M1 机器后架构不匹配导致的崩溃风险。
@@ -45,6 +46,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要在真机上追踪“为什么这次启动仍然黑屏、是否触发了 fallback、首帧有没有真正画出来”时，优先读取 `20260419200923` 文档。
 - 需要排查“打包版 Touch Bar 偶发黑屏，但又不想失去左贴边 modal 展示”时，优先读取 `20260419194740` 文档。
 - 需要排查“通用包已生成但 `.app` 启动仍意外退出”时，优先读取 `20260418235435` 文档。
 - 需要排查“压缩 `.app` 发给 M1 后应用意外退出/架构不匹配”时，优先读取 `20260418231251` 文档。
@@ -90,6 +92,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- Touch Bar 诊断日志开关为 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1`：日志通过 `NSLog` 输出，统一前缀为 `[TouchBarDiag]`，可用于观察 system modal 是否成功、异步双次刷新是否执行、健康检查是否触发 fallback，以及 `GameTouchBarView` 是否拿到了有效尺寸并完成首帧绘制。
 - 打包版 Touch Bar 黑屏目前按“渲染时序”处理：`GameTouchBarView` 会把零尺寸阶段的刷新记为 pending，待 bounds 有效后补绘；`GameViewController` 会异步执行两次 `prepareForDisplay()`，并在私有 modal 下做 220ms 健康检查，失败时自动回退 `window.touchBar`。
 - 最新打包启动崩溃根因是资源 Bundle 路径：SwiftPM 生成的 `Bundle.module` 更适合直接从 `.build` 运行，手工组装 `.app` 时应显式兼容 `Bundle.main.resourceURL/Contents/Resources`。
 - 当前打包脚本默认输出通用二进制：分别构建 `x86_64` 与 `arm64`，再用 `lipo` 合成，最终 `file dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1` 应显示 `Mach-O universal binary with 2 architectures`。
```

## 测试用例
### TC-001 Debug 构建验证
- 类型：构建测试
- 操作步骤：执行 `/bin/bash -c 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build'`
- 预期结果：新增 `TouchBarDiagnostics.swift` 后仍可正常编译。
- 是否通过：已通过。

### TC-002 Release 打包验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./package.sh`
- 预期结果：
- 正常完成 `x86_64` 与 `arm64` 构建
- 成功生成最新 `dist/Eliminate Teris 1.app`
- 当前环境若无法生成 DMG，则自动回退 ZIP 且流程不中断
- 是否通过：已通过。

### TC-003 真机诊断验证
- 类型：人工验证
- 操作步骤：
1. 执行 `ELIMINATE_TOUCHBAR_DIAGNOSTICS=1 'dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1'`
2. 连续冷启动多次，观察终端或 Console.app 中 `[TouchBarDiag]` 日志
3. 关注 system modal 挂载、异步刷新、健康检查与 fallback 顺序
- 预期结果：
- 能清楚看到每次启动时 Touch Bar 挂载流程
- 一旦再次出现黑屏，可从日志中判断是“尺寸无效”“未完成首帧绘制”还是“fallback 未触发/未接住”
- 是否通过：待用户在真机 Touch Bar 环境确认。
