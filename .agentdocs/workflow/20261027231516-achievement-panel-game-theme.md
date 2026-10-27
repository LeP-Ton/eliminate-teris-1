# 成就面板统一主界面像素主题

## 背景与目标
- 对应会话：会话-26 起，用户要求成就面板的 UI 风格与游戏主界面保持一致。
- 将系统浅色面板、白色行卡片与灰色进度条统一为主界面的深色像素主题，覆盖全部成就与单项详情。
- 基线提交：`6f8c506f68ce1a9cc30588d378cb1505a61c2917`；本轮开始时工作区干净。本文记录本轮全部逐行 diff，便于按会话回溯。

## 约束与原则
- 保持成就定义、进度、存档、解锁通知和 Touch Bar 逻辑不变。
- 保持既有主窗口居中定位、屏幕边界保护和非模态/不争夺键盘焦点行为。
- 直接复用现有 AppKit 绘制组件，不引入图片资源或第三方 UI 依赖。
- 既有五语言文案与全部/未解锁/已解锁筛选语义保持不变。

## 阶段与 TODO
- [x] 复用主界面扫描线、像素矩阵和蓝紫色背景光晕。
- [x] 复用主界面内外双框与四角像素卡片，覆盖面板头部及成就行。
- [x] 统一标题、说明、进度与日期的等宽字体及主题色。
- [x] 将筛选控件和返回按钮绘制为深色红框控件，保留原生选择状态和辅助功能。
- [x] 将进度条绘制为分段像素样式，随锁定/解锁状态使用红色或浅绿色。
- [x] 完成真实视图渲染验收、五语言/双宽度布局和鼠标事件回归。
- [x] 更新核心认知、根索引和完整变更记录。

## 实现要点
- `ArcadeStageView` 和 `PixelFrameCardView` 从主控制器文件内私有组件调整为模块内共用组件；绘制算法保持不变，两个窗口复用相同实现。
- 成就面板采用固定深色外观，标题栏透明、背景深蓝；头部与行卡片使用共用像素角标边框。
- 红色对应主界面玩法说明/成就主题，浅绿色对应主界面状态主题；正文采用浅粉色，次要状态采用柔和灰粉色。
- 自绘筛选继承 `NSSegmentedControl`，继续使用既有 selectedSegment、label、target/action 和辅助功能语义；按可见标签区域处理鼠标事件。
- 像素进度条继承 `NSProgressIndicator`，保留现有数值和辅助功能接口，以自绘轨道与分段填充呈现进度。
- 测试只增强既有原生界面回归，使用隔离存档；预览图片仅写入临时目录，不作为发布资源。

## 测试用例与结果

### TC-001 筛选按钮真实点击
- 类型：原生界面回归；优先级：高；模块：AchievementsWindowController。
- 前置条件：创建成就面板，测试存档包含一枚已解锁成就。
- 操作步骤：通过真实 NSEvent 鼠标事件点击“已解锁”和“未解锁”按钮。
- 预期结果：选择状态和实际成就行数量同步变化，面板不获取主窗口或键盘焦点。
- 是否通过：通过。

### TC-002 多语言布局与渲染
- 类型：布局/视觉验收；优先级：高。
- 前置条件：加载中、英、日、韩、俄五种语言的真实文案。
- 操作步骤：在 480/600 点宽度下布局图鉴，检查滚动内容和进度条尺寸；将中文视图渲染为 PNG 后实际查看。
- 预期结果：长文案正常换行，内容可滚动，进度条无尺寸异常；扫描线、像素角标、字体、颜色和筛选按钮与主界面一致。
- 是否通过：通过；已实际查看临时 PNG 预览。

### TC-003 标签与窗口定位回归
- 类型：界面回归；优先级：高。
- 操作步骤：运行五枚标签完整显示、图文居中/点击、首次打开居中、主窗口移动后重开与屏幕边缘用例。
- 预期结果：主题改动不影响徽章栏与窗口定位。
- 是否通过：通过。

## 当前进展与验证
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementPresentationTests`：6 项测试，0 失败；已完成应用编译与链接。
- `git diff --check`：通过。
- 临时预览：`eliminate-achievement-panel-preview.png`，由 XCTest 使用隔离数据渲染，路径由测试输出打印；预览日期是测试时钟，非玩家真实数据。
- 用户当前运行的进程未被重启，重启游戏后可查看新主题。

## 代码变更

以下为本轮全部代码、测试、核心认知和索引的完整逐行 diff。

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -1823,7 +1823,8 @@
     }
 }
 
-private final class ArcadeStageView: NSView {
+/// 主窗口与成就面板共用像素背景，统一扫描线与光晕效果。
+final class ArcadeStageView: NSView {
     private var animationTick: CGFloat = 0
     private var animationTimer: Timer?
 
@@ -1917,7 +1918,8 @@
     }
 }
 
-private final class PixelFrameCardView: NSView {
+/// 共用主题卡片，边框、内框和四角像素在各窗口保持一致。
+final class PixelFrameCardView: NSView {
     private let accentColor: NSColor
 
     init(accentColor: NSColor) {
```

### `Sources/AchievementViews.swift`

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -176,6 +176,112 @@
     @objc private func badgeTapped(_ sender: NSButton) { onSelect?(sender.tag) }
 }
 
+/// 成就沿用主界面的红色卡片主题，已解锁项目使用状态栏同款浅绿色。
+private enum AchievementPanelStyle {
+    static let accent = NSColor(calibratedRed: 1, green: 0.53, blue: 0.5, alpha: 0.96)
+    static let success = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
+    static let body = NSColor(calibratedRed: 1, green: 0.82, blue: 0.82, alpha: 0.9)
+    static let muted = NSColor(calibratedRed: 0.78, green: 0.71, blue: 0.75, alpha: 1)
+    static let controlFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
+
+    static func drawControl(_ rect: NSRect, title: String, selected: Bool) {
+        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
+        NSColor(calibratedRed: selected ? 0.27 : 0.12, green: 0.14, blue: 0.2, alpha: 1).setFill()
+        path.fill()
+        accent.withAlphaComponent(selected ? 0.95 : 0.4).setStroke()
+        path.lineWidth = 1
+        path.stroke()
+        let attributes: [NSAttributedString.Key: Any] = [
+            .font: controlFont,
+            .foregroundColor: selected ? accent : body
+        ]
+        let size = (title as NSString).size(withAttributes: attributes)
+        (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
+                                 withAttributes: attributes)
+    }
+}
+
+/// 保留原生分段控件的选择状态和辅助功能，以主题绘制代替系统浅色胶囊。
+private final class AchievementFilterControl: NSSegmentedControl {
+    override var intrinsicContentSize: NSSize {
+        NSSize(width: (0..<segmentCount).reduce(0) { $0 + segmentWidth($1) } + CGFloat(max(0, segmentCount - 1)) * 8,
+               height: 32)
+    }
+
+    func refreshMetrics() {
+        for index in 0..<segmentCount { setWidth(segmentWidth(index), forSegment: index) }
+        invalidateIntrinsicContentSize()
+        needsDisplay = true
+    }
+
+    private func segmentWidth(_ index: Int) -> CGFloat {
+        max(70, ceil(((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24)
+    }
+
+    private func segmentRect(_ index: Int) -> NSRect {
+        let x = (0..<index).reduce(CGFloat(0)) { $0 + segmentWidth($1) + 8 }
+        return NSRect(x: x, y: 0, width: segmentWidth(index), height: bounds.height)
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        for index in 0..<segmentCount {
+            AchievementPanelStyle.drawControl(segmentRect(index), title: label(forSegment: index) ?? "", selected: selectedSegment == index)
+        }
+    }
+
+    override func mouseDown(with event: NSEvent) {
+        let point = convert(event.locationInWindow, from: nil)
+        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }) else { return }
+        selectedSegment = index
+        needsDisplay = true
+        sendAction(action, to: target)
+    }
+}
+
+private final class AchievementPanelActionButton: NSButton {
+    override var intrinsicContentSize: NSSize {
+        NSSize(width: max(88, ceil((title as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24), height: 32)
+    }
+
+    override var isHighlighted: Bool { didSet { needsDisplay = true } }
+
+    override func draw(_ dirtyRect: NSRect) {
+        AchievementPanelStyle.drawControl(bounds, title: title, selected: isHighlighted)
+    }
+}
+
+/// 像素进度条沿用原生进度接口，显示颜色与所在成就卡片一致。
+private final class AchievementProgressIndicator: NSProgressIndicator {
+    var accentColor: NSColor = AchievementPanelStyle.accent
+
+    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 10) }
+
+    override func draw(_ dirtyRect: NSRect) {
+        let track = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
+        NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1).setFill()
+        track.fill()
+        accentColor.withAlphaComponent(0.3).setStroke()
+        track.lineWidth = 1
+        track.stroke()
+        let inner = bounds.insetBy(dx: 3, dy: 3)
+        guard inner.width > 0, inner.height > 0 else { return }
+        let fraction = min(1, max(0, (doubleValue - minValue) / max(1, maxValue - minValue)))
+        let filledWidth = inner.width * fraction
+        var x = inner.minX
+        while x < inner.maxX {
+            let width = min(6, inner.maxX - x)
+            accentColor.withAlphaComponent(0.1).setFill()
+            NSBezierPath(rect: NSRect(x: x, y: inner.minY, width: width, height: inner.height)).fill()
+            let activeWidth = min(width, max(0, inner.minX + filledWidth - x))
+            if activeWidth > 0 {
+                accentColor.setFill()
+                NSBezierPath(rect: NSRect(x: x, y: inner.minY, width: activeWidth, height: inner.height)).fill()
+            }
+            x += 9
+        }
+    }
+}
+
 /// 面板不争夺主窗口焦点，点击筛选时仍保留 Touch Bar 的游戏棋盘。
 private final class AchievementPanel: NSPanel {
     override var canBecomeKey: Bool { false }
@@ -188,9 +294,9 @@
 
 final class AchievementsWindowController: NSWindowController {
     private let manager: AchievementsManager
-    private let filter = NSSegmentedControl()
+    private let filter = AchievementFilterControl()
     private let heading = NSTextField(labelWithString: "")
-    private let backButton = NSButton()
+    private let backButton = AchievementPanelActionButton()
     private let list = NSStackView()
     private let scroll = NSScrollView()
     private var detailID: Int?
@@ -203,6 +309,10 @@
         panel.isReleasedWhenClosed = false
         panel.hidesOnDeactivate = true
         panel.minSize = NSSize(width: 480, height: 360)
+        panel.appearance = NSAppearance(named: .darkAqua)
+        panel.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1)
+        panel.titlebarAppearsTransparent = true
+        panel.contentView = ArcadeStageView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))
         super.init(window: panel)
         buildContent()
     }
@@ -245,11 +355,13 @@
         window?.title = AchievementText.string("panel.achievements")
         heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
         backButton.title = AchievementText.string("achievement.view_all")
+        backButton.invalidateIntrinsicContentSize()
         backButton.isHidden = detailID == nil
         filter.isHidden = detailID != nil
         for (index, key) in ["all", "locked", "unlocked"].enumerated() {
             filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
         }
+        filter.refreshMetrics()
         list.arrangedSubviews.forEach { view in
             list.removeArrangedSubview(view)
             view.removeFromSuperview()
@@ -266,8 +378,8 @@
             let group = definitions.filter { $0.category == category }
             guard !group.isEmpty else { continue }
             let label = NSTextField(labelWithString: AchievementText.string("achievement.category.\(category.rawValue)"))
-            label.font = .systemFont(ofSize: 13, weight: .bold)
-            label.textColor = .systemRed
+            label.font = .monospacedSystemFont(ofSize: 12, weight: .heavy)
+            label.textColor = AchievementPanelStyle.accent
             list.addArrangedSubview(label)
             for definition in group {
                 let row = makeRow(definition)
@@ -276,29 +388,48 @@
             }
         }
         if definitions.isEmpty {
-            list.addArrangedSubview(NSTextField(labelWithString: AchievementText.string("achievement.empty")))
+            let empty = NSTextField(wrappingLabelWithString: AchievementText.string("achievement.empty"))
+            empty.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
+            empty.textColor = AchievementPanelStyle.body
+            list.addArrangedSubview(empty)
         }
     }
 
     private func buildContent() {
         guard let content = window?.contentView else { return }
-        heading.font = .systemFont(ofSize: 16, weight: .semibold)
+        heading.font = .monospacedSystemFont(ofSize: 16, weight: .heavy)
+        heading.textColor = AchievementPanelStyle.accent
+        heading.lineBreakMode = .byTruncatingTail
+        heading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         filter.segmentCount = 3
         filter.trackingMode = .selectOne
         filter.selectedSegment = 0
         filter.target = self
         filter.action = #selector(filterChanged)
-        backButton.bezelStyle = .rounded
+        backButton.isBordered = false
+        backButton.setButtonType(.momentaryPushIn)
         backButton.target = self
         backButton.action = #selector(showAll)
         let actions = NSStackView(views: [filter, backButton])
         actions.orientation = .horizontal
-        let toolbar = NSStackView(views: [heading, actions])
+        let icon = NSImageView(image: NSImage(systemSymbolName: "rosette", accessibilityDescription: nil) ?? NSImage())
+        icon.contentTintColor = AchievementPanelStyle.accent
+        icon.translatesAutoresizingMaskIntoConstraints = false
+        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
+        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
+        let titleRow = NSStackView(views: [icon, heading])
+        titleRow.orientation = .horizontal
+        titleRow.alignment = .centerY
+        titleRow.spacing = 8
+        let toolbar = NSStackView(views: [titleRow, actions])
         toolbar.orientation = .vertical
         toolbar.alignment = .leading
-        toolbar.spacing = 8
+        toolbar.spacing = 12
         toolbar.translatesAutoresizingMaskIntoConstraints = false
-        content.addSubview(toolbar)
+        let header = PixelFrameCardView(accentColor: AchievementPanelStyle.accent)
+        header.translatesAutoresizingMaskIntoConstraints = false
+        header.addSubview(toolbar)
+        content.addSubview(header)
 
         scroll.translatesAutoresizingMaskIntoConstraints = false
         scroll.hasVerticalScroller = true
@@ -314,10 +445,17 @@
         list.translatesAutoresizingMaskIntoConstraints = false
         document.addSubview(list)
         NSLayoutConstraint.activate([
-            toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
-            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
-            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
-            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 14),
+            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
+            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
+            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
+            toolbar.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
+            toolbar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
+            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
+            toolbar.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
+            titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
+            filter.heightAnchor.constraint(equalToConstant: 32),
+            backButton.heightAnchor.constraint(equalToConstant: 32),
+            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
             scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
             scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
             scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
@@ -331,18 +469,15 @@
 
     private func makeRow(_ definition: AchievementDefinition) -> NSView {
         let unlocked = manager.isUnlocked(id: definition.id)
-        let row = NSView()
-        row.wantsLayer = true
-        row.layer?.cornerRadius = 8
-        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
-        row.layer?.borderWidth = 1
-        row.layer?.borderColor = (unlocked ? NSColor.systemGreen : NSColor.separatorColor).cgColor
+        let accent = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.accent
+        let row = PixelFrameCardView(accentColor: accent)
         row.translatesAutoresizingMaskIntoConstraints = false
         let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
-        name.font = .systemFont(ofSize: 14, weight: .semibold)
+        name.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
+        name.textColor = accent
         name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
         let icon = NSImageView(image: NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil) ?? NSImage())
-        icon.contentTintColor = unlocked ? .systemGreen : .secondaryLabelColor
+        icon.contentTintColor = accent
         icon.translatesAutoresizingMaskIntoConstraints = false
         icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
         icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
@@ -350,12 +485,17 @@
         titleRow.orientation = .horizontal
         titleRow.spacing = 6
         let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
-        condition.textColor = .secondaryLabelColor
+        condition.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
+        condition.textColor = AchievementPanelStyle.body
         let progress = NSTextField(wrappingLabelWithString: AchievementText.progress(definition, manager: manager))
+        progress.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
+        progress.textColor = accent
         let status = NSTextField(wrappingLabelWithString: AchievementText.status(definition, manager: manager))
-        status.font = .systemFont(ofSize: 11)
-        status.textColor = unlocked ? .systemGreen : .secondaryLabelColor
-        let meter = NSProgressIndicator()
+        status.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
+        status.textColor = unlocked ? AchievementPanelStyle.success : AchievementPanelStyle.muted
+        let meter = AchievementProgressIndicator()
+        meter.accentColor = accent
+        meter.heightAnchor.constraint(equalToConstant: 10).isActive = true
         meter.style = .bar
         meter.isIndeterminate = false
         meter.minValue = 0
@@ -365,7 +505,7 @@
         let stack = NSStackView(views: [titleRow, condition, progress, meter, status])
         stack.orientation = .vertical
         stack.alignment = .leading
-        stack.spacing = 7
+        stack.spacing = 9
         stack.translatesAutoresizingMaskIntoConstraints = false
         row.addSubview(stack)
         for view in stack.arrangedSubviews {
@@ -373,10 +513,10 @@
             view.setContentCompressionResistancePriority(.required, for: .vertical)
         }
         NSLayoutConstraint.activate([
-            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
-            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
-            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
-            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
+            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
+            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
+            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
+            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
         ])
         return row
     }
```

### `Tests/AchievementPresentationTests.swift`

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -21,16 +21,25 @@
         let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
         func progressBars() -> Int { descendants(content).filter { $0 is NSProgressIndicator }.count }
         XCTAssertEqual(progressBars(), 20)
-        filter.selectedSegment = 2
-        XCTAssertTrue(filter.sendAction(filter.action, to: filter.target))
+        content.layoutSubtreeIfNeeded()
+        // 使用真实鼠标事件验证主题控件的点击区域，而非直接修改选择状态。
+        func clickFilter(at fraction: CGFloat) throws {
+            let point = filter.convert(NSPoint(x: filter.bounds.width * fraction, y: filter.bounds.midY), to: nil)
+            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
+                                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
+            filter.mouseDown(with: event)
+        }
+        try clickFilter(at: 5.0 / 6)
+        XCTAssertEqual(filter.selectedSegment, 2)
         XCTAssertEqual(progressBars(), 1)
-        filter.selectedSegment = 1
-        filter.sendAction(filter.action, to: filter.target)
+        try clickFilter(at: 0.5)
+        XCTAssertEqual(filter.selectedSegment, 1)
         XCTAssertEqual(progressBars(), 19)
     }
 
     func testLibraryRowsHaveUsableLayoutForEveryLanguage() throws {
         _ = NSApplication.shared
+        swap(score: 100)
         let original = Localizer.shared.language
         defer { Localizer.shared.setLanguage(original) }
         let panel = AchievementsWindowController(manager: manager)
@@ -51,6 +60,15 @@
                 for meter in descendants(document).compactMap({ $0 as? NSProgressIndicator }) {
                     XCTAssertGreaterThan(meter.frame.width, 300, language.rawValue)
                     XCTAssertGreaterThan(meter.frame.height, 0)
+                }
+                // 保留真实视图渲染用于视觉验收，产物仅写入临时目录。
+                if language == .chineseSimplified, width == 600 {
+                    let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
+                    content.cacheDisplay(in: content.bounds, to: bitmap)
+                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+                    let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-achievement-panel-preview.png")
+                    try png.write(to: preview)
+                    print("成就面板视觉预览：\(preview.path)")
                 }
             }
         }
```

### `AGENTS.md`

```diff
diff --git a/AGENTS.md b/AGENTS.md
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -4,6 +4,9 @@
 - 项目为 macOS 12+ 原生 AppKit/Cocoa 游戏，使用 Swift 5.7+ 与 Swift Package Manager；桌面窗口负责设置和信息展示，16 格 Touch Bar 承载核心操作。
 - 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
 - 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
+
+## 2026-10-27
+- 主窗口与成就面板共享 `ArcadeStageView` 背景和 `PixelFrameCardView` 卡片绘制组件；跨窗口界面沿用固定深色外观、等宽字体及模块主题色，保持视觉一致。
 
 ## 2026-10-26
 - 成就采用独立的事件驱动架构：`GameState` 提供交换结算数据，`GameBoardController` 提交交换与正常结算事件，`AchievementsManager` 负责规则、去重、累计进度和版本化本地存档；界面刷新与挑战排行榜不参与成就判定。
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261027231516-achievement-panel-game-theme.md` - 会话-26 起统一成就面板与主界面的深色像素主题：复用背景/卡片绘制，统一筛选、字体和像素进度条；含完整逐行 diff、真实渲染验收及 6 项界面回归结果。
 `workflow/20261027225436-achievement-panel-position.md` - 会话-21 起修复成就面板在屏幕边缘显示：先按主窗口定位再附加，每次打开重新居中并限制在当前屏幕可用区域；含完整增量 diff 和 6 项界面回归结果。
 `workflow/20261027224658-achievement-badge-layout.md` - 会话-16 起修复成就标签遮挡、图文居中与标签过宽；默认完整显示 5 枚，含本轮增量 diff 及 4 项界面回归测试结果。
 `workflow/20261026092356-achievement-system.md` - 会话-5 起实现 20 枚事件驱动成就、版本化存档迁移、五语言徽章/非模态图鉴与提示队列；含完整逐行 diff 和 29 项测试结果。
@@ -62,6 +63,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整成就图鉴/详情的深色主题、像素边框、字体、筛选控件、分段进度条或了解共用绘制组件时，读取 `20261027231516-achievement-panel-game-theme.md`。
 - 成就面板首次打开位置异常、需要跟随主窗口定位或处理靠近屏幕边缘时，读取 `20261027225436-achievement-panel-position.md`。
 - 需要调整成就徽章栏高度、默认五枚布局、图文居中、滚动条兼容或长名称展示时，读取 `20261027224658-achievement-badge-layout.md`。
 - 需要了解成就清单、真实交换/结算事件、旧成就迁移、进度存档、非模态图鉴或成就测试时，读取 `20261026092356-achievement-system.md`。
@@ -124,6 +126,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就面板现与主窗口复用 `ArcadeStageView` 扫描线背景与 `PixelFrameCardView` 像素卡片；面板使用深色外观、红色主题与等宽字体，已解锁项目采用浅绿色，原有窗口定位和筛选语义保持不变。
 - 成就面板需在 `addChildWindow` 之前完成定位，因为附加子窗口会使其可见；每次打开以主窗口 frame 为中心，并限制在主窗口所在屏幕的 visibleFrame 内，四边预留 8 点。
 - 成就卡片高度由标题、内边距与 64 点高的标签区域决定，不再与顶部横幅等高；标签按实际可视宽度适配五枚，图标与文字整体居中，长名称截断后可通过悬浮提示或详情查看。
 - 成就统计由棋盘控制器提交真实事件，独立于 HUD 刷新和挑战排行；累计值与历史最佳跨局保存，节奏/连续交换在重开和模式切换时清零。
```
