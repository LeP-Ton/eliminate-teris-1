# 玩法说明文案统一：所有模式去小标题 + 第二条固定“操作方式”

## 背景与目标
- 用户反馈：不只竞速模式，其他模式的玩法说明也要一致。
- 目标：
  1. 自由/竞分/竞速都去掉玩法说明小标题。
  2. 第二条统一为“操作方式：...”。

## 约束与原则
- 不改动玩法逻辑，仅改玩法说明文案拼装。
- 保持当前圆点 `•` 列表形式。
- 多语言键不新增，仅复用已有 `rules.label.operation`。

## 阶段与 TODO
- [x] 去除 `updateRulesDescription` 中所有模式标题输出。
- [x] 保留“操作方式”作为第二条规则。
- [x] 更新 AGENTS 与索引文档。
- [x] 完成构建验证。

## 当前进展
- 三种模式玩法说明均不再显示模式标题。
- 第二条规则固定展示“操作方式：支持多点触控交换...”。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
@@
-    private func updateRulesDescription(for selection: ModeSelection) {
-        let modeTitle: String
+    private func updateRulesDescription(for selection: ModeSelection) {
@@
-        case .free:
-            modeTitle = localized("rules.mode_title.free")
+        case .free:
             modeRule = localized("rules.short.mode.free")
             settlementRule = localized("rules.short.settlement.free")
@@
-        case .scoreAttack:
+        case .scoreAttack:
             let minutes = scoreAttackMinutes[min(max(0, selectedScoreAttackIndex), scoreAttackMinutes.count - 1)]
-            modeTitle = localized("rules.mode_title.score_attack")
             modeRule = localizedFormat("rules.short.mode.score_attack", localizedFormat("option.minute_format", minutes))
             settlementRule = localized("rules.short.settlement.score_attack")
@@
-        case .speedRun:
+        case .speedRun:
             let targetScore = speedRunTargets[min(max(0, selectedSpeedRunIndex), speedRunTargets.count - 1)]
-            modeTitle = ""
             modeRule = localizedFormat("rules.short.mode.speed_run", localizedFormat("option.target_format", targetScore))
             settlementRule = localized("rules.short.settlement.speed_run")
         }
 
-        // 玩法说明保持简短结构，竞速模式去掉小标题。
+        // 玩法说明统一去掉模式小标题，只保留规则项。
         var descriptionRows: [String] = []
-        if !modeTitle.isEmpty {
-            descriptionRows.append(modeTitle)
-        }
         descriptionRows.append("• \(localized("rules.category.core"))：\(coreRulePrimary)")
         descriptionRows.append("• \(operationLabel)：\(coreRuleSecondary)")
         descriptionRows.append("• \(localized("rules.label.mode_rule"))：\(modeRule)")
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
-- 玩法说明中竞速模式已去掉“竞速模式”小标题；基础规则第二条改为“操作方式：...”前缀并保持多语言同步。
+- 玩法说明在所有模式下都已去掉模式小标题；基础规则第二条统一为“操作方式：...”前缀并保持多语言同步。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221125656-rules-copy-all-modes-no-title.md` - 所有模式玩法说明去掉小标题，第二条统一为“操作方式：...”文案。
@@
 ## 读取场景
+- 需要确认“所有模式均不显示玩法说明小标题 + 第二条固定为操作方式前缀”时，优先读取 `20260221125656` 文档。
@@
 ## 关键记忆
-- 玩法说明在竞速模式下不再显示“竞速模式”标题行，基础规则第二条统一为“操作方式：...”文案，并已同步中英日韩俄多语言。
+- 玩法说明在所有模式下都不再显示模式标题行，基础规则第二条统一为“操作方式：...”文案，并已同步中英日韩俄多语言。
```

## 测试用例
### TC-001 三模式标题一致性
- 类型：UI测试
- 操作步骤：分别切换自由、竞分、竞速，查看玩法说明首行
- 预期结果：都不显示“自由模式/竞分模式/竞速模式”小标题

### TC-002 第二条文案一致性
- 类型：UI测试
- 操作步骤：在任一模式查看玩法说明第二条
- 预期结果：固定为“操作方式：支持多点触控交换...”

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
