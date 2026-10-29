# 累计消除卡片的七段数字与跳动反馈

## 背景与目标
- 对应会话：会话-38 起，用户要求移除每种方块旁重复的“累计消除”，改为整张卡片标题。
- 数量使用计算器式七段数码管，数字与对应方块等高、同步浮动；产生新消除时对应数字增加跳动反馈。
- 本轮开始时存在上一轮尚未提交的分类统计改动。本文以本轮开始快照记录增量，保留 `20261029222742-piece-clear-counts-and-milestones.md` 中的独立实现记录。

## 约束与原则
- 卡片仍为 88 点高，不改变主窗口整体布局。
- 保留各方块颜色、本地化数字分组、完整数量及辅助功能说明。
- 不改动消除统计、成就、存档、Touch Bar 或玩法逻辑。
- 不依赖额外字体或图片资源，使用原生 AppKit 路径绘制。
- 本轮为局部展示及反馈变化，不向 AGENTS.md 添加具体视觉需求。

## 阶段与 TODO
- [x] 将“累计消除”改为顶部统一标题，移除各类型重复小标题。
- [x] 新增七段数字原生绘制器，支持 0—9 与本地化分组符。
- [x] 让数字与方块共用高度及基础浮动坐标，长数量仅压缩横向宽度。
- [x] 在对应类型数量增长时触发独立跳动，首次加载、同值刷新及语言切换不触发。
- [x] 使用单调时钟驱动跳动，并尊重系统“减少动态效果”设置。
- [x] 完成确定性动画测试、五语言渲染、视觉验收与差异检查。
- [x] 新建完整增量文档并登记根索引。

## 实现要点
- `SevenSegmentNumberRenderer` 使用七段掩码与带斜角的多边形绘制数字，未点亮段以低透明度显示。
- 每个数字区高度等于旁边形状的整体高度；不足宽度时只缩放横向段宽，不缩小高度，也不把数字改为 K/M 缩写。
- 顶部统一标题复用现有 `banner.total_cleared` 五语言文案；网格区域向下让出标题空间。
- 图案与数字直接使用同一个基础 Y 坐标，持续浮动的相位、振幅一致。
- `PixelBannerView` 保存各类型上次显示值，新增数量大于旧值时记录该类型的跳动起点。
- 跳动持续约 0.42 秒，使用正弦曲线向上最多 6 点后回落，仅影响对应数字；快速增长时以最新一次事件重新触发。
- 时钟默认为系统运行时长，可注入测试时钟；初次恢复存档仅显示已有数量。
- 系统启用“减少动态效果”时，停止该卡片的浮动、数字跳动及网格脉动，数量仍立即更新。

## 测试用例与结果

### TC-001 对应数字跳动并回落
- 类型：动画状态测试；优先级：高；模块：PixelBannerView。
- 前置条件：注入可控单调时钟，使用独立测试存档。
- 操作步骤：先加载零值，增加橙色数量，推进到 0.21 秒与 0.5 秒；再增加蓝色数量。
- 预期结果：橙色先跳起至约 -6 点并回到 0；其余类型保持 0；之后只有蓝色跳动。
- 是否通过：通过。

### TC-002 初始加载及同值刷新
- 类型：动画状态测试；优先级：高。
- 前置条件：存档中已有橙色累计值。
- 操作步骤：首次加载并推进时钟；新增一次消除，在跳动中重复刷新相同值；动画结束后再次刷新。
- 预期结果：首次加载不跳；中途刷新不重置起点；结束后同值刷新不再次触发。
- 是否通过：通过。

### TC-003 七段数字与五语言渲染
- 类型：原生界面/视觉验收；优先级：高。
- 操作步骤：使用 100、1,000、10,000、1,234,567,890 样本，在五种语言下绘制统计横幅；渲染中文预览并实际查看。
- 预期结果：统一标题、四个对应颜色的七段数字均正常显示；所有 0—9 字形、分组符、大数量完整且不越界，数字与方块同高。
- 是否通过：通过，已查看测试生成的真实渲染 PNG。

### TC-004 既有界面行为回归
- 类型：界面回归；优先级：高。
- 操作步骤：运行五枚徽章显示、五语言图文居中、筛选点击、图鉴布局、首次打开居中、边缘定位用例。
- 预期结果：原有交互与定位正常。
- 是否通过：通过。

## 当前进展与验证
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AchievementPresentationTests`：9 项测试，0 失败；应用编译与链接正常。
- `git diff --check`：通过。
- 视觉预览仍由测试生成至临时目录 `eliminate-piece-counts-banner.png`，使用隔离数据，不修改玩家存档。
- 本轮未重启用户当前游戏进程，重启后可查看七段数字与跳动效果。

## 代码变更

以下为相对本轮开始快照的全部逐行增量 diff，包含新增绘制文件。

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -2524,6 +2524,24 @@
     private var animationTick: CGFloat = 0
     private var animationTimer: Timer?
     private var countTexts: [PieceKind: String] = [:]
+    private var previousCounts: [PieceKind: Double] = [:]
+    private var jumpStartedAt: [PieceKind: TimeInterval] = [:]
+    private let animationClock: () -> TimeInterval
+
+    init(frame: NSRect, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
+        self.animationClock = clock
+        super.init(frame: frame)
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    /// 数量增长时跳起并落回；使用单调时钟，避免系统时间调整干扰动画。
+    func numberJumpOffset(for kind: PieceKind) -> CGFloat {
+        guard let start = jumpStartedAt[kind] else { return 0 }
+        let progress = (animationClock() - start) / 0.42
+        guard progress >= 0, progress < 1 else { return 0 }
+        return -6 * CGFloat(sin(progress * .pi))
+    }
 
     /// 与成就共用累计数据源，语言切换时同步更新数字格式及辅助功能说明。
     func refresh(manager: AchievementsManager) {
@@ -2532,8 +2550,17 @@
         formatter.numberStyle = .decimal
         formatter.maximumFractionDigits = 0
         var descriptions: [String] = []
+        let now = animationClock()
         for kind in PieceKind.allCases {
-            let text = formatter.string(from: NSNumber(value: manager.totalCleared(for: kind))) ?? "0"
+            let count = manager.totalCleared(for: kind)
+            if let previous = previousCounts[kind], count > previous {
+                jumpStartedAt[kind] = now
+            } else if count < previousCounts[kind, default: 0] {
+                jumpStartedAt.removeValue(forKey: kind)
+            }
+            // 首次加载与同值刷新仅恢复显示，不把历史数量误当作新消除。
+            previousCounts[kind] = count
+            let text = formatter.string(from: NSNumber(value: count)) ?? "0"
             countTexts[kind] = text
             descriptions.append(AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), text))
         }
@@ -2586,7 +2613,13 @@
         outerPath.lineWidth = 1
         outerPath.stroke()
 
-        let boardRect = outerRect.insetBy(dx: 12, dy: 12)
+        let titleRect = NSRect(x: outerRect.minX + 16, y: outerRect.minY + 10, width: max(0, outerRect.width - 32), height: 14)
+        (AchievementText.string("banner.total_cleared") as NSString).draw(in: titleRect, withAttributes: [
+            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .heavy),
+            .foregroundColor: NSColor(calibratedRed: 0.7, green: 0.86, blue: 1, alpha: 0.96)
+        ])
+        let boardRect = NSRect(x: outerRect.minX + 12, y: outerRect.minY + 30,
+                               width: max(0, outerRect.width - 24), height: max(0, outerRect.height - 42))
         NSColor.black.withAlphaComponent(0.38).setFill()
         NSBezierPath(roundedRect: boardRect, xRadius: 6, yRadius: 6).fill()
 
@@ -2595,7 +2628,8 @@
     }
 
     private func drawGrid(in rect: CGRect) {
-        let pulse = 0.06 + CGFloat((sin(Double(animationTick) * 0.08) + 1) * 0.025)
+        let pulse = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
+            ? 0.08 : 0.06 + CGFloat((sin(Double(animationTick) * 0.08) + 1) * 0.025)
         let lineColor = NSColor.white.withAlphaComponent(pulse)
         let step: CGFloat = 9
         let path = NSBezierPath()
@@ -2624,7 +2658,9 @@
         guard !kinds.isEmpty else { return }
 
         let slotWidth = rect.width / CGFloat(kinds.count)
-        let baseBlockSize = max(7, min(10, floor((rect.height - 14) / 4)))
+        // 当前四种图案均为两行，为浮动和数字跳动预留上下空间。
+        let baseBlockSize = max(7, min(10, floor((rect.height - 16) / 2)))
+        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
 
         for (index, kind) in kinds.enumerated() {
             let blocks = kind.blocks
@@ -2640,21 +2676,12 @@
             let pieceHeight = CGFloat(heightCells) * baseBlockSize
 
             let slotX = rect.minX + CGFloat(index) * slotWidth
-            let wave = CGFloat(sin(Double(animationTick) * 0.12 + Double(index) * 0.7)) * 2.2
+            let wave = reduceMotion ? 0 : CGFloat(sin(Double(animationTick) * 0.12 + Double(index) * 0.7)) * 2.2
             let count = countTexts[kind] ?? "0"
-            let caption = AchievementText.string("banner.total_cleared")
-            let maximumTextWidth = max(1, slotWidth - pieceWidth - 26)
-            var fontSize: CGFloat = 14
-            var countFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
-            // 数量增加时适度收缩数字字号，避免与相邻类型重叠。
-            while (count as NSString).size(withAttributes: [.font: countFont]).width > maximumTextWidth, fontSize > 9 {
-                fontSize -= 1
-                countFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
-            }
-            let captionFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
-            let textWidth = min(maximumTextWidth, max((count as NSString).size(withAttributes: [.font: countFont]).width,
-                                                    (caption as NSString).size(withAttributes: [.font: captionFont]).width))
-            let originX = slotX + (slotWidth - pieceWidth - 10 - textWidth) * 0.5
+            let numberWidth = min(max(1, slotWidth - pieceWidth - 26),
+                                  SevenSegmentNumberRenderer.width(for: count, height: pieceHeight))
+            let originX = slotX + (slotWidth - pieceWidth - 10 - numberWidth) * 0.5
+            // 图案与数字共用基础 Y 坐标，因此持续浮动的相位与振幅始终一致。
             let originY = rect.minY + (rect.height - pieceHeight) * 0.5 + wave
             let glowPulse = CGFloat((sin(Double(animationTick) * 0.14 + Double(index)) + 1) * 0.5)
 
@@ -2667,15 +2694,11 @@
                 blockSize: baseBlockSize,
                 pulse: glowPulse
             )
-            let textX = originX + pieceWidth + 10
-            let textY = rect.midY - 17
-            let paragraph = NSMutableParagraphStyle()
-            paragraph.lineBreakMode = .byTruncatingTail
+            let jump = reduceMotion ? 0 : numberJumpOffset(for: kind)
+            let numberRect = NSRect(x: originX + pieceWidth + 10, y: originY + jump,
+                                    width: numberWidth, height: pieceHeight)
             let color = kind.color.blended(withFraction: 0.4, of: .white) ?? kind.color
-            (caption as NSString).draw(in: NSRect(x: textX, y: textY, width: textWidth, height: 12),
-                                      withAttributes: [.font: captionFont, .foregroundColor: color.withAlphaComponent(0.8), .paragraphStyle: paragraph])
-            (count as NSString).draw(in: NSRect(x: textX, y: textY + 14, width: textWidth, height: 21),
-                                    withAttributes: [.font: countFont, .foregroundColor: color, .paragraphStyle: paragraph])
+            SevenSegmentNumberRenderer.draw(count, in: numberRect, color: color)
         }
     }
 
```

### `Sources/SevenSegmentNumberRenderer.swift`

```diff
diff --git a/Sources/SevenSegmentNumberRenderer.swift b/Sources/SevenSegmentNumberRenderer.swift
--- /dev/null
+++ b/Sources/SevenSegmentNumberRenderer.swift
@@ -0,0 +1,74 @@
+import Cocoa
+
+/// 直接绘制计算器式七段数字；只在水平方向适配可用宽度，保持数字高度不变。
+enum SevenSegmentNumberRenderer {
+    // 段位依次为：上、右上、右下、下、左下、左上、中。
+    private static let digitMasks = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]
+    private static let segments: [NSRect] = [
+        NSRect(x: 0.08, y: 0, width: 0.39, height: 0.08),
+        NSRect(x: 0.47, y: 0.08, width: 0.08, height: 0.38),
+        NSRect(x: 0.47, y: 0.54, width: 0.08, height: 0.38),
+        NSRect(x: 0.08, y: 0.92, width: 0.39, height: 0.08),
+        NSRect(x: 0, y: 0.54, width: 0.08, height: 0.38),
+        NSRect(x: 0, y: 0.08, width: 0.08, height: 0.38),
+        NSRect(x: 0.08, y: 0.46, width: 0.39, height: 0.08)
+    ]
+
+    static func width(for text: String, height: CGFloat) -> CGFloat {
+        let characters = Array(text)
+        return height * (characters.reduce(CGFloat(0)) { $0 + glyphWidth($1) } + CGFloat(max(0, characters.count - 1)) * 0.1)
+    }
+
+    /// 坐标按顶部向下递增，与顶部统计卡片的翻转坐标保持一致。
+    static func draw(_ text: String, in rect: NSRect, color: NSColor) {
+        guard rect.width > 0, rect.height > 0, !text.isEmpty else { return }
+        let scaleX = min(1, rect.width / max(1, width(for: text, height: rect.height)))
+        let unitX = rect.height * scaleX
+        var x = rect.minX
+        for character in text {
+            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
+                for (index, segment) in segments.enumerated() {
+                    let target = NSRect(x: x + segment.minX * unitX, y: rect.minY + segment.minY * rect.height,
+                                        width: segment.width * unitX, height: segment.height * rect.height)
+                    let active = digitMasks[digit] & (1 << index) != 0
+                    (active ? color : color.withAlphaComponent(0.1)).setFill()
+                    beveledSegment(in: target, horizontal: index == 0 || index == 3 || index == 6).fill()
+                }
+            } else if character == "," || character == "." {
+                // 本地化分组符也采用小数码段，保留完整数量而不改成缩写。
+                color.setFill()
+                NSBezierPath(rect: NSRect(x: x + unitX * 0.04, y: rect.minY + rect.height * 0.88,
+                                          width: unitX * 0.08, height: rect.height * 0.08)).fill()
+                if character == "," {
+                    NSBezierPath(rect: NSRect(x: x + unitX * 0.02, y: rect.minY + rect.height * 0.96,
+                                              width: unitX * 0.04, height: rect.height * 0.04)).fill()
+                }
+            }
+            // 俄语等语言的空白分组符保留间距，不绘制额外内容。
+            x += unitX * (glyphWidth(character) + 0.1)
+        }
+    }
+
+    private static func glyphWidth(_ character: Character) -> CGFloat {
+        character.wholeNumberValue != nil ? 0.55 : 0.16
+    }
+
+    private static func beveledSegment(in rect: NSRect, horizontal: Bool) -> NSBezierPath {
+        let cap = horizontal ? min(rect.height / 2, rect.width / 2) : min(rect.width / 2, rect.height / 2)
+        let points: [NSPoint]
+        if horizontal {
+            points = [NSPoint(x: rect.minX, y: rect.midY), NSPoint(x: rect.minX + cap, y: rect.minY),
+                      NSPoint(x: rect.maxX - cap, y: rect.minY), NSPoint(x: rect.maxX, y: rect.midY),
+                      NSPoint(x: rect.maxX - cap, y: rect.maxY), NSPoint(x: rect.minX + cap, y: rect.maxY)]
+        } else {
+            points = [NSPoint(x: rect.midX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY + cap),
+                      NSPoint(x: rect.maxX, y: rect.maxY - cap), NSPoint(x: rect.midX, y: rect.maxY),
+                      NSPoint(x: rect.minX, y: rect.maxY - cap), NSPoint(x: rect.minX, y: rect.minY + cap)]
+        }
+        let path = NSBezierPath()
+        path.move(to: points[0])
+        points.dropFirst().forEach { path.line(to: $0) }
+        path.close()
+        return path
+    }
+}
```

### `Tests/AchievementPresentationTests.swift`

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -220,4 +220,45 @@
         }
     }
 
+
+    func testBannerOnlyBouncesTheTypeWhoseCountIncreased() {
+        var now: TimeInterval = 0
+        let banner = PixelBannerView(frame: NSRect(x: 0, y: 0, width: 672, height: 88), clock: { now })
+        banner.refresh(manager: manager)
+        now = 1
+        typedSwap([.orangeRicky: 3])
+        banner.refresh(manager: manager)
+        now = 1.21
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), -6, accuracy: 0.001)
+        XCTAssertEqual(banner.numberJumpOffset(for: .blueRicky), 0)
+        XCTAssertEqual(banner.numberJumpOffset(for: .clevelandZ), 0)
+        XCTAssertEqual(banner.numberJumpOffset(for: .rhodeIslandZ), 0)
+        now = 1.5
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), 0)
+        typedSwap([.blueRicky: 3])
+        banner.refresh(manager: manager)
+        now = 1.71
+        XCTAssertEqual(banner.numberJumpOffset(for: .blueRicky), -6, accuracy: 0.001)
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), 0)
+    }
+
+    func testBannerDoesNotBounceOnLoadOrRestartBounceOnSameValueRefresh() {
+        var now: TimeInterval = 0
+        typedSwap([.orangeRicky: 100])
+        let banner = PixelBannerView(frame: NSRect(x: 0, y: 0, width: 672, height: 88), clock: { now })
+        banner.refresh(manager: manager)
+        now = 0.21
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), 0)
+        now = 1
+        typedSwap([.orangeRicky: 1])
+        banner.refresh(manager: manager)
+        now = 1.21
+        let before = banner.numberJumpOffset(for: .orangeRicky)
+        banner.refresh(manager: manager)
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), before, accuracy: 0.001)
+        now = 1.5
+        banner.refresh(manager: manager)
+        XCTAssertEqual(banner.numberJumpOffset(for: .orangeRicky), 0)
+    }
+
 }
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261029224856-seven-segment-counts-and-bounce.md` - 会话-38 起将累计消除改为统一卡片标题，数量使用等高七段数码管、同步浮动与增长跳动；含完整增量 diff、真实渲染验收和 9 项界面回归结果。
 `workflow/20261029222742-piece-clear-counts-and-milestones.md` - 会话-33 起新增顶部四种方块累计消除数量及每类百/千/万三档里程碑，共新增 12 枚成就、总数 32；含完整逐行 diff、存档兼容说明和 38 项回归结果。
 `workflow/20261027231516-achievement-panel-game-theme.md` - 会话-26 起统一成就面板与主界面的深色像素主题：复用背景/卡片绘制，统一筛选、字体和像素进度条；含完整逐行 diff、真实渲染验收及 6 项界面回归结果。
 `workflow/20261027225436-achievement-panel-position.md` - 会话-21 起修复成就面板在屏幕边缘显示：先按主窗口定位再附加，每次打开重新居中并限制在当前屏幕可用区域；含完整增量 diff 和 6 项界面回归结果。
@@ -64,6 +65,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要调整顶部统计卡片标题、七段数字绘制、数字与方块同步浮动或消除增长跳动时，读取 `20261029224856-seven-segment-counts-and-bounce.md`。
 - 需要了解按方块类型计数、顶部数量显示、每类 100/1,000/10,000 成就及旧存档升级口径时，读取 `20261029222742-piece-clear-counts-and-milestones.md`。
 - 需要调整成就图鉴/详情的深色主题、像素边框、字体、筛选控件、分段进度条或了解共用绘制组件时，读取 `20261027231516-achievement-panel-game-theme.md`。
 - 成就面板首次打开位置异常、需要跟随主窗口定位或处理靠近屏幕边缘时，读取 `20261027225436-achievement-panel-position.md`。
@@ -128,6 +130,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 顶部统计卡片使用统一“累计消除”标题，七段数字按方块高度绘制，长数量只横向压缩；图案和数字共用浮动位置，只有数量增长时数字额外跳动，首次加载/同值刷新不触发。
 - 成就现为 32 枚，新增编号 21—32 对应橙/蓝/绿/红四类方块的百/千/万累计里程碑；原编号 1—20 保持不变。
 - 类型累计值跨局、跨模式及重启保存；旧存档没有类型明细时从 0 开始，保留既有总数和解锁状态，不推测历史分布。顶部横幅与类型成就读取同一数据源。
 - 成就面板现与主窗口复用 `ArcadeStageView` 扫描线背景与 `PixelFrameCardView` 像素卡片；面板使用深色外观、红色主题与等宽字体，已解锁项目采用浅绿色，原有窗口定位和筛选语义保持不变。
```
