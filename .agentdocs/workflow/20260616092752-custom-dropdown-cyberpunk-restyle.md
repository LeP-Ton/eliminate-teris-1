# 自定义下拉恢复赛博朋克样式：重做选择框与浮层视觉

## 背景与目标
- 用户说明：当前自定义下拉的交互已经由另一个模型实现，但“选择框和下拉浮层样式不满意”，希望重新改回赛博朋克风格。
- 这说明本轮重点不是重新发明交互，而是**保留现有可用弹出逻辑，只重做视觉层**。

## 约束与原则
- 不推翻现有 `ArcadeCustomPopupButton` 的基本弹出方式。
- 优先保留“能弹出”的交互结构，只处理按钮外观、浮层背景、选项 hover/选中态。
- 视觉需与当前窗口主 UI 的霓虹赛博朋克风一致。

## 阶段与 TODO
- [x] 识别当前真正生效的下拉实现文件为 `Sources/ArcadeCustomPopup.swift`。
- [x] 重做选择框按钮的赛博朋克外观。
- [x] 重做 popover 浮层背景为科技切角 + 霓虹描边。
- [x] 重做选项项的 hover / 选中态样式。
- [x] 更新索引与项目认知。
- [x] 重新编译验证。

## 关键风险
- 当前 `ArcadeCustomPopupButton` 仍基于 `NSPopUpButton + NSPopover` 混合方式工作，后续若还要继续深度自定义交互，可能仍需要进一步收敛组件职责。
- 但本轮先确保“样式回到赛博朋克，且不破坏已可用的展开行为”。

## 当前进展
- 已重写 `Sources/ArcadeCustomPopup.swift`：
  - 选择框按钮恢复霓虹深色底、描边、辉光、亮色文字和自定义箭头状态
  - 下拉浮层恢复科技切角背景与双层霓虹描边
  - 选项恢复 hover 高亮、当前选中条、亮黄选中态
- 保持现有 `NSPopover` 弹出方式不变。

## 代码变更
- `Sources/ArcadeCustomPopup.swift`
```diff
--- a/Sources/ArcadeCustomPopup.swift
+++ b/Sources/ArcadeCustomPopup.swift
@@
-final class ArcadeCustomPopupButton: NSPopUpButton {
-    private let popover = NSPopover()
+final class ArcadeCustomPopupButton: NSPopUpButton {
+    private let popover = NSPopover()
+    private let titleLabel = NSTextField(labelWithString: "")
+    private let chevronImageView = NSImageView()
+    private var hoverTrackingArea: NSTrackingArea?
+    private var isHovering = false
@@
-        let stack = NSStackView()
-        stack.orientation = .vertical
+        let stack = NSStackView()
+        stack.orientation = .vertical
@@
-            let btn = NSButton(title: title, target: self, action: #selector(itemTapped(_:)))
+            let button = ArcadePopupOptionButton(title: title)
+            button.isCurrentSelection = index == selectedIndex
@@
-        popover.animates = true
+        popover.animates = false
```

## 测试用例
### TC-001 选择框恢复赛博朋克外观
- 类型：视觉测试
- 优先级：高
- 关联模块：`ArcadeCustomPopupButton`
- 前置条件：启动游戏主窗口
- 操作步骤：
1. 观察语言 / 模式 / 规则（目标）三个选择框
- 预期结果：
- 选择框为深色底、霓虹描边、亮色标题文字、科技感箭头
- 是否通过：待验证

### TC-002 下拉浮层恢复赛博朋克外观
- 类型：视觉测试
- 优先级：高
- 关联模块：`ArcadePopupContentViewController`
- 前置条件：任意选择框可展开
- 操作步骤：
1. 点击任意一个选择框
2. 观察浮层背景和选项态
- 预期结果：
- 浮层为切角面板、霓虹描边
- hover 有高亮
- 当前选中项有明显亮黄/强调态
- 是否通过：待验证
