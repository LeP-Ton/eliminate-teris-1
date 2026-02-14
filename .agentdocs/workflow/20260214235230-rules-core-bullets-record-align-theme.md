# 恢复基础规则圆点样式，修复挑战记录两侧对齐并统一模块主题色

## 背景与目标
- 用户反馈本轮回归问题：
  1. 玩法说明中的“基础规则”被删，需要恢复。
  2. 玩法说明列表不应使用 `-`，应改回 `•`。
  3. 挑战记录“排名+得分 / 日期”两侧对齐失效，需要恢复。
  4. 其他模块标题与正文不应再使用白色文本，需要与模块主题色一致。

## 约束与原则
- 不改动玩法逻辑，仅修复展示与排版。
- 保持挑战记录上限、排序与 seed 逻辑不变。
- 保持玩法说明按当前模式和子规则动态变化。

## 阶段与 TODO
- [x] 恢复玩法说明中的基础规则并改回圆点序号。
- [x] 修复挑战记录在布局变化后失去右侧对齐的问题。
- [x] 将设置/状态/记录模块标题与主要正文替换为各自主题色。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 关键风险
- 挑战记录使用 `NSTextAttachment + NSTextTab` 组合排版，对容器宽度变化较敏感；本次通过布局阶段宽度变更触发重建文本，降低错位风险。

## 当前进展
- 玩法说明已恢复基础规则，结构改为“模式标题 + 圆点规则列表”。
- 挑战记录在 `viewDidLayout` 宽度变化时重新生成富文本，恢复两侧对齐稳定性。
- 游戏设置、时间与得分、挑战记录模块标题与主要正文已切换到蓝/绿/橙主题色。

## 代码变更
- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index dcde583..bd6da0a 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -13,3 +13,5 @@
 - 新增“玩法说明”模块，位于游戏设置与挑战记录下方，使用罗德岛风格红色主题边框，并按“基础规则/模式规则/结算规则”分类展示。
 - 玩法说明会根据当前模式与规则档位动态变化（自由、竞分档位、竞速目标分），用于解释不同玩法规则。
 - 玩法说明文案已改为精简版结构：仅展示“模式标题 + 模式规则 + 结算方式”，不再显示“模式规则/结算规则/当前模式”分段模块。
+- 玩法说明已恢复“基础规则”，并把列表符号统一为 `•`；挑战记录在面板宽度变化时会重建排版，恢复“排名+得分/日期”两侧对齐。
+- 游戏设置、时间与得分、挑战记录模块的标题与主要内容文本已统一切换为对应主题色（蓝/绿/橙），不再使用白色正文。
```

- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 9448ef9..04b45d1 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -31,6 +31,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }
 
     private let localizer = Localizer.shared
+    private let settingsThemeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
+    private let statusThemeColor = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
+    private let recordsThemeColor = NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.58, alpha: 0.96)
+    private let rulesThemeColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
+    private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
@@ -49,6 +54,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private var lastScoreGainDate: Date?
     private var hasSavedFinishedRecord = false
     private var latestRecordIDByMode: [String: String] = [:]
+    private var lastRecordsLayoutWidth: CGFloat = 0
@@ -102,11 +108,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var settingsTitleLabel: NSTextField = {
-        return makeSectionTitleLabel()
+        return makeSectionTitleLabel(color: settingsThemeColor)
     }()
 
     private lazy var statusTitleLabel: NSTextField = {
-        return makeSectionTitleLabel()
+        return makeSectionTitleLabel(color: statusThemeColor)
     }()
@@ -124,7 +130,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var languageTitleLabel: NSTextField = {
-        return makeControlTitleLabel()
+        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
     }()
@@ -136,7 +142,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var modeTitleLabel: NSTextField = {
-        return makeControlTitleLabel()
+        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
     }()
@@ -148,7 +154,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var optionTitleLabel: NSTextField = {
-        return makeControlTitleLabel()
+        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
     }()
@@ -160,7 +166,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var startTitleLabel: NSTextField = {
-        return makeControlTitleLabel()
+        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
     }()
@@ -201,7 +207,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private lazy var resultLabel: NSTextField = {
         let label = NSTextField(wrappingLabelWithString: "")
         label.alignment = .left
-        label.textColor = NSColor.white.withAlphaComponent(0.86)
+        label.textColor = statusThemeColor.withAlphaComponent(0.86)
         label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
         label.maximumNumberOfLines = 0
         label.translatesAutoresizingMaskIntoConstraints = false
@@ -209,15 +215,13 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var rulesTitleLabel: NSTextField = {
-        let label = makeSectionTitleLabel()
-        label.textColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
-        return label
+        return makeSectionTitleLabel(color: rulesThemeColor)
     }()
 
     private lazy var rulesBodyLabel: NSTextField = {
         let label = NSTextField(wrappingLabelWithString: "")
         label.alignment = .left
-        label.textColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
+        label.textColor = rulesBodyThemeColor
         label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
         label.maximumNumberOfLines = 0
         label.translatesAutoresizingMaskIntoConstraints = false
@@ -271,7 +275,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }()
 
     private lazy var recordsTitleLabel: NSTextField = {
-        return makeSectionTitleLabel()
+        return makeSectionTitleLabel(color: recordsThemeColor)
     }()
@@ -293,7 +297,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         textView.importsGraphics = false
         textView.textContainerInset = NSSize(width: 2, height: 2)
         textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
-        textView.textColor = NSColor.white.withAlphaComponent(0.88)
+        textView.textColor = recordsThemeColor.withAlphaComponent(0.88)
         textView.string = ""
         textView.minSize = NSSize(width: 0, height: 0)
         textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
@@ -485,6 +489,11 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     override func viewDidLayout() {
         super.viewDidLayout()
+        let currentWidth = max(recordsScrollView.contentSize.width, 0)
+        if abs(currentWidth - lastRecordsLayoutWidth) > 0.5 {
+            lastRecordsLayoutWidth = currentWidth
+            updateRecordPanel(with: controller.snapshot())
+        }
         refreshRecordsTextLayout()
     }
@@ -652,6 +661,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     private func updateRulesDescription(for selection: ModeSelection) {
         let modeTitle: String
+        let coreRulePrimary = localized("rules.core.line1")
+        let coreRuleSecondary = localized("rules.core.line2")
         let modeRule: String
         let settlementRule: String
@@ -674,11 +685,13 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             settlementRule = localized("rules.short.settlement.speed_run")
         }
 
-        // 玩法说明改为精简结构：模式名 + 两条规则（模式规则/结算方式）。
+        // 玩法说明保持简短结构，同时恢复“基础规则”并统一使用圆点分隔。
         let description = """
         \(modeTitle)
-        - \(localized("rules.label.mode_rule"))：\(modeRule)
-        - \(localized("rules.label.settlement"))：\(settlementRule)
+        • \(localized("rules.category.core"))：\(coreRulePrimary)
+        • \(coreRuleSecondary)
+        • \(localized("rules.label.mode_rule"))：\(modeRule)
+        • \(localized("rules.label.settlement"))：\(settlementRule)
         """
         rulesBodyLabel.stringValue = description
     }
@@ -962,7 +975,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     }
 
     private func setRecordRows(_ records: [ModeRecord], modeKey: ModeRecordKey, newestRecordID: String?) {
-        let availableWidth = max(recordsScrollView.contentSize.width - 2, 180)
+        let availableWidth = recordRowTabStopWidth()
         let paragraphStyle = NSMutableParagraphStyle()
         paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: availableWidth, options: [:])]
         paragraphStyle.defaultTabInterval = availableWidth
@@ -974,17 +987,17 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
         let metricAttributes: [NSAttributedString.Key: Any] = [
             .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
-            .foregroundColor: NSColor.white.withAlphaComponent(0.94),
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.94),
             .paragraphStyle: paragraphStyle
         ]
         let dateAttributes: [NSAttributedString.Key: Any] = [
             .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
-            .foregroundColor: NSColor.white.withAlphaComponent(0.48),
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.5),
             .paragraphStyle: paragraphStyle
         ]
         let newAttributes: [NSAttributedString.Key: Any] = [
             .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy),
-            .foregroundColor: NSColor.systemOrange.withAlphaComponent(0.95),
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.88),
             .paragraphStyle: paragraphStyle
         ]
@@ -1027,7 +1040,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .heavy)
         let attributes: [NSAttributedString.Key: Any] = [
             .font: font,
-            .foregroundColor: NSColor.white.withAlphaComponent(0.96)
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96)
         ]
         let textSize = (text as NSString).size(withAttributes: attributes)
         let horizontalInset: CGFloat = 6
@@ -1052,7 +1065,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         paragraph.alignment = .center
         let drawAttributes: [NSAttributedString.Key: Any] = [
             .font: font,
-            .foregroundColor: NSColor.white.withAlphaComponent(0.96),
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96),
             .paragraphStyle: paragraph
         ]
         let textRect = NSRect(
@@ -1107,12 +1120,18 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private func setRecordsText(_ text: String) {
         let attributes: [NSAttributedString.Key: Any] = [
             .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
-            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
+            .foregroundColor: recordsThemeColor.withAlphaComponent(0.9)
         ]
         let attributed = NSAttributedString(string: text, attributes: attributes)
         setRecordsText(attributed)
     }
+
+    private func recordRowTabStopWidth() -> CGFloat {
+        let insetWidth = recordsTextView.textContainerInset.width * 2
+        let width = recordsScrollView.contentSize.width - insetWidth - 2
+        return max(width, 180)
+    }
@@ -1153,20 +1172,20 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return String(format: format, locale: localizer.locale, arguments: arguments)
     }
 
-    private func makeControlTitleLabel() -> NSTextField {
+    private func makeControlTitleLabel(color: NSColor) -> NSTextField {
         let label = NSTextField(labelWithString: "")
         label.alignment = .right
-        label.textColor = NSColor.white.withAlphaComponent(0.7)
+        label.textColor = color
         label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
         label.setContentHuggingPriority(.required, for: .horizontal)
         label.translatesAutoresizingMaskIntoConstraints = false
         return label
     }
 
-    private func makeSectionTitleLabel() -> NSTextField {
+    private func makeSectionTitleLabel(color: NSColor) -> NSTextField {
         let label = NSTextField(labelWithString: "")
         label.alignment = .left
-        label.textColor = NSColor.white.withAlphaComponent(0.78)
+        label.textColor = color
         label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
         label.translatesAutoresizingMaskIntoConstraints = false
         return label
@@ -1474,7 +1493,7 @@ private final class ArcadePopupButton: NSPopUpButton {
         wantsLayer = true
         isBordered = false
         focusRingType = .none
-        contentTintColor = .white
+        contentTintColor = NSColor(calibratedRed: 0.8, green: 0.91, blue: 1.0, alpha: 0.96)
         setContentHuggingPriority(.defaultLow, for: .horizontal)
         setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
@@ -1491,7 +1510,9 @@ private final class ArcadePopupButton: NSPopUpButton {
 
     private func updateTitleStyle() {
         let title = selectedItem?.title ?? ""
-        let color = isEnabled ? NSColor.white : NSColor.white.withAlphaComponent(0.4)
+        let color = isEnabled
+            ? NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.96)
+            : NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.42)
         attributedTitle = NSAttributedString(
             string: "    \(title)    ",
             attributes: [
@@ -1566,11 +1587,11 @@ private final class ArcadePopupButton: NSPopUpButton {
     private func updateChevronTint() {
         let tint: NSColor
         if !isEnabled {
-            tint = NSColor.white.withAlphaComponent(0.35)
+            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.36)
         } else if isHighlighted {
-            tint = NSColor.white.withAlphaComponent(0.92)
+            tint = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 0.92)
         } else {
-            tint = NSColor.white.withAlphaComponent(0.72)
+            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.74)
         }
 
         chevronImageView?.contentTintColor = tint
@@ -1648,7 +1669,7 @@ private final class ArcadeActionButton: NSButton {
         focusRingType = .none
         imagePosition = .noImage
         alignment = .center
-        contentTintColor = .white
+        contentTintColor = NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
         setContentHuggingPriority(.defaultLow, for: .horizontal)
         setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         setButtonType(.momentaryPushIn)
@@ -1696,7 +1717,9 @@ private final class ArcadeActionButton: NSButton {
     }
 
     private func updateTitleStyle() {
-        let color = isEnabled ? NSColor.white : NSColor.white.withAlphaComponent(0.45)
+        let color = isEnabled
+            ? NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
+            : NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.45)
         textLabel.stringValue = displayTitle
         textLabel.textColor = color
         textLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260214235230-rules-core-bullets-record-align-theme.md` - 恢复基础规则与圆点序号，修复挑战记录两侧对齐，并把模块文字改为主题色。
@@
 ## 读取场景
+- 需要确认“基础规则已恢复 + 玩法说明圆点序号 + 挑战记录两侧对齐恢复 + 模块文本主题色”时，优先读取 `20260214235230` 文档。
@@
 ## 关键记忆
+- 玩法说明现已补回“基础规则”并统一 `•` 圆点样式；挑战记录会在布局宽度变化时重建富文本，确保“排名+得分/日期”保持两侧对齐。
+- 游戏设置/时间与得分/挑战记录模块标题与主要内容文本统一为蓝/绿/橙主题色，避免白色正文与主题割裂。
```

## 测试用例
### TC-001 玩法说明基础规则恢复与圆点样式
- 类型：UI测试
- 操作步骤：切换自由/竞分/竞速，观察玩法说明
- 预期结果：每种模式都显示基础规则，且列表符号使用 `•`，不再出现 `-`

### TC-002 挑战记录两侧对齐稳定性
- 类型：UI测试
- 操作步骤：切换模式与窗口尺寸，观察挑战记录每行“左侧排名+指标 / 右侧日期”
- 预期结果：左右两侧保持对齐，模式切换后不出现日期贴左问题

### TC-003 模块主题色一致性
- 类型：UI测试
- 操作步骤：查看游戏设置、时间与得分、挑战记录模块的标题与正文
- 预期结果：文本分别为蓝/绿/橙主题色，不再出现白色正文

### TC-004 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
