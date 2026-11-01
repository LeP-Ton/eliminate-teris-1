# 消除数量结算、60 秒限时与 30 次限步挑战

## 背景与目标
- 按用户确认的新方案取消得分，以实际消除数量作为唯一结果；两种挑战分别考验反应速度和交换效率。
- 本轮基于 `experiment/ui-refactor` 分支的 `2d124b6249bb6617e1d80bf80d5c489385da8742`，保留已完成的按钮、空格与触控栏滑动开局。
- 会话-148 完成预览检查与最后文案修正；本文件记录本轮相对开始时工作区的全部增量，可与上一轮开局变更独立对照。

## 当前规则
| 模式 | 结束条件 | 结果与排序 |
| --- | --- | --- |
| 自由模式 | 无时间与次数限制 | 仅展示本局实际消除数量，不进挑战榜 |
| 限时挑战 | 正式开场结束后计时，满 60 秒结束 | 消除数量越多越靠前 |
| 限步挑战 | 用完 30 次合法相邻交换结束，不限制思考时间 | 消除数量越多越靠前，不比较用时 |

- 无消除或相同类型之间的合法交换均使用一次；选中、取消、越界、非相邻、相同位置及受锁定阻止的操作不计次。
- 一次交换引起的补位、自动连锁均包含在本次操作中，不重复扣次；第 30 次交换的全部连锁先计入结果，再结束。
- 两种挑战相同消除数量共享名次，例如 `1、1、3`。日期和编号仅用于相同名次的稳定展示；耗时永远不作第二排序条件。
- 正常完成但零消除也可记录挑战结果；完成类成就仍要求该局有消除。
- 重开或实际切换模式清空本局统计；点击已选模式不清零。到期后尚未收到界面 tick 就重开或切模式，也先结算旧局，防止丢失成绩。

## 实现与数据兼容
- `GameState.totalCleared` 由分类消除数量合计，删除分数存储与每个方块乘 10 的逻辑；首页总量和分类统计使用同一数据源。
- `GameSnapshot` 提供 `swapsUsed` 和 `remainingSwaps`；控制器在完整结算真实交换后计次，动画读取 `consumeLastSwapPair` 不改变次数。
- `GameMode` / `HomeGameMode` 统一为自由、限时、限步；限步不启动倒计时刷新，音频按新模式名称接入既有主题。
- 新榜单单独存于 `challenge_records_v2`，使用 `timed_60` / `moves_30` 分区，每区保留最多 9 条；存储入口校验已完成当前规则。
- 旧 `mode_records_v1` 只读，不转换成新挑战成绩、不改写原始字节；有真实历史时提供可展开/收起的“旧规则记录”入口，按原分数或用时展示。
- 新榜单不注入开发成绩；旧记录展示过滤 `seed_` 测试数据，但不删除或重写旧存档。
- 成就存档提升到版本 2，32 个稳定编号、已解锁状态、解锁时间、总累计与分类累计全部保留。
- 旧单局最高分除以 10 向下取整迁移为最高消除数量，仅迁移一次；新模式最高消除与完成指标使用新键，不从旧模式成绩推导。
- 旧规则已解锁但新条件尚未达到时保留解锁，并显示兼容说明。
- 首页、状态提示、玩法说明、排行榜、成就条件与中英文 README 同步更新；产品文本覆盖中、英、日、韩、俄五种语言。

## 挑战成就适配
| 稳定编号 | 当前名称 | 新条件 |
| --- | --- | --- |
| 1 | 小试身手 | 任意模式单局消除至少 10 个 |
| 10 | 一分钟热身 | 完成 60 秒限时挑战，消除至少 30 个 |
| 11 | 火力全开 | 完成 60 秒限时挑战，消除至少 60 个 |
| 12 | 极限消除 | 完成 60 秒限时挑战，消除至少 90 个 |
| 13 | 三十步旅程 | 用完 30 次交换，且有消除 |
| 14 | 精打细算 | 完成 30 次交换，消除至少 30 个 |
| 15 | 步步制胜 | 完成 30 次交换，消除至少 60 个 |
| 16 | 坚持一分钟 | 完成 60 秒限时挑战，且有消除 |

- 其余节奏、连续成功交换、单轮长度、自动连锁、累计完成数与总量/分类百千万里程碑继续使用真实事件；涉及旧“得分”的条件描述改为“产生消除”。
- 只改变需要适配的条件与名称，不新增成就编号，也不取消玩家已获得的成就。

## 阶段与完成情况
- [x] 核心规则与交换计次、时间边界、最后一步连锁。
- [x] 首页与辅助面板数量显示、新模式状态、排行榜并列名次。
- [x] 旧榜单只读分区、成就兼容迁移与零消除结果边界。
- [x] 五语言与 README、根目录核心认知及索引更新。
- [x] 自动化回归、真实 AppKit 离屏预览与完整变更留痕。

## 测试方法与结果
- 完整回归：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，2026-11-01 18:07:11 完成，**81 项通过，0 失败**。
- 最后仅修正中文“连锁得分”为“连锁消除”及四种语言的自由模式简介后，运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeUtilityPanelTests.testFiveLanguagesCompactWindowsAndExportRealPanels`，18:14:09 完成，**1 项通过**，覆盖五语言与紧凑窗口并重新导出面板。
- `git diff --check` 通过；全部测试使用隔离存档、可控时间与确定性棋盘，未写玩家存档。

### TC-001 合法交换扣次与非法操作隔离（通过）
- `ChallengeRulesTests.testOnlyRealLegalSwapsConsumeMovesAndRefreshNeverResetsThem`：选中/取消/越界/非相邻/锁定均不计次；无消除交换计次；快照、tick、动画消费不清零；限步等待一天仍继续。

### TC-002 末步连锁全部入账（通过）
- `ChallengeRulesTests.testThirtiethSwapResolvesEveryCascadeThenRefusesThirtyFirst`：前 29 次不消除，最后一次触发十轮连锁清除 30 个，按实际类型累计，解锁对应成就，拒绝第 31 次。

### TC-003 限时时间边界与重开结算（通过）
- 可控时间验证 59.999 秒接受交换、60 秒结束、到期拒绝操作；到期未 tick 立即重开，仍先广播旧局完成事件。

### TC-004 并列排名与历史存档（通过）
- 同消除数耗时不同也共享 `1、1、3`；实际面板两条并列第一均显示第一名和高亮。
- 旧 450 分与新 12 个独立显示，旧存档字节保持一致；旧记录只在主动展开历史入口后出现。
- 未自然完成的结果拒绝写入，合法完成的零消除结果可存。

### TC-005 成就迁移与开局回归（通过）
- 旧最高分只迁移一次，保留原有解锁与累计，新旧模式进度隔离；新挑战成就验证自然完成和数量阈值。
- 主按钮/空格/触控栏开局、开场不扣步、重开去重、模式切换和成就图文居中继续通过既有回归。

### TC-006 界面验收（离屏预览通过，实机触摸待体验）
- 查看 [限时首页](../../docs/previews/challenge-timed.png)、[限步首页](../../docs/previews/challenge-moves.png)、[玩法说明](../../docs/previews/utility-rules.png)、[历史记录](../../docs/previews/utility-records-history.png) 与 [成就页](../../docs/previews/achievement-panel.png)。
- 预览由真实 AppKit 组件导出，正式应用无测试入口；人工核对剩余时间/次数、数量单位、连锁消除文案和历史分区。
- 实机体验：运行 `./run.sh`，选择限时/限步，通过按钮、空格或触控栏滑动开始；限时等待 60 秒结算，限步交换 30 次结算并检查最后连锁。
- 本轮未通过工具操作玩家真实 Touch Bar，也未自动提交或推送仓库。

## 完整代码及文档增量
以下相对于本轮开始时的工作区快照生成；文本使用统一 diff，包含所有增删行及新增测试；本变更文档作为记录载体不递归记录自身。二进制预览以路径、字节数和 SHA-256 留痕。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261101181421-count-based-timed-move-challenges.md` - 本轮按新方案取消得分，改为自由/60 秒限时/30 次交换限步；真实交换计次、末步完整连锁、数量并列榜单、旧记录只读分区、成就版本 2 兼容；含全部增量 diff、真实预览与 81 项完整回归。
@@ -84,0 +86 @@
+- 需要了解当前消除数量计数、60 秒限时/30 次限步规则、合法交换扣次、末步连锁、并列名次、旧记录分区或成就版本 2 迁移时，优先读取 `20261101181421-count-based-timed-move-challenges.md`。
@@ -173 +175,3 @@
-- 探索分支三种模式通过按钮、空格或滑动触控栏显式开局；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
+- 当前三种模式通过按钮、空格或滑动触控栏显式开局：自由不限时间/次数，限时挑战固定 60 秒，限步挑战固定 30 次合法相邻交换；只统计消除数量，不再计分。无消除也扣一次，自动连锁不多扣，末次交换完整结算；限步不比较耗时。
+- 新榜单使用 `challenge_records_v2`，仅按数量排序，相同数量共享名次（例如 1、1、3）；自然完成的零消除结果也可保存。旧 `mode_records_v1` 原样只读，通过独立历史入口展示，不混入新榜。
+- 成就存档版本为 2，32 个编号及已解锁状态/时间与累计数量均保留；旧单局最高分除以 10 转数量，仅迁移一次。新模式进度使用新键，旧模式数据不伪造新挑战成绩；有消除且自然完成才累计完成类成就。
@@ -194 +198 @@
-- 挑战记录测试数据当前只在开发模式注入：`run.sh` 会导出 `ELIMINATE_DEVELOPMENT_MODE=1`，`ModeRecordStore` 在非开发模式启动时会主动移除旧 seed，避免正式版本看到 9/1/0 条测试记录。
+- 新挑战排行榜不注入开发测试成绩；测试与预览均使用隔离 UserDefaults 域。旧记录展示时过滤 `seed_` 条目，但不改写旧存档；开发模式环境变量仍由 `run.sh` 提供给其他开发功能。
@@ -203 +207 @@
-- 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
+- `GameAudioSystem` 程序化音频按自由/限时/限步模式切换 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -6,0 +7,6 @@
+
+## 2026-11-01（按消除数量结算的新规则）
+- 当前模式为自由、60 秒限时挑战、30 次交换限步挑战；运行时不再统计分数，数量统一来自 `GameState` 的分类消除计数。历史段落中的竞分/竞速规则仅作为旧版记录。
+- 合法相邻交换在完整连锁结算后累计一次，无消除也计次；选中、取消、非法或受锁定阻止的操作不计次。`GameSnapshot` 提供已用/剩余交换次数，限步不受时间影响。
+- 新榜单使用 `challenge_records_v2`，两种挑战均按消除数量排序并共享并列名次；旧 `mode_records_v1` 只读，通过历史入口展示，不写回、不混入新榜，也不向新榜注入开发成绩。
+- 成就存档版本为 2，保留 32 个稳定编号、已解锁状态、时间及累计数量；旧单局最高分可确定地除以 10 转为单局数量，新模式进度另起键。游戏到期后立即重开或切模式，也会先广播旧局结算以保存记录。
```

### `README.en.md`

```diff
--- a/README.en.md
+++ b/README.en.md
@@ -12 +12 @@
-`Eliminate Teris 1` is a lightweight macOS puzzle game designed around the Touch Bar. The battlefield is not the center of your screen, but the narrow strip above your keyboard that people often notice less and use even less. On a one-dimensional board of 16 slots, you swap adjacent tiles, create matches of three or more, chase higher scores, and compress every action into a tighter and more direct rhythm in score attack and speed run modes.
+`Eliminate Teris 1` is a lightweight macOS puzzle game built for the Touch Bar. Swap adjacent tiles on a one-dimensional board of 16 slots and match three or more. Race to clear more tiles in one minute, or take your time planning thirty swaps.
@@ -34 +34 @@
-Ideally shows the settings panel, time and score panel, challenge records, and mode briefing together.
+Ideally shows mode selection, live tile counts, challenge records, and the rules.
@@ -53 +53 @@
-- Every cleared tile gives `10` points.
+- The game counts cleared tiles directly, with no point multiplier.
@@ -58,4 +58,4 @@
-### 3. Three modes for practice, score chasing, and speed
-- **Free Mode**: no time limit and no target score; ideal for learning the rules and getting comfortable with the controls.
-- **Score Attack**: score as high as possible within a limited time; uses a fixed `60` second round and ends automatically.
-- **Speed Run**: reach a target score as quickly as possible; uses a fixed `300` point target and ends automatically.
+### 3. Three modes for practice, pace, and planning
+- **Free Mode**: unlimited time and swaps for practice.
+- **Timed Challenge**: clear as many tiles as possible in `60` seconds.
+- **Swap Challenge**: clear as many tiles as possible in `30` swaps, with no time limit. The final swap and its cascades resolve fully.
@@ -64,2 +64,2 @@
-- Records are stored locally by mode and by sub-rule.
-- The current interface shows 60-second Score Attack and 300-point Speed Run rankings. Other historical buckets remain in local storage.
+- Both challenge modes rank by tiles cleared. Equal counts share a rank; elapsed time does not break ties.
+- New records use separate storage. Previous Score Attack and Speed Run results remain available under the previous-rules records section.
@@ -80 +80 @@
-Swap adjacent tiles so that at least 3 identical tiles line up, then clear them for points.
+Swap adjacent tiles to line up at least three identical tiles and clear as many as possible.
@@ -87,4 +87,4 @@
-### Scoring
-- Each cleared tile is worth `10` points.
-- Consecutive clears continue to add to your score.
-- Score Attack ranks by final score, while Speed Run ranks by the time required to reach the target.
+### Counts and Swaps
+- All cleared tiles, including refill cascades, count toward the round total. There are no point or combo multipliers.
+- Every legal adjacent swap uses one move in Swap Challenge, even if it clears nothing.
+- Selecting, cancelling, and invalid drags use no moves. Cascades cost no extra moves.
@@ -95,7 +95,7 @@
-Best for your first few rounds. There is no time pressure and no score target. It lets you learn the feel of the one-dimensional board, the Touch Bar interaction, and the general flow of clearing tiles.
-
-### Score Attack
-This is the most straightforward mode for chasing high scores. You need to create as many efficient swaps as possible within limited time. It rewards consistency, quick decisions, and control under pressure.
-
-### Speed Run
-Reach the fixed target of `300` points as quickly as possible. The round ends automatically when the target is reached.
+Best for your first few rounds. Time and swaps are unlimited, so you can learn the board and controls at your own pace.
+
+### Timed Challenge
+Clear as many tiles as possible in `60` seconds. The opening animation does not use any challenge time.
+
+### Swap Challenge
+Use `30` swaps to clear as many tiles as possible. There is no countdown. Swaps without a match still count, and all cascades from the final swap resolve before the round ends.
@@ -107 +107 @@
-- **Game Modes**: choose Free Play, Speed Run, or Score Attack, then start or restart. Time and target settings are fixed.
+- **Game Modes**: choose Free Mode, Timed Challenge, or Swap Challenge with fixed rules. Start with the main button, Space, or the Touch Bar slider.
```

### `README.md`

```diff
--- a/README.md
+++ b/README.md
@@ -12,3 +12,3 @@
-> 当前为 `experiment/ui-refactor` 探索分支：桌面窗口采用浅色首页、模式卡片与本局实时统计；竞分固定 60 秒，竞速固定 300 分。点击“开始游戏”、按空格或向右滑动触控栏均可开局，开场完成后才开始计时。
-
-`Eliminate Teris 1` 是一款为 macOS 与 Touch Bar 场景设计的轻量消除游戏：战场不在大屏幕中央，而是在键盘上方那条熟悉又常被忽视的细长区域里。你会在 16 格的一维棋盘上交换相邻方块、制造三连消除、追逐更高分数，也会在竞速与限时模式里，把每一次操作都压缩成更紧凑、更直接的节奏。
+> 当前为 `experiment/ui-refactor` 探索分支：自由模式、60 秒限时挑战、30 次交换限步挑战统一统计消除数量。点击“开始游戏”、按空格或向右滑动触控栏均可开局，开场完成后才启用计时或计次。
+
+`Eliminate Teris 1` 是一款为 macOS 与 Touch Bar 场景设计的轻量消除游戏：战场在键盘上方的细长区域。你会在 16 格的一维棋盘上交换相邻方块、制造三连消除；既可以在一分钟内挑战消除数量，也可以不限思考时间，规划三十次交换。
@@ -36 +36 @@
-建议展示设置、时间与得分、挑战记录、玩法说明四大模块。
+建议展示模式选择、本局消除统计、挑战记录和玩法说明。
@@ -55 +55 @@
-- 被消除的每个方块计 `10` 分。
+- 直接统计实际消除数量，不再乘以分数系数。
@@ -60,4 +60,4 @@
-### 3. 三种模式，照顾练手、冲分与竞速
-- **自由模式**：没有时间限制，也没有目标分数，适合熟悉规则、放松手感。
-- **竞分模式**：在限定时间内尽可能拿高分，固定为 `60` 秒，到时自动结算。
-- **竞速模式**：以最短时间冲到目标分数，固定为 `300` 分，达标自动结算。
+### 3. 三种模式，练习、限时与限步
+- **自由模式**：不限时间和交换次数，适合熟悉规则、放松手感。
+- **限时挑战**：固定 `60` 秒，尽可能多消除，到时自动结算。
+- **限步挑战**：固定 `30` 次交换，不限思考时间，最后一次交换的连消完整结算后结束。
@@ -66,3 +66,3 @@
-- 游戏按竞分、竞速的固定规则分别保存挑战记录。
-- 当前显示“竞分 60 秒”和“竞速 300 分”两组排行；旧版其他档位的存档仍保留。
-- 每个记录桶最多保留 `9` 条成绩，方便持续追分、反复刷新个人最佳。
+- 两种挑战分别按消除数量排名，同数量共享名次；限步挑战不比较用时。
+- 新榜单使用独立存档；旧竞分、竞速成绩可从“查看旧规则记录”打开，保留原规则和数据。
+- 每组榜单最多保留 `9` 条记录，方便反复刷新个人最佳。
@@ -82 +82 @@
-通过交换相邻方块，让相同颜色的方块连成至少 3 个，触发消除并获得分数。
+通过交换相邻方块，让相同颜色的方块连成至少 3 个，尽可能多地消除。
@@ -89,4 +89,4 @@
-### 计分方式
-- 每个被消除的方块固定计 `10` 分。
-- 连续消除会继续累计得分。
-- 竞分模式按最终分数排名；竞速模式按达成目标分数所用时间排名。
+### 数量与次数
+- 本局消除数量包含所有补位连消，不设置分数或连击倍率。
+- 限步挑战中，每次实际完成的合法相邻交换消耗一次，没有消除也消耗。
+- 选中、取消、无效拖动不扣次数；同一次交换的自动连消不额外扣次数。
@@ -99,5 +99,5 @@
-### 竞分模式
-这是最直接的“冲高分”玩法。你要在有限时间里尽量制造更多有效交换，让分数尽快抬升。它更考验稳定输出、连续判断和临场节奏。
-
-### 竞速模式
-竞速模式把目标固定为“尽快到达 300 分”。你需要的不只是正确操作，还包括尽可能少的犹豫与停顿；达到目标后立即结算。
+### 限时挑战
+在 `60` 秒内尽可能多地消除方块，考验判断速度和操作熟练度。开场动画不占用挑战时间。
+
+### 限步挑战
+在 `30` 次交换中尽可能多地消除方块。没有倒计时，可以仔细观察和规划；无消除的合法交换也计次，第 30 次交换及其全部连消完成后结算。
@@ -109 +109 @@
-- **游戏模式**：直接选择自由、竞速、竞分，点击开始或重新开始；不提供时间和目标档位设置。
+- **游戏模式**：选择自由、限时或限步，使用固定规则，不提供时间或交换次数档位设置。
```

### `Sources/AchievementViews.swift`

```diff
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -17 +17 @@
-        let reached = progress.isTime ? manager.hasTimedResult(for: definition) && progress.current <= progress.target : progress.current >= progress.target
+        let reached = progress.current >= progress.target
@@ -21,4 +20,0 @@
-        if progress.isTime {
-            guard manager.hasTimedResult(for: definition) else { return format("achievement.progress.no_time", progress.target) }
-            return format("achievement.progress.time", progress.current, progress.target)
-        }
@@ -26 +22 @@
-        case .firstClear, .speedRun:
+        case .firstClear, .completedMode:
```

### `Sources/AchievementsManager.swift`

```diff
--- a/Sources/AchievementsManager.swift
+++ b/Sources/AchievementsManager.swift
@@ -9 +9 @@
-    case bestScore(Int), rhythm(Int), completedRounds(Int), firstClear
+    case bestCleared(Int), rhythm(Int), completedRounds(Int), firstClear
@@ -11,2 +11,3 @@
-    case scoreAttack(minutes: Int, score: Int)
-    case speedRun(target: Int, limit: TimeInterval?)
+    case timedClears(seconds: Int, count: Int)
+    case moveClears(limit: Int, count: Int)
+    case completedMode(mode: ModeRecordKey, ruleValue: Int)
@@ -26 +27 @@
-        .init(id: 1, category: .beginner, goal: .bestScore(100)),
+        .init(id: 1, category: .beginner, goal: .bestCleared(10)),
@@ -35,7 +36,7 @@
-        .init(id: 10, category: .mode, goal: .scoreAttack(minutes: 1, score: 300)),
-        .init(id: 11, category: .mode, goal: .scoreAttack(minutes: 1, score: 600)),
-        .init(id: 12, category: .mode, goal: .scoreAttack(minutes: 1, score: 900)),
-        .init(id: 13, category: .mode, goal: .speedRun(target: 300, limit: nil)),
-        .init(id: 14, category: .mode, goal: .speedRun(target: 300, limit: 45)),
-        .init(id: 15, category: .mode, goal: .speedRun(target: 300, limit: 30)),
-        .init(id: 16, category: .mode, goal: .speedRun(target: 300, limit: 60)),
+        .init(id: 10, category: .mode, goal: .timedClears(seconds: 60, count: 30)),
+        .init(id: 11, category: .mode, goal: .timedClears(seconds: 60, count: 60)),
+        .init(id: 12, category: .mode, goal: .timedClears(seconds: 60, count: 90)),
+        .init(id: 13, category: .mode, goal: .completedMode(mode: .moves, ruleValue: 30)),
+        .init(id: 14, category: .mode, goal: .moveClears(limit: 30, count: 30)),
+        .init(id: 15, category: .mode, goal: .moveClears(limit: 30, count: 60)),
+        .init(id: 16, category: .mode, goal: .completedMode(mode: .timed, ruleValue: 60)),
@@ -65 +65,0 @@
-    let isTime: Bool
@@ -68 +67,0 @@
-        if isTime { return current > 0 ? min(1, target / current) : 0 }
@@ -117 +116 @@
-    func recordSwap(roundID: UUID, swapID: UUID, result: SwapResolution, score: Int, at date: Date) {
+    func recordSwap(roundID: UUID, swapID: UUID, result: SwapResolution, roundCleared: Int, at date: Date) {
@@ -138 +137 @@
-        updateBest("bestScore", Double(score))
+        updateBest("bestRoundCleared", Double(roundCleared))
@@ -144 +143 @@
-    func finishRound(id: UUID, mode: GameMode, score: Int, elapsed: TimeInterval, at date: Date) {
+    func finishRound(id: UUID, mode: GameMode, clearedCount: Int, swapsUsed: Int, elapsed: TimeInterval, at date: Date) {
@@ -149 +148 @@
-        case .scoreAttack(let duration):
+        case .timed(let duration):
@@ -152,4 +151,5 @@
-            guard score > 0 else { return }
-            updateBest("scoreAttack.\(Int(duration / 60))", Double(score))
-        case .speedRun(let target):
-            guard target > 0, score >= target else { return }
+            guard clearedCount > 0 else { return }
+            updateBest("timedCleared.\(Int(duration))", Double(clearedCount))
+            metrics["completedMode.timed.\(Int(duration))"] = 1
+        case .moves(let limit):
+            guard limit > 0, swapsUsed >= limit else { return }
@@ -157,4 +157,3 @@
-            let key = "speedRun.\(target)"
-            // 完成标记与用时分开保存，允许合法的 0 秒成绩。
-            metrics[key] = min(metrics[key] ?? .greatestFiniteMagnitude, elapsed)
-            metrics["speedRunCompleted.\(target)"] = 1
+            guard clearedCount > 0 else { return }
+            updateBest("movesCleared.\(limit)", Double(clearedCount))
+            metrics["completedMode.moves.\(limit)"] = 1
@@ -168 +167 @@
-            .init(current: metrics[key, default: 0], target: target, isTime: false)
+            .init(current: metrics[key, default: 0], target: target)
@@ -171 +170 @@
-        case .bestScore(let target): return value("bestScore", Double(target))
+        case .bestCleared(let target): return value("bestRoundCleared", Double(target))
@@ -174 +173 @@
-        case .firstClear: return .init(current: metrics["totalCleared", default: 0] > 0 ? 1 : 0, target: 1, isTime: false)
+        case .firstClear: return .init(current: metrics["totalCleared", default: 0] > 0 ? 1 : 0, target: 1)
@@ -178,6 +177,3 @@
-        case .scoreAttack(let minutes, let score): return value("scoreAttack.\(minutes)", Double(score))
-        case .speedRun(let target, let limit):
-            if let limit {
-                return .init(current: metrics["speedRun.\(target)", default: 0], target: limit, isTime: true)
-            }
-            return value("speedRunCompleted.\(target)", 1)
+        case .timedClears(let seconds, let count): return value("timedCleared.\(seconds)", Double(count))
+        case .moveClears(let limit, let count): return value("movesCleared.\(limit)", Double(count))
+        case .completedMode(let mode, let rule): return value("completedMode.\(mode.rawValue).\(rule)", 1)
@@ -187,5 +182,0 @@
-    }
-
-    func hasTimedResult(for definition: AchievementDefinition) -> Bool {
-        guard case .speedRun(let target, let limit) = definition.goal, limit != nil else { return false }
-        return metrics["speedRunCompleted.\(target)"] == 1
@@ -202,3 +193 @@
-            let reached = progress.isTime
-                ? hasTimedResult(for: definition) && progress.current <= progress.target
-                : progress.current >= progress.target
+            let reached = progress.current >= progress.target
@@ -224,0 +214,5 @@
+            // 总累计与解锁状态原样保留；旧分数只转换为可确定的单局消除数。
+            // 新模式的历史最佳使用新键，避免将旧规则结果冒充新挑战成绩。
+            if (stored["version"] as? Int ?? 1) < 2 {
+                metrics["bestRoundCleared"] = max(metrics["bestRoundCleared", default: 0], floor(metrics["bestScore", default: 0] / 10))
+            }
@@ -245 +239 @@
-        defaults.set(["version": 1, "unlocked": unlocked.sorted(), "timestamps": timestamps, "metrics": metrics], forKey: Self.storageKey)
+        defaults.set(["version": 2, "unlocked": unlocked.sorted(), "timestamps": timestamps, "metrics": metrics], forKey: Self.storageKey)
```

### `Sources/GameAudioSystem.swift`

```diff
--- a/Sources/GameAudioSystem.swift
+++ b/Sources/GameAudioSystem.swift
@@ -15,2 +15,2 @@
-        case scoreAttack
-        case speedRun
+        case moves
+        case timed
@@ -176,4 +176,4 @@
-        case .scoreAttack:
-            return .scoreAttack
-        case .speedRun:
-            return .speedRun
+        case .timed:
+            return .timed
+        case .moves:
+            return .moves
@@ -187 +187 @@
-        case .scoreAttack:
+        case .moves:
@@ -189 +189 @@
-        case .speedRun:
+        case .timed:
@@ -246 +246 @@
-        case .scoreAttack:
+        case .moves:
@@ -265 +265 @@
-        case .speedRun:
+        case .timed:
```

### `Sources/GamePresentation.swift`

```diff
--- a/Sources/GamePresentation.swift
+++ b/Sources/GamePresentation.swift
@@ -5 +5 @@
-    case free, speedRun, scoreAttack
+    case free, timed, moves
@@ -7,2 +7,2 @@
-    static let scoreAttackDuration: TimeInterval = 60
-    static let speedRunTarget = 300
+    static let timedDuration: TimeInterval = 60
+    static let moveLimit = 30
@@ -13,2 +13,2 @@
-        case .speedRun: return .speedRun(targetScore: Self.speedRunTarget)
-        case .scoreAttack: return .scoreAttack(duration: Self.scoreAttackDuration)
+        case .timed: return .timed(duration: Self.timedDuration)
+        case .moves: return .moves(limit: Self.moveLimit)
@@ -21,2 +21,2 @@
-        case .speedRun: return "speed_run"
-        case .scoreAttack: return "score_attack"
+        case .timed: return "timed"
+        case .moves: return "moves"
@@ -29,2 +29,2 @@
-        case .speedRun: return "stopwatch"
-        case .scoreAttack: return "trophy"
+        case .timed: return "stopwatch"
+        case .moves: return "arrow.left.arrow.right"
```

### `Sources/GameState.swift`

```diff
--- a/Sources/GameState.swift
+++ b/Sources/GameState.swift
@@ -36 +36 @@
-    private(set) var score: Int = 0
+    var totalCleared: Int { clearedByKind.values.reduce(0, +) }
@@ -99 +98,0 @@
-            score += matches.count * 10
```

### `Sources/GameTouchBarView.swift`

```diff
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -5,2 +5,2 @@
-    case scoreAttack(duration: TimeInterval)
-    case speedRun(targetScore: Int)
+    case timed(duration: TimeInterval)
+    case moves(limit: Int)
@@ -11 +10,0 @@
-    let score: Int
@@ -14 +13 @@
-    let targetScore: Int?
+    let remainingSwaps: Int?
@@ -17,0 +17 @@
+    var swapsUsed: Int = 0
@@ -39,0 +40 @@
+    private var swapsUsed = 0
@@ -62,0 +64,2 @@
+        // 到期后立即切换或重开，也先广播旧局结算，避免 HUD 下次刷新前丢失记录。
+        if updateFinishedState(now: currentDate()) { notifyChange() }
@@ -78,0 +82 @@
+        if updateFinishedState(now: currentDate()) { notifyChange() }
@@ -119 +122,0 @@
-                score: state.score,
@@ -122 +125 @@
-                targetScore: nil,
+                remainingSwaps: nil,
@@ -125 +128 @@
-                clearedByKind: state.clearedByKind
+                clearedByKind: state.clearedByKind, swapsUsed: swapsUsed
@@ -128 +131 @@
-        case .scoreAttack(let duration):
+        case .timed(let duration):
@@ -138 +140,0 @@
-                score: state.score,
@@ -141 +143 @@
-                targetScore: nil,
+                remainingSwaps: nil,
@@ -144 +146 @@
-                clearedByKind: state.clearedByKind
+                clearedByKind: state.clearedByKind, swapsUsed: swapsUsed
@@ -147 +149 @@
-        case .speedRun(let targetScore):
+        case .moves(let limit):
@@ -150 +151,0 @@
-                score: state.score,
@@ -153 +154 @@
-                targetScore: targetScore,
+                remainingSwaps: max(0, limit - swapsUsed),
@@ -156 +157 @@
-                clearedByKind: state.clearedByKind
+                clearedByKind: state.clearedByKind, swapsUsed: swapsUsed
@@ -179,0 +181 @@
+        guard (0..<columnsCount).contains(index) else { return false }
@@ -220,0 +223,2 @@
+        // 每次实际完成的合法交换只扣一步；无消除也计次，所有自动连锁归入同一步。
+        swapsUsed += 1
@@ -227 +231 @@
-        achievements.recordSwap(roundID: roundID, swapID: UUID(), result: state.lastResolution, score: state.score, at: now)
+        achievements.recordSwap(roundID: roundID, swapID: UUID(), result: state.lastResolution, roundCleared: state.totalCleared, at: now)
@@ -261,0 +266 @@
+        swapsUsed = 0
@@ -291 +296 @@
-        case .scoreAttack(let duration):
+        case .timed(let duration):
@@ -293,2 +298,2 @@
-        case .speedRun(let targetScore):
-            isFinished = state.score >= targetScore
+        case .moves(let limit):
+            isFinished = swapsUsed >= limit
@@ -302 +307 @@
-            achievements.finishRound(id: roundID, mode: mode, score: state.score, elapsed: elapsed, at: now)
+            achievements.finishRound(id: roundID, mode: mode, clearedCount: state.totalCleared, swapsUsed: swapsUsed, elapsed: elapsed, at: now)
```

### `Sources/GameViewController.swift`

```diff
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -114,8 +114,8 @@
-            if snapshot.score > 0 {
-                switch snapshot.mode {
-                case .scoreAttack:
-                    _ = recordStore.addScoreAttackRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, durationMinutes: 1)
-                case .speedRun:
-                    _ = recordStore.addSpeedRunRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, targetScore: HomeGameMode.speedRunTarget)
-                case .free: break
-                }
+            switch snapshot.mode {
+            case .timed(let duration):
+                _ = recordStore.addRecord(mode: .timed, detailValue: Int(duration), clearedCount: snapshot.totalCleared,
+                                          swapsUsed: snapshot.swapsUsed, elapsedTime: snapshot.elapsedTime)
+            case .moves(let limit):
+                _ = recordStore.addRecord(mode: .moves, detailValue: limit, clearedCount: snapshot.totalCleared,
+                                          swapsUsed: snapshot.swapsUsed, elapsedTime: snapshot.elapsedTime)
+            case .free: break
@@ -124 +124 @@
-        if snapshot.isRunning, selection != .free, !snapshot.isFinished {
+        if snapshot.isRunning, selection == .timed, !snapshot.isFinished {
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -118 +118 @@
-        HomeStyle.text(AchievementText.string("banner.total_cleared"), in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: 20, weight: .bold)
+        HomeStyle.text(AchievementText.string("home.cleared_title"), in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: 20, weight: .bold)
@@ -228,3 +228 @@
-            hint.stringValue = mode == .speedRun
-                ? AchievementText.format("result.speed_run_finished", Self.clock(snapshot.elapsedTime))
-                : AchievementText.format("result.score_attack_finished", snapshot.score)
+            hint.stringValue = AchievementText.format("home.result", snapshot.totalCleared)
@@ -232,3 +230,3 @@
-            hint.stringValue = mode == .scoreAttack
-                ? AchievementText.format("hud.score_attack", snapshot.score, Self.clock(snapshot.remainingTime ?? 0))
-                : AchievementText.format("hud.speed_run", snapshot.score, HomeGameMode.speedRunTarget, Self.clock(snapshot.elapsedTime))
+            hint.stringValue = mode == .timed
+                ? AchievementText.format("home.hud.timed", snapshot.totalCleared, Self.clock(snapshot.remainingTime ?? 0))
+                : AchievementText.format("home.hud.moves", snapshot.totalCleared, snapshot.remainingSwaps ?? 0)
```

### `Sources/HomeUtilityPanel.swift`

```diff
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -23,0 +24 @@
+    private var showingHistory = false
@@ -40 +41 @@
-        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = ["trophy", "stopwatch"]
+        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = ["stopwatch", "arrow.left.arrow.right"]
@@ -64 +65 @@
-            let ids = recordEntries(.scoreAttack).map(\.id) + recordEntries(.speedRun).map(\.id)
+            let ids = recordEntries(.timed).map(\.id) + recordEntries(.moves).map(\.id)
@@ -68,2 +69,2 @@
-                recordTabs.setLabel(UtilityStyle.text("home.mode.score_attack"), forSegment: 0)
-                recordTabs.setLabel(UtilityStyle.text("home.mode.speed_run"), forSegment: 1)
+                recordTabs.setLabel(UtilityStyle.text("home.mode.timed"), forSegment: 0)
+                recordTabs.setLabel(UtilityStyle.text("home.mode.moves"), forSegment: 1)
@@ -71 +72 @@
-            recordTabs.updateCounts([recordEntries(.scoreAttack).count, recordEntries(.speedRun).count]); recordTabs.refreshMetrics()
+            recordTabs.updateCounts([recordEntries(.timed).count, recordEntries(.moves).count]); recordTabs.refreshMetrics()
@@ -100 +101 @@
-    private func recordEntries(_ mode: ModeRecordKey) -> [ModeRecord] { store.records(for: mode, detailValue: mode == .scoreAttack ? 1 : 300) }
+    private func recordEntries(_ mode: ModeRecordKey) -> [ModeRecord] { store.records(for: mode, detailValue: mode == .timed ? 60 : 30) }
@@ -104 +105 @@
-        let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .scoreAttack : .speedRun
+        let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .timed : .moves
@@ -107,0 +109,18 @@
+        }
+        let sections = store.legacySections()
+        if !sections.isEmpty {
+            let historyButton = HomeButton(frame: .zero)
+            historyButton.title = UtilityStyle.text(showingHistory ? "utility.records.hide_history" : "utility.records.show_history")
+            historyButton.symbolName = "clock"
+            historyButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
+            historyButton.onClick = { [weak self] in
+                guard let self else { return }
+                self.showingHistory.toggle(); self.refreshRecords(); self.content.layoutSubtreeIfNeeded()
+            }
+            recordBody.addArrangedSubview(historyButton); UtilityStyle.fillWidth(historyButton, in: recordBody)
+            if showingHistory {
+                for section in sections {
+                    let card = UtilityRecordContent.legacyTable(section)
+                    recordBody.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: recordBody)
+                }
+            }
```

### `Sources/HomeUtilityViews.swift`

```diff
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -245 +245 @@
-        let metric = entry.map { mode == .scoreAttack ? String($0.score) : String(format: "%.2f", $0.elapsedTime) } ?? "—"
+        let metric = entry.map { String($0.clearedCount) } ?? "—"
@@ -248 +248 @@
-        let unit = UtilityStyle.label(UtilityStyle.text(mode == .scoreAttack ? "utility.unit.points" : "utility.unit.seconds"), size: 13, weight: .semibold, color: HomeStyle.secondary)
+        let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeStyle.secondary)
@@ -252 +252 @@
-            UtilityStyle.label(UtilityStyle.text(mode == .scoreAttack ? "utility.records.score_rule" : "utility.records.speed_rule"), size: 11, color: HomeStyle.secondary)
+            UtilityStyle.label(UtilityStyle.text(mode == .timed ? "utility.records.timed_rule" : "utility.records.moves_rule"), size: 11, color: HomeStyle.secondary)
@@ -254 +254 @@
-        let icon = UtilityStyle.icon(mode == .scoreAttack ? "trophy" : "stopwatch", color: .systemOrange, size: 56)
+        let icon = UtilityStyle.icon(mode == .timed ? "stopwatch" : "arrow.left.arrow.right", color: .systemOrange, size: 56)
@@ -281,0 +282 @@
+        let ranks = ModeRecordStore.ranks(for: entries)
@@ -285 +286 @@
-            let rank = UtilityRankView(rank: index + 1)
+            let rank = UtilityRankView(rank: ranks[index])
@@ -288,5 +289,4 @@
-            let metric = mode == .scoreAttack ? AchievementText.format("records.metric.score", entry.score)
-                : String(format: "%.2f", entry.elapsedTime) + " " + UtilityStyle.text("utility.unit.seconds")
-            let score = UtilityStyle.label(metric, size: 15, weight: index == 0 ? .bold : .semibold)
-            score.font = .monospacedDigitSystemFont(ofSize: 15, weight: index == 0 ? .bold : .semibold)
-            score.setContentHuggingPriority(.defaultLow, for: .horizontal)
+            let metric = AchievementText.format("records.metric.cleared", entry.clearedCount)
+            let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold)
+            countLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: ranks[index] == 1 ? .bold : .semibold)
+            countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
@@ -296 +296 @@
-            let row = UtilityStyle.stack([rank, score, date], vertical: false, spacing: 12)
+            let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 12)
@@ -299 +299 @@
-            row.setAccessibilityLabel("\(index + 1). \(metric), \(date.stringValue)")
+            row.setAccessibilityLabel("\(ranks[index]). \(metric), \(date.stringValue)")
@@ -313,0 +314,14 @@
+
+    static func legacyTable(_ section: LegacyRecordSection) -> NSView {
+        let stack = UtilityStyle.stack([], spacing: 8)
+        let title = AchievementText.format(section.kind == .scoreAttack ? "utility.records.legacy_score" : "utility.records.legacy_speed", section.ruleValue)
+        let heading = UtilityStyle.label(title, size: 13, weight: .bold)
+        stack.addArrangedSubview(heading); UtilityStyle.fillWidth(heading, in: stack)
+        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
+        for (index, record) in section.entries.enumerated() {
+            let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
+            let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeStyle.secondary)
+            stack.addArrangedSubview(label); UtilityStyle.fillWidth(label, in: stack)
+        }
+        return UtilityCard(stack, tint: NSColor(calibratedWhite: 0.975, alpha: 1), padding: 16)
+    }
```

### `Sources/ModeRecordStore.swift`

```diff
--- a/Sources/ModeRecordStore.swift
+++ b/Sources/ModeRecordStore.swift
@@ -3,3 +3,2 @@
-enum ModeRecordKey: String, Codable {
-    case scoreAttack = "score_attack"
-    case speedRun = "speed_run"
+enum ModeRecordKey: String, Codable, CaseIterable {
+    case timed, moves
@@ -7,0 +7 @@
+/// 当前挑战仅记录消除数；耗时保留作历史信息，永远不参与新榜单排序。
@@ -8,0 +9,9 @@
+    let id: String
+    let clearedCount: Int
+    let swapsUsed: Int
+    let elapsedTime: TimeInterval
+    let createdAt: TimeInterval
+}
+
+/// 旧版结构只读，用于展示原规则记录，不转换或写回玩家的旧存档。
+struct LegacyModeRecord: Codable {
@@ -16,0 +26,7 @@
+struct LegacyRecordSection {
+    enum Kind: String { case scoreAttack, speedRun }
+    let kind: Kind
+    let ruleValue: Int
+    let entries: [LegacyModeRecord]
+}
+
@@ -18,0 +35,6 @@
+    static let storageKey = "challenge_records_v2"
+    static let legacyStorageKey = "mode_records_v1"
+    private let defaults: UserDefaults
+    private var buckets: [String: [ModeRecord]] = [:]
+    private var history: [LegacyRecordSection] = []
+    private let maximumRecords = 9
@@ -20,33 +42 @@
-    static func scopeID(mode: ModeRecordKey, detailValue: Int) -> String {
-        return "\(mode.rawValue)_\(detailValue)"
-    }
-
-    private static let developmentModeEnvironmentKey = "ELIMINATE_DEVELOPMENT_MODE"
-
-    private static var shouldInjectDevelopmentSeedRecords: Bool {
-        let rawValue = ProcessInfo.processInfo.environment[developmentModeEnvironmentKey]?
-            .trimmingCharacters(in: .whitespacesAndNewlines)
-            .lowercased()
-
-        switch rawValue {
-        case "1", "true", "yes", "on", "debug":
-            return true
-        case "0", "false", "no", "off", "release":
-            return false
-        default:
-#if DEBUG
-            return true
-#else
-            return false
-#endif
-        }
-    }
-
-    private let storageKey = "mode_records_v1"
-    private let seedVersionKey = "mode_records_seed_version"
-    private let seedVersion = 5
-    private let maxRecordsPerScope = 9
-    private let scoreAttackDurations = [1, 2, 3]
-    private let speedRunTargets = [300, 600, 900]
-    private let defaults: UserDefaults
-    private var recordsByScope: [String: [ModeRecord]] = [:]
+    static func scopeID(mode: ModeRecordKey, detailValue: Int) -> String { "\(mode.rawValue)_\(detailValue)" }
@@ -56,12 +46,10 @@
-        load()
-        var shouldSave = normalizeBucketsToMaxCount()
-
-        if Self.shouldInjectDevelopmentSeedRecords {
-            // 开发模式下确保测试记录存在，便于持续验证 0/1/9 条等边界展示。
-            if synchronizeDevelopmentSeedRecords() {
-                shouldSave = true
-            }
-        } else {
-            // 非开发模式启动时主动清掉旧 seed，避免历史调试数据泄漏到正式体验。
-            if removeSeedRecordsIfNeeded() {
-                shouldSave = true
+        // 新旧存档分开加载，打开新版不会改写旧榜单，也不会生成开发用虚构成绩。
+        if let data = defaults.data(forKey: Self.storageKey),
+           let decoded = try? JSONDecoder().decode([String: [ModeRecord]].self, from: data) {
+            for (key, entries) in decoded {
+                var seen: Set<String> = []
+                let valid = entries.filter {
+                    !$0.id.isEmpty && $0.clearedCount >= 0 && $0.swapsUsed >= 0 &&
+                    $0.elapsedTime.isFinite && $0.elapsedTime >= 0 && $0.createdAt.isFinite && seen.insert($0.id).inserted
+                }
+                buckets[key] = Array(sorted(valid).prefix(maximumRecords))
@@ -70,4 +58 @@
-
-        if shouldSave {
-            save()
-        }
+        loadHistory()
@@ -77,2 +62 @@
-        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
-        return recordsByScope[scopeID] ?? []
+        buckets[Self.scopeID(mode: mode, detailValue: detailValue)] ?? []
@@ -81,57 +65,6 @@
-    @discardableResult
-    func addScoreAttackRecord(score: Int, elapsedTime: TimeInterval, durationMinutes: Int) -> ModeRecord? {
-        let minutes = max(1, durationMinutes)
-        let record = ModeRecord(
-            id: UUID().uuidString,
-            score: score,
-            elapsedTime: elapsedTime,
-            durationMinutes: minutes,
-            targetScore: nil,
-            createdAt: Date().timeIntervalSince1970
-        )
-
-        return append(record, for: .scoreAttack, detailValue: minutes)
-    }
-
-    @discardableResult
-    func addSpeedRunRecord(score: Int, elapsedTime: TimeInterval, targetScore: Int) -> ModeRecord? {
-        let clampedTarget = max(1, targetScore)
-        let record = ModeRecord(
-            id: UUID().uuidString,
-            score: score,
-            elapsedTime: elapsedTime,
-            durationMinutes: nil,
-            targetScore: clampedTarget,
-            createdAt: Date().timeIntervalSince1970
-        )
-
-        return append(record, for: .speedRun, detailValue: clampedTarget)
-    }
-
-    @discardableResult
-    private func append(_ record: ModeRecord, for mode: ModeRecordKey, detailValue: Int) -> ModeRecord? {
-        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
-        var bucket = recordsByScope[scopeID] ?? []
-        bucket.append(record)
-        sortAndTrim(&bucket, for: mode)
-
-        recordsByScope[scopeID] = bucket
-        save()
-
-        guard bucket.contains(where: { $0.id == record.id }) else {
-            return nil
-        }
-
-        return record
-    }
-
-    private func sortAndTrim(_ bucket: inout [ModeRecord], for mode: ModeRecordKey) {
-        switch mode {
-        case .scoreAttack:
-            bucket.sort(by: compareScoreAttackRecords)
-        case .speedRun:
-            bucket.sort(by: compareSpeedRunRecords)
-        }
-
-        if bucket.count > maxRecordsPerScope {
-            bucket = Array(bucket.prefix(maxRecordsPerScope))
+    /// 同数量共享名次，后续跳过相应序号；日期仅用于稳定展示，不改变并列关系。
+    static func ranks(for entries: [ModeRecord]) -> [Int] {
+        var rank = 0
+        return entries.enumerated().map { index, record in
+            if index == 0 || record.clearedCount != entries[index - 1].clearedCount { rank = index + 1 }
+            return rank
@@ -142,11 +75,7 @@
-    private func synchronizeDevelopmentSeedRecords() -> Bool {
-        var changed = false
-
-        for minutes in scoreAttackDurations {
-            if ensureSeedRecords(
-                for: .scoreAttack,
-                detailValue: minutes,
-                seeds: makeScoreAttackSeedRecords(durationMinutes: minutes)
-            ) {
-                changed = true
-            }
+    func addRecord(mode: ModeRecordKey, detailValue: Int, clearedCount: Int, swapsUsed: Int,
+                   elapsedTime: TimeInterval) -> ModeRecord? {
+        guard detailValue > 0, clearedCount >= 0, swapsUsed >= 0, elapsedTime.isFinite, elapsedTime >= 0 else { return nil }
+        // 只接纳自然完成的挑战，零消除也是有效结果；成就另行判断是否达标。
+        switch mode {
+        case .timed: guard elapsedTime >= Double(detailValue) else { return nil }
+        case .moves: guard swapsUsed == detailValue else { return nil }
@@ -154,17 +83,6 @@
-
-        for targetScore in speedRunTargets {
-            if ensureSeedRecords(
-                for: .speedRun,
-                detailValue: targetScore,
-                seeds: makeSpeedRunSeedRecords(targetScore: targetScore)
-            ) {
-                changed = true
-            }
-        }
-
-        if defaults.integer(forKey: seedVersionKey) < seedVersion {
-            defaults.set(seedVersion, forKey: seedVersionKey)
-            changed = true
-        }
-
-        return changed
+        let record = ModeRecord(id: UUID().uuidString, clearedCount: clearedCount, swapsUsed: swapsUsed,
+                                elapsedTime: elapsedTime, createdAt: Date().timeIntervalSince1970)
+        let key = Self.scopeID(mode: mode, detailValue: detailValue)
+        buckets[key] = Array(sorted((buckets[key] ?? []) + [record]).prefix(maximumRecords))
+        if let data = try? JSONEncoder().encode(buckets) { defaults.set(data, forKey: Self.storageKey) }
+        return buckets[key]?.contains(where: { $0.id == record.id }) == true ? record : nil
@@ -173,5 +91 @@
-    @discardableResult
-    private func ensureSeedRecords(for mode: ModeRecordKey, detailValue: Int, seeds: [ModeRecord]) -> Bool {
-        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
-        let originalBucket = recordsByScope[scopeID] ?? []
-        var bucket = originalBucket
+    func legacySections() -> [LegacyRecordSection] { history }
@@ -179,70 +93,5 @@
-        // 仅包含 seed 的旧分桶直接替换，确保 seed 策略升级后可生效。
-        if bucket.isEmpty || bucket.allSatisfy({ Self.isSeedRecordID($0.id) }) {
-            bucket = seeds
-            sortAndTrim(&bucket, for: mode)
-            recordsByScope[scopeID] = bucket
-            return hasDifferentRecords(lhs: originalBucket, rhs: bucket)
-        }
-
-        guard bucket.count < maxRecordsPerScope else { return false }
-
-        let existingIDs = Set(bucket.map(\.id))
-        let availableSeeds = seeds.filter { !existingIDs.contains($0.id) }
-        let missingCount = maxRecordsPerScope - bucket.count
-        bucket.append(contentsOf: availableSeeds.prefix(missingCount))
-        sortAndTrim(&bucket, for: mode)
-
-        recordsByScope[scopeID] = bucket
-        return hasDifferentRecords(lhs: originalBucket, rhs: bucket)
-    }
-
-    @discardableResult
-    private func removeSeedRecordsIfNeeded() -> Bool {
-        var changed = false
-
-        for (scopeID, bucket) in recordsByScope {
-            let filtered = bucket.filter { !Self.isSeedRecordID($0.id) }
-            guard hasDifferentRecords(lhs: bucket, rhs: filtered) else { continue }
-
-            changed = true
-            if filtered.isEmpty {
-                recordsByScope.removeValue(forKey: scopeID)
-            } else {
-                recordsByScope[scopeID] = filtered
-            }
-        }
-
-        return changed
-    }
-
-    private func hasDifferentRecords(lhs: [ModeRecord], rhs: [ModeRecord]) -> Bool {
-        guard lhs.count == rhs.count else { return true }
-
-        for (left, right) in zip(lhs, rhs) {
-            if left.id != right.id ||
-                left.score != right.score ||
-                left.elapsedTime != right.elapsedTime ||
-                left.durationMinutes != right.durationMinutes ||
-                left.targetScore != right.targetScore ||
-                left.createdAt != right.createdAt {
-                return true
-            }
-        }
-
-        return false
-    }
-
-    private func makeScoreAttackSeedRecords(durationMinutes: Int) -> [ModeRecord] {
-        let baseTime = Date().addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970 + Double(durationMinutes * 100)
-        let baseScore = 420 - durationMinutes * 12
-        let seedCount = seedRecordCount(for: .scoreAttack, detailValue: durationMinutes)
-
-        return (0..<seedCount).map { rank in
-            ModeRecord(
-                id: "seed_score_attack_\(durationMinutes)_\(rank)",
-                score: max(80, baseScore - rank * 9),
-                elapsedTime: TimeInterval(durationMinutes * 60),
-                durationMinutes: durationMinutes,
-                targetScore: nil,
-                createdAt: baseTime + Double(rank)
-            )
+    private func sorted(_ records: [ModeRecord]) -> [ModeRecord] {
+        records.sorted {
+            if $0.clearedCount != $1.clearedCount { return $0.clearedCount > $1.clearedCount }
+            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
+            return $0.id < $1.id
@@ -252,19 +101,27 @@
-    private func makeSpeedRunSeedRecords(targetScore: Int) -> [ModeRecord] {
-        let baseElapsedByTarget: [Int: Int] = [
-            300: 54,
-            600: 108,
-            900: 156
-        ]
-        let baseElapsed = baseElapsedByTarget[targetScore] ?? max(45, targetScore / 6)
-        let baseTime = Date().addingTimeInterval(-6 * 24 * 60 * 60).timeIntervalSince1970 + Double(targetScore)
-        let seedCount = seedRecordCount(for: .speedRun, detailValue: targetScore)
-
-        return (0..<seedCount).map { rank in
-            ModeRecord(
-                id: "seed_speed_run_\(targetScore)_\(rank)",
-                score: targetScore,
-                elapsedTime: TimeInterval(baseElapsed + rank * 4),
-                durationMinutes: nil,
-                targetScore: targetScore,
-                createdAt: baseTime + Double(rank)
-            )
+    private func loadHistory() {
+        guard let data = defaults.data(forKey: Self.legacyStorageKey),
+              let decoded = try? JSONDecoder().decode([String: [LegacyModeRecord]].self, from: data) else { return }
+        var grouped: [String: [LegacyModeRecord]] = [:]
+        var kinds: [String: (LegacyRecordSection.Kind, Int)] = [:]
+        var seen: Set<String> = []
+        for (scope, records) in decoded {
+            for record in records where !record.id.hasPrefix("seed_") && record.score >= 0 &&
+                record.elapsedTime.isFinite && record.elapsedTime >= 0 && record.createdAt.isFinite {
+                let kind: LegacyRecordSection.Kind = scope.hasPrefix("score_attack") ? .scoreAttack : .speedRun
+                guard scope.hasPrefix("score_attack") || scope.hasPrefix("speed_run"),
+                      let rule = kind == .scoreAttack ? record.durationMinutes : record.targetScore,
+                      rule > 0, seen.insert(record.id).inserted else { continue }
+                let key = "\(kind.rawValue).\(rule)"
+                grouped[key, default: []].append(record); kinds[key] = (kind, rule)
+            }
+        }
+        history = kinds.map { key, value in
+            let entries = (grouped[key] ?? []).sorted {
+                if value.0 == .scoreAttack, $0.score != $1.score { return $0.score > $1.score }
+                if $0.elapsedTime != $1.elapsedTime { return $0.elapsedTime < $1.elapsedTime }
+                return $0.createdAt < $1.createdAt
+            }
+            return LegacyRecordSection(kind: value.0, ruleValue: value.1, entries: entries)
+        }.sorted {
+            if $0.kind != $1.kind { return $0.kind == .scoreAttack }
+            return $0.ruleValue < $1.ruleValue
@@ -273,159 +129,0 @@
-
-    private func seedRecordCount(for mode: ModeRecordKey, detailValue: Int) -> Int {
-        switch mode {
-        case .scoreAttack:
-            switch detailValue {
-            case 1:
-                return maxRecordsPerScope
-            case 2:
-                return 1
-            case 3:
-                return 0
-            default:
-                return maxRecordsPerScope
-            }
-
-        case .speedRun:
-            switch detailValue {
-            case 300:
-                return maxRecordsPerScope
-            case 600:
-                return 1
-            case 900:
-                return 0
-            default:
-                return maxRecordsPerScope
-            }
-        }
-    }
-
-    private static func isSeedRecordID(_ id: String) -> Bool {
-        return id.hasPrefix("seed_score_attack_") || id.hasPrefix("seed_speed_run_")
-    }
-
-    private func normalizeBucketsToMaxCount() -> Bool {
-        var changed = false
-
-        for (scopeID, bucket) in recordsByScope {
-            guard let mode = modeKey(forScopeID: scopeID) else { continue }
-
-            var normalized = bucket
-            sortAndTrim(&normalized, for: mode)
-            if normalized.map(\.id) != bucket.map(\.id) {
-                changed = true
-            }
-
-            recordsByScope[scopeID] = normalized
-        }
-
-        return changed
-    }
-
-    private func modeKey(forScopeID scopeID: String) -> ModeRecordKey? {
-        if scopeID.hasPrefix("\(ModeRecordKey.scoreAttack.rawValue)_") || scopeID == ModeRecordKey.scoreAttack.rawValue {
-            return .scoreAttack
-        }
-        if scopeID.hasPrefix("\(ModeRecordKey.speedRun.rawValue)_") || scopeID == ModeRecordKey.speedRun.rawValue {
-            return .speedRun
-        }
-        return nil
-    }
-
-    private func compareScoreAttackRecords(_ lhs: ModeRecord, _ rhs: ModeRecord) -> Bool {
-        if lhs.score != rhs.score {
-            return lhs.score > rhs.score
-        }
-
-        let lhsMinutes = lhs.durationMinutes ?? Int.max
-        let rhsMinutes = rhs.durationMinutes ?? Int.max
-        if lhsMinutes != rhsMinutes {
-            return lhsMinutes < rhsMinutes
-        }
-
-        if abs(lhs.elapsedTime - rhs.elapsedTime) > 0.0001 {
-            return lhs.elapsedTime < rhs.elapsedTime
-        }
-
-        return lhs.createdAt < rhs.createdAt
-    }
-
-    private func compareSpeedRunRecords(_ lhs: ModeRecord, _ rhs: ModeRecord) -> Bool {
-        if abs(lhs.elapsedTime - rhs.elapsedTime) > 0.0001 {
-            return lhs.elapsedTime < rhs.elapsedTime
-        }
-
-        let lhsTarget = lhs.targetScore ?? 0
-        let rhsTarget = rhs.targetScore ?? 0
-        if lhsTarget != rhsTarget {
-            return lhsTarget > rhsTarget
-        }
-
-        if lhs.score != rhs.score {
-            return lhs.score > rhs.score
-        }
-
-        return lhs.createdAt < rhs.createdAt
-    }
-
-    private func load() {
-        guard let data = defaults.data(forKey: storageKey) else { return }
-
-        let decoder = JSONDecoder()
-        guard let decoded = try? decoder.decode([String: [ModeRecord]].self, from: data) else {
-            return
-        }
-
-        recordsByScope = decoded
-        if migrateLegacyBucketsIfNeeded() {
-            save()
-        }
-    }
-
-    @discardableResult
-    private func migrateLegacyBucketsIfNeeded() -> Bool {
-        var changed = false
-
-        for mode in [ModeRecordKey.scoreAttack, ModeRecordKey.speedRun] {
-            let legacyKey = mode.rawValue
-            guard let legacyRecords = recordsByScope.removeValue(forKey: legacyKey) else {
-                continue
-            }
-
-            changed = true
-            for record in legacyRecords {
-                guard let detailValue = detailValue(for: mode, record: record) else {
-                    continue
-                }
-
-                let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
-                var bucket = recordsByScope[scopeID] ?? []
-                bucket.append(record)
-                sortAndTrim(&bucket, for: mode)
-                recordsByScope[scopeID] = bucket
-            }
-        }
-
-        return changed
-    }
-
-    private func detailValue(for mode: ModeRecordKey, record: ModeRecord) -> Int? {
-        switch mode {
-        case .scoreAttack:
-            guard let minutes = record.durationMinutes, minutes > 0 else {
-                return nil
-            }
-            return minutes
-
-        case .speedRun:
-            guard let target = record.targetScore, target > 0 else {
-                return nil
-            }
-            return target
-        }
-    }
-
-    private func save() {
-        let encoder = JSONEncoder()
-        guard let data = try? encoder.encode(recordsByScope) else { return }
-        defaults.set(data, forKey: storageKey)
-    }
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -87 +87 @@
-"achievement.1.desc" = "Reach 100 points in one round of any mode.";
+"achievement.1.desc" = "Clear at least 10 tiles in one round of any mode.";
@@ -89 +89 @@
-"achievement.2.desc" = "Score on 3 swaps in a row, with no more than 1.6 seconds between swaps. A swap without a clear breaks the streak.";
+"achievement.2.desc" = "Make 3 clearing swaps in a row, no more than 1.6 seconds apart. A non-clearing swap breaks the streak.";
@@ -91 +91 @@
-"achievement.3.desc" = "Finish a Score Attack or Speed Run round with a positive score.";
+"achievement.3.desc" = "Finish a Timed or Swap Challenge with at least one tile cleared.";
@@ -105 +105 @@
-"achievement.10.desc" = "Finish a 1-minute Score Attack with at least 300 points.";
+"achievement.10.desc" = "Finish a 60-second Timed Challenge with at least 30 tiles cleared.";
@@ -107,11 +107,11 @@
-"achievement.11.desc" = "Finish a 1-minute Score Attack with at least 600 points.";
-"achievement.12.title" = "Score Limit Break";
-"achievement.12.desc" = "Finish a 1-minute Score Attack with at least 900 points.";
-"achievement.13.title" = "First Finish Line";
-"achievement.13.desc" = "Complete a 300-point Speed Run.";
-"achievement.14.title" = "Picking Up Speed";
-"achievement.14.desc" = "Complete a 300-point Speed Run in 45 seconds or less.";
-"achievement.15.title" = "Lightning Sprint";
-"achievement.15.desc" = "Complete a 300-point Speed Run in 30 seconds or less.";
-"achievement.16.title" = "Every Second Counts";
-"achievement.16.desc" = "Complete a 300-point Speed Run in 60 seconds or less.";
+"achievement.11.desc" = "Finish a 60-second Timed Challenge with at least 60 tiles cleared.";
+"achievement.12.title" = "Clear the Limit";
+"achievement.12.desc" = "Finish a 60-second Timed Challenge with at least 90 tiles cleared.";
+"achievement.13.title" = "Thirty-Swap Journey";
+"achievement.13.desc" = "Use all 30 swaps to finish Swap Challenge with at least one clear.";
+"achievement.14.title" = "Make Every Swap Count";
+"achievement.14.desc" = "Finish a 30-swap challenge with at least 30 tiles cleared.";
+"achievement.15.title" = "Thoughtful Victory";
+"achievement.15.desc" = "Finish a 30-swap challenge with at least 60 tiles cleared.";
+"achievement.16.title" = "A Full Minute";
+"achievement.16.desc" = "Finish a 60-second Timed Challenge with at least one clear.";
@@ -125 +125 @@
-"achievement.20.desc" = "Finish 20 Score Attack or Speed Run rounds. Zero-point Score Attack rounds do not count.";
+"achievement.20.desc" = "Finish 20 Timed or Swap Challenges with at least one clear each.";
@@ -147 +147 @@
-"achievement.progress.legacy" = "Unlocked in an earlier version; past progress was not recorded";
+"achievement.progress.legacy" = "Unlocked under previous rules; new goal not yet reached";
@@ -185,2 +185,2 @@
-"home.hero.speed_run" = "Beat the clock.\nFind your flow.";
-"home.hero.score_attack" = "Keep it going.\nChase your best.";
+"home.hero.timed" = "One minute.\nMake it count.";
+"home.hero.moves" = "Thirty swaps.\nThink ahead.";
@@ -188,2 +188,2 @@
-"home.subtitle.speed_run" = "Reach 300 points as quickly as you can.";
-"home.subtitle.score_attack" = "One minute. Make every swap count.";
+"home.subtitle.timed" = "Clear as many tiles as you can in one minute.";
+"home.subtitle.moves" = "Take your time. Make every swap worthwhile.";
@@ -191,5 +191,5 @@
-"home.mode.speed_run" = "Speed run";
-"home.mode.score_attack" = "Score attack";
-"home.mode_desc.free" = "No timer or target score.";
-"home.mode_desc.speed_run" = "Finish by reaching 300 points.";
-"home.mode_desc.score_attack" = "60 seconds to chase a high score.";
+"home.mode.timed" = "Timed Challenge";
+"home.mode.moves" = "Swap Challenge";
+"home.mode_desc.free" = "No time or swap limits.";
+"home.mode_desc.timed" = "60 seconds. Clear as many tiles as possible.";
+"home.mode_desc.moves" = "30 swaps. No time limit.";
@@ -202,2 +202,2 @@
-"home.rules.fixed" = "Each cleared tile earns 10 points. Score Attack lasts 60 seconds; Speed Run ends at 300 points. Switching modes or restarting clears this round’s counters. Lifetime achievement progress is saved.";
-"home.records.fixed" = "Fixed rules: 60-second Score Attack · 300-point Speed Run";
+"home.rules.fixed" = "Timed Challenge lasts 60 seconds. Swap Challenge allows 30 swaps. Both rank by tiles cleared. Every legal swap counts, even without a match. Cascades cost no extra swaps; the final swap resolves fully.";
+"home.records.fixed" = "60 seconds or 30 swaps · Ranked by tiles cleared";
@@ -213 +213 @@
-"utility.lesson.0.body" = "Drag neighboring tiles on the Touch Bar. Multi-touch is supported.";
+"utility.lesson.0.body" = "Swap neighboring tiles on the Touch Bar. Every legal swap counts in Swap Challenge.";
@@ -215 +215 @@
-"utility.lesson.1.body" = "Connect at least three tiles of the same kind. Each cleared tile earns 10 points.";
+"utility.lesson.1.body" = "Connect at least three tiles of the same kind. Each cleared tile counts once.";
@@ -217 +217 @@
-"utility.lesson.2.body" = "New tiles fill the gaps. Further matches clear automatically.";
+"utility.lesson.2.body" = "Refill cascades belong to the same swap. The final swap resolves fully.";
@@ -224,2 +223,0 @@
-"utility.records.score_rule" = "Fixed 60 seconds · Higher scores rank first";
-"utility.records.speed_rule" = "Target 300 points · Faster times rank first";
@@ -227 +225 @@
-"utility.records.result" = "Result";
+"utility.records.result" = "Tiles cleared";
@@ -234 +232 @@
-"home.starting_hint" = "Revealing the board. Timing begins when ready.";
+"home.starting_hint" = "Revealing the board. The challenge starts when ready.";
@@ -237,0 +236,14 @@
+
+/* 消除数量与新挑战规则。 */
+"home.cleared_title" = "Tiles cleared";
+"home.hud.timed" = "%d cleared · %@ remaining";
+"home.hud.moves" = "%d cleared · %d swaps left";
+"home.result" = "Round complete · %d tiles cleared";
+"utility.records.timed_rule" = "Fixed 60 seconds · More clears rank higher";
+"utility.records.moves_rule" = "Fixed 30 swaps · Equal clears share a rank";
+"utility.unit.tiles" = "tiles";
+"records.metric.cleared" = "%d tiles";
+"utility.records.show_history" = "View previous rules records";
+"utility.records.hide_history" = "Hide previous rules records";
+"utility.records.legacy_score" = "Previous Score Attack · %d min";
+"utility.records.legacy_speed" = "Previous Speed Run · %d-point target";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -80 +80 @@
-"achievement.1.desc" = "いずれかのモードで、1 回のプレイ中に 100 点に到達する。";
+"achievement.1.desc" = "いずれかのモードで 1 回に 10 個以上消去。";
@@ -82 +82 @@
-"achievement.2.desc" = "1.6 秒以内の間隔で、得点する入れ替えを 3 回連続で行う。消去しない入れ替えで途切れる。";
+"achievement.2.desc" = "消去を伴う交換を 1.6 秒以内の間隔で 3 回連続。消えない交換で中断。";
@@ -84 +84 @@
-"achievement.3.desc" = "得点のあるスコアアタックかスピードランを最後まで完了する。";
+"achievement.3.desc" = "時間制または手数制を、1 個以上消去して完了。";
@@ -98 +98 @@
-"achievement.10.desc" = "1 分のスコアアタックを 300 点以上で最後まで完了する。";
+"achievement.10.desc" = "60 秒の時間制で 30 個以上消去して完了。";
@@ -100,11 +100,11 @@
-"achievement.11.desc" = "1 分のスコアアタックを 600 点以上で完了する。";
-"achievement.12.title" = "限界突破";
-"achievement.12.desc" = "1 分のスコアアタックを 900 点以上で完了する。";
-"achievement.13.title" = "初めてのゴール";
-"achievement.13.desc" = "300 点のスピードランを完了する。";
-"achievement.14.title" = "加速する指先";
-"achievement.14.desc" = "300 点のスピードランを 45 秒以内に完了する。";
-"achievement.15.title" = "電光石火";
-"achievement.15.desc" = "300 点のスピードランを 30 秒以内に完了する。";
-"achievement.16.title" = "一秒を争え";
-"achievement.16.desc" = "300 点のスピードランを 60 秒以内に完了する。";
+"achievement.11.desc" = "60 秒の時間制で 60 個以上消去して完了。";
+"achievement.12.title" = "消去の極み";
+"achievement.12.desc" = "60 秒の時間制で 90 個以上消去して完了。";
+"achievement.13.title" = "30 手の旅";
+"achievement.13.desc" = "30 回交換して手数制を完了。1 個以上の消去が必要。";
+"achievement.14.title" = "一手を大切に";
+"achievement.14.desc" = "30 回の手数制で 30 個以上消去して完了。";
+"achievement.15.title" = "読みの勝利";
+"achievement.15.desc" = "30 回の手数制で 60 個以上消去して完了。";
+"achievement.16.title" = "1 分間の挑戦";
+"achievement.16.desc" = "60 秒の時間制を、1 個以上消去して完了。";
@@ -118 +118 @@
-"achievement.20.desc" = "スコアアタックかスピードランを合計 20 回完了する。0 点のスコアアタックは含まない。";
+"achievement.20.desc" = "時間制または手数制を、1 個以上消去して 20 回完了。";
@@ -140 +140 @@
-"achievement.progress.legacy" = "旧バージョンで達成済み。過去の進捗記録はありません";
+"achievement.progress.legacy" = "旧ルールで解除済み。新しい目標は未達成";
@@ -178,2 +178,2 @@
-"home.hero.speed_run" = "一秒を争い、\nゴールへ。";
-"home.hero.score_attack" = "連鎖をつなぎ、\n最高得点へ。";
+"home.hero.timed" = "1 分間、\n消去に挑戦。";
+"home.hero.moves" = "30 手で、\n先を読もう。";
@@ -181,2 +181,2 @@
-"home.subtitle.speed_run" = "300 点まで、最速の一局に挑戦。";
-"home.subtitle.score_attack" = "60 秒で、最高得点を目指そう。";
+"home.subtitle.timed" = "1 分間でできるだけ多く消そう。";
+"home.subtitle.moves" = "時間を気にせず、一手を大切に。";
@@ -184,5 +184,5 @@
-"home.mode.speed_run" = "スピードラン";
-"home.mode.score_attack" = "スコアアタック";
-"home.mode_desc.free" = "時間・目標点数の制限なし。";
-"home.mode_desc.speed_run" = "300 点に到達すると終了。";
-"home.mode_desc.score_attack" = "制限時間 60 秒で高得点へ。";
+"home.mode.timed" = "時間制チャレンジ";
+"home.mode.moves" = "手数制チャレンジ";
+"home.mode_desc.free" = "時間・交換回数の制限なし。";
+"home.mode_desc.timed" = "制限時間 60 秒。たくさん消そう。";
+"home.mode_desc.moves" = "交換は 30 回。時間制限なし。";
@@ -195,2 +195,2 @@
-"home.rules.fixed" = "1 個消すと 10 点。スコアアタックは 60 秒、スピードランは 300 点で終了。モード変更や再開で一局の記録はリセットされ、実績の累計は保存されます。";
-"home.records.fixed" = "固定ルール：60 秒スコアアタック · 300 点スピードラン";
+"home.rules.fixed" = "時間制は 60 秒、手数制は 30 回交換。消去数で順位を決定。消えない交換も 1 回に数え、連鎖で手数は減りません。最後の交換も連鎖をすべて処理します。";
+"home.records.fixed" = "60 秒・30 回交換 · 消去数で順位決定";
@@ -206 +206 @@
-"utility.lesson.0.body" = "Touch Bar で隣り合うブロックをドラッグ。マルチタッチにも対応。";
+"utility.lesson.0.body" = "Touch Bar で隣接ブロックを交換。手数制では消えない交換も数えます。";
@@ -208 +208 @@
-"utility.lesson.1.body" = "同じ種類を 3 個以上つなげると消去。1 個につき 10 点。";
+"utility.lesson.1.body" = "同じ種類を 3 個以上つなげて消去。実際に消えた数を記録します。";
@@ -210 +210 @@
-"utility.lesson.2.body" = "消去した場所にブロックを補充。再びそろうと自動で連鎖。";
+"utility.lesson.2.body" = "補充による連鎖は同じ一手。最後の交換の連鎖もすべて処理します。";
@@ -217,2 +216,0 @@
-"utility.records.score_rule" = "制限時間 60 秒 · 高得点ほど上位";
-"utility.records.speed_rule" = "目標 300 点 · 短いタイムほど上位";
@@ -220 +218 @@
-"utility.records.result" = "記録";
+"utility.records.result" = "消去数";
@@ -227 +225 @@
-"home.starting_hint" = "盤面が開いたら計測を開始します";
+"home.starting_hint" = "盤面が開いたらチャレンジ開始";
@@ -230,0 +229,14 @@
+
+/* 消除数量与新挑战规则。 */
+"home.cleared_title" = "今回の消去数";
+"home.hud.timed" = "%d 個消去 · 残り %@";
+"home.hud.moves" = "%d 個消去 · 残り %d 回";
+"home.result" = "終了 · 合計 %d 個消去";
+"utility.records.timed_rule" = "60 秒固定 · 消去数が多いほど上位";
+"utility.records.moves_rule" = "30 回交換 · 同じ消去数は同順位";
+"utility.unit.tiles" = "個";
+"records.metric.cleared" = "%d 個";
+"utility.records.show_history" = "旧ルールの記録を見る";
+"utility.records.hide_history" = "旧ルールの記録を閉じる";
+"utility.records.legacy_score" = "旧スコアアタック · %d 分";
+"utility.records.legacy_speed" = "旧スピードラン · 目標 %d 点";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -80 +80 @@
-"achievement.1.desc" = "아무 모드에서 한 판에 100점을 달성하세요.";
+"achievement.1.desc" = "어떤 모드에서든 한 게임에 블록 10개 이상 제거.";
@@ -82 +82 @@
-"achievement.2.desc" = "각 간격이 1.6초 이하가 되도록 점수를 얻는 교환을 3회 연속 수행하세요. 제거 없는 교환은 연속 기록을 끊습니다.";
+"achievement.2.desc" = "1.6초 이내 간격으로 제거되는 교환을 3회 연속 달성. 제거되지 않으면 중단.";
@@ -84 +84 @@
-"achievement.3.desc" = "점수를 얻은 점수 도전 또는 스피드런 한 판을 정상 완료하세요.";
+"achievement.3.desc" = "시간 또는 횟수 도전에서 블록을 1개 이상 제거하고 완료.";
@@ -98 +98 @@
-"achievement.10.desc" = "1분 점수 도전을 300점 이상으로 끝까지 완료하세요.";
+"achievement.10.desc" = "60초 시간 도전을 블록 30개 이상 제거하고 완료.";
@@ -100,11 +100,11 @@
-"achievement.11.desc" = "1분 점수 도전을 600점 이상으로 완료하세요.";
-"achievement.12.title" = "한계 돌파";
-"achievement.12.desc" = "1분 점수 도전을 900점 이상으로 완료하세요.";
-"achievement.13.title" = "첫 결승선";
-"achievement.13.desc" = "300점 스피드런을 완료하세요.";
-"achievement.14.title" = "속도를 높여";
-"achievement.14.desc" = "300점 스피드런을 45초 이내에 완료하세요.";
-"achievement.15.title" = "번개 질주";
-"achievement.15.desc" = "300점 스피드런을 30초 이내에 완료하세요.";
-"achievement.16.title" = "매초가 소중해";
-"achievement.16.desc" = "300점 스피드런을 60초 이내에 완료하세요.";
+"achievement.11.desc" = "60초 시간 도전을 블록 60개 이상 제거하고 완료.";
+"achievement.12.title" = "제거의 극한";
+"achievement.12.desc" = "60초 시간 도전을 블록 90개 이상 제거하고 완료.";
+"achievement.13.title" = "서른 번의 여정";
+"achievement.13.desc" = "블록 1개 이상을 제거하고 교환 30회를 모두 사용해 완료.";
+"achievement.14.title" = "신중한 한 수";
+"achievement.14.desc" = "교환 30회 도전을 블록 30개 이상 제거하고 완료.";
+"achievement.15.title" = "생각의 승리";
+"achievement.15.desc" = "교환 30회 도전을 블록 60개 이상 제거하고 완료.";
+"achievement.16.title" = "온전한 1분";
+"achievement.16.desc" = "60초 시간 도전을 블록 1개 이상 제거하고 완료.";
@@ -118 +118 @@
-"achievement.20.desc" = "점수 도전 또는 스피드런을 총 20판 정상 완료하세요. 0점인 점수 도전은 제외됩니다.";
+"achievement.20.desc" = "시간 또는 횟수 도전을 매번 블록 1개 이상 제거하고 20회 완료.";
@@ -140 +140 @@
-"achievement.progress.legacy" = "이전 버전에서 달성했습니다. 과거 진행 기록은 없습니다";
+"achievement.progress.legacy" = "이전 규칙에서 해제됨. 새 목표는 아직 미달성";
@@ -178,2 +178,2 @@
-"home.hero.speed_run" = "매초를 아끼며,\n결승선까지.";
-"home.hero.score_attack" = "연쇄를 이어,\n최고 점수에.";
+"home.hero.timed" = "1분 동안,\n제거에 집중!";
+"home.hero.moves" = "서른 번의 교환,\n한 수 앞을!";
@@ -181,2 +181,2 @@
-"home.subtitle.speed_run" = "300점에 도달하는 가장 빠른 도전.";
-"home.subtitle.score_attack" = "60초 동안, 최고의 점수를 만들어 보세요.";
+"home.subtitle.timed" = "1분 안에 최대한 많은 블록을 제거하세요.";
+"home.subtitle.moves" = "시간에 쫓기지 말고 매번 신중하게 교환하세요.";
@@ -184,5 +184,5 @@
-"home.mode.speed_run" = "스피드런";
-"home.mode.score_attack" = "점수 도전";
-"home.mode_desc.free" = "시간과 목표 점수 제한 없음.";
-"home.mode_desc.speed_run" = "300점에 도달하면 종료.";
-"home.mode_desc.score_attack" = "60초 동안 최고 점수에 도전.";
+"home.mode.timed" = "시간 도전";
+"home.mode.moves" = "교환 횟수 도전";
+"home.mode_desc.free" = "시간과 교환 횟수 제한 없음.";
+"home.mode_desc.timed" = "제한 시간 60초. 최대한 많이 제거하세요.";
+"home.mode_desc.moves" = "교환 30회. 시간 제한 없음.";
@@ -195,2 +195,2 @@
-"home.rules.fixed" = "블록 하나당 10점입니다. 점수 도전은 60초, 스피드런은 300점에 도달하면 끝납니다. 모드 변경이나 재시작 시 현재 판의 통계는 초기화되며 업적의 누적 진행은 유지됩니다.";
-"home.records.fixed" = "고정 규칙: 60초 점수 도전 · 300점 스피드런";
+"home.rules.fixed" = "시간 도전은 60초, 횟수 도전은 교환 30회입니다. 제거 수로 순위를 정합니다. 제거되지 않은 교환도 횟수를 쓰며 연쇄 제거는 추가 횟수를 쓰지 않습니다. 마지막 교환도 모두 처리됩니다.";
+"home.records.fixed" = "60초 또는 교환 30회 · 제거 수로 순위 결정";
@@ -206 +206 @@
-"utility.lesson.0.body" = "Touch Bar에서 이웃한 블록을 드래그하세요. 멀티 터치도 지원합니다.";
+"utility.lesson.0.body" = "Touch Bar에서 이웃한 블록을 교환하세요. 횟수 도전은 제거되지 않아도 횟수를 씁니다.";
@@ -208 +208 @@
-"utility.lesson.1.body" = "같은 종류를 3개 이상 연결하면 제거됩니다. 블록당 10점입니다.";
+"utility.lesson.1.body" = "같은 종류를 3개 이상 연결해 제거하세요. 실제 제거 수를 기록합니다.";
@@ -210 +210 @@
-"utility.lesson.2.body" = "제거한 자리에 새 블록이 채워집니다. 다시 연결되면 자동으로 제거됩니다.";
+"utility.lesson.2.body" = "채워진 블록의 연쇄도 같은 교환입니다. 마지막 교환의 연쇄도 모두 처리합니다.";
@@ -217,2 +216,0 @@
-"utility.records.score_rule" = "제한 시간 60초 · 점수가 높을수록 높은 순위";
-"utility.records.speed_rule" = "목표 300점 · 시간이 짧을수록 높은 순위";
@@ -220 +218 @@
-"utility.records.result" = "기록";
+"utility.records.result" = "제거 수";
@@ -227 +225 @@
-"home.starting_hint" = "보드가 모두 나타나면 시간이 시작됩니다";
+"home.starting_hint" = "보드가 모두 나타나면 도전이 시작됩니다";
@@ -230,0 +229,14 @@
+
+/* 消除数量与新挑战规则。 */
+"home.cleared_title" = "이번 게임 제거 수";
+"home.hud.timed" = "%d개 제거 · 남은 시간 %@";
+"home.hud.moves" = "%d개 제거 · 남은 교환 %d회";
+"home.result" = "게임 종료 · 총 %d개 제거";
+"utility.records.timed_rule" = "60초 고정 · 제거 수가 많을수록 높은 순위";
+"utility.records.moves_rule" = "교환 30회 · 제거 수가 같으면 공동 순위";
+"utility.unit.tiles" = "개";
+"records.metric.cleared" = "%d개";
+"utility.records.show_history" = "이전 규칙 기록 보기";
+"utility.records.hide_history" = "이전 규칙 기록 접기";
+"utility.records.legacy_score" = "이전 점수 도전 · %d분";
+"utility.records.legacy_speed" = "이전 속도 도전 · 목표 %d점";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -80 +80 @@
-"achievement.1.desc" = "Наберите 100 очков за одну игру в любом режиме.";
+"achievement.1.desc" = "Уберите не менее 10 фигур за один раунд любого режима.";
@@ -82 +82 @@
-"achievement.2.desc" = "Выполните 3 обмена с очками подряд с интервалом не более 1,6 секунды. Обмен без удаления прерывает серию.";
+"achievement.2.desc" = "Три обмена с исчезновением фигур подряд с интервалами не более 1,6 секунды. Обмен без исчезновения прерывает серию.";
@@ -84 +84 @@
-"achievement.3.desc" = "Завершите игру на очки или на скорость с положительным счётом.";
+"achievement.3.desc" = "Завершите испытание на время или ходы, убрав хотя бы одну фигуру.";
@@ -98 +98 @@
-"achievement.10.desc" = "Завершите минутную игру на очки, набрав не менее 300 очков.";
+"achievement.10.desc" = "Завершите 60-секундное испытание, убрав не менее 30 фигур.";
@@ -100,11 +100,11 @@
-"achievement.11.desc" = "Завершите минутную игру на очки с результатом не менее 600.";
-"achievement.12.title" = "За пределами рекорда";
-"achievement.12.desc" = "Завершите минутную игру на очки с результатом не менее 900.";
-"achievement.13.title" = "Первый финиш";
-"achievement.13.desc" = "Завершите игру на скорость до 300 очков.";
-"achievement.14.title" = "Набирая скорость";
-"achievement.14.desc" = "Завершите игру на скорость до 300 очков за 45 секунд или быстрее.";
-"achievement.15.title" = "Молниеносный спринт";
-"achievement.15.desc" = "Завершите игру на скорость до 300 очков за 30 секунд или быстрее.";
-"achievement.16.title" = "Каждая секунда важна";
-"achievement.16.desc" = "Завершите игру на скорость до 300 очков за 60 секунд или быстрее.";
+"achievement.11.desc" = "Завершите 60-секундное испытание, убрав не менее 60 фигур.";
+"achievement.12.title" = "Предел исчезновения";
+"achievement.12.desc" = "Завершите 60-секундное испытание, убрав не менее 90 фигур.";
+"achievement.13.title" = "Тридцать ходов";
+"achievement.13.desc" = "Используйте все 30 обменов, убрав хотя бы одну фигуру.";
+"achievement.14.title" = "Каждый ход важен";
+"achievement.14.desc" = "Завершите испытание на 30 обменов, убрав не менее 30 фигур.";
+"achievement.15.title" = "Продуманная победа";
+"achievement.15.desc" = "Завершите испытание на 30 обменов, убрав не менее 60 фигур.";
+"achievement.16.title" = "Полная минута";
+"achievement.16.desc" = "Завершите 60-секундное испытание, убрав хотя бы одну фигуру.";
@@ -118 +118 @@
-"achievement.20.desc" = "Завершите 20 игр на очки или на скорость. Игры на очки с нулевым счётом не учитываются.";
+"achievement.20.desc" = "Завершите 20 испытаний на время или ходы с хотя бы одной убранной фигурой в каждом.";
@@ -140 +140 @@
-"achievement.progress.legacy" = "Открыто в прежней версии; прошлый прогресс не записывался";
+"achievement.progress.legacy" = "Открыто по прежним правилам; новая цель ещё не достигнута";
@@ -178,2 +178,2 @@
-"home.hero.speed_run" = "Каждая секунда.\nВперёд к финишу.";
-"home.hero.score_attack" = "Продолжай серию.\nПобей рекорд.";
+"home.hero.timed" = "Одна минута.\nБольше фигур!";
+"home.hero.moves" = "Тридцать ходов.\nДумайте вперёд.";
@@ -181,2 +181,2 @@
-"home.subtitle.speed_run" = "Набери 300 очков как можно быстрее.";
-"home.subtitle.score_attack" = "Одна минута, чтобы набрать максимум очков.";
+"home.subtitle.timed" = "Уберите как можно больше фигур за минуту.";
+"home.subtitle.moves" = "Без спешки. Пусть каждый обмен будет полезным.";
@@ -184,5 +184,5 @@
-"home.mode.speed_run" = "На скорость";
-"home.mode.score_attack" = "На очки";
-"home.mode_desc.free" = "Без таймера и цели по очкам.";
-"home.mode_desc.speed_run" = "Финиш при достижении 300 очков.";
-"home.mode_desc.score_attack" = "60 секунд для лучшего результата.";
+"home.mode.timed" = "На время";
+"home.mode.moves" = "На ходы";
+"home.mode_desc.free" = "Без ограничений времени и обменов.";
+"home.mode_desc.timed" = "60 секунд. Уберите как можно больше фигур.";
+"home.mode_desc.moves" = "30 обменов. Время не ограничено.";
@@ -195,2 +195,2 @@
-"home.rules.fixed" = "Каждый удалённый блок даёт 10 очков. Игра на очки длится 60 секунд; игра на скорость завершается при 300 очках. Смена режима или перезапуск обнуляет статистику игры, но сохраняет общий прогресс достижений.";
-"home.records.fixed" = "Правила: 60 секунд на очки · 300 очков на скорость";
+"home.rules.fixed" = "Испытание на время длится 60 секунд, на ходы — 30 обменов. Рейтинг зависит от числа убранных фигур. Обмен без совпадения тоже расходует ход. Цепочки не тратят ходы; последний обмен обрабатывается полностью.";
+"home.records.fixed" = "60 секунд или 30 обменов · Рейтинг по числу фигур";
@@ -206 +206 @@
-"utility.lesson.0.body" = "Перетаскивайте соседние фигуры на Touch Bar. Поддерживается мультитач.";
+"utility.lesson.0.body" = "Меняйте соседние фигуры на Touch Bar. В режиме ходов любой допустимый обмен расходует ход.";
@@ -208 +208 @@
-"utility.lesson.1.body" = "Три и более фигуры одного вида исчезают. Каждая приносит 10 очков.";
+"utility.lesson.1.body" = "Соедините три и более фигуры одного вида. Считаются все убранные фигуры.";
@@ -210 +210 @@
-"utility.lesson.2.body" = "Пустоты заполняются новыми фигурами. Новые совпадения исчезают автоматически.";
+"utility.lesson.2.body" = "Цепочки после заполнения относятся к тому же ходу. Последний обмен обрабатывается полностью.";
@@ -217,2 +216,0 @@
-"utility.records.score_rule" = "60 секунд · Больше очков — выше место";
-"utility.records.speed_rule" = "Цель: 300 очков · Меньше время — выше место";
@@ -220 +218 @@
-"utility.records.result" = "Результат";
+"utility.records.result" = "Убрано";
@@ -227 +225 @@
-"home.starting_hint" = "Открываем поле. Отсчёт начнётся после анимации.";
+"home.starting_hint" = "Открываем поле. Испытание начнётся после анимации.";
@@ -230,0 +229,14 @@
+
+/* 消除数量与新挑战规则。 */
+"home.cleared_title" = "Убрано за раунд";
+"home.hud.timed" = "Убрано: %d · Осталось: %@";
+"home.hud.moves" = "Убрано: %d · Обменов осталось: %d";
+"home.result" = "Раунд завершён · Убрано фигур: %d";
+"utility.records.timed_rule" = "60 секунд · Больше фигур — выше место";
+"utility.records.moves_rule" = "30 обменов · Одинаковое число фигур — общее место";
+"utility.unit.tiles" = "фигур";
+"records.metric.cleared" = "%d фигур";
+"utility.records.show_history" = "Рекорды по прежним правилам";
+"utility.records.hide_history" = "Скрыть прежние рекорды";
+"utility.records.legacy_score" = "Прежний режим очков · %d мин";
+"utility.records.legacy_speed" = "Прежний режим скорости · Цель: %d очков";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -87 +87 @@
-"achievement.1.desc" = "任意模式单局达到 100 分。";
+"achievement.1.desc" = "任意模式单局消除至少 10 个方块。";
@@ -89 +89 @@
-"achievement.2.desc" = "连续 3 次交换均得分，相邻间隔不超过 1.6 秒；不消除的交换会中断。";
+"achievement.2.desc" = "连续 3 次交换均产生消除，相邻间隔不超过 1.6 秒；不消除的交换会中断。";
@@ -91 +91 @@
-"achievement.3.desc" = "正常完成一局有得分的竞分或竞速。";
+"achievement.3.desc" = "正常完成一局有消除的限时或限步挑战。";
@@ -105 +105 @@
-"achievement.10.desc" = "自然完成 1 分钟竞分，并达到 300 分。";
+"achievement.10.desc" = "完成 60 秒限时挑战，并消除至少 30 个方块。";
@@ -107,11 +107,11 @@
-"achievement.11.desc" = "完成 1 分钟竞分，并达到 600 分。";
-"achievement.12.title" = "极限冲分";
-"achievement.12.desc" = "完成 1 分钟竞分，并达到 900 分。";
-"achievement.13.title" = "初见终点";
-"achievement.13.desc" = "完成 300 分竞速。";
-"achievement.14.title" = "加速前进";
-"achievement.14.desc" = "在 45 秒以内完成 300 分竞速。";
-"achievement.15.title" = "极速冲刺";
-"achievement.15.desc" = "在 30 秒以内完成 300 分竞速。";
-"achievement.16.title" = "分秒必争";
-"achievement.16.desc" = "在 60 秒以内完成 300 分竞速。";
+"achievement.11.desc" = "完成 60 秒限时挑战，并消除至少 60 个方块。";
+"achievement.12.title" = "极限消除";
+"achievement.12.desc" = "完成 60 秒限时挑战，并消除至少 90 个方块。";
+"achievement.13.title" = "三十步旅程";
+"achievement.13.desc" = "用完 30 次交换完成限步挑战，并至少消除 1 个方块。";
+"achievement.14.title" = "精打细算";
+"achievement.14.desc" = "完成 30 次交换的限步挑战，并消除至少 30 个方块。";
+"achievement.15.title" = "步步制胜";
+"achievement.15.desc" = "完成 30 次交换的限步挑战，并消除至少 60 个方块。";
+"achievement.16.title" = "坚持一分钟";
+"achievement.16.desc" = "完成 60 秒限时挑战，并至少消除 1 个方块。";
@@ -125 +125 @@
-"achievement.20.desc" = "正常完成 20 局竞分或竞速；零分竞分不计入。";
+"achievement.20.desc" = "正常完成 20 局有消除的限时或限步挑战。";
@@ -147 +147 @@
-"achievement.progress.legacy" = "旧版已解锁，历史进度未记录";
+"achievement.progress.legacy" = "旧规则已解锁，新规则进度尚未达标";
@@ -185,2 +185,2 @@
-"home.hero.speed_run" = "争分夺秒，\n冲向终点。";
-"home.hero.score_attack" = "连消不停，\n挑战高分。";
+"home.hero.timed" = "一分钟，\n消除冲刺。";
+"home.hero.moves" = "三十步，\n步步为营。";
@@ -188,2 +188,2 @@
-"home.subtitle.speed_run" = "冲到 300 分，与自己的速度较量。";
-"home.subtitle.score_attack" = "用 60 秒，创造这一局的最高分。";
+"home.subtitle.timed" = "争取在一分钟内消除更多方块。";
+"home.subtitle.moves" = "不必赶时间，让每一步更有价值。";
@@ -191,2 +191,2 @@
-"home.mode.speed_run" = "竞速模式";
-"home.mode.score_attack" = "竞分模式";
+"home.mode.timed" = "限时挑战";
+"home.mode.moves" = "限步挑战";
@@ -194,2 +194,2 @@
-"home.mode_desc.speed_run" = "达到 300 分即结束。";
-"home.mode_desc.score_attack" = "限时 60 秒，挑战高分。";
+"home.mode_desc.timed" = "限时 60 秒，消除越多越好。";
+"home.mode_desc.moves" = "30 次交换，不限思考时间。";
@@ -202,2 +202,2 @@
-"home.rules.fixed" = "每个消除方块计 10 分。竞分固定 60 秒，竞速固定 300 分；达到条件后自动结束。切换模式或重新开始会清零本局统计，成就累计进度会保留。";
-"home.records.fixed" = "固定规则：竞分 60 秒 · 竞速 300 分";
+"home.rules.fixed" = "限时挑战固定 60 秒，限步挑战固定 30 次交换，均统计消除数量。无消除的合法交换也计次，自动连消不额外扣次，最后一次交换完整结算后结束。";
+"home.records.fixed" = "限时 60 秒 · 限步 30 次交换 · 按消除数量排名";
@@ -213 +213 @@
-"utility.lesson.0.body" = "在触控栏上拖动相邻方块，支持多点触控。";
+"utility.lesson.0.body" = "在触控栏交换相邻方块；限步挑战中，每次合法交换都计次。";
@@ -215,3 +215,3 @@
-"utility.lesson.1.body" = "三个或更多同类方块相连即可消除，每个计 10 分。";
-"utility.lesson.2.title" = "补位接力，连锁得分";
-"utility.lesson.2.body" = "消除后自动补位；再次连成同类方块可继续消除。";
+"utility.lesson.1.body" = "三个或更多同类方块相连即可消除，按实际数量累计。";
+"utility.lesson.2.title" = "补位接力，连锁消除";
+"utility.lesson.2.body" = "补位后的自动连消归入同一次交换，最后一步也完整结算。";
@@ -224,2 +223,0 @@
-"utility.records.score_rule" = "固定 60 秒 · 分数越高，排名越前";
-"utility.records.speed_rule" = "目标 300 分 · 用时越短，排名越前";
@@ -227 +225 @@
-"utility.records.result" = "成绩";
+"utility.records.result" = "消除数";
@@ -234 +232 @@
-"home.starting_hint" = "正在展开触控栏，完成后开始计时";
+"home.starting_hint" = "正在展开触控栏，完成后开始挑战";
@@ -237,0 +236,14 @@
+
+/* 消除数量与新挑战规则。 */
+"home.cleared_title" = "本局消除";
+"home.hud.timed" = "已消除 %d 个 · 剩余 %@";
+"home.hud.moves" = "已消除 %d 个 · 剩余 %d 次交换";
+"home.result" = "本局结束 · 共消除 %d 个方块";
+"utility.records.timed_rule" = "固定 60 秒 · 消除越多，排名越前";
+"utility.records.moves_rule" = "固定 30 次交换 · 同数量并列，不比较用时";
+"utility.unit.tiles" = "个方块";
+"records.metric.cleared" = "%d 个";
+"utility.records.show_history" = "查看旧规则记录";
+"utility.records.hide_history" = "收起旧规则记录";
+"utility.records.legacy_score" = "历史竞分 · %d 分钟（旧规则）";
+"utility.records.legacy_speed" = "历史竞速 · 目标 %d 分（旧规则）";
```

### `Tests/AchievementFilterControlTests.swift`

```diff
--- a/Tests/AchievementFilterControlTests.swift
+++ b/Tests/AchievementFilterControlTests.swift
@@ -29 +29 @@
-        swap(score: 100)
+        swap(roundCleared: 10)
@@ -87 +87 @@
-        swap(score: 100)
+        swap(roundCleared: 10)
```

### `Tests/AchievementPresentationTests.swift`

```diff
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -42 +42 @@
-        swap(score: 100)
+        swap(roundCleared: 10)
```

### `Tests/AchievementsTests.swift`

```diff
--- a/Tests/AchievementsTests.swift
+++ b/Tests/AchievementsTests.swift
@@ -32 +32 @@
-    func swap(at seconds: Double = 0, count: Int = 3, waves: Int = 1, longest: Int = 3, score: Int = 30, id: UUID = UUID()) {
+    func swap(at seconds: Double = 0, count: Int = 3, waves: Int = 1, longest: Int = 3, roundCleared: Int = 3, id: UUID = UUID()) {
@@ -35 +35 @@
-                           score: score, at: date.addingTimeInterval(seconds))
+                           roundCleared: roundCleared, at: date.addingTimeInterval(seconds))
@@ -43 +43 @@
-                           score: total * 10, at: date)
+                           roundCleared: total, at: date)
@@ -68 +68 @@
-        swap(count: 10_000, waves: 3, longest: 5, score: 100_000)
+        swap(count: 10_000, waves: 3, longest: 5, roundCleared: 10_000)
@@ -79,2 +79,2 @@
-        manager.recordSwap(roundID: UUID(), swapID: UUID(), result: .invalid, score: 1000, at: date)
-        manager.recordSwap(roundID: round, swapID: UUID(), result: .invalid, score: 1000, at: date)
+        manager.recordSwap(roundID: UUID(), swapID: UUID(), result: .invalid, roundCleared: 100, at: date)
+        manager.recordSwap(roundID: round, swapID: UUID(), result: .invalid, roundCleared: 100, at: date)
@@ -124,2 +124,2 @@
-            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 60, at: date)
-            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 61, at: date)
+            manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: 3, swapsUsed: 1, elapsed: 60, at: date)
+            manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: 3, swapsUsed: 1, elapsed: 61, at: date)
@@ -131,2 +131,2 @@
-    func testZeroScoreAndPrematureFinishesDoNotCount() {
-        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 59.99, at: date)
+    func testZeroClearsAndPrematureFinishesDoNotCount() {
+        manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: 30, swapsUsed: 10, elapsed: 59.99, at: date)
@@ -134,2 +134,2 @@
-        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 0, elapsed: 60, at: date)
-        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 61, at: date)
+        manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: 0, swapsUsed: 0, elapsed: 60, at: date)
+        manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: 30, swapsUsed: 10, elapsed: 61, at: date)
@@ -138,2 +138,2 @@
-        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 290, elapsed: 10, at: date)
-        manager.finishRound(id: round, mode: .free, score: 1000, elapsed: 100, at: date)
+        manager.finishRound(id: round, mode: .moves(limit: 30), clearedCount: 29, swapsUsed: 29, elapsed: 1000, at: date)
+        manager.finishRound(id: round, mode: .free, clearedCount: 100, swapsUsed: 30, elapsed: 100, at: date)
@@ -143,2 +143,2 @@
-    func testEachFixedScoreAttackThresholdRequiresItsFinishedRound() {
-        for (score, id) in [(300, 10), (600, 11), (900, 12)] {
+    func testTimedThresholdsRequireFinishedRoundAndCounts() {
+        for (count, id) in [(30, 10), (60, 11), (90, 12)] {
@@ -146 +146 @@
-            swap(score: score)
+            swap(roundCleared: count)
@@ -148 +148 @@
-            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: score, elapsed: 60, at: date)
+            manager.finishRound(id: round, mode: .timed(duration: 60), clearedCount: count, swapsUsed: 10, elapsed: 60, at: date)
@@ -151,4 +151,7 @@
-    }
-
-    func testFixedSpeedRunTimeChallengesAndSixtySecondBoundary() {
-        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 60.001, at: date)
+        XCTAssertTrue(manager.isUnlocked(id: 16))
+    }
+
+    func testMoveChallengesIgnoreTimeAndRequireThirtySwaps() {
+        manager.finishRound(id: round, mode: .moves(limit: 30), clearedCount: 60, swapsUsed: 29, elapsed: 30, at: date)
+        XCTAssertFalse(manager.isUnlocked(id: 13))
+        manager.finishRound(id: round, mode: .moves(limit: 30), clearedCount: 60, swapsUsed: 30, elapsed: 3600, at: date)
@@ -155,0 +159,2 @@
+        XCTAssertTrue(manager.isUnlocked(id: 14))
+        XCTAssertTrue(manager.isUnlocked(id: 15))
@@ -157,7 +161,0 @@
-        for (seconds, id) in [(60.0, 16), (45.0, 14), (30.0, 15)] {
-            newRound()
-            manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 330, elapsed: seconds, at: date)
-            XCTAssertTrue(manager.isUnlocked(id: id))
-        }
-        let best = AchievementDefinition.all.first { $0.id == 16 }!
-        XCTAssertEqual(manager.progress(for: best).current, 30)
@@ -222,7 +220,15 @@
-    func testZeroSecondSpeedRunIsDistinguishedFromMissingResult() {
-        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 0, at: date)
-        XCTAssertTrue(manager.isUnlocked(id: 16))
-        manager = AchievementsManager(defaults: defaults)
-        let definition = AchievementDefinition.all.first { $0.id == 16 }!
-        XCTAssertTrue(manager.hasTimedResult(for: definition))
-        XCTAssertEqual(manager.progress(for: definition).current, 0)
+    func testOldRulesMigrationPreservesUnlocksAndDoesNotInventNewModeProgress() {
+        defaults.set(["version": 1, "unlocked": [1, 13, 16, 21], "timestamps": ["13": date.timeIntervalSince1970],
+                      "metrics": ["bestScore": 150, "totalCleared": 456, "pieceCleared.orange_ricky": 100,
+                                  "speedRunCompleted.300": 1, "speedRun.300": 0, "scoreAttack.1": 900]],
+                     forKey: AchievementsManager.storageKey)
+        manager = AchievementsManager(defaults: defaults)
+        XCTAssertEqual(manager.unlockedIDs(), [1, 13, 16, 21])
+        XCTAssertEqual(manager.unlockDate(id: 13), date)
+        XCTAssertEqual(progress(1), 15)
+        XCTAssertEqual(progress(17), 456)
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 100)
+        XCTAssertEqual(progress(10), 0)
+        XCTAssertEqual(progress(13), 0)
+        manager = AchievementsManager(defaults: defaults)
+        XCTAssertEqual(progress(1), 15, "迁移不会再次除以 10")
```

### `Tests/ChallengeRulesTests.swift`

```diff
--- /dev/null
+++ b/Tests/ChallengeRulesTests.swift
@@ -0,0 +1,137 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+/// 新规则以真实交换和消除事件验证，测试记录与玩家存档隔离。
+final class ChallengeRulesTests: AchievementTestCase {
+    private var now = Date(timeIntervalSince1970: 1_000_000)
+
+    private func board(cascade: Bool = false) -> GameBoardController {
+        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+        return GameBoardController(columns: 4, achievements: manager, now: { self.now }) { _ in
+            var index = 0
+            let fill = cascade ? Array(repeating: a, count: 27) + [c, d, c] : [c, d, c]
+            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
+                defer { index += 1 }
+                return fill[index % fill.count]
+            }
+        }
+    }
+
+    func testOnlyRealLegalSwapsConsumeMovesAndRefreshNeverResetsThem() {
+        let board = board()
+        board.configure(mode: .moves(limit: 30)); board.startRound()
+        board.handleTap(at: 0); board.handleTap(at: 0)
+        board.performSwap(from: -1, to: 0); board.performSwap(from: 0, to: 0); board.performSwap(from: 0, to: 2)
+        XCTAssertFalse(board.lock(-1))
+        XCTAssertEqual(board.snapshot().swapsUsed, 0)
+        XCTAssertTrue(board.lock(1))
+        board.performSwap(from: 0, to: 1)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 30)
+        board.unlock(1)
+        board.performSwap(from: 0, to: 1)
+        XCTAssertEqual(board.snapshot().totalCleared, 0)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 29, "不消除的合法交换也扣一次")
+        _ = board.consumeLastSwapPair()
+        for _ in 0..<5 { _ = board.snapshot(); board.tick() }
+        XCTAssertEqual(board.snapshot().remainingSwaps, 29, "动画和界面读取不能重置计次")
+        now = now.addingTimeInterval(86_400)
+        board.tick()
+        XCTAssertTrue(board.snapshot().isRunning, "限步挑战没有思考时间限制")
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().totalCleared, 3)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 28)
+    }
+
+    func testThirtiethSwapResolvesEveryCascadeThenRefusesThirtyFirst() {
+        let board = board(cascade: true)
+        board.configure(mode: .moves(limit: 30)); board.startRound()
+        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
+        XCTAssertFalse(board.snapshot().isFinished)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 1)
+        board.performSwap(from: 2, to: 3)
+        let final = board.snapshot()
+        XCTAssertTrue(final.isFinished)
+        XCTAssertEqual(final.swapsUsed, 30)
+        XCTAssertEqual(final.remainingSwaps, 0)
+        XCTAssertEqual(final.totalCleared, 30, "最后一次交换触发的十轮连锁都应计入")
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
+        XCTAssertTrue(manager.isUnlocked(id: 13))
+        XCTAssertTrue(manager.isUnlocked(id: 14))
+        let tiles = board.tiles()
+        board.performSwap(from: 0, to: 1)
+        XCTAssertEqual(board.tiles(), tiles)
+        XCTAssertEqual(board.snapshot().swapsUsed, 30)
+    }
+
+    func testTimedModeEndsAtSixtySecondsAndRejectsLateActions() {
+        let board = board()
+        board.configure(mode: .timed(duration: 60)); board.startRound()
+        now = date.addingTimeInterval(59.999)
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().totalCleared, 3)
+        now = date.addingTimeInterval(60)
+        board.tick()
+        XCTAssertTrue(board.snapshot().isFinished)
+        XCTAssertEqual(board.snapshot().remainingTime, 0)
+        let used = board.snapshot().swapsUsed
+        board.performSwap(from: 0, to: 1)
+        XCTAssertEqual(board.snapshot().swapsUsed, used)
+    }
+
+    func testRestartAtDeadlineSavesCompletedRoundBeforePreparingNewBoard() {
+        _ = NSApplication.shared
+        let board = board()
+        let records = ModeRecordStore(defaults: defaults)
+        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false)
+        _ = controller.view
+        controller.selectMode(.timed)
+        controller.startSequence.reducesMotion = { true }
+        controller.startRound()
+        board.performSwap(from: 2, to: 3)
+        now = date.addingTimeInterval(60)
+        // 不先触发 tick，直接按开始；刚结束的旧局仍必须保存一次。
+        controller.startRound()
+        XCTAssertEqual(records.records(for: .timed, detailValue: 60).map(\.clearedCount), [3])
+        XCTAssertTrue(board.snapshot().isRunning)
+        XCTAssertEqual(board.snapshot().totalCleared, 0)
+        XCTAssertEqual(board.snapshot().remainingTime, 60)
+    }
+
+    func testCountRankingSharesPlacesAndNeverUsesElapsedTimeAsTieBreaker() throws {
+        let records = ModeRecordStore(defaults: defaults)
+        let fast = try XCTUnwrap(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 90, swapsUsed: 30, elapsedTime: 5))
+        let slow = try XCTUnwrap(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 90, swapsUsed: 30, elapsedTime: 500))
+        _ = records.addRecord(mode: .moves, detailValue: 30, clearedCount: 80, swapsUsed: 30, elapsedTime: 1)
+        let entries = records.records(for: .moves, detailValue: 30)
+        XCTAssertEqual(entries.map(\.clearedCount), [90, 90, 80])
+        XCTAssertEqual(ModeRecordStore.ranks(for: entries), [1, 1, 3])
+        XCTAssertTrue(entries.contains { $0.id == fast.id })
+        XCTAssertTrue(entries.contains { $0.id == slow.id })
+        let reloaded = ModeRecordStore(defaults: defaults)
+        XCTAssertEqual(ModeRecordStore.ranks(for: reloaded.records(for: .moves, detailValue: 30)), [1, 1, 3])
+    }
+
+    func testLegacyRecordsRemainByteIdenticalAndNeverPopulateNewBoards() throws {
+        let legacy = LegacyModeRecord(id: "real-legacy", score: 450, elapsedTime: 60, durationMinutes: 1, targetScore: nil, createdAt: 100)
+        let bytes = try JSONEncoder().encode(["score_attack_1": [legacy]])
+        defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
+        let records = ModeRecordStore(defaults: defaults)
+        XCTAssertTrue(records.records(for: .timed, detailValue: 60).isEmpty)
+        XCTAssertEqual(records.legacySections().first?.entries.first?.score, 450)
+        _ = records.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
+        XCTAssertEqual(defaults.data(forKey: ModeRecordStore.legacyStorageKey), bytes)
+        let reloaded = ModeRecordStore(defaults: defaults)
+        XCTAssertEqual(reloaded.records(for: .timed, detailValue: 60).map(\.clearedCount), [12])
+        XCTAssertEqual(reloaded.legacySections().first?.entries.first?.score, 450)
+    }
+
+    func testRecordsRequireCompletedRulesAndAcceptRealZeroClearResults() {
+        let records = ModeRecordStore(defaults: defaults)
+        XCTAssertNil(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 10, swapsUsed: 29, elapsedTime: 1000))
+        XCTAssertNil(records.addRecord(mode: .timed, detailValue: 60, clearedCount: 10, swapsUsed: 4, elapsedTime: 59.99))
+        XCTAssertNotNil(records.addRecord(mode: .timed, detailValue: 60, clearedCount: 0, swapsUsed: 0, elapsedTime: 60))
+        XCTAssertNotNil(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 0, swapsUsed: 30, elapsedTime: 0))
+        XCTAssertEqual(records.records(for: .moves, detailValue: 30).first?.clearedCount, 0)
+    }
+}
```

### `Tests/GameBoardControllerTests.swift`

```diff
--- a/Tests/GameBoardControllerTests.swift
+++ b/Tests/GameBoardControllerTests.swift
@@ -17 +17 @@
-        controller.configure(mode: .speedRun(targetScore: 100))
+        controller.configure(mode: .moves(limit: 1))
@@ -37 +37 @@
-        controller.configure(mode: .scoreAttack(duration: 60))
+        controller.configure(mode: .timed(duration: 60))
@@ -45 +45 @@
-    func testExpirationRefusesLateSwapAndZeroScoreDoesNotCount() {
+    func testExpirationRefusesLateSwapAndZeroClearsDoesNotCount() {
@@ -48 +48 @@
-        controller.configure(mode: .scoreAttack(duration: 60))
+        controller.configure(mode: .timed(duration: 60))
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -119,2 +119,2 @@
-        home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
-                                           targetScore: nil, isRunning: false, isFinished: false), mode: .free, manager: progress)
+        home.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
+                                           remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free, manager: progress)
@@ -140,2 +140,2 @@
-        let snapshot = GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
-                                    targetScore: nil, isRunning: false, isFinished: false)
+        let snapshot = GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
+                                    remainingSwaps: nil, isRunning: false, isFinished: false)
```

### `Tests/GameStartSequenceTests.swift`

```diff
--- a/Tests/GameStartSequenceTests.swift
+++ b/Tests/GameStartSequenceTests.swift
@@ -15 +15 @@
-    private func fixture(mode: GameMode = .scoreAttack(duration: 60), columns: Int = 4) -> (GameBoardController, GameStartSequence, GameTouchBarView) {
+    private func fixture(mode: GameMode = .timed(duration: 60), columns: Int = 4) -> (GameBoardController, GameStartSequence, GameTouchBarView) {
@@ -85 +85 @@
-        XCTAssertEqual(board.snapshot().score, 30)
+        XCTAssertEqual(board.snapshot().totalCleared, 3)
@@ -126 +126 @@
-        XCTAssertEqual(board.snapshot().score, 30)
+        XCTAssertEqual(board.snapshot().totalCleared, 3)
@@ -162 +162 @@
-        sequence.reset(notify: false); board.configure(mode: .speedRun(targetScore: 300))
+        sequence.reset(notify: false); board.configure(mode: .moves(limit: 30))
@@ -174 +174 @@
-    func testSpeedRunIgnoresOpeningTimeAndManualRestartSavesEachRound() throws {
+    func testMoveChallengeIgnoresOpeningTimeAndManualRestartSavesEachRound() throws {
@@ -189,2 +189,2 @@
-        // 使用确定的连锁补位达到固定 300 分目标，不缩小正式规则阈值。
-        controller.selectMode(.speedRun)
+        // 使用确定补位序列，完整用完 30 次交换，验证正式限步规则。
+        controller.selectMode(.moves)
@@ -192 +192 @@
-        let baseline = Set(records.records(for: .speedRun, detailValue: 300).map(\.id))
+        let baseline = Set(records.records(for: .moves, detailValue: 30).map(\.id))
@@ -200,0 +201 @@
+            for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
@@ -204 +205 @@
-        let newEntries = records.records(for: .speedRun, detailValue: 300).filter { !baseline.contains($0.id) }
+        let newEntries = records.records(for: .moves, detailValue: 30).filter { !baseline.contains($0.id) }
@@ -257 +258 @@
-        controller.selectMode(.speedRun)
+        controller.selectMode(.moves)
```

### `Tests/GameStateTests.swift`

```diff
--- a/Tests/GameStateTests.swift
+++ b/Tests/GameStateTests.swift
@@ -19 +19 @@
-    func testSingleTripleAndScore() {
+    func testSingleTripleAndCount() {
@@ -23 +23 @@
-        XCTAssertEqual(game.score, 30)
+        XCTAssertEqual(game.totalCleared, 3)
@@ -43 +43 @@
-        XCTAssertEqual(game.score, 80)
+        XCTAssertEqual(game.totalCleared, 8)
@@ -50 +50 @@
-        XCTAssertEqual(game.score, 100)
+        XCTAssertEqual(game.totalCleared, 10)
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -34 +34 @@
-        board.configure(mode: HomeGameMode.speedRun.gameMode)
+        board.configure(mode: HomeGameMode.moves.gameMode)
@@ -39 +39 @@
-    func testFixedModesFinishAtSixtySecondsAndThreeHundredPoints() {
+    func testFixedModesFinishAtSixtySecondsAndThirtySwaps() {
@@ -42 +42 @@
-        board.configure(mode: HomeGameMode.scoreAttack.gameMode)
+        board.configure(mode: HomeGameMode.timed.gameMode)
@@ -50,4 +50,6 @@
-        board.configure(mode: HomeGameMode.speedRun.gameMode)
-        board.startRound()
-        board.performSwap(from: 2, to: 3)
-        XCTAssertEqual(board.snapshot().score, 300)
+        board.configure(mode: HomeGameMode.moves.gameMode)
+        board.startRound()
+        board.performSwap(from: 2, to: 3)
+        XCTAssertEqual(board.snapshot().totalCleared, 30)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 29)
+        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
@@ -80 +82 @@
-        let speed = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .speedRun })
+        let speed = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .moves })
@@ -82 +84 @@
-        XCTAssertEqual(board.snapshot().targetScore, 300)
+        XCTAssertEqual(board.snapshot().remainingSwaps, 30)
@@ -86,0 +89 @@
+        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
@@ -89 +92 @@
-        let finished = try XCTUnwrap(records.records(for: .speedRun, detailValue: 300).first)
+        let finished = try XCTUnwrap(records.records(for: .moves, detailValue: 30).first)
@@ -92 +95 @@
-        XCTAssertEqual(records.records(for: .speedRun, detailValue: 300).first?.id, finished.id)
+        XCTAssertEqual(records.records(for: .moves, detailValue: 30).first?.id, finished.id)
@@ -94 +97 @@
-        let score = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .scoreAttack })
+        let score = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == .timed })
@@ -110,2 +113,2 @@
-                let snapshot = GameSnapshot(mode: mode.gameMode, score: 210, elapsedTime: 12, remainingTime: mode == .scoreAttack ? 48 : nil,
-                                            targetScore: mode == .speedRun ? 300 : nil, isRunning: true, isFinished: false,
+                let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: 12, remainingTime: mode == .timed ? 48 : nil,
+                                            remainingSwaps: mode == .moves ? 18 : nil, isRunning: true, isFinished: false,
@@ -147 +150 @@
-            panel.refresh(mode: .speedRun, volume: 0.4)
+            panel.refresh(mode: .timed, volume: 0.4)
```

### `Tests/HomeUtilityPanelTests.swift`

```diff
--- a/Tests/HomeUtilityPanelTests.swift
+++ b/Tests/HomeUtilityPanelTests.swift
@@ -13,3 +13,3 @@
-            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 1)] = (0..<9).map {
-                ModeRecord(id: "utility-score-\($0)", score: 920 - $0 * 70, elapsedTime: 60,
-                           durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600 - Double($0) * 86400)
+            buckets[ModeRecordStore.scopeID(mode: .timed, detailValue: 60)] = (0..<9).map {
+                ModeRecord(id: "utility-timed-\($0)", clearedCount: 92 - $0 * 7, swapsUsed: 30,
+                           elapsedTime: 60, createdAt: 1_793_361_600 - Double($0) * 86400)
@@ -17,3 +17,3 @@
-            buckets[ModeRecordStore.scopeID(mode: .speedRun, detailValue: 300)] = (0..<9).map {
-                ModeRecord(id: "utility-speed-\($0)", score: 300, elapsedTime: 18.42 + Double($0) * 3.2,
-                           durationMinutes: nil, targetScore: 300, createdAt: 1_793_361_600 - Double($0) * 86400)
+            buckets[ModeRecordStore.scopeID(mode: .moves, detailValue: 30)] = (0..<9).map {
+                ModeRecord(id: "utility-moves-\($0)", clearedCount: 75 - $0 * 5, swapsUsed: 30,
+                           elapsedTime: 180 + Double($0) * 60, createdAt: 1_793_361_600 - Double($0) * 86400)
@@ -21,2 +21,2 @@
-            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 2)] = [
-                ModeRecord(id: "old-rule", score: 999_999, elapsedTime: 120, durationMinutes: 2, targetScore: nil, createdAt: 0)
+            buckets[ModeRecordStore.scopeID(mode: .timed, detailValue: 120)] = [
+                ModeRecord(id: "other-rule", clearedCount: 999_999, swapsUsed: 90, elapsedTime: 120, createdAt: 0)
@@ -25,7 +25 @@
-        defaults.set(try JSONEncoder().encode(buckets), forKey: "mode_records_v1")
-        let previous = ProcessInfo.processInfo.environment["ELIMINATE_DEVELOPMENT_MODE"]
-        setenv("ELIMINATE_DEVELOPMENT_MODE", "0", 1)
-        defer {
-            if let previous { setenv("ELIMINATE_DEVELOPMENT_MODE", previous, 1) }
-            else { unsetenv("ELIMINATE_DEVELOPMENT_MODE") }
-        }
+        defaults.set(try JSONEncoder().encode(buckets), forKey: ModeRecordStore.storageKey)
@@ -73 +67 @@
-        XCTAssertTrue(labels(content).contains("920"))
+        XCTAssertTrue(labels(content).contains("92"))
@@ -76,4 +70,4 @@
-        XCTAssertTrue(labels(content).contains("18.42"))
-        XCTAssertFalse(labels(content).contains("920"))
-        _ = store.addScoreAttackRecord(score: 990, elapsedTime: 60, durationMinutes: 1)
-        panel.refresh(mode: .scoreAttack, volume: 0.7)
+        XCTAssertTrue(labels(content).contains("75"))
+        XCTAssertFalse(labels(content).contains("92"))
+        _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 99, swapsUsed: 30, elapsedTime: 60)
+        panel.refresh(mode: .timed, volume: 0.7)
@@ -81 +75 @@
-        XCTAssertTrue(labels(content).contains("18.42"))
+        XCTAssertTrue(labels(content).contains("75"))
@@ -83,3 +77,3 @@
-        XCTAssertTrue(labels(content).contains("990"))
-        XCTAssertTrue(labels(content).contains(AchievementText.format("records.metric.score", 990)))
-        XCTAssertEqual(store.records(for: .scoreAttack, detailValue: 1).count, 9)
+        XCTAssertTrue(labels(content).contains("99"))
+        XCTAssertTrue(labels(content).contains(AchievementText.format("records.metric.cleared", 99)))
+        XCTAssertEqual(store.records(for: .timed, detailValue: 60).count, 9)
@@ -101,2 +95,2 @@
-            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.score_attack")))
-            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.speed_run")))
+            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.timed")))
+            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.moves")))
@@ -105,2 +99,47 @@
-        XCTAssertTrue(store.records(for: .scoreAttack, detailValue: 1).isEmpty)
-        XCTAssertTrue(store.records(for: .speedRun, detailValue: 300).isEmpty)
+        XCTAssertTrue(store.records(for: .timed, detailValue: 60).isEmpty)
+        XCTAssertTrue(store.records(for: .moves, detailValue: 30).isEmpty)
+    }
+
+    func testOldRulesRecordsOnlyAppearInExplicitHistorySection() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let old = LegacyModeRecord(id: "legacy-player-record", score: 450, elapsedTime: 60,
+                                   durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600)
+        let bytes = try JSONEncoder().encode(["score_attack_1": [old]])
+        defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
+        let store = ModeRecordStore(defaults: defaults)
+        _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
+        let panel = HomeUtilityPanel(page: "records", store: store)
+        defer { panel.close() }
+        panel.refresh(mode: .timed, volume: 0.3)
+        let content = try XCTUnwrap(panel.window?.contentView)
+        XCTAssertTrue(labels(content).contains("12"))
+        XCTAssertFalse(labels(content).contains { $0.contains("450") })
+        let button = try XCTUnwrap(descendants(content).compactMap { $0 as? HomeButton }.first {
+            $0.title == AchievementText.string("utility.records.show_history")
+        })
+        button.performClick(nil)
+        content.layoutSubtreeIfNeeded()
+        XCTAssertTrue(labels(content).contains { $0.contains("450") })
+        XCTAssertEqual(store.records(for: .timed, detailValue: 60).map(\.clearedCount), [12])
+        XCTAssertEqual(defaults.data(forKey: ModeRecordStore.legacyStorageKey), bytes)
+        try export(content, name: "utility-records-history")
+    }
+
+    func testEqualCountsHaveSharedVisibleRanksRegardlessOfTime() throws {
+        _ = NSApplication.shared
+        let store = ModeRecordStore(defaults: defaults)
+        for (count, seconds) in [(90, 5.0), (90, 500.0), (80, 1.0)] {
+            _ = store.addRecord(mode: .moves, detailValue: 30, clearedCount: count, swapsUsed: 30, elapsedTime: seconds)
+        }
+        let panel = HomeUtilityPanel(page: "records", store: store)
+        defer { panel.close() }
+        panel.refresh(mode: .moves, volume: 0.4)
+        let content = try XCTUnwrap(panel.window?.contentView)
+        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
+        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
+        let rowLabels = descendants(content).compactMap { $0.accessibilityLabel() }
+        XCTAssertEqual(rowLabels.filter { $0.hasPrefix("1.") }.count, 2)
+        XCTAssertEqual(rowLabels.filter { $0.hasPrefix("3.") }.count, 1)
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -3,0 +4,8 @@
+
+## 消除数量、限时与限步
+
+- [限时挑战首页](challenge-timed.png)：固定 60 秒，显示已消除数量与剩余时间。
+- [限步挑战首页](challenge-moves.png)：固定 30 次交换，显示已消除数量与剩余次数；思考时间不限。
+- 两种挑战只按消除数量排名，相同数量共享名次。
+- [历史记录入口效果](utility-records-history.png)：新榜与旧分数/用时分区展示，旧存档保持原样。
+- 成就页条件已改用消除数量，已获得的旧成就仍保留。
@@ -21,2 +29,2 @@
-- [玩法说明](utility-rules.png)：三步操作示意、固定模式规则和本局/累计进度说明。
-- [竞分排行榜](utility-records.png)、[竞速排行榜](utility-records-speed.png)：带滑动过渡的模式切换、个人最佳、金银铜名次及对齐的记录列。
+- [玩法说明](utility-rules.png)：三步操作示意、60 秒/30 次交换规则和本局/累计进度说明。
+- [限时排行榜](utility-records.png)、[限步排行榜](utility-records-speed.png)：带滑动过渡的模式切换、按数量计算的个人最佳及并列名次；第二张沿用原预览文件名。
```

### `docs/previews/achievement-icons.png`

```diff
- 292806 字节；SHA-256 7879c7c9f173cb50b0d16de409a9a8682d6676bc79b15cf803d8ee2c8ff7e765
+ 291976 字节；SHA-256 ee073425147b161a71abbbcd031b89b68b1b0ab5429c18f551424e7c9466f87a
```

### `docs/previews/achievement-panel.png`

```diff
- 159078 字节；SHA-256 c9d27a614be146f8981669114a6dd369c1f90643be429951d43c24da1cb891e5
+ 162230 字节；SHA-256 f0ccb3227c00dbddb719e6101c715eae3a9d2d857736cc03004d06747004b251
```

### `docs/previews/challenge-moves.png`

```diff
- 不存在（新增预览）
+ 486439 字节；SHA-256 8c9d4d2066494de90cc5aa1862b10766373566d07993bf379d6877cbd08a7577
```

### `docs/previews/challenge-timed.png`

```diff
- 不存在（新增预览）
+ 495093 字节；SHA-256 7eca0ad24a8a49ad6a065ca413bbd76380112d670eab84e76cdcb504111504d2
```

### `docs/previews/utility-records-empty.png`

```diff
- 135689 字节；SHA-256 468116f6c463d366fb5ee6ba7523ac6921b63e88007aec52ff6ba126000fa8de
+ 143273 字节；SHA-256 d1b7632bdd7335ae80264c599cbc8f48babf5cbb1fc03d3f8cb566bb531c592f
```

### `docs/previews/utility-records-history.png`

```diff
- 不存在（新增预览）
+ 160566 字节；SHA-256 020ee3d2aa911bcc0949d523330b3d04f3aa3d4ced1400c2af7dc5ca658cdea4
```

### `docs/previews/utility-records-speed.png`

```diff
- 209684 字节；SHA-256 e802afb56494d6d0cd9085391b0b2bd88459dbaefe0f89a4861af419a8880982
+ 195837 字节；SHA-256 d089e14aba2b3c0ca018c1c112cf783a59ac3d53ae5402f5819e433eb958492a
```

### `docs/previews/utility-records.png`

```diff
- 202496 字节；SHA-256 6e27a0a9693a81105dac1272bd9b1ea3505fef87707bdf8c14763e9df6cc658c
+ 198906 字节；SHA-256 9a783b2c211c0a916d1e04db887503aa428a14b00ecc2f94d2e9a85915038676
```

### `docs/previews/utility-rules.png`

```diff
- 207272 字节；SHA-256 91222c9030c30276225b27324882868874814d9673b1187067e250691f91721f
+ 217770 字节；SHA-256 232c161f95c90205d36ac1ec6a2c1bfc63a2f552b8aa6ed73d2bacedde4f6aee
```
