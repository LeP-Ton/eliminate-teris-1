import Cocoa
import QuartzCore

/// 滑轨只承载视觉过渡；真实选中值和筛选事件仍沿用原生 NSSegmentedControl。
final class AchievementFilterControl: NSSegmentedControl {
    private let thumb = CAGradientLayer()
    private let labels = FilterLabelsView()
    private var counts: [Int] = []
    private var tracking: NSTrackingArea?
    private var hoveredSegment: Int?
    private var hasPlacedThumb = false
    /// 辅助页面复用同一套滑轨质感；未指定时保持成就筛选的三个状态图标。
    var segmentSymbols = ["square.grid.2x2.fill", "lock.fill", "checkmark.seal.fill"]
    /// 在测试中可替换系统偏好，运行时每次切换都读取最新设置。
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static let transitionDuration: CFTimeInterval = 0.24

    override var isFlipped: Bool { true }
    // 自绘轨道不使用系统分段胶囊的隐含外边距，避免 Auto Layout 放大实际 frame。
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    override var selectedSegment: Int { didSet { if oldValue != selectedSegment { positionThumb(animated: true) } } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        labels.owner = self
        labels.wantsLayer = true
        addSubview(labels)
        thumb.name = "achievement-filter-selection"
        thumb.colors = [NSColor(calibratedRed: 1, green: 0.88, blue: 0.35, alpha: 1).cgColor,
                        HomeStyle.yellow.cgColor]
        thumb.startPoint = CGPoint(x: 0.5, y: 0)
        thumb.endPoint = CGPoint(x: 0.5, y: 1)
        thumb.cornerRadius = 9
        thumb.borderWidth = 0.75
        thumb.borderColor = NSColor(calibratedRed: 0.91, green: 0.66, blue: 0.05, alpha: 0.5).cgColor
        thumb.shadowColor = NSColor(calibratedRed: 0.43, green: 0.32, blue: 0.09, alpha: 1).cgColor
        thumb.shadowOpacity = 0.16
        thumb.shadowRadius = 2
        thumb.shadowOffset = CGSize(width: 0, height: 1)
        layer?.insertSublayer(thumb, at: 0)
        labels.layer?.zPosition = 1
        focusRingType = .exterior
    }
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        let widest = (0..<segmentCount).map { index in
            ((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: labelFont]).width
        }.max() ?? 0
        return NSSize(width: CGFloat(segmentCount) * max(102, widest + 58) + 8, height: 44)
    }

    private var labelFont: NSFont { .systemFont(ofSize: 12, weight: .semibold) }

    func updateCounts(_ values: [Int]) {
        counts = values
        labels.needsDisplay = true
    }

    func refreshMetrics() {
        for index in 0..<segmentCount {
            setWidth(0, forSegment: index)
            setToolTip("\(label(forSegment: index) ?? "") · \(counts.indices.contains(index) ? counts[index] : 0)", forSegment: index)
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        needsDisplay = true
        labels.needsDisplay = true
    }

    private func segmentRect(_ index: Int) -> NSRect {
        guard segmentCount > 0 else { return .zero }
        let width = max(0, bounds.width - 8) / CGFloat(segmentCount)
        return NSRect(x: 4 + CGFloat(index) * width, y: 4, width: width, height: max(0, bounds.height - 8))
    }

    override func layout() {
        super.layout()
        labels.frame = bounds
        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
        // 刷新列表或数量时不重置正在进行的动画；仅在几何尺寸改变时同步。
        if !hasPlacedThumb || thumb.frame != target { positionThumb(animated: false) }
    }

    private func positionThumb(animated: Bool) {
        guard selectedSegment >= 0, selectedSegment < segmentCount, bounds.width > 8, bounds.height > 8 else { return }
        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
        let previous = thumb.presentation()?.frame ?? thumb.frame
        let shouldAnimate = animated && hasPlacedThumb && !reducesMotion()
        thumb.removeAnimation(forKey: "filter-selection")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        thumb.frame = target
        thumb.shadowPath = CGPath(roundedRect: thumb.bounds, cornerWidth: 9, cornerHeight: 9, transform: nil)
        CATransaction.commit()
        if shouldAnimate {
            let movement = CABasicAnimation(keyPath: "position")
            movement.fromValue = NSValue(point: NSPoint(x: previous.midX, y: previous.midY))
            movement.toValue = NSValue(point: NSPoint(x: target.midX, y: target.midY))
            let resizing = CABasicAnimation(keyPath: "bounds")
            resizing.fromValue = NSValue(rect: NSRect(origin: .zero, size: previous.size))
            resizing.toValue = NSValue(rect: NSRect(origin: .zero, size: target.size))
            let group = CAAnimationGroup()
            group.animations = [movement, resizing]
            group.duration = Self.transitionDuration
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            thumb.add(group, forKey: "filter-selection")
        }
        hasPlacedThumb = true
        labels.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        NSGradient(colors: [NSColor(calibratedWhite: 0.94, alpha: 1), NSColor(calibratedWhite: 0.965, alpha: 1)])?.draw(in: path, angle: 90)
        NSColor(calibratedWhite: 0.86, alpha: 0.65).setStroke(); path.lineWidth = 1; path.stroke()
    }

    fileprivate func drawLabels() {
        for index in 0..<segmentCount {
            let rect = segmentRect(index)
            let selected = selectedSegment == index
            let title = label(forSegment: index) ?? ""
            let color = selected ? HomeStyle.ink : hoveredSegment == index ? HomeStyle.ink : HomeStyle.secondary
            let count = counts.indices.contains(index) ? String(counts[index]) : "0"
            let countFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
            let countWidth = max(21, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 10)
            var font = labelFont
            var titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            while 13 + 6 + titleWidth + 7 + countWidth > rect.width - 10, font.pointSize > 10 {
                font = .systemFont(ofSize: font.pointSize - 0.5, weight: .semibold)
                titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            }
            let contentWidth = 13 + 6 + titleWidth + 7 + countWidth
            let start = rect.midX - contentWidth / 2
            let symbol = segmentSymbols.indices.contains(index) ? segmentSymbols[index] : "square.fill"
            HomeStyle.symbol(symbol, in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
            let titleSize = (title as NSString).size(withAttributes: [.font: font])
            (title as NSString).draw(at: NSPoint(x: start + 19, y: rect.midY - titleSize.height / 2), withAttributes: [.font: font, .foregroundColor: color])
            let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
            (selected ? HomeStyle.ink.withAlphaComponent(0.075) : HomeStyle.ink.withAlphaComponent(0.035)).setFill()
            NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6).fill()
            let size = (count as NSString).size(withAttributes: [.font: countFont])
            (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2), withAttributes: [.font: countFont, .foregroundColor: color])
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredSegment = (0..<segmentCount).first { segmentRect($0).contains(point) }
        labels.needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) { hoveredSegment = nil; labels.needsDisplay = true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }), index != selectedSegment else { return }
        selectedSegment = index
        sendAction(action, to: target)
    }

    @discardableResult
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        // 辅助功能可通过原生 Cell 改变选中值，再同步滑块，保持与鼠标/键盘相同的反馈。
        if hasPlacedThumb, selectedSegment >= 0, thumb.frame != segmentRect(selectedSegment).insetBy(dx: 1, dy: 0) {
            positionThumb(animated: true)
        }
        return super.sendAction(action, to: target)
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        let offset: Int
        switch event.keyCode {
        case 123: offset = -1
        case 124: offset = 1
        default: super.keyDown(with: event); return
        }
        let next = min(segmentCount - 1, max(0, selectedSegment + offset))
        guard next != selectedSegment else { return }
        selectedSegment = next
        sendAction(action, to: target)
    }
}

/// 图文位于滑块上方，且不截获点击；分段控件继续提供原生辅助功能语义。
private final class FilterLabelsView: NSView {
    weak var owner: AchievementFilterControl?
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { owner?.drawLabels() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }
}
