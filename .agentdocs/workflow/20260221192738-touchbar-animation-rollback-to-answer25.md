# Touch Bar 动画回退到答-25（取消两阶段时序）

## 背景与目标
- 用户明确要求回退到“答-25”。
- 需要撤销“先移动后消除”的两阶段串联逻辑，恢复为答-25的单阶段动画。

## 回退策略
- 移除两阶段时序字段与 pending 串联状态。
- `beginPieceTransition` 回退为单阶段 transitions 生成与播放。
- `handleTransitionTick` 回退为使用统一 `transitionDuration`。
- 保留答-25已确认有效的增强消除表现（光晕/外环 + 强缩放淡出）。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 2fe5ec5..a8ddf3e 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -307,19 +307,14 @@ final class GameTouchBarView: NSView {
     private let controller: GameBoardController
     private let columnRange: Range<Int>
     private let columnCount: Int
     private let leadingCompensationX: CGFloat
-    private let movePhaseDuration: TimeInterval = 0.18
-    private let resolvePhaseDuration: TimeInterval = 0.24
+    private let transitionDuration: TimeInterval = 0.28
     private let animationFrameInterval: TimeInterval = 1.0 / 60.0
@@
     private var observerToken: UUID?
     private var activeTouches: [ObjectIdentifier: TouchState] = [:]
     private var renderedTiles: [BoardTile]
     private var pieceTransitions: [PieceTransition] = []
-    private var pendingTransitions: [PieceTransition] = []
     private var transitionStartTime: TimeInterval = 0
     private var transitionProgress: CGFloat = 1
-    private var currentTransitionDuration: TimeInterval = 0.2
-    private var pendingTransitionDuration: TimeInterval = 0
     private var transitionTimer: Timer?
@@ -499,10 +494,8 @@ final class GameTouchBarView: NSView {
     private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile]) {
         transitionTimer?.invalidate()
-        pendingTransitions = []
-        pendingTransitionDuration = 0
 
         // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
         let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
         let newIndices = Dictionary(uniqueKeysWithValues: newTiles.enumerated().map { ($1.id, $0) })
@@ -510,11 +503,8 @@ final class GameTouchBarView: NSView {
         let removedIDs = oldIDs.subtracting(newIDs)
         let insertedIDs = newIDs.subtracting(oldIDs)
 
-        var movePhaseTransitions: [PieceTransition] = []
-        movePhaseTransitions.reserveCapacity(sharedIDs.count + removedIDs.count)
-        var resolvePhaseTransitions: [PieceTransition] = []
-        resolvePhaseTransitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
+        var transitions: [PieceTransition] = []
+        transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
@@ -520,7 +510,7 @@ final class GameTouchBarView: NSView {
             guard let oldIndex = oldIndices[id], let newIndex = newIndices[id] else { continue }
             guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
-            movePhaseTransitions.append(
+            transitions.append(
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
@@ -549,7 +539,7 @@ final class GameTouchBarView: NSView {
         for id in removedIDs {
             guard let oldIndex = oldIndices[id] else { continue }
             guard let tile = oldTiles.first(where: { $0.id == id }) else { continue }
-            resolvePhaseTransitions.append(
+            transitions.append(
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
@@ -587,7 +577,7 @@ final class GameTouchBarView: NSView {
         for id in insertedByIndex {
             guard let newIndex = newIndices[id] else { continue }
             guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
-            resolvePhaseTransitions.append(
+            transitions.append(
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
@@ -607,46 +597,12 @@ final class GameTouchBarView: NSView {
-        let hasMovePhase = movePhaseTransitions.contains { $0.fromIndex != $0.toIndex }
-        let hasResolvePhase = !removedIDs.isEmpty || !insertedIDs.isEmpty
-
-        if hasMovePhase && hasResolvePhase {
-            startTransition(
-                current: movePhaseTransitions,
-                duration: movePhaseDuration,
-                pending: resolvePhaseTransitions,
-                pendingDuration: resolvePhaseDuration
-            )
-            return
-        }
-
-        let singlePhaseTransitions: [PieceTransition]
-        let singlePhaseDuration: TimeInterval
-        if hasResolvePhase {
-            singlePhaseTransitions = resolvePhaseTransitions
-            singlePhaseDuration = resolvePhaseDuration
-        } else {
-            singlePhaseTransitions = movePhaseTransitions
-            singlePhaseDuration = movePhaseDuration
-        }
-
-        if singlePhaseTransitions.isEmpty {
+        if transitions.isEmpty {
             pieceTransitions = []
-            pendingTransitions = []
             transitionProgress = 1
             needsDisplay = true
             return
         }
 
-        startTransition(
-            current: singlePhaseTransitions,
-            duration: singlePhaseDuration,
-            pending: [],
-            pendingDuration: 0
-        )
-    }
-
-    private func startTransition(
-        current: [PieceTransition],
-        duration: TimeInterval,
-        pending: [PieceTransition],
-        pendingDuration: TimeInterval
-    ) {
-        pieceTransitions = current
-        pendingTransitions = pending
-        currentTransitionDuration = max(0.01, duration)
-        pendingTransitionDuration = pendingDuration
+        pieceTransitions = transitions
         transitionStartTime = Date().timeIntervalSinceReferenceDate
         transitionProgress = 0
         needsDisplay = true
@@ -668,22 +624,11 @@ final class GameTouchBarView: NSView {
     @objc private func handleTransitionTick() {
         let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
-        let duration = max(0.01, currentTransitionDuration)
-        let progress = min(1, max(0, elapsed / duration))
+        let progress = min(1, max(0, elapsed / transitionDuration))
         transitionProgress = CGFloat(progress)
         needsDisplay = true
 
         guard progress >= 1 else { return }
-        if !pendingTransitions.isEmpty {
-            pieceTransitions = pendingTransitions
-            pendingTransitions = []
-            currentTransitionDuration = max(0.01, pendingTransitionDuration)
-            pendingTransitionDuration = 0
-            transitionStartTime = Date().timeIntervalSinceReferenceDate
-            transitionProgress = 0
-            needsDisplay = true
-            return
-        }
         transitionTimer?.invalidate()
         transitionTimer = nil
         pieceTransitions = []
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index a2259cf..3e5e8ec 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -36,4 +36,4 @@
 - 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
 - 当前已恢复 ESC 隐藏占位：`escapeKeyReplacementItemIdentifier` 绑定 0 宽 `escape-placeholder`，确保不显示系统 ESC 键且保持主棋盘渲染链路不变。
 - 已增强消除动画可见性：新增消除光晕/外环特效，消除缩放范围扩大（`1.22 -> 0.12`），并把过渡时长提升到 `0.28s`，使消除反馈更明显。
-- Touch Bar 动画顺序已改为两阶段：先执行移动阶段（交换/位移），移动完成后再执行结算阶段（消除光效+淡出与左侧补位滑入），避免“移动与消除同时发生”造成观感混乱。
+- 已按“答-25”回退动画时序：取消两阶段串联，恢复为单阶段过渡（`0.28s`），保留增强后的消除光晕/外环与缩放淡出效果。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 5e1ea0c..6d59724 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221192738-touchbar-animation-rollback-to-answer25.md` - 按“答-25”回退 Touch Bar 动画时序，取消两阶段串联并恢复单阶段过渡。
 `workflow/20260221185955-touchbar-animation-sequence-move-then-eliminate.md` - Touch Bar 动画改为两阶段顺序：先移动后消除与补位。
@@ -38,7 +39,8 @@
 ## 读取场景
-- 需要确认“动画顺序是否改为先移动后消除”时，优先读取 `20260221185955` 文档。
+- 需要确认“已回退到答-25的动画时序”时，优先读取 `20260221192738` 文档。
+- 需要确认“动画顺序为何曾改为先移动后消除（历史方案）”时，优先读取 `20260221185955` 文档。
@@ -70,7 +72,7 @@
 ## 关键记忆
-- Touch Bar 动画已改为双阶段时序：先移动阶段（`0.18s`），后结算阶段（`0.24s`，含消除与补位），通过 pending transition 串联，保证“移动完成后再消除”。
+- Touch Bar 动画时序已回退到答-25：单阶段过渡（`0.28s`），保留消除光晕/外环与放大缩放淡出，取消两阶段 pending 串联逻辑。
```

## 测试用例
### TC-001 回退时序验证
- 类型：交互测试
- 步骤：触发可消除交换。
- 预期：交换/消除/补位再次回到单阶段过渡（答-25表现）。

### TC-002 消除增强效果验证
- 类型：交互测试
- 步骤：连续触发 3 连消。
- 预期：仍可看到增强后的消除光晕 + 收缩淡出。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
- 结果：已通过。
