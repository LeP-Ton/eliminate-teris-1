# 按比例分配本局消除统计宽度

## 背景与目标

会话-200 起，四类方块明细使用消除统计可用宽度的三分之二，并按类型平分宽度。

## 实施结果

- [x] 挑战模式先留出时间或剩余交换次数区域，再让总数占消除统计区域的三分之一。自由模式直接使用卡片内容宽度分配。
- [x] 四类方块在另外三分之二宽度中等分单行列宽，随窗口调整。各组数字按列靠右，图标与数字保持间距。
- [x] 窄卡的长数字先缩小再截断，提示和辅助功能继续显示完整值。
- [x] 更新实际渲染预览和根索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameLobbyPresentationTests|HomeDashboardTests'` 通过 14 项测试，0 失败。
- 对三种模式的 534 点和 1360 点宽卡片测量真实渲染的图案间距，回归四类统计在宽窄视图中均为等宽列。窄卡六位数预览确认图案和数值各自留在列内。
- 运行 `./run.sh` 后选择限时或限步，横向调整窗口，核对消除数量与四类明细的宽度比例。
- [查看大窗口预览](../../docs/previews/achievement-grid.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122154723-proportional-piece-stat-columns.md` - 会话-200 起将消除统计按总数三分之一、方块明细三分之二分配，四类方块随窗口宽度等分。含宽窄窗口像素回归、预览与完整 diff。
@@ -95,0 +97 @@
+- 需要调整本局消除总数与四类方块的宽度比例、等宽列或长数字显示时，读取 `20261122154723-proportional-piece-stat-columns.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -65 +65 @@
-        // 缩窄左侧两项，为四类方块的一行明细留出宽度。
+        // 扣除挑战预算后，消除总数占三分之一，其余宽度交给四类方块明细。
@@ -68 +68 @@
-        let totalWidth = content.width * (showsBudget ? 0.21 : 0.31)
+        let totalWidth = (content.width - budgetWidth) / 3
@@ -129 +129 @@
-        let slot = min(80, rect.width / CGFloat(kinds.count))
+        let slot = rect.width / CGFloat(kinds.count)
@@ -133 +133 @@
-        // 明细从卡片右侧排起，数字右边缘固定，位数变化时仍与图标保持间距。
+        // 四列平分明细区域，各组数字靠列右侧，位数变化时仍贴近图标。
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- a/Tests/GameLobbyPresentationTests.swift
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -58,0 +59,41 @@
+    }
+
+    func testPieceCountsFillFourEqualColumnsAcrossStatWidths() throws {
+        _ = NSApplication.shared
+        let count = 123_456
+        let counts = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { ($0, count) })
+        for mode in HomeGameMode.allCases {
+            for width: CGFloat in [534, 1_360] {
+                let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: width, height: 148))
+                hud.refresh(snapshot: GameSnapshot(mode: mode.gameMode, elapsedTime: 60,
+                                                   remainingTime: mode == .timed ? 0 : nil,
+                                                   remainingSwaps: mode == .moves ? 0 : nil,
+                                                   isRunning: false, isFinished: true, clearedByKind: counts), mode: mode)
+                let bitmap = try image(hud)
+                let scale = CGFloat(bitmap.pixelsWide) / width
+                var iconStarts: [CGFloat] = []
+                var previousColoredX = -CGFloat.infinity
+                // 结算后的进度条没有颜色。扫描彩色列即可测出四组方块的实际间距。
+                for x in 0..<bitmap.pixelsWide {
+                    let containsArtwork = stride(from: 0, to: bitmap.pixelsHigh, by: 2).contains { y in
+                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
+                              color.alphaComponent > 0.9 else { return false }
+                        let high = max(color.redComponent, color.greenComponent, color.blueComponent)
+                        let low = min(color.redComponent, color.greenComponent, color.blueComponent)
+                        return high - low > 0.4
+                    }
+                    guard containsArtwork else { continue }
+                    let position = CGFloat(x) / scale
+                    if position - previousColoredX > 3 { iconStarts.append(position) }
+                    previousColoredX = position
+                }
+                let statsWidth = (hud.surfaceRect.width - 40) * (mode == .free ? 1 : 0.73)
+                let columnWidth = statsWidth * 2 / 3 / CGFloat(PieceKind.allCases.count)
+                XCTAssertEqual(iconStarts.count, PieceKind.allCases.count, "\(mode.key) / \(width)")
+                for (left, right) in zip(iconStarts, iconStarts.dropFirst()) {
+                    XCTAssertEqual(right - left, columnWidth, accuracy: 1, "\(mode.key) / \(width)")
+                }
+                XCTAssertTrue(hud.toolTip?.contains("\(count)") == true, "长数字的完整值可通过提示查看")
+                if mode == .moves, width == 534 { try export(hud, name: "hud-compact-long-counts") }
+            }
+        }
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -11 +11 @@
-- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块明细横排并靠卡片右侧，与总数用留白分隔。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。消除统计宽度的右侧三分之二由四类方块等分，各组在列内靠右。
```

### `docs/previews/achievement-grid.png`

```diff
- 1960675 字节，SHA-256 e03ded593b0e78c0796472ba9d2a521156a002573064348b3558e50910bd2e0c
+ 1969911 字节，SHA-256 2d8d8f515039f188c336a2e014c275fb9374c0b66b7484f67725cfa8febf41c9
```

### `docs/previews/challenge-moves.png`

```diff
- 1349055 字节，SHA-256 15b428416047185450cc31922fa159dc84cbefc0fbfefd2113a905c23fb12e65
+ 1365661 字节，SHA-256 b7d766e3fd214beab806a09863a4f9f50cdc7ab8184c1eb936c7e9eff3aada6a
```

### `docs/previews/challenge-preview.gif`

```diff
- 605070 字节，SHA-256 e5f45ebe85ded344d9aba4e847ee5a1f97c54707fc53753b5e42337c7b27c404
+ 604468 字节，SHA-256 4c0f161bda6f7d4de9d454dc49a25c24babe2d87e5eb46935d30bc4e99af9f26
```

### `docs/previews/challenge-timed.png`

```diff
- 1356364 字节，SHA-256 0e78569c0e982b834249519ee8632ecbc3de48f282d197bc696438548f0b449d
+ 1366891 字节，SHA-256 9230f1f94b0773d881e9ac859cf44b268e29e8f96ddec4c840c55293f3d5cbc9
```

### `docs/previews/lobby-finished.png`

```diff
- 1344425 字节，SHA-256 48f69469d39837dc56e46543c9938842cec6d56af699f31f5e09a863af3fd588
+ 1361211 字节，SHA-256 f220483f97ef0c262768bfa3ad85a3dbae1bb199d513852718571b10b6f62f2f
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1368244 字节，SHA-256 7c0977cb85d324a92644f88d6b3229c35671ee0fbd1929ed638b4e71a1d2a420
+ 1379467 字节，SHA-256 4ccf0ce89ea0ef42eaf4756e8b52437e63237cb1edc52b2607c440442a978aa2
```
