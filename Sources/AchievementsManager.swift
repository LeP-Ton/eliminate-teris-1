import Foundation
import CoreFoundation

enum AchievementCategory: String, CaseIterable {
    case beginner, skill, mode, lifetime
}

enum AchievementGoal {
    case bestCleared(Int), rhythm(Int), completedRounds(Int), firstClear
    case longestRun(Int), cascades(Int), successfulSwaps(Int)
    case timedClears(seconds: Int, count: Int)
    case moveClears(limit: Int, count: Int)
    case completedMode(mode: ModeRecordKey, ruleValue: Int)
    case totalCleared(Int)
    case pieceCleared(kind: PieceKind, count: Int)
}

struct AchievementDefinition {
    let id: Int
    let category: AchievementCategory
    let goal: AchievementGoal

    var titleKey: String { "achievement.\(id).title" }
    var descriptionKey: String { "achievement.\(id).desc" }

    static let all: [AchievementDefinition] = [
        .init(id: 1, category: .beginner, goal: .bestCleared(10)),
        .init(id: 2, category: .beginner, goal: .rhythm(3)),
        .init(id: 3, category: .beginner, goal: .completedRounds(1)),
        .init(id: 4, category: .beginner, goal: .firstClear),
        .init(id: 5, category: .skill, goal: .longestRun(4)),
        .init(id: 6, category: .skill, goal: .longestRun(5)),
        .init(id: 7, category: .skill, goal: .cascades(2)),
        .init(id: 8, category: .skill, goal: .cascades(3)),
        .init(id: 9, category: .skill, goal: .successfulSwaps(5)),
        .init(id: 10, category: .mode, goal: .timedClears(seconds: 60, count: 30)),
        .init(id: 11, category: .mode, goal: .timedClears(seconds: 60, count: 60)),
        .init(id: 12, category: .mode, goal: .timedClears(seconds: 60, count: 90)),
        .init(id: 13, category: .mode, goal: .completedMode(mode: .moves, ruleValue: 30)),
        .init(id: 14, category: .mode, goal: .moveClears(limit: 30, count: 30)),
        .init(id: 15, category: .mode, goal: .moveClears(limit: 30, count: 60)),
        .init(id: 16, category: .mode, goal: .completedMode(mode: .timed, ruleValue: 60)),
        .init(id: 17, category: .lifetime, goal: .totalCleared(100)),
        .init(id: 18, category: .lifetime, goal: .totalCleared(1_000)),
        .init(id: 19, category: .lifetime, goal: .totalCleared(10_000)),
        .init(id: 20, category: .lifetime, goal: .completedRounds(20)),
        // 按稳定编号追加，旧成就及其解锁时间不变。
        .init(id: 21, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 100)),
        .init(id: 22, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 1_000)),
        .init(id: 23, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 10_000)),
        .init(id: 24, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 100)),
        .init(id: 25, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 1_000)),
        .init(id: 26, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 10_000)),
        .init(id: 27, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 100)),
        .init(id: 28, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 1_000)),
        .init(id: 29, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 10_000)),
        .init(id: 30, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 100)),
        .init(id: 31, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 1_000)),
        .init(id: 32, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 10_000))
    ]
}

struct AchievementProgress {
    let current: Double
    let target: Double

    var fraction: Double {
        return min(1, current / target)
    }
}

/// 只消费控制器提交的真实事件，不读取排行或界面快照。
/// 游戏在主线程运行；写入和通知均在事件处理线程同步完成。
final class AchievementsManager {
    static let shared = AchievementsManager()
    static let didUnlockNotification = Notification.Name("com.eliminateteris1.achievements.didUnlock")
    static let didChangeNotification = Notification.Name("com.eliminateteris1.achievements.didChange")
    static let storageKey = "AchievementsManager.state.v1"

    private let defaults: UserDefaults
    private var unlocked: Set<Int> = []
    private var timestamps: [String: Double] = [:]
    // 仅持久化累计值与历史最佳；跨局节奏和连续交换状态不会被恢复。
    private var metrics: [String: Double] = [:]
    private var roundID: UUID?
    private var processedSwaps: Set<UUID> = []
    private var roundFinished = false
    private var rhythm = 0
    private var successfulSwaps = 0
    private var lastClearDate: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isUnlocked(id: Int) -> Bool { unlocked.contains(id) }
    func unlockedIDs() -> [Int] { unlocked.sorted() }
    func unlockDate(id: Int) -> Date? { timestamps[String(id)].map(Date.init(timeIntervalSince1970:)) }

    /// 分类计数与原有累计值共用存档；旧数据缺少分类明细时返回 0，不推测历史分布。
    func totalCleared(for kind: PieceKind) -> Double {
        metrics["pieceCleared.\(kind.rawValue)", default: 0]
    }

    func beginRound(id: UUID) {
        guard roundID != id else { return }
        roundID = id
        processedSwaps.removeAll()
        roundFinished = false
        rhythm = 0
        successfulSwaps = 0
        lastClearDate = nil
    }

    func recordSwap(roundID: UUID, swapID: UUID, result: SwapResolution, roundCleared: Int, at date: Date) {
        guard self.roundID == roundID, !roundFinished, result.isValidSwap,
              processedSwaps.insert(swapID).inserted else { return }

        if result.clearedCount > 0 {
            let interval = lastClearDate.map { date.timeIntervalSince($0) }
            // 浮点时间在精确 1.6 秒处可能出现微小误差。
            rhythm = interval.map { $0 >= 0 && $0 <= 1.600001 } == true ? rhythm + 1 : 1
            successfulSwaps += 1
            lastClearDate = date
            metrics["totalCleared", default: 0] += Double(result.clearedCount)
            for (kind, count) in result.clearedByKind where count > 0 {
                metrics["pieceCleared.\(kind.rawValue)", default: 0] += Double(count)
            }
            updateBest("rhythm", Double(rhythm))
            updateBest("successfulSwaps", Double(successfulSwaps))
        } else {
            rhythm = 0
            successfulSwaps = 0
            lastClearDate = nil
        }
        updateBest("bestRoundCleared", Double(roundCleared))
        updateBest("longestRun", Double(result.longestRun))
        updateBest("cascades", Double(result.cascadeCount))
        saveAndEvaluate(at: date)
    }

    func finishRound(id: UUID, mode: GameMode, clearedCount: Int, swapsUsed: Int, elapsed: TimeInterval, at date: Date) {
        guard roundID == id, !roundFinished, elapsed.isFinite, elapsed >= 0 else { return }
        switch mode {
        case .free:
            return
        case .timed(let duration):
            guard duration > 0, elapsed >= duration else { return }
            roundFinished = true
            guard clearedCount > 0 else { return }
            updateBest("timedCleared.\(Int(duration))", Double(clearedCount))
            metrics["completedMode.timed.\(Int(duration))"] = 1
        case .moves(let limit):
            guard limit > 0, swapsUsed >= limit else { return }
            roundFinished = true
            guard clearedCount > 0 else { return }
            updateBest("movesCleared.\(limit)", Double(clearedCount))
            metrics["completedMode.moves.\(limit)"] = 1
        }
        metrics["completedRounds", default: 0] += 1
        saveAndEvaluate(at: date)
    }

    func progress(for definition: AchievementDefinition) -> AchievementProgress {
        func value(_ key: String, _ target: Double) -> AchievementProgress {
            .init(current: metrics[key, default: 0], target: target)
        }
        switch definition.goal {
        case .bestCleared(let target): return value("bestRoundCleared", Double(target))
        case .rhythm(let target): return value("rhythm", Double(target))
        case .completedRounds(let target): return value("completedRounds", Double(target))
        case .firstClear: return .init(current: metrics["totalCleared", default: 0] > 0 ? 1 : 0, target: 1)
        case .longestRun(let target): return value("longestRun", Double(target))
        case .cascades(let target): return value("cascades", Double(target))
        case .successfulSwaps(let target): return value("successfulSwaps", Double(target))
        case .timedClears(let seconds, let count): return value("timedCleared.\(seconds)", Double(count))
        case .moveClears(let limit, let count): return value("movesCleared.\(limit)", Double(count))
        case .completedMode(let mode, let rule): return value("completedMode.\(mode.rawValue).\(rule)", 1)
        case .totalCleared(let target): return value("totalCleared", Double(target))
        case .pieceCleared(let kind, let count): return value("pieceCleared.\(kind.rawValue)", Double(count))
        }
    }

    private func updateBest(_ key: String, _ value: Double) {
        metrics[key] = max(metrics[key, default: 0], value)
    }

    private func saveAndEvaluate(at date: Date) {
        var newIDs: [Int] = []
        for definition in AchievementDefinition.all where !isUnlocked(id: definition.id) {
            let progress = progress(for: definition)
            let reached = progress.current >= progress.target
            if reached {
                unlocked.insert(definition.id)
                timestamps[String(definition.id)] = date.timeIntervalSince1970
                newIDs.append(definition.id)
            }
        }
        save()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        if !newIDs.isEmpty {
            NotificationCenter.default.post(name: Self.didUnlockNotification, object: self, userInfo: ["ids": newIDs])
        }
    }

    private func load() {
        let validIDs = Set(AchievementDefinition.all.map(\.id))
        if let stored = defaults.dictionary(forKey: Self.storageKey) {
            unlocked = Set((stored["unlocked"] as? [Int] ?? []).filter { validIDs.contains($0) })
            // 分字段读取，避免一个损坏字段导致整份进度丢失。
            metrics = readNumbers(stored["metrics"])
            timestamps = readNumbers(stored["timestamps"])
            // 总累计与解锁状态原样保留；旧分数只转换为可确定的单局消除数。
            // 新模式的历史最佳使用新键，避免将旧规则结果冒充新挑战成绩。
            if (stored["version"] as? Int ?? 1) < 2 {
                metrics["bestRoundCleared"] = max(metrics["bestRoundCleared", default: 0], floor(metrics["bestScore", default: 0] / 10))
            }
        } else {
            // 旧版 4...20 为无真实定义的占位，不能迁移成新成就。
            unlocked = Set((defaults.array(forKey: "AchievementsManager.unlockedIds") as? [Int] ?? []).filter { (1...3).contains($0) })
            let oldTimes = readNumbers(defaults.dictionary(forKey: "AchievementsManager.unlockTimestamps"))
            timestamps = oldTimes.filter { unlocked.contains(Int($0.key) ?? -1) }
        }
        save()
    }

    private func readNumbers(_ raw: Any?) -> [String: Double] {
        guard let dictionary = raw as? [String: Any] else { return [:] }
        return dictionary.reduce(into: [:]) { values, item in
            if let number = item.value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
               number.doubleValue.isFinite, number.doubleValue >= 0 {
                values[item.key] = number.doubleValue
            }
        }
    }

    private func save() {
        defaults.set(["version": 2, "unlocked": unlocked.sorted(), "timestamps": timestamps, "metrics": metrics], forKey: Self.storageKey)
    }
}

/// 展示队列与窗口无关，便于验证顺序、去重和批量提示策略。
struct AchievementUnlockQueue {
    private(set) var pending: [Int] = []

    mutating func enqueue(_ ids: [Int]) {
        pending = Array(Set(pending).union(ids)).sorted()
    }

    mutating func next() -> [Int] {
        guard !pending.isEmpty else { return [] }
        if pending.count > 3 {
            let batch = pending
            pending.removeAll()
            return batch
        }
        return [pending.removeFirst()]
    }
}
