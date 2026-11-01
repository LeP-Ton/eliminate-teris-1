import Cocoa
import XCTest
@testable import EliminateTeris1

/// 新规则以真实交换和消除事件验证，测试记录与玩家存档隔离。
final class ChallengeRulesTests: AchievementTestCase {
    private var now = Date(timeIntervalSince1970: 1_000_000)

    private func board(cascade: Bool = false) -> GameBoardController {
        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky, c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
        return GameBoardController(columns: 4, achievements: manager, now: { self.now }) { _ in
            var index = 0
            let fill = cascade ? Array(repeating: a, count: 27) + [c, d, c] : [c, d, c]
            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
                defer { index += 1 }
                return fill[index % fill.count]
            }
        }
    }

    func testOnlyRealLegalSwapsConsumeMovesAndRefreshNeverResetsThem() {
        let board = board()
        board.configure(mode: .moves(limit: 30)); board.startRound()
        board.handleTap(at: 0); board.handleTap(at: 0)
        board.performSwap(from: -1, to: 0); board.performSwap(from: 0, to: 0); board.performSwap(from: 0, to: 2)
        XCTAssertFalse(board.lock(-1))
        XCTAssertEqual(board.snapshot().swapsUsed, 0)
        XCTAssertTrue(board.lock(1))
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.snapshot().remainingSwaps, 30)
        board.unlock(1)
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        XCTAssertEqual(board.snapshot().remainingSwaps, 29, "不消除的合法交换也扣一次")
        _ = board.consumeLastSwapPair()
        for _ in 0..<5 { _ = board.snapshot(); board.tick() }
        XCTAssertEqual(board.snapshot().remainingSwaps, 29, "动画和界面读取不能重置计次")
        now = now.addingTimeInterval(86_400)
        board.tick()
        XCTAssertTrue(board.snapshot().isRunning, "限步挑战没有思考时间限制")
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 3)
        XCTAssertEqual(board.snapshot().remainingSwaps, 28)
    }

    func testThirtiethSwapResolvesEveryCascadeThenRefusesThirtyFirst() {
        let board = board(cascade: true)
        board.configure(mode: .moves(limit: 30)); board.startRound()
        for _ in 0..<29 { board.performSwap(from: 0, to: 1) }
        XCTAssertFalse(board.snapshot().isFinished)
        XCTAssertEqual(board.snapshot().remainingSwaps, 1)
        board.performSwap(from: 2, to: 3)
        let final = board.snapshot()
        XCTAssertTrue(final.isFinished)
        XCTAssertEqual(final.swapsUsed, 30)
        XCTAssertEqual(final.remainingSwaps, 0)
        XCTAssertEqual(final.totalCleared, 30, "最后一次交换触发的十轮连锁都应计入")
        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 30)
        XCTAssertTrue(manager.isUnlocked(id: 13))
        XCTAssertTrue(manager.isUnlocked(id: 14))
        let tiles = board.tiles()
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.tiles(), tiles)
        XCTAssertEqual(board.snapshot().swapsUsed, 30)
    }

    func testTimedModeEndsAtSixtySecondsAndRejectsLateActions() {
        let board = board()
        board.configure(mode: .timed(duration: 60)); board.startRound()
        now = date.addingTimeInterval(59.999)
        board.performSwap(from: 2, to: 3)
        XCTAssertEqual(board.snapshot().totalCleared, 3)
        now = date.addingTimeInterval(60)
        board.tick()
        XCTAssertTrue(board.snapshot().isFinished)
        XCTAssertEqual(board.snapshot().remainingTime, 0)
        let used = board.snapshot().swapsUsed
        board.performSwap(from: 0, to: 1)
        XCTAssertEqual(board.snapshot().swapsUsed, used)
    }

    func testRestartAtDeadlineSavesCompletedRoundBeforePreparingNewBoard() {
        _ = NSApplication.shared
        let board = board()
        let records = ModeRecordStore(defaults: defaults)
        let controller = GameViewController(achievements: manager, records: records, board: board, audioEnabled: false)
        _ = controller.view
        controller.selectMode(.timed)
        controller.startSequence.reducesMotion = { true }
        controller.startRound()
        board.performSwap(from: 2, to: 3)
        now = date.addingTimeInterval(60)
        // 不先触发 tick，直接按开始；刚结束的旧局仍必须保存一次。
        controller.startRound()
        XCTAssertEqual(records.records(for: .timed, detailValue: 60).map(\.clearedCount), [3])
        XCTAssertTrue(board.snapshot().isRunning)
        XCTAssertEqual(board.snapshot().totalCleared, 0)
        XCTAssertEqual(board.snapshot().remainingTime, 60)
    }

    func testCountRankingSharesPlacesAndNeverUsesElapsedTimeAsTieBreaker() throws {
        let records = ModeRecordStore(defaults: defaults)
        let fast = try XCTUnwrap(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 90, swapsUsed: 30, elapsedTime: 5))
        let slow = try XCTUnwrap(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 90, swapsUsed: 30, elapsedTime: 500))
        _ = records.addRecord(mode: .moves, detailValue: 30, clearedCount: 80, swapsUsed: 30, elapsedTime: 1)
        let entries = records.records(for: .moves, detailValue: 30)
        XCTAssertEqual(entries.map(\.clearedCount), [90, 90, 80])
        XCTAssertEqual(ModeRecordStore.ranks(for: entries), [1, 1, 3])
        XCTAssertTrue(entries.contains { $0.id == fast.id })
        XCTAssertTrue(entries.contains { $0.id == slow.id })
        let reloaded = ModeRecordStore(defaults: defaults)
        XCTAssertEqual(ModeRecordStore.ranks(for: reloaded.records(for: .moves, detailValue: 30)), [1, 1, 3])
    }

    func testLegacyRecordsRemainByteIdenticalAndNeverPopulateNewBoards() throws {
        let legacy = LegacyModeRecord(id: "real-legacy", score: 450, elapsedTime: 60, durationMinutes: 1, targetScore: nil, createdAt: 100)
        let bytes = try JSONEncoder().encode(["score_attack_1": [legacy]])
        defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
        let records = ModeRecordStore(defaults: defaults)
        XCTAssertTrue(records.records(for: .timed, detailValue: 60).isEmpty)
        XCTAssertEqual(records.legacySections().first?.entries.first?.score, 450)
        _ = records.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
        XCTAssertEqual(defaults.data(forKey: ModeRecordStore.legacyStorageKey), bytes)
        let reloaded = ModeRecordStore(defaults: defaults)
        XCTAssertEqual(reloaded.records(for: .timed, detailValue: 60).map(\.clearedCount), [12])
        XCTAssertEqual(reloaded.legacySections().first?.entries.first?.score, 450)
    }

    func testRecordsRequireCompletedRulesAndAcceptRealZeroClearResults() {
        let records = ModeRecordStore(defaults: defaults)
        XCTAssertNil(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 10, swapsUsed: 29, elapsedTime: 1000))
        XCTAssertNil(records.addRecord(mode: .timed, detailValue: 60, clearedCount: 10, swapsUsed: 4, elapsedTime: 59.99))
        XCTAssertNotNil(records.addRecord(mode: .timed, detailValue: 60, clearedCount: 0, swapsUsed: 0, elapsedTime: 60))
        XCTAssertNotNil(records.addRecord(mode: .moves, detailValue: 30, clearedCount: 0, swapsUsed: 30, elapsedTime: 0))
        XCTAssertEqual(records.records(for: .moves, detailValue: 30).first?.clearedCount, 0)
    }
}
