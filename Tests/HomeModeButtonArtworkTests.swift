import Cocoa
import XCTest
@testable import EliminateTeris1

final class HomeModeButtonArtworkTests: XCTestCase {
    private let modes: [HomeGameMode?] = [.free, nil, .timed, .moves]
    private let sizes = [NSSize(width: 480, height: 86), NSSize(width: 288, height: 58)]

    func testEveryModeIconRendersInsideTheRaisedPlate() throws {
        _ = NSApplication.shared
        for size in sizes {
            for mode in modes {
                let idle = try assertRaisedPlate(on: makeButton(mode: mode, size: size, selected: false))
                if mode != nil {
                    let selected = try assertRaisedPlate(on: makeButton(mode: mode, size: size, selected: true))
                    XCTAssertNotEqual(idle, selected, "选中态与默认态应保留可见区别")
                }
            }
        }
    }

    func testContactCardShowsTheRaisedIconAndLowerTrailingFeedback() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        for size in [NSSize(width: 302, height: 110), NSSize(width: 500, height: 148)] {
            let contact = HomeContactPanelView(frame: NSRect(origin: .zero, size: size))
            contact.layoutSubtreeIfNeeded()
            let feedback = try XCTUnwrap(contact.subviews.compactMap { $0 as? HomeButton }.first)
            let face = contact.faceRect
            let plate = contact.iconPlateRect
            let action = contact.feedbackPlateRect
            let context = "联系我们／\(size.width)×\(size.height)"
            XCTAssertTrue(contact.bounds.contains(feedback.frame), context)
            XCTAssertTrue(feedback.frame.contains(action), context)
            XCTAssertFalse(plate.intersects(feedback.frame), context)
            XCTAssertGreaterThan(action.midX, face.midX, context)

            let bitmap = try assertRaisedPlate(in: contact, face: face, plate: plate, icon: contact.contactIconRect, context: context)
            let projections = assertContactProjections(in: contact, context: context)
            let empty = NSPoint(x: face.minX + face.width * 0.12, y: projections.bottom.y)
            let emptyAlpha = try color(in: bitmap, size: size, at: empty).alphaComponent
            for point in [projections.left, projections.right, projections.bottom] {
                XCTAssertGreaterThan(try color(in: bitmap, size: size, at: point).alphaComponent - emptyAlpha, 0.35, context)
            }

            let titleArea = NSRect(x: plate.maxX + 2, y: face.minY + 2,
                                   width: face.maxX - plate.maxX - 4, height: action.minY - face.minY - 4)
            XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: titleArea), 8, context)
            let actionInk = action.insetBy(dx: HomeDashboardStyle.edgeOffset(for: action.height) + 3, dy: 3)
            XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: actionInk), 8, context)

            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-icon-plate-\(Int(size.width)).png")
            try png.write(to: preview)
        }
    }

    func testContactCardKeepsLocalProjectionsAcrossLobbySizes() {
        _ = NSApplication.shared
        for size in [NSSize(width: 960, height: 720), NSSize(width: 1585, height: 992)] {
            let lobby = HomeDashboardView(frame: NSRect(origin: .zero, size: size))
            lobby.layoutSubtreeIfNeeded()
            _ = assertContactProjections(in: lobby.contactPanel, context: "大厅／\(size.width)×\(size.height)")
        }
    }

    private func assertContactProjections(in contact: HomeContactPanelView, context: String)
        -> (left: NSPoint, right: NSPoint, bottom: NSPoint) {
        let face = contact.faceRect
        let icon = contact.iconPlateRect
        let action = contact.feedbackPlateRect
        // 左上图标只从联系卡自身少量伸出，在同一高度比较实际左斜边。
        let leftY = (face.minY + icon.maxY) / 2
        let faceLeft = face.minX + HomeDashboardStyle.edgeOffset(for: face.maxY - leftY)
        let iconLeft = icon.minX + HomeDashboardStyle.edgeOffset(for: icon.maxY - leftY)
        XCTAssertTrue((8...12).contains(faceLeft - iconLeft), context)
        XCTAssertEqual(face.minY - icon.minY, 7, accuracy: 1, context)
        let left = NSPoint(x: (iconLeft + faceLeft) / 2, y: leftY)

        // 右下按钮以同一高度的水平距离和底边垂直距离分别测量。
        let rightY = (action.minY + face.maxY) / 2
        XCTAssertGreaterThan(rightY, face.minY, context)
        XCTAssertLessThan(action.minY, face.maxY, context)
        XCTAssertLessThan(rightY, action.maxY, context)
        let faceRight = face.maxX - HomeDashboardStyle.edgeOffset(for: rightY - face.minY)
        let actionRight = action.maxX - HomeDashboardStyle.edgeOffset(for: rightY - action.minY)
        let vertical = action.maxY - face.maxY
        XCTAssertEqual(vertical, 12, accuracy: 0.1, context)
        XCTAssertEqual(actionRight - faceRight, vertical, accuracy: 0.1, context)
        let right = NSPoint(x: (faceRight + actionRight) / 2, y: rightY)
        let bottomY = (action.maxY + face.maxY) / 2
        let bottomX = action.midX - (bottomY - action.midY) * HomeDashboardStyle.slope
        return (left, right, NSPoint(x: bottomX, y: bottomY))
    }

    func testExportModeIconPlatePreview() throws {
        _ = NSApplication.shared
        let original = Localizer.shared.language
        defer { Localizer.shared.setLanguage(original) }
        Localizer.shared.setLanguage(.chineseSimplified)
        let preview = ModeIconPlatePreview(frame: NSRect(x: 0, y: 0, width: 830, height: 424))
        for (index, mode) in modes.enumerated() {
            let y = 17 + CGFloat(index) * 100
            let wide = makeButton(mode: mode, size: sizes[0], selected: mode != nil)
            wide.setFrameOrigin(NSPoint(x: 16, y: y))
            let compact = makeButton(mode: mode, size: sizes[1], selected: false)
            compact.setFrameOrigin(NSPoint(x: 522, y: y + 14))
            preview.addSubview(wide)
            preview.addSubview(compact)
        }
        let png = try XCTUnwrap(try bitmap(of: preview).representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-mode-icon-plates.png")
        try png.write(to: url)
    }

    private func makeButton(mode: HomeGameMode?, size: NSSize, selected: Bool) -> HomeModeButton {
        let button = HomeModeButton(mode: mode)
        button.frame = NSRect(origin: .zero, size: size)
        let otherMode: HomeGameMode = mode == .free ? .timed : .free
        button.refresh(selectedMode: selected ? (mode ?? otherMode) : otherMode)
        return button
    }

    private func bitmap(of view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private func assertRaisedPlate(on button: HomeModeButton) throws -> Data {
        let context = "\(button.mode?.key ?? "解谜")／\(button.bounds.width)／\(button.selected ? "选中" : "默认")"
        let bitmap = try assertRaisedPlate(in: button, face: button.faceRect, plate: button.iconPlateRect, icon: button.modeIconRect,
                                          context: context)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private func assertRaisedPlate(in view: NSView, face: NSRect, plate: NSRect, icon: NSRect,
                                   context: String) throws -> NSBitmapImageRep {
        XCTAssertGreaterThan(face.minY - plate.minY, 2, context)
        XCTAssertGreaterThan(plate.maxY, face.minY, context)
        XCTAssertLessThan(plate.midX, face.midX, context)
        XCTAssertTrue(view.bounds.contains(plate), context)
        XCTAssertTrue(plate.contains(icon), context)

        let bitmap = try bitmap(of: view)
        // 在主卡上沿上方横向取样，确认只有前层所在位置绘制了内容。
        let size = view.bounds.size
        let raisedY = (plate.minY + face.minY) / 2
        let raisedX = plate.midX + (plate.midY - raisedY) * HomeDashboardStyle.slope
        let raised = try color(in: bitmap, size: size, at: NSPoint(x: raisedX, y: raisedY))
        let outside = try color(in: bitmap, size: size, at: NSPoint(x: face.midX, y: raisedY))
        XCTAssertGreaterThan(raised.alphaComponent - outside.alphaComponent, 0.35, context)

        // 在图标矩形内寻找高对比笔画，避开前层和主卡的分隔描边。
        XCTAssertGreaterThan(visibleInk(in: bitmap, size: size, area: icon.insetBy(dx: 1, dy: 1)), 8, context)
        return bitmap
    }

    private func color(in bitmap: NSBitmapImageRep, size: NSSize, at point: NSPoint) throws -> NSColor {
        let x = Int(point.x * CGFloat(bitmap.pixelsWide) / size.width)
        let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / size.height)
        return try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    }

    private func visibleInk(in bitmap: NSBitmapImageRep, size: NSSize, area: NSRect) -> Int {
        guard area.width > 1, area.height > 1 else { return 0 }
        let xScale = CGFloat(bitmap.pixelsWide) / size.width
        let yScale = CGFloat(bitmap.pixelsHigh) / size.height
        let columns = Int(ceil(area.minX * xScale))..<Int(floor(area.maxX * xScale))
        let rows = Int(ceil(area.minY * yScale))..<Int(floor(area.maxY * yScale))
        var visiblePixels = 0
        for y in rows {
            for x in columns {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.75, min(color.greenComponent, color.blueComponent) > 0.63 else { continue }
                visiblePixels += 1
            }
        }
        return visiblePixels
    }
}

private final class ModeIconPlatePreview: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        HomeDashboardStyle.backdrop(in: bounds)
    }
}
