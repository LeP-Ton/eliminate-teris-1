# 简化选中模式并增加顶栏按钮内边距

## 背景与目标

- 去掉选中模式卡右侧的对勾，使用主卡边框和图标的青色状态表达选择。
- 给顶栏的挑战记录、玩法说明和游戏设置增加左右留白。

## 实现

- 删除右侧对勾绘制。选中轮廓、图标着色和辅助功能选中值沿用既有交互。
- 顶栏按钮用实际绘制的标题字号计算宽度，每侧至少留出 24 点。三项的分隔线继续位于按钮之间。窄窗口中遇到较长的译文时，三项共用略小的字号，为完整游戏名预留空间。

## 验证

- 在两种原生卡片尺寸下覆盖三个可选模式，逐像素检查旧对勾区域、青色边框与图标，并验证选中值。
- 在五语种与三种窗口尺寸下核对顶栏按钮内边距、排列、间隔、完整游戏名所需宽度及导航回调。
- 实看标准中文大厅和 960 点宽俄语大厅的原生截图。`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 105 项，全部通过。
- 手动验证可运行 `./run.sh`，切换模式、缩放窗口，检查选中卡和顶栏文字两侧的空间，再点开三项导航。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 0dc75abd3f0fb6212865f1f33d67869147b9052f..8dc7ed50cd2b7c7fd31b535be45098d7372e2efa 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127063642-polish-mode-selection-and-navigation-padding.md` - 会话-95 起移除选中模式卡右侧的对勾，为顶栏三项导航增加左右内边距。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
 `workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
@@ -110,6 +111,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整首页选中模式提示、顶栏按钮内边距或不同语言下的导航间距时，读取 `20261127063642-polish-mode-selection-and-navigation-padding.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
 - 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 8e4719d718e2788a193be20a84d9e820268e9861..78e86f8a3d335b3ec69f82de03c9bfe3630417e3 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -11,6 +11,8 @@ class HomeButton: NSButton {
     private(set) var hovering = false
     let feedback = GameControlFeedback()
 
+    static func standardTitleSize(for height: CGFloat) -> CGFloat { min(19, height * 0.44) }
+
     override init(frame: NSRect) {
         super.init(frame: frame)
         isBordered = false
@@ -82,7 +84,7 @@ class HomeButton: NSButton {
         let weight: NSFont.Weight = primary ? .black : .bold
         let icon: CGFloat = symbolName == nil ? 0 : (primary ? bounds.height * 0.44 : 16)
         let gap: CGFloat = icon > 0 ? 10 : 0
-        let preferred = primary ? min(34, bounds.height * 0.52) : min(19, bounds.height * 0.44)
+        let preferred = primary ? min(34, bounds.height * 0.52) : Self.standardTitleSize(for: bounds.height)
         let size = GameLobbyStyle.fittedSize(label, width: bounds.width - icon - gap - (primary ? 52 : 24),
                                              preferred: preferred, minimum: 10, weight: weight)
         let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
@@ -183,12 +185,6 @@ final class HomeModeButton: HomeButton {
         HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY,
                                                                width: descriptionWidth, height: face.maxY - descriptionY - 5),
                                        preferred: min(16, face.height * 0.23))
-        if effect.selection > 0 {
-            let size = min(22, face.height * 0.31)
-            HomeStyle.symbol("checkmark.circle.fill",
-                             in: NSRect(x: face.maxX - face.height * 0.71, y: face.minY + face.height * 0.23, width: size, height: size),
-                             color: cyan.withAlphaComponent(effect.selection))
-        }
     }
 
     private func drawIconPlate(_ plate: NSRect, tint: CGFloat) {
@@ -578,8 +574,10 @@ final class HomeDashboardView: NSView {
     private var showsShortcut = true
     private var displayedLanguage: AppLanguage?
 
+    private static let minimumBrandSize: CGFloat = 16
     private var margin: CGFloat { max(29, bounds.width * 0.034) }
     private var headerHeight: CGFloat { min(76, max(56, bounds.height * 0.071)) }
+    private var brandLeadingX: CGFloat { margin + 12 + 72 + 27 }
     private var sectionTop: CGFloat { max(headerHeight + 20, bounds.height * 0.105) }
     private var achievementTop: CGFloat { bounds.height * 0.815 }
     private var stageBottom: CGFloat { achievementTop - max(35, bounds.height * 0.058) }
@@ -698,13 +696,7 @@ final class HomeDashboardView: NSView {
             button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap) - frontClearance,
                                   width: max(0, panel.width - 15), height: rowHeight + frontClearance)
         }
-        var navX = bounds.width - margin + 5
-        for button in [settings, rules, records] {
-            let width = max(89, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width + 27)
-            navX -= width
-            button.frame = NSRect(x: navX, y: (headerHeight - 40) / 2, width: width, height: 40)
-            navX -= 19
-        }
+        layoutNavigation()
         needsDisplay = true
     }
 
@@ -755,6 +747,40 @@ final class HomeDashboardView: NSView {
         hint.attributedStringValue = NSAttributedString(string: value, attributes: attributes)
     }
 
+    private func layoutNavigation() {
+        let buttons = [settings, rules, records]
+        let horizontalPadding: CGFloat = 24
+        let gap: CGFloat = 19
+        let rightEdge = bounds.maxX - margin + 5
+        let brand = AchievementText.string("home.brand")
+        let brandFont = NSFont.systemFont(ofSize: Self.minimumBrandSize, weight: .black)
+        let brandWidth = ceil((brand as NSString).size(withAttributes: [.font: brandFont]).width)
+        let available = rightEdge - brandLeadingX - brandWidth - 26 - CGFloat(buttons.count - 1) * gap
+
+        func widths(for height: CGFloat) -> [CGFloat] {
+            let font = NSFont.systemFont(ofSize: HomeButton.standardTitleSize(for: height), weight: .bold)
+            return buttons.map { button in
+                let titleWidth = (button.title as NSString).size(withAttributes: [.font: font]).width
+                return max(89, ceil(titleWidth) + 2 * horizontalPadding)
+            }
+        }
+
+        // 窄窗中的长译文共用略小的字号，给品牌和按钮两侧的留白都留足空间。
+        var height: CGFloat = 40
+        var buttonWidths = widths(for: height)
+        while buttonWidths.reduce(0, +) > available, height > 33 {
+            height -= 1
+            buttonWidths = widths(for: height)
+        }
+
+        var x = rightEdge
+        for (button, width) in zip(buttons, buttonWidths) {
+            x -= width
+            button.frame = NSRect(x: x, y: (headerHeight - height) / 2, width: width, height: height)
+            x -= gap
+        }
+    }
+
     private func drawNavigation() {
         let y = headerHeight / 2
         let logoX = margin + 12
@@ -769,10 +795,11 @@ final class HomeDashboardView: NSView {
                                     height: 32, color: HomeDashboardStyle.muted.withAlphaComponent(0.62), width: 1.3)
 
         let brand = AchievementText.string("home.brand")
-        let brandX = slashX + 27
+        let brandX = brandLeadingX
         let brandWidth = max(0, records.frame.minX - brandX - 16)
         let preferred = min(34, max(25, bounds.width * 0.023))
-        let size = GameLobbyStyle.fittedSize(brand, width: brandWidth - 10, preferred: preferred, minimum: 16, weight: .black)
+        let size = GameLobbyStyle.fittedSize(brand, width: brandWidth - 10, preferred: preferred,
+                                           minimum: Self.minimumBrandSize, weight: .black)
         let measuredWidth = (brand as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .black)]).width
         HomeDashboardStyle.text(brand, in: NSRect(x: brandX, y: y - size * 0.65, width: brandWidth, height: size * 1.52),
                                 size: size, weight: .black)
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index 56da26ab49e4baefd57eedb2754b8507e0c92d0c..f38c357ee8e6ded013b7d8df09ab28bcef5f38bc 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -199,9 +199,14 @@ final class HomeDashboardTests: AchievementTestCase {
         defaults.set(["version": 1, "unlocked": [1, 3, 4, 7], "metrics": [:]], forKey: AchievementsManager.storageKey)
         let progress = AchievementsManager(defaults: defaults)
         let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        let navigationPages = ["records", "rules", "settings"]
+        let minimumBrandFont = NSFont.systemFont(ofSize: 16, weight: .black)
+        var openedPages: [String] = []
+        home.onNavigate = { openedPages.append($0) }
         for language in AppLanguage.allCases {
             Localizer.shared.setLanguage(language)
             let brand = AchievementText.string("home.brand")
+            let minimumBrandWidth = (brand as NSString).size(withAttributes: [.font: minimumBrandFont]).width
             XCTAssertEqual(brand, AchievementText.string("window.title"))
             if language == .chineseSimplified {
                 XCTAssertEqual(brand, "消除俄罗斯方块")
@@ -218,10 +223,29 @@ final class HomeDashboardTests: AchievementTestCase {
                     let feedback = try XCTUnwrap(home.contactPanel.subviews.compactMap { $0 as? HomeButton }.first)
                     XCTAssertEqual(feedback.title, AchievementText.string("home.contact.action"))
                     XCTAssertTrue(home.contactPanel.bounds.contains(feedback.frame))
-                    for button in home.subviews.compactMap({ $0 as? HomeButton }) where !button.isHidden {
+                    let visibleButtons = home.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden }
+                    for button in visibleButtons {
                         XCTAssertTrue(home.bounds.contains(button.frame), "\(language.rawValue): \(button.frame)")
                         XCTAssertGreaterThan(button.frame.height, 30)
                     }
+                    let navigationButtons = visibleButtons.filter { $0.style == .navigation }.sorted { $0.frame.minX < $1.frame.minX }
+                    XCTAssertEqual(navigationButtons.map(\.title), navigationPages.map { AchievementText.string("panel.\($0)") })
+                    let firstNavigationFrame = try XCTUnwrap(navigationButtons.first).frame
+                    let brandX = max(29, size.width * 0.034) + 111
+                    XCTAssertGreaterThanOrEqual(firstNavigationFrame.minX - brandX, minimumBrandWidth + 26, "\(language.rawValue): \(size.width)")
+                    let navigationFont = NSFont.systemFont(ofSize: min(19, firstNavigationFrame.height * 0.44), weight: .bold)
+                    for button in navigationButtons {
+                        XCTAssertEqual(button.frame.height, firstNavigationFrame.height)
+                        let titleWidth = (button.title as NSString).size(withAttributes: [.font: navigationFont]).width
+                        XCTAssertGreaterThanOrEqual((button.frame.width - titleWidth) / 2, 24, button.title)
+                    }
+                    for (left, right) in zip(navigationButtons, navigationButtons.dropFirst()) {
+                        XCTAssertEqual(right.frame.minX - left.frame.maxX, 19, accuracy: 0.01)
+                    }
+                    if language == .chineseSimplified, mode == .free, size.width == 960 {
+                        navigationButtons.forEach { $0.performClick(nil) }
+                        XCTAssertEqual(openedPages, navigationPages)
+                    }
                     if language == .chineseSimplified, size.width == 1180 {
                         let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: home.bounds))
                         home.cacheDisplay(in: home.bounds, to: bitmap)
diff --git a/Tests/HomeModeButtonArtworkTests.swift b/Tests/HomeModeButtonArtworkTests.swift
index 6aa42cb2e1219c5a6ae08e32022ef01d0d8f53c4..b3bad4ac57138e6c1c4922da93eb4ffc98dc53a5 100644
--- a/Tests/HomeModeButtonArtworkTests.swift
+++ b/Tests/HomeModeButtonArtworkTests.swift
@@ -19,6 +19,30 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         }
     }
 
+    func testSelectedModeUsesCyanOutlineAndIconWithoutTheTrailingCheckmark() throws {
+        _ = NSApplication.shared
+        for size in sizes {
+            for mode in HomeGameMode.allCases {
+                let button = makeButton(mode: mode, size: size, selected: true)
+                let bitmap = try bitmap(of: button)
+                let face = button.faceRect
+                let context = "\(mode.key)／\(size.width)×\(size.height)"
+                // 检查旧对勾所在的区域，避开主卡斜边和正常文字。
+                let badgeSize = min(22, face.height * 0.31)
+                let oldBadge = NSRect(x: face.maxX - face.height * 0.71, y: face.minY + face.height * 0.23,
+                                      width: badgeSize, height: badgeSize)
+                XCTAssertFalse(containsBrightCyan(in: bitmap, area: oldBadge, size: size), context)
+
+                let outline = NSRect(x: face.midX, y: face.minY, width: face.width / 4, height: 4)
+                XCTAssertTrue(containsBrightCyan(in: bitmap, area: outline, size: size), context)
+                XCTAssertTrue(containsBrightCyan(in: bitmap, area: button.modeIconRect, size: size), context)
+                XCTAssertEqual(button.accessibilityValue() as? Int, 1, context)
+                button.refresh(selectedMode: mode == .free ? .timed : .free)
+                XCTAssertEqual(button.accessibilityValue() as? Int, 0, context)
+            }
+        }
+    }
+
     func testExportModeIconPlatePreview() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
@@ -54,6 +78,22 @@ final class HomeModeButtonArtworkTests: XCTestCase {
         return bitmap
     }
 
+    private func containsBrightCyan(in bitmap: NSBitmapImageRep, area: NSRect, size: NSSize) -> Bool {
+        let xScale = CGFloat(bitmap.pixelsWide) / size.width
+        let yScale = CGFloat(bitmap.pixelsHigh) / size.height
+        let columns = Int(ceil(area.minX * xScale))..<Int(floor(area.maxX * xScale))
+        let rows = Int(ceil(area.minY * yScale))..<Int(floor(area.maxY * yScale))
+        return rows.contains { y in
+            columns.contains { x in
+                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.75 else {
+                    return false
+                }
+                let light = min(color.greenComponent, color.blueComponent)
+                return light > 0.77 && light - color.redComponent > 0.45
+            }
+        }
+    }
+
     private func assertRaisedPlate(on button: HomeModeButton) throws -> Data {
         let face = button.faceRect
         let plate = button.iconPlateRect
```
