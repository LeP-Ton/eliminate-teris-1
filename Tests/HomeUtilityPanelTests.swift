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
            buckets[ModeRecordStore.scopeID(mode: .timed, detailValue: 60)] = (0..<9).map {
                ModeRecord(id: "utility-timed-\($0)", clearedCount: 92 - $0 * 7, swapsUsed: 30,
                           elapsedTime: 60, createdAt: 1_793_361_600 - Double($0) * 86400)
            }
            buckets[ModeRecordStore.scopeID(mode: .moves, detailValue: 30)] = (0..<9).map {
                ModeRecord(id: "utility-moves-\($0)", clearedCount: 75 - $0 * 5, swapsUsed: 30,
                           elapsedTime: 180 + Double($0) * 60, createdAt: 1_793_361_600 - Double($0) * 86400)
            }
            buckets[ModeRecordStore.scopeID(mode: .timed, detailValue: 120)] = [
                ModeRecord(id: "other-rule", clearedCount: 999_999, swapsUsed: 90, elapsedTime: 120, createdAt: 0)
            ]
        }
        defaults.set(try JSONEncoder().encode(buckets), forKey: ModeRecordStore.storageKey)
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
        XCTAssertTrue(labels(content).contains("92"))
        XCTAssertFalse(labels(content).contains { $0.contains("999999") || $0.contains("999,999") })
        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
        XCTAssertTrue(labels(content).contains("75"))
        XCTAssertFalse(labels(content).contains("92"))
        _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 99, swapsUsed: 30, elapsedTime: 60)
        panel.refresh(mode: .timed, volume: 0.7)
        XCTAssertEqual(tabs.selectedSegment, 1)
        XCTAssertTrue(labels(content).contains("75"))
        tabs.selectedSegment = 0; tabs.sendAction(tabs.action, to: tabs.target)
        XCTAssertTrue(labels(content).contains("99"))
        XCTAssertTrue(labels(content).contains(AchievementText.format("records.metric.cleared", 99)))
        XCTAssertEqual(store.records(for: .timed, detailValue: 60).count, 9)
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
            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.timed")))
            XCTAssertTrue(text.contains(AchievementText.string("home.mode_desc.moves")))
            XCTAssertEqual(text.filter { $0 == AchievementText.string("utility.rules.current") }.count, 1)
        }
        XCTAssertTrue(store.records(for: .timed, detailValue: 60).isEmpty)
        XCTAssertTrue(store.records(for: .moves, detailValue: 30).isEmpty)
    }

    func testOldRulesRecordsOnlyAppearInExplicitHistorySection() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let old = LegacyModeRecord(id: "legacy-player-record", score: 450, elapsedTime: 60,
                                   durationMinutes: 1, targetScore: nil, createdAt: 1_793_361_600)
        let bytes = try JSONEncoder().encode(["score_attack_1": [old]])
        defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
        let store = ModeRecordStore(defaults: defaults)
        _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
        let panel = HomeUtilityPanel(page: "records", store: store)
        defer { panel.close() }
        panel.refresh(mode: .timed, volume: 0.3)
        let content = try XCTUnwrap(panel.window?.contentView)
        XCTAssertTrue(labels(content).contains("12"))
        XCTAssertFalse(labels(content).contains { $0.contains("450") })
        let button = try XCTUnwrap(descendants(content).compactMap { $0 as? HomeButton }.first {
            $0.title == AchievementText.string("utility.records.show_history")
        })
        button.performClick(nil)
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(labels(content).contains { $0.contains("450") })
        XCTAssertEqual(store.records(for: .timed, detailValue: 60).map(\.clearedCount), [12])
        XCTAssertEqual(defaults.data(forKey: ModeRecordStore.legacyStorageKey), bytes)
        try export(content, name: "utility-records-history")
    }

    func testEqualCountsHaveSharedVisibleRanksRegardlessOfTime() throws {
        _ = NSApplication.shared
        let store = ModeRecordStore(defaults: defaults)
        for (count, seconds) in [(90, 5.0), (90, 500.0), (80, 1.0)] {
            _ = store.addRecord(mode: .moves, detailValue: 30, clearedCount: count, swapsUsed: 30, elapsedTime: seconds)
        }
        let panel = HomeUtilityPanel(page: "records", store: store)
        defer { panel.close() }
        panel.refresh(mode: .moves, volume: 0.4)
        let content = try XCTUnwrap(panel.window?.contentView)
        let tabs = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
        tabs.selectedSegment = 1; tabs.sendAction(tabs.action, to: tabs.target)
        let rowLabels = descendants(content).compactMap { $0.accessibilityLabel() }
        XCTAssertEqual(rowLabels.filter { $0.hasPrefix("1.") }.count, 2)
        XCTAssertEqual(rowLabels.filter { $0.hasPrefix("3.") }.count, 1)
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
