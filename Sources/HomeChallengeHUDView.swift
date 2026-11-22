import Cocoa

/// 左侧局内面板从同一份快照展示剩余预算、消除总数和四类方块明细。
final class HomeChallengeHUDView: NSView {
    static let surfaceInsetY: CGFloat = 5
    var surfaceRect: NSRect { bounds.insetBy(dx: 3, dy: Self.surfaceInsetY) }
    private(set) var snapshot: GameSnapshot?
    private(set) var mode: HomeGameMode = .timed
    var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { nil }

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

    override func draw(_ dirtyRect: NSRect) {
        guard let snapshot else { return }
        let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : mode == .moves ? HomeStyle.blue : GameLobbyStyle.teal
        let face = surfaceRect
        let depth = revealFraction.map { 1 - $0 } ?? 0
        if depth > 0 {
            // 在卡面右下缘露出带色的厚度，转正时收回到静态卡面的阴影中。
            let side = face.offsetBy(dx: 2.5 * depth, dy: 4.5 * depth)
            GameLobbyStyle.gradient(side, colors: [accent.withAlphaComponent(0.26 * depth),
                                                  accent.withAlphaComponent(0.68 * depth)], radius: 18)
        }
        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1), strength: 0.07 + 0.13 * depth)
        // 扣除挑战预算后，消除总数占三分之一，其余宽度交给四类方块明细。
        let content = face.insetBy(dx: 20, dy: 18)
        let budgetWidth = showsBudget ? content.width * 0.27 : 0
        let totalWidth = (content.width - budgetWidth) / 3
        let totalX = content.minX + budgetWidth
        let breakdownX = totalX + totalWidth
        let metricTop = content.minY + (showsBudget ? 4 : 16)
        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: budgetWidth + totalWidth, height: face.height),
                            color: accent.withAlphaComponent(0.08))
        if showsBudget {
            drawMetric(budgetText, label: budgetLabelKey, x: content.minX, y: metricTop,
                       width: budgetWidth - 17, color: urgent ? .systemRed : HomeStyle.ink)
            drawDivider(at: totalX - 9, from: metricTop, to: metricTop + 76)
        }
        drawMetric(String(snapshot.totalCleared), label: "home.cleared_title", x: totalX, y: metricTop,
                   width: totalWidth - 17, color: HomeStyle.ink)
        drawBreakdown(snapshot, in: NSRect(x: breakdownX, y: metricTop + 33, width: content.maxX - breakdownX, height: 28))
        if showsBudget {
            drawTrack(NSRect(x: content.minX, y: content.maxY - 6, width: content.width, height: 6), accent: accent, snapshot: snapshot)
        }
        if let revealFraction { drawRevealHighlight(in: face, accent: accent, fraction: revealFraction) }
    }

    private func drawRevealHighlight(in face: NSRect, accent: NSColor, fraction: CGFloat) {
        // 随滑入从右向左掠过一次，收尾时完全淡出，只照亮卡面。
        let intensity = sin(.pi * fraction)
        guard intensity > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        let outline = NSBezierPath(roundedRect: face, xRadius: 18, yRadius: 18)
        outline.addClip()
        let x = face.maxX + 90 - (face.width + 180) * fraction
        let shine = NSBezierPath()
        shine.move(to: NSPoint(x: x, y: face.minY))
        shine.line(to: NSPoint(x: x + 135, y: face.minY))
        shine.line(to: NSPoint(x: x + 83, y: face.maxY))
        shine.line(to: NSPoint(x: x - 52, y: face.maxY))
        shine.close()
        NSGradient(colors: [.clear, .white.withAlphaComponent(0.42 * intensity), accent.withAlphaComponent(0.12 * intensity), .clear])?
            .draw(in: shine, angle: 0)
        accent.withAlphaComponent(0.32 * intensity).setStroke()
        outline.lineWidth = 2
        outline.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMetric(_ value: String, label key: String, x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor) {
        let label = AchievementText.string(key)
        let labelSize = GameLobbyStyle.fittedSize(label, width: width, preferred: 13, minimum: 10, weight: .semibold)
        HomeStyle.text(label, in: NSRect(x: x, y: y, width: width, height: 19), size: labelSize, weight: .semibold, color: HomeStyle.secondary)
        let size = GameLobbyStyle.fittedSize(value, width: width, preferred: 44, minimum: 14, weight: .heavy)
        let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).height)
        HomeStyle.text(value, in: NSRect(x: x, y: y + 47 - height / 2, width: width, height: height), size: size, weight: .heavy, color: color)
    }

    private func drawDivider(at x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
        HomeStyle.border.withAlphaComponent(0.6).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: x, y: top))
        divider.line(to: NSPoint(x: x, y: bottom))
        divider.stroke()
    }

    private func drawBreakdown(_ snapshot: GameSnapshot, in rect: NSRect) {
        let kinds = PieceKind.allCases
        let slot = rect.width / CGFloat(kinds.count)
        let iconWidth = min(36, slot * 0.46)
        let gap: CGFloat = 6
        let numberWidth = slot - iconWidth - gap - 6
        // 四组都从各自的列左边缘排起，数字位数变化时图标之间仍然等距。
        for (index, kind) in kinds.enumerated() {
            let number = String(snapshot.clearedByKind[kind, default: 0])
            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: 18, minimum: 10, weight: .semibold)
            let height = ceil((number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height)
            let iconX = rect.minX + CGFloat(index) * slot
            let numberX = iconX + iconWidth + gap
            HomeStyle.piece(kind, in: NSRect(x: iconX, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
            HomeStyle.text(number, in: NSRect(x: numberX, y: rect.midY - height / 2, width: numberWidth, height: height),
                           size: size, weight: .semibold)
        }
    }

    private func drawTrack(_ track: NSRect, accent: NSColor, snapshot: GameSnapshot) {
        HomeStyle.ink.withAlphaComponent(0.055).setFill()
        NSBezierPath(roundedRect: track, xRadius: 2.5, yRadius: 2.5).fill()
        if mode == .moves {
            // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
            let gap: CGFloat = 2
            let width = (track.width - gap * CGFloat(HomeGameMode.moveLimit - 1)) / CGFloat(HomeGameMode.moveLimit)
            for index in 0..<max(0, min(HomeGameMode.moveLimit, snapshot.remainingSwaps ?? 0)) {
                accent.setFill()
                NSBezierPath(roundedRect: NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY, width: width, height: track.height), xRadius: 1.5, yRadius: 1.5).fill()
            }
        } else if remainingFraction > 0 {
            GameLobbyStyle.gradient(NSRect(x: track.minX, y: track.minY, width: track.width * remainingFraction, height: track.height),
                                    colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent], radius: 2.5)
        }
    }
}
