# 选中挑战即预览并推开首页文案

## 背景与目标

- 会话-175 起，选中限时或限步就展示限制规则和消除统计，开局按钮仍负责开始游戏。
- 左上角转场持续 2 秒，卡片从右向左滑入并逐渐显现。卡片前沿接近文字后，两者一起向左移动，文字随后淡出。
- 本轮工作区保留上一轮「合并统计与解谜入口」的未提交变更。下面的 diff 以本轮开始前的内容为基线。

## 实施结果

- [x] 限时预览显示「时间限制」和 01:00，限步预览显示「交换上限」和 30，两者都显示本局消除总数及四类方块明细。
- [x] 转场使用固定裁切边界、轻微升起、透明度过渡和沿卡面一次掠过的斜向高光。
- [x] 在两种挑战之间切换时，离场卡保留旧规则，再由新卡接替。切回自由时，主文案回到左上角。
- [x] 同一模式的快照刷新及正式开局延续当前过渡。开始后改用剩余预算标签，游戏规则与计时继续由棋盘控制器负责。
- [x] 系统启用减少动态效果时，转场直接定位。新增中、英、日、韩、俄五种语言的限制标签。

## 测试方法与结果

- 执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。2026-11-22 13:21 完成，87 项测试通过，0 失败。
- 可控时钟验证卡片从右侧进入、接近后推动文案、精确在 2 秒归位。检查重复刷新、两种挑战切换、动画中开局和减少动态效果。
- 通过正常模式按钮验证选中限时后等待 90 秒仍显示 01:00，棋盘保持待机。检查限步预览也能在开局前显示。
- 核对真实 AppKit 动图的首帧与转场画面。手动复核可运行 `./run.sh`，从自由切换到限时或限步，再点击开始查看预算标签变化。
- `git diff --check` 通过。

[查看挑战卡转场动图](../../docs/previews/challenge-preview.gif)

## 本轮全部增量 diff

文本使用统一 diff 逐行记录，新增动图记录字节数与 SHA-256。本文件不记录自身。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122131153-animate-challenge-preview-entry.md` - 会话-175 起让限时和限步选中即显示挑战卡，卡片在 2 秒内从右向左浮现并推开文案。含动图、开局计时边界、五语言与逐行 diff。
@@ -89,0 +91 @@
+- 需要调整挑战选中后的两秒滑入、文案推出、预览与开局的边界，或查看动图时，读取 `20261122131153-animate-challenge-preview-entry.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -6,0 +7 @@
+    var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
@@ -15 +16,5 @@
-    private var budgetLabelKey: String { mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left" }
+    private var budgetLabelKey: String {
+        let isPreview = snapshot?.isRunning == false && snapshot?.isFinished == false
+        if mode == .timed { return isPreview ? "home.challenge.time_limit" : "home.challenge.time_left" }
+        return isPreview ? "home.challenge.move_limit" : "home.challenge.moves_left"
+    }
@@ -47 +52 @@
-        let urgent = showsBudget && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
+        let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
@@ -71,0 +77,23 @@
+        if let revealFraction { drawRevealHighlight(in: face, accent: accent, fraction: revealFraction) }
+    }
+
+    private func drawRevealHighlight(in face: NSRect, accent: NSColor, fraction: CGFloat) {
+        // 随滑入从右向左掠过一次，收尾时完全淡出，只照亮卡面。
+        let intensity = sin(.pi * fraction)
+        guard intensity > 0 else { return }
+        NSGraphicsContext.saveGraphicsState()
+        let outline = NSBezierPath(roundedRect: face, xRadius: 18, yRadius: 18)
+        outline.addClip()
+        let x = face.maxX + 90 - (face.width + 180) * fraction
+        let shine = NSBezierPath()
+        shine.move(to: NSPoint(x: x, y: face.minY))
+        shine.line(to: NSPoint(x: x + 135, y: face.minY))
+        shine.line(to: NSPoint(x: x + 83, y: face.maxY))
+        shine.line(to: NSPoint(x: x - 52, y: face.maxY))
+        shine.close()
+        NSGradient(colors: [.clear, .white.withAlphaComponent(0.42 * intensity), accent.withAlphaComponent(0.12 * intensity), .clear])?
+            .draw(in: shine, angle: 0)
+        accent.withAlphaComponent(0.32 * intensity).setStroke()
+        outline.lineWidth = 2
+        outline.stroke()
+        NSGraphicsContext.restoreGraphicsState()
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -184,3 +184,2 @@
-    let challengeHUD = HomeChallengeHUDView(frame: .zero)
-    private let heading = NSTextField(wrappingLabelWithString: "")
-    private let subtitle = NSTextField(wrappingLabelWithString: "")
+    let modeHeader = HomeModeHeaderView(frame: .zero)
+    var challengeHUD: HomeChallengeHUDView { modeHeader.card }
@@ -194 +192,0 @@
-    private var showsSession = false
@@ -207,4 +205,2 @@
-        for label in [heading, subtitle, hint] { label.isSelectable = false; label.drawsBackground = false }
-        heading.textColor = HomeStyle.ink
-        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
-        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
+        hint.isSelectable = false
+        hint.drawsBackground = false
@@ -214,2 +210 @@
-        [heading, subtitle, hint, hero, challengeHUD, startButton, records, rules, settings, all].forEach { addSubview($0) }
-        challengeHUD.isHidden = true
+        [hint, hero, modeHeader, startButton, records, rules, settings, all].forEach { addSubview($0) }
@@ -239,7 +234 @@
-        showsSession = !isStarting && (snapshot.isRunning || snapshot.isFinished)
-        challengeHUD.isHidden = !showsSession
-        challengeHUD.refresh(snapshot: snapshot, mode: mode)
-        heading.isHidden = showsSession
-        subtitle.isHidden = showsSession
-        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
-        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
+        modeHeader.refresh(snapshot: snapshot, mode: mode, isStarting: isStarting)
@@ -280,6 +269 @@
-        heading.font = .systemFont(ofSize: min(60, max(44, leftWidth * 0.092)), weight: .heavy)
-        heading.preferredMaxLayoutWidth = leftWidth
-        heading.frame = NSRect(x: margin, y: top + 26, width: leftWidth, height: bodyHeight * 0.32)
-        subtitle.preferredMaxLayoutWidth = leftWidth
-        subtitle.frame = NSRect(x: margin, y: top + bodyHeight * 0.33, width: leftWidth, height: 56)
-        challengeHUD.frame = NSRect(x: margin, y: top + 12, width: leftWidth, height: 148)
+        modeHeader.frame = NSRect(x: margin, y: top, width: leftWidth, height: bodyHeight * 0.33 + 56)
@@ -289,4 +273 @@
-        let heroHeight: CGFloat = 138
-        let sessionHeroY = (challengeHUD.frame.maxY + hint.frame.minY - heroHeight) / 2
-        hero.frame = NSRect(x: margin + 12, y: showsSession ? sessionHeroY : top + bodyHeight * 0.45,
-                            width: leftWidth - 24, height: heroHeight)
+        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.45, width: leftWidth - 24, height: 138)
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -253,0 +254,2 @@
+"home.challenge.time_limit" = "TIME LIMIT";
+"home.challenge.move_limit" = "SWAP LIMIT";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -246,0 +247,2 @@
+"home.challenge.time_limit" = "制限時間";
+"home.challenge.move_limit" = "交換回数の上限";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -246,0 +247,2 @@
+"home.challenge.time_limit" = "제한 시간";
+"home.challenge.move_limit" = "최대 교환 횟수";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -246,0 +247,2 @@
+"home.challenge.time_limit" = "ЛИМИТ ВРЕМЕНИ";
+"home.challenge.move_limit" = "ЛИМИТ ОБМЕНОВ";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -253,0 +254,2 @@
+"home.challenge.time_limit" = "时间限制";
+"home.challenge.move_limit" = "交换上限";
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -79 +79 @@
-                        XCTAssertEqual(home.challengeHUD.isHidden, !running)
+                        XCTAssertEqual(home.challengeHUD.isHidden, !running && mode == .free)
@@ -81 +81,2 @@
-                        XCTAssertTrue(home.bounds.contains(home.challengeHUD.frame))
+                        let hudRect = home.challengeHUD.convert(home.challengeHUD.bounds, to: home)
+                        XCTAssertTrue(home.bounds.contains(hudRect))
@@ -84 +85 @@
-                        XCTAssertLessThan(home.challengeHUD.frame.maxX, cards[0].frame.minX)
+                        XCTAssertLessThan(hudRect.maxX, cards[0].frame.minX)
@@ -91,0 +93,4 @@
+                        if !running && mode != .free {
+                            let key = mode == .timed ? "home.challenge.time_limit" : "home.challenge.move_limit"
+                            XCTAssertTrue(label.contains(AchievementText.string(key)))
+                        }
@@ -120,0 +126,79 @@
+    }
+
+    func testChallengePreviewSlidesForTwoSecondsAndKeepsItsProgressOnRoundStart() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        let window = NSWindow(contentRect: home.frame, styleMask: [.borderless], backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false
+        window.contentView = home
+        defer { window.close() }
+        let header = home.modeHeader
+        var clock: TimeInterval = 100
+        var reduceMotion = false
+        header.now = { clock }
+        header.reducesMotion = { reduceMotion }
+        let free = GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil, remainingSwaps: nil, isRunning: false, isFinished: false)
+        let timed = GameSnapshot(mode: .timed(duration: 60), elapsedTime: 0, remainingTime: 60, remainingSwaps: nil, isRunning: false, isFinished: false)
+        let moves = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 0, remainingTime: nil, remainingSwaps: 30, isRunning: false, isFinished: false)
+        home.refresh(snapshot: free, mode: .free, manager: manager)
+        home.layoutSubtreeIfNeeded()
+        let intro = try XCTUnwrap(header.subviews.first { !$0.isHidden })
+        home.refresh(snapshot: timed, mode: .timed, manager: manager)
+        let preview = home.challengeHUD
+        XCTAssertEqual(preview.frame.minX, header.bounds.width, accuracy: 1)
+        XCTAssertLessThan(preview.alphaValue, 0.2)
+
+        let steps = 32
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-challenge-preview.gif")
+        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
+        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        let duration = HomeModeHeaderView.previewDuration
+        XCTAssertEqual(duration, 2)
+        for step in 0...steps {
+            clock = 100 + duration * Double(step) / Double(steps)
+            header.advanceAnimation()
+            if step == steps / 2 {
+                let position = preview.frame.minX
+                XCTAssertGreaterThan(position, 0)
+                XCTAssertGreaterThan(preview.alphaValue, 0.2)
+                home.refresh(snapshot: timed, mode: .timed, manager: manager)
+                home.layoutSubtreeIfNeeded()
+                XCTAssertEqual(preview.frame.minX, position, accuracy: 1, "重复刷新不能重启动画")
+            }
+            if step == steps * 3 / 4 { XCTAssertLessThan(intro.frame.minX, 0, "卡片接触文案后将其向左推开") }
+            home.layoutSubtreeIfNeeded()
+            let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
+            home.cacheDisplay(in: header.frame, to: pixels)
+            let frame = try XCTUnwrap(pixels.cgImage)
+            if step == steps * 3 / 4 {
+                try XCTUnwrap(pixels.representation(using: .png, properties: [:]))
+                    .write(to: url.deletingLastPathComponent().appendingPathComponent("eliminate-challenge-preview-motion.png"))
+            }
+            let delay = step == steps ? 1.0 : duration / Double(steps)
+            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(gif))
+        XCTAssertEqual(preview.frame.minX, 0, accuracy: 1)
+        XCTAssertEqual(preview.alphaValue, 1)
+        XCTAssertTrue(intro.isHidden)
+
+        home.refresh(snapshot: moves, mode: .moves, manager: manager)
+        XCTAssertEqual(home.challengeHUD.budgetText, "30")
+        XCTAssertEqual(preview.mode, .timed, "离场卡保留原规则")
+        clock += 0.7
+        header.advanceAnimation()
+        let frameDuringEntry = home.challengeHUD.frame
+        let playing = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 1, remainingTime: nil, remainingSwaps: 29, isRunning: true, isFinished: false)
+        home.refresh(snapshot: playing, mode: .moves, manager: manager)
+        XCTAssertEqual(home.challengeHUD.frame, frameDuringEntry)
+        XCTAssertEqual(home.challengeHUD.budgetText, "29")
+        reduceMotion = true
+        header.advanceAnimation()
+        XCTAssertEqual(home.challengeHUD.frame.minX, 0, accuracy: 1)
+        XCTAssertTrue(preview.isHidden)
+        home.refresh(snapshot: free, mode: .free, manager: manager)
+        XCTAssertTrue(home.challengeHUD.isHidden)
+        XCTAssertFalse(intro.isHidden)
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -64 +64,2 @@
-        let board = board(now: { self.date })
+        var gameTime = date
+        let board = board(now: { gameTime })
@@ -71 +72 @@
-        let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeChallengeHUDView }.first)
+        let home = try XCTUnwrap(view as? HomeDashboardView)
@@ -82 +83 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
@@ -85 +86 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
@@ -88 +89 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 30, "点击已选模式不应重置本局")
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30, "点击已选模式不应重置本局")
@@ -92 +93,3 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 0)
+        XCTAssertFalse(home.challengeHUD.isHidden)
+        XCTAssertFalse(board.snapshot().isRunning)
@@ -98 +101 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 30)
@@ -107 +110,8 @@
-        XCTAssertEqual(stats.snapshot?.totalCleared, 0)
+        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 0)
+        XCTAssertFalse(home.challengeHUD.isHidden)
+        XCTAssertEqual(home.challengeHUD.budgetText, "01:00")
+        gameTime = gameTime.addingTimeInterval(90)
+        board.tick()
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertFalse(board.snapshot().isFinished)
+        XCTAssertEqual(home.challengeHUD.budgetText, "01:00", "等待开局期间保持完整时间限制")
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -9,0 +10 @@
+- [挑战卡选中动画](challenge-preview.gif)展示限时模式在开局前从右侧滑入，接触主文案后将它向左推开。限步使用相同动效并显示 30 次交换上限。
@@ -17,0 +19,2 @@
+
+挑战卡动图为 `eliminate-challenge-preview.gif`，去掉 `eliminate-` 前缀后归档。
```

### `Sources/HomeModeHeaderView.swift`

```diff
--- /dev/null
+++ b/Sources/HomeModeHeaderView.swift
@@ -0,0 +1,211 @@
+import Cocoa
+
+/// 左上区域的独立转场。裁切边界固定，文案和卡片在同一列内滑动。
+final class HomeModeHeaderView: NSView {
+    static let previewDuration: TimeInterval = 2
+    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
+    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
+
+    private let intro = HomeModeIntroView(frame: .zero)
+    private(set) var card = HomeChallengeHUDView(frame: .zero)
+    private var spareCard = HomeChallengeHUDView(frame: .zero)
+    private var selectedMode: HomeGameMode?
+    private var showsCard = false
+    private var timer: Timer?
+    private var transition: Transition?
+
+    private struct Transition {
+        let outgoing: NSView
+        let incoming: NSView
+        let direction: CGFloat
+        let start: TimeInterval
+        let duration: TimeInterval
+        let outgoingOffset: CGFloat
+        let incomingOffset: CGFloat
+        let outgoingAlpha: CGFloat
+        let incomingAlpha: CGFloat
+        var fraction: CGFloat = 0
+    }
+
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        wantsLayer = true
+        layer?.masksToBounds = true
+        addSubview(intro)
+        addSubview(spareCard)
+        addSubview(card)
+        settle()
+    }
+
+    required init?(coder: NSCoder) { nil }
+    deinit { timer?.invalidate() }
+
+    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, isStarting: Bool) {
+        let shouldShowCard = mode != .free || (!isStarting && (snapshot.isRunning || snapshot.isFinished))
+        let changedMode = selectedMode.map { $0 != mode } ?? false
+        let previousView = showsCard ? card as NSView : intro
+        if changedMode, showsCard {
+            // 切换挑战时保留旧卡的快照，避免滑出过程中先变成下一种模式。
+            let previousCard = card
+            card = spareCard
+            spareCard = previousCard
+        } else if changedMode, shouldShowCard, !spareCard.isHidden, spareCard.mode == mode {
+            // 用户在返回过程中改主意时，沿用仍在画面中的同一张卡。
+            let nextCard = spareCard
+            spareCard = card
+            card = nextCard
+        }
+        let activeView = shouldShowCard ? card as NSView : intro
+        selectedMode = mode
+        showsCard = shouldShowCard
+        card.refresh(snapshot: snapshot, mode: mode)
+        if activeView === intro { intro.refresh(mode: mode) }
+
+        if changedMode, previousView !== activeView, window != nil, bounds.width > 0, !reducesMotion() {
+            animate(from: previousView, to: activeView, entersFromRight: shouldShowCard)
+        } else if changedMode || previousView !== activeView || transition == nil {
+            settle()
+        }
+    }
+
+    private func animate(from outgoing: NSView, to incoming: NSView, entersFromRight: Bool) {
+        // 位置以列宽为单位保存，快速切换和调整窗口大小时从当前画面继续。
+        let direction: CGFloat = entersFromRight ? 1 : -1
+        let incomingWasVisible = !incoming.isHidden
+        transition = Transition(outgoing: outgoing, incoming: incoming, direction: direction,
+                                start: now(), duration: entersFromRight ? Self.previewDuration : 0.46,
+                                outgoingOffset: outgoing.frame.minX / bounds.width,
+                                incomingOffset: incomingWasVisible ? incoming.frame.minX / bounds.width : direction,
+                                outgoingAlpha: outgoing.alphaValue,
+                                incomingAlpha: incomingWasVisible ? incoming.alphaValue : 0.12)
+        for item in subviews {
+            item.isHidden = item !== incoming && item !== outgoing
+            item.setAccessibilityHidden(item !== incoming)
+        }
+        addSubview(incoming, positioned: .above, relativeTo: outgoing)
+        placeSubviews()
+
+        timer?.invalidate()
+        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
+        RunLoop.main.add(timer, forMode: .common)
+        self.timer = timer
+    }
+
+    func advanceAnimation() {
+        guard var transition else { return }
+        let elapsed = max(0, now() - transition.start)
+        if elapsed >= transition.duration || reducesMotion() {
+            settle()
+        } else {
+            transition.fraction = CGFloat(elapsed / transition.duration)
+            self.transition = transition
+            placeSubviews()
+        }
+    }
+
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        if window == nil { settle() }
+    }
+
+    override func layout() {
+        super.layout()
+        placeSubviews()
+    }
+
+    private func settle() {
+        transition = nil
+        timer?.invalidate()
+        timer = nil
+        let activeView = showsCard ? card as NSView : intro
+        for item in subviews {
+            item.isHidden = item !== activeView
+            item.setAccessibilityHidden(item !== activeView)
+            item.alphaValue = 1
+        }
+        placeSubviews()
+    }
+
+    private func placeSubviews() {
+        guard let transition else {
+            place(intro, offset: 0)
+            place(card, offset: 0)
+            place(spareCard, offset: 0)
+            card.revealFraction = nil
+            spareCard.revealFraction = nil
+            return
+        }
+        let t = transition.fraction
+        let travel = t * t * (3 - 2 * t)
+        let incomingOffset = transition.incomingOffset * (1 - travel)
+        var outgoingOffset = transition.outgoingOffset * (1 - travel) - transition.direction * travel
+        var exitProgress = travel
+        if transition.outgoing === intro, transition.direction > 0, bounds.width > 0 {
+            // 卡片前沿先接近实际文字，再推着文字离场，避免两者隔着一整列空白一起移动。
+            let textWidth = min(1, (intro.contentWidth + 14) / bounds.width)
+            outgoingOffset = min(transition.outgoingOffset, incomingOffset - textWidth)
+            exitProgress = min(1, max(0, -outgoingOffset / textWidth))
+        }
+        place(transition.outgoing, offset: outgoingOffset)
+        place(transition.incoming, offset: incomingOffset, lift: transition.direction > 0 ? 7 * (1 - travel) : 0)
+        transition.outgoing.alphaValue = transition.outgoingAlpha * (1 - exitProgress * exitProgress)
+        transition.incoming.alphaValue = transition.incomingAlpha + (1 - transition.incomingAlpha) * travel
+        (transition.outgoing as? HomeChallengeHUDView)?.revealFraction = nil
+        (transition.incoming as? HomeChallengeHUDView)?.revealFraction = travel
+    }
+
+    private func place(_ view: NSView, offset: CGFloat, lift: CGFloat = 0) {
+        let x = offset * bounds.width
+        if view === intro {
+            view.frame = NSRect(x: x, y: 0, width: bounds.width, height: bounds.height)
+        } else {
+            view.frame = NSRect(x: x, y: 12 + lift, width: bounds.width, height: 148)
+        }
+    }
+}
+
+private final class HomeModeIntroView: NSView {
+    private let heading = NSTextField(wrappingLabelWithString: "")
+    private let subtitle = NSTextField(wrappingLabelWithString: "")
+
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        heading.textColor = HomeStyle.ink
+        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
+        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
+        addSubview(heading)
+        addSubview(subtitle)
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    var contentWidth: CGFloat {
+        max(lineWidth(in: heading), lineWidth(in: subtitle))
+    }
+
+    private func lineWidth(in label: NSTextField) -> CGFloat {
+        guard let font = label.font else { return 0 }
+        return label.stringValue.split(separator: "\n").map { line in
+            (String(line) as NSString).size(withAttributes: [.font: font]).width
+        }.max() ?? 0
+    }
+
+    func refresh(mode: HomeGameMode) {
+        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
+        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
+    }
+
+    override func layout() {
+        super.layout()
+        heading.font = .systemFont(ofSize: min(60, max(44, bounds.width * 0.092)), weight: .heavy)
+        heading.preferredMaxLayoutWidth = bounds.width
+        subtitle.preferredMaxLayoutWidth = bounds.width
+        let subtitleY = bounds.height - 56
+        heading.frame = NSRect(x: 0, y: 26, width: bounds.width, height: max(0, subtitleY - 4))
+        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: 56)
+    }
+}
```

### `docs/previews/challenge-preview.gif`

```diff
- 不存在（新增动图）
+ 831883 字节，SHA-256 016c3e7531638fea8c34a7b8d3f027eace80762b2152b4f00895d64ed8eb19e8
```
