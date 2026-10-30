import Cocoa
import ObjectiveC.runtime

final class GameViewController: NSViewController, NSTouchBarDelegate {
    private let columns = 16
    private let localizer = Localizer.shared
    private let recordStore: ModeRecordStore
    private let achievements: AchievementsManager
    private let audioEnabled: Bool
    private let controller: GameBoardController
    private var selection: HomeGameMode = .free
    private var hasConfiguredMode = false
    private var hasSavedFinishedRecord = false
    private let audioSystem = GameAudioSystem.shared
    private var observerToken: UUID?
    private var achievementsChangeObserver: NSObjectProtocol?
    private var achievementsUnlockObserver: NSObjectProtocol?
    private var achievementsPanel: AchievementsWindowController?
    private var utilityPanels: [String: HomeUtilityPanel] = [:]
    private var achievementToasts: AchievementToastPresenter?
    private var hudTimer: Timer?
    private lazy var dashboard = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
    private let touchBarSecondaryRefreshDelay: TimeInterval = 0.12
    private let touchBarTertiaryRefreshDelay: TimeInterval = 0.26
    private let touchBarHealthCheckDelay: TimeInterval = 0.18
    private let touchBarMaxReattachAttempts = 3
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

    init(achievements: AchievementsManager = .shared, records: ModeRecordStore = .shared,
         board: GameBoardController? = nil, audioEnabled: Bool = true) {
        self.achievements = achievements; self.recordStore = records; self.audioEnabled = audioEnabled
        self.controller = board ?? GameBoardController(columns: 16, achievements: achievements)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

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

    override func loadView() { view = dashboard }

    override func viewDidLoad() {
        super.viewDidLoad()
        dashboard.onStart = { [weak self] in self?.startRound() }
        dashboard.onMode = { [weak self] mode in self?.selectMode(mode) }
        dashboard.onNavigate = { [weak self] page in self?.presentUtility(page) }
        dashboard.onAchievement = { [weak self] id in self?.presentAchievements(detailID: id) }
        observerToken = controller.addObserver(owner: self) { [weak self] in self?.refresh() }
        achievementsChangeObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didChangeNotification, object: achievements, queue: .main) { [weak self] _ in self?.refreshAchievements() }
        achievementsUnlockObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: achievements, queue: .main) { [weak self] note in
            if let ids = note.userInfo?["ids"] as? [Int] { self?.achievementToasts?.enqueue(ids) }
        }
        achievementToasts = AchievementToastPresenter(host: view) { [weak self] ids in self?.presentAchievements(detailID: ids.count == 1 ? ids.first : nil) }
        selectMode(.free)
    }

    func selectMode(_ mode: HomeGameMode) {
        guard !hasConfiguredMode || mode != selection else { return }
        hasConfiguredMode = true
        selection = mode; hasSavedFinishedRecord = false
        controller.configure(mode: mode.gameMode)
        if audioEnabled { audioSystem.updateBackgroundMusic(for: mode.gameMode) }
        refresh()
        synchronizeSystemModalTouchBarPresentation(trigger: "modeSelectionChanged")
    }

    func startRound() {
        hasSavedFinishedRecord = false
        controller.startRound()
        refresh()
    }

    private func refreshAchievements() {
        dashboard.refresh(snapshot: controller.snapshot(), mode: selection, manager: achievements)
        if achievementsPanel?.window?.isVisible == true { achievementsPanel?.refresh() }
        achievementToasts?.refreshLanguage()
    }

    private func refresh() {
        let snapshot = controller.snapshot()
        dashboard.refresh(snapshot: snapshot, mode: selection, manager: achievements)
        if snapshot.isFinished, !hasSavedFinishedRecord {
            hasSavedFinishedRecord = true
            if snapshot.score > 0 {
                switch snapshot.mode {
                case .scoreAttack:
                    _ = recordStore.addScoreAttackRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, durationMinutes: 1)
                case .speedRun:
                    _ = recordStore.addSpeedRunRecord(score: snapshot.score, elapsedTime: snapshot.elapsedTime, targetScore: HomeGameMode.speedRunTarget)
                case .free: break
                }
            }
        }
        if snapshot.isRunning, selection != .free, !snapshot.isFinished {
            if hudTimer == nil {
                let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.controller.tick() }
                RunLoop.main.add(timer, forMode: .common); hudTimer = timer
            }
        } else { hudTimer?.invalidate(); hudTimer = nil }
        view.window?.title = localizer.string("window.title")
        for panel in utilityPanels.values where panel.window?.isVisible == true { panel.refresh(mode: selection, volume: audioSystem.masterVolume) }
    }

    private func presentAchievements(detailID: Int?) {
        if achievementsPanel == nil { achievementsPanel = AchievementsWindowController(manager: achievements) }
        achievementsPanel?.present(from: view.window, detailID: detailID)
    }

    private func presentUtility(_ page: String) {
        if utilityPanels[page] == nil {
            let panel = HomeUtilityPanel(page: page, store: recordStore)
            panel.onLanguage = { [weak self] language in
                self?.localizer.setLanguage(language)
                self?.refresh(); self?.refreshAchievements()
            }
            panel.onVolume = { [weak self] volume in self?.audioSystem.setMasterVolume(volume) }
            utilityPanels[page] = panel
        }
        utilityPanels[page]?.refresh(mode: selection, volume: audioSystem.masterVolume)
        utilityPanels[page]?.present(from: view.window)
    }

    deinit {
        if let observerToken { controller.removeObserver(observerToken) }
        for observer in [achievementsChangeObserver, achievementsUnlockObserver].compactMap({ $0 }) { NotificationCenter.default.removeObserver(observer) }
        achievementsPanel?.close(); utilityPanels.values.forEach { $0.close() }
        removeTouchBarLifecycleObservers()
        invalidateSystemModalTouchBarPresentation(reason: "deinit")
        hudTimer?.invalidate()
        if audioEnabled { audioSystem.stopBackgroundMusic() }
    }

    override func makeTouchBar() -> NSTouchBar? { nil }
    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window { installTouchBarLifecycleObservers(for: window) }
        synchronizeSystemModalTouchBarPresentation(trigger: "viewDidAppear")
        view.window?.makeFirstResponder(self)
        view.window?.contentMinSize = NSSize(width: 960, height: 720)
        refresh()
    }
    override func viewDidDisappear() {
        invalidateSystemModalTouchBarPresentation(reason: "viewDidDisappear")
        removeTouchBarLifecycleObservers()
        super.viewDidDisappear()
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

}

/// 辅助面板沿用首页的暖白背景，保留共用组件入口以减少主题分歧。
final class ArcadeStageView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.background.setFill()
        bounds.fill()
    }
}

/// 成就列表共用的轻量卡片，解锁状态通过边框颜色及图标共同表示。
final class PixelFrameCardView: NSView {
    private let accentColor: NSColor
    init(accentColor: NSColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.card(bounds, border: accentColor == HomeStyle.green ? HomeStyle.green.withAlphaComponent(0.5) : HomeStyle.border)
    }
}

final class PixelBannerView: NSView {
    private var animationTick: CGFloat = 0
    private var animationTimer: Timer?
    private var countTexts: [PieceKind: String] = [:]
    private var previousCounts: [PieceKind: Double] = [:]
    private var jumpStartedAt: [PieceKind: TimeInterval] = [:]
    private let animationClock: () -> TimeInterval

    init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.animationClock = clock
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    /// 数量增长时跳起并落回；使用单调时钟，避免系统时间调整干扰动画。
    func numberJumpOffset(for kind: PieceKind) -> CGFloat {
        guard let start = jumpStartedAt[kind] else { return 0 }
        let progress = (animationClock() - start) / 0.42
        guard progress >= 0, progress < 1 else { return 0 }
        return -6 * CGFloat(sin(progress * .pi))
    }

    /// 与成就共用累计数据源，语言切换时同步更新数字格式及辅助功能说明。
    func refresh(manager: AchievementsManager) {
        let formatter = NumberFormatter()
        formatter.locale = Localizer.shared.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        var descriptions: [String] = []
        let now = animationClock()
        for kind in PieceKind.allCases {
            let count = manager.totalCleared(for: kind)
            if let previous = previousCounts[kind], count > previous {
                jumpStartedAt[kind] = now
            } else if count < previousCounts[kind, default: 0] {
                jumpStartedAt.removeValue(forKey: kind)
            }
            // 首次加载与同值刷新仅恢复显示，不把历史数量误当作新消除。
            previousCounts[kind] = count
            let text = formatter.string(from: NSNumber(value: count)) ?? "0"
            countTexts[kind] = text
            descriptions.append(AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), text))
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(descriptions.joined(separator: "；"))
        needsDisplay = true
    }

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

        let titleRect = NSRect(x: outerRect.minX + 16, y: outerRect.minY + 10, width: max(0, outerRect.width - 32), height: 14)
        (AchievementText.string("banner.total_cleared") as NSString).draw(in: titleRect, withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: NSColor(calibratedRed: 0.7, green: 0.86, blue: 1, alpha: 0.96)
        ])
        let boardRect = NSRect(x: outerRect.minX + 12, y: outerRect.minY + 30,
                               width: max(0, outerRect.width - 24), height: max(0, outerRect.height - 42))
        NSColor.black.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: boardRect, xRadius: 6, yRadius: 6).fill()

        drawGrid(in: boardRect)
        drawTetrominoes(in: boardRect)
    }

    private func drawGrid(in rect: CGRect) {
        let pulse = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0.08 : 0.06 + CGFloat((sin(Double(animationTick) * 0.08) + 1) * 0.025)
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
        // 当前四种图案均为两行，为浮动和数字跳动预留上下空间。
        let baseBlockSize = max(7, min(10, floor((rect.height - 16) / 2)))
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

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
            let wave = reduceMotion ? 0 : CGFloat(sin(Double(animationTick) * 0.12 + Double(index) * 0.7)) * 2.2
            let count = countTexts[kind] ?? "0"
            let numberWidth = min(max(1, slotWidth - pieceWidth - 26),
                                  SevenSegmentNumberRenderer.width(for: count, height: pieceHeight))
            let originX = slotX + (slotWidth - pieceWidth - 10 - numberWidth) * 0.5
            // 图案与数字共用基础 Y 坐标，因此持续浮动的相位与振幅始终一致。
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
            let jump = reduceMotion ? 0 : numberJumpOffset(for: kind)
            let numberRect = NSRect(x: originX + pieceWidth + 10, y: originY + jump,
                                    width: numberWidth, height: pieceHeight)
            let color = kind.color.blended(withFraction: 0.4, of: .white) ?? kind.color
            SevenSegmentNumberRenderer.draw(count, in: numberRect, color: color)
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
