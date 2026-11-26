# 联系卡图标左上小幅凸出与反馈按钮右下等距

## 背景与目标

- 用户要求联系卡图标像模式卡左上角，沿联系卡自身的边缘稍微凸出。
- 将 GitHub 反馈按钮向下微调，使按钮前层露出主卡底边的距离，与同一高度测得的右侧距离相等。

## 实现

- 图标前层沿用模式卡的斜率和比例。高度比主卡短时，沿主卡左斜边计算前层的起点，得到约 7 点上沿外露及约 9–11 点左侧外露。
- 「在 GitHub 反馈」的前层在右侧和底边各露出 12 点。使用原生按钮的面板内边距预留侧沿和按压空间，悬停和按下时同步调整横向及纵向位置。
- 联系卡外部占位继续与开局区对齐，反馈仍由原生链接按钮触发。

## 验证

- 检查 302 × 110、500 × 148 点联系卡，以及 960 × 720、1585 × 992 点大厅。按同一高度测量斜边，验证图标小幅外露、反馈按钮右下等距及文字可见。
- 检查标准与俄语紧凑窗口的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 106 项，全部通过。
- 手动验证可运行 `./run.sh` 并调整窗口大小。查看图标是否贴着联系卡左上角，以及反馈按钮的右侧和底边外露是否等距。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 678986792c0f53ed1c499fef4137fab914bc28ea..6ff92088e53a358c5e638ce98f272e8a06d20195 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261126212639-balance-contact-card-overhangs.md` - 会话-67 起按联系卡自身左上斜边定位图标，并统一反馈按钮右侧与底边的外露距离。
 `workflow/20261125091517-align-contact-icon-and-raise-feedback.md` - 会话-65 起把联系卡图标前层向右对齐限步卡图标，并将 GitHub 反馈按钮放到主卡右下的凸出前层。
 `workflow/20261125085410-layer-contact-card-icon.md` - 会话-63 起让「联系我们」沿用游戏模式卡的凸出图标前层，含紧凑与标准窗口的原生回归。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
@@ -112,6 +113,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整联系卡左上图标的小幅外露或反馈按钮右、下等距时，读取 `20261126212639-balance-contact-card-overhangs.md`。
 - 需要调整联系卡图标对齐、右下反馈前层或按钮焦点轮廓时，读取 `20261125091517-align-contact-icon-and-raise-feedback.md`。
 - 需要调整「联系我们」的前层、消息图标、反馈按钮与主卡间距时，读取 `20261125085410-layer-contact-card-icon.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
diff --git a/Sources/HomeDashboardStyle.swift b/Sources/HomeDashboardStyle.swift
index 7ce9e774087c957517b4d03d299938b9398bda09..1b61c8324e52e8c2c058f92d7b547c9a0c0eefe4 100644
--- a/Sources/HomeDashboardStyle.swift
+++ b/Sources/HomeDashboardStyle.swift
@@ -71,11 +71,14 @@ enum HomeDashboardStyle {
         face.stroke()
     }
 
-    static func iconPlate(in face: NSRect) -> NSRect {
-        let height = face.height * 0.77
-        let width = face.height * 0.76 + edgeOffset(for: height)
-        let rise = min(iconPlateClearance - 1, face.height * 0.13)
-        return NSRect(x: face.minX + 1.5, y: face.minY - rise, width: width, height: height)
+    static func iconPlate(in face: NSRect, referenceHeight: CGFloat? = nil) -> NSRect {
+        let baseHeight = referenceHeight ?? face.height
+        let height = baseHeight * 0.77
+        let width = baseHeight * 0.76 + edgeOffset(for: height)
+        let rise = min(iconPlateClearance - 1, baseHeight * 0.13)
+        // 前层较短时，沿主卡的左斜边补偿起点，保留同样的小幅外露。
+        let x = face.minX + 1.5 + edgeOffset(for: face.height - baseHeight)
+        return NSRect(x: x, y: face.minY - rise, width: width, height: height)
     }
 
     static func centeredIcon(in plate: NSRect) -> NSRect {
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index a0994cda23bb46c1307bf5a9f734ab45515c9a54..361ba75b02eadaadb352d405fba7cde761c070fe 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -46,16 +46,24 @@ class HomeButton: NSButton {
         needsDisplay = true
     }
 
-    var buttonSurfaceRect: NSRect {
-        let effect = feedback.values
-        let offset = effect.press * 1.8 - effect.hover
-        var face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
+    var buttonSurfaceInsets: NSEdgeInsets {
         if style == .raisedFeedback {
             // 右下侧沿和按下时的位移都画在原生按钮边界内。
-            face.size.width = max(0, face.width - 4)
-            face.size.height = max(0, face.height - 5.5)
+            return NSEdgeInsets(top: 1.2, left: 1.2, bottom: 4.2, right: 5.2)
         }
-        return face
+        return NSEdgeInsets(top: 1.2, left: 1.2, bottom: 1.2, right: 1.2)
+    }
+
+    var buttonSurfaceRect: NSRect {
+        let effect = feedback.values
+        let insets = buttonSurfaceInsets
+        let raised = style == .raisedFeedback
+        let dy = raised ? effect.press * 0.4 - effect.hover * 0.7 : effect.press * 1.8 - effect.hover
+        // 反馈前层有上下位移时同步微调横向位置，保持右侧和底边等量外露。
+        let dx = raised ? dy * (1 - HomeDashboardStyle.slope) : 0
+        return NSRect(x: bounds.minX + insets.left + dx, y: bounds.minY + insets.top + dy,
+                      width: max(0, bounds.width - insets.left - insets.right),
+                      height: max(0, bounds.height - insets.top - insets.bottom))
     }
 
     override func draw(_ dirtyRect: NSRect) {
@@ -674,10 +682,6 @@ final class HomeDashboardView: NSView {
             button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap) - frontClearance,
                                   width: max(0, panel.width - 15), height: rowHeight + frontClearance)
         }
-        if let bottomMode = modes.last {
-            let icon = bottomMode.modeIconRect
-            contactPanel.iconCenterX = bottomMode.convert(NSPoint(x: icon.midX, y: icon.midY), to: contactPanel).x
-        }
         var navX = bounds.width - margin + 5
         for button in [settings, rules, records] {
             let width = max(89, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width + 27)
@@ -798,26 +802,24 @@ final class HomeModePanelView: NSView {
 /// 反馈按钮打开项目的问题跟踪页。
 final class HomeContactPanelView: NSView {
     private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
-    private static let feedbackClearance: CGFloat = 11
+    private static let feedbackOverhang: CGFloat = 12
     private let feedback = HomeButton(frame: .zero)
     var openURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }
-    var iconCenterX: CGFloat? { didSet { if oldValue != iconCenterX { needsDisplay = true } } }
 
     override var isFlipped: Bool { true }
 
     var faceRect: NSRect {
-        let clearance = HomeDashboardStyle.iconPlateClearance
-        return NSRect(x: bounds.minX, y: bounds.minY + clearance, width: bounds.width,
-                      height: max(0, bounds.height - clearance - Self.feedbackClearance))
+        let top = HomeDashboardStyle.iconPlateClearance
+        let bottom = Self.feedbackOverhang + feedback.buttonSurfaceInsets.bottom
+        return NSRect(x: bounds.minX, y: bounds.minY + top, width: bounds.width,
+                      height: max(0, bounds.height - top - bottom))
     }
 
     var iconPlateRect: NSRect {
         // 前层按标题和说明这部分的高度定尺寸，给下方反馈按钮留出空间。
-        var heading = faceRect
-        heading.size.height = min(90, (heading.height + Self.feedbackClearance) * 0.72)
-        let plate = HomeDashboardStyle.iconPlate(in: heading)
-        let center = iconCenterX ?? plate.midX + min(25, heading.width * 0.07)
-        return plate.offsetBy(dx: center - plate.midX, dy: 0)
+        let face = faceRect
+        let headingHeight = min(90, face.height, (bounds.maxY - face.minY) * 0.72)
+        return HomeDashboardStyle.iconPlate(in: face, referenceHeight: max(0, headingHeight))
     }
 
     var contactIconRect: NSRect { HomeDashboardStyle.centeredIcon(in: iconPlateRect) }
@@ -850,8 +852,10 @@ final class HomeContactPanelView: NSView {
         let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
         let height = min(52, face.height * 0.42)
         let y = bounds.maxY - height
-        // 按按钮上沿所在高度找主卡的右斜边，让前层跨出主卡的右下角。
-        let right = min(bounds.maxX, face.maxX - HomeDashboardStyle.edgeOffset(for: y - face.minY) + 17)
+        let insets = feedback.buttonSurfaceInsets
+        // 在前层上沿测量同一高度的右斜边，使用与底边相同的外露距离。
+        let bodyRight = face.maxX - HomeDashboardStyle.edgeOffset(for: y + insets.top - face.minY)
+        let right = min(bounds.maxX, bodyRight + Self.feedbackOverhang + insets.right)
         let left = face.minX + HomeDashboardStyle.edgeOffset(for: face.maxY - y) + 13
         let width = min(max(0, right - left), max(face.width * 0.52, ceil(titleWidth) + 67))
         feedback.frame = NSRect(x: right - width, y: y, width: width, height: height)
diff --git a/Tests/HomeModeButtonArtworkTests.swift b/Tests/HomeModeButtonArtworkTests.swift
index 04c3d9803e52984f8913d430dc0a7780671dfdec..9a9aea848af0c3721b1595cf9a2bb0d2d14e3b6a 100644
--- a/Tests/HomeModeButtonArtworkTests.swift
+++ b/Tests/HomeModeButtonArtworkTests.swift
@@ -36,23 +36,12 @@ final class HomeModeButtonArtworkTests: XCTestCase {
             XCTAssertTrue(feedback.frame.contains(action), context)
             XCTAssertFalse(plate.intersects(feedback.frame), context)
             XCTAssertGreaterThan(action.midX, face.midX, context)
-            XCTAssertGreaterThan(action.maxY - face.maxY, 2, context)
 
             let bitmap = try assertRaisedPlate(in: contact, face: face, plate: plate, icon: contact.contactIconRect, context: context)
-            // 比较同一高度的实际斜边，避免用两个外接矩形的最右端判断凸出。
-            let sharedY = (action.minY + face.maxY) / 2
-            XCTAssertGreaterThan(sharedY, face.minY, context)
-            XCTAssertLessThan(sharedY, action.maxY, context)
-            let faceRight = face.maxX - HomeDashboardStyle.edgeOffset(for: sharedY - face.minY)
-            let actionRight = action.maxX - HomeDashboardStyle.edgeOffset(for: sharedY - action.minY)
-            XCTAssertGreaterThan(actionRight - faceRight, 2, context)
-            let right = NSPoint(x: (faceRight + actionRight) / 2, y: sharedY)
-            let bottomY = (action.maxY + face.maxY) / 2
-            let bottomX = action.midX - (bottomY - action.midY) * HomeDashboardStyle.slope
-            let bottom = NSPoint(x: bottomX, y: bottomY)
-            let empty = NSPoint(x: face.minX + face.width * 0.12, y: bottomY)
+            let projections = assertContactProjections(in: contact, context: context)
+            let empty = NSPoint(x: face.minX + face.width * 0.12, y: projections.bottom.y)
             let emptyAlpha = try color(in: bitmap, size: size, at: empty).alphaComponent
-            for point in [right, bottom] {
+            for point in [projections.left, projections.right, projections.bottom] {
                 XCTAssertGreaterThan(try color(in: bitmap, size: size, at: point).alphaComponent - emptyAlpha, 0.35, context)
             }
 
@@ -68,19 +57,44 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         }
     }
 
-    func testContactIconAlignsWithTheNearestModeIconInTheLobby() throws {
+    func testContactCardKeepsLocalProjectionsAcrossLobbySizes() {
         _ = NSApplication.shared
         for size in [NSSize(width: 960, height: 720), NSSize(width: 1585, height: 992)] {
             let lobby = HomeDashboardView(frame: NSRect(origin: .zero, size: size))
             lobby.layoutSubtreeIfNeeded()
-            let button = try XCTUnwrap(lobby.modePanel.subviews.compactMap { $0 as? HomeModeButton }.first { $0.mode == .moves })
-            let modeIcon = button.convert(button.modeIconRect, to: lobby)
-            let contact = lobby.contactPanel
-            let contactIcon = contact.convert(contact.contactIconRect, to: lobby)
-            XCTAssertEqual(contactIcon.midX, modeIcon.midX, accuracy: 0.1)
+            _ = assertContactProjections(in: lobby.contactPanel, context: "大厅／\(size.width)×\(size.height)")
         }
     }
 
+    private func assertContactProjections(in contact: HomeContactPanelView, context: String)
+        -> (left: NSPoint, right: NSPoint, bottom: NSPoint) {
+        let face = contact.faceRect
+        let icon = contact.iconPlateRect
+        let action = contact.feedbackPlateRect
+        // 左上图标只从联系卡自身少量伸出，在同一高度比较实际左斜边。
+        let leftY = (face.minY + icon.maxY) / 2
+        let faceLeft = face.minX + HomeDashboardStyle.edgeOffset(for: face.maxY - leftY)
+        let iconLeft = icon.minX + HomeDashboardStyle.edgeOffset(for: icon.maxY - leftY)
+        XCTAssertTrue((8...12).contains(faceLeft - iconLeft), context)
+        XCTAssertEqual(face.minY - icon.minY, 7, accuracy: 1, context)
+        let left = NSPoint(x: (iconLeft + faceLeft) / 2, y: leftY)
+
+        // 右下按钮以同一高度的水平距离和底边垂直距离分别测量。
+        let rightY = (action.minY + face.maxY) / 2
+        XCTAssertGreaterThan(rightY, face.minY, context)
+        XCTAssertLessThan(action.minY, face.maxY, context)
+        XCTAssertLessThan(rightY, action.maxY, context)
+        let faceRight = face.maxX - HomeDashboardStyle.edgeOffset(for: rightY - face.minY)
+        let actionRight = action.maxX - HomeDashboardStyle.edgeOffset(for: rightY - action.minY)
+        let vertical = action.maxY - face.maxY
+        XCTAssertEqual(vertical, 12, accuracy: 0.1, context)
+        XCTAssertEqual(actionRight - faceRight, vertical, accuracy: 0.1, context)
+        let right = NSPoint(x: (faceRight + actionRight) / 2, y: rightY)
+        let bottomY = (action.maxY + face.maxY) / 2
+        let bottomX = action.midX - (bottomY - action.midY) * HomeDashboardStyle.slope
+        return (left, right, NSPoint(x: bottomX, y: bottomY))
+    }
+
     func testExportModeIconPlatePreview() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
```
