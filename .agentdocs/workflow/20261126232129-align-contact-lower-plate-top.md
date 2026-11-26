# 联系卡下板右侧收窄并与上板同顶

## 背景与目标

- 下板右斜边按原宽度收窄 8%，并向上延伸到与上板的上边框同高。
- 保留上板的原几何、下板左侧斜线与底部位置，以及下板在右侧的渐隐。

## 实现

- 在下板原上沿的高度计算 8% 内收，再沿大厅共用斜率向上延伸。窄高尺寸下，新右上角以联系卡右界为限。
- 让渐隐的中间色标跟随上板底缘，反馈链接按缩进后的下板边缘重新定位。

## 验证

- 对 302 × 110、500 × 148 点的联系卡测量上下板顶部和旧上沿高度的 8% 内收，另用 302 × 165 点用例验证窄高尺寸的边界。
- 核对渐隐像素、反馈链接的原生布局和点击目标。手动验证可运行 `./run.sh` 并缩放窗口，查看两层上边框和右侧渐隐。
- 检查标准和紧凑大厅原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index b91b3b2ac37bd4fbc2e5dda9ad7031e8a7dc7c19..5bb55cc8f6d8619f99ae5a995d7b77e8e53a0e0b 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126232129-align-contact-lower-plate-top.md` - 会话-85 起将联系卡下板右斜边收窄 8%，并沿原斜率向上延伸至与上板齐平。
 `workflow/20261126230618-reveal-contact-lower-plate-top-right.md` - 会话-83 起缩短联系卡上板右缘，让下板右上渐隐斜面露出更多。
 `workflow/20261126224828-refine-contact-stack-overlap-and-fade.md` - 会话-81 起向交界延伸联系卡上下板，让下板右上渐隐，并将 GitHub 反馈改为无边框链接。
 `workflow/20261126223219-stack-contact-card-like-statistics.md` - 会话-79 起将当前分支的「联系我们」拆成错位叠放的左上说明板和右下反馈板，沿用规则统计卡的斜边关系。
@@ -113,6 +114,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整联系卡下板右斜边、上下板顶部对齐或窄高窗口外缘约束时，读取 `20261126232129-align-contact-lower-plate-top.md`。
 - 需要调整联系卡上板右侧宽度或下板右上露出面积时，读取 `20261126230618-reveal-contact-lower-plate-top-right.md`。
 - 需要调整联系卡两块斜板的重叠、下板顶部透明度或反馈链接边框时，读取 `20261126224828-refine-contact-stack-overlap-and-fade.md`。
 - 需要调整「联系我们」的左上说明板、右下反馈板、重叠区域或反馈按钮定位时，读取 `20261126223219-stack-contact-card-like-statistics.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index b37f0f69633b1d0bbb3227c971541f1d14cee01e..f3b236b955b4d9fcb6819e6b058d6a87e8fb6319 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -832,7 +832,7 @@ final class HomeContactPanelView: NSView {
     override var isFlipped: Bool { true }
 
     var upperPlateRect: NSRect {
-        let lower = lowerPlateRect
+        let lower = lowerPlateReferenceRect
         let height = bounds.height * 0.70
         // 只收窄右边，露出更宽的下板右上渐隐区域。
         let rightTrim = min(26, bounds.width * 0.05)
@@ -841,6 +841,15 @@ final class HomeContactPanelView: NSView {
     }
 
     var lowerPlateRect: NSRect {
+        let reference = lowerPlateReferenceRect
+        let rise = reference.minY - bounds.minY
+        let trimmedRight = reference.maxX - reference.width * 0.08
+        // 先在原上沿高度收窄右斜边，再沿同一斜率向上延伸到与上板齐平。
+        let topRight = min(bounds.maxX, trimmedRight + HomeDashboardStyle.edgeOffset(for: rise))
+        return NSRect(x: reference.minX, y: bounds.minY, width: max(0, topRight - reference.minX), height: bounds.height)
+    }
+
+    private var lowerPlateReferenceRect: NSRect {
         let height = bounds.height * 0.55
         let offset = min(bounds.width, bounds.height * 0.11)
         return NSRect(x: bounds.minX + offset, y: bounds.maxY - height, width: bounds.width - offset, height: height)
@@ -915,7 +924,8 @@ final class HomeContactPanelView: NSView {
         guard !shape.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
         let start = NSPoint(x: plate.midX, y: plate.minY)
         let end = NSPoint(x: plate.midX, y: plate.maxY)
-        let stops: [CGFloat] = [0, 0.46, 1]
+        let join = min(0.90, (upperPlateRect.maxY - plate.minY) / plate.height)
+        let stops: [CGFloat] = [0, join, 1]
 
         // 填色和描边一起渐隐，避免右上角只剩一条悬空亮线。
         func drawFade(colors: [NSColor], tracingBorder: Bool) {
diff --git a/Tests/HomeContactPanelLayerTests.swift b/Tests/HomeContactPanelLayerTests.swift
index bc20bfd64d89977a69c4445058de6df84a8e3175..64752bc38e38bf3cacd4d421d9cb16be216486cd 100644
--- a/Tests/HomeContactPanelLayerTests.swift
+++ b/Tests/HomeContactPanelLayerTests.swift
@@ -3,13 +3,15 @@ import XCTest
 @testable import EliminateTeris1
 
 final class HomeContactPanelLayerTests: XCTestCase {
-    func testContactFadesTheExtendedLowerPlateAndKeepsAnUnframedFeedbackLink() throws {
+    func testContactAlignsThePlateTopsAndPreservesTheLowerFadeAndFeedbackLink() throws {
         _ = NSApplication.shared
         let language = Localizer.shared.language
         defer { Localizer.shared.setLanguage(language) }
         Localizer.shared.setLanguage(.chineseSimplified)
 
-        for size in [NSSize(width: 302, height: 110), NSSize(width: 500, height: 148)] {
+        let sizes = [(NSSize(width: 302, height: 110), false), (NSSize(width: 500, height: 148), false),
+                     (NSSize(width: 302, height: 165), true)]
+        for (size, keepsRightEdgeInBounds) in sizes {
             let card = HomeContactPanelView(frame: NSRect(origin: .zero, size: size))
             card.layoutSubtreeIfNeeded()
             let upper = card.upperPlateRect
@@ -19,22 +21,39 @@ final class HomeContactPanelLayerTests: XCTestCase {
             XCTAssertTrue(card.bounds.contains(lower), context)
             XCTAssertEqual(upper.minX, card.bounds.minX, accuracy: 0.01, context)
             XCTAssertEqual(upper.minY, card.bounds.minY, accuracy: 0.01, context)
+            XCTAssertEqual(lower.minY, upper.minY, accuracy: 0.01, context)
             XCTAssertEqual(lower.minX, card.bounds.minX + size.height * 0.11, accuracy: 0.01, context)
-            XCTAssertEqual(lower.maxX, card.bounds.maxX, accuracy: 0.01, context)
             XCTAssertEqual(lower.maxY, card.bounds.maxY, accuracy: 0.01, context)
-            XCTAssertGreaterThan(lower.minY, upper.minY, context)
             XCTAssertGreaterThan(lower.maxY, upper.maxY, context)
             XCTAssertEqual(upper.height / size.height, 0.70, accuracy: 0.01, context)
-            XCTAssertEqual(lower.height / size.height, 0.55, accuracy: 0.01, context)
             let overlap = upper.maxY - lower.minY
-            XCTAssertEqual(overlap / size.height, 0.25, accuracy: 0.01, context)
+            XCTAssertEqual(overlap / size.height, 0.70, accuracy: 0.01, context)
+
+            let oldLowerHeight = size.height * 0.55
+            let oldLowerTop = card.bounds.maxY - oldLowerHeight
+            let oldLowerWidth = card.bounds.maxX - lower.minX
+            let oldUpperWidth = oldLowerWidth + HomeDashboardStyle.edgeOffset(for: upper.height - oldLowerHeight)
+                - min(26, size.width * 0.05)
+            XCTAssertEqual(upper.width, oldUpperWidth, accuracy: 0.01, context)
+
+            // 沿用原下板左斜边，并在旧上沿高度核对右边的 8% 内收。
+            let oldTopEdges = edges(of: lower, at: oldLowerTop)
+            XCTAssertEqual(oldTopEdges.left, lower.minX + HomeDashboardStyle.edgeOffset(for: oldLowerHeight), accuracy: 0.01, context)
+            let trimmedRight = card.bounds.maxX - oldLowerWidth * 0.08
+            let extendedRight = trimmedRight + HomeDashboardStyle.edgeOffset(for: oldLowerTop - upper.minY)
+            if keepsRightEdgeInBounds {
+                XCTAssertGreaterThan(extendedRight, card.bounds.maxX, context)
+                XCTAssertEqual(lower.maxX, card.bounds.maxX, accuracy: 0.01, context)
+            } else {
+                XCTAssertLessThan(extendedRight, card.bounds.maxX, context)
+                XCTAssertEqual(oldTopEdges.right, trimmedRight, accuracy: 0.01, context)
+            }
 
             let joinY = lower.minY + overlap / 2
             let upperJoin = edges(of: upper, at: joinY)
             let lowerJoin = edges(of: lower, at: joinY)
-            let trim = min(26, size.width * 0.05)
             XCTAssertGreaterThan(lowerJoin.left - upperJoin.left, 2, context)
-            XCTAssertEqual((lowerJoin.right - upperJoin.right) - (lowerJoin.left - upperJoin.left), trim, accuracy: 0.1, context)
+            XCTAssertGreaterThan(lowerJoin.right - upperJoin.right, 2, context)
 
             let feedback = try XCTUnwrap(card.subviews.compactMap { $0 as? HomeButton }.first)
             XCTAssertEqual(feedback.style, .feedbackLink, context)
@@ -55,20 +74,22 @@ final class HomeContactPanelLayerTests: XCTestCase {
                 return try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
             }
 
-            let upperOnly = center(of: upper, at: (upper.minY + lower.minY) / 2)
+            let upperOnlyY = upper.minY + upper.height / 4
+            let anchoredLeft = edges(of: upper, at: upperOnlyY).left
+            let upperOnly = NSPoint(x: (anchoredLeft + edges(of: lower, at: upperOnlyY).left) / 2, y: upperOnlyY)
             XCTAssertGreaterThan(try alpha(at: upperOnly), 0.55, context)
-            let anchoredLeft = edges(of: upper, at: upperOnly.y).left
             XCTAssertLessThan(try alpha(at: NSPoint(x: anchoredLeft - 3, y: upperOnly.y)), 0.10, context)
             XCTAssertGreaterThan(try alpha(at: NSPoint(x: anchoredLeft + 3, y: upperOnly.y)), 0.90, context)
 
-            // 采样点落在原先被上板覆盖的位置，收短右缘后应看见下板渐变。
-            func newlyExposedLowerPlate(at fraction: CGFloat) -> NSPoint {
+            // 采样点落在重叠区仅属于下板的右边，核对同顶后仍保有渐隐。
+            func lowerRight(at fraction: CGFloat) -> NSPoint {
                 let y = lower.minY + overlap * fraction
-                return NSPoint(x: edges(of: upper, at: y).right + trim / 2, y: y)
+                let right = (edges(of: upper, at: y).right + edges(of: lower, at: y).right) / 2
+                return NSPoint(x: right, y: y)
             }
-            let beginningPoint = newlyExposedLowerPlate(at: 0.12)
+            let beginningPoint = lowerRight(at: 0.12)
             let beginning = try alpha(at: beginningPoint)
-            let nearJoin = try alpha(at: newlyExposedLowerPlate(at: 0.88))
+            let nearJoin = try alpha(at: lowerRight(at: 0.88))
             let stillCovered = NSPoint(x: edges(of: upper, at: beginningPoint.y).right - 3, y: beginningPoint.y)
             XCTAssertGreaterThan(try alpha(at: stillCovered), 0.90, context)
             let bottomY = upper.maxY + (lower.maxY - upper.maxY) * 0.75
@@ -87,7 +108,8 @@ final class HomeContactPanelLayerTests: XCTestCase {
             XCTAssertEqual(opened?.absoluteString, "https://github.com/LeP-Ton/eliminate-teris-1/issues", context)
 
             let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
-            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-layered-\(Int(size.width)).png")
+            let label = keepsRightEdgeInBounds ? "\(Int(size.width))x\(Int(size.height))" : "\(Int(size.width))"
+            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-layered-\(label).png")
             try png.write(to: preview)
         }
     }
@@ -97,11 +119,6 @@ final class HomeContactPanelLayerTests: XCTestCase {
          plate.maxX - HomeDashboardStyle.edgeOffset(for: y - plate.minY))
     }
 
-    private func center(of plate: NSRect, at y: CGFloat) -> NSPoint {
-        let edge = edges(of: plate, at: y)
-        return NSPoint(x: (edge.left + edge.right) / 2, y: y)
-    }
-
     private func render(_ view: NSView) throws -> NSBitmapImageRep {
         view.needsDisplay = true
         let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
```
