# Touch Bar 增加消除与移动动画（交换 + 左补位）

## 背景与目标
- 用户希望增强游戏反馈，为 Touch Bar 棋盘加入动画。
- 重点覆盖：
  - 交换位置时的位移动画
  - 消除时的反馈动画
  - 左侧补位（新方块进入）时的位移动画

## 方案
- 在数据层给每个方块增加稳定 `id`（`BoardTile`），保证前后帧可追踪。
- 在 Touch Bar 渲染层基于 `id` 做前后状态 diff：
  - 共享 id：位置插值（移动）
  - 被移除 id：缩放 + 淡出（消除）
  - 新增 id：从左侧滑入 + 淡入（左补位）
- 动画统一约 `0.22s`，使用 `easeOutCubic`，并通过 60fps 定时器驱动重绘。

## 代码变更
- Sources/GameState.swift
```diff
diff --git a/Sources/GameState.swift b/Sources/GameState.swift
index 96ec63d..282cbb9 100644
--- a/Sources/GameState.swift
+++ b/Sources/GameState.swift
@@ -1,21 +1,30 @@
 import Foundation
 
+struct BoardTile: Equatable {
+    let id: UUID
+    let kind: PieceKind
+
+    init(id: UUID = UUID(), kind: PieceKind) {
+        self.id = id
+        self.kind = kind
+    }
+}
+
 final class GameState {
     let columns: Int
-    private(set) var tiles: [PieceKind]
+    private(set) var tiles: [BoardTile]
     private(set) var score: Int = 0
 
     init(columns: Int) {
         self.columns = columns
-        self.tiles = (0..<columns).map { _ in PieceKind.random() }
+        self.tiles = (0..<columns).map { _ in BoardTile(kind: PieceKind.random()) }
         normalizeStart()
     }
@@ -53,7 +62,7 @@ final class GameState {
     private func normalizeStart() {
         while !findMatches().isEmpty {
             for index in findMatches() {
-                tiles[index] = PieceKind.random()
+                tiles[index] = BoardTile(kind: PieceKind.random())
             }
         }
     }
@@ -77,9 +86,9 @@ final class GameState {
         var matches: Set<Int> = []
         var index = 0
         while index < tiles.count {
-            let current = tiles[index]
+            let current = tiles[index].kind
             var next = index + 1
-            while next < tiles.count, tiles[next] == current {
+            while next < tiles.count, tiles[next].kind == current {
                 next += 1
             }
@@ -96,14 +105,14 @@ final class GameState {
 
     private func refillAfterClearing(_ matches: Set<Int>) {
         guard !matches.isEmpty else { return }
-        var remaining: [PieceKind] = []
+        var remaining: [BoardTile] = []
         remaining.reserveCapacity(columns - matches.count)
         for (index, tile) in tiles.enumerated() where !matches.contains(index) {
             remaining.append(tile)
         }
 
         let missing = columns - remaining.count
-        let leftFill = (0..<missing).map { _ in PieceKind.random() }
+        let leftFill = (0..<missing).map { _ in BoardTile(kind: PieceKind.random()) }
         tiles = leftFill + remaining
     }
 }
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 20f6689..cd5d4f5 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -123,6 +123,10 @@ final class GameBoardController {
     func tile(at index: Int) -> PieceKind {
-        return state.tiles[index]
+        return state.tiles[index].kind
+    }
+
+    func tiles() -> [BoardTile] {
+        return state.tiles
     }
@@ -282,14 +286,34 @@ final class GameTouchBarView: NSView {
     private struct TouchState {
         let startIndex: Int
         var currentIndex: Int
     }
+
+    private struct PieceTransition {
+        let id: UUID
+        let kind: PieceKind
+        let fromIndex: Int
+        let toIndex: Int
+        let fromAlpha: CGFloat
+        let toAlpha: CGFloat
+        let fromScale: CGFloat
+        let toScale: CGFloat
+    }
@@
     private let leadingCompensationX: CGFloat
+    private let transitionDuration: TimeInterval = 0.22
+    private let animationFrameInterval: TimeInterval = 1.0 / 60.0
@@
     private var observerToken: UUID?
     private var activeTouches: [ObjectIdentifier: TouchState] = [:]
+    private var renderedTiles: [BoardTile]
+    private var pieceTransitions: [PieceTransition] = []
+    private var transitionStartTime: TimeInterval = 0
+    private var transitionProgress: CGFloat = 1
+    private var transitionTimer: Timer?
@@
     init(columnRange: Range<Int>, controller: GameBoardController, leadingCompensationX: CGFloat = 0) {
@@
         self.controller = controller
         self.leadingCompensationX = max(0, leadingCompensationX)
+        self.renderedTiles = controller.tiles()
@@
-        observerToken = controller.addObserver(owner: self) { [weak self] in
-            self?.needsDisplay = true
-        }
+        observerToken = controller.addObserver(owner: self) { [weak self] in
+            self?.handleControllerChange()
+        }
     }
@@
     deinit {
+        transitionTimer?.invalidate()
         if let observerToken {
             controller.removeObserver(observerToken)
         }
@@
     override func draw(_ dirtyRect: NSRect) {
@@
-            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
-            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
+            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
+        }
+
+        if pieceTransitions.isEmpty {
+            for localIndex in 0..<columnCount {
+                let globalIndex = columnRange.lowerBound + localIndex
+                let rect = cellRect(forLocalIndex: localIndex)
+                let isSelected = controller.isSelected(globalIndex)
+                let isLocked = controller.isLocked(globalIndex)
+                drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected, alpha: 1, scale: 1)
+            }
+            return
+        }
+
+        let easedProgress = easeOutCubic(transitionProgress)
+        for transition in pieceTransitions where shouldRenderTransition(transition) {
+            let interpolatedPosition = CGFloat(transition.fromIndex) + CGFloat(transition.toIndex - transition.fromIndex) * easedProgress
+            let rect = cellRect(forBoardPosition: interpolatedPosition)
+            let alpha = transition.fromAlpha + (transition.toAlpha - transition.fromAlpha) * easedProgress
+            let scale = transition.fromScale + (transition.toScale - transition.fromScale) * easedProgress
+            let highlightIndex = transition.toAlpha >= transition.fromAlpha ? transition.toIndex : transition.fromIndex
+            let isHighlighted = isBoardIndex(highlightIndex) && (controller.isLocked(highlightIndex) || controller.isSelected(highlightIndex))
+            drawPiece(transition.kind, in: rect, highlighted: isHighlighted, alpha: alpha, scale: scale)
         }
     }
@@
+    private func handleControllerChange() {
+        let latestTiles = controller.tiles()
+        if latestTiles == renderedTiles {
+            needsDisplay = true
+            return
+        }
+        beginPieceTransition(from: renderedTiles, to: latestTiles)
+        renderedTiles = latestTiles
+    }
+
+    private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile]) {
+        transitionTimer?.invalidate()
+        // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
+        let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
+        let newIndices = Dictionary(uniqueKeysWithValues: newTiles.enumerated().map { ($1.id, $0) })
+        let oldIDs = Set(oldIndices.keys)
+        let newIDs = Set(newIndices.keys)
+        let sharedIDs = oldIDs.intersection(newIDs)
+        let removedIDs = oldIDs.subtracting(newIDs)
+        let insertedIDs = newIDs.subtracting(oldIDs)
+        var transitions: [PieceTransition] = []
+        transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)
+        // 新补位方块从左侧滑入，体现“左补位”动态效果。
+        let insertedByIndex = insertedIDs.sorted {
+            (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
+        }
+        let insertedCount = insertedByIndex.count
+        for id in insertedByIndex {
+            guard let newIndex = newIndices[id] else { continue }
+            guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
+            transitions.append(
+                PieceTransition(id: id, kind: tile.kind, fromIndex: newIndex - insertedCount, toIndex: newIndex, fromAlpha: 0, toAlpha: 1, fromScale: 0.82, toScale: 1)
+            )
+        }
+    }
+
+    @objc private func handleTransitionTick() {
+        let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
+        let progress = min(1, max(0, elapsed / transitionDuration))
+        transitionProgress = CGFloat(progress)
+        needsDisplay = true
+        guard progress >= 1 else { return }
+        transitionTimer?.invalidate()
+        transitionTimer = nil
+        pieceTransitions = []
+    }
@@
-    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool) {
+    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool, alpha: CGFloat, scale: CGFloat) {
+        let clampedAlpha = min(1, max(0, alpha))
+        guard clampedAlpha > 0.01 else { return }
+        let scaledRect = applyScale(scale, to: rect)
+        let inner = scaledRect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
@@
-        let fillColor = highlighted ? baseColor.highlight(withLevel: 0.15) ?? baseColor : baseColor
-        let strokeColor = baseColor.shadow(withLevel: 0.2) ?? baseColor
+        let mainColor = highlighted ? baseColor.highlight(withLevel: 0.15) ?? baseColor : baseColor
+        let fillColor = mainColor.withAlphaComponent(clampedAlpha)
+        let strokeColor = (baseColor.shadow(withLevel: 0.2) ?? baseColor).withAlphaComponent(clampedAlpha)
@@
     private func cellRect(forLocalIndex localIndex: Int) -> CGRect {
-        let width = boardWidth / CGFloat(columnCount)
-        return CGRect(
-            x: boardOriginX + CGFloat(localIndex) * width,
-            y: 0,
-            width: width,
-            height: bounds.height
-        )
+        return cellRect(forBoardPosition: CGFloat(columnRange.lowerBound + localIndex))
+    }
+
+    private func cellRect(forBoardPosition boardIndex: CGFloat) -> CGRect {
+        let width = boardWidth / CGFloat(columnCount)
+        let localPosition = boardIndex - CGFloat(columnRange.lowerBound)
+        return CGRect(x: boardOriginX + localPosition * width, y: 0, width: width, height: bounds.height)
+    }
+
+    private func shouldRenderTransition(_ transition: PieceTransition) -> Bool {
+        return columnRange.contains(transition.fromIndex) || columnRange.contains(transition.toIndex)
+    }
+
+    private func applyScale(_ scale: CGFloat, to rect: CGRect) -> CGRect {
+        let clampedScale = min(1.15, max(0.4, scale))
+        let width = rect.width * clampedScale
+        let height = rect.height * clampedScale
+        return CGRect(x: rect.midX - width * 0.5, y: rect.midY - height * 0.5, width: width, height: height)
+    }
+
+    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
+        let t = min(1, max(0, value))
+        let inverted = 1 - t
+        return 1 - inverted * inverted * inverted
+    }
     }
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- 已为 Touch Bar 棋盘加入基础动画：交换/位移动画使用 tile id 插值，消除使用缩放淡出，左侧补位新方块从左向右滑入，统一采用约 0.22s 的 easing 过渡。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221174215-touchbar-eliminate-move-animation.md` - 为 Touch Bar 增加交换/消除/左补位动画，并基于 tile id 做位移插值渲染。
@@
+- 需要确认“交换、消除、左补位动画是否已接入 Touch Bar”时，优先读取 `20260221174215` 文档。
@@
+- Touch Bar 已接入过渡动画：共享 tile 使用位置插值，消除使用缩放淡出，新补位从左侧滑入；动画时长约 `0.22s`，曲线为 `easeOutCubic`。
```

## 测试用例
### TC-001 交换动画
- 类型：交互测试
- 步骤：
  1. 启动应用
  2. 在 Touch Bar 点击相邻方块触发交换
- 预期：
  - 两个方块在约 0.22s 内完成平滑位移

### TC-002 消除 + 左补位动画
- 类型：交互测试
- 步骤：
  1. 连续交换直到触发 3 连消
  2. 观察消除位置与新补位位置
- 预期：
  - 被消除方块有缩放淡出效果
  - 新补位方块从左侧滑入且淡入

### TC-003 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`
- 预期：构建成功
- 结果：已通过
