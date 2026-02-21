# Touch Bar 私有 API 路线：系统级 Modal 展示

## 背景与目标
- 用户要求继续私有 API 路线，目标是像 Pock 一样尽量消除左侧 ESC 预留留白。
- 现有公开 API 方案在“左贴边”和“首二列间距一致”之间反复 trade-off。

## 调研结论
- 参考 Pock 源码可见，其核心使用私有方法 `presentSystemModalTouchBar`（以及对应 dismiss），并非仅靠常规 `window.touchBar`。
- 因此本次接入私有 API 的 system modal 展示链路，先验证可行性。

## 方案
- 保留单槽位 16 列渲染（`0..<16`），避免 ESC 槽位与主槽位的天然 seam。
- 在视图出现时，通过私有 API 调用 `presentSystemModalTouchBar`。
- 在视图消失 / 控制器释放时，调用 `dismissSystemModalTouchBar` 做清理。
- `window.touchBar` 仍保留作为回退路径，避免私有 API 调用失败时无 UI。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 4d3c2c3..8c4d04c 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -1,4 +1,5 @@
 import Cocoa
+import ObjectiveC.runtime
@@
-    private var touchBarFrameObserver: NSObjectProtocol?
+    private var isPresentingSystemModalTouchBar = false
@@
-        bar.escapeKeyReplacementItemIdentifier = .escapeGame
         bar.customizationAllowedItemIdentifiers = []
@@
-        if let touchBarFrameObserver {
-            NotificationCenter.default.removeObserver(touchBarFrameObserver)
-        }
+        dismissSystemModalTouchBarIfNeeded()
@@
         updateWindowTitle()
+        // 优先走私有 API 的系统级 Touch Bar 展示，尽可能消除 ESC 预留留白。
+        presentSystemModalTouchBarIfPossible()
+    }
+
+    override func viewDidDisappear() {
+        super.viewDidDisappear()
+        dismissSystemModalTouchBarIfNeeded()
     }
@@
-        if identifier == .escapeGame {
-            let item = NSCustomTouchBarItem(identifier: .escapeGame)
-            ...
-            return item
-        }
-
         guard identifier == .game else { return nil }
@@
+    private func presentSystemModalTouchBarIfPossible() {
+        guard isPresentingSystemModalTouchBar == false else { return }
+        let selector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
+        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }
+
+        typealias PresentModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
+        let implementation = method_getImplementation(method)
+        let function = unsafeBitCast(implementation, to: PresentModalTouchBar.self)
+        function(NSTouchBar.self, selector, gameTouchBar, 1, nil)
+        isPresentingSystemModalTouchBar = true
+    }
+
+    private func dismissSystemModalTouchBarIfNeeded() {
+        guard isPresentingSystemModalTouchBar else { return }
+        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
+        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }
+
+        typealias DismissModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
+        let implementation = method_getImplementation(method)
+        let function = unsafeBitCast(implementation, to: DismissModalTouchBar.self)
+        function(NSTouchBar.self, selector, gameTouchBar)
+        isPresentingSystemModalTouchBar = false
+    }
@@
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
-    static let escapeGame = NSTouchBarItem.Identifier("com.eliminateteris1.escape-game")
 }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- 已接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，当前策略改为“单槽位 16 列 + 系统级 modal 展示”，用于规避 ESC 预留留白与跨槽位缝隙并存问题。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221161737-touchbar-private-api-system-modal.md` - 引入私有 API 系统级 Touch Bar 展示，改为单槽位 16 列并尝试消除 ESC 预留留白。
@@
+- 需要确认“私有 API 路线（system modal）是否已接入”时，优先读取 `20260221161737` 文档。
@@
+- 已接入私有 API 调用链：`presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，当前策略为单槽位 16 列 + system modal 展示，以规避公开 API 下 ESC 预留留白。
```

## 风险提示
- 该方案依赖私有 API，系统版本变化可能导致行为变更。
- 上架分发/审核场景不建议使用。

## 测试用例
### TC-001 私有 API 路径生效
- 类型：功能测试
- 步骤：启动应用，观察 Touch Bar 是否进入系统级自定义展示。
- 预期：左侧 ESC 预留留白显著收敛。

### TC-002 退出清理
- 类型：稳定性测试
- 步骤：关闭窗口或退出应用。
- 预期：不会残留 modal touch bar，应用可正常退出。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
