import Foundation

/// 一次实际交换的结算数据；自动补位引发的所有消除都归属同一次交换。
struct SwapResolution: Equatable {
    let isValidSwap: Bool
    let clearedCount: Int
    let cascadeCount: Int
    let longestRun: Int
    let clearedByKind: [PieceKind: Int]

    init(isValidSwap: Bool, clearedCount: Int, cascadeCount: Int, longestRun: Int,
         clearedByKind: [PieceKind: Int] = [:]) {
        self.isValidSwap = isValidSwap
        self.clearedCount = clearedCount
        self.cascadeCount = cascadeCount
        self.longestRun = longestRun
        self.clearedByKind = clearedByKind
    }

    static let invalid = SwapResolution(isValidSwap: false, clearedCount: 0, cascadeCount: 0, longestRun: 0)
}

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
    /// 本局分类计数，随新棋盘清零；成就管理器另外保存跨局累计值。
    private(set) var clearedByKind: [PieceKind: Int] = [:]
    private(set) var lastResolution: SwapResolution = .invalid
    private let nextKind: () -> PieceKind

    /// 可注入初始棋盘和补位序列，让连消等规则可以确定性验证。
    init(columns: Int, initialKinds: [PieceKind]? = nil, nextKind: @escaping () -> PieceKind = PieceKind.random) {
        precondition(columns > 0 && (initialKinds == nil || initialKinds?.count == columns))
        self.columns = columns
        self.nextKind = nextKind
        self.tiles = initialKinds?.map { BoardTile(kind: $0) } ?? (0..<columns).map { _ in BoardTile(kind: nextKind()) }
        normalizeStart()
    }

    func attemptSwap(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
        lastResolution = .invalid
        guard leftIndex != rightIndex else { return false }
        guard abs(leftIndex - rightIndex) == 1 else { return false }
        guard leftIndex >= 0, rightIndex >= 0 else { return false }
        guard leftIndex < tiles.count, rightIndex < tiles.count else { return false }

        tiles.swapAt(leftIndex, rightIndex)
        if findMatches().isEmpty {
            tiles.swapAt(leftIndex, rightIndex)
            return false
        }

        lastResolution = resolveMatches()
        return true
    }

    func swapAndResolve(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
        lastResolution = .invalid
        guard leftIndex != rightIndex else { return false }
        guard abs(leftIndex - rightIndex) == 1 else { return false }
        guard leftIndex >= 0, rightIndex >= 0 else { return false }
        guard leftIndex < tiles.count, rightIndex < tiles.count else { return false }

        tiles.swapAt(leftIndex, rightIndex)
        lastResolution = resolveMatches()
        return lastResolution.clearedCount > 0
    }

    private func normalizeStart() {
        while !findMatches().isEmpty {
            for index in findMatches() {
                tiles[index] = BoardTile(kind: nextKind())
            }
        }
    }

    private func resolveMatches() -> SwapResolution {
        var clearedCount = 0
        var cascadeCount = 0
        var longestRun = 0
        var clearedByKind: [PieceKind: Int] = [:]
        while true {
            let (matches, runLength) = matchDetails()
            if matches.isEmpty {
                break
            }

            score += matches.count * 10
            clearedCount += matches.count
            cascadeCount += 1
            longestRun = max(longestRun, runLength)
            // 补位前读取实际消除方块的类型，将每轮连锁合并到本次交换。
            for index in matches {
                clearedByKind[tiles[index].kind, default: 0] += 1
                self.clearedByKind[tiles[index].kind, default: 0] += 1
            }
            refillAfterClearing(matches)
        }
        return SwapResolution(isValidSwap: true, clearedCount: clearedCount, cascadeCount: cascadeCount,
                              longestRun: longestRun, clearedByKind: clearedByKind)
    }

    private func findMatches() -> Set<Int> {
        return matchDetails().0
    }

    private func matchDetails() -> (Set<Int>, Int) {
        var matches: Set<Int> = []
        var longestRun = 0
        var index = 0
        while index < tiles.count {
            let current = tiles[index].kind
            var next = index + 1
            while next < tiles.count, tiles[next].kind == current {
                next += 1
            }

            let length = next - index
            if length >= 3 {
                longestRun = max(longestRun, length)
                for matchIndex in index..<next {
                    matches.insert(matchIndex)
                }
            }

            index = next
        }
        return (matches, longestRun)
    }

    private func refillAfterClearing(_ matches: Set<Int>) {
        guard !matches.isEmpty else { return }
        var remaining: [BoardTile] = []
        remaining.reserveCapacity(columns - matches.count)
        for (index, tile) in tiles.enumerated() where !matches.contains(index) {
            remaining.append(tile)
        }

        let missing = columns - remaining.count
        let leftFill = (0..<missing).map { _ in BoardTile(kind: nextKind()) }
        tiles = leftFill + remaining
    }
}
