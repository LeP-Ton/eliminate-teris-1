# 恢复弹窗卡片的平行四边形边框

## 背景与目标

- 会话-12 至会话-15 修复玩法说明截图中的切角六边形。弹窗内容卡片应使用与大厅同斜率的完整平行四边形。
- 保留各弹窗的原生操作与滚动布局。内容须落在斜边内，并适应现有五种语言和紧凑窗口。

## 完成情况

- [x] 移除切角分支，设置、玩法说明、挑战记录和成就的卡片统一使用现有 0.45 斜率绘制左右全长斜边。
- [x] 使用布局引导线按各行四角计算斜边留白。高度贴合内容，避免横向抱紧约束拉长整张卡片。
- [x] 玩法说明保持三个步骤共用一张大卡。标题、示意图和正文各按可用空间排版，正文独占一行的有效宽度。记录日期列随行宽变化。
- [x] 成就筛选栏、详情说明和进度条应用相同卡片布局。

## 测试方法

- 用宽窄窗口渲染玩法、设置和挑战记录的五种语言，校验卡内文字与两条斜边的位置。对玩法卡左右边在四个高度采样，并核对说明实际换行和约束后的窗口宽度。
- 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，覆盖弹窗滚动、切换、成就进度与既有大厅行为。最终 90 项测试全部通过。
- 手动打开 `./run.sh` 后点击「玩法说明」，查看教学大卡下方的模式卡与说明卡。俄语紧凑窗口的预览由同一原生视图导出。

## 代码变更


```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 9451f3df24d0222f2e068034aa78b1201ecb3a6a..021351643a97b1c5a23fdc7e639d765571ea403c 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261123215822-restore-popup-parallelogram-borders.md` - 会话-12 至会话-15 恢复辅助弹窗卡片的整条斜边，逐行给文案和表格留白。含宽窄原生渲染与本轮增量 diff。
 `workflow/20261123092817-unify-lobby-and-panel-slants.md` - 会话-9 至会话-11 统一大厅和弹窗的斜边与文字，修正等宽统计格、斜切进度填充和滑块动画。含实际预览、回归与本轮增量 diff。
 `workflow/20261123082529-match-reference-rule-and-stat-card.md` - 会话-6 至会话-8 按参考图坐标还原规则背板、总数前板和四张分类斜卡。含双边暗缝像素回归与本轮增量 diff。
 `workflow/20261123075948-dark-angular-appkit-ui.md` - 会话-2 至会话-5 在 `experiment/ui-refactor-v2` 按设计图重构深色 AppKit 界面，保留「消除俄罗斯方块」名称。含五语言、原生预览验证和完整 diff。
@@ -100,6 +101,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整玩法、设置、挑战记录或成就弹窗的完整平行四边形和内部行布局时，读取 `20261123215822-restore-popup-parallelogram-borders.md`。
 - 需要调整统一斜角、轻斜文字、成就进度的部分填充、等宽消除分格或弹窗分段滑块时，读取 `20261123092817-unify-lobby-and-panel-slants.md`。
 - 需要核对深色大厅规则与消除统计卡的原图尺寸、层间错位、分格暗缝、长数字或转场遮挡时，读取 `20261123082529-match-reference-rule-and-stat-card.md`。
 - 需要调整深色大厅斜边主题、统计与标题并排、方块及触控栏示意，或核对辅助面板主题和游戏名称时，读取 `20261123075948-dark-angular-appkit-ui.md`。
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
index 0a5e41a710b19f84439fa96454c6eeddeededc91..ee39fe5cf39034ac71a12447b356c89db244ca8a 100644
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -394,14 +394,8 @@ final class AchievementsWindowController: NSWindowController {
         titleRow.orientation = .horizontal
         titleRow.alignment = .centerY
         titleRow.spacing = 8
-        let toolbar = NSStackView(views: [titleRow, actions])
-        toolbar.orientation = .vertical
-        toolbar.alignment = .leading
-        toolbar.spacing = 12
-        toolbar.translatesAutoresizingMaskIntoConstraints = false
-        let header = PixelFrameCardView(accentColor: AchievementPanelStyle.accent)
+        let header = UtilityCard(rows: [titleRow, actions], padding: 16, spacing: 12)
         header.translatesAutoresizingMaskIntoConstraints = false
-        header.addSubview(toolbar)
         content.addSubview(header)
 
         scroll.translatesAutoresizingMaskIntoConstraints = false
@@ -421,13 +415,6 @@ final class AchievementsWindowController: NSWindowController {
             header.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
             header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
             header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
-            toolbar.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
-            toolbar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
-            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
-            toolbar.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
-            titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
-            actions.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
-            filter.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
             filter.heightAnchor.constraint(equalToConstant: 44),
             backButton.heightAnchor.constraint(equalToConstant: 32),
             scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
@@ -445,8 +432,6 @@ final class AchievementsWindowController: NSWindowController {
     private func makeRow(_ definition: AchievementDefinition) -> NSView {
         let unlocked = manager.isUnlocked(id: definition.id)
         let accent = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.accent
-        let row = PixelFrameCardView(accentColor: accent)
-        row.translatesAutoresizingMaskIntoConstraints = false
         let name = UtilityStyle.label(AchievementText.string(definition.titleKey), size: 13, weight: .semibold,
                                       color: unlocked ? accent : AchievementPanelStyle.body)
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
@@ -472,22 +457,12 @@ final class AchievementsWindowController: NSWindowController {
         meter.maxValue = 1
         meter.doubleValue = unlocked ? 1 : manager.progress(for: definition).fraction
         meter.setAccessibilityLabel(progress.stringValue)
-        let stack = NSStackView(views: [titleRow, condition, progress, meter, status])
-        stack.orientation = .vertical
-        stack.alignment = .leading
-        stack.spacing = 9
-        stack.translatesAutoresizingMaskIntoConstraints = false
-        row.addSubview(stack)
-        for view in stack.arrangedSubviews {
-            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
+        let details: [NSView] = [titleRow, condition, progress, meter, status]
+        for view in details {
             view.setContentCompressionResistancePriority(.required, for: .vertical)
         }
-        NSLayoutConstraint.activate([
-            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
-            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
-            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
-            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
-        ])
+        let row = UtilityCard(rows: details, accent: unlocked ? accent : nil, padding: 16, spacing: 9)
+        row.translatesAutoresizingMaskIntoConstraints = false
         return row
     }
 
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index ab4ea8733a6db54e8306662a123d203f86d8b7b3..b539dd3b854532a920be0d4f59f2df6d9f8573c4 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -569,20 +569,6 @@ final class ArcadeStageView: NSView {
     }
 }
 
-/// 成就列表沿用辅助面板的斜边卡片，解锁状态由边框和图标共同表示。
-final class PixelFrameCardView: NSView {
-    private let accentColor: NSColor
-    init(accentColor: NSColor) {
-        self.accentColor = accentColor
-        super.init(frame: .zero)
-    }
-    required init?(coder: NSCoder) { nil }
-    override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) {
-        UtilityStyle.drawCard(bounds, accent: accentColor == HomeDashboardStyle.green ? accentColor : nil, containsContent: true)
-    }
-}
-
 final class PixelBannerView: NSView {
     private var animationTick: CGFloat = 0
     private var animationTimer: Timer?
diff --git a/Sources/HomeUtilityPanel.swift b/Sources/HomeUtilityPanel.swift
index f3ef67580fab8251a647b845e2b1d7d732da880f..e07a71e84a83080f9a3e1df6dfbe906f047b6445 100644
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -104,7 +104,7 @@ final class HomeUtilityPanel: NSWindowController {
         for view in recordBody.arrangedSubviews { recordBody.removeArrangedSubview(view); view.removeFromSuperview() }
         let mode: ModeRecordKey = recordTabs.selectedSegment == 0 ? .timed : .moves
         let entries = recordEntries(mode)
-        for view in [UtilityRecordBestView(mode: mode, entry: entries.first), UtilityRecordContent.table(mode: mode, entries: entries)] {
+        for view in [UtilityRecordContent.best(mode: mode, entry: entries.first), UtilityRecordContent.table(mode: mode, entries: entries)] {
             recordBody.addArrangedSubview(view); UtilityStyle.fillWidth(view, in: recordBody)
         }
         let sections = store.legacySections()
diff --git a/Sources/HomeUtilityViews.swift b/Sources/HomeUtilityViews.swift
index a63c77f9e502e81435844dc6e8dde8c5ce2dc179..6a784d3898d7b2ba51977ac4501941de4e6a71cb 100644
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -50,33 +50,12 @@ enum UtilityStyle {
         return view
     }
 
-    static func drawCard(_ rect: NSRect, accent: NSColor? = nil, containsContent: Bool = false) {
+    static func drawCard(_ rect: NSRect, accent: NSColor? = nil) {
         let top = HomeDashboardStyle.panel
         let base = HomeDashboardStyle.color(0x101C28)
         let tint = accent.flatMap { top.blended(withFraction: 0.12, of: $0) } ?? top
         let outline = accent?.withAlphaComponent(0.62) ?? HomeDashboardStyle.border
-        guard containsContent else {
-            HomeDashboardStyle.surface(rect, colors: [tint, base], border: outline)
-            return
-        }
-        // 长表格和说明保留足够的排版宽度，首尾切角与独立控件使用同一个斜率。
-        let face = rect.insetBy(dx: 0.5, dy: 0.5)
-        guard face.width > 1, face.height > 1 else { return }
-        let height = min(24, face.height)
-        let inset = HomeDashboardStyle.edgeOffset(for: height)
-        guard face.width > inset else { return }
-        let path = NSBezierPath()
-        path.move(to: NSPoint(x: face.minX + inset, y: face.minY))
-        path.line(to: NSPoint(x: face.maxX, y: face.minY))
-        path.line(to: NSPoint(x: face.maxX, y: face.maxY - height))
-        path.line(to: NSPoint(x: face.maxX - inset, y: face.maxY))
-        path.line(to: NSPoint(x: face.minX, y: face.maxY))
-        path.line(to: NSPoint(x: face.minX, y: face.minY + height))
-        path.close()
-        NSGradient(colors: [tint, base])?.draw(in: path, angle: 20)
-        outline.setStroke()
-        path.lineWidth = 1
-        path.stroke()
+        HomeDashboardStyle.surface(rect, colors: [tint, base], border: outline)
     }
 }
 
@@ -96,20 +75,50 @@ final class UtilityArtworkView: NSView {
 final class UtilityCard: NSView {
     private let accent: NSColor?
 
-    init(_ content: NSView, accent: NSColor? = nil, padding: CGFloat = 20) {
+    convenience init(_ content: NSView, accent: NSColor? = nil, padding: CGFloat = 20) {
+        self.init(rows: [content], accent: accent, padding: padding)
+    }
+
+    init(rows: [NSView], accent: NSColor? = nil, padding: CGFloat = 20, spacing: CGFloat = 0) {
         self.accent = accent
         super.init(frame: .zero)
-        content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
-        NSLayoutConstraint.activate([
-            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
-            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
-            content.topAnchor.constraint(equalTo: topAnchor, constant: padding),
-            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
-        ])
+        var top = topAnchor
+        for (index, row) in rows.enumerated() {
+            row.translatesAutoresizingMaskIntoConstraints = false
+            addSubview(row)
+            row.topAnchor.constraint(equalTo: top, constant: index == 0 ? padding : spacing).isActive = true
+            constrainToSlantedEdges(row, padding: padding)
+            top = row.bottomAnchor
+        }
+        bottomAnchor.constraint(equalTo: top, constant: padding).isActive = true
+        // 斜边把宽高联在一起。优先贴合内容高度，避免水平抱紧约束靠拉高卡片缩短各行。
+        let fittedHeight = heightAnchor.constraint(equalToConstant: 0)
+        fittedHeight.priority = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultHigh.rawValue - 1)
+        fittedHeight.isActive = true
     }
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent, containsContent: true) }
+    override func draw(_ dirtyRect: NSRect) { UtilityStyle.drawCard(bounds, accent: accent) }
+
+    private func constrainToSlantedEdges(_ row: NSView, padding: CGFloat) {
+        let left = NSLayoutGuide()
+        let right = NSLayoutGuide()
+        addLayoutGuide(left)
+        addLayoutGuide(right)
+        // 左上角和右下角最接近边框。以这两处的垂直距离换算水平留白。
+        NSLayoutConstraint.activate([
+            left.leadingAnchor.constraint(equalTo: leadingAnchor),
+            left.trailingAnchor.constraint(equalTo: row.leadingAnchor),
+            left.topAnchor.constraint(equalTo: row.topAnchor),
+            left.bottomAnchor.constraint(equalTo: bottomAnchor),
+            left.widthAnchor.constraint(equalTo: left.heightAnchor, multiplier: HomeDashboardStyle.slope, constant: padding),
+            right.leadingAnchor.constraint(equalTo: row.trailingAnchor),
+            right.trailingAnchor.constraint(equalTo: trailingAnchor),
+            right.topAnchor.constraint(equalTo: topAnchor),
+            right.bottomAnchor.constraint(equalTo: row.bottomAnchor),
+            right.widthAnchor.constraint(equalTo: right.heightAnchor, multiplier: HomeDashboardStyle.slope, constant: padding)
+        ])
+    }
 }
 
 /// 标题固定、正文独立滚动，在小屏幕与长翻译下不裁切内容。
@@ -224,12 +233,22 @@ final class UtilityLessonArtwork: NSView {
     init(step: Int) {
         self.step = step; super.init(frame: .zero)
         translatesAutoresizingMaskIntoConstraints = false
-        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 100), heightAnchor.constraint(equalToConstant: 52)])
+        let preferredWidth = widthAnchor.constraint(equalToConstant: 72)
+        preferredWidth.priority = .defaultLow
+        NSLayoutConstraint.activate([
+            widthAnchor.constraint(greaterThanOrEqualToConstant: 48), widthAnchor.constraint(lessThanOrEqualToConstant: 72),
+            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.52), preferredWidth
+        ])
         setAccessibilityElement(false)
     }
     required init?(coder: NSCoder) { nil }
     override var isFlipped: Bool { true }
     override func draw(_ dirtyRect: NSRect) {
+        NSGraphicsContext.saveGraphicsState()
+        defer { NSGraphicsContext.restoreGraphicsState() }
+        let fit = NSAffineTransform()
+        fit.scale(by: min(bounds.width / 100, bounds.height / 52))
+        fit.concat()
         if step == 0 {
             HomeStyle.piece(.orangeRicky, in: NSRect(x: 0, y: 14, width: 33, height: 24))
             HomeStyle.symbol("arrow.left.arrow.right", in: NSRect(x: 38, y: 17, width: 22, height: 18), color: HomeDashboardStyle.muted)
@@ -252,24 +271,25 @@ final class UtilityLessonArtwork: NSView {
 enum UtilityRulesContent {
     static func populate(_ page: UtilityPageView, mode: HomeGameMode) {
         page.removeSections()
-        let lessons = UtilityStyle.stack([], spacing: 0)
+        var lessons: [NSView] = []
         for step in 0..<3 {
             let number = UtilityStyle.label(String(format: "%02d", step + 1), size: 13, weight: .heavy, color: HomeDashboardStyle.cyan)
             number.widthAnchor.constraint(equalToConstant: 25).isActive = true
-            let copy = UtilityStyle.stack([
-                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold),
-                UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeDashboardStyle.muted)
-            ], spacing: 5)
-            let row = UtilityStyle.stack([number, copy, UtilityLessonArtwork(step: step)], vertical: false, spacing: 12)
-            copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
-            lessons.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: lessons)
-            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
+            let title = UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).title"), size: 15, weight: .bold)
+            title.setContentHuggingPriority(.defaultLow, for: .horizontal)
+            let heading = UtilityStyle.stack([number, title, UtilityLessonArtwork(step: step)], vertical: false, spacing: 9)
+            let body = UtilityStyle.label(UtilityStyle.text("utility.lesson.\(step).body"), size: 12, color: HomeDashboardStyle.muted)
+            // 标题和说明各自沿边框排版。说明使用整个横截面，插图不会挤占文案宽度。
+            heading.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
+            body.heightAnchor.constraint(greaterThanOrEqualToConstant: 25).isActive = true
+            lessons += [heading, body]
             if step < 2 {
                 let divider = NSBox(); divider.boxType = .separator
-                lessons.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: lessons)
+                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
+                lessons.append(divider)
             }
         }
-        page.addSection(UtilityCard(lessons, padding: 18))
+        page.addSection(UtilityCard(rows: lessons, padding: 14, spacing: 7))
         page.addSection(UtilityStyle.label(UtilityStyle.text("utility.rules.modes"), size: 14, weight: .bold))
         let modes = UtilityStyle.stack([], spacing: 10)
         for candidate in HomeGameMode.allCases {
@@ -296,10 +316,9 @@ enum UtilityRulesContent {
     }
 }
 
-/// 数字为视觉中心，并明确当前榜单的固定规则。
-final class UtilityRecordBestView: NSView {
-    init(mode: ModeRecordKey, entry: ModeRecord?) {
-        super.init(frame: .zero)
+enum UtilityRecordContent {
+    /// 数字为视觉中心，并明确当前榜单的固定规则。
+    static func best(mode: ModeRecordKey, entry: ModeRecord?) -> NSView {
         let metric = entry.map { String($0.clearedCount) } ?? "—"
         let value = UtilityStyle.label(metric, size: 38, weight: .heavy, color: HomeDashboardStyle.yellow, monospacedDigits: true)
         let unit = UtilityStyle.label(UtilityStyle.text("utility.unit.tiles"), size: 13, weight: .semibold, color: HomeDashboardStyle.muted)
@@ -311,39 +330,29 @@ final class UtilityRecordBestView: NSView {
         let icon = UtilityStyle.icon(mode == .timed ? HomeGameMode.timed.symbol : HomeGameMode.moves.symbol, color: HomeDashboardStyle.yellow, size: 56)
         let row = UtilityStyle.stack([copy, icon], vertical: false, spacing: 16)
         copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
-        row.translatesAutoresizingMaskIntoConstraints = false; addSubview(row)
-        NSLayoutConstraint.activate([
-            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
-            row.topAnchor.constraint(equalTo: topAnchor, constant: 18), row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
-        ])
+        return UtilityCard(row, accent: HomeDashboardStyle.yellow, padding: 18)
     }
-    required init?(coder: NSCoder) { nil }
-    override var isFlipped: Bool { true }
-    override func draw(_ dirtyRect: NSRect) {
-        UtilityStyle.drawCard(bounds, accent: HomeDashboardStyle.yellow, containsContent: true)
-    }
-}
 
-enum UtilityRecordContent {
-    /// 独立列宽确保日期不会因分数位数改变而错位。
+    /// 日期按行宽分配，窄窗仍给名次和消除数量预留位置。
     static func table(mode: ModeRecordKey, entries: [ModeRecord]) -> NSView {
-        let rows = UtilityStyle.stack([], spacing: 0)
+        var rows: [NSView] = []
         let headings = UtilityStyle.stack([
             UtilityStyle.label(UtilityStyle.text("utility.records.rank"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
             UtilityStyle.label(UtilityStyle.text("utility.records.result"), size: 10, weight: .semibold, color: HomeDashboardStyle.muted),
             UtilityStyle.label(UtilityStyle.text("utility.records.date"), size: 10, weight: .semibold,
                                color: HomeDashboardStyle.muted, alignment: .right)
-        ], vertical: false, spacing: 12)
+        ], vertical: false, spacing: 8)
         headings.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 36).isActive = true
-        headings.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 135).isActive = true
+        headings.arrangedSubviews[2].widthAnchor.constraint(equalTo: headings.widthAnchor, multiplier: 0.43).isActive = true
         headings.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
-        rows.addArrangedSubview(headings); UtilityStyle.fillWidth(headings, in: rows)
+        rows.append(headings)
         headings.heightAnchor.constraint(equalToConstant: 30).isActive = true
         let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
         let ranks = ModeRecordStore.ranks(for: entries)
         for (index, entry) in entries.enumerated() {
             let divider = NSBox(); divider.boxType = .separator
-            rows.addArrangedSubview(divider); UtilityStyle.fillWidth(divider, in: rows)
+            divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
+            rows.append(divider)
             let rank = UtilityRankView(rank: ranks[index])
             rank.translatesAutoresizingMaskIntoConstraints = false
             NSLayoutConstraint.activate([rank.widthAnchor.constraint(equalToConstant: 36), rank.heightAnchor.constraint(equalToConstant: 30)])
@@ -352,10 +361,10 @@ enum UtilityRecordContent {
             countLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
             let date = UtilityStyle.label(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)), size: 11,
                                           color: HomeDashboardStyle.muted, alignment: .right)
-            date.widthAnchor.constraint(equalToConstant: 135).isActive = true
-            let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 12)
-            rows.addArrangedSubview(row); UtilityStyle.fillWidth(row, in: rows)
-            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
+            let row = UtilityStyle.stack([rank, countLabel, date], vertical: false, spacing: 8)
+            date.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.43).isActive = true
+            rows.append(row)
+            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
             row.setAccessibilityLabel("\(ranks[index]). \(metric), \(date.stringValue)")
         }
         if entries.isEmpty {
@@ -366,24 +375,23 @@ enum UtilityRecordContent {
                                    alignment: .center)
             ], spacing: 12)
             empty.alignment = .centerX
-            rows.addArrangedSubview(empty); UtilityStyle.fillWidth(empty, in: rows)
+            rows.append(empty)
             empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
         }
-        return UtilityCard(rows, padding: 16)
+        return UtilityCard(rows: rows, padding: 16)
     }
 
     static func legacyTable(_ section: LegacyRecordSection) -> NSView {
-        let stack = UtilityStyle.stack([], spacing: 8)
         let title = AchievementText.format(section.kind == .scoreAttack ? "utility.records.legacy_score" : "utility.records.legacy_speed", section.ruleValue)
         let heading = UtilityStyle.label(title, size: 13, weight: .bold)
-        stack.addArrangedSubview(heading); UtilityStyle.fillWidth(heading, in: stack)
+        var rows: [NSView] = [heading]
         let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
         for (index, record) in section.entries.enumerated() {
             let metric = section.kind == .scoreAttack ? AchievementText.format("records.metric.score", record.score) : String(format: "%.2f s", record.elapsedTime)
             let label = UtilityStyle.label("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: record.createdAt)))", size: 12, color: HomeDashboardStyle.muted)
-            stack.addArrangedSubview(label); UtilityStyle.fillWidth(label, in: stack)
+            rows.append(label)
         }
-        return UtilityCard(stack, padding: 16)
+        return UtilityCard(rows: rows, padding: 16, spacing: 8)
     }
 }
 
diff --git a/Tests/HomeUtilityPanelTests.swift b/Tests/HomeUtilityPanelTests.swift
index 788ca396e516b1302ec6522e67b265d2e097856a..67b0b262f619709de09cf49afd050366656d42f3 100644
--- a/Tests/HomeUtilityPanelTests.swift
+++ b/Tests/HomeUtilityPanelTests.swift
@@ -152,6 +152,7 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         let store = try recordStore()
         for language in AppLanguage.allCases {
             Localizer.shared.setLanguage(language)
+            let lessonBodies = Set((0..<3).map { AchievementText.string("utility.lesson.\($0).body") })
             for page in ["settings", "rules", "records"] {
                 let panel = HomeUtilityPanel(page: page, store: store)
                 defer { panel.close() }
@@ -161,19 +162,34 @@ final class HomeUtilityPanelTests: AchievementTestCase {
                 let originalSize = content.bounds.size
                 for size in [originalSize, NSSize(width: 480, height: 420)] {
                     window.setContentSize(size); content.layoutSubtreeIfNeeded()
+                    XCTAssertEqual(content.bounds.width, size.width, accuracy: 1)
                     XCTAssertFalse(labels(content).contains { $0.hasPrefix("utility.") })
                     XCTAssertGreaterThan(content.document.bounds.height, 100)
                     XCTAssertLessThanOrEqual(content.document.frame.width, content.scroll.contentView.bounds.width + 1)
                     XCTAssertEqual(content.scroll.contentView.bounds.minY, 0, accuracy: 1, "初次打开应从顶部显示")
-                    for card in descendants(content).compactMap({ $0 as? UtilityCard }) {
+                    let cards = descendants(content).compactMap { $0 as? UtilityCard }
+                    XCTAssertFalse(cards.isEmpty)
+                    for card in cards {
                         XCTAssertGreaterThan(card.frame.height, 20)
                         XCTAssertGreaterThan(card.frame.width, 200)
                         for label in descendants(card).compactMap({ $0 as? NSTextField }) {
                             let rect = card.convert(label.bounds, from: label)
-                            XCTAssertGreaterThanOrEqual(rect.minX, -1, "\(language): \(label.stringValue)")
-                            XCTAssertLessThanOrEqual(rect.maxX, card.bounds.maxX + 1, "\(language): \(label.stringValue)")
+                            // 用矩形顶边检查缩进最深的左侧，用底边检查收窄最深的右侧。
+                            let left = card.bounds.minX + 0.45 * (card.bounds.maxY - rect.minY)
+                            let right = card.bounds.maxX - 0.45 * (rect.maxY - card.bounds.minY)
+                            XCTAssertGreaterThanOrEqual(rect.minX, left - 1, "\(page) / \(language): \(label.stringValue)")
+                            XCTAssertLessThanOrEqual(rect.maxX, right + 1, "\(page) / \(language): \(label.stringValue)")
+                            if page == "rules", lessonBodies.contains(label.stringValue) {
+                                let textBounds = label.attributedStringValue.boundingRect(
+                                    with: NSSize(width: max(1, rect.width - 4), height: .greatestFiniteMagnitude),
+                                    options: [.usesLineFragmentOrigin, .usesFontLeading])
+                                XCTAssertGreaterThanOrEqual(rect.height + 2, ceil(textBounds.height), label.stringValue)
+                            }
                         }
                     }
+                    if page == "rules", language == .chineseSimplified || language == .russian {
+                        for card in cards { try assertFullLengthSlantedEdges(of: card) }
+                    }
                     if language == .russian, size.width == 480 { try export(content, name: "utility-\(page)-compact-ru") }
                 }
                 if language == .chineseSimplified {
@@ -214,6 +230,33 @@ final class HomeUtilityPanelTests: AchievementTestCase {
         XCTAssertEqual(content.scroll.contentView.bounds.origin, position)
     }
 
+    private func assertFullLengthSlantedEdges(of card: UtilityCard) throws {
+        let scale: CGFloat = 2
+        let bitmap = try XCTUnwrap(NSBitmapImageRep(
+            bitmapDataPlanes: nil, pixelsWide: Int(ceil(card.bounds.width * scale)),
+            pixelsHigh: Int(ceil(card.bounds.height * scale)), bitsPerSample: 8, samplesPerPixel: 4,
+            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
+        ))
+        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)).cgContext
+        context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
+        context.scaleBy(x: scale, y: -scale)
+        let previous = NSGraphicsContext.current
+        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
+        defer { NSGraphicsContext.current = previous }
+        // 单独渲染卡片边框，避免滚动区或文案干扰透明轮廓采样。
+        card.draw(card.bounds)
+        for fraction: CGFloat in [0.12, 0.36, 0.64, 0.88] {
+            let row = Int(card.bounds.height * fraction * scale)
+            let y = (CGFloat(row) + 0.5) / scale
+            let pixels = 0..<bitmap.pixelsWide
+            let isOpaque: (Int) -> Bool = { (bitmap.colorAt(x: $0, y: row)?.alphaComponent ?? 0) > 0.85 }
+            let left = try XCTUnwrap(pixels.first(where: isOpaque))
+            let right = try XCTUnwrap(pixels.last(where: isOpaque))
+            XCTAssertEqual(CGFloat(left) / scale, (card.bounds.height - y) * 0.45, accuracy: 1.25, "左边应从顶到底连续倾斜")
+            XCTAssertEqual(CGFloat(right) / scale, card.bounds.width - y * 0.45, accuracy: 1.25, "右边应从顶到底连续倾斜")
+        }
+    }
+
     private func export(_ view: NSView, name: String) throws {
         view.layoutSubtreeIfNeeded()
         let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
```
