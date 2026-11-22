# 首组方块明细左对齐

## 背景与目标

会话-203 起，将第一组方块的图标和数字移到首列左侧，缩短与消除总数之间的视觉距离。

## 实施结果

- [x] 第一组图标贴齐明细区域的左边缘，数字紧随图标且左对齐。
- [x] 其余三组保持列内右对齐。明细仍占消除统计宽度的三分之二，四列等分。
- [x] 更新实际界面预览和索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameLobbyPresentationTests|HomeDashboardTests'` 通过 14 项测试，0 失败。
- 对三种模式和两种卡片宽度测量真实渲染结果，核对首组贴齐明细区左侧和其余三组的等宽列间距。
- 运行 `./run.sh`，选择限时或限步并横向拉伸窗口，确认第一组靠近总数。
- [查看宽窗口实际预览](../../docs/previews/achievement-grid.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122161432-left-align-first-piece-stat.md` - 会话-203 起把首组方块明细贴齐左边缘，缩短与消除总数的视觉距离。含宽窄窗口像素回归、预览与完整 diff。
@@ -96,0 +98 @@
+- 需要调整方块明细首列左对齐或与消除总数的留白时，读取 `20261122161432-left-align-first-piece-stat.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -133 +133 @@
-        // 四列平分明细区域，各组数字靠列右侧，位数变化时仍贴近图标。
+        // 首组从明细区左边缘排起，其余各组靠列右侧。
@@ -141,2 +141,4 @@
-            let numberX = right - width
-            HomeStyle.piece(kind, in: NSRect(x: numberX - gap - iconWidth, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
+            let alignsLeft = index == 0
+            let iconX = alignsLeft ? rect.minX : right - width - gap - iconWidth
+            let numberX = iconX + iconWidth + gap
+            HomeStyle.piece(kind, in: NSRect(x: iconX, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
@@ -144 +146 @@
-                           size: size, weight: .semibold, alignment: .right)
+                           size: size, weight: .semibold, alignment: alignsLeft ? .left : .right)
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -76 +76 @@
-                // 结算后的进度条没有颜色。扫描彩色列即可测出四组方块的实际间距。
+                // 结算后的进度条没有颜色。扫描彩色列以核对首组左边缘和后三组的间距。
@@ -93 +93,4 @@
-                for (left, right) in zip(iconStarts, iconStarts.dropFirst()) {
+                let firstStart = try XCTUnwrap(iconStarts.first)
+                let breakdownStart = hud.surfaceRect.maxX - 20 - statsWidth * 2 / 3
+                XCTAssertEqual(firstStart, breakdownStart, accuracy: 1, "\(mode.key) / \(width)：首组贴齐明细区左边缘")
+                for (left, right) in zip(iconStarts.dropFirst(), iconStarts.dropFirst(2)) {
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -11 +11 @@
-- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。消除统计宽度的右侧三分之二由四类方块等分，各组在列内靠右。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。消除统计宽度的右侧三分之二由四类方块等分，第一组靠列左侧，其余三组靠列右侧。
```

### `docs/previews/achievement-grid.png`

```diff
- 1969911 字节，SHA-256 2d8d8f515039f188c336a2e014c275fb9374c0b66b7484f67725cfa8febf41c9
+ 1969485 字节，SHA-256 5f5b44aa74a11d1138e44ec53c321d6f0324f621f103eb3df515ebecd8c67567
```

### `docs/previews/challenge-moves.png`

```diff
- 1365661 字节，SHA-256 b7d766e3fd214beab806a09863a4f9f50cdc7ab8184c1eb936c7e9eff3aada6a
+ 1366244 字节，SHA-256 4f21daffe8c774239214f8d5caf11051d7c800097eeacf4484538cba186e1373
```

### `docs/previews/challenge-preview.gif`

```diff
- 604468 字节，SHA-256 4c0f161bda6f7d4de9d454dc49a25c24babe2d87e5eb46935d30bc4e99af9f26
+ 603384 字节，SHA-256 4b6cbbc605fa095bea6bf6b5f58082e917b6ecff17e5a67020ddd4332dee59ff
```

### `docs/previews/challenge-timed.png`

```diff
- 1366891 字节，SHA-256 9230f1f94b0773d881e9ac859cf44b268e29e8f96ddec4c840c55293f3d5cbc9
+ 1367420 字节，SHA-256 4fe41209ff8dfbd92776dec49238a7f3443bed94ecf1424f0c12b11b80ad8c95
```

### `docs/previews/lobby-finished.png`

```diff
- 1361211 字节，SHA-256 f220483f97ef0c262768bfa3ad85a3dbae1bb199d513852718571b10b6f62f2f
+ 1361587 字节，SHA-256 5d68b1a36eb35025a4d267197889ff414d3a6cd2049a4d0a3514db8868830597
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1379467 字节，SHA-256 4ccf0ce89ea0ef42eaf4756e8b52437e63237cb1edc52b2607c440442a978aa2
+ 1379745 字节，SHA-256 f36837883999df3458ef8995528a421be960f9b0b1fd7c4ce9c0d021c4737bc4
```
