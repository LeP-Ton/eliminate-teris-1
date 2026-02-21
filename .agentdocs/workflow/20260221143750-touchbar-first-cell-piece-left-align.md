# 继续修复首列留白：首列图案改为左对齐

## 背景与目标
- 用户反馈：即使已做首列贴边，最左侧仍有留白感。
- 目标：把首列图案从“居中”改为“左对齐”，进一步消除首列视觉空白。

## 约束与原则
- 不改触摸索引逻辑，仅改绘制定位。
- 仅作用于首列，其他列保持原居中策略。

## 阶段与 TODO
- [x] 将首列图案定位从居中改为左对齐。
- [x] 保持非首列图案仍居中。
- [x] 更新 AGENTS 与索引文档。
- [x] 完成构建验证。

## 当前进展
- 首列图案已按左对齐放置；非首列继续居中。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 1a8dce2..a690fb5 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -421,12 +421,7 @@ final class GameTouchBarView: NSView {
-    private func drawPiece(_ kind: PieceKind, in rect: CGRect, localIndex: Int, highlighted: Bool) {
-        var inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
-        // 首列图案也向左贴边，避免看起来仍有左侧空白。
-        if localIndex == 0 {
-            inner.origin.x -= Layout.tileInnerInsetX
-        }
+    private func drawPiece(_ kind: PieceKind, in rect: CGRect, localIndex: Int, highlighted: Bool) {
+        let inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
         guard inner.width > 0, inner.height > 0 else { return }
@@ -434,7 +429,14 @@ final class GameTouchBarView: NSView {
         let width = maxX - minX + 1
         let height = maxY - minY + 1
         let blockSize = min(inner.width / CGFloat(width), inner.height / CGFloat(height))
 
         let totalWidth = blockSize * CGFloat(width)
         let totalHeight = blockSize * CGFloat(height)
-        let originX = inner.minX + (inner.width - totalWidth) * 0.5
+        // 首列按左对齐放置图案，其他列保持居中布局。
+        let originX: CGFloat
+        if localIndex == 0 {
+            originX = inner.minX
+        } else {
+            originX = inner.minX + (inner.width - totalWidth) * 0.5
+        }
         let originY = inner.minY + (inner.height - totalHeight) * 0.5
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index d846cc1..f0ac939 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -23,3 +23,4 @@
 - Touch Bar 方块列数已从 12 扩展到 16，控制区可同时显示 16 个可交互方块。
 - Touch Bar 最左格背景已贴齐左边缘（首列取消额外左 inset），修复“首个方块左侧留白”问题。
 - Touch Bar 首列方块图案绘制也会左移（不仅背景贴边），进一步消除首列视觉留白。
+- Touch Bar 首列图案定位策略已改为“左对齐而非居中”，确保首列方块视觉上真正贴近左边界。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221143750-touchbar-first-cell-piece-left-align.md` - 继续修复首列留白：首列图案改为左对齐，避免首列仍然居中导致视觉空白。
@@
 ## 读取场景
+- 需要确认“首列图案从居中改为左对齐后留白消除”时，优先读取 `20260221143750` 文档。
@@
 ## 关键记忆
+- 首列图案最终采用“左对齐”策略（非居中），与首列背景贴边叠加后可最大化消除左侧视觉留白。
```

## 测试用例
### TC-001 首列图案对齐
- 类型：UI测试
- 操作步骤：启动应用，观察 Touch Bar 首列图案位置。
- 预期结果：首列图案明显更靠左，不再有“居中导致的左边留白感”。

### TC-002 非首列不受影响
- 类型：UI测试
- 操作步骤：观察第2列及后续列图案位置。
- 预期结果：非首列仍保持居中展示。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
