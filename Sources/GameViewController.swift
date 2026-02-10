import Cocoa

final class GameViewController: NSViewController, NSTouchBarDelegate {
    private let columns = 12
    private lazy var touchBarView = GameTouchBarView(columns: columns)
    private lazy var gameTouchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [.game]
        bar.principalItemIdentifier = .game
        bar.customizationAllowedItemIdentifiers = []
        bar.customizationRequiredItemIdentifiers = [.game]
        return bar
    }()

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 240))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view

        let label = NSTextField(labelWithString: "Activate this app and use the Touch Bar to play.\nDrag tiles to swap, match 3+ to clear.\nMulti-touch swaps are supported.")
        label.alignment = .center
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func makeTouchBar() -> NSTouchBar? {
        return gameTouchBar
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.touchBar = gameTouchBar
        view.window?.makeFirstResponder(self)
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == .game else { return nil }
        let item = NSCustomTouchBarItem(identifier: .game)
        item.view = touchBarView
        return item
    }
}

extension NSTouchBarItem.Identifier {
    static let game = NSTouchBarItem.Identifier("com.touchbarmatch.game")
}
