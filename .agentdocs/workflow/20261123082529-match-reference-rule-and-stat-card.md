# 对齐设计稿的规则与消除统计卡

## 背景与目标

- 会话-6 至会话-8 调整深色大厅左上方的规则与消除统计卡。上一版把三层内容包在一块同斜率的外框中，位置和尺寸也与设计稿有偏差。
- 以用户提供的 1585 × 992 设计图为坐标基准，保留规则背板、总数前板、四个分类分格之间的错位、叠放和暗缝。
- 使用原生路径重绘面板。当前模式的规则文案与实时计数由本地化文本与 `GameSnapshot` 提供。

## 完成情况

- [x] 在参考画布上将前景面板的布局边界校准至约 x=410–1046、y=123–309，背板左缘在前板旁继续向左下方延伸。
- [x] 将总数卡单独描边，恢复约 y=175 的错层与 y=255 的分格上沿。四张分格之间各有两条边线和暗缝，底部沿用原图的通长边线。
- [x] 按图定位双青色斜标、总数、四种方块图标和分类数字。受限高度下方块仍然左侧对齐，长数字保留全部位数。
- [x] 为统计卡的右上斜角向右收入模式列，右栏联系卡和大厅下部继续按原有尺寸排版。
- [x] 验证窗口缩放、面板转场、五语言及三种游戏规则的回归。

## 测试方法

| 用例 | 操作与预期 |
| --- | --- |
| 参考尺寸 | 在 1585 × 992 点渲染自由模式，核对卡片四边坐标、前板上沿亮差和四张分类卡的三条双边暗缝 |
| 分类定位 | 渲染 336、534、1360 点宽的独立统计卡。检查四种图标位置，以及长数字的完整提示 |
| 大厅与转场 | 在紧凑窗口和全屏尺寸切换三种模式和五种语言，核对统计卡入场中标题的位置、右栏遮挡和开局边界 |
| 全套回归 | 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，涵盖开局、游戏、成就及挑战记录 |

- 最终全套 89 项测试通过，含参考坐标、图标起点、前板边线、分格暗缝与转场的像素回归。
- 手动查看时运行 `./run.sh`，切到自由模式，将大厅缩放至约 1585 × 992 点。检查规则牌与总数牌的叠放以及下方的四个分格。再切换到限时、限步模式，确认预算和本局消除按当前快照显示。

## 代码变更


```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 3ec8c49888c03c8018f1be34dc5945c1dac3bd8d..fc505dd999ac91997073a771193dc4fdefcbd3ac 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261123082529-match-reference-rule-and-stat-card.md` - 会话-6 至会话-8 按参考图坐标还原规则背板、总数前板和四张分类斜卡。含双边暗缝像素回归与本轮增量 diff。
 `workflow/20261123075948-dark-angular-appkit-ui.md` - 会话-2 至会话-5 在 `experiment/ui-refactor-v2` 按设计图重构深色 AppKit 界面，保留「消除俄罗斯方块」名称。含五语言、原生预览验证和完整 diff。
 `workflow/20261122165517-full-width-achievement-row.md` - 会话-207 起恢复跨栏单行成就，并让开始按钮与联系我们卡片底边对齐。含宽窄窗口回归、实际预览与完整 diff。
 `workflow/20261122163532-even-piece-stat-spacing.md` - 会话-205 起将四组方块放在等宽列的同一侧，首组贴齐明细区左边缘，图标保持等距。含不同位数的像素回归、预览与完整 diff。
@@ -98,6 +99,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要核对深色大厅规则与消除统计卡的原图尺寸、层间错位、分格暗缝、长数字或转场遮挡时，读取 `20261123082529-match-reference-rule-and-stat-card.md`。
 - 需要调整深色大厅斜边主题、统计与标题并排、方块及触控栏示意，或核对辅助面板主题和游戏名称时，读取 `20261123075948-dark-angular-appkit-ui.md`。
 - 需要调整当前首页的跨栏成就预览、开始按钮与联系卡的底边或小窗口布局时，读取 `20261122165517-full-width-achievement-row.md`。
 - 需要调整当前方块图标的等距布局，或核对数字位数变化时图标的位置，读取 `20261122163532-even-piece-stat-spacing.md`。
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index c0690c0948d8b3a7371b205542dd88f59953bf44..aab2650788a3f3a005c473211472fba8bd616bb1 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -3,7 +3,41 @@ import Cocoa
 /// 左侧局内面板从同一份快照展示剩余预算、消除总数和四类方块明细。
 final class HomeChallengeHUDView: NSView {
     static let surfaceInsetY: CGFloat = 5
-    var surfaceRect: NSRect { bounds.insetBy(dx: 3, dy: Self.surfaceInsetY) }
+    static let trailingInset: CGFloat = 3
+    private static let rearOverhang: CGFloat = 0.08
+
+    static func leadingInset(for width: CGFloat) -> CGFloat { width * rearOverhang }
+
+    var surfaceRect: NSRect {
+        let width = max(0, (bounds.width - Self.trailingInset) / (1 + Self.rearOverhang))
+        return NSRect(x: Self.leadingInset(for: width), y: Self.surfaceInsetY, width: width,
+                      height: max(0, bounds.height - 2 * Self.surfaceInsetY))
+    }
+
+    /// 设计稿坐标以底部分格左边缘为参考。背板可以越过这个边缘，在前层左侧露出。
+    private struct Face {
+        let frame: NSRect
+        var typographyScale: CGFloat { min(frame.width / 636, frame.height / 186) }
+
+        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
+            NSPoint(x: frame.minX + (x - 410) / 636 * frame.width,
+                    y: frame.minY + (y - 123) / 186 * frame.height)
+        }
+
+        func box(_ x: CGFloat, _ y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
+            let origin = point(x, y)
+            let end = point(x + width, y + height)
+            return NSRect(x: origin.x, y: origin.y, width: end.x - origin.x, height: end.y - origin.y)
+        }
+
+        func path(_ corners: [(CGFloat, CGFloat)]) -> NSBezierPath {
+            let shape = NSBezierPath()
+            shape.move(to: point(corners[0].0, corners[0].1))
+            for (x, y) in corners.dropFirst() { shape.line(to: point(x, y)) }
+            shape.close()
+            return shape
+        }
+    }
     private(set) var snapshot: GameSnapshot?
     private(set) var mode: HomeGameMode = .timed
     var revealFraction: CGFloat? { didSet { if oldValue != revealFraction { needsDisplay = true } } }
@@ -52,72 +86,63 @@ final class HomeChallengeHUDView: NSView {
     private var modeCaption: String {
         let title = AchievementText.string("home.mode.\(mode.key)")
         let description = AchievementText.string("home.mode_desc.\(mode.key)")
-        return title + " · " + description
+        return title + " · " + description.trimmingCharacters(in: CharacterSet(charactersIn: "。."))
     }
 
     override func draw(_ dirtyRect: NSRect) {
         guard let snapshot, surfaceRect.width > 40, surfaceRect.height > 45 else { return }
         let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
         let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
-        let face = surfaceRect
-        let cut = min(face.height * 0.25, face.width * 0.09)
-        let outline = HomeDashboardStyle.slant(face, cut: cut)
+        let face = Face(frame: surfaceRect)
+        let rear = face.path([(455, 123), (1046, 123), (963, 309), (362, 309)])
+        let total = face.path([(472, 175), (1033, 175), (997, 255), (434, 255)])
         if let revealFraction {
             let depth = 1 - revealFraction
-            let side = face.offsetBy(dx: 2.5 * depth, dy: 4.5 * depth)
+            NSGraphicsContext.saveGraphicsState()
+            let offset = NSAffineTransform()
+            offset.translateX(by: 2.5 * depth, yBy: 4.5 * depth)
+            offset.concat()
             accent.withAlphaComponent(0.46 * depth).setFill()
-            HomeDashboardStyle.slant(side, cut: cut).fill()
+            total.fill()
+            NSGraphicsContext.restoreGraphicsState()
         }
 
-        NSGradient(colors: [NSColor(srgbRed: 0.095, green: 0.154, blue: 0.207, alpha: 0.99),
-                            NSColor(srgbRed: 0.058, green: 0.095, blue: 0.130, alpha: 0.99)])?.draw(in: outline, angle: 28)
-        let headerHeight = face.height * 0.28
-        let middleHeight = face.height * 0.43
-        let header = NSRect(x: face.minX, y: face.minY, width: face.width, height: headerHeight)
-        let body = NSRect(x: face.minX, y: header.maxY, width: face.width, height: middleHeight)
-        let breakdown = NSRect(x: face.minX, y: body.maxY, width: face.width, height: face.maxY - body.maxY)
-        NSGraphicsContext.saveGraphicsState()
-        outline.addClip()
-        NSGradient(colors: [NSColor(srgbRed: 0.033, green: 0.061, blue: 0.088, alpha: 1),
-                            NSColor(srgbRed: 0.066, green: 0.109, blue: 0.149, alpha: 1)])?.draw(in: body, angle: 12)
-        drawHeader(header, face: face, cut: cut)
-        drawTotals(snapshot, in: body, face: face, cut: cut, accent: accent)
-        drawBreakdown(snapshot, in: breakdown, face: face, cut: cut)
-        NSGraphicsContext.restoreGraphicsState()
+        drawRules(on: face, plate: rear)
+        // 总数牌压在规则背板上，独立描边在左右两侧形成错位。
+        fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
+                             HomeDashboardStyle.color(0x101A25)], angle: 14,
+             border: HomeDashboardStyle.color(0x57636B))
+        drawTotals(snapshot, on: face, accent: accent)
+        drawBreakdown(snapshot, on: face)
+        if let revealFraction { drawRevealHighlight(in: surfaceRect, outline: total, accent: accent, fraction: revealFraction) }
+    }
+
+    private func drawRules(on face: Face, plate: NSBezierPath) {
+        let blue = HomeDashboardStyle.color(0x203547)
+        NSGradient(colors: [blue.withAlphaComponent(0.62), blue.withAlphaComponent(0.30), blue.withAlphaComponent(0)])?
+            .draw(in: plate, angle: 90)
+        let rim = HomeDashboardStyle.color(0x657681)
+        HomeDashboardStyle.line(from: face.point(455, 123), to: face.point(1046, 123), color: rim.withAlphaComponent(0.80), width: 1.25)
+        HomeDashboardStyle.line(from: face.point(1046, 123), to: face.point(1024, 175), color: rim.withAlphaComponent(0.65), width: 1.25)
+        let leftRim = face.path([(454.5, 123), (455.8, 123), (362.8, 309), (361.5, 309)])
+        NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
 
-        HomeDashboardStyle.border.setStroke()
-        outline.lineWidth = 1
-        outline.stroke()
-        if let revealFraction { drawRevealHighlight(in: face, outline: outline, accent: accent, fraction: revealFraction) }
-    }
-
-    private func drawHeader(_ header: NSRect, face: NSRect, cut: CGFloat) {
-        let inset = max(10, min(face.width * 0.047, 27))
-        let markHeight = min(19, header.height * 0.42)
-        let x = leftEdge(of: face, cut: cut, at: header.midY) + inset
-        for index in 0..<2 {
-            let mark = NSRect(x: x + CGFloat(index) * markHeight * 0.76, y: header.midY - markHeight / 2,
-                              width: markHeight, height: markHeight)
-            HomeDashboardStyle.cyan.setFill()
-            HomeDashboardStyle.slant(mark, cut: markHeight * 0.45).fill()
+        HomeDashboardStyle.cyan.setFill()
+        for x: CGFloat in [482, 498] {
+            face.path([(x + 10, 138), (x + 24, 138), (x + 14, 158), (x, 158)]).fill()
         }
-        let textStart = x + markHeight * 1.76 + inset * 0.55
-        let width = max(0, face.maxX - inset - textStart)
-        let size = GameLobbyStyle.fittedSize(modeCaption, width: width, preferred: min(18, header.height * 0.50),
-                                             minimum: 10, weight: .bold)
-        label(modeCaption, x: textStart, y: header.midY, width: width, size: size, weight: .bold,
+        let caption = face.box(535, 123, width: 478, height: 52)
+        let size = GameLobbyStyle.fittedSize(modeCaption, width: caption.width,
+                                             preferred: max(11, 18 * face.typographyScale), minimum: 9, weight: .bold)
+        label(modeCaption, x: caption.minX, y: caption.midY - 1, width: caption.width, size: size, weight: .bold,
               color: HomeDashboardStyle.cyan)
     }
 
-    private func drawTotals(_ snapshot: GameSnapshot, in body: NSRect, face: NSRect, cut: CGFloat, accent: NSColor) {
-        let inset = max(13, min(face.width * 0.047, 30))
-        let x = leftEdge(of: face, cut: cut, at: body.midY) + inset
-        let available = face.width - cut - inset * 2
-        let right = x + available
-        for y in [body.minY, body.maxY] {
-            HomeDashboardStyle.line(from: NSPoint(x: body.minX, y: y), to: NSPoint(x: body.maxX, y: y),
-                                    color: HomeDashboardStyle.border)
-        }
+    private func drawTotals(_ snapshot: GameSnapshot, on face: Face, accent: NSColor) {
+        let body = face.box(478, 175, width: 506, height: 80)
+        let x = body.minX
+        let available = body.width
+        let right = body.maxX
         if showsBudget {
             let split = x + available * 0.48
             let trackY = body.maxY - 8
@@ -134,14 +159,14 @@ final class HomeChallengeHUDView: NSView {
         } else {
             let title = AchievementText.string("home.cleared_title")
             let titleWidth = available * 0.48
-            let titleSize = GameLobbyStyle.fittedSize(title, width: titleWidth, preferred: min(20, body.height * 0.32),
+            let titleSize = GameLobbyStyle.fittedSize(title, width: titleWidth, preferred: max(12, 21 * face.typographyScale),
                                                        minimum: 10, weight: .bold)
             label(title, x: x, y: body.midY, width: titleWidth, size: titleSize, weight: .bold)
             let value = String(snapshot.totalCleared)
-            let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth, preferred: min(55, body.height * 0.77),
-                                                 minimum: 12, weight: .heavy)
-            label(value, x: x + titleWidth, y: body.midY, width: available - titleWidth, size: size, weight: .heavy,
-                  italic: true, alignment: .right)
+            let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth - 8,
+                                                 preferred: max(24, 58 * face.typographyScale), minimum: 12, weight: .black)
+            count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1, width: available - titleWidth, height: body.height),
+                  size: size, weight: .black, italic: true, alignment: .right)
         }
     }
 
@@ -158,33 +183,52 @@ final class HomeChallengeHUDView: NSView {
               color: color, italic: true, alignment: alignment)
     }
 
-    private func drawBreakdown(_ snapshot: GameSnapshot, in row: NSRect, face: NSRect, cut: CGFloat) {
-        let kinds = PieceKind.allCases
-        let slot = (face.width - cut) / CGFloat(kinds.count)
-        let iconWidth = min(42, row.height * 1.04, slot * 0.46)
-        let gap = max(4, min(9, slot * 0.08))
-        let padding = min(18, slot * 0.10)
-        // 四列平行等宽，图标锚定在同一位置，消除数量的位数变化不推动图标。
-        for (index, kind) in kinds.enumerated() {
-            let indexOffset = CGFloat(index) * slot
-            let dividerX = leftEdge(of: face, cut: cut, at: row.minY) + indexOffset
-            if index > 0 {
-                HomeDashboardStyle.line(from: NSPoint(x: dividerX, y: row.minY),
-                                        to: NSPoint(x: face.minX + indexOffset, y: row.maxY),
-                                        color: HomeDashboardStyle.border)
-            }
-            let iconX = leftEdge(of: face, cut: cut, at: row.midY) + indexOffset + padding
-            HomeLobbyArtwork.drawPiece(kind, in: NSRect(x: iconX, y: row.minY, width: iconWidth, height: row.height))
-            let number = String(snapshot.clearedByKind[kind, default: 0])
-            let numberWidth = slot - iconWidth - gap - padding * 2
-            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: min(20, row.height * 0.54),
-                                                 minimum: 8, weight: .semibold)
-            label(number, x: iconX + iconWidth + gap, y: row.midY, width: numberWidth, size: size, weight: .semibold)
+    private func drawBreakdown(_ snapshot: GameSnapshot, on face: Face) {
+        // 各分格用独立轮廓，双斜边之间留出原稿中的暗缝。
+        let cells: [(kind: PieceKind, left: CGFloat, right: CGFloat, icon: CGFloat, value: CGFloat)] = [
+            (.orangeRicky, 434, 571, 448, 502),
+            (.blueRicky, 581, 716, 589, 644),
+            (.clevelandZ, 726, 864, 734, 787),
+            (.rhodeIslandZ, 875, 997, 882, 936),
+        ]
+        let rim = HomeDashboardStyle.color(0x55616A)
+        for cell in cells {
+            let shape = face.path([(cell.left, 255), (cell.right, 255), (cell.right - 24, 308), (cell.left - 24, 308)])
+            fill(shape, colors: [HomeDashboardStyle.color(0x202B34), HomeDashboardStyle.color(0x121E29)],
+                 angle: 21, border: rim)
+            var icon = face.box(cell.icon, 266, width: 42, height: 30)
+            // 高度先触顶时收窄图标框，图案仍从原稿对应的左侧位置起画。
+            icon.size.width = min(icon.width, icon.height * 42 / 30)
+            HomeLobbyArtwork.drawPiece(cell.kind, in: icon)
+            let number = String(snapshot.clearedByKind[cell.kind, default: 0])
+            let slot = face.box(cell.value, 255, width: cell.right - 15 - cell.value, height: 53)
+            let size = GameLobbyStyle.fittedSize(number, width: slot.width, preferred: max(11, 21 * face.typographyScale),
+                                                 minimum: 7, weight: .semibold)
+            count(number, in: slot, size: size, weight: .semibold)
         }
+        HomeDashboardStyle.line(from: face.point(410, 308), to: face.point(973, 308), color: rim)
+    }
+
+    private func fill(_ shape: NSBezierPath, colors: [NSColor], angle: CGFloat, border: NSColor) {
+        NSGradient(colors: colors)?.draw(in: shape, angle: angle)
+        border.setStroke()
+        shape.lineWidth = 1.25
+        shape.stroke()
     }
 
-    private func leftEdge(of face: NSRect, cut: CGFloat, at y: CGFloat) -> CGFloat {
-        face.minX + cut * (face.maxY - y) / face.height
+    private func count(_ value: String, in slot: NSRect, size: CGFloat, weight: NSFont.Weight,
+                       italic: Bool = false, alignment: NSTextAlignment = .left) {
+        guard slot.width > 0 else { return }
+        let font = NSFont.systemFont(ofSize: size, weight: weight)
+        let width = max(slot.width, ceil((value as NSString).size(withAttributes: [.font: font]).width) + 2)
+        // 极窄窗口里的长数字仍保留全部位数，只压缩字形宽度。
+        NSGraphicsContext.saveGraphicsState()
+        let fit = NSAffineTransform()
+        fit.translateX(by: slot.minX, yBy: 0)
+        fit.scaleX(by: slot.width / width, yBy: 1)
+        fit.concat()
+        label(value, x: 0, y: slot.midY, width: width, size: size, weight: weight, italic: italic, alignment: alignment)
+        NSGraphicsContext.restoreGraphicsState()
     }
 
     private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight,
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index f36d02a5e915a83737a48a146a64f320e6f4e1c7..59aabc628715f0da0691bc127035b3547759c04e 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -567,11 +567,14 @@ final class HomeDashboardView: NSView {
         let contactHeight = min(165, max(110, bounds.height * 0.152))
         let verticalGap = min(52, max(27, bounds.height * 0.050))
         let contactTop = stageBottom - contactHeight
-        let panel = NSRect(x: rightX, y: sectionTop, width: rightWidth, height: max(0, contactTop - verticalGap - sectionTop))
+        // 模式列沿右边对齐，为规则牌的右上斜角预留空间。联系卡仍沿右栏外缘排版。
+        let modeInset = min(rightWidth * 0.12, max(0, rightWidth - 302), bounds.width * 0.038)
+        let panel = NSRect(x: rightX + modeInset, y: sectionTop, width: rightWidth - modeInset,
+                           height: max(0, contactTop - verticalGap - sectionTop))
         modePanel.frame = panel
         modePanel.needsDisplay = true
-        contactPanel.frame = NSRect(x: panel.minX, y: contactTop, width: panel.width, height: contactHeight)
-        let leftWidth = max(0, panel.minX - margin - 20)
+        contactPanel.frame = NSRect(x: rightX, y: contactTop, width: rightWidth, height: contactHeight)
+        let leftWidth = max(0, rightX - margin - 20)
         let leftColumn = NSRect(x: margin, y: sectionTop, width: leftWidth, height: bounds.height * 0.245)
         modeHeader.position(leftColumn: leftColumn, windowWidth: bounds.width, modePanelLeading: panel.minX)
         let artworkWidth = leftWidth * 0.95
@@ -623,7 +626,7 @@ final class HomeDashboardView: NSView {
         HomeDashboardStyle.line(from: dividerStart, to: dividerEnd, color: HomeDashboardStyle.border.withAlphaComponent(0.5))
         let middle = NSPoint(x: (dividerStart.x + dividerEnd.x) / 2, y: (dividerStart.y + dividerEnd.y) / 2)
         HomeDashboardStyle.line(from: dividerStart, to: middle, color: cyan.withAlphaComponent(0.22))
-        HomeDashboardStyle.line(from: NSPoint(x: modePanel.frame.minX + 12, y: contactPanel.frame.minY - 24),
+        HomeDashboardStyle.line(from: NSPoint(x: contactPanel.frame.minX + 28, y: contactPanel.frame.minY - 24),
                                 to: NSPoint(x: contactPanel.frame.maxX, y: contactPanel.frame.minY - 24),
                                 color: HomeDashboardStyle.border.withAlphaComponent(0.77))
         if showsShortcut {
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index b93b1225f7c9bc43d090a7d98ad4ee431984b959..47ff9662a0332a77888c31057963970440b48cb7 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -48,11 +48,16 @@ final class HomeModeHeaderView: NSView {
     func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
         let topPadding = HomeChallengeHUDView.surfaceInsetY + 3
         frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
-        let headingWidth = (leftColumn.width * 0.36).rounded(.down)
+        let headingWidth = (leftColumn.width * 0.361).rounded(.down)
         let gap = min(16, leftColumn.width * 0.025)
         intro.frame = NSRect(x: leftColumn.minX, y: topPadding, width: headingWidth, height: leftColumn.height)
-        let cardHeight = min(200, max(102, leftColumn.height * 0.84))
-        cardColumn = NSRect(x: intro.frame.maxX + gap, y: topPadding, width: max(0, leftColumn.width - headingWidth - gap),
+        let cardTop = min(19, leftColumn.height * 0.079)
+        let cardHeight = min(186, max(102, leftColumn.height * 0.77))
+        let faceX = intro.frame.maxX + gap + HomeChallengeHUDView.trailingInset
+        let faceRight = modePanelLeading - min(22, leftColumn.width * 0.031)
+        let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX))
+        cardColumn = NSRect(x: cardX, y: topPadding + cardTop,
+                            width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                             height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
         entryX = modePanelLeading
         needsLayout = true
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index b4a926e9e4ca64ef9108461bcb61e2132d8585c0..38254b879c4f5bf13ed4f8f9064706eb3218866f 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -12,7 +12,10 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         return pixels
     }
     private func export(_ view: NSView, name: String) throws {
-        try XCTUnwrap(try image(view).representation(using: .png, properties: [:]))
+        try export(image(view), name: name)
+    }
+    private func export(_ bitmap: NSBitmapImageRep, name: String) throws {
+        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
             .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-\(name).png"))
     }
 
@@ -58,7 +61,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(hud.budgetText, "0")
     }
 
-    func testPieceCountsFillFourEqualColumnsAcrossStatWidths() throws {
+    func testPieceCountsFollowReferenceSlotsAcrossStatWidths() throws {
         _ = NSApplication.shared
         let longCount = 123_456
         let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
@@ -72,7 +75,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                 let bitmap = try image(hud)
                 let scale = CGFloat(bitmap.pixelsWide) / width
                 let surface = hud.surfaceRect
-                let rowStart = surface.maxY - surface.height * 0.29
+                let rowStart = surface.minY + surface.height * 132 / 186
                 let rowPixels = stride(from: Int(ceil(rowStart * scale)), to: Int(surface.maxY * scale), by: 2)
                 var iconStarts: [CGFloat] = []
                 var previousColoredX = -CGFloat.infinity
@@ -90,13 +93,12 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                     if position - previousColoredX > 3 { iconStarts.append(position) }
                     previousColoredX = position
                 }
-                let cut = min(surface.height * 0.25, surface.width * 0.09)
-                let columnWidth = (surface.width - cut) / CGFloat(PieceKind.allCases.count)
+                // 即使高度限制等比缩放，起点仍按设计稿在各分格内的位置对齐。
+                let referenceOffsets: [CGFloat] = [38, 179, 324, 472]
                 XCTAssertEqual(iconStarts.count, PieceKind.allCases.count, "\(mode.key) / \(width)")
-                let breakdownStart = surface.minX + cut * 0.145 + min(18, columnWidth * 0.10)
-                for (index, start) in iconStarts.enumerated() {
-                    XCTAssertEqual(start, breakdownStart + CGFloat(index) * columnWidth, accuracy: 2,
-                                   "\(mode.key) / \(width)：方块图标应依等宽列左边缘排布")
+                for (start, offset) in zip(iconStarts, referenceOffsets) {
+                    XCTAssertEqual(start, surface.minX + surface.width * offset / 636, accuracy: 3,
+                                   "\(mode.key) / \(width)：方块起点应与设计稿对应列对齐")
                 }
                 XCTAssertTrue(hud.toolTip?.contains("\(longCount)") == true, "长数字的完整值可通过提示查看")
                 if mode == .moves, width == 534 { try export(hud, name: "hud-compact-long-counts") }
@@ -130,7 +132,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                         let heading = try XCTUnwrap(labels.first)
                         let subtitle = try XCTUnwrap(labels.last)
                         XCTAssertGreaterThanOrEqual(subtitle.frame.minY - heading.frame.maxY, 8)
-                        XCTAssertLessThan(intro.frame.maxX, home.challengeHUD.frame.minX)
+                        let headerSurface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home.modeHeader)
+                        XCTAssertLessThan(intro.frame.maxX, headerSurface.minX)
                         XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, running ? 42 : 0)
                         let hudRect = home.challengeHUD.convert(home.challengeHUD.bounds, to: home)
                         XCTAssertTrue(home.bounds.contains(hudRect))
@@ -138,7 +141,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                         XCTAssertEqual(cards.map(\.mode), [.free, nil, .timed, .moves])
                         XCTAssertLessThan(hudRect.maxX, home.modePanel.frame.minX)
                         let surface = home.challengeHUD.convert(home.challengeHUD.surfaceRect, to: home)
-                        XCTAssertEqual(surface.minY, home.modePanel.frame.minY, accuracy: 0.1)
+                        let topInset = min(19, size.height * 0.245 * 0.079)
+                        XCTAssertEqual(surface.minY, home.modePanel.frame.minY + topInset, accuracy: 0.2)
                         XCTAssertFalse(cards[1].isEnabled)
                         let label = try XCTUnwrap(home.challengeHUD.accessibilityLabel())
                         XCTAssertEqual(label.components(separatedBy: AchievementText.string("home.cleared_title")).count, 2)
@@ -170,7 +174,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         home.setFrameSize(NSSize(width: 1585, height: 992))
         home.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
             remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free, manager: manager)
-        try export(home, name: "lobby-reference-size")
+        let referenceBitmap = try image(home)
+        try assertRuleCardMatchesReference(home, bitmap: referenceBitmap)
+        try export(referenceBitmap, name: "lobby-reference-size")
         home.setFrameSize(NSSize(width: 1180, height: 800))
         home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 150, remainingTime: nil,
             remainingSwaps: 3, isRunning: true, isFinished: false, clearedByKind: [.orangeRicky: 120]), mode: .moves, manager: manager)
@@ -210,6 +216,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let outgoing = home.challengeHUD
         let restingX = outgoing.frame.minX
         let restingWidth = outgoing.frame.width
+        let restingSurfaceY = outgoing.convert(outgoing.surfaceRect, to: home).minY
         home.refresh(snapshot: timed, mode: .timed, manager: manager)
         let preview = home.challengeHUD
         XCTAssertGreaterThan(preview.frame.minX, restingX)
@@ -242,7 +249,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             }
             if step == steps / 3 { try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview) }
             XCTAssertEqual(intro.frame, introFrame, "切换统计卡时保留标题的位置")
-            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, home.modePanel.frame.minY, accuracy: 0.1)
+            XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, restingSurfaceY, accuracy: 0.1)
             home.layoutSubtreeIfNeeded()
             let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
             home.cacheDisplay(in: header.frame, to: pixels)
@@ -284,6 +291,35 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         try XCTUnwrap(header.subviews.first { !$0.isHidden && !($0 is HomeChallengeHUDView) })
     }
 
+    private func assertRuleCardMatchesReference(_ home: HomeDashboardView, bitmap: NSBitmapImageRep) throws {
+        let card = home.challengeHUD
+        let surface = card.convert(card.surfaceRect, to: home)
+        XCTAssertEqual(surface.minX, 410, accuracy: 2.5)
+        XCTAssertEqual(surface.minY, 123, accuracy: 2.5)
+        XCTAssertEqual(surface.maxX, 1046, accuracy: 2.5)
+        XCTAssertEqual(surface.maxY, 309, accuracy: 2.5)
+        let scale = CGFloat(bitmap.pixelsWide) / home.bounds.width
+
+        func brightness(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
+            let pointX = surface.minX + (x - 410) * surface.width / 636
+            let pointY = surface.minY + (y - 123) * surface.height / 186
+            let color = try XCTUnwrap(bitmap.colorAt(x: Int(pointX * scale), y: Int(pointY * scale))?.usingColorSpace(.sRGB))
+            return (color.redComponent + color.greenComponent + color.blueComponent) / 3
+        }
+
+        let rim = try (173...176).map { try brightness(780, CGFloat($0)) }.max() ?? 0
+        let rimNeighbors = try max(brightness(780, 170), brightness(780, 178))
+        XCTAssertGreaterThan(rim, rimNeighbors + 0.09, "统计前板的上边缘应在两层深色面板之间清楚可见")
+
+        // 取三条缝左右边缘的亮点，验证底部由四张独立斜卡组成。
+        for (left, right) in [(560, 570), (705, 715), (854, 864)] {
+            let leftRim = try (left - 2...left + 2).map { try brightness(CGFloat($0), 280) }.max() ?? 0
+            let rightRim = try (right - 2...right + 2).map { try brightness(CGFloat($0), 280) }.max() ?? 0
+            let gap = try brightness(CGFloat(left + right) / 2, 280)
+            XCTAssertGreaterThan(min(leftRim, rightRim), gap + 0.05, "两张统计卡之间应保留可见间隔")
+        }
+    }
+
     private func assertLaunchIsWithinScreen(_ preview: HomeChallengeHUDView, in window: NSWindow) throws {
         XCTAssertLessThanOrEqual(preview.frame.maxX, try XCTUnwrap(preview.superview).bounds.maxX + 0.1)
         if let screen = window.screen {
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index a8e612cadda7225c14f953143167286de08c384c..a025e00e803984f3e938ddd08f765373660182c7 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -141,8 +141,8 @@ final class HomeDashboardTests: AchievementTestCase {
             XCTAssertEqual(home.startButton.frame.maxY, contact.maxY, accuracy: 0.1)
             XCTAssertGreaterThanOrEqual(contact.minY - mode.maxY, 27)
             XCTAssertLessThanOrEqual(contact.minY - mode.maxY, 52.1)
-            XCTAssertEqual(contact.minX, mode.minX, accuracy: 0.1)
-            XCTAssertEqual(contact.width, mode.width, accuracy: 0.1)
+            XCTAssertGreaterThanOrEqual(mode.minX, contact.minX)
+            XCTAssertEqual(contact.maxX, mode.maxX, accuracy: 0.1)
             XCTAssertTrue((110...165).contains(contact.height))
             XCTAssertGreaterThanOrEqual(path.minY - contact.maxY, 35)
             XCTAssertEqual(path.minX, home.bounds.maxX - path.maxX, accuracy: 0.1)
```
