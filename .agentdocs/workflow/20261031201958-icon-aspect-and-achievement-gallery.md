# 图标比例修复与全部成就图标预览

## 背景与目标
- 对应会话：会话-71 起；分支：`experiment/ui-refactor`。
- 用户反馈模式和成就图标变形、竞分图标缺失，要求改善美观度并预览所有未解锁成就图标。
- 基线提交：`d603749`；本轮开始时工作区干净。
- 继续沿用设计稿的浅色首页、线条图标和 Touch Bar 原有行为。

## 原因与实现
- 原 `HomeStyle.symbol` 将系统符号直接拉伸到目标方框，宽图标和窄图标都改变了原始比例；系统未提供的符号则直接返回，导致竞分奖杯为空。
- 新增 `GameIconRenderer`，按符号固有尺寸等比居中；系统字形先在四倍分辨率下定型并缓存，避免不同控件尺寸触发不同光学校正字形。
- 奖杯和终点旗采用本地矢量路径，兼容旧系统，避免图标缺失和终点成就退化为普通旗帜。
- `AchievementIconCatalog` 集中定义所有成就图标；普通成就使用含义对应的 SF Symbols（系统矢量符号），四种类型累计成就使用对应四格轮廓与主题色。
- 百、千、万档以一、二、三个圆点区分，已解锁/未解锁只影响显示色彩，图形身份保持一致。
- 首页徽章、图鉴、详情和图标预览共用同一图标入口，不再只为少数成就提供图标、其余均回退到统一花章。

## 预览入口与文件位置
- 应用入口：成就模块“查看全部” → “图标预览”。
- 预览以原生按钮网格展示全部 32 枚图标，点击可打开真实达成条件；无需解锁，也不修改解锁、计数或存档。
- 图标定义与本地矢量路径：`Sources/GameIcons.swift`。
- 预览视图：`Sources/AchievementIconGalleryView.swift`。
- 可分享总览：`docs/previews/achievement-icons.png`；图片由实际 AppKit 视图导出，不是运行时图标资源。
- 五种语言新增入口、总览标题和操作提示文案。

## 阶段与 TODO
- [x] 定位拉伸和系统符号缺失问题。
- [x] 统一等比绘制、固定字形缓存及本地兼容路径。
- [x] 为全部成就建立统一映射并接入各处展示。
- [x] 新增可点击、可滚动、无需解锁的全部图标预览。
- [x] 生成静态完整总览并人工检查图标和首页渲染。
- [x] 完成五语言、图标比例、预览存档隔离和完整回归。
- [x] 更新核心认知、根索引与本轮完整逐行 diff。

## 测试方法与结果

### TC-001 宽窄图标比例
- 使用 infinity、music.note、hand.tap、flag 的实际符号墨迹边界为参考，在 64×64 和 100×40 两类容器下对比比例。
- 参考字形放大后取样，避免原始十几像素高度的取整影响测量精度。
- 结果：通过，宽窄图标均未被拉成目标矩形。

### TC-002 图标完整性与档位
- 渲染三种模式及全部 32 枚成就的正常/灰色两种状态，检查均有有效图形。
- 四种类型的百、千、万图标输出彼此不同，验证档位圆点存在。
- 结果：通过，竞分奖杯与终点旗不依赖系统符号可用性。

### TC-003 无解锁预览与详情
- 使用无成就解锁的隔离存档，点击真实“图标预览”按钮。
- 检查出现编号 1—32 的全部按钮且位于画廊范围内，点击编号 32 打开对应真实详情。
- 比较预览前后解锁列表和本地存储对象。
- 结果：通过，预览不写入进度或解锁状态。

### TC-004 多语言与整体回归
- 预览覆盖现有五种语言和 416、568、760 点宽度；验证全部 32 个按钮布局并导出中文总览。
- 首页原有三种模式、五种语言、三种窗口尺寸测试，以及旧成就窗口定位/筛选/点击测试均通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests`：4 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：50 项通过，0 失败；最终完成于 2026-10-31 20:18:28。
- `git diff --check`：通过。
- 已人工查看完整图标总览和竞分首页截图；测试使用隔离数据，未修改玩家进度，未重启玩家当前游戏。

## 预览图片校验
- 文件：`docs/previews/achievement-icons.png`。
- 大小：319760 字节。
- SHA-256：`aef79d1c35774d7c9ad10ced2cfe6567e54a88e099c18e4b8550180406a72912`。

## 代码变更

以下为本轮全部源码、语言资源、测试、认知和说明文档的完整逐行 diff；预览 PNG 另以新增二进制文件及校验值记录。

### `Sources/GamePresentation.swift`

```diff
--- a/Sources/GamePresentation.swift
+++ b/Sources/GamePresentation.swift
@@ -53,14 +53,7 @@
     }
 
     static func symbol(_ name: String, in rect: NSRect, color: NSColor = ink) {
-        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
-        let tinted = NSImage(size: rect.size, flipped: true) { target in
-            image.draw(in: target)
-            color.setFill()
-            target.fill(using: .sourceAtop)
-            return true
-        }
-        tinted.draw(in: rect)
+        GameIconRenderer.drawSymbol(name, in: rect, color: color)
     }
 
     static func card(_ rect: NSRect, fill: NSColor = NSColor.white.withAlphaComponent(0.7), border: NSColor = border, radius: CGFloat = 10) {
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -145,8 +145,8 @@
         HomeStyle.card(bounds)
         let status = unlocked ? "checkmark.circle.fill" : "lock.fill"
         HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
-        let names = [1: "hand.tap", 2: "music.note", 3: "flag", 4: "sparkles", 7: "link"]
-        HomeStyle.symbol(names[definition.id] ?? "rosette", in: NSRect(x: 45, y: bounds.midY - 15, width: 30, height: 30), color: unlocked ? HomeStyle.ink : HomeStyle.muted)
+        AchievementIconCatalog.image(for: definition, muted: !unlocked).draw(in: NSRect(x: 42, y: bounds.midY - 19, width: 38, height: 38),
+                                                                           from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
         HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: 89, y: bounds.midY - 9, width: bounds.width - 98, height: 22), size: 13, weight: .semibold,
                        color: unlocked ? HomeStyle.ink : HomeStyle.muted)
     }
```

### `Sources/AchievementViews.swift`

```diff
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -98,9 +98,8 @@
         let color = unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.82, blue: 0.82, alpha: 0.9)
         nameLabel.stringValue = AchievementText.string(definition.titleKey)
         nameLabel.textColor = color
-        iconView.image = NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil)
-        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
-        iconView.contentTintColor = color
+        iconView.image = AchievementIconCatalog.image(for: definition, muted: !unlocked)
+        iconView.contentTintColor = nil
         layer?.borderColor = (unlocked ? NSColor.systemGreen : NSColor(calibratedRed: 1, green: 0.53, blue: 0.5, alpha: 0.96)).cgColor
         toolTip = AchievementText.string(definition.titleKey) + "\n" + AchievementText.string(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
         setAccessibilityLabel(AchievementText.title(definition, manager: manager))
@@ -286,9 +285,11 @@
     private let filter = AchievementFilterControl()
     private let heading = NSTextField(labelWithString: "")
     private let backButton = AchievementPanelActionButton()
+    private let previewButton = AchievementPanelActionButton()
     private let list = NSStackView()
     private let scroll = NSScrollView()
     private var detailID: Int?
+    private var previewsIcons = false
 
     init(manager: AchievementsManager) {
         self.manager = manager
@@ -310,6 +311,7 @@
 
     func present(from parent: NSWindow?, detailID: Int? = nil) {
         self.detailID = detailID
+        previewsIcons = false
         refresh()
         window?.contentView?.layoutSubtreeIfNeeded()
         scroll.contentView.scroll(to: .zero)
@@ -342,11 +344,15 @@
 
     func refresh() {
         window?.title = AchievementText.string("panel.achievements")
-        heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
+        heading.stringValue = previewsIcons
+            ? AchievementText.format("achievement.preview.summary", AchievementDefinition.all.count)
+            : AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
         backButton.title = AchievementText.string("achievement.view_all")
         backButton.invalidateIntrinsicContentSize()
-        backButton.isHidden = detailID == nil
-        filter.isHidden = detailID != nil
+        previewButton.title = AchievementText.string("achievement.icon_preview")
+        previewButton.invalidateIntrinsicContentSize()
+        backButton.isHidden = detailID == nil && !previewsIcons
+        filter.isHidden = detailID != nil || previewsIcons
         for (index, key) in ["all", "locked", "unlocked"].enumerated() {
             filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
         }
@@ -354,6 +360,25 @@
         list.arrangedSubviews.forEach { view in
             list.removeArrangedSubview(view)
             view.removeFromSuperview()
+        }
+        if previewsIcons {
+            let hint = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.preview.hint"))
+            hint.font = .systemFont(ofSize: 12)
+            hint.textColor = HomeStyle.secondary
+            list.addArrangedSubview(hint)
+            let gallery = AchievementIconGalleryView(frame: .zero)
+            gallery.translatesAutoresizingMaskIntoConstraints = false
+            gallery.constrainHeight()
+            gallery.onSelect = { [weak self] id in
+                self?.previewsIcons = false
+                self?.detailID = id
+                self?.refresh()
+                self?.scroll.contentView.scroll(to: .zero)
+                if let scroll = self?.scroll { scroll.reflectScrolledClipView(scroll.contentView) }
+            }
+            list.addArrangedSubview(gallery)
+            gallery.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
+            return
         }
         let definitions = AchievementDefinition.all.filter { definition in
             if let detailID { return definition.id == detailID }
@@ -399,14 +424,19 @@
         backButton.setButtonType(.momentaryPushIn)
         backButton.target = self
         backButton.action = #selector(showAll)
+        previewButton.isBordered = false
+        previewButton.setButtonType(.momentaryPushIn)
+        previewButton.target = self
+        previewButton.action = #selector(showIconPreview)
         let actions = NSStackView(views: [filter, backButton])
         actions.orientation = .horizontal
         let icon = NSImageView(image: NSImage(systemSymbolName: "rosette", accessibilityDescription: nil) ?? NSImage())
         icon.contentTintColor = AchievementPanelStyle.accent
+        icon.imageScaling = .scaleProportionallyUpOrDown
         icon.translatesAutoresizingMaskIntoConstraints = false
         icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
         icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
-        let titleRow = NSStackView(views: [icon, heading])
+        let titleRow = NSStackView(views: [icon, heading, previewButton])
         titleRow.orientation = .horizontal
         titleRow.alignment = .centerY
         titleRow.spacing = 8
@@ -444,6 +474,7 @@
             titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
             filter.heightAnchor.constraint(equalToConstant: 32),
             backButton.heightAnchor.constraint(equalToConstant: 32),
+            previewButton.heightAnchor.constraint(equalToConstant: 32),
             scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
             scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
             scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
@@ -465,13 +496,14 @@
         name.font = .systemFont(ofSize: 13, weight: .semibold)
         name.textColor = accent
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
-        let icon = NSImageView(image: NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil) ?? NSImage())
-        icon.contentTintColor = accent
+        let icon = NSImageView(image: AchievementIconCatalog.image(for: definition, muted: !unlocked))
+        icon.imageScaling = .scaleProportionallyUpOrDown
         icon.translatesAutoresizingMaskIntoConstraints = false
-        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
-        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
+        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
+        icon.heightAnchor.constraint(equalToConstant: 30).isActive = true
         let titleRow = NSStackView(views: [icon, name])
         titleRow.orientation = .horizontal
+        titleRow.alignment = .centerY
         titleRow.spacing = 6
         let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
         condition.font = .systemFont(ofSize: 12, weight: .regular)
@@ -511,7 +543,14 @@
     }
 
     @objc private func filterChanged() { refresh() }
-    @objc private func showAll() { detailID = nil; refresh() }
+    @objc private func showAll() { detailID = nil; previewsIcons = false; refresh() }
+    @objc private func showIconPreview() {
+        detailID = nil
+        previewsIcons = true
+        refresh()
+        scroll.contentView.scroll(to: .zero)
+        scroll.reflectScrolledClipView(scroll.contentView)
+    }
 }
 
 /// 提示是窗口内可点击按钮，显示三秒，不创建 modal 或替换 Touch Bar。
```

### `Sources/GameIcons.swift`

```diff
--- /dev/null
+++ b/Sources/GameIcons.swift
@@ -0,0 +1,143 @@
+import Cocoa
+
+/// 统一图标的比例、线条和系统兼容性；不把宽图标强行拉成正方形。
+enum GameIconRenderer {
+    private static var symbolCache: [String: NSImage] = [:]
+    static func fittedRect(size: NSSize, in bounds: NSRect) -> NSRect {
+        guard size.width > 0, size.height > 0 else { return .zero }
+        let scale = min(bounds.width / size.width, bounds.height / size.height)
+        return NSRect(x: bounds.midX - size.width * scale / 2, y: bounds.midY - size.height * scale / 2,
+                      width: size.width * scale, height: size.height * scale)
+    }
+
+    static func drawSymbol(_ name: String, in bounds: NSRect, color: NSColor, fallbacks: [String] = []) {
+        if name == "trophy" { drawTrophy(in: bounds, color: color); return }
+        if name == "flag.checkered" { drawFinishFlag(in: bounds, color: color); return }
+        let key = ([name] + fallbacks).joined(separator: ".") + color.description
+        if let cached = symbolCache[key] {
+            cached.draw(in: fittedRect(size: cached.size, in: bounds), from: .zero, operation: .sourceOver,
+                        fraction: 1, respectFlipped: true, hints: nil)
+            return
+        }
+        let image = ([name] + fallbacks + ["star"]).compactMap {
+            NSImage(systemSymbolName: $0, accessibilityDescription: nil)
+        }.first
+        guard let image else { return }
+        let configured = image.withSymbolConfiguration(.init(pointSize: 32, weight: .regular)) ?? image
+        // 统一在四倍分辨率下定型，避免系统符号在不同控件尺寸下重新选取光学校正字形。
+        guard let pixels = NSBitmapImageRep(bitmapDataPlanes: nil,
+                                            pixelsWide: Int(ceil(configured.size.width * 4)),
+                                            pixelsHigh: Int(ceil(configured.size.height * 4)), bitsPerSample: 8,
+                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
+                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
+              let context = NSGraphicsContext(bitmapImageRep: pixels) else { return }
+        NSGraphicsContext.saveGraphicsState()
+        NSGraphicsContext.current = context
+        let target = NSRect(x: 0, y: 0, width: pixels.pixelsWide, height: pixels.pixelsHigh)
+        configured.draw(in: target)
+        color.setFill(); target.fill(using: .sourceAtop)
+        NSGraphicsContext.restoreGraphicsState()
+        guard let cgImage = pixels.cgImage else { return }
+        let tinted = NSImage(cgImage: cgImage, size: configured.size)
+        tinted.isTemplate = false
+        symbolCache[key] = tinted
+        tinted.draw(in: fittedRect(size: configured.size, in: bounds), from: .zero, operation: .sourceOver,
+                    fraction: 1, respectFlipped: true, hints: nil)
+    }
+
+    /// 终点旗同样使用本地矢量，避免旧系统回退为普通旗帜后与入门成就混淆。
+    private static func drawFinishFlag(in bounds: NSRect, color: NSColor) {
+        let rect = fittedRect(size: NSSize(width: 24, height: 24), in: bounds)
+        NSGraphicsContext.saveGraphicsState()
+        let transform = NSAffineTransform()
+        transform.translateX(by: rect.minX, yBy: rect.minY)
+        transform.scaleX(by: rect.width / 24, yBy: rect.height / 24)
+        transform.concat()
+        color.setStroke(); color.setFill()
+        let pole = NSBezierPath(); pole.lineWidth = 1.6; pole.lineCapStyle = .round
+        pole.move(to: NSPoint(x: 5, y: 3)); pole.line(to: NSPoint(x: 5, y: 22)); pole.stroke()
+        let flag = NSBezierPath(rect: NSRect(x: 5, y: 4, width: 14, height: 10))
+        flag.lineWidth = 1.2; flag.stroke()
+        for row in 0..<3 {
+            for column in 0..<4 where (row + column).isMultiple(of: 2) {
+                NSRect(x: 5 + CGFloat(column) * 3.5, y: 4 + CGFloat(row) * 10 / 3, width: 3.5, height: 10 / 3).fill()
+            }
+        }
+        NSGraphicsContext.restoreGraphicsState()
+    }
+
+    /// 奖杯使用本地路径，兼容未提供 trophy 系统符号的 macOS 12。
+    private static func drawTrophy(in bounds: NSRect, color: NSColor) {
+        let rect = fittedRect(size: NSSize(width: 24, height: 26), in: bounds)
+        NSGraphicsContext.saveGraphicsState()
+        let transform = NSAffineTransform()
+        transform.translateX(by: rect.minX, yBy: rect.minY)
+        transform.scaleX(by: rect.width / 24, yBy: rect.height / 26)
+        transform.concat()
+        let path = NSBezierPath()
+        path.lineWidth = 1.65; path.lineCapStyle = .round; path.lineJoinStyle = .round
+        path.move(to: NSPoint(x: 6, y: 3)); path.line(to: NSPoint(x: 18, y: 3))
+        path.line(to: NSPoint(x: 18, y: 10))
+        path.curve(to: NSPoint(x: 12, y: 17), controlPoint1: NSPoint(x: 18, y: 14), controlPoint2: NSPoint(x: 16, y: 17))
+        path.curve(to: NSPoint(x: 6, y: 10), controlPoint1: NSPoint(x: 8, y: 17), controlPoint2: NSPoint(x: 6, y: 14))
+        path.close()
+        path.move(to: NSPoint(x: 6, y: 5)); path.line(to: NSPoint(x: 2, y: 5)); path.line(to: NSPoint(x: 2, y: 9))
+        path.curve(to: NSPoint(x: 6, y: 13), controlPoint1: NSPoint(x: 2, y: 12), controlPoint2: NSPoint(x: 4, y: 13))
+        path.move(to: NSPoint(x: 18, y: 5)); path.line(to: NSPoint(x: 22, y: 5)); path.line(to: NSPoint(x: 22, y: 9))
+        path.curve(to: NSPoint(x: 18, y: 13), controlPoint1: NSPoint(x: 22, y: 12), controlPoint2: NSPoint(x: 20, y: 13))
+        path.move(to: NSPoint(x: 12, y: 17)); path.line(to: NSPoint(x: 12, y: 21))
+        path.move(to: NSPoint(x: 8, y: 21)); path.line(to: NSPoint(x: 16, y: 21))
+        path.line(to: NSPoint(x: 18, y: 24)); path.line(to: NSPoint(x: 6, y: 24)); path.close()
+        color.setStroke(); path.stroke()
+        NSGraphicsContext.restoreGraphicsState()
+    }
+}
+
+/// 所有成就图标的唯一映射；首页、图鉴、详情和预览共用，独立于解锁状态。
+enum AchievementIconCatalog {
+    private static let symbols: [Int: [String]] = [
+        1: ["hand.tap", "hand.point.up"], 2: ["music.note"], 3: ["flag"], 4: ["sparkles"],
+        5: ["square.grid.2x2"], 6: ["star"], 7: ["link"], 8: ["waveform.path", "waveform"],
+        9: ["checkmark.circle"], 10: ["timer"], 11: ["flame"], 12: ["bolt"],
+        13: ["flag.checkered", "flag"], 14: ["hare"], 15: ["bolt.circle"], 16: ["stopwatch"],
+        17: ["square.stack"], 18: ["square.stack.3d.up", "square.stack"],
+        19: ["map"], 20: ["calendar.badge.clock", "calendar"]
+    ]
+    private static var cache: [String: NSImage] = [:]
+
+    static func accent(for definition: AchievementDefinition) -> NSColor {
+        if case .pieceCleared(let kind, _) = definition.goal { return kind.color }
+        return HomeStyle.ink
+    }
+
+    static func image(for definition: AchievementDefinition, muted: Bool = false) -> NSImage {
+        let key = "\(definition.id).\(muted)"
+        if let cached = cache[key] { return cached }
+        let color = muted ? HomeStyle.muted : accent(for: definition)
+        let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { _ in
+            if case .pieceCleared(let kind, let count) = definition.goal {
+                // 类型里程碑用四格轮廓及一、二、三颗进度点区分百、千、万档。
+                let cell: CGFloat = 11
+                for block in kind.blocks {
+                    let rect = NSRect(x: 7 + CGFloat(block.x) * cell, y: 9 + CGFloat(1 - block.y) * cell, width: 10, height: 10)
+                    color.withAlphaComponent(0.12).setFill()
+                    let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
+                    path.fill(); color.setStroke(); path.lineWidth = 1.6; path.stroke()
+                }
+                let tier = count == 100 ? 1 : count == 1_000 ? 2 : 3
+                color.setFill()
+                for index in 0..<tier {
+                    NSBezierPath(ovalIn: NSRect(x: 24 - CGFloat(tier) * 3.5 + CGFloat(index) * 7, y: 38, width: 4, height: 4)).fill()
+                }
+            } else {
+                let names = symbols[definition.id] ?? ["rosette"]
+                GameIconRenderer.drawSymbol(names[0], in: NSRect(x: 5, y: 4, width: 38, height: 39), color: color,
+                                            fallbacks: Array(names.dropFirst()))
+            }
+            return true
+        }
+        image.isTemplate = false
+        cache[key] = image
+        return image
+    }
+}
```

### `Sources/AchievementIconGalleryView.swift`

```diff
--- /dev/null
+++ b/Sources/AchievementIconGalleryView.swift
@@ -0,0 +1,88 @@
+import Cocoa
+
+/// 保留原生按钮的键盘操作和辅助功能，视觉与首页的线条图标保持一致。
+private final class AchievementIconPreviewButton: HomeButton {
+    let definition: AchievementDefinition
+    init(definition: AchievementDefinition) {
+        self.definition = definition
+        super.init(frame: .zero)
+        tag = definition.id
+        setAccessibilityLabel(AchievementText.string(definition.titleKey))
+        toolTip = AchievementText.string(definition.titleKey) + "\n" + AchievementText.string(definition.descriptionKey)
+    }
+    required init?(coder: NSCoder) { nil }
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.card(bounds, fill: .white, border: hovering ? HomeStyle.blue : HomeStyle.border, radius: 10)
+        let badge = NSRect(x: bounds.midX - 27, y: 12, width: 54, height: 54)
+        AchievementIconCatalog.accent(for: definition).withAlphaComponent(0.05).setFill()
+        NSBezierPath(ovalIn: badge).fill()
+        AchievementIconCatalog.image(for: definition).draw(in: badge.insetBy(dx: 4, dy: 4), from: .zero,
+                                                           operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+        HomeStyle.text(AchievementText.string(definition.titleKey),
+                       in: NSRect(x: 7, y: 77, width: bounds.width - 14, height: 22),
+                       size: 13, weight: .semibold, alignment: .center)
+        HomeStyle.text(String(format: "%02d", definition.id),
+                       in: NSRect(x: 8, y: 103, width: bounds.width - 16, height: 17),
+                       size: 10, color: HomeStyle.secondary, alignment: .center)
+    }
+}
+
+/// 无需解锁即可查看全部图标；只展示成就定义，不访问或修改玩家进度。
+final class AchievementIconGalleryView: NSView {
+    var onSelect: ((Int) -> Void)?
+    private var heightConstraint: NSLayoutConstraint?
+    private var buttons: [AchievementIconPreviewButton] = []
+    private let gap: CGFloat = 12
+    private let cardHeight: CGFloat = 126
+    override var isFlipped: Bool { true }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        setAccessibilityElement(true)
+        setAccessibilityRole(.group)
+        setAccessibilityLabel(AchievementText.format("achievement.preview.summary", AchievementDefinition.all.count))
+        for definition in AchievementDefinition.all {
+            let button = AchievementIconPreviewButton(definition: definition)
+            button.onClick = { [weak self] in self?.onSelect?(definition.id) }
+            buttons.append(button)
+            addSubview(button)
+        }
+    }
+    required init?(coder: NSCoder) { nil }
+
+    func constrainHeight() {
+        heightConstraint = heightAnchor.constraint(equalToConstant: contentHeight(for: bounds.width))
+        heightConstraint?.isActive = true
+    }
+
+    override func setFrameSize(_ newSize: NSSize) {
+        super.setFrameSize(newSize)
+        heightConstraint?.constant = contentHeight(for: newSize.width)
+        needsDisplay = true
+        needsLayout = true
+    }
+
+    override func layout() {
+        super.layout()
+        for (index, button) in buttons.enumerated() { button.frame = cardRect(at: index) }
+    }
+
+    func contentHeight(for width: CGFloat) -> CGFloat {
+        let columns = columnCount(for: width)
+        let rows = (AchievementDefinition.all.count + columns - 1) / columns
+        return CGFloat(rows) * (cardHeight + gap) - gap
+    }
+
+    private func columnCount(for width: CGFloat) -> Int { max(2, min(4, Int((width + gap) / 142))) }
+
+    private func cardRect(at index: Int) -> NSRect {
+        let columns = columnCount(for: bounds.width)
+        let width = (bounds.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
+        return NSRect(x: CGFloat(index % columns) * (width + gap), y: CGFloat(index / columns) * (cardHeight + gap),
+                      width: width, height: cardHeight)
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.background.setFill(); bounds.fill()
+    }
+}
```

### `Tests/GameIconPresentationTests.swift`

```diff
--- /dev/null
+++ b/Tests/GameIconPresentationTests.swift
@@ -0,0 +1,116 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class GameIconPresentationTests: AchievementTestCase {
+    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
+
+    private func bitmap(_ image: NSImage) throws -> NSBitmapImageRep {
+        try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
+    }
+
+    private func inkBounds(_ bitmap: NSBitmapImageRep) -> NSRect {
+        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
+        for y in 0..<bitmap.pixelsHigh {
+            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
+                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
+            }
+        }
+        guard maxX >= minX else { return .zero }
+        return NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
+    }
+
+    func testSystemSymbolsKeepTheirInkAspectRatio() throws {
+        _ = NSApplication.shared
+        for name in ["infinity", "music.note", "hand.tap", "flag"] {
+            let original = try XCTUnwrap(NSImage(systemSymbolName: name, accessibilityDescription: nil))
+                .withSymbolConfiguration(.init(pointSize: 32, weight: .regular))!
+            // 先放大参考矢量再测量，避免原始十几像素的字形取整放大比例误差。
+            let reference = NSImage(size: NSSize(width: original.size.width * 4, height: original.size.height * 4), flipped: true) { rect in
+                original.draw(in: rect)
+                return true
+            }
+            let baseline = inkBounds(try bitmap(reference))
+            for size in [NSSize(width: 64, height: 64), NSSize(width: 100, height: 40)] {
+                let rendered = NSImage(size: size, flipped: true) { bounds in
+                    HomeStyle.symbol(name, in: bounds)
+                    return true
+                }
+                let ink = inkBounds(try bitmap(rendered))
+                XCTAssertGreaterThan(ink.width, 0)
+                XCTAssertEqual(ink.width / ink.height, baseline.width / baseline.height, accuracy: 0.15, name)
+            }
+        }
+    }
+
+    func testEveryModeAndAchievementRendersIncludingLocalTrophyAndAllTiers() throws {
+        for mode in HomeGameMode.allCases {
+            let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { bounds in
+                HomeStyle.symbol(mode.symbol, in: bounds.insetBy(dx: 3, dy: 3))
+                return true
+            }
+            XCTAssertGreaterThan(inkBounds(try bitmap(image)).width, 16, mode.key)
+        }
+        for definition in AchievementDefinition.all {
+            for muted in [false, true] {
+                let ink = inkBounds(try bitmap(AchievementIconCatalog.image(for: definition, muted: muted)))
+                XCTAssertGreaterThan(ink.width, 10, "成就 \(definition.id) 不应显示空图标")
+                XCTAssertGreaterThan(ink.height, 10)
+            }
+        }
+        for first in [21, 24, 27, 30] {
+            let data = try (first...first + 2).map { id in
+                try XCTUnwrap(AchievementIconCatalog.image(for: AchievementDefinition.all[id - 1]).tiffRepresentation)
+            }
+            XCTAssertEqual(Set(data).count, 3, "同一类型的百、千、万图标应可区分")
+        }
+    }
+
+    func testPreviewIsAvailableWithoutUnlocksAndOpensRealDetails() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
+        let controller = AchievementsWindowController(manager: manager)
+        defer { controller.close() }
+        controller.refresh()
+        let content = try XCTUnwrap(controller.window?.contentView)
+        let preview = try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.first { $0.title == "图标预览" })
+        preview.performClick(nil)
+        content.layoutSubtreeIfNeeded()
+        let gallery = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementIconGalleryView }.first)
+        gallery.layoutSubtreeIfNeeded()
+        let cards = gallery.subviews.compactMap { $0 as? NSButton }
+        XCTAssertEqual(cards.map(\.tag).sorted(), Array(1...32))
+        XCTAssertTrue(cards.allSatisfy { gallery.bounds.contains($0.frame) })
+        try XCTUnwrap(cards.first { $0.tag == 32 }).performClick(nil)
+        XCTAssertNil(descendants(content).first { $0 is AchievementIconGalleryView })
+        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 1)
+        XCTAssertTrue(descendants(content).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "红色万格" })
+        XCTAssertEqual(manager.unlockedIDs(), [])
+        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
+    }
+
+    func testGalleryRendersAllLanguagesAndExportsAllThirtyTwoIcons() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            for width: CGFloat in [416, 568, 760] {
+                let gallery = AchievementIconGalleryView(frame: .zero)
+                gallery.frame = NSRect(x: 0, y: 0, width: width, height: gallery.contentHeight(for: width))
+                gallery.layoutSubtreeIfNeeded()
+                XCTAssertEqual(gallery.subviews.count, 32)
+                XCTAssertTrue(gallery.subviews.allSatisfy { gallery.bounds.contains($0.frame) })
+                if language == .chineseSimplified, width == 760 {
+                    let bitmap = try XCTUnwrap(gallery.bitmapImageRepForCachingDisplay(in: gallery.bounds))
+                    gallery.cacheDisplay(in: gallery.bounds, to: bitmap)
+                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+                    try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-all-achievement-icons.png"))
+                }
+            }
+        }
+    }
+}
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -201,3 +201,8 @@
 "home.unlocked_count" = "Unlocked %d / %d";
 "home.rules.fixed" = "Each cleared tile earns 10 points. Score Attack lasts 60 seconds; Speed Run ends at 300 points. Switching modes or restarting clears this round’s counters. Lifetime achievement progress is saved.";
 "home.records.fixed" = "Fixed rules: 60-second Score Attack · 300-point Speed Run";
+
+// 成就图标预览，无需解锁即可查看。
+"achievement.icon_preview" = "Icon gallery";
+"achievement.preview.summary" = "All %d achievement icons";
+"achievement.preview.hint" = "Select an icon to see its requirements.";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -194,3 +194,8 @@
 "home.unlocked_count" = "達成 %d / %d";
 "home.rules.fixed" = "1 個消すと 10 点。スコアアタックは 60 秒、スピードランは 300 点で終了。モード変更や再開で一局の記録はリセットされ、実績の累計は保存されます。";
 "home.records.fixed" = "固定ルール：60 秒スコアアタック · 300 点スピードラン";
+
+// 成就图标预览，无需解锁即可查看。
+"achievement.icon_preview" = "アイコン一覧";
+"achievement.preview.summary" = "全 %d 個の実績アイコン";
+"achievement.preview.hint" = "アイコンを選ぶと達成条件を確認できます。";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -194,3 +194,8 @@
 "home.unlocked_count" = "달성 %d / %d";
 "home.rules.fixed" = "블록 하나당 10점입니다. 점수 도전은 60초, 스피드런은 300점에 도달하면 끝납니다. 모드 변경이나 재시작 시 현재 판의 통계는 초기화되며 업적의 누적 진행은 유지됩니다.";
 "home.records.fixed" = "고정 규칙: 60초 점수 도전 · 300점 스피드런";
+
+// 成就图标预览，无需解锁即可查看。
+"achievement.icon_preview" = "아이콘 미리보기";
+"achievement.preview.summary" = "전체 업적 아이콘 %d개";
+"achievement.preview.hint" = "아이콘을 선택하면 달성 조건을 볼 수 있습니다.";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -194,3 +194,8 @@
 "home.unlocked_count" = "Открыто %d / %d";
 "home.rules.fixed" = "Каждый удалённый блок даёт 10 очков. Игра на очки длится 60 секунд; игра на скорость завершается при 300 очках. Смена режима или перезапуск обнуляет статистику игры, но сохраняет общий прогресс достижений.";
 "home.records.fixed" = "Правила: 60 секунд на очки · 300 очков на скорость";
+
+// 成就图标预览，无需解锁即可查看。
+"achievement.icon_preview" = "Все значки";
+"achievement.preview.summary" = "Все значки достижений: %d";
+"achievement.preview.hint" = "Выберите значок, чтобы увидеть условия.";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -201,3 +201,8 @@
 "home.unlocked_count" = "已解锁 %d / %d";
 "home.rules.fixed" = "每个消除方块计 10 分。竞分固定 60 秒，竞速固定 300 分；达到条件后自动结束。切换模式或重新开始会清零本局统计，成就累计进度会保留。";
 "home.records.fixed" = "固定规则：竞分 60 秒 · 竞速 300 分";
+
+// 成就图标预览，无需解锁即可查看。
+"achievement.icon_preview" = "图标预览";
+"achievement.preview.summary" = "全部 %d 枚成就图标";
+"achievement.preview.hint" = "点击图标查看达成条件。";
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -11,6 +11,7 @@
 - 三种模式均需点击开始；竞分固定 60 秒，竞速固定 300 分，首页不再提供档位设置。旧挑战记录保留，成就按固定规则兼容升级并保留已解锁状态。
 - 首页及辅助面板在探索分支使用暖白、蓝色选择态与黄色主操作的浅色主题，替代旧版桌面像素背景；Touch Bar 棋盘绘制链路沿用既有实现。
 - 首页主插画直接使用设计稿提取的本地透明资源，按四种形状独立缓存和浮动；图片与语言表共用 `GameResourceLocator` 定位资源，运行时不依赖网络或三维渲染服务。
+- 模式与成就图标共用 `GameIconRenderer` 的等比绘制和系统兼容路径；成就图标统一由 `AchievementIconCatalog` 映射，图标预览只读取定义，不修改玩家解锁或累计数据。
 
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
+`workflow/20261031201958-icon-aspect-and-achievement-gallery.md` - 会话-71 起修复系统图标拉伸与竞分奖杯缺失，统一全部成就图标，新增无需解锁的图标预览与可分享总览；含全部逐行 diff、50 项完整回归及真实渲染验收。
 `workflow/20261030090548-use-original-design-cutouts.md` - 会话-64 起直接从原始设计稿提取方块、投影、短线和箭头，按原稿坐标整体等比排列；主体像素保真验证、独立浮动及 46 项完整回归，含全部增量 diff 和资源校验。
 `workflow/20261030085356-home-hero-studio-artwork.md` - 会话-59 起以 imagegen 透明立体图集替换程序渐变插画；独立缓存与浮动、共用资源定位、透明和四种轮廓验证，含本轮完整增量 diff 与 46 项完整回归。
 `workflow/20261030083751-home-hero-3d-material.md` - 会话-55 起细化首页四种方块插画：立体侧面、柔和倒角、哑光微纹理及落地色影；修复短线裁切，含本轮完整增量 diff 和 5 项首页回归。
@@ -69,6 +70,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整模式/成就图标的比例、奖杯兼容路径、32 枚图标映射或无需解锁的图标预览入口时，读取 `20261031201958-icon-aspect-and-achievement-gallery.md`。
 - 需要调整当前首页原稿提取素材、复现抠图、核对像素保真或原稿相对布局时，读取 `20261030090548-use-original-design-cutouts.md`。
 - 需要调整当前首页立体插画图集、实体缩放边界、透明资源加载或查看生成提示词时，读取 `20261030085356-home-hero-studio-artwork.md`。
 - 需要调整浅色首页主插画的 3D 材质、光照、投影、装饰短线或绘制缓存时，读取 `20261030083751-home-hero-3d-material.md`。
@@ -138,6 +140,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 模式与成就图标集中在 `Sources/GameIcons.swift`：`GameIconRenderer` 等比居中并缓存固定分辨率字形，奖杯/终点旗有本地路径；`AchievementIconCatalog` 是 32 枚成就图标的统一入口。成就图鉴的“图标预览”可查看全部图标，不更改存档；静态总览位于 `docs/previews/achievement-icons.png`。
 - 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
 - 本局分类数量来自 `GameState`/`GameSnapshot`，重开或实际切换模式清零；点击已选模式不清零。跨局成就继续由 `AchievementsManager` 持久化。
```

### `docs/previews/README.md`

```diff
--- /dev/null
+++ b/docs/previews/README.md
@@ -0,0 +1,20 @@
+# 界面预览
+
+## 全部成就图标
+
+![全部 32 枚成就图标](achievement-icons.png)
+
+- 图标定义集中在 `Sources/GameIcons.swift` 的 `AchievementIconCatalog`，不依赖成就是否解锁。
+- 常规图标使用 SF Symbols（系统矢量符号），奖杯、终点旗和四种方块里程碑使用本地矢量路径。
+- 类型里程碑的一、二、三个圆点分别对应百、千、万档。
+- 当前 PNG 由真实 AppKit 视图导出，供完整预览；应用运行时使用共用图标绘制，不读取此总览图。
+- 游戏中的入口：成就模块“查看全部” → “图标预览”；点击图标可查看真实达成条件。
+- 预览不会解锁成就，也不会修改进度或本地存档。
+
+## 更新预览
+
+执行下列现有回归后，将系统临时目录中的 `eliminate-all-achievement-icons.png` 复制到本目录的 `achievement-icons.png`。
+
+```sh
+DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameIconPresentationTests
+```
```

### `docs/previews/achievement-icons.png`

```diff
diff --git a/docs/previews/achievement-icons.png b/docs/previews/achievement-icons.png
new file mode 100644
Binary files /dev/null and b/docs/previews/achievement-icons.png differ
```
