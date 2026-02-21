# Touch Bar 消除动画可见性增强

## 背景与目标
- 用户反馈：当前消除动画不够明显。
- 目标：在不破坏已有交换/补位动画的前提下，让消除反馈更容易感知。

## 方案
- 新增过渡类型 `TransitionKind`，区分 move / remove / insert。
- 对消除单独使用 `easeInCubic`，并叠加光晕 + 外环特效。
- 放大消除缩放区间（`1.22 -> 0.12`），并将整体过渡时长从 `0.22s` 调整为 `0.28s`。
- 保持移动与补位动画独立 easing，减少相互覆盖导致的“看不出来”。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 681eef2..a8ddf3e 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -286,9 +286,16 @@ final class GameTouchBarView: NSView {
     private struct TouchState {
         let startIndex: Int
         var currentIndex: Int
     }
+
+    private enum TransitionKind {
+        case move
+        case remove
+        case insert
+    }
 
     private struct PieceTransition {
         let id: UUID
         let kind: PieceKind
+        let transitionKind: TransitionKind
         let fromIndex: Int
         let toIndex: Int
         let fromAlpha: CGFloat
@@ -304,7 +311,7 @@ final class GameTouchBarView: NSView {
     private let controller: GameBoardController
     private let columnRange: Range<Int>
     private let columnCount: Int
     private let leadingCompensationX: CGFloat
-    private let transitionDuration: TimeInterval = 0.22
+    private let transitionDuration: TimeInterval = 0.28
     private let animationFrameInterval: TimeInterval = 1.0 / 60.0
@@ -389,22 +396,13 @@ final class GameTouchBarView: NSView {
-        let easedProgress = easeOutCubic(transitionProgress)
-        for transition in pieceTransitions where shouldRenderTransition(transition) {
-            let fromPosition = CGFloat(transition.fromIndex)
-            let toPosition = CGFloat(transition.toIndex)
-            let interpolatedPosition = fromPosition + (toPosition - fromPosition) * easedProgress
-            let rect = cellRect(forBoardPosition: interpolatedPosition)
-            let alpha = transition.fromAlpha + (transition.toAlpha - transition.fromAlpha) * easedProgress
-            let scale = transition.fromScale + (transition.toScale - transition.fromScale) * easedProgress
-            let highlightIndex = transition.toAlpha >= transition.fromAlpha ? transition.toIndex : transition.fromIndex
-            let isHighlighted = isBoardIndex(highlightIndex) && (controller.isLocked(highlightIndex) || controller.isSelected(highlightIndex))
-            drawPiece(
-                transition.kind,
-                in: rect,
-                highlighted: isHighlighted,
-                alpha: alpha,
-                scale: scale
-            )
+        let visibleTransitions = pieceTransitions.filter { shouldRenderTransition($0) }
+        // 先绘制移动/补位，再叠加消除效果，避免消除反馈被后续方块遮挡。
+        for transition in visibleTransitions where transition.transitionKind != .remove {
+            drawTransitionPiece(transition)
+        }
+        for transition in visibleTransitions where transition.transitionKind == .remove {
+            drawTransitionPiece(transition)
         }
     }
@@ -522,6 +520,7 @@ final class GameTouchBarView: NSView {
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
+                    transitionKind: .move,
                     fromIndex: oldIndex,
                     toIndex: newIndex,
                     fromAlpha: 1,
@@ -537,11 +536,12 @@ final class GameTouchBarView: NSView {
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
+                    transitionKind: .remove,
                     fromIndex: oldIndex,
                     toIndex: oldIndex,
                     fromAlpha: 1,
                     toAlpha: 0,
-                    fromScale: 1,
-                    toScale: 0.72
+                    fromScale: 1.22,
+                    toScale: 0.12
                 )
             )
         }
@@ -558,10 +558,11 @@ final class GameTouchBarView: NSView {
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
+                    transitionKind: .insert,
                     fromIndex: newIndex - insertedCount,
                     toIndex: newIndex,
-                    fromAlpha: 0,
+                    fromAlpha: 0.1,
                     toAlpha: 1,
-                    fromScale: 0.82,
+                    fromScale: 0.72,
                     toScale: 1
                 )
             )
@@ -603,6 +604,40 @@ final class GameTouchBarView: NSView {
         transitionTimer = nil
         pieceTransitions = []
     }
+
+    private func drawTransitionPiece(_ transition: PieceTransition) {
+        let progress: CGFloat
+        switch transition.transitionKind {
+        case .move:
+            progress = easeInOutCubic(transitionProgress)
+        case .insert:
+            progress = easeOutCubic(transitionProgress)
+        case .remove:
+            progress = easeInCubic(transitionProgress)
+        }
+
+        let fromPosition = CGFloat(transition.fromIndex)
+        let toPosition = CGFloat(transition.toIndex)
+        let interpolatedPosition = fromPosition + (toPosition - fromPosition) * progress
+        let rect = cellRect(forBoardPosition: interpolatedPosition)
+        let alpha = transition.fromAlpha + (transition.toAlpha - transition.fromAlpha) * progress
+        let scale = transition.fromScale + (transition.toScale - transition.fromScale) * progress
+        let highlightIndex = transition.toAlpha >= transition.fromAlpha ? transition.toIndex : transition.fromIndex
+        let isHighlighted = isBoardIndex(highlightIndex) && (controller.isLocked(highlightIndex) || controller.isSelected(highlightIndex))
+
+        if transition.transitionKind == .remove {
+            drawEliminationBurst(in: rect, progress: progress, color: transition.kind.color)
+        }
+
+        drawPiece(
+            transition.kind,
+            in: rect,
+            highlighted: isHighlighted,
+            alpha: alpha,
+            scale: scale
+        )
+    }
@@ -679,8 +714,24 @@ final class GameTouchBarView: NSView {
     private func shouldRenderTransition(_ transition: PieceTransition) -> Bool {
         return columnRange.contains(transition.fromIndex) || columnRange.contains(transition.toIndex)
     }
+
+    private func drawEliminationBurst(in rect: CGRect, progress: CGFloat, color: NSColor) {
+        let clampedProgress = min(1, max(0, progress))
+        let fade = max(0, 1 - clampedProgress)
+        guard fade > 0.01 else { return }
+
+        let bloomScale = 0.95 + clampedProgress * 0.95
+        let bloomRect = applyScale(bloomScale, to: rect).insetBy(dx: 4, dy: 4)
+        NSColor.white.withAlphaComponent(fade * 0.32).setFill()
+        NSBezierPath(ovalIn: bloomRect).fill()
+
+        let ringRect = bloomRect.insetBy(dx: 2, dy: 2)
+        let ringPath = NSBezierPath(ovalIn: ringRect)
+        color.withAlphaComponent(fade * 0.55).setStroke()
+        ringPath.lineWidth = 1.4
+        ringPath.stroke()
+    }
 
     private func applyScale(_ scale: CGFloat, to rect: CGRect) -> CGRect {
-        let clampedScale = min(1.15, max(0.4, scale))
+        let clampedScale = min(1.4, max(0.08, scale))
         let width = rect.width * clampedScale
         let height = rect.height * clampedScale
         return CGRect(
@@ -696,6 +747,22 @@ final class GameTouchBarView: NSView {
         let t = min(1, max(0, value))
         let inverted = 1 - t
         return 1 - inverted * inverted * inverted
     }
+
+    private func easeInCubic(_ value: CGFloat) -> CGFloat {
+        let t = min(1, max(0, value))
+        return t * t * t
+    }
+
+    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
+        let t = min(1, max(0, value))
+        if t < 0.5 {
+            return 4 * t * t * t
+        }
+        let adjusted = -2 * t + 2
+        return 1 - (adjusted * adjusted * adjusted) / 2
+    }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index f3017cf..65f194b 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -35,3 +35,4 @@
 - 私有 API 展示链路已升级为“双签名回退”：优先 `presentSystemModalTouchBar:systemTrayItemIdentifier:`，其次回退三参 placement 自动模式；`window.touchBar` 仅在私有调用不可用时启用，避免与系统级 modal 渲染冲突。
 - 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
 - 当前已恢复 ESC 隐藏占位：`escapeKeyReplacementItemIdentifier` 绑定 0 宽 `escape-placeholder`，确保不显示系统 ESC 键且保持主棋盘渲染链路不变。
+- 已增强消除动画可见性：新增消除光晕/外环特效，消除缩放范围扩大（`1.22 -> 0.12`），并把过渡时长提升到 `0.28s`，使消除反馈更明显。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 9a2f3aa..3f0d3fe 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221184845-touchbar-eliminate-animation-visibility-boost.md` - 增强消除动画可见性，增加消除光晕特效并放大缩放/时长参数。
 `workflow/20260221174959-touchbar-hide-esc-placeholder.md` - 恢复 ESC 隐藏占位，避免系统 ESC 键重新显示。
@@ -36,6 +37,7 @@
 ## 读取场景
+- 需要确认“消除动画不明显如何增强”时，优先读取 `20260221184845` 文档。
 - 需要确认“为什么 ESC 又出现、如何重新隐藏 ESC”时，优先读取 `20260221174959` 文档。
@@ -70,6 +72,7 @@
 ## 关键记忆
+- 消除动画可见性已增强：消除帧使用 `easeIn` + 光晕外环，缩放区间 `1.22 -> 0.12`，动画总时长 `0.28s`，并对移动/插入采用分离 easing。
 - Touch Bar 当前通过 `escapeKeyReplacementItemIdentifier = escape-placeholder`（0 宽视图）隐藏系统 ESC，避免私有 API 链路中再次显示 ESC 键。
```

## 测试用例
### TC-001 消除动画可见性
- 类型：交互测试
- 步骤：连续交换触发消除。
- 预期：消除时可明显看到光晕/外环 + 快速收缩淡出。

### TC-002 移动与补位动画无回归
- 类型：交互测试
- 步骤：触发普通交换与左补位。
- 预期：交换平滑、补位从左滑入，时序正常。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
- 结果：已通过。
