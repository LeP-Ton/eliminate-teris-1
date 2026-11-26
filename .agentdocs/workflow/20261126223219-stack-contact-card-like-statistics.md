# 将联系我们改为左上与右下的两块斜板

## 背景与目标

- 在 `experiment/ui-refactor-v2` 上，将首页联系卡按规则与消除统计卡的形态重做成两块错位叠放的宽斜板。
- 消息图标、标题和说明在左上板，GitHub 反馈按钮在右下板的露出区域。

## 实现

- 两板共用大厅斜率，水平净宽相同。重叠约为联系卡高度的 12%，在同一测量高度下两侧错位等距。
- 上板和下板采用两段深色渐变及各自的描边，右下板的边缘露在上板右侧。
- 反馈按钮按下板的实际斜边布局，保留原有原生链接和右栏整体占位。

## 验证

- 在 302 × 110 与 500 × 148 点渲染原生联系卡，检查两板独占区域和右侧阶梯的像素，并在同一高度测量两侧错位。
- 验证反馈按钮位于下板的斜边范围内、避开上板，激活按钮时仍打开项目问题跟踪页。
- 检查标准大厅和俄语紧凑大厅的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动验证可运行 `./run.sh`，缩放窗口，查看左上说明板、右下反馈板，以及它们在右侧露出的错位。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 0dc75abd3f0fb6212865f1f33d67869147b9052f..204dab078fc92243a44b4851ad616215a61f7f0b 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126223219-stack-contact-card-like-statistics.md` - 会话-79 起将当前分支的「联系我们」拆成错位叠放的左上说明板和右下反馈板，沿用规则统计卡的斜边关系。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
 `workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
@@ -110,6 +111,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整「联系我们」的左上说明板、右下反馈板、重叠区域或反馈按钮定位时，读取 `20261126223219-stack-contact-card-like-statistics.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
 - 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 8e4719d718e2788a193be20a84d9e820268e9861..2ac23e3861b010103e502c7f41c5ecbc0cb68a75 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -823,6 +823,20 @@ final class HomeContactPanelView: NSView {
 
     override var isFlipped: Bool { true }
 
+    var upperPlateRect: NSRect {
+        let lower = lowerPlateRect
+        let height = bounds.height * 0.63
+        // 两层在水平截面上等宽，左上和右下的错位沿用同一斜角。
+        let width = lower.width + HomeDashboardStyle.edgeOffset(for: height - lower.height)
+        return NSRect(x: bounds.minX, y: bounds.minY, width: width, height: height)
+    }
+
+    var lowerPlateRect: NSRect {
+        let height = bounds.height * 0.49
+        let offset = min(bounds.width, bounds.height * 0.11)
+        return NSRect(x: bounds.minX + offset, y: bounds.maxY - height, width: bounds.width - offset, height: height)
+    }
+
     override init(frame: NSRect) {
         super.init(frame: frame)
         feedback.symbolName = "arrow.up.right"
@@ -846,31 +860,43 @@ final class HomeContactPanelView: NSView {
 
     override func layout() {
         super.layout()
+        let lower = lowerPlateRect
+        // 反馈按钮在下板露出的区域内，四周留白沿真实斜边计算。
+        let top = upperPlateRect.maxY + 4
+        let availableHeight = max(0, lower.maxY - top - 5)
+        let height = min(43, availableHeight)
+        let y = top + (availableHeight - height) / 2
+        let left = lower.minX + HomeDashboardStyle.edgeOffset(for: lower.maxY - y) + 12
+        let right = lower.maxX - HomeDashboardStyle.edgeOffset(for: y - lower.minY) - 12
         let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
-        let width = min(max(0, bounds.width - 84), max(bounds.width * 0.52, ceil(titleWidth) + 67))
-        let height = min(47, bounds.height * 0.31)
-        feedback.frame = NSRect(x: bounds.height * 0.38 + 12, y: bounds.height - height - bounds.height * 0.12,
-                                width: width, height: height)
+        let width = min(max(0, right - left), max(lower.width * 0.54, ceil(titleWidth) + 67))
+        feedback.frame = NSRect(x: right - width, y: y, width: width, height: height)
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        let cut = HomeDashboardStyle.edgeOffset(for: bounds.height)
-        HomeDashboardStyle.surface(bounds, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
-                                   border: HomeDashboardStyle.color(0x344C65))
-        let size = min(43, bounds.height * 0.29)
-        let icon = NSRect(x: cut + 11, y: bounds.height * 0.145, width: size, height: size)
+        let upper = upperPlateRect
+        HomeDashboardStyle.surface(lowerPlateRect, colors: [HomeDashboardStyle.color(0x192734), HomeDashboardStyle.color(0x101A25)],
+                                   border: HomeDashboardStyle.color(0x52616D), lineWidth: 1.25)
+        HomeDashboardStyle.surface(upper, colors: [HomeDashboardStyle.color(0x203547), HomeDashboardStyle.color(0x142232)],
+                                   border: HomeDashboardStyle.color(0x586D7F), lineWidth: 1.25)
+
+        let size = min(43, upper.height * 0.54)
+        let iconY = upper.midY - size / 2
+        let iconX = upper.minX + HomeDashboardStyle.edgeOffset(for: upper.maxY - iconY) + 9
+        let icon = NSRect(x: iconX, y: iconY, width: size, height: size)
         HomeStyle.symbol("ellipsis.bubble", in: icon, color: HomeDashboardStyle.ink)
         let textX = icon.maxX + 13
-        let textWidth = max(0, bounds.width - textX - cut * 0.69)
+        let textWidth = max(0, upper.maxX - textX - HomeDashboardStyle.edgeOffset(for: upper.height) - 12)
         let title = AchievementText.string("home.contact.title")
-        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, bounds.height * 0.18),
+        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, upper.height * 0.31),
                                                  minimum: 13, weight: .heavy)
-        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: bounds.height * 0.067, width: textWidth, height: 35),
+        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: upper.minY + upper.height * 0.13,
+                                                  width: textWidth, height: min(35, upper.height * 0.48)),
                                 size: titleSize, weight: .heavy)
         let description = AchievementText.string("home.contact.description")
-        let descriptionY = bounds.height * 0.325
+        let descriptionY = upper.minY + upper.height * 0.48
         HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY, width: textWidth,
-                                                               height: feedback.frame.minY - descriptionY - 4),
+                                                               height: upper.maxY - descriptionY - 8),
                                        preferred: min(17, bounds.height * 0.12))
     }
 }
diff --git a/Tests/HomeContactPanelLayerTests.swift b/Tests/HomeContactPanelLayerTests.swift
new file mode 100644
index 0000000000000000000000000000000000000000..20d8d6b474cf88b8d4fe92ca104d25e590e99eb9
--- /dev/null
+++ b/Tests/HomeContactPanelLayerTests.swift
@@ -0,0 +1,86 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class HomeContactPanelLayerTests: XCTestCase {
+    func testContactRendersTwoOffsetPlatesAndKeepsTheFeedbackLink() throws {
+        _ = NSApplication.shared
+        let language = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(language) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+
+        for size in [NSSize(width: 302, height: 110), NSSize(width: 500, height: 148)] {
+            let card = HomeContactPanelView(frame: NSRect(origin: .zero, size: size))
+            card.layoutSubtreeIfNeeded()
+            let upper = card.upperPlateRect
+            let lower = card.lowerPlateRect
+            let context = "联系我们／\(size.width)×\(size.height)"
+            XCTAssertTrue(card.bounds.contains(upper), context)
+            XCTAssertTrue(card.bounds.contains(lower), context)
+            XCTAssertGreaterThan(lower.minY, upper.minY, context)
+            XCTAssertGreaterThan(lower.maxY, upper.maxY, context)
+            let overlap = upper.maxY - lower.minY
+            XCTAssertEqual(overlap / size.height, 0.12, accuracy: 0.035, context)
+
+            let joinY = lower.minY + overlap / 2
+            let upperJoin = edges(of: upper, at: joinY)
+            let lowerJoin = edges(of: lower, at: joinY)
+            XCTAssertGreaterThan(lowerJoin.left - upperJoin.left, 2, context)
+            XCTAssertEqual(lowerJoin.left - upperJoin.left, lowerJoin.right - upperJoin.right, accuracy: 0.1, context)
+
+            let feedback = try XCTUnwrap(card.subviews.compactMap { $0 as? HomeButton }.first)
+            XCTAssertTrue(lower.contains(feedback.frame), context)
+            XCTAssertGreaterThanOrEqual(feedback.frame.minY, upper.maxY - 0.1, context)
+            let face = HomeDashboardStyle.slant(lower)
+            let button = feedback.frame.insetBy(dx: 1.2, dy: 1.2)
+            for y in [button.minY + 0.5, button.maxY - 0.5] {
+                let edge = edges(of: button, at: y)
+                XCTAssertTrue(face.contains(NSPoint(x: edge.left + 0.5, y: y)), context)
+                XCTAssertTrue(face.contains(NSPoint(x: edge.right - 0.5, y: y)), context)
+            }
+
+            let bitmap = try XCTUnwrap(card.bitmapImageRepForCachingDisplay(in: card.bounds))
+            card.cacheDisplay(in: card.bounds, to: bitmap)
+            func alpha(at point: NSPoint) throws -> CGFloat {
+                let x = Int(point.x * CGFloat(bitmap.pixelsWide) / size.width)
+                let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / size.height)
+                return try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
+            }
+
+            let upperOnly = center(of: upper, at: (upper.minY + lower.minY) / 2)
+            let lowerOnly = center(of: lower, at: (upper.maxY + lower.maxY) / 2)
+            XCTAssertGreaterThan(try alpha(at: upperOnly), 0.55, context)
+            XCTAssertGreaterThan(try alpha(at: lowerOnly), 0.55, context)
+
+            // 在阶梯上下比较同一列像素，确认下板斜边实际露出在上板右侧。
+            let before = lower.minY - 2
+            let after = lower.minY + 2
+            let beforeRight = edges(of: upper, at: before).right
+            let afterRight = edges(of: lower, at: after).right
+            XCTAssertGreaterThan(afterRight - beforeRight, 2, context)
+            let stepX = (beforeRight + afterRight) / 2
+            let alphaAbove = try alpha(at: NSPoint(x: stepX, y: before))
+            let alphaBelow = try alpha(at: NSPoint(x: stepX, y: after))
+            XCTAssertGreaterThan(alphaBelow - alphaAbove, 0.35, context)
+
+            var opened: URL?
+            card.openURL = { opened = $0 }
+            feedback.performClick(nil)
+            XCTAssertEqual(opened?.absoluteString, "https://github.com/LeP-Ton/eliminate-teris-1/issues", context)
+
+            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-layered-\(Int(size.width)).png")
+            try png.write(to: preview)
+        }
+    }
+
+    private func edges(of plate: NSRect, at y: CGFloat) -> (left: CGFloat, right: CGFloat) {
+        (plate.minX + HomeDashboardStyle.edgeOffset(for: plate.maxY - y),
+         plate.maxX - HomeDashboardStyle.edgeOffset(for: y - plate.minY))
+    }
+
+    private func center(of plate: NSRect, at y: CGFloat) -> NSPoint {
+        let edge = edges(of: plate, at: y)
+        return NSPoint(x: (edge.left + edge.right) / 2, y: y)
+    }
+}
```
