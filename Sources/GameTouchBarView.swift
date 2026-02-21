import Cocoa

enum GameMode: Equatable {
    case free
    case scoreAttack(duration: TimeInterval)
    case speedRun(targetScore: Int)
}

struct GameSnapshot {
    let mode: GameMode
    let score: Int
    let elapsedTime: TimeInterval
    let remainingTime: TimeInterval?
    let targetScore: Int?
    let isRunning: Bool
    let isFinished: Bool
}

final class GameBoardController {
    private struct Observer {
        weak var owner: AnyObject?
        let callback: () -> Void
    }

    private let columnsCount: Int
    private var state: GameState
    private var mode: GameMode = .free
    private var roundStartDate = Date()
    private var stoppedElapsedTime: TimeInterval = 0
    private var isRunningRound = true
    private var isFinished = false
    private var lastSwapPair: (Int, Int)?

    private var lockedIndices: Set<Int> = []
    private var selectedIndex: Int?
    private var observers: [UUID: Observer] = [:]

    init(columns: Int) {
        self.columnsCount = columns
        self.state = GameState(columns: columns)
    }

    var columns: Int {
        return columnsCount
    }

    func configure(mode: GameMode) {
        self.mode = mode
        resetBoard(startDate: Date())
        stoppedElapsedTime = 0
        isRunningRound = isFreeMode
        isFinished = false
        notifyChange()
    }

    func startRound() {
        guard !isFreeMode else { return }

        resetBoard(startDate: Date())
        stoppedElapsedTime = 0
        isRunningRound = true
        isFinished = false
        notifyChange()
    }

    func tick(now: Date = Date()) {
        guard !isFreeMode else { return }
        guard isRunningRound else { return }

        _ = updateFinishedState(now: now)
        notifyChange()
    }

    func snapshot(now: Date = Date()) -> GameSnapshot {
        _ = updateFinishedState(now: now)

        let elapsed: TimeInterval
        if isRunningRound {
            elapsed = max(0, now.timeIntervalSince(roundStartDate))
        } else {
            elapsed = stoppedElapsedTime
        }

        switch mode {
        case .free:
            return GameSnapshot(
                mode: mode,
                score: state.score,
                elapsedTime: elapsed,
                remainingTime: nil,
                targetScore: nil,
                isRunning: true,
                isFinished: isFinished
            )

        case .scoreAttack(let duration):
            let remaining: TimeInterval
            if isRunningRound || isFinished {
                remaining = max(0, duration - elapsed)
            } else {
                remaining = duration
            }

            return GameSnapshot(
                mode: mode,
                score: state.score,
                elapsedTime: elapsed,
                remainingTime: remaining,
                targetScore: nil,
                isRunning: isRunningRound,
                isFinished: isFinished
            )

        case .speedRun(let targetScore):
            return GameSnapshot(
                mode: mode,
                score: state.score,
                elapsedTime: elapsed,
                remainingTime: nil,
                targetScore: targetScore,
                isRunning: isRunningRound,
                isFinished: isFinished
            )
        }
    }

    func tile(at index: Int) -> PieceKind {
        return state.tiles[index].kind
    }

    func tiles() -> [BoardTile] {
        return state.tiles
    }

    func isLocked(_ index: Int) -> Bool {
        return lockedIndices.contains(index)
    }

    func isSelected(_ index: Int) -> Bool {
        return selectedIndex == index
    }

    @discardableResult
    func lock(_ index: Int) -> Bool {
        guard canInteract() else { return false }
        guard !lockedIndices.contains(index) else { return false }
        lockedIndices.insert(index)
        notifyChange()
        return true
    }

    func unlock(_ index: Int) {
        guard lockedIndices.remove(index) != nil else { return }
        notifyChange()
    }

    func handleTap(at index: Int) {
        guard canInteract() else { return }

        if let selected = selectedIndex {
            if selected == index {
                selectedIndex = nil
                notifyChange()
                return
            }

            if abs(selected - index) == 1 {
                performSwap(from: selected, to: index)
                return
            }
        }

        selectedIndex = index
        notifyChange()
    }

    func performSwap(from leftIndex: Int, to rightIndex: Int) {
        guard canInteract() else { return }
        guard abs(leftIndex - rightIndex) == 1 else { return }
        guard !lockedIndices.contains(leftIndex), !lockedIndices.contains(rightIndex) else { return }

        lastSwapPair = (leftIndex, rightIndex)
        lockedIndices.insert(leftIndex)
        lockedIndices.insert(rightIndex)
        _ = state.swapAndResolve(leftIndex, rightIndex)
        lockedIndices.remove(leftIndex)
        lockedIndices.remove(rightIndex)
        selectedIndex = nil

        _ = updateFinishedState(now: Date())
        notifyChange()
    }

    func consumeLastSwapPair() -> (Int, Int)? {
        let pair = lastSwapPair
        lastSwapPair = nil
        return pair
    }

    func addObserver(owner: AnyObject, callback: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = Observer(owner: owner, callback: callback)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private var isFreeMode: Bool {
        if case .free = mode {
            return true
        }
        return false
    }

    private func resetBoard(startDate: Date) {
        state = GameState(columns: columnsCount)
        lockedIndices.removeAll()
        selectedIndex = nil
        lastSwapPair = nil
        roundStartDate = startDate
    }

    private func canInteract(now: Date = Date()) -> Bool {
        _ = updateFinishedState(now: now)
        if isFreeMode {
            return !isFinished
        }
        return isRunningRound && !isFinished
    }

    @discardableResult
    private func updateFinishedState(now: Date) -> Bool {
        let previousFinished = isFinished

        if isFreeMode {
            isFinished = false
            return previousFinished != isFinished
        }

        guard isRunningRound else {
            return false
        }

        let elapsed = max(0, now.timeIntervalSince(roundStartDate))

        switch mode {
        case .free:
            isFinished = false
        case .scoreAttack(let duration):
            isFinished = elapsed >= duration
        case .speedRun(let targetScore):
            isFinished = state.score >= targetScore
        }

        if isFinished {
            isRunningRound = false
            stoppedElapsedTime = elapsed
            lockedIndices.removeAll()
            selectedIndex = nil
        }

        return previousFinished != isFinished
    }

    private func notifyChange() {
        var staleObservers: [UUID] = []

        for (id, observer) in observers {
            guard observer.owner != nil else {
                staleObservers.append(id)
                continue
            }
            observer.callback()
        }

        for id in staleObservers {
            observers.removeValue(forKey: id)
        }
    }
}

final class GameTouchBarView: NSView {
    private enum Layout {
        static let controlHeight: CGFloat = 30
        static let tileOuterInsetX: CGFloat = 2
        static let tileOuterInsetY: CGFloat = 1
        static let tileInnerInsetX: CGFloat = 4
        static let tileInnerInsetY: CGFloat = 7
    }

    private struct TouchState {
        let startIndex: Int
        var currentIndex: Int
    }

    private enum TransitionKind {
        case move
        case remove
        case insert
    }

    private struct PieceTransition {
        let id: UUID
        let kind: PieceKind
        let transitionKind: TransitionKind
        let fromIndex: Int
        let toIndex: Int
        let fromAlpha: CGFloat
        let toAlpha: CGFloat
        let fromScale: CGFloat
        let toScale: CGFloat
    }

    private struct TransitionPhase {
        let transitions: [PieceTransition]
        let duration: TimeInterval
    }

    private let controller: GameBoardController
    private let audioSystem = GameAudioSystem.shared
    private let columnRange: Range<Int>
    private let columnCount: Int
    private let leadingCompensationX: CGFloat
    private let transitionDuration: TimeInterval = 0.28
    private let swapPhaseDuration: TimeInterval = 0.16
    private let eliminatePhaseDuration: TimeInterval = 0.2
    private let refillPhaseDuration: TimeInterval = 0.24
    private let animationFrameInterval: TimeInterval = 1.0 / 60.0

    private var observerToken: UUID?
    private var activeTouches: [ObjectIdentifier: TouchState] = [:]
    private var renderedTiles: [BoardTile]
    private var pieceTransitions: [PieceTransition] = []
    private var transitionPhases: [TransitionPhase] = []
    private var transitionPhaseIndex = 0
    private var activePhaseDuration: TimeInterval = 0.28
    private var shouldPlayTransitionEffects = false
    private var transitionStartTime: TimeInterval = 0
    private var transitionProgress: CGFloat = 1
    private var transitionTimer: Timer?

    init(columnRange: Range<Int>, controller: GameBoardController, leadingCompensationX: CGFloat = 0) {
        precondition(!columnRange.isEmpty, "columnRange must contain at least one column")

        self.columnRange = columnRange
        self.columnCount = columnRange.count
        self.controller = controller
        self.leadingCompensationX = max(0, leadingCompensationX)
        self.renderedTiles = controller.tiles()

        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        allowedTouchTypes = [.direct, .indirect]
        wantsRestingTouches = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        observerToken = controller.addObserver(owner: self) { [weak self] in
            self?.handleControllerChange()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        transitionTimer?.invalidate()
        if let observerToken {
            controller.removeObserver(observerToken)
        }
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: Layout.controlHeight)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.9).setFill()
        bounds.fill()

        for localIndex in 0..<columnCount {
            let globalIndex = columnRange.lowerBound + localIndex
            let rect = cellRect(forLocalIndex: localIndex)
            let isSelected = controller.isSelected(globalIndex)
            let isLocked = controller.isLocked(globalIndex)

            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
        }

        if pieceTransitions.isEmpty {
            for localIndex in 0..<columnCount {
                let globalIndex = columnRange.lowerBound + localIndex
                let rect = cellRect(forLocalIndex: localIndex)
                let isSelected = controller.isSelected(globalIndex)
                let isLocked = controller.isLocked(globalIndex)
                drawPiece(
                    controller.tile(at: globalIndex),
                    in: rect,
                    highlighted: isLocked || isSelected,
                    alpha: 1,
                    scale: 1
                )
            }
            return
        }

        let visibleTransitions = pieceTransitions.filter { shouldRenderTransition($0) }
        // 先绘制移动/补位，再叠加消除效果，避免消除反馈被后续方块遮挡。
        for transition in visibleTransitions where transition.transitionKind != .remove {
            drawTransitionPiece(transition)
        }
        for transition in visibleTransitions where transition.transitionKind == .remove {
            drawTransitionPiece(transition)
        }
    }

    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        for touch in touches {
            let point = touch.location(in: self)
            let index = indexForPoint(point)
            guard isValidIndex(index) else { continue }
            guard controller.lock(index) else { continue }

            let id = ObjectIdentifier(touch.identity as AnyObject)
            activeTouches[id] = TouchState(startIndex: index, currentIndex: index)
        }
    }

    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        for touch in touches {
            let id = ObjectIdentifier(touch.identity as AnyObject)
            guard var state = activeTouches[id] else { continue }

            let point = touch.location(in: self)
            let index = indexForPoint(point)
            if isValidIndex(index) && index != state.currentIndex {
                state.currentIndex = index
                activeTouches[id] = state
            }
        }
    }

    override func touchesEnded(with event: NSEvent) {
        let touches = event.touches(matching: .ended, in: self)
        handleTouchesEnded(touches)
    }

    override func touchesCancelled(with event: NSEvent) {
        let touches = event.touches(matching: .cancelled, in: self)
        handleTouchesCancelled(touches)
    }

    private func handleTouchesEnded(_ touches: Set<NSTouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch.identity as AnyObject)
            guard let state = activeTouches[id] else { continue }

            let point = touch.location(in: self)
            let endIndex = indexForPoint(point)

            controller.unlock(state.startIndex)
            activeTouches.removeValue(forKey: id)

            guard isBoardIndex(endIndex) else { continue }
            if endIndex == state.startIndex {
                controller.handleTap(at: endIndex)
                continue
            }

            guard abs(endIndex - state.startIndex) == 1 else { continue }
            guard !controller.isLocked(endIndex) else { continue }

            controller.performSwap(from: state.startIndex, to: endIndex)
        }
    }

    private func handleTouchesCancelled(_ touches: Set<NSTouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch.identity as AnyObject)
            guard let state = activeTouches[id] else { continue }

            controller.unlock(state.startIndex)
            activeTouches.removeValue(forKey: id)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = indexForPoint(point)
        guard isValidIndex(index) else { return }
        controller.handleTap(at: index)
    }

    private func handleControllerChange() {
        let latestTiles = controller.tiles()
        let swapPair = controller.consumeLastSwapPair()
        if latestTiles == renderedTiles {
            needsDisplay = true
            return
        }

        beginPieceTransition(from: renderedTiles, to: latestTiles, swapPair: swapPair)
        renderedTiles = latestTiles
    }

    private func beginPieceTransition(from oldTiles: [BoardTile], to newTiles: [BoardTile], swapPair: (Int, Int)?) {
        transitionTimer?.invalidate()
        transitionPhases = []
        transitionPhaseIndex = 0
        shouldPlayTransitionEffects = swapPair != nil

        // 通过 tile id 做前后帧配对：既能识别交换位移，也能识别消除/补位。
        let oldIndices = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
        let newIndices = Dictionary(uniqueKeysWithValues: newTiles.enumerated().map { ($1.id, $0) })

        let oldIDs = Set(oldIndices.keys)
        let newIDs = Set(newIndices.keys)
        let sharedIDs = oldIDs.intersection(newIDs)
        let removedIDs = oldIDs.subtracting(newIDs)
        let insertedIDs = newIDs.subtracting(oldIDs)

        var phases: [TransitionPhase] = []

        // 第 1 阶段：交换位移动画（仅在有明确交换对时启用）。
        if let swapPair {
            let swappedIndexByID = buildSwappedIndexMap(oldTiles: oldTiles, swapPair: swapPair)
            var swapPhaseTransitions: [PieceTransition] = []
            swapPhaseTransitions.reserveCapacity(oldTiles.count)
            for tile in oldTiles {
                guard let fromIndex = oldIndices[tile.id], let toIndex = swappedIndexByID[tile.id] else { continue }
                swapPhaseTransitions.append(
                    PieceTransition(
                        id: tile.id,
                        kind: tile.kind,
                        transitionKind: .move,
                        fromIndex: fromIndex,
                        toIndex: toIndex,
                        fromAlpha: 1,
                        toAlpha: 1,
                        fromScale: 1,
                        toScale: 1
                    )
                )
            }
            if !swapPhaseTransitions.isEmpty {
                phases.append(TransitionPhase(transitions: swapPhaseTransitions, duration: swapPhaseDuration))
            }

            // 第 2 阶段：消除动画，仅对被消除方块做明显反馈，其余方块静止等待。
            if !removedIDs.isEmpty {
                var eliminatePhaseTransitions: [PieceTransition] = []
                eliminatePhaseTransitions.reserveCapacity(oldTiles.count)
                for tile in oldTiles {
                    guard let swappedIndex = swappedIndexByID[tile.id] else { continue }
                    if removedIDs.contains(tile.id) {
                        eliminatePhaseTransitions.append(
                            PieceTransition(
                                id: tile.id,
                                kind: tile.kind,
                                transitionKind: .remove,
                                fromIndex: swappedIndex,
                                toIndex: swappedIndex,
                                fromAlpha: 1,
                                toAlpha: 0,
                                fromScale: 1.22,
                                toScale: 0.12
                            )
                        )
                    } else {
                        eliminatePhaseTransitions.append(
                            PieceTransition(
                                id: tile.id,
                                kind: tile.kind,
                                transitionKind: .move,
                                fromIndex: swappedIndex,
                                toIndex: swappedIndex,
                                fromAlpha: 1,
                                toAlpha: 1,
                                fromScale: 1,
                                toScale: 1
                            )
                        )
                    }
                }
                phases.append(TransitionPhase(transitions: eliminatePhaseTransitions, duration: eliminatePhaseDuration))
            }

            // 第 3 阶段：左侧补位与存活方块位移。
            var refillPhaseTransitions: [PieceTransition] = []
            refillPhaseTransitions.reserveCapacity(sharedIDs.count + insertedIDs.count)
            let insertedByIndex = insertedIDs.sorted {
                (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
            }
            let insertedCount = insertedByIndex.count

            for id in sharedIDs {
                guard let endIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
                let fromIndex = swappedIndexByID[id] ?? oldIndices[id] ?? endIndex
                refillPhaseTransitions.append(
                    PieceTransition(
                        id: id,
                        kind: tile.kind,
                        transitionKind: .move,
                        fromIndex: fromIndex,
                        toIndex: endIndex,
                        fromAlpha: 1,
                        toAlpha: 1,
                        fromScale: 1,
                        toScale: 1
                    )
                )
            }

            for id in insertedByIndex {
                guard let newIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
                refillPhaseTransitions.append(
                    PieceTransition(
                        id: id,
                        kind: tile.kind,
                        transitionKind: .insert,
                        fromIndex: newIndex - insertedCount,
                        toIndex: newIndex,
                        fromAlpha: 0.1,
                        toAlpha: 1,
                        fromScale: 0.72,
                        toScale: 1
                    )
                )
            }

            if !refillPhaseTransitions.isEmpty {
                phases.append(TransitionPhase(transitions: refillPhaseTransitions, duration: refillPhaseDuration))
            }
        } else {
            // 无明确交换对时，回退到单阶段过渡，避免非交换场景动画中断。
            var transitions: [PieceTransition] = []
            transitions.reserveCapacity(sharedIDs.count + removedIDs.count + insertedIDs.count)

            for id in sharedIDs {
                guard let oldIndex = oldIndices[id], let newIndex = newIndices[id] else { continue }
                guard let tile = newTiles.first(where: { $0.id == id }) else { continue }
                transitions.append(
                    PieceTransition(
                        id: id,
                        kind: tile.kind,
                        transitionKind: .move,
                        fromIndex: oldIndex,
                        toIndex: newIndex,
                        fromAlpha: 1,
                        toAlpha: 1,
                        fromScale: 1,
                        toScale: 1
                    )
                )
            }

            for id in removedIDs {
                guard let oldIndex = oldIndices[id] else { continue }
                guard let tile = oldTiles.first(where: { $0.id == id }) else { continue }
                transitions.append(
                    PieceTransition(
                        id: id,
                        kind: tile.kind,
                        transitionKind: .remove,
                        fromIndex: oldIndex,
                        toIndex: oldIndex,
                        fromAlpha: 1,
                        toAlpha: 0,
                        fromScale: 1.22,
                        toScale: 0.12
                    )
                )
            }

            let insertedByIndex = insertedIDs.sorted {
                (newIndices[$0] ?? 0) < (newIndices[$1] ?? 0)
            }
            let insertedCount = insertedByIndex.count
            for id in insertedByIndex {
                guard let newIndex = newIndices[id], let tile = newTiles.first(where: { $0.id == id }) else { continue }
                transitions.append(
                    PieceTransition(
                        id: id,
                        kind: tile.kind,
                        transitionKind: .insert,
                        fromIndex: newIndex - insertedCount,
                        toIndex: newIndex,
                        fromAlpha: 0.1,
                        toAlpha: 1,
                        fromScale: 0.72,
                        toScale: 1
                    )
                )
            }

            if !transitions.isEmpty {
                phases.append(TransitionPhase(transitions: transitions, duration: transitionDuration))
            }
        }

        if phases.isEmpty {
            pieceTransitions = []
            transitionProgress = 1
            shouldPlayTransitionEffects = false
            needsDisplay = true
            return
        }

        transitionPhases = phases
        transitionPhaseIndex = 0
        applyCurrentPhase()
        transitionTimer = Timer.scheduledTimer(
            timeInterval: animationFrameInterval,
            target: self,
            selector: #selector(handleTransitionTick),
            userInfo: nil,
            repeats: true
        )
    }

    private func buildSwappedIndexMap(oldTiles: [BoardTile], swapPair: (Int, Int)) -> [UUID: Int] {
        guard swapPair.0 >= 0, swapPair.1 >= 0, swapPair.0 < oldTiles.count, swapPair.1 < oldTiles.count else {
            return Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
        }

        var indexMap = Dictionary(uniqueKeysWithValues: oldTiles.enumerated().map { ($1.id, $0) })
        let leftTileID = oldTiles[swapPair.0].id
        let rightTileID = oldTiles[swapPair.1].id
        indexMap[leftTileID] = swapPair.1
        indexMap[rightTileID] = swapPair.0
        return indexMap
    }

    private func applyCurrentPhase() {
        guard transitionPhaseIndex < transitionPhases.count else { return }
        let phase = transitionPhases[transitionPhaseIndex]
        pieceTransitions = phase.transitions
        activePhaseDuration = max(0.01, phase.duration)
        transitionStartTime = Date().timeIntervalSinceReferenceDate
        transitionProgress = 0
        playPhaseSoundEffectIfNeeded(transitions: phase.transitions)
        needsDisplay = true
    }

    @objc private func handleTransitionTick() {
        let elapsed = Date().timeIntervalSinceReferenceDate - transitionStartTime
        let progress = min(1, max(0, elapsed / activePhaseDuration))
        transitionProgress = CGFloat(progress)
        needsDisplay = true

        guard progress >= 1 else { return }
        if transitionPhaseIndex + 1 < transitionPhases.count {
            transitionPhaseIndex += 1
            applyCurrentPhase()
            return
        }
        transitionTimer?.invalidate()
        transitionTimer = nil
        pieceTransitions = []
        transitionPhases = []
        transitionPhaseIndex = 0
        shouldPlayTransitionEffects = false
    }

    private func playPhaseSoundEffectIfNeeded(transitions: [PieceTransition]) {
        guard shouldPlayTransitionEffects else { return }
        guard !transitions.isEmpty else { return }

        // 三阶段按优先级触发：消除 > 补位 > 移动，确保同一阶段只播一种提示音。
        if transitions.contains(where: { $0.transitionKind == .remove }) {
            audioSystem.playEffect(.eliminate)
            return
        }

        if transitions.contains(where: { $0.transitionKind == .insert }) {
            audioSystem.playEffect(.refill)
            return
        }

        let hasMove = transitions.contains {
            $0.transitionKind == .move && $0.fromIndex != $0.toIndex
        }
        if hasMove {
            audioSystem.playEffect(.move)
        }
    }

    private func drawTransitionPiece(_ transition: PieceTransition) {
        let progress: CGFloat
        switch transition.transitionKind {
        case .move:
            progress = easeInOutCubic(transitionProgress)
        case .insert:
            progress = easeOutCubic(transitionProgress)
        case .remove:
            progress = easeInCubic(transitionProgress)
        }

        let fromPosition = CGFloat(transition.fromIndex)
        let toPosition = CGFloat(transition.toIndex)
        let interpolatedPosition = fromPosition + (toPosition - fromPosition) * progress
        let rect = cellRect(forBoardPosition: interpolatedPosition)
        let alpha = transition.fromAlpha + (transition.toAlpha - transition.fromAlpha) * progress
        let scale = transition.fromScale + (transition.toScale - transition.fromScale) * progress
        let highlightIndex = transition.toAlpha >= transition.fromAlpha ? transition.toIndex : transition.fromIndex
        let isHighlighted = isBoardIndex(highlightIndex) && (controller.isLocked(highlightIndex) || controller.isSelected(highlightIndex))

        if transition.transitionKind == .remove {
            drawEliminationBurst(in: rect, progress: progress, color: transition.kind.color)
        }

        drawPiece(
            transition.kind,
            in: rect,
            highlighted: isHighlighted,
            alpha: alpha,
            scale: scale
        )
    }

    private func drawCellBackground(in rect: CGRect, globalIndex: Int, highlighted: Bool) {
        var inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
        // 仅让全局第 0 列贴齐最左边缘，避免拆分视图后中间列误判为“首列”。
        if globalIndex == 0 {
            inset.origin.x -= Layout.tileOuterInsetX
            inset.size.width += Layout.tileOuterInsetX * 2
        }
        let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
        let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
        fill.setFill()
        path.fill()
    }

    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool, alpha: CGFloat, scale: CGFloat) {
        let clampedAlpha = min(1, max(0, alpha))
        guard clampedAlpha > 0.01 else { return }

        let scaledRect = applyScale(scale, to: rect)
        let inner = scaledRect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
        guard inner.width > 0, inner.height > 0 else { return }

        let blocks = kind.blocks
        let minX = blocks.map { $0.x }.min() ?? 0
        let maxX = blocks.map { $0.x }.max() ?? 0
        let minY = blocks.map { $0.y }.min() ?? 0
        let maxY = blocks.map { $0.y }.max() ?? 0

        let width = maxX - minX + 1
        let height = maxY - minY + 1
        let blockSize = min(inner.width / CGFloat(width), inner.height / CGFloat(height))

        let totalWidth = blockSize * CGFloat(width)
        let totalHeight = blockSize * CGFloat(height)
        let originX = inner.minX + (inner.width - totalWidth) * 0.5
        let originY = inner.minY + (inner.height - totalHeight) * 0.5

        let baseColor = kind.color
        let mainColor = highlighted ? baseColor.highlight(withLevel: 0.15) ?? baseColor : baseColor
        let fillColor = mainColor.withAlphaComponent(clampedAlpha)
        let strokeColor = (baseColor.shadow(withLevel: 0.2) ?? baseColor).withAlphaComponent(clampedAlpha)

        for block in blocks {
            let rect = CGRect(
                x: originX + CGFloat(block.x - minX) * blockSize,
                y: originY + CGFloat(block.y - minY) * blockSize,
                width: blockSize,
                height: blockSize
            ).insetBy(dx: 0.5, dy: 0.5)

            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            fillColor.setFill()
            path.fill()
            strokeColor.setStroke()
            path.lineWidth = 0.8
            path.stroke()
        }
    }

    private func cellRect(forLocalIndex localIndex: Int) -> CGRect {
        return cellRect(forBoardPosition: CGFloat(columnRange.lowerBound + localIndex))
    }

    private func cellRect(forBoardPosition boardIndex: CGFloat) -> CGRect {
        let width = boardWidth / CGFloat(columnCount)
        let localPosition = boardIndex - CGFloat(columnRange.lowerBound)
        return CGRect(
            x: boardOriginX + localPosition * width,
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    private func shouldRenderTransition(_ transition: PieceTransition) -> Bool {
        return columnRange.contains(transition.fromIndex) || columnRange.contains(transition.toIndex)
    }

    private func drawEliminationBurst(in rect: CGRect, progress: CGFloat, color: NSColor) {
        let clampedProgress = min(1, max(0, progress))
        let fade = max(0, 1 - clampedProgress)
        guard fade > 0.01 else { return }

        let bloomScale = 0.95 + clampedProgress * 0.95
        let bloomRect = applyScale(bloomScale, to: rect).insetBy(dx: 4, dy: 4)
        NSColor.white.withAlphaComponent(fade * 0.32).setFill()
        NSBezierPath(ovalIn: bloomRect).fill()

        let ringRect = bloomRect.insetBy(dx: 2, dy: 2)
        let ringPath = NSBezierPath(ovalIn: ringRect)
        color.withAlphaComponent(fade * 0.55).setStroke()
        ringPath.lineWidth = 1.4
        ringPath.stroke()
    }

    private func applyScale(_ scale: CGFloat, to rect: CGRect) -> CGRect {
        let clampedScale = min(1.4, max(0.08, scale))
        let width = rect.width * clampedScale
        let height = rect.height * clampedScale
        return CGRect(
            x: rect.midX - width * 0.5,
            y: rect.midY - height * 0.5,
            width: width,
            height: height
        )
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        let inverted = 1 - t
        return 1 - inverted * inverted * inverted
    }

    private func easeInCubic(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * t
    }

    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        if t < 0.5 {
            return 4 * t * t * t
        }
        let adjusted = -2 * t + 2
        return 1 - (adjusted * adjusted * adjusted) / 2
    }

    private func indexForPoint(_ point: CGPoint) -> Int {
        guard boardWidth > 0 else { return -1 }

        if point.x < boardOriginX {
            return columnRange.lowerBound - 1
        }
        if point.x >= boardOriginX + boardWidth {
            return columnRange.upperBound
        }

        let width = boardWidth / CGFloat(columnCount)
        let localIndex = Int((point.x - boardOriginX) / width)
        return columnRange.lowerBound + localIndex
    }

    private var boardWidth: CGFloat {
        return max(0, bounds.width + leadingCompensationX)
    }

    private var boardOriginX: CGFloat {
        return -leadingCompensationX
    }

    private func isValidIndex(_ index: Int) -> Bool {
        return columnRange.contains(index)
    }

    private func isBoardIndex(_ index: Int) -> Bool {
        return index >= 0 && index < controller.columns
    }
}
