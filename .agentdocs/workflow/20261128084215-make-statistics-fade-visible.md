# 让统计卡每次换模式都能看到淡入

## 背景与目标

- 会话-124 反馈统计卡从透明到显现不明显，要求实测。
- 原生窗口通过模式按钮切换并采样预算轨道，确认旧版第一次切换从透明起步，但 0.284 秒便到半透明。在限时叠合期间切到限步，新的轨道首张采样已有约 51% 的不透明度，沿用了上一轮的进度。

## 实施

- 两层牌面一同匀速从全透明过渡到完整亮度，卡片合拢后扫过接缝高光。统计卡叠合仍在 1.20 秒内完成。
- 每次实际换到不同模式就重新播放透明起步的转场。沿用定时器驱动新一轮动画，同一模式的游戏数据更新继续当前转场。

## 验证

- 原生窗口与真实时钟实测，限时轨道首张采样不透明度为 0，0.510 秒到达半透明。叠合中换到限步后，首张采样不透明度同样为 0，0.569 秒到达半透明。采样验证输出像素随帧逐步显现。
- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全量测试，108 项全部通过。查看原生渲染动图前段，核对透明度较浅时的轮廓和文字。
- 运行 `./run.sh` 后，先由自由切到限时，再在叠合结束前切到限步，观察两次淡入。

## 本轮完整增量 diff

以会话-124 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 5220cd78f141322c813e95d30cc82ef0b3c2abf4..bd1af323d25a9cfa55ed077c06fc5e3e9a89b21a 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128084215-make-statistics-fade-visible.md` - 会话-124 起改为匀速淡入，每次换模式从透明起步，含真实窗口轨道像素实测。
 `workflow/20261127231423-match-statistics-plate-heights.md` - 会话-120 起将统计背板高度与前板总数和分类的合计高度对齐。
 `workflow/20261127225349-complete-statistics-backing-outline.md` - 会话-117 起补齐统计背板右斜边和底边，底边向左下角渐隐。
 `workflow/20261127222703-stabilize-statistics-assembly-timing.md` - 会话-112 起从首个动画周期计时，延长统计卡叠合，含原生按钮实时测量。
@@ -118,6 +119,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡淡入的可见节奏或验证快速换模式也从透明开始时，读取 `20261128084215-make-statistics-fade-visible.md`。
 - 需要调整统计背板与前板的等高关系或检查分层时的底边位置，读取 `20261127231423-match-statistics-plate-heights.md`。
 - 需要调整统计背板右斜边、底边左下角渐隐或检查分层动画中的边框时，读取 `20261127225349-complete-statistics-backing-outline.md`。
 - 需要调整统计卡叠合时长、首播计时或复测冷启动与连续模式切换时，读取 `20261127222703-stabilize-statistics-assembly-timing.md`。
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 0e7404eaef67bccbae6de4bea238441c4444647e..8f944e799bf1f798e1754b4d3ad3f7e6e81a804b 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -58,10 +58,11 @@ final class HomeModeHeaderView: NSView {
             settle()
             return
         }
-        // 连续换模式时直接更新内容，已经在叠合的两层沿当前进度到位。
+        // 每次换模式都从透明起步。已运行的定时器继续驱动新一轮叠合。
+        transitionStart = nil
+        card.plateAssembly = .separated
         guard timer == nil else { return }
         card.positionPlates(in: cardColumn, assembling: true)
-        card.plateAssembly = .separated
 
         let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
         RunLoop.main.add(timer, forMode: .common)
@@ -88,11 +89,11 @@ final class HomeModeHeaderView: NSView {
         let time = CGFloat(elapsed / Self.previewDuration)
         let backingRemaining = 1 - min(1, time / 0.62)
         let frontTime = min(1, max(0, (time - 0.12) / 0.66))
-        let fadeTime = min(1, time / 0.78)
+        let opacity = min(1, time / 0.78)
         let highlight = max(0, (time - 0.78) / 0.22)
         card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining,
                                    front: frontTime * frontTime * (3 - 2 * frontTime),
-                                   opacity: fadeTime * (2 - fadeTime),
+                                   opacity: opacity,
                                    highlight: highlight)
     }
 
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index b3245f6c16695c087d6b5624766188430bc5bb1e..28a644ff59e1210c5132551a08610b25ed6c4ae8 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -456,12 +456,13 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             case 2:
                 XCTAssertGreaterThan(assembly.backing, 0)
                 XCTAssertEqual(assembly.front, 0, accuracy: 0.001, "前板延后启动")
-            case 4:
+            case 6:
                 XCTAssertLessThan(preview.backingPlateOffset.y, -1)
                 XCTAssertGreaterThan(preview.frontPlateOffset.y, 1)
+                XCTAssertEqual(assembly.opacity, 0.31, accuracy: 0.02, "前段保留较浅的透明度")
                 try assertAssemblingPlatesAreVisible(home, preview: preview)
-            case 6:
-                XCTAssertEqual(assembly.opacity, 0.52, accuracy: 0.03, "叠合前段经过半透明状态")
+            case 10:
+                XCTAssertEqual(assembly.opacity, 0.51, accuracy: 0.02, "叠合经过半透明状态")
             case 12:
                 XCTAssertGreaterThan(assembly.front, 0)
                 XCTAssertLessThan(assembly.front, 1)
@@ -506,12 +507,18 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertLessThan(assemblyDuringEntry.front, 1)
         home.refresh(snapshot: timed, mode: .timed, manager: manager)
         XCTAssertEqual(preview.mode, .timed)
-        XCTAssertEqual(preview.plateAssembly, assemblyDuringEntry, "快速切回保留两层的当前进度")
+        XCTAssertEqual(preview.plateAssembly, .separated, "快速切回也从透明起步")
         home.refresh(snapshot: moves, mode: .moves, manager: manager)
+        XCTAssertEqual(preview.plateAssembly, .separated)
+        header.advanceAnimation()
+        clock += duration * 0.32
+        header.advanceAnimation()
+        let restartedAssembly = preview.plateAssembly
+        XCTAssertEqual(restartedAssembly.opacity, assemblyDuringEntry.opacity, accuracy: 0.001)
         window.setContentSize(NSSize(width: 960, height: 720))
         home.layoutSubtreeIfNeeded()
         XCTAssertEqual(home.bounds.width, 960, accuracy: 0.1)
-        XCTAssertEqual(preview.plateAssembly, assemblyDuringEntry)
+        XCTAssertEqual(preview.plateAssembly, restartedAssembly)
         assertStatisticsPlatesLeftOfModes(home, preview: preview)
         clock += duration * 0.08
         header.advanceAnimation()
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index c6af56d5b8d16089a24683a501c454d56b3ae1ee..e3c0f579ba552bc56651077a836b8b67318c0f39 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -118,25 +118,29 @@ final class HomeDashboardTests: AchievementTestCase {
         XCTAssertEqual(home.challengeHUD.budgetText, "01:00", "等待开局期间保持完整时间限制")
     }
 
-    func testModeButtonsGiveStatisticsAssemblyItsFullVisibleDuration() throws {
+    private func openStatisticsTestWindow() throws -> (window: NSWindow, home: HomeDashboardView) {
         _ = NSApplication.shared
         let controller = GameViewController(achievements: manager, records: ModeRecordStore(defaults: defaults),
                                             board: board(now: { Date() }), audioEnabled: false)
+        let home = try XCTUnwrap(controller.view as? HomeDashboardView)
         let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled],
                               backing: .buffered, defer: false)
         window.isReleasedWhenClosed = false
         window.contentViewController = controller
         window.orderFront(nil)
-        defer { window.close() }
-
-        let home = try XCTUnwrap(controller.view as? HomeDashboardView)
-        let hud = home.challengeHUD
         home.modeHeader.reducesMotion = { false }
         home.layoutSubtreeIfNeeded()
         window.displayIfNeeded()
         CATransaction.flush()
         // 先呈现初始大厅，再按模式按钮，避免把窗口首次显示的工作算进转场。
         RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
+        return (window, home)
+    }
+
+    func testModeButtonsGiveStatisticsAssemblyItsFullVisibleDuration() throws {
+        let (window, home) = try openStatisticsTestWindow()
+        defer { window.close() }
+        let hud = home.challengeHUD
 
         let onMode = try XCTUnwrap(home.onMode)
         home.onMode = { mode in
@@ -192,6 +196,79 @@ final class HomeDashboardTests: AchievementTestCase {
         }
     }
 
+    func testStatisticsBudgetPixelsFadeInAgainWhenModeChangesDuringAssembly() throws {
+        let (window, home) = try openStatisticsTestWindow()
+        defer { window.close() }
+        let hud = home.challengeHUD
+        let buttons = home.modePanel.subviews.compactMap { $0 as? HomeModeButton }
+        let timed = try XCTUnwrap(buttons.first { $0.mode == .timed })
+        let moves = try XCTUnwrap(buttons.first { $0.mode == .moves })
+        let duration = HomeModeHeaderView.previewDuration
+        let animationClock = home.modeHeader.now
+        var firstTick: TimeInterval?
+        var latestTick: TimeInterval?
+        home.modeHeader.now = {
+            let timestamp = animationClock()
+            if firstTick == nil { firstTick = timestamp }
+            latestTick = timestamp
+            return timestamp
+        }
+
+        func budgetOpacity() throws -> CGFloat {
+            let track = try XCTUnwrap(hud.budgetTrackRect)
+            let center = NSPoint(x: track.midX + hud.backingPlateOffset.x, y: track.midY + hud.backingPlateOffset.y)
+            // 在轨道中线取一小段，限步轨道至少会命中一个实心分格。
+            let rect = NSRect(x: center.x - 9, y: center.y - 2, width: 18, height: 4)
+            let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: rect))
+            hud.cacheDisplay(in: rect, to: bitmap)
+            let row = bitmap.pixelsHigh / 2
+            return (0..<bitmap.pixelsWide).compactMap { bitmap.colorAt(x: $0, y: row)?.alphaComponent }.max() ?? 0
+        }
+
+        func samplesThroughHalfOpacity() throws -> [(elapsed: TimeInterval, opacity: CGFloat)] {
+            let deadline = ProcessInfo.processInfo.systemUptime + duration + 1
+            var lastSampledTick: TimeInterval?
+            var samples: [(elapsed: TimeInterval, opacity: CGFloat)] = []
+            while ProcessInfo.processInfo.systemUptime < deadline {
+                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
+                guard let firstTick, let latestTick, latestTick != lastSampledTick else { continue }
+                lastSampledTick = latestTick
+                let opacity = try budgetOpacity()
+                samples.append((latestTick - firstTick, opacity))
+                if opacity >= 0.50 { break }
+            }
+            return samples
+        }
+
+        timed.performClick(nil)
+        XCTAssertTrue(timed.selected)
+        XCTAssertEqual(hud.mode, .timed)
+        let initial = try budgetOpacity()
+        let samples = try samplesThroughHalfOpacity()
+        let early = try XCTUnwrap(samples.first { $0.opacity >= 0.10 })
+        let halfway = try XCTUnwrap(samples.first { $0.opacity >= 0.50 })
+        print(String(format: "限时统计轨道实测，初始 %.2f，首段 %.2f，至半透明 %.3f 秒，取样 %d 帧",
+                     Double(initial), Double(early.opacity), halfway.elapsed, samples.count))
+        XCTAssertLessThan(initial, 0.10, "首次切换从接近透明开始")
+        XCTAssertLessThan(early.opacity + 0.15, halfway.opacity, "首段经过不同程度的半透明")
+        for (previous, current) in zip(samples, samples.dropFirst()) {
+            XCTAssertGreaterThanOrEqual(current.opacity + 0.03, previous.opacity, "可见像素逐步显现")
+        }
+        XCTAssertGreaterThanOrEqual(halfway.elapsed, duration * 0.30, "前段淡入为半透明状态保留足够时间")
+
+        XCTAssertNotEqual(hud.plateAssembly, .settled, "在上一次动画完成前点击下一个模式")
+        firstTick = nil
+        latestTick = nil
+        moves.performClick(nil)
+        XCTAssertTrue(moves.selected)
+        XCTAssertEqual(hud.mode, .moves)
+        let restarted = try budgetOpacity()
+        let movesSamples = try samplesThroughHalfOpacity()
+        let movesHalfway = try XCTUnwrap(movesSamples.first { $0.opacity >= 0.50 })
+        print(String(format: "限步统计轨道实测，中途切换后初始 %.2f，至半透明 %.3f 秒", Double(restarted), movesHalfway.elapsed))
+        XCTAssertLessThan(restarted, 0.12, "中途切换时新轨道从接近透明重新淡入")
+    }
+
     func testAchievementRowSpansBothColumnsAndStartAlignsWithContact() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
```
