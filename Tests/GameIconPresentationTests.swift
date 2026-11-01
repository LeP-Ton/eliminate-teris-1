import Cocoa
import XCTest
@testable import EliminateTeris1

final class GameIconPresentationTests: AchievementTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    private func bitmap(_ image: NSImage) throws -> NSBitmapImageRep {
        try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
    }

    private func inkBounds(_ bitmap: NSBitmapImageRep) -> NSRect {
        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return .zero }
        return NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func testSystemSymbolsKeepTheirInkAspectRatio() throws {
        _ = NSApplication.shared
        for name in ["infinity", "music.note", "hand.tap", "flag"] {
            let original = try XCTUnwrap(NSImage(systemSymbolName: name, accessibilityDescription: nil))
                .withSymbolConfiguration(.init(pointSize: 32, weight: .regular))!
            // 先放大参考矢量再测量，避免原始十几像素的字形取整放大比例误差。
            let reference = NSImage(size: NSSize(width: original.size.width * 4, height: original.size.height * 4), flipped: true) { rect in
                original.draw(in: rect)
                return true
            }
            let baseline = inkBounds(try bitmap(reference))
            for size in [NSSize(width: 64, height: 64), NSSize(width: 100, height: 40)] {
                let rendered = NSImage(size: size, flipped: true) { bounds in
                    HomeStyle.symbol(name, in: bounds)
                    return true
                }
                let ink = inkBounds(try bitmap(rendered))
                XCTAssertGreaterThan(ink.width, 0)
                XCTAssertEqual(ink.width / ink.height, baseline.width / baseline.height, accuracy: 0.15, name)
            }
        }
    }

    func testEveryModeAndAchievementRendersIncludingLocalTrophyAndAllTiers() throws {
        for mode in HomeGameMode.allCases {
            let image = NSImage(size: NSSize(width: 48, height: 48), flipped: true) { bounds in
                HomeStyle.symbol(mode.symbol, in: bounds.insetBy(dx: 3, dy: 3))
                return true
            }
            XCTAssertGreaterThan(inkBounds(try bitmap(image)).width, 16, mode.key)
        }
        for definition in AchievementDefinition.all {
            for muted in [false, true] {
                let ink = inkBounds(try bitmap(AchievementIconCatalog.image(for: definition, muted: muted)))
                XCTAssertGreaterThan(ink.width, 10, "成就 \(definition.id) 不应显示空图标")
                XCTAssertGreaterThan(ink.height, 10)
            }
        }
        let fullSet = try AchievementDefinition.all.map { try XCTUnwrap(AchievementIconCatalog.image(for: $0).tiffRepresentation) }
        XCTAssertEqual(Set(fullSet).count, 32, "全部徽章应具有各自的身份或等级")
        for first in [21, 24, 27, 30] {
            let data = try (first...first + 2).map { id in
                try XCTUnwrap(AchievementIconCatalog.image(for: AchievementDefinition.all[id - 1]).tiffRepresentation)
            }
            XCTAssertEqual(Set(data).count, 3, "同一类型的百、千、万图标应可区分")
        }
    }

    func testProductionPanelHasNoIconPreviewEntryAndDoesNotChangeProgress() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
        let controller = AchievementsWindowController(manager: manager)
        defer { controller.close() }
        controller.refresh()
        let content = try XCTUnwrap(controller.window?.contentView)
        content.layoutSubtreeIfNeeded()
        XCTAssertFalse(descendants(content).compactMap { $0 as? NSButton }.contains { $0.title.contains("图标预览") })
        XCTAssertFalse(controller.responds(to: NSSelectorFromString("showIconPreview")))
        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 32)
        XCTAssertEqual(manager.unlockedIDs(), [])
        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
    }

    func testTestOnlyContactSheetExportsEveryBadgeWithoutUnlocking() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            let sheet = AchievementIconContactSheet(frame: NSRect(x: 0, y: 0, width: AchievementIconContactSheet.width, height: AchievementIconContactSheet.height))
            let bitmap = try XCTUnwrap(sheet.bitmapImageRepForCachingDisplay(in: sheet.bounds))
            sheet.cacheDisplay(in: sheet.bounds, to: bitmap)
            if language == .chineseSimplified {
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-all-achievement-icons.png"))
            }
        }
        XCTAssertEqual(manager.unlockedIDs(), [])
        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
    }

    func testRedesignedBadgesRenderAndRemainClickableInHomeLabels() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let domain = "badge-label-preview.\(UUID().uuidString)"
        let fixture = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { fixture.removePersistentDomain(forName: domain) }
        fixture.set(["version": 1, "unlocked": [17, 18, 19], "metrics": [:]], forKey: AchievementsManager.storageKey)
        let progress = AchievementsManager(defaults: fixture)
        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
        home.refresh(snapshot: GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
                                           targetScore: nil, isRunning: false, isFinished: false), mode: .free, manager: progress)
        home.layoutSubtreeIfNeeded()
        var selected: Int?
        home.onAchievement = { selected = $0 }
        for id in [17, 18, 19] {
            let description = AchievementText.string(AchievementDefinition.all[id - 1].descriptionKey)
            let button = try XCTUnwrap(home.subviews.compactMap { $0 as? HomeButton }.first { $0.toolTip?.contains(description) == true })
            button.performClick(nil)
            XCTAssertEqual(selected, id)
        }
        let strip = NSRect(x: 44, y: 708, width: 1092, height: 54)
        let bitmap = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: strip))
        home.cacheDisplay(in: strip, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-game-badge-labels.png"))
    }

    func testHomeBadgesStayCenteredAtFullscreenWidths() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let snapshot = GameSnapshot(mode: .free, score: 0, elapsedTime: 0, remainingTime: nil,
                                    targetScore: nil, isRunning: false, isFinished: false)
        for unlocked in [[], [1, 2, 3, 4, 5]] {
            defaults.set(["version": 1, "unlocked": unlocked, "metrics": [:]], forKey: AchievementsManager.storageKey)
            let progress = AchievementsManager(defaults: defaults)
            let home = HomeDashboardView(frame: .zero)
            for language in AppLanguage.allCases {
                Localizer.shared.setLanguage(language)
                for width: CGFloat in [960, 1440, 1920, 2560, 1180] {
                    home.setFrameSize(NSSize(width: width, height: width > 1440 ? 1080 : 800))
                    home.refresh(snapshot: snapshot, mode: .free, manager: progress)
                    home.layoutSubtreeIfNeeded()
                    let badges = home.subviews.compactMap { $0 as? HomeButton }.filter { $0.toolTip != nil }
                    XCTAssertEqual(badges.count, 5)
                    for badge in badges {
                        let pixels = try XCTUnwrap(badge.bitmapImageRepForCachingDisplay(in: badge.bounds))
                        badge.cacheDisplay(in: badge.bounds, to: pixels)
                        let scale = CGFloat(pixels.pixelsWide) / badge.bounds.width
                        var minX = pixels.pixelsWide, minY = pixels.pixelsHigh, maxX = -1, maxY = -1
                        var statusMinX = pixels.pixelsWide, statusMaxX = -1
                        // 状态标记单独检查；居中测量仅包含成就图案与文字，忽略浅色卡片和边框。
                        let insetX = Int(8 * scale), insetY = Int(4 * scale)
                        for y in stride(from: insetY, to: pixels.pixelsHigh - insetY, by: 2) {
                            for x in stride(from: insetX, to: pixels.pixelsWide - insetX, by: 2) {
                                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                                      color.alphaComponent > 0.5,
                                      min(color.redComponent, color.greenComponent, color.blueComponent) < 0.78 else { continue }
                                if CGFloat(x) / scale < 34 {
                                    statusMinX = min(statusMinX, x); statusMaxX = max(statusMaxX, x)
                                } else {
                                    minX = min(minX, x); maxX = max(maxX, x)
                                    minY = min(minY, y); maxY = max(maxY, y)
                                }
                            }
                        }
                        XCTAssertGreaterThan(maxX, minX)
                        XCTAssertGreaterThan(statusMaxX, statusMinX, "完成/锁定标记应独立保留在左侧")
                        XCTAssertEqual(CGFloat(statusMinX + statusMaxX + 1) / (2 * scale), 23, accuracy: 2,
                                       "状态标记位置不应随名称或窗口宽度改变")
                        let centerX = CGFloat(minX + maxX + 1) / (2 * scale)
                        let centerY = CGFloat(minY + maxY + 1) / (2 * scale)
                        // 成就图案透明画布的左右留白可不同，像素外沿容许 5 点光学差异。
                        XCTAssertEqual(centerX, badge.bounds.midX, accuracy: 5, "\(language.rawValue) / \(width)：仅成就图案与文字水平居中")
                        XCTAssertEqual(centerY, badge.bounds.midY, accuracy: 3, "\(language.rawValue) / \(width)：标签图文应垂直居中")
                    }
                    if language == .chineseSimplified, width == 1920, !unlocked.isEmpty {
                        let strip = try XCTUnwrap(badges.map(\.frame).reduce(nil as NSRect?) { $0?.union($1) ?? $1 })
                        let image = try XCTUnwrap(home.bitmapImageRepForCachingDisplay(in: strip))
                        home.cacheDisplay(in: strip, to: image)
                        try XCTUnwrap(image.representation(using: .png, properties: [:])).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-fullscreen-badge-labels.png"))
                    }
                }
            }
        }
    }
}
