import Cocoa

/// 成就专用的彩色游戏图案，使用透明背景，不绘制外框或底板。
/// 所有几何以 48 点画布绘制，不依赖系统功能图标或玩家解锁状态。
enum AchievementBadgeArtwork {
    static func accent(for definition: AchievementDefinition) -> NSColor {
        if case .pieceCleared(let kind, _) = definition.goal { return kind.color }
        switch definition.id {
        case 1, 10, 12, 17, 20: return NSColor(calibratedRed: 0.91, green: 0.57, blue: 0.12, alpha: 1)
        case 2, 6, 8, 19: return NSColor(calibratedRed: 0.55, green: 0.39, blue: 0.83, alpha: 1)
        case 3, 7, 9, 14: return NSColor(calibratedRed: 0.12, green: 0.62, blue: 0.46, alpha: 1)
        case 4, 11, 15: return NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.28, alpha: 1)
        default: return NSColor(calibratedRed: 0.19, green: 0.50, blue: 0.84, alpha: 1)
        }
    }

    static func draw(_ definition: AchievementDefinition, muted: Bool) {
        Painter(base: accent(for: definition), muted: muted).draw(definition)
    }

    private struct Painter {
        let base: NSColor
        let muted: Bool
        private let gold = NSColor(calibratedRed: 1, green: 0.73, blue: 0.13, alpha: 1)
        private let coral = NSColor(calibratedRed: 0.98, green: 0.33, blue: 0.28, alpha: 1)
        private let blue = NSColor(calibratedRed: 0.12, green: 0.57, blue: 0.95, alpha: 1)
        private let teal = NSColor(calibratedRed: 0.13, green: 0.76, blue: 0.60, alpha: 1)
        private let ink = NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.33, alpha: 1)

        private func tone(_ color: NSColor) -> NSColor {
            guard muted, let rgb = color.usingColorSpace(.deviceRGB) else { return color }
            let level = 0.34 + (rgb.redComponent * 0.21 + rgb.greenComponent * 0.72 + rgb.blueComponent * 0.07) * 0.55
            return NSColor(calibratedWhite: level, alpha: rgb.alphaComponent)
        }

        private func mix(_ color: NSColor, _ other: NSColor, _ fraction: CGFloat) -> NSColor {
            color.blended(withFraction: fraction, of: other) ?? color
        }

        private func fill(_ path: NSBezierPath, _ color: NSColor, shaded: Bool = true) {
            let color = tone(color)
            if shaded {
                NSGradient(colors: [mix(color, .white, 0.30), color, mix(color, .black, 0.16)])?.draw(in: path, angle: -90)
            } else { color.setFill(); path.fill() }
        }

        private func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat = 1.5) {
            tone(color).setStroke(); path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
        }

        private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: NSColor, radius: CGFloat = 1.5) {
            fill(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius), color)
        }

        private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: NSColor) {
            fill(NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), color)
        }

        private func polygon(_ points: [NSPoint]) -> NSBezierPath {
            let path = NSBezierPath(); path.move(to: points[0])
            points.dropFirst().forEach { path.line(to: $0) }; path.close(); return path
        }

        private func star(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, color: NSColor) {
            let points = (0..<10).map { index -> NSPoint in
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let length = index.isMultiple(of: 2) ? radius : radius * 0.46
                return NSPoint(x: x + cos(angle) * length, y: y + sin(angle) * length)
            }
            fill(polygon(points), color)
        }

        func draw(_ definition: AchievementDefinition) {
            // 去掉外围装饰后将主体略微放大，保留适当留白，避免标签中的图案显得过小。
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let transform = NSAffineTransform()
            transform.translateX(by: 24, yBy: 24)
            transform.scale(by: 1.12)
            transform.translateX(by: -24, yBy: -24)
            transform.concat()

            if case .pieceCleared(let kind, let count) = definition.goal {
                piece(kind, count: count)
            } else {
                switch definition.id {
                case 1: joystick()
                case 2: rhythm()
                case 3: flag(checkered: false)
                case 4: fingertipSpark()
                case 5: line(count: 4)
                case 6: line(count: 5)
                case 7: cascade(count: 2)
                case 8: cascade(count: 3)
                case 9: steppingTrail()
                case 10: trophy()
                case 11: flame()
                case 12: crown()
                case 13: flag(checkered: true)
                case 14: speed()
                case 15: rocket()
                case 16: clock()
                case 17: collection(level: 1)
                case 18: collection(level: 2)
                case 19: collection(level: 3)
                default: challengePasses()
                }
            }
        }

        private func joystick() {
            rect(11, 29, 26, 7, blue, radius: 3)
            rect(22.5, 18, 3, 12, ink)
            circle(24, 16, 6, coral); circle(22.5, 14, 1.5, .white.withAlphaComponent(0.6))
            rect(15, 30.5, 5, 2, gold); rect(28, 30.5, 5, 2, teal)
        }

        private func rhythm() {
            for (x, y, color) in [(CGFloat(13), CGFloat(23), blue), (CGFloat(21), CGFloat(14), base), (CGFloat(29), CGFloat(19), coral)] {
                rect(x, y, 6, 33 - y, color, radius: 2)
                rect(x + 1, y + 1, 4, 1.5, .white.withAlphaComponent(0.65), radius: 0.5)
            }
            star(35, 12, radius: 3.1, color: gold)
            for x: CGFloat in [16, 24, 32] { circle(x, 36, 1.4, base) }
        }

        private func flag(checkered: Bool) {
            let pole = NSBezierPath(); pole.move(to: NSPoint(x: 15, y: 11)); pole.line(to: NSPoint(x: 15, y: 35)); stroke(pole, ink, width: 2)
            let cloth = polygon([NSPoint(x: 16, y: 12), NSPoint(x: 35, y: 13), NSPoint(x: 32, y: 24), NSPoint(x: 16, y: 23)])
            fill(cloth, checkered ? .white : teal)
            if checkered {
                NSGraphicsContext.saveGraphicsState(); cloth.addClip()
                for row in 0..<3 { for column in 0..<5 where (row + column).isMultiple(of: 2) { rect(16 + CGFloat(column) * 4, 12 + CGFloat(row) * 4, 4, 4, ink, radius: 0) } }
                NSGraphicsContext.restoreGraphicsState()
            } else { star(25, 18, radius: 3, color: gold) }
            rect(11, 34, 10, 3, gold)
        }

        private func fingertipSpark() {
            // 指尖触碰方块，短促的金色火花强调“首次交换触发消除”。
            rect(27, 12, 10, 10, blue, radius: 2)
            rect(28.5, 13.5, 7, 1.3, .white.withAlphaComponent(0.65), radius: 0.5)
            let hand = NSBezierPath()
            hand.move(to: NSPoint(x: 18, y: 35)); hand.line(to: NSPoint(x: 12, y: 26))
            hand.curve(to: NSPoint(x: 16, y: 23), controlPoint1: NSPoint(x: 9, y: 22), controlPoint2: NSPoint(x: 13, y: 20))
            hand.line(to: NSPoint(x: 19, y: 26)); hand.line(to: NSPoint(x: 19, y: 16))
            hand.curve(to: NSPoint(x: 24, y: 16), controlPoint1: NSPoint(x: 19, y: 12), controlPoint2: NSPoint(x: 24, y: 12))
            hand.line(to: NSPoint(x: 24, y: 23))
            hand.curve(to: NSPoint(x: 33, y: 25), controlPoint1: NSPoint(x: 27, y: 21), controlPoint2: NSPoint(x: 31, y: 21))
            hand.line(to: NSPoint(x: 33, y: 31)); hand.line(to: NSPoint(x: 29, y: 36)); hand.close()
            let peach = NSColor(calibratedRed: 1, green: 0.73, blue: 0.48, alpha: 1)
            fill(hand, peach); stroke(hand, mix(peach, coral, 0.35), width: 0.65)
            rect(17, 34, 14, 5.5, teal, radius: 1.5)
            star(21.5, 9, radius: 4.8, color: gold)
            let rays = NSBezierPath()
            rays.move(to: NSPoint(x: 12, y: 13)); rays.line(to: NSPoint(x: 9, y: 11))
            rays.move(to: NSPoint(x: 30, y: 7)); rays.line(to: NSPoint(x: 32, y: 5))
            stroke(rays, coral, width: 1.7)
        }

        private func line(count: Int) {
            let size: CGFloat = count == 4 ? 6.6 : 5.6
            let start = 24 - CGFloat(count) * (size + 0.7) / 2
            for index in 0..<count { rect(start + CGFloat(index) * (size + 0.7), 23, size, 9, [blue, teal, gold, coral, base][index]) }
            star(24, 15, radius: count == 4 ? 4 : 6, color: gold)
        }

        private func cascade(count: Int) {
            // 只保留方块；按两行或三行的实际高度定位，使透明图案垂直居中。
            let top = 24 - (CGFloat(count - 1) * 8 + 6) / 2
            for row in 0..<count {
                for column in 0..<3 { rect(11.75 + CGFloat(column) * 8 + CGFloat(row % 2) * 2, top + CGFloat(row) * 8, 6.5, 6, [blue, teal, gold][row]) }
            }
        }

        private func steppingTrail() {
            // 只保留两枚脚印，并将它们组成的图案重新居中。
            for (x, y, color) in [(CGFloat(17.75), CGFloat(26.75), blue), (CGFloat(30.75), CGFloat(17.75), teal)] {
                NSGraphicsContext.saveGraphicsState()
                let tilt = NSAffineTransform(); tilt.translateX(by: x, yBy: y); tilt.rotate(byDegrees: 22); tilt.concat()
                fill(NSBezierPath(roundedRect: NSRect(x: -3.6, y: -7, width: 7.2, height: 11), xRadius: 3.6, yRadius: 3.6), color)
                rect(-2.8, 6, 5.6, 4, color, radius: 1.5)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        private func trophy() {
            let cup = NSBezierPath(); cup.move(to: NSPoint(x: 16, y: 12)); cup.line(to: NSPoint(x: 32, y: 12)); cup.line(to: NSPoint(x: 30, y: 24))
            cup.curve(to: NSPoint(x: 18, y: 24), controlPoint1: NSPoint(x: 27, y: 30), controlPoint2: NSPoint(x: 21, y: 30)); cup.close()
            let handles = NSBezierPath(); handles.appendOval(in: NSRect(x: 11, y: 13, width: 9, height: 11)); handles.appendOval(in: NSRect(x: 28, y: 13, width: 9, height: 11)); stroke(handles, gold, width: 2.3)
            fill(cup, gold); rect(22, 26, 4, 7, gold); rect(16, 33, 16, 3, base)
            star(24, 20, radius: 3.8, color: .white)
        }

        private func flame() {
            let fire = NSBezierPath(); fire.move(to: NSPoint(x: 24, y: 8))
            fire.curve(to: NSPoint(x: 31, y: 19), controlPoint1: NSPoint(x: 25, y: 15), controlPoint2: NSPoint(x: 30, y: 12))
            fire.curve(to: NSPoint(x: 24, y: 36), controlPoint1: NSPoint(x: 43, y: 32), controlPoint2: NSPoint(x: 31, y: 37))
            fire.curve(to: NSPoint(x: 16, y: 18), controlPoint1: NSPoint(x: 10, y: 38), controlPoint2: NSPoint(x: 10, y: 27))
            fire.curve(to: NSPoint(x: 24, y: 8), controlPoint1: NSPoint(x: 15, y: 24), controlPoint2: NSPoint(x: 24, y: 18)); fire.close(); fill(fire, coral)
            fill(polygon([NSPoint(x: 23, y: 20), NSPoint(x: 30, y: 30), NSPoint(x: 24, y: 35), NSPoint(x: 18, y: 30)]), gold)
        }

        private func crown() {
            fill(polygon([NSPoint(x: 11, y: 17), NSPoint(x: 19, y: 23), NSPoint(x: 24, y: 11), NSPoint(x: 29, y: 23), NSPoint(x: 37, y: 17), NSPoint(x: 33, y: 33), NSPoint(x: 15, y: 33)]), gold)
            rect(15, 32, 18, 4, base); circle(24, 27, 2.5, coral)
            for x: CGFloat in [11, 24, 37] { circle(x, x == 24 ? 11 : 17, 1.8, gold) }
        }

        private func speed() {
            for index in 0..<2 {
                let x = CGFloat(index) * 11
                fill(polygon([NSPoint(x: 15 + x, y: 13), NSPoint(x: 24 + x, y: 24), NSPoint(x: 15 + x, y: 35), NSPoint(x: 10 + x, y: 35), NSPoint(x: 19 + x, y: 24), NSPoint(x: 10 + x, y: 13)]), index == 0 ? teal : blue)
            }
        }

        private func rocket() {
            NSGraphicsContext.saveGraphicsState()
            let tilt = NSAffineTransform(); tilt.translateX(by: 24, yBy: 23); tilt.rotate(byDegrees: 25); tilt.translateX(by: -24, yBy: -23); tilt.concat()
            fill(polygon([NSPoint(x: 20, y: 31), NSPoint(x: 24, y: 40), NSPoint(x: 28, y: 31)]), gold)
            fill(polygon([NSPoint(x: 18, y: 24), NSPoint(x: 13, y: 34), NSPoint(x: 21, y: 31), NSPoint(x: 27, y: 31), NSPoint(x: 35, y: 34), NSPoint(x: 30, y: 24)]), coral)
            fill(NSBezierPath(ovalIn: NSRect(x: 18, y: 8, width: 12, height: 25)), .white); circle(24, 20, 4, blue)
            NSGraphicsContext.restoreGraphicsState()
        }

        private func clock() {
            rect(21, 8, 6, 4, base); circle(24, 24, 12, gold); circle(24, 24, 9.4, .white)
            let hand = NSBezierPath(); hand.move(to: NSPoint(x: 24, y: 17)); hand.line(to: NSPoint(x: 24, y: 24)); hand.line(to: NSPoint(x: 29, y: 27)); stroke(hand, base, width: 2)
            circle(24, 24, 1.7, coral)
        }

        private func collection(level: Int) {
            let colors = [blue, teal, coral]
            // 三档分别保留两、三、四层，随层数缩小单格，使整体尺寸和视觉面积接近。
            let cell: CGFloat = [12, 8.5, 6.3][level - 1]
            let gap: CGFloat = [1, 0.8, 0.7][level - 1]
            let rows = level + 1
            let extent = CGFloat(rows) * cell + CGFloat(rows - 1) * gap
            let top = 24 - extent / 2
            // 仅保留方块，横纵都以主体的实际边界居中。
            let centerX: CGFloat = 24
            for row in 0..<rows {
                let count = row + 1
                let width = CGFloat(count) * cell + CGFloat(count - 1) * gap
                for column in 0..<count {
                    rect(centerX - width / 2 + CGFloat(column) * (cell + gap), top + CGFloat(row) * (cell + gap),
                         cell, cell, colors[row % 3])
                }
            }
        }

        private func challengePasses() {
            // 叠放的街机挑战票券表现多次参赛，不再把累计次数直接画成图标。
            for (index, color) in [blue, teal, gold].enumerated() {
                NSGraphicsContext.saveGraphicsState()
                let tilt = NSAffineTransform(); tilt.translateX(by: 24, yBy: 24)
                tilt.rotate(byDegrees: CGFloat(index - 1) * 13); tilt.translateX(by: -24, yBy: -24); tilt.concat()
                let y = 11 + CGFloat(index) * 6
                let ticket = NSBezierPath()
                ticket.move(to: NSPoint(x: 12, y: y)); ticket.line(to: NSPoint(x: 36, y: y))
                ticket.line(to: NSPoint(x: 36, y: y + 4))
                ticket.curve(to: NSPoint(x: 36, y: y + 10), controlPoint1: NSPoint(x: 31, y: y + 4), controlPoint2: NSPoint(x: 31, y: y + 10))
                ticket.line(to: NSPoint(x: 36, y: y + 14)); ticket.line(to: NSPoint(x: 12, y: y + 14))
                ticket.line(to: NSPoint(x: 12, y: y + 10))
                ticket.curve(to: NSPoint(x: 12, y: y + 4), controlPoint1: NSPoint(x: 17, y: y + 10), controlPoint2: NSPoint(x: 17, y: y + 4))
                ticket.close(); fill(ticket, color)
                if index == 2 {
                    star(23, y + 7, radius: 4, color: coral)
                    for dot in 0..<4 { circle(30, y + 2 + CGFloat(dot) * 3.3, 0.65, .white) }
                }
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        private func piece(_ kind: PieceKind, count: Int) {
            for block in kind.blocks { rect(13 + CGFloat(block.x) * 7.5, 12 + CGFloat(1 - block.y) * 7.5, 7, 7, kind.color) }
            let tier = count == 100 ? 1 : count == 1_000 ? 2 : 3
            for index in 0..<tier { star(24 - CGFloat(tier - 1) * 4.4 + CGFloat(index) * 8.8, 35, radius: 3.1, color: gold) }
        }
    }
}
