import Cocoa
import ObjectiveC.runtime

private enum CyberpunkPalette {
    // 统一的赛博朋克基础色板，优先用“深底 + 霓虹描边 + 高亮扫描”。
    static let abyss = NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.06, alpha: 1)
    static let midnight = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.14, alpha: 1)
    static let ultraviolet = NSColor(calibratedRed: 0.12, green: 0.05, blue: 0.16, alpha: 1)
    static let panelBase = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 0.95)
    static let panelOverlay = NSColor(calibratedRed: 0.1, green: 0.08, blue: 0.14, alpha: 0.86)
    static let neonYellow = NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.01, alpha: 1)
    static let neonCyan = NSColor(calibratedRed: 0.18, green: 0.9, blue: 1.0, alpha: 1)
    static let neonMagenta = NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.69, alpha: 1)
    static let neonGreen = NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.29, alpha: 1)
    static let neonRed = NSColor(calibratedRed: 1.0, green: 0.19, blue: 0.34, alpha: 1)
    static let textPrimary = NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.42, alpha: 0.98)
    static let textSecondary = NSColor(calibratedRed: 0.58, green: 0.95, blue: 1.0, alpha: 0.82)
    static let textMuted = NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.96, alpha: 0.58)
}

private func makeCyberpunkPanelPath(in rect: CGRect, cut: CGFloat = 18, lowerInset: CGFloat = 70, lowerStep: CGFloat = 12) -> NSBezierPath {
    let path = NSBezierPath()
    let safeLowerInset = min(max(lowerInset, cut + 18), max(rect.width - 28, cut + 18))

    path.move(to: CGPoint(x: rect.minX, y: rect.minY + cut))
    path.line(to: CGPoint(x: rect.minX + cut, y: rect.minY))
    path.line(to: CGPoint(x: rect.maxX - cut * 2.2, y: rect.minY))
    path.line(to: CGPoint(x: rect.maxX - cut, y: rect.minY + cut))
    path.line(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
    path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - lowerStep))
    path.line(to: CGPoint(x: rect.maxX - lowerStep, y: rect.maxY))
    path.line(to: CGPoint(x: rect.minX + safeLowerInset, y: rect.maxY))
    path.line(to: CGPoint(x: rect.minX + safeLowerInset - 14, y: rect.maxY - lowerStep))
    path.line(to: CGPoint(x: rect.minX, y: rect.maxY - lowerStep))
    path.close()
    return path
}

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
        case volume = 3
        case action = 4
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
    private let settingsThemeColor = CyberpunkPalette.neonYellow
    private let statusThemeColor = CyberpunkPalette.neonCyan
    private let recordsThemeColor = CyberpunkPalette.neonMagenta
    private let rulesThemeColor = CyberpunkPalette.neonRed
    private let rulesBodyThemeColor = CyberpunkPalette.textPrimary.withAlphaComponent(0.92)

    private let columns = 16
    private let scoreAttackMinutes = [1, 2, 3]
    private let speedRunTargets = [300, 600, 900]
    private let recordStore = ModeRecordStore.shared
    private let audioSystem = GameAudioSystem.shared
    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
    private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
    private let touchBarHealthCheckDelay: TimeInterval = 0.18
    private let touchBarMaxReattachAttempts = 3

    private lazy var controller = GameBoardController(columns: columns)
    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)

    private var observerToken: UUID?
    private var isPresentingSystemModalTouchBar = false
    private var touchBarPresentationGeneration = 0
    private var touchBarInitialRefreshWorkItem: DispatchWorkItem?
    private var touchBarSecondaryRefreshWorkItem: DispatchWorkItem?
    private var touchBarTertiaryRefreshWorkItem: DispatchWorkItem?
    private var touchBarHealthCheckWorkItem: DispatchWorkItem?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var appDidResignActiveObserver: NSObjectProtocol?
    private var windowDidBecomeKeyObserver: NSObjectProtocol?
    private var windowDidResignKeyObserver: NSObjectProtocol?
    private weak var observedTouchBarWindow: NSWindow?
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
        imageView.contentTintColor = CyberpunkPalette.neonYellow
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .heavy)
        imageView.imageScaling = .scaleProportionallyDown
        return imageView
    }()

    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .heavy)
        label.textColor = CyberpunkPalette.textPrimary
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = CyberpunkPalette.textSecondary
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

    private lazy var languagePopup: ArcadeCustomPopupButton = {
        let popup = ArcadeCustomPopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(languageSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var modeTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var modePopup: ArcadeCustomPopupButton = {
        let popup = ArcadeCustomPopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(modeSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var optionTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var optionPopup: ArcadeCustomPopupButton = {
        let popup = ArcadeCustomPopupButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(optionSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var startTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var volumeTitleLabel: NSTextField = {
        return makeControlTitleLabel(color: settingsThemeColor.withAlphaComponent(0.92))
    }()

    private lazy var volumeControlView: ArcadeVolumeControlView = {
        let view = ArcadeVolumeControlView(themeColor: settingsThemeColor)
        view.slider.target = self
        view.slider.action = #selector(volumeSliderChanged(_:))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
            [volumeTitleLabel, volumeControlView],
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
        label.textColor = CyberpunkPalette.neonCyan
        label.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .heavy)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var resultLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: "")
        label.alignment = .left
        label.textColor = CyberpunkPalette.textMuted
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
        return PixelFrameCardView(accentColor: CyberpunkPalette.neonRed)
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
        // 用 0 宽占位替换 ESC，保持左侧不显示系统 ESC 键。
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
            volumeControlView.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
            volumeControlView.heightAnchor.constraint(equalToConstant: 38),
            startButton.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),
            startButton.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            startButton.heightAnchor.constraint(equalToConstant: 38),

            languageTitleLabel.centerYAnchor.constraint(equalTo: languagePopup.centerYAnchor),
            modeTitleLabel.centerYAnchor.constraint(equalTo: modePopup.centerYAnchor),
            optionTitleLabel.centerYAnchor.constraint(equalTo: optionPopup.centerYAnchor),
            volumeTitleLabel.centerYAnchor.constraint(equalTo: volumeControlView.centerYAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureLocalizedText()

        observerToken = controller.addObserver(owner: self) { [weak self] in
            self?.updateCompetitiveInfo()
        }

        syncVolumeControlFromAudioSystem()
        modePopup.selectItem(at: ModeSelection.free.rawValue)
        applyModeSelection(resetGame: true)
    }

    deinit {
        if let observerToken {
            controller.removeObserver(observerToken)
        }
        removeTouchBarLifecycleObservers()
        invalidateSystemModalTouchBarPresentation(reason: "deinit")
        hudTimer?.invalidate()
        audioSystem.stopBackgroundMusic()
    }

    override func makeTouchBar() -> NSTouchBar? {
        // 当前正式方案固定使用私有 modal；不再通过公开 responder 链路提供游戏 Touch Bar。
        return nil
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            installTouchBarLifecycleObservers(for: window)
        }
        // 当前正式方案固定使用私有 modal，目标是尽量隐藏右侧常驻系统功能栏并占满 Touch Bar。
        logTouchBarDiagnostics("viewDidAppear，windowExists=\(view.window != nil)")
        synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
        view.window?.makeFirstResponder(self)
        view.window?.minSize = NSSize(width: 720, height: 450)
        updateWindowTitle()
    }

    override func viewDidDisappear() {
        logTouchBarDiagnostics("viewDidDisappear，开始失效私有 modal Touch Bar")
        invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
        removeTouchBarLifecycleObservers()
        super.viewDidDisappear()
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
                placeholder.heightAnchor.constraint(equalToConstant: gameTouchBarView.intrinsicContentSize.height)
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

    private func installTouchBarLifecycleObservers(for window: NSWindow) {
        let notificationCenter = NotificationCenter.default

        if appDidBecomeActiveObserver == nil {
            appDidBecomeActiveObserver = notificationCenter.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidBecomeActive()
            }
        }

        if appDidResignActiveObserver == nil {
            appDidResignActiveObserver = notificationCenter.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidResignActive()
            }
        }

        guard observedTouchBarWindow !== window else { return }
        removeWindowTouchBarLifecycleObservers()
        observedTouchBarWindow = window

        windowDidBecomeKeyObserver = notificationCenter.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handleWindowDidBecomeKey()
        }

        windowDidResignKeyObserver = notificationCenter.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handleWindowDidResignKey()
        }
    }

    private func removeTouchBarLifecycleObservers() {
        let notificationCenter = NotificationCenter.default

        if let appDidBecomeActiveObserver {
            notificationCenter.removeObserver(appDidBecomeActiveObserver)
            self.appDidBecomeActiveObserver = nil
        }

        if let appDidResignActiveObserver {
            notificationCenter.removeObserver(appDidResignActiveObserver)
            self.appDidResignActiveObserver = nil
        }

        removeWindowTouchBarLifecycleObservers()
    }

    private func removeWindowTouchBarLifecycleObservers() {
        let notificationCenter = NotificationCenter.default

        if let windowDidBecomeKeyObserver {
            notificationCenter.removeObserver(windowDidBecomeKeyObserver)
            self.windowDidBecomeKeyObserver = nil
        }

        if let windowDidResignKeyObserver {
            notificationCenter.removeObserver(windowDidResignKeyObserver)
            self.windowDidResignKeyObserver = nil
        }

        observedTouchBarWindow = nil
    }

    private func handleApplicationDidBecomeActive() {
        logTouchBarDiagnostics("应用重新激活，准备恢复私有 modal Touch Bar")
        synchronizeSystemModalTouchBarPresentation(trigger: "applicationDidBecomeActive")
    }

    private func handleApplicationDidResignActive() {
        logTouchBarDiagnostics("应用失活，准备关闭私有 modal Touch Bar")
        invalidateSystemModalTouchBarPresentation(reason: "applicationDidResignActive")
    }

    private func handleWindowDidBecomeKey() {
        logTouchBarDiagnostics("窗口重新成为 key，准备恢复私有 modal Touch Bar")
        synchronizeSystemModalTouchBarPresentation(trigger: "windowDidBecomeKey")
    }

    private func handleWindowDidResignKey() {
        logTouchBarDiagnostics("窗口失去 key，准备关闭私有 modal Touch Bar")
        invalidateSystemModalTouchBarPresentation(reason: "windowDidResignKey")
    }

    private var shouldPresentSystemModalTouchBar: Bool {
        guard isViewLoaded, let window = view.window else { return false }
        guard NSApp.isActive else { return false }
        guard window.isVisible, window.isKeyWindow else { return false }
        guard !window.isMiniaturized else { return false }
        return true
    }

    private func synchronizeSystemModalTouchBarPresentation(trigger: String) {
        guard shouldPresentSystemModalTouchBar else {
            logTouchBarDiagnostics("跳过私有 modal 挂载，trigger=\(trigger)，reason=窗口或应用当前不可展示")
            invalidateSystemModalTouchBarPresentation(reason: "\(trigger)-not-eligible", shouldAdvanceGeneration: false)
            return
        }

        if isPresentingSystemModalTouchBar {
            refreshPresentedSystemModalTouchBar(trigger: trigger)
        } else {
            beginSystemModalTouchBarPresentation(trigger: trigger, attempt: 0)
        }
    }

    private func beginSystemModalTouchBarPresentation(trigger: String, attempt: Int) {
        guard shouldPresentSystemModalTouchBar else {
            logTouchBarDiagnostics("放弃私有 modal 挂载，trigger=\(trigger)，attempt=\(attempt)，reason=展示条件不满足")
            return
        }

        touchBarPresentationGeneration += 1
        let generation = touchBarPresentationGeneration
        cancelTouchBarRefreshWorkItems()
        view.window?.touchBar = nil

        guard presentSystemModalTouchBarIfPossible() else {
            logTouchBarDiagnostics("私有 modal 挂载失败，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)")
            return
        }

        logTouchBarDiagnostics("已展示私有 modal Touch Bar，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)")
        scheduleSystemModalDisplayRefreshes(
            for: generation,
            attempt: attempt,
            trigger: trigger,
            includeHealthCheck: true
        )
    }

    private func refreshPresentedSystemModalTouchBar(trigger: String) {
        guard shouldPresentSystemModalTouchBar else {
            logTouchBarDiagnostics("私有 modal 已展示但当前不应继续保留，trigger=\(trigger)")
            invalidateSystemModalTouchBarPresentation(reason: "\(trigger)-refresh-not-eligible")
            return
        }

        touchBarPresentationGeneration += 1
        let generation = touchBarPresentationGeneration
        cancelTouchBarRefreshWorkItems()
        view.window?.touchBar = nil
        logTouchBarDiagnostics("刷新已展示的私有 modal Touch Bar，trigger=\(trigger)，generation=\(generation)")
        scheduleSystemModalDisplayRefreshes(
            for: generation,
            attempt: 0,
            trigger: trigger,
            includeHealthCheck: false
        )
    }

    private func scheduleSystemModalDisplayRefreshes(
        for generation: Int,
        attempt: Int,
        trigger: String,
        includeHealthCheck: Bool
    ) {
        let initialRefresh = DispatchWorkItem { [weak self] in
            guard let self, self.touchBarPresentationGeneration == generation else { return }
            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
            self.logTouchBarDiagnostics(
                "私有 modal 首次异步刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
            )
        }
        touchBarInitialRefreshWorkItem = initialRefresh
        DispatchQueue.main.async(execute: initialRefresh)

        let secondaryRefresh = DispatchWorkItem { [weak self] in
            guard let self, self.touchBarPresentationGeneration == generation else { return }
            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
            self.logTouchBarDiagnostics(
                "私有 modal 二次刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
            )
        }
        touchBarSecondaryRefreshWorkItem = secondaryRefresh
        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarSecondaryRefreshDelay, execute: secondaryRefresh)

        let tertiaryRefresh = DispatchWorkItem { [weak self] in
            guard let self, self.touchBarPresentationGeneration == generation else { return }
            let displayGeneration = self.gameTouchBarView.prepareForDisplay()
            self.logTouchBarDiagnostics(
                "私有 modal 三次刷新，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，displayGeneration=\(displayGeneration)，bounds=\(TouchBarDiagnostics.describe(rect: self.gameTouchBarView.bounds))"
            )
        }
        touchBarTertiaryRefreshWorkItem = tertiaryRefresh
        DispatchQueue.main.asyncAfter(deadline: .now() + touchBarTertiaryRefreshDelay, execute: tertiaryRefresh)

        if includeHealthCheck {
            let healthCheck = DispatchWorkItem { [weak self] in
                guard let self, self.touchBarPresentationGeneration == generation else { return }
                guard self.isPresentingSystemModalTouchBar else { return }

                let bounds = self.gameTouchBarView.bounds
                let hasRenderableBounds = bounds.width > 1 && bounds.height > 1
                let hasVisibleContent = self.gameTouchBarView.hasDrawnVisibleContent

                self.logTouchBarDiagnostics(
                    "私有 modal 健康检查，trigger=\(trigger)，attempt=\(attempt)，presentationGeneration=\(generation)，bounds=\(TouchBarDiagnostics.describe(rect: bounds))，hasRenderableBounds=\(hasRenderableBounds)，hasVisibleContent=\(hasVisibleContent)，displayGeneration=\(self.gameTouchBarView.displayGeneration)"
                )

                guard hasRenderableBounds, hasVisibleContent else {
                    self.handleSystemModalHealthCheckFailure(trigger: trigger, attempt: attempt)
                    return
                }
            }
            touchBarHealthCheckWorkItem = healthCheck
            DispatchQueue.main.asyncAfter(deadline: .now() + touchBarHealthCheckDelay, execute: healthCheck)
        }

        logTouchBarDiagnostics(
            "已安排私有 modal 刷新序列，trigger=\(trigger)，attempt=\(attempt)，generation=\(generation)，secondaryDelay=\(touchBarSecondaryRefreshDelay)s，healthDelay=\(touchBarHealthCheckDelay)s，tertiaryDelay=\(touchBarTertiaryRefreshDelay)s"
        )
    }

    private func handleSystemModalHealthCheckFailure(trigger: String, attempt: Int) {
        cancelTouchBarRefreshWorkItems()

        if attempt < touchBarMaxReattachAttempts {
            let nextAttempt = attempt + 1
            logTouchBarDiagnostics("私有 modal 健康检查失败，准备重挂载，trigger=\(trigger)，currentAttempt=\(attempt)，nextAttempt=\(nextAttempt)")
            dismissSystemModalTouchBarIfNeeded(reason: "health-check-failed-attempt-\(attempt)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.beginSystemModalTouchBarPresentation(trigger: "\(trigger)-reattach", attempt: nextAttempt)
            }
            return
        }

        logTouchBarDiagnostics("私有 modal 已达到最大重挂载次数，停止自动重试，trigger=\(trigger)，finalAttempt=\(attempt)")
        dismissSystemModalTouchBarIfNeeded(reason: "health-check-final-failure")
    }

    private func presentSystemModalTouchBarIfPossible() -> Bool {
        guard isPresentingSystemModalTouchBar == false else { return true }

        let modernSelector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        if let modernMethod = class_getClassMethod(NSTouchBar.self, modernSelector) {
            typealias PresentModernModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
            let implementation = method_getImplementation(modernMethod)
            let function = unsafeBitCast(implementation, to: PresentModernModalTouchBar.self)
            function(NSTouchBar.self, modernSelector, gameTouchBar, nil)
            isPresentingSystemModalTouchBar = true
            logTouchBarDiagnostics("已通过现代私有 API 展示 system modal")
            return true
        }

        let fallbackSelector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        if let fallbackMethod = class_getClassMethod(NSTouchBar.self, fallbackSelector) {
            typealias PresentFallbackModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?, Int64, AnyObject?) -> Void
            let implementation = method_getImplementation(fallbackMethod)
            let function = unsafeBitCast(implementation, to: PresentFallbackModalTouchBar.self)
            function(NSTouchBar.self, fallbackSelector, gameTouchBar, 0, nil)
            isPresentingSystemModalTouchBar = true
            logTouchBarDiagnostics("已通过回退私有 API 展示 system modal")
            return true
        }

        logTouchBarDiagnostics("当前系统不支持私有 modal API，无法展示全宽 Touch Bar")
        return false
    }

    private func dismissSystemModalTouchBarIfNeeded(reason: String) {
        guard isPresentingSystemModalTouchBar else { return }

        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            isPresentingSystemModalTouchBar = false
            logTouchBarDiagnostics("私有 modal dismiss API 不可用，已重置展示状态，reason=\(reason)")
            return
        }

        typealias DismissModalTouchBar = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let implementation = method_getImplementation(method)
        let function = unsafeBitCast(implementation, to: DismissModalTouchBar.self)
        function(NSTouchBar.self, selector, gameTouchBar)
        isPresentingSystemModalTouchBar = false
        logTouchBarDiagnostics("已关闭私有 modal Touch Bar，reason=\(reason)")
    }

    private func invalidateSystemModalTouchBarPresentation(
        reason: String,
        shouldAdvanceGeneration: Bool = true
    ) {
        if shouldAdvanceGeneration {
            touchBarPresentationGeneration += 1
        }
        logTouchBarDiagnostics("失效私有 modal Touch Bar，reason=\(reason)，newGeneration=\(touchBarPresentationGeneration)")
        cancelTouchBarRefreshWorkItems()
        view.window?.touchBar = nil
        dismissSystemModalTouchBarIfNeeded(reason: reason)
    }

    private func cancelTouchBarRefreshWorkItems() {
        if touchBarInitialRefreshWorkItem != nil ||
            touchBarSecondaryRefreshWorkItem != nil ||
            touchBarTertiaryRefreshWorkItem != nil ||
            touchBarHealthCheckWorkItem != nil {
            logTouchBarDiagnostics("取消待执行的私有 modal 刷新与健康检查任务")
        }
        touchBarInitialRefreshWorkItem?.cancel()
        touchBarSecondaryRefreshWorkItem?.cancel()
        touchBarTertiaryRefreshWorkItem?.cancel()
        touchBarHealthCheckWorkItem?.cancel()
        touchBarInitialRefreshWorkItem = nil
        touchBarSecondaryRefreshWorkItem = nil
        touchBarTertiaryRefreshWorkItem = nil
        touchBarHealthCheckWorkItem = nil
    }

    private func logTouchBarDiagnostics(_ message: @autoclosure () -> String) {
        TouchBarDiagnostics.log(
            "GameViewController pg=\(touchBarPresentationGeneration) \(message())"
        )
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

    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        let volume = Float(sender.doubleValue)
        audioSystem.setMasterVolume(volume)
        updateVolumeControlDisplay(for: volume)
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
        let selectedMode = gameMode(for: selection)
        let windowFrameBeforeUpdate = view.window?.frame
        populateOptionPopup(for: selection)
        updateStartControlVisibility(for: selection)
        updateCardsLayout(for: selection)
        updateRulesDescription(for: selection)

        if resetGame {
            resetRuntimeIndicators()
            hasSavedFinishedRecord = false
            controller.configure(mode: selectedMode)
        }
        audioSystem.updateBackgroundMusic(for: selectedMode)

        updateCompetitiveInfo()
        preserveWindowFrame(windowFrameBeforeUpdate)
        refreshRecordPanelAfterLayoutIfNeeded()
        synchronizeSystemModalTouchBarPresentation(trigger: "modeSelectionChanged")
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
        volumeTitleLabel.stringValue = localized("volume.label")
        startTitleLabel.stringValue = ""
        syncVolumeControlFromAudioSystem()

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

    private func preserveWindowFrame(_ previousFrame: NSRect?) {
        guard let previousFrame,
              let window = view.window else {
            return
        }

        let shouldRestoreFrame =
            abs(window.frame.width - previousFrame.width) > 0.5 ||
            abs(window.frame.height - previousFrame.height) > 0.5

        guard shouldRestoreFrame else { return }
        window.setFrame(previousFrame, display: false, animate: false)
    }

    private func refreshRecordPanelAfterLayoutIfNeeded() {
        guard currentModeSelection != .free else { return }
        view.layoutSubtreeIfNeeded()
        updateRecordPanel(with: controller.snapshot())
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
            statusBadgeLabel.textColor = CyberpunkPalette.textPrimary
            statusBadgeLabel.layer?.backgroundColor = CyberpunkPalette.panelBase.withAlphaComponent(0.95).cgColor
            statusBadgeLabel.layer?.borderColor = CyberpunkPalette.neonCyan.withAlphaComponent(0.7).cgColor

        case .running:
            statusBadgeLabel.textColor = CyberpunkPalette.textPrimary
            statusBadgeLabel.layer?.backgroundColor = CyberpunkPalette.neonGreen.withAlphaComponent(0.18).cgColor
            statusBadgeLabel.layer?.borderColor = CyberpunkPalette.neonGreen.withAlphaComponent(0.92).cgColor

        case .combo:
            statusBadgeLabel.textColor = CyberpunkPalette.neonYellow
            statusBadgeLabel.layer?.backgroundColor = CyberpunkPalette.neonYellow.withAlphaComponent(0.12).cgColor
            statusBadgeLabel.layer?.borderColor = CyberpunkPalette.neonYellow.withAlphaComponent(0.95).cgColor

        case .finish:
            statusBadgeLabel.textColor = CyberpunkPalette.textPrimary
            statusBadgeLabel.layer?.backgroundColor = CyberpunkPalette.neonRed.withAlphaComponent(0.18).cgColor
            statusBadgeLabel.layer?.borderColor = CyberpunkPalette.neonRed.withAlphaComponent(0.95).cgColor
        }

        statusBadgeLabel.layer?.borderWidth = 1
        statusBadgeLabel.layer?.shadowColor = (statusBadgeLabel.layer?.borderColor ?? CyberpunkPalette.neonCyan.cgColor)
        statusBadgeLabel.layer?.shadowOpacity = 0.35
        statusBadgeLabel.layer?.shadowRadius = 8
        statusBadgeLabel.layer?.shadowOffset = .zero
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
            .foregroundColor: CyberpunkPalette.textPrimary
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
        let path = makeCyberpunkPanelPath(in: rect.insetBy(dx: 0.5, dy: 0.5), cut: 4, lowerInset: max(18, rect.width - 10), lowerStep: 4)
        recordsThemeColor.withAlphaComponent(0.16).setFill()
        path.fill()
        recordsThemeColor.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let drawAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CyberpunkPalette.textPrimary,
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

    private func syncVolumeControlFromAudioSystem() {
        updateVolumeControlDisplay(for: audioSystem.masterVolume)
    }

    private func updateVolumeControlDisplay(for volume: Float) {
        let clampedVolume = min(max(volume, 0), 1)
        let percentage = Int((clampedVolume * 100).rounded())
        volumeControlView.setVolume(Double(clampedVolume))
        volumeControlView.setDisplayText("\(percentage)%")
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
        label.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSectionTitleLabel(color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.alignment = .left
        label.textColor = color
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy)
        label.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = color.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = 6
            shadow.shadowOffset = .zero
            return shadow
        }()
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
        stack.spacing = 8
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
            CyberpunkPalette.abyss,
            CyberpunkPalette.midnight,
            CyberpunkPalette.ultraviolet
        ])
        baseGradient?.draw(in: bounds, angle: -90)

        drawGlow(at: CGPoint(x: bounds.maxX * 0.14, y: bounds.maxY * 0.18), radius: 250, color: CyberpunkPalette.neonMagenta.withAlphaComponent(0.16))
        drawGlow(at: CGPoint(x: bounds.maxX * 0.82, y: bounds.maxY * 0.68), radius: 280, color: CyberpunkPalette.neonCyan.withAlphaComponent(0.13))
        drawGlow(at: CGPoint(x: bounds.maxX * 0.54, y: bounds.maxY * 0.04), radius: 210, color: CyberpunkPalette.neonYellow.withAlphaComponent(0.08))

        drawScanlines(in: bounds)
        drawPixelMatrix(in: bounds)
        drawCircuitStripes(in: bounds)
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
        CyberpunkPalette.neonCyan.withAlphaComponent(alpha).setStroke()
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
                CyberpunkPalette.neonYellow.withAlphaComponent(alpha).setFill()
                NSBezierPath(rect: dotRect).fill()
                y += step
            }
            x += step
        }
    }

    private func drawCircuitStripes(in rect: CGRect) {
        let stripeColor = CyberpunkPalette.neonMagenta.withAlphaComponent(0.16)
        let guideColor = CyberpunkPalette.neonYellow.withAlphaComponent(0.12)

        let topPath = NSBezierPath()
        topPath.move(to: CGPoint(x: rect.minX + 36, y: rect.minY + 34))
        topPath.line(to: CGPoint(x: rect.minX + 220, y: rect.minY + 34))
        topPath.line(to: CGPoint(x: rect.minX + 250, y: rect.minY + 16))
        topPath.line(to: CGPoint(x: rect.maxX - 90, y: rect.minY + 16))
        stripeColor.setStroke()
        topPath.lineWidth = 2
        topPath.stroke()

        let bottomPath = NSBezierPath()
        bottomPath.move(to: CGPoint(x: rect.maxX - 40, y: rect.maxY - 36))
        bottomPath.line(to: CGPoint(x: rect.maxX - 240, y: rect.maxY - 36))
        bottomPath.line(to: CGPoint(x: rect.maxX - 280, y: rect.maxY - 18))
        bottomPath.line(to: CGPoint(x: rect.minX + 120, y: rect.maxY - 18))
        guideColor.setStroke()
        bottomPath.lineWidth = 2
        bottomPath.stroke()
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
        let outerPath = makeCyberpunkPanelPath(in: cardRect, cut: 18, lowerInset: 74, lowerStep: 12)
        let innerRect = cardRect.insetBy(dx: 7, dy: 7)
        let innerPath = makeCyberpunkPanelPath(in: innerRect, cut: 12, lowerInset: 62, lowerStep: 9)

        let fillGradient = NSGradient(colors: [
            CyberpunkPalette.panelBase,
            CyberpunkPalette.panelOverlay
        ])
        fillGradient?.draw(in: outerPath, angle: -90)

        outerPath.lineWidth = 1.4
        accentColor.withAlphaComponent(0.88).setStroke()
        outerPath.stroke()

        innerPath.lineWidth = 1
        accentColor.withAlphaComponent(0.2).setStroke()
        innerPath.stroke()

        drawTechEdgeMarkers(in: cardRect)
        drawCornerPixel(at: CGPoint(x: cardRect.minX + 10, y: cardRect.minY + 10), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 15, y: cardRect.minY + 10), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.minX + 10, y: cardRect.maxY - 15), color: accentColor)
        drawCornerPixel(at: CGPoint(x: cardRect.maxX - 15, y: cardRect.maxY - 15), color: accentColor)
    }

    private func drawTechEdgeMarkers(in rect: CGRect) {
        let markerColor = accentColor.withAlphaComponent(0.95)
        let subtleColor = CyberpunkPalette.neonYellow.withAlphaComponent(0.6)

        markerColor.setFill()
        NSBezierPath(rect: CGRect(x: rect.minX + 22, y: rect.minY + 6, width: 42, height: 3)).fill()
        subtleColor.setFill()
        NSBezierPath(rect: CGRect(x: rect.maxX - 78, y: rect.maxY - 8, width: 30, height: 2)).fill()
        NSBezierPath(rect: CGRect(x: rect.maxX - 42, y: rect.maxY - 8, width: 10, height: 2)).fill()
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
        CyberpunkPalette.neonMagenta.withAlphaComponent(0.22).setStroke()
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
            let color = index.isMultiple(of: 2)
                ? CyberpunkPalette.neonCyan.withAlphaComponent(alpha)
                : CyberpunkPalette.neonYellow.withAlphaComponent(alpha * 0.9)
            color.setFill()
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
        contentTintColor = CyberpunkPalette.textPrimary
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
            ? CyberpunkPalette.textPrimary
            : CyberpunkPalette.textPrimary.withAlphaComponent(0.42)
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
            background = CyberpunkPalette.panelBase.withAlphaComponent(0.72)
            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.18)
        } else if isHighlighted {
            background = CyberpunkPalette.neonMagenta.withAlphaComponent(0.28)
            border = CyberpunkPalette.neonYellow
        } else if isHovering {
            background = CyberpunkPalette.neonCyan.withAlphaComponent(0.18)
            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.92)
        } else {
            background = CyberpunkPalette.midnight.withAlphaComponent(0.92)
            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.78)
        }

        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = ArcadeControlStyle.borderWidth
        layer.cornerRadius = 0
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
        layer.shadowRadius = isHovering ? 8 : 5
        layer.shadowOpacity = isEnabled ? 0.38 : 0
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
            tint = CyberpunkPalette.textPrimary.withAlphaComponent(0.36)
        } else if isHighlighted {
            tint = CyberpunkPalette.neonYellow
        } else {
            tint = CyberpunkPalette.textPrimary.withAlphaComponent(0.82)
        }

        chevronImageView?.contentTintColor = tint
    }
}

private final class ArcadeVolumeControlView: NSView {
    private let themeColor: NSColor
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false

    let slider: NSSlider = {
        let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.isContinuous = true
        slider.controlSize = .small
        slider.allowsTickMarkValuesOnly = false
        slider.numberOfTickMarks = 0
        slider.focusRingType = .none
        return slider
    }()

    private lazy var valueLabel: NSTextField = {
        let label = NSTextField(labelWithString: "100%")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 38)
    }

    init(themeColor: NSColor) {
        self.themeColor = themeColor
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.themeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
        super.init(coder: coder)
        commonInit()
    }

    func setVolume(_ value: Double) {
        if abs(slider.doubleValue - value) > 0.0001 {
            slider.doubleValue = value
        }
    }

    func setDisplayText(_ text: String) {
        valueLabel.stringValue = text
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

    private func commonInit() {
        wantsLayer = true

        addSubview(slider)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 42)
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        guard let layer else { return }

        let background: NSColor
        let border: NSColor

        if isHovering {
            background = CyberpunkPalette.neonCyan.withAlphaComponent(0.16)
            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.92)
        } else {
            background = CyberpunkPalette.midnight.withAlphaComponent(0.92)
            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.76)
        }

        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = ArcadeControlStyle.borderWidth
        layer.cornerRadius = 0
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(0.72).cgColor
        layer.shadowRadius = isHovering ? 8 : 5
        layer.shadowOpacity = 0.34
        layer.shadowOffset = .zero

        valueLabel.textColor = CyberpunkPalette.textPrimary
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
        contentTintColor = CyberpunkPalette.textPrimary
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
            ? CyberpunkPalette.textPrimary
            : CyberpunkPalette.textPrimary.withAlphaComponent(0.45)
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
            background = CyberpunkPalette.panelBase.withAlphaComponent(0.8)
            border = CyberpunkPalette.neonYellow.withAlphaComponent(0.18)
        } else if isHighlighted {
            background = CyberpunkPalette.neonYellow.withAlphaComponent(0.26)
            border = CyberpunkPalette.neonYellow
        } else if isHovering {
            background = CyberpunkPalette.neonGreen.withAlphaComponent(0.18)
            border = CyberpunkPalette.neonGreen.withAlphaComponent(0.92)
        } else {
            background = CyberpunkPalette.panelOverlay.withAlphaComponent(0.92)
            border = CyberpunkPalette.neonGreen.withAlphaComponent(0.82)
        }

        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = ArcadeControlStyle.borderWidth
        layer.cornerRadius = 0
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(0.75).cgColor
        layer.shadowRadius = isHovering ? 8 : 5
        layer.shadowOpacity = isEnabled ? 0.38 : 0
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
        let outerPath = makeCyberpunkPanelPath(in: outerRect, cut: 20, lowerInset: 88, lowerStep: 14)
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.08, alpha: 1).setFill()
        outerPath.fill()

        CyberpunkPalette.neonCyan.withAlphaComponent(0.72).setStroke()
        outerPath.lineWidth = 1.2
        outerPath.stroke()

        let boardRect = outerRect.insetBy(dx: 12, dy: 12)
        CyberpunkPalette.panelBase.withAlphaComponent(0.86).setFill()
        makeCyberpunkPanelPath(in: boardRect, cut: 12, lowerInset: 70, lowerStep: 9).fill()

        drawGrid(in: boardRect)
        drawTetrominoes(in: boardRect)
        drawSignalLabel(in: outerRect)
    }

    private func drawGrid(in rect: CGRect) {
        let pulse = 0.06 + CGFloat((sin(Double(animationTick) * 0.08) + 1) * 0.025)
        let lineColor = CyberpunkPalette.neonCyan.withAlphaComponent(pulse * 1.3)
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

    private func drawSignalLabel(in rect: CGRect) {
        let text = "NEON GRID // READY"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .heavy),
            .foregroundColor: CyberpunkPalette.neonYellow.withAlphaComponent(0.96),
            .kern: 0.8
        ]
        let textRect = CGRect(x: rect.minX + 18, y: rect.maxY - 20, width: 180, height: 12)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}

extension NSTouchBarItem.Identifier {
    static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
}
