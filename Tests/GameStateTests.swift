import XCTest
@testable import EliminateTeris1

final class GameStateTests: XCTestCase {
    private let a = PieceKind.orangeRicky
    private let b = PieceKind.blueRicky
    private let c = PieceKind.clevelandZ
    private let d = PieceKind.rhodeIslandZ

    func state(_ board: [PieceKind], refill: [PieceKind]) -> GameState {
        var index = 0
        return GameState(columns: board.count, initialKinds: board) {
            XCTAssertLessThan(index, refill.count, "补位次数超出预期，可能出现额外连消")
            defer { index += 1 }
            return refill[index % refill.count]
        }
    }

    func testSingleTripleAndScore() {
        let game = state([a, a, b, a], refill: [c, d, c])
        XCTAssertTrue(game.swapAndResolve(2, 3))
        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 3, cascadeCount: 1, longestRun: 3))
        XCTAssertEqual(game.score, 30)
        XCTAssertEqual(game.tiles.map(\.kind), [c, d, c, b])
    }

    func testTwoTriplesInSameWaveAreNotFourOrFiveInARow() {
        let game = state([b, b, a, b, a, a, c, d], refill: [a, b, c, d, a, b])
        XCTAssertTrue(game.swapAndResolve(2, 3))
        XCTAssertEqual(game.lastResolution.clearedCount, 6)
        XCTAssertEqual(game.lastResolution.cascadeCount, 1)
        XCTAssertEqual(game.lastResolution.longestRun, 3)
    }

    func testRefillCanMakeFiveInARow() {
        let game = state([c, c, a, a, b, a], refill: [c, c, c, a, b, c, d, a])
        XCTAssertTrue(game.swapAndResolve(4, 5))
        XCTAssertEqual(game.lastResolution.clearedCount, 8)
        XCTAssertEqual(game.lastResolution.cascadeCount, 2)
        XCTAssertEqual(game.lastResolution.longestRun, 5)
        XCTAssertEqual(game.score, 80)
    }

    func testThreeCascadesIncludeTheInitialWave() {
        let game = state([a, a, b, a], refill: [b, b, b, c, c, c, d, a, b, a])
        XCTAssertTrue(game.swapAndResolve(2, 3))
        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 10, cascadeCount: 3, longestRun: 4))
        XCTAssertEqual(game.score, 100)
    }

    func testNonClearingSwapRemainsOnBoardWhileAttemptSwapRollsBack() {
        let game = state([a, b, c, d], refill: [a])
        XCTAssertFalse(game.swapAndResolve(0, 1))
        XCTAssertTrue(game.lastResolution.isValidSwap)
        XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
        XCTAssertFalse(game.attemptSwap(0, 1))
        XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
        XCTAssertFalse(game.swapAndResolve(-1, 0))
        XCTAssertEqual(game.lastResolution, .invalid)
    }
}
