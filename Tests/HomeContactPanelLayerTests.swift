import Cocoa
import XCTest
@testable import EliminateTeris1

final class HomeContactPanelLayerTests: XCTestCase {
    func testContactAlignsThePlateTopsAndPreservesTheLowerFadeAndFeedbackLink() throws {
        _ = NSApplication.shared
        let language = Localizer.shared.language
        defer { Localizer.shared.setLanguage(language) }
        Localizer.shared.setLanguage(.chineseSimplified)

        let sizes = [(NSSize(width: 302, height: 110), false), (NSSize(width: 500, height: 148), false),
                     (NSSize(width: 302, height: 165), true)]
        for (size, keepsRightEdgeInBounds) in sizes {
            let card = HomeContactPanelView(frame: NSRect(origin: .zero, size: size))
            card.layoutSubtreeIfNeeded()
            let upper = card.upperPlateRect
            let lower = card.lowerPlateRect
            let context = "联系我们／\(size.width)×\(size.height)"
            XCTAssertTrue(card.bounds.contains(upper), context)
            XCTAssertTrue(card.bounds.contains(lower), context)
            XCTAssertEqual(upper.minX, card.bounds.minX, accuracy: 0.01, context)
            XCTAssertEqual(upper.minY, card.bounds.minY, accuracy: 0.01, context)
            XCTAssertEqual(lower.minY, upper.minY, accuracy: 0.01, context)
            XCTAssertEqual(lower.minX, card.bounds.minX + size.height * 0.11, accuracy: 0.01, context)
            XCTAssertEqual(lower.maxY, card.bounds.maxY, accuracy: 0.01, context)
            XCTAssertGreaterThan(lower.maxY, upper.maxY, context)
            XCTAssertEqual(upper.height / size.height, 0.70, accuracy: 0.01, context)
            let overlap = upper.maxY - lower.minY
            XCTAssertEqual(overlap / size.height, 0.70, accuracy: 0.01, context)

            let oldLowerHeight = size.height * 0.55
            let oldLowerTop = card.bounds.maxY - oldLowerHeight
            let oldLowerWidth = card.bounds.maxX - lower.minX
            let oldUpperWidth = oldLowerWidth + HomeDashboardStyle.edgeOffset(for: upper.height - oldLowerHeight)
                - min(26, size.width * 0.05)
            XCTAssertEqual(upper.width, oldUpperWidth * 0.98, accuracy: 0.01, context)

            // 沿用原下板左斜边，并在旧上沿高度核对右边的 8% 内收。
            let oldTopEdges = edges(of: lower, at: oldLowerTop)
            XCTAssertEqual(oldTopEdges.left, lower.minX + HomeDashboardStyle.edgeOffset(for: oldLowerHeight), accuracy: 0.01, context)
            let trimmedRight = card.bounds.maxX - oldLowerWidth * 0.08
            let extendedRight = trimmedRight + HomeDashboardStyle.edgeOffset(for: oldLowerTop - upper.minY)
            if keepsRightEdgeInBounds {
                XCTAssertGreaterThan(extendedRight, card.bounds.maxX, context)
                XCTAssertEqual(lower.maxX, card.bounds.maxX, accuracy: 0.01, context)
            } else {
                XCTAssertLessThan(extendedRight, card.bounds.maxX, context)
                XCTAssertEqual(oldTopEdges.right, trimmedRight, accuracy: 0.01, context)
            }

            let joinY = lower.minY + overlap / 2
            let upperJoin = edges(of: upper, at: joinY)
            let lowerJoin = edges(of: lower, at: joinY)
            XCTAssertGreaterThan(lowerJoin.left - upperJoin.left, 2, context)
            XCTAssertGreaterThan(lowerJoin.right - upperJoin.right, 2, context)

            let feedback = try XCTUnwrap(card.subviews.compactMap { $0 as? HomeButton }.first)
            XCTAssertEqual(feedback.style, .feedbackLink, context)
            XCTAssertTrue(lower.contains(feedback.frame), context)
            XCTAssertGreaterThanOrEqual(feedback.frame.minY, upper.maxY - 0.1, context)
            let face = HomeDashboardStyle.slant(lower)
            let button = feedback.frame.insetBy(dx: 1.2, dy: 1.2)
            for y in [button.minY + 0.5, button.maxY - 0.5] {
                let edge = edges(of: button, at: y)
                XCTAssertTrue(face.contains(NSPoint(x: edge.left + 0.5, y: y)), context)
                XCTAssertTrue(face.contains(NSPoint(x: edge.right - 0.5, y: y)), context)
            }

            let bitmap = try render(card)
            func alpha(at point: NSPoint) throws -> CGFloat {
                let x = Int(point.x * CGFloat(bitmap.pixelsWide) / size.width)
                let y = Int(point.y * CGFloat(bitmap.pixelsHigh) / size.height)
                return try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
            }

            let upperOnlyY = upper.minY + upper.height / 4
            let anchoredLeft = edges(of: upper, at: upperOnlyY).left
            let upperOnly = NSPoint(x: (anchoredLeft + edges(of: lower, at: upperOnlyY).left) / 2, y: upperOnlyY)
            XCTAssertGreaterThan(try alpha(at: upperOnly), 0.55, context)
            XCTAssertLessThan(try alpha(at: NSPoint(x: anchoredLeft - 3, y: upperOnly.y)), 0.10, context)
            XCTAssertGreaterThan(try alpha(at: NSPoint(x: anchoredLeft + 3, y: upperOnly.y)), 0.90, context)

            // 采样点落在重叠区仅属于下板的右边，核对同顶后仍保有渐隐。
            func lowerRight(at fraction: CGFloat) -> NSPoint {
                let y = lower.minY + overlap * fraction
                let right = (edges(of: upper, at: y).right + edges(of: lower, at: y).right) / 2
                return NSPoint(x: right, y: y)
            }
            let beginningPoint = lowerRight(at: 0.12)
            let beginning = try alpha(at: beginningPoint)
            let nearJoin = try alpha(at: lowerRight(at: 0.88))
            let upperRight = edges(of: upper, at: beginningPoint.y).right
            // 在额外收短的狭带中心采样，应露出同高度的下板渐隐。
            let newlyExposed = NSPoint(x: upperRight + (oldUpperWidth - upper.width) / 2, y: beginningPoint.y)
            XCTAssertEqual(try alpha(at: newlyExposed), beginning, accuracy: 0.05, context)
            let stillCovered = NSPoint(x: upperRight - 3, y: beginningPoint.y)
            XCTAssertGreaterThan(try alpha(at: stillCovered), 0.90, context)
            let bottomY = upper.maxY + (lower.maxY - upper.maxY) * 0.75
            let bottom = NSPoint(x: edges(of: lower, at: bottomY).left + 18, y: bottomY)
            let lowerAlpha = try alpha(at: bottom)
            XCTAssertTrue((0.04...0.40).contains(beginning), context)
            XCTAssertTrue((0.50...0.88).contains(nearJoin), context)
            XCTAssertGreaterThan(nearJoin - beginning, 0.30, context)
            XCTAssertGreaterThan(lowerAlpha, 0.90, context)

            try assertUnframedFeedback(feedback, context: context)

            var opened: URL?
            card.openURL = { opened = $0 }
            feedback.performClick(nil)
            XCTAssertEqual(opened?.absoluteString, "https://github.com/LeP-Ton/eliminate-teris-1/issues", context)

            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            let label = keepsRightEdgeInBounds ? "\(Int(size.width))x\(Int(size.height))" : "\(Int(size.width))"
            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-contact-layered-\(label).png")
            try png.write(to: preview)
        }
    }

    private func edges(of plate: NSRect, at y: CGFloat) -> (left: CGFloat, right: CGFloat) {
        (plate.minX + HomeDashboardStyle.edgeOffset(for: plate.maxY - y),
         plate.maxX - HomeDashboardStyle.edgeOffset(for: y - plate.minY))
    }

    private func render(_ view: NSView) throws -> NSBitmapImageRep {
        view.needsDisplay = true
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private func assertUnframedFeedback(_ feedback: HomeButton, context: String) throws {
        defer { feedback.feedback.update(hover: false, press: false, animated: false) }
        for hovering in [false, true] {
            feedback.feedback.update(hover: hovering, press: false, animated: false)
            let bitmap = try render(feedback)
            let scale = CGFloat(bitmap.pixelsHigh) / feedback.bounds.height
            // 单独缓存按钮，顶部仍透明，中央保留图标和文字的像素。
            for y in 0..<Int(ceil(3 * scale)) {
                let edge = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: y))
                XCTAssertLessThan(edge.alphaComponent, 0.10, context)
            }
            let containsInk = (bitmap.pixelsHigh / 4..<(bitmap.pixelsHigh * 3 / 4)).contains { y in
                (bitmap.pixelsWide / 4..<(bitmap.pixelsWide * 3 / 4)).contains { x in
                    (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.80
                }
            }
            XCTAssertTrue(containsInk, context)
        }
    }
}
