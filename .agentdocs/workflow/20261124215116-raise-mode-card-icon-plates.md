# 游戏模式卡的凸出图标前层

## 背景与目标

- 参考截图中解谜模式左侧标注的位置和斜面比例，给右侧四张模式卡增加承载图标的独立前层。
- 前层沿用大厅的斜率。上沿凸出主卡，图标在前层几何中心等比绘制。

## 实现

- 使用深蓝灰渐变、从上沿渐隐的细高光和右下侧沿表现前后关系。选中色接入既有青色选择动画。
- 让前层右斜边承接图标与文字的分隔，移除原有斜分隔线。主卡沿原来的文字对齐规则排版。
- 将上沿留空纳入原生按钮的绘制和点击范围。键盘焦点轮廓覆盖两层，紧凑窗口中凸出的前层与相邻卡保持间隔。

## 验证

- 原生渲染回归覆盖四种默认模式卡、三种可选模式的选中态及 480 × 86、288 × 58 点两种卡片尺寸。通过像素确认上方凸出部分和前层内图标均实际绘制。
- 检查 1585 × 992 点与 960 × 720 点的真实大厅截图，确认图标、上沿、侧沿和相邻卡间隙完整。
- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全部 98 项测试，全部通过。手动核对可运行 `./run.sh`，在首页缩放窗口并切换自由、限时和限步，查看前层及所属卡片同步选中。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 8969919f7ffe66d4070119581db5c0d9c57dfdd3..7bcb3c9daa82cdab45092bf76078e274324f40bd 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124215116-raise-mode-card-icon-plates.md` - 会话-35 起给右侧四张游戏模式卡加入凸出上沿的斜面图标前层，含原生渲染与紧凑布局验证。
 `workflow/20261124212018-match-stat-plate-side-spacing.md` - 会话-32 起统一消除统计卡背板与前板左右斜边的水平错位，含原生像素回归及进度轨道留白校验。
 `workflow/20261124091725-animate-home-touch-bar-guide.md` - 会话-27 起将首页触控栏示意改为循环演示，包含竖直手指、蓝色滑动提示、相邻交换、三连消除和左侧补位。
 `workflow/20261124003148-move-challenge-budget-into-hud-header.md` - 会话-22 起移除统计卡顶部规则文案，自由模式留空，限时和限步把进度条移至顶部并沿斜边等距。
@@ -105,6 +106,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整右侧游戏模式卡的图标前层、立体侧沿、选中色或上沿留空时，读取 `20261124215116-raise-mode-card-icon-plates.md`。
 - 需要调整消除统计卡背板与前板的左右斜边间距或核对等距像素回归时，读取 `20261124212018-match-stat-plate-side-spacing.md`。
 - 需要调整首页触控栏演示的手势、交换、消除、补位、循环节奏或减少动态效果时，读取 `20261124091725-animate-home-touch-bar-guide.md`。
 - 需要调整统计卡顶部的预算轨道、左右等距留白、自由模式标题区域或限时限步预算显示时，读取 `20261124003148-move-challenge-budget-into-hud-header.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 91ad2e6644b8c6c2b91e75f948f1acb7ac72a167..8e4719d718e2788a193be20a84d9e820268e9861 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -100,6 +100,8 @@ class HomeButton: NSButton {
 }
 
 final class HomeModeButton: HomeButton {
+    static let iconPlateClearance: CGFloat = 8
+
     // 解谜暂时只是大厅入口，没有可交给棋盘控制器的游戏模式。
     let mode: HomeGameMode?
     private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
@@ -116,6 +118,34 @@ final class HomeModeButton: HomeButton {
     }
     required init?(coder: NSCoder) { nil }
 
+    var faceRect: NSRect {
+        let effect = feedback.values
+        let inset = bounds.insetBy(dx: 1.2, dy: 1.2)
+        return NSRect(x: inset.minX, y: inset.minY + Self.iconPlateClearance + effect.press * 1.4 - effect.hover,
+                      width: inset.width, height: max(0, inset.height - Self.iconPlateClearance))
+    }
+
+    var iconPlateRect: NSRect {
+        let face = faceRect
+        let height = face.height * 0.77
+        let width = face.height * 0.76 + HomeDashboardStyle.edgeOffset(for: height)
+        let rise = min(Self.iconPlateClearance - 1, face.height * 0.13)
+        return NSRect(x: face.minX + 1.5, y: face.minY - rise, width: width, height: height)
+    }
+
+    var modeIconRect: NSRect {
+        let plate = iconPlateRect
+        let size = min(44, plate.height * 0.64)
+        return NSRect(x: plate.midX - size / 2, y: plate.midY - size / 2, width: size, height: size)
+    }
+
+    override var focusRingMaskBounds: NSRect { faceRect.union(iconPlateRect) }
+
+    override func drawFocusRingMask() {
+        HomeDashboardStyle.slant(faceRect).fill()
+        HomeDashboardStyle.slant(iconPlateRect).fill()
+    }
+
     func refresh(selectedMode: HomeGameMode) {
         selected = mode == selectedMode
         let language = Localizer.shared.language
@@ -126,7 +156,8 @@ final class HomeModeButton: HomeButton {
     }
     override func draw(_ dirtyRect: NSRect) {
         let effect = feedback.values
-        let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: effect.press * 1.4 - effect.hover)
+        let face = faceRect
+        guard face.height > 0, face.width > 0 else { return }
         let cyan = HomeDashboardStyle.cyan
         let tint = min(1, effect.selection + effect.hover * 0.26)
         let left = HomeDashboardStyle.color(0x222D35)
@@ -136,13 +167,9 @@ final class HomeModeButton: HomeButton {
         let stroke = HomeDashboardStyle.border.blended(withFraction: tint, of: cyan) ?? cyan
         HomeDashboardStyle.surface(face, colors: colors, border: stroke,
                                    lineWidth: 1 + 1.7 * effect.selection)
-        let iconSize = min(48, face.height * 0.56)
-        let icon = NSRect(x: face.minX + face.height * 0.57, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
-        drawModeIcon(in: icon, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
-        let splitX = icon.maxX + face.height * 0.26
-        HomeDashboardStyle.diagonal(from: NSPoint(x: splitX, y: face.midY - iconSize / 2),
-                                    height: iconSize, color: HomeDashboardStyle.border, width: 1.2)
-        let textX = splitX + 13
+        drawIconPlate(iconPlateRect, tint: tint)
+        drawModeIcon(in: modeIconRect, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
+        let textX = face.minX + face.height * 0.83 + min(48, face.height * 0.56) + 13
         let textWidth = face.maxX - textX - max(31, face.height * 0.67)
         let title = AchievementText.string(titleKey)
         let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(24, face.height * 0.34),
@@ -164,6 +191,31 @@ final class HomeModeButton: HomeButton {
         }
     }
 
+    private func drawIconPlate(_ plate: NSRect, tint: CGFloat) {
+        let depth = min(3.5, plate.height * 0.07)
+        let side = HomeDashboardStyle.color(0x09151E)
+        let activeSide = HomeDashboardStyle.color(0x12424B)
+        (side.blended(withFraction: tint, of: activeSide) ?? side).setFill()
+        HomeDashboardStyle.slant(plate.offsetBy(dx: depth, dy: depth)).fill()
+
+        let upper = HomeDashboardStyle.color(0x354858)
+        let lower = HomeDashboardStyle.color(0x162631)
+        let edge = HomeDashboardStyle.color(0x617889)
+        let cyan = HomeDashboardStyle.cyan
+        HomeDashboardStyle.surface(plate,
+                                   colors: [upper.blended(withFraction: tint, of: HomeDashboardStyle.color(0x236570)) ?? upper,
+                                            lower.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0D303A)) ?? lower],
+                                   border: edge.blended(withFraction: tint * 0.72, of: cyan) ?? edge)
+
+        // 只提亮前层受光的一段上沿，让下沿的侧面保有厚度。
+        let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
+        let light = HomeDashboardStyle.color(0xB4D3E8).blended(withFraction: tint * 0.55, of: cyan) ?? cyan
+        let highlight = NSRect(x: plate.minX + cut + 1.3, y: plate.minY + 1,
+                               width: (plate.width - cut) * 0.81, height: 1)
+        NSGradient(starting: light.withAlphaComponent(0.78), ending: light.withAlphaComponent(0))?
+            .draw(in: highlight, angle: 0)
+    }
+
     private func drawModeIcon(in rect: NSRect, color: NSColor) {
         switch mode {
         case .free:
@@ -636,13 +688,15 @@ final class HomeDashboardView: NSView {
                             width: hint.preferredMaxLayoutWidth, height: max(0, achievementTop - stageBottom - 10))
         achievementPath.frame = NSRect(x: margin, y: achievementTop, width: bounds.width - margin * 2,
                                        height: max(0, bounds.height - achievementTop - min(30, bounds.height * 0.031)))
-        let rowGap = min(13, max(7, bounds.height * 0.012))
+        let frontClearance = HomeModeButton.iconPlateClearance
+        let rowGap = min(13, max(frontClearance + 1, bounds.height * 0.012))
         let firstRowY: CGFloat = modePanel.isCompact ? 49 : 57
         let rowHeight = max(0, panel.height - firstRowY - 4 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
         for (index, button) in modes.enumerated() {
             let x = CGFloat(modes.count - 1 - index) * min(5, bounds.width * 0.0039)
-            button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap),
-                                  width: max(0, panel.width - 15), height: rowHeight)
+            // 把伸出上沿的前层纳入按钮范围，绘制不会被裁切，图标也可以点击。
+            button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap) - frontClearance,
+                                  width: max(0, panel.width - 15), height: rowHeight + frontClearance)
         }
         var navX = bounds.width - margin + 5
         for button in [settings, rules, records] {
diff --git a/Tests/HomeModeButtonArtworkTests.swift b/Tests/HomeModeButtonArtworkTests.swift
new file mode 100644
index 0000000000000000000000000000000000000000..6aa42cb2e1219c5a6ae08e32022ef01d0d8f53c4
--- /dev/null
+++ b/Tests/HomeModeButtonArtworkTests.swift
@@ -0,0 +1,105 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class HomeModeButtonArtworkTests: XCTestCase {
+    private let modes: [HomeGameMode?] = [.free, nil, .timed, .moves]
+    private let sizes = [NSSize(width: 480, height: 86), NSSize(width: 288, height: 58)]
+
+    func testEveryModeIconRendersInsideTheRaisedPlate() throws {
+        _ = NSApplication.shared
+        for size in sizes {
+            for mode in modes {
+                let idle = try assertRaisedPlate(on: makeButton(mode: mode, size: size, selected: false))
+                if mode != nil {
+                    let selected = try assertRaisedPlate(on: makeButton(mode: mode, size: size, selected: true))
+                    XCTAssertNotEqual(idle, selected, "选中态与默认态应保留可见区别")
+                }
+            }
+        }
+    }
+
+    func testExportModeIconPlatePreview() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let preview = ModeIconPlatePreview(frame: NSRect(x: 0, y: 0, width: 830, height: 424))
+        for (index, mode) in modes.enumerated() {
+            let y = 17 + CGFloat(index) * 100
+            let wide = makeButton(mode: mode, size: sizes[0], selected: mode != nil)
+            wide.setFrameOrigin(NSPoint(x: 16, y: y))
+            let compact = makeButton(mode: mode, size: sizes[1], selected: false)
+            compact.setFrameOrigin(NSPoint(x: 522, y: y + 14))
+            preview.addSubview(wide)
+            preview.addSubview(compact)
+        }
+        let png = try XCTUnwrap(try bitmap(of: preview).representation(using: .png, properties: [:]))
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-mode-icon-plates.png")
+        try png.write(to: url)
+    }
+
+    private func makeButton(mode: HomeGameMode?, size: NSSize, selected: Bool) -> HomeModeButton {
+        let button = HomeModeButton(mode: mode)
+        button.frame = NSRect(origin: .zero, size: size)
+        let otherMode: HomeGameMode = mode == .free ? .timed : .free
+        button.refresh(selectedMode: selected ? (mode ?? otherMode) : otherMode)
+        return button
+    }
+
+    private func bitmap(of view: NSView) throws -> NSBitmapImageRep {
+        view.layoutSubtreeIfNeeded()
+        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+        view.cacheDisplay(in: view.bounds, to: bitmap)
+        return bitmap
+    }
+
+    private func assertRaisedPlate(on button: HomeModeButton) throws -> Data {
+        let face = button.faceRect
+        let plate = button.iconPlateRect
+        let icon = button.modeIconRect
+        let context = "\(button.mode?.key ?? "解谜")／\(button.bounds.width)／\(button.selected ? "选中" : "默认")"
+        XCTAssertGreaterThan(face.minY - plate.minY, 2, context)
+        XCTAssertGreaterThan(plate.maxY, face.minY, context)
+        XCTAssertLessThan(plate.midX, face.midX, context)
+        XCTAssertTrue(button.bounds.contains(plate), context)
+        XCTAssertTrue(plate.contains(icon), context)
+
+        let bitmap = try bitmap(of: button)
+        let xScale = CGFloat(bitmap.pixelsWide) / button.bounds.width
+        let yScale = CGFloat(bitmap.pixelsHigh) / button.bounds.height
+        func color(at point: NSPoint) throws -> NSColor {
+            try XCTUnwrap(bitmap.colorAt(x: Int(point.x * xScale), y: Int(point.y * yScale))?.usingColorSpace(.sRGB))
+        }
+
+        // 在主卡上沿上方横向取样，确认只有前层所在位置绘制了内容。
+        let raisedY = (plate.minY + face.minY) / 2
+        let raisedX = plate.midX + (plate.midY - raisedY) * HomeDashboardStyle.slope
+        let raised = try color(at: NSPoint(x: raisedX, y: raisedY))
+        let outside = try color(at: NSPoint(x: face.midX, y: raisedY))
+        XCTAssertGreaterThan(raised.alphaComponent - outside.alphaComponent, 0.35, context)
+
+        // 在图标矩形内寻找高对比笔画，避开前层和主卡的分隔描边。
+        let ink = icon.insetBy(dx: 1, dy: 1)
+        let columns = Int(ceil(ink.minX * xScale))..<Int(floor(ink.maxX * xScale))
+        let rows = Int(ceil(ink.minY * yScale))..<Int(floor(ink.maxY * yScale))
+        var visiblePixels = 0
+        for y in rows {
+            for x in columns {
+                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
+                      color.alphaComponent > 0.75, min(color.greenComponent, color.blueComponent) > 0.63 else { continue }
+                visiblePixels += 1
+            }
+        }
+        XCTAssertGreaterThan(visiblePixels, 8, context)
+        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+    }
+}
+
+private final class ModeIconPlatePreview: NSView {
+    override var isFlipped: Bool { true }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeDashboardStyle.backdrop(in: bounds)
+    }
+}
```
