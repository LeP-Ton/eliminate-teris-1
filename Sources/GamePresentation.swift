import Cocoa

/// 首页只暴露固定规则；历史记录中的旧档位仍可被读取。
enum HomeGameMode: Int, CaseIterable {
    case free, speedRun, scoreAttack

    static let scoreAttackDuration: TimeInterval = 60
    static let speedRunTarget = 300

    var gameMode: GameMode {
        switch self {
        case .free: return .free
        case .speedRun: return .speedRun(targetScore: Self.speedRunTarget)
        case .scoreAttack: return .scoreAttack(duration: Self.scoreAttackDuration)
        }
    }

    var key: String {
        switch self {
        case .free: return "free"
        case .speedRun: return "speed_run"
        case .scoreAttack: return "score_attack"
        }
    }

    var symbol: String {
        switch self {
        case .free: return "infinity"
        case .speedRun: return "stopwatch"
        case .scoreAttack: return "trophy"
        }
    }
}

/// 首页与辅助面板共用轻量浅色主题，所有颜色显式定义，避免系统深浅色切换影响对比度。
enum HomeStyle {
    static let background = NSColor(calibratedRed: 0.985, green: 0.979, blue: 0.966, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.085, alpha: 1)
    static let secondary = NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.49, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.60, green: 0.62, blue: 0.65, alpha: 1)
    static let border = NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.89, alpha: 1)
    static let blue = NSColor(calibratedRed: 0, green: 0.51, blue: 1, alpha: 1)
    static let yellow = NSColor(calibratedRed: 1, green: 0.79, blue: 0.025, alpha: 1)
    static let green = NSColor(calibratedRed: 0.025, green: 0.79, blue: 0.34, alpha: 1)

    static func text(_ string: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
                     color: NSColor = ink, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (string as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                           .foregroundColor: color, .paragraphStyle: paragraph])
    }

    static func symbol(_ name: String, in rect: NSRect, color: NSColor = ink) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let tinted = NSImage(size: rect.size, flipped: true) { target in
            image.draw(in: target)
            color.setFill()
            target.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: rect)
    }

    static func card(_ rect: NSRect, fill: NSColor = NSColor.white.withAlphaComponent(0.7), border: NSColor = border, radius: CGFloat = 10) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func piece(_ kind: PieceKind, in rect: NSRect, shadow: Bool = true) {
        let cell = min(rect.width / 3, rect.height / 2)
        let origin = NSPoint(x: rect.midX - cell * 1.5, y: rect.midY - cell)
        NSGraphicsContext.saveGraphicsState()
        if shadow {
            let effect = NSShadow()
            effect.shadowColor = kind.color.withAlphaComponent(0.17)
            effect.shadowBlurRadius = cell * 0.3
            effect.shadowOffset = NSSize(width: cell * 0.12, height: -cell * 0.15)
            effect.set()
        }
        for block in kind.blocks {
            let tile = NSRect(x: origin.x + CGFloat(block.x) * cell, y: origin.y + CGFloat(1 - block.y) * cell,
                              width: cell - 0.5, height: cell - 0.5)
            let path = NSBezierPath(roundedRect: tile, xRadius: max(1, cell * 0.09), yRadius: max(1, cell * 0.09))
            let light = kind.color.blended(withFraction: 0.18, of: .white) ?? kind.color
            let dark = kind.color.shadow(withLevel: 0.12) ?? kind.color
            NSGradient(colors: [light, kind.color, dark])?.draw(in: path, angle: 90)
            dark.withAlphaComponent(0.7).setStroke()
            path.lineWidth = max(0.5, cell * 0.025)
            path.stroke()
            NSColor.white.withAlphaComponent(0.18).setStroke()
            NSBezierPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), xRadius: 2, yRadius: 2).stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
