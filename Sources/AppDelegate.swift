import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewController = GameViewController()
        let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: min(1180, max(960, available.width - 64)), height: min(800, max(720, available.height - 80))),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = Localizer.shared.string("window.title")
        window.appearance = NSAppearance(named: .aqua)
        window.contentMinSize = NSSize(width: 960, height: 720)
        window.contentViewController = viewController
        window.makeFirstResponder(viewController)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
