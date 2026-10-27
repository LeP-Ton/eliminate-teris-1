# 成就标签布局与可读性修复

## 背景与目标
- 对应会话：会话-16 起，本轮修复用户截图反馈的标签底部遮挡、图标偏左和标签过宽。
- 默认可视区域完整展示 5 枚成就，其余成就继续通过横向滚动浏览。
- 工作区包含上一轮尚未提交的成就系统实现；本文严格以本轮开始时的文件快照为基线，仅记录本轮增量。上一轮完整记录保留在 `20261026092356-achievement-system.md`。

## 约束与原则
- 沿用现有红色像素卡片、已解锁绿色与未解锁浅红色状态。
- 保持成就条件、存档、通知队列、详情面板及 Touch Bar 行为不变。
- 本轮属于局部界面修复，不改变项目核心架构认知，因此不向根 AGENTS.md 添加需求细节。
- 参考 ui-ux-pro-max 的间距、内容对齐与对比度规则；保持原生 AppKit 实现。

## 阶段与 TODO
- [x] 移除成就卡片与 88 点横幅的等高约束，为滚动区域独立保留 64 点高度。
- [x] 按实际可视宽度计算五枚标签的宽度，标签高 32 点、间距 10 点、左右内边距 6 点。
- [x] 将图标和文字合为居中内容组，维持整枚按钮点击行为。
- [x] 长名称单行截断，悬浮提示及辅助功能保留完整名称。
- [x] 显式指定“查看全部”的文字颜色，提升深色背景上的可读性。
- [x] 完成原生界面回归、构建及差异检查，更新索引和逐行 diff。

## 关键实现
- `AchievementBadgeStripView` 根据滚动视口尺寸布局标签，兼容常驻与覆盖式滚动条；窗口尺寸变化后保留并约束滚动位置。
- `AchievementBadgeButton` 通过内容组中心约束实现图文整体居中，图标固定为 12 点；子视图的点击统一交给按钮处理。
- 卡片总高度由标题、间距、64 点滚动区和上下内边距计算，避免固定总高度挤压标签。
- 不新增第三方依赖，测试沿用系统 XCTest。

## 测试用例

### TC-001 默认五枚且无遮挡
- 类型：界面回归；优先级：高；模块：AchievementBadgeStripView。
- 前置条件：真实 AppKit 视图，分别采用常驻和覆盖式滚动条。
- 操作步骤：将宽度设为 500、644、900 点，完成布局并检查实际裁切区域。
- 预期结果：完整及部分可见的标签均恰好是前五枚；标签上下均有留白，右侧不露出半枚标签；剩余内容仍可滚动。
- 是否通过：通过。

### TC-002 图文居中、长名称和点击
- 类型：界面回归；优先级：高；模块：AchievementBadgeButton。
- 前置条件：加载中、英、日、韩、俄五种语言的真实文案。
- 操作步骤：检查全部标签的内容组中心、图文中心、左右内边距，分别命中图标/文字并触发按钮。
- 预期结果：内容组在标签中央（允许原生像素对齐误差），长名称保留边距并在悬浮提示中完整展示；点击返回正确成就编号。
- 是否通过：通过。

### TC-003 原图鉴回归
- 类型：界面回归；优先级：中；模块：AchievementsWindowController。
- 操作步骤：验证全部/已解锁/未解锁筛选、不获取主窗口焦点，并在五种语言、480/600 点宽度下布局图鉴。
- 预期结果：原有筛选、焦点与滚动布局正常。
- 是否通过：通过（沿用 2 项既有测试）。

## 当前进展与验证结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementPresentationTests`：4 项测试，0 失败，已完成应用编译与链接。
- `git diff --check`：通过。
- 测试的图文坐标检查允许一个物理像素的原生取整误差；点击检查按 AppKit 要求使用父视图坐标。
- 未重启用户正在运行的游戏。重新执行 `./run.sh` 后可查看本轮界面。

## 代码变更

下列为相对本轮开始快照的完整逐行 diff，可用于区分和回溯本轮与上一轮改动。

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -74,9 +74,6 @@
     private var hasSavedFinishedRecord = false
     private var latestRecordIDByMode: [String: String] = [:]
     private var lastRecordsLayoutWidth: CGFloat = 0
-    private var achievementButtons: [Int: NSButton] = [:]
-    private var achievementsContentWidthConstraint: NSLayoutConstraint?
-    private var achievementsContainerWrapper: NSView?
     private var achievementsUnlockObserver: NSObjectProtocol?
     private var achievementsChangeObserver: NSObjectProtocol?
     private var achievementsPanel: AchievementsWindowController?
@@ -445,26 +442,10 @@
         return stack
     }()
 
-    private lazy var achievementsContainerStack: NSStackView = {
-        let stack = NSStackView()
-        stack.orientation = .horizontal
-        stack.alignment = .centerY
-        stack.spacing = 10
-        stack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        return stack
-    }()
-
-    private lazy var achievementsScrollView: NSScrollView = {
-        let scroll = NSScrollView()
-        scroll.translatesAutoresizingMaskIntoConstraints = false
-        scroll.drawsBackground = false
-        scroll.hasHorizontalScroller = true
-        scroll.hasVerticalScroller = false
-        scroll.autohidesScrollers = true
-        scroll.borderType = .noBorder
-        // documentView will be set when building content to allow explicit content width
-        return scroll
+    private lazy var achievementsScrollView: AchievementBadgeStripView = {
+        let strip = AchievementBadgeStripView()
+        strip.onSelect = { [weak self] id in self?.presentAchievements(detailID: id) }
+        return strip
     }()
 
     private lazy var achievementsCardView: PixelFrameCardView = {
@@ -600,8 +581,8 @@
             achievementsCardStack.bottomAnchor.constraint(equalTo: achievementsCardView.bottomAnchor, constant: -14),
             achievementsScrollView.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
             achievementsHeaderStack.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
-            // 固定成就卡片高度与 PixelBannerView 相同（与标题下方的四块方块区域等高）
-            achievementsCardView.heightAnchor.constraint(equalTo: pixelBannerView.heightAnchor),
+            // 高度由标题、内边距及完整标签区共同决定，不再受横幅高度限制。
+            achievementsScrollView.heightAnchor.constraint(equalToConstant: AchievementBadgeStripView.preferredHeight),
 
             languagePopup.widthAnchor.constraint(equalToConstant: 240),
             languagePopup.heightAnchor.constraint(equalToConstant: 38),
@@ -640,42 +621,6 @@
     // MARK: - Achievements
 
     private func configureAchievements() {
-        let wrapper = NSView()
-        wrapper.translatesAutoresizingMaskIntoConstraints = false
-        wrapper.addSubview(achievementsContainerStack)
-        achievementsScrollView.documentView = wrapper
-        achievementsContainerWrapper = wrapper
-        let definitions = AchievementDefinition.all
-        let buttonWidth: CGFloat = 210
-        let buttonHeight: CGFloat = 28
-        for definition in definitions {
-            let button = NSButton(title: "", target: self, action: #selector(achievementTapped(_:)))
-            button.tag = definition.id
-            button.bezelStyle = .regularSquare
-            button.isBordered = false
-            button.font = .systemFont(ofSize: 11, weight: .semibold)
-            button.wantsLayer = true
-            button.layer?.cornerRadius = 6
-            button.layer?.borderWidth = 1
-            button.imagePosition = .imageLeading
-            button.translatesAutoresizingMaskIntoConstraints = false
-            NSLayoutConstraint.activate([
-                button.widthAnchor.constraint(equalToConstant: buttonWidth),
-                button.heightAnchor.constraint(equalToConstant: buttonHeight)
-            ])
-            achievementsContainerStack.addArrangedSubview(button)
-            achievementButtons[definition.id] = button
-        }
-        let insets = achievementsContainerStack.edgeInsets
-        let width = CGFloat(definitions.count) * buttonWidth + CGFloat(definitions.count - 1) * achievementsContainerStack.spacing + insets.left + insets.right
-        achievementsContentWidthConstraint = wrapper.widthAnchor.constraint(equalToConstant: width)
-        NSLayoutConstraint.activate([
-            achievementsContainerStack.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
-            achievementsContainerStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
-            achievementsContainerStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
-            wrapper.heightAnchor.constraint(equalToConstant: buttonHeight + insets.top + insets.bottom),
-            achievementsContentWidthConstraint!
-        ])
         achievementToasts = AchievementToastPresenter(host: view) { [weak self] ids in
             self?.presentAchievements(detailID: ids.count == 1 ? ids.first : nil)
         }
@@ -694,18 +639,12 @@
     private func refreshAchievements() {
         let manager = AchievementsManager.shared
         achievementsTitleLabel.stringValue = localizedFormat("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
-        achievementsAllButton.title = localized("achievement.view_all")
-        for definition in AchievementDefinition.all {
-            guard let button = achievementButtons[definition.id] else { continue }
-            let unlocked = manager.isUnlocked(id: definition.id)
-            button.title = localized(definition.titleKey)
-            button.image = NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil)
-            button.contentTintColor = unlocked ? .systemGreen : rulesBodyThemeColor
-            button.layer?.borderColor = (unlocked ? NSColor.systemGreen : rulesThemeColor).cgColor
-            button.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor
-            button.toolTip = localized(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
-            button.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
-        }
+        // 自绘深色背景下显式指定文字颜色，避免 inline 按钮回退成黑色文字。
+        achievementsAllButton.attributedTitle = NSAttributedString(
+            string: localized("achievement.view_all"),
+            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: rulesThemeColor]
+        )
+        achievementsScrollView.refresh(manager: manager)
         if achievementsPanel?.window?.isVisible == true { achievementsPanel?.refresh() }
         achievementToasts?.refreshLanguage()
     }
@@ -718,7 +657,6 @@
     }
 
     @objc private func showAllAchievements() { presentAchievements(detailID: nil) }
-    @objc private func achievementTapped(_ sender: NSButton) { presentAchievements(detailID: sender.tag) }
 
     deinit {
         if let observerToken {
```

### `Sources/AchievementViews.swift`

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -49,6 +49,131 @@
         formatter.timeStyle = .short
         return format("achievement.date", formatter.string(from: date))
     }
+}
+
+/// 标签内容作为一个整体居中，避免 NSButton 原生布局把图标贴到左边缘。
+final class AchievementBadgeButton: NSButton {
+    private let iconView = NSImageView()
+    private let nameLabel = NSTextField(labelWithString: "")
+
+    override init(frame frameRect: NSRect) {
+        super.init(frame: frameRect)
+        title = ""
+        isBordered = false
+        setButtonType(.momentaryPushIn)
+        wantsLayer = true
+        layer?.cornerRadius = 6
+        layer?.borderWidth = 1
+        layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor
+
+        iconView.translatesAutoresizingMaskIntoConstraints = false
+        iconView.imageScaling = .scaleProportionallyDown
+        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
+        nameLabel.lineBreakMode = .byTruncatingTail
+        nameLabel.usesSingleLineMode = true
+        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
+        let content = NSStackView(views: [iconView, nameLabel])
+        content.orientation = .horizontal
+        content.alignment = .centerY
+        content.spacing = 5
+        content.translatesAutoresizingMaskIntoConstraints = false
+        content.setContentHuggingPriority(.required, for: .horizontal)
+        content.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
+        addSubview(content)
+        NSLayoutConstraint.activate([
+            iconView.widthAnchor.constraint(equalToConstant: 12),
+            iconView.heightAnchor.constraint(equalToConstant: 12),
+            content.centerXAnchor.constraint(equalTo: centerXAnchor),
+            content.centerYAnchor.constraint(equalTo: centerYAnchor),
+            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
+            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
+        ])
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    func refresh(_ definition: AchievementDefinition, manager: AchievementsManager) {
+        let unlocked = manager.isUnlocked(id: definition.id)
+        let color = unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.82, blue: 0.82, alpha: 0.9)
+        nameLabel.stringValue = AchievementText.string(definition.titleKey)
+        nameLabel.textColor = color
+        iconView.image = NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil)
+        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
+        iconView.contentTintColor = color
+        layer?.borderColor = (unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.53, blue: 0.5, alpha: 0.96)).cgColor
+        toolTip = AchievementText.string(definition.titleKey) + "\n" + AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
+        setAccessibilityLabel(AchievementText.title(definition, manager: manager))
+    }
+
+    // 图标和文字只负责展示，整个标签仍作为同一个按钮接收点击。
+    override func hitTest(_ point: NSPoint) -> NSView? {
+        super.hitTest(point) == nil ? nil : self
+    }
+}
+
+/// 可视区域恰好容纳五枚标签；独立预留高度以兼容常驻和覆盖式滚动条。
+final class AchievementBadgeStripView: NSScrollView {
+    static let preferredHeight: CGFloat = 64
+    private let definitions: [AchievementDefinition]
+    private let document = NSView()
+    private var badges: [AchievementBadgeButton] = []
+    private var previousViewportSize = NSSize.zero
+    var onSelect: ((Int) -> Void)?
+
+    init(definitions: [AchievementDefinition] = AchievementDefinition.all) {
+        self.definitions = definitions
+        super.init(frame: .zero)
+        translatesAutoresizingMaskIntoConstraints = false
+        drawsBackground = false
+        hasHorizontalScroller = true
+        hasVerticalScroller = false
+        autohidesScrollers = true
+        borderType = .noBorder
+        automaticallyAdjustsContentInsets = false
+        horizontalScrollElasticity = .none
+        verticalScrollElasticity = .none
+        documentView = document
+        for definition in definitions {
+            let button = AchievementBadgeButton(frame: .zero)
+            button.tag = definition.id
+            button.target = self
+            button.action = #selector(badgeTapped(_:))
+            document.addSubview(button)
+            badges.append(button)
+        }
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    func refresh(manager: AchievementsManager) {
+        for (definition, badge) in zip(definitions, badges) {
+            badge.refresh(definition, manager: manager)
+        }
+    }
+
+    override func layout() {
+        super.layout()
+        let viewport = contentView.bounds.size
+        guard viewport.width > 0, viewport.height > 0, viewport != previousViewportSize else { return }
+        previousViewportSize = viewport
+        let inset: CGFloat = 6
+        let spacing: CGFloat = 10
+        let width = max(1, (viewport.width - inset * 2 - spacing * 4) / 5)
+        let height: CGFloat = 32
+        let oldOffset = contentView.bounds.origin.x
+        document.setFrameSize(NSSize(width: inset * 2 + CGFloat(badges.count) * width + CGFloat(max(0, badges.count - 1)) * spacing,
+                                     height: viewport.height))
+        for (index, badge) in badges.enumerated() {
+            badge.frame = NSRect(x: inset + CGFloat(index) * (width + spacing),
+                                 y: (viewport.height - height) / 2, width: width, height: height)
+        }
+        // 尺寸变化后保留浏览位置，并限制在有效范围，避免末端出现大片空白。
+        let maximumOffset = max(0, document.frame.width - viewport.width)
+        contentView.scroll(to: NSPoint(x: min(max(0, oldOffset), maximumOffset), y: 0))
+        reflectScrolledClipView(contentView)
+    }
+
+    @objc private func badgeTapped(_ sender: NSButton) { onSelect?(sender.tag) }
 }
 
 /// 面板不争夺主窗口焦点，点击筛选时仍保留 Touch Bar 的游戏棋盘。
```

### `Tests/AchievementPresentationTests.swift`

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -55,4 +55,69 @@
             }
         }
     }
+
+    func testBadgeStripShowsExactlyFiveWholeBadgesForBothScrollerStyles() throws {
+        _ = NSApplication.shared
+        let strip = AchievementBadgeStripView()
+        strip.refresh(manager: manager)
+        for style in [NSScroller.Style.legacy, .overlay] {
+            strip.scrollerStyle = style
+            for width: CGFloat in [500, 644, 900] {
+                strip.frame = NSRect(x: 0, y: 0, width: width, height: AchievementBadgeStripView.preferredHeight)
+                strip.needsLayout = true
+                strip.layoutSubtreeIfNeeded()
+                let document = try XCTUnwrap(strip.documentView)
+                document.layoutSubtreeIfNeeded()
+                let badges = document.subviews.compactMap { $0 as? AchievementBadgeButton }.sorted { $0.tag < $1.tag }
+                let visible = document.visibleRect
+                let complete = badges.filter { visible.contains($0.frame) }
+                let intersecting = badges.filter { !visible.intersection($0.frame).isEmpty }
+                XCTAssertEqual(complete.map(\.tag), [1, 2, 3, 4, 5])
+                XCTAssertEqual(intersecting.count, 5, "不应在右侧露出半枚标签")
+                XCTAssertGreaterThan(complete[0].frame.minY, visible.minY)
+                XCTAssertLessThan(complete[0].frame.maxY, visible.maxY)
+                XCTAssertGreaterThan(document.frame.width, visible.width)
+            }
+        }
+    }
+
+    func testBadgeContentIsCenteredAndStillClickableWithLongLocalizedNames() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let strip = AchievementBadgeStripView()
+        strip.frame = NSRect(x: 0, y: 0, width: 644, height: AchievementBadgeStripView.preferredHeight)
+        var selected: Int?
+        strip.onSelect = { selected = $0 }
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            strip.refresh(manager: manager)
+            strip.needsLayout = true
+            strip.layoutSubtreeIfNeeded()
+            let document = try XCTUnwrap(strip.documentView)
+            document.layoutSubtreeIfNeeded()
+            for badge in document.subviews.compactMap({ $0 as? AchievementBadgeButton }) {
+                badge.layoutSubtreeIfNeeded()
+                let group = try XCTUnwrap(badge.subviews.first as? NSStackView)
+                let image = try XCTUnwrap(group.arrangedSubviews.first as? NSImageView)
+                let label = try XCTUnwrap(group.arrangedSubviews.last as? NSTextField)
+                // AppKit 会对最终 frame 做像素对齐，独立视图允许一个像素的取整误差。
+                let pixel = 1 / (strip.window?.backingScaleFactor ?? 1)
+                XCTAssertEqual(group.frame.midX, badge.bounds.midX, accuracy: pixel)
+                XCTAssertEqual(group.frame.midY, badge.bounds.midY, accuracy: pixel)
+                XCTAssertEqual(image.frame.midY, label.frame.midY, accuracy: pixel)
+                XCTAssertGreaterThanOrEqual(group.frame.minX, 8 - pixel)
+                XCTAssertLessThanOrEqual(group.frame.maxX, badge.bounds.maxX - 8 + pixel)
+                XCTAssertTrue(badge.toolTip?.contains(label.stringValue) == true)
+                // hitTest 接收的是父视图坐标，分别点击图标和文字的中心。
+                for child in [image, label] {
+                    let point = child.convert(NSPoint(x: child.bounds.midX, y: child.bounds.midY), to: document)
+                    XCTAssertTrue(badge.hitTest(point) === badge)
+                }
+                badge.performClick(nil)
+                XCTAssertEqual(selected, badge.tag)
+            }
+        }
+    }
+
 }
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261027224658-achievement-badge-layout.md` - 会话-16 起修复成就标签遮挡、图文居中与标签过宽；默认完整显示 5 枚，含本轮增量 diff 及 4 项界面回归测试结果。
 `workflow/20261026092356-achievement-system.md` - 会话-5 起实现 20 枚事件驱动成就、版本化存档迁移、五语言徽章/非模态图鉴与提示队列；含完整逐行 diff 和 29 项测试结果。
 `workflow/20260615223620-readme-screenshot-preview-remove-note-and-table.md` - 移除中英文 README 截图预览区的说明提示，并把表格布局改为更自然的分段图片展示。
 `workflow/20260615222900-readme-screenshot-preview-remove-package-column.md` - 从中英文 README 的截图预览区移除“打包产物”栏位，并同步更新截图资源说明文档。
@@ -60,6 +61,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整成就徽章栏高度、默认五枚布局、图文居中、滚动条兼容或长名称展示时，读取 `20261027224658-achievement-badge-layout.md`。
 - 需要了解成就清单、真实交换/结算事件、旧成就迁移、进度存档、非模态图鉴或成就测试时，读取 `20261026092356-achievement-system.md`。
 - 需要确认“截图预览区是否已经去掉提示文案与表格，改为纵向分段展示”时，优先读取 `20260615223620` 文档。
 - 需要确认“截图预览区是否已经去掉打包产物，仅保留桌面主界面与 Touch Bar 棋盘”时，优先读取 `20260615222900` 文档。
@@ -120,6 +122,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就卡片高度由标题、内边距与 64 点高的标签区域决定，不再与顶部横幅等高；标签按实际可视宽度适配五枚，图标与文字整体居中，长名称截断后可通过悬浮提示或详情查看。
 - 成就统计由棋盘控制器提交真实事件，独立于 HUD 刷新和挑战排行；累计值与历史最佳跨局保存，节奏/连续交换在重开和模式切换时清零。
 - 旧版仅迁移成就编号 1—3 的解锁与时间；不使用排行榜或开发 seed 回推新成就。
 - 成就面板不获取主窗口焦点；自动化测试通过隔离 UserDefaults 与可控棋盘验证规则，命令为 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。
```
