import Cocoa

/// 辅助页共用首页材质；文字使用原生视图，支持换行和辅助功能。
enum UtilityStyle {
    static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                      color: NSColor = HomeStyle.ink) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
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
    init(_ content: NSView, tint: NSColor = .white, padding: CGFloat = 20) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = tint.cgColor
        layer?.borderColor = HomeStyle.border.withAlphaComponent(0.8).cgColor
        layer?.borderWidth = 0.75; layer?.cornerRadius = 14
        content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            content.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ])
    }
    required init?(coder: NSCoder) { nil }
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
    private let subtitle = UtilityStyle.label("", size: 12, color: HomeStyle.secondary)

    init(page: String) {
        super.init(frame: .zero)
        let symbol = page == "settings" ? "slider.horizontal.3" : page == "rules" ? "gamecontroller.fill" : "trophy"
        let artwork = UtilityStyle.icon(symbol, color: page == "records" ? .systemOrange : HomeStyle.blue, size: 32)
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
    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
    func refreshHeader(page: String) {
        title.stringValue = UtilityStyle.text("panel.\(page)")
        subtitle.stringValue = UtilityStyle.text("utility.\(page).subtitle")
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
    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 44) }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.card(bounds, fill: HomeStyle.blue.withAlphaComponent(isHighlighted ? 0.09 : 0.035), border: HomeStyle.blue.withAlphaComponent(0.25), radius: 9)
        HomeStyle.text(title, in: NSRect(x: 15, y: bounds.midY - 10, width: bounds.width - 52, height: 22), size: 14, weight: .semibold)
        HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeStyle.blue)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// 原生滑杆负责拖动与键盘步进，自绘金色进度和白色旋钮。
final class UtilityVolumeSliderCell: NSSliderCell {
    override var knobThickness: CGFloat { 22 }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        // 原生旋钮的光学中心与 barRect 有细微偏移，轨道以旋钮中心为准。
        let track = NSRect(x: rect.minX, y: knobRect(flipped: flipped).midY - 3, width: rect.width, height: 6)
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill(); NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
    }
    override func drawKnob(_ knobRect: NSRect) {
        let knob = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = HomeStyle.ink.withAlphaComponent(0.16)
        shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
        NSColor.white.setFill(); NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
        HomeStyle.border.setStroke(); NSBezierPath(ovalIn: knob.insetBy(dx: 0.5, dy: 0.5)).stroke()
        HomeStyle.yellow.setFill(); NSBezierPath(ovalIn: knob.insetBy(dx: 7, dy: 7)).fill()
    }
}

/// 静态游戏示意不增加定时器，不参与真实棋盘状态。
final class UtilityLessonArtwork: NSView {
    let step: Int
    init(step: Int) {
        self.step = step; super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 100), heightAnchor.constraint(equalToConstant: 52)])
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        if step == 0 {
            HomeStyle.piece(.orangeRicky, in: NSRect(x: 0, y: 14, width: 33, height: 24))
            HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeStyle.secondary)
            HomeStyle.piece(.blueRicky, in: NSRect(x: 65, y: 14, width: 33, height: 24))
        } else {
            let rows = step == 1 ? 1 : 2
            for row in 0..<rows {
                for column in 0..<3 {
                    let tile = NSRect(x: 19 + CGFloat(column) * 21, y: CGFloat(rows == 1 ? 17 : 7) + CGFloat(row) * 21, width: 18, height: 18)
                    let color = row == 0 ? HomeStyle.blue : HomeStyle.green
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
        let lessons = UtilityStyle.stack([], spacing: 0)
        for step in 0..<3 {
            let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeStyle.blue)
            number.widthAnchor.constraint(equalToConstant: 25).isActive = true
            let copy = UtilityStyle.stack([
                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold),
                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeStyle.secondary)
            ], spacing: 5)
            let row = UtilityStyle.stack([number, copy, UtilityLessonArtwork(step: step)], vertical: false, spacing: 12)
            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
            lessons.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: lessons)
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
            if step < 2 {
                let divider = NSBox(); divider.boxType = .separator
                lessons.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: lessons)
            }
        }
        page.addSection(UtilityCard(lessons, padding: 18))
        page.addSection(UtilityStyle.label(UtilityStyle.text("utility.rules.modes"), size: 14, weight: .bold))
        let modes = UtilityStyle.stack([], spacing: 10)
        for candidate in HomeGameMode.allCases {
            let selected = candidate == mode
            let copy = UtilityStyle.stack([
                UtilityStyle.label(UtilityStyle.text("home.mode.\(candidate.key)"), size: 13, weight: .bold),
                UtilityStyle.label(UtilityStyle.text("home.mode_desc.\(candidate.key)"), size: 12, color: HomeStyle.secondary)
            ], spacing: 3)
            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let row = UtilityStyle.stack([UtilityStyle.icon(candidate.symbol, color: selected ? HomeStyle.blue : HomeStyle.secondary, size: 26), copy], vertical: false, spacing: 13)
            if selected {
                let current = UtilityStyle.label(UtilityStyle.text("utility.rules.current"), size: 10, weight: .semibold, color: HomeStyle.blue)
                current.setContentHuggingPriority(.required, for: .horizontal)
                current.setContentCompressionResistancePriority(.required, for: .horizontal)
                row.addArrangedSubview(current)
            }
            let card = UtilityCard(row, tint: selected ? NSColor(calibratedRed: 0.94, green: 0.975, blue: 1, alpha: 1) : .white, padding: 12)
            modes.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: modes)
        }
        page.addSection(modes)
        let note = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.secondary, size: 19),
                                     UtilityStyle.label(UtilityStyle.text("utility.rules.progress"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 10)
        page.addSection(UtilityCard(note, tint: HomeStyle.yellow.withAlphaComponent(0.08), padding: 14))
    }
}

/// 数字为视觉中心，并明确当前榜单的固定规则。
final class UtilityRecordBestView: NSView {
    init(mode: ModeRecordKey, entry: ModeRecord?) {
        super.init(frame: .zero)
        wantsLayer = true; layer?.cornerRadius = 14
        layer?.backgroundColor = HomeStyle.yellow.withAlphaComponent(0.12).cgColor
        layer?.borderColor = HomeStyle.yellow.withAlphaComponent(0.4).cgColor; layer?.borderWidth = 0.75
        let metric = entry.map { String($0.clearedCount) } ?? "—"
        let value = UtilityStyle.label(metric, size: 38, weight: .heavy)
        value.font = .monospacedDigitSystemFont(ofSize: 38, weight: .heavy)
        let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeStyle.secondary)
        let copy = UtilityStyle.stack([
            UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeStyle.secondary),
            UtilityStyle.stack([value, unit], vertical: false, spacing: 8),
            UtilityStyle.label(UtilityStyle.text(mode == .timed ? "utility.records.timed_rule" : "utility.records.moves_rule"), size: 11, color: HomeStyle.secondary)
        ], spacing: 4)
        let icon = UtilityStyle.icon(mode == .timed ? "stopwatch" : "arrow.left.arrow.right", color: .systemOrange, size: 56)
        let row = UtilityStyle.stack([copy, icon], vertical: false, spacing: 16)
        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.translatesAutoresizingMaskIntoConstraints = false; addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18), row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }
    required init?(coder: NSCoder) { nil }
}

enum UtilityRecordContent {
    /// 独立列宽确保日期不会因分数位数改变而错位。
    static func table(mode: ModeRecordKey, entries: [ModeRecord]) -> NSView {
        let rows = UtilityStyle.stack([], spacing: 0)
        let headings = UtilityStyle.stack([
            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeStyle.secondary),
            UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeStyle.secondary),
            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold, color: HomeStyle.secondary)
        ], vertical: false, spacing: 12)
        headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
        headings.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 135).isActive = true
        (headings.arrangedSubviews[2] as? NSTextField)?.alignment = .right
        headings.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
        rows.addArrangedSubview(headings); UtilityStyle.fillWidth(headings, in: rows)
        headings.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
        let ranks = ModeRecordStore.ranks(for: entries)
        for (index, entry) in entries.enumerated() {
            let divider = NSBox(); divider.boxType = .separator
            rows.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: rows)
            let rank = UtilityRankView(rank: ranks[index])
            rank.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([rank.widthAnchor.constraint(equalToConstant: 36), rank.heightAnchor.constraint(equalToConstant: 30)])
            let metric = AchievementText.format("records.metric.cleared", entry.clearedCount)
            let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold)
            countLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: ranks[index] == 1 ? .bold : .semibold)
            countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11, color: HomeStyle.secondary)
            date.alignment = .right
            date.widthAnchor.constraint(equalToConstant: 135).isActive = true
            let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 12)
            rows.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: rows)
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            row.setAccessibilityLabel("\(ranks[index]). \(metric), \(date.stringValue)")
        }
        if entries.isEmpty {
            let empty = UtilityStyle.stack([
                UtilityStyle.icon("flag.checkered", color: HomeStyle.secondary, size: 40),
                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold),
                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeStyle.secondary)
            ], spacing: 12)
            empty.alignment = .centerX
            for label in empty.arrangedSubviews.compactMap({ $0 as? NSTextField }) { label.alignment = .center }
            rows.addArrangedSubview(empty); UtilityStyle.fillWidth(empty, in: rows)
            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        }
        return UtilityCard(rows, padding: 16)
    }

    static func legacyTable(_ section: LegacyRecordSection) -> NSView {
        let stack = UtilityStyle.stack([], spacing: 8)
        let title = AchievementText.format(section.kind == .scoreAttack ? "utility.records.legacy_score" : "utility.records.legacy_speed", section.ruleValue)
        let heading = UtilityStyle.label(title, size: 13, weight: .bold)
        stack.addArrangedSubview(heading); UtilityStyle.fillWidth(heading, in: stack)
        let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
        for (index, record) in section.entries.enumerated() {
            let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
            let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeStyle.secondary)
            stack.addArrangedSubview(label); UtilityStyle.fillWidth(label, in: stack)
        }
        return UtilityCard(stack, tint: NSColor(calibratedWhite: 0.975, alpha: 1), padding: 16)
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
            let colors = [HomeStyle.yellow, NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1), NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.45, alpha: 1)]
            let circle = NSRect(x: bounds.midX - 11, y: bounds.midY - 11, width: 22, height: 22)
            NSGradient(colors: [colors[rank - 1].blended(withFraction: 0.32, of: .white)!, colors[rank - 1]])?.draw(in: NSBezierPath(ovalIn: circle), angle: -90)
        }
        HomeStyle.text(String(rank), in: NSRect(x: 0, y: bounds.midY - 8, width: bounds.width, height: 18), size: 12, weight: .bold,
                       color: rank <= 3 ? HomeStyle.ink : HomeStyle.secondary, alignment: .center)
    }
}
