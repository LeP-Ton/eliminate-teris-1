# 修复首列按钮左侧留白（根因修复：棋盘整体左移补偿）

## 背景与目标
- 用户反馈：此前修复引入新问题，首列方块不再在按钮内居中。
- 用户真实诉求：首列方块需保持按钮内居中，同时去掉“首按钮左侧留白”。

## 根因分析
- 留白并非仅来自首列图案位置，而是棋盘绘制区域起点与 Touch Bar 项容器存在左侧保留空隙。
- 直接把首列图案左对齐会破坏“按钮内居中”，属于副作用修复。

## 约束与原则
- 首列方块必须恢复居中。
- 只通过棋盘整体偏移抵消容器左侧留白，避免影响触摸索引逻辑。
- 保持其余列布局与交互一致。

## 阶段与 TODO
- [x] 回退首列图案左对齐，恢复图案居中。
- [x] 增加棋盘整体左移补偿（`boardOriginX` / `boardWidth`）。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 首列图案已恢复按钮内居中。
- 棋盘整体左移 6px 并扩宽 6px，抵消左侧容器留白。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index a690fb5..b6690e8 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -283,6 +283,7 @@ final class GameTouchBarView: NSView {
     private enum Layout {
         static let controlHeight: CGFloat = 30
+        static let boardLeadingCompensationX: CGFloat = 6
         static let tileOuterInsetX: CGFloat = 2
@@ -342,7 +343,7 @@ final class GameTouchBarView: NSView {
             let isLocked = controller.isLocked(globalIndex)
 
             drawCellBackground(in: rect, localIndex: localIndex, highlighted: isLocked || isSelected)
-            drawPiece(controller.tile(at: globalIndex), in: rect, localIndex: localIndex, highlighted: isLocked || isSelected)
+            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
         }
     }
@@ -440,7 +441,7 @@ final class GameTouchBarView: NSView {
-    private func drawPiece(_ kind: PieceKind, in rect: CGRect, localIndex: Int, highlighted: Bool) {
+    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool) {
         let inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
@@ -456,13 +457,7 @@ final class GameTouchBarView: NSView {
         let blockSize = min(inner.width / CGFloat(width), inner.height / CGFloat(height))
 
         let totalWidth = blockSize * CGFloat(width)
-        let totalHeight = blockSize * CGFloat(height)
-        // 首列按左对齐放置图案，其他列保持居中布局。
-        let originX: CGFloat
-        if localIndex == 0 {
-            originX = inner.minX
-        } else {
-            originX = inner.minX + (inner.width - totalWidth) * 0.5
-        }
+        let totalHeight = blockSize * CGFloat(height)
+        let originX = inner.minX + (inner.width - totalWidth) * 0.5
         let originY = inner.minY + (inner.height - totalHeight) * 0.5
@@ -518,11 +513,13 @@ final class GameTouchBarView: NSView {
     }
 
     private var boardWidth: CGFloat {
-        return max(0, bounds.width)
+        return max(0, bounds.width + Layout.boardLeadingCompensationX)
     }
 
     private var boardOriginX: CGFloat {
-        return 0
+        // 左移棋盘起点，抵消 Touch Bar 项容器的默认左侧留白。
+        return -Layout.boardLeadingCompensationX
     }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index f0ac939..12491f5 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -22,5 +22,5 @@
 - 模式切换时会锁定窗口 frame，避免自由/竞分/竞速切换引发窗口尺寸跳变；并在切换后强制按最终布局重算挑战记录两端对齐文本。
 - Touch Bar 方块列数已从 12 扩展到 16，控制区可同时显示 16 个可交互方块。
 - Touch Bar 最左格背景已贴齐左边缘（首列取消额外左 inset），修复“首个方块左侧留白”问题。
-- Touch Bar 首列方块图案绘制也会左移（不仅背景贴边），进一步消除首列视觉留白。
-- Touch Bar 首列图案定位策略已改为“左对齐而非居中”，确保首列方块视觉上真正贴近左边界。
+- Touch Bar 首列方块图案曾尝试左移与左对齐（用于排查留白来源），当前已回退为按钮内居中。
+- Touch Bar 首列方块已恢复按钮内居中，同时通过棋盘整体左移补偿（`boardOriginX = -6`）消除“按钮左侧留白”。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221144303-touchbar-left-padding-root-cause-board-offset.md` - 修复首列按钮左侧留白：恢复首列图案居中并通过棋盘左移补偿消除容器留白。
@@
 ## 读取场景
+- 需要确认“首列方块居中且首按钮左侧留白消除”的根因修复时，优先读取 `20260221144303` 文档。
@@
 ## 关键记忆
+- Touch Bar 左侧留白根因定位为棋盘整体起点未抵消容器留白；现通过 `boardOriginX = -6` 与 `boardWidth = bounds.width + 6` 处理，首列图案恢复居中显示。
@@
-- 首列图案最终采用“左对齐”策略（非居中），与首列背景贴边叠加后可最大化消除左侧视觉留白。
+- 首列图案在排查期曾改为左对齐，最终回退为按钮内居中；左侧留白通过棋盘整体左移补偿方案解决。
```

## 测试用例
### TC-001 首列按钮内居中
- 类型：UI测试
- 操作步骤：启动应用，观察首列方块在按钮内位置。
- 预期结果：首列方块居中，不出现“偏左/偏右”。

### TC-002 首按钮左侧留白
- 类型：UI测试
- 操作步骤：观察 Touch Bar 最左边界与首按钮之间间距。
- 预期结果：首按钮更贴近左边界，留白明显收敛。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
