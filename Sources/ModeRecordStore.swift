import Foundation

enum ModeRecordKey: String, Codable, CaseIterable {
    case timed, moves
}

/// 当前挑战仅记录消除数；耗时保留作历史信息，永远不参与新榜单排序。
struct ModeRecord: Codable {
    let id: String
    let clearedCount: Int
    let swapsUsed: Int
    let elapsedTime: TimeInterval
    let createdAt: TimeInterval
}

/// 旧版结构只读，用于展示原规则记录，不转换或写回玩家的旧存档。
struct LegacyModeRecord: Codable {
    let id: String
    let score: Int
    let elapsedTime: TimeInterval
    let durationMinutes: Int?
    let targetScore: Int?
    let createdAt: TimeInterval
}

struct LegacyRecordSection {
    enum Kind: String { case scoreAttack, speedRun }
    let kind: Kind
    let ruleValue: Int
    let entries: [LegacyModeRecord]
}

final class ModeRecordStore {
    static let shared = ModeRecordStore()
    static let storageKey = "challenge_records_v2"
    static let legacyStorageKey = "mode_records_v1"
    private let defaults: UserDefaults
    private var buckets: [String: [ModeRecord]] = [:]
    private var history: [LegacyRecordSection] = []
    private let maximumRecords = 9

    static func scopeID(mode: ModeRecordKey, detailValue: Int) -> String { "\(mode.rawValue)_\(detailValue)" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 新旧存档分开加载，打开新版不会改写旧榜单，也不会生成开发用虚构成绩。
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: [ModeRecord]].self, from: data) {
            for (key, entries) in decoded {
                var seen: Set<String> = []
                let valid = entries.filter {
                    !$0.id.isEmpty && $0.clearedCount >= 0 && $0.swapsUsed >= 0 &&
                    $0.elapsedTime.isFinite && $0.elapsedTime >= 0 && $0.createdAt.isFinite && seen.insert($0.id).inserted
                }
                buckets[key] = Array(sorted(valid).prefix(maximumRecords))
            }
        }
        loadHistory()
    }

    func records(for mode: ModeRecordKey, detailValue: Int) -> [ModeRecord] {
        buckets[Self.scopeID(mode: mode, detailValue: detailValue)] ?? []
    }

    /// 同数量共享名次，后续跳过相应序号；日期仅用于稳定展示，不改变并列关系。
    static func ranks(for entries: [ModeRecord]) -> [Int] {
        var rank = 0
        return entries.enumerated().map { index, record in
            if index == 0 || record.clearedCount != entries[index - 1].clearedCount { rank = index + 1 }
            return rank
        }
    }

    @discardableResult
    func addRecord(mode: ModeRecordKey, detailValue: Int, clearedCount: Int, swapsUsed: Int,
                   elapsedTime: TimeInterval) -> ModeRecord? {
        guard detailValue > 0, clearedCount >= 0, swapsUsed >= 0, elapsedTime.isFinite, elapsedTime >= 0 else { return nil }
        // 只接纳自然完成的挑战，零消除也是有效结果；成就另行判断是否达标。
        switch mode {
        case .timed: guard elapsedTime >= Double(detailValue) else { return nil }
        case .moves: guard swapsUsed == detailValue else { return nil }
        }
        let record = ModeRecord(id: UUID().uuidString, clearedCount: clearedCount, swapsUsed: swapsUsed,
                                elapsedTime: elapsedTime, createdAt: Date().timeIntervalSince1970)
        let key = Self.scopeID(mode: mode, detailValue: detailValue)
        buckets[key] = Array(sorted((buckets[key] ?? []) + [record]).prefix(maximumRecords))
        if let data = try? JSONEncoder().encode(buckets) { defaults.set(data, forKey: Self.storageKey) }
        return buckets[key]?.contains(where: { $0.id == record.id }) == true ? record : nil
    }

    func legacySections() -> [LegacyRecordSection] { history }

    private func sorted(_ records: [ModeRecord]) -> [ModeRecord] {
        records.sorted {
            if $0.clearedCount != $1.clearedCount { return $0.clearedCount > $1.clearedCount }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: Self.legacyStorageKey),
              let decoded = try? JSONDecoder().decode([String: [LegacyModeRecord]].self, from: data) else { return }
        var grouped: [String: [LegacyModeRecord]] = [:]
        var kinds: [String: (LegacyRecordSection.Kind, Int)] = [:]
        var seen: Set<String> = []
        for (scope, records) in decoded {
            for record in records where !record.id.hasPrefix("seed_") && record.score >= 0 &&
                record.elapsedTime.isFinite && record.elapsedTime >= 0 && record.createdAt.isFinite {
                let kind: LegacyRecordSection.Kind = scope.hasPrefix("score_attack") ? .scoreAttack : .speedRun
                guard scope.hasPrefix("score_attack") || scope.hasPrefix("speed_run"),
                      let rule = kind == .scoreAttack ? record.durationMinutes : record.targetScore,
                      rule > 0, seen.insert(record.id).inserted else { continue }
                let key = "\(kind.rawValue).\(rule)"
                grouped[key, default: []].append(record); kinds[key] = (kind, rule)
            }
        }
        history = kinds.map { key, value in
            let entries = (grouped[key] ?? []).sorted {
                if value.0 == .scoreAttack, $0.score != $1.score { return $0.score > $1.score }
                if $0.elapsedTime != $1.elapsedTime { return $0.elapsedTime < $1.elapsedTime }
                return $0.createdAt < $1.createdAt
            }
            return LegacyRecordSection(kind: value.0, ruleValue: value.1, entries: entries)
        }.sorted {
            if $0.kind != $1.kind { return $0.kind == .scoreAttack }
            return $0.ruleValue < $1.ruleValue
        }
    }
}
