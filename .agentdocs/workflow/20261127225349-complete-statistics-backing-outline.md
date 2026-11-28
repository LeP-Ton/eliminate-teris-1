# 补齐统计背板的右斜边和底边

## 背景与目标

- 会话-117 指出统计卡叠合时，背板右斜边在前板上沿的高度突然断开，需要连到底边并向左下角渐隐。

## 实施

- 使用同一条描边从右上沿斜边走到右下角，再转向左侧。右斜边和底边右段亮度连续，底边左侧约 45% 渐淡，左下端透明。
- 新描边按原有斜率随背板一起移动。两层重合时，由前板自然覆盖背板下方。

## 验证

- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全量测试，107 项全部通过。
- 在分离的背板中检查右斜边下段三个采样点，并沿底边比较三个不同位置的不透明度。原有斜边间距回归也通过。
- 查看原生动画帧，确认两层分开时右斜边延伸至前板遮盖处。可运行 `./run.sh`，切换游戏模式观察叠合前段。

## 本轮完整增量 diff

以会话-117 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 3ec0adb9d75f35bf7b3d4f449e8863de24c29431..f535b4ed99361486638736b7268dfae56073e6c6 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127225349-complete-statistics-backing-outline.md` - 会话-117 起补齐统计背板右斜边和底边，底边向左下角渐隐。
 `workflow/20261127222703-stabilize-statistics-assembly-timing.md` - 会话-112 起从首个动画周期计时，延长统计卡叠合，含原生按钮实时测量。
 `workflow/20261127221016-fade-in-statistics-plate-assembly.md` - 会话-110 起让统计卡叠合时从全透明经过半透明，合拢后到达原有亮度。
 `workflow/20261127215826-stack-statistics-card-plates.md` - 会话-107 起改用背板和前板交错叠合，再以接缝高光收尾，含逐帧和快速切换验证。
@@ -116,6 +117,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计背板右斜边、底边左下角渐隐或检查分层动画中的边框时，读取 `20261127225349-complete-statistics-backing-outline.md`。
 - 需要调整统计卡叠合时长、首播计时或复测冷启动与连续模式切换时，读取 `20261127222703-stabilize-statistics-assembly-timing.md`。
 - 需要调整统计卡叠合前段的透明度或核对淡入曲线时，读取 `20261127221016-fade-in-statistics-plate-assembly.md`。
 - 需要调整统计卡双层叠合、收尾高光或连续切换的动画节奏时，读取 `20261127215826-stack-statistics-card-plates.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index cb9b69908f913f53af6e1a17b4728051d29eb517..7af424c899edca0d878960e16a395b71a97b8c9b 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -315,13 +315,25 @@ final class HomeChallengeHUDView: NSView {
         let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
         let topLeft = NSPoint(x: plate.minX + cut, y: plate.minY)
         let topRight = NSPoint(x: plate.maxX, y: plate.minY)
-        let joinY = face.totals.minY
-        let joinX = plate.maxX - HomeDashboardStyle.edgeOffset(for: joinY - plate.minY)
+        let bottomRight = NSPoint(x: plate.maxX - cut, y: plate.maxY)
+        let bottomLeft = NSPoint(x: plate.minX, y: plate.maxY)
         HomeDashboardStyle.line(from: topLeft, to: topRight, color: rim.withAlphaComponent(0.80), width: 1.25)
-        HomeDashboardStyle.line(from: topRight, to: NSPoint(x: joinX, y: joinY), color: rim.withAlphaComponent(0.65), width: 1.25)
         let leftRim = HomeDashboardStyle.slant(NSRect(x: plate.minX - 0.625, y: plate.minY,
                                                       width: cut + 1.25, height: plate.height))
         NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
+
+        guard let context = NSGraphicsContext.current?.cgContext else { return }
+        // 右斜边和底边共用一条描边，右下角连续，底边左段逐渐融入背景。
+        context.saveGState()
+        context.beginPath()
+        context.addLines(between: [topRight, bottomRight, bottomLeft])
+        context.setLineWidth(1.25)
+        context.replacePathWithStrokedPath()
+        context.clip()
+        let fadeEnd = NSPoint(x: bottomLeft.x + (bottomRight.x - bottomLeft.x) * 0.45, y: bottomLeft.y)
+        NSGradient(starting: rim.withAlphaComponent(0), ending: rim.withAlphaComponent(0.65))?
+            .draw(from: bottomLeft, to: fadeEnd, options: .drawsAfterEndingLocation)
+        context.restoreGState()
     }
 
     private func drawTotals(_ totalCleared: Int, on face: Face, accent: NSColor) {
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index a414b64e28faf2ac895cd65a67d1c7268c737294..0d0dfee16c2fd8a703920ef4fc2450c4e9dc7732 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -103,6 +103,55 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         }
     }
 
+    func testStatisticsBackingRimContinuesDownRightSideAndFadesTowardLeft() throws {
+        _ = NSApplication.shared
+        let frame = NSRect(x: 0, y: 0, width: 336, height: 62)
+        let hud = HomeChallengeHUDView(frame: frame)
+        hud.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
+                                          remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free)
+        // 矮画布让错开后的背板底边高于前板，便于检查正常高度下会被盖住的描边。
+        hud.positionPlates(in: frame, assembling: true)
+        hud.plateAssembly = .init(backing: 0, front: 0, opacity: 1, highlight: 0)
+        let bitmap = try image(hud)
+        let bounds = hud.bounds
+        let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
+        let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
+        let rest = hud.surfaceRect
+        let backing = rest.offsetBy(dx: hud.backingPlateOffset.x, dy: hud.backingPlateOffset.y)
+        let frontTop = rest.minY + rest.height * 52 / 186 + hud.frontPlateOffset.y
+        XCTAssertLessThan(backing.maxY + 2, frontTop)
+
+        func alpha(x: CGFloat, y: CGFloat) throws -> CGFloat {
+            let pixelX = Int(floor((x - bounds.minX) * scaleX))
+            let pixelY = Int(floor((y - bounds.minY) * scaleY))
+            return try XCTUnwrap(bitmap.colorAt(x: pixelX, y: pixelY)).alphaComponent
+        }
+
+        let rightTopX = backing.minX + backing.width * 606 / 636
+        for fraction: CGFloat in [0.55, 0.72, 0.88] {
+            let y = backing.minY + backing.height * fraction
+            let rightX = rightTopX - HomeDashboardStyle.edgeOffset(for: y - backing.minY)
+            let peak = try [-1, 0, 1].map { try alpha(x: rightX + CGFloat($0), y: y) }.max() ?? 0
+            let nearby = try max(alpha(x: rightX - 3, y: y), alpha(x: rightX + 3, y: y))
+            XCTAssertGreaterThan(peak, nearby + 0.10, "背板右斜边延伸至下段，采样高度 \(fraction)")
+        }
+
+        let cut = HomeDashboardStyle.edgeOffset(for: backing.height)
+        let leftBottomX = backing.minX + backing.width * 45 / 636 - cut
+        let rightBottomX = rightTopX - cut
+        func bottomAlpha(at fraction: CGFloat) throws -> CGFloat {
+            let x = leftBottomX + (rightBottomX - leftBottomX) * fraction
+            return try [-1, 0, 1].map { try alpha(x: x, y: backing.maxY + CGFloat($0)) }.max() ?? 0
+        }
+
+        let faintLeft = try bottomAlpha(at: 0.05)
+        let fade = try bottomAlpha(at: 0.25)
+        let solid = try bottomAlpha(at: 0.68)
+        XCTAssertLessThan(faintLeft, 0.15, "底边靠近左下角时接近透明")
+        XCTAssertGreaterThan(fade, faintLeft + 0.07, "底边左段亮度沿宽度渐变")
+        XCTAssertGreaterThan(solid, fade + 0.07, "底边右段保持清晰")
+    }
+
     func testChallengeBudgetTrackReplacesOnlyTheTopBandContent() throws {
         _ = NSApplication.shared
         for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196)] {
```
