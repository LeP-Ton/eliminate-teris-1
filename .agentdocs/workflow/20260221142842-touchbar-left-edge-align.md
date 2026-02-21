# 修复 Touch Bar 首个方块左侧留白（左边缘对齐）

## 背景与目标
- 用户反馈：Touch Bar 最左边方块左侧仍有一段空白。
- 目标：让首个方块背景贴齐最左边缘，不再出现左侧留白。

## 约束与原则
- 不改交互索引与触摸映射，仅修正绘制区域。
- 保持其他列之间原有间距与视觉风格。

## 阶段与 TODO
- [x] 调整首列背景绘制 inset 逻辑。
- [x] 保持其余列绘制不变，避免连带影响。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 首列背景会向左补偿一个 `tileOuterInsetX`，并相应扩宽背景宽度。
- Touch Bar 左侧留白已移除，首格贴齐左边缘。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 6b28116..7b888d3 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -338,7 +338,7 @@ final class GameTouchBarView: NSView {
             let isSelected = controller.isSelected(globalIndex)
             let isLocked = controller.isLocked(globalIndex)
 
-            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
+            drawCellBackground(in: rect, localIndex: localIndex, highlighted: isLocked || isSelected)
             drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
         }
     }
@@ -411,8 +411,14 @@ final class GameTouchBarView: NSView {
-    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
-        let inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+    private func drawCellBackground(in rect: CGRect, localIndex: Int, highlighted: Bool) {
+        var inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+        // 让最左侧格子贴齐 Touch Bar 左边缘，不再保留额外左侧空白。
+        if localIndex == 0 {
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
index b9fd95c..d2d3b53 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -21,3 +21,4 @@
 - 玩法说明标题图标已切换为兼容性更高的 `doc.text`，并增加系统符号缺失时的回退图标，避免个别系统版本不显示。
 - 模式切换时会锁定窗口 frame，避免自由/竞分/竞速切换引发窗口尺寸跳变；并在切换后强制按最终布局重算挑战记录两端对齐文本。
 - Touch Bar 方块列数已从 12 扩展到 16，控制区可同时显示 16 个可交互方块。
+- Touch Bar 最左格背景已贴齐左边缘（首列取消额外左 inset），修复“首个方块左侧留白”问题。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221142842-touchbar-left-edge-align.md` - 修复 Touch Bar 首个方块左侧留白，使最左格贴齐左边缘。
@@
 ## 读取场景
+- 需要确认“Touch Bar 最左方块左对齐、无额外留白”时，优先读取 `20260221142842` 文档。
@@
 ## 关键记忆
+- Touch Bar 首列背景绘制会在 x 方向向左补偿 `tileOuterInsetX`，以贴齐最左边界并保留其余列间距策略。
```

## 测试用例
### TC-001 首列左对齐
- 类型：UI测试
- 操作步骤：启动应用，观察 Touch Bar 最左方块背景左边缘。
- 预期结果：首列贴齐左边缘，不再有额外留白。

### TC-002 其他列间距稳定
- 类型：UI测试
- 操作步骤：观察前几列之间的间距与高亮样式。
- 预期结果：除首列左边缘外，其余列间距与原视觉一致。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
