import Foundation

/// 使用代码所在 Bundle 定位 XCTest 宿主旁的 SwiftPM 资源，避免依赖测试进程的主 Bundle。
private final class LocalizationBundleToken: NSObject {}

/// 语言表与首页插画共用资源定位，兼容 SwiftPM 测试、直接运行及手工打包的 .app。
enum GameResourceLocator {
    static let bundleName = "EliminateTeris1_EliminateTeris1"

    static func resourceBundle() -> Bundle? {
        let bundleFileName = "\(bundleName).bundle"
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
        let executableParentDirectory = executableDirectory?.deletingLastPathComponent()
        let codeBundle = Bundle(for: LocalizationBundleToken.self)

        // 同时兼容 SwiftPM 直接运行（bundle 与可执行文件同级）和手工打包 .app（bundle 位于 Contents/Resources）。
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleFileName),
            Bundle.main.bundleURL.appendingPathComponent(bundleFileName),
            executableDirectory?.appendingPathComponent(bundleFileName),
            executableParentDirectory?.appendingPathComponent("Resources").appendingPathComponent(bundleFileName),
            codeBundle.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleFileName)
        ]

        for candidate in candidates {
            guard let candidate else { continue }
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return nil
    }
}

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
        guard let resourceBundle = GameResourceLocator.resourceBundle() else {
            return nil
        }

        let rawCode = language.rawValue
        let candidates = [
            rawCode,
            rawCode.lowercased(),
            rawCode.replacingOccurrences(of: "-", with: "_"),
            rawCode.lowercased().replacingOccurrences(of: "-", with: "_")
        ]

        for candidate in candidates {
            guard let path = resourceBundle.path(forResource: candidate, ofType: "lproj") else {
                continue
            }
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return nil
    }
}
