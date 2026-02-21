# 修复 Touch Bar 首列左留白（首列视觉补偿 + 图案居中）

## 背景与目标
- 用户反馈：首按钮恢复显示后，左侧仍有留白，未贴齐左边。
- 目标：在不再引入“首按钮不显示”与“首块偏移”的前提下，继续收敛左侧留白。

## 约束与原则
- 不再依赖 ESC 槽位拆分（该方案在当前环境不稳定）。
- 不改触摸索引映射，避免交互副作用。
- 首列图案保持居中，避免再次出现“首块不居中”。

## 方案
- 保持单一 16 列视图渲染。
- 首列仅在视觉层做补偿：首列背景绘制区域向左扩展 `6px`。
- 首列图案不跟随扩展区域偏移，而是基于“首列可见区域”居中绘制。

## 当前进展
- 已完成首列视觉补偿与图案可见区域居中逻辑。
- 已完成本地构建验证。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 256e1a7..523b293 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -271,6 +271,7 @@ final class GameBoardController {
 final class GameTouchBarView: NSView {
     private enum Layout {
         static let controlHeight: CGFloat = 30
+        static let boardLeadingVisualCompensationX: CGFloat = 6
         static let tileOuterInsetX: CGFloat = 2
         static let tileOuterInsetY: CGFloat = 1
         static let tileInnerInsetX: CGFloat = 4
@@ -336,12 +337,13 @@ final class GameTouchBarView: NSView {
 
         for localIndex in 0..<columnCount {
             let globalIndex = columnRange.lowerBound + localIndex
-            let rect = cellRect(forLocalIndex: localIndex)
+            let rect = cellRect(forLocalIndex: localIndex, globalIndex: globalIndex)
+            let pieceRect = visibleCellRect(for: rect, globalIndex: globalIndex)
             let isSelected = controller.isSelected(globalIndex)
             let isLocked = controller.isLocked(globalIndex)
 
-            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
-            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
+            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
+            drawPiece(controller.tile(at: globalIndex), in: pieceRect, highlighted: isLocked || isSelected)
         }
     }
@@ -424,8 +426,13 @@ final class GameTouchBarView: NSView {
         controller.handleTap(at: index)
     }
 
-    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
-        let inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+    private func drawCellBackground(in rect: CGRect, globalIndex: Int, highlighted: Bool) {
+        var inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+        // 仅让全局第 0 列贴齐最左边缘，避免拆分视图后中间列误判为“首列”。
+        if globalIndex == 0 {
+            inset.origin.x -= Layout.tileOuterInsetX
+            inset.size.width += Layout.tileOuterInsetX * 2
+        }
         let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
         let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
         fill.setFill()
@@ -472,14 +479,23 @@ final class GameTouchBarView: NSView {
         }
     }
 
-    private func cellRect(forLocalIndex localIndex: Int) -> CGRect {
+    private func cellRect(forLocalIndex localIndex: Int, globalIndex: Int) -> CGRect {
         let width = boardWidth / CGFloat(columnCount)
-        return CGRect(
-            x: boardOriginX + CGFloat(localIndex) * width,
-            y: 0,
-            width: width,
-            height: bounds.height
-        )
+        let x = boardOriginX + CGFloat(localIndex) * width
+        if globalIndex == 0 {
+            return CGRect(
+                x: x - Layout.boardLeadingVisualCompensationX,
+                y: 0,
+                width: width + Layout.boardLeadingVisualCompensationX,
+                height: bounds.height
+            )
+        }
+        return CGRect(x: x, y: 0, width: width, height: bounds.height)
+    }
+
+    private func visibleCellRect(for rect: CGRect, globalIndex: Int) -> CGRect {
+        guard globalIndex == 0 else { return rect }
+        return rect.intersection(bounds)
     }
 ```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- Touch Bar 当前采用“首列单独视觉补偿”方案：首列背景绘制区域向左扩展 6px，图案绘制使用首列可见区域居中，避免“左贴边”和“图案偏移”互相冲突。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221150546-touchbar-first-cell-visual-compensation.md` - 首列左贴边与图案居中并行修复：首列背景左扩 6px，图案按可见区域居中。
@@
+- 需要确认“首列向左贴边但图案仍居中”的并行修复时，优先读取 `20260221150546` 文档。
@@
+- Touch Bar 首列使用独立视觉补偿：背景区域左扩 6px（不改触摸索引），图案绘制按首列可见区域居中，减少左留白同时避免首列图案偏移。
```

## 测试用例
### TC-001 首列左留白收敛
- 类型：UI 测试
- 步骤：启动应用并观察 Touch Bar 最左边缘与首按钮。
- 预期：首按钮更贴近最左边缘，左侧留白较上一版明显减小。

### TC-002 首列图案居中
- 类型：UI 测试
- 步骤：观察第一个按钮内方块图案位置。
- 预期：首列图案仍居中，不出现向左偏移。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
