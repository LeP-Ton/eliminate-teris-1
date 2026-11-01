# 去掉成就徽章外框与底板

## 背景与目标
- 对应会话：会话-81 起；分支：`experiment/ui-refactor`。
- 用户反馈现有徽章仍不美观，明确建议去掉徽章边框。
- 本轮只移除图标外围装饰，保留已经建立的彩色主题图案及等级辨识。
- 以本轮开始时工作区快照记录增量，不覆盖之前各会话变更文档。

## 实现
- 删除盾牌轮廓、珐琅底板、内侧描边与外围投影的全部绘制代码。
- 保留摇杆、节拍光柱、阶梯终点星、方块、奖杯等主题元素，使用透明画布直接展示。
- 主体以画布中心为基准等比放大 12%，补偿去掉外框后产生的视觉空隙，不改变宽高比例。
- 更新测试标签图与全部图标总览；正式应用仍无测试预览入口。
- 本次是局部样式调整，无核心架构变化；偏好与实现记入根索引，不额外改写项目核心认知。

## 阶段与 TODO
- [x] 移除外框、底板、内描边及投影。
- [x] 校准透明主体缩放与留白。
- [x] 运行现有图标回归，人工查看真实标签及全部图案。
- [x] 更新测试图、说明与完整增量 diff。

## 测试方法与结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：5 项通过，0 失败；完成于 2026-10-31 20:51:25。
- 覆盖三种模式图标、全部 32 个图案的正常和灰色状态、图案身份与等级区分、正式面板无预览入口、测试导出不写入进度、节奏/步步有解的真实标签点击。
- 人工查看最终标签与全部图案，确认盾牌外框和底板已消失，透明图案完整显示且未裁切。
- `git diff --check`：通过。
- 使用现有测试验证本次样式调整，未新增镜像绘制实现的测试，未修改玩家存档或重启游戏。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 277241 | `f9bdcd95ef4622c002e80b2cda2b58e3dd21e5fd4eabba97e0a2bd1e34dc7a57` |
| `docs/previews/achievement-labels.png` | 44185 | `c5f786d82e4921777201b569e9a8b51d157b04fdcda20195037ddf9da748f094` |

## 代码变更

以下为本轮源码、索引及说明的全部逐行 diff；两张更新的 PNG 以二进制变更及校验值记录。

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- a/Sources/AchievementBadgeArtwork.swift
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -1,6 +1,6 @@
 import Cocoa
 
-/// 成就专用的街机收藏徽章：共同的珐琅盾牌边框与各自的游戏主题图案。
+/// 成就专用的彩色游戏图案，使用透明背景，不绘制外框或底板。
 /// 所有几何以 48 点画布绘制，不依赖系统功能图标或玩家解锁状态。
 enum AchievementBadgeArtwork {
     static func accent(for definition: AchievementDefinition) -> NSColor {
@@ -70,30 +70,15 @@
             fill(polygon(points), color)
         }
 
-        private func shield() -> NSBezierPath {
-            let path = NSBezierPath()
-            path.move(to: NSPoint(x: 12, y: 4)); path.line(to: NSPoint(x: 36, y: 4))
-            path.curve(to: NSPoint(x: 43, y: 12), controlPoint1: NSPoint(x: 41, y: 4), controlPoint2: NSPoint(x: 44, y: 7))
-            path.line(to: NSPoint(x: 40, y: 31))
-            path.curve(to: NSPoint(x: 24, y: 44), controlPoint1: NSPoint(x: 39, y: 36), controlPoint2: NSPoint(x: 30, y: 42))
-            path.curve(to: NSPoint(x: 8, y: 31), controlPoint1: NSPoint(x: 18, y: 42), controlPoint2: NSPoint(x: 9, y: 36))
-            path.line(to: NSPoint(x: 5, y: 12))
-            path.curve(to: NSPoint(x: 12, y: 4), controlPoint1: NSPoint(x: 4, y: 7), controlPoint2: NSPoint(x: 7, y: 4))
-            path.close(); return path
-        }
-
         func draw(_ definition: AchievementDefinition) {
-            let rim = shield()
+            // 去掉外围装饰后将主体略微放大，保留适当留白，避免标签中的图案显得过小。
             NSGraphicsContext.saveGraphicsState()
-            let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
-            shadow.shadowBlurRadius = 1.5; shadow.shadowOffset = NSSize(width: 0, height: -1.2); shadow.set()
-            fill(rim, mix(base, ink, 0.24))
-            NSGraphicsContext.restoreGraphicsState()
-            let face = rim.copy() as! NSBezierPath
-            let inset = NSAffineTransform(); inset.translateX(by: 24, yBy: 24); inset.scale(by: 0.87); inset.translateX(by: -24, yBy: -24)
-            face.transform(using: inset as AffineTransform)
-            fill(face, mix(base, .white, 0.83))
-            stroke(face, .white.withAlphaComponent(0.75), width: 0.7)
+            defer { NSGraphicsContext.restoreGraphicsState() }
+            let transform = NSAffineTransform()
+            transform.translateX(by: 24, yBy: 24)
+            transform.scale(by: 1.12)
+            transform.translateX(by: -24, yBy: -24)
+            transform.concat()
 
             if case .pieceCleared(let kind, let count) = definition.goal {
                 piece(kind, count: count)
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -14,7 +14,7 @@
 ![全部成就徽章](achievement-icons.png)
 
 - 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
-- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用彩色珐琅盾牌、街机摇杆、节拍光柱、阶梯终点星等图案。
+- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、阶梯终点星等游戏图案。
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
+`workflow/20261031205241-remove-achievement-badge-frames.md` - 会话-81 起按反馈去掉成就徽章的盾牌外框、底板和投影，保留透明彩色主题图案并放大 12%；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031204033-game-badges-test-only-preview.md` - 会话-76 起移除正式图标预览入口和页面，将全部图标展示收回测试 target；成就重绘为彩色街机收藏徽章，重点替换节奏/步步有解，含完整逐行 diff、标签测试图和 51 项回归。
 `workflow/20261031201958-icon-aspect-and-achievement-gallery.md` - 会话-71 起修复系统图标拉伸与竞分奖杯缺失，统一全部成就图标，新增无需解锁的图标预览与可分享总览；含全部逐行 diff、50 项完整回归及真实渲染验收。
 `workflow/20261030090548-use-original-design-cutouts.md` - 会话-64 起直接从原始设计稿提取方块、投影、短线和箭头，按原稿坐标整体等比排列；主体像素保真验证、独立浮动及 46 项完整回归，含全部增量 diff 和资源校验。
@@ -71,6 +72,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认成就图标为何没有徽章外框、调整透明图案的主体缩放或查看去边框效果时，读取 `20261031205241-remove-achievement-badge-frames.md`。
 - 需要调整彩色游戏成就徽章、节奏光柱/阶梯终点星、测试总览导出，或确认正式应用为何没有预览入口时，读取 `20261031204033-game-badges-test-only-preview.md`。
 - 需要调整模式/成就图标的比例、奖杯兼容路径、32 枚图标映射或无需解锁的图标预览入口时，读取 `20261031201958-icon-aspect-and-achievement-gallery.md`。
 - 需要调整当前首页原稿提取素材、复现抠图、核对像素保真或原稿相对布局时，读取 `20261030090548-use-original-design-cutouts.md`。
@@ -142,7 +144,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的彩色游戏收藏徽章。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
+- `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的透明背景彩色游戏图案，不绘制徽章外框或底板。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
 - 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
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
