# 去掉总累计三档图案中的五角星

## 背景与目标
- 对应会话：会话-95 起；分支：`experiment/ui-refactor`。
- 用户要求删除百格、千格、万格图案中的多余五角星。
- 本文以本轮开始工作区快照记录增量，保留之前各轮变更文档。

## 实现
- 删除 `collection(level:)` 中的五角星绘制，只保留两、三、四层彩色方块。
- 取消原来为右侧星星预留的水平偏移，改为以方块组自身的中心定位。
- 保留上一轮调整后的单格尺寸、间距和垂直中心，继续保持三档大小接近。
- 更新静态测试图和说明；本次是局部样式调整，不涉及规则、计数或整体架构。

## 阶段与 TODO
- [x] 删除三档总累计图案中的五角星。
- [x] 重新校准方块组水平中心。
- [x] 验证实际标签及既有图标测试，更新测试图。
- [x] 记录完整增量 diff 并更新根索引。

## 测试方法与结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：5 项通过，0 失败；完成于 2026-10-31 22:22:09。
- 验证所有图标正常/灰色状态、图案身份与档位、测试数据隔离、正式面板无预览入口，以及编号 17、18、19 的真实标签点击。
- 人工查看真实标签，确认三个图案均无五角星，方块完整且居中。
- 从导出总览的图案边界检查居中，三档中心均位于画布中心附近，误差不超过 1 点。
- `git diff --check`：通过。
- 使用现有图标回归验证，未新增重复绘制实现的测试，未重启游戏或修改玩家存档。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 292806 | `7879c7c9f173cb50b0d16de409a9a8682d6676bc79b15cf803d8ee2c8ff7e765` |
| `docs/previews/achievement-labels.png` | 47222 | `d68a4e97010cd3aabfea52579e808091b0cad135dc9b05ad72d57451026f3661` |

## 代码变更

以下为本轮全部源码、说明和索引的逐行 diff；测试图片以二进制变更及校验值记录。

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- a/Sources/AchievementBadgeArtwork.swift
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -237,8 +237,8 @@
             let rows = level + 1
             let extent = CGFloat(rows) * cell + CGFloat(rows - 1) * gap
             let top = 24 - extent / 2
-            // 右侧小星也计入水平范围，主体略左移后整组居中；纵向按实际层高居中。
-            let centerX: CGFloat = 22.9
+            // 仅保留方块，横纵都以主体的实际边界居中。
+            let centerX: CGFloat = 24
             for row in 0..<rows {
                 let count = row + 1
                 let width = CGFloat(count) * cell + CGFloat(count - 1) * gap
@@ -247,7 +247,6 @@
                          cell, cell, colors[row % 3])
                 }
             }
-            star(centerX + extent / 2 - 0.5, top + 3, radius: 2.8, color: gold)
         }
 
         private func challengePasses() {
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -15,7 +15,7 @@
 
 - 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
 - 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、纯脚印、挑战票券等游戏图案。
-- 总累计百/千/万图案分别保留两、三、四层方块，调整单格尺寸以保持整体大小接近并垂直居中。
+- 总累计百/千/万图案仅保留两、三、四层方块，不含五角星；调整单格尺寸以保持整体大小接近并居中。
 - 四种类型的百/千/万档分别使用一、二、三颗星。
 - 测试总览夹具：`Tests/AchievementIconContactSheet.swift`，只编入 XCTest target，不进入正式 App。
 
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031222305-remove-lifetime-milestone-stars.md` - 会话-95 起移除总累计百/千/万图案中的五角星，仅保留三档方块并重新居中；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031221440-normalize-lifetime-milestone-icons.md` - 会话-92 起调整百格/千格/万格累计成就图案的单格大小与整体居中，三档视觉尺寸接近；含完整增量 diff、像素边界测量、测试图与 5 项图标回归。
 `workflow/20261031215904-simplify-cascade-and-footprint-icons.md` - 会话-90 起去掉连锁/余波图标下方箭头并按实际行数垂直居中；步步有解只保留居中脚印，含全部增量 diff、测试图与 5 项图标回归。
 `workflow/20261031210746-redesign-three-achievement-icons.md` - 会话-83 起重设计指尖火花、步步有解和挑战常客：指尖消除火花、落脚路径及挑战票券；保持无外框，含完整增量 diff、5 项回归及其余 29 个图标逐像素一致检查。
@@ -75,6 +76,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认总累计百/千/万图案为何没有五角星、查看纯方块效果或居中调整时，读取 `20261031222305-remove-lifetime-milestone-stars.md`。
 - 需要调整百格起步、千格熟手、万格旅人的整体尺寸差距和垂直居中时，读取 `20261031221440-normalize-lifetime-milestone-icons.md`。
 - 需要调整连锁反应/余波未平的无箭头方块居中，或步步有解的纯脚印图案时，读取 `20261031215904-simplify-cascade-and-footprint-icons.md`。
 - 需要调整编号 4/9/20 的指尖火花、落脚路径和挑战票券图案，或查看三个重设计图标的真实标签测试图时，读取 `20261031210746-redesign-three-achievement-icons.md`。
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
