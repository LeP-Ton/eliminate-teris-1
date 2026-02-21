# 模块标题增加图标并统一间距

## 背景与目标
- 用户要求：给“游戏设置 / 时间与得分 / 挑战记录 / 玩法说明”四个模块标题前增加图标。
- 同时要求图标与标题文本之间保留稳定间距，保证视觉一致。

## 约束与原则
- 不改动业务逻辑，仅改 UI 头部结构。
- 图标颜色需与各模块主题色一致（蓝/绿/橙/红）。
- 间距统一，避免每个模块手动微调。

## 阶段与 TODO
- [x] 为四个模块新增标题图标视图。
- [x] 将标题从“纯文本”替换为“图标 + 标题”的头部堆栈。
- [x] 抽取公共方法统一图标大小、着色和间距。
- [x] 更新项目认知与索引。
- [x] 完成构建验证。

## 当前进展
- 四个模块标题已全部带图标，间距统一为 6px。
- 图标使用 SF Symbols，并与模块主题色一致。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
@@
     private lazy var settingsTitleLabel: NSTextField = {
         return makeSectionTitleLabel(color: settingsThemeColor)
     }()
+
+    private lazy var settingsTitleIconView: NSImageView = {
+        return makeSectionIconView(symbolName: "slider.horizontal.3", color: settingsThemeColor)
+    }()
+
+    private lazy var settingsHeaderStack: NSStackView = {
+        return makeSectionHeaderStack(iconView: settingsTitleIconView, titleLabel: settingsTitleLabel)
+    }()
@@
     private lazy var statusTitleLabel: NSTextField = {
         return makeSectionTitleLabel(color: statusThemeColor)
     }()
+
+    private lazy var statusTitleIconView: NSImageView = {
+        return makeSectionIconView(symbolName: "timer", color: statusThemeColor)
+    }()
+
+    private lazy var statusHeaderStack: NSStackView = {
+        return makeSectionHeaderStack(iconView: statusTitleIconView, titleLabel: statusTitleLabel)
+    }()
@@
     private lazy var rulesTitleLabel: NSTextField = {
         return makeSectionTitleLabel(color: rulesThemeColor)
     }()
+
+    private lazy var rulesTitleIconView: NSImageView = {
+        return makeSectionIconView(symbolName: "book.pages", color: rulesThemeColor)
+    }()
+
+    private lazy var rulesHeaderStack: NSStackView = {
+        return makeSectionHeaderStack(iconView: rulesTitleIconView, titleLabel: rulesTitleLabel)
+    }()
@@
     private lazy var settingsCardStack: NSStackView = {
-        let stack = NSStackView(views: [settingsTitleLabel, controlsGrid])
+        let stack = NSStackView(views: [settingsHeaderStack, controlsGrid])
@@
     private lazy var statusCardStack: NSStackView = {
-        let stack = NSStackView(views: [statusTitleLabel, statusBadgeLabel, competitiveInfoLabel, resultLabel])
+        let stack = NSStackView(views: [statusHeaderStack, statusBadgeLabel, competitiveInfoLabel, resultLabel])
@@
     private lazy var recordsTitleLabel: NSTextField = {
         return makeSectionTitleLabel(color: recordsThemeColor)
     }()
+
+    private lazy var recordsTitleIconView: NSImageView = {
+        return makeSectionIconView(symbolName: "list.number", color: recordsThemeColor)
+    }()
@@
     private lazy var recordsHeaderStack: NSStackView = {
-        let stack = NSStackView(views: [recordsTitleLabel])
+        let stack = NSStackView(views: [recordsTitleIconView, recordsTitleLabel])
@@
-        stack.spacing = 0
+        stack.spacing = 6
@@
     private lazy var rulesCardStack: NSStackView = {
-        let stack = NSStackView(views: [rulesTitleLabel, rulesBodyLabel])
+        let stack = NSStackView(views: [rulesHeaderStack, rulesBodyLabel])
@@
     private func makeSectionTitleLabel(color: NSColor) -> NSTextField {
@@
         return label
     }
+
+    private func makeSectionIconView(symbolName: String, color: NSColor) -> NSImageView {
+        let iconView = NSImageView()
+        iconView.translatesAutoresizingMaskIntoConstraints = false
+        iconView.imageScaling = .scaleProportionallyDown
+        iconView.contentTintColor = color.withAlphaComponent(0.95)
+
+        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
+            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
+            iconView.image = symbol.withSymbolConfiguration(config)
+        }
+
+        NSLayoutConstraint.activate([
+            iconView.widthAnchor.constraint(equalToConstant: 14),
+            iconView.heightAnchor.constraint(equalToConstant: 14)
+        ])
+        return iconView
+    }
+
+    private func makeSectionHeaderStack(iconView: NSImageView, titleLabel: NSTextField) -> NSStackView {
+        let stack = NSStackView(views: [iconView, titleLabel])
+        stack.orientation = .horizontal
+        stack.alignment = .centerY
+        stack.spacing = 6
+        stack.translatesAutoresizingMaskIntoConstraints = false
+        return stack
+    }
 }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
 - 玩法说明在所有模式下都已去掉模式小标题；基础规则第二条统一为“操作方式：...”前缀并保持多语言同步。
 - 自由模式下会隐藏右侧状态/记录列，并将“游戏设置”卡片扩展为占满整行宽度，与下方玩法说明卡片等宽。
+- 各模块（游戏设置/时间与得分/挑战记录/玩法说明）标题前已加入主题色图标，并统一保留约 6px 的图标与标题间距。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
 ## 当前变更文档
+`workflow/20260221131220-section-title-icons.md` - 为游戏设置/时间与得分/挑战记录/玩法说明标题加入图标，并统一图标与标题间距。
@@
 ## 读取场景
+- 需要确认“四个模块标题增加图标且间距一致”时，优先读取 `20260221131220` 文档。
@@
 ## 关键记忆
+- 四个模块标题均采用“图标 + 标题”头部，图标使用 SF Symbols 并按模块主题色着色，图标与标题间距统一为 `6`。
```

## 测试用例
### TC-001 模块标题图标显示
- 类型：UI测试
- 操作步骤：打开页面，观察游戏设置/时间与得分/挑战记录/玩法说明标题。
- 预期结果：每个标题前均显示图标。

### TC-002 图标间距一致性
- 类型：UI测试
- 操作步骤：对比四个模块标题中“图标与文字”的水平间距。
- 预期结果：间距一致，约为 6px，无紧贴或过大间隔。

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。
- 预期结果：构建成功。
