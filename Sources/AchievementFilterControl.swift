import Cocoa
import QuartzCore

/// 滑轨只承载视觉过渡；真实选中值和筛选事件仍沿用原生 NSSegmentedControl。
final class AchievementFilterControl: NSSegmentedControl {
    private let thumb = CALayer()
    private let thumbFill = CAGradientLayer()
    private let thumbMask = CAShapeLayer()
    private let thumbRim = CAShapeLayer()
    private let labels = FilterLabelsView()
    private var counts: [Int] = []
    private var tracking: NSTrackingArea?
    private var hoveredSegment: Int?
    private var placedThumbFrame: NSRect?
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
        thumbFill.name = "achievement-filter-selection-fill"
        thumbFill.colors = [HomeDashboardStyle.color(0x17505A).cgColor, HomeDashboardStyle.color(0x10313D).cgColor]
        thumbFill.startPoint = CGPoint(x: 0, y: 0.5)
        thumbFill.endPoint = CGPoint(x: 1, y: 0.5)
        thumbMask.fillColor = NSColor.white.cgColor
        thumbFill.mask = thumbMask
        thumbRim.name = "achievement-filter-selection-rim"
        thumbRim.fillColor = nil
        thumbRim.strokeColor = HomeDashboardStyle.cyan.withAlphaComponent(0.85).cgColor
        thumbRim.lineWidth = 1
        thumb.addSublayer(thumbFill)
        thumb.addSublayer(thumbRim)
        thumb.shadowColor = HomeDashboardStyle.cyan.cgColor
        thumb.shadowOpacity = 0.18
        thumb.shadowRadius = 3
        thumb.shadowOffset = .zero
        layer?.insertSublayer(thumb, at: 0)
        labels.layer?.zPosition = 1
        focusRingType = .exterior
    }
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        let widest = (0..<segmentCount).map { index in
            ((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: labelFont]).width
        }.max() ?? 0
        return NSSize(width: CGFloat(segmentCount) * max(102, widest + 58) + 8 + HomeDashboardStyle.edgeOffset(for: 36),
                      height: 44)
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
        let track = bounds.insetBy(dx: 4, dy: 4)
        let offset = HomeDashboardStyle.edgeOffset(for: track.height)
        let pitch = max(0, track.width - offset) / CGFloat(segmentCount)
        return NSRect(x: track.minX + CGFloat(index) * pitch, y: track.minY, width: pitch + offset, height: track.height)
    }

    private func segmentIndex(at point: NSPoint) -> Int? {
        (0..<segmentCount).first { HomeDashboardStyle.slant(segmentRect($0)).contains(point) }
    }

    override func layout() {
        super.layout()
        labels.frame = bounds
        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
        // 刷新列表或数量时不重置正在进行的动画；仅在几何尺寸改变时同步。
        if placedThumbFrame != target { positionThumb(animated: false) }
    }

    private func positionThumb(animated: Bool) {
        guard selectedSegment >= 0, selectedSegment < segmentCount, bounds.width > 8, bounds.height > 8 else { return }
        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
        let previous = thumb.presentation()?.frame ?? thumb.frame
        let shouldAnimate = animated && placedThumbFrame != nil && !reducesMotion()
        thumb.removeAnimation(forKey: "filter-selection")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        thumb.frame = target
        thumbFill.frame = thumb.bounds
        thumbMask.frame = thumbFill.bounds
        thumbRim.frame = thumb.bounds
        // 渐变、描边和光晕共用同一轮廓，整个滑块在切换时一同移动。
        let outline = HomeDashboardStyle.cgSlant(thumb.bounds.insetBy(dx: 0.5, dy: 0.5))
        thumbMask.path = outline
        thumbRim.path = outline
        thumb.shadowPath = outline
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
        // 图层会由中心点反算 frame。保留布局目标可避免小数舍入误差把刷新误判成变尺寸。
        placedThumbFrame = target
        labels.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        UtilityStyle.drawCard(bounds)
    }

    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { HomeDashboardStyle.slant(bounds).fill() }

    fileprivate func drawLabels() {
        for index in 0..<segmentCount {
            let rect = segmentRect(index)
            let selected = selectedSegment == index
            let title = label(forSegment: index) ?? ""
            let color = selected ? HomeDashboardStyle.cyan : hoveredSegment == index ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
            let count = counts.indices.contains(index) ? String(counts[index]) : "0"
            let countFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
            let countWidth = max(23, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 12)
            let labelWidth = max(0, rect.width - HomeDashboardStyle.edgeOffset(for: rect.height) - 34 - countWidth)
            var font = labelFont
            var titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            while titleWidth > labelWidth, font.pointSize > 10 {
                font = .systemFont(ofSize: font.pointSize - 0.5, weight: .semibold)
                titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            }
            titleWidth = min(titleWidth, labelWidth)
            let contentWidth = 13 + 6 + titleWidth + 7 + countWidth
            let start = rect.midX - contentWidth / 2
            let symbol = segmentSymbols.indices.contains(index) ? segmentSymbols[index] : "square.fill"
            HomeStyle.symbol(symbol, in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
            let titleHeight = font.ascender - font.descender + font.leading
            HomeDashboardStyle.text(title, in: NSRect(x: start + 19, y: rect.midY - titleHeight / 2, width: titleWidth + 3,
                                                     height: titleHeight + 2), size: font.pointSize, weight: .semibold, color: color)
            let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
            color.withAlphaComponent(selected ? 0.16 : 0.09).setFill()
            HomeDashboardStyle.slant(chip).fill()
            let size = (count as NSString).size(withAttributes: [.font: countFont])
            (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2),
                                    withAttributes: [.font: countFont, .foregroundColor: color,
                                                     .obliqueness: HomeDashboardStyle.letterSlant])
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
        hoveredSegment = segmentIndex(at: point)
        labels.needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) { hoveredSegment = nil; labels.needsDisplay = true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard isEnabled, let index = segmentIndex(at: point), index != selectedSegment else { return }
        selectedSegment = index
        sendAction(action, to: target)
    }

    @discardableResult
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        // 辅助功能可通过原生 Cell 改变选中值，再同步滑块，保持与鼠标/键盘相同的反馈。
        if let placedThumbFrame, selectedSegment >= 0,
           placedThumbFrame != segmentRect(selectedSegment).insetBy(dx: 1, dy: 0) {
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
