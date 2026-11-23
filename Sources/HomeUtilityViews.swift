import Cocoa

/// 辅助页共用首页材质；文字使用原生视图，支持换行和辅助功能。
enum UtilityStyle {
    static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                      color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .natural,
                      monospacedDigits: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.font = monospacedDigits ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
                                      : .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = alignment
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        setText(text, on: label)
        return label
    }

    static func setText(_ text: String, on label: NSTextField) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = label.alignment
        paragraph.lineBreakMode = label.lineBreakMode
        label.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: label.font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: label.textColor ?? HomeDashboardStyle.ink,
            .paragraphStyle: paragraph,
            .obliqueness: HomeDashboardStyle.letterSlant,
        ])
    }
    static func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 10) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .leading : .centerY
        if !vertical { stack.distribution = .fill }
        stack.spacing = spacing
        if vertical {
            for label in views.compactMap({ $0 as? NSTextField }) { fillWidth(label, in: stack) }
        }
        return stack
    }
    static func fillWidth(_ view: NSView, in parent: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: parent.widthAnchor).isActive = true
    }
    static func text(_ key: String) -> String { AchievementText.string(key) }
    static func icon(_ symbol: String, color: NSColor, size: CGFloat = 24) -> NSView {
        let view = UtilityArtworkView(symbol: symbol, color: color)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([view.widthAnchor.constraint(equalToConstant: size), view.heightAnchor.constraint(equalToConstant: size)])
        return view
    }

    static func drawCard(_ rect: NSRect, accent: NSColor? = nil) {
        let top = HomeDashboardStyle.panel
        let base = HomeDashboardStyle.color(0x101C28)
        let tint = accent.flatMap { top.blended(withFraction: 0.12, of: $0) } ?? top
        let outline = accent?.withAlphaComponent(0.62) ?? HomeDashboardStyle.border
        HomeDashboardStyle.surface(rect, colors: [tint, base], border: outline)
    }
}

/// 彩色矢量始终等比绘制，不依赖字体附件的基线。
final class UtilityArtworkView: NSView {
    let symbol: String
    let color: NSColor
    init(symbol: String, color: NSColor) {
        self.symbol = symbol; self.color = color
        super.init(frame: .zero); setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { HomeStyle.symbol(symbol, in: bounds.insetBy(dx: 2, dy: 2), color: color) }
}

final class UtilityCard: NSView {
    private let accent: NSColor?

    convenience init(_ content: NSView, accent: NSColor? = nil, padding: CGFloat = 20) {
        self.init(rows: [content], accent: accent, padding: padding)
    }

    init(rows: [NSView], accent: NSColor? = nil, padding: CGFloat = 20, spacing: CGFloat = 0) {
        self.accent = accent
        super.init(frame: .zero)
        var top = topAnchor
        for (index, row) in rows.enumerated() {
            row.translatesAutoresizingMaskIntoConstraints = false
            addSubview(row)
            row.topAnchor.constraint(equalTo: top, constant: index == 0 ? padding : spacing).isActive = true
            constrainToSlantedEdges(row, padding: padding)
            top = row.bottomAnchor
        }
        bottomAnchor.constraint(equalTo: top, constant: padding).isActive = true
        // 斜边把宽高联在一起。优先贴合内容高度，避免水平抱紧约束靠拉高卡片缩短各行。
        let fittedHeight = heightAnchor.constraint(equalToConstant: 0)
        fittedHeight.priority = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultHigh.rawValue - 1)
        fittedHeight.isActive = true
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent) }

    private func constrainToSlantedEdges(_ row: NSView, padding: CGFloat) {
        let left = NSLayoutGuide()
        let right = NSLayoutGuide()
        addLayoutGuide(left)
        addLayoutGuide(right)
        // 左上角和右下角最接近边框。以这两处的垂直距离换算水平留白。
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leadingAnchor),
            left.trailingAnchor.constraint(equalTo: row.leadingAnchor),
            left.topAnchor.constraint(equalTo: row.topAnchor),
            left.bottomAnchor.constraint(equalTo: bottomAnchor),
            left.widthAnchor.constraint(equalTo: left.heightAnchor, multiplier: HomeDashboardStyle.slope, constant: padding),
            right.leadingAnchor.constraint(equalTo: row.trailingAnchor),
            right.trailingAnchor.constraint(equalTo: trailingAnchor),
            right.topAnchor.constraint(equalTo: topAnchor),
            right.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            right.widthAnchor.constraint(equalTo: right.heightAnchor, multiplier: HomeDashboardStyle.slope, constant: padding)
        ])
    }
}

/// 标题固定、正文独立滚动，在小屏幕与长翻译下不裁切内容。
private final class UtilityDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class UtilityPageView: NSView {
    let scroll = NSScrollView()
    let document: NSView = UtilityDocumentView()
    let sections = UtilityStyle.stack([])
    private let title = UtilityStyle.label("", size: 23, weight: .bold)
    private let subtitle = UtilityStyle.label("", size: 12, color: HomeDashboardStyle.muted)

    init(page: String) {
        super.init(frame: .zero)
        let symbol = page == "settings" ? "slider.horizontal.3" : page == "rules" ? "gamecontroller.fill" : "trophy"
        let artwork = UtilityStyle.icon(symbol, color: page == "records" ? HomeDashboardStyle.yellow : HomeDashboardStyle.cyan, size: 32)
        let headings = UtilityStyle.stack([title, subtitle], spacing: 5)
        let header = UtilityStyle.stack([artwork, headings], vertical: false, spacing: 14)
        header.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        addSubview(header); addSubview(scroll)
        document.translatesAutoresizingMaskIntoConstraints = false
        sections.translatesAutoresizingMaskIntoConstraints = false; sections.spacing = 14
        document.addSubview(sections); scroll.documentView = document
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 26),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            sections.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
            sections.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
            sections.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
            sections.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -4)
        ])
        headings.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { HomeDashboardStyle.backdrop(in: bounds) }
    func refreshHeader(page: String) {
        UtilityStyle.setText(UtilityStyle.text("panel.\(page)"), on: title)
        UtilityStyle.setText(UtilityStyle.text("utility.\(page).subtitle"), on: subtitle)
    }
    func addSection(_ view: NSView) {
        sections.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: sections)
    }
    func removeSections() {
        for view in sections.arrangedSubviews { sections.removeArrangedSubview(view); view.removeFromSuperview() }
    }
}

/// 保留原生菜单和辅助功能，只重绘游戏主题外观。
final class UtilityLanguagePopup: NSPopUpButton {
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 44) }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { HomeDashboardStyle.slant(bounds).fill() }
    override func draw(_ dirtyRect: NSRect) {
        UtilityStyle.drawCard(bounds, accent: isHighlighted ? HomeDashboardStyle.cyan : nil)
        HomeDashboardStyle.text(title, in: NSRect(x: 19, y: bounds.midY - 10, width: bounds.width - 58, height: 22),
                                size: 14, weight: .semibold)
        HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeDashboardStyle.cyan)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// 原生滑杆负责拖动与键盘步进，深色轨道突出黄色进度。
final class UtilityVolumeSliderCell: NSSliderCell {
    override var knobThickness: CGFloat { 22 }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        // 原生旋钮的光学中心与 barRect 有细微偏移，轨道以旋钮中心为准。
        let track = NSRect(x: rect.minX, y: knobRect(flipped: flipped).midY - 3, width: rect.width, height: 6)
        NSGraphicsContext.saveGraphicsState()
        if !flipped {
            let orient = NSAffineTransform()
            orient.translateX(by: 0, yBy: track.midY * 2)
            orient.scaleX(by: 1, yBy: -1)
            orient.concat()
        }
        HomeDashboardStyle.border.setFill()
        HomeDashboardStyle.slant(track).fill()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        HomeDashboardStyle.yellow.setFill()
        HomeDashboardStyle.segmentFill(track, fraction: fraction).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    override func drawKnob(_ knobRect: NSRect) {
        let knob = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = HomeDashboardStyle.yellow.withAlphaComponent(0.36)
        shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
        HomeDashboardStyle.navy.setFill(); NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
        HomeDashboardStyle.yellow.withAlphaComponent(0.75).setStroke()
        NSBezierPath(ovalIn: knob.insetBy(dx: 0.5, dy: 0.5)).stroke()
        HomeDashboardStyle.yellow.setFill(); NSBezierPath(ovalIn: knob.insetBy(dx: 7, dy: 7)).fill()
    }
}

/// 静态游戏示意不增加定时器，不参与真实棋盘状态。
final class UtilityLessonArtwork: NSView {
    let step: Int
    init(step: Int) {
        self.step = step; super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let preferredWidth = widthAnchor.constraint(equalToConstant: 72)
        preferredWidth.priority = .defaultLow
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 48), widthAnchor.constraint(lessThanOrEqualToConstant: 72),
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.52), preferredWidth
        ])
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let fit = NSAffineTransform()
        fit.scale(by: min(bounds.width / 100, bounds.height / 52))
        fit.concat()
        if step == 0 {
            HomeStyle.piece(.orangeRicky, in: NSRect(x: 0, y: 14, width: 33, height: 24))
            HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeDashboardStyle.muted)
            HomeStyle.piece(.blueRicky, in: NSRect(x: 65, y: 14, width: 33, height: 24))
        } else {
            let rows = step == 1 ? 1 : 2
            for row in 0..<rows {
                for column in 0..<3 {
                    let tile = NSRect(x: 19 + CGFloat(column) * 21, y: CGFloat(rows == 1 ? 17 : 7) + CGFloat(row) * 21, width: 18, height: 18)
                    let color = row == 0 ? HomeDashboardStyle.cyan : HomeDashboardStyle.green
                    NSGradient(colors: [color.blended(withFraction: 0.25, of: .white)!, color])?.draw(in: NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4), angle: -90)
                    NSColor.white.withAlphaComponent(0.4).setStroke()
                    NSBezierPath(roundedRect: tile.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).stroke()
                }
            }
        }
    }
}

enum UtilityRulesContent {
    static func populate(_ page: UtilityPageView, mode: HomeGameMode) {
        page.removeSections()
        let lessons = UtilityStyle.stack([], spacing: 8)
        for step in 0..<3 {
            let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeDashboardStyle.cyan)
            number.widthAnchor.constraint(equalToConstant: 25).isActive = true
            let title = UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold)
            title.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let heading = UtilityStyle.stack([number, title, UtilityLessonArtwork(step: step)], vertical: false, spacing: 9)
            let body = UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeDashboardStyle.muted)
            // 标题和说明各自沿边框排版。说明使用整个横截面，插图不会挤占文案宽度。
            heading.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
            body.heightAnchor.constraint(greaterThanOrEqualToConstant: 25).isActive = true
            let stepCard = UtilityCard(rows: [heading, body], padding: 10, spacing: 4)
            lessons.addArrangedSubview(stepCard)
            UtilityStyle.fillWidth(stepCard, in: lessons)
        }
        page.addSection(lessons)
        page.addSection(UtilityStyle.label(UtilityStyle.text("utility.rules.modes"), size: 14, weight: .bold))
        let modes = UtilityStyle.stack([], spacing: 10)
        for candidate in HomeGameMode.allCases {
            let selected = candidate == mode
            let copy = UtilityStyle.stack([
                UtilityStyle.label(UtilityStyle.text("home.mode.\(candidate.key)"), size: 13, weight: .bold),
                UtilityStyle.label(UtilityStyle.text("home.mode_desc.\(candidate.key)"), size: 12, color: HomeDashboardStyle.muted)
            ], spacing: 3)
            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let row = UtilityStyle.stack([UtilityStyle.icon(candidate.symbol, color: selected ? HomeDashboardStyle.cyan : HomeDashboardStyle.muted, size: 26), copy], vertical: false, spacing: 13)
            if selected {
                let current = UtilityStyle.label(UtilityStyle.text("utility.rules.current"), size: 10, weight: .semibold, color: HomeDashboardStyle.cyan)
                current.setContentHuggingPriority(.required, for: .horizontal)
                current.setContentCompressionResistancePriority(.required, for: .horizontal)
                row.addArrangedSubview(current)
            }
            let card = UtilityCard(row, accent: selected ? HomeDashboardStyle.cyan : nil, padding: 12)
            modes.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: modes)
        }
        page.addSection(modes)
        let note = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeDashboardStyle.muted, size: 19),
                                     UtilityStyle.label(UtilityStyle.text("utility.rules.progress"), size: 11, color: HomeDashboardStyle.muted)], vertical: false, spacing: 10)
        page.addSection(UtilityCard(note, padding: 14))
    }
}

enum UtilityRecordContent {
    /// 数字为视觉中心，并明确当前榜单的固定规则。
    static func best(mode: ModeRecordKey, entry: ModeRecord?) -> NSView {
        let metric = entry.map { String($0.clearedCount) } ?? "—"
        let value = UtilityStyle.label(metric, size: 38, weight: .heavy, color: HomeDashboardStyle.yellow, monospacedDigits: true)
        let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeDashboardStyle.muted)
        let copy = UtilityStyle.stack([
            UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeDashboardStyle.muted),
            UtilityStyle.stack([value, unit], vertical: false, spacing: 8),
            UtilityStyle.label(UtilityStyle.text(mode == .timed ? "utility.records.timed_rule" : "utility.records.moves_rule"), size: 11, color: HomeDashboardStyle.muted)
        ], spacing: 4)
        let icon = UtilityStyle.icon(mode == .timed ? HomeGameMode.timed.symbol : HomeGameMode.moves.symbol, color: HomeDashboardStyle.yellow, size: 56)
        let row = UtilityStyle.stack([copy, icon], vertical: false, spacing: 16)
        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return UtilityCard(row, accent: HomeDashboardStyle.yellow, padding: 18)
    }

    static func table(entries: [ModeRecord]) -> NSView {
        if entries.isEmpty {
            let empty = UtilityStyle.stack([
                UtilityStyle.icon("flag.checkered", color: HomeDashboardStyle.muted, size: 40),
                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold, alignment: .center),
                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted,
                                   alignment: .center)
            ], spacing: 12)
            empty.alignment = .centerX
            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 148).isActive = true
            return UtilityCard(empty, padding: 16)
        }

        let headings = recordColumns(
            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold,
                               color: HomeDashboardStyle.muted, alignment: .center),
            UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold,
                               color: HomeDashboardStyle.muted, alignment: .right)
        )
        let headerCard = UtilityCard(headings, padding: 7)
        let cards = UtilityStyle.stack([headerCard], spacing: 7)
        UtilityStyle.fillWidth(headerCard, in: cards)
        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
        let ranks = ModeRecordStore.ranks(for: entries)
        for (index, entry) in entries.enumerated() {
            let rank = UtilityRankView(rank: ranks[index])
            rank.translatesAutoresizingMaskIntoConstraints = false
            rank.heightAnchor.constraint(equalToConstant: 30).isActive = true
            let metric = AchievementText.format("records.metric.cleared", entry.clearedCount)
            let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold, monospacedDigits: true)
            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11,
                                          color: HomeDashboardStyle.muted, alignment: .right)
            let row = recordColumns(rank, countLabel, date)
            row.setAccessibilityLabel("\(ranks[index]). \(metric), \(date.stringValue)")
            let card = UtilityCard(row, padding: 7)
            cards.addArrangedSubview(card)
            UtilityStyle.fillWidth(card, in: cards)
        }
        return cards
    }

    static func legacyTable(_ section: LegacyRecordSection) -> NSView {
        let title = AchievementText.format(section.kind == .scoreAttack ? "utility.records.legacy_score" : "utility.records.legacy_speed", section.ruleValue)
        let heading = UtilityStyle.label(title, size: 13, weight: .bold)
        let cards = UtilityStyle.stack([heading], spacing: 7)
        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
        for (index, record) in section.entries.enumerated() {
            let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
            let rank = UtilityStyle.label("\(index + 1).", size: 12, weight: .semibold, alignment: .center, monospacedDigits: true)
            let result = UtilityStyle.label(metric, size: 14, weight: .semibold, monospacedDigits: true)
            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)), size: 11,
                                          color: HomeDashboardStyle.muted, alignment: .right)
            let row = recordColumns(rank, result, date)
            row.setAccessibilityLabel("\(index + 1). \(metric), \(date.stringValue)")
            let card = UtilityCard(row, padding: 7)
            cards.addArrangedSubview(card)
            UtilityStyle.fillWidth(card, in: cards)
        }
        return cards
    }

    private static func recordColumns(_ rank: NSView, _ result: NSTextField, _ date: NSTextField) -> NSStackView {
        let row = UtilityStyle.stack([rank, result, date], vertical: false, spacing: 8)
        result.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // 表头与所有记录的高度、内边距和列宽相同，数据位数变化也不会移动列。
        NSLayoutConstraint.activate([
            rank.widthAnchor.constraint(equalToConstant: 36),
            date.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.43),
            row.heightAnchor.constraint(equalToConstant: 38)
        ])
        return row
    }
}

/// 前三名用金银铜奖牌，其他名次使用等宽数字。
private final class UtilityRankView: NSView {
    let rank: Int
    init(rank: Int) { self.rank = rank; super.init(frame: .zero); setAccessibilityElement(false) }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        if rank <= 3 {
            let colors = [HomeDashboardStyle.yellow, NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1), NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.45, alpha: 1)]
            let circle = NSRect(x: bounds.midX - 11, y: bounds.midY - 11, width: 22, height: 22)
            NSGradient(colors: [colors[rank - 1].blended(withFraction: 0.32, of: .white)!, colors[rank - 1]])?.draw(in: NSBezierPath(ovalIn: circle), angle: -90)
        }
        HomeDashboardStyle.text(String(rank), in: NSRect(x: 0, y: bounds.midY - 8, width: bounds.width, height: 18), size: 12, weight: .bold,
                       color: rank <= 3 ? HomeDashboardStyle.navy : HomeDashboardStyle.muted, alignment: .center)
    }
}
