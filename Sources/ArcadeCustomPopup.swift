import Cocoa

private struct LocalPalette {
    static let midnight = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.14, alpha: 1)
    static let neonCyan = NSColor(calibratedRed: 0.18, green: 0.9, blue: 1.0, alpha: 1)
    static let neonYellow = NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.01, alpha: 1)
    static let textPrimary = NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.42, alpha: 0.98)
}

private final class ArcadePopupContentViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let items: [String]
    private let selectionHandler: (Int) -> Void
    private let selectedIndex: Int
    private let labelLeading: CGFloat

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    init(items: [String], selected: Int = -1, labelLeading: CGFloat = 12, selection: @escaping (Int) -> Void) {
        self.items = items
        self.selectedIndex = selected
        self.selectionHandler = selection
        self.labelLeading = labelLeading
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        // 使用类似音量控件的透明背景与霓虹边框
        view.layer?.backgroundColor = LocalPalette.midnight.withAlphaComponent(0.92).cgColor
        view.layer?.borderColor = LocalPalette.neonCyan.withAlphaComponent(0.76).cgColor
        view.layer?.borderWidth = 1.1
        view.layer?.cornerRadius = 0
        view.layer?.masksToBounds = false
        view.layer?.shadowColor = LocalPalette.neonCyan.withAlphaComponent(0.72).cgColor
        view.layer?.shadowRadius = 5
        view.layer?.shadowOpacity = 0.34
        view.layer?.shadowOffset = .zero

        // Configure table view inside a scroll view
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "col")))
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.focusRingType = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.intercellSpacing = NSSize(width: 0, height: 0)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Preselect if needed
        if selectedIndex >= 0 && selectedIndex < items.count {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }
    }

    // MARK: - NSTableViewDataSource/Delegate
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        if let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell.textField?.stringValue = items[row]
            // 更新文字颜色以匹配选中态
            if row == tableView.selectedRow {
                cell.textField?.textColor = LocalPalette.neonYellow
            } else {
                cell.textField?.textColor = LocalPalette.textPrimary.withAlphaComponent(0.9)
            }
            return cell
        }

        let cell = NSTableCellView()
        cell.identifier = id
        let tf = NSTextField(labelWithString: items[row])
        tf.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tf.textColor = (row == tableView.selectedRow) ? LocalPalette.neonYellow : LocalPalette.textPrimary.withAlphaComponent(0.9)
        tf.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: labelLeading),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PopupRowView()
    }

    private final class PopupRowView: NSTableRowView {
        override func drawSelection(in dirtyRect: NSRect) {
            guard let color = LocalPalette.neonCyan.withAlphaComponent(0.22).cgColor.copy(alpha: LocalPalette.neonCyan.withAlphaComponent(0.22).alphaComponent) else { return }
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.setFillColor(LocalPalette.neonCyan.withAlphaComponent(0.22).cgColor)
            ctx?.fill(dirtyRect)
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        selectionHandler(row)
    }
}

final class ArcadeCustomPopupButton: NSPopUpButton {
    private var panelWindow: NSWindow?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet { updateAppearance() }
    }
    private var chevronImageView: NSImageView?
    private var labelField: NSTextField?
    private let textLeading: CGFloat = 14
    private let textTrailingArea: CGFloat = 32

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    override init(frame frameRect: NSRect, pullsDown flag: Bool) {
        super.init(frame: frameRect, pullsDown: flag)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(click)
        wantsLayer = true
        isBordered = false
        focusRingType = .none
        font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureChevronIfNeeded()
        // add a custom label to fully control text rendering and alignment
        let lbl = NSTextField(labelWithString: "")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        lbl.textColor = LocalPalette.neonYellow
        lbl.lineBreakMode = .byTruncatingTail
        addSubview(lbl)
        labelField = lbl
        if let chevron = chevronImageView {
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textLeading),
                lbl.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
                lbl.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textLeading),
                lbl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -textTrailingArea),
                lbl.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
        updateAppearance()
        if let popupCell = cell as? NSPopUpButtonCell {
            popupCell.arrowPosition = .noArrow
        }
        // hide native title drawing — we control the label
        self.title = ""
        updateTitleStyle()
    }

    override var intrinsicContentSize: NSSize {
        var s = super.intrinsicContentSize
        s.height = max(38, s.height + 4)
        return s
    }

    override var alignmentRectInsets: NSEdgeInsets {
        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override func addItems(withTitles itemTitles: [String]) {
        super.addItems(withTitles: itemTitles)
        updateTitleStyle()
    }

    override func removeAllItems() {
        super.removeAllItems()
        updateTitleStyle()
    }

    override func selectItem(at index: Int) {
        super.selectItem(at: index)
        updateTitleStyle()
    }

    override func synchronizeTitleAndSelectedItem() {
        super.synchronizeTitleAndSelectedItem()
        updateTitleStyle()
    }

    private func updateTitleStyle() {
        let title = selectedItem?.title ?? ""
        let para = NSMutableParagraphStyle()
        para.headIndent = textLeading
        para.lineBreakMode = .byTruncatingTail
        // Ensure neon yellow in closed state; dim when disabled
        let fgColor: NSColor = isEnabled ? LocalPalette.neonYellow : LocalPalette.neonYellow.withAlphaComponent(0.42)

        // Update custom label if present
        if let lbl = labelField {
            lbl.stringValue = title
            lbl.textColor = fgColor
        }

        // Keep native control titles empty to avoid double-draw; only update our label
        attributedTitle = NSAttributedString(string: "")
        if let popupCell = cell as? NSPopUpButtonCell {
            popupCell.attributedTitle = NSAttributedString(string: "")
        }
    }

    // Prevent the superclass from drawing the title (avoids double-rendering)
    override func draw(_ dirtyRect: NSRect) {
        // Intentionally empty — drawing handled by labelField and layer
    }

    @objc private func handleClick(_ sender: NSClickGestureRecognizer) {
        showPanel()
    }

    override func mouseDown(with event: NSEvent) {
        showPanel()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
    }

    private func configureChevronIfNeeded() {
        guard chevronImageView == nil else { return }
        let chevron = NSImageView()
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.imageScaling = .scaleProportionallyDown
        if let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            chevron.image = image.withSymbolConfiguration(config)
        }
        addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 11),
            chevron.heightAnchor.constraint(equalToConstant: 11)
        ])
        chevronImageView = chevron
        updateAppearance()
    }

    private func updateAppearance() {
        guard let layer else { return }
        let background: NSColor = isEnabled ? LocalPalette.midnight.withAlphaComponent(0.92) : LocalPalette.midnight.withAlphaComponent(0.72)
        let border: NSColor = isEnabled ? LocalPalette.neonCyan.withAlphaComponent(0.76) : LocalPalette.neonCyan.withAlphaComponent(0.18)
        layer.backgroundColor = background.cgColor
        layer.borderColor = border.cgColor
        layer.borderWidth = 1.1
        layer.cornerRadius = 0
        layer.masksToBounds = false
        layer.shadowColor = border.withAlphaComponent(isHovering ? 0.9 : 0.72).cgColor
        layer.shadowRadius = isHovering ? 8 : 5
        layer.shadowOpacity = isEnabled ? 0.38 : 0
        layer.shadowOffset = .zero

        // update chevron tint
        let tint: NSColor = isEnabled ? (isHovering ? LocalPalette.neonYellow : LocalPalette.textPrimary.withAlphaComponent(0.82)) : LocalPalette.textPrimary.withAlphaComponent(0.36)
        chevronImageView?.contentTintColor = tint
    }

    private func showPanel() {
        if panelWindow != nil {
            closePanel()
            return
        }

        let titles = menu?.items.compactMap { $0.title } ?? []
        let content = ArcadePopupContentViewController(items: titles, selected: self.indexOfSelectedItem, labelLeading: textLeading) { [weak self] index in
            guard let self = self else { return }
            if index >= 0 && index < (self.menu?.items.count ?? 0) {
                self.selectItem(at: index)
                _ = self.target?.perform(self.action, with: self)
            }
            self.closePanel()
        }

        // Size content — keep width at least the button width, but align its origin to label start
        let height = CGFloat(min(10, titles.count)) * 34 + 16
        let width = max(bounds.width, 160)
        content.view.setFrameSize(NSSize(width: width, height: height))

        // Calculate screen position under the button
        guard let hostWindow = self.window else { return }
        let buttonRectInWindow = self.convert(self.bounds, to: nil)
        let buttonRectOnScreen = hostWindow.convertToScreen(buttonRectInWindow)

        // popup aligns to button's left; labelInside uses labelLeading to start text
        let originX = buttonRectOnScreen.minX
        let originY = buttonRectOnScreen.minY - height

        let frame = NSRect(x: originX, y: originY, width: width, height: height)

        // Create borderless window (rectangular)
        let panel = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.contentViewController = content
        panel.collectionBehavior = [.transient]

        // Show window
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)

        panelWindow = panel

        // Monitor clicks outside to close
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] ev in
            guard let self = self else { return ev }
            if let w = self.panelWindow, w != ev.window {
                self.closePanel()
            }
            return ev
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        if let panel = panelWindow {
            panel.orderOut(nil)
        }
        panelWindow = nil

        if let local = localClickMonitor {
            NSEvent.removeMonitor(local)
            localClickMonitor = nil
        }
        if let global = globalClickMonitor {
            NSEvent.removeMonitor(global)
            globalClickMonitor = nil
        }
    }
}


