# Touch Bar 三阶段动画时序：交换 → 消除 → 左补位

## 背景与目标
- 用户要求严格时序：交换动画后才消除，消除动画后才补位。
- 本次把动画链路改为三阶段顺序执行，避免并发动画导致观感错误。

## 方案
- 在 `GameBoardController` 增加 `lastSwapPair`，用于提供真实交换索引。
- 在 `GameTouchBarView` 增加 `TransitionPhase` 阶段队列，按顺序执行：
  - 交换位移（0.16s）
  - 消除反馈（0.20s）
  - 左侧补位（0.24s）
- 非交换触发的更新保留单阶段兜底，避免动画中断。

## 代码变更
- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 4a55925..3942ce9 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -29,6 +29,7 @@ final class GameBoardController {
     private var stoppedElapsedTime: TimeInterval = 0
     private var isRunningRound = true
     private var isFinished = false
+    private var lastSwapPair: (Int, Int)?
 
     private var lockedIndices: Set<Int> = []
     private var selectedIndex: Int?
@@ -178,6 +179,7 @@ final class GameBoardController {
         guard abs(leftIndex - rightIndex) == 1 else { return }
         guard !lockedIndices.contains(leftIndex), !lockedIndices.contains(rightIndex) else { return }
 
+        lastSwapPair = (leftIndex, rightIndex)
         lockedIndices.insert(leftIndex)
         lockedIndices.insert(rightIndex)
         _ = state.swapAndResolve(leftIndex, rightIndex)
@@ -189,6 +191,12 @@ final class GameBoardController {
         notifyChange()
     }
 
+    func consumeLastSwapPair() -> (Int, Int)? {
+        let pair = lastSwapPair
+        lastSwapPair = nil
+        return pair
+    }
+
     func addObserver(owner: AnyObject, callback: @escaping () -> Void) -> UUID {
         let id = UUID()
         observers[id] = Observer(owner: owner, callback: callback)
@@ -210,6 +218,7 @@ final class GameBoardController {
         state = GameState(columns: columnsCount)
         lockedIndices.removeAll()
         selectedIndex = nil
+        lastSwapPair = nil
         roundStartDate = startDate
     }
 
@@ -304,17 +313,28 @@ final class GameTouchBarView: NSView {
         let toScale: CGFloat
     }
 
+    private struct TransitionPhase {
+        let transitions: [PieceTransition]
+        let duration: TimeInterval
+    }
+
     private let controller: GameBoardController
     private let columnRange: Range<Int>
     private let columnCount: Int
     private let leadingCompensationX: CGFloat
     private let transitionDuration: TimeInterval = 0.28
+    private let swapPhaseDuration: TimeInterval = 0.16
+    private let eliminatePhaseDuration: TimeInterval = 0.2
+    private let refillPhaseDuration: TimeInterval = 0.24
     private let animationFrameInterval: TimeInterval = 1.0 / 60.0
 
     private var observerToken: UUID?
     private var activeTouches: [ObjectIdentifier: TouchState] = [:]
     private var renderedTiles: [BoardTile]
     private var pieceTransitions: [PieceTransition] = []
+    private var transitionPhases: [TransitionPhase] = []
+    private var transitionPhaseIndex = 0
+    private var activePhaseDuration: TimeInterval = 0.28
     private var transitionStartTime: TimeInterval = 0
     private var transitionProgress: CGFloat = 1
     private var transitionTimer: Timer?
@@ -484,17 +504,20 @@ final class GameTouchBarView: NSView {
 
     private func handleControllerChange() {
         let latestTiles = controller.tiles()
+        let swapPair = controller.consumeLastSwapPair()
         if latestTiles == renderedTiles {
             needsDisplay = true
             return
         }
 
-        beginPieceTransition(from: renderedTiles, to: latestTiles)
+        beginPieceTransition(from: renderedTiles, to: latestTiles, swapPair: swapPair)
         renderedTiles = latestTiles
     }
 
-    private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile]) {
+    private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile], swapPair: (Int, Int)?) {
         transitionTimer?.invalidate()
+        transitionPhases = []
+        transitionPhaseIndex = 0
 
         // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
         let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
@@ -506,80 +529,195 @@ final class GameTouchBarView: NSView {
         let removedIDs = oldIDs.subtracting(newIDs)
         let insertedIDs = newIDs.subtracting(oldIDs)
 
-        var transitions: [PieceTransition] = []
-        transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
-
-        for id in sharedIDs {
-            guard let oldIndex = oldIndices[id], let newIndex = newIndices[id] else { continue }
-            guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
-            transitions.append(
-                PieceTransition(
-                    id: id,
-                    kind: tile.kind,
-                    transitionKind: .move,
-                    fromIndex: oldIndex,
-                    toIndex: newIndex,
-                    fromAlpha: 1,
-                    toAlpha: 1,
-                    fromScale: 1,
-                    toScale: 1
-                )
-            )
-        }
-
-        for id in removedIDs {
-            guard let oldIndex = oldIndices[id] else { continue }
-            guard let tile = oldTiles.first(where: { $0.id == id }) else { continue }
-            transitions.append(
-                PieceTransition(
-                    id: id,
-                    kind: tile.kind,
-                    transitionKind: .remove,
-                    fromIndex: oldIndex,
-                    toIndex: oldIndex,
-                    fromAlpha: 1,
-                    toAlpha: 0,
-                    fromScale: 1.22,
-                    toScale: 0.12
-                )
-            )
-        }
-
-        let insertedByIndex = insertedIDs.sorted {
-            (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
-        }
-        let insertedCount = insertedByIndex.count
-        for id in insertedByIndex {
-            guard let newIndex = newIndices[id] else { continue }
-            guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
-            // 新补位方块从左侧滑入，体现“左补位”动态效果。
-            transitions.append(
-                PieceTransition(
-                    id: id,
-                    kind: tile.kind,
-                    transitionKind: .insert,
-                    fromIndex: newIndex - insertedCount,
-                    toIndex: newIndex,
-                    fromAlpha: 0.1,
-                    toAlpha: 1,
-                    fromScale: 0.72,
-                    toScale: 1
-                )
-            )
-        }
-
-        if transitions.isEmpty {
-            pieceTransitions = []
-            transitionProgress = 1
-            needsDisplay = true
-            return
-        }
-
-        pieceTransitions = transitions
-        transitionStartTime = Date().timeIntervalSinceReferenceDate
-        transitionProgress = 0
-        needsDisplay = true
-
-        transitionTimer = Timer.scheduledTimer(
-            timeInterval: animationFrameInterval,
-            target: self,
-            selector: #selector(handleTransitionTick),
-            userInfo: nil,
-            repeats: true
-        )
-    }
+        var phases: [TransitionPhase] = []
+
+        // 第 1 阶段：交换位移动画（仅在有明确交换对时启用）。
+        if let swapPair {
+            let swappedIndexByID = buildSwappedIndexMap(oldTiles: oldTiles, swapPair: swapPair)
+            var swapPhaseTransitions: [PieceTransition] = []
+            swapPhaseTransitions.reserveCapacity(oldTiles.count)
+            for tile in oldTiles {
+                guard let fromIndex = oldIndices[tile.id], let toIndex = swappedIndexByID[tile.id] else { continue }
+                swapPhaseTransitions.append(
+                    PieceTransition(
+                        id: tile.id,
+                        kind: tile.kind,
+                        transitionKind: .move,
+                        fromIndex: fromIndex,
+                        toIndex: toIndex,
+                        fromAlpha: 1,
+                        toAlpha: 1,
+                        fromScale: 1,
+                        toScale: 1
+                    )
+                )
+            }
+            if !swapPhaseTransitions.isEmpty {
+                phases.append(TransitionPhase(transitions: swapPhaseTransitions, duration: swapPhaseDuration))
+            }
+
+            // 第 2 阶段：消除动画，仅对被消除方块做明显反馈，其余方块静止等待。
+            if !removedIDs.isEmpty {
+                var eliminatePhaseTransitions: [PieceTransition] = []
+                eliminatePhaseTransitions.reserveCapacity(oldTiles.count)
+                for tile in oldTiles {
+                    guard let swappedIndex = swappedIndexByID[tile.id] else { continue }
+                    if removedIDs.contains(tile.id) {
+                        eliminatePhaseTransitions.append(
+                            PieceTransition(
+                                id: tile.id,
+                                kind: tile.kind,
+                                transitionKind: .remove,
+                                fromIndex: swappedIndex,
+                                toIndex: swappedIndex,
+                                fromAlpha: 1,
+                                toAlpha: 0,
+                                fromScale: 1.22,
+                                toScale: 0.12
+                            )
+                        )
+                    } else {
+                        eliminatePhaseTransitions.append(
+                            PieceTransition(
+                                id: tile.id,
+                                kind: tile.kind,
+                                transitionKind: .move,
+                                fromIndex: swappedIndex,
+                                toIndex: swappedIndex,
+                                fromAlpha: 1,
+                                toAlpha: 1,
+                                fromScale: 1,
+                                toScale: 1
+                            )
+                        )
+                    }
+                }
+                phases.append(TransitionPhase(transitions: eliminatePhaseTransitions, duration: eliminatePhaseDuration))
+            }
+
+            // 第 3 阶段：左侧补位与存活方块位移。
+            var refillPhaseTransitions: [PieceTransition] = []
+            refillPhaseTransitions.reserveCapacity(sharedIDs.count + insertedIDs.count)
+            let insertedByIndex = insertedIDs.sorted {
+                (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
+            }
+            let insertedCount = insertedByIndex.count
+
+            for id in sharedIDs {
+                guard let endIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
+                let fromIndex = swappedIndexByID[id] ?? oldIndices[id] ?? endIndex
+                refillPhaseTransitions.append(
+                    PieceTransition(
+                        id: id,
+                        kind: tile.kind,
+                        transitionKind: .move,
+                        fromIndex: fromIndex,
+                        toIndex: endIndex,
+                        fromAlpha: 1,
+                        toAlpha: 1,
+                        fromScale: 1,
+                        toScale: 1
+                    )
+                )
+            }
+
+            for id in insertedByIndex {
+                guard let newIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
+                refillPhaseTransitions.append(
+                    PieceTransition(
+                        id: id,
+                        kind: tile.kind,
+                        transitionKind: .insert,
+                        fromIndex: newIndex - insertedCount,
+                        toIndex: newIndex,
+                        fromAlpha: 0.1,
+                        toAlpha: 1,
+                        fromScale: 0.72,
+                        toScale: 1
+                    )
+                )
+            }
+
+            if !refillPhaseTransitions.isEmpty {
+                phases.append(TransitionPhase(transitions: refillPhaseTransitions, duration: refillPhaseDuration))
+            }
+        } else {
+            // 无明确交换对时，回退到单阶段过渡，避免非交换场景动画中断。
+            var transitions: [PieceTransition] = []
+            transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
+
+            for id in sharedIDs {
+                guard let oldIndex = oldIndices[id], let newIndex = newIndices[id] else { continue }
+                guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
+                transitions.append(
+                    PieceTransition(
+                        id: id,
+                        kind: tile.kind,
+                        transitionKind: .move,
+                        fromIndex: oldIndex,
+                        toIndex: newIndex,
+                        fromAlpha: 1,
+                        toAlpha: 1,
+                        fromScale: 1,
+                        toScale: 1
+                    )
+                )
+            }
+
+            for id in removedIDs {
+                guard let oldIndex = oldIndices[id] else { continue }
+                guard let tile = oldTiles.first(where: { $0.id == id }) else { continue }
+                transitions.append(
+                    PieceTransition(
+                        id: id,
+                        kind: tile.kind,
+                        transitionKind: .remove,
+                        fromIndex: oldIndex,
+                        toIndex: oldIndex,
+                        fromAlpha: 1,
+                        toAlpha: 0,
+                        fromScale: 1.22,
+                        toScale: 0.12
+                    )
+                )
+            }
+
+            let insertedByIndex = insertedIDs.sorted {
+                (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
+            }
+            let insertedCount = insertedByIndex.count
+            for id in insertedByIndex {
+                guard let newIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
+                transitions.append(
+                    PieceTransition(
+                        id: id,
+                        kind: tile.kind,
+                        transitionKind: .insert,
+                        fromIndex: newIndex - insertedCount,
+                        toIndex: newIndex,
+                        fromAlpha: 0.1,
+                        toAlpha: 1,
+                        fromScale: 0.72,
+                        toScale: 1
+                    )
+                )
+            }
+
+            if !transitions.isEmpty {
+                phases.append(TransitionPhase(transitions: transitions, duration: transitionDuration))
+            }
+        }
+
+        if phases.isEmpty {
+            pieceTransitions = []
+            transitionProgress = 1
+            needsDisplay = true
+            return
+        }
+
+        transitionPhases = phases
+        transitionPhaseIndex = 0
+        applyCurrentPhase()
+        transitionTimer = Timer.scheduledTimer(
+            timeInterval: animationFrameInterval,
+            target: self,
+            selector: #selector(handleTransitionTick),
+            userInfo: nil,
+            repeats: true
+        )
+    }
+
+    private func buildSwappedIndexMap(oldTiles: [BoardTile], swapPair: (Int, Int)) -> [UUID: Int] {
+        guard swapPair.0 >= 0, swapPair.1 >= 0, swapPair.0 < oldTiles.count, swapPair.1 < oldTiles.count else {
+            return Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
+        }
+
+        var indexMap = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
+        let leftTileID = oldTiles[swapPair.0].id
+        let rightTileID = oldTiles[swapPair.1].id
+        indexMap[leftTileID] = swapPair.1
+        indexMap[rightTileID] = swapPair.0
+        return indexMap
+    }
+
+    private func applyCurrentPhase() {
+        guard transitionPhaseIndex < transitionPhases.count else { return }
+        let phase = transitionPhases[transitionPhaseIndex]
+        pieceTransitions = phase.transitions
+        activePhaseDuration = max(0.01, phase.duration)
+        transitionStartTime = Date().timeIntervalSinceReferenceDate
+        transitionProgress = 0
+        needsDisplay = true
+    }
@@ -589,16 +727,46 @@ final class GameTouchBarView: NSView {
     }
 
     @objc private func handleTransitionTick() {
         let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
-        let progress = min(1, max(0, elapsed / transitionDuration))
+        let progress = min(1, max(0, elapsed / activePhaseDuration))
         transitionProgress = CGFloat(progress)
         needsDisplay = true
 
         guard progress >= 1 else { return }
+        if transitionPhaseIndex + 1 < transitionPhases.count {
+            transitionPhaseIndex += 1
+            applyCurrentPhase()
+            return
+        }
         transitionTimer?.invalidate()
         transitionTimer = nil
         pieceTransitions = []
+        transitionPhases = []
+        transitionPhaseIndex = 0
     }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index a50752b..9181ac7 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -37,3 +37,4 @@
 - 当前已恢复 ESC 隐藏占位：`escapeKeyReplacementItemIdentifier` 绑定 0 宽 `escape-placeholder`，确保不显示系统 ESC 键且保持主棋盘渲染链路不变。
 - 已增强消除动画可见性：新增消除光晕/外环特效，消除缩放范围扩大（`1.22 -> 0.12`），并把过渡时长提升到 `0.28s`，使消除反馈更明显。
 - 已按“答-25”回退动画时序：取消两阶段串联，恢复为单阶段过渡（`0.28s`），保留增强后的消除光晕/外环与缩放淡出效果。
+- 动画时序现已按最新需求调整为三阶段：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；通过 `lastSwapPair + transitionPhases` 串联，确保“先交换、再消除、后补位”。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 45f4ab3..d0f2562 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
 `workflow/20260221192738-touchbar-animation-rollback-to-answer25.md` - 按“答-25”回退 Touch Bar 动画时序，取消两阶段串联并恢复单阶段过渡。
 `workflow/20260221185955-touchbar-animation-sequence-move-then-eliminate.md` - Touch Bar 动画改为两阶段顺序：先移动后消除与补位。
 `workflow/20260221184845-touchbar-eliminate-animation-visibility-boost.md` - 增强消除动画可见性，增加消除光晕特效并放大缩放/时长参数。
@@ -37,6 +38,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
 - 需要确认“已回退到答-25的动画时序”时，优先读取 `20260221192738` 文档。
 - 需要确认“动画顺序为何曾改为先移动后消除（历史方案）”时，优先读取 `20260221185955` 文档。
 - 需要确认“消除动画不明显如何增强”时，优先读取 `20260221184845` 文档。
@@ -74,6 +76,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
 - Touch Bar 动画时序已回退到答-25：单阶段过渡（`0.28s`），保留消除光晕/外环与放大缩放淡出，取消两阶段 pending 串联逻辑。
 - 消除动画可见性已增强：消除帧使用 `easeIn` + 光晕外环，缩放区间 `1.22 -> 0.12`，动画总时长 `0.28s`，并对移动/插入采用分离 easing。
 - Touch Bar 当前通过 `escapeKeyReplacementItemIdentifier = escape-placeholder`（0 宽视图）隐藏系统 ESC，避免私有 API 链路中再次显示 ESC 键。
```

## 测试用例
### TC-001 三阶段时序验证
- 类型：交互测试
- 步骤：触发一次可消除交换。
- 预期：先看到交换动画，再看到消除动画，最后才出现左补位动画。

### TC-002 非交换场景兜底验证
- 类型：稳定性测试
- 步骤：触发非交换导致的棋盘刷新（例如重置）。
- 预期：仍可正常渲染，回退单阶段动画，不出现空白帧。

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
- 结果：已通过。
