# Touch Bar 动画时序调整：先移动，再消除与补位

## 背景与目标
- 用户反馈当前动画时序不对，期望“先完成移动，再触发消除与消除动画”。
- 目标：把动画改为明确的两阶段流程，避免移动和消除同时发生。

## 方案
- 将单阶段过渡拆成两阶段：
  1. 移动阶段（交换/位移）
  2. 结算阶段（消除淡出 + 光效 + 左侧补位滑入）
- 新增 `pendingTransitions` 机制串联阶段，阶段 1 完成后自动进入阶段 2。
- 调整阶段时长：移动 `0.18s`、结算 `0.24s`。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index a8ddf3e..2fe5ec5 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -307,14 +307,19 @@ final class GameTouchBarView: NSView {
     private let controller: GameBoardController
     private let columnRange: Range<Int>
     private let columnCount: Int
     private let leadingCompensationX: CGFloat
-    private let transitionDuration: TimeInterval = 0.28
+    private let movePhaseDuration: TimeInterval = 0.18
+    private let resolvePhaseDuration: TimeInterval = 0.24
     private let animationFrameInterval: TimeInterval = 1.0 / 60.0
 
     private var observerToken: UUID?
     private var activeTouches: [ObjectIdentifier: TouchState] = [:]
     private var renderedTiles: [BoardTile]
     private var pieceTransitions: [PieceTransition] = []
+    private var pendingTransitions: [PieceTransition] = []
     private var transitionStartTime: TimeInterval = 0
     private var transitionProgress: CGFloat = 1
+    private var currentTransitionDuration: TimeInterval = 0.2
+    private var pendingTransitionDuration: TimeInterval = 0
     private var transitionTimer: Timer?
@@ -499,8 +504,10 @@ final class GameTouchBarView: NSView {
     private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile]) {
         transitionTimer?.invalidate()
+        pendingTransitions = []
+        pendingTransitionDuration = 0
 
         // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
         let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
         let newIndices = Dictionary(uniqueKeysWithValues: newTiles.enumerated().map { ($1.id, $0) })
@@ -510,8 +517,11 @@ final class GameTouchBarView: NSView {
         let removedIDs = oldIDs.subtracting(newIDs)
         let insertedIDs = newIDs.subtracting(oldIDs)
 
-        var transitions: [PieceTransition] = []
-        transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
+        var movePhaseTransitions: [PieceTransition] = []
+        movePhaseTransitions.reserveCapacity(sharedIDs.count + removedIDs.count)
+        var resolvePhaseTransitions: [PieceTransition] = []
+        resolvePhaseTransitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
@@ -520,6 +530,7 @@ final class GameTouchBarView: NSView {
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
+                    transitionKind: .move,
                     fromIndex: oldIndex,
                     toIndex: newIndex,
                     fromAlpha: 1,
@@ -528,6 +539,20 @@ final class GameTouchBarView: NSView {
                     toScale: 1
                 )
             )
+            resolvePhaseTransitions.append(
+                PieceTransition(
+                    id: id,
+                    kind: tile.kind,
+                    transitionKind: .move,
+                    fromIndex: newIndex,
+                    toIndex: newIndex,
+                    fromAlpha: 1,
+                    toAlpha: 1,
+                    fromScale: 1,
+                    toScale: 1
+                )
+            )
         }
@@ -532,7 +557,21 @@ final class GameTouchBarView: NSView {
             guard let oldIndex = oldIndices[id] else { continue }
             guard let tile = oldTiles.first(where: { $0.id == id }) else { continue }
-            transitions.append(
+            // 先等待移动阶段结束，再触发真正的消除反馈。
+            movePhaseTransitions.append(
+                PieceTransition(
+                    id: id,
+                    kind: tile.kind,
+                    transitionKind: .move,
+                    fromIndex: oldIndex,
+                    toIndex: oldIndex,
+                    fromAlpha: 1,
+                    toAlpha: 1,
+                    fromScale: 1,
+                    toScale: 1
+                )
+            )
+            resolvePhaseTransitions.append(
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
@@ -558,7 +597,7 @@ final class GameTouchBarView: NSView {
             guard let newIndex = newIndices[id] else { continue }
             guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
             // 新补位方块从左侧滑入，体现“左补位”动态效果。
-            transitions.append(
+            resolvePhaseTransitions.append(
                 PieceTransition(
                     id: id,
                     kind: tile.kind,
@@ -572,24 +611,60 @@ final class GameTouchBarView: NSView {
             )
         }
 
-        if transitions.isEmpty {
+        let hasMovePhase = movePhaseTransitions.contains { $0.fromIndex != $0.toIndex }
+        let hasResolvePhase = !removedIDs.isEmpty || !insertedIDs.isEmpty
+
+        if hasMovePhase && hasResolvePhase {
+            startTransition(
+                current: movePhaseTransitions,
+                duration: movePhaseDuration,
+                pending: resolvePhaseTransitions,
+                pendingDuration: resolvePhaseDuration
+            )
+            return
+        }
+
+        let singlePhaseTransitions: [PieceTransition]
+        let singlePhaseDuration: TimeInterval
+        if hasResolvePhase {
+            singlePhaseTransitions = resolvePhaseTransitions
+            singlePhaseDuration = resolvePhaseDuration
+        } else {
+            singlePhaseTransitions = movePhaseTransitions
+            singlePhaseDuration = movePhaseDuration
+        }
+
+        if singlePhaseTransitions.isEmpty {
             pieceTransitions = []
+            pendingTransitions = []
             transitionProgress = 1
             needsDisplay = true
             return
         }
 
-        pieceTransitions = transitions
+        startTransition(
+            current: singlePhaseTransitions,
+            duration: singlePhaseDuration,
+            pending: [],
+            pendingDuration: 0
+        )
+    }
+
+    private func startTransition(
+        current: [PieceTransition],
+        duration: TimeInterval,
+        pending: [PieceTransition],
+        pendingDuration: TimeInterval
+    ) {
+        pieceTransitions = current
+        pendingTransitions = pending
+        currentTransitionDuration = max(0.01, duration)
+        pendingTransitionDuration = pendingDuration
         transitionStartTime = Date().timeIntervalSinceReferenceDate
         transitionProgress = 0
         needsDisplay = true
@@ -607,13 +682,24 @@ final class GameTouchBarView: NSView {
 
     @objc private func handleTransitionTick() {
         let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
-        let progress = min(1, max(0, elapsed / transitionDuration))
+        let duration = max(0.01, currentTransitionDuration)
+        let progress = min(1, max(0, elapsed / duration))
         transitionProgress = CGFloat(progress)
         needsDisplay = true
 
         guard progress >= 1 else { return }
+        if !pendingTransitions.isEmpty {
+            pieceTransitions = pendingTransitions
+            pendingTransitions = []
+            currentTransitionDuration = max(0.01, pendingTransitionDuration)
+            pendingTransitionDuration = 0
+            transitionStartTime = Date().timeIntervalSinceReferenceDate
+            transitionProgress = 0
+            needsDisplay = true
+            return
+        }
         transitionTimer?.invalidate()
         transitionTimer = nil
         pieceTransitions = []
     }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 65f194b..a2259cf 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -36,3 +36,4 @@
 - 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
 - 当前已恢复 ESC 隐藏占位：`escapeKeyReplacementItemIdentifier` 绑定 0 宽 `escape-placeholder`，确保不显示系统 ESC 键且保持主棋盘渲染链路不变。
 - 已增强消除动画可见性：新增消除光晕/外环特效，消除缩放范围扩大（`1.22 -> 0.12`），并把过渡时长提升到 `0.28s`，使消除反馈更明显。
+- Touch Bar 动画顺序已改为两阶段：先执行移动阶段（交换/位移），移动完成后再执行结算阶段（消除光效+淡出与左侧补位滑入），避免“移动与消除同时发生”造成观感混乱。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 3f0d3fe..5e1ea0c 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,5 +1,6 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221185955-touchbar-animation-sequence-move-then-eliminate.md` - Touch Bar 动画改为两阶段顺序：先移动后消除与补位。
 `workflow/20260221184845-touchbar-eliminate-animation-visibility-boost.md` - 增强消除动画可见性，增加消除光晕特效并放大缩放/时长参数。
@@ -37,6 +38,7 @@
 ## 读取场景
+- 需要确认“动画顺序是否改为先移动后消除”时，优先读取 `20260221185955` 文档。
 - 需要确认“消除动画不明显如何增强”时，优先读取 `20260221184845` 文档。
@@ -72,6 +74,7 @@
 ## 关键记忆
+- Touch Bar 动画已改为双阶段时序：先移动阶段（`0.18s`），后结算阶段（`0.24s`，含消除与补位），通过 pending transition 串联，保证“移动完成后再消除”。
 - 消除动画可见性已增强：消除帧使用 `easeIn` + 光晕外环，缩放区间 `1.22 -> 0.12`，动画总时长 `0.28s`，并对移动/插入采用分离 easing。
```

## 测试用例
### TC-001 先移动后消除顺序验证
- 类型：交互测试
- 步骤：触发一次可消除交换。
- 预期：先看到交换/位移，位移结束后才出现消除光效与淡出。

### TC-002 左补位时序验证
- 类型：交互测试
- 步骤：触发 3 连消。
- 预期：消除阶段内才出现左补位滑入，不与前置移动阶段同时发生。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
- 结果：已通过。
