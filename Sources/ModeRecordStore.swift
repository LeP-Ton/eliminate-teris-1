import Foundation

enum ModeRecordKey: String, Codable {
    case scoreAttack = "score_attack"
    case speedRun = "speed_run"
}

struct ModeRecord: Codable {
    let id: String
    let score: Int
    let elapsedTime: TimeInterval
    let durationMinutes: Int?
    let targetScore: Int?
    let createdAt: TimeInterval
}

final class ModeRecordStore {
    static let shared = ModeRecordStore()

    static func scopeID(mode: ModeRecordKey, detailValue: Int) -> String {
        return "\(mode.rawValue)_\(detailValue)"
    }

    private let storageKey = "mode_records_v1"
    private let seedVersionKey = "mode_records_seed_version"
    private let seedVersion = 5
    private let maxRecordsPerScope = 9
    private let scoreAttackDurations = [1, 2, 3]
    private let speedRunTargets = [300, 600, 900]
    private let defaults: UserDefaults
    private var recordsByScope: [String: [ModeRecord]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        if normalizeBucketsToMaxCount() {
            save()
        }
        seedTestRecordsIfNeeded()
    }

    func records(for mode: ModeRecordKey, detailValue: Int) -> [ModeRecord] {
        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
        return recordsByScope[scopeID] ?? []
    }

    @discardableResult
    func addScoreAttackRecord(score: Int, elapsedTime: TimeInterval, durationMinutes: Int) -> ModeRecord? {
        let minutes = max(1, durationMinutes)
        let record = ModeRecord(
            id: UUID().uuidString,
            score: score,
            elapsedTime: elapsedTime,
            durationMinutes: minutes,
            targetScore: nil,
            createdAt: Date().timeIntervalSince1970
        )

        return append(record, for: .scoreAttack, detailValue: minutes)
    }

    @discardableResult
    func addSpeedRunRecord(score: Int, elapsedTime: TimeInterval, targetScore: Int) -> ModeRecord? {
        let clampedTarget = max(1, targetScore)
        let record = ModeRecord(
            id: UUID().uuidString,
            score: score,
            elapsedTime: elapsedTime,
            durationMinutes: nil,
            targetScore: clampedTarget,
            createdAt: Date().timeIntervalSince1970
        )

        return append(record, for: .speedRun, detailValue: clampedTarget)
    }

    @discardableResult
    private func append(_ record: ModeRecord, for mode: ModeRecordKey, detailValue: Int) -> ModeRecord? {
        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
        var bucket = recordsByScope[scopeID] ?? []
        bucket.append(record)
        sortAndTrim(&bucket, for: mode)

        recordsByScope[scopeID] = bucket
        save()

        guard bucket.contains(where: { $0.id == record.id }) else {
            return nil
        }

        return record
    }

    private func sortAndTrim(_ bucket: inout [ModeRecord], for mode: ModeRecordKey) {
        switch mode {
        case .scoreAttack:
            bucket.sort(by: compareScoreAttackRecords)
        case .speedRun:
            bucket.sort(by: compareSpeedRunRecords)
        }

        if bucket.count > maxRecordsPerScope {
            bucket = Array(bucket.prefix(maxRecordsPerScope))
        }
    }

    private func seedTestRecordsIfNeeded() {
        guard defaults.integer(forKey: seedVersionKey) < seedVersion else { return }

        for minutes in scoreAttackDurations {
            ensureSeedRecords(
                for: .scoreAttack,
                detailValue: minutes,
                seeds: makeScoreAttackSeedRecords(durationMinutes: minutes)
            )
        }

        for targetScore in speedRunTargets {
            ensureSeedRecords(
                for: .speedRun,
                detailValue: targetScore,
                seeds: makeSpeedRunSeedRecords(targetScore: targetScore)
            )
        }

        defaults.set(seedVersion, forKey: seedVersionKey)
        save()
    }

    private func ensureSeedRecords(for mode: ModeRecordKey, detailValue: Int, seeds: [ModeRecord]) {
        let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
        var bucket = recordsByScope[scopeID] ?? []

        // 仅包含 seed 的旧分桶直接替换，确保 seed 策略升级后可生效。
        if bucket.isEmpty || bucket.allSatisfy({ Self.isSeedRecordID($0.id) }) {
            bucket = seeds
            sortAndTrim(&bucket, for: mode)
            recordsByScope[scopeID] = bucket
            return
        }

        guard bucket.count < maxRecordsPerScope else { return }

        let existingIDs = Set(bucket.map(\.id))
        let availableSeeds = seeds.filter { !existingIDs.contains($0.id) }
        let missingCount = maxRecordsPerScope - bucket.count
        bucket.append(contentsOf: availableSeeds.prefix(missingCount))
        sortAndTrim(&bucket, for: mode)

        recordsByScope[scopeID] = bucket
    }

    private func makeScoreAttackSeedRecords(durationMinutes: Int) -> [ModeRecord] {
        let baseTime = Date().addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970 + Double(durationMinutes * 100)
        let baseScore = 420 - durationMinutes * 12
        let seedCount = seedRecordCount(for: .scoreAttack, detailValue: durationMinutes)

        return (0..<seedCount).map { rank in
            ModeRecord(
                id: "seed_score_attack_\(durationMinutes)_\(rank)",
                score: max(80, baseScore - rank * 9),
                elapsedTime: TimeInterval(durationMinutes * 60),
                durationMinutes: durationMinutes,
                targetScore: nil,
                createdAt: baseTime + Double(rank)
            )
        }
    }

    private func makeSpeedRunSeedRecords(targetScore: Int) -> [ModeRecord] {
        let baseElapsedByTarget: [Int: Int] = [
            300: 54,
            600: 108,
            900: 156
        ]
        let baseElapsed = baseElapsedByTarget[targetScore] ?? max(45, targetScore / 6)
        let baseTime = Date().addingTimeInterval(-6 * 24 * 60 * 60).timeIntervalSince1970 + Double(targetScore)
        let seedCount = seedRecordCount(for: .speedRun, detailValue: targetScore)

        return (0..<seedCount).map { rank in
            ModeRecord(
                id: "seed_speed_run_\(targetScore)_\(rank)",
                score: targetScore,
                elapsedTime: TimeInterval(baseElapsed + rank * 4),
                durationMinutes: nil,
                targetScore: targetScore,
                createdAt: baseTime + Double(rank)
            )
        }
    }

    private func seedRecordCount(for mode: ModeRecordKey, detailValue: Int) -> Int {
        switch mode {
        case .scoreAttack:
            switch detailValue {
            case 1:
                return maxRecordsPerScope
            case 2:
                return 1
            case 3:
                return 0
            default:
                return maxRecordsPerScope
            }

        case .speedRun:
            switch detailValue {
            case 300:
                return maxRecordsPerScope
            case 600:
                return 1
            case 900:
                return 0
            default:
                return maxRecordsPerScope
            }
        }
    }

    private static func isSeedRecordID(_ id: String) -> Bool {
        return id.hasPrefix("seed_score_attack_") || id.hasPrefix("seed_speed_run_")
    }

    private func normalizeBucketsToMaxCount() -> Bool {
        var changed = false

        for (scopeID, bucket) in recordsByScope {
            guard let mode = modeKey(forScopeID: scopeID) else { continue }

            var normalized = bucket
            sortAndTrim(&normalized, for: mode)
            if normalized.map(\.id) != bucket.map(\.id) {
                changed = true
            }

            recordsByScope[scopeID] = normalized
        }

        return changed
    }

    private func modeKey(forScopeID scopeID: String) -> ModeRecordKey? {
        if scopeID.hasPrefix("\(ModeRecordKey.scoreAttack.rawValue)_") || scopeID == ModeRecordKey.scoreAttack.rawValue {
            return .scoreAttack
        }
        if scopeID.hasPrefix("\(ModeRecordKey.speedRun.rawValue)_") || scopeID == ModeRecordKey.speedRun.rawValue {
            return .speedRun
        }
        return nil
    }

    private func compareScoreAttackRecords(_ lhs: ModeRecord, _ rhs: ModeRecord) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        let lhsMinutes = lhs.durationMinutes ?? Int.max
        let rhsMinutes = rhs.durationMinutes ?? Int.max
        if lhsMinutes != rhsMinutes {
            return lhsMinutes < rhsMinutes
        }

        if abs(lhs.elapsedTime - rhs.elapsedTime) > 0.0001 {
            return lhs.elapsedTime < rhs.elapsedTime
        }

        return lhs.createdAt < rhs.createdAt
    }

    private func compareSpeedRunRecords(_ lhs: ModeRecord, _ rhs: ModeRecord) -> Bool {
        if abs(lhs.elapsedTime - rhs.elapsedTime) > 0.0001 {
            return lhs.elapsedTime < rhs.elapsedTime
        }

        let lhsTarget = lhs.targetScore ?? 0
        let rhsTarget = rhs.targetScore ?? 0
        if lhsTarget != rhsTarget {
            return lhsTarget > rhsTarget
        }

        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        return lhs.createdAt < rhs.createdAt
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([String: [ModeRecord]].self, from: data) else {
            return
        }

        recordsByScope = decoded
        if migrateLegacyBucketsIfNeeded() {
            save()
        }
    }

    @discardableResult
    private func migrateLegacyBucketsIfNeeded() -> Bool {
        var changed = false

        for mode in [ModeRecordKey.scoreAttack, ModeRecordKey.speedRun] {
            let legacyKey = mode.rawValue
            guard let legacyRecords = recordsByScope.removeValue(forKey: legacyKey) else {
                continue
            }

            changed = true
            for record in legacyRecords {
                guard let detailValue = detailValue(for: mode, record: record) else {
                    continue
                }

                let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
                var bucket = recordsByScope[scopeID] ?? []
                bucket.append(record)
                sortAndTrim(&bucket, for: mode)
                recordsByScope[scopeID] = bucket
            }
        }

        return changed
    }

    private func detailValue(for mode: ModeRecordKey, record: ModeRecord) -> Int? {
        switch mode {
        case .scoreAttack:
            guard let minutes = record.durationMinutes, minutes > 0 else {
                return nil
            }
            return minutes

        case .speedRun:
            guard let target = record.targetScore, target > 0 else {
                return nil
            }
            return target
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(recordsByScope) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
