import Cocoa
import CoreText

/// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
class HomeButton: NSButton {
    enum Style { case navigation, primary, outline, achievementLink }
    var style: Style = .navigation
    var symbolName: String?
    var onClick: (() -> Void)?
    private var tracking: NSTrackingArea?
    private(set) var hovering = false
    let feedback = GameControlFeedback()

    static func standardTitleSize(for height: CGFloat) -> CGFloat { min(19, height * 0.44) }

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
    override func drawFocusRingMask() {
        HomeDashboardStyle.slant(bounds).fill()
    }
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
        let effect = feedback.values
        let offset = effect.press * 1.8 - effect.hover
        let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
        let primary = style == .primary
        let outlined = style == .outline
        let color = primary ? HomeDashboardStyle.navy : HomeDashboardStyle.ink
        if primary {
            let yellow = HomeDashboardStyle.yellow
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = yellow.withAlphaComponent(0.22 + effect.hover * 0.15)
            glow.shadowBlurRadius = 10
            glow.set()
            yellow.setFill()
            HomeDashboardStyle.slant(face).fill()
            NSGraphicsContext.restoreGraphicsState()
            HomeDashboardStyle.surface(face,
                                       colors: [HomeDashboardStyle.color(0xFFF87D), yellow, HomeDashboardStyle.color(0xF1CD23)],
                                       border: .white.withAlphaComponent(isEnabled ? 0.56 : 0.24))
            if !isEnabled {
                HomeDashboardStyle.navy.withAlphaComponent(0.36).setFill()
                HomeDashboardStyle.slant(face).fill()
            }
        } else if outlined || effect.hover > 0 {
            let cyan = HomeDashboardStyle.cyan
            HomeDashboardStyle.surface(face,
                                       colors: [cyan.withAlphaComponent(effect.hover * 0.10),
                                                cyan.withAlphaComponent(0.04 + effect.hover * 0.14)],
                                       border: cyan.withAlphaComponent(outlined ? 0.95 : effect.hover * 0.45),
                                       lineWidth: outlined ? 1.35 : 0.8)
        }
        let label = style == .achievementLink && title.hasSuffix("  →") ? String(title.dropLast(3)) : title
        let weight: NSFont.Weight = primary ? .black : .bold
        let icon: CGFloat = symbolName == nil ? 0 : (primary ? bounds.height * 0.44 : 16)
        let gap: CGFloat = icon > 0 ? 10 : 0
        let preferred = primary ? min(34, bounds.height * 0.52) : Self.standardTitleSize(for: bounds.height)
        let size = GameLobbyStyle.fittedSize(label, width: bounds.width - icon - gap - (primary ? 52 : 24),
                                             preferred: preferred, minimum: 10, weight: weight)
        let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
        let x = (bounds.width - width - icon - gap) / 2
        if let symbolName {
            let iconX = style == .achievementLink ? x + width + gap : x
            let iconColor = style == .achievementLink ? HomeDashboardStyle.yellow : color
            HomeStyle.symbol(symbolName, in: NSRect(x: iconX, y: face.midY - icon / 2, width: icon, height: icon), color: iconColor)
        }
        let textX = style == .achievementLink ? x : x + icon + gap
        HomeDashboardStyle.text(label, in: NSRect(x: textX, y: face.midY - size * 0.63, width: width + 8, height: size * 1.5),
                                size: size, weight: weight, color: color)
    }
    @objc private func clicked() { onClick?() }
}

final class HomeModeButton: HomeButton {
    static let iconPlateClearance: CGFloat = 8

    // 解谜暂时只是大厅入口，没有可交给棋盘控制器的游戏模式。
    let mode: HomeGameMode?
    private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
    private var descriptionKey: String { "home.mode_desc.\(mode?.key ?? "puzzle")" }
    private var displayedLanguage: AppLanguage?
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

    var faceRect: NSRect {
        let effect = feedback.values
        let inset = bounds.insetBy(dx: 1.2, dy: 1.2)
        return NSRect(x: inset.minX, y: inset.minY + Self.iconPlateClearance + effect.press * 1.4 - effect.hover,
                      width: inset.width, height: max(0, inset.height - Self.iconPlateClearance))
    }

    var iconPlateRect: NSRect {
        let face = faceRect
        let height = face.height * 0.77
        let width = face.height * 0.76 + HomeDashboardStyle.edgeOffset(for: height)
        let rise = min(Self.iconPlateClearance - 1, face.height * 0.13)
        return NSRect(x: face.minX + 1.5, y: face.minY - rise, width: width, height: height)
    }

    var modeIconRect: NSRect {
        let plate = iconPlateRect
        let size = min(44, plate.height * 0.64)
        return NSRect(x: plate.midX - size / 2, y: plate.midY - size / 2, width: size, height: size)
    }

    override var focusRingMaskBounds: NSRect { faceRect.union(iconPlateRect) }

    override func drawFocusRingMask() {
        HomeDashboardStyle.slant(faceRect).fill()
        HomeDashboardStyle.slant(iconPlateRect).fill()
    }

    func refresh(selectedMode: HomeGameMode) {
        selected = mode == selectedMode
        let language = Localizer.shared.language
        guard displayedLanguage != language else { return }
        displayedLanguage = language
        setAccessibilityLabel(AchievementText.string(titleKey) + ", " + AchievementText.string(descriptionKey))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let effect = feedback.values
        let face = faceRect
        guard face.height > 0, face.width > 0 else { return }
        let cyan = HomeDashboardStyle.cyan
        let tint = min(1, effect.selection + effect.hover * 0.26)
        let left = HomeDashboardStyle.color(0x222D35)
        let right = HomeDashboardStyle.color(0x101B29)
        let colors = [left.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0C3E46)) ?? left,
                      right.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0A2733)) ?? right]
        let stroke = HomeDashboardStyle.border.blended(withFraction: tint, of: cyan) ?? cyan
        HomeDashboardStyle.surface(face, colors: colors, border: stroke,
                                   lineWidth: 1 + 1.7 * effect.selection)
        drawIconPlate(iconPlateRect, tint: tint)
        drawModeIcon(in: modeIconRect, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
        let textX = face.minX + face.height * 0.83 + min(48, face.height * 0.56) + 13
        let textWidth = face.maxX - textX - max(31, face.height * 0.67)
        let title = AchievementText.string(titleKey)
        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(24, face.height * 0.34),
                                                  minimum: 13, weight: .heavy)
        let textY = face.midY - titleSize * 1.15
        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: titleSize * 1.5),
                                size: titleSize, weight: .heavy)
        let description = AchievementText.string(descriptionKey)
        let descriptionY = face.midY + 1
        let descriptionWidth = face.maxX - textX - max(18, face.height * 0.49)
        HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY,
                                                               width: descriptionWidth, height: face.maxY - descriptionY - 5),
                                       preferred: min(16, face.height * 0.23))
    }

    private func drawIconPlate(_ plate: NSRect, tint: CGFloat) {
        let depth = min(3.5, plate.height * 0.07)
        let side = HomeDashboardStyle.color(0x09151E)
        let activeSide = HomeDashboardStyle.color(0x12424B)
        (side.blended(withFraction: tint, of: activeSide) ?? side).setFill()
        HomeDashboardStyle.slant(plate.offsetBy(dx: depth, dy: depth)).fill()

        let upper = HomeDashboardStyle.color(0x354858)
        let lower = HomeDashboardStyle.color(0x162631)
        let edge = HomeDashboardStyle.color(0x617889)
        let cyan = HomeDashboardStyle.cyan
        HomeDashboardStyle.surface(plate,
                                   colors: [upper.blended(withFraction: tint, of: HomeDashboardStyle.color(0x236570)) ?? upper,
                                            lower.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0D303A)) ?? lower],
                                   border: edge.blended(withFraction: tint * 0.72, of: cyan) ?? edge)

        // 只提亮前层受光的一段上沿，让下沿的侧面保有厚度。
        let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
        let light = HomeDashboardStyle.color(0xB4D3E8).blended(withFraction: tint * 0.55, of: cyan) ?? cyan
        let highlight = NSRect(x: plate.minX + cut + 1.3, y: plate.minY + 1,
                               width: (plate.width - cut) * 0.81, height: 1)
        NSGradient(starting: light.withAlphaComponent(0.78), ending: light.withAlphaComponent(0))?
            .draw(in: highlight, angle: 0)
    }

    private func drawModeIcon(in rect: NSRect, color: NSColor) {
        switch mode {
        case .free:
            GameIconRenderer.drawSymbol("infinity", in: rect, color: color)
        case .timed:
            GameIconRenderer.drawSymbol("stopwatch", in: rect, color: color, fallbacks: ["timer"])
        case .moves:
            let tile = rect.insetBy(dx: 1, dy: rect.height * 0.12)
            let outline = NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4)
            color.setStroke()
            outline.lineWidth = 2.2
            outline.stroke()
            let size = tile.height * 0.61
            HomeDashboardStyle.text(String(HomeGameMode.moveLimit),
                                    in: NSRect(x: tile.minX, y: tile.midY - size * 0.58, width: tile.width, height: size * 1.3),
                                    size: size, weight: .heavy, color: color, alignment: .center)
        case nil:
            GameIconRenderer.drawSymbol("puzzlepiece", in: rect, color: color, fallbacks: ["square.dashed"])
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
            guard let self, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            self.phase += 0.06; self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    override func draw(_ dirtyRect: NSRect) {
        let animated = window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        HomeLobbyArtwork.drawHero(in: bounds, phase: phase, animated: animated)
    }
}

private final class HomeTouchBarGuideView: NSView {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private var lastTick: TimeInterval = 0
    private var reducesMotion = false

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    required init?(coder: NSCoder) { nil }

    deinit { timer?.invalidate() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }

        elapsed = 0
        lastTick = ProcessInfo.processInfo.systemUptime
        reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.advanceDemo()
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        needsDisplay = true
    }

    private func advanceDemo() {
        let now = ProcessInfo.processInfo.systemUptime
        let interval = now - lastTick
        lastTick = now
        guard let window, window.isVisible, !window.isMiniaturized, !isHiddenOrHasHiddenAncestor else { return }

        let previous = reducesMotion
        reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reducesMotion {
            // 窗口隐藏或系统休眠后保留当前阶段，避免恢复时直接跳到补位。
            elapsed = (elapsed + min(interval, 0.1)).truncatingRemainder(dividingBy: HomeTouchBarDemo.loopDuration)
        }
        if !reducesMotion || previous != reducesMotion { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = HomeTouchBarDemo.frame(at: elapsed, animated: window != nil && !reducesMotion)
        HomeLobbyArtwork.drawTouchBar(in: bounds, frame: frame)
        let canvas = HomeLobbyArtwork.touchBarCanvasSize
        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
        let size = min(19, max(12, scale * 19))
        let caption = AchievementText.string("home.operation_hint")
        let width = min(bounds.width * 0.63, (caption as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
        ]).width + 4)
        let x = bounds.width * 0.475 - width / 2
        let y = scale * 82
        HomeDashboardStyle.mark(in: NSRect(x: x - 20, y: y + 3, width: 10, height: size * 0.94))
        HomeDashboardStyle.text(caption, in: NSRect(x: x, y: y, width: width, height: size * 1.4),
                                size: size, weight: .medium, alignment: .center)
    }
}

private final class HomeAchievementButton: HomeButton {
    private static let iconSize: CGFloat = 28
    private static var iconBounds: [String: NSRect] = [:]
    private static var icons: [String: NSImage] = [:]
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
        let effect = feedback.values
        let border = HomeDashboardStyle.border.blended(withFraction: effect.hover * 0.66, of: HomeDashboardStyle.cyan) ?? HomeDashboardStyle.border
        HomeDashboardStyle.surface(bounds.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: effect.press),
                                   colors: [HomeDashboardStyle.color(0x212D37), HomeDashboardStyle.color(0x101B26)],
                                   border: border)
        let title = AchievementText.string(definition.titleKey)
        // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
        // 窄窗口先缩小字级，再按完整字符截短，避免较短的名称也出现省略号。
        let key = "\(definition.id).\(unlocked)"
        let color = unlocked ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
        let artwork = Self.icon(for: definition, color: color, key: key)
        let artworkBounds = Self.visibleBounds(of: artwork, key: key)
        let fixedWidth = ceil(artworkBounds.width) + 9
        // 覆盖状态图标及抗锯齿边缘，并为图文居中在另一侧预留同等空间。
        let statusX = max(14, HomeDashboardStyle.edgeOffset(for: bounds.height / 2) + 4)
        let availableWidth = max(0, floor(bounds.width - (statusX + 22) * 2 - fixedWidth))
        let preferredSize = min(17, max(12, bounds.height * 0.28))
        let titleSize = GameLobbyStyle.fittedSize(title, width: availableWidth - 2, preferred: preferredSize,
                                                  minimum: 12, weight: .bold)
        let font = NSFont.systemFont(ofSize: titleSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var characters = Array(title), displayedTitle = title
        while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
            characters.removeLast()
            displayedTitle = String(characters) + "…"
        }
        if (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth { displayedTitle = "" }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: displayedTitle, attributes: [
            .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]))
        // 按截断后字形的实际轮廓居中，兼顾没有下伸笔画的标题和各语言的字体回退。
        let tilt = CGAffineTransform(a: 1, b: 0, c: HomeDashboardStyle.letterSlant, d: 1, tx: 0, ty: 0)
        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).applying(tilt)
        let titleWidth = displayedTitle.isEmpty || textBounds.isNull ? 0 : textBounds.width
        let startX = bounds.midX - (fixedWidth + titleWidth) / 2
        let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
        HomeStyle.symbol(status, in: NSRect(x: statusX, y: bounds.midY - 9, width: 18, height: 18),
                         color: unlocked ? HomeDashboardStyle.green : HomeDashboardStyle.muted)
        artwork.draw(in: NSRect(x: startX - artworkBounds.minX, y: bounds.midY - artworkBounds.midY,
                               width: Self.iconSize, height: Self.iconSize),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if titleWidth > 0, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            // 当前视图的 y 向下，文字绘制坐标的 y 向上。
            context.translateBy(x: startX + fixedWidth - textBounds.minX, y: bounds.midY + textBounds.midY)
            context.scaleBy(x: 1, y: -1)
            context.textMatrix = tilt
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    private static func icon(for definition: AchievementDefinition, color: NSColor, key: String) -> NSImage {
        if let icon = icons[key] { return icon }
        let symbols = [
            1: "trophy", 2: "waveform", 3: "flag", 4: "sparkle", 5: "square.stack",
            6: "square.3.layers.3d", 7: "link", 8: "wifi", 9: "point.topleft.down.to.point.bottomright.curvepath",
            10: "stopwatch", 11: "stopwatch", 12: "stopwatch", 13: "flag.checkered", 14: "scope",
            15: "scope", 16: "flag.checkered", 20: "ticket",
        ]
        let size = NSSize(width: iconSize, height: iconSize)
        let icon = NSImage(size: size, flipped: true) { rect in
            if let symbol = symbols[definition.id] {
                GameIconRenderer.drawSymbol(symbol, in: rect, color: color)
            } else {
                AchievementIconCatalog.image(for: definition, muted: false)
                    .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                color.setFill()
                rect.fill(using: .sourceAtop)
            }
            return true
        }
        icons[key] = icon
        return icon
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
    var onAchievement: ((Int?) -> Void)?
    private let all = HomeButton(frame: .zero)
    private var badges: [HomeAchievementButton] = []
    private var unlockedCount = 0

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(all)
        all.style = .achievementLink
        all.symbolName = "arrow.right"
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
        let title = AchievementText.string("achievement.view_all") + "  →"
        if all.title != title {
            all.title = title
            all.setAccessibilityLabel(AchievementText.string("achievement.view_all"))
            all.needsDisplay = true
            needsLayout = true
            needsDisplay = true
        }
        let unlocked = Set(manager.unlockedIDs())
        if unlockedCount != unlocked.count {
            unlockedCount = unlocked.count
            needsDisplay = true
        }
        let definitions = AchievementDefinition.all.sorted {
            let a = unlocked.contains($0.id), b = unlocked.contains($1.id)
            return a == b ? $0.id < $1.id : a
        }
        for (badge, definition) in zip(badges, definitions) { badge.refresh(definition, manager: manager) }
    }

    override func layout() {
        super.layout()
        let titleWidth = (all.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
        let linkWidth = max(120, titleWidth + 34)
        all.frame = NSRect(x: max(0, bounds.width - linkWidth), y: 11, width: linkWidth, height: 36)
        let width = bounds.width
        let gap: CGFloat = 10
        let columns = min(badges.count, max(5, Int((width + gap) / 193)))
        let badgeWidth = max(0, width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let rowY = min(71, bounds.height * 0.46)
        for (index, badge) in badges.enumerated() {
            badge.isHidden = index >= columns
            guard !badge.isHidden else { continue }
            badge.frame = NSRect(x: CGFloat(index) * (badgeWidth + gap), y: rowY, width: badgeWidth, height: min(62, bounds.height - rowY))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        HomeDashboardStyle.line(from: NSPoint(x: 0, y: 0.5), to: NSPoint(x: bounds.maxX, y: 0.5), color: HomeDashboardStyle.border)
        HomeDashboardStyle.mark(in: NSRect(x: 0, y: 19, width: 19, height: 21))
        let title = AchievementText.string("home.achievement_path")
        let size: CGFloat = bounds.width < 1050 ? 21 : 25
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).width)
        HomeDashboardStyle.text(title, in: NSRect(x: 27, y: 13, width: titleWidth + 12, height: 36),
                                size: size, weight: .heavy)
        let count = AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count)
        let countSize: CGFloat = bounds.width < 1050 ? 13 : 17
        let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: countSize, weight: .semibold)]).width)
        let countX = titleWidth + 56
        HomeDashboardStyle.text(count, in: NSRect(x: countX, y: 29 - countSize * 0.61, width: countWidth + 3, height: 23),
                                size: countSize, weight: .semibold)
        let meterX = countX + countWidth + 28
        let meter = NSRect(x: meterX, y: 24, width: min(bounds.width * 0.21, max(0, all.frame.minX - meterX - 78)), height: 12)
        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
        let countSegments = 10
        let gap: CGFloat = 2
        let inset = HomeDashboardStyle.edgeOffset(for: meter.height)
        let pitch = (meter.width - inset + gap) / CGFloat(countSegments)
        for index in 0..<countSegments where pitch > gap {
            let segment = NSRect(x: meter.minX + CGFloat(index) * pitch, y: meter.minY,
                                 width: pitch - gap + inset, height: meter.height)
            HomeDashboardStyle.border.setFill()
            HomeDashboardStyle.slant(segment).fill()
            let fill = ratio * CGFloat(countSegments) - CGFloat(index)
            HomeDashboardStyle.yellow.setFill()
            HomeDashboardStyle.segmentFill(segment, fraction: fill).fill()
        }
        let percentage = Double(ratio).formatted(.percent.precision(.fractionLength(1)).locale(Localizer.shared.locale))
        HomeDashboardStyle.text(percentage, in: NSRect(x: meter.maxX + 15, y: 19, width: 58, height: 23),
                                size: min(16, countSize), weight: .semibold)
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
    private let guide = HomeTouchBarGuideView(frame: .zero)
    private let records = HomeButton(frame: .zero), rules = HomeButton(frame: .zero), settings = HomeButton(frame: .zero)
    private var modes: [HomeModeButton] = []
    private var shortcut = NSRect.zero
    private var showsShortcut = true
    private var displayedLanguage: AppLanguage?

    private static let minimumBrandSize: CGFloat = 16
    private var margin: CGFloat { max(29, bounds.width * 0.034) }
    private var headerHeight: CGFloat { min(76, max(56, bounds.height * 0.071)) }
    private var brandLeadingX: CGFloat { margin + 12 + 72 + 27 }
    private var sectionTop: CGFloat { max(headerHeight + 20, bounds.height * 0.105) }
    private var achievementTop: CGFloat { bounds.height * 0.815 }
    private var stageBottom: CGFloat { achievementTop - max(35, bounds.height * 0.058) }
    private var rightWidth: CGFloat { min(max(302, bounds.width * 0.33), max(0, bounds.width - margin * 2)) }

    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        hint.isSelectable = false
        hint.drawsBackground = false
        [hero, guide, hint, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
        startButton.style = .primary
        startButton.symbolName = "play.fill"
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
        modeHeader.refresh(snapshot: snapshot, mode: mode)
        let status: String
        if isStarting {
            status = AchievementText.string("home.starting_hint")
        } else if snapshot.isFinished {
            status = AchievementText.string("home.round_finished")
        } else {
            status = snapshot.isRunning ? "" : AchievementText.string("home.start_hint")
        }
        let shortcutAvailable = !isStarting && !snapshot.isRunning
        if hint.stringValue != status || showsShortcut != shortcutAvailable {
            updateHint(status)
            hint.isHidden = status.isEmpty
            showsShortcut = shortcutAvailable
            setNeedsDisplay(hint.frame.insetBy(dx: -22, dy: 0).union(shortcut))
        }
        let startTitle = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
        if startButton.title != startTitle || startButton.isEnabled == isStarting {
            startButton.title = startTitle
            startButton.isEnabled = !isStarting
            startButton.setAccessibilityLabel(startTitle)
            startButton.needsDisplay = true
        }
        let language = Localizer.shared.language
        if displayedLanguage != language {
            displayedLanguage = language
            records.title = AchievementText.string("panel.records")
            rules.title = AchievementText.string("panel.rules")
            settings.title = AchievementText.string("panel.settings")
            contactPanel.refreshLanguage()
            guide.setAccessibilityLabel(AchievementText.string("home.operation_hint"))
            [guide, modePanel, achievementPath, records, rules, settings].forEach { $0.needsDisplay = true }
            needsLayout = true
            needsDisplay = true
        }
        achievementPath.refresh(manager: manager)
        modes.forEach { $0.refresh(selectedMode: mode) }
    }

    override func layout() {
        super.layout()
        let rightX = bounds.width - margin - rightWidth
        let contactHeight = min(165, max(110, bounds.height * 0.152))
        let verticalGap = min(52, max(27, bounds.height * 0.050))
        let contactTop = stageBottom - contactHeight
        // 模式列沿右边对齐，为规则牌的右上斜角预留空间。联系卡仍沿右栏外缘排版。
        let modeInset = min(rightWidth * 0.12, max(0, rightWidth - 302), bounds.width * 0.038)
        let panel = NSRect(x: rightX + modeInset, y: sectionTop, width: rightWidth - modeInset,
                           height: max(0, contactTop - verticalGap - sectionTop))
        modePanel.frame = panel
        modePanel.needsDisplay = true
        contactPanel.frame = NSRect(x: rightX, y: contactTop, width: rightWidth, height: contactHeight)
        let leftWidth = max(0, rightX - margin - 20)
        let leftColumn = NSRect(x: margin, y: sectionTop, width: leftWidth, height: bounds.height * 0.245)
        modeHeader.position(leftColumn: leftColumn, windowWidth: bounds.width, modePanelLeading: panel.minX)
        let artworkWidth = leftWidth * 0.95
        let artworkY = leftColumn.maxY - 1
        hero.frame = NSRect(x: margin, y: artworkY, width: artworkWidth, height: max(0, bounds.height * 0.539 - artworkY))

        let buttonHeight = min(68, max(48, bounds.height * 0.068))
        let buttonWidth = min(435, leftWidth * 0.55)
        let shortcutWidth = min(92, max(65, leftWidth * 0.10))
        let gap: CGFloat = 12
        let startX = margin + (leftWidth - buttonWidth - gap - shortcutWidth) / 2
        startButton.frame = NSRect(x: startX, y: stageBottom - buttonHeight, width: buttonWidth, height: buttonHeight)
        shortcut = NSRect(x: startButton.frame.maxX + gap, y: startButton.frame.midY - 13, width: shortcutWidth, height: 26)
        let guideY = bounds.height * 0.546
        let guideHeight = max(0, startButton.frame.minY - guideY - 12)
        guide.frame = NSRect(x: margin, y: guideY, width: artworkWidth, height: guideHeight)

        hint.preferredMaxLayoutWidth = buttonWidth + 100
        updateHint(hint.stringValue)
        hint.frame = NSRect(x: startButton.frame.midX - hint.preferredMaxLayoutWidth / 2, y: stageBottom + 8,
                            width: hint.preferredMaxLayoutWidth, height: max(0, achievementTop - stageBottom - 10))
        achievementPath.frame = NSRect(x: margin, y: achievementTop, width: bounds.width - margin * 2,
                                       height: max(0, bounds.height - achievementTop - min(30, bounds.height * 0.031)))
        let frontClearance = HomeModeButton.iconPlateClearance
        let rowGap = min(13, max(frontClearance + 1, bounds.height * 0.012))
        let firstRowY: CGFloat = modePanel.isCompact ? 49 : 57
        let rowHeight = max(0, panel.height - firstRowY - 4 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
        for (index, button) in modes.enumerated() {
            let x = CGFloat(modes.count - 1 - index) * min(5, bounds.width * 0.0039)
            // 把伸出上沿的前层纳入按钮范围，绘制不会被裁切，图标也可以点击。
            button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap) - frontClearance,
                                  width: max(0, panel.width - 15), height: rowHeight + frontClearance)
        }
        layoutNavigation()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        HomeDashboardStyle.backdrop(in: bounds)
        drawNavigation()

        HomeDashboardStyle.line(from: NSPoint(x: contactPanel.frame.minX + 28, y: contactPanel.frame.minY - 24),
                                to: NSPoint(x: contactPanel.frame.maxX, y: contactPanel.frame.minY - 24),
                                color: HomeDashboardStyle.border.withAlphaComponent(0.77))
        if showsShortcut {
            HomeDashboardStyle.surface(shortcut, colors: [HomeDashboardStyle.color(0x1B2632), HomeDashboardStyle.navy],
                                       border: HomeDashboardStyle.muted)
            HomeDashboardStyle.text(AchievementText.string("home.space_key"),
                                    in: shortcut.offsetBy(dx: 0, dy: 4), size: 13, weight: .bold, alignment: .center)
        }
        if !hint.isHidden {
            let font = hintFont
            let width = (hint.stringValue as NSString).size(withAttributes: [.font: font]).width
            let x = hint.frame.midX - min(width, hint.frame.width) / 2 - 20
            let size = HomeDashboardStyle.hintMarkSize(for: font.pointSize)
            HomeDashboardStyle.mark(in: NSRect(origin: NSPoint(x: x, y: hint.frame.minY + 3), size: size))
        }
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsLayout = true
    }

    private var hintFont: NSFont {
        .systemFont(ofSize: HomeDashboardStyle.hintPointSize(for: bounds.width), weight: .medium)
    }

    private func updateHint(_ value: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attributes = HomeDashboardStyle.textAttributes(font: hintFont)
        attributes[.paragraphStyle] = paragraph
        hint.attributedStringValue = NSAttributedString(string: value, attributes: attributes)
    }

    private func layoutNavigation() {
        let buttons = [settings, rules, records]
        let horizontalPadding: CGFloat = 24
        let gap: CGFloat = 19
        let rightEdge = bounds.maxX - margin + 5
        let brand = AchievementText.string("home.brand")
        let brandFont = NSFont.systemFont(ofSize: Self.minimumBrandSize, weight: .black)
        let brandWidth = ceil((brand as NSString).size(withAttributes: [.font: brandFont]).width)
        let available = rightEdge - brandLeadingX - brandWidth - 26 - CGFloat(buttons.count - 1) * gap

        func widths(for height: CGFloat) -> [CGFloat] {
            let font = NSFont.systemFont(ofSize: HomeButton.standardTitleSize(for: height), weight: .bold)
            return buttons.map { button in
                let titleWidth = (button.title as NSString).size(withAttributes: [.font: font]).width
                return max(89, ceil(titleWidth) + 2 * horizontalPadding)
            }
        }

        // 窄窗中的长译文共用略小的字号，给品牌和按钮两侧的留白都留足空间。
        var height: CGFloat = 40
        var buttonWidths = widths(for: height)
        while buttonWidths.reduce(0, +) > available, height > 33 {
            height -= 1
            buttonWidths = widths(for: height)
        }

        var x = rightEdge
        for (button, width) in zip(buttons, buttonWidths) {
            x -= width
            button.frame = NSRect(x: x, y: (headerHeight - height) / 2, width: width, height: height)
            x -= gap
        }
    }

    private func drawNavigation() {
        let y = headerHeight / 2
        let logoX = margin + 12
        let logoColors: [UInt32] = [0x35F4FF, 0xFFF052, 0xFA725F, 0xAF80F0]
        for (index, rgb) in logoColors.enumerated() {
            let x = logoX + CGFloat(index % 2) * 24 + (index < 2 ? 0 : 4)
            let tile = NSRect(x: x, y: y - 16 + CGFloat(index / 2) * 17, width: 27, height: 14)
            HomeDashboardStyle.mark(in: tile, color: HomeDashboardStyle.color(rgb))
        }
        let slashX = logoX + 72
        HomeDashboardStyle.diagonal(from: NSPoint(x: slashX + HomeDashboardStyle.edgeOffset(for: 32), y: y - 16),
                                    height: 32, color: HomeDashboardStyle.muted.withAlphaComponent(0.62), width: 1.3)

        let brand = AchievementText.string("home.brand")
        let brandX = brandLeadingX
        let brandWidth = max(0, records.frame.minX - brandX - 16)
        let preferred = min(34, max(25, bounds.width * 0.023))
        let size = GameLobbyStyle.fittedSize(brand, width: brandWidth - 10, preferred: preferred,
                                           minimum: Self.minimumBrandSize, weight: .black)
        let measuredWidth = (brand as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .black)]).width
        HomeDashboardStyle.text(brand, in: NSRect(x: brandX, y: y - size * 0.65, width: brandWidth, height: size * 1.52),
                                size: size, weight: .black)
        if brandWidth - measuredWidth > 132, bounds.width >= 1050 {
            HomeDashboardStyle.text("TOUCH BAR", in: NSRect(x: brandX + measuredWidth + 23, y: y - 8, width: 99, height: 19),
                                    size: 13, weight: .medium, color: HomeDashboardStyle.muted)
        }
        for button in [rules, settings] {
            HomeDashboardStyle.mark(in: NSRect(x: button.frame.minX - 15, y: y - 8, width: 11, height: 17))
        }
        HomeDashboardStyle.line(from: NSPoint(x: 0, y: headerHeight), to: NSPoint(x: bounds.maxX, y: headerHeight),
                                color: HomeDashboardStyle.border)
    }

}

/// 右栏标题和游戏模式按钮共用同一布局区域。
final class HomeModePanelView: NSView {
    override var isFlipped: Bool { true }
    var isCompact: Bool { bounds.height < 340 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let size: CGFloat = isCompact ? 24 : 29
        HomeDashboardStyle.mark(in: NSRect(x: 26, y: 7, width: 21, height: size * 0.83))
        HomeDashboardStyle.text(AchievementText.string("home.game_modes"),
                                in: NSRect(x: 54, y: 0, width: bounds.width - 60, height: 41),
                                size: size, weight: .black)
    }
}

/// 反馈按钮打开项目的问题跟踪页。
final class HomeContactPanelView: NSView {
    private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
    private let feedback = HomeButton(frame: .zero)
    var openURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        feedback.symbolName = "arrow.up.right"
        feedback.style = .outline
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
        let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
        let width = min(max(0, bounds.width - 84), max(bounds.width * 0.52, ceil(titleWidth) + 67))
        let height = min(47, bounds.height * 0.31)
        feedback.frame = NSRect(x: bounds.height * 0.38 + 12, y: bounds.height - height - bounds.height * 0.12,
                                width: width, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let cut = HomeDashboardStyle.edgeOffset(for: bounds.height)
        HomeDashboardStyle.surface(bounds, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
                                   border: HomeDashboardStyle.color(0x344C65))
        let size = min(43, bounds.height * 0.29)
        let icon = NSRect(x: cut + 11, y: bounds.height * 0.145, width: size, height: size)
        HomeStyle.symbol("ellipsis.bubble", in: icon, color: HomeDashboardStyle.ink)
        let textX = icon.maxX + 13
        let textWidth = max(0, bounds.width - textX - cut * 0.69)
        let title = AchievementText.string("home.contact.title")
        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, bounds.height * 0.18),
                                                 minimum: 13, weight: .heavy)
        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: bounds.height * 0.067, width: textWidth, height: 35),
                                size: titleSize, weight: .heavy)
        let description = AchievementText.string("home.contact.description")
        let descriptionY = bounds.height * 0.325
        HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY, width: textWidth,
                                                               height: feedback.frame.minY - descriptionY - 4),
                                       preferred: min(17, bounds.height * 0.12))
    }
}
