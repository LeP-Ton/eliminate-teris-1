# 首页双栏、成就滚动与联系我们

## 背景与目标

会话-196 起，将首页分为左右两栏。开始按钮与右栏模式卡底边对齐，成就之路移入左栏，右栏新增联系我们卡片。

## 实施结果

- [x] 开局区固定在左栏上方。按钮与模式卡的底边使用同一布局坐标，静止时黄色按钮的立体底边也与卡片对齐。
- [x] 成就区保留进度和查看全部入口。徽章按左栏宽度分列，使用原生纵向滚动浏览全部 32 枚。游戏状态刷新时保持滚动位置与徽章详情入口。
- [x] 联系卡与模式卡等宽，间距 24 点，高 156 点，沿用旧统计卡的高度。使用仓库已有的 GitHub Issues（问题反馈页）作为反馈渠道。
- [x] 五种语言均可显示反馈入口。紧凑窗口按可用高度调整自由模式主标题字级，给副标题留出独立排版空间。
- [x] 更新实际渲染预览与项目索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 通过 88 项测试，0 失败。
- 自动验证 960×720 到 1920×1250 下的两栏边界、按钮底边、联系卡尺寸、徽章列数与标题间距。验证滚动到第 32 枚成就后可打开详情，刷新时维持位置。
- 按钮测试拦截打开链接的动作，核对反馈地址。使用 `./run.sh` 可以手工切换模式、缩放窗口、在左栏滚动成就，并点击联系我们中的反馈按钮。
- [待机首页预览](../../docs/previews/lobby-idle.png)。
- [大窗口双栏预览](../../docs/previews/achievement-grid.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122151441-split-lobby-achievements-and-contact.md` - 会话-196 起将大厅分成双栏，固定开局按钮与模式卡底边，左栏成就可滚动，右栏新增反馈卡。含完整增量 diff、预览和回归结果。
@@ -94,0 +96 @@
+- 需要调整当前首页双栏、开始按钮对齐、左栏成就滚动或右栏联系我们卡片时，读取 `20261122151441-split-lobby-achievements-and-contact.md`。
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -6,0 +7,3 @@
+
+## 2026-11-22（首页双栏布局）
+- `HomeDashboardView` 管理固定的开局区和右侧信息栏。`HomeAchievementPathView` 负责左栏成就进度与原生纵向滚动网格，挑战卡转场仍由 `HomeModeHeaderView` 独立绘制。
```

### `Sources/GameLobbyStyle.swift`

```diff
--- a/Sources/GameLobbyStyle.swift
+++ b/Sources/GameLobbyStyle.swift
@@ -47 +47,2 @@
-        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: press * 2 - hover)
+        // 静止时按钮的立体底边贴齐控件底边，与右侧卡片共用一条基线。
+        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: 2 + press * 2 - hover)
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -147,2 +147,21 @@
-    var definition: AchievementDefinition?
-    var unlocked = false
+    private(set) var definition: AchievementDefinition?
+    private var unlocked = false
+    private var displayedLanguage: AppLanguage?
+    private var displayedProgress: Double?
+
+    func refresh(_ definition: AchievementDefinition, manager: AchievementsManager) {
+        let language = Localizer.shared.language
+        let unlocked = manager.isUnlocked(id: definition.id)
+        let progress = manager.progress(for: definition).current
+        // 计时刷新只更新变化的标签，避免重复格式化整个滚动列表。
+        guard self.definition?.id != definition.id || self.unlocked != unlocked ||
+              displayedLanguage != language || displayedProgress != progress else { return }
+        self.definition = definition
+        self.unlocked = unlocked
+        displayedLanguage = language
+        displayedProgress = progress
+        toolTip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
+        setAccessibilityLabel(AchievementText.title(definition, manager: manager))
+        needsDisplay = true
+    }
+
@@ -219,0 +239,94 @@
+private final class HomeAchievementDocumentView: NSView {
+    override var isFlipped: Bool { true }
+}
+
+/// 成就标题和进度固定在左栏，完整的徽章网格由原生滚动视图裁剪和滚动。
+final class HomeAchievementPathView: NSView {
+    let scroll = NSScrollView()
+    var onAchievement: ((Int?) -> Void)?
+    private let document = HomeAchievementDocumentView(frame: .zero)
+    private let all = HomeButton(frame: .zero)
+    private var badges: [HomeAchievementButton] = []
+    private var unlockedCount = 0
+
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        scroll.drawsBackground = false
+        scroll.borderType = .noBorder
+        scroll.scrollerStyle = .overlay
+        scroll.hasVerticalScroller = true
+        scroll.autohidesScrollers = true
+        scroll.horizontalScrollElasticity = .none
+        scroll.documentView = document
+        addSubview(scroll)
+        addSubview(all)
+        all.onClick = { [weak self] in self?.onAchievement?(nil) }
+        for _ in AchievementDefinition.all {
+            let badge = HomeAchievementButton(frame: .zero)
+            badge.onClick = { [weak self, weak badge] in
+                guard let id = badge?.definition?.id else { return }
+                self?.onAchievement?(id)
+            }
+            document.addSubview(badge)
+            badges.append(badge)
+        }
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    func refresh(manager: AchievementsManager) {
+        all.title = AchievementText.string("achievement.view_all") + "  →"
+        let unlocked = Set(manager.unlockedIDs())
+        unlockedCount = unlocked.count
+        let definitions = AchievementDefinition.all.sorted {
+            let a = unlocked.contains($0.id), b = unlocked.contains($1.id)
+            return a == b ? $0.id < $1.id : a
+        }
+        for (badge, definition) in zip(badges, definitions) { badge.refresh(definition, manager: manager) }
+        needsDisplay = true
+    }
+
+    override func layout() {
+        super.layout()
+        all.frame = NSRect(x: max(0, bounds.width - 120), y: 8, width: 120, height: 28)
+        scroll.frame = NSRect(x: 0, y: 65, width: bounds.width, height: max(0, bounds.height - 65))
+        let width = max(0, scroll.contentSize.width - 12)
+        let gap: CGFloat = 12, height: CGFloat = 54
+        let columns = max(1, min(badges.count, Int((width + gap) / (166 + gap))))
+        let rows = (badges.count + columns - 1) / columns
+        let badgeWidth = max(0, width - CGFloat(columns - 1) * gap) / CGFloat(columns)
+        document.frame.size = NSSize(width: scroll.contentSize.width, height: CGFloat(rows) * (height + gap) + 2)
+        for (index, badge) in badges.enumerated() {
+            badge.frame = NSRect(x: CGFloat(index % columns) * (badgeWidth + gap),
+                                 y: 2 + CGFloat(index / columns) * (height + gap), width: badgeWidth, height: height)
+        }
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.border.withAlphaComponent(0.7).setStroke()
+        let line = NSBezierPath()
+        line.move(to: NSPoint(x: 0, y: 0.5))
+        line.line(to: NSPoint(x: bounds.maxX, y: 0.5))
+        line.stroke()
+
+        let title = AchievementText.string("home.achievement_path")
+        HomeStyle.text(title, in: NSRect(x: 0, y: 9, width: bounds.width - 126, height: 28), size: 21, weight: .heavy)
+        let count = AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count)
+        let countWidth = ceil((count as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]).width)
+        HomeStyle.text(count, in: NSRect(x: 0, y: 39, width: countWidth + 2, height: 19), size: 13, weight: .semibold)
+        let meterX = countWidth + 15
+        let meter = NSRect(x: meterX, y: 44, width: min(210, max(0, bounds.width - meterX - 56)), height: 9)
+        HomeStyle.border.setFill()
+        NSBezierPath(roundedRect: meter, xRadius: 5, yRadius: 5).fill()
+        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
+        if ratio > 0 {
+            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
+                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 5)
+        }
+        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: 39, width: 50, height: 19),
+                       size: 11, color: HomeStyle.secondary)
+    }
+}
+
@@ -227,0 +341,2 @@
+    let achievementPath = HomeAchievementPathView(frame: .zero)
+    let contactPanel = HomeContactPanelView(frame: .zero)
@@ -232 +346,0 @@
-    private let all = HomeButton(frame: .zero)
@@ -234,7 +347,0 @@
-    private var badges: [HomeAchievementButton] = []
-    private var orderedAchievements: [AchievementDefinition] = []
-    private var achievementManager: AchievementsManager?
-    private var unlockedCount = 0
-    private static let achievementGap: CGFloat = 24
-    private static let badgeGap: CGFloat = 12
-    private static let badgeHeight: CGFloat = 54
@@ -243 +349,0 @@
-    private var singleRowTop: CGFloat { bounds.height - 144 }
@@ -246,14 +352,2 @@
-        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: min(496, singleRowTop - 120))
-    }
-
-    private func achievementGrid(below panel: NSRect) -> (top: CGFloat, columns: Int, count: Int, badgeWidth: CGFloat) {
-        let availableWidth = max(0, bounds.width - margin * 2)
-        let gap = Self.badgeGap
-        let total = AchievementDefinition.all.count
-        let columns = min(total, max(5, Int((availableWidth + gap) / (174 + gap))))
-        let rowStride = Self.badgeHeight + gap
-        // 以底部的一行作为基准，只有上方还有完整行高和安全间距时才添加一行。
-        let extraHeight = max(0, singleRowTop - panel.maxY - Self.achievementGap)
-        let rows = min((total + columns - 1) / columns, 1 + Int(extraHeight / rowStride))
-        let width = max(0, availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
-        return (singleRowTop - CGFloat(rows - 1) * rowStride, columns, min(total, rows * columns), width)
+        let height = min(456, max(396, (bounds.height * 0.56).rounded(.down)))
+        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: height)
@@ -272 +366 @@
-        [hint, hero, modeHeader, modePanel, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        [hint, hero, modeHeader, modePanel, startButton, achievementPath, contactPanel, records, rules, settings].forEach { addSubview($0) }
@@ -278 +372 @@
-        all.onClick = { [weak self] in self?.onAchievement?(nil) }
+        achievementPath.onAchievement = { [weak self] id in self?.onAchievement?(id) }
@@ -287,5 +380,0 @@
-        for _ in AchievementDefinition.all {
-            let button = HomeAchievementButton(frame: .zero)
-            button.onClick = { [weak self, weak button] in self?.onAchievement?(button?.definition?.id) }
-            addSubview(button); badges.append(button)
-        }
@@ -308 +397,2 @@
-        all.title = AchievementText.string("achievement.view_all") + "  →"
+        achievementPath.refresh(manager: manager)
+        contactPanel.refreshLanguage()
@@ -311,6 +400,0 @@
-        unlockedCount = manager.unlockedIDs().count
-        achievementManager = manager
-        orderedAchievements = AchievementDefinition.all.sorted {
-            let a = manager.isUnlocked(id: $0.id), b = manager.isUnlocked(id: $1.id)
-            return a == b ? $0.id < $1.id : a
-        }
@@ -318 +402 @@
-        [startButton, records, rules, settings, all].forEach { $0.needsDisplay = true }
+        [startButton, records, rules, settings].forEach { $0.needsDisplay = true }
@@ -324 +407,0 @@
-        let grid = achievementGrid(below: panel)
@@ -327,3 +410 @@
-        // 左侧开局区始终在成就标题之上，也不随超高窗口把插图和按钮拉得过远。
-        let bodyBottom = min(grid.top, panel.maxY + 64)
-        let bodyHeight = bodyBottom - top - 24
+        let bodyHeight = panel.height
@@ -333 +414,2 @@
-        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: bodyBottom - 89, width: 294, height: 62)
+        // 开局按钮随模式卡片定位，左栏滚动时两者保持底边对齐。
+        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: panel.maxY - 62, width: 294, height: 62)
@@ -336 +418,5 @@
-        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.45, width: leftWidth - 24, height: 138)
+        let heroY = min(top + bodyHeight * 0.43, hint.frame.minY - 150)
+        hero.frame = NSRect(x: margin + 12, y: heroY, width: leftWidth - 24, height: 138)
+        let lowerTop = panel.maxY + 24
+        achievementPath.frame = NSRect(x: margin, y: lowerTop, width: leftWidth, height: max(0, bounds.height - lowerTop - 20))
+        contactPanel.frame = NSRect(x: panel.minX, y: lowerTop, width: panel.width, height: 156)
@@ -349,18 +434,0 @@
-        all.frame = NSRect(x: bounds.width - margin - 120, y: grid.top + 8, width: 120, height: 32)
-        for (index, badge) in badges.enumerated() {
-            badge.isHidden = index >= min(grid.count, orderedAchievements.count)
-            guard !badge.isHidden, let manager = achievementManager else { continue }
-            // 仅为当前可见的标签格式化进度，改变窗口大小后再填充新露出的行。
-            let definition = orderedAchievements[index]
-            badge.definition = definition
-            badge.unlocked = manager.isUnlocked(id: definition.id)
-            let tooltip = AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
-            if badge.toolTip != tooltip { badge.toolTip = tooltip }
-            badge.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
-            badge.needsDisplay = true
-            let column = CGFloat(index % grid.columns)
-            let row = CGFloat(index / grid.columns)
-            badge.frame = NSRect(x: margin + column * (grid.badgeWidth + Self.badgeGap),
-                                 y: grid.top + 52 + row * (Self.badgeHeight + Self.badgeGap),
-                                 width: grid.badgeWidth, height: Self.badgeHeight)
-        }
@@ -372 +439,0 @@
-        let footerY = achievementGrid(below: panel).top
@@ -376 +443 @@
-        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), footerY - 60, HomeStyle.yellow)] {
+        for (x, y, color) in [(bounds.width * 0.42, CGFloat(166), HomeStyle.yellow), (bounds.width * 0.57, CGFloat(138), HomeStyle.blue), (CGFloat(48), panel.maxY - 40, HomeStyle.yellow)] {
@@ -386,15 +453,4 @@
-        for y in [CGFloat(70), footerY] {
-            let line = NSBezierPath(); line.move(to: NSPoint(x: y == 70 ? 0 : margin, y: y)); line.line(to: NSPoint(x: y == 70 ? bounds.width : bounds.width - margin, y: y)); line.stroke()
-        }
-        let achievementTitle = AchievementText.string("home.achievement_path")
-        let achievementSize = GameLobbyStyle.fittedSize(achievementTitle, width: 140, preferred: 21, minimum: 13, weight: .bold)
-        HomeStyle.text(achievementTitle, in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: achievementSize, weight: .bold)
-        HomeStyle.text(AchievementText.format("home.unlocked_count", unlockedCount, AchievementDefinition.all.count), in: NSRect(x: margin + 145, y: footerY + 20, width: 140, height: 23), size: 14, weight: .semibold)
-        let meter = NSRect(x: margin + 292, y: footerY + 23, width: min(230, max(100, bounds.width - 850)), height: 12)
-        NSColor(calibratedWhite: 0.9, alpha: 1).setFill(); NSBezierPath(roundedRect: meter, xRadius: 6, yRadius: 6).fill()
-        let ratio = CGFloat(unlockedCount) / CGFloat(AchievementDefinition.all.count)
-        if ratio > 0 {
-            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
-                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 6)
-        }
-        HomeStyle.text(String(format: "%.1f%%", Double(ratio * 100)), in: NSRect(x: meter.maxX + 10, y: footerY + 20, width: 60, height: 22), size: 11, color: HomeStyle.secondary)
+        let line = NSBezierPath()
+        line.move(to: NSPoint(x: 0, y: 70))
+        line.line(to: NSPoint(x: bounds.maxX, y: 70))
+        line.stroke()
@@ -422,0 +479,51 @@
+
+/// 联系卡沿用右栏的暖白材质，反馈按钮打开项目的问题跟踪页。
+final class HomeContactPanelView: NSView {
+    private static let feedbackURL = URL(string: "https://github.com/LeP-Ton/eliminate-teris-1/issues")!
+    private let feedback = HomeButton(frame: .zero)
+    var openURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }
+
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        feedback.symbolName = "arrow.up.right"
+        feedback.setAccessibilityRole(.link)
+        feedback.onClick = { [weak self] in self?.openURL(Self.feedbackURL) }
+        addSubview(feedback)
+        refreshLanguage()
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    func refreshLanguage() {
+        let title = AchievementText.string("home.contact.action")
+        guard feedback.title != title else { return }
+        feedback.title = title
+        feedback.setAccessibilityLabel(title)
+        needsLayout = true
+        needsDisplay = true
+    }
+
+    override func layout() {
+        super.layout()
+        let titleWidth = (feedback.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width
+        let width = min(max(0, bounds.width - 44), ceil(titleWidth) + 56)
+        feedback.frame = NSRect(x: 22, y: bounds.height - 56, width: width, height: 34)
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        GameLobbyStyle.surface(bounds, radius: 20,
+                               tint: NSColor(calibratedRed: 0.98, green: 0.989, blue: 1, alpha: 1), strength: 0.035)
+        let icon = NSRect(x: 22, y: 18, width: 46, height: 46)
+        GameLobbyStyle.gradient(icon, colors: [NSColor(calibratedRed: 0.94, green: 0.99, blue: 1, alpha: 1),
+                                                NSColor(calibratedRed: 0.82, green: 0.94, blue: 1, alpha: 1)], radius: 13)
+        HomeStyle.symbol("ellipsis.bubble.fill", in: icon.insetBy(dx: 10, dy: 10), color: HomeStyle.blue)
+        HomeStyle.text(AchievementText.string("home.contact.title"),
+                       in: NSRect(x: 81, y: 24, width: bounds.width - 103, height: 34), size: 21, weight: .heavy)
+        GameLobbyStyle.wrappedText(AchievementText.string("home.contact.description"),
+                                   in: NSRect(x: 22, y: 72, width: bounds.width - 44, height: 25), size: 13, color: HomeStyle.secondary)
+        HomeStyle.card(feedback.frame, fill: HomeStyle.blue.withAlphaComponent(0.08),
+                       border: HomeStyle.blue.withAlphaComponent(0.12), radius: 8)
+    }
+}
```

### `Sources/HomeModeHeaderView.swift`

```diff
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -250 +250,16 @@
-        heading.font = .systemFont(ofSize: min(60, max(44, bounds.width * 0.092)), weight: .heavy)
+        let headingY: CGFloat = 20
+        let subtitleY = max(headingY, bounds.height - 42)
+        let headingHeight = max(0, subtitleY - headingY - 8)
+        let textWidth = max(0, bounds.width - 4)
+        var fontSize = min(60, max(44, bounds.width * 0.092))
+        // 先给副标题留出独立区域，再按语言和窗口宽高调整主标题字级。
+        while fontSize > 32 {
+            let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
+            let textSize = (heading.stringValue as NSString).boundingRect(
+                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
+                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]
+            )
+            if ceil(textSize.height) + 4 <= headingHeight { break }
+            fontSize -= 1
+        }
+        heading.font = .systemFont(ofSize: fontSize, weight: .heavy)
@@ -253,3 +268,2 @@
-        let subtitleY = bounds.height - 56
-        heading.frame = NSRect(x: 0, y: 26, width: bounds.width, height: max(0, subtitleY - 4))
-        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: 56)
+        heading.frame = NSRect(x: 0, y: headingY, width: bounds.width, height: headingHeight)
+        subtitle.frame = NSRect(x: 0, y: subtitleY, width: bounds.width, height: 42)
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -200,0 +201,3 @@
+"home.contact.title" = "Contact us";
+"home.contact.description" = "Report a bug or suggest an improvement.";
+"home.contact.action" = "Give feedback on GitHub";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -193,0 +194,3 @@
+"home.contact.title" = "お問い合わせ";
+"home.contact.description" = "不具合の報告やご提案をお寄せください。";
+"home.contact.action" = "GitHubでフィードバック";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -193,0 +194,3 @@
+"home.contact.title" = "문의하기";
+"home.contact.description" = "오류를 신고하거나 개선 의견을 남겨 주세요.";
+"home.contact.action" = "GitHub에 의견 남기기";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -193,0 +194,3 @@
+"home.contact.title" = "Связаться с нами";
+"home.contact.description" = "Сообщите об ошибке или поделитесь идеей.";
+"home.contact.action" = "Оставить отзыв на GitHub";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -200,0 +201,3 @@
+"home.contact.title" = "联系我们";
+"home.contact.description" = "欢迎报告问题或分享玩法建议。";
+"home.contact.action" = "在 GitHub 反馈";
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -121,0 +122,2 @@
+        let scroll = home.achievementPath.scroll
+        let document = try XCTUnwrap(scroll.documentView)
@@ -126 +128 @@
-            let button = try XCTUnwrap(home.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
+            let button = try XCTUnwrap(document.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
@@ -130 +132 @@
-        let strip = NSRect(x: 44, y: 708, width: 1092, height: 54)
+        let strip = document.convert(NSRect(x: 0, y: 2, width: document.bounds.width - 12, height: 54), to: home)
@@ -152,2 +154,4 @@
-                    let badges = home.subviews.compactMap { $0 as? HomeButton }.filter { !$0.isHidden && $0.toolTip != nil }
-                    XCTAssertGreaterThanOrEqual(badges.count, 5)
+                    let scroll = home.achievementPath.scroll
+                    let document = try XCTUnwrap(scroll.documentView)
+                    let badges = document.subviews.compactMap { $0 as? HomeButton }
+                    XCTAssertEqual(badges.count, AchievementDefinition.all.count)
@@ -188 +192,3 @@
-                        let strip = try XCTUnwrap(badges.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
+                        let visible = badges.filter { scroll.documentVisibleRect.contains($0.frame) }
+                        let rect = try XCTUnwrap(visible.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
+                        let strip = document.convert(rect, to: home)
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -79,0 +80,7 @@
+                        if !running, mode == .free {
+                            let intro = try XCTUnwrap(home.modeHeader.subviews.first { !$0.isHidden })
+                            let labels = intro.subviews.compactMap { $0 as? NSTextField }.sorted { $0.frame.minY < $1.frame.minY }
+                            XCTAssertEqual(labels.count, 2)
+                            XCTAssertGreaterThanOrEqual(labels[1].frame.minY - labels[0].frame.maxY, 8,
+                                                        "主标题和副标题之间保留独立排版空间")
+                        }
```

### `Tests/HomeDashboardTests.swift`

```diff
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -120 +120 @@
-    func testAchievementGridGrowsByColumnAndRowAndRespectsModePanel() throws {
+    func testSplitDashboardKeepsActionAlignedWhileAchievementsScroll() throws {
@@ -131,3 +131,8 @@
-        for (width, height, columns, rows, count) in [(960, 720, 5, 1, 5), (1440, 720, 7, 1, 7),
-                                                       (960, 1000, 5, 4, 20), (1600, 1000, 8, 4, 32),
-                                                       (1920, 1250, 9, 4, 32), (960, 720, 5, 1, 5)] {
+        let scroll = home.achievementPath.scroll
+        let document = try XCTUnwrap(scroll.documentView)
+        let badges = document.subviews.compactMap { $0 as? HomeButton }
+        XCTAssertEqual(badges.count, AchievementDefinition.all.count)
+        XCTAssertTrue(scroll.hasVerticalScroller)
+        XCTAssertFalse(scroll.hasHorizontalScroller)
+        var compactVisibleCount = 0
+        for (width, height, columns) in [(960, 720, 3), (1440, 720, 4), (960, 1000, 3), (1600, 1000, 5), (1920, 1250, 7)] {
@@ -136,13 +141,17 @@
-            let buttons = home.subviews.compactMap { $0 as? HomeButton }
-            let badges = buttons.filter { !$0.isHidden && $0.toolTip != nil }
-            let groupedRows = Dictionary(grouping: badges) { $0.frame.minY }
-            XCTAssertEqual(badges.count, count, "\(width)×\(height)")
-            XCTAssertEqual(groupedRows.count, rows)
-            XCTAssertEqual(groupedRows.values.map(\.count).max(), columns)
-            XCTAssertTrue(badges.allSatisfy { home.bounds.contains($0.frame) })
-            let all = try XCTUnwrap(buttons.first { $0.title.hasPrefix(AchievementText.string("achievement.view_all")) })
-            let sectionTop = all.frame.minY - 8
-            let gap = sectionTop - home.modePanel.frame.maxY
-            XCTAssertGreaterThanOrEqual(gap, 24)
-            XCTAssertLessThan(home.startButton.frame.maxY, sectionTop)
-            if count < AchievementDefinition.all.count { XCTAssertLessThan(gap, 24 + 66) }
+            let mode = home.modePanel.frame
+            let path = home.achievementPath.frame
+            let contact = home.contactPanel.frame
+            XCTAssertEqual(home.startButton.frame.maxY, mode.maxY, accuracy: 0.1)
+            XCTAssertLessThan(path.maxX, mode.minX)
+            XCTAssertEqual(path.minY, mode.maxY + 24, accuracy: 0.1)
+            XCTAssertEqual(contact.minY, path.minY, accuracy: 0.1)
+            XCTAssertEqual(contact.minX, mode.minX, accuracy: 0.1)
+            XCTAssertEqual(contact.width, mode.width, accuracy: 0.1)
+            XCTAssertEqual(contact.height, 156)
+            XCTAssertTrue(home.bounds.contains(contact))
+            XCTAssertEqual(Dictionary(grouping: badges) { $0.frame.minY }.values.map(\.count).max(), columns)
+            XCTAssertTrue(badges.allSatisfy { document.bounds.contains($0.frame) })
+
+            let visibleCount = badges.filter { scroll.documentVisibleRect.contains($0.frame) }.count
+            if width == 960, height == 720 { compactVisibleCount = visibleCount }
+            if width == 960, height == 1000 { XCTAssertGreaterThan(visibleCount, compactVisibleCount) }
@@ -150,8 +158,0 @@
-                let description = AchievementText.string(AchievementDefinition.all[31].descriptionKey)
-                let last = try XCTUnwrap(badges.first { $0.toolTip?.hasPrefix(description) == true })
-                var detail: Int?
-                home.onAchievement = { detail = $0 }
-                last.performClick(nil)
-                XCTAssertEqual(detail, 32)
-                home.onAchievement = nil
-
@@ -163,0 +165,25 @@
+
+        home.setFrameSize(NSSize(width: 960, height: 720))
+        home.layoutSubtreeIfNeeded()
+        let last = try XCTUnwrap(badges.last)
+        XCTAssertFalse(scroll.documentVisibleRect.intersects(last.frame))
+        XCTAssertTrue(last.scrollToVisible(last.bounds))
+        XCTAssertTrue(scroll.documentVisibleRect.contains(last.frame))
+        let offset = scroll.documentVisibleRect.minY
+        home.refresh(snapshot: snapshot, mode: .moves, manager: progress)
+        home.layoutSubtreeIfNeeded()
+        XCTAssertEqual(scroll.documentVisibleRect.minY, offset, accuracy: 0.1)
+        XCTAssertEqual(home.startButton.frame.maxY, home.modePanel.frame.maxY, accuracy: 0.1)
+
+        var openedAchievements: [Int?] = []
+        home.onAchievement = { openedAchievements.append($0) }
+        last.performClick(nil)
+        let all = try XCTUnwrap(home.achievementPath.subviews.compactMap { $0 as? HomeButton }.first)
+        all.performClick(nil)
+        XCTAssertEqual(openedAchievements, [32, nil])
+        var feedbackURL: URL?
+        home.contactPanel.openURL = { feedbackURL = $0 }
+        let feedback = try XCTUnwrap(home.contactPanel.subviews.compactMap { $0 as? HomeButton }.first)
+        feedback.performClick(nil)
+        XCTAssertEqual(feedback.title, "在 GitHub 反馈")
+        XCTAssertEqual(feedbackURL?.absoluteString, "https://github.com/LeP-Ton/eliminate-teris-1/issues")
@@ -183,0 +210,3 @@
+                    let feedback = try XCTUnwrap(home.contactPanel.subviews.compactMap { $0 as? HomeButton }.first)
+                    XCTAssertEqual(feedback.title, AchievementText.string("home.contact.action"))
+                    XCTAssertTrue(home.contactPanel.bounds.contains(feedback.frame))
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -7 +7 @@
-- [待机首页](lobby-idle.png)展示模式文案和开局入口。自由模式下方是标注“玩法待定”的解谜卡片。
+- [待机首页](lobby-idle.png)展示双栏布局。左栏的开局按钮与右栏模式卡底边齐平，模式卡下方是联系我们卡片。
@@ -75 +75 @@
-- [大窗口成就网格](achievement-grid.png)展示模式面板与成就区的间距。窗口更宽时增加列，更高时增加整行，直到达到空间或 32 枚成就的上限。
+- [大窗口成就网格](achievement-grid.png)展示左栏的独立滚动区。窗口更宽时增加列，更高时可看到更多行，也可滚动查看全部 32 枚成就。
```

### `docs/previews/achievement-grid.png`

```diff
- 1898272 字节，SHA-256 558dbe6cc4d8a50194ba7497e96214cf0e4a6bb9dd6974c4977ef435752ba6c8
+ 1960675 字节，SHA-256 e03ded593b0e78c0796472ba9d2a521156a002573064348b3558e50910bd2e0c
```

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 561157 字节，SHA-256 3b453019619b679bb0d9aa46b781e2e5c38acfca10151f720b15e1e9c7942ae6
+ 556899 字节，SHA-256 c9ad852fc808d6ad129f55a746329253b1b7c3ce6a37da728aa64bad151a178f
```

### `docs/previews/achievement-labels.png`

```diff
- 104382 字节，SHA-256 eafc6fed3c59291f340743255dbb7904e1e56ea53abf2acbc63a3c4d813decfb
+ 66506 字节，SHA-256 cf28ab93f0f573ceb9ac33f5fc68b23bb6bd1c7b9ad19cd4ebf6d83088758801
```

### `docs/previews/challenge-moves.png`

```diff
- 1250386 字节，SHA-256 be39b0c028d6f51cc8ad47bccbc3959ec9fab8a4c162cd2d0f3f7282fc2aaebd
+ 1349055 字节，SHA-256 15b428416047185450cc31922fa159dc84cbefc0fbfefd2113a905c23fb12e65
```

### `docs/previews/challenge-preview.gif`

```diff
- 636889 字节，SHA-256 49a275f4a9658a499475a29015f8f3a6ce63319d38ea37226ec38d6fd98c324f
+ 605070 字节，SHA-256 e5f45ebe85ded344d9aba4e847ee5a1f97c54707fc53753b5e42337c7b27c404
```

### `docs/previews/challenge-timed.png`

```diff
- 1253544 字节，SHA-256 bcc058ffbc01912cc4692a3c7004762ea4fded1fd919467aa83b39393f083047
+ 1356364 字节，SHA-256 0e78569c0e982b834249519ee8632ecbc3de48f282d197bc696438548f0b449d
```

### `docs/previews/lobby-feedback.gif`

```diff
- 174037 字节，SHA-256 79a0edeea049a3a5aa99e9c4ae16df36f1c29ac0dc5fb156149a178198b00be4
+ 173274 字节，SHA-256 52b9bb63c890c0fd2dff959b6638281271c05c51668327e3418f543f07f06ee4
```

### `docs/previews/lobby-finished.png`

```diff
- 1245953 字节，SHA-256 936cd27ffa1e5272900d1386287dfc8edda1aad5f357c938a60d111efe950110
+ 1344425 字节，SHA-256 48f69469d39837dc56e46543c9938842cec6d56af699f31f5e09a863af3fd588
```

### `docs/previews/lobby-idle.png`

```diff
- 1112793 字节，SHA-256 a77a99280e377d6701f7cffd0fb00b47b813e28bd138014419a40f20654a57ae
+ 1201125 字节，SHA-256 7d38bb040bc5be344559c7d44902c21ffbbe0e71a8985b84161bd8e08ba8a727
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1270117 字节，SHA-256 f98b339b33ae301853f525644444cc8bca3fc6044903f03a0f3bfb8db32d91c2
+ 1368244 字节，SHA-256 7c0977cb85d324a92644f88d6b3229c35671ee0fbd1929ed638b4e71a1d2a420
```
