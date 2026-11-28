# 统计卡叠合后填充挑战预算

## 背景与目标

- 会话-129 要求模式切换动画后，从零增长背板的预算进度。待机时填满。如果播放期间开始新一局，则以实时剩余量为目标。

## 实施

- 挑战模式叠合阶段显示空轨道，叠合完成后用 0.60 秒填充。限时连续推进，限步逐格点亮，自由模式在叠合后直接收尾。
- 每帧以当前剩余预算乘上动画进度。开局、计时和合法交换产生的快照可以更新目标，同模式刷新沿用动画进度。切到另一模式重新从空轨开始。
- 预算数字、无障碍读数和低预算着色继续读取实际值。减少动态效果时直接显示当前预算。

## 验证

- 原生合成像素回归核对限时空轨、四分之一、半满和完整填充，并验证动画期间改用剩余时间。限步回归验证开局和消耗后只按剩余步数逐格点亮，最终准确到达剩余格数。
- 原生窗口淡入回归采样统计前板，验证开局相关刷新和快速切换后的淡入。全量 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过 109 项。
- 运行 `./run.sh` 后切换限时或限步，等待卡片叠合即可查看填充。也可以在动画期间开局，再观察轨道最终停在实际剩余量。

## 本轮完整增量 diff

以会话-129 开始时的提交为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index bd1af323d25a9cfa55ed077c06fc5e3e9a89b21a..12d291ad457fbac1c438e5b3ddb4a3050077154d 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128090504-animate-statistics-budget-fill.md` - 会话-129 起在统计卡叠合后从零填充挑战预算，开局后动态跟随剩余值。
 `workflow/20261128084215-make-statistics-fade-visible.md` - 会话-124 起改为匀速淡入，每次换模式从透明起步，含真实窗口轨道像素实测。
 `workflow/20261127231423-match-statistics-plate-heights.md` - 会话-120 起将统计背板高度与前板总数和分类的合计高度对齐。
 `workflow/20261127225349-complete-statistics-backing-outline.md` - 会话-117 起补齐统计背板右斜边和底边，底边向左下角渐隐。
@@ -119,6 +120,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整切换模式后的预算填充、开局时的剩余目标或限步分格显示时，读取 `20261128090504-animate-statistics-budget-fill.md`。
 - 需要调整统计卡淡入的可见节奏或验证快速换模式也从透明开始时，读取 `20261128084215-make-statistics-fade-visible.md`。
 - 需要调整统计背板与前板的等高关系或检查分层时的底边位置，读取 `20261127231423-match-statistics-plate-heights.md`。
 - 需要调整统计背板右斜边、底边左下角渐隐或检查分层动画中的边框时，读取 `20261127225349-complete-statistics-backing-outline.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 8d810ea7eac36c70e1c2b36a4592006efa31b058..697213b2a28a0fd273da75e3cfcc1a5f57a20a96 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -27,6 +27,9 @@ final class HomeChallengeHUDView: NSView {
     var plateAssembly = PlateAssembly.settled {
         didSet { if plateAssembly != oldValue { needsDisplay = true } }
     }
+    var budgetFillProgress: CGFloat = 1 {
+        didSet { if budgetFillProgress != oldValue { needsDisplay = true } }
+    }
 
     var backingPlateOffset: NSPoint {
         NSPoint(x: Self.backingTravel.x * (1 - plateAssembly.backing), y: Self.backingTravel.y * (1 - plateAssembly.backing))
@@ -183,6 +186,8 @@ final class HomeChallengeHUDView: NSView {
         return CGFloat(min(1, max(0, fraction)))
     }
 
+    var displayedBudgetFraction: CGFloat { remainingFraction * budgetFillProgress }
+
     var budgetText: String {
         guard showsBudget, let snapshot else { return "" }
         if mode == .moves { return String(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) }
@@ -463,7 +468,8 @@ final class HomeChallengeHUDView: NSView {
         if mode == .moves {
             // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
             let limit = HomeGameMode.moveLimit
-            let remaining = snapshot.remainingSwaps ?? limit
+            let remaining = min(limit, max(0, snapshot.remainingSwaps ?? limit))
+            let lit = Int(CGFloat(remaining) * budgetFillProgress)
             let cut = HomeDashboardStyle.edgeOffset(for: track.height)
             let available = max(0, track.width - cut)
             let gap = min(2, available / CGFloat(limit * 2))
@@ -471,13 +477,13 @@ final class HomeChallengeHUDView: NSView {
             for index in 0..<limit {
                 let segment = NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY,
                                      width: width + cut, height: track.height)
-                (index < remaining ? accent : idleColor).setFill()
+                (index < lit ? accent : idleColor).setFill()
                 HomeDashboardStyle.slant(segment).fill()
             }
         } else {
             idleColor.setFill()
             HomeDashboardStyle.slant(track).fill()
-            let fill = HomeDashboardStyle.segmentFill(track, fraction: remainingFraction)
+            let fill = HomeDashboardStyle.segmentFill(track, fraction: displayedBudgetFraction)
             guard !fill.isEmpty else { return }
             NSGradient(colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent])?
                 .draw(in: fill, angle: 90)
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 8f944e799bf1f798e1754b4d3ad3f7e6e81a804b..99238ca84a11ffe2300f59f405090fe165042663 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -3,6 +3,7 @@ import Cocoa
 /// 上方文案和本局统计并排排版，切换模式时交错叠合统计卡的前后两层。
 final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1.20
+    static let budgetFillDuration: TimeInterval = 0.60
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
@@ -10,6 +11,7 @@ final class HomeModeHeaderView: NSView {
     let card = HomeChallengeHUDView(frame: .zero)
     private var timer: Timer?
     private var transitionStart: TimeInterval?
+    private var isAssembling = false
     private var cardColumn = NSRect.zero
 
     override var isFlipped: Bool { true }
@@ -60,9 +62,11 @@ final class HomeModeHeaderView: NSView {
         }
         // 每次换模式都从透明起步。已运行的定时器继续驱动新一轮叠合。
         transitionStart = nil
+        if !isAssembling { card.positionPlates(in: cardColumn, assembling: true) }
+        isAssembling = true
         card.plateAssembly = .separated
+        card.budgetFillProgress = mode == .free ? 1 : 0
         guard timer == nil else { return }
-        card.positionPlates(in: cardColumn, assembling: true)
 
         let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
         RunLoop.main.add(timer, forMode: .common)
@@ -82,8 +86,14 @@ final class HomeModeHeaderView: NSView {
             return
         }
         let elapsed = max(0, currentTime - transitionStart)
-        guard elapsed < Self.previewDuration else {
-            settle()
+        if elapsed >= Self.previewDuration {
+            let progress = (elapsed - Self.previewDuration) / Self.budgetFillDuration
+            guard card.mode != .free, progress < 1 else {
+                settle()
+                return
+            }
+            finishAssembly()
+            card.budgetFillProgress = CGFloat(progress)
             return
         }
         let time = CGFloat(elapsed / Self.previewDuration)
@@ -104,15 +114,22 @@ final class HomeModeHeaderView: NSView {
 
     override func layout() {
         super.layout()
-        card.positionPlates(in: cardColumn, assembling: timer != nil)
+        card.positionPlates(in: cardColumn, assembling: isAssembling)
+    }
+
+    private func finishAssembly() {
+        guard isAssembling else { return }
+        isAssembling = false
+        card.plateAssembly = .settled
+        card.positionPlates(in: cardColumn, assembling: false)
     }
 
     private func settle() {
         transitionStart = nil
         timer?.invalidate()
         timer = nil
-        card.plateAssembly = .settled
-        card.positionPlates(in: cardColumn, assembling: false)
+        finishAssembly()
+        card.budgetFillProgress = 1
     }
 }
 
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 28a644ff59e1210c5132551a08610b25ed6c4ae8..61fec3bccc8aad8f7c0bc99f402a9e280c5ec642 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -541,6 +541,139 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertFalse(intro.isHidden)
     }
 
+    func testChallengeBudgetTrackFillsAfterAssemblyAndFollowsTheLiveBudget() throws {
+        _ = NSApplication.shared
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        let window = NSWindow(contentRect: home.frame, styleMask: [.borderless], backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false
+        window.contentView = home
+        defer { window.close() }
+        let header = home.modeHeader
+        let hud = home.challengeHUD
+        var clock: TimeInterval = 0
+        var transitionStartedAt = clock
+        header.now = { clock }
+        header.reducesMotion = { false }
+        let assemblyDuration = HomeModeHeaderView.previewDuration
+        let fillDuration = HomeModeHeaderView.budgetFillDuration
+        XCTAssertEqual(fillDuration, 0.60, accuracy: 0.001)
+
+        func refresh(_ mode: HomeGameMode, seconds: TimeInterval? = nil, swaps: Int? = nil, running: Bool = false) {
+            let elapsed = seconds.map { HomeGameMode.timedDuration - $0 } ?? (running ? 1 : 0)
+            let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: elapsed, remainingTime: seconds,
+                                        remainingSwaps: swaps, isRunning: running, isFinished: false)
+            home.refresh(snapshot: snapshot, mode: mode, manager: manager)
+        }
+
+        func beginTransition() {
+            transitionStartedAt = clock
+            header.advanceAnimation()
+        }
+
+        func advance(to elapsed: TimeInterval) {
+            clock = transitionStartedAt + elapsed
+            header.advanceAnimation()
+        }
+
+        func litColumns() throws -> [Int] {
+            home.layoutSubtreeIfNeeded()
+            let offset = hud.backingPlateOffset
+            let local = try XCTUnwrap(hud.budgetTrackRect).offsetBy(dx: offset.x, dy: offset.y)
+            let track = hud.convert(local, to: home)
+            // 用与动图相同的统计区合成帧采样，按裁剪区域的原点换算像素坐标。
+            let region = header.frame
+            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: region))
+            home.cacheDisplay(in: region, to: bitmap)
+            let scale = CGFloat(bitmap.pixelsWide) / region.width
+            let y = Int((track.midY - region.minY) * scale)
+            let first = Int(ceil((track.minX - region.minX) * scale))
+            let last = Int(floor((track.maxX - region.minX) * scale))
+            return (first..<last).filter { x in
+                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
+                let cyan = min(color.greenComponent, color.blueComponent)
+                return cyan > 0.62 && cyan - color.redComponent > 0.22
+            }
+        }
+
+        func litSegments() throws -> Int {
+            let columns = try litColumns()
+            guard !columns.isEmpty else { return 0 }
+            return 1 + zip(columns, columns.dropFirst()).filter { left, right in right > left + 1 }.count
+        }
+
+        refresh(.free)
+        home.layoutSubtreeIfNeeded()
+        XCTAssertNil(hud.budgetTrackRect)
+        refresh(.timed, seconds: 60)
+        beginTransition()
+        advance(to: assemblyDuration * 0.96)
+        XCTAssertNotEqual(hud.plateAssembly, .settled)
+        XCTAssertEqual(hud.budgetFillProgress, 0)
+        XCTAssertTrue(try litColumns().isEmpty, "叠合期间只绘制暗色轨道")
+
+        let steps = 12
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-budget-fill.gif")
+        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
+        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        var fillColumns: [[Int]] = []
+        for step in 0...steps {
+            let fraction = Double(step) / Double(steps)
+            advance(to: assemblyDuration + fillDuration * fraction + (step == steps ? 0.001 : 0))
+            home.layoutSubtreeIfNeeded()
+            XCTAssertEqual(hud.plateAssembly, .settled, "预算填充开始时两层已到位")
+            XCTAssertEqual(hud.budgetFillProgress, CGFloat(fraction), accuracy: 0.001)
+            XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(fraction), accuracy: 0.001)
+            if step == 0 || step == steps / 4 || step == steps / 2 || step == steps {
+                fillColumns.append(try litColumns())
+            }
+            let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
+            home.cacheDisplay(in: header.frame, to: bitmap)
+            let frame = try XCTUnwrap(bitmap.cgImage)
+            let delay = step == steps ? 1.0 : fillDuration / Double(steps)
+            CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(gif))
+        XCTAssertEqual(fillColumns.count, 4)
+        let full = try XCTUnwrap(fillColumns.last.flatMap { $0.isEmpty ? nil : $0 }, "未开局的限时模式填满整条轨道")
+        XCTAssertTrue(try XCTUnwrap(fillColumns.first).isEmpty)
+        for (columns, fraction) in zip(fillColumns.dropFirst().dropLast(), [0.25, 0.50]) {
+            XCTAssertEqual(columns.first, full.first, "预算从轨道左端开始填充")
+            XCTAssertEqual(Double(columns.count) / Double(full.count), fraction, accuracy: 0.05)
+        }
+        refresh(.timed, seconds: 48, running: true)
+        XCTAssertEqual(hud.budgetFillProgress, 1, "已填满后更新剩余时间无需重新填充")
+        XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.8, accuracy: 0.05)
+
+        refresh(.moves, swaps: 30)
+        XCTAssertEqual(hud.budgetFillProgress, 0)
+        beginTransition()
+        advance(to: assemblyDuration + fillDuration * 0.34)
+        XCTAssertEqual(try litSegments(), 10, "限步只显示填满的整格")
+        refresh(.moves, swaps: 30, running: true)
+        XCTAssertEqual(hud.budgetFillProgress, 0.34, accuracy: 0.001, "填充期间开局保留当前进度")
+        XCTAssertEqual(try litSegments(), 10)
+        refresh(.moves, swaps: 13, running: true)
+        XCTAssertEqual(hud.remainingFraction, CGFloat(13) / 30, accuracy: 0.001)
+        XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(13) / 30 * 0.34, accuracy: 0.001)
+        XCTAssertEqual(try litSegments(), 4, "按填充进度换算当前剩余交换次数")
+        advance(to: assemblyDuration + fillDuration * 0.72)
+        XCTAssertEqual(try litSegments(), 9)
+        advance(to: assemblyDuration + fillDuration + 0.001)
+        XCTAssertEqual(hud.budgetFillProgress, 1)
+        XCTAssertEqual(try litSegments(), 13, "动画结束时准确显示实际剩余步数")
+
+        refresh(.timed, seconds: 60)
+        beginTransition()
+        advance(to: assemblyDuration + fillDuration * 0.5)
+        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
+        refresh(.timed, seconds: 42, running: true)
+        XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
+        XCTAssertEqual(Double(try litColumns().count) / Double(full.count), 0.35, accuracy: 0.05, "限时开局后按当前剩余时间填充")
+        refresh(.moves, swaps: 30)
+        XCTAssertEqual(hud.plateAssembly, .separated)
+        XCTAssertEqual(hud.budgetFillProgress, 0, "上一模式尚在填充时，切换后仍重回空轨")
+    }
+
     private func modeIntro(in header: HomeModeHeaderView) throws -> NSView {
         try XCTUnwrap(header.subviews.first { !$0.isHidden && !($0 is HomeChallengeHUDView) })
     }
@@ -598,10 +731,11 @@ final class GameLobbyPresentationTests: AchievementTestCase {
     }
 
     private func assertAssemblingPlatesAreVisible(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
-        let budget = try XCTUnwrap(preview.budgetTrackRect)
+        let backing = preview.surfaceRect.offsetBy(dx: preview.backingPlateOffset.x, dy: preview.backingPlateOffset.y)
         let cell = try XCTUnwrap(preview.breakdownCellRects.last)
-        let budgetPoint = preview.convert(NSPoint(x: budget.midX + preview.backingPlateOffset.x,
-                                                y: budget.midY + preview.backingPlateOffset.y), to: home)
+        let rimPoints = [-1.0, 0, 1].map { offset in
+            preview.convert(NSPoint(x: backing.midX, y: backing.minY + CGFloat(offset)), to: home)
+        }
         let cellPoint = preview.convert(NSPoint(x: cell.midX + preview.frontPlateOffset.x,
                                               y: cell.midY + preview.frontPlateOffset.y), to: home)
 
@@ -615,11 +749,14 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             abs(first.redComponent - second.redComponent) + abs(first.greenComponent - second.greenComponent) + abs(first.blueComponent - second.blueComponent)
         }
 
-        let visibleBudget = try color(at: budgetPoint)
+        let visibleRim = try rimPoints.map { try color(at: $0) }
         let visibleCell = try color(at: cellPoint)
         preview.isHidden = true
         defer { preview.isHidden = false }
-        XCTAssertGreaterThan(difference(visibleBudget, try color(at: budgetPoint)), 0.06, "组装时移动后的进度轨道可见")
+        let rimContrast = try zip(visibleRim, rimPoints).map { colorWithCard, point in
+            difference(colorWithCard, try color(at: point))
+        }.max() ?? 0
+        XCTAssertGreaterThan(rimContrast, 0.06, "组装时移动后的背板上缘可见")
         XCTAssertGreaterThan(difference(visibleCell, try color(at: cellPoint)), 0.012, "组装时移动后的末尾分类格可见")
     }
 
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index e3c0f579ba552bc56651077a836b8b67318c0f39..e2051007b46f35b8ce6eb438891f9d5a6fb68706 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -196,7 +196,7 @@ final class HomeDashboardTests: AchievementTestCase {
         }
     }
 
-    func testStatisticsBudgetPixelsFadeInAgainWhenModeChangesDuringAssembly() throws {
+    func testStatisticsPlatePixelsFadeInAgainWhenModeChangesDuringAssembly() throws {
         let (window, home) = try openStatisticsTestWindow()
         defer { window.close() }
         let hud = home.challengeHUD
@@ -214,10 +214,11 @@ final class HomeDashboardTests: AchievementTestCase {
             return timestamp
         }
 
-        func budgetOpacity() throws -> CGFloat {
-            let track = try XCTUnwrap(hud.budgetTrackRect)
-            let center = NSPoint(x: track.midX + hud.backingPlateOffset.x, y: track.midY + hud.backingPlateOffset.y)
-            // 在轨道中线取一小段，限步轨道至少会命中一个实心分格。
+        func frontPlateOpacity() throws -> CGFloat {
+            let surface = hud.surfaceRect
+            let offset = hud.frontPlateOffset
+            // 采样随前板移动的总数区底色，避开背板上独立填充的预算轨道。
+            let center = NSPoint(x: surface.minX + surface.width * 0.65 + offset.x, y: surface.midY + offset.y)
             let rect = NSRect(x: center.x - 9, y: center.y - 2, width: 18, height: 4)
             let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: rect))
             hud.cacheDisplay(in: rect, to: bitmap)
@@ -233,7 +234,7 @@ final class HomeDashboardTests: AchievementTestCase {
                 RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
                 guard let firstTick, let latestTick, latestTick != lastSampledTick else { continue }
                 lastSampledTick = latestTick
-                let opacity = try budgetOpacity()
+                let opacity = try frontPlateOpacity()
                 samples.append((latestTick - firstTick, opacity))
                 if opacity >= 0.50 { break }
             }
@@ -243,11 +244,11 @@ final class HomeDashboardTests: AchievementTestCase {
         timed.performClick(nil)
         XCTAssertTrue(timed.selected)
         XCTAssertEqual(hud.mode, .timed)
-        let initial = try budgetOpacity()
+        let initial = try frontPlateOpacity()
         let samples = try samplesThroughHalfOpacity()
         let early = try XCTUnwrap(samples.first { $0.opacity >= 0.10 })
         let halfway = try XCTUnwrap(samples.first { $0.opacity >= 0.50 })
-        print(String(format: "限时统计轨道实测，初始 %.2f，首段 %.2f，至半透明 %.3f 秒，取样 %d 帧",
+        print(String(format: "限时统计前板实测，初始 %.2f，首段 %.2f，至半透明 %.3f 秒，取样 %d 帧",
                      Double(initial), Double(early.opacity), halfway.elapsed, samples.count))
         XCTAssertLessThan(initial, 0.10, "首次切换从接近透明开始")
         XCTAssertLessThan(early.opacity + 0.15, halfway.opacity, "首段经过不同程度的半透明")
@@ -262,11 +263,11 @@ final class HomeDashboardTests: AchievementTestCase {
         moves.performClick(nil)
         XCTAssertTrue(moves.selected)
         XCTAssertEqual(hud.mode, .moves)
-        let restarted = try budgetOpacity()
+        let restarted = try frontPlateOpacity()
         let movesSamples = try samplesThroughHalfOpacity()
         let movesHalfway = try XCTUnwrap(movesSamples.first { $0.opacity >= 0.50 })
-        print(String(format: "限步统计轨道实测，中途切换后初始 %.2f，至半透明 %.3f 秒", Double(restarted), movesHalfway.elapsed))
-        XCTAssertLessThan(restarted, 0.12, "中途切换时新轨道从接近透明重新淡入")
+        print(String(format: "限步统计前板实测，中途切换后初始 %.2f，至半透明 %.3f 秒", Double(restarted), movesHalfway.elapsed))
+        XCTAssertLessThan(restarted, 0.12, "中途切换时新前板从接近透明重新淡入")
     }
 
     func testAchievementRowSpansBothColumnsAndStartAlignsWithContact() throws {
```
