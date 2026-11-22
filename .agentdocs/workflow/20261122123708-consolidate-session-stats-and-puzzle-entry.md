# 合并左侧局内统计并预留解谜入口

## 背景与目标

- 会话-171 起根据主窗口截图优化局内面板。此前左侧的模式标题与右侧模式卡片重复，本局消除总数也在两侧分别显示。
- 在自由模式下方预留解谜模式的位置，玩法待后续设计。
- 本轮基于探索分支的 `d30728d`。

## 实施结果

- [x] 局内和结束状态在左侧使用一张统计卡。限时、限步展示剩余时间或次数和进度条，三个可玩模式均展示本局总数和橙、蓝、绿、红四类方块明细。
- [x] 移除右侧独立统计卡和开局后的重复模式标题、副标题。结束提示只显示本局状态，结果数字留在统计卡内。
- [x] 待机和开场动画期间保留对应的模式主文案，开场完成后切换到实时统计。
- [x] 统计面板从同一快照更新，长数字在固定列宽内缩小，鼠标提示和辅助功能标签可读取完整数值。
- [x] 右侧按自由、解谜、限时、限步排列。解谜卡使用紫色拼图图案并标注“玩法待定”，属于禁用的大厅占位入口，不传入游戏控制器。
- [x] 补齐中、英、日、韩、俄文案，更新实际界面预览和文档索引。

## 验证

| 场景 | 检查内容 | 结果 |
| --- | --- | --- |
| 局内及结束状态 | 一份总数和四类明细，局内无重复模式文案，结束提示无重复结果数字 | 通过 |
| 三种可玩模式 | 限时检查倒计时，限步检查剩余次数与结算，自由模式无预算 | 通过 |
| 解谜占位 | 位于自由下方，无法选中或改变待机和正在进行的游戏 | 通过 |
| 五语言布局 | 在 960×720、1180×800、1920×1080 渲染，检查统计与模式卡位置 | 通过 |

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 在 2026-11-22 12:43 完成，共 86 项通过，0 失败。
- 人工查看实际 AppKit 渲染图，确认限步与自由局内统计布局。检查 960×720 的俄语待机页，四张模式卡及说明均完整显示。
- `git diff --check` 通过。实机可运行 `./run.sh`，分别开始三种模式并消除方块，观察左侧总数与分类数据同步刷新。

## 预览

- [待机与解谜入口](../../docs/previews/lobby-idle.png)
- [限步局内](../../docs/previews/challenge-moves.png)与[限时局内](../../docs/previews/challenge-timed.png)
- [最后三次交换](../../docs/previews/lobby-last-moves.png)与[结束状态](../../docs/previews/lobby-finished.png)

## 完整增量 diff

文本按统一 diff 逐行记录，二进制预览记录字节数与 SHA-256。本文件不递归记录自身。

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index a7ef822..4f98a17 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122123708-consolidate-session-stats-and-puzzle-entry.md` - 会话-171 起合并左侧局内预算、消除总数和四类方块统计，移除重复文案，在自由模式下方加入玩法待定的解谜入口。含完整增量 diff、界面预览与回归结果。
@@ -88,0 +90 @@
+- 需要调整左侧局内统计、查看右栏四张模式卡片的布局，或确认解谜占位入口与可玩模式的边界时，读取 `20261122123708-consolidate-session-stats-and-puzzle-entry.md`。
```

### `Sources/GameModeArtwork.swift`

```diff
diff --git a/Sources/GameModeArtwork.swift b/Sources/GameModeArtwork.swift
index 353edae..623061e 100644
--- a/Sources/GameModeArtwork.swift
+++ b/Sources/GameModeArtwork.swift
@@ -26,0 +27,9 @@ enum GameModeArtwork {
+    /// 大厅预留入口用紫色拼图造型，与可玩的三种模式区分。
+    static func drawPuzzle(in bounds: NSRect) {
+        let face = bounds.insetBy(dx: bounds.width * 0.15, dy: bounds.height * 0.15)
+        let lavender = NSColor(calibratedRed: 0.54, green: 0.41, blue: 0.84, alpha: 1)
+        GameLobbyStyle.glow(face.insetBy(dx: -5, dy: -4), color: lavender.withAlphaComponent(0.16))
+        HomeStyle.symbol("puzzlepiece.fill", in: face.offsetBy(dx: 1, dy: 2), color: NSColor(calibratedRed: 0.37, green: 0.26, blue: 0.64, alpha: 1))
+        HomeStyle.symbol("puzzlepiece.fill", in: face, color: lavender)
+    }
+
```

### `Sources/HomeChallengeHUDView.swift`

```diff
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index f316e7d..087e8a8 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -3 +3 @@ import Cocoa
-/// 局内把行动预算置于插画上方；只消费快照，不参与计时、扣次或结束判定。
+/// 左侧局内面板从同一份快照展示剩余预算、消除总数和四类方块明细。
@@ -13,0 +14,3 @@ final class HomeChallengeHUDView: NSView {
+    private var showsBudget: Bool { mode != .free }
+    private var budgetLabelKey: String { mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left" }
+
@@ -15 +18 @@ final class HomeChallengeHUDView: NSView {
-        guard let snapshot else { return 1 }
+        guard showsBudget, let snapshot else { return 0 }
@@ -23 +26 @@ final class HomeChallengeHUDView: NSView {
-        guard let snapshot else { return "" }
+        guard showsBudget, let snapshot else { return "" }
@@ -31,2 +34,8 @@ final class HomeChallengeHUDView: NSView {
-        setAccessibilityLabel(AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
-            + ": " + budgetText + "; " + AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
+        var labels: [String] = []
+        if showsBudget { labels.append(AchievementText.string(budgetLabelKey) + ": " + budgetText) }
+        labels.append(AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
+        labels += PieceKind.allCases.map { kind in
+            AchievementText.string(kind.titleKey) + ": \(snapshot.clearedByKind[kind, default: 0])"
+        }
+        setAccessibilityLabel(labels.joined(separator: ", "))
+        toolTip = labels.joined(separator: "\n")
@@ -38,2 +47,2 @@ final class HomeChallengeHUDView: NSView {
-        let urgent = !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
-        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : HomeStyle.blue
+        let urgent = showsBudget && !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
+        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : mode == .moves ? HomeStyle.blue : GameLobbyStyle.teal
@@ -42,7 +51,33 @@ final class HomeChallengeHUDView: NSView {
-        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: face.width * 0.6, height: face.height), color: accent.withAlphaComponent(0.08))
-        let split = face.width * 0.57
-        let label = AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
-        HomeStyle.text(label, in: NSRect(x: 22, y: 17, width: split - 30, height: 20), size: 12, weight: .semibold, color: HomeStyle.secondary)
-        let budgetSize = GameLobbyStyle.fittedSize(budgetText, width: split - 32, preferred: 44, minimum: 25, weight: .heavy)
-        HomeStyle.text(budgetText, in: NSRect(x: 20, y: 36, width: split - 30, height: 58), size: budgetSize, weight: .heavy,
-                       color: urgent ? .systemRed : HomeStyle.ink)
+        // 数字区和方块明细共用列边界，避免长数字挤到相邻列。
+        let content = face.insetBy(dx: 20, dy: 18)
+        let budgetWidth = showsBudget ? content.width * 0.30 : 0
+        let totalWidth = content.width * (showsBudget ? 0.23 : 0.36)
+        let totalX = content.minX + budgetWidth
+        let breakdownX = totalX + totalWidth
+        let metricTop = content.minY + (showsBudget ? 4 : 16)
+        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: budgetWidth + totalWidth, height: face.height),
+                            color: accent.withAlphaComponent(0.08))
+        if showsBudget {
+            drawMetric(budgetText, label: budgetLabelKey, x: content.minX, y: metricTop,
+                       width: budgetWidth - 17, color: urgent ? .systemRed : HomeStyle.ink)
+            drawDivider(at: totalX - 9, from: metricTop, to: metricTop + 76)
+        }
+        drawMetric(String(snapshot.totalCleared), label: "home.cleared_title", x: totalX, y: metricTop,
+                   width: totalWidth - 17, color: HomeStyle.ink)
+        drawDivider(at: breakdownX - 9, from: metricTop, to: metricTop + 76)
+        drawBreakdown(snapshot, in: NSRect(x: breakdownX, y: metricTop, width: content.maxX - breakdownX, height: 76))
+        if showsBudget {
+            drawTrack(NSRect(x: content.minX, y: content.maxY - 6, width: content.width, height: 6), accent: accent, snapshot: snapshot)
+        }
+    }
+
+    private func drawMetric(_ value: String, label key: String, x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor) {
+        let label = AchievementText.string(key)
+        let labelSize = GameLobbyStyle.fittedSize(label, width: width, preferred: 13, minimum: 10, weight: .semibold)
+        HomeStyle.text(label, in: NSRect(x: x, y: y, width: width, height: 19), size: labelSize, weight: .semibold, color: HomeStyle.secondary)
+        let size = GameLobbyStyle.fittedSize(value, width: width, preferred: 44, minimum: 14, weight: .heavy)
+        let height = ceil((value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)]).height)
+        HomeStyle.text(value, in: NSRect(x: x, y: y + 47 - height / 2, width: width, height: height), size: size, weight: .heavy, color: color)
+    }
+
+    private func drawDivider(at x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
@@ -50,7 +85,23 @@ final class HomeChallengeHUDView: NSView {
-        let divider = NSBezierPath(); divider.move(to: NSPoint(x: split, y: 22)); divider.line(to: NSPoint(x: split, y: 89)); divider.stroke()
-        HomeStyle.text(AchievementText.string("home.cleared_title"), in: NSRect(x: split + 20, y: 19, width: face.width - split - 27, height: 20),
-                       size: 12, weight: .semibold, color: HomeStyle.secondary)
-        let count = String(snapshot.totalCleared)
-        let countSize = GameLobbyStyle.fittedSize(count, width: face.width - split - 30, preferred: 38, minimum: 18, weight: .heavy)
-        HomeStyle.text(count, in: NSRect(x: split + 19, y: 42, width: face.width - split - 28, height: 48), size: countSize, weight: .heavy)
-        let track = NSRect(x: 22, y: face.height - 17, width: face.width - 38, height: 5)
+        let divider = NSBezierPath()
+        divider.move(to: NSPoint(x: x, y: top))
+        divider.line(to: NSPoint(x: x, y: bottom))
+        divider.stroke()
+    }
+
+    private func drawBreakdown(_ snapshot: GameSnapshot, in rect: NSRect) {
+        let slot = rect.width / 2
+        let row = rect.height / 2
+        for (index, kind) in PieceKind.allCases.enumerated() {
+            let x = rect.minX + CGFloat(index % 2) * slot
+            let y = rect.minY + (CGFloat(index / 2) + 0.5) * row
+            let iconWidth = min(42, slot * 0.44)
+            HomeStyle.piece(kind, in: NSRect(x: x, y: y - 14, width: iconWidth, height: 28), shadow: false)
+            let number = String(snapshot.clearedByKind[kind, default: 0])
+            let numberWidth = slot - iconWidth - 12
+            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: 21, minimum: 10, weight: .semibold)
+            let height = ceil((number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height)
+            HomeStyle.text(number, in: NSRect(x: x + iconWidth + 7, y: y - height / 2, width: numberWidth, height: height), size: size, weight: .semibold)
+        }
+    }
+
+    private func drawTrack(_ track: NSRect, accent: NSColor, snapshot: GameSnapshot) {
```

### `Sources/HomeDashboardView.swift`

```diff
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 0434149..4c3a8ea 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -25 +25,3 @@ class HomeButton: NSButton {
-    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
+    override func resetCursorRects() {
+        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
+    }
@@ -64 +66,4 @@ final class HomeModeButton: HomeButton {
-    let mode: HomeGameMode
+    // 解谜暂时只是大厅入口，没有可交给棋盘控制器的游戏模式。
+    let mode: HomeGameMode?
+    private var titleKey: String { "home.mode.\(mode?.key ?? "puzzle")" }
+    private var descriptionKey: String { "home.mode_desc.\(mode?.key ?? "puzzle")" }
@@ -67 +72 @@ final class HomeModeButton: HomeButton {
-    init(mode: HomeGameMode) {
+    init(mode: HomeGameMode?) {
@@ -71,0 +77 @@ final class HomeModeButton: HomeButton {
+        isEnabled = mode != nil
@@ -73,0 +80,6 @@ final class HomeModeButton: HomeButton {
+
+    func refresh(selectedMode: HomeGameMode) {
+        selected = mode == selectedMode
+        setAccessibilityLabel(AchievementText.string(titleKey) + ", " + AchievementText.string(descriptionKey))
+        needsDisplay = true
+    }
@@ -87 +99,6 @@ final class HomeModeButton: HomeButton {
-        GameModeArtwork.draw(mode, in: NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize))
+        let icon = NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize)
+        if let mode {
+            GameModeArtwork.draw(mode, in: icon)
+        } else {
+            GameModeArtwork.drawPuzzle(in: icon)
+        }
@@ -89 +106 @@ final class HomeModeButton: HomeButton {
-        let title = AchievementText.string("home.mode.\(mode.key)")
+        let title = AchievementText.string(titleKey)
@@ -93,2 +110,3 @@ final class HomeModeButton: HomeButton {
-        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold)
-        GameLobbyStyle.wrappedText(AchievementText.string("home.mode_desc.\(mode.key)"),
+        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold,
+                       color: isEnabled ? HomeStyle.ink : HomeStyle.secondary)
+        GameLobbyStyle.wrappedText(AchievementText.string(descriptionKey),
@@ -125,40 +142,0 @@ final class HomeHeroView: NSView {
-/// 当前棋盘的实时统计，不读取跨局成就数量。
-final class HomeSessionStatsView: NSView {
-    var snapshot: GameSnapshot? { didSet { needsDisplay = true; updateAccessibility() } }
-    override var isFlipped: Bool { true }
-    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityElement(true); setAccessibilityRole(.group) }
-    required init?(coder: NSCoder) { nil }
-    private func updateAccessibility() {
-        let total = snapshot?.totalCleared ?? 0
-        let pieces = PieceKind.allCases.map { kind in
-            AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), String(snapshot?.clearedByKind[kind, default: 0] ?? 0))
-        }
-        setAccessibilityLabel(([AchievementText.string("home.session_stats") + ": \(total)"] + pieces).joined(separator: "; "))
-    }
-    override func draw(_ dirtyRect: NSRect) {
-        GameLobbyStyle.surface(bounds.insetBy(dx: 3, dy: 4), radius: 16, tint: NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1))
-        let dividerX = bounds.width * 0.38
-        let title = AchievementText.string("home.cleared_title")
-        let titleSize = GameLobbyStyle.fittedSize(title, width: dividerX - 30, preferred: 20, minimum: 11, weight: .bold)
-        HomeStyle.text(title, in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: titleSize, weight: .bold)
-        let totalText = "\(snapshot?.totalCleared ?? 0)"
-        var totalSize: CGFloat = 58
-        while (totalText as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: totalSize, weight: .heavy)]).width > dividerX - 27, totalSize > 24 { totalSize -= 2 }
-        HomeStyle.text(totalText, in: NSRect(x: 21, y: 47, width: dividerX - 27, height: 70), size: totalSize, weight: .heavy)
-        HomeStyle.text(AchievementText.string("home.session_stats"), in: NSRect(x: 23, y: bounds.height - 29, width: dividerX - 27, height: 18), size: 11, color: HomeStyle.muted)
-        HomeStyle.border.setStroke()
-        let divider = NSBezierPath(); divider.move(to: NSPoint(x: dividerX, y: 24)); divider.line(to: NSPoint(x: dividerX, y: bounds.height - 24)); divider.stroke()
-        let slot = (bounds.width - dividerX - 20) / 2
-        for (index, kind) in PieceKind.allCases.enumerated() {
-            let x = dividerX + 14 + CGFloat(index % 2) * slot
-            let y = CGFloat(index / 2) * 55 + 35
-            HomeStyle.piece(kind, in: NSRect(x: x, y: y, width: 43, height: 29), shadow: false)
-            let text = "\(snapshot?.clearedByKind[kind, default: 0] ?? 0)"
-            let numberWidth = max(20, slot - 55)
-            var numberSize: CGFloat = 20
-            while (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: numberSize, weight: .semibold)]).width > numberWidth, numberSize > 10 { numberSize -= 1 }
-            HomeStyle.text(text, in: NSRect(x: x + 53, y: y + 2, width: numberWidth, height: 29), size: numberSize, weight: .semibold)
-        }
-    }
-}
-
@@ -205 +182,0 @@ final class HomeDashboardView: NSView {
-    let stats = HomeSessionStatsView(frame: .zero)
@@ -216 +192,0 @@ final class HomeDashboardView: NSView {
-    private var selectedMode: HomeGameMode = .free
@@ -218 +194,8 @@ final class HomeDashboardView: NSView {
-    private var showsChallenge = false
+    private var showsSession = false
+
+    private var margin: CGFloat { bounds.width < 1050 ? 32 : 44 }
+    private var footerY: CGFloat { bounds.height - 144 }
+    private var modePanelFrame: NSRect {
+        let width = max(330, min(440, bounds.width * 0.34))
+        return NSRect(x: bounds.width - margin - width, y: 96, width: width, height: min(496, footerY - 120))
+    }
@@ -231 +214 @@ final class HomeDashboardView: NSView {
-        [heading, subtitle, hint, hero, stats, challengeHUD, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        [heading, subtitle, hint, hero, challengeHUD, startButton, records, rules, settings, all].forEach { addSubview($0) }
@@ -243,0 +227,3 @@ final class HomeDashboardView: NSView {
+        let puzzle = HomeModeButton(mode: nil)
+        modes.insert(puzzle, at: 1)
+        addSubview(puzzle, positioned: .above, relativeTo: modes[0])
@@ -253,4 +239,2 @@ final class HomeDashboardView: NSView {
-        selectedMode = mode
-        stats.snapshot = snapshot
-        showsChallenge = mode != .free && (snapshot.isRunning || snapshot.isFinished)
-        challengeHUD.isHidden = !showsChallenge
+        showsSession = !isStarting && (snapshot.isRunning || snapshot.isFinished)
+        challengeHUD.isHidden = !showsSession
@@ -258,3 +242,4 @@ final class HomeDashboardView: NSView {
-        heading.stringValue = AchievementText.string(showsChallenge ? "home.mode.\(mode.key)" : "home.hero.\(mode.key)")
-        subtitle.stringValue = AchievementText.string(showsChallenge ? "home.mode_desc.\(mode.key)" : "home.subtitle.\(mode.key)")
-        subtitle.font = .systemFont(ofSize: showsChallenge ? 14 : 19, weight: .medium)
+        heading.isHidden = showsSession
+        subtitle.isHidden = showsSession
+        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
+        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
@@ -264 +249 @@ final class HomeDashboardView: NSView {
-            hint.stringValue = AchievementText.format("home.result", snapshot.totalCleared)
+            hint.stringValue = AchievementText.string("home.round_finished")
@@ -273,4 +258 @@ final class HomeDashboardView: NSView {
-        for button in modes {
-            button.selected = button.mode == mode
-            button.setAccessibilityLabel(AchievementText.string("home.mode.\(button.mode.key)") + ", " + AchievementText.string("home.mode_desc.\(button.mode.key)"))
-        }
+        modes.forEach { $0.refresh(selectedMode: mode) }
@@ -294,6 +276,3 @@ final class HomeDashboardView: NSView {
-        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
-        let rightWidth = max(330, min(440, bounds.width * 0.34))
-        let rightX = bounds.width - margin - rightWidth
-        let leftWidth = rightX - margin - 32
-        let footerY = bounds.height - 144
-        let top: CGFloat = 96
+        let panel = modePanelFrame
+        let leftWidth = panel.minX - margin - 32
+        let top = panel.minY
@@ -301,2 +280 @@ final class HomeDashboardView: NSView {
-        let modeHeight = bodyHeight - 172
-        heading.font = .systemFont(ofSize: showsChallenge ? 24 : min(60, max(44, leftWidth * 0.092)), weight: .heavy)
+        heading.font = .systemFont(ofSize: min(60, max(44, leftWidth * 0.092)), weight: .heavy)
@@ -304 +282 @@ final class HomeDashboardView: NSView {
-        heading.frame = NSRect(x: margin, y: top + (showsChallenge ? 10 : 26), width: leftWidth, height: showsChallenge ? 36 : bodyHeight * 0.32)
+        heading.frame = NSRect(x: margin, y: top + 26, width: leftWidth, height: bodyHeight * 0.32)
@@ -306,3 +284,2 @@ final class HomeDashboardView: NSView {
-        subtitle.frame = NSRect(x: margin, y: showsChallenge ? top + 49 : top + bodyHeight * 0.33, width: leftWidth, height: showsChallenge ? 32 : 56)
-        challengeHUD.frame = NSRect(x: margin, y: top + 83, width: leftWidth, height: min(128, bodyHeight * 0.27))
-        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.45, width: leftWidth - 24, height: 138)
+        subtitle.frame = NSRect(x: margin, y: top + bodyHeight * 0.33, width: leftWidth, height: 56)
+        challengeHUD.frame = NSRect(x: margin, y: top + 12, width: leftWidth, height: 148)
@@ -312 +289,6 @@ final class HomeDashboardView: NSView {
-        let rowHeight = (modeHeight - 86) / 3
+        let heroHeight: CGFloat = 138
+        let sessionHeroY = (challengeHUD.frame.maxY + hint.frame.minY - heroHeight) / 2
+        hero.frame = NSRect(x: margin + 12, y: showsSession ? sessionHeroY : top + bodyHeight * 0.45,
+                            width: leftWidth - 24, height: heroHeight)
+        let rowGap: CGFloat = 8
+        let rowHeight = (panel.height - 74 - CGFloat(modes.count - 1) * rowGap) / CGFloat(modes.count)
@@ -314 +296 @@ final class HomeDashboardView: NSView {
-            button.frame = NSRect(x: rightX + 20, y: top + 60 + CGFloat(index) * (rowHeight + 8), width: rightWidth - 40, height: rowHeight)
+            button.frame = NSRect(x: panel.minX + 20, y: top + 60 + CGFloat(index) * (rowHeight + rowGap), width: panel.width - 40, height: rowHeight)
@@ -316 +297,0 @@ final class HomeDashboardView: NSView {
-        stats.frame = NSRect(x: rightX, y: top + modeHeight + 16, width: rightWidth, height: 156)
@@ -331,6 +312,2 @@ final class HomeDashboardView: NSView {
-        let margin: CGFloat = bounds.width < 1050 ? 32 : 44
-        let rightWidth = max(330, min(440, bounds.width * 0.34))
-        let rightX = bounds.width - margin - rightWidth
-        let footerY = bounds.height - 144
-        let bodyHeight = footerY - 120
-        GameLobbyStyle.surface(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172), radius: 20,
+        let panel = modePanelFrame
+        GameLobbyStyle.surface(panel, radius: 20,
@@ -339 +316 @@ final class HomeDashboardView: NSView {
-        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: rightX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
+        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: panel.minX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
@@ -350 +327 @@ final class HomeDashboardView: NSView {
-        HomeStyle.text(AchievementText.string("home.game_modes"), in: NSRect(x: rightX + 22, y: 114, width: rightWidth - 44, height: 36), size: 27, weight: .heavy)
+        HomeStyle.text(AchievementText.string("home.game_modes"), in: NSRect(x: panel.minX + 22, y: 114, width: panel.width - 44, height: 36), size: 27, weight: .heavy)
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index e002bdf..bab937e 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -190,0 +191 @@
+"home.mode.puzzle" = "Puzzle Mode";
@@ -193,0 +195 @@
+"home.mode_desc.puzzle" = "Rules to be announced";
@@ -199 +200,0 @@
-"home.session_stats" = "This round, live";
@@ -241 +242 @@
-"home.result" = "Round complete · %d tiles cleared";
+"home.round_finished" = "Round complete";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index 86bf903..cdc0863 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -183,0 +184 @@
+"home.mode.puzzle" = "パズルモード";
@@ -186,0 +188 @@
+"home.mode_desc.puzzle" = "ルールは未定";
@@ -192 +193,0 @@
-"home.session_stats" = "この一局の記録";
@@ -234 +235 @@
-"home.result" = "終了 · 合計 %d 個消去";
+"home.round_finished" = "ラウンド終了";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index 4ea9fb0..c40da92 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -183,0 +184 @@
+"home.mode.puzzle" = "퍼즐 모드";
@@ -186,0 +188 @@
+"home.mode_desc.puzzle" = "플레이 방식 미정";
@@ -192 +193,0 @@
-"home.session_stats" = "현재 판 실시간 통계";
@@ -234 +235 @@
-"home.result" = "게임 종료 · 총 %d개 제거";
+"home.round_finished" = "라운드 종료";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index 7f2573c..78653f2 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -183,0 +184 @@
+"home.mode.puzzle" = "Головоломка";
@@ -186,0 +188 @@
+"home.mode_desc.puzzle" = "Правила пока не определены";
@@ -192 +193,0 @@
-"home.session_stats" = "Текущая игра";
@@ -234 +235 @@
-"home.result" = "Раунд завершён · Убрано фигур: %d";
+"home.round_finished" = "Раунд завершён";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index 31c1bb4..0269893 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -190,0 +191 @@
+"home.mode.puzzle" = "解谜模式";
@@ -193,0 +195 @@
+"home.mode_desc.puzzle" = "玩法待定";
@@ -199 +200,0 @@
-"home.session_stats" = "本局实时统计";
@@ -241 +242 @@
-"home.result" = "本局结束 · 共消除 %d 个方块";
+"home.round_finished" = "本局结束";
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
diff --git a/Tests/GameLobbyPresentationTests.swift b/Tests/GameLobbyPresentationTests.swift
index fe17baf..26efa98 100644
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -79,2 +79,2 @@ final class GameLobbyPresentationTests: AchievementTestCase {
-                        XCTAssertEqual(home.challengeHUD.isHidden, !running || mode == .free)
-                        XCTAssertEqual(home.stats.snapshot?.totalCleared, running ? 42 : 0)
+                        XCTAssertEqual(home.challengeHUD.isHidden, !running)
+                        XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, running ? 42 : 0)
@@ -81,0 +82,15 @@ final class GameLobbyPresentationTests: AchievementTestCase {
+                        let cards = home.subviews.compactMap { $0 as? HomeModeButton }.sorted { $0.frame.minY < $1.frame.minY }
+                        XCTAssertEqual(cards.map(\.mode), [.free, nil, .timed, .moves])
+                        XCTAssertLessThan(home.challengeHUD.frame.maxX, cards[0].frame.minX)
+                        XCTAssertFalse(cards[1].isEnabled)
+                        let label = try XCTUnwrap(home.challengeHUD.accessibilityLabel())
+                        XCTAssertEqual(label.components(separatedBy: AchievementText.string("home.cleared_title")).count, 2)
+                        for kind in PieceKind.allCases {
+                            XCTAssertTrue(label.contains(AchievementText.string(kind.titleKey) + ": \(snapshot.clearedByKind[kind, default: 0])"))
+                        }
+                        if mode == .free { XCTAssertTrue(home.challengeHUD.budgetText.isEmpty) }
+                        if running {
+                            let visibleLabels = home.subviews.compactMap { $0 as? NSTextField }.filter { !$0.isHidden }.map(\.stringValue)
+                            XCTAssertFalse(visibleLabels.contains(AchievementText.string("home.mode.\(mode.key)")))
+                            XCTAssertFalse(visibleLabels.contains(AchievementText.string("home.mode_desc.\(mode.key)")))
+                        }
@@ -101,0 +117,3 @@ final class GameLobbyPresentationTests: AchievementTestCase {
+        let finishedLabels = home.subviews.compactMap { $0 as? NSTextField }.filter { !$0.isHidden }.map(\.stringValue)
+        XCTAssertTrue(finishedLabels.contains(AchievementText.string("home.round_finished")))
+        XCTAssertFalse(finishedLabels.contains { $0.contains("126") }, "结果提示不应重复统计面板的总数")
```

### `Tests/HomeDashboardTests.swift`

```diff
diff --git a/Tests/HomeDashboardTests.swift b/Tests/HomeDashboardTests.swift
index 2e1df48..060d9fa 100644
--- a/Tests/HomeDashboardTests.swift
+++ b/Tests/HomeDashboardTests.swift
@@ -71 +71,5 @@ final class HomeDashboardTests: AchievementTestCase {
-        let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeSessionStatsView }.first)
+        let stats = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeChallengeHUDView }.first)
+        let puzzle = try XCTUnwrap(descendants(view).compactMap { $0 as? HomeModeButton }.first { $0.mode == nil })
+        XCTAssertFalse(board.snapshot().isRunning)
+        XCTAssertFalse(puzzle.isEnabled)
+        puzzle.performClick(nil)
@@ -78,0 +83,3 @@ final class HomeDashboardTests: AchievementTestCase {
+        puzzle.performClick(nil)
+        XCTAssertTrue(board.snapshot().isRunning, "解谜入口不能切换或重置正在进行的游戏")
+        XCTAssertEqual(stats.snapshot?.totalCleared, 30)
@@ -120 +127 @@ final class HomeDashboardTests: AchievementTestCase {
-                    XCTAssertEqual(home.stats.snapshot?.totalCleared, 21)
+                    XCTAssertEqual(home.challengeHUD.snapshot?.totalCleared, 21)
```

### `docs/previews/README.md`

```diff
diff --git a/docs/previews/README.md b/docs/previews/README.md
index f7faa49..48a59a4 100644
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -7 +7 @@
-- [待机首页](lobby-idle.png)：暖白环境光、设计稿方块、柔和立体卡片与金色主按钮。
+- [待机首页](lobby-idle.png)展示模式文案和开局入口。自由模式下方是标注“玩法待定”的解谜卡片。
@@ -10 +10 @@
-- [限时局内](challenge-timed.png)、[限步局内](challenge-moves.png)：大号剩余预算、消除数量与时间/行动条。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条、消除总数和四类方块明细。
```

### `docs/previews/challenge-moves.png`

```diff
- 1235174 字节，SHA-256 99863fbf1acae7a4c16b90dd514dd8aceba97461d873ce627c9d6a525d8d014c
+ 1281212 字节，SHA-256 6ab4affbb56b5eb322fdaa145132200a873643cacc9f4d931d7c0468566a229e
```

### `docs/previews/challenge-timed.png`

```diff
- 1232610 字节，SHA-256 b6e8c19a1d508c0f47d201cb22ac5f3bc23d08594a3bc1c295f83da4df37776a
+ 1278575 字节，SHA-256 1b72faeceefe6e69fc722d704a899b5d5074290cf83fcc34298edddd9218b407
```

### `docs/previews/lobby-finished.png`

```diff
- 1240242 字节，SHA-256 69339466ddd3681525c461e73553ab610814aedbfd879fe2c0a9f06e5c7809c6
+ 1274254 字节，SHA-256 f216a1976afa99bb49e02fbb4aa780009b694923be457295683911991d470aee
```

### `docs/previews/lobby-idle.png`

```diff
- 1122289 字节，SHA-256 44a1b90b7e2777601e2fb1ca2004fa199a749cc743e299819db97772d8fc405d
+ 1112793 字节，SHA-256 a77a99280e377d6701f7cffd0fb00b47b813e28bd138014419a40f20654a57ae
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1257715 字节，SHA-256 570a5062e0d68eb849bcfaa9ce9d97d9a7f9898deb1bfb7d5a7bb278ab3b1a29
+ 1297567 字节，SHA-256 9b02cd86119e14d8fea1aa6c4514e3f56a59b92d1bac06e97b84779a00bcf655
```
