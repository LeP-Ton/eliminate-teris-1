# 继续修复 Touch Bar 首列留白（首列图案左移）

## 背景与目标
- 用户反馈：在“首列背景贴边”后，首列左侧仍存在视觉留白。
- 目标：让首列图案也向左贴近边缘，进一步消除首列留白感。

## 约束与原则
- 不改触摸索引与棋盘逻辑，仅调整首列绘制偏移。
- 仅影响首列，其他列绘制保持不变。

## 阶段与 TODO
- [x] 让 `drawPiece` 接收 `localIndex`。
- [x] 对首列图案增加左移补偿。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 首列背景与图案均已做左对齐处理：背景贴边、图案左移。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 7b888d3..1a8dce2 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -338,7 +338,7 @@ final class GameTouchBarView: NSView {
             let isLocked = controller.isLocked(globalIndex)
 
             drawCellBackground(in: rect, localIndex: localIndex, highlighted: isLocked || isSelected)
-            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
+            drawPiece(controller.tile(at: globalIndex), in: rect, localIndex: localIndex, highlighted: isLocked || isSelected)
         }
     }
@@ -421,7 +421,12 @@ final class GameTouchBarView: NSView {
-    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool) {
-        let inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
+    private func drawPiece(_ kind: PieceKind, in rect: CGRect, localIndex: Int, highlighted: Bool) {
+        var inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
+        // 首列图案也向左贴边，避免看起来仍有左侧空白。
+        if localIndex == 0 {
+            inner.origin.x -= Layout.tileInnerInsetX
+        }
         guard inner.width > 0, inner.height > 0 else { return }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index d2d3b53..d846cc1 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -22,3 +22,4 @@
 - 模式切换时会锁定窗口 frame，避免自由/竞分/竞速切换引发窗口尺寸跳变；并在切换后强制按最终布局重算挑战记录两端对齐文本。
 - Touch Bar 方块列数已从 12 扩展到 16，控制区可同时显示 16 个可交互方块。
 - Touch Bar 最左格背景已贴齐左边缘（首列取消额外左 inset），修复“首个方块左侧留白”问题。
+- Touch Bar 首列方块图案绘制也会左移（不仅背景贴边），进一步消除首列视觉留白。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221143308-touchbar-left-edge-align-piece-shift.md` - 继续修复首列留白：首列方块图案左移，配合背景贴边实现更彻底左对齐。
@@
 ## 读取场景
+- 需要确认“首列图案也左移、首列视觉留白进一步消除”时，优先读取 `20260221143308` 文档。
@@
 ## 关键记忆
+- 首列对齐已覆盖“背景 + 图案”两层：背景左补偿 `tileOuterInsetX`，图案左移 `tileInnerInsetX`。
```

## 测试用例
### TC-001 首列视觉贴边
- 类型：UI测试
- 操作步骤：启动应用并观察 Touch Bar 最左列。
- 预期结果：首列背景与图案都更靠左，留白明显减少。

### TC-002 其他列稳定性
- 类型：UI测试
- 操作步骤：观察第2列及后续列图案位置。
- 预期结果：非首列布局不发生明显变化。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
