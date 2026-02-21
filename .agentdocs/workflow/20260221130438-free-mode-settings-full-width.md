# 自由模式下游戏设置卡片扩展为整行宽度

## 背景与目标
- 用户要求：自由模式时“游戏设置”模块宽度应占满，与“玩法说明”宽度一致。
- 目标：在自由模式隐藏右侧状态/挑战记录列，让设置卡片单列铺满；竞分/竞速保持原双列布局。

## 约束与原则
- 仅调整布局约束与显隐，不改玩法逻辑。
- 保持现有模块结构（settings + rightColumn + rules）不重构。
- 模式切换时布局需可逆：自由模式扩展，竞分/竞速恢复。

## 阶段与 TODO
- [x] 为布局新增可切换约束（整行宽约束/双列比例约束）。
- [x] 自由模式隐藏右侧列并激活整行宽约束。
- [x] 竞分/竞速恢复右侧列并还原双列约束。
- [x] 更新项目认知与索引文档。
- [x] 完成构建验证。

## 当前进展
- 自由模式下：`rightColumnStack` 隐藏，`settingsCardView` 与 `cardsStack` 等宽。
- 竞分/竞速：恢复原比例关系（设置宽度 >= 右列宽度 * 1.24，右列最小宽度 250）。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
@@
     private var hasSavedFinishedRecord = false
     private var latestRecordIDByMode: [String: String] = [:]
     private var lastRecordsLayoutWidth: CGFloat = 0
+    private var settingsExpandedWidthConstraint: NSLayoutConstraint?
+    private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
+    private var rightColumnMinWidthConstraint: NSLayoutConstraint?
@@
     private lazy var cardsStack: NSStackView = {
         let stack = NSStackView(views: [settingsCardView, rightColumnStack])
         stack.orientation = .horizontal
         stack.alignment = .top
         stack.distribution = .fill
         stack.spacing = 14
+        stack.detachesHiddenViews = true
         stack.translatesAutoresizingMaskIntoConstraints = false
         return stack
     }()
@@
     override func loadView() {
@@
         statusCardView.addSubview(statusCardStack)
         recordsCardView.addSubview(recordsCardStack)
         rulesCardView.addSubview(rulesCardStack)
+
+        let settingsVersusRightColumnConstraint = settingsCardView.widthAnchor.constraint(
+            greaterThanOrEqualTo: rightColumnStack.widthAnchor,
+            multiplier: 1.24
+        )
+        let rightColumnMinWidthConstraint = rightColumnStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
+        let settingsExpandedWidthConstraint = settingsCardView.widthAnchor.constraint(equalTo: cardsStack.widthAnchor)
+        settingsExpandedWidthConstraint.isActive = false
+
+        self.settingsVersusRightColumnConstraint = settingsVersusRightColumnConstraint
+        self.rightColumnMinWidthConstraint = rightColumnMinWidthConstraint
+        self.settingsExpandedWidthConstraint = settingsExpandedWidthConstraint
@@
             cardsStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
             settingsCardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 390),
-            settingsCardView.widthAnchor.constraint(greaterThanOrEqualTo: rightColumnStack.widthAnchor, multiplier: 1.24),
-            rightColumnStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
+            settingsVersusRightColumnConstraint,
+            rightColumnMinWidthConstraint,
             rightColumnStack.heightAnchor.constraint(lessThanOrEqualTo: settingsCardView.heightAnchor),
             statusCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),
             recordsCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),
@@
     private func applyModeSelection(resetGame: Bool) {
         let selection = currentModeSelection
         populateOptionPopup(for: selection)
         updateStartControlVisibility(for: selection)
+        updateCardsLayout(for: selection)
         updateRulesDescription(for: selection)
@@
         populateOptionPopup(for: currentModeSelection)
         updateStartControlVisibility(for: currentModeSelection)
+        updateCardsLayout(for: currentModeSelection)
         updateRulesDescription(for: currentModeSelection)
@@
     private func updateStartControlVisibility(for selection: ModeSelection) {
         let actionRow = controlsGrid.row(at: ControlRow.action.rawValue)
         actionRow.isHidden = selection == .free
     }
+
+    private func updateCardsLayout(for selection: ModeSelection) {
+        let shouldExpandSettings = selection == .free
+        rightColumnStack.isHidden = shouldExpandSettings
+        settingsExpandedWidthConstraint?.isActive = shouldExpandSettings
+        settingsVersusRightColumnConstraint?.isActive = !shouldExpandSettings
+        rightColumnMinWidthConstraint?.isActive = !shouldExpandSettings
+    }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
 - 游戏设置、时间与得分、挑战记录模块的标题与主要内容文本已统一切换为对应主题色（蓝/绿/橙），不再使用白色正文。
 - 玩法说明在所有模式下都已去掉模式小标题；基础规则第二条统一为“操作方式：...”前缀并保持多语言同步。
+- 自由模式下会隐藏右侧状态/记录列，并将“游戏设置”卡片扩展为占满整行宽度，与下方玩法说明卡片等宽。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221130438-free-mode-settings-full-width.md` - 自由模式隐藏右侧列，游戏设置卡片扩展为整行，与玩法说明等宽。
@@
 ## 读取场景
+- 需要确认“自由模式游戏设置卡片占满整行、与玩法说明同宽”时，优先读取 `20260221130438` 文档。
@@
 ## 关键记忆
+- 自由模式会隐藏右侧状态/挑战记录列，并启用设置卡片整行宽约束；竞分/竞速模式恢复双列布局约束。
```

## 测试用例
### TC-001 自由模式宽度铺满
- 类型：UI测试
- 操作步骤：切换到自由模式，观察“游戏设置”与“玩法说明”左右边界。
- 预期结果：游戏设置卡片宽度与玩法说明一致，占满整行。

### TC-002 竞分/竞速回退双列
- 类型：UI测试
- 操作步骤：切换到竞分或竞速。
- 预期结果：右侧状态/挑战记录列恢复显示，布局回到双列。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
