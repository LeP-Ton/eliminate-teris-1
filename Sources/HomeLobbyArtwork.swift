import Cocoa

/// 大厅的方块与触控栏教学图，使用矢量绘制以适应不同窗口和显示倍率。
enum HomeLobbyArtwork {
    private struct PiecePalette {
        let face: NSColor
        let light: NSColor
        let shade: NSColor
    }

    private static let palettes: [PieceKind: PiecePalette] = [
        .orangeRicky: PiecePalette(face: color(0xFF9B0A), light: color(0xFFE5A1), shade: color(0xA44903)),
        .blueRicky: PiecePalette(face: color(0x008CFF), light: color(0x9CF4FF), shade: color(0x024394)),
        .clevelandZ: PiecePalette(face: color(0x00DB64), light: color(0xA1FFC7), shade: color(0x08783A)),
        .rhodeIslandZ: PiecePalette(face: color(0xFF5B4B), light: color(0xFFD0C4), shade: color(0xA92B25))
    ]
    private static let pieceSize = NSSize(width: 138, height: 94)
    private static let pieces: [PieceKind: NSImage] = {
        palettes.reduce(into: [:]) { images, entry in
            let (kind, palette) = entry
            images[kind] = NSImage(size: pieceSize, flipped: true) { _ in
                let pitch: CGFloat = 46
                for block in kind.blocks {
                    let cell = NSRect(x: CGFloat(block.x) * pitch, y: CGFloat(1 - block.y) * pitch,
                                      width: pitch - 0.8, height: pitch + 1.5)
                    drawCell(in: cell, palette: palette)
                }
                return true
            }
        }
    }()

    /// 绘制与大厅插画一致的方块，保持原始长宽比。
    static func drawPiece(_ kind: PieceKind, in bounds: NSRect) {
        guard let image = pieces[kind], bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(bounds.width / pieceSize.width, bounds.height / pieceSize.height)
        let width = pieceSize.width * scale
        let height = pieceSize.height * scale
        let rect = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: nil)
    }

    static func drawHero(in bounds: NSRect, phase: CGFloat, animated: Bool) {
        let canvas = NSSize(width: 920, height: 184)
        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
        guard scale > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX - canvas.width * scale / 2, yBy: bounds.midY - canvas.height * scale / 2)
        transform.scale(by: scale)
        transform.concat()

        // 地面的侧边与大厅卡片共用斜率，插画等比缩放时也保持这个角度。
        let floor = HomeDashboardStyle.slant(NSRect(x: 25, y: 99, width: 892, height: 53))
        gradient(floor, from: .clear, to: color(0x254350, alpha: 0.43),
                 start: NSPoint(x: 36, y: 130), end: NSPoint(x: 890, y: 147))
        let floorEdge = HomeDashboardStyle.slant(NSRect(x: 76, y: 150, width: 813, height: 2))
        gradient(floorEdge, from: color(0x5F9CB2, alpha: 0.14), to: .clear,
                 start: NSPoint(x: 76, y: 151), end: NSPoint(x: 889, y: 151))

        let positions: [(kind: PieceKind, x: CGFloat, streak: NSPoint)] = [
            (.orangeRicky, 80, NSPoint(x: 80, y: 40)),
            (.blueRicky, 271, NSPoint(x: 381, y: 15)),
            (.clevelandZ, 532, NSPoint(x: 666, y: 28)),
            (.rhodeIslandZ, 720, NSPoint(x: 854, y: 32))
        ]
        for (index, position) in positions.enumerated() {
            guard let palette = palettes[position.kind] else { continue }
            drawStreaks(at: position.streak, color: palette.face)
            let floating = animated ? sin(phase + CGFloat(index) * 0.9) * 2.7 : 0
            let rect = NSRect(x: position.x, y: 43 + floating, width: pieceSize.width, height: pieceSize.height)
            let reflectedColor = palette.face.withAlphaComponent(0.29)
            glow(NSRect(x: rect.minX - 43, y: rect.maxY - 38, width: rect.width + 86, height: 86),
                 color: palette.face.withAlphaComponent(0.43))
            glow(NSRect(x: rect.minX - 9, y: rect.maxY - 9, width: rect.width + 18, height: 24),
                 color: color(0x020509, alpha: 0.72))
            drawReflection(of: position.kind, in: rect, color: reflectedColor)
            drawPiece(position.kind, in: rect)
        }
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 447, y: 90))
        arrow.line(to: NSPoint(x: 504, y: 90))
        arrow.move(to: NSPoint(x: 458, y: 79))
        arrow.line(to: NSPoint(x: 447, y: 90))
        arrow.line(to: NSPoint(x: 458, y: 101))
        arrow.move(to: NSPoint(x: 493, y: 79))
        arrow.line(to: NSPoint(x: 504, y: 90))
        arrow.line(to: NSPoint(x: 493, y: 101))
        color(0xF3F8FF, alpha: 0.92).setStroke()
        arrow.lineWidth = 3.5
        arrow.stroke()
    }

    static func drawTouchBar(in bounds: NSRect) {
        let canvas = NSSize(width: 925, height: 112)
        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
        guard scale > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX - canvas.width * scale / 2, yBy: bounds.minY)
        transform.scale(by: scale)
        transform.concat()

        let rail = HomeDashboardStyle.slant(NSRect(x: 1, y: 1, width: 923, height: 67))
        gradient(rail, from: color(0x040B10), to: color(0x10202A),
                 start: NSPoint(x: 0, y: 0), end: NSPoint(x: 15, y: 68))
        color(0xB7D3DA, alpha: 0.7).setStroke()
        rail.lineWidth = 1.2
        rail.stroke()

        let cyan = color(0x28E8FA)
        glow(NSRect(x: 561, y: 37, width: 190, height: 50), color: cyan.withAlphaComponent(0.40))
        glow(NSRect(x: 634, y: 7, width: 88, height: 58), color: color(0x235CFF, alpha: 0.74))
        let kinds: [PieceKind] = [.orangeRicky, .blueRicky, .clevelandZ, .rhodeIslandZ]
        for index in 0..<13 {
            drawPiece(kinds[index % kinds.count], in: NSRect(x: 56 + CGFloat(index) * 65.5, y: 14, width: 48, height: 34))
        }
        for index in 0..<3 {
            let x = 617 + CGFloat(index) * 15.5
            let chevron = NSBezierPath()
            chevron.move(to: NSPoint(x: x, y: 42))
            chevron.line(to: NSPoint(x: x + 8, y: 49))
            chevron.line(to: NSPoint(x: x, y: 56))
            cyan.withAlphaComponent(0.72 + CGFloat(index) * 0.12).setStroke()
            chevron.lineWidth = 3
            chevron.stroke()
        }
        let swipe = NSBezierPath()
        swipe.move(to: NSPoint(x: 585, y: 65))
        swipe.line(to: NSPoint(x: 697, y: 65))
        cyan.withAlphaComponent(0.63).setStroke()
        swipe.lineWidth = 1
        swipe.stroke()
        drawHand(at: NSPoint(x: 671, y: 46), tint: cyan)
    }

    private static func drawCell(in rect: NSRect, palette: PiecePalette) {
        // 底沿与高光分开绘制，缩小到统计和触控栏图示后仍能辨认每一格。
        let bevel = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        gradient(bevel, from: palette.light, to: palette.shade,
                 start: NSPoint(x: rect.midX, y: rect.minY), end: NSPoint(x: rect.midX, y: rect.maxY))
        let face = NSBezierPath(roundedRect: NSRect(x: rect.minX + 2.2, y: rect.minY + 3.2,
                                                   width: rect.width - 5.0, height: rect.height - 8.2),
                                xRadius: 4, yRadius: 4)
        let highlight = palette.face.blended(withFraction: 0.18, of: palette.light) ?? palette.face
        let lowerFace = palette.face.blended(withFraction: 0.16, of: palette.shade) ?? palette.face
        gradient(face, from: highlight, to: lowerFace,
                 start: NSPoint(x: rect.minX, y: rect.minY), end: NSPoint(x: rect.maxX, y: rect.maxY))
        color(0xFFFFFF, alpha: 0.24).setStroke()
        face.lineWidth = 0.8
        face.stroke()
        let shine = NSBezierPath()
        shine.move(to: NSPoint(x: rect.minX + 6.5, y: rect.minY + 1.3))
        shine.line(to: NSPoint(x: rect.maxX - 7, y: rect.minY + 1.3))
        NSColor.white.withAlphaComponent(0.76).setStroke()
        shine.lineCapStyle = .round
        shine.lineWidth = 1.15
        shine.stroke()
    }

    private static func drawStreaks(at point: NSPoint, color: NSColor) {
        for index in 0..<3 {
            let x = point.x + CGFloat(index) * 11.0
            let y = point.y - CGFloat(index) * 3.3
            let path = HomeDashboardStyle.slant(NSRect(x: x - 8, y: y + 4, width: 35, height: 51))
            gradient(path, from: color.withAlphaComponent(0.29 + CGFloat(index) * 0.22), to: color.withAlphaComponent(0),
                     start: NSPoint(x: x + 29, y: y + 5), end: NSPoint(x: x - 8, y: y + 51))
        }
    }

    private static func drawReflection(of kind: PieceKind, in rect: NSRect, color: NSColor) {
        let depth: CGFloat = 25
        let base = rect.maxY + 5
        for block in kind.blocks where block.y == 0 {
            let reflection = NSRect(x: rect.minX + CGFloat(block.x) * 46 + 1, y: base, width: 43, height: depth)
            let path = NSBezierPath(roundedRect: reflection, xRadius: 4, yRadius: 4)
            gradient(path, from: color, to: color.withAlphaComponent(0),
                     start: NSPoint(x: reflection.midX, y: base), end: NSPoint(x: reflection.midX, y: base + depth))
        }
    }

    private static func drawHand(at origin: NSPoint, tint: NSColor) {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x, y: origin.y + y) }
        let hand = NSBezierPath()
        hand.move(to: point(24, 62))
        hand.curve(to: point(17, 55), controlPoint1: point(22, 59), controlPoint2: point(21, 57))
        hand.curve(to: point(5, 40), controlPoint1: point(13, 53), controlPoint2: point(8, 45))
        hand.curve(to: point(10, 33), controlPoint1: point(0, 34), controlPoint2: point(5, 29))
        hand.line(to: point(15, 39))
        hand.line(to: point(6, 9))
        hand.curve(to: point(14, 5), controlPoint1: point(4, 2), controlPoint2: point(12, 0))
        hand.line(to: point(21, 30))
        hand.curve(to: point(29, 27), controlPoint1: point(20, 23), controlPoint2: point(27, 21))
        hand.line(to: point(31, 33))
        hand.curve(to: point(39, 31), controlPoint1: point(30, 26), controlPoint2: point(37, 25))
        hand.line(to: point(41, 36))
        hand.curve(to: point(47, 35), controlPoint1: point(41, 30), controlPoint2: point(45, 30))
        hand.curve(to: point(48, 51), controlPoint1: point(50, 40), controlPoint2: point(50, 46))
        hand.curve(to: point(49, 61), controlPoint1: point(47, 56), controlPoint2: point(48, 59))
        // 底端敞开；填充先封闭内部，白色描边在手腕两侧自然结束。
        color(0x091722, alpha: 0.91).setFill()
        hand.fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = tint.withAlphaComponent(0.55)
        glow.shadowBlurRadius = 7
        glow.shadowOffset = .zero
        glow.set()
        color(0xEAF9FE).setStroke()
        hand.lineWidth = 2.35
        hand.lineCapStyle = .round
        hand.lineJoinStyle = .round
        hand.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func gradient(_ path: NSBezierPath, from: NSColor, to: NSColor, start: NSPoint, end: NSPoint) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(starting: from, ending: to)?
            .draw(from: start, to: end, options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func glow(_ rect: NSRect, color: NSColor) {
        let colors = [color.cgColor, color.withAlphaComponent(color.alphaComponent * 0.28).cgColor,
                      color.withAlphaComponent(0).cgColor]
        guard let context = NSGraphicsContext.current?.cgContext,
              let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 0.55, 1]) else { return }
        // 在单位圆内衰减，再缩放到椭圆，既保持扁平的地面反光，也避免出现可见的椭圆边。
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: rect.width / 2, y: rect.height / 2)
        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
        context.restoreGState()
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
