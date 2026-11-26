# 对齐联系卡图标并凸出右下反馈按钮

## 背景与目标

- 截图中联系卡图标前层比上方限步模式偏左。让两者的图标中心在同一竖线上。
- 将「在 GitHub 反馈」放在联系卡右下，使用与图标前层相同的斜面材质和侧沿。

## 实现

- 大厅布局使用最下方模式卡的图标中心定位联系卡图标。标题和说明随图标留出间距，联系卡在独立预览中也采用右移位置。
- 反馈按钮的前层按主卡同高度的右斜边定位，跨过主卡的右下沿。按钮的外框为阴影和按压位移留出空间，焦点轮廓贴合实际前层。
- 主卡外部占位维持与开始按钮底部对齐。原生反馈按钮仍通过现有入口打开问题跟踪页。

## 验证

- 核对两种大厅尺寸下限步卡和联系卡图标中心对齐。
- 在 302 × 110 及 500 × 148 点联系卡上检查右侧和下方凸出像素、图标与文字可见，以及两个前层的间距。
- 实看标准大厅及俄语紧凑大厅的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 106 项，全部通过。
- 手动验证可运行 `./run.sh`，缩放窗口后查看右栏图标对齐和右下反馈前层，再点击反馈按钮。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index eda819fd074349f8bd55adae15b98867b151743e..678986792c0f53ed1c499fef4137fab914bc28ea 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261125091517-align-contact-icon-and-raise-feedback.md` - 会话-65 起把联系卡图标前层向右对齐限步卡图标，并将 GitHub 反馈按钮放到主卡右下的凸出前层。
 `workflow/20261125085410-layer-contact-card-icon.md` - 会话-63 起让「联系我们」沿用游戏模式卡的凸出图标前层，含紧凑与标准窗口的原生回归。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
@@ -111,6 +112,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整联系卡图标对齐、右下反馈前层或按钮焦点轮廓时，读取 `20261125091517-align-contact-icon-and-raise-feedback.md`。
 - 需要调整「联系我们」的前层、消息图标、反馈按钮与主卡间距时，读取 `20261125085410-layer-contact-card-icon.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index e763e22bf18b1536a14be3c074c059b4dc951cdd..a0994cda23bb46c1307bf5a9f734ab45515c9a54 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -3,7 +3,7 @@ import CoreText
 
 /// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
 class HomeButton: NSButton {
-    enum Style { case navigation, primary, outline, achievementLink }
+    enum Style { case navigation, primary, achievementLink, raisedFeedback }
     var style: Style = .navigation
     var symbolName: String?
     var onClick: (() -> Void)?
@@ -22,9 +22,9 @@ class HomeButton: NSButton {
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
     override var isHighlighted: Bool { didSet { refreshFeedback() } }
-    override var focusRingMaskBounds: NSRect { bounds }
+    override var focusRingMaskBounds: NSRect { style == .raisedFeedback ? buttonSurfaceRect : bounds }
     override func drawFocusRingMask() {
-        HomeDashboardStyle.slant(bounds).fill()
+        HomeDashboardStyle.slant(focusRingMaskBounds).fill()
     }
     override func resetCursorRects() {
         if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
@@ -46,12 +46,23 @@ class HomeButton: NSButton {
         needsDisplay = true
     }
 
-    override func draw(_ dirtyRect: NSRect) {
+    var buttonSurfaceRect: NSRect {
         let effect = feedback.values
         let offset = effect.press * 1.8 - effect.hover
-        let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
+        var face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
+        if style == .raisedFeedback {
+            // 右下侧沿和按下时的位移都画在原生按钮边界内。
+            face.size.width = max(0, face.width - 4)
+            face.size.height = max(0, face.height - 5.5)
+        }
+        return face
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        let effect = feedback.values
+        let face = buttonSurfaceRect
         let primary = style == .primary
-        let outlined = style == .outline
+        let raisedFeedback = style == .raisedFeedback
         let color = primary ? HomeDashboardStyle.navy : HomeDashboardStyle.ink
         if primary {
             let yellow = HomeDashboardStyle.yellow
@@ -70,23 +81,25 @@ class HomeButton: NSButton {
                 HomeDashboardStyle.navy.withAlphaComponent(0.36).setFill()
                 HomeDashboardStyle.slant(face).fill()
             }
-        } else if outlined || effect.hover > 0 {
+        } else if raisedFeedback {
+            HomeDashboardStyle.drawIconPlate(face, tint: 0.75 + effect.hover * 0.2 - effect.press * 0.08)
+        } else if effect.hover > 0 {
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
-        let size = GameLobbyStyle.fittedSize(label, width: bounds.width - icon - gap - (primary ? 52 : 24),
+        let content = raisedFeedback ? face : bounds
+        let preferred = primary ? min(34, content.height * 0.52) : min(19, content.height * 0.44)
+        let size = GameLobbyStyle.fittedSize(label, width: content.width - icon - gap - (primary ? 52 : 24),
                                              preferred: preferred, minimum: 10, weight: weight)
         let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
-        let x = (bounds.width - width - icon - gap) / 2
+        let x = content.minX + (content.width - width - icon - gap) / 2
         if let symbolName {
             let iconX = style == .achievementLink ? x + width + gap : x
             let iconColor = style == .achievementLink ? HomeDashboardStyle.yellow : color
@@ -661,6 +674,10 @@ final class HomeDashboardView: NSView {
             button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap) - frontClearance,
                                   width: max(0, panel.width - 15), height: rowHeight + frontClearance)
         }
+        if let bottomMode = modes.last {
+            let icon = bottomMode.modeIconRect
+            contactPanel.iconCenterX = bottomMode.convert(NSPoint(x: icon.midX, y: icon.midY), to: contactPanel).x
+        }
         var navX = bounds.width - margin + 5
         for button in [settings, rules, records] {
             let width = max(89, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width + 27)
@@ -781,30 +798,35 @@ final class HomeModePanelView: NSView {
 /// 反馈按钮打开项目的问题跟踪页。
 final class HomeContactPanelView: NSView {
     private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
+    private static let feedbackClearance: CGFloat = 11
     private let feedback = HomeButton(frame: .zero)
     var openURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }
+    var iconCenterX: CGFloat? { didSet { if oldValue != iconCenterX { needsDisplay = true } } }
 
     override var isFlipped: Bool { true }
 
     var faceRect: NSRect {
         let clearance = HomeDashboardStyle.iconPlateClearance
         return NSRect(x: bounds.minX, y: bounds.minY + clearance, width: bounds.width,
-                      height: max(0, bounds.height - clearance))
+                      height: max(0, bounds.height - clearance - Self.feedbackClearance))
     }
 
     var iconPlateRect: NSRect {
         // 前层按标题和说明这部分的高度定尺寸，给下方反馈按钮留出空间。
         var heading = faceRect
-        heading.size.height = min(90, heading.height * 0.72)
-        return HomeDashboardStyle.iconPlate(in: heading)
+        heading.size.height = min(90, (heading.height + Self.feedbackClearance) * 0.72)
+        let plate = HomeDashboardStyle.iconPlate(in: heading)
+        let center = iconCenterX ?? plate.midX + min(25, heading.width * 0.07)
+        return plate.offsetBy(dx: center - plate.midX, dy: 0)
     }
 
     var contactIconRect: NSRect { HomeDashboardStyle.centeredIcon(in: iconPlateRect) }
+    var feedbackPlateRect: NSRect { feedback.convert(feedback.buttonSurfaceRect, to: self) }
 
     override init(frame: NSRect) {
         super.init(frame: frame)
         feedback.symbolName = "arrow.up.right"
-        feedback.style = .outline
+        feedback.style = .raisedFeedback
         feedback.setAccessibilityRole(.link)
         feedback.onClick = { [weak self] in self?.openURL(Self.feedbackURL) }
         addSubview(feedback)
@@ -826,10 +848,13 @@ final class HomeContactPanelView: NSView {
         super.layout()
         let face = faceRect
         let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
-        let width = min(max(0, face.width - 84), max(face.width * 0.52, ceil(titleWidth) + 67))
-        let height = min(47, face.height * 0.31)
-        feedback.frame = NSRect(x: face.minX + face.height * 0.38 + 12, y: face.maxY - height - face.height * 0.12,
-                                width: width, height: height)
+        let height = min(52, face.height * 0.42)
+        let y = bounds.maxY - height
+        // 按按钮上沿所在高度找主卡的右斜边，让前层跨出主卡的右下角。
+        let right = min(bounds.maxX, face.maxX - HomeDashboardStyle.edgeOffset(for: y - face.minY) + 17)
+        let left = face.minX + HomeDashboardStyle.edgeOffset(for: face.maxY - y) + 13
+        let width = min(max(0, right - left), max(face.width * 0.52, ceil(titleWidth) + 67))
+        feedback.frame = NSRect(x: right - width, y: y, width: width, height: height)
     }
 
     override func draw(_ dirtyRect: NSRect) {
diff --git a/Tests/HomeModeButtonArtworkTests.swift b/Tests/HomeModeButtonArtworkTests.swift
index bbd7dc2c8b7a292d2c25211d4196f7284f9faa6c..04c3d9803e52984f8913d430dc0a7780671dfdec 100644
--- a/Tests/HomeModeButtonArtworkTests.swift
+++ b/Tests/HomeModeButtonArtworkTests.swift
@@ -19,7 +19,7 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         }
     }
 
-    func testContactIconUsesTheRaisedPlateAndFeedbackStaysOnTheMainCard() throws {
+    func testContactCardShowsTheRaisedIconAndLowerTrailingFeedback() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
@@ -30,16 +30,57 @@ final class HomeModeButtonArtworkTests: XCTestCase {
             let feedback = try XCTUnwrap(contact.subviews.compactMap { $0 as? HomeButton }.first)
             let face = contact.faceRect
             let plate = contact.iconPlateRect
+            let action = contact.feedbackPlateRect
             let context = "联系我们／\(size.width)×\(size.height)"
-            XCTAssertTrue(face.contains(feedback.frame), context)
+            XCTAssertTrue(contact.bounds.contains(feedback.frame), context)
+            XCTAssertTrue(feedback.frame.contains(action), context)
             XCTAssertFalse(plate.intersects(feedback.frame), context)
+            XCTAssertGreaterThan(action.midX, face.midX, context)
+            XCTAssertGreaterThan(action.maxY - face.maxY, 2, context)
 
-            let png = try assertRaisedPlate(in: contact, face: face, plate: plate, icon: contact.contactIconRect, context: context)
+            let bitmap = try assertRaisedPlate(in: contact, face: face, plate: plate, icon: contact.contactIconRect, context: context)
+            // 比较同一高度的实际斜边，避免用两个外接矩形的最右端判断凸出。
+            let sharedY = (action.minY + face.maxY) / 2
+            XCTAssertGreaterThan(sharedY, face.minY, context)
+            XCTAssertLessThan(sharedY, action.maxY, context)
+            let faceRight = face.maxX - HomeDashboardStyle.edgeOffset(for: sharedY - face.minY)
+            let actionRight = action.maxX - HomeDashboardStyle.edgeOffset(for: sharedY - action.minY)
+            XCTAssertGreaterThan(actionRight - faceRight, 2, context)
+            let right = NSPoint(x: (faceRight + actionRight) / 2, y: sharedY)
+            let bottomY = (action.maxY + face.maxY) / 2
+            let bottomX = action.midX - (bottomY - action.midY) * HomeDashboardStyle.slope
+            let bottom = NSPoint(x: bottomX, y: bottomY)
+            let empty = NSPoint(x: face.minX + face.width * 0.12, y: bottomY)
+            let emptyAlpha = try color(in: bitmap, size: size, at: empty).alphaComponent
+            for point in [right, bottom] {
+                XCTAssertGreaterThan(try color(in: bitmap, size: size, at: point).alphaComponent - emptyAlpha, 0.35, context)
+            }
+
+            let titleArea = NSRect(x: plate.maxX + 2, y: face.minY + 2,
+                                   width: face.maxX - plate.maxX - 4, height: action.minY - face.minY - 4)
+            XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: titleArea), 8, context)
+            let actionInk = action.insetBy(dx: HomeDashboardStyle.edgeOffset(for: action.height) + 3, dy: 3)
+            XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: actionInk), 8, context)
+
+            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
             let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-icon-plate-\(Int(size.width)).png")
             try png.write(to: preview)
         }
     }
 
+    func testContactIconAlignsWithTheNearestModeIconInTheLobby() throws {
+        _ = NSApplication.shared
+        for size in [NSSize(width: 960, height: 720), NSSize(width: 1585, height: 992)] {
+            let lobby = HomeDashboardView(frame: NSRect(origin: .zero, size: size))
+            lobby.layoutSubtreeIfNeeded()
+            let button = try XCTUnwrap(lobby.modePanel.subviews.compactMap { $0 as? HomeModeButton }.first { $0.mode == .moves })
+            let modeIcon = button.convert(button.modeIconRect, to: lobby)
+            let contact = lobby.contactPanel
+            let contactIcon = contact.convert(contact.contactIconRect, to: lobby)
+            XCTAssertEqual(contactIcon.midX, modeIcon.midX, accuracy: 0.1)
+        }
+    }
+
     func testExportModeIconPlatePreview() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
@@ -77,11 +118,13 @@ final class HomeModeButtonArtworkTests: XCTestCase {
 
     private func assertRaisedPlate(on button: HomeModeButton) throws -> Data {
         let context = "\(button.mode?.key ?? "解谜")／\(button.bounds.width)／\(button.selected ? "选中" : "默认")"
-        return try assertRaisedPlate(in: button, face: button.faceRect, plate: button.iconPlateRect, icon: button.modeIconRect,
-                                     context: context)
+        let bitmap = try assertRaisedPlate(in: button, face: button.faceRect, plate: button.iconPlateRect, icon: button.modeIconRect,
+                                          context: context)
+        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
     }
 
-    private func assertRaisedPlate(in view: NSView, face: NSRect, plate: NSRect, icon: NSRect, context: String) throws -> Data {
+    private func assertRaisedPlate(in view: NSView, face: NSRect, plate: NSRect, icon: NSRect,
+                                   context: String) throws -> NSBitmapImageRep {
         XCTAssertGreaterThan(face.minY - plate.minY, 2, context)
         XCTAssertGreaterThan(plate.maxY, face.minY, context)
         XCTAssertLessThan(plate.midX, face.midX, context)
@@ -89,23 +132,31 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         XCTAssertTrue(plate.contains(icon), context)
 
         let bitmap = try bitmap(of: view)
-        let xScale = CGFloat(bitmap.pixelsWide) / view.bounds.width
-        let yScale = CGFloat(bitmap.pixelsHigh) / view.bounds.height
-        func color(at point: NSPoint) throws -> NSColor {
-            try XCTUnwrap(bitmap.colorAt(x: Int(point.x * xScale), y: Int(point.y * yScale))?.usingColorSpace(.sRGB))
-        }
-
         // 在主卡上沿上方横向取样，确认只有前层所在位置绘制了内容。
+        let size = view.bounds.size
         let raisedY = (plate.minY + face.minY) / 2
         let raisedX = plate.midX + (plate.midY - raisedY) * HomeDashboardStyle.slope
-        let raised = try color(at: NSPoint(x: raisedX, y: raisedY))
-        let outside = try color(at: NSPoint(x: face.midX, y: raisedY))
+        let raised = try color(in: bitmap, size: size, at: NSPoint(x: raisedX, y: raisedY))
+        let outside = try color(in: bitmap, size: size, at: NSPoint(x: face.midX, y: raisedY))
         XCTAssertGreaterThan(raised.alphaComponent - outside.alphaComponent, 0.35, context)
 
         // 在图标矩形内寻找高对比笔画，避开前层和主卡的分隔描边。
-        let ink = icon.insetBy(dx: 1, dy: 1)
-        let columns = Int(ceil(ink.minX * xScale))..<Int(floor(ink.maxX * xScale))
-        let rows = Int(ceil(ink.minY * yScale))..<Int(floor(ink.maxY * yScale))
+        XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: icon.insetBy(dx: 1, dy: 1)), 8, context)
+        return bitmap
+    }
+
+    private func color(in bitmap: NSBitmapImageRep, size: NSSize, at point: NSPoint) throws -> NSColor {
+        let x = Int(point.x * CGFloat(bitmap.pixelsWide) / size.width)
+        let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / size.height)
+        return try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
+    }
+
+    private func visibleInk(in bitmap: NSBitmapImageRep, size: NSSize, area: NSRect) -> Int {
+        guard area.width > 1, area.height > 1 else { return 0 }
+        let xScale = CGFloat(bitmap.pixelsWide) / size.width
+        let yScale = CGFloat(bitmap.pixelsHigh) / size.height
+        let columns = Int(ceil(area.minX * xScale))..<Int(floor(area.maxX * xScale))
+        let rows = Int(ceil(area.minY * yScale))..<Int(floor(area.maxY * yScale))
         var visiblePixels = 0
         for y in rows {
             for x in columns {
@@ -114,8 +165,7 @@ final class HomeModeButtonArtworkTests: XCTestCase {
                 visiblePixels += 1
             }
         }
-        XCTAssertGreaterThan(visiblePixels, 8, context)
-        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+        return visiblePixels
     }
 }
 
```
