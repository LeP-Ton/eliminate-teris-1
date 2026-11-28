import Cocoa

/// 上方文案和本局统计并排排版，切换模式时交错叠合统计卡的前后两层。
final class HomeModeHeaderView: NSView {
    static let previewDuration: TimeInterval = 1.20
    static let budgetFillDuration: TimeInterval = 0.60
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private let intro = HomeModeIntroView(frame: .zero)
    let card = HomeChallengeHUDView(frame: .zero)
    private var timer: Timer?
    private var transitionStart: TimeInterval?
    private var isAssembling = false
    private var cardColumn = NSRect.zero

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(card)
        addSubview(intro)
    }

    required init?(coder: NSCoder) { nil }
    deinit { timer?.invalidate() }

    func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
        let topPadding = HomeChallengeHUDView.surfaceInsetY + 3 + HomeChallengeHUDView.assemblyTopSpace
        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth,
                       height: leftColumn.height + topPadding + HomeChallengeHUDView.assemblyBottomSpace)
        let headingWidth = (leftColumn.width * 0.361).rounded(.down)
        let gap = min(16, leftColumn.width * 0.025)
        intro.frame = NSRect(x: leftColumn.minX, y: topPadding, width: headingWidth, height: leftColumn.height)
        let cardTop = min(19, leftColumn.height * 0.079)
        let cardHeight = min(186, max(102, leftColumn.height * 0.77))
        let faceX = intro.frame.maxX + gap + HomeChallengeHUDView.trailingInset
        let faceRight = modePanelLeading - min(22, leftColumn.width * 0.031)
        let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX), height: cardHeight)
        cardColumn = NSRect(x: cardX, y: topPadding + cardTop - HomeChallengeHUDView.surfaceInsetY,
                            width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                            height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
        let changedMode = card.snapshot != nil && card.mode != mode
        card.refresh(snapshot: snapshot, mode: mode)
        intro.refresh(mode: mode)

        guard changedMode else { return }
        guard window != nil, cardColumn.width > 0, !reducesMotion() else {
            settle()
            return
        }
        // 每次换模式都从透明起步。已运行的定时器继续驱动新一轮叠合。
        transitionStart = nil
        if !isAssembling { card.positionPlates(in: cardColumn, assembling: true) }
        isAssembling = true
        card.plateAssembly = .separated
        card.budgetFillProgress = mode == .free ? 1 : 0
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func advanceAnimation() {
        guard timer != nil else { return }
        guard !reducesMotion() else {
            settle()
            return
        }
        let currentTime = now()
        // 首次切换可能还在同步准备模式资源。等主循环驱动首帧再计时。
        guard let transitionStart else {
            self.transitionStart = currentTime
            return
        }
        let elapsed = max(0, currentTime - transitionStart)
        if elapsed >= Self.previewDuration {
            let progress = (elapsed - Self.previewDuration) / Self.budgetFillDuration
            guard card.mode != .free, progress < 1 else {
                settle()
                return
            }
            finishAssembly()
            card.budgetFillProgress = CGFloat(progress)
            return
        }
        let time = CGFloat(elapsed / Self.previewDuration)
        let backingRemaining = 1 - min(1, time / 0.62)
        let frontTime = min(1, max(0, (time - 0.12) / 0.66))
        let opacity = min(1, time / 0.78)
        let highlight = max(0, (time - 0.78) / 0.22)
        card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining,
                                   front: frontTime * frontTime * (3 - 2 * frontTime),
                                   opacity: opacity,
                                   highlight: highlight)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { settle() }
    }

    override func layout() {
        super.layout()
        card.positionPlates(in: cardColumn, assembling: isAssembling)
    }

    private func finishAssembly() {
        guard isAssembling else { return }
        isAssembling = false
        card.plateAssembly = .settled
        card.positionPlates(in: cardColumn, assembling: false)
    }

    private func settle() {
        transitionStart = nil
        timer?.invalidate()
        timer = nil
        finishAssembly()
        card.budgetFillProgress = 1
    }
}

private final class HomeModeIntroView: NSView {
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let subtitle = NSTextField(wrappingLabelWithString: "")
    private var title = ""

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        subtitle.textColor = HomeDashboardStyle.muted
        addSubview(heading)
        addSubview(subtitle)
    }

    required init?(coder: NSCoder) { nil }

    func refresh(mode: HomeGameMode) {
        let newTitle = AchievementText.string("home.hero.\(mode.key)")
        let newSubtitle = AchievementText.string("home.subtitle.\(mode.key)")
        guard title != newTitle || subtitle.stringValue != newSubtitle else { return }
        title = newTitle
        subtitle.stringValue = newSubtitle
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let textWidth = max(1, bounds.width - 8)
        let headingY = min(10, bounds.height * 0.04)
        let headingMaxHeight = bounds.height * 0.68
        let lines = title.split(separator: "\n")
        var size = min(66, max(24, bounds.width * 0.21), bounds.height * 0.32)
        var font = NSFont.systemFont(ofSize: size, weight: .heavy)
        // 本地化后的两行标题需同时满足宽度和高度，以免副标题被挤出。
        while size > 17 {
            let maxWidth = lines.map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            if maxWidth <= textWidth, textHeight(title, width: textWidth, font: font) <= headingMaxHeight { break }
            size -= 1
            font = .systemFont(ofSize: size, weight: .heavy)
        }
        let styled = NSMutableAttributedString(string: title, attributes: HomeDashboardStyle.textAttributes(font: font))
        let divider = (title as NSString).range(of: "\n")
        if divider.location != NSNotFound {
            let start = NSMaxRange(divider)
            styled.addAttribute(.foregroundColor, value: HomeDashboardStyle.yellow, range: NSRange(location: start, length: styled.length - start))
        }
        heading.attributedStringValue = styled
        heading.preferredMaxLayoutWidth = bounds.width
        let headingHeight = min(headingMaxHeight, textHeight(title, width: textWidth, font: font) + 4)
        heading.frame = NSRect(x: 0, y: headingY, width: bounds.width, height: headingHeight)

        let subtitleY = heading.frame.maxY + 8
        let available = max(0, bounds.height - subtitleY - 12)
        var subtitleSize = min(20, max(11, bounds.width * 0.063))
        var subtitleFont = NSFont.systemFont(ofSize: subtitleSize, weight: .medium)
        while subtitleSize > 10, textHeight(subtitle.stringValue, width: textWidth, font: subtitleFont) > available {
            subtitleSize -= 1
            subtitleFont = .systemFont(ofSize: subtitleSize, weight: .medium)
        }
        subtitle.attributedStringValue = NSAttributedString(string: subtitle.stringValue,
            attributes: HomeDashboardStyle.textAttributes(font: subtitleFont, color: HomeDashboardStyle.muted))
        subtitle.preferredMaxLayoutWidth = bounds.width
        let subtitleHeight = min(available, textHeight(subtitle.stringValue, width: textWidth, font: subtitleFont) + 2)
        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: subtitleHeight)
        needsDisplay = true
    }

    private func textHeight(_ value: String, width: CGFloat, font: NSFont) -> CGFloat {
        ceil((value as NSString).boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !title.isEmpty else { return }
        let width = min(78, bounds.width * 0.25)
        let y = min(bounds.maxY - 4, subtitle.frame.maxY + 11)
        let underline = HomeDashboardStyle.slant(NSRect(x: 10, y: y, width: width, height: 4))
        NSGradient(colors: [HomeDashboardStyle.yellow, HomeDashboardStyle.yellow, .clear])?.draw(in: underline, angle: 0)
    }
}
