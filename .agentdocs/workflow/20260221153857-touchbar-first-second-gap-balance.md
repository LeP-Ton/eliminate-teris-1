# 修复首二列间距偏大（ESC 分隔补偿）

## 背景与目标
- 用户反馈：最左侧起第一个和第二个按钮之间间距，比其他按钮明显更大。
- 目标：在保留“首按钮贴左 + 首列可见”的前提下，拉齐首二列与其他列的间距。

## 根因分析
- 第 0 列位于 ESC 槽位，第 1 列位于主棋盘 item，二者之间存在系统级分隔。
- 即使列宽一致，该分隔也会让首二列视觉间距偏大。

## 方案
- 不改触摸索引、不改列宽同步逻辑。
- 仅在绘制层对 `globalIndex == 1`（第 1 列）收敛左内边距，抵消系统分隔造成的额外空隙。

## 当前进展
- 已完成第 1 列左内边距补偿，首二列间距与其余列更接近。
- 已完成本地构建验证。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 5b2a31c..97dd45a 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -430,6 +430,10 @@ final class GameTouchBarView: NSView {
         if globalIndex == 0 {
             inset.origin.x -= Layout.tileOuterInsetX
             inset.size.width += Layout.tileOuterInsetX * 2
+        } else if globalIndex == 1 {
+            // ESC 槽位与主棋盘之间存在系统级分隔，收敛第 1 列左内边距以拉齐首二列间距。
+            inset.origin.x -= Layout.tileOuterInsetX
+            inset.size.width += Layout.tileOuterInsetX
         }
         let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
         let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- ESC 槽位与主棋盘的系统分隔会放大首二列间距；已通过收敛第 1 列左内边距（`globalIndex == 1`）拉齐首二列与其余列的间距表现。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221153857-touchbar-first-second-gap-balance.md` - 修复首二列间距偏大：收敛第 1 列左内边距，拉齐首二列与其余列间距。
@@
+- 需要确认“首二列间距偏大”修复（第 1 列左内边距补偿）时，优先读取 `20260221153857` 文档。
@@
+- ESC 槽位和主棋盘之间存在系统级分隔，当前通过 `globalIndex == 1` 的左内边距补偿来收敛首二列间距。
```

## 测试用例
### TC-001 首二列间距
- 类型：UI 测试
- 步骤：启动应用，观察第 1 与第 2 按钮间距，并与第 2/3、3/4 间距对比。
- 预期：首二列间距明显收敛，与其他列接近。

### TC-002 交互稳定性
- 类型：UI 测试
- 步骤：连续点击第 1、2 列交换，再点击第 2、3 列交换。
- 预期：交互正常，无错位。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
