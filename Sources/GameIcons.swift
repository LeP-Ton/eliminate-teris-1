import Cocoa

/// 统一图标的比例、线条和系统兼容性；不把宽图标强行拉成正方形。
enum GameIconRenderer {
    private static var symbolCache: [String: NSImage] = [:]
    static func fittedRect(size: NSSize, in bounds: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return NSRect(x: bounds.midX - size.width * scale / 2, y: bounds.midY - size.height * scale / 2,
                      width: size.width * scale, height: size.height * scale)
    }

    static func drawSymbol(_ name: String, in bounds: NSRect, color: NSColor, fallbacks: [String] = []) {
        // 模式图案是游戏美术，颜色由自身定义；所有入口共用同一资源，保持等比。
        if let mode = HomeGameMode.allCases.first(where: { $0.symbol == name }) {
            GameModeArtwork.draw(mode, in: bounds); return
        }
        if name == "trophy" { drawTrophy(in: bounds, color: color); return }
        if name == "flag.checkered" { drawFinishFlag(in: bounds, color: color); return }
        let key = ([name] + fallbacks).joined(separator: ".") + color.description
        if let cached = symbolCache[key] {
            cached.draw(in: fittedRect(size: cached.size, in: bounds), from: .zero, operation: .sourceOver,
                        fraction: 1, respectFlipped: true, hints: nil)
            return
        }
        let image = ([name] + fallbacks + ["star"]).compactMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)
        }.first
        guard let image else { return }
        let configured = image.withSymbolConfiguration(.init(pointSize: 32, weight: .regular)) ?? image
        // 统一在四倍分辨率下定型，避免系统符号在不同控件尺寸下重新选取光学校正字形。
        guard let pixels = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(ceil(configured.size.width * 4)),
                                            pixelsHigh: Int(ceil(configured.size.height * 4)), bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: pixels) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let target = NSRect(x: 0, y: 0, width: pixels.pixelsWide, height: pixels.pixelsHigh)
        configured.draw(in: target)
        color.setFill(); target.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = pixels.cgImage else { return }
        let tinted = NSImage(cgImage: cgImage, size: configured.size)
        tinted.isTemplate = false
        symbolCache[key] = tinted
        tinted.draw(in: fittedRect(size: configured.size, in: bounds), from: .zero, operation: .sourceOver,
                    fraction: 1, respectFlipped: true, hints: nil)
    }

    /// 终点旗同样使用本地矢量，避免旧系统回退为普通旗帜后与入门成就混淆。
    private static func drawFinishFlag(in bounds: NSRect, color: NSColor) {
        let rect = fittedRect(size: NSSize(width: 24, height: 24), in: bounds)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 24, yBy: rect.height / 24)
        transform.concat()
        color.setStroke(); color.setFill()
        let pole = NSBezierPath(); pole.lineWidth = 1.6; pole.lineCapStyle = .round
        pole.move(to: NSPoint(x: 5, y: 3)); pole.line(to: NSPoint(x: 5, y: 22)); pole.stroke()
        let flag = NSBezierPath(rect: NSRect(x: 5, y: 4, width: 14, height: 10))
        flag.lineWidth = 1.2; flag.stroke()
        for row in 0..<3 {
            for column in 0..<4 where (row + column).isMultiple(of: 2) {
                NSRect(x: 5 + CGFloat(column) * 3.5, y: 4 + CGFloat(row) * 10 / 3, width: 3.5, height: 10 / 3).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// 奖杯使用本地路径，兼容未提供 trophy 系统符号的 macOS 12。
    private static func drawTrophy(in bounds: NSRect, color: NSColor) {
        let rect = fittedRect(size: NSSize(width: 24, height: 26), in: bounds)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 24, yBy: rect.height / 26)
        transform.concat()
        let path = NSBezierPath()
        path.lineWidth = 1.65; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: NSPoint(x: 6, y: 3)); path.line(to: NSPoint(x: 18, y: 3))
        path.line(to: NSPoint(x: 18, y: 10))
        path.curve(to: NSPoint(x: 12, y: 17), controlPoint1: NSPoint(x: 18, y: 14), controlPoint2: NSPoint(x: 16, y: 17))
        path.curve(to: NSPoint(x: 6, y: 10), controlPoint1: NSPoint(x: 8, y: 17), controlPoint2: NSPoint(x: 6, y: 14))
        path.close()
        path.move(to: NSPoint(x: 6, y: 5)); path.line(to: NSPoint(x: 2, y: 5)); path.line(to: NSPoint(x: 2, y: 9))
        path.curve(to: NSPoint(x: 6, y: 13), controlPoint1: NSPoint(x: 2, y: 12), controlPoint2: NSPoint(x: 4, y: 13))
        path.move(to: NSPoint(x: 18, y: 5)); path.line(to: NSPoint(x: 22, y: 5)); path.line(to: NSPoint(x: 22, y: 9))
        path.curve(to: NSPoint(x: 18, y: 13), controlPoint1: NSPoint(x: 22, y: 12), controlPoint2: NSPoint(x: 20, y: 13))
        path.move(to: NSPoint(x: 12, y: 17)); path.line(to: NSPoint(x: 12, y: 21))
        path.move(to: NSPoint(x: 8, y: 21)); path.line(to: NSPoint(x: 16, y: 21))
        path.line(to: NSPoint(x: 18, y: 24)); path.line(to: NSPoint(x: 6, y: 24)); path.close()
        color.setStroke(); path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// 所有成就徽章的唯一入口；正式界面和测试总览使用同一幅游戏主题图案。
enum AchievementIconCatalog {
    private static var cache: [String: NSImage] = [:]

    static func accent(for definition: AchievementDefinition) -> NSColor {
        AchievementBadgeArtwork.accent(for: definition)
    }

    static func image(for definition: AchievementDefinition, muted: Bool = false) -> NSImage {
        let key = "\(definition.id).\(muted)"
        if let cached = cache[key] { return cached }
        let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { _ in
            AchievementBadgeArtwork.draw(definition, muted: muted)
            return true
        }
        image.isTemplate = false
        cache[key] = image
        return image
    }
}
