# 修复首按钮偏窄：ESC 槽位与主棋盘列宽同步

## 背景与目标
- 用户反馈：最左按钮已经贴左，但宽度明显比其他按钮窄。
- 目标：保持“最左贴边”的前提下，让首按钮宽度与其他列一致。

## 根因分析
- ESC 槽位首列此前使用固定宽度常量，主棋盘列宽是按剩余空间动态分配，二者不一致会出现首列偏窄。

## 方案
- 仍保留 ESC 槽位承载第 0 列、主棋盘承载第 1...15 列的结构。
- ESC 槽位宽度改为动态同步：`主棋盘当前宽度 / 15`。
- 监听主棋盘 frame 变化，实时更新 ESC 槽位宽度，避免窗口/系统栏变化后再次失配。
- 增加 fallback 宽度（56）仅作初始保底，防止首帧宽度为 0 时塌陷。

## 当前进展
- 已实现 ESC 槽位首列宽度与主棋盘单列宽度同步。
- 已完成本地编译验证。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 533a06d..35b572e 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -38,14 +38,17 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
 
     private let columns = 16
+    private let escapeColumnFallbackWidth: CGFloat = 56
@@
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
+    private lazy var escapeTouchBarView = GameTouchBarView(columnRange: 0..<1, controller: controller)
+    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 1..<columns, controller: controller)
 
     private var observerToken: UUID?
+    private var touchBarFrameObserver: NSObjectProtocol?
@@
     private var settingsExpandedWidthConstraint: NSLayoutConstraint?
     private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
     private var rightColumnMinWidthConstraint: NSLayoutConstraint?
+    private var escapeColumnWidthConstraint: NSLayoutConstraint?
@@ -403,7 +407,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let bar = NSTouchBar()
         bar.delegate = self
         bar.defaultItemIdentifiers = [.game]
-        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
+        bar.escapeKeyReplacementItemIdentifier = .escapeGame
@@ -516,6 +520,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         if let observerToken {
             controller.removeObserver(observerToken)
         }
+        if let touchBarFrameObserver {
+            NotificationCenter.default.removeObserver(touchBarFrameObserver)
+        }
         hudTimer?.invalidate()
     }
@@ -542,16 +549,21 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
-        if identifier == .escapePlaceholder {
-            let item = NSCustomTouchBarItem(identifier: .escapePlaceholder)
-            let placeholder = NSView(frame: .zero)
-            placeholder.translatesAutoresizingMaskIntoConstraints = false
-            item.view = placeholder
+        if identifier == .escapeGame {
+            let item = NSCustomTouchBarItem(identifier: .escapeGame)
+            escapeTouchBarView.translatesAutoresizingMaskIntoConstraints = false
+            item.view = escapeTouchBarView
 
+            let widthConstraint = escapeTouchBarView.widthAnchor.constraint(equalToConstant: escapeColumnFallbackWidth)
+            escapeColumnWidthConstraint = widthConstraint
             NSLayoutConstraint.activate([
-                placeholder.widthAnchor.constraint(equalToConstant: 0),
-                placeholder.heightAnchor.constraint(equalToConstant: 30)
+                widthConstraint,
+                escapeTouchBarView.heightAnchor.constraint(equalToConstant: escapeTouchBarView.intrinsicContentSize.height)
             ])
+
+            DispatchQueue.main.async { [weak self] in
+                self?.updateEscapeColumnWidth()
+            }
             return item
         }
@@ -563,9 +575,40 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         NSLayoutConstraint.activate([
             gameTouchBarView.heightAnchor.constraint(equalToConstant: gameTouchBarView.intrinsicContentSize.height)
         ])
+
+        installTouchBarFrameObserverIfNeeded()
+        DispatchQueue.main.async { [weak self] in
+            self?.updateEscapeColumnWidth()
+        }
         return item
     }
+
+    private func installTouchBarFrameObserverIfNeeded() {
+        guard touchBarFrameObserver == nil else { return }
+        gameTouchBarView.postsFrameChangedNotifications = true
+        touchBarFrameObserver = NotificationCenter.default.addObserver(
+            forName: NSView.frameDidChangeNotification,
+            object: gameTouchBarView,
+            queue: .main
+        ) { [weak self] _ in
+            self?.updateEscapeColumnWidth()
+        }
+    }
+
+    private func updateEscapeColumnWidth() {
+        guard let escapeColumnWidthConstraint else { return }
+
+        let mainWidth = gameTouchBarView.bounds.width
+        guard mainWidth > 0 else { return }
+
+        let denominator = max(1, columns - 1)
+        // 让 ESC 槽位列宽跟随主棋盘单列宽度，避免首列视觉偏窄。
+        let targetWidth = max(44, round(mainWidth / CGFloat(denominator)))
+        if abs(escapeColumnWidthConstraint.constant - targetWidth) > 0.5 {
+            escapeColumnWidthConstraint.constant = targetWidth
+        }
+    }
@@ -2026,5 +2069,5 @@ private final class PixelBannerView: NSView {
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
-    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
+    static let escapeGame = NSTouchBarItem.Identifier("com.eliminateteris1.escape-game")
 }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- ESC 槽位首列宽度已改为“跟随主棋盘单列宽度自适应”，通过监听主棋盘 frame 动态更新首列宽度，修复首列偏窄问题。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221151827-touchbar-escape-column-width-sync.md` - 修复首按钮偏窄：ESC 槽位宽度跟随主棋盘单列宽度动态同步。
@@
+- 需要确认“首按钮偏窄”修复（ESC 槽位与主棋盘列宽同步）时，优先读取 `20260221151827` 文档。
@@
+- ESC 槽位首列宽度不再固定常量，改为实时同步 `主棋盘宽度 / 15`，并监听主棋盘 frame 变化自动更新，避免首列视觉偏窄。
```

## 测试用例
### TC-001 首列宽度一致
- 类型：UI 测试
- 步骤：启动应用，观察首按钮和第二按钮宽度。
- 预期：两者宽度接近一致，不再明显偏窄。

### TC-002 动态同步验证
- 类型：UI 测试
- 步骤：触发 Touch Bar 可用宽度变化（如显示/隐藏系统功能栏），观察首列宽度。
- 预期：首列宽度可跟随主棋盘列宽变化，无明显失配。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
