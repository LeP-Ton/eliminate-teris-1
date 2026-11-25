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
        let face = button.faceRect
        let plate = button.iconPlateRect
        let icon = button.modeIconRect
        let context = "\(button.mode?.key ?? "解谜")／\(button.bounds.width)／\(button.selected ? "选中" : "默认")"
        XCTAssertGreaterThan(face.minY - plate.minY, 2, context)
        XCTAssertGreaterThan(plate.maxY, face.minY, context)
        XCTAssertLessThan(plate.midX, face.midX, context)
        XCTAssertTrue(button.bounds.contains(plate), context)
        XCTAssertTrue(plate.contains(icon), context)

        let bitmap = try bitmap(of: button)
        let xScale = CGFloat(bitmap.pixelsWide) / button.bounds.width
        let yScale = CGFloat(bitmap.pixelsHigh) / button.bounds.height
        func color(at point: NSPoint) throws -> NSColor {
            try XCTUnwrap(bitmap.colorAt(x: Int(point.x * xScale), y: Int(point.y * yScale))?.usingColorSpace(.sRGB))
        }

        // 在主卡上沿上方横向取样，确认只有前层所在位置绘制了内容。
        let raisedY = (plate.minY + face.minY) / 2
        let raisedX = plate.midX + (plate.midY - raisedY) * HomeDashboardStyle.slope
        let raised = try color(at: NSPoint(x: raisedX, y: raisedY))
        let outside = try color(at: NSPoint(x: face.midX, y: raisedY))
        XCTAssertGreaterThan(raised.alphaComponent - outside.alphaComponent, 0.35, context)

        // 在图标矩形内寻找高对比笔画，避开前层和主卡的分隔描边。
        let ink = icon.insetBy(dx: 1, dy: 1)
        let columns = Int(ceil(ink.minX * xScale))..<Int(floor(ink.maxX * xScale))
        let rows = Int(ceil(ink.minY * yScale))..<Int(floor(ink.maxY * yScale))
        var visiblePixels = 0
        for y in rows {
            for x in columns {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.75, min(color.greenComponent, color.blueComponent) > 0.63 else { continue }
                visiblePixels += 1
            }
        }
        XCTAssertGreaterThan(visiblePixels, 8, context)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}

private final class ModeIconPlatePreview: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        HomeDashboardStyle.backdrop(in: bounds)
    }
}
