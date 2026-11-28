# 统一统计卡两层高度

## 背景与目标

- 会话-120 要求后方背板与前方统计板等高。前板高度以本局消除区的上沿至四个分类格的底边为准。

## 实施

- 背板共用前板的分类底边坐标计算自身高度。背板上沿按原位置布局，底边上移到与前板等高所需的位置。
- 右斜边与渐隐底边由背板的新几何生成。叠合过程在同一坐标系绘制两层。

## 验证

- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全量测试，107 项全部通过。
- 用原生像素检查背板底边位于前板对应高度，并确认新底边下方透明。核对原生动画的分层状态、斜边间距和预算轨道。
- 运行 `./run.sh` 后切换游戏模式，可在叠合前段查看两张等高卡片。

## 本轮完整增量 diff

以会话-120 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index f535b4ed99361486638736b7268dfae56073e6c6..5220cd78f141322c813e95d30cc82ef0b3c2abf4 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127231423-match-statistics-plate-heights.md` - 会话-120 起将统计背板高度与前板总数和分类的合计高度对齐。
 `workflow/20261127225349-complete-statistics-backing-outline.md` - 会话-117 起补齐统计背板右斜边和底边，底边向左下角渐隐。
 `workflow/20261127222703-stabilize-statistics-assembly-timing.md` - 会话-112 起从首个动画周期计时，延长统计卡叠合，含原生按钮实时测量。
 `workflow/20261127221016-fade-in-statistics-plate-assembly.md` - 会话-110 起让统计卡叠合时从全透明经过半透明，合拢后到达原有亮度。
@@ -117,6 +118,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计背板与前板的等高关系或检查分层时的底边位置，读取 `20261127231423-match-statistics-plate-heights.md`。
 - 需要调整统计背板右斜边、底边左下角渐隐或检查分层动画中的边框时，读取 `20261127225349-complete-statistics-backing-outline.md`。
 - 需要调整统计卡叠合时长、首播计时或复测冷启动与连续模式切换时，读取 `20261127222703-stabilize-statistics-assembly-timing.md`。
 - 需要调整统计卡叠合前段的透明度或核对淡入曲线时，读取 `20261127221016-fade-in-statistics-plate-assembly.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 7af424c899edca0d878960e16a395b71a97b8c9b..8d810ea7eac36c70e1c2b36a4592006efa31b058 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -65,7 +65,7 @@ final class HomeChallengeHUDView: NSView {
         bounds = NSRect(x: -left, y: -top, width: frame.width, height: frame.height)
     }
 
-    /// 设计稿坐标以底部分格左边缘为参考。背板与前板同宽，沿同一斜率错开。
+    /// 设计稿坐标以底部分格左边缘为参考。两层等宽等高，沿同一斜率错开。
     private struct Face {
         let frame: NSRect
         var typographyScale: CGFloat { min(frame.width / 636, frame.height / 186) }
@@ -75,9 +75,11 @@ final class HomeChallengeHUDView: NSView {
             let front = totals
             // 两层在同一高度的净宽相同，左右斜边就会露出相同的错位。
             let width = front.width - HomeDashboardStyle.edgeOffset(for: front.height)
-            return plate(from: left, to: NSPoint(x: left.x + width, y: point(455, 309).y))
+            let height = breakdownBottomY - front.minY
+            return plate(from: left, to: NSPoint(x: left.x + width, y: left.y + height))
         }
         var totals: NSRect { plate(from: point(472, 175), to: point(1033, 255)) }
+        private var breakdownBottomY: CGFloat { point(410, 308).y }
 
         var budgetTrack: NSRect {
             let plate = rules
@@ -94,7 +96,7 @@ final class HomeChallengeHUDView: NSView {
 
         var breakdownCellRects: [NSRect] {
             let total = totals
-            let height = point(410, 308).y - total.maxY
+            let height = breakdownBottomY - total.maxY
             let cut = HomeDashboardStyle.edgeOffset(for: height)
             let count = CGFloat(PieceKind.allCases.count)
             let available = total.width - HomeDashboardStyle.edgeOffset(for: total.height)
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 0d0dfee16c2fd8a703920ef4fc2450c4e9dc7732..b3245f6c16695c087d6b5624766188430bc5bb1e 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -117,9 +117,11 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
         let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
         let rest = hud.surfaceRect
-        let backing = rest.offsetBy(dx: hud.backingPlateOffset.x, dy: hud.backingPlateOffset.y)
-        let frontTop = rest.minY + rest.height * 52 / 186 + hud.frontPlateOffset.y
-        XCTAssertLessThan(backing.maxY + 2, frontTop)
+        let frontTop = rest.minY + rest.height * 52 / 186
+        let frontBottom = try XCTUnwrap(hud.breakdownCellRects.last).maxY
+        let backing = NSRect(x: rest.minX + hud.backingPlateOffset.x, y: rest.minY + hud.backingPlateOffset.y,
+                             width: rest.width, height: frontBottom - frontTop)
+        XCTAssertLessThan(backing.maxY + 2, frontTop + hud.frontPlateOffset.y)
 
         func alpha(x: CGFloat, y: CGFloat) throws -> CGFloat {
             let pixelX = Int(floor((x - bounds.minX) * scaleX))
@@ -139,8 +141,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let cut = HomeDashboardStyle.edgeOffset(for: backing.height)
         let leftBottomX = backing.minX + backing.width * 45 / 636 - cut
         let rightBottomX = rightTopX - cut
+        func bottomX(at fraction: CGFloat) -> CGFloat { leftBottomX + (rightBottomX - leftBottomX) * fraction }
         func bottomAlpha(at fraction: CGFloat) throws -> CGFloat {
-            let x = leftBottomX + (rightBottomX - leftBottomX) * fraction
+            let x = bottomX(at: fraction)
             return try [-1, 0, 1].map { try alpha(x: x, y: backing.maxY + CGFloat($0)) }.max() ?? 0
         }
 
@@ -150,6 +153,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertLessThan(faintLeft, 0.15, "底边靠近左下角时接近透明")
         XCTAssertGreaterThan(fade, faintLeft + 0.07, "底边左段亮度沿宽度渐变")
         XCTAssertGreaterThan(solid, fade + 0.07, "底边右段保持清晰")
+        XCTAssertLessThan(try alpha(x: bottomX(at: 0.68), y: backing.maxY + 2), 0.03,
+                          "背板在与前板等高的描边下方保持透明")
     }
 
     func testChallengeBudgetTrackReplacesOnlyTheTopBandContent() throws {
```
