import Cocoa

/// 直接绘制计算器式七段数字；只在水平方向适配可用宽度，保持数字高度不变。
enum SevenSegmentNumberRenderer {
    // 段位依次为：上、右上、右下、下、左下、左上、中。
    private static let digitMasks = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]
    private static let segments: [NSRect] = [
        NSRect(x: 0.08, y: 0, width: 0.39, height: 0.08),
        NSRect(x: 0.47, y: 0.08, width: 0.08, height: 0.38),
        NSRect(x: 0.47, y: 0.54, width: 0.08, height: 0.38),
        NSRect(x: 0.08, y: 0.92, width: 0.39, height: 0.08),
        NSRect(x: 0, y: 0.54, width: 0.08, height: 0.38),
        NSRect(x: 0, y: 0.08, width: 0.08, height: 0.38),
        NSRect(x: 0.08, y: 0.46, width: 0.39, height: 0.08)
    ]

    static func width(for text: String, height: CGFloat) -> CGFloat {
        let characters = Array(text)
        return height * (characters.reduce(CGFloat(0)) { $0 + glyphWidth($1) } + CGFloat(max(0, characters.count - 1)) * 0.1)
    }

    /// 坐标按顶部向下递增，与顶部统计卡片的翻转坐标保持一致。
    static func draw(_ text: String, in rect: NSRect, color: NSColor) {
        guard rect.width > 0, rect.height > 0, !text.isEmpty else { return }
        let scaleX = min(1, rect.width / max(1, width(for: text, height: rect.height)))
        let unitX = rect.height * scaleX
        var x = rect.minX
        for character in text {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                for (index, segment) in segments.enumerated() {
                    let target = NSRect(x: x + segment.minX * unitX, y: rect.minY + segment.minY * rect.height,
                                        width: segment.width * unitX, height: segment.height * rect.height)
                    let active = digitMasks[digit] & (1 << index) != 0
                    (active ? color : color.withAlphaComponent(0.1)).setFill()
                    beveledSegment(in: target, horizontal: index == 0 || index == 3 || index == 6).fill()
                }
            } else if character == "," || character == "." {
                // 本地化分组符也采用小数码段，保留完整数量而不改成缩写。
                color.setFill()
                NSBezierPath(rect: NSRect(x: x + unitX * 0.04, y: rect.minY + rect.height * 0.88,
                                          width: unitX * 0.08, height: rect.height * 0.08)).fill()
                if character == "," {
                    NSBezierPath(rect: NSRect(x: x + unitX * 0.02, y: rect.minY + rect.height * 0.96,
                                              width: unitX * 0.04, height: rect.height * 0.04)).fill()
                }
            }
            // 俄语等语言的空白分组符保留间距，不绘制额外内容。
            x += unitX * (glyphWidth(character) + 0.1)
        }
    }

    private static func glyphWidth(_ character: Character) -> CGFloat {
        character.wholeNumberValue != nil ? 0.55 : 0.16
    }

    private static func beveledSegment(in rect: NSRect, horizontal: Bool) -> NSBezierPath {
        let cap = horizontal ? min(rect.height / 2, rect.width / 2) : min(rect.width / 2, rect.height / 2)
        let points: [NSPoint]
        if horizontal {
            points = [NSPoint(x: rect.minX, y: rect.midY), NSPoint(x: rect.minX + cap, y: rect.minY),
                      NSPoint(x: rect.maxX - cap, y: rect.minY), NSPoint(x: rect.maxX, y: rect.midY),
                      NSPoint(x: rect.maxX - cap, y: rect.maxY), NSPoint(x: rect.minX + cap, y: rect.maxY)]
        } else {
            points = [NSPoint(x: rect.midX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY + cap),
                      NSPoint(x: rect.maxX, y: rect.maxY - cap), NSPoint(x: rect.midX, y: rect.maxY),
                      NSPoint(x: rect.minX, y: rect.maxY - cap), NSPoint(x: rect.minX, y: rect.minY + cap)]
        }
        let path = NSBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }
        path.close()
        return path
    }
}
