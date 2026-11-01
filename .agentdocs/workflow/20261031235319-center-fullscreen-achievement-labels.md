# 修复全屏时首页成就标签图文未居中

## 背景与目标
- 对应会话-113：用户反馈全屏后成就标签内的图标和文字没有居中。
- 本轮只修改首页标签的绘制位置，保留标签数量、尺寸、图案、点击回调、提示与真实解锁状态。

## 原因与修复
- `HomeAchievementButton` 原先固定在 x=13/42/89 处绘制状态图标、成就图案、文字，卡片变宽时图文不会跟随居中。
- 以状态图标 20 点、成就图案 38 点、固定间隔与文字实际宽度构成整体，再按卡片中心计算起点；两枚图标继续垂直居中。
- 字体度量用于文字的垂直中心，避免固定文本框偏移。
- 窄窗口先按完整 Character（字符簇）截短并加省略号，再测量最终可见文字。这样不会因原生省略算法留下空余字符槽，使图文视觉偏左。
- 原始名称仍来自本地化定义，既有辅助功能和详情点击语义保留。
- 本轮不涉及核心架构，无需更新 `AGENTS.md`。

## 阶段与 TODO
- [x] 定位固定左侧绘制坐标。
- [x] 添加读取实际绘制像素的回归，复现宽窗口偏左。
- [x] 改为整体居中，并处理长名称省略后的实际宽度。
- [x] 完成普通窗口、全屏等效宽度与缩回窗口尺寸验证。
- [x] 更新实际标签测试图与变更文档。

## 测试方法与结果
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'GameIconPresentationTests|HomeDashboardTests'`。
- 最终结果：2026-10-31 23:52:04，12 项通过，0 失败。
- 新回归读取实际渲染的深色/彩色像素，排除透明圆角、浅色底板和边框，独立测量图文整体中心，不复用实现中的排版计算。
- 覆盖五语言 × 锁定/解锁 × 960/1440/1920/2560/1180 五种宽度 × 五枚标签，共 250 组检查，同时验证水平与垂直中心。
- 尺寸顺序覆盖宽度扩大后再缩回普通窗口；测试使用全屏等效尺寸，不自动触发系统全屏切换动画。
- 原实现运行该回归出现 210 处失败；第一版修复宽窗口后，窄窗口长名称仍有 12 处偏差，加入最终可见文字测量后全部通过。
- 既有测试继续覆盖图标比例、三种模式、32 枚成就、正式面板无测试入口、标签点击与首页固定规则。
- 截图来自隔离测试存档，不修改玩家解锁数据；已查看普通及 1920 宽度标签实际截图。
- 静态检查：`git diff --check`。

## 手工测试
1. 使用 `./run.sh` 启动，将主窗口切换全屏。
2. 观察底部五枚标签：状态图标、成就图案及名称作为整体位于卡片中心。
3. 退出全屏并缩小窗口，检查长名称省略后依旧居中；切换语言检查相同效果。
4. 点击标签确认详情可正常打开。

## 全部增量 diff
- 基线为本轮开始时的工作区；此前未提交的 UI 改动保持不变。

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -143,11 +143,26 @@
     override func draw(_ dirtyRect: NSRect) {
         guard let definition else { return }
         HomeStyle.card(bounds)
+        let title = AchievementText.string(definition.titleKey)
+        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
+        // 状态、成就图案与实际文字宽度作为同一组居中；全屏时留白均分到两侧。
+        // 窄窗口先按完整字符截短，再测量包含省略号的可见文字，避免空余字槽使整体偏左。
+        let fixedWidth: CGFloat = 20 + 9 + 38 + 9
+        let availableWidth = max(0, floor(bounds.width - 28 - fixedWidth))
+        var characters = Array(title), displayedTitle = title
+        while (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth, !characters.isEmpty {
+            characters.removeLast()
+            displayedTitle = String(characters) + "…"
+        }
+        if (displayedTitle as NSString).size(withAttributes: attributes).width > availableWidth { displayedTitle = "" }
+        let titleSize = (displayedTitle as NSString).size(withAttributes: attributes)
+        let titleWidth = ceil(titleSize.width)
+        let startX = bounds.midX - (fixedWidth + titleWidth) / 2
         let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
-        HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
-        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: 42, y: bounds.midY - 19, width: 38, height: 38),
+        HomeStyle.symbol(status, in: NSRect(x: startX, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
+        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: startX + 29, y: bounds.midY - 19, width: 38, height: 38),
                                                                            from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
-        HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: 89, y: bounds.midY - 9, width: bounds.width - 98, height: 22), size: 13, weight: .semibold,
+        HomeStyle.text(displayedTitle, in: NSRect(x: startX + fixedWidth, y: bounds.midY - titleSize.height / 2, width: titleWidth, height: titleSize.height), size: 13, weight: .semibold,
                        color: unlocked ? HomeStyle.ink : HomeStyle.muted)
     }
 }
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -132,4 +132,55 @@
         home.cacheDisplay(in: strip, to: bitmap)
         try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-game-badge-labels.png"))
     }
+
+    func testHomeBadgesStayCenteredAtFullscreenWidths() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let snapshot = GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
+                                    targetScore: nil, isRunning: false, isFinished: false)
+        for unlocked in [[], [1, 2, 3, 4, 5]] {
+            defaults.set(["version": 1, "unlocked": unlocked, "metrics": [:]], forKey: AchievementsManager.storageKey)
+            let progress = AchievementsManager(defaults: defaults)
+            let home = HomeDashboardView(frame: .zero)
+            for language in AppLanguage.allCases {
+                Localizer.shared.setLanguage(language)
+                for width: CGFloat in [960, 1440, 1920, 2560, 1180] {
+                    home.setFrameSize(NSSize(width: width, height: width > 1440 ? 1080 : 800))
+                    home.refresh(snapshot: snapshot, mode: .free, manager: progress)
+                    home.layoutSubtreeIfNeeded()
+                    let badges = home.subviews.compactMap { $0 as? HomeButton }.filter { $0.toolTip != nil }
+                    XCTAssertEqual(badges.count, 5)
+                    for badge in badges {
+                        let pixels = try XCTUnwrap(badge.bitmapImageRepForCachingDisplay(in: badge.bounds))
+                        badge.cacheDisplay(in: badge.bounds, to: pixels)
+                        let scale = CGFloat(pixels.pixelsWide) / badge.bounds.width
+                        var minX = pixels.pixelsWide, minY = pixels.pixelsHigh, maxX = -1, maxY = -1
+                        // 读取真实像素中的图标和文字，忽略浅色卡片及边框，不复制布局算法。
+                        let insetX = Int(8 * scale), insetY = Int(4 * scale)
+                        for y in stride(from: insetY, to: pixels.pixelsHigh - insetY, by: 2) {
+                            for x in stride(from: insetX, to: pixels.pixelsWide - insetX, by: 2) {
+                                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
+                                      color.alphaComponent > 0.5,
+                                      min(color.redComponent, color.greenComponent, color.blueComponent) < 0.78 else { continue }
+                                minX = min(minX, x); maxX = max(maxX, x)
+                                minY = min(minY, y); maxY = max(maxY, y)
+                            }
+                        }
+                        XCTAssertGreaterThan(maxX, minX)
+                        let centerX = CGFloat(minX + maxX + 1) / (2 * scale)
+                        let centerY = CGFloat(minY + maxY + 1) / (2 * scale)
+                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 3.5, "\(language.rawValue) / \(width)：标签图文应整体水平居中")
+                        XCTAssertEqual(centerY, badge.bounds.midY, accuracy: 3, "\(language.rawValue) / \(width)：标签图文应垂直居中")
+                    }
+                    if language == .chineseSimplified, width == 1920, !unlocked.isEmpty {
+                        let strip = try XCTUnwrap(badges.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
+                        let image = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: strip))
+                        home.cacheDisplay(in: strip, to: image)
+                        try XCTUnwrap(image.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-fullscreen-badge-labels.png"))
+                    }
+                }
+            }
+        }
+    }
 }
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031235319-center-fullscreen-achievement-labels.md` - 会话-113 起修复首页成就标签全屏时图文偏左：按状态图标、成就图案与最终可见文字整体居中，兼容长名称省略和宽度恢复；含全部增量 diff、真实标签图及 12 项回归。
 `workflow/20261031233928-polish-game-utility-panels.md` - 会话-106 起统一重构游戏设置、玩法说明与挑战记录：主题卡片、金色音量滑杆、三步图文教学、动画模式切换、个人最佳及金银铜排行；含全部增量 diff、五语言/小窗口截图与 60 项完整回归。
 `workflow/20261031231944-simplify-achievement-heading.md` - 会话-103 起简化成就页标题，移除分隔点与已解锁统计，前置图标改为彩色奖章；含全部增量 diff、真实截图与 4 项界面回归。
 `workflow/20261031230317-animated-achievement-filter.md` - 会话-97 起将成就筛选改为暖白金色一体式滑轨，加入数量提示、0.24 秒滑动、快速打断接续与减少动态效果支持；含全部逐行 diff、真实动画/截图和 55 项完整回归。
@@ -79,6 +80,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要修复首页成就标签全屏/宽窗口的图文居中、长名称截短或尺寸恢复时，读取 `20261031235319-center-fullscreen-achievement-labels.md`。
 - 需要调整设置控件、玩法教学卡片、挑战排行榜/空状态、辅助面板滚动与定位，或查看实际测试图时，读取 `20261031233928-polish-game-utility-panels.md`。
 - 需要调整成就页简洁标题、前置彩色奖章或核对本轮标题变更时，读取 `20261031231944-simplify-achievement-heading.md`。
 - 需要调整成就页筛选滑块的美术、动画、数量、原生选择兼容或五语言布局时，读取 `20261031230317-animated-achievement-filter.md`。
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -35,6 +35,7 @@
 ![成就标签实际效果](achievement-labels.png)
 
 - 使用首页真实标签组件渲染，重点展示“百格起步”“千格熟手”和“万格旅人”的尺寸与居中效果。
+- [全屏尺寸标签效果](achievement-labels-fullscreen.png)：1920 宽度下五枚标签的状态图标、成就图案与文字作为整体居中；缩回窄窗口时长名称按最终省略文本重新居中。
 - 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
 ## 全部 32 枚徽章
@@ -53,7 +54,7 @@
 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests
 ```
 
-将系统临时目录中的 `eliminate-all-achievement-icons.png` 和 `eliminate-game-badge-labels.png` 分别复制为本目录中的 `achievement-icons.png` 和 `achievement-labels.png`。
+将系统临时目录中的 `eliminate-all-achievement-icons.png` 和 `eliminate-game-badge-labels.png` 分别复制为本目录中的 `achievement-icons.png` 和 `achievement-labels.png`；`eliminate-fullscreen-badge-labels.png` 复制为 `achievement-labels-fullscreen.png`。
 
 更新筛选条动画与完整成就页截图：
 
```

### `docs/previews/achievement-labels.png`

```diff
- 原标签图文固定靠左。
+ 更新普通窗口真实标签截图，图标与可见文字整体居中。
```

- 原 SHA-256：`d68a4e97010cd3aabfea52579e808091b0cad135dc9b05ad72d57451026f3661`
- 新 SHA-256：`9e43cd05c6a7a08ab7eee2d2e3d2dd547a24749c3f27035f281bbdcdffabda06`

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 无全屏尺寸标签预览。
+ 新增 1920 宽度真实标签截图，图标与可见文字整体居中。
```

- 新 SHA-256：`bdda2ead4b033c2381a16e76c2d6c9215bcfec570657033eafc92709db055880`
