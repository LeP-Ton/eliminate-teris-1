# 首页主插画替换为柔光立体资源

## 背景与目标
- 对应会话：会话-59 起；分支：`experiment/ui-refactor`。
- 用户对上一轮“平面正面 + 偏移侧边”的效果仍不满意，指出与设计图的 3D 质感差距明显。
- 本轮替换主插画实现方式：使用按参考图生成的透明立体资源，表现圆润体积、自然高光、接触阴影和落地投影。
- 文档基线为本轮开始的工作区快照；前两轮 UI 与程序材质变更文档均保留原样。

## 设计与实现
- 使用内置 imagegen 工具与 imagegen 技能生成一张四象限图集，参考最初首页设计和待替换的效果图；最终提示词完整保存在资源目录 README 中。
- 图集 1254×1254 像素，RGBA 透明背景；左上橙色、右上蓝色、左下绿色、右下红色，每种形状恰好包含四个立方体。
- `HomeHeroPieceRenderer` 删除原程序渐变、侧边叠层和颗粒绘制，改为从应用资源 Bundle 读取 PNG，在内存中分成四张图片并缓存。
- 缩放使用每张图片的实际实体边界，保留透明留白、柔和投影与原始透视；使用高质量插值，兼容 AppKit 的 NSNumber 参数桥接。
- 四种方块仍随已有相位独立浮动；箭头、装饰短线和小尺寸统计图标保持原生绘制。
- 将原私有本地化资源定位器改名为共用 `GameResourceLocator`，沿用现有 SwiftPM、测试宿主、手工 .app 多路径逻辑，同时加载语言表和图片。
- 资源随应用离线分发，不依赖生成工具的本机路径或运行时网络。加载失败时可回退为正确形状；自动化测试确保正常构建的资源完整。
- 模式规则、本局统计、累计成就、排行榜、Touch Bar 展示与绘制不参与本轮变更。

## 资源留痕
- 资源：`Sources/Resources/Artwork/home-pieces-studio-v1.png`。
- 生成方式：内置 imagegen，透明背景，参考图作为风格与反例输入；未使用 CLI/API fallback。
- 提示词：`Sources/Resources/Artwork/README.md` 的“原始生成提示词”。
- 新增二进制大小：851059 字节。
- SHA-256：`662099e0badf8b4e09a110a8935c8abea4eae905e38916d57a781b452be20b8a`。
- 图集原始输出保留在生成工具目录，应用只使用仓库中的副本。

## 阶段与 TODO
- [x] 重新确认圆角体积和柔光材质要求，替换上一轮实现方式。
- [x] 生成并检查透明图集，核对四种颜色、形状与方向。
- [x] 完成本地资源加载、实体边界缩放、内存裁切缓存和首页接入。
- [x] 验证资源打包路径、透明通道和每种形状的四格轮廓。
- [x] 人工查看真实 AppKit 首页预览并运行完整回归。
- [x] 更新项目认知、根索引与本轮完整增量 diff。

## 测试方法与结果

### TC-001 资源打包、透明和轮廓
- 执行新增测试 `testBundledHeroArtworkHasTransparencyAndFourCorrectSilhouettes`。
- 从实际资源 Bundle 读取图片，验证 1254×1254 和透明通道、四角与象限留白透明。
- 对四个形状的两行三列正面中心采样，以实体透明度与饱和度判断有无方块；与 `PieceKind.blocks` 比对，共 24 个采样位置。
- 结果：通过，未出现多格、缺格、左右镜像或上下翻转。

### TC-002 首页渲染与交互
- 现有布局回归覆盖三种模式、五种语言、960×720、1180×800、1440×940 三种尺寸。
- 生成实际 AppKit 首页 PNG，人工核对四种图片的朝向、大小、光照、透明边缘、投影及箭头和短线位置。
- 开始、模式切换、本局清零、固定结束标准及辅助面板回归通过。

### TC-003 全部回归
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests`：6 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：46 项通过，0 失败；最终完成于 2026-10-30 08:52:57。
- 五语言与本地化格式、成就/存档兼容、棋盘控制、窗口定位等均通过。
- `git diff --check`：通过。
- 预览副本：`/tmp/eliminate-home-studio-3d-preview.png`。截图使用测试存档，不修改玩家实际进度。
- 未重启用户正在运行的游戏；可执行 `./run.sh` 检查实际窗口中的独立浮动。

## 代码变更

以下逐行 diff 记录本轮全部文本文件变更；二进制图片按新增文件记录并以上述 SHA-256 校验。

### `Sources/HomeHeroPieceRenderer.swift`

```diff
--- a/Sources/HomeHeroPieceRenderer.swift
+++ b/Sources/HomeHeroPieceRenderer.swift
@@ -1,119 +1,50 @@
 import Cocoa
 
-/// 首页插画专用的立体材质；以原有方块几何绘制，细小统计图标继续使用简化样式。
+/// 首页主插画使用离线生成的立体资源，运行时只加载本地图片，不依赖网络或三维渲染环境。
 enum HomeHeroPieceRenderer {
-    private static let cell: CGFloat = 36
-    private static let face = NSRect(x: 18, y: 16, width: 108, height: 72)
-    private static let canvas = NSSize(width: 154, height: 116)
-
-    // 固定光照来自左上方，使用明确色值避免系统强调色改变插画材质。
-    private static func color(for kind: PieceKind) -> NSColor {
-        switch kind {
-        case .orangeRicky: return NSColor(calibratedRed: 1, green: 0.61, blue: 0, alpha: 1)
-        case .blueRicky: return NSColor(calibratedRed: 0, green: 0.49, blue: 1, alpha: 1)
-        case .clevelandZ: return NSColor(calibratedRed: 0, green: 0.81, blue: 0.23, alpha: 1)
-        case .rhodeIslandZ: return NSColor(calibratedRed: 1, green: 0.23, blue: 0.20, alpha: 1)
-        }
+    private struct Sprite {
+        let image: NSImage
+        /// 四分图内实体的像素边界，不含周围透明留白和柔和投影。
+        let body: NSRect
     }
 
-    /// 缓存静态材质，浮动动画只移动成品，避免每帧重复计算阴影和细腻纹理。
-    private static let images: [PieceKind: NSImage] = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { kind in
-        let image = NSImage(size: canvas, flipped: true) { _ in
-            guard let context = NSGraphicsContext.current?.cgContext else { return false }
-            paint(kind, context: context)
-            return true
+    private static let sprites: [PieceKind: Sprite] = loadSprites()
+
+    private static func loadSprites() -> [PieceKind: Sprite] {
+        guard let url = GameResourceLocator.resourceBundle()?.url(forResource: "home-pieces-studio-v1", withExtension: "png"),
+              let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data),
+              let atlas = bitmap.cgImage else { return [:] }
+
+        let half = CGFloat(atlas.width) / 2
+        // 图集固定为 1254×1254，四种形状的前景边界经过透明度和颜色检查。
+        let definitions: [(PieceKind, Int, Int, NSRect)] = [
+            (.orangeRicky, 0, 0, NSRect(x: 80, y: 196, width: 496, height: 359)),
+            (.blueRicky, 1, 0, NSRect(x: 83, y: 201, width: 474, height: 366)),
+            (.clevelandZ, 0, 1, NSRect(x: 77, y: 102, width: 497, height: 360)),
+            (.rhodeIslandZ, 1, 1, NSRect(x: 65, y: 113, width: 496, height: 347))
+        ]
+        var result: [PieceKind: Sprite] = [:]
+        for (kind, column, row, body) in definitions {
+            // CGImage 裁切采用图像左上坐标；每张子图保留完整透明边缘与投影。
+            let crop = NSRect(x: CGFloat(column) * half, y: CGFloat(row) * half, width: half, height: half)
+            guard let pixels = atlas.cropping(to: crop) else { continue }
+            result[kind] = Sprite(image: NSImage(cgImage: pixels, size: crop.size), body: body)
         }
-        return (kind, image)
-    })
+        return result
+    }
 
     static func draw(_ kind: PieceKind, in rect: NSRect) {
-        let scale = min(rect.width / face.width, rect.height / face.height)
-        let destination = NSRect(x: rect.midX - face.width * scale / 2 - face.minX * scale,
-                                 y: rect.midY - face.height * scale / 2 - face.minY * scale,
-                                 width: canvas.width * scale, height: canvas.height * scale)
-        images[kind]?.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
-    }
-
-    private static func paint(_ kind: PieceKind, context: CGContext) {
-        let base = color(for: kind)
-        let tiles = kind.blocks.map { block in
-            NSRect(x: face.minX + CGFloat(block.x) * cell, y: face.minY + CGFloat(1 - block.y) * cell,
-                   width: cell - 0.6, height: cell - 0.6)
+        guard let sprite = sprites[kind] else {
+            // 资源缺失时仍展示正确的方块形状，开发回归会检查资源是否被完整打包。
+            HomeStyle.piece(kind, in: rect)
+            return
         }
-        let silhouette = CGMutablePath()
-        for tile in tiles { silhouette.addRoundedRect(in: tile, cornerWidth: 3, cornerHeight: 3) }
-
-        // 脚下的柔和色影表现与地面的距离，整体轮廓投影补足右侧厚度。
-        context.saveGState()
-        context.translateBy(x: face.midX + 7, y: face.maxY + 8)
-        context.scaleBy(x: 1, y: 0.18)
-        if let ground = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
-                                   colors: [mix(base, .black, 0.35).withAlphaComponent(0.13).cgColor,
-                                            base.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
-            context.drawRadialGradient(ground, startCenter: .zero, startRadius: 0, endCenter: .zero,
-                                       endRadius: face.width * 0.56, options: [])
-        }
-        context.restoreGState()
-
-        // CGContext 的阴影偏移遵循设备坐标，翻转视图中负高度才会落在方块下方。
-        context.saveGState()
-        context.setShadow(offset: CGSize(width: 5, height: -8), blur: 7,
-                          color: mix(base, .black, 0.35).withAlphaComponent(0.16).cgColor)
-        context.addPath(silhouette)
-        context.setFillColor(base.cgColor)
-        context.fillPath()
-        context.restoreGState()
-
-        // 先绘制所有侧面，再覆盖正面，方块相邻处保持细窄的接缝而不是双层描边。
-        for tile in tiles {
-            for layer in stride(from: 12, through: 0, by: -1) {
-                let depth = CGFloat(layer) / 12
-                let body = tile.offsetBy(dx: 4.8 * depth, dy: 4.5 * depth)
-                let side = mix(base, .black, 0.15 + depth * 0.10)
-                context.setFillColor(side.cgColor)
-                context.addPath(CGPath(roundedRect: body, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil))
-                context.fillPath()
-            }
-        }
-
-        for (index, tile) in tiles.enumerated() {
-            let outer = CGPath(roundedRect: tile, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
-            gradient(in: outer, rect: tile, colors: [mix(base, .white, 0.28), base, mix(base, .black, 0.22)], context: context)
-
-            // 柔和倒角连接正面和侧面，不再绘制原先亮白的内嵌边框。
-            let inset = tile.insetBy(dx: 2.3, dy: 2.3)
-            let surface = CGPath(roundedRect: inset, cornerWidth: 2.6, cornerHeight: 2.6, transform: nil)
-            gradient(in: surface, rect: inset, colors: [mix(base, .white, 0.10), base, mix(base, .black, 0.045)], context: context)
-            context.saveGState()
-            context.addPath(surface); context.clip()
-            let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
-                                   colors: [NSColor.white.withAlphaComponent(0.16).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
-                                   locations: [0, 1])!
-            let light = CGPoint(x: inset.minX + 2, y: inset.minY + 1)
-            context.drawRadialGradient(sheen, startCenter: light, startRadius: 0, endCenter: light,
-                                       endRadius: cell * 0.92, options: [.drawsAfterEndLocation])
-
-            // 固定种子的细微颗粒赋予哑光塑料质感，缓存后不会随动画闪烁。
-            for speck in 0..<100 {
-                let x = CGFloat((speck * 47 + index * 17) % 101) / 101
-                let y = CGFloat((speck * 31 + index * 29) % 103) / 103
-                context.setFillColor((speck.isMultiple(of: 2) ? NSColor.white : NSColor.black).withAlphaComponent(0.022).cgColor)
-                context.fillEllipse(in: CGRect(x: inset.minX + x * inset.width, y: inset.minY + y * inset.height, width: 0.45, height: 0.45))
-            }
-            context.restoreGState()
-        }
-    }
-
-    private static func mix(_ color: NSColor, _ other: NSColor, _ fraction: CGFloat) -> NSColor {
-        color.blended(withFraction: fraction, of: other) ?? color
-    }
-
-    private static func gradient(in path: CGPath, rect: NSRect, colors: [NSColor], context: CGContext) {
-        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 0.55, 1]) else { return }
-        context.saveGState()
-        context.addPath(path); context.clip()
-        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
-                                   end: CGPoint(x: rect.maxX, y: rect.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
-        context.restoreGState()
+        // 按实体宽度缩放，透明画布不会挤小图案；保持原始投影、圆角与相机透视。
+        let scale = rect.width / sprite.body.width
+        let destination = NSRect(x: rect.midX - sprite.body.midX * scale,
+                                 y: rect.midY - sprite.body.midY * scale,
+                                 width: sprite.image.size.width * scale, height: sprite.image.size.height * scale)
+        sprite.image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1,
+                          respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
     }
 }
```

### `Sources/Localization.swift`

```diff
--- a/Sources/Localization.swift
+++ b/Sources/Localization.swift
@@ -3,7 +3,8 @@
 /// 使用代码所在 Bundle 定位 XCTest 宿主旁的 SwiftPM 资源，避免依赖测试进程的主 Bundle。
 private final class LocalizationBundleToken: NSObject {}
 
-private enum LocalizerResourceLocator {
+/// 语言表与首页插画共用资源定位，兼容 SwiftPM 测试、直接运行及手工打包的 .app。
+enum GameResourceLocator {
     static let bundleName = "EliminateTeris1_EliminateTeris1"
 
     static func resourceBundle() -> Bundle? {
@@ -113,7 +114,7 @@
     }
 
     private func bundle(for language: AppLanguage) -> Bundle? {
-        guard let resourceBundle = LocalizerResourceLocator.resourceBundle() else {
+        guard let resourceBundle = GameResourceLocator.resourceBundle() else {
             return nil
         }
 
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -154,4 +154,33 @@
         }
     }
 
+    func testBundledHeroArtworkHasTransparencyAndFourCorrectSilhouettes() throws {
+        let url = try XCTUnwrap(GameResourceLocator.resourceBundle()?.url(forResource: "home-pieces-studio-v1", withExtension: "png"))
+        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
+        XCTAssertTrue(bitmap.hasAlpha, "透明插画不应在暖白背景中出现矩形底色")
+        XCTAssertEqual(bitmap.pixelsWide, 1254)
+        XCTAssertEqual(bitmap.pixelsHigh, 1254)
+        for point in [(0, 0), (626, 0), (627, 627), (1253, 1253)] {
+            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1)).alphaComponent, 0.01)
+        }
+        // 从实际图集采样每一格的正面中心，验证生成资源没有多画、漏画或翻转方块。
+        let bodies = [NSRect(x: 80, y: 196, width: 496, height: 359),
+                      NSRect(x: 710, y: 201, width: 474, height: 366),
+                      NSRect(x: 77, y: 729, width: 497, height: 360),
+                      NSRect(x: 692, y: 740, width: 496, height: 347)]
+        for (index, kind) in PieceKind.allCases.enumerated() {
+            let body = bodies[index]
+            for row in 0..<2 {
+                for column in 0..<3 {
+                    let x = Int(body.minX + (CGFloat(column) + 0.48) * body.width / 3)
+                    let y = Int(body.minY + (CGFloat(row) + 0.5) * body.height / 2)
+                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
+                    let channels = [color.redComponent, color.greenComponent, color.blueComponent]
+                    let solid = color.alphaComponent > 0.7 && channels.max()! - channels.min()! > 0.3
+                    XCTAssertEqual(solid, kind.blocks.contains(PieceBlock(x: column, y: 1 - row)), "\(kind.rawValue)：\(column),\(row)")
+                }
+            }
+        }
+    }
+
 }
```

### `Sources/Resources/Artwork/README.md`

```diff
--- /dev/null
+++ b/Sources/Resources/Artwork/README.md
@@ -0,0 +1,24 @@
+# 首页立体方块插画
+
+- `home-pieces-studio-v1.png`：1254×1254 像素 RGBA（包含透明通道）图集，由内置 imagegen 工具按参考设计生成。
+- 图集分成四个等大的象限：左上橙色、右上蓝色、左下绿色、右下红色；每个形状恰好包含四个立方体，方向与 `PieceKind.blocks` 一致。
+- 圆润体积、柔光高光、接触阴影和地面投影已包含在图片中，界面不再额外叠加侧边或描边。
+- `HomeHeroPieceRenderer` 从资源 Bundle 加载图集，在内存中分成四张图片并缓存；每种形状按自己的实体边界缩放，保留透明留白和投影。
+- 暖白首页的箭头、装饰短线和独立浮动仍由原生视图绘制。资源随 SwiftPM 与 `.app` 打包，不依赖外部路径或运行时网络。
+- 替换资源时需同步核对实体边界、透明通道、形状方向和首页尺寸预览；不能只改图集尺寸。
+
+## 原始生成提示词
+
+以下为生成工具实际接收的提示词，保留原文便于复现。第一张参考图为用户最初提供的首页设计，第二张为待替换的程序绘制效果。
+
+```text
+Use case: stylized-concept
+Asset type: A single transparent 2 by 2 sprite atlas of four premium 3D tetromino toy pieces, for a native macOS game's hero illustration.
+Primary request: Create REAL beautifully rounded 3D toy blocks matching the soft high-end plastic/clay rendering of the four small blocks in reference image 1. Reference image 2 is the inadequate current implementation: DO NOT reproduce its flat planar bevels, uniform diagonal strips, or vector-button appearance. We need physically convincing, subtle softbox reflections, broad rounded corner transitions, smooth solid thickness, gentle ambient occlusion between touching cubes, warm diffuse bounced light, and soft contact shadows. The first reference's four blocks around the exchange arrow are the target style, not the rest of its UI.
+Subject/geometry: exactly FOUR separate tetromino pieces, each made of exactly FOUR equal cubes. Each occupies its own quadrant with ample empty transparent margins. TOP LEFT is vivid golden-orange J piece with grid rows "..X" then "XXX". TOP RIGHT is saturated azure-blue L piece with rows "X.." then "XXX". BOTTOM LEFT is vivid fresh-green Z piece with rows "XX." then ".XX". BOTTOM RIGHT is coral-red S piece with rows ".XX" then "XX.". Preserve these exact silhouette orientations. Cubes share edges with tiny natural seams, not thick outlines.
+Composition/framing: Square atlas, four equal quadrants, orange at quadrant center (25%,25%), blue at (75%,25%), green at (25%,75%), red at (75%,75%). Each piece has the SAME cube size, each approximately 3 cubes wide and 2 cubes high, occupying about 66% of its quadrant width, centered. Consistent almost-frontal orthographic camera, very slight view from above and right, just enough to see true top and right surfaces, no dramatic isometric rotation. Pieces upright in the screen plane. Full pieces fully inside their own quadrant, no overlap. Leave a transparent gutter at horizontal and vertical center for software to crop the four quadrants.
+Lighting/mood: large warm-white softbox upper left, subtle cool fill, soft lower-right translucent contact shadow suitable for compositing onto a warm-white UI. No floor rectangle or visible horizon.
+Materials/textures: satin solid colored molded plastic, subtly soft rounded corners and edges, micro-roughness, not glossy glass or metal. Rich saturated colors; clearly modeled rounded edge surfaces with natural highlights rather than painted vector gradients.
+Text: none.
+Constraints: true transparent alpha background, including all margins and gutters; isolated assets only; no arrows, no sparkles or rays, no labels, no logos, no UI, no colored panels, no outlines or embossed inner borders, no fifth cubes, no extra pieces. This is ONE final asset atlas.
+```
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -10,6 +10,7 @@
 - 本局数据由 `GameState` 持有并通过 `GameSnapshot` 提供，成就累计由 `AchievementsManager` 单独持久化；两种生命周期互不混用。
 - 三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，首页不再提供档位设置。旧挑战记录保留，成就按固定规则兼容升级并保留已解锁状态。
 - 首页及辅助面板在探索分支使用暖白、蓝色选择态与黄色主操作的浅色主题，替代旧版桌面像素背景；Touch Bar 棋盘绘制链路沿用既有实现。
+- 首页主插画使用随应用打包的透明立体图集，按四种形状独立缓存和浮动；图片与语言表共用 `GameResourceLocator` 定位资源，运行时不依赖网络或三维渲染服务。
 
 ## 2026-10-29
 - 消除结算事件包含按 `PieceKind` 稳定标识分类的明细，先记录被消除的实际类型再补位；顶部统计与类型成就共用同一累计存档数据源，按类型统计不依赖分数或界面动画反推。
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261030085356-home-hero-studio-artwork.md` - 会话-59 起以 imagegen 透明立体图集替换程序渐变插画；独立缓存与浮动、共用资源定位、透明和四种轮廓验证，含本轮完整增量 diff 与 46 项完整回归。
 `workflow/20261030083751-home-hero-3d-material.md` - 会话-55 起细化首页四种方块插画：立体侧面、柔和倒角、哑光微纹理及落地色影；修复短线裁切，含本轮完整增量 diff 和 5 项首页回归。
 `workflow/20261030005042-light-home-ui-refactor-fixed-rules.md` - 会话-46 起在 experiment/ui-refactor 分支按参考图重构浅色首页；本局实时统计、固定竞分 60 秒/竞速 300 分、顶部辅助面板及成就兼容；含全部逐行 diff、45 项回归与原生渲染验收。
 `workflow/20261029224856-seven-segment-counts-and-bounce.md` - 会话-38 起将累计消除改为统一卡片标题，数量使用等高七段数码管、同步浮动与增长跳动；含完整增量 diff、真实渲染验收和 9 项界面回归结果。
@@ -67,6 +68,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整当前首页立体插画图集、实体缩放边界、透明资源加载或查看生成提示词时，读取 `20261030085356-home-hero-studio-artwork.md`。
 - 需要调整浅色首页主插画的 3D 材质、光照、投影、装饰短线或绘制缓存时，读取 `20261030083751-home-hero-3d-material.md`。
 - 需要了解探索分支浅色首页、本局统计与跨局成就分离、固定结束条件、开始按钮或顶部导航时，读取 `20261030005042-light-home-ui-refactor-fixed-rules.md`。
 - 需要调整顶部统计卡片标题、七段数字绘制、数字与方块同步浮动或消除增长跳动时，读取 `20261029224856-seven-segment-counts-and-bounce.md`。
@@ -134,7 +136,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- 首页主插画使用 `HomeHeroPieceRenderer` 的缓存立体材质，按原 `PieceKind.blocks` 绘制；小尺寸统计图标继续使用 `HomeStyle.piece`，主插画浮动时整体移动材质与投影。
+- 首页主插画使用 `HomeHeroPieceRenderer` 从本地透明立体图集加载四张缓存图片，实体边界控制缩放；`GameResourceLocator` 共用于语言和图片。小尺寸统计图标继续使用 `HomeStyle.piece`，主插画独立浮动时整体移动材质与投影。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
 - 探索分支三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
```

### `Sources/Resources/Artwork/home-pieces-studio-v1.png`

```diff
diff --git a/Sources/Resources/Artwork/home-pieces-studio-v1.png b/Sources/Resources/Artwork/home-pieces-studio-v1.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-pieces-studio-v1.png differ
```
