# Touch Bar 单槽位回退：消除首二列跨槽位间距异常

## 背景与目标
- 用户反馈：第一个和第二个按钮之间间距仍明显大于其他按钮。
- 排查结论：该间距异常来自 ESC 槽位与主棋盘槽位的系统分隔。
- 目标：回到“全按钮同槽位”方案，避免跨槽位分隔导致的首二列间距异常。

## 方案
- 采用单一主棋盘槽位承载全部 16 列（`0..<16`），ESC 仅保留 0 宽占位隐藏。
- 移除针对 `globalIndex == 1` 的跨槽位补偿逻辑，避免在单槽位下产生额外左偏。
- 保留首列（`globalIndex == 0`）背景贴边补偿，使最左按钮尽量贴近左边缘。

## 当前进展
- 已完成单槽位回退与首二列间距异常移除。
- 已完成本地构建验证。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 97dd45a..02e7a5e 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -430,10 +430,6 @@ final class GameTouchBarView: NSView {
         if globalIndex == 0 {
             inset.origin.x -= Layout.tileOuterInsetX
             inset.size.width += Layout.tileOuterInsetX * 2
-        } else if globalIndex == 1 {
-            // ESC 槽位与主棋盘之间存在系统级分隔，收敛第 1 列左内边距以拉齐首二列间距。
-            inset.origin.x -= Layout.tileOuterInsetX
-            inset.size.width += Layout.tileOuterInsetX
         }
         let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
         let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- Touch Bar 为消除首二列系统分隔，已回退为单一主棋盘槽位（`0..<16`）+ 0 宽 ESC 占位；首列继续通过背景左补偿贴近最左边缘。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221155545-touchbar-single-slot-remove-first-second-gap.md` - 回退为单槽位 Touch Bar，移除首二列跨槽位分隔导致的间距放大问题。
@@
+- 需要确认“首二列间距仍异常”后的结构性回退（单槽位渲染）时，优先读取 `20260221155545` 文档。
@@
+- Touch Bar 当前已回到单槽位渲染：主棋盘显示 `0..<16`，ESC 仅保留 0 宽占位；这样可避免首二列跨槽位带来的系统分隔间距。
```

## 测试用例
### TC-001 首二列间距一致性
- 类型：UI 测试
- 步骤：启动应用后观察第 1/2 与第 2/3 按钮间距。
- 预期：第 1/2 间距不再显著大于其他列。

### TC-002 最左按钮贴边
- 类型：UI 测试
- 步骤：观察最左按钮左侧与 Touch Bar 边缘距离。
- 预期：最左按钮保持贴近左边缘，无明显新增留白。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
