# 修复 Touch Bar 首按钮左留白与首块不居中（ESC 槽位拆分方案）

## 背景与目标
- 用户反馈：前一版虽然尝试消除左留白，但出现“第一个方块没有在按钮中居中”的新问题。
- 目标：定位左留白真实来源，确保“首按钮贴左 + 首块保持居中”同时成立。

## 根因分析
- 左侧留白主要来自 Touch Bar 的 ESC 专属槽位与普通 item 区域分离。
- 之前通过整盘左移补偿处理，会导致首列可视宽度变化，进而产生“首块不居中”的副作用。

## 方案
- 把第 0 列单独挂载到 `escapeKeyReplacementItemIdentifier` 对应 item（占用 ESC 槽位）。
- 主棋盘 item 仅负责第 1...15 列，避免再通过整盘偏移挤压首列。
- 背景贴边逻辑改为按全局列号判断，仅全局第 0 列执行左补偿。

## 当前进展
- 已完成 Touch Bar 视图拆分：ESC 槽位（第 0 列）+ 主棋盘（第 1...15 列）。
- 首列图案保持居中，且不再依赖棋盘整体偏移。
- 已完成本地构建验证。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 533a06d..cd74ff6 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -43,7 +43,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let recordStore = ModeRecordStore.shared
 
     private lazy var controller = GameBoardController(columns: columns)
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
+    private lazy var escapeTouchBarView = GameTouchBarView(columnRange: 0..<1, controller: controller)
+    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 1..<columns, controller: controller)
@@ -403,7 +404,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let bar = NSTouchBar()
         bar.delegate = self
         bar.defaultItemIdentifiers = [.game]
-        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
+        bar.escapeKeyReplacementItemIdentifier = .escapeGame
         bar.customizationAllowedItemIdentifiers = []
         bar.customizationRequiredItemIdentifiers = [.game]
         return bar
@@ -542,15 +543,13 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }
 
     func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
-        if identifier == .escapePlaceholder {
-            let item = NSCustomTouchBarItem(identifier: .escapePlaceholder)
-            let placeholder = NSView(frame: .zero)
-            placeholder.translatesAutoresizingMaskIntoConstraints = false
-            item.view = placeholder
+        if identifier == .escapeGame {
+            let item = NSCustomTouchBarItem(identifier: .escapeGame)
+            escapeTouchBarView.translatesAutoresizingMaskIntoConstraints = false
+            item.view = escapeTouchBarView
 
             NSLayoutConstraint.activate([
-                placeholder.widthAnchor.constraint(equalToConstant: 0),
-                placeholder.heightAnchor.constraint(equalToConstant: 30)
+                escapeTouchBarView.heightAnchor.constraint(equalToConstant: escapeTouchBarView.intrinsicContentSize.height)
             ])
             return item
         }
@@ -2026,5 +2025,5 @@ private final class PixelBannerView: NSView {
 
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
-    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
+    static let escapeGame = NSTouchBarItem.Identifier("com.eliminateteris1.escape-game")
 }
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 256e1a7..5b2a31c 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -340,7 +340,7 @@ final class GameTouchBarView: NSView {
             let isSelected = controller.isSelected(globalIndex)
             let isLocked = controller.isLocked(globalIndex)
 
-            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
+            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
             drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
         }
     }
@@ -424,8 +424,13 @@ final class GameTouchBarView: NSView {
         controller.handleTap(at: index)
     }
 
-    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
-        let inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+    private func drawCellBackground(in rect: CGRect, globalIndex: Int, highlighted: Bool) {
+        var inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+        // 仅让全局第 0 列贴齐最左边缘，避免拆分视图后中间列误判为“首列”。
+        if globalIndex == 0 {
+            inset.origin.x -= Layout.tileOuterInsetX
+            inset.size.width += Layout.tileOuterInsetX
+        }
         let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
         let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
         fill.setFill()
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 013a694..b1f62e3 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -21,3 +21,6 @@
 - 玩法说明标题图标已切换为兼容性更高的 `doc.text`，并增加系统符号缺失时的回退图标，避免个别系统版本不显示。
 - 模式切换时会锁定窗口 frame，避免自由/竞分/竞速切换引发窗口尺寸跳变；并在切换后强制按最终布局重算挑战记录两端对齐文本。
 - Touch Bar 方块列数已从 12 扩展到 16，控制区可同时显示 16 个可交互方块。
+- Touch Bar 最左格背景已贴齐左边缘（首列取消额外左 inset），修复“首个方块左侧留白”问题。
+- Touch Bar 首列方块图案曾尝试左移与左对齐（用于排查留白来源），当前已回退为按钮内居中。
+- Touch Bar 左侧留白根因为 ESC 专属槽位与主棋盘区域分离；现将第 0 列挂到 `escapeKeyReplacementItemIdentifier`，主棋盘显示第 1...15 列，首列保持居中且不再依赖棋盘整体左移补偿。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 158187f..65b0102 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221144850-touchbar-escape-slot-split-fix.md` - 修复首按钮左侧留白根因：将第 0 列挂载到 ESC 替换槽位，主棋盘改为第 1...15 列，避免首列图案偏移。
@@ -18,6 +19,7 @@
 ## 读取场景
+- 需要确认“首按钮左侧留白来自 ESC 槽位、并通过拆分 Touch Bar 视图修复”时，优先读取 `20260221144850` 文档。
@@ -36,6 +38,10 @@
 ## 关键记忆
+- Touch Bar 左侧留白的最新根因定位为 ESC 专属槽位与主棋盘区域分离；当前方案是“ESC 槽位承载第 0 列 + 主棋盘承载第 1...15 列”。
+- 首列图案在排查期曾改为左对齐，现已回退为按钮内居中；当前留白修复基于“ESC 槽位拆分”，不再移动整盘坐标。
+- 旧的“棋盘整体左移补偿（`boardOriginX = -6`）”方案已下线，避免首列可视宽度变窄导致“图案不居中”副作用。
+- 首列对齐当前仅作用于背景层：仅全局第 0 列执行左补偿 `tileOuterInsetX`，图案层统一保持居中绘制。
 ```

## 测试用例
### TC-001 首按钮左侧留白消除
- 类型：UI 测试
- 步骤：启动应用，观察 Touch Bar 最左边界与首按钮左边缘。
- 预期：首按钮贴近最左边界，无额外空白槽位。

### TC-002 首按钮图案居中
- 类型：UI 测试
- 步骤：观察第一个按钮内的方块图案位置。
- 预期：图案在按钮内保持居中，不再出现偏移。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=$PWD/.tmp-home DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：编译通过，生成 `Eliminate Teris 1`。
