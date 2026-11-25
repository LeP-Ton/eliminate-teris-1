# 消除统计数字等间隔递增

## 背景与目标

- 会话-45 至会话-46 确认 `3 → 6` 的最后一次变化等待约 250 毫秒，占整个 360 毫秒动画的约七成。
- 将三次缓出改为线性进度，让每个整数变化分到相等时间。动画总时长仍为 360 毫秒，数字在原位绘制。

## 验证

- 对 `3 → 4 → 5 → 6` 在 120、240 和 360 毫秒三个边界前后各取一帧，断言每次都按等间隔到达。
- 复核原生绘制、总数与分类同步、连续消除、重开归零与减少动态效果。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 103 项，全部通过。
- 手动验证可运行 `./run.sh`，选自由模式开局，消除两次三连，观察第二次消除时 `3 → 4 → 5 → 6` 的三个间隔。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 03107a41a965c694e1dba52fac93879199d745ff..9198388fd9b170802308c3247ddafc6134763d9a 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124232704-even-stat-count-step-intervals.md` - 会话-51 起让统计数字等间隔递增，消除最后一步的停顿，并补上节奏边界回归。
 `workflow/20261124225830-animate-stat-count-values-in-place.md` - 会话-42 起改为在原位逐步递增消除统计值，连续消除从画面当前值接续，汇总与分类同步。
 `workflow/20261124223031-restore-space-start-and-stat-number-jumps.md` - 会话-38 起修复模式卡保留焦点时的空格开局，并恢复消除总数和变化分类数字的跳动。
 `workflow/20261124215116-raise-mode-card-icon-plates.md` - 会话-35 起给右侧四张游戏模式卡加入凸出上沿的斜面图标前层，含原生渲染与紧凑布局验证。
@@ -108,6 +109,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整消除统计每次变数的间隔或核对最后一步的节奏时，读取 `20261124232704-even-stat-count-step-intervals.md`。
 - 需要调整消除统计的数字递增、动画快速接续、静态基线或汇总与分类同步时，读取 `20261124225830-animate-stat-count-values-in-place.md`。
 - 需要核对空格开局的主窗口焦点边界，或调整消除统计数字的跳动、归零及减少动态效果时，读取 `20261124223031-restore-space-start-and-stat-number-jumps.md`。
 - 需要调整右侧游戏模式卡的图标前层、立体侧沿、选中色或上沿留空时，读取 `20261124215116-raise-mode-card-icon-plates.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 1f5d5decd90139773b4d289378b85c100b94a362..567f547f923bce566d0f365425d9f362b599ffe4 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -93,7 +93,8 @@ final class HomeChallengeHUDView: NSView {
             let progress = max(0, now - start) / HomeChallengeHUDView.countAnimationDuration
             guard progress < 1 else { return target }
             let distance = Double(target - initial)
-            let advance = floor(distance * (1 - pow(1 - progress, 3)))
+            // 等分各次整数变化的时间，最后一次与前面的步长相同。
+            let advance = floor(distance * progress)
             return advance < distance ? initial + Int(advance) : target
         }
     }
diff --git a/Tests/HomeChallengeHUDAnimationTests.swift b/Tests/HomeChallengeHUDAnimationTests.swift
index de51d962d5398b1b90d7d847c63c9f881fe927ef..6e8ca2cc37d781ae1820e41815deed52944b60fa 100644
--- a/Tests/HomeChallengeHUDAnimationTests.swift
+++ b/Tests/HomeChallengeHUDAnimationTests.swift
@@ -20,8 +20,8 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let initial: [PieceKind: Int] = [.orangeRicky: 8, .blueRicky: 4]
         let target: [PieceKind: Int] = [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]
         let stages: [(time: TimeInterval, counts: [PieceKind: Int])] = [
-            (0.08, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
-            (0.16, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
+            (0.19, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
+            (0.31, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
             (0.36, target)
         ]
         for (mode, size) in cases {
@@ -36,7 +36,7 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
             XCTAssertEqual(animated.snapshot?.totalCleared, 18, "快照应立即保留实际总数")
             XCTAssertEqual(try image(of: animated), original)
 
-            // 和相同数值的静态画面逐帧比对，覆盖数字换位数时的基线及分类之和。
+            // 和相同数值的静态画面逐帧比对，覆盖位数变化时的基线及分类之和。
             for stage in stages {
                 clock = stage.time
                 assertDisplayed(animated, stage.counts)
@@ -48,27 +48,42 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         }
     }
 
+    func testThreeCountIncreaseAdvancesAtUniform120MillisecondIntervals() {
+        var clock: TimeInterval = 0
+        let hud = makeHUD(clock: { clock })
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
+        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 6]), mode: .free)
+        // 在每个整步的前后各取一帧，确认最后一步与前两步等长。
+        let samples: [(time: TimeInterval, count: Int)] = [
+            (0, 3), (0.119, 3), (0.121, 4), (0.239, 4), (0.241, 5), (0.359, 5), (0.361, 6)
+        ]
+        for sample in samples {
+            clock = sample.time
+            assertDisplayed(hud, [.orangeRicky: sample.count])
+        }
+    }
+
     func testBudgetAndRepeatedRefreshesDoNotRestartCounting() {
         var clock: TimeInterval = 0
         let hud = makeHUD(clock: { clock })
         hud.refresh(snapshot: snapshot(.moves, [:], movesLeft: 30), mode: .moves)
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 29), mode: .moves)
-        clock = 0.08
+        clock = 0.13
         assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 28), mode: .moves)
         XCTAssertEqual(hud.budgetText, "28")
         assertDisplayed(hud, [.orangeRicky: 1])
-        clock = 0.16
+        clock = 0.26
         assertDisplayed(hud, [.orangeRicky: 2])
 
-        // 最后一手的实际消除照常滚动，步数和结算快照立即更新。
+        // 最后一手的实际消除照常递增，步数和结算快照立即更新。
         let finished: [PieceKind: Int] = [.orangeRicky: 3, .blueRicky: 3]
         hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
         XCTAssertEqual(hud.budgetText, "0")
         XCTAssertEqual(hud.snapshot?.totalCleared, 6)
-        clock = 0.24
-        assertDisplayed(hud, [.orangeRicky: 2, .blueRicky: 1])
-        clock = 0.53
+        clock = 0.39
+        assertDisplayed(hud, [.orangeRicky: 3, .blueRicky: 1])
+        clock = 0.63
         hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
         assertDisplayed(hud, finished)
 
@@ -83,15 +98,15 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let hud = makeHUD(clock: { clock })
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 7]), mode: .free)
-        clock = 0.08
+        clock = 0.13
         assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7]), mode: .free)
         assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
-        clock = 0.16
-        assertDisplayed(hud, [.orangeRicky: 11, .blueRicky: 6])
+        clock = 0.26
+        assertDisplayed(hud, [.orangeRicky: 10, .blueRicky: 6])
         clock = 0.36
-        assertDisplayed(hud, [.orangeRicky: 13, .blueRicky: 7])
-        clock = 0.45
+        assertDisplayed(hud, [.orangeRicky: 12, .blueRicky: 7])
+        clock = 0.50
         assertDisplayed(hud, [.orangeRicky: 14, .blueRicky: 7])
     }
 
@@ -101,20 +116,20 @@ final class HomeChallengeHUDAnimationTests: XCTestCase {
         let hud = makeHUD(clock: { clock }, reducesMotion: { reducedMotion })
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
-        clock = 0.08
+        clock = 0.13
         assertDisplayed(hud, [.orangeRicky: 1])
         hud.refresh(snapshot: snapshot(.free, [:], running: false), mode: .free)
         assertDisplayed(hud, [:])
 
         hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
         hud.refresh(snapshot: snapshot(.free, [.blueRicky: 3]), mode: .free)
-        clock = 0.16
+        clock = 0.26
         assertDisplayed(hud, [.blueRicky: 1])
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 9]), mode: .timed)
         assertDisplayed(hud, [.blueRicky: 9])
 
         hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 12]), mode: .timed)
-        clock = 0.24
+        clock = 0.39
         assertDisplayed(hud, [.blueRicky: 10])
         reducedMotion = true
         assertDisplayed(hud, [.blueRicky: 12])
```
