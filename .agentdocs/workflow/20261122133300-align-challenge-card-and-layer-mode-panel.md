# 对齐统计卡顶边并调整转场层级

## 背景与目标

会话-180 起，规则与统计卡需要顶边对齐右侧「游戏模式」面板。滑动时卡面跨过左栏边界，右侧模式面板仅遮挡与它重叠的部分。

## 实施与结果

- [x] 两张卡以同一条顶线定位。统计卡按实际绘制面计算位置，保留阴影视觉所需的内边距。整个两秒滑动过程保持顶边齐平。
- [x] 将转场区域扩展到整行宽度，保留左栏的停靠位置。卡面经过两栏间距时完整可见。
- [x] 独立绘制右侧模式面板并把模式按钮放入面板内。模式选择面板遮挡从它后方经过的统计卡。
- [x] 更新挑战卡动图与四份局内预览，包含左侧溢出和右侧遮挡的实际画面。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameLobbyPresentationTests` 通过 6 项。在五种语言及多种窗口尺寸下核对顶边，并逐帧检查动画。通过实际像素比对确认卡片在两栏间隙可见，右侧重叠处由前景面板完整遮挡。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter HomeDashboardTests` 通过 6 项。验证模式按钮、开局和实时统计。
- `git diff --check` 通过。可运行 `./run.sh` 从自由切换至限时或限步，观察统计卡从模式面板后方滑出。
- [查看实际转场动图](../../docs/previews/challenge-preview.gif)与[对齐后的局内预览](../../docs/previews/challenge-timed.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区，保留之前两轮未提交的改动。文本采用统一 diff 逐行记录，二进制注明字节数与 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122133300-align-challenge-card-and-layer-mode-panel.md` - 会话-180 起对齐统计卡与右侧模式面板顶边，放宽横向转场区域并让右侧面板遮挡重叠部分。含实际像素回归、动图和本轮完整 diff。
@@ -90,0 +92 @@
+- 需要调整挑战卡与模式面板的顶边对齐、转场遮挡和左栏溢出显示时，读取 `20261122133300-align-challenge-card-and-layer-mode-panel.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -4,0 +5,2 @@
+    static let surfaceInsetY: CGFloat = 5
+    var surfaceRect: NSRect { bounds.insetBy(dx: 3, dy: Self.surfaceInsetY) }
@@ -54 +56 @@
-        let face = bounds.insetBy(dx: 3, dy: 5)
+        let face = surfaceRect
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -184,0 +185 @@
+    let modePanel = HomeModePanelView(frame: .zero)
@@ -210 +211,2 @@
-        [hint, hero, modeHeader, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        // 转场盖住左侧画面，右侧不透明模式面板与其按钮在转场上方。
+        [hint, hero, modeHeader, modePanel, startButton, records, rules, settings, all].forEach { addSubview($0) }
@@ -220 +222 @@
-            addSubview(button); modes.append(button)
+            modePanel.addSubview(button); modes.append(button)
@@ -224 +226 @@
-        addSubview(puzzle, positioned: .above, relativeTo: modes[0])
+        modePanel.addSubview(puzzle, positioned: .above, relativeTo: modes[0])
@@ -247,0 +250 @@
+        modePanel.needsDisplay = true
@@ -269 +272,3 @@
-        modeHeader.frame = NSRect(x: margin, y: top, width: leftWidth, height: bodyHeight * 0.33 + 56)
+        let leftColumn = NSRect(x: margin, y: top, width: leftWidth, height: bodyHeight * 0.33 + 56)
+        modeHeader.position(leftColumn: leftColumn, windowWidth: bounds.width, modePanelLeading: panel.minX)
+        modePanel.frame = panel
@@ -277 +282 @@
-            button.frame = NSRect(x: panel.minX + 20, y: top + 60 + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
+            button.frame = NSRect(x: 20, y: 60 + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
@@ -294,2 +298,0 @@
-        GameLobbyStyle.surface(panel, radius: 20,
-                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
@@ -308 +310,0 @@
-        HomeStyle.text(AchievementText.string("home.game_modes"), in: NSRect(x: panel.minX + 22, y: 114, width: panel.width - 44, height: 36), size: 27, weight: .heavy)
@@ -327,0 +330,19 @@
+
+/// 单独绘制右侧外框，让它能遮住滑到后方的统计卡。
+final class HomeModePanelView: NSView {
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        wantsLayer = true
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    override func draw(_ dirtyRect: NSRect) {
+        GameLobbyStyle.surface(bounds, radius: 20,
+                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
+        HomeStyle.text(AchievementText.string("home.game_modes"),
+                       in: NSRect(x: 22, y: 18, width: bounds.width - 44, height: 36), size: 27, weight: .heavy)
+    }
+}
```

### `Sources/HomeModeHeaderView.swift`

```diff
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -3 +3 @@
-/// 左上区域的独立转场。裁切边界固定，文案和卡片在同一列内滑动。
+/// 转场覆盖窗口上方整行，左列只负责定位。右侧模式面板由大厅单独叠在前方。
@@ -15,0 +16,2 @@
+    private var column = NSRect.zero
+    private var entryX: CGFloat = 0
@@ -43,0 +46,13 @@
+
+    func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
+        let topPadding: CGFloat = 8
+        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
+        column = leftColumn.offsetBy(dx: 0, dy: -frame.minY)
+        entryX = modePanelLeading
+        needsLayout = true
+    }
+
+    override func hitTest(_ point: NSPoint) -> NSView? {
+        let hit = super.hitTest(point)
+        return hit === self ? nil : hit
+    }
@@ -66 +81 @@
-        if changedMode, previousView !== activeView, window != nil, bounds.width > 0, !reducesMotion() {
+        if changedMode, previousView !== activeView, window != nil, column.width > 0, !reducesMotion() {
@@ -76,0 +92 @@
+        let initialOffset = entersFromRight ? (entryX - column.minX) / column.width : -1
@@ -79,2 +95,2 @@
-                                outgoingOffset: outgoing.frame.minX / bounds.width,
-                                incomingOffset: incomingWasVisible ? incoming.frame.minX / bounds.width : direction,
+                                outgoingOffset: (outgoing.frame.minX - column.minX) / column.width,
+                                incomingOffset: incomingWasVisible ? (incoming.frame.minX - column.minX) / column.width : initialOffset,
@@ -82 +98 @@
-                                incomingAlpha: incomingWasVisible ? incoming.alphaValue : 0.12)
+                                incomingAlpha: incomingWasVisible ? incoming.alphaValue : 0)
@@ -145 +161 @@
-        if transition.outgoing === intro, transition.direction > 0, bounds.width > 0 {
+        if transition.outgoing === intro, transition.direction > 0, column.width > 0 {
@@ -147 +163 @@
-            let textWidth = min(1, (intro.contentWidth + 14) / bounds.width)
+            let textWidth = min(1, (intro.contentWidth + 14) / column.width)
@@ -152 +168 @@
-        place(transition.incoming, offset: incomingOffset, lift: transition.direction > 0 ? 7 * (1 - travel) : 0)
+        place(transition.incoming, offset: incomingOffset)
@@ -159,2 +175,2 @@
-    private func place(_ view: NSView, offset: CGFloat, lift: CGFloat = 0) {
-        let x = offset * bounds.width
+    private func place(_ view: NSView, offset: CGFloat) {
+        let x = column.minX + offset * column.width
@@ -162 +178 @@
-            view.frame = NSRect(x: x, y: 0, width: bounds.width, height: bounds.height)
+            view.frame = NSRect(x: x, y: column.minY, width: column.width, height: column.height)
@@ -164 +180,2 @@
-            view.frame = NSRect(x: x, y: 12 + lift, width: bounds.width, height: 148)
+            // 对齐画出来的卡面顶边，视图本身预留阴影内边距。
+            view.frame = NSRect(x: x, y: column.minY - HomeChallengeHUDView.surfaceInsetY, width: column.width, height: 148)
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -83 +83 @@
-                        let cards = home.subviews.compactMap { $0 as? HomeModeButton }.sorted { $0.frame.minY < $1.frame.minY }
+                        let cards = home.modePanel.subviews.compactMap { $0 as? HomeModeButton }.sorted { $0.frame.minY < $1.frame.minY }
@@ -85 +85,3 @@
-                        XCTAssertLessThan(hudRect.maxX, cards[0].frame.minX)
+                        XCTAssertLessThan(hudRect.maxX, home.modePanel.frame.minX)
+                        let surface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home)
+                        XCTAssertEqual(surface.minY, home.modePanel.frame.minY, accuracy: 0.1)
@@ -148,0 +151 @@
+        let restingX = intro.frame.minX
@@ -151 +154 @@
-        XCTAssertEqual(preview.frame.minX, header.bounds.width, accuracy: 1)
+        XCTAssertEqual(preview.frame.minX, home.modePanel.frame.minX, accuracy: 1)
@@ -165 +168 @@
-                XCTAssertGreaterThan(position, 0)
+                XCTAssertGreaterThan(position, restingX)
@@ -169,0 +173 @@
+                try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview)
@@ -171 +175,2 @@
-            if step == steps * 3 / 4 { XCTAssertLessThan(intro.frame.minX, 0, "卡片接触文案后将其向左推开") }
+            if step == steps * 3 / 4 { XCTAssertLessThan(intro.frame.minX, restingX, "卡片接触文案后将其向左推开") }
+            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, home.modePanel.frame.minY, accuracy: 0.1)
@@ -184 +189 @@
-        XCTAssertEqual(preview.frame.minX, 0, accuracy: 1)
+        XCTAssertEqual(preview.frame.minX, restingX, accuracy: 1)
@@ -200 +205 @@
-        XCTAssertEqual(home.challengeHUD.frame.minX, 0, accuracy: 1)
+        XCTAssertEqual(home.challengeHUD.frame.minX, restingX, accuracy: 1)
@@ -204,0 +210,25 @@
+    }
+
+    private func assertPreviewLaysOverGapAndBehindPanel(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
+        let panel = home.modePanel.frame
+        let surface = preview.convert(preview.surfaceRect, to: home)
+        let gapPoint = NSPoint(x: panel.minX - 14, y: panel.minY + 43)
+        let panelPoint = NSPoint(x: panel.minX + 10, y: gapPoint.y)
+        XCTAssertTrue(surface.contains(gapPoint) && surface.contains(panelPoint))
+
+        func color(at point: NSPoint) throws -> NSColor {
+            let rect = NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
+            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: rect))
+            home.cacheDisplay(in: rect, to: bitmap)
+            return try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
+        }
+        func difference(_ first: NSColor, _ second: NSColor) -> CGFloat {
+            abs(first.redComponent - second.redComponent) + abs(first.greenComponent - second.greenComponent) + abs(first.blueComponent - second.blueComponent)
+        }
+
+        let visibleGap = try color(at: gapPoint)
+        let visiblePanel = try color(at: panelPoint)
+        preview.isHidden = true
+        defer { preview.isHidden = false }
+        XCTAssertGreaterThan(difference(visibleGap, try color(at: gapPoint)), 0.012, "超出左栏的卡面应进入两栏间隙")
+        XCTAssertLessThan(difference(visiblePanel, try color(at: panelPoint)), 0.008, "右侧面板应在重叠处完整盖住统计卡")
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -10 +10 @@
-- [挑战卡选中动画](challenge-preview.gif)展示限时模式在开局前从右侧滑入，接触主文案后将它向左推开。限步使用相同动效并显示 30 次交换上限。
+- [挑战卡选中动画](challenge-preview.gif)展示限时模式开局前从右侧模式面板后方滑出，越过两栏间隙后把主文案向左推开。统计卡和模式面板顶边齐平，限步沿用同样动效。
```

### `docs/previews/challenge-moves.png`

```diff
- 1281212 字节，SHA-256 6ab4affbb56b5eb322fdaa145132200a873643cacc9f4d931d7c0468566a229e
+ 1270754 字节，SHA-256 e268341fd2b10546e4d1227fd59ea9992d179adb2270fb2886b5b259ff976f80
```

### `docs/previews/challenge-preview.gif`

```diff
- 831883 字节，SHA-256 016c3e7531638fea8c34a7b8d3f027eace80762b2152b4f00895d64ed8eb19e8
+ 916472 字节，SHA-256 6a9a21d1f6842a3ed865054051a56f3fecec556687de789a222e1b3f2a4ea77f
```

### `docs/previews/challenge-timed.png`

```diff
- 1278575 字节，SHA-256 1b72faeceefe6e69fc722d704a899b5d5074290cf83fcc34298edddd9218b407
+ 1267125 字节，SHA-256 f6bd542ecc895507edea557710c3853199b01359ca3339f13c60f1fe072cd789
```

### `docs/previews/lobby-finished.png`

```diff
- 1274254 字节，SHA-256 f216a1976afa99bb49e02fbb4aa780009b694923be457295683911991d470aee
+ 1267390 字节，SHA-256 da1fb9899303c18a2bfa78c26f8bb3f8e3f328a65a449630a4826df2e83fedf6
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1297567 字节，SHA-256 9b02cd86119e14d8fea1aa6c4514e3f56a59b92d1bac06e97b84779a00bcf655
+ 1287953 字节，SHA-256 f2fe6ca8e079577f9d592332ba9f22c4d3c9f1be776e094e312f5a632901e8ef
```
