import Cocoa

/// 直接提取用户设计稿的像素，只移除纸纹背景；不重绘方块、光影或装饰短线。
/// 用法：swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let source = NSBitmapImageRep(data: try Data(contentsOf: input))!
precondition(source.pixelsWide == 1536 && source.pixelsHigh == 1024, "需要原始 1536×1024 设计稿")
print("沿用原稿色彩空间：\(source.colorSpace.localizedName ?? "RGB")")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func rgb(_ x: Int, _ y: Int) -> [Double] {
    // 直接读取编码通道，避开 NSColor 取色时的隐式转换，确保主体像素不发生二次色彩转换。
    var components = [Int](repeating: 0, count: source.samplesPerPixel)
    source.getPixel(&components, atX: x, y: y)
    return components.prefix(3).map { Double($0) / 255 }
}

/// 四角的纸张颜色取中位数，避免纹理中个别深色像素影响背景估计。
func background(_ x: Int, _ y: Int) -> [Double] {
    let samples = (-3...3).flatMap { dy in (-3...3).map { dx in rgb(x + dx, y + dy) } }
    return (0..<3).map { channel in samples.map { $0[channel] }.sorted()[samples.count / 2] }
}

let crops: [(String, Int, Int, Int, Int)] = [
    ("home-design-orange", 76, 450, 190, 150),
    ("home-design-blue", 290, 450, 167, 150),
    ("home-design-green", 544, 435, 197, 165),
    ("home-design-red", 744, 440, 207, 160),
    ("home-design-arrow", 462, 515, 75, 43)
]

for (name, originX, originY, width, height) in crops {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bitmapFormat: [.alphaNonpremultiplied],
                                  bytesPerRow: width * 4, bitsPerPixel: 32)!
    let corners = [background(originX + 4, originY + 4), background(originX + width - 5, originY + 4),
                   background(originX + 4, originY + height - 5), background(originX + width - 5, originY + height - 5)]
    for y in 0..<height {
        for x in 0..<width {
            let pixel = rgb(originX + x, originY + y)
            let u = Double(x) / Double(width - 1), v = Double(y) / Double(height - 1)
            let paper = (0..<3).map { channel in
                (1 - v) * ((1 - u) * corners[0][channel] + u * corners[1][channel])
                    + v * ((1 - u) * corners[2][channel] + u * corners[3][channel])
            }
            let difference = (0..<3).map { abs(pixel[$0] - paper[$0]) }.max()!
            let alpha: Double
            if difference < 0.027 {
                alpha = 0
            } else if difference >= 0.18 {
                // 方块与短线的主体保持不透明，原始材质像素原样保留。
                alpha = 1
            } else {
                let t = (difference - 0.027) / (0.18 - 0.027)
                let minimum = (0..<3).map { channel -> Double in
                    if pixel[channel] <= paper[channel] { return (paper[channel] - pixel[channel]) / max(paper[channel], 0.001) }
                    return (pixel[channel] - paper[channel]) / max(1 - paper[channel], 0.001)
                }.max()!
                alpha = min(1, max(minimum, t * t * (3 - 2 * t)))
            }
            let offset = y * bitmap.bytesPerRow + x * 4
            for channel in 0..<3 {
                // 反解纸张混色，透明投影贴到首页底色时不会出现白边或矩形纸纹。
                let value = alpha == 0 ? 0 : (pixel[channel] - paper[channel] * (1 - alpha)) / alpha
                bitmap.bitmapData![offset + channel] = UInt8((min(1, max(0, value)) * 255).rounded())
            }
            bitmap.bitmapData![offset + 3] = UInt8((alpha * 255).rounded())
        }
    }
    // 沿用原稿嵌入的色彩空间，避免广色域颜色转为 sRGB 时被裁切或再次转换。
    let png = bitmap.retagging(with: source.colorSpace)!.representation(using: .png, properties: [:])!
    try png.write(to: output.appendingPathComponent(name + ".png"))
    print("已直接提取：\(name)，\(width)×\(height)")
}
