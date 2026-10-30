import Cocoa

/// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
class HomeButton: NSButton {
    var primary = false
    var symbolName: String?
    var onClick: (() -> Void)?
    private var tracking: NSTrackingArea?
    private(set) var hovering = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(clicked)
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var isHighlighted: Bool { didSet { needsDisplay = true } }
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
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        if primary {
            let color = isHighlighted ? (HomeStyle.yellow.shadow(withLevel: 0.08) ?? HomeStyle.yellow) : HomeStyle.yellow
            HomeStyle.card(bounds, fill: color, border: color, radius: 9)
        } else if hovering || isHighlighted {
            HomeStyle.card(bounds, fill: NSColor.white.withAlphaComponent(0.6), border: HomeStyle.border.withAlphaComponent(0.4), radius: 7)
        }
        let size: CGFloat = primary ? 23 : 14
        let font = NSFont.systemFont(ofSize: size, weight: primary ? .heavy : .semibold)
        let width = (title as NSString).size(withAttributes: [.font: font]).width
        let icon: CGFloat = symbolName == nil ? 0 : (primary ? 24 : 16)
        let x = (bounds.width - width - (icon > 0 ? icon + 10 : 0)) / 2
        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2, width: icon, height: icon)) }
        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65, width: width + 2, height: size * 1.5),
                       size: size, weight: primary ? .heavy : .semibold)
    }
    @objc private func clicked() { onClick?() }
}

final class HomeModeButton: HomeButton {
    let mode: HomeGameMode
    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
    init(mode: HomeGameMode) {
        self.mode = mode
        super.init(frame: .zero)
        setAccessibilityRole(.radioButton)
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.card(bounds, fill: selected ? NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 1) : .white.withAlphaComponent(0.75),
                       border: selected ? HomeStyle.blue : hovering ? HomeStyle.blue.withAlphaComponent(0.4) : HomeStyle.border)
        let check = NSRect(x: 18, y: bounds.midY - 15, width: 30, height: 30)
        if selected {
            HomeStyle.symbol("checkmark.circle.fill", in: check, color: HomeStyle.blue)
        } else {
            HomeStyle.muted.withAlphaComponent(0.65).setStroke()
            let circle = NSBezierPath(ovalIn: check.insetBy(dx: 1, dy: 1)); circle.lineWidth = 2; circle.stroke()
        }
        HomeStyle.symbol(mode.symbol, in: NSRect(x: 66, y: bounds.midY - 19, width: 38, height: 38))
        let y = max(9, (bounds.height - 48) / 2)
        HomeStyle.text(AchievementText.string("home.mode.\(mode.key)"), in: NSRect(x: 117, y: y, width: bounds.width - 130, height: 27), size: 20, weight: .bold)
        HomeStyle.text(AchievementText.string("home.mode_desc.\(mode.key)"), in: NSRect(x: 117, y: y + 29, width: bounds.width - 130, height: 20), size: 13, color: HomeStyle.secondary)
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
        HomeStyle.card(bounds)
        let dividerX = bounds.width * 0.38
        HomeStyle.text(AchievementText.string("banner.total_cleared"), in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: 20, weight: .bold)
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
        HomeStyle.card(bounds)
        let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
        HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
        let names = [1: "hand.tap", 2: "music.note", 3: "flag", 4: "sparkles", 7: "link"]
        HomeStyle.symbol(names[definition.id] ?? "rosette", in: NSRect(x: 45, y: bounds.midY - 15, width: 30, height: 30), color: unlocked ? HomeStyle.ink : HomeStyle.muted)
        HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: 89, y: bounds.midY - 9, width: bounds.width - 98, height: 22), size: 13, weight: .semibold,
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

    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .aqua)
        for label in [heading, subtitle, hint] { label.isSelectable = false; label.drawsBackground = false }
        heading.textColor = HomeStyle.ink
        subtitle.textColor = HomeStyle.muted
        subtitle.font = .systemFont(ofSize: 21, weight: .semibold)
        hint.textColor = HomeStyle.secondary
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.alignment = .center
        [heading, subtitle, hint, hero, stats, startButton, records, rules, settings, all].forEach { addSubview($0) }
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

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager) {
        selectedMode = mode
        stats.snapshot = snapshot
        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
        if snapshot.isFinished {
            hint.stringValue = mode == .speedRun
                ? AchievementText.format("result.speed_run_finished", Self.clock(snapshot.elapsedTime))
                : AchievementText.format("result.score_attack_finished", snapshot.score)
        } else if snapshot.isRunning, mode != .free {
            hint.stringValue = mode == .scoreAttack
                ? AchievementText.format("hud.score_attack", snapshot.score, Self.clock(snapshot.remainingTime ?? 0))
                : AchievementText.format("hud.speed_run", snapshot.score, HomeGameMode.speedRunTarget, Self.clock(snapshot.elapsedTime))
        } else { hint.stringValue = AchievementText.string("home.operation_hint") }
        startButton.title = AchievementText.string(snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
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
        heading.font = .systemFont(ofSize: min(68, max(48, leftWidth * 0.1)), weight: .heavy)
        heading.preferredMaxLayoutWidth = leftWidth
        heading.frame = NSRect(x: margin, y: top + 30, width: leftWidth, height: bodyHeight * 0.33)
        subtitle.preferredMaxLayoutWidth = leftWidth
        subtitle.frame = NSRect(x: margin, y: top + bodyHeight * 0.34, width: leftWidth, height: 56)
        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.47, width: leftWidth - 24, height: 125)
        startButton.frame = NSRect(x: margin + (leftWidth - 280) / 2, y: footerY - 82, width: 280, height: 54)
        hint.preferredMaxLayoutWidth = leftWidth
        hint.frame = NSRect(x: margin, y: startButton.frame.minY - 43, width: leftWidth, height: 38)
        let rowHeight = (modeHeight - 104) / 3
        for (index, button) in modes.enumerated() {
            button.frame = NSRect(x: rightX + 20, y: top + 68 + CGFloat(index) * (rowHeight + 12), width: rightWidth - 40, height: rowHeight)
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
        HomeStyle.card(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172))
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
        HomeStyle.text(AchievementText.string("home.achievement_path"), in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: 21, weight: .bold)
        HomeStyle.text(AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count), in: NSRect(x: margin + 145, y: footerY + 20, width: 140, height: 23), size: 14, weight: .semibold)
        let meter = NSRect(x: margin + 292, y: footerY + 23, width: min(230, max(100, bounds.width - 850)), height: 12)
        NSColor(calibratedWhite: 0.9, alpha: 1).setFill(); NSBezierPath(roundedRect: meter, xRadius: 6, yRadius: 6).fill()
        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: NSRect(x: meter.minX, y: meter.minY, width: max(0, meter.width * ratio), height: meter.height), xRadius: 6, yRadius: 6).fill()
        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: footerY + 20, width: 60, height: 22), size: 11, color: HomeStyle.secondary)
    }

    private static func clock(_ interval: TimeInterval) -> String {
        let value = max(0, Int(interval))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
