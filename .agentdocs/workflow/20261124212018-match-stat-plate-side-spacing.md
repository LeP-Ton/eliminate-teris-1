# 统一消除统计卡两侧斜边间距

## 背景与目标

- 截图标出了消除统计卡前板与背板交界处的左右斜边。原来右侧的水平间距小于左侧。
- 在同一高度测量两层轮廓，让两侧的水平间距相等，并沿用大厅统一的斜率。

## 实现

- 以前板在同一高度的横向跨度确定背板宽度，保留背板左边缘和统计前板的位置。参考尺寸下两侧水平间距均为约 40.4 点。
- 挑战预算轨道随背板边缘重新计算右端，保持背板内的左右留白相等。

## 验证

- 在 336 × 148、692 × 196 和 1360 × 148 点三种尺寸下采样 AppKit 实际描边。将交界上下的采样位置按统一斜率投到同一高度，再测量两个间距。
- 核对 1585 × 992 点首页的原生截图，以及限时和限步进度轨道的左右留白。
- 通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全套 96 项测试，全部通过。
- 手动验证可运行 `./run.sh` 后切到自由模式，改变窗口宽度，对比统计卡前板上沿左右两侧的错位距离。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 2dac6ddc6829e30494a21f09fa251e2e10065f90..8969919f7ffe66d4070119581db5c0d9c57dfdd3 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124212018-match-stat-plate-side-spacing.md` - 会话-32 起统一消除统计卡背板与前板左右斜边的水平错位，含原生像素回归及进度轨道留白校验。
 `workflow/20261124091725-animate-home-touch-bar-guide.md` - 会话-27 起将首页触控栏示意改为循环演示，包含竖直手指、蓝色滑动提示、相邻交换、三连消除和左侧补位。
 `workflow/20261124003148-move-challenge-budget-into-hud-header.md` - 会话-22 起移除统计卡顶部规则文案，自由模式留空，限时和限步把进度条移至顶部并沿斜边等距。
 `workflow/20261123231057-split-popup-lists-into-row-cards.md` - 会话-16 至会话-18 将挑战记录、旧规则记录和玩法教学按条目拆为独立斜边卡，记录表头和数据保持列对齐。
@@ -104,6 +105,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整消除统计卡背板与前板的左右斜边间距或核对等距像素回归时，读取 `20261124212018-match-stat-plate-side-spacing.md`。
 - 需要调整首页触控栏演示的手势、交换、消除、补位、循环节奏或减少动态效果时，读取 `20261124091725-animate-home-touch-bar-guide.md`。
 - 需要调整统计卡顶部的预算轨道、左右等距留白、自由模式标题区域或限时限步预算显示时，读取 `20261124003148-move-challenge-budget-into-hud-header.md`。
 - 需要调整弹窗逐行卡片、记录表头与列宽、历史记录分组或教学卡片间距时，读取 `20261123231057-split-popup-lists-into-row-cards.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index b4f0f486b189a0c188551d3ec70e0b3535cf72fe..9b0b74fd5cfa698d6d72539ace2a35323f05598d 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -23,12 +23,18 @@ final class HomeChallengeHUDView: NSView {
     var breakdownCellRects: [NSRect] { Face(frame: surfaceRect).breakdownCellRects }
     var budgetTrackRect: NSRect? { showsBudget ? Face(frame: surfaceRect).budgetTrack : nil }
 
-    /// 设计稿坐标以底部分格左边缘为参考。背板可以越过这个边缘，在前层左侧露出。
+    /// 设计稿坐标以底部分格左边缘为参考。背板与前板同宽，沿同一斜率错开。
     private struct Face {
         let frame: NSRect
         var typographyScale: CGFloat { min(frame.width / 636, frame.height / 186) }
 
-        var rules: NSRect { plate(from: point(455, 123), to: point(1046, 309)) }
+        var rules: NSRect {
+            let left = point(455, 123)
+            let front = totals
+            // 两层在同一高度的净宽相同，左右斜边就会露出相同的错位。
+            let width = front.width - HomeDashboardStyle.edgeOffset(for: front.height)
+            return plate(from: left, to: NSPoint(x: left.x + width, y: point(455, 309).y))
+        }
         var totals: NSRect { plate(from: point(472, 175), to: point(1033, 255)) }
 
         var budgetTrack: NSRect {
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index a599dc7c693a4b41346c846672556aff2d9438de..05c4c87678b3495cffde60f46a6cb9360e716a5c 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -61,6 +61,48 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(hud.budgetText, "0")
     }
 
+    func testStatisticsPlateSlantsHaveEqualVisibleSpacing() throws {
+        _ = NSApplication.shared
+        for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196), NSSize(width: 1_360, height: 148)] {
+            let hud = HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size))
+            hud.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
+                                              remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free)
+            let bitmap = try image(hud)
+            let scale = CGFloat(bitmap.pixelsWide) / size.width
+            let surface = hud.surfaceRect
+            let join = surface.minY + surface.height * 52 / 186
+
+            func rimCenters(at y: CGFloat) -> [CGFloat] {
+                let row = Int(y * scale)
+                let bright = (0..<bitmap.pixelsWide).filter { x in
+                    guard let color = bitmap.colorAt(x: x, y: row)?.usingColorSpace(.sRGB) else { return false }
+                    return color.alphaComponent > 0.4 && color.redComponent > 0.26
+                }
+                var spans: [ClosedRange<Int>] = []
+                for x in bright {
+                    if let previous = spans.last, x == previous.upperBound + 1 {
+                        spans[spans.count - 1] = previous.lowerBound...x
+                    } else {
+                        spans.append(x...x)
+                    }
+                }
+                return spans.map { CGFloat($0.lowerBound + $0.upperBound) / (2 * scale) }
+            }
+
+            // 背板右线会在交界处被盖住，将交界上方的两根背板斜线投到同一测量高度。
+            let rear = rimCenters(at: join - 4)
+            let front = rimCenters(at: join + 4)
+            XCTAssertEqual(rear.count, 2, "\(size)：交界上方应显示背板的两根斜边")
+            XCTAssertEqual(front.count, 3, "\(size)：交界下方应显示背板左边和两根前板斜边")
+            guard rear.count == 2, front.count == 3 else { continue }
+            let shift = HomeDashboardStyle.edgeOffset(for: 8)
+            let leftGap = front[1] - rear[0] + shift
+            let rightGap = front[2] - rear[1] + shift
+            XCTAssertGreaterThan(leftGap, 0)
+            XCTAssertEqual(rightGap, leftGap, accuracy: 1.5, "\(size)：左右可见错位要等宽")
+        }
+    }
+
     func testChallengeBudgetTrackReplacesOnlyTheTopBandContent() throws {
         _ = NSApplication.shared
         for size in [NSSize(width: 336, height: 148), NSSize(width: 692, height: 196)] {
@@ -108,7 +150,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                 let plateOffset = HomeDashboardStyle.edgeOffset(for: track.midY - surface.minY)
                 let trackOffset = HomeDashboardStyle.edgeOffset(for: track.height) / 2
                 let left = surface.minX + surface.width * 45 / 636 - plateOffset
-                let right = surface.maxX - plateOffset
+                let right = surface.minX + surface.width * 606 / 636 - plateOffset
                 let leftGap = track.minX + trackOffset - left
                 let rightGap = right - (track.maxX - trackOffset)
                 XCTAssertGreaterThan(leftGap, 0)
```
