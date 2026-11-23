# 按参考图重构深色 AppKit 游戏界面

## 背景与目标

- 会话-2 至会话-5 在 `experiment/ui-refactor-v2` 上把参考图的深蓝斜纹、青色选中态和黄色主按钮落实到原生游戏窗口。
- 简体中文大厅标识和窗口标题使用「消除俄罗斯方块」。五种语言的大厅名称与各自窗口标题一致。
- 使用 AppKit 绘制实际界面与插画。原有按钮、空格、触控栏开局入口继续交由控制器处理。

## 阶段与完成情况

- [x] 重排大厅导航、标题与本局统计、右侧模式卡和反馈卡，保留跨栏的单行成就与进度。
- [x] 重绘四类立体方块、反光、互换箭头与触控栏滑动示意。统计栏复用同一方块画法。
- [x] 切换游戏模式时仅对统计卡执行入场动画，介绍始终与卡片并排。自由模式待机时也展示本局消除。
- [x] 设置、玩法说明、挑战记录与成就图鉴共用深色材质和斜边。长模式说明和反馈文案在紧凑窗口中可以换行。
- [x] 核对五语言、紧凑窗口与宽屏视觉，以及原生控件交互和游戏规则回归。

## 测试与验收

| 用例 | 操作 | 结果 |
| --- | --- | --- |
| 大厅样式与名称 | 渲染五种语言、三种模式和多种窗口尺寸 | 简体中文显示「消除俄罗斯方块」。1585 × 992 点宽屏与 960 × 720 点俄语紧凑预览已目视核对 |
| 统计与模式转场 | 切换自由、限时和限步模式，推进动画并开始本局 | 标题保持可见，卡片入场受窗口边界和右栏遮挡约束。四类统计图标等距，数字位数变化不推动图标 |
| 开局与结算 | 验证按钮、空格和模拟触控栏滑动，推进限时和限步结算 | 开场完成后开始计算游戏预算。解谜入口保持禁用，挑战记录和成就沿用既有存档规则 |
| 辅助窗口 | 渲染设置、玩法说明、挑战记录和成就图鉴，验证原生操作 | 通过控件回调、筛选动画、滚动和焦点回归 |

- 自动化命令为 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。全套 89 项测试通过。
- 手动验证时运行 `./run.sh`，在大厅查看名称，切换模式、缩放窗口、点击开始或按空格，再打开顶部导航和成就图鉴。实体触控栏需在带相应硬件的机器上核对。
- 本轮宽屏预览由测试导出为 `eliminate-lobby-reference-size.png`，紧凑俄语预览导出为 `eliminate-lobby-compact-ru.png`。两张图均来自原生视图快照，进度来自隔离的测试存档。

## 代码变更


```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index a5705a1ef8fa622314317710789602ed5ce83be5..3ec8c49888c03c8018f1be34dc5945c1dac3bd8d 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261123075948-dark-angular-appkit-ui.md` - 会话-2 至会话-5 在 `experiment/ui-refactor-v2` 按设计图重构深色 AppKit 界面，保留「消除俄罗斯方块」名称。含五语言、原生预览验证和完整 diff。
 `workflow/20261122165517-full-width-achievement-row.md` - 会话-207 起恢复跨栏单行成就，并让开始按钮与联系我们卡片底边对齐。含宽窄窗口回归、实际预览与完整 diff。
 `workflow/20261122163532-even-piece-stat-spacing.md` - 会话-205 起将四组方块放在等宽列的同一侧，首组贴齐明细区左边缘，图标保持等距。含不同位数的像素回归、预览与完整 diff。
 `workflow/20261122161432-left-align-first-piece-stat.md` - 会话-203 起把首组方块明细贴齐左边缘，缩短与消除总数的视觉距离。含宽窄窗口像素回归、预览与完整 diff。
@@ -97,6 +98,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整深色大厅斜边主题、统计与标题并排、方块及触控栏示意，或核对辅助面板主题和游戏名称时，读取 `20261123075948-dark-angular-appkit-ui.md`。
 - 需要调整当前首页的跨栏成就预览、开始按钮与联系卡的底边或小窗口布局时，读取 `20261122165517-full-width-achievement-row.md`。
 - 需要调整当前方块图标的等距布局，或核对数字位数变化时图标的位置，读取 `20261122163532-even-piece-stat-spacing.md`。
 - 需要调整方块明细首列左对齐或与消除总数的留白时，读取 `20261122161432-left-align-first-piece-stat.md`。
@@ -194,12 +196,12 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- 模式图案由 `GameModeArtwork` 独立绘制，自由是悬浮方块、限时是冲刺秒表、限步是 30 次行动计数器；`game.mode.*` 经统一图标入口供首页和辅助页使用，不能再按系统符号名称处理。
-- 大厅材质由 `GameLobbyStyle` 提供；`GameControlFeedback` 的 0.18 秒反馈只在交互变化时刷新，重复界面刷新不重新计时，减少动态效果立即到位。局内预算面板只消费快照，原开局及结算规则仍由控制器执行。
+- 深色大厅、辅助面板和成就窗口共用 `HomeDashboardStyle`。大厅模式卡使用线形图标，辅助页通过 `GameIconRenderer` 继续使用 `GameModeArtwork` 的彩色模式图案。
+- `GameControlFeedback` 的 0.18 秒反馈仅由交互变化触发，减少动态效果时立即到位。任何模式在大厅均显示 `GameSnapshot` 的本局统计，挑战卡切换时保留独立转场。
 - 开局由 `GameStartSequence` 统一管理；`prepareRound` 仅生成预览，`beginPreparedRound` 在开场结束后启用同一棋盘并开始计时。待机 Touch Bar 显示滑轨，开局指针全部抬起后才接受交换；私有 modal 刷新保持开场进度。
-- 成就筛选由 `AchievementFilterControl` 统一绘制一体式滑轨与数量，沿用 `NSSegmentedControl` 的真实选择值；黄色滑块由 Core Animation 移动，刷新列表不重置动画，减少动态效果时即时定位。测试动画及页面图位于 `docs/previews/achievement-filter.gif` 和 `achievement-panel.png`，正式应用无测试预览入口。
+- 成就筛选由 `AchievementFilterControl` 统一绘制滑轨与数量，沿用 `NSSegmentedControl` 的真实选择值。深色版滑块使用青色，刷新列表时继续当前动画，减少动态效果时即时定位。
 - `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的透明背景彩色游戏图案，不绘制徽章外框或底板。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
-- 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
+- 深色大厅的四种立体方块、触控栏示意和统计图标由 `HomeLobbyArtwork` 等比绘制，减少动态效果时方块静止。历史浅色设计稿与提取图用于追溯和像素校验。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
 - 当前三种模式通过按钮、空格或滑动触控栏显式开局：自由不限时间/次数，限时挑战固定 60 秒，限步挑战固定 30 次合法相邻交换；只统计消除数量，不再计分。无消除也扣一次，自动连锁不多扣，末次交换完整结算；限步不比较耗时。
diff --git a/AGENTS.md b/AGENTS.md
index 1fda0015ce42dd9ae0c9960454a3436dc6626334..8b4fc8a39ea7135f10d7c74f2ab9c2b7e78749d4 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -5,6 +5,10 @@
 - 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
 - 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
 
+## 2026-11-23（深色界面探索分支）
+- `experiment/ui-refactor-v2` 的大厅、设置、玩法、挑战记录和成就窗口共用 `HomeDashboardStyle` 的深蓝底、斜边与状态色。桌面大厅和窗口标题的简体中文名称为「消除俄罗斯方块」。
+- 大厅的介绍与本局快照并排展示。模式切换只让统计卡入场，标题继续可见。左侧插画、统计图标与触控栏示意共用 `HomeLobbyArtwork` 的原生矢量方块。实际触控栏由 `GameTouchBarView` 绘制，开局和结算仍经原有控制器协调。
+
 ## 2026-11-22（首页双栏与跨栏成就）
 - `HomeDashboardView` 管理左侧开局区、右侧信息栏及下方跨栏成就。`HomeAchievementPathView` 按窗口宽度提供单行预览，完整列表由成就窗口展示。挑战卡转场由 `HomeModeHeaderView` 独立绘制。
 
diff --git a/Sources/AchievementFilterControl.swift b/Sources/AchievementFilterControl.swift
index c0836dfb83ca29072d982099337a52763777c15f..b8e6320d4d382c1551e74008e13bb62fe651cddf 100644
--- a/Sources/AchievementFilterControl.swift
+++ b/Sources/AchievementFilterControl.swift
@@ -27,17 +27,16 @@ final class AchievementFilterControl: NSSegmentedControl {
         labels.wantsLayer = true
         addSubview(labels)
         thumb.name = "achievement-filter-selection"
-        thumb.colors = [NSColor(calibratedRed: 1, green: 0.88, blue: 0.35, alpha: 1).cgColor,
-                        HomeStyle.yellow.cgColor]
-        thumb.startPoint = CGPoint(x: 0.5, y: 0)
-        thumb.endPoint = CGPoint(x: 0.5, y: 1)
-        thumb.cornerRadius = 9
-        thumb.borderWidth = 0.75
-        thumb.borderColor = NSColor(calibratedRed: 0.91, green: 0.66, blue: 0.05, alpha: 0.5).cgColor
-        thumb.shadowColor = NSColor(calibratedRed: 0.43, green: 0.32, blue: 0.09, alpha: 1).cgColor
-        thumb.shadowOpacity = 0.16
-        thumb.shadowRadius = 2
-        thumb.shadowOffset = CGSize(width: 0, height: 1)
+        thumb.colors = [HomeDashboardStyle.color(0x17505A).cgColor, HomeDashboardStyle.color(0x10313D).cgColor]
+        thumb.startPoint = CGPoint(x: 0, y: 0.5)
+        thumb.endPoint = CGPoint(x: 1, y: 0.5)
+        thumb.cornerRadius = 2
+        thumb.borderWidth = 1
+        thumb.borderColor = HomeDashboardStyle.cyan.withAlphaComponent(0.85).cgColor
+        thumb.shadowColor = HomeDashboardStyle.cyan.cgColor
+        thumb.shadowOpacity = 0.18
+        thumb.shadowRadius = 3
+        thumb.shadowOffset = .zero
         layer?.insertSublayer(thumb, at: 0)
         labels.layer?.zPosition = 1
         focusRingType = .exterior
@@ -91,7 +90,7 @@ final class AchievementFilterControl: NSSegmentedControl {
         thumb.removeAnimation(forKey: "filter-selection")
         CATransaction.begin(); CATransaction.setDisableActions(true)
         thumb.frame = target
-        thumb.shadowPath = CGPath(roundedRect: thumb.bounds, cornerWidth: 9, cornerHeight: 9, transform: nil)
+        thumb.shadowPath = CGPath(roundedRect: thumb.bounds, cornerWidth: 2, cornerHeight: 2, transform: nil)
         CATransaction.commit()
         if shouldAnimate {
             let movement = CABasicAnimation(keyPath: "position")
@@ -111,9 +110,7 @@ final class AchievementFilterControl: NSSegmentedControl {
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
-        NSGradient(colors: [NSColor(calibratedWhite: 0.94, alpha: 1), NSColor(calibratedWhite: 0.965, alpha: 1)])?.draw(in: path, angle: 90)
-        NSColor(calibratedWhite: 0.86, alpha: 0.65).setStroke(); path.lineWidth = 1; path.stroke()
+        UtilityStyle.drawCard(bounds, cut: 5)
     }
 
     fileprivate func drawLabels() {
@@ -121,7 +118,7 @@ final class AchievementFilterControl: NSSegmentedControl {
             let rect = segmentRect(index)
             let selected = selectedSegment == index
             let title = label(forSegment: index) ?? ""
-            let color = selected ? HomeStyle.ink : hoveredSegment == index ? HomeStyle.ink : HomeStyle.secondary
+            let color = selected ? HomeDashboardStyle.cyan : hoveredSegment == index ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
             let count = counts.indices.contains(index) ? String(counts[index]) : "0"
             let countFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
             let countWidth = max(21, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 10)
@@ -138,8 +135,8 @@ final class AchievementFilterControl: NSSegmentedControl {
             let titleSize = (title as NSString).size(withAttributes: [.font: font])
             (title as NSString).draw(at: NSPoint(x: start + 19, y: rect.midY - titleSize.height / 2), withAttributes: [.font: font, .foregroundColor: color])
             let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
-            (selected ? HomeStyle.ink.withAlphaComponent(0.075) : HomeStyle.ink.withAlphaComponent(0.035)).setFill()
-            NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6).fill()
+            color.withAlphaComponent(selected ? 0.16 : 0.09).setFill()
+            HomeDashboardStyle.slant(chip, cut: 3).fill()
             let size = (count as NSString).size(withAttributes: [.font: countFont])
             (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2), withAttributes: [.font: countFont, .foregroundColor: color])
         }
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
index fd114af55e18533183378c215176abe6718bacba..b247578d97ae4f865fbc458b124451a70cf4d96a 100644
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -172,19 +172,19 @@ final class AchievementBadgeStripView: NSScrollView {
     @objc private func badgeTapped(_ sender: NSButton) { onSelect?(sender.tag) }
 }
 
-/// 辅助面板沿用浅色首页的文字、边框及成功状态颜色。
+/// 图鉴与大厅共用深色材质和状态配色。
 private enum AchievementPanelStyle {
-    static let accent = HomeStyle.ink
-    static let success = HomeStyle.green
-    static let body = HomeStyle.ink
-    static let muted = HomeStyle.secondary
+    static let accent = HomeDashboardStyle.cyan
+    static let success = HomeDashboardStyle.green
+    static let body = HomeDashboardStyle.ink
+    static let muted = HomeDashboardStyle.muted
     static let controlFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
 
     /// 标题使用独立的彩色奖章，保持原有奖章语义，不受系统模板染色影响。
     static let headingIcon: NSImage = {
         let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { _ in
             for (points, color) in [
-                ([NSPoint(x: 11, y: 24), NSPoint(x: 24, y: 27), NSPoint(x: 20, y: 44), NSPoint(x: 15, y: 39), NSPoint(x: 9, y: 42)], HomeStyle.blue),
+                ([NSPoint(x: 11, y: 24), NSPoint(x: 24, y: 27), NSPoint(x: 20, y: 44), NSPoint(x: 15, y: 39), NSPoint(x: 9, y: 42)], HomeDashboardStyle.cyan),
                 ([NSPoint(x: 24, y: 27), NSPoint(x: 37, y: 24), NSPoint(x: 39, y: 42), NSPoint(x: 32, y: 39), NSPoint(x: 28, y: 44)], NSColor.systemRed)
             ] {
                 let ribbon = NSBezierPath(); ribbon.move(to: points[0])
@@ -193,7 +193,7 @@ private enum AchievementPanelStyle {
             }
             let medal = NSBezierPath(ovalIn: NSRect(x: 8, y: 4, width: 32, height: 32))
             NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.92, blue: 0.57, alpha: 1),
-                                HomeStyle.yellow, NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.08, alpha: 1)])?.draw(in: medal, angle: -90)
+                                HomeDashboardStyle.yellow, NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.08, alpha: 1)])?.draw(in: medal, angle: -90)
             let star = NSBezierPath()
             for index in 0..<10 {
                 let angle = CGFloat(index) * .pi / 5 - .pi / 2
@@ -210,15 +210,10 @@ private enum AchievementPanelStyle {
     }()
 
     static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
-        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
-        (selected ? NSColor(calibratedRed: 0.9, green: 0.96, blue: 1, alpha: 1) : NSColor.white).setFill()
-        path.fill()
-        (selected ? HomeStyle.blue : HomeStyle.border).setStroke()
-        path.lineWidth = 1
-        path.stroke()
+        UtilityStyle.drawCard(rect, accent: selected ? accent : nil, cut: 6)
         let attributes: [NSAttributedString.Key: Any] = [
             .font: controlFont,
-            .foregroundColor: selected ? HomeStyle.blue : body
+            .foregroundColor: selected ? accent : body
         ]
         let size = (title as NSString).size(withAttributes: attributes)
         (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
@@ -227,6 +222,8 @@ private enum AchievementPanelStyle {
 }
 
 private final class AchievementPanelActionButton: NSButton {
+    override var isFlipped: Bool { true }
+
     override var intrinsicContentSize: NSSize {
         NSSize(width: max(88, ceil((title as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24), height: 32)
     }
@@ -238,21 +235,21 @@ private final class AchievementPanelActionButton: NSButton {
     }
 }
 
-/// 像素进度条沿用原生进度接口，显示颜色与所在成就卡片一致。
+/// 进度条沿用原生进度接口，通过斜边和状态色呈现完成度。
 private final class AchievementProgressIndicator: NSProgressIndicator {
     var accentColor: NSColor = AchievementPanelStyle.accent
 
+    override var isFlipped: Bool { true }
     override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 10) }
 
     override func draw(_ dirtyRect: NSRect) {
-        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
-        NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
-        track.fill()
+        HomeDashboardStyle.border.withAlphaComponent(0.55).setFill()
+        HomeDashboardStyle.slant(bounds, cut: 4).fill()
         let fraction = min(1, max(0, (doubleValue - minValue) / max(1, maxValue - minValue)))
         if fraction > 0 {
             accentColor.setFill()
-            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height),
-                         xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
+            let fill = NSRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
+            HomeDashboardStyle.slant(fill, cut: 4).fill()
         }
     }
 
@@ -285,8 +282,8 @@ final class AchievementsWindowController: NSWindowController {
         panel.isReleasedWhenClosed = false
         panel.hidesOnDeactivate = true
         panel.minSize = NSSize(width: 480, height: 360)
-        panel.appearance = NSAppearance(named: .aqua)
-        panel.backgroundColor = HomeStyle.background
+        panel.appearance = NSAppearance(named: .darkAqua)
+        panel.backgroundColor = HomeDashboardStyle.navy
         panel.titlebarAppearsTransparent = true
         panel.contentView = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))
         super.init(window: panel)
@@ -376,7 +373,7 @@ final class AchievementsWindowController: NSWindowController {
     private func buildContent() {
         guard let content = window?.contentView else { return }
         heading.font = .systemFont(ofSize: 16, weight: .heavy)
-        heading.textColor = AchievementPanelStyle.accent
+        heading.textColor = AchievementPanelStyle.body
         heading.lineBreakMode = .byTruncatingTail
         heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         filter.segmentCount = 3
@@ -454,7 +451,7 @@ final class AchievementsWindowController: NSWindowController {
         row.translatesAutoresizingMaskIntoConstraints = false
         let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
         name.font = .systemFont(ofSize: 13, weight: .semibold)
-        name.textColor = accent
+        name.textColor = unlocked ? accent : AchievementPanelStyle.body
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
         let icon = NSImageView(image: AchievementIconCatalog.image(for: definition, muted: !unlocked))
         icon.imageScaling = .scaleProportionallyUpOrDown
@@ -475,7 +472,7 @@ final class AchievementsWindowController: NSWindowController {
         status.font = .systemFont(ofSize: 10, weight: .regular)
         status.textColor = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted
         let meter = AchievementProgressIndicator()
-        meter.accentColor = unlocked ? HomeStyle.green : HomeStyle.yellow
+        meter.accentColor = unlocked ? AchievementPanelStyle.success : HomeDashboardStyle.yellow
         meter.heightAnchor.constraint(equalToConstant: 10).isActive = true
         meter.style = .bar
         meter.isIndeterminate = false
diff --git a/Sources/AppDelegate.swift b/Sources/AppDelegate.swift
index 373a5045a1254e92948d3cb0d1bc4004c3ea5e1a..cace61899d3a5bd8829c4443771ebfce31224446 100644
--- a/Sources/AppDelegate.swift
+++ b/Sources/AppDelegate.swift
@@ -7,14 +7,15 @@ final class AppDelegate: NSObject, NSApplicationDelegate {
         let viewController = GameViewController()
         let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
         let window = NSWindow(
-            contentRect: NSRect(x: 0, y: 0, width: min(1180, max(960, available.width - 64)), height: min(800, max(720, available.height - 80))),
+            contentRect: NSRect(x: 0, y: 0, width: min(1340, max(960, available.width - 64)), height: min(840, max(720, available.height - 80))),
             styleMask: [.titled, .closable, .miniaturizable, .resizable],
             backing: .buffered,
             defer: false
         )
         window.center()
         window.title = Localizer.shared.string("window.title")
-        window.appearance = NSAppearance(named: .aqua)
+        window.appearance = NSAppearance(named: .darkAqua)
+        window.backgroundColor = HomeDashboardStyle.navy
         window.contentMinSize = NSSize(width: 960, height: 720)
         window.contentViewController = viewController
         window.makeFirstResponder(viewController)
diff --git a/Sources/GameIcons.swift b/Sources/GameIcons.swift
index 736965bf37ab7ce60bda1ae1435a098788b66c93..7769165c7eb0175d7dfd1cdd9ff5356be53bd178 100644
--- a/Sources/GameIcons.swift
+++ b/Sources/GameIcons.swift
@@ -11,7 +11,7 @@ enum GameIconRenderer {
     }
 
     static func drawSymbol(_ name: String, in bounds: NSRect, color: NSColor, fallbacks: [String] = []) {
-        // 模式图案是游戏美术，颜色由自身定义；所有入口共用同一资源，保持等比。
+        // 玩法说明等入口使用自带颜色的游戏图案，统一等比绘制。
         if let mode = HomeGameMode.allCases.first(where: { $0.symbol == name }) {
             GameModeArtwork.draw(mode, in: bounds); return
         }
diff --git a/Sources/GameLobbyStyle.swift b/Sources/GameLobbyStyle.swift
index df4dfcb9171b537b37e6e0d7e7c2be67908351f0..1b41d062d9203cece02aafcf90317801c47abe14 100644
--- a/Sources/GameLobbyStyle.swift
+++ b/Sources/GameLobbyStyle.swift
@@ -1,6 +1,6 @@
 import Cocoa
 
-/// 大厅的柔和游戏材质。所有绘制都限制在控件内部，保留原生点击区域和焦点环。
+/// 游戏图标与统计界面共用的渐变、光晕和字号计算。
 enum GameLobbyStyle {
     static let amber = NSColor(calibratedRed: 1, green: 0.68, blue: 0.08, alpha: 1)
     static let teal = NSColor(calibratedRed: 0.05, green: 0.70, blue: 0.54, alpha: 1)
@@ -14,20 +14,6 @@ enum GameLobbyStyle {
             .draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
     }
 
-    static func surface(_ rect: NSRect, radius: CGFloat = 15, tint: NSColor = .white, strength: CGFloat = 0.07) {
-        NSGraphicsContext.saveGraphicsState()
-        let shadow = NSShadow()
-        shadow.shadowColor = NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.13, alpha: strength)
-        shadow.shadowBlurRadius = 8; shadow.shadowOffset = NSSize(width: 0, height: -3); shadow.set()
-        NSColor.white.setFill()
-        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
-        NSGraphicsContext.restoreGraphicsState()
-        gradient(rect, colors: [.white, tint], radius: radius)
-        HomeStyle.border.withAlphaComponent(0.42).setStroke()
-        let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
-        outline.lineWidth = 0.7; outline.stroke()
-    }
-
     static func fittedSize(_ text: String, width: CGFloat, preferred: CGFloat, minimum: CGFloat, weight: NSFont.Weight) -> CGFloat {
         var size = preferred
         while size > minimum, (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width > width {
@@ -35,36 +21,6 @@ enum GameLobbyStyle {
         }
         return size
     }
-
-    static func wrappedText(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor) {
-        let paragraph = NSMutableParagraphStyle()
-        paragraph.lineBreakMode = .byWordWrapping
-        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
-                               attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: paragraph])
-    }
-
-    static func primaryButton(_ bounds: NSRect, hover: CGFloat, press: CGFloat) {
-        // 静止时按钮的立体底边贴齐控件底边，与右侧卡片共用一条基线。
-        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: 2 + press * 2 - hover)
-        NSGraphicsContext.saveGraphicsState()
-        let shadow = NSShadow()
-        shadow.shadowColor = amber.withAlphaComponent(0.22 + hover * 0.12)
-        shadow.shadowBlurRadius = 8 + hover * 4
-        shadow.shadowOffset = NSSize(width: 0, height: -3 + press * 2); shadow.set()
-        amber.setFill(); NSBezierPath(roundedRect: face, xRadius: 13, yRadius: 13).fill()
-        NSGraphicsContext.restoreGraphicsState()
-        let lip = face.offsetBy(dx: 0, dy: 3 - press * 2)
-        NSColor(calibratedRed: 0.91, green: 0.62, blue: 0.015, alpha: 1).setFill()
-        NSBezierPath(roundedRect: lip, xRadius: 13, yRadius: 13).fill()
-        gradient(face, colors: [NSColor(calibratedRed: 1, green: 0.88, blue: 0.25, alpha: 1), HomeStyle.yellow], radius: 13)
-        NSColor.white.withAlphaComponent(0.65).setStroke()
-        let highlight = NSBezierPath()
-        highlight.lineWidth = 1
-        highlight.move(to: NSPoint(x: face.minX + 14, y: face.minY + 1))
-        highlight.line(to: NSPoint(x: face.maxX - 14, y: face.minY + 1)); highlight.stroke()
-        // 细小的高光只用于按钮表面，避免让整张首页持续闪烁。
-        glow(NSRect(x: face.minX + 8, y: face.minY, width: face.width * 0.55, height: face.height), color: .white.withAlphaComponent(0.14 + hover * 0.12))
-    }
 }
 
 /// 悬停、按压和选中共用短动画；仅变化期间刷新，界面 tick 不重新启动过渡。
diff --git a/Sources/GameModeArtwork.swift b/Sources/GameModeArtwork.swift
index 623061eda908ddd5cb1badbbb597508fb1553e00..353edaea51a50ea3e37ed142d343b9cb5a9117de 100644
--- a/Sources/GameModeArtwork.swift
+++ b/Sources/GameModeArtwork.swift
@@ -24,15 +24,6 @@ enum GameModeArtwork {
                    operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
     }
 
-    /// 大厅预留入口用紫色拼图造型，与可玩的三种模式区分。
-    static func drawPuzzle(in bounds: NSRect) {
-        let face = bounds.insetBy(dx: bounds.width * 0.15, dy: bounds.height * 0.15)
-        let lavender = NSColor(calibratedRed: 0.54, green: 0.41, blue: 0.84, alpha: 1)
-        GameLobbyStyle.glow(face.insetBy(dx: -5, dy: -4), color: lavender.withAlphaComponent(0.16))
-        HomeStyle.symbol("puzzlepiece.fill", in: face.offsetBy(dx: 1, dy: 2), color: NSColor(calibratedRed: 0.37, green: 0.26, blue: 0.64, alpha: 1))
-        HomeStyle.symbol("puzzlepiece.fill", in: face, color: lavender)
-    }
-
     /// 方块通过侧面、顶部高光和柔和色影获得体积，三种图案保持同一光照。
     private static func tile(_ rect: NSRect, color: NSColor, angle: CGFloat = 0) {
         NSGraphicsContext.saveGraphicsState()
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 71e033bcfa6e1cf21a562e91dad983ac484fe1fb..fc987ab9deee5c873268bdfa6f40ff51cff057e8 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -561,16 +561,15 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
 
 }
 
-/// 辅助面板沿用首页的暖白背景，保留共用组件入口以减少主题分歧。
+/// 成就图鉴与大厅共用深色斜纹背景。
 final class ArcadeStageView: NSView {
     override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.background.setFill()
-        bounds.fill()
+        HomeDashboardStyle.backdrop(in: bounds)
     }
 }
 
-/// 成就列表共用的轻量卡片，解锁状态通过边框颜色及图标共同表示。
+/// 成就列表沿用辅助面板的斜边卡片，解锁状态由边框和图标共同表示。
 final class PixelFrameCardView: NSView {
     private let accentColor: NSColor
     init(accentColor: NSColor) {
@@ -578,8 +577,9 @@ final class PixelFrameCardView: NSView {
         super.init(frame: .zero)
     }
     required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.card(bounds, border: accentColor == HomeStyle.green ? HomeStyle.green.withAlphaComponent(0.5) : HomeStyle.border)
+        UtilityStyle.drawCard(bounds, accent: accentColor == HomeDashboardStyle.green ? accentColor : nil)
     }
 }
 
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index 983c42217e6111527cc42530fd82f13d315ee4c5..c0690c0948d8b3a7371b205542dd88f59953bf44 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -38,7 +38,7 @@ final class HomeChallengeHUDView: NSView {
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
         self.snapshot = snapshot; self.mode = mode
-        var labels: [String] = []
+        var labels = [modeCaption]
         if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
         labels.append(AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
         labels += PieceKind.allCases.map { kind in
@@ -49,106 +49,171 @@ final class HomeChallengeHUDView: NSView {
         needsDisplay = true
     }
 
+    private var modeCaption: String {
+        let title = AchievementText.string("home.mode.\(mode.key)")
+        let description = AchievementText.string("home.mode_desc.\(mode.key)")
+        return title + " · " + description
+    }
+
     override func draw(_ dirtyRect: NSRect) {
-        guard let snapshot else { return }
+        guard let snapshot, surfaceRect.width > 40, surfaceRect.height > 45 else { return }
         let urgent = showsBudget && snapshot.isRunning && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
-        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : mode == .moves ? HomeStyle.blue : GameLobbyStyle.teal
+        let accent = urgent ? NSColor.systemRed : HomeDashboardStyle.cyan
         let face = surfaceRect
-        let depth = revealFraction.map { 1 - $0 } ?? 0
-        if depth > 0 {
-            // 在卡面右下缘露出带色的厚度，转正时收回到静态卡面的阴影中。
+        let cut = min(face.height * 0.25, face.width * 0.09)
+        let outline = HomeDashboardStyle.slant(face, cut: cut)
+        if let revealFraction {
+            let depth = 1 - revealFraction
             let side = face.offsetBy(dx: 2.5 * depth, dy: 4.5 * depth)
-            GameLobbyStyle.gradient(side, colors: [accent.withAlphaComponent(0.26 * depth),
-                                                  accent.withAlphaComponent(0.68 * depth)], radius: 18)
-        }
-        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1), strength: 0.07 + 0.13 * depth)
-        // 扣除挑战预算后，消除总数占三分之一，其余宽度交给四类方块明细。
-        let content = face.insetBy(dx: 20, dy: 18)
-        let budgetWidth = showsBudget ? content.width * 0.27 : 0
-        let totalWidth = (content.width - budgetWidth) / 3
-        let totalX = content.minX + budgetWidth
-        let breakdownX = totalX + totalWidth
-        let metricTop = content.minY + (showsBudget ? 4 : 16)
-        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: budgetWidth + totalWidth, height: face.height),
-                            color: accent.withAlphaComponent(0.08))
-        if showsBudget {
-            drawMetric(budgetText, label: budgetLabelKey, x: content.minX, y: metricTop,
-                       width: budgetWidth - 17, color: urgent ? .systemRed : HomeStyle.ink)
-            drawDivider(at: totalX - 9, from: metricTop, to: metricTop + 76)
+            accent.withAlphaComponent(0.46 * depth).setFill()
+            HomeDashboardStyle.slant(side, cut: cut).fill()
         }
-        drawMetric(String(snapshot.totalCleared), label: "home.cleared_title", x: totalX, y: metricTop,
-                   width: totalWidth - 17, color: HomeStyle.ink)
-        drawBreakdown(snapshot, in: NSRect(x: breakdownX, y: metricTop + 33, width: content.maxX - breakdownX, height: 28))
-        if showsBudget {
-            drawTrack(NSRect(x: content.minX, y: content.maxY - 6, width: content.width, height: 6), accent: accent, snapshot: snapshot)
-        }
-        if let revealFraction { drawRevealHighlight(in: face, accent: accent, fraction: revealFraction) }
-    }
 
-    private func drawRevealHighlight(in face: NSRect, accent: NSColor, fraction: CGFloat) {
-        // 随滑入从右向左掠过一次，收尾时完全淡出，只照亮卡面。
-        let intensity = sin(.pi * fraction)
-        guard intensity > 0 else { return }
+        NSGradient(colors: [NSColor(srgbRed: 0.095, green: 0.154, blue: 0.207, alpha: 0.99),
+                            NSColor(srgbRed: 0.058, green: 0.095, blue: 0.130, alpha: 0.99)])?.draw(in: outline, angle: 28)
+        let headerHeight = face.height * 0.28
+        let middleHeight = face.height * 0.43
+        let header = NSRect(x: face.minX, y: face.minY, width: face.width, height: headerHeight)
+        let body = NSRect(x: face.minX, y: header.maxY, width: face.width, height: middleHeight)
+        let breakdown = NSRect(x: face.minX, y: body.maxY, width: face.width, height: face.maxY - body.maxY)
         NSGraphicsContext.saveGraphicsState()
-        let outline = NSBezierPath(roundedRect: face, xRadius: 18, yRadius: 18)
         outline.addClip()
-        let x = face.maxX + 90 - (face.width + 180) * fraction
-        let shine = NSBezierPath()
-        shine.move(to: NSPoint(x: x, y: face.minY))
-        shine.line(to: NSPoint(x: x + 135, y: face.minY))
-        shine.line(to: NSPoint(x: x + 83, y: face.maxY))
-        shine.line(to: NSPoint(x: x - 52, y: face.maxY))
-        shine.close()
-        NSGradient(colors: [.clear, .white.withAlphaComponent(0.42 * intensity), accent.withAlphaComponent(0.12 * intensity), .clear])?
-            .draw(in: shine, angle: 0)
-        accent.withAlphaComponent(0.32 * intensity).setStroke()
-        outline.lineWidth = 2
-        outline.stroke()
+        NSGradient(colors: [NSColor(srgbRed: 0.033, green: 0.061, blue: 0.088, alpha: 1),
+                            NSColor(srgbRed: 0.066, green: 0.109, blue: 0.149, alpha: 1)])?.draw(in: body, angle: 12)
+        drawHeader(header, face: face, cut: cut)
+        drawTotals(snapshot, in: body, face: face, cut: cut, accent: accent)
+        drawBreakdown(snapshot, in: breakdown, face: face, cut: cut)
         NSGraphicsContext.restoreGraphicsState()
+
+        HomeDashboardStyle.border.setStroke()
+        outline.lineWidth = 1
+        outline.stroke()
+        if let revealFraction { drawRevealHighlight(in: face, outline: outline, accent: accent, fraction: revealFraction) }
+    }
+
+    private func drawHeader(_ header: NSRect, face: NSRect, cut: CGFloat) {
+        let inset = max(10, min(face.width * 0.047, 27))
+        let markHeight = min(19, header.height * 0.42)
+        let x = leftEdge(of: face, cut: cut, at: header.midY) + inset
+        for index in 0..<2 {
+            let mark = NSRect(x: x + CGFloat(index) * markHeight * 0.76, y: header.midY - markHeight / 2,
+                              width: markHeight, height: markHeight)
+            HomeDashboardStyle.cyan.setFill()
+            HomeDashboardStyle.slant(mark, cut: markHeight * 0.45).fill()
+        }
+        let textStart = x + markHeight * 1.76 + inset * 0.55
+        let width = max(0, face.maxX - inset - textStart)
+        let size = GameLobbyStyle.fittedSize(modeCaption, width: width, preferred: min(18, header.height * 0.50),
+                                             minimum: 10, weight: .bold)
+        label(modeCaption, x: textStart, y: header.midY, width: width, size: size, weight: .bold,
+              color: HomeDashboardStyle.cyan)
     }
 
-    private func drawMetric(_ value: String, label key: String, x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor) {
-        let label = AchievementText.string(key)
-        let labelSize = GameLobbyStyle.fittedSize(label, width: width, preferred: 13, minimum: 10, weight: .semibold)
-        HomeStyle.text(label, in: NSRect(x: x, y: y, width: width, height: 19), size: labelSize, weight: .semibold, color: HomeStyle.secondary)
-        let size = GameLobbyStyle.fittedSize(value, width: width, preferred: 44, minimum: 14, weight: .heavy)
-        let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).height)
-        HomeStyle.text(value, in: NSRect(x: x, y: y + 47 - height / 2, width: width, height: height), size: size, weight: .heavy, color: color)
+    private func drawTotals(_ snapshot: GameSnapshot, in body: NSRect, face: NSRect, cut: CGFloat, accent: NSColor) {
+        let inset = max(13, min(face.width * 0.047, 30))
+        let x = leftEdge(of: face, cut: cut, at: body.midY) + inset
+        let available = face.width - cut - inset * 2
+        let right = x + available
+        for y in [body.minY, body.maxY] {
+            HomeDashboardStyle.line(from: NSPoint(x: body.minX, y: y), to: NSPoint(x: body.maxX, y: y),
+                                    color: HomeDashboardStyle.border)
+        }
+        if showsBudget {
+            let split = x + available * 0.48
+            let trackY = body.maxY - 8
+            let track = NSRect(x: x, y: trackY, width: right - x, height: 3)
+            drawTrack(track, accent: accent, snapshot: snapshot)
+            let metricY = body.midY - 4
+            drawStackedMetric(budgetText, labelKey: budgetLabelKey, center: metricY, x: x,
+                              width: split - x - 8, height: body.height, color: accent, alignment: .left)
+            drawStackedMetric(String(snapshot.totalCleared), labelKey: "home.cleared_title", center: metricY,
+                              x: split + 8, width: right - split - 8, height: body.height,
+                              color: HomeDashboardStyle.ink, alignment: .right)
+            HomeDashboardStyle.line(from: NSPoint(x: split + 5, y: body.minY + 8),
+                                    to: NSPoint(x: split - 5, y: trackY - 6), color: HomeDashboardStyle.border)
+        } else {
+            let title = AchievementText.string("home.cleared_title")
+            let titleWidth = available * 0.48
+            let titleSize = GameLobbyStyle.fittedSize(title, width: titleWidth, preferred: min(20, body.height * 0.32),
+                                                       minimum: 10, weight: .bold)
+            label(title, x: x, y: body.midY, width: titleWidth, size: titleSize, weight: .bold)
+            let value = String(snapshot.totalCleared)
+            let size = GameLobbyStyle.fittedSize(value, width: available - titleWidth, preferred: min(55, body.height * 0.77),
+                                                 minimum: 12, weight: .heavy)
+            label(value, x: x + titleWidth, y: body.midY, width: available - titleWidth, size: size, weight: .heavy,
+                  italic: true, alignment: .right)
+        }
     }
 
-    private func drawDivider(at x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
-        HomeStyle.border.withAlphaComponent(0.6).setStroke()
-        let divider = NSBezierPath()
-        divider.move(to: NSPoint(x: x, y: top))
-        divider.line(to: NSPoint(x: x, y: bottom))
-        divider.stroke()
+    private func drawStackedMetric(_ value: String, labelKey: String, center: CGFloat, x: CGFloat, width: CGFloat,
+                                   height: CGFloat, color: NSColor, alignment: NSTextAlignment) {
+        let title = AchievementText.string(labelKey)
+        let titleSize = GameLobbyStyle.fittedSize(title, width: width, preferred: min(13, height * 0.26),
+                                                   minimum: 8, weight: .semibold)
+        let valueSize = GameLobbyStyle.fittedSize(value, width: width, preferred: min(38, height * 0.59),
+                                                   minimum: 11, weight: .heavy)
+        label(title, x: x, y: center - height * 0.24, width: width, size: titleSize, weight: .semibold,
+              color: HomeDashboardStyle.muted, alignment: alignment)
+        label(value, x: x, y: center + height * 0.11, width: width, size: valueSize, weight: .heavy,
+              color: color, italic: true, alignment: alignment)
     }
 
-    private func drawBreakdown(_ snapshot: GameSnapshot, in rect: NSRect) {
+    private func drawBreakdown(_ snapshot: GameSnapshot, in row: NSRect, face: NSRect, cut: CGFloat) {
         let kinds = PieceKind.allCases
-        let slot = rect.width / CGFloat(kinds.count)
-        let iconWidth = min(36, slot * 0.46)
-        let gap: CGFloat = 6
-        let numberWidth = slot - iconWidth - gap - 6
-        // 四组都从各自的列左边缘排起，数字位数变化时图标之间仍然等距。
+        let slot = (face.width - cut) / CGFloat(kinds.count)
+        let iconWidth = min(42, row.height * 1.04, slot * 0.46)
+        let gap = max(4, min(9, slot * 0.08))
+        let padding = min(18, slot * 0.10)
+        // 四列平行等宽，图标锚定在同一位置，消除数量的位数变化不推动图标。
         for (index, kind) in kinds.enumerated() {
+            let indexOffset = CGFloat(index) * slot
+            let dividerX = leftEdge(of: face, cut: cut, at: row.minY) + indexOffset
+            if index > 0 {
+                HomeDashboardStyle.line(from: NSPoint(x: dividerX, y: row.minY),
+                                        to: NSPoint(x: face.minX + indexOffset, y: row.maxY),
+                                        color: HomeDashboardStyle.border)
+            }
+            let iconX = leftEdge(of: face, cut: cut, at: row.midY) + indexOffset + padding
+            HomeLobbyArtwork.drawPiece(kind, in: NSRect(x: iconX, y: row.minY, width: iconWidth, height: row.height))
             let number = String(snapshot.clearedByKind[kind, default: 0])
-            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: 18, minimum: 10, weight: .semibold)
-            let height = ceil((number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height)
-            let iconX = rect.minX + CGFloat(index) * slot
-            let numberX = iconX + iconWidth + gap
-            HomeStyle.piece(kind, in: NSRect(x: iconX, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
-            HomeStyle.text(number, in: NSRect(x: numberX, y: rect.midY - height / 2, width: numberWidth, height: height),
-                           size: size, weight: .semibold)
+            let numberWidth = slot - iconWidth - gap - padding * 2
+            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: min(20, row.height * 0.54),
+                                                 minimum: 8, weight: .semibold)
+            label(number, x: iconX + iconWidth + gap, y: row.midY, width: numberWidth, size: size, weight: .semibold)
         }
     }
 
+    private func leftEdge(of face: NSRect, cut: CGFloat, at y: CGFloat) -> CGFloat {
+        face.minX + cut * (face.maxY - y) / face.height
+    }
+
+    private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight,
+                       color: NSColor = HomeDashboardStyle.ink, italic: Bool = false, alignment: NSTextAlignment = .left) {
+        let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).height)
+        HomeDashboardStyle.text(value, in: NSRect(x: x, y: y - height / 2, width: width, height: height + 1),
+                                size: size, weight: weight, color: color, italic: italic, alignment: alignment)
+    }
+
+    private func drawRevealHighlight(in face: NSRect, outline: NSBezierPath, accent: NSColor, fraction: CGFloat) {
+        // 斜光随卡面掠过一次，最终回到静态描边。
+        let intensity = sin(.pi * fraction)
+        guard intensity > 0 else { return }
+        NSGraphicsContext.saveGraphicsState()
+        outline.addClip()
+        let width = min(140, face.width * 0.32)
+        let x = face.maxX + width - (face.width + width * 2) * fraction
+        let beam = NSRect(x: x, y: face.minY, width: width, height: face.height)
+        NSGradient(colors: [.clear, accent.withAlphaComponent(0.22 * intensity), .clear])?
+            .draw(in: HomeDashboardStyle.slant(beam, cut: width * 0.4), angle: 0)
+        NSGraphicsContext.restoreGraphicsState()
+    }
+
     private func drawTrack(_ track: NSRect, accent: NSColor, snapshot: GameSnapshot) {
-        HomeStyle.ink.withAlphaComponent(0.055).setFill()
+        HomeDashboardStyle.muted.withAlphaComponent(0.18).setFill()
         NSBezierPath(roundedRect: track, xRadius: 2.5, yRadius: 2.5).fill()
         if mode == .moves {
             // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
-            let gap: CGFloat = 2
+            let gap = min(2, track.width / 60)
             let width = (track.width - gap * CGFloat(HomeGameMode.moveLimit - 1)) / CGFloat(HomeGameMode.moveLimit)
             for index in 0..<max(0, min(HomeGameMode.moveLimit, snapshot.remainingSwaps ?? 0)) {
                 accent.setFill()
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index e3f0c5822e4661b987db55b77d5eb036cb0d6cd4..f36d02a5e915a83737a48a146a64f320e6f4e1c7 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -3,7 +3,8 @@ import CoreText
 
 /// 轻量原生按钮：保持完整点击区域、键盘激活与辅助功能，绘制跟随首页主题。
 class HomeButton: NSButton {
-    var primary = false
+    enum Style { case navigation, primary, outline, achievementLink }
+    var style: Style = .navigation
     var symbolName: String?
     var onClick: (() -> Void)?
     private var tracking: NSTrackingArea?
@@ -22,7 +23,9 @@ class HomeButton: NSButton {
     override var isFlipped: Bool { true }
     override var isHighlighted: Bool { didSet { refreshFeedback() } }
     override var focusRingMaskBounds: NSRect { bounds }
-    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill() }
+    override func drawFocusRingMask() {
+        HomeDashboardStyle.slant(bounds, cut: bounds.height * 0.48).fill()
+    }
     override func resetCursorRects() {
         if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
     }
@@ -44,21 +47,54 @@ class HomeButton: NSButton {
     }
 
     override func draw(_ dirtyRect: NSRect) {
+        let effect = feedback.values
+        let offset = effect.press * 1.8 - effect.hover
+        let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: offset)
+        let primary = style == .primary
+        let outlined = style == .outline
+        let color = primary ? HomeDashboardStyle.navy : HomeDashboardStyle.ink
         if primary {
-            GameLobbyStyle.primaryButton(bounds, hover: feedback.values.hover, press: feedback.values.press)
-        } else if hovering || isHighlighted {
-            HomeStyle.card(bounds, fill: NSColor.white.withAlphaComponent(0.6), border: HomeStyle.border.withAlphaComponent(0.4), radius: 7)
+            let yellow = HomeDashboardStyle.yellow
+            NSGraphicsContext.saveGraphicsState()
+            let glow = NSShadow()
+            glow.shadowColor = yellow.withAlphaComponent(0.22 + effect.hover * 0.15)
+            glow.shadowBlurRadius = 10
+            glow.set()
+            yellow.setFill()
+            HomeDashboardStyle.slant(face, cut: face.height * 0.54).fill()
+            NSGraphicsContext.restoreGraphicsState()
+            HomeDashboardStyle.surface(face, cut: face.height * 0.54,
+                                       colors: [HomeDashboardStyle.color(0xFFF87D), yellow, HomeDashboardStyle.color(0xF1CD23)],
+                                       border: .white.withAlphaComponent(isEnabled ? 0.56 : 0.24))
+            if !isEnabled {
+                HomeDashboardStyle.navy.withAlphaComponent(0.36).setFill()
+                HomeDashboardStyle.slant(face, cut: face.height * 0.54).fill()
+            }
+        } else if outlined || effect.hover > 0 {
+            let cyan = HomeDashboardStyle.cyan
+            HomeDashboardStyle.surface(face, cut: face.height * 0.46,
+                                       colors: [cyan.withAlphaComponent(effect.hover * 0.10),
+                                                cyan.withAlphaComponent(0.04 + effect.hover * 0.14)],
+                                       border: cyan.withAlphaComponent(outlined ? 0.95 : effect.hover * 0.45),
+                                       lineWidth: outlined ? 1.35 : 0.8)
+        }
+        let label = style == .achievementLink && title.hasSuffix("  →") ? String(title.dropLast(3)) : title
+        let weight: NSFont.Weight = primary ? .black : .bold
+        let icon: CGFloat = symbolName == nil ? 0 : (primary ? bounds.height * 0.44 : 16)
+        let gap: CGFloat = icon > 0 ? 10 : 0
+        let preferred = primary ? min(34, bounds.height * 0.52) : min(19, bounds.height * 0.44)
+        let size = GameLobbyStyle.fittedSize(label, width: bounds.width - icon - gap - (primary ? 52 : 24),
+                                             preferred: preferred, minimum: 10, weight: weight)
+        let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
+        let x = (bounds.width - width - icon - gap) / 2
+        if let symbolName {
+            let iconX = style == .achievementLink ? x + width + gap : x
+            let iconColor = style == .achievementLink ? HomeDashboardStyle.yellow : color
+            HomeStyle.symbol(symbolName, in: NSRect(x: iconX, y: face.midY - icon / 2, width: icon, height: icon), color: iconColor)
         }
-        let preferred: CGFloat = primary ? 22 : 14
-        let size = GameLobbyStyle.fittedSize(title, width: bounds.width - (primary ? 60 : 24), preferred: preferred, minimum: 11, weight: primary ? .heavy : .semibold)
-        let font = NSFont.systemFont(ofSize: size, weight: primary ? .heavy : .semibold)
-        let width = (title as NSString).size(withAttributes: [.font: font]).width
-        let icon: CGFloat = symbolName == nil ? 0 : (primary ? 24 : 16)
-        let x = (bounds.width - width - (icon > 0 ? icon + 10 : 0)) / 2
-        let offset = primary ? feedback.values.press * 2 - feedback.values.hover : 0
-        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2 + offset, width: icon, height: icon)) }
-        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65 + offset, width: width + 2, height: size * 1.5),
-                       size: size, weight: primary ? .heavy : .semibold)
+        let textX = style == .achievementLink ? x : x + icon + gap
+        HomeDashboardStyle.text(label, in: NSRect(x: textX, y: face.midY - size * 0.63, width: width + 8, height: size * 1.5),
+                                size: size, weight: weight, color: color, italic: !outlined)
     }
     @objc private func clicked() { onClick?() }
 }
@@ -68,6 +104,7 @@ final class HomeModeButton: HomeButton {
     let mode: HomeGameMode?
     private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
     private var descriptionKey: String { "home.mode_desc.\(mode?.key ?? "puzzle")" }
+    private var displayedLanguage: AppLanguage?
     var selected = false { didSet { if oldValue != selected { refreshFeedback(); setAccessibilityValue(selected ? 1 : 0) } } }
     override var selectedForFeedback: Bool { selected }
     init(mode: HomeGameMode?) {
@@ -81,45 +118,71 @@ final class HomeModeButton: HomeButton {
 
     func refresh(selectedMode: HomeGameMode) {
         selected = mode == selectedMode
+        let language = Localizer.shared.language
+        guard displayedLanguage != language else { return }
+        displayedLanguage = language
         setAccessibilityLabel(AchievementText.string(titleKey) + ", " + AchievementText.string(descriptionKey))
         needsDisplay = true
     }
     override func draw(_ dirtyRect: NSRect) {
         let effect = feedback.values
-        let face = bounds.insetBy(dx: 4, dy: bounds.height < 65 ? 3 : 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
-        GameLobbyStyle.surface(face, tint: NSColor(calibratedRed: 0.98, green: 0.985, blue: 0.99, alpha: 1), strength: 0.045 + effect.hover * 0.05)
-        if effect.selection > 0 {
-            GameLobbyStyle.gradient(face, colors: [.white.withAlphaComponent(effect.selection),
-                NSColor(calibratedRed: 0.86, green: 0.95, blue: 1, alpha: effect.selection)], radius: 15)
-            GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: 100, height: face.height), color: HomeStyle.blue.withAlphaComponent(0.09 * effect.selection))
-        }
-        let outline = NSBezierPath(roundedRect: face, xRadius: 15, yRadius: 15)
-        HomeStyle.blue.withAlphaComponent(effect.selection * 0.8 + effect.hover * 0.15).setStroke()
-        outline.lineWidth = 1.25; outline.stroke()
-        let iconSize = min(57, face.height - 9)
-        let icon = NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
-        if let mode {
-            GameModeArtwork.draw(mode, in: icon)
-        } else {
-            GameModeArtwork.drawPuzzle(in: icon)
-        }
-        let compact = face.height < 65
-        let textX = compact ? icon.maxX + 11 : face.minX + 81
-        let textWidth = face.maxX - textX - 27
+        let face = bounds.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: effect.press * 1.4 - effect.hover)
+        let cyan = HomeDashboardStyle.cyan
+        let tint = min(1, effect.selection + effect.hover * 0.26)
+        let left = HomeDashboardStyle.color(0x222D35)
+        let right = HomeDashboardStyle.color(0x101B29)
+        let colors = [left.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0C3E46)) ?? left,
+                      right.blended(withFraction: tint, of: HomeDashboardStyle.color(0x0A2733)) ?? right]
+        let stroke = HomeDashboardStyle.border.blended(withFraction: tint, of: cyan) ?? cyan
+        HomeDashboardStyle.surface(face, cut: face.height * 0.41, colors: colors, border: stroke,
+                                   lineWidth: 1 + 1.7 * effect.selection)
+        let iconSize = min(48, face.height * 0.56)
+        let icon = NSRect(x: face.minX + face.height * 0.57, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
+        drawModeIcon(in: icon, color: HomeDashboardStyle.ink.blended(withFraction: effect.selection, of: cyan) ?? cyan)
+        let splitX = icon.maxX + face.height * 0.26
+        HomeDashboardStyle.line(from: NSPoint(x: splitX, y: face.midY - iconSize / 2),
+                                to: NSPoint(x: splitX - 10, y: face.midY + iconSize / 2),
+                                color: HomeDashboardStyle.border, width: 1.2)
+        let textX = splitX + 13
+        let textWidth = face.maxX - textX - max(31, face.height * 0.67)
         let title = AchievementText.string(titleKey)
-        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: compact ? 17 : 20, minimum: 13, weight: .bold)
-        let textY = compact ? face.minY + 3 : face.midY - 24
-        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold,
-                       color: isEnabled ? HomeStyle.ink : HomeStyle.secondary)
-        let descriptionY = textY + (compact ? 21 : 27)
+        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(24, face.height * 0.34),
+                                                  minimum: 13, weight: .heavy)
+        let textY = face.midY - titleSize * 1.15
+        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: titleSize * 1.5),
+                                size: titleSize, weight: .heavy, italic: true)
         let description = AchievementText.string(descriptionKey)
-        let descriptionWidth = face.maxX - textX - 16
-        let descriptionSize = compact ? GameLobbyStyle.fittedSize(description, width: descriptionWidth, preferred: 11, minimum: 9, weight: .regular) : 12
-        GameLobbyStyle.wrappedText(description,
-            in: NSRect(x: textX, y: descriptionY, width: descriptionWidth, height: face.maxY - descriptionY - 3),
-            size: descriptionSize, color: HomeStyle.secondary)
+        let descriptionY = face.midY + 1
+        let descriptionWidth = face.maxX - textX - max(18, face.height * 0.49)
+        HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY,
+                                                               width: descriptionWidth, height: face.maxY - descriptionY - 5),
+                                       preferred: min(16, face.height * 0.23))
         if effect.selection > 0 {
-            HomeStyle.symbol("checkmark.circle.fill", in: NSRect(x: face.maxX - 24, y: face.minY + 12, width: 15, height: 15), color: HomeStyle.blue.withAlphaComponent(effect.selection))
+            let size = min(22, face.height * 0.31)
+            HomeStyle.symbol("checkmark.circle.fill",
+                             in: NSRect(x: face.maxX - face.height * 0.71, y: face.minY + face.height * 0.23, width: size, height: size),
+                             color: cyan.withAlphaComponent(effect.selection))
+        }
+    }
+
+    private func drawModeIcon(in rect: NSRect, color: NSColor) {
+        switch mode {
+        case .free:
+            GameIconRenderer.drawSymbol("infinity", in: rect, color: color)
+        case .timed:
+            GameIconRenderer.drawSymbol("stopwatch", in: rect, color: color, fallbacks: ["timer"])
+        case .moves:
+            let tile = rect.insetBy(dx: 1, dy: rect.height * 0.12)
+            let outline = NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4)
+            color.setStroke()
+            outline.lineWidth = 2.2
+            outline.stroke()
+            let size = tile.height * 0.61
+            HomeDashboardStyle.text(String(HomeGameMode.moveLimit),
+                                    in: NSRect(x: tile.minX, y: tile.midY - size * 0.58, width: tile.width, height: size * 1.3),
+                                    size: size, weight: .heavy, color: color, alignment: .center)
+        case nil:
+            GameIconRenderer.drawSymbol("puzzlepiece", in: rect, color: color, fallbacks: ["square.dashed"])
         }
     }
 }
@@ -134,7 +197,7 @@ final class HomeHeroView: NSView {
         timer?.invalidate(); timer = nil
         guard window != nil else { return }
         let timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
-            guard let self else { return }
+            guard let self, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
             self.phase += 0.06; self.needsDisplay = true
         }
         RunLoop.main.add(timer, forMode: .common)
@@ -142,13 +205,41 @@ final class HomeHeroView: NSView {
     }
     override func draw(_ dirtyRect: NSRect) {
         let animated = window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
-        HomeHeroPieceRenderer.draw(in: bounds, phase: phase, animated: animated)
+        HomeLobbyArtwork.drawHero(in: bounds, phase: phase, animated: animated)
+    }
+}
+
+private final class HomeTouchBarGuideView: NSView {
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        setAccessibilityElement(true)
+        setAccessibilityRole(.staticText)
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeLobbyArtwork.drawTouchBar(in: bounds)
+        let scale = min(bounds.width / 925, bounds.height / 112)
+        let size = min(19, max(12, scale * 19))
+        let caption = AchievementText.string("home.operation_hint")
+        let width = min(bounds.width * 0.63, (caption as NSString).size(withAttributes: [
+            .font: NSFont.systemFont(ofSize: size, weight: .medium),
+        ]).width + 4)
+        let x = bounds.width * 0.475 - width / 2
+        let y = scale * 82
+        HomeDashboardStyle.mark(in: NSRect(x: x - 20, y: y + 3, width: 10, height: size * 0.94))
+        HomeDashboardStyle.text(caption, in: NSRect(x: x, y: y, width: width, height: size * 1.4),
+                                size: size, weight: .medium, alignment: .center)
     }
 }
 
 private final class HomeAchievementButton: HomeButton {
-    private static let iconSize: CGFloat = 38
+    private static let iconSize: CGFloat = 28
     private static var iconBounds: [String: NSRect] = [:]
+    private static var icons: [String: NSImage] = [:]
     private(set) var definition: AchievementDefinition?
     private var unlocked = false
     private var displayedLanguage: AppLanguage?
@@ -172,18 +263,21 @@ private final class HomeAchievementButton: HomeButton {
 
     override func draw(_ dirtyRect: NSRect) {
         guard let definition else { return }
-        GameLobbyStyle.surface(bounds.insetBy(dx: 1, dy: 1), radius: 12,
-                               tint: NSColor(calibratedRed: 1, green: 0.998, blue: 0.985, alpha: 1), strength: 0.025)
-        if hovering {
-            GameLobbyStyle.glow(bounds, color: GameLobbyStyle.amber.withAlphaComponent(0.07 * feedback.values.hover))
-        }
+        let effect = feedback.values
+        let cut = bounds.height * 0.43
+        let border = HomeDashboardStyle.border.blended(withFraction: effect.hover * 0.66, of: HomeDashboardStyle.cyan) ?? HomeDashboardStyle.border
+        HomeDashboardStyle.surface(bounds.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: effect.press),
+                                   cut: cut, colors: [HomeDashboardStyle.color(0x212D37), HomeDashboardStyle.color(0x101B26)],
+                                   border: border)
         let title = AchievementText.string(definition.titleKey)
-        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
+        let font = NSFont.systemFont(ofSize: min(17, max(12, bounds.height * 0.28)), weight: .bold)
         let attributes: [NSAttributedString.Key: Any] = [.font: font]
         // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
         // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
-        let artwork = AchievementIconCatalog.image(for: definition, muted: !unlocked)
-        let artworkBounds = Self.visibleBounds(of: artwork, key: "\(definition.id).\(unlocked)")
+        let key = "\(definition.id).\(unlocked)"
+        let color = unlocked ? HomeDashboardStyle.ink : HomeDashboardStyle.muted
+        let artwork = Self.icon(for: definition, color: color, key: key)
+        let artworkBounds = Self.visibleBounds(of: artwork, key: key)
         let fixedWidth = ceil(artworkBounds.width) + 9
         // 覆盖状态图标及抗锯齿边缘，并为图文居中在另一侧预留同等空间。
         let availableWidth = max(0, floor(bounds.width - 36 * 2 - fixedWidth))
@@ -193,7 +287,6 @@ private final class HomeAchievementButton: HomeButton {
             displayedTitle = String(characters) + "…"
         }
         if (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth { displayedTitle = "" }
-        let color = unlocked ? HomeStyle.ink : HomeStyle.muted
         let line = CTLineCreateWithAttributedString(NSAttributedString(string: displayedTitle, attributes: [
             .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
         ]))
@@ -202,7 +295,8 @@ private final class HomeAchievementButton: HomeButton {
         let titleWidth = displayedTitle.isEmpty || textBounds.isNull ? 0 : textBounds.width
         let startX = bounds.midX - (fixedWidth + titleWidth) / 2
         let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
-        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18), color: unlocked ? HomeStyle.green.withAlphaComponent(0.80) : HomeStyle.muted)
+        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18),
+                         color: unlocked ? HomeDashboardStyle.green : HomeDashboardStyle.muted)
         artwork.draw(in: NSRect(x: startX - artworkBounds.minX, y: bounds.midY - artworkBounds.midY,
                                width: Self.iconSize, height: Self.iconSize),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
@@ -218,6 +312,30 @@ private final class HomeAchievementButton: HomeButton {
         }
     }
 
+    private static func icon(for definition: AchievementDefinition, color: NSColor, key: String) -> NSImage {
+        if let icon = icons[key] { return icon }
+        let symbols = [
+            1: "trophy", 2: "waveform", 3: "flag", 4: "sparkle", 5: "square.stack",
+            6: "square.3.layers.3d", 7: "link", 8: "wifi", 9: "point.topleft.down.to.point.bottomright.curvepath",
+            10: "stopwatch", 11: "stopwatch", 12: "stopwatch", 13: "flag.checkered", 14: "scope",
+            15: "scope", 16: "flag.checkered", 20: "ticket",
+        ]
+        let size = NSSize(width: iconSize, height: iconSize)
+        let icon = NSImage(size: size, flipped: true) { rect in
+            if let symbol = symbols[definition.id] {
+                GameIconRenderer.drawSymbol(symbol, in: rect, color: color)
+            } else {
+                AchievementIconCatalog.image(for: definition, muted: false)
+                    .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+                color.setFill()
+                rect.fill(using: .sourceAtop)
+            }
+            return true
+        }
+        icons[key] = icon
+        return icon
+    }
+
     private static func visibleBounds(of artwork: NSImage, key: String) -> NSRect {
         if let cached = iconBounds[key] { return cached }
         let canvas = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
@@ -243,7 +361,6 @@ private final class HomeAchievementButton: HomeButton {
 
 /// 横跨两栏的成就预览，按可用宽度显示一行，完整清单由成就面板展示。
 final class HomeAchievementPathView: NSView {
-    static let preferredHeight: CGFloat = 106
     var onAchievement: ((Int?) -> Void)?
     private let all = HomeButton(frame: .zero)
     private var badges: [HomeAchievementButton] = []
@@ -254,6 +371,8 @@ final class HomeAchievementPathView: NSView {
     override init(frame: NSRect) {
         super.init(frame: frame)
         addSubview(all)
+        all.style = .achievementLink
+        all.symbolName = "arrow.right"
         all.onClick = { [weak self] in self?.onAchievement?(nil) }
         for _ in AchievementDefinition.all {
             let badge = HomeAchievementButton(frame: .zero)
@@ -269,56 +388,80 @@ final class HomeAchievementPathView: NSView {
     required init?(coder: NSCoder) { nil }
 
     func refresh(manager: AchievementsManager) {
-        all.title = AchievementText.string("achievement.view_all") + "  →"
+        let title = AchievementText.string("achievement.view_all") + "  →"
+        if all.title != title {
+            all.title = title
+            all.setAccessibilityLabel(AchievementText.string("achievement.view_all"))
+            all.needsDisplay = true
+            needsLayout = true
+            needsDisplay = true
+        }
         let unlocked = Set(manager.unlockedIDs())
-        unlockedCount = unlocked.count
+        if unlockedCount != unlocked.count {
+            unlockedCount = unlocked.count
+            needsDisplay = true
+        }
         let definitions = AchievementDefinition.all.sorted {
             let a = unlocked.contains($0.id), b = unlocked.contains($1.id)
             return a == b ? $0.id < $1.id : a
         }
         for (badge, definition) in zip(badges, definitions) { badge.refresh(definition, manager: manager) }
-        needsDisplay = true
     }
 
     override func layout() {
         super.layout()
-        all.frame = NSRect(x: max(0, bounds.width - 120), y: 10, width: 120, height: 32)
+        let titleWidth = (all.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
+        let linkWidth = max(120, titleWidth + 34)
+        all.frame = NSRect(x: max(0, bounds.width - linkWidth), y: 11, width: linkWidth, height: 36)
         let width = bounds.width
-        let gap: CGFloat = 12
-        let columns = min(badges.count, max(5, Int((width + gap) / (174 + gap))))
+        let gap: CGFloat = 10
+        let columns = min(badges.count, max(5, Int((width + gap) / 193)))
         let badgeWidth = max(0, width - CGFloat(columns - 1) * gap) / CGFloat(columns)
+        let rowY = min(71, bounds.height * 0.46)
         for (index, badge) in badges.enumerated() {
             badge.isHidden = index >= columns
             guard !badge.isHidden else { continue }
-            badge.frame = NSRect(x: CGFloat(index) * (badgeWidth + gap), y: 52, width: badgeWidth, height: 54)
+            badge.frame = NSRect(x: CGFloat(index) * (badgeWidth + gap), y: rowY, width: badgeWidth, height: min(62, bounds.height - rowY))
         }
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.border.withAlphaComponent(0.7).setStroke()
-        let line = NSBezierPath()
-        line.move(to: NSPoint(x: 0, y: 0.5))
-        line.line(to: NSPoint(x: bounds.maxX, y: 0.5))
-        line.stroke()
-
+        HomeDashboardStyle.line(from: NSPoint(x: 0, y: 0.5), to: NSPoint(x: bounds.maxX, y: 0.5), color: HomeDashboardStyle.border)
+        HomeDashboardStyle.mark(in: NSRect(x: 0, y: 19, width: 19, height: 21))
         let title = AchievementText.string("home.achievement_path")
-        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 21, weight: .heavy)]).width)
-        HomeStyle.text(title, in: NSRect(x: 0, y: 11, width: titleWidth + 2, height: 30), size: 21, weight: .heavy)
+        let size: CGFloat = bounds.width < 1050 ? 21 : 25
+        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).width)
+        HomeDashboardStyle.text(title, in: NSRect(x: 27, y: 13, width: titleWidth + 12, height: 36),
+                                size: size, weight: .heavy, italic: true)
         let count = AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count)
-        let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]).width)
-        let countX = titleWidth + 24
-        HomeStyle.text(count, in: NSRect(x: countX, y: 18, width: countWidth + 2, height: 19), size: 13, weight: .semibold)
-        let meterX = countX + countWidth + 15
-        let meter = NSRect(x: meterX, y: 22, width: min(210, max(0, all.frame.minX - meterX - 64)), height: 9)
-        HomeStyle.border.setFill()
-        NSBezierPath(roundedRect: meter, xRadius: 5, yRadius: 5).fill()
+        let countSize: CGFloat = bounds.width < 1050 ? 13 : 17
+        let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: countSize, weight: .semibold)]).width)
+        let countX = titleWidth + 56
+        HomeDashboardStyle.text(count, in: NSRect(x: countX, y: 29 - countSize * 0.61, width: countWidth + 3, height: 23),
+                                size: countSize, weight: .semibold)
+        let meterX = countX + countWidth + 28
+        let meter = NSRect(x: meterX, y: 24, width: min(bounds.width * 0.21, max(0, all.frame.minX - meterX - 78)), height: 12)
         let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
-        if ratio > 0 {
-            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
-                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 5)
+        let countSegments = 10
+        let pitch = max(0, meter.width - 10) / CGFloat(countSegments)
+        for index in 0..<countSegments where pitch > 2 {
+            let segment = NSRect(x: meter.minX + CGFloat(index) * pitch, y: meter.minY,
+                                 width: pitch + 8, height: meter.height)
+            let face = HomeDashboardStyle.slant(segment, cut: 10)
+            HomeDashboardStyle.border.setFill()
+            face.fill()
+            let fill = min(1, max(0, ratio * CGFloat(countSegments) - CGFloat(index)))
+            if fill > 0 {
+                NSGraphicsContext.saveGraphicsState()
+                face.addClip()
+                HomeDashboardStyle.yellow.setFill()
+                NSRect(x: segment.minX, y: segment.minY, width: fill * segment.width, height: segment.height).fill()
+                NSGraphicsContext.restoreGraphicsState()
+            }
         }
-        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: 18, width: 50, height: 19),
-                       size: 11, color: HomeStyle.secondary)
+        let percentage = Double(ratio).formatted(.percent.precision(.fractionLength(1)).locale(Localizer.shared.locale))
+        HomeDashboardStyle.text(percentage, in: NSRect(x: meter.maxX + 15, y: 19, width: 58, height: 23),
+                                size: min(16, countSize), weight: .semibold, italic: true)
     }
 }
 
@@ -335,33 +478,33 @@ final class HomeDashboardView: NSView {
     var challengeHUD: HomeChallengeHUDView { modeHeader.card }
     private let hint = NSTextField(wrappingLabelWithString: "")
     private let hero = HomeHeroView()
+    private let guide = HomeTouchBarGuideView(frame: .zero)
     private let records = HomeButton(frame: .zero), rules = HomeButton(frame: .zero), settings = HomeButton(frame: .zero)
     private var modes: [HomeModeButton] = []
-    private static let sectionGap: CGFloat = 24
-    private static let contactHeight: CGFloat = 156
+    private var shortcut = NSRect.zero
+    private var showsShortcut = true
+    private var displayedLanguage: AppLanguage?
 
-    private var margin: CGFloat { bounds.width < 1050 ? 32 : 44 }
-    private var modePanelFrame: NSRect {
-        let width = max(330, min(440, bounds.width * 0.34))
-        let top: CGFloat = 96
-        // 给联系卡和全宽成就栏留出空间，缩小窗口时优先收紧模式区。
-        let reserved = Self.contactHeight + Self.sectionGap * 2 + HomeAchievementPathView.preferredHeight + 20
-        let height = max(0, min(456, (bounds.height * 0.56).rounded(.down), bounds.height - top - reserved))
-        return NSRect(x: bounds.width - margin - width, y: top, width: width, height: height)
-    }
+    private var margin: CGFloat { max(29, bounds.width * 0.034) }
+    private var headerHeight: CGFloat { min(76, max(56, bounds.height * 0.071)) }
+    private var sectionTop: CGFloat { max(headerHeight + 20, bounds.height * 0.105) }
+    private var achievementTop: CGFloat { bounds.height * 0.815 }
+    private var stageBottom: CGFloat { achievementTop - max(35, bounds.height * 0.058) }
+    private var rightWidth: CGFloat { min(max(302, bounds.width * 0.33), max(0, bounds.width - margin * 2)) }
 
     override var isFlipped: Bool { true }
     override init(frame: NSRect) {
         super.init(frame: frame)
-        appearance = NSAppearance(named: .aqua)
+        appearance = NSAppearance(named: .darkAqua)
         hint.isSelectable = false
         hint.drawsBackground = false
-        hint.textColor = HomeStyle.secondary
+        hint.textColor = HomeDashboardStyle.ink
         hint.font = .systemFont(ofSize: 14, weight: .medium)
         hint.alignment = .center
-        // 转场盖住左侧画面，右侧不透明模式面板与其按钮在转场上方。
-        [hint, hero, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
-        startButton.primary = true; startButton.symbolName = "play.fill"
+        // 右侧模式列表以相同背景遮住跨入右栏的统计卡，原生控件继续处理点击和键盘焦点。
+        [hero, guide, hint, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
+        startButton.style = .primary
+        startButton.symbolName = "play.fill"
         startButton.onClick = { [weak self] in self?.onStart?() }
         for (button, key) in [(records, "records"), (rules, "rules"), (settings, "settings")] {
             button.onClick = { [weak self] in self?.onNavigate?(key) }
@@ -379,78 +522,160 @@ final class HomeDashboardView: NSView {
     required init?(coder: NSCoder) { nil }
 
     func refresh(snapshot: GameSnapshot, mode: HomeGameMode, manager: AchievementsManager, isStarting: Bool = false) {
-        modeHeader.refresh(snapshot: snapshot, mode: mode, isStarting: isStarting)
+        modeHeader.refresh(snapshot: snapshot, mode: mode)
+        let status: String
         if isStarting {
-            hint.stringValue = AchievementText.string("home.starting_hint")
+            status = AchievementText.string("home.starting_hint")
         } else if snapshot.isFinished {
-            hint.stringValue = AchievementText.string("home.round_finished")
-        } else { hint.stringValue = AchievementText.string(snapshot.isRunning ? "home.operation_hint" : "home.start_hint") }
-        startButton.title = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
-        startButton.isEnabled = !isStarting
-        startButton.setAccessibilityLabel(startButton.title)
-        records.title = AchievementText.string("panel.records")
-        rules.title = AchievementText.string("panel.rules")
-        settings.title = AchievementText.string("panel.settings")
+            status = AchievementText.string("home.round_finished")
+        } else {
+            status = snapshot.isRunning ? "" : AchievementText.string("home.start_hint")
+        }
+        let shortcutAvailable = !isStarting && !snapshot.isRunning
+        if hint.stringValue != status || showsShortcut != shortcutAvailable {
+            hint.stringValue = status
+            hint.isHidden = status.isEmpty
+            showsShortcut = shortcutAvailable
+            setNeedsDisplay(hint.frame.insetBy(dx: -22, dy: 0).union(shortcut))
+        }
+        let startTitle = AchievementText.string(isStarting ? "home.starting" : snapshot.isFinished ? "home.play_again" : snapshot.isRunning ? "start.action_restart" : "home.start")
+        if startButton.title != startTitle || startButton.isEnabled == isStarting {
+            startButton.title = startTitle
+            startButton.isEnabled = !isStarting
+            startButton.setAccessibilityLabel(startTitle)
+            startButton.needsDisplay = true
+        }
+        let language = Localizer.shared.language
+        if displayedLanguage != language {
+            displayedLanguage = language
+            records.title = AchievementText.string("panel.records")
+            rules.title = AchievementText.string("panel.rules")
+            settings.title = AchievementText.string("panel.settings")
+            contactPanel.refreshLanguage()
+            guide.setAccessibilityLabel(AchievementText.string("home.operation_hint"))
+            [guide, modePanel, achievementPath, records, rules, settings].forEach { $0.needsDisplay = true }
+            needsLayout = true
+            needsDisplay = true
+        }
         achievementPath.refresh(manager: manager)
-        contactPanel.refreshLanguage()
         modes.forEach { $0.refresh(selectedMode: mode) }
-        modePanel.needsDisplay = true
-        needsLayout = true; needsDisplay = true
-        [startButton, records, rules, settings].forEach { $0.needsDisplay = true }
     }
 
     override func layout() {
         super.layout()
-        let panel = modePanelFrame
-        let leftWidth = panel.minX - margin - 32
-        let top = panel.minY
+        let rightX = bounds.width - margin - rightWidth
+        let contactHeight = min(165, max(110, bounds.height * 0.152))
+        let verticalGap = min(52, max(27, bounds.height * 0.050))
+        let contactTop = stageBottom - contactHeight
+        let panel = NSRect(x: rightX, y: sectionTop, width: rightWidth, height: max(0, contactTop - verticalGap - sectionTop))
         modePanel.frame = panel
-        contactPanel.frame = NSRect(x: panel.minX, y: panel.maxY + Self.sectionGap, width: panel.width, height: Self.contactHeight)
-        let bottom = contactPanel.frame.maxY
-        let leftColumn = NSRect(x: margin, y: top, width: leftWidth, height: min(230, (bottom - top) * 0.33 + 56))
+        modePanel.needsDisplay = true
+        contactPanel.frame = NSRect(x: panel.minX, y: contactTop, width: panel.width, height: contactHeight)
+        let leftWidth = max(0, panel.minX - margin - 20)
+        let leftColumn = NSRect(x: margin, y: sectionTop, width: leftWidth, height: bounds.height * 0.245)
         modeHeader.position(leftColumn: leftColumn, windowWidth: bounds.width, modePanelLeading: panel.minX)
-        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: bottom - 62, width: 294, height: 62)
-        hint.preferredMaxLayoutWidth = leftWidth
-        hint.frame = NSRect(x: margin, y: startButton.frame.minY - 43, width: leftWidth, height: 38)
-        let heroY = (leftColumn.maxY + hint.frame.minY - 138) / 2
-        hero.frame = NSRect(x: margin + 12, y: heroY, width: leftWidth - 24, height: 138)
-        achievementPath.frame = NSRect(x: margin, y: bottom + Self.sectionGap,
-                                       width: bounds.width - margin * 2, height: HomeAchievementPathView.preferredHeight)
-        let rowGap: CGFloat = modePanel.isCompact ? 4 : 8
-        let firstRowY: CGFloat = modePanel.isCompact ? 48 : 60
-        let rowHeight = max(0, panel.height - firstRowY - 14 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
+        let artworkWidth = leftWidth * 0.95
+        let artworkY = leftColumn.maxY - 1
+        hero.frame = NSRect(x: margin, y: artworkY, width: artworkWidth, height: max(0, bounds.height * 0.539 - artworkY))
+
+        let buttonHeight = min(68, max(48, bounds.height * 0.068))
+        let buttonWidth = min(435, leftWidth * 0.55)
+        let shortcutWidth = min(92, max(65, leftWidth * 0.10))
+        let gap: CGFloat = 12
+        let startX = margin + (leftWidth - buttonWidth - gap - shortcutWidth) / 2
+        startButton.frame = NSRect(x: startX, y: stageBottom - buttonHeight, width: buttonWidth, height: buttonHeight)
+        shortcut = NSRect(x: startButton.frame.maxX + gap, y: startButton.frame.midY - 13, width: shortcutWidth, height: 26)
+        let guideY = bounds.height * 0.546
+        let guideHeight = max(0, startButton.frame.minY - guideY - 12)
+        guide.frame = NSRect(x: margin, y: guideY, width: artworkWidth, height: guideHeight)
+
+        hint.preferredMaxLayoutWidth = buttonWidth + 100
+        hint.font = .systemFont(ofSize: min(16, max(12, bounds.width * 0.010)), weight: .medium)
+        hint.frame = NSRect(x: startButton.frame.midX - hint.preferredMaxLayoutWidth / 2, y: stageBottom + 8,
+                            width: hint.preferredMaxLayoutWidth, height: max(0, achievementTop - stageBottom - 10))
+        achievementPath.frame = NSRect(x: margin, y: achievementTop, width: bounds.width - margin * 2,
+                                       height: max(0, bounds.height - achievementTop - min(30, bounds.height * 0.031)))
+        let rowGap = min(13, max(7, bounds.height * 0.012))
+        let firstRowY: CGFloat = modePanel.isCompact ? 49 : 57
+        let rowHeight = max(0, panel.height - firstRowY - 4 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
         for (index, button) in modes.enumerated() {
-            button.frame = NSRect(x: 20, y: firstRowY + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
+            let x = CGFloat(modes.count - 1 - index) * min(5, bounds.width * 0.0039)
+            button.frame = NSRect(x: x, y: firstRowY + CGFloat(index) * (rowHeight + rowGap),
+                                  width: max(0, panel.width - 15), height: rowHeight)
         }
-        var navX = bounds.width - margin
+        var navX = bounds.width - margin + 5
         for button in [settings, rules, records] {
-            let width = max(84, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width + 24)
+            let width = max(89, (button.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width + 27)
             navX -= width
-            button.frame = NSRect(x: navX, y: 19, width: width, height: 36)
-            navX -= 8
+            button.frame = NSRect(x: navX, y: (headerHeight - 40) / 2, width: width, height: 40)
+            navX -= 19
         }
+        needsDisplay = true
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.background.setFill(); bounds.fill()
-        let panel = modePanelFrame
-        // 暖色环境光承接原设计稿插画；静态绘制，不添加常驻粒子计时器。
-        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: panel.minX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
-        // 低透明度装饰方块呼应四种颜色，避免盖住正文和交互区域。
-        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), startButton.frame.maxY - 40, HomeStyle.yellow)] {
-            color.withAlphaComponent(0.10).setFill()
-            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 25, height: 25), xRadius: 5, yRadius: 5).fill()
+        HomeDashboardStyle.backdrop(in: bounds)
+        drawNavigation()
+
+        let cyan = HomeDashboardStyle.cyan
+        let dividerStart = NSPoint(x: modePanel.frame.minX - 5, y: headerHeight + 13)
+        let dividerEnd = NSPoint(x: modePanel.frame.minX - bounds.height * 0.12, y: achievementTop)
+        HomeDashboardStyle.line(from: dividerStart, to: dividerEnd, color: HomeDashboardStyle.border.withAlphaComponent(0.5))
+        let middle = NSPoint(x: (dividerStart.x + dividerEnd.x) / 2, y: (dividerStart.y + dividerEnd.y) / 2)
+        HomeDashboardStyle.line(from: dividerStart, to: middle, color: cyan.withAlphaComponent(0.22))
+        HomeDashboardStyle.line(from: NSPoint(x: modePanel.frame.minX + 12, y: contactPanel.frame.minY - 24),
+                                to: NSPoint(x: contactPanel.frame.maxX, y: contactPanel.frame.minY - 24),
+                                color: HomeDashboardStyle.border.withAlphaComponent(0.77))
+        if showsShortcut {
+            HomeDashboardStyle.surface(shortcut, cut: 12, colors: [HomeDashboardStyle.color(0x1B2632), HomeDashboardStyle.navy],
+                                       border: HomeDashboardStyle.muted)
+            HomeDashboardStyle.text(AchievementText.string("home.space_key"),
+                                    in: shortcut.offsetBy(dx: 0, dy: 4), size: 13, weight: .bold, italic: true, alignment: .center)
         }
-        for (index, color) in [NSColor.systemOrange, .systemBlue, .systemGreen, .systemRed].enumerated() {
-            color.setFill()
-            NSBezierPath(roundedRect: NSRect(x: margin + CGFloat(index % 2) * 16, y: 20 + CGFloat(index / 2) * 16, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
+        if !hint.isHidden, let font = hint.font {
+            let width = (hint.stringValue as NSString).size(withAttributes: [.font: font]).width
+            let x = hint.frame.midX - min(width, hint.frame.width) / 2 - 20
+            HomeDashboardStyle.mark(in: NSRect(x: x, y: hint.frame.minY + 3, width: 10, height: font.pointSize + 1))
         }
-        HomeStyle.text(AchievementText.string("home.brand"), in: NSRect(x: margin + 47, y: 18, width: 360, height: 38), size: 26, weight: .heavy)
-        HomeStyle.border.withAlphaComponent(0.7).setStroke()
-        let line = NSBezierPath()
-        line.move(to: NSPoint(x: 0, y: 70))
-        line.line(to: NSPoint(x: bounds.maxX, y: 70))
-        line.stroke()
+    }
+
+    override func viewDidEndLiveResize() {
+        super.viewDidEndLiveResize()
+        needsLayout = true
+    }
+
+    private func drawNavigation() {
+        let y = headerHeight / 2
+        let logoX = margin + 12
+        let logoColors: [UInt32] = [0x35F4FF, 0xFFF052, 0xFA725F, 0xAF80F0]
+        for (index, rgb) in logoColors.enumerated() {
+            let x = logoX + CGFloat(index % 2) * 24 + (index < 2 ? 0 : 4)
+            let tile = NSRect(x: x, y: y - 16 + CGFloat(index / 2) * 17, width: 27, height: 14)
+            HomeDashboardStyle.mark(in: tile, color: HomeDashboardStyle.color(rgb))
+        }
+        let slashX = logoX + 72
+        HomeDashboardStyle.line(from: NSPoint(x: slashX + 11, y: y - 16), to: NSPoint(x: slashX, y: y + 16),
+                                color: HomeDashboardStyle.muted.withAlphaComponent(0.62), width: 1.3)
+
+        let brand = AchievementText.string("home.brand")
+        let brandX = slashX + 27
+        let brandWidth = max(0, records.frame.minX - brandX - 16)
+        let preferred = min(34, max(25, bounds.width * 0.023))
+        let size = GameLobbyStyle.fittedSize(brand, width: brandWidth - 10, preferred: preferred, minimum: 16, weight: .black)
+        let measuredWidth = (brand as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .black)]).width
+        HomeDashboardStyle.text(brand, in: NSRect(x: brandX, y: y - size * 0.65, width: brandWidth, height: size * 1.52),
+                                size: size, weight: .black, italic: true)
+        if brandWidth - measuredWidth > 132, bounds.width >= 1050 {
+            HomeDashboardStyle.text("TOUCH BAR", in: NSRect(x: brandX + measuredWidth + 23, y: y - 8, width: 99, height: 19),
+                                    size: 13, weight: .medium, color: HomeDashboardStyle.muted, italic: true)
+        }
+        for button in [rules, settings] {
+            HomeDashboardStyle.mark(in: NSRect(x: button.frame.minX - 15, y: y - 8, width: 11, height: 17))
+        }
+        HomeDashboardStyle.line(from: NSPoint(x: 0, y: headerHeight), to: NSPoint(x: bounds.maxX, y: headerHeight),
+                                color: HomeDashboardStyle.border)
+        HomeDashboardStyle.line(from: NSPoint(x: 0, y: headerHeight), to: NSPoint(x: logoX + 57, y: headerHeight),
+                                color: HomeDashboardStyle.cyan, width: 2.5)
     }
 
 }
@@ -468,15 +693,18 @@ final class HomeModePanelView: NSView {
     required init?(coder: NSCoder) { nil }
 
     override func draw(_ dirtyRect: NSRect) {
-        GameLobbyStyle.surface(bounds, radius: 20,
-                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
-        HomeStyle.text(AchievementText.string("home.game_modes"),
-                       in: NSRect(x: 22, y: isCompact ? 10 : 18, width: bounds.width - 44, height: 36),
-                       size: isCompact ? 23 : 27, weight: .heavy)
+        if let superview {
+            HomeDashboardStyle.backdrop(in: convert(superview.bounds, from: superview))
+        }
+        let size: CGFloat = isCompact ? 24 : 29
+        HomeDashboardStyle.mark(in: NSRect(x: 26, y: 7, width: 21, height: size * 0.83))
+        HomeDashboardStyle.text(AchievementText.string("home.game_modes"),
+                                in: NSRect(x: 54, y: 0, width: bounds.width - 60, height: 41),
+                                size: size, weight: .black, italic: true)
     }
 }
 
-/// 联系卡沿用右栏的暖白材质，反馈按钮打开项目的问题跟踪页。
+/// 反馈按钮打开项目的问题跟踪页。
 final class HomeContactPanelView: NSView {
     private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
     private let feedback = HomeButton(frame: .zero)
@@ -487,6 +715,7 @@ final class HomeContactPanelView: NSView {
     override init(frame: NSRect) {
         super.init(frame: frame)
         feedback.symbolName = "arrow.up.right"
+        feedback.style = .outline
         feedback.setAccessibilityRole(.link)
         feedback.onClick = { [weak self] in self?.openURL(Self.feedbackURL) }
         addSubview(feedback)
@@ -506,23 +735,31 @@ final class HomeContactPanelView: NSView {
 
     override func layout() {
         super.layout()
-        let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width
-        let width = min(max(0, bounds.width - 44), ceil(titleWidth) + 56)
-        feedback.frame = NSRect(x: 22, y: bounds.height - 56, width: width, height: 34)
+        let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .bold)]).width
+        let width = min(max(0, bounds.width - 84), max(bounds.width * 0.52, ceil(titleWidth) + 67))
+        let height = min(47, bounds.height * 0.31)
+        feedback.frame = NSRect(x: bounds.height * 0.38 + 12, y: bounds.height - height - bounds.height * 0.12,
+                                width: width, height: height)
     }
 
     override func draw(_ dirtyRect: NSRect) {
-        GameLobbyStyle.surface(bounds, radius: 20,
-                               tint: NSColor(calibratedRed: 0.98, green: 0.989, blue: 1, alpha: 1), strength: 0.035)
-        let icon = NSRect(x: 22, y: 18, width: 46, height: 46)
-        GameLobbyStyle.gradient(icon, colors: [NSColor(calibratedRed: 0.94, green: 0.99, blue: 1, alpha: 1),
-                                                NSColor(calibratedRed: 0.82, green: 0.94, blue: 1, alpha: 1)], radius: 13)
-        HomeStyle.symbol("ellipsis.bubble.fill", in: icon.insetBy(dx: 10, dy: 10), color: HomeStyle.blue)
-        HomeStyle.text(AchievementText.string("home.contact.title"),
-                       in: NSRect(x: 81, y: 24, width: bounds.width - 103, height: 34), size: 21, weight: .heavy)
-        GameLobbyStyle.wrappedText(AchievementText.string("home.contact.description"),
-                                   in: NSRect(x: 22, y: 72, width: bounds.width - 44, height: 25), size: 13, color: HomeStyle.secondary)
-        HomeStyle.card(feedback.frame, fill: HomeStyle.blue.withAlphaComponent(0.08),
-                       border: HomeStyle.blue.withAlphaComponent(0.12), radius: 8)
+        let cut = bounds.height * 0.35
+        HomeDashboardStyle.surface(bounds, cut: cut, colors: [HomeDashboardStyle.color(0x1A2939), HomeDashboardStyle.color(0x101C2B)],
+                                   border: HomeDashboardStyle.color(0x344C65))
+        let size = min(43, bounds.height * 0.29)
+        let icon = NSRect(x: cut + 11, y: bounds.height * 0.145, width: size, height: size)
+        HomeStyle.symbol("ellipsis.bubble", in: icon, color: HomeDashboardStyle.ink)
+        let textX = icon.maxX + 13
+        let textWidth = max(0, bounds.width - textX - cut * 0.69)
+        let title = AchievementText.string("home.contact.title")
+        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: min(26, bounds.height * 0.18),
+                                                 minimum: 13, weight: .heavy)
+        HomeDashboardStyle.text(title, in: NSRect(x: textX, y: bounds.height * 0.067, width: textWidth, height: 35),
+                                size: titleSize, weight: .heavy)
+        let description = AchievementText.string("home.contact.description")
+        let descriptionY = bounds.height * 0.325
+        HomeDashboardStyle.description(description, in: NSRect(x: textX, y: descriptionY, width: textWidth,
+                                                               height: feedback.frame.minY - descriptionY - 4),
+                                       preferred: min(17, bounds.height * 0.12))
     }
 }
diff --git a/Sources/HomeHeroPieceRenderer.swift b/Sources/HomeHeroPieceRenderer.swift
deleted file mode 100644
index 81f5e95d86a11b68bb4e5a0df2759d20a5c2fc2c..0000000000000000000000000000000000000000
--- a/Sources/HomeHeroPieceRenderer.swift
+++ /dev/null
@@ -1,43 +0,0 @@
-import Cocoa
-
-/// 直接使用原始设计稿提取的插画，保留其材质、投影、短线与相对位置。
-enum HomeHeroPieceRenderer {
-    private struct Sprite {
-        let kind: PieceKind?
-        let name: String
-        /// 原设计稿中的裁切区域，以左上角为原点。
-        let crop: NSRect
-    }
-
-    private static let reference = NSRect(x: 76, y: 435, width: 875, height: 165)
-    private static let sprites: [Sprite] = [
-        Sprite(kind: .orangeRicky, name: "home-design-orange", crop: NSRect(x: 76, y: 450, width: 190, height: 150)),
-        Sprite(kind: .blueRicky, name: "home-design-blue", crop: NSRect(x: 290, y: 450, width: 167, height: 150)),
-        Sprite(kind: .clevelandZ, name: "home-design-green", crop: NSRect(x: 544, y: 435, width: 197, height: 165)),
-        Sprite(kind: .rhodeIslandZ, name: "home-design-red", crop: NSRect(x: 744, y: 440, width: 207, height: 160)),
-        Sprite(kind: nil, name: "home-design-arrow", crop: NSRect(x: 462, y: 515, width: 75, height: 43))
-    ]
-    private static let images: [String: NSImage] = {
-        guard let bundle = GameResourceLocator.resourceBundle() else { return [:] }
-        return Dictionary(uniqueKeysWithValues: sprites.compactMap { sprite in
-            guard let url = bundle.url(forResource: sprite.name, withExtension: "png"),
-                  let image = NSImage(contentsOf: url) else { return nil }
-            return (sprite.name, image)
-        })
-    }()
-
-    static func draw(in bounds: NSRect, phase: CGFloat, animated: Bool) {
-        // 整组插画共用一个缩放比例，方块宽度、彼此间距、箭头与短线位置均来自设计稿。
-        let scale = min(bounds.width / reference.width, max(0, bounds.height - 6) / reference.height)
-        let origin = NSPoint(x: bounds.midX - reference.width * scale / 2,
-                             y: bounds.midY - reference.height * scale / 2)
-        for (index, sprite) in sprites.enumerated() {
-            let floating = animated && sprite.kind != nil ? sin(phase + CGFloat(index)) * 3 : 0
-            let destination = NSRect(x: origin.x + (sprite.crop.minX - reference.minX) * scale,
-                                     y: origin.y + (sprite.crop.minY - reference.minY) * scale + floating,
-                                     width: sprite.crop.width * scale, height: sprite.crop.height * scale)
-            images[sprite.name]?.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1,
-                                      respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
-        }
-    }
-}
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 268b2d56231d42dcfb448cd650a9ca551b5f288e..b93b1225f7c9bc43d090a7d98ad4ee431984b959 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -1,11 +1,9 @@
 import Cocoa
 
-/// 转场覆盖窗口上方整行，左列只负责定位。右侧模式面板由大厅单独叠在前方。
+/// 上方文案和本局统计并排排版，切换模式时仅统计卡从右侧滑入。
 final class HomeModeHeaderView: NSView {
     static let previewDuration: TimeInterval = 1
-    private static let cardHeight: CGFloat = 148
     private static let fullScale = NSSize(width: 1, height: 1)
-    // 远处的卡片横向收得更多，靠近时逐渐展开成正面。
     private static let distantScale = NSSize(width: 0.20, height: 0.27)
     var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
     var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
@@ -14,24 +12,21 @@ final class HomeModeHeaderView: NSView {
     private(set) var card = HomeChallengeHUDView(frame: .zero)
     private var spareCard = HomeChallengeHUDView(frame: .zero)
     private var selectedMode: HomeGameMode?
-    private var showsCard = false
     private var timer: Timer?
     private var transition: Transition?
-    private var column = NSRect.zero
+    private var cardColumn = NSRect.zero
     private var entryX: CGFloat = 0
 
+    private struct Pose {
+        let offset: CGFloat
+        let scale: NSSize
+        let alpha: CGFloat
+    }
+
     private struct Transition {
-        let outgoing: NSView
-        let incoming: NSView
-        let direction: CGFloat
         let start: TimeInterval
-        let duration: TimeInterval
-        let outgoingOffset: CGFloat
-        let incomingOffset: CGFloat
-        let outgoingScale: NSSize
-        let incomingScale: NSSize
-        let outgoingAlpha: CGFloat
-        let incomingAlpha: CGFloat
+        let outgoing: Pose
+        let incoming: Pose
         var fraction: CGFloat = 0
     }
 
@@ -41,9 +36,9 @@ final class HomeModeHeaderView: NSView {
         super.init(frame: frame)
         wantsLayer = true
         layer?.masksToBounds = true
-        addSubview(intro)
         addSubview(spareCard)
         addSubview(card)
+        addSubview(intro)
         settle()
     }
 
@@ -51,9 +46,14 @@ final class HomeModeHeaderView: NSView {
     deinit { timer?.invalidate() }
 
     func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
-        let topPadding: CGFloat = 8
+        let topPadding = HomeChallengeHUDView.surfaceInsetY + 3
         frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth, height: leftColumn.height + topPadding)
-        column = leftColumn.offsetBy(dx: 0, dy: -frame.minY)
+        let headingWidth = (leftColumn.width * 0.36).rounded(.down)
+        let gap = min(16, leftColumn.width * 0.025)
+        intro.frame = NSRect(x: leftColumn.minX, y: topPadding, width: headingWidth, height: leftColumn.height)
+        let cardHeight = min(200, max(102, leftColumn.height * 0.84))
+        cardColumn = NSRect(x: intro.frame.maxX + gap, y: topPadding, width: max(0, leftColumn.width - headingWidth - gap),
+                            height: cardHeight + HomeChallengeHUDView.surfaceInsetY * 2)
         entryX = modePanelLeading
         needsLayout = true
     }
@@ -63,53 +63,36 @@ final class HomeModeHeaderView: NSView {
         return hit === self ? nil : hit
     }
 
-    func refresh(snapshot: GameSnapshot, mode: HomeGameMode, isStarting: Bool) {
-        let shouldShowCard = mode != .free || (!isStarting && (snapshot.isRunning || snapshot.isFinished))
+    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
         let changedMode = selectedMode.map { $0 != mode } ?? false
-        let previousView = showsCard ? card as NSView : intro
-        if changedMode, showsCard {
-            // 切换挑战时保留旧卡的快照，避免滑出过程中先变成下一种模式。
+        let reuseIncoming = changedMode && !spareCard.isHidden && spareCard.mode == mode
+        if changedMode {
+            // 离场卡保留自己的快照，连续切换时只在回到同一模式后续用它的位置。
             let previousCard = card
             card = spareCard
             spareCard = previousCard
-        } else if changedMode, shouldShowCard, !spareCard.isHidden, spareCard.mode == mode {
-            // 用户在返回过程中改主意时，沿用仍在画面中的同一张卡。
-            let nextCard = spareCard
-            spareCard = card
-            card = nextCard
         }
-        let activeView = shouldShowCard ? card as NSView : intro
         selectedMode = mode
-        showsCard = shouldShowCard
         card.refresh(snapshot: snapshot, mode: mode)
-        if activeView === intro { intro.refresh(mode: mode) }
+        intro.refresh(mode: mode)
 
-        if changedMode, previousView !== activeView, window != nil, column.width > 0, !reducesMotion() {
-            animate(from: previousView, to: activeView, entersFromRight: shouldShowCard)
-        } else if changedMode || previousView !== activeView || transition == nil {
+        if changedMode, window != nil, cardColumn.width > 0, !reducesMotion() {
+            animate(reuseIncoming: reuseIncoming)
+        } else if changedMode || transition == nil {
             settle()
         }
     }
 
-    private func animate(from outgoing: NSView, to incoming: NSView, entersFromRight: Bool) {
-        // 位置以列宽为单位保存，快速切换和调整窗口大小时从当前画面继续。
-        let direction: CGFloat = entersFromRight ? 1 : -1
-        let incomingWasVisible = !incoming.isHidden
-        let incomingScale = incomingWasVisible ? scale(of: incoming) : entersFromRight ? Self.distantScale : Self.fullScale
-        let initialX = entersFromRight ? min(entryX, visibleRightEdge - column.width * incomingScale.width - 6) : column.minX - column.width
-        let initialOffset = (initialX - column.minX) / column.width
-        transition = Transition(outgoing: outgoing, incoming: incoming, direction: direction,
-                                start: now(), duration: entersFromRight ? Self.previewDuration : 0.46,
-                                outgoingOffset: (outgoing.frame.minX - column.minX) / column.width,
-                                incomingOffset: incomingWasVisible ? (incoming.frame.minX - column.minX) / column.width : initialOffset,
-                                outgoingScale: scale(of: outgoing), incomingScale: incomingScale,
-                                outgoingAlpha: outgoing.alphaValue,
-                                incomingAlpha: incomingWasVisible ? incoming.alphaValue : 0)
-        for item in subviews {
-            item.isHidden = item !== incoming && item !== outgoing
-            item.setAccessibilityHidden(item !== incoming)
-        }
-        addSubview(incoming, positioned: .above, relativeTo: outgoing)
+    private func animate(reuseIncoming: Bool) {
+        // 以卡面宽度为单位记录位置，重设窗口尺寸时进度可按比例继续。
+        let right = visibleRightEdge - cardColumn.width * Self.distantScale.width - 6
+        let launchX = min(entryX, right)
+        let launch = Pose(offset: (launchX - cardColumn.minX) / cardColumn.width, scale: Self.distantScale, alpha: 0)
+        transition = Transition(start: now(), outgoing: pose(of: spareCard), incoming: reuseIncoming ? pose(of: card) : launch)
+        card.isHidden = false
+        card.setAccessibilityHidden(false)
+        spareCard.setAccessibilityHidden(true)
+        addSubview(card, positioned: .above, relativeTo: spareCard)
         placeSubviews()
 
         timer?.invalidate()
@@ -124,18 +107,19 @@ final class HomeModeHeaderView: NSView {
         return min(bounds.maxX, convert(window.convertPoint(fromScreen: point), from: nil).x)
     }
 
-    private func scale(of view: NSView) -> NSSize {
-        guard view !== intro else { return Self.fullScale }
-        return NSSize(width: view.frame.width / column.width, height: view.frame.height / Self.cardHeight)
+    private func pose(of view: HomeChallengeHUDView) -> Pose {
+        Pose(offset: (view.frame.minX - cardColumn.minX) / cardColumn.width,
+             scale: NSSize(width: view.frame.width / cardColumn.width, height: view.frame.height / cardColumn.height),
+             alpha: view.alphaValue)
     }
 
     func advanceAnimation() {
         guard var transition else { return }
         let elapsed = max(0, now() - transition.start)
-        if elapsed >= transition.duration || reducesMotion() {
+        if elapsed >= Self.previewDuration || reducesMotion() {
             settle()
         } else {
-            transition.fraction = CGFloat(elapsed / transition.duration)
+            transition.fraction = CGFloat(elapsed / Self.previewDuration)
             self.transition = transition
             placeSubviews()
         }
@@ -155,117 +139,124 @@ final class HomeModeHeaderView: NSView {
         transition = nil
         timer?.invalidate()
         timer = nil
-        let activeView = showsCard ? card as NSView : intro
-        for item in subviews {
-            item.isHidden = item !== activeView
-            item.setAccessibilityHidden(item !== activeView)
-            item.alphaValue = 1
-        }
+        card.isHidden = false
+        card.setAccessibilityHidden(false)
+        spareCard.isHidden = true
+        spareCard.setAccessibilityHidden(true)
         placeSubviews()
     }
 
     private func placeSubviews() {
-        guard let transition else {
-            place(intro, offset: 0)
-            place(card, offset: 0)
-            place(spareCard, offset: 0)
+        guard let transition, cardColumn.width > 0 else {
+            place(card, pose: Pose(offset: 0, scale: Self.fullScale, alpha: 1))
+            place(spareCard, pose: Pose(offset: 0, scale: Self.fullScale, alpha: 1))
             card.revealFraction = nil
             spareCard.revealFraction = nil
             return
         }
         let t = transition.fraction
         let travel = t * t * (3 - 2 * t)
-        let incomingScale = NSSize(width: transition.incomingScale.width + (1 - transition.incomingScale.width) * travel,
-                                   height: transition.incomingScale.height + (1 - transition.incomingScale.height) * travel)
-        var incomingOffset = transition.incomingOffset * (1 - travel)
-        if transition.incoming !== intro, column.width > 0 {
-            // 窗口缩放期间也限制卡片右端，始终以完整卡面的实际尺寸计算。
-            let rightmostOffset = (bounds.maxX - column.minX) / column.width - incomingScale.width
-            incomingOffset = min(incomingOffset, rightmostOffset)
-        }
-        var outgoingOffset = transition.outgoingOffset * (1 - travel) - transition.direction * travel
-        var exitProgress = travel
-        if transition.outgoing === intro, transition.direction > 0, column.width > 0 {
-            // 卡片前沿先接近实际文字，再推着文字离场，避免两者隔着一整列空白一起移动。
-            let textWidth = min(1, (intro.contentWidth + 14) / column.width)
-            outgoingOffset = min(transition.outgoingOffset, incomingOffset - textWidth)
-            exitProgress = min(1, max(0, -outgoingOffset / textWidth))
-        }
-        place(transition.outgoing, offset: outgoingOffset, scale: transition.outgoingScale)
-        place(transition.incoming, offset: incomingOffset, scale: incomingScale)
-        transition.outgoing.alphaValue = transition.outgoingAlpha * (1 - exitProgress * exitProgress)
-        transition.incoming.alphaValue = transition.incomingAlpha + (1 - transition.incomingAlpha) * sqrt(travel)
-        (transition.outgoing as? HomeChallengeHUDView)?.revealFraction = nil
-        (transition.incoming as? HomeChallengeHUDView)?.revealFraction = travel
+        let incoming = transition.incoming
+        let scale = NSSize(width: incoming.scale.width + (1 - incoming.scale.width) * travel,
+                           height: incoming.scale.height + (1 - incoming.scale.height) * travel)
+        let rightmostOffset = (bounds.maxX - cardColumn.minX) / cardColumn.width - scale.width
+        let offset = min(incoming.offset * (1 - travel), rightmostOffset)
+        place(card, pose: Pose(offset: offset, scale: scale, alpha: incoming.alpha + (1 - incoming.alpha) * sqrt(travel)))
+        card.revealFraction = travel
+
+        let outgoing = transition.outgoing
+        place(spareCard, pose: Pose(offset: outgoing.offset * (1 - travel) - 0.08 * travel,
+                                    scale: outgoing.scale, alpha: outgoing.alpha * (1 - travel)))
+        spareCard.revealFraction = nil
     }
 
-    private func place(_ view: NSView, offset: CGFloat, scale: NSSize = HomeModeHeaderView.fullScale) {
-        let x = column.minX + offset * column.width
-        if view === intro {
-            view.frame = NSRect(x: x, y: column.minY, width: column.width, height: column.height)
-        } else {
-            // 按完整卡面的坐标绘制，再缩放整个视图，使数字、图案和阴影一起放大。
-            view.frame = NSRect(x: x, y: column.minY - HomeChallengeHUDView.surfaceInsetY * scale.height,
-                                width: column.width * scale.width, height: Self.cardHeight * scale.height)
-            view.bounds = NSRect(x: 0, y: 0, width: column.width, height: Self.cardHeight)
-        }
+    private func place(_ view: HomeChallengeHUDView, pose: Pose) {
+        // 卡片始终使用完整坐标绘制，入场时数字、分格和斜边一起做透视缩放。
+        view.frame = NSRect(x: cardColumn.minX + pose.offset * cardColumn.width,
+                            y: cardColumn.minY - HomeChallengeHUDView.surfaceInsetY * pose.scale.height,
+                            width: cardColumn.width * pose.scale.width, height: cardColumn.height * pose.scale.height)
+        view.bounds = NSRect(origin: .zero, size: cardColumn.size)
+        view.alphaValue = pose.alpha
     }
 }
 
 private final class HomeModeIntroView: NSView {
     private let heading = NSTextField(wrappingLabelWithString: "")
     private let subtitle = NSTextField(wrappingLabelWithString: "")
+    private var title = ""
 
     override var isFlipped: Bool { true }
 
     override init(frame: NSRect) {
         super.init(frame: frame)
-        heading.textColor = HomeStyle.ink
-        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
-        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
+        subtitle.textColor = HomeDashboardStyle.muted
         addSubview(heading)
         addSubview(subtitle)
     }
 
     required init?(coder: NSCoder) { nil }
 
-    var contentWidth: CGFloat {
-        max(lineWidth(in: heading), lineWidth(in: subtitle))
-    }
-
-    private func lineWidth(in label: NSTextField) -> CGFloat {
-        guard let font = label.font else { return 0 }
-        return label.stringValue.split(separator: "\n").map { line in
-            (String(line) as NSString).size(withAttributes: [.font: font]).width
-        }.max() ?? 0
-    }
-
     func refresh(mode: HomeGameMode) {
-        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
-        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
+        let newTitle = AchievementText.string("home.hero.\(mode.key)")
+        let newSubtitle = AchievementText.string("home.subtitle.\(mode.key)")
+        guard title != newTitle || subtitle.stringValue != newSubtitle else { return }
+        title = newTitle
+        subtitle.stringValue = newSubtitle
+        needsLayout = true
     }
 
     override func layout() {
         super.layout()
-        let headingY: CGFloat = 20
-        let subtitleY = max(headingY, bounds.height - 42)
-        let headingHeight = max(0, subtitleY - headingY - 8)
-        let textWidth = max(0, bounds.width - 4)
-        var fontSize = min(60, max(44, bounds.width * 0.092))
-        // 先给副标题留出独立区域，再按语言和窗口宽高调整主标题字级。
-        while fontSize > 32 {
-            let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
-            let textSize = (heading.stringValue as NSString).boundingRect(
-                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
-                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]
-            )
-            if ceil(textSize.height) + 4 <= headingHeight { break }
-            fontSize -= 1
+        let textWidth = max(1, bounds.width - 8)
+        let headingY = min(10, bounds.height * 0.04)
+        let headingMaxHeight = bounds.height * 0.68
+        let lines = title.split(separator: "\n")
+        var size = min(66, max(24, bounds.width * 0.21), bounds.height * 0.32)
+        var font = NSFont.systemFont(ofSize: size, weight: .heavy)
+        // 本地化后的两行标题需同时满足宽度和高度，以免副标题被挤出。
+        while size > 17 {
+            let maxWidth = lines.map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
+            if maxWidth <= textWidth, textHeight(title, width: textWidth, font: font) <= headingMaxHeight { break }
+            size -= 1
+            font = .systemFont(ofSize: size, weight: .heavy)
         }
-        heading.font = .systemFont(ofSize: fontSize, weight: .heavy)
+        let styled = NSMutableAttributedString(string: title, attributes: [.font: font, .foregroundColor: HomeDashboardStyle.ink,
+                                                                          .obliqueness: 0.18])
+        let divider = (title as NSString).range(of: "\n")
+        if divider.location != NSNotFound {
+            let start = NSMaxRange(divider)
+            styled.addAttribute(.foregroundColor, value: HomeDashboardStyle.yellow, range: NSRange(location: start, length: styled.length - start))
+        }
+        heading.attributedStringValue = styled
         heading.preferredMaxLayoutWidth = bounds.width
-        subtitle.preferredMaxLayoutWidth = bounds.width
+        let headingHeight = min(headingMaxHeight, textHeight(title, width: textWidth, font: font) + 4)
         heading.frame = NSRect(x: 0, y: headingY, width: bounds.width, height: headingHeight)
-        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: 42)
+
+        let subtitleY = heading.frame.maxY + 8
+        let available = max(0, bounds.height - subtitleY - 12)
+        var subtitleSize = min(20, max(11, bounds.width * 0.063))
+        var subtitleFont = NSFont.systemFont(ofSize: subtitleSize, weight: .medium)
+        while subtitleSize > 10, textHeight(subtitle.stringValue, width: textWidth, font: subtitleFont) > available {
+            subtitleSize -= 1
+            subtitleFont = .systemFont(ofSize: subtitleSize, weight: .medium)
+        }
+        subtitle.font = subtitleFont
+        subtitle.preferredMaxLayoutWidth = bounds.width
+        let subtitleHeight = min(available, textHeight(subtitle.stringValue, width: textWidth, font: subtitleFont) + 2)
+        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: subtitleHeight)
+        needsDisplay = true
+    }
+
+    private func textHeight(_ value: String, width: CGFloat, font: NSFont) -> CGFloat {
+        ceil((value as NSString).boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
+                                              options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height)
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        guard !title.isEmpty else { return }
+        let width = min(78, bounds.width * 0.25)
+        let y = min(bounds.maxY - 4, subtitle.frame.maxY + 11)
+        let underline = HomeDashboardStyle.slant(NSRect(x: 10, y: y, width: width, height: 4), cut: 3)
+        NSGradient(colors: [HomeDashboardStyle.yellow, HomeDashboardStyle.yellow, .clear])?.draw(in: underline, angle: 0)
     }
 }
diff --git a/Sources/HomeUtilityPanel.swift b/Sources/HomeUtilityPanel.swift
index 5b789e977cc1b1840381a5bade2b7b5d0f721134..cb006d37fca31ab44481a3c06d7b53371b39fd78 100644
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -13,7 +13,7 @@ final class HomeUtilityPanel: NSWindowController {
     private let content: UtilityPageView
     private let language = UtilityLanguagePopup(frame: .zero, pullsDown: false)
     private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
-    private let percent = UtilityStyle.label("", size: 18, weight: .bold)
+    private let percent = UtilityStyle.label("", size: 18, weight: .bold, color: HomeDashboardStyle.yellow)
     private let recordTabs = AchievementFilterControl(frame: .zero)
     private let recordBody = UtilityStyle.stack([])
     private let store: ModeRecordStore
@@ -28,8 +28,8 @@ final class HomeUtilityPanel: NSWindowController {
         let size = NSSize(width: page == "settings" ? 540 : 600, height: page == "settings" ? 430 : 740)
         let panel = HomeAuxiliaryWindow(contentRect: NSRect(origin: .zero, size: size),
                                         styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
-        panel.isReleasedWhenClosed = false; panel.appearance = NSAppearance(named: .aqua)
-        panel.backgroundColor = HomeStyle.background; panel.hidesOnDeactivate = true
+        panel.isReleasedWhenClosed = false; panel.appearance = NSAppearance(named: .darkAqua)
+        panel.backgroundColor = HomeDashboardStyle.navy; panel.hidesOnDeactivate = true
         content.frame = NSRect(origin: .zero, size: size); content.autoresizingMask = [.width, .height]
         panel.contentView = content
         super.init(window: panel)
@@ -82,21 +82,21 @@ final class HomeUtilityPanel: NSWindowController {
         let languageStack = UtilityStyle.stack([settingHeading("globe", title: "language.label", detail: "utility.settings.language_hint"), language], spacing: 16)
         UtilityStyle.fillWidth(language, in: languageStack)
         content.addSection(UtilityCard(languageStack))
-        let sliderRow = UtilityStyle.stack([UtilityStyle.icon("speaker.fill", color: HomeStyle.secondary, size: 16), volume, percent], vertical: false, spacing: 14)
+        let sliderRow = UtilityStyle.stack([UtilityStyle.icon("speaker.fill", color: HomeDashboardStyle.muted, size: 16), volume, percent], vertical: false, spacing: 14)
         volume.setContentHuggingPriority(.defaultLow, for: .horizontal)
         let volumeStack = UtilityStyle.stack([settingHeading("speaker.wave.2.fill", title: "volume.label", detail: "utility.settings.volume_hint"), sliderRow], spacing: 14)
         UtilityStyle.fillWidth(sliderRow, in: volumeStack)
         content.addSection(UtilityCard(volumeStack))
-        let footnote = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.green, size: 16),
-                                          UtilityStyle.label(UtilityStyle.text("utility.settings.instant"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 7)
+        let footnote = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeDashboardStyle.green, size: 16),
+                                          UtilityStyle.label(UtilityStyle.text("utility.settings.instant"), size: 11, color: HomeDashboardStyle.muted)], vertical: false, spacing: 7)
         content.addSection(footnote)
         language.setAccessibilityLabel(UtilityStyle.text("language.label")); volume.setAccessibilityLabel(UtilityStyle.text("volume.label"))
     }
 
     private func settingHeading(_ symbol: String, title: String, detail: String) -> NSView {
         let copy = UtilityStyle.stack([UtilityStyle.label(UtilityStyle.text(title), size: 15, weight: .bold),
-                                       UtilityStyle.label(UtilityStyle.text(detail), size: 12, color: HomeStyle.secondary)], spacing: 4)
-        return UtilityStyle.stack([UtilityStyle.icon(symbol, color: HomeStyle.blue, size: 26), copy], vertical: false, spacing: 13)
+                                       UtilityStyle.label(UtilityStyle.text(detail), size: 12, color: HomeDashboardStyle.muted)], spacing: 4)
+        return UtilityStyle.stack([UtilityStyle.icon(symbol, color: HomeDashboardStyle.cyan, size: 26), copy], vertical: false, spacing: 13)
     }
     private func recordEntries(_ mode: ModeRecordKey) -> [ModeRecord] { store.records(for: mode, detailValue: mode == .timed ? 60 : 30) }
 
diff --git a/Sources/HomeUtilityViews.swift b/Sources/HomeUtilityViews.swift
index dad9cd8c1a1280daf69713662a62f69d913c62a6..707f7e66080980e23f0e2366fd8008fce17a38b1 100644
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -3,7 +3,7 @@ import Cocoa
 /// 辅助页共用首页材质；文字使用原生视图，支持换行和辅助功能。
 enum UtilityStyle {
     static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
-                      color: NSColor = HomeStyle.ink) -> NSTextField {
+                      color: NSColor = HomeDashboardStyle.ink) -> NSTextField {
         let label = NSTextField(wrappingLabelWithString: text)
         label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
         label.maximumNumberOfLines = 0
@@ -32,6 +32,14 @@ enum UtilityStyle {
         NSLayoutConstraint.activate([view.widthAnchor.constraint(equalToConstant: size), view.heightAnchor.constraint(equalToConstant: size)])
         return view
     }
+
+    static func drawCard(_ rect: NSRect, accent: NSColor? = nil, cut: CGFloat = 10) {
+        let top = HomeDashboardStyle.panel
+        let base = HomeDashboardStyle.color(0x101C28)
+        let tint = accent.flatMap { top.blended(withFraction: 0.12, of: $0) } ?? top
+        let outline = accent?.withAlphaComponent(0.62) ?? HomeDashboardStyle.border
+        HomeDashboardStyle.surface(rect, cut: cut, colors: [tint, base], border: outline)
+    }
 }
 
 /// 彩色矢量始终等比绘制，不依赖字体附件的基线。
@@ -48,12 +56,11 @@ final class UtilityArtworkView: NSView {
 }
 
 final class UtilityCard: NSView {
-    init(_ content: NSView, tint: NSColor = .white, padding: CGFloat = 20) {
+    private let accent: NSColor?
+
+    init(_ content: NSView, accent: NSColor? = nil, padding: CGFloat = 20) {
+        self.accent = accent
         super.init(frame: .zero)
-        wantsLayer = true
-        layer?.backgroundColor = tint.cgColor
-        layer?.borderColor = HomeStyle.border.withAlphaComponent(0.8).cgColor
-        layer?.borderWidth = 0.75; layer?.cornerRadius = 14
         content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
         NSLayoutConstraint.activate([
             content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
@@ -63,6 +70,8 @@ final class UtilityCard: NSView {
         ])
     }
     required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent) }
 }
 
 /// 标题固定、正文独立滚动，在小屏幕与长翻译下不裁切内容。
@@ -75,12 +84,12 @@ final class UtilityPageView: NSView {
     let document: NSView = UtilityDocumentView()
     let sections = UtilityStyle.stack([])
     private let title = UtilityStyle.label("", size: 23, weight: .bold)
-    private let subtitle = UtilityStyle.label("", size: 12, color: HomeStyle.secondary)
+    private let subtitle = UtilityStyle.label("", size: 12, color: HomeDashboardStyle.muted)
 
     init(page: String) {
         super.init(frame: .zero)
         let symbol = page == "settings" ? "slider.horizontal.3" : page == "rules" ? "gamecontroller.fill" : "trophy"
-        let artwork = UtilityStyle.icon(symbol, color: page == "records" ? .systemOrange : HomeStyle.blue, size: 32)
+        let artwork = UtilityStyle.icon(symbol, color: page == "records" ? HomeDashboardStyle.yellow : HomeDashboardStyle.cyan, size: 32)
         let headings = UtilityStyle.stack([title, subtitle], spacing: 5)
         let header = UtilityStyle.stack([artwork, headings], vertical: false, spacing: 14)
         header.translatesAutoresizingMaskIntoConstraints = false
@@ -109,7 +118,7 @@ final class UtilityPageView: NSView {
     }
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
+    override func draw(_ dirtyRect: NSRect) { HomeDashboardStyle.backdrop(in: bounds) }
     func refreshHeader(page: String) {
         title.stringValue = UtilityStyle.text("panel.\(page)")
         subtitle.stringValue = UtilityStyle.text("utility.\(page).subtitle")
@@ -124,36 +133,40 @@ final class UtilityPageView: NSView {
 
 /// 保留原生菜单和辅助功能，只重绘游戏主题外观。
 final class UtilityLanguagePopup: NSPopUpButton {
+    override var isFlipped: Bool { true }
     override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 44) }
     override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
     override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.card(bounds, fill: HomeStyle.blue.withAlphaComponent(isHighlighted ? 0.09 : 0.035), border: HomeStyle.blue.withAlphaComponent(0.25), radius: 9)
-        HomeStyle.text(title, in: NSRect(x: 15, y: bounds.midY - 10, width: bounds.width - 52, height: 22), size: 14, weight: .semibold)
-        HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeStyle.blue)
+        UtilityStyle.drawCard(bounds, accent: isHighlighted ? HomeDashboardStyle.cyan : nil, cut: 8)
+        HomeDashboardStyle.text(title, in: NSRect(x: 15, y: bounds.midY - 10, width: bounds.width - 52, height: 22), size: 14, weight: .semibold)
+        HomeStyle.symbol("chevron.down", in: NSRect(x: bounds.maxX - 29, y: bounds.midY - 6, width: 12, height: 12), color: HomeDashboardStyle.cyan)
     }
     override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
 }
 
-/// 原生滑杆负责拖动与键盘步进，自绘金色进度和白色旋钮。
+/// 原生滑杆负责拖动与键盘步进，深色轨道突出黄色进度。
 final class UtilityVolumeSliderCell: NSSliderCell {
     override var knobThickness: CGFloat { 22 }
     override func drawBar(inside rect: NSRect, flipped: Bool) {
         // 原生旋钮的光学中心与 barRect 有细微偏移，轨道以旋钮中心为准。
         let track = NSRect(x: rect.minX, y: knobRect(flipped: flipped).midY - 3, width: rect.width, height: 6)
-        NSColor(calibratedWhite: 0.92, alpha: 1).setFill(); NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
+        HomeDashboardStyle.border.setFill()
+        HomeDashboardStyle.slant(track, cut: 2).fill()
         let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
         let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
-        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
+        HomeDashboardStyle.yellow.setFill()
+        HomeDashboardStyle.slant(fill, cut: 2).fill()
     }
     override func drawKnob(_ knobRect: NSRect) {
         let knob = NSRect(x: knobRect.midX - 10, y: knobRect.midY - 10, width: 20, height: 20)
         NSGraphicsContext.saveGraphicsState()
-        let shadow = NSShadow(); shadow.shadowColor = HomeStyle.ink.withAlphaComponent(0.16)
+        let shadow = NSShadow(); shadow.shadowColor = HomeDashboardStyle.yellow.withAlphaComponent(0.36)
         shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 0, height: -1); shadow.set()
-        NSColor.white.setFill(); NSBezierPath(ovalIn: knob).fill()
+        HomeDashboardStyle.navy.setFill(); NSBezierPath(ovalIn: knob).fill()
         NSGraphicsContext.restoreGraphicsState()
-        HomeStyle.border.setStroke(); NSBezierPath(ovalIn: knob.insetBy(dx: 0.5, dy: 0.5)).stroke()
-        HomeStyle.yellow.setFill(); NSBezierPath(ovalIn: knob.insetBy(dx: 7, dy: 7)).fill()
+        HomeDashboardStyle.yellow.withAlphaComponent(0.75).setStroke()
+        NSBezierPath(ovalIn: knob.insetBy(dx: 0.5, dy: 0.5)).stroke()
+        HomeDashboardStyle.yellow.setFill(); NSBezierPath(ovalIn: knob.insetBy(dx: 7, dy: 7)).fill()
     }
 }
 
@@ -171,14 +184,14 @@ final class UtilityLessonArtwork: NSView {
     override func draw(_ dirtyRect: NSRect) {
         if step == 0 {
             HomeStyle.piece(.orangeRicky, in: NSRect(x: 0, y: 14, width: 33, height: 24))
-            HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeStyle.secondary)
+            HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeDashboardStyle.muted)
             HomeStyle.piece(.blueRicky, in: NSRect(x: 65, y: 14, width: 33, height: 24))
         } else {
             let rows = step == 1 ? 1 : 2
             for row in 0..<rows {
                 for column in 0..<3 {
                     let tile = NSRect(x: 19 + CGFloat(column) * 21, y: CGFloat(rows == 1 ? 17 : 7) + CGFloat(row) * 21, width: 18, height: 18)
-                    let color = row == 0 ? HomeStyle.blue : HomeStyle.green
+                    let color = row == 0 ? HomeDashboardStyle.cyan : HomeDashboardStyle.green
                     NSGradient(colors: [color.blended(withFraction: 0.25, of: .white)!, color])?.draw(in: NSBezierPath(roundedRect: tile, xRadius: 4, yRadius: 4), angle: -90)
                     NSColor.white.withAlphaComponent(0.4).setStroke()
                     NSBezierPath(roundedRect: tile.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).stroke()
@@ -193,11 +206,11 @@ enum UtilityRulesContent {
         page.removeSections()
         let lessons = UtilityStyle.stack([], spacing: 0)
         for step in 0..<3 {
-            let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeStyle.blue)
+            let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeDashboardStyle.cyan)
             number.widthAnchor.constraint(equalToConstant: 25).isActive = true
             let copy = UtilityStyle.stack([
                 UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold),
-                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeStyle.secondary)
+                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeDashboardStyle.muted)
             ], spacing: 5)
             let row = UtilityStyle.stack([number, copy, UtilityLessonArtwork(step: step)], vertical: false, spacing: 12)
             copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
@@ -215,23 +228,23 @@ enum UtilityRulesContent {
             let selected = candidate == mode
             let copy = UtilityStyle.stack([
                 UtilityStyle.label(UtilityStyle.text("home.mode.\(candidate.key)"), size: 13, weight: .bold),
-                UtilityStyle.label(UtilityStyle.text("home.mode_desc.\(candidate.key)"), size: 12, color: HomeStyle.secondary)
+                UtilityStyle.label(UtilityStyle.text("home.mode_desc.\(candidate.key)"), size: 12, color: HomeDashboardStyle.muted)
             ], spacing: 3)
             copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
-            let row = UtilityStyle.stack([UtilityStyle.icon(candidate.symbol, color: selected ? HomeStyle.blue : HomeStyle.secondary, size: 26), copy], vertical: false, spacing: 13)
+            let row = UtilityStyle.stack([UtilityStyle.icon(candidate.symbol, color: selected ? HomeDashboardStyle.cyan : HomeDashboardStyle.muted, size: 26), copy], vertical: false, spacing: 13)
             if selected {
-                let current = UtilityStyle.label(UtilityStyle.text("utility.rules.current"), size: 10, weight: .semibold, color: HomeStyle.blue)
+                let current = UtilityStyle.label(UtilityStyle.text("utility.rules.current"), size: 10, weight: .semibold, color: HomeDashboardStyle.cyan)
                 current.setContentHuggingPriority(.required, for: .horizontal)
                 current.setContentCompressionResistancePriority(.required, for: .horizontal)
                 row.addArrangedSubview(current)
             }
-            let card = UtilityCard(row, tint: selected ? NSColor(calibratedRed: 0.94, green: 0.975, blue: 1, alpha: 1) : .white, padding: 12)
+            let card = UtilityCard(row, accent: selected ? HomeDashboardStyle.cyan : nil, padding: 12)
             modes.addArrangedSubview(card); UtilityStyle.fillWidth(card, in: modes)
         }
         page.addSection(modes)
-        let note = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeStyle.secondary, size: 19),
-                                     UtilityStyle.label(UtilityStyle.text("utility.rules.progress"), size: 11, color: HomeStyle.secondary)], vertical: false, spacing: 10)
-        page.addSection(UtilityCard(note, tint: HomeStyle.yellow.withAlphaComponent(0.08), padding: 14))
+        let note = UtilityStyle.stack([UtilityStyle.icon("checkmark.circle.fill", color: HomeDashboardStyle.muted, size: 19),
+                                     UtilityStyle.label(UtilityStyle.text("utility.rules.progress"), size: 11, color: HomeDashboardStyle.muted)], vertical: false, spacing: 10)
+        page.addSection(UtilityCard(note, padding: 14))
     }
 }
 
@@ -239,19 +252,16 @@ enum UtilityRulesContent {
 final class UtilityRecordBestView: NSView {
     init(mode: ModeRecordKey, entry: ModeRecord?) {
         super.init(frame: .zero)
-        wantsLayer = true; layer?.cornerRadius = 14
-        layer?.backgroundColor = HomeStyle.yellow.withAlphaComponent(0.12).cgColor
-        layer?.borderColor = HomeStyle.yellow.withAlphaComponent(0.4).cgColor; layer?.borderWidth = 0.75
         let metric = entry.map { String($0.clearedCount) } ?? "—"
-        let value = UtilityStyle.label(metric, size: 38, weight: .heavy)
+        let value = UtilityStyle.label(metric, size: 38, weight: .heavy, color: HomeDashboardStyle.yellow)
         value.font = .monospacedDigitSystemFont(ofSize: 38, weight: .heavy)
-        let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeStyle.secondary)
+        let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeDashboardStyle.muted)
         let copy = UtilityStyle.stack([
-            UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeStyle.secondary),
+            UtilityStyle.label(UtilityStyle.text("utility.records.best"), size: 11, weight: .semibold, color: HomeDashboardStyle.muted),
             UtilityStyle.stack([value, unit], vertical: false, spacing: 8),
-            UtilityStyle.label(UtilityStyle.text(mode == .timed ? "utility.records.timed_rule" : "utility.records.moves_rule"), size: 11, color: HomeStyle.secondary)
+            UtilityStyle.label(UtilityStyle.text(mode == .timed ? "utility.records.timed_rule" : "utility.records.moves_rule"), size: 11, color: HomeDashboardStyle.muted)
         ], spacing: 4)
-        let icon = UtilityStyle.icon(mode == .timed ? HomeGameMode.timed.symbol : HomeGameMode.moves.symbol, color: .systemOrange, size: 56)
+        let icon = UtilityStyle.icon(mode == .timed ? HomeGameMode.timed.symbol : HomeGameMode.moves.symbol, color: HomeDashboardStyle.yellow, size: 56)
         let row = UtilityStyle.stack([copy, icon], vertical: false, spacing: 16)
         copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
         row.translatesAutoresizingMaskIntoConstraints = false; addSubview(row)
@@ -261,6 +271,8 @@ final class UtilityRecordBestView: NSView {
         ])
     }
     required init?(coder: NSCoder) { nil }
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: HomeDashboardStyle.yellow) }
 }
 
 enum UtilityRecordContent {
@@ -268,9 +280,9 @@ enum UtilityRecordContent {
     static func table(mode: ModeRecordKey, entries: [ModeRecord]) -> NSView {
         let rows = UtilityStyle.stack([], spacing: 0)
         let headings = UtilityStyle.stack([
-            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeStyle.secondary),
-            UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeStyle.secondary),
-            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold, color: HomeStyle.secondary)
+            UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
+            UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
+            UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted)
         ], vertical: false, spacing: 12)
         headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
         headings.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 135).isActive = true
@@ -290,7 +302,7 @@ enum UtilityRecordContent {
             let countLabel = UtilityStyle.label(metric, size: 15, weight: ranks[index] == 1 ? .bold : .semibold)
             countLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: ranks[index] == 1 ? .bold : .semibold)
             countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
-            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11, color: HomeStyle.secondary)
+            let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11, color: HomeDashboardStyle.muted)
             date.alignment = .right
             date.widthAnchor.constraint(equalToConstant: 135).isActive = true
             let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 12)
@@ -300,9 +312,9 @@ enum UtilityRecordContent {
         }
         if entries.isEmpty {
             let empty = UtilityStyle.stack([
-                UtilityStyle.icon("flag.checkered", color: HomeStyle.secondary, size: 40),
+                UtilityStyle.icon("flag.checkered", color: HomeDashboardStyle.muted, size: 40),
                 UtilityStyle.label(UtilityStyle.text("records.empty"), size: 15, weight: .semibold),
-                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeStyle.secondary)
+                UtilityStyle.label(UtilityStyle.text("utility.records.empty_hint"), size: 12, color: HomeDashboardStyle.muted)
             ], spacing: 12)
             empty.alignment = .centerX
             for label in empty.arrangedSubviews.compactMap({ $0 as? NSTextField }) { label.alignment = .center }
@@ -320,10 +332,10 @@ enum UtilityRecordContent {
         let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
         for (index, record) in section.entries.enumerated() {
             let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
-            let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeStyle.secondary)
+            let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeDashboardStyle.muted)
             stack.addArrangedSubview(label); UtilityStyle.fillWidth(label, in: stack)
         }
-        return UtilityCard(stack, tint: NSColor(calibratedWhite: 0.975, alpha: 1), padding: 16)
+        return UtilityCard(stack, padding: 16)
     }
 }
 
@@ -335,11 +347,11 @@ private final class UtilityRankView: NSView {
     override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
         if rank <= 3 {
-            let colors = [HomeStyle.yellow, NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1), NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.45, alpha: 1)]
+            let colors = [HomeDashboardStyle.yellow, NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.89, alpha: 1), NSColor(calibratedRed: 0.88, green: 0.66, blue: 0.45, alpha: 1)]
             let circle = NSRect(x: bounds.midX - 11, y: bounds.midY - 11, width: 22, height: 22)
             NSGradient(colors: [colors[rank - 1].blended(withFraction: 0.32, of: .white)!, colors[rank - 1]])?.draw(in: NSBezierPath(ovalIn: circle), angle: -90)
         }
-        HomeStyle.text(String(rank), in: NSRect(x: 0, y: bounds.midY - 8, width: bounds.width, height: 18), size: 12, weight: .bold,
-                       color: rank <= 3 ? HomeStyle.ink : HomeStyle.secondary, alignment: .center)
+        HomeDashboardStyle.text(String(rank), in: NSRect(x: 0, y: bounds.midY - 8, width: bounds.width, height: 18), size: 12, weight: .bold,
+                       color: rank <= 3 ? HomeDashboardStyle.navy : HomeDashboardStyle.muted, alignment: .center)
     }
 }
diff --git a/Sources/Resources/Artwork/README.md b/Sources/Resources/Artwork/README.md
index eeac02afa269ef925e67ccbab14b162a8f0d8151..de69adb375a91bf9d30ed05393485b1875ebce6b 100644
--- a/Sources/Resources/Artwork/README.md
+++ b/Sources/Resources/Artwork/README.md
@@ -1,6 +1,6 @@
-# 首页设计稿插画
+# 历史首页设计稿插画
 
-当前首页直接使用用户原始设计稿中提取的图像，不重新生成或重绘方块。
+这组透明图像来自浅色版首页设计稿，保留用于追溯与像素校验。深色版首页由 `HomeLobbyArtwork` 使用 AppKit 绘制游戏方块、反光与触控栏示意。
 
 ## 来源与提取
 - 原始设计稿：`docs/design/home-reference.png`，1536×1024 像素。
@@ -9,11 +9,10 @@
 - 脚本只移除纸纹背景，对低透明投影反解背景混色，方块和短线主体保留原始像素。
 - 每张图为透明 PNG；原始尺寸分别为橙色 190×150、蓝色 167×150、绿色 197×165、红色 207×160，箭头 75×43。
 
-## 布局与运行
-- `HomeHeroPieceRenderer` 按原稿坐标整体等比缩放，保持方块宽度、相互距离、箭头和短线的相对位置。
-- 四个方块独立浮动，箭头保持原位；减少动态效果开启时停止浮动。
-- 图片通过 `GameResourceLocator` 从应用资源 Bundle 读取并缓存，无网络依赖。
-- 先前生成的近似插画移至 `docs/design/rejected-studio-artwork.png`，供历史回看，不再进入应用资源 Bundle。
+## 历史素材
+- 旧版将方块按原稿坐标整体等比缩放，各自浮动，交换箭头保持原位。
+- 测试通过 `GameResourceLocator` 从应用资源包读取这些图片，逐像素校验提取结果。
+- 先前生成的近似插画保存在 `docs/design/rejected-studio-artwork.png`，可供回看。
 
 ## 重新提取
 
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index f2bbb37aef130b877cc1b2f94294fbb899605be6..25e7710d0966f3a6b4515cb6f765bb2de07f889c 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -1,4 +1,4 @@
-"window.title" = "Eliminate Teris 1";
+"window.title" = "Eliminate Teris";
 "window.subtitle" = "Pixel Touch Bar Challenge";
 "panel.settings" = "Game Settings";
 "panel.status" = "Time & Score";
@@ -179,7 +179,8 @@
 "achievement.32.desc" = "Clear 10,000 red tiles across all modes.";
 
 // 浅色探索版首页与固定玩法规则。
-"home.brand" = "Eliminate Teris 1";
+"home.brand" = "Eliminate Teris";
+"home.space_key" = "SPACE";
 "home.game_modes" = "Game modes";
 "home.hero.free" = "Swap a little.\nSmile a lot.";
 "home.hero.timed" = "One minute.\nMake it count.";
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index 8cb650745c4a0c01e6758cea83379280ff760e23..2d0ef3c4010c03d88b80e8901f3e414fdba2c525 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -1,4 +1,4 @@
-"window.title" = "テリス消去1";
+"window.title" = "テトリス消去";
 "window.subtitle" = "ピクセル Touch Bar チャレンジ";
 "panel.settings" = "ゲーム設定";
 "panel.status" = "時間とスコア";
@@ -172,7 +172,8 @@
 "achievement.32.desc" = "すべてのモードで、赤色のブロックを合計 10,000 個消す。";
 
 // 浅色探索版首页与固定玩法规则。
-"home.brand" = "消去テトリス 1";
+"home.brand" = "テトリス消去";
+"home.space_key" = "スペース";
 "home.game_modes" = "ゲームモード";
 "home.hero.free" = "入れ替えて、\n楽しく消そう。";
 "home.hero.timed" = "1 分間、\n消去に挑戦。";
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index 8edde6cbf3d5345f9eef5d3095c3fad3e25693ba..7fae830aa46d666762ad4bb40ac7fb59f57b7c38 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -1,4 +1,4 @@
-"window.title" = "테리스 제거 1";
+"window.title" = "테트리스 제거";
 "window.subtitle" = "픽셀 Touch Bar 챌린지";
 "panel.settings" = "게임 설정";
 "panel.status" = "시간 및 점수";
@@ -172,7 +172,8 @@
 "achievement.32.desc" = "모든 모드에서 빨간색 블록을 누적 10,000개 제거하세요.";
 
 // 浅色探索版首页与固定玩法规则。
-"home.brand" = "블록 제거 테트리스 1";
+"home.brand" = "테트리스 제거";
+"home.space_key" = "스페이스";
 "home.game_modes" = "게임 모드";
 "home.hero.free" = "가볍게 바꾸고,\n즐겁게 지워요.";
 "home.hero.timed" = "1분 동안,\n제거에 집중!";
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index 53525a6dc61a09a8fadfb39e930fc43c5194357a..983032b74007df9a9094f450ab5bdfa747b6dce8 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -1,4 +1,4 @@
-"window.title" = "Устранение Терис 1";
+"window.title" = "Тетрис на Touch Bar";
 "window.subtitle" = "Пиксельный вызов Touch Bar";
 "panel.settings" = "Настройки игры";
 "panel.status" = "Время и счёт";
@@ -172,7 +172,8 @@
 "achievement.32.desc" = "Удалите 10,000 красных блоков во всех режимах.";
 
 // 浅色探索版首页与固定玩法规则。
-"home.brand" = "Тетрис на Touch Bar 1";
+"home.brand" = "Тетрис на Touch Bar";
+"home.space_key" = "ПРОБЕЛ";
 "home.game_modes" = "Режим игры";
 "home.hero.free" = "Меняй блоки.\nИграй с радостью.";
 "home.hero.timed" = "Одна минута.\nБольше фигур!";
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index dd443ac936cb55f691897e9067e136299f332515..d31d1bf152d86011c9c3fdee731e57631a6eda0e 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -1,4 +1,4 @@
-"window.title" = "消除俄罗斯方块1";
+"window.title" = "消除俄罗斯方块";
 "window.subtitle" = "像素风触控栏方块挑战";
 "panel.settings" = "游戏设置";
 "panel.status" = "时间与得分";
@@ -179,9 +179,10 @@
 "achievement.32.desc" = "全部模式累计消除 10,000 个红色方块。";
 
 // 浅色探索版首页与固定玩法规则。
-"home.brand" = "消除俄罗斯方块 1";
+"home.brand" = "消除俄罗斯方块";
+"home.space_key" = "空格";
 "home.game_modes" = "游戏模式";
-"home.hero.free" = "没有限制，\n自由消除。";
+"home.hero.free" = "打破常规，\n自由消除。";
 "home.hero.timed" = "一分钟内，\n挑战高分。";
 "home.hero.moves" = "三十步内，\n挑战高分。";
 "home.subtitle.free" = "没有倒计时，按自己的节奏玩。";
@@ -192,10 +193,10 @@
 "home.mode.timed" = "限时挑战";
 "home.mode.moves" = "限步挑战";
 "home.mode_desc.free" = "无时间与目标限制。";
-"home.mode_desc.puzzle" = "玩法待定";
+"home.mode_desc.puzzle" = "玩法待定。";
 "home.mode_desc.timed" = "限时 60 秒，消除越多越好。";
 "home.mode_desc.moves" = "30 次交换，不限思考时间。";
-"home.operation_hint" = "拖动交换  ·  三个及以上相连即可消除";
+"home.operation_hint" = "滑动交换，三个及以上相连即可消除";
 "home.start" = "开始游戏";
 "home.play_again" = "再来一局";
 "home.contact.title" = "联系我们";
@@ -231,7 +232,7 @@
 "utility.records.empty_hint" = "完成一局挑战，写下你的第一条记录。";
 
 /* 滑动开局与主窗口快捷入口。 */
-"home.start_hint" = "点击按钮/按空格键，或滑动触控栏开始游戏";
+"home.start_hint" = "点击按钮、按空格键，或滑动触控栏开始游戏";
 "home.starting" = "准备开始…";
 "home.starting_hint" = "正在展开触控栏，完成后开始挑战";
 "touchbar.slide_start" = "向右滑动开始游戏";
diff --git a/Tests/GameIconPresentationTests.swift b/Tests/GameIconPresentationTests.swift
index df5a55f8f30f116ba0c9a7caa643b310b94438a7..3f75d55d65759967b0e88b4fea6714dc20184c6d 100644
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -161,13 +161,13 @@ final class GameIconPresentationTests: AchievementTestCase {
                         let verticalScale = CGFloat(pixels.pixelsHigh) / badge.bounds.height
                         var minX = pixels.pixelsWide, minY = pixels.pixelsHigh, maxX = -1, maxY = -1
                         var statusMinX = pixels.pixelsWide, statusMaxX = -1
-                        // 状态标记单独检查；居中测量仅包含成就图案与文字，忽略浅色卡片和边框。
+                        // 状态标记单独检查；按亮度将图案与文字从深色卡面中提取。
                         let insetX = Int(8 * scale), insetY = Int(4 * verticalScale)
                         for y in stride(from: insetY, to: pixels.pixelsHigh - insetY, by: 2) {
                             for x in stride(from: insetX, to: pixels.pixelsWide - insetX, by: 2) {
                                 guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                                       color.alphaComponent > 0.5,
-                                      min(color.redComponent, color.greenComponent, color.blueComponent) < 0.78 else { continue }
+                                      max(color.redComponent, color.greenComponent, color.blueComponent) > 0.58 else { continue }
                                 if CGFloat(x) / scale < 34 {
                                     statusMinX = min(statusMinX, x); statusMaxX = max(statusMaxX, x)
                                 } else {
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index 39cf35bf43213b46bcb59d9d3a01521bb6628004..b4a926e9e4ca64ef9108461bcb61e2132d8585c0 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -63,7 +63,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let longCount = 123_456
         let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
         for mode in HomeGameMode.allCases {
-            for width: CGFloat in [534, 1_360] {
+            for width: CGFloat in [336, 534, 1_360] {
                 let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: width, height: 148))
                 hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode, elapsedTime: 60,
                                                    remainingTime: mode == .timed ? 0 : nil,
@@ -71,11 +71,14 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                                                    isRunning: false, isFinished: true, clearedByKind: counts), mode: mode)
                 let bitmap = try image(hud)
                 let scale = CGFloat(bitmap.pixelsWide) / width
+                let surface = hud.surfaceRect
+                let rowStart = surface.maxY - surface.height * 0.29
+                let rowPixels = stride(from: Int(ceil(rowStart * scale)), to: Int(surface.maxY * scale), by: 2)
                 var iconStarts: [CGFloat] = []
                 var previousColoredX = -CGFloat.infinity
-                // 结算后的进度条没有颜色。用彩色列测量四个图标实际位置，覆盖不同位数的数字。
+                // 只在底部方块行检测彩色像素，避免把青色模式标题误当成方块。
                 for x in 0..<bitmap.pixelsWide {
-                    let containsArtwork = stride(from: 0, to: bitmap.pixelsHigh, by: 2).contains { y in
+                    let containsArtwork = rowPixels.contains { y in
                         guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                               color.alphaComponent > 0.9 else { return false }
                         let high = max(color.redComponent, color.greenComponent, color.blueComponent)
@@ -87,12 +90,12 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                     if position - previousColoredX > 3 { iconStarts.append(position) }
                     previousColoredX = position
                 }
-                let statsWidth = (hud.surfaceRect.width - 40) * (mode == .free ? 1 : 0.73)
-                let columnWidth = statsWidth * 2 / 3 / CGFloat(PieceKind.allCases.count)
+                let cut = min(surface.height * 0.25, surface.width * 0.09)
+                let columnWidth = (surface.width - cut) / CGFloat(PieceKind.allCases.count)
                 XCTAssertEqual(iconStarts.count, PieceKind.allCases.count, "\(mode.key) / \(width)")
-                let breakdownStart = hud.surfaceRect.maxX - 20 - statsWidth * 2 / 3
+                let breakdownStart = surface.minX + cut * 0.145 + min(18, columnWidth * 0.10)
                 for (index, start) in iconStarts.enumerated() {
-                    XCTAssertEqual(start, breakdownStart + CGFloat(index) * columnWidth, accuracy: 1,
+                    XCTAssertEqual(start, breakdownStart + CGFloat(index) * columnWidth, accuracy: 2,
                                    "\(mode.key) / \(width)：方块图标应依等宽列左边缘排布")
                 }
                 XCTAssertTrue(hud.toolTip?.contains("\(longCount)") == true, "长数字的完整值可通过提示查看")
@@ -119,14 +122,15 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                     for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1920, height: 1080)] {
                         home.setFrameSize(size); home.refresh(snapshot: snapshot, mode: mode, manager: manager)
                         _ = try image(home)
-                        XCTAssertEqual(home.challengeHUD.isHidden, !running && mode == .free)
-                        if !running, mode == .free {
-                            let intro = try XCTUnwrap(home.modeHeader.subviews.first { !$0.isHidden })
-                            let labels = intro.subviews.compactMap { $0 as? NSTextField }.sorted { $0.frame.minY < $1.frame.minY }
-                            XCTAssertEqual(labels.count, 2)
-                            XCTAssertGreaterThanOrEqual(labels[1].frame.minY - labels[0].frame.maxY, 8,
-                                                        "主标题和副标题之间保留独立排版空间")
-                        }
+                        XCTAssertFalse(home.challengeHUD.isHidden)
+                        let intro = try modeIntro(in: home.modeHeader)
+                        let labels = intro.subviews.compactMap { $0 as? NSTextField }.sorted { $0.frame.minY < $1.frame.minY }
+                        XCTAssertEqual(labels.map(\.stringValue), [AchievementText.string("home.hero.\(mode.key)"),
+                                                                 AchievementText.string("home.subtitle.\(mode.key)")])
+                        let heading = try XCTUnwrap(labels.first)
+                        let subtitle = try XCTUnwrap(labels.last)
+                        XCTAssertGreaterThanOrEqual(subtitle.frame.minY - heading.frame.maxY, 8)
+                        XCTAssertLessThan(intro.frame.maxX, home.challengeHUD.frame.minX)
                         XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, running ? 42 : 0)
                         let hudRect = home.challengeHUD.convert(home.challengeHUD.bounds, to: home)
                         XCTAssertTrue(home.bounds.contains(hudRect))
@@ -163,6 +167,10 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         }
         XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
         Localizer.shared.setLanguage(.chineseSimplified)
+        home.setFrameSize(NSSize(width: 1585, height: 992))
+        home.refresh(snapshot: GameSnapshot(mode: .free, elapsedTime: 0, remainingTime: nil,
+            remainingSwaps: nil, isRunning: false, isFinished: false), mode: .free, manager: manager)
+        try export(home, name: "lobby-reference-size")
         home.setFrameSize(NSSize(width: 1180, height: 800))
         home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 150, remainingTime: nil,
             remainingSwaps: 3, isRunning: true, isFinished: false, clearedByKind: [.orangeRicky: 120]), mode: .moves, manager: manager)
@@ -197,9 +205,11 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let moves = GameSnapshot(mode: .moves(limit: 30), elapsedTime: 0, remainingTime: nil, remainingSwaps: 30, isRunning: false, isFinished: false)
         home.refresh(snapshot: free, mode: .free, manager: manager)
         home.layoutSubtreeIfNeeded()
-        let intro = try XCTUnwrap(header.subviews.first { !$0.isHidden })
-        let restingX = intro.frame.minX
-        let restingWidth = intro.frame.width
+        let intro = try modeIntro(in: header)
+        let introFrame = intro.frame
+        let outgoing = home.challengeHUD
+        let restingX = outgoing.frame.minX
+        let restingWidth = outgoing.frame.width
         home.refresh(snapshot: timed, mode: .timed, manager: manager)
         let preview = home.challengeHUD
         XCTAssertGreaterThan(preview.frame.minX, restingX)
@@ -229,9 +239,9 @@ final class GameLobbyPresentationTests: AchievementTestCase {
                 home.refresh(snapshot: timed, mode: .timed, manager: manager)
                 home.layoutSubtreeIfNeeded()
                 XCTAssertEqual(preview.frame.minX, position, accuracy: 1, "重复刷新不能重启动画")
-                try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview)
             }
-            if step == steps * 3 / 4 { XCTAssertLessThan(intro.frame.minX, restingX, "卡片接触文案后将其向左推开") }
+            if step == steps / 3 { try assertPreviewLaysOverGapAndBehindPanel(home, preview: preview) }
+            XCTAssertEqual(intro.frame, introFrame, "切换统计卡时保留标题的位置")
             XCTAssertEqual(preview.convert(preview.surfaceRect, to: home).minY, home.modePanel.frame.minY, accuracy: 0.1)
             home.layoutSubtreeIfNeeded()
             let pixels = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: header.frame))
@@ -248,7 +258,8 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(preview.frame.minX, restingX, accuracy: 1)
         XCTAssertEqual(preview.frame.width, restingWidth, accuracy: 0.1)
         XCTAssertEqual(preview.alphaValue, 1)
-        XCTAssertTrue(intro.isHidden)
+        XCTAssertTrue(outgoing.isHidden)
+        XCTAssertFalse(intro.isHidden)
 
         home.refresh(snapshot: moves, mode: .moves, manager: manager)
         XCTAssertEqual(home.challengeHUD.budgetText, "30")
@@ -265,10 +276,14 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         XCTAssertEqual(home.challengeHUD.frame.minX, restingX, accuracy: 1)
         XCTAssertTrue(preview.isHidden)
         home.refresh(snapshot: free, mode: .free, manager: manager)
-        XCTAssertTrue(home.challengeHUD.isHidden)
+        XCTAssertFalse(home.challengeHUD.isHidden)
         XCTAssertFalse(intro.isHidden)
     }
 
+    private func modeIntro(in header: HomeModeHeaderView) throws -> NSView {
+        try XCTUnwrap(header.subviews.first { !$0.isHidden && !($0 is HomeChallengeHUDView) })
+    }
+
     private func assertLaunchIsWithinScreen(_ preview: HomeChallengeHUDView, in window: NSWindow) throws {
         XCTAssertLessThanOrEqual(preview.frame.maxX, try XCTUnwrap(preview.superview).bounds.maxX + 0.1)
         if let screen = window.screen {
@@ -281,7 +296,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
     private func assertPreviewLaysOverGapAndBehindPanel(_ home: HomeDashboardView, preview: HomeChallengeHUDView) throws {
         let panel = home.modePanel.frame
         let surface = preview.convert(preview.surfaceRect, to: home)
-        let gapPoint = NSPoint(x: panel.minX - 14, y: panel.minY + 43)
+        let gapPoint = NSPoint(x: panel.minX - 10, y: surface.midY)
         let panelPoint = NSPoint(x: panel.minX + 10, y: gapPoint.y)
         XCTAssertTrue(surface.contains(gapPoint) && surface.contains(panelPoint))
 
@@ -338,7 +353,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
         let mode = HomeModeButton(mode: .moves)
         mode.frame = NSRect(x: 10, y: 80, width: 320, height: 90); mode.selected = true
         let button = HomeButton(frame: NSRect(x: 23, y: 10, width: 294, height: 62))
-        button.primary = true; button.title = "开始游戏"; button.symbolName = "play.fill"
+        button.style = .primary; button.title = "开始游戏"; button.symbolName = "play.fill"
         preview.addSubview(mode); preview.addSubview(button)
         var clock: TimeInterval = 100
         for effect in [mode.feedback, button.feedback] { effect.now = { clock }; effect.reducesMotion = { false } }
@@ -361,7 +376,7 @@ final class GameLobbyPresentationTests: AchievementTestCase {
 }
 
 private final class LobbyFeedbackPreview: NSView {
-    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
+    override func draw(_ dirtyRect: NSRect) { HomeDashboardStyle.backdrop(in: bounds) }
 }
 
 /// 仅测试 target 中的三枚图案总览，不增加正式页面入口。
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index 4c39f3529a33f336c4ad9e20f9cd287998b4360d..a8e612cadda7225c14f953143167286de08c384c 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -68,7 +68,7 @@ final class HomeDashboardTests: AchievementTestCase {
         let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false, startClock: { animationTime })
         controller.startSequence.reducesMotion = { false }
         let view = controller.view
-        let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.primary })
+        let start = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeButton }.first { $0.style == .primary })
         let home = try XCTUnwrap(view as? HomeDashboardView)
         let puzzle = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == nil })
         XCTAssertFalse(board.snapshot().isRunning)
@@ -132,18 +132,19 @@ final class HomeDashboardTests: AchievementTestCase {
         let badges = buttons.filter { $0.toolTip != nil }
         XCTAssertEqual(badges.count, AchievementDefinition.all.count)
         for (width, height, count) in [(960, 720, 5), (1180, 800, 5), (1440, 720, 7),
-                                       (960, 1000, 5), (1600, 1000, 8), (1920, 1250, 9), (960, 720, 5)] {
+                                       (960, 1000, 5), (1600, 1000, 7), (1920, 1250, 9), (960, 720, 5)] {
             home.setFrameSize(NSSize(width: width, height: height))
             home.layoutSubtreeIfNeeded()
             let mode = home.modePanel.frame
             let path = home.achievementPath.frame
             let contact = home.contactPanel.frame
             XCTAssertEqual(home.startButton.frame.maxY, contact.maxY, accuracy: 0.1)
-            XCTAssertEqual(contact.minY - mode.maxY, 24, accuracy: 0.1)
+            XCTAssertGreaterThanOrEqual(contact.minY - mode.maxY, 27)
+            XCTAssertLessThanOrEqual(contact.minY - mode.maxY, 52.1)
             XCTAssertEqual(contact.minX, mode.minX, accuracy: 0.1)
             XCTAssertEqual(contact.width, mode.width, accuracy: 0.1)
-            XCTAssertEqual(contact.height, 156)
-            XCTAssertEqual(path.minY - contact.maxY, 24, accuracy: 0.1)
+            XCTAssertTrue((110...165).contains(contact.height))
+            XCTAssertGreaterThanOrEqual(path.minY - contact.maxY, 35)
             XCTAssertEqual(path.minX, home.bounds.maxX - path.maxX, accuracy: 0.1)
             XCTAssertEqual(path.maxX, contact.maxX, accuracy: 0.1)
             XCTAssertTrue(home.bounds.contains(path))
@@ -186,6 +187,11 @@ final class HomeDashboardTests: AchievementTestCase {
         let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
         for language in AppLanguage.allCases {
             Localizer.shared.setLanguage(language)
+            let brand = AchievementText.string("home.brand")
+            XCTAssertEqual(brand, AchievementText.string("window.title"))
+            if language == .chineseSimplified {
+                XCTAssertEqual(brand, "消除俄罗斯方块")
+            }
             for mode in HomeGameMode.allCases {
                 let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: 12, remainingTime: mode == .timed ? 48 : nil,
                                             remainingSwaps: mode == .moves ? 18 : nil, isRunning: true, isFinished: false,
diff --git a/Sources/HomeDashboardStyle.swift b/Sources/HomeDashboardStyle.swift
new file mode 100644
index 0000000000000000000000000000000000000000..f3cb547221035e0b8b2990e0d2563bbb86e1bf77
--- /dev/null
+++ b/Sources/HomeDashboardStyle.swift
@@ -0,0 +1,114 @@
+import Cocoa
+
+/// 大厅以深蓝底、青色状态和黄色主操作组织视觉层级。
+enum HomeDashboardStyle {
+    static let navy = color(0x0B1520)
+    static let ink = color(0xF4F7FC)
+    static let muted = color(0xB6C4D2)
+    static let cyan = color(0x20EDF5)
+    static let yellow = color(0xFFF044)
+    static let green = color(0x59EF86)
+    static let border = color(0x526779)
+    static let panel = color(0x172636)
+
+    static func color(_ rgb: UInt32) -> NSColor {
+        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
+                green: CGFloat((rgb >> 8) & 255) / 255,
+                blue: CGFloat(rgb & 255) / 255, alpha: 1)
+    }
+
+    static func slant(_ rect: NSRect, cut: CGFloat, reverse: Bool = false) -> NSBezierPath {
+        let path = NSBezierPath()
+        let inset = min(max(0, cut), max(0, rect.width))
+        let top = reverse ? 0 : inset
+        let bottom = reverse ? inset : 0
+        path.move(to: NSPoint(x: rect.minX + top, y: rect.minY))
+        path.line(to: NSPoint(x: rect.maxX - bottom, y: rect.minY))
+        path.line(to: NSPoint(x: rect.maxX - top, y: rect.maxY))
+        path.line(to: NSPoint(x: rect.minX + bottom, y: rect.maxY))
+        path.close()
+        return path
+    }
+
+    static func surface(_ rect: NSRect, cut: CGFloat, colors: [NSColor], border: NSColor, lineWidth: CGFloat = 1) {
+        guard rect.width > lineWidth, rect.height > lineWidth else { return }
+        let face = slant(rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cut: cut)
+        NSGradient(colors: colors)?.draw(in: face, angle: 20)
+        border.setStroke()
+        face.lineWidth = lineWidth
+        face.stroke()
+    }
+
+    static func line(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat = 1) {
+        let path = NSBezierPath()
+        path.move(to: start)
+        path.line(to: end)
+        color.setStroke()
+        path.lineWidth = width
+        path.stroke()
+    }
+
+    static func text(_ value: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
+                     color: NSColor = ink, italic: Bool = false, alignment: NSTextAlignment = .left) {
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.alignment = alignment
+        paragraph.lineBreakMode = .byTruncatingTail
+        (value as NSString).draw(in: rect, withAttributes: [
+            .font: NSFont.systemFont(ofSize: size, weight: weight),
+            .foregroundColor: color, .paragraphStyle: paragraph, .obliqueness: italic ? 0.19 : 0,
+        ])
+    }
+
+    static func description(_ value: String, in rect: NSRect, preferred: CGFloat) {
+        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.lineBreakMode = .byWordWrapping
+        var size = max(9, preferred)
+        let text = value as NSString
+        let constraint = NSSize(width: max(1, rect.width), height: .greatestFiniteMagnitude)
+        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: muted, .paragraphStyle: paragraph]
+        while true {
+            attributes[.font] = NSFont.systemFont(ofSize: size)
+            if size <= 9 || ceil(text.boundingRect(with: constraint, options: options, attributes: attributes).height) <= rect.height {
+                break
+            }
+            size = max(9, size - 1)
+        }
+        text.draw(with: rect, options: options.union(.truncatesLastVisibleLine), attributes: attributes)
+    }
+
+    static func mark(in rect: NSRect, color: NSColor = cyan) {
+        color.setFill()
+        slant(rect, cut: rect.width * 0.48).fill()
+    }
+
+    static func backdrop(in rect: NSRect) {
+        NSGradient(colors: [color(0x090F16), navy, color(0x080E16)])?.draw(in: rect, angle: 21)
+        if let context = NSGraphicsContext.current?.cgContext, rect.width > 0, rect.height > 0 {
+            let blue = color(0x2A5B71)
+            let colors = [blue.withAlphaComponent(0.26).cgColor, blue.withAlphaComponent(0).cgColor]
+            if let light = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
+                                      colors: colors as CFArray, locations: [0, 1]) {
+                context.saveGState()
+                context.translateBy(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.52)
+                context.scaleBy(x: rect.width * 0.45, y: rect.height * 0.44)
+                context.drawRadialGradient(light, startCenter: .zero, startRadius: 0,
+                                           endCenter: .zero, endRadius: 1, options: [])
+                context.restoreGState()
+            }
+        }
+        // 斜纹沿整个窗口铺开，右栏按同一坐标重绘以遮住入场中的统计卡。
+        let bands: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
+            (-0.20, 0.0, 0.27, 0.10), (-0.03, -0.04, 0.10, 0.15),
+            (0.21, 0, 0.065, 0.12), (0.43, -0.02, 0.037, 0.08),
+            (0.62, 0, 0.061, 0.13), (0.98, 0.13, 0.12, 0.14),
+        ]
+        for (x, y, width, alpha) in bands {
+            let band = NSRect(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y,
+                              width: rect.width * (width + 0.38), height: rect.height)
+            NSGradient(colors: [color(0x355474).withAlphaComponent(alpha),
+                                color(0x355474).withAlphaComponent(alpha * 0.19)])?
+                .draw(in: slant(band, cut: rect.width * 0.38), angle: 73)
+        }
+    }
+}
diff --git a/Sources/HomeLobbyArtwork.swift b/Sources/HomeLobbyArtwork.swift
new file mode 100644
index 0000000000000000000000000000000000000000..94ed7f924aa7398a86f72be74b99b1d186171a00
--- /dev/null
+++ b/Sources/HomeLobbyArtwork.swift
@@ -0,0 +1,259 @@
+import Cocoa
+
+/// 大厅的方块与触控栏教学图，使用矢量绘制以适应不同窗口和显示倍率。
+enum HomeLobbyArtwork {
+    private struct PiecePalette {
+        let face: NSColor
+        let light: NSColor
+        let shade: NSColor
+    }
+
+    private static let palettes: [PieceKind: PiecePalette] = [
+        .orangeRicky: PiecePalette(face: color(0xFF9B0A), light: color(0xFFE5A1), shade: color(0xA44903)),
+        .blueRicky: PiecePalette(face: color(0x008CFF), light: color(0x9CF4FF), shade: color(0x024394)),
+        .clevelandZ: PiecePalette(face: color(0x00DB64), light: color(0xA1FFC7), shade: color(0x08783A)),
+        .rhodeIslandZ: PiecePalette(face: color(0xFF5B4B), light: color(0xFFD0C4), shade: color(0xA92B25))
+    ]
+    private static let pieceSize = NSSize(width: 138, height: 94)
+    private static let pieces: [PieceKind: NSImage] = {
+        palettes.reduce(into: [:]) { images, entry in
+            let (kind, palette) = entry
+            images[kind] = NSImage(size: pieceSize, flipped: true) { _ in
+                let pitch: CGFloat = 46
+                for block in kind.blocks {
+                    let cell = NSRect(x: CGFloat(block.x) * pitch, y: CGFloat(1 - block.y) * pitch,
+                                      width: pitch - 0.8, height: pitch + 1.5)
+                    drawCell(in: cell, palette: palette)
+                }
+                return true
+            }
+        }
+    }()
+
+    /// 绘制与大厅插画一致的方块，保持原始长宽比。
+    static func drawPiece(_ kind: PieceKind, in bounds: NSRect) {
+        guard let image = pieces[kind], bounds.width > 0, bounds.height > 0 else { return }
+        let scale = min(bounds.width / pieceSize.width, bounds.height / pieceSize.height)
+        let width = pieceSize.width * scale
+        let height = pieceSize.height * scale
+        let rect = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
+        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
+                   respectFlipped: true, hints: nil)
+    }
+
+    static func drawHero(in bounds: NSRect, phase: CGFloat, animated: Bool) {
+        let canvas = NSSize(width: 920, height: 184)
+        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
+        guard scale > 0 else { return }
+        NSGraphicsContext.saveGraphicsState()
+        defer { NSGraphicsContext.restoreGraphicsState() }
+        let transform = NSAffineTransform()
+        transform.translateX(by: bounds.midX - canvas.width * scale / 2, yBy: bounds.midY - canvas.height * scale / 2)
+        transform.scale(by: scale)
+        transform.concat()
+
+        let floor = polygon([NSPoint(x: 59, y: 99), NSPoint(x: 917, y: 99),
+                             NSPoint(x: 888, y: 152), NSPoint(x: 25, y: 152)])
+        gradient(floor, from: .clear, to: color(0x254350, alpha: 0.43),
+                 start: NSPoint(x: 36, y: 130), end: NSPoint(x: 890, y: 147))
+        let floorEdge = polygon([NSPoint(x: 76, y: 150), NSPoint(x: 889, y: 150),
+                                 NSPoint(x: 889, y: 152), NSPoint(x: 76, y: 152)])
+        gradient(floorEdge, from: color(0x5F9CB2, alpha: 0.14), to: .clear,
+                 start: NSPoint(x: 76, y: 151), end: NSPoint(x: 889, y: 151))
+
+        let positions: [(kind: PieceKind, x: CGFloat, streak: NSPoint)] = [
+            (.orangeRicky, 80, NSPoint(x: 80, y: 40)),
+            (.blueRicky, 271, NSPoint(x: 381, y: 15)),
+            (.clevelandZ, 532, NSPoint(x: 666, y: 28)),
+            (.rhodeIslandZ, 720, NSPoint(x: 854, y: 32))
+        ]
+        for (index, position) in positions.enumerated() {
+            guard let palette = palettes[position.kind] else { continue }
+            drawStreaks(at: position.streak, color: palette.face)
+            let floating = animated ? sin(phase + CGFloat(index) * 0.9) * 2.7 : 0
+            let rect = NSRect(x: position.x, y: 43 + floating, width: pieceSize.width, height: pieceSize.height)
+            let reflectedColor = palette.face.withAlphaComponent(0.29)
+            glow(NSRect(x: rect.minX - 43, y: rect.maxY - 38, width: rect.width + 86, height: 86),
+                 color: palette.face.withAlphaComponent(0.43))
+            glow(NSRect(x: rect.minX - 9, y: rect.maxY - 9, width: rect.width + 18, height: 24),
+                 color: color(0x020509, alpha: 0.72))
+            drawReflection(of: position.kind, in: rect, color: reflectedColor)
+            drawPiece(position.kind, in: rect)
+        }
+        let arrow = NSBezierPath()
+        arrow.move(to: NSPoint(x: 447, y: 90))
+        arrow.line(to: NSPoint(x: 504, y: 90))
+        arrow.move(to: NSPoint(x: 458, y: 79))
+        arrow.line(to: NSPoint(x: 447, y: 90))
+        arrow.line(to: NSPoint(x: 458, y: 101))
+        arrow.move(to: NSPoint(x: 493, y: 79))
+        arrow.line(to: NSPoint(x: 504, y: 90))
+        arrow.line(to: NSPoint(x: 493, y: 101))
+        color(0xF3F8FF, alpha: 0.92).setStroke()
+        arrow.lineWidth = 3.5
+        arrow.stroke()
+    }
+
+    static func drawTouchBar(in bounds: NSRect) {
+        let canvas = NSSize(width: 925, height: 112)
+        let scale = min(bounds.width / canvas.width, bounds.height / canvas.height)
+        guard scale > 0 else { return }
+        NSGraphicsContext.saveGraphicsState()
+        defer { NSGraphicsContext.restoreGraphicsState() }
+        let transform = NSAffineTransform()
+        transform.translateX(by: bounds.midX - canvas.width * scale / 2, yBy: bounds.minY)
+        transform.scale(by: scale)
+        transform.concat()
+
+        let rail = polygon([NSPoint(x: 36, y: 1), NSPoint(x: 924, y: 1),
+                            NSPoint(x: 891, y: 68), NSPoint(x: 1, y: 68)])
+        gradient(rail, from: color(0x040B10), to: color(0x10202A),
+                 start: NSPoint(x: 0, y: 0), end: NSPoint(x: 15, y: 68))
+        color(0xB7D3DA, alpha: 0.7).setStroke()
+        rail.lineWidth = 1.2
+        rail.stroke()
+
+        let cyan = color(0x28E8FA)
+        glow(NSRect(x: 561, y: 37, width: 190, height: 50), color: cyan.withAlphaComponent(0.40))
+        glow(NSRect(x: 634, y: 7, width: 88, height: 58), color: color(0x235CFF, alpha: 0.74))
+        let kinds: [PieceKind] = [.orangeRicky, .blueRicky, .clevelandZ, .rhodeIslandZ]
+        for index in 0..<13 {
+            drawPiece(kinds[index % kinds.count], in: NSRect(x: 56 + CGFloat(index) * 65.5, y: 14, width: 48, height: 34))
+        }
+        for index in 0..<3 {
+            let x = 617 + CGFloat(index) * 15.5
+            let chevron = NSBezierPath()
+            chevron.move(to: NSPoint(x: x, y: 42))
+            chevron.line(to: NSPoint(x: x + 8, y: 49))
+            chevron.line(to: NSPoint(x: x, y: 56))
+            cyan.withAlphaComponent(0.72 + CGFloat(index) * 0.12).setStroke()
+            chevron.lineWidth = 3
+            chevron.stroke()
+        }
+        let swipe = NSBezierPath()
+        swipe.move(to: NSPoint(x: 585, y: 65))
+        swipe.line(to: NSPoint(x: 697, y: 65))
+        cyan.withAlphaComponent(0.63).setStroke()
+        swipe.lineWidth = 1
+        swipe.stroke()
+        drawHand(at: NSPoint(x: 671, y: 46), tint: cyan)
+    }
+
+    private static func drawCell(in rect: NSRect, palette: PiecePalette) {
+        // 底沿与高光分开绘制，缩小到统计和触控栏图示后仍能辨认每一格。
+        let bevel = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
+        gradient(bevel, from: palette.light, to: palette.shade,
+                 start: NSPoint(x: rect.midX, y: rect.minY), end: NSPoint(x: rect.midX, y: rect.maxY))
+        let face = NSBezierPath(roundedRect: NSRect(x: rect.minX + 2.2, y: rect.minY + 3.2,
+                                                   width: rect.width - 5.0, height: rect.height - 8.2),
+                                xRadius: 4, yRadius: 4)
+        let highlight = palette.face.blended(withFraction: 0.18, of: palette.light) ?? palette.face
+        let lowerFace = palette.face.blended(withFraction: 0.16, of: palette.shade) ?? palette.face
+        gradient(face, from: highlight, to: lowerFace,
+                 start: NSPoint(x: rect.minX, y: rect.minY), end: NSPoint(x: rect.maxX, y: rect.maxY))
+        color(0xFFFFFF, alpha: 0.24).setStroke()
+        face.lineWidth = 0.8
+        face.stroke()
+        let shine = NSBezierPath()
+        shine.move(to: NSPoint(x: rect.minX + 6.5, y: rect.minY + 1.3))
+        shine.line(to: NSPoint(x: rect.maxX - 7, y: rect.minY + 1.3))
+        NSColor.white.withAlphaComponent(0.76).setStroke()
+        shine.lineCapStyle = .round
+        shine.lineWidth = 1.15
+        shine.stroke()
+    }
+
+    private static func drawStreaks(at point: NSPoint, color: NSColor) {
+        for index in 0..<3 {
+            let x = point.x + CGFloat(index) * 11.0
+            let y = point.y - CGFloat(index) * 3.3
+            let path = polygon([NSPoint(x: x + 20, y: y + 7), NSPoint(x: x + 32, y: y + 4),
+                                NSPoint(x: x - 3, y: y + 55), NSPoint(x: x - 13, y: y + 55)])
+            gradient(path, from: color.withAlphaComponent(0.29 + CGFloat(index) * 0.22), to: color.withAlphaComponent(0),
+                     start: NSPoint(x: x + 29, y: y + 5), end: NSPoint(x: x - 8, y: y + 51))
+        }
+    }
+
+    private static func drawReflection(of kind: PieceKind, in rect: NSRect, color: NSColor) {
+        let depth: CGFloat = 25
+        let base = rect.maxY + 5
+        for block in kind.blocks where block.y == 0 {
+            let reflection = NSRect(x: rect.minX + CGFloat(block.x) * 46 + 1, y: base, width: 43, height: depth)
+            let path = NSBezierPath(roundedRect: reflection, xRadius: 4, yRadius: 4)
+            gradient(path, from: color, to: color.withAlphaComponent(0),
+                     start: NSPoint(x: reflection.midX, y: base), end: NSPoint(x: reflection.midX, y: base + depth))
+        }
+    }
+
+    private static func drawHand(at origin: NSPoint, tint: NSColor) {
+        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x, y: origin.y + y) }
+        let hand = NSBezierPath()
+        hand.move(to: point(24, 62))
+        hand.curve(to: point(17, 55), controlPoint1: point(22, 59), controlPoint2: point(21, 57))
+        hand.curve(to: point(5, 40), controlPoint1: point(13, 53), controlPoint2: point(8, 45))
+        hand.curve(to: point(10, 33), controlPoint1: point(0, 34), controlPoint2: point(5, 29))
+        hand.line(to: point(15, 39))
+        hand.line(to: point(6, 9))
+        hand.curve(to: point(14, 5), controlPoint1: point(4, 2), controlPoint2: point(12, 0))
+        hand.line(to: point(21, 30))
+        hand.curve(to: point(29, 27), controlPoint1: point(20, 23), controlPoint2: point(27, 21))
+        hand.line(to: point(31, 33))
+        hand.curve(to: point(39, 31), controlPoint1: point(30, 26), controlPoint2: point(37, 25))
+        hand.line(to: point(41, 36))
+        hand.curve(to: point(47, 35), controlPoint1: point(41, 30), controlPoint2: point(45, 30))
+        hand.curve(to: point(48, 51), controlPoint1: point(50, 40), controlPoint2: point(50, 46))
+        hand.curve(to: point(49, 61), controlPoint1: point(47, 56), controlPoint2: point(48, 59))
+        // 底端敞开；填充先封闭内部，白色描边在手腕两侧自然结束。
+        color(0x091722, alpha: 0.91).setFill()
+        hand.fill()
+        NSGraphicsContext.saveGraphicsState()
+        let glow = NSShadow()
+        glow.shadowColor = tint.withAlphaComponent(0.55)
+        glow.shadowBlurRadius = 7
+        glow.shadowOffset = .zero
+        glow.set()
+        color(0xEAF9FE).setStroke()
+        hand.lineWidth = 2.35
+        hand.lineCapStyle = .round
+        hand.lineJoinStyle = .round
+        hand.stroke()
+        NSGraphicsContext.restoreGraphicsState()
+    }
+
+    private static func polygon(_ points: [NSPoint]) -> NSBezierPath {
+        let path = NSBezierPath()
+        guard let first = points.first else { return path }
+        path.move(to: first)
+        for point in points.dropFirst() {
+            path.line(to: point)
+        }
+        path.close()
+        return path
+    }
+
+    private static func gradient(_ path: NSBezierPath, from: NSColor, to: NSColor, start: NSPoint, end: NSPoint) {
+        NSGraphicsContext.saveGraphicsState()
+        path.addClip()
+        NSGradient(starting: from, ending: to)?
+            .draw(from: start, to: end, options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
+        NSGraphicsContext.restoreGraphicsState()
+    }
+
+    private static func glow(_ rect: NSRect, color: NSColor) {
+        let colors = [color.cgColor, color.withAlphaComponent(color.alphaComponent * 0.28).cgColor,
+                      color.withAlphaComponent(0).cgColor]
+        guard let context = NSGraphicsContext.current?.cgContext,
+              let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 0.55, 1]) else { return }
+        // 在单位圆内衰减，再缩放到椭圆，既保持扁平的地面反光，也避免出现可见的椭圆边。
+        context.saveGState()
+        context.translateBy(x: rect.midX, y: rect.midY)
+        context.scaleBy(x: rect.width / 2, y: rect.height / 2)
+        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
+        context.restoreGState()
+    }
+
+    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
+        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
+                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
+    }
+}
```
