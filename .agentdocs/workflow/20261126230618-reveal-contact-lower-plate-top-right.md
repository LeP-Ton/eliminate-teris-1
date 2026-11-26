# 收短联系卡上板右侧

## 背景与目标

- 保持联系卡上板沿原来的左斜边和纵向位置，只收短右侧。
- 让下板右上的渐隐区域露出更多，形成与规则统计卡呼应的错位。

## 实现

- 上板右缘按卡宽的 5% 向左收，最多 26 点。上板内容的可用宽度随新边缘计算。
- 下板的几何、渐隐和反馈按钮继续使用既有布局。

## 验证

- 在 302 × 110 及 500 × 148 点卡片检查上板左边缘及高度、下板坐标、右侧多出的错位和新露出区域的透明度。
- 检查标准和俄语紧凑大厅的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动验证可运行 `./run.sh`，缩放大厅并查看联系卡左侧、上板右缘以及露出的下板渐隐区域。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index e894004ed4045be8b0f0fe2a66a9504c734b3186..b91b3b2ac37bd4fbc2e5dda9ad7031e8a7dc7c19 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126230618-reveal-contact-lower-plate-top-right.md` - 会话-83 起缩短联系卡上板右缘，让下板右上渐隐斜面露出更多。
 `workflow/20261126224828-refine-contact-stack-overlap-and-fade.md` - 会话-81 起向交界延伸联系卡上下板，让下板右上渐隐，并将 GitHub 反馈改为无边框链接。
 `workflow/20261126223219-stack-contact-card-like-statistics.md` - 会话-79 起将当前分支的「联系我们」拆成错位叠放的左上说明板和右下反馈板，沿用规则统计卡的斜边关系。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
@@ -112,6 +113,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整联系卡上板右侧宽度或下板右上露出面积时，读取 `20261126230618-reveal-contact-lower-plate-top-right.md`。
 - 需要调整联系卡两块斜板的重叠、下板顶部透明度或反馈链接边框时，读取 `20261126224828-refine-contact-stack-overlap-and-fade.md`。
 - 需要调整「联系我们」的左上说明板、右下反馈板、重叠区域或反馈按钮定位时，读取 `20261126223219-stack-contact-card-like-statistics.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index c5fa1c254fb5b28c70c1f875e043211216f55075..b37f0f69633b1d0bbb3227c971541f1d14cee01e 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -834,8 +834,9 @@ final class HomeContactPanelView: NSView {
     var upperPlateRect: NSRect {
         let lower = lowerPlateRect
         let height = bounds.height * 0.70
-        // 两层在水平截面上等宽，左上和右下的错位沿用同一斜角。
-        let width = lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height)
+        // 只收窄右边，露出更宽的下板右上渐隐区域。
+        let rightTrim = min(26, bounds.width * 0.05)
+        let width = max(0, lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height) - rightTrim)
         return NSRect(x: bounds.minX, y: bounds.minY, width: width, height: height)
     }
 
diff --git a/Tests/HomeContactPanelLayerTests.swift b/Tests/HomeContactPanelLayerTests.swift
index e623434c33c6407f651cc013352bf86979500523..bc20bfd64d89977a69c4445058de6df84a8e3175 100644
--- a/Tests/HomeContactPanelLayerTests.swift
+++ b/Tests/HomeContactPanelLayerTests.swift
@@ -17,6 +17,11 @@ final class HomeContactPanelLayerTests: XCTestCase {
             let context = "联系我们／\(size.width)×\(size.height)"
             XCTAssertTrue(card.bounds.contains(upper), context)
             XCTAssertTrue(card.bounds.contains(lower), context)
+            XCTAssertEqual(upper.minX, card.bounds.minX, accuracy: 0.01, context)
+            XCTAssertEqual(upper.minY, card.bounds.minY, accuracy: 0.01, context)
+            XCTAssertEqual(lower.minX, card.bounds.minX + size.height * 0.11, accuracy: 0.01, context)
+            XCTAssertEqual(lower.maxX, card.bounds.maxX, accuracy: 0.01, context)
+            XCTAssertEqual(lower.maxY, card.bounds.maxY, accuracy: 0.01, context)
             XCTAssertGreaterThan(lower.minY, upper.minY, context)
             XCTAssertGreaterThan(lower.maxY, upper.maxY, context)
             XCTAssertEqual(upper.height / size.height, 0.70, accuracy: 0.01, context)
@@ -27,8 +32,9 @@ final class HomeContactPanelLayerTests: XCTestCase {
             let joinY = lower.minY + overlap / 2
             let upperJoin = edges(of: upper, at: joinY)
             let lowerJoin = edges(of: lower, at: joinY)
+            let trim = min(26, size.width * 0.05)
             XCTAssertGreaterThan(lowerJoin.left - upperJoin.left, 2, context)
-            XCTAssertEqual(lowerJoin.left - upperJoin.left, lowerJoin.right - upperJoin.right, accuracy: 0.1, context)
+            XCTAssertEqual((lowerJoin.right - upperJoin.right) - (lowerJoin.left - upperJoin.left), trim, accuracy: 0.1, context)
 
             let feedback = try XCTUnwrap(card.subviews.compactMap { $0 as? HomeButton }.first)
             XCTAssertEqual(feedback.style, .feedbackLink, context)
@@ -51,15 +57,20 @@ final class HomeContactPanelLayerTests: XCTestCase {
 
             let upperOnly = center(of: upper, at: (upper.minY + lower.minY) / 2)
             XCTAssertGreaterThan(try alpha(at: upperOnly), 0.55, context)
+            let anchoredLeft = edges(of: upper, at: upperOnly.y).left
+            XCTAssertLessThan(try alpha(at: NSPoint(x: anchoredLeft - 3, y: upperOnly.y)), 0.10, context)
+            XCTAssertGreaterThan(try alpha(at: NSPoint(x: anchoredLeft + 3, y: upperOnly.y)), 0.90, context)
 
-            // 在重叠区右侧只采下板，分别核对渐变的起始、交界和下段。
-            func lowerRight(at fraction: CGFloat) -> NSPoint {
+            // 采样点落在原先被上板覆盖的位置，收短右缘后应看见下板渐变。
+            func newlyExposedLowerPlate(at fraction: CGFloat) -> NSPoint {
                 let y = lower.minY + overlap * fraction
-                let x = (edges(of: upper, at: y).right + edges(of: lower, at: y).right) / 2
-                return NSPoint(x: x, y: y)
+                return NSPoint(x: edges(of: upper, at: y).right + trim / 2, y: y)
             }
-            let beginning = try alpha(at: lowerRight(at: 0.12))
-            let nearJoin = try alpha(at: lowerRight(at: 0.88))
+            let beginningPoint = newlyExposedLowerPlate(at: 0.12)
+            let beginning = try alpha(at: beginningPoint)
+            let nearJoin = try alpha(at: newlyExposedLowerPlate(at: 0.88))
+            let stillCovered = NSPoint(x: edges(of: upper, at: beginningPoint.y).right - 3, y: beginningPoint.y)
+            XCTAssertGreaterThan(try alpha(at: stillCovered), 0.90, context)
             let bottomY = upper.maxY + (lower.maxY - upper.maxY) * 0.75
             let bottom = NSPoint(x: edges(of: lower, at: bottomY).left + 18, y: bottomY)
             let lowerAlpha = try alpha(at: bottom)
```
