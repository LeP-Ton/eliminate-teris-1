import Cocoa

/// 统一生成徽章、详情和图鉴文案，语言切换时无需重建成就定义。
enum AchievementText {
    static func string(_ key: String) -> String { Localizer.shared.string(key) }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Localizer.shared.locale, arguments: arguments)
    }

    static func title(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
        // 按钮另外设置系统图标；文本同时包含状态，便于辅助功能读取。
        return format(manager.isUnlocked(id: definition.id) ? "achievement.accessibility.unlocked" : "achievement.accessibility.locked", string(definition.titleKey))
    }

    static func progress(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
        let progress = manager.progress(for: definition)
        let reached = progress.isTime ? manager.hasTimedResult(for: definition) && progress.current <= progress.target : progress.current >= progress.target
        if manager.isUnlocked(id: definition.id), !reached {
            return string("achievement.progress.legacy")
        }
        if progress.isTime {
            guard manager.hasTimedResult(for: definition) else { return format("achievement.progress.no_time", progress.target) }
            return format("achievement.progress.time", progress.current, progress.target)
        }
        switch definition.goal {
        case .firstClear, .speedRun:
            return string(manager.isUnlocked(id: definition.id) ? "achievement.state.unlocked" : "achievement.state.locked")
        default:
            let formatter = NumberFormatter()
            formatter.locale = Localizer.shared.locale
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let current = formatter.string(from: NSNumber(value: progress.current)) ?? "0"
            let target = formatter.string(from: NSNumber(value: progress.target)) ?? "0"
            let key: String
            switch definition.goal {
            case .totalCleared, .completedRounds, .pieceCleared: key = "achievement.progress.total"
            default: key = "achievement.progress.best"
            }
            return format(key, current, target)
        }
    }

    static func status(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
        guard manager.isUnlocked(id: definition.id) else { return string("achievement.state.locked") }
        guard let date = manager.unlockDate(id: definition.id) else { return string("achievement.state.unlocked") }
        let formatter = DateFormatter()
        formatter.locale = Localizer.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return format("achievement.date", formatter.string(from: date))
    }
}

/// 标签内容作为一个整体居中，避免 NSButton 原生布局把图标贴到左边缘。
final class AchievementBadgeButton: NSButton {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        setButtonType(.momentaryPushIn)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.usesSingleLineMode = true
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let content = NSStackView(views: [iconView, nameLabel])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 5
        content.translatesAutoresizingMaskIntoConstraints = false
        content.setContentHuggingPriority(.required, for: .horizontal)
        content.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(content)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func refresh(_ definition: AchievementDefinition, manager: AchievementsManager) {
        let unlocked = manager.isUnlocked(id: definition.id)
        let color = unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.82, blue: 0.82, alpha: 0.9)
        nameLabel.stringValue = AchievementText.string(definition.titleKey)
        nameLabel.textColor = color
        iconView.image = NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        iconView.contentTintColor = color
        layer?.borderColor = (unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.53, blue: 0.5, alpha: 0.96)).cgColor
        toolTip = AchievementText.string(definition.titleKey) + "\n" + AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
        setAccessibilityLabel(AchievementText.title(definition, manager: manager))
    }

    // 图标和文字只负责展示，整个标签仍作为同一个按钮接收点击。
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }
}

/// 可视区域恰好容纳五枚标签；独立预留高度以兼容常驻和覆盖式滚动条。
final class AchievementBadgeStripView: NSScrollView {
    static let preferredHeight: CGFloat = 64
    private let definitions: [AchievementDefinition]
    private let document = NSView()
    private var badges: [AchievementBadgeButton] = []
    private var previousViewportSize = NSSize.zero
    var onSelect: ((Int) -> Void)?

    init(definitions: [AchievementDefinition] = AchievementDefinition.all) {
        self.definitions = definitions
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        drawsBackground = false
        hasHorizontalScroller = true
        hasVerticalScroller = false
        autohidesScrollers = true
        borderType = .noBorder
        automaticallyAdjustsContentInsets = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        documentView = document
        for definition in definitions {
            let button = AchievementBadgeButton(frame: .zero)
            button.tag = definition.id
            button.target = self
            button.action = #selector(badgeTapped(_:))
            document.addSubview(button)
            badges.append(button)
        }
    }

    required init?(coder: NSCoder) { nil }

    func refresh(manager: AchievementsManager) {
        for (definition, badge) in zip(definitions, badges) {
            badge.refresh(definition, manager: manager)
        }
    }

    override func layout() {
        super.layout()
        let viewport = contentView.bounds.size
        guard viewport.width > 0, viewport.height > 0, viewport != previousViewportSize else { return }
        previousViewportSize = viewport
        let inset: CGFloat = 6
        let spacing: CGFloat = 10
        let width = max(1, (viewport.width - inset * 2 - spacing * 4) / 5)
        let height: CGFloat = 32
        let oldOffset = contentView.bounds.origin.x
        document.setFrameSize(NSSize(width: inset * 2 + CGFloat(badges.count) * width + CGFloat(max(0, badges.count - 1)) * spacing,
                                     height: viewport.height))
        for (index, badge) in badges.enumerated() {
            badge.frame = NSRect(x: inset + CGFloat(index) * (width + spacing),
                                 y: (viewport.height - height) / 2, width: width, height: height)
        }
        // 尺寸变化后保留浏览位置，并限制在有效范围，避免末端出现大片空白。
        let maximumOffset = max(0, document.frame.width - viewport.width)
        contentView.scroll(to: NSPoint(x: min(max(0, oldOffset), maximumOffset), y: 0))
        reflectScrolledClipView(contentView)
    }

    @objc private func badgeTapped(_ sender: NSButton) { onSelect?(sender.tag) }
}

/// 辅助面板沿用浅色首页的文字、边框及成功状态颜色。
private enum AchievementPanelStyle {
    static let accent = HomeStyle.ink
    static let success = HomeStyle.green
    static let body = HomeStyle.ink
    static let muted = HomeStyle.secondary
    static let controlFont = NSFont.systemFont(ofSize: 12, weight: .semibold)

    static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (selected ? NSColor(calibratedRed: 0.9, green: 0.96, blue: 1, alpha: 1) : NSColor.white).setFill()
        path.fill()
        (selected ? HomeStyle.blue : HomeStyle.border).setStroke()
        path.lineWidth = 1
        path.stroke()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: controlFont,
            .foregroundColor: selected ? HomeStyle.blue : body
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                                 withAttributes: attributes)
    }
}

/// 保留原生分段控件的选择状态和辅助功能，以主题绘制代替系统浅色胶囊。
private final class AchievementFilterControl: NSSegmentedControl {
    override var intrinsicContentSize: NSSize {
        NSSize(width: (0..<segmentCount).reduce(0) { $0 + segmentWidth($1) } + CGFloat(max(0, segmentCount - 1)) * 8,
               height: 32)
    }

    func refreshMetrics() {
        for index in 0..<segmentCount { setWidth(segmentWidth(index), forSegment: index) }
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private func segmentWidth(_ index: Int) -> CGFloat {
        max(70, ceil(((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24)
    }

    private func segmentRect(_ index: Int) -> NSRect {
        let x = (0..<index).reduce(CGFloat(0)) { $0 + segmentWidth($1) + 8 }
        return NSRect(x: x, y: 0, width: segmentWidth(index), height: bounds.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<segmentCount {
            AchievementPanelStyle.drawControl(segmentRect(index), title: label(forSegment: index) ?? "", selected: selectedSegment == index)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }) else { return }
        selectedSegment = index
        needsDisplay = true
        sendAction(action, to: target)
    }
}

private final class AchievementPanelActionButton: NSButton {
    override var intrinsicContentSize: NSSize {
        NSSize(width: max(88, ceil((title as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24), height: 32)
    }

    override var isHighlighted: Bool { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        AchievementPanelStyle.drawControl(bounds, title: title, selected: isHighlighted)
    }
}

/// 像素进度条沿用原生进度接口，显示颜色与所在成就卡片一致。
private final class AchievementProgressIndicator: NSProgressIndicator {
    var accentColor: NSColor = AchievementPanelStyle.accent

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 10) }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
        track.fill()
        let fraction = min(1, max(0, (doubleValue - minValue) / max(1, maxValue - minValue)))
        if fraction > 0 {
            accentColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height),
                         xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        }
    }

}

/// 面板不争夺主窗口焦点，点击筛选时仍保留 Touch Bar 的游戏棋盘。
private final class AchievementPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class AchievementDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class AchievementsWindowController: NSWindowController {
    private let manager: AchievementsManager
    private let filter = AchievementFilterControl()
    private let heading = NSTextField(labelWithString: "")
    private let backButton = AchievementPanelActionButton()
    private let list = NSStackView()
    private let scroll = NSScrollView()
    private var detailID: Int?

    init(manager: AchievementsManager) {
        self.manager = manager
        let panel = AchievementPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 580),
                                     styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.minSize = NSSize(width: 480, height: 360)
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = HomeStyle.background
        panel.titlebarAppearsTransparent = true
        panel.contentView = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))
        super.init(window: panel)
        buildContent()
    }

    required init?(coder: NSCoder) { nil }

    func present(from parent: NSWindow?, detailID: Int? = nil) {
        self.detailID = detailID
        refresh()
        window?.contentView?.layoutSubtreeIfNeeded()
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        if let parent, let window {
            var frame = window.frame
            let availableFrame = (parent.screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 8, dy: 8)
            if let availableFrame {
                frame.size.width = min(frame.width, availableFrame.width)
                frame.size.height = min(frame.height, availableFrame.height)
            }
            frame.origin = NSPoint(x: parent.frame.midX - frame.width / 2,
                                   y: parent.frame.midY - frame.height / 2)
            if let availableFrame {
                // 主窗口靠近屏幕边缘时，保证标题栏和整个面板仍处于可用区域。
                frame.origin.x = min(max(frame.minX, availableFrame.minX), availableFrame.maxX - frame.width)
                frame.origin.y = min(max(frame.minY, availableFrame.minY), availableFrame.maxY - frame.height)
            }
            // addChildWindow 会使子窗口可见，必须先完成定位，不能再依赖 isVisible 判断。
            window.setFrame(frame, display: false)
            if window.parent !== parent {
                window.parent?.removeChildWindow(window)
                parent.addChildWindow(window, ordered: .above)
            }
        } else {
            window?.center()
        }
        window?.orderFront(nil)
    }

    func refresh() {
        window?.title = AchievementText.string("panel.achievements")
        heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
        backButton.title = AchievementText.string("achievement.view_all")
        backButton.invalidateIntrinsicContentSize()
        backButton.isHidden = detailID == nil
        filter.isHidden = detailID != nil
        for (index, key) in ["all", "locked", "unlocked"].enumerated() {
            filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
        }
        filter.refreshMetrics()
        list.arrangedSubviews.forEach { view in
            list.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let definitions = AchievementDefinition.all.filter { definition in
            if let detailID { return definition.id == detailID }
            switch filter.selectedSegment {
            case 1: return !manager.isUnlocked(id: definition.id)
            case 2: return manager.isUnlocked(id: definition.id)
            default: return true
            }
        }
        for category in AchievementCategory.allCases {
            let group = definitions.filter { $0.category == category }
            guard !group.isEmpty else { continue }
            let label = NSTextField(labelWithString: AchievementText.string("achievement.category.\(category.rawValue)"))
            label.font = .systemFont(ofSize: 12, weight: .heavy)
            label.textColor = AchievementPanelStyle.accent
            list.addArrangedSubview(label)
            for definition in group {
                let row = makeRow(definition)
                list.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
            }
        }
        if definitions.isEmpty {
            let empty = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.empty"))
            empty.font = .systemFont(ofSize: 12, weight: .regular)
            empty.textColor = AchievementPanelStyle.body
            list.addArrangedSubview(empty)
        }
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        heading.font = .systemFont(ofSize: 16, weight: .heavy)
        heading.textColor = AchievementPanelStyle.accent
        heading.lineBreakMode = .byTruncatingTail
        heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        filter.segmentCount = 3
        filter.trackingMode = .selectOne
        filter.selectedSegment = 0
        filter.target = self
        filter.action = #selector(filterChanged)
        backButton.isBordered = false
        backButton.setButtonType(.momentaryPushIn)
        backButton.target = self
        backButton.action = #selector(showAll)
        let actions = NSStackView(views: [filter, backButton])
        actions.orientation = .horizontal
        let icon = NSImageView(image: NSImage(systemSymbolName: "rosette", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = AchievementPanelStyle.accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let titleRow = NSStackView(views: [icon, heading])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        let toolbar = NSStackView(views: [titleRow, actions])
        toolbar.orientation = .vertical
        toolbar.alignment = .leading
        toolbar.spacing = 12
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let header = PixelFrameCardView(accentColor: AchievementPanelStyle.accent)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(toolbar)
        content.addSubview(header)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        content.addSubview(scroll)
        let document = AchievementDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 12
        list.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            toolbar.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            toolbar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            toolbar.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
            titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
            filter.heightAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            list.topAnchor.constraint(equalTo: document.topAnchor, constant: 16),
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
            list.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
        ])
    }

    private func makeRow(_ definition: AchievementDefinition) -> NSView {
        let unlocked = manager.isUnlocked(id: definition.id)
        let accent = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.accent
        let row = PixelFrameCardView(accentColor: accent)
        row.translatesAutoresizingMaskIntoConstraints = false
        let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.textColor = accent
        name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
        let icon = NSImageView(image: NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let titleRow = NSStackView(views: [icon, name])
        titleRow.orientation = .horizontal
        titleRow.spacing = 6
        let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
        condition.font = .systemFont(ofSize: 12, weight: .regular)
        condition.textColor = AchievementPanelStyle.body
        let progress = NSTextField(wrappingLabelWithString: AchievementText.progress(definition, manager: manager))
        progress.font = .systemFont(ofSize: 11, weight: .medium)
        progress.textColor = accent
        let status = NSTextField(wrappingLabelWithString: AchievementText.status(definition, manager: manager))
        status.font = .systemFont(ofSize: 10, weight: .regular)
        status.textColor = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted
        let meter = AchievementProgressIndicator()
        meter.accentColor = unlocked ? HomeStyle.green : HomeStyle.yellow
        meter.heightAnchor.constraint(equalToConstant: 10).isActive = true
        meter.style = .bar
        meter.isIndeterminate = false
        meter.minValue = 0
        meter.maxValue = 1
        meter.doubleValue = unlocked ? 1 : manager.progress(for: definition).fraction
        meter.setAccessibilityLabel(progress.stringValue)
        let stack = NSStackView(views: [titleRow, condition, progress, meter, status])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            view.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
        ])
        return row
    }

    @objc private func filterChanged() { refresh() }
    @objc private func showAll() { detailID = nil; refresh() }
}

/// 提示是窗口内可点击按钮，显示三秒，不创建 modal 或替换 Touch Bar。
final class AchievementToastPresenter: NSObject {
    private weak var host: NSView?
    private let onSelect: ([Int]) -> Void
    private var queue = AchievementUnlockQueue()
    private var button: NSButton?
    private var activeIDs: [Int] = []
    private var dismissWork: DispatchWorkItem?
    private var isScheduled = false

    init(host: NSView, onSelect: @escaping ([Int]) -> Void) {
        self.host = host
        self.onSelect = onSelect
    }

    deinit { dismissWork?.cancel() }

    func enqueue(_ ids: [Int]) {
        queue.enqueue(ids)
        guard button == nil, !isScheduled else { return }
        isScheduled = true
        // 合并同一事件循环中的交换与结算解锁，再决定是否批量提示。
        DispatchQueue.main.async { [weak self] in
            self?.isScheduled = false
            self?.showNext()
        }
    }

    func refreshLanguage() {
        guard let button else { return }
        button.title = message(for: activeIDs)
    }

    private func message(for ids: [Int]) -> String {
        if ids.count == 1, let definition = AchievementDefinition.all.first(where: { $0.id == ids[0] }) {
            return AchievementText.format("achievement.toast.single", AchievementText.string(definition.titleKey))
        }
        return AchievementText.format("achievement.toast.multiple", ids.count)
    }

    private func showNext() {
        guard button == nil, let host else { return }
        activeIDs = queue.next()
        guard !activeIDs.isEmpty else { return }
        let toast = NSButton(title: message(for: activeIDs), target: self, action: #selector(selected))
        toast.bezelStyle = .rounded
        toast.font = .systemFont(ofSize: 12, weight: .semibold)
        toast.contentTintColor = .systemGreen
        toast.wantsLayer = true
        toast.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        toast.layer?.cornerRadius = 8
        toast.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -12),
            toast.widthAnchor.constraint(lessThanOrEqualTo: host.widthAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 42)
        ])
        button = toast
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        button?.removeFromSuperview()
        button = nil
        activeIDs = []
        showNext()
    }

    @objc private func selected() {
        onSelect(activeIDs)
        dismiss()
    }
}
