# 方块统计图标等距排列

## 背景与目标

会话-205 起，让首组贴齐明细区域左边缘，并让四个方块图标的相邻间距一致。

## 实施结果

- [x] 四组均从各自等宽列的左边缘起排，图标间距由列宽统一决定。每个数字紧随相应图标。
- [x] 明细使用消除统计宽度的三分之二。窗口宽度改变时四列同步伸缩，数字位数改变时图标位置保持稳定。
- [x] 更新实际界面预览和索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameLobbyPresentationTests|HomeDashboardTests'` 通过 14 项测试，0 失败。
- 测量三种模式下 534 点和 1360 点宽卡片的实际图标位置。使用一位、两位、三位和六位的统计值，核对首组贴齐左边缘及相邻图标等距。
- 运行 `./run.sh`，选择限时或限步并横向拉伸窗口，查看四个方块图标是否等距。
- [查看宽窗口实际预览](../../docs/previews/achievement-grid.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122163532-even-piece-stat-spacing.md` - 会话-205 起将四组方块放在等宽列的同一侧，首组贴齐明细区左边缘，图标保持等距。含不同位数的像素回归、预览与完整 diff。
@@ -97,0 +99 @@
+- 需要调整当前方块图标的等距布局，或核对数字位数变化时图标的位置，读取 `20261122163532-even-piece-stat-spacing.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -133 +133 @@
-        // 首组从明细区左边缘排起，其余各组靠列右侧。
+        // 四组都从各自的列左边缘排起，数字位数变化时图标之间仍然等距。
@@ -137,6 +137,2 @@
-            let text = (number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)])
-            let width = min(numberWidth, ceil(text.width))
-            let height = ceil(text.height)
-            let right = rect.maxX - CGFloat(kinds.count - index - 1) * slot
-            let alignsLeft = index == 0
-            let iconX = alignsLeft ? rect.minX : right - width - gap - iconWidth
+            let height = ceil((number as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).height)
+            let iconX = rect.minX + CGFloat(index) * slot
@@ -145,2 +141,2 @@
-            HomeStyle.text(number, in: NSRect(x: numberX, y: rect.midY - height / 2, width: width, height: height),
-                           size: size, weight: .semibold, alignment: alignsLeft ? .left : .right)
+            HomeStyle.text(number, in: NSRect(x: numberX, y: rect.midY - height / 2, width: numberWidth, height: height),
+                           size: size, weight: .semibold)
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -63,2 +63,2 @@
-        let count = 123_456
-        let counts = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { ($0, count) })
+        let longCount = 123_456
+        let counts = Dictionary(uniqueKeysWithValues: zip(PieceKind.allCases, [0, 12, 345, longCount]))
@@ -76 +76 @@
-                // 结算后的进度条没有颜色。扫描彩色列以核对首组左边缘和后三组的间距。
+                // 结算后的进度条没有颜色。用彩色列测量四个图标实际位置，覆盖不同位数的数字。
@@ -93 +92,0 @@
-                let firstStart = try XCTUnwrap(iconStarts.first)
@@ -95,3 +94,3 @@
-                XCTAssertEqual(firstStart, breakdownStart, accuracy: 1, "\(mode.key) / \(width)：首组贴齐明细区左边缘")
-                for (left, right) in zip(iconStarts.dropFirst(), iconStarts.dropFirst(2)) {
-                    XCTAssertEqual(right - left, columnWidth, accuracy: 1, "\(mode.key) / \(width)")
+                for (index, start) in iconStarts.enumerated() {
+                    XCTAssertEqual(start, breakdownStart + CGFloat(index) * columnWidth, accuracy: 1,
+                                   "\(mode.key) / \(width)：方块图标应依等宽列左边缘排布")
@@ -99 +98 @@
-                XCTAssertTrue(hud.toolTip?.contains("\(count)") == true, "长数字的完整值可通过提示查看")
+                XCTAssertTrue(hud.toolTip?.contains("\(longCount)") == true, "长数字的完整值可通过提示查看")
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -11 +11 @@
-- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。消除统计宽度的右侧三分之二由四类方块等分，第一组靠列左侧，其余三组靠列右侧。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块等分消除统计右侧区域，每个图标从列左侧起排，数字紧随图标。
```

### `docs/previews/achievement-grid.png`

```diff
- 1969485 字节，SHA-256 5f5b44aa74a11d1138e44ec53c321d6f0324f621f103eb3df515ebecd8c67567
+ 1970131 字节，SHA-256 0a5072ddfdba2f3e76322d848991d6374f7f9d3df674082bb5483be09ab2a6cf
```

### `docs/previews/challenge-moves.png`

```diff
- 1366244 字节，SHA-256 4f21daffe8c774239214f8d5caf11051d7c800097eeacf4484538cba186e1373
+ 1366865 字节，SHA-256 e6965aff7fa0f86f6100186ac0a4cd08c55b2082d6667797bf5ae05482611056
```

### `docs/previews/challenge-preview.gif`

```diff
- 603384 字节，SHA-256 4b6cbbc605fa095bea6bf6b5f58082e917b6ecff17e5a67020ddd4332dee59ff
+ 605713 字节，SHA-256 15feaea398034bc5de0b3e0d0baf655493952e67fd6b2118ed05fb3fc4c61749
```

### `docs/previews/challenge-timed.png`

```diff
- 1367420 字节，SHA-256 4fe41209ff8dfbd92776dec49238a7f3443bed94ecf1424f0c12b11b80ad8c95
+ 1367392 字节，SHA-256 fccbb07a2f84983bd7ef62901f6f6dce738929cbeb85af4d09137e1d354027eb
```

### `docs/previews/lobby-finished.png`

```diff
- 1361587 字节，SHA-256 5d68b1a36eb35025a4d267197889ff414d3a6cd2049a4d0a3514db8868830597
+ 1362008 字节，SHA-256 bf835af0e0459171e8c8413e770763a51df86a469ee63942f6923c6916b1783a
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1379745 字节，SHA-256 f36837883999df3458ef8995528a421be960f9b0b1fd7c4ce9c0d021c4737bc4
+ 1380163 字节，SHA-256 f9eb8473ea16e94316921652626ab8eca0b7ab4599f74b19a40c922fa39b08aa
```
