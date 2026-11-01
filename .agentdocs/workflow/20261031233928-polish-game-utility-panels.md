# 游戏设置、玩法说明与挑战记录界面优化

## 背景与目标
- 对应会话-106：三个辅助页面原先为基础控件或纯文本，需要与浅色游戏首页、成就筛选条保持同一套材质和视觉层级。
- 保留语言、总音量、固定规则及真实挑战记录；不改动核心游戏、成就、存档协议与 Touch Bar 展示链路。

## 设计与边界
- 暖白底色、深蓝文字、白色圆角卡片、蓝色信息与黄色重点，统一边距和字体层级。
- 设置页：语言菜单和声音分组，自绘原生下拉控件与金色音量轨道；原生菜单、拖动、辅助功能及回调保留。
- 玩法页：交换、相连、连锁三个步骤配静态游戏示意，三个固定模式分卡展示，当前模式只做标记，不在说明页切换真实模式。
- 记录页：带数量的竞分/竞速滑轨、个人最佳、金银铜名次和对齐的成绩/日期列；真实空榜单显示破折号和提示，不生成成绩。
- 复用成就页 0.24 秒滑轨与减少动态效果支持，仅增加可配置图标；成就筛选的默认三枚图标不变。
- 辅助窗口继续不获取主窗口焦点；在加入父窗口前定位并限制屏幕可用区域。小窗口正文可滚动，初始从顶部展示。
- 快照高频刷新只更新必要数据，避免重建卡片引起滚动重置、榜单切换丢失或菜单被打断。
- 24 条新增文案完整覆盖中文、英文、日文、韩文、俄文。
- 使用 `ui-ux-pro-max` 的可读性、等比图标、对比度与减少动态效果规范。该技能的 scripts 条目为失效路径占位文件，检索脚本不可运行；本轮按已读取规范实现并以原生截图验证。
- 本轮未改变核心架构与数据流，不更新根目录核心认知。

## 阶段与 TODO
- [x] 抽出辅助页共用主题视图及排版组件。
- [x] 接入原生语言菜单、总音量滑杆与真实记录接口。
- [x] 补齐五种语言，处理紧凑窗口、初始滚动与空榜单。
- [x] 新增 5 项行为/布局测试并导出真实预览。
- [x] 完整 60 项测试通过，人工检查常规及俄文紧凑截图。
- [x] 更新索引与全部逐行增量 diff。

## 代码变更
- 以下以本轮开始时的工作区为基线，完整记录所有文本行变化；此前未提交的成就图标/页头改动保留。

### `Sources/HomeUtilityPanel.swift`

```diff
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -1,113 +1,137 @@
 import Cocoa
-
-private final class HomeUtilityBackgroundView: NSView {
-    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
-}
 
 private final class HomeAuxiliaryWindow: NSPanel {
     override var canBecomeKey: Bool { false }
     override var canBecomeMain: Bool { false }
 }
 
-/// 顶部导航的辅助面板，不覆盖主窗口的游戏状态与 Touch Bar 焦点。
+/// 控制事件与真实数据留在控制器，主题组件负责辅助页面布局。
 final class HomeUtilityPanel: NSWindowController {
     let page: String
     var onLanguage: ((AppLanguage) -> Void)?
     var onVolume: ((Float) -> Void)?
-    private let titleLabel = NSTextField(labelWithString: "")
-    private let body = NSTextView()
-    private let languageLabel = NSTextField(labelWithString: "")
-    private let language = NSPopUpButton(frame: .zero, pullsDown: false)
-    private let volumeLabel = NSTextField(labelWithString: "")
+    private let content: UtilityPageView
+    private let language = UtilityLanguagePopup(frame: .zero, pullsDown: false)
     private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
-    private let percent = NSTextField(labelWithString: "")
+    private let percent = UtilityStyle.label("", size: 18, weight: .bold)
+    private let recordTabs = AchievementFilterControl(frame: .zero)
+    private let recordBody = UtilityStyle.stack([])
     private let store: ModeRecordStore
+    // 快照高频刷新时不重建卡片，保留滚动位置和控件操作状态。
+    private var renderedLanguage: AppLanguage?
+    private var renderedMode: HomeGameMode?
+    private var renderedRecordIDs: [String] = []
 
     init(page: String, store: ModeRecordStore = .shared) {
-        self.page = page; self.store = store
-        let panel = HomeAuxiliaryWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: page == "settings" ? 270 : 480),
+        self.page = page; self.store = store; content = UtilityPageView(page: page)
+        let size = NSSize(width: page == "settings" ? 540 : 600, height: page == "settings" ? 430 : 740)
+        let panel = HomeAuxiliaryWindow(contentRect: NSRect(origin: .zero, size: size),
                                         styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
-        panel.isReleasedWhenClosed = false
-        panel.appearance = NSAppearance(named: .aqua)
-        panel.backgroundColor = HomeStyle.background
-        panel.hidesOnDeactivate = true
-        panel.contentView = HomeUtilityBackgroundView(frame: NSRect(origin: .zero, size: panel.contentLayoutRect.size))
+        panel.isReleasedWhenClosed = false; panel.appearance = NSAppearance(named: .aqua)
+        panel.backgroundColor = HomeStyle.background; panel.hidesOnDeactivate = true
+        content.frame = NSRect(origin: .zero, size: size); content.autoresizingMask = [.width, .height]
+        panel.contentView = content
         super.init(window: panel)
-        guard let content = panel.contentView else { return }
-        titleLabel.frame = NSRect(x: 24, y: content.bounds.height - 65, width: 452, height: 38)
-        titleLabel.font = .systemFont(ofSize: 25, weight: .bold); titleLabel.textColor = HomeStyle.ink
-        content.addSubview(titleLabel)
-        if page == "settings" {
-            for label in [languageLabel, volumeLabel, percent] { label.font = .systemFont(ofSize: 15); label.textColor = HomeStyle.ink; content.addSubview(label) }
-            languageLabel.frame = NSRect(x: 26, y: 141, width: 90, height: 26)
-            language.frame = NSRect(x: 135, y: 136, width: 325, height: 34)
-            language.font = .systemFont(ofSize: 15); language.target = self; language.action = #selector(languageChanged)
-            volumeLabel.frame = NSRect(x: 26, y: 75, width: 90, height: 26)
-            volume.frame = NSRect(x: 135, y: 74, width: 245, height: 28)
-            percent.frame = NSRect(x: 398, y: 74, width: 68, height: 28)
-            volume.target = self; volume.action = #selector(volumeChanged)
-            content.addSubview(language); content.addSubview(volume)
-        } else {
-            let scroll = NSScrollView(frame: NSRect(x: 22, y: 24, width: 456, height: content.bounds.height - 105))
-            scroll.hasVerticalScroller = true; scroll.drawsBackground = false
-            body.isEditable = false; body.isSelectable = true; body.drawsBackground = false
-            body.font = .systemFont(ofSize: 15); body.textColor = HomeStyle.ink
-            body.isVerticallyResizable = true; body.isHorizontallyResizable = false
-            body.autoresizingMask = [.width]; body.textContainer?.widthTracksTextView = true
-            body.frame = scroll.bounds; scroll.documentView = body
-            content.addSubview(scroll)
-        }
+        language.font = .systemFont(ofSize: 14, weight: .semibold); language.isBordered = false
+        language.focusRingType = .exterior; language.target = self; language.action = #selector(languageChanged)
+        volume.cell = UtilityVolumeSliderCell(); volume.minValue = 0; volume.maxValue = 1
+        volume.isContinuous = true; volume.target = self; volume.action = #selector(volumeChanged)
+        percent.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold); percent.alignment = .right
+        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = ["trophy", "stopwatch"]
+        recordTabs.selectedSegment = 0; recordTabs.target = self; recordTabs.action = #selector(recordModeChanged)
+        // 固定尺寸只注册一次，语言切换时仅重建排版与文案。
+        NSLayoutConstraint.activate([
+            language.heightAnchor.constraint(equalToConstant: 44), volume.heightAnchor.constraint(equalToConstant: 34),
+            percent.widthAnchor.constraint(equalToConstant: 56), recordTabs.heightAnchor.constraint(equalToConstant: 44)
+        ])
     }
     required init?(coder: NSCoder) { nil }
 
     func refresh(mode: HomeGameMode, volume value: Float) {
-        let key = "panel.\(page)"
-        titleLabel.stringValue = AchievementText.string(key); window?.title = titleLabel.stringValue
+        let languageChanged = renderedLanguage != Localizer.shared.language
+        content.refreshHeader(page: page); window?.title = UtilityStyle.text("panel.\(page)")
         if page == "settings" {
-            languageLabel.stringValue = AchievementText.string("language.label")
-            volumeLabel.stringValue = AchievementText.string("volume.label")
-            language.removeAllItems()
-            language.addItems(withTitles: AppLanguage.allCases.map { AchievementText.string($0.titleKey) })
+            if languageChanged { buildSettings() }
+            if languageChanged {
+                language.removeAllItems()
+                language.addItems(withTitles: AppLanguage.allCases.map { UtilityStyle.text($0.titleKey) })
+            }
             language.selectItem(at: AppLanguage.allCases.firstIndex(of: Localizer.shared.language) ?? 0)
-            volume.doubleValue = Double(value); percent.stringValue = "\(Int(value * 100))%"
+            volume.doubleValue = Double(value); updateVolumeLabel()
         } else if page == "rules" {
-            body.string = "• " + AchievementText.string("rules.core.line1") + "\n\n• " + AchievementText.string("rules.core.line2")
-                + "\n\n• " + AchievementText.string("home.mode_desc.\(mode.key)") + "\n\n• " + AchievementText.string("home.rules.fixed")
+            if languageChanged || renderedMode != mode { UtilityRulesContent.populate(content, mode: mode) }
         } else {
-            var lines = [AchievementText.string("home.records.fixed"), ""]
-            let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
-            for (recordMode, detail, titleKey) in [(ModeRecordKey.scoreAttack, 1, "home.mode.score_attack"), (.speedRun, 300, "home.mode.speed_run")] {
-                lines.append(AchievementText.string(titleKey))
-                let entries = store.records(for: recordMode, detailValue: detail)
-                if entries.isEmpty { lines.append(AchievementText.string("records.empty")) }
-                for (index, entry) in entries.enumerated() {
-                    let metric = recordMode == .scoreAttack ? AchievementText.format("records.metric.score", entry.score) : String(format: "%.2f s", entry.elapsedTime)
-                    lines.append("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)))")
-                }
-                lines.append("")
+            let ids = recordEntries(.scoreAttack).map(\.id) + recordEntries(.speedRun).map(\.id)
+            if languageChanged {
+                content.removeSections(); content.addSection(recordTabs)
+                content.addSection(recordBody)
+                recordTabs.setLabel(UtilityStyle.text("home.mode.score_attack"), forSegment: 0)
+                recordTabs.setLabel(UtilityStyle.text("home.mode.speed_run"), forSegment: 1)
             }
-            body.string = lines.joined(separator: "\n")
+            recordTabs.updateCounts([recordEntries(.scoreAttack).count, recordEntries(.speedRun).count]); recordTabs.refreshMetrics()
+            if languageChanged || ids != renderedRecordIDs { refreshRecords() }
+            renderedRecordIDs = ids
         }
-        // 文本视图只在竖直方向扩展，让较多历史记录可正常滚动。
-        if page != "settings" { body.sizeToFit() }
+        renderedLanguage = Localizer.shared.language; renderedMode = mode
+        content.layoutSubtreeIfNeeded()
+    }
+
+    private func buildSettings() {
+        content.removeSections()
+        let languageStack = UtilityStyle.stack([settingHeading("globe", title: "language.label", detail: "utility.settings.language_hint"), language], spacing: 16)
+        UtilityStyle.fillWidth(language, in: languageStack)
+        content.addSection(UtilityCard(languageStack))
+        let sliderRow = UtilityStyle.stack([UtilityStyle.icon("speaker.fill", color: HomeStyle.secondary, size: 16), volume, percent], vertical: false, spacing: 14)
+        volume.setContentHuggingPriority(.defaultLow, for: .horizontal)
+        let volumeStack = UtilityStyle.stack([settingHeading("speaker.wave.2.fill", title: "volume.label", detail: "utility.settings.volume_hint"), sliderRow], spacing: 14)
+        UtilityStyle.fillWidth(sliderRow, in: volumeStack)
+        content.addSection(UtilityCard(volumeStack))
+        let footnote = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.green, size: 16),
+                                          UtilityStyle.label(UtilityStyle.text("utility.settings.instant"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 7)
+        content.addSection(footnote)
+        language.setAccessibilityLabel(UtilityStyle.text("language.label")); volume.setAccessibilityLabel(UtilityStyle.text("volume.label"))
+    }
+
+    private func settingHeading(_ symbol: String, title: String, detail: String) -> NSView {
+        let copy = UtilityStyle.stack([UtilityStyle.label(UtilityStyle.text(title), size: 15, weight: .bold),
+                                       UtilityStyle.label(UtilityStyle.text(detail), size: 12, color: HomeStyle.secondary)], spacing: 4)
+        return UtilityStyle.stack([UtilityStyle.icon(symbol, color: HomeStyle.blue, size: 26), copy], vertical: false, spacing: 13)
+    }
+    private func recordEntries(_ mode: ModeRecordKey) -> [ModeRecord] { store.records(for: mode, detailValue: mode == .scoreAttack ? 1 : 300) }
+
+    private func refreshRecords() {
+        for view in recordBody.arrangedSubviews { recordBody.removeArrangedSubview(view); view.removeFromSuperview() }
+        let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .scoreAttack : .speedRun
+        let entries = recordEntries(mode)
+        for view in [UtilityRecordBestView(mode: mode, entry: entries.first), UtilityRecordContent.table(mode: mode, entries: entries)] {
+            recordBody.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: recordBody)
+        }
     }
 
     func present(from parent: NSWindow?) {
         guard let window else { return }
         if let parent {
             let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
-            let x = min(max(parent.frame.midX - window.frame.width / 2, available.minX + 8), available.maxX - window.frame.width - 8)
-            let y = min(max(parent.frame.midY - window.frame.height / 2, available.minY + 8), available.maxY - window.frame.height - 8)
-            window.setFrameOrigin(NSPoint(x: x, y: y))
+            // 小屏幕先收敛尺寸，再按主窗口居中，正文滚动区承载剩余内容。
+            var frame = window.frame
+            frame.size.width = min(frame.width, available.width - 16); frame.size.height = min(frame.height, available.height - 16)
+            frame.origin.x = min(max(parent.frame.midX - frame.width / 2, available.minX + 8), available.maxX - frame.width - 8)
+            frame.origin.y = min(max(parent.frame.midY - frame.height / 2, available.minY + 8), available.maxY - frame.height - 8)
+            window.setFrame(frame, display: false)
             if window.parent !== parent { window.parent?.removeChildWindow(window); parent.addChildWindow(window, ordered: .above) }
         } else { window.center() }
-        window.orderFront(nil)
+        content.layoutSubtreeIfNeeded(); window.orderFront(nil)
     }
+
     @objc private func languageChanged() {
-        onLanguage?(AppLanguage.allCases[max(0, language.indexOfSelectedItem)])
+        guard AppLanguage.allCases.indices.contains(language.indexOfSelectedItem) else { return }
+        onLanguage?(AppLanguage.allCases[language.indexOfSelectedItem])
     }
-    @objc private func volumeChanged() {
-        percent.stringValue = "\(Int(volume.doubleValue * 100))%"
-        onVolume?(Float(volume.doubleValue))
+    private func updateVolumeLabel() {
+        percent.stringValue = "\(Int((volume.doubleValue * 100).rounded()))%"; volume.setAccessibilityValue(percent.stringValue)
+    }
+    @objc private func volumeChanged() { updateVolumeLabel(); onVolume?(Float(volume.doubleValue)) }
+    @objc private func recordModeChanged() {
+        refreshRecords(); content.layoutSubtreeIfNeeded(); content.scroll.documentView?.scroll(.zero)
     }
 }
```

### `Sources/HomeUtilityViews.swift`

```diff
--- /dev/null
+++ b/Sources/HomeUtilityViews.swift
@@ -0,0 +1,331 @@
+import Cocoa
+
+/// 辅助页共用首页材质；文字使用原生视图，支持换行和辅助功能。
+enum UtilityStyle {
+    static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
+                      color: NSColor = HomeStyle.ink) -> NSTextField {
+        let label = NSTextField(wrappingLabelWithString: text)
+        label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
+        label.maximumNumberOfLines = 0
+        label.setContentCompressionResistancePriority(.required, for: .vertical)
+        return label
+    }
+    static func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 10) -> NSStackView {
+        let stack = NSStackView(views: views)
+        stack.orientation = vertical ? .vertical : .horizontal
+        stack.alignment = vertical ? .leading : .centerY
+        if !vertical { stack.distribution = .fill }
+        stack.spacing = spacing
+        if vertical {
+            for label in views.compactMap({ $0 as? NSTextField }) { fillWidth(label, in: stack) }
+        }
+        return stack
+    }
+    static func fillWidth(_ view: NSView, in parent: NSView) {
+        view.translatesAutoresizingMaskIntoConstraints = false
+        view.widthAnchor.constraint(equalTo: parent.widthAnchor).isActive = true
+    }
+    static func text(_ key: String) -> String { AchievementText.string(key) }
+    static func icon(_ symbol: String, color: NSColor, size: CGFloat = 24) -> NSView {
+        let view = UtilityArtworkView(symbol: symbol, color: color)
+        view.translatesAutoresizingMaskIntoConstraints = false
+        NSLayoutConstraint.activate([view.widthAnchor.constraint(equalToConstant: size), view.heightAnchor.constraint(equalToConstant: size)])
+        return view
+    }
+}
+
+/// 彩色矢量始终等比绘制，不依赖字体附件的基线。
+final class UtilityArtworkView: NSView {
+    let symbol: String
+    let color: NSColor
+    init(symbol: String, color: NSColor) {
+        self.symbol = symbol; self.color = color
+        super.init(frame: .zero); setAccessibilityElement(false)
+    }
+    required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) { HomeStyle.symbol(symbol, in: bounds.insetBy(dx: 2, dy: 2), color: color) }
+}
+
+final class UtilityCard: NSView {
+    init(_ content: NSView, tint: NSColor = .white, padding: CGFloat = 20) {
+        super.init(frame: .zero)
+        wantsLayer = true
+        layer?.backgroundColor = tint.cgColor
+        layer?.borderColor = HomeStyle.border.withAlphaComponent(0.8).cgColor
+        layer?.borderWidth = 0.75; layer?.cornerRadius = 14
+        content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
+        NSLayoutConstraint.activate([
+            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
+            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
+            content.topAnchor.constraint(equalTo: topAnchor, constant: padding),
+            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
+        ])
+    }
+    required init?(coder: NSCoder) { nil }
+}
+
+/// 标题固定、正文独立滚动，在小屏幕与长翻译下不裁切内容。
+private final class UtilityDocumentView: NSView {
+    override var isFlipped: Bool { true }
+}
+
+final class UtilityPageView: NSView {
+    let scroll = NSScrollView()
+    let document: NSView = UtilityDocumentView()
+    let sections = UtilityStyle.stack([])
+    private let title = UtilityStyle.label("", size: 23, weight: .bold)
+    private let subtitle = UtilityStyle.label("", size: 12, color: HomeStyle.secondary)
+
+    init(page: String) {
+        super.init(frame: .zero)
+        let symbol = page == "settings" ? "slider.horizontal.3" : page == "rules" ? "gamecontroller.fill" : "trophy"
+        let artwork = UtilityStyle.icon(symbol, color: page == "records" ? .systemOrange : HomeStyle.blue, size: 32)
+        let headings = UtilityStyle.stack([title, subtitle], spacing: 5)
+        let header = UtilityStyle.stack([artwork, headings], vertical: false, spacing: 14)
+        header.translatesAutoresizingMaskIntoConstraints = false
+        scroll.translatesAutoresizingMaskIntoConstraints = false
+        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
+        scroll.borderType = .noBorder
+        addSubview(header); addSubview(scroll)
+        document.translatesAutoresizingMaskIntoConstraints = false
+        sections.translatesAutoresizingMaskIntoConstraints = false; sections.spacing = 14
+        document.addSubview(sections); scroll.documentView = document
+        NSLayoutConstraint.activate([
+            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
+            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
+            header.topAnchor.constraint(equalTo: topAnchor, constant: 26),
+            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
+            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
+            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
+            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
+            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
+            sections.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
+            sections.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
+            sections.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
+            sections.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -4)
+        ])
+        headings.setContentHuggingPriority(.defaultLow, for: .horizontal)
+    }
+    required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
+    func refreshHeader(page: String) {
+        title.stringValue = UtilityStyle.text("panel.\(page)")
+        subtitle.stringValue = UtilityStyle.text("utility.\(page).subtitle")
+    }
+    func addSection(_ view: NSView) {
+        sections.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: sections)
+    }
+    func removeSections() {
+        for view in sections.arrangedSubviews { sections.removeArrangedSubview(view); view.removeFromSuperview() }
+    }
+}
+
+/// 保留原生菜单和辅助功能，只重绘游戏主题外观。
+final class UtilityLanguagePopup: NSPopUpButton {
+    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 44) }
+    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.card(bounds, fill: HomeStyle.blue.withAlphaComponent(isHighlighted ? 0.09 : 0.035), border: HomeStyle.blue.withAlphaComponent(0.25), radius: 9)
+        HomeStyle.text(title, in: NSRect(x: 15, y: bounds.midY - 10, width: bounds.width - 52, height: 22), size: 14, weight: .semibold)
+        HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeStyle.blue)
+    }
+    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
+}
+
+/// 原生滑杆负责拖动与键盘步进，自绘金色进度和白色旋钮。
+final class UtilityVolumeSliderCell: NSSliderCell {
+    override var knobThickness: CGFloat { 22 }
+    override func drawBar(inside rect: NSRect, flipped: Bool) {
+        // 原生旋钮的光学中心与 barRect 有细微偏移，轨道以旋钮中心为准。
+        let track = NSRect(x: rect.minX, y: knobRect(flipped: flipped).midY - 3, width: rect.width, height: 6)
+        NSColor(calibratedWhite: 0.92, alpha: 1).setFill(); NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
+        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
+        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
+        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
+    }
+    override func drawKnob(_ knobRect: NSRect) {
+        let knob = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
+        NSGraphicsContext.saveGraphicsState()
+        let shadow = NSShadow(); shadow.shadowColor = HomeStyle.ink.withAlphaComponent(0.16)
+        shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
+        NSColor.white.setFill(); NSBezierPath(ovalIn: knob).fill()
+        NSGraphicsContext.restoreGraphicsState()
+        HomeStyle.border.setStroke(); NSBezierPath(ovalIn: knob.insetBy(dx: 0.5, dy: 0.5)).stroke()
+        HomeStyle.yellow.setFill(); NSBezierPath(ovalIn: knob.insetBy(dx: 7, dy: 7)).fill()
+    }
+}
+
+/// 静态游戏示意不增加定时器，不参与真实棋盘状态。
+final class UtilityLessonArtwork: NSView {
+    let step: Int
+    init(step: Int) {
+        self.step = step; super.init(frame: .zero)
+        translatesAutoresizingMaskIntoConstraints = false
+        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 100), heightAnchor.constraint(equalToConstant: 52)])
+        setAccessibilityElement(false)
+    }
+    required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) {
+        if step == 0 {
+            HomeStyle.piece(.orangeRicky, in: NSRect(x: 0, y: 14, width: 33, height: 24))
+            HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeStyle.secondary)
+            HomeStyle.piece(.blueRicky, in: NSRect(x: 65, y: 14, width: 33, height: 24))
+        } else {
+            let rows = step == 1 ? 1 : 2
+            for row in 0..<rows {
+                for column in 0..<3 {
+                    let tile = NSRect(x: 19 + CGFloat(column) * 21, y: CGFloat(rows == 1 ? 17 : 7) + CGFloat(row) * 21, width: 18, height: 18)
+                    let color = row == 0 ? HomeStyle.blue : HomeStyle.green
+                    NSGradient(colors: [color.blended(withFraction: 0.25, of: .white)!, color])?.draw(in: NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4), angle: -90)
+                    NSColor.white.withAlphaComponent(0.4).setStroke()
+                    NSBezierPath(roundedRect: tile.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).stroke()
+                }
+            }
+        }
+    }
+}
+
+enum UtilityRulesContent {
+    static func populate(_ page: UtilityPageView, mode: HomeGameMode) {
+        page.removeSections()
+        let lessons = UtilityStyle.stack([], spacing: 0)
+        for step in 0..<3 {
+            let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeStyle.blue)
+            number.widthAnchor.constraint(equalToConstant: 25).isActive = true
+            let copy = UtilityStyle.stack([
+                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold),
+                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeStyle.secondary)
+            ], spacing: 5)
+            let row = UtilityStyle.stack([number, copy, UtilityLessonArtwork(step: step)], vertical: false, spacing: 12)
+            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
+            lessons.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: lessons)
+            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
+            if step < 2 {
+                let divider = NSBox(); divider.boxType = .separator
+                lessons.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: lessons)
+            }
+        }
+        page.addSection(UtilityCard(lessons, padding: 18))
+        page.addSection(UtilityStyle.label(UtilityStyle.text("utility.rules.modes"), size: 14, weight: .bold))
+        let modes = UtilityStyle.stack([], spacing: 10)
+        for candidate in HomeGameMode.allCases {
+            let selected = candidate == mode
+            let copy = UtilityStyle.stack([
+                UtilityStyle.label(UtilityStyle.text("home.mode.\(candidate.key)"), size: 13, weight: .bold),
+                UtilityStyle.label(UtilityStyle.text("home.mode_desc.\(candidate.key)"), size: 12, color: HomeStyle.secondary)
+            ], spacing: 3)
+            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
+            let row = UtilityStyle.stack([UtilityStyle.icon(candidate.symbol, color: selected ? HomeStyle.blue : HomeStyle.secondary, size: 26), copy], vertical: false, spacing: 13)
+            if selected {
+                let current = UtilityStyle.label(UtilityStyle.text("utility.rules.current"), size: 10, weight: .semibold, color: HomeStyle.blue)
+                current.setContentHuggingPriority(.required, for: .horizontal)
+                current.setContentCompressionResistancePriority(.required, for: .horizontal)
+                row.addArrangedSubview(current)
+            }
+            let card = UtilityCard(row, tint: selected ? NSColor(calibratedRed: 0.94, green: 0.975, blue: 1, alpha: 1) : .white, padding: 12)
+            modes.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: modes)
+        }
+        page.addSection(modes)
+        let note = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.secondary, size: 19),
+                                     UtilityStyle.label(UtilityStyle.text("utility.rules.progress"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 10)
+        page.addSection(UtilityCard(note, tint: HomeStyle.yellow.withAlphaComponent(0.08), padding: 14))
+    }
+}
+
+/// 数字为视觉中心，并明确当前榜单的固定规则。
+final class UtilityRecordBestView: NSView {
+    init(mode: ModeRecordKey, entry: ModeRecord?) {
+        super.init(frame: .zero)
+        wantsLayer = true; layer?.cornerRadius = 14
+        layer?.backgroundColor = HomeStyle.yellow.withAlphaComponent(0.12).cgColor
+        layer?.borderColor = HomeStyle.yellow.withAlphaComponent(0.4).cgColor; layer?.borderWidth = 0.75
+        let metric = entry.map { mode == .scoreAttack ? String($0.score) : String(format: "%.2f", $0.elapsedTime) } ?? "—"
+        let value = UtilityStyle.label(metric, size: 38, weight: .heavy)
+        value.font = .monospacedDigitSystemFont(ofSize: 38, weight: .heavy)
+        let unit = UtilityStyle.label(UtilityStyle.text(mode == .scoreAttack ? "utility.unit.points" : "utility.unit.seconds"), size: 13, weight: .semibold, color: HomeStyle.secondary)
+        let copy = UtilityStyle.stack([
+            UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeStyle.secondary),
+            UtilityStyle.stack([value, unit], vertical: false, spacing: 8),
+            UtilityStyle.label(UtilityStyle.text(mode == .scoreAttack ? "utility.records.score_rule" : "utility.records.speed_rule"), size: 11, color: HomeStyle.secondary)
+        ], spacing: 4)
+        let icon = UtilityStyle.icon(mode == .scoreAttack ? "trophy" : "stopwatch", color: .systemOrange, size: 56)
+        let row = UtilityStyle.stack([copy, icon], vertical: false, spacing: 16)
+        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
+        row.translatesAutoresizingMaskIntoConstraints = false; addSubview(row)
+        NSLayoutConstraint.activate([
+            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
+            row.topAnchor.constraint(equalTo: topAnchor, constant: 18), row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
+        ])
+    }
+    required init?(coder: NSCoder) { nil }
+}
+
+enum UtilityRecordContent {
+    /// 独立列宽确保日期不会因分数位数改变而错位。
+    static func table(mode: ModeRecordKey, entries: [ModeRecord]) -> NSView {
+        let rows = UtilityStyle.stack([], spacing: 0)
+        let headings = UtilityStyle.stack([
+            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeStyle.secondary),
+            UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeStyle.secondary),
+            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold, color: HomeStyle.secondary)
+        ], vertical: false, spacing: 12)
+        headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
+        headings.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 135).isActive = true
+        (headings.arrangedSubviews[2] as? NSTextField)?.alignment = .right
+        headings.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
+        rows.addArrangedSubview(headings); UtilityStyle.fillWidth(headings, in: rows)
+        headings.heightAnchor.constraint(equalToConstant: 30).isActive = true
+        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
+        for (index, entry) in entries.enumerated() {
+            let divider = NSBox(); divider.boxType = .separator
+            rows.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: rows)
+            let rank = UtilityRankView(rank: index + 1)
+            rank.translatesAutoresizingMaskIntoConstraints = false
+            NSLayoutConstraint.activate([rank.widthAnchor.constraint(equalToConstant: 36), rank.heightAnchor.constraint(equalToConstant: 30)])
+            let metric = mode == .scoreAttack ? AchievementText.format("records.metric.score", entry.score)
+                : String(format: "%.2f", entry.elapsedTime) + " " + UtilityStyle.text("utility.unit.seconds")
+            let score = UtilityStyle.label(metric, size: 15, weight: index == 0 ? .bold : .semibold)
+            score.font = .monospacedDigitSystemFont(ofSize: 15, weight: index == 0 ? .bold : .semibold)
+            score.setContentHuggingPriority(.defaultLow, for: .horizontal)
+            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11, color: HomeStyle.secondary)
+            date.alignment = .right
+            date.widthAnchor.constraint(equalToConstant: 135).isActive = true
+            let row = UtilityStyle.stack([rank, score, date], vertical: false, spacing: 12)
+            rows.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: rows)
+            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
+            row.setAccessibilityLabel("\(index + 1). \(metric), \(date.stringValue)")
+        }
+        if entries.isEmpty {
+            let empty = UtilityStyle.stack([
+                UtilityStyle.icon("flag.checkered", color: HomeStyle.secondary, size: 40),
+                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold),
+                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeStyle.secondary)
+            ], spacing: 12)
+            empty.alignment = .centerX
+            for label in empty.arrangedSubviews.compactMap({ $0 as? NSTextField }) { label.alignment = .center }
+            rows.addArrangedSubview(empty); UtilityStyle.fillWidth(empty, in: rows)
+            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
+        }
+        return UtilityCard(rows, padding: 16)
+    }
+}
+
+/// 前三名用金银铜奖牌，其他名次使用等宽数字。
+private final class UtilityRankView: NSView {
+    let rank: Int
+    init(rank: Int) { self.rank = rank; super.init(frame: .zero); setAccessibilityElement(false) }
+    required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) {
+        if rank <= 3 {
+            let colors = [HomeStyle.yellow, NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1), NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.45, alpha: 1)]
+            let circle = NSRect(x: bounds.midX - 11, y: bounds.midY - 11, width: 22, height: 22)
+            NSGradient(colors: [colors[rank - 1].blended(withFraction: 0.32, of: .white)!, colors[rank - 1]])?.draw(in: NSBezierPath(ovalIn: circle), angle: -90)
+        }
+        HomeStyle.text(String(rank), in: NSRect(x: 0, y: bounds.midY - 8, width: bounds.width, height: 18), size: 12, weight: .bold,
+                       color: rank <= 3 ? HomeStyle.ink : HomeStyle.secondary, alignment: .center)
+    }
+}
```

### `Tests/HomeUtilityPanelTests.swift`

```diff
--- /dev/null
+++ b/Tests/HomeUtilityPanelTests.swift
@@ -0,0 +1,187 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+/// 全部面板使用独立记录域；预览仅由测试导出，不在正式应用增加入口。
+final class HomeUtilityPanelTests: AchievementTestCase {
+    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
+    private func labels(_ view: NSView) -> [String] { descendants(view).compactMap { ($0 as? NSTextField)?.stringValue } }
+
+    private func recordStore(empty: Bool = false) throws -> ModeRecordStore {
+        var buckets: [String: [ModeRecord]] = [:]
+        if !empty {
+            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 1)] = (0..<9).map {
+                ModeRecord(id: "utility-score-\($0)", score: 920 - $0 * 70, elapsedTime: 60,
+                           durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600 - Double($0) * 86400)
+            }
+            buckets[ModeRecordStore.scopeID(mode: .speedRun, detailValue: 300)] = (0..<9).map {
+                ModeRecord(id: "utility-speed-\($0)", score: 300, elapsedTime: 18.42 + Double($0) * 3.2,
+                           durationMinutes: nil, targetScore: 300, createdAt: 1_793_361_600 - Double($0) * 86400)
+            }
+            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 2)] = [
+                ModeRecord(id: "old-rule", score: 999_999, elapsedTime: 120, durationMinutes: 2, targetScore: nil, createdAt: 0)
+            ]
+        }
+        defaults.set(try JSONEncoder().encode(buckets), forKey: "mode_records_v1")
+        let previous = ProcessInfo.processInfo.environment["ELIMINATE_DEVELOPMENT_MODE"]
+        setenv("ELIMINATE_DEVELOPMENT_MODE", "0", 1)
+        defer {
+            if let previous { setenv("ELIMINATE_DEVELOPMENT_MODE", previous, 1) }
+            else { unsetenv("ELIMINATE_DEVELOPMENT_MODE") }
+        }
+        return ModeRecordStore(defaults: defaults)
+    }
+
+    func testSettingsLanguageAndVolumeCallbacksRemainNative() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let panel = HomeUtilityPanel(page: "settings", store: try recordStore())
+        defer { panel.close() }
+        panel.refresh(mode: .free, volume: 0.26)
+        let content = try XCTUnwrap(panel.window?.contentView)
+        let menu = try XCTUnwrap(descendants(content).compactMap { $0 as? NSPopUpButton }.first)
+        let slider = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSlider }.first)
+        var chosen: AppLanguage?
+        panel.onLanguage = { chosen = $0; Localizer.shared.setLanguage($0) }
+        var changed: Float = -1
+        panel.onVolume = { changed = $0 }
+        for (index, language) in AppLanguage.allCases.enumerated() {
+            menu.selectItem(at: index); menu.sendAction(menu.action, to: menu.target)
+            XCTAssertEqual(chosen, language)
+            panel.refresh(mode: .free, volume: 0.26)
+            XCTAssertEqual(menu.indexOfSelectedItem, index)
+            XCTAssertEqual(menu.numberOfItems, 5)
+        }
+        for value in [0.0, 0.26, 1.0] {
+            slider.doubleValue = value; slider.sendAction(slider.action, to: slider.target)
+            XCTAssertEqual(changed, Float(value), accuracy: 0.001)
+            XCTAssertTrue(labels(content).contains("\(Int(value * 100))%"))
+        }
+        XCTAssertEqual(descendants(content).compactMap { $0 as? NSPopUpButton }.count, 1)
+        XCTAssertFalse(try XCTUnwrap(panel.window).canBecomeKey)
+    }
+
+    func testRecordTabsUseRealRankedBucketsAndKeepSelectionOnRefresh() throws {
+        _ = NSApplication.shared
+        let store = try recordStore()
+        let panel = HomeUtilityPanel(page: "records", store: store)
+        defer { panel.close() }
+        panel.refresh(mode: .free, volume: 0.4)
+        let content = try XCTUnwrap(panel.window?.contentView)
+        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
+        XCTAssertTrue(labels(content).contains("920"))
+        XCTAssertFalse(labels(content).contains { $0.contains("999999") || $0.contains("999,999") })
+        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
+        XCTAssertTrue(labels(content).contains("18.42"))
+        XCTAssertFalse(labels(content).contains("920"))
+        _ = store.addScoreAttackRecord(score: 990, elapsedTime: 60, durationMinutes: 1)
+        panel.refresh(mode: .scoreAttack, volume: 0.7)
+        XCTAssertEqual(tabs.selectedSegment, 1)
+        XCTAssertTrue(labels(content).contains("18.42"))
+        tabs.selectedSegment = 0; tabs.sendAction(tabs.action, to: tabs.target)
+        XCTAssertTrue(labels(content).contains("990"))
+        XCTAssertTrue(labels(content).contains(AchievementText.format("records.metric.score", 990)))
+        XCTAssertEqual(store.records(for: .scoreAttack, detailValue: 1).count, 9)
+    }
+
+    func testEmptyRecordsAndAllRuleModesRemainAccurate() throws {
+        _ = NSApplication.shared
+        let store = try recordStore(empty: true)
+        let panel = HomeUtilityPanel(page: "records", store: store)
+        let rules = HomeUtilityPanel(page: "rules", store: store)
+        defer { panel.close(); rules.close() }
+        panel.refresh(mode: .free, volume: 0.4)
+        let content = try XCTUnwrap(panel.window?.contentView)
+        XCTAssertTrue(labels(content).contains(AchievementText.string("records.empty")))
+        XCTAssertTrue(labels(content).contains("—"))
+        for mode in HomeGameMode.allCases {
+            rules.refresh(mode: mode, volume: 0.4)
+            let text = labels(try XCTUnwrap(rules.window?.contentView))
+            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.score_attack")))
+            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.speed_run")))
+            XCTAssertEqual(text.filter { $0 == AchievementText.string("utility.rules.current") }.count, 1)
+        }
+        XCTAssertTrue(store.records(for: .scoreAttack, detailValue: 1).isEmpty)
+        XCTAssertTrue(store.records(for: .speedRun, detailValue: 300).isEmpty)
+    }
+
+    func testFiveLanguagesCompactWindowsAndExportRealPanels() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let store = try recordStore()
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            for page in ["settings", "rules", "records"] {
+                let panel = HomeUtilityPanel(page: page, store: store)
+                defer { panel.close() }
+                panel.refresh(mode: .free, volume: 0.26)
+                let window = try XCTUnwrap(panel.window)
+                let content = try XCTUnwrap(window.contentView as? UtilityPageView)
+                let originalSize = content.bounds.size
+                for size in [originalSize, NSSize(width: 480, height: 420)] {
+                    window.setContentSize(size); content.layoutSubtreeIfNeeded()
+                    XCTAssertFalse(labels(content).contains { $0.hasPrefix("utility.") })
+                    XCTAssertGreaterThan(content.document.bounds.height, 100)
+                    XCTAssertLessThanOrEqual(content.document.frame.width, content.scroll.contentView.bounds.width + 1)
+                    XCTAssertEqual(content.scroll.contentView.bounds.minY, 0, accuracy: 1, "初次打开应从顶部显示")
+                    for card in descendants(content).compactMap({ $0 as? UtilityCard }) {
+                        XCTAssertGreaterThan(card.frame.height, 20)
+                        XCTAssertGreaterThan(card.frame.width, 200)
+                        for label in descendants(card).compactMap({ $0 as? NSTextField }) {
+                            let rect = card.convert(label.bounds, from: label)
+                            XCTAssertGreaterThanOrEqual(rect.minX, -1, "\(language): \(label.stringValue)")
+                            XCTAssertLessThanOrEqual(rect.maxX, card.bounds.maxX + 1, "\(language): \(label.stringValue)")
+                        }
+                    }
+                    if language == .russian, size.width == 480 { try export(content, name: "utility-\(page)-compact-ru") }
+                }
+                if language == .chineseSimplified {
+                    window.setContentSize(originalSize); content.layoutSubtreeIfNeeded()
+                    content.document.scroll(.zero)
+                    try export(content, name: "utility-\(page)")
+                    if page == "records" {
+                        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
+                        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
+                        try export(content, name: "utility-records-speed")
+                    }
+                }
+            }
+        }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let empty = HomeUtilityPanel(page: "records", store: try recordStore(empty: true))
+        defer { empty.close() }
+        empty.refresh(mode: .free, volume: 0)
+        try export(try XCTUnwrap(empty.window?.contentView), name: "utility-records-empty")
+    }
+
+    func testPanelsStayNearParentAndSnapshotRefreshPreservesScroll() throws {
+        _ = NSApplication.shared
+        let parent = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 620), styleMask: [.titled], backing: .buffered, defer: false)
+        parent.isReleasedWhenClosed = false
+        let panel = HomeUtilityPanel(page: "rules", store: try recordStore())
+        defer { panel.close(); parent.close() }
+        panel.refresh(mode: .free, volume: 0.4); panel.present(from: parent)
+        let window = try XCTUnwrap(panel.window)
+        XCTAssertTrue(window.parent === parent)
+        XCTAssertFalse(window.canBecomeKey)
+        if let screen = parent.screen ?? NSScreen.main { XCTAssertTrue(screen.visibleFrame.insetBy(dx: 7, dy: 7).contains(window.frame)) }
+        let content = try XCTUnwrap(window.contentView as? UtilityPageView)
+        window.setContentSize(NSSize(width: 480, height: 420)); content.layoutSubtreeIfNeeded()
+        content.document.scroll(NSPoint(x: 0, y: 100))
+        let position = content.scroll.contentView.bounds.origin
+        panel.refresh(mode: .free, volume: 0.5)
+        XCTAssertEqual(content.scroll.contentView.bounds.origin, position)
+    }
+
+    private func export(_ view: NSView, name: String) throws {
+        view.layoutSubtreeIfNeeded()
+        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+        view.cacheDisplay(in: view.bounds, to: bitmap)
+        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-\(name).png")
+        try png.write(to: url)
+        print("辅助面板预览：\(url.path)")
+    }
+}
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -1,6 +1,25 @@
-# 成就界面测试图
+# 游戏界面测试图
 
 这些文件仅用于开发测试与评审，正式应用中没有图标预览按钮或图标预览页面。
+
+## 游戏设置、玩法说明与挑战记录
+
+三个辅助面板共用首页的暖白背景、圆角卡片、蓝色信息色和黄色强调色。
+
+- [游戏设置](utility-settings.png)：语言选择卡片、金色音量滑杆、实时百分比与即时生效提示。
+- [玩法说明](utility-rules.png)：三步操作示意、固定模式规则和本局/累计进度说明。
+- [竞分排行榜](utility-records.png)、[竞速排行榜](utility-records-speed.png)：带滑动过渡的模式切换、个人最佳、金银铜名次及对齐的记录列。
+- [暂无记录状态](utility-records-empty.png)：显示空榜单提示，不生成虚构成绩。
+- 上述截图中的成绩来自隔离测试存档；正式应用没有测试预览入口。
+- 小窗口可滚动查看内容，系统减少动态效果开启时切换立即完成。
+
+重新生成辅助面板截图：
+
+```sh
+DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeUtilityPanelTests
+```
+
+将临时目录中的 `eliminate-utility-*.png` 复制为本目录对应的 `utility-*.png`；`*-compact-ru.png` 仅用于长翻译与紧凑窗口检查，无需归档。
 
 ## 筛选切换动画
 
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031233928-polish-game-utility-panels.md` - 会话-106 起统一重构游戏设置、玩法说明与挑战记录：主题卡片、金色音量滑杆、三步图文教学、动画模式切换、个人最佳及金银铜排行；含全部增量 diff、五语言/小窗口截图与 60 项完整回归。
 `workflow/20261031231944-simplify-achievement-heading.md` - 会话-103 起简化成就页标题，移除分隔点与已解锁统计，前置图标改为彩色奖章；含全部增量 diff、真实截图与 4 项界面回归。
 `workflow/20261031230317-animated-achievement-filter.md` - 会话-97 起将成就筛选改为暖白金色一体式滑轨，加入数量提示、0.24 秒滑动、快速打断接续与减少动态效果支持；含全部逐行 diff、真实动画/截图和 55 项完整回归。
 `workflow/20261031222305-remove-lifetime-milestone-stars.md` - 会话-95 起移除总累计百/千/万图案中的五角星，仅保留三档方块并重新居中；含完整增量 diff、更新测试图与 5 项图标回归。
@@ -78,6 +79,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整设置控件、玩法教学卡片、挑战排行榜/空状态、辅助面板滚动与定位，或查看实际测试图时，读取 `20261031233928-polish-game-utility-panels.md`。
 - 需要调整成就页简洁标题、前置彩色奖章或核对本轮标题变更时，读取 `20261031231944-simplify-achievement-heading.md`。
 - 需要调整成就页筛选滑块的美术、动画、数量、原生选择兼容或五语言布局时，读取 `20261031230317-animated-achievement-filter.md`。
 - 需要确认总累计百/千/万图案为何没有五角星、查看纯方块效果或居中调整时，读取 `20261031222305-remove-lifetime-milestone-stars.md`。
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -201,3 +201,29 @@
 "home.unlocked_count" = "已解锁 %d / %d";
 "home.rules.fixed" = "每个消除方块计 10 分。竞分固定 60 秒，竞速固定 300 分；达到条件后自动结束。切换模式或重新开始会清零本局统计，成就累计进度会保留。";
 "home.records.fixed" = "固定规则：竞分 60 秒 · 竞速 300 分";
+
+/* 辅助面板：设置、玩法说明与挑战记录。 */
+"utility.settings.subtitle" = "让游戏，更合你的节奏。";
+"utility.rules.subtitle" = "交换、相连、连锁，快乐就这么简单。";
+"utility.records.subtitle" = "记录每次突破，向个人最佳再进一步。";
+"utility.settings.language_hint" = "选择你熟悉的界面语言";
+"utility.settings.volume_hint" = "统一调节背景音乐与游戏音效";
+"utility.settings.instant" = "调整即时生效，无需额外保存。";
+"utility.lesson.0.title" = "交换位置";
+"utility.lesson.0.body" = "在触控栏上拖动相邻方块，支持多点触控。";
+"utility.lesson.1.title" = "连成三个，轻松消除";
+"utility.lesson.1.body" = "三个或更多同类方块相连即可消除，每个计 10 分。";
+"utility.lesson.2.title" = "补位接力，连锁得分";
+"utility.lesson.2.body" = "消除后自动补位；再次连成同类方块可继续消除。";
+"utility.rules.modes" = "三种玩法，随心挑战";
+"utility.rules.current" = "当前模式";
+"utility.rules.progress" = "重新开始或切换模式会清空本局统计；已获得成就与累计进度会保留。";
+"utility.unit.points" = "分";
+"utility.unit.seconds" = "秒";
+"utility.records.best" = "个人最佳";
+"utility.records.score_rule" = "固定 60 秒 · 分数越高，排名越前";
+"utility.records.speed_rule" = "目标 300 分 · 用时越短，排名越前";
+"utility.records.rank" = "名次";
+"utility.records.result" = "成绩";
+"utility.records.date" = "挑战日期";
+"utility.records.empty_hint" = "完成一局挑战，写下你的第一条记录。";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -194,3 +194,29 @@
 "home.unlocked_count" = "達成 %d / %d";
 "home.rules.fixed" = "1 個消すと 10 点。スコアアタックは 60 秒、スピードランは 300 点で終了。モード変更や再開で一局の記録はリセットされ、実績の累計は保存されます。";
 "home.records.fixed" = "固定ルール：60 秒スコアアタック · 300 点スピードラン";
+
+/* 辅助面板：设置、玩法说明与挑战记录。 */
+"utility.settings.subtitle" = "自分らしいペースで楽しもう。";
+"utility.rules.subtitle" = "交換、マッチ、連鎖。楽しさはシンプル。";
+"utility.records.subtitle" = "自己ベストの先へ、もう一度。";
+"utility.settings.language_hint" = "使いやすい表示言語を選択";
+"utility.settings.volume_hint" = "BGM とゲーム効果音をまとめて調整";
+"utility.settings.instant" = "変更はすぐに反映されます。";
+"utility.lesson.0.title" = "位置を交換";
+"utility.lesson.0.body" = "Touch Bar で隣り合うブロックをドラッグ。マルチタッチにも対応。";
+"utility.lesson.1.title" = "3 個以上つなげよう";
+"utility.lesson.1.body" = "同じ種類を 3 個以上つなげると消去。1 個につき 10 点。";
+"utility.lesson.2.title" = "補充から連鎖へ";
+"utility.lesson.2.body" = "消去した場所にブロックを補充。再びそろうと自動で連鎖。";
+"utility.rules.modes" = "選べる 3 つの遊び方";
+"utility.rules.current" = "選択中";
+"utility.rules.progress" = "やり直しやモード変更で今回の統計はリセット。実績と累計進捗は保持されます。";
+"utility.unit.points" = "点";
+"utility.unit.seconds" = "秒";
+"utility.records.best" = "自己ベスト";
+"utility.records.score_rule" = "制限時間 60 秒 · 高得点ほど上位";
+"utility.records.speed_rule" = "目標 300 点 · 短いタイムほど上位";
+"utility.records.rank" = "順位";
+"utility.records.result" = "記録";
+"utility.records.date" = "プレイ日";
+"utility.records.empty_hint" = "チャレンジを完了して最初の記録を残そう。";
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -201,3 +201,29 @@
 "home.unlocked_count" = "Unlocked %d / %d";
 "home.rules.fixed" = "Each cleared tile earns 10 points. Score Attack lasts 60 seconds; Speed Run ends at 300 points. Switching modes or restarting clears this round’s counters. Lifetime achievement progress is saved.";
 "home.records.fixed" = "Fixed rules: 60-second Score Attack · 300-point Speed Run";
+
+/* 辅助面板：设置、玩法说明与挑战记录。 */
+"utility.settings.subtitle" = "Make the game feel like you.";
+"utility.rules.subtitle" = "Swap, match, and let the chain begin.";
+"utility.records.subtitle" = "Keep your best. Chase your next breakthrough.";
+"utility.settings.language_hint" = "Choose your preferred interface language";
+"utility.settings.volume_hint" = "Adjust music and game effects together";
+"utility.settings.instant" = "Changes take effect immediately.";
+"utility.lesson.0.title" = "Swap positions";
+"utility.lesson.0.body" = "Drag neighboring tiles on the Touch Bar. Multi-touch is supported.";
+"utility.lesson.1.title" = "Match three or more";
+"utility.lesson.1.body" = "Connect at least three tiles of the same kind. Each cleared tile earns 10 points.";
+"utility.lesson.2.title" = "Keep the chain going";
+"utility.lesson.2.body" = "New tiles fill the gaps. Further matches clear automatically.";
+"utility.rules.modes" = "Three ways to play";
+"utility.rules.current" = "Current mode";
+"utility.rules.progress" = "Restarting or changing mode resets this round. Achievements and lifetime progress stay with you.";
+"utility.unit.points" = "pts";
+"utility.unit.seconds" = "sec";
+"utility.records.best" = "Personal best";
+"utility.records.score_rule" = "Fixed 60 seconds · Higher scores rank first";
+"utility.records.speed_rule" = "Target 300 points · Faster times rank first";
+"utility.records.rank" = "Rank";
+"utility.records.result" = "Result";
+"utility.records.date" = "Played on";
+"utility.records.empty_hint" = "Finish a challenge to set your first record.";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -194,3 +194,29 @@
 "home.unlocked_count" = "달성 %d / %d";
 "home.rules.fixed" = "블록 하나당 10점입니다. 점수 도전은 60초, 스피드런은 300점에 도달하면 끝납니다. 모드 변경이나 재시작 시 현재 판의 통계는 초기화되며 업적의 누적 진행은 유지됩니다.";
 "home.records.fixed" = "고정 규칙: 60초 점수 도전 · 300점 스피드런";
+
+/* 辅助面板：设置、玩法说明与挑战记录。 */
+"utility.settings.subtitle" = "나만의 리듬으로 즐겨 보세요.";
+"utility.rules.subtitle" = "교환하고, 연결하고, 연쇄로 즐기세요.";
+"utility.records.subtitle" = "매번 도전하며 나의 최고 기록을 넘어서세요.";
+"utility.settings.language_hint" = "익숙한 화면 언어를 선택하세요";
+"utility.settings.volume_hint" = "배경 음악과 게임 효과음을 함께 조절합니다";
+"utility.settings.instant" = "변경 사항은 즉시 적용됩니다.";
+"utility.lesson.0.title" = "위치 교환";
+"utility.lesson.0.body" = "Touch Bar에서 이웃한 블록을 드래그하세요. 멀티 터치도 지원합니다.";
+"utility.lesson.1.title" = "3개 이상 연결";
+"utility.lesson.1.body" = "같은 종류를 3개 이상 연결하면 제거됩니다. 블록당 10점입니다.";
+"utility.lesson.2.title" = "계속되는 연쇄";
+"utility.lesson.2.body" = "제거한 자리에 새 블록이 채워집니다. 다시 연결되면 자동으로 제거됩니다.";
+"utility.rules.modes" = "세 가지 플레이 방식";
+"utility.rules.current" = "현재 모드";
+"utility.rules.progress" = "다시 시작하거나 모드를 바꾸면 이번 게임 통계가 초기화됩니다. 업적과 누적 진행도는 유지됩니다.";
+"utility.unit.points" = "점";
+"utility.unit.seconds" = "초";
+"utility.records.best" = "개인 최고 기록";
+"utility.records.score_rule" = "제한 시간 60초 · 점수가 높을수록 높은 순위";
+"utility.records.speed_rule" = "목표 300점 · 시간이 짧을수록 높은 순위";
+"utility.records.rank" = "순위";
+"utility.records.result" = "기록";
+"utility.records.date" = "도전 날짜";
+"utility.records.empty_hint" = "도전을 완료하고 첫 기록을 남겨 보세요.";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -194,3 +194,29 @@
 "home.unlocked_count" = "Открыто %d / %d";
 "home.rules.fixed" = "Каждый удалённый блок даёт 10 очков. Игра на очки длится 60 секунд; игра на скорость завершается при 300 очках. Смена режима или перезапуск обнуляет статистику игры, но сохраняет общий прогресс достижений.";
 "home.records.fixed" = "Правила: 60 секунд на очки · 300 очков на скорость";
+
+/* 辅助面板：设置、玩法说明与挑战记录。 */
+"utility.settings.subtitle" = "Играйте в своём ритме.";
+"utility.rules.subtitle" = "Меняйте, собирайте, запускайте цепочки.";
+"utility.records.subtitle" = "Сохраняйте успехи и улучшайте личный рекорд.";
+"utility.settings.language_hint" = "Выберите удобный язык интерфейса";
+"utility.settings.volume_hint" = "Общая громкость музыки и звуков игры";
+"utility.settings.instant" = "Изменения применяются сразу.";
+"utility.lesson.0.title" = "Меняйте местами";
+"utility.lesson.0.body" = "Перетаскивайте соседние фигуры на Touch Bar. Поддерживается мультитач.";
+"utility.lesson.1.title" = "Соберите три или больше";
+"utility.lesson.1.body" = "Три и более фигуры одного вида исчезают. Каждая приносит 10 очков.";
+"utility.lesson.2.title" = "Продолжайте цепочку";
+"utility.lesson.2.body" = "Пустоты заполняются новыми фигурами. Новые совпадения исчезают автоматически.";
+"utility.rules.modes" = "Три режима игры";
+"utility.rules.current" = "Текущий режим";
+"utility.rules.progress" = "Перезапуск или смена режима обнуляет статистику раунда. Достижения и общий прогресс сохраняются.";
+"utility.unit.points" = "очк.";
+"utility.unit.seconds" = "сек.";
+"utility.records.best" = "Личный рекорд";
+"utility.records.score_rule" = "60 секунд · Больше очков — выше место";
+"utility.records.speed_rule" = "Цель: 300 очков · Меньше время — выше место";
+"utility.records.rank" = "Место";
+"utility.records.result" = "Результат";
+"utility.records.date" = "Дата игры";
+"utility.records.empty_hint" = "Завершите испытание, чтобы установить первый рекорд.";
```

### `Sources/AchievementFilterControl.swift`

```diff
--- a/Sources/AchievementFilterControl.swift
+++ b/Sources/AchievementFilterControl.swift
@@ -9,6 +9,8 @@
     private var tracking: NSTrackingArea?
     private var hoveredSegment: Int?
     private var hasPlacedThumb = false
+    /// 辅助页面复用同一套滑轨质感；未指定时保持成就筛选的三个状态图标。
+    var segmentSymbols = ["square.grid.2x2.fill", "lock.fill", "checkmark.seal.fill"]
     /// 在测试中可替换系统偏好，运行时每次切换都读取最新设置。
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
     static let transitionDuration: CFTimeInterval = 0.24
@@ -131,8 +133,8 @@
             }
             let contentWidth = 13 + 6 + titleWidth + 7 + countWidth
             let start = rect.midX - contentWidth / 2
-            let symbols = ["square.grid.2x2.fill", "lock.fill", "checkmark.seal.fill"]
-            HomeStyle.symbol(symbols[min(index, 2)], in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
+            let symbol = segmentSymbols.indices.contains(index) ? segmentSymbols[index] : "square.fill"
+            HomeStyle.symbol(symbol, in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
             let titleSize = (title as NSString).size(withAttributes: [.font: font])
             (title as NSString).draw(at: NSPoint(x: start + 19, y: rect.midY - titleSize.height / 2), withAttributes: [.font: font, .foregroundColor: color])
             let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
```

### `docs/previews/utility-settings.png`

```diff
- 未提供该面板的测试预览。
+ 新增真实 AppKit 渲染 PNG，使用隔离测试数据，不写入玩家存档。
```

- SHA-256：`969fd8a7f48021cb388333c6e3818020871a9f79b445b7fefde2013bc8126ad4`

### `docs/previews/utility-rules.png`

```diff
- 未提供该面板的测试预览。
+ 新增真实 AppKit 渲染 PNG，使用隔离测试数据，不写入玩家存档。
```

- SHA-256：`91222c9030c30276225b27324882868874814d9673b1187067e250691f91721f`

### `docs/previews/utility-records.png`

```diff
- 未提供该面板的测试预览。
+ 新增真实 AppKit 渲染 PNG，使用隔离测试数据，不写入玩家存档。
```

- SHA-256：`6e27a0a9693a81105dac1272bd9b1ea3505fef87707bdf8c14763e9df6cc658c`

### `docs/previews/utility-records-speed.png`

```diff
- 未提供该面板的测试预览。
+ 新增真实 AppKit 渲染 PNG，使用隔离测试数据，不写入玩家存档。
```

- SHA-256：`e802afb56494d6d0cd9085391b0b2bd88459dbaefe0f89a4861af419a8880982`

### `docs/previews/utility-records-empty.png`

```diff
- 未提供该面板的测试预览。
+ 新增真实 AppKit 渲染 PNG，使用隔离测试数据，不写入玩家存档。
```

- SHA-256：`468116f6c463d366fb5ee6ba7523ac6921b63e88007aec52ff6ba126000fa8de`

## 测试方法与结果
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。
- 最终结果：2026-10-31 23:38:02，60 项通过，0 失败。
- 新增专项：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeUtilityPanelTests`，5 项通过。
- TC-001 设置：五语言原生菜单回调、音量 0%/26%/100%、实时显示，且仅暴露语言和总音量。
- TC-002 排行榜：真实固定规则分桶、竞分/竞速切换、排序后的最佳成绩、记录新增后刷新，保留已选榜单；旧两分钟记录不混入当前榜单。
- TC-003 空记录/玩法：不生成虚构成绩；三个模式的说明均使用固定规则，并且只有一个当前模式标记。
- TC-004 多语言/布局：五语言 × 三页面 × 默认/480×420 尺寸；无缺失文案键、无横向溢出；初始滚动从顶部开始。
- TC-005 窗口/滚动：跟随主窗口定位并收敛到屏幕可用区域；不争抢焦点；快照刷新保留正文滚动位置。
- 既有成就筛选测试覆盖快速切换的动画接续、原生事件和系统减少动态效果；复用后完整回归通过。
- 首轮专项中临时父窗口关闭时发生测试崩溃，已明确设置该测试窗口 `isReleasedWhenClosed = false`，避免测试持有引用与 AppKit 关闭释放冲突；最终回归通过。
- 人工查看所有正常中文面板、两个榜单、空榜单与三张俄文紧凑截图，确认卡片、列对齐、换行、滚动及控件中心正常。
- 最终静态检查：`git diff --check`。

## 手工验收
1. 使用 `./run.sh` 启动，在首页分别打开游戏设置、玩法说明、挑战记录。
2. 在设置中切换语言，拖动音量到 0%、中间值、100%，观察百分比与实际音量。
3. 在玩法页确认三步示意和固定 60 秒/300 分规则；切换首页模式后重新查看当前模式标记。
4. 在记录页切换竞分/竞速，观察金色滑块过渡、对应个人最佳及名次。完成新挑战后重新打开验证数据更新。
5. 小屏幕或靠近屏幕边缘打开面板，确认位于主窗口附近且正文可滚动；在系统减少动态效果开启后切换榜单应立即完成。

## 预览
- `docs/previews/README.md` 为开发评审入口，仅测试导出，不在正式应用中增加预览按钮。
