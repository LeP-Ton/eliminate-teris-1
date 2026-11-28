# 统计卡预算填充与上沿扫光同步

## 背景与目标

- 会话-136 要求背板进度条与前板上沿的蓝色扫光同时开始。

## 实施

- 扫光和预算填充共用叠合开始后 0.936 秒的时间点。进度条用 0.60 秒填到满值或当前剩余量。
- 限时从轨道左端连续增长。限步在起播帧点亮第一格，随后逐格推进，最终显示实际剩余格数。

## 验证

- 原生像素回归验证扫光之前为空轨，起播后的同一帧出现限时轨道的第一段青色和限步轨道的第一格，并覆盖开局与消耗后的剩余目标。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 共 109 项全部通过。查看原生动图帧，确认扫光和进度条可同时看到。
- 运行 `./run.sh` 后切到限时或限步，可观察前板上沿亮线出现时进度条开始填充。

## 本轮完整增量 diff

以会话-136 开始时的提交为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 12d291ad457fbac1c438e5b3ddb4a3050077154d..a202d110a3d8e431ce9db59f8e6ab1f66f31bef5 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128094456-synchronize-budget-fill-with-highlight.md` - 会话-136 起让统计卡预算填充和前板上沿扫光同步起播。
 `workflow/20261128090504-animate-statistics-budget-fill.md` - 会话-129 起在统计卡叠合后从零填充挑战预算，开局后动态跟随剩余值。
 `workflow/20261128084215-make-statistics-fade-visible.md` - 会话-124 起改为匀速淡入，每次换模式从透明起步，含真实窗口轨道像素实测。
 `workflow/20261127231423-match-statistics-plate-heights.md` - 会话-120 起将统计背板高度与前板总数和分类的合计高度对齐。
@@ -120,6 +121,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡扫光和预算填充的共同起点，读取 `20261128094456-synchronize-budget-fill-with-highlight.md`。
 - 需要调整切换模式后的预算填充、开局时的剩余目标或限步分格显示时，读取 `20261128090504-animate-statistics-budget-fill.md`。
 - 需要调整统计卡淡入的可见节奏或验证快速换模式也从透明开始时，读取 `20261128084215-make-statistics-fade-visible.md`。
 - 需要调整统计背板与前板的等高关系或检查分层时的底边位置，读取 `20261127231423-match-statistics-plate-heights.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 697213b2a28a0fd273da75e3cfcc1a5f57a20a96..8416be417a7ae10d1e43230cccde1265946fdeaf 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -469,7 +469,8 @@ final class HomeChallengeHUDView: NSView {
             // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
             let limit = HomeGameMode.moveLimit
             let remaining = min(limit, max(0, snapshot.remainingSwaps ?? limit))
-            let lit = Int(CGFloat(remaining) * budgetFillProgress)
+            // 第一格随扫光起播，其余格按填充进度逐个点亮。
+            let lit = Int(ceil(CGFloat(remaining) * budgetFillProgress))
             let cut = HomeDashboardStyle.edgeOffset(for: track.height)
             let available = max(0, track.width - cut)
             let gap = min(2, available / CGFloat(limit * 2))
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 99238ca84a11ffe2300f59f405090fe165042663..4cfedae0ff3cdbecb9a58c87d7d6fad487729d2f 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -3,6 +3,7 @@ import Cocoa
 /// 上方文案和本局统计并排排版，切换模式时交错叠合统计卡的前后两层。
 final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1.20
+    static let joinHighlightStart: TimeInterval = previewDuration * 0.78
     static let budgetFillDuration: TimeInterval = 0.60
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
@@ -86,25 +87,27 @@ final class HomeModeHeaderView: NSView {
             return
         }
         let elapsed = max(0, currentTime - transitionStart)
+        // 扫光和预算填充同一帧起播，各自按原时长结束。
+        let highlightElapsed = elapsed - Self.joinHighlightStart
+        let fillProgress = min(1, max(0, highlightElapsed / Self.budgetFillDuration))
         if elapsed >= Self.previewDuration {
-            let progress = (elapsed - Self.previewDuration) / Self.budgetFillDuration
-            guard card.mode != .free, progress < 1 else {
+            guard card.mode != .free, fillProgress < 1 else {
                 settle()
                 return
             }
             finishAssembly()
-            card.budgetFillProgress = CGFloat(progress)
-            return
+        } else {
+            let time = CGFloat(elapsed / Self.previewDuration)
+            let backingRemaining = 1 - min(1, time / 0.62)
+            let frontTime = min(1, max(0, (time - 0.12) / 0.66))
+            let opacity = CGFloat(min(1, elapsed / Self.joinHighlightStart))
+            let highlight = CGFloat(max(0, highlightElapsed / (Self.previewDuration - Self.joinHighlightStart)))
+            card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining,
+                                       front: frontTime * frontTime * (3 - 2 * frontTime),
+                                       opacity: opacity,
+                                       highlight: highlight)
         }
-        let time = CGFloat(elapsed / Self.previewDuration)
-        let backingRemaining = 1 - min(1, time / 0.62)
-        let frontTime = min(1, max(0, (time - 0.12) / 0.66))
-        let opacity = min(1, time / 0.78)
-        let highlight = max(0, (time - 0.78) / 0.22)
-        card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining,
-                                   front: frontTime * frontTime * (3 - 2 * frontTime),
-                                   opacity: opacity,
-                                   highlight: highlight)
+        if card.mode != .free { card.budgetFillProgress = CGFloat(fillProgress) }
     }
 
     override func viewDidMoveToWindow() {
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 61fec3bccc8aad8f7c0bc99f402a9e280c5ec642..04681add300259c2f36cc6cc7eebf3b6e87e9c7d 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -554,8 +554,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         var transitionStartedAt = clock
         header.now = { clock }
         header.reducesMotion = { false }
-        let assemblyDuration = HomeModeHeaderView.previewDuration
+        let sharedStart = HomeModeHeaderView.joinHighlightStart
         let fillDuration = HomeModeHeaderView.budgetFillDuration
+        let firstFrameInterval = 1.0 / 60
         XCTAssertEqual(fillDuration, 0.60, accuracy: 0.001)
 
         func refresh(_ mode: HomeGameMode, seconds: TimeInterval? = nil, swaps: Int? = nil, running: Bool = false) {
@@ -606,30 +607,40 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertNil(hud.budgetTrackRect)
         refresh(.timed, seconds: 60)
         beginTransition()
-        advance(to: assemblyDuration * 0.96)
-        XCTAssertNotEqual(hud.plateAssembly, .settled)
+        advance(to: sharedStart - firstFrameInterval)
+        XCTAssertEqual(hud.plateAssembly.highlight, 0)
         XCTAssertEqual(hud.budgetFillProgress, 0)
-        XCTAssertTrue(try litColumns().isEmpty, "叠合期间只绘制暗色轨道")
+        XCTAssertTrue(try litColumns().isEmpty, "接缝扫光前只绘制暗色轨道")
 
         let steps = 12
+        let offsets = [0, firstFrameInterval] + (1...steps).map { fillDuration * Double($0) / Double(steps) }
         let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-budget-fill.gif")
-        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
+        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, offsets.count, nil))
         CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
         var fillColumns: [[Int]] = []
-        for step in 0...steps {
-            let fraction = Double(step) / Double(steps)
-            advance(to: assemblyDuration + fillDuration * fraction + (step == steps ? 0.001 : 0))
+        for (step, offset) in offsets.enumerated() {
+            let isLast = step == offsets.count - 1
+            let fraction = CGFloat(offset / fillDuration)
+            advance(to: sharedStart + offset + (isLast ? 0.001 : 0))
             home.layoutSubtreeIfNeeded()
-            XCTAssertEqual(hud.plateAssembly, .settled, "预算填充开始时两层已到位")
-            XCTAssertEqual(hud.budgetFillProgress, CGFloat(fraction), accuracy: 0.001)
-            XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(fraction), accuracy: 0.001)
-            if step == 0 || step == steps / 4 || step == steps / 2 || step == steps {
+            XCTAssertEqual(hud.plateAssembly.backing, 1, accuracy: 0.001, "扫光开始时背板已到位")
+            XCTAssertEqual(hud.plateAssembly.front, 1, accuracy: 0.001, "扫光开始时前板已到位")
+            XCTAssertEqual(hud.budgetFillProgress, fraction, accuracy: 0.001)
+            XCTAssertEqual(hud.displayedBudgetFraction, fraction, accuracy: 0.001)
+            if step == 0 {
+                XCTAssertEqual(hud.plateAssembly.highlight, 0, accuracy: 0.001)
+            } else if step == 1 {
+                XCTAssertGreaterThan(hud.plateAssembly.highlight, 0, "扫光和预算在同一帧开始")
+                XCTAssertGreaterThan(hud.budgetFillProgress, 0)
+                XCTAssertFalse(try litColumns().isEmpty, "限时轨道随扫光出现第一段青色填充")
+            }
+            if step == 0 || step == 1 + steps / 4 || step == 1 + steps / 2 || isLast {
                 fillColumns.append(try litColumns())
             }
             let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
             home.cacheDisplay(in: header.frame, to: bitmap)
             let frame = try XCTUnwrap(bitmap.cgImage)
-            let delay = step == steps ? 1.0 : fillDuration / Double(steps)
+            let delay = isLast ? 1.0 : offsets[step + 1] - offset
             CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
         }
         XCTAssertTrue(CGImageDestinationFinalize(gif))
@@ -647,24 +658,32 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         refresh(.moves, swaps: 30)
         XCTAssertEqual(hud.budgetFillProgress, 0)
         beginTransition()
-        advance(to: assemblyDuration + fillDuration * 0.34)
-        XCTAssertEqual(try litSegments(), 10, "限步只显示填满的整格")
+        advance(to: sharedStart - firstFrameInterval)
+        XCTAssertEqual(hud.plateAssembly.highlight, 0)
+        XCTAssertEqual(hud.budgetFillProgress, 0)
+        XCTAssertEqual(try litSegments(), 0)
+        advance(to: sharedStart + firstFrameInterval)
+        XCTAssertGreaterThan(hud.plateAssembly.highlight, 0)
+        XCTAssertGreaterThan(hud.budgetFillProgress, 0)
+        XCTAssertEqual(try litSegments(), 1, "限步第一格随扫光出现")
+        advance(to: sharedStart + fillDuration * 0.34)
+        XCTAssertEqual(try litSegments(), 11, "限步填充以整格逐一显示")
         refresh(.moves, swaps: 30, running: true)
         XCTAssertEqual(hud.budgetFillProgress, 0.34, accuracy: 0.001, "填充期间开局保留当前进度")
-        XCTAssertEqual(try litSegments(), 10)
+        XCTAssertEqual(try litSegments(), 11)
         refresh(.moves, swaps: 13, running: true)
         XCTAssertEqual(hud.remainingFraction, CGFloat(13) / 30, accuracy: 0.001)
         XCTAssertEqual(hud.displayedBudgetFraction, CGFloat(13) / 30 * 0.34, accuracy: 0.001)
-        XCTAssertEqual(try litSegments(), 4, "按填充进度换算当前剩余交换次数")
-        advance(to: assemblyDuration + fillDuration * 0.72)
-        XCTAssertEqual(try litSegments(), 9)
-        advance(to: assemblyDuration + fillDuration + 0.001)
+        XCTAssertEqual(try litSegments(), 5, "按填充进度换算当前剩余交换次数")
+        advance(to: sharedStart + fillDuration * 0.72)
+        XCTAssertEqual(try litSegments(), 10)
+        advance(to: sharedStart + fillDuration + 0.001)
         XCTAssertEqual(hud.budgetFillProgress, 1)
         XCTAssertEqual(try litSegments(), 13, "动画结束时准确显示实际剩余步数")
 
         refresh(.timed, seconds: 60)
         beginTransition()
-        advance(to: assemblyDuration + fillDuration * 0.5)
+        advance(to: sharedStart + fillDuration * 0.5)
         XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
         refresh(.timed, seconds: 42, running: true)
         XCTAssertEqual(hud.budgetFillProgress, 0.5, accuracy: 0.001)
```
