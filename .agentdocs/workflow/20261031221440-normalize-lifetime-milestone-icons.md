# 统一累计百格、千格、万格图标的视觉尺寸

## 背景与目标
- 对应会话：会话-92 起；分支：`experiment/ui-refactor`。
- 用户指出百格图案太小、千格略小，要求缩小三档尺寸差距并保持垂直居中。
- 本轮以开始时的工作区快照记录增量，保留之前各次变更文档。

## 实现
- 继续以两、三、四层方块区分总累计 100、1,000、10,000 三档。
- 单格尺寸分别改为 12、8.5、6.3 点，间距为 1、0.8、0.7 点，三档主体高度分别为 25、27.1、27.3 点。
- 以实际层高计算顶部位置，垂直中心固定为 48 点画布的中心。
- 小星随主体宽度定位，并纳入整体水平范围的居中校准。
- 更新现有标签测试，使用独立临时存储域模拟编号 17、18、19 解锁，分别验证点击回调并导出标签效果。
- 不改变成就门槛、计数、状态存储或其余图标；无整体架构变化。

## 阶段与 TODO
- [x] 放大百格和千格主体，缩小与万格的视觉差距。
- [x] 按实际图案边界统一居中。
- [x] 检查真实标签渲染、点击与整套图标回归。
- [x] 更新测试图、说明、根索引及本轮完整增量 diff。

## 测试方法与结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：5 项通过，0 失败；完成于 2026-10-31 22:12:41。
- 覆盖所有图标和灰色状态、32 个图案身份、等级区分、无正式预览入口、测试不修改玩家数据及真实标签点击。
- 人工查看百/千/万的真实标签效果，确认整体尺寸接近，图案未裁切。
- 从实际 AppKit 总览 PNG 的 60×60 点区域测量彩色图案边界：
  - 编号 17：38×35 点，中心 `(30,30)`。
  - 编号 18：41×38 点，中心 `(30,30)`。
  - 编号 19：41.5×38 点，中心 `(29.75,30)`。
- 三档宽高差距均在约 10% 以内，垂直中心一致。
- `git diff --check`：通过。
- 本次局部绘制调整使用现有图标回归，未新增重复实现的测试，未重启游戏或修改实际玩家存档。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 294199 | `66b1f668bd21ad82227bf029b313ab5d1e863e0cad1e8b9c58fe69ba1cea3207` |
| `docs/previews/achievement-labels.png` | 48029 | `f65f6944382ecc7aa214b328e033d96a2716b912d00ec8797881718df0dfe7d6` |

## 代码变更

以下逐行 diff 覆盖本轮全部源码、测试、说明和索引；两张 PNG 以二进制变更与校验值记录。

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- a/Sources/AchievementBadgeArtwork.swift
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -231,11 +231,23 @@
 
         private func collection(level: Int) {
             let colors = [blue, teal, coral]
-            for row in 0...level {
-                let count = min(4, row + 1)
-                for column in 0..<count { rect(24 - CGFloat(count) * 3.5 + CGFloat(column) * 7, 10 + CGFloat(row) * 6, 6.3, 6.3, colors[row % 3]) }
-            }
-            star(35, 12, radius: 3.4, color: gold)
+            // 三档分别保留两、三、四层，随层数缩小单格，使整体尺寸和视觉面积接近。
+            let cell: CGFloat = [12, 8.5, 6.3][level - 1]
+            let gap: CGFloat = [1, 0.8, 0.7][level - 1]
+            let rows = level + 1
+            let extent = CGFloat(rows) * cell + CGFloat(rows - 1) * gap
+            let top = 24 - extent / 2
+            // 右侧小星也计入水平范围，主体略左移后整组居中；纵向按实际层高居中。
+            let centerX: CGFloat = 22.9
+            for row in 0..<rows {
+                let count = row + 1
+                let width = CGFloat(count) * cell + CGFloat(count - 1) * gap
+                for column in 0..<count {
+                    rect(centerX - width / 2 + CGFloat(column) * (cell + gap), top + CGFloat(row) * (cell + gap),
+                         cell, cell, colors[row % 3])
+                }
+            }
+            star(centerX + extent / 2 - 0.5, top + 3, radius: 2.8, color: gold)
         }
 
         private func challengePasses() {
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -113,7 +113,7 @@
         let domain = "badge-label-preview.\(UUID().uuidString)"
         let fixture = try XCTUnwrap(UserDefaults(suiteName: domain))
         defer { fixture.removePersistentDomain(forName: domain) }
-        fixture.set(["version": 1, "unlocked": [7, 8, 9], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        fixture.set(["version": 1, "unlocked": [17, 18, 19], "metrics": [:]], forKey: AchievementsManager.storageKey)
         let progress = AchievementsManager(defaults: fixture)
         let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
         home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
@@ -121,7 +121,7 @@
         home.layoutSubtreeIfNeeded()
         var selected: Int?
         home.onAchievement = { selected = $0 }
-        for id in [7, 8, 9] {
+        for id in [17, 18, 19] {
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
 
-- 使用首页真实标签组件渲染，重点展示“连锁反应”“余波未平”和“步步有解”。
+- 使用首页真实标签组件渲染，重点展示“百格起步”“千格熟手”和“万格旅人”的尺寸与居中效果。
 - 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
 ## 全部 32 枚徽章
@@ -15,7 +15,8 @@
 
 - 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
 - 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、纯脚印、挑战票券等游戏图案。
-- 百、千、万档分别使用一、二、三颗星。
+- 总累计百/千/万图案分别保留两、三、四层方块，调整单格尺寸以保持整体大小接近并垂直居中。
+- 四种类型的百/千/万档分别使用一、二、三颗星。
 - 测试总览夹具：`Tests/AchievementIconContactSheet.swift`，只编入 XCTest target，不进入正式 App。
 
 ## 更新测试图
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031221440-normalize-lifetime-milestone-icons.md` - 会话-92 起调整百格/千格/万格累计成就图案的单格大小与整体居中，三档视觉尺寸接近；含完整增量 diff、像素边界测量、测试图与 5 项图标回归。
 `workflow/20261031215904-simplify-cascade-and-footprint-icons.md` - 会话-90 起去掉连锁/余波图标下方箭头并按实际行数垂直居中；步步有解只保留居中脚印，含全部增量 diff、测试图与 5 项图标回归。
 `workflow/20261031210746-redesign-three-achievement-icons.md` - 会话-83 起重设计指尖火花、步步有解和挑战常客：指尖消除火花、落脚路径及挑战票券；保持无外框，含完整增量 diff、5 项回归及其余 29 个图标逐像素一致检查。
 `workflow/20261031205241-remove-achievement-badge-frames.md` - 会话-81 起按反馈去掉成就徽章的盾牌外框、底板和投影，保留透明彩色主题图案并放大 12%；含完整增量 diff、更新测试图与 5 项图标回归。
@@ -74,6 +75,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整百格起步、千格熟手、万格旅人的整体尺寸差距和垂直居中时，读取 `20261031221440-normalize-lifetime-milestone-icons.md`。
 - 需要调整连锁反应/余波未平的无箭头方块居中，或步步有解的纯脚印图案时，读取 `20261031215904-simplify-cascade-and-footprint-icons.md`。
 - 需要调整编号 4/9/20 的指尖火花、落脚路径和挑战票券图案，或查看三个重设计图标的真实标签测试图时，读取 `20261031210746-redesign-three-achievement-icons.md`。
 - 需要确认成就图标为何没有徽章外框、调整透明图案的主体缩放或查看去边框效果时，读取 `20261031205241-remove-achievement-badge-frames.md`。
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
