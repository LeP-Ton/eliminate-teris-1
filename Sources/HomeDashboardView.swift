import Cocoa

/// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
class HomeButton: NSButton {
    var primary = false
    var symbolName: String?
    var onClick: (() -> Void)?
    private var tracking: NSTrackingArea?
    private(set) var hovering = false
    let feedback = GameControlFeedback()

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(clicked)
        feedback.onUpdate = { [weak self] in self?.needsDisplay = true }
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var isHighlighted: Bool { didSet { refreshFeedback() } }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; refreshFeedback() }
    override func mouseExited(with event: NSEvent) { hovering = false; refreshFeedback() }
    var selectedForFeedback: Bool { false }
    func refreshFeedback() {
        feedback.update(hover: hovering && isEnabled, press: isHighlighted && isEnabled,
                        selected: selectedForFeedback, animated: window != nil)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if primary {
            GameLobbyStyle.primaryButton(bounds, hover: feedback.values.hover, press: feedback.values.press)
        } else if hovering || isHighlighted {
            HomeStyle.card(bounds, fill: NSColor.white.withAlphaComponent(0.6), border: HomeStyle.border.withAlphaComponent(0.4), radius: 7)
        }
        let preferred: CGFloat = primary ? 22 : 14
        let size = GameLobbyStyle.fittedSize(title, width: bounds.width - (primary ? 60 : 24), preferred: preferred, minimum: 11, weight: primary ? .heavy : .semibold)
        let font = NSFont.systemFont(ofSize: size, weight: primary ? .heavy : .semibold)
        let width = (title as NSString).size(withAttributes: [.font: font]).width
        let icon: CGFloat = symbolName == nil ? 0 : (primary ? 24 : 16)
        let x = (bounds.width - width - (icon > 0 ? icon + 10 : 0)) / 2
        let offset = primary ? feedback.values.press * 2 - feedback.values.hover : 0
        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2 + offset, width: icon, height: icon)) }
        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65 + offset, width: width + 2, height: size * 1.5),
                       size: size, weight: primary ? .heavy : .semibold)
    }
    @objc private func clicked() { onClick?() }
}

final class HomeModeButton: HomeButton {
    let mode: HomeGameMode
    var selected = false { didSet { if oldValue != selected { refreshFeedback(); setAccessibilityValue(selected ? 1 : 0) } } }
    override var selectedForFeedback: Bool { selected }
    init(mode: HomeGameMode) {
        self.mode = mode
        super.init(frame: .zero)
        setAccessibilityRole(.radioButton)
        setAccessibilityValue(0)
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        let effect = feedback.values
        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
        GameLobbyStyle.surface(face, tint: NSColor(calibratedRed: 0.98, green: 0.985, blue: 0.99, alpha: 1), strength: 0.045 + effect.hover * 0.05)
        if effect.selection > 0 {
            GameLobbyStyle.gradient(face, colors: [.white.withAlphaComponent(effect.selection),
                NSColor(calibratedRed: 0.86, green: 0.95, blue: 1, alpha: effect.selection)], radius: 15)
            GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: 100, height: face.height), color: HomeStyle.blue.withAlphaComponent(0.09 * effect.selection))
        }
        let outline = NSBezierPath(roundedRect: face, xRadius: 15, yRadius: 15)
        HomeStyle.blue.withAlphaComponent(effect.selection * 0.8 + effect.hover * 0.15).setStroke()
        outline.lineWidth = 1.25; outline.stroke()
        let iconSize = min(57, face.height - 9)
        GameModeArtwork.draw(mode, in: NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize))
        let textX = face.minX + 81, textWidth = face.width - 108
        let title = AchievementText.string("home.mode.\(mode.key)")
        let compact = face.height < 65
        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: compact ? 17 : 20, minimum: 13, weight: .bold)
        let textY = compact ? face.minY + 4 : face.midY - 24
        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold)
        GameLobbyStyle.wrappedText(AchievementText.string("home.mode_desc.\(mode.key)"),
            in: NSRect(x: textX, y: textY + (compact ? 21 : 27), width: face.width - 98, height: face.maxY - textY - (compact ? 25 : 31)),
            size: compact ? 11 : 12, color: HomeStyle.secondary)
        if effect.selection > 0 {
            HomeStyle.symbol("checkmark.circle.fill", in: NSRect(x: face.maxX - 24, y: face.minY + 12, width: 15, height: 15), color: HomeStyle.blue.withAlphaComponent(effect.selection))
        }
    }
}

final class HomeHeroView: NSView {
    private var phase: CGFloat = 0
    private var timer: Timer?
    override var isFlipped: Bool { true }
    deinit { timer?.invalidate() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate(); timer = nil
        guard window != nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.06; self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    override func draw(_ dirtyRect: NSRect) {
        let animated = window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        HomeHeroPieceRenderer.draw(in: bounds, phase: phase, animated: animated)
    }
}

/// 当前棋盘的实时统计，不读取跨局成就数量。
final class HomeSessionStatsView: NSView {
    var snapshot: GameSnapshot? { didSet { needsDisplay = true; updateAccessibility() } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityElement(true); setAccessibilityRole(.group) }
    required init?(coder: NSCoder) { nil }
    private func updateAccessibility() {
        let total = snapshot?.totalCleared ?? 0
        let pieces = PieceKind.allCases.map { kind in
            AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), String(snapshot?.clearedByKind[kind, default: 0] ?? 0))
        }
        setAccessibilityLabel(([AchievementText.string("home.session_stats") + ": \(total)"] + pieces).joined(separator: "; "))
    }
    override func draw(_ dirtyRect: NSRect) {
        GameLobbyStyle.surface(bounds.insetBy(dx: 3, dy: 4), radius: 16, tint: NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1))
        let dividerX = bounds.width * 0.38
        let title = AchievementText.string("home.cleared_title")
        let titleSize = GameLobbyStyle.fittedSize(title, width: dividerX - 30, preferred: 20, minimum: 11, weight: .bold)
        HomeStyle.text(title, in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: titleSize, weight: .bold)
        let totalText = "\(snapshot?.totalCleared ?? 0)"
        var totalSize: CGFloat = 58
        while (totalText as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: totalSize, weight: .heavy)]).width > dividerX - 27, totalSize > 24 { totalSize -= 2 }
        HomeStyle.text(totalText, in: NSRect(x: 21, y: 47, width: dividerX - 27, height: 70), size: totalSize, weight: .heavy)
        HomeStyle.text(AchievementText.string("home.session_stats"), in: NSRect(x: 23, y: bounds.height - 29, width: dividerX - 27, height: 18), size: 11, color: HomeStyle.muted)
        HomeStyle.border.setStroke()
        let divider = NSBezierPath(); divider.move(to: NSPoint(x: dividerX, y: 24)); divider.line(to: NSPoint(x: dividerX, y: bounds.height - 24)); divider.stroke()
        let slot = (bounds.width - dividerX - 20) / 2
        for (index, kind) in PieceKind.allCases.enumerated() {
            let x = dividerX + 14 + CGFloat(index % 2) * slot
            let y = CGFloat(index / 2) * 55 + 35
            HomeStyle.piece(kind, in: NSRect(x: x, y: y, width: 43, height: 29), shadow: false)
            let text = "\(snapshot?.clearedByKind[kind, default: 0] ?? 0)"
            let numberWidth = max(20, slot - 55)
            var numberSize: CGFloat = 20
            while (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: numberSize, weight: .semibold)]).width > numberWidth, numberSize > 10 { numberSize -= 1 }
            HomeStyle.text(text, in: NSRect(x: x + 53, y: y + 2, width: numberWidth, height: 29), size: numberSize, weight: .semibold)
        }
    }
}

private final class HomeAchievementButton: HomeButton {
    var definition: AchievementDefinition?
    var unlocked = false
    override func draw(_ dirtyRect: NSRect) {
        guard let definition else { return }
        GameLobbyStyle.surface(bounds.insetBy(dx: 1, dy: 1), radius: 12,
                               tint: NSColor(calibratedRed: 1, green: 0.998, blue: 0.985, alpha: 1), strength: 0.025)
        if hovering {
            GameLobbyStyle.glow(bounds, color: GameLobbyStyle.amber.withAlphaComponent(0.07 * feedback.values.hover))
        }
        let title = AchievementText.string(definition.titleKey)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
        // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
        let fixedWidth: CGFloat = 38 + 9
        // 左侧状态占据 13...33 点，居中内容两侧对称预留 34 点，避免窄窗口重叠。
        let availableWidth = max(0, floor(bounds.width - 34 * 2 - fixedWidth))
        var characters = Array(title), displayedTitle = title
        while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
            characters.removeLast()
            displayedTitle = String(characters) + "…"
        }
        if (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth { displayedTitle = "" }
        let titleSize = (displayedTitle as NSString).size(withAttributes: attributes)
        let titleWidth = ceil(titleSize.width)
        let startX = bounds.midX - (fixedWidth + titleWidth) / 2
        let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18), color: unlocked ? HomeStyle.green.withAlphaComponent(0.80) : HomeStyle.muted)
        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: startX, y: bounds.midY - 19, width: 38, height: 38),
                                                                           from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        HomeStyle.text(displayedTitle, in: NSRect(x: startX + fixedWidth, y: bounds.midY - titleSize.height / 2, width: titleWidth, height: titleSize.height), size: 13, weight: .semibold,
                       color: unlocked ? HomeStyle.ink : HomeStyle.muted)
    }
}

final class HomeDashboardView: NSView {
    var onStart: (() -> Void)?
    var onMode: ((HomeGameMode) -> Void)?
    var onNavigate: ((String) -> Void)?
    var onAchievement: ((Int?) -> Void)?
    let stats = HomeSessionStatsView(frame: .zero)
    let startButton = HomeButton(frame: .zero)
    let challengeHUD = HomeChallengeHUDView(frame: .zero)
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let subtitle = NSTextField(wrappingLabelWithString: "")
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let hero = HomeHeroView()
    private let records = HomeButton(frame: .zero), rules = HomeButton(frame: .zero), settings = HomeButton(frame: .zero)
    private let all = HomeButton(frame: .zero)
    private var modes: [HomeModeButton] = []
    private var badges: [HomeAchievementButton] = []
    private var selectedMode: HomeGameMode = .free
    private var unlockedCount = 0
    private var showsChallenge = false

    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .aqua)
        for label in [heading, subtitle, hint] { label.isSelectable = false; label.drawsBackground = false }
        heading.textColor = HomeStyle.ink
        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
        hint.textColor = HomeStyle.secondary
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.alignment = .center
        [heading, subtitle, hint, hero, stats, challengeHUD, startButton, records, rules, settings, all].forEach { addSubview($0) }
        challengeHUD.isHidden = true
        startButton.primary = true; startButton.symbolName = "play.fill"
        startButton.onClick = { [weak self] in self?.onStart?() }
        for (button, key) in [(records, "records"), (rules, "rules"), (settings, "settings")] {
            button.onClick = { [weak self] in self?.onNavigate?(key) }
        }
        all.onClick = { [weak self] in self?.onAchievement?(nil) }
        for mode in HomeGameMode.allCases {
            let button = HomeModeButton(mode: mode)
            button.onClick = { [weak self] in self?.onMode?(mode) }
            addSubview(button); modes.append(button)
        }
        for _ in 0..<5 {
            let button = HomeAchievementButton(frame: .zero)
            button.onClick = { [weak self, weak button] in self?.onAchievement?(button?.definition?.id) }
            addSubview(button); badges.append(button)
        }
    }
    required init?(coder: NSCoder) { nil }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager, isStarting: Bool = false) {
        selectedMode = mode
        stats.snapshot = snapshot
        showsChallenge = mode != .free && (snapshot.isRunning || snapshot.isFinished)
        challengeHUD.isHidden = !showsChallenge
        challengeHUD.refresh(snapshot: snapshot, mode: mode)
        heading.stringValue = AchievementText.string(showsChallenge ? "home.mode.\(mode.key)" : "home.hero.\(mode.key)")
        subtitle.stringValue = AchievementText.string(showsChallenge ? "home.mode_desc.\(mode.key)" : "home.subtitle.\(mode.key)")
        subtitle.font = .systemFont(ofSize: showsChallenge ? 14 : 19, weight: .medium)
        if isStarting {
            hint.stringValue = AchievementText.string("home.starting_hint")
        } else if snapshot.isFinished {
            hint.stringValue = AchievementText.format("home.result", snapshot.totalCleared)
        } else { hint.stringValue = AchievementText.string(snapshot.isRunning ? "home.operation_hint" : "home.start_hint") }
        startButton.title = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
        startButton.isEnabled = !isStarting
        startButton.setAccessibilityLabel(startButton.title)
        records.title = AchievementText.string("panel.records")
        rules.title = AchievementText.string("panel.rules")
        settings.title = AchievementText.string("panel.settings")
        all.title = AchievementText.string("achievement.view_all") + "  →"
        for button in modes {
            button.selected = button.mode == mode
            button.setAccessibilityLabel(AchievementText.string("home.mode.\(button.mode.key)") + ", " + AchievementText.string("home.mode_desc.\(button.mode.key)"))
        }
        unlockedCount = manager.unlockedIDs().count
        let definitions = AchievementDefinition.all.sorted {
            let a = manager.isUnlocked(id: $0.id), b = manager.isUnlocked(id: $1.id)
            return a == b ? $0.id < $1.id : a
        }
        for (button, definition) in zip(badges, definitions) {
            button.definition = definition; button.unlocked = manager.isUnlocked(id: definition.id)
            button.toolTip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
            button.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
            button.needsDisplay = true
        }
        needsLayout = true; needsDisplay = true
        [startButton, records, rules, settings, all].forEach { $0.needsDisplay = true }
    }

    override func layout() {
        super.layout()
        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
        let rightWidth = max(330, min(440, bounds.width * 0.34))
        let rightX = bounds.width - margin - rightWidth
        let leftWidth = rightX - margin - 32
        let footerY = bounds.height - 144
        let top: CGFloat = 96
        let bodyHeight = footerY - top - 24
        let modeHeight = bodyHeight - 172
        heading.font = .systemFont(ofSize: showsChallenge ? 24 : min(60, max(44, leftWidth * 0.092)), weight: .heavy)
        heading.preferredMaxLayoutWidth = leftWidth
        heading.frame = NSRect(x: margin, y: top + (showsChallenge ? 10 : 26), width: leftWidth, height: showsChallenge ? 36 : bodyHeight * 0.32)
        subtitle.preferredMaxLayoutWidth = leftWidth
        subtitle.frame = NSRect(x: margin, y: showsChallenge ? top + 49 : top + bodyHeight * 0.33, width: leftWidth, height: showsChallenge ? 32 : 56)
        challengeHUD.frame = NSRect(x: margin, y: top + 83, width: leftWidth, height: min(128, bodyHeight * 0.27))
        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.45, width: leftWidth - 24, height: 138)
        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: footerY - 89, width: 294, height: 62)
        hint.preferredMaxLayoutWidth = leftWidth
        hint.frame = NSRect(x: margin, y: startButton.frame.minY - 43, width: leftWidth, height: 38)
        let rowHeight = (modeHeight - 86) / 3
        for (index, button) in modes.enumerated() {
            button.frame = NSRect(x: rightX + 20, y: top + 60 + CGFloat(index) * (rowHeight + 8), width: rightWidth - 40, height: rowHeight)
        }
        stats.frame = NSRect(x: rightX, y: top + modeHeight + 16, width: rightWidth, height: 156)
        var navX = bounds.width - margin
        for button in [settings, rules, records] {
            let width = max(84, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width + 24)
            navX -= width
            button.frame = NSRect(x: navX, y: 19, width: width, height: 36)
            navX -= 8
        }
        all.frame = NSRect(x: bounds.width - margin - 120, y: footerY + 8, width: 120, height: 32)
        let badgeWidth = (bounds.width - margin * 2 - 12 * 4) / 5
        for (index, badge) in badges.enumerated() { badge.frame = NSRect(x: margin + CGFloat(index) * (badgeWidth + 12), y: footerY + 52, width: badgeWidth, height: 54) }
    }

    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.background.setFill(); bounds.fill()
        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
        let rightWidth = max(330, min(440, bounds.width * 0.34))
        let rightX = bounds.width - margin - rightWidth
        let footerY = bounds.height - 144
        let bodyHeight = footerY - 120
        GameLobbyStyle.surface(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172), radius: 20,
                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
        // 暖色环境光承接原设计稿插画；静态绘制，不添加常驻粒子计时器。
        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: rightX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
        // 低透明度装饰方块呼应四种颜色，避免盖住正文和交互区域。
        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), footerY - 60, HomeStyle.yellow)] {
            color.withAlphaComponent(0.10).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 25, height: 25), xRadius: 5, yRadius: 5).fill()
        }
        for (index, color) in [NSColor.systemOrange, .systemBlue, .systemGreen, .systemRed].enumerated() {
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: margin + CGFloat(index % 2) * 16, y: 20 + CGFloat(index / 2) * 16, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
        }
        HomeStyle.text(AchievementText.string("home.brand"), in: NSRect(x: margin + 47, y: 18, width: 360, height: 38), size: 26, weight: .heavy)
        HomeStyle.text(AchievementText.string("home.game_modes"), in: NSRect(x: rightX + 22, y: 114, width: rightWidth - 44, height: 36), size: 27, weight: .heavy)
        HomeStyle.border.withAlphaComponent(0.7).setStroke()
        for y in [CGFloat(70), footerY] {
            let line = NSBezierPath(); line.move(to: NSPoint(x: y == 70 ? 0 : margin, y: y)); line.line(to: NSPoint(x: y == 70 ? bounds.width : bounds.width - margin, y: y)); line.stroke()
        }
        let achievementTitle = AchievementText.string("home.achievement_path")
        let achievementSize = GameLobbyStyle.fittedSize(achievementTitle, width: 140, preferred: 21, minimum: 13, weight: .bold)
        HomeStyle.text(achievementTitle, in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: achievementSize, weight: .bold)
        HomeStyle.text(AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count), in: NSRect(x: margin + 145, y: footerY + 20, width: 140, height: 23), size: 14, weight: .semibold)
        let meter = NSRect(x: margin + 292, y: footerY + 23, width: min(230, max(100, bounds.width - 850)), height: 12)
        NSColor(calibratedWhite: 0.9, alpha: 1).setFill(); NSBezierPath(roundedRect: meter, xRadius: 6, yRadius: 6).fill()
        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
        if ratio > 0 {
            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 6)
        }
        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: footerY + 20, width: 60, height: 22), size: 11, color: HomeStyle.secondary)
    }

}
