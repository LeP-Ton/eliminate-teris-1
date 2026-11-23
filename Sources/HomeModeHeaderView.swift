import Cocoa

/// 上方文案和本局统计并排排版，切换模式时仅统计卡从右侧滑入。
final class HomeModeHeaderView: NSView {
    static let previewDuration: TimeInterval = 1
    private static let distantScale: CGFloat = 0.20
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private let intro = HomeModeIntroView(frame: .zero)
    private(set) var card = HomeChallengeHUDView(frame: .zero)
    private var spareCard = HomeChallengeHUDView(frame: .zero)
    private var selectedMode: HomeGameMode?
    private var timer: Timer?
    private var transition: Transition?
    private var cardColumn = NSRect.zero
    private var entryX: CGFloat = 0

    private struct Pose {
        let offset: CGFloat
        let scale: CGFloat
        let alpha: CGFloat
    }

    private struct Transition {
        let start: TimeInterval
        let outgoing: Pose
        let incoming: Pose
        var fraction: CGFloat = 0
    }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(spareCard)
        addSubview(card)
        addSubview(intro)
        settle()
    }

    required init?(coder: NSCoder) { nil }
    deinit { timer?.invalidate() }

    func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
        let topPadding = HomeChallengeHUDView.surfaceInsetY + 3
        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
        let headingWidth = (leftColumn.width * 0.361).rounded(.down)
        let gap = min(16, leftColumn.width * 0.025)
        intro.frame = NSRect(x: leftColumn.minX, y: topPadding, width: headingWidth, height: leftColumn.height)
        let cardTop = min(19, leftColumn.height * 0.079)
        let cardHeight = min(186, max(102, leftColumn.height * 0.77))
        let faceX = intro.frame.maxX + gap + HomeChallengeHUDView.trailingInset
        let faceRight = modePanelLeading - min(22, leftColumn.width * 0.031)
        let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX), height: cardHeight)
        cardColumn = NSRect(x: cardX, y: topPadding + cardTop,
                            width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                            height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
        entryX = modePanelLeading
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
        let changedMode = selectedMode.map { $0 != mode } ?? false
        let reuseIncoming = changedMode && !spareCard.isHidden && spareCard.mode == mode
        if changedMode {
            // 离场卡保留自己的快照，连续切换时只在回到同一模式后续用它的位置。
            let previousCard = card
            card = spareCard
            spareCard = previousCard
        }
        selectedMode = mode
        card.refresh(snapshot: snapshot, mode: mode)
        intro.refresh(mode: mode)

        if changedMode, window != nil, cardColumn.width > 0, !reducesMotion() {
            animate(reuseIncoming: reuseIncoming)
        } else if changedMode || transition == nil {
            settle()
        }
    }

    private func animate(reuseIncoming: Bool) {
        // 以卡面宽度为单位记录位置，重设窗口尺寸时进度可按比例继续。
        let right = visibleRightEdge - cardColumn.width * Self.distantScale - 6
        let launchX = min(entryX, right)
        let launch = Pose(offset: (launchX - cardColumn.minX) / cardColumn.width, scale: Self.distantScale, alpha: 0)
        transition = Transition(start: now(), outgoing: pose(of: spareCard), incoming: reuseIncoming ? pose(of: card) : launch)
        card.isHidden = false
        card.setAccessibilityHidden(false)
        spareCard.setAccessibilityHidden(true)
        addSubview(card, positioned: .above, relativeTo: spareCard)
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

    private func pose(of view: HomeChallengeHUDView) -> Pose {
        Pose(offset: (view.frame.minX - cardColumn.minX) / cardColumn.width,
             scale: view.bounds.width > 0 ? view.frame.width / view.bounds.width : 1,
             alpha: view.alphaValue)
    }

    func advanceAnimation() {
        guard var transition else { return }
        let elapsed = max(0, now() - transition.start)
        if elapsed >= Self.previewDuration || reducesMotion() {
            settle()
        } else {
            transition.fraction = CGFloat(elapsed / Self.previewDuration)
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
        card.isHidden = false
        card.setAccessibilityHidden(false)
        spareCard.isHidden = true
        spareCard.setAccessibilityHidden(true)
        placeSubviews()
    }

    private func placeSubviews() {
        guard let transition, cardColumn.width > 0 else {
            place(card, pose: Pose(offset: 0, scale: 1, alpha: 1))
            place(spareCard, pose: Pose(offset: 0, scale: 1, alpha: 1))
            card.revealFraction = nil
            spareCard.revealFraction = nil
            return
        }
        let t = transition.fraction
        let travel = t * t * (3 - 2 * t)
        let incoming = transition.incoming
        let scale = incoming.scale + (1 - incoming.scale) * travel
        let rightmostOffset = (bounds.maxX - cardColumn.minX) / cardColumn.width - scale
        let offset = min(incoming.offset * (1 - travel), rightmostOffset)
        place(card, pose: Pose(offset: offset, scale: scale, alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(travel)))
        card.revealFraction = travel

        let outgoing = transition.outgoing
        place(spareCard, pose: Pose(offset: outgoing.offset * (1 - travel) - 0.08 * travel,
                                    scale: outgoing.scale, alpha: outgoing.alpha * (1 - travel)))
        spareCard.revealFraction = nil
    }

    private func place(_ view: HomeChallengeHUDView, pose: Pose) {
        // 入场全程等比缩放，使卡片斜边和文字角度在移动时也保持一致。
        view.frame = NSRect(x: cardColumn.minX + pose.offset * cardColumn.width,
                            y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale,
                            width: cardColumn.width * pose.scale, height: cardColumn.height * pose.scale)
        view.bounds = NSRect(origin: .zero, size: cardColumn.size)
        view.alphaValue = pose.alpha
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
