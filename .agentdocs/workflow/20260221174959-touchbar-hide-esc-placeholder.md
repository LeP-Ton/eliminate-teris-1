# Touch Bar 恢复隐藏 ESC（占位替换）

## 背景与目标
- 用户反馈：系统 ESC 键又出现在 Touch Bar 左侧。
- 目标：在当前私有 API 路线不回退的前提下，重新隐藏 ESC。

## 方案
- 在 `NSTouchBar` 上恢复 `escapeKeyReplacementItemIdentifier`。
- 提供一个 0 宽占位 item（`escape-placeholder`）替换系统 ESC。
- 不改动现有主棋盘 item 与动画链路，避免引入新的布局回归。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 6d68740..5f7d7a5 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -404,6 +404,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let bar = NSTouchBar()
         bar.delegate = self
         bar.defaultItemIdentifiers = [.game]
+        // 用 0 宽占位替换 ESC，保持左侧不显示系统 ESC 键。
+        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
         bar.customizationAllowedItemIdentifiers = []
         bar.customizationRequiredItemIdentifiers = [.game]
         return bar
@@ -554,6 +556,19 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }
 
     func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
+        if identifier == .escapePlaceholder {
+            let item = NSCustomTouchBarItem(identifier: .escapePlaceholder)
+            let placeholder = NSView(frame: .zero)
+            placeholder.translatesAutoresizingMaskIntoConstraints = false
+            item.view = placeholder
+
+            NSLayoutConstraint.activate([
+                placeholder.widthAnchor.constraint(equalToConstant: 0),
+                placeholder.heightAnchor.constraint(equalToConstant: gameTouchBarView.intrinsicContentSize.height)
+            ])
+            return item
+        }
+
         guard identifier == .game else { return nil }
         let item = NSCustomTouchBarItem(identifier: .game)
         gameTouchBarView.translatesAutoresizingMaskIntoConstraints = false
@@ -2077,4 +2092,5 @@ private final class PixelBannerView: NSView {
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
+    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
 }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 10e4ebe..f3017cf 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -34,3 +34,4 @@
 - 已接入私有 API `NSTouchBar.presentSystemModalTouchBar` / `dismissSystemModalTouchBar`，当前策略改为“单槽位 16 列 + 系统级 modal 展示”，用于规避 ESC 预留留白与跨槽位缝隙并存问题。
 - 私有 API 展示链路已升级为“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；`window.touchBar` 仅在私有调用不可用时启用，避免与系统级 modal 渲染冲突。
 - 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
+- 当前已恢复 ESC 隐藏占位：`escapeKeyReplacementItemIdentifier` 绑定 0 宽 `escape-placeholder`，确保不显示系统 ESC 键且保持主棋盘渲染链路不变。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index c115fe6..9a2f3aa 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221174959-touchbar-hide-esc-placeholder.md` - 恢复 ESC 隐藏占位，避免系统 ESC 键重新显示。
 `workflow/20260221174215-touchbar-eliminate-move-animation.md` - 为 Touch Bar 增加交换/消除/左补位动画，并基于 tile id 做位移插值渲染。
@@ -33,6 +34,7 @@
 ## 读取场景
+- 需要确认“为什么 ESC 又出现、如何重新隐藏 ESC”时，优先读取 `20260221174959` 文档。
 - 需要确认“交换、消除、左补位动画是否已接入 Touch Bar”时，优先读取 `20260221174215` 文档。
@@ -66,6 +68,7 @@
 ## 关键记忆
+- Touch Bar 当前通过 `escapeKeyReplacementItemIdentifier = escape-placeholder`（0 宽视图）隐藏系统 ESC，避免私有 API 链路中再次显示 ESC 键。
 - Touch Bar 已接入过渡动画：共享 tile 使用位置插值，消除使用缩放淡出，新补位从左侧滑入；动画时长约 `0.22s`，曲线为 `easeOutCubic`。
```

## 测试用例
### TC-001 ESC 隐藏验证
- 类型：UI 测试
- 步骤：启动应用并聚焦窗口，查看 Touch Bar 左侧。
- 预期：系统 ESC 键不显示。

### TC-002 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
- 结果：已通过。
