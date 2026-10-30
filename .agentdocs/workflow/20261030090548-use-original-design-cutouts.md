# 直接提取设计稿插画并按原稿比例排列

## 背景与目标
- 对应会话：会话-64 起；分支：`experiment/ui-refactor`。
- 用户明确要求对齐设计稿，并授权直接将原稿中的插画抠出使用。
- 本轮直接使用用户最初提供的首页设计稿像素，替换之前生成的近似素材。
- 文档以本轮开始时的工作区快照为基线记录增量；之前各次变更文档保留，便于按会话追溯。

## 来源与处理方式
- 原始设计稿保存为 `docs/design/home-reference.png`，1536×1024 像素。
- 新增 `Tools/extract-home-design.swift`：通过 AppKit 直接读取原稿编码像素，裁出四种方块和交换箭头。
- 方块图包含原稿的材质、高光、投影和装饰短线，不另外生成、补画或替换这些内容。
- 从裁切区域四角估计纸张底色，仅清除纸纹背景，并反解半透明投影的混色；不透明主体保留原始像素。
- PNG 沿用原稿嵌入的色彩空间，避免取色 API 的隐式转换导致颜色偏移。
- 先前生成的近似素材从应用资源移至 `docs/design/rejected-studio-artwork.png`，仅作历史追溯。

## 设计稿坐标

| 资源 | 原稿左上角 | 原始裁切尺寸 |
| --- | --- | --- |
| 橙色方块、投影和短线 | 76, 450 | 190×150 |
| 蓝色方块、投影和短线 | 290, 450 | 167×150 |
| 绿色方块、投影和短线 | 544, 435 | 197×165 |
| 红色方块、投影和短线 | 744, 440 | 207×160 |
| 交换箭头 | 462, 515 | 75×43 |

- 整组参考区域为 `(76, 435, 875, 165)`，所有资源共用一个缩放比例。
- `HomeHeroView` 不再单独绘制近似短线或箭头，也不再按手写百分比调整各个方块宽度与间距。
- 四个方块保留独立浮动，箭头不浮动；减少动态效果开启或离屏预览时停止浮动。
- 首页其他原生文字、按钮、模式卡片、统计和成就数据流保持既有实现。

## 阶段与 TODO
- [x] 保存原始设计稿，建立本轮工作区快照。
- [x] 直接提取五张透明资源，保留主体像素和原始材质。
- [x] 按原稿坐标整体等比排列，保留已有浮动体验。
- [x] 将不采用的生成素材移出运行资源目录。
- [x] 完成像素保真、轮廓和原生首页渲染验证。
- [x] 完成完整回归、根索引、资源说明与本轮逐行 diff。

## 复现与测试

### TC-001 重新提取
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork`。
- 结果：生成四个方块图和一个箭头图，均为透明 PNG，尺寸与原稿裁切区域一致。

### TC-002 主体像素与形状
- 测试：`testBundledHeroArtworkUsesOriginalDesignPixelsAndCorrectSilhouettes`。
- 从实际应用资源 Bundle 加载四种素材；核对尺寸、透明背景，以及两行三列中心采样与 `PieceKind.blocks` 的对应关系。
- 对全部不透明像素逐一与原稿对应坐标比较，要求通道误差不超过一个 8 位色阶。
- 结果：通过；证明素材直接来自原稿，形状没有多格、缺格或翻转。

### TC-003 首页渲染与功能回归
- 首页现有回归覆盖三种模式、五种语言、960×720、1180×800、1440×940 三种尺寸。
- 人工查看实际 AppKit 首页截图，确认采用原稿材质、阴影、短线与箭头，原生按钮和统计仍正常展示。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests`：6 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：46 项通过，0 失败，最终完成于 2026-10-30 09:04:43。
- `git diff --check`：通过。
- 首页预览：`/tmp/eliminate-home-original-design-preview.png`；插画单独预览：`/tmp/eliminate-home-original-design-hero.png`。
- 未重启玩家当前游戏，截图使用隔离测试数据；可执行 `./run.sh` 检查实际窗口中的浮动。

## 资源校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/design/home-reference.png` | 1833448 | `626ae39802348ceabfb8714c192080eb18df9a23aee371f8bbbb1efaf88ec821` |
| `Sources/Resources/Artwork/home-design-orange.png` | 23356 | `e64ff70ef4e49d6e6b1a965051c8efcb03aa95026c8ae5c126650d8b91407db5` |
| `Sources/Resources/Artwork/home-design-blue.png` | 22488 | `c1be946583913772f50dbfee3e72da25736689701d4675dfec7a6c6130c14fc0` |
| `Sources/Resources/Artwork/home-design-green.png` | 24848 | `0802f348b6e8ac7afaaec18ca75849f8d45fe24f6af54415d1b127b7874d90ec` |
| `Sources/Resources/Artwork/home-design-red.png` | 24200 | `25e9515c6e4d07449c05e8c49f1191eddca543068fd1638b04d8af68c980de82` |
| `Sources/Resources/Artwork/home-design-arrow.png` | 3142 | `c276e9e422ac36f257dfe55f78adf35c5233c4ff4a03fd389202dab58f4bb0bf` |
| `docs/design/rejected-studio-artwork.png` | 851059 | `662099e0badf8b4e09a110a8935c8abea4eae905e38916d57a781b452be20b8a` |

## 代码变更

以下为本轮全部文本变更的逐行 diff；新增图片及历史素材移动同时以 diff 记录，并以上述校验值追溯。

### `Sources/HomeHeroPieceRenderer.swift`

```diff
--- a/Sources/HomeHeroPieceRenderer.swift
+++ b/Sources/HomeHeroPieceRenderer.swift
@@ -1,50 +1,43 @@
 import Cocoa
 
-/// 首页主插画使用离线生成的立体资源，运行时只加载本地图片，不依赖网络或三维渲染环境。
+/// 直接使用原始设计稿提取的插画，保留其材质、投影、短线与相对位置。
 enum HomeHeroPieceRenderer {
     private struct Sprite {
-        let image: NSImage
-        /// 四分图内实体的像素边界，不含周围透明留白和柔和投影。
-        let body: NSRect
+        let kind: PieceKind?
+        let name: String
+        /// 原设计稿中的裁切区域，以左上角为原点。
+        let crop: NSRect
     }
 
-    private static let sprites: [PieceKind: Sprite] = loadSprites()
+    private static let reference = NSRect(x: 76, y: 435, width: 875, height: 165)
+    private static let sprites: [Sprite] = [
+        Sprite(kind: .orangeRicky, name: "home-design-orange", crop: NSRect(x: 76, y: 450, width: 190, height: 150)),
+        Sprite(kind: .blueRicky, name: "home-design-blue", crop: NSRect(x: 290, y: 450, width: 167, height: 150)),
+        Sprite(kind: .clevelandZ, name: "home-design-green", crop: NSRect(x: 544, y: 435, width: 197, height: 165)),
+        Sprite(kind: .rhodeIslandZ, name: "home-design-red", crop: NSRect(x: 744, y: 440, width: 207, height: 160)),
+        Sprite(kind: nil, name: "home-design-arrow", crop: NSRect(x: 462, y: 515, width: 75, height: 43))
+    ]
+    private static let images: [String: NSImage] = {
+        guard let bundle = GameResourceLocator.resourceBundle() else { return [:] }
+        return Dictionary(uniqueKeysWithValues: sprites.compactMap { sprite in
+            guard let url = bundle.url(forResource: sprite.name, withExtension: "png"),
+                  let image = NSImage(contentsOf: url) else { return nil }
+            return (sprite.name, image)
+        })
+    }()
 
-    private static func loadSprites() -> [PieceKind: Sprite] {
-        guard let url = GameResourceLocator.resourceBundle()?.url(forResource: "home-pieces-studio-v1", withExtension: "png"),
-              let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data),
-              let atlas = bitmap.cgImage else { return [:] }
-
-        let half = CGFloat(atlas.width) / 2
-        // 图集固定为 1254×1254，四种形状的前景边界经过透明度和颜色检查。
-        let definitions: [(PieceKind, Int, Int, NSRect)] = [
-            (.orangeRicky, 0, 0, NSRect(x: 80, y: 196, width: 496, height: 359)),
-            (.blueRicky, 1, 0, NSRect(x: 83, y: 201, width: 474, height: 366)),
-            (.clevelandZ, 0, 1, NSRect(x: 77, y: 102, width: 497, height: 360)),
-            (.rhodeIslandZ, 1, 1, NSRect(x: 65, y: 113, width: 496, height: 347))
-        ]
-        var result: [PieceKind: Sprite] = [:]
-        for (kind, column, row, body) in definitions {
-            // CGImage 裁切采用图像左上坐标；每张子图保留完整透明边缘与投影。
-            let crop = NSRect(x: CGFloat(column) * half, y: CGFloat(row) * half, width: half, height: half)
-            guard let pixels = atlas.cropping(to: crop) else { continue }
-            result[kind] = Sprite(image: NSImage(cgImage: pixels, size: crop.size), body: body)
+    static func draw(in bounds: NSRect, phase: CGFloat, animated: Bool) {
+        // 整组插画共用一个缩放比例，方块宽度、彼此间距、箭头与短线位置均来自设计稿。
+        let scale = min(bounds.width / reference.width, max(0, bounds.height - 6) / reference.height)
+        let origin = NSPoint(x: bounds.midX - reference.width * scale / 2,
+                             y: bounds.midY - reference.height * scale / 2)
+        for (index, sprite) in sprites.enumerated() {
+            let floating = animated && sprite.kind != nil ? sin(phase + CGFloat(index)) * 3 : 0
+            let destination = NSRect(x: origin.x + (sprite.crop.minX - reference.minX) * scale,
+                                     y: origin.y + (sprite.crop.minY - reference.minY) * scale + floating,
+                                     width: sprite.crop.width * scale, height: sprite.crop.height * scale)
+            images[sprite.name]?.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1,
+                                      respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
         }
-        return result
-    }
-
-    static func draw(_ kind: PieceKind, in rect: NSRect) {
-        guard let sprite = sprites[kind] else {
-            // 资源缺失时仍展示正确的方块形状，开发回归会检查资源是否被完整打包。
-            HomeStyle.piece(kind, in: rect)
-            return
-        }
-        // 按实体宽度缩放，透明画布不会挤小图案；保持原始投影、圆角与相机透视。
-        let scale = rect.width / sprite.body.width
-        let destination = NSRect(x: rect.midX - sprite.body.midX * scale,
-                                 y: rect.midY - sprite.body.midY * scale,
-                                 width: sprite.image.size.width * scale, height: sprite.image.size.height * scale)
-        sprite.image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1,
-                          respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
     }
 }
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -94,39 +94,8 @@
         self.timer = timer
     }
     override func draw(_ dirtyRect: NSRect) {
-        let centers: [CGFloat] = [0.12, 0.35, 0.65, 0.88]
-        for (index, kind) in PieceKind.allCases.enumerated() {
-            let float = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : sin(phase + CGFloat(index)) * 3
-            let width = min(106, bounds.width * 0.18)
-            let rect = NSRect(x: bounds.width * centers[index] - width / 2, y: max(34, bounds.midY - width / 3 + 5) + float,
-                              width: width, height: width * 2 / 3)
-            HomeHeroPieceRenderer.draw(kind, in: rect)
-            kind.color.withAlphaComponent(0.95).setStroke()
-            let rays = NSBezierPath(); rays.lineWidth = width * 0.04; rays.lineCapStyle = .round
-            // 蓝色从较低的一侧发散，其余从上角发散；为浮动最高点预留完整短线空间。
-            let x = index == 0 ? rect.minX - 3 : rect.maxX - 1
-            let y = rect.minY + (index == 1 ? rect.height * 0.35 : 0)
-            let direction: CGFloat = index == 0 ? -1 : 1
-            if direction < 0 {
-                rays.move(to: NSPoint(x: x, y: y - 7)); rays.line(to: NSPoint(x: x - 11, y: y - 18))
-                rays.move(to: NSPoint(x: x + 9, y: y - 14)); rays.line(to: NSPoint(x: x + 12, y: y - 27))
-            } else {
-                rays.move(to: NSPoint(x: x - 1, y: y - 13)); rays.line(to: NSPoint(x: x + 3, y: y - 25))
-                rays.move(to: NSPoint(x: x + 10, y: y - 6)); rays.line(to: NSPoint(x: x + 20, y: y - 13))
-            }
-            rays.stroke()
-        }
-        // 设计图中的双向箭头共用一条水平轴线，与两侧方块的中心对齐。
-        HomeStyle.secondary.setStroke()
-        let arrow = NSBezierPath(); arrow.lineWidth = 2.5; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
-        let x = bounds.midX, y = bounds.midY + 7
-        arrow.move(to: NSPoint(x: x - 20, y: y)); arrow.line(to: NSPoint(x: x + 20, y: y))
-        for direction: CGFloat in [-1, 1] {
-            arrow.move(to: NSPoint(x: x + direction * 13, y: y - 7))
-            arrow.line(to: NSPoint(x: x + direction * 20, y: y))
-            arrow.line(to: NSPoint(x: x + direction * 13, y: y + 7))
-        }
-        arrow.stroke()
+        let animated = window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
+        HomeHeroPieceRenderer.draw(in: bounds, phase: phase, animated: animated)
     }
 }
 
```

### `Sources/Resources/Artwork/README.md`

```diff
--- a/Sources/Resources/Artwork/README.md
+++ b/Sources/Resources/Artwork/README.md
@@ -1,24 +1,24 @@
-# 首页立体方块插画
+# 首页设计稿插画
 
-- `home-pieces-studio-v1.png`：1254×1254 像素 RGBA（包含透明通道）图集，由内置 imagegen 工具按参考设计生成。
-- 图集分成四个等大的象限：左上橙色、右上蓝色、左下绿色、右下红色；每个形状恰好包含四个立方体，方向与 `PieceKind.blocks` 一致。
-- 圆润体积、柔光高光、接触阴影和地面投影已包含在图片中，界面不再额外叠加侧边或描边。
-- `HomeHeroPieceRenderer` 从资源 Bundle 加载图集，在内存中分成四张图片并缓存；每种形状按自己的实体边界缩放，保留透明留白和投影。
-- 暖白首页的箭头、装饰短线和独立浮动仍由原生视图绘制。资源随 SwiftPM 与 `.app` 打包，不依赖外部路径或运行时网络。
-- 替换资源时需同步核对实体边界、透明通道、形状方向和首页尺寸预览；不能只改图集尺寸。
+当前首页直接使用用户原始设计稿中提取的图像，不重新生成或重绘方块。
 
-## 原始生成提示词
+## 来源与提取
+- 原始设计稿：`docs/design/home-reference.png`，1536×1024 像素。
+- 提取脚本：`Tools/extract-home-design.swift`，使用系统 AppKit 直接读取原稿像素。
+- 四个方块各自包含原稿中的材质、投影与装饰短线；交换箭头也来自原稿。
+- 脚本只移除纸纹背景，对低透明投影反解背景混色，方块和短线主体保留原始像素。
+- 每张图为透明 PNG；原始尺寸分别为橙色 190×150、蓝色 167×150、绿色 197×165、红色 207×160，箭头 75×43。
 
-以下为生成工具实际接收的提示词，保留原文便于复现。第一张参考图为用户最初提供的首页设计，第二张为待替换的程序绘制效果。
+## 布局与运行
+- `HomeHeroPieceRenderer` 按原稿坐标整体等比缩放，保持方块宽度、相互距离、箭头和短线的相对位置。
+- 四个方块独立浮动，箭头保持原位；减少动态效果开启时停止浮动。
+- 图片通过 `GameResourceLocator` 从应用资源 Bundle 读取并缓存，无网络依赖。
+- 先前生成的近似插画移至 `docs/design/rejected-studio-artwork.png`，供历史回看，不再进入应用资源 Bundle。
 
-```text
-Use case: stylized-concept
-Asset type: A single transparent 2 by 2 sprite atlas of four premium 3D tetromino toy pieces, for a native macOS game's hero illustration.
-Primary request: Create REAL beautifully rounded 3D toy blocks matching the soft high-end plastic/clay rendering of the four small blocks in reference image 1. Reference image 2 is the inadequate current implementation: DO NOT reproduce its flat planar bevels, uniform diagonal strips, or vector-button appearance. We need physically convincing, subtle softbox reflections, broad rounded corner transitions, smooth solid thickness, gentle ambient occlusion between touching cubes, warm diffuse bounced light, and soft contact shadows. The first reference's four blocks around the exchange arrow are the target style, not the rest of its UI.
-Subject/geometry: exactly FOUR separate tetromino pieces, each made of exactly FOUR equal cubes. Each occupies its own quadrant with ample empty transparent margins. TOP LEFT is vivid golden-orange J piece with grid rows "..X" then "XXX". TOP RIGHT is saturated azure-blue L piece with rows "X.." then "XXX". BOTTOM LEFT is vivid fresh-green Z piece with rows "XX." then ".XX". BOTTOM RIGHT is coral-red S piece with rows ".XX" then "XX.". Preserve these exact silhouette orientations. Cubes share edges with tiny natural seams, not thick outlines.
-Composition/framing: Square atlas, four equal quadrants, orange at quadrant center (25%,25%), blue at (75%,25%), green at (25%,75%), red at (75%,75%). Each piece has the SAME cube size, each approximately 3 cubes wide and 2 cubes high, occupying about 66% of its quadrant width, centered. Consistent almost-frontal orthographic camera, very slight view from above and right, just enough to see true top and right surfaces, no dramatic isometric rotation. Pieces upright in the screen plane. Full pieces fully inside their own quadrant, no overlap. Leave a transparent gutter at horizontal and vertical center for software to crop the four quadrants.
-Lighting/mood: large warm-white softbox upper left, subtle cool fill, soft lower-right translucent contact shadow suitable for compositing onto a warm-white UI. No floor rectangle or visible horizon.
-Materials/textures: satin solid colored molded plastic, subtly soft rounded corners and edges, micro-roughness, not glossy glass or metal. Rich saturated colors; clearly modeled rounded edge surfaces with natural highlights rather than painted vector gradients.
-Text: none.
-Constraints: true transparent alpha background, including all margins and gutters; isolated assets only; no arrows, no sparkles or rays, no labels, no logos, no UI, no colored panels, no outlines or embossed inner borders, no fifth cubes, no extra pieces. This is ONE final asset atlas.
+## 重新提取
+
+```sh
+DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork
 ```
+
+需保留原始 1536×1024 尺寸，不能先缩放输入设计稿。自动化测试会对比提取图片中的不透明像素与原稿，避免出现无意重绘。
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -121,6 +121,12 @@
                         let path = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-\(mode.key).png")
                         try png.write(to: path)
                         print("首页预览：\(path.path)")
+                        if mode == .free {
+                            let hero = try XCTUnwrap(descendants(home).compactMap { $0 as? HomeHeroView }.first)
+                            let artwork = try XCTUnwrap(hero.bitmapImageRepForCachingDisplay(in: hero.bounds))
+                            hero.cacheDisplay(in: hero.bounds, to: artwork)
+                            try XCTUnwrap(artwork.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-design-cutout-hero.png"))
+                        }
                     }
                 }
             }
@@ -154,33 +160,50 @@
         }
     }
 
-    func testBundledHeroArtworkHasTransparencyAndFourCorrectSilhouettes() throws {
-        let url = try XCTUnwrap(GameResourceLocator.resourceBundle()?.url(forResource: "home-pieces-studio-v1", withExtension: "png"))
-        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
-        XCTAssertTrue(bitmap.hasAlpha, "透明插画不应在暖白背景中出现矩形底色")
-        XCTAssertEqual(bitmap.pixelsWide, 1254)
-        XCTAssertEqual(bitmap.pixelsHigh, 1254)
-        for point in [(0, 0), (626, 0), (627, 627), (1253, 1253)] {
-            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1)).alphaComponent, 0.01)
-        }
-        // 从实际图集采样每一格的正面中心，验证生成资源没有多画、漏画或翻转方块。
-        let bodies = [NSRect(x: 80, y: 196, width: 496, height: 359),
-                      NSRect(x: 710, y: 201, width: 474, height: 366),
-                      NSRect(x: 77, y: 729, width: 497, height: 360),
-                      NSRect(x: 692, y: 740, width: 496, height: 347)]
-        for (index, kind) in PieceKind.allCases.enumerated() {
-            let body = bodies[index]
+    func testBundledHeroArtworkUsesOriginalDesignPixelsAndCorrectSilhouettes() throws {
+        let bundle = try XCTUnwrap(GameResourceLocator.resourceBundle())
+        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
+        let source = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: root.appendingPathComponent("docs/design/home-reference.png"))))
+        let definitions: [(PieceKind, String, Int, Int, Int, Int, NSRect)] = [
+            (.orangeRicky, "orange", 76, 450, 190, 150, NSRect(x: 28, y: 29, width: 138, height: 95)),
+            (.blueRicky, "blue", 290, 450, 167, 150, NSRect(x: 18, y: 34, width: 133, height: 92)),
+            (.clevelandZ, "green", 544, 435, 197, 165, NSRect(x: 17, y: 51, width: 134, height: 91)),
+            (.rhodeIslandZ, "red", 744, 440, 207, 160, NSRect(x: 16, y: 46, width: 135, height: 91))
+        ]
+        for (kind, name, originX, originY, width, height, body) in definitions {
+            let url = try XCTUnwrap(bundle.url(forResource: "home-design-\(name)", withExtension: "png"))
+            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
+            XCTAssertTrue(bitmap.hasAlpha)
+            XCTAssertEqual(bitmap.pixelsWide, width)
+            XCTAssertEqual(bitmap.pixelsHigh, height)
+            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.01)
+            // 对比主体的全部不透明像素，证明使用原稿而非相似的重新生成素材。
+            var maximumError: CGFloat = 0
+            var opaqueCount = 0
+            for y in 0..<height {
+                for x in 0..<width {
+                    let pixel = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
+                    guard pixel.alphaComponent > 0.999 else { continue }
+                    let original = try XCTUnwrap(source.colorAt(x: x + originX, y: y + originY)?.usingColorSpace(.sRGB))
+                    maximumError = max(maximumError, abs(pixel.redComponent - original.redComponent),
+                                       abs(pixel.greenComponent - original.greenComponent), abs(pixel.blueComponent - original.blueComponent))
+                    opaqueCount += 1
+                }
+            }
+            XCTAssertGreaterThan(opaqueCount, 5000)
+            XCTAssertLessThanOrEqual(maximumError, 1.1 / 255, "\(name) 主体像素应与设计稿一致")
             for row in 0..<2 {
                 for column in 0..<3 {
                     let x = Int(body.minX + (CGFloat(column) + 0.48) * body.width / 3)
                     let y = Int(body.minY + (CGFloat(row) + 0.5) * body.height / 2)
-                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
+                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                     let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                     let solid = color.alphaComponent > 0.7 && channels.max()! - channels.min()! > 0.3
                     XCTAssertEqual(solid, kind.blocks.contains(PieceBlock(x: column, y: 1 - row)), "\(kind.rawValue)：\(column),\(row)")
                 }
             }
         }
+        XCTAssertNotNil(bundle.url(forResource: "home-design-arrow", withExtension: "png"))
     }
 
 }
```

### `Tools/extract-home-design.swift`

```diff
--- /dev/null
+++ b/Tools/extract-home-design.swift
@@ -0,0 +1,76 @@
+import Cocoa
+
+/// 直接提取用户设计稿的像素，只移除纸纹背景；不重绘方块、光影或装饰短线。
+/// 用法：swift Tools/extract-home-design.swift docs/design/home-reference.png Sources/Resources/Artwork
+let input = URL(fileURLWithPath: CommandLine.arguments[1])
+let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
+let source = NSBitmapImageRep(data: try Data(contentsOf: input))!
+precondition(source.pixelsWide == 1536 && source.pixelsHigh == 1024, "需要原始 1536×1024 设计稿")
+print("沿用原稿色彩空间：\(source.colorSpace.localizedName ?? "RGB")")
+try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
+
+func rgb(_ x: Int, _ y: Int) -> [Double] {
+    // 直接读取编码通道，避开 NSColor 取色时的隐式转换，确保主体像素不发生二次色彩转换。
+    var components = [Int](repeating: 0, count: source.samplesPerPixel)
+    source.getPixel(&components, atX: x, y: y)
+    return components.prefix(3).map { Double($0) / 255 }
+}
+
+/// 四角的纸张颜色取中位数，避免纹理中个别深色像素影响背景估计。
+func background(_ x: Int, _ y: Int) -> [Double] {
+    let samples = (-3...3).flatMap { dy in (-3...3).map { dx in rgb(x + dx, y + dy) } }
+    return (0..<3).map { channel in samples.map { $0[channel] }.sorted()[samples.count / 2] }
+}
+
+let crops: [(String, Int, Int, Int, Int)] = [
+    ("home-design-orange", 76, 450, 190, 150),
+    ("home-design-blue", 290, 450, 167, 150),
+    ("home-design-green", 544, 435, 197, 165),
+    ("home-design-red", 744, 440, 207, 160),
+    ("home-design-arrow", 462, 515, 75, 43)
+]
+
+for (name, originX, originY, width, height) in crops {
+    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
+                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
+                                  colorSpaceName: .deviceRGB, bitmapFormat: [.alphaNonpremultiplied],
+                                  bytesPerRow: width * 4, bitsPerPixel: 32)!
+    let corners = [background(originX + 4, originY + 4), background(originX + width - 5, originY + 4),
+                   background(originX + 4, originY + height - 5), background(originX + width - 5, originY + height - 5)]
+    for y in 0..<height {
+        for x in 0..<width {
+            let pixel = rgb(originX + x, originY + y)
+            let u = Double(x) / Double(width - 1), v = Double(y) / Double(height - 1)
+            let paper = (0..<3).map { channel in
+                (1 - v) * ((1 - u) * corners[0][channel] + u * corners[1][channel])
+                    + v * ((1 - u) * corners[2][channel] + u * corners[3][channel])
+            }
+            let difference = (0..<3).map { abs(pixel[$0] - paper[$0]) }.max()!
+            let alpha: Double
+            if difference < 0.027 {
+                alpha = 0
+            } else if difference >= 0.18 {
+                // 方块与短线的主体保持不透明，原始材质像素原样保留。
+                alpha = 1
+            } else {
+                let t = (difference - 0.027) / (0.18 - 0.027)
+                let minimum = (0..<3).map { channel -> Double in
+                    if pixel[channel] <= paper[channel] { return (paper[channel] - pixel[channel]) / max(paper[channel], 0.001) }
+                    return (pixel[channel] - paper[channel]) / max(1 - paper[channel], 0.001)
+                }.max()!
+                alpha = min(1, max(minimum, t * t * (3 - 2 * t)))
+            }
+            let offset = y * bitmap.bytesPerRow + x * 4
+            for channel in 0..<3 {
+                // 反解纸张混色，透明投影贴到首页底色时不会出现白边或矩形纸纹。
+                let value = alpha == 0 ? 0 : (pixel[channel] - paper[channel] * (1 - alpha)) / alpha
+                bitmap.bitmapData![offset + channel] = UInt8((min(1, max(0, value)) * 255).rounded())
+            }
+            bitmap.bitmapData![offset + 3] = UInt8((alpha * 255).rounded())
+        }
+    }
+    // 沿用原稿嵌入的色彩空间，避免广色域颜色转为 sRGB 时被裁切或再次转换。
+    let png = bitmap.retagging(with: source.colorSpace)!.representation(using: .png, properties: [:])!
+    try png.write(to: output.appendingPathComponent(name + ".png"))
+    print("已直接提取：\(name)，\(width)×\(height)")
+}
```

### `docs/design/README.md`

```diff
--- /dev/null
+++ b/docs/design/README.md
@@ -0,0 +1,6 @@
+# 首页设计参考
+
+- `home-reference.png`：用户最初提供的 1536×1024 首页设计稿，作为当前主插画的直接像素来源。
+- `rejected-studio-artwork.png`：此前生成但未能对齐设计稿的近似素材，仅保留作变更追溯，不参与应用打包。
+- 当前应用使用 `Sources/Resources/Artwork/home-design-*.png`，由 `Tools/extract-home-design.swift` 从原设计稿直接提取。
+- 设计稿整体不作为界面背景使用；文字、按钮、统计、模式选择与成就仍为可交互的原生视图。
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -10,7 +10,7 @@
 - 本局数据由 `GameState` 持有并通过 `GameSnapshot` 提供，成就累计由 `AchievementsManager` 单独持久化；两种生命周期互不混用。
 - 三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，首页不再提供档位设置。旧挑战记录保留，成就按固定规则兼容升级并保留已解锁状态。
 - 首页及辅助面板在探索分支使用暖白、蓝色选择态与黄色主操作的浅色主题，替代旧版桌面像素背景；Touch Bar 棋盘绘制链路沿用既有实现。
-- 首页主插画使用随应用打包的透明立体图集，按四种形状独立缓存和浮动；图片与语言表共用 `GameResourceLocator` 定位资源，运行时不依赖网络或三维渲染服务。
+- 首页主插画直接使用设计稿提取的本地透明资源，按四种形状独立缓存和浮动；图片与语言表共用 `GameResourceLocator` 定位资源，运行时不依赖网络或三维渲染服务。
 
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
+`workflow/20261030090548-use-original-design-cutouts.md` - 会话-64 起直接从原始设计稿提取方块、投影、短线和箭头，按原稿坐标整体等比排列；主体像素保真验证、独立浮动及 46 项完整回归，含全部增量 diff 和资源校验。
 `workflow/20261030085356-home-hero-studio-artwork.md` - 会话-59 起以 imagegen 透明立体图集替换程序渐变插画；独立缓存与浮动、共用资源定位、透明和四种轮廓验证，含本轮完整增量 diff 与 46 项完整回归。
 `workflow/20261030083751-home-hero-3d-material.md` - 会话-55 起细化首页四种方块插画：立体侧面、柔和倒角、哑光微纹理及落地色影；修复短线裁切，含本轮完整增量 diff 和 5 项首页回归。
 `workflow/20261030005042-light-home-ui-refactor-fixed-rules.md` - 会话-46 起在 experiment/ui-refactor 分支按参考图重构浅色首页；本局实时统计、固定竞分 60 秒/竞速 300 分、顶部辅助面板及成就兼容；含全部逐行 diff、45 项回归与原生渲染验收。
@@ -68,6 +69,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整当前首页原稿提取素材、复现抠图、核对像素保真或原稿相对布局时，读取 `20261030090548-use-original-design-cutouts.md`。
 - 需要调整当前首页立体插画图集、实体缩放边界、透明资源加载或查看生成提示词时，读取 `20261030085356-home-hero-studio-artwork.md`。
 - 需要调整浅色首页主插画的 3D 材质、光照、投影、装饰短线或绘制缓存时，读取 `20261030083751-home-hero-3d-material.md`。
 - 需要了解探索分支浅色首页、本局统计与跨局成就分离、固定结束条件、开始按钮或顶部导航时，读取 `20261030005042-light-home-ui-refactor-fixed-rules.md`。
@@ -136,7 +138,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- 首页主插画使用 `HomeHeroPieceRenderer` 从本地透明立体图集加载四张缓存图片，实体边界控制缩放；`GameResourceLocator` 共用于语言和图片。小尺寸统计图标继续使用 `HomeStyle.piece`，主插画独立浮动时整体移动材质与投影。
+- 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
 - 探索分支三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
```

### `docs/design/home-reference.png`

```diff
diff --git a/docs/design/home-reference.png b/docs/design/home-reference.png
new file mode 100644
Binary files /dev/null and b/docs/design/home-reference.png differ
```

### `Sources/Resources/Artwork/home-design-orange.png`

```diff
diff --git a/Sources/Resources/Artwork/home-design-orange.png b/Sources/Resources/Artwork/home-design-orange.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-design-orange.png differ
```

### `Sources/Resources/Artwork/home-design-blue.png`

```diff
diff --git a/Sources/Resources/Artwork/home-design-blue.png b/Sources/Resources/Artwork/home-design-blue.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-design-blue.png differ
```

### `Sources/Resources/Artwork/home-design-green.png`

```diff
diff --git a/Sources/Resources/Artwork/home-design-green.png b/Sources/Resources/Artwork/home-design-green.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-design-green.png differ
```

### `Sources/Resources/Artwork/home-design-red.png`

```diff
diff --git a/Sources/Resources/Artwork/home-design-red.png b/Sources/Resources/Artwork/home-design-red.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-design-red.png differ
```

### `Sources/Resources/Artwork/home-design-arrow.png`

```diff
diff --git a/Sources/Resources/Artwork/home-design-arrow.png b/Sources/Resources/Artwork/home-design-arrow.png
new file mode 100644
Binary files /dev/null and b/Sources/Resources/Artwork/home-design-arrow.png differ
```

### 历史素材移出应用资源

```diff
diff --git a/Sources/Resources/Artwork/home-pieces-studio-v1.png b/docs/design/rejected-studio-artwork.png
similarity index 100%
rename from Sources/Resources/Artwork/home-pieces-studio-v1.png
rename to docs/design/rejected-studio-artwork.png
```
