# 消除统计数字在原位递增

## 背景与目标

- 用户希望看到数值变化过程。本轮将会话-38 加入的垂直位移改为数值递增。
- 核对了 `experiment/ui-refactor` 的 `5b276ef`。该分支的大厅统计使用固定位置绘制最新快照，模式切换另有整卡入场效果。本次沿用固定数字位置，为新消除增加中间计数。

## 实现

- 分类计数在 0.36 秒内从屏幕当前值递增到实际值，前段较快、逐渐放缓。连续消除时只为增长类型重新计时，并从当前已绘制的数字接续。
- 本局总数使用同一帧的四个分类显示值求和。可访问性标签和提示立即更新到真实快照值。
- 首次加载、换模式、重开归零及启用“减少动态效果”时直接显示实际数值。
- 限时和限步的预算标签及数字恢复原来的静态基线，释放为垂直跳动预留的空间。

## 验证

- 三种模式的中间帧与同计数的静态原生图逐像素比较，覆盖紧凑统计卡、数字跨位数和汇总求和。
- 测试重复快照、预算更新、连续消除、中途增长、最后一步、归零及减少动态效果。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 全部 102 项通过。
- 手动验证可运行 `./run.sh`，开局后消除一组同类方块，观察统计卡数字在原处从旧数值逐步增加。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index ef986b032ae369a1cdf6fba36b5142f33d0653a9..03107a41a965c694e1dba52fac93879199d745ff 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
 `workflow/20261124223031-restore-space-start-and-stat-number-jumps.md` - 会话-38 起修复模式卡保留焦点时的空格开局，并恢复消除总数和变化分类数字的跳动。
 `workflow/20261124215116-raise-mode-card-icon-plates.md` - 会话-35 起给右侧四张游戏模式卡加入凸出上沿的斜面图标前层，含原生渲染与紧凑布局验证。
 `workflow/20261124212018-match-stat-plate-side-spacing.md` - 会话-32 起统一消除统计卡背板与前板左右斜边的水平错位，含原生像素回归及进度轨道留白校验。
@@ -107,6 +108,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
 - 需要核对空格开局的主窗口焦点边界，或调整消除统计数字的跳动、归零及减少动态效果时，读取 `20261124223031-restore-space-start-and-stat-number-jumps.md`。
 - 需要调整右侧游戏模式卡的图标前层、立体侧沿、选中色或上沿留空时，读取 `20261124215116-raise-mode-card-icon-plates.md`。
 - 需要调整消除统计卡背板与前板的左右斜边间距或核对等距像素回归时，读取 `20261124212018-match-stat-plate-side-spacing.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 8e3d5b4829e6e0980ae8b36d0bf5ae3baf51f227..1f5d5decd90139773b4d289378b85c100b94a362 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -6,7 +6,7 @@ final class HomeChallengeHUDView: NSView {
     static let trailingInset: CGFloat = 3
     private static let rearOverhang: CGFloat = 0.08
     private static let rearTopInset: CGFloat = 45 / 636
-    private static let countJumpDuration: TimeInterval = 0.42
+    private static let countAnimationDuration: TimeInterval = 0.36
 
     static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
         max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
@@ -84,11 +84,24 @@ final class HomeChallengeHUDView: NSView {
     }
     private(set) var snapshot: GameSnapshot?
     private(set) var mode: HomeGameMode = .timed
-    private enum CountNumber: Hashable { case total, piece(PieceKind) }
+    private struct CountTransition {
+        let initial: Int
+        let target: Int
+        let start: TimeInterval
+
+        func value(at now: TimeInterval) -> Int {
+            let progress = max(0, now - start) / HomeChallengeHUDView.countAnimationDuration
+            guard progress < 1 else { return target }
+            let distance = Double(target - initial)
+            let advance = floor(distance * (1 - pow(1 - progress, 3)))
+            return advance < distance ? initial + Int(advance) : target
+        }
+    }
+
     private let animationClock: () -> TimeInterval
     private let reducesMotion: () -> Bool
-    private var countJumpStarts: [CountNumber: TimeInterval] = [:]
-    private var countJumpTimer: Timer?
+    private var countTransitions: [PieceKind: CountTransition] = [:]
+    private var countAnimationTimer: Timer?
     var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
     override var isFlipped: Bool { true }
     init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
@@ -99,7 +112,7 @@ final class HomeChallengeHUDView: NSView {
         setAccessibilityElement(true); setAccessibilityRole(.group)
     }
     required init?(coder: NSCoder) { nil }
-    deinit { countJumpTimer?.invalidate() }
+    deinit { countAnimationTimer?.invalidate() }
 
     override func viewDidMoveToWindow() {
         super.viewDidMoveToWindow()
@@ -142,13 +155,14 @@ final class HomeChallengeHUDView: NSView {
         needsDisplay = true
     }
 
-    /// 未传方块类型时读取总数的跳动偏移。
-    func numberJumpOffset(for kind: PieceKind? = nil) -> CGFloat {
-        let number = kind.map(CountNumber.piece) ?? .total
-        guard let start = countJumpStarts[number], !reducesMotion() else { return 0 }
-        let progress = (animationClock() - start) / Self.countJumpDuration
-        guard progress >= 0, progress < 1 else { return 0 }
-        return -6 * CGFloat(sin(.pi * progress))
+    /// 同一帧共用一个时间采样，汇总与四个分类同步更新。
+    func displayedCounts() -> [PieceKind: Int] {
+        let now = animationClock()
+        let transitions = reducesMotion() ? [:] : countTransitions
+        return Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { kind in
+            let value = transitions[kind]?.value(at: now) ?? snapshot?.clearedByKind[kind, default: 0] ?? 0
+            return (kind, value)
+        })
     }
 
     private func updateCountAnimation(snapshot: GameSnapshot, mode: HomeGameMode) {
@@ -159,21 +173,22 @@ final class HomeChallengeHUDView: NSView {
             return
         }
         let now = animationClock()
-        if snapshot.totalCleared > previous.totalCleared { countJumpStarts[.total] = now }
+        countTransitions = countTransitions.filter { now - $0.value.start < Self.countAnimationDuration }
         for kind in PieceKind.allCases {
             let value = snapshot.clearedByKind[kind, default: 0]
             let previousValue = previous.clearedByKind[kind, default: 0]
             if value > previousValue {
-                countJumpStarts[.piece(kind)] = now
+                // 连续消除从当前屏幕数字继续累加，避免突然跳到上一笔的目标值。
+                let initial = countTransitions[kind]?.value(at: now) ?? previousValue
+                countTransitions[kind] = CountTransition(initial: initial, target: value, start: now)
             } else if value < previousValue {
-                countJumpStarts.removeValue(forKey: .piece(kind))
+                countTransitions.removeValue(forKey: kind)
             }
         }
-        // 普通刷新仍更新快照，只有计数增长才设置新的跳动起点。
-        guard !countJumpStarts.isEmpty, countJumpTimer == nil, isCountAnimationVisible else { return }
+        guard !countTransitions.isEmpty, countAnimationTimer == nil, isCountAnimationVisible else { return }
         let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advanceCountAnimation() }
         RunLoop.main.add(timer, forMode: .common)
-        countJumpTimer = timer
+        countAnimationTimer = timer
     }
 
     private var isCountAnimationVisible: Bool {
@@ -183,15 +198,15 @@ final class HomeChallengeHUDView: NSView {
 
     private func advanceCountAnimation() {
         let now = animationClock()
-        countJumpStarts = countJumpStarts.filter { now - $0.value < Self.countJumpDuration }
-        if countJumpStarts.isEmpty || reducesMotion() || !isCountAnimationVisible { stopCountAnimation() }
+        countTransitions = countTransitions.filter { now - $0.value.start < Self.countAnimationDuration }
+        if countTransitions.isEmpty || reducesMotion() || !isCountAnimationVisible { stopCountAnimation() }
         needsDisplay = true
     }
 
     private func stopCountAnimation() {
-        countJumpStarts.removeAll()
-        countJumpTimer?.invalidate()
-        countJumpTimer = nil
+        countTransitions.removeAll()
+        countAnimationTimer?.invalidate()
+        countAnimationTimer = nil
     }
 
     override func draw(_ dirtyRect: NSRect) {
@@ -218,8 +233,9 @@ final class HomeChallengeHUDView: NSView {
         fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                              HomeDashboardStyle.color(0x101A25)], angle: 14,
              border: HomeDashboardStyle.color(0x57636B))
-        drawTotals(snapshot, on: face, accent: accent)
-        drawBreakdown(snapshot, on: face)
+        let counts = displayedCounts()
+        drawTotals(counts.values.reduce(0, +), on: face, accent: accent)
+        drawBreakdown(counts, on: face)
         if let revealFraction { drawRevealHighlight(in: surface, outline: total, accent: accent, fraction: revealFraction) }
     }
 
@@ -241,7 +257,7 @@ final class HomeChallengeHUDView: NSView {
         NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
     }
 
-    private func drawTotals(_ snapshot: GameSnapshot, on face: Face, accent: NSColor) {
+    private func drawTotals(_ totalCleared: Int, on face: Face, accent: NSColor) {
         let body = face.box(478, 175, width: 506, height: 80)
         let x = body.minX
         let available = body.width
@@ -255,9 +271,9 @@ final class HomeChallengeHUDView: NSView {
             let metricY = body.midY
             drawStackedMetric(budgetText, labelKey: budgetLabelKey, center: metricY, x: x,
                               width: split - x - columnPadding, height: body.height, color: accent, alignment: .left)
-            drawStackedMetric(String(snapshot.totalCleared), labelKey: "home.cleared_title", center: metricY,
+            drawStackedMetric(String(totalCleared), labelKey: "home.cleared_title", center: metricY,
                               x: split + columnPadding, width: right - split - columnPadding, height: body.height,
-                              color: HomeDashboardStyle.ink, alignment: .right, numberOffset: numberJumpOffset())
+                              color: HomeDashboardStyle.ink, alignment: .right)
             HomeDashboardStyle.line(from: NSPoint(x: split + separatorOffset, y: separatorTop),
                                     to: NSPoint(x: split - separatorOffset, y: separatorBottom), color: HomeDashboardStyle.border)
         } else {
@@ -266,30 +282,28 @@ final class HomeChallengeHUDView: NSView {
             let titleSize = GameLobbyStyle.fittedSize(title, width: titleWidth, preferred: max(12, 21 * face.typographyScale),
                                                        minimum: 10, weight: .bold)
             label(title, x: x, y: body.midY, width: titleWidth, size: titleSize, weight: .bold)
-            let value = String(snapshot.totalCleared)
+            let value = String(totalCleared)
             let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth - 8,
                                                  preferred: max(24, 58 * face.typographyScale), minimum: 12, weight: .black)
-            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1 + numberJumpOffset(),
-                                    width: available - titleWidth, height: body.height),
+            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1, width: available - titleWidth, height: body.height),
                   size: size, weight: .black, alignment: .right)
         }
     }
 
     private func drawStackedMetric(_ value: String, labelKey: String, center: CGFloat, x: CGFloat, width: CGFloat,
-                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment, numberOffset: CGFloat = 0) {
+                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment) {
         let title = AchievementText.string(labelKey)
         let titleSize = GameLobbyStyle.fittedSize(title, width: width, preferred: min(13, height * 0.26),
                                                    minimum: 8, weight: .semibold)
         let valueSize = GameLobbyStyle.fittedSize(value, width: width, preferred: min(38, height * 0.59),
                                                    minimum: 11, weight: .heavy)
-        // 两列使用相同的静止基线，给汇总数字的上跳留出间距。
-        label(title, x: x, y: center - height * 0.24 - 3, width: width, size: titleSize, weight: .semibold,
+        label(title, x: x, y: center - height * 0.24, width: width, size: titleSize, weight: .semibold,
               color: HomeDashboardStyle.muted, alignment: alignment)
-        let number = NSRect(x: x, y: center - height * 0.39 + 3 + numberOffset, width: width, height: height)
+        let number = NSRect(x: x, y: center - height * 0.39, width: width, height: height)
         count(value, in: number, size: valueSize, weight: .heavy, color: color, alignment: alignment)
     }
 
-    private func drawBreakdown(_ snapshot: GameSnapshot, on face: Face) {
+    private func drawBreakdown(_ counts: [PieceKind: Int], on face: Face) {
         // 各分格用独立轮廓，双斜边之间留出原稿中的暗缝。
         let cells = face.breakdownCellRects
         let rim = HomeDashboardStyle.color(0x55616A)
@@ -304,10 +318,9 @@ final class HomeChallengeHUDView: NSView {
             let scale = face.typographyScale
             let icon = NSRect(x: content.minX, y: cell.midY - 15 * scale, width: 42 * scale, height: 30 * scale)
             HomeLobbyArtwork.drawPiece(kind, in: icon)
-            let number = String(snapshot.clearedByKind[kind, default: 0])
+            let number = String(counts[kind, default: 0])
             let numberX = icon.maxX + 12 * scale
-            let slot = NSRect(x: numberX, y: cell.minY + numberJumpOffset(for: kind),
-                              width: max(0, content.maxX - numberX), height: cell.height)
+            let slot = NSRect(x: numberX, y: cell.minY, width: max(0, content.maxX - numberX), height: cell.height)
             let size = GameLobbyStyle.fittedSize(number, width: slot.width, preferred: max(11, 21 * face.typographyScale),
                                                  minimum: 7, weight: .semibold)
             count(number, in: slot, size: size, weight: .semibold)
diff --git a/Tests/HomeChallengeHUDAnimationTests.swift b/Tests/HomeChallengeHUDAnimationTests.swift
index 08e14640d0c80546c113ee0a4ae3915f1e7ecbb1..de51d962d5398b1b90d7d847c63c9f881fe927ef 100644
--- a/Tests/HomeChallengeHUDAnimationTests.swift
+++ b/Tests/HomeChallengeHUDAnimationTests.swift
@@ -3,152 +3,125 @@ import XCTest
 @testable import EliminateTeris1
 
 final class HomeChallengeHUDAnimationTests: XCTestCase {
-    func testTotalAndChangedClassificationsJumpInTheRenderedCard() throws {
+    func testRenderedIntermediateCountsMatchStaticDigitsAtTheSamePosition() throws {
         _ = NSApplication.shared
-        var now: TimeInterval = 100
-        let hud = makeHUD(clock: { now })
-        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
-        now += 0.21
-        assertResting(hud)
-
-        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]), mode: .free)
-        let baseline = try image(of: hud)
-        now += 0.21
-        XCTAssertEqual(hud.numberJumpOffset(), -6, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), -6, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .clevelandZ), -6, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .blueRicky), 0)
-        XCTAssertEqual(hud.numberJumpOffset(for: .rhodeIslandZ), 0)
-        let peak = try image(of: hud)
-
-        let surface = hud.surfaceRect
-        let total = NSRect(x: surface.minX + surface.width * 0.73, y: surface.minY + surface.height * 53 / 186,
-                           width: surface.width * 0.18, height: surface.height * 78 / 186)
-        let cells = hud.breakdownCellRects
-        let typeScale = min(surface.width / 636, surface.height / 186)
-        let regions = cells.map { cell in
-            let cut = HomeDashboardStyle.edgeOffset(for: cell.height)
-            let padding = min(24, (cell.width - cut) * 0.18)
-            let numberX = cell.minX + cut / 2 + padding + 54 * typeScale
-            return NSRect(x: numberX, y: cell.minY + 2, width: cell.maxX - cut / 2 - padding - numberX, height: cell.height - 4)
-        }
-        let areas = [total] + regions
-        // 直接比较同一份数字的亮色像素，只允许总数和两类新消除方块上移。
-        for (index, area) in areas.enumerated() {
-            let before = try digitCenter(in: baseline, area: area, viewSize: hud.bounds.size)
-            let after = try digitCenter(in: peak, area: area, viewSize: hud.bounds.size)
-            let jump: CGFloat = [0, 1, 3].contains(index) ? -6 : 0
-            XCTAssertEqual(after - before, jump, accuracy: 0.75)
-        }
-
-        now += 0.23
-        assertResting(hud)
-        let settled = try image(of: hud)
-        for area in areas {
-            let before = try digitCenter(in: baseline, area: area, viewSize: hud.bounds.size)
-            XCTAssertEqual(try digitCenter(in: settled, area: area, viewSize: hud.bounds.size), before, accuracy: 0.01)
+        let language = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(language) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let lobby = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
+        lobby.layoutSubtreeIfNeeded()
+        let productionSize = lobby.challengeHUD.bounds.size
+        let compact = NSSize(width: 336, height: 148)
+        let cases: [(mode: HomeGameMode, size: NSSize)] = [
+            (.free, NSSize(width: 692, height: 196)),
+            (.timed, productionSize), (.moves, productionSize),
+            (.timed, compact), (.moves, compact)
+        ]
+        let initial: [PieceKind: Int] = [.orangeRicky: 8, .blueRicky: 4]
+        let target: [PieceKind: Int] = [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]
+        let stages: [(time: TimeInterval, counts: [PieceKind: Int])] = [
+            (0.08, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
+            (0.16, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
+            (0.36, target)
+        ]
+        for (mode, size) in cases {
+            var clock: TimeInterval = 0
+            let animated = makeHUD(size: size, clock: { clock })
+            let reference = makeHUD(size: size, clock: { clock }, reducesMotion: { true })
+            animated.refresh(snapshot: snapshot(mode, initial), mode: mode)
+            assertDisplayed(animated, initial)
+            let original = try image(of: animated)
+            animated.refresh(snapshot: snapshot(mode, target), mode: mode)
+            assertDisplayed(animated, initial)
+            XCTAssertEqual(animated.snapshot?.totalCleared, 18, "快照应立即保留实际总数")
+            XCTAssertEqual(try image(of: animated), original)
+
+            // 和相同数值的静态画面逐帧比对，覆盖数字换位数时的基线及分类之和。
+            for stage in stages {
+                clock = stage.time
+                assertDisplayed(animated, stage.counts)
+                reference.refresh(snapshot: snapshot(mode, stage.counts), mode: mode)
+                let frame = try image(of: animated)
+                XCTAssertNotEqual(frame, original, "原生绘制应确实显示新的计数")
+                XCTAssertEqual(frame, try image(of: reference), "\(mode.key)／\(size) 的数字应保持静态绘制位置")
+            }
         }
     }
 
-    func testBudgetAndRepeatedRefreshesDoNotRestartJumps() {
-        var now: TimeInterval = 100
-        let hud = makeHUD(clock: { now })
+    func testBudgetAndRepeatedRefreshesDoNotRestartCounting() {
+        var clock: TimeInterval = 0
+        let hud = makeHUD(clock: { clock })
         hud.refresh(snapshot: snapshot(.moves, [:], movesLeft: 30), mode: .moves)
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 29), mode: .moves)
-        now += 0.12
-        let active = hud.numberJumpOffset()
-        XCTAssertLessThan(active, 0)
+        clock = 0.08
+        assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 28), mode: .moves)
         XCTAssertEqual(hud.budgetText, "28")
-        XCTAssertEqual(hud.numberJumpOffset(), active, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), active, accuracy: 0.001)
-
-        // 最后一手的实际消除也要显示；只有这次新增的数字会重新计时。
-        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3, .blueRicky: 3], movesLeft: 0, finished: true), mode: .moves)
-        XCTAssertEqual(hud.numberJumpOffset(), 0, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .orangeRicky), active, accuracy: 0.001)
-        now += 0.21
-        XCTAssertEqual(hud.numberJumpOffset(), -6, accuracy: 0.001)
-        XCTAssertEqual(hud.numberJumpOffset(for: .blueRicky), -6, accuracy: 0.001)
-        now += 0.23
-        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3, .blueRicky: 3], movesLeft: 0, finished: true), mode: .moves)
-        assertResting(hud)
+        assertDisplayed(hud, [.orangeRicky: 1])
+        clock = 0.16
+        assertDisplayed(hud, [.orangeRicky: 2])
+
+        // 最后一手的实际消除照常滚动，步数和结算快照立即更新。
+        let finished: [PieceKind: Int] = [.orangeRicky: 3, .blueRicky: 3]
+        hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
+        XCTAssertEqual(hud.budgetText, "0")
+        XCTAssertEqual(hud.snapshot?.totalCleared, 6)
+        clock = 0.24
+        assertDisplayed(hud, [.orangeRicky: 2, .blueRicky: 1])
+        clock = 0.53
+        hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
+        assertDisplayed(hud, finished)
 
         hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 59), mode: .timed)
         hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 58), mode: .timed)
-        now += 0.21
         XCTAssertEqual(hud.budgetText, "00:58")
-        assertResting(hud)
+        assertDisplayed(hud, [:])
     }
 
-    func testCompactChallengeTotalLeavesClearanceBelowItsLabelAtPeak() throws {
-        _ = NSApplication.shared
-        let language = Localizer.shared.language
-        defer { Localizer.shared.setLanguage(language) }
-        Localizer.shared.setLanguage(.chineseSimplified)
-        let lobby = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
-        lobby.layoutSubtreeIfNeeded()
-        for size in [lobby.challengeHUD.bounds.size, NSSize(width: 336, height: 148)] {
-            for mode in [HomeGameMode.timed, .moves] {
-                var now: TimeInterval = 100
-                let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size), clock: { now }, reducesMotion: { false })
-                hud.refresh(snapshot: snapshot(mode, [.orangeRicky: 12], movesLeft: 30, timeLeft: 43), mode: mode)
-                hud.refresh(snapshot: snapshot(mode, [.orangeRicky: 15], movesLeft: 29, timeLeft: 42), mode: mode)
-                let baseline = try image(of: hud)
-                now += 0.21
-                let peak = try image(of: hud)
-
-                let surface = hud.surfaceRect
-                let area = NSRect(x: surface.minX + surface.width * 0.55, y: surface.minY + surface.height * 53 / 186,
-                                  width: surface.width * 0.37, height: surface.height * 78 / 186)
-                func labelBottom(in bitmap: NSBitmapImageRep) throws -> CGFloat {
-                    // 标签的蓝灰笔画比近白的汇总数字色差更大。
-                    try XCTUnwrap(inkRows(in: bitmap, area: area, viewSize: size) { pixel in
-                        pixel.redComponent > 0.5 && pixel.greenComponent - pixel.redComponent > 0.04 &&
-                            pixel.blueComponent - pixel.greenComponent > 0.04
-                    }.max())
-                }
-                let baselineTop = try XCTUnwrap(inkRows(in: baseline, area: area, viewSize: size).min())
-                let peakTop = try XCTUnwrap(inkRows(in: peak, area: area, viewSize: size).min())
-                let label = try labelBottom(in: baseline)
-                XCTAssertEqual(try labelBottom(in: peak), label, accuracy: 0.01)
-                XCTAssertEqual(baselineTop - peakTop, 6, accuracy: 0.75)
-                XCTAssertGreaterThanOrEqual(peakTop - label, 2, "\(mode.key) ／ \(size) 的总数在跳峰处仍应与标签留有间距")
-            }
-        }
+    func testRapidGrowthContinuesFromTheVisibleCountWithoutRestartingOtherKinds() {
+        var clock: TimeInterval = 0
+        let hud = makeHUD(clock: { clock })
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 7]), mode: .free)
+        clock = 0.08
+        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7]), mode: .free)
+        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
+        clock = 0.16
+        assertDisplayed(hud, [.orangeRicky: 11, .blueRicky: 6])
+        clock = 0.36
+        assertDisplayed(hud, [.orangeRicky: 13, .blueRicky: 7])
+        clock = 0.45
+        assertDisplayed(hud, [.orangeRicky: 14, .blueRicky: 7])
     }
 
-    func testResetModeChangeAndReducedMotionKeepDigitsAtRest() {
-        var now: TimeInterval = 100
+    func testResetsModeChangesAndReducedMotionImmediatelyDisplayCurrentCounts() {
+        var clock: TimeInterval = 0
         var reducedMotion = false
-        let hud = makeHUD(clock: { now }, reducesMotion: { reducedMotion })
+        let hud = makeHUD(clock: { clock }, reducesMotion: { reducedMotion })
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
-        now += 0.21
-        XCTAssertLessThan(hud.numberJumpOffset(), 0)
+        clock = 0.08
+        assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.free, [:], running: false), mode: .free)
-        XCTAssertEqual(hud.snapshot?.totalCleared, 0)
-        assertResting(hud)
+        assertDisplayed(hud, [:])
 
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.blueRicky: 3]), mode: .free)
-        now += 0.21
-        XCTAssertLessThan(hud.numberJumpOffset(for: .blueRicky), 0)
+        clock = 0.16
+        assertDisplayed(hud, [.blueRicky: 1])
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 9]), mode: .timed)
-        now += 0.21
-        assertResting(hud)
+        assertDisplayed(hud, [.blueRicky: 9])
 
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 12]), mode: .timed)
-        now += 0.12
-        XCTAssertLessThan(hud.numberJumpOffset(), 0)
+        clock = 0.24
+        assertDisplayed(hud, [.blueRicky: 10])
         reducedMotion = true
-        assertResting(hud)
+        assertDisplayed(hud, [.blueRicky: 12])
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 15]), mode: .timed)
-        XCTAssertEqual(hud.snapshot?.totalCleared, 15)
-        now += 0.12
-        assertResting(hud)
+        assertDisplayed(hud, [.blueRicky: 15])
         reducedMotion = false
-        assertResting(hud)
+        assertDisplayed(hud, [.blueRicky: 15])
     }
 
     private func snapshot(_ mode: HomeGameMode, _ counts: [PieceKind: Int], movesLeft: Int? = nil,
@@ -157,44 +130,21 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
                      isRunning: running && !finished, isFinished: finished, clearedByKind: counts)
     }
 
-    private func makeHUD(clock: @escaping () -> TimeInterval, reducesMotion: @escaping () -> Bool = { false }) -> HomeChallengeHUDView {
-        HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: 692, height: 196), clock: clock, reducesMotion: reducesMotion)
+    private func makeHUD(size: NSSize = NSSize(width: 692, height: 196), clock: @escaping () -> TimeInterval,
+                         reducesMotion: @escaping () -> Bool = { false }) -> HomeChallengeHUDView {
+        HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size), clock: clock, reducesMotion: reducesMotion)
     }
 
-    private func assertResting(_ hud: HomeChallengeHUDView, file: StaticString = #filePath, line: UInt = #line) {
-        XCTAssertEqual(hud.numberJumpOffset(), 0, file: file, line: line)
-        for kind in PieceKind.allCases {
-            XCTAssertEqual(hud.numberJumpOffset(for: kind), 0, file: file, line: line)
-        }
+    private func assertDisplayed(_ hud: HomeChallengeHUDView, _ expected: [PieceKind: Int],
+                                 file: StaticString = #filePath, line: UInt = #line) {
+        let allKinds = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { ($0, expected[$0, default: 0]) })
+        XCTAssertEqual(hud.displayedCounts(), allKinds, file: file, line: line)
     }
 
-    private func image(of hud: HomeChallengeHUDView) throws -> NSBitmapImageRep {
+    private func image(of hud: HomeChallengeHUDView) throws -> Data {
         hud.needsDisplay = true
         let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: hud.bounds))
         hud.cacheDisplay(in: hud.bounds, to: bitmap)
-        return bitmap
-    }
-
-    private func digitCenter(in bitmap: NSBitmapImageRep, area: NSRect, viewSize: NSSize) throws -> CGFloat {
-        let rows = inkRows(in: bitmap, area: area, viewSize: viewSize)
-        XCTAssertFalse(rows.isEmpty, "应能找到原生数字笔画")
-        return rows.reduce(0, +) / CGFloat(max(1, rows.count))
-    }
-
-    private func inkRows(in bitmap: NSBitmapImageRep, area: NSRect, viewSize: NSSize,
-                         matches: (NSColor) -> Bool = { min($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.75 }) -> [CGFloat] {
-        let scaleX = CGFloat(bitmap.pixelsWide) / viewSize.width
-        let scaleY = CGFloat(bitmap.pixelsHigh) / viewSize.height
-        let columns = Int(ceil(area.minX * scaleX))..<Int(floor(area.maxX * scaleX))
-        let rows = Int(ceil(area.minY * scaleY))..<Int(floor(area.maxY * scaleY))
-        var hits: [CGFloat] = []
-        for y in rows {
-            for x in columns {
-                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
-                      color.alphaComponent > 0.85, matches(color) else { continue }
-                hits.append(CGFloat(y) / scaleY)
-            }
-        }
-        return hits
+        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
     }
 }
```
