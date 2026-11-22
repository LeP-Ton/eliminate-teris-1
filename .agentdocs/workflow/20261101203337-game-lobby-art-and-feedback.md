# 游戏大厅美术、模式图案与局内信息优化

## 背景与目标
- 会话-162 起落实会话-157/158 的评审：保留首页大体构图和设计稿方块，减少工具软件的表单观感，形成统一的轻立体游戏材质与反馈。
- 本轮以 `experiment/ui-refactor` 的提交 `9dd05c6` 为基线；不改变自由/60 秒限时/30 次限步的规则和存档口径。
- UI 评审沿用已读取的 ui-ux-pro-max 准则；本地检索脚本缺失，按原生 AppKit 的现有绘制体系实施，不引入网页框架或外部依赖。

## 设计与实施
### 模式图案
- 新增 `GameModeArtwork`：自由使用四枚疏朗悬浮的彩色方块；限时使用橙金秒表和速度细节；限步使用带侧边按钮、显示 30 的蓝色行动计数器。
- 图案共用 64 点画布、侧面厚度、顶部光照和柔和色影；透明背景、无外围徽章底框，等比缩放并缓存。
- 计数器上的 30 是模式固定规则，不随本局剩余次数变化；侧边按钮避免日历图案的日期联想。
- `GameIconRenderer` 识别独立 `game.mode.*` 名称，首页、玩法说明和排行榜复用同一图案；交换教学中仍使用表示真实操作的箭头。

### 大厅材质与交互
- `GameLobbyStyle` 提供暖白表面、轻投影、细高光、局部环境光及金色按钮厚度，原设计稿方块资源不重绘。
- 模式卡片取消未选中的空心单选圆圈；选中使用淡蓝辉光、轮廓和小勾选，保持可识别状态与原生无线电按钮辅助功能。
- `GameControlFeedback` 在 0.18 秒内平滑过渡悬停、按压和选中强度；仅变化期间添加定时器，重复刷新不重启，快速反向从当前值接续。
- 初次离屏定位直接到位，再挂载窗口或悬停不会导致高光倒退；减少动态效果开启时立即完成，动画中启用也立即收敛。
- 主按钮增加金色渐变、底部厚度、高光和按压下沉；布局与文案宽度适配仍保留原生点击及键盘行为。
- 首页标题适度缩小、副标题加深，插画和操作区的垂直间距收紧；小窗口的模式说明允许两行，长翻译标题适度缩小。
- 成就标签沿用透明图案与“仅图案加名称居中”的布局；表面增加柔和厚度，左侧完成标记略小、降低权重。锁定和完成标记中心仍固定在左侧 23 点。

### 局内信息
- 新增只消费快照的 `HomeChallengeHUDView`，在限时/限步开始后替代大幅宣传标题区域展示预算；待机保留用户指定的三种主标题和开局提示。
- 限时展示大号剩余时间和时间条；限步展示剩余次数与 30 格行动条；两种状态均显示实际消除数。
- 剩余不超过 10 秒或不超过 6 次行动时使用红色强调；结束后保留本局数量和耗尽的行动条。
- 倒计时向上取整显示秒数，避免正式开局后第一秒立即显示 00:59；真实计时和结束判定仍由原棋盘控制器负责。
- 局内按钮上方恢复操作提示，避免与大号预算面板重复报数；结束时仍显示本局结束文案。
- 新标签补齐中、英、日、韩、俄五种语言；根目录核心认知及文档索引已同步。

## 阶段与完成情况
- [x] 三种模式重新构思并绘制，贯穿首页和辅助页面。
- [x] 大厅卡片、环境光、金色按钮与成就栏材质统一。
- [x] 快速交互与减少动态效果支持。
- [x] 局内剩余预算、行动条、紧张阶段和结束状态展示。
- [x] 小窗口与五语言检查、完整回归和真实预览归档。

## 验证方法与结果
- 第一轮首页/模式图标/开局回归：23 项通过。
- 新增 `GameLobbyPresentationTests`：5 项通过，包含反馈接续、预算边界、五语言状态展示、图案透明及真实动画导出。
- 最终执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，2026-11-01 20:51:19 完成，**86 项通过，0 失败**。
- `git diff --check` 通过；新增文档另行检查行尾空白，全部代码增量使用零上下文统一 diff。
- 全部预览来自真实 AppKit 组件，使用隔离存档和可控时间，不挂载玩家真实 Touch Bar，不向正式应用添加测试预览入口。

### TC-001 悬停、按压和选中快速接续（通过）
- 初次直接选中，再进入悬停，选中强度保持 1；半程重复刷新仍按原时间完成；快速反向保持当前画面；减少动态效果立即到位。

### TC-002 挑战预算按快照展示（通过）
- 59.9 秒显示 01:00；18 次显示 18 和 60% 行动条；完成 30 次后显示 0 与空条，不改变任何真实规则。

### TC-003 待机、局内、结束与语言尺寸（通过）
- 五语言、三模式、待机与局内，分别在 960×720、1180×800、1920×1080 渲染；检查预算面板显示边界和本局数值，确保成就存档未改写。
- 单独检查剩余 3 次的红色状态、结束后保留 126 个结果；人工核对俄语小窗口完整两行模式说明。

### TC-004 图案在小尺寸和非正方形区域的表现（通过）
- 在 24×24、64×64、120×64 检查透明边角、彩色主体和三枚独立图案，沿用统一等比绘制。

### TC-005 原有流程和布局（通过）
- 原设计稿方块像素、16 格 Touch Bar 开局、空格路由、最后一次连锁、旧存档兼容、成就全屏图文居中与辅助面板均包含在最终 86 项回归中。

## 实际效果与手动体验
- [待机大厅](../../docs/previews/lobby-idle.png)
- [三枚模式图案](../../docs/previews/mode-artwork.png)
- [真实控件交互动画](../../docs/previews/lobby-feedback.gif)
- [限时局内](../../docs/previews/challenge-timed.png)、[限步局内](../../docs/previews/challenge-moves.png)
- [最后三次行动](../../docs/previews/lobby-last-moves.png)、[结束状态](../../docs/previews/lobby-finished.png)
- 运行 `./run.sh`，切换模式并悬停/按压按钮，通过按钮、空格或触控栏滑动开局；观察大号预算、行动条以及结束提示。
- 本轮通过离屏真实渲染验证视觉，实机指针和 Touch Bar 体验可在启动后检查；不自动重启正在进行的玩家游戏。

## 完整代码与文档增量
以下相对于本轮开始时的独立快照；每个文本文件使用零上下文统一 diff，完整记录所有新增和删除行。二进制预览记录字节数及 SHA-256。本记录载体不递归记录自身。

### `.agentdocs/index.md`

```diff
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -3,0 +4 @@
+`workflow/20261101203337-game-lobby-art-and-feedback.md` - 会话-162 起落实会话-157/158：重绘自由方块/冲刺秒表/30 次行动计数器，统一大厅光影、选中/按压反馈与局内预算面板；含完整增量 diff、真实界面/动画预览及回归结果。
@@ -87,0 +89 @@
+- 需要调整游戏大厅的模式美术、柔和投影/高光、悬停按压/选中过渡、局内倒计时/行动条或查看本轮真实预览时，读取 `20261101203337-game-lobby-art-and-feedback.md`。
@@ -172,0 +175,2 @@
+- 模式图案由 `GameModeArtwork` 独立绘制，自由是悬浮方块、限时是冲刺秒表、限步是 30 次行动计数器；`game.mode.*` 经统一图标入口供首页和辅助页使用，不能再按系统符号名称处理。
+- 大厅材质由 `GameLobbyStyle` 提供；`GameControlFeedback` 的 0.18 秒反馈只在交互变化时刷新，重复界面刷新不重新计时，减少动态效果立即到位。局内预算面板只消费快照，原开局及结算规则仍由控制器执行。
```

### `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -6,0 +7,5 @@
+
+## 2026-11-01（游戏大厅美术与局内信息）
+- 模式使用 `GameModeArtwork` 的本地彩色矢量图案，首页、玩法说明和排行榜通过 `GameIconRenderer` 共用入口等比绘制；模式图案与系统操作符号分开维护。
+- 大厅材质位于 `GameLobbyStyle`；`GameControlFeedback` 只在交互变化期间驱动短动画，支持快速反向和减少动态效果，不参与开局、计时或游戏规则。
+- 首页按待机/局内/结束状态组织信息；`HomeChallengeHUDView` 只读取 `GameSnapshot` 展示剩余预算和消除数，真实规则仍由棋盘控制器统一执行。原设计稿方块资源与 Touch Bar 生命周期沿用原实现。
```

### `Sources/GameIcons.swift`

```diff
--- a/Sources/GameIcons.swift
+++ b/Sources/GameIcons.swift
@@ -13,0 +14,4 @@
+        // 模式图案是游戏美术，颜色由自身定义；所有入口共用同一资源，保持等比。
+        if let mode = HomeGameMode.allCases.first(where: { $0.symbol == name }) {
+            GameModeArtwork.draw(mode, in: bounds); return
+        }
```

### `Sources/GameLobbyStyle.swift`

```diff
--- /dev/null
+++ b/Sources/GameLobbyStyle.swift
@@ -0,0 +1,117 @@
+import Cocoa
+
+/// 大厅的柔和游戏材质。所有绘制都限制在控件内部，保留原生点击区域和焦点环。
+enum GameLobbyStyle {
+    static let amber = NSColor(calibratedRed: 1, green: 0.68, blue: 0.08, alpha: 1)
+    static let teal = NSColor(calibratedRed: 0.05, green: 0.70, blue: 0.54, alpha: 1)
+
+    static func gradient(_ rect: NSRect, colors: [NSColor], radius: CGFloat) {
+        NSGradient(colors: colors)?.draw(in: NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius), angle: 90)
+    }
+
+    static func glow(_ rect: NSRect, color: NSColor) {
+        NSGradient(starting: color, ending: color.withAlphaComponent(0))?
+            .draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
+    }
+
+    static func surface(_ rect: NSRect, radius: CGFloat = 15, tint: NSColor = .white, strength: CGFloat = 0.07) {
+        NSGraphicsContext.saveGraphicsState()
+        let shadow = NSShadow()
+        shadow.shadowColor = NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.13, alpha: strength)
+        shadow.shadowBlurRadius = 8; shadow.shadowOffset = NSSize(width: 0, height: -3); shadow.set()
+        NSColor.white.setFill()
+        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
+        NSGraphicsContext.restoreGraphicsState()
+        gradient(rect, colors: [.white, tint], radius: radius)
+        HomeStyle.border.withAlphaComponent(0.42).setStroke()
+        let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
+        outline.lineWidth = 0.7; outline.stroke()
+    }
+
+    static func fittedSize(_ text: String, width: CGFloat, preferred: CGFloat, minimum: CGFloat, weight: NSFont.Weight) -> CGFloat {
+        var size = preferred
+        while size > minimum, (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width > width {
+            size -= 1
+        }
+        return size
+    }
+
+    static func wrappedText(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor) {
+        let paragraph = NSMutableParagraphStyle()
+        paragraph.lineBreakMode = .byWordWrapping
+        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
+                               attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: paragraph])
+    }
+
+    static func primaryButton(_ bounds: NSRect, hover: CGFloat, press: CGFloat) {
+        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: press * 2 - hover)
+        NSGraphicsContext.saveGraphicsState()
+        let shadow = NSShadow()
+        shadow.shadowColor = amber.withAlphaComponent(0.22 + hover * 0.12)
+        shadow.shadowBlurRadius = 8 + hover * 4
+        shadow.shadowOffset = NSSize(width: 0, height: -3 + press * 2); shadow.set()
+        amber.setFill(); NSBezierPath(roundedRect: face, xRadius: 13, yRadius: 13).fill()
+        NSGraphicsContext.restoreGraphicsState()
+        let lip = face.offsetBy(dx: 0, dy: 3 - press * 2)
+        NSColor(calibratedRed: 0.91, green: 0.62, blue: 0.015, alpha: 1).setFill()
+        NSBezierPath(roundedRect: lip, xRadius: 13, yRadius: 13).fill()
+        gradient(face, colors: [NSColor(calibratedRed: 1, green: 0.88, blue: 0.25, alpha: 1), HomeStyle.yellow], radius: 13)
+        NSColor.white.withAlphaComponent(0.65).setStroke()
+        let highlight = NSBezierPath()
+        highlight.lineWidth = 1
+        highlight.move(to: NSPoint(x: face.minX + 14, y: face.minY + 1))
+        highlight.line(to: NSPoint(x: face.maxX - 14, y: face.minY + 1)); highlight.stroke()
+        // 细小的高光只用于按钮表面，避免让整张首页持续闪烁。
+        glow(NSRect(x: face.minX + 8, y: face.minY, width: face.width * 0.55, height: face.height), color: .white.withAlphaComponent(0.14 + hover * 0.12))
+    }
+}
+
+/// 悬停、按压和选中共用短动画；仅变化期间刷新，界面 tick 不重新启动过渡。
+final class GameControlFeedback {
+    struct Values: Equatable {
+        var hover: CGFloat = 0
+        var press: CGFloat = 0
+        var selection: CGFloat = 0
+        func mixed(with end: Values, fraction: CGFloat) -> Values {
+            Values(hover: hover + (end.hover - hover) * fraction,
+                   press: press + (end.press - press) * fraction,
+                   selection: selection + (end.selection - selection) * fraction)
+        }
+    }
+    private(set) var values = Values()
+    private var origin = Values(), target = Values()
+    private var started: TimeInterval = 0
+    private var timer: Timer?
+    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
+    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
+    var onUpdate: (() -> Void)?
+    static let duration: TimeInterval = 0.18
+    deinit { timer?.invalidate() }
+
+    func update(hover: Bool, press: Bool, selected: Bool = false, animated: Bool) {
+        let next = Values(hover: hover ? 1 : 0, press: press ? 1 : 0, selection: selected ? 1 : 0)
+        guard next != target else { return }
+        advance(at: now())
+        origin = values; target = next; started = now()
+        timer?.invalidate(); timer = nil
+        guard animated, !reducesMotion() else {
+            values = target; origin = target; started -= Self.duration
+            onUpdate?(); return
+        }
+        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.advance(at: self?.now() ?? 0) }
+        RunLoop.main.add(timer, forMode: .common); self.timer = timer
+    }
+
+    /// 测试可推进时间，快速反向时从当前视觉值接续，避免高光跳变。
+    func advance(at time: TimeInterval) {
+        if reducesMotion() {
+            values = target; origin = target; timer?.invalidate(); timer = nil
+            onUpdate?(); return
+        }
+        let t = CGFloat(min(1, max(0, (time - started) / Self.duration)))
+        let eased = t * t * (3 - 2 * t)
+        values = origin.mixed(with: target, fraction: eased)
+        if t >= 1 { timer?.invalidate(); timer = nil }
+        onUpdate?()
+    }
+}
```

### `Sources/GameModeArtwork.swift`

```diff
--- /dev/null
+++ b/Sources/GameModeArtwork.swift
@@ -0,0 +1,113 @@
+import Cocoa
+
+/// 模式使用独立的游戏主题图案；64 点设计画布等比缩放，不复用无限环或交换箭头。
+enum GameModeArtwork {
+    private static var cache: [HomeGameMode: NSImage] = [:]
+
+    static func image(for mode: HomeGameMode) -> NSImage {
+        if let image = cache[mode] { return image }
+        let image = NSImage(size: NSSize(width: 64, height: 64), flipped: true) { _ in
+            switch mode {
+            case .free: freeTiles()
+            case .timed: stopwatch()
+            case .moves: actionCounter()
+            }
+            return true
+        }
+        image.isTemplate = false; cache[mode] = image
+        return image
+    }
+
+    static func draw(_ mode: HomeGameMode, in bounds: NSRect) {
+        let image = image(for: mode)
+        image.draw(in: GameIconRenderer.fittedRect(size: image.size, in: bounds), from: .zero,
+                   operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
+    }
+
+    /// 方块通过侧面、顶部高光和柔和色影获得体积，三种图案保持同一光照。
+    private static func tile(_ rect: NSRect, color: NSColor, angle: CGFloat = 0) {
+        NSGraphicsContext.saveGraphicsState()
+        let transform = NSAffineTransform()
+        transform.translateX(by: rect.midX, yBy: rect.midY); transform.rotate(byDegrees: angle)
+        transform.translateX(by: -rect.midX, yBy: -rect.midY); transform.concat()
+        let shade = color.shadow(withLevel: 0.18) ?? color
+        NSGraphicsContext.saveGraphicsState()
+        let shadow = NSShadow(); shadow.shadowColor = color.withAlphaComponent(0.22)
+        shadow.shadowBlurRadius = 4; shadow.shadowOffset = NSSize(width: 1, height: -3); shadow.set()
+        shade.setFill(); NSBezierPath(roundedRect: rect.offsetBy(dx: 1.5, dy: 2.5), xRadius: 4, yRadius: 4).fill()
+        NSGraphicsContext.restoreGraphicsState()
+        GameLobbyStyle.gradient(rect, colors: [color.blended(withFraction: 0.28, of: .white) ?? color, color], radius: 4)
+        NSColor.white.withAlphaComponent(0.4).setStroke()
+        let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
+        edge.lineWidth = 0.7; edge.stroke()
+        NSGraphicsContext.restoreGraphicsState()
+    }
+
+    private static func freeTiles() {
+        // 疏朗悬浮的独立方块表达随心操作，避免画成需要向上堆叠的棋盘。
+        GameLobbyStyle.glow(NSRect(x: 6, y: 27, width: 52, height: 33), color: GameLobbyStyle.teal.withAlphaComponent(0.13))
+        tile(NSRect(x: 10, y: 11, width: 19, height: 19), color: .systemOrange, angle: -12)
+        tile(NSRect(x: 35, y: 7, width: 19, height: 19), color: HomeStyle.blue, angle: 9)
+        tile(NSRect(x: 7, y: 36, width: 19, height: 19), color: GameLobbyStyle.teal, angle: 7)
+        tile(NSRect(x: 34, y: 34, width: 21, height: 21), color: .systemRed, angle: -8)
+        spark(at: NSPoint(x: 33, y: 31), color: GameLobbyStyle.amber, length: 3)
+    }
+
+    private static func stopwatch() {
+        GameLobbyStyle.glow(NSRect(x: 10, y: 31, width: 48, height: 30), color: GameLobbyStyle.amber.withAlphaComponent(0.15))
+        tile(NSRect(x: 28, y: 4, width: 12, height: 8), color: GameLobbyStyle.amber)
+        tile(NSRect(x: 47, y: 14, width: 9, height: 7), color: GameLobbyStyle.amber, angle: 35)
+        let shell = NSRect(x: 15, y: 13, width: 43, height: 43)
+        NSColor(calibratedRed: 0.89, green: 0.42, blue: 0.02, alpha: 1).setFill()
+        NSBezierPath(ovalIn: shell.offsetBy(dx: 1, dy: 3)).fill()
+        NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.85, blue: 0.29, alpha: 1), .systemOrange])?
+            .draw(in: NSBezierPath(ovalIn: shell), angle: 90)
+        NSColor.white.withAlphaComponent(0.9).setFill()
+        NSBezierPath(ovalIn: shell.insetBy(dx: 5, dy: 5)).fill()
+        let center = NSPoint(x: shell.midX, y: shell.midY)
+        for index in 0..<12 {
+            let a = CGFloat(index) * .pi / 6
+            let point = NSPoint(x: center.x + sin(a) * 13.2, y: center.y - cos(a) * 13.2)
+            HomeStyle.secondary.withAlphaComponent(index.isMultiple(of: 3) ? 0.7 : 0.28).setFill()
+            NSBezierPath(ovalIn: NSRect(x: point.x - 0.8, y: point.y - 0.8, width: 1.6, height: 1.6)).fill()
+        }
+        stroke([NSPoint(x: center.x, y: center.y - 10), center, NSPoint(x: center.x + 8, y: center.y + 5)], color: HomeStyle.ink, width: 2.8)
+        GameLobbyStyle.amber.setFill(); NSBezierPath(ovalIn: NSRect(x: center.x - 2.1, y: center.y - 2.1, width: 4.2, height: 4.2)).fill()
+        stroke([NSPoint(x: 5, y: 24), NSPoint(x: 11, y: 24)], color: GameLobbyStyle.amber, width: 2.5)
+        stroke([NSPoint(x: 3, y: 33), NSPoint(x: 9, y: 33)], color: GameLobbyStyle.amber.withAlphaComponent(0.65), width: 2.5)
+    }
+
+    private static func actionCounter() {
+        GameLobbyStyle.glow(NSRect(x: 6, y: 31, width: 53, height: 30), color: HomeStyle.blue.withAlphaComponent(0.15))
+        // 侧面的行动按钮表达可消耗次数；不用日历挂环，避免被理解为日期。
+        tile(NSRect(x: 51, y: 25, width: 8, height: 13), color: GameLobbyStyle.amber)
+        let shell = NSRect(x: 9, y: 12, width: 46, height: 40)
+        NSColor(calibratedRed: 0.02, green: 0.30, blue: 0.70, alpha: 1).setFill()
+        NSBezierPath(roundedRect: shell.offsetBy(dx: 1, dy: 3), xRadius: 8, yRadius: 8).fill()
+        GameLobbyStyle.gradient(shell, colors: [NSColor(calibratedRed: 0.25, green: 0.73, blue: 1, alpha: 1), HomeStyle.blue], radius: 8)
+        // “30”是固定玩法的行动预算，不随某一局扣减，防止模式入口被误认为实时状态。
+        let display = NSRect(x: 14, y: 18, width: 36, height: 25)
+        GameLobbyStyle.gradient(display, colors: [.white, NSColor(calibratedRed: 0.90, green: 0.97, blue: 1, alpha: 1)], radius: 4)
+        let text = "\(HomeGameMode.moveLimit)" as NSString
+        let font = NSFont.monospacedDigitSystemFont(ofSize: 23, weight: .heavy)
+        let size = text.size(withAttributes: [.font: font])
+        text.draw(at: NSPoint(x: display.midX - size.width / 2, y: display.midY - size.height / 2), withAttributes: [.font: font, .foregroundColor: HomeStyle.ink])
+        for index in 0..<3 {
+            NSColor.white.withAlphaComponent(0.92 - Double(index) * 0.17).setFill()
+            NSBezierPath(roundedRect: NSRect(x: CGFloat(21 + index * 8), y: 46, width: 5, height: 3), xRadius: 1, yRadius: 1).fill()
+        }
+    }
+
+    private static func stroke(_ points: [NSPoint], color: NSColor, width: CGFloat) {
+        guard let first = points.first else { return }
+        let path = NSBezierPath(); path.move(to: first)
+        points.dropFirst().forEach { path.line(to: $0) }
+        path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round
+        color.setStroke(); path.stroke()
+    }
+
+    private static func spark(at point: NSPoint, color: NSColor, length: CGFloat) {
+        stroke([NSPoint(x: point.x - length, y: point.y), NSPoint(x: point.x + length, y: point.y)], color: color, width: 1.7)
+        stroke([NSPoint(x: point.x, y: point.y - length), NSPoint(x: point.x, y: point.y + length)], color: color, width: 1.7)
+    }
+}
```

### `Sources/GamePresentation.swift`

```diff
--- a/Sources/GamePresentation.swift
+++ b/Sources/GamePresentation.swift
@@ -28,3 +28,3 @@
-        case .free: return "infinity"
-        case .timed: return "stopwatch"
-        case .moves: return "arrow.left.arrow.right"
+        case .free: return "game.mode.free"
+        case .timed: return "game.mode.timed"
+        case .moves: return "game.mode.moves"
```

### `Sources/HomeChallengeHUDView.swift`

```diff
--- /dev/null
+++ b/Sources/HomeChallengeHUDView.swift
@@ -0,0 +1,72 @@
+import Cocoa
+
+/// 局内把行动预算置于插画上方；只消费快照，不参与计时、扣次或结束判定。
+final class HomeChallengeHUDView: NSView {
+    private(set) var snapshot: GameSnapshot?
+    private(set) var mode: HomeGameMode = .timed
+    override var isFlipped: Bool { true }
+    override init(frame: NSRect) {
+        super.init(frame: frame)
+        setAccessibilityElement(true); setAccessibilityRole(.group)
+    }
+    required init?(coder: NSCoder) { nil }
+
+    var remainingFraction: CGFloat {
+        guard let snapshot else { return 1 }
+        let fraction = mode == .timed
+            ? (snapshot.remainingTime ?? HomeGameMode.timedDuration) / HomeGameMode.timedDuration
+            : Double(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) / Double(HomeGameMode.moveLimit)
+        return CGFloat(min(1, max(0, fraction)))
+    }
+
+    var budgetText: String {
+        guard let snapshot else { return "" }
+        if mode == .moves { return String(snapshot.remainingSwaps ?? HomeGameMode.moveLimit) }
+        let seconds = max(0, Int(ceil(snapshot.remainingTime ?? HomeGameMode.timedDuration)))
+        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
+    }
+
+    func refresh(snapshot: GameSnapshot, mode: HomeGameMode) {
+        self.snapshot = snapshot; self.mode = mode
+        setAccessibilityLabel(AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
+            + ": " + budgetText + "; " + AchievementText.string("home.cleared_title") + ": \(snapshot.totalCleared)")
+        needsDisplay = true
+    }
+
+    override func draw(_ dirtyRect: NSRect) {
+        guard let snapshot else { return }
+        let urgent = !snapshot.isFinished && remainingFraction <= (mode == .timed ? 1.0 / 6 : 1.0 / 5)
+        let accent: NSColor = urgent ? .systemRed : mode == .timed ? GameLobbyStyle.amber : HomeStyle.blue
+        let face = bounds.insetBy(dx: 3, dy: 5)
+        GameLobbyStyle.surface(face, radius: 18, tint: NSColor(calibratedRed: 1, green: 0.99, blue: 0.96, alpha: 1))
+        GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: face.width * 0.6, height: face.height), color: accent.withAlphaComponent(0.08))
+        let split = face.width * 0.57
+        let label = AchievementText.string(mode == .timed ? "home.challenge.time_left" : "home.challenge.moves_left")
+        HomeStyle.text(label, in: NSRect(x: 22, y: 17, width: split - 30, height: 20), size: 12, weight: .semibold, color: HomeStyle.secondary)
+        let budgetSize = GameLobbyStyle.fittedSize(budgetText, width: split - 32, preferred: 44, minimum: 25, weight: .heavy)
+        HomeStyle.text(budgetText, in: NSRect(x: 20, y: 36, width: split - 30, height: 58), size: budgetSize, weight: .heavy,
+                       color: urgent ? .systemRed : HomeStyle.ink)
+        HomeStyle.border.withAlphaComponent(0.6).setStroke()
+        let divider = NSBezierPath(); divider.move(to: NSPoint(x: split, y: 22)); divider.line(to: NSPoint(x: split, y: 89)); divider.stroke()
+        HomeStyle.text(AchievementText.string("home.cleared_title"), in: NSRect(x: split + 20, y: 19, width: face.width - split - 27, height: 20),
+                       size: 12, weight: .semibold, color: HomeStyle.secondary)
+        let count = String(snapshot.totalCleared)
+        let countSize = GameLobbyStyle.fittedSize(count, width: face.width - split - 30, preferred: 38, minimum: 18, weight: .heavy)
+        HomeStyle.text(count, in: NSRect(x: split + 19, y: 42, width: face.width - split - 28, height: 48), size: countSize, weight: .heavy)
+        let track = NSRect(x: 22, y: face.height - 17, width: face.width - 38, height: 5)
+        HomeStyle.ink.withAlphaComponent(0.055).setFill()
+        NSBezierPath(roundedRect: track, xRadius: 2.5, yRadius: 2.5).fill()
+        if mode == .moves {
+            // 30 个可消耗格让有限行动可视化，最后一步完成后清空。
+            let gap: CGFloat = 2
+            let width = (track.width - gap * CGFloat(HomeGameMode.moveLimit - 1)) / CGFloat(HomeGameMode.moveLimit)
+            for index in 0..<max(0, min(HomeGameMode.moveLimit, snapshot.remainingSwaps ?? 0)) {
+                accent.setFill()
+                NSBezierPath(roundedRect: NSRect(x: track.minX + CGFloat(index) * (width + gap), y: track.minY, width: width, height: track.height), xRadius: 1.5, yRadius: 1.5).fill()
+            }
+        } else if remainingFraction > 0 {
+            GameLobbyStyle.gradient(NSRect(x: track.minX, y: track.minY, width: track.width * remainingFraction, height: track.height),
+                                    colors: [accent, accent.blended(withFraction: 0.25, of: .white) ?? accent], radius: 2.5)
+        }
+    }
+}
```

### `Sources/HomeDashboardView.swift`

```diff
--- a/Sources/HomeDashboardView.swift
+++ b/Sources/HomeDashboardView.swift
@@ -9,0 +10 @@
+    let feedback = GameControlFeedback()
@@ -16,0 +18 @@
+        feedback.onUpdate = { [weak self] in self?.needsDisplay = true }
@@ -20 +22 @@
-    override var isHighlighted: Bool { didSet { needsDisplay = true } }
+    override var isHighlighted: Bool { didSet { refreshFeedback() } }
@@ -32,2 +34,8 @@
-    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
-    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
+    override func mouseEntered(with event: NSEvent) { hovering = true; refreshFeedback() }
+    override func mouseExited(with event: NSEvent) { hovering = false; refreshFeedback() }
+    var selectedForFeedback: Bool { false }
+    func refreshFeedback() {
+        feedback.update(hover: hovering && isEnabled, press: isHighlighted && isEnabled,
+                        selected: selectedForFeedback, animated: window != nil)
+        needsDisplay = true
+    }
@@ -37,2 +45 @@
-            let color = isHighlighted ? (HomeStyle.yellow.shadow(withLevel: 0.08) ?? HomeStyle.yellow) : HomeStyle.yellow
-            HomeStyle.card(bounds, fill: color, border: color, radius: 9)
+            GameLobbyStyle.primaryButton(bounds, hover: feedback.values.hover, press: feedback.values.press)
@@ -42 +49,2 @@
-        let size: CGFloat = primary ? 23 : 14
+        let preferred: CGFloat = primary ? 22 : 14
+        let size = GameLobbyStyle.fittedSize(title, width: bounds.width - (primary ? 60 : 24), preferred: preferred, minimum: 11, weight: primary ? .heavy : .semibold)
@@ -47,2 +55,3 @@
-        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2, width: icon, height: icon)) }
-        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65, width: width + 2, height: size * 1.5),
+        let offset = primary ? feedback.values.press * 2 - feedback.values.hover : 0
+        if let symbolName { HomeStyle.symbol(symbolName, in: NSRect(x: x, y: bounds.midY - icon / 2 + offset, width: icon, height: icon)) }
+        HomeStyle.text(title, in: NSRect(x: x + (icon > 0 ? icon + 10 : 0), y: bounds.midY - size * 0.65 + offset, width: width + 2, height: size * 1.5),
@@ -56 +65,2 @@
-    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
+    var selected = false { didSet { if oldValue != selected { refreshFeedback(); setAccessibilityValue(selected ? 1 : 0) } } }
+    override var selectedForFeedback: Bool { selected }
@@ -60,0 +71 @@
+        setAccessibilityValue(0)
@@ -64,13 +75,25 @@
-        HomeStyle.card(bounds, fill: selected ? NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 1) : .white.withAlphaComponent(0.75),
-                       border: selected ? HomeStyle.blue : hovering ? HomeStyle.blue.withAlphaComponent(0.4) : HomeStyle.border)
-        let check = NSRect(x: 18, y: bounds.midY - 15, width: 30, height: 30)
-        if selected {
-            HomeStyle.symbol("checkmark.circle.fill", in: check, color: HomeStyle.blue)
-        } else {
-            HomeStyle.muted.withAlphaComponent(0.65).setStroke()
-            let circle = NSBezierPath(ovalIn: check.insetBy(dx: 1, dy: 1)); circle.lineWidth = 2; circle.stroke()
-        }
-        HomeStyle.symbol(mode.symbol, in: NSRect(x: 66, y: bounds.midY - 19, width: 38, height: 38))
-        let y = max(9, (bounds.height - 48) / 2)
-        HomeStyle.text(AchievementText.string("home.mode.\(mode.key)"), in: NSRect(x: 117, y: y, width: bounds.width - 130, height: 27), size: 20, weight: .bold)
-        HomeStyle.text(AchievementText.string("home.mode_desc.\(mode.key)"), in: NSRect(x: 117, y: y + 29, width: bounds.width - 130, height: 20), size: 13, color: HomeStyle.secondary)
+        let effect = feedback.values
+        let face = bounds.insetBy(dx: 4, dy: 5).offsetBy(dx: 0, dy: effect.press * 1.5 - effect.hover)
+        GameLobbyStyle.surface(face, tint: NSColor(calibratedRed: 0.98, green: 0.985, blue: 0.99, alpha: 1), strength: 0.045 + effect.hover * 0.05)
+        if effect.selection > 0 {
+            GameLobbyStyle.gradient(face, colors: [.white.withAlphaComponent(effect.selection),
+                NSColor(calibratedRed: 0.86, green: 0.95, blue: 1, alpha: effect.selection)], radius: 15)
+            GameLobbyStyle.glow(NSRect(x: face.minX, y: face.minY, width: 100, height: face.height), color: HomeStyle.blue.withAlphaComponent(0.09 * effect.selection))
+        }
+        let outline = NSBezierPath(roundedRect: face, xRadius: 15, yRadius: 15)
+        HomeStyle.blue.withAlphaComponent(effect.selection * 0.8 + effect.hover * 0.15).setStroke()
+        outline.lineWidth = 1.25; outline.stroke()
+        let iconSize = min(57, face.height - 9)
+        GameModeArtwork.draw(mode, in: NSRect(x: face.minX + 12, y: face.midY - iconSize / 2, width: iconSize, height: iconSize))
+        let textX = face.minX + 81, textWidth = face.width - 108
+        let title = AchievementText.string("home.mode.\(mode.key)")
+        let compact = face.height < 65
+        let titleSize = GameLobbyStyle.fittedSize(title, width: textWidth, preferred: compact ? 17 : 20, minimum: 13, weight: .bold)
+        let textY = compact ? face.minY + 4 : face.midY - 24
+        HomeStyle.text(title, in: NSRect(x: textX, y: textY, width: textWidth, height: 26), size: titleSize, weight: .bold)
+        GameLobbyStyle.wrappedText(AchievementText.string("home.mode_desc.\(mode.key)"),
+            in: NSRect(x: textX, y: textY + (compact ? 21 : 27), width: face.width - 98, height: face.maxY - textY - (compact ? 25 : 31)),
+            size: compact ? 11 : 12, color: HomeStyle.secondary)
+        if effect.selection > 0 {
+            HomeStyle.symbol("checkmark.circle.fill", in: NSRect(x: face.maxX - 24, y: face.minY + 12, width: 15, height: 15), color: HomeStyle.blue.withAlphaComponent(effect.selection))
+        }
@@ -116 +139 @@
-        HomeStyle.card(bounds)
+        GameLobbyStyle.surface(bounds.insetBy(dx: 3, dy: 4), radius: 16, tint: NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1))
@@ -118 +141,3 @@
-        HomeStyle.text(AchievementText.string("home.cleared_title"), in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: 20, weight: .bold)
+        let title = AchievementText.string("home.cleared_title")
+        let titleSize = GameLobbyStyle.fittedSize(title, width: dividerX - 30, preferred: 20, minimum: 11, weight: .bold)
+        HomeStyle.text(title, in: NSRect(x: 22, y: 17, width: dividerX - 30, height: 26), size: titleSize, weight: .bold)
@@ -145 +170,5 @@
-        HomeStyle.card(bounds)
+        GameLobbyStyle.surface(bounds.insetBy(dx: 1, dy: 1), radius: 12,
+                               tint: NSColor(calibratedRed: 1, green: 0.998, blue: 0.985, alpha: 1), strength: 0.025)
+        if hovering {
+            GameLobbyStyle.glow(bounds, color: GameLobbyStyle.amber.withAlphaComponent(0.07 * feedback.values.hover))
+        }
@@ -163 +192 @@
-        HomeStyle.symbol(status, in: NSRect(x: 13, y: bounds.midY - 10, width: 20, height: 20), color: unlocked ? HomeStyle.green : HomeStyle.muted)
+        HomeStyle.symbol(status, in: NSRect(x: 14, y: bounds.midY - 9, width: 18, height: 18), color: unlocked ? HomeStyle.green.withAlphaComponent(0.80) : HomeStyle.muted)
@@ -177,0 +207 @@
+    let challengeHUD = HomeChallengeHUDView(frame: .zero)
@@ -187,0 +218 @@
+    private var showsChallenge = false
@@ -195,2 +226,2 @@
-        subtitle.textColor = HomeStyle.muted
-        subtitle.font = .systemFont(ofSize: 21, weight: .semibold)
+        subtitle.textColor = HomeStyle.secondary.withAlphaComponent(0.82)
+        subtitle.font = .systemFont(ofSize: 19, weight: .medium)
@@ -200 +231,2 @@
-        [heading, subtitle, hint, hero, stats, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        [heading, subtitle, hint, hero, stats, challengeHUD, startButton, records, rules, settings, all].forEach { addSubview($0) }
+        challengeHUD.isHidden = true
@@ -223,2 +255,6 @@
-        heading.stringValue = AchievementText.string("home.hero.\(mode.key)")
-        subtitle.stringValue = AchievementText.string("home.subtitle.\(mode.key)")
+        showsChallenge = mode != .free && (snapshot.isRunning || snapshot.isFinished)
+        challengeHUD.isHidden = !showsChallenge
+        challengeHUD.refresh(snapshot: snapshot, mode: mode)
+        heading.stringValue = AchievementText.string(showsChallenge ? "home.mode.\(mode.key)" : "home.hero.\(mode.key)")
+        subtitle.stringValue = AchievementText.string(showsChallenge ? "home.mode_desc.\(mode.key)" : "home.subtitle.\(mode.key)")
+        subtitle.font = .systemFont(ofSize: showsChallenge ? 14 : 19, weight: .medium)
@@ -229,4 +264,0 @@
-        } else if snapshot.isRunning, mode != .free {
-            hint.stringValue = mode == .timed
-                ? AchievementText.format("home.hud.timed", snapshot.totalCleared, Self.clock(snapshot.remainingTime ?? 0))
-                : AchievementText.format("home.hud.moves", snapshot.totalCleared, snapshot.remainingSwaps ?? 0)
@@ -270 +302 @@
-        heading.font = .systemFont(ofSize: min(68, max(48, leftWidth * 0.1)), weight: .heavy)
+        heading.font = .systemFont(ofSize: showsChallenge ? 24 : min(60, max(44, leftWidth * 0.092)), weight: .heavy)
@@ -272 +304 @@
-        heading.frame = NSRect(x: margin, y: top + 30, width: leftWidth, height: bodyHeight * 0.33)
+        heading.frame = NSRect(x: margin, y: top + (showsChallenge ? 10 : 26), width: leftWidth, height: showsChallenge ? 36 : bodyHeight * 0.32)
@@ -274,3 +306,4 @@
-        subtitle.frame = NSRect(x: margin, y: top + bodyHeight * 0.34, width: leftWidth, height: 56)
-        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.47, width: leftWidth - 24, height: 125)
-        startButton.frame = NSRect(x: margin + (leftWidth - 280) / 2, y: footerY - 82, width: 280, height: 54)
+        subtitle.frame = NSRect(x: margin, y: showsChallenge ? top + 49 : top + bodyHeight * 0.33, width: leftWidth, height: showsChallenge ? 32 : 56)
+        challengeHUD.frame = NSRect(x: margin, y: top + 83, width: leftWidth, height: min(128, bodyHeight * 0.27))
+        hero.frame = NSRect(x: margin + 12, y: top + bodyHeight * 0.45, width: leftWidth - 24, height: 138)
+        startButton.frame = NSRect(x: margin + (leftWidth - 294) / 2, y: footerY - 89, width: 294, height: 62)
@@ -279 +312 @@
-        let rowHeight = (modeHeight - 104) / 3
+        let rowHeight = (modeHeight - 86) / 3
@@ -281 +314 @@
-            button.frame = NSRect(x: rightX + 20, y: top + 68 + CGFloat(index) * (rowHeight + 12), width: rightWidth - 40, height: rowHeight)
+            button.frame = NSRect(x: rightX + 20, y: top + 60 + CGFloat(index) * (rowHeight + 8), width: rightWidth - 40, height: rowHeight)
@@ -303 +336,4 @@
-        HomeStyle.card(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172))
+        GameLobbyStyle.surface(NSRect(x: rightX, y: 96, width: rightWidth, height: bodyHeight - 172), radius: 20,
+                               tint: NSColor(calibratedRed: 0.985, green: 0.983, blue: 0.974, alpha: 1), strength: 0.025)
+        // 暖色环境光承接原设计稿插画；静态绘制，不添加常驻粒子计时器。
+        GameLobbyStyle.glow(NSRect(x: margin - 20, y: 245, width: rightX - margin, height: 265), color: GameLobbyStyle.amber.withAlphaComponent(0.045))
@@ -319 +355,3 @@
-        HomeStyle.text(AchievementText.string("home.achievement_path"), in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: 21, weight: .bold)
+        let achievementTitle = AchievementText.string("home.achievement_path")
+        let achievementSize = GameLobbyStyle.fittedSize(achievementTitle, width: 140, preferred: 21, minimum: 13, weight: .bold)
+        HomeStyle.text(achievementTitle, in: NSRect(x: margin, y: footerY + 15, width: 140, height: 30), size: achievementSize, weight: .bold)
@@ -324 +362,4 @@
-        HomeStyle.yellow.setFill(); NSBezierPath(roundedRect: NSRect(x: meter.minX, y: meter.minY, width: max(0, meter.width * ratio), height: meter.height), xRadius: 6, yRadius: 6).fill()
+        if ratio > 0 {
+            GameLobbyStyle.gradient(NSRect(x: meter.minX, y: meter.minY, width: meter.width * ratio, height: meter.height),
+                                    colors: [NSColor(calibratedRed: 1, green: 0.87, blue: 0.24, alpha: 1), HomeStyle.yellow], radius: 6)
+        }
@@ -328,5 +369 @@
-    private static func clock(_ interval: TimeInterval) -> String {
-        let value = max(0, Int(interval))
-        return String(format: "%02d:%02d", value / 60, value % 60)
-    }
-}
+}
```

### `Sources/HomeUtilityPanel.swift`

```diff
--- a/Sources/HomeUtilityPanel.swift
+++ b/Sources/HomeUtilityPanel.swift
@@ -41 +41 @@
-        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = ["stopwatch", "arrow.left.arrow.right"]
+        recordTabs.segmentCount = 2; recordTabs.segmentSymbols = [HomeGameMode.timed.symbol, HomeGameMode.moves.symbol]
```

### `Sources/HomeUtilityViews.swift`

```diff
--- a/Sources/HomeUtilityViews.swift
+++ b/Sources/HomeUtilityViews.swift
@@ -254 +254 @@
-        let icon = UtilityStyle.icon(mode == .timed ? "stopwatch" : "arrow.left.arrow.right", color: .systemOrange, size: 56)
+        let icon = UtilityStyle.icon(mode == .timed ? HomeGameMode.timed.symbol : HomeGameMode.moves.symbol, color: .systemOrange, size: 56)
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -249,0 +250,3 @@
+
+"home.challenge.time_left" = "TIME LEFT";
+"home.challenge.moves_left" = "SWAPS LEFT";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -242,0 +243,3 @@
+
+"home.challenge.time_left" = "残り時間";
+"home.challenge.moves_left" = "残り交換回数";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -242,0 +243,3 @@
+
+"home.challenge.time_left" = "남은 시간";
+"home.challenge.moves_left" = "남은 교환 횟수";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -242,0 +243,3 @@
+
+"home.challenge.time_left" = "ОСТАЛОСЬ ВРЕМЕНИ";
+"home.challenge.moves_left" = "ОСТАЛОСЬ ОБМЕНОВ";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -249,0 +250,3 @@
+
+"home.challenge.time_left" = "剩余时间";
+"home.challenge.moves_left" = "剩余交换次数";
```

### `Tests/GameLobbyPresentationTests.swift`

```diff
--- /dev/null
+++ b/Tests/GameLobbyPresentationTests.swift
@@ -0,0 +1,178 @@
+import Cocoa
+import ImageIO
+import XCTest
+@testable import EliminateTeris1
+
+/// 验证新视觉反馈不会改变真实规则，预览全部使用隔离存档。
+final class GameLobbyPresentationTests: AchievementTestCase {
+    private func image(_ view: NSView) throws -> NSBitmapImageRep {
+        view.layoutSubtreeIfNeeded()
+        let pixels = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
+        view.cacheDisplay(in: view.bounds, to: pixels)
+        return pixels
+    }
+    private func export(_ view: NSView, name: String) throws {
+        try XCTUnwrap(try image(view).representation(using: .png, properties: [:]))
+            .write(to: FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-\(name).png"))
+    }
+
+    func testFeedbackReversalRefreshAndReducedMotionPreserveVisibleState() {
+        var clock: TimeInterval = 100
+        let effect = GameControlFeedback()
+        effect.now = { clock }; effect.reducesMotion = { false }
+        // 离屏初次展示直接到位；挂到窗口后再悬停不能使选中高光倒退。
+        effect.update(hover: false, press: false, selected: true, animated: false)
+        clock += 0.01
+        effect.update(hover: true, press: false, selected: true, animated: true)
+        XCTAssertEqual(effect.values.selection, 1)
+        clock += GameControlFeedback.duration / 2
+        effect.advance(at: clock)
+        XCTAssertEqual(effect.values.hover, 0.5, accuracy: 0.001)
+        effect.update(hover: true, press: false, selected: true, animated: true)
+        clock += GameControlFeedback.duration / 2
+        effect.advance(at: clock)
+        XCTAssertEqual(effect.values.hover, 1, accuracy: 0.001, "重复刷新不能重新计时")
+        effect.update(hover: false, press: false, selected: false, animated: true)
+        clock += GameControlFeedback.duration / 2; effect.advance(at: clock)
+        let halfway = effect.values
+        effect.update(hover: true, press: true, selected: true, animated: true)
+        XCTAssertEqual(effect.values, halfway, "快速反向从当前画面接续")
+        effect.reducesMotion = { true }
+        effect.advance(at: clock)
+        XCTAssertEqual(effect.values, .init(hover: 1, press: 1, selection: 1))
+    }
+
+    func testChallengeBudgetUsesSnapshotAndClampsAtTheRuleBoundary() {
+        let hud = HomeChallengeHUDView(frame: NSRect(x: 0, y: 0, width: 500, height: 128))
+        hud.refresh(snapshot: GameSnapshot(mode: .timed(duration: 60), elapsedTime: 0.1, remainingTime: 59.9,
+                                          remainingSwaps: nil, isRunning: true, isFinished: false), mode: .timed)
+        XCTAssertEqual(hud.budgetText, "01:00", "不提前跳过第一秒")
+        XCTAssertEqual(hud.remainingFraction, CGFloat(59.9 / 60), accuracy: 0.001)
+        hud.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 600, remainingTime: nil,
+                                          remainingSwaps: 18, isRunning: true, isFinished: false), mode: .moves)
+        XCTAssertEqual(hud.budgetText, "18")
+        XCTAssertEqual(hud.remainingFraction, 0.6, accuracy: 0.001)
+        hud.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 600, remainingTime: nil,
+                                          remainingSwaps: 0, isRunning: false, isFinished: true), mode: .moves)
+        XCTAssertEqual(hud.remainingFraction, 0)
+        XCTAssertEqual(hud.budgetText, "0")
+    }
+
+    func testLobbyStatesAndFiveLanguagesExportRealViewsWithoutChangingAchievements() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let saved = defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary
+        let home = HomeDashboardView(frame: NSRect(x: 0, y: 0, width: 1180, height: 800))
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            for mode in HomeGameMode.allCases {
+                for running in [false, true] {
+                    let snapshot = GameSnapshot(mode: mode.gameMode, elapsedTime: running ? 42 : 0,
+                        remainingTime: mode == .timed ? (running ? 18 : 60) : nil,
+                        remainingSwaps: mode == .moves ? (running ? 12 : 30) : nil,
+                        isRunning: running, isFinished: false,
+                        clearedByKind: running ? [.orangeRicky: 15, .blueRicky: 9, .clevelandZ: 6, .rhodeIslandZ: 12] : [:])
+                    for size in [NSSize(width: 960, height: 720), NSSize(width: 1180, height: 800), NSSize(width: 1920, height: 1080)] {
+                        home.setFrameSize(size); home.refresh(snapshot: snapshot, mode: mode, manager: manager)
+                        _ = try image(home)
+                        XCTAssertEqual(home.challengeHUD.isHidden, !running || mode == .free)
+                        XCTAssertEqual(home.stats.snapshot?.totalCleared, running ? 42 : 0)
+                        XCTAssertTrue(home.bounds.contains(home.challengeHUD.frame))
+                        if language == .chineseSimplified, size.width == 1180 {
+                            try export(home, name: running ? "lobby-\(mode.key)" : "lobby-idle-\(mode.key)")
+                        }
+                        if language == .russian, size.width == 960, mode == .moves, !running {
+                            try export(home, name: "lobby-compact-ru")
+                        }
+                    }
+                }
+            }
+        }
+        XCTAssertEqual(defaults.object(forKey: AchievementsManager.storageKey) as? NSDictionary, saved)
+        Localizer.shared.setLanguage(.chineseSimplified)
+        home.setFrameSize(NSSize(width: 1180, height: 800))
+        home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 150, remainingTime: nil,
+            remainingSwaps: 3, isRunning: true, isFinished: false, clearedByKind: [.orangeRicky: 120]), mode: .moves, manager: manager)
+        try export(home, name: "lobby-last-moves")
+        home.refresh(snapshot: GameSnapshot(mode: .moves(limit: 30), elapsedTime: 160, remainingTime: nil,
+            remainingSwaps: 0, isRunning: false, isFinished: true, clearedByKind: [.orangeRicky: 126]), mode: .moves, manager: manager)
+        XCTAssertFalse(home.challengeHUD.isHidden)
+        XCTAssertEqual(home.challengeHUD.budgetText, "0")
+        try export(home, name: "lobby-finished")
+    }
+
+    func testModeArtworkKeepsTransparencyAndIdentityAtSmallAndWideSizes() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        var unique: Set<Data> = []
+        for mode in HomeGameMode.allCases {
+            unique.insert(try XCTUnwrap(GameModeArtwork.image(for: mode).tiffRepresentation))
+            for size in [NSSize(width: 24, height: 24), NSSize(width: 64, height: 64), NSSize(width: 120, height: 64)] {
+                let artwork = NSImage(size: size, flipped: true) { bounds in GameModeArtwork.draw(mode, in: bounds); return true }
+                let pixels = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(artwork.tiffRepresentation)))
+                XCTAssertLessThan(pixels.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.01)
+                var colored = 0
+                for y in 0..<pixels.pixelsHigh {
+                    for x in 0..<pixels.pixelsWide {
+                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.5 else { continue }
+                        if max(color.redComponent, color.greenComponent, color.blueComponent) - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.2 { colored += 1 }
+                    }
+                }
+                XCTAssertGreaterThan(colored, 25, "每种模式都应有独立彩色主体")
+            }
+        }
+        XCTAssertEqual(unique.count, 3)
+        try export(ModeArtworkPreview(frame: NSRect(x: 0, y: 0, width: 600, height: 200)), name: "mode-artwork")
+    }
+
+    func testExportActualSelectionAndButtonFeedbackAnimation() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        Localizer.shared.setLanguage(.chineseSimplified)
+        let preview = LobbyFeedbackPreview(frame: NSRect(x: 0, y: 0, width: 340, height: 180))
+        let mode = HomeModeButton(mode: .moves)
+        mode.frame = NSRect(x: 10, y: 80, width: 320, height: 90); mode.selected = true
+        let button = HomeButton(frame: NSRect(x: 23, y: 10, width: 294, height: 62))
+        button.primary = true; button.title = "开始游戏"; button.symbolName = "play.fill"
+        preview.addSubview(mode); preview.addSubview(button)
+        var clock: TimeInterval = 100
+        for effect in [mode.feedback, button.feedback] { effect.now = { clock }; effect.reducesMotion = { false } }
+        mode.feedback.update(hover: false, press: false, selected: false, animated: false)
+        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-lobby-feedback.gif") as CFURL,
+                                                                      "com.compuserve.gif" as CFString, 36, nil))
+        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
+        for frame in 0..<36 {
+            if frame == 0 { mode.feedback.update(hover: false, press: false, selected: true, animated: true) }
+            if frame == 10 { button.feedback.update(hover: true, press: false, animated: true) }
+            if frame == 20 { button.feedback.update(hover: true, press: true, animated: true) }
+            if frame == 27 { button.feedback.update(hover: false, press: false, animated: true) }
+            mode.feedback.advance(at: clock); button.feedback.advance(at: clock)
+            let pixels = try image(preview)
+            CGImageDestinationAddImage(destination, try XCTUnwrap(pixels.cgImage), [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
+            clock += 0.04
+        }
+        XCTAssertTrue(CGImageDestinationFinalize(destination))
+    }
+}
+
+private final class LobbyFeedbackPreview: NSView {
+    override func draw(_ dirtyRect: NSRect) { HomeStyle.background.setFill(); bounds.fill() }
+}
+
+/// 仅测试 target 中的三枚图案总览，不增加正式页面入口。
+private final class ModeArtworkPreview: NSView {
+    override var isFlipped: Bool { true }
+    override func draw(_ dirtyRect: NSRect) {
+        HomeStyle.background.setFill(); bounds.fill()
+        for (index, mode) in HomeGameMode.allCases.enumerated() {
+            let x = CGFloat(index) * 200
+            GameModeArtwork.draw(mode, in: NSRect(x: x + 50, y: 18, width: 100, height: 100))
+            HomeStyle.text(AchievementText.string("home.mode.\(mode.key)"), in: NSRect(x: x + 10, y: 130, width: 180, height: 26), size: 18, weight: .semibold, alignment: .center)
+            GameModeArtwork.draw(mode, in: NSRect(x: x + 88, y: 166, width: 24, height: 24))
+        }
+    }
+}
```

### `docs/previews/README.md`

```diff
--- a/docs/previews/README.md
+++ b/docs/previews/README.md
@@ -3,0 +4,14 @@
+
+## 游戏大厅美术与交互反馈
+
+- [待机首页](lobby-idle.png)：暖白环境光、设计稿方块、柔和立体卡片与金色主按钮。
+- [三种模式新图案](mode-artwork.png)：自由悬浮方块、橙金冲刺秒表、蓝色 30 次行动计数器；展示大图和 24 点小图。
+- [实际交互动画](lobby-feedback.gif)：使用真实控件导出的选中辉光、悬停提亮与按压下沉。
+- [限时局内](challenge-timed.png)、[限步局内](challenge-moves.png)：大号剩余预算、消除数量与时间/行动条。
+- [最后三次行动](lobby-last-moves.png)、[本局结束](lobby-finished.png)：紧张阶段改用红色提示，结束后保留本局结果。
+- 模式入口图案不读取本局剩余次数；其中 30 表示固定模式规则。
+- 减少动态效果开启时交互立即定位；测试在独立存档和可控时间下生成预览。
+
+重新生成：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameLobbyPresentationTests`。
+
+临时目录中的 `eliminate-lobby-idle-free.png` 对应 `lobby-idle.png`，`eliminate-lobby-timed.png` / `eliminate-lobby-moves.png` 对应两张 `challenge-*.png`；其余 `eliminate-mode-artwork.png`、`eliminate-lobby-feedback.gif`、`eliminate-lobby-last-moves.png`、`eliminate-lobby-finished.png` 去掉 `eliminate-` 前缀后归档。
```

### `docs/previews/achievement-labels-fullscreen.png`

```diff
- 54593 字节；SHA-256 49c35a9735b529f9210d779312054d5d7922af8133d42098545e13413cc84dc9
+ 137517 字节；SHA-256 7adf90b19fbca3e83e054fb3605dd0987b222220d2cb45a9973afabec2a9e472
```

### `docs/previews/achievement-labels.png`

```diff
- 47030 字节；SHA-256 6fdd0a9cc1a69bce3a0081cd593336dad9e063030407e106906447a3eac32181
+ 102372 字节；SHA-256 c6acb2719654556772f6f498aa63f0d3dcbea5a45209094c89cfa974ff52498b
```

### `docs/previews/challenge-moves.png`

```diff
- 496396 字节；SHA-256 bcdad5c62e51fcbe0b06ee53167af827bbefeeb3d784904d2ef4570382224e65
+ 1235174 字节；SHA-256 99863fbf1acae7a4c16b90dd514dd8aceba97461d873ce627c9d6a525d8d014c
```

### `docs/previews/challenge-timed.png`

```diff
- 502285 字节；SHA-256 20d194f87cb0a442ca4cf8b9bab7e550426797a168b73cbe8d0da748a06ad07f
+ 1232610 字节；SHA-256 b6e8c19a1d508c0f47d201cb22ac5f3bc23d08594a3bc1c295f83da4df37776a
```

### `docs/previews/lobby-feedback.gif`

```diff
- 不存在（新增预览）
+ 174037 字节；SHA-256 79a0edeea049a3a5aa99e9c4ae16df36f1c29ac0dc5fb156149a178198b00be4
```

### `docs/previews/lobby-finished.png`

```diff
- 不存在（新增预览）
+ 1240242 字节；SHA-256 69339466ddd3681525c461e73553ab610814aedbfd879fe2c0a9f06e5c7809c6
```

### `docs/previews/lobby-idle.png`

```diff
- 不存在（新增预览）
+ 1122289 字节；SHA-256 44a1b90b7e2777601e2fb1ca2004fa199a749cc743e299819db97772d8fc405d
```

### `docs/previews/lobby-last-moves.png`

```diff
- 不存在（新增预览）
+ 1257715 字节；SHA-256 570a5062e0d68eb849bcfaa9ce9d97d9a7f9898deb1bfb7d5a7bb278ab3b1a29
```

### `docs/previews/mode-artwork.png`

```diff
- 不存在（新增预览）
+ 114829 字节；SHA-256 66fb8da9e7126df81a95e0ffc98cca15f255b6a1fc7a60a36ab14c9996913f3e
```

### `docs/previews/utility-records-empty.png`

```diff
- 143273 字节；SHA-256 d1b7632bdd7335ae80264c599cbc8f48babf5cbb1fc03d3f8cb566bb531c592f
+ 145039 字节；SHA-256 2992f6c5df3fb075efb55ff932373065398a7d50817d0fdc042296141691fe14
```

### `docs/previews/utility-records-history.png`

```diff
- 160566 字节；SHA-256 020ee3d2aa911bcc0949d523330b3d04f3aa3d4ced1400c2af7dc5ca658cdea4
+ 162701 字节；SHA-256 2c82f435b58ca687895130a9510d3ccc95cbd84781b4cf23322096c5c2132196
```

### `docs/previews/utility-records-speed.png`

```diff
- 195837 字节；SHA-256 d089e14aba2b3c0ca018c1c112cf783a59ac3d53ae5402f5819e433eb958492a
+ 198987 字节；SHA-256 d24e7a80d070fcff7ea80c23fa74d8b50c89fd77087bcf6d830d4ce0d444f99d
```

### `docs/previews/utility-records.png`

```diff
- 198906 字节；SHA-256 9a783b2c211c0a916d1e04db887503aa428a14b00ecc2f94d2e9a85915038676
+ 200883 字节；SHA-256 45bc0d7a5403e9daa47b2e7d70dacd66349afc4bf3fa6dd4cde9884b46bcbe31
```

### `docs/previews/utility-rules.png`

```diff
- 217770 字节；SHA-256 232c161f95c90205d36ac1ec6a2c1bfc63a2f552b8aa6ed73d2bacedde4f6aee
+ 221930 字节；SHA-256 529eb5463d1b7626e13795548c8166dd8455ea6b97fd8cb840a62f9d93227a29
```
