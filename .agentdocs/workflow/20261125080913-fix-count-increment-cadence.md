# 统计数字固定每一跳的时间

## 背景与目标

- 会话-53 至会话-55 讨论了按消除量缩放间隔的现象。会话-56 按确认的方案将每次更新统一为 60 毫秒。
- 普通单类消除每拍加 1。消除 3 个约需 180 毫秒，消除 9 个约需 540 毫秒。

## 实现

- 各分类共用单调时钟的同一个节拍。动画期间再次消除时，只按当前计数更新目标，下一拍沿用原来的时间。新增长的分类也可加入正在运行的节拍。总数继续由同一帧的分类数字求和。
- 大量消除时每类最多用十拍追上目标，共约 600 毫秒。每拍的增量按商和余数分配，必要时一次加多个，兼顾节拍和追赶速度。
- 可见窗口的绘制沿用现有刷新时钟。重开、换模式和系统“减少动态效果”沿用直接显示实际值的处理。

## 验证

- 在每一拍前后取样核对 +3、+9、连续同类追加、异类加入和空闲后的新起点。大增量测试验证十拍合并与整数边界。
- 核对三种模式的原生数字位置、预算更新、最后一步结算及减少动态效果。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 104 项，全部通过。
- 手动验证可运行 `./run.sh`，在首页开局，比较三连和较大连锁的递增节奏。一次计数尚在递增时再完成消除，可观察下一拍按原节奏继续。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 9198388fd9b170802308c3247ddafc6134763d9a..0dc75abd3f0fb6212865f1f33d67869147b9052f 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
 `workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
 `workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
 `workflow/20261124223031-restore-space-start-and-stat-number-jumps.md` - 会话-38 起修复模式卡保留焦点时的空格开局，并恢复消除总数和变化分类数字的跳动。
@@ -109,6 +110,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
 - 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
 - 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
 - 需要核对空格开局的主窗口焦点边界，或调整消除统计数字的跳动、归零及减少动态效果时，读取 `20261124223031-restore-space-start-and-stat-number-jumps.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 567f547f923bce566d0f365425d9f362b599ffe4..168fc6b6fdaaed5dcd4c6fd7a76c425d6b41f6f3 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -6,7 +6,8 @@ final class HomeChallengeHUDView: NSView {
     static let trailingInset: CGFloat = 3
     private static let rearOverhang: CGFloat = 0.08
     private static let rearTopInset: CGFloat = 45 / 636
-    private static let countAnimationDuration: TimeInterval = 0.36
+    private static let countStepInterval: TimeInterval = 0.06
+    private static let maxCountSteps = 10
 
     static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
         max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
@@ -87,21 +88,27 @@ final class HomeChallengeHUDView: NSView {
     private struct CountTransition {
         let initial: Int
         let target: Int
-        let start: TimeInterval
-
-        func value(at now: TimeInterval) -> Int {
-            let progress = max(0, now - start) / HomeChallengeHUDView.countAnimationDuration
-            guard progress < 1 else { return target }
-            let distance = Double(target - initial)
-            // 等分各次整数变化的时间，最后一次与前面的步长相同。
-            let advance = floor(distance * progress)
-            return advance < distance ? initial + Int(advance) : target
+        let startStep: Int
+
+        private var stepCount: Int { min(target - initial, HomeChallengeHUDView.maxCountSteps) }
+        var endStep: Int { startStep + stepCount }
+
+        func value(at step: Int) -> Int {
+            guard step < endStep else { return target }
+            let completed = max(0, step - startStep)
+            let distance = target - initial
+            let steps = stepCount
+            // 增量过大时在同一个节拍里多加几个，十拍内补齐。
+            let perStep = distance / steps
+            let extra = (completed * (distance % steps) + steps - 1) / steps
+            return initial + completed * perStep + extra
         }
     }
 
     private let animationClock: () -> TimeInterval
     private let reducesMotion: () -> Bool
     private var countTransitions: [PieceKind: CountTransition] = [:]
+    private var countAnimationStart: TimeInterval?
     private var countAnimationTimer: Timer?
     var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
     override var isFlipped: Bool { true }
@@ -158,14 +165,19 @@ final class HomeChallengeHUDView: NSView {
 
     /// 同一帧共用一个时间采样，汇总与四个分类同步更新。
     func displayedCounts() -> [PieceKind: Int] {
-        let now = animationClock()
+        let step = countStep(at: animationClock())
         let transitions = reducesMotion() ? [:] : countTransitions
         return Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { kind in
-            let value = transitions[kind]?.value(at: now) ?? snapshot?.clearedByKind[kind, default: 0] ?? 0
+            let value = transitions[kind]?.value(at: step) ?? snapshot?.clearedByKind[kind, default: 0] ?? 0
             return (kind, value)
         })
     }
 
+    private func countStep(at now: TimeInterval) -> Int {
+        guard let countAnimationStart else { return 0 }
+        return Int(max(0, now - countAnimationStart) / Self.countStepInterval)
+    }
+
     private func updateCountAnimation(snapshot: GameSnapshot, mode: HomeGameMode) {
         guard let previous = self.snapshot, self.mode == mode, previous.mode == snapshot.mode,
               snapshot.isRunning || snapshot.isFinished, !(previous.isFinished && snapshot.isRunning),
@@ -174,19 +186,27 @@ final class HomeChallengeHUDView: NSView {
             return
         }
         let now = animationClock()
-        countTransitions = countTransitions.filter { now - $0.value.start < Self.countAnimationDuration }
+        let step = countStep(at: now)
+        countTransitions = countTransitions.filter { step < $0.value.endStep }
+        let startsNewSequence = countTransitions.isEmpty
+        let startStep = startsNewSequence ? 0 : step
         for kind in PieceKind.allCases {
             let value = snapshot.clearedByKind[kind, default: 0]
             let previousValue = previous.clearedByKind[kind, default: 0]
             if value > previousValue {
-                // 连续消除从当前屏幕数字继续累加，避免突然跳到上一笔的目标值。
-                let initial = countTransitions[kind]?.value(at: now) ?? previousValue
-                countTransitions[kind] = CountTransition(initial: initial, target: value, start: now)
+                // 所有分类沿用同一节拍，插入新的消除时只更新终点。
+                let initial = countTransitions[kind]?.value(at: step) ?? previousValue
+                countTransitions[kind] = CountTransition(initial: initial, target: value, startStep: startStep)
             } else if value < previousValue {
                 countTransitions.removeValue(forKey: kind)
             }
         }
-        guard !countTransitions.isEmpty, countAnimationTimer == nil, isCountAnimationVisible else { return }
+        guard !countTransitions.isEmpty else {
+            stopCountAnimation()
+            return
+        }
+        if startsNewSequence { countAnimationStart = now }
+        guard countAnimationTimer == nil, isCountAnimationVisible else { return }
         let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advanceCountAnimation() }
         RunLoop.main.add(timer, forMode: .common)
         countAnimationTimer = timer
@@ -198,14 +218,15 @@ final class HomeChallengeHUDView: NSView {
     }
 
     private func advanceCountAnimation() {
-        let now = animationClock()
-        countTransitions = countTransitions.filter { now - $0.value.start < Self.countAnimationDuration }
+        let step = countStep(at: animationClock())
+        countTransitions = countTransitions.filter { step < $0.value.endStep }
         if countTransitions.isEmpty || reducesMotion() || !isCountAnimationVisible { stopCountAnimation() }
         needsDisplay = true
     }
 
     private func stopCountAnimation() {
         countTransitions.removeAll()
+        countAnimationStart = nil
         countAnimationTimer?.invalidate()
         countAnimationTimer = nil
     }
diff --git a/Tests/HomeChallengeHUDAnimationTests.swift b/Tests/HomeChallengeHUDAnimationTests.swift
index 6e8ca2cc37d781ae1820e41815deed52944b60fa..71c220ac6d0d33e42eebe0626d4479b5e8d8053a 100644
--- a/Tests/HomeChallengeHUDAnimationTests.swift
+++ b/Tests/HomeChallengeHUDAnimationTests.swift
@@ -20,9 +20,9 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let initial: [PieceKind: Int] = [.orangeRicky: 8, .blueRicky: 4]
         let target: [PieceKind: Int] = [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]
         let stages: [(time: TimeInterval, counts: [PieceKind: Int])] = [
-            (0.19, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
-            (0.31, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
-            (0.36, target)
+            (0.061, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
+            (0.121, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
+            (0.181, target)
         ]
         for (mode, size) in cases {
             var clock: TimeInterval = 0
@@ -48,18 +48,30 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         }
     }
 
-    func testThreeCountIncreaseAdvancesAtUniform120MillisecondIntervals() {
-        var clock: TimeInterval = 0
-        let hud = makeHUD(clock: { clock })
-        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
-        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 6]), mode: .free)
-        // 在每个整步的前后各取一帧，确认最后一步与前两步等长。
-        let samples: [(time: TimeInterval, count: Int)] = [
-            (0, 3), (0.119, 3), (0.121, 4), (0.239, 4), (0.241, 5), (0.359, 5), (0.361, 6)
-        ]
-        for sample in samples {
-            clock = sample.time
-            assertDisplayed(hud, [.orangeRicky: sample.count])
+    func testSmallChangesAlwaysUseSixtyMillisecondBeats() {
+        for increase in [3, 9] {
+            var clock: TimeInterval = 0
+            let hud = makeHUD(clock: { clock })
+            let initial = 3
+            let target = initial + increase
+            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: initial]), mode: .free)
+            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target]), mode: .free)
+            // 每拍前后各取一帧，确认 +3 与 +9 的每一步始终相隔 60 毫秒。
+            for step in 1...increase {
+                let beat = Double(step) * 0.06
+                clock = beat - 0.001
+                assertDisplayed(hud, [.orangeRicky: initial + step - 1])
+                clock = beat + 0.001
+                assertDisplayed(hud, [.orangeRicky: initial + step])
+            }
+
+            let newStart = Double(increase) * 0.06 + 0.023
+            clock = newStart
+            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target + 1]), mode: .free)
+            clock = newStart + 0.059
+            assertDisplayed(hud, [.orangeRicky: target])
+            clock = newStart + 0.061
+            assertDisplayed(hud, [.orangeRicky: target + 1])
         }
     }
 
@@ -68,12 +80,12 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let hud = makeHUD(clock: { clock })
         hud.refresh(snapshot: snapshot(.moves, [:], movesLeft: 30), mode: .moves)
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 29), mode: .moves)
-        clock = 0.13
+        clock = 0.071
         assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 28), mode: .moves)
         XCTAssertEqual(hud.budgetText, "28")
         assertDisplayed(hud, [.orangeRicky: 1])
-        clock = 0.26
+        clock = 0.131
         assertDisplayed(hud, [.orangeRicky: 2])
 
         // 最后一手的实际消除照常递增，步数和结算快照立即更新。
@@ -81,9 +93,9 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
         XCTAssertEqual(hud.budgetText, "0")
         XCTAssertEqual(hud.snapshot?.totalCleared, 6)
-        clock = 0.39
+        clock = 0.181
         assertDisplayed(hud, [.orangeRicky: 3, .blueRicky: 1])
-        clock = 0.63
+        clock = 0.301
         hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
         assertDisplayed(hud, finished)
 
@@ -93,21 +105,51 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         assertDisplayed(hud, [:])
     }
 
-    func testRapidGrowthContinuesFromTheVisibleCountWithoutRestartingOtherKinds() {
+    func testRapidGrowthKeepsTheSameBeatForExistingAndNewKinds() {
         var clock: TimeInterval = 0
         let hud = makeHUD(clock: { clock })
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 7]), mode: .free)
-        clock = 0.13
+        clock = 0.081
         assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7]), mode: .free)
         assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
-        clock = 0.26
+        clock = 0.119
+        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
+        clock = 0.121
         assertDisplayed(hud, [.orangeRicky: 10, .blueRicky: 6])
-        clock = 0.36
-        assertDisplayed(hud, [.orangeRicky: 12, .blueRicky: 7])
-        clock = 0.50
-        assertDisplayed(hud, [.orangeRicky: 14, .blueRicky: 7])
+        clock = 0.149
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7, .clevelandZ: 3]), mode: .free)
+        clock = 0.179
+        assertDisplayed(hud, [.orangeRicky: 10, .blueRicky: 6])
+        clock = 0.181
+        assertDisplayed(hud, [.orangeRicky: 11, .blueRicky: 7, .clevelandZ: 1])
+        clock = 0.301
+        assertDisplayed(hud, [.orangeRicky: 13, .blueRicky: 7, .clevelandZ: 3])
+        clock = 0.361
+        assertDisplayed(hud, [.orangeRicky: 14, .blueRicky: 7, .clevelandZ: 3])
+    }
+
+    func testLargeChangesDistributeTheRemainderAndSettleInTenBeats() {
+        let expectedForTwelve = [0, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12]
+        let largest = Int.max
+        let expectedForLargest = (0...10).map { step in
+            (largest / 10) * step + ((largest % 10) * step + 9) / 10
+        }
+        for (target, steps) in [(12, expectedForTwelve), (largest, expectedForLargest)] {
+            var clock: TimeInterval = 0
+            let hud = makeHUD(clock: { clock })
+            hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
+            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target]), mode: .free)
+            // 大数量按拍追赶，确认第 10 拍前仍有余量，且极值计算不丢位。
+            for step in 1...10 {
+                let beat = Double(step) * 0.06
+                clock = beat - 0.001
+                assertDisplayed(hud, [.orangeRicky: steps[step - 1]])
+                clock = beat + 0.001
+                assertDisplayed(hud, [.orangeRicky: steps[step]])
+            }
+        }
     }
 
     func testResetsModeChangesAndReducedMotionImmediatelyDisplayCurrentCounts() {
@@ -116,20 +158,20 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let hud = makeHUD(clock: { clock }, reducesMotion: { reducedMotion })
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
-        clock = 0.13
+        clock = 0.071
         assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.free, [:], running: false), mode: .free)
         assertDisplayed(hud, [:])
 
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.blueRicky: 3]), mode: .free)
-        clock = 0.26
+        clock = 0.142
         assertDisplayed(hud, [.blueRicky: 1])
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 9]), mode: .timed)
         assertDisplayed(hud, [.blueRicky: 9])
 
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 12]), mode: .timed)
-        clock = 0.39
+        clock = 0.213
         assertDisplayed(hud, [.blueRicky: 10])
         reducedMotion = true
         assertDisplayed(hud, [.blueRicky: 12])
```
