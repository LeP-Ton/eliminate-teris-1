# 玩法说明文案改为精简结构（模式规则 + 结算方式）

## 背景与目标
- 用户要求：
  1. 去掉“模式规则、结算规则和当前模式”分段模块。
  2. 文案改为更简短结构，示例为竞速 300 分场景。
- 目标：统一改成“模式标题 + 两条短规则（模式规则、结算方式）”，并保留模式/子规则动态变化。

## 约束与原则
- 不改动玩法逻辑，仅调整玩法说明文案结构。
- 保持多语言能力，避免切换语言出现 key 文本。
- 保持已有红色主题玩法说明卡片样式。

## 阶段与 TODO
- [x] 重构 `updateRulesDescription`，移除旧分段结构。
- [x] 新增简短文案 key（中英日韩俄）。
- [x] 更新项目认知与索引。
- [x] 编译验证。

## 关键风险
- 旧 key 目前仍保留在字符串文件中，功能正常但会存在未使用 key；后续可再清理。

## 当前进展
- 玩法说明已变更为“模式标题 + 规则两行”形式。
- 竞速模式示例文案已为“以最短时间达到300分目标 / 达到目标分数后立即结算，以用时排名”同类结构。
- 构建通过。

## git记录
- branch：main
- commit：c54df9e 精简玩法说明文案并按模式动态展示

## 代码变更
- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 92a3d35..dcde583 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -12,3 +12,4 @@
 - 挑战记录行间距已缩减 50%，`paragraphStyle.lineSpacing` 从 `7` 调整为 `3.5`。
 - 新增“玩法说明”模块，位于游戏设置与挑战记录下方，使用罗德岛风格红色主题边框，并按“基础规则/模式规则/结算规则”分类展示。
 - 玩法说明会根据当前模式与规则档位动态变化（自由、竞分档位、竞速目标分），用于解释不同玩法规则。
+- 玩法说明文案已改为精简版结构：仅展示“模式标题 + 模式规则 + 结算方式”，不再显示“模式规则/结算规则/当前模式”分段模块。
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index bc5c918..9448ef9 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -651,41 +651,34 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }
 
     private func updateRulesDescription(for selection: ModeSelection) {
+        let modeTitle: String
         let modeRule: String
-        let goalRule: String
-        let currentRule: String
+        let settlementRule: String
 
         switch selection {
         case .free:
-            modeRule = localized("rules.mode.free")
-            goalRule = localized("rules.goal.free")
-            currentRule = localized("rules.current.free")
+            modeTitle = localized("rules.mode_title.free")
+            modeRule = localized("rules.short.mode.free")
+            settlementRule = localized("rules.short.settlement.free")
 
         case .scoreAttack:
             let minutes = scoreAttackMinutes[min(max(0, selectedScoreAttackIndex), scoreAttackMinutes.count - 1)]
-            modeRule = localizedFormat("rules.mode.score_attack", scoreAttackMinutes[0], scoreAttackMinutes[1], scoreAttackMinutes[2])
-            goalRule = localized("rules.goal.score_attack")
-            currentRule = localizedFormat("rules.current.score_attack", localizedFormat("option.minute_format", minutes))
+            modeTitle = localized("rules.mode_title.score_attack")
+            modeRule = localizedFormat("rules.short.mode.score_attack", localizedFormat("option.minute_format", minutes))
+            settlementRule = localized("rules.short.settlement.score_attack")
 
         case .speedRun:
             let targetScore = speedRunTargets[min(max(0, selectedSpeedRunIndex), speedRunTargets.count - 1)]
-            modeRule = localizedFormat("rules.mode.speed_run", speedRunTargets[0], speedRunTargets[1], speedRunTargets[2])
-            goalRule = localized("rules.goal.speed_run")
-            currentRule = localizedFormat("rules.current.speed_run", localizedFormat("option.target_format", targetScore))
+            modeTitle = localized("rules.mode_title.speed_run")
+            modeRule = localizedFormat("rules.short.mode.speed_run", localizedFormat("option.target_format", targetScore))
+            settlementRule = localized("rules.short.settlement.speed_run")
         }
 
+        // 玩法说明改为精简结构：模式名 + 两条规则（模式规则/结算方式）。
         let description = """
-        \(localized("rules.category.core"))
-        • \(localized("rules.core.line1"))
-        • \(localized("rules.core.line2"))
-
-        \(localized("rules.category.mode"))
-        • \(modeRule)
-
-        \(localized("rules.category.goal"))
-        • \(goalRule)
-
-        \(currentRule)
+        \(modeTitle)
+        - \(localized("rules.label.mode_rule"))：\(modeRule)
+        - \(localized("rules.label.settlement"))：\(settlementRule)
         """
         rulesBodyLabel.stringValue = description
     }
```

- Sources/Resources/zh-Hans.lproj/Localizable.strings
```diff
@@
 "rules.current.free" = "当前模式：自由（无时间限制 / 无目标分数）";
 "rules.current.score_attack" = "当前模式：竞分（当前档位：%@）";
 "rules.current.speed_run" = "当前模式：竞速（当前目标：%@）";
+
+"rules.mode_title.free" = "自由模式：";
+"rules.mode_title.score_attack" = "竞分模式：";
+"rules.mode_title.speed_run" = "竞速模式：";
+"rules.label.mode_rule" = "模式规则";
+"rules.label.settlement" = "结算方式";
+"rules.short.mode.free" = "无时间和目标分数限制，可持续练习操作";
+"rules.short.mode.score_attack" = "在%@内尽可能获得更高分";
+"rules.short.mode.speed_run" = "以最短时间达到%@目标";
+"rules.short.settlement.free" = "不判定胜负，不参与排名结算";
+"rules.short.settlement.score_attack" = "倒计时归零后结算，以最终得分排名";
+"rules.short.settlement.speed_run" = "达到目标分数后立即结算，以用时排名";
```

- Sources/Resources/en.lproj/Localizable.strings
```diff
@@
 "rules.current.free" = "Current Mode: Free (No timer / No target score)";
 "rules.current.score_attack" = "Current Mode: Score Attack (Current tier: %@)";
 "rules.current.speed_run" = "Current Mode: Speed Run (Current target: %@)";
+
+"rules.mode_title.free" = "Free Mode:";
+"rules.mode_title.score_attack" = "Score Attack:";
+"rules.mode_title.speed_run" = "Speed Run:";
+"rules.label.mode_rule" = "Mode Rule";
+"rules.label.settlement" = "Settlement";
+"rules.short.mode.free" = "No timer or target score, suitable for practice";
+"rules.short.mode.score_attack" = "Earn as many points as possible within %@";
+"rules.short.mode.speed_run" = "Reach %@ in the shortest time";
+"rules.short.settlement.free" = "No win/lose settlement and no ranking";
+"rules.short.settlement.score_attack" = "Settles when countdown ends, ranked by final score";
+"rules.short.settlement.speed_run" = "Settles immediately on target reach, ranked by elapsed time";
```

- Sources/Resources/ja.lproj/Localizable.strings
```diff
@@
 "rules.current.free" = "現在モード：フリー（時間制限なし / 目標スコアなし）";
 "rules.current.score_attack" = "現在モード：スコアアタック（現在の設定：%@）";
 "rules.current.speed_run" = "現在モード：スピードラン（現在の目標：%@）";
+
+"rules.mode_title.free" = "フリーモード：";
+"rules.mode_title.score_attack" = "スコアアタック：";
+"rules.mode_title.speed_run" = "スピードラン：";
+"rules.label.mode_rule" = "モードルール";
+"rules.label.settlement" = "決着方式";
+"rules.short.mode.free" = "時間制限と目標スコアなしで継続練習できます";
+"rules.short.mode.score_attack" = "%@ 内でできるだけ高得点を狙います";
+"rules.short.mode.speed_run" = "%@ 目標を最短時間で達成します";
+"rules.short.settlement.free" = "勝敗判定なし、ランキング対象外です";
+"rules.short.settlement.score_attack" = "時間切れで終了し、最終スコアで順位付けします";
+"rules.short.settlement.speed_run" = "目標到達で即終了し、経過時間で順位付けします";
```

- Sources/Resources/ko.lproj/Localizable.strings
```diff
@@
 "rules.current.free" = "현재 모드: 자유 (시간 제한 없음 / 목표 점수 없음)";
 "rules.current.score_attack" = "현재 모드: 점수전 (현재 설정: %@)";
 "rules.current.speed_run" = "현재 모드: 스피드런 (현재 목표: %@)";
+
+"rules.mode_title.free" = "자유 모드:";
+"rules.mode_title.score_attack" = "점수전 모드:";
+"rules.mode_title.speed_run" = "스피드런 모드:";
+"rules.label.mode_rule" = "모드 규칙";
+"rules.label.settlement" = "결산 방식";
+"rules.short.mode.free" = "시간 제한과 목표 점수 없이 계속 연습할 수 있습니다";
+"rules.short.mode.score_attack" = "%@ 안에 최대한 높은 점수를 노립니다";
+"rules.short.mode.speed_run" = "%@ 목표를 최단 시간에 달성합니다";
+"rules.short.settlement.free" = "승패 판정이 없고 랭킹 집계도 하지 않습니다";
+"rules.short.settlement.score_attack" = "시간 종료 시 결산하며 최종 점수로 순위를 매깁니다";
+"rules.short.settlement.speed_run" = "목표 달성 즉시 결산하며 소요 시간으로 순위를 매깁니다";
```

- Sources/Resources/ru.lproj/Localizable.strings
```diff
@@
 "rules.current.free" = "Текущий режим: Свободный (без таймера / без цели по очкам)";
 "rules.current.score_attack" = "Текущий режим: На очки (текущий уровень: %@)";
 "rules.current.speed_run" = "Текущий режим: На скорость (текущая цель: %@)";
+
+"rules.mode_title.free" = "Свободный режим:";
+"rules.mode_title.score_attack" = "Режим на очки:";
+"rules.mode_title.speed_run" = "Режим на скорость:";
+"rules.label.mode_rule" = "Правило режима";
+"rules.label.settlement" = "Условие завершения";
+"rules.short.mode.free" = "Без таймера и целевого счёта, можно спокойно тренироваться";
+"rules.short.mode.score_attack" = "Наберите максимум очков за %@";
+"rules.short.mode.speed_run" = "Достигните %@ за минимальное время";
+"rules.short.settlement.free" = "Без победы/поражения и без рейтинга";
+"rules.short.settlement.score_attack" = "Завершение по таймеру, рейтинг по итоговому счёту";
+"rules.short.settlement.speed_run" = "Завершение сразу после цели, рейтинг по времени";
```

## 测试用例
### TC-001 精简结构显示
- 类型：UI测试
- 前置条件：进入任一模式
- 操作步骤：查看玩法说明模块
- 预期结果：仅展示“模式标题 + 模式规则 + 结算方式”三行结构，不再显示旧分段模块

### TC-002 竞速 300 分示例
- 类型：功能测试
- 前置条件：切换到竞速，目标选 300 分
- 操作步骤：查看玩法说明文案
- 预期结果：出现“竞速模式：- 模式规则：以最短时间达到300分目标 - 结算方式：达到目标分数后立即结算，以用时排名”同类文案

### TC-003 其他模式与子规则联动
- 类型：功能测试
- 前置条件：切换自由、竞分（1/2/3 分钟）、竞速（300/600/900 分）
- 操作步骤：观察玩法说明
- 预期结果：模式标题和两条规则随当前选项同步变化

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
