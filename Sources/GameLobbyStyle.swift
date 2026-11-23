import Cocoa

/// 游戏图标与统计界面共用的渐变、光晕和字号计算。
enum GameLobbyStyle {
    static let amber = NSColor(calibratedRed: 1, green: 0.68, blue: 0.08, alpha: 1)
    static let teal = NSColor(calibratedRed: 0.05, green: 0.70, blue: 0.54, alpha: 1)

    static func gradient(_ rect: NSRect, colors: [NSColor], radius: CGFloat) {
        NSGradient(colors: colors)?.draw(in: NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius), angle: 90)
    }

    static func glow(_ rect: NSRect, color: NSColor) {
        NSGradient(starting: color, ending: color.withAlphaComponent(0))?
            .draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
    }

    static func fittedSize(_ text: String, width: CGFloat, preferred: CGFloat, minimum: CGFloat, weight: NSFont.Weight) -> CGFloat {
        var size = preferred
        while size > minimum, (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width > width {
            size -= 1
        }
        return size
    }
}

/// 悬停、按压和选中共用短动画；仅变化期间刷新，界面 tick 不重新启动过渡。
final class GameControlFeedback {
    struct Values: Equatable {
        var hover: CGFloat = 0
        var press: CGFloat = 0
        var selection: CGFloat = 0
        func mixed(with end: Values, fraction: CGFloat) -> Values {
            Values(hover: hover + (end.hover - hover) * fraction,
                   press: press + (end.press - press) * fraction,
                   selection: selection + (end.selection - selection) * fraction)
        }
    }
    private(set) var values = Values()
    private var origin = Values(), target = Values()
    private var started: TimeInterval = 0
    private var timer: Timer?
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var onUpdate: (() -> Void)?
    static let duration: TimeInterval = 0.18
    deinit { timer?.invalidate() }

    func update(hover: Bool, press: Bool, selected: Bool = false, animated: Bool) {
        let next = Values(hover: hover ? 1 : 0, press: press ? 1 : 0, selection: selected ? 1 : 0)
        guard next != target else { return }
        advance(at: now())
        origin = values; target = next; started = now()
        timer?.invalidate(); timer = nil
        guard animated, !reducesMotion() else {
            values = target; origin = target; started -= Self.duration
            onUpdate?(); return
        }
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advance(at: self?.now() ?? 0) }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }

    /// 测试可推进时间，快速反向时从当前视觉值接续，避免高光跳变。
    func advance(at time: TimeInterval) {
        if reducesMotion() {
            values = target; origin = target; timer?.invalidate(); timer = nil
            onUpdate?(); return
        }
        let t = CGFloat(min(1, max(0, (time - started) / Self.duration)))
        let eased = t * t * (3 - 2 * t)
        values = origin.mixed(with: target, fraction: eased)
        if t >= 1 { timer?.invalidate(); timer = nil }
        onUpdate?()
    }
}
