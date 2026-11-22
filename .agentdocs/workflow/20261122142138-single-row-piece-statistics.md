# 规则与统计卡的单行方块明细

## 背景与目标

会话-188 起，把规则与统计卡中的四类方块明细排成同一行。总数与分类明细之间用留白分隔。

## 实施结果

- [x] 四组图案与数字按原有顺序横排，并对齐本局总数的垂直中心。
- [x] 移除总数与方块明细之间的竖线，预算与总数之间仍有竖线。
- [x] 调整预算和总数的列宽。明细使用等宽列并根据可用空间缩小长数字。
- [x] 更新实际界面预览、动画和文档索引。

## 测试方法与结果

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameLobbyPresentationTests`，6 项通过，0 失败。
- 核对实际渲染的常规限步局内和 960×720 俄语预览。四类方块及数字均在同一行，明细与本局消除之间无竖线。
- `git diff --check` 通过。可运行 `./run.sh` 并选择限时或限步以查看布局。
- [查看限步界面预览](../../docs/previews/challenge-moves.png)。

## 本轮完整增量 diff

基线为本轮开始前的工作区。文本使用统一 diff 逐行记录，预览资源注明字节数和 SHA-256。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261122142138-single-row-piece-statistics.md` - 会话-188 起把规则与统计卡中的四类方块明细排成一行，移除本局消除与明细之间的分隔线。含实际预览、测试结果与完整 diff。
@@ -92,0 +94 @@
+- 需要调整规则与统计卡的一行方块明细、数字列宽或分隔线时，读取 `20261122142138-single-row-piece-statistics.md`。
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- a/Sources/HomeChallengeHUDView.swift
+++ b/Sources/HomeChallengeHUDView.swift
@@ -65 +65 @@
-        // 数字区和方块明细共用列边界，避免长数字挤到相邻列。
+        // 缩窄左侧两项，为四类方块的一行明细留出宽度。
@@ -67,2 +67,2 @@
-        let budgetWidth = showsBudget ? content.width * 0.30 : 0
-        let totalWidth = content.width * (showsBudget ? 0.23 : 0.36)
+        let budgetWidth = showsBudget ? content.width * 0.27 : 0
+        let totalWidth = content.width * (showsBudget ? 0.21 : 0.31)
@@ -81,2 +81 @@
-        drawDivider(at: breakdownX - 9, from: metricTop, to: metricTop + 76)
-        drawBreakdown(snapshot, in: NSRect(x: breakdownX, y: metricTop, width: content.maxX - breakdownX, height: 76))
+        drawBreakdown(snapshot, in: NSRect(x: breakdownX, y: metricTop + 33, width: content.maxX - breakdownX, height: 28))
@@ -129,7 +128,9 @@
-        let slot = rect.width / 2
-        let row = rect.height / 2
-        for (index, kind) in PieceKind.allCases.enumerated() {
-            let x = rect.minX + CGFloat(index % 2) * slot
-            let y = rect.minY + (CGFloat(index / 2) + 0.5) * row
-            let iconWidth = min(42, slot * 0.44)
-            HomeStyle.piece(kind, in: NSRect(x: x, y: y - 14, width: iconWidth, height: 28), shadow: false)
+        let kinds = PieceKind.allCases
+        let slot = rect.width / CGFloat(kinds.count)
+        let iconWidth = min(36, slot * 0.46)
+        let gap: CGFloat = 6
+        let numberWidth = slot - iconWidth - gap - 6
+        // 每组的图案和数字都对齐本局总数的垂直中心。
+        for (index, kind) in kinds.enumerated() {
+            let x = rect.minX + CGFloat(index) * slot
+            HomeStyle.piece(kind, in: NSRect(x: x, y: rect.minY, width: iconWidth, height: rect.height), shadow: false)
@@ -137,2 +138 @@
-            let numberWidth = slot - iconWidth - 12
-            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: 21, minimum: 10, weight: .semibold)
+            let size = GameLobbyStyle.fittedSize(number, width: numberWidth, preferred: 18, minimum: 10, weight: .semibold)
@@ -140 +140,2 @@
-            HomeStyle.text(number, in: NSRect(x: x + iconWidth + 7, y: y - height / 2, width: numberWidth, height: height), size: size, weight: .semibold)
+            HomeStyle.text(number, in: NSRect(x: x + iconWidth + gap, y: rect.midY - height / 2, width: numberWidth, height: height),
+                           size: size, weight: .semibold)
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -11 +11 @@
-- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条、消除总数和四类方块明细。
+- [限时局内](challenge-timed.png)与[限步局内](challenge-moves.png)在左侧集中显示剩余时间或次数、进度条和消除总数。四类方块明细横向排在总数旁，中间以留白分隔。
```

### `docs/previews/challenge-moves.png`

```diff
- 1270754 字节，SHA-256 e268341fd2b10546e4d1227fd59ea9992d179adb2270fb2886b5b259ff976f80
+ 1250003 字节，SHA-256 dba61a258ba00fb59d8c625114b7293de62bbf08d2963f3fcccce10f1697d89c
```

### `docs/previews/challenge-preview.gif`

```diff
- 666893 字节，SHA-256 5a12821c092331b31e812ff23e968c0baf269cc1bfd509c6a3cfcc0b69105121
+ 640129 字节，SHA-256 aec7cd17c45c9492a53308f25fadf8b48e250afd3c0ecb3d42c0c795cc4a65e1
```

### `docs/previews/challenge-timed.png`

```diff
- 1267125 字节，SHA-256 f6bd542ecc895507edea557710c3853199b01359ca3339f13c60f1fe072cd789
+ 1253751 字节，SHA-256 36e0d9e755c1d5b7924412f18f4cfb51787274aa8f23ac3aee8c32f8b31e1053
```

### `docs/previews/lobby-finished.png`

```diff
- 1267390 字节，SHA-256 da1fb9899303c18a2bfa78c26f8bb3f8e3f328a65a449630a4826df2e83fedf6
+ 1246141 字节，SHA-256 e2aa196d120ebe1112a3f6f684781a66dce963c72e9e300d051fb003a168aa88
```

### `docs/previews/lobby-last-moves.png`

```diff
- 1287953 字节，SHA-256 f2fe6ca8e079577f9d592332ba9f22c4d3c9f1be776e094e312f5a632901e8ef
+ 1270113 字节，SHA-256 ed9c1fd60cc690aadd2999164067020658928279cb32d3b98d3824d33d6b07bf
```
