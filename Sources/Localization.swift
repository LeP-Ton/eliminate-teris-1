import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"

    var titleKey: String {
        switch self {
        case .english:
            return "language.english"
        case .chineseSimplified:
            return "language.chinese"
        case .japanese:
            return "language.japanese"
        case .korean:
            return "language.korean"
        case .russian:
            return "language.russian"
        }
    }

    static func fromPreferredLanguages(_ preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier.lowercased()
            if code.hasPrefix("zh-hans") || code.hasPrefix("zh-cn") {
                return .chineseSimplified
            }
            if code.hasPrefix("ja") {
                return .japanese
            }
            if code.hasPrefix("ko") {
                return .korean
            }
            if code.hasPrefix("ru") {
                return .russian
            }
            if code.hasPrefix("en") {
                return .english
            }
        }
        return .english
    }
}

final class Localizer {
    static let shared = Localizer()

    private(set) var language: AppLanguage

    private init() {
        self.language = AppLanguage.fromPreferredLanguages()
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    var locale: Locale {
        return Locale(identifier: language.rawValue)
    }

    func string(_ key: String) -> String {
        if let bundle = bundle(for: language) {
            let localized = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
            if localized != key {
                return localized
            }
        }

        if language != .english, let englishBundle = bundle(for: .english) {
            let fallback = englishBundle.localizedString(forKey: key, value: nil, table: "Localizable")
            if fallback != key {
                return fallback
            }
        }

        return key
    }

    private func bundle(for language: AppLanguage) -> Bundle? {
        let rawCode = language.rawValue
        let candidates = [
            rawCode,
            rawCode.lowercased(),
            rawCode.replacingOccurrences(of: "-", with: "_"),
            rawCode.lowercased().replacingOccurrences(of: "-", with: "_")
        ]

        for candidate in candidates {
            guard let path = Bundle.module.path(forResource: candidate, ofType: "lproj") else {
                continue
            }
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return nil
    }
}
