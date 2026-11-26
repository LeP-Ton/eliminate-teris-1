# 联系我们卡片的凸出图标前层

## 背景与目标

- 将首页的「联系我们」做成两层，消息图标位于左上凸出的斜面。标题、说明和反馈按钮位于主卡。

## 实现

- 联系卡与游戏模式卡共用图标前层的斜率、比例、深蓝渐变、上沿高光和右下侧沿。
- 联系卡前层按标题和说明区域的高度定尺寸，主卡下部留给反馈按钮，整体沿用右栏位置及底部对齐。

## 验证

- 在 302 × 110 和 500 × 148 点的原生联系卡上采样上沿和图标，验证前层确实凸出、消息图标可见、反馈按钮在主卡内且避开前层。
- 检查不同尺寸的大厅原生截图、五语言首页布局及反馈链接。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动核对可运行 `./run.sh`，缩放大厅，查看右栏联系卡和模式卡的层次，并测试反馈按钮。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 0dc75abd3f0fb6212865f1f33d67869147b9052f..eda819fd074349f8bd55adae15b98867b151743e 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261125085410-layer-contact-card-icon.md` - 会话-63 起让「联系我们」沿用游戏模式卡的凸出图标前层，含紧凑与标准窗口的原生回归。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
 `workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
@@ -110,6 +111,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整「联系我们」的前层、消息图标、反馈按钮与主卡间距时，读取 `20261125085410-layer-contact-card-icon.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
 - 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
diff --git a/Sources/HomeDashboardStyle.swift b/Sources/HomeDashboardStyle.swift
index f03ad9ea13996d7980dbbeb7a3e7734484e712e2..7ce9e774087c957517b4d03d299938b9398bda09 100644
--- a/Sources/HomeDashboardStyle.swift
+++ b/Sources/HomeDashboardStyle.swift
@@ -13,6 +13,7 @@ enum HomeDashboardStyle {
     // 以每点垂直距离对应的水平偏移定义斜边，组件尺寸变化时角度保持一致。
     static let slope: CGFloat = 0.45
     static let letterSlant: CGFloat = 0.19
+    static let iconPlateClearance: CGFloat = 8
 
     static func color(_ rgb: UInt32) -> NSColor {
         NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
@@ -70,6 +71,42 @@ enum HomeDashboardStyle {
         face.stroke()
     }
 
+    static func iconPlate(in face: NSRect) -> NSRect {
+        let height = face.height * 0.77
+        let width = face.height * 0.76 + edgeOffset(for: height)
+        let rise = min(iconPlateClearance - 1, face.height * 0.13)
+        return NSRect(x: face.minX + 1.5, y: face.minY - rise, width: width, height: height)
+    }
+
+    static func centeredIcon(in plate: NSRect) -> NSRect {
+        let size = min(44, plate.height * 0.64)
+        return NSRect(x: plate.midX - size / 2, y: plate.midY - size / 2, width: size, height: size)
+    }
+
+    static func drawIconPlate(_ plate: NSRect, tint: CGFloat = 0) {
+        guard plate.width > 0, plate.height > 0 else { return }
+        let depth = min(3.5, plate.height * 0.07)
+        let side = color(0x09151E)
+        let activeSide = color(0x12424B)
+        (side.blended(withFraction: tint, of: activeSide) ?? side).setFill()
+        slant(plate.offsetBy(dx: depth, dy: depth)).fill()
+
+        let upper = color(0x354858)
+        let lower = color(0x162631)
+        let edge = color(0x617889)
+        surface(plate, colors: [upper.blended(withFraction: tint, of: color(0x236570)) ?? upper,
+                                lower.blended(withFraction: tint, of: color(0x0D303A)) ?? lower],
+                border: edge.blended(withFraction: tint * 0.72, of: cyan) ?? edge)
+
+        // 只提亮前层受光的一段上沿，让下沿的侧面保有厚度。
+        let cut = edgeOffset(for: plate.height)
+        let light = color(0xB4D3E8).blended(withFraction: tint * 0.55, of: cyan) ?? cyan
+        let highlight = NSRect(x: plate.minX + cut + 1.3, y: plate.minY + 1,
+                               width: (plate.width - cut) * 0.81, height: 1)
+        NSGradient(starting: light.withAlphaComponent(0.78), ending: light.withAlphaComponent(0))?
+            .draw(in: highlight, angle: 0)
+    }
+
     static func line(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat = 1) {
         let path = NSBezierPath()
         path.move(to: start)
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 8e4719d718e2788a193be20a84d9e820268e9861..e763e22bf18b1536a14be3c074c059b4dc951cdd 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -100,8 +100,6 @@ class HomeButton: NSButton {
 }
 
 final class HomeModeButton: HomeButton {
-    static let iconPlateClearance: CGFloat = 8
-
     // 解谜暂时只是大厅入口，没有可交给棋盘控制器的游戏模式。
     let mode: HomeGameMode?
     private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
@@ -121,23 +119,13 @@ final class HomeModeButton: HomeButton {
     var faceRect: NSRect {
         let effect = feedback.values
         let inset = bounds.insetBy(dx: 1.2, dy: 1.2)
-        return NSRect(x: inset.minX, y: inset.minY + Self.iconPlateClearance + effect.press * 1.4 - effect.hover,
-                      width: inset.width, height: max(0, inset.height - Self.iconPlateClearance))
+        let clearance = HomeDashboardStyle.iconPlateClearance
+        return NSRect(x: inset.minX, y: inset.minY + clearance + effect.press * 1.4 - effect.hover,
+                      width: inset.width, height: max(0, inset.height - clearance))
     }
 
-    var iconPlateRect: NSRect {
-        let face = faceRect
-        let height = face.height * 0.77
-        let width = face.height * 0.76 + HomeDashboardStyle.edgeOffset(for: height)
-        let rise = min(Self.iconPlateClearance - 1, face.height * 0.13)
-        return NSRect(x: face.minX + 1.5, y: face.minY - rise, width: width, height: height)
-    }
-
-    var modeIconRect: NSRect {
-        let plate = iconPlateRect
-        let size = min(44, plate.height * 0.64)
-        return NSRect(x: plate.midX - size / 2, y: plate.midY - size / 2, width: size, height: size)
-    }
+    var iconPlateRect: NSRect { HomeDashboardStyle.iconPlate(in: faceRect) }
+    var modeIconRect: NSRect { HomeDashboardStyle.centeredIcon(in: iconPlateRect) }
 
     override var focusRingMaskBounds: NSRect { faceRect.union(iconPlateRect) }
 
@@ -167,7 +155,7 @@ final class HomeModeButton: HomeButton {
         let stroke = HomeDashboardStyle.border.blended(withFraction: tint, of: cyan) ?? cyan
         HomeDashboardStyle.surface(face, colors: colors, border: stroke,
                                    lineWidth: 1 + 1.7 * effect.selection)
-        drawIconPlate(iconPlateRect, tint: tint)
+        HomeDashboardStyle.drawIconPlate(iconPlateRect, tint: tint)
         drawModeIcon(in: modeIconRect, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
         let textX = face.minX + face.height * 0.83 + min(48, face.height * 0.56) + 13
         let textWidth = face.maxX - textX - max(31, face.height * 0.67)
@@ -191,31 +179,6 @@ final class HomeModeButton: HomeButton {
         }
     }
 
-    private func drawIconPlate(_ plate: NSRect, tint: CGFloat) {
-        let depth = min(3.5, plate.height * 0.07)
-        let side = HomeDashboardStyle.color(0x09151E)
-        let activeSide = HomeDashboardStyle.color(0x12424B)
-        (side.blended(withFraction: tint, of: activeSide) ?? side).setFill()
-        HomeDashboardStyle.slant(plate.offsetBy(dx: depth, dy: depth)).fill()
-
-        let upper = HomeDashboardStyle.color(0x354858)
-        let lower = HomeDashboardStyle.color(0x162631)
-        let edge = HomeDashboardStyle.color(0x617889)
-        let cyan = HomeDashboardStyle.cyan
-        HomeDashboardStyle.surface(plate,
-                                   colors: [upper.blended(withFraction: tint, of: HomeDashboardStyle.color(0x236570)) ?? upper,
-                                            lower.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0D303A)) ?? lower],
-                                   border: edge.blended(withFraction: tint * 0.72, of: cyan) ?? edge)
-
-        // 只提亮前层受光的一段上沿，让下沿的侧面保有厚度。
-        let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
-        let light = HomeDashboardStyle.color(0xB4D3E8).blended(withFraction: tint * 0.55, of: cyan) ?? cyan
-        let highlight = NSRect(x: plate.minX + cut + 1.3, y: plate.minY + 1,
-                               width: (plate.width - cut) * 0.81, height: 1)
-        NSGradient(starting: light.withAlphaComponent(0.78), ending: light.withAlphaComponent(0))?
-            .draw(in: highlight, angle: 0)
-    }
-
     private func drawModeIcon(in rect: NSRect, color: NSColor) {
         switch mode {
         case .free:
@@ -688,7 +651,7 @@ final class HomeDashboardView: NSView {
                             width: hint.preferredMaxLayoutWidth, height: max(0, achievementTop - stageBottom - 10))
         achievementPath.frame = NSRect(x: margin, y: achievementTop, width: bounds.width - margin * 2,
                                        height: max(0, bounds.height - achievementTop - min(30, bounds.height * 0.031)))
-        let frontClearance = HomeModeButton.iconPlateClearance
+        let frontClearance = HomeDashboardStyle.iconPlateClearance
         let rowGap = min(13, max(frontClearance + 1, bounds.height * 0.012))
         let firstRowY: CGFloat = modePanel.isCompact ? 49 : 57
         let rowHeight = max(0, panel.height - firstRowY - 4 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
@@ -823,6 +786,21 @@ final class HomeContactPanelView: NSView {
 
     override var isFlipped: Bool { true }
 
+    var faceRect: NSRect {
+        let clearance = HomeDashboardStyle.iconPlateClearance
+        return NSRect(x: bounds.minX, y: bounds.minY + clearance, width: bounds.width,
+                      height: max(0, bounds.height - clearance))
+    }
+
+    var iconPlateRect: NSRect {
+        // 前层按标题和说明这部分的高度定尺寸，给下方反馈按钮留出空间。
+        var heading = faceRect
+        heading.size.height = min(90, heading.height * 0.72)
+        return HomeDashboardStyle.iconPlate(in: heading)
+    }
+
+    var contactIconRect: NSRect { HomeDashboardStyle.centeredIcon(in: iconPlateRect) }
+
     override init(frame: NSRect) {
         super.init(frame: frame)
         feedback.symbolName = "arrow.up.right"
@@ -846,31 +824,33 @@ final class HomeContactPanelView: NSView {
 
     override func layout() {
         super.layout()
+        let face = faceRect
         let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
-        let width = min(max(0, bounds.width - 84), max(bounds.width * 0.52, ceil(titleWidth) + 67))
-        let height = min(47, bounds.height * 0.31)
-        feedback.frame = NSRect(x: bounds.height * 0.38 + 12, y: bounds.height - height - bounds.height * 0.12,
+        let width = min(max(0, face.width - 84), max(face.width * 0.52, ceil(titleWidth) + 67))
+        let height = min(47, face.height * 0.31)
+        feedback.frame = NSRect(x: face.minX + face.height * 0.38 + 12, y: face.maxY - height - face.height * 0.12,
                                 width: width, height: height)
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        let cut = HomeDashboardStyle.edgeOffset(for: bounds.height)
-        HomeDashboardStyle.surface(bounds, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
+        let face = faceRect
+        let plate = iconPlateRect
+        let cut = HomeDashboardStyle.edgeOffset(for: face.height)
+        HomeDashboardStyle.surface(face, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
                                    border: HomeDashboardStyle.color(0x344C65))
-        let size = min(43, bounds.height * 0.29)
-        let icon = NSRect(x: cut + 11, y: bounds.height * 0.145, width: size, height: size)
-        HomeStyle.symbol("ellipsis.bubble", in: icon, color: HomeDashboardStyle.ink)
-        let textX = icon.maxX + 13
-        let textWidth = max(0, bounds.width - textX - cut * 0.69)
+        HomeDashboardStyle.drawIconPlate(plate)
+        HomeStyle.symbol("ellipsis.bubble", in: contactIconRect, color: HomeDashboardStyle.ink)
+        let textX = max(plate.maxX + 16, face.minX + cut + 11)
+        let textWidth = max(0, face.maxX - textX - cut * 0.69)
         let title = AchievementText.string("home.contact.title")
-        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, bounds.height * 0.18),
+        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, face.height * 0.18),
                                                  minimum: 13, weight: .heavy)
-        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: bounds.height * 0.067, width: textWidth, height: 35),
+        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: face.minY + face.height * 0.055, width: textWidth, height: 35),
                                 size: titleSize, weight: .heavy)
         let description = AchievementText.string("home.contact.description")
-        let descriptionY = bounds.height * 0.325
+        let descriptionY = face.minY + face.height * 0.31
         HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY, width: textWidth,
                                                                height: feedback.frame.minY - descriptionY - 4),
-                                       preferred: min(17, bounds.height * 0.12))
+                                       preferred: min(17, face.height * 0.12))
     }
 }
diff --git a/Tests/HomeModeButtonArtworkTests.swift b/Tests/HomeModeButtonArtworkTests.swift
index 6aa42cb2e1219c5a6ae08e32022ef01d0d8f53c4..bbd7dc2c8b7a292d2c25211d4196f7284f9faa6c 100644
--- a/Tests/HomeModeButtonArtworkTests.swift
+++ b/Tests/HomeModeButtonArtworkTests.swift
@@ -19,6 +19,27 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         }
     }
 
+    func testContactIconUsesTheRaisedPlateAndFeedbackStaysOnTheMainCard() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        for size in [NSSize(width: 302, height: 110), NSSize(width: 500, height: 148)] {
+            let contact = HomeContactPanelView(frame: NSRect(origin: .zero, size: size))
+            contact.layoutSubtreeIfNeeded()
+            let feedback = try XCTUnwrap(contact.subviews.compactMap { $0 as? HomeButton }.first)
+            let face = contact.faceRect
+            let plate = contact.iconPlateRect
+            let context = "联系我们／\(size.width)×\(size.height)"
+            XCTAssertTrue(face.contains(feedback.frame), context)
+            XCTAssertFalse(plate.intersects(feedback.frame), context)
+
+            let png = try assertRaisedPlate(in: contact, face: face, plate: plate, icon: contact.contactIconRect, context: context)
+            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-icon-plate-\(Int(size.width)).png")
+            try png.write(to: preview)
+        }
+    }
+
     func testExportModeIconPlatePreview() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
@@ -55,19 +76,21 @@ final class HomeModeButtonArtworkTests: XCTestCase {
     }
 
     private func assertRaisedPlate(on button: HomeModeButton) throws -> Data {
-        let face = button.faceRect
-        let plate = button.iconPlateRect
-        let icon = button.modeIconRect
         let context = "\(button.mode?.key ?? "解谜")／\(button.bounds.width)／\(button.selected ? "选中" : "默认")"
+        return try assertRaisedPlate(in: button, face: button.faceRect, plate: button.iconPlateRect, icon: button.modeIconRect,
+                                     context: context)
+    }
+
+    private func assertRaisedPlate(in view: NSView, face: NSRect, plate: NSRect, icon: NSRect, context: String) throws -> Data {
         XCTAssertGreaterThan(face.minY - plate.minY, 2, context)
         XCTAssertGreaterThan(plate.maxY, face.minY, context)
         XCTAssertLessThan(plate.midX, face.midX, context)
-        XCTAssertTrue(button.bounds.contains(plate), context)
+        XCTAssertTrue(view.bounds.contains(plate), context)
         XCTAssertTrue(plate.contains(icon), context)
 
-        let bitmap = try bitmap(of: button)
-        let xScale = CGFloat(bitmap.pixelsWide) / button.bounds.width
-        let yScale = CGFloat(bitmap.pixelsHigh) / button.bounds.height
+        let bitmap = try bitmap(of: view)
+        let xScale = CGFloat(bitmap.pixelsWide) / view.bounds.width
+        let yScale = CGFloat(bitmap.pixelsHigh) / view.bounds.height
         func color(at point: NSPoint) throws -> NSColor {
             try XCTUnwrap(bitmap.colorAt(x: Int(point.x * xScale), y: Int(point.y * yScale))?.usingColorSpace(.sRGB))
         }
```
