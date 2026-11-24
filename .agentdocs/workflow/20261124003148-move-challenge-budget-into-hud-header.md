# 将挑战预算进度条移至统计卡顶部

## 背景与目标

- 用户要求隐藏自由模式统计卡顶部的双斜标与规则文案。限时和限步用此区域展示进度条，并让进度条两端到左右斜边的距离相同。
- 进度仍根据本局快照展示剩余秒数或剩余交换次数。

## 完成情况

- [x] 自由模式的顶部保留背板，移除双斜标和规则文案。
- [x] 限时和限步共用顶部轨道布局。进度条从进度区域的原左端起画，按同一斜率计算两端留白。
- [x] 限时使用连续进度，限步使用 30 个分格。统计本体保留预算数字、总数与分类消除数。

## 测试方法

- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。检查自由模式顶部、两种挑战轨道的实际像素、左右距离与完整、部分、耗尽预算状态。91 项测试全部通过，另核对了三种模式的原生预览。
- 手动运行 `./run.sh` 并切换三种模式。查看自由模式统计卡顶部，再开始挑战，观察顶部进度是否随预算减少。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 8cf91f24b96c0438aefd69079055b295d012366f..4b60e8a0cf604c0b3649fd7d49ef8ec412cdecac 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124003148-move-challenge-budget-into-hud-header.md` - 会话-22 起移除统计卡顶部规则文案，自由模式留空，限时和限步把进度条移至顶部并沿斜边等距。
 `workflow/20261123231057-split-popup-lists-into-row-cards.md` - 会话-16 至会话-18 将挑战记录、旧规则记录和玩法教学按条目拆为独立斜边卡，记录表头和数据保持列对齐。
 `workflow/20261123215822-restore-popup-parallelogram-borders.md` - 会话-12 至会话-15 恢复辅助弹窗卡片的整条斜边，逐行给文案和表格留白。含宽窄原生渲染与本轮增量 diff。
 `workflow/20261123092817-unify-lobby-and-panel-slants.md` - 会话-9 至会话-11 统一大厅和弹窗的斜边与文字，修正等宽统计格、斜切进度填充和滑块动画。含实际预览、回归与本轮增量 diff。
@@ -102,6 +103,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡顶部的预算轨道、左右等距留白、自由模式标题区域或限时限步预算显示时，读取 `20261124003148-move-challenge-budget-into-hud-header.md`。
 - 需要调整弹窗逐行卡片、记录表头与列宽、历史记录分组或教学卡片间距时，读取 `20261123231057-split-popup-lists-into-row-cards.md`。
 - 需要调整玩法、设置、挑战记录或成就弹窗的完整平行四边形和内部行布局时，读取 `20261123215822-restore-popup-parallelogram-borders.md`。
 - 需要调整统一斜角、轻斜文字、成就进度的部分填充、等宽消除分格或弹窗分段滑块时，读取 `20261123092817-unify-lobby-and-panel-slants.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 1da67d3d5adcc67bd7962f72b2d4a3d22164588f..b4f0f486b189a0c188551d3ec70e0b3535cf72fe 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -21,6 +21,7 @@ final class HomeChallengeHUDView: NSView {
     }
 
     var breakdownCellRects: [NSRect] { Face(frame: surfaceRect).breakdownCellRects }
+    var budgetTrackRect: NSRect? { showsBudget ? Face(frame: surfaceRect).budgetTrack : nil }
 
     /// 设计稿坐标以底部分格左边缘为参考。背板可以越过这个边缘，在前层左侧露出。
     private struct Face {
@@ -30,6 +31,19 @@ final class HomeChallengeHUDView: NSView {
         var rules: NSRect { plate(from: point(455, 123), to: point(1046, 309)) }
         var totals: NSRect { plate(from: point(472, 175), to: point(1033, 255)) }
 
+        var budgetTrack: NSRect {
+            let plate = rules
+            let headerHeight = totals.minY - plate.minY
+            let height = headerHeight * 0.22
+            let y = plate.minY + (headerHeight - height) / 2
+            // 左端沿用原标记的起点，右端按同一斜率和留白镜像定位。
+            let left = plate.minX + HomeDashboardStyle.edgeOffset(for: plate.maxY - y - height)
+            let right = plate.maxX - HomeDashboardStyle.edgeOffset(for: y - plate.minY)
+            let start = point(482, 123).x
+            let inset = start - left
+            return NSRect(x: start, y: y, width: max(0, right - inset - start), height: height)
+        }
+
         var breakdownCellRects: [NSRect] {
             let total = totals
             let height = point(410, 308).y - total.maxY
@@ -95,7 +109,7 @@ final class HomeChallengeHUDView: NSView {
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
         self.snapshot = snapshot; self.mode = mode
-        var labels = [modeCaption]
+        var labels: [String] = []
         if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
         labels.append(AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
         labels += PieceKind.allCases.map { kind in
@@ -106,12 +120,6 @@ final class HomeChallengeHUDView: NSView {
         needsDisplay = true
     }
 
-    private var modeCaption: String {
-        let title = AchievementText.string("home.mode.\(mode.key)")
-        let description = AchievementText.string("home.mode_desc.\(mode.key)")
-        return title + " · " + description.trimmingCharacters(in: CharacterSet(charactersIn: "。."))
-    }
-
     override func draw(_ dirtyRect: NSRect) {
         let surface = surfaceRect
         guard let snapshot, surface.width > 40, surface.height > 45 else { return }
@@ -130,7 +138,8 @@ final class HomeChallengeHUDView: NSView {
             NSGraphicsContext.restoreGraphicsState()
         }
 
-        drawRules(on: face)
+        drawBackingPlate(on: face)
+        if let track = budgetTrackRect { drawTrack(track, accent: accent, snapshot: snapshot) }
         // 总数牌压在规则背板上，独立描边在左右两侧形成错位。
         fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                              HomeDashboardStyle.color(0x101A25)], angle: 14,
@@ -140,7 +149,7 @@ final class HomeChallengeHUDView: NSView {
         if let revealFraction { drawRevealHighlight(in: surface, outline: total, accent: accent, fraction: revealFraction) }
     }
 
-    private func drawRules(on face: Face) {
+    private func drawBackingPlate(on face: Face) {
         let plate = face.rules
         let blue = HomeDashboardStyle.color(0x203547)
         NSGradient(colors: [blue.withAlphaComponent(0.62), blue.withAlphaComponent(0.30), blue.withAlphaComponent(0)])?
@@ -156,17 +165,6 @@ final class HomeChallengeHUDView: NSView {
         let leftRim = HomeDashboardStyle.slant(NSRect(x: plate.minX - 0.625, y: plate.minY,
                                                       width: cut + 1.25, height: plate.height))
         NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
-
-        for x: CGFloat in [482, 498] {
-            var mark = face.box(x, 138, width: 14, height: 20)
-            mark.size.width += HomeDashboardStyle.edgeOffset(for: mark.height)
-            HomeDashboardStyle.mark(in: mark)
-        }
-        let caption = face.box(535, 123, width: 478, height: 52)
-        let size = GameLobbyStyle.fittedSize(modeCaption, width: caption.width,
-                                             preferred: max(11, 18 * face.typographyScale), minimum: 9, weight: .bold)
-        label(modeCaption, x: caption.minX, y: caption.midY - 1, width: caption.width, size: size, weight: .bold,
-              color: HomeDashboardStyle.cyan)
     }
 
     private func drawTotals(_ snapshot: GameSnapshot, on face: Face, accent: NSColor) {
@@ -176,14 +174,11 @@ final class HomeChallengeHUDView: NSView {
         let right = body.maxX
         if showsBudget {
             let split = x + available * 0.48
-            let trackY = body.maxY - 8
-            let track = NSRect(x: x, y: trackY, width: right - x, height: 3)
-            drawTrack(track, accent: accent, snapshot: snapshot)
             let separatorTop = body.minY + 8
-            let separatorBottom = trackY - 6
+            let separatorBottom = body.maxY - 8
             let separatorOffset = HomeDashboardStyle.edgeOffset(for: separatorBottom - separatorTop) / 2
             let columnPadding = separatorOffset + 5
-            let metricY = body.midY - 4
+            let metricY = body.midY
             drawStackedMetric(budgetText, labelKey: budgetLabelKey, center: metricY, x: x,
                               width: split - x - columnPadding, height: body.height, color: accent, alignment: .left)
             drawStackedMetric(String(snapshot.totalCleared), labelKey: "home.cleared_title", center: metricY,
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 2df28e01f6529cdc84ec4ebc78104e044741091e..a599dc7c693a4b41346c846672556aff2d9438de 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -61,6 +61,90 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(hud.budgetText, "0")
     }
 
+    func testChallengeBudgetTrackReplacesOnlyTheTopBandContent() throws {
+        _ = NSApplication.shared
+        for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196)] {
+            let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size))
+            func render(_ mode: HomeGameMode, remaining: Double) throws -> NSBitmapImageRep {
+                hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode,
+                    elapsedTime: (1 - remaining) * HomeGameMode.timedDuration,
+                    remainingTime: mode == .timed ? remaining * HomeGameMode.timedDuration : nil,
+                    remainingSwaps: mode == .moves ? Int(remaining * Double(HomeGameMode.moveLimit)) : nil,
+                    isRunning: remaining > 0 && remaining < 1, isFinished: remaining == 0,
+                    clearedByKind: [.orangeRicky: 21]), mode: mode)
+                return try image(hud)
+            }
+
+            let free = try render(.free, remaining: 1)
+            XCTAssertNil(hud.budgetTrackRect)
+            let surface = hud.surfaceRect
+            let scale = CGFloat(free.pixelsWide) / size.width
+            func pixels(from start: CGFloat, to end: CGFloat) -> Range<Int> {
+                Int(ceil(start * scale))..<Int(floor(end * scale))
+            }
+            func cyanColumns(in bitmap: NSBitmapImageRep, y: Int, x: Range<Int>) -> [Int] {
+                x.filter { column in
+                    guard let color = bitmap.colorAt(x: column, y: y)?.usingColorSpace(.sRGB),
+                          color.alphaComponent > 0.8 else { return false }
+                    return min(color.greenComponent, color.blueComponent) - color.redComponent > 0.45
+                }
+            }
+            let headerBottom = surface.minY + surface.height * 52 / 186
+            let headerRows = pixels(from: surface.minY, to: headerBottom)
+            let headerColumns = pixels(from: 0, to: size.width)
+            XCTAssertFalse(headerRows.contains { !cyanColumns(in: free, y: $0, x: headerColumns).isEmpty },
+                           "自由模式的背板顶部不应残留青色标记或文字")
+
+            var timedTrack: NSRect?
+            for mode in [HomeGameMode.timed, .moves] {
+                let full = try render(mode, remaining: 1)
+                let track = try XCTUnwrap(hud.budgetTrackRect)
+                if mode == .timed { timedTrack = track } else { XCTAssertEqual(track, timedTrack) }
+                XCTAssertGreaterThan(track.minY, surface.minY)
+                XCTAssertLessThan(track.maxY, headerBottom)
+                XCTAssertEqual(track.midY, (surface.minY + headerBottom) / 2, accuracy: 0.1)
+                XCTAssertEqual(track.minX, surface.minX + surface.width * 72 / 636, accuracy: 0.1)
+                // 在轨道同一高度量两侧水平留白，斜边保持平行时整条轨道都等距。
+                let plateOffset = HomeDashboardStyle.edgeOffset(for: track.midY - surface.minY)
+                let trackOffset = HomeDashboardStyle.edgeOffset(for: track.height) / 2
+                let left = surface.minX + surface.width * 45 / 636 - plateOffset
+                let right = surface.maxX - plateOffset
+                let leftGap = track.minX + trackOffset - left
+                let rightGap = right - (track.maxX - trackOffset)
+                XCTAssertGreaterThan(leftGap, 0)
+                XCTAssertEqual(leftGap, rightGap, accuracy: 0.1)
+
+                let row = Int(track.midY * scale)
+                let columns = pixels(from: track.minX, to: track.maxX)
+                let fullInk = cyanColumns(in: full, y: row, x: columns)
+                XCTAssertGreaterThan(fullInk.count, columns.count / 2)
+                func segmentCount(_ ink: [Int]) -> Int {
+                    guard !ink.isEmpty else { return 0 }
+                    return 1 + zip(ink, ink.dropFirst()).filter { left, right in right > left + 1 }.count
+                }
+                XCTAssertEqual(segmentCount(fullInk), mode == .moves ? 30 : 1)
+
+                let partial = try render(mode, remaining: 0.5)
+                let partialInk = cyanColumns(in: partial, y: row, x: columns)
+                XCTAssertEqual(Double(partialInk.count) / Double(fullInk.count), 0.5, accuracy: 0.05)
+                XCTAssertEqual(segmentCount(partialInk), mode == .moves ? 15 : 1)
+                XCTAssertEqual(partialInk.first, fullInk.first)
+                let empty = try render(mode, remaining: 0)
+                XCTAssertEqual(hud.budgetTrackRect, track, "预算用尽后仍显示空轨道")
+                XCTAssertTrue(cyanColumns(in: empty, y: row, x: columns).isEmpty)
+                let first = try XCTUnwrap(fullInk.first)
+                XCTAssertNotEqual(empty.colorAt(x: first, y: row), free.colorAt(x: first, y: row),
+                                  "挑战归零后仍应绘制暗色轨道底板")
+
+                let totalsRows = pixels(from: headerBottom, to: surface.minY + surface.height * 132 / 186)
+                let totalsColumns = pixels(from: surface.minX + surface.width * 0.50,
+                                           to: surface.minX + surface.width * 0.85)
+                XCTAssertFalse(totalsRows.contains { !cyanColumns(in: full, y: $0, x: totalsColumns).isEmpty },
+                               "统计区下方不得重复绘制进度轨道")
+            }
+        }
+    }
+
     func testPieceCountsUseEqualCellsAndGapsAcrossStatWidths() throws {
         _ = NSApplication.shared
         let longCount = 123_456
```
