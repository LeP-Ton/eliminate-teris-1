import Cocoa

/// 直接使用原始设计稿提取的插画，保留其材质、投影、短线与相对位置。
enum HomeHeroPieceRenderer {
    private struct Sprite {
        let kind: PieceKind?
        let name: String
        /// 原设计稿中的裁切区域，以左上角为原点。
        let crop: NSRect
    }

    private static let reference = NSRect(x: 76, y: 435, width: 875, height: 165)
    private static let sprites: [Sprite] = [
        Sprite(kind: .orangeRicky, name: "home-design-orange", crop: NSRect(x: 76, y: 450, width: 190, height: 150)),
        Sprite(kind: .blueRicky, name: "home-design-blue", crop: NSRect(x: 290, y: 450, width: 167, height: 150)),
        Sprite(kind: .clevelandZ, name: "home-design-green", crop: NSRect(x: 544, y: 435, width: 197, height: 165)),
        Sprite(kind: .rhodeIslandZ, name: "home-design-red", crop: NSRect(x: 744, y: 440, width: 207, height: 160)),
        Sprite(kind: nil, name: "home-design-arrow", crop: NSRect(x: 462, y: 515, width: 75, height: 43))
    ]
    private static let images: [String: NSImage] = {
        guard let bundle = GameResourceLocator.resourceBundle() else { return [:] }
        return Dictionary(uniqueKeysWithValues: sprites.compactMap { sprite in
            guard let url = bundle.url(forResource: sprite.name, withExtension: "png"),
                  let image = NSImage(contentsOf: url) else { return nil }
            return (sprite.name, image)
        })
    }()

    static func draw(in bounds: NSRect, phase: CGFloat, animated: Bool) {
        // 整组插画共用一个缩放比例，方块宽度、彼此间距、箭头与短线位置均来自设计稿。
        let scale = min(bounds.width / reference.width, max(0, bounds.height - 6) / reference.height)
        let origin = NSPoint(x: bounds.midX - reference.width * scale / 2,
                             y: bounds.midY - reference.height * scale / 2)
        for (index, sprite) in sprites.enumerated() {
            let floating = animated && sprite.kind != nil ? sin(phase + CGFloat(index)) * 3 : 0
            let destination = NSRect(x: origin.x + (sprite.crop.minX - reference.minX) * scale,
                                     y: origin.y + (sprite.crop.minY - reference.minY) * scale + floating,
                                     width: sprite.crop.width * scale, height: sprite.crop.height * scale)
            images[sprite.name]?.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1,
                                      respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
        }
    }
}
