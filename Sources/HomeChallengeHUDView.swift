import Cocoa

/// 左侧局内面板从同一份快照展示剩余预算、消除总数和四类方块明细。
final class HomeChallengeHUDView: NSView {
    static let surfaceInsetY: CGFloat = 5
    static let trailingInset: CGFloat = 3
    private static let rearOverhang: CGFloat = 0.08
    private static let rearTopInset: CGFloat = 45 / 636
    private static let countStepInterval: TimeInterval = 0.06
    private static let maxCountSteps = 10

    static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
        max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
    }

    var surfaceRect: NSRect {
        let height = max(0, bounds.height - 2 * Self.surfaceInsetY)
        let available = bounds.width - Self.trailingInset
        // 窄窗背板向左伸得更远，为斜边和描线留出完整空间。
        let rearWidth = (available - HomeDashboardStyle.edgeOffset(for: height) - 1) / (1 - Self.rearTopInset)
        let width = max(0, min(available / (1 + Self.rearOverhang), rearWidth))
        return NSRect(x: Self.leadingInset(for: width, height: height), y: Self.surfaceInsetY, width: width, height: height)
    }

    var breakdownCellRects: [NSRect] { Face(frame: surfaceRect).breakdownCellRects }
    var budgetTrackRect: NSRect? { showsBudget ? Face(frame: surfaceRect).budgetTrack : nil }

    /// 设计稿坐标以底部分格左边缘为参考。背板与前板同宽，沿同一斜率错开。
    private struct Face {
        let frame: NSRect
        var typographyScale: CGFloat { min(frame.width / 636, frame.height / 186) }

        var rules: NSRect {
            let left = point(455, 123)
            let front = totals
            // 两层在同一高度的净宽相同，左右斜边就会露出相同的错位。
            let width = front.width - HomeDashboardStyle.edgeOffset(for: front.height)
            return plate(from: left, to: NSPoint(x: left.x + width, y: point(455, 309).y))
        }
        var totals: NSRect { plate(from: point(472, 175), to: point(1033, 255)) }

        var budgetTrack: NSRect {
            let plate = rules
            let headerHeight = totals.minY - plate.minY
            let height = headerHeight * 0.22
            let y = plate.minY + (headerHeight - height) / 2
            // 左端沿用原标记的起点，右端按同一斜率和留白镜像定位。
            let left = plate.minX + HomeDashboardStyle.edgeOffset(for: plate.maxY - y - height)
            let right = plate.maxX - HomeDashboardStyle.edgeOffset(for: y - plate.minY)
            let start = point(482, 123).x
            let inset = start - left
            return NSRect(x: start, y: y, width: max(0, right - inset - start), height: height)
        }

        var breakdownCellRects: [NSRect] {
            let total = totals
            let height = point(410, 308).y - total.maxY
            let cut = HomeDashboardStyle.edgeOffset(for: height)
            let count = CGFloat(PieceKind.allCases.count)
            let available = total.width - HomeDashboardStyle.edgeOffset(for: total.height)
            let gap = 10 * typographyScale
            let cellWidth = max(0, (available - gap * (count - 1)) / count)
            return PieceKind.allCases.indices.map { index in
                NSRect(x: total.minX - cut + CGFloat(index) * (cellWidth + gap), y: total.maxY,
                       width: cellWidth + cut, height: height)
            }
        }

        private func plate(from topLeft: NSPoint, to rightAndBottom: NSPoint) -> NSRect {
            let height = rightAndBottom.y - topLeft.y
            let x = topLeft.x - HomeDashboardStyle.edgeOffset(for: height)
            return NSRect(x: x, y: topLeft.y, width: rightAndBottom.x - x, height: height)
        }

        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: frame.minX + (x - 410) / 636 * frame.width,
                    y: frame.minY + (y - 123) / 186 * frame.height)
        }

        func box(_ x: CGFloat, _ y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
            let origin = point(x, y)
            let end = point(x + width, y + height)
            return NSRect(x: origin.x, y: origin.y, width: end.x - origin.x, height: end.y - origin.y)
        }
    }
    private(set) var snapshot: GameSnapshot?
    private(set) var mode: HomeGameMode = .timed
    private struct CountTransition {
        let initial: Int
        let target: Int
        let startStep: Int

        private var stepCount: Int { min(target - initial, HomeChallengeHUDView.maxCountSteps) }
        var endStep: Int { startStep + stepCount }

        func value(at step: Int) -> Int {
            guard step < endStep else { return target }
            let completed = max(0, step - startStep)
            let distance = target - initial
            let steps = stepCount
            // 增量过大时在同一个节拍里多加几个，十拍内补齐。
            let perStep = distance / steps
            let extra = (completed * (distance % steps) + steps - 1) / steps
            return initial + completed * perStep + extra
        }
    }

    private let animationClock: () -> TimeInterval
    private let reducesMotion: () -> Bool
    private var countTransitions: [PieceKind: CountTransition] = [:]
    private var countAnimationStart: TimeInterval?
    private var countAnimationTimer: Timer?
    var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
    override var isFlipped: Bool { true }
    init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         reducesMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.animationClock = clock
        self.reducesMotion = reducesMotion
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { nil }
    deinit { countAnimationTimer?.invalidate() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopCountAnimation() }
    }

    private var showsBudget: Bool { mode != .free }
    private var budgetLabelKey: String {
        let isPreview = snapshot?.isRunning == false && snapshot?.isFinished == false
        if mode == .timed { return isPreview ? "home.challenge.time_limit" : "home.challenge.time_left" }
        return isPreview ? "home.challenge.move_limit" : "home.challenge.moves_left"
    }

    var remainingFraction: CGFloat {
        guard showsBudget, let snapshot else { return 0 }
        let fraction = mode == .timed
            ? (snapshot.remainingTime ?? HomeGameMode.timedDuration) / HomeGameMode.timedDuration
            : Double(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) / Double(HomeGameMode.moveLimit)
        return CGFloat(min(1, max(0, fraction)))
    }

    var budgetText: String {
        guard showsBudget, let snapshot else { return "" }
        if mode == .moves { return String(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) }
        let seconds = max(0, Int(ceil(snapshot.remainingTime ?? HomeGameMode.timedDuration)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
        updateCountAnimation(snapshot: snapshot, mode: mode)
        self.snapshot = snapshot; self.mode = mode
        var labels: [String] = []
        if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
        labels.append(AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
        labels += PieceKind.allCases.map { kind in
            AchievementText.string(kind.titleKey) + ": \(snapshot.clearedByKind[kind, default: 0])"
        }
        setAccessibilityLabel(labels.joined(separator: ", "))
        toolTip = labels.joined(separator: "\n")
        needsDisplay = true
    }

    /// 同一帧共用一个时间采样，汇总与四个分类同步更新。
    func displayedCounts() -> [PieceKind: Int] {
        let step = countStep(at: animationClock())
        let transitions = reducesMotion() ? [:] : countTransitions
        return Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { kind in
            let value = transitions[kind]?.value(at: step) ?? snapshot?.clearedByKind[kind, default: 0] ?? 0
            return (kind, value)
        })
    }

    private func countStep(at now: TimeInterval) -> Int {
        guard let countAnimationStart else { return 0 }
        return Int(max(0, now - countAnimationStart) / Self.countStepInterval)
    }

    private func updateCountAnimation(snapshot: GameSnapshot, mode: HomeGameMode) {
        guard let previous = self.snapshot, self.mode == mode, previous.mode == snapshot.mode,
              snapshot.isRunning || snapshot.isFinished, !(previous.isFinished && snapshot.isRunning),
              snapshot.totalCleared >= previous.totalCleared, !reducesMotion() else {
            stopCountAnimation()
            return
        }
        let now = animationClock()
        let step = countStep(at: now)
        countTransitions = countTransitions.filter { step < $0.value.endStep }
        let startsNewSequence = countTransitions.isEmpty
        let startStep = startsNewSequence ? 0 : step
        for kind in PieceKind.allCases {
            let value = snapshot.clearedByKind[kind, default: 0]
            let previousValue = previous.clearedByKind[kind, default: 0]
            if value > previousValue {
                // 所有分类沿用同一节拍，插入新的消除时只更新终点。
                let initial = countTransitions[kind]?.value(at: step) ?? previousValue
                countTransitions[kind] = CountTransition(initial: initial, target: value, startStep: startStep)
            } else if value < previousValue {
                countTransitions.removeValue(forKey: kind)
            }
        }
        guard !countTransitions.isEmpty else {
            stopCountAnimation()
            return
        }
        if startsNewSequence { countAnimationStart = now }
        guard countAnimationTimer == nil, isCountAnimationVisible else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advanceCountAnimation() }
        RunLoop.main.add(timer, forMode: .common)
        countAnimationTimer = timer
    }

    private var isCountAnimationVisible: Bool {
        guard let window else { return false }
        return window.isVisible && !window.isMiniaturized && !isHiddenOrHasHiddenAncestor
    }

    private func advanceCountAnimation() {
        let step = countStep(at: animationClock())
        countTransitions = countTransitions.filter { step < $0.value.endStep }
        if countTransitions.isEmpty || reducesMotion() || !isCountAnimationVisible { stopCountAnimation() }
        needsDisplay = true
    }

    private func stopCountAnimation() {
        countTransitions.removeAll()
        countAnimationStart = nil
        countAnimationTimer?.invalidate()
        countAnimationTimer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let surface = surfaceRect
        guard let snapshot, surface.width > 40, surface.height > 45 else { return }
        let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
        let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
        let face = Face(frame: surface)
        let total = HomeDashboardStyle.slant(face.totals)
        if let revealFraction {
            let depth = 1 - revealFraction
            NSGraphicsContext.saveGraphicsState()
            let offset = NSAffineTransform()
            offset.translateX(by: 2.5 * depth, yBy: 4.5 * depth)
            offset.concat()
            accent.withAlphaComponent(0.46 * depth).setFill()
            total.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        drawBackingPlate(on: face)
        if let track = budgetTrackRect { drawTrack(track, accent: accent, snapshot: snapshot) }
        // 总数牌压在规则背板上，独立描边在左右两侧形成错位。
        fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                             HomeDashboardStyle.color(0x101A25)], angle: 14,
             border: HomeDashboardStyle.color(0x57636B))
        let counts = displayedCounts()
        drawTotals(counts.values.reduce(0, +), on: face, accent: accent)
        drawBreakdown(counts, on: face)
        if let revealFraction { drawRevealHighlight(in: surface, outline: total, accent: accent, fraction: revealFraction) }
    }

    private func drawBackingPlate(on face: Face) {
        let plate = face.rules
        let blue = HomeDashboardStyle.color(0x203547)
        NSGradient(colors: [blue.withAlphaComponent(0.62), blue.withAlphaComponent(0.30), blue.withAlphaComponent(0)])?
            .draw(in: HomeDashboardStyle.slant(plate), angle: 90)
        let rim = HomeDashboardStyle.color(0x657681)
        let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
        let topLeft = NSPoint(x: plate.minX + cut, y: plate.minY)
        let topRight = NSPoint(x: plate.maxX, y: plate.minY)
        let joinY = face.totals.minY
        let joinX = plate.maxX - HomeDashboardStyle.edgeOffset(for: joinY - plate.minY)
        HomeDashboardStyle.line(from: topLeft, to: topRight, color: rim.withAlphaComponent(0.80), width: 1.25)
        HomeDashboardStyle.line(from: topRight, to: NSPoint(x: joinX, y: joinY), color: rim.withAlphaComponent(0.65), width: 1.25)
        let leftRim = HomeDashboardStyle.slant(NSRect(x: plate.minX - 0.625, y: plate.minY,
                                                      width: cut + 1.25, height: plate.height))
        NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
    }

    private func drawTotals(_ totalCleared: Int, on face: Face, accent: NSColor) {
        let body = face.box(478, 175, width: 506, height: 80)
        let x = body.minX
        let available = body.width
        let right = body.maxX
        if showsBudget {
            let split = x + available * 0.48
            let separatorTop = body.minY + 8
            let separatorBottom = body.maxY - 8
            let separatorOffset = HomeDashboardStyle.edgeOffset(for: separatorBottom - separatorTop) / 2
            let columnPadding = separatorOffset + 5
            let metricY = body.midY
            drawStackedMetric(budgetText, labelKey: budgetLabelKey, center: metricY, x: x,
                              width: split - x - columnPadding, height: body.height, color: accent, alignment: .left)
            drawStackedMetric(String(totalCleared), labelKey: "home.cleared_title", center: metricY,
                              x: split + columnPadding, width: right - split - columnPadding, height: body.height,
                              color: HomeDashboardStyle.ink, alignment: .right)
            HomeDashboardStyle.line(from: NSPoint(x: split + separatorOffset, y: separatorTop),
                                    to: NSPoint(x: split - separatorOffset, y: separatorBottom), color: HomeDashboardStyle.border)
        } else {
            let title = AchievementText.string("home.cleared_title")
            let titleWidth = available * 0.48
            let titleSize = GameLobbyStyle.fittedSize(title, width: titleWidth, preferred: max(12, 21 * face.typographyScale),
                                                       minimum: 10, weight: .bold)
            label(title, x: x, y: body.midY, width: titleWidth, size: titleSize, weight: .bold)
            let value = String(totalCleared)
            let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth - 8,
                                                 preferred: max(24, 58 * face.typographyScale), minimum: 12, weight: .black)
            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1, width: available - titleWidth, height: body.height),
                  size: size, weight: .black, alignment: .right)
        }
    }

    private func drawStackedMetric(_ value: String, labelKey: String, center: CGFloat, x: CGFloat, width: CGFloat,
                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment) {
        let title = AchievementText.string(labelKey)
        let titleSize = GameLobbyStyle.fittedSize(title, width: width, preferred: min(13, height * 0.26),
                                                   minimum: 8, weight: .semibold)
        let valueSize = GameLobbyStyle.fittedSize(value, width: width, preferred: min(38, height * 0.59),
                                                   minimum: 11, weight: .heavy)
        label(title, x: x, y: center - height * 0.24, width: width, size: titleSize, weight: .semibold,
              color: HomeDashboardStyle.muted, alignment: alignment)
        let number = NSRect(x: x, y: center - height * 0.39, width: width, height: height)
        count(value, in: number, size: valueSize, weight: .heavy, color: color, alignment: alignment)
    }

    private func drawBreakdown(_ counts: [PieceKind: Int], on face: Face) {
        // 各分格用独立轮廓，双斜边之间留出原稿中的暗缝。
        let cells = face.breakdownCellRects
        let rim = HomeDashboardStyle.color(0x55616A)
        for (kind, cell) in zip(PieceKind.allCases, cells) {
            let shape = HomeDashboardStyle.slant(cell)
            fill(shape, colors: [HomeDashboardStyle.color(0x202B34), HomeDashboardStyle.color(0x121E29)],
                 angle: 21, border: rim)
            let cut = HomeDashboardStyle.edgeOffset(for: cell.height)
            let padding = min(24, (cell.width - cut) * 0.18)
            let content = cell.insetBy(dx: cut / 2 + padding, dy: 0)
            // 图标按较短一边等比缩放，四格的图标起点和数字间距使用相同规则。
            let scale = face.typographyScale
            let icon = NSRect(x: content.minX, y: cell.midY - 15 * scale, width: 42 * scale, height: 30 * scale)
            HomeLobbyArtwork.drawPiece(kind, in: icon)
            let number = String(counts[kind, default: 0])
            let numberX = icon.maxX + 12 * scale
            let slot = NSRect(x: numberX, y: cell.minY, width: max(0, content.maxX - numberX), height: cell.height)
            let size = GameLobbyStyle.fittedSize(number, width: slot.width, preferred: max(11, 21 * face.typographyScale),
                                                 minimum: 7, weight: .semibold)
            count(number, in: slot, size: size, weight: .semibold)
        }
        if let first = cells.first, let last = cells.last {
            let right = last.maxX - HomeDashboardStyle.edgeOffset(for: last.height)
            HomeDashboardStyle.line(from: NSPoint(x: first.minX, y: first.maxY),
                                    to: NSPoint(x: right, y: last.maxY), color: rim)
        }
    }

    private func fill(_ shape: NSBezierPath, colors: [NSColor], angle: CGFloat, border: NSColor) {
        NSGradient(colors: colors)?.draw(in: shape, angle: angle)
        border.setStroke()
        shape.lineWidth = 1.25
        shape.stroke()
    }

    private func count(_ value: String, in slot: NSRect, size: CGFloat, weight: NSFont.Weight,
                       color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .left) {
        guard slot.width > 0 else { return }
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let width = max(slot.width, ceil((value as NSString).size(withAttributes: [.font: font]).width) + 2)
        // 极窄窗口里的长数字仍保留全部位数，只压缩字形宽度。
        NSGraphicsContext.saveGraphicsState()
        let fit = NSAffineTransform()
        fit.translateX(by: slot.minX, yBy: 0)
        fit.scaleX(by: slot.width / width, yBy: 1)
        fit.concat()
        label(value, x: 0, y: slot.midY, width: width, size: size, weight: weight, color: color, alignment: alignment)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight,
                       color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .left) {
        let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).height)
        HomeDashboardStyle.text(value, in: NSRect(x: x, y: y - height / 2, width: width, height: height + 1),
                                size: size, weight: weight, color: color, alignment: alignment)
    }

    private func drawRevealHighlight(in face: NSRect, outline: NSBezierPath, accent: NSColor, fraction: CGFloat) {
        // 斜光随卡面掠过一次，最终回到静态描边。
        let intensity = sin(.pi * fraction)
        guard intensity > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        let width = min(140, face.width * 0.32) + HomeDashboardStyle.edgeOffset(for: face.height)
        let x = face.maxX + width - (face.width + width * 2) * fraction
        let beam = NSRect(x: x, y: face.minY, width: width, height: face.height)
        NSGradient(colors: [.clear, accent.withAlphaComponent(0.22 * intensity), .clear])?
            .draw(in: HomeDashboardStyle.slant(beam), angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawTrack(_ track: NSRect, accent: NSColor, snapshot: GameSnapshot) {
        let idleColor = HomeDashboardStyle.muted.withAlphaComponent(0.18)
        if mode == .moves {
            // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
            let limit = HomeGameMode.moveLimit
            let remaining = snapshot.remainingSwaps ?? limit
            let cut = HomeDashboardStyle.edgeOffset(for: track.height)
            let available = max(0, track.width - cut)
            let gap = min(2, available / CGFloat(limit * 2))
            let width = (available - gap * CGFloat(limit - 1)) / CGFloat(limit)
            for index in 0..<limit {
                let segment = NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY,
                                     width: width + cut, height: track.height)
                (index < remaining ? accent : idleColor).setFill()
                HomeDashboardStyle.slant(segment).fill()
            }
        } else {
            idleColor.setFill()
            HomeDashboardStyle.slant(track).fill()
            let fill = HomeDashboardStyle.segmentFill(track, fraction: remainingFraction)
            guard !fill.isEmpty else { return }
            NSGradient(colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent])?
                .draw(in: fill, angle: 90)
        }
    }
}
