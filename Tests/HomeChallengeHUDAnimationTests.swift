import Cocoa
import XCTest
@testable import EliminateTeris1

final class HomeChallengeHUDAnimationTests: XCTestCase {
    func testRenderedIntermediateCountsMatchStaticDigitsAtTheSamePosition() throws {
        _ = NSApplication.shared
        let language = Localizer.shared.language
        defer { Localizer.shared.setLanguage(language) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let lobby = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
        lobby.layoutSubtreeIfNeeded()
        let productionSize = lobby.challengeHUD.bounds.size
        let compact = NSSize(width: 336, height: 148)
        let cases: [(mode: HomeGameMode, size: NSSize)] = [
            (.free, NSSize(width: 692, height: 196)),
            (.timed, productionSize), (.moves, productionSize),
            (.timed, compact), (.moves, compact)
        ]
        let initial: [PieceKind: Int] = [.orangeRicky: 8, .blueRicky: 4]
        let target: [PieceKind: Int] = [.orangeRicky: 11, .blueRicky: 4, .clevelandZ: 3]
        let stages: [(time: TimeInterval, counts: [PieceKind: Int])] = [
            (0.061, [.orangeRicky: 9, .blueRicky: 4, .clevelandZ: 1]),
            (0.121, [.orangeRicky: 10, .blueRicky: 4, .clevelandZ: 2]),
            (0.181, target)
        ]
        for (mode, size) in cases {
            var clock: TimeInterval = 0
            let animated = makeHUD(size: size, clock: { clock })
            let reference = makeHUD(size: size, clock: { clock }, reducesMotion: { true })
            animated.refresh(snapshot: snapshot(mode, initial), mode: mode)
            assertDisplayed(animated, initial)
            let original = try image(of: animated)
            animated.refresh(snapshot: snapshot(mode, target), mode: mode)
            assertDisplayed(animated, initial)
            XCTAssertEqual(animated.snapshot?.totalCleared, 18, "快照应立即保留实际总数")
            XCTAssertEqual(try image(of: animated), original)

            // 和相同数值的静态画面逐帧比对，覆盖位数变化时的基线及分类之和。
            for stage in stages {
                clock = stage.time
                assertDisplayed(animated, stage.counts)
                reference.refresh(snapshot: snapshot(mode, stage.counts), mode: mode)
                let frame = try image(of: animated)
                XCTAssertNotEqual(frame, original, "原生绘制应确实显示新的计数")
                XCTAssertEqual(frame, try image(of: reference), "\(mode.key)／\(size) 的数字应保持静态绘制位置")
            }
        }
    }

    func testSmallChangesAlwaysUseSixtyMillisecondBeats() {
        for increase in [3, 9] {
            var clock: TimeInterval = 0
            let hud = makeHUD(clock: { clock })
            let initial = 3
            let target = initial + increase
            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: initial]), mode: .free)
            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target]), mode: .free)
            // 每拍前后各取一帧，确认 +3 与 +9 的每一步始终相隔 60 毫秒。
            for step in 1...increase {
                let beat = Double(step) * 0.06
                clock = beat - 0.001
                assertDisplayed(hud, [.orangeRicky: initial + step - 1])
                clock = beat + 0.001
                assertDisplayed(hud, [.orangeRicky: initial + step])
            }

            let newStart = Double(increase) * 0.06 + 0.023
            clock = newStart
            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target + 1]), mode: .free)
            clock = newStart + 0.059
            assertDisplayed(hud, [.orangeRicky: target])
            clock = newStart + 0.061
            assertDisplayed(hud, [.orangeRicky: target + 1])
        }
    }

    func testBudgetAndRepeatedRefreshesDoNotRestartCounting() {
        var clock: TimeInterval = 0
        let hud = makeHUD(clock: { clock })
        hud.refresh(snapshot: snapshot(.moves, [:], movesLeft: 30), mode: .moves)
        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 29), mode: .moves)
        clock = 0.071
        assertDisplayed(hud, [.orangeRicky: 1])
        hud.refresh(snapshot: snapshot(.moves, [.orangeRicky: 3], movesLeft: 28), mode: .moves)
        XCTAssertEqual(hud.budgetText, "28")
        assertDisplayed(hud, [.orangeRicky: 1])
        clock = 0.131
        assertDisplayed(hud, [.orangeRicky: 2])

        // 最后一手的实际消除照常递增，步数和结算快照立即更新。
        let finished: [PieceKind: Int] = [.orangeRicky: 3, .blueRicky: 3]
        hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
        XCTAssertEqual(hud.budgetText, "0")
        XCTAssertEqual(hud.snapshot?.totalCleared, 6)
        clock = 0.181
        assertDisplayed(hud, [.orangeRicky: 3, .blueRicky: 1])
        clock = 0.301
        hud.refresh(snapshot: snapshot(.moves, finished, movesLeft: 0, finished: true), mode: .moves)
        assertDisplayed(hud, finished)

        hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 59), mode: .timed)
        hud.refresh(snapshot: snapshot(.timed, [:], timeLeft: 58), mode: .timed)
        XCTAssertEqual(hud.budgetText, "00:58")
        assertDisplayed(hud, [:])
    }

    func testRapidGrowthKeepsTheSameBeatForExistingAndNewKinds() {
        var clock: TimeInterval = 0
        let hud = makeHUD(clock: { clock })
        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 8, .blueRicky: 4]), mode: .free)
        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 11, .blueRicky: 7]), mode: .free)
        clock = 0.081
        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7]), mode: .free)
        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
        clock = 0.119
        assertDisplayed(hud, [.orangeRicky: 9, .blueRicky: 5])
        clock = 0.121
        assertDisplayed(hud, [.orangeRicky: 10, .blueRicky: 6])
        clock = 0.149
        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 14, .blueRicky: 7, .clevelandZ: 3]), mode: .free)
        clock = 0.179
        assertDisplayed(hud, [.orangeRicky: 10, .blueRicky: 6])
        clock = 0.181
        assertDisplayed(hud, [.orangeRicky: 11, .blueRicky: 7, .clevelandZ: 1])
        clock = 0.301
        assertDisplayed(hud, [.orangeRicky: 13, .blueRicky: 7, .clevelandZ: 3])
        clock = 0.361
        assertDisplayed(hud, [.orangeRicky: 14, .blueRicky: 7, .clevelandZ: 3])
    }

    func testLargeChangesDistributeTheRemainderAndSettleInTenBeats() {
        let expectedForTwelve = [0, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12]
        let largest = Int.max
        let expectedForLargest = (0...10).map { step in
            (largest / 10) * step + ((largest % 10) * step + 9) / 10
        }
        for (target, steps) in [(12, expectedForTwelve), (largest, expectedForLargest)] {
            var clock: TimeInterval = 0
            let hud = makeHUD(clock: { clock })
            hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
            hud.refresh(snapshot: snapshot(.free, [.orangeRicky: target]), mode: .free)
            // 大数量按拍追赶，确认第 10 拍前仍有余量，且极值计算不丢位。
            for step in 1...10 {
                let beat = Double(step) * 0.06
                clock = beat - 0.001
                assertDisplayed(hud, [.orangeRicky: steps[step - 1]])
                clock = beat + 0.001
                assertDisplayed(hud, [.orangeRicky: steps[step]])
            }
        }
    }

    func testResetsModeChangesAndReducedMotionImmediatelyDisplayCurrentCounts() {
        var clock: TimeInterval = 0
        var reducedMotion = false
        let hud = makeHUD(clock: { clock }, reducesMotion: { reducedMotion })
        hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
        hud.refresh(snapshot: snapshot(.free, [.orangeRicky: 3]), mode: .free)
        clock = 0.071
        assertDisplayed(hud, [.orangeRicky: 1])
        hud.refresh(snapshot: snapshot(.free, [:], running: false), mode: .free)
        assertDisplayed(hud, [:])

        hud.refresh(snapshot: snapshot(.free, [:]), mode: .free)
        hud.refresh(snapshot: snapshot(.free, [.blueRicky: 3]), mode: .free)
        clock = 0.142
        assertDisplayed(hud, [.blueRicky: 1])
        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 9]), mode: .timed)
        assertDisplayed(hud, [.blueRicky: 9])

        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 12]), mode: .timed)
        clock = 0.213
        assertDisplayed(hud, [.blueRicky: 10])
        reducedMotion = true
        assertDisplayed(hud, [.blueRicky: 12])
        hud.refresh(snapshot: snapshot(.timed, [.blueRicky: 15]), mode: .timed)
        assertDisplayed(hud, [.blueRicky: 15])
        reducedMotion = false
        assertDisplayed(hud, [.blueRicky: 15])
    }

    private func snapshot(_ mode: HomeGameMode, _ counts: [PieceKind: Int], movesLeft: Int? = nil,
                          timeLeft: TimeInterval? = nil, running: Bool = true, finished: Bool = false) -> GameSnapshot {
        GameSnapshot(mode: mode.gameMode, elapsedTime: 0, remainingTime: timeLeft, remainingSwaps: movesLeft,
                     isRunning: running && !finished, isFinished: finished, clearedByKind: counts)
    }

    private func makeHUD(size: NSSize = NSSize(width: 692, height: 196), clock: @escaping () -> TimeInterval,
                         reducesMotion: @escaping () -> Bool = { false }) -> HomeChallengeHUDView {
        HomeChallengeHUDView(frame: NSRect(origin: .zero, size: size), clock: clock, reducesMotion: reducesMotion)
    }

    private func assertDisplayed(_ hud: HomeChallengeHUDView, _ expected: [PieceKind: Int],
                                 file: StaticString = #filePath, line: UInt = #line) {
        let allKinds = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { ($0, expected[$0, default: 0]) })
        XCTAssertEqual(hud.displayedCounts(), allKinds, file: file, line: line)
    }

    private func image(of hud: HomeChallengeHUDView) throws -> Data {
        hud.needsDisplay = true
        let bitmap = try XCTUnwrap(hud.bitmapImageRepForCachingDisplay(in: hud.bounds))
        hud.cacheDisplay(in: hud.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
