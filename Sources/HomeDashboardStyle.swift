import Cocoa

/// 大厅以深蓝底、青色状态和黄色主操作组织视觉层级。
enum HomeDashboardStyle {
    static let navy = color(0x0B1520)
    static let ink = color(0xF4F7FC)
    static let muted = color(0xB6C4D2)
    static let cyan = color(0x20EDF5)
    static let yellow = color(0xFFF044)
    static let green = color(0x59EF86)
    static let border = color(0x526779)
    static let panel = color(0x172636)
    // 以每点垂直距离对应的水平偏移定义斜边，组件尺寸变化时角度保持一致。
    static let slope: CGFloat = 0.45
    static let letterSlant: CGFloat = 0.19

    static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }

    static func edgeOffset(for height: CGFloat) -> CGFloat { max(0, height) * slope }

    private static func corners(of rect: NSRect, reverse: Bool = false) -> [NSPoint] {
        let inset = edgeOffset(for: rect.height)
        guard rect.height > 0, rect.width > inset else { return [] }
        let top = reverse ? 0 : inset
        let bottom = reverse ? inset : 0
        return [
            NSPoint(x: rect.minX + top, y: rect.minY), NSPoint(x: rect.maxX - bottom, y: rect.minY),
            NSPoint(x: rect.maxX - top, y: rect.maxY), NSPoint(x: rect.minX + bottom, y: rect.maxY),
        ]
    }

    static func slant(_ rect: NSRect, reverse: Bool = false) -> NSBezierPath {
        let path = NSBezierPath()
        let vertices = corners(of: rect, reverse: reverse)
        guard let first = vertices.first else { return path }
        path.move(to: first)
        for point in vertices.dropFirst() { path.line(to: point) }
        path.close()
        return path
    }

    static func cgSlant(_ rect: NSRect) -> CGPath {
        let path = CGMutablePath()
        let vertices = corners(of: rect)
        guard !vertices.isEmpty else { return path }
        path.addLines(between: vertices)
        path.closeSubpath()
        return path
    }

    /// 进度按平行四边形的净宽计算，任意完成度下填充末端都与轨道斜边平行。
    static func segmentFill(_ rect: NSRect, fraction: CGFloat) -> NSBezierPath {
        let inset = edgeOffset(for: rect.height)
        guard fraction > 0, rect.width > inset else { return NSBezierPath() }
        let width = inset + (rect.width - inset) * min(1, fraction)
        return slant(NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
    }

    static func surface(_ rect: NSRect, colors: [NSColor], border: NSColor, lineWidth: CGFloat = 1) {
        guard rect.width > lineWidth, rect.height > lineWidth else { return }
        let face = slant(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        guard !face.isEmpty else { return }
        NSGradient(colors: colors)?.draw(in: face, angle: 20)
        border.setStroke()
        face.lineWidth = lineWidth
        face.stroke()
    }

    static func line(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat = 1) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    static func diagonal(from top: NSPoint, height: CGFloat, color: NSColor, width: CGFloat = 1) {
        line(from: top, to: NSPoint(x: top.x - edgeOffset(for: height), y: top.y + height), color: color, width: width)
    }

    static func textAttributes(font: NSFont, color: NSColor = ink) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color, .obliqueness: letterSlant]
    }

    static func text(_ value: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
                     color: NSColor = ink, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes = textAttributes(font: .systemFont(ofSize: size, weight: weight), color: color)
        attributes[.paragraphStyle] = paragraph
        (value as NSString).draw(in: rect, withAttributes: attributes)
    }

    static func description(_ value: String, in rect: NSRect, preferred: CGFloat) {
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        var size = max(9, preferred)
        let text = value as NSString
        let constraint = NSSize(width: max(1, rect.width), height: .greatestFiniteMagnitude)
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: muted, .paragraphStyle: paragraph, .obliqueness: letterSlant]
        while true {
            attributes[.font] = NSFont.systemFont(ofSize: size)
            if size <= 9 || ceil(text.boundingRect(with: constraint, options: options, attributes: attributes).height) <= rect.height {
                break
            }
            size = max(9, size - 1)
        }
        text.draw(with: rect, options: options.union(.truncatesLastVisibleLine), attributes: attributes)
    }

    static func mark(in rect: NSRect, color: NSColor = cyan) {
        color.setFill()
        slant(rect).fill()
    }

    static func backdrop(in rect: NSRect) {
        NSGradient(colors: [color(0x090F16), navy, color(0x080E16)])?.draw(in: rect, angle: 21)
        if let context = NSGraphicsContext.current?.cgContext, rect.width > 0, rect.height > 0 {
            let blue = color(0x2A5B71)
            let colors = [blue.withAlphaComponent(0.26).cgColor, blue.withAlphaComponent(0).cgColor]
            if let light = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: colors as CFArray, locations: [0, 1]) {
                context.saveGState()
                context.translateBy(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.52)
                context.scaleBy(x: rect.width * 0.45, y: rect.height * 0.44)
                context.drawRadialGradient(light, startCenter: .zero, startRadius: 0,
                                           endCenter: .zero, endRadius: 1, options: [])
                context.restoreGState()
            }
        }
        // 斜纹沿整个窗口铺开，右栏按同一坐标重绘以遮住入场中的统计卡。
        let bands: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.20, 0.0, 0.27, 0.10), (-0.03, -0.04, 0.10, 0.15),
            (0.21, 0, 0.065, 0.12), (0.43, -0.02, 0.037, 0.08),
            (0.62, 0, 0.061, 0.13), (0.98, 0.13, 0.12, 0.14),
        ]
        for (x, y, width, alpha) in bands {
            let band = NSRect(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y,
                              width: rect.width * width + edgeOffset(for: rect.height), height: rect.height)
            NSGradient(colors: [color(0x355474).withAlphaComponent(alpha),
                                color(0x355474).withAlphaComponent(alpha * 0.19)])?
                .draw(in: slant(band), angle: 73)
        }
    }
}
