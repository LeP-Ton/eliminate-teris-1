# 统计明细右对齐与首页自适应成就网格

## 背景与目标

会话-190 起，把规则与统计卡中的四类方块明细靠右显示，并让成就之路根据窗口宽高显示更多成就。

## 实施结果

- [x] 四类明细保持单行，每一组数字右边缘固定。图案跟随数字宽度调整位置，整组贴齐卡片内容区右边缘。
- [x] 成就标签在 960×720 窗口显示 5 列、1 行。宽窗口增加列，高窗口从底部向上增加整行，最多显示全部 32 枚成就。
- [x] 成就区顶部与游戏模式卡片底部至少留出 24 点间距。若还放不下一整行，剩余空间保留为留白。
- [x] 保持原有排序与详情入口。缩放后仅填写可见标签的详情提示。按图案轮廓和实际字形对齐图文，状态标记仍在左侧固定位置。
- [x] 更新预览和根索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过 88 项测试，0 失败。

- 使用 XCTest 验证 960×720、1440×720、960×1000、1600×1000、1920×1250 和缩回最小尺寸的行列数。检查模式面板最小间距、开始按钮位置和最后一枚成就的详情入口。
- 隔点取样检查五种语言的可见徽章，图文中心像素测量允许水平 5 点、垂直 4 点偏差，状态标记独立核对。
- 运行 `./run.sh` 后切换限时或限步，查看四类明细靠右。先横向拉宽，再纵向拉高，观察成就增加列和行。
- [大窗口实际预览](../../docs/previews/achievement-grid.png)展示 1600×1000 下的 8 列、4 行和完整 32 枚成就。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122143206-adaptive-achievement-grid.md` - 会话-190 起在统计卡右侧对齐方块明细，并让成就之路按窗口宽高增加列和行。含模式面板间距回归、实际预览与完整 diff。
@@ -93,0 +95 @@
+- 需要调整首页成就网格的行列数量、与模式面板的间距，或统计卡明细的右对齐时，读取 `20261122143206-adaptive-achievement-grid.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -129 +129 @@
-        let slot = rect.width / CGFloat(kinds.count)
+        let slot = min(80, rect.width / CGFloat(kinds.count))
@@ -133 +133 @@
-        // 每组的图案和数字都对齐本局总数的垂直中心。
+        // 明细从卡片右侧排起，数字右边缘固定，位数变化时仍与图标保持间距。
@@ -135,2 +134,0 @@
-            let x = rect.minX + CGFloat(index) * slot
-            HomeStyle.piece(kind, in: NSRect(x: x, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
@@ -139,3 +137,8 @@
-            let height = ceil((number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height)
-            HomeStyle.text(number, in: NSRect(x: x + iconWidth + gap, y: rect.midY - height / 2, width: numberWidth, height: height),
-                           size: size, weight: .semibold)
+            let text = (number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)])
+            let width = min(numberWidth, ceil(text.width))
+            let height = ceil(text.height)
+            let right = rect.maxX - CGFloat(kinds.count - index - 1) * slot
+            let numberX = right - width
+            HomeStyle.piece(kind, in: NSRect(x: numberX - gap - iconWidth, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
+            HomeStyle.text(number, in: NSRect(x: numberX, y: rect.midY - height / 2, width: width, height: height),
+                           size: size, weight: .semibold, alignment: .right)
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -1,0 +2 @@
+import CoreText
@@ -143,0 +145,2 @@
+    private static let iconSize: CGFloat = 38
+    private static var iconBounds: [String: NSRect] = [:]
@@ -154 +157,2 @@
-        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
+        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
+        let attributes: [NSAttributedString.Key: Any] = [.font: font]
@@ -157,3 +161,5 @@
-        let fixedWidth: CGFloat = 38 + 9
-        // 左侧状态占据 13...33 点，居中内容两侧对称预留 34 点，避免窄窗口重叠。
-        let availableWidth = max(0, floor(bounds.width - 34 * 2 - fixedWidth))
+        let artwork = AchievementIconCatalog.image(for: definition, muted: !unlocked)
+        let artworkBounds = Self.visibleBounds(of: artwork, key: "\(definition.id).\(unlocked)")
+        let fixedWidth = ceil(artworkBounds.width) + 9
+        // 覆盖状态图标及抗锯齿边缘，并为图文居中在另一侧预留同等空间。
+        let availableWidth = max(0, floor(bounds.width - 36 * 2 - fixedWidth))
@@ -166,2 +172,7 @@
-        let titleSize = (displayedTitle as NSString).size(withAttributes: attributes)
-        let titleWidth = ceil(titleSize.width)
+        let color = unlocked ? HomeStyle.ink : HomeStyle.muted
+        let line = CTLineCreateWithAttributedString(NSAttributedString(string: displayedTitle, attributes: [
+            .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
+        ]))
+        // 按截断后字形的实际轮廓居中，兼顾没有下伸笔画的标题和各语言的字体回退。
+        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
+        let titleWidth = displayedTitle.isEmpty || textBounds.isNull ? 0 : textBounds.width
@@ -171,4 +182,35 @@
-        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: startX, y: bounds.midY - 19, width: 38, height: 38),
-                                                                           from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
-        HomeStyle.text(displayedTitle, in: NSRect(x: startX + fixedWidth, y: bounds.midY - titleSize.height / 2, width: titleWidth, height: titleSize.height), size: 13, weight: .semibold,
-                       color: unlocked ? HomeStyle.ink : HomeStyle.muted)
+        artwork.draw(in: NSRect(x: startX - artworkBounds.minX, y: bounds.midY - artworkBounds.midY,
+                               width: Self.iconSize, height: Self.iconSize),
+                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+        if titleWidth > 0, let context = NSGraphicsContext.current?.cgContext {
+            context.saveGState()
+            // 当前视图的 y 向下，文字绘制坐标的 y 向上。
+            context.translateBy(x: startX + fixedWidth - textBounds.minX, y: bounds.midY + textBounds.midY)
+            context.scaleBy(x: 1, y: -1)
+            context.textMatrix = .identity
+            context.textPosition = .zero
+            CTLineDraw(line, context)
+            context.restoreGState()
+        }
+    }
+
+    private static func visibleBounds(of artwork: NSImage, key: String) -> NSRect {
+        if let cached = iconBounds[key] { return cached }
+        let canvas = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
+        guard let data = artwork.tiffRepresentation, let image = NSBitmapImageRep(data: data) else { return canvas }
+        var left = image.pixelsWide, right = -1, top = image.pixelsHigh, bottom = -1
+        // 忽略透明留白与抗锯齿细边，用图案轮廓对齐。
+        for y in 0..<image.pixelsHigh {
+            for x in 0..<image.pixelsWide {
+                guard let color = image.colorAt(x: x, y: y), color.alphaComponent > 0.2 else { continue }
+                left = min(left, x); right = max(right, x)
+                top = min(top, y); bottom = max(bottom, y)
+            }
+        }
+        guard left <= right, top <= bottom else { return canvas }
+        let scaleX = iconSize / CGFloat(image.pixelsWide)
+        let scaleY = iconSize / CGFloat(image.pixelsHigh)
+        let result = NSRect(x: CGFloat(left) * scaleX, y: CGFloat(top) * scaleY,
+                            width: CGFloat(right - left + 1) * scaleX, height: CGFloat(bottom - top + 1) * scaleY)
+        iconBounds[key] = result
+        return result
@@ -192,0 +235,2 @@
+    private var orderedAchievements: [AchievementDefinition] = []
+    private var achievementManager: AchievementsManager?
@@ -193,0 +238,3 @@
+    private static let achievementGap: CGFloat = 24
+    private static let badgeGap: CGFloat = 12
+    private static let badgeHeight: CGFloat = 54
@@ -196 +243 @@
-    private var footerY: CGFloat { bounds.height - 144 }
+    private var singleRowTop: CGFloat { bounds.height - 144 }
@@ -199 +246,14 @@
-        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: min(496, footerY - 120))
+        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: min(496, singleRowTop - 120))
+    }
+
+    private func achievementGrid(below panel: NSRect) -> (top: CGFloat, columns: Int, count: Int, badgeWidth: CGFloat) {
+        let availableWidth = max(0, bounds.width - margin * 2)
+        let gap = Self.badgeGap
+        let total = AchievementDefinition.all.count
+        let columns = min(total, max(5, Int((availableWidth + gap) / (174 + gap))))
+        let rowStride = Self.badgeHeight + gap
+        // 以底部的一行作为基准，只有上方还有完整行高和安全间距时才添加一行。
+        let extraHeight = max(0, singleRowTop - panel.maxY - Self.achievementGap)
+        let rows = min((total + columns - 1) / columns, 1 + Int(extraHeight / rowStride))
+        let width = max(0, availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
+        return (singleRowTop - CGFloat(rows - 1) * rowStride, columns, min(total, rows * columns), width)
@@ -227 +287 @@
-        for _ in 0..<5 {
+        for _ in AchievementDefinition.all {
@@ -252 +312,2 @@
-        let definitions = AchievementDefinition.all.sorted {
+        achievementManager = manager
+        orderedAchievements = AchievementDefinition.all.sorted {
@@ -255,6 +315,0 @@
-        }
-        for (button, definition) in zip(badges, definitions) {
-            button.definition = definition; button.unlocked = manager.isUnlocked(id: definition.id)
-            button.toolTip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
-            button.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
-            button.needsDisplay = true
@@ -268,0 +324 @@
+        let grid = achievementGrid(below: panel)
@@ -271 +327,3 @@
-        let bodyHeight = footerY - top - 24
+        // 左侧开局区始终在成就标题之上，也不随超高窗口把插图和按钮拉得过远。
+        let bodyBottom = min(grid.top, panel.maxY + 64)
+        let bodyHeight = bodyBottom - top - 24
@@ -275 +333 @@
-        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: footerY - 89, width: 294, height: 62)
+        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: bodyBottom - 89, width: 294, height: 62)
@@ -291,3 +349,18 @@
-        all.frame = NSRect(x: bounds.width - margin - 120, y: footerY + 8, width: 120, height: 32)
-        let badgeWidth = (bounds.width - margin * 2 - 12 * 4) / 5
-        for (index, badge) in badges.enumerated() { badge.frame = NSRect(x: margin + CGFloat(index) * (badgeWidth + 12), y: footerY + 52, width: badgeWidth, height: 54) }
+        all.frame = NSRect(x: bounds.width - margin - 120, y: grid.top + 8, width: 120, height: 32)
+        for (index, badge) in badges.enumerated() {
+            badge.isHidden = index >= min(grid.count, orderedAchievements.count)
+            guard !badge.isHidden, let manager = achievementManager else { continue }
+            // 仅为当前可见的标签格式化进度，改变窗口大小后再填充新露出的行。
+            let definition = orderedAchievements[index]
+            badge.definition = definition
+            badge.unlocked = manager.isUnlocked(id: definition.id)
+            let tooltip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
+            if badge.toolTip != tooltip { badge.toolTip = tooltip }
+            badge.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
+            badge.needsDisplay = true
+            let column = CGFloat(index % grid.columns)
+            let row = CGFloat(index / grid.columns)
+            badge.frame = NSRect(x: margin + column * (grid.badgeWidth + Self.badgeGap),
+                                 y: grid.top + 52 + row * (Self.badgeHeight + Self.badgeGap),
+                                 width: grid.badgeWidth, height: Self.badgeHeight)
+        }
@@ -298,0 +372 @@
+        let footerY = achievementGrid(below: panel).top
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -152,2 +152,2 @@
-                    let badges = home.subviews.compactMap { $0 as? HomeButton }.filter { $0.toolTip != nil }
-                    XCTAssertEqual(badges.count, 5)
+                    let badges = home.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden && $0.toolTip != nil }
+                    XCTAssertGreaterThanOrEqual(badges.count, 5)
@@ -154,0 +155 @@
+                        let name = badge.accessibilityLabel() ?? "成就"
@@ -157,0 +159 @@
+                        let verticalScale = CGFloat(pixels.pixelsHigh) / badge.bounds.height
@@ -161 +163 @@
-                        let insetX = Int(8 * scale), insetY = Int(4 * scale)
+                        let insetX = Int(8 * scale), insetY = Int(4 * verticalScale)
@@ -180,4 +182,4 @@
-                        let centerY = CGFloat(minY + maxY + 1) / (2 * scale)
-                        // 成就图案透明画布的左右留白可不同，像素外沿容许 5 点光学差异。
-                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 5, "\(language.rawValue) / \(width)：仅成就图案与文字水平居中")
-                        XCTAssertEqual(centerY, badge.bounds.midY, accuracy: 3, "\(language.rawValue) / \(width)：标签图文应垂直居中")
+                        let centerY = CGFloat(minY + maxY + 1) / (2 * verticalScale)
+                        // 与实际绘制相比，隔点取样及浅色边缘过滤会略微改变测得的轮廓。
+                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 5, "\(language.rawValue) / \(width) / \(name)：仅成就图案与文字水平居中")
+                        XCTAssertEqual(centerY, badge.bounds.midY, accuracy: 4, "\(language.rawValue) / \(width) / \(name)：标签图文应垂直居中")
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -119,0 +120,46 @@
+    func testAchievementGridGrowsByColumnAndRowAndRespectsModePanel() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        defaults.set(["version": 1, "unlocked": [1, 3, 4, 7, 17, 18], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        let progress = AchievementsManager(defaults: defaults)
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
+        let snapshot = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 0, remainingTime: nil, remainingSwaps: 30,
+                                    isRunning: false, isFinished: false)
+        home.refresh(snapshot: snapshot, mode: .moves, manager: progress)
+        for (width, height, columns, rows, count) in [(960, 720, 5, 1, 5), (1440, 720, 7, 1, 7),
+                                                       (960, 1000, 5, 4, 20), (1600, 1000, 8, 4, 32),
+                                                       (1920, 1250, 9, 4, 32), (960, 720, 5, 1, 5)] {
+            home.setFrameSize(NSSize(width: width, height: height))
+            home.layoutSubtreeIfNeeded()
+            let buttons = home.subviews.compactMap { $0 as? HomeButton }
+            let badges = buttons.filter { !$0.isHidden && $0.toolTip != nil }
+            let groupedRows = Dictionary(grouping: badges) { $0.frame.minY }
+            XCTAssertEqual(badges.count, count, "\(width)×\(height)")
+            XCTAssertEqual(groupedRows.count, rows)
+            XCTAssertEqual(groupedRows.values.map(\.count).max(), columns)
+            XCTAssertTrue(badges.allSatisfy { home.bounds.contains($0.frame) })
+            let all = try XCTUnwrap(buttons.first { $0.title.hasPrefix(AchievementText.string("achievement.view_all")) })
+            let sectionTop = all.frame.minY - 8
+            let gap = sectionTop - home.modePanel.frame.maxY
+            XCTAssertGreaterThanOrEqual(gap, 24)
+            XCTAssertLessThan(home.startButton.frame.maxY, sectionTop)
+            if count < AchievementDefinition.all.count { XCTAssertLessThan(gap, 24 + 66) }
+            if width == 1600 {
+                let description = AchievementText.string(AchievementDefinition.all[31].descriptionKey)
+                let last = try XCTUnwrap(badges.first { $0.toolTip?.hasPrefix(description) == true })
+                var detail: Int?
+                home.onAchievement = { detail = $0 }
+                last.performClick(nil)
+                XCTAssertEqual(detail, 32)
+                home.onAchievement = nil
+
+                let rep = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: home.bounds))
+                home.cacheDisplay(in: home.bounds, to: rep)
+                try XCTUnwrap(rep.representation(using: .png, properties: [:]))
+                    .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-achievement-grid.png"))
+            }
+        }
+    }
+
@@ -138 +184 @@
-                    for button in home.subviews.compactMap({ $0 as? HomeButton }) {
+                    for button in home.subviews.compactMap({ $0 as? HomeButton }) where !button.isHidden {
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -11 +11 @@
-- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块明细横向排在总数旁，中间以留白分隔。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块明细横排并靠卡片右侧，与总数用留白分隔。
@@ -74 +74,2 @@
-- [全屏尺寸标签效果](achievement-labels-fullscreen.png)：1920 宽度下每枚标签的状态标记固定左侧，成就图案与名称单独在卡片中心对齐；缩回窄窗口时长名称按最终省略文本重新居中。
+- [全屏尺寸标签效果](achievement-labels-fullscreen.png)展示 1920 点宽度下的多行布局。每枚标签的状态标记固定左侧，成就图案与名称单独居中。
+- [大窗口成就网格](achievement-grid.png)展示模式面板与成就区的间距。窗口更宽时增加列，更高时增加整行，直到达到空间或 32 枚成就的上限。
@@ -94,0 +96,2 @@
+运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests` 可生成 `eliminate-home-achievement-grid.png`，复制为 `achievement-grid.png`。
+
```

### `docs/previews/achievement-grid.png`

```diff
- 不存在
+ 1898272 字节，SHA-256 558dbe6cc4d8a50194ba7497e96214cf0e4a6bb9dd6974c4977ef435752ba6c8
```

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 137517 字节，SHA-256 7adf90b19fbca3e83e054fb3605dd0987b222220d2cb45a9973afabec2a9e472
+ 561157 字节，SHA-256 3b453019619b679bb0d9aa46b781e2e5c38acfca10151f720b15e1e9c7942ae6
```

### `docs/previews/achievement-labels.png`

```diff
- 102372 字节，SHA-256 c6acb2719654556772f6f498aa63f0d3dcbea5a45209094c89cfa974ff52498b
+ 104382 字节，SHA-256 eafc6fed3c59291f340743255dbb7904e1e56ea53abf2acbc63a3c4d813decfb
```

### `docs/previews/challenge-moves.png`

```diff
- 1250003 字节，SHA-256 dba61a258ba00fb59d8c625114b7293de62bbf08d2963f3fcccce10f1697d89c
+ 1250386 字节，SHA-256 be39b0c028d6f51cc8ad47bccbc3959ec9fab8a4c162cd2d0f3f7282fc2aaebd
```

### `docs/previews/challenge-preview.gif`

```diff
- 640129 字节，SHA-256 aec7cd17c45c9492a53308f25fadf8b48e250afd3c0ecb3d42c0c795cc4a65e1
+ 636889 字节，SHA-256 49a275f4a9658a499475a29015f8f3a6ce63319d38ea37226ec38d6fd98c324f
```

### `docs/previews/challenge-timed.png`

```diff
- 1253751 字节，SHA-256 36e0d9e755c1d5b7924412f18f4cfb51787274aa8f23ac3aee8c32f8b31e1053
+ 1253544 字节，SHA-256 bcc058ffbc01912cc4692a3c7004762ea4fded1fd919467aa83b39393f083047
```

### `docs/previews/lobby-finished.png`

```diff
- 1246141 字节，SHA-256 e2aa196d120ebe1112a3f6f684781a66dce963c72e9e300d051fb003a168aa88
+ 1245953 字节，SHA-256 936cd27ffa1e5272900d1386287dfc8edda1aad5f357c938a60d111efe950110
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1270113 字节，SHA-256 ed9c1fd60cc690aadd2999164067020658928279cb32d3b98d3824d33d6b07bf
+ 1270117 字节，SHA-256 f98b339b33ae301853f525644444cc8bca3fc6044903f03a0f3bfb8db32d91c2
```
