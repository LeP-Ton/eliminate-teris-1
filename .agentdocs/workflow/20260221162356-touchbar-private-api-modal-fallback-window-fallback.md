# Touch Bar 私有 API 路线增强：双签名回退 + window 兜底隔离

## 背景与目标
- 用户确认继续走私有 API 路线，希望最大化复现类似 Pock 的最左贴边效果。
- 当前实现仍保留 `window.touchBar` 常规路径，可能与系统级 modal 展示互相干扰。

## 本次调整
- 将系统级展示入口改为“先私有 API，后 window 兜底”。
- 私有 API 调用改为“双签名回退”：
  - 优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`
  - 回退 `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`（placement=自动）
- `AppDelegate` 不再提前注入 `window.touchBar`，避免在窗口初始化阶段抢占展示路径。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
@@
-    override func viewDidAppear() {
-        super.viewDidAppear()
-        view.window?.touchBar = gameTouchBar
+    override func viewDidAppear() {
+        super.viewDidAppear()
+        // 优先使用系统级 modal touch bar；仅在不可用时回退 window.touchBar。
+        if presentSystemModalTouchBarIfPossible() {
+            view.window?.touchBar = nil
+        } else {
+            view.window?.touchBar = gameTouchBar
+        }
@@
-    private func presentSystemModalTouchBarIfPossible() {
-        guard isPresentingSystemModalTouchBar == false else { return }
-        let selector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
-        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }
-
-        typealias PresentModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
-        let implementation = method_getImplementation(method)
-        let function = unsafeBitCast(implementation, to: PresentModalTouchBar.self)
-        function(NSTouchBar.self, selector, gameTouchBar, 1, nil)
-        isPresentingSystemModalTouchBar = true
+    private func presentSystemModalTouchBarIfPossible() -> Bool {
+        guard isPresentingSystemModalTouchBar == false else { return true }
+
+        // 优先匹配 Pock 同款签名，减少不同系统版本下 placement 语义差异带来的布局偏移。
+        let modernSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
+        if let modernMethod = class_getClassMethod(NSTouchBar.self, modernSelector) {
+            typealias PresentModernModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
+            let implementation = method_getImplementation(modernMethod)
+            let function = unsafeBitCast(implementation, to: PresentModernModalTouchBar.self)
+            function(NSTouchBar.self, modernSelector, gameTouchBar, nil)
+            isPresentingSystemModalTouchBar = true
+            return true
+        }
+
+        // 回退三参签名，placement 使用 0（自动）避免硬编码到特定槽位策略。
+        let fallbackSelector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
+        guard let fallbackMethod = class_getClassMethod(NSTouchBar.self, fallbackSelector) else { return false }
+
+        typealias PresentFallbackModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
+        let fallbackImplementation = method_getImplementation(fallbackMethod)
+        let fallbackFunction = unsafeBitCast(fallbackImplementation, to: PresentFallbackModalTouchBar.self)
+        fallbackFunction(NSTouchBar.self, fallbackSelector, gameTouchBar, 0, nil)
+        isPresentingSystemModalTouchBar = true
+        return true
     }
```

- Sources/AppDelegate.swift
```diff
diff --git a/Sources/AppDelegate.swift b/Sources/AppDelegate.swift
@@
         window.center()
         window.title = Localizer.shared.string("window.title")
         window.contentViewController = viewController
-        window.touchBar = viewController.makeTouchBar()
         window.makeFirstResponder(viewController)
         window.makeKeyAndOrderFront(nil)
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- 私有 API 展示链路已升级为“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；`window.touchBar` 仅在私有调用不可用时启用，避免与系统级 modal 渲染冲突。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221162356-touchbar-private-api-modal-fallback-window-fallback.md` - 私有 API 触发改为双签名回退，并将 `window.touchBar` 限制为私有调用失败时的兜底路径。
@@
+- 需要确认“私有 API 触发失败时如何回退、是否还会与 window.touchBar 冲突”时，优先读取 `20260221162356` 文档。
@@
+- 私有 API 当前采用双签名回退：优先调用 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，不可用时回退到 `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`（placement=自动）；仅在两者都不可用时才启用 `window.touchBar`。
```

## 测试用例
### TC-001 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`
- 预期：构建成功
- 结果：已通过

### TC-002 Touch Bar 展示路径验证
- 类型：功能测试
- 步骤：
  1. 运行应用并聚焦窗口
  2. 观察最左侧是否仍存在 ESC 预留留白
  3. 切到其它应用再切回，确认 Touch Bar 持续可用
- 预期：
  - 私有 API 生效时优先显示系统级 modal 触控栏
  - 若私有签名不可用，自动回退常规 `window.touchBar`
