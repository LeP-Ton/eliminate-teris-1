# 修复模式切换时窗口尺寸跳变与挑战记录对齐漂移

## 背景与目标
- 用户反馈两个问题：
  1. 切换游戏模式后窗口尺寸会变化。
  2. 切换游戏模式后挑战记录的两端对齐会变化。
- 目标：保持窗口尺寸稳定，并保证记录文本在模式切换后仍按最终布局宽度对齐。

## 约束与原则
- 不改玩法规则，仅调整模式切换时机与布局刷新策略。
- 保持现有自由模式单列 / 竞分竞速双列布局逻辑。
- 避免引入额外状态复杂度，优先最小改动。

## 阶段与 TODO
- [x] 在模式切换前后增加窗口 frame 保护。
- [x] 在模式切换完成后，按最终布局宽度重算挑战记录文本。
- [x] 更新项目认知与索引。
- [x] 完成构建验证。

## 当前进展
- `applyModeSelection` 在更新前记录窗口 frame，更新后若尺寸被动变化则恢复。
- 模式切换后追加一次 `layoutSubtreeIfNeeded + updateRecordPanel`，保证两端对齐基于最终宽度重算。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 0b72c49..b73fa25 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -607,6 +607,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
     private func applyModeSelection(resetGame: Bool) {
         let selection = currentModeSelection
+        let windowFrameBeforeUpdate = view.window?.frame
         populateOptionPopup(for: selection)
         updateStartControlVisibility(for: selection)
         updateCardsLayout(for: selection)
@@ -619,6 +620,8 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         }
 
         updateCompetitiveInfo()
+        preserveWindowFrame(windowFrameBeforeUpdate)
+        refreshRecordPanelAfterLayoutIfNeeded()
     }
@@ -713,6 +716,26 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         rightColumnMinWidthConstraint?.isActive = !shouldExpandSettings
     }
 
+    private func preserveWindowFrame(_ previousFrame: NSRect?) {
+        guard let previousFrame,
+              let window = view.window else {
+            return
+        }
+
+        let shouldRestoreFrame =
+            abs(window.frame.width - previousFrame.width) > 0.5 ||
+            abs(window.frame.height - previousFrame.height) > 0.5
+
+        guard shouldRestoreFrame else { return }
+        window.setFrame(previousFrame, display: false, animate: false)
+    }
+
+    private func refreshRecordPanelAfterLayoutIfNeeded() {
+        guard currentModeSelection != .free else { return }
+        view.layoutSubtreeIfNeeded()
+        updateRecordPanel(with: controller.snapshot())
+    }
+
     private func updateRulesDescription(for selection: ModeSelection) {
         let coreRulePrimary = localized("rules.core.line1")
         let coreRuleSecondary = localized("rules.core.line2")
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 825de91..81911ee 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -19,3 +19,4 @@
 - 自由模式下会隐藏右侧状态/记录列，并将“游戏设置”卡片扩展为占满整行宽度，与下方玩法说明卡片等宽。
 - 各模块（游戏设置/时间与得分/挑战记录/玩法说明）标题前已加入主题色图标，并统一保留约 6px 的图标与标题间距。
 - 玩法说明标题图标已切换为兼容性更高的 `doc.text`，并增加系统符号缺失时的回退图标，避免个别系统版本不显示。
+- 模式切换时会锁定窗口 frame，避免自由/竞分/竞速切换引发窗口尺寸跳变；并在切换后强制按最终布局重算挑战记录两端对齐文本。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221133502-mode-switch-window-lock-record-align.md` - 修复模式切换导致窗口尺寸变化，并在切换后重算挑战记录两端对齐。
@@
 ## 读取场景
+- 需要确认“模式切换后窗口尺寸稳定 + 挑战记录两端对齐稳定”时，优先读取 `20260221133502` 文档。
@@
 ## 关键记忆
+- 模式切换流程中已加入窗口 frame 保护与切换后记录面板二次重排，解决窗口跳变和记录对齐漂移。
```

## 测试用例
### TC-001 模式切换窗口尺寸稳定
- 类型：UI测试
- 操作步骤：在自由/竞分/竞速之间多次切换。
- 预期结果：窗口宽高保持不变，不出现自动拉伸或收缩。

### TC-002 挑战记录两端对齐稳定
- 类型：UI测试
- 操作步骤：在竞分与竞速模式之间切换并观察挑战记录每行。
- 预期结果：左侧排名+指标与右侧日期持续保持两端对齐。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
