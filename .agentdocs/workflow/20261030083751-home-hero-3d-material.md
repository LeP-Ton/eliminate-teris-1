# 首页方块插画立体材质细化

## 背景与目标
- 对应会话：会话-55 起；当前分支：`experiment/ui-refactor`。
- 用户指出首页主插画只有平面渐变和双层描边，缺少参考设计图的立体厚度、圆润高光和落地阴影。
- 本轮仅细化红框中的四种方块插画、装饰短线和交换箭头；不修改模式规则、统计数据源、成就规则或 Touch Bar 绘制。
- 本文基于本轮开始时的工作区快照记录增量，前一轮浅色首页重构仍保留在原变更文档中，不合并或覆盖旧记录。

## 设计与实现
- 新增 `HomeHeroPieceRenderer`，继续以 `PieceKind.blocks` 的真实形状绘制四种方块，无新图片或字体资源。
- 固定左上光照，用右下侧面表达厚度；正面采用柔和倒角、斜向渐变、局部高光及固定种子的细微哑光颗粒，移除原双层内描边。
- 整体投影只生成一次，结合脚下的柔和色影，避免逐格阴影叠加；正确处理翻转视图中 CGContext 阴影偏移的方向。
- 缓存每种方块的静态 NSImage 原生绘制内容，已有浮动动画只移动成品，纹理不会逐帧随机变化。
- 四种方块略微收小并增加两端留白，为投影和装饰短线提供空间；分开两根短线，避免相互连成折线或被顶部裁切。
- 交换箭头使用单一水平轴线的双向箭头，匹配参考图。
- 小尺寸实时统计图标保持简化绘制，避免立体侧面侵占数字空间。

## 阶段与 TODO
- [x] 对照参考设计图确认平面材质与立体材质的差异。
- [x] 完成立体侧面、倒角、高光、微纹理、投影与缓存。
- [x] 调整插画间距、装饰短线和双向箭头。
- [x] 运行现有首页回归并人工查看实际 AppKit 渲染截图。
- [x] 记录完整增量 diff 并更新根索引。

## 测试方法与结果
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests`。
- 结果：5 项测试全部通过，0 失败；最终运行时间为 2026-10-30 08:37。
- 现有布局测试覆盖三种模式、五种语言与 960×720、1180×800、1440×940 三种内容尺寸，同时生成原生首页 PNG。
- 人工查看最终首页截图，确认四种形状正确、倒角/侧面/下方投影可见、短线分离完整、箭头水平双向，原界面按钮和统计未被遮挡。
- 现有开始/模式切换/本局与累计数据隔离/固定结束条件测试均通过。
- `git diff --check`：通过。
- 未新增仅镜像绘制实现的测试，未重启用户正在运行的游戏；可通过 `./run.sh` 查看实际窗口中的浮动效果。

## 代码变更

以下逐行 diff 以本轮开始时的工作区快照为基线，新增文件完整记录。

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -94,21 +94,39 @@
         self.timer = timer
     }
     override func draw(_ dirtyRect: NSRect) {
-        let centers: [CGFloat] = [0.105, 0.335, 0.665, 0.895]
+        let centers: [CGFloat] = [0.12, 0.35, 0.65, 0.88]
         for (index, kind) in PieceKind.allCases.enumerated() {
             let float = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : sin(phase + CGFloat(index)) * 3
-            let width = min(112, bounds.width * 0.19)
-            let rect = NSRect(x: bounds.width * centers[index] - width / 2, y: bounds.midY - width / 3 + float,
+            let width = min(106, bounds.width * 0.18)
+            let rect = NSRect(x: bounds.width * centers[index] - width / 2, y: max(34, bounds.midY - width / 3 + 5) + float,
                               width: width, height: width * 2 / 3)
-            HomeStyle.piece(kind, in: rect)
-            kind.color.withAlphaComponent(0.85).setStroke()
-            let rays = NSBezierPath(); rays.lineWidth = 5; rays.lineCapStyle = .round
-            let x = index == 0 ? rect.minX + 4 : rect.maxX - 5
-            rays.move(to: NSPoint(x: x, y: rect.minY - 10)); rays.line(to: NSPoint(x: x + (index == 0 ? -9 : 9), y: rect.minY - 22))
-            rays.move(to: NSPoint(x: x + 9, y: rect.minY - 13)); rays.line(to: NSPoint(x: x + 12, y: rect.minY - 29))
+            HomeHeroPieceRenderer.draw(kind, in: rect)
+            kind.color.withAlphaComponent(0.95).setStroke()
+            let rays = NSBezierPath(); rays.lineWidth = width * 0.04; rays.lineCapStyle = .round
+            // 蓝色从较低的一侧发散，其余从上角发散；为浮动最高点预留完整短线空间。
+            let x = index == 0 ? rect.minX - 3 : rect.maxX - 1
+            let y = rect.minY + (index == 1 ? rect.height * 0.35 : 0)
+            let direction: CGFloat = index == 0 ? -1 : 1
+            if direction < 0 {
+                rays.move(to: NSPoint(x: x, y: y - 7)); rays.line(to: NSPoint(x: x - 11, y: y - 18))
+                rays.move(to: NSPoint(x: x + 9, y: y - 14)); rays.line(to: NSPoint(x: x + 12, y: y - 27))
+            } else {
+                rays.move(to: NSPoint(x: x - 1, y: y - 13)); rays.line(to: NSPoint(x: x + 3, y: y - 25))
+                rays.move(to: NSPoint(x: x + 10, y: y - 6)); rays.line(to: NSPoint(x: x + 20, y: y - 13))
+            }
             rays.stroke()
         }
-        HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: bounds.midX - 24, y: bounds.midY - 16, width: 48, height: 32), color: HomeStyle.secondary)
+        // 设计图中的双向箭头共用一条水平轴线，与两侧方块的中心对齐。
+        HomeStyle.secondary.setStroke()
+        let arrow = NSBezierPath(); arrow.lineWidth = 2.5; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
+        let x = bounds.midX, y = bounds.midY + 7
+        arrow.move(to: NSPoint(x: x - 20, y: y)); arrow.line(to: NSPoint(x: x + 20, y: y))
+        for direction: CGFloat in [-1, 1] {
+            arrow.move(to: NSPoint(x: x + direction * 13, y: y - 7))
+            arrow.line(to: NSPoint(x: x + direction * 20, y: y))
+            arrow.line(to: NSPoint(x: x + direction * 13, y: y + 7))
+        }
+        arrow.stroke()
     }
 }
 
```

### `Sources/HomeHeroPieceRenderer.swift`

```diff
--- /dev/null
+++ b/Sources/HomeHeroPieceRenderer.swift
@@ -0,0 +1,119 @@
+import Cocoa
+
+/// 首页插画专用的立体材质；以原有方块几何绘制，细小统计图标继续使用简化样式。
+enum HomeHeroPieceRenderer {
+    private static let cell: CGFloat = 36
+    private static let face = NSRect(x: 18, y: 16, width: 108, height: 72)
+    private static let canvas = NSSize(width: 154, height: 116)
+
+    // 固定光照来自左上方，使用明确色值避免系统强调色改变插画材质。
+    private static func color(for kind: PieceKind) -> NSColor {
+        switch kind {
+        case .orangeRicky: return NSColor(calibratedRed: 1, green: 0.61, blue: 0, alpha: 1)
+        case .blueRicky: return NSColor(calibratedRed: 0, green: 0.49, blue: 1, alpha: 1)
+        case .clevelandZ: return NSColor(calibratedRed: 0, green: 0.81, blue: 0.23, alpha: 1)
+        case .rhodeIslandZ: return NSColor(calibratedRed: 1, green: 0.23, blue: 0.20, alpha: 1)
+        }
+    }
+
+    /// 缓存静态材质，浮动动画只移动成品，避免每帧重复计算阴影和细腻纹理。
+    private static let images: [PieceKind: NSImage] = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { kind in
+        let image = NSImage(size: canvas, flipped: true) { _ in
+            guard let context = NSGraphicsContext.current?.cgContext else { return false }
+            paint(kind, context: context)
+            return true
+        }
+        return (kind, image)
+    })
+
+    static func draw(_ kind: PieceKind, in rect: NSRect) {
+        let scale = min(rect.width / face.width, rect.height / face.height)
+        let destination = NSRect(x: rect.midX - face.width * scale / 2 - face.minX * scale,
+                                 y: rect.midY - face.height * scale / 2 - face.minY * scale,
+                                 width: canvas.width * scale, height: canvas.height * scale)
+        images[kind]?.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+    }
+
+    private static func paint(_ kind: PieceKind, context: CGContext) {
+        let base = color(for: kind)
+        let tiles = kind.blocks.map { block in
+            NSRect(x: face.minX + CGFloat(block.x) * cell, y: face.minY + CGFloat(1 - block.y) * cell,
+                   width: cell - 0.6, height: cell - 0.6)
+        }
+        let silhouette = CGMutablePath()
+        for tile in tiles { silhouette.addRoundedRect(in: tile, cornerWidth: 3, cornerHeight: 3) }
+
+        // 脚下的柔和色影表现与地面的距离，整体轮廓投影补足右侧厚度。
+        context.saveGState()
+        context.translateBy(x: face.midX + 7, y: face.maxY + 8)
+        context.scaleBy(x: 1, y: 0.18)
+        if let ground = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
+                                   colors: [mix(base, .black, 0.35).withAlphaComponent(0.13).cgColor,
+                                            base.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
+            context.drawRadialGradient(ground, startCenter: .zero, startRadius: 0, endCenter: .zero,
+                                       endRadius: face.width * 0.56, options: [])
+        }
+        context.restoreGState()
+
+        // CGContext 的阴影偏移遵循设备坐标，翻转视图中负高度才会落在方块下方。
+        context.saveGState()
+        context.setShadow(offset: CGSize(width: 5, height: -8), blur: 7,
+                          color: mix(base, .black, 0.35).withAlphaComponent(0.16).cgColor)
+        context.addPath(silhouette)
+        context.setFillColor(base.cgColor)
+        context.fillPath()
+        context.restoreGState()
+
+        // 先绘制所有侧面，再覆盖正面，方块相邻处保持细窄的接缝而不是双层描边。
+        for tile in tiles {
+            for layer in stride(from: 12, through: 0, by: -1) {
+                let depth = CGFloat(layer) / 12
+                let body = tile.offsetBy(dx: 4.8 * depth, dy: 4.5 * depth)
+                let side = mix(base, .black, 0.15 + depth * 0.10)
+                context.setFillColor(side.cgColor)
+                context.addPath(CGPath(roundedRect: body, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil))
+                context.fillPath()
+            }
+        }
+
+        for (index, tile) in tiles.enumerated() {
+            let outer = CGPath(roundedRect: tile, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
+            gradient(in: outer, rect: tile, colors: [mix(base, .white, 0.28), base, mix(base, .black, 0.22)], context: context)
+
+            // 柔和倒角连接正面和侧面，不再绘制原先亮白的内嵌边框。
+            let inset = tile.insetBy(dx: 2.3, dy: 2.3)
+            let surface = CGPath(roundedRect: inset, cornerWidth: 2.6, cornerHeight: 2.6, transform: nil)
+            gradient(in: surface, rect: inset, colors: [mix(base, .white, 0.10), base, mix(base, .black, 0.045)], context: context)
+            context.saveGState()
+            context.addPath(surface); context.clip()
+            let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
+                                   colors: [NSColor.white.withAlphaComponent(0.16).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
+                                   locations: [0, 1])!
+            let light = CGPoint(x: inset.minX + 2, y: inset.minY + 1)
+            context.drawRadialGradient(sheen, startCenter: light, startRadius: 0, endCenter: light,
+                                       endRadius: cell * 0.92, options: [.drawsAfterEndLocation])
+
+            // 固定种子的细微颗粒赋予哑光塑料质感，缓存后不会随动画闪烁。
+            for speck in 0..<100 {
+                let x = CGFloat((speck * 47 + index * 17) % 101) / 101
+                let y = CGFloat((speck * 31 + index * 29) % 103) / 103
+                context.setFillColor((speck.isMultiple(of: 2) ? NSColor.white : NSColor.black).withAlphaComponent(0.022).cgColor)
+                context.fillEllipse(in: CGRect(x: inset.minX + x * inset.width, y: inset.minY + y * inset.height, width: 0.45, height: 0.45))
+            }
+            context.restoreGState()
+        }
+    }
+
+    private static func mix(_ color: NSColor, _ other: NSColor, _ fraction: CGFloat) -> NSColor {
+        color.blended(withFraction: fraction, of: other) ?? color
+    }
+
+    private static func gradient(in path: CGPath, rect: NSRect, colors: [NSColor], context: CGContext) {
+        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 0.55, 1]) else { return }
+        context.saveGState()
+        context.addPath(path); context.clip()
+        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
+                                   end: CGPoint(x: rect.maxX, y: rect.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
+        context.restoreGState()
+    }
+}
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261030083751-home-hero-3d-material.md` - 会话-55 起细化首页四种方块插画：立体侧面、柔和倒角、哑光微纹理及落地色影；修复短线裁切，含本轮完整增量 diff 和 5 项首页回归。
 `workflow/20261030005042-light-home-ui-refactor-fixed-rules.md` - 会话-46 起在 experiment/ui-refactor 分支按参考图重构浅色首页；本局实时统计、固定竞分 60 秒/竞速 300 分、顶部辅助面板及成就兼容；含全部逐行 diff、45 项回归与原生渲染验收。
 `workflow/20261029224856-seven-segment-counts-and-bounce.md` - 会话-38 起将累计消除改为统一卡片标题，数量使用等高七段数码管、同步浮动与增长跳动；含完整增量 diff、真实渲染验收和 9 项界面回归结果。
 `workflow/20261029222742-piece-clear-counts-and-milestones.md` - 会话-33 起新增顶部四种方块累计消除数量及每类百/千/万三档里程碑，共新增 12 枚成就、总数 32；含完整逐行 diff、存档兼容说明和 38 项回归结果。
@@ -66,6 +67,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整浅色首页主插画的 3D 材质、光照、投影、装饰短线或绘制缓存时，读取 `20261030083751-home-hero-3d-material.md`。
 - 需要了解探索分支浅色首页、本局统计与跨局成就分离、固定结束条件、开始按钮或顶部导航时，读取 `20261030005042-light-home-ui-refactor-fixed-rules.md`。
 - 需要调整顶部统计卡片标题、七段数字绘制、数字与方块同步浮动或消除增长跳动时，读取 `20261029224856-seven-segment-counts-and-bounce.md`。
 - 需要了解按方块类型计数、顶部数量显示、每类 100/1,000/10,000 成就及旧存档升级口径时，读取 `20261029222742-piece-clear-counts-and-milestones.md`。
@@ -132,6 +134,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 首页主插画使用 `HomeHeroPieceRenderer` 的缓存立体材质，按原 `PieceKind.blocks` 绘制；小尺寸统计图标继续使用 `HomeStyle.piece`，主插画浮动时整体移动材质与投影。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
 - 探索分支三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，设置只提供语言与总音量。原长时限/高目标成就已适配固定规则，保留历史解锁和存档。
```
