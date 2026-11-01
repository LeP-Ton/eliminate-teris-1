# 重设计指尖火花、步步有解和挑战常客

## 背景与目标
- 对应会话：会话-83 起；分支：`experiment/ui-refactor`。
- 用户明确指定重设计三项成就图标：编号 4“指尖火花”、编号 9“步步有解”、编号 20“挑战常客”。
- 沿用上一轮透明背景、无徽章外框和底板的约束，不扩展成正式预览功能。
- 本文以本轮开始的工作区快照记录增量，保留此前各轮变更文档。

## 设计与变更
- 指尖火花：改成彩色手指触碰方块、指尖亮起金色火花，表达首次通过交换触发消除。
- 步步有解：改成两枚连续落脚印走向点亮的方块，替换楼梯路线和终点星的旧构图。
- 挑战常客：改成叠放的街机挑战票券与星形印记，替换月桂和数字 20 的旧构图。
- 三种图案继续共用彩色与灰色状态的绘制、缓存和等比缩放。
- 更新现有真实标签测试的临时解锁编号为 4、9、20，分别检查点击回调并导出实际标签效果。
- 模式规则、成就条件、玩家存档和其余图标不参与本轮修改，无需更新整体核心架构认知。

## 阶段与 TODO
- [x] 完成三个独立图案的重绘。
- [x] 在真实首页标签内检查小尺寸效果与点击行为。
- [x] 更新测试总览与真实标签图。
- [x] 完成回归及图标变更范围检查。
- [x] 更新根索引、说明与全部逐行 diff。

## 测试方法与结果
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：5 项通过，0 失败；完成于 2026-10-31 21:05:02。
- 检查所有图标和灰色状态可见、32 枚图案身份不同、百/千/万档可区分、正式面板无预览入口及测试不修改玩家数据。
- 真实首页标签测试分别点击编号 4、9、20，回调均匹配，并导出三个图案的标签效果图。
- 人工查看三个图标的实际标签渲染，确认保持无外框且图案未裁切。
- 使用 AppKit 读取本轮基线和新总览 PNG，逐像素比较每个成就区域：仅编号 4、9、20 改变，其余 29 个区域完全一致。
- `git diff --check`：通过。
- 本次为局部图案调整，使用现有图标专项回归，未新增重复实现的测试，未重启游戏或修改实际玩家存档。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 284708 | `924bfb4fde4111af0d5ed9a449ad7af50774822f46b235dc114c99fc32999290` |
| `docs/previews/achievement-labels.png` | 52038 | `2711271c9c66fcb3e5533f8c7254efdaaf6590f0ee6e26b483676e97ca520390` |

## 代码变更

以下为本轮全部源码、测试、说明与索引的逐行 diff；两张测试图片以二进制变更和上述校验值记录。

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- a/Sources/AchievementBadgeArtwork.swift
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -87,12 +87,12 @@
                 case 1: joystick()
                 case 2: rhythm()
                 case 3: flag(checkered: false)
-                case 4: spark()
+                case 4: fingertipSpark()
                 case 5: line(count: 4)
                 case 6: line(count: 5)
                 case 7: cascade(count: 2)
                 case 8: cascade(count: 3)
-                case 9: steps()
+                case 9: steppingTrail()
                 case 10: trophy()
                 case 11: flame()
                 case 12: crown()
@@ -103,7 +103,7 @@
                 case 17: collection(level: 1)
                 case 18: collection(level: 2)
                 case 19: collection(level: 3)
-                default: laurel()
+                default: challengePasses()
                 }
             }
         }
@@ -136,10 +136,26 @@
             rect(11, 34, 10, 3, gold)
         }
 
-        private func spark() {
-            rect(17, 25, 14, 10, blue, radius: 2)
-            star(24, 19, radius: 9, color: gold)
-            star(12, 15, radius: 2.5, color: coral); star(36, 25, radius: 2.8, color: teal)
+        private func fingertipSpark() {
+            // 指尖触碰方块，短促的金色火花强调“首次交换触发消除”。
+            rect(27, 12, 10, 10, blue, radius: 2)
+            rect(28.5, 13.5, 7, 1.3, .white.withAlphaComponent(0.65), radius: 0.5)
+            let hand = NSBezierPath()
+            hand.move(to: NSPoint(x: 18, y: 35)); hand.line(to: NSPoint(x: 12, y: 26))
+            hand.curve(to: NSPoint(x: 16, y: 23), controlPoint1: NSPoint(x: 9, y: 22), controlPoint2: NSPoint(x: 13, y: 20))
+            hand.line(to: NSPoint(x: 19, y: 26)); hand.line(to: NSPoint(x: 19, y: 16))
+            hand.curve(to: NSPoint(x: 24, y: 16), controlPoint1: NSPoint(x: 19, y: 12), controlPoint2: NSPoint(x: 24, y: 12))
+            hand.line(to: NSPoint(x: 24, y: 23))
+            hand.curve(to: NSPoint(x: 33, y: 25), controlPoint1: NSPoint(x: 27, y: 21), controlPoint2: NSPoint(x: 31, y: 21))
+            hand.line(to: NSPoint(x: 33, y: 31)); hand.line(to: NSPoint(x: 29, y: 36)); hand.close()
+            let peach = NSColor(calibratedRed: 1, green: 0.73, blue: 0.48, alpha: 1)
+            fill(hand, peach); stroke(hand, mix(peach, coral, 0.35), width: 0.65)
+            rect(17, 34, 14, 5.5, teal, radius: 1.5)
+            star(21.5, 9, radius: 4.8, color: gold)
+            let rays = NSBezierPath()
+            rays.move(to: NSPoint(x: 12, y: 13)); rays.line(to: NSPoint(x: 9, y: 11))
+            rays.move(to: NSPoint(x: 30, y: 7)); rays.line(to: NSPoint(x: 32, y: 5))
+            stroke(rays, coral, width: 1.7)
         }
 
         private func line(count: Int) {
@@ -157,10 +173,17 @@
             fill(arrow, base)
         }
 
-        private func steps() {
-            for index in 0..<3 { rect(10 + CGFloat(index) * 8, 29 - CGFloat(index) * 5, 8, 7, [blue, teal, gold][index]) }
-            let route = NSBezierPath(); route.move(to: NSPoint(x: 12, y: 24)); route.line(to: NSPoint(x: 20, y: 24)); route.line(to: NSPoint(x: 20, y: 18)); route.line(to: NSPoint(x: 29, y: 18)); stroke(route, base, width: 2.2)
-            star(35, 14, radius: 5, color: gold)
+        private func steppingTrail() {
+            // 两枚落脚印走向亮起的方块，避免继续使用勾选圈或楼梯状功能图标。
+            for (x, y, color) in [(CGFloat(16), CGFloat(26), blue), (CGFloat(29), CGFloat(17), teal)] {
+                NSGraphicsContext.saveGraphicsState()
+                let tilt = NSAffineTransform(); tilt.translateX(by: x, yBy: y); tilt.rotate(byDegrees: 22); tilt.concat()
+                fill(NSBezierPath(roundedRect: NSRect(x: -3.6, y: -7, width: 7.2, height: 11), xRadius: 3.6, yRadius: 3.6), color)
+                rect(-2.8, 6, 5.6, 4, color, radius: 1.5)
+                NSGraphicsContext.restoreGraphicsState()
+            }
+            rect(33, 7, 6.3, 6.3, gold, radius: 1.4)
+            star(39, 7, radius: 2.7, color: gold)
         }
 
         private func trophy() {
@@ -217,13 +240,27 @@
             star(35, 12, radius: 3.4, color: gold)
         }
 
-        private func laurel() {
-            for side: CGFloat in [-1, 1] {
-                for row in 0..<4 { fill(NSBezierPath(ovalIn: NSRect(x: 23 + side * (11 - CGFloat(row) * 0.7) - 3, y: 15 + CGFloat(row) * 4, width: 5, height: 7)), teal) }
-            }
-            star(24, 13, radius: 4, color: gold)
-            tone(base).setFill()
-            ("20" as NSString).draw(in: NSRect(x: 14, y: 21, width: 20, height: 14), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .heavy), .foregroundColor: tone(base)])
+        private func challengePasses() {
+            // 叠放的街机挑战票券表现多次参赛，不再把累计次数直接画成图标。
+            for (index, color) in [blue, teal, gold].enumerated() {
+                NSGraphicsContext.saveGraphicsState()
+                let tilt = NSAffineTransform(); tilt.translateX(by: 24, yBy: 24)
+                tilt.rotate(byDegrees: CGFloat(index - 1) * 13); tilt.translateX(by: -24, yBy: -24); tilt.concat()
+                let y = 11 + CGFloat(index) * 6
+                let ticket = NSBezierPath()
+                ticket.move(to: NSPoint(x: 12, y: y)); ticket.line(to: NSPoint(x: 36, y: y))
+                ticket.line(to: NSPoint(x: 36, y: y + 4))
+                ticket.curve(to: NSPoint(x: 36, y: y + 10), controlPoint1: NSPoint(x: 31, y: y + 4), controlPoint2: NSPoint(x: 31, y: y + 10))
+                ticket.line(to: NSPoint(x: 36, y: y + 14)); ticket.line(to: NSPoint(x: 12, y: y + 14))
+                ticket.line(to: NSPoint(x: 12, y: y + 10))
+                ticket.curve(to: NSPoint(x: 12, y: y + 4), controlPoint1: NSPoint(x: 17, y: y + 10), controlPoint2: NSPoint(x: 17, y: y + 4))
+                ticket.close(); fill(ticket, color)
+                if index == 2 {
+                    star(23, y + 7, radius: 4, color: coral)
+                    for dot in 0..<4 { circle(30, y + 2 + CGFloat(dot) * 3.3, 0.65, .white) }
+                }
+                NSGraphicsContext.restoreGraphicsState()
+            }
         }
 
         private func piece(_ kind: PieceKind, count: Int) {
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -105,7 +105,7 @@
         XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
     }
 
-    func testRhythmAndStepsBadgesRenderAndRemainClickableInHomeLabels() throws {
+    func testRedesignedBadgesRenderAndRemainClickableInHomeLabels() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
@@ -113,7 +113,7 @@
         let domain = "badge-label-preview.\(UUID().uuidString)"
         let fixture = try XCTUnwrap(UserDefaults(suiteName: domain))
         defer { fixture.removePersistentDomain(forName: domain) }
-        fixture.set(["version": 1, "unlocked": [2, 9], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        fixture.set(["version": 1, "unlocked": [4, 9, 20], "metrics": [:]], forKey: AchievementsManager.storageKey)
         let progress = AchievementsManager(defaults: fixture)
         let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
         home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
@@ -121,7 +121,7 @@
         home.layoutSubtreeIfNeeded()
         var selected: Int?
         home.onAchievement = { selected = $0 }
-        for id in [2, 9] {
+        for id in [4, 9, 20] {
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
 
-- 使用首页真实标签组件渲染，重点展示“节奏初现”和“步步有解”。
+- 使用首页真实标签组件渲染，重点展示“指尖火花”“步步有解”和“挑战常客”。
 - 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
 ## 全部 32 枚徽章
@@ -14,7 +14,7 @@
 ![全部成就徽章](achievement-icons.png)
 
 - 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
-- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、阶梯终点星等游戏图案。
+- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用无外框、无底板的彩色摇杆、节拍光柱、指尖消除火花、落脚路径、挑战票券等游戏图案。
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
+`workflow/20261031210746-redesign-three-achievement-icons.md` - 会话-83 起重设计指尖火花、步步有解和挑战常客：指尖消除火花、落脚路径及挑战票券；保持无外框，含完整增量 diff、5 项回归及其余 29 个图标逐像素一致检查。
 `workflow/20261031205241-remove-achievement-badge-frames.md` - 会话-81 起按反馈去掉成就徽章的盾牌外框、底板和投影，保留透明彩色主题图案并放大 12%；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031204033-game-badges-test-only-preview.md` - 会话-76 起移除正式图标预览入口和页面，将全部图标展示收回测试 target；成就重绘为彩色街机收藏徽章，重点替换节奏/步步有解，含完整逐行 diff、标签测试图和 51 项回归。
 `workflow/20261031201958-icon-aspect-and-achievement-gallery.md` - 会话-71 起修复系统图标拉伸与竞分奖杯缺失，统一全部成就图标，新增无需解锁的图标预览与可分享总览；含全部逐行 diff、50 项完整回归及真实渲染验收。
@@ -72,6 +73,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整编号 4/9/20 的指尖火花、落脚路径和挑战票券图案，或查看三个重设计图标的真实标签测试图时，读取 `20261031210746-redesign-three-achievement-icons.md`。
 - 需要确认成就图标为何没有徽章外框、调整透明图案的主体缩放或查看去边框效果时，读取 `20261031205241-remove-achievement-badge-frames.md`。
 - 需要调整彩色游戏成就徽章、节奏光柱/阶梯终点星、测试总览导出，或确认正式应用为何没有预览入口时，读取 `20261031204033-game-badges-test-only-preview.md`。
 - 需要调整模式/成就图标的比例、奖杯兼容路径、32 枚图标映射或无需解锁的图标预览入口时，读取 `20261031201958-icon-aspect-and-achievement-gallery.md`。
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
