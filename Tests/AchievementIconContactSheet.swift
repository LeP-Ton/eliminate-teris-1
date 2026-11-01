import Cocoa
@testable import EliminateTeris1

/// 仅测试使用的静态图标总览，正式应用没有预览入口或预览页面。
final class AchievementIconContactSheet: NSView {
    override var isFlipped: Bool { true }
    static let width: CGFloat = 760
    static let cell: CGFloat = 126
    static let height: CGFloat = 8 * cell + 40

    override func draw(_ dirtyRect: NSRect) {
        HomeStyle.background.setFill(); bounds.fill()
        HomeStyle.text("成就徽章 · 测试总览", in: NSRect(x: 16, y: 8, width: bounds.width - 32, height: 28), size: 18, weight: .bold)
        let width = bounds.width / 4
        for (index, definition) in AchievementDefinition.all.enumerated() {
            let rect = NSRect(x: CGFloat(index % 4) * width, y: 40 + CGFloat(index / 4) * Self.cell, width: width, height: Self.cell)
            AchievementIconCatalog.image(for: definition).draw(in: NSRect(x: rect.midX - 30, y: rect.minY + 8, width: 60, height: 60),
                                                               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            HomeStyle.text(AchievementText.string(definition.titleKey), in: NSRect(x: rect.minX + 4, y: rect.minY + 78, width: width - 8, height: 22),
                           size: 13, weight: .semibold, alignment: .center)
            HomeStyle.text(String(format: "%02d", definition.id), in: NSRect(x: rect.minX, y: rect.minY + 103, width: width, height: 18),
                           size: 10, color: HomeStyle.secondary, alignment: .center)
        }
    }
}
