# 重构 Touch Bar 左侧布局：首列挂到 ESC 槽位并显式定宽

## 背景与目标
- 用户持续反馈：最左侧仍有留白，要求像系统 ESC 或其他应用一样贴左显示。
- 目标：让第一个按钮直接占用系统 ESC 槽位，从结构上消除左侧空白。

## 根因与决策
- 单一主棋盘 item 无法完全消除系统为 ESC 区域预留的空间。
- 之前把首列挂 ESC 槽位时“首按钮消失”，根因为 ESC 槽位视图宽度未定导致被压缩为 0。
- 本次采用“ESC 槽位拆分 + 显式宽度”方案，先确保左贴边与首按钮可见。

## 方案
- 第 0 列使用 `escapeKeyReplacementItemIdentifier` 的自定义 item 承载。
- 主棋盘 item 改为仅显示第 1...15 列。
- 给 ESC 槽位首列视图增加 `48pt` 显式宽度约束，避免首按钮丢失。
- 回退此前“首列单独视觉补偿”逻辑，保持绘制与触摸索引简洁稳定。

## 当前进展
- 已完成 Touch Bar 左侧结构重构。
- 已完成本地构建验证。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 533a06d..77f4200 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -38,12 +38,14 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
 
     private let columns = 16
+    private let escapeColumnWidth: CGFloat = 48
     private let scoreAttackMinutes = [1, 2, 3]
     private let speedRunTargets = [300, 600, 900]
     private let recordStore = ModeRecordStore.shared
 
     private lazy var controller = GameBoardController(columns: columns)
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
+    private lazy var escapeTouchBarView = GameTouchBarView(columnRange: 0..<1, controller: controller)
+    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 1..<columns, controller: controller)
@@ -403,7 +405,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let bar = NSTouchBar()
         bar.delegate = self
         bar.defaultItemIdentifiers = [.game]
-        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
+        bar.escapeKeyReplacementItemIdentifier = .escapeGame
         bar.customizationAllowedItemIdentifiers = []
         bar.customizationRequiredItemIdentifiers = [.game]
         return bar
@@ -545,15 +547,14 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
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
+                escapeTouchBarView.widthAnchor.constraint(equalToConstant: escapeColumnWidth),
+                escapeTouchBarView.heightAnchor.constraint(equalToConstant: escapeTouchBarView.intrinsicContentSize.height)
             ])
             return item
         }
@@ -2027,5 +2028,5 @@ private final class PixelBannerView: NSView {
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
-    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
+    static let escapeGame = NSTouchBarItem.Identifier("com.eliminateteris1.escape-game")
 }
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 523b293..5b2a31c 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -271,7 +271,6 @@ final class GameBoardController {
 final class GameTouchBarView: NSView {
     private enum Layout {
         static let controlHeight: CGFloat = 30
-        static let boardLeadingVisualCompensationX: CGFloat = 6
         static let tileOuterInsetX: CGFloat = 2
         static let tileOuterInsetY: CGFloat = 1
         static let tileInnerInsetX: CGFloat = 4
@@ -338,8 +337,7 @@ final class GameTouchBarView: NSView {
         for localIndex in 0..<columnCount {
             let globalIndex = columnRange.lowerBound + localIndex
-            let rect = cellRect(forLocalIndex: localIndex, globalIndex: globalIndex)
-            let pieceRect = visibleCellRect(for: rect, globalIndex: globalIndex)
+            let rect = cellRect(forLocalIndex: localIndex)
             let isSelected = controller.isSelected(globalIndex)
             let isLocked = controller.isLocked(globalIndex)
 
@@ -345,7 +343,7 @@ final class GameTouchBarView: NSView {
             drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
-            drawPiece(controller.tile(at: globalIndex), in: pieceRect, highlighted: isLocked || isSelected)
+            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
         }
     }
@@ -482,25 +479,14 @@ final class GameTouchBarView: NSView {
-    private func cellRect(forLocalIndex localIndex: Int, globalIndex: Int) -> CGRect {
+    private func cellRect(forLocalIndex localIndex: Int) -> CGRect {
         let width = boardWidth / CGFloat(columnCount)
-        let x = boardOriginX + CGFloat(localIndex) * width
-        if globalIndex == 0 {
-            return CGRect(
-                x: x - Layout.boardLeadingVisualCompensationX,
-                y: 0,
-                width: width + Layout.boardLeadingVisualCompensationX,
-                height: bounds.height
-            )
-        }
-        return CGRect(x: x, y: 0, width: width, height: bounds.height)
-    }
-
-    private func visibleCellRect(for rect: CGRect, globalIndex: Int) -> CGRect {
-        guard globalIndex == 0 else { return rect }
-        return rect.intersection(bounds)
+        return CGRect(
+            x: boardOriginX + CGFloat(localIndex) * width,
+            y: 0,
+            width: width,
+            height: bounds.height
+        )
     }
 ```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- Touch Bar 最新方案：恢复 ESC 槽位拆分并给首列显式宽度（48pt），第 0 列放到 `escapeKeyReplacementItemIdentifier`、第 1...15 列放主棋盘，确保最左按钮占用系统 ESC 位置且可见。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221151437-touchbar-escape-slot-split-with-fixed-width.md` - 重构 Touch Bar 左侧布局：首列挂到 ESC 槽位并增加显式宽度，主棋盘显示 1...15 列。
@@
+- 需要确认“最左按钮占用 ESC 槽位且不再消失”的重构修复时，优先读取 `20260221151437` 文档。
@@
+- Touch Bar 左侧最新实现为“ESC 槽位首列 + 主区 1...15 列”，并给 ESC 槽位视图显式宽度 48pt，避免首列消失并贴齐最左边。
```

## 测试用例
### TC-001 首按钮左贴边
- 类型：UI 测试
- 步骤：启动应用，观察 Touch Bar 最左侧。
- 预期：第一个按钮占用最左 ESC 位置，不再有额外左留白。

### TC-002 首按钮可见性
- 类型：UI 测试
- 步骤：确认首按钮始终可见。
- 预期：不再出现“首按钮不显示”。

### TC-003 首二列间距
- 类型：UI 测试
- 步骤：观察第 1、2 个按钮间距与后续列。
- 预期：间距稳定，无异常放大。

### TC-004 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
