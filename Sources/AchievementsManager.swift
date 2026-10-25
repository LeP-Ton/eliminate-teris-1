import Foundation

final class AchievementsManager {
    static let shared = AchievementsManager()

    static let didUnlockNotification = Notification.Name("com.eliminateteris1.achievements.didUnlock")

    private let unlockedKey = "AchievementsManager.unlockedIds"
    private let timestampsKey = "AchievementsManager.unlockTimestamps"

    private var unlockedIds: Set<Int> = []
    private var unlockTimestamps: [String: TimeInterval] = [:]

    private init() {
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        if let array = defaults.array(forKey: unlockedKey) as? [Int] {
            unlockedIds = Set(array)
        }
        if let dict = defaults.dictionary(forKey: timestampsKey) as? [String: Double] {
            unlockTimestamps = dict
        }
    }

    private func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(Array(unlockedIds), forKey: unlockedKey)
        defaults.set(unlockTimestamps, forKey: timestampsKey)
    }

    func isUnlocked(id: Int) -> Bool {
        return unlockedIds.contains(id)
    }

    func unlock(id: Int) {
        guard !unlockedIds.contains(id) else { return }
        unlockedIds.insert(id)
        unlockTimestamps[String(id)] = Date().timeIntervalSince1970
        saveToDefaults()
        NotificationCenter.default.post(name: AchievementsManager.didUnlockNotification, object: self, userInfo: ["id": id])
    }

    func unlockedIDs() -> [Int] {
        return Array(unlockedIds).sorted()
    }

    func resetAll() {
        unlockedIds.removeAll()
        unlockTimestamps.removeAll()
        saveToDefaults()
    }
}
