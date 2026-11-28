# 统计卡前后两层交错叠合

## 背景与目标

- 会话-107 要求将统计卡整体从右侧滑入的动画，改为上下两层交错叠起来的效果。

## 实施

- 背板带着进度轨道从左上落下，前板带着本局统计与四类方块从右下稍后滑上。两层合拢后，青色高光沿接缝扫过。完整转场为 0.70 秒。
- 两层从同一张统计卡读取当前快照。快速连续切换更新到最新模式并接续当前动画，开局和重复刷新沿用当前进度。启用减少动态效果时直接归位。
- 为运动中的两层临时扩展绘制范围，保留两层的静态坐标及与右栏的间距。

## 验证

- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，105 项全部通过。
- 逐帧核对两层延迟、移动、合拢与高光，检查入场前段轨道和右端分类格的实际像素。补充缩窗、连续切换、开局刷新及减少动态效果的回归。
- 查看 AppKit 导出的动图帧，确认入场分层可见，收尾高光沿接缝呈现。运行 `./run.sh` 后可在自由、限时和限步之间切换，查看完整转场。

## 本轮完整增量 diff

以会话-107 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index a76bf8a984156b027bf782c008880461289b1d32..f379067ad3174a8926865ffe9cafe07f3a51f4de 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261127215826-stack-statistics-card-plates.md` - 会话-107 起改用背板和前板交错叠合，再以接缝高光收尾，含逐帧和快速切换验证。
 `workflow/20261127213541-clear-statistics-card-entry.md` - 会话-104 起把统计卡的起点移出右栏，前段更快淡入，含双层像素、连续切换和缩窗回归。
 `workflow/20261127210415-remove-lobby-division-and-logo-accent.md` - 会话-100 起移除首页分隔左右栏的斜线和标志下方的高亮线。
 `workflow/20261127063642-polish-mode-selection-and-navigation-padding.md` - 会话-95 起移除选中模式卡右侧的对勾，为顶栏三项导航增加左右内边距。
@@ -113,6 +114,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统计卡双层叠合、收尾高光或连续切换的动画节奏时，读取 `20261127215826-stack-statistics-card-plates.md`。
 - 需要调整统计卡滑入起点、入场可见性或切换过程中缩窗时，读取 `20261127213541-clear-statistics-card-entry.md`。
 - 需要核对首页左右栏分隔线或标志下方高亮时，读取 `20261127210415-remove-lobby-division-and-logo-accent.md`。
 - 需要调整首页选中模式提示、顶栏按钮内边距或不同语言下的导航间距时，读取 `20261127063642-polish-mode-selection-and-navigation-padding.md`。
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 63d8261ab8dfbb9be4402570348dd66aba678e38..1cbf3e35d2f4d42d494c3835d72a44d4f74b2936 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -1,34 +1,16 @@
 import Cocoa
 
-/// 上方文案和本局统计并排排版，切换模式时仅统计卡从右侧滑入。
+/// 上方文案和本局统计并排排版，切换模式时交错叠合统计卡的前后两层。
 final class HomeModeHeaderView: NSView {
-    static let previewDuration: TimeInterval = 1
-    private static let distantScale: CGFloat = 0.28
-    private static let entryClearance: CGFloat = 6
+    static let previewDuration: TimeInterval = 0.70
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
     private let intro = HomeModeIntroView(frame: .zero)
-    private(set) var card = HomeChallengeHUDView(frame: .zero)
-    private var spareCard = HomeChallengeHUDView(frame: .zero)
-    private var selectedMode: HomeGameMode?
+    let card = HomeChallengeHUDView(frame: .zero)
     private var timer: Timer?
-    private var transition: Transition?
+    private var transitionStart: TimeInterval?
     private var cardColumn = NSRect.zero
-    private var modePanelLeading: CGFloat = 0
-
-    private struct Pose {
-        let offset: CGFloat
-        let scale: CGFloat
-        let alpha: CGFloat
-    }
-
-    private struct Transition {
-        let start: TimeInterval
-        let outgoing: Pose
-        let incoming: Pose
-        var fraction: CGFloat = 0
-    }
 
     override var isFlipped: Bool { true }
 
@@ -36,18 +18,17 @@ final class HomeModeHeaderView: NSView {
         super.init(frame: frame)
         wantsLayer = true
         layer?.masksToBounds = true
-        addSubview(spareCard)
         addSubview(card)
         addSubview(intro)
-        settle()
     }
 
     required init?(coder: NSCoder) { nil }
     deinit { timer?.invalidate() }
 
     func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
-        let topPadding = HomeChallengeHUDView.surfaceInsetY + 3
-        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
+        let topPadding = HomeChallengeHUDView.surfaceInsetY + 3 + HomeChallengeHUDView.assemblyTopSpace
+        frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth,
+                       height: leftColumn.height + topPadding + HomeChallengeHUDView.assemblyBottomSpace)
         let headingWidth = (leftColumn.width * 0.361).rounded(.down)
         let gap = min(16, leftColumn.width * 0.025)
         intro.frame = NSRect(x: leftColumn.minX, y: topPadding, width: headingWidth, height: leftColumn.height)
@@ -56,10 +37,9 @@ final class HomeModeHeaderView: NSView {
         let faceX = intro.frame.maxX + gap + HomeChallengeHUDView.trailingInset
         let faceRight = modePanelLeading - min(22, leftColumn.width * 0.031)
         let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX), height: cardHeight)
-        cardColumn = NSRect(x: cardX, y: topPadding + cardTop,
+        cardColumn = NSRect(x: cardX, y: topPadding + cardTop - HomeChallengeHUDView.surfaceInsetY,
                             width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                             height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
-        self.modePanelLeading = modePanelLeading
         needsLayout = true
     }
 
@@ -69,65 +49,40 @@ final class HomeModeHeaderView: NSView {
     }
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
-        let changedMode = selectedMode.map { $0 != mode } ?? false
-        let reuseIncoming = changedMode && !spareCard.isHidden && spareCard.mode == mode
-        if changedMode {
-            // 离场卡保留自己的快照，连续切换时只在回到同一模式后续用它的位置。
-            let previousCard = card
-            card = spareCard
-            spareCard = previousCard
-        }
-        selectedMode = mode
+        let changedMode = card.snapshot != nil && card.mode != mode
         card.refresh(snapshot: snapshot, mode: mode)
         intro.refresh(mode: mode)
 
-        if changedMode, window != nil, cardColumn.width > 0, !reducesMotion() {
-            animate(reuseIncoming: reuseIncoming)
-        } else if changedMode || transition == nil {
+        guard changedMode else { return }
+        guard window != nil, cardColumn.width > 0, !reducesMotion() else {
             settle()
+            return
         }
-    }
-
-    private func animate(reuseIncoming: Bool) {
-        // 以卡面宽度为单位记录位置，重设窗口尺寸时进度可按比例继续。
-        let launchRight = min(modePanelLeading, visibleRightEdge) - Self.entryClearance
-        let launchX = launchRight - cardColumn.width * Self.distantScale
-        let launch = Pose(offset: (launchX - cardColumn.minX) / cardColumn.width, scale: Self.distantScale, alpha: 0)
-        transition = Transition(start: now(), outgoing: pose(of: spareCard), incoming: reuseIncoming ? pose(of: card) : launch)
-        card.isHidden = false
-        card.setAccessibilityHidden(false)
-        spareCard.setAccessibilityHidden(true)
-        addSubview(card, positioned: .above, relativeTo: spareCard)
-        placeSubviews()
+        // 连续换模式时直接更新内容，已经在叠合的两层沿当前进度到位。
+        guard transitionStart == nil else { return }
+        transitionStart = now()
+        card.positionPlates(in: cardColumn, assembling: true)
+        card.plateAssembly = .separated
 
-        timer?.invalidate()
         let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advanceAnimation() }
         RunLoop.main.add(timer, forMode: .common)
         self.timer = timer
     }
 
-    private var visibleRightEdge: CGFloat {
-        guard let window, let screen = window.screen else { return bounds.maxX }
-        let point = NSPoint(x: screen.frame.maxX, y: screen.frame.midY)
-        return min(bounds.maxX, convert(window.convertPoint(fromScreen: point), from: nil).x)
-    }
-
-    private func pose(of view: HomeChallengeHUDView) -> Pose {
-        Pose(offset: (view.frame.minX - cardColumn.minX) / cardColumn.width,
-             scale: view.bounds.width > 0 ? view.frame.width / view.bounds.width : 1,
-             alpha: view.alphaValue)
-    }
-
     func advanceAnimation() {
-        guard var transition else { return }
-        let elapsed = max(0, now() - transition.start)
-        if elapsed >= Self.previewDuration || reducesMotion() {
+        guard let transitionStart else { return }
+        let elapsed = max(0, now() - transitionStart)
+        guard elapsed < Self.previewDuration, !reducesMotion() else {
             settle()
-        } else {
-            transition.fraction = CGFloat(elapsed / Self.previewDuration)
-            self.transition = transition
-            placeSubviews()
+            return
         }
+        let time = CGFloat(elapsed / Self.previewDuration)
+        let backingRemaining = 1 - min(1, time / 0.62)
+        let frontTime = min(1, max(0, (time - 0.12) / 0.66))
+        let highlight = max(0, (time - 0.78) / 0.22)
+        card.plateAssembly = .init(backing: 1 - backingRemaining * backingRemaining * backingRemaining,
+                                   front: frontTime * frontTime * (3 - 2 * frontTime),
+                                   highlight: highlight)
     }
 
     override func viewDidMoveToWindow() {
@@ -137,52 +92,15 @@ final class HomeModeHeaderView: NSView {
 
     override func layout() {
         super.layout()
-        placeSubviews()
+        card.positionPlates(in: cardColumn, assembling: transitionStart != nil)
     }
 
     private func settle() {
-        transition = nil
+        transitionStart = nil
         timer?.invalidate()
         timer = nil
-        card.isHidden = false
-        card.setAccessibilityHidden(false)
-        spareCard.isHidden = true
-        spareCard.setAccessibilityHidden(true)
-        placeSubviews()
-    }
-
-    private func placeSubviews() {
-        guard let transition, cardColumn.width > 0 else {
-            place(card, pose: Pose(offset: 0, scale: 1, alpha: 1))
-            place(spareCard, pose: Pose(offset: 0, scale: 1, alpha: 1))
-            card.revealFraction = nil
-            spareCard.revealFraction = nil
-            return
-        }
-        let t = transition.fraction
-        let travel = t * t * (3 - 2 * t)
-        let incoming = transition.incoming
-        let scale = incoming.scale + (1 - incoming.scale) * travel
-        place(card, pose: Pose(offset: incoming.offset * (1 - travel), scale: scale,
-                               alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(t)))
-        card.revealFraction = travel
-
-        let outgoing = transition.outgoing
-        place(spareCard, pose: Pose(offset: outgoing.offset * (1 - travel) - 0.08 * travel,
-                                    scale: outgoing.scale, alpha: outgoing.alpha * (1 - travel)))
-        spareCard.revealFraction = nil
-    }
-
-    private func place(_ view: HomeChallengeHUDView, pose: Pose) {
-        let width = cardColumn.width * pose.scale
-        // 按当前栏位约束整个卡片，窗口缩放或快速切换时也给右栏留空。
-        let right = max(cardColumn.maxX, modePanelLeading - Self.entryClearance)
-        let x = min(cardColumn.minX + pose.offset * cardColumn.width, right - width)
-        view.frame = NSRect(x: x,
-                            y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale,
-                            width: width, height: cardColumn.height * pose.scale)
-        view.bounds = NSRect(origin: .zero, size: cardColumn.size)
-        view.alphaValue = pose.alpha
+        card.plateAssembly = .settled
+        card.positionPlates(in: cardColumn, assembling: false)
     }
 }
 
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 168fc6b6fdaaed5dcd4c6fd7a76c425d6b41f6f3..4c3f664c6ae4e1241f8be7f6c1298bad3702d972 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -8,14 +8,41 @@ final class HomeChallengeHUDView: NSView {
     private static let rearTopInset: CGFloat = 45 / 636
     private static let countStepInterval: TimeInterval = 0.06
     private static let maxCountSteps = 10
+    private static let backingTravel = NSPoint(x: -24, y: -26)
+    private static let frontTravel = NSPoint(x: 8, y: 24)
+    static let assemblyTopSpace = -backingTravel.y
+    static let assemblyBottomSpace = frontTravel.y
+
+    struct PlateAssembly: Equatable {
+        let backing: CGFloat
+        let front: CGFloat
+        let highlight: CGFloat
+
+        static let separated = PlateAssembly(backing: 0, front: 0, highlight: 0)
+        static let settled = PlateAssembly(backing: 1, front: 1, highlight: 0)
+    }
+
+    private var plateSize: NSSize?
+    var plateAssembly = PlateAssembly.settled {
+        didSet { if plateAssembly != oldValue { needsDisplay = true } }
+    }
+
+    var backingPlateOffset: NSPoint {
+        NSPoint(x: Self.backingTravel.x * (1 - plateAssembly.backing), y: Self.backingTravel.y * (1 - plateAssembly.backing))
+    }
+
+    var frontPlateOffset: NSPoint {
+        NSPoint(x: Self.frontTravel.x * (1 - plateAssembly.front), y: Self.frontTravel.y * (1 - plateAssembly.front))
+    }
 
     static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
         max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
     }
 
     var surfaceRect: NSRect {
-        let height = max(0, bounds.height - 2 * Self.surfaceInsetY)
-        let available = bounds.width - Self.trailingInset
+        let size = plateSize ?? bounds.size
+        let height = max(0, size.height - 2 * Self.surfaceInsetY)
+        let available = size.width - Self.trailingInset
         // 窄窗背板向左伸得更远，为斜边和描线留出完整空间。
         let rearWidth = (available - HomeDashboardStyle.edgeOffset(for: height) - 1) / (1 - Self.rearTopInset)
         let width = max(0, min(available / (1 + Self.rearOverhang), rearWidth))
@@ -25,6 +52,18 @@ final class HomeChallengeHUDView: NSView {
     var breakdownCellRects: [NSRect] { Face(frame: surfaceRect).breakdownCellRects }
     var budgetTrackRect: NSRect? { showsBudget ? Face(frame: surfaceRect).budgetTrack : nil }
 
+    func positionPlates(in rect: NSRect, assembling: Bool) {
+        plateSize = rect.size
+        // 动画留白只扩展绘制范围，牌面尺寸与静态坐标保持一致。
+        let left = assembling ? -Self.backingTravel.x : 0
+        let top = assembling ? Self.assemblyTopSpace : 0
+        let right = assembling ? Self.frontTravel.x : 0
+        let bottom = assembling ? Self.assemblyBottomSpace : 0
+        frame = NSRect(x: rect.minX - left, y: rect.minY - top,
+                       width: rect.width + left + right, height: rect.height + top + bottom)
+        bounds = NSRect(x: -left, y: -top, width: frame.width, height: frame.height)
+    }
+
     /// 设计稿坐标以底部分格左边缘为参考。背板与前板同宽，沿同一斜率错开。
     private struct Face {
         let frame: NSRect
@@ -110,7 +149,6 @@ final class HomeChallengeHUDView: NSView {
     private var countTransitions: [PieceKind: CountTransition] = [:]
     private var countAnimationStart: TimeInterval?
     private var countAnimationTimer: Timer?
-    var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
     override var isFlipped: Bool { true }
     init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
          reducesMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
@@ -236,29 +274,38 @@ final class HomeChallengeHUDView: NSView {
         guard let snapshot, surface.width > 40, surface.height > 45 else { return }
         let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
         let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
-        let face = Face(frame: surface)
-        let total = HomeDashboardStyle.slant(face.totals)
-        if let revealFraction {
-            let depth = 1 - revealFraction
-            NSGraphicsContext.saveGraphicsState()
-            let offset = NSAffineTransform()
-            offset.translateX(by: 2.5 * depth, yBy: 4.5 * depth)
-            offset.concat()
-            accent.withAlphaComponent(0.46 * depth).setFill()
-            total.fill()
-            NSGraphicsContext.restoreGraphicsState()
+        let backing = backingPlateOffset
+        let backFace = Face(frame: surface.offsetBy(dx: backing.x, dy: backing.y))
+        drawPlate(opacity: 0.46 + 0.54 * plateAssembly.backing) {
+            drawBackingPlate(on: backFace)
+            if showsBudget { drawTrack(backFace.budgetTrack, accent: accent, snapshot: snapshot) }
         }
 
-        drawBackingPlate(on: face)
-        if let track = budgetTrackRect { drawTrack(track, accent: accent, snapshot: snapshot) }
-        // 总数牌压在规则背板上，独立描边在左右两侧形成错位。
-        fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
-                             HomeDashboardStyle.color(0x101A25)], angle: 14,
-             border: HomeDashboardStyle.color(0x57636B))
-        let counts = displayedCounts()
-        drawTotals(counts.values.reduce(0, +), on: face, accent: accent)
-        drawBreakdown(counts, on: face)
-        if let revealFraction { drawRevealHighlight(in: surface, outline: total, accent: accent, fraction: revealFraction) }
+        let front = frontPlateOffset
+        let frontFace = Face(frame: surface.offsetBy(dx: front.x, dy: front.y))
+        drawPlate(opacity: 0.62 + 0.38 * plateAssembly.front) {
+            fill(HomeDashboardStyle.slant(frontFace.totals),
+                 colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
+                          HomeDashboardStyle.color(0x101A25)], angle: 14, border: HomeDashboardStyle.color(0x57636B))
+            let counts = displayedCounts()
+            drawTotals(counts.values.reduce(0, +), on: frontFace, accent: accent)
+            drawBreakdown(counts, on: frontFace)
+        }
+        drawJoinHighlight(on: frontFace.totals, accent: accent)
+    }
+
+    private func drawPlate(opacity: CGFloat, _ draw: () -> Void) {
+        guard opacity < 1, let context = NSGraphicsContext.current?.cgContext else {
+            draw()
+            return
+        }
+        // 按整层合成透明度，牌面中的渐变、文字和方块保持原有叠放。
+        context.saveGState()
+        context.setAlpha(opacity)
+        context.beginTransparencyLayer(auxiliaryInfo: nil)
+        draw()
+        context.endTransparencyLayer()
+        context.restoreGState()
     }
 
     private func drawBackingPlate(on face: Face) {
@@ -383,17 +430,19 @@ final class HomeChallengeHUDView: NSView {
                                 size: size, weight: weight, color: color, alignment: alignment)
     }
 
-    private func drawRevealHighlight(in face: NSRect, outline: NSBezierPath, accent: NSColor, fraction: CGFloat) {
-        // 斜光随卡面掠过一次，最终回到静态描边。
-        let intensity = sin(.pi * fraction)
-        guard intensity > 0 else { return }
+    private func drawJoinHighlight(on plate: NSRect, accent: NSColor) {
+        let progress = plateAssembly.highlight
+        guard progress > 0, progress < 1 else { return }
+        let left = plate.minX + HomeDashboardStyle.edgeOffset(for: plate.height)
+        let width = max(0, plate.maxX - left)
+        let beamWidth = min(160, width * 0.44)
+        let center = left + width * progress
+        let intensity = sin(.pi * progress)
+        let seam = NSRect(x: left, y: plate.minY - 1, width: width, height: 2)
         NSGraphicsContext.saveGraphicsState()
-        outline.addClip()
-        let width = min(140, face.width * 0.32) + HomeDashboardStyle.edgeOffset(for: face.height)
-        let x = face.maxX + width - (face.width + width * 2) * fraction
-        let beam = NSRect(x: x, y: face.minY, width: width, height: face.height)
-        NSGradient(colors: [.clear, accent.withAlphaComponent(0.22 * intensity), .clear])?
-            .draw(in: HomeDashboardStyle.slant(beam), angle: 0)
+        NSBezierPath(rect: seam).addClip()
+        NSGradient(colors: [.clear, accent.withAlphaComponent(0.84 * intensity), .clear])?
+            .draw(in: NSRect(x: center - beamWidth / 2, y: seam.minY, width: beamWidth, height: seam.height), angle: 0)
         NSGraphicsContext.restoreGraphicsState()
     }
 
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index ace19860d1b62f29a2ae76bcdac851ca656ca6d9..996aa7a94b3eb362a1cddfa833a35bfbcec8888e 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -338,7 +338,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         try export(home, name: "lobby-finished")
     }
 
-    func testChallengePreviewGrowsWithinScreenForOneSecondAndKeepsItsProgressOnRoundStart() throws {
+    func testStatisticsPlatesAssembleInPlaceAndKeepProgressAcrossRefreshes() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
@@ -360,92 +360,111 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         home.layoutSubtreeIfNeeded()
         let intro = try modeIntro(in: header)
         let introFrame = intro.frame
-        let outgoing = home.challengeHUD
-        let restingX = outgoing.frame.minX
-        let restingWidth = outgoing.frame.width
-        let restingSurfaceY = outgoing.convert(outgoing.surfaceRect, to: home).minY
-        home.refresh(snapshot: timed, mode: .timed, manager: manager)
         let preview = home.challengeHUD
-        XCTAssertGreaterThan(preview.frame.minX, restingX)
-        XCTAssertLessThanOrEqual(preview.frame.maxX, home.modePanel.frame.minX - 5.9)
-        XCTAssertEqual(preview.frame.width, restingWidth * 0.28, accuracy: 0.1)
-        XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
-                       accuracy: 0.001, "卡面起始帧须保持原有斜边角度")
-        try assertLaunchIsWithinScreen(preview, in: window)
-        XCTAssertEqual(preview.alphaValue, 0)
+        let restingSurface = preview.convert(preview.surfaceRect, to: home)
+        XCTAssertEqual(preview.plateAssembly, .settled)
+        home.refresh(snapshot: timed, mode: .timed, manager: manager)
+        XCTAssertTrue(home.challengeHUD === preview, "模式切换复用同一张统计卡")
+        XCTAssertEqual(preview.plateAssembly, .separated)
+        XCTAssertEqual(preview.backingPlateOffset.x, -24, accuracy: 0.1)
+        XCTAssertEqual(preview.backingPlateOffset.y, -26, accuracy: 0.1)
+        XCTAssertEqual(preview.frontPlateOffset.x, 8, accuracy: 0.1)
+        XCTAssertEqual(preview.frontPlateOffset.y, 24, accuracy: 0.1)
 
         let steps = 25
-        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-challenge-preview.gif")
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-statistics-plate-assembly.gif")
         let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, steps + 1, nil))
         CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
         let duration = HomeModeHeaderView.previewDuration
-        XCTAssertEqual(duration, 1)
-        var previousWidth = preview.frame.width
+        XCTAssertEqual(duration, 0.70, accuracy: 0.001)
+        var previous = preview.plateAssembly
         for step in 0...steps {
             clock = 100 + duration * Double(step) / Double(steps)
             header.advanceAnimation()
-            XCTAssertGreaterThanOrEqual(preview.frame.width + 0.1, previousWidth)
-            XCTAssertLessThan(preview.frame.maxX, home.modePanel.frame.minX, "统计卡完整位于右栏左侧")
-            XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
-                           accuracy: 0.001, "入场每帧都须等比缩放")
-            previousWidth = preview.frame.width
-            if step == steps / 2 {
-                let position = preview.frame.minX
-                XCTAssertGreaterThan(position, restingX)
-                XCTAssertGreaterThan(preview.alphaValue, 0.2)
+            home.layoutSubtreeIfNeeded()
+            let assembly = preview.plateAssembly
+            XCTAssertGreaterThanOrEqual(assembly.backing, previous.backing)
+            XCTAssertGreaterThanOrEqual(assembly.front, previous.front)
+            previous = assembly
+            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home), restingSurface, "两层移动时保留牌面的基准位置和尺寸")
+            XCTAssertEqual(intro.frame, introFrame, "模式切换保留标题位置")
+            assertStatisticsPlatesLeftOfModes(home, preview: preview)
+
+            switch step {
+            case 2:
+                XCTAssertGreaterThan(assembly.backing, 0)
+                XCTAssertEqual(assembly.front, 0, accuracy: 0.001, "前板延后启动")
+            case 4:
+                XCTAssertLessThan(preview.backingPlateOffset.y, -1)
+                XCTAssertGreaterThan(preview.frontPlateOffset.y, 1)
+                try assertAssemblingPlatesAreVisible(home, preview: preview)
+            case 12:
+                XCTAssertGreaterThan(assembly.front, 0)
+                XCTAssertLessThan(assembly.front, 1)
                 home.refresh(snapshot: timed, mode: .timed, manager: manager)
                 home.layoutSubtreeIfNeeded()
-                XCTAssertEqual(preview.frame.minX, position, accuracy: 1, "重复刷新不能重启动画")
+                XCTAssertEqual(preview.plateAssembly, assembly, "重复刷新保留统计卡组装进度")
+            case 16:
+                XCTAssertEqual(assembly.backing, 1, accuracy: 0.001)
+                XCTAssertEqual(preview.backingPlateOffset, .zero)
+                XCTAssertLessThan(assembly.front, 1, "背板先于前板到位")
+                XCTAssertEqual(assembly.highlight, 0, accuracy: 0.001)
+            case 22:
+                XCTAssertEqual(assembly.front, 1, accuracy: 0.001)
+                XCTAssertEqual(preview.frontPlateOffset, .zero)
+                XCTAssertGreaterThan(assembly.highlight, 0, "两层合拢后才播放高光")
+                XCTAssertLessThan(assembly.highlight, 1)
+            default:
+                break
             }
-            if step == 3 { try assertPreviewLayersAreVisible(home, preview: preview) }
-            XCTAssertEqual(intro.frame, introFrame, "切换统计卡时保留标题的位置")
-            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, restingSurfaceY, accuracy: 0.1)
-            home.layoutSubtreeIfNeeded()
             let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
             home.cacheDisplay(in: header.frame, to: pixels)
             let frame = try XCTUnwrap(pixels.cgImage)
-            if step == 3 || step == steps * 3 / 4 {
-                let name = step == 3 ? "eliminate-challenge-preview-entry.png" : "eliminate-challenge-preview-motion.png"
-                try XCTUnwrap(pixels.representation(using: .png, properties: [:]))
-                    .write(to: url.deletingLastPathComponent().appendingPathComponent(name))
-            }
             let delay = step == steps ? 1.0 : duration / Double(steps)
             CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
         }
         XCTAssertTrue(CGImageDestinationFinalize(gif))
-        XCTAssertEqual(preview.frame.minX, restingX, accuracy: 1)
-        XCTAssertEqual(preview.frame.width, restingWidth, accuracy: 0.1)
-        XCTAssertEqual(preview.alphaValue, 1)
-        XCTAssertTrue(outgoing.isHidden)
+        XCTAssertEqual(preview.plateAssembly, .settled)
+        XCTAssertEqual(preview.backingPlateOffset, .zero)
+        XCTAssertEqual(preview.frontPlateOffset, .zero)
         XCTAssertFalse(intro.isHidden)
 
         home.refresh(snapshot: moves, mode: .moves, manager: manager)
-        XCTAssertEqual(home.challengeHUD.budgetText, "30")
-        XCTAssertEqual(preview.mode, .timed, "离场卡保留原规则")
-        clock += 0.12
+        XCTAssertEqual(preview.mode, .moves)
+        XCTAssertEqual(preview.budgetText, "30")
+        XCTAssertEqual(preview.plateAssembly, .separated)
+        clock += duration * 0.32
         header.advanceAnimation()
-        let reversingFrame = preview.frame
+        let assemblyDuringEntry = preview.plateAssembly
+        XCTAssertGreaterThan(assemblyDuringEntry.front, 0)
+        XCTAssertLessThan(assemblyDuringEntry.front, 1)
         home.refresh(snapshot: timed, mode: .timed, manager: manager)
-        XCTAssertEqual(home.challengeHUD.frame.minX, reversingFrame.minX, accuracy: 0.1, "反向切换从离场卡当前位置继续")
-        XCTAssertEqual(home.challengeHUD.frame.width, reversingFrame.width, accuracy: 0.1)
+        XCTAssertEqual(preview.mode, .timed)
+        XCTAssertEqual(preview.plateAssembly, assemblyDuringEntry, "快速切回保留两层的当前进度")
         home.refresh(snapshot: moves, mode: .moves, manager: manager)
-        home.setFrameSize(NSSize(width: 960, height: 720))
+        window.setContentSize(NSSize(width: 960, height: 720))
         home.layoutSubtreeIfNeeded()
-        XCTAssertLessThan(max(home.challengeHUD.frame.maxX, preview.frame.maxX), home.modePanel.frame.minX)
-        clock += 0.7
+        XCTAssertEqual(home.bounds.width, 960, accuracy: 0.1)
+        XCTAssertEqual(preview.plateAssembly, assemblyDuringEntry)
+        assertStatisticsPlatesLeftOfModes(home, preview: preview)
+        clock += duration * 0.08
         header.advanceAnimation()
-        let frameDuringEntry = home.challengeHUD.frame
+        let assemblyAfterResize = preview.plateAssembly
+        XCTAssertGreaterThan(assemblyAfterResize.front, assemblyDuringEntry.front)
+        assertStatisticsPlatesLeftOfModes(home, preview: preview)
         let playing = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 1, remainingTime: nil, remainingSwaps: 29, isRunning: true, isFinished: false)
         home.refresh(snapshot: playing, mode: .moves, manager: manager)
-        XCTAssertEqual(home.challengeHUD.frame, frameDuringEntry)
-        XCTAssertEqual(home.challengeHUD.budgetText, "29")
+        XCTAssertEqual(preview.plateAssembly, assemblyAfterResize, "开局更新数字时继续组装")
+        XCTAssertEqual(preview.budgetText, "29")
         reduceMotion = true
         header.advanceAnimation()
-        XCTAssertLessThan(home.challengeHUD.frame.maxX, home.modePanel.frame.minX)
-        XCTAssertEqual(home.challengeHUD.alphaValue, 1)
-        XCTAssertTrue(preview.isHidden)
+        XCTAssertEqual(preview.plateAssembly, .settled)
+        XCTAssertEqual(preview.backingPlateOffset, .zero)
+        XCTAssertEqual(preview.frontPlateOffset, .zero)
         home.refresh(snapshot: free, mode: .free, manager: manager)
-        XCTAssertFalse(home.challengeHUD.isHidden)
+        XCTAssertTrue(home.challengeHUD === preview)
+        XCTAssertEqual(preview.plateAssembly, .settled)
+        XCTAssertFalse(preview.isHidden)
         XCTAssertFalse(intro.isHidden)
     }
 
@@ -495,20 +514,23 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         }
     }
 
-    private func assertLaunchIsWithinScreen(_ preview: HomeChallengeHUDView, in window: NSWindow) throws {
-        XCTAssertLessThanOrEqual(preview.frame.maxX, try XCTUnwrap(preview.superview).bounds.maxX + 0.1)
-        if let screen = window.screen {
-            let right = preview.convert(preview.bounds, to: nil).maxX
-            let launchRight = window.convertPoint(toScreen: NSPoint(x: right, y: 0)).x
-            XCTAssertLessThanOrEqual(launchRight, screen.frame.maxX + 0.1)
+    private func assertStatisticsPlatesLeftOfModes(_ home: HomeDashboardView, preview: HomeChallengeHUDView,
+                                                   file: StaticString = #filePath, line: UInt = #line) {
+        for offset in [preview.backingPlateOffset, preview.frontPlateOffset] {
+            let shifted = preview.surfaceRect.offsetBy(dx: offset.x, dy: offset.y)
+            XCTAssertTrue(preview.bounds.contains(shifted), "绘制范围为移动中的板面留足空间", file: file, line: line)
+            let surface = preview.convert(shifted, to: home)
+            XCTAssertLessThan(surface.maxX, home.modePanel.frame.minX, "移动中的板面与右栏保留间隔", file: file, line: line)
         }
     }
 
-    private func assertPreviewLayersAreVisible(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
+    private func assertAssemblingPlatesAreVisible(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
         let budget = try XCTUnwrap(preview.budgetTrackRect)
         let cell = try XCTUnwrap(preview.breakdownCellRects.last)
-        let budgetPoint = preview.convert(NSPoint(x: budget.maxX - budget.width * 0.2, y: budget.midY), to: home)
-        let cellPoint = preview.convert(NSPoint(x: cell.midX, y: cell.midY), to: home)
+        let budgetPoint = preview.convert(NSPoint(x: budget.midX + preview.backingPlateOffset.x,
+                                                y: budget.midY + preview.backingPlateOffset.y), to: home)
+        let cellPoint = preview.convert(NSPoint(x: cell.midX + preview.frontPlateOffset.x,
+                                              y: cell.midY + preview.frontPlateOffset.y), to: home)
 
         func color(at point: NSPoint) throws -> NSColor {
             let rect = NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
@@ -524,8 +546,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let visibleCell = try color(at: cellPoint)
         preview.isHidden = true
         defer { preview.isHidden = false }
-        XCTAssertGreaterThan(difference(visibleBudget, try color(at: budgetPoint)), 0.06, "入场前段的进度背板应当可见")
-        XCTAssertGreaterThan(difference(visibleCell, try color(at: cellPoint)), 0.012, "入场前段的右侧分类格应当可见")
+        XCTAssertGreaterThan(difference(visibleBudget, try color(at: budgetPoint)), 0.06, "组装时移动后的进度轨道可见")
+        XCTAssertGreaterThan(difference(visibleCell, try color(at: cellPoint)), 0.012, "组装时移动后的末尾分类格可见")
     }
 
     func testModeArtworkKeepsTransparencyAndIdentityAtSmallAndWideSizes() throws {
```
