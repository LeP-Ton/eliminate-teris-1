import XCTest
@testable import EliminateTeris1

/// 每条用例使用独立存储域，不读取或修改玩家的真实成就。
class AchievementTestCase: XCTestCase {
    var defaults: UserDefaults!
    var suite: String!
    var manager: AchievementsManager!
    var round: UUID!
    let date = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        suite = "EliminateTeris1Tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        manager = AchievementsManager(defaults: defaults)
        round = UUID()
        manager.beginRound(id: round)
    }

    override func tearDown() {
        manager = nil
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func progress(_ id: Int) -> Double {
        manager.progress(for: AchievementDefinition.all.first { $0.id == id }!).current
    }

    func swap(at seconds: Double = 0, count: Int = 3, waves: Int = 1, longest: Int = 3, score: Int = 30, id: UUID = UUID()) {
        manager.recordSwap(roundID: round, swapID: id,
                           result: SwapResolution(isValidSwap: true, clearedCount: count, cascadeCount: waves, longestRun: longest),
                           score: score, at: date.addingTimeInterval(seconds))
    }

    func newRound() {
        round = UUID()
        manager.beginRound(id: round)
    }
}

final class AchievementsTests: AchievementTestCase {
    func testAllDefinitionsHaveStableIDs() {
        XCTAssertEqual(AchievementDefinition.all.map(\.id), Array(1...20))
        XCTAssertEqual(AchievementCategory.allCases.map { c in AchievementDefinition.all.filter { $0.category == c }.count }, [4, 5, 7, 4])
    }

    func testOneSwapUnlocksEveryReachedMilestoneAndPersistsBeforeNotification() {
        var batches: [[Int]] = []
        let observer = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: nil, queue: nil) { [self] note in
            guard note.object as? AchievementsManager === manager else { return }
            let ids = note.userInfo?["ids"] as! [Int]
            batches.append(ids)
            let reloaded = AchievementsManager(defaults: defaults)
            XCTAssertTrue(ids.allSatisfy { reloaded.isUnlocked(id: $0) })
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        swap(count: 10_000, waves: 3, longest: 5, score: 100_000)
        XCTAssertEqual(batches, [[1, 4, 5, 6, 7, 8, 17, 18, 19]])
        XCTAssertEqual(manager.unlockDate(id: 19), date)
        swap(at: 1)
        XCTAssertEqual(batches.count, 1)
    }

    func testDuplicateAndInvalidSwapEventsDoNotCount() {
        let id = UUID()
        swap(id: id)
        swap(id: id)
        manager.recordSwap(roundID: UUID(), swapID: UUID(), result: .invalid, score: 1000, at: date)
        manager.recordSwap(roundID: round, swapID: UUID(), result: .invalid, score: 1000, at: date)
        XCTAssertEqual(progress(17), 3)
        XCTAssertFalse(manager.isUnlocked(id: 1))
    }

    func testRhythmIncludesExactBoundary() {
        swap()
        swap(at: 1.6)
        swap(at: 3.2)
        XCTAssertTrue(manager.isUnlocked(id: 2))
    }

    func testRhythmExpiresWhileSuccessfulSwapStreakHasNoTimeout() {
        for i in 0..<5 { swap(at: Double(i) * 1.601) }
        XCTAssertFalse(manager.isUnlocked(id: 2))
        XCTAssertTrue(manager.isUnlocked(id: 9))
    }

    func testNonClearingSwapBreaksBothStreaks() {
        swap()
        swap(at: 0.1)
        swap(at: 0.2, count: 0, waves: 0, longest: 0)
        swap(at: 0.3)
        swap(at: 0.4)
        XCTAssertFalse(manager.isUnlocked(id: 2))
        XCTAssertEqual(progress(9), 2)
    }

    func testRestartClearsStreakButRetainsLifetimeProgress() {
        swap()
        swap(at: 0.1)
        newRound()
        swap(at: 0.2)
        swap(at: 0.3)
        XCTAssertFalse(manager.isUnlocked(id: 2))
        XCTAssertEqual(progress(17), 12)
        XCTAssertEqual(progress(9), 2)
    }

    func testFinishIsIdempotentAndDoesNotRequireRankingEntry() {
        // 排行、seed 和是否进入前九名都不是成就事件的输入。
        defaults.set(["seed": true], forKey: "mode_records_v1")
        for _ in 0..<20 {
            newRound()
            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 60, at: date)
            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 61, at: date)
        }
        XCTAssertEqual(progress(20), 20)
        XCTAssertTrue(manager.isUnlocked(id: 20))
    }

    func testZeroScoreAndPrematureFinishesDoNotCount() {
        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 59.99, at: date)
        XCTAssertEqual(progress(20), 0)
        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 0, elapsed: 60, at: date)
        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 61, at: date)
        XCTAssertEqual(progress(20), 0)
        newRound()
        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 290, elapsed: 10, at: date)
        manager.finishRound(id: round, mode: .free, score: 1000, elapsed: 100, at: date)
        XCTAssertEqual(progress(20), 0)
    }

    func testEachScoreAttackTierRequiresItsOwnFinishedRound() {
        for (minutes, id) in [(1, 10), (2, 11), (3, 12)] {
            newRound()
            swap(score: minutes * 300)
            XCTAssertFalse(manager.isUnlocked(id: id))
            manager.finishRound(id: round, mode: .scoreAttack(duration: Double(minutes * 60)), score: minutes * 300, elapsed: Double(minutes * 60), at: date)
            XCTAssertTrue(manager.isUnlocked(id: id))
        }
    }

    func testSpeedRunTiersAndSixtySecondBoundary() {
        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 60.001, at: date)
        XCTAssertTrue(manager.isUnlocked(id: 13))
        XCTAssertFalse(manager.isUnlocked(id: 16))
        newRound()
        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 330, elapsed: 60, at: date)
        XCTAssertTrue(manager.isUnlocked(id: 16))
        for (target, id) in [(600, 14), (900, 15)] {
            newRound()
            manager.finishRound(id: round, mode: .speedRun(targetScore: target), score: target, elapsed: 90, at: date)
            XCTAssertTrue(manager.isUnlocked(id: id))
        }
        let best = AchievementDefinition.all.first { $0.id == 16 }!
        XCTAssertEqual(manager.progress(for: best).current, 60)
    }

    func testReloadRetainsMetricsAndTimeButStartsNewStreak() {
        swap()
        swap(at: 0.1)
        let unlockDate = manager.unlockDate(id: 4)
        manager = AchievementsManager(defaults: defaults)
        manager.beginRound(id: round)
        swap(at: 0.2)
        XCTAssertFalse(manager.isUnlocked(id: 2))
        XCTAssertEqual(progress(17), 9)
        XCTAssertEqual(manager.unlockDate(id: 4), unlockDate)
    }

    func testOnlyLegacyOneToThreeMigrateAndMigrationIsOneTime() {
        defaults.removeObject(forKey: AchievementsManager.storageKey)
        defaults.set([1, 2, 3, 4, 20], forKey: "AchievementsManager.unlockedIds")
        defaults.set(["1": date.timeIntervalSince1970, "4": date.timeIntervalSince1970], forKey: "AchievementsManager.unlockTimestamps")
        manager = AchievementsManager(defaults: defaults)
        XCTAssertEqual(manager.unlockedIDs(), [1, 2, 3])
        XCTAssertEqual(manager.unlockDate(id: 1), date)
        XCTAssertEqual(progress(17), 0)
        defaults.set([], forKey: "AchievementsManager.unlockedIds")
        manager = AchievementsManager(defaults: defaults)
        XCTAssertEqual(manager.unlockedIDs(), [1, 2, 3])
    }

    func testDamagedFieldsPreserveReadableMetrics() {
        defaults.set(["unlocked": [1, 99], "metrics": ["totalCleared": 99, "bestScore": "broken", "rhythm": -1, "cascades": true], "timestamps": "broken"], forKey: AchievementsManager.storageKey)
        manager = AchievementsManager(defaults: defaults)
        manager.beginRound(id: round)
        XCTAssertEqual(manager.unlockedIDs(), [1])
        XCTAssertEqual(progress(17), 99)
        XCTAssertEqual(progress(8), 0)
        swap()
        XCTAssertTrue(manager.isUnlocked(id: 17))
    }

    func testUnlockQueueOrdersDeduplicatesAndCombinesLargeBatches() {
        var queue = AchievementUnlockQueue()
        queue.enqueue([8, 1, 3, 3])
        XCTAssertEqual(queue.next(), [1])
        XCTAssertEqual(queue.next(), [3])
        XCTAssertEqual(queue.next(), [8])
        XCTAssertEqual(queue.next(), [])
        queue.enqueue([9, 2])
        queue.enqueue([6, 4, 2])
        XCTAssertEqual(queue.next(), [2, 4, 6, 9])
    }

    func testObjectFilteredNotificationReachesTheInterface() {
        var received = false
        let observer = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: manager, queue: .main) { _ in received = true }
        defer { NotificationCenter.default.removeObserver(observer) }
        swap()
        XCTAssertTrue(received)
    }

    func testZeroSecondSpeedRunIsDistinguishedFromMissingResult() {
        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 0, at: date)
        XCTAssertTrue(manager.isUnlocked(id: 16))
        manager = AchievementsManager(defaults: defaults)
        let definition = AchievementDefinition.all.first { $0.id == 16 }!
        XCTAssertTrue(manager.hasTimedResult(for: definition))
        XCTAssertEqual(manager.progress(for: definition).current, 0)
    }
}
