import Cocoa
import XCTest
@testable import EliminateTeris1

final class AchievementPresentationTests: AchievementTestCase {
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    func testLibraryFiltersAndPanelDoesNotTakeKeyboardFocus() throws {
        XCTAssertTrue(Thread.isMainThread)
        _ = NSApplication.shared
        swap()
        let panel = AchievementsWindowController(manager: manager)
        defer { panel.close() }
        panel.refresh()
        let window = try XCTUnwrap(panel.window)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
        let content = try XCTUnwrap(window.contentView)
        let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
        func progressBars() -> Int { descendants(content).filter { $0 is NSProgressIndicator }.count }
        XCTAssertEqual(progressBars(), 20)
        filter.selectedSegment = 2
        XCTAssertTrue(filter.sendAction(filter.action, to: filter.target))
        XCTAssertEqual(progressBars(), 1)
        filter.selectedSegment = 1
        filter.sendAction(filter.action, to: filter.target)
        XCTAssertEqual(progressBars(), 19)
    }

    func testLibraryRowsHaveUsableLayoutForEveryLanguage() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let panel = AchievementsWindowController(manager: manager)
        defer { panel.close() }
        let window = try XCTUnwrap(panel.window)
        let content = try XCTUnwrap(window.contentView)
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            XCTAssertNotEqual(Localizer.shared.string("achievement.1.title"), "achievement.1.title")
            panel.refresh()
            for width: CGFloat in [480, 600] {
                window.setContentSize(NSSize(width: width, height: 580))
                content.layoutSubtreeIfNeeded()
                let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }.first)
                let document = try XCTUnwrap(scroll.documentView)
                document.layoutSubtreeIfNeeded()
                XCTAssertGreaterThan(document.frame.height, scroll.contentView.bounds.height)
                for meter in descendants(document).compactMap({ $0 as? NSProgressIndicator }) {
                    XCTAssertGreaterThan(meter.frame.width, 300, language.rawValue)
                    XCTAssertGreaterThan(meter.frame.height, 0)
                }
            }
        }
    }

    func testBadgeStripShowsExactlyFiveWholeBadgesForBothScrollerStyles() throws {
        _ = NSApplication.shared
        let strip = AchievementBadgeStripView()
        strip.refresh(manager: manager)
        for style in [NSScroller.Style.legacy, .overlay] {
            strip.scrollerStyle = style
            for width: CGFloat in [500, 644, 900] {
                strip.frame = NSRect(x: 0, y: 0, width: width, height: AchievementBadgeStripView.preferredHeight)
                strip.needsLayout = true
                strip.layoutSubtreeIfNeeded()
                let document = try XCTUnwrap(strip.documentView)
                document.layoutSubtreeIfNeeded()
                let badges = document.subviews.compactMap { $0 as? AchievementBadgeButton }.sorted { $0.tag < $1.tag }
                let visible = document.visibleRect
                let complete = badges.filter { visible.contains($0.frame) }
                let intersecting = badges.filter { !visible.intersection($0.frame).isEmpty }
                XCTAssertEqual(complete.map(\.tag), [1, 2, 3, 4, 5])
                XCTAssertEqual(intersecting.count, 5, "不应在右侧露出半枚标签")
                XCTAssertGreaterThan(complete[0].frame.minY, visible.minY)
                XCTAssertLessThan(complete[0].frame.maxY, visible.maxY)
                XCTAssertGreaterThan(document.frame.width, visible.width)
            }
        }
    }

    func testBadgeContentIsCenteredAndStillClickableWithLongLocalizedNames() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        let strip = AchievementBadgeStripView()
        strip.frame = NSRect(x: 0, y: 0, width: 644, height: AchievementBadgeStripView.preferredHeight)
        var selected: Int?
        strip.onSelect = { selected = $0 }
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            strip.refresh(manager: manager)
            strip.needsLayout = true
            strip.layoutSubtreeIfNeeded()
            let document = try XCTUnwrap(strip.documentView)
            document.layoutSubtreeIfNeeded()
            for badge in document.subviews.compactMap({ $0 as? AchievementBadgeButton }) {
                badge.layoutSubtreeIfNeeded()
                let group = try XCTUnwrap(badge.subviews.first as? NSStackView)
                let image = try XCTUnwrap(group.arrangedSubviews.first as? NSImageView)
                let label = try XCTUnwrap(group.arrangedSubviews.last as? NSTextField)
                // AppKit 会对最终 frame 做像素对齐，独立视图允许一个像素的取整误差。
                let pixel = 1 / (strip.window?.backingScaleFactor ?? 1)
                XCTAssertEqual(group.frame.midX, badge.bounds.midX, accuracy: pixel)
                XCTAssertEqual(group.frame.midY, badge.bounds.midY, accuracy: pixel)
                XCTAssertEqual(image.frame.midY, label.frame.midY, accuracy: pixel)
                XCTAssertGreaterThanOrEqual(group.frame.minX, 8 - pixel)
                XCTAssertLessThanOrEqual(group.frame.maxX, badge.bounds.maxX - 8 + pixel)
                XCTAssertTrue(badge.toolTip?.contains(label.stringValue) == true)
                // hitTest 接收的是父视图坐标，分别点击图标和文字的中心。
                for child in [image, label] {
                    let point = child.convert(NSPoint(x: child.bounds.midX, y: child.bounds.midY), to: document)
                    XCTAssertTrue(badge.hitTest(point) === badge)
                }
                badge.performClick(nil)
                XCTAssertEqual(selected, badge.tag)
            }
        }
    }

    func testPanelCentersOnParentOnFirstOpenAndAfterParentMoves() throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main?.visibleFrame)
        let parent = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        let parentSize = NSSize(width: min(800, screen.width - 64), height: min(700, screen.height - 64))
        parent.setFrame(NSRect(x: screen.midX - parentSize.width / 2, y: screen.midY - parentSize.height / 2,
                               width: parentSize.width, height: parentSize.height), display: false)
        parent.orderFront(nil)
        let panel = AchievementsWindowController(manager: manager)
        defer { panel.close(); parent.close() }
        let window = try XCTUnwrap(panel.window)

        func verifyCentered() {
            XCTAssertEqual(window.frame.midX, parent.frame.midX, accuracy: 1)
            XCTAssertEqual(window.frame.midY, parent.frame.midY, accuracy: 1)
            XCTAssertTrue(window.parent === parent)
        }
        panel.present(from: parent)
        verifyCentered()
        // 面板已经可见时再次点击入口，也应从旧位置回到主窗口中央。
        window.setFrameOrigin(screen.origin)
        panel.present(from: parent, detailID: 1)
        verifyCentered()
        panel.close()
        parent.setFrameOrigin(NSPoint(x: parent.frame.minX + 24, y: parent.frame.minY + 16))
        panel.present(from: parent)
        verifyCentered()
    }

    func testPanelStaysWithinUsableScreenWhenParentIsNearEdge() throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main?.visibleFrame)
        let parent = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        parent.setFrame(NSRect(x: screen.minX, y: screen.maxY - 280, width: 300, height: 280), display: false)
        parent.orderFront(nil)
        let panel = AchievementsWindowController(manager: manager)
        defer { panel.close(); parent.close() }
        panel.present(from: parent)
        let window = try XCTUnwrap(panel.window)
        let available = try XCTUnwrap((parent.screen ?? NSScreen.main)?.visibleFrame)
        XCTAssertGreaterThanOrEqual(window.frame.minX, available.minX + 7)
        XCTAssertGreaterThanOrEqual(window.frame.minY, available.minY + 7)
        XCTAssertLessThanOrEqual(window.frame.maxX, available.maxX - 7)
        XCTAssertLessThanOrEqual(window.frame.maxY, available.maxY - 7)
        XCTAssertTrue(window.parent === parent)
        XCTAssertFalse(window.canBecomeKey)
    }

}
