# 简化成就页标题与彩色奖章

## 背景与目标
- 对应会话-103：标题去掉“成就”后面的分隔点及已解锁统计，前面的图标改为彩色。
- 标题沿用现有本地化“成就”；筛选条数量与成就规则不变。

## 阶段与 TODO
- [x] 标题改为现有 `panel.achievements` 文案。
- [x] 用非模板彩色奖章替换单色系统图标，保持原尺寸与比例。
- [x] 导出并查看真实面板截图，更新开发测试预览。
- [x] 运行现有界面测试，记录本轮全部增量 diff。

## 实现与边界
- 彩色奖章通过 AppKit 原生路径绘制并缓存，金色圆面配蓝红缎带，保持奖章语义。
- 图像设为非模板并取消模板染色，使用等比缩放。
- 本轮仅调整成就页页头，不涉及存档、解锁判定及首页展示。
- 没有核心架构变化，无需更新 `AGENTS.md`。

## 代码与预览变更
- 以下 diff 以本轮开始时的工作区为基线，保留先前尚未提交的变更。

### `Sources/AchievementViews.swift`

```diff
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -184,6 +184,35 @@
     static let muted = HomeStyle.secondary
     static let controlFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
 
+    /// 标题使用独立的彩色奖章，保持原有奖章语义，不受系统模板染色影响。
+    static let headingIcon: NSImage = {
+        let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { _ in
+            for (points, color) in [
+                ([NSPoint(x: 11, y: 24), NSPoint(x: 24, y: 27), NSPoint(x: 20, y: 44), NSPoint(x: 15, y: 39), NSPoint(x: 9, y: 42)], HomeStyle.blue),
+                ([NSPoint(x: 24, y: 27), NSPoint(x: 37, y: 24), NSPoint(x: 39, y: 42), NSPoint(x: 32, y: 39), NSPoint(x: 28, y: 44)], NSColor.systemRed)
+            ] {
+                let ribbon = NSBezierPath(); ribbon.move(to: points[0])
+                points.dropFirst().forEach { ribbon.line(to: $0) }; ribbon.close()
+                color.setFill(); ribbon.fill()
+            }
+            let medal = NSBezierPath(ovalIn: NSRect(x: 8, y: 4, width: 32, height: 32))
+            NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.92, blue: 0.57, alpha: 1),
+                                HomeStyle.yellow, NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.08, alpha: 1)])?.draw(in: medal, angle: -90)
+            let star = NSBezierPath()
+            for index in 0..<10 {
+                let angle = CGFloat(index) * .pi / 5 - .pi / 2
+                let radius: CGFloat = index.isMultiple(of: 2) ? 8.5 : 4
+                let point = NSPoint(x: 24 + cos(angle) * radius, y: 20 + sin(angle) * radius)
+                if index == 0 { star.move(to: point) } else { star.line(to: point) }
+            }
+            star.close()
+            NSColor(calibratedRed: 0.77, green: 0.43, blue: 0.05, alpha: 1).setFill(); star.fill()
+            return true
+        }
+        image.isTemplate = false
+        return image
+    }()
+
     static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
         let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
         (selected ? NSColor(calibratedRed: 0.9, green: 0.96, blue: 1, alpha: 1) : NSColor.white).setFill()
@@ -304,7 +333,7 @@
 
     func refresh() {
         window?.title = AchievementText.string("panel.achievements")
-        heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
+        heading.stringValue = AchievementText.string("panel.achievements")
         backButton.title = AchievementText.string("achievement.view_all")
         backButton.invalidateIntrinsicContentSize()
         backButton.isHidden = detailID == nil
@@ -365,8 +394,7 @@
         backButton.action = #selector(showAll)
         let actions = NSStackView(views: [filter, backButton])
         actions.orientation = .horizontal
-        let icon = NSImageView(image: NSImage(systemSymbolName: "rosette", accessibilityDescription: nil) ?? NSImage())
-        icon.contentTintColor = AchievementPanelStyle.accent
+        let icon = NSImageView(image: AchievementPanelStyle.headingIcon)
         icon.imageScaling = .scaleProportionallyUpOrDown
         icon.translatesAutoresizingMaskIntoConstraints = false
         icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -9,7 +9,7 @@
 - 共用暖白轨道，黄色选中滑块在全部、未解锁、已解锁之间移动，显示对应数量。
 - 过渡时长 0.24 秒，快速切换从当前视觉位置接续；系统减少动态效果开启时即时切换。
 - 动画由真实 Core Animation（核心动画）展示层导出，测试入口不进入正式应用。
-- [查看成就页完整效果](achievement-panel.png)。页面中的进度和时间来自隔离测试存档。
+- [查看成就页完整效果](achievement-panel.png)。页头仅显示“成就”与彩色奖章；页面中的进度和时间来自隔离测试存档。
 
 ## 标签实际效果
 
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031231944-simplify-achievement-heading.md` - 会话-103 起简化成就页标题，移除分隔点与已解锁统计，前置图标改为彩色奖章；含全部增量 diff、真实截图与 4 项界面回归。
 `workflow/20261031230317-animated-achievement-filter.md` - 会话-97 起将成就筛选改为暖白金色一体式滑轨，加入数量提示、0.24 秒滑动、快速打断接续与减少动态效果支持；含全部逐行 diff、真实动画/截图和 55 项完整回归。
 `workflow/20261031222305-remove-lifetime-milestone-stars.md` - 会话-95 起移除总累计百/千/万图案中的五角星，仅保留三档方块并重新居中；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031221440-normalize-lifetime-milestone-icons.md` - 会话-92 起调整百格/千格/万格累计成就图案的单格大小与整体居中，三档视觉尺寸接近；含完整增量 diff、像素边界测量、测试图与 5 项图标回归。
@@ -77,6 +78,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整成就页简洁标题、前置彩色奖章或核对本轮标题变更时，读取 `20261031231944-simplify-achievement-heading.md`。
 - 需要调整成就页筛选滑块的美术、动画、数量、原生选择兼容或五语言布局时，读取 `20261031230317-animated-achievement-filter.md`。
 - 需要确认总累计百/千/万图案为何没有五角星、查看纯方块效果或居中调整时，读取 `20261031222305-remove-lifetime-milestone-stars.md`。
 - 需要调整百格起步、千格熟手、万格旅人的整体尺寸差距和垂直居中时，读取 `20261031221440-normalize-lifetime-milestone-icons.md`。
```

### `docs/previews/achievement-panel.png`

```diff
- 原成就页截图：标题包含分隔点及解锁统计，使用单色奖章。
+ 更新真实渲染截图：标题仅显示“成就”，使用金色奖章与蓝红缎带。
```

- 原 SHA-256：`8ec340d07481a7d7d55b20f267b68cb889f95acec511bf9354940f94c6a0726f`
- 新 SHA-256：`c9d27a614be146f8981669114a6dd369c1f90643be429951d43c24da1cb891e5`

## 测试方法与结果
- 执行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementFilterControlTests`。
- 结果：4 项通过，0 失败。
- 覆盖真实点击与快速切换动画、减少动态效果/键盘、五语言与两种窗口宽度、真实面板和动画导出。
- 人工查看导出的 `eliminate-achievement-panel-refined.png`：页头只显示“成就”，彩色奖章完整显示且垂直对齐，筛选条计数正常。
- 更新截图：`docs/previews/achievement-panel.png`，使用隔离测试存档，不修改玩家成就。
