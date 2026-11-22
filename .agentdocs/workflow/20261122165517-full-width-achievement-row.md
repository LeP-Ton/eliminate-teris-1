# 全宽单行成就与开局按钮底边对齐

## 背景与目标

会话-207 起，将成就之路移到左右两栏下方并铺满窗口内容宽度，开始按钮与联系我们卡片底边对齐。

## 实施结果

- [x] 成就区使用全宽单行预览，标题、进度与「查看全部」同排。窗口横向伸缩时调整标签数量，完整 32 枚成就由成就窗口展示。
- [x] 开始按钮与联系卡共用底边坐标。联系卡高 156 点，位于模式区下方，成就区与联系卡留出 24 点间距。
- [x] 矮窗口为联系卡和成就栏预留足够高度，采用更紧凑的模式按钮间距与文字排版。
- [x] 更新真实渲染预览、根索引和首页结构说明。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过 89 项测试，0 失败。
- 验证 960×720 至 1920×1250 的窗口，包括单独增加高度和缩回最小尺寸。检查单行成就跨度、按钮和卡片的底边以及点击徽章和查看全部的入口。
- 运行 `./run.sh`，调整窗口宽度和高度，检查开局按钮与联系我们底部齐平、成就始终单行。点击「查看全部」可核对完整清单。
- [常规窗口预览](../../docs/previews/lobby-idle.png)。
- [宽窗口预览](../../docs/previews/achievement-grid.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122165517-full-width-achievement-row.md` - 会话-207 起恢复跨栏单行成就，并让开始按钮与联系我们卡片底边对齐。含宽窄窗口回归、实际预览与完整 diff。
@@ -98,0 +100 @@
+- 需要调整当前首页的跨栏成就预览、开始按钮与联系卡的底边或小窗口布局时，读取 `20261122165517-full-width-achievement-row.md`。
@@ -102 +104 @@
-- 需要调整当前首页双栏、开始按钮对齐、左栏成就滚动或右栏联系我们卡片时，读取 `20261122151441-split-lobby-achievements-and-contact.md`。
+- 需要追溯左栏成就滚动版和右栏联系我们卡片的初版时，读取 `20261122151441-split-lobby-achievements-and-contact.md`。
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -8,2 +8,2 @@
-## 2026-11-22（首页双栏布局）
-- `HomeDashboardView` 管理固定的开局区和右侧信息栏。`HomeAchievementPathView` 负责左栏成就进度与原生纵向滚动网格，挑战卡转场仍由 `HomeModeHeaderView` 独立绘制。
+## 2026-11-22（首页双栏与跨栏成就）
+- `HomeDashboardView` 管理左侧开局区、右侧信息栏及下方跨栏成就。`HomeAchievementPathView` 按窗口宽度提供单行预览，完整列表由成就窗口展示。挑战卡转场由 `HomeModeHeaderView` 独立绘制。
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -89 +89 @@
-        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
+        let face = bounds.insetBy(dx: 4, dy: bounds.height < 65 ? 3 : 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
@@ -106 +106,3 @@
-        let textX = face.minX + 81, textWidth = face.width - 108
+        let compact = face.height < 65
+        let textX = compact ? icon.maxX + 11 : face.minX + 81
+        let textWidth = face.maxX - textX - 27
@@ -108 +109,0 @@
-        let compact = face.height < 65
@@ -110 +111 @@
-        let textY = compact ? face.minY + 4 : face.midY - 24
+        let textY = compact ? face.minY + 3 : face.midY - 24
@@ -113,3 +114,7 @@
-        GameLobbyStyle.wrappedText(AchievementText.string(descriptionKey),
-            in: NSRect(x: textX, y: textY + (compact ? 21 : 27), width: face.width - 98, height: face.maxY - textY - (compact ? 25 : 31)),
-            size: compact ? 11 : 12, color: HomeStyle.secondary)
+        let descriptionY = textY + (compact ? 21 : 27)
+        let description = AchievementText.string(descriptionKey)
+        let descriptionWidth = face.maxX - textX - 16
+        let descriptionSize = compact ? GameLobbyStyle.fittedSize(description, width: descriptionWidth, preferred: 11, minimum: 9, weight: .regular) : 12
+        GameLobbyStyle.wrappedText(description,
+            in: NSRect(x: textX, y: descriptionY, width: descriptionWidth, height: face.maxY - descriptionY - 3),
+            size: descriptionSize, color: HomeStyle.secondary)
@@ -156 +161 @@
-        // 计时刷新只更新变化的标签，避免重复格式化整个滚动列表。
+        // 计时刷新只更新变化的标签，避免重复格式化成就文案。
@@ -239,5 +244 @@
-private final class HomeAchievementDocumentView: NSView {
-    override var isFlipped: Bool { true }
-}
-
-/// 成就标题和进度固定在左栏，完整的徽章网格由原生滚动视图裁剪和滚动。
+/// 横跨两栏的成就预览，按可用宽度显示一行，完整清单由成就面板展示。
@@ -245 +246 @@
-    let scroll = NSScrollView()
+    static let preferredHeight: CGFloat = 106
@@ -247 +247,0 @@
-    private let document = HomeAchievementDocumentView(frame: .zero)
@@ -256,8 +255,0 @@
-        scroll.drawsBackground = false
-        scroll.borderType = .noBorder
-        scroll.scrollerStyle = .overlay
-        scroll.hasVerticalScroller = true
-        scroll.autohidesScrollers = true
-        scroll.horizontalScrollElasticity = .none
-        scroll.documentView = document
-        addSubview(scroll)
@@ -272 +264 @@
-            document.addSubview(badge)
+            addSubview(badge)
@@ -293,6 +285,4 @@
-        all.frame = NSRect(x: max(0, bounds.width - 120), y: 8, width: 120, height: 28)
-        scroll.frame = NSRect(x: 0, y: 65, width: bounds.width, height: max(0, bounds.height - 65))
-        let width = max(0, scroll.contentSize.width - 12)
-        let gap: CGFloat = 12, height: CGFloat = 54
-        let columns = max(1, min(badges.count, Int((width + gap) / (166 + gap))))
-        let rows = (badges.count + columns - 1) / columns
+        all.frame = NSRect(x: max(0, bounds.width - 120), y: 10, width: 120, height: 32)
+        let width = bounds.width
+        let gap: CGFloat = 12
+        let columns = min(badges.count, max(5, Int((width + gap) / (174 + gap))))
@@ -300 +289,0 @@
-        document.frame.size = NSSize(width: scroll.contentSize.width, height: CGFloat(rows) * (height + gap) + 2)
@@ -302,2 +291,3 @@
-            badge.frame = NSRect(x: CGFloat(index % columns) * (badgeWidth + gap),
-                                 y: 2 + CGFloat(index / columns) * (height + gap), width: badgeWidth, height: height)
+            badge.isHidden = index >= columns
+            guard !badge.isHidden else { continue }
+            badge.frame = NSRect(x: CGFloat(index) * (badgeWidth + gap), y: 52, width: badgeWidth, height: 54)
@@ -315 +305,2 @@
-        HomeStyle.text(title, in: NSRect(x: 0, y: 9, width: bounds.width - 126, height: 28), size: 21, weight: .heavy)
+        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 21, weight: .heavy)]).width)
+        HomeStyle.text(title, in: NSRect(x: 0, y: 11, width: titleWidth + 2, height: 30), size: 21, weight: .heavy)
@@ -318,3 +309,4 @@
-        HomeStyle.text(count, in: NSRect(x: 0, y: 39, width: countWidth + 2, height: 19), size: 13, weight: .semibold)
-        let meterX = countWidth + 15
-        let meter = NSRect(x: meterX, y: 44, width: min(210, max(0, bounds.width - meterX - 56)), height: 9)
+        let countX = titleWidth + 24
+        HomeStyle.text(count, in: NSRect(x: countX, y: 18, width: countWidth + 2, height: 19), size: 13, weight: .semibold)
+        let meterX = countX + countWidth + 15
+        let meter = NSRect(x: meterX, y: 22, width: min(210, max(0, all.frame.minX - meterX - 64)), height: 9)
@@ -328 +320 @@
-        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: 39, width: 50, height: 19),
+        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: 18, width: 50, height: 19),
@@ -347,0 +340,2 @@
+    private static let sectionGap: CGFloat = 24
+    private static let contactHeight: CGFloat = 156
@@ -352,2 +346,5 @@
-        let height = min(456, max(396, (bounds.height * 0.56).rounded(.down)))
-        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: height)
+        let top: CGFloat = 96
+        // 给联系卡和全宽成就栏留出空间，缩小窗口时优先收紧模式区。
+        let reserved = Self.contactHeight + Self.sectionGap * 2 + HomeAchievementPathView.preferredHeight + 20
+        let height = max(0, min(456, (bounds.height * 0.56).rounded(.down), bounds.height - top - reserved))
+        return NSRect(x: bounds.width - margin - width, y: top, width: width, height: height)
@@ -410,2 +407,4 @@
-        let bodyHeight = panel.height
-        let leftColumn = NSRect(x: margin, y: top, width: leftWidth, height: bodyHeight * 0.33 + 56)
+        modePanel.frame = panel
+        contactPanel.frame = NSRect(x: panel.minX, y: panel.maxY + Self.sectionGap, width: panel.width, height: Self.contactHeight)
+        let bottom = contactPanel.frame.maxY
+        let leftColumn = NSRect(x: margin, y: top, width: leftWidth, height: min(230, (bottom - top) * 0.33 + 56))
@@ -413,3 +412 @@
-        modePanel.frame = panel
-        // 开局按钮随模式卡片定位，左栏滚动时两者保持底边对齐。
-        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: panel.maxY - 62, width: 294, height: 62)
+        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: bottom - 62, width: 294, height: 62)
@@ -418 +415 @@
-        let heroY = min(top + bodyHeight * 0.43, hint.frame.minY - 150)
+        let heroY = (leftColumn.maxY + hint.frame.minY - 138) / 2
@@ -420,5 +417,5 @@
-        let lowerTop = panel.maxY + 24
-        achievementPath.frame = NSRect(x: margin, y: lowerTop, width: leftWidth, height: max(0, bounds.height - lowerTop - 20))
-        contactPanel.frame = NSRect(x: panel.minX, y: lowerTop, width: panel.width, height: 156)
-        let rowGap: CGFloat = 8
-        let rowHeight = (panel.height - 74 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
+        achievementPath.frame = NSRect(x: margin, y: bottom + Self.sectionGap,
+                                       width: bounds.width - margin * 2, height: HomeAchievementPathView.preferredHeight)
+        let rowGap: CGFloat = modePanel.isCompact ? 4 : 8
+        let firstRowY: CGFloat = modePanel.isCompact ? 48 : 60
+        let rowHeight = max(0, panel.height - firstRowY - 14 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
@@ -426 +423 @@
-            button.frame = NSRect(x: 20, y: 60 + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
+            button.frame = NSRect(x: 20, y: firstRowY + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
@@ -443 +440 @@
-        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), panel.maxY - 40, HomeStyle.yellow)] {
+        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), startButton.frame.maxY - 40, HomeStyle.yellow)] {
@@ -463,0 +461 @@
+    var isCompact: Bool { bounds.height < 340 }
@@ -476 +474,2 @@
-                       in: NSRect(x: 22, y: 18, width: bounds.width - 44, height: 36), size: 27, weight: .heavy)
+                       in: NSRect(x: 22, y: isCompact ? 10 : 18, width: bounds.width - 44, height: 36),
+                       size: isCompact ? 23 : 27, weight: .heavy)
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -122,2 +122 @@
-        let scroll = home.achievementPath.scroll
-        let document = try XCTUnwrap(scroll.documentView)
+        let badges = home.achievementPath.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden && $0.toolTip != nil }
@@ -128 +127 @@
-            let button = try XCTUnwrap(document.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
+            let button = try XCTUnwrap(badges.first { $0.toolTip?.contains(description) == true })
@@ -132 +131,2 @@
-        let strip = document.convert(NSRect(x: 0, y: 2, width: document.bounds.width - 12, height: 54), to: home)
+        let rect = try XCTUnwrap(badges.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
+        let strip = home.achievementPath.convert(rect, to: home)
@@ -154,4 +154,2 @@
-                    let scroll = home.achievementPath.scroll
-                    let document = try XCTUnwrap(scroll.documentView)
-                    let badges = document.subviews.compactMap { $0 as? HomeButton }
-                    XCTAssertEqual(badges.count, AchievementDefinition.all.count)
+                    let badges = home.achievementPath.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden && $0.toolTip != nil }
+                    XCTAssertGreaterThanOrEqual(badges.count, 5)
@@ -192,3 +190,2 @@
-                        let visible = badges.filter { scroll.documentVisibleRect.contains($0.frame) }
-                        let rect = try XCTUnwrap(visible.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
-                        let strip = document.convert(rect, to: home)
+                        let rect = try XCTUnwrap(badges.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
+                        let strip = home.achievementPath.convert(rect, to: home)
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -120 +120 @@
-    func testSplitDashboardKeepsActionAlignedWhileAchievementsScroll() throws {
+    func testAchievementRowSpansBothColumnsAndStartAlignsWithContact() throws {
@@ -131,3 +131,2 @@
-        let scroll = home.achievementPath.scroll
-        let document = try XCTUnwrap(scroll.documentView)
-        let badges = document.subviews.compactMap { $0 as? HomeButton }
+        let buttons = home.achievementPath.subviews.compactMap { $0 as? HomeButton }
+        let badges = buttons.filter { $0.toolTip != nil }
@@ -135,4 +134,2 @@
-        XCTAssertTrue(scroll.hasVerticalScroller)
-        XCTAssertFalse(scroll.hasHorizontalScroller)
-        var compactVisibleCount = 0
-        for (width, height, columns) in [(960, 720, 3), (1440, 720, 4), (960, 1000, 3), (1600, 1000, 5), (1920, 1250, 7)] {
+        for (width, height, count) in [(960, 720, 5), (1180, 800, 5), (1440, 720, 7),
+                                       (960, 1000, 5), (1600, 1000, 8), (1920, 1250, 9), (960, 720, 5)] {
@@ -144,4 +141,2 @@
-            XCTAssertEqual(home.startButton.frame.maxY, mode.maxY, accuracy: 0.1)
-            XCTAssertLessThan(path.maxX, mode.minX)
-            XCTAssertEqual(path.minY, mode.maxY + 24, accuracy: 0.1)
-            XCTAssertEqual(contact.minY, path.minY, accuracy: 0.1)
+            XCTAssertEqual(home.startButton.frame.maxY, contact.maxY, accuracy: 0.1)
+            XCTAssertEqual(contact.minY - mode.maxY, 24, accuracy: 0.1)
@@ -151,7 +146,11 @@
-            XCTAssertTrue(home.bounds.contains(contact))
-            XCTAssertEqual(Dictionary(grouping: badges) { $0.frame.minY }.values.map(\.count).max(), columns)
-            XCTAssertTrue(badges.allSatisfy { document.bounds.contains($0.frame) })
-
-            let visibleCount = badges.filter { scroll.documentVisibleRect.contains($0.frame) }.count
-            if width == 960, height == 720 { compactVisibleCount = visibleCount }
-            if width == 960, height == 1000 { XCTAssertGreaterThan(visibleCount, compactVisibleCount) }
+            XCTAssertEqual(path.minY - contact.maxY, 24, accuracy: 0.1)
+            XCTAssertEqual(path.minX, home.bounds.maxX - path.maxX, accuracy: 0.1)
+            XCTAssertEqual(path.maxX, contact.maxX, accuracy: 0.1)
+            XCTAssertTrue(home.bounds.contains(path))
+
+            let visible = badges.filter { !$0.isHidden }
+            XCTAssertEqual(visible.count, count)
+            XCTAssertEqual(Set(visible.map { $0.frame.minY }).count, 1)
+            XCTAssertTrue(visible.allSatisfy { home.achievementPath.bounds.contains($0.frame) })
+            XCTAssertEqual(try XCTUnwrap(visible.first).frame.minX, 0, accuracy: 0.1)
+            XCTAssertEqual(try XCTUnwrap(visible.last).frame.maxX, path.width, accuracy: 0.1)
@@ -166,12 +164,0 @@
-        home.setFrameSize(NSSize(width: 960, height: 720))
-        home.layoutSubtreeIfNeeded()
-        let last = try XCTUnwrap(badges.last)
-        XCTAssertFalse(scroll.documentVisibleRect.intersects(last.frame))
-        XCTAssertTrue(last.scrollToVisible(last.bounds))
-        XCTAssertTrue(scroll.documentVisibleRect.contains(last.frame))
-        let offset = scroll.documentVisibleRect.minY
-        home.refresh(snapshot: snapshot, mode: .moves, manager: progress)
-        home.layoutSubtreeIfNeeded()
-        XCTAssertEqual(scroll.documentVisibleRect.minY, offset, accuracy: 0.1)
-        XCTAssertEqual(home.startButton.frame.maxY, home.modePanel.frame.maxY, accuracy: 0.1)
-
@@ -180,2 +167,3 @@
-        last.performClick(nil)
-        let all = try XCTUnwrap(home.achievementPath.subviews.compactMap { $0 as? HomeButton }.first)
+        let badge = try XCTUnwrap(badges.first { !$0.isHidden })
+        badge.performClick(nil)
+        let all = try XCTUnwrap(buttons.first { $0.title.hasPrefix(AchievementText.string("achievement.view_all")) })
@@ -183 +171 @@
-        XCTAssertEqual(openedAchievements, [32, nil])
+        XCTAssertEqual(openedAchievements, [1, nil])
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -7 +7 @@
-- [待机首页](lobby-idle.png)展示双栏布局。左栏的开局按钮与右栏模式卡底边齐平，模式卡下方是联系我们卡片。
+- [待机首页](lobby-idle.png)展示开局按钮与联系我们卡片的底边对齐，成就之路横跨下方两栏。
@@ -74,2 +74,2 @@
-- [全屏尺寸标签效果](achievement-labels-fullscreen.png)展示 1920 点宽度下的多行布局。每枚标签的状态标记固定左侧，成就图案与名称单独居中。
-- [大窗口成就网格](achievement-grid.png)展示左栏的独立滚动区。窗口更宽时增加列，更高时可看到更多行，也可滚动查看全部 32 枚成就。
+- [全屏尺寸标签效果](achievement-labels-fullscreen.png)展示 1920 点宽度下的单行布局。每枚标签的状态标记固定左侧，成就图案与名称单独居中。
+- [大窗口成就栏](achievement-grid.png)展示 1600 点宽度下跨越左右两栏的 8 枚成就。窗口更宽时一行可容纳更多徽章，通过「查看全部」浏览完整清单。
```

### `docs/previews/achievement-grid.png`

```diff
- 1970131 字节，SHA-256 0a5072ddfdba2f3e76322d848991d6374f7f9d3df674082bb5483be09ab2a6cf
+ 1714724 字节，SHA-256 f0124a10a136ddaaadc18363f9668abf6fb47d6b67c80f459f8af19a718f736f
```

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 556899 字节，SHA-256 c9ad852fc808d6ad129f55a746329253b1b7c3ce6a37da728aa64bad151a178f
+ 170821 字节，SHA-256 210678e6e9b508838276743d64228adceead687896628a7f9c47ea9b088286b7
```

### `docs/previews/achievement-labels.png`

```diff
- 66506 字节，SHA-256 cf28ab93f0f573ceb9ac33f5fc68b23bb6bd1c7b9ad19cd4ebf6d83088758801
+ 103374 字节，SHA-256 4ef5c222dba302f892c2f293badf9e7d45e06cff2ab32de825bb0aaa7028f998
```

### `docs/previews/challenge-moves.png`

```diff
- 1366865 字节，SHA-256 e6965aff7fa0f86f6100186ac0a4cd08c55b2082d6667797bf5ae05482611056
+ 1290265 字节，SHA-256 e18c54ab7e0566d8190ba5af871e1e5fb91eccd9ff1e5f4b92577d655152d53a
```

### `docs/previews/challenge-preview.gif`

```diff
- 605713 字节，SHA-256 15feaea398034bc5de0b3e0d0baf655493952e67fd6b2118ed05fb3fc4c61749
+ 638716 字节，SHA-256 4275dbda5bedbd77a84244a142118e30fe6adc3b2bf29754c665581355e9300b
```

### `docs/previews/challenge-timed.png`

```diff
- 1367392 字节，SHA-256 fccbb07a2f84983bd7ef62901f6f6dce738929cbeb85af4d09137e1d354027eb
+ 1285653 字节，SHA-256 35ad7710ed5301ec4986d017a863309de7214b1085582aca35771711977ce24e
```

### `docs/previews/lobby-finished.png`

```diff
- 1362008 字节，SHA-256 bf835af0e0459171e8c8413e770763a51df86a469ee63942f6923c6916b1783a
+ 1280501 字节，SHA-256 a5315832a28f01739401695203c66595af2cf20c1f3a9f1e6b540a920c9c8e34
```

### `docs/previews/lobby-idle.png`

```diff
- 1201125 字节，SHA-256 7d38bb040bc5be344559c7d44902c21ffbbe0e71a8985b84161bd8e08ba8a727
+ 1130938 字节，SHA-256 88a59a70a431e238f213477c6462c9d6650d0f5ec7363a0fb8e0a47e42bf7fb2
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1380163 字节，SHA-256 f9eb8473ea16e94316921652626ab8eca0b7ab4599f74b19a40c922fa39b08aa
+ 1302593 字节，SHA-256 efcc377f8297445baa1b04bab7b045b7735d4322efddc20e721501967df74a11
```
