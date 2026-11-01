# 精简连锁、余波和脚印图标并居中

## 背景与目标
- 对应会话：会话-90 起；分支：`experiment/ui-refactor`。
- 用户要求删除“连锁反应”“余波未平”图标下方的箭头，并注意垂直居中。
- 用户要求删除“步步有解”右上角黄色图案，仅保留脚印。
- 本文基于本轮开始时工作区快照记录增量，不覆盖此前变更文档。

## 实现
- 删除连锁图案共用绘制函数中的下方箭头。
- 根据两行或三行方块的实际高度计算起始纵坐标，让两种图案都以 48 点画布的中心定位；同时将方块组的横向中心对齐画布。
- 删除脚印图案中的黄色方块与星星，仅保留蓝绿两枚脚印，重新调整整体位置。
- 更新现有标签测试的临时解锁与点击编号为 7、8、9，导出真实标签效果图。
- 更新静态测试总览与说明，正式应用继续无测试预览入口。
- 本轮仅调整三个图案，不涉及规则、成就条件或整体架构认知。

## 阶段与 TODO
- [x] 去掉两个连锁图标下方的箭头。
- [x] 按实际图案高度垂直居中。
- [x] 步步有解只保留脚印并重新居中。
- [x] 验证图标、实际标签和点击回调，更新测试图。
- [x] 记录本轮全部逐行 diff。

## 测试方法与结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：5 项通过，0 失败；完成于 2026-10-31 21:57:05。
- 包含全部图标的正常/灰色状态、图案身份与等级、正式面板无预览入口、测试不写入玩家数据、编号 7/8/9 的真实标签点击。
- 人工查看真实标签截图，确认连锁与余波无箭头、步步有解无黄色装饰。
- 从 AppKit 导出的总览 PNG 测量彩色图案边界，在 60×60 点区域内，编号 7、8 的中心均为 `(30,30)`；编号 9 为 `(29.75,29.5)`，与目标中心差不超过 0.5 点。
- `git diff --check`：通过。
- 未新增重复绘制实现的测试，未重启游戏或修改玩家存档。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 285843 | `5fba67a11c444169504e1ab06185f72da52657876736af182e42f5563e64eecd` |
| `docs/previews/achievement-labels.png` | 47866 | `c0aac426bacfc4426ac16b786580d9005b2a1c3824cdb69adfe30ff2c9155d2c` |

## 代码变更

以下逐行 diff 覆盖本轮全部源码、测试、说明和索引；测试图片以二进制变更和校验值记录。

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- a/Sources/AchievementBadgeArtwork.swift
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -166,24 +166,22 @@
         }
 
         private func cascade(count: Int) {
+            // 只保留方块；按两行或三行的实际高度定位，使透明图案垂直居中。
+            let top = 24 - (CGFloat(count - 1) * 8 + 6) / 2
             for row in 0..<count {
-                for column in 0..<3 { rect(12 + CGFloat(column) * 8 + CGFloat(row % 2) * 2, 12 + CGFloat(row) * 8, 6.5, 6, [blue, teal, gold][row]) }
-            }
-            let arrow = polygon([NSPoint(x: 18, y: 34), NSPoint(x: 24, y: 38), NSPoint(x: 30, y: 34), NSPoint(x: 24, y: 35)])
-            fill(arrow, base)
+                for column in 0..<3 { rect(11.75 + CGFloat(column) * 8 + CGFloat(row % 2) * 2, top + CGFloat(row) * 8, 6.5, 6, [blue, teal, gold][row]) }
+            }
         }
 
         private func steppingTrail() {
-            // 两枚落脚印走向亮起的方块，避免继续使用勾选圈或楼梯状功能图标。
-            for (x, y, color) in [(CGFloat(16), CGFloat(26), blue), (CGFloat(29), CGFloat(17), teal)] {
+            // 只保留两枚脚印，并将它们组成的图案重新居中。
+            for (x, y, color) in [(CGFloat(17.75), CGFloat(26.75), blue), (CGFloat(30.75), CGFloat(17.75), teal)] {
                 NSGraphicsContext.saveGraphicsState()
                 let tilt = NSAffineTransform(); tilt.translateX(by: x, yBy: y); tilt.rotate(byDegrees: 22); tilt.concat()
                 fill(NSBezierPath(roundedRect: NSRect(x: -3.6, y: -7, width: 7.2, height: 11), xRadius: 3.6, yRadius: 3.6), color)
                 rect(-2.8, 6, 5.6, 4, color, radius: 1.5)
                 NSGraphicsContext.restoreGraphicsState()
             }
-            rect(33, 7, 6.3, 6.3, gold, radius: 1.4)
-            star(39, 7, radius: 2.7, color: gold)
         }
 
         private func trophy() {
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -113,7 +113,7 @@
         let domain = "badge-label-preview.\(UUID().uuidString)"
         let fixture = try XCTUnwrap(UserDefaults(suiteName: domain))
         defer { fixture.removePersistentDomain(forName: domain) }
-        fixture.set(["version": 1, "unlocked": [4, 9, 20], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        fixture.set(["version": 1, "unlocked": [7, 8, 9], "metrics": [:]], forKey: AchievementsManager.storageKey)
         let progress = AchievementsManager(defaults: fixture)
         let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
         home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
@@ -121,7 +121,7 @@
         home.layoutSubtreeIfNeeded()
         var selected: Int?
         home.onAchievement = { selected = $0 }
-        for id in [4, 9, 20] {
+        for id in [7, 8, 9] {
             let description = AchievementText.string(AchievementDefinition.all[id - 1].descriptionKey)
             let button = try XCTUnwrap(home.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
             button.performClick(nil)
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -6,7 +6,7 @@
 
 ![成就标签实际效果](achievement-labels.png)
 
-- 使用首页真实标签组件渲染，重点展示“指尖火花”“步步有解”和“挑战常客”。
+- 使用首页真实标签组件渲染，重点展示“连锁反应”“余波未平”和“步步有解”。
 - 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
 ## 全部 32 枚徽章
@@ -14,7 +14,7 @@
 ![全部成就徽章](achievement-icons.png)
 
 - 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
-- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、落脚路径、挑战票券等游戏图案。
+- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、纯脚印、挑战票券等游戏图案。
 - 百、千、万档分别使用一、二、三颗星。
 - 测试总览夹具：`Tests/AchievementIconContactSheet.swift`，只编入 XCTest target，不进入正式 App。
 
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031215904-simplify-cascade-and-footprint-icons.md` - 会话-90 起去掉连锁/余波图标下方箭头并按实际行数垂直居中；步步有解只保留居中脚印，含全部增量 diff、测试图与 5 项图标回归。
 `workflow/20261031210746-redesign-three-achievement-icons.md` - 会话-83 起重设计指尖火花、步步有解和挑战常客：指尖消除火花、落脚路径及挑战票券；保持无外框，含完整增量 diff、5 项回归及其余 29 个图标逐像素一致检查。
 `workflow/20261031205241-remove-achievement-badge-frames.md` - 会话-81 起按反馈去掉成就徽章的盾牌外框、底板和投影，保留透明彩色主题图案并放大 12%；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031204033-game-badges-test-only-preview.md` - 会话-76 起移除正式图标预览入口和页面，将全部图标展示收回测试 target；成就重绘为彩色街机收藏徽章，重点替换节奏/步步有解，含完整逐行 diff、标签测试图和 51 项回归。
@@ -73,6 +74,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整连锁反应/余波未平的无箭头方块居中，或步步有解的纯脚印图案时，读取 `20261031215904-simplify-cascade-and-footprint-icons.md`。
 - 需要调整编号 4/9/20 的指尖火花、落脚路径和挑战票券图案，或查看三个重设计图标的真实标签测试图时，读取 `20261031210746-redesign-three-achievement-icons.md`。
 - 需要确认成就图标为何没有徽章外框、调整透明图案的主体缩放或查看去边框效果时，读取 `20261031205241-remove-achievement-badge-frames.md`。
 - 需要调整彩色游戏成就徽章、节奏光柱/阶梯终点星、测试总览导出，或确认正式应用为何没有预览入口时，读取 `20261031204033-game-badges-test-only-preview.md`。
```

### `docs/previews/achievement-icons.png`

```diff
diff --git a/docs/previews/achievement-icons.png b/docs/previews/achievement-icons.png
Binary files a/docs/previews/achievement-icons.png and b/docs/previews/achievement-icons.png differ
```

### `docs/previews/achievement-labels.png`

```diff
diff --git a/docs/previews/achievement-labels.png b/docs/previews/achievement-labels.png
Binary files a/docs/previews/achievement-labels.png and b/docs/previews/achievement-labels.png differ
```
