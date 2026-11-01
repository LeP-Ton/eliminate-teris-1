# 游戏主题成就徽章与仅测试可见的总览

## 背景与目标
- 对应会话：会话-76 起；分支：`experiment/ui-refactor`。
- 用户澄清“预览全部图标”仅为测试需求，反对把预览入口与页面加入正式产品。
- 用户同时指出通用系统图标过于接近网页平台，尤其是“步步有解”的勾选圈和“节奏初现”的单音符缺少游戏美感。
- 本轮基于会话开始时的工作区快照记录增量；上一轮尚未提交的图标工作及其文档保留追溯。

## 正式功能收敛
- 移除成就面板的图标预览按钮、预览状态、图标画廊页面及其点击跳转。
- 移除五种语言中仅供该入口使用的三条预览文案。
- 删除 `Sources/AchievementIconGalleryView.swift`，不在 App target 中保留测试展示页面。
- 成就面板恢复“真实进度、筛选与详情”的既有用途。
- 全部图标的展示改由 `Tests/AchievementIconContactSheet.swift` 在 XCTest target 离屏绘制；正式应用无相关入口，也不需要假解锁玩家存档。

## 徽章设计
- 新增 `AchievementBadgeArtwork`，以 48 点画布统一绘制彩色珐琅盾牌、浅浮雕边框及各自的街机主题图案。
- “小试身手”：街机摇杆；“节奏初现”：三根彩色节拍光柱；“步步有解”：阶梯方块、路线与终点星。
- 入门、技巧、模式、累计成就使用对应摇杆、旗帜、消除火花、方块连消、奖杯、火焰、皇冠、火箭、秒表及收集方块等本地绘制。
- 类型成就保留对应方块的颜色与几何形状，百、千、万档改用一、二、三颗星。
- 未解锁时转为同形灰色徽章，已解锁时显示完整配色；图案不再由通用网页功能符号直接充当。
- `AchievementIconCatalog` 继续为首页、旧徽章组件和图鉴提供同一图案；模式图标的等比修复和奖杯兼容保持有效。

## 测试展示位置
- 全部徽章：`docs/previews/achievement-icons.png`。
- 真实首页标签：`docs/previews/achievement-labels.png`。
- 总览只由测试生成，标签使用独立的临时 UserDefaults 域模拟编号 2、9 解锁，完成后移除该测试域，不修改玩家数据。

## 阶段与 TODO
- [x] 移除正式预览入口、页面、状态与多语言文案。
- [x] 将图标总览移至仅测试使用的夹具。
- [x] 绘制完整的 32 枚游戏主题徽章及灰色状态。
- [x] 重点核对节奏/步步有解在真实首页标签中的显示和点击行为。
- [x] 完成正式面板无预览入口与数据隔离测试。
- [x] 完成完整回归、测试图导出和文档留痕。

## 测试方法与结果

### TC-001 图标完整性与身份
- 检查三种模式图标、全部 32 枚徽章的正常与灰色状态均有有效图形。
- 检查全部 32 个徽章输出各不相同；各类型百、千、万输出不同。
- 保留宽窄系统图标的比例回归，确认模式图标没有重新拉伸。
- 结果：通过。

### TC-002 正式应用无预览入口
- 构建真实成就面板，检查无“图标预览”按钮、不响应旧预览 action，仍正常显示 32 条真实进度。
- 比较前后玩家解锁列表和本地存储对象。
- 结果：通过，无新增解锁或进度写入。

### TC-003 仅测试导出全部图标
- 使用 XCTest target 中的静态夹具，覆盖五种语言并导出中文完整总览。
- 在无解锁状态下导出，不依赖或修改实际玩家进度。
- 结果：通过，已人工查看总览。

### TC-004 真实标签中重点徽章
- 在独立的临时存储域中仅模拟编号 2、9 解锁，使用真实 `HomeDashboardView` 渲染标签。
- 分别点击“节奏初现”和“步步有解”，确认仍回调正确成就编号，并导出真实标签区域。
- 结果：通过，已人工核对彩色/灰色徽章及小尺寸效果。

### TC-005 完整回归
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：51 项通过，0 失败；最终完成于 2026-10-31 20:38:32。
- 其中图标专项 5 项通过，旧成就筛选/定位/点击、游戏规则、存档兼容、设计稿主体像素与五语言检查均通过。
- `git diff --check`：通过。
- 未重启用户当前游戏。手工体验可执行 `./run.sh`，确认正式成就面板只有进度、筛选与详情。

## 测试图片校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-icons.png` | 474281 | `9e79d10f66b30441e2641c04263ee79658f92f7a9eb9bcb7c7931a040bf4788a` |
| `docs/previews/achievement-labels.png` | 60521 | `bc603896d43ad4d23334324f9b44f0e2354f41e2275b215ba7926cb1b1013147` |

## 代码变更

以下记录相对本轮开始快照的全部逐行 diff，包含删除的正式画廊代码和新增的测试夹具；二进制测试图以文件变更及校验值记录。

### `Sources/GameIcons.swift`

```diff
--- a/Sources/GameIcons.swift
+++ b/Sources/GameIcons.swift
@@ -93,47 +93,19 @@
     }
 }
 
-/// 所有成就图标的唯一映射；首页、图鉴、详情和预览共用，独立于解锁状态。
+/// 所有成就徽章的唯一入口；正式界面和测试总览使用同一幅游戏主题图案。
 enum AchievementIconCatalog {
-    private static let symbols: [Int: [String]] = [
-        1: ["hand.tap", "hand.point.up"], 2: ["music.note"], 3: ["flag"], 4: ["sparkles"],
-        5: ["square.grid.2x2"], 6: ["star"], 7: ["link"], 8: ["waveform.path", "waveform"],
-        9: ["checkmark.circle"], 10: ["timer"], 11: ["flame"], 12: ["bolt"],
-        13: ["flag.checkered", "flag"], 14: ["hare"], 15: ["bolt.circle"], 16: ["stopwatch"],
-        17: ["square.stack"], 18: ["square.stack.3d.up", "square.stack"],
-        19: ["map"], 20: ["calendar.badge.clock", "calendar"]
-    ]
     private static var cache: [String: NSImage] = [:]
 
     static func accent(for definition: AchievementDefinition) -> NSColor {
-        if case .pieceCleared(let kind, _) = definition.goal { return kind.color }
-        return HomeStyle.ink
+        AchievementBadgeArtwork.accent(for: definition)
     }
 
     static func image(for definition: AchievementDefinition, muted: Bool = false) -> NSImage {
         let key = "\(definition.id).\(muted)"
         if let cached = cache[key] { return cached }
-        let color = muted ? HomeStyle.muted : accent(for: definition)
         let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { _ in
-            if case .pieceCleared(let kind, let count) = definition.goal {
-                // 类型里程碑用四格轮廓及一、二、三颗进度点区分百、千、万档。
-                let cell: CGFloat = 11
-                for block in kind.blocks {
-                    let rect = NSRect(x: 7 + CGFloat(block.x) * cell, y: 9 + CGFloat(1 - block.y) * cell, width: 10, height: 10)
-                    color.withAlphaComponent(0.12).setFill()
-                    let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
-                    path.fill(); color.setStroke(); path.lineWidth = 1.6; path.stroke()
-                }
-                let tier = count == 100 ? 1 : count == 1_000 ? 2 : 3
-                color.setFill()
-                for index in 0..<tier {
-                    NSBezierPath(ovalIn: NSRect(x: 24 - CGFloat(tier) * 3.5 + CGFloat(index) * 7, y: 38, width: 4, height: 4)).fill()
-                }
-            } else {
-                let names = symbols[definition.id] ?? ["rosette"]
-                GameIconRenderer.drawSymbol(names[0], in: NSRect(x: 5, y: 4, width: 38, height: 39), color: color,
-                                            fallbacks: Array(names.dropFirst()))
-            }
+            AchievementBadgeArtwork.draw(definition, muted: muted)
             return true
         }
         image.isTemplate = false
```

### `Sources/AchievementViews.swift`

```diff
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -285,11 +285,9 @@
     private let filter = AchievementFilterControl()
     private let heading = NSTextField(labelWithString: "")
     private let backButton = AchievementPanelActionButton()
-    private let previewButton = AchievementPanelActionButton()
     private let list = NSStackView()
     private let scroll = NSScrollView()
     private var detailID: Int?
-    private var previewsIcons = false
 
     init(manager: AchievementsManager) {
         self.manager = manager
@@ -311,7 +309,6 @@
 
     func present(from parent: NSWindow?, detailID: Int? = nil) {
         self.detailID = detailID
-        previewsIcons = false
         refresh()
         window?.contentView?.layoutSubtreeIfNeeded()
         scroll.contentView.scroll(to: .zero)
@@ -344,15 +341,11 @@
 
     func refresh() {
         window?.title = AchievementText.string("panel.achievements")
-        heading.stringValue = previewsIcons
-            ? AchievementText.format("achievement.preview.summary", AchievementDefinition.all.count)
-            : AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
+        heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
         backButton.title = AchievementText.string("achievement.view_all")
         backButton.invalidateIntrinsicContentSize()
-        previewButton.title = AchievementText.string("achievement.icon_preview")
-        previewButton.invalidateIntrinsicContentSize()
-        backButton.isHidden = detailID == nil && !previewsIcons
-        filter.isHidden = detailID != nil || previewsIcons
+        backButton.isHidden = detailID == nil
+        filter.isHidden = detailID != nil
         for (index, key) in ["all", "locked", "unlocked"].enumerated() {
             filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
         }
@@ -360,25 +353,6 @@
         list.arrangedSubviews.forEach { view in
             list.removeArrangedSubview(view)
             view.removeFromSuperview()
-        }
-        if previewsIcons {
-            let hint = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.preview.hint"))
-            hint.font = .systemFont(ofSize: 12)
-            hint.textColor = HomeStyle.secondary
-            list.addArrangedSubview(hint)
-            let gallery = AchievementIconGalleryView(frame: .zero)
-            gallery.translatesAutoresizingMaskIntoConstraints = false
-            gallery.constrainHeight()
-            gallery.onSelect = { [weak self] id in
-                self?.previewsIcons = false
-                self?.detailID = id
-                self?.refresh()
-                self?.scroll.contentView.scroll(to: .zero)
-                if let scroll = self?.scroll { scroll.reflectScrolledClipView(scroll.contentView) }
-            }
-            list.addArrangedSubview(gallery)
-            gallery.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
-            return
         }
         let definitions = AchievementDefinition.all.filter { definition in
             if let detailID { return definition.id == detailID }
@@ -424,10 +398,6 @@
         backButton.setButtonType(.momentaryPushIn)
         backButton.target = self
         backButton.action = #selector(showAll)
-        previewButton.isBordered = false
-        previewButton.setButtonType(.momentaryPushIn)
-        previewButton.target = self
-        previewButton.action = #selector(showIconPreview)
         let actions = NSStackView(views: [filter, backButton])
         actions.orientation = .horizontal
         let icon = NSImageView(image: NSImage(systemSymbolName: "rosette", accessibilityDescription: nil) ?? NSImage())
@@ -436,7 +406,7 @@
         icon.translatesAutoresizingMaskIntoConstraints = false
         icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
         icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
-        let titleRow = NSStackView(views: [icon, heading, previewButton])
+        let titleRow = NSStackView(views: [icon, heading])
         titleRow.orientation = .horizontal
         titleRow.alignment = .centerY
         titleRow.spacing = 8
@@ -474,7 +444,6 @@
             titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
             filter.heightAnchor.constraint(equalToConstant: 32),
             backButton.heightAnchor.constraint(equalToConstant: 32),
-            previewButton.heightAnchor.constraint(equalToConstant: 32),
             scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
             scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
             scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
@@ -543,14 +512,7 @@
     }
 
     @objc private func filterChanged() { refresh() }
-    @objc private func showAll() { detailID = nil; previewsIcons = false; refresh() }
-    @objc private func showIconPreview() {
-        detailID = nil
-        previewsIcons = true
-        refresh()
-        scroll.contentView.scroll(to: .zero)
-        scroll.reflectScrolledClipView(scroll.contentView)
-    }
+    @objc private func showAll() { detailID = nil; refresh() }
 }
 
 /// 提示是窗口内可点击按钮，显示三秒，不创建 modal 或替换 Touch Bar。
```

### `Sources/AchievementBadgeArtwork.swift`

```diff
--- /dev/null
+++ b/Sources/AchievementBadgeArtwork.swift
@@ -0,0 +1,250 @@
+import Cocoa
+
+/// 成就专用的街机收藏徽章：共同的珐琅盾牌边框与各自的游戏主题图案。
+/// 所有几何以 48 点画布绘制，不依赖系统功能图标或玩家解锁状态。
+enum AchievementBadgeArtwork {
+    static func accent(for definition: AchievementDefinition) -> NSColor {
+        if case .pieceCleared(let kind, _) = definition.goal { return kind.color }
+        switch definition.id {
+        case 1, 10, 12, 17, 20: return NSColor(calibratedRed: 0.91, green: 0.57, blue: 0.12, alpha: 1)
+        case 2, 6, 8, 19: return NSColor(calibratedRed: 0.55, green: 0.39, blue: 0.83, alpha: 1)
+        case 3, 7, 9, 14: return NSColor(calibratedRed: 0.12, green: 0.62, blue: 0.46, alpha: 1)
+        case 4, 11, 15: return NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.28, alpha: 1)
+        default: return NSColor(calibratedRed: 0.19, green: 0.50, blue: 0.84, alpha: 1)
+        }
+    }
+
+    static func draw(_ definition: AchievementDefinition, muted: Bool) {
+        Painter(base: accent(for: definition), muted: muted).draw(definition)
+    }
+
+    private struct Painter {
+        let base: NSColor
+        let muted: Bool
+        private let gold = NSColor(calibratedRed: 1, green: 0.73, blue: 0.13, alpha: 1)
+        private let coral = NSColor(calibratedRed: 0.98, green: 0.33, blue: 0.28, alpha: 1)
+        private let blue = NSColor(calibratedRed: 0.12, green: 0.57, blue: 0.95, alpha: 1)
+        private let teal = NSColor(calibratedRed: 0.13, green: 0.76, blue: 0.60, alpha: 1)
+        private let ink = NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.33, alpha: 1)
+
+        private func tone(_ color: NSColor) -> NSColor {
+            guard muted, let rgb = color.usingColorSpace(.deviceRGB) else { return color }
+            let level = 0.34 + (rgb.redComponent * 0.21 + rgb.greenComponent * 0.72 + rgb.blueComponent * 0.07) * 0.55
+            return NSColor(calibratedWhite: level, alpha: rgb.alphaComponent)
+        }
+
+        private func mix(_ color: NSColor, _ other: NSColor, _ fraction: CGFloat) -> NSColor {
+            color.blended(withFraction: fraction, of: other) ?? color
+        }
+
+        private func fill(_ path: NSBezierPath, _ color: NSColor, shaded: Bool = true) {
+            let color = tone(color)
+            if shaded {
+                NSGradient(colors: [mix(color, .white, 0.30), color, mix(color, .black, 0.16)])?.draw(in: path, angle: -90)
+            } else { color.setFill(); path.fill() }
+        }
+
+        private func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat = 1.5) {
+            tone(color).setStroke(); path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
+        }
+
+        private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: NSColor, radius: CGFloat = 1.5) {
+            fill(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius), color)
+        }
+
+        private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: NSColor) {
+            fill(NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), color)
+        }
+
+        private func polygon(_ points: [NSPoint]) -> NSBezierPath {
+            let path = NSBezierPath(); path.move(to: points[0])
+            points.dropFirst().forEach { path.line(to: $0) }; path.close(); return path
+        }
+
+        private func star(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, color: NSColor) {
+            let points = (0..<10).map { index -> NSPoint in
+                let angle = CGFloat(index) * .pi / 5 - .pi / 2
+                let length = index.isMultiple(of: 2) ? radius : radius * 0.46
+                return NSPoint(x: x + cos(angle) * length, y: y + sin(angle) * length)
+            }
+            fill(polygon(points), color)
+        }
+
+        private func shield() -> NSBezierPath {
+            let path = NSBezierPath()
+            path.move(to: NSPoint(x: 12, y: 4)); path.line(to: NSPoint(x: 36, y: 4))
+            path.curve(to: NSPoint(x: 43, y: 12), controlPoint1: NSPoint(x: 41, y: 4), controlPoint2: NSPoint(x: 44, y: 7))
+            path.line(to: NSPoint(x: 40, y: 31))
+            path.curve(to: NSPoint(x: 24, y: 44), controlPoint1: NSPoint(x: 39, y: 36), controlPoint2: NSPoint(x: 30, y: 42))
+            path.curve(to: NSPoint(x: 8, y: 31), controlPoint1: NSPoint(x: 18, y: 42), controlPoint2: NSPoint(x: 9, y: 36))
+            path.line(to: NSPoint(x: 5, y: 12))
+            path.curve(to: NSPoint(x: 12, y: 4), controlPoint1: NSPoint(x: 4, y: 7), controlPoint2: NSPoint(x: 7, y: 4))
+            path.close(); return path
+        }
+
+        func draw(_ definition: AchievementDefinition) {
+            let rim = shield()
+            NSGraphicsContext.saveGraphicsState()
+            let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
+            shadow.shadowBlurRadius = 1.5; shadow.shadowOffset = NSSize(width: 0, height: -1.2); shadow.set()
+            fill(rim, mix(base, ink, 0.24))
+            NSGraphicsContext.restoreGraphicsState()
+            let face = rim.copy() as! NSBezierPath
+            let inset = NSAffineTransform(); inset.translateX(by: 24, yBy: 24); inset.scale(by: 0.87); inset.translateX(by: -24, yBy: -24)
+            face.transform(using: inset as AffineTransform)
+            fill(face, mix(base, .white, 0.83))
+            stroke(face, .white.withAlphaComponent(0.75), width: 0.7)
+
+            if case .pieceCleared(let kind, let count) = definition.goal {
+                piece(kind, count: count)
+            } else {
+                switch definition.id {
+                case 1: joystick()
+                case 2: rhythm()
+                case 3: flag(checkered: false)
+                case 4: spark()
+                case 5: line(count: 4)
+                case 6: line(count: 5)
+                case 7: cascade(count: 2)
+                case 8: cascade(count: 3)
+                case 9: steps()
+                case 10: trophy()
+                case 11: flame()
+                case 12: crown()
+                case 13: flag(checkered: true)
+                case 14: speed()
+                case 15: rocket()
+                case 16: clock()
+                case 17: collection(level: 1)
+                case 18: collection(level: 2)
+                case 19: collection(level: 3)
+                default: laurel()
+                }
+            }
+        }
+
+        private func joystick() {
+            rect(11, 29, 26, 7, blue, radius: 3)
+            rect(22.5, 18, 3, 12, ink)
+            circle(24, 16, 6, coral); circle(22.5, 14, 1.5, .white.withAlphaComponent(0.6))
+            rect(15, 30.5, 5, 2, gold); rect(28, 30.5, 5, 2, teal)
+        }
+
+        private func rhythm() {
+            for (x, y, color) in [(CGFloat(13), CGFloat(23), blue), (CGFloat(21), CGFloat(14), base), (CGFloat(29), CGFloat(19), coral)] {
+                rect(x, y, 6, 33 - y, color, radius: 2)
+                rect(x + 1, y + 1, 4, 1.5, .white.withAlphaComponent(0.65), radius: 0.5)
+            }
+            star(35, 12, radius: 3.1, color: gold)
+            for x: CGFloat in [16, 24, 32] { circle(x, 36, 1.4, base) }
+        }
+
+        private func flag(checkered: Bool) {
+            let pole = NSBezierPath(); pole.move(to: NSPoint(x: 15, y: 11)); pole.line(to: NSPoint(x: 15, y: 35)); stroke(pole, ink, width: 2)
+            let cloth = polygon([NSPoint(x: 16, y: 12), NSPoint(x: 35, y: 13), NSPoint(x: 32, y: 24), NSPoint(x: 16, y: 23)])
+            fill(cloth, checkered ? .white : teal)
+            if checkered {
+                NSGraphicsContext.saveGraphicsState(); cloth.addClip()
+                for row in 0..<3 { for column in 0..<5 where (row + column).isMultiple(of: 2) { rect(16 + CGFloat(column) * 4, 12 + CGFloat(row) * 4, 4, 4, ink, radius: 0) } }
+                NSGraphicsContext.restoreGraphicsState()
+            } else { star(25, 18, radius: 3, color: gold) }
+            rect(11, 34, 10, 3, gold)
+        }
+
+        private func spark() {
+            rect(17, 25, 14, 10, blue, radius: 2)
+            star(24, 19, radius: 9, color: gold)
+            star(12, 15, radius: 2.5, color: coral); star(36, 25, radius: 2.8, color: teal)
+        }
+
+        private func line(count: Int) {
+            let size: CGFloat = count == 4 ? 6.6 : 5.6
+            let start = 24 - CGFloat(count) * (size + 0.7) / 2
+            for index in 0..<count { rect(start + CGFloat(index) * (size + 0.7), 23, size, 9, [blue, teal, gold, coral, base][index]) }
+            star(24, 15, radius: count == 4 ? 4 : 6, color: gold)
+        }
+
+        private func cascade(count: Int) {
+            for row in 0..<count {
+                for column in 0..<3 { rect(12 + CGFloat(column) * 8 + CGFloat(row % 2) * 2, 12 + CGFloat(row) * 8, 6.5, 6, [blue, teal, gold][row]) }
+            }
+            let arrow = polygon([NSPoint(x: 18, y: 34), NSPoint(x: 24, y: 38), NSPoint(x: 30, y: 34), NSPoint(x: 24, y: 35)])
+            fill(arrow, base)
+        }
+
+        private func steps() {
+            for index in 0..<3 { rect(10 + CGFloat(index) * 8, 29 - CGFloat(index) * 5, 8, 7, [blue, teal, gold][index]) }
+            let route = NSBezierPath(); route.move(to: NSPoint(x: 12, y: 24)); route.line(to: NSPoint(x: 20, y: 24)); route.line(to: NSPoint(x: 20, y: 18)); route.line(to: NSPoint(x: 29, y: 18)); stroke(route, base, width: 2.2)
+            star(35, 14, radius: 5, color: gold)
+        }
+
+        private func trophy() {
+            let cup = NSBezierPath(); cup.move(to: NSPoint(x: 16, y: 12)); cup.line(to: NSPoint(x: 32, y: 12)); cup.line(to: NSPoint(x: 30, y: 24))
+            cup.curve(to: NSPoint(x: 18, y: 24), controlPoint1: NSPoint(x: 27, y: 30), controlPoint2: NSPoint(x: 21, y: 30)); cup.close()
+            let handles = NSBezierPath(); handles.appendOval(in: NSRect(x: 11, y: 13, width: 9, height: 11)); handles.appendOval(in: NSRect(x: 28, y: 13, width: 9, height: 11)); stroke(handles, gold, width: 2.3)
+            fill(cup, gold); rect(22, 26, 4, 7, gold); rect(16, 33, 16, 3, base)
+            star(24, 20, radius: 3.8, color: .white)
+        }
+
+        private func flame() {
+            let fire = NSBezierPath(); fire.move(to: NSPoint(x: 24, y: 8))
+            fire.curve(to: NSPoint(x: 31, y: 19), controlPoint1: NSPoint(x: 25, y: 15), controlPoint2: NSPoint(x: 30, y: 12))
+            fire.curve(to: NSPoint(x: 24, y: 36), controlPoint1: NSPoint(x: 43, y: 32), controlPoint2: NSPoint(x: 31, y: 37))
+            fire.curve(to: NSPoint(x: 16, y: 18), controlPoint1: NSPoint(x: 10, y: 38), controlPoint2: NSPoint(x: 10, y: 27))
+            fire.curve(to: NSPoint(x: 24, y: 8), controlPoint1: NSPoint(x: 15, y: 24), controlPoint2: NSPoint(x: 24, y: 18)); fire.close(); fill(fire, coral)
+            fill(polygon([NSPoint(x: 23, y: 20), NSPoint(x: 30, y: 30), NSPoint(x: 24, y: 35), NSPoint(x: 18, y: 30)]), gold)
+        }
+
+        private func crown() {
+            fill(polygon([NSPoint(x: 11, y: 17), NSPoint(x: 19, y: 23), NSPoint(x: 24, y: 11), NSPoint(x: 29, y: 23), NSPoint(x: 37, y: 17), NSPoint(x: 33, y: 33), NSPoint(x: 15, y: 33)]), gold)
+            rect(15, 32, 18, 4, base); circle(24, 27, 2.5, coral)
+            for x: CGFloat in [11, 24, 37] { circle(x, x == 24 ? 11 : 17, 1.8, gold) }
+        }
+
+        private func speed() {
+            for index in 0..<2 {
+                let x = CGFloat(index) * 11
+                fill(polygon([NSPoint(x: 15 + x, y: 13), NSPoint(x: 24 + x, y: 24), NSPoint(x: 15 + x, y: 35), NSPoint(x: 10 + x, y: 35), NSPoint(x: 19 + x, y: 24), NSPoint(x: 10 + x, y: 13)]), index == 0 ? teal : blue)
+            }
+        }
+
+        private func rocket() {
+            NSGraphicsContext.saveGraphicsState()
+            let tilt = NSAffineTransform(); tilt.translateX(by: 24, yBy: 23); tilt.rotate(byDegrees: 25); tilt.translateX(by: -24, yBy: -23); tilt.concat()
+            fill(polygon([NSPoint(x: 20, y: 31), NSPoint(x: 24, y: 40), NSPoint(x: 28, y: 31)]), gold)
+            fill(polygon([NSPoint(x: 18, y: 24), NSPoint(x: 13, y: 34), NSPoint(x: 21, y: 31), NSPoint(x: 27, y: 31), NSPoint(x: 35, y: 34), NSPoint(x: 30, y: 24)]), coral)
+            fill(NSBezierPath(ovalIn: NSRect(x: 18, y: 8, width: 12, height: 25)), .white); circle(24, 20, 4, blue)
+            NSGraphicsContext.restoreGraphicsState()
+        }
+
+        private func clock() {
+            rect(21, 8, 6, 4, base); circle(24, 24, 12, gold); circle(24, 24, 9.4, .white)
+            let hand = NSBezierPath(); hand.move(to: NSPoint(x: 24, y: 17)); hand.line(to: NSPoint(x: 24, y: 24)); hand.line(to: NSPoint(x: 29, y: 27)); stroke(hand, base, width: 2)
+            circle(24, 24, 1.7, coral)
+        }
+
+        private func collection(level: Int) {
+            let colors = [blue, teal, coral]
+            for row in 0...level {
+                let count = min(4, row + 1)
+                for column in 0..<count { rect(24 - CGFloat(count) * 3.5 + CGFloat(column) * 7, 10 + CGFloat(row) * 6, 6.3, 6.3, colors[row % 3]) }
+            }
+            star(35, 12, radius: 3.4, color: gold)
+        }
+
+        private func laurel() {
+            for side: CGFloat in [-1, 1] {
+                for row in 0..<4 { fill(NSBezierPath(ovalIn: NSRect(x: 23 + side * (11 - CGFloat(row) * 0.7) - 3, y: 15 + CGFloat(row) * 4, width: 5, height: 7)), teal) }
+            }
+            star(24, 13, radius: 4, color: gold)
+            tone(base).setFill()
+            ("20" as NSString).draw(in: NSRect(x: 14, y: 21, width: 20, height: 14), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .heavy), .foregroundColor: tone(base)])
+        }
+
+        private func piece(_ kind: PieceKind, count: Int) {
+            for block in kind.blocks { rect(13 + CGFloat(block.x) * 7.5, 12 + CGFloat(1 - block.y) * 7.5, 7, 7, kind.color) }
+            let tier = count == 100 ? 1 : count == 1_000 ? 2 : 3
+            for index in 0..<tier { star(24 - CGFloat(tier - 1) * 4.4 + CGFloat(index) * 8.8, 35, radius: 3.1, color: gold) }
+        }
+    }
+}
```

### `Sources/AchievementIconGalleryView.swift`

```diff
--- a/Sources/AchievementIconGalleryView.swift
+++ /dev/null
@@ -1,88 +0,0 @@
-import Cocoa
-
-/// 保留原生按钮的键盘操作和辅助功能，视觉与首页的线条图标保持一致。
-private final class AchievementIconPreviewButton: HomeButton {
-    let definition: AchievementDefinition
-    init(definition: AchievementDefinition) {
-        self.definition = definition
-        super.init(frame: .zero)
-        tag = definition.id
-        setAccessibilityLabel(AchievementText.string(definition.titleKey))
-        toolTip = AchievementText.string(definition.titleKey) + "\n" + AchievementText.string(definition.descriptionKey)
-    }
-    required init?(coder: NSCoder) { nil }
-    override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.card(bounds, fill: .white, border: hovering ? HomeStyle.blue : HomeStyle.border, radius: 10)
-        let badge = NSRect(x: bounds.midX - 27, y: 12, width: 54, height: 54)
-        AchievementIconCatalog.accent(for: definition).withAlphaComponent(0.05).setFill()
-        NSBezierPath(ovalIn: badge).fill()
-        AchievementIconCatalog.image(for: definition).draw(in: badge.insetBy(dx: 4, dy: 4), from: .zero,
-                                                           operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
-        HomeStyle.text(AchievementText.string(definition.titleKey),
-                       in: NSRect(x: 7, y: 77, width: bounds.width - 14, height: 22),
-                       size: 13, weight: .semibold, alignment: .center)
-        HomeStyle.text(String(format: "%02d", definition.id),
-                       in: NSRect(x: 8, y: 103, width: bounds.width - 16, height: 17),
-                       size: 10, color: HomeStyle.secondary, alignment: .center)
-    }
-}
-
-/// 无需解锁即可查看全部图标；只展示成就定义，不访问或修改玩家进度。
-final class AchievementIconGalleryView: NSView {
-    var onSelect: ((Int) -> Void)?
-    private var heightConstraint: NSLayoutConstraint?
-    private var buttons: [AchievementIconPreviewButton] = []
-    private let gap: CGFloat = 12
-    private let cardHeight: CGFloat = 126
-    override var isFlipped: Bool { true }
-
-    override init(frame: NSRect) {
-        super.init(frame: frame)
-        setAccessibilityElement(true)
-        setAccessibilityRole(.group)
-        setAccessibilityLabel(AchievementText.format("achievement.preview.summary", AchievementDefinition.all.count))
-        for definition in AchievementDefinition.all {
-            let button = AchievementIconPreviewButton(definition: definition)
-            button.onClick = { [weak self] in self?.onSelect?(definition.id) }
-            buttons.append(button)
-            addSubview(button)
-        }
-    }
-    required init?(coder: NSCoder) { nil }
-
-    func constrainHeight() {
-        heightConstraint = heightAnchor.constraint(equalToConstant: contentHeight(for: bounds.width))
-        heightConstraint?.isActive = true
-    }
-
-    override func setFrameSize(_ newSize: NSSize) {
-        super.setFrameSize(newSize)
-        heightConstraint?.constant = contentHeight(for: newSize.width)
-        needsDisplay = true
-        needsLayout = true
-    }
-
-    override func layout() {
-        super.layout()
-        for (index, button) in buttons.enumerated() { button.frame = cardRect(at: index) }
-    }
-
-    func contentHeight(for width: CGFloat) -> CGFloat {
-        let columns = columnCount(for: width)
-        let rows = (AchievementDefinition.all.count + columns - 1) / columns
-        return CGFloat(rows) * (cardHeight + gap) - gap
-    }
-
-    private func columnCount(for width: CGFloat) -> Int { max(2, min(4, Int((width + gap) / 142))) }
-
-    private func cardRect(at index: Int) -> NSRect {
-        let columns = columnCount(for: bounds.width)
-        let width = (bounds.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
-        return NSRect(x: CGFloat(index % columns) * (width + gap), y: CGFloat(index / columns) * (cardHeight + gap),
-                      width: width, height: cardHeight)
-    }
-
-    override func draw(_ dirtyRect: NSRect) {
-        HomeStyle.background.setFill(); bounds.fill()
-    }
-}
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- a/Tests/GameIconPresentationTests.swift
+++ b/Tests/GameIconPresentationTests.swift
@@ -58,6 +58,8 @@
                 XCTAssertGreaterThan(ink.height, 10)
             }
         }
+        let fullSet = try AchievementDefinition.all.map { try XCTUnwrap(AchievementIconCatalog.image(for: $0).tiffRepresentation) }
+        XCTAssertEqual(Set(fullSet).count, 32, "全部徽章应具有各自的身份或等级")
         for first in [21, 24, 27, 30] {
             let data = try (first...first + 2).map { id in
                 try XCTUnwrap(AchievementIconCatalog.image(for: AchievementDefinition.all[id - 1]).tiffRepresentation)
@@ -66,7 +68,7 @@
         }
     }
 
-    func testPreviewIsAvailableWithoutUnlocksAndOpensRealDetails() throws {
+    func testProductionPanelHasNoIconPreviewEntryAndDoesNotChangeProgress() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
@@ -76,41 +78,58 @@
         defer { controller.close() }
         controller.refresh()
         let content = try XCTUnwrap(controller.window?.contentView)
-        let preview = try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.first { $0.title == "图标预览" })
-        preview.performClick(nil)
         content.layoutSubtreeIfNeeded()
-        let gallery = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementIconGalleryView }.first)
-        gallery.layoutSubtreeIfNeeded()
-        let cards = gallery.subviews.compactMap { $0 as? NSButton }
-        XCTAssertEqual(cards.map(\.tag).sorted(), Array(1...32))
-        XCTAssertTrue(cards.allSatisfy { gallery.bounds.contains($0.frame) })
-        try XCTUnwrap(cards.first { $0.tag == 32 }).performClick(nil)
-        XCTAssertNil(descendants(content).first { $0 is AchievementIconGalleryView })
-        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 1)
-        XCTAssertTrue(descendants(content).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "红色万格" })
+        XCTAssertFalse(descendants(content).compactMap { $0 as? NSButton }.contains { $0.title.contains("图标预览") })
+        XCTAssertFalse(controller.responds(to: NSSelectorFromString("showIconPreview")))
+        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 32)
         XCTAssertEqual(manager.unlockedIDs(), [])
         XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
     }
 
-    func testGalleryRendersAllLanguagesAndExportsAllThirtyTwoIcons() throws {
+    func testTestOnlyContactSheetExportsEveryBadgeWithoutUnlocking() throws {
         _ = NSApplication.shared
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
+        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
         for language in AppLanguage.allCases {
             Localizer.shared.setLanguage(language)
-            for width: CGFloat in [416, 568, 760] {
-                let gallery = AchievementIconGalleryView(frame: .zero)
-                gallery.frame = NSRect(x: 0, y: 0, width: width, height: gallery.contentHeight(for: width))
-                gallery.layoutSubtreeIfNeeded()
-                XCTAssertEqual(gallery.subviews.count, 32)
-                XCTAssertTrue(gallery.subviews.allSatisfy { gallery.bounds.contains($0.frame) })
-                if language == .chineseSimplified, width == 760 {
-                    let bitmap = try XCTUnwrap(gallery.bitmapImageRepForCachingDisplay(in: gallery.bounds))
-                    gallery.cacheDisplay(in: gallery.bounds, to: bitmap)
-                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
-                    try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-all-achievement-icons.png"))
-                }
+            let sheet = AchievementIconContactSheet(frame: NSRect(x: 0, y: 0, width: AchievementIconContactSheet.width, height: AchievementIconContactSheet.height))
+            let bitmap = try XCTUnwrap(sheet.bitmapImageRepForCachingDisplay(in: sheet.bounds))
+            sheet.cacheDisplay(in: sheet.bounds, to: bitmap)
+            if language == .chineseSimplified {
+                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+                try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-all-achievement-icons.png"))
             }
         }
+        XCTAssertEqual(manager.unlockedIDs(), [])
+        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
+    }
+
+    func testRhythmAndStepsBadgesRenderAndRemainClickableInHomeLabels() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let domain = "badge-label-preview.\(UUID().uuidString)"
+        let fixture = try XCTUnwrap(UserDefaults(suiteName: domain))
+        defer { fixture.removePersistentDomain(forName: domain) }
+        fixture.set(["version": 1, "unlocked": [2, 9], "metrics": [:]], forKey: AchievementsManager.storageKey)
+        let progress = AchievementsManager(defaults: fixture)
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
+                                           targetScore: nil, isRunning: false, isFinished: false), mode: .free, manager: progress)
+        home.layoutSubtreeIfNeeded()
+        var selected: Int?
+        home.onAchievement = { selected = $0 }
+        for id in [2, 9] {
+            let description = AchievementText.string(AchievementDefinition.all[id - 1].descriptionKey)
+            let button = try XCTUnwrap(home.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
+            button.performClick(nil)
+            XCTAssertEqual(selected, id)
+        }
+        let strip = NSRect(x: 44, y: 708, width: 1092, height: 54)
+        let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: strip))
+        home.cacheDisplay(in: strip, to: bitmap)
+        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-game-badge-labels.png"))
     }
 }
```

### `Tests/AchievementIconContactSheet.swift`

```diff
--- /dev/null
+++ b/Tests/AchievementIconContactSheet.swift
@@ -0,0 +1,25 @@
+import Cocoa
+@testable import EliminateTeris1
+
+/// 仅测试使用的静态图标总览，正式应用没有预览入口或预览页面。
+final class AchievementIconContactSheet: NSView {
+    override var isFlipped: Bool { true }
+    static let width: CGFloat = 760
+    static let cell: CGFloat = 126
+    static let height: CGFloat = 8 * cell + 40
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.background.setFill(); bounds.fill()
+        HomeStyle.text("成就徽章 · 测试总览", in: NSRect(x: 16, y: 8, width: bounds.width - 32, height: 28), size: 18, weight: .bold)
+        let width = bounds.width / 4
+        for (index, definition) in AchievementDefinition.all.enumerated() {
+            let rect = NSRect(x: CGFloat(index % 4) * width, y: 40 + CGFloat(index / 4) * Self.cell, width: width, height: Self.cell)
+            AchievementIconCatalog.image(for: definition).draw(in: NSRect(x: rect.midX - 30, y: rect.minY + 8, width: 60, height: 60),
+                                                               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+            HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: rect.minX + 4, y: rect.minY + 78, width: width - 8, height: 22),
+                           size: 13, weight: .semibold, alignment: .center)
+            HomeStyle.text(String(format: "%02d", definition.id), in: NSRect(x: rect.minX, y: rect.minY + 103, width: width, height: 18),
+                           size: 10, color: HomeStyle.secondary, alignment: .center)
+        }
+    }
+}
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -11,7 +11,7 @@
 - 三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，首页不再提供档位设置。旧挑战记录保留，成就按固定规则兼容升级并保留已解锁状态。
 - 首页及辅助面板在探索分支使用暖白、蓝色选择态与黄色主操作的浅色主题，替代旧版桌面像素背景；Touch Bar 棋盘绘制链路沿用既有实现。
 - 首页主插画直接使用设计稿提取的本地透明资源，按四种形状独立缓存和浮动；图片与语言表共用 `GameResourceLocator` 定位资源，运行时不依赖网络或三维渲染服务。
-- 模式与成就图标共用 `GameIconRenderer` 的等比绘制和系统兼容路径；成就图标统一由 `AchievementIconCatalog` 映射，图标预览只读取定义，不修改玩家解锁或累计数据。
+- 模式与成就图标共用 `GameIconRenderer` 的等比绘制和系统兼容路径；成就徽章由 `AchievementIconCatalog` 与本地游戏主题绘制统一提供；全部图标的测试总览仅存在于 XCTest target，正式应用不提供测试预览入口。
 
 ## 2026-10-29
 - 消除结算事件包含按 `PieceKind` 稳定标识分类的明细，先记录被消除的实际类型再补位；顶部统计与类型成就共用同一累计存档数据源，按类型统计不依赖分数或界面动画反推。
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031204033-game-badges-test-only-preview.md` - 会话-76 起移除正式图标预览入口和页面，将全部图标展示收回测试 target；成就重绘为彩色街机收藏徽章，重点替换节奏/步步有解，含完整逐行 diff、标签测试图和 51 项回归。
 `workflow/20261031201958-icon-aspect-and-achievement-gallery.md` - 会话-71 起修复系统图标拉伸与竞分奖杯缺失，统一全部成就图标，新增无需解锁的图标预览与可分享总览；含全部逐行 diff、50 项完整回归及真实渲染验收。
 `workflow/20261030090548-use-original-design-cutouts.md` - 会话-64 起直接从原始设计稿提取方块、投影、短线和箭头，按原稿坐标整体等比排列；主体像素保真验证、独立浮动及 46 项完整回归，含全部增量 diff 和资源校验。
 `workflow/20261030085356-home-hero-studio-artwork.md` - 会话-59 起以 imagegen 透明立体图集替换程序渐变插画；独立缓存与浮动、共用资源定位、透明和四种轮廓验证，含本轮完整增量 diff 与 46 项完整回归。
@@ -70,6 +71,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整彩色游戏成就徽章、节奏光柱/阶梯终点星、测试总览导出，或确认正式应用为何没有预览入口时，读取 `20261031204033-game-badges-test-only-preview.md`。
 - 需要调整模式/成就图标的比例、奖杯兼容路径、32 枚图标映射或无需解锁的图标预览入口时，读取 `20261031201958-icon-aspect-and-achievement-gallery.md`。
 - 需要调整当前首页原稿提取素材、复现抠图、核对像素保真或原稿相对布局时，读取 `20261030090548-use-original-design-cutouts.md`。
 - 需要调整当前首页立体插画图集、实体缩放边界、透明资源加载或查看生成提示词时，读取 `20261030085356-home-hero-studio-artwork.md`。
@@ -140,7 +142,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
-- 模式与成就图标集中在 `Sources/GameIcons.swift`：`GameIconRenderer` 等比居中并缓存固定分辨率字形，奖杯/终点旗有本地路径；`AchievementIconCatalog` 是 32 枚成就图标的统一入口。成就图鉴的“图标预览”可查看全部图标，不更改存档；静态总览位于 `docs/previews/achievement-icons.png`。
+- `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的彩色游戏收藏徽章。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
 - 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -1,20 +1,27 @@
-# 界面预览
+# 成就徽章测试图
 
-## 全部成就图标
+这些文件仅用于开发测试与评审，正式应用中没有图标预览按钮或图标预览页面。
 
-![全部 32 枚成就图标](achievement-icons.png)
+## 标签实际效果
 
-- 图标定义集中在 `Sources/GameIcons.swift` 的 `AchievementIconCatalog`，不依赖成就是否解锁。
-- 常规图标使用 SF Symbols（系统矢量符号），奖杯、终点旗和四种方块里程碑使用本地矢量路径。
-- 类型里程碑的一、二、三个圆点分别对应百、千、万档。
-- 当前 PNG 由真实 AppKit 视图导出，供完整预览；应用运行时使用共用图标绘制，不读取此总览图。
-- 游戏中的入口：成就模块“查看全部” → “图标预览”；点击图标可查看真实达成条件。
-- 预览不会解锁成就，也不会修改进度或本地存档。
+![成就标签实际效果](achievement-labels.png)
 
-## 更新预览
+- 使用首页真实标签组件渲染，重点展示“节奏初现”和“步步有解”。
+- 截图中的解锁状态来自独立的测试存档，不修改玩家存档。
 
-执行下列现有回归后，将系统临时目录中的 `eliminate-all-achievement-icons.png` 复制到本目录的 `achievement-icons.png`。
+## 全部 32 枚徽章
+
+![全部成就徽章](achievement-icons.png)
+
+- 图标入口：`Sources/GameIcons.swift` 中的 `AchievementIconCatalog`。
+- 游戏主题绘制：`Sources/AchievementBadgeArtwork.swift`，使用彩色珐琅盾牌、街机摇杆、节拍光柱、阶梯终点星等图案。
+- 百、千、万档分别使用一、二、三颗星。
+- 测试总览夹具：`Tests/AchievementIconContactSheet.swift`，只编入 XCTest target，不进入正式 App。
+
+## 更新测试图
 
 ```sh
 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests
 ```
+
+将系统临时目录中的 `eliminate-all-achievement-icons.png` 和 `eliminate-game-badge-labels.png` 分别复制为本目录中的 `achievement-icons.png` 和 `achievement-labels.png`。
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -201,8 +201,3 @@
 "home.unlocked_count" = "Unlocked %d / %d";
 "home.rules.fixed" = "Each cleared tile earns 10 points. Score Attack lasts 60 seconds; Speed Run ends at 300 points. Switching modes or restarting clears this round’s counters. Lifetime achievement progress is saved.";
 "home.records.fixed" = "Fixed rules: 60-second Score Attack · 300-point Speed Run";
-
-// 成就图标预览，无需解锁即可查看。
-"achievement.icon_preview" = "Icon gallery";
-"achievement.preview.summary" = "All %d achievement icons";
-"achievement.preview.hint" = "Select an icon to see its requirements.";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -194,8 +194,3 @@
 "home.unlocked_count" = "達成 %d / %d";
 "home.rules.fixed" = "1 個消すと 10 点。スコアアタックは 60 秒、スピードランは 300 点で終了。モード変更や再開で一局の記録はリセットされ、実績の累計は保存されます。";
 "home.records.fixed" = "固定ルール：60 秒スコアアタック · 300 点スピードラン";
-
-// 成就图标预览，无需解锁即可查看。
-"achievement.icon_preview" = "アイコン一覧";
-"achievement.preview.summary" = "全 %d 個の実績アイコン";
-"achievement.preview.hint" = "アイコンを選ぶと達成条件を確認できます。";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -194,8 +194,3 @@
 "home.unlocked_count" = "달성 %d / %d";
 "home.rules.fixed" = "블록 하나당 10점입니다. 점수 도전은 60초, 스피드런은 300점에 도달하면 끝납니다. 모드 변경이나 재시작 시 현재 판의 통계는 초기화되며 업적의 누적 진행은 유지됩니다.";
 "home.records.fixed" = "고정 규칙: 60초 점수 도전 · 300점 스피드런";
-
-// 成就图标预览，无需解锁即可查看。
-"achievement.icon_preview" = "아이콘 미리보기";
-"achievement.preview.summary" = "전체 업적 아이콘 %d개";
-"achievement.preview.hint" = "아이콘을 선택하면 달성 조건을 볼 수 있습니다.";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -194,8 +194,3 @@
 "home.unlocked_count" = "Открыто %d / %d";
 "home.rules.fixed" = "Каждый удалённый блок даёт 10 очков. Игра на очки длится 60 секунд; игра на скорость завершается при 300 очках. Смена режима или перезапуск обнуляет статистику игры, но сохраняет общий прогресс достижений.";
 "home.records.fixed" = "Правила: 60 секунд на очки · 300 очков на скорость";
-
-// 成就图标预览，无需解锁即可查看。
-"achievement.icon_preview" = "Все значки";
-"achievement.preview.summary" = "Все значки достижений: %d";
-"achievement.preview.hint" = "Выберите значок, чтобы увидеть условия.";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -201,8 +201,3 @@
 "home.unlocked_count" = "已解锁 %d / %d";
 "home.rules.fixed" = "每个消除方块计 10 分。竞分固定 60 秒，竞速固定 300 分；达到条件后自动结束。切换模式或重新开始会清零本局统计，成就累计进度会保留。";
 "home.records.fixed" = "固定规则：竞分 60 秒 · 竞速 300 分";
-
-// 成就图标预览，无需解锁即可查看。
-"achievement.icon_preview" = "图标预览";
-"achievement.preview.summary" = "全部 %d 枚成就图标";
-"achievement.preview.hint" = "点击图标查看达成条件。";
```

### `docs/previews/achievement-icons.png`

```diff
diff --git a/docs/previews/achievement-icons.png b/docs/previews/achievement-icons.png
Binary files a/docs/previews/achievement-icons.png and b/docs/previews/achievement-icons.png differ
```

### `docs/previews/achievement-labels.png`

```diff
diff --git a/docs/previews/achievement-labels.png b/docs/previews/achievement-labels.png
new file mode 100644
Binary files /dev/null and b/docs/previews/achievement-labels.png differ
```
