import Cocoa

/// 大厅的方块与触控栏演示，使用矢量绘制以适应不同窗口和显示倍率。
enum HomeLobbyArtwork {
    static let touchBarCanvasSize = NSSize(width: 925, height: 112)

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
        drawPiece(kind, in: bounds, opacity: 1)
    }

    private static func drawPiece(_ kind: PieceKind, in bounds: NSRect, opacity: CGFloat) {
        guard let image = pieces[kind], bounds.width > 0, bounds.height > 0, opacity > 0 else { return }
        let scale = min(bounds.width / pieceSize.width, bounds.height / pieceSize.height)
        let width = pieceSize.width * scale
        let height = pieceSize.height * scale
        let rect = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity,
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

    static func drawTouchBar(in bounds: NSRect, frame: HomeTouchBarDemo.Frame) {
        let canvas = touchBarCanvasSize
        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
        guard scale > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX - canvas.width * scale / 2, yBy: bounds.minY)
        transform.scale(by: scale)
        transform.concat()

        let rail = HomeDashboardStyle.slant(NSRect(x: 1, y: 1, width: canvas.width - 2, height: 67))
        gradient(rail, from: color(0x040B10), to: color(0x10202A),
                 start: NSPoint(x: 0, y: 0), end: NSPoint(x: 15, y: 68))

        // 裁剪从左侧生成的方块和消除光效，手势的手腕可延伸到轨道之外。
        let cyan = color(0x28E8FA)
        let fingertipX = frame.gesture.map { gesture in
            let column = CGFloat(gesture.from) + CGFloat(gesture.to - gesture.from) * gesture.progress
            return touchBarX(for: column)
        }
        NSGraphicsContext.saveGraphicsState()
        rail.addClip()
        if let gesture = frame.gesture, let fingertipX {
            drawSwipeHint(for: gesture, fingertipX: fingertipX, tint: cyan)
        }
        for tile in frame.tiles {
            let x = touchBarX(for: tile.column)
            let y = 31 - tile.lift
            let rect = NSRect(x: x - 24 * tile.scale, y: y - 17 * tile.scale,
                              width: 48 * tile.scale, height: 34 * tile.scale)
            if tile.highlight > 0, let palette = palettes[tile.kind] {
                let halo = NSRect(x: x - 44, y: y - 32, width: 88, height: 64)
                glow(halo, color: palette.light.withAlphaComponent(0.8 * tile.highlight))
            }
            drawPiece(tile.kind, in: rect, opacity: tile.opacity)
        }
        NSGraphicsContext.restoreGraphicsState()

        color(0xB7D3DA, alpha: 0.7).setStroke()
        rail.lineWidth = 1.2
        rail.stroke()
        if let gesture = frame.gesture, let fingertipX {
            drawHand(at: NSPoint(x: fingertipX, y: 45 + gesture.lift), tint: cyan, opacity: gesture.opacity)
        }
    }

    private static func touchBarX(for column: CGFloat) -> CGFloat {
        80 + column * 65.5
    }

    private static func drawSwipeHint(for gesture: HomeTouchBarDemo.Gesture, fingertipX: CGFloat, tint: NSColor) {
        let direction: CGFloat = gesture.to < gesture.from ? -1 : 1
        let fromX = touchBarX(for: CGFloat(gesture.from))
        let toX = touchBarX(for: CGFloat(gesture.to))
        let midpoint = (fromX + toX) / 2
        let opacity = gesture.opacity
        glow(NSRect(x: midpoint - 80, y: 41, width: 160, height: 50), color: tint.withAlphaComponent(0.4 * opacity))
        glow(NSRect(x: fingertipX - 44, y: 7, width: 88, height: 58), color: color(0x235CFF, alpha: 0.74 * opacity))

        // 箭头跟随滑动方向，依次提亮以预告手指即将移动的路径。
        for index in 0..<3 {
            let x = midpoint + direction * (CGFloat(index - 1) * 15.5 + 8 * (gesture.progress - 0.5))
            let emphasis = 1 - abs(gesture.progress - (CGFloat(index) + 0.5) / 3)
            let chevron = NSBezierPath()
            chevron.move(to: NSPoint(x: x - direction * 4, y: 46))
            chevron.line(to: NSPoint(x: x + direction * 4, y: 53))
            chevron.line(to: NSPoint(x: x - direction * 4, y: 60))
            tint.withAlphaComponent((0.42 + 0.58 * emphasis) * opacity).setStroke()
            chevron.lineWidth = 3
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            chevron.stroke()
        }
        let swipe = NSBezierPath()
        swipe.move(to: NSPoint(x: min(fromX, toX) - 16, y: 65))
        swipe.line(to: NSPoint(x: max(fromX, toX) + 16, y: 65))
        tint.withAlphaComponent(0.63 * opacity).setStroke()
        swipe.lineWidth = 1
        swipe.stroke()
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

    private static func drawHand(at origin: NSPoint, tint: NSColor, opacity: CGFloat) {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x, y: origin.y + y) }
        let hand = NSBezierPath()
        hand.move(to: point(8, 53))
        hand.curve(to: point(2, 46), controlPoint1: point(7, 50), controlPoint2: point(5, 48))
        hand.curve(to: point(-12, 34), controlPoint1: point(-3, 43), controlPoint2: point(-9, 39))
        hand.curve(to: point(-7, 28), controlPoint1: point(-15, 29), controlPoint2: point(-11, 26))
        hand.line(to: point(-4.5, 32))
        // 指尖固定在原点，竖直食指随手势整体平移，始终对准方块列的中心。
        hand.line(to: point(-4.5, 5))
        hand.curve(to: point(0, 0), controlPoint1: point(-4.5, 2), controlPoint2: point(-2.5, 0))
        hand.curve(to: point(4.5, 5), controlPoint1: point(2.5, 0), controlPoint2: point(4.5, 2))
        hand.line(to: point(4.5, 25))
        hand.curve(to: point(13.5, 25), controlPoint1: point(4.5, 19), controlPoint2: point(13.5, 19))
        hand.line(to: point(13.5, 28))
        hand.curve(to: point(22.5, 28), controlPoint1: point(13.5, 22), controlPoint2: point(22.5, 22))
        hand.line(to: point(22.5, 31))
        hand.curve(to: point(31, 31), controlPoint1: point(22.5, 25), controlPoint2: point(30, 26))
        hand.curve(to: point(32, 43), controlPoint1: point(32, 35), controlPoint2: point(33, 39))
        hand.curve(to: point(28, 53), controlPoint1: point(31, 48), controlPoint2: point(28, 49))
        // 底端敞开；填充先封闭内部，白色描边在手腕两侧自然结束。
        color(0x091722, alpha: 0.91 * opacity).setFill()
        hand.fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = tint.withAlphaComponent(0.55 * opacity)
        glow.shadowBlurRadius = 7
        glow.shadowOffset = .zero
        glow.set()
        color(0xEAF9FE, alpha: opacity).setStroke()
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
