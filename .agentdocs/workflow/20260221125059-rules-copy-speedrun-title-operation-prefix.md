# 调整玩法说明文案（竞速去小标题 + 操作方式前缀）

## 背景与目标
- 用户反馈玩法说明文案仍不满意，要求：
  1. 以竞速模式为例，去掉小标题“竞速模式”。
  2. 基础规则第二条“支持多点触控交换...”前增加“操作方式：”前缀。

## 约束与原则
- 不改玩法逻辑，仅改文案拼装与本地化文案键。
- 保持多语言一致性（中/英/日/韩/俄）。
- 维持当前圆点 `•` 列表结构。

## 阶段与 TODO
- [x] 修改玩法说明拼装逻辑：竞速模式隐藏标题行。
- [x] 为“操作方式”新增本地化 key 并接入基础规则第二条。
- [x] 同步更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 竞速模式玩法说明不再显示“竞速模式”标题。
- 基础规则第二条已统一为“操作方式：支持多点触控交换...”。
- 多语言均补齐 `rules.label.operation`。

## 代码变更
- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index bd6da0a..3b8f04c 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -15,3 +15,4 @@
 - 玩法说明文案已改为精简版结构：仅展示“模式标题 + 模式规则 + 结算方式”，不再显示“模式规则/结算规则/当前模式”分段模块。
 - 玩法说明已恢复“基础规则”，并把列表符号统一为 `•`；挑战记录在面板宽度变化时会重建排版，恢复“排名+得分/日期”两侧对齐。
 - 游戏设置、时间与得分、挑战记录模块的标题与主要内容文本已统一切换为对应主题色（蓝/绿/橙），不再使用白色正文。
+- 玩法说明中竞速模式已去掉“竞速模式”小标题；基础规则第二条改为“操作方式：...”前缀并保持多语言同步。
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 04b45d1..60a4631 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -663,6 +663,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let modeTitle: String
         let coreRulePrimary = localized("rules.core.line1")
         let coreRuleSecondary = localized("rules.core.line2")
+        let operationLabel = localized("rules.label.operation")
         let modeRule: String
         let settlementRule: String
@@ -680,19 +681,21 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
         case .speedRun:
             let targetScore = speedRunTargets[min(max(0, selectedSpeedRunIndex), speedRunTargets.count - 1)]
-            modeTitle = localized("rules.mode_title.speed_run")
+            modeTitle = ""
             modeRule = localizedFormat("rules.short.mode.speed_run", localizedFormat("option.target_format", targetScore))
             settlementRule = localized("rules.short.settlement.speed_run")
         }
 
-        // 玩法说明保持简短结构，同时恢复“基础规则”并统一使用圆点分隔。
-        let description = """
-        \(modeTitle)
-        • \(localized("rules.category.core"))：\(coreRulePrimary)
-        • \(coreRuleSecondary)
-        • \(localized("rules.label.mode_rule"))：\(modeRule)
-        • \(localized("rules.label.settlement"))：\(settlementRule)
-        """
+        // 玩法说明保持简短结构，竞速模式去掉小标题。
+        var descriptionRows: [String] = []
+        if !modeTitle.isEmpty {
+            descriptionRows.append(modeTitle)
+        }
+        descriptionRows.append("• \(localized("rules.category.core"))：\(coreRulePrimary)")
+        descriptionRows.append("• \(operationLabel)：\(coreRuleSecondary)")
+        descriptionRows.append("• \(localized("rules.label.mode_rule"))：\(modeRule)")
+        descriptionRows.append("• \(localized("rules.label.settlement"))：\(settlementRule)")
+        let description = descriptionRows.joined(separator: "\n")
         rulesBodyLabel.stringValue = description
     }
```

- Sources/Resources/zh-Hans.lproj/Localizable.strings
```diff
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index 145acff..e64678f 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -64,6 +64,7 @@
 "rules.mode_title.score_attack" = "竞分模式：";
 "rules.mode_title.speed_run" = "竞速模式：";
 "rules.label.mode_rule" = "模式规则";
+"rules.label.operation" = "操作方式";
 "rules.label.settlement" = "结算方式";
 "rules.short.mode.free" = "无时间和目标分数限制，可持续练习操作";
 "rules.short.mode.score_attack" = "在%@内尽可能获得更高分";
```

- Sources/Resources/en.lproj/Localizable.strings
```diff
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index f66903d..145d582 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -64,6 +64,7 @@
 "rules.mode_title.score_attack" = "Score Attack:";
 "rules.mode_title.speed_run" = "Speed Run:";
 "rules.label.mode_rule" = "Mode Rule";
+"rules.label.operation" = "Operation";
 "rules.label.settlement" = "Settlement";
 "rules.short.mode.free" = "No timer or target score, suitable for practice";
 "rules.short.mode.score_attack" = "Earn as many points as possible within %@";
```

- Sources/Resources/ja.lproj/Localizable.strings
```diff
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index f56b4c8..adb5d9e 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -64,6 +64,7 @@
 "rules.mode_title.score_attack" = "スコアアタック：";
 "rules.mode_title.speed_run" = "スピードラン：";
 "rules.label.mode_rule" = "モードルール";
+"rules.label.operation" = "操作方法";
 "rules.label.settlement" = "決着方式";
 "rules.short.mode.free" = "時間制限と目標スコアなしで継続練習できます";
 "rules.short.mode.score_attack" = "%@ 内でできるだけ高得点を狙います";
```

- Sources/Resources/ko.lproj/Localizable.strings
```diff
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index efba045..8499c20 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -64,6 +64,7 @@
 "rules.mode_title.score_attack" = "점수전 모드:";
 "rules.mode_title.speed_run" = "스피드런 모드:";
 "rules.label.mode_rule" = "모드 규칙";
+"rules.label.operation" = "조작 방식";
 "rules.label.settlement" = "결산 방식";
 "rules.short.mode.free" = "시간 제한과 목표 점수 없이 계속 연습할 수 있습니다";
 "rules.short.mode.score_attack" = "%@ 안에 최대한 높은 점수를 노립니다";
```

- Sources/Resources/ru.lproj/Localizable.strings
```diff
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index db4ca7d..7b82e5d 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -64,6 +64,7 @@
 "rules.mode_title.score_attack" = "Режим на очки:";
 "rules.mode_title.speed_run" = "Режим на скорость:";
 "rules.label.mode_rule" = "Правило режима";
+"rules.label.operation" = "Способ управления";
 "rules.label.settlement" = "Условие завершения";
 "rules.short.mode.free" = "Без таймера и целевого счёта, можно спокойно тренироваться";
 "rules.short.mode.score_attack" = "Наберите максимум очков за %@";
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221125059-rules-copy-speedrun-title-operation-prefix.md` - 竞速玩法说明去掉小标题，基础规则第二条改为“操作方式：...”，并补齐多语言键值。
@@
 ## 读取场景
+- 需要确认“竞速模式不显示小标题 + 第二条基础规则改为操作方式前缀”时，优先读取 `20260221125059` 文档。
@@
 ## 关键记忆
+- 玩法说明在竞速模式下不再显示“竞速模式”标题行，基础规则第二条统一为“操作方式：...”文案，并已同步中英日韩俄多语言。
```

## 测试用例
### TC-001 竞速模式标题隐藏
- 类型：UI测试
- 操作步骤：切换到竞速模式，查看玩法说明第一行
- 预期结果：不显示“竞速模式”标题，直接显示规则项

### TC-002 操作方式前缀展示
- 类型：UI测试
- 操作步骤：查看玩法说明第二条基础规则
- 预期结果：文案格式为“操作方式：支持多点触控交换...”

### TC-003 多语言文案完整性
- 类型：功能测试
- 操作步骤：切换中/英/日/韩/俄语言并查看玩法说明第二条
- 预期结果：均显示本地化“操作方式”前缀，不出现 key 文本

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
