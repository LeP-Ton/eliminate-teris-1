import Cocoa

final class GameTouchBarView: NSView {
    private struct TouchState {
        let startIndex: Int
        var currentIndex: Int
    }

    private let columns: Int
    private let state: GameState
    private var activeTouches: [ObjectIdentifier: TouchState] = [:]
    private var lockedIndices: Set<Int> = []
    private var selectedIndex: Int?

    init(columns: Int) {
        self.columns = columns
        self.state = GameState(columns: columns)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        allowedTouchTypes = [.direct, .indirect]
        wantsRestingTouches = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 1085, height: 30)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.9).setFill()
        bounds.fill()

        for index in 0..<columns {
            let rect = cellRect(for: index)
            let isSelected = selectedIndex == index
            let isLocked = lockedIndices.contains(index)
            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
            drawPiece(state.tiles[index], in: rect, highlighted: isLocked || isSelected)
        }

        drawScore()
    }

    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        for touch in touches {
            let point = touch.location(in: self)
            let index = indexForPoint(point)
            guard isValidIndex(index) else { continue }
            if lockedIndices.contains(index) {
                continue
            }
            let id = ObjectIdentifier(touch.identity as AnyObject)
            activeTouches[id] = TouchState(startIndex: index, currentIndex: index)
            lockedIndices.insert(index)
        }
        needsDisplay = true
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
        needsDisplay = true
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

            lockedIndices.remove(state.startIndex)
            activeTouches.removeValue(forKey: id)

            guard isValidIndex(endIndex) else { continue }
            if endIndex == state.startIndex {
                handleTap(at: endIndex)
                continue
            }

            guard abs(endIndex - state.startIndex) == 1 else { continue }
            guard !lockedIndices.contains(endIndex) else { continue }

            performSwap(from: state.startIndex, to: endIndex)
        }
        needsDisplay = true
    }

    private func handleTouchesCancelled(_ touches: Set<NSTouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch.identity as AnyObject)
            guard let state = activeTouches[id] else { continue }
            lockedIndices.remove(state.startIndex)
            activeTouches.removeValue(forKey: id)
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = indexForPoint(point)
        guard isValidIndex(index) else { return }
        handleTap(at: index)
        needsDisplay = true
    }

    private func handleTap(at index: Int) {
        if let selected = selectedIndex {
            if selected == index {
                selectedIndex = nil
                return
            }
            if abs(selected - index) == 1 {
                performSwap(from: selected, to: index)
                selectedIndex = nil
                return
            }
        }
        selectedIndex = index
    }

    private func performSwap(from leftIndex: Int, to rightIndex: Int) {
        guard abs(leftIndex - rightIndex) == 1 else { return }
        guard !lockedIndices.contains(leftIndex), !lockedIndices.contains(rightIndex) else { return }

        lockedIndices.insert(leftIndex)
        lockedIndices.insert(rightIndex)
        _ = state.swapAndResolve(leftIndex, rightIndex)
        lockedIndices.remove(leftIndex)
        lockedIndices.remove(rightIndex)
        selectedIndex = nil
        needsDisplay = true
    }

    private func drawScore() {
        let scoreText = "Score \(state.score)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let text = scoreText as NSString
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(
            x: bounds.maxX - size.width - 8,
            y: bounds.maxY - size.height - 6
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
        let inset = rect.insetBy(dx: 3, dy: 4)
        let path = NSBezierPath(roundedRect: inset, xRadius: 6, yRadius: 6)
        let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
        fill.setFill()
        path.fill()
    }

    private func drawPiece(_ kind: PieceKind, in rect: CGRect, highlighted: Bool) {
        let inner = rect.insetBy(dx: 7, dy: 6)
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

    private func cellRect(for index: Int) -> CGRect {
        let width = bounds.width / CGFloat(columns)
        return CGRect(
            x: CGFloat(index) * width,
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    private func indexForPoint(_ point: CGPoint) -> Int {
        guard bounds.width > 0 else { return -1 }
        let width = bounds.width / CGFloat(columns)
        return Int(point.x / width)
    }

    private func isValidIndex(_ index: Int) -> Bool {
        return index >= 0 && index < columns
    }
}
