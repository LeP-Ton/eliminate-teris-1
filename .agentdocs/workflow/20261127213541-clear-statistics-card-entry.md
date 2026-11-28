# 修复统计卡入场时的右栏遮挡

## 背景与目标

- 会话-104 报告切换游戏模式时，统计卡刚从右侧弹出就有部分卡层被遮挡。
- 旧动画以游戏模式栏的左边界作为小卡的左边界。模式栏会额外绘制大块背景，开头几帧由这块背景盖住卡片，旧测试也把遮挡当作正常结果。

## 实施

- 把缩小后整张卡的右边缘放在模式栏左侧，首帧留 6 点间距。摆放新旧卡时都按当前栏位约束右端，覆盖缩窗与快速反向切换。
- 统计卡从 28% 尺寸等比滑入，前段更快淡入，一秒到位。模式栏的底色由大厅统一绘制。
- 用逐帧边界和入场前段的合成像素替换原来的遮挡断言，实际检测顶部进度背板与右侧分类格的可见性。

## 验证

- 使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 运行全量测试，105 项全部通过。
- 在 1180 点宽大厅逐帧验证完整入场，核对 0.12 秒时的背板与分类格。验证快速切回、转场中缩到 960 点、开局刷新与减少动态效果。查看导出的入场与中段原生截图。
- 手工复核可运行 `./run.sh`，在自由、限时和限步之间切换，观察整张统计卡在模式栏左侧展开。

## 本轮完整增量 diff

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 6ad282b8c53e634ae828b152c9456c710c07a03f..a76bf8a984156b027bf782c008880461289b1d32 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127213541-clear-statistics-card-entry.md` - 会话-104 起把统计卡的起点移出右栏，前段更快淡入，含双层像素、连续切换和缩窗回归。
 `workflow/20261127210415-remove-lobby-division-and-logo-accent.md` - 会话-100 起移除首页分隔左右栏的斜线和标志下方的高亮线。
 `workflow/20261127063642-polish-mode-selection-and-navigation-padding.md` - 会话-95 起移除选中模式卡右侧的对勾，为顶栏三项导航增加左右内边距。
 `workflow/20261125080913-fix-count-increment-cadence.md` - 会话-56 起固定统计数字的 60 毫秒节拍，连续消除沿同一节拍增加目标，大连锁在十拍内追上实际值。
@@ -112,6 +113,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡滑入起点、入场可见性或切换过程中缩窗时，读取 `20261127213541-clear-statistics-card-entry.md`。
 - 需要核对首页左右栏分隔线或标志下方高亮时，读取 `20261127210415-remove-lobby-division-and-logo-accent.md`。
 - 需要调整首页选中模式提示、顶栏按钮内边距或不同语言下的导航间距时，读取 `20261127063642-polish-mode-selection-and-navigation-padding.md`。
 - 需要调整统计数字固定节拍、连续消除时的接续或大连锁的计数追赶时，读取 `20261125080913-fix-count-increment-cadence.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index c1c4069f87210267ed69083a91ff975855f174fe..64eaf2f36df621ffab45a53d2889a8fb3d674779 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -589,7 +589,6 @@ final class HomeDashboardView: NSView {
         appearance = NSAppearance(named: .darkAqua)
         hint.isSelectable = false
         hint.drawsBackground = false
-        // 右侧模式列表以相同背景遮住跨入右栏的统计卡，原生控件继续处理点击和键盘焦点。
         [hero, guide, hint, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
         startButton.style = .primary
         startButton.symbolName = "play.fill"
@@ -807,7 +806,7 @@ final class HomeDashboardView: NSView {
 
 }
 
-/// 单独绘制右侧外框，让它能遮住滑到后方的统计卡。
+/// 右栏标题和游戏模式按钮共用同一布局区域。
 final class HomeModePanelView: NSView {
     override var isFlipped: Bool { true }
     var isCompact: Bool { bounds.height < 340 }
@@ -820,9 +819,6 @@ final class HomeModePanelView: NSView {
     required init?(coder: NSCoder) { nil }
 
     override func draw(_ dirtyRect: NSRect) {
-        if let superview {
-            HomeDashboardStyle.backdrop(in: convert(superview.bounds, from: superview))
-        }
         let size: CGFloat = isCompact ? 24 : 29
         HomeDashboardStyle.mark(in: NSRect(x: 26, y: 7, width: 21, height: size * 0.83))
         HomeDashboardStyle.text(AchievementText.string("home.game_modes"),
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index da099d6d3086622b7d0d6148d4dd20fcd2608926..63d8261ab8dfbb9be4402570348dd66aba678e38 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -3,7 +3,8 @@ import Cocoa
 /// 上方文案和本局统计并排排版，切换模式时仅统计卡从右侧滑入。
 final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1
-    private static let distantScale: CGFloat = 0.20
+    private static let distantScale: CGFloat = 0.28
+    private static let entryClearance: CGFloat = 6
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
@@ -14,7 +15,7 @@ final class HomeModeHeaderView: NSView {
     private var timer: Timer?
     private var transition: Transition?
     private var cardColumn = NSRect.zero
-    private var entryX: CGFloat = 0
+    private var modePanelLeading: CGFloat = 0
 
     private struct Pose {
         let offset: CGFloat
@@ -58,7 +59,7 @@ final class HomeModeHeaderView: NSView {
         cardColumn = NSRect(x: cardX, y: topPadding + cardTop,
                             width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                             height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
-        entryX = modePanelLeading
+        self.modePanelLeading = modePanelLeading
         needsLayout = true
     }
 
@@ -89,8 +90,8 @@ final class HomeModeHeaderView: NSView {
 
     private func animate(reuseIncoming: Bool) {
         // 以卡面宽度为单位记录位置，重设窗口尺寸时进度可按比例继续。
-        let right = visibleRightEdge - cardColumn.width * Self.distantScale - 6
-        let launchX = min(entryX, right)
+        let launchRight = min(modePanelLeading, visibleRightEdge) - Self.entryClearance
+        let launchX = launchRight - cardColumn.width * Self.distantScale
         let launch = Pose(offset: (launchX - cardColumn.minX) / cardColumn.width, scale: Self.distantScale, alpha: 0)
         transition = Transition(start: now(), outgoing: pose(of: spareCard), incoming: reuseIncoming ? pose(of: card) : launch)
         card.isHidden = false
@@ -162,9 +163,8 @@ final class HomeModeHeaderView: NSView {
         let travel = t * t * (3 - 2 * t)
         let incoming = transition.incoming
         let scale = incoming.scale + (1 - incoming.scale) * travel
-        let rightmostOffset = (bounds.maxX - cardColumn.minX) / cardColumn.width - scale
-        let offset = min(incoming.offset * (1 - travel), rightmostOffset)
-        place(card, pose: Pose(offset: offset, scale: scale, alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(travel)))
+        place(card, pose: Pose(offset: incoming.offset * (1 - travel), scale: scale,
+                               alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(t)))
         card.revealFraction = travel
 
         let outgoing = transition.outgoing
@@ -174,10 +174,13 @@ final class HomeModeHeaderView: NSView {
     }
 
     private func place(_ view: HomeChallengeHUDView, pose: Pose) {
-        // 入场全程等比缩放，使卡片斜边和文字角度在移动时也保持一致。
-        view.frame = NSRect(x: cardColumn.minX + pose.offset * cardColumn.width,
+        let width = cardColumn.width * pose.scale
+        // 按当前栏位约束整个卡片，窗口缩放或快速切换时也给右栏留空。
+        let right = max(cardColumn.maxX, modePanelLeading - Self.entryClearance)
+        let x = min(cardColumn.minX + pose.offset * cardColumn.width, right - width)
+        view.frame = NSRect(x: x,
                             y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale,
-                            width: cardColumn.width * pose.scale, height: cardColumn.height * pose.scale)
+                            width: width, height: cardColumn.height * pose.scale)
         view.bounds = NSRect(origin: .zero, size: cardColumn.size)
         view.alphaValue = pose.alpha
     }
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 05c4c87678b3495cffde60f46a6cb9360e716a5c..ace19860d1b62f29a2ae76bcdac851ca656ca6d9 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -367,12 +367,12 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         home.refresh(snapshot: timed, mode: .timed, manager: manager)
         let preview = home.challengeHUD
         XCTAssertGreaterThan(preview.frame.minX, restingX)
-        XCTAssertLessThanOrEqual(preview.frame.minX, home.modePanel.frame.minX + 0.1)
-        XCTAssertEqual(preview.frame.width, restingWidth * 0.20, accuracy: 0.1)
+        XCTAssertLessThanOrEqual(preview.frame.maxX, home.modePanel.frame.minX - 5.9)
+        XCTAssertEqual(preview.frame.width, restingWidth * 0.28, accuracy: 0.1)
         XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
                        accuracy: 0.001, "卡面起始帧须保持原有斜边角度")
         try assertLaunchIsWithinScreen(preview, in: window)
-        XCTAssertLessThan(preview.alphaValue, 0.2)
+        XCTAssertEqual(preview.alphaValue, 0)
 
         let steps = 25
         let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-challenge-preview.gif")
@@ -385,7 +385,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             clock = 100 + duration * Double(step) / Double(steps)
             header.advanceAnimation()
             XCTAssertGreaterThanOrEqual(preview.frame.width + 0.1, previousWidth)
-            XCTAssertLessThanOrEqual(preview.frame.maxX, header.bounds.maxX + 0.1)
+            XCTAssertLessThan(preview.frame.maxX, home.modePanel.frame.minX, "统计卡完整位于右栏左侧")
             XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
                            accuracy: 0.001, "入场每帧都须等比缩放")
             previousWidth = preview.frame.width
@@ -397,16 +397,17 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                 home.layoutSubtreeIfNeeded()
                 XCTAssertEqual(preview.frame.minX, position, accuracy: 1, "重复刷新不能重启动画")
             }
-            if step == steps / 3 { try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview) }
+            if step == 3 { try assertPreviewLayersAreVisible(home, preview: preview) }
             XCTAssertEqual(intro.frame, introFrame, "切换统计卡时保留标题的位置")
             XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, restingSurfaceY, accuracy: 0.1)
             home.layoutSubtreeIfNeeded()
             let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
             home.cacheDisplay(in: header.frame, to: pixels)
             let frame = try XCTUnwrap(pixels.cgImage)
-            if step == steps * 3 / 4 {
+            if step == 3 || step == steps * 3 / 4 {
+                let name = step == 3 ? "eliminate-challenge-preview-entry.png" : "eliminate-challenge-preview-motion.png"
                 try XCTUnwrap(pixels.representation(using: .png, properties: [:]))
-                    .write(to: url.deletingLastPathComponent().appendingPathComponent("eliminate-challenge-preview-motion.png"))
+                    .write(to: url.deletingLastPathComponent().appendingPathComponent(name))
             }
             let delay = step == steps ? 1.0 : duration / Double(steps)
             CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
@@ -421,6 +422,16 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         home.refresh(snapshot: moves, mode: .moves, manager: manager)
         XCTAssertEqual(home.challengeHUD.budgetText, "30")
         XCTAssertEqual(preview.mode, .timed, "离场卡保留原规则")
+        clock += 0.12
+        header.advanceAnimation()
+        let reversingFrame = preview.frame
+        home.refresh(snapshot: timed, mode: .timed, manager: manager)
+        XCTAssertEqual(home.challengeHUD.frame.minX, reversingFrame.minX, accuracy: 0.1, "反向切换从离场卡当前位置继续")
+        XCTAssertEqual(home.challengeHUD.frame.width, reversingFrame.width, accuracy: 0.1)
+        home.refresh(snapshot: moves, mode: .moves, manager: manager)
+        home.setFrameSize(NSSize(width: 960, height: 720))
+        home.layoutSubtreeIfNeeded()
+        XCTAssertLessThan(max(home.challengeHUD.frame.maxX, preview.frame.maxX), home.modePanel.frame.minX)
         clock += 0.7
         header.advanceAnimation()
         let frameDuringEntry = home.challengeHUD.frame
@@ -430,7 +441,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(home.challengeHUD.budgetText, "29")
         reduceMotion = true
         header.advanceAnimation()
-        XCTAssertEqual(home.challengeHUD.frame.minX, restingX, accuracy: 1)
+        XCTAssertLessThan(home.challengeHUD.frame.maxX, home.modePanel.frame.minX)
+        XCTAssertEqual(home.challengeHUD.alphaValue, 1)
         XCTAssertTrue(preview.isHidden)
         home.refresh(snapshot: free, mode: .free, manager: manager)
         XCTAssertFalse(home.challengeHUD.isHidden)
@@ -492,12 +504,11 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         }
     }
 
-    private func assertPreviewLaysOverGapAndBehindPanel(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
-        let panel = home.modePanel.frame
-        let surface = preview.convert(preview.surfaceRect, to: home)
-        let gapPoint = NSPoint(x: panel.minX - 10, y: surface.midY)
-        let panelPoint = NSPoint(x: panel.minX + 10, y: gapPoint.y)
-        XCTAssertTrue(surface.contains(gapPoint) && surface.contains(panelPoint))
+    private func assertPreviewLayersAreVisible(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
+        let budget = try XCTUnwrap(preview.budgetTrackRect)
+        let cell = try XCTUnwrap(preview.breakdownCellRects.last)
+        let budgetPoint = preview.convert(NSPoint(x: budget.maxX - budget.width * 0.2, y: budget.midY), to: home)
+        let cellPoint = preview.convert(NSPoint(x: cell.midX, y: cell.midY), to: home)
 
         func color(at point: NSPoint) throws -> NSColor {
             let rect = NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
@@ -509,12 +520,12 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             abs(first.redComponent - second.redComponent) + abs(first.greenComponent - second.greenComponent) + abs(first.blueComponent - second.blueComponent)
         }
 
-        let visibleGap = try color(at: gapPoint)
-        let visiblePanel = try color(at: panelPoint)
+        let visibleBudget = try color(at: budgetPoint)
+        let visibleCell = try color(at: cellPoint)
         preview.isHidden = true
         defer { preview.isHidden = false }
-        XCTAssertGreaterThan(difference(visibleGap, try color(at: gapPoint)), 0.012, "超出左栏的卡面应进入两栏间隙")
-        XCTAssertLessThan(difference(visiblePanel, try color(at: panelPoint)), 0.008, "右侧面板应在重叠处完整盖住统计卡")
+        XCTAssertGreaterThan(difference(visibleBudget, try color(at: budgetPoint)), 0.06, "入场前段的进度背板应当可见")
+        XCTAssertGreaterThan(difference(visibleCell, try color(at: cellPoint)), 0.012, "入场前段的右侧分类格应当可见")
     }
 
     func testModeArtworkKeepsTransparencyAndIdentityAtSmallAndWideSizes() throws {
```
