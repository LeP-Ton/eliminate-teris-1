import Cocoa
import CoreText

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
    override func resetCursorRects() {
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }

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
    // 解谜暂时只是大厅入口，没有可交给棋盘控制器的游戏模式。
    let mode: HomeGameMode?
    private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
    private var descriptionKey: String { "home.mode_desc.\(mode?.key ?? "puzzle")" }
    var selected = false { didSet { if oldValue != selected { refreshFeedback(); setAccessibilityValue(selected ? 1 : 0) } } }
    override var selectedForFeedback: Bool { selected }
    init(mode: HomeGameMode?) {
        self.mode = mode
        super.init(frame: .zero)
        setAccessibilityRole(.radioButton)
        setAccessibilityValue(0)
        isEnabled = mode != nil
    }
    required init?(coder: NSCoder) { nil }

    func refresh(selectedMode: HomeGameMode) {
        selected = mode == selectedMode
        setAccessibilityLabel(AchievementText.string(titleKey) + ", " + AchievementText.string(descriptionKey))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let effect = feedback.values
        let face = bounds.insetBy(dx: 4, dy: bounds.height < 65 ? 3 : 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
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
        let icon = NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
        if let mode {
            GameModeArtwork.draw(mode, in: icon)
        } else {
            GameModeArtwork.drawPuzzle(in: icon)
        }
        let compact = face.height < 65
        let textX = compact ? icon.maxX + 11 : face.minX + 81
        let textWidth = face.maxX - textX - 27
        let title = AchievementText.string(titleKey)
        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: compact ? 17 : 20, minimum: 13, weight: .bold)
        let textY = compact ? face.minY + 3 : face.midY - 24
        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold,
                       color: isEnabled ? HomeStyle.ink : HomeStyle.secondary)
        let descriptionY = textY + (compact ? 21 : 27)
        let description = AchievementText.string(descriptionKey)
        let descriptionWidth = face.maxX - textX - 16
        let descriptionSize = compact ? GameLobbyStyle.fittedSize(description, width: descriptionWidth, preferred: 11, minimum: 9, weight: .regular) : 12
        GameLobbyStyle.wrappedText(description,
            in: NSRect(x: textX, y: descriptionY, width: descriptionWidth, height: face.maxY - descriptionY - 3),
            size: descriptionSize, color: HomeStyle.secondary)
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

private final class HomeAchievementButton: HomeButton {
    private static let iconSize: CGFloat = 38
    private static var iconBounds: [String: NSRect] = [:]
    private(set) var definition: AchievementDefinition?
    private var unlocked = false
    private var displayedLanguage: AppLanguage?
    private var displayedProgress: Double?

    func refresh(_ definition: AchievementDefinition, manager: AchievementsManager) {
        let language = Localizer.shared.language
        let unlocked = manager.isUnlocked(id: definition.id)
        let progress = manager.progress(for: definition).current
        // 计时刷新只更新变化的标签，避免重复格式化成就文案。
        guard self.definition?.id != definition.id || self.unlocked != unlocked ||
              displayedLanguage != language || displayedProgress != progress else { return }
        self.definition = definition
        self.unlocked = unlocked
        displayedLanguage = language
        displayedProgress = progress
        toolTip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
        setAccessibilityLabel(AchievementText.title(definition, manager: manager))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let definition else { return }
        GameLobbyStyle.surface(bounds.insetBy(dx: 1, dy: 1), radius: 12,
                               tint: NSColor(calibratedRed: 1, green: 0.998, blue: 0.985, alpha: 1), strength: 0.025)
        if hovering {
            GameLobbyStyle.glow(bounds, color: GameLobbyStyle.amber.withAlphaComponent(0.07 * feedback.values.hover))
        }
        let title = AchievementText.string(definition.titleKey)
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
        // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
        let artwork = AchievementIconCatalog.image(for: definition, muted: !unlocked)
        let artworkBounds = Self.visibleBounds(of: artwork, key: "\(definition.id).\(unlocked)")
        let fixedWidth = ceil(artworkBounds.width) + 9
        // 覆盖状态图标及抗锯齿边缘，并为图文居中在另一侧预留同等空间。
        let availableWidth = max(0, floor(bounds.width - 36 * 2 - fixedWidth))
        var characters = Array(title), displayedTitle = title
        while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
            characters.removeLast()
            displayedTitle = String(characters) + "…"
        }
        if (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth { displayedTitle = "" }
        let color = unlocked ? HomeStyle.ink : HomeStyle.muted
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: displayedTitle, attributes: [
            .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]))
        // 按截断后字形的实际轮廓居中，兼顾没有下伸笔画的标题和各语言的字体回退。
        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let titleWidth = displayedTitle.isEmpty || textBounds.isNull ? 0 : textBounds.width
        let startX = bounds.midX - (fixedWidth + titleWidth) / 2
        let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18), color: unlocked ? HomeStyle.green.withAlphaComponent(0.80) : HomeStyle.muted)
        artwork.draw(in: NSRect(x: startX - artworkBounds.minX, y: bounds.midY - artworkBounds.midY,
                               width: Self.iconSize, height: Self.iconSize),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if titleWidth > 0, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            // 当前视图的 y 向下，文字绘制坐标的 y 向上。
            context.translateBy(x: startX + fixedWidth - textBounds.minX, y: bounds.midY + textBounds.midY)
            context.scaleBy(x: 1, y: -1)
            context.textMatrix = .identity
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    private static func visibleBounds(of artwork: NSImage, key: String) -> NSRect {
        if let cached = iconBounds[key] { return cached }
        let canvas = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
        guard let data = artwork.tiffRepresentation, let image = NSBitmapImageRep(data: data) else { return canvas }
        var left = image.pixelsWide, right = -1, top = image.pixelsHigh, bottom = -1
        // 忽略透明留白与抗锯齿细边，用图案轮廓对齐。
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y), color.alphaComponent > 0.2 else { continue }
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard left <= right, top <= bottom else { return canvas }
        let scaleX = iconSize / CGFloat(image.pixelsWide)
        let scaleY = iconSize / CGFloat(image.pixelsHigh)
        let result = NSRect(x: CGFloat(left) * scaleX, y: CGFloat(top) * scaleY,
                            width: CGFloat(right - left + 1) * scaleX, height: CGFloat(bottom - top + 1) * scaleY)
        iconBounds[key] = result
        return result
    }
}

/// 横跨两栏的成就预览，按可用宽度显示一行，完整清单由成就面板展示。
final class HomeAchievementPathView: NSView {
    static let preferredHeight: CGFloat = 106
    var onAchievement: ((Int?) -> Void)?
    private let all = HomeButton(frame: .zero)
    private var badges: [HomeAchievementButton] = []
    private var unlockedCount = 0

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(all)
        all.onClick = { [weak self] in self?.onAchievement?(nil) }
        for _ in AchievementDefinition.all {
            let badge = HomeAchievementButton(frame: .zero)
            badge.onClick = { [weak self, weak badge] in
                guard let id = badge?.definition?.id else { return }
                self?.onAchievement?(id)
            }
            addSubview(badge)
            badges.append(badge)
        }
    }

    required init?(coder: NSCoder) { nil }

    func refresh(manager: AchievementsManager) {
        all.title = AchievementText.string("achievement.view_all") + "  →"
        let unlocked = Set(manager.unlockedIDs())
        unlockedCount = unlocked.count
        let definitions = AchievementDefinition.all.sorted {
            let a = unlocked.contains($0.id), b = unlocked.contains($1.id)
            return a == b ? $0.id < $1.id : a
        }
        for (badge, definition) in zip(badges, definitions) { badge.refresh(definition, manager: manager) }
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        all.frame = NSRect(x: max(0, bounds.width - 120), y: 10, width: 120, height: 32)
        let width = bounds.width
        let gap: CGFloat = 12
        let columns = min(badges.count, max(5, Int((width + gap) / (174 + gap))))
        let badgeWidth = max(0, width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        for (index, badge) in badges.enumerated() {
            badge.isHidden = index >= columns
            guard !badge.isHidden else { continue }
            badge.frame = NSRect(x: CGFloat(index) * (badgeWidth + gap), y: 52, width: badgeWidth, height: 54)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.border.withAlphaComponent(0.7).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 0.5))
        line.line(to: NSPoint(x: bounds.maxX, y: 0.5))
        line.stroke()

        let title = AchievementText.string("home.achievement_path")
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 21, weight: .heavy)]).width)
        HomeStyle.text(title, in: NSRect(x: 0, y: 11, width: titleWidth + 2, height: 30), size: 21, weight: .heavy)
        let count = AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count)
        let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]).width)
        let countX = titleWidth + 24
        HomeStyle.text(count, in: NSRect(x: countX, y: 18, width: countWidth + 2, height: 19), size: 13, weight: .semibold)
        let meterX = countX + countWidth + 15
        let meter = NSRect(x: meterX, y: 22, width: min(210, max(0, all.frame.minX - meterX - 64)), height: 9)
        HomeStyle.border.setFill()
        NSBezierPath(roundedRect: meter, xRadius: 5, yRadius: 5).fill()
        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
        if ratio > 0 {
            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 5)
        }
        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: 18, width: 50, height: 19),
                       size: 11, color: HomeStyle.secondary)
    }
}

final class HomeDashboardView: NSView {
    var onStart: (() -> Void)?
    var onMode: ((HomeGameMode) -> Void)?
    var onNavigate: ((String) -> Void)?
    var onAchievement: ((Int?) -> Void)?
    let startButton = HomeButton(frame: .zero)
    let modeHeader = HomeModeHeaderView(frame: .zero)
    let modePanel = HomeModePanelView(frame: .zero)
    let achievementPath = HomeAchievementPathView(frame: .zero)
    let contactPanel = HomeContactPanelView(frame: .zero)
    var challengeHUD: HomeChallengeHUDView { modeHeader.card }
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let hero = HomeHeroView()
    private let records = HomeButton(frame: .zero), rules = HomeButton(frame: .zero), settings = HomeButton(frame: .zero)
    private var modes: [HomeModeButton] = []
    private static let sectionGap: CGFloat = 24
    private static let contactHeight: CGFloat = 156

    private var margin: CGFloat { bounds.width < 1050 ? 32 : 44 }
    private var modePanelFrame: NSRect {
        let width = max(330, min(440, bounds.width * 0.34))
        let top: CGFloat = 96
        // 给联系卡和全宽成就栏留出空间，缩小窗口时优先收紧模式区。
        let reserved = Self.contactHeight + Self.sectionGap * 2 + HomeAchievementPathView.preferredHeight + 20
        let height = max(0, min(456, (bounds.height * 0.56).rounded(.down), bounds.height - top - reserved))
        return NSRect(x: bounds.width - margin - width, y: top, width: width, height: height)
    }

    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .aqua)
        hint.isSelectable = false
        hint.drawsBackground = false
        hint.textColor = HomeStyle.secondary
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.alignment = .center
        // 转场盖住左侧画面，右侧不透明模式面板与其按钮在转场上方。
        [hint, hero, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
        startButton.primary = true; startButton.symbolName = "play.fill"
        startButton.onClick = { [weak self] in self?.onStart?() }
        for (button, key) in [(records, "records"), (rules, "rules"), (settings, "settings")] {
            button.onClick = { [weak self] in self?.onNavigate?(key) }
        }
        achievementPath.onAchievement = { [weak self] id in self?.onAchievement?(id) }
        for mode in HomeGameMode.allCases {
            let button = HomeModeButton(mode: mode)
            button.onClick = { [weak self] in self?.onMode?(mode) }
            modePanel.addSubview(button); modes.append(button)
        }
        let puzzle = HomeModeButton(mode: nil)
        modes.insert(puzzle, at: 1)
        modePanel.addSubview(puzzle, positioned: .above, relativeTo: modes[0])
    }
    required init?(coder: NSCoder) { nil }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager, isStarting: Bool = false) {
        modeHeader.refresh(snapshot: snapshot, mode: mode, isStarting: isStarting)
        if isStarting {
            hint.stringValue = AchievementText.string("home.starting_hint")
        } else if snapshot.isFinished {
            hint.stringValue = AchievementText.string("home.round_finished")
        } else { hint.stringValue = AchievementText.string(snapshot.isRunning ? "home.operation_hint" : "home.start_hint") }
        startButton.title = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
        startButton.isEnabled = !isStarting
        startButton.setAccessibilityLabel(startButton.title)
        records.title = AchievementText.string("panel.records")
        rules.title = AchievementText.string("panel.rules")
        settings.title = AchievementText.string("panel.settings")
        achievementPath.refresh(manager: manager)
        contactPanel.refreshLanguage()
        modes.forEach { $0.refresh(selectedMode: mode) }
        modePanel.needsDisplay = true
        needsLayout = true; needsDisplay = true
        [startButton, records, rules, settings].forEach { $0.needsDisplay = true }
    }

    override func layout() {
        super.layout()
        let panel = modePanelFrame
        let leftWidth = panel.minX - margin - 32
        let top = panel.minY
        modePanel.frame = panel
        contactPanel.frame = NSRect(x: panel.minX, y: panel.maxY + Self.sectionGap, width: panel.width, height: Self.contactHeight)
        let bottom = contactPanel.frame.maxY
        let leftColumn = NSRect(x: margin, y: top, width: leftWidth, height: min(230, (bottom - top) * 0.33 + 56))
        modeHeader.position(leftColumn: leftColumn, windowWidth: bounds.width, modePanelLeading: panel.minX)
        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: bottom - 62, width: 294, height: 62)
        hint.preferredMaxLayoutWidth = leftWidth
        hint.frame = NSRect(x: margin, y: startButton.frame.minY - 43, width: leftWidth, height: 38)
        let heroY = (leftColumn.maxY + hint.frame.minY - 138) / 2
        hero.frame = NSRect(x: margin + 12, y: heroY, width: leftWidth - 24, height: 138)
        achievementPath.frame = NSRect(x: margin, y: bottom + Self.sectionGap,
                                       width: bounds.width - margin * 2, height: HomeAchievementPathView.preferredHeight)
        let rowGap: CGFloat = modePanel.isCompact ? 4 : 8
        let firstRowY: CGFloat = modePanel.isCompact ? 48 : 60
        let rowHeight = max(0, panel.height - firstRowY - 14 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
        for (index, button) in modes.enumerated() {
            button.frame = NSRect(x: 20, y: firstRowY + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
        }
        var navX = bounds.width - margin
        for button in [settings, rules, records] {
            let width = max(84, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width + 24)
            navX -= width
            button.frame = NSRect(x: navX, y: 19, width: width, height: 36)
            navX -= 8
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.background.setFill(); bounds.fill()
        let panel = modePanelFrame
        // 暖色环境光承接原设计稿插画；静态绘制，不添加常驻粒子计时器。
        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: panel.minX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
        // 低透明度装饰方块呼应四种颜色，避免盖住正文和交互区域。
        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), startButton.frame.maxY - 40, HomeStyle.yellow)] {
            color.withAlphaComponent(0.10).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 25, height: 25), xRadius: 5, yRadius: 5).fill()
        }
        for (index, color) in [NSColor.systemOrange, .systemBlue, .systemGreen, .systemRed].enumerated() {
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: margin + CGFloat(index % 2) * 16, y: 20 + CGFloat(index / 2) * 16, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
        }
        HomeStyle.text(AchievementText.string("home.brand"), in: NSRect(x: margin + 47, y: 18, width: 360, height: 38), size: 26, weight: .heavy)
        HomeStyle.border.withAlphaComponent(0.7).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 70))
        line.line(to: NSPoint(x: bounds.maxX, y: 70))
        line.stroke()
    }

}

/// 单独绘制右侧外框，让它能遮住滑到后方的统计卡。
final class HomeModePanelView: NSView {
    override var isFlipped: Bool { true }
    var isCompact: Bool { bounds.height < 340 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        GameLobbyStyle.surface(bounds, radius: 20,
                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
        HomeStyle.text(AchievementText.string("home.game_modes"),
                       in: NSRect(x: 22, y: isCompact ? 10 : 18, width: bounds.width - 44, height: 36),
                       size: isCompact ? 23 : 27, weight: .heavy)
    }
}

/// 联系卡沿用右栏的暖白材质，反馈按钮打开项目的问题跟踪页。
final class HomeContactPanelView: NSView {
    private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
    private let feedback = HomeButton(frame: .zero)
    var openURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        feedback.symbolName = "arrow.up.right"
        feedback.setAccessibilityRole(.link)
        feedback.onClick = { [weak self] in self?.openURL(Self.feedbackURL) }
        addSubview(feedback)
        refreshLanguage()
    }

    required init?(coder: NSCoder) { nil }

    func refreshLanguage() {
        let title = AchievementText.string("home.contact.action")
        guard feedback.title != title else { return }
        feedback.title = title
        feedback.setAccessibilityLabel(title)
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width
        let width = min(max(0, bounds.width - 44), ceil(titleWidth) + 56)
        feedback.frame = NSRect(x: 22, y: bounds.height - 56, width: width, height: 34)
    }

    override func draw(_ dirtyRect: NSRect) {
        GameLobbyStyle.surface(bounds, radius: 20,
                               tint: NSColor(calibratedRed: 0.98, green: 0.989, blue: 1, alpha: 1), strength: 0.035)
        let icon = NSRect(x: 22, y: 18, width: 46, height: 46)
        GameLobbyStyle.gradient(icon, colors: [NSColor(calibratedRed: 0.94, green: 0.99, blue: 1, alpha: 1),
                                                NSColor(calibratedRed: 0.82, green: 0.94, blue: 1, alpha: 1)], radius: 13)
        HomeStyle.symbol("ellipsis.bubble.fill", in: icon.insetBy(dx: 10, dy: 10), color: HomeStyle.blue)
        HomeStyle.text(AchievementText.string("home.contact.title"),
                       in: NSRect(x: 81, y: 24, width: bounds.width - 103, height: 34), size: 21, weight: .heavy)
        GameLobbyStyle.wrappedText(AchievementText.string("home.contact.description"),
                                   in: NSRect(x: 22, y: 72, width: bounds.width - 44, height: 25), size: 13, color: HomeStyle.secondary)
        HomeStyle.card(feedback.frame, fill: HomeStyle.blue.withAlphaComponent(0.08),
                       border: HomeStyle.blue.withAlphaComponent(0.12), radius: 8)
    }
}
