import Cocoa
import QuartzCore
import ImageIO
import XCTest
@testable import EliminateTeris1

final class AchievementFilterControlTests: AchievementTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    private func filter(in controller: AchievementsWindowController) throws -> AchievementFilterControl {
        let content = try XCTUnwrap(controller.window?.contentView)
        content.layoutSubtreeIfNeeded()
        return try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
    }

    private func thumb(in filter: AchievementFilterControl) throws -> CALayer {
        try XCTUnwrap(filter.layer?.sublayers?.first { $0.name == "achievement-filter-selection" })
    }

    private func click(_ index: Int, on filter: AchievementFilterControl) throws {
        try click(NSPoint(x: filter.bounds.width * (CGFloat(index) + 0.5) / CGFloat(filter.segmentCount),
                          y: filter.bounds.midY), on: filter)
    }

    private func click(_ position: NSPoint, on filter: AchievementFilterControl) throws {
        let point = filter.convert(position, to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                                   windowNumber: filter.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        filter.mouseDown(with: event)
    }

    private func corners(of path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                points.append(element.pointee.points[0])
            }
        }
        return points
    }

    func testSelectionRimFillAndGlowFollowOuterSlantInBothPanels() throws {
        _ = NSApplication.shared
        let achievements = AchievementsWindowController(manager: manager)
        let records = HomeUtilityPanel(page: "records", store: ModeRecordStore(defaults: defaults))
        defer { achievements.close(); records.close() }
        achievements.refresh()
        records.refresh(mode: .free, volume: 0.5)

        for window in [try XCTUnwrap(achievements.window), try XCTUnwrap(records.window)] {
            for width: CGFloat in [480, 600] {
                window.setContentSize(NSSize(width: width, height: 580))
                let content = try XCTUnwrap(window.contentView)
                content.layoutSubtreeIfNeeded()
                let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? AchievementFilterControl }.first)
                filter.reducesMotion = { true }
                let layer = try thumb(in: filter)
                let mask = try XCTUnwrap(layer.sublayers?.first { $0.name == "achievement-filter-selection-fill" }?.mask as? CAShapeLayer)
                let rim = try XCTUnwrap(layer.sublayers?.first { $0.name == "achievement-filter-selection-rim" } as? CAShapeLayer)
                let outer = corners(of: HomeDashboardStyle.cgSlant(filter.bounds.insetBy(dx: 0.5, dy: 0.5)))
                let selected = corners(of: try XCTUnwrap(rim.path))
                XCTAssertEqual(selected, corners(of: try XCTUnwrap(mask.path)))
                XCTAssertEqual(selected, corners(of: try XCTUnwrap(layer.shadowPath)))
                XCTAssertEqual(selected, corners(of: HomeDashboardStyle.cgSlant(layer.bounds.insetBy(dx: 0.5, dy: 0.5))))
                guard outer.count == 4, selected.count == 4 else { return XCTFail("外框和选中层应为四边形") }
                // 外框和选中层高度不同，通过垂直距离归一后，左右两侧保持相同斜率。
                for points in [outer, selected] {
                    XCTAssertEqual((points[0].x - points[3].x) / (points[3].y - points[0].y), 0.45, accuracy: 0.001)
                    XCTAssertEqual((points[1].x - points[2].x) / (points[2].y - points[1].y), 0.45, accuracy: 0.001)
                }

                let track = filter.bounds.insetBy(dx: 4, dy: 4)
                let offset = HomeDashboardStyle.edgeOffset(for: track.height)
                let boundary = track.minX + (track.width - offset) / CGFloat(filter.segmentCount)
                // 相同的横坐标穿过斜分界，上缘属于第一段，下缘属于第二段。
                try click(NSPoint(x: boundary + offset / 2, y: track.maxY - 4), on: filter)
                XCTAssertEqual(filter.selectedSegment, 1)
                try click(NSPoint(x: boundary + offset / 2, y: track.minY + 4), on: filter)
                XCTAssertEqual(filter.selectedSegment, 0)
            }
        }
    }

    func testAnimatedSelectionSurvivesRefreshAndRapidChanges() throws {
        _ = NSApplication.shared
        swap(roundCleared: 10)
        let controller = AchievementsWindowController(manager: manager)
        defer { controller.close() }
        controller.refresh()
        controller.window?.orderFront(nil)
        let filter = try filter(in: controller)
        filter.reducesMotion = { false }
        let layer = try thumb(in: filter)
        let initial = layer.frame
        try click(2, on: filter)
        XCTAssertEqual(filter.selectedSegment, 2)
        XCTAssertGreaterThan(layer.frame.minX, filter.bounds.midX)
        let animation = try XCTUnwrap(layer.animation(forKey: "filter-selection") as? CAAnimationGroup)
        XCTAssertEqual(animation.duration, 0.24, accuracy: 0.001)
        XCTAssertEqual(animation.animations?.count, 2)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertNotNil(layer.animation(forKey: "filter-selection"), "刷新真实筛选结果不应取消滑块动画")
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.07))
        let interrupted = try XCTUnwrap(layer.presentation()).frame
        try click(1, on: filter)
        let next = try XCTUnwrap(layer.animation(forKey: "filter-selection") as? CAAnimationGroup)
        let start = try XCTUnwrap((next.animations?.first as? CABasicAnimation)?.fromValue as? NSValue).pointValue
        XCTAssertEqual(start.x, interrupted.midX, accuracy: 5, "连续切换应从当前视觉位置继续移动")
        try click(0, on: filter)
        XCTAssertEqual(filter.selectedSegment, 0)
        XCTAssertEqual(layer.frame, initial)
        let content = try XCTUnwrap(controller.window?.contentView)
        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 32)
    }

    func testReducedMotionKeyboardAndNativeCellSelection() throws {
        _ = NSApplication.shared
        let controller = AchievementsWindowController(manager: manager)
        defer { controller.close() }
        controller.refresh()
        let filter = try filter(in: controller)
        filter.reducesMotion = { true }
        let layer = try thumb(in: filter)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                 windowNumber: filter.window?.windowNumber ?? 0, context: nil,
                                                 characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124))
        filter.keyDown(with: event)
        XCTAssertEqual(filter.selectedSegment, 1)
        XCTAssertNil(layer.animation(forKey: "filter-selection"))
        filter.setSelected(true, forSegment: 2)
        filter.sendAction(filter.action, to: filter.target)
        XCTAssertEqual(filter.selectedSegment, 2)
        XCTAssertGreaterThan(layer.frame.minX, filter.bounds.midX)
        XCTAssertNil(layer.animation(forKey: "filter-selection"))
        let content = try XCTUnwrap(controller.window?.contentView)
        XCTAssertEqual(descendants(content).filter { $0 is NSProgressIndicator }.count, 0)
    }

    func testCountsAndSliderFitFiveLanguagesAndBothPanelWidths() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        swap(roundCleared: 10)
        let controller = AchievementsWindowController(manager: manager)
        defer { controller.close() }
        for language in AppLanguage.allCases {
            Localizer.shared.setLanguage(language)
            controller.refresh()
            for width: CGFloat in [480, 600] {
                controller.window?.setContentSize(NSSize(width: width, height: 580))
                let filter = try filter(in: controller)
                filter.reducesMotion = { true }
                XCTAssertEqual(filter.frame.height, 44, accuracy: 0.5)
                XCTAssertTrue(filter.toolTip(forSegment: 0)?.contains("32") == true)
                XCTAssertTrue(filter.toolTip(forSegment: 2)?.contains(String(manager.unlockedIDs().count)) == true)
                let layer = try thumb(in: filter)
                for index in 0..<3 {
                    try click(index, on: filter)
                    XCTAssertTrue(filter.bounds.contains(layer.frame), language.rawValue)
                    XCTAssertGreaterThan(layer.frame.height, 30)
                }
            }
        }
    }

    func testExportRealPanelAndAnimatedFilterPreview() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let unlocked = [1, 3, 4, 7, 9]
        let dates = Dictionary(uniqueKeysWithValues: unlocked.map { (String($0), Date().timeIntervalSince1970) })
        defaults.set(["version": 1, "unlocked": unlocked, "timestamps": dates,
                      "metrics": ["bestScore": 150, "totalCleared": 45, "rhythm": 2, "cascades": 2, "successfulSwaps": 5]],
                     forKey: AchievementsManager.storageKey)
        let fixture = AchievementsManager(defaults: defaults)
        let controller = AchievementsWindowController(manager: fixture)
        defer { controller.close() }
        controller.refresh()
        let window = try XCTUnwrap(controller.window)
        window.orderFront(nil)
        let content = try XCTUnwrap(window.contentView)
        let filter = try filter(in: controller)
        filter.reducesMotion = { false }
        content.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: panel)
        let directory = FileManager.default.temporaryDirectory
        try XCTUnwrap(panel.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent("eliminate-achievement-panel-refined.png"))

        // 导出实际 Core Animation 展示层，记录滑块位移，而非手工拼造设计稿。
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(directory.appendingPathComponent("eliminate-achievement-filter.gif") as CFURL,
                                                                       "com.compuserve.gif" as CFString, 40, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<40 {
            if frame == 8 { try click(1, on: filter) }
            if frame == 20 { try click(2, on: filter) }
            if frame == 32 { try click(0, on: filter) }
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(filter.bounds.width * 2),
                                                       pixelsHigh: Int(filter.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)).cgContext
            context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
            context.scaleBy(x: 2, y: -2)
            (filter.layer?.presentation() ?? filter.layer)?.render(in: context)
            let image = try XCTUnwrap(bitmap.cgImage)
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
            if frame == 0 || frame == 10 || frame == 22 {
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent("eliminate-filter-frame-\(frame).png"))
            }
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
