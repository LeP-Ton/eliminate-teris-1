import Cocoa
import XCTest
@testable import EliminateTeris1

/// 全部面板使用独立记录域；预览仅由测试导出，不在正式应用增加入口。
final class HomeUtilityPanelTests: AchievementTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func labels(_ view: NSView) -> [String] { descendants(view).compactMap { ($0 as? NSTextField)?.stringValue } }

    private func recordStore(empty: Bool = false) throws -> ModeRecordStore {
        var buckets: [String: [ModeRecord]] = [:]
        if !empty {
            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 1)] = (0..<9).map {
                ModeRecord(id: "utility-score-\($0)", score: 920 - $0 * 70, elapsedTime: 60,
                           durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600 - Double($0) * 86400)
            }
            buckets[ModeRecordStore.scopeID(mode: .speedRun, detailValue: 300)] = (0..<9).map {
                ModeRecord(id: "utility-speed-\($0)", score: 300, elapsedTime: 18.42 + Double($0) * 3.2,
                           durationMinutes: nil, targetScore: 300, createdAt: 1_793_361_600 - Double($0) * 86400)
            }
            buckets[ModeRecordStore.scopeID(mode: .scoreAttack, detailValue: 2)] = [
                ModeRecord(id: "old-rule", score: 999_999, elapsedTime: 120, durationMinutes: 2, targetScore: nil, createdAt: 0)
            ]
        }
        defaults.set(try JSONEncoder().encode(buckets), forKey: "mode_records_v1")
        let previous = ProcessInfo.processInfo.environment["ELIMINATE_DEVELOPMENT_MODE"]
        setenv("ELIMINATE_DEVELOPMENT_MODE", "0", 1)
        defer {
            if let previous { setenv("ELIMINATE_DEVELOPMENT_MODE", previous, 1) }
            else { unsetenv("ELIMINATE_DEVELOPMENT_MODE") }
        }
        return ModeRecordStore(defaults: defaults)
    }

    func testSettingsLanguageAndVolumeCallbacksRemainNative() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let panel = HomeUtilityPanel(page: "settings", store: try recordStore())
        defer { panel.close() }
        panel.refresh(mode: .free, volume: 0.26)
        let content = try XCTUnwrap(panel.window?.contentView)
        let menu = try XCTUnwrap(descendants(content).compactMap { $0 as? NSPopUpButton }.first)
        let slider = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSlider }.first)
        var chosen: AppLanguage?
        panel.onLanguage = { chosen = $0; Localizer.shared.setLanguage($0) }
        var changed: Float = -1
        panel.onVolume = { changed = $0 }
        for (index, language) in AppLanguage.allCases.enumerated() {
            menu.selectItem(at: index); menu.sendAction(menu.action, to: menu.target)
            XCTAssertEqual(chosen, language)
            panel.refresh(mode: .free, volume: 0.26)
            XCTAssertEqual(menu.indexOfSelectedItem, index)
            XCTAssertEqual(menu.numberOfItems, 5)
        }
        for value in [0.0, 0.26, 1.0] {
            slider.doubleValue = value; slider.sendAction(slider.action, to: slider.target)
            XCTAssertEqual(changed, Float(value), accuracy: 0.001)
            XCTAssertTrue(labels(content).contains("\(Int(value * 100))%"))
        }
        XCTAssertEqual(descendants(content).compactMap { $0 as? NSPopUpButton }.count, 1)
        XCTAssertFalse(try XCTUnwrap(panel.window).canBecomeKey)
    }

    func testRecordTabsUseRealRankedBucketsAndKeepSelectionOnRefresh() throws {
        _ = NSApplication.shared
        let store = try recordStore()
        let panel = HomeUtilityPanel(page: "records", store: store)
        defer { panel.close() }
        panel.refresh(mode: .free, volume: 0.4)
        let content = try XCTUnwrap(panel.window?.contentView)
        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
        XCTAssertTrue(labels(content).contains("920"))
        XCTAssertFalse(labels(content).contains { $0.contains("999999") || $0.contains("999,999") })
        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
        XCTAssertTrue(labels(content).contains("18.42"))
        XCTAssertFalse(labels(content).contains("920"))
        _ = store.addScoreAttackRecord(score: 990, elapsedTime: 60, durationMinutes: 1)
        panel.refresh(mode: .scoreAttack, volume: 0.7)
        XCTAssertEqual(tabs.selectedSegment, 1)
        XCTAssertTrue(labels(content).contains("18.42"))
        tabs.selectedSegment = 0; tabs.sendAction(tabs.action, to: tabs.target)
        XCTAssertTrue(labels(content).contains("990"))
        XCTAssertTrue(labels(content).contains(AchievementText.format("records.metric.score", 990)))
        XCTAssertEqual(store.records(for: .scoreAttack, detailValue: 1).count, 9)
    }

    func testEmptyRecordsAndAllRuleModesRemainAccurate() throws {
        _ = NSApplication.shared
        let store = try recordStore(empty: true)
        let panel = HomeUtilityPanel(page: "records", store: store)
        let rules = HomeUtilityPanel(page: "rules", store: store)
        defer { panel.close(); rules.close() }
        panel.refresh(mode: .free, volume: 0.4)
        let content = try XCTUnwrap(panel.window?.contentView)
        XCTAssertTrue(labels(content).contains(AchievementText.string("records.empty")))
        XCTAssertTrue(labels(content).contains("—"))
        for mode in HomeGameMode.allCases {
            rules.refresh(mode: mode, volume: 0.4)
            let text = labels(try XCTUnwrap(rules.window?.contentView))
            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.score_attack")))
            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.speed_run")))
            XCTAssertEqual(text.filter { $0 == AchievementText.string("utility.rules.current") }.count, 1)
        }
        XCTAssertTrue(store.records(for: .scoreAttack, detailValue: 1).isEmpty)
        XCTAssertTrue(store.records(for: .speedRun, detailValue: 300).isEmpty)
    }

    func testFiveLanguagesCompactWindowsAndExportRealPanels() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let store = try recordStore()
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            for page in ["settings", "rules", "records"] {
                let panel = HomeUtilityPanel(page: page, store: store)
                defer { panel.close() }
                panel.refresh(mode: .free, volume: 0.26)
                let window = try XCTUnwrap(panel.window)
                let content = try XCTUnwrap(window.contentView as? UtilityPageView)
                let originalSize = content.bounds.size
                for size in [originalSize, NSSize(width: 480, height: 420)] {
                    window.setContentSize(size); content.layoutSubtreeIfNeeded()
                    XCTAssertFalse(labels(content).contains { $0.hasPrefix("utility.") })
                    XCTAssertGreaterThan(content.document.bounds.height, 100)
                    XCTAssertLessThanOrEqual(content.document.frame.width, content.scroll.contentView.bounds.width + 1)
                    XCTAssertEqual(content.scroll.contentView.bounds.minY, 0, accuracy: 1, "初次打开应从顶部显示")
                    for card in descendants(content).compactMap({ $0 as? UtilityCard }) {
                        XCTAssertGreaterThan(card.frame.height, 20)
                        XCTAssertGreaterThan(card.frame.width, 200)
                        for label in descendants(card).compactMap({ $0 as? NSTextField }) {
                            let rect = card.convert(label.bounds, from: label)
                            XCTAssertGreaterThanOrEqual(rect.minX, -1, "\(language): \(label.stringValue)")
                            XCTAssertLessThanOrEqual(rect.maxX, card.bounds.maxX + 1, "\(language): \(label.stringValue)")
                        }
                    }
                    if language == .russian, size.width == 480 { try export(content, name: "utility-\(page)-compact-ru") }
                }
                if language == .chineseSimplified {
                    window.setContentSize(originalSize); content.layoutSubtreeIfNeeded()
                    content.document.scroll(.zero)
                    try export(content, name: "utility-\(page)")
                    if page == "records" {
                        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
                        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
                        try export(content, name: "utility-records-speed")
                    }
                }
            }
        }
        Localizer.shared.setLanguage(.chineseSimplified)
        let empty = HomeUtilityPanel(page: "records", store: try recordStore(empty: true))
        defer { empty.close() }
        empty.refresh(mode: .free, volume: 0)
        try export(try XCTUnwrap(empty.window?.contentView), name: "utility-records-empty")
    }

    func testPanelsStayNearParentAndSnapshotRefreshPreservesScroll() throws {
        _ = NSApplication.shared
        let parent = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 620), styleMask: [.titled], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        let panel = HomeUtilityPanel(page: "rules", store: try recordStore())
        defer { panel.close(); parent.close() }
        panel.refresh(mode: .free, volume: 0.4); panel.present(from: parent)
        let window = try XCTUnwrap(panel.window)
        XCTAssertTrue(window.parent === parent)
        XCTAssertFalse(window.canBecomeKey)
        if let screen = parent.screen ?? NSScreen.main { XCTAssertTrue(screen.visibleFrame.insetBy(dx: 7, dy: 7).contains(window.frame)) }
        let content = try XCTUnwrap(window.contentView as? UtilityPageView)
        window.setContentSize(NSSize(width: 480, height: 420)); content.layoutSubtreeIfNeeded()
        content.document.scroll(NSPoint(x: 0, y: 100))
        let position = content.scroll.contentView.bounds.origin
        panel.refresh(mode: .free, volume: 0.5)
        XCTAssertEqual(content.scroll.contentView.bounds.origin, position)
    }

    private func export(_ view: NSView, name: String) throws {
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-\(name).png")
        try png.write(to: url)
        print("辅助面板预览：\(url.path)")
    }
}
