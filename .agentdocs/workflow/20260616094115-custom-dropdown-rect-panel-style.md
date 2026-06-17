# 自定义下拉收敛为简单矩形浮层：只修样式，不再折腾复杂弹层结构

## 背景与目标
- 用户明确反馈：前一轮改动导致“点击选择框直接闪退”，并指出这轮需求其实很简单——**只需要修样式**。
- 用户进一步给出收敛要求：
  - 弹出层用矩形
  - 颜色配合选择框
  - 不需要复杂切角、复杂时序、复杂浮层结构

## 约束与原则
- 不继续尝试复杂赛博朋克切角浮层。
- 不继续折腾复杂的 `mouseUp + async` 时序链路。
- 保留自定义选择框，但把浮层收敛为更简单、更稳定的矩形面板。

## 阶段与 TODO
- [x] 删除复杂切角版 `ArcadeCustomPopup.swift`。
- [x] 重建为“选择框 + 简单矩形浮层 + 简单 hover/选中态”。
- [x] 保持颜色与选择框一致。
- [x] 更新索引与项目认知。
- [x] 重新编译验证。

## 关键风险
- 当前仍是 `NSPopUpButton + NSPopover` 的混合组件，但视觉复杂度已明显下降，后续维护成本也会更低。
- 这轮目标优先级明确是“先稳定、再好看”，因此不再强行保留复杂几何装饰。

## 当前进展
- `Sources/ArcadeCustomPopup.swift` 已重写为：
  - 选择框：圆角矩形、蓝青描边、亮黄激活态
  - 浮层：简单圆角矩形面板
  - 选项：矩形 hover 背景与当前选中高亮
- 已移除切角路径、自定义复杂几何背景等高风险样式实现。

## 代码变更
- `Sources/ArcadeCustomPopup.swift`
```diff
--- a/Sources/ArcadeCustomPopup.swift
+++ b/Sources/ArcadeCustomPopup.swift
@@
-private func makeArcadePopupPanelPath(...) -> NSBezierPath { ... }
-private final class ArcadePopupPanelBackgroundView: NSView { ...切角绘制... }
+private final class ArcadePopupPanelBackgroundView: NSView {
+    override func draw(_ dirtyRect: NSRect) {
+        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
+        ...
+    }
+}
@@
-        popover.behavior = .transient
+        popover.behavior = .semitransient
```

## 测试用例
### TC-001 选择框样式正常
- 类型：视觉测试
- 优先级：高
- 关联模块：`ArcadeCustomPopupButton`
- 前置条件：启动游戏主窗口
- 操作步骤：
1. 观察语言 / 模式 / 规则（目标）选择框
- 预期结果：
- 选择框为统一矩形风格
- 颜色与整体赛博朋克选择框主题一致
- 是否通过：待验证

### TC-002 浮层可弹出且为简单矩形
- 类型：交互/视觉测试
- 优先级：高
- 关联模块：`ArcadePopupContentViewController`
- 前置条件：任意下拉可点击
- 操作步骤：
1. 点击任意一个选择框
2. 观察浮层样式
- 预期结果：
- 浮层可以弹出
- 浮层为简单矩形/圆角矩形
- 颜色与选择框风格一致
- 是否通过：待验证
