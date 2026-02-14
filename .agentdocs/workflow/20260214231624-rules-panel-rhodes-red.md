# 新增玩法说明模块（罗德岛风格红色主题）

## 背景与目标
- 用户要求在“游戏设置 + 挑战记录”下方新增一个玩法说明模块。
- 模块视觉风格需要接近罗德岛 Z 的红色主题。
- 需要按不同模式与规则分类解释玩法，并随当前模式/档位动态变化。

## 约束与原则
- 保持原有布局主结构不变，仅在 `cardsStack` 下方新增模块。
- 保持多语言一致性，避免切换语言时出现 key 泄漏。
- 不改动玩法核心逻辑，仅新增说明展示能力。

## 阶段与 TODO
- [x] 新增玩法说明卡片容器与红色主题。
- [x] 新增按“基础规则/模式规则/结算规则”分类文案。
- [x] 根据当前模式与规则档位动态更新说明。
- [x] 补齐中/英/日/韩/俄多语言文案。
- [x] 编译验证通过。

## 关键风险
- 多语言文本长度差异可能导致模块高度变化，当前通过自动换行处理。
- 红色主题为程序化配色（非设计稿色值），后续可按视觉反馈继续微调。

## 当前进展
- 已新增“玩法说明”模块，位于 `cardsStack` 下方。
- 已引入罗德岛风格偏深红强调色卡片边框与红系正文。
- 已实现模式动态说明：自由、竞分（含当前分钟档位）、竞速（含当前目标分）。

## git记录
- branch：main
- commit：72c097b 新增玩法说明模块并补充多语言规则文案

## 代码变更
- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 7f92e77..92a3d35 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -10,3 +10,5 @@
 - 序号 Tag 当前按视觉反馈下移 3px（`attachment.bounds.y = -3`）以贴齐同一行文本。
 - 测试 seed 数据采用“9条 + 0/1条混合”策略：竞分 1分钟=9、2分钟=1、3分钟=0；竞速 300分=9、600分=1、900分=0。
 - 挑战记录行间距已缩减 50%，`paragraphStyle.lineSpacing` 从 `7` 调整为 `3.5`。
+- 新增“玩法说明”模块，位于游戏设置与挑战记录下方，使用罗德岛风格红色主题边框，并按“基础规则/模式规则/结算规则”分类展示。
+- 玩法说明会根据当前模式与规则档位动态变化（自由、竞分档位、竞速目标分），用于解释不同玩法规则。
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index ff452a7..bc5c918 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -208,10 +208,16 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
-    private lazy var instructionsLabel: NSTextField = {
+    private lazy var rulesTitleLabel: NSTextField = {
+        let label = makeSectionTitleLabel()
+        label.textColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
+        return label
+    }()
+
+    private lazy var rulesBodyLabel: NSTextField = {
         let label = NSTextField(wrappingLabelWithString: "")
         label.alignment = .left
-        label.textColor = NSColor.white.withAlphaComponent(0.66)
+        label.textColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
@@ -328,6 +334,20 @@
+    private lazy var rulesCardView: PixelFrameCardView = {
+        // 罗德岛风格的偏深红强调色。
+        return PixelFrameCardView(accentColor: NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.3, alpha: 1.0))
+    }()
+
+    private lazy var rulesCardStack: NSStackView = {
+        let stack = NSStackView(views: [rulesTitleLabel, rulesBodyLabel])
+        stack.orientation = .vertical
+        stack.alignment = .leading
+        stack.spacing = 10
+        stack.translatesAutoresizingMaskIntoConstraints = false
+        return stack
+    }()
@@ -335,7 +355,7 @@
-        let stack = NSStackView(views: [headerStack, dividerView, pixelBannerView, cardsStack, instructionsLabel])
+        let stack = NSStackView(views: [headerStack, dividerView, pixelBannerView, cardsStack, rulesCardView])
@@ -407,7 +428,12 @@
-            instructionsLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
+            rulesCardView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
+            rulesCardStack.topAnchor.constraint(equalTo: rulesCardView.topAnchor, constant: 14),
+            rulesCardStack.leadingAnchor.constraint(equalTo: rulesCardView.leadingAnchor, constant: 14),
+            rulesCardStack.trailingAnchor.constraint(equalTo: rulesCardView.trailingAnchor, constant: -14),
+            rulesCardStack.bottomAnchor.constraint(equalTo: rulesCardView.bottomAnchor, constant: -14),
+            rulesBodyLabel.widthAnchor.constraint(equalTo: rulesCardStack.widthAnchor),
@@ -530,6 +556,7 @@
         let selection = currentModeSelection
         populateOptionPopup(for: selection)
         updateStartControlVisibility(for: selection)
+        updateRulesDescription(for: selection)
@@ -548,10 +575,10 @@
         statusTitleLabel.stringValue = localized("panel.status")
         recordsTitleLabel.stringValue = localized("panel.records")
+        rulesTitleLabel.stringValue = localized("panel.rules")
         languageTitleLabel.stringValue = localized("language.label")
         modeTitleLabel.stringValue = localized("mode.label")
         startTitleLabel.stringValue = ""
-        instructionsLabel.stringValue = localized("instructions.text")
@@ -622,6 +650,46 @@
+    private func updateRulesDescription(for selection: ModeSelection) {
+        let modeRule: String
+        let goalRule: String
+        let currentRule: String
+        ...
+        let description = """
+        \(localized("rules.category.core"))
+        • \(localized("rules.core.line1"))
+        • \(localized("rules.core.line2"))
+
+        \(localized("rules.category.mode"))
+        • \(modeRule)
+
+        \(localized("rules.category.goal"))
+        • \(goalRule)
+
+        \(currentRule)
+        """
+        rulesBodyLabel.stringValue = description
+    }
```

- Sources/Resources/zh-Hans.lproj/Localizable.strings
```diff
@@
 "panel.records" = "挑战记录";
+"panel.rules" = "玩法说明";
@@
+"rules.category.core" = "基础规则";
+"rules.category.mode" = "模式规则";
+"rules.category.goal" = "结算规则";
+"rules.core.line1" = "在触控栏拖动方块交换位置，连成 3 个及以上即可消除。";
+"rules.core.line2" = "支持多点触控交换，连续消除会更容易拉开分差。";
+"rules.mode.free" = "自由：无时间与目标分数限制，可持续练习操作。";
+"rules.mode.score_attack" = "竞分：在 %d/%d/%d 分钟倒计时内尽可能拿到更高分。";
+"rules.mode.speed_run" = "竞速：以最短时间达到 %d/%d/%d 分目标。";
+"rules.goal.free" = "自由：不判定胜负，仅用于练习与手感调整。";
+"rules.goal.score_attack" = "竞分：倒计时归零后结算，以最终得分排名。";
+"rules.goal.speed_run" = "竞速：达到目标分后立即结算，以用时排名。";
+"rules.current.free" = "当前模式：自由（无时间限制 / 无目标分数）";
+"rules.current.score_attack" = "当前模式：竞分（当前档位：%@）";
+"rules.current.speed_run" = "当前模式：竞速（当前目标：%@）";
```

- Sources/Resources/en.lproj/Localizable.strings
```diff
@@
 "panel.records" = "Challenge Records";
+"panel.rules" = "Mode Briefing";
@@
+"rules.category.core" = "Core Rules";
+"rules.category.mode" = "Mode Rules";
+"rules.category.goal" = "Settlement Rules";
+"rules.core.line1" = "Drag tiles on the Touch Bar to swap positions; match 3+ to clear.";
+"rules.core.line2" = "Multi-touch swapping is supported; chain clears help build a score gap.";
+"rules.mode.free" = "Free: No timer and no target score; ideal for control practice.";
+"rules.mode.score_attack" = "Score Attack: Earn as many points as possible within %d/%d/%d minutes.";
+"rules.mode.speed_run" = "Speed Run: Reach %d/%d/%d points as quickly as possible.";
+"rules.goal.free" = "Free: No win/lose settlement, used for practice only.";
+"rules.goal.score_attack" = "Score Attack: Settles when countdown ends, ranked by final score.";
+"rules.goal.speed_run" = "Speed Run: Settles immediately after target score is reached, ranked by elapsed time.";
+"rules.current.free" = "Current Mode: Free (No timer / No target score)";
+"rules.current.score_attack" = "Current Mode: Score Attack (Current tier: %@)";
+"rules.current.speed_run" = "Current Mode: Speed Run (Current target: %@)";
```

- Sources/Resources/ja.lproj/Localizable.strings
```diff
@@
 "panel.records" = "チャレンジ記録";
+"panel.rules" = "ルール説明";
@@
+"rules.category.core" = "基本ルール";
+"rules.category.mode" = "モード別ルール";
+"rules.category.goal" = "決着ルール";
+"rules.core.line1" = "Touch Bar 上でタイルをドラッグして入れ替え、3 個以上そろえると消去されます。";
+"rules.core.line2" = "マルチタッチでの入れ替えに対応し、連続消去でスコア差を広げやすくなります。";
+"rules.mode.free" = "フリー：時間制限と目標スコアがなく、操作練習向けです。";
+"rules.mode.score_attack" = "スコアアタック：%d/%d/%d 分の制限時間内で高得点を狙います。";
+"rules.mode.speed_run" = "スピードラン：%d/%d/%d 点に最短時間で到達することを目指します。";
+"rules.goal.free" = "フリー：勝敗判定はなく、練習専用です。";
+"rules.goal.score_attack" = "スコアアタック：時間切れで終了し、最終スコアで順位付けします。";
+"rules.goal.speed_run" = "スピードラン：目標到達で即終了し、経過時間で順位付けします。";
+"rules.current.free" = "現在モード：フリー（時間制限なし / 目標スコアなし）";
+"rules.current.score_attack" = "現在モード：スコアアタック（現在の設定：%@）";
+"rules.current.speed_run" = "現在モード：スピードラン（現在の目標：%@）";
```

- Sources/Resources/ko.lproj/Localizable.strings
```diff
@@
 "panel.records" = "챌린지 기록";
+"panel.rules" = "플레이 규칙";
@@
+"rules.category.core" = "기본 규칙";
+"rules.category.mode" = "모드 규칙";
+"rules.category.goal" = "종료 규칙";
+"rules.core.line1" = "Touch Bar에서 타일을 드래그해 위치를 바꾸고, 3개 이상 맞추면 제거됩니다.";
+"rules.core.line2" = "멀티터치 교환을 지원하며, 연속 제거 시 점수 격차를 벌리기 쉽습니다.";
+"rules.mode.free" = "자유: 시간 제한과 목표 점수 없이 자유롭게 연습합니다.";
+"rules.mode.score_attack" = "점수전: %d/%d/%d분 제한 시간 안에 최대 점수를 노립니다.";
+"rules.mode.speed_run" = "스피드런: %d/%d/%d점을 가장 빠르게 달성하는 모드입니다.";
+"rules.goal.free" = "자유: 승패 판정 없이 연습용으로만 사용합니다.";
+"rules.goal.score_attack" = "점수전: 시간이 끝나면 종료되며 최종 점수로 순위를 매깁니다.";
+"rules.goal.speed_run" = "스피드런: 목표 점수 달성 즉시 종료되며 경과 시간으로 순위를 매깁니다.";
+"rules.current.free" = "현재 모드: 자유 (시간 제한 없음 / 목표 점수 없음)";
+"rules.current.score_attack" = "현재 모드: 점수전 (현재 설정: %@)";
+"rules.current.speed_run" = "현재 모드: 스피드런 (현재 목표: %@)";
```

- Sources/Resources/ru.lproj/Localizable.strings
```diff
@@
 "panel.records" = "Рекорды испытаний";
+"panel.rules" = "Правила режима";
@@
+"rules.category.core" = "Базовые правила";
+"rules.category.mode" = "Правила режимов";
+"rules.category.goal" = "Условия завершения";
+"rules.core.line1" = "Перетаскивайте плитки на Touch Bar; 3 и более подряд очищаются.";
+"rules.core.line2" = "Поддерживается мультитач-обмен; серии очисток помогают увеличить отрыв по очкам.";
+"rules.mode.free" = "Свободный: без лимита времени и целевого счёта, подходит для тренировки.";
+"rules.mode.score_attack" = "На очки: наберите максимум очков за %d/%d/%d минут.";
+"rules.mode.speed_run" = "На скорость: достигните %d/%d/%d очков как можно быстрее.";
+"rules.goal.free" = "Свободный: без победы/поражения, только для практики.";
+"rules.goal.score_attack" = "На очки: завершение по таймеру, рейтинг по итоговому счёту.";
+"rules.goal.speed_run" = "На скорость: завершение сразу после цели, рейтинг по времени.";
+"rules.current.free" = "Текущий режим: Свободный (без таймера / без цели по очкам)";
+"rules.current.score_attack" = "Текущий режим: На очки (текущий уровень: %@)";
+"rules.current.speed_run" = "Текущий режим: На скорость (текущая цель: %@)";
```

## 测试用例
### TC-001 模块位置与主题
- 类型：UI测试
- 前置条件：应用启动
- 操作步骤：观察“游戏设置 + 挑战记录”下方是否出现新卡片
- 预期结果：出现红色主题“玩法说明”卡片，宽度与内容区一致

### TC-002 模式切换动态说明
- 类型：功能测试
- 前置条件：应用启动
- 操作步骤：分别切换自由/竞分/竞速，且切换竞分时间档、竞速目标档
- 预期结果：说明文本中的“当前模式/当前档位或目标”随选择同步更新

### TC-003 多语言验证
- 类型：国际化测试
- 前置条件：应用启动
- 操作步骤：切换英/中/日/韩/俄语言
- 预期结果：玩法说明标题与分类文案均显示为对应语言，不出现 key 文本

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
