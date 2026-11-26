# 加深联系卡双层重叠并渐隐下板边角

## 背景与目标

- 上板下边缘向下延伸，下板上边缘向上延伸，让两块斜板叠得更紧。
- 下板右上外露区参考规则统计卡的渐隐边角。GitHub 反馈入口使用箭头和文字。

## 实现

- 上板高度从 63% 增至 70%，下板从 49% 增至 55%，重叠由 12% 增至 25%。两层在同一高度的左右间距继续等量。
- 下板的填色和描边沿高度从半透明渐入底部，让露出的右上角贴合大厅背景。
- 反馈按钮采用无边框链接样式，悬停或按下通过文字与箭头的颜色反馈。按钮位于下板实际露出的区域内，保留键盘焦点和原链接。

## 验证

- 在 302 × 110、500 × 148 点原生联系卡采样重叠比例、右上和下部的透明度、默认及悬停时的按钮边缘，并核对反馈链接目标。
- 检查标准大厅与俄语紧凑大厅的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动验证可运行 `./run.sh`，缩放大厅，查看上板底缘及下板右上角，再悬停或点击 GitHub 反馈链接。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 204dab078fc92243a44b4851ad616215a61f7f0b..e894004ed4045be8b0f0fe2a66a9504c734b3186 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126224828-refine-contact-stack-overlap-and-fade.md` - 会话-81 起向交界延伸联系卡上下板，让下板右上渐隐，并将 GitHub 反馈改为无边框链接。
 `workflow/20261126223219-stack-contact-card-like-statistics.md` - 会话-79 起将当前分支的「联系我们」拆成错位叠放的左上说明板和右下反馈板，沿用规则统计卡的斜边关系。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
@@ -111,6 +112,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整联系卡两块斜板的重叠、下板顶部透明度或反馈链接边框时，读取 `20261126224828-refine-contact-stack-overlap-and-fade.md`。
 - 需要调整「联系我们」的左上说明板、右下反馈板、重叠区域或反馈按钮定位时，读取 `20261126223219-stack-contact-card-like-statistics.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 2ac23e3861b010103e502c7f41c5ecbc0cb68a75..c5fa1c254fb5b28c70c1f875e043211216f55075 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -3,7 +3,7 @@ import CoreText
 
 /// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
 class HomeButton: NSButton {
-    enum Style { case navigation, primary, outline, achievementLink }
+    enum Style { case navigation, primary, feedbackLink, achievementLink }
     var style: Style = .navigation
     var symbolName: String?
     var onClick: (() -> Void)?
@@ -51,8 +51,17 @@ class HomeButton: NSButton {
         let offset = effect.press * 1.8 - effect.hover
         let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
         let primary = style == .primary
-        let outlined = style == .outline
-        let color = primary ? HomeDashboardStyle.navy : HomeDashboardStyle.ink
+        let feedbackLink = style == .feedbackLink
+        let ink = HomeDashboardStyle.ink
+        let color: NSColor
+        if primary {
+            color = HomeDashboardStyle.navy
+        } else if feedbackLink {
+            color = ink.blended(withFraction: effect.hover * 0.75 + effect.press * 0.25,
+                                of: HomeDashboardStyle.cyan) ?? ink
+        } else {
+            color = ink
+        }
         if primary {
             let yellow = HomeDashboardStyle.yellow
             NSGraphicsContext.saveGraphicsState()
@@ -70,19 +79,18 @@ class HomeButton: NSButton {
                 HomeDashboardStyle.navy.withAlphaComponent(0.36).setFill()
                 HomeDashboardStyle.slant(face).fill()
             }
-        } else if outlined || effect.hover > 0 {
+        } else if !feedbackLink, effect.hover > 0 {
             let cyan = HomeDashboardStyle.cyan
             HomeDashboardStyle.surface(face,
                                        colors: [cyan.withAlphaComponent(effect.hover * 0.10),
                                                 cyan.withAlphaComponent(0.04 + effect.hover * 0.14)],
-                                       border: cyan.withAlphaComponent(outlined ? 0.95 : effect.hover * 0.45),
-                                       lineWidth: outlined ? 1.35 : 0.8)
+                                       border: cyan.withAlphaComponent(effect.hover * 0.45), lineWidth: 0.8)
         }
         let label = style == .achievementLink && title.hasSuffix("  →") ? String(title.dropLast(3)) : title
         let weight: NSFont.Weight = primary ? .black : .bold
         let icon: CGFloat = symbolName == nil ? 0 : (primary ? bounds.height * 0.44 : 16)
         let gap: CGFloat = icon > 0 ? 10 : 0
-        let preferred = primary ? min(34, bounds.height * 0.52) : min(19, bounds.height * 0.44)
+        let preferred = primary ? min(34, bounds.height * 0.52) : min(19, bounds.height * (feedbackLink ? 0.47 : 0.44))
         let size = GameLobbyStyle.fittedSize(label, width: bounds.width - icon - gap - (primary ? 52 : 24),
                                              preferred: preferred, minimum: 10, weight: weight)
         let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
@@ -825,14 +833,14 @@ final class HomeContactPanelView: NSView {
 
     var upperPlateRect: NSRect {
         let lower = lowerPlateRect
-        let height = bounds.height * 0.63
+        let height = bounds.height * 0.70
         // 两层在水平截面上等宽，左上和右下的错位沿用同一斜角。
         let width = lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height)
         return NSRect(x: bounds.minX, y: bounds.minY, width: width, height: height)
     }
 
     var lowerPlateRect: NSRect {
-        let height = bounds.height * 0.49
+        let height = bounds.height * 0.55
         let offset = min(bounds.width, bounds.height * 0.11)
         return NSRect(x: bounds.minX + offset, y: bounds.maxY - height, width: bounds.width - offset, height: height)
     }
@@ -840,7 +848,7 @@ final class HomeContactPanelView: NSView {
     override init(frame: NSRect) {
         super.init(frame: frame)
         feedback.symbolName = "arrow.up.right"
-        feedback.style = .outline
+        feedback.style = .feedbackLink
         feedback.setAccessibilityRole(.link)
         feedback.onClick = { [weak self] in self?.openURL(Self.feedbackURL) }
         addSubview(feedback)
@@ -862,8 +870,8 @@ final class HomeContactPanelView: NSView {
         super.layout()
         let lower = lowerPlateRect
         // 反馈按钮在下板露出的区域内，四周留白沿真实斜边计算。
-        let top = upperPlateRect.maxY + 4
-        let availableHeight = max(0, lower.maxY - top - 5)
+        let top = upperPlateRect.maxY + 2
+        let availableHeight = max(0, lower.maxY - top - 2)
         let height = min(43, availableHeight)
         let y = top + (availableHeight - height) / 2
         let left = lower.minX + HomeDashboardStyle.edgeOffset(for: lower.maxY - y) + 12
@@ -875,8 +883,7 @@ final class HomeContactPanelView: NSView {
 
     override func draw(_ dirtyRect: NSRect) {
         let upper = upperPlateRect
-        HomeDashboardStyle.surface(lowerPlateRect, colors: [HomeDashboardStyle.color(0x192734), HomeDashboardStyle.color(0x101A25)],
-                                   border: HomeDashboardStyle.color(0x52616D), lineWidth: 1.25)
+        drawLowerPlate()
         HomeDashboardStyle.surface(upper, colors: [HomeDashboardStyle.color(0x203547), HomeDashboardStyle.color(0x142232)],
                                    border: HomeDashboardStyle.color(0x586D7F), lineWidth: 1.25)
 
@@ -899,4 +906,34 @@ final class HomeContactPanelView: NSView {
                                                                height: upper.maxY - descriptionY - 8),
                                        preferred: min(17, bounds.height * 0.12))
     }
+
+    private func drawLowerPlate() {
+        let lineWidth: CGFloat = 1.25
+        let plate = lowerPlateRect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
+        let shape = HomeDashboardStyle.cgSlant(plate)
+        guard !shape.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
+        let start = NSPoint(x: plate.midX, y: plate.minY)
+        let end = NSPoint(x: plate.midX, y: plate.maxY)
+        let stops: [CGFloat] = [0, 0.46, 1]
+
+        // 填色和描边一起渐隐，避免右上角只剩一条悬空亮线。
+        func drawFade(colors: [NSColor], tracingBorder: Bool) {
+            context.saveGState()
+            context.addPath(shape)
+            if tracingBorder {
+                context.setLineWidth(lineWidth)
+                context.replacePathWithStrokedPath()
+            }
+            context.clip()
+            NSGradient(colors: colors, atLocations: stops, colorSpace: .sRGB)?
+                .draw(from: start, to: end, options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
+            context.restoreGState()
+        }
+
+        let top = HomeDashboardStyle.color(0x243A4B)
+        let bottom = HomeDashboardStyle.color(0x13202C)
+        drawFade(colors: [top.withAlphaComponent(0.10), top.withAlphaComponent(0.76), bottom], tracingBorder: false)
+        let rim = HomeDashboardStyle.color(0x52616D)
+        drawFade(colors: [rim.withAlphaComponent(0.08), rim.withAlphaComponent(0.72), rim], tracingBorder: true)
+    }
 }
diff --git a/Tests/HomeContactPanelLayerTests.swift b/Tests/HomeContactPanelLayerTests.swift
index 20d8d6b474cf88b8d4fe92ca104d25e590e99eb9..e623434c33c6407f651cc013352bf86979500523 100644
--- a/Tests/HomeContactPanelLayerTests.swift
+++ b/Tests/HomeContactPanelLayerTests.swift
@@ -3,7 +3,7 @@ import XCTest
 @testable import EliminateTeris1
 
 final class HomeContactPanelLayerTests: XCTestCase {
-    func testContactRendersTwoOffsetPlatesAndKeepsTheFeedbackLink() throws {
+    func testContactFadesTheExtendedLowerPlateAndKeepsAnUnframedFeedbackLink() throws {
         _ = NSApplication.shared
         let language = Localizer.shared.language
         defer { Localizer.shared.setLanguage(language) }
@@ -19,8 +19,10 @@ final class HomeContactPanelLayerTests: XCTestCase {
             XCTAssertTrue(card.bounds.contains(lower), context)
             XCTAssertGreaterThan(lower.minY, upper.minY, context)
             XCTAssertGreaterThan(lower.maxY, upper.maxY, context)
+            XCTAssertEqual(upper.height / size.height, 0.70, accuracy: 0.01, context)
+            XCTAssertEqual(lower.height / size.height, 0.55, accuracy: 0.01, context)
             let overlap = upper.maxY - lower.minY
-            XCTAssertEqual(overlap / size.height, 0.12, accuracy: 0.035, context)
+            XCTAssertEqual(overlap / size.height, 0.25, accuracy: 0.01, context)
 
             let joinY = lower.minY + overlap / 2
             let upperJoin = edges(of: upper, at: joinY)
@@ -29,6 +31,7 @@ final class HomeContactPanelLayerTests: XCTestCase {
             XCTAssertEqual(lowerJoin.left - upperJoin.left, lowerJoin.right - upperJoin.right, accuracy: 0.1, context)
 
             let feedback = try XCTUnwrap(card.subviews.compactMap { $0 as? HomeButton }.first)
+            XCTAssertEqual(feedback.style, .feedbackLink, context)
             XCTAssertTrue(lower.contains(feedback.frame), context)
             XCTAssertGreaterThanOrEqual(feedback.frame.minY, upper.maxY - 0.1, context)
             let face = HomeDashboardStyle.slant(lower)
@@ -39,8 +42,7 @@ final class HomeContactPanelLayerTests: XCTestCase {
                 XCTAssertTrue(face.contains(NSPoint(x: edge.right - 0.5, y: y)), context)
             }
 
-            let bitmap = try XCTUnwrap(card.bitmapImageRepForCachingDisplay(in: card.bounds))
-            card.cacheDisplay(in: card.bounds, to: bitmap)
+            let bitmap = try render(card)
             func alpha(at point: NSPoint) throws -> CGFloat {
                 let x = Int(point.x * CGFloat(bitmap.pixelsWide) / size.width)
                 let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / size.height)
@@ -48,20 +50,25 @@ final class HomeContactPanelLayerTests: XCTestCase {
             }
 
             let upperOnly = center(of: upper, at: (upper.minY + lower.minY) / 2)
-            let lowerOnly = center(of: lower, at: (upper.maxY + lower.maxY) / 2)
             XCTAssertGreaterThan(try alpha(at: upperOnly), 0.55, context)
-            XCTAssertGreaterThan(try alpha(at: lowerOnly), 0.55, context)
 
-            // 在阶梯上下比较同一列像素，确认下板斜边实际露出在上板右侧。
-            let before = lower.minY - 2
-            let after = lower.minY + 2
-            let beforeRight = edges(of: upper, at: before).right
-            let afterRight = edges(of: lower, at: after).right
-            XCTAssertGreaterThan(afterRight - beforeRight, 2, context)
-            let stepX = (beforeRight + afterRight) / 2
-            let alphaAbove = try alpha(at: NSPoint(x: stepX, y: before))
-            let alphaBelow = try alpha(at: NSPoint(x: stepX, y: after))
-            XCTAssertGreaterThan(alphaBelow - alphaAbove, 0.35, context)
+            // 在重叠区右侧只采下板，分别核对渐变的起始、交界和下段。
+            func lowerRight(at fraction: CGFloat) -> NSPoint {
+                let y = lower.minY + overlap * fraction
+                let x = (edges(of: upper, at: y).right + edges(of: lower, at: y).right) / 2
+                return NSPoint(x: x, y: y)
+            }
+            let beginning = try alpha(at: lowerRight(at: 0.12))
+            let nearJoin = try alpha(at: lowerRight(at: 0.88))
+            let bottomY = upper.maxY + (lower.maxY - upper.maxY) * 0.75
+            let bottom = NSPoint(x: edges(of: lower, at: bottomY).left + 18, y: bottomY)
+            let lowerAlpha = try alpha(at: bottom)
+            XCTAssertTrue((0.04...0.40).contains(beginning), context)
+            XCTAssertTrue((0.50...0.88).contains(nearJoin), context)
+            XCTAssertGreaterThan(nearJoin - beginning, 0.30, context)
+            XCTAssertGreaterThan(lowerAlpha, 0.90, context)
+
+            try assertUnframedFeedback(feedback, context: context)
 
             var opened: URL?
             card.openURL = { opened = $0 }
@@ -83,4 +90,31 @@ final class HomeContactPanelLayerTests: XCTestCase {
         let edge = edges(of: plate, at: y)
         return NSPoint(x: (edge.left + edge.right) / 2, y: y)
     }
+
+    private func render(_ view: NSView) throws -> NSBitmapImageRep {
+        view.needsDisplay = true
+        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+        view.cacheDisplay(in: view.bounds, to: bitmap)
+        return bitmap
+    }
+
+    private func assertUnframedFeedback(_ feedback: HomeButton, context: String) throws {
+        defer { feedback.feedback.update(hover: false, press: false, animated: false) }
+        for hovering in [false, true] {
+            feedback.feedback.update(hover: hovering, press: false, animated: false)
+            let bitmap = try render(feedback)
+            let scale = CGFloat(bitmap.pixelsHigh) / feedback.bounds.height
+            // 单独缓存按钮，顶部仍透明，中央保留图标和文字的像素。
+            for y in 0..<Int(ceil(3 * scale)) {
+                let edge = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: y))
+                XCTAssertLessThan(edge.alphaComponent, 0.10, context)
+            }
+            let containsInk = (bitmap.pixelsHigh / 4..<(bitmap.pixelsHigh * 3 / 4)).contains { y in
+                (bitmap.pixelsWide / 4..<(bitmap.pixelsWide * 3 / 4)).contains { x in
+                    (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.80
+                }
+            }
+            XCTAssertTrue(containsInk, context)
+        }
+    }
 }
```
