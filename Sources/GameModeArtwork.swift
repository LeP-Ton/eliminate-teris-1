import Cocoa

/// 模式使用独立的游戏主题图案；64 点设计画布等比缩放，不复用无限环或交换箭头。
enum GameModeArtwork {
    private static var cache: [HomeGameMode: NSImage] = [:]

    static func image(for mode: HomeGameMode) -> NSImage {
        if let image = cache[mode] { return image }
        let image = NSImage(size: NSSize(width: 64, height: 64), flipped: true) { _ in
            switch mode {
            case .free: freeTiles()
            case .timed: stopwatch()
            case .moves: actionCounter()
            }
            return true
        }
        image.isTemplate = false; cache[mode] = image
        return image
    }

    static func draw(_ mode: HomeGameMode, in bounds: NSRect) {
        let image = image(for: mode)
        image.draw(in: GameIconRenderer.fittedRect(size: image.size, in: bounds), from: .zero,
                   operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    /// 方块通过侧面、顶部高光和柔和色影获得体积，三种图案保持同一光照。
    private static func tile(_ rect: NSRect, color: NSColor, angle: CGFloat = 0) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY); transform.rotate(byDegrees: angle)
        transform.translateX(by: -rect.midX, yBy: -rect.midY); transform.concat()
        let shade = color.shadow(withLevel: 0.18) ?? color
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = color.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 4; shadow.shadowOffset = NSSize(width: 1, height: -3); shadow.set()
        shade.setFill(); NSBezierPath(roundedRect: rect.offsetBy(dx: 1.5, dy: 2.5), xRadius: 4, yRadius: 4).fill()
        NSGraphicsContext.restoreGraphicsState()
        GameLobbyStyle.gradient(rect, colors: [color.blended(withFraction: 0.28, of: .white) ?? color, color], radius: 4)
        NSColor.white.withAlphaComponent(0.4).setStroke()
        let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        edge.lineWidth = 0.7; edge.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func freeTiles() {
        // 疏朗悬浮的独立方块表达随心操作，避免画成需要向上堆叠的棋盘。
        GameLobbyStyle.glow(NSRect(x: 6, y: 27, width: 52, height: 33), color: GameLobbyStyle.teal.withAlphaComponent(0.13))
        tile(NSRect(x: 10, y: 11, width: 19, height: 19), color: .systemOrange, angle: -12)
        tile(NSRect(x: 35, y: 7, width: 19, height: 19), color: HomeStyle.blue, angle: 9)
        tile(NSRect(x: 7, y: 36, width: 19, height: 19), color: GameLobbyStyle.teal, angle: 7)
        tile(NSRect(x: 34, y: 34, width: 21, height: 21), color: .systemRed, angle: -8)
        spark(at: NSPoint(x: 33, y: 31), color: GameLobbyStyle.amber, length: 3)
    }

    private static func stopwatch() {
        GameLobbyStyle.glow(NSRect(x: 10, y: 31, width: 48, height: 30), color: GameLobbyStyle.amber.withAlphaComponent(0.15))
        tile(NSRect(x: 28, y: 4, width: 12, height: 8), color: GameLobbyStyle.amber)
        tile(NSRect(x: 47, y: 14, width: 9, height: 7), color: GameLobbyStyle.amber, angle: 35)
        let shell = NSRect(x: 15, y: 13, width: 43, height: 43)
        NSColor(calibratedRed: 0.89, green: 0.42, blue: 0.02, alpha: 1).setFill()
        NSBezierPath(ovalIn: shell.offsetBy(dx: 1, dy: 3)).fill()
        NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.85, blue: 0.29, alpha: 1), .systemOrange])?
            .draw(in: NSBezierPath(ovalIn: shell), angle: 90)
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: shell.insetBy(dx: 5, dy: 5)).fill()
        let center = NSPoint(x: shell.midX, y: shell.midY)
        for index in 0..<12 {
            let a = CGFloat(index) * .pi / 6
            let point = NSPoint(x: center.x + sin(a) * 13.2, y: center.y - cos(a) * 13.2)
            HomeStyle.secondary.withAlphaComponent(index.isMultiple(of: 3) ? 0.7 : 0.28).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - 0.8, y: point.y - 0.8, width: 1.6, height: 1.6)).fill()
        }
        stroke([NSPoint(x: center.x, y: center.y - 10), center, NSPoint(x: center.x + 8, y: center.y + 5)], color: HomeStyle.ink, width: 2.8)
        GameLobbyStyle.amber.setFill(); NSBezierPath(ovalIn: NSRect(x: center.x - 2.1, y: center.y - 2.1, width: 4.2, height: 4.2)).fill()
        stroke([NSPoint(x: 5, y: 24), NSPoint(x: 11, y: 24)], color: GameLobbyStyle.amber, width: 2.5)
        stroke([NSPoint(x: 3, y: 33), NSPoint(x: 9, y: 33)], color: GameLobbyStyle.amber.withAlphaComponent(0.65), width: 2.5)
    }

    private static func actionCounter() {
        GameLobbyStyle.glow(NSRect(x: 6, y: 31, width: 53, height: 30), color: HomeStyle.blue.withAlphaComponent(0.15))
        // 侧面的行动按钮表达可消耗次数；不用日历挂环，避免被理解为日期。
        tile(NSRect(x: 51, y: 25, width: 8, height: 13), color: GameLobbyStyle.amber)
        let shell = NSRect(x: 9, y: 12, width: 46, height: 40)
        NSColor(calibratedRed: 0.02, green: 0.30, blue: 0.70, alpha: 1).setFill()
        NSBezierPath(roundedRect: shell.offsetBy(dx: 1, dy: 3), xRadius: 8, yRadius: 8).fill()
        GameLobbyStyle.gradient(shell, colors: [NSColor(calibratedRed: 0.25, green: 0.73, blue: 1, alpha: 1), HomeStyle.blue], radius: 8)
        // “30”是固定玩法的行动预算，不随某一局扣减，防止模式入口被误认为实时状态。
        let display = NSRect(x: 14, y: 18, width: 36, height: 25)
        GameLobbyStyle.gradient(display, colors: [.white, NSColor(calibratedRed: 0.90, green: 0.97, blue: 1, alpha: 1)], radius: 4)
        let text = "\(HomeGameMode.moveLimit)" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 23, weight: .heavy)
        let size = text.size(withAttributes: [.font: font])
        text.draw(at: NSPoint(x: display.midX - size.width / 2, y: display.midY - size.height / 2), withAttributes: [.font: font, .foregroundColor: HomeStyle.ink])
        for index in 0..<3 {
            NSColor.white.withAlphaComponent(0.92 - Double(index) * 0.17).setFill()
            NSBezierPath(roundedRect: NSRect(x: CGFloat(21 + index * 8), y: 46, width: 5, height: 3), xRadius: 1, yRadius: 1).fill()
        }
    }

    private static func stroke(_ points: [NSPoint], color: NSColor, width: CGFloat) {
        guard let first = points.first else { return }
        let path = NSBezierPath(); path.move(to: first)
        points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round
        color.setStroke(); path.stroke()
    }

    private static func spark(at point: NSPoint, color: NSColor, length: CGFloat) {
        stroke([NSPoint(x: point.x - length, y: point.y), NSPoint(x: point.x + length, y: point.y)], color: color, width: 1.7)
        stroke([NSPoint(x: point.x, y: point.y - length), NSPoint(x: point.x, y: point.y + length)], color: color, width: 1.7)
    }
}
