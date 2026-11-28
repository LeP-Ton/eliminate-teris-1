# 自由模式统计背板的打字提示

## 背景与目标

- 会话-142 要求在自由模式统计背板显示「在自由模式中练习操作技巧」，逐字打出，左侧加入蓝色斜杠。

## 实施

- 自由模式的背板占用原轨道位置，按完整文案确定字号，蓝色斜杠采用大厅已有斜率。提示从左向右逐字显示，播放时长为 0.80 秒。
- 首次显示自由模式时直接打字。切回自由模式时，打字与前板上沿的扫光同时开始。同模式的快照更新继续当前进度。
- 背板的提示与挑战预算填充共用转场时钟。提示使用五种语言的本地化资源，无障碍读数包含完整句子。开启减少动态效果时直接显示全文。

## 验证

- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，110 项全部通过。
- 原生测试核对自由模式左部斜杠、提示首次显示、逐字顺序、同模式刷新及切回自由时的扫光同步。核对五种语言、紧凑窗口和原生打字动图。
- 运行 `./run.sh`，可在首次打开大厅或由挑战切回自由模式时查看提示。

## 本轮完整增量 diff

以会话-142 开始时的提交为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index a202d110a3d8e431ce9db59f8e6ab1f66f31bef5..3c7e4a14c63e0f76b2f2ed3d32bf2a1cb9ad11d5 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128101138-type-free-mode-practice-hint.md` - 会话-142 起在自由模式背板加入蓝色斜杠和逐字显示的练习提示。
 `workflow/20261128094456-synchronize-budget-fill-with-highlight.md` - 会话-136 起让统计卡预算填充和前板上沿扫光同步起播。
 `workflow/20261128090504-animate-statistics-budget-fill.md` - 会话-129 起在统计卡叠合后从零填充挑战预算，开局后动态跟随剩余值。
 `workflow/20261128084215-make-statistics-fade-visible.md` - 会话-124 起改为匀速淡入，每次换模式从透明起步，含真实窗口轨道像素实测。
@@ -121,6 +122,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整自由模式背板文案、蓝色斜杠、打字动画或首次进大厅的提示时，读取 `20261128101138-type-free-mode-practice-hint.md`。
 - 需要调整统计卡扫光和预算填充的共同起点，读取 `20261128094456-synchronize-budget-fill-with-highlight.md`。
 - 需要调整切换模式后的预算填充、开局时的剩余目标或限步分格显示时，读取 `20261128090504-animate-statistics-budget-fill.md`。
 - 需要调整统计卡淡入的可见节奏或验证快速换模式也从透明开始时，读取 `20261128084215-make-statistics-fade-visible.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 8416be417a7ae10d1e43230cccde1265946fdeaf..7193623d3c0bfdae39c6d0bc69f0c31614caf547 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -27,8 +27,13 @@ final class HomeChallengeHUDView: NSView {
     var plateAssembly = PlateAssembly.settled {
         didSet { if plateAssembly != oldValue { needsDisplay = true } }
     }
-    var budgetFillProgress: CGFloat = 1 {
-        didSet { if budgetFillProgress != oldValue { needsDisplay = true } }
+    var backingRevealProgress: CGFloat = 1 {
+        didSet { if backingRevealProgress != oldValue { needsDisplay = true } }
+    }
+    private var practiceHint = ""
+
+    var displayedPracticeHint: String {
+        String(practiceHint.prefix(Int(ceil(CGFloat(practiceHint.count) * backingRevealProgress))))
     }
 
     var backingPlateOffset: NSPoint {
@@ -186,7 +191,7 @@ final class HomeChallengeHUDView: NSView {
         return CGFloat(min(1, max(0, fraction)))
     }
 
-    var displayedBudgetFraction: CGFloat { remainingFraction * budgetFillProgress }
+    var displayedBudgetFraction: CGFloat { remainingFraction * backingRevealProgress }
 
     var budgetText: String {
         guard showsBudget, let snapshot else { return "" }
@@ -199,7 +204,12 @@ final class HomeChallengeHUDView: NSView {
         updateCountAnimation(snapshot: snapshot, mode: mode)
         self.snapshot = snapshot; self.mode = mode
         var labels: [String] = []
-        if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
+        practiceHint = showsBudget ? "" : AchievementText.string("home.practice_hint")
+        if showsBudget {
+            labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText)
+        } else {
+            labels.append(practiceHint)
+        }
         labels.append(AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
         labels += PieceKind.allCases.map { kind in
             AchievementText.string(kind.titleKey) + ": \(snapshot.clearedByKind[kind, default: 0])"
@@ -288,7 +298,11 @@ final class HomeChallengeHUDView: NSView {
         let frontFace = Face(frame: surface.offsetBy(dx: front.x, dy: front.y))
         drawPlates(opacity: plateAssembly.opacity) {
             drawBackingPlate(on: backFace)
-            if showsBudget { drawTrack(backFace.budgetTrack, accent: accent, snapshot: snapshot) }
+            if showsBudget {
+                drawTrack(backFace.budgetTrack, accent: accent, snapshot: snapshot)
+            } else {
+                drawPracticeHint(on: backFace)
+            }
             fill(HomeDashboardStyle.slant(frontFace.totals),
                  colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                           HomeDashboardStyle.color(0x101A25)], angle: 14, border: HomeDashboardStyle.color(0x57636B))
@@ -343,6 +357,24 @@ final class HomeChallengeHUDView: NSView {
         context.restoreGState()
     }
 
+    private func drawPracticeHint(on face: Face) {
+        let band = face.budgetTrack
+        let headerHeight = face.totals.minY - face.rules.minY
+        let markHeight = min(15, max(9, headerHeight * 0.38))
+        let markWidth = HomeDashboardStyle.edgeOffset(for: markHeight) + 4
+        let marker = NSRect(x: band.minX, y: band.midY - markHeight / 2, width: markWidth, height: markHeight)
+        HomeDashboardStyle.mark(in: marker)
+
+        let text = displayedPracticeHint
+        let x = marker.maxX + 9
+        let width = band.maxX - x - 4
+        guard !text.isEmpty, width > 0 else { return }
+        // 按完整文案计算字号，逐字显示时文字位置和大小不跳动。
+        let size = GameLobbyStyle.fittedSize(practiceHint, width: width, preferred: min(17, max(10, headerHeight * 0.38)),
+                                           minimum: 9, weight: .bold)
+        label(text, x: x, y: band.midY, width: width, size: size, weight: .bold)
+    }
+
     private func drawTotals(_ totalCleared: Int, on face: Face, accent: NSColor) {
         let body = face.box(478, 175, width: 506, height: 80)
         let x = body.minX
@@ -470,7 +502,7 @@ final class HomeChallengeHUDView: NSView {
             let limit = HomeGameMode.moveLimit
             let remaining = min(limit, max(0, snapshot.remainingSwaps ?? limit))
             // 第一格随扫光起播，其余格按填充进度逐个点亮。
-            let lit = Int(ceil(CGFloat(remaining) * budgetFillProgress))
+            let lit = Int(ceil(CGFloat(remaining) * backingRevealProgress))
             let cut = HomeDashboardStyle.edgeOffset(for: track.height)
             let available = max(0, track.width - cut)
             let gap = min(2, available / CGFloat(limit * 2))
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 4cfedae0ff3cdbecb9a58c87d7d6fad487729d2f..70b154d23197e82031eef6febac7bd33f78b230e 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -5,6 +5,7 @@ final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1.20
     static let joinHighlightStart: TimeInterval = previewDuration * 0.78
     static let budgetFillDuration: TimeInterval = 0.60
+    static let practiceHintDuration: TimeInterval = 0.80
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
@@ -12,6 +13,7 @@ final class HomeModeHeaderView: NSView {
     let card = HomeChallengeHUDView(frame: .zero)
     private var timer: Timer?
     private var transitionStart: TimeInterval?
+    private var backingRevealDelay: TimeInterval = 0
     private var isAssembling = false
     private var cardColumn = NSRect.zero
 
@@ -52,21 +54,35 @@ final class HomeModeHeaderView: NSView {
     }
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
-        let changedMode = card.snapshot != nil && card.mode != mode
+        let previousMode = card.snapshot.map { _ in card.mode }
         card.refresh(snapshot: snapshot, mode: mode)
         intro.refresh(mode: mode)
 
-        guard changedMode else { return }
+        guard let previousMode else {
+            startInitialPracticeHint()
+            return
+        }
+        guard previousMode != mode else { return }
         guard window != nil, cardColumn.width > 0, !reducesMotion() else {
             settle()
             return
         }
         // 每次换模式都从透明起步。已运行的定时器继续驱动新一轮叠合。
-        transitionStart = nil
         if !isAssembling { card.positionPlates(in: cardColumn, assembling: true) }
         isAssembling = true
         card.plateAssembly = .separated
-        card.budgetFillProgress = mode == .free ? 1 : 0
+        startBackingReveal(after: Self.joinHighlightStart)
+    }
+
+    private func startInitialPracticeHint() {
+        guard timer == nil, window != nil, card.snapshot != nil, card.mode == .free, !reducesMotion() else { return }
+        startBackingReveal(after: 0)
+    }
+
+    private func startBackingReveal(after delay: TimeInterval) {
+        transitionStart = nil
+        backingRevealDelay = delay
+        card.backingRevealProgress = 0
         guard timer == nil else { return }
 
         let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
@@ -87,16 +103,11 @@ final class HomeModeHeaderView: NSView {
             return
         }
         let elapsed = max(0, currentTime - transitionStart)
-        // 扫光和预算填充同一帧起播，各自按原时长结束。
+        // 切换模式时，背板内容和前板扫光共用起点。
         let highlightElapsed = elapsed - Self.joinHighlightStart
-        let fillProgress = min(1, max(0, highlightElapsed / Self.budgetFillDuration))
-        if elapsed >= Self.previewDuration {
-            guard card.mode != .free, fillProgress < 1 else {
-                settle()
-                return
-            }
-            finishAssembly()
-        } else {
+        let revealDuration = card.mode == .free ? Self.practiceHintDuration : Self.budgetFillDuration
+        let revealProgress = min(1, max(0, (elapsed - backingRevealDelay) / revealDuration))
+        if isAssembling, elapsed < Self.previewDuration {
             let time = CGFloat(elapsed / Self.previewDuration)
             let backingRemaining = 1 - min(1, time / 0.62)
             let frontTime = min(1, max(0, (time - 0.12) / 0.66))
@@ -106,13 +117,23 @@ final class HomeModeHeaderView: NSView {
                                        front: frontTime * frontTime * (3 - 2 * frontTime),
                                        opacity: opacity,
                                        highlight: highlight)
+        } else {
+            guard revealProgress < 1 else {
+                settle()
+                return
+            }
+            finishAssembly()
         }
-        if card.mode != .free { card.budgetFillProgress = CGFloat(fillProgress) }
+        card.backingRevealProgress = CGFloat(revealProgress)
     }
 
     override func viewDidMoveToWindow() {
         super.viewDidMoveToWindow()
-        if window == nil { settle() }
+        if window == nil {
+            settle()
+        } else {
+            startInitialPracticeHint()
+        }
     }
 
     override func layout() {
@@ -132,7 +153,7 @@ final class HomeModeHeaderView: NSView {
         timer?.invalidate()
         timer = nil
         finishAssembly()
-        card.budgetFillProgress = 1
+        card.backingRevealProgress = 1
     }
 }
 
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index 25e7710d0966f3a6b4515cb6f765bb2de07f889c..026cad80cd3ea7b53206be1f06105b2b0d087f0e 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -188,6 +188,7 @@
 "home.subtitle.free" = "No countdown. Play at your own pace.";
 "home.subtitle.timed" = "Clear as many tiles as you can in one minute.";
 "home.subtitle.moves" = "Take your time. Make every swap worthwhile.";
+"home.practice_hint" = "Practice your moves in free play";
 "home.mode.free" = "Free play";
 "home.mode.puzzle" = "Puzzle Mode";
 "home.mode.timed" = "Timed Challenge";
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index 2d0ef3c4010c03d88b80e8901f3e414fdba2c525..69e89a6a0820721e870c246ae6a12d8f850c435b 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -181,6 +181,7 @@
 "home.subtitle.free" = "時間を気にせず、自分のペースで。";
 "home.subtitle.timed" = "1 分間でできるだけ多く消そう。";
 "home.subtitle.moves" = "時間を気にせず、一手を大切に。";
+"home.practice_hint" = "フリーモードで操作を練習しよう";
 "home.mode.free" = "フリーモード";
 "home.mode.puzzle" = "パズルモード";
 "home.mode.timed" = "時間制チャレンジ";
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index 7fae830aa46d666762ad4bb40ac7fb59f57b7c38..f37e0a8fd6b229c99033c6c94e42f95ca1d7c931 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -181,6 +181,7 @@
 "home.subtitle.free" = "시간에 쫓기지 않고, 내 속도로 즐겨요.";
 "home.subtitle.timed" = "1분 안에 최대한 많은 블록을 제거하세요.";
 "home.subtitle.moves" = "시간에 쫓기지 말고 매번 신중하게 교환하세요.";
+"home.practice_hint" = "자유 모드에서 조작을 연습해 보세요";
 "home.mode.free" = "자유 모드";
 "home.mode.puzzle" = "퍼즐 모드";
 "home.mode.timed" = "시간 도전";
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index 983032b74007df9a9094f450ab5bdfa747b6dce8..c7f684d79a0ee1fdd66d840a8290281c89267ea2 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -181,6 +181,7 @@
 "home.subtitle.free" = "Без таймера. Играй в своём ритме.";
 "home.subtitle.timed" = "Уберите как можно больше фигур за минуту.";
 "home.subtitle.moves" = "Без спешки. Пусть каждый обмен будет полезным.";
+"home.practice_hint" = "Оттачивай навыки в свободной игре";
 "home.mode.free" = "Свободная игра";
 "home.mode.puzzle" = "Головоломка";
 "home.mode.timed" = "На время";
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index d31d1bf152d86011c9c3fdee731e57631a6eda0e..c74e9fc58730c7df36dc4cbec72908435eeafe3a 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -188,6 +188,7 @@
 "home.subtitle.free" = "没有倒计时，按自己的节奏玩。";
 "home.subtitle.timed" = "和时间赛跑，迅速消除更多方块。";
 "home.subtitle.moves" = "不必赶时间，让每一步更有价值。";
+"home.practice_hint" = "在自由模式中练习操作技巧";
 "home.mode.free" = "自由模式";
 "home.mode.puzzle" = "解谜模式";
 "home.mode.timed" = "限时挑战";
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 04681add300259c2f36cc6cc7eebf3b6e87e9c7d..59e80de8ae9b1dd39501bb23dcafa8ddb1c9bbee 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -187,9 +187,19 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             }
             let headerBottom = surface.minY + surface.height * 52 / 186
             let headerRows = pixels(from: surface.minY, to: headerBottom)
-            let headerColumns = pixels(from: 0, to: size.width)
-            XCTAssertFalse(headerRows.contains { !cyanColumns(in: free, y: $0, x: headerColumns).isEmpty },
-                           "自由模式的背板顶部不应残留青色标记或文字")
+            let markBandEnd = surface.minX + surface.width / 4
+            let leftColumns = pixels(from: surface.minX, to: markBandEnd)
+            let rightColumns = pixels(from: markBandEnd, to: surface.maxX)
+            func hasBlueMark(in columns: Range<Int>) -> Bool {
+                headerRows.contains { y in
+                    columns.contains { x in
+                        guard let color = free.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
+                        return color.alphaComponent > 0.65 && color.blueComponent > 0.60 && color.blueComponent - color.redComponent > 0.25
+                    }
+                }
+            }
+            XCTAssertTrue(hasBlueMark(in: leftColumns), "自由模式顶部保留左侧蓝色短斜杠")
+            XCTAssertFalse(hasBlueMark(in: rightColumns), "自由模式顶部右侧没有挑战进度轨道")
 
             var timedTrack: NSRect?
             for mode in [HomeGameMode.timed, .moves] {
@@ -609,7 +619,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         beginTransition()
         advance(to: sharedStart - firstFrameInterval)
         XCTAssertEqual(hud.plateAssembly.highlight, 0)
-        XCTAssertEqual(hud.budgetFillProgress, 0)
+        XCTAssertEqual(hud.backingRevealProgress, 0)
         XCTAssertTrue(try litColumns().isEmpty, "接缝扫光前只绘制暗色轨道")
 
         let steps = 12
@@ -625,13 +635,13 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             home.layoutSubtreeIfNeeded()
             XCTAssertEqual(hud.plateAssembly.backing, 1, accuracy: 0.001, "扫光开始时背板已到位")
             XCTAssertEqual(hud.plateAssembly.front, 1, accuracy: 0.001, "扫光开始时前板已到位")
-            XCTAssertEqual(hud.budgetFillProgress, fraction, accuracy: 0.001)
+            XCTAssertEqual(hud.backingRevealProgress, fraction, accuracy: 0.001)
             XCTAssertEqual(hud.displayedBudgetFraction, fraction, accuracy: 0.001)
             if step == 0 {
                 XCTAssertEqual(hud.plateAssembly.highlight, 0, accuracy: 0.001)
             } else if step == 1 {
                 XCTAssertGreaterThan(hud.plateAssembly.highlight, 0, "扫光和预算在同一帧开始")
-                XCTAssertGreaterThan(hud.budgetFillProgress, 0)
+                XCTAssertGreaterThan(hud.backingRevealProgress, 0)
                 XCTAssertFalse(try litColumns().isEmpty, "限时轨道随扫光出现第一段青色填充")
             }
             if step == 0 || step == 1 + steps / 4 || step == 1 + steps / 2 || isLast {
@@ -652,24 +662,24 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             XCTAssertEqual(Double(columns.count) / Double(full.count), fraction, accuracy: 0.05)
         }
         refresh(.timed, seconds: 48, running: true)
-        XCTAssertEqual(hud.budgetFillProgress, 1, "已填满后更新剩余时间无需重新填充")
+        XCTAssertEqual(hud.backingRevealProgress, 1, "已填满后更新剩余时间无需重新填充")
         XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.8, accuracy: 0.05)
 
         refresh(.moves, swaps: 30)
-        XCTAssertEqual(hud.budgetFillProgress, 0)
+        XCTAssertEqual(hud.backingRevealProgress, 0)
         beginTransition()
         advance(to: sharedStart - firstFrameInterval)
         XCTAssertEqual(hud.plateAssembly.highlight, 0)
-        XCTAssertEqual(hud.budgetFillProgress, 0)
+        XCTAssertEqual(hud.backingRevealProgress, 0)
         XCTAssertEqual(try litSegments(), 0)
         advance(to: sharedStart + firstFrameInterval)
         XCTAssertGreaterThan(hud.plateAssembly.highlight, 0)
-        XCTAssertGreaterThan(hud.budgetFillProgress, 0)
+        XCTAssertGreaterThan(hud.backingRevealProgress, 0)
         XCTAssertEqual(try litSegments(), 1, "限步第一格随扫光出现")
         advance(to: sharedStart + fillDuration * 0.34)
         XCTAssertEqual(try litSegments(), 11, "限步填充以整格逐一显示")
         refresh(.moves, swaps: 30, running: true)
-        XCTAssertEqual(hud.budgetFillProgress, 0.34, accuracy: 0.001, "填充期间开局保留当前进度")
+        XCTAssertEqual(hud.backingRevealProgress, 0.34, accuracy: 0.001, "填充期间开局保留当前进度")
         XCTAssertEqual(try litSegments(), 11)
         refresh(.moves, swaps: 13, running: true)
         XCTAssertEqual(hud.remainingFraction, CGFloat(13) / 30, accuracy: 0.001)
@@ -678,19 +688,114 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         advance(to: sharedStart + fillDuration * 0.72)
         XCTAssertEqual(try litSegments(), 10)
         advance(to: sharedStart + fillDuration + 0.001)
-        XCTAssertEqual(hud.budgetFillProgress, 1)
+        XCTAssertEqual(hud.backingRevealProgress, 1)
         XCTAssertEqual(try litSegments(), 13, "动画结束时准确显示实际剩余步数")
 
         refresh(.timed, seconds: 60)
         beginTransition()
         advance(to: sharedStart + fillDuration * 0.5)
-        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
+        XCTAssertEqual(hud.backingRevealProgress, 0.5, accuracy: 0.001)
         refresh(.timed, seconds: 42, running: true)
-        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
+        XCTAssertEqual(hud.backingRevealProgress, 0.5, accuracy: 0.001)
         XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.35, accuracy: 0.05, "限时开局后按当前剩余时间填充")
         refresh(.moves, swaps: 30)
         XCTAssertEqual(hud.plateAssembly, .separated)
-        XCTAssertEqual(hud.budgetFillProgress, 0, "上一模式尚在填充时，切换后仍重回空轨")
+        XCTAssertEqual(hud.backingRevealProgress, 0, "上一模式尚在填充时，切换后仍重回空轨")
+    }
+
+    func testPracticeHintTypesAtLaunchAndWithTheFreeModeHighlight() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let hint = AchievementText.string("home.practice_hint")
+        XCTAssertEqual(hint, "在自由模式中练习操作技巧")
+
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        let header = home.modeHeader
+        let hud = home.challengeHUD
+        var clock: TimeInterval = 0
+        header.now = { clock }
+        header.reducesMotion = { false }
+        let duration = HomeModeHeaderView.practiceHintDuration
+        let frameInterval = 1.0 / 60
+        XCTAssertEqual(duration, 0.80, accuracy: 0.001)
+
+        let free = GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil, remainingSwaps: nil, isRunning: false, isFinished: false)
+        let playing = GameSnapshot(mode: .free, elapsedTime: 1, remainingTime: nil, remainingSwaps: nil, isRunning: true, isFinished: false)
+        let timed = GameSnapshot(mode: .timed(duration: 60), elapsedTime: 0, remainingTime: 60, remainingSwaps: nil, isRunning: false, isFinished: false)
+        home.refresh(snapshot: free, mode: .free, manager: manager)
+        let window = NSWindow(contentRect: home.frame, styleMask: [.borderless], backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false
+        window.contentView = home
+        defer { window.close() }
+        home.layoutSubtreeIfNeeded()
+        XCTAssertEqual(hud.plateAssembly, .settled, "首次显示自由模式直接打字")
+        XCTAssertTrue(hud.displayedPracticeHint.isEmpty)
+        XCTAssertNil(hud.budgetTrackRect)
+        header.advanceAnimation()
+        clock = frameInterval
+        header.advanceAnimation()
+        XCTAssertEqual(hud.displayedPracticeHint, String(hint.prefix(1)))
+        XCTAssertEqual(hud.plateAssembly, .settled)
+        clock = duration * 0.5
+        header.advanceAnimation()
+        let partial = hud.displayedPracticeHint
+        XCTAssertGreaterThan(partial.count, 1)
+        XCTAssertLessThan(partial.count, hint.count)
+        XCTAssertEqual(partial, String(hint.prefix(partial.count)))
+        home.refresh(snapshot: playing, mode: .free, manager: manager)
+        XCTAssertEqual(hud.displayedPracticeHint, partial, "同模式开局保留已显示的字符")
+        clock = duration + frameInterval
+        header.advanceAnimation()
+        XCTAssertEqual(hud.displayedPracticeHint, hint)
+        home.refresh(snapshot: free, mode: .free, manager: manager)
+        XCTAssertEqual(hud.displayedPracticeHint, hint, "同模式刷新不重新打字")
+
+        home.refresh(snapshot: timed, mode: .timed, manager: manager)
+        XCTAssertTrue(hud.displayedPracticeHint.isEmpty)
+        header.advanceAnimation()
+        clock += HomeModeHeaderView.previewDuration + HomeModeHeaderView.budgetFillDuration
+        header.advanceAnimation()
+        home.refresh(snapshot: free, mode: .free, manager: manager)
+        XCTAssertEqual(hud.plateAssembly, .separated)
+        XCTAssertTrue(hud.displayedPracticeHint.isEmpty)
+        header.advanceAnimation()
+        let start = clock + HomeModeHeaderView.joinHighlightStart
+        clock = start - frameInterval
+        header.advanceAnimation()
+        XCTAssertEqual(hud.plateAssembly.highlight, 0)
+        XCTAssertTrue(hud.displayedPracticeHint.isEmpty, "前板扫光之前显示空提示")
+
+        let steps = 16
+        let offsets = [0, frameInterval] + (1...steps).map { duration * Double($0) / Double(steps) }
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-practice-hint.gif")
+        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, offsets.count, nil))
+        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        var previousCount = 0
+        for (step, offset) in offsets.enumerated() {
+            let isLast = step == offsets.count - 1
+            clock = start + offset + (isLast ? 0.001 : 0)
+            header.advanceAnimation()
+            let visibleHint = hud.displayedPracticeHint
+            XCTAssertGreaterThanOrEqual(visibleHint.count, previousCount)
+            XCTAssertEqual(visibleHint, String(hint.prefix(visibleHint.count)))
+            previousCount = visibleHint.count
+            if step == 1 {
+                XCTAssertGreaterThan(hud.plateAssembly.highlight, 0)
+                XCTAssertEqual(visibleHint, String(hint.prefix(1)), "扫光出现的第一帧同时显示首字")
+            }
+
+            home.layoutSubtreeIfNeeded()
+            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
+            home.cacheDisplay(in: header.frame, to: bitmap)
+            let frame = try XCTUnwrap(bitmap.cgImage)
+            let delay = isLast ? 1.0 : offsets[step + 1] - offset
+            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(gif))
+        XCTAssertEqual(hud.displayedPracticeHint, hint)
+        XCTAssertNil(hud.budgetTrackRect)
     }
 
     private func modeIntro(in header: HomeModeHeaderView) throws -> NSView {
```
