# 成就页动画筛选条

## 背景与目标
- 对应会话：会话-97 起；分支：`experiment/ui-refactor`。
- 用户认为成就页三个独立筛选按钮过于简陋，要求按专业游戏界面标准改善美观并加入切换动画。
- 保持主界面的暖白、深蓝和黄色主题，继续保留真实成就条件、计数、存档及非模态面板行为。
- 本文相对本轮开始的工作区快照记录增量，之前的图标迭代文档保持原样。

## 美术与交互
- 将三个独立边框按钮整合为一条暖灰色圆角轨道。
- 选中项使用暖金渐变滑块、轻微投影、细边和高光，文字与状态符号统一深蓝色。
- 每一项显示对应成就数量，使用等宽数字避免读数变化导致视觉跳动。
- 未选中项使用柔和文字和半透明数量底色，悬停时增强文字对比。
- 三段等宽铺满头部可用区域，控件高 44 点；取消原生分段胶囊的隐含边距，保证实际 frame 与设计尺寸一致。
- 长语言文案按可用宽度调整字号；滤条仍沿用原生 NSSegmentedControl 的语义、标签、选择值和 action。
- 切换后按真实状态重建列表并返回列表顶部，不创建额外窗口或测试预览入口。

## 动画实现
- 新增 `Sources/AchievementFilterControl.swift`，与成就面板事件协调分离。
- 选中滑块使用 CAGradientLayer（渐变图层），以位置与大小动画完成 0.24 秒缓入缓出过渡。
- 真实选择值与图层目标 frame 即时更新，动画只负责视觉反馈，不延迟筛选结果。
- 快速连续切换从当前展示层位置继续移动，替换旧动画，结束后落在最后一次选择上。
- 刷新数量、语言和列表时，如果几何目标未变化，不取消正在进行的滑动。
- 窗口尺寸变化时同步几何位置，避免布局缩放产生错误动画。
- 每次切换读取系统“减少动态效果”偏好，开启时立即定位；测试可注入该偏好验证两条路径。
- 鼠标、左右方向键及原生 Cell（控件单元）触发的选择均会同步视觉滑块。
- 图文覆盖层不截获点击，也不作为重复的辅助功能元素出现。

## 测试产物
- 动画：`docs/previews/achievement-filter.gif`，40 帧，使用实际 Core Animation 展示层导出，包含从全部到未解锁、已解锁并返回的滑动。
- 页面：`docs/previews/achievement-panel.png`，真实 AppKit 成就页，使用隔离测试进度模拟 5/32 解锁。
- 所有截图和动画由测试生成，不写入玩家真实存档，也不成为正式应用功能入口。

## 阶段与 TODO
- [x] 完成一体式轨道、暖金滑块、数量与悬停视觉。
- [x] 完成滑动动画与快速连续切换接续。
- [x] 保留原生选择语义、键盘和减少动态效果支持。
- [x] 接入真实成就数量与筛选回调，切换后回到列表顶部。
- [x] 验证五语言及两档面板宽度，导出实际动画和截图。
- [x] 完成完整回归、说明、根索引与完整增量 diff。

## 测试方法与结果

### TC-001 真实筛选和快速动画
- 使用真实鼠标事件点击成就页滤条，验证选择值、筛选结果和 0.24 秒动画存在。
- 刷新列表后动画保持；窗口展示时等待部分移动后再次点击，验证新动画起点取自当前展示位置。
- 快速切换后回到“全部”，验证图层目标与初始选择一致，列表返回 32 条。
- 结果：通过。

### TC-002 减少动态效果与原生选择
- 注入减少动态效果偏好，通过方向键和原生 Cell 选择触发真实 action。
- 验证滑块立即到达正确选项，未创建位移动画，筛选数据仍正确。
- 结果：通过。

### TC-003 五语言与面板布局
- 遍历现有五种语言和 480/600 点面板宽度，检查三种选择。
- 验证数量提示与真实解锁数一致，滑块位于控件内，实际控件高 44 点。
- 既有成就窗口布局、筛选、焦点、定位及卡片点击测试通过。

### TC-004 实际渲染与动画导出
- 导出真实成就页和实际图层展示过程 GIF，人工查看初始与运动中间帧。
- 确认文字方向、控件边距、高光、投影、数量及滑动过程正常，无截断或上下翻转。
- 结果：通过。

### TC-005 完整回归
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementFilterControlTests`：4 项通过。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：55 项通过，0 失败，最终完成于 2026-10-31 22:59:53。
- 包含既有游戏规则、成就/存档、五语言、图案保真、图标及界面回归。
- `git diff --check`：通过。
- 本轮仅调整展示组件和事件衔接，无整体核心架构变动；相关实现记入索引，不改写核心认知。
- 未重启用户当前游戏；可执行 `./run.sh` 体验实际面板的滑动切换。

## 产物校验

| 文件 | 字节数 | SHA-256 |
| --- | --- | --- |
| `docs/previews/achievement-filter.gif` | 365719 | `65bd5ed1bd56a94987435009bcd4881a63be1ecbb9ccdf215e5235ce0509156f` |
| `docs/previews/achievement-panel.png` | 163746 | `8ec340d07481a7d7d55b20f267b68cb889f95acec511bf9354940f94c6a0726f` |

## 代码变更

以下记录本轮全部源码、测试、说明和索引的完整逐行 diff；新增动画与截图以二进制变更和上述校验值记录。

### `Sources/AchievementViews.swift`

```diff
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -198,43 +198,6 @@
         let size = (title as NSString).size(withAttributes: attributes)
         (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                                  withAttributes: attributes)
-    }
-}
-
-/// 保留原生分段控件的选择状态和辅助功能，以主题绘制代替系统浅色胶囊。
-private final class AchievementFilterControl: NSSegmentedControl {
-    override var intrinsicContentSize: NSSize {
-        NSSize(width: (0..<segmentCount).reduce(0) { $0 + segmentWidth($1) } + CGFloat(max(0, segmentCount - 1)) * 8,
-               height: 32)
-    }
-
-    func refreshMetrics() {
-        for index in 0..<segmentCount { setWidth(segmentWidth(index), forSegment: index) }
-        invalidateIntrinsicContentSize()
-        needsDisplay = true
-    }
-
-    private func segmentWidth(_ index: Int) -> CGFloat {
-        max(70, ceil(((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: AchievementPanelStyle.controlFont]).width) + 24)
-    }
-
-    private func segmentRect(_ index: Int) -> NSRect {
-        let x = (0..<index).reduce(CGFloat(0)) { $0 + segmentWidth($1) + 8 }
-        return NSRect(x: x, y: 0, width: segmentWidth(index), height: bounds.height)
-    }
-
-    override func draw(_ dirtyRect: NSRect) {
-        for index in 0..<segmentCount {
-            AchievementPanelStyle.drawControl(segmentRect(index), title: label(forSegment: index) ?? "", selected: selectedSegment == index)
-        }
-    }
-
-    override func mouseDown(with event: NSEvent) {
-        let point = convert(event.locationInWindow, from: nil)
-        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }) else { return }
-        selectedSegment = index
-        needsDisplay = true
-        sendAction(action, to: target)
     }
 }
 
@@ -349,6 +312,8 @@
         for (index, key) in ["all", "locked", "unlocked"].enumerated() {
             filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
         }
+        let unlocked = manager.unlockedIDs().count
+        filter.updateCounts([AchievementDefinition.all.count, AchievementDefinition.all.count - unlocked, unlocked])
         filter.refreshMetrics()
         list.arrangedSubviews.forEach { view in
             list.removeArrangedSubview(view)
@@ -442,7 +407,9 @@
             toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
             toolbar.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
             titleRow.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
-            filter.heightAnchor.constraint(equalToConstant: 32),
+            actions.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
+            filter.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
+            filter.heightAnchor.constraint(equalToConstant: 44),
             backButton.heightAnchor.constraint(equalToConstant: 32),
             scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
             scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
@@ -511,7 +478,12 @@
         return row
     }
 
-    @objc private func filterChanged() { refresh() }
+    @objc private func filterChanged() {
+        refresh()
+        window?.contentView?.layoutSubtreeIfNeeded()
+        scroll.contentView.scroll(to: .zero)
+        scroll.reflectScrolledClipView(scroll.contentView)
+    }
     @objc private func showAll() { detailID = nil; refresh() }
 }
 
```

### `Sources/AchievementFilterControl.swift`

```diff
--- /dev/null
+++ b/Sources/AchievementFilterControl.swift
@@ -0,0 +1,199 @@
+import Cocoa
+import QuartzCore
+
+/// 滑轨只承载视觉过渡；真实选中值和筛选事件仍沿用原生 NSSegmentedControl。
+final class AchievementFilterControl: NSSegmentedControl {
+    private let thumb = CAGradientLayer()
+    private let labels = FilterLabelsView()
+    private var counts: [Int] = []
+    private var tracking: NSTrackingArea?
+    private var hoveredSegment: Int?
+    private var hasPlacedThumb = false
+    /// 在测试中可替换系统偏好，运行时每次切换都读取最新设置。
+    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
+    static let transitionDuration: CFTimeInterval = 0.24
+
+    override var isFlipped: Bool { true }
+    // 自绘轨道不使用系统分段胶囊的隐含外边距，避免 Auto Layout 放大实际 frame。
+    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
+    override var selectedSegment: Int { didSet { if oldValue != selectedSegment { positionThumb(animated: true) } } }
+
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        wantsLayer = true
+        labels.owner = self
+        labels.wantsLayer = true
+        addSubview(labels)
+        thumb.name = "achievement-filter-selection"
+        thumb.colors = [NSColor(calibratedRed: 1, green: 0.88, blue: 0.35, alpha: 1).cgColor,
+                        HomeStyle.yellow.cgColor]
+        thumb.startPoint = CGPoint(x: 0.5, y: 0)
+        thumb.endPoint = CGPoint(x: 0.5, y: 1)
+        thumb.cornerRadius = 9
+        thumb.borderWidth = 0.75
+        thumb.borderColor = NSColor(calibratedRed: 0.91, green: 0.66, blue: 0.05, alpha: 0.5).cgColor
+        thumb.shadowColor = NSColor(calibratedRed: 0.43, green: 0.32, blue: 0.09, alpha: 1).cgColor
+        thumb.shadowOpacity = 0.16
+        thumb.shadowRadius = 2
+        thumb.shadowOffset = CGSize(width: 0, height: 1)
+        layer?.insertSublayer(thumb, at: 0)
+        labels.layer?.zPosition = 1
+        focusRingType = .exterior
+    }
+    required init?(coder: NSCoder) { nil }
+
+    override var intrinsicContentSize: NSSize {
+        let widest = (0..<segmentCount).map { index in
+            ((label(forSegment: index) ?? "") as NSString).size(withAttributes: [.font: labelFont]).width
+        }.max() ?? 0
+        return NSSize(width: CGFloat(segmentCount) * max(102, widest + 58) + 8, height: 44)
+    }
+
+    private var labelFont: NSFont { .systemFont(ofSize: 12, weight: .semibold) }
+
+    func updateCounts(_ values: [Int]) {
+        counts = values
+        labels.needsDisplay = true
+    }
+
+    func refreshMetrics() {
+        for index in 0..<segmentCount {
+            setWidth(0, forSegment: index)
+            setToolTip("\(label(forSegment: index) ?? "") · \(counts.indices.contains(index) ? counts[index] : 0)", forSegment: index)
+        }
+        invalidateIntrinsicContentSize()
+        needsLayout = true
+        needsDisplay = true
+        labels.needsDisplay = true
+    }
+
+    private func segmentRect(_ index: Int) -> NSRect {
+        guard segmentCount > 0 else { return .zero }
+        let width = max(0, bounds.width - 8) / CGFloat(segmentCount)
+        return NSRect(x: 4 + CGFloat(index) * width, y: 4, width: width, height: max(0, bounds.height - 8))
+    }
+
+    override func layout() {
+        super.layout()
+        labels.frame = bounds
+        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
+        // 刷新列表或数量时不重置正在进行的动画；仅在几何尺寸改变时同步。
+        if !hasPlacedThumb || thumb.frame != target { positionThumb(animated: false) }
+    }
+
+    private func positionThumb(animated: Bool) {
+        guard selectedSegment >= 0, selectedSegment < segmentCount, bounds.width > 8, bounds.height > 8 else { return }
+        let target = segmentRect(selectedSegment).insetBy(dx: 1, dy: 0)
+        let previous = thumb.presentation()?.frame ?? thumb.frame
+        let shouldAnimate = animated && hasPlacedThumb && !reducesMotion()
+        thumb.removeAnimation(forKey: "filter-selection")
+        CATransaction.begin(); CATransaction.setDisableActions(true)
+        thumb.frame = target
+        thumb.shadowPath = CGPath(roundedRect: thumb.bounds, cornerWidth: 9, cornerHeight: 9, transform: nil)
+        CATransaction.commit()
+        if shouldAnimate {
+            let movement = CABasicAnimation(keyPath: "position")
+            movement.fromValue = NSValue(point: NSPoint(x: previous.midX, y: previous.midY))
+            movement.toValue = NSValue(point: NSPoint(x: target.midX, y: target.midY))
+            let resizing = CABasicAnimation(keyPath: "bounds")
+            resizing.fromValue = NSValue(rect: NSRect(origin: .zero, size: previous.size))
+            resizing.toValue = NSValue(rect: NSRect(origin: .zero, size: target.size))
+            let group = CAAnimationGroup()
+            group.animations = [movement, resizing]
+            group.duration = Self.transitionDuration
+            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
+            thumb.add(group, forKey: "filter-selection")
+        }
+        hasPlacedThumb = true
+        labels.needsDisplay = true
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
+        NSGradient(colors: [NSColor(calibratedWhite: 0.94, alpha: 1), NSColor(calibratedWhite: 0.965, alpha: 1)])?.draw(in: path, angle: 90)
+        NSColor(calibratedWhite: 0.86, alpha: 0.65).setStroke(); path.lineWidth = 1; path.stroke()
+    }
+
+    fileprivate func drawLabels() {
+        for index in 0..<segmentCount {
+            let rect = segmentRect(index)
+            let selected = selectedSegment == index
+            let title = label(forSegment: index) ?? ""
+            let color = selected ? HomeStyle.ink : hoveredSegment == index ? HomeStyle.ink : HomeStyle.secondary
+            let count = counts.indices.contains(index) ? String(counts[index]) : "0"
+            let countFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
+            let countWidth = max(21, ceil((count as NSString).size(withAttributes: [.font: countFont]).width) + 10)
+            var font = labelFont
+            var titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
+            while 13 + 6 + titleWidth + 7 + countWidth > rect.width - 10, font.pointSize > 10 {
+                font = .systemFont(ofSize: font.pointSize - 0.5, weight: .semibold)
+                titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
+            }
+            let contentWidth = 13 + 6 + titleWidth + 7 + countWidth
+            let start = rect.midX - contentWidth / 2
+            let symbols = ["square.grid.2x2.fill", "lock.fill", "checkmark.seal.fill"]
+            HomeStyle.symbol(symbols[min(index, 2)], in: NSRect(x: start, y: rect.midY - 6.5, width: 13, height: 13), color: color)
+            let titleSize = (title as NSString).size(withAttributes: [.font: font])
+            (title as NSString).draw(at: NSPoint(x: start + 19, y: rect.midY - titleSize.height / 2), withAttributes: [.font: font, .foregroundColor: color])
+            let chip = NSRect(x: start + 19 + titleWidth + 7, y: rect.midY - 9, width: countWidth, height: 18)
+            (selected ? HomeStyle.ink.withAlphaComponent(0.075) : HomeStyle.ink.withAlphaComponent(0.035)).setFill()
+            NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6).fill()
+            let size = (count as NSString).size(withAttributes: [.font: countFont])
+            (count as NSString).draw(at: NSPoint(x: chip.midX - size.width / 2, y: chip.midY - size.height / 2), withAttributes: [.font: countFont, .foregroundColor: color])
+        }
+    }
+
+    override func updateTrackingAreas() {
+        super.updateTrackingAreas()
+        if let tracking { removeTrackingArea(tracking) }
+        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
+        addTrackingArea(area); tracking = area
+    }
+
+    override func mouseMoved(with event: NSEvent) {
+        let point = convert(event.locationInWindow, from: nil)
+        hoveredSegment = (0..<segmentCount).first { segmentRect($0).contains(point) }
+        labels.needsDisplay = true
+    }
+    override func mouseExited(with event: NSEvent) { hoveredSegment = nil; labels.needsDisplay = true }
+    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
+
+    override func mouseDown(with event: NSEvent) {
+        let point = convert(event.locationInWindow, from: nil)
+        guard isEnabled, let index = (0..<segmentCount).first(where: { segmentRect($0).contains(point) }), index != selectedSegment else { return }
+        selectedSegment = index
+        sendAction(action, to: target)
+    }
+
+    @discardableResult
+    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
+        // 辅助功能可通过原生 Cell 改变选中值，再同步滑块，保持与鼠标/键盘相同的反馈。
+        if hasPlacedThumb, selectedSegment >= 0, thumb.frame != segmentRect(selectedSegment).insetBy(dx: 1, dy: 0) {
+            positionThumb(animated: true)
+        }
+        return super.sendAction(action, to: target)
+    }
+
+    override func keyDown(with event: NSEvent) {
+        guard isEnabled else { return }
+        let offset: Int
+        switch event.keyCode {
+        case 123: offset = -1
+        case 124: offset = 1
+        default: super.keyDown(with: event); return
+        }
+        let next = min(segmentCount - 1, max(0, selectedSegment + offset))
+        guard next != selectedSegment else { return }
+        selectedSegment = next
+        sendAction(action, to: target)
+    }
+}
+
+/// 图文位于滑块上方，且不截获点击；分段控件继续提供原生辅助功能语义。
+private final class FilterLabelsView: NSView {
+    weak var owner: AchievementFilterControl?
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) { owner?.drawLabels() }
+    override func hitTest(_ point: NSPoint) -> NSView? { nil }
+    override func isAccessibilityElement() -> Bool { false }
+}
```

### `Tests/AchievementFilterControlTests.swift`

```diff
--- /dev/null
+++ b/Tests/AchievementFilterControlTests.swift
@@ -0,0 +1,160 @@
+import Cocoa
+import QuartzCore
+import ImageIO
+import XCTest
+@testable import EliminateTeris1
+
+final class AchievementFilterControlTests: AchievementTestCase {
+    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
+
+    private func filter(in controller: AchievementsWindowController) throws -> AchievementFilterControl {
+        let content = try XCTUnwrap(controller.window?.contentView)
+        content.layoutSubtreeIfNeeded()
+        return try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
+    }
+
+    private func thumb(in filter: AchievementFilterControl) throws -> CALayer {
+        try XCTUnwrap(filter.layer?.sublayers?.first { $0.name == "achievement-filter-selection" })
+    }
+
+    private func click(_ index: Int, on filter: AchievementFilterControl) throws {
+        let point = filter.convert(NSPoint(x: filter.bounds.width * (CGFloat(index) + 0.5) / 3, y: filter.bounds.midY), to: nil)
+        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
+                                                   windowNumber: filter.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
+        filter.mouseDown(with: event)
+    }
+
+    func testAnimatedSelectionSurvivesRefreshAndRapidChanges() throws {
+        _ = NSApplication.shared
+        swap(score: 100)
+        let controller = AchievementsWindowController(manager: manager)
+        defer { controller.close() }
+        controller.refresh()
+        controller.window?.orderFront(nil)
+        let filter = try filter(in: controller)
+        filter.reducesMotion = { false }
+        let layer = try thumb(in: filter)
+        let initial = layer.frame
+        try click(2, on: filter)
+        XCTAssertEqual(filter.selectedSegment, 2)
+        XCTAssertGreaterThan(layer.frame.minX, filter.bounds.midX)
+        let animation = try XCTUnwrap(layer.animation(forKey: "filter-selection") as? CAAnimationGroup)
+        XCTAssertEqual(animation.duration, 0.24, accuracy: 0.001)
+        XCTAssertEqual(animation.animations?.count, 2)
+        controller.window?.contentView?.layoutSubtreeIfNeeded()
+        XCTAssertNotNil(layer.animation(forKey: "filter-selection"), "刷新真实筛选结果不应取消滑块动画")
+        CATransaction.flush()
+        RunLoop.main.run(until: Date().addingTimeInterval(0.07))
+        let interrupted = try XCTUnwrap(layer.presentation()).frame
+        try click(1, on: filter)
+        let next = try XCTUnwrap(layer.animation(forKey: "filter-selection") as? CAAnimationGroup)
+        let start = try XCTUnwrap((next.animations?.first as? CABasicAnimation)?.fromValue as? NSValue).pointValue
+        XCTAssertEqual(start.x, interrupted.midX, accuracy: 5, "连续切换应从当前视觉位置继续移动")
+        try click(0, on: filter)
+        XCTAssertEqual(filter.selectedSegment, 0)
+        XCTAssertEqual(layer.frame, initial)
+        let content = try XCTUnwrap(controller.window?.contentView)
+        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 32)
+    }
+
+    func testReducedMotionKeyboardAndNativeCellSelection() throws {
+        _ = NSApplication.shared
+        let controller = AchievementsWindowController(manager: manager)
+        defer { controller.close() }
+        controller.refresh()
+        let filter = try filter(in: controller)
+        filter.reducesMotion = { true }
+        let layer = try thumb(in: filter)
+        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
+                                                 windowNumber: filter.window?.windowNumber ?? 0, context: nil,
+                                                 characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124))
+        filter.keyDown(with: event)
+        XCTAssertEqual(filter.selectedSegment, 1)
+        XCTAssertNil(layer.animation(forKey: "filter-selection"))
+        filter.setSelected(true, forSegment: 2)
+        filter.sendAction(filter.action, to: filter.target)
+        XCTAssertEqual(filter.selectedSegment, 2)
+        XCTAssertGreaterThan(layer.frame.minX, filter.bounds.midX)
+        XCTAssertNil(layer.animation(forKey: "filter-selection"))
+        let content = try XCTUnwrap(controller.window?.contentView)
+        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 0)
+    }
+
+    func testCountsAndSliderFitFiveLanguagesAndBothPanelWidths() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        swap(score: 100)
+        let controller = AchievementsWindowController(manager: manager)
+        defer { controller.close() }
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            controller.refresh()
+            for width: CGFloat in [480, 600] {
+                controller.window?.setContentSize(NSSize(width: width, height: 580))
+                let filter = try filter(in: controller)
+                filter.reducesMotion = { true }
+                XCTAssertEqual(filter.frame.height, 44, accuracy: 0.5)
+                XCTAssertTrue(filter.toolTip(forSegment: 0)?.contains("32") == true)
+                XCTAssertTrue(filter.toolTip(forSegment: 2)?.contains(String(manager.unlockedIDs().count)) == true)
+                let layer = try thumb(in: filter)
+                for index in 0..<3 {
+                    try click(index, on: filter)
+                    XCTAssertTrue(filter.bounds.contains(layer.frame), language.rawValue)
+                    XCTAssertGreaterThan(layer.frame.height, 30)
+                }
+            }
+        }
+    }
+
+    func testExportRealPanelAndAnimatedFilterPreview() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let unlocked = [1, 3, 4, 7, 9]
+        let dates = Dictionary(uniqueKeysWithValues: unlocked.map { (String($0), Date().timeIntervalSince1970) })
+        defaults.set(["version": 1, "unlocked": unlocked, "timestamps": dates,
+                      "metrics": ["bestScore": 150, "totalCleared": 45, "rhythm": 2, "cascades": 2, "successfulSwaps": 5]],
+                     forKey: AchievementsManager.storageKey)
+        let fixture = AchievementsManager(defaults: defaults)
+        let controller = AchievementsWindowController(manager: fixture)
+        defer { controller.close() }
+        controller.refresh()
+        let window = try XCTUnwrap(controller.window)
+        window.orderFront(nil)
+        let content = try XCTUnwrap(window.contentView)
+        let filter = try filter(in: controller)
+        filter.reducesMotion = { false }
+        content.layoutSubtreeIfNeeded()
+        let panel = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
+        content.cacheDisplay(in: content.bounds, to: panel)
+        let directory = FileManager.default.temporaryDirectory
+        try XCTUnwrap(panel.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent("eliminate-achievement-panel-refined.png"))
+
+        // 导出实际 Core Animation 展示层，记录滑块位移，而非手工拼造设计稿。
+        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(directory.appendingPathComponent("eliminate-achievement-filter.gif") as CFURL,
+                                                                       "com.compuserve.gif" as CFString, 40, nil))
+        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        for frame in 0..<40 {
+            if frame == 8 { try click(1, on: filter) }
+            if frame == 20 { try click(2, on: filter) }
+            if frame == 32 { try click(0, on: filter) }
+            CATransaction.flush()
+            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
+            let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(filter.bounds.width * 2),
+                                                       pixelsHigh: Int(filter.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
+                                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
+            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)).cgContext
+            context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
+            context.scaleBy(x: 2, y: -2)
+            (filter.layer?.presentation() ?? filter.layer)?.render(in: context)
+            let image = try XCTUnwrap(bitmap.cgImage)
+            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
+            if frame == 0 || frame == 10 || frame == 22 {
+                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent("eliminate-filter-frame-\(frame).png"))
+            }
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(destination))
+    }
+}
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -1,6 +1,15 @@
-# 成就徽章测试图
+# 成就界面测试图
 
 这些文件仅用于开发测试与评审，正式应用中没有图标预览按钮或图标预览页面。
+
+## 筛选切换动画
+
+![筛选切换动画](achievement-filter.gif)
+
+- 共用暖白轨道，黄色选中滑块在全部、未解锁、已解锁之间移动，显示对应数量。
+- 过渡时长 0.24 秒，快速切换从当前视觉位置接续；系统减少动态效果开启时即时切换。
+- 动画由真实 Core Animation（核心动画）展示层导出，测试入口不进入正式应用。
+- [查看成就页完整效果](achievement-panel.png)。页面中的进度和时间来自隔离测试存档。
 
 ## 标签实际效果
 
@@ -26,3 +35,11 @@
 ```
 
 将系统临时目录中的 `eliminate-all-achievement-icons.png` 和 `eliminate-game-badge-labels.png` 分别复制为本目录中的 `achievement-icons.png` 和 `achievement-labels.png`。
+
+更新筛选条动画与完整成就页截图：
+
+```sh
+DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementFilterControlTests
+```
+
+将临时目录中的 `eliminate-achievement-filter.gif` 和 `eliminate-achievement-panel-refined.png` 分别复制到本目录的 `achievement-filter.gif` 和 `achievement-panel.png`。
```

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261031230317-animated-achievement-filter.md` - 会话-97 起将成就筛选改为暖白金色一体式滑轨，加入数量提示、0.24 秒滑动、快速打断接续与减少动态效果支持；含全部逐行 diff、真实动画/截图和 55 项完整回归。
 `workflow/20261031222305-remove-lifetime-milestone-stars.md` - 会话-95 起移除总累计百/千/万图案中的五角星，仅保留三档方块并重新居中；含完整增量 diff、更新测试图与 5 项图标回归。
 `workflow/20261031221440-normalize-lifetime-milestone-icons.md` - 会话-92 起调整百格/千格/万格累计成就图案的单格大小与整体居中，三档视觉尺寸接近；含完整增量 diff、像素边界测量、测试图与 5 项图标回归。
 `workflow/20261031215904-simplify-cascade-and-footprint-icons.md` - 会话-90 起去掉连锁/余波图标下方箭头并按实际行数垂直居中；步步有解只保留居中脚印，含全部增量 diff、测试图与 5 项图标回归。
@@ -76,6 +77,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整成就页筛选滑块的美术、动画、数量、原生选择兼容或五语言布局时，读取 `20261031230317-animated-achievement-filter.md`。
 - 需要确认总累计百/千/万图案为何没有五角星、查看纯方块效果或居中调整时，读取 `20261031222305-remove-lifetime-milestone-stars.md`。
 - 需要调整百格起步、千格熟手、万格旅人的整体尺寸差距和垂直居中时，读取 `20261031221440-normalize-lifetime-milestone-icons.md`。
 - 需要调整连锁反应/余波未平的无箭头方块居中，或步步有解的纯脚印图案时，读取 `20261031215904-simplify-cascade-and-footprint-icons.md`。
@@ -152,6 +154,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就筛选由 `AchievementFilterControl` 统一绘制一体式滑轨与数量，沿用 `NSSegmentedControl` 的真实选择值；黄色滑块由 Core Animation 移动，刷新列表不重置动画，减少动态效果时即时定位。测试动画及页面图位于 `docs/previews/achievement-filter.gif` 和 `achievement-panel.png`，正式应用无测试预览入口。
 - `GameIconRenderer` 保留模式图标的等比绘制与奖杯兼容；成就使用 `AchievementIconCatalog` 和 `AchievementBadgeArtwork` 的透明背景彩色游戏图案，不绘制徽章外框或底板。正式应用没有测试预览入口；`Tests/AchievementIconContactSheet.swift` 仅在 XCTest 导出全部图标，静态测试图位于 `docs/previews/`。
 - 首页主插画使用从原始设计稿直接提取的 `home-design-*.png`，包含四种方块、投影、短线与交换箭头；按原稿坐标整体等比缩放，方块独立浮动。`GameResourceLocator` 共用于语言和图片；小尺寸统计图标仍使用 `HomeStyle.piece`。
 - `experiment/ui-refactor` 探索分支使用暖白首页：左侧标题/方块插画/开始按钮，右侧模式卡片与本局实时统计，底部五枚成就及完成度；设置、玩法说明与挑战记录从顶部导航打开。
```

### `docs/previews/achievement-filter.gif`

```diff
diff --git a/docs/previews/achievement-filter.gif b/docs/previews/achievement-filter.gif
new file mode 100644
Binary files /dev/null and b/docs/previews/achievement-filter.gif differ
```

### `docs/previews/achievement-panel.png`

```diff
diff --git a/docs/previews/achievement-panel.png b/docs/previews/achievement-panel.png
new file mode 100644
Binary files /dev/null and b/docs/previews/achievement-panel.png differ
```
