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
        let previous = LegacyModeRecord(id: "legacy-player-previous", score: 390, elapsedTime: 60,
                                        durationMinutes: 1, targetScore: nil, createdAt: 1_793_275_200)
        let bytes = try JSONEncoder().encode(["score_attack_1": [old, previous]])
        defaults.set(bytes, forKey: ModeRecordStore.legacyStorageKey)
        let store = ModeRecordStore(defaults: defaults)
        _ = store.addRecord(mode: .timed, detailValue: 60, clearedCount: 12, swapsUsed: 4, elapsedTime: 60)
        let panel = HomeUtilityPanel(page: "records", store: store)
        defer { panel.close() }
        panel.refresh(mode: .timed, volume: 0.3)
        let content = try XCTUnwrap(panel.window?.contentView as? UtilityPageView)
        XCTAssertTrue(labels(content).contains("12"))
        XCTAssertFalse(labels(content).contains { $0.contains("450") })
        let button = try XCTUnwrap(descendants(content).compactMap { $0 as? HomeButton }.first {
            $0.title == AchievementText.string("utility.records.show_history")
        })
        button.performClick(nil)
        content.layoutSubtreeIfNeeded()
        let historyCards = try [old, previous].map {
            try card(containing: AchievementText.format("records.metric.score", $0.score), in: content)
        }
        try assertStackedCards(historyCards, in: content.document)
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
            let lessonBodies = (0..<3).map { AchievementText.string("utility.lesson.\($0).body") }
            for page in ["settings", "rules", "records"] {
                let panel = HomeUtilityPanel(page: page, store: store)
                defer { panel.close() }
                panel.refresh(mode: .free, volume: 0.26)
                let window = try XCTUnwrap(panel.window)
                let content = try XCTUnwrap(window.contentView as? UtilityPageView)
                let originalSize = content.bounds.size
                for size in [originalSize, NSSize(width: 480, height: 420)] {
                    window.setContentSize(size); content.layoutSubtreeIfNeeded()
                    XCTAssertEqual(content.bounds.width, size.width, accuracy: 1)
                    XCTAssertFalse(labels(content).contains { $0.hasPrefix("utility.") })
                    XCTAssertGreaterThan(content.document.bounds.height, 100)
                    XCTAssertLessThanOrEqual(content.document.frame.width, content.scroll.contentView.bounds.width + 1)
                    XCTAssertEqual(content.scroll.contentView.bounds.minY, 0, accuracy: 1, "初次打开应从顶部显示")
                    let cards = descendants(content).compactMap { $0 as? UtilityCard }
                    XCTAssertFalse(cards.isEmpty)
                    if page == "rules" {
                        let lessonCards = try lessonBodies.map { try card(containing: $0, in: content) }
                        try assertStackedCards(lessonCards, in: content.document)
                        for (index, lessonCard) in lessonCards.enumerated() {
                            XCTAssertTrue(labels(lessonCard).contains(AchievementText.string("utility.lesson.\(index).title")))
                        }
                    } else if page == "records" {
                        try assertRecordCards(store.records(for: .timed, detailValue: 60), in: content)
                    }
                    for card in cards {
                        XCTAssertGreaterThan(card.frame.height, 20)
                        XCTAssertGreaterThan(card.frame.width, 200)
                        for label in descendants(card).compactMap({ $0 as? NSTextField }) {
                            let rect = card.convert(label.bounds, from: label)
                            // 用矩形顶边检查缩进最深的左侧，用底边检查收窄最深的右侧。
                            let left = card.bounds.minX + 0.45 * (card.bounds.maxY - rect.minY)
                            let right = card.bounds.maxX - 0.45 * (rect.maxY - card.bounds.minY)
                            XCTAssertGreaterThanOrEqual(rect.minX, left - 1, "\(page) / \(language): \(label.stringValue)")
                            XCTAssertLessThanOrEqual(rect.maxX, right + 1, "\(page) / \(language): \(label.stringValue)")
                            if page == "rules", lessonBodies.contains(label.stringValue) {
                                let textBounds = label.attributedStringValue.boundingRect(
                                    with: NSSize(width: max(1, rect.width - 4), height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading])
                                XCTAssertGreaterThanOrEqual(rect.height + 2, ceil(textBounds.height), label.stringValue)
                            }
                        }
                    }
                    if page == "rules", language == .chineseSimplified || language == .russian {
                        for card in cards { try assertFullLengthSlantedEdges(of: card) }
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
                        try assertRecordCards(store.records(for: .moves, detailValue: 30), in: content)
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

    private func card(containing text: String, in parent: NSView) throws -> UtilityCard {
        let label = try XCTUnwrap(descendants(parent).compactMap { $0 as? NSTextField }.first { $0.stringValue == text })
        let ancestors = sequence(first: label as NSView, next: { $0.superview })
        return try XCTUnwrap(ancestors.first { $0 is UtilityCard } as? UtilityCard, "该行应有独立卡片 \(text)")
    }

    private func assertStackedCards(_ cards: [UtilityCard], in document: NSView) throws {
        XCTAssertEqual(Set(cards.map(ObjectIdentifier.init)).count, cards.count, "每一行要用不同的卡片")
        let frames = cards.map { document.convert($0.bounds, from: $0) }
        let first = try XCTUnwrap(frames.first)
        for frame in frames.dropFirst() {
            XCTAssertEqual(frame.minX, first.minX, accuracy: 0.5)
            XCTAssertEqual(frame.width, first.width, accuracy: 0.5)
        }
        let gaps = zip(frames, frames.dropFirst()).map { $0.1.minY - $0.0.maxY }
        let firstGap = try XCTUnwrap(gaps.first)
        XCTAssertGreaterThan(firstGap, 0, "相邻卡片之间应留有间距")
        for gap in gaps.dropFirst() { XCTAssertEqual(gap, firstGap, accuracy: 0.5) }
    }

    private func assertRecordCards(_ records: [ModeRecord], in content: UtilityPageView) throws {
        let header = try card(containing: AchievementText.string("utility.records.rank"), in: content)
        let rows = try records.map {
            try card(containing: AchievementText.format("records.metric.cleared", $0.clearedCount), in: content)
        }
        try assertStackedCards([header] + rows, in: content.document)
        func columns(in card: UtilityCard) throws -> [NSRect] {
            let row = try XCTUnwrap(card.subviews.compactMap { $0 as? NSStackView }.first)
            XCTAssertEqual(row.arrangedSubviews.count, 3)
            // 文本框的外框还包含系统边距，三列按原生布局的对齐框比较。
            return row.arrangedSubviews.map { column in
                content.document.convert(column.alignmentRect(forFrame: column.frame), from: column.superview)
            }
        }
        let headerColumns = try columns(in: header)
        for card in rows {
            for (column, expected) in zip(try columns(in: card), headerColumns) {
                XCTAssertEqual(column.minX, expected.minX, accuracy: 1)
                XCTAssertEqual(column.maxX, expected.maxX, accuracy: 1)
            }
        }
    }

    private func assertFullLengthSlantedEdges(of card: UtilityCard) throws {
        let scale: CGFloat = 2
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(ceil(card.bounds.width * scale)),
            pixelsHigh: Int(ceil(card.bounds.height * scale)), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)).cgContext
        context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        context.scaleBy(x: scale, y: -scale)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previous }
        // 单独渲染卡片边框，避免滚动区或文案干扰透明轮廓采样。
        card.draw(card.bounds)
        for fraction: CGFloat in [0.12, 0.36, 0.64, 0.88] {
            let row = Int(card.bounds.height * fraction * scale)
            let y = (CGFloat(row) + 0.5) / scale
            let pixels = 0..<bitmap.pixelsWide
            let isOpaque: (Int) -> Bool = { (bitmap.colorAt(x: $0, y: row)?.alphaComponent ?? 0) > 0.85 }
            let left = try XCTUnwrap(pixels.first(where: isOpaque))
            let right = try XCTUnwrap(pixels.last(where: isOpaque))
            XCTAssertEqual(CGFloat(left) / scale, (card.bounds.height - y) * 0.45, accuracy: 1.25, "左边应从顶到底连续倾斜")
            XCTAssertEqual(CGFloat(right) / scale, card.bounds.width - y * 0.45, accuracy: 1.25, "右边应从顶到底连续倾斜")
        }
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
