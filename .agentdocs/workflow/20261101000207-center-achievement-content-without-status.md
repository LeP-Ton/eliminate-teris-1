# 更正成就标签居中范围：状态独立，仅图案与名称居中

## 背景与目标
- 对应会话-119：用户明确“已完成或未解锁”的状态图标不属于需要居中的内容。
- 上一轮误将状态标记也纳入图文组；本轮更正该理解，保留已完成的长名称处理与五枚布局。
- 本文取代 `20261031235319-center-fullscreen-achievement-labels.md` 中三者一起居中的设计，旧文保留历史记录。

## 实现
- 状态标记独立固定在 x=13、宽 20 点的位置，保持垂直居中。
- 成就图案 38 点与名称之间保持 9 点间隔，只有这两者的总宽度参与居中计算。
- 居中参考为整张卡片的中心；两侧对称预留 34 点安全区域，避免窄窗口时内容碰到左侧状态。
- 长名称继续按完整字符截短，使用最终可见文本宽度排版。
- 既有图案、状态、点击详情、辅助功能和存档语义保留。
- 本轮仅修正局部绘制，不影响核心认知，无需更新 `AGENTS.md`。

## 阶段与 TODO
- [x] 分离左侧状态标记与居中图文组。
- [x] 更正像素回归的检测范围，并独立验证状态固定位置。
- [x] 验证五语言、锁定/解锁及普通到全屏宽度。
- [x] 更新真实预览、索引与完整增量 diff。

## 测试方法与结果
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameIconPresentationTests|HomeDashboardTests'`。
- 最终结果：2026-11-01 00:01:22，12 项通过，0 失败。
- 像素回归独立扫描左侧状态标记，验证其中心始终位于 x=23 附近，避免再次将状态参与居中。
- 右侧扫描区域只测成就图案与名称；由于透明图案画布的主体留白不完全对称，像素外沿检查容许 5 点光学差异，几何布局仍按图案视口与可见文本居中。
- 覆盖五语言 × 两种解锁状态 × 五种宽度 × 五枚标签，共 250 组；宽度为 960/1440/1920/2560/1180，包含扩大后缩回窗口的顺序。
- 既有首页点击、标签点击、图案完整性/比例与数据隔离测试全部通过。
- 已检查普通及 1920 宽度的真实标签截图；没有触发系统全屏动画。
- 静态检查：`git diff --check`。

## 手工测试
1. `./run.sh` 启动后切换全屏，观察左侧状态标记位置保持一致。
2. 确认居中的仅为成就图案与名称，而非状态、图案、名称三者。
3. 退出全屏、缩小窗口、切换语言，确认名称省略后仍居中且状态不移动。

## 本轮全部增量 diff
- 基线为本轮开始时的工作区，保留此前尚未提交的其他 UI 变更。

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -145,10 +145,11 @@
         HomeStyle.card(bounds)
         let title = AchievementText.string(definition.titleKey)
         let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
-        // 状态、成就图案与实际文字宽度作为同一组居中；全屏时留白均分到两侧。
+        // 仅成就图案与文字作为一组居中；完成/锁定状态独立固定在左侧。
         // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
-        let fixedWidth: CGFloat = 20 + 9 + 38 + 9
-        let availableWidth = max(0, floor(bounds.width - 28 - fixedWidth))
+        let fixedWidth: CGFloat = 38 + 9
+        // 左侧状态占据 13...33 点，居中内容两侧对称预留 34 点，避免窄窗口重叠。
+        let availableWidth = max(0, floor(bounds.width - 34 * 2 - fixedWidth))
         var characters = Array(title), displayedTitle = title
         while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
             characters.removeLast()
@@ -159,8 +160,8 @@
         let titleWidth = ceil(titleSize.width)
         let startX = bounds.midX - (fixedWidth + titleWidth) / 2
         let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
-        HomeStyle.symbol(status, in: NSRect(x: startX, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
-        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: startX + 29, y: bounds.midY - 19, width: 38, height: 38),
+        HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
+        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: startX, y: bounds.midY - 19, width: 38, height: 38),
                                                                            from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
         HomeStyle.text(displayedTitle, in: NSRect(x: startX + fixedWidth, y: bounds.midY - titleSize.height / 2, width: titleWidth, height: titleSize.height), size: 13, weight: .semibold,
                        color: unlocked ? HomeStyle.ink : HomeStyle.muted)
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -156,21 +156,30 @@
                         badge.cacheDisplay(in: badge.bounds, to: pixels)
                         let scale = CGFloat(pixels.pixelsWide) / badge.bounds.width
                         var minX = pixels.pixelsWide, minY = pixels.pixelsHigh, maxX = -1, maxY = -1
-                        // 读取真实像素中的图标和文字，忽略浅色卡片及边框，不复制布局算法。
+                        var statusMinX = pixels.pixelsWide, statusMaxX = -1
+                        // 状态标记单独检查；居中测量仅包含成就图案与文字，忽略浅色卡片和边框。
                         let insetX = Int(8 * scale), insetY = Int(4 * scale)
                         for y in stride(from: insetY, to: pixels.pixelsHigh - insetY, by: 2) {
                             for x in stride(from: insetX, to: pixels.pixelsWide - insetX, by: 2) {
                                 guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                                       color.alphaComponent > 0.5,
                                       min(color.redComponent, color.greenComponent, color.blueComponent) < 0.78 else { continue }
-                                minX = min(minX, x); maxX = max(maxX, x)
-                                minY = min(minY, y); maxY = max(maxY, y)
+                                if CGFloat(x) / scale < 34 {
+                                    statusMinX = min(statusMinX, x); statusMaxX = max(statusMaxX, x)
+                                } else {
+                                    minX = min(minX, x); maxX = max(maxX, x)
+                                    minY = min(minY, y); maxY = max(maxY, y)
+                                }
                             }
                         }
                         XCTAssertGreaterThan(maxX, minX)
+                        XCTAssertGreaterThan(statusMaxX, statusMinX, "完成/锁定标记应独立保留在左侧")
+                        XCTAssertEqual(CGFloat(statusMinX + statusMaxX + 1) / (2 * scale), 23, accuracy: 2,
+                                       "状态标记位置不应随名称或窗口宽度改变")
                         let centerX = CGFloat(minX + maxX + 1) / (2 * scale)
                         let centerY = CGFloat(minY + maxY + 1) / (2 * scale)
-                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 3.5, "\(language.rawValue) / \(width)：标签图文应整体水平居中")
+                        // 成就图案透明画布的左右留白可不同，像素外沿容许 5 点光学差异。
+                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 5, "\(language.rawValue) / \(width)：仅成就图案与文字水平居中")
                         XCTAssertEqual(centerY, badge.bounds.midY, accuracy: 3, "\(language.rawValue) / \(width)：标签图文应垂直居中")
                     }
                     if language == .chineseSimplified, width == 1920, !unlocked.isEmpty {
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261101000207-center-achievement-content-without-status.md` - 会话-119 起更正居中范围：完成/锁定状态固定左侧，仅成就图案与名称按卡片中心对齐；含全部增量 diff、更新预览及 12 项回归，取代上一轮三者合并居中的设计。
 `workflow/20261031235319-center-fullscreen-achievement-labels.md` - 会话-113 起修复首页成就标签全屏时图文偏左：按状态图标、成就图案与最终可见文字整体居中，兼容长名称省略和宽度恢复；含全部增量 diff、真实标签图及 12 项回归。
 `workflow/20261031233928-polish-game-utility-panels.md` - 会话-106 起统一重构游戏设置、玩法说明与挑战记录：主题卡片、金色音量滑杆、三步图文教学、动画模式切换、个人最佳及金银铜排行；含全部增量 diff、五语言/小窗口截图与 60 项完整回归。
 `workflow/20261031231944-simplify-achievement-heading.md` - 会话-103 起简化成就页标题，移除分隔点与已解锁统计，前置图标改为彩色奖章；含全部增量 diff、真实截图与 4 项界面回归。
@@ -80,6 +81,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认成就标签居中范围、状态标记固定左侧及图案与名称单独居中的布局时，优先读取 `20261101000207-center-achievement-content-without-status.md`。
 - 需要修复首页成就标签全屏/宽窗口的图文居中、长名称截短或尺寸恢复时，读取 `20261031235319-center-fullscreen-achievement-labels.md`。
 - 需要调整设置控件、玩法教学卡片、挑战排行榜/空状态、辅助面板滚动与定位，或查看实际测试图时，读取 `20261031233928-polish-game-utility-panels.md`。
 - 需要调整成就页简洁标题、前置彩色奖章或核对本轮标题变更时，读取 `20261031231944-simplify-achievement-heading.md`。
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -35,7 +35,7 @@
 ![成就标签实际效果](achievement-labels.png)
 
 - 使用首页真实标签组件渲染，重点展示“百格起步”“千格熟手”和“万格旅人”的尺寸与居中效果。
-- [全屏尺寸标签效果](achievement-labels-fullscreen.png)：1920 宽度下五枚标签的状态图标、成就图案与文字作为整体居中；缩回窄窗口时长名称按最终省略文本重新居中。
+- [全屏尺寸标签效果](achievement-labels-fullscreen.png)：1920 宽度下每枚标签的状态标记固定左侧，成就图案与名称单独在卡片中心对齐；缩回窄窗口时长名称按最终省略文本重新居中。
 - 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
 ## 全部 32 枚徽章
```

### `docs/previews/achievement-labels.png`

```diff
- 状态标记与图案、名称一起居中。
+ 状态标记固定左侧，仅成就图案与名称居中。
```

- 原 SHA-256：`9e43cd05c6a7a08ab7eee2d2e3d2dd547a24749c3f27035f281bbdcdffabda06`
- 新 SHA-256：`6fdd0a9cc1a69bce3a0081cd593336dad9e063030407e106906447a3eac32181`

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 状态标记与图案、名称一起居中。
+ 状态标记固定左侧，仅成就图案与名称居中。
```

- 原 SHA-256：`bdda2ead4b033c2381a16e76c2d6c9215bcfec570657033eafc92709db055880`
- 新 SHA-256：`49c35a9735b529f9210d779312054d5d7922af8133d42098545e13413cc84dc9`
