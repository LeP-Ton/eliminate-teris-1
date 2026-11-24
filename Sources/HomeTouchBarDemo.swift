import Foundation

/// 首页教学使用独立棋盘预演交换、消除和左侧补位。
enum HomeTouchBarDemo {
    struct Tile: Equatable {
        let kind: PieceKind
        let column: CGFloat
        var lift: CGFloat = 0
        var opacity: CGFloat = 1
        var scale: CGFloat = 1
        var highlight: CGFloat = 0
    }

    struct Gesture: Equatable {
        let from: Int
        let to: Int
        let progress: CGFloat
        let opacity: CGFloat
        let lift: CGFloat
    }

    struct Frame: Equatable {
        let tiles: [Tile]
        var gesture: Gesture? = nil
    }

    private struct Step {
        let from: Int
        let to: Int
        let before: [BoardTile]
        let swapped: [BoardTile]
        let after: [BoardTile]
        let cleared: Set<Int>
        let refillOrigins: [Int?]
    }

    static let columnCount = 13
    private static let gestureStart = 0.55
    private static let swapStart = 1.75
    private static let clearStart = 2.11
    private static let refillStart = 2.84
    static let stepDuration = 3.55
    static var stepCount: Int { steps.count }
    static var loopDuration: TimeInterval { stepDuration * Double(stepCount) }

    private static let steps: [Step] = {
        let orange = PieceKind.orangeRicky
        let blue = PieceKind.blueRicky
        let green = PieceKind.clevelandZ
        let red = PieceKind.rhodeIslandZ
        let initial = [orange, blue, green, green, blue, blue, orange, orange, green, orange, blue, blue, red]
        // 三次左侧补位之后回到初始排列，循环接缝处无需重置画面。
        let script = [
            (from: 9, to: 8, incoming: [orange, orange, green]),
            (from: 8, to: 9, incoming: [green, blue, blue]),
            (from: 11, to: 10, incoming: [orange, blue, green])
        ]
        var incoming = script.flatMap(\.incoming).makeIterator()
        let board = GameState(columns: columnCount, initialKinds: initial) {
            incoming.next() ?? PieceKind.random()
        }
        return script.map { cue in
            let before = board.tiles
            var swapped = before
            swapped.swapAt(cue.from, cue.to)
            _ = board.swapAndResolve(cue.from, cue.to)
            let after = board.tiles
            let survivorIDs = Set(after.map(\.id))
            let cleared = Set(swapped.indices.filter { !survivorIDs.contains(swapped[$0].id) })
            let oldColumns = Dictionary(uniqueKeysWithValues: swapped.enumerated().map { ($0.element.id, $0.offset) })
            return Step(from: cue.from, to: cue.to, before: before, swapped: swapped, after: after,
                        cleared: cleared, refillOrigins: after.map { oldColumns[$0.id] })
        }
    }()

    static func frame(at elapsed: TimeInterval, animated: Bool = true) -> Frame {
        guard animated else {
            let step = steps[0]
            return Frame(tiles: stationaryTiles(step.before),
                         gesture: Gesture(from: step.from, to: step.to, progress: 0, opacity: 1, lift: 0))
        }

        let loopTime = max(0, elapsed).truncatingRemainder(dividingBy: loopDuration)
        let stepIndex = min(stepCount - 1, Int(loopTime / stepDuration))
        let step = steps[stepIndex]
        let time = loopTime - Double(stepIndex) * stepDuration

        switch time {
        case ..<gestureStart:
            return Frame(tiles: stationaryTiles(step.before))
        case ..<swapStart:
            let phase = CGFloat((time - gestureStart) / (swapStart - gestureStart))
            let appear = eased(phase / 0.25)
            let swipe = eased((phase - 0.29) / 0.55)
            let fade = eased((phase - 0.83) / 0.17)
            let gesture = Gesture(from: step.from, to: step.to, progress: swipe,
                                  opacity: appear * (1 - fade), lift: 12 * (1 - appear) + 4 * fade)
            return Frame(tiles: stationaryTiles(step.before), gesture: gesture)
        case ..<clearStart:
            let phase = eased(CGFloat((time - swapStart) / (clearStart - swapStart)))
            let distance = CGFloat(step.to - step.from) * phase
            let height = 7 * sin(.pi * phase)
            let tiles = step.before.enumerated().map { index, tile in
                switch index {
                case step.from: return Tile(kind: tile.kind, column: CGFloat(index) + distance, lift: height)
                case step.to: return Tile(kind: tile.kind, column: CGFloat(index) - distance, lift: -height)
                default: return Tile(kind: tile.kind, column: CGFloat(index))
                }
            }
            return Frame(tiles: tiles)
        case ..<refillStart:
            let phase = CGFloat((time - clearStart) / (refillStart - clearStart))
            let emphasis = eased(phase / 0.24)
            let removal = eased((phase - 0.37) / 0.63)
            let tiles = step.swapped.enumerated().map { index, tile in
                guard step.cleared.contains(index) else { return Tile(kind: tile.kind, column: CGFloat(index)) }
                return Tile(kind: tile.kind, column: CGFloat(index), opacity: 1 - removal,
                            scale: 1 + 0.10 * emphasis - 0.75 * removal, highlight: emphasis * (1 - removal))
            }
            return Frame(tiles: tiles)
        default:
            let phase = eased(CGFloat((time - refillStart) / (stepDuration - refillStart)))
            let tiles = step.after.enumerated().map { index, tile in
                let origin = step.refillOrigins[index]
                // 原方块向右填补空位，新方块从滑轨左端进入。
                let start = CGFloat(origin ?? (index - step.cleared.count))
                let destination = CGFloat(index)
                return Tile(kind: tile.kind, column: start + (destination - start) * phase,
                            opacity: origin == nil ? min(1, phase * 2) : 1)
            }
            return Frame(tiles: tiles)
        }
    }

    private static func stationaryTiles(_ board: [BoardTile]) -> [Tile] {
        board.enumerated().map { Tile(kind: $0.element.kind, column: CGFloat($0.offset)) }
    }

    private static func eased(_ progress: CGFloat) -> CGFloat {
        let value = min(1, max(0, progress))
        return value * value * (3 - 2 * value)
    }
}
