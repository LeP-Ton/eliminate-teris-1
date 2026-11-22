import Cocoa

/// 大厅的柔和游戏材质。所有绘制都限制在控件内部，保留原生点击区域和焦点环。
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

    static func surface(_ rect: NSRect, radius: CGFloat = 15, tint: NSColor = .white, strength: CGFloat = 0.07) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.13, alpha: strength)
        shadow.shadowBlurRadius = 8; shadow.shadowOffset = NSSize(width: 0, height: -3); shadow.set()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()
        gradient(rect, colors: [.white, tint], radius: radius)
        HomeStyle.border.withAlphaComponent(0.42).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        outline.lineWidth = 0.7; outline.stroke()
    }

    static func fittedSize(_ text: String, width: CGFloat, preferred: CGFloat, minimum: CGFloat, weight: NSFont.Weight) -> CGFloat {
        var size = preferred
        while size > minimum, (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width > width {
            size -= 1
        }
        return size
    }

    static func wrappedText(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                               attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: paragraph])
    }

    static func primaryButton(_ bounds: NSRect, hover: CGFloat, press: CGFloat) {
        // 静止时按钮的立体底边贴齐控件底边，与右侧卡片共用一条基线。
        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: 2 + press * 2 - hover)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = amber.withAlphaComponent(0.22 + hover * 0.12)
        shadow.shadowBlurRadius = 8 + hover * 4
        shadow.shadowOffset = NSSize(width: 0, height: -3 + press * 2); shadow.set()
        amber.setFill(); NSBezierPath(roundedRect: face, xRadius: 13, yRadius: 13).fill()
        NSGraphicsContext.restoreGraphicsState()
        let lip = face.offsetBy(dx: 0, dy: 3 - press * 2)
        NSColor(calibratedRed: 0.91, green: 0.62, blue: 0.015, alpha: 1).setFill()
        NSBezierPath(roundedRect: lip, xRadius: 13, yRadius: 13).fill()
        gradient(face, colors: [NSColor(calibratedRed: 1, green: 0.88, blue: 0.25, alpha: 1), HomeStyle.yellow], radius: 13)
        NSColor.white.withAlphaComponent(0.65).setStroke()
        let highlight = NSBezierPath()
        highlight.lineWidth = 1
        highlight.move(to: NSPoint(x: face.minX + 14, y: face.minY + 1))
        highlight.line(to: NSPoint(x: face.maxX - 14, y: face.minY + 1)); highlight.stroke()
        // 细小的高光只用于按钮表面，避免让整张首页持续闪烁。
        glow(NSRect(x: face.minX + 8, y: face.minY, width: face.width * 0.55, height: face.height), color: .white.withAlphaComponent(0.14 + hover * 0.12))
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
