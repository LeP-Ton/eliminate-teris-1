import Cocoa

/// 局内把行动预算置于插画上方；只消费快照，不参与计时、扣次或结束判定。
final class HomeChallengeHUDView: NSView {
    private(set) var snapshot: GameSnapshot?
    private(set) var mode: HomeGameMode = .timed
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { nil }

    var remainingFraction: CGFloat {
        guard let snapshot else { return 1 }
        let fraction = mode == .timed
            ? (snapshot.remainingTime ?? HomeGameMode.timedDuration) / HomeGameMode.timedDuration
            : Double(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) / Double(HomeGameMode.moveLimit)
        return CGFloat(min(1, max(0, fraction)))
    }

    var budgetText: String {
        guard let snapshot else { return "" }
        if mode == .moves { return String(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) }
        let seconds = max(0, Int(ceil(snapshot.remainingTime ?? HomeGameMode.timedDuration)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
        self.snapshot = snapshot; self.mode = mode
        setAccessibilityLabel(AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
            + ": " + budgetText + "; " + AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let snapshot else { return }
        let urgent = !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : HomeStyle.blue
        let face = bounds.insetBy(dx: 3, dy: 5)
        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1))
        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: face.width * 0.6, height: face.height), color: accent.withAlphaComponent(0.08))
        let split = face.width * 0.57
        let label = AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
        HomeStyle.text(label, in: NSRect(x: 22, y: 17, width: split - 30, height: 20), size: 12, weight: .semibold, color: HomeStyle.secondary)
        let budgetSize = GameLobbyStyle.fittedSize(budgetText, width: split - 32, preferred: 44, minimum: 25, weight: .heavy)
        HomeStyle.text(budgetText, in: NSRect(x: 20, y: 36, width: split - 30, height: 58), size: budgetSize, weight: .heavy,
                       color: urgent ? .systemRed : HomeStyle.ink)
        HomeStyle.border.withAlphaComponent(0.6).setStroke()
        let divider = NSBezierPath(); divider.move(to: NSPoint(x: split, y: 22)); divider.line(to: NSPoint(x: split, y: 89)); divider.stroke()
        HomeStyle.text(AchievementText.string("home.cleared_title"), in: NSRect(x: split + 20, y: 19, width: face.width - split - 27, height: 20),
                       size: 12, weight: .semibold, color: HomeStyle.secondary)
        let count = String(snapshot.totalCleared)
        let countSize = GameLobbyStyle.fittedSize(count, width: face.width - split - 30, preferred: 38, minimum: 18, weight: .heavy)
        HomeStyle.text(count, in: NSRect(x: split + 19, y: 42, width: face.width - split - 28, height: 48), size: countSize, weight: .heavy)
        let track = NSRect(x: 22, y: face.height - 17, width: face.width - 38, height: 5)
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
