# 统一练习提示与开局提示的尺寸

## 背景与目标

- 会话-147 要求自由模式练习提示的文字大小和蓝色斜杠与截图中的开局提示一致。

## 实施

- 两处提示使用同一套大厅宽度到字号的计算。自由模式按完整文案为窄窗适配字号。
- 蓝色斜杠共用宽 10 点、高度为基准字号加 1 点的尺寸，使用同一斜边绘制。

## 验证

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 全部 110 项通过。
- 核对原生大厅预览，提取两处斜杠的青色像素，边界均为 19 × 34 像素。运行 `./run.sh` 后，在自由模式的统计背板和开始按钮下方对照两处提示。

## 本轮完整增量 diff

以会话-147 开始时的工作区为基线。

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 2ca82071bf407f983412d678f43a7aafaa93093b..d6cb90d16a5b8be92d7fb17b91dcdb6e670ad9c7 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261128103633-match-practice-hint-and-start-hint-size.md` - 会话-147 起让自由模式提示和开局提示共用字号与蓝色斜杠尺寸。
 `workflow/20261128102721-match-practice-hint-description-tone.md` - 会话-145 起让自由模式练习提示与联系我们说明使用同样的常规字重和灰蓝色。
 `workflow/20261128101138-type-free-mode-practice-hint.md` - 会话-142 起在自由模式背板加入蓝色斜杠和逐字显示的练习提示。
 `workflow/20261128094456-synchronize-budget-fill-with-highlight.md` - 会话-136 起让统计卡预算填充和前板上沿扫光同步起播。
@@ -123,6 +124,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整自由模式提示或开局提示的字号、斜杠尺寸时，读取 `20261128103633-match-practice-hint-and-start-hint-size.md`。
 - 需要核对自由模式练习提示和联系我们说明的字重或颜色时，读取 `20261128102721-match-practice-hint-description-tone.md`。
 - 需要调整自由模式背板文案、蓝色斜杠、打字动画或首次进大厅的提示时，读取 `20261128101138-type-free-mode-practice-hint.md`。
 - 需要调整统计卡扫光和预算填充的共同起点，读取 `20261128094456-synchronize-budget-fill-with-highlight.md`。
diff --git a/Sources/HomeDashboardStyle.swift b/Sources/HomeDashboardStyle.swift
index f03ad9ea13996d7980dbbeb7a3e7734484e712e2..f4692a3370de8baea0d0933459da8e8a32f07233 100644
--- a/Sources/HomeDashboardStyle.swift
+++ b/Sources/HomeDashboardStyle.swift
@@ -120,6 +120,14 @@ enum HomeDashboardStyle {
         slant(rect).fill()
     }
 
+    static func hintPointSize(for dashboardWidth: CGFloat) -> CGFloat {
+        min(16, max(12, dashboardWidth * 0.010))
+    }
+
+    static func hintMarkSize(for pointSize: CGFloat) -> NSSize {
+        NSSize(width: 10, height: pointSize + 1)
+    }
+
     static func backdrop(in rect: NSRect) {
         NSGradient(colors: [color(0x090F16), navy, color(0x080E16)])?.draw(in: rect, angle: 21)
         if let context = NSGraphicsContext.current?.cgContext, rect.width > 0, rect.height > 0 {
diff --git a/Sources/HomeDashboardView.swift b/Sources/HomeDashboardView.swift
index 64eaf2f36df621ffab45a53d2889a8fb3d674779..30e366cd7807bac297525323db1f718b3c37b840 100644
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -716,7 +716,8 @@ final class HomeDashboardView: NSView {
             let font = hintFont
             let width = (hint.stringValue as NSString).size(withAttributes: [.font: font]).width
             let x = hint.frame.midX - min(width, hint.frame.width) / 2 - 20
-            HomeDashboardStyle.mark(in: NSRect(x: x, y: hint.frame.minY + 3, width: 10, height: font.pointSize + 1))
+            let size = HomeDashboardStyle.hintMarkSize(for: font.pointSize)
+            HomeDashboardStyle.mark(in: NSRect(origin: NSPoint(x: x, y: hint.frame.minY + 3), size: size))
         }
     }
 
@@ -726,7 +727,7 @@ final class HomeDashboardView: NSView {
     }
 
     private var hintFont: NSFont {
-        .systemFont(ofSize: min(16, max(12, bounds.width * 0.010)), weight: .medium)
+        .systemFont(ofSize: HomeDashboardStyle.hintPointSize(for: bounds.width), weight: .medium)
     }
 
     private func updateHint(_ value: String) {
diff --git a/Sources/HomeModeHeaderView.swift b/Sources/HomeModeHeaderView.swift
index 70b154d23197e82031eef6febac7bd33f78b230e..e2d1094428bcaed64f572573b07d7bee0afbf9b4 100644
--- a/Sources/HomeModeHeaderView.swift
+++ b/Sources/HomeModeHeaderView.swift
@@ -31,6 +31,7 @@ final class HomeModeHeaderView: NSView {
     deinit { timer?.invalidate() }
 
     func position(leftColumn: NSRect, windowWidth: CGFloat, modePanelLeading: CGFloat) {
+        card.hintPointSize = HomeDashboardStyle.hintPointSize(for: windowWidth)
         let topPadding = HomeChallengeHUDView.surfaceInsetY + 3 + HomeChallengeHUDView.assemblyTopSpace
         frame = NSRect(x: 0, y: leftColumn.minY - topPadding, width: windowWidth,
                        height: leftColumn.height + topPadding + HomeChallengeHUDView.assemblyBottomSpace)
diff --git a/Sources/HomeChallengeHUDView.swift b/Sources/HomeChallengeHUDView.swift
index b7fc337204a468fb48da77455d78e54aa19b425a..9821f0f96e49c18ce90718c507cd447aa3309234 100644
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -30,6 +30,9 @@ final class HomeChallengeHUDView: NSView {
     var backingRevealProgress: CGFloat = 1 {
         didSet { if backingRevealProgress != oldValue { needsDisplay = true } }
     }
+    var hintPointSize = HomeDashboardStyle.hintPointSize(for: 0) {
+        didSet { if hintPointSize != oldValue { needsDisplay = true } }
+    }
     private var practiceHint = ""
 
     var displayedPracticeHint: String {
@@ -359,10 +362,8 @@ final class HomeChallengeHUDView: NSView {
 
     private func drawPracticeHint(on face: Face) {
         let band = face.budgetTrack
-        let headerHeight = face.totals.minY - face.rules.minY
-        let markHeight = min(15, max(9, headerHeight * 0.38))
-        let markWidth = HomeDashboardStyle.edgeOffset(for: markHeight) + 4
-        let marker = NSRect(x: band.minX, y: band.midY - markHeight / 2, width: markWidth, height: markHeight)
+        let markSize = HomeDashboardStyle.hintMarkSize(for: hintPointSize)
+        let marker = NSRect(origin: NSPoint(x: band.minX, y: band.midY - markSize.height / 2), size: markSize)
         HomeDashboardStyle.mark(in: marker)
 
         let text = displayedPracticeHint
@@ -370,7 +371,7 @@ final class HomeChallengeHUDView: NSView {
         let width = band.maxX - x - 4
         guard !text.isEmpty, width > 0 else { return }
         // 按完整文案计算字号，逐字显示时文字位置和大小不跳动。
-        let size = GameLobbyStyle.fittedSize(practiceHint, width: width, preferred: min(17, max(10, headerHeight * 0.38)),
+        let size = GameLobbyStyle.fittedSize(practiceHint, width: width, preferred: hintPointSize,
                                            minimum: 9, weight: .regular)
         label(text, x: x, y: band.midY, width: width, size: size, weight: .regular, color: HomeDashboardStyle.muted)
     }
```
