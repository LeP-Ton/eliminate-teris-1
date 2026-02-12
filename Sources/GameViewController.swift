import Cocoa

final class GameViewController: NSViewController, NSTouchBarDelegate {
    private enum ModeSelection: Int {
        case free = 0
        case scoreAttack = 1
        case speedRun = 2
    }

    private let localizer = Localizer.shared

    private let columns = 12
    private let scoreAttackMinutes = [1, 2, 3]
    private let speedRunTargets = [300, 600, 900]

    private lazy var controller = GameBoardController(columns: columns)
    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)

    private var observerToken: UUID?
    private var hudTimer: Timer?
    private var selectedScoreAttackIndex = 0
    private var selectedSpeedRunIndex = 0

    private lazy var languageTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var languagePopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(languageSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var modeTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var modePopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(modeSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var optionTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var optionPopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(optionSelectionChanged(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }()

    private lazy var startTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var startButton: NSButton = {
        let button = NSButton(title: "", target: self, action: #selector(startButtonTapped(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.imagePosition = .imageLeading
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var competitiveInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = NSColor.labelColor
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var resultLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var instructionsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var controlsStack: NSStackView = {
        let stack = NSStackView(views: [
            languageTitleLabel,
            languagePopup,
            modeTitleLabel,
            modePopup,
            optionTitleLabel,
            optionPopup,
            startTitleLabel,
            startButton
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
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
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 300))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view

        view.addSubview(controlsStack)
        view.addSubview(competitiveInfoLabel)
        view.addSubview(resultLabel)
        view.addSubview(instructionsLabel)

        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            controlsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            competitiveInfoLabel.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            competitiveInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            resultLabel.topAnchor.constraint(equalTo: competitiveInfoLabel.bottomAnchor, constant: 4),
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 24),
            instructionsLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
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
        updateWindowTitle()
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

        if resetGame {
            controller.configure(mode: gameMode(for: selection))
        }

        updateCompetitiveInfo()
    }

    private func configureLocalizedText() {
        configureLanguagePopup()

        languageTitleLabel.stringValue = localized("language.label")
        modeTitleLabel.stringValue = localized("mode.label")
        startTitleLabel.stringValue = localized("start.label")
        instructionsLabel.stringValue = localized("instructions.text")

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
        applyStartButtonAppearance(isRestart: false)
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
        switch selection {
        case .free:
            optionTitleLabel.isHidden = true
            optionPopup.isHidden = true

        case .scoreAttack:
            optionTitleLabel.isHidden = false
            optionPopup.isHidden = false
            optionTitleLabel.stringValue = localized("option.time")

            let titles = scoreAttackMinutes.map { localizedFormat("option.minute_format", $0) }
            optionPopup.removeAllItems()
            optionPopup.addItems(withTitles: titles)
            let clampedIndex = min(max(0, selectedScoreAttackIndex), titles.count - 1)
            optionPopup.selectItem(at: clampedIndex)
            selectedScoreAttackIndex = clampedIndex

        case .speedRun:
            optionTitleLabel.isHidden = false
            optionPopup.isHidden = false
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
        let isCompetitive = selection != .free
        startTitleLabel.isHidden = !isCompetitive
        startButton.isHidden = !isCompetitive
        startButton.isEnabled = isCompetitive
    }

    private func updateCompetitiveInfo() {
        let snapshot = controller.snapshot()
        syncHudTimer(with: snapshot)
        updateStartControl(for: snapshot)

        switch snapshot.mode {
        case .free:
            competitiveInfoLabel.isHidden = true
            resultLabel.isHidden = true
            resultLabel.stringValue = ""

        case .scoreAttack:
            competitiveInfoLabel.isHidden = false
            let remaining = formatClock(snapshot.remainingTime ?? 0)
            competitiveInfoLabel.stringValue = localizedFormat("hud.score_attack", snapshot.score, remaining)

            if snapshot.isFinished {
                resultLabel.isHidden = false
                resultLabel.stringValue = localizedFormat("result.score_attack_finished", snapshot.score)
            } else if !snapshot.isRunning {
                resultLabel.isHidden = false
                resultLabel.stringValue = localized("result.waiting_start")
            } else {
                resultLabel.isHidden = true
                resultLabel.stringValue = ""
            }

        case .speedRun:
            competitiveInfoLabel.isHidden = false
            let targetScore = snapshot.targetScore ?? 0
            let elapsed = formatClock(snapshot.elapsedTime)
            competitiveInfoLabel.stringValue = localizedFormat("hud.speed_run", snapshot.score, targetScore, elapsed)

            if snapshot.isFinished {
                resultLabel.isHidden = false
                resultLabel.stringValue = localizedFormat("result.speed_run_finished", elapsed)
            } else if !snapshot.isRunning {
                resultLabel.isHidden = false
                resultLabel.stringValue = localized("result.waiting_start")
            } else {
                resultLabel.isHidden = true
                resultLabel.stringValue = ""
            }
        }
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

        startButton.title = title
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            startButton.image = symbol
        } else {
            startButton.image = nil
        }
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
}

extension NSTouchBarItem.Identifier {
    static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
}
