import Cocoa

/// 转场覆盖窗口上方整行，左列只负责定位。右侧模式面板由大厅单独叠在前方。
final class HomeModeHeaderView: NSView {
    static let previewDuration: TimeInterval = 1
    private static let cardHeight: CGFloat = 148
    private static let fullScale = NSSize(width: 1, height: 1)
    // 远处的卡片横向收得更多，靠近时逐渐展开成正面。
    private static let distantScale = NSSize(width: 0.20, height: 0.27)
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private let intro = HomeModeIntroView(frame: .zero)
    private(set) var card = HomeChallengeHUDView(frame: .zero)
    private var spareCard = HomeChallengeHUDView(frame: .zero)
    private var selectedMode: HomeGameMode?
    private var showsCard = false
    private var timer: Timer?
    private var transition: Transition?
    private var column = NSRect.zero
    private var entryX: CGFloat = 0

    private struct Transition {
        let outgoing: NSView
        let incoming: NSView
        let direction: CGFloat
        let start: TimeInterval
        let duration: TimeInterval
        let outgoingOffset: CGFloat
        let incomingOffset: CGFloat
        let outgoingScale: NSSize
        let incomingScale: NSSize
        let outgoingAlpha: CGFloat
        let incomingAlpha: CGFloat
        var fraction: CGFloat = 0
    }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(intro)
        addSubview(spareCard)
        addSubview(card)
        settle()
    }

    required init?(coder: NSCoder) { nil }
    deinit { timer?.invalidate() }

    func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
        let topPadding: CGFloat = 8
        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
        column = leftColumn.offsetBy(dx: 0, dy: -frame.minY)
        entryX = modePanelLeading
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, isStarting: Bool) {
        let shouldShowCard = mode != .free || (!isStarting && (snapshot.isRunning || snapshot.isFinished))
        let changedMode = selectedMode.map { $0 != mode } ?? false
        let previousView = showsCard ? card as NSView : intro
        if changedMode, showsCard {
            // 切换挑战时保留旧卡的快照，避免滑出过程中先变成下一种模式。
            let previousCard = card
            card = spareCard
            spareCard = previousCard
        } else if changedMode, shouldShowCard, !spareCard.isHidden, spareCard.mode == mode {
            // 用户在返回过程中改主意时，沿用仍在画面中的同一张卡。
            let nextCard = spareCard
            spareCard = card
            card = nextCard
        }
        let activeView = shouldShowCard ? card as NSView : intro
        selectedMode = mode
        showsCard = shouldShowCard
        card.refresh(snapshot: snapshot, mode: mode)
        if activeView === intro { intro.refresh(mode: mode) }

        if changedMode, previousView !== activeView, window != nil, column.width > 0, !reducesMotion() {
            animate(from: previousView, to: activeView, entersFromRight: shouldShowCard)
        } else if changedMode || previousView !== activeView || transition == nil {
            settle()
        }
    }

    private func animate(from outgoing: NSView, to incoming: NSView, entersFromRight: Bool) {
        // 位置以列宽为单位保存，快速切换和调整窗口大小时从当前画面继续。
        let direction: CGFloat = entersFromRight ? 1 : -1
        let incomingWasVisible = !incoming.isHidden
        let incomingScale = incomingWasVisible ? scale(of: incoming) : entersFromRight ? Self.distantScale : Self.fullScale
        let initialX = entersFromRight ? min(entryX, visibleRightEdge - column.width * incomingScale.width - 6) : column.minX - column.width
        let initialOffset = (initialX - column.minX) / column.width
        transition = Transition(outgoing: outgoing, incoming: incoming, direction: direction,
                                start: now(), duration: entersFromRight ? Self.previewDuration : 0.46,
                                outgoingOffset: (outgoing.frame.minX - column.minX) / column.width,
                                incomingOffset: incomingWasVisible ? (incoming.frame.minX - column.minX) / column.width : initialOffset,
                                outgoingScale: scale(of: outgoing), incomingScale: incomingScale,
                                outgoingAlpha: outgoing.alphaValue,
                                incomingAlpha: incomingWasVisible ? incoming.alphaValue : 0)
        for item in subviews {
            item.isHidden = item !== incoming && item !== outgoing
            item.setAccessibilityHidden(item !== incoming)
        }
        addSubview(incoming, positioned: .above, relativeTo: outgoing)
        placeSubviews()

        timer?.invalidate()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private var visibleRightEdge: CGFloat {
        guard let window, let screen = window.screen else { return bounds.maxX }
        let point = NSPoint(x: screen.frame.maxX, y: screen.frame.midY)
        return min(bounds.maxX, convert(window.convertPoint(fromScreen: point), from: nil).x)
    }

    private func scale(of view: NSView) -> NSSize {
        guard view !== intro else { return Self.fullScale }
        return NSSize(width: view.frame.width / column.width, height: view.frame.height / Self.cardHeight)
    }

    func advanceAnimation() {
        guard var transition else { return }
        let elapsed = max(0, now() - transition.start)
        if elapsed >= transition.duration || reducesMotion() {
            settle()
        } else {
            transition.fraction = CGFloat(elapsed / transition.duration)
            self.transition = transition
            placeSubviews()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { settle() }
    }

    override func layout() {
        super.layout()
        placeSubviews()
    }

    private func settle() {
        transition = nil
        timer?.invalidate()
        timer = nil
        let activeView = showsCard ? card as NSView : intro
        for item in subviews {
            item.isHidden = item !== activeView
            item.setAccessibilityHidden(item !== activeView)
            item.alphaValue = 1
        }
        placeSubviews()
    }

    private func placeSubviews() {
        guard let transition else {
            place(intro, offset: 0)
            place(card, offset: 0)
            place(spareCard, offset: 0)
            card.revealFraction = nil
            spareCard.revealFraction = nil
            return
        }
        let t = transition.fraction
        let travel = t * t * (3 - 2 * t)
        let incomingScale = NSSize(width: transition.incomingScale.width + (1 - transition.incomingScale.width) * travel,
                                   height: transition.incomingScale.height + (1 - transition.incomingScale.height) * travel)
        var incomingOffset = transition.incomingOffset * (1 - travel)
        if transition.incoming !== intro, column.width > 0 {
            // 窗口缩放期间也限制卡片右端，始终以完整卡面的实际尺寸计算。
            let rightmostOffset = (bounds.maxX - column.minX) / column.width - incomingScale.width
            incomingOffset = min(incomingOffset, rightmostOffset)
        }
        var outgoingOffset = transition.outgoingOffset * (1 - travel) - transition.direction * travel
        var exitProgress = travel
        if transition.outgoing === intro, transition.direction > 0, column.width > 0 {
            // 卡片前沿先接近实际文字，再推着文字离场，避免两者隔着一整列空白一起移动。
            let textWidth = min(1, (intro.contentWidth + 14) / column.width)
            outgoingOffset = min(transition.outgoingOffset, incomingOffset - textWidth)
            exitProgress = min(1, max(0, -outgoingOffset / textWidth))
        }
        place(transition.outgoing, offset: outgoingOffset, scale: transition.outgoingScale)
        place(transition.incoming, offset: incomingOffset, scale: incomingScale)
        transition.outgoing.alphaValue = transition.outgoingAlpha * (1 - exitProgress * exitProgress)
        transition.incoming.alphaValue = transition.incomingAlpha + (1 - transition.incomingAlpha) * sqrt(travel)
        (transition.outgoing as? HomeChallengeHUDView)?.revealFraction = nil
        (transition.incoming as? HomeChallengeHUDView)?.revealFraction = travel
    }

    private func place(_ view: NSView, offset: CGFloat, scale: NSSize = HomeModeHeaderView.fullScale) {
        let x = column.minX + offset * column.width
        if view === intro {
            view.frame = NSRect(x: x, y: column.minY, width: column.width, height: column.height)
        } else {
            // 按完整卡面的坐标绘制，再缩放整个视图，使数字、图案和阴影一起放大。
            view.frame = NSRect(x: x, y: column.minY - HomeChallengeHUDView.surfaceInsetY * scale.height,
                                width: column.width * scale.width, height: Self.cardHeight * scale.height)
            view.bounds = NSRect(x: 0, y: 0, width: column.width, height: Self.cardHeight)
        }
    }
}

private final class HomeModeIntroView: NSView {
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let subtitle = NSTextField(wrappingLabelWithString: "")

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        heading.textColor = HomeStyle.ink
        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
        addSubview(heading)
        addSubview(subtitle)
    }

    required init?(coder: NSCoder) { nil }

    var contentWidth: CGFloat {
        max(lineWidth(in: heading), lineWidth(in: subtitle))
    }

    private func lineWidth(in label: NSTextField) -> CGFloat {
        guard let font = label.font else { return 0 }
        return label.stringValue.split(separator: "\n").map { line in
            (String(line) as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
    }

    func refresh(mode: HomeGameMode) {
        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
    }

    override func layout() {
        super.layout()
        let headingY: CGFloat = 20
        let subtitleY = max(headingY, bounds.height - 42)
        let headingHeight = max(0, subtitleY - headingY - 8)
        let textWidth = max(0, bounds.width - 4)
        var fontSize = min(60, max(44, bounds.width * 0.092))
        // 先给副标题留出独立区域，再按语言和窗口宽高调整主标题字级。
        while fontSize > 32 {
            let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
            let textSize = (heading.stringValue as NSString).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]
            )
            if ceil(textSize.height) + 4 <= headingHeight { break }
            fontSize -= 1
        }
        heading.font = .systemFont(ofSize: fontSize, weight: .heavy)
        heading.preferredMaxLayoutWidth = bounds.width
        subtitle.preferredMaxLayoutWidth = bounds.width
        heading.frame = NSRect(x: 0, y: headingY, width: bounds.width, height: headingHeight)
        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: 42)
    }
}
