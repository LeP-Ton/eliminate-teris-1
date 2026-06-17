# 回退到另一模型实现的自定义弹窗版本

## 背景与目标
- 用户明确要求：不要继续当前这轮样式和交互实验，**直接回到另一个模型实现的自定义弹窗版本**。
- 这意味着本轮目标不是优化，而是准确回退到那个基线实现。

## 约束与原则
- 不继续保留当前矩形浮层样式实验。
- 不继续保留赛博朋克切角浮层实验。
- 直接恢复为另一模型最初写入的 `ArcadeCustomPopup.swift` 版本。

## 阶段与 TODO
- [x] 删除当前实验版 `Sources/ArcadeCustomPopup.swift`
- [x] 恢复为另一模型实现的原始自定义弹窗版本
- [x] 更新索引与项目认知
- [x] 重新编译验证

## 关键风险
- 回退后的版本会带回那一版的原始样式与交互特征，不包含后续所有样式增强或稳定性实验。
- 这是用户主动选择的回退方向，本轮不对其行为做额外“优化”。

## 当前进展
- `Sources/ArcadeCustomPopup.swift` 已恢复为最初的简单实现：
  - `ArcadePopupContentViewController`
  - `ArcadeCustomPopupButton`
  - 基于 `NSPopover` 的原始展开逻辑
- 当前版本不再包含我后续加入的赛博朋克矩形浮层样式和复杂状态逻辑。

## 代码变更
- `Sources/ArcadeCustomPopup.swift`
```diff
--- a/Sources/ArcadeCustomPopup.swift
+++ b/Sources/ArcadeCustomPopup.swift
@@
-private enum ArcadePopupPalette { ... }
-private final class ArcadePopupPanelBackgroundView: NSView { ... }
-private final class ArcadePopupOptionButton: NSButton { ... }
+private final class ArcadePopupContentViewController: NSViewController { ... }
+
+final class ArcadeCustomPopupButton: NSPopUpButton {
+    private let popover = NSPopover()
+    ...
+}
```

## 测试用例
### TC-001 自定义弹窗恢复为另一模型版本
- 类型：回退验证
- 优先级：高
- 关联模块：`ArcadeCustomPopupButton`
- 前置条件：启动游戏主窗口
- 操作步骤：
1. 点击语言选择框
2. 点击模式选择框
3. 点击规则/目标选择框
- 预期结果：
- 下拉行为回到另一模型那版实现
- 不再包含这轮实验版样式
- 是否通过：待验证
