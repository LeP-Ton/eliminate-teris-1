import XCTest
@testable import EliminateTeris1

final class GameBoardControllerTests: AchievementTestCase {
    func testLastSwapIsRecordedBeforeFinishAndRepeatedSnapshotsDoNotCount() {
        var now = date
        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
        let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
        let controller = GameBoardController(columns: 4, achievements: manager, now: { now }) { _ in
            var index = 0
            let refill = [b, b, b, c, c, c, d, a, b, a]
            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
                defer { index += 1 }
                return refill[index]
            }
        }
        controller.configure(mode: .speedRun(targetScore: 100))
        controller.startRound()
        now = date.addingTimeInterval(2)
        controller.performSwap(from: 2, to: 3)
        XCTAssertTrue(manager.isUnlocked(id: 1))
        XCTAssertTrue(manager.isUnlocked(id: 3))
        XCTAssertTrue(manager.isUnlocked(id: 8))
        for _ in 0..<10 { _ = controller.snapshot(); controller.tick() }
        XCTAssertEqual(progress(20), 1)
        XCTAssertEqual(progress(17), 10)
        XCTAssertEqual(manager.totalCleared(for: a), 3)
        XCTAssertEqual(manager.totalCleared(for: b), 4)
        XCTAssertEqual(manager.totalCleared(for: c), 3)
        XCTAssertEqual(manager.totalCleared(for: d), 0)
        controller.performSwap(from: 0, to: 1)
        XCTAssertEqual(progress(17), 10)
    }

    func testRestartAndModeChangeDoNotFinishAbandonedRounds() {
        let controller = GameBoardController(columns: 4, achievements: manager, now: { self.date })
        controller.configure(mode: .scoreAttack(duration: 60))
        controller.startRound()
        controller.startRound()
        controller.configure(mode: .free)
        XCTAssertEqual(progress(20), 0)
        XCTAssertFalse(manager.isUnlocked(id: 3))
    }

    func testExpirationRefusesLateSwapAndZeroScoreDoesNotCount() {
        var now = date
        let controller = GameBoardController(columns: 4, achievements: manager, now: { now })
        controller.configure(mode: .scoreAttack(duration: 60))
        controller.startRound()
        let original = controller.tiles()
        now = date.addingTimeInterval(60)
        controller.performSwap(from: 0, to: 1)
        XCTAssertEqual(controller.tiles(), original)
        XCTAssertTrue(controller.snapshot().isFinished)
        XCTAssertEqual(progress(20), 0)
        XCTAssertEqual(progress(17), 0)
    }

    func testFreeModeTracksClearsWithoutCompletedRounds() {
        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
        let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
        let controller = GameBoardController(columns: 4, achievements: manager, stateFactory: { _ in
            var index = 0
            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
                defer { index += 1 }
                return [c, d, c][index]
            }
        })
        controller.performSwap(from: 2, to: 3)
        XCTAssertTrue(manager.isUnlocked(id: 4))
        XCTAssertEqual(progress(20), 0)
    }
}
