import Cocoa

private final class HomeAuxiliaryWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 控制事件与真实数据留在控制器，主题组件负责辅助页面布局。
final class HomeUtilityPanel: NSWindowController {
    let page: String
    var onLanguage: ((AppLanguage) -> Void)?
    var onVolume: ((Float) -> Void)?
    private let content: UtilityPageView
    private let language = UtilityLanguagePopup(frame: .zero, pullsDown: false)
    private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let percent = UtilityStyle.label("", size: 18, weight: .bold)
    private let recordTabs = AchievementFilterControl(frame: .zero)
    private let recordBody = UtilityStyle.stack([])
    private let store: ModeRecordStore
    // 快照高频刷新时不重建卡片，保留滚动位置和控件操作状态。
    private var renderedLanguage: AppLanguage?
    private var renderedMode: HomeGameMode?
    private var renderedRecordIDs: [String] = []
    private var showingHistory = false

    init(page: String, store: ModeRecordStore = .shared) {
        self.page = page; self.store = store; content = UtilityPageView(page: page)
        let size = NSSize(width: page == "settings" ? 540 : 600, height: page == "settings" ? 430 : 740)
        let panel = HomeAuxiliaryWindow(contentRect: NSRect(origin: .zero, size: size),
                                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = HomeStyle.background; panel.hidesOnDeactivate = true
        content.frame = NSRect(origin: .zero, size: size); content.autoresizingMask = [.width, .height]
        panel.contentView = content
        super.init(window: panel)
        language.font = .systemFont(ofSize: 14, weight: .semibold); language.isBordered = false
        language.focusRingType = .exterior; language.target = self; language.action = #selector(languageChanged)
        volume.cell = UtilityVolumeSliderCell(); volume.minValue = 0; volume.maxValue = 1
        volume.isContinuous = true; volume.target = self; volume.action = #selector(volumeChanged)
        percent.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold); percent.alignment = .right
        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = [HomeGameMode.timed.symbol, HomeGameMode.moves.symbol]
        recordTabs.selectedSegment = 0; recordTabs.target = self; recordTabs.action = #selector(recordModeChanged)
        // 固定尺寸只注册一次，语言切换时仅重建排版与文案。
        NSLayoutConstraint.activate([
            language.heightAnchor.constraint(equalToConstant: 44), volume.heightAnchor.constraint(equalToConstant: 34),
            percent.widthAnchor.constraint(equalToConstant: 56), recordTabs.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    required init?(coder: NSCoder) { nil }

    func refresh(mode: HomeGameMode, volume value: Float) {
        let languageChanged = renderedLanguage != Localizer.shared.language
        content.refreshHeader(page: page); window?.title = UtilityStyle.text("panel.\(page)")
        if page == "settings" {
            if languageChanged { buildSettings() }
            if languageChanged {
                language.removeAllItems()
                language.addItems(withTitles: AppLanguage.allCases.map { UtilityStyle.text($0.titleKey) })
            }
            language.selectItem(at: AppLanguage.allCases.firstIndex(of: Localizer.shared.language) ?? 0)
            volume.doubleValue = Double(value); updateVolumeLabel()
        } else if page == "rules" {
            if languageChanged || renderedMode != mode { UtilityRulesContent.populate(content, mode: mode) }
        } else {
            let ids = recordEntries(.timed).map(\.id) + recordEntries(.moves).map(\.id)
            if languageChanged {
                content.removeSections(); content.addSection(recordTabs)
                content.addSection(recordBody)
                recordTabs.setLabel(UtilityStyle.text("home.mode.timed"), forSegment: 0)
                recordTabs.setLabel(UtilityStyle.text("home.mode.moves"), forSegment: 1)
            }
            recordTabs.updateCounts([recordEntries(.timed).count, recordEntries(.moves).count]); recordTabs.refreshMetrics()
            if languageChanged || ids != renderedRecordIDs { refreshRecords() }
            renderedRecordIDs = ids
        }
        renderedLanguage = Localizer.shared.language; renderedMode = mode
        content.layoutSubtreeIfNeeded()
    }

    private func buildSettings() {
        content.removeSections()
        let languageStack = UtilityStyle.stack([settingHeading("globe", title: "language.label", detail: "utility.settings.language_hint"), language], spacing: 16)
        UtilityStyle.fillWidth(language, in: languageStack)
        content.addSection(UtilityCard(languageStack))
        let sliderRow = UtilityStyle.stack([UtilityStyle.icon("speaker.fill", color: HomeStyle.secondary, size: 16), volume, percent], vertical: false, spacing: 14)
        volume.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let volumeStack = UtilityStyle.stack([settingHeading("speaker.wave.2.fill", title: "volume.label", detail: "utility.settings.volume_hint"), sliderRow], spacing: 14)
        UtilityStyle.fillWidth(sliderRow, in: volumeStack)
        content.addSection(UtilityCard(volumeStack))
        let footnote = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.green, size: 16),
                                          UtilityStyle.label(UtilityStyle.text("utility.settings.instant"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 7)
        content.addSection(footnote)
        language.setAccessibilityLabel(UtilityStyle.text("language.label")); volume.setAccessibilityLabel(UtilityStyle.text("volume.label"))
    }

    private func settingHeading(_ symbol: String, title: String, detail: String) -> NSView {
        let copy = UtilityStyle.stack([UtilityStyle.label(UtilityStyle.text(title), size: 15, weight: .bold),
                                       UtilityStyle.label(UtilityStyle.text(detail), size: 12, color: HomeStyle.secondary)], spacing: 4)
        return UtilityStyle.stack([UtilityStyle.icon(symbol, color: HomeStyle.blue, size: 26), copy], vertical: false, spacing: 13)
    }
    private func recordEntries(_ mode: ModeRecordKey) -> [ModeRecord] { store.records(for: mode, detailValue: mode == .timed ? 60 : 30) }

    private func refreshRecords() {
        for view in recordBody.arrangedSubviews { recordBody.removeArrangedSubview(view); view.removeFromSuperview() }
        let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .timed : .moves
        let entries = recordEntries(mode)
        for view in [UtilityRecordBestView(mode: mode, entry: entries.first), UtilityRecordContent.table(mode: mode, entries: entries)] {
            recordBody.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: recordBody)
        }
        let sections = store.legacySections()
        if !sections.isEmpty {
            let historyButton = HomeButton(frame: .zero)
            historyButton.title = UtilityStyle.text(showingHistory ? "utility.records.hide_history" : "utility.records.show_history")
            historyButton.symbolName = "clock"
            historyButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            historyButton.onClick = { [weak self] in
                guard let self else { return }
                self.showingHistory.toggle(); self.refreshRecords(); self.content.layoutSubtreeIfNeeded()
            }
            recordBody.addArrangedSubview(historyButton); UtilityStyle.fillWidth(historyButton, in: recordBody)
            if showingHistory {
                for section in sections {
                    let card = UtilityRecordContent.legacyTable(section)
                    recordBody.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: recordBody)
                }
            }
        }
    }

    func present(from parent: NSWindow?) {
        guard let window else { return }
        if let parent {
            let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
            // 小屏幕先收敛尺寸，再按主窗口居中，正文滚动区承载剩余内容。
            var frame = window.frame
            frame.size.width = min(frame.width, available.width - 16); frame.size.height = min(frame.height, available.height - 16)
            frame.origin.x = min(max(parent.frame.midX - frame.width / 2, available.minX + 8), available.maxX - frame.width - 8)
            frame.origin.y = min(max(parent.frame.midY - frame.height / 2, available.minY + 8), available.maxY - frame.height - 8)
            window.setFrame(frame, display: false)
            if window.parent !== parent { window.parent?.removeChildWindow(window); parent.addChildWindow(window, ordered: .above) }
        } else { window.center() }
        content.layoutSubtreeIfNeeded(); window.orderFront(nil)
    }

    @objc private func languageChanged() {
        guard AppLanguage.allCases.indices.contains(language.indexOfSelectedItem) else { return }
        onLanguage?(AppLanguage.allCases[language.indexOfSelectedItem])
    }
    private func updateVolumeLabel() {
        percent.stringValue = "\(Int((volume.doubleValue * 100).rounded()))%"; volume.setAccessibilityValue(percent.stringValue)
    }
    @objc private func volumeChanged() { updateVolumeLabel(); onVolume?(Float(volume.doubleValue)) }
    @objc private func recordModeChanged() {
        refreshRecords(); content.layoutSubtreeIfNeeded(); content.scroll.documentView?.scroll(.zero)
    }
}
