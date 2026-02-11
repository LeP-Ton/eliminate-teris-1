import Cocoa

final class GameBoardController {
    private struct Observer {
        weak var owner: AnyObject?
        let callback: () -> Void
    }

    private let state: GameState
    private var lockedIndices: Set<Int> = []
    private var selectedIndex: Int?
    private var observers: [UUID: Observer] = [:]

    init(columns: Int) {
        self.state = GameState(columns: columns)
    }

    var score: Int {
        return state.score
    }

    var columns: Int {
        return state.columns
    }

    func tile(at index: Int) -> PieceKind {
        return state.tiles[index]
    }

    func isLocked(_ index: Int) -> Bool {
        return lockedIndices.contains(index)
    }

    func isSelected(_ index: Int) -> Bool {
        return selectedIndex == index
    }

    @discardableResult
    func lock(_ index: Int) -> Bool {
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
        guard abs(leftIndex - rightIndex) == 1 else { return }
        guard !lockedIndices.contains(leftIndex), !lockedIndices.contains(rightIndex) else { return }

        lockedIndices.insert(leftIndex)
        lockedIndices.insert(rightIndex)
        _ = state.swapAndResolve(leftIndex, rightIndex)
        lockedIndices.remove(leftIndex)
        lockedIndices.remove(rightIndex)
        selectedIndex = nil
        notifyChange()
    }

    func addObserver(owner: AnyObject, callback: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = Observer(owner: owner, callback: callback)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
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
        static let minScoreAreaWidth: CGFloat = 74
        static let maxScoreAreaWidth: CGFloat = 120
        static let scoreAreaRatio: CGFloat = 0.12
        static let tileOuterInsetX: CGFloat = 2
        static let tileOuterInsetY: CGFloat = 1
        static let tileInnerInsetX: CGFloat = 4
        static let tileInnerInsetY: CGFloat = 7
    }

    private struct TouchState {
        let startIndex: Int
        var currentIndex: Int
    }

    private let controller: GameBoardController
    private let columnRange: Range<Int>
    private let columnCount: Int
    private let showsScore: Bool

    private var observerToken: UUID?
    private var activeTouches: [ObjectIdentifier: TouchState] = [:]

    init(columnRange: Range<Int>, controller: GameBoardController, showsScore: Bool) {
        precondition(!columnRange.isEmpty, "columnRange must contain at least one column")

        self.columnRange = columnRange
        self.columnCount = columnRange.count
        self.controller = controller
        self.showsScore = showsScore

        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        allowedTouchTypes = [.direct, .indirect]
        wantsRestingTouches = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        observerToken = controller.addObserver(owner: self) { [weak self] in
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
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

            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
            drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
        }

        if showsScore {
            drawScore()
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

    private func drawScore() {
        let scoreText = "Score \(controller.score)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let text = scoreText as NSString
        let size = text.size(withAttributes: attributes)

        let origin = CGPoint(
            x: availableBoardWidth + (scoreAreaWidth - size.width) * 0.5,
            y: bounds.midY - size.height * 0.5
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
        let inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
        let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
        let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
        fill.setFill()
        path.fill()
    }

    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool) {
        let inner = rect.insetBy(dx: Layout.tileInnerInsetX, dy: Layout.tileInnerInsetY)
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
        let fillColor = highlighted ? baseColor.highlight(withLevel: 0.15) ?? baseColor : baseColor
        let strokeColor = baseColor.shadow(withLevel: 0.2) ?? baseColor

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
        let width = boardWidth / CGFloat(columnCount)
        return CGRect(
            x: boardOriginX + CGFloat(localIndex) * width,
            y: 0,
            width: width,
            height: bounds.height
        )
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

    private var availableBoardWidth: CGFloat {
        return max(0, bounds.width - scoreAreaWidth)
    }

    private var boardWidth: CGFloat {
        return availableBoardWidth
    }

    private var boardOriginX: CGFloat {
        return 0
    }

    private var scoreAreaWidth: CGFloat {
        guard showsScore else { return 0 }

        let proposedWidth = bounds.width * Layout.scoreAreaRatio
        return min(Layout.maxScoreAreaWidth, max(Layout.minScoreAreaWidth, proposedWidth))
    }

    private func isValidIndex(_ index: Int) -> Bool {
        return columnRange.contains(index)
    }

    private func isBoardIndex(_ index: Int) -> Bool {
        return index >= 0 && index < controller.columns
    }
}
