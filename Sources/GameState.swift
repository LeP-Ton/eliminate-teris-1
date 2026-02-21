import Foundation

struct BoardTile: Equatable {
    let id: UUID
    let kind: PieceKind

    init(id: UUID = UUID(), kind: PieceKind) {
        self.id = id
        self.kind = kind
    }
}

final class GameState {
    let columns: Int
    private(set) var tiles: [BoardTile]
    private(set) var score: Int = 0

    init(columns: Int) {
        self.columns = columns
        self.tiles = (0..<columns).map { _ in BoardTile(kind: PieceKind.random()) }
        normalizeStart()
    }

    func attemptSwap(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
        guard leftIndex != rightIndex else { return false }
        guard abs(leftIndex - rightIndex) == 1 else { return false }
        guard leftIndex >= 0, rightIndex >= 0 else { return false }
        guard leftIndex < tiles.count, rightIndex < tiles.count else { return false }

        tiles.swapAt(leftIndex, rightIndex)
        if findMatches().isEmpty {
            tiles.swapAt(leftIndex, rightIndex)
            return false
        }

        resolveMatches()
        return true
    }

    func swapAndResolve(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
        guard leftIndex != rightIndex else { return false }
        guard abs(leftIndex - rightIndex) == 1 else { return false }
        guard leftIndex >= 0, rightIndex >= 0 else { return false }
        guard leftIndex < tiles.count, rightIndex < tiles.count else { return false }

        tiles.swapAt(leftIndex, rightIndex)
        let hasMatch = !findMatches().isEmpty
        if hasMatch {
            resolveMatches()
        }
        return hasMatch
    }

    private func normalizeStart() {
        while !findMatches().isEmpty {
            for index in findMatches() {
                tiles[index] = BoardTile(kind: PieceKind.random())
            }
        }
    }

    private func resolveMatches() {
        while true {
            let matches = findMatches()
            if matches.isEmpty {
                break
            }

            score += matches.count * 10
            refillAfterClearing(matches)
        }
    }

    private func findMatches() -> Set<Int> {
        guard !tiles.isEmpty else { return [] }

        var matches: Set<Int> = []
        var index = 0
        while index < tiles.count {
            let current = tiles[index].kind
            var next = index + 1
            while next < tiles.count, tiles[next].kind == current {
                next += 1
            }

            let length = next - index
            if length >= 3 {
                for matchIndex in index..<next {
                    matches.insert(matchIndex)
                }
            }

            index = next
        }
        return matches
    }

    private func refillAfterClearing(_ matches: Set<Int>) {
        guard !matches.isEmpty else { return }
        var remaining: [BoardTile] = []
        remaining.reserveCapacity(columns - matches.count)
        for (index, tile) in tiles.enumerated() where !matches.contains(index) {
            remaining.append(tile)
        }

        let missing = columns - remaining.count
        let leftFill = (0..<missing).map { _ in BoardTile(kind: PieceKind.random()) }
        tiles = leftFill + remaining
    }
}
