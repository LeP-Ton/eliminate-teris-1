import Cocoa
import ImageIO
import XCTest
@testable import EliminateTeris1

final class HomeTouchBarDemoTests: XCTestCase {
    func testEachGestureSwapsAdjacentTilesBeforeClearingItsOwnRun() throws {
        let examples: [(from: Int, to: Int, match: PieceKind)] = [
            (9, 8, .orangeRicky), (8, 9, .blueRicky), (11, 10, .clevelandZ)
        ]
        XCTAssertEqual(HomeTouchBarDemo.stepCount, examples.count)
        for (step, example) in examples.enumerated() {
            let start = Double(step) * HomeTouchBarDemo.stepDuration
            let holding = HomeTouchBarDemo.frame(at: start + 0.25)
            let initial = settledKinds(in: holding)
            XCTAssertNil(holding.gesture)

            // 手势期间棋盘保持静止，手指在两格之间移动。
            let gestureStart = HomeTouchBarDemo.frame(at: start + 0.96)
            let gestureEnd = HomeTouchBarDemo.frame(at: start + 1.45)
            XCTAssertEqual(settledKinds(in: gestureStart), initial)
            XCTAssertEqual(settledKinds(in: gestureEnd), initial)
            let firstGesture = try XCTUnwrap(gestureStart.gesture)
            let nextGesture = try XCTUnwrap(gestureEnd.gesture)
            for gesture in [firstGesture, nextGesture] {
                XCTAssertEqual(gesture.from, example.from)
                XCTAssertEqual(gesture.to, example.to)
                XCTAssertEqual(abs(gesture.from - gesture.to), 1)
                XCTAssertGreaterThan(gesture.opacity, 0)
            }
            XCTAssertGreaterThan(nextGesture.progress, firstGesture.progress)

            let moving = HomeTouchBarDemo.frame(at: start + 1.90)
            let involved = [example.from, example.to]
            let lower = CGFloat(min(example.from, example.to))
            let upper = CGFloat(max(example.from, example.to))
            let movingPair = moving.tiles.filter { $0.column > lower && $0.column < upper }
            XCTAssertEqual(movingPair.count, 2)
            XCTAssertEqual(Set(movingPair.map(\.kind)), Set(involved.map { initial[$0] }))
            for column in initial.indices where !involved.contains(column) {
                XCTAssertTrue(moving.tiles.contains { $0.column == CGFloat(column) && $0.kind == initial[column] })
            }

            var expected = initial
            expected.swapAt(example.from, example.to)
            let matched = expected.indices.dropLast(2).filter { index in
                expected[index] == expected[index + 1] && expected[index] == expected[index + 2]
            }
            let matchStart = try XCTUnwrap(matched.first)
            XCTAssertEqual(matched.count, 1, "交换应恰好形成一个三连")
            let matchedColumns = (matchStart..<(matchStart + 3)).map { CGFloat($0) }
            XCTAssertEqual(expected[matchStart], example.match)
            let highlighted = HomeTouchBarDemo.frame(at: start + 2.31)
            let settled = highlighted.tiles.sorted { $0.column < $1.column }
            XCTAssertEqual(settled.map(\.kind), expected)
            XCTAssertEqual(settled.filter { $0.highlight > 0.05 }.map(\.column), matchedColumns)

            let dissolving = HomeTouchBarDemo.frame(at: start + 2.70)
            for tile in dissolving.tiles where matchedColumns.contains(tile.column) {
                XCTAssertLessThan(tile.opacity, 1)
                XCTAssertLessThan(tile.scale, 1)
            }
            XCTAssertEqual(dissolving.tiles.filter { $0.opacity < 1 }.map(\.column).sorted(), matchedColumns)
            XCTAssertTrue(dissolving.tiles.filter { !matchedColumns.contains($0.column) }.allSatisfy { $0.opacity == 1 })
        }
    }

    func testRefillPreservesSurvivorOrderAndLoopReturnsToTheSameBoard() {
        let loop = HomeTouchBarDemo.loopDuration
        let duration = HomeTouchBarDemo.stepDuration
        XCTAssertEqual(loop, Double(HomeTouchBarDemo.stepCount) * duration, accuracy: 0.001)
        for step in 0..<HomeTouchBarDemo.stepCount {
            let start = Double(step) * duration
            let clearing = HomeTouchBarDemo.frame(at: start + 2.31)
            let survivors = clearing.tiles.filter { $0.highlight < 0.05 }.sorted { $0.column < $1.column }
            XCTAssertEqual(survivors.count, HomeTouchBarDemo.columnCount - 3)
            let refilling = HomeTouchBarDemo.frame(at: start + 2.96).tiles.sorted { $0.column < $1.column }
            XCTAssertEqual(refilling.count, HomeTouchBarDemo.columnCount)
            XCTAssertTrue(refilling.prefix(3).allSatisfy { $0.column < 0 }, "三个补位方块应从左边进入")
            let remaining = Array(refilling.dropFirst(3))
            XCTAssertEqual(remaining.map(\.kind), survivors.map(\.kind))
            XCTAssertTrue(zip(remaining, survivors).contains { moved, original in moved.column > original.column })
            for (index, pair) in zip(remaining, survivors).enumerated() {
                let (moved, original) = pair
                XCTAssertGreaterThanOrEqual(moved.column, original.column)
                XCTAssertLessThanOrEqual(moved.column, CGFloat(index + 3))
            }

            let beforeNextStep = HomeTouchBarDemo.frame(at: start + duration - 0.0001)
            let next = HomeTouchBarDemo.frame(at: start + duration + 0.10)
            let finalTiles = beforeNextStep.tiles.sorted { $0.column < $1.column }
            let nextKinds = settledKinds(in: next)
            XCTAssertEqual(finalTiles.map(\.kind), nextKinds)
            XCTAssertEqual(Array(nextKinds.dropFirst(3)), survivors.map(\.kind))
            for (column, tile) in finalTiles.enumerated() {
                XCTAssertEqual(tile.column, CGFloat(column), accuracy: 0.01)
                XCTAssertEqual(tile.opacity, 1, accuracy: 0.01)
            }
        }
        XCTAssertEqual(HomeTouchBarDemo.frame(at: loop), HomeTouchBarDemo.frame(at: 0))
    }

    func testReducedMotionKeepsBoardAndGestureStationary() throws {
        let still = HomeTouchBarDemo.frame(at: 0, animated: false)
        XCTAssertEqual(settledKinds(in: still), settledKinds(in: HomeTouchBarDemo.frame(at: 0)))
        let gesture = try XCTUnwrap(still.gesture)
        XCTAssertGreaterThan(gesture.opacity, 0)
        for elapsed in [0.9, 1.9, 2.7, 3.1, HomeTouchBarDemo.loopDuration - 0.01, HomeTouchBarDemo.loopDuration * 2] {
            XCTAssertEqual(HomeTouchBarDemo.frame(at: elapsed, animated: false), still)
        }
    }

    func testExportTouchBarDemoLoop() throws {
        _ = NSApplication.shared
        let view = TouchBarDemoPreview(frame: NSRect(x: 0, y: 0, width: 925, height: 112))
        let count = Int(ceil(HomeTouchBarDemo.loopDuration * 12))
        let delay = HomeTouchBarDemo.loopDuration / Double(count)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-touch-bar-demo-loop.gif")
        let gif = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, count, nil))
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let timing = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
        let sampleFrames = Set([0.25, 1.16, 1.92, 2.31, 3.12].map { Int(($0 / delay).rounded()) })
        var sampleImages: Set<Data> = []
        for index in 0..<count {
            view.demoFrame = HomeTouchBarDemo.frame(at: Double(index) * delay)
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if sampleFrames.contains(index) {
                sampleImages.insert(try XCTUnwrap(bitmap.representation(using: .png, properties: [:])))
            }
            CGImageDestinationAddImage(gif, try XCTUnwrap(bitmap.cgImage), timing)
        }
        XCTAssertTrue(CGImageDestinationFinalize(gif))
        XCTAssertEqual(sampleImages.count, sampleFrames.count, "准备、手势、交换、消除及补位应绘出不同的画面")
    }

    private func settledKinds(in frame: HomeTouchBarDemo.Frame) -> [PieceKind] {
        let tiles = frame.tiles.sorted { $0.column < $1.column }
        XCTAssertEqual(tiles.count, HomeTouchBarDemo.columnCount)
        for (column, tile) in tiles.enumerated() {
            XCTAssertEqual(tile.column, CGFloat(column))
            XCTAssertEqual(tile.opacity, 1)
            XCTAssertEqual(tile.lift, 0)
        }
        return tiles.map(\.kind)
    }
}

/// 只在测试中把同一套绘制代码导出为预览。
private final class TouchBarDemoPreview: NSView {
    var demoFrame = HomeTouchBarDemo.frame(at: 0) { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        HomeDashboardStyle.navy.setFill()
        bounds.fill()
        HomeLobbyArtwork.drawTouchBar(in: bounds, frame: demoFrame)
    }
}
