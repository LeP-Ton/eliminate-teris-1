import Cocoa

final class GameViewController: NSViewController, NSTouchBarDelegate {
    private enum ModeSelection: Int {
        case free = 0
        case scoreAttack = 1
        case speedRun = 2
    }

    private enum ControlRow: Int {
        case language = 0
        case mode = 1
        case option = 2
        case action = 3
    }

    private enum BadgeTone {
        case ready
        case running
        case combo
        case finish
    }

    private struct RecordPanelContext {
        let modeKey: ModeRecordKey
        let detailValue: Int

        var scopeID: String {
            return ModeRecordStore.scopeID(mode: modeKey, detailValue: detailValue)
        }
    }

    private let localizer = Localizer.shared
    private let settingsThemeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
    private let statusThemeColor = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
    private let recordsThemeColor = NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.58, alpha: 0.96)
    private let rulesThemeColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
    private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)

    private let columns = 12
    private let scoreAttackMinutes = [1, 2, 3]
    private let speedRunTargets = [300, 600, 900]
    private let recordStore = ModeRecordStore.shared

    private lazy var controller = GameBoardController(columns: columns)
    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)

    private var observerToken: UUID?
    private var hudTimer: Timer?
    private var selectedScoreAttackIndex = 0
    private var selectedSpeedRunIndex = 0
    private var comboStreak = 0
    private var lastObservedScore = 0
    private var lastScoreGainDate: Date?
    private var hasSavedFinishedRecord = false
    private var latestRecordIDByMode: [String: String] = [:]
    private var lastRecordsLayoutWidth: CGFloat = 0
    private var settingsExpandedWidthConstraint: NSLayoutConstraint?
    private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
    private var rightColumnMinWidthConstraint: NSLayoutConstraint?

    private lazy var headerIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = NSColor.systemYellow
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .heavy)
        imageView.imageScaling = .scaleProportionallyDown
        return imageView
    }()

    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .heavy)
        label.textColor = NSColor.white
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = NSColor.white.withAlphaComponent(0.72)
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var headerTextStack: NSStackView = {
        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var headerStack: NSStackView = {
        let stack = NSStackView(views: [headerIconView, headerTextStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var pixelBannerView: PixelBannerView = {
        let banner = PixelBannerView(frame: .zero)
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }()

    private lazy var settingsTitleLabel: NSTextField = {
        return makeSectionTitleLabel(color: settingsThemeColor)
    }()

    private lazy var settingsTitleIconView: NSImageView = {
        return makeSectionIconView(symbolName: "slider.horizontal.3", color: settingsThemeColor)
    }()

    private lazy var settingsHeaderStack: NSStackView = {
        return makeSectionHeaderStack(iconView: settingsTitleIconView, titleLabel: settingsTitleLabel)
    }()

    private lazy var statusTitleLabel: NSTextField = {
        return makeSectionTitleLabel(color: statusThemeColor)
    }()

    private lazy var statusTitleIconView: NSImageView = {
        return makeSectionIconView(symbolName: "timer", color: statusThemeColor)
    }()

    private lazy var statusHeaderStack: NSStackView = {
        return makeSectionHeaderStack(iconView: statusTitleIconView, titleLabel: statusTitleLabel)
    }()

    private lazy var statusBadgeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = NSColor.white
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
        label.wantsLayer = true
        label.layer?.cornerRadius = 5
        label.layer?.masksToBounds = true
        label.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var languageTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var languagePopup: ArcadePopupButton = {
        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(languageSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var modeTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var modePopup: ArcadePopupButton = {
        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(modeSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var optionTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var optionPopup: ArcadePopupButton = {
        let popup = ArcadePopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(optionSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var startTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var startButton: ArcadeActionButton = {
        let button = ArcadeActionButton(title: "", target: self, action: #selector(startButtonTapped(_:)))
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var controlsGrid: NSGridView = {
        let grid = NSGridView(views: [
            [languageTitleLabel, languagePopup],
            [modeTitleLabel, modePopup],
            [optionTitleLabel, optionPopup],
            [startTitleLabel, startButton]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        for rowIndex in 0..<grid.numberOfRows {
            grid.row(at: rowIndex).yPlacement = .center
        }
        return grid
    }()

    private lazy var competitiveInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .left
        label.textColor = NSColor.systemGreen
        label.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .heavy)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var resultLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.alignment = .left
        label.textColor = statusThemeColor.withAlphaComponent(0.86)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var rulesTitleLabel: NSTextField = {
        return makeSectionTitleLabel(color: rulesThemeColor)
    }()

    private lazy var rulesTitleIconView: NSImageView = {
        return makeSectionIconView(symbolName: "doc.text", color: rulesThemeColor)
    }()

    private lazy var rulesHeaderStack: NSStackView = {
        return makeSectionHeaderStack(iconView: rulesTitleIconView, titleLabel: rulesTitleLabel)
    }()

    private lazy var rulesBodyLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.alignment = .left
        label.textColor = rulesBodyThemeColor
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var settingsCardView: PixelFrameCardView = {
        return PixelFrameCardView(accentColor: NSColor.systemBlue)
    }()

    private lazy var statusCardView: PixelFrameCardView = {
        return PixelFrameCardView(accentColor: NSColor.systemGreen)
    }()

    private lazy var settingsCardStack: NSStackView = {
        let stack = NSStackView(views: [settingsHeaderStack, controlsGrid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var statusCardStack: NSStackView = {
        let stack = NSStackView(views: [statusHeaderStack, statusBadgeLabel, competitiveInfoLabel, resultLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var rightColumnStack: NSStackView = {
        let stack = NSStackView(views: [statusCardView, recordsCardView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var cardsStack: NSStackView = {
        let stack = NSStackView(views: [settingsCardView, rightColumnStack])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.distribution = .fill
        stack.spacing = 14
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var recordsTitleLabel: NSTextField = {
        return makeSectionTitleLabel(color: recordsThemeColor)
    }()

    private lazy var recordsTitleIconView: NSImageView = {
        return makeSectionIconView(symbolName: "list.number", color: recordsThemeColor)
    }()

    private lazy var recordsHeaderStack: NSStackView = {
        let stack = NSStackView(views: [recordsTitleIconView, recordsTitleLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var recordsTextView: NSTextView = {
        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = recordsThemeColor.withAlphaComponent(0.88)
        textView.string = ""
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        return textView
    }()

    private lazy var recordsScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = recordsTextView
        return scrollView
    }()

    private lazy var recordsCardView: PixelFrameCardView = {
        let view = PixelFrameCardView(accentColor: NSColor.systemOrange)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.isHidden = true
        return view
    }()

    private lazy var recordsCardStack: NSStackView = {
        let stack = NSStackView(views: [recordsHeaderStack, recordsScrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var rulesCardView: PixelFrameCardView = {
        // 罗德岛风格的偏深红强调色。
        return PixelFrameCardView(accentColor: NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.3, alpha: 1.0))
    }()

    private lazy var rulesCardStack: NSStackView = {
        let stack = NSStackView(views: [rulesHeaderStack, rulesBodyLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var dividerView: PixelDividerView = {
        let view = PixelDividerView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var contentStack: NSStackView = {
        let stack = NSStackView(views: [headerStack, dividerView, pixelBannerView, cardsStack, rulesCardView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var gameTouchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [.game]
        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
        bar.customizationAllowedItemIdentifiers = []
        bar.customizationRequiredItemIdentifiers = [.game]
        return bar
    }()

    override func loadView() {
        let view = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
        self.view = view

        view.addSubview(contentStack)
        settingsCardView.addSubview(settingsCardStack)
        statusCardView.addSubview(statusCardStack)
        recordsCardView.addSubview(recordsCardStack)
        rulesCardView.addSubview(rulesCardStack)

        let settingsVersusRightColumnConstraint = settingsCardView.widthAnchor.constraint(
            greaterThanOrEqualTo: rightColumnStack.widthAnchor,
            multiplier: 1.24
        )
        let rightColumnMinWidthConstraint = rightColumnStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
        let settingsExpandedWidthConstraint = settingsCardView.widthAnchor.constraint(equalTo: cardsStack.widthAnchor)
        settingsExpandedWidthConstraint.isActive = false

        self.settingsVersusRightColumnConstraint = settingsVersusRightColumnConstraint
        self.rightColumnMinWidthConstraint = rightColumnMinWidthConstraint
        self.settingsExpandedWidthConstraint = settingsExpandedWidthConstraint

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),

            headerIconView.widthAnchor.constraint(equalToConstant: 34),
            headerIconView.heightAnchor.constraint(equalToConstant: 34),

            dividerView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 10),

            pixelBannerView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            pixelBannerView.heightAnchor.constraint(equalToConstant: 88),

            cardsStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            settingsCardView.widthAnchor.constraint(greaterThanOrEqualToConstant: 390),
            settingsVersusRightColumnConstraint,
            rightColumnMinWidthConstraint,
            rightColumnStack.heightAnchor.constraint(lessThanOrEqualTo: settingsCardView.heightAnchor),
            statusCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),
            recordsCardView.widthAnchor.constraint(equalTo: rightColumnStack.widthAnchor),

            settingsCardStack.topAnchor.constraint(equalTo: settingsCardView.topAnchor, constant: 14),
            settingsCardStack.leadingAnchor.constraint(equalTo: settingsCardView.leadingAnchor, constant: 14),
            settingsCardStack.trailingAnchor.constraint(equalTo: settingsCardView.trailingAnchor, constant: -14),
            settingsCardStack.bottomAnchor.constraint(equalTo: settingsCardView.bottomAnchor, constant: -14),

            statusCardStack.topAnchor.constraint(equalTo: statusCardView.topAnchor, constant: 14),
            statusCardStack.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 14),
            statusCardStack.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -14),
            statusCardStack.bottomAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: -14),

            recordsCardStack.topAnchor.constraint(equalTo: recordsCardView.topAnchor, constant: 14),
            recordsCardStack.leadingAnchor.constraint(equalTo: recordsCardView.leadingAnchor, constant: 14),
            recordsCardStack.trailingAnchor.constraint(equalTo: recordsCardView.trailingAnchor, constant: -14),
            recordsCardStack.bottomAnchor.constraint(equalTo: recordsCardView.bottomAnchor, constant: -14),

            controlsGrid.widthAnchor.constraint(equalTo: settingsCardStack.widthAnchor),
            statusBadgeLabel.widthAnchor.constraint(lessThanOrEqualTo: statusCardStack.widthAnchor),
            competitiveInfoLabel.widthAnchor.constraint(equalTo: statusCardStack.widthAnchor),
            resultLabel.widthAnchor.constraint(equalTo: statusCardStack.widthAnchor),
            recordsHeaderStack.widthAnchor.constraint(lessThanOrEqualTo: recordsCardStack.widthAnchor),
            recordsScrollView.widthAnchor.constraint(equalTo: recordsCardStack.widthAnchor),
            recordsScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            rulesCardView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            rulesCardStack.topAnchor.constraint(equalTo: rulesCardView.topAnchor, constant: 14),
            rulesCardStack.leadingAnchor.constraint(equalTo: rulesCardView.leadingAnchor, constant: 14),
            rulesCardStack.trailingAnchor.constraint(equalTo: rulesCardView.trailingAnchor, constant: -14),
            rulesCardStack.bottomAnchor.constraint(equalTo: rulesCardView.bottomAnchor, constant: -14),
            rulesBodyLabel.widthAnchor.constraint(equalTo: rulesCardStack.widthAnchor),

            languagePopup.widthAnchor.constraint(equalToConstant: 240),
            languagePopup.heightAnchor.constraint(equalToConstant: 38),
            modePopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
            modePopup.heightAnchor.constraint(equalToConstant: 38),
            optionPopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
            optionPopup.heightAnchor.constraint(equalToConstant: 38),
            startButton.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
            startButton.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            startButton.heightAnchor.constraint(equalToConstant: 38),

            languageTitleLabel.centerYAnchor.constraint(equalTo: languagePopup.centerYAnchor),
            modeTitleLabel.centerYAnchor.constraint(equalTo: modePopup.centerYAnchor),
            optionTitleLabel.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureLocalizedText()

        observerToken = controller.addObserver(owner: self) { [weak self] in
            self?.updateCompetitiveInfo()
        }

        modePopup.selectItem(at: ModeSelection.free.rawValue)
        applyModeSelection(resetGame: true)
    }

    deinit {
        if let observerToken {
            controller.removeObserver(observerToken)
        }
        hudTimer?.invalidate()
    }

    override func makeTouchBar() -> NSTouchBar? {
        return gameTouchBar
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.touchBar = gameTouchBar
        view.window?.makeFirstResponder(self)
        view.window?.minSize = NSSize(width: 720, height: 450)
        updateWindowTitle()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let currentWidth = max(recordsScrollView.contentSize.width, 0)
        if abs(currentWidth - lastRecordsLayoutWidth) > 0.5 {
            lastRecordsLayoutWidth = currentWidth
            updateRecordPanel(with: controller.snapshot())
        }
        refreshRecordsTextLayout()
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == .escapePlaceholder {
            let item = NSCustomTouchBarItem(identifier: .escapePlaceholder)
            let placeholder = NSView(frame: .zero)
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            item.view = placeholder

            NSLayoutConstraint.activate([
                placeholder.widthAnchor.constraint(equalToConstant: 0),
                placeholder.heightAnchor.constraint(equalToConstant: 30)
            ])
            return item
        }

        guard identifier == .game else { return nil }
        let item = NSCustomTouchBarItem(identifier: .game)
        gameTouchBarView.translatesAutoresizingMaskIntoConstraints = false
        item.view = gameTouchBarView

        NSLayoutConstraint.activate([
            gameTouchBarView.heightAnchor.constraint(equalToConstant: gameTouchBarView.intrinsicContentSize.height)
        ])
        return item
    }

    @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
        let index = max(0, sender.indexOfSelectedItem)
        let language = AppLanguage.allCases[min(index, AppLanguage.allCases.count - 1)]
        localizer.setLanguage(language)

        configureLocalizedText()
        updateCompetitiveInfo()
        updateWindowTitle()
    }

    @objc private func modeSelectionChanged(_ sender: NSPopUpButton) {
        applyModeSelection(resetGame: true)
    }

    @objc private func optionSelectionChanged(_ sender: NSPopUpButton) {
        switch currentModeSelection {
        case .free:
            break
        case .scoreAttack:
            selectedScoreAttackIndex = max(0, optionPopup.indexOfSelectedItem)
        case .speedRun:
            selectedSpeedRunIndex = max(0, optionPopup.indexOfSelectedItem)
        }

        applyModeSelection(resetGame: true)
    }

    @objc private func startButtonTapped(_ sender: NSButton) {
        guard currentModeSelection != .free else { return }
        resetRuntimeIndicators()
        hasSavedFinishedRecord = false
        controller.startRound()
        updateCompetitiveInfo()
    }

    @objc private func handleHudTimerTick() {
        controller.tick()
    }

    private func applyModeSelection(resetGame: Bool) {
        let selection = currentModeSelection
        populateOptionPopup(for: selection)
        updateStartControlVisibility(for: selection)
        updateCardsLayout(for: selection)
        updateRulesDescription(for: selection)

        if resetGame {
            resetRuntimeIndicators()
            hasSavedFinishedRecord = false
            controller.configure(mode: gameMode(for: selection))
        }

        updateCompetitiveInfo()
    }

    private func configureLocalizedText() {
        configureLanguagePopup()

        titleLabel.stringValue = localized("window.title")
        subtitleLabel.stringValue = localized("window.subtitle")
        settingsTitleLabel.stringValue = localized("panel.settings")
        statusTitleLabel.stringValue = localized("panel.status")
        recordsTitleLabel.stringValue = localized("panel.records")
        rulesTitleLabel.stringValue = localized("panel.rules")
        languageTitleLabel.stringValue = localized("language.label")
        modeTitleLabel.stringValue = localized("mode.label")
        startTitleLabel.stringValue = ""

        if let icon = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: titleLabel.stringValue) {
            headerIconView.image = icon
        }

        let selectedModeIndex = max(0, modePopup.indexOfSelectedItem)
        modePopup.removeAllItems()
        modePopup.addItems(withTitles: [
            localized("mode.free"),
            localized("mode.score_attack"),
            localized("mode.speed_run")
        ])
        modePopup.selectItem(at: min(selectedModeIndex, 2))

        populateOptionPopup(for: currentModeSelection)
        updateStartControlVisibility(for: currentModeSelection)
        updateCardsLayout(for: currentModeSelection)
        updateRulesDescription(for: currentModeSelection)

        let snapshot = controller.snapshot()
        updateStartControl(for: snapshot)
        updateRecordPanel(with: snapshot)
    }

    private func configureLanguagePopup() {
        let selectedLanguage = localizer.language
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map { localized($0.titleKey) })

        if let index = AppLanguage.allCases.firstIndex(of: selectedLanguage) {
            languagePopup.selectItem(at: index)
        } else {
            languagePopup.selectItem(at: 0)
        }
    }

    private func populateOptionPopup(for selection: ModeSelection) {
        let optionRow = controlsGrid.row(at: ControlRow.option.rawValue)

        switch selection {
        case .free:
            optionRow.isHidden = true

        case .scoreAttack:
            optionRow.isHidden = false
            optionTitleLabel.stringValue = localized("option.time")

            let titles = scoreAttackMinutes.map { localizedFormat("option.minute_format", $0) }
            optionPopup.removeAllItems()
            optionPopup.addItems(withTitles: titles)
            let clampedIndex = min(max(0, selectedScoreAttackIndex), titles.count - 1)
            optionPopup.selectItem(at: clampedIndex)
            selectedScoreAttackIndex = clampedIndex

        case .speedRun:
            optionRow.isHidden = false
            optionTitleLabel.stringValue = localized("option.target_score")

            let titles = speedRunTargets.map { localizedFormat("option.target_format", $0) }
            optionPopup.removeAllItems()
            optionPopup.addItems(withTitles: titles)
            let clampedIndex = min(max(0, selectedSpeedRunIndex), titles.count - 1)
            optionPopup.selectItem(at: clampedIndex)
            selectedSpeedRunIndex = clampedIndex
        }
    }

    private func updateStartControlVisibility(for selection: ModeSelection) {
        let actionRow = controlsGrid.row(at: ControlRow.action.rawValue)
        actionRow.isHidden = selection == .free
    }

    private func updateCardsLayout(for selection: ModeSelection) {
        let shouldExpandSettings = selection == .free
        rightColumnStack.isHidden = shouldExpandSettings
        settingsExpandedWidthConstraint?.isActive = shouldExpandSettings
        settingsVersusRightColumnConstraint?.isActive = !shouldExpandSettings
        rightColumnMinWidthConstraint?.isActive = !shouldExpandSettings
    }

    private func updateRulesDescription(for selection: ModeSelection) {
        let coreRulePrimary = localized("rules.core.line1")
        let coreRuleSecondary = localized("rules.core.line2")
        let operationLabel = localized("rules.label.operation")
        let modeRule: String
        let settlementRule: String

        switch selection {
        case .free:
            modeRule = localized("rules.short.mode.free")
            settlementRule = localized("rules.short.settlement.free")

        case .scoreAttack:
            let minutes = scoreAttackMinutes[min(max(0, selectedScoreAttackIndex), scoreAttackMinutes.count - 1)]
            modeRule = localizedFormat("rules.short.mode.score_attack", localizedFormat("option.minute_format", minutes))
            settlementRule = localized("rules.short.settlement.score_attack")

        case .speedRun:
            let targetScore = speedRunTargets[min(max(0, selectedSpeedRunIndex), speedRunTargets.count - 1)]
            modeRule = localizedFormat("rules.short.mode.speed_run", localizedFormat("option.target_format", targetScore))
            settlementRule = localized("rules.short.settlement.speed_run")
        }

        // 玩法说明统一去掉模式小标题，只保留规则项。
        var descriptionRows: [String] = []
        descriptionRows.append("• \(localized("rules.category.core"))：\(coreRulePrimary)")
        descriptionRows.append("• \(operationLabel)：\(coreRuleSecondary)")
        descriptionRows.append("• \(localized("rules.label.mode_rule"))：\(modeRule)")
        descriptionRows.append("• \(localized("rules.label.settlement"))：\(settlementRule)")
        let description = descriptionRows.joined(separator: "\n")
        rulesBodyLabel.stringValue = description
    }

    private func updateCompetitiveInfo() {
        let snapshot = controller.snapshot()
        updateComboState(with: snapshot)
        syncHudTimer(with: snapshot)
        updateStartControl(for: snapshot)
        updateStatusBadge(with: snapshot)
        persistModeRecordIfNeeded(with: snapshot)
        updateRecordPanel(with: snapshot)

        switch snapshot.mode {
        case .free:
            statusCardView.isHidden = true
            competitiveInfoLabel.stringValue = ""
            resultLabel.stringValue = ""
            resultLabel.isHidden = true

        case .scoreAttack:
            statusCardView.isHidden = false
            let remaining = formatClock(snapshot.remainingTime ?? 0)
            competitiveInfoLabel.stringValue = localizedFormat("hud.score_attack", snapshot.score, remaining)

            if snapshot.isFinished {
                resultLabel.stringValue = localizedFormat("result.score_attack_finished", snapshot.score)
                resultLabel.isHidden = false
            } else if !snapshot.isRunning {
                resultLabel.stringValue = localized("result.waiting_start")
                resultLabel.isHidden = false
            } else {
                resultLabel.stringValue = ""
                resultLabel.isHidden = true
            }

        case .speedRun:
            statusCardView.isHidden = false
            let targetScore = snapshot.targetScore ?? 0
            let elapsed = formatClock(snapshot.elapsedTime)
            competitiveInfoLabel.stringValue = localizedFormat("hud.speed_run", snapshot.score, targetScore, elapsed)

            if snapshot.isFinished {
                resultLabel.stringValue = localizedFormat("result.speed_run_finished", elapsed)
                resultLabel.isHidden = false
            } else if !snapshot.isRunning {
                resultLabel.stringValue = localized("result.waiting_start")
                resultLabel.isHidden = false
            } else {
                resultLabel.stringValue = ""
                resultLabel.isHidden = true
            }
        }
    }

    private func updateComboState(with snapshot: GameSnapshot) {
        switch snapshot.mode {
        case .free:
            resetRuntimeIndicators()
            return

        case .scoreAttack, .speedRun:
            if snapshot.isFinished {
                lastObservedScore = snapshot.score
                return
            }

            guard snapshot.isRunning else {
                comboStreak = 0
                lastObservedScore = snapshot.score
                lastScoreGainDate = nil
                return
            }

            let now = Date()
            if snapshot.score > lastObservedScore {
                comboStreak = min(comboStreak + 1, 99)
                lastScoreGainDate = now
            } else if snapshot.score < lastObservedScore {
                comboStreak = 0
                lastScoreGainDate = nil
            } else if let lastGain = lastScoreGainDate, now.timeIntervalSince(lastGain) > 1.6 {
                comboStreak = 0
            }

            lastObservedScore = snapshot.score
        }
    }

    private func updateStatusBadge(with snapshot: GameSnapshot) {
        switch snapshot.mode {
        case .free:
            hideStatusBadge()

        case .scoreAttack, .speedRun:
            if snapshot.isFinished {
                setStatusBadge(text: localized("status.finish"), tone: .finish)
            } else if !snapshot.isRunning {
                hideStatusBadge()
            } else if comboStreak >= 2 {
                setStatusBadge(text: localizedFormat("status.combo", comboStreak), tone: .combo)
            } else {
                setStatusBadge(text: localized("status.running"), tone: .running)
            }
        }
    }

    private func setStatusBadge(text: String, tone: BadgeTone) {
        statusBadgeLabel.isHidden = false
        statusBadgeLabel.stringValue = "  \(text)  "

        switch tone {
        case .ready:
            statusBadgeLabel.textColor = NSColor.white.withAlphaComponent(0.92)
            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.32, alpha: 0.95).cgColor
            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.38, green: 0.47, blue: 0.6, alpha: 0.95).cgColor

        case .running:
            statusBadgeLabel.textColor = NSColor(calibratedRed: 0.82, green: 1.0, blue: 0.82, alpha: 1)
            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.29, blue: 0.16, alpha: 0.95).cgColor
            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.38, green: 0.82, blue: 0.42, alpha: 0.95).cgColor

        case .combo:
            statusBadgeLabel.textColor = NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.76, alpha: 1)
            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.44, green: 0.27, blue: 0.06, alpha: 0.95).cgColor
            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.2, alpha: 0.95).cgColor

        case .finish:
            statusBadgeLabel.textColor = NSColor(calibratedRed: 1, green: 0.87, blue: 0.87, alpha: 1)
            statusBadgeLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.4, green: 0.14, blue: 0.16, alpha: 0.95).cgColor
            statusBadgeLabel.layer?.borderColor = NSColor(calibratedRed: 0.98, green: 0.44, blue: 0.44, alpha: 0.95).cgColor
        }

        statusBadgeLabel.layer?.borderWidth = 1
    }

    private func hideStatusBadge() {
        statusBadgeLabel.stringValue = ""
        statusBadgeLabel.isHidden = true
    }

    private func resetRuntimeIndicators() {
        comboStreak = 0
        lastObservedScore = 0
        lastScoreGainDate = nil
    }

    private func updateStartControl(for snapshot: GameSnapshot) {
        switch snapshot.mode {
        case .free:
            applyStartButtonAppearance(isRestart: false)
        case .scoreAttack, .speedRun:
            let isRestart = snapshot.isRunning || snapshot.isFinished
            applyStartButtonAppearance(isRestart: isRestart)
        }
    }

    private func applyStartButtonAppearance(isRestart: Bool) {
        let titleKey = isRestart ? "start.action_restart" : "start.action_start"
        let symbolName = isRestart ? "arrow.clockwise" : "play.fill"
        let title = localized(titleKey)

        let symbol: NSImage?
        if let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            symbol = baseSymbol.withSymbolConfiguration(config)
        } else {
            symbol = nil
        }

        startButton.setDisplay(title: title, image: symbol)
        startButton.toolTip = title
    }

    private func syncHudTimer(with snapshot: GameSnapshot) {
        let shouldRun: Bool
        switch snapshot.mode {
        case .free:
            shouldRun = false
        case .scoreAttack, .speedRun:
            shouldRun = snapshot.isRunning && !snapshot.isFinished
        }

        if shouldRun {
            if hudTimer == nil {
                let timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(handleHudTimerTick), userInfo: nil, repeats: true)
                RunLoop.main.add(timer, forMode: .common)
                hudTimer = timer
            }
        } else {
            hudTimer?.invalidate()
            hudTimer = nil
        }
    }

    private var currentModeSelection: ModeSelection {
        return ModeSelection(rawValue: modePopup.indexOfSelectedItem) ?? .free
    }

    private func gameMode(for selection: ModeSelection) -> GameMode {
        switch selection {
        case .free:
            return .free
        case .scoreAttack:
            let minutes = scoreAttackMinutes[selectedScoreAttackIndex]
            return .scoreAttack(duration: TimeInterval(minutes * 60))
        case .speedRun:
            let target = speedRunTargets[selectedSpeedRunIndex]
            return .speedRun(targetScore: target)
        }
    }

    private func updateWindowTitle() {
        view.window?.title = localized("window.title")
    }

    private func persistModeRecordIfNeeded(with snapshot: GameSnapshot) {
        guard let context = recordPanelContext(for: snapshot.mode) else {
            hasSavedFinishedRecord = false
            return
        }

        guard snapshot.isFinished else {
            hasSavedFinishedRecord = false
            return
        }

        guard !hasSavedFinishedRecord else { return }

        let insertedRecord: ModeRecord?
        switch snapshot.mode {
        case .free:
            insertedRecord = nil

        case .scoreAttack:
            insertedRecord = recordStore.addScoreAttackRecord(
                score: snapshot.score,
                elapsedTime: snapshot.elapsedTime,
                durationMinutes: context.detailValue
            )

        case .speedRun:
            insertedRecord = recordStore.addSpeedRunRecord(
                score: snapshot.score,
                elapsedTime: snapshot.elapsedTime,
                targetScore: context.detailValue
            )
        }

        hasSavedFinishedRecord = true

        if let insertedRecord {
            let topRecordID = recordStore.records(for: context.modeKey, detailValue: context.detailValue).first?.id
            if topRecordID == insertedRecord.id {
                latestRecordIDByMode[context.scopeID] = insertedRecord.id
            } else {
                latestRecordIDByMode.removeValue(forKey: context.scopeID)
            }
        }
    }

    private func updateRecordPanel(with snapshot: GameSnapshot) {
        guard let context = recordPanelContext(for: snapshot.mode) else {
            recordsCardView.isHidden = true
            recordsTitleLabel.stringValue = localized("panel.records")
            setRecordsText("")
            return
        }

        recordsCardView.isHidden = false
        recordsTitleLabel.stringValue = localized("panel.records")

        let records = recordStore.records(for: context.modeKey, detailValue: context.detailValue)
        guard !records.isEmpty else {
            setRecordsText(localized("records.empty"))
            return
        }

        let newestRecordID = latestRecordIDByMode[context.scopeID]
        setRecordRows(records, modeKey: context.modeKey, newestRecordID: newestRecordID)
    }

    private func setRecordRows(_ records: [ModeRecord], modeKey: ModeRecordKey, newestRecordID: String?) {
        let availableWidth = recordRowTabStopWidth()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: availableWidth, options: [:])]
        paragraphStyle.defaultTabInterval = availableWidth
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.minimumLineHeight = 24
        paragraphStyle.maximumLineHeight = 24
        // 记录项行间距缩减 50%，从 7 调整为 3.5。
        paragraphStyle.lineSpacing = 3.5

        let metricAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.94),
            .paragraphStyle: paragraphStyle
        ]
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.5),
            .paragraphStyle: paragraphStyle
        ]
        let newAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy),
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.88),
            .paragraphStyle: paragraphStyle
        ]

        let content = NSMutableAttributedString()
        for (index, record) in records.enumerated() {
            let row = NSMutableAttributedString()
            row.append(rankTagAttributedText(rank: index + 1))
            row.append(NSAttributedString(string: " "))
            row.append(NSAttributedString(string: recordMetricText(for: modeKey, record: record), attributes: metricAttributes))

            if record.id == newestRecordID {
                let marker = localized("records.new_suffix").trimmingCharacters(in: .whitespaces)
                row.append(NSAttributedString(string: " \(marker)", attributes: newAttributes))
            }

            row.append(NSAttributedString(string: "\t", attributes: metricAttributes))
            row.append(NSAttributedString(string: recordDateText(for: record), attributes: dateAttributes))
            row.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: row.length))
            content.append(row)

            if index < records.count - 1 {
                content.append(NSAttributedString(string: "\n"))
            }
        }

        setRecordsText(content)
    }

    private func rankTagAttributedText(rank: Int) -> NSAttributedString {
        let attachment = NSTextAttachment()
        let image = rankTagImage(rank: rank)
        attachment.image = image
        // 根据视觉反馈，将序号 Tag 整体向下平移 3px，避免与同行文本中线错位。
        attachment.bounds = NSRect(x: 0, y: -3, width: image.size.width, height: image.size.height)
        return NSAttributedString(attachment: attachment)
    }

    private func rankTagImage(rank: Int) -> NSImage {
        let text = String(rank)
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let horizontalInset: CGFloat = 6
        let verticalInset: CGFloat = 2
        let size = NSSize(
            width: ceil(textSize.width + horizontalInset * 2),
            height: ceil(textSize.height + verticalInset * 2)
        )

        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        NSColor(calibratedRed: 0.96, green: 0.56, blue: 0.18, alpha: 0.24).setFill()
        path.fill()
        NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.32, alpha: 0.85).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let drawAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.96),
            .paragraphStyle: paragraph
        ]
        let textRect = NSRect(
            x: 0,
            y: floor((size.height - textSize.height) / 2),
            width: size.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: drawAttributes)

        image.unlockFocus()
        return image
    }

    private func recordMetricText(for modeKey: ModeRecordKey, record: ModeRecord) -> String {
        switch modeKey {
        case .scoreAttack:
            return localizedFormat("records.metric.score", record.score)
        case .speedRun:
            return formatClock(record.elapsedTime)
        }
    }

    private func recordDateText(for record: ModeRecord) -> String {
        let formatter = DateFormatter()
        formatter.locale = localizer.locale
        formatter.dateFormat = localized("records.date_format")
        return formatter.string(from: Date(timeIntervalSince1970: record.createdAt))
    }

    private func recordPanelContext(for mode: GameMode) -> RecordPanelContext? {
        switch mode {
        case .free:
            return nil

        case .scoreAttack(let duration):
            let minutes = max(1, Int((duration / 60).rounded()))
            return RecordPanelContext(
                modeKey: .scoreAttack,
                detailValue: minutes
            )

        case .speedRun(let targetScore):
            let normalizedTarget = max(1, targetScore)
            return RecordPanelContext(
                modeKey: .speedRun,
                detailValue: normalizedTarget
            )
        }
    }

    private func setRecordsText(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: recordsThemeColor.withAlphaComponent(0.9)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        setRecordsText(attributed)
    }

    private func recordRowTabStopWidth() -> CGFloat {
        let insetWidth = recordsTextView.textContainerInset.width * 2
        let width = recordsScrollView.contentSize.width - insetWidth - 2
        return max(width, 180)
    }

    private func setRecordsText(_ attributed: NSAttributedString) {
        recordsTextView.textStorage?.setAttributedString(attributed)
        refreshRecordsTextLayout()
    }

    private func refreshRecordsTextLayout() {
        guard let textContainer = recordsTextView.textContainer,
              let layoutManager = recordsTextView.layoutManager else {
            return
        }

        let width = max(recordsScrollView.contentSize.width, 1)
        textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let requiredHeight = max(
            usedRect.height + recordsTextView.textContainerInset.height * 2,
            recordsScrollView.contentSize.height
        )

        recordsTextView.frame = NSRect(x: 0, y: 0, width: width, height: requiredHeight)
    }

    private func formatClock(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func localized(_ key: String) -> String {
        return localizer.string(key)
    }

    private func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: localizer.locale, arguments: arguments)
    }

    private func makeControlTitleLabel(color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.alignment = .right
        label.textColor = color
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSectionTitleLabel(color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.alignment = .left
        label.textColor = color
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSectionIconView(symbolName: String, color: NSColor) -> NSImageView {
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = color.withAlphaComponent(0.95)

        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            iconView.image = symbol.withSymbolConfiguration(config)
        } else if let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            iconView.image = fallback.withSymbolConfiguration(config)
        }

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14)
        ])
        return iconView
    }

    private func makeSectionHeaderStack(iconView: NSImageView, titleLabel: NSTextField) -> NSStackView {
        let stack = NSStackView(views: [iconView, titleLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
}

private final class ArcadeStageView: NSView {
    private var animationTick: CGFloat = 0
    private var animationTimer: Timer?

    override var isFlipped: Bool {
        return true
    }

    deinit {
        animationTimer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            animationTimer?.invalidate()
            animationTimer = nil
            return
        }

        guard animationTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationTick += 1
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let baseGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.1, blue: 0.16, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1)
        ])
        baseGradient?.draw(in: bounds, angle: -90)

        drawGlow(at: CGPoint(x: bounds.maxX * 0.16, y: bounds.maxY * 0.2), radius: 220, color: NSColor.systemBlue.withAlphaComponent(0.16))
        drawGlow(at: CGPoint(x: bounds.maxX * 0.78, y: bounds.maxY * 0.72), radius: 260, color: NSColor.systemPurple.withAlphaComponent(0.12))

        drawScanlines(in: bounds)
        drawPixelMatrix(in: bounds)
    }

    private func drawGlow(at center: CGPoint, radius: CGFloat, color: NSColor) {
        let glowRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = NSBezierPath(ovalIn: glowRect)
        color.setFill()
        path.fill()
    }

    private func drawScanlines(in rect: CGRect) {
        let path = NSBezierPath()
        let alpha = 0.04 + CGFloat((sin(Double(animationTick) * 0.07) + 1) * 0.01)
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            y += 4
        }
        NSColor.white.withAlphaComponent(alpha).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawPixelMatrix(in rect: CGRect) {
        let step: CGFloat = 18
        let size: CGFloat = 2

        var x = rect.minX + 8
        while x < rect.maxX {
            var y = rect.minY + 8
            while y < rect.maxY {
                let wave = CGFloat(sin((Double(x + y) / 80.0) + Double(animationTick) * 0.05))
                let alpha = 0.03 + max(0, wave) * 0.05
                let dotRect = CGRect(x: x, y: y, width: size, height: size)
                NSColor.white.withAlphaComponent(alpha).setFill()
                NSBezierPath(rect: dotRect).fill()
                y += step
            }
            x += step
        }
    }
}

private final class PixelFrameCardView: NSView {
    private let accentColor: NSColor

    init(accentColor: NSColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let rounded = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)

        NSColor(calibratedRed: 0.1, green: 0.12, blue: 0.17, alpha: 0.93).setFill()
        rounded.fill()

        accentColor.withAlphaComponent(0.48).setStroke()
        rounded.lineWidth = 1
        rounded.stroke()

        let innerRect = cardRect.insetBy(dx: 8, dy: 8)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 6, yRadius: 6)
        NSColor.white.withAlphaComponent(0.05).setStroke()
        innerPath.lineWidth = 1
        innerPath.stroke()

        drawCornerPixel(at: CGPoint(x: cardRect.minX + 7, y: cardRect.minY + 7), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 11, y: cardRect.minY + 7), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.minX + 7, y: cardRect.maxY - 11), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 11, y: cardRect.maxY - 11), color: accentColor)
    }

    private func drawCornerPixel(at origin: CGPoint, color: NSColor) {
        let rect = CGRect(x: origin.x, y: origin.y, width: 4, height: 4)
        color.withAlphaComponent(0.9).setFill()
        NSBezierPath(rect: rect).fill()
    }
}

private final class PixelDividerView: NSView {
    private var phase: CGFloat = 0
    private var timer: Timer?

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 10)
    }

    deinit {
        timer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            timer?.invalidate()
            timer = nil
            return
        }

        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.35
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let baseline = bounds.midY
        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: baseline))
        path.line(to: CGPoint(x: bounds.maxX, y: baseline))
        NSColor.white.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 1
        path.stroke()

        let segmentWidth: CGFloat = 9
        let segmentGap: CGFloat = 5
        var x = bounds.minX
        var index = 0

        while x < bounds.maxX {
            let wave = CGFloat(sin(Double(index) * 0.65 + Double(phase)))
            let alpha = 0.16 + max(0, wave) * 0.48
            let rect = CGRect(x: x, y: baseline - 2, width: segmentWidth, height: 4)
            NSColor.systemTeal.withAlphaComponent(alpha).setFill()
            NSBezierPath(rect: rect).fill()
            x += segmentWidth + segmentGap
            index += 1
        }
    }
}

private enum ArcadeControlStyle {
    static let borderWidth: CGFloat = 1.1
    static let cornerRadius: CGFloat = 7
}

private final class ArcadePopupButton: NSPopUpButton {
    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false
    private var hasConfigured = false
    private var chevronImageView: NSImageView?

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.height = max(38, size.height + 12)
        return size
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateTitleStyle()
            updateAppearance()
        }
    }

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        configureIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureIfNeeded()
    }

    override func addItems(withTitles itemTitles: [String]) {
        super.addItems(withTitles: itemTitles)
        updateTitleStyle()
        updateMenuAppearance()
    }

    override func removeAllItems() {
        super.removeAllItems()
        updateTitleStyle()
        updateMenuAppearance()
    }

    override func selectItem(at index: Int) {
        super.selectItem(at: index)
        updateTitleStyle()
    }

    override func synchronizeTitleAndSelectedItem() {
        super.synchronizeTitleAndSelectedItem()
        updateTitleStyle()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        updateAppearance()
    }

    private func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true

        wantsLayer = true
        isBordered = false
        focusRingType = .none
        contentTintColor = NSColor(calibratedRed: 0.8, green: 0.91, blue: 1.0, alpha: 0.96)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)

        if let popupCell = cell as? NSPopUpButtonCell {
            popupCell.arrowPosition = .noArrow
        }

        configureChevronIfNeeded()
        updateTitleStyle()
        updateMenuAppearance()
        updateAppearance()
    }

    private func updateTitleStyle() {
        let title = selectedItem?.title ?? ""
        let color = isEnabled
            ? NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.96)
            : NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.42)
        attributedTitle = NSAttributedString(
            string: "    \(title)    ",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: color,
                .kern: 0.22
            ]
        )
    }

    private func updateMenuAppearance() {
        guard let menu else { return }
        menu.appearance = NSAppearance(named: .darkAqua)
    }

    private func updateAppearance() {
        guard let layer else { return }

        let background: NSColor
        let border: NSColor

        if !isEnabled {
            background = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 0.8)
            border = NSColor(calibratedRed: 0.32, green: 0.32, blue: 0.32, alpha: 0.8)
        } else if isHighlighted {
            background = NSColor(calibratedRed: 0.09, green: 0.3, blue: 0.58, alpha: 0.96)
            border = NSColor(calibratedRed: 0.4, green: 0.72, blue: 1.0, alpha: 0.95)
        } else if isHovering {
            background = NSColor(calibratedRed: 0.1, green: 0.24, blue: 0.42, alpha: 0.94)
            border = NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.94, alpha: 0.9)
        } else {
            background = NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.31, alpha: 0.9)
            border = NSColor(calibratedRed: 0.3, green: 0.53, blue: 0.8, alpha: 0.84)
        }

        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = ArcadeControlStyle.borderWidth
        layer.cornerRadius = ArcadeControlStyle.cornerRadius
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
        layer.shadowRadius = isHovering ? 5 : 3
        layer.shadowOpacity = isEnabled ? 0.28 : 0
        layer.shadowOffset = .zero

        updateChevronTint()
    }

    private func configureChevronIfNeeded() {
        guard chevronImageView == nil else { return }

        let chevron = NSImageView()
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.imageScaling = .scaleProportionallyDown
        if let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            chevron.image = image.withSymbolConfiguration(config)
        }

        addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 11),
            chevron.heightAnchor.constraint(equalToConstant: 11)
        ])

        chevronImageView = chevron
        updateChevronTint()
    }

    private func updateChevronTint() {
        let tint: NSColor
        if !isEnabled {
            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.36)
        } else if isHighlighted {
            tint = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 0.92)
        } else {
            tint = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1.0, alpha: 0.74)
        }

        chevronImageView?.contentTintColor = tint
    }
}

private final class ArcadeActionButton: NSButton {
    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false
    private var displayTitle = ""
    private var displayImage: NSImage?

    private lazy var iconView: NSImageView = {
        let view = NSImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageScaling = .scaleProportionallyDown
        return view
    }()

    private lazy var textLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var contentStack: NSStackView = {
        let stack = NSStackView(views: [iconView, textLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        return stack
    }()

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateTitleStyle()
            updateAppearance()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func setDisplay(title: String, image: NSImage?) {
        displayTitle = title
        displayImage = image
        updateTitleStyle()
    }

    private func commonInit() {
        wantsLayer = true
        isBordered = false
        focusRingType = .none
        imagePosition = .noImage
        alignment = .center
        contentTintColor = NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setButtonType(.momentaryPushIn)

        super.title = ""
        super.image = nil

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14)
        ])

        updateTitleStyle()
        updateAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        updateAppearance()
    }

    private func updateTitleStyle() {
        let color = isEnabled
            ? NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.96)
            : NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.86, alpha: 0.45)
        textLabel.stringValue = displayTitle
        textLabel.textColor = color
        textLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)

        iconView.image = displayImage
        iconView.contentTintColor = color
        iconView.isHidden = displayImage == nil
        contentStack.spacing = displayImage == nil ? 0 : 6
    }

    private func updateAppearance() {
        guard let layer else { return }

        let background: NSColor
        let border: NSColor

        if !isEnabled {
            background = NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.18, alpha: 0.85)
            border = NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        } else if isHighlighted {
            background = NSColor(calibratedRed: 0.09, green: 0.47, blue: 0.2, alpha: 0.98)
            border = NSColor(calibratedRed: 0.5, green: 0.92, blue: 0.54, alpha: 0.95)
        } else if isHovering {
            background = NSColor(calibratedRed: 0.12, green: 0.39, blue: 0.18, alpha: 0.95)
            border = NSColor(calibratedRed: 0.46, green: 0.86, blue: 0.5, alpha: 0.9)
        } else {
            background = NSColor(calibratedRed: 0.1, green: 0.28, blue: 0.15, alpha: 0.92)
            border = NSColor(calibratedRed: 0.34, green: 0.72, blue: 0.4, alpha: 0.82)
        }

        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = ArcadeControlStyle.borderWidth
        layer.cornerRadius = ArcadeControlStyle.cornerRadius
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
        layer.shadowRadius = isHovering ? 5 : 3
        layer.shadowOpacity = isEnabled ? 0.28 : 0
        layer.shadowOffset = .zero
    }
}

private final class PixelBannerView: NSView {
    private var animationTick: CGFloat = 0
    private var animationTimer: Timer?

    override var isFlipped: Bool {
        return true
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 88)
    }

    deinit {
        animationTimer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            animationTimer?.invalidate()
            animationTimer = nil
            return
        }

        guard animationTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationTick += 1
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let outerRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 0.08, green: 0.1, blue: 0.14, alpha: 1).setFill()
        outerPath.fill()

        NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.62, alpha: 0.52).setStroke()
        outerPath.lineWidth = 1
        outerPath.stroke()

        let boardRect = outerRect.insetBy(dx: 12, dy: 12)
        NSColor.black.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: boardRect, xRadius: 6, yRadius: 6).fill()

        drawGrid(in: boardRect)
        drawTetrominoes(in: boardRect)
    }

    private func drawGrid(in rect: CGRect) {
        let pulse = 0.06 + CGFloat((sin(Double(animationTick) * 0.08) + 1) * 0.025)
        let lineColor = NSColor.white.withAlphaComponent(pulse)
        let step: CGFloat = 9
        let path = NSBezierPath()

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }

        lineColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawTetrominoes(in rect: CGRect) {
        let kinds = PieceKind.allCases
        guard !kinds.isEmpty else { return }

        let slotWidth = rect.width / CGFloat(kinds.count)
        let baseBlockSize = max(7, min(10, floor((rect.height - 14) / 4)))

        for (index, kind) in kinds.enumerated() {
            let blocks = kind.blocks
            let minX = blocks.map { $0.x }.min() ?? 0
            let maxX = blocks.map { $0.x }.max() ?? 0
            let minY = blocks.map { $0.y }.min() ?? 0
            let maxY = blocks.map { $0.y }.max() ?? 0

            let widthCells = maxX - minX + 1
            let heightCells = maxY - minY + 1

            let pieceWidth = CGFloat(widthCells) * baseBlockSize
            let pieceHeight = CGFloat(heightCells) * baseBlockSize

            let slotX = rect.minX + CGFloat(index) * slotWidth
            let wave = CGFloat(sin(Double(animationTick) * 0.12 + Double(index) * 0.7)) * 2.2
            let originX = slotX + (slotWidth - pieceWidth) * 0.5
            let originY = rect.minY + (rect.height - pieceHeight) * 0.5 + wave
            let glowPulse = CGFloat((sin(Double(animationTick) * 0.14 + Double(index)) + 1) * 0.5)

            drawPiece(
                kind,
                blocks: blocks,
                minX: minX,
                maxY: maxY,
                origin: CGPoint(x: originX, y: originY),
                blockSize: baseBlockSize,
                pulse: glowPulse
            )
        }
    }

    private func drawPiece(
        _ kind: PieceKind,
        blocks: [PieceBlock],
        minX: Int,
        maxY: Int,
        origin: CGPoint,
        blockSize: CGFloat,
        pulse: CGFloat
    ) {
        let fillColor = kind.color.blended(withFraction: 0.12 + pulse * 0.22, of: .white) ?? kind.color
        let borderColor = kind.color.shadow(withLevel: 0.35) ?? kind.color

        for block in blocks {
            let gridX = CGFloat(block.x - minX)
            let gridY = CGFloat(maxY - block.y)
            let pixelRect = CGRect(
                x: origin.x + gridX * blockSize,
                y: origin.y + gridY * blockSize,
                width: blockSize,
                height: blockSize
            ).integral

            let path = NSBezierPath(rect: pixelRect.insetBy(dx: 0.5, dy: 0.5))
            fillColor.setFill()
            path.fill()
            borderColor.setStroke()
            path.lineWidth = 1
            path.stroke()

            let shineRect = CGRect(
                x: pixelRect.minX + 1,
                y: pixelRect.minY + 1,
                width: max(1, blockSize / 4),
                height: max(1, blockSize / 4)
            ).integral
            NSColor.white.withAlphaComponent(0.25 + pulse * 0.2).setFill()
            NSBezierPath(rect: shineRect).fill()
        }
    }
}

extension NSTouchBarItem.Identifier {
    static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
}
