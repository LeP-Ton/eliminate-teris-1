import Cocoa

private final class HomeUtilityBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
}

private final class HomeAuxiliaryWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 顶部导航的辅助面板，不覆盖主窗口的游戏状态与 Touch Bar 焦点。
final class HomeUtilityPanel: NSWindowController {
    let page: String
    var onLanguage: ((AppLanguage) -> Void)?
    var onVolume: ((Float) -> Void)?
    private let titleLabel = NSTextField(labelWithString: "")
    private let body = NSTextView()
    private let languageLabel = NSTextField(labelWithString: "")
    private let language = NSPopUpButton(frame: .zero, pullsDown: false)
    private let volumeLabel = NSTextField(labelWithString: "")
    private let volume = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let percent = NSTextField(labelWithString: "")
    private let store: ModeRecordStore

    init(page: String, store: ModeRecordStore = .shared) {
        self.page = page; self.store = store
        let panel = HomeAuxiliaryWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: page == "settings" ? 270 : 480),
                                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = HomeStyle.background
        panel.hidesOnDeactivate = true
        panel.contentView = HomeUtilityBackgroundView(frame: NSRect(origin: .zero, size: panel.contentLayoutRect.size))
        super.init(window: panel)
        guard let content = panel.contentView else { return }
        titleLabel.frame = NSRect(x: 24, y: content.bounds.height - 65, width: 452, height: 38)
        titleLabel.font = .systemFont(ofSize: 25, weight: .bold); titleLabel.textColor = HomeStyle.ink
        content.addSubview(titleLabel)
        if page == "settings" {
            for label in [languageLabel, volumeLabel, percent] { label.font = .systemFont(ofSize: 15); label.textColor = HomeStyle.ink; content.addSubview(label) }
            languageLabel.frame = NSRect(x: 26, y: 141, width: 90, height: 26)
            language.frame = NSRect(x: 135, y: 136, width: 325, height: 34)
            language.font = .systemFont(ofSize: 15); language.target = self; language.action = #selector(languageChanged)
            volumeLabel.frame = NSRect(x: 26, y: 75, width: 90, height: 26)
            volume.frame = NSRect(x: 135, y: 74, width: 245, height: 28)
            percent.frame = NSRect(x: 398, y: 74, width: 68, height: 28)
            volume.target = self; volume.action = #selector(volumeChanged)
            content.addSubview(language); content.addSubview(volume)
        } else {
            let scroll = NSScrollView(frame: NSRect(x: 22, y: 24, width: 456, height: content.bounds.height - 105))
            scroll.hasVerticalScroller = true; scroll.drawsBackground = false
            body.isEditable = false; body.isSelectable = true; body.drawsBackground = false
            body.font = .systemFont(ofSize: 15); body.textColor = HomeStyle.ink
            body.isVerticallyResizable = true; body.isHorizontallyResizable = false
            body.autoresizingMask = [.width]; body.textContainer?.widthTracksTextView = true
            body.frame = scroll.bounds; scroll.documentView = body
            content.addSubview(scroll)
        }
    }
    required init?(coder: NSCoder) { nil }

    func refresh(mode: HomeGameMode, volume value: Float) {
        let key = "panel.\(page)"
        titleLabel.stringValue = AchievementText.string(key); window?.title = titleLabel.stringValue
        if page == "settings" {
            languageLabel.stringValue = AchievementText.string("language.label")
            volumeLabel.stringValue = AchievementText.string("volume.label")
            language.removeAllItems()
            language.addItems(withTitles: AppLanguage.allCases.map { AchievementText.string($0.titleKey) })
            language.selectItem(at: AppLanguage.allCases.firstIndex(of: Localizer.shared.language) ?? 0)
            volume.doubleValue = Double(value); percent.stringValue = "\(Int(value * 100))%"
        } else if page == "rules" {
            body.string = "• " + AchievementText.string("rules.core.line1") + "\n\n• " + AchievementText.string("rules.core.line2")
                + "\n\n• " + AchievementText.string("home.mode_desc.\(mode.key)") + "\n\n• " + AchievementText.string("home.rules.fixed")
        } else {
            var lines = [AchievementText.string("home.records.fixed"), ""]
            let formatter = DateFormatter(); formatter.locale = Localizer.shared.locale; formatter.dateStyle = .medium
            for (recordMode, detail, titleKey) in [(ModeRecordKey.scoreAttack, 1, "home.mode.score_attack"), (.speedRun, 300, "home.mode.speed_run")] {
                lines.append(AchievementText.string(titleKey))
                let entries = store.records(for: recordMode, detailValue: detail)
                if entries.isEmpty { lines.append(AchievementText.string("records.empty")) }
                for (index, entry) in entries.enumerated() {
                    let metric = recordMode == .scoreAttack ? AchievementText.format("records.metric.score", entry.score) : String(format: "%.2f s", entry.elapsedTime)
                    lines.append("\(index + 1).  \(metric)    \(formatter.string(from: Date(timeIntervalSince1970: entry.createdAt)))")
                }
                lines.append("")
            }
            body.string = lines.joined(separator: "\n")
        }
        // 文本视图只在竖直方向扩展，让较多历史记录可正常滚动。
        if page != "settings" { body.sizeToFit() }
    }

    func present(from parent: NSWindow?) {
        guard let window else { return }
        if let parent {
            let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
            let x = min(max(parent.frame.midX - window.frame.width / 2, available.minX + 8), available.maxX - window.frame.width - 8)
            let y = min(max(parent.frame.midY - window.frame.height / 2, available.minY + 8), available.maxY - window.frame.height - 8)
            window.setFrameOrigin(NSPoint(x: x, y: y))
            if window.parent !== parent { window.parent?.removeChildWindow(window); parent.addChildWindow(window, ordered: .above) }
        } else { window.center() }
        window.orderFront(nil)
    }
    @objc private func languageChanged() {
        onLanguage?(AppLanguage.allCases[max(0, language.indexOfSelectedItem)])
    }
    @objc private func volumeChanged() {
        percent.stringValue = "\(Int(volume.doubleValue * 100))%"
        onVolume?(Float(volume.doubleValue))
    }
}
