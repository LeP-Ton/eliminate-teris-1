# 修复自定义下拉样式回归后的弹出失效：恢复稳定的 popover 展开时序

## 背景与目标
- 上一轮已经把当前真正生效的下拉组件 `Sources/ArcadeCustomPopup.swift` 重做成赛博朋克风格。
- 但在重做视觉时，把旧的 `mouseDown -> transient NSPopover.show(...)` 时序又带了回来。
- 用户反馈为：浮层又弹不出来。

## 约束与原则
- 不回退赛博朋克样式改造。
- 不推翻当前 `ArcadeCustomPopupButton` 交互结构。
- 仅修正 popover 的展开时序，恢复稳定可弹出行为。

## 阶段与 TODO
- [x] 复查 `ArcadeCustomPopupButton` 当前点击链路。
- [x] 确认问题为 `mouseDown + transient popover` 同帧冲突。
- [x] 改为 `mouseDown` 只进入按压态，`mouseUp` 后异步切换 popover。
- [x] 保持赛博朋克样式不变。
- [x] 重新编译验证。

## 关键风险
- 当前 `ArcadeCustomPopupButton` 仍是“`NSPopUpButton` 外壳 + `NSPopover` 自定义浮层”的混合方案，后续若继续深度调整交互，仍要留意 AppKit 事件时序。
- 但本轮已先把最直接的回归问题收掉：浮层不再在同一点击事件中被瞬时关闭。

## 当前进展
- `ArcadeCustomPopupButton` 已补齐：
  - `acceptsFirstMouse`
  - `isPressing / isTrackingPrimaryClick`
  - `mouseDragged` 按压态更新
  - `mouseUp + DispatchQueue.main.async` 延后切换 popover
- 当前样式与交互都已保留。

## 代码变更
- `Sources/ArcadeCustomPopup.swift`
```diff
--- a/Sources/ArcadeCustomPopup.swift
+++ b/Sources/ArcadeCustomPopup.swift
@@
-    override func mouseDown(with event: NSEvent) {
-        if popover.isShown {
-            popover.performClose(nil)
-            return
-        }
-        ...
-        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
-    }
+    override func mouseDown(with event: NSEvent) {
+        guard isEnabled else { return }
+        isTrackingPrimaryClick = true
+        isPressing = true
+        updateAppearance()
+    }
+
+    override func mouseUp(with event: NSEvent) {
+        ...
+        schedulePopoverToggle()
+    }
+
+    private func schedulePopoverToggle() {
+        DispatchQueue.main.async { [weak self] in
+            ...
+        }
+    }
```

## 测试用例
### TC-001 自定义下拉可正常弹出
- 类型：交互测试
- 优先级：高
- 关联模块：`ArcadeCustomPopupButton`
- 前置条件：启动游戏主窗口
- 操作步骤：
1. 点击语言选择框
2. 点击模式选择框
3. 点击规则/目标选择框
- 预期结果：
- 浮层可稳定弹出
- 不再出现“样式回来了，但浮层不见了”
- 是否通过：待验证

### TC-002 赛博朋克样式保持不丢失
- 类型：视觉回归测试
- 优先级：中
- 关联模块：`ArcadeCustomPopupButton`、`ArcadePopupContentViewController`
- 前置条件：任意下拉已可展开
- 操作步骤：
1. 打开任意下拉
2. 观察按钮与浮层样式
- 预期结果：
- 按钮仍保持霓虹描边与高亮风格
- 浮层仍保持切角面板和 hover/选中态
- 是否通过：待验证
