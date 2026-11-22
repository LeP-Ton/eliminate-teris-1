# 一秒挑战卡入场与立体缩放

## 背景与目标

会话-184 起，将挑战预览入场缩短至一秒。卡片从右侧以小尺寸出现，滑动中逐渐放大，初始右端不超出屏幕。

## 实施结果

- [x] 入场过渡持续 1 秒。卡片从最终宽度的 20%、高度的 27% 开始，滑动时逐渐展开成正面并整体放大。绘制内容使用同一坐标系缩放。
- [x] 增加带色侧缘、渐弱投影与掠过卡面的高光。卡片展开后，侧缘收回到静态阴影。
- [x] 起始位置同时考虑窗口边界和所在显示器的右边缘，按起始实际宽度留出边距。滑动途中也约束窗口内的右端，适应窗口缩放。
- [x] 缩放过程中卡面顶部保持对齐右侧模式面板。经过两栏间隙时可见，与右侧面板重叠时由右侧面板遮挡。
- [x] 动画期间开局延续当前进度，减少动态效果直接归位。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameLobbyPresentationTests` 完成，6 项通过，0 失败。
- 逐帧验证一秒时长、初始比例、持续放大、右端边界和顶边对齐。使用实际像素检查跨栏可见与右侧遮挡，并核对真机 AppKit 离屏渲染的中段画面。
- `git diff --check` 通过。运行 `./run.sh` 后切换限时或限步，可查看从右侧放大的效果。
- [查看一秒转场动图](../../docs/previews/challenge-preview.gif)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本采用统一 diff 逐行记录，动图注明字节数与 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122134514-shorten-challenge-preview-with-depth.md` - 会话-184 起把挑战卡入场改为一秒，以透视缩放、侧缘和阴影表现立体感，并限制起始右端。含回归、动图与完整 diff。
@@ -91,0 +93 @@
+- 需要调整当前的一秒挑战卡入场、小卡放大、立体侧缘或窗口与屏幕右边界时，读取 `20261122134514-shorten-challenge-preview-with-depth.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -57 +57,8 @@
-        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1))
+        let depth = revealFraction.map { 1 - $0 } ?? 0
+        if depth > 0 {
+            // 在卡面右下缘露出带色的厚度，转正时收回到静态卡面的阴影中。
+            let side = face.offsetBy(dx: 2.5 * depth, dy: 4.5 * depth)
+            GameLobbyStyle.gradient(side, colors: [accent.withAlphaComponent(0.26 * depth),
+                                                  accent.withAlphaComponent(0.68 * depth)], radius: 18)
+        }
+        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1), strength: 0.07 + 0.13 * depth)
```

### `Sources/HomeModeHeaderView.swift`

```diff
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -5 +5,5 @@
-    static let previewDuration: TimeInterval = 2
+    static let previewDuration: TimeInterval = 1
+    private static let cardHeight: CGFloat = 148
+    private static let fullScale = NSSize(width: 1, height: 1)
+    // 远处的卡片横向收得更多，靠近时逐渐展开成正面。
+    private static let distantScale = NSSize(width: 0.20, height: 0.27)
@@ -26,0 +31,2 @@
+        let outgoingScale: NSSize
+        let incomingScale: NSSize
@@ -92 +98,3 @@
-        let initialOffset = entersFromRight ? (entryX - column.minX) / column.width : -1
+        let incomingScale = incomingWasVisible ? scale(of: incoming) : entersFromRight ? Self.distantScale : Self.fullScale
+        let initialX = entersFromRight ? min(entryX, visibleRightEdge - column.width * incomingScale.width - 6) : column.minX - column.width
+        let initialOffset = (initialX - column.minX) / column.width
@@ -96,0 +105 @@
+                                outgoingScale: scale(of: outgoing), incomingScale: incomingScale,
@@ -109,0 +119,11 @@
+    }
+
+    private var visibleRightEdge: CGFloat {
+        guard let window, let screen = window.screen else { return bounds.maxX }
+        let point = NSPoint(x: screen.frame.maxX, y: screen.frame.midY)
+        return min(bounds.maxX, convert(window.convertPoint(fromScreen: point), from: nil).x)
+    }
+
+    private func scale(of view: NSView) -> NSSize {
+        guard view !== intro else { return Self.fullScale }
+        return NSSize(width: view.frame.width / column.width, height: view.frame.height / Self.cardHeight)
@@ -158 +178,8 @@
-        let incomingOffset = transition.incomingOffset * (1 - travel)
+        let incomingScale = NSSize(width: transition.incomingScale.width + (1 - transition.incomingScale.width) * travel,
+                                   height: transition.incomingScale.height + (1 - transition.incomingScale.height) * travel)
+        var incomingOffset = transition.incomingOffset * (1 - travel)
+        if transition.incoming !== intro, column.width > 0 {
+            // 窗口缩放期间也限制卡片右端，始终以完整卡面的实际尺寸计算。
+            let rightmostOffset = (bounds.maxX - column.minX) / column.width - incomingScale.width
+            incomingOffset = min(incomingOffset, rightmostOffset)
+        }
@@ -167,2 +194,2 @@
-        place(transition.outgoing, offset: outgoingOffset)
-        place(transition.incoming, offset: incomingOffset)
+        place(transition.outgoing, offset: outgoingOffset, scale: transition.outgoingScale)
+        place(transition.incoming, offset: incomingOffset, scale: incomingScale)
@@ -170 +197 @@
-        transition.incoming.alphaValue = transition.incomingAlpha + (1 - transition.incomingAlpha) * travel
+        transition.incoming.alphaValue = transition.incomingAlpha + (1 - transition.incomingAlpha) * sqrt(travel)
@@ -175 +202 @@
-    private func place(_ view: NSView, offset: CGFloat) {
+    private func place(_ view: NSView, offset: CGFloat, scale: NSSize = HomeModeHeaderView.fullScale) {
@@ -180,2 +207,4 @@
-            // 对齐画出来的卡面顶边，视图本身预留阴影内边距。
-            view.frame = NSRect(x: x, y: column.minY - HomeChallengeHUDView.surfaceInsetY, width: column.width, height: 148)
+            // 按完整卡面的坐标绘制，再缩放整个视图，使数字、图案和阴影一起放大。
+            view.frame = NSRect(x: x, y: column.minY - HomeChallengeHUDView.surfaceInsetY * scale.height,
+                                width: column.width * scale.width, height: Self.cardHeight * scale.height)
+            view.bounds = NSRect(x: 0, y: 0, width: column.width, height: Self.cardHeight)
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -130 +130 @@
-    func testChallengePreviewSlidesForTwoSecondsAndKeepsItsProgressOnRoundStart() throws {
+    func testChallengePreviewGrowsWithinScreenForOneSecondAndKeepsItsProgressOnRoundStart() throws {
@@ -151,0 +152 @@
+        let restingWidth = intro.frame.width
@@ -154 +155,5 @@
-        XCTAssertEqual(preview.frame.minX, home.modePanel.frame.minX, accuracy: 1)
+        XCTAssertGreaterThan(preview.frame.minX, restingX)
+        XCTAssertLessThanOrEqual(preview.frame.minX, home.modePanel.frame.minX + 0.1)
+        XCTAssertEqual(preview.frame.width, restingWidth * 0.20, accuracy: 0.1)
+        XCTAssertLessThan(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height)
+        try assertLaunchIsWithinScreen(preview, in: window)
@@ -157 +162 @@
-        let steps = 32
+        let steps = 25
@@ -162 +167,2 @@
-        XCTAssertEqual(duration, 2)
+        XCTAssertEqual(duration, 1)
+        var previousWidth = preview.frame.width
@@ -165,0 +172,3 @@
+            XCTAssertGreaterThanOrEqual(preview.frame.width + 0.1, previousWidth)
+            XCTAssertLessThanOrEqual(preview.frame.maxX, header.bounds.maxX + 0.1)
+            previousWidth = preview.frame.width
@@ -189,0 +199 @@
+        XCTAssertEqual(preview.frame.width, restingWidth, accuracy: 0.1)
@@ -209,0 +220,9 @@
+    }
+
+    private func assertLaunchIsWithinScreen(_ preview: HomeChallengeHUDView, in window: NSWindow) throws {
+        XCTAssertLessThanOrEqual(preview.frame.maxX, try XCTUnwrap(preview.superview).bounds.maxX + 0.1)
+        if let screen = window.screen {
+            let right = preview.convert(preview.bounds, to: nil).maxX
+            let launchRight = window.convertPoint(toScreen: NSPoint(x: right, y: 0)).x
+            XCTAssertLessThanOrEqual(launchRight, screen.frame.maxX + 0.1)
+        }
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -10 +10 @@
-- [挑战卡选中动画](challenge-preview.gif)展示限时模式开局前从右侧模式面板后方滑出，越过两栏间隙后把主文案向左推开。统计卡和模式面板顶边齐平，限步沿用同样动效。
+- [挑战卡选中动画](challenge-preview.gif)展示限时卡片在一秒内从右侧模式面板后方滑出。卡片从较小、偏窄的形态逐渐放大，侧缘和阴影随转场收拢，最终与模式面板顶边齐平。限步沿用同样动效。
```

### `docs/previews/challenge-preview.gif`

```diff
- 916472 字节，SHA-256 6a9a21d1f6842a3ed865054051a56f3fecec556687de789a222e1b3f2a4ea77f
+ 666893 字节，SHA-256 5a12821c092331b31e812ff23e968c0baf269cc1bfd509c6a3cfcc0b69105121
```
