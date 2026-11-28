# 统计卡叠合前段渐入

## 背景与目标

- 会话-110 要求统计卡叠合前段从透明过渡到半透明。

## 实施

- 两层从全透明起步，约 0.16 秒到达半透明，合拢时达到完整亮度。
- 按合成后的卡片整体淡入，两层重叠处采用同一透明度。接缝高光在卡片完全显现后出现。

## 验证

- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，105 项全部通过。
- 在逐帧测试中检查全透明首帧、前段半透明、逐帧淡入的方向及高光期间完整亮度；核对导出的原生动画帧。
- 可运行 `./run.sh`，在大厅切换自由、限时和限步模式查看淡入过程。

## 本轮完整增量 diff

以会话-110 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index f379067ad3174a8926865ffe9cafe07f3a51f4de..bd0311091eef1ae097e60a76d4bec77eb45a8796 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127221016-fade-in-statistics-plate-assembly.md` - 会话-110 起让统计卡叠合时从全透明经过半透明，合拢后到达原有亮度。
 `workflow/20261127215826-stack-statistics-card-plates.md` - 会话-107 起改用背板和前板交错叠合，再以接缝高光收尾，含逐帧和快速切换验证。
 `workflow/20261127213541-clear-statistics-card-entry.md` - 会话-104 起把统计卡的起点移出右栏，前段更快淡入，含双层像素、连续切换和缩窗回归。
 `workflow/20261127210415-remove-lobby-division-and-logo-accent.md` - 会话-100 起移除首页分隔左右栏的斜线和标志下方的高亮线。
@@ -114,6 +115,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡叠合前段的透明度或核对淡入曲线时，读取 `20261127221016-fade-in-statistics-plate-assembly.md`。
 - 需要调整统计卡双层叠合、收尾高光或连续切换的动画节奏时，读取 `20261127215826-stack-statistics-card-plates.md`。
 - 需要调整统计卡滑入起点、入场可见性或切换过程中缩窗时，读取 `20261127213541-clear-statistics-card-entry.md`。
 - 需要核对首页左右栏分隔线或标志下方高亮时，读取 `20261127210415-remove-lobby-division-and-logo-accent.md`。
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 1cbf3e35d2f4d42d494c3835d72a44d4f74b2936..d944be47a4c0bd4fb5923f88f77afe65eae1035c 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -79,9 +79,11 @@ final class HomeModeHeaderView: NSView {
         let time = CGFloat(elapsed / Self.previewDuration)
         let backingRemaining = 1 - min(1, time / 0.62)
         let frontTime = min(1, max(0, (time - 0.12) / 0.66))
+        let fadeTime = min(1, time / 0.78)
         let highlight = max(0, (time - 0.78) / 0.22)
         card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining * backingRemaining,
                                    front: frontTime * frontTime * (3 - 2 * frontTime),
+                                   opacity: fadeTime * (2 - fadeTime),
                                    highlight: highlight)
     }
 
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 4c3f664c6ae4e1241f8be7f6c1298bad3702d972..cb9b69908f913f53af6e1a17b4728051d29eb517 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -16,10 +16,11 @@ final class HomeChallengeHUDView: NSView {
     struct PlateAssembly: Equatable {
         let backing: CGFloat
         let front: CGFloat
+        let opacity: CGFloat
         let highlight: CGFloat
 
-        static let separated = PlateAssembly(backing: 0, front: 0, highlight: 0)
-        static let settled = PlateAssembly(backing: 1, front: 1, highlight: 0)
+        static let separated = PlateAssembly(backing: 0, front: 0, opacity: 0, highlight: 0)
+        static let settled = PlateAssembly(backing: 1, front: 1, opacity: 1, highlight: 0)
     }
 
     private var plateSize: NSSize?
@@ -271,19 +272,16 @@ final class HomeChallengeHUDView: NSView {
 
     override func draw(_ dirtyRect: NSRect) {
         let surface = surfaceRect
-        guard let snapshot, surface.width > 40, surface.height > 45 else { return }
+        guard let snapshot, surface.width > 40, surface.height > 45, plateAssembly.opacity > 0 else { return }
         let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
         let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
         let backing = backingPlateOffset
         let backFace = Face(frame: surface.offsetBy(dx: backing.x, dy: backing.y))
-        drawPlate(opacity: 0.46 + 0.54 * plateAssembly.backing) {
-            drawBackingPlate(on: backFace)
-            if showsBudget { drawTrack(backFace.budgetTrack, accent: accent, snapshot: snapshot) }
-        }
-
         let front = frontPlateOffset
         let frontFace = Face(frame: surface.offsetBy(dx: front.x, dy: front.y))
-        drawPlate(opacity: 0.62 + 0.38 * plateAssembly.front) {
+        drawPlates(opacity: plateAssembly.opacity) {
+            drawBackingPlate(on: backFace)
+            if showsBudget { drawTrack(backFace.budgetTrack, accent: accent, snapshot: snapshot) }
             fill(HomeDashboardStyle.slant(frontFace.totals),
                  colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                           HomeDashboardStyle.color(0x101A25)], angle: 14, border: HomeDashboardStyle.color(0x57636B))
@@ -294,12 +292,12 @@ final class HomeChallengeHUDView: NSView {
         drawJoinHighlight(on: frontFace.totals, accent: accent)
     }
 
-    private func drawPlate(opacity: CGFloat, _ draw: () -> Void) {
+    private func drawPlates(opacity: CGFloat, _ draw: () -> Void) {
         guard opacity < 1, let context = NSGraphicsContext.current?.cgContext else {
             draw()
             return
         }
-        // 按整层合成透明度，牌面中的渐变、文字和方块保持原有叠放。
+        // 先合成两层再淡入，让重叠的部分也沿用同一透明度。
         context.saveGState()
         context.setAlpha(opacity)
         context.beginTransparencyLayer(auxiliaryInfo: nil)
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 996aa7a94b3eb362a1cddfa833a35bfbcec8888e..e6f92d0e8adf248b5f2aad8e05cb7e44b2f25199 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -385,12 +385,15 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             let assembly = preview.plateAssembly
             XCTAssertGreaterThanOrEqual(assembly.backing, previous.backing)
             XCTAssertGreaterThanOrEqual(assembly.front, previous.front)
+            XCTAssertGreaterThanOrEqual(assembly.opacity, previous.opacity, "两层叠合时整体逐帧淡入")
             previous = assembly
             XCTAssertEqual(preview.convert(preview.surfaceRect, to: home), restingSurface, "两层移动时保留牌面的基准位置和尺寸")
             XCTAssertEqual(intro.frame, introFrame, "模式切换保留标题位置")
             assertStatisticsPlatesLeftOfModes(home, preview: preview)
 
             switch step {
+            case 0:
+                XCTAssertEqual(assembly.opacity, 0, accuracy: 0.001, "入场首帧完全透明")
             case 2:
                 XCTAssertGreaterThan(assembly.backing, 0)
                 XCTAssertEqual(assembly.front, 0, accuracy: 0.001, "前板延后启动")
@@ -398,6 +401,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                 XCTAssertLessThan(preview.backingPlateOffset.y, -1)
                 XCTAssertGreaterThan(preview.frontPlateOffset.y, 1)
                 try assertAssemblingPlatesAreVisible(home, preview: preview)
+            case 6:
+                XCTAssertEqual(assembly.opacity, 0.52, accuracy: 0.03, "叠合前段经过半透明状态")
             case 12:
                 XCTAssertGreaterThan(assembly.front, 0)
                 XCTAssertLessThan(assembly.front, 1)
@@ -412,6 +417,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             case 22:
                 XCTAssertEqual(assembly.front, 1, accuracy: 0.001)
                 XCTAssertEqual(preview.frontPlateOffset, .zero)
+                XCTAssertEqual(assembly.opacity, 1, accuracy: 0.001, "接缝高光出现时牌面已完全显现")
                 XCTAssertGreaterThan(assembly.highlight, 0, "两层合拢后才播放高光")
                 XCTAssertLessThan(assembly.highlight, 1)
             default:
```
