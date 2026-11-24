# 首页触控栏循环演示

## 背景与目标

- 将首页的静态触控栏示意改为自动循环演示。
- 每轮先显示蓝色滑动方向和竖直食指，再演示相邻方块交换、三连消除和左侧补位。

## 实现与约束

- `HomeTouchBarDemo` 使用独立的 `GameState`（游戏状态）预演三个相连的局面。第三轮补位后的排列能直接接回首轮。消除时高亮本次成组的方块，补位按原有方块身份保持顺序。
- `HomeTouchBarGuideView` 负责演示时钟。窗口隐藏或最小化时暂停推进，启用 macOS 的“减少动态效果”时显示静态棋盘和手势。
- `HomeLobbyArtwork` 沿用斜边轨道和方块绘制，把补位方块及消除光效裁剪在轨道内。手指以指尖为定位点，随手势平移，全程竖直。
- 演示与真实棋盘、挑战计数、成就及存档独立。

## 验证

- 完整 SwiftPM 测试共 95 项全部通过。新增 4 项覆盖每轮手势与交换顺序、真实三连消除、左侧补位和幸存方块顺序、循环接缝、减少动态效果及原生画面差异。
- 原生渲染导出 128 帧 GIF。抽查手势起止、换位交叉、消除高亮与淡出、左侧补位画面，并核对完整首页里的手指与说明文字间距。
- 手动验证可运行 `./run.sh`，在首页等候约 11 秒观看一轮完整循环，再打开系统“减少动态效果”验证静态状态。

## 代码变更

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 4b60e8a0cf604c0b3649fd7d49ef8ec412cdecac..2dac6ddc6829e30494a21f09fa251e2e10065f90 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261124091725-animate-home-touch-bar-guide.md` - 会话-27 起将首页触控栏示意改为循环演示，包含竖直手指、蓝色滑动提示、相邻交换、三连消除和左侧补位。
 `workflow/20261124003148-move-challenge-budget-into-hud-header.md` - 会话-22 起移除统计卡顶部规则文案，自由模式留空，限时和限步把进度条移至顶部并沿斜边等距。
 `workflow/20261123231057-split-popup-lists-into-row-cards.md` - 会话-16 至会话-18 将挑战记录、旧规则记录和玩法教学按条目拆为独立斜边卡，记录表头和数据保持列对齐。
 `workflow/20261123215822-restore-popup-parallelogram-borders.md` - 会话-12 至会话-15 恢复辅助弹窗卡片的整条斜边，逐行给文案和表格留白。含宽窄原生渲染与本轮增量 diff。
@@ -103,6 +104,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整首页触控栏演示的手势、交换、消除、补位、循环节奏或减少动态效果时，读取 `20261124091725-animate-home-touch-bar-guide.md`。
 - 需要调整统计卡顶部的预算轨道、左右等距留白、自由模式标题区域或限时限步预算显示时，读取 `20261124003148-move-challenge-budget-into-hud-header.md`。
 - 需要调整弹窗逐行卡片、记录表头与列宽、历史记录分组或教学卡片间距时，读取 `20261123231057-split-popup-lists-into-row-cards.md`。
 - 需要调整玩法、设置、挑战记录或成就弹窗的完整平行四边形和内部行布局时，读取 `20261123215822-restore-popup-parallelogram-borders.md`。
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index c527472cdc477a3c7bf59e3908d06c7a09529c70..91ad2e6644b8c6c2b91e75f948f1acb7ac72a167 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -209,6 +209,11 @@ final class HomeHeroView: NSView {
 }
 
 private final class HomeTouchBarGuideView: NSView {
+    private var timer: Timer?
+    private var elapsed: TimeInterval = 0
+    private var lastTick: TimeInterval = 0
+    private var reducesMotion = false
+
     override var isFlipped: Bool { true }
 
     override init(frame: NSRect) {
@@ -219,9 +224,46 @@ private final class HomeTouchBarGuideView: NSView {
 
     required init?(coder: NSCoder) { nil }
 
+    deinit { timer?.invalidate() }
+
+    override func viewDidMoveToWindow() {
+        super.viewDidMoveToWindow()
+        timer?.invalidate()
+        timer = nil
+        guard window != nil else { return }
+
+        elapsed = 0
+        lastTick = ProcessInfo.processInfo.systemUptime
+        reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
+        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
+            self?.advanceDemo()
+        }
+        timer.tolerance = 0.005
+        RunLoop.main.add(timer, forMode: .common)
+        self.timer = timer
+        needsDisplay = true
+    }
+
+    private func advanceDemo() {
+        let now = ProcessInfo.processInfo.systemUptime
+        let interval = now - lastTick
+        lastTick = now
+        guard let window, window.isVisible, !window.isMiniaturized, !isHiddenOrHasHiddenAncestor else { return }
+
+        let previous = reducesMotion
+        reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
+        if !reducesMotion {
+            // 窗口隐藏或系统休眠后保留当前阶段，避免恢复时直接跳到补位。
+            elapsed = (elapsed + min(interval, 0.1)).truncatingRemainder(dividingBy: HomeTouchBarDemo.loopDuration)
+        }
+        if !reducesMotion || previous != reducesMotion { needsDisplay = true }
+    }
+
     override func draw(_ dirtyRect: NSRect) {
-        HomeLobbyArtwork.drawTouchBar(in: bounds)
-        let scale = min(bounds.width / 925, bounds.height / 112)
+        let frame = HomeTouchBarDemo.frame(at: elapsed, animated: window != nil && !reducesMotion)
+        HomeLobbyArtwork.drawTouchBar(in: bounds, frame: frame)
+        let canvas = HomeLobbyArtwork.touchBarCanvasSize
+        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
         let size = min(19, max(12, scale * 19))
         let caption = AchievementText.string("home.operation_hint")
         let width = min(bounds.width * 0.63, (caption as NSString).size(withAttributes: [
diff --git a/Sources/HomeLobbyArtwork.swift b/Sources/HomeLobbyArtwork.swift
index 0af5a950cc1c28f11b5eab0cf89a2eb8aba6f26d..a6967630108b4370e3418c49fc25eb14ec8558b0 100644
--- a/Sources/HomeLobbyArtwork.swift
+++ b/Sources/HomeLobbyArtwork.swift
@@ -1,7 +1,9 @@
 import Cocoa
 
-/// 大厅的方块与触控栏教学图，使用矢量绘制以适应不同窗口和显示倍率。
+/// 大厅的方块与触控栏演示，使用矢量绘制以适应不同窗口和显示倍率。
 enum HomeLobbyArtwork {
+    static let touchBarCanvasSize = NSSize(width: 925, height: 112)
+
     private struct PiecePalette {
         let face: NSColor
         let light: NSColor
@@ -32,12 +34,16 @@ enum HomeLobbyArtwork {
 
     /// 绘制与大厅插画一致的方块，保持原始长宽比。
     static func drawPiece(_ kind: PieceKind, in bounds: NSRect) {
-        guard let image = pieces[kind], bounds.width > 0, bounds.height > 0 else { return }
+        drawPiece(kind, in: bounds, opacity: 1)
+    }
+
+    private static func drawPiece(_ kind: PieceKind, in bounds: NSRect, opacity: CGFloat) {
+        guard let image = pieces[kind], bounds.width > 0, bounds.height > 0, opacity > 0 else { return }
         let scale = min(bounds.width / pieceSize.width, bounds.height / pieceSize.height)
         let width = pieceSize.width * scale
         let height = pieceSize.height * scale
         let rect = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
-        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
+        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity,
                    respectFlipped: true, hints: nil)
     }
 
@@ -93,8 +99,8 @@ enum HomeLobbyArtwork {
         arrow.stroke()
     }
 
-    static func drawTouchBar(in bounds: NSRect) {
-        let canvas = NSSize(width: 925, height: 112)
+    static func drawTouchBar(in bounds: NSRect, frame: HomeTouchBarDemo.Frame) {
+        let canvas = touchBarCanvasSize
         let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
         guard scale > 0 else { return }
         NSGraphicsContext.saveGraphicsState()
@@ -104,37 +110,75 @@ enum HomeLobbyArtwork {
         transform.scale(by: scale)
         transform.concat()
 
-        let rail = HomeDashboardStyle.slant(NSRect(x: 1, y: 1, width: 923, height: 67))
+        let rail = HomeDashboardStyle.slant(NSRect(x: 1, y: 1, width: canvas.width - 2, height: 67))
         gradient(rail, from: color(0x040B10), to: color(0x10202A),
                  start: NSPoint(x: 0, y: 0), end: NSPoint(x: 15, y: 68))
+
+        // 裁剪从左侧生成的方块和消除光效，手势的手腕可延伸到轨道之外。
+        let cyan = color(0x28E8FA)
+        let fingertipX = frame.gesture.map { gesture in
+            let column = CGFloat(gesture.from) + CGFloat(gesture.to - gesture.from) * gesture.progress
+            return touchBarX(for: column)
+        }
+        NSGraphicsContext.saveGraphicsState()
+        rail.addClip()
+        if let gesture = frame.gesture, let fingertipX {
+            drawSwipeHint(for: gesture, fingertipX: fingertipX, tint: cyan)
+        }
+        for tile in frame.tiles {
+            let x = touchBarX(for: tile.column)
+            let y = 31 - tile.lift
+            let rect = NSRect(x: x - 24 * tile.scale, y: y - 17 * tile.scale,
+                              width: 48 * tile.scale, height: 34 * tile.scale)
+            if tile.highlight > 0, let palette = palettes[tile.kind] {
+                let halo = NSRect(x: x - 44, y: y - 32, width: 88, height: 64)
+                glow(halo, color: palette.light.withAlphaComponent(0.8 * tile.highlight))
+            }
+            drawPiece(tile.kind, in: rect, opacity: tile.opacity)
+        }
+        NSGraphicsContext.restoreGraphicsState()
+
         color(0xB7D3DA, alpha: 0.7).setStroke()
         rail.lineWidth = 1.2
         rail.stroke()
-
-        let cyan = color(0x28E8FA)
-        glow(NSRect(x: 561, y: 37, width: 190, height: 50), color: cyan.withAlphaComponent(0.40))
-        glow(NSRect(x: 634, y: 7, width: 88, height: 58), color: color(0x235CFF, alpha: 0.74))
-        let kinds: [PieceKind] = [.orangeRicky, .blueRicky, .clevelandZ, .rhodeIslandZ]
-        for index in 0..<13 {
-            drawPiece(kinds[index % kinds.count], in: NSRect(x: 56 + CGFloat(index) * 65.5, y: 14, width: 48, height: 34))
+        if let gesture = frame.gesture, let fingertipX {
+            drawHand(at: NSPoint(x: fingertipX, y: 45 + gesture.lift), tint: cyan, opacity: gesture.opacity)
         }
+    }
+
+    private static func touchBarX(for column: CGFloat) -> CGFloat {
+        80 + column * 65.5
+    }
+
+    private static func drawSwipeHint(for gesture: HomeTouchBarDemo.Gesture, fingertipX: CGFloat, tint: NSColor) {
+        let direction: CGFloat = gesture.to < gesture.from ? -1 : 1
+        let fromX = touchBarX(for: CGFloat(gesture.from))
+        let toX = touchBarX(for: CGFloat(gesture.to))
+        let midpoint = (fromX + toX) / 2
+        let opacity = gesture.opacity
+        glow(NSRect(x: midpoint - 80, y: 41, width: 160, height: 50), color: tint.withAlphaComponent(0.4 * opacity))
+        glow(NSRect(x: fingertipX - 44, y: 7, width: 88, height: 58), color: color(0x235CFF, alpha: 0.74 * opacity))
+
+        // 箭头跟随滑动方向，依次提亮以预告手指即将移动的路径。
         for index in 0..<3 {
-            let x = 617 + CGFloat(index) * 15.5
+            let x = midpoint + direction * (CGFloat(index - 1) * 15.5 + 8 * (gesture.progress - 0.5))
+            let emphasis = 1 - abs(gesture.progress - (CGFloat(index) + 0.5) / 3)
             let chevron = NSBezierPath()
-            chevron.move(to: NSPoint(x: x, y: 42))
-            chevron.line(to: NSPoint(x: x + 8, y: 49))
-            chevron.line(to: NSPoint(x: x, y: 56))
-            cyan.withAlphaComponent(0.72 + CGFloat(index) * 0.12).setStroke()
+            chevron.move(to: NSPoint(x: x - direction * 4, y: 46))
+            chevron.line(to: NSPoint(x: x + direction * 4, y: 53))
+            chevron.line(to: NSPoint(x: x - direction * 4, y: 60))
+            tint.withAlphaComponent((0.42 + 0.58 * emphasis) * opacity).setStroke()
             chevron.lineWidth = 3
+            chevron.lineCapStyle = .round
+            chevron.lineJoinStyle = .round
             chevron.stroke()
         }
         let swipe = NSBezierPath()
-        swipe.move(to: NSPoint(x: 585, y: 65))
-        swipe.line(to: NSPoint(x: 697, y: 65))
-        cyan.withAlphaComponent(0.63).setStroke()
+        swipe.move(to: NSPoint(x: min(fromX, toX) - 16, y: 65))
+        swipe.line(to: NSPoint(x: max(fromX, toX) + 16, y: 65))
+        tint.withAlphaComponent(0.63 * opacity).setStroke()
         swipe.lineWidth = 1
         swipe.stroke()
-        drawHand(at: NSPoint(x: 671, y: 46), tint: cyan)
     }
 
     private static func drawCell(in rect: NSRect, palette: PiecePalette) {
@@ -182,34 +226,36 @@ enum HomeLobbyArtwork {
         }
     }
 
-    private static func drawHand(at origin: NSPoint, tint: NSColor) {
+    private static func drawHand(at origin: NSPoint, tint: NSColor, opacity: CGFloat) {
         func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x, y: origin.y + y) }
         let hand = NSBezierPath()
-        hand.move(to: point(24, 62))
-        hand.curve(to: point(17, 55), controlPoint1: point(22, 59), controlPoint2: point(21, 57))
-        hand.curve(to: point(5, 40), controlPoint1: point(13, 53), controlPoint2: point(8, 45))
-        hand.curve(to: point(10, 33), controlPoint1: point(0, 34), controlPoint2: point(5, 29))
-        hand.line(to: point(15, 39))
-        hand.line(to: point(6, 9))
-        hand.curve(to: point(14, 5), controlPoint1: point(4, 2), controlPoint2: point(12, 0))
-        hand.line(to: point(21, 30))
-        hand.curve(to: point(29, 27), controlPoint1: point(20, 23), controlPoint2: point(27, 21))
-        hand.line(to: point(31, 33))
-        hand.curve(to: point(39, 31), controlPoint1: point(30, 26), controlPoint2: point(37, 25))
-        hand.line(to: point(41, 36))
-        hand.curve(to: point(47, 35), controlPoint1: point(41, 30), controlPoint2: point(45, 30))
-        hand.curve(to: point(48, 51), controlPoint1: point(50, 40), controlPoint2: point(50, 46))
-        hand.curve(to: point(49, 61), controlPoint1: point(47, 56), controlPoint2: point(48, 59))
+        hand.move(to: point(8, 53))
+        hand.curve(to: point(2, 46), controlPoint1: point(7, 50), controlPoint2: point(5, 48))
+        hand.curve(to: point(-12, 34), controlPoint1: point(-3, 43), controlPoint2: point(-9, 39))
+        hand.curve(to: point(-7, 28), controlPoint1: point(-15, 29), controlPoint2: point(-11, 26))
+        hand.line(to: point(-4.5, 32))
+        // 指尖固定在原点，竖直食指随手势整体平移，始终对准方块列的中心。
+        hand.line(to: point(-4.5, 5))
+        hand.curve(to: point(0, 0), controlPoint1: point(-4.5, 2), controlPoint2: point(-2.5, 0))
+        hand.curve(to: point(4.5, 5), controlPoint1: point(2.5, 0), controlPoint2: point(4.5, 2))
+        hand.line(to: point(4.5, 25))
+        hand.curve(to: point(13.5, 25), controlPoint1: point(4.5, 19), controlPoint2: point(13.5, 19))
+        hand.line(to: point(13.5, 28))
+        hand.curve(to: point(22.5, 28), controlPoint1: point(13.5, 22), controlPoint2: point(22.5, 22))
+        hand.line(to: point(22.5, 31))
+        hand.curve(to: point(31, 31), controlPoint1: point(22.5, 25), controlPoint2: point(30, 26))
+        hand.curve(to: point(32, 43), controlPoint1: point(32, 35), controlPoint2: point(33, 39))
+        hand.curve(to: point(28, 53), controlPoint1: point(31, 48), controlPoint2: point(28, 49))
         // 底端敞开；填充先封闭内部，白色描边在手腕两侧自然结束。
-        color(0x091722, alpha: 0.91).setFill()
+        color(0x091722, alpha: 0.91 * opacity).setFill()
         hand.fill()
         NSGraphicsContext.saveGraphicsState()
         let glow = NSShadow()
-        glow.shadowColor = tint.withAlphaComponent(0.55)
+        glow.shadowColor = tint.withAlphaComponent(0.55 * opacity)
         glow.shadowBlurRadius = 7
         glow.shadowOffset = .zero
         glow.set()
-        color(0xEAF9FE).setStroke()
+        color(0xEAF9FE, alpha: opacity).setStroke()
         hand.lineWidth = 2.35
         hand.lineCapStyle = .round
         hand.lineJoinStyle = .round
diff --git a/Sources/HomeTouchBarDemo.swift b/Sources/HomeTouchBarDemo.swift
new file mode 100644
index 0000000000000000000000000000000000000000..bf20257e7c9389e4236c1c276230bcfc837b6d6d
--- /dev/null
+++ b/Sources/HomeTouchBarDemo.swift
@@ -0,0 +1,143 @@
+import Foundation
+
+/// 首页教学使用独立棋盘预演交换、消除和左侧补位。
+enum HomeTouchBarDemo {
+    struct Tile: Equatable {
+        let kind: PieceKind
+        let column: CGFloat
+        var lift: CGFloat = 0
+        var opacity: CGFloat = 1
+        var scale: CGFloat = 1
+        var highlight: CGFloat = 0
+    }
+
+    struct Gesture: Equatable {
+        let from: Int
+        let to: Int
+        let progress: CGFloat
+        let opacity: CGFloat
+        let lift: CGFloat
+    }
+
+    struct Frame: Equatable {
+        let tiles: [Tile]
+        var gesture: Gesture? = nil
+    }
+
+    private struct Step {
+        let from: Int
+        let to: Int
+        let before: [BoardTile]
+        let swapped: [BoardTile]
+        let after: [BoardTile]
+        let cleared: Set<Int>
+        let refillOrigins: [Int?]
+    }
+
+    static let columnCount = 13
+    private static let gestureStart = 0.55
+    private static let swapStart = 1.75
+    private static let clearStart = 2.11
+    private static let refillStart = 2.84
+    static let stepDuration = 3.55
+    static var stepCount: Int { steps.count }
+    static var loopDuration: TimeInterval { stepDuration * Double(stepCount) }
+
+    private static let steps: [Step] = {
+        let orange = PieceKind.orangeRicky
+        let blue = PieceKind.blueRicky
+        let green = PieceKind.clevelandZ
+        let red = PieceKind.rhodeIslandZ
+        let initial = [orange, blue, green, green, blue, blue, orange, orange, green, orange, blue, blue, red]
+        // 三次左侧补位之后回到初始排列，循环接缝处无需重置画面。
+        let script = [
+            (from: 9, to: 8, incoming: [orange, orange, green]),
+            (from: 8, to: 9, incoming: [green, blue, blue]),
+            (from: 11, to: 10, incoming: [orange, blue, green])
+        ]
+        var incoming = script.flatMap(\.incoming).makeIterator()
+        let board = GameState(columns: columnCount, initialKinds: initial) {
+            incoming.next() ?? PieceKind.random()
+        }
+        return script.map { cue in
+            let before = board.tiles
+            var swapped = before
+            swapped.swapAt(cue.from, cue.to)
+            _ = board.swapAndResolve(cue.from, cue.to)
+            let after = board.tiles
+            let survivorIDs = Set(after.map(\.id))
+            let cleared = Set(swapped.indices.filter { !survivorIDs.contains(swapped[$0].id) })
+            let oldColumns = Dictionary(uniqueKeysWithValues: swapped.enumerated().map { ($0.element.id, $0.offset) })
+            return Step(from: cue.from, to: cue.to, before: before, swapped: swapped, after: after,
+                        cleared: cleared, refillOrigins: after.map { oldColumns[$0.id] })
+        }
+    }()
+
+    static func frame(at elapsed: TimeInterval, animated: Bool = true) -> Frame {
+        guard animated else {
+            let step = steps[0]
+            return Frame(tiles: stationaryTiles(step.before),
+                         gesture: Gesture(from: step.from, to: step.to, progress: 0, opacity: 1, lift: 0))
+        }
+
+        let loopTime = max(0, elapsed).truncatingRemainder(dividingBy: loopDuration)
+        let stepIndex = min(stepCount - 1, Int(loopTime / stepDuration))
+        let step = steps[stepIndex]
+        let time = loopTime - Double(stepIndex) * stepDuration
+
+        switch time {
+        case ..<gestureStart:
+            return Frame(tiles: stationaryTiles(step.before))
+        case ..<swapStart:
+            let phase = CGFloat((time - gestureStart) / (swapStart - gestureStart))
+            let appear = eased(phase / 0.25)
+            let swipe = eased((phase - 0.29) / 0.55)
+            let fade = eased((phase - 0.83) / 0.17)
+            let gesture = Gesture(from: step.from, to: step.to, progress: swipe,
+                                  opacity: appear * (1 - fade), lift: 12 * (1 - appear) + 4 * fade)
+            return Frame(tiles: stationaryTiles(step.before), gesture: gesture)
+        case ..<clearStart:
+            let phase = eased(CGFloat((time - swapStart) / (clearStart - swapStart)))
+            let distance = CGFloat(step.to - step.from) * phase
+            let height = 7 * sin(.pi * phase)
+            let tiles = step.before.enumerated().map { index, tile in
+                switch index {
+                case step.from: return Tile(kind: tile.kind, column: CGFloat(index) + distance, lift: height)
+                case step.to: return Tile(kind: tile.kind, column: CGFloat(index) - distance, lift: -height)
+                default: return Tile(kind: tile.kind, column: CGFloat(index))
+                }
+            }
+            return Frame(tiles: tiles)
+        case ..<refillStart:
+            let phase = CGFloat((time - clearStart) / (refillStart - clearStart))
+            let emphasis = eased(phase / 0.24)
+            let removal = eased((phase - 0.37) / 0.63)
+            let tiles = step.swapped.enumerated().map { index, tile in
+                guard step.cleared.contains(index) else { return Tile(kind: tile.kind, column: CGFloat(index)) }
+                return Tile(kind: tile.kind, column: CGFloat(index), opacity: 1 - removal,
+                            scale: 1 + 0.10 * emphasis - 0.75 * removal, highlight: emphasis * (1 - removal))
+            }
+            return Frame(tiles: tiles)
+        default:
+            let phase = eased(CGFloat((time - refillStart) / (stepDuration - refillStart)))
+            let tiles = step.after.enumerated().map { index, tile in
+                let origin = step.refillOrigins[index]
+                // 原方块向右填补空位，新方块从滑轨左端进入。
+                let start = CGFloat(origin ?? (index - step.cleared.count))
+                let destination = CGFloat(index)
+                return Tile(kind: tile.kind, column: start + (destination - start) * phase,
+                            opacity: origin == nil ? min(1, phase * 2) : 1)
+            }
+            return Frame(tiles: tiles)
+        }
+    }
+
+    private static func stationaryTiles(_ board: [BoardTile]) -> [Tile] {
+        board.enumerated().map { Tile(kind: $0.element.kind, column: CGFloat($0.offset)) }
+    }
+
+    private static func eased(_ progress: CGFloat) -> CGFloat {
+        let value = min(1, max(0, progress))
+        return value * value * (3 - 2 * value)
+    }
+}
diff --git a/Tests/HomeTouchBarDemoTests.swift b/Tests/HomeTouchBarDemoTests.swift
new file mode 100644
index 0000000000000000000000000000000000000000..7b22351b05c3676e814661dde0b3d26b76a318c2
--- /dev/null
+++ b/Tests/HomeTouchBarDemoTests.swift
@@ -0,0 +1,160 @@
+import Cocoa
+import ImageIO
+import XCTest
+@testable import EliminateTeris1
+
+final class HomeTouchBarDemoTests: XCTestCase {
+    func testEachGestureSwapsAdjacentTilesBeforeClearingItsOwnRun() throws {
+        let examples: [(from: Int, to: Int, match: PieceKind)] = [
+            (9, 8, .orangeRicky), (8, 9, .blueRicky), (11, 10, .clevelandZ)
+        ]
+        XCTAssertEqual(HomeTouchBarDemo.stepCount, examples.count)
+        for (step, example) in examples.enumerated() {
+            let start = Double(step) * HomeTouchBarDemo.stepDuration
+            let holding = HomeTouchBarDemo.frame(at: start + 0.25)
+            let initial = settledKinds(in: holding)
+            XCTAssertNil(holding.gesture)
+
+            // 手势期间棋盘保持静止，手指在两格之间移动。
+            let gestureStart = HomeTouchBarDemo.frame(at: start + 0.96)
+            let gestureEnd = HomeTouchBarDemo.frame(at: start + 1.45)
+            XCTAssertEqual(settledKinds(in: gestureStart), initial)
+            XCTAssertEqual(settledKinds(in: gestureEnd), initial)
+            let firstGesture = try XCTUnwrap(gestureStart.gesture)
+            let nextGesture = try XCTUnwrap(gestureEnd.gesture)
+            for gesture in [firstGesture, nextGesture] {
+                XCTAssertEqual(gesture.from, example.from)
+                XCTAssertEqual(gesture.to, example.to)
+                XCTAssertEqual(abs(gesture.from - gesture.to), 1)
+                XCTAssertGreaterThan(gesture.opacity, 0)
+            }
+            XCTAssertGreaterThan(nextGesture.progress, firstGesture.progress)
+
+            let moving = HomeTouchBarDemo.frame(at: start + 1.90)
+            let involved = [example.from, example.to]
+            let lower = CGFloat(min(example.from, example.to))
+            let upper = CGFloat(max(example.from, example.to))
+            let movingPair = moving.tiles.filter { $0.column > lower && $0.column < upper }
+            XCTAssertEqual(movingPair.count, 2)
+            XCTAssertEqual(Set(movingPair.map(\.kind)), Set(involved.map { initial[$0] }))
+            for column in initial.indices where !involved.contains(column) {
+                XCTAssertTrue(moving.tiles.contains { $0.column == CGFloat(column) && $0.kind == initial[column] })
+            }
+
+            var expected = initial
+            expected.swapAt(example.from, example.to)
+            let matched = expected.indices.dropLast(2).filter { index in
+                expected[index] == expected[index + 1] && expected[index] == expected[index + 2]
+            }
+            let matchStart = try XCTUnwrap(matched.first)
+            XCTAssertEqual(matched.count, 1, "交换应恰好形成一个三连")
+            let matchedColumns = (matchStart..<(matchStart + 3)).map { CGFloat($0) }
+            XCTAssertEqual(expected[matchStart], example.match)
+            let highlighted = HomeTouchBarDemo.frame(at: start + 2.31)
+            let settled = highlighted.tiles.sorted { $0.column < $1.column }
+            XCTAssertEqual(settled.map(\.kind), expected)
+            XCTAssertEqual(settled.filter { $0.highlight > 0.05 }.map(\.column), matchedColumns)
+
+            let dissolving = HomeTouchBarDemo.frame(at: start + 2.70)
+            for tile in dissolving.tiles where matchedColumns.contains(tile.column) {
+                XCTAssertLessThan(tile.opacity, 1)
+                XCTAssertLessThan(tile.scale, 1)
+            }
+            XCTAssertEqual(dissolving.tiles.filter { $0.opacity < 1 }.map(\.column).sorted(), matchedColumns)
+            XCTAssertTrue(dissolving.tiles.filter { !matchedColumns.contains($0.column) }.allSatisfy { $0.opacity == 1 })
+        }
+    }
+
+    func testRefillPreservesSurvivorOrderAndLoopReturnsToTheSameBoard() {
+        let loop = HomeTouchBarDemo.loopDuration
+        let duration = HomeTouchBarDemo.stepDuration
+        XCTAssertEqual(loop, Double(HomeTouchBarDemo.stepCount) * duration, accuracy: 0.001)
+        for step in 0..<HomeTouchBarDemo.stepCount {
+            let start = Double(step) * duration
+            let clearing = HomeTouchBarDemo.frame(at: start + 2.31)
+            let survivors = clearing.tiles.filter { $0.highlight < 0.05 }.sorted { $0.column < $1.column }
+            XCTAssertEqual(survivors.count, HomeTouchBarDemo.columnCount - 3)
+            let refilling = HomeTouchBarDemo.frame(at: start + 2.96).tiles.sorted { $0.column < $1.column }
+            XCTAssertEqual(refilling.count, HomeTouchBarDemo.columnCount)
+            XCTAssertTrue(refilling.prefix(3).allSatisfy { $0.column < 0 }, "三个补位方块应从左边进入")
+            let remaining = Array(refilling.dropFirst(3))
+            XCTAssertEqual(remaining.map(\.kind), survivors.map(\.kind))
+            XCTAssertTrue(zip(remaining, survivors).contains { moved, original in moved.column > original.column })
+            for (index, pair) in zip(remaining, survivors).enumerated() {
+                let (moved, original) = pair
+                XCTAssertGreaterThanOrEqual(moved.column, original.column)
+                XCTAssertLessThanOrEqual(moved.column, CGFloat(index + 3))
+            }
+
+            let beforeNextStep = HomeTouchBarDemo.frame(at: start + duration - 0.0001)
+            let next = HomeTouchBarDemo.frame(at: start + duration + 0.10)
+            let finalTiles = beforeNextStep.tiles.sorted { $0.column < $1.column }
+            let nextKinds = settledKinds(in: next)
+            XCTAssertEqual(finalTiles.map(\.kind), nextKinds)
+            XCTAssertEqual(Array(nextKinds.dropFirst(3)), survivors.map(\.kind))
+            for (column, tile) in finalTiles.enumerated() {
+                XCTAssertEqual(tile.column, CGFloat(column), accuracy: 0.01)
+                XCTAssertEqual(tile.opacity, 1, accuracy: 0.01)
+            }
+        }
+        XCTAssertEqual(HomeTouchBarDemo.frame(at: loop), HomeTouchBarDemo.frame(at: 0))
+    }
+
+    func testReducedMotionKeepsBoardAndGestureStationary() throws {
+        let still = HomeTouchBarDemo.frame(at: 0, animated: false)
+        XCTAssertEqual(settledKinds(in: still), settledKinds(in: HomeTouchBarDemo.frame(at: 0)))
+        let gesture = try XCTUnwrap(still.gesture)
+        XCTAssertGreaterThan(gesture.opacity, 0)
+        for elapsed in [0.9, 1.9, 2.7, 3.1, HomeTouchBarDemo.loopDuration - 0.01, HomeTouchBarDemo.loopDuration * 2] {
+            XCTAssertEqual(HomeTouchBarDemo.frame(at: elapsed, animated: false), still)
+        }
+    }
+
+    func testExportTouchBarDemoLoop() throws {
+        _ = NSApplication.shared
+        let view = TouchBarDemoPreview(frame: NSRect(x: 0, y: 0, width: 925, height: 112))
+        let count = Int(ceil(HomeTouchBarDemo.loopDuration * 12))
+        let delay = HomeTouchBarDemo.loopDuration / Double(count)
+        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touch-bar-demo-loop.gif")
+        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, count, nil))
+        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        let timing = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
+        let sampleFrames = Set([0.25, 1.16, 1.92, 2.31, 3.12].map { Int(($0 / delay).rounded()) })
+        var sampleImages: Set<Data> = []
+        for index in 0..<count {
+            view.demoFrame = HomeTouchBarDemo.frame(at: Double(index) * delay)
+            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+            view.cacheDisplay(in: view.bounds, to: bitmap)
+            if sampleFrames.contains(index) {
+                sampleImages.insert(try XCTUnwrap(bitmap.representation(using: .png, properties: [:])))
+            }
+            CGImageDestinationAddImage(gif, try XCTUnwrap(bitmap.cgImage), timing)
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(gif))
+        XCTAssertEqual(sampleImages.count, sampleFrames.count, "准备、手势、交换、消除及补位应绘出不同的画面")
+    }
+
+    private func settledKinds(in frame: HomeTouchBarDemo.Frame) -> [PieceKind] {
+        let tiles = frame.tiles.sorted { $0.column < $1.column }
+        XCTAssertEqual(tiles.count, HomeTouchBarDemo.columnCount)
+        for (column, tile) in tiles.enumerated() {
+            XCTAssertEqual(tile.column, CGFloat(column))
+            XCTAssertEqual(tile.opacity, 1)
+            XCTAssertEqual(tile.lift, 0)
+        }
+        return tiles.map(\.kind)
+    }
+}
+
+/// 只在测试中把同一套绘制代码导出为预览。
+private final class TouchBarDemoPreview: NSView {
+    var demoFrame = HomeTouchBarDemo.frame(at: 0) { didSet { needsDisplay = true } }
+
+    override var isFlipped: Bool { true }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeDashboardStyle.navy.setFill()
+        bounds.fill()
+        HomeLobbyArtwork.drawTouchBar(in: bounds, frame: demoFrame)
+    }
+}
```
