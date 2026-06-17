# 游戏窗口 UI 赛博朋克化改造

## 背景与目标
- 用户希望参考同级项目 `cyberpunk-ui`，把当前游戏窗口的桌面 UI 从原本的像素街机风格进一步优化成更明显的赛博朋克风格。
- 本次目标不是重做交互结构，而是在保留现有布局与玩法模块的前提下，把窗口主舞台、卡片、标题、下拉框、按钮、音量条、分割线与横幅整体升级为统一的霓虹科技视觉。

## 约束与原则
- 不改动 Touch Bar 棋盘逻辑，只处理桌面窗口 UI 的视觉层。
- 保持现有模块结构不变：游戏设置、时间与得分、挑战记录、玩法说明仍维持当前布局。
- 优先复用当前自定义原生控件，通过 `NSView.draw(_:)` 与颜色系统升级，而不是额外引入复杂依赖。

## 阶段与 TODO
- [x] 分析当前 `GameViewController` 的桌面窗口 UI 结构。
- [x] 对照 `cyberpunk-ui` 提炼可迁移的视觉语言：深底、霓虹色、切角轮廓、扫描线、辉光。
- [x] 升级主舞台背景、卡片边框、横幅、分割线、按钮、下拉框、音量条与标题文字层级。
- [x] 执行编译自检，并同步索引与项目认知。

## 关键风险
- 如果只换颜色不改控件几何，视觉会停留在“换皮”层面，因此本次同时改了卡片路径、控件阴影与背景扫描效果。
- 如果赛博朋克颜色过亮，容易影响可读性，所以正文仍保留较克制的浅色文本，仅把标题、边框和交互态做霓虹强化。

## 当前进展
- `ArcadeStageView` 已改为深色渐变舞台，并加入霓虹辉光、扫描线、像素矩阵与电路引导线。
- `PixelFrameCardView` 已从圆角像素卡片升级为科技切角卡片，增加霓虹描边、内层弱描边与角落信号标记。
- `ArcadePopupButton`、`ArcadeVolumeControlView`、`ArcadeActionButton`、`PixelDividerView`、`PixelBannerView` 均已切换为更强的赛博朋克色板与发光反馈。
- 标题、模块标题、状态徽章、挑战记录序号标签也同步做了霓虹层级强化，避免出现“背景很赛博、文字很旧”的割裂感。

## 代码变更
- `Sources/GameViewController.swift`
```diff
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@
+private enum CyberpunkPalette {
+    static let abyss = NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.06, alpha: 1)
+    static let midnight = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.14, alpha: 1)
+    static let ultraviolet = NSColor(calibratedRed: 0.12, green: 0.05, blue: 0.16, alpha: 1)
+    static let panelBase = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 0.95)
+    static let panelOverlay = NSColor(calibratedRed: 0.1, green: 0.08, blue: 0.14, alpha: 0.86)
+    static let neonYellow = NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.01, alpha: 1)
+    static let neonCyan = NSColor(calibratedRed: 0.18, green: 0.9, blue: 1.0, alpha: 1)
+    static let neonMagenta = NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.69, alpha: 1)
+    static let neonGreen = NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.29, alpha: 1)
+    static let neonRed = NSColor(calibratedRed: 1.0, green: 0.19, blue: 0.34, alpha: 1)
+    static let textPrimary = NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.42, alpha: 0.98)
+    static let textSecondary = NSColor(calibratedRed: 0.58, green: 0.95, blue: 1.0, alpha: 0.82)
+    static let textMuted = NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.96, alpha: 0.58)
+}
@@
-    private let settingsThemeColor = NSColor(calibratedRed: 0.7, green: 0.86, blue: 1.0, alpha: 0.96)
-    private let statusThemeColor = NSColor(calibratedRed: 0.74, green: 0.98, blue: 0.78, alpha: 0.96)
-    private let recordsThemeColor = NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.58, alpha: 0.96)
-    private let rulesThemeColor = NSColor(calibratedRed: 1.0, green: 0.53, blue: 0.5, alpha: 0.96)
-    private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
+    private let settingsThemeColor = CyberpunkPalette.neonYellow
+    private let statusThemeColor = CyberpunkPalette.neonCyan
+    private let recordsThemeColor = CyberpunkPalette.neonMagenta
+    private let rulesThemeColor = CyberpunkPalette.neonRed
+    private let rulesBodyThemeColor = CyberpunkPalette.textPrimary.withAlphaComponent(0.92)
@@
-        let baseGradient = NSGradient(colors: [
-            NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1),
-            NSColor(calibratedRed: 0.08, green: 0.1, blue: 0.16, alpha: 1),
-            NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1)
-        ])
+        let baseGradient = NSGradient(colors: [
+            CyberpunkPalette.abyss,
+            CyberpunkPalette.midnight,
+            CyberpunkPalette.ultraviolet
+        ])
@@
-        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
-        let rounded = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
+        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
+        let outerPath = makeCyberpunkPanelPath(in: cardRect, cut: 18, lowerInset: 74, lowerStep: 12)
@@
-        if !isEnabled {
-            background = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 0.8)
-            border = NSColor(calibratedRed: 0.32, green: 0.32, blue: 0.32, alpha: 0.8)
+        if !isEnabled {
+            background = CyberpunkPalette.panelBase.withAlphaComponent(0.72)
+            border = CyberpunkPalette.neonCyan.withAlphaComponent(0.18)
```

## 测试用例
### TC-001 主舞台赛博朋克背景可见
- 类型：界面检查
- 优先级：中
- 关联模块：`ArcadeStageView`
- 前置条件：启动游戏窗口
- 操作步骤：
1. 观察窗口背景
2. 检查是否存在深色渐变、霓虹辉光、扫描线与像素点阵
- 预期结果：
- 窗口背景明显呈现赛博朋克风格，而不是原先的普通深色像素背景
- 是否通过：待运行验证

### TC-002 卡片与控件风格统一
- 类型：界面检查
- 优先级：高
- 关联模块：`PixelFrameCardView`、`ArcadePopupButton`、`ArcadeActionButton`、`ArcadeVolumeControlView`
- 前置条件：启动游戏窗口
- 操作步骤：
1. 观察设置、状态、记录、玩法说明卡片边框
2. 悬浮或按下下拉框与按钮
3. 观察音量条外框与文字
- 预期结果：
- 卡片为科技切角描边
- 按钮与下拉框有霓虹边框和发光反馈
- 颜色风格统一，不再是原先的蓝绿橙分散像素面板感
- 是否通过：待运行验证
