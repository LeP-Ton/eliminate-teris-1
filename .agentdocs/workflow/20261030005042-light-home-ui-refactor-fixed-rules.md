# 浅色首页 UI 重构与固定模式规则

## 背景与目标
- 对应会话：会话-46 起；执行分支：`experiment/ui-refactor`。
- 参考用户提供的浅色设计图，以原生 AppKit 实现完整首页及可用交互。
- “累计消除”改为当前模式本局的实时统计，不再展示跨局总量。
- 竞分和竞速取消规则档位选择，分别使用原默认值：60 秒与 300 分，满足条件自动结束。
- 基线提交：`198eff532eb046a9048f06d262bd2002cacb46e0`。本轮开始工作区干净，本文记录相对本轮开始快照的全部源码、资源、测试和文档逐行 diff。

## 设计与约束
- 左侧为两行大标题、简短模式文案、四种立体渐变方块和黄色开始按钮；右侧为蓝色选择态模式卡片、本局分类统计。
- 顶部为挑战记录、玩法说明、游戏设置入口；底部展示成就完成度及五枚徽章。
- 继续使用原生 AppKit、系统字体与 SF Symbols；方块用已有 PieceKind 几何数据绘制，无新图片或字体依赖。
- 不删除玩家历史存档、累计计数或已解锁成就；已有 Touch Bar 私有 modal 展示、健康检查、重挂载与诊断方法保持原实现。
- 默认内容区域最高 1180×800 点，按屏幕可用范围收敛；最小内容区域 960×720 点。覆盖五种语言与三种窗口尺寸。

## 阶段与 TODO
- [x] 新建首页、共用浅色绘制/固定规则与顶部辅助面板组件。
- [x] 精简主控制器，保留原 Touch Bar 展示链路，协调模式、开始、结算、设置和成就入口。
- [x] 增加本局类型计数并通过 GameSnapshot 提供，分离本局状态和跨局持久化状态。
- [x] 三种模式统一显式开始/重新开始；开始前及结束后禁止交换。
- [x] 固定竞分 60 秒、竞速 300 分，移除用户可调时间/目标入口。
- [x] 成就与导航辅助面板同步浅色主题。
- [x] 配套成就适配固定规则，同时保留已有解锁与日期。
- [x] 更新五语言资源、中英文 README、根认知与文档索引。
- [x] 完成 45 项自动化回归、真实原生视图渲染及静态比对。
- [ ] Touch Bar 真机触控与模式切换体验验收。

## 数据流与接口
- `GameState.clearedByKind` 为本局累计，按实际消除逐格增加；创建新棋盘自然归零。
- `GameSnapshot.clearedByKind` 和 `totalCleared` 提供只读展示数据。首页不通过分数除以 10 或全局累计值推算统计。
- `HomeGameMode` 定义自由、竞速、竞分以及固定规则常量。其 gameMode 是首页开始和切换使用的唯一规则入口。
- `GameBoardController` 的自由模式也等待 startRound，重开和切换均清零本局；跨局成就累计不受影响。
- `HomeDashboardView` 管理展示与点击回调；`GameViewController` 负责将事件接入控制器、保存结算记录及显示辅助面板。
- 顶部设置只提供语言和总音量；语言切换不会重置本局。记录面板展示固定规则的两组排行，旧档位桶仍保留在存档中。
- 结算记录按每局最多一次保存；结束后本局统计冻结，等待重开。点击已经选中的模式不重置正在进行的游戏。
- 已解锁成就优先出现在首页五枚徽章中；完整图鉴继续支持全部/锁定/已解锁筛选及单项详情。

## 默认规则与兼容取舍
- “默认标准”采用旧界面第一档：竞分 1 分钟，竞速 300 分。
- 用户未对可选成就处理问题另作选择，本轮采用已说明的推荐方案，避免移除档位后产生无法达成的成就：
  - 编号 10/11/12：完成 1 分钟竞分，分别达到 300/600/900 分。
  - 编号 13：完成 300 分竞速；编号 16/14/15：分别在 60/45/30 秒以内完成 300 分。
- 保留原编号、历史解锁和时间；已解锁但新条件缺少对应历史最佳时显示旧版解锁说明。
- 类别、累计类型里程碑及总数 32 均不变。
- 旧版顶部七段数字组件作为备用组件保留，首页实时统计使用设计图中的普通粗体数字。

## 测试用例与结果

### TC-001 本局与跨局统计分离
- 类型：集成测试；优先级：高；模块：GameState/GameBoardController。
- 步骤：开始前尝试交换；开始后制造 30 个橙色消除；重开，再切换模式。
- 预期：开始前不累计，游戏中实时显示橙色 30；新局和切换后本局为 0，但跨局仍为 30。
- 结果：通过。

### TC-002 固定标准自动结束
- 类型：边界测试；优先级：高。
- 步骤：竞分推进到 59.9 秒和 60 秒；竞速执行达到 300 分的交换，再尝试交换。
- 预期：竞分仅在 60 秒结束，竞速达到 300 分结束；结算后计数不继续变化。
- 结果：通过。

### TC-003 首页真实点击与记录去重
- 类型：原生控制器集成；优先级：高。
- 步骤：点击开始；交换后检查统计；点击已选模式；切到竞速并开始、完成；重复 tick；再切竞分。
- 预期：已选模式不重置统计，切换清零；竞速目标固定 300、竞分固定 60 秒，无档位菜单；结算记录只保存一次。
- 结果：通过。

### TC-004 三模式、五语言、三尺寸
- 类型：原生布局/视觉测试；优先级：高。
- 步骤：遍历自由/竞速/竞分，遍历现有五种语言，在 960×720、1180×800、1440×940 内容尺寸下布局。
- 预期：按钮位于内容区域内，点击高度足够，本局类型计数总和正确；三种模式中文截图符合参考布局。
- 结果：通过，并实际查看首页 PNG。

### TC-005 顶部导航与设置
- 类型：原生界面测试；优先级：高。
- 步骤：构建设置、玩法说明和记录面板；检查控件与非模态焦点；调整音量滑杆并触发原生 action，渲染各面板。
- 预期：设置只有一个语言菜单和总音量，滑杆回调正确；不存在目标/时限选择，规则/记录可读并可滚动；辅助面板不抢主窗口键盘焦点。
- 结果：通过，已查看设置/记录预览。

### TC-006 既有功能回归
- 类型：完整回归；优先级：高。
- 覆盖：交换/连消、成就去重与迁移、类型里程碑、五语言格式参数、成就筛选与窗口定位。
- 结果：通过；Touch Bar 展示、诊断与生命周期方法相对基线逐字比对一致，模式切换保留原刷新入口。

## 当前验证与限制
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：45 项测试，0 失败，最终构建与链接正常。
- `git diff --check`：通过。
- 原生预览：临时目录中的 `eliminate-home-free.png`、`eliminate-home-speed_run.png`、`eliminate-home-score_attack.png`，以及 settings/rules/records 辅助面板预览；数据来自隔离测试存档。
- 测试不读取或修改玩家真实记录；未重启用户当前游戏进程。
- 真机 Touch Bar 触控和音效尚未进行实际体验验收，可通过 `./run.sh` 在当前探索分支运行。

## 代码变更

以下为本轮全部代码、资源、测试、核心认知和说明文档的完整逐行 diff，没有省略变更代码行。

### `AGENTS.md`

```diff
diff --git a/AGENTS.md b/AGENTS.md
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -4,6 +4,12 @@
 - 项目为 macOS 12+ 原生 AppKit/Cocoa 游戏，使用 Swift 5.7+ 与 Swift Package Manager；桌面窗口负责设置和信息展示，16 格 Touch Bar 承载核心操作。
 - 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
 - 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
+
+## 2026-10-30（experiment/ui-refactor 探索分支）
+- 桌面首页由 `HomeDashboardView` 负责展示，`GameViewController` 负责事件协调、记录结算与既有 Touch Bar 展示生命周期；共用规则和浅色绘制位于 `GamePresentation`。
+- 本局数据由 `GameState` 持有并通过 `GameSnapshot` 提供，成就累计由 `AchievementsManager` 单独持久化；两种生命周期互不混用。
+- 三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，首页不再提供档位设置。旧挑战记录保留，成就按固定规则兼容升级并保留已解锁状态。
+- 首页及辅助面板在探索分支使用暖白、蓝色选择态与黄色主操作的浅色主题，替代旧版桌面像素背景；Touch Bar 棋盘绘制链路沿用既有实现。
 
 ## 2026-10-29
 - 消除结算事件包含按 `PieceKind` 稳定标识分类的明细，先记录被消除的实际类型再补位；顶部统计与类型成就共用同一累计存档数据源，按类型统计不依赖分数或界面动画反推。
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261030005042-light-home-ui-refactor-fixed-rules.md` - 会话-46 起在 experiment/ui-refactor 分支按参考图重构浅色首页；本局实时统计、固定竞分 60 秒/竞速 300 分、顶部辅助面板及成就兼容；含全部逐行 diff、45 项回归与原生渲染验收。
 `workflow/20261029224856-seven-segment-counts-and-bounce.md` - 会话-38 起将累计消除改为统一卡片标题，数量使用等高七段数码管、同步浮动与增长跳动；含完整增量 diff、真实渲染验收和 9 项界面回归结果。
 `workflow/20261029222742-piece-clear-counts-and-milestones.md` - 会话-33 起新增顶部四种方块累计消除数量及每类百/千/万三档里程碑，共新增 12 枚成就、总数 32；含完整逐行 diff、存档兼容说明和 38 项回归结果。
 `workflow/20261027231516-achievement-panel-game-theme.md` - 会话-26 起统一成就面板与主界面的深色像素主题：复用背景/卡片绘制，统一筛选、字体和像素进度条；含完整逐行 diff、真实渲染验收及 6 项界面回归结果。
@@ -65,6 +66,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要了解探索分支浅色首页、本局统计与跨局成就分离、固定结束条件、开始按钮或顶部导航时，读取 `20261030005042-light-home-ui-refactor-fixed-rules.md`。
 - 需要调整顶部统计卡片标题、七段数字绘制、数字与方块同步浮动或消除增长跳动时，读取 `20261029224856-seven-segment-counts-and-bounce.md`。
 - 需要了解按方块类型计数、顶部数量显示、每类 100/1,000/10,000 成就及旧存档升级口径时，读取 `20261029222742-piece-clear-counts-and-milestones.md`。
 - 需要调整成就图鉴/详情的深色主题、像素边框、字体、筛选控件、分段进度条或了解共用绘制组件时，读取 `20261027231516-achievement-panel-game-theme.md`。
@@ -130,6 +132,9 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
+- 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
+- 探索分支三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
 - 顶部统计卡片使用统一“累计消除”标题，七段数字按方块高度绘制，长数量只横向压缩；图案和数字共用浮动位置，只有数量增长时数字额外跳动，首次加载/同值刷新不触发。
 - 成就现为 32 枚，新增编号 21—32 对应橙/蓝/绿/红四类方块的百/千/万累计里程碑；原编号 1—20 保持不变。
 - 类型累计值跨局、跨模式及重启保存；旧存档没有类型明细时从 0 开始，保留既有总数和解锁状态，不推测历史分布。顶部横幅与类型成就读取同一数据源。
```

### `README.md`

```diff
diff --git a/README.md b/README.md
--- a/README.md
+++ b/README.md
@@ -8,6 +8,8 @@
 ![Status](https://img.shields.io/badge/Status-Playable-2ea043)
 
 把消除游戏搬进 MacBook Touch Bar 的一次认真尝试。
+
+> 当前为 `experiment/ui-refactor` 探索分支：桌面窗口采用浅色首页、模式卡片与本局实时统计；竞分固定 60 秒，竞速固定 300 分，全部模式点击“开始游戏”后开始。
 
 `Eliminate Teris 1` 是一款为 macOS 与 Touch Bar 场景设计的轻量消除游戏：战场不在大屏幕中央，而是在键盘上方那条熟悉又常被忽视的细长区域里。你会在 16 格的一维棋盘上交换相邻方块、制造三连消除、追逐更高分数，也会在竞速与限时模式里，把每一次操作都压缩成更紧凑、更直接的节奏。
 
@@ -57,12 +59,12 @@
 
 ### 3. 三种模式，照顾练手、冲分与竞速
 - **自由模式**：没有时间限制，也没有目标分数，适合熟悉规则、放松手感。
-- **竞分模式**：在限定时间内尽可能拿高分，当前支持 `1 / 2 / 3` 分钟三个档位。
-- **竞速模式**：以最短时间冲到目标分数，当前支持 `300 / 600 / 900` 分三个目标。
+- **竞分模式**：在限定时间内尽可能拿高分，固定为 `60` 秒，到时自动结算。
+- **竞速模式**：以最短时间冲到目标分数，固定为 `300` 分，达标自动结算。
 
 ### 4. 本地挑战记录，记住每一次更强的自己
-- 游戏会按模式与细分规则分别保存挑战记录。
-- 例如“竞分 1 分钟”和“竞分 3 分钟”会分开排行；“竞速 300 分”和“竞速 900 分”也各自独立。
+- 游戏按竞分、竞速的固定规则分别保存挑战记录。
+- 当前显示“竞分 60 秒”和“竞速 300 分”两组排行；旧版其他档位的存档仍保留。
 - 每个记录桶最多保留 `9` 条成绩，方便持续追分、反复刷新个人最佳。
 
 ### 5. 有节奏感的视听反馈
@@ -98,16 +100,16 @@
 这是最直接的“冲高分”玩法。你要在有限时间里尽量制造更多有效交换，让分数尽快抬升。它更考验稳定输出、连续判断和临场节奏。
 
 ### 竞速模式
-竞速模式把目标改成“尽快到达指定分数”。当目标是 `300` 分、`600` 分或 `900` 分时，你需要的不只是正确操作，还包括尽可能少的犹豫与停顿。它更像是一场短跑。
+竞速模式把目标固定为“尽快到达 300 分”。你需要的不只是正确操作，还包括尽可能少的犹豫与停顿；达到目标后立即结算。
 
 ## 游戏界面说明
 
-除了 Touch Bar 主棋盘外，桌面窗口还提供了完整的辅助信息区域：
-
-- **游戏设置**：切换模式、规则档位、语言，并开始或重新开始一局。
-- **时间与得分**：显示当前用时、剩余时间（如适用）与得分变化。
-- **挑战记录**：按当前模式与细分规则展示本地最佳记录。
-- **玩法说明**：根据当前模式展示对应规则，帮助玩家快速理解本局目标。
+桌面窗口按“左侧介绍与开始按钮、右侧模式与实时统计、底部成就”的结构展示：
+
+- **游戏模式**：直接选择自由、竞速、竞分，点击开始或重新开始；不提供时间和目标档位设置。
+- **累计消除**：显示当前本局的总数量及四种类型明细，重开或切换模式清零；跨局成就进度独立保留。
+- **顶部导航**：挑战记录、玩法说明、游戏设置在独立辅助面板中打开；设置只提供语言和总音量。
+- **成就之路**：显示解锁数量、完成比例和五枚徽章，支持查看全部及单项详情。
 
 也就是说，这个项目不是“只有一条 Touch Bar 在工作”，而是把窗口信息面板和 Touch Bar 主战场组合成了一套完整的游玩体验。
 
@@ -187,7 +189,10 @@
 
 - `Sources/GameTouchBarView.swift`：Touch Bar 棋盘渲染、触控交互、动画表现
 - `Sources/GameState.swift`：棋盘状态、匹配判定、消除与左侧补位逻辑
-- `Sources/GameViewController.swift`：桌面窗口 UI、模式切换、状态展示
+- `Sources/GameViewController.swift`：事件协调、模式切换、结算记录和 Touch Bar 生命周期
+- `Sources/HomeDashboardView.swift`：浅色首页与本局统计
+- `Sources/GamePresentation.swift`：固定规则与共用绘制样式
+- `Sources/HomeUtilityPanel.swift`：顶部导航辅助面板
 - `Sources/ModeRecordStore.swift`：本地挑战记录的分桶保存与排序
 - `Sources/GameAudioSystem.swift`：程序化 BGM 与交互音效
 - `Sources/Localization.swift`：多语言资源查找与切换
```

### `README.en.md`

```diff
diff --git a/README.en.md b/README.en.md
--- a/README.en.md
+++ b/README.en.md
@@ -57,12 +57,12 @@
 
 ### 3. Three modes for practice, score chasing, and speed
 - **Free Mode**: no time limit and no target score; ideal for learning the rules and getting comfortable with the controls.
-- **Score Attack**: score as high as possible within a limited time; currently supports `1 / 2 / 3` minute presets.
-- **Speed Run**: reach a target score as quickly as possible; currently supports `300 / 600 / 900` point targets.
+- **Score Attack**: score as high as possible within a limited time; uses a fixed `60` second round and ends automatically.
+- **Speed Run**: reach a target score as quickly as possible; uses a fixed `300` point target and ends automatically.
 
 ### 4. Local challenge records
 - Records are stored locally by mode and by sub-rule.
-- For example, “Score Attack - 1 minute” and “Score Attack - 3 minutes” are ranked separately, and so are “Speed Run - 300” and “Speed Run - 900”.
+- The current interface shows 60-second Score Attack and 300-point Speed Run rankings. Other historical buckets remain in local storage.
 - Each record bucket keeps up to `9` entries so you can keep pushing your best results.
 
 ### 5. Audio feedback with a clear rhythm
@@ -98,16 +98,16 @@
 This is the most straightforward mode for chasing high scores. You need to create as many efficient swaps as possible within limited time. It rewards consistency, quick decisions, and control under pressure.
 
 ### Speed Run
-In this mode, the goal is simple: hit the target score as fast as possible. Whether the target is `300`, `600`, or `900`, success depends not only on making correct moves, but also on minimizing hesitation.
+Reach the fixed target of `300` points as quickly as possible. The round ends automatically when the target is reached.
 
 ## Interface Overview
 
-Besides the Touch Bar board itself, the desktop window provides several supporting panels:
-
-- **Game Settings**: switch mode, sub-rules, language, and start or restart a run.
-- **Time & Score**: shows elapsed time, remaining time when applicable, and score updates.
-- **Challenge Records**: shows local best results for the current mode and current rule bucket.
-- **Mode Briefing**: explains the rules for the currently selected mode.
+This `experiment/ui-refactor` branch uses a light desktop dashboard with a hero area, mode cards, live round statistics, and an achievement strip.
+
+- **Game Modes**: choose Free Play, Speed Run, or Score Attack, then start or restart. Time and target settings are fixed.
+- **Cleared Tiles**: live totals and four tile-type counts for this round. Restarting or switching modes clears them; lifetime achievement progress remains saved.
+- **Navigation**: records, rules, and settings open separate panels. Settings contain language and master volume.
+- **Achievements**: completion progress, five badges, and access to the full collection.
 
 In other words, this is not just “a Touch Bar strip doing something.” It is a complete play experience made of a Touch Bar battlefield and a desktop information panel.
 
@@ -187,7 +187,10 @@
 
 - `Sources/GameTouchBarView.swift`: Touch Bar board rendering, interaction, and animation
 - `Sources/GameState.swift`: board state, match detection, clearing, and left-side refill logic
-- `Sources/GameViewController.swift`: desktop UI, mode switching, and status presentation
+- `Sources/GameViewController.swift`: event coordination, fixed mode selection, result recording, and Touch Bar lifecycle
+- `Sources/HomeDashboardView.swift`: light dashboard and live round statistics
+- `Sources/GamePresentation.swift`: fixed rules and shared rendering style
+- `Sources/HomeUtilityPanel.swift`: navigation panels
 - `Sources/ModeRecordStore.swift`: local challenge record storage and ranking
 - `Sources/GameAudioSystem.swift`: procedural BGM and sound effects
 - `Sources/Localization.swift`: language switching and resource bundle lookup
```

### `Sources/GameTouchBarView.swift`

```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -14,6 +14,9 @@
     let targetScore: Int?
     let isRunning: Bool
     let isFinished: Bool
+    var clearedByKind: [PieceKind: Int] = [:]
+
+    var totalCleared: Int { clearedByKind.values.reduce(0, +) }
 }
 
 final class GameBoardController {
@@ -31,7 +34,7 @@
     private var mode: GameMode = .free
     private var roundStartDate = Date()
     private var stoppedElapsedTime: TimeInterval = 0
-    private var isRunningRound = true
+    private var isRunningRound = false
     private var isFinished = false
     private var lastSwapPair: (Int, Int)?
 
@@ -59,14 +62,12 @@
         self.mode = mode
         resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
-        isRunningRound = isFreeMode
+        isRunningRound = false
         isFinished = false
         notifyChange()
     }
 
     func startRound() {
-        guard !isFreeMode else { return }
-
         resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
         isRunningRound = true
@@ -101,8 +102,9 @@
                 elapsedTime: elapsed,
                 remainingTime: nil,
                 targetScore: nil,
-                isRunning: true,
-                isFinished: isFinished
+                isRunning: isRunningRound,
+                isFinished: isFinished,
+                clearedByKind: state.clearedByKind
             )
 
         case .scoreAttack(let duration):
@@ -120,7 +122,8 @@
                 remainingTime: remaining,
                 targetScore: nil,
                 isRunning: isRunningRound,
-                isFinished: isFinished
+                isFinished: isFinished,
+                clearedByKind: state.clearedByKind
             )
 
         case .speedRun(let targetScore):
@@ -131,7 +134,8 @@
                 remainingTime: nil,
                 targetScore: targetScore,
                 isRunning: isRunningRound,
-                isFinished: isFinished
+                isFinished: isFinished,
+                clearedByKind: state.clearedByKind
             )
         }
     }
@@ -243,7 +247,7 @@
     private func canInteract() -> Bool {
         _ = updateFinishedState(now: currentDate())
         if isFreeMode {
-            return !isFinished
+            return isRunningRound && !isFinished
         }
         return isRunningRound && !isFinished
     }
```

### `Sources/AchievementsManager.swift`

```diff
diff --git a/Sources/AchievementsManager.swift b/Sources/AchievementsManager.swift
--- a/Sources/AchievementsManager.swift
+++ b/Sources/AchievementsManager.swift
@@ -33,11 +33,11 @@
         .init(id: 8, category: .skill, goal: .cascades(3)),
         .init(id: 9, category: .skill, goal: .successfulSwaps(5)),
         .init(id: 10, category: .mode, goal: .scoreAttack(minutes: 1, score: 300)),
-        .init(id: 11, category: .mode, goal: .scoreAttack(minutes: 2, score: 600)),
-        .init(id: 12, category: .mode, goal: .scoreAttack(minutes: 3, score: 900)),
+        .init(id: 11, category: .mode, goal: .scoreAttack(minutes: 1, score: 600)),
+        .init(id: 12, category: .mode, goal: .scoreAttack(minutes: 1, score: 900)),
         .init(id: 13, category: .mode, goal: .speedRun(target: 300, limit: nil)),
-        .init(id: 14, category: .mode, goal: .speedRun(target: 600, limit: nil)),
-        .init(id: 15, category: .mode, goal: .speedRun(target: 900, limit: nil)),
+        .init(id: 14, category: .mode, goal: .speedRun(target: 300, limit: 45)),
+        .init(id: 15, category: .mode, goal: .speedRun(target: 300, limit: 30)),
         .init(id: 16, category: .mode, goal: .speedRun(target: 300, limit: 60)),
         .init(id: 17, category: .lifetime, goal: .totalCleared(100)),
         .init(id: 18, category: .lifetime, goal: .totalCleared(1_000)),
```

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -2,58 +2,29 @@
 import ObjectiveC.runtime
 
 final class GameViewController: NSViewController, NSTouchBarDelegate {
-    private enum ModeSelection: Int {
-        case free = 0
-        case scoreAttack = 1
-        case speedRun = 2
-    }
-
-    private enum ControlRow: Int {
-        case language = 0
-        case mode = 1
-        case option = 2
-        case volume = 3
-        case action = 4
-    }
-
-    private enum BadgeTone {
-        case ready
-        case running
-        case combo
-        case finish
-    }
-
-    private struct RecordPanelContext {
-        let modeKey: ModeRecordKey
-        let detailValue: Int
-
-        var scopeID: String {
-            return ModeRecordStore.scopeID(mode: modeKey, detailValue: detailValue)
-        }
-    }
-
+    private let columns = 16
     private let localizer = Localizer.shared
-    private let settingsThemeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
-    private let statusThemeColor = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
-    private let recordsThemeColor = NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.58, alpha: 0.96)
-    private let rulesThemeColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
-    private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
-
-    private let columns = 16
-    private let contentFixedWidth: CGFloat = 672
-    private let scoreAttackMinutes = [1, 2, 3]
-    private let speedRunTargets = [300, 600, 900]
-    private let recordStore = ModeRecordStore.shared
+    private let recordStore: ModeRecordStore
+    private let achievements: AchievementsManager
+    private let audioEnabled: Bool
+    private let controller: GameBoardController
+    private var selection: HomeGameMode = .free
+    private var hasConfiguredMode = false
+    private var hasSavedFinishedRecord = false
     private let audioSystem = GameAudioSystem.shared
+    private var observerToken: UUID?
+    private var achievementsChangeObserver: NSObjectProtocol?
+    private var achievementsUnlockObserver: NSObjectProtocol?
+    private var achievementsPanel: AchievementsWindowController?
+    private var utilityPanels: [String: HomeUtilityPanel] = [:]
+    private var achievementToasts: AchievementToastPresenter?
+    private var hudTimer: Timer?
+    private lazy var dashboard = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
     private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
     private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
     private let touchBarHealthCheckDelay: TimeInterval = 0.18
     private let touchBarMaxReattachAttempts = 3
-
-    private lazy var controller = GameBoardController(columns: columns)
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
-
-    private var observerToken: UUID?
     private var isPresentingSystemModalTouchBar = false
     private var touchBarPresentationGeneration = 0
     private var touchBarInitialRefreshWorkItem: DispatchWorkItem?
@@ -65,426 +36,14 @@
     private var windowDidBecomeKeyObserver: NSObjectProtocol?
     private var windowDidResignKeyObserver: NSObjectProtocol?
     private weak var observedTouchBarWindow: NSWindow?
-    private var hudTimer: Timer?
-    private var selectedScoreAttackIndex = 0
-    private var selectedSpeedRunIndex = 0
-    private var comboStreak = 0
-    private var lastObservedScore = 0
-    private var lastScoreGainDate: Date?
-    private var hasSavedFinishedRecord = false
-    private var latestRecordIDByMode: [String: String] = [:]
-    private var lastRecordsLayoutWidth: CGFloat = 0
-    private var achievementsUnlockObserver: NSObjectProtocol?
-    private var achievementsChangeObserver: NSObjectProtocol?
-    private var achievementsPanel: AchievementsWindowController?
-    private var achievementToasts: AchievementToastPresenter?
-    private var settingsExpandedWidthConstraint: NSLayoutConstraint?
-    private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
-    private var rightColumnMinWidthConstraint: NSLayoutConstraint?
-
-    private lazy var headerIconView: NSImageView = {
-        let imageView = NSImageView()
-        imageView.translatesAutoresizingMaskIntoConstraints = false
-        imageView.contentTintColor = NSColor.systemYellow
-        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .heavy)
-        imageView.imageScaling = .scaleProportionallyDown
-        return imageView
-    }()
-
-    private lazy var titleLabel: NSTextField = {
-        let label = NSTextField(labelWithString: "")
-        label.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .heavy)
-        label.textColor = NSColor.white
-        label.alignment = .left
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var subtitleLabel: NSTextField = {
-        let label = NSTextField(labelWithString: "")
-        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
-        label.textColor = NSColor.white.withAlphaComponent(0.72)
-        label.alignment = .left
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var headerTextStack: NSStackView = {
-        let stack = NSStackView(views: [titleLabel, subtitleLabel])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 2
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var headerStack: NSStackView = {
-        let stack = NSStackView(views: [headerIconView, headerTextStack])
-        stack.orientation = .horizontal
-        stack.alignment = .centerY
-        stack.spacing = 12
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var pixelBannerView: PixelBannerView = {
-        let banner = PixelBannerView(frame: .zero)
-        banner.translatesAutoresizingMaskIntoConstraints = false
-        return banner
-    }()
-
-    private lazy var settingsTitleLabel: NSTextField = {
-        return makeSectionTitleLabel(color: settingsThemeColor)
-    }()
-
-    private lazy var settingsTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "slider.horizontal.3", color: settingsThemeColor)
-    }()
-
-    private lazy var settingsHeaderStack: NSStackView = {
-        return makeSectionHeaderStack(iconView: settingsTitleIconView, titleLabel: settingsTitleLabel)
-    }()
-
-    private lazy var statusTitleLabel: NSTextField = {
-        return makeSectionTitleLabel(color: statusThemeColor)
-    }()
-
-    private lazy var statusTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "timer", color: statusThemeColor)
-    }()
-
-    private lazy var statusHeaderStack: NSStackView = {
-        return makeSectionHeaderStack(iconView: statusTitleIconView, titleLabel: statusTitleLabel)
-    }()
-
-    private lazy var statusBadgeLabel: NSTextField = {
-        let label = NSTextField(labelWithString: "")
-        label.alignment = .center
-        label.textColor = NSColor.white
-        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
-        label.wantsLayer = true
-        label.layer?.cornerRadius = 5
-        label.layer?.masksToBounds = true
-        label.isHidden = true
-        label.setContentHuggingPriority(.required, for: .horizontal)
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var languageTitleLabel: NSTextField = {
-        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
-    }()
-
-    private lazy var languagePopup: ArcadePopupButton = {
-        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
-        popup.target = self
-        popup.action = #selector(languageSelectionChanged(_:))
-        popup.translatesAutoresizingMaskIntoConstraints = false
-        return popup
-    }()
-
-    private lazy var modeTitleLabel: NSTextField = {
-        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
-    }()
-
-    private lazy var modePopup: ArcadePopupButton = {
-        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
-        popup.target = self
-        popup.action = #selector(modeSelectionChanged(_:))
-        popup.translatesAutoresizingMaskIntoConstraints = false
-        return popup
-    }()
-
-    private lazy var optionTitleLabel: NSTextField = {
-        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
-    }()
-
-    private lazy var optionPopup: ArcadePopupButton = {
-        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
-        popup.target = self
-        popup.action = #selector(optionSelectionChanged(_:))
-        popup.translatesAutoresizingMaskIntoConstraints = false
-        return popup
-    }()
-
-    private lazy var startTitleLabel: NSTextField = {
-        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
-    }()
-
-    private lazy var volumeTitleLabel: NSTextField = {
-        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
-    }()
-
-    private lazy var volumeControlView: ArcadeVolumeControlView = {
-        let view = ArcadeVolumeControlView(themeColor: settingsThemeColor)
-        view.slider.target = self
-        view.slider.action = #selector(volumeSliderChanged(_:))
-        view.translatesAutoresizingMaskIntoConstraints = false
-        return view
-    }()
-
-    private lazy var startButton: ArcadeActionButton = {
-        let button = ArcadeActionButton(title: "", target: self, action: #selector(startButtonTapped(_:)))
-        button.imagePosition = .imageLeading
-        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
-        button.translatesAutoresizingMaskIntoConstraints = false
-        return button
-    }()
-
-    private lazy var controlsGrid: NSGridView = {
-        let grid = NSGridView(views: [
-            [languageTitleLabel, languagePopup],
-            [modeTitleLabel, modePopup],
-            [optionTitleLabel, optionPopup],
-            [volumeTitleLabel, volumeControlView],
-            [startTitleLabel, startButton]
-        ])
-        grid.translatesAutoresizingMaskIntoConstraints = false
-        grid.rowSpacing = 12
-        grid.columnSpacing = 12
-        grid.column(at: 0).xPlacement = .trailing
-        grid.column(at: 1).xPlacement = .leading
-        for rowIndex in 0..<grid.numberOfRows {
-            grid.row(at: rowIndex).yPlacement = .center
-        }
-        return grid
-    }()
-
-    private lazy var competitiveInfoLabel: NSTextField = {
-        let label = NSTextField(wrappingLabelWithString: "")
-        label.alignment = .left
-        label.textColor = NSColor.systemGreen
-        label.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .heavy)
-        label.maximumNumberOfLines = 2
-        if let cell = label.cell as? NSTextFieldCell {
-            cell.lineBreakMode = .byWordWrapping
-        }
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var resultLabel: NSTextField = {
-        let label = NSTextField(wrappingLabelWithString: "")
-        label.alignment = .left
-        label.textColor = statusThemeColor.withAlphaComponent(0.86)
-        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
-        label.maximumNumberOfLines = 0
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var rulesTitleLabel: NSTextField = {
-        return makeSectionTitleLabel(color: NSColor.white)
-    }()
-
-    private lazy var rulesTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "doc.text", color: NSColor.white)
-    }()
-
-    private lazy var rulesHeaderStack: NSStackView = {
-        return makeSectionHeaderStack(iconView: rulesTitleIconView, titleLabel: rulesTitleLabel)
-    }()
-
-    private lazy var rulesBodyLabel: NSTextField = {
-        let label = NSTextField(wrappingLabelWithString: "")
-        label.alignment = .left
-        label.textColor = NSColor.white
-        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
-        label.maximumNumberOfLines = 0
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }()
-
-    private lazy var settingsCardView: PixelFrameCardView = {
-        return PixelFrameCardView(accentColor: NSColor.systemBlue)
-    }()
-
-    private lazy var statusCardView: PixelFrameCardView = {
-        return PixelFrameCardView(accentColor: NSColor.systemGreen)
-    }()
-
-    private lazy var settingsCardStack: NSStackView = {
-        let stack = NSStackView(views: [settingsHeaderStack, controlsGrid])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 12
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var statusCardStack: NSStackView = {
-        let stack = NSStackView(views: [statusHeaderStack, statusBadgeLabel, competitiveInfoLabel, resultLabel])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 8
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var rightColumnStack: NSStackView = {
-        let stack = NSStackView(views: [statusCardView, recordsCardView])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.distribution = .fill
-        stack.spacing = 12
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var cardsStack: NSStackView = {
-        let stack = NSStackView(views: [settingsCardView, rightColumnStack])
-        stack.orientation = .horizontal
-        stack.alignment = .top
-        stack.distribution = .fill
-        stack.spacing = 14
-        stack.detachesHiddenViews = true
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var recordsTitleLabel: NSTextField = {
-        return makeSectionTitleLabel(color: recordsThemeColor)
-    }()
-
-    private lazy var recordsTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "list.number", color: recordsThemeColor)
-    }()
-
-    private lazy var recordsHeaderStack: NSStackView = {
-        let stack = NSStackView(views: [recordsTitleIconView, recordsTitleLabel])
-        stack.orientation = .horizontal
-        stack.alignment = .centerY
-        stack.spacing = 6
-        stack.detachesHiddenViews = true
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var recordsTextView: NSTextView = {
-        let textView = NSTextView(frame: .zero)
-        textView.isEditable = false
-        textView.isSelectable = false
-        textView.drawsBackground = false
-        textView.isRichText = false
-        textView.importsGraphics = false
-        textView.textContainerInset = NSSize(width: 2, height: 2)
-        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
-        textView.textColor = recordsThemeColor.withAlphaComponent(0.88)
-        textView.string = ""
-        textView.minSize = NSSize(width: 0, height: 0)
-        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
-        textView.isVerticallyResizable = true
-        textView.isHorizontallyResizable = false
-        textView.autoresizingMask = [.width]
-        textView.textContainer?.widthTracksTextView = true
-        textView.textContainer?.heightTracksTextView = false
-        textView.textContainer?.lineFragmentPadding = 0
-        return textView
-    }()
-
-    private lazy var recordsScrollView: NSScrollView = {
-        let scrollView = NSScrollView()
-        scrollView.translatesAutoresizingMaskIntoConstraints = false
-        scrollView.drawsBackground = false
-        scrollView.hasVerticalScroller = true
-        scrollView.hasHorizontalScroller = false
-        scrollView.autohidesScrollers = true
-        scrollView.borderType = .noBorder
-        scrollView.documentView = recordsTextView
-        return scrollView
-    }()
-
-    private lazy var recordsCardView: PixelFrameCardView = {
-        let view = PixelFrameCardView(accentColor: NSColor.systemOrange)
-        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
-        view.isHidden = true
-        return view
-    }()
-
-    private lazy var recordsCardStack: NSStackView = {
-        let stack = NSStackView(views: [recordsHeaderStack, recordsScrollView])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 8
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    // 玩法说明改为无强调边框卡片，使用默认白色文字
-    private lazy var rulesCardView: NSView = {
-        let view = NSView()
-        view.wantsLayer = true
-        view.layer?.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.17, alpha: 0.93).cgColor
-        view.layer?.cornerRadius = 10
-        return view
-    }()
-
-    // 成就模块：使用原本玩法说明的红色边框卡片样式
-    private lazy var achievementsTitleLabel: NSTextField = {
-        return makeSectionTitleLabel(color: rulesThemeColor)
-    }()
-
-    private lazy var achievementsTitleIconView: NSImageView = {
-        return makeSectionIconView(symbolName: "rosette", color: rulesThemeColor)
-    }()
-
-    private lazy var achievementsAllButton: NSButton = {
-        let button = NSButton(title: "", target: self, action: #selector(showAllAchievements))
-        button.bezelStyle = .inline
-        button.contentTintColor = rulesThemeColor
-        return button
-    }()
-
-    private lazy var achievementsHeaderStack: NSStackView = {
-        let stack = makeSectionHeaderStack(iconView: achievementsTitleIconView, titleLabel: achievementsTitleLabel)
-        stack.addArrangedSubview(NSView())
-        stack.addArrangedSubview(achievementsAllButton)
-        return stack
-    }()
-
-    private lazy var achievementsScrollView: AchievementBadgeStripView = {
-        let strip = AchievementBadgeStripView()
-        strip.onSelect = { [weak self] id in self?.presentAchievements(detailID: id) }
-        return strip
-    }()
-
-    private lazy var achievementsCardView: PixelFrameCardView = {
-        return PixelFrameCardView(accentColor: NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.3, alpha: 1.0))
-    }()
-
-    private lazy var achievementsCardStack: NSStackView = {
-        let stack = NSStackView(views: [achievementsHeaderStack, achievementsScrollView])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 10
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var rulesCardStack: NSStackView = {
-        let stack = NSStackView(views: [rulesHeaderStack, rulesBodyLabel])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 10
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var dividerView: PixelDividerView = {
-        let view = PixelDividerView(frame: .zero)
-        view.translatesAutoresizingMaskIntoConstraints = false
-        return view
-    }()
-
-    private lazy var contentStack: NSStackView = {
-        // Put achievements above rules by default
-        let stack = NSStackView(views: [headerStack, dividerView, pixelBannerView, cardsStack, achievementsCardView, rulesCardView])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 14
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
+
+    init(achievements: AchievementsManager = .shared, records: ModeRecordStore = .shared,
+         board: GameBoardController? = nil, audioEnabled: Bool = true) {
+        self.achievements = achievements; self.recordStore = records; self.audioEnabled = audioEnabled
+        self.controller = board ?? GameBoardController(columns: 16, achievements: achievements)
+        super.init(nibName: nil, bundle: nil)
+    }
+    required init?(coder: NSCoder) { nil }
 
     private lazy var gameTouchBar: NSTouchBar = {
         let bar = NSTouchBar()
@@ -497,219 +56,112 @@
         return bar
     }()
 
-    override func loadView() {
-        let view = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
-        self.view = view
-
-        view.addSubview(contentStack)
-        settingsCardView.addSubview(settingsCardStack)
-        statusCardView.addSubview(statusCardStack)
-        recordsCardView.addSubview(recordsCardStack)
-        rulesCardView.addSubview(rulesCardStack)
-        achievementsCardView.addSubview(achievementsCardStack)
-
-        let settingsVersusRightColumnConstraint = settingsCardView.widthAnchor.constraint(
-            greaterThanOrEqualTo: rightColumnStack.widthAnchor,
-            multiplier: 1.24
-        )
-        let rightColumnMinWidthConstraint = rightColumnStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
-        let settingsExpandedWidthConstraint = settingsCardView.widthAnchor.constraint(equalTo: cardsStack.widthAnchor)
-        settingsExpandedWidthConstraint.isActive = false
-
-        self.settingsVersusRightColumnConstraint = settingsVersusRightColumnConstraint
-        self.rightColumnMinWidthConstraint = rightColumnMinWidthConstraint
-        self.settingsExpandedWidthConstraint = settingsExpandedWidthConstraint
-
-        NSLayoutConstraint.activate([
-            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
-            // 固定主内容宽度并整体水平居中，竖直方向顶部对齐
-            contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
-            contentStack.widthAnchor.constraint(equalToConstant: contentFixedWidth),
-            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
-
-            headerIconView.widthAnchor.constraint(equalToConstant: 34),
-            headerIconView.heightAnchor.constraint(equalToConstant: 34),
-            // 确保标题宽度与主内容宽度一致，从而标题和卡片左对齐
-            headerStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-
-            dividerView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-            dividerView.heightAnchor.constraint(equalToConstant: 10),
-
-            pixelBannerView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-            pixelBannerView.heightAnchor.constraint(equalToConstant: 88),
-
-            cardsStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-            settingsCardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 390),
-            settingsVersusRightColumnConstraint,
-            rightColumnMinWidthConstraint,
-            rightColumnStack.heightAnchor.constraint(lessThanOrEqualTo: settingsCardView.heightAnchor),
-            statusCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),
-            recordsCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),
-
-            settingsCardStack.topAnchor.constraint(equalTo: settingsCardView.topAnchor, constant: 14),
-            settingsCardStack.leadingAnchor.constraint(equalTo: settingsCardView.leadingAnchor, constant: 14),
-            settingsCardStack.trailingAnchor.constraint(equalTo: settingsCardView.trailingAnchor, constant: -14),
-            settingsCardStack.bottomAnchor.constraint(equalTo: settingsCardView.bottomAnchor, constant: -14),
-
-            statusCardStack.topAnchor.constraint(equalTo: statusCardView.topAnchor, constant: 14),
-            statusCardStack.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 14),
-            statusCardStack.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -14),
-            statusCardStack.bottomAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: -14),
-
-            recordsCardStack.topAnchor.constraint(equalTo: recordsCardView.topAnchor, constant: 14),
-            recordsCardStack.leadingAnchor.constraint(equalTo: recordsCardView.leadingAnchor, constant: 14),
-            recordsCardStack.trailingAnchor.constraint(equalTo: recordsCardView.trailingAnchor, constant: -14),
-            recordsCardStack.bottomAnchor.constraint(equalTo: recordsCardView.bottomAnchor, constant: -14),
-
-            controlsGrid.widthAnchor.constraint(equalTo: settingsCardStack.widthAnchor),
-            statusBadgeLabel.widthAnchor.constraint(lessThanOrEqualTo: statusCardStack.widthAnchor),
-            competitiveInfoLabel.widthAnchor.constraint(equalTo: statusCardStack.widthAnchor),
-            resultLabel.widthAnchor.constraint(equalTo: statusCardStack.widthAnchor),
-            recordsHeaderStack.widthAnchor.constraint(lessThanOrEqualTo: recordsCardStack.widthAnchor),
-            recordsScrollView.widthAnchor.constraint(equalTo: recordsCardStack.widthAnchor),
-            recordsScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
-            rulesCardView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-            achievementsCardView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
-            rulesCardStack.topAnchor.constraint(equalTo: rulesCardView.topAnchor, constant: 14),
-            rulesCardStack.leadingAnchor.constraint(equalTo: rulesCardView.leadingAnchor, constant: 14),
-            rulesCardStack.trailingAnchor.constraint(equalTo: rulesCardView.trailingAnchor, constant: -14),
-            rulesCardStack.bottomAnchor.constraint(equalTo: rulesCardView.bottomAnchor, constant: -14),
-            rulesBodyLabel.widthAnchor.constraint(equalTo: rulesCardStack.widthAnchor),
-            achievementsCardStack.topAnchor.constraint(equalTo: achievementsCardView.topAnchor, constant: 14),
-            achievementsCardStack.leadingAnchor.constraint(equalTo: achievementsCardView.leadingAnchor, constant: 14),
-            achievementsCardStack.trailingAnchor.constraint(equalTo: achievementsCardView.trailingAnchor, constant: -14),
-            achievementsCardStack.bottomAnchor.constraint(equalTo: achievementsCardView.bottomAnchor, constant: -14),
-            achievementsScrollView.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
-            achievementsHeaderStack.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
-            // 高度由标题、内边距及完整标签区共同决定，不再受横幅高度限制。
-            achievementsScrollView.heightAnchor.constraint(equalToConstant: AchievementBadgeStripView.preferredHeight),
-
-            languagePopup.widthAnchor.constraint(equalToConstant: 240),
-            languagePopup.heightAnchor.constraint(equalToConstant: 38),
-            modePopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
-            modePopup.heightAnchor.constraint(equalToConstant: 38),
-            optionPopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
-            optionPopup.heightAnchor.constraint(equalToConstant: 38),
-            volumeControlView.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
-            volumeControlView.heightAnchor.constraint(equalToConstant: 38),
-            startButton.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
-            startButton.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
-            startButton.heightAnchor.constraint(equalToConstant: 38),
-
-            languageTitleLabel.centerYAnchor.constraint(equalTo: languagePopup.centerYAnchor),
-            modeTitleLabel.centerYAnchor.constraint(equalTo: modePopup.centerYAnchor),
-            optionTitleLabel.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor),
-            volumeTitleLabel.centerYAnchor.constraint(equalTo: volumeControlView.centerYAnchor)
-        ])
-    }
+    override func loadView() { view = dashboard }
 
     override func viewDidLoad() {
         super.viewDidLoad()
-
-        configureLocalizedText()
-
-        observerToken = controller.addObserver(owner: self) { [weak self] in
-            self?.updateCompetitiveInfo()
-        }
-
-        syncVolumeControlFromAudioSystem()
-        modePopup.selectItem(at: ModeSelection.free.rawValue)
-        applyModeSelection(resetGame: true)
-        configureAchievements()
-    }
-
-    // MARK: - Achievements
-
-    private func configureAchievements() {
-        achievementToasts = AchievementToastPresenter(host: view) { [weak self] ids in
-            self?.presentAchievements(detailID: ids.count == 1 ? ids.first : nil)
-        }
-        achievementsChangeObserver = NotificationCenter.default.addObserver(
-            forName: AchievementsManager.didChangeNotification, object: AchievementsManager.shared, queue: .main
-        ) { [weak self] _ in self?.refreshAchievements() }
-        achievementsUnlockObserver = NotificationCenter.default.addObserver(
-            forName: AchievementsManager.didUnlockNotification, object: AchievementsManager.shared, queue: .main
-        ) { [weak self] note in
-            guard let ids = note.userInfo?["ids"] as? [Int] else { return }
-            self?.achievementToasts?.enqueue(ids)
-        }
-        refreshAchievements()
+        dashboard.onStart = { [weak self] in self?.startRound() }
+        dashboard.onMode = { [weak self] mode in self?.selectMode(mode) }
+        dashboard.onNavigate = { [weak self] page in self?.presentUtility(page) }
+        dashboard.onAchievement = { [weak self] id in self?.presentAchievements(detailID: id) }
+        observerToken = controller.addObserver(owner: self) { [weak self] in self?.refresh() }
+        achievementsChangeObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didChangeNotification, object: achievements, queue: .main) { [weak self] _ in self?.refreshAchievements() }
+        achievementsUnlockObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: achievements, queue: .main) { [weak self] note in
+            if let ids = note.userInfo?["ids"] as? [Int] { self?.achievementToasts?.enqueue(ids) }
+        }
+        achievementToasts = AchievementToastPresenter(host: view) { [weak self] ids in self?.presentAchievements(detailID: ids.count == 1 ? ids.first : nil) }
+        selectMode(.free)
+    }
+
+    func selectMode(_ mode: HomeGameMode) {
+        guard !hasConfiguredMode || mode != selection else { return }
+        hasConfiguredMode = true
+        selection = mode; hasSavedFinishedRecord = false
+        controller.configure(mode: mode.gameMode)
+        if audioEnabled { audioSystem.updateBackgroundMusic(for: mode.gameMode) }
+        refresh()
+        synchronizeSystemModalTouchBarPresentation(trigger: "modeSelectionChanged")
+    }
+
+    func startRound() {
+        hasSavedFinishedRecord = false
+        controller.startRound()
+        refresh()
     }
 
     private func refreshAchievements() {
-        let manager = AchievementsManager.shared
-        pixelBannerView.refresh(manager: manager)
-        achievementsTitleLabel.stringValue = localizedFormat("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
-        // 自绘深色背景下显式指定文字颜色，避免 inline 按钮回退成黑色文字。
-        achievementsAllButton.attributedTitle = NSAttributedString(
-            string: localized("achievement.view_all"),
-            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: rulesThemeColor]
-        )
-        achievementsScrollView.refresh(manager: manager)
+        dashboard.refresh(snapshot: controller.snapshot(), mode: selection, manager: achievements)
         if achievementsPanel?.window?.isVisible == true { achievementsPanel?.refresh() }
         achievementToasts?.refreshLanguage()
     }
 
+    private func refresh() {
+        let snapshot = controller.snapshot()
+        dashboard.refresh(snapshot: snapshot, mode: selection, manager: achievements)
+        if snapshot.isFinished, !hasSavedFinishedRecord {
+            hasSavedFinishedRecord = true
+            if snapshot.score > 0 {
+                switch snapshot.mode {
+                case .scoreAttack:
+                    _ = recordStore.addScoreAttackRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, durationMinutes: 1)
+                case .speedRun:
+                    _ = recordStore.addSpeedRunRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, targetScore: HomeGameMode.speedRunTarget)
+                case .free: break
+                }
+            }
+        }
+        if snapshot.isRunning, selection != .free, !snapshot.isFinished {
+            if hudTimer == nil {
+                let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.controller.tick() }
+                RunLoop.main.add(timer, forMode: .common); hudTimer = timer
+            }
+        } else { hudTimer?.invalidate(); hudTimer = nil }
+        view.window?.title = localizer.string("window.title")
+        for panel in utilityPanels.values where panel.window?.isVisible == true { panel.refresh(mode: selection, volume: audioSystem.masterVolume) }
+    }
+
     private func presentAchievements(detailID: Int?) {
-        if achievementsPanel == nil {
-            achievementsPanel = AchievementsWindowController(manager: .shared)
-        }
+        if achievementsPanel == nil { achievementsPanel = AchievementsWindowController(manager: achievements) }
         achievementsPanel?.present(from: view.window, detailID: detailID)
     }
 
-    @objc private func showAllAchievements() { presentAchievements(detailID: nil) }
+    private func presentUtility(_ page: String) {
+        if utilityPanels[page] == nil {
+            let panel = HomeUtilityPanel(page: page, store: recordStore)
+            panel.onLanguage = { [weak self] language in
+                self?.localizer.setLanguage(language)
+                self?.refresh(); self?.refreshAchievements()
+            }
+            panel.onVolume = { [weak self] volume in self?.audioSystem.setMasterVolume(volume) }
+            utilityPanels[page] = panel
+        }
+        utilityPanels[page]?.refresh(mode: selection, volume: audioSystem.masterVolume)
+        utilityPanels[page]?.present(from: view.window)
+    }
 
     deinit {
-        if let observerToken {
-            controller.removeObserver(observerToken)
-        }
-        if let observer = achievementsUnlockObserver {
-            NotificationCenter.default.removeObserver(observer)
-            achievementsUnlockObserver = nil
-        }
-        if let observer = achievementsChangeObserver {
-            NotificationCenter.default.removeObserver(observer)
-        }
-        achievementsPanel?.close()
+        if let observerToken { controller.removeObserver(observerToken) }
+        for observer in [achievementsChangeObserver, achievementsUnlockObserver].compactMap({ $0 }) { NotificationCenter.default.removeObserver(observer) }
+        achievementsPanel?.close(); utilityPanels.values.forEach { $0.close() }
         removeTouchBarLifecycleObservers()
         invalidateSystemModalTouchBarPresentation(reason: "deinit")
         hudTimer?.invalidate()
-        audioSystem.stopBackgroundMusic()
-    }
-
-    override func makeTouchBar() -> NSTouchBar? {
-        // 当前正式方案固定使用私有 modal；不再通过公开 responder 链路提供游戏 Touch Bar。
-        return nil
-    }
-
+        if audioEnabled { audioSystem.stopBackgroundMusic() }
+    }
+
+    override func makeTouchBar() -> NSTouchBar? { nil }
     override func viewDidAppear() {
         super.viewDidAppear()
-        if let window = view.window {
-            installTouchBarLifecycleObservers(for: window)
-        }
-        // 当前正式方案固定使用私有 modal，目标是尽量隐藏右侧常驻系统功能栏并占满 Touch Bar。
-        logTouchBarDiagnostics("viewDidAppear，windowExists=\(view.window != nil)")
+        if let window = view.window { installTouchBarLifecycleObservers(for: window) }
         synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
         view.window?.makeFirstResponder(self)
-        view.window?.minSize = NSSize(width: 720, height: 450)
-        updateWindowTitle()
-    }
-
+        view.window?.contentMinSize = NSSize(width: 960, height: 720)
+        refresh()
+    }
     override func viewDidDisappear() {
-        logTouchBarDiagnostics("viewDidDisappear，开始失效私有 modal Touch Bar")
         invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
         removeTouchBarLifecycleObservers()
         super.viewDidDisappear()
-    }
-
-    override func viewDidLayout() {
-        super.viewDidLayout()
-        let currentWidth = max(recordsScrollView.contentSize.width, 0)
-        if abs(currentWidth - lastRecordsLayoutWidth) > 0.5 {
-            lastRecordsLayoutWidth = currentWidth
-            updateRecordPanel(with: controller.snapshot())
-        }
-        refreshRecordsTextLayout()
     }
 
     func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
@@ -1064,1459 +516,27 @@
         )
     }
 
-    @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
-        let index = max(0, sender.indexOfSelectedItem)
-        let language = AppLanguage.allCases[min(index, AppLanguage.allCases.count - 1)]
-        localizer.setLanguage(language)
-
-        configureLocalizedText()
-        updateCompetitiveInfo()
-        updateWindowTitle()
-    }
-
-    @objc private func modeSelectionChanged(_ sender: NSPopUpButton) {
-        applyModeSelection(resetGame: true)
-    }
-
-    @objc private func optionSelectionChanged(_ sender: NSPopUpButton) {
-        switch currentModeSelection {
-        case .free:
-            break
-        case .scoreAttack:
-            selectedScoreAttackIndex = max(0, optionPopup.indexOfSelectedItem)
-        case .speedRun:
-            selectedSpeedRunIndex = max(0, optionPopup.indexOfSelectedItem)
-        }
-
-        applyModeSelection(resetGame: true)
-    }
-
-    @objc private func volumeSliderChanged(_ sender: NSSlider) {
-        let volume = Float(sender.doubleValue)
-        audioSystem.setMasterVolume(volume)
-        updateVolumeControlDisplay(for: volume)
-    }
-
-    @objc private func startButtonTapped(_ sender: NSButton) {
-        guard currentModeSelection != .free else { return }
-        resetRuntimeIndicators()
-        hasSavedFinishedRecord = false
-        controller.startRound()
-        updateCompetitiveInfo()
-    }
-
-    @objc private func handleHudTimerTick() {
-        controller.tick()
-    }
-
-    private func applyModeSelection(resetGame: Bool) {
-        let selection = currentModeSelection
-        let selectedMode = gameMode(for: selection)
-        let windowFrameBeforeUpdate = view.window?.frame
-        populateOptionPopup(for: selection)
-        updateStartControlVisibility(for: selection)
-        updateCardsLayout(for: selection)
-        updateRulesDescription(for: selection)
-
-        if resetGame {
-            resetRuntimeIndicators()
-            hasSavedFinishedRecord = false
-            controller.configure(mode: selectedMode)
-        }
-        audioSystem.updateBackgroundMusic(for: selectedMode)
-
-        updateCompetitiveInfo()
-        preserveWindowFrame(windowFrameBeforeUpdate)
-        refreshRecordPanelAfterLayoutIfNeeded()
-        synchronizeSystemModalTouchBarPresentation(trigger: "modeSelectionChanged")
-    }
-
-    private func configureLocalizedText() {
-        configureLanguagePopup()
-
-        titleLabel.stringValue = localized("window.title")
-        subtitleLabel.stringValue = localized("window.subtitle")
-        settingsTitleLabel.stringValue = localized("panel.settings")
-        statusTitleLabel.stringValue = localized("panel.status")
-        recordsTitleLabel.stringValue = localized("panel.records")
-        rulesTitleLabel.stringValue = localized("panel.rules")
-        refreshAchievements()
-        languageTitleLabel.stringValue = localized("language.label")
-        modeTitleLabel.stringValue = localized("mode.label")
-        volumeTitleLabel.stringValue = localized("volume.label")
-        startTitleLabel.stringValue = ""
-        syncVolumeControlFromAudioSystem()
-
-        if let icon = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: titleLabel.stringValue) {
-            headerIconView.image = icon
-        }
-
-        let selectedModeIndex = max(0, modePopup.indexOfSelectedItem)
-        modePopup.removeAllItems()
-        modePopup.addItems(withTitles: [
-            localized("mode.free"),
-            localized("mode.score_attack"),
-            localized("mode.speed_run")
-        ])
-        modePopup.selectItem(at: min(selectedModeIndex, 2))
-
-        populateOptionPopup(for: currentModeSelection)
-        updateStartControlVisibility(for: currentModeSelection)
-        updateCardsLayout(for: currentModeSelection)
-        updateRulesDescription(for: currentModeSelection)
-
-        let snapshot = controller.snapshot()
-        updateStartControl(for: snapshot)
-        updateRecordPanel(with: snapshot)
-
-        // Ensure controls grid column alignment after localization changes
-        controlsGrid.column(at: 0).xPlacement = .trailing
-        controlsGrid.column(at: 1).xPlacement = .leading
-        view.layoutSubtreeIfNeeded()
-    }
-
-    private func configureLanguagePopup() {
-        let selectedLanguage = localizer.language
-        languagePopup.removeAllItems()
-        languagePopup.addItems(withTitles: AppLanguage.allCases.map { localized($0.titleKey) })
-
-        if let index = AppLanguage.allCases.firstIndex(of: selectedLanguage) {
-            languagePopup.selectItem(at: index)
-        } else {
-            languagePopup.selectItem(at: 0)
-        }
-    }
-
-    private func populateOptionPopup(for selection: ModeSelection) {
-        let optionRow = controlsGrid.row(at: ControlRow.option.rawValue)
-
-        switch selection {
-        case .free:
-            optionRow.isHidden = true
-
-        case .scoreAttack:
-            optionRow.isHidden = false
-            optionTitleLabel.stringValue = localized("option.time")
-
-            let titles = scoreAttackMinutes.map { localizedFormat("option.minute_format", $0) }
-            optionPopup.removeAllItems()
-            optionPopup.addItems(withTitles: titles)
-            let clampedIndex = min(max(0, selectedScoreAttackIndex), titles.count - 1)
-            optionPopup.selectItem(at: clampedIndex)
-            selectedScoreAttackIndex = clampedIndex
-
-        case .speedRun:
-            optionRow.isHidden = false
-            optionTitleLabel.stringValue = localized("option.target_score")
-
-            let titles = speedRunTargets.map { localizedFormat("option.target_format", $0) }
-            optionPopup.removeAllItems()
-            optionPopup.addItems(withTitles: titles)
-            let clampedIndex = min(max(0, selectedSpeedRunIndex), titles.count - 1)
-            optionPopup.selectItem(at: clampedIndex)
-            selectedSpeedRunIndex = clampedIndex
-        }
-    }
-
-    private func updateStartControlVisibility(for selection: ModeSelection) {
-        let actionRow = controlsGrid.row(at: ControlRow.action.rawValue)
-        actionRow.isHidden = selection == .free
-    }
-
-    private func updateCardsLayout(for selection: ModeSelection) {
-        let shouldExpandSettings = selection == .free
-        rightColumnStack.isHidden = shouldExpandSettings
-        settingsExpandedWidthConstraint?.isActive = shouldExpandSettings
-        settingsVersusRightColumnConstraint?.isActive = !shouldExpandSettings
-        rightColumnMinWidthConstraint?.isActive = !shouldExpandSettings
-    }
-
-    private func preserveWindowFrame(_ previousFrame: NSRect?) {
-        guard let previousFrame,
-              let window = view.window else {
-            return
-        }
-
-        let shouldRestoreFrame =
-            abs(window.frame.width - previousFrame.width) > 0.5 ||
-            abs(window.frame.height - previousFrame.height) > 0.5
-
-        guard shouldRestoreFrame else { return }
-        window.setFrame(previousFrame, display: false, animate: false)
-    }
-
-    private func refreshRecordPanelAfterLayoutIfNeeded() {
-        guard currentModeSelection != .free else { return }
-        view.layoutSubtreeIfNeeded()
-        updateRecordPanel(with: controller.snapshot())
-    }
-
-    private func updateRulesDescription(for selection: ModeSelection) {
-        let coreRulePrimary = localized("rules.core.line1")
-        let coreRuleSecondary = localized("rules.core.line2")
-        let operationLabel = localized("rules.label.operation")
-        let modeRule: String
-        let settlementRule: String
-
-        switch selection {
-        case .free:
-            modeRule = localized("rules.short.mode.free")
-            settlementRule = localized("rules.short.settlement.free")
-
-        case .scoreAttack:
-            let minutes = scoreAttackMinutes[min(max(0, selectedScoreAttackIndex), scoreAttackMinutes.count - 1)]
-            modeRule = localizedFormat("rules.short.mode.score_attack", localizedFormat("option.minute_format", minutes))
-            settlementRule = localized("rules.short.settlement.score_attack")
-
-        case .speedRun:
-            let targetScore = speedRunTargets[min(max(0, selectedSpeedRunIndex), speedRunTargets.count - 1)]
-            modeRule = localizedFormat("rules.short.mode.speed_run", localizedFormat("option.target_format", targetScore))
-            settlementRule = localized("rules.short.settlement.speed_run")
-        }
-
-        // 玩法说明统一去掉模式小标题，只保留规则项。
-        var descriptionRows: [String] = []
-        descriptionRows.append("• \(localized("rules.category.core"))：\(coreRulePrimary)")
-        descriptionRows.append("• \(operationLabel)：\(coreRuleSecondary)")
-        descriptionRows.append("• \(localized("rules.label.mode_rule"))：\(modeRule)")
-        descriptionRows.append("• \(localized("rules.label.settlement"))：\(settlementRule)")
-        let description = descriptionRows.joined(separator: "\n")
-        rulesBodyLabel.stringValue = description
-    }
-
-    private func updateCompetitiveInfo() {
-        let snapshot = controller.snapshot()
-        updateComboState(with: snapshot)
-        syncHudTimer(with: snapshot)
-        updateStartControl(for: snapshot)
-        updateStatusBadge(with: snapshot)
-        persistModeRecordIfNeeded(with: snapshot)
-        updateRecordPanel(with: snapshot)
-
-        switch snapshot.mode {
-        case .free:
-            statusCardView.isHidden = true
-            competitiveInfoLabel.stringValue = ""
-            resultLabel.stringValue = ""
-            resultLabel.isHidden = true
-
-        case .scoreAttack:
-            statusCardView.isHidden = false
-            let remaining = formatClock(snapshot.remainingTime ?? 0)
-            let scoreLine = localizedFormat("hud.score_attack_line1", snapshot.score)
-            let timeLine = localizedFormat("hud.score_attack_line2", remaining)
-            competitiveInfoLabel.stringValue = "\(scoreLine)\n\(timeLine)"
-
-            if snapshot.isFinished {
-                resultLabel.stringValue = localizedFormat("result.score_attack_finished", snapshot.score)
-                resultLabel.isHidden = false
-            } else if !snapshot.isRunning {
-                resultLabel.stringValue = localized("result.waiting_start")
-                resultLabel.isHidden = false
-            } else {
-                resultLabel.stringValue = ""
-                resultLabel.isHidden = true
-            }
-
-        case .speedRun:
-            statusCardView.isHidden = false
-            let targetScore = snapshot.targetScore ?? 0
-            let elapsed = formatClock(snapshot.elapsedTime)
-            let scoreLine = localizedFormat("hud.speed_run_line1", snapshot.score, targetScore)
-            let timeLine = localizedFormat("hud.speed_run_line2", elapsed)
-            competitiveInfoLabel.stringValue = "\(scoreLine)\n\(timeLine)"
-
-            if snapshot.isFinished {
-                resultLabel.stringValue = localizedFormat("result.speed_run_finished", elapsed)
-                resultLabel.isHidden = false
-            } else if !snapshot.isRunning {
-                resultLabel.stringValue = localized("result.waiting_start")
-                resultLabel.isHidden = false
-            } else {
-                resultLabel.stringValue = ""
-                resultLabel.isHidden = true
-            }
-        }
-    }
-
-    private func updateComboState(with snapshot: GameSnapshot) {
-        switch snapshot.mode {
-        case .free:
-            resetRuntimeIndicators()
-            return
-
-        case .scoreAttack, .speedRun:
-            if snapshot.isFinished {
-                lastObservedScore = snapshot.score
-                return
-            }
-
-            guard snapshot.isRunning else {
-                comboStreak = 0
-                lastObservedScore = snapshot.score
-                lastScoreGainDate = nil
-                return
-            }
-
-            let now = Date()
-            if snapshot.score > lastObservedScore {
-                comboStreak = min(comboStreak + 1, 99)
-                lastScoreGainDate = now
-            } else if snapshot.score < lastObservedScore {
-                comboStreak = 0
-                lastScoreGainDate = nil
-            } else if let lastGain = lastScoreGainDate, now.timeIntervalSince(lastGain) > 1.6 {
-                comboStreak = 0
-            }
-
-            lastObservedScore = snapshot.score
-        }
-    }
-
-    private func updateStatusBadge(with snapshot: GameSnapshot) {
-        switch snapshot.mode {
-        case .free:
-            hideStatusBadge()
-
-        case .scoreAttack, .speedRun:
-            // 在计时/得分模式下不显示“进行中”或“已结束”徽章，只保留连击（combo）提示
-            if !snapshot.isRunning || snapshot.isFinished {
-                hideStatusBadge()
-            } else if comboStreak >= 2 {
-                setStatusBadge(text: localizedFormat("status.combo", comboStreak), tone: .combo)
-            } else {
-                hideStatusBadge()
-            }
-        }
-    }
-
-    private func setStatusBadge(text: String, tone: BadgeTone) {
-        statusBadgeLabel.isHidden = false
-        statusBadgeLabel.stringValue = "  \(text)  "
-
-        switch tone {
-        case .ready:
-            statusBadgeLabel.textColor = NSColor.white.withAlphaComponent(0.92)
-            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.32, alpha: 0.95).cgColor
-            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.38, green: 0.47, blue: 0.6, alpha: 0.95).cgColor
-
-        case .running:
-            statusBadgeLabel.textColor = NSColor(calibratedRed: 0.82, green: 1.0, blue: 0.82, alpha: 1)
-            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.29, blue: 0.16, alpha: 0.95).cgColor
-            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.38, green: 0.82, blue: 0.42, alpha: 0.95).cgColor
-
-        case .combo:
-            statusBadgeLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.76, alpha: 1)
-            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.44, green: 0.27, blue: 0.06, alpha: 0.95).cgColor
-            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.2, alpha: 0.95).cgColor
-
-        case .finish:
-            statusBadgeLabel.textColor = NSColor(calibratedRed: 1, green: 0.87, blue: 0.87, alpha: 1)
-            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.4, green: 0.14, blue: 0.16, alpha: 0.95).cgColor
-            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.98, green: 0.44, blue: 0.44, alpha: 0.95).cgColor
-        }
-
-        statusBadgeLabel.layer?.borderWidth = 1
-    }
-
-    private func hideStatusBadge() {
-        statusBadgeLabel.stringValue = ""
-        statusBadgeLabel.isHidden = true
-    }
-
-    private func resetRuntimeIndicators() {
-        comboStreak = 0
-        lastObservedScore = 0
-        lastScoreGainDate = nil
-    }
-
-    private func updateStartControl(for snapshot: GameSnapshot) {
-        switch snapshot.mode {
-        case .free:
-            applyStartButtonAppearance(isRestart: false)
-        case .scoreAttack, .speedRun:
-            let isRestart = snapshot.isRunning || snapshot.isFinished
-            applyStartButtonAppearance(isRestart: isRestart)
-        }
-    }
-
-    private func applyStartButtonAppearance(isRestart: Bool) {
-        let titleKey = isRestart ? "start.action_restart" : "start.action_start"
-        let symbolName = isRestart ? "arrow.clockwise" : "play.fill"
-        let title = localized(titleKey)
-
-        let symbol: NSImage?
-        if let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
-            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
-            symbol = baseSymbol.withSymbolConfiguration(config)
-        } else {
-            symbol = nil
-        }
-
-        startButton.setDisplay(title: title, image: symbol)
-        startButton.toolTip = title
-    }
-
-    private func syncHudTimer(with snapshot: GameSnapshot) {
-        let shouldRun: Bool
-        switch snapshot.mode {
-        case .free:
-            shouldRun = false
-        case .scoreAttack, .speedRun:
-            shouldRun = snapshot.isRunning && !snapshot.isFinished
-        }
-
-        if shouldRun {
-            if hudTimer == nil {
-                let timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(handleHudTimerTick), userInfo: nil, repeats: true)
-                RunLoop.main.add(timer, forMode: .common)
-                hudTimer = timer
-            }
-        } else {
-            hudTimer?.invalidate()
-            hudTimer = nil
-        }
-    }
-
-    private var currentModeSelection: ModeSelection {
-        return ModeSelection(rawValue: modePopup.indexOfSelectedItem) ?? .free
-    }
-
-    private func gameMode(for selection: ModeSelection) -> GameMode {
-        switch selection {
-        case .free:
-            return .free
-        case .scoreAttack:
-            let minutes = scoreAttackMinutes[selectedScoreAttackIndex]
-            return .scoreAttack(duration: TimeInterval(minutes * 60))
-        case .speedRun:
-            let target = speedRunTargets[selectedSpeedRunIndex]
-            return .speedRun(targetScore: target)
-        }
-    }
-
-    private func updateWindowTitle() {
-        view.window?.title = localized("window.title")
-    }
-
-    private func persistModeRecordIfNeeded(with snapshot: GameSnapshot) {
-        guard let context = recordPanelContext(for: snapshot.mode) else {
-            hasSavedFinishedRecord = false
-            return
-        }
-
-        guard snapshot.isFinished else {
-            hasSavedFinishedRecord = false
-            return
-        }
-
-        guard !hasSavedFinishedRecord else { return }
-
-        let insertedRecord: ModeRecord?
-        switch snapshot.mode {
-        case .free:
-            insertedRecord = nil
-
-        case .scoreAttack:
-            insertedRecord = recordStore.addScoreAttackRecord(
-                score: snapshot.score,
-                elapsedTime: snapshot.elapsedTime,
-                durationMinutes: context.detailValue
-            )
-
-        case .speedRun:
-            insertedRecord = recordStore.addSpeedRunRecord(
-                score: snapshot.score,
-                elapsedTime: snapshot.elapsedTime,
-                targetScore: context.detailValue
-            )
-        }
-
-        hasSavedFinishedRecord = true
-
-        if let insertedRecord {
-            let topRecordID = recordStore.records(for: context.modeKey, detailValue: context.detailValue).first?.id
-            if topRecordID == insertedRecord.id {
-                latestRecordIDByMode[context.scopeID] = insertedRecord.id
-            } else {
-                latestRecordIDByMode.removeValue(forKey: context.scopeID)
-            }
-        }
-    }
-
-    private func updateRecordPanel(with snapshot: GameSnapshot) {
-        guard let context = recordPanelContext(for: snapshot.mode) else {
-            recordsCardView.isHidden = true
-            recordsTitleLabel.stringValue = localized("panel.records")
-            setRecordsText("")
-            return
-        }
-
-        recordsCardView.isHidden = false
-        recordsTitleLabel.stringValue = localized("panel.records")
-
-        let records = recordStore.records(for: context.modeKey, detailValue: context.detailValue)
-        guard !records.isEmpty else {
-            setRecordsText(localized("records.empty"))
-            return
-        }
-
-        let newestRecordID = latestRecordIDByMode[context.scopeID]
-        setRecordRows(records, modeKey: context.modeKey, newestRecordID: newestRecordID)
-    }
-
-    private func setRecordRows(_ records: [ModeRecord], modeKey: ModeRecordKey, newestRecordID: String?) {
-        let availableWidth = recordRowTabStopWidth()
-        let paragraphStyle = NSMutableParagraphStyle()
-        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: availableWidth, options: [:])]
-        paragraphStyle.defaultTabInterval = availableWidth
-        paragraphStyle.lineBreakMode = .byTruncatingTail
-        paragraphStyle.minimumLineHeight = 24
-        paragraphStyle.maximumLineHeight = 24
-        // 记录项行间距缩减 50%，从 7 调整为 3.5。
-        paragraphStyle.lineSpacing = 3.5
-
-        let metricAttributes: [NSAttributedString.Key: Any] = [
-            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.94),
-            .paragraphStyle: paragraphStyle
-        ]
-        let dateAttributes: [NSAttributedString.Key: Any] = [
-            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.5),
-            .paragraphStyle: paragraphStyle
-        ]
-        let newAttributes: [NSAttributedString.Key: Any] = [
-            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy),
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.88),
-            .paragraphStyle: paragraphStyle
-        ]
-
-        let content = NSMutableAttributedString()
-        for (index, record) in records.enumerated() {
-            let row = NSMutableAttributedString()
-            row.append(rankTagAttributedText(rank: index + 1))
-            row.append(NSAttributedString(string: " "))
-            row.append(NSAttributedString(string: recordMetricText(for: modeKey, record: record), attributes: metricAttributes))
-
-            if record.id == newestRecordID {
-                let marker = localized("records.new_suffix").trimmingCharacters(in: .whitespaces)
-                row.append(NSAttributedString(string: " \(marker)", attributes: newAttributes))
-            }
-
-            row.append(NSAttributedString(string: "\t", attributes: metricAttributes))
-            row.append(NSAttributedString(string: recordDateText(for: record), attributes: dateAttributes))
-            row.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: row.length))
-            content.append(row)
-
-            if index < records.count - 1 {
-                content.append(NSAttributedString(string: "\n"))
-            }
-        }
-
-        setRecordsText(content)
-    }
-
-    private func rankTagAttributedText(rank: Int) -> NSAttributedString {
-        let attachment = NSTextAttachment()
-        let image = rankTagImage(rank: rank)
-        attachment.image = image
-        // 根据视觉反馈，将序号 Tag 整体向下平移 3px，避免与同行文本中线错位。
-        attachment.bounds = NSRect(x: 0, y: -3, width: image.size.width, height: image.size.height)
-        return NSAttributedString(attachment: attachment)
-    }
-
-    private func rankTagImage(rank: Int) -> NSImage {
-        let text = String(rank)
-        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .heavy)
-        let attributes: [NSAttributedString.Key: Any] = [
-            .font: font,
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96)
-        ]
-        let textSize = (text as NSString).size(withAttributes: attributes)
-        let horizontalInset: CGFloat = 6
-        let verticalInset: CGFloat = 2
-        let size = NSSize(
-            width: ceil(textSize.width + horizontalInset * 2),
-            height: ceil(textSize.height + verticalInset * 2)
-        )
-
-        let image = NSImage(size: size)
-        image.lockFocus()
-
-        let rect = NSRect(origin: .zero, size: size)
-        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
-        NSColor(calibratedRed: 0.96, green: 0.56, blue: 0.18, alpha: 0.24).setFill()
-        path.fill()
-        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.32, alpha: 0.85).setStroke()
-        path.lineWidth = 1
-        path.stroke()
-
-        let paragraph = NSMutableParagraphStyle()
-        paragraph.alignment = .center
-        let drawAttributes: [NSAttributedString.Key: Any] = [
-            .font: font,
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96),
-            .paragraphStyle: paragraph
-        ]
-        let textRect = NSRect(
-            x: 0,
-            y: floor((size.height - textSize.height) / 2),
-            width: size.width,
-            height: textSize.height
-        )
-        (text as NSString).draw(in: textRect, withAttributes: drawAttributes)
-
-        image.unlockFocus()
-        return image
-    }
-
-    private func recordMetricText(for modeKey: ModeRecordKey, record: ModeRecord) -> String {
-        switch modeKey {
-        case .scoreAttack:
-            return localizedFormat("records.metric.score", record.score)
-        case .speedRun:
-            return formatClock(record.elapsedTime)
-        }
-    }
-
-    private func recordDateText(for record: ModeRecord) -> String {
-        let formatter = DateFormatter()
-        formatter.locale = localizer.locale
-        formatter.dateFormat = localized("records.date_format")
-        return formatter.string(from: Date(timeIntervalSince1970: record.createdAt))
-    }
-
-    private func recordPanelContext(for mode: GameMode) -> RecordPanelContext? {
-        switch mode {
-        case .free:
-            return nil
-
-        case .scoreAttack(let duration):
-            let minutes = max(1, Int((duration / 60).rounded()))
-            return RecordPanelContext(
-                modeKey: .scoreAttack,
-                detailValue: minutes
-            )
-
-        case .speedRun(let targetScore):
-            let normalizedTarget = max(1, targetScore)
-            return RecordPanelContext(
-                modeKey: .speedRun,
-                detailValue: normalizedTarget
-            )
-        }
-    }
-
-    private func setRecordsText(_ text: String) {
-        let attributes: [NSAttributedString.Key: Any] = [
-            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
-            .foregroundColor: recordsThemeColor.withAlphaComponent(0.9)
-        ]
-        let attributed = NSAttributedString(string: text, attributes: attributes)
-        setRecordsText(attributed)
-    }
-
-    private func recordRowTabStopWidth() -> CGFloat {
-        let insetWidth = recordsTextView.textContainerInset.width * 2
-        let width = recordsScrollView.contentSize.width - insetWidth - 2
-        return max(width, 180)
-    }
-
-    private func setRecordsText(_ attributed: NSAttributedString) {
-        recordsTextView.textStorage?.setAttributedString(attributed)
-        refreshRecordsTextLayout()
-    }
-
-    private func refreshRecordsTextLayout() {
-        guard let textContainer = recordsTextView.textContainer,
-              let layoutManager = recordsTextView.layoutManager else {
-            return
-        }
-
-        let width = max(recordsScrollView.contentSize.width, 1)
-        textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
-        layoutManager.ensureLayout(for: textContainer)
-
-        let usedRect = layoutManager.usedRect(for: textContainer)
-        let requiredHeight = max(
-            usedRect.height + recordsTextView.textContainerInset.height * 2,
-            recordsScrollView.contentSize.height
-        )
-
-        recordsTextView.frame = NSRect(x: 0, y: 0, width: width, height: requiredHeight)
-    }
-
-    private func formatClock(_ interval: TimeInterval) -> String {
-        let totalSeconds = max(0, Int(interval.rounded(.down)))
-        let minutes = totalSeconds / 60
-        let seconds = totalSeconds % 60
-        return String(format: "%02d:%02d", minutes, seconds)
-    }
-
-    private func syncVolumeControlFromAudioSystem() {
-        updateVolumeControlDisplay(for: audioSystem.masterVolume)
-    }
-
-    private func updateVolumeControlDisplay(for volume: Float) {
-        let clampedVolume = min(max(volume, 0), 1)
-        let percentage = Int((clampedVolume * 100).rounded())
-        volumeControlView.setVolume(Double(clampedVolume))
-        volumeControlView.setDisplayText("\(percentage)%")
-    }
-
-    private func localized(_ key: String) -> String {
-        return localizer.string(key)
-    }
-
-    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
-        let format = localized(key)
-        return String(format: format, locale: localizer.locale, arguments: arguments)
-    }
-
-    private func makeControlTitleLabel(color: NSColor) -> NSTextField {
-        let label = NSTextField(labelWithString: "")
-        label.alignment = .right
-        label.textColor = color
-        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
-        label.setContentHuggingPriority(.required, for: .horizontal)
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }
-
-    private func makeSectionTitleLabel(color: NSColor) -> NSTextField {
-        let label = NSTextField(labelWithString: "")
-        label.alignment = .left
-        label.textColor = color
-        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
-        label.translatesAutoresizingMaskIntoConstraints = false
-        return label
-    }
-
-    private func makeSectionIconView(symbolName: String, color: NSColor) -> NSImageView {
-        let iconView = NSImageView()
-        iconView.translatesAutoresizingMaskIntoConstraints = false
-        iconView.imageScaling = .scaleProportionallyDown
-        iconView.contentTintColor = color.withAlphaComponent(0.95)
-
-        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
-            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
-            iconView.image = symbol.withSymbolConfiguration(config)
-        } else if let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) {
-            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
-            iconView.image = fallback.withSymbolConfiguration(config)
-        }
-
-        NSLayoutConstraint.activate([
-            iconView.widthAnchor.constraint(equalToConstant: 14),
-            iconView.heightAnchor.constraint(equalToConstant: 14)
-        ])
-        return iconView
-    }
-
-    private func makeSectionHeaderStack(iconView: NSImageView, titleLabel: NSTextField) -> NSStackView {
-        let stack = NSStackView(views: [iconView, titleLabel])
-        stack.orientation = .horizontal
-        stack.alignment = .centerY
-        stack.spacing = 6
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }
 }
 
-/// 主窗口与成就面板共用像素背景，统一扫描线与光晕效果。
+/// 辅助面板沿用首页的暖白背景，保留共用组件入口以减少主题分歧。
 final class ArcadeStageView: NSView {
-    private var animationTick: CGFloat = 0
-    private var animationTimer: Timer?
-
-    override var isFlipped: Bool {
-        return true
-    }
-
-    deinit {
-        animationTimer?.invalidate()
-    }
-
-    override func viewDidMoveToWindow() {
-        super.viewDidMoveToWindow()
-
-        if window == nil {
-            animationTimer?.invalidate()
-            animationTimer = nil
-            return
-        }
-
-        guard animationTimer == nil else { return }
-        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
-            guard let self else { return }
-            self.animationTick += 1
-            self.needsDisplay = true
-        }
-        RunLoop.main.add(timer, forMode: .common)
-        animationTimer = timer
-    }
-
+    override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
-        super.draw(dirtyRect)
-
-        let baseGradient = NSGradient(colors: [
-            NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1),
-            NSColor(calibratedRed: 0.08, green: 0.1, blue: 0.16, alpha: 1),
-            NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1)
-        ])
-        baseGradient?.draw(in: bounds, angle: -90)
-
-        drawGlow(at: CGPoint(x: bounds.maxX * 0.16, y: bounds.maxY * 0.2), radius: 220, color: NSColor.systemBlue.withAlphaComponent(0.16))
-        drawGlow(at: CGPoint(x: bounds.maxX * 0.78, y: bounds.maxY * 0.72), radius: 260, color: NSColor.systemPurple.withAlphaComponent(0.12))
-
-        drawScanlines(in: bounds)
-        drawPixelMatrix(in: bounds)
-    }
-
-    private func drawGlow(at center: CGPoint, radius: CGFloat, color: NSColor) {
-        let glowRect = CGRect(
-            x: center.x - radius,
-            y: center.y - radius,
-            width: radius * 2,
-            height: radius * 2
-        )
-        let path = NSBezierPath(ovalIn: glowRect)
-        color.setFill()
-        path.fill()
-    }
-
-    private func drawScanlines(in rect: CGRect) {
-        let path = NSBezierPath()
-        let alpha = 0.04 + CGFloat((sin(Double(animationTick) * 0.07) + 1) * 0.01)
-        var y = rect.minY
-        while y <= rect.maxY {
-            path.move(to: CGPoint(x: rect.minX, y: y))
-            path.line(to: CGPoint(x: rect.maxX, y: y))
-            y += 4
-        }
-        NSColor.white.withAlphaComponent(alpha).setStroke()
-        path.lineWidth = 1
-        path.stroke()
-    }
-
-    private func drawPixelMatrix(in rect: CGRect) {
-        let step: CGFloat = 18
-        let size: CGFloat = 2
-
-        var x = rect.minX + 8
-        while x < rect.maxX {
-            var y = rect.minY + 8
-            while y < rect.maxY {
-                let wave = CGFloat(sin((Double(x + y) / 80.0) + Double(animationTick) * 0.05))
-                let alpha = 0.03 + max(0, wave) * 0.05
-                let dotRect = CGRect(x: x, y: y, width: size, height: size)
-                NSColor.white.withAlphaComponent(alpha).setFill()
-                NSBezierPath(rect: dotRect).fill()
-                y += step
-            }
-            x += step
-        }
+        HomeStyle.background.setFill()
+        bounds.fill()
     }
 }
 
-/// 共用主题卡片，边框、内框和四角像素在各窗口保持一致。
+/// 成就列表共用的轻量卡片，解锁状态通过边框颜色及图标共同表示。
 final class PixelFrameCardView: NSView {
     private let accentColor: NSColor
-
     init(accentColor: NSColor) {
         self.accentColor = accentColor
         super.init(frame: .zero)
-        wantsLayer = true
-    }
-
-    required init?(coder: NSCoder) {
-        fatalError("init(coder:) has not been implemented")
-    }
-
+    }
+    required init?(coder: NSCoder) { nil }
     override func draw(_ dirtyRect: NSRect) {
-        super.draw(dirtyRect)
-
-        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
-        let rounded = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
-
-        NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.17, alpha: 0.93).setFill()
-        rounded.fill()
-
-        accentColor.withAlphaComponent(0.48).setStroke()
-        rounded.lineWidth = 1
-        rounded.stroke()
-
-        let innerRect = cardRect.insetBy(dx: 8, dy: 8)
-        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 6, yRadius: 6)
-        NSColor.white.withAlphaComponent(0.05).setStroke()
-        innerPath.lineWidth = 1
-        innerPath.stroke()
-
-        drawCornerPixel(at: CGPoint(x: cardRect.minX + 7, y: cardRect.minY + 7), color: accentColor)
-        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 11, y: cardRect.minY + 7), color: accentColor)
-        drawCornerPixel(at: CGPoint(x: cardRect.minX + 7, y: cardRect.maxY - 11), color: accentColor)
-        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 11, y: cardRect.maxY - 11), color: accentColor)
-    }
-
-    private func drawCornerPixel(at origin: CGPoint, color: NSColor) {
-        let rect = CGRect(x: origin.x, y: origin.y, width: 4, height: 4)
-        color.withAlphaComponent(0.9).setFill()
-        NSBezierPath(rect: rect).fill()
-    }
-}
-
-private final class PixelDividerView: NSView {
-    private var phase: CGFloat = 0
-    private var timer: Timer?
-
-    override var intrinsicContentSize: NSSize {
-        return NSSize(width: NSView.noIntrinsicMetric, height: 10)
-    }
-
-    deinit {
-        timer?.invalidate()
-    }
-
-    override func viewDidMoveToWindow() {
-        super.viewDidMoveToWindow()
-
-        if window == nil {
-            timer?.invalidate()
-            timer = nil
-            return
-        }
-
-        guard timer == nil else { return }
-        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
-            guard let self else { return }
-            self.phase += 0.35
-            self.needsDisplay = true
-        }
-        RunLoop.main.add(timer, forMode: .common)
-        self.timer = timer
-    }
-
-    override func draw(_ dirtyRect: NSRect) {
-        super.draw(dirtyRect)
-
-        let baseline = bounds.midY
-        let path = NSBezierPath()
-        path.move(to: CGPoint(x: bounds.minX, y: baseline))
-        path.line(to: CGPoint(x: bounds.maxX, y: baseline))
-        NSColor.white.withAlphaComponent(0.08).setStroke()
-        path.lineWidth = 1
-        path.stroke()
-
-        let segmentWidth: CGFloat = 9
-        let segmentGap: CGFloat = 5
-        var x = bounds.minX
-        var index = 0
-
-        while x < bounds.maxX {
-            let wave = CGFloat(sin(Double(index) * 0.65 + Double(phase)))
-            let alpha = 0.16 + max(0, wave) * 0.48
-            let rect = CGRect(x: x, y: baseline - 2, width: segmentWidth, height: 4)
-            NSColor.systemTeal.withAlphaComponent(alpha).setFill()
-            NSBezierPath(rect: rect).fill()
-            x += segmentWidth + segmentGap
-            index += 1
-        }
-    }
-}
-
-private enum ArcadeControlStyle {
-    static let borderWidth: CGFloat = 1.1
-    static let cornerRadius: CGFloat = 7
-}
-
-private final class ArcadePopupButton: NSPopUpButton {
-    override var alignmentRectInsets: NSEdgeInsets {
-        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
-    }
-
-    private var hoverTrackingArea: NSTrackingArea?
-    private var isHovering = false
-    private var hasConfigured = false
-    private var chevronImageView: NSImageView?
-
-    override var intrinsicContentSize: NSSize {
-        var size = super.intrinsicContentSize
-        size.height = max(38, size.height + 12)
-        return size
-    }
-
-    override var isHighlighted: Bool {
-        didSet {
-            updateAppearance()
-        }
-    }
-
-    override var isEnabled: Bool {
-        didSet {
-            updateTitleStyle()
-            updateAppearance()
-        }
-    }
-
-    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
-        super.init(frame: buttonFrame, pullsDown: flag)
-        configureIfNeeded()
-    }
-
-    required init?(coder: NSCoder) {
-        super.init(coder: coder)
-        configureIfNeeded()
-    }
-
-    override func viewDidMoveToWindow() {
-        super.viewDidMoveToWindow()
-        configureIfNeeded()
-    }
-
-    override func addItems(withTitles itemTitles: [String]) {
-        super.addItems(withTitles: itemTitles)
-        updateTitleStyle()
-        updateMenuAppearance()
-    }
-
-    override func removeAllItems() {
-        super.removeAllItems()
-        updateTitleStyle()
-        updateMenuAppearance()
-    }
-
-    override func selectItem(at index: Int) {
-        super.selectItem(at: index)
-        updateTitleStyle()
-    }
-
-    override func synchronizeTitleAndSelectedItem() {
-        super.synchronizeTitleAndSelectedItem()
-        updateTitleStyle()
-    }
-
-    override func updateTrackingAreas() {
-        super.updateTrackingAreas()
-
-        if let hoverTrackingArea {
-            removeTrackingArea(hoverTrackingArea)
-        }
-
-        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
-        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
-        addTrackingArea(area)
-        hoverTrackingArea = area
-    }
-
-    override func mouseEntered(with event: NSEvent) {
-        super.mouseEntered(with: event)
-        isHovering = true
-        updateAppearance()
-    }
-
-    override func mouseExited(with event: NSEvent) {
-        super.mouseExited(with: event)
-        isHovering = false
-        updateAppearance()
-    }
-
-    private func configureIfNeeded() {
-        guard !hasConfigured else { return }
-        hasConfigured = true
-
-        wantsLayer = true
-        isBordered = false
-        focusRingType = .none
-        contentTintColor = NSColor(calibratedRed: 0.8, green: 0.91, blue: 1.0, alpha: 0.96)
-        setContentHuggingPriority(.defaultLow, for: .horizontal)
-        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
-        font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
-
-        if let popupCell = cell as? NSPopUpButtonCell {
-            popupCell.arrowPosition = .noArrow
-        }
-
-        configureChevronIfNeeded()
-        updateTitleStyle()
-        updateMenuAppearance()
-        updateAppearance()
-    }
-
-    private func updateTitleStyle() {
-        let title = selectedItem?.title ?? ""
-        let color = isEnabled
-            ? NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.96)
-            : NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.42)
-        attributedTitle = NSAttributedString(
-            string: "    \(title)    ",
-            attributes: [
-                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
-                .foregroundColor: color,
-                .kern: 0.22
-            ]
-        )
-    }
-
-    private func updateMenuAppearance() {
-        guard let menu else { return }
-        menu.appearance = NSAppearance(named: .darkAqua)
-    }
-
-    private func updateAppearance() {
-        guard let layer else { return }
-
-        let background: NSColor
-        let border: NSColor
-
-        if !isEnabled {
-            background = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 0.8)
-            border = NSColor(calibratedRed: 0.32, green: 0.32, blue: 0.32, alpha: 0.8)
-        } else if isHighlighted {
-            background = NSColor(calibratedRed: 0.09, green: 0.3, blue: 0.58, alpha: 0.96)
-            border = NSColor(calibratedRed: 0.4, green: 0.72, blue: 1.0, alpha: 0.95)
-        } else if isHovering {
-            background = NSColor(calibratedRed: 0.1, green: 0.24, blue: 0.42, alpha: 0.94)
-            border = NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.94, alpha: 0.9)
-        } else {
-            background = NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.31, alpha: 0.9)
-            border = NSColor(calibratedRed: 0.3, green: 0.53, blue: 0.8, alpha: 0.84)
-        }
-
-        layer.backgroundColor = background.cgColor
-        layer.borderColor = border.cgColor
-        layer.borderWidth = ArcadeControlStyle.borderWidth
-        layer.cornerRadius = ArcadeControlStyle.cornerRadius
-        layer.masksToBounds = false
-        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
-        layer.shadowRadius = isHovering ? 5 : 3
-        layer.shadowOpacity = isEnabled ? 0.28 : 0
-        layer.shadowOffset = .zero
-
-        updateChevronTint()
-    }
-
-    private func configureChevronIfNeeded() {
-        guard chevronImageView == nil else { return }
-
-        let chevron = NSImageView()
-        chevron.translatesAutoresizingMaskIntoConstraints = false
-        chevron.imageScaling = .scaleProportionallyDown
-        if let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
-            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
-            chevron.image = image.withSymbolConfiguration(config)
-        }
-
-        addSubview(chevron)
-        NSLayoutConstraint.activate([
-            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
-            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
-            chevron.widthAnchor.constraint(equalToConstant: 11),
-            chevron.heightAnchor.constraint(equalToConstant: 11)
-        ])
-
-        chevronImageView = chevron
-        updateChevronTint()
-    }
-
-    private func updateChevronTint() {
-        let tint: NSColor
-        if !isEnabled {
-            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.36)
-        } else if isHighlighted {
-            tint = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 0.92)
-        } else {
-            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.74)
-        }
-
-        chevronImageView?.contentTintColor = tint
-    }
-}
-
-private final class ArcadeVolumeControlView: NSView {
-    private let themeColor: NSColor
-    private var hoverTrackingArea: NSTrackingArea?
-    private var isHovering = false
-
-    let slider: NSSlider = {
-        let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
-        slider.translatesAutoresizingMaskIntoConstraints = false
-        slider.isContinuous = true
-        slider.controlSize = .small
-        slider.allowsTickMarkValuesOnly = false
-        slider.numberOfTickMarks = 0
-        slider.focusRingType = .none
-        return slider
-    }()
-
-    private lazy var valueLabel: NSTextField = {
-        let label = NSTextField(labelWithString: "100%")
-        label.translatesAutoresizingMaskIntoConstraints = false
-        label.alignment = .right
-        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
-        label.setContentCompressionResistancePriority(.required, for: .horizontal)
-        label.setContentHuggingPriority(.required, for: .horizontal)
-        return label
-    }()
-
-    override var intrinsicContentSize: NSSize {
-        return NSSize(width: NSView.noIntrinsicMetric, height: 38)
-    }
-
-    init(themeColor: NSColor) {
-        self.themeColor = themeColor
-        super.init(frame: .zero)
-        commonInit()
-    }
-
-    required init?(coder: NSCoder) {
-        self.themeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
-        super.init(coder: coder)
-        commonInit()
-    }
-
-    func setVolume(_ value: Double) {
-        if abs(slider.doubleValue - value) > 0.0001 {
-            slider.doubleValue = value
-        }
-    }
-
-    func setDisplayText(_ text: String) {
-        valueLabel.stringValue = text
-        updateAppearance()
-    }
-
-    override func updateTrackingAreas() {
-        super.updateTrackingAreas()
-
-        if let hoverTrackingArea {
-            removeTrackingArea(hoverTrackingArea)
-        }
-
-        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
-        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
-        addTrackingArea(area)
-        hoverTrackingArea = area
-    }
-
-    override func mouseEntered(with event: NSEvent) {
-        super.mouseEntered(with: event)
-        isHovering = true
-        updateAppearance()
-    }
-
-    override func mouseExited(with event: NSEvent) {
-        super.mouseExited(with: event)
-        isHovering = false
-        updateAppearance()
-    }
-
-    private func commonInit() {
-        wantsLayer = true
-
-        addSubview(slider)
-        addSubview(valueLabel)
-
-        NSLayoutConstraint.activate([
-            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
-            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
-            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
-            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
-            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
-            valueLabel.widthAnchor.constraint(equalToConstant: 42)
-        ])
-
-        updateAppearance()
-    }
-
-    private func updateAppearance() {
-        guard let layer else { return }
-
-        let background: NSColor
-        let border: NSColor
-
-        if isHovering {
-            background = NSColor(calibratedRed: 0.1, green: 0.24, blue: 0.42, alpha: 0.94)
-            border = NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.94, alpha: 0.9)
-        } else {
-            background = NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.31, alpha: 0.9)
-            border = NSColor(calibratedRed: 0.3, green: 0.53, blue: 0.8, alpha: 0.84)
-        }
-
-        layer.backgroundColor = background.cgColor
-        layer.borderColor = border.cgColor
-        layer.borderWidth = ArcadeControlStyle.borderWidth
-        layer.cornerRadius = ArcadeControlStyle.cornerRadius
-        layer.masksToBounds = false
-        layer.shadowColor = border.withAlphaComponent(0.72).cgColor
-        layer.shadowRadius = isHovering ? 5 : 3
-        layer.shadowOpacity = 0.26
-        layer.shadowOffset = .zero
-
-        valueLabel.textColor = themeColor.withAlphaComponent(0.94)
-    }
-}
-
-private final class ArcadeActionButton: NSButton {
-    override var alignmentRectInsets: NSEdgeInsets {
-        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
-    }
-
-    private var hoverTrackingArea: NSTrackingArea?
-    private var isHovering = false
-    private var displayTitle = ""
-    private var displayImage: NSImage?
-
-    private lazy var iconView: NSImageView = {
-        let view = NSImageView()
-        view.translatesAutoresizingMaskIntoConstraints = false
-        view.imageScaling = .scaleProportionallyDown
-        return view
-    }()
-
-    private lazy var textLabel: NSTextField = {
-        let label = NSTextField(labelWithString: "")
-        label.translatesAutoresizingMaskIntoConstraints = false
-        label.alignment = .center
-        label.lineBreakMode = .byTruncatingTail
-        label.setContentHuggingPriority(.required, for: .horizontal)
-        return label
-    }()
-
-    private lazy var contentStack: NSStackView = {
-        let stack = NSStackView(views: [iconView, textLabel])
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        stack.orientation = .horizontal
-        stack.alignment = .centerY
-        stack.spacing = 6
-        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
-        return stack
-    }()
-
-    override var isHighlighted: Bool {
-        didSet {
-            updateAppearance()
-        }
-    }
-
-    override var isEnabled: Bool {
-        didSet {
-            updateTitleStyle()
-            updateAppearance()
-        }
-    }
-
-    override init(frame frameRect: NSRect) {
-        super.init(frame: frameRect)
-        commonInit()
-    }
-
-    required init?(coder: NSCoder) {
-        super.init(coder: coder)
-        commonInit()
-    }
-
-    func setDisplay(title: String, image: NSImage?) {
-        displayTitle = title
-        displayImage = image
-        updateTitleStyle()
-    }
-
-    private func commonInit() {
-        wantsLayer = true
-        isBordered = false
-        focusRingType = .none
-        imagePosition = .noImage
-        alignment = .center
-        contentTintColor = NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
-        setContentHuggingPriority(.defaultLow, for: .horizontal)
-        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
-        setButtonType(.momentaryPushIn)
-
-        super.title = ""
-        super.image = nil
-
-        addSubview(contentStack)
-        NSLayoutConstraint.activate([
-            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
-            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
-            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
-            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
-            iconView.widthAnchor.constraint(equalToConstant: 14),
-            iconView.heightAnchor.constraint(equalToConstant: 14)
-        ])
-
-        updateTitleStyle()
-        updateAppearance()
-    }
-
-    override func updateTrackingAreas() {
-        super.updateTrackingAreas()
-
-        if let hoverTrackingArea {
-            removeTrackingArea(hoverTrackingArea)
-        }
-
-        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
-        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
-        addTrackingArea(area)
-        hoverTrackingArea = area
-    }
-
-    override func mouseEntered(with event: NSEvent) {
-        super.mouseEntered(with: event)
-        isHovering = true
-        updateAppearance()
-    }
-
-    override func mouseExited(with event: NSEvent) {
-        super.mouseExited(with: event)
-        isHovering = false
-        updateAppearance()
-    }
-
-    private func updateTitleStyle() {
-        let color = isEnabled
-            ? NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
-            : NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.45)
-        textLabel.stringValue = displayTitle
-        textLabel.textColor = color
-        textLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
-
-        iconView.image = displayImage
-        iconView.contentTintColor = color
-        iconView.isHidden = displayImage == nil
-        contentStack.spacing = displayImage == nil ? 0 : 6
-    }
-
-    private func updateAppearance() {
-        guard let layer else { return }
-
-        let background: NSColor
-        let border: NSColor
-
-        if !isEnabled {
-            background = NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.18, alpha: 0.85)
-            border = NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
-        } else if isHighlighted {
-            background = NSColor(calibratedRed: 0.09, green: 0.47, blue: 0.2, alpha: 0.98)
-            border = NSColor(calibratedRed: 0.5, green: 0.92, blue: 0.54, alpha: 0.95)
-        } else if isHovering {
-            background = NSColor(calibratedRed: 0.12, green: 0.39, blue: 0.18, alpha: 0.95)
-            border = NSColor(calibratedRed: 0.46, green: 0.86, blue: 0.5, alpha: 0.9)
-        } else {
-            background = NSColor(calibratedRed: 0.1, green: 0.28, blue: 0.15, alpha: 0.92)
-            border = NSColor(calibratedRed: 0.34, green: 0.72, blue: 0.4, alpha: 0.82)
-        }
-
-        layer.backgroundColor = background.cgColor
-        layer.borderColor = border.cgColor
-        layer.borderWidth = ArcadeControlStyle.borderWidth
-        layer.cornerRadius = ArcadeControlStyle.cornerRadius
-        layer.masksToBounds = false
-        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
-        layer.shadowRadius = isHovering ? 5 : 3
-        layer.shadowOpacity = isEnabled ? 0.28 : 0
-        layer.shadowOffset = .zero
+        HomeStyle.card(bounds, border: accentColor == HomeStyle.green ? HomeStyle.green.withAlphaComponent(0.5) : HomeStyle.border)
     }
 }
 
```

### `Sources/GameState.swift`

```diff
diff --git a/Sources/GameState.swift b/Sources/GameState.swift
--- a/Sources/GameState.swift
+++ b/Sources/GameState.swift
@@ -34,6 +34,8 @@
     let columns: Int
     private(set) var tiles: [BoardTile]
     private(set) var score: Int = 0
+    /// 本局分类计数，随新棋盘清零；成就管理器另外保存跨局累计值。
+    private(set) var clearedByKind: [PieceKind: Int] = [:]
     private(set) var lastResolution: SwapResolution = .invalid
     private let nextKind: () -> PieceKind
 
@@ -99,7 +101,10 @@
             cascadeCount += 1
             longestRun = max(longestRun, runLength)
             // 补位前读取实际消除方块的类型，将每轮连锁合并到本次交换。
-            for index in matches { clearedByKind[tiles[index].kind, default: 0] += 1 }
+            for index in matches {
+                clearedByKind[tiles[index].kind, default: 0] += 1
+                self.clearedByKind[tiles[index].kind, default: 0] += 1
+            }
             refillAfterClearing(matches)
         }
         return SwapResolution(isValidSwap: true, clearedCount: clearedCount, cascadeCount: cascadeCount,
```

### `Sources/AchievementViews.swift`

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -14,11 +14,12 @@
 
     static func progress(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
         let progress = manager.progress(for: definition)
-        if definition.id <= 3, manager.isUnlocked(id: definition.id), progress.current < progress.target {
+        let reached = progress.isTime ? manager.hasTimedResult(for: definition) && progress.current <= progress.target : progress.current >= progress.target
+        if manager.isUnlocked(id: definition.id), !reached {
             return string("achievement.progress.legacy")
         }
         if progress.isTime {
-            guard manager.hasTimedResult(for: definition) else { return string("achievement.progress.no_time") }
+            guard manager.hasTimedResult(for: definition) else { return format("achievement.progress.no_time", progress.target) }
             return format("achievement.progress.time", progress.current, progress.target)
         }
         switch definition.goal {
@@ -176,24 +177,24 @@
     @objc private func badgeTapped(_ sender: NSButton) { onSelect?(sender.tag) }
 }
 
-/// 成就沿用主界面的红色卡片主题，已解锁项目使用状态栏同款浅绿色。
+/// 辅助面板沿用浅色首页的文字、边框及成功状态颜色。
 private enum AchievementPanelStyle {
-    static let accent = NSColor(calibratedRed: 1, green: 0.53, blue: 0.5, alpha: 0.96)
-    static let success = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
-    static let body = NSColor(calibratedRed: 1, green: 0.82, blue: 0.82, alpha: 0.9)
-    static let muted = NSColor(calibratedRed: 0.78, green: 0.71, blue: 0.75, alpha: 1)
-    static let controlFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
+    static let accent = HomeStyle.ink
+    static let success = HomeStyle.green
+    static let body = HomeStyle.ink
+    static let muted = HomeStyle.secondary
+    static let controlFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
 
     static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
         let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
-        NSColor(calibratedRed: selected ? 0.27 : 0.12, green: 0.14, blue: 0.2, alpha: 1).setFill()
+        (selected ? NSColor(calibratedRed: 0.9, green: 0.96, blue: 1, alpha: 1) : NSColor.white).setFill()
         path.fill()
-        accent.withAlphaComponent(selected ? 0.95 : 0.4).setStroke()
+        (selected ? HomeStyle.blue : HomeStyle.border).setStroke()
         path.lineWidth = 1
         path.stroke()
         let attributes: [NSAttributedString.Key: Any] = [
             .font: controlFont,
-            .foregroundColor: selected ? accent : body
+            .foregroundColor: selected ? HomeStyle.blue : body
         ]
         let size = (title as NSString).size(withAttributes: attributes)
         (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
@@ -257,29 +258,17 @@
     override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 10) }
 
     override func draw(_ dirtyRect: NSRect) {
-        let track = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
-        NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1).setFill()
+        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
+        NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
         track.fill()
-        accentColor.withAlphaComponent(0.3).setStroke()
-        track.lineWidth = 1
-        track.stroke()
-        let inner = bounds.insetBy(dx: 3, dy: 3)
-        guard inner.width > 0, inner.height > 0 else { return }
         let fraction = min(1, max(0, (doubleValue - minValue) / max(1, maxValue - minValue)))
-        let filledWidth = inner.width * fraction
-        var x = inner.minX
-        while x < inner.maxX {
-            let width = min(6, inner.maxX - x)
-            accentColor.withAlphaComponent(0.1).setFill()
-            NSBezierPath(rect: NSRect(x: x, y: inner.minY, width: width, height: inner.height)).fill()
-            let activeWidth = min(width, max(0, inner.minX + filledWidth - x))
-            if activeWidth > 0 {
-                accentColor.setFill()
-                NSBezierPath(rect: NSRect(x: x, y: inner.minY, width: activeWidth, height: inner.height)).fill()
-            }
-            x += 9
-        }
-    }
+        if fraction > 0 {
+            accentColor.setFill()
+            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height),
+                         xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
+        }
+    }
+
 }
 
 /// 面板不争夺主窗口焦点，点击筛选时仍保留 Touch Bar 的游戏棋盘。
@@ -309,8 +298,8 @@
         panel.isReleasedWhenClosed = false
         panel.hidesOnDeactivate = true
         panel.minSize = NSSize(width: 480, height: 360)
-        panel.appearance = NSAppearance(named: .darkAqua)
-        panel.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1)
+        panel.appearance = NSAppearance(named: .aqua)
+        panel.backgroundColor = HomeStyle.background
         panel.titlebarAppearsTransparent = true
         panel.contentView = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))
         super.init(window: panel)
@@ -378,7 +367,7 @@
             let group = definitions.filter { $0.category == category }
             guard !group.isEmpty else { continue }
             let label = NSTextField(labelWithString: AchievementText.string("achievement.category.\(category.rawValue)"))
-            label.font = .monospacedSystemFont(ofSize: 12, weight: .heavy)
+            label.font = .systemFont(ofSize: 12, weight: .heavy)
             label.textColor = AchievementPanelStyle.accent
             list.addArrangedSubview(label)
             for definition in group {
@@ -389,7 +378,7 @@
         }
         if definitions.isEmpty {
             let empty = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.empty"))
-            empty.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
+            empty.font = .systemFont(ofSize: 12, weight: .regular)
             empty.textColor = AchievementPanelStyle.body
             list.addArrangedSubview(empty)
         }
@@ -397,7 +386,7 @@
 
     private func buildContent() {
         guard let content = window?.contentView else { return }
-        heading.font = .monospacedSystemFont(ofSize: 16, weight: .heavy)
+        heading.font = .systemFont(ofSize: 16, weight: .heavy)
         heading.textColor = AchievementPanelStyle.accent
         heading.lineBreakMode = .byTruncatingTail
         heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
@@ -473,7 +462,7 @@
         let row = PixelFrameCardView(accentColor: accent)
         row.translatesAutoresizingMaskIntoConstraints = false
         let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
-        name.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
+        name.font = .systemFont(ofSize: 13, weight: .semibold)
         name.textColor = accent
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
         let icon = NSImageView(image: NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil) ?? NSImage())
@@ -485,16 +474,16 @@
         titleRow.orientation = .horizontal
         titleRow.spacing = 6
         let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
-        condition.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
+        condition.font = .systemFont(ofSize: 12, weight: .regular)
         condition.textColor = AchievementPanelStyle.body
         let progress = NSTextField(wrappingLabelWithString: AchievementText.progress(definition, manager: manager))
-        progress.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
+        progress.font = .systemFont(ofSize: 11, weight: .medium)
         progress.textColor = accent
         let status = NSTextField(wrappingLabelWithString: AchievementText.status(definition, manager: manager))
-        status.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
+        status.font = .systemFont(ofSize: 10, weight: .regular)
         status.textColor = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted
         let meter = AchievementProgressIndicator()
-        meter.accentColor = accent
+        meter.accentColor = unlocked ? HomeStyle.green : HomeStyle.yellow
         meter.heightAnchor.constraint(equalToConstant: 10).isActive = true
         meter.style = .bar
         meter.isIndeterminate = false
```

### `Sources/AppDelegate.swift`

```diff
diff --git a/Sources/AppDelegate.swift b/Sources/AppDelegate.swift
--- a/Sources/AppDelegate.swift
+++ b/Sources/AppDelegate.swift
@@ -5,14 +5,17 @@
 
     func applicationDidFinishLaunching(_ notification: Notification) {
         let viewController = GameViewController()
+        let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
         let window = NSWindow(
-            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
+            contentRect: NSRect(x: 0, y: 0, width: min(1180, max(960, available.width - 64)), height: min(800, max(720, available.height - 80))),
             styleMask: [.titled, .closable, .miniaturizable, .resizable],
             backing: .buffered,
             defer: false
         )
         window.center()
         window.title = Localizer.shared.string("window.title")
+        window.appearance = NSAppearance(named: .aqua)
+        window.contentMinSize = NSSize(width: 960, height: 720)
         window.contentViewController = viewController
         window.makeFirstResponder(viewController)
         window.makeKeyAndOrderFront(nil)
```

### `Tests/AchievementLocalizationTests.swift`

```diff
diff --git a/Tests/AchievementLocalizationTests.swift b/Tests/AchievementLocalizationTests.swift
--- a/Tests/AchievementLocalizationTests.swift
+++ b/Tests/AchievementLocalizationTests.swift
@@ -20,7 +20,7 @@
             }
         }
         let english = try XCTUnwrap(tables["en"])
-        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") }
+        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") || $0.hasPrefix("home.") }
         for table in tables.values {
             for key in keys {
                 let value = try XCTUnwrap(table[key], key)
```

### `Tests/GameBoardControllerTests.swift`

```diff
diff --git a/Tests/GameBoardControllerTests.swift b/Tests/GameBoardControllerTests.swift
--- a/Tests/GameBoardControllerTests.swift
+++ b/Tests/GameBoardControllerTests.swift
@@ -66,6 +66,7 @@
                 return [c, d, c][index]
             }
         })
+        controller.startRound()
         controller.performSwap(from: 2, to: 3)
         XCTAssertTrue(manager.isUnlocked(id: 4))
         XCTAssertEqual(progress(20), 0)
```

### `Tests/AchievementsTests.swift`

```diff
diff --git a/Tests/AchievementsTests.swift b/Tests/AchievementsTests.swift
--- a/Tests/AchievementsTests.swift
+++ b/Tests/AchievementsTests.swift
@@ -140,30 +140,27 @@
         XCTAssertEqual(progress(20), 0)
     }
 
-    func testEachScoreAttackTierRequiresItsOwnFinishedRound() {
-        for (minutes, id) in [(1, 10), (2, 11), (3, 12)] {
-            newRound()
-            swap(score: minutes * 300)
+    func testEachFixedScoreAttackThresholdRequiresItsFinishedRound() {
+        for (score, id) in [(300, 10), (600, 11), (900, 12)] {
+            newRound()
+            swap(score: score)
             XCTAssertFalse(manager.isUnlocked(id: id))
-            manager.finishRound(id: round, mode: .scoreAttack(duration: Double(minutes * 60)), score: minutes * 300, elapsed: Double(minutes * 60), at: date)
+            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: score, elapsed: 60, at: date)
             XCTAssertTrue(manager.isUnlocked(id: id))
         }
     }
 
-    func testSpeedRunTiersAndSixtySecondBoundary() {
+    func testFixedSpeedRunTimeChallengesAndSixtySecondBoundary() {
         manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 60.001, at: date)
         XCTAssertTrue(manager.isUnlocked(id: 13))
         XCTAssertFalse(manager.isUnlocked(id: 16))
-        newRound()
-        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 330, elapsed: 60, at: date)
-        XCTAssertTrue(manager.isUnlocked(id: 16))
-        for (target, id) in [(600, 14), (900, 15)] {
-            newRound()
-            manager.finishRound(id: round, mode: .speedRun(targetScore: target), score: target, elapsed: 90, at: date)
+        for (seconds, id) in [(60.0, 16), (45.0, 14), (30.0, 15)] {
+            newRound()
+            manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 330, elapsed: seconds, at: date)
             XCTAssertTrue(manager.isUnlocked(id: id))
         }
         let best = AchievementDefinition.all.first { $0.id == 16 }!
-        XCTAssertEqual(manager.progress(for: best).current, 60)
+        XCTAssertEqual(manager.progress(for: best).current, 30)
     }
 
     func testReloadRetainsMetricsAndTimeButStartsNewStreak() {
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -103,16 +103,16 @@
 "achievement.9.desc" = "单局连续 5 次交换均产生消除，不限操作间隔。";
 "achievement.10.title" = "一分钟热身";
 "achievement.10.desc" = "自然完成 1 分钟竞分，并达到 300 分。";
-"achievement.11.title" = "两分钟专注";
-"achievement.11.desc" = "自然完成 2 分钟竞分，并达到 600 分。";
-"achievement.12.title" = "三分钟巡航";
-"achievement.12.desc" = "自然完成 3 分钟竞分，并达到 900 分。";
+"achievement.11.title" = "火力全开";
+"achievement.11.desc" = "完成 1 分钟竞分，并达到 600 分。";
+"achievement.12.title" = "极限冲分";
+"achievement.12.desc" = "完成 1 分钟竞分，并达到 900 分。";
 "achievement.13.title" = "初见终点";
 "achievement.13.desc" = "完成 300 分竞速。";
 "achievement.14.title" = "加速前进";
-"achievement.14.desc" = "完成 600 分竞速。";
-"achievement.15.title" = "长程冲刺";
-"achievement.15.desc" = "完成 900 分竞速。";
+"achievement.14.desc" = "在 45 秒以内完成 300 分竞速。";
+"achievement.15.title" = "极速冲刺";
+"achievement.15.desc" = "在 30 秒以内完成 300 分竞速。";
 "achievement.16.title" = "分秒必争";
 "achievement.16.desc" = "在 60 秒以内完成 300 分竞速。";
 "achievement.17.title" = "百格起步";
@@ -136,7 +136,7 @@
 "achievement.state.unlocked" = "已解锁";
 "achievement.progress.best" = "历史最佳：%@ / %@";
 "achievement.progress.total" = "累计进度：%@ / %@";
-"achievement.progress.no_time" = "尚未完成 300 分竞速 · 目标 ≤ 60 秒";
+"achievement.progress.no_time" = "尚未完成 300 分竞速 · 目标 ≤ %.0f 秒";
 "achievement.progress.time" = "最佳用时：%.2f 秒 · 目标 ≤ %.0f 秒";
 "achievement.date" = "解锁时间：%@";
 "achievement.toast.single" = "✓ 成就解锁：%@ · 点击查看";
@@ -177,3 +177,27 @@
 "achievement.31.desc" = "全部模式累计消除 1,000 个红色方块。";
 "achievement.32.title" = "红色万格";
 "achievement.32.desc" = "全部模式累计消除 10,000 个红色方块。";
+
+// 浅色探索版首页与固定玩法规则。
+"home.brand" = "消除俄罗斯方块 1";
+"home.game_modes" = "游戏模式";
+"home.hero.free" = "交换一下，\n快乐消除。";
+"home.hero.speed_run" = "争分夺秒，\n冲向终点。";
+"home.hero.score_attack" = "连消不停，\n挑战高分。";
+"home.subtitle.free" = "没有倒计时，按自己的节奏玩。";
+"home.subtitle.speed_run" = "冲到 300 分，与自己的速度较量。";
+"home.subtitle.score_attack" = "用 60 秒，创造这一局的最高分。";
+"home.mode.free" = "自由模式";
+"home.mode.speed_run" = "竞速模式";
+"home.mode.score_attack" = "竞分模式";
+"home.mode_desc.free" = "无时间与目标限制。";
+"home.mode_desc.speed_run" = "达到 300 分即结束。";
+"home.mode_desc.score_attack" = "限时 60 秒，挑战高分。";
+"home.operation_hint" = "拖动交换  ·  三个及以上相连即可消除";
+"home.start" = "开始游戏";
+"home.play_again" = "再来一局";
+"home.session_stats" = "本局实时统计";
+"home.achievement_path" = "成就之路";
+"home.unlocked_count" = "已解锁 %d / %d";
+"home.rules.fixed" = "每个消除方块计 10 分。竞分固定 60 秒，竞速固定 300 分；达到条件后自动结束。切换模式或重新开始会清零本局统计，成就累计进度会保留。";
+"home.records.fixed" = "固定规则：竞分 60 秒 · 竞速 300 分";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -96,16 +96,16 @@
 "achievement.9.desc" = "1 回のプレイで、消去する入れ替えを 5 回連続で行う。操作間隔は問わない。";
 "achievement.10.title" = "1 分の準備運動";
 "achievement.10.desc" = "1 分のスコアアタックを 300 点以上で最後まで完了する。";
-"achievement.11.title" = "2 分の集中";
-"achievement.11.desc" = "2 分のスコアアタックを 600 点以上で最後まで完了する。";
-"achievement.12.title" = "3 分の巡航";
-"achievement.12.desc" = "3 分のスコアアタックを 900 点以上で最後まで完了する。";
+"achievement.11.title" = "全力疾走";
+"achievement.11.desc" = "1 分のスコアアタックを 600 点以上で完了する。";
+"achievement.12.title" = "限界突破";
+"achievement.12.desc" = "1 分のスコアアタックを 900 点以上で完了する。";
 "achievement.13.title" = "初めてのゴール";
 "achievement.13.desc" = "300 点のスピードランを完了する。";
 "achievement.14.title" = "加速する指先";
-"achievement.14.desc" = "600 点のスピードランを完了する。";
-"achievement.15.title" = "長いスプリント";
-"achievement.15.desc" = "900 点のスピードランを完了する。";
+"achievement.14.desc" = "300 点のスピードランを 45 秒以内に完了する。";
+"achievement.15.title" = "電光石火";
+"achievement.15.desc" = "300 点のスピードランを 30 秒以内に完了する。";
 "achievement.16.title" = "一秒を争え";
 "achievement.16.desc" = "300 点のスピードランを 60 秒以内に完了する。";
 "achievement.17.title" = "百個からの一歩";
@@ -129,7 +129,7 @@
 "achievement.state.unlocked" = "達成済み";
 "achievement.progress.best" = "自己ベスト：%@ / %@";
 "achievement.progress.total" = "累計：%@ / %@";
-"achievement.progress.no_time" = "300 点の完走記録なし · 目標 60 秒以内";
+"achievement.progress.no_time" = "300 点の完走記録なし · 目標 %.0f 秒以内";
 "achievement.progress.time" = "最速：%.2f 秒 · 目標 %.0f 秒以内";
 "achievement.date" = "達成日時：%@";
 "achievement.toast.single" = "✓ 実績達成：%@ · 詳細";
@@ -170,3 +170,27 @@
 "achievement.31.desc" = "すべてのモードで、赤色のブロックを合計 1,000 個消す。";
 "achievement.32.title" = "赤色・10,000個";
 "achievement.32.desc" = "すべてのモードで、赤色のブロックを合計 10,000 個消す。";
+
+// 浅色探索版首页与固定玩法规则。
+"home.brand" = "消去テトリス 1";
+"home.game_modes" = "ゲームモード";
+"home.hero.free" = "入れ替えて、\n楽しく消そう。";
+"home.hero.speed_run" = "一秒を争い、\nゴールへ。";
+"home.hero.score_attack" = "連鎖をつなぎ、\n最高得点へ。";
+"home.subtitle.free" = "時間を気にせず、自分のペースで。";
+"home.subtitle.speed_run" = "300 点まで、最速の一局に挑戦。";
+"home.subtitle.score_attack" = "60 秒で、最高得点を目指そう。";
+"home.mode.free" = "フリーモード";
+"home.mode.speed_run" = "スピードラン";
+"home.mode.score_attack" = "スコアアタック";
+"home.mode_desc.free" = "時間・目標点数の制限なし。";
+"home.mode_desc.speed_run" = "300 点に到達すると終了。";
+"home.mode_desc.score_attack" = "制限時間 60 秒で高得点へ。";
+"home.operation_hint" = "ドラッグで入れ替え  ·  3 個以上で消去";
+"home.start" = "ゲーム開始";
+"home.play_again" = "もう一度";
+"home.session_stats" = "この一局の記録";
+"home.achievement_path" = "実績への道";
+"home.unlocked_count" = "達成 %d / %d";
+"home.rules.fixed" = "1 個消すと 10 点。スコアアタックは 60 秒、スピードランは 300 点で終了。モード変更や再開で一局の記録はリセットされ、実績の累計は保存されます。";
+"home.records.fixed" = "固定ルール：60 秒スコアアタック · 300 点スピードラン";
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -103,16 +103,16 @@
 "achievement.9.desc" = "Make 5 consecutive swaps that each clear tiles in one round, with no time limit between swaps.";
 "achievement.10.title" = "One-Minute Warmup";
 "achievement.10.desc" = "Finish a 1-minute Score Attack with at least 300 points.";
-"achievement.11.title" = "Two-Minute Focus";
-"achievement.11.desc" = "Finish a 2-minute Score Attack with at least 600 points.";
-"achievement.12.title" = "Three-Minute Cruise";
-"achievement.12.desc" = "Finish a 3-minute Score Attack with at least 900 points.";
+"achievement.11.title" = "Full Throttle";
+"achievement.11.desc" = "Finish a 1-minute Score Attack with at least 600 points.";
+"achievement.12.title" = "Score Limit Break";
+"achievement.12.desc" = "Finish a 1-minute Score Attack with at least 900 points.";
 "achievement.13.title" = "First Finish Line";
 "achievement.13.desc" = "Complete a 300-point Speed Run.";
 "achievement.14.title" = "Picking Up Speed";
-"achievement.14.desc" = "Complete a 600-point Speed Run.";
-"achievement.15.title" = "The Long Sprint";
-"achievement.15.desc" = "Complete a 900-point Speed Run.";
+"achievement.14.desc" = "Complete a 300-point Speed Run in 45 seconds or less.";
+"achievement.15.title" = "Lightning Sprint";
+"achievement.15.desc" = "Complete a 300-point Speed Run in 30 seconds or less.";
 "achievement.16.title" = "Every Second Counts";
 "achievement.16.desc" = "Complete a 300-point Speed Run in 60 seconds or less.";
 "achievement.17.title" = "A Hundred Tiles";
@@ -136,7 +136,7 @@
 "achievement.state.unlocked" = "Unlocked";
 "achievement.progress.best" = "Personal best: %@ / %@";
 "achievement.progress.total" = "Total progress: %@ / %@";
-"achievement.progress.no_time" = "No 300-point finish yet · Goal ≤ 60 seconds";
+"achievement.progress.no_time" = "No 300-point finish yet · Goal ≤ %.0f seconds";
 "achievement.progress.time" = "Best time: %.2f s · Goal ≤ %.0f s";
 "achievement.date" = "Unlocked: %@";
 "achievement.toast.single" = "✓ Achievement unlocked: %@ · View";
@@ -177,3 +177,27 @@
 "achievement.31.desc" = "Clear 1,000 red tiles across all modes.";
 "achievement.32.title" = "Red · 10,000";
 "achievement.32.desc" = "Clear 10,000 red tiles across all modes.";
+
+// 浅色探索版首页与固定玩法规则。
+"home.brand" = "Eliminate Teris 1";
+"home.game_modes" = "Game modes";
+"home.hero.free" = "Swap a little.\nSmile a lot.";
+"home.hero.speed_run" = "Beat the clock.\nFind your flow.";
+"home.hero.score_attack" = "Keep it going.\nChase your best.";
+"home.subtitle.free" = "No countdown. Play at your own pace.";
+"home.subtitle.speed_run" = "Reach 300 points as quickly as you can.";
+"home.subtitle.score_attack" = "One minute. Make every swap count.";
+"home.mode.free" = "Free play";
+"home.mode.speed_run" = "Speed run";
+"home.mode.score_attack" = "Score attack";
+"home.mode_desc.free" = "No timer or target score.";
+"home.mode_desc.speed_run" = "Finish by reaching 300 points.";
+"home.mode_desc.score_attack" = "60 seconds to chase a high score.";
+"home.operation_hint" = "Drag to swap  ·  Match three or more to clear";
+"home.start" = "Start playing";
+"home.play_again" = "Play again";
+"home.session_stats" = "This round, live";
+"home.achievement_path" = "Achievement journey";
+"home.unlocked_count" = "Unlocked %d / %d";
+"home.rules.fixed" = "Each cleared tile earns 10 points. Score Attack lasts 60 seconds; Speed Run ends at 300 points. Switching modes or restarting clears this round’s counters. Lifetime achievement progress is saved.";
+"home.records.fixed" = "Fixed rules: 60-second Score Attack · 300-point Speed Run";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -96,16 +96,16 @@
 "achievement.9.desc" = "한 판에서 블록을 제거하는 교환을 5회 연속 수행하세요. 교환 사이 시간 제한은 없습니다.";
 "achievement.10.title" = "1분 준비 운동";
 "achievement.10.desc" = "1분 점수 도전을 300점 이상으로 끝까지 완료하세요.";
-"achievement.11.title" = "2분 집중";
-"achievement.11.desc" = "2분 점수 도전을 600점 이상으로 끝까지 완료하세요.";
-"achievement.12.title" = "3분 순항";
-"achievement.12.desc" = "3분 점수 도전을 900점 이상으로 끝까지 완료하세요.";
+"achievement.11.title" = "전력 질주";
+"achievement.11.desc" = "1분 점수 도전을 600점 이상으로 완료하세요.";
+"achievement.12.title" = "한계 돌파";
+"achievement.12.desc" = "1분 점수 도전을 900점 이상으로 완료하세요.";
 "achievement.13.title" = "첫 결승선";
 "achievement.13.desc" = "300점 스피드런을 완료하세요.";
 "achievement.14.title" = "속도를 높여";
-"achievement.14.desc" = "600점 스피드런을 완료하세요.";
-"achievement.15.title" = "긴 전력 질주";
-"achievement.15.desc" = "900점 스피드런을 완료하세요.";
+"achievement.14.desc" = "300점 스피드런을 45초 이내에 완료하세요.";
+"achievement.15.title" = "번개 질주";
+"achievement.15.desc" = "300점 스피드런을 30초 이내에 완료하세요.";
 "achievement.16.title" = "매초가 소중해";
 "achievement.16.desc" = "300점 스피드런을 60초 이내에 완료하세요.";
 "achievement.17.title" = "백 칸의 시작";
@@ -129,7 +129,7 @@
 "achievement.state.unlocked" = "달성";
 "achievement.progress.best" = "최고 기록: %@ / %@";
 "achievement.progress.total" = "누적 진행: %@ / %@";
-"achievement.progress.no_time" = "300점 완주 기록 없음 · 목표 60초 이내";
+"achievement.progress.no_time" = "300점 완주 기록 없음 · 목표 %.0f초 이내";
 "achievement.progress.time" = "최고 시간: %.2f초 · 목표 %.0f초 이내";
 "achievement.date" = "달성 시간: %@";
 "achievement.toast.single" = "✓ 업적 달성: %@ · 보기";
@@ -170,3 +170,27 @@
 "achievement.31.desc" = "모든 모드에서 빨간색 블록을 누적 1,000개 제거하세요.";
 "achievement.32.title" = "빨간색 · 10,000개";
 "achievement.32.desc" = "모든 모드에서 빨간색 블록을 누적 10,000개 제거하세요.";
+
+// 浅色探索版首页与固定玩法规则。
+"home.brand" = "블록 제거 테트리스 1";
+"home.game_modes" = "게임 모드";
+"home.hero.free" = "가볍게 바꾸고,\n즐겁게 지워요.";
+"home.hero.speed_run" = "매초를 아끼며,\n결승선까지.";
+"home.hero.score_attack" = "연쇄를 이어,\n최고 점수에.";
+"home.subtitle.free" = "시간에 쫓기지 않고, 내 속도로 즐겨요.";
+"home.subtitle.speed_run" = "300점에 도달하는 가장 빠른 도전.";
+"home.subtitle.score_attack" = "60초 동안, 최고의 점수를 만들어 보세요.";
+"home.mode.free" = "자유 모드";
+"home.mode.speed_run" = "스피드런";
+"home.mode.score_attack" = "점수 도전";
+"home.mode_desc.free" = "시간과 목표 점수 제한 없음.";
+"home.mode_desc.speed_run" = "300점에 도달하면 종료.";
+"home.mode_desc.score_attack" = "60초 동안 최고 점수에 도전.";
+"home.operation_hint" = "드래그로 교환  ·  3개 이상 연결하면 제거";
+"home.start" = "게임 시작";
+"home.play_again" = "다시 한 판";
+"home.session_stats" = "현재 판 실시간 통계";
+"home.achievement_path" = "업적의 여정";
+"home.unlocked_count" = "달성 %d / %d";
+"home.rules.fixed" = "블록 하나당 10점입니다. 점수 도전은 60초, 스피드런은 300점에 도달하면 끝납니다. 모드 변경이나 재시작 시 현재 판의 통계는 초기화되며 업적의 누적 진행은 유지됩니다.";
+"home.records.fixed" = "고정 규칙: 60초 점수 도전 · 300점 스피드런";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -96,16 +96,16 @@
 "achievement.9.desc" = "Сделайте 5 обменов с удалением подряд за одну игру. Время между обменами не ограничено.";
 "achievement.10.title" = "Минутная разминка";
 "achievement.10.desc" = "Завершите минутную игру на очки, набрав не менее 300 очков.";
-"achievement.11.title" = "Две минуты внимания";
-"achievement.11.desc" = "Завершите двухминутную игру на очки, набрав не менее 600 очков.";
-"achievement.12.title" = "Три минуты полёта";
-"achievement.12.desc" = "Завершите трёхминутную игру на очки, набрав не менее 900 очков.";
+"achievement.11.title" = "Полный газ";
+"achievement.11.desc" = "Завершите минутную игру на очки с результатом не менее 600.";
+"achievement.12.title" = "За пределами рекорда";
+"achievement.12.desc" = "Завершите минутную игру на очки с результатом не менее 900.";
 "achievement.13.title" = "Первый финиш";
 "achievement.13.desc" = "Завершите игру на скорость до 300 очков.";
 "achievement.14.title" = "Набирая скорость";
-"achievement.14.desc" = "Завершите игру на скорость до 600 очков.";
-"achievement.15.title" = "Длинный спринт";
-"achievement.15.desc" = "Завершите игру на скорость до 900 очков.";
+"achievement.14.desc" = "Завершите игру на скорость до 300 очков за 45 секунд или быстрее.";
+"achievement.15.title" = "Молниеносный спринт";
+"achievement.15.desc" = "Завершите игру на скорость до 300 очков за 30 секунд или быстрее.";
 "achievement.16.title" = "Каждая секунда важна";
 "achievement.16.desc" = "Завершите игру на скорость до 300 очков за 60 секунд или быстрее.";
 "achievement.17.title" = "Первая сотня";
@@ -129,7 +129,7 @@
 "achievement.state.unlocked" = "Открыто";
 "achievement.progress.best" = "Личный рекорд: %@ / %@";
 "achievement.progress.total" = "Общий прогресс: %@ / %@";
-"achievement.progress.no_time" = "Нет финиша на 300 очков · Цель ≤ 60 секунд";
+"achievement.progress.no_time" = "Нет финиша на 300 очков · Цель ≤ %.0f секунд";
 "achievement.progress.time" = "Лучшее время: %.2f с · Цель ≤ %.0f с";
 "achievement.date" = "Открыто: %@";
 "achievement.toast.single" = "✓ Достижение: %@ · Подробнее";
@@ -170,3 +170,27 @@
 "achievement.31.desc" = "Удалите 1,000 красных блоков во всех режимах.";
 "achievement.32.title" = "Красные · 10,000";
 "achievement.32.desc" = "Удалите 10,000 красных блоков во всех режимах.";
+
+// 浅色探索版首页与固定玩法规则。
+"home.brand" = "Тетрис на Touch Bar 1";
+"home.game_modes" = "Режим игры";
+"home.hero.free" = "Меняй блоки.\nИграй с радостью.";
+"home.hero.speed_run" = "Каждая секунда.\nВперёд к финишу.";
+"home.hero.score_attack" = "Продолжай серию.\nПобей рекорд.";
+"home.subtitle.free" = "Без таймера. Играй в своём ритме.";
+"home.subtitle.speed_run" = "Набери 300 очков как можно быстрее.";
+"home.subtitle.score_attack" = "Одна минута, чтобы набрать максимум очков.";
+"home.mode.free" = "Свободная игра";
+"home.mode.speed_run" = "На скорость";
+"home.mode.score_attack" = "На очки";
+"home.mode_desc.free" = "Без таймера и цели по очкам.";
+"home.mode_desc.speed_run" = "Финиш при достижении 300 очков.";
+"home.mode_desc.score_attack" = "60 секунд для лучшего результата.";
+"home.operation_hint" = "Перетаскивай блоки  ·  Три в ряд — и готово";
+"home.start" = "Начать игру";
+"home.play_again" = "Играть ещё";
+"home.session_stats" = "Текущая игра";
+"home.achievement_path" = "Путь достижений";
+"home.unlocked_count" = "Открыто %d / %d";
+"home.rules.fixed" = "Каждый удалённый блок даёт 10 очков. Игра на очки длится 60 секунд; игра на скорость завершается при 300 очках. Смена режима или перезапуск обнуляет статистику игры, но сохраняет общий прогресс достижений.";
+"home.records.fixed" = "Правила: 60 секунд на очки · 300 очков на скорость";
```

### `Sources/HomeDashboardView.swift`

```diff
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
--- /dev/null
+++ b/Sources/HomeDashboardView.swift
@@ -0,0 +1,328 @@
+import Cocoa
+
+/// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
+class HomeButton: NSButton {
+    var primary = false
+    var symbolName: String?
+    var onClick: (() -> Void)?
+    private var tracking: NSTrackingArea?
+    private(set) var hovering = false
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        isBordered = false
+        setButtonType(.momentaryPushIn)
+        target = self
+        action = #selector(clicked)
+    }
+    required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override var isHighlighted: Bool { didSet { needsDisplay = true } }
+    override var focusRingMaskBounds: NSRect { bounds }
+    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill() }
+    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
+
+    override func updateTrackingAreas() {
+        super.updateTrackingAreas()
+        if let tracking { removeTrackingArea(tracking) }
+        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
+        addTrackingArea(area)
+        tracking = area
+    }
+    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
+    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
+
+    override func draw(_ dirtyRect: NSRect) {
+        if primary {
+            let color = isHighlighted ? (HomeStyle.yellow.shadow(withLevel: 0.08) ?? HomeStyle.yellow) : HomeStyle.yellow
+            HomeStyle.card(bounds, fill: color, border: color, radius: 9)
+        } else if hovering || isHighlighted {
+            HomeStyle.card(bounds, fill: NSColor.white.withAlphaComponent(0.6), border: HomeStyle.border.withAlphaComponent(0.4), radius: 7)
+        }
+        let size: CGFloat = primary ? 23 : 14
+        let font = NSFont.systemFont(ofSize: size, weight: primary ? .heavy : .semibold)
+        let width = (title as NSString).size(withAttributes: [.font: font]).width
+        let icon: CGFloat = symbolName == nil ? 0 : (primary ? 24 : 16)
+        let x = (bounds.width - width - (icon > 0 ? icon + 10 : 0)) / 2
+        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2, width: icon, height: icon)) }
+        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65, width: width + 2, height: size * 1.5),
+                       size: size, weight: primary ? .heavy : .semibold)
+    }
+    @objc private func clicked() { onClick?() }
+}
+
+final class HomeModeButton: HomeButton {
+    let mode: HomeGameMode
+    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
+    init(mode: HomeGameMode) {
+        self.mode = mode
+        super.init(frame: .zero)
+        setAccessibilityRole(.radioButton)
+    }
+    required init?(coder: NSCoder) { nil }
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.card(bounds, fill: selected ? NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 1) : .white.withAlphaComponent(0.75),
+                       border: selected ? HomeStyle.blue : hovering ? HomeStyle.blue.withAlphaComponent(0.4) : HomeStyle.border)
+        let check = NSRect(x: 18, y: bounds.midY - 15, width: 30, height: 30)
+        if selected {
+            HomeStyle.symbol("checkmark.circle.fill", in: check, color: HomeStyle.blue)
+        } else {
+            HomeStyle.muted.withAlphaComponent(0.65).setStroke()
+            let circle = NSBezierPath(ovalIn: check.insetBy(dx: 1, dy: 1)); circle.lineWidth = 2; circle.stroke()
+        }
+        HomeStyle.symbol(mode.symbol, in: NSRect(x: 66, y: bounds.midY - 19, width: 38, height: 38))
+        let y = max(9, (bounds.height - 48) / 2)
+        HomeStyle.text(AchievementText.string("home.mode.\(mode.key)"), in: NSRect(x: 117, y: y, width: bounds.width - 130, height: 27), size: 20, weight: .bold)
+        HomeStyle.text(AchievementText.string("home.mode_desc.\(mode.key)"), in: NSRect(x: 117, y: y + 29, width: bounds.width - 130, height: 20), size: 13, color: HomeStyle.secondary)
+    }
+}
+
+final class HomeHeroView: NSView {
+    private var phase: CGFloat = 0
+    private var timer: Timer?
+    override var isFlipped: Bool { true }
+    deinit { timer?.invalidate() }
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        timer?.invalidate(); timer = nil
+        guard window != nil else { return }
+        let timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
+            guard let self else { return }
+            self.phase += 0.06; self.needsDisplay = true
+        }
+        RunLoop.main.add(timer, forMode: .common)
+        self.timer = timer
+    }
+    override func draw(_ dirtyRect: NSRect) {
+        let centers: [CGFloat] = [0.105, 0.335, 0.665, 0.895]
+        for (index, kind) in PieceKind.allCases.enumerated() {
+            let float = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : sin(phase + CGFloat(index)) * 3
+            let width = min(112, bounds.width * 0.19)
+            let rect = NSRect(x: bounds.width * centers[index] - width / 2, y: bounds.midY - width / 3 + float,
+                              width: width, height: width * 2 / 3)
+            HomeStyle.piece(kind, in: rect)
+            kind.color.withAlphaComponent(0.85).setStroke()
+            let rays = NSBezierPath(); rays.lineWidth = 5; rays.lineCapStyle = .round
+            let x = index == 0 ? rect.minX + 4 : rect.maxX - 5
+            rays.move(to: NSPoint(x: x, y: rect.minY - 10)); rays.line(to: NSPoint(x: x + (index == 0 ? -9 : 9), y: rect.minY - 22))
+            rays.move(to: NSPoint(x: x + 9, y: rect.minY - 13)); rays.line(to: NSPoint(x: x + 12, y: rect.minY - 29))
+            rays.stroke()
+        }
+        HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: bounds.midX - 24, y: bounds.midY - 16, width: 48, height: 32), color: HomeStyle.secondary)
+    }
+}
+
+/// 当前棋盘的实时统计，不读取跨局成就数量。
+final class HomeSessionStatsView: NSView {
+    var snapshot: GameSnapshot? { didSet { needsDisplay = true; updateAccessibility() } }
+    override var isFlipped: Bool { true }
+    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityElement(true); setAccessibilityRole(.group) }
+    required init?(coder: NSCoder) { nil }
+    private func updateAccessibility() {
+        let total = snapshot?.totalCleared ?? 0
+        let pieces = PieceKind.allCases.map { kind in
+            AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), String(snapshot?.clearedByKind[kind, default: 0] ?? 0))
+        }
+        setAccessibilityLabel(([AchievementText.string("home.session_stats") + ": \(total)"] + pieces).joined(separator: "; "))
+    }
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.card(bounds)
+        let dividerX = bounds.width * 0.38
+        HomeStyle.text(AchievementText.string("banner.total_cleared"), in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: 20, weight: .bold)
+        let totalText = "\(snapshot?.totalCleared ?? 0)"
+        var totalSize: CGFloat = 58
+        while (totalText as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: totalSize, weight: .heavy)]).width > dividerX - 27, totalSize > 24 { totalSize -= 2 }
+        HomeStyle.text(totalText, in: NSRect(x: 21, y: 47, width: dividerX - 27, height: 70), size: totalSize, weight: .heavy)
+        HomeStyle.text(AchievementText.string("home.session_stats"), in: NSRect(x: 23, y: bounds.height - 29, width: dividerX - 27, height: 18), size: 11, color: HomeStyle.muted)
+        HomeStyle.border.setStroke()
+        let divider = NSBezierPath(); divider.move(to: NSPoint(x: dividerX, y: 24)); divider.line(to: NSPoint(x: dividerX, y: bounds.height - 24)); divider.stroke()
+        let slot = (bounds.width - dividerX - 20) / 2
+        for (index, kind) in PieceKind.allCases.enumerated() {
+            let x = dividerX + 14 + CGFloat(index % 2) * slot
+            let y = CGFloat(index / 2) * 55 + 35
+            HomeStyle.piece(kind, in: NSRect(x: x, y: y, width: 43, height: 29), shadow: false)
+            let text = "\(snapshot?.clearedByKind[kind, default: 0] ?? 0)"
+            let numberWidth = max(20, slot - 55)
+            var numberSize: CGFloat = 20
+            while (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: numberSize, weight: .semibold)]).width > numberWidth, numberSize > 10 { numberSize -= 1 }
+            HomeStyle.text(text, in: NSRect(x: x + 53, y: y + 2, width: numberWidth, height: 29), size: numberSize, weight: .semibold)
+        }
+    }
+}
+
+private final class HomeAchievementButton: HomeButton {
+    var definition: AchievementDefinition?
+    var unlocked = false
+    override func draw(_ dirtyRect: NSRect) {
+        guard let definition else { return }
+        HomeStyle.card(bounds)
+        let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
+        HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
+        let names = [1: "hand.tap", 2: "music.note", 3: "flag", 4: "sparkles", 7: "link"]
+        HomeStyle.symbol(names[definition.id] ?? "rosette", in: NSRect(x: 45, y: bounds.midY - 15, width: 30, height: 30), color: unlocked ? HomeStyle.ink : HomeStyle.muted)
+        HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: 89, y: bounds.midY - 9, width: bounds.width - 98, height: 22), size: 13, weight: .semibold,
+                       color: unlocked ? HomeStyle.ink : HomeStyle.muted)
+    }
+}
+
+final class HomeDashboardView: NSView {
+    var onStart: (() -> Void)?
+    var onMode: ((HomeGameMode) -> Void)?
+    var onNavigate: ((String) -> Void)?
+    var onAchievement: ((Int?) -> Void)?
+    let stats = HomeSessionStatsView(frame: .zero)
+    let startButton = HomeButton(frame: .zero)
+    private let heading = NSTextField(wrappingLabelWithString: "")
+    private let subtitle = NSTextField(wrappingLabelWithString: "")
+    private let hint = NSTextField(wrappingLabelWithString: "")
+    private let hero = HomeHeroView()
+    private let records = HomeButton(frame: .zero), rules = HomeButton(frame: .zero), settings = HomeButton(frame: .zero)
+    private let all = HomeButton(frame: .zero)
+    private var modes: [HomeModeButton] = []
+    private var badges: [HomeAchievementButton] = []
+    private var selectedMode: HomeGameMode = .free
+    private var unlockedCount = 0
+
+    override var isFlipped: Bool { true }
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        appearance = NSAppearance(named: .aqua)
+        for label in [heading, subtitle, hint] { label.isSelectable = false; label.drawsBackground = false }
+        heading.textColor = HomeStyle.ink
+        subtitle.textColor = HomeStyle.muted
+        subtitle.font = .systemFont(ofSize: 21, weight: .semibold)
+        hint.textColor = HomeStyle.secondary
+        hint.font = .systemFont(ofSize: 14, weight: .medium)
+        hint.alignment = .center
+        [heading, subtitle, hint, hero, stats, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        startButton.primary = true; startButton.symbolName = "play.fill"
+        startButton.onClick = { [weak self] in self?.onStart?() }
+        for (button, key) in [(records, "records"), (rules, "rules"), (settings, "settings")] {
+            button.onClick = { [weak self] in self?.onNavigate?(key) }
+        }
+        all.onClick = { [weak self] in self?.onAchievement?(nil) }
+        for mode in HomeGameMode.allCases {
+            let button = HomeModeButton(mode: mode)
+            button.onClick = { [weak self] in self?.onMode?(mode) }
+            addSubview(button); modes.append(button)
+        }
+        for _ in 0..<5 {
+            let button = HomeAchievementButton(frame: .zero)
+            button.onClick = { [weak self, weak button] in self?.onAchievement?(button?.definition?.id) }
+            addSubview(button); badges.append(button)
+        }
+    }
+    required init?(coder: NSCoder) { nil }
+
+    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager) {
+        selectedMode = mode
+        stats.snapshot = snapshot
+        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
+        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
+        if snapshot.isFinished {
+            hint.stringValue = mode == .speedRun
+                ? AchievementText.format("result.speed_run_finished", Self.clock(snapshot.elapsedTime))
+                : AchievementText.format("result.score_attack_finished", snapshot.score)
+        } else if snapshot.isRunning, mode != .free {
+            hint.stringValue = mode == .scoreAttack
+                ? AchievementText.format("hud.score_attack", snapshot.score, Self.clock(snapshot.remainingTime ?? 0))
+                : AchievementText.format("hud.speed_run", snapshot.score, HomeGameMode.speedRunTarget, Self.clock(snapshot.elapsedTime))
+        } else { hint.stringValue = AchievementText.string("home.operation_hint") }
+        startButton.title = AchievementText.string(snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
+        startButton.setAccessibilityLabel(startButton.title)
+        records.title = AchievementText.string("panel.records")
+        rules.title = AchievementText.string("panel.rules")
+        settings.title = AchievementText.string("panel.settings")
+        all.title = AchievementText.string("achievement.view_all") + "  →"
+        for button in modes {
+            button.selected = button.mode == mode
+            button.setAccessibilityLabel(AchievementText.string("home.mode.\(button.mode.key)") + ", " + AchievementText.string("home.mode_desc.\(button.mode.key)"))
+        }
+        unlockedCount = manager.unlockedIDs().count
+        let definitions = AchievementDefinition.all.sorted {
+            let a = manager.isUnlocked(id: $0.id), b = manager.isUnlocked(id: $1.id)
+            return a == b ? $0.id < $1.id : a
+        }
+        for (button, definition) in zip(badges, definitions) {
+            button.definition = definition; button.unlocked = manager.isUnlocked(id: definition.id)
+            button.toolTip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
+            button.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
+            button.needsDisplay = true
+        }
+        needsLayout = true; needsDisplay = true
+        [startButton, records, rules, settings, all].forEach { $0.needsDisplay = true }
+    }
+
+    override func layout() {
+        super.layout()
+        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
+        let rightWidth = max(330, min(440, bounds.width * 0.34))
+        let rightX = bounds.width - margin - rightWidth
+        let leftWidth = rightX - margin - 32
+        let footerY = bounds.height - 144
+        let top: CGFloat = 96
+        let bodyHeight = footerY - top - 24
+        let modeHeight = bodyHeight - 172
+        heading.font = .systemFont(ofSize: min(68, max(48, leftWidth * 0.1)), weight: .heavy)
+        heading.preferredMaxLayoutWidth = leftWidth
+        heading.frame = NSRect(x: margin, y: top + 30, width: leftWidth, height: bodyHeight * 0.33)
+        subtitle.preferredMaxLayoutWidth = leftWidth
+        subtitle.frame = NSRect(x: margin, y: top + bodyHeight * 0.34, width: leftWidth, height: 56)
+        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.47, width: leftWidth - 24, height: 125)
+        startButton.frame = NSRect(x: margin + (leftWidth - 280) / 2, y: footerY - 82, width: 280, height: 54)
+        hint.preferredMaxLayoutWidth = leftWidth
+        hint.frame = NSRect(x: margin, y: startButton.frame.minY - 43, width: leftWidth, height: 38)
+        let rowHeight = (modeHeight - 104) / 3
+        for (index, button) in modes.enumerated() {
+            button.frame = NSRect(x: rightX + 20, y: top + 68 + CGFloat(index) * (rowHeight + 12), width: rightWidth - 40, height: rowHeight)
+        }
+        stats.frame = NSRect(x: rightX, y: top + modeHeight + 16, width: rightWidth, height: 156)
+        var navX = bounds.width - margin
+        for button in [settings, rules, records] {
+            let width = max(84, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width + 24)
+            navX -= width
+            button.frame = NSRect(x: navX, y: 19, width: width, height: 36)
+            navX -= 8
+        }
+        all.frame = NSRect(x: bounds.width - margin - 120, y: footerY + 8, width: 120, height: 32)
+        let badgeWidth = (bounds.width - margin * 2 - 12 * 4) / 5
+        for (index, badge) in badges.enumerated() { badge.frame = NSRect(x: margin + CGFloat(index) * (badgeWidth + 12), y: footerY + 52, width: badgeWidth, height: 54) }
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.background.setFill(); bounds.fill()
+        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
+        let rightWidth = max(330, min(440, bounds.width * 0.34))
+        let rightX = bounds.width - margin - rightWidth
+        let footerY = bounds.height - 144
+        let bodyHeight = footerY - 120
+        HomeStyle.card(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172))
+        // 低透明度装饰方块呼应四种颜色，避免盖住正文和交互区域。
+        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), footerY - 60, HomeStyle.yellow)] {
+            color.withAlphaComponent(0.10).setFill()
+            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 25, height: 25), xRadius: 5, yRadius: 5).fill()
+        }
+        for (index, color) in [NSColor.systemOrange, .systemBlue, .systemGreen, .systemRed].enumerated() {
+            color.setFill()
+            NSBezierPath(roundedRect: NSRect(x: margin + CGFloat(index % 2) * 16, y: 20 + CGFloat(index / 2) * 16, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
+        }
+        HomeStyle.text(AchievementText.string("home.brand"), in: NSRect(x: margin + 47, y: 18, width: 360, height: 38), size: 26, weight: .heavy)
+        HomeStyle.text(AchievementText.string("home.game_modes"), in: NSRect(x: rightX + 22, y: 114, width: rightWidth - 44, height: 36), size: 27, weight: .heavy)
+        HomeStyle.border.withAlphaComponent(0.7).setStroke()
+        for y in [CGFloat(70), footerY] {
+            let line = NSBezierPath(); line.move(to: NSPoint(x: y == 70 ? 0 : margin, y: y)); line.line(to: NSPoint(x: y == 70 ? bounds.width : bounds.width - margin, y: y)); line.stroke()
+        }
+        HomeStyle.text(AchievementText.string("home.achievement_path"), in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: 21, weight: .bold)
+        HomeStyle.text(AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count), in: NSRect(x: margin + 145, y: footerY + 20, width: 140, height: 23), size: 14, weight: .semibold)
+        let meter = NSRect(x: margin + 292, y: footerY + 23, width: min(230, max(100, bounds.width - 850)), height: 12)
+        NSColor(calibratedWhite: 0.9, alpha: 1).setFill(); NSBezierPath(roundedRect: meter, xRadius: 6, yRadius: 6).fill()
+        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
+        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: NSRect(x: meter.minX, y: meter.minY, width: max(0, meter.width * ratio), height: meter.height), xRadius: 6, yRadius: 6).fill()
+        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: footerY + 20, width: 60, height: 22), size: 11, color: HomeStyle.secondary)
+    }
+
+    private static func clock(_ interval: TimeInterval) -> String {
+        let value = max(0, Int(interval))
+        return String(format: "%02d:%02d", value / 60, value % 60)
+    }
+}
```

### `Sources/HomeUtilityPanel.swift`

```diff
diff --git a/Sources/HomeUtilityPanel.swift b/Sources/HomeUtilityPanel.swift
--- /dev/null
+++ b/Sources/HomeUtilityPanel.swift
@@ -0,0 +1,113 @@
+import Cocoa
+
+private final class HomeUtilityBackgroundView: NSView {
+    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
+}
+
+private final class HomeAuxiliaryWindow: NSPanel {
+    override var canBecomeKey: Bool { false }
+    override var canBecomeMain: Bool { false }
+}
+
+/// 顶部导航的辅助面板，不覆盖主窗口的游戏状态与 Touch Bar 焦点。
+final class HomeUtilityPanel: NSWindowController {
+    let page: String
+    var onLanguage: ((AppLanguage) -> Void)?
+    var onVolume: ((Float) -> Void)?
+    private let titleLabel = NSTextField(labelWithString: "")
+    private let body = NSTextView()
+    private let languageLabel = NSTextField(labelWithString: "")
+    private let language = NSPopUpButton(frame: .zero, pullsDown: false)
+    private let volumeLabel = NSTextField(labelWithString: "")
+    private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
+    private let percent = NSTextField(labelWithString: "")
+    private let store: ModeRecordStore
+
+    init(page: String, store: ModeRecordStore = .shared) {
+        self.page = page; self.store = store
+        let panel = HomeAuxiliaryWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: page == "settings" ? 270 : 480),
+                                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
+        panel.isReleasedWhenClosed = false
+        panel.appearance = NSAppearance(named: .aqua)
+        panel.backgroundColor = HomeStyle.background
+        panel.hidesOnDeactivate = true
+        panel.contentView = HomeUtilityBackgroundView(frame: NSRect(origin: .zero, size: panel.contentLayoutRect.size))
+        super.init(window: panel)
+        guard let content = panel.contentView else { return }
+        titleLabel.frame = NSRect(x: 24, y: content.bounds.height - 65, width: 452, height: 38)
+        titleLabel.font = .systemFont(ofSize: 25, weight: .bold); titleLabel.textColor = HomeStyle.ink
+        content.addSubview(titleLabel)
+        if page == "settings" {
+            for label in [languageLabel, volumeLabel, percent] { label.font = .systemFont(ofSize: 15); label.textColor = HomeStyle.ink; content.addSubview(label) }
+            languageLabel.frame = NSRect(x: 26, y: 141, width: 90, height: 26)
+            language.frame = NSRect(x: 135, y: 136, width: 325, height: 34)
+            language.font = .systemFont(ofSize: 15); language.target = self; language.action = #selector(languageChanged)
+            volumeLabel.frame = NSRect(x: 26, y: 75, width: 90, height: 26)
+            volume.frame = NSRect(x: 135, y: 74, width: 245, height: 28)
+            percent.frame = NSRect(x: 398, y: 74, width: 68, height: 28)
+            volume.target = self; volume.action = #selector(volumeChanged)
+            content.addSubview(language); content.addSubview(volume)
+        } else {
+            let scroll = NSScrollView(frame: NSRect(x: 22, y: 24, width: 456, height: content.bounds.height - 105))
+            scroll.hasVerticalScroller = true; scroll.drawsBackground = false
+            body.isEditable = false; body.isSelectable = true; body.drawsBackground = false
+            body.font = .systemFont(ofSize: 15); body.textColor = HomeStyle.ink
+            body.isVerticallyResizable = true; body.isHorizontallyResizable = false
+            body.autoresizingMask = [.width]; body.textContainer?.widthTracksTextView = true
+            body.frame = scroll.bounds; scroll.documentView = body
+            content.addSubview(scroll)
+        }
+    }
+    required init?(coder: NSCoder) { nil }
+
+    func refresh(mode: HomeGameMode, volume value: Float) {
+        let key = "panel.\(page)"
+        titleLabel.stringValue = AchievementText.string(key); window?.title = titleLabel.stringValue
+        if page == "settings" {
+            languageLabel.stringValue = AchievementText.string("language.label")
+            volumeLabel.stringValue = AchievementText.string("volume.label")
+            language.removeAllItems()
+            language.addItems(withTitles: AppLanguage.allCases.map { AchievementText.string($0.titleKey) })
+            language.selectItem(at: AppLanguage.allCases.firstIndex(of: Localizer.shared.language) ?? 0)
+            volume.doubleValue = Double(value); percent.stringValue = "\(Int(value * 100))%"
+        } else if page == "rules" {
+            body.string = "• " + AchievementText.string("rules.core.line1") + "\n\n• " + AchievementText.string("rules.core.line2")
+                + "\n\n• " + AchievementText.string("home.mode_desc.\(mode.key)") + "\n\n• " + AchievementText.string("home.rules.fixed")
+        } else {
+            var lines = [AchievementText.string("home.records.fixed"), ""]
+            let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
+            for (recordMode, detail, titleKey) in [(ModeRecordKey.scoreAttack, 1, "home.mode.score_attack"), (.speedRun, 300, "home.mode.speed_run")] {
+                lines.append(AchievementText.string(titleKey))
+                let entries = store.records(for: recordMode, detailValue: detail)
+                if entries.isEmpty { lines.append(AchievementText.string("records.empty")) }
+                for (index, entry) in entries.enumerated() {
+                    let metric = recordMode == .scoreAttack ? AchievementText.format("records.metric.score", entry.score) : String(format: "%.2f s", entry.elapsedTime)
+                    lines.append("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)))")
+                }
+                lines.append("")
+            }
+            body.string = lines.joined(separator: "\n")
+        }
+        // 文本视图只在竖直方向扩展，让较多历史记录可正常滚动。
+        if page != "settings" { body.sizeToFit() }
+    }
+
+    func present(from parent: NSWindow?) {
+        guard let window else { return }
+        if let parent {
+            let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
+            let x = min(max(parent.frame.midX - window.frame.width / 2, available.minX + 8), available.maxX - window.frame.width - 8)
+            let y = min(max(parent.frame.midY - window.frame.height / 2, available.minY + 8), available.maxY - window.frame.height - 8)
+            window.setFrameOrigin(NSPoint(x: x, y: y))
+            if window.parent !== parent { window.parent?.removeChildWindow(window); parent.addChildWindow(window, ordered: .above) }
+        } else { window.center() }
+        window.orderFront(nil)
+    }
+    @objc private func languageChanged() {
+        onLanguage?(AppLanguage.allCases[max(0, language.indexOfSelectedItem)])
+    }
+    @objc private func volumeChanged() {
+        percent.stringValue = "\(Int(volume.doubleValue * 100))%"
+        onVolume?(Float(volume.doubleValue))
+    }
+}
```

### `Sources/GamePresentation.swift`

```diff
diff --git a/Sources/GamePresentation.swift b/Sources/GamePresentation.swift
--- /dev/null
+++ b/Sources/GamePresentation.swift
@@ -0,0 +1,101 @@
+import Cocoa
+
+/// 首页只暴露固定规则；历史记录中的旧档位仍可被读取。
+enum HomeGameMode: Int, CaseIterable {
+    case free, speedRun, scoreAttack
+
+    static let scoreAttackDuration: TimeInterval = 60
+    static let speedRunTarget = 300
+
+    var gameMode: GameMode {
+        switch self {
+        case .free: return .free
+        case .speedRun: return .speedRun(targetScore: Self.speedRunTarget)
+        case .scoreAttack: return .scoreAttack(duration: Self.scoreAttackDuration)
+        }
+    }
+
+    var key: String {
+        switch self {
+        case .free: return "free"
+        case .speedRun: return "speed_run"
+        case .scoreAttack: return "score_attack"
+        }
+    }
+
+    var symbol: String {
+        switch self {
+        case .free: return "infinity"
+        case .speedRun: return "stopwatch"
+        case .scoreAttack: return "trophy"
+        }
+    }
+}
+
+/// 首页与辅助面板共用轻量浅色主题，所有颜色显式定义，避免系统深浅色切换影响对比度。
+enum HomeStyle {
+    static let background = NSColor(calibratedRed: 0.985, green: 0.979, blue: 0.966, alpha: 1)
+    static let ink = NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.085, alpha: 1)
+    static let secondary = NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.49, alpha: 1)
+    static let muted = NSColor(calibratedRed: 0.60, green: 0.62, blue: 0.65, alpha: 1)
+    static let border = NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.89, alpha: 1)
+    static let blue = NSColor(calibratedRed: 0, green: 0.51, blue: 1, alpha: 1)
+    static let yellow = NSColor(calibratedRed: 1, green: 0.79, blue: 0.025, alpha: 1)
+    static let green = NSColor(calibratedRed: 0.025, green: 0.79, blue: 0.34, alpha: 1)
+
+    static func text(_ string: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
+                     color: NSColor = ink, alignment: NSTextAlignment = .left) {
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.alignment = alignment
+        paragraph.lineBreakMode = .byTruncatingTail
+        (string as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
+                                                           .foregroundColor: color, .paragraphStyle: paragraph])
+    }
+
+    static func symbol(_ name: String, in rect: NSRect, color: NSColor = ink) {
+        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
+        let tinted = NSImage(size: rect.size, flipped: true) { target in
+            image.draw(in: target)
+            color.setFill()
+            target.fill(using: .sourceAtop)
+            return true
+        }
+        tinted.draw(in: rect)
+    }
+
+    static func card(_ rect: NSRect, fill: NSColor = NSColor.white.withAlphaComponent(0.7), border: NSColor = border, radius: CGFloat = 10) {
+        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
+        fill.setFill()
+        path.fill()
+        border.setStroke()
+        path.lineWidth = 1
+        path.stroke()
+    }
+
+    static func piece(_ kind: PieceKind, in rect: NSRect, shadow: Bool = true) {
+        let cell = min(rect.width / 3, rect.height / 2)
+        let origin = NSPoint(x: rect.midX - cell * 1.5, y: rect.midY - cell)
+        NSGraphicsContext.saveGraphicsState()
+        if shadow {
+            let effect = NSShadow()
+            effect.shadowColor = kind.color.withAlphaComponent(0.17)
+            effect.shadowBlurRadius = cell * 0.3
+            effect.shadowOffset = NSSize(width: cell * 0.12, height: -cell * 0.15)
+            effect.set()
+        }
+        for block in kind.blocks {
+            let tile = NSRect(x: origin.x + CGFloat(block.x) * cell, y: origin.y + CGFloat(1 - block.y) * cell,
+                              width: cell - 0.5, height: cell - 0.5)
+            let path = NSBezierPath(roundedRect: tile, xRadius: max(1, cell * 0.09), yRadius: max(1, cell * 0.09))
+            let light = kind.color.blended(withFraction: 0.18, of: .white) ?? kind.color
+            let dark = kind.color.shadow(withLevel: 0.12) ?? kind.color
+            NSGradient(colors: [light, kind.color, dark])?.draw(in: path, angle: 90)
+            dark.withAlphaComponent(0.7).setStroke()
+            path.lineWidth = max(0.5, cell * 0.025)
+            path.stroke()
+            NSColor.white.withAlphaComponent(0.18).setStroke()
+            NSBezierPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), xRadius: 2, yRadius: 2).stroke()
+        }
+        NSGraphicsContext.restoreGraphicsState()
+    }
+}
```

### `Tests/HomeDashboardTests.swift`

```diff
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
--- /dev/null
+++ b/Tests/HomeDashboardTests.swift
@@ -0,0 +1,157 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class HomeDashboardTests: AchievementTestCase {
+    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
+
+    private func board(now: @escaping () -> Date) -> GameBoardController {
+        GameBoardController(columns: 4, achievements: manager, now: now) { _ in
+            let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
+            let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+            let refill = Array(repeating: a, count: 27) + [c, d, c]
+            var index = 0
+            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
+                defer { index += 1 }
+                return refill[index]
+            }
+        }
+    }
+
+    func testCurrentRoundStatisticsResetWhileLifetimeCountsRemain() {
+        let board = board(now: { self.date })
+        XCTAssertFalse(board.snapshot().isRunning)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().totalCleared, 0)
+        board.startRound()
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().totalCleared, 30)
+        XCTAssertEqual(board.snapshot().clearedByKind[.orangeRicky], 30)
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
+        board.startRound()
+        XCTAssertEqual(board.snapshot().totalCleared, 0)
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
+        board.configure(mode: HomeGameMode.speedRun.gameMode)
+        XCTAssertEqual(board.snapshot().totalCleared, 0)
+        XCTAssertFalse(board.snapshot().isRunning)
+    }
+
+    func testFixedModesFinishAtSixtySecondsAndThreeHundredPoints() {
+        var now = date
+        let board = board(now: { now })
+        board.configure(mode: HomeGameMode.scoreAttack.gameMode)
+        board.startRound()
+        now = date.addingTimeInterval(59.9)
+        board.tick()
+        XCTAssertFalse(board.snapshot().isFinished)
+        now = date.addingTimeInterval(60)
+        board.tick()
+        XCTAssertTrue(board.snapshot().isFinished)
+        board.configure(mode: HomeGameMode.speedRun.gameMode)
+        board.startRound()
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().score, 300)
+        XCTAssertTrue(board.snapshot().isFinished)
+        let final = board.snapshot().clearedByKind
+        board.performSwap(from: 0, to: 1)
+        XCTAssertEqual(board.snapshot().clearedByKind, final)
+    }
+
+    func testHomeButtonsUseFixedRulesAndLiveStats() throws {
+        _ = NSApplication.shared
+        let board = board(now: { self.date })
+        let records = ModeRecordStore(defaults: defaults)
+        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false)
+        let view = controller.view
+        let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.primary })
+        let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeSessionStatsView }.first)
+        XCTAssertFalse(board.snapshot().isRunning)
+        start.performClick(nil)
+        XCTAssertTrue(board.snapshot().isRunning)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
+        let free = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .free })
+        free.performClick(nil)
+        XCTAssertEqual(stats.snapshot?.totalCleared, 30, "点击已选模式不应重置本局")
+        let speed = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .speedRun })
+        speed.performClick(nil)
+        XCTAssertEqual(board.snapshot().targetScore, 300)
+        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
+        start.performClick(nil)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertTrue(board.snapshot().isFinished)
+        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
+        let finished = try XCTUnwrap(records.records(for: .speedRun, detailValue: 300).first)
+        XCTAssertEqual(finished.elapsedTime, 0)
+        for _ in 0..<3 { board.tick() }
+        XCTAssertEqual(records.records(for: .speedRun, detailValue: 300).first?.id, finished.id)
+        XCTAssertTrue(descendants(view).allSatisfy { !($0 is NSPopUpButton) })
+        let score = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .scoreAttack })
+        score.performClick(nil)
+        XCTAssertEqual(board.snapshot().remainingTime, 60)
+        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
+    }
+
+    func testHomeRendersAllModesLanguagesAndWindowSizes() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        defaults.set(["version": 1, "unlocked": [1, 3, 4, 7], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        let progress = AchievementsManager(defaults: defaults)
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            for mode in HomeGameMode.allCases {
+                let snapshot = GameSnapshot(mode: mode.gameMode, score: 210, elapsedTime: 12, remainingTime: mode == .scoreAttack ? 48 : nil,
+                                            targetScore: mode == .speedRun ? 300 : nil, isRunning: true, isFinished: false,
+                                            clearedByKind: [.orangeRicky: 3, .blueRicky: 9, .clevelandZ: 6, .rhodeIslandZ: 3])
+                for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1440, height: 940)] {
+                    home.setFrameSize(size)
+                    home.refresh(snapshot: snapshot, mode: mode, manager: progress)
+                    home.layoutSubtreeIfNeeded()
+                    XCTAssertEqual(home.stats.snapshot?.totalCleared, 21)
+                    for button in home.subviews.compactMap({ $0 as? HomeButton }) {
+                        XCTAssertTrue(home.bounds.contains(button.frame), "\(language.rawValue): \(button.frame)")
+                        XCTAssertGreaterThan(button.frame.height, 30)
+                    }
+                    if language == .chineseSimplified, size.width == 1180 {
+                        let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: home.bounds))
+                        home.cacheDisplay(in: home.bounds, to: bitmap)
+                        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+                        let path = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-\(mode.key).png")
+                        try png.write(to: path)
+                        print("首页预览：\(path.path)")
+                    }
+                }
+            }
+        }
+    }
+
+    func testSettingsOnlyExposeLanguageAndVolumeAndNavigationPanelsRender() throws {
+        _ = NSApplication.shared
+        let store = ModeRecordStore(defaults: defaults)
+        for page in ["settings", "rules", "records"] {
+            let panel = HomeUtilityPanel(page: page, store: store)
+            defer { panel.close() }
+            panel.refresh(mode: .speedRun, volume: 0.4)
+            let window = try XCTUnwrap(panel.window)
+            XCTAssertFalse(window.canBecomeKey)
+            let content = try XCTUnwrap(window.contentView)
+            let popups = descendants(content).compactMap { $0 as? NSPopUpButton }
+            if page == "settings" {
+                XCTAssertEqual(popups.count, 1, "设置只提供语言菜单，不提供规则档位")
+                let slider = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSlider }.first)
+                var volume: Float = 0
+                panel.onVolume = { volume = $0 }
+                slider.doubleValue = 0.25
+                slider.sendAction(slider.action, to: slider.target)
+                XCTAssertEqual(volume, 0.25)
+            } else { XCTAssertTrue(popups.isEmpty) }
+            let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
+            content.cacheDisplay(in: content.bounds, to: bitmap)
+            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+            try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-\(page).png"))
+        }
+    }
+
+}
```
