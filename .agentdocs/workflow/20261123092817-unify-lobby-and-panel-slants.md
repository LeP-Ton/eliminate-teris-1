# 统一大厅和弹窗的斜边与文字

## 背景与目标

- 会话-9 至会话-11 按大厅截图细化深色主题。校准结构斜边及文字，修复成就进度的垂直填充端、消除明细末格偏窄和弹窗选中层的矩形轮廓。
- 使用共享的几何参数和文字样式。根据窗口宽高排版，按实时快照更新消除与挑战预算。

## 完成情况

- [x] `HomeDashboardStyle` 统一用水平偏移 ÷ 垂直高度 0.45（与竖直约成 24.2°）绘制斜边，包括标题标记、按钮、统计牌、背景斜纹和插画轨道。
- [x] 将应用内标题、说明、按钮、标签和数值统一为同一轻斜体，保留各层级字号与字重。
- [x] 成就段条和详情进度按平行四边形净宽计算填充。部分填充仍保留与轨道平行的斜端。限时余额归零时只绘制空轨道。
- [x] 四类方块明细改为等宽等距，统计卡转场改为等比缩放。检查并调整大厅分隔线的收尾位置、成就图标与斜边的距离以及紧凑尺寸的名称截短。
- [x] 成就与挑战记录复用同一选中轮廓。渐变遮罩、描边、光晕与分段命中均使用共享斜率。记录目标矩形，避免图层由中心点反算边界时的小数误差打断快速切换动画。

## 测试与验收

| 用例 | 操作与结果 |
| --- | --- |
| 大厅几何 | 渲染 336、534、1360 点的独立卡片及宽窄大厅。比较四格宽度、缝隙与不同高度的描边像素 |
| 部分进度 | 用 6 / 32 的测试进度比较两行黄色像素末端的横向偏移 |
| 原生弹窗 | 在成就和挑战记录的两种宽度比较遮罩、描边、光晕路径，验证斜分界点击与快捷键，连续切换检查动画接续 |
| 玩法回归 | 渲染五种语言和三个模式，验证入场等比缩放、预算、计数与原有点击 |

- 本地可运行 `./run.sh`，缩放大厅，切换三种模式，再打开成就和挑战记录切换选中项。
- 自动化命令为 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，最终 90 项测试全部通过。原生快照由大厅、成就和挑战记录测试导出。

## 代码变更


```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index fc505dd999ac91997073a771193dc4fdefcbd3ac..9451f3df24d0222f2e068034aa78b1201ecb3a6a 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261123092817-unify-lobby-and-panel-slants.md` - 会话-9 至会话-11 统一大厅和弹窗的斜边与文字，修正等宽统计格、斜切进度填充和滑块动画。含实际预览、回归与本轮增量 diff。
 `workflow/20261123082529-match-reference-rule-and-stat-card.md` - 会话-6 至会话-8 按参考图坐标还原规则背板、总数前板和四张分类斜卡。含双边暗缝像素回归与本轮增量 diff。
 `workflow/20261123075948-dark-angular-appkit-ui.md` - 会话-2 至会话-5 在 `experiment/ui-refactor-v2` 按设计图重构深色 AppKit 界面，保留「消除俄罗斯方块」名称。含五语言、原生预览验证和完整 diff。
 `workflow/20261122165517-full-width-achievement-row.md` - 会话-207 起恢复跨栏单行成就，并让开始按钮与联系我们卡片底边对齐。含宽窄窗口回归、实际预览与完整 diff。
@@ -99,6 +100,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整统一斜角、轻斜文字、成就进度的部分填充、等宽消除分格或弹窗分段滑块时，读取 `20261123092817-unify-lobby-and-panel-slants.md`。
 - 需要核对深色大厅规则与消除统计卡的原图尺寸、层间错位、分格暗缝、长数字或转场遮挡时，读取 `20261123082529-match-reference-rule-and-stat-card.md`。
 - 需要调整深色大厅斜边主题、统计与标题并排、方块及触控栏示意，或核对辅助面板主题和游戏名称时，读取 `20261123075948-dark-angular-appkit-ui.md`。
 - 需要调整当前首页的跨栏成就预览、开始按钮与联系卡的底边或小窗口布局时，读取 `20261122165517-full-width-achievement-row.md`。
@@ -198,7 +200,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- 深色大厅、辅助面板和成就窗口共用 `HomeDashboardStyle`。大厅模式卡使用线形图标，辅助页通过 `GameIconRenderer` 继续使用 `GameModeArtwork` 的彩色模式图案。
+- 深色大厅、辅助面板和成就窗口共用 `HomeDashboardStyle` 的 0.45 结构斜率和轻斜字形。大厅模式卡使用线形图标，辅助页通过 `GameIconRenderer` 继续使用 `GameModeArtwork` 的彩色模式图案。
 - `GameControlFeedback` 的 0.18 秒反馈仅由交互变化触发，减少动态效果时立即到位。任何模式在大厅均显示 `GameSnapshot` 的本局统计，挑战卡切换时保留独立转场。
 - 开局由 `GameStartSequence` 统一管理；`prepareRound` 仅生成预览，`beginPreparedRound` 在开场结束后启用同一棋盘并开始计时。待机 Touch Bar 显示滑轨，开局指针全部抬起后才接受交换；私有 modal 刷新保持开场进度。
 - 成就筛选由 `AchievementFilterControl` 统一绘制滑轨与数量，沿用 `NSSegmentedControl` 的真实选择值。深色版滑块使用青色，刷新列表时继续当前动画，减少动态效果时即时定位。
diff --git a/AGENTS.md b/AGENTS.md
index 8b4fc8a39ea7135f10d7c74f2ab9c2b7e78749d4..958c129844324bbe96a644fa545a98f08d1b1b12 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -7,6 +7,7 @@
 
 ## 2026-11-23（深色界面探索分支）
 - `experiment/ui-refactor-v2` 的大厅、设置、玩法、挑战记录和成就窗口共用 `HomeDashboardStyle` 的深蓝底、斜边与状态色。桌面大厅和窗口标题的简体中文名称为「消除俄罗斯方块」。
+- 深色主题的结构斜边以水平偏移 ÷ 垂直高度 0.45 绘制。边框、分段选中态、进度填充与统计入场共享该几何规范。应用内自绘文字和标签共享轻斜体。
 - 大厅的介绍与本局快照并排展示。模式切换只让统计卡入场，标题继续可见。左侧插画、统计图标与触控栏示意共用 `HomeLobbyArtwork` 的原生矢量方块。实际触控栏由 `GameTouchBarView` 绘制，开局和结算仍经原有控制器协调。
 
 ## 2026-11-22（首页双栏与跨栏成就）
diff --git a/Sources/AchievementFilterControl.swift b/Sources/AchievementFilterControl.swift
index b8e6320d4d382c1551e74008e13bb62fe651cddf..c8d4a6bb8b59677c49cb179d23cdfa7f11595b6e 100644
--- a/Sources/AchievementFilterControl.swift
+++ b/Sources/AchievementFilterControl.swift
@@ -3,12 +3,15 @@ import QuartzCore
 
 /// 滑轨只承载视觉过渡；真实选中值和筛选事件仍沿用原生 NSSegmentedControl。
 final class AchievementFilterControl: NSSegmentedControl {
-    private let thumb = CAGradientLayer()
+    private let thumb = CALayer()
+    private let thumbFill = CAGradientLayer()
+    private let thumbMask = CAShapeLayer()
+    private let thumbRim = CAShapeLayer()
     private let labels = FilterLabelsView()
     private var counts: [Int] = []
     private var tracking: NSTrackingArea?
     private var hoveredSegment: Int?
-    private var hasPlacedThumb = false
+    private var placedThumbFrame: NSRect?
     /// 辅助页面复用同一套滑轨质感；未指定时保持成就筛选的三个状态图标。
     var segmentSymbols = ["square.grid.2x2.fill", "lock.fill", "checkmark.seal.fill"]
     /// 在测试中可替换系统偏好，运行时每次切换都读取最新设置。
@@ -27,12 +30,18 @@ final class AchievementFilterControl: NSSegmentedControl {
         labels.wantsLayer = true
         addSubview(labels)
         thumb.name = "achievement-filter-selection"
-        thumb.colors = [HomeDashboardStyle.color(0x17505A).cgColor, HomeDashboardStyle.color(0x10313D).cgColor]
-        thumb.startPoint = CGPoint(x: 0, y: 0.5)
-        thumb.endPoint = CGPoint(x: 1, y: 0.5)
-        thumb.cornerRadius = 2
-        thumb.borderWidth = 1
-        thumb.borderColor = HomeDashboardStyle.cyan.withAlphaComponent(0.85).cgColor
+        thumbFill.name = "achievement-filter-selection-fill"
+        thumbFill.colors = [HomeDashboardStyle.color(0x17505A).cgColor, HomeDashboardStyle.color(0x10313D).cgColor]
+        thumbFill.startPoint = CGPoint(x: 0, y: 0.5)
+        thumbFill.endPoint = CGPoint(x: 1, y: 0.5)
+        thumbMask.fillColor = NSColor.white.cgColor
+        thumbFill.mask = thumbMask
+        thumbRim.name = "achievement-filter-selection-rim"
+        thumbRim.fillColor = nil
+        thumbRim.strokeColor = HomeDashboardStyle.cyan.withAlphaComponent(0.85).cgColor
+        thumbRim.lineWidth = 1
+        thumb.addSublayer(thumbFill)
+        thumb.addSublayer(thumbRim)
         thumb.shadowColor = HomeDashboardStyle.cyan.cgColor
         thumb.shadowOpacity = 0.18
         thumb.shadowRadius = 3
@@ -47,7 +56,8 @@ final class AchievementFilterControl: NSSegmentedControl {
         let widest = (0..<segmentCount).map { index in
             ((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: labelFont]).width
         }.max() ?? 0
-        return NSSize(width: CGFloat(segmentCount) * max(102, widest + 58) + 8, height: 44)
+        return NSSize(width: CGFloat(segmentCount) * max(102, widest + 58) + 8 + HomeDashboardStyle.edgeOffset(for: 36),
+                      height: 44)
     }
 
     private var labelFont: NSFont { .systemFont(ofSize: 12, weight: .semibold) }
@@ -70,8 +80,14 @@ final class AchievementFilterControl: NSSegmentedControl {
 
     private func segmentRect(_ index: Int) -> NSRect {
         guard segmentCount > 0 else { return .zero }
-        let width = max(0, bounds.width - 8) / CGFloat(segmentCount)
-        return NSRect(x: 4 + CGFloat(index) * width, y: 4, width: width, height: max(0, bounds.height - 8))
+        let track = bounds.insetBy(dx: 4, dy: 4)
+        let offset = HomeDashboardStyle.edgeOffset(for: track.height)
+        let pitch = max(0, track.width - offset) / CGFloat(segmentCount)
+        return NSRect(x: track.minX + CGFloat(index) * pitch, y: track.minY, width: pitch + offset, height: track.height)
+    }
+
+    private func segmentIndex(at point: NSPoint) -> Int? {
+        (0..<segmentCount).first { HomeDashboardStyle.slant(segmentRect($0)).contains(point) }
     }
 
     override func layout() {
@@ -79,18 +95,25 @@ final class AchievementFilterControl: NSSegmentedControl {
         labels.frame = bounds
         let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
         // 刷新列表或数量时不重置正在进行的动画；仅在几何尺寸改变时同步。
-        if !hasPlacedThumb || thumb.frame != target { positionThumb(animated: false) }
+        if placedThumbFrame != target { positionThumb(animated: false) }
     }
 
     private func positionThumb(animated: Bool) {
         guard selectedSegment >= 0, selectedSegment < segmentCount, bounds.width > 8, bounds.height > 8 else { return }
         let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
         let previous = thumb.presentation()?.frame ?? thumb.frame
-        let shouldAnimate = animated && hasPlacedThumb && !reducesMotion()
+        let shouldAnimate = animated && placedThumbFrame != nil && !reducesMotion()
         thumb.removeAnimation(forKey: "filter-selection")
         CATransaction.begin(); CATransaction.setDisableActions(true)
         thumb.frame = target
-        thumb.shadowPath = CGPath(roundedRect: thumb.bounds, cornerWidth: 2, cornerHeight: 2, transform: nil)
+        thumbFill.frame = thumb.bounds
+        thumbMask.frame = thumbFill.bounds
+        thumbRim.frame = thumb.bounds
+        // 渐变、描边和光晕共用同一轮廓，整个滑块在切换时一同移动。
+        let outline = HomeDashboardStyle.cgSlant(thumb.bounds.insetBy(dx: 0.5, dy: 0.5))
+        thumbMask.path = outline
+        thumbRim.path = outline
+        thumb.shadowPath = outline
         CATransaction.commit()
         if shouldAnimate {
             let movement = CABasicAnimation(keyPath: "position")
@@ -105,14 +128,18 @@ final class AchievementFilterControl: NSSegmentedControl {
             group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
             thumb.add(group, forKey: "filter-selection")
         }
-        hasPlacedThumb = true
+        // 图层会由中心点反算 frame。保留布局目标可避免小数舍入误差把刷新误判成变尺寸。
+        placedThumbFrame = target
         labels.needsDisplay = true
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        UtilityStyle.drawCard(bounds, cut: 5)
+        UtilityStyle.drawCard(bounds)
     }
 
+    override var focusRingMaskBounds: NSRect { bounds }
+    override func drawFocusRingMask() { HomeDashboardStyle.slant(bounds).fill() }
+
     fileprivate func drawLabels() {
         for index in 0..<segmentCount {
             let rect = segmentRect(index)
@@ -121,24 +148,29 @@ final class AchievementFilterControl: NSSegmentedControl {
             let color = selected ? HomeDashboardStyle.cyan : hoveredSegment == index ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
             let count = counts.indices.contains(index) ? String(counts[index]) : "0"
             let countFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
-            let countWidth = max(21, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 10)
+            let countWidth = max(23, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 12)
+            let labelWidth = max(0, rect.width - HomeDashboardStyle.edgeOffset(for: rect.height) - 34 - countWidth)
             var font = labelFont
             var titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
-            while 13 + 6 + titleWidth + 7 + countWidth > rect.width - 10, font.pointSize > 10 {
+            while titleWidth > labelWidth, font.pointSize > 10 {
                 font = .systemFont(ofSize: font.pointSize - 0.5, weight: .semibold)
                 titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
             }
+            titleWidth = min(titleWidth, labelWidth)
             let contentWidth = 13 + 6 + titleWidth + 7 + countWidth
             let start = rect.midX - contentWidth / 2
             let symbol = segmentSymbols.indices.contains(index) ? segmentSymbols[index] : "square.fill"
             HomeStyle.symbol(symbol, in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
-            let titleSize = (title as NSString).size(withAttributes: [.font: font])
-            (title as NSString).draw(at: NSPoint(x: start + 19, y: rect.midY - titleSize.height / 2), withAttributes: [.font: font, .foregroundColor: color])
+            let titleHeight = font.ascender - font.descender + font.leading
+            HomeDashboardStyle.text(title, in: NSRect(x: start + 19, y: rect.midY - titleHeight / 2, width: titleWidth + 3,
+                                                     height: titleHeight + 2), size: font.pointSize, weight: .semibold, color: color)
             let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
             color.withAlphaComponent(selected ? 0.16 : 0.09).setFill()
-            HomeDashboardStyle.slant(chip, cut: 3).fill()
+            HomeDashboardStyle.slant(chip).fill()
             let size = (count as NSString).size(withAttributes: [.font: countFont])
-            (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2), withAttributes: [.font: countFont, .foregroundColor: color])
+            (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2),
+                                    withAttributes: [.font: countFont, .foregroundColor: color,
+                                                     .obliqueness: HomeDashboardStyle.letterSlant])
         }
     }
 
@@ -151,7 +183,7 @@ final class AchievementFilterControl: NSSegmentedControl {
 
     override func mouseMoved(with event: NSEvent) {
         let point = convert(event.locationInWindow, from: nil)
-        hoveredSegment = (0..<segmentCount).first { segmentRect($0).contains(point) }
+        hoveredSegment = segmentIndex(at: point)
         labels.needsDisplay = true
     }
     override func mouseExited(with event: NSEvent) { hoveredSegment = nil; labels.needsDisplay = true }
@@ -159,7 +191,7 @@ final class AchievementFilterControl: NSSegmentedControl {
 
     override func mouseDown(with event: NSEvent) {
         let point = convert(event.locationInWindow, from: nil)
-        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }), index != selectedSegment else { return }
+        guard isEnabled, let index = segmentIndex(at: point), index != selectedSegment else { return }
         selectedSegment = index
         sendAction(action, to: target)
     }
@@ -167,7 +199,8 @@ final class AchievementFilterControl: NSSegmentedControl {
     @discardableResult
     override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
         // 辅助功能可通过原生 Cell 改变选中值，再同步滑块，保持与鼠标/键盘相同的反馈。
-        if hasPlacedThumb, selectedSegment >= 0, thumb.frame != segmentRect(selectedSegment).insetBy(dx: 1, dy: 0) {
+        if let placedThumbFrame, selectedSegment >= 0,
+           placedThumbFrame != segmentRect(selectedSegment).insetBy(dx: 1, dy: 0) {
             positionThumb(animated: true)
         }
         return super.sendAction(action, to: target)
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
index b247578d97ae4f865fbc458b124451a70cf4d96a..0a5e41a710b19f84439fa96454c6eeddeededc91 100644
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -210,10 +210,11 @@ private enum AchievementPanelStyle {
     }()
 
     static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
-        UtilityStyle.drawCard(rect, accent: selected ? accent : nil, cut: 6)
+        UtilityStyle.drawCard(rect, accent: selected ? accent : nil)
         let attributes: [NSAttributedString.Key: Any] = [
             .font: controlFont,
-            .foregroundColor: selected ? accent : body
+            .foregroundColor: selected ? accent : body,
+            .obliqueness: HomeDashboardStyle.letterSlant,
         ]
         let size = (title as NSString).size(withAttributes: attributes)
         (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
@@ -223,6 +224,8 @@ private enum AchievementPanelStyle {
 
 private final class AchievementPanelActionButton: NSButton {
     override var isFlipped: Bool { true }
+    override var focusRingMaskBounds: NSRect { bounds }
+    override func drawFocusRingMask() { HomeDashboardStyle.slant(bounds).fill() }
 
     override var intrinsicContentSize: NSSize {
         NSSize(width: max(88, ceil((title as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24), height: 32)
@@ -244,12 +247,11 @@ private final class AchievementProgressIndicator: NSProgressIndicator {
 
     override func draw(_ dirtyRect: NSRect) {
         HomeDashboardStyle.border.withAlphaComponent(0.55).setFill()
-        HomeDashboardStyle.slant(bounds, cut: 4).fill()
+        HomeDashboardStyle.slant(bounds).fill()
         let fraction = min(1, max(0, (doubleValue - minValue) / max(1, maxValue - minValue)))
         if fraction > 0 {
             accentColor.setFill()
-            let fill = NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
-            HomeDashboardStyle.slant(fill, cut: 4).fill()
+            HomeDashboardStyle.segmentFill(bounds, fraction: fraction).fill()
         }
     }
 
@@ -268,7 +270,7 @@ private final class AchievementDocumentView: NSView {
 final class AchievementsWindowController: NSWindowController {
     private let manager: AchievementsManager
     private let filter = AchievementFilterControl()
-    private let heading = NSTextField(labelWithString: "")
+    private let heading = UtilityStyle.label("", size: 16, weight: .heavy)
     private let backButton = AchievementPanelActionButton()
     private let list = NSStackView()
     private let scroll = NSScrollView()
@@ -326,7 +328,7 @@ final class AchievementsWindowController: NSWindowController {
 
     func refresh() {
         window?.title = AchievementText.string("panel.achievements")
-        heading.stringValue = AchievementText.string("panel.achievements")
+        UtilityStyle.setText(AchievementText.string("panel.achievements"), on: heading)
         backButton.title = AchievementText.string("achievement.view_all")
         backButton.invalidateIntrinsicContentSize()
         backButton.isHidden = detailID == nil
@@ -352,9 +354,8 @@ final class AchievementsWindowController: NSWindowController {
         for category in AchievementCategory.allCases {
             let group = definitions.filter { $0.category == category }
             guard !group.isEmpty else { continue }
-            let label = NSTextField(labelWithString: AchievementText.string("achievement.category.\(category.rawValue)"))
-            label.font = .systemFont(ofSize: 12, weight: .heavy)
-            label.textColor = AchievementPanelStyle.accent
+            let label = UtilityStyle.label(AchievementText.string("achievement.category.\(category.rawValue)"),
+                                           size: 12, weight: .heavy, color: AchievementPanelStyle.accent)
             list.addArrangedSubview(label)
             for definition in group {
                 let row = makeRow(definition)
@@ -363,18 +364,15 @@ final class AchievementsWindowController: NSWindowController {
             }
         }
         if definitions.isEmpty {
-            let empty = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.empty"))
-            empty.font = .systemFont(ofSize: 12, weight: .regular)
-            empty.textColor = AchievementPanelStyle.body
+            let empty = UtilityStyle.label(AchievementText.string("achievement.empty"), size: 12)
             list.addArrangedSubview(empty)
         }
     }
 
     private func buildContent() {
         guard let content = window?.contentView else { return }
-        heading.font = .systemFont(ofSize: 16, weight: .heavy)
-        heading.textColor = AchievementPanelStyle.body
         heading.lineBreakMode = .byTruncatingTail
+        heading.maximumNumberOfLines = 1
         heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         filter.segmentCount = 3
         filter.trackingMode = .selectOne
@@ -449,9 +447,8 @@ final class AchievementsWindowController: NSWindowController {
         let accent = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.accent
         let row = PixelFrameCardView(accentColor: accent)
         row.translatesAutoresizingMaskIntoConstraints = false
-        let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
-        name.font = .systemFont(ofSize: 13, weight: .semibold)
-        name.textColor = unlocked ? accent : AchievementPanelStyle.body
+        let name = UtilityStyle.label(AchievementText.string(definition.titleKey), size: 13, weight: .semibold,
+                                      color: unlocked ? accent : AchievementPanelStyle.body)
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
         let icon = NSImageView(image: AchievementIconCatalog.image(for: definition, muted: !unlocked))
         icon.imageScaling = .scaleProportionallyUpOrDown
@@ -462,15 +459,10 @@ final class AchievementsWindowController: NSWindowController {
         titleRow.orientation = .horizontal
         titleRow.alignment = .centerY
         titleRow.spacing = 6
-        let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
-        condition.font = .systemFont(ofSize: 12, weight: .regular)
-        condition.textColor = AchievementPanelStyle.body
-        let progress = NSTextField(wrappingLabelWithString: AchievementText.progress(definition, manager: manager))
-        progress.font = .systemFont(ofSize: 11, weight: .medium)
-        progress.textColor = accent
-        let status = NSTextField(wrappingLabelWithString: AchievementText.status(definition, manager: manager))
-        status.font = .systemFont(ofSize: 10, weight: .regular)
-        status.textColor = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted
+        let condition = UtilityStyle.label(AchievementText.string(definition.descriptionKey), size: 12)
+        let progress = UtilityStyle.label(AchievementText.progress(definition, manager: manager), size: 11, weight: .medium, color: accent)
+        let status = UtilityStyle.label(AchievementText.status(definition, manager: manager), size: 10,
+                                        color: unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted)
         let meter = AchievementProgressIndicator()
         meter.accentColor = unlocked ? AchievementPanelStyle.success : HomeDashboardStyle.yellow
         meter.heightAnchor.constraint(equalToConstant: 10).isActive = true
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index fc987ab9deee5c873268bdfa6f40ff51cff057e8..ab4ea8733a6db54e8306662a123d203f86d8b7b3 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -579,7 +579,7 @@ final class PixelFrameCardView: NSView {
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
-        UtilityStyle.drawCard(bounds, accent: accentColor == HomeDashboardStyle.green ? accentColor : nil)
+        UtilityStyle.drawCard(bounds, accent: accentColor == HomeDashboardStyle.green ? accentColor : nil, containsContent: true)
     }
 }
 
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index aab2650788a3f3a005c473211472fba8bd616bb1..1da67d3d5adcc67bd7962f72b2d4a3d22164588f 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -5,20 +5,51 @@ final class HomeChallengeHUDView: NSView {
     static let surfaceInsetY: CGFloat = 5
     static let trailingInset: CGFloat = 3
     private static let rearOverhang: CGFloat = 0.08
+    private static let rearTopInset: CGFloat = 45 / 636
 
-    static func leadingInset(for width: CGFloat) -> CGFloat { width * rearOverhang }
+    static func leadingInset(for width: CGFloat, height: CGFloat) -> CGFloat {
+        max(width * rearOverhang, HomeDashboardStyle.edgeOffset(for: height) + 1 - width * rearTopInset)
+    }
 
     var surfaceRect: NSRect {
-        let width = max(0, (bounds.width - Self.trailingInset) / (1 + Self.rearOverhang))
-        return NSRect(x: Self.leadingInset(for: width), y: Self.surfaceInsetY, width: width,
-                      height: max(0, bounds.height - 2 * Self.surfaceInsetY))
+        let height = max(0, bounds.height - 2 * Self.surfaceInsetY)
+        let available = bounds.width - Self.trailingInset
+        // 窄窗背板向左伸得更远，为斜边和描线留出完整空间。
+        let rearWidth = (available - HomeDashboardStyle.edgeOffset(for: height) - 1) / (1 - Self.rearTopInset)
+        let width = max(0, min(available / (1 + Self.rearOverhang), rearWidth))
+        return NSRect(x: Self.leadingInset(for: width, height: height), y: Self.surfaceInsetY, width: width, height: height)
     }
 
+    var breakdownCellRects: [NSRect] { Face(frame: surfaceRect).breakdownCellRects }
+
     /// 设计稿坐标以底部分格左边缘为参考。背板可以越过这个边缘，在前层左侧露出。
     private struct Face {
         let frame: NSRect
         var typographyScale: CGFloat { min(frame.width / 636, frame.height / 186) }
 
+        var rules: NSRect { plate(from: point(455, 123), to: point(1046, 309)) }
+        var totals: NSRect { plate(from: point(472, 175), to: point(1033, 255)) }
+
+        var breakdownCellRects: [NSRect] {
+            let total = totals
+            let height = point(410, 308).y - total.maxY
+            let cut = HomeDashboardStyle.edgeOffset(for: height)
+            let count = CGFloat(PieceKind.allCases.count)
+            let available = total.width - HomeDashboardStyle.edgeOffset(for: total.height)
+            let gap = 10 * typographyScale
+            let cellWidth = max(0, (available - gap * (count - 1)) / count)
+            return PieceKind.allCases.indices.map { index in
+                NSRect(x: total.minX - cut + CGFloat(index) * (cellWidth + gap), y: total.maxY,
+                       width: cellWidth + cut, height: height)
+            }
+        }
+
+        private func plate(from topLeft: NSPoint, to rightAndBottom: NSPoint) -> NSRect {
+            let height = rightAndBottom.y - topLeft.y
+            let x = topLeft.x - HomeDashboardStyle.edgeOffset(for: height)
+            return NSRect(x: x, y: topLeft.y, width: rightAndBottom.x - x, height: height)
+        }
+
         func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
             NSPoint(x: frame.minX + (x - 410) / 636 * frame.width,
                     y: frame.minY + (y - 123) / 186 * frame.height)
@@ -29,14 +60,6 @@ final class HomeChallengeHUDView: NSView {
             let end = point(x + width, y + height)
             return NSRect(x: origin.x, y: origin.y, width: end.x - origin.x, height: end.y - origin.y)
         }
-
-        func path(_ corners: [(CGFloat, CGFloat)]) -> NSBezierPath {
-            let shape = NSBezierPath()
-            shape.move(to: point(corners[0].0, corners[0].1))
-            for (x, y) in corners.dropFirst() { shape.line(to: point(x, y)) }
-            shape.close()
-            return shape
-        }
     }
     private(set) var snapshot: GameSnapshot?
     private(set) var mode: HomeGameMode = .timed
@@ -90,12 +113,12 @@ final class HomeChallengeHUDView: NSView {
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        guard let snapshot, surfaceRect.width > 40, surfaceRect.height > 45 else { return }
+        let surface = surfaceRect
+        guard let snapshot, surface.width > 40, surface.height > 45 else { return }
         let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
         let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
-        let face = Face(frame: surfaceRect)
-        let rear = face.path([(455, 123), (1046, 123), (963, 309), (362, 309)])
-        let total = face.path([(472, 175), (1033, 175), (997, 255), (434, 255)])
+        let face = Face(frame: surface)
+        let total = HomeDashboardStyle.slant(face.totals)
         if let revealFraction {
             let depth = 1 - revealFraction
             NSGraphicsContext.saveGraphicsState()
@@ -107,29 +130,37 @@ final class HomeChallengeHUDView: NSView {
             NSGraphicsContext.restoreGraphicsState()
         }
 
-        drawRules(on: face, plate: rear)
+        drawRules(on: face)
         // 总数牌压在规则背板上，独立描边在左右两侧形成错位。
         fill(total, colors: [HomeDashboardStyle.color(0x17232D), HomeDashboardStyle.color(0x0C151E),
                              HomeDashboardStyle.color(0x101A25)], angle: 14,
              border: HomeDashboardStyle.color(0x57636B))
         drawTotals(snapshot, on: face, accent: accent)
         drawBreakdown(snapshot, on: face)
-        if let revealFraction { drawRevealHighlight(in: surfaceRect, outline: total, accent: accent, fraction: revealFraction) }
+        if let revealFraction { drawRevealHighlight(in: surface, outline: total, accent: accent, fraction: revealFraction) }
     }
 
-    private func drawRules(on face: Face, plate: NSBezierPath) {
+    private func drawRules(on face: Face) {
+        let plate = face.rules
         let blue = HomeDashboardStyle.color(0x203547)
         NSGradient(colors: [blue.withAlphaComponent(0.62), blue.withAlphaComponent(0.30), blue.withAlphaComponent(0)])?
-            .draw(in: plate, angle: 90)
+            .draw(in: HomeDashboardStyle.slant(plate), angle: 90)
         let rim = HomeDashboardStyle.color(0x657681)
-        HomeDashboardStyle.line(from: face.point(455, 123), to: face.point(1046, 123), color: rim.withAlphaComponent(0.80), width: 1.25)
-        HomeDashboardStyle.line(from: face.point(1046, 123), to: face.point(1024, 175), color: rim.withAlphaComponent(0.65), width: 1.25)
-        let leftRim = face.path([(454.5, 123), (455.8, 123), (362.8, 309), (361.5, 309)])
+        let cut = HomeDashboardStyle.edgeOffset(for: plate.height)
+        let topLeft = NSPoint(x: plate.minX + cut, y: plate.minY)
+        let topRight = NSPoint(x: plate.maxX, y: plate.minY)
+        let joinY = face.totals.minY
+        let joinX = plate.maxX - HomeDashboardStyle.edgeOffset(for: joinY - plate.minY)
+        HomeDashboardStyle.line(from: topLeft, to: topRight, color: rim.withAlphaComponent(0.80), width: 1.25)
+        HomeDashboardStyle.line(from: topRight, to: NSPoint(x: joinX, y: joinY), color: rim.withAlphaComponent(0.65), width: 1.25)
+        let leftRim = HomeDashboardStyle.slant(NSRect(x: plate.minX - 0.625, y: plate.minY,
+                                                      width: cut + 1.25, height: plate.height))
         NSGradient(colors: [rim, rim.withAlphaComponent(0.58), rim.withAlphaComponent(0)])?.draw(in: leftRim, angle: 90)
 
-        HomeDashboardStyle.cyan.setFill()
         for x: CGFloat in [482, 498] {
-            face.path([(x + 10, 138), (x + 24, 138), (x + 14, 158), (x, 158)]).fill()
+            var mark = face.box(x, 138, width: 14, height: 20)
+            mark.size.width += HomeDashboardStyle.edgeOffset(for: mark.height)
+            HomeDashboardStyle.mark(in: mark)
         }
         let caption = face.box(535, 123, width: 478, height: 52)
         let size = GameLobbyStyle.fittedSize(modeCaption, width: caption.width,
@@ -148,14 +179,18 @@ final class HomeChallengeHUDView: NSView {
             let trackY = body.maxY - 8
             let track = NSRect(x: x, y: trackY, width: right - x, height: 3)
             drawTrack(track, accent: accent, snapshot: snapshot)
+            let separatorTop = body.minY + 8
+            let separatorBottom = trackY - 6
+            let separatorOffset = HomeDashboardStyle.edgeOffset(for: separatorBottom - separatorTop) / 2
+            let columnPadding = separatorOffset + 5
             let metricY = body.midY - 4
             drawStackedMetric(budgetText, labelKey: budgetLabelKey, center: metricY, x: x,
-                              width: split - x - 8, height: body.height, color: accent, alignment: .left)
+                              width: split - x - columnPadding, height: body.height, color: accent, alignment: .left)
             drawStackedMetric(String(snapshot.totalCleared), labelKey: "home.cleared_title", center: metricY,
-                              x: split + 8, width: right - split - 8, height: body.height,
+                              x: split + columnPadding, width: right - split - columnPadding, height: body.height,
                               color: HomeDashboardStyle.ink, alignment: .right)
-            HomeDashboardStyle.line(from: NSPoint(x: split + 5, y: body.minY + 8),
-                                    to: NSPoint(x: split - 5, y: trackY - 6), color: HomeDashboardStyle.border)
+            HomeDashboardStyle.line(from: NSPoint(x: split + separatorOffset, y: separatorTop),
+                                    to: NSPoint(x: split - separatorOffset, y: separatorBottom), color: HomeDashboardStyle.border)
         } else {
             let title = AchievementText.string("home.cleared_title")
             let titleWidth = available * 0.48
@@ -166,7 +201,7 @@ final class HomeChallengeHUDView: NSView {
             let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth - 8,
                                                  preferred: max(24, 58 * face.typographyScale), minimum: 12, weight: .black)
             count(value, in: NSRect(x: x + titleWidth, y: body.minY - 1, width: available - titleWidth, height: body.height),
-                  size: size, weight: .black, italic: true, alignment: .right)
+                  size: size, weight: .black, alignment: .right)
         }
     }
 
@@ -179,34 +214,37 @@ final class HomeChallengeHUDView: NSView {
                                                    minimum: 11, weight: .heavy)
         label(title, x: x, y: center - height * 0.24, width: width, size: titleSize, weight: .semibold,
               color: HomeDashboardStyle.muted, alignment: alignment)
-        label(value, x: x, y: center + height * 0.11, width: width, size: valueSize, weight: .heavy,
-              color: color, italic: true, alignment: alignment)
+        let number = NSRect(x: x, y: center - height * 0.39, width: width, height: height)
+        count(value, in: number, size: valueSize, weight: .heavy, color: color, alignment: alignment)
     }
 
     private func drawBreakdown(_ snapshot: GameSnapshot, on face: Face) {
         // 各分格用独立轮廓，双斜边之间留出原稿中的暗缝。
-        let cells: [(kind: PieceKind, left: CGFloat, right: CGFloat, icon: CGFloat, value: CGFloat)] = [
-            (.orangeRicky, 434, 571, 448, 502),
-            (.blueRicky, 581, 716, 589, 644),
-            (.clevelandZ, 726, 864, 734, 787),
-            (.rhodeIslandZ, 875, 997, 882, 936),
-        ]
+        let cells = face.breakdownCellRects
         let rim = HomeDashboardStyle.color(0x55616A)
-        for cell in cells {
-            let shape = face.path([(cell.left, 255), (cell.right, 255), (cell.right - 24, 308), (cell.left - 24, 308)])
+        for (kind, cell) in zip(PieceKind.allCases, cells) {
+            let shape = HomeDashboardStyle.slant(cell)
             fill(shape, colors: [HomeDashboardStyle.color(0x202B34), HomeDashboardStyle.color(0x121E29)],
                  angle: 21, border: rim)
-            var icon = face.box(cell.icon, 266, width: 42, height: 30)
-            // 高度先触顶时收窄图标框，图案仍从原稿对应的左侧位置起画。
-            icon.size.width = min(icon.width, icon.height * 42 / 30)
-            HomeLobbyArtwork.drawPiece(cell.kind, in: icon)
-            let number = String(snapshot.clearedByKind[cell.kind, default: 0])
-            let slot = face.box(cell.value, 255, width: cell.right - 15 - cell.value, height: 53)
+            let cut = HomeDashboardStyle.edgeOffset(for: cell.height)
+            let padding = min(24, (cell.width - cut) * 0.18)
+            let content = cell.insetBy(dx: cut / 2 + padding, dy: 0)
+            // 图标按较短一边等比缩放，四格的图标起点和数字间距使用相同规则。
+            let scale = face.typographyScale
+            let icon = NSRect(x: content.minX, y: cell.midY - 15 * scale, width: 42 * scale, height: 30 * scale)
+            HomeLobbyArtwork.drawPiece(kind, in: icon)
+            let number = String(snapshot.clearedByKind[kind, default: 0])
+            let numberX = icon.maxX + 12 * scale
+            let slot = NSRect(x: numberX, y: cell.minY, width: max(0, content.maxX - numberX), height: cell.height)
             let size = GameLobbyStyle.fittedSize(number, width: slot.width, preferred: max(11, 21 * face.typographyScale),
                                                  minimum: 7, weight: .semibold)
             count(number, in: slot, size: size, weight: .semibold)
         }
-        HomeDashboardStyle.line(from: face.point(410, 308), to: face.point(973, 308), color: rim)
+        if let first = cells.first, let last = cells.last {
+            let right = last.maxX - HomeDashboardStyle.edgeOffset(for: last.height)
+            HomeDashboardStyle.line(from: NSPoint(x: first.minX, y: first.maxY),
+                                    to: NSPoint(x: right, y: last.maxY), color: rim)
+        }
     }
 
     private func fill(_ shape: NSBezierPath, colors: [NSColor], angle: CGFloat, border: NSColor) {
@@ -217,7 +255,7 @@ final class HomeChallengeHUDView: NSView {
     }
 
     private func count(_ value: String, in slot: NSRect, size: CGFloat, weight: NSFont.Weight,
-                       italic: Bool = false, alignment: NSTextAlignment = .left) {
+                       color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .left) {
         guard slot.width > 0 else { return }
         let font = NSFont.systemFont(ofSize: size, weight: weight)
         let width = max(slot.width, ceil((value as NSString).size(withAttributes: [.font: font]).width) + 2)
@@ -227,15 +265,15 @@ final class HomeChallengeHUDView: NSView {
         fit.translateX(by: slot.minX, yBy: 0)
         fit.scaleX(by: slot.width / width, yBy: 1)
         fit.concat()
-        label(value, x: 0, y: slot.midY, width: width, size: size, weight: weight, italic: italic, alignment: alignment)
+        label(value, x: 0, y: slot.midY, width: width, size: size, weight: weight, color: color, alignment: alignment)
         NSGraphicsContext.restoreGraphicsState()
     }
 
     private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight,
-                       color: NSColor = HomeDashboardStyle.ink, italic: Bool = false, alignment: NSTextAlignment = .left) {
+                       color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .left) {
         let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).height)
         HomeDashboardStyle.text(value, in: NSRect(x: x, y: y - height / 2, width: width, height: height + 1),
-                                size: size, weight: weight, color: color, italic: italic, alignment: alignment)
+                                size: size, weight: weight, color: color, alignment: alignment)
     }
 
     private func drawRevealHighlight(in face: NSRect, outline: NSBezierPath, accent: NSColor, fraction: CGFloat) {
@@ -244,28 +282,37 @@ final class HomeChallengeHUDView: NSView {
         guard intensity > 0 else { return }
         NSGraphicsContext.saveGraphicsState()
         outline.addClip()
-        let width = min(140, face.width * 0.32)
+        let width = min(140, face.width * 0.32) + HomeDashboardStyle.edgeOffset(for: face.height)
         let x = face.maxX + width - (face.width + width * 2) * fraction
         let beam = NSRect(x: x, y: face.minY, width: width, height: face.height)
         NSGradient(colors: [.clear, accent.withAlphaComponent(0.22 * intensity), .clear])?
-            .draw(in: HomeDashboardStyle.slant(beam, cut: width * 0.4), angle: 0)
+            .draw(in: HomeDashboardStyle.slant(beam), angle: 0)
         NSGraphicsContext.restoreGraphicsState()
     }
 
     private func drawTrack(_ track: NSRect, accent: NSColor, snapshot: GameSnapshot) {
-        HomeDashboardStyle.muted.withAlphaComponent(0.18).setFill()
-        NSBezierPath(roundedRect: track, xRadius: 2.5, yRadius: 2.5).fill()
+        let idleColor = HomeDashboardStyle.muted.withAlphaComponent(0.18)
         if mode == .moves {
             // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
-            let gap = min(2, track.width / 60)
-            let width = (track.width - gap * CGFloat(HomeGameMode.moveLimit - 1)) / CGFloat(HomeGameMode.moveLimit)
-            for index in 0..<max(0, min(HomeGameMode.moveLimit, snapshot.remainingSwaps ?? 0)) {
-                accent.setFill()
-                NSBezierPath(roundedRect: NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY, width: width, height: track.height), xRadius: 1.5, yRadius: 1.5).fill()
+            let limit = HomeGameMode.moveLimit
+            let remaining = snapshot.remainingSwaps ?? limit
+            let cut = HomeDashboardStyle.edgeOffset(for: track.height)
+            let available = max(0, track.width - cut)
+            let gap = min(2, available / CGFloat(limit * 2))
+            let width = (available - gap * CGFloat(limit - 1)) / CGFloat(limit)
+            for index in 0..<limit {
+                let segment = NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY,
+                                     width: width + cut, height: track.height)
+                (index < remaining ? accent : idleColor).setFill()
+                HomeDashboardStyle.slant(segment).fill()
             }
-        } else if remainingFraction > 0 {
-            GameLobbyStyle.gradient(NSRect(x: track.minX, y: track.minY, width: track.width * remainingFraction, height: track.height),
-                                    colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent], radius: 2.5)
+        } else {
+            idleColor.setFill()
+            HomeDashboardStyle.slant(track).fill()
+            let fill = HomeDashboardStyle.segmentFill(track, fraction: remainingFraction)
+            guard !fill.isEmpty else { return }
+            NSGradient(colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent])?
+                .draw(in: fill, angle: 90)
         }
     }
 }
diff --git a/Sources/HomeDashboardStyle.swift b/Sources/HomeDashboardStyle.swift
index f3cb547221035e0b8b2990e0d2563bbb86e1bf77..f03ad9ea13996d7980dbbeb7a3e7734484e712e2 100644
--- a/Sources/HomeDashboardStyle.swift
+++ b/Sources/HomeDashboardStyle.swift
@@ -10,6 +10,9 @@ enum HomeDashboardStyle {
     static let green = color(0x59EF86)
     static let border = color(0x526779)
     static let panel = color(0x172636)
+    // 以每点垂直距离对应的水平偏移定义斜边，组件尺寸变化时角度保持一致。
+    static let slope: CGFloat = 0.45
+    static let letterSlant: CGFloat = 0.19
 
     static func color(_ rgb: UInt32) -> NSColor {
         NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
@@ -17,22 +20,50 @@ enum HomeDashboardStyle {
                 blue: CGFloat(rgb & 255) / 255, alpha: 1)
     }
 
-    static func slant(_ rect: NSRect, cut: CGFloat, reverse: Bool = false) -> NSBezierPath {
-        let path = NSBezierPath()
-        let inset = min(max(0, cut), max(0, rect.width))
+    static func edgeOffset(for height: CGFloat) -> CGFloat { max(0, height) * slope }
+
+    private static func corners(of rect: NSRect, reverse: Bool = false) -> [NSPoint] {
+        let inset = edgeOffset(for: rect.height)
+        guard rect.height > 0, rect.width > inset else { return [] }
         let top = reverse ? 0 : inset
         let bottom = reverse ? inset : 0
-        path.move(to: NSPoint(x: rect.minX + top, y: rect.minY))
-        path.line(to: NSPoint(x: rect.maxX - bottom, y: rect.minY))
-        path.line(to: NSPoint(x: rect.maxX - top, y: rect.maxY))
-        path.line(to: NSPoint(x: rect.minX + bottom, y: rect.maxY))
+        return [
+            NSPoint(x: rect.minX + top, y: rect.minY), NSPoint(x: rect.maxX - bottom, y: rect.minY),
+            NSPoint(x: rect.maxX - top, y: rect.maxY), NSPoint(x: rect.minX + bottom, y: rect.maxY),
+        ]
+    }
+
+    static func slant(_ rect: NSRect, reverse: Bool = false) -> NSBezierPath {
+        let path = NSBezierPath()
+        let vertices = corners(of: rect, reverse: reverse)
+        guard let first = vertices.first else { return path }
+        path.move(to: first)
+        for point in vertices.dropFirst() { path.line(to: point) }
         path.close()
         return path
     }
 
-    static func surface(_ rect: NSRect, cut: CGFloat, colors: [NSColor], border: NSColor, lineWidth: CGFloat = 1) {
+    static func cgSlant(_ rect: NSRect) -> CGPath {
+        let path = CGMutablePath()
+        let vertices = corners(of: rect)
+        guard !vertices.isEmpty else { return path }
+        path.addLines(between: vertices)
+        path.closeSubpath()
+        return path
+    }
+
+    /// 进度按平行四边形的净宽计算，任意完成度下填充末端都与轨道斜边平行。
+    static func segmentFill(_ rect: NSRect, fraction: CGFloat) -> NSBezierPath {
+        let inset = edgeOffset(for: rect.height)
+        guard fraction > 0, rect.width > inset else { return NSBezierPath() }
+        let width = inset + (rect.width - inset) * min(1, fraction)
+        return slant(NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
+    }
+
+    static func surface(_ rect: NSRect, colors: [NSColor], border: NSColor, lineWidth: CGFloat = 1) {
         guard rect.width > lineWidth, rect.height > lineWidth else { return }
-        let face = slant(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cut: cut)
+        let face = slant(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
+        guard !face.isEmpty else { return }
         NSGradient(colors: colors)?.draw(in: face, angle: 20)
         border.setStroke()
         face.lineWidth = lineWidth
@@ -48,15 +79,22 @@ enum HomeDashboardStyle {
         path.stroke()
     }
 
+    static func diagonal(from top: NSPoint, height: CGFloat, color: NSColor, width: CGFloat = 1) {
+        line(from: top, to: NSPoint(x: top.x - edgeOffset(for: height), y: top.y + height), color: color, width: width)
+    }
+
+    static func textAttributes(font: NSFont, color: NSColor = ink) -> [NSAttributedString.Key: Any] {
+        [.font: font, .foregroundColor: color, .obliqueness: letterSlant]
+    }
+
     static func text(_ value: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
-                     color: NSColor = ink, italic: Bool = false, alignment: NSTextAlignment = .left) {
+                     color: NSColor = ink, alignment: NSTextAlignment = .left) {
         let paragraph = NSMutableParagraphStyle()
         paragraph.alignment = alignment
         paragraph.lineBreakMode = .byTruncatingTail
-        (value as NSString).draw(in: rect, withAttributes: [
-            .font: NSFont.systemFont(ofSize: size, weight: weight),
-            .foregroundColor: color, .paragraphStyle: paragraph, .obliqueness: italic ? 0.19 : 0,
-        ])
+        var attributes = textAttributes(font: .systemFont(ofSize: size, weight: weight), color: color)
+        attributes[.paragraphStyle] = paragraph
+        (value as NSString).draw(in: rect, withAttributes: attributes)
     }
 
     static func description(_ value: String, in rect: NSRect, preferred: CGFloat) {
@@ -66,7 +104,7 @@ enum HomeDashboardStyle {
         var size = max(9, preferred)
         let text = value as NSString
         let constraint = NSSize(width: max(1, rect.width), height: .greatestFiniteMagnitude)
-        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: muted, .paragraphStyle: paragraph]
+        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: muted, .paragraphStyle: paragraph, .obliqueness: letterSlant]
         while true {
             attributes[.font] = NSFont.systemFont(ofSize: size)
             if size <= 9 || ceil(text.boundingRect(with: constraint, options: options, attributes: attributes).height) <= rect.height {
@@ -79,7 +117,7 @@ enum HomeDashboardStyle {
 
     static func mark(in rect: NSRect, color: NSColor = cyan) {
         color.setFill()
-        slant(rect, cut: rect.width * 0.48).fill()
+        slant(rect).fill()
     }
 
     static func backdrop(in rect: NSRect) {
@@ -105,10 +143,10 @@ enum HomeDashboardStyle {
         ]
         for (x, y, width, alpha) in bands {
             let band = NSRect(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y,
-                              width: rect.width * (width + 0.38), height: rect.height)
+                              width: rect.width * width + edgeOffset(for: rect.height), height: rect.height)
             NSGradient(colors: [color(0x355474).withAlphaComponent(alpha),
                                 color(0x355474).withAlphaComponent(alpha * 0.19)])?
-                .draw(in: slant(band, cut: rect.width * 0.38), angle: 73)
+                .draw(in: slant(band), angle: 73)
         }
     }
 }
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 59aabc628715f0da0691bc127035b3547759c04e..c527472cdc477a3c7bf59e3908d06c7a09529c70 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -24,7 +24,7 @@ class HomeButton: NSButton {
     override var isHighlighted: Bool { didSet { refreshFeedback() } }
     override var focusRingMaskBounds: NSRect { bounds }
     override func drawFocusRingMask() {
-        HomeDashboardStyle.slant(bounds, cut: bounds.height * 0.48).fill()
+        HomeDashboardStyle.slant(bounds).fill()
     }
     override func resetCursorRects() {
         if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
@@ -61,18 +61,18 @@ class HomeButton: NSButton {
             glow.shadowBlurRadius = 10
             glow.set()
             yellow.setFill()
-            HomeDashboardStyle.slant(face, cut: face.height * 0.54).fill()
+            HomeDashboardStyle.slant(face).fill()
             NSGraphicsContext.restoreGraphicsState()
-            HomeDashboardStyle.surface(face, cut: face.height * 0.54,
+            HomeDashboardStyle.surface(face,
                                        colors: [HomeDashboardStyle.color(0xFFF87D), yellow, HomeDashboardStyle.color(0xF1CD23)],
                                        border: .white.withAlphaComponent(isEnabled ? 0.56 : 0.24))
             if !isEnabled {
                 HomeDashboardStyle.navy.withAlphaComponent(0.36).setFill()
-                HomeDashboardStyle.slant(face, cut: face.height * 0.54).fill()
+                HomeDashboardStyle.slant(face).fill()
             }
         } else if outlined || effect.hover > 0 {
             let cyan = HomeDashboardStyle.cyan
-            HomeDashboardStyle.surface(face, cut: face.height * 0.46,
+            HomeDashboardStyle.surface(face,
                                        colors: [cyan.withAlphaComponent(effect.hover * 0.10),
                                                 cyan.withAlphaComponent(0.04 + effect.hover * 0.14)],
                                        border: cyan.withAlphaComponent(outlined ? 0.95 : effect.hover * 0.45),
@@ -94,7 +94,7 @@ class HomeButton: NSButton {
         }
         let textX = style == .achievementLink ? x : x + icon + gap
         HomeDashboardStyle.text(label, in: NSRect(x: textX, y: face.midY - size * 0.63, width: width + 8, height: size * 1.5),
-                                size: size, weight: weight, color: color, italic: !outlined)
+                                size: size, weight: weight, color: color)
     }
     @objc private func clicked() { onClick?() }
 }
@@ -134,15 +134,14 @@ final class HomeModeButton: HomeButton {
         let colors = [left.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0C3E46)) ?? left,
                       right.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0A2733)) ?? right]
         let stroke = HomeDashboardStyle.border.blended(withFraction: tint, of: cyan) ?? cyan
-        HomeDashboardStyle.surface(face, cut: face.height * 0.41, colors: colors, border: stroke,
+        HomeDashboardStyle.surface(face, colors: colors, border: stroke,
                                    lineWidth: 1 + 1.7 * effect.selection)
         let iconSize = min(48, face.height * 0.56)
         let icon = NSRect(x: face.minX + face.height * 0.57, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
         drawModeIcon(in: icon, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
         let splitX = icon.maxX + face.height * 0.26
-        HomeDashboardStyle.line(from: NSPoint(x: splitX, y: face.midY - iconSize / 2),
-                                to: NSPoint(x: splitX - 10, y: face.midY + iconSize / 2),
-                                color: HomeDashboardStyle.border, width: 1.2)
+        HomeDashboardStyle.diagonal(from: NSPoint(x: splitX, y: face.midY - iconSize / 2),
+                                    height: iconSize, color: HomeDashboardStyle.border, width: 1.2)
         let textX = splitX + 13
         let textWidth = face.maxX - textX - max(31, face.height * 0.67)
         let title = AchievementText.string(titleKey)
@@ -150,7 +149,7 @@ final class HomeModeButton: HomeButton {
                                                   minimum: 13, weight: .heavy)
         let textY = face.midY - titleSize * 1.15
         HomeDashboardStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: titleSize * 1.5),
-                                size: titleSize, weight: .heavy, italic: true)
+                                size: titleSize, weight: .heavy)
         let description = AchievementText.string(descriptionKey)
         let descriptionY = face.midY + 1
         let descriptionWidth = face.maxX - textX - max(18, face.height * 0.49)
@@ -264,23 +263,26 @@ private final class HomeAchievementButton: HomeButton {
     override func draw(_ dirtyRect: NSRect) {
         guard let definition else { return }
         let effect = feedback.values
-        let cut = bounds.height * 0.43
         let border = HomeDashboardStyle.border.blended(withFraction: effect.hover * 0.66, of: HomeDashboardStyle.cyan) ?? HomeDashboardStyle.border
         HomeDashboardStyle.surface(bounds.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: effect.press),
-                                   cut: cut, colors: [HomeDashboardStyle.color(0x212D37), HomeDashboardStyle.color(0x101B26)],
+                                   colors: [HomeDashboardStyle.color(0x212D37), HomeDashboardStyle.color(0x101B26)],
                                    border: border)
         let title = AchievementText.string(definition.titleKey)
-        let font = NSFont.systemFont(ofSize: min(17, max(12, bounds.height * 0.28)), weight: .bold)
-        let attributes: [NSAttributedString.Key: Any] = [.font: font]
         // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
-        // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
+        // 窄窗口先缩小字级，再按完整字符截短，避免较短的名称也出现省略号。
         let key = "\(definition.id).\(unlocked)"
         let color = unlocked ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
         let artwork = Self.icon(for: definition, color: color, key: key)
         let artworkBounds = Self.visibleBounds(of: artwork, key: key)
         let fixedWidth = ceil(artworkBounds.width) + 9
         // 覆盖状态图标及抗锯齿边缘，并为图文居中在另一侧预留同等空间。
-        let availableWidth = max(0, floor(bounds.width - 36 * 2 - fixedWidth))
+        let statusX = max(14, HomeDashboardStyle.edgeOffset(for: bounds.height / 2) + 4)
+        let availableWidth = max(0, floor(bounds.width - (statusX + 22) * 2 - fixedWidth))
+        let preferredSize = min(17, max(12, bounds.height * 0.28))
+        let titleSize = GameLobbyStyle.fittedSize(title, width: availableWidth - 2, preferred: preferredSize,
+                                                  minimum: 12, weight: .bold)
+        let font = NSFont.systemFont(ofSize: titleSize, weight: .bold)
+        let attributes: [NSAttributedString.Key: Any] = [.font: font]
         var characters = Array(title), displayedTitle = title
         while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
             characters.removeLast()
@@ -291,11 +293,12 @@ private final class HomeAchievementButton: HomeButton {
             .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
         ]))
         // 按截断后字形的实际轮廓居中，兼顾没有下伸笔画的标题和各语言的字体回退。
-        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
+        let tilt = CGAffineTransform(a: 1, b: 0, c: HomeDashboardStyle.letterSlant, d: 1, tx: 0, ty: 0)
+        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).applying(tilt)
         let titleWidth = displayedTitle.isEmpty || textBounds.isNull ? 0 : textBounds.width
         let startX = bounds.midX - (fixedWidth + titleWidth) / 2
         let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
-        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18),
+        HomeStyle.symbol(status, in: NSRect(x: statusX, y: bounds.midY - 9, width: 18, height: 18),
                          color: unlocked ? HomeDashboardStyle.green : HomeDashboardStyle.muted)
         artwork.draw(in: NSRect(x: startX - artworkBounds.minX, y: bounds.midY - artworkBounds.midY,
                                width: Self.iconSize, height: Self.iconSize),
@@ -305,7 +308,7 @@ private final class HomeAchievementButton: HomeButton {
             // 当前视图的 y 向下，文字绘制坐标的 y 向上。
             context.translateBy(x: startX + fixedWidth - textBounds.minX, y: bounds.midY + textBounds.midY)
             context.scaleBy(x: 1, y: -1)
-            context.textMatrix = .identity
+            context.textMatrix = tilt
             context.textPosition = .zero
             CTLineDraw(line, context)
             context.restoreGState()
@@ -432,7 +435,7 @@ final class HomeAchievementPathView: NSView {
         let size: CGFloat = bounds.width < 1050 ? 21 : 25
         let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).width)
         HomeDashboardStyle.text(title, in: NSRect(x: 27, y: 13, width: titleWidth + 12, height: 36),
-                                size: size, weight: .heavy, italic: true)
+                                size: size, weight: .heavy)
         let count = AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count)
         let countSize: CGFloat = bounds.width < 1050 ? 13 : 17
         let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: countSize, weight: .semibold)]).width)
@@ -443,25 +446,21 @@ final class HomeAchievementPathView: NSView {
         let meter = NSRect(x: meterX, y: 24, width: min(bounds.width * 0.21, max(0, all.frame.minX - meterX - 78)), height: 12)
         let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
         let countSegments = 10
-        let pitch = max(0, meter.width - 10) / CGFloat(countSegments)
-        for index in 0..<countSegments where pitch > 2 {
+        let gap: CGFloat = 2
+        let inset = HomeDashboardStyle.edgeOffset(for: meter.height)
+        let pitch = (meter.width - inset + gap) / CGFloat(countSegments)
+        for index in 0..<countSegments where pitch > gap {
             let segment = NSRect(x: meter.minX + CGFloat(index) * pitch, y: meter.minY,
-                                 width: pitch + 8, height: meter.height)
-            let face = HomeDashboardStyle.slant(segment, cut: 10)
+                                 width: pitch - gap + inset, height: meter.height)
             HomeDashboardStyle.border.setFill()
-            face.fill()
-            let fill = min(1, max(0, ratio * CGFloat(countSegments) - CGFloat(index)))
-            if fill > 0 {
-                NSGraphicsContext.saveGraphicsState()
-                face.addClip()
-                HomeDashboardStyle.yellow.setFill()
-                NSRect(x: segment.minX, y: segment.minY, width: fill * segment.width, height: segment.height).fill()
-                NSGraphicsContext.restoreGraphicsState()
-            }
+            HomeDashboardStyle.slant(segment).fill()
+            let fill = ratio * CGFloat(countSegments) - CGFloat(index)
+            HomeDashboardStyle.yellow.setFill()
+            HomeDashboardStyle.segmentFill(segment, fraction: fill).fill()
         }
         let percentage = Double(ratio).formatted(.percent.precision(.fractionLength(1)).locale(Localizer.shared.locale))
         HomeDashboardStyle.text(percentage, in: NSRect(x: meter.maxX + 15, y: 19, width: 58, height: 23),
-                                size: min(16, countSize), weight: .semibold, italic: true)
+                                size: min(16, countSize), weight: .semibold)
     }
 }
 
@@ -498,9 +497,6 @@ final class HomeDashboardView: NSView {
         appearance = NSAppearance(named: .darkAqua)
         hint.isSelectable = false
         hint.drawsBackground = false
-        hint.textColor = HomeDashboardStyle.ink
-        hint.font = .systemFont(ofSize: 14, weight: .medium)
-        hint.alignment = .center
         // 右侧模式列表以相同背景遮住跨入右栏的统计卡，原生控件继续处理点击和键盘焦点。
         [hero, guide, hint, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
         startButton.style = .primary
@@ -533,7 +529,7 @@ final class HomeDashboardView: NSView {
         }
         let shortcutAvailable = !isStarting && !snapshot.isRunning
         if hint.stringValue != status || showsShortcut != shortcutAvailable {
-            hint.stringValue = status
+            updateHint(status)
             hint.isHidden = status.isEmpty
             showsShortcut = shortcutAvailable
             setNeedsDisplay(hint.frame.insetBy(dx: -22, dy: 0).union(shortcut))
@@ -593,7 +589,7 @@ final class HomeDashboardView: NSView {
         guide.frame = NSRect(x: margin, y: guideY, width: artworkWidth, height: guideHeight)
 
         hint.preferredMaxLayoutWidth = buttonWidth + 100
-        hint.font = .systemFont(ofSize: min(16, max(12, bounds.width * 0.010)), weight: .medium)
+        updateHint(hint.stringValue)
         hint.frame = NSRect(x: startButton.frame.midX - hint.preferredMaxLayoutWidth / 2, y: stageBottom + 8,
                             width: hint.preferredMaxLayoutWidth, height: max(0, achievementTop - stageBottom - 10))
         achievementPath.frame = NSRect(x: margin, y: achievementTop, width: bounds.width - margin * 2,
@@ -621,21 +617,25 @@ final class HomeDashboardView: NSView {
         drawNavigation()
 
         let cyan = HomeDashboardStyle.cyan
-        let dividerStart = NSPoint(x: modePanel.frame.minX - 5, y: headerHeight + 13)
-        let dividerEnd = NSPoint(x: modePanel.frame.minX - bounds.height * 0.12, y: achievementTop)
-        HomeDashboardStyle.line(from: dividerStart, to: dividerEnd, color: HomeDashboardStyle.border.withAlphaComponent(0.5))
-        let middle = NSPoint(x: (dividerStart.x + dividerEnd.x) / 2, y: (dividerStart.y + dividerEnd.y) / 2)
-        HomeDashboardStyle.line(from: dividerStart, to: middle, color: cyan.withAlphaComponent(0.22))
+        let dividerY = sectionTop + 12
+        let dividerX = modePanel.frame.minX - 1
+        let artworkRight = max(hero.frame.maxX, guide.frame.maxX) + 8
+        // 分隔线在进入左侧插画之前收尾，避免统一斜角后穿过方块。
+        let dividerHeight = max(0, min(achievementTop - dividerY, (dividerX - artworkRight) / HomeDashboardStyle.slope))
+        let dividerTop = NSPoint(x: dividerX, y: dividerY)
+        HomeDashboardStyle.diagonal(from: dividerTop, height: dividerHeight, color: HomeDashboardStyle.border.withAlphaComponent(0.5))
+        HomeDashboardStyle.diagonal(from: dividerTop, height: dividerHeight / 2, color: cyan.withAlphaComponent(0.22))
         HomeDashboardStyle.line(from: NSPoint(x: contactPanel.frame.minX + 28, y: contactPanel.frame.minY - 24),
                                 to: NSPoint(x: contactPanel.frame.maxX, y: contactPanel.frame.minY - 24),
                                 color: HomeDashboardStyle.border.withAlphaComponent(0.77))
         if showsShortcut {
-            HomeDashboardStyle.surface(shortcut, cut: 12, colors: [HomeDashboardStyle.color(0x1B2632), HomeDashboardStyle.navy],
+            HomeDashboardStyle.surface(shortcut, colors: [HomeDashboardStyle.color(0x1B2632), HomeDashboardStyle.navy],
                                        border: HomeDashboardStyle.muted)
             HomeDashboardStyle.text(AchievementText.string("home.space_key"),
-                                    in: shortcut.offsetBy(dx: 0, dy: 4), size: 13, weight: .bold, italic: true, alignment: .center)
+                                    in: shortcut.offsetBy(dx: 0, dy: 4), size: 13, weight: .bold, alignment: .center)
         }
-        if !hint.isHidden, let font = hint.font {
+        if !hint.isHidden {
+            let font = hintFont
             let width = (hint.stringValue as NSString).size(withAttributes: [.font: font]).width
             let x = hint.frame.midX - min(width, hint.frame.width) / 2 - 20
             HomeDashboardStyle.mark(in: NSRect(x: x, y: hint.frame.minY + 3, width: 10, height: font.pointSize + 1))
@@ -647,6 +647,18 @@ final class HomeDashboardView: NSView {
         needsLayout = true
     }
 
+    private var hintFont: NSFont {
+        .systemFont(ofSize: min(16, max(12, bounds.width * 0.010)), weight: .medium)
+    }
+
+    private func updateHint(_ value: String) {
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.alignment = .center
+        var attributes = HomeDashboardStyle.textAttributes(font: hintFont)
+        attributes[.paragraphStyle] = paragraph
+        hint.attributedStringValue = NSAttributedString(string: value, attributes: attributes)
+    }
+
     private func drawNavigation() {
         let y = headerHeight / 2
         let logoX = margin + 12
@@ -657,8 +669,8 @@ final class HomeDashboardView: NSView {
             HomeDashboardStyle.mark(in: tile, color: HomeDashboardStyle.color(rgb))
         }
         let slashX = logoX + 72
-        HomeDashboardStyle.line(from: NSPoint(x: slashX + 11, y: y - 16), to: NSPoint(x: slashX, y: y + 16),
-                                color: HomeDashboardStyle.muted.withAlphaComponent(0.62), width: 1.3)
+        HomeDashboardStyle.diagonal(from: NSPoint(x: slashX + HomeDashboardStyle.edgeOffset(for: 32), y: y - 16),
+                                    height: 32, color: HomeDashboardStyle.muted.withAlphaComponent(0.62), width: 1.3)
 
         let brand = AchievementText.string("home.brand")
         let brandX = slashX + 27
@@ -667,10 +679,10 @@ final class HomeDashboardView: NSView {
         let size = GameLobbyStyle.fittedSize(brand, width: brandWidth - 10, preferred: preferred, minimum: 16, weight: .black)
         let measuredWidth = (brand as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .black)]).width
         HomeDashboardStyle.text(brand, in: NSRect(x: brandX, y: y - size * 0.65, width: brandWidth, height: size * 1.52),
-                                size: size, weight: .black, italic: true)
+                                size: size, weight: .black)
         if brandWidth - measuredWidth > 132, bounds.width >= 1050 {
             HomeDashboardStyle.text("TOUCH BAR", in: NSRect(x: brandX + measuredWidth + 23, y: y - 8, width: 99, height: 19),
-                                    size: 13, weight: .medium, color: HomeDashboardStyle.muted, italic: true)
+                                    size: 13, weight: .medium, color: HomeDashboardStyle.muted)
         }
         for button in [rules, settings] {
             HomeDashboardStyle.mark(in: NSRect(x: button.frame.minX - 15, y: y - 8, width: 11, height: 17))
@@ -703,7 +715,7 @@ final class HomeModePanelView: NSView {
         HomeDashboardStyle.mark(in: NSRect(x: 26, y: 7, width: 21, height: size * 0.83))
         HomeDashboardStyle.text(AchievementText.string("home.game_modes"),
                                 in: NSRect(x: 54, y: 0, width: bounds.width - 60, height: 41),
-                                size: size, weight: .black, italic: true)
+                                size: size, weight: .black)
     }
 }
 
@@ -746,8 +758,8 @@ final class HomeContactPanelView: NSView {
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        let cut = bounds.height * 0.35
-        HomeDashboardStyle.surface(bounds, cut: cut, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
+        let cut = HomeDashboardStyle.edgeOffset(for: bounds.height)
+        HomeDashboardStyle.surface(bounds, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
                                    border: HomeDashboardStyle.color(0x344C65))
         let size = min(43, bounds.height * 0.29)
         let icon = NSRect(x: cut + 11, y: bounds.height * 0.145, width: size, height: size)
diff --git a/Sources/HomeLobbyArtwork.swift b/Sources/HomeLobbyArtwork.swift
index 94ed7f924aa7398a86f72be74b99b1d186171a00..0af5a950cc1c28f11b5eab0cf89a2eb8aba6f26d 100644
--- a/Sources/HomeLobbyArtwork.swift
+++ b/Sources/HomeLobbyArtwork.swift
@@ -52,12 +52,11 @@ enum HomeLobbyArtwork {
         transform.scale(by: scale)
         transform.concat()
 
-        let floor = polygon([NSPoint(x: 59, y: 99), NSPoint(x: 917, y: 99),
-                             NSPoint(x: 888, y: 152), NSPoint(x: 25, y: 152)])
+        // 地面的侧边与大厅卡片共用斜率，插画等比缩放时也保持这个角度。
+        let floor = HomeDashboardStyle.slant(NSRect(x: 25, y: 99, width: 892, height: 53))
         gradient(floor, from: .clear, to: color(0x254350, alpha: 0.43),
                  start: NSPoint(x: 36, y: 130), end: NSPoint(x: 890, y: 147))
-        let floorEdge = polygon([NSPoint(x: 76, y: 150), NSPoint(x: 889, y: 150),
-                                 NSPoint(x: 889, y: 152), NSPoint(x: 76, y: 152)])
+        let floorEdge = HomeDashboardStyle.slant(NSRect(x: 76, y: 150, width: 813, height: 2))
         gradient(floorEdge, from: color(0x5F9CB2, alpha: 0.14), to: .clear,
                  start: NSPoint(x: 76, y: 151), end: NSPoint(x: 889, y: 151))
 
@@ -105,8 +104,7 @@ enum HomeLobbyArtwork {
         transform.scale(by: scale)
         transform.concat()
 
-        let rail = polygon([NSPoint(x: 36, y: 1), NSPoint(x: 924, y: 1),
-                            NSPoint(x: 891, y: 68), NSPoint(x: 1, y: 68)])
+        let rail = HomeDashboardStyle.slant(NSRect(x: 1, y: 1, width: 923, height: 67))
         gradient(rail, from: color(0x040B10), to: color(0x10202A),
                  start: NSPoint(x: 0, y: 0), end: NSPoint(x: 15, y: 68))
         color(0xB7D3DA, alpha: 0.7).setStroke()
@@ -167,8 +165,7 @@ enum HomeLobbyArtwork {
         for index in 0..<3 {
             let x = point.x + CGFloat(index) * 11.0
             let y = point.y - CGFloat(index) * 3.3
-            let path = polygon([NSPoint(x: x + 20, y: y + 7), NSPoint(x: x + 32, y: y + 4),
-                                NSPoint(x: x - 3, y: y + 55), NSPoint(x: x - 13, y: y + 55)])
+            let path = HomeDashboardStyle.slant(NSRect(x: x - 8, y: y + 4, width: 35, height: 51))
             gradient(path, from: color.withAlphaComponent(0.29 + CGFloat(index) * 0.22), to: color.withAlphaComponent(0),
                      start: NSPoint(x: x + 29, y: y + 5), end: NSPoint(x: x - 8, y: y + 51))
         }
@@ -220,17 +217,6 @@ enum HomeLobbyArtwork {
         NSGraphicsContext.restoreGraphicsState()
     }
 
-    private static func polygon(_ points: [NSPoint]) -> NSBezierPath {
-        let path = NSBezierPath()
-        guard let first = points.first else { return path }
-        path.move(to: first)
-        for point in points.dropFirst() {
-            path.line(to: point)
-        }
-        path.close()
-        return path
-    }
-
     private static func gradient(_ path: NSBezierPath, from: NSColor, to: NSColor, start: NSPoint, end: NSPoint) {
         NSGraphicsContext.saveGraphicsState()
         path.addClip()
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 47ff9662a0332a77888c31057963970440b48cb7..da099d6d3086622b7d0d6148d4dd20fcd2608926 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -3,8 +3,7 @@ import Cocoa
 /// 上方文案和本局统计并排排版，切换模式时仅统计卡从右侧滑入。
 final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1
-    private static let fullScale = NSSize(width: 1, height: 1)
-    private static let distantScale = NSSize(width: 0.20, height: 0.27)
+    private static let distantScale: CGFloat = 0.20
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
 
@@ -19,7 +18,7 @@ final class HomeModeHeaderView: NSView {
 
     private struct Pose {
         let offset: CGFloat
-        let scale: NSSize
+        let scale: CGFloat
         let alpha: CGFloat
     }
 
@@ -55,7 +54,7 @@ final class HomeModeHeaderView: NSView {
         let cardHeight = min(186, max(102, leftColumn.height * 0.77))
         let faceX = intro.frame.maxX + gap + HomeChallengeHUDView.trailingInset
         let faceRight = modePanelLeading - min(22, leftColumn.width * 0.031)
-        let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX))
+        let cardX = faceX - HomeChallengeHUDView.leadingInset(for: max(0, faceRight - faceX), height: cardHeight)
         cardColumn = NSRect(x: cardX, y: topPadding + cardTop,
                             width: max(0, faceRight + HomeChallengeHUDView.trailingInset - cardX),
                             height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
@@ -90,7 +89,7 @@ final class HomeModeHeaderView: NSView {
 
     private func animate(reuseIncoming: Bool) {
         // 以卡面宽度为单位记录位置，重设窗口尺寸时进度可按比例继续。
-        let right = visibleRightEdge - cardColumn.width * Self.distantScale.width - 6
+        let right = visibleRightEdge - cardColumn.width * Self.distantScale - 6
         let launchX = min(entryX, right)
         let launch = Pose(offset: (launchX - cardColumn.minX) / cardColumn.width, scale: Self.distantScale, alpha: 0)
         transition = Transition(start: now(), outgoing: pose(of: spareCard), incoming: reuseIncoming ? pose(of: card) : launch)
@@ -114,7 +113,7 @@ final class HomeModeHeaderView: NSView {
 
     private func pose(of view: HomeChallengeHUDView) -> Pose {
         Pose(offset: (view.frame.minX - cardColumn.minX) / cardColumn.width,
-             scale: NSSize(width: view.frame.width / cardColumn.width, height: view.frame.height / cardColumn.height),
+             scale: view.bounds.width > 0 ? view.frame.width / view.bounds.width : 1,
              alpha: view.alphaValue)
     }
 
@@ -153,8 +152,8 @@ final class HomeModeHeaderView: NSView {
 
     private func placeSubviews() {
         guard let transition, cardColumn.width > 0 else {
-            place(card, pose: Pose(offset: 0, scale: Self.fullScale, alpha: 1))
-            place(spareCard, pose: Pose(offset: 0, scale: Self.fullScale, alpha: 1))
+            place(card, pose: Pose(offset: 0, scale: 1, alpha: 1))
+            place(spareCard, pose: Pose(offset: 0, scale: 1, alpha: 1))
             card.revealFraction = nil
             spareCard.revealFraction = nil
             return
@@ -162,9 +161,8 @@ final class HomeModeHeaderView: NSView {
         let t = transition.fraction
         let travel = t * t * (3 - 2 * t)
         let incoming = transition.incoming
-        let scale = NSSize(width: incoming.scale.width + (1 - incoming.scale.width) * travel,
-                           height: incoming.scale.height + (1 - incoming.scale.height) * travel)
-        let rightmostOffset = (bounds.maxX - cardColumn.minX) / cardColumn.width - scale.width
+        let scale = incoming.scale + (1 - incoming.scale) * travel
+        let rightmostOffset = (bounds.maxX - cardColumn.minX) / cardColumn.width - scale
         let offset = min(incoming.offset * (1 - travel), rightmostOffset)
         place(card, pose: Pose(offset: offset, scale: scale, alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(travel)))
         card.revealFraction = travel
@@ -176,10 +174,10 @@ final class HomeModeHeaderView: NSView {
     }
 
     private func place(_ view: HomeChallengeHUDView, pose: Pose) {
-        // 卡片始终使用完整坐标绘制，入场时数字、分格和斜边一起做透视缩放。
+        // 入场全程等比缩放，使卡片斜边和文字角度在移动时也保持一致。
         view.frame = NSRect(x: cardColumn.minX + pose.offset * cardColumn.width,
-                            y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale.height,
-                            width: cardColumn.width * pose.scale.width, height: cardColumn.height * pose.scale.height)
+                            y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale,
+                            width: cardColumn.width * pose.scale, height: cardColumn.height * pose.scale)
         view.bounds = NSRect(origin: .zero, size: cardColumn.size)
         view.alphaValue = pose.alpha
     }
@@ -225,8 +223,7 @@ private final class HomeModeIntroView: NSView {
             size -= 1
             font = .systemFont(ofSize: size, weight: .heavy)
         }
-        let styled = NSMutableAttributedString(string: title, attributes: [.font: font, .foregroundColor: HomeDashboardStyle.ink,
-                                                                          .obliqueness: 0.18])
+        let styled = NSMutableAttributedString(string: title, attributes: HomeDashboardStyle.textAttributes(font: font))
         let divider = (title as NSString).range(of: "\n")
         if divider.location != NSNotFound {
             let start = NSMaxRange(divider)
@@ -245,7 +242,8 @@ private final class HomeModeIntroView: NSView {
             subtitleSize -= 1
             subtitleFont = .systemFont(ofSize: subtitleSize, weight: .medium)
         }
-        subtitle.font = subtitleFont
+        subtitle.attributedStringValue = NSAttributedString(string: subtitle.stringValue,
+            attributes: HomeDashboardStyle.textAttributes(font: subtitleFont, color: HomeDashboardStyle.muted))
         subtitle.preferredMaxLayoutWidth = bounds.width
         let subtitleHeight = min(available, textHeight(subtitle.stringValue, width: textWidth, font: subtitleFont) + 2)
         subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: subtitleHeight)
@@ -261,7 +259,7 @@ private final class HomeModeIntroView: NSView {
         guard !title.isEmpty else { return }
         let width = min(78, bounds.width * 0.25)
         let y = min(bounds.maxY - 4, subtitle.frame.maxY + 11)
-        let underline = HomeDashboardStyle.slant(NSRect(x: 10, y: y, width: width, height: 4), cut: 3)
+        let underline = HomeDashboardStyle.slant(NSRect(x: 10, y: y, width: width, height: 4))
         NSGradient(colors: [HomeDashboardStyle.yellow, HomeDashboardStyle.yellow, .clear])?.draw(in: underline, angle: 0)
     }
 }
diff --git a/Sources/HomeUtilityPanel.swift b/Sources/HomeUtilityPanel.swift
index cb006d37fca31ab44481a3c06d7b53371b39fd78..f3ef67580fab8251a647b845e2b1d7d732da880f 100644
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -13,7 +13,8 @@ final class HomeUtilityPanel: NSWindowController {
     private let content: UtilityPageView
     private let language = UtilityLanguagePopup(frame: .zero, pullsDown: false)
     private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
-    private let percent = UtilityStyle.label("", size: 18, weight: .bold, color: HomeDashboardStyle.yellow)
+    private let percent = UtilityStyle.label("", size: 18, weight: .bold, color: HomeDashboardStyle.yellow,
+                                             alignment: .right, monospacedDigits: true)
     private let recordTabs = AchievementFilterControl(frame: .zero)
     private let recordBody = UtilityStyle.stack([])
     private let store: ModeRecordStore
@@ -37,7 +38,6 @@ final class HomeUtilityPanel: NSWindowController {
         language.focusRingType = .exterior; language.target = self; language.action = #selector(languageChanged)
         volume.cell = UtilityVolumeSliderCell(); volume.minValue = 0; volume.maxValue = 1
         volume.isContinuous = true; volume.target = self; volume.action = #selector(volumeChanged)
-        percent.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold); percent.alignment = .right
         recordTabs.segmentCount = 2; recordTabs.segmentSymbols = [HomeGameMode.timed.symbol, HomeGameMode.moves.symbol]
         recordTabs.selectedSegment = 0; recordTabs.target = self; recordTabs.action = #selector(recordModeChanged)
         // 固定尺寸只注册一次，语言切换时仅重建排版与文案。
@@ -147,7 +147,9 @@ final class HomeUtilityPanel: NSWindowController {
         onLanguage?(AppLanguage.allCases[language.indexOfSelectedItem])
     }
     private func updateVolumeLabel() {
-        percent.stringValue = "\(Int((volume.doubleValue * 100).rounded()))%"; volume.setAccessibilityValue(percent.stringValue)
+        let text = "\(Int((volume.doubleValue * 100).rounded()))%"
+        UtilityStyle.setText(text, on: percent)
+        volume.setAccessibilityValue(text)
     }
     @objc private func volumeChanged() { updateVolumeLabel(); onVolume?(Float(volume.doubleValue)) }
     @objc private func recordModeChanged() {
diff --git a/Sources/HomeUtilityViews.swift b/Sources/HomeUtilityViews.swift
index 707f7e66080980e23f0e2366fd8008fce17a38b1..a63c77f9e502e81435844dc6e8dde8c5ce2dc179 100644
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -3,13 +3,30 @@ import Cocoa
 /// 辅助页共用首页材质；文字使用原生视图，支持换行和辅助功能。
 enum UtilityStyle {
     static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
-                      color: NSColor = HomeDashboardStyle.ink) -> NSTextField {
-        let label = NSTextField(wrappingLabelWithString: text)
-        label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
+                      color: NSColor = HomeDashboardStyle.ink, alignment: NSTextAlignment = .natural,
+                      monospacedDigits: Bool = false) -> NSTextField {
+        let label = NSTextField(wrappingLabelWithString: "")
+        label.font = monospacedDigits ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
+                                      : .systemFont(ofSize: size, weight: weight)
+        label.textColor = color
+        label.alignment = alignment
         label.maximumNumberOfLines = 0
         label.setContentCompressionResistancePriority(.required, for: .vertical)
+        setText(text, on: label)
         return label
     }
+
+    static func setText(_ text: String, on label: NSTextField) {
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.alignment = label.alignment
+        paragraph.lineBreakMode = label.lineBreakMode
+        label.attributedStringValue = NSAttributedString(string: text, attributes: [
+            .font: label.font ?? NSFont.systemFont(ofSize: 13),
+            .foregroundColor: label.textColor ?? HomeDashboardStyle.ink,
+            .paragraphStyle: paragraph,
+            .obliqueness: HomeDashboardStyle.letterSlant,
+        ])
+    }
     static func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 10) -> NSStackView {
         let stack = NSStackView(views: views)
         stack.orientation = vertical ? .vertical : .horizontal
@@ -33,12 +50,33 @@ enum UtilityStyle {
         return view
     }
 
-    static func drawCard(_ rect: NSRect, accent: NSColor? = nil, cut: CGFloat = 10) {
+    static func drawCard(_ rect: NSRect, accent: NSColor? = nil, containsContent: Bool = false) {
         let top = HomeDashboardStyle.panel
         let base = HomeDashboardStyle.color(0x101C28)
         let tint = accent.flatMap { top.blended(withFraction: 0.12, of: $0) } ?? top
         let outline = accent?.withAlphaComponent(0.62) ?? HomeDashboardStyle.border
-        HomeDashboardStyle.surface(rect, cut: cut, colors: [tint, base], border: outline)
+        guard containsContent else {
+            HomeDashboardStyle.surface(rect, colors: [tint, base], border: outline)
+            return
+        }
+        // 长表格和说明保留足够的排版宽度，首尾切角与独立控件使用同一个斜率。
+        let face = rect.insetBy(dx: 0.5, dy: 0.5)
+        guard face.width > 1, face.height > 1 else { return }
+        let height = min(24, face.height)
+        let inset = HomeDashboardStyle.edgeOffset(for: height)
+        guard face.width > inset else { return }
+        let path = NSBezierPath()
+        path.move(to: NSPoint(x: face.minX + inset, y: face.minY))
+        path.line(to: NSPoint(x: face.maxX, y: face.minY))
+        path.line(to: NSPoint(x: face.maxX, y: face.maxY - height))
+        path.line(to: NSPoint(x: face.maxX - inset, y: face.maxY))
+        path.line(to: NSPoint(x: face.minX, y: face.maxY))
+        path.line(to: NSPoint(x: face.minX, y: face.minY + height))
+        path.close()
+        NSGradient(colors: [tint, base])?.draw(in: path, angle: 20)
+        outline.setStroke()
+        path.lineWidth = 1
+        path.stroke()
     }
 }
 
@@ -71,7 +109,7 @@ final class UtilityCard: NSView {
     }
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent) }
+    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent, containsContent: true) }
 }
 
 /// 标题固定、正文独立滚动，在小屏幕与长翻译下不裁切内容。
@@ -120,8 +158,8 @@ final class UtilityPageView: NSView {
     override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) { HomeDashboardStyle.backdrop(in: bounds) }
     func refreshHeader(page: String) {
-        title.stringValue = UtilityStyle.text("panel.\(page)")
-        subtitle.stringValue = UtilityStyle.text("utility.\(page).subtitle")
+        UtilityStyle.setText(UtilityStyle.text("panel.\(page)"), on: title)
+        UtilityStyle.setText(UtilityStyle.text("utility.\(page).subtitle"), on: subtitle)
     }
     func addSection(_ view: NSView) {
         sections.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: sections)
@@ -136,9 +174,12 @@ final class UtilityLanguagePopup: NSPopUpButton {
     override var isFlipped: Bool { true }
     override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 44) }
     override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
+    override var focusRingMaskBounds: NSRect { bounds }
+    override func drawFocusRingMask() { HomeDashboardStyle.slant(bounds).fill() }
     override func draw(_ dirtyRect: NSRect) {
-        UtilityStyle.drawCard(bounds, accent: isHighlighted ? HomeDashboardStyle.cyan : nil, cut: 8)
-        HomeDashboardStyle.text(title, in: NSRect(x: 15, y: bounds.midY - 10, width: bounds.width - 52, height: 22), size: 14, weight: .semibold)
+        UtilityStyle.drawCard(bounds, accent: isHighlighted ? HomeDashboardStyle.cyan : nil)
+        HomeDashboardStyle.text(title, in: NSRect(x: 19, y: bounds.midY - 10, width: bounds.width - 58, height: 22),
+                                size: 14, weight: .semibold)
         HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeDashboardStyle.cyan)
     }
     override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
@@ -150,12 +191,19 @@ final class UtilityVolumeSliderCell: NSSliderCell {
     override func drawBar(inside rect: NSRect, flipped: Bool) {
         // 原生旋钮的光学中心与 barRect 有细微偏移，轨道以旋钮中心为准。
         let track = NSRect(x: rect.minX, y: knobRect(flipped: flipped).midY - 3, width: rect.width, height: 6)
+        NSGraphicsContext.saveGraphicsState()
+        if !flipped {
+            let orient = NSAffineTransform()
+            orient.translateX(by: 0, yBy: track.midY * 2)
+            orient.scaleX(by: 1, yBy: -1)
+            orient.concat()
+        }
         HomeDashboardStyle.border.setFill()
-        HomeDashboardStyle.slant(track, cut: 2).fill()
+        HomeDashboardStyle.slant(track).fill()
         let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
-        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
         HomeDashboardStyle.yellow.setFill()
-        HomeDashboardStyle.slant(fill, cut: 2).fill()
+        HomeDashboardStyle.segmentFill(track, fraction: fraction).fill()
+        NSGraphicsContext.restoreGraphicsState()
     }
     override func drawKnob(_ knobRect: NSRect) {
         let knob = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
@@ -253,8 +301,7 @@ final class UtilityRecordBestView: NSView {
     init(mode: ModeRecordKey, entry: ModeRecord?) {
         super.init(frame: .zero)
         let metric = entry.map { String($0.clearedCount) } ?? "—"
-        let value = UtilityStyle.label(metric, size: 38, weight: .heavy, color: HomeDashboardStyle.yellow)
-        value.font = .monospacedDigitSystemFont(ofSize: 38, weight: .heavy)
+        let value = UtilityStyle.label(metric, size: 38, weight: .heavy, color: HomeDashboardStyle.yellow, monospacedDigits: true)
         let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeDashboardStyle.muted)
         let copy = UtilityStyle.stack([
             UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeDashboardStyle.muted),
@@ -272,7 +319,9 @@ final class UtilityRecordBestView: NSView {
     }
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: HomeDashboardStyle.yellow) }
+    override func draw(_ dirtyRect: NSRect) {
+        UtilityStyle.drawCard(bounds, accent: HomeDashboardStyle.yellow, containsContent: true)
+    }
 }
 
 enum UtilityRecordContent {
@@ -282,11 +331,11 @@ enum UtilityRecordContent {
         let headings = UtilityStyle.stack([
             UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
             UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
-            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted)
+            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold,
+                               color: HomeDashboardStyle.muted, alignment: .right)
         ], vertical: false, spacing: 12)
         headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
         headings.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 135).isActive = true
-        (headings.arrangedSubviews[2] as? NSTextField)?.alignment = .right
         headings.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
         rows.addArrangedSubview(headings); UtilityStyle.fillWidth(headings, in: rows)
         headings.heightAnchor.constraint(equalToConstant: 30).isActive = true
@@ -299,11 +348,10 @@ enum UtilityRecordContent {
             rank.translatesAutoresizingMaskIntoConstraints = false
             NSLayoutConstraint.activate([rank.widthAnchor.constraint(equalToConstant: 36), rank.heightAnchor.constraint(equalToConstant: 30)])
             let metric = AchievementText.format("records.metric.cleared", entry.clearedCount)
-            let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold)
-            countLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: ranks[index] == 1 ? .bold : .semibold)
+            let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold, monospacedDigits: true)
             countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
-            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11, color: HomeDashboardStyle.muted)
-            date.alignment = .right
+            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11,
+                                          color: HomeDashboardStyle.muted, alignment: .right)
             date.widthAnchor.constraint(equalToConstant: 135).isActive = true
             let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 12)
             rows.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: rows)
@@ -313,11 +361,11 @@ enum UtilityRecordContent {
         if entries.isEmpty {
             let empty = UtilityStyle.stack([
                 UtilityStyle.icon("flag.checkered", color: HomeDashboardStyle.muted, size: 40),
-                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold),
-                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted)
+                UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold, alignment: .center),
+                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted,
+                                   alignment: .center)
             ], spacing: 12)
             empty.alignment = .centerX
-            for label in empty.arrangedSubviews.compactMap({ $0 as? NSTextField }) { label.alignment = .center }
             rows.addArrangedSubview(empty); UtilityStyle.fillWidth(empty, in: rows)
             empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
         }
diff --git a/Tests/AchievementFilterControlTests.swift b/Tests/AchievementFilterControlTests.swift
index 97b14c5e0d179d0026172bfdd1d6a7f0a401514f..69e51bf8925c370e4506eca238529ca627b9a5eb 100644
--- a/Tests/AchievementFilterControlTests.swift
+++ b/Tests/AchievementFilterControlTests.swift
@@ -18,12 +18,69 @@ final class AchievementFilterControlTests: AchievementTestCase {
     }
 
     private func click(_ index: Int, on filter: AchievementFilterControl) throws {
-        let point = filter.convert(NSPoint(x: filter.bounds.width * (CGFloat(index) + 0.5) / 3, y: filter.bounds.midY), to: nil)
+        try click(NSPoint(x: filter.bounds.width * (CGFloat(index) + 0.5) / CGFloat(filter.segmentCount),
+                          y: filter.bounds.midY), on: filter)
+    }
+
+    private func click(_ position: NSPoint, on filter: AchievementFilterControl) throws {
+        let point = filter.convert(position, to: nil)
         let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                                    windowNumber: filter.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
         filter.mouseDown(with: event)
     }
 
+    private func corners(of path: CGPath) -> [CGPoint] {
+        var points: [CGPoint] = []
+        path.applyWithBlock { element in
+            if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
+                points.append(element.pointee.points[0])
+            }
+        }
+        return points
+    }
+
+    func testSelectionRimFillAndGlowFollowOuterSlantInBothPanels() throws {
+        _ = NSApplication.shared
+        let achievements = AchievementsWindowController(manager: manager)
+        let records = HomeUtilityPanel(page: "records", store: ModeRecordStore(defaults: defaults))
+        defer { achievements.close(); records.close() }
+        achievements.refresh()
+        records.refresh(mode: .free, volume: 0.5)
+
+        for window in [try XCTUnwrap(achievements.window), try XCTUnwrap(records.window)] {
+            for width: CGFloat in [480, 600] {
+                window.setContentSize(NSSize(width: width, height: 580))
+                let content = try XCTUnwrap(window.contentView)
+                content.layoutSubtreeIfNeeded()
+                let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
+                filter.reducesMotion = { true }
+                let layer = try thumb(in: filter)
+                let mask = try XCTUnwrap(layer.sublayers?.first { $0.name == "achievement-filter-selection-fill" }?.mask as? CAShapeLayer)
+                let rim = try XCTUnwrap(layer.sublayers?.first { $0.name == "achievement-filter-selection-rim" } as? CAShapeLayer)
+                let outer = corners(of: HomeDashboardStyle.cgSlant(filter.bounds.insetBy(dx: 0.5, dy: 0.5)))
+                let selected = corners(of: try XCTUnwrap(rim.path))
+                XCTAssertEqual(selected, corners(of: try XCTUnwrap(mask.path)))
+                XCTAssertEqual(selected, corners(of: try XCTUnwrap(layer.shadowPath)))
+                XCTAssertEqual(selected, corners(of: HomeDashboardStyle.cgSlant(layer.bounds.insetBy(dx: 0.5, dy: 0.5))))
+                guard outer.count == 4, selected.count == 4 else { return XCTFail("外框和选中层应为四边形") }
+                // 外框和选中层高度不同，通过垂直距离归一后，左右两侧保持相同斜率。
+                for points in [outer, selected] {
+                    XCTAssertEqual((points[0].x - points[3].x) / (points[3].y - points[0].y), 0.45, accuracy: 0.001)
+                    XCTAssertEqual((points[1].x - points[2].x) / (points[2].y - points[1].y), 0.45, accuracy: 0.001)
+                }
+
+                let track = filter.bounds.insetBy(dx: 4, dy: 4)
+                let offset = HomeDashboardStyle.edgeOffset(for: track.height)
+                let boundary = track.minX + (track.width - offset) / CGFloat(filter.segmentCount)
+                // 相同的横坐标穿过斜分界，上缘属于第一段，下缘属于第二段。
+                try click(NSPoint(x: boundary + offset / 2, y: track.maxY - 4), on: filter)
+                XCTAssertEqual(filter.selectedSegment, 1)
+                try click(NSPoint(x: boundary + offset / 2, y: track.minY + 4), on: filter)
+                XCTAssertEqual(filter.selectedSegment, 0)
+            }
+        }
+    }
+
     func testAnimatedSelectionSurvivesRefreshAndRapidChanges() throws {
         _ = NSApplication.shared
         swap(roundCleared: 10)
diff --git a/Tests/GameIconPresentationTests.swift b/Tests/GameIconPresentationTests.swift
index 3f75d55d65759967b0e88b4fea6714dc20184c6d..8a939801e1b0d228ee654b8ece01b7e6987e6078 100644
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -162,13 +162,14 @@ final class GameIconPresentationTests: AchievementTestCase {
                         var minX = pixels.pixelsWide, minY = pixels.pixelsHigh, maxX = -1, maxY = -1
                         var statusMinX = pixels.pixelsWide, statusMaxX = -1
                         // 状态标记单独检查；按亮度将图案与文字从深色卡面中提取。
+                        let statusCenter = max(14, HomeDashboardStyle.edgeOffset(for: badge.bounds.height / 2) + 4) + 9
                         let insetX = Int(8 * scale), insetY = Int(4 * verticalScale)
                         for y in stride(from: insetY, to: pixels.pixelsHigh - insetY, by: 2) {
                             for x in stride(from: insetX, to: pixels.pixelsWide - insetX, by: 2) {
                                 guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                                       color.alphaComponent > 0.5,
                                       max(color.redComponent, color.greenComponent, color.blueComponent) > 0.58 else { continue }
-                                if CGFloat(x) / scale < 34 {
+                                if CGFloat(x) / scale < statusCenter + 11 {
                                     statusMinX = min(statusMinX, x); statusMaxX = max(statusMaxX, x)
                                 } else {
                                     minX = min(minX, x); maxX = max(maxX, x)
@@ -178,8 +179,8 @@ final class GameIconPresentationTests: AchievementTestCase {
                         }
                         XCTAssertGreaterThan(maxX, minX)
                         XCTAssertGreaterThan(statusMaxX, statusMinX, "完成/锁定标记应独立保留在左侧")
-                        XCTAssertEqual(CGFloat(statusMinX + statusMaxX + 1) / (2 * scale), 23, accuracy: 2,
-                                       "状态标记位置不应随名称或窗口宽度改变")
+                        XCTAssertEqual(CGFloat(statusMinX + statusMaxX + 1) / (2 * scale), statusCenter, accuracy: 2,
+                                       "状态标记与斜边的间距不应随名称或窗口宽度改变")
                         let centerX = CGFloat(minX + maxX + 1) / (2 * scale)
                         let centerY = CGFloat(minY + maxY + 1) / (2 * verticalScale)
                         // 与实际绘制相比，隔点取样及浅色边缘过滤会略微改变测得的轮廓。
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 38254b879c4f5bf13ed4f8f9064706eb3218866f..2df28e01f6529cdc84ec4ebc78104e044741091e 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -61,7 +61,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(hud.budgetText, "0")
     }
 
-    func testPieceCountsFollowReferenceSlotsAcrossStatWidths() throws {
+    func testPieceCountsUseEqualCellsAndGapsAcrossStatWidths() throws {
         _ = NSApplication.shared
         let longCount = 123_456
         let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
@@ -74,9 +74,27 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                                                    isRunning: false, isFinished: true, clearedByKind: counts), mode: mode)
                 let bitmap = try image(hud)
                 let scale = CGFloat(bitmap.pixelsWide) / width
-                let surface = hud.surfaceRect
-                let rowStart = surface.minY + surface.height * 132 / 186
-                let rowPixels = stride(from: Int(ceil(rowStart * scale)), to: Int(surface.maxY * scale), by: 2)
+                let cells = hud.breakdownCellRects
+                XCTAssertEqual(cells.count, PieceKind.allCases.count)
+                let first = try XCTUnwrap(cells.first)
+                let cut = HomeDashboardStyle.edgeOffset(for: first.height)
+                let flatWidth = first.width - cut
+                let gaps = zip(cells, cells.dropFirst()).map { previous, next in
+                    next.minX + cut - previous.maxX
+                }
+                let firstGap = try XCTUnwrap(gaps.first)
+                XCTAssertGreaterThan(firstGap, 0)
+                for cell in cells {
+                    XCTAssertEqual(cell.minY, first.minY)
+                    XCTAssertEqual(cell.width, first.width, "四类统计必须使用相同宽度")
+                    XCTAssertEqual(cell.height, first.height)
+                    XCTAssertTrue(hud.bounds.contains(cell))
+                }
+                for gap in gaps {
+                    XCTAssertEqual(gap, firstGap, accuracy: 0.001, "四张卡之间的斜缝必须等宽")
+                }
+
+                let rowPixels = stride(from: Int(ceil(first.minY * scale)), to: Int(first.maxY * scale), by: 2)
                 var iconStarts: [CGFloat] = []
                 var previousColoredX = -CGFloat.infinity
                 // 只在底部方块行检测彩色像素，避免把青色模式标题误当成方块。
@@ -93,12 +111,12 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                     if position - previousColoredX > 3 { iconStarts.append(position) }
                     previousColoredX = position
                 }
-                // 即使高度限制等比缩放，起点仍按设计稿在各分格内的位置对齐。
-                let referenceOffsets: [CGFloat] = [38, 179, 324, 472]
-                XCTAssertEqual(iconStarts.count, PieceKind.allCases.count, "\(mode.key) / \(width)")
-                for (start, offset) in zip(iconStarts, referenceOffsets) {
-                    XCTAssertEqual(start, surface.minX + surface.width * offset / 636, accuracy: 3,
-                                   "\(mode.key) / \(width)：方块起点应与设计稿对应列对齐")
+                // 从彩色像素验证实际绘制也遵循每个等宽格的左侧留白。
+                let iconInset = cut / 2 + min(24, flatWidth * 0.18)
+                XCTAssertEqual(iconStarts.count, cells.count, "\(mode.key) / \(width)")
+                for (start, cell) in zip(iconStarts, cells) {
+                    XCTAssertEqual(start, cell.minX + iconInset, accuracy: 3,
+                                   "\(mode.key) / \(width)：方块应按分格对齐")
                 }
                 XCTAssertTrue(hud.toolTip?.contains("\(longCount)") == true, "长数字的完整值可通过提示查看")
                 if mode == .moves, width == 534 { try export(hud, name: "hud-compact-long-counts") }
@@ -165,6 +183,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                         if language == .russian, size.width == 960, mode == .moves, !running {
                             try export(home, name: "lobby-compact-ru")
                         }
+                        if language == .chineseSimplified, size.width == 960, mode == .moves, !running {
+                            try export(home, name: "lobby-compact-zh-hans")
+                        }
                     }
                 }
             }
@@ -222,7 +243,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertGreaterThan(preview.frame.minX, restingX)
         XCTAssertLessThanOrEqual(preview.frame.minX, home.modePanel.frame.minX + 0.1)
         XCTAssertEqual(preview.frame.width, restingWidth * 0.20, accuracy: 0.1)
-        XCTAssertLessThan(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height)
+        XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
+                       accuracy: 0.001, "卡面起始帧须保持原有斜边角度")
         try assertLaunchIsWithinScreen(preview, in: window)
         XCTAssertLessThan(preview.alphaValue, 0.2)
 
@@ -238,6 +260,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
             header.advanceAnimation()
             XCTAssertGreaterThanOrEqual(preview.frame.width + 0.1, previousWidth)
             XCTAssertLessThanOrEqual(preview.frame.maxX, header.bounds.maxX + 0.1)
+            XCTAssertEqual(preview.frame.width / preview.bounds.width, preview.frame.height / preview.bounds.height,
+                           accuracy: 0.001, "入场每帧都须等比缩放")
             previousWidth = preview.frame.width
             if step == steps / 2 {
                 let position = preview.frame.minX
@@ -300,23 +324,36 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(surface.maxY, 309, accuracy: 2.5)
         let scale = CGFloat(bitmap.pixelsWide) / home.bounds.width
 
-        func brightness(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
-            let pointX = surface.minX + (x - 410) * surface.width / 636
-            let pointY = surface.minY + (y - 123) * surface.height / 186
-            let color = try XCTUnwrap(bitmap.colorAt(x: Int(pointX * scale), y: Int(pointY * scale))?.usingColorSpace(.sRGB))
+        func brightness(at point: NSPoint) throws -> CGFloat {
+            let color = try XCTUnwrap(bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB))
             return (color.redComponent + color.greenComponent + color.blueComponent) / 3
         }
 
-        let rim = try (173...176).map { try brightness(780, CGFloat($0)) }.max() ?? 0
-        let rimNeighbors = try max(brightness(780, 170), brightness(780, 178))
+        func brightnessInReference(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
+            try brightness(at: NSPoint(x: surface.minX + (x - 410) * surface.width / 636,
+                                       y: surface.minY + (y - 123) * surface.height / 186))
+        }
+
+        let rim = try (173...176).map { try brightnessInReference(780, CGFloat($0)) }.max() ?? 0
+        let rimNeighbors = try max(brightnessInReference(780, 170), brightnessInReference(780, 178))
         XCTAssertGreaterThan(rim, rimNeighbors + 0.09, "统计前板的上边缘应在两层深色面板之间清楚可见")
 
-        // 取三条缝左右边缘的亮点，验证底部由四张独立斜卡组成。
-        for (left, right) in [(560, 570), (705, 715), (854, 864)] {
-            let leftRim = try (left - 2...left + 2).map { try brightness(CGFloat($0), 280) }.max() ?? 0
-            let rightRim = try (right - 2...right + 2).map { try brightness(CGFloat($0), 280) }.max() ?? 0
-            let gap = try brightness(CGFloat(left + right) / 2, 280)
-            XCTAssertGreaterThan(min(leftRim, rightRim), gap + 0.05, "两张统计卡之间应保留可见间隔")
+        func edgeBrightness(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat {
+            try (-2...2).map { try brightness(at: NSPoint(x: x + CGFloat($0) / 2, y: y)) }.max() ?? 0
+        }
+
+        let cells = card.breakdownCellRects.map { card.convert($0, to: home) }
+        // 从两个高度采样暗缝，两边的描线都必须贴合共用角度。
+        for (left, right) in zip(cells, cells.dropFirst()) {
+            for fraction: CGFloat in [0.25, 0.75] {
+                let y = left.minY + left.height * fraction
+                let leftX = left.maxX - HomeDashboardStyle.edgeOffset(for: y - left.minY)
+                let rightX = right.minX + HomeDashboardStyle.edgeOffset(for: right.maxY - y)
+                let leftRim = try edgeBrightness(leftX, y)
+                let rightRim = try edgeBrightness(rightX, y)
+                let gap = try brightness(at: NSPoint(x: (leftX + rightX) / 2, y: y))
+                XCTAssertGreaterThan(min(leftRim, rightRim), gap + 0.05, "两张斜卡之间应保留可见间隔")
+            }
         }
     }
 
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index a025e00e803984f3e938ddd08f765373660182c7..56da26ab49e4baefd57eedb2754b8507e0c92d0c 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -160,6 +160,20 @@ final class HomeDashboardTests: AchievementTestCase {
                 home.cacheDisplay(in: home.bounds, to: rep)
                 try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                     .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-home-achievement-grid.png"))
+                // 6 / 32 的进度停在第二个分段中，比较两行黄色像素右端以捕捉垂直裁切回归。
+                let crop = NSRect(x: 0, y: 18, width: path.width * 0.66, height: 24)
+                let meter = try XCTUnwrap(home.achievementPath.bitmapImageRepForCachingDisplay(in: crop))
+                home.achievementPath.cacheDisplay(in: crop, to: meter)
+                let scale = CGFloat(meter.pixelsHigh) / crop.height
+                func fillEnd(at y: CGFloat) throws -> CGFloat {
+                    let row = Int((y - crop.minY) * scale)
+                    let x = try XCTUnwrap((0..<meter.pixelsWide).last { x in
+                        guard let color = meter.colorAt(x: x, y: row)?.usingColorSpace(.sRGB) else { return false }
+                        return color.redComponent > 0.8 && color.greenComponent > 0.7 && color.blueComponent < 0.45
+                    })
+                    return CGFloat(x) / scale
+                }
+                XCTAssertEqual(try fillEnd(at: 26) - fillEnd(at: 33), HomeDashboardStyle.edgeOffset(for: 7), accuracy: 1)
             }
         }
 
```
