# 移除大厅左右栏分隔线与标志下方高亮

## 背景与目标

- 会话-100 要求去掉分隔首页左右栏的斜线和标志下方的高亮线。
- 左右栏间的斜线由一条灰线和叠在上半段的青线组成。顶栏底部的青色短线叠在通栏灰线上。

## 代码变更

- 从大厅背景绘制移除两条斜分隔线及其坐标计算。
- 从顶栏绘制移除标志下方的青色短线，顶栏底部采用通栏灰线。

```diff
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 78e86f8a3d335b3ec69f82de03c9bfe3630417e3..c1c4069f87210267ed69083a91ff975855f174fe 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -704,15 +704,6 @@ final class HomeDashboardView: NSView {
         HomeDashboardStyle.backdrop(in: bounds)
         drawNavigation()
 
-        let cyan = HomeDashboardStyle.cyan
-        let dividerY = sectionTop + 12
-        let dividerX = modePanel.frame.minX - 1
-        let artworkRight = max(hero.frame.maxX, guide.frame.maxX) + 8
-        // 分隔线在进入左侧插画之前收尾，避免统一斜角后穿过方块。
-        let dividerHeight = max(0, min(achievementTop - dividerY, (dividerX - artworkRight) / HomeDashboardStyle.slope))
-        let dividerTop = NSPoint(x: dividerX, y: dividerY)
-        HomeDashboardStyle.diagonal(from: dividerTop, height: dividerHeight, color: HomeDashboardStyle.border.withAlphaComponent(0.5))
-        HomeDashboardStyle.diagonal(from: dividerTop, height: dividerHeight / 2, color: cyan.withAlphaComponent(0.22))
         HomeDashboardStyle.line(from: NSPoint(x: contactPanel.frame.minX + 28, y: contactPanel.frame.minY - 24),
                                 to: NSPoint(x: contactPanel.frame.maxX, y: contactPanel.frame.minY - 24),
                                 color: HomeDashboardStyle.border.withAlphaComponent(0.77))
@@ -812,8 +803,6 @@ final class HomeDashboardView: NSView {
         }
         HomeDashboardStyle.line(from: NSPoint(x: 0, y: headerHeight), to: NSPoint(x: bounds.maxX, y: headerHeight),
                                 color: HomeDashboardStyle.border)
-        HomeDashboardStyle.line(from: NSPoint(x: 0, y: headerHeight), to: NSPoint(x: logoX + 57, y: headerHeight),
-                                color: HomeDashboardStyle.cyan, width: 2.5)
     }
 
 }
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 8dc7ed50cd2b7c7fd31b535be45098d7372e2efa..6ad282b8c53e634ae828b152c9456c710c07a03f 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127210415-remove-lobby-division-and-logo-accent.md` - 会话-100 起移除首页分隔左右栏的斜线和标志下方的高亮线。
 `workflow/20261127063642-polish-mode-selection-and-navigation-padding.md` - 会话-95 起移除选中模式卡右侧的对勾，为顶栏三项导航增加左右内边距。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
@@ -111,6 +112,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对首页左右栏分隔线或标志下方高亮时，读取 `20261127210415-remove-lobby-division-and-logo-accent.md`。
 - 需要调整首页选中模式提示、顶栏按钮内边距或不同语言下的导航间距时，读取 `20261127063642-polish-mode-selection-and-navigation-padding.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
```

## 验证

- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全量测试，105 项全部通过。
- 查看测试导出的 1585 × 992 点大厅截图，确认左右栏间无独立分隔线，标志下方仅有顶栏灰色底线，统计卡边框完整。
- 手工复核可运行 `./run.sh` 打开大厅，查看标志正下方及统计卡与游戏模式之间。
