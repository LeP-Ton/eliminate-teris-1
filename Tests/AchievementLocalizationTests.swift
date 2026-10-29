import XCTest
@testable import EliminateTeris1

final class AchievementLocalizationTests: XCTestCase {
    func testFiveLanguagesHaveCompleteKeysAndMatchingFormatArguments() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var tables: [String: [String: String]] = [:]
        let formatPattern = try NSRegularExpression(pattern: "%[0-9.]*[@df]")
        for language in AppLanguage.allCases {
            let url = root.appendingPathComponent("Sources/Resources/\(language.rawValue).lproj/Localizable.strings")
            let data = try Data(contentsOf: url)
            let table = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            tables[language.rawValue] = table
            for kind in PieceKind.allCases { XCTAssertNotNil(table[kind.titleKey]) }
            XCTAssertNotNil(table["banner.total_cleared"])
            XCTAssertNotNil(table["banner.piece_cleared"])
            for definition in AchievementDefinition.all {
                XCTAssertNotNil(table[definition.titleKey], "\(language.rawValue): \(definition.titleKey)")
                XCTAssertNotNil(table[definition.descriptionKey])
            }
        }
        let english = try XCTUnwrap(tables["en"])
        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") }
        for table in tables.values {
            for key in keys {
                let value = try XCTUnwrap(table[key], key)
                func arguments(_ text: String) -> [String] {
                    formatPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                        String(text[Range($0.range, in: text)!])
                    }
                }
                XCTAssertEqual(arguments(value), arguments(english[key]!), key)
            }
        }
    }
}
