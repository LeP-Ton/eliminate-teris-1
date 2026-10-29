# 方块类型累计消除数量与分档成就

## 背景与目标
- 对应会话：会话-33 起，用户要求在顶部每种俄罗斯方块旁统计显示已消除数量，并在累计里程碑中增加不同类型的百、千、万三档成就。
- 顶部橙/蓝/绿/红四种方块分别显示跨局累计数量；每种类型追加 100、1,000、10,000 三档，合计新增 12 枚成就，总数由 20 变为 32。
- 基线提交：`e4b1483838af70b4a91fc5ef3aa743dde25814be`；本轮开始时工作区干净。本文记录本轮全部代码、资源、测试、认知与索引的完整逐行 diff。

## 约束与统计口径
- 一个棋盘格中的完整方块形状计为 1 个，不按构成图案的四个像素小方格计数。
- 统计适用于自由、竞分、竞速全部模式；重开、切换模式、重新启动均不清零。
- 每轮真实消除先记录类型再补位，同一次交换中的自动连锁全部累计；未产生消除、无效操作与初始棋盘归一化不计数。
- 不改变原有玩法、每格 10 分、Touch Bar 动画/音效和已解锁记录。
- 原有 1—20 编号保持不变，类型里程碑只向后追加。

## 阶段与 TODO
- [x] 为 PieceKind 增加稳定字符串标识及本地化名称键。
- [x] 在交换结算数据中记录每种类型实际消除数量，合并各轮连锁。
- [x] 将分类数量接入现有事件去重、存档及进度查询。
- [x] 新增 12 枚类型里程碑，使用累计进度与现有解锁反馈。
- [x] 在顶部图案旁显示各自的累计数量，保持 88 点高横幅与现有颜色/动画。
- [x] 补齐中、英、日、韩、俄五语言文案与辅助功能说明。
- [x] 完成 38 项回归、真实横幅渲染验收及差异检查。
- [x] 更新根索引、核心认知与完整变更记录。

## 新增成就

| 类型 | 100 个 | 1,000 个 | 10,000 个 |
| --- | --- | --- | --- |
| 橙色方块 | 21 橙色百格 | 22 橙色千格 | 23 橙色万格 |
| 蓝色方块 | 24 蓝色百格 | 25 蓝色千格 | 26 蓝色万格 |
| 绿色方块 | 27 绿色百格 | 28 绿色千格 | 29 绿色万格 |
| 红色方块 | 30 红色百格 | 31 红色千格 | 32 红色万格 |

## 实现与接口
- `SwapResolution.clearedByKind` 提供每种方块的消除数量；默认空字典保留现有构造方式，真实 GameState 结算始终填充明细。
- `PieceKind` 的 rawValue 为稳定存档标识，不依赖枚举顺序、颜色名称或界面语言。
- `AchievementsManager.totalCleared(for:)` 查询类型累计值；新条件为 `pieceCleared(kind:count:)`，读取与横幅完全相同的数据。
- 分类值使用既有 v1 存档中的追加指标 `pieceCleared.<类型标识>`，沿用保存、通知及交换 UUID 去重链路。
- 横幅通过既有成就状态变更通知与语言切换刷新；数量使用本地数字分组，长数字自动收缩字号，完整数量同时提供给辅助功能。
- 累计里程碑分类由 4 枚扩展为 16 枚；成就栏仍默认完整显示五枚，筛选及面板行为保持一致。

## 兼容与限制
- 旧存档只记录全类型总数，无法可靠拆解为四种类型，因此新分类值从升级后开始统计，缺失值按 0 读取。
- 既有累计总数、成就状态与解锁日期全部保留；旧总数可能大于四类新计数之和，这是正常升级结果。
- 不按分数、历史排行榜或开发 seed 推算类型分布，不补发无法证实的分类成就。

## 测试用例与结果

### TC-001 分类消除与连锁准确
- 类型：规则测试；优先级：高；模块：GameState。
- 前置条件：注入固定初始棋盘及补位序列。
- 操作步骤：分别触发单组三连、同轮双类型三连、补位长连与三轮混合类型连锁，并检查无消除交换。
- 预期结果：类型明细准确，例如三轮链为橙 3、蓝 4、绿 3，总量 10；无消除明细为空。
- 是否通过：通过，增强既有 5 项规则测试。

### TC-002 每类三档边界与独立性
- 类型：成就状态测试；优先级：高；模块：AchievementsManager。
- 操作步骤：对四种类型依次达到 99/100、999/1,000、9,999/10,000；混合两类各 50；重复提交同一交换；单次跨越所有三档。
- 预期结果：仅相应类型达到门槛时解锁；不串类型、不重复累计；跨越三档时按编号全部解锁。
- 是否通过：通过。

### TC-003 旧存档兼容与持久化
- 类型：存档测试；优先级：高。
- 前置条件：构造包含原有总数、解锁记录与日期、缺少类型指标的 v1 存档。
- 操作步骤：加载、按类型消除、切换新局、再次创建管理器读取存档。
- 预期结果：原有记录保留，分类起始值为 0，新分类数量与解锁状态跨局及重新加载后保持。
- 是否通过：通过。

### TC-004 控制器真实事件集成
- 类型：集成测试；优先级：高；模块：GameBoardController。
- 操作步骤：使用固定棋盘执行一次产生三轮连锁的交换，读取快照及计时器多次。
- 预期结果：交换与结算顺序正常，类型计数恰好为橙 3、蓝 4、绿 3、红 0，重复刷新不增加数量。
- 是否通过：通过，增强既有控制器用例。

### TC-005 五语言与横幅视觉
- 类型：原生界面/本地化测试；优先级：高。
- 操作步骤：给四种类型设置不同累计值，重新加载存档；遍历五种语言绘制横幅，检查辅助功能中的完整类型和数量；渲染中文 PNG 并实际查看。
- 预期结果：图案旁展示正确的本地分组数量；最大示例 1,234,567,890 正常收缩字号且不越界；32 枚成就文案完整，筛选数量及五枚标签布局正常。
- 是否通过：通过，已实际查看横幅预览。

## 当前进展与验证
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`：38 项测试，0 失败；应用编译与链接正常。
- 分类新增测试：4 项成就/存档用例、1 项横幅用例；同时增强已有规则、控制器与资源检查。
- `git diff --check`：通过。
- 临时预览：测试输出的 `eliminate-piece-counts-banner.png`，使用隔离测试存档，不读取或修改玩家真实数据。
- 本轮未重启用户当前游戏进程，重启后可查看分类统计与新增成就。

## 代码变更

以下为本轮全部变更的完整逐行 diff。

### `Sources/GameState.swift`

```diff
diff --git a/Sources/GameState.swift b/Sources/GameState.swift
--- a/Sources/GameState.swift
+++ b/Sources/GameState.swift
@@ -6,6 +6,16 @@
     let clearedCount: Int
     let cascadeCount: Int
     let longestRun: Int
+    let clearedByKind: [PieceKind: Int]
+
+    init(isValidSwap: Bool, clearedCount: Int, cascadeCount: Int, longestRun: Int,
+         clearedByKind: [PieceKind: Int] = [:]) {
+        self.isValidSwap = isValidSwap
+        self.clearedCount = clearedCount
+        self.cascadeCount = cascadeCount
+        self.longestRun = longestRun
+        self.clearedByKind = clearedByKind
+    }
 
     static let invalid = SwapResolution(isValidSwap: false, clearedCount: 0, cascadeCount: 0, longestRun: 0)
 }
@@ -77,6 +87,7 @@
         var clearedCount = 0
         var cascadeCount = 0
         var longestRun = 0
+        var clearedByKind: [PieceKind: Int] = [:]
         while true {
             let (matches, runLength) = matchDetails()
             if matches.isEmpty {
@@ -87,9 +98,12 @@
             clearedCount += matches.count
             cascadeCount += 1
             longestRun = max(longestRun, runLength)
+            // 补位前读取实际消除方块的类型，将每轮连锁合并到本次交换。
+            for index in matches { clearedByKind[tiles[index].kind, default: 0] += 1 }
             refillAfterClearing(matches)
         }
-        return SwapResolution(isValidSwap: true, clearedCount: clearedCount, cascadeCount: cascadeCount, longestRun: longestRun)
+        return SwapResolution(isValidSwap: true, clearedCount: clearedCount, cascadeCount: cascadeCount,
+                              longestRun: longestRun, clearedByKind: clearedByKind)
     }
 
     private func findMatches() -> Set<Int> {
```

### `Sources/Piece.swift`

```diff
diff --git a/Sources/Piece.swift b/Sources/Piece.swift
--- a/Sources/Piece.swift
+++ b/Sources/Piece.swift
@@ -5,11 +5,14 @@
     let y: Int
 }
 
-enum PieceKind: CaseIterable {
-    case orangeRicky
-    case blueRicky
-    case clevelandZ
-    case rhodeIslandZ
+enum PieceKind: String, CaseIterable, Hashable {
+    // 稳定标识用于累计统计存档，不依赖枚举顺序或界面语言。
+    case orangeRicky = "orange_ricky"
+    case blueRicky = "blue_ricky"
+    case clevelandZ = "cleveland_z"
+    case rhodeIslandZ = "rhode_island_z"
+
+    var titleKey: String { "piece.\(rawValue).name" }
 
     static func random() -> PieceKind {
         return PieceKind.allCases.randomElement() ?? .orangeRicky
```

### `Sources/AchievementsManager.swift`

```diff
diff --git a/Sources/AchievementsManager.swift b/Sources/AchievementsManager.swift
--- a/Sources/AchievementsManager.swift
+++ b/Sources/AchievementsManager.swift
@@ -11,6 +11,7 @@
     case scoreAttack(minutes: Int, score: Int)
     case speedRun(target: Int, limit: TimeInterval?)
     case totalCleared(Int)
+    case pieceCleared(kind: PieceKind, count: Int)
 }
 
 struct AchievementDefinition {
@@ -41,7 +42,20 @@
         .init(id: 17, category: .lifetime, goal: .totalCleared(100)),
         .init(id: 18, category: .lifetime, goal: .totalCleared(1_000)),
         .init(id: 19, category: .lifetime, goal: .totalCleared(10_000)),
-        .init(id: 20, category: .lifetime, goal: .completedRounds(20))
+        .init(id: 20, category: .lifetime, goal: .completedRounds(20)),
+        // 按稳定编号追加，旧成就及其解锁时间不变。
+        .init(id: 21, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 100)),
+        .init(id: 22, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 1_000)),
+        .init(id: 23, category: .lifetime, goal: .pieceCleared(kind: .orangeRicky, count: 10_000)),
+        .init(id: 24, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 100)),
+        .init(id: 25, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 1_000)),
+        .init(id: 26, category: .lifetime, goal: .pieceCleared(kind: .blueRicky, count: 10_000)),
+        .init(id: 27, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 100)),
+        .init(id: 28, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 1_000)),
+        .init(id: 29, category: .lifetime, goal: .pieceCleared(kind: .clevelandZ, count: 10_000)),
+        .init(id: 30, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 100)),
+        .init(id: 31, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 1_000)),
+        .init(id: 32, category: .lifetime, goal: .pieceCleared(kind: .rhodeIslandZ, count: 10_000))
     ]
 }
 
@@ -85,6 +99,11 @@
     func unlockedIDs() -> [Int] { unlocked.sorted() }
     func unlockDate(id: Int) -> Date? { timestamps[String(id)].map(Date.init(timeIntervalSince1970:)) }
 
+    /// 分类计数与原有累计值共用存档；旧数据缺少分类明细时返回 0，不推测历史分布。
+    func totalCleared(for kind: PieceKind) -> Double {
+        metrics["pieceCleared.\(kind.rawValue)", default: 0]
+    }
+
     func beginRound(id: UUID) {
         guard roundID != id else { return }
         roundID = id
@@ -106,6 +125,9 @@
             successfulSwaps += 1
             lastClearDate = date
             metrics["totalCleared", default: 0] += Double(result.clearedCount)
+            for (kind, count) in result.clearedByKind where count > 0 {
+                metrics["pieceCleared.\(kind.rawValue)", default: 0] += Double(count)
+            }
             updateBest("rhythm", Double(rhythm))
             updateBest("successfulSwaps", Double(successfulSwaps))
         } else {
@@ -160,6 +182,7 @@
             }
             return value("speedRunCompleted.\(target)", 1)
         case .totalCleared(let target): return value("totalCleared", Double(target))
+        case .pieceCleared(let kind, let count): return value("pieceCleared.\(kind.rawValue)", Double(count))
         }
     }
 
```

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -638,6 +638,7 @@
 
     private func refreshAchievements() {
         let manager = AchievementsManager.shared
+        pixelBannerView.refresh(manager: manager)
         achievementsTitleLabel.stringValue = localizedFormat("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
         // 自绘深色背景下显式指定文字颜色，避免 inline 按钮回退成黑色文字。
         achievementsAllButton.attributedTitle = NSAttributedString(
@@ -2519,9 +2520,28 @@
     }
 }
 
-private final class PixelBannerView: NSView {
+final class PixelBannerView: NSView {
     private var animationTick: CGFloat = 0
     private var animationTimer: Timer?
+    private var countTexts: [PieceKind: String] = [:]
+
+    /// 与成就共用累计数据源，语言切换时同步更新数字格式及辅助功能说明。
+    func refresh(manager: AchievementsManager) {
+        let formatter = NumberFormatter()
+        formatter.locale = Localizer.shared.locale
+        formatter.numberStyle = .decimal
+        formatter.maximumFractionDigits = 0
+        var descriptions: [String] = []
+        for kind in PieceKind.allCases {
+            let text = formatter.string(from: NSNumber(value: manager.totalCleared(for: kind))) ?? "0"
+            countTexts[kind] = text
+            descriptions.append(AchievementText.format("banner.piece_cleared", AchievementText.string(kind.titleKey), text))
+        }
+        setAccessibilityElement(true)
+        setAccessibilityRole(.group)
+        setAccessibilityLabel(descriptions.joined(separator: "；"))
+        needsDisplay = true
+    }
 
     override var isFlipped: Bool {
         return true
@@ -2621,7 +2641,20 @@
 
             let slotX = rect.minX + CGFloat(index) * slotWidth
             let wave = CGFloat(sin(Double(animationTick) * 0.12 + Double(index) * 0.7)) * 2.2
-            let originX = slotX + (slotWidth - pieceWidth) * 0.5
+            let count = countTexts[kind] ?? "0"
+            let caption = AchievementText.string("banner.total_cleared")
+            let maximumTextWidth = max(1, slotWidth - pieceWidth - 26)
+            var fontSize: CGFloat = 14
+            var countFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
+            // 数量增加时适度收缩数字字号，避免与相邻类型重叠。
+            while (count as NSString).size(withAttributes: [.font: countFont]).width > maximumTextWidth, fontSize > 9 {
+                fontSize -= 1
+                countFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
+            }
+            let captionFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
+            let textWidth = min(maximumTextWidth, max((count as NSString).size(withAttributes: [.font: countFont]).width,
+                                                    (caption as NSString).size(withAttributes: [.font: captionFont]).width))
+            let originX = slotX + (slotWidth - pieceWidth - 10 - textWidth) * 0.5
             let originY = rect.minY + (rect.height - pieceHeight) * 0.5 + wave
             let glowPulse = CGFloat((sin(Double(animationTick) * 0.14 + Double(index)) + 1) * 0.5)
 
@@ -2634,6 +2667,15 @@
                 blockSize: baseBlockSize,
                 pulse: glowPulse
             )
+            let textX = originX + pieceWidth + 10
+            let textY = rect.midY - 17
+            let paragraph = NSMutableParagraphStyle()
+            paragraph.lineBreakMode = .byTruncatingTail
+            let color = kind.color.blended(withFraction: 0.4, of: .white) ?? kind.color
+            (caption as NSString).draw(in: NSRect(x: textX, y: textY, width: textWidth, height: 12),
+                                      withAttributes: [.font: captionFont, .foregroundColor: color.withAlphaComponent(0.8), .paragraphStyle: paragraph])
+            (count as NSString).draw(in: NSRect(x: textX, y: textY + 14, width: textWidth, height: 21),
+                                    withAttributes: [.font: countFont, .foregroundColor: color, .paragraphStyle: paragraph])
         }
     }
 
```

### `Sources/AchievementViews.swift`

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
--- a/Sources/AchievementViews.swift
+++ b/Sources/AchievementViews.swift
@@ -33,7 +33,7 @@
             let target = formatter.string(from: NSNumber(value: progress.target)) ?? "0"
             let key: String
             switch definition.goal {
-            case .totalCleared, .completedRounds: key = "achievement.progress.total"
+            case .totalCleared, .completedRounds, .pieceCleared: key = "achievement.progress.total"
             default: key = "achievement.progress.best"
             }
             return format(key, current, target)
```

### `Tests/GameStateTests.swift`

```diff
diff --git a/Tests/GameStateTests.swift b/Tests/GameStateTests.swift
--- a/Tests/GameStateTests.swift
+++ b/Tests/GameStateTests.swift
@@ -19,7 +19,7 @@
     func testSingleTripleAndScore() {
         let game = state([a, a, b, a], refill: [c, d, c])
         XCTAssertTrue(game.swapAndResolve(2, 3))
-        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 3, cascadeCount: 1, longestRun: 3))
+        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 3, cascadeCount: 1, longestRun: 3, clearedByKind: [a: 3]))
         XCTAssertEqual(game.score, 30)
         XCTAssertEqual(game.tiles.map(\.kind), [c, d, c, b])
     }
@@ -28,6 +28,7 @@
         let game = state([b, b, a, b, a, a, c, d], refill: [a, b, c, d, a, b])
         XCTAssertTrue(game.swapAndResolve(2, 3))
         XCTAssertEqual(game.lastResolution.clearedCount, 6)
+        XCTAssertEqual(game.lastResolution.clearedByKind, [a: 3, b: 3])
         XCTAssertEqual(game.lastResolution.cascadeCount, 1)
         XCTAssertEqual(game.lastResolution.longestRun, 3)
     }
@@ -36,6 +37,7 @@
         let game = state([c, c, a, a, b, a], refill: [c, c, c, a, b, c, d, a])
         XCTAssertTrue(game.swapAndResolve(4, 5))
         XCTAssertEqual(game.lastResolution.clearedCount, 8)
+        XCTAssertEqual(game.lastResolution.clearedByKind, [a: 3, c: 5])
         XCTAssertEqual(game.lastResolution.cascadeCount, 2)
         XCTAssertEqual(game.lastResolution.longestRun, 5)
         XCTAssertEqual(game.score, 80)
@@ -44,7 +46,7 @@
     func testThreeCascadesIncludeTheInitialWave() {
         let game = state([a, a, b, a], refill: [b, b, b, c, c, c, d, a, b, a])
         XCTAssertTrue(game.swapAndResolve(2, 3))
-        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 10, cascadeCount: 3, longestRun: 4))
+        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 10, cascadeCount: 3, longestRun: 4, clearedByKind: [a: 3, b: 4, c: 3]))
         XCTAssertEqual(game.score, 100)
     }
 
@@ -52,6 +54,7 @@
         let game = state([a, b, c, d], refill: [a])
         XCTAssertFalse(game.swapAndResolve(0, 1))
         XCTAssertTrue(game.lastResolution.isValidSwap)
+        XCTAssertTrue(game.lastResolution.clearedByKind.isEmpty)
         XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
         XCTAssertFalse(game.attemptSwap(0, 1))
         XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
```

### `Tests/AchievementsTests.swift`

```diff
diff --git a/Tests/AchievementsTests.swift b/Tests/AchievementsTests.swift
--- a/Tests/AchievementsTests.swift
+++ b/Tests/AchievementsTests.swift
@@ -35,6 +35,14 @@
                            score: score, at: date.addingTimeInterval(seconds))
     }
 
+    func typedSwap(_ counts: [PieceKind: Int], id: UUID = UUID()) {
+        let total = counts.values.reduce(0, +)
+        manager.recordSwap(roundID: round, swapID: id,
+                           result: SwapResolution(isValidSwap: true, clearedCount: total, cascadeCount: 1,
+                                                  longestRun: 3, clearedByKind: counts),
+                           score: total * 10, at: date)
+    }
+
     func newRound() {
         round = UUID()
         manager.beginRound(id: round)
@@ -43,8 +51,8 @@
 
 final class AchievementsTests: AchievementTestCase {
     func testAllDefinitionsHaveStableIDs() {
-        XCTAssertEqual(AchievementDefinition.all.map(\.id), Array(1...20))
-        XCTAssertEqual(AchievementCategory.allCases.map { c in AchievementDefinition.all.filter { $0.category == c }.count }, [4, 5, 7, 4])
+        XCTAssertEqual(AchievementDefinition.all.map(\.id), Array(1...32))
+        XCTAssertEqual(AchievementCategory.allCases.map { c in AchievementDefinition.all.filter { $0.category == c }.count }, [4, 5, 7, 16])
     }
 
     func testOneSwapUnlocksEveryReachedMilestoneAndPersistsBeforeNotification() {
@@ -222,4 +230,69 @@
         XCTAssertTrue(manager.hasTimedResult(for: definition))
         XCTAssertEqual(manager.progress(for: definition).current, 0)
     }
+
+    func testEveryPieceKindUnlocksItsOwnHundredThousandAndTenThousandMilestones() {
+        for (index, kind) in PieceKind.allCases.enumerated() {
+            newRound()
+            let firstID = 21 + index * 3
+            for (tier, threshold) in [100, 1_000, 10_000].enumerated() {
+                let previous = Int(manager.totalCleared(for: kind))
+                typedSwap([kind: threshold - previous - 1])
+                XCTAssertEqual(progress(firstID + tier), Double(threshold - 1))
+                XCTAssertFalse(manager.isUnlocked(id: firstID + tier))
+                typedSwap([kind: 1])
+                XCTAssertTrue(manager.isUnlocked(id: firstID + tier))
+            }
+            XCTAssertEqual(manager.totalCleared(for: kind), 10_000)
+        }
+        XCTAssertTrue((21...32).allSatisfy { manager.isUnlocked(id: $0) })
+        XCTAssertEqual(progress(19), 40_000)
+    }
+
+    func testTypedClearsDoNotBleedAcrossKindsOrCountDuplicateEvents() {
+        let id = UUID()
+        typedSwap([.orangeRicky: 50, .blueRicky: 50], id: id)
+        typedSwap([.orangeRicky: 50, .blueRicky: 50], id: id)
+        XCTAssertEqual(progress(17), 100)
+        XCTAssertFalse(manager.isUnlocked(id: 21))
+        XCTAssertFalse(manager.isUnlocked(id: 24))
+        typedSwap([.orangeRicky: 50])
+        XCTAssertTrue(manager.isUnlocked(id: 21))
+        XCTAssertFalse(manager.isUnlocked(id: 24))
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 100)
+        XCTAssertEqual(manager.totalCleared(for: .blueRicky), 50)
+        XCTAssertEqual(manager.totalCleared(for: .clevelandZ), 0)
+        XCTAssertEqual(manager.totalCleared(for: .rhodeIslandZ), 0)
+    }
+
+    func testOneTypedEventCanUnlockAllThreeTiersTogether() {
+        var newIDs: [Int] = []
+        let observer = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: manager, queue: nil) { note in
+            newIDs += (note.userInfo?["ids"] as? [Int] ?? []).filter { $0 >= 21 }
+        }
+        defer { NotificationCenter.default.removeObserver(observer) }
+        typedSwap([.rhodeIslandZ: 10_000])
+        XCTAssertEqual(newIDs, [30, 31, 32])
+    }
+
+    func testExistingSaveKeepsTotalsAndNewTypedCountsPersistAcrossRoundsAndReloads() {
+        defaults.set(["version": 1, "unlocked": [1, 17], "timestamps": ["1": date.timeIntervalSince1970],
+                      "metrics": ["totalCleared": 1_234]], forKey: AchievementsManager.storageKey)
+        manager = AchievementsManager(defaults: defaults)
+        manager.beginRound(id: round)
+        XCTAssertEqual(progress(17), 1_234)
+        XCTAssertEqual(manager.unlockDate(id: 1), date)
+        XCTAssertTrue(PieceKind.allCases.allSatisfy { manager.totalCleared(for: $0) == 0 })
+        typedSwap([.orangeRicky: 100])
+        newRound()
+        typedSwap([.blueRicky: 1])
+        manager = AchievementsManager(defaults: defaults)
+        XCTAssertEqual(manager.totalCleared(for: .orangeRicky), 100)
+        XCTAssertEqual(manager.totalCleared(for: .blueRicky), 1)
+        XCTAssertEqual(progress(17), 1_335)
+        XCTAssertTrue(manager.isUnlocked(id: 21))
+        XCTAssertTrue(manager.isUnlocked(id: 17))
+        XCTAssertEqual(manager.unlockDate(id: 1), date)
+    }
+
 }
```

### `Tests/GameBoardControllerTests.swift`

```diff
diff --git a/Tests/GameBoardControllerTests.swift b/Tests/GameBoardControllerTests.swift
--- a/Tests/GameBoardControllerTests.swift
+++ b/Tests/GameBoardControllerTests.swift
@@ -24,6 +24,10 @@
         for _ in 0..<10 { _ = controller.snapshot(); controller.tick() }
         XCTAssertEqual(progress(20), 1)
         XCTAssertEqual(progress(17), 10)
+        XCTAssertEqual(manager.totalCleared(for: a), 3)
+        XCTAssertEqual(manager.totalCleared(for: b), 4)
+        XCTAssertEqual(manager.totalCleared(for: c), 3)
+        XCTAssertEqual(manager.totalCleared(for: d), 0)
         controller.performSwap(from: 0, to: 1)
         XCTAssertEqual(progress(17), 10)
     }
```

### `Tests/AchievementPresentationTests.swift`

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
--- a/Tests/AchievementPresentationTests.swift
+++ b/Tests/AchievementPresentationTests.swift
@@ -20,7 +20,7 @@
         let content = try XCTUnwrap(window.contentView)
         let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
         func progressBars() -> Int { descendants(content).filter { $0 is NSProgressIndicator }.count }
-        XCTAssertEqual(progressBars(), 20)
+        XCTAssertEqual(progressBars(), AchievementDefinition.all.count)
         content.layoutSubtreeIfNeeded()
         // 使用真实鼠标事件验证主题控件的点击区域，而非直接修改选择状态。
         func clickFilter(at fraction: CGFloat) throws {
@@ -34,7 +34,7 @@
         XCTAssertEqual(progressBars(), 1)
         try clickFilter(at: 0.5)
         XCTAssertEqual(filter.selectedSegment, 1)
-        XCTAssertEqual(progressBars(), 19)
+        XCTAssertEqual(progressBars(), AchievementDefinition.all.count - 1)
     }
 
     func testLibraryRowsHaveUsableLayoutForEveryLanguage() throws {
@@ -188,4 +188,36 @@
         XCTAssertFalse(window.canBecomeKey)
     }
 
+
+    func testBannerRendersPersistedCountsBesideEveryPieceInAllLanguages() throws {
+        _ = NSApplication.shared
+        typedSwap([.orangeRicky: 100, .blueRicky: 1_000, .clevelandZ: 10_000, .rhodeIslandZ: 1_234_567_890])
+        let reloaded = AchievementsManager(defaults: defaults)
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let banner = PixelBannerView(frame: NSRect(x: 0, y: 0, width: 672, height: 88))
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            banner.refresh(manager: reloaded)
+            let description = try XCTUnwrap(banner.accessibilityLabel())
+            let formatter = NumberFormatter()
+            formatter.locale = Localizer.shared.locale
+            formatter.numberStyle = .decimal
+            formatter.maximumFractionDigits = 0
+            for kind in PieceKind.allCases {
+                XCTAssertTrue(description.contains(Localizer.shared.string(kind.titleKey)))
+                let count = try XCTUnwrap(formatter.string(from: NSNumber(value: reloaded.totalCleared(for: kind))))
+                XCTAssertTrue(description.contains(count))
+            }
+            let bitmap = try XCTUnwrap(banner.bitmapImageRepForCachingDisplay(in: banner.bounds))
+            banner.cacheDisplay(in: banner.bounds, to: bitmap)
+            if language == .chineseSimplified {
+                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
+                let preview = FileManager.default.temporaryDirectory.appendingPathComponent("eliminate-piece-counts-banner.png")
+                try png.write(to: preview)
+                print("方块累计数量预览：\(preview.path)")
+            }
+        }
+    }
+
 }
```

### `Tests/AchievementLocalizationTests.swift`

```diff
diff --git a/Tests/AchievementLocalizationTests.swift b/Tests/AchievementLocalizationTests.swift
--- a/Tests/AchievementLocalizationTests.swift
+++ b/Tests/AchievementLocalizationTests.swift
@@ -11,13 +11,16 @@
             let data = try Data(contentsOf: url)
             let table = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
             tables[language.rawValue] = table
+            for kind in PieceKind.allCases { XCTAssertNotNil(table[kind.titleKey]) }
+            XCTAssertNotNil(table["banner.total_cleared"])
+            XCTAssertNotNil(table["banner.piece_cleared"])
             for definition in AchievementDefinition.all {
                 XCTAssertNotNil(table[definition.titleKey], "\(language.rawValue): \(definition.titleKey)")
                 XCTAssertNotNil(table[definition.descriptionKey])
             }
         }
         let english = try XCTUnwrap(tables["en"])
-        let keys = english.keys.filter { $0.hasPrefix("achievement.") }
+        let keys = english.keys.filter { $0.hasPrefix("achievement.") || $0.hasPrefix("banner.") || $0.hasPrefix("piece.") }
         for table in tables.values {
             for key in keys {
                 let value = try XCTUnwrap(table[key], key)
```

### `AGENTS.md`

```diff
diff --git a/AGENTS.md b/AGENTS.md
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -4,6 +4,9 @@
 - 项目为 macOS 12+ 原生 AppKit/Cocoa 游戏，使用 Swift 5.7+ 与 Swift Package Manager；桌面窗口负责设置和信息展示，16 格 Touch Bar 承载核心操作。
 - 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
 - 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
+
+## 2026-10-29
+- 消除结算事件包含按 `PieceKind` 稳定标识分类的明细，先记录被消除的实际类型再补位；顶部统计与类型成就共用同一累计存档数据源，按类型统计不依赖分数或界面动画反推。
 
 ## 2026-10-27
 - 主窗口与成就面板共享 `ArcadeStageView` 背景和 `PixelFrameCardView` 卡片绘制组件；跨窗口界面沿用固定深色外观、等宽字体及模块主题色，保持视觉一致。
```

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261029222742-piece-clear-counts-and-milestones.md` - 会话-33 起新增顶部四种方块累计消除数量及每类百/千/万三档里程碑，共新增 12 枚成就、总数 32；含完整逐行 diff、存档兼容说明和 38 项回归结果。
 `workflow/20261027231516-achievement-panel-game-theme.md` - 会话-26 起统一成就面板与主界面的深色像素主题：复用背景/卡片绘制，统一筛选、字体和像素进度条；含完整逐行 diff、真实渲染验收及 6 项界面回归结果。
 `workflow/20261027225436-achievement-panel-position.md` - 会话-21 起修复成就面板在屏幕边缘显示：先按主窗口定位再附加，每次打开重新居中并限制在当前屏幕可用区域；含完整增量 diff 和 6 项界面回归结果。
 `workflow/20261027224658-achievement-badge-layout.md` - 会话-16 起修复成就标签遮挡、图文居中与标签过宽；默认完整显示 5 枚，含本轮增量 diff 及 4 项界面回归测试结果。
@@ -63,6 +64,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要了解按方块类型计数、顶部数量显示、每类 100/1,000/10,000 成就及旧存档升级口径时，读取 `20261029222742-piece-clear-counts-and-milestones.md`。
 - 需要调整成就图鉴/详情的深色主题、像素边框、字体、筛选控件、分段进度条或了解共用绘制组件时，读取 `20261027231516-achievement-panel-game-theme.md`。
 - 成就面板首次打开位置异常、需要跟随主窗口定位或处理靠近屏幕边缘时，读取 `20261027225436-achievement-panel-position.md`。
 - 需要调整成就徽章栏高度、默认五枚布局、图文居中、滚动条兼容或长名称展示时，读取 `20261027224658-achievement-badge-layout.md`。
@@ -126,6 +128,8 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就现为 32 枚，新增编号 21—32 对应橙/蓝/绿/红四类方块的百/千/万累计里程碑；原编号 1—20 保持不变。
+- 类型累计值跨局、跨模式及重启保存；旧存档没有类型明细时从 0 开始，保留既有总数和解锁状态，不推测历史分布。顶部横幅与类型成就读取同一数据源。
 - 成就面板现与主窗口复用 `ArcadeStageView` 扫描线背景与 `PixelFrameCardView` 像素卡片；面板使用深色外观、红色主题与等宽字体，已解锁项目采用浅绿色，原有窗口定位和筛选语义保持不变。
 - 成就面板需在 `addChildWindow` 之前完成定位，因为附加子窗口会使其可见；每次打开以主窗口 frame 为中心，并限制在主窗口所在屏幕的 visibleFrame 内，四边预留 8 点。
 - 成就卡片高度由标题、内边距与 64 点高的标签区域决定，不再与顶部横幅等高；标签按实际可视宽度适配五枚，图标与文字整体居中，长名称截断后可通过悬浮提示或详情查看。
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -145,3 +145,35 @@
 "achievement.accessibility.locked" = "%@，未解锁";
 "achievement.accessibility.unlocked" = "%@，已解锁";
 "achievement.progress.legacy" = "旧版已解锁，历史进度未记录";
+
+// 按方块类型记录累计消除数量及百、千、万三档里程碑。
+"banner.total_cleared" = "累计消除";
+"banner.piece_cleared" = "%@：累计消除 %@";
+"piece.orange_ricky.name" = "橙色方块";
+"achievement.21.title" = "橙色百格";
+"achievement.21.desc" = "全部模式累计消除 100 个橙色方块。";
+"achievement.22.title" = "橙色千格";
+"achievement.22.desc" = "全部模式累计消除 1,000 个橙色方块。";
+"achievement.23.title" = "橙色万格";
+"achievement.23.desc" = "全部模式累计消除 10,000 个橙色方块。";
+"piece.blue_ricky.name" = "蓝色方块";
+"achievement.24.title" = "蓝色百格";
+"achievement.24.desc" = "全部模式累计消除 100 个蓝色方块。";
+"achievement.25.title" = "蓝色千格";
+"achievement.25.desc" = "全部模式累计消除 1,000 个蓝色方块。";
+"achievement.26.title" = "蓝色万格";
+"achievement.26.desc" = "全部模式累计消除 10,000 个蓝色方块。";
+"piece.cleveland_z.name" = "绿色方块";
+"achievement.27.title" = "绿色百格";
+"achievement.27.desc" = "全部模式累计消除 100 个绿色方块。";
+"achievement.28.title" = "绿色千格";
+"achievement.28.desc" = "全部模式累计消除 1,000 个绿色方块。";
+"achievement.29.title" = "绿色万格";
+"achievement.29.desc" = "全部模式累计消除 10,000 个绿色方块。";
+"piece.rhode_island_z.name" = "红色方块";
+"achievement.30.title" = "红色百格";
+"achievement.30.desc" = "全部模式累计消除 100 个红色方块。";
+"achievement.31.title" = "红色千格";
+"achievement.31.desc" = "全部模式累计消除 1,000 个红色方块。";
+"achievement.32.title" = "红色万格";
+"achievement.32.desc" = "全部模式累计消除 10,000 个红色方块。";
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -145,3 +145,35 @@
 "achievement.accessibility.locked" = "%@, locked";
 "achievement.accessibility.unlocked" = "%@, unlocked";
 "achievement.progress.legacy" = "Unlocked in an earlier version; past progress was not recorded";
+
+// 按方块类型记录累计消除数量及百、千、万三档里程碑。
+"banner.total_cleared" = "Total cleared";
+"banner.piece_cleared" = "%@: total cleared %@";
+"piece.orange_ricky.name" = "Orange tiles";
+"achievement.21.title" = "Orange · 100";
+"achievement.21.desc" = "Clear 100 orange tiles across all modes.";
+"achievement.22.title" = "Orange · 1,000";
+"achievement.22.desc" = "Clear 1,000 orange tiles across all modes.";
+"achievement.23.title" = "Orange · 10,000";
+"achievement.23.desc" = "Clear 10,000 orange tiles across all modes.";
+"piece.blue_ricky.name" = "Blue tiles";
+"achievement.24.title" = "Blue · 100";
+"achievement.24.desc" = "Clear 100 blue tiles across all modes.";
+"achievement.25.title" = "Blue · 1,000";
+"achievement.25.desc" = "Clear 1,000 blue tiles across all modes.";
+"achievement.26.title" = "Blue · 10,000";
+"achievement.26.desc" = "Clear 10,000 blue tiles across all modes.";
+"piece.cleveland_z.name" = "Green tiles";
+"achievement.27.title" = "Green · 100";
+"achievement.27.desc" = "Clear 100 green tiles across all modes.";
+"achievement.28.title" = "Green · 1,000";
+"achievement.28.desc" = "Clear 1,000 green tiles across all modes.";
+"achievement.29.title" = "Green · 10,000";
+"achievement.29.desc" = "Clear 10,000 green tiles across all modes.";
+"piece.rhode_island_z.name" = "Red tiles";
+"achievement.30.title" = "Red · 100";
+"achievement.30.desc" = "Clear 100 red tiles across all modes.";
+"achievement.31.title" = "Red · 1,000";
+"achievement.31.desc" = "Clear 1,000 red tiles across all modes.";
+"achievement.32.title" = "Red · 10,000";
+"achievement.32.desc" = "Clear 10,000 red tiles across all modes.";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -138,3 +138,35 @@
 "achievement.accessibility.locked" = "%@、未達成";
 "achievement.accessibility.unlocked" = "%@、達成済み";
 "achievement.progress.legacy" = "旧バージョンで達成済み。過去の進捗記録はありません";
+
+// 按方块类型记录累计消除数量及百、千、万三档里程碑。
+"banner.total_cleared" = "累計消去";
+"banner.piece_cleared" = "%@：累計消去 %@";
+"piece.orange_ricky.name" = "オレンジ色のブロック";
+"achievement.21.title" = "オレンジ色・100個";
+"achievement.21.desc" = "すべてのモードで、オレンジ色のブロックを合計 100 個消す。";
+"achievement.22.title" = "オレンジ色・1,000個";
+"achievement.22.desc" = "すべてのモードで、オレンジ色のブロックを合計 1,000 個消す。";
+"achievement.23.title" = "オレンジ色・10,000個";
+"achievement.23.desc" = "すべてのモードで、オレンジ色のブロックを合計 10,000 個消す。";
+"piece.blue_ricky.name" = "青色のブロック";
+"achievement.24.title" = "青色・100個";
+"achievement.24.desc" = "すべてのモードで、青色のブロックを合計 100 個消す。";
+"achievement.25.title" = "青色・1,000個";
+"achievement.25.desc" = "すべてのモードで、青色のブロックを合計 1,000 個消す。";
+"achievement.26.title" = "青色・10,000個";
+"achievement.26.desc" = "すべてのモードで、青色のブロックを合計 10,000 個消す。";
+"piece.cleveland_z.name" = "緑色のブロック";
+"achievement.27.title" = "緑色・100個";
+"achievement.27.desc" = "すべてのモードで、緑色のブロックを合計 100 個消す。";
+"achievement.28.title" = "緑色・1,000個";
+"achievement.28.desc" = "すべてのモードで、緑色のブロックを合計 1,000 個消す。";
+"achievement.29.title" = "緑色・10,000個";
+"achievement.29.desc" = "すべてのモードで、緑色のブロックを合計 10,000 個消す。";
+"piece.rhode_island_z.name" = "赤色のブロック";
+"achievement.30.title" = "赤色・100個";
+"achievement.30.desc" = "すべてのモードで、赤色のブロックを合計 100 個消す。";
+"achievement.31.title" = "赤色・1,000個";
+"achievement.31.desc" = "すべてのモードで、赤色のブロックを合計 1,000 個消す。";
+"achievement.32.title" = "赤色・10,000個";
+"achievement.32.desc" = "すべてのモードで、赤色のブロックを合計 10,000 個消す。";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -138,3 +138,35 @@
 "achievement.accessibility.locked" = "%@, 미달성";
 "achievement.accessibility.unlocked" = "%@, 달성";
 "achievement.progress.legacy" = "이전 버전에서 달성했습니다. 과거 진행 기록은 없습니다";
+
+// 按方块类型记录累计消除数量及百、千、万三档里程碑。
+"banner.total_cleared" = "누적 제거";
+"banner.piece_cleared" = "%@: 누적 제거 %@";
+"piece.orange_ricky.name" = "주황색 블록";
+"achievement.21.title" = "주황색 · 100개";
+"achievement.21.desc" = "모든 모드에서 주황색 블록을 누적 100개 제거하세요.";
+"achievement.22.title" = "주황색 · 1,000개";
+"achievement.22.desc" = "모든 모드에서 주황색 블록을 누적 1,000개 제거하세요.";
+"achievement.23.title" = "주황색 · 10,000개";
+"achievement.23.desc" = "모든 모드에서 주황색 블록을 누적 10,000개 제거하세요.";
+"piece.blue_ricky.name" = "파란색 블록";
+"achievement.24.title" = "파란색 · 100개";
+"achievement.24.desc" = "모든 모드에서 파란색 블록을 누적 100개 제거하세요.";
+"achievement.25.title" = "파란색 · 1,000개";
+"achievement.25.desc" = "모든 모드에서 파란색 블록을 누적 1,000개 제거하세요.";
+"achievement.26.title" = "파란색 · 10,000개";
+"achievement.26.desc" = "모든 모드에서 파란색 블록을 누적 10,000개 제거하세요.";
+"piece.cleveland_z.name" = "초록색 블록";
+"achievement.27.title" = "초록색 · 100개";
+"achievement.27.desc" = "모든 모드에서 초록색 블록을 누적 100개 제거하세요.";
+"achievement.28.title" = "초록색 · 1,000개";
+"achievement.28.desc" = "모든 모드에서 초록색 블록을 누적 1,000개 제거하세요.";
+"achievement.29.title" = "초록색 · 10,000개";
+"achievement.29.desc" = "모든 모드에서 초록색 블록을 누적 10,000개 제거하세요.";
+"piece.rhode_island_z.name" = "빨간색 블록";
+"achievement.30.title" = "빨간색 · 100개";
+"achievement.30.desc" = "모든 모드에서 빨간색 블록을 누적 100개 제거하세요.";
+"achievement.31.title" = "빨간색 · 1,000개";
+"achievement.31.desc" = "모든 모드에서 빨간색 블록을 누적 1,000개 제거하세요.";
+"achievement.32.title" = "빨간색 · 10,000개";
+"achievement.32.desc" = "모든 모드에서 빨간색 블록을 누적 10,000개 제거하세요.";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -138,3 +138,35 @@
 "achievement.accessibility.locked" = "%@, закрыто";
 "achievement.accessibility.unlocked" = "%@, открыто";
 "achievement.progress.legacy" = "Открыто в прежней версии; прошлый прогресс не записывался";
+
+// 按方块类型记录累计消除数量及百、千、万三档里程碑。
+"banner.total_cleared" = "Всего удалено";
+"banner.piece_cleared" = "%@: всего удалено %@";
+"piece.orange_ricky.name" = "Оранжевые блоки";
+"achievement.21.title" = "Оранжевые · 100";
+"achievement.21.desc" = "Удалите 100 оранжевых блоков во всех режимах.";
+"achievement.22.title" = "Оранжевые · 1,000";
+"achievement.22.desc" = "Удалите 1,000 оранжевых блоков во всех режимах.";
+"achievement.23.title" = "Оранжевые · 10,000";
+"achievement.23.desc" = "Удалите 10,000 оранжевых блоков во всех режимах.";
+"piece.blue_ricky.name" = "Синие блоки";
+"achievement.24.title" = "Синие · 100";
+"achievement.24.desc" = "Удалите 100 синих блоков во всех режимах.";
+"achievement.25.title" = "Синие · 1,000";
+"achievement.25.desc" = "Удалите 1,000 синих блоков во всех режимах.";
+"achievement.26.title" = "Синие · 10,000";
+"achievement.26.desc" = "Удалите 10,000 синих блоков во всех режимах.";
+"piece.cleveland_z.name" = "Зелёные блоки";
+"achievement.27.title" = "Зелёные · 100";
+"achievement.27.desc" = "Удалите 100 зелёных блоков во всех режимах.";
+"achievement.28.title" = "Зелёные · 1,000";
+"achievement.28.desc" = "Удалите 1,000 зелёных блоков во всех режимах.";
+"achievement.29.title" = "Зелёные · 10,000";
+"achievement.29.desc" = "Удалите 10,000 зелёных блоков во всех режимах.";
+"piece.rhode_island_z.name" = "Красные блоки";
+"achievement.30.title" = "Красные · 100";
+"achievement.30.desc" = "Удалите 100 красных блоков во всех режимах.";
+"achievement.31.title" = "Красные · 1,000";
+"achievement.31.desc" = "Удалите 1,000 красных блоков во всех режимах.";
+"achievement.32.title" = "Красные · 10,000";
+"achievement.32.desc" = "Удалите 10,000 красных блоков во всех режимах.";
```
