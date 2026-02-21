# Touch Bar 分槽位 + seam 补偿（兼顾左贴边与首二列间距）

## 背景与目标
- 用户确认：单槽位虽然缓解首二列间距，但会重新出现左侧留白。
- 用户诉求：左侧第一个按钮贴左，同时首二列间距不要异常放大。

## 根因分析
- 单槽位方案：会受 ESC 预留区域影响，左侧留白难完全消除。
- 分槽位方案：首列可贴左，但 ESC 槽位与主槽位存在系统缝隙，导致首二列间距偏大。

## 方案
- 重新启用分槽位：第 0 列放 ESC 槽位，第 1...15 列放主槽位。
- 给主槽位视图加入 `leadingCompensationX=8` 左移补偿，抵消跨槽位 seam。
- 保留 ESC 槽位宽度自适应（按主槽位单列宽度同步），避免首列偏窄。

## 当前进展
- 已完成分槽位恢复 + 主槽位 seam 补偿。
- 已完成本地构建验证。

## 代码变更
- Sources/GameViewController.swift
```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 533a06d..4d3c2c3 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -38,14 +38,22 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private let rulesBodyThemeColor = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.82, alpha: 0.9)
 
     private let columns = 16
+    private let escapeColumnFallbackWidth: CGFloat = 56
+    private let touchBarSeamCompensationX: CGFloat = 8
@@
     private let recordStore = ModeRecordStore.shared
 
     private lazy var controller = GameBoardController(columns: columns)
-    private lazy var gameTouchBarView = GameTouchBarView(columnRange: 0..<columns, controller: controller)
+    private lazy var escapeTouchBarView = GameTouchBarView(columnRange: 0..<1, controller: controller)
+    private lazy var gameTouchBarView = GameTouchBarView(
+        columnRange: 1..<columns,
+        controller: controller,
+        leadingCompensationX: touchBarSeamCompensationX
+    )
 
     private var observerToken: UUID?
+    private var touchBarFrameObserver: NSObjectProtocol?
@@
     private var settingsExpandedWidthConstraint: NSLayoutConstraint?
     private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
     private var rightColumnMinWidthConstraint: NSLayoutConstraint?
+    private var escapeColumnWidthConstraint: NSLayoutConstraint?
@@ -403,7 +412,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         let bar = NSTouchBar()
         bar.delegate = self
         bar.defaultItemIdentifiers = [.game]
-        bar.escapeKeyReplacementItemIdentifier = .escapePlaceholder
+        bar.escapeKeyReplacementItemIdentifier = .escapeGame
@@ -516,6 +525,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         if let observerToken {
             controller.removeObserver(observerToken)
         }
+        if let touchBarFrameObserver {
+            NotificationCenter.default.removeObserver(touchBarFrameObserver)
+        }
         hudTimer?.invalidate()
     }
@@ -542,16 +554,21 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
-        if identifier == .escapePlaceholder {
-            let item = NSCustomTouchBarItem(identifier: .escapePlaceholder)
-            let placeholder = NSView(frame: .zero)
-            placeholder.translatesAutoresizingMaskIntoConstraints = false
-            item.view = placeholder
+        if identifier == .escapeGame {
+            let item = NSCustomTouchBarItem(identifier: .escapeGame)
+            escapeTouchBarView.translatesAutoresizingMaskIntoConstraints = false
+            item.view = escapeTouchBarView
 
+            let widthConstraint = escapeTouchBarView.widthAnchor.constraint(equalToConstant: escapeColumnFallbackWidth)
+            escapeColumnWidthConstraint = widthConstraint
             NSLayoutConstraint.activate([
-                placeholder.widthAnchor.constraint(equalToConstant: 0),
-                placeholder.heightAnchor.constraint(equalToConstant: 30)
+                widthConstraint,
+                escapeTouchBarView.heightAnchor.constraint(equalToConstant: escapeTouchBarView.intrinsicContentSize.height)
             ])
+
+            DispatchQueue.main.async { [weak self] in
+                self?.updateEscapeColumnWidth()
+            }
             return item
         }
@@ -563,9 +580,39 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         NSLayoutConstraint.activate([
             gameTouchBarView.heightAnchor.constraint(equalToConstant: gameTouchBarView.intrinsicContentSize.height)
         ])
+
+        installTouchBarFrameObserverIfNeeded()
+        DispatchQueue.main.async { [weak self] in
+            self?.updateEscapeColumnWidth()
+        }
         return item
     }
 
+    private func installTouchBarFrameObserverIfNeeded() {
+        guard touchBarFrameObserver == nil else { return }
+        gameTouchBarView.postsFrameChangedNotifications = true
+        touchBarFrameObserver = NotificationCenter.default.addObserver(
+            forName: NSView.frameDidChangeNotification,
+            object: gameTouchBarView,
+            queue: .main
+        ) { [weak self] _ in
+            self?.updateEscapeColumnWidth()
+        }
+    }
+
+    private func updateEscapeColumnWidth() {
+        guard let escapeColumnWidthConstraint else { return }
+
+        let mainWidth = gameTouchBarView.bounds.width
+        guard mainWidth > 0 else { return }
+
+        let denominator = max(1, columns - 1)
+        let targetWidth = max(44, round(mainWidth / CGFloat(denominator)))
+        if abs(escapeColumnWidthConstraint.constant - targetWidth) > 0.5 {
+            escapeColumnWidthConstraint.constant = targetWidth
+        }
+    }
+
@@ -2026,5 +2073,5 @@ private final class PixelBannerView: NSView {
 extension NSTouchBarItem.Identifier {
     static let game = NSTouchBarItem.Identifier("com.eliminateteris1.game")
-    static let escapePlaceholder = NSTouchBarItem.Identifier("com.eliminateteris1.escape-placeholder")
+    static let escapeGame = NSTouchBarItem.Identifier("com.eliminateteris1.escape-game")
 }
```

- Sources/GameTouchBarView.swift
```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 256e1a7..c62ef0b 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -285,16 +285,18 @@ final class GameTouchBarView: NSView {
     private let controller: GameBoardController
     private let columnRange: Range<Int>
     private let columnCount: Int
+    private let leadingCompensationX: CGFloat
@@
-    init(columnRange: Range<Int>, controller: GameBoardController) {
+    init(columnRange: Range<Int>, controller: GameBoardController, leadingCompensationX: CGFloat = 0) {
@@
         self.columnRange = columnRange
         self.columnCount = columnRange.count
         self.controller = controller
+        self.leadingCompensationX = max(0, leadingCompensationX)
@@ -340,7 +342,7 @@ final class GameTouchBarView: NSView {
             let isSelected = controller.isSelected(globalIndex)
             let isLocked = controller.isLocked(globalIndex)
 
-            drawCellBackground(in: rect, highlighted: isLocked || isSelected)
+            drawCellBackground(in: rect, globalIndex: globalIndex, highlighted: isLocked || isSelected)
             drawPiece(controller.tile(at: globalIndex), in: rect, highlighted: isLocked || isSelected)
         }
     }
@@ -424,8 +426,13 @@ final class GameTouchBarView: NSView {
         controller.handleTap(at: index)
     }
 
-    private func drawCellBackground(in rect: CGRect, highlighted: Bool) {
-        let inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+    private func drawCellBackground(in rect: CGRect, globalIndex: Int, highlighted: Bool) {
+        var inset = rect.insetBy(dx: Layout.tileOuterInsetX, dy: Layout.tileOuterInsetY)
+        // 仅让全局第 0 列贴齐最左边缘，避免拆分视图后中间列误判为“首列”。
+        if globalIndex == 0 {
+            inset.origin.x -= Layout.tileOuterInsetX
+            inset.size.width += Layout.tileOuterInsetX * 2
+        }
         let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
         let fill = highlighted ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)
         fill.setFill()
@@ -498,11 +505,11 @@ final class GameTouchBarView: NSView {
     }
 
     private var boardWidth: CGFloat {
-        return max(0, bounds.width)
+        return max(0, bounds.width + leadingCompensationX)
     }
 
     private var boardOriginX: CGFloat {
-        return 0
+        return -leadingCompensationX
     }
 ```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
@@
+- 最新回调到分槽位方案：首列仍在 ESC 槽位、其余 1...15 在主棋盘槽位，但给主棋盘增加 `leadingCompensationX=8` 左移补偿以抵消跨槽位分隔，首列宽度继续按主棋盘单列宽度自适应同步。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
@@
+`workflow/20260221160132-touchbar-split-seam-compensation.md` - 重新启用 ESC 分槽位并加入主棋盘左移补偿，兼顾左贴边与首二列间距。
@@
+- 需要确认“左贴边 + 首二列间距收敛”的最新方案（分槽位 + seam 补偿）时，优先读取 `20260221160132` 文档。
@@
+- Touch Bar 最新策略为分槽位渲染：ESC 槽位承载第 0 列、主槽位承载 1...15，并对主槽位施加 `leadingCompensationX=8` 左移补偿，减少跨槽位缝隙。
```

## 测试用例
### TC-001 左侧贴边
- 类型：UI 测试
- 步骤：启动应用，观察最左按钮与 Touch Bar 左边缘。
- 预期：首按钮贴近最左边缘。

### TC-002 首二列间距
- 类型：UI 测试
- 步骤：比较第 1/2 与第 2/3 列间距。
- 预期：首二列间距收敛，不再明显大于后续列。

### TC-003 首列宽度
- 类型：UI 测试
- 步骤：观察第 1 列与第 2 列宽度。
- 预期：列宽接近一致，无明显首列偏窄。

### TC-004 构建验证
- 类型：构建测试
- 步骤：执行 `HOME=/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox`。
- 预期：构建成功。
