# 延长统计卡叠合并统一首播节奏

## 背景与目标

- 会话-112 反馈统计卡首播偏快，后续切换显得更慢，且动画整体太短。
- 旧代码在模式切换的同步回调中记录起点。首次进入某个模式可能还要现场准备背景音乐，因此主循环继续处理动画帧时，已经走过前段。

## 实施

- 在主循环驱动的首个动画帧记录起点，转场从 0.70 秒调整为 1.20 秒。
- 背板使用更平缓的缓出，避免动画刚出现便快速收拢。同模式刷新与快速切换继续当前转场。

## 验证

- 原生窗口测试用真正的模式按钮和系统单调时钟，依次切换限时、限步、自由。首轮在按钮动作内模拟 0.18 秒同步准备，另两轮按常规切换。
- 改动前，三轮从按钮动作返回到卡片到位分别为 0.587、0.760、0.771 秒。首轮触发可见时段过短的断言。
- 改动后，三轮从首个动画帧到合拢及高光结束分别为 1.210、1.243、1.226 秒。定向复测从按钮返回到完成为 1.218、1.294、1.297 秒。最终全量测试首轮在开播前额外等待 0.537 秒，说明按钮返回和动画实际播放需分别计时。
- 逐帧回归额外模拟首帧之前等待 0.35 秒，确认初始透明状态与叠合进度仍从零开始。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 全部 106 项通过。手动复核可运行 `./run.sh`，等待窗口显示后依次切换模式，查看双层叠合和接缝高光。

## 本轮完整增量 diff

以会话-112 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index bd0311091eef1ae097e60a76d4bec77eb45a8796..3ec0adb9d75f35bf7b3d4f449e8863de24c29431 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127222703-stabilize-statistics-assembly-timing.md` - 会话-112 起从首个动画周期计时，延长统计卡叠合，含原生按钮实时测量。
 `workflow/20261127221016-fade-in-statistics-plate-assembly.md` - 会话-110 起让统计卡叠合时从全透明经过半透明，合拢后到达原有亮度。
 `workflow/20261127215826-stack-statistics-card-plates.md` - 会话-107 起改用背板和前板交错叠合，再以接缝高光收尾，含逐帧和快速切换验证。
 `workflow/20261127213541-clear-statistics-card-entry.md` - 会话-104 起把统计卡的起点移出右栏，前段更快淡入，含双层像素、连续切换和缩窗回归。
@@ -115,6 +116,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡叠合时长、首播计时或复测冷启动与连续模式切换时，读取 `20261127222703-stabilize-statistics-assembly-timing.md`。
 - 需要调整统计卡叠合前段的透明度或核对淡入曲线时，读取 `20261127221016-fade-in-statistics-plate-assembly.md`。
 - 需要调整统计卡双层叠合、收尾高光或连续切换的动画节奏时，读取 `20261127215826-stack-statistics-card-plates.md`。
 - 需要调整统计卡滑入起点、入场可见性或切换过程中缩窗时，读取 `20261127213541-clear-statistics-card-entry.md`。
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index d944be47a4c0bd4fb5923f88f77afe65eae1035c..0e7404eaef67bccbae6de4bea238441c4444647e 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -2,7 +2,7 @@ import Cocoa
 
 /// 上方文案和本局统计并排排版，切换模式时交错叠合统计卡的前后两层。
 final class HomeModeHeaderView: NSView {
-    static let previewDuration: TimeInterval = 0.70
+    static let previewDuration: TimeInterval = 1.20
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
@@ -59,8 +59,7 @@ final class HomeModeHeaderView: NSView {
             return
         }
         // 连续换模式时直接更新内容，已经在叠合的两层沿当前进度到位。
-        guard transitionStart == nil else { return }
-        transitionStart = now()
+        guard timer == nil else { return }
         card.positionPlates(in: cardColumn, assembling: true)
         card.plateAssembly = .separated
 
@@ -70,9 +69,19 @@ final class HomeModeHeaderView: NSView {
     }
 
     func advanceAnimation() {
-        guard let transitionStart else { return }
-        let elapsed = max(0, now() - transitionStart)
-        guard elapsed < Self.previewDuration, !reducesMotion() else {
+        guard timer != nil else { return }
+        guard !reducesMotion() else {
+            settle()
+            return
+        }
+        let currentTime = now()
+        // 首次切换可能还在同步准备模式资源。等主循环驱动首帧再计时。
+        guard let transitionStart else {
+            self.transitionStart = currentTime
+            return
+        }
+        let elapsed = max(0, currentTime - transitionStart)
+        guard elapsed < Self.previewDuration else {
             settle()
             return
         }
@@ -81,7 +90,7 @@ final class HomeModeHeaderView: NSView {
         let frontTime = min(1, max(0, (time - 0.12) / 0.66))
         let fadeTime = min(1, time / 0.78)
         let highlight = max(0, (time - 0.78) / 0.22)
-        card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining * backingRemaining,
+        card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining,
                                    front: frontTime * frontTime * (3 - 2 * frontTime),
                                    opacity: fadeTime * (2 - fadeTime),
                                    highlight: highlight)
@@ -94,7 +103,7 @@ final class HomeModeHeaderView: NSView {
 
     override func layout() {
         super.layout()
-        card.positionPlates(in: cardColumn, assembling: transitionStart != nil)
+        card.positionPlates(in: cardColumn, assembling: timer != nil)
     }
 
     private func settle() {
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index e6f92d0e8adf248b5f2aad8e05cb7e44b2f25199..a414b64e28faf2ac895cd65a67d1c7268c737294 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -376,10 +376,15 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
         CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
         let duration = HomeModeHeaderView.previewDuration
-        XCTAssertEqual(duration, 0.70, accuracy: 0.001)
+        XCTAssertEqual(duration, 1.20, accuracy: 0.001)
+        clock += 0.35
+        header.advanceAnimation()
+        XCTAssertEqual(preview.plateAssembly, .separated, "首帧前的等待不应消耗可见动画时间")
+        let firstFrameTime = clock
         var previous = preview.plateAssembly
         for step in 0...steps {
-            clock = 100 + duration * Double(step) / Double(steps)
+            clock = firstFrameTime + duration * Double(step) / Double(steps)
+            if step == steps { clock += 0.001 }
             header.advanceAnimation()
             home.layoutSubtreeIfNeeded()
             let assembly = preview.plateAssembly
@@ -439,6 +444,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(preview.mode, .moves)
         XCTAssertEqual(preview.budgetText, "30")
         XCTAssertEqual(preview.plateAssembly, .separated)
+        header.advanceAnimation()
         clock += duration * 0.32
         header.advanceAnimation()
         let assemblyDuringEntry = preview.plateAssembly
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index f38c357ee8e6ded013b7d8df09ab28bcef5f38bc..c6af56d5b8d16089a24683a501c454d56b3ae1ee 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -1,4 +1,5 @@
 import Cocoa
+import QuartzCore
 import XCTest
 @testable import EliminateTeris1
 
@@ -117,6 +118,80 @@ final class HomeDashboardTests: AchievementTestCase {
         XCTAssertEqual(home.challengeHUD.budgetText, "01:00", "等待开局期间保持完整时间限制")
     }
 
+    func testModeButtonsGiveStatisticsAssemblyItsFullVisibleDuration() throws {
+        _ = NSApplication.shared
+        let controller = GameViewController(achievements: manager, records: ModeRecordStore(defaults: defaults),
+                                            board: board(now: { Date() }), audioEnabled: false)
+        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800), styleMask: [.titled],
+                              backing: .buffered, defer: false)
+        window.isReleasedWhenClosed = false
+        window.contentViewController = controller
+        window.orderFront(nil)
+        defer { window.close() }
+
+        let home = try XCTUnwrap(controller.view as? HomeDashboardView)
+        let hud = home.challengeHUD
+        home.modeHeader.reducesMotion = { false }
+        home.layoutSubtreeIfNeeded()
+        window.displayIfNeeded()
+        CATransaction.flush()
+        // 先呈现初始大厅，再按模式按钮，避免把窗口首次显示的工作算进转场。
+        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
+
+        let onMode = try XCTUnwrap(home.onMode)
+        home.onMode = { mode in
+            onMode(mode)
+            // 模拟首次切换仍在同步处理启动工作，窗口要等按钮动作返回才可继续绘制。
+            if mode == .timed { Thread.sleep(forTimeInterval: 0.18) }
+        }
+
+        let duration = HomeModeHeaderView.previewDuration
+        let animationClock = home.modeHeader.now
+        var animationTicks: [TimeInterval] = []
+        home.modeHeader.now = {
+            let timestamp = animationClock()
+            animationTicks.append(timestamp)
+            return timestamp
+        }
+        func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
+        for mode in [HomeGameMode.timed, .moves, .free] {
+            let button = try XCTUnwrap(home.modePanel.subviews.compactMap { $0 as? HomeModeButton }.first { $0.mode == mode })
+            animationTicks.removeAll(keepingCapacity: true)
+            button.performClick(nil)
+            let returnedAt = uptime()
+            XCTAssertTrue(button.selected)
+            XCTAssertEqual(hud.mode, mode)
+
+            var sawProgress = false
+            var halfwayOpacity: CGFloat?
+            var settledAt: TimeInterval?
+            // 让窗口自然绘制，采样过程不插入同步重绘。
+            repeat {
+                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.008))
+                let sampledAt = uptime()
+                let assembly = hud.plateAssembly
+                if assembly != .settled {
+                    sawProgress = true
+                    if halfwayOpacity == nil && (0.30...0.75).contains(assembly.opacity) {
+                        halfwayOpacity = assembly.opacity
+                    }
+                } else if sawProgress {
+                    settledAt = sampledAt
+                }
+            } while settledAt == nil && uptime() < returnedAt + duration + 1
+
+            let settled = try XCTUnwrap(settledAt, "模式 \(mode.key) 的统计卡应完成可见动画")
+            let elapsed = settled - returnedAt
+            let opacity = try XCTUnwrap(halfwayOpacity, "模式 \(mode.key) 的统计卡应绘制半透明帧")
+            let firstTick = try XCTUnwrap(animationTicks.first)
+            let lastTick = try XCTUnwrap(animationTicks.last)
+            print(String(format: "统计卡模式切换 %@，按钮返回后 %.3f 秒到位，首个动画帧至完成 %.3f 秒，半透明帧不透明度 %.2f",
+                         mode.key, elapsed, lastTick - firstTick, Double(opacity)))
+            XCTAssertGreaterThanOrEqual(elapsed, duration - 0.04, "按钮动作中的同步工作不应缩短可见动画")
+            XCTAssertGreaterThanOrEqual(lastTick - firstTick, duration, "两层卡片应该走完整个动画时段")
+        }
+    }
+
     func testAchievementRowSpansBothColumnsAndStartAlignsWithContact() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
```
