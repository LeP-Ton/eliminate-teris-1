# 20 枚成就系统实现

## 背景与目标
- 将原有 20 个占位按钮和 3 个快照触发示例替换为完整的入门、技巧、模式及累计成就。
- 对应会话：会话-4 的设计方案；会话-5 起的本轮实现与验证。
- Git 基线：`b37bcdce5545710a4044d0d0cdbd75dbce03f27f`。本轮开始时工作区干净，本文 diff 包含本轮全部代码、资源、测试与认知/索引变化，不包含本文自身。
- 本轮未创建 Git 提交。按会话回溯时，应以本文逐文件 diff 与基线定位本轮变更，避免覆盖后续修改。

## 约束与原则
- 不改变每格 10 分、左侧补位或现有 Touch Bar 三阶段动画与音效链路。
- 不增加签到、数值奖励、外观装备或联网依赖。
- 采用系统 XCTest，不引入第三方测试框架；测试存储与玩家存档完全隔离。
- 文档检索先读 `.agentdocs/index.md`，再按读取场景查阅本文。

## 阶段与 TODO
- [x] 提取交换结算数据并接入真实操作/结算事件。
- [x] 实现固定定义、事件去重、累计统计、历史最佳和版本化存档。
- [x] 保留旧编号 1—3 的解锁与时间，不迁移占位成就或排行榜 seed。
- [x] 完成徽章栏、详情/全部成就筛选、非模态通知与五语言文案。
- [x] 完成 29 项自动化测试、构建与 diff 检查。
- [x] 更新根索引及 AGENTS.md 中的核心架构认知。
- [ ] Touch Bar 真机触控、动画与音效体验验收。

## 成就与统计口径

| 编号 | 名称 | 条件 |
| --- | --- | --- |
| 1 | 小试身手 | 任意模式单局 100 分 |
| 2 | 节奏初现 | 连续 3 次得分交换，相邻间隔 ≤ 1.6 秒 |
| 3 | 有始有终 | 正常完成一局有得分的竞分/竞速 |
| 4 | 指尖火花 | 第一次交换消除 |
| 5 | 四格齐鸣 | 单轮至少 4 格同色长连 |
| 6 | 五格共振 | 单轮至少 5 格同色长连 |
| 7 | 连锁反应 | 单次交换至少 2 轮消除 |
| 8 | 余波未平 | 单次交换至少 3 轮消除 |
| 9 | 步步有解 | 单局连续 5 次交换均消除，不限间隔 |
| 10 | 一分钟热身 | 完成 1 分钟竞分且 ≥ 300 分 |
| 11 | 两分钟专注 | 完成 2 分钟竞分且 ≥ 600 分 |
| 12 | 三分钟巡航 | 完成 3 分钟竞分且 ≥ 900 分 |
| 13 | 初见终点 | 完成 300 分竞速 |
| 14 | 加速前进 | 完成 600 分竞速 |
| 15 | 长程冲刺 | 完成 900 分竞速 |
| 16 | 分秒必争 | 300 分竞速用时 ≤ 60 秒 |
| 17 | 百格起步 | 累计消除 100 格 |
| 18 | 千格熟手 | 累计消除 1,000 格 |
| 19 | 万格旅人 | 累计消除 10,000 格 |
| 20 | 挑战常客 | 正常完成 20 局有效挑战 |

- 同轮多组三连不会被计为四连/五连；自动补位产生的后续消除算同一次交换的后续轮次。
- 不消除的有效交换打断两种连续操作；节奏超时只打断节奏，重开/模式切换打断所有单局连续状态。
- 竞分自然到时且有得分才计完成；竞速达标即完成。提前退出、重开、切换不计完成。
- 先记录最后一次交换，再记录完成；重复交换 UUID、重复完成与旧局事件均不会重复累计。
- 所有解锁时间和历史最佳保存在本机；迁移成就没有旧进度时明确显示旧版解锁说明。

## 实现与接口
- `SwapResolution` 表达有效交换、消除格数、消除轮数和最长同色连续长度；原交换方法仍返回是否产生消除。
- `GameBoardController` 可注入成就管理器、时钟和棋盘工厂；生产默认行为保持不变，自动化测试使用确定性数据。
- `AchievementsManager` 提供 `beginRound`、`recordSwap`、`finishRound`、进度/时间查询；存储键为 `AchievementsManager.state.v1`，分字段读取损坏存档。
- 使用 `didChangeNotification` 刷新界面，`didUnlockNotification` 的 `ids` 数组按编号发送本次所有新成就；存档先于通知保存。
- 横向徽章栏显示完成数、锁/勾图标及真实名称；详情和图鉴复用不获取键盘焦点的原生面板，按类别及解锁状态筛选。
- 窗口内提示显示 3 秒，按编号排队；待展示数量大于 3 时合并。当前操作事件循环内的交换和结算解锁会合并处理。
- 五语言均有独立成就文案。资源查找新增代码 Bundle 旁的 SwiftPM 资源路径，用于 XCTest 宿主；开发态/打包态继续优先匹配原路径。

## 关键风险与限制
- 高难阈值为首版值，尚未经真实玩家数据校准；以后调整阈值应保留已解锁记录。
- 无法从旧排行榜准确还原消除或完整局数，因此不回推旧累计进度。
- 自动化已验证面板不争夺键盘焦点，但尚未完成真实 Touch Bar 的触摸、三阶段动画和音效验收。

## 测试用例与结果

### TC-001 消除数据准确
- 类型：规则测试；优先级：高；模块：GameState。
- 前置条件：注入固定初始棋盘和补位序列。
- 步骤：触发单组三连、同轮双三连、补位五连和三轮连消。
- 预期：格数、轮次、最长连续长度和每格 10 分均准确；无消除交换仍保留。
- 结果：通过，5 项测试。

### TC-002 统计、存档与迁移
- 类型：状态测试；优先级：高；模块：AchievementsManager。
- 前置条件：为每条用例创建独立 UserDefaults 存储域。
- 步骤：覆盖节奏边界、失败交换、跨局/重启、重复事件、批量解锁、损坏字段、旧成就迁移和提示队列。
- 预期：只统计真实事件且恰好一次；保留合法字段与旧编号 1—3；提示有序且可合并。
- 结果：通过，17 项测试；包含界面按对象订阅通知及 0 秒竞速成绩的边界验证。

### TC-003 控制器生命周期
- 类型：集成测试；优先级：高；模块：GameBoardController。
- 前置条件：注入固定时钟、棋盘及成就管理器。
- 步骤：最后一次交换达标、重复读取快照、超时后交换、重开、切换及自由模式消除。
- 预期：先交换后结算，刷新不重复累计，提前放弃与零分局不计完成。
- 结果：通过，4 项测试。

### TC-004 五语言与原生面板
- 类型：资源/界面测试；优先级：高；模块：AchievementViews、Localization。
- 前置条件：加载每种语言的真实翻译和原生 AppKit 视图。
- 步骤：检查所有成就键和格式参数；切换筛选；在 480/600 宽度下布局全部成就。
- 预期：五种语言文本真实加载；全部/已解锁/未解锁数量正确，进度条有有效尺寸且可滚动；面板不获取键盘或主窗口焦点。
- 结果：通过，资源 1 项、原生界面 2 项测试。

### TC-005 Touch Bar 真机验收
- 类型：手工体验测试；优先级：高；模块：Touch Bar 与桌面主窗口。
- 前置条件：有 Touch Bar 的 MacBook，运行 `./run.sh`。
- 步骤：完成一次消除，查看解锁提示；点击徽章和查看全部，切换筛选；继续触控交换，完成竞分/竞速后重启。
- 预期：提示不阻塞触控，面板不导致棋盘消失，动画和音效正常，成就/进度/时间重启后保持。
- 结果：待真机验证。

## 验证命令

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git diff --check
```

- 最终自动化结果：29 项测试，0 失败；测试构建同时完成游戏可执行程序的编译与链接。
- 首次测试因沙箱外 Swift 编译缓存不可写而申请执行权限；获准后正常运行。
- 增强界面断言后曾发现 XCTest 宿主无法定位语言 Bundle，已补充查找路径并通过完整回归。

## 代码变更

以下均为完整逐行 diff，含新增测试及资源文件，无省略代码行。

### `.agentdocs/index.md`

```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 9da8693..42e3361 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20261026092356-achievement-system.md` - 会话-5 起实现 20 枚事件驱动成就、版本化存档迁移、五语言徽章/非模态图鉴与提示队列；含完整逐行 diff 和 29 项测试结果。
 `workflow/20260615223620-readme-screenshot-preview-remove-note-and-table.md` - 移除中英文 README 截图预览区的说明提示，并把表格布局改为更自然的分段图片展示。
 `workflow/20260615222900-readme-screenshot-preview-remove-package-column.md` - 从中英文 README 的截图预览区移除“打包产物”栏位，并同步更新截图资源说明文档。
 `workflow/20260610234858-readme-english-closing-copy-sync.md` - 同步调整英文 README 结尾邀请文案，与中文版本统一为更轻松的“关注并留言”语气。
@@ -59,6 +60,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要了解成就清单、真实交换/结算事件、旧成就迁移、进度存档、非模态图鉴或成就测试时，读取 `20261026092356-achievement-system.md`。
 - 需要确认“截图预览区是否已经去掉提示文案与表格，改为纵向分段展示”时，优先读取 `20260615223620` 文档。
 - 需要确认“截图预览区是否已经去掉打包产物，仅保留桌面主界面与 Touch Bar 棋盘”时，优先读取 `20260615222900` 文档。
 - 需要确认“英文 README 结尾是否也已经同步改成更轻松的关注/留言语气”时，优先读取 `20260610234858` 文档。
@@ -118,6 +120,9 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 成就统计由棋盘控制器提交真实事件，独立于 HUD 刷新和挑战排行；累计值与历史最佳跨局保存，节奏/连续交换在重开和模式切换时清零。
+- 旧版仅迁移成就编号 1—3 的解锁与时间；不使用排行榜或开发 seed 回推新成就。
+- 成就面板不获取主窗口焦点；自动化测试通过隔离 UserDefaults 与可控棋盘验证规则，命令为 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。
 - 中英文 README 的截图预览区现已去掉顶部说明提示与表格结构，改为“标题 + 图片 + 简短说明”的纵向分段展示。
 - README 截图预览区现已收敛为两栏：仅保留“桌面主界面”和“Touch Bar 棋盘”；`docs/screenshots/README.md` 也已同步移除“打包产物”说明。
 - 英文 README 结尾现已与中文同步，改为更轻松的展示页式邀请语：强调“small but fun”，并以“follow and leave a comment”收尾。
```

### `AGENTS.md`

```diff
diff --git a/AGENTS.md b/AGENTS.md
index 42e6ca5..c4e9d1f 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -1,5 +1,15 @@
 # 项目认知记录
 
+## 项目基础与检索方法
+- 项目为 macOS 12+ 原生 AppKit/Cocoa 游戏，使用 Swift 5.7+ 与 Swift Package Manager；桌面窗口负责设置和信息展示，16 格 Touch Bar 承载核心操作。
+- 本地启动使用 `./run.sh`，打包使用 `./package.sh`；自动化验证使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，测试使用系统自带 XCTest。
+- 检索项目时先读取 `.agentdocs/index.md`，再按索引中的读取场景查阅具体文档；不要直接全量检索 `.agentdocs/workflow/`。
+
+## 2026-10-26
+- 成就采用独立的事件驱动架构：`GameState` 提供交换结算数据，`GameBoardController` 提交交换与正常结算事件，`AchievementsManager` 负责规则、去重、累计进度和版本化本地存档；界面刷新与挑战排行榜不参与成就判定。
+- 成就展示使用桌面徽章栏、非模态图鉴/详情面板与窗口内通知队列；成就面板不争夺主窗口焦点，避免影响现有 Touch Bar 展示生命周期。
+- 测试通过注入时间、棋盘补位序列与独立 UserDefaults 域验证游戏和成就规则，不依赖随机结果或玩家真实存档。
+
 ## 2026-06-10
 - README 顶部现已增强为“项目首页入口”形态：`README.md` 与 `README.en.md` 都新增了静态徽章，首屏即可看到平台、Swift 版本、Touch Bar 适配与当前可玩状态。
 - 中英文 README 顶部都已加入目录（TOC）与“截图预览”占位区；当前仓库还没有正式截图资源，后续补图时应优先填充该区域，而不是把截图分散插入正文各处。
```

### `Package.swift`

```diff
diff --git a/Package.swift b/Package.swift
index ae251c2..92afff3 100644
--- a/Package.swift
+++ b/Package.swift
@@ -17,6 +17,7 @@ let package = Package(
             resources: [
                 .process("Resources")
             ]
-        )
+        ),
+        .testTarget(name: "EliminateTeris1Tests", dependencies: ["EliminateTeris1"], path: "Tests")
     ]
 )
```

### `Sources/AchievementsManager.swift`

```diff
diff --git a/Sources/AchievementsManager.swift b/Sources/AchievementsManager.swift
index 32d05a6..63ece02 100644
--- a/Sources/AchievementsManager.swift
+++ b/Sources/AchievementsManager.swift
@@ -1,55 +1,243 @@
 import Foundation
+import CoreFoundation
 
+enum AchievementCategory: String, CaseIterable {
+    case beginner, skill, mode, lifetime
+}
+
+enum AchievementGoal {
+    case bestScore(Int), rhythm(Int), completedRounds(Int), firstClear
+    case longestRun(Int), cascades(Int), successfulSwaps(Int)
+    case scoreAttack(minutes: Int, score: Int)
+    case speedRun(target: Int, limit: TimeInterval?)
+    case totalCleared(Int)
+}
+
+struct AchievementDefinition {
+    let id: Int
+    let category: AchievementCategory
+    let goal: AchievementGoal
+
+    var titleKey: String { "achievement.\(id).title" }
+    var descriptionKey: String { "achievement.\(id).desc" }
+
+    static let all: [AchievementDefinition] = [
+        .init(id: 1, category: .beginner, goal: .bestScore(100)),
+        .init(id: 2, category: .beginner, goal: .rhythm(3)),
+        .init(id: 3, category: .beginner, goal: .completedRounds(1)),
+        .init(id: 4, category: .beginner, goal: .firstClear),
+        .init(id: 5, category: .skill, goal: .longestRun(4)),
+        .init(id: 6, category: .skill, goal: .longestRun(5)),
+        .init(id: 7, category: .skill, goal: .cascades(2)),
+        .init(id: 8, category: .skill, goal: .cascades(3)),
+        .init(id: 9, category: .skill, goal: .successfulSwaps(5)),
+        .init(id: 10, category: .mode, goal: .scoreAttack(minutes: 1, score: 300)),
+        .init(id: 11, category: .mode, goal: .scoreAttack(minutes: 2, score: 600)),
+        .init(id: 12, category: .mode, goal: .scoreAttack(minutes: 3, score: 900)),
+        .init(id: 13, category: .mode, goal: .speedRun(target: 300, limit: nil)),
+        .init(id: 14, category: .mode, goal: .speedRun(target: 600, limit: nil)),
+        .init(id: 15, category: .mode, goal: .speedRun(target: 900, limit: nil)),
+        .init(id: 16, category: .mode, goal: .speedRun(target: 300, limit: 60)),
+        .init(id: 17, category: .lifetime, goal: .totalCleared(100)),
+        .init(id: 18, category: .lifetime, goal: .totalCleared(1_000)),
+        .init(id: 19, category: .lifetime, goal: .totalCleared(10_000)),
+        .init(id: 20, category: .lifetime, goal: .completedRounds(20))
+    ]
+}
+
+struct AchievementProgress {
+    let current: Double
+    let target: Double
+    let isTime: Bool
+
+    var fraction: Double {
+        if isTime { return current > 0 ? min(1, target / current) : 0 }
+        return min(1, current / target)
+    }
+}
+
+/// 只消费控制器提交的真实事件，不读取排行或界面快照。
+/// 游戏在主线程运行；写入和通知均在事件处理线程同步完成。
 final class AchievementsManager {
     static let shared = AchievementsManager()
-
     static let didUnlockNotification = Notification.Name("com.eliminateteris1.achievements.didUnlock")
+    static let didChangeNotification = Notification.Name("com.eliminateteris1.achievements.didChange")
+    static let storageKey = "AchievementsManager.state.v1"
 
-    private let unlockedKey = "AchievementsManager.unlockedIds"
-    private let timestampsKey = "AchievementsManager.unlockTimestamps"
+    private let defaults: UserDefaults
+    private var unlocked: Set<Int> = []
+    private var timestamps: [String: Double] = [:]
+    // 仅持久化累计值与历史最佳；跨局节奏和连续交换状态不会被恢复。
+    private var metrics: [String: Double] = [:]
+    private var roundID: UUID?
+    private var processedSwaps: Set<UUID> = []
+    private var roundFinished = false
+    private var rhythm = 0
+    private var successfulSwaps = 0
+    private var lastClearDate: Date?
 
-    private var unlockedIds: Set<Int> = []
-    private var unlockTimestamps: [String: TimeInterval] = [:]
+    init(defaults: UserDefaults = .standard) {
+        self.defaults = defaults
+        load()
+    }
 
-    private init() {
-        loadFromDefaults()
+    func isUnlocked(id: Int) -> Bool { unlocked.contains(id) }
+    func unlockedIDs() -> [Int] { unlocked.sorted() }
+    func unlockDate(id: Int) -> Date? { timestamps[String(id)].map(Date.init(timeIntervalSince1970:)) }
+
+    func beginRound(id: UUID) {
+        guard roundID != id else { return }
+        roundID = id
+        processedSwaps.removeAll()
+        roundFinished = false
+        rhythm = 0
+        successfulSwaps = 0
+        lastClearDate = nil
     }
 
-    private func loadFromDefaults() {
-        let defaults = UserDefaults.standard
-        if let array = defaults.array(forKey: unlockedKey) as? [Int] {
-            unlockedIds = Set(array)
+    func recordSwap(roundID: UUID, swapID: UUID, result: SwapResolution, score: Int, at date: Date) {
+        guard self.roundID == roundID, !roundFinished, result.isValidSwap,
+              processedSwaps.insert(swapID).inserted else { return }
+
+        if result.clearedCount > 0 {
+            let interval = lastClearDate.map { date.timeIntervalSince($0) }
+            // 浮点时间在精确 1.6 秒处可能出现微小误差。
+            rhythm = interval.map { $0 >= 0 && $0 <= 1.600001 } == true ? rhythm + 1 : 1
+            successfulSwaps += 1
+            lastClearDate = date
+            metrics["totalCleared", default: 0] += Double(result.clearedCount)
+            updateBest("rhythm", Double(rhythm))
+            updateBest("successfulSwaps", Double(successfulSwaps))
+        } else {
+            rhythm = 0
+            successfulSwaps = 0
+            lastClearDate = nil
         }
-        if let dict = defaults.dictionary(forKey: timestampsKey) as? [String: Double] {
-            unlockTimestamps = dict
+        updateBest("bestScore", Double(score))
+        updateBest("longestRun", Double(result.longestRun))
+        updateBest("cascades", Double(result.cascadeCount))
+        saveAndEvaluate(at: date)
+    }
+
+    func finishRound(id: UUID, mode: GameMode, score: Int, elapsed: TimeInterval, at date: Date) {
+        guard roundID == id, !roundFinished, elapsed.isFinite, elapsed >= 0 else { return }
+        switch mode {
+        case .free:
+            return
+        case .scoreAttack(let duration):
+            guard duration > 0, elapsed >= duration else { return }
+            roundFinished = true
+            guard score > 0 else { return }
+            updateBest("scoreAttack.\(Int(duration / 60))", Double(score))
+        case .speedRun(let target):
+            guard target > 0, score >= target else { return }
+            roundFinished = true
+            let key = "speedRun.\(target)"
+            // 完成标记与用时分开保存，允许合法的 0 秒成绩。
+            metrics[key] = min(metrics[key] ?? .greatestFiniteMagnitude, elapsed)
+            metrics["speedRunCompleted.\(target)"] = 1
         }
+        metrics["completedRounds", default: 0] += 1
+        saveAndEvaluate(at: date)
     }
 
-    private func saveToDefaults() {
-        let defaults = UserDefaults.standard
-        defaults.set(Array(unlockedIds), forKey: unlockedKey)
-        defaults.set(unlockTimestamps, forKey: timestampsKey)
+    func progress(for definition: AchievementDefinition) -> AchievementProgress {
+        func value(_ key: String, _ target: Double) -> AchievementProgress {
+            .init(current: metrics[key, default: 0], target: target, isTime: false)
+        }
+        switch definition.goal {
+        case .bestScore(let target): return value("bestScore", Double(target))
+        case .rhythm(let target): return value("rhythm", Double(target))
+        case .completedRounds(let target): return value("completedRounds", Double(target))
+        case .firstClear: return .init(current: metrics["totalCleared", default: 0] > 0 ? 1 : 0, target: 1, isTime: false)
+        case .longestRun(let target): return value("longestRun", Double(target))
+        case .cascades(let target): return value("cascades", Double(target))
+        case .successfulSwaps(let target): return value("successfulSwaps", Double(target))
+        case .scoreAttack(let minutes, let score): return value("scoreAttack.\(minutes)", Double(score))
+        case .speedRun(let target, let limit):
+            if let limit {
+                return .init(current: metrics["speedRun.\(target)", default: 0], target: limit, isTime: true)
+            }
+            return value("speedRunCompleted.\(target)", 1)
+        case .totalCleared(let target): return value("totalCleared", Double(target))
+        }
     }
 
-    func isUnlocked(id: Int) -> Bool {
-        return unlockedIds.contains(id)
+    func hasTimedResult(for definition: AchievementDefinition) -> Bool {
+        guard case .speedRun(let target, let limit) = definition.goal, limit != nil else { return false }
+        return metrics["speedRunCompleted.\(target)"] == 1
     }
 
-    func unlock(id: Int) {
-        guard !unlockedIds.contains(id) else { return }
-        unlockedIds.insert(id)
-        unlockTimestamps[String(id)] = Date().timeIntervalSince1970
-        saveToDefaults()
-        NotificationCenter.default.post(name: AchievementsManager.didUnlockNotification, object: self, userInfo: ["id": id])
+    private func updateBest(_ key: String, _ value: Double) {
+        metrics[key] = max(metrics[key, default: 0], value)
     }
 
-    func unlockedIDs() -> [Int] {
-        return Array(unlockedIds).sorted()
+    private func saveAndEvaluate(at date: Date) {
+        var newIDs: [Int] = []
+        for definition in AchievementDefinition.all where !isUnlocked(id: definition.id) {
+            let progress = progress(for: definition)
+            let reached = progress.isTime
+                ? hasTimedResult(for: definition) && progress.current <= progress.target
+                : progress.current >= progress.target
+            if reached {
+                unlocked.insert(definition.id)
+                timestamps[String(definition.id)] = date.timeIntervalSince1970
+                newIDs.append(definition.id)
+            }
+        }
+        save()
+        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
+        if !newIDs.isEmpty {
+            NotificationCenter.default.post(name: Self.didUnlockNotification, object: self, userInfo: ["ids": newIDs])
+        }
     }
 
-    func resetAll() {
-        unlockedIds.removeAll()
-        unlockTimestamps.removeAll()
-        saveToDefaults()
+    private func load() {
+        let validIDs = Set(AchievementDefinition.all.map(\.id))
+        if let stored = defaults.dictionary(forKey: Self.storageKey) {
+            unlocked = Set((stored["unlocked"] as? [Int] ?? []).filter { validIDs.contains($0) })
+            // 分字段读取，避免一个损坏字段导致整份进度丢失。
+            metrics = readNumbers(stored["metrics"])
+            timestamps = readNumbers(stored["timestamps"])
+        } else {
+            // 旧版 4...20 为无真实定义的占位，不能迁移成新成就。
+            unlocked = Set((defaults.array(forKey: "AchievementsManager.unlockedIds") as? [Int] ?? []).filter { (1...3).contains($0) })
+            let oldTimes = readNumbers(defaults.dictionary(forKey: "AchievementsManager.unlockTimestamps"))
+            timestamps = oldTimes.filter { unlocked.contains(Int($0.key) ?? -1) }
+        }
+        save()
+    }
+
+    private func readNumbers(_ raw: Any?) -> [String: Double] {
+        guard let dictionary = raw as? [String: Any] else { return [:] }
+        return dictionary.reduce(into: [:]) { values, item in
+            if let number = item.value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
+               number.doubleValue.isFinite, number.doubleValue >= 0 {
+                values[item.key] = number.doubleValue
+            }
+        }
+    }
+
+    private func save() {
+        defaults.set(["version": 1, "unlocked": unlocked.sorted(), "timestamps": timestamps, "metrics": metrics], forKey: Self.storageKey)
+    }
+}
+
+/// 展示队列与窗口无关，便于验证顺序、去重和批量提示策略。
+struct AchievementUnlockQueue {
+    private(set) var pending: [Int] = []
+
+    mutating func enqueue(_ ids: [Int]) {
+        pending = Array(Set(pending).union(ids)).sorted()
+    }
+
+    mutating func next() -> [Int] {
+        guard !pending.isEmpty else { return [] }
+        if pending.count > 3 {
+            let batch = pending
+            pending.removeAll()
+            return batch
+        }
+        return [pending.removeFirst()]
     }
 }
```

### `Sources/GameState.swift`

```diff
diff --git a/Sources/GameState.swift b/Sources/GameState.swift
index 09766dc..f99305f 100644
--- a/Sources/GameState.swift
+++ b/Sources/GameState.swift
@@ -1,5 +1,15 @@
 import Foundation
 
+/// 一次实际交换的结算数据；自动补位引发的所有消除都归属同一次交换。
+struct SwapResolution: Equatable {
+    let isValidSwap: Bool
+    let clearedCount: Int
+    let cascadeCount: Int
+    let longestRun: Int
+
+    static let invalid = SwapResolution(isValidSwap: false, clearedCount: 0, cascadeCount: 0, longestRun: 0)
+}
+
 struct BoardTile: Equatable {
     let id: UUID
     let kind: PieceKind
@@ -14,14 +24,20 @@ final class GameState {
     let columns: Int
     private(set) var tiles: [BoardTile]
     private(set) var score: Int = 0
+    private(set) var lastResolution: SwapResolution = .invalid
+    private let nextKind: () -> PieceKind
 
-    init(columns: Int) {
+    /// 可注入初始棋盘和补位序列，让连消等规则可以确定性验证。
+    init(columns: Int, initialKinds: [PieceKind]? = nil, nextKind: @escaping () -> PieceKind = PieceKind.random) {
+        precondition(columns > 0 && (initialKinds == nil || initialKinds?.count == columns))
         self.columns = columns
-        self.tiles = (0..<columns).map { _ in BoardTile(kind: PieceKind.random()) }
+        self.nextKind = nextKind
+        self.tiles = initialKinds?.map { BoardTile(kind: $0) } ?? (0..<columns).map { _ in BoardTile(kind: nextKind()) }
         normalizeStart()
     }
 
     func attemptSwap(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
+        lastResolution = .invalid
         guard leftIndex != rightIndex else { return false }
         guard abs(leftIndex - rightIndex) == 1 else { return false }
         guard leftIndex >= 0, rightIndex >= 0 else { return false }
@@ -33,48 +49,56 @@ final class GameState {
             return false
         }
 
-        resolveMatches()
+        lastResolution = resolveMatches()
         return true
     }
 
     func swapAndResolve(_ leftIndex: Int, _ rightIndex: Int) -> Bool {
+        lastResolution = .invalid
         guard leftIndex != rightIndex else { return false }
         guard abs(leftIndex - rightIndex) == 1 else { return false }
         guard leftIndex >= 0, rightIndex >= 0 else { return false }
         guard leftIndex < tiles.count, rightIndex < tiles.count else { return false }
 
         tiles.swapAt(leftIndex, rightIndex)
-        let hasMatch = !findMatches().isEmpty
-        if hasMatch {
-            resolveMatches()
-        }
-        return hasMatch
+        lastResolution = resolveMatches()
+        return lastResolution.clearedCount > 0
     }
 
     private func normalizeStart() {
         while !findMatches().isEmpty {
             for index in findMatches() {
-                tiles[index] = BoardTile(kind: PieceKind.random())
+                tiles[index] = BoardTile(kind: nextKind())
             }
         }
     }
 
-    private func resolveMatches() {
+    private func resolveMatches() -> SwapResolution {
+        var clearedCount = 0
+        var cascadeCount = 0
+        var longestRun = 0
         while true {
-            let matches = findMatches()
+            let (matches, runLength) = matchDetails()
             if matches.isEmpty {
                 break
             }
 
             score += matches.count * 10
+            clearedCount += matches.count
+            cascadeCount += 1
+            longestRun = max(longestRun, runLength)
             refillAfterClearing(matches)
         }
+        return SwapResolution(isValidSwap: true, clearedCount: clearedCount, cascadeCount: cascadeCount, longestRun: longestRun)
     }
 
     private func findMatches() -> Set<Int> {
-        guard !tiles.isEmpty else { return [] }
+        return matchDetails().0
+    }
 
+    private func matchDetails() -> (Set<Int>, Int) {
         var matches: Set<Int> = []
+        var longestRun = 0
         var index = 0
         while index < tiles.count {
             let current = tiles[index].kind
@@ -85,6 +109,7 @@ final class GameState {
 
             let length = next - index
             if length >= 3 {
+                longestRun = max(longestRun, length)
                 for matchIndex in index..<next {
                     matches.insert(matchIndex)
                 }
@@ -92,7 +117,7 @@ final class GameState {
 
             index = next
         }
-        return matches
+        return (matches, longestRun)
     }
 
     private func refillAfterClearing(_ matches: Set<Int>) {
@@ -104,7 +129,7 @@ final class GameState {
         }
 
         let missing = columns - remaining.count
-        let leftFill = (0..<missing).map { _ in BoardTile(kind: PieceKind.random()) }
+        let leftFill = (0..<missing).map { _ in BoardTile(kind: nextKind()) }
         tiles = leftFill + remaining
     }
 }
```

### `Sources/GameTouchBarView.swift`

```diff
diff --git a/Sources/GameTouchBarView.swift b/Sources/GameTouchBarView.swift
index 82b4613..964cf08 100644
--- a/Sources/GameTouchBarView.swift
+++ b/Sources/GameTouchBarView.swift
@@ -23,6 +23,10 @@ final class GameBoardController {
     }
 
     private let columnsCount: Int
+    private let achievements: AchievementsManager
+    private let currentDate: () -> Date
+    private let stateFactory: (Int) -> GameState
+    private var roundID = UUID()
     private var state: GameState
     private var mode: GameMode = .free
     private var roundStartDate = Date()
@@ -35,9 +39,16 @@ final class GameBoardController {
     private var selectedIndex: Int?
     private var observers: [UUID: Observer] = [:]
 
-    init(columns: Int) {
+    init(columns: Int, achievements: AchievementsManager = .shared,
+         now: @escaping () -> Date = Date.init,
+         stateFactory: @escaping (Int) -> GameState = { GameState(columns: $0) }) {
         self.columnsCount = columns
-        self.state = GameState(columns: columns)
+        self.achievements = achievements
+        self.currentDate = now
+        self.stateFactory = stateFactory
+        self.state = stateFactory(columns)
+        self.roundStartDate = now()
+        achievements.beginRound(id: roundID)
     }
 
     var columns: Int {
@@ -46,7 +57,7 @@ final class GameBoardController {
 
     func configure(mode: GameMode) {
         self.mode = mode
-        resetBoard(startDate: Date())
+        resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
         isRunningRound = isFreeMode
         isFinished = false
@@ -56,22 +67,23 @@ final class GameBoardController {
     func startRound() {
         guard !isFreeMode else { return }
 
-        resetBoard(startDate: Date())
+        resetBoard(startDate: currentDate())
         stoppedElapsedTime = 0
         isRunningRound = true
         isFinished = false
         notifyChange()
     }
 
-    func tick(now: Date = Date()) {
+    func tick(now: Date? = nil) {
         guard !isFreeMode else { return }
         guard isRunningRound else { return }
 
-        _ = updateFinishedState(now: now)
+        _ = updateFinishedState(now: now ?? currentDate())
         notifyChange()
     }
 
-    func snapshot(now: Date = Date()) -> GameSnapshot {
+    func snapshot(now: Date? = nil) -> GameSnapshot {
+        let now = now ?? currentDate()
         _ = updateFinishedState(now: now)
 
         let elapsed: TimeInterval
@@ -176,6 +188,7 @@ final class GameBoardController {
 
     func performSwap(from leftIndex: Int, to rightIndex: Int) {
         guard canInteract() else { return }
+        guard (0..<columnsCount).contains(leftIndex), (0..<columnsCount).contains(rightIndex) else { return }
         guard abs(leftIndex - rightIndex) == 1 else { return }
         guard !lockedIndices.contains(leftIndex), !lockedIndices.contains(rightIndex) else { return }
 
@@ -187,7 +200,10 @@ final class GameBoardController {
         lockedIndices.remove(rightIndex)
         selectedIndex = nil
 
-        _ = updateFinishedState(now: Date())
+        // 最后一笔交换先入账，再发送达标结算，保证同一操作触发的成就全部生效。
+        let now = currentDate()
+        achievements.recordSwap(roundID: roundID, swapID: UUID(), result: state.lastResolution, score: state.score, at: now)
+        _ = updateFinishedState(now: now)
         notifyChange()
     }
 
@@ -215,15 +231,17 @@ final class GameBoardController {
     }
 
     private func resetBoard(startDate: Date) {
-        state = GameState(columns: columnsCount)
+        state = stateFactory(columnsCount)
+        roundID = UUID()
+        achievements.beginRound(id: roundID)
         lockedIndices.removeAll()
         selectedIndex = nil
         lastSwapPair = nil
         roundStartDate = startDate
     }
 
-    private func canInteract(now: Date = Date()) -> Bool {
-        _ = updateFinishedState(now: now)
+    private func canInteract() -> Bool {
+        _ = updateFinishedState(now: currentDate())
         if isFreeMode {
             return !isFinished
         }
@@ -259,6 +277,7 @@ final class GameBoardController {
             stoppedElapsedTime = elapsed
             lockedIndices.removeAll()
             selectedIndex = nil
+            achievements.finishRound(id: roundID, mode: mode, score: state.score, elapsed: elapsed, at: now)
         }
 
         return previousFinished != isFinished
```

### `Sources/GameViewController.swift`

```diff
diff --git a/Sources/GameViewController.swift b/Sources/GameViewController.swift
index 7a2e757..7f243c1 100644
--- a/Sources/GameViewController.swift
+++ b/Sources/GameViewController.swift
@@ -78,6 +78,9 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     private var achievementsContentWidthConstraint: NSLayoutConstraint?
     private var achievementsContainerWrapper: NSView?
     private var achievementsUnlockObserver: NSObjectProtocol?
+    private var achievementsChangeObserver: NSObjectProtocol?
+    private var achievementsPanel: AchievementsWindowController?
+    private var achievementToasts: AchievementToastPresenter?
     private var settingsExpandedWidthConstraint: NSLayoutConstraint?
     private var settingsVersusRightColumnConstraint: NSLayoutConstraint?
     private var rightColumnMinWidthConstraint: NSLayoutConstraint?
@@ -428,8 +431,18 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return makeSectionIconView(symbolName: "rosette", color: rulesThemeColor)
     }()
 
+    private lazy var achievementsAllButton: NSButton = {
+        let button = NSButton(title: "", target: self, action: #selector(showAllAchievements))
+        button.bezelStyle = .inline
+        button.contentTintColor = rulesThemeColor
+        return button
+    }()
+
     private lazy var achievementsHeaderStack: NSStackView = {
-        return makeSectionHeaderStack(iconView: achievementsTitleIconView, titleLabel: achievementsTitleLabel)
+        let stack = makeSectionHeaderStack(iconView: achievementsTitleIconView, titleLabel: achievementsTitleLabel)
+        stack.addArrangedSubview(NSView())
+        stack.addArrangedSubview(achievementsAllButton)
+        return stack
     }()
 
     private lazy var achievementsContainerStack: NSStackView = {
@@ -586,6 +599,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             achievementsCardStack.trailingAnchor.constraint(equalTo: achievementsCardView.trailingAnchor, constant: -14),
             achievementsCardStack.bottomAnchor.constraint(equalTo: achievementsCardView.bottomAnchor, constant: -14),
             achievementsScrollView.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
+            achievementsHeaderStack.widthAnchor.constraint(equalTo: achievementsCardStack.widthAnchor),
             // 固定成就卡片高度与 PixelBannerView 相同（与标题下方的四块方块区域等高）
             achievementsCardView.heightAnchor.constraint(equalTo: pixelBannerView.heightAnchor),
 
@@ -626,109 +640,86 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
     // MARK: - Achievements
 
     private func configureAchievements() {
-        // 构建一个 wrapper 作为 scroll 的 documentView，以便设定明确的内容宽度
-        // 清理旧内容
-        achievementButtons.removeAll()
-        achievementsContainerStack.subviews.forEach { $0.removeFromSuperview() }
-        achievementsContentWidthConstraint?.isActive = false
-        achievementsContentWidthConstraint = nil
-        achievementsContainerWrapper?.removeFromSuperview()
-        achievementsContainerWrapper = nil
-
         let wrapper = NSView()
         wrapper.translatesAutoresizingMaskIntoConstraints = false
         wrapper.addSubview(achievementsContainerStack)
-        // 让容器在 wrapper 中垂直居中显示（tag 风格）
-        NSLayoutConstraint.activate([
-            achievementsContainerStack.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
-            achievementsContainerStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
-            achievementsContainerStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
-        ])
-
         achievementsScrollView.documentView = wrapper
         achievementsContainerWrapper = wrapper
-
-        // 生成约 20 个成就按钮（tag 风格，高度较小），并计算内容宽度以确保横向滚动
-        let count = 20
-        let buttonWidth: CGFloat = 140
+        let definitions = AchievementDefinition.all
+        let buttonWidth: CGFloat = 210
         let buttonHeight: CGFloat = 28
-        let spacing = achievementsContainerStack.spacing
-
-        for index in 1...count {
-            let button = NSButton()
+        for definition in definitions {
+            let button = NSButton(title: "", target: self, action: #selector(achievementTapped(_:)))
+            button.tag = definition.id
             button.bezelStyle = .regularSquare
             button.isBordered = false
+            button.font = .systemFont(ofSize: 11, weight: .semibold)
             button.wantsLayer = true
             button.layer?.cornerRadius = 6
-            button.translatesAutoresizingMaskIntoConstraints = false
-
-            let title = localizedFormat("achievement.title", index)
-            let label = NSTextField(labelWithString: title)
-            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
-            label.textColor = NSColor.white
-            label.alignment = .center
-            label.translatesAutoresizingMaskIntoConstraints = false
-
-            button.addSubview(label)
-            NSLayoutConstraint.activate([
-                label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
-                label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
-            ])
-
-            button.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor
-            button.layer?.borderColor = NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.3, alpha: 1.0).cgColor
             button.layer?.borderWidth = 1
-
+            button.imagePosition = .imageLeading
+            button.translatesAutoresizingMaskIntoConstraints = false
             NSLayoutConstraint.activate([
                 button.widthAnchor.constraint(equalToConstant: buttonWidth),
                 button.heightAnchor.constraint(equalToConstant: buttonHeight)
             ])
-
-            button.tag = index
-            button.target = self
-            button.action = #selector(achievementTapped(_:))
-
             achievementsContainerStack.addArrangedSubview(button)
-            achievementButtons[index] = button
-        }
-
-        // 计算内容宽度并锁定 wrapper 宽度，确保横向滚动行为正常
-        let contentWidth = CGFloat(count) * buttonWidth + CGFloat(max(0, count - 1)) * spacing + achievementsContainerStack.edgeInsets.left + achievementsContainerStack.edgeInsets.right
-        achievementsContentWidthConstraint = wrapper.widthAnchor.constraint(equalToConstant: contentWidth)
-        achievementsContentWidthConstraint?.isActive = true
-        // wrapper 的高度与按钮高度一致（含内边距），并且容器已经垂直居中，避免溢出卡片
-        wrapper.heightAnchor.constraint(equalToConstant: buttonHeight + achievementsContainerStack.edgeInsets.top + achievementsContainerStack.edgeInsets.bottom).isActive = true
-
-        // 根据持久化状态刷新每个按钮样式
-        for index in 1...count {
-            updateAchievementButtonAppearance(index)
+            achievementButtons[definition.id] = button
         }
-
-        // 监听解锁通知，异步更新 UI
-        if achievementsUnlockObserver == nil {
-            achievementsUnlockObserver = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: nil, queue: .main) { [weak self] note in
-                guard let id = note.userInfo?["id"] as? Int else { return }
-                self?.onAchievementUnlocked(id)
-            }
+        let insets = achievementsContainerStack.edgeInsets
+        let width = CGFloat(definitions.count) * buttonWidth + CGFloat(definitions.count - 1) * achievementsContainerStack.spacing + insets.left + insets.right
+        achievementsContentWidthConstraint = wrapper.widthAnchor.constraint(equalToConstant: width)
+        NSLayoutConstraint.activate([
+            achievementsContainerStack.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
+            achievementsContainerStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
+            achievementsContainerStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
+            wrapper.heightAnchor.constraint(equalToConstant: buttonHeight + insets.top + insets.bottom),
+            achievementsContentWidthConstraint!
+        ])
+        achievementToasts = AchievementToastPresenter(host: view) { [weak self] ids in
+            self?.presentAchievements(detailID: ids.count == 1 ? ids.first : nil)
+        }
+        achievementsChangeObserver = NotificationCenter.default.addObserver(
+            forName: AchievementsManager.didChangeNotification, object: AchievementsManager.shared, queue: .main
+        ) { [weak self] _ in self?.refreshAchievements() }
+        achievementsUnlockObserver = NotificationCenter.default.addObserver(
+            forName: AchievementsManager.didUnlockNotification, object: AchievementsManager.shared, queue: .main
+        ) { [weak self] note in
+            guard let ids = note.userInfo?["ids"] as? [Int] else { return }
+            self?.achievementToasts?.enqueue(ids)
+        }
+        refreshAchievements()
+    }
+
+    private func refreshAchievements() {
+        let manager = AchievementsManager.shared
+        achievementsTitleLabel.stringValue = localizedFormat("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
+        achievementsAllButton.title = localized("achievement.view_all")
+        for definition in AchievementDefinition.all {
+            guard let button = achievementButtons[definition.id] else { continue }
+            let unlocked = manager.isUnlocked(id: definition.id)
+            button.title = localized(definition.titleKey)
+            button.image = NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil)
+            button.contentTintColor = unlocked ? .systemGreen : rulesBodyThemeColor
+            button.layer?.borderColor = (unlocked ? NSColor.systemGreen : rulesThemeColor).cgColor
+            button.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor
+            button.toolTip = localized(definition.descriptionKey) + "\n" + AchievementText.progress(definition, manager: manager)
+            button.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
         }
+        if achievementsPanel?.window?.isVisible == true { achievementsPanel?.refresh() }
+        achievementToasts?.refreshLanguage()
     }
 
-    @objc private func achievementTapped(_ sender: NSButton) {
-        let idx = sender.tag
-        let title = localizedFormat("achievement.title", idx)
-        let desc = localizedFormat("achievement.desc", idx)
-        let alert = NSAlert()
-        alert.alertStyle = .informational
-        alert.messageText = title
-        alert.informativeText = desc
-        alert.addButton(withTitle: localized("action.ok"))
-        if let window = view.window {
-            alert.beginSheetModal(for: window, completionHandler: nil)
-        } else {
-            alert.runModal()
+    private func presentAchievements(detailID: Int?) {
+        if achievementsPanel == nil {
+            achievementsPanel = AchievementsWindowController(manager: .shared)
         }
+        achievementsPanel?.present(from: view.window, detailID: detailID)
     }
 
+    @objc private func showAllAchievements() { presentAchievements(detailID: nil) }
+    @objc private func achievementTapped(_ sender: NSButton) { presentAchievements(detailID: sender.tag) }
+
     deinit {
         if let observerToken {
             controller.removeObserver(observerToken)
@@ -737,6 +728,10 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
             NotificationCenter.default.removeObserver(observer)
             achievementsUnlockObserver = nil
         }
+        if let observer = achievementsChangeObserver {
+            NotificationCenter.default.removeObserver(observer)
+        }
+        achievementsPanel?.close()
         removeTouchBarLifecycleObservers()
         invalidateSystemModalTouchBarPresentation(reason: "deinit")
         hudTimer?.invalidate()
@@ -1206,7 +1201,7 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         statusTitleLabel.stringValue = localized("panel.status")
         recordsTitleLabel.stringValue = localized("panel.records")
         rulesTitleLabel.stringValue = localized("panel.rules")
-        achievementsTitleLabel.stringValue = localized("panel.achievements")
+        refreshAchievements()
         languageTitleLabel.stringValue = localized("language.label")
         modeTitleLabel.stringValue = localized("mode.label")
         volumeTitleLabel.stringValue = localized("volume.label")
@@ -1403,8 +1398,6 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
                 resultLabel.isHidden = true
             }
         }
-        // 检查并触发成就解锁条件（轻量示例）
-        checkAchievementTriggers(with: snapshot)
     }
 
     private func updateComboState(with snapshot: GameSnapshot) {
@@ -1842,57 +1835,6 @@ final class GameViewController: NSViewController, NSTouchBarDelegate {
         return String(format: format, locale: localizer.locale, arguments: arguments)
     }
 
-    // MARK: - Achievement helpers
-
-    private func updateAchievementButtonAppearance(_ id: Int) {
-        let unlocked = AchievementsManager.shared.isUnlocked(id: id)
-        guard let button = achievementButtons[id] else { return }
-        if unlocked {
-            button.layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.44, blue: 0.12, alpha: 1).cgColor
-            button.layer?.borderColor = NSColor(calibratedRed: 0.28, green: 0.84, blue: 0.36, alpha: 1).cgColor
-        } else {
-            button.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.2, alpha: 1).cgColor
-            button.layer?.borderColor = NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.3, alpha: 1.0).cgColor
-        }
-    }
-
-    private func onAchievementUnlocked(_ id: Int) {
-        updateAchievementButtonAppearance(id)
-        if let btn = achievementButtons[id] {
-            let pop = NSPopover()
-            let vc = NSViewController()
-            let label = NSTextField(labelWithString: localizedFormat("achievement.unlocked", id))
-            label.textColor = NSColor.white
-            label.backgroundColor = NSColor.clear
-            label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
-            vc.view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 40))
-            vc.view.addSubview(label)
-            label.translatesAutoresizingMaskIntoConstraints = false
-            NSLayoutConstraint.activate([
-                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
-                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
-            ])
-            pop.contentViewController = vc
-            pop.behavior = .transient
-            pop.show(relativeTo: btn.bounds, of: btn, preferredEdge: .maxY)
-        }
-    }
-
-    private func checkAchievementTriggers(with snapshot: GameSnapshot) {
-        // 简单示例触发点：分数、连击和完成局
-        if snapshot.score >= 100 {
-            AchievementsManager.shared.unlock(id: 1)
-        }
-
-        if comboStreak >= 3 {
-            AchievementsManager.shared.unlock(id: 2)
-        }
-
-        if snapshot.isFinished {
-            AchievementsManager.shared.unlock(id: 3)
-        }
-    }
-
     private func makeControlTitleLabel(color: NSColor) -> NSTextField {
         let label = NSTextField(labelWithString: "")
         label.alignment = .right
```

### `Sources/Localization.swift`

```diff
diff --git a/Sources/Localization.swift b/Sources/Localization.swift
index 161c922..2fd1df9 100644
--- a/Sources/Localization.swift
+++ b/Sources/Localization.swift
@@ -1,5 +1,8 @@
 import Foundation
 
+/// 使用代码所在 Bundle 定位 XCTest 宿主旁的 SwiftPM 资源，避免依赖测试进程的主 Bundle。
+private final class LocalizationBundleToken: NSObject {}
+
 private enum LocalizerResourceLocator {
     static let bundleName = "EliminateTeris1_EliminateTeris1"
 
@@ -7,13 +10,15 @@ private enum LocalizerResourceLocator {
         let bundleFileName = "\(bundleName).bundle"
         let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
         let executableParentDirectory = executableDirectory?.deletingLastPathComponent()
+        let codeBundle = Bundle(for: LocalizationBundleToken.self)
 
         // 同时兼容 SwiftPM 直接运行（bundle 与可执行文件同级）和手工打包 .app（bundle 位于 Contents/Resources）。
         let candidates: [URL?] = [
             Bundle.main.resourceURL?.appendingPathComponent(bundleFileName),
             Bundle.main.bundleURL.appendingPathComponent(bundleFileName),
             executableDirectory?.appendingPathComponent(bundleFileName),
-            executableParentDirectory?.appendingPathComponent("Resources").appendingPathComponent(bundleFileName)
+            executableParentDirectory?.appendingPathComponent("Resources").appendingPathComponent(bundleFileName),
+            codeBundle.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleFileName)
         ]
 
         for candidate in candidates {
```

### `Sources/Resources/en.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/en.lproj/Localizable.strings b/Sources/Resources/en.lproj/Localizable.strings
index f1e4a24..f767b0b 100644
--- a/Sources/Resources/en.lproj/Localizable.strings
+++ b/Sources/Resources/en.lproj/Localizable.strings
@@ -80,7 +80,68 @@
 "rules.short.settlement.score_attack" = "Settles when countdown ends, ranked by final score";
 "rules.short.settlement.speed_run" = "Settles immediately on target reach, ranked by elapsed time";
 "panel.achievements" = "Achievements";
-"achievement.unlocked" = "Unlocked: Achievement %d";
-"achievement.title" = "Achievement %d";
-"achievement.desc" = "Description for achievement %d. Requirement: example requirement.";
 "action.ok" = "OK";
+
+// 成就定义、进度、筛选与解锁反馈。
+"achievement.1.title" = "A Small Start";
+"achievement.1.desc" = "Reach 100 points in one round of any mode.";
+"achievement.2.title" = "Find Your Rhythm";
+"achievement.2.desc" = "Score on 3 swaps in a row, with no more than 1.6 seconds between swaps. A swap without a clear breaks the streak.";
+"achievement.3.title" = "See It Through";
+"achievement.3.desc" = "Finish a Score Attack or Speed Run round with a positive score.";
+"achievement.4.title" = "First Spark";
+"achievement.4.desc" = "Trigger your first clear with a swap.";
+"achievement.5.title" = "Four in Harmony";
+"achievement.5.desc" = "Clear a run of at least 4 identical tiles in one wave.";
+"achievement.6.title" = "Five in Resonance";
+"achievement.6.desc" = "Clear a run of at least 5 identical tiles in one wave.";
+"achievement.7.title" = "Chain Reaction";
+"achievement.7.desc" = "Trigger at least 2 clear waves from one swap, including automatic clears after refills.";
+"achievement.8.title" = "Aftershocks";
+"achievement.8.desc" = "Trigger at least 3 clear waves from one swap, including automatic clears after refills.";
+"achievement.9.title" = "Every Move Counts";
+"achievement.9.desc" = "Make 5 consecutive swaps that each clear tiles in one round, with no time limit between swaps.";
+"achievement.10.title" = "One-Minute Warmup";
+"achievement.10.desc" = "Finish a 1-minute Score Attack with at least 300 points.";
+"achievement.11.title" = "Two-Minute Focus";
+"achievement.11.desc" = "Finish a 2-minute Score Attack with at least 600 points.";
+"achievement.12.title" = "Three-Minute Cruise";
+"achievement.12.desc" = "Finish a 3-minute Score Attack with at least 900 points.";
+"achievement.13.title" = "First Finish Line";
+"achievement.13.desc" = "Complete a 300-point Speed Run.";
+"achievement.14.title" = "Picking Up Speed";
+"achievement.14.desc" = "Complete a 600-point Speed Run.";
+"achievement.15.title" = "The Long Sprint";
+"achievement.15.desc" = "Complete a 900-point Speed Run.";
+"achievement.16.title" = "Every Second Counts";
+"achievement.16.desc" = "Complete a 300-point Speed Run in 60 seconds or less.";
+"achievement.17.title" = "A Hundred Tiles";
+"achievement.17.desc" = "Clear 100 tiles across all modes.";
+"achievement.18.title" = "A Thousand Tiles";
+"achievement.18.desc" = "Clear 1,000 tiles across all modes.";
+"achievement.19.title" = "Ten Thousand Tiles";
+"achievement.19.desc" = "Clear 10,000 tiles across all modes.";
+"achievement.20.title" = "Challenge Regular";
+"achievement.20.desc" = "Finish 20 Score Attack or Speed Run rounds. Zero-point Score Attack rounds do not count.";
+"achievement.summary" = "Achievements · %d/%d unlocked";
+"achievement.view_all" = "View all";
+"achievement.filter.all" = "All";
+"achievement.filter.locked" = "Locked";
+"achievement.filter.unlocked" = "Unlocked";
+"achievement.category.beginner" = "Getting started";
+"achievement.category.skill" = "Skills";
+"achievement.category.mode" = "Mode challenges";
+"achievement.category.lifetime" = "Milestones";
+"achievement.state.locked" = "Locked";
+"achievement.state.unlocked" = "Unlocked";
+"achievement.progress.best" = "Personal best: %@ / %@";
+"achievement.progress.total" = "Total progress: %@ / %@";
+"achievement.progress.no_time" = "No 300-point finish yet · Goal ≤ 60 seconds";
+"achievement.progress.time" = "Best time: %.2f s · Goal ≤ %.0f s";
+"achievement.date" = "Unlocked: %@";
+"achievement.toast.single" = "✓ Achievement unlocked: %@ · View";
+"achievement.toast.multiple" = "✓ %d achievements unlocked · View";
+"achievement.empty" = "No achievements in this filter";
+"achievement.accessibility.locked" = "%@, locked";
+"achievement.accessibility.unlocked" = "%@, unlocked";
+"achievement.progress.legacy" = "Unlocked in an earlier version; past progress was not recorded";
```

### `Sources/Resources/ja.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ja.lproj/Localizable.strings b/Sources/Resources/ja.lproj/Localizable.strings
index f32e3d3..7210f0e 100644
--- a/Sources/Resources/ja.lproj/Localizable.strings
+++ b/Sources/Resources/ja.lproj/Localizable.strings
@@ -73,3 +73,68 @@
 "rules.short.settlement.free" = "勝敗判定なし、ランキング対象外です";
 "rules.short.settlement.score_attack" = "時間切れで終了し、最終スコアで順位付けします";
 "rules.short.settlement.speed_run" = "目標到達で即終了し、経過時間で順位付けします";
+
+// 成就定义、进度、筛选与解锁反馈。
+"panel.achievements" = "実績";
+"achievement.1.title" = "小さな一歩";
+"achievement.1.desc" = "いずれかのモードで、1 回のプレイ中に 100 点に到達する。";
+"achievement.2.title" = "リズムをつかめ";
+"achievement.2.desc" = "1.6 秒以内の間隔で、得点する入れ替えを 3 回連続で行う。消去しない入れ替えで途切れる。";
+"achievement.3.title" = "最後まで";
+"achievement.3.desc" = "得点のあるスコアアタックかスピードランを最後まで完了する。";
+"achievement.4.title" = "最初の火花";
+"achievement.4.desc" = "入れ替えで初めてブロックを消す。";
+"achievement.5.title" = "四つの調和";
+"achievement.5.desc" = "1 回の消去で、同じブロックを連続 4 個以上消す。";
+"achievement.6.title" = "五つの共鳴";
+"achievement.6.desc" = "1 回の消去で、同じブロックを連続 5 個以上消す。";
+"achievement.7.title" = "連鎖反応";
+"achievement.7.desc" = "1 回の入れ替えで、補充後の自動消去を含めて 2 連鎖以上を起こす。";
+"achievement.8.title" = "止まらぬ余波";
+"achievement.8.desc" = "1 回の入れ替えで、補充後の自動消去を含めて 3 連鎖以上を起こす。";
+"achievement.9.title" = "一手ずつ確実に";
+"achievement.9.desc" = "1 回のプレイで、消去する入れ替えを 5 回連続で行う。操作間隔は問わない。";
+"achievement.10.title" = "1 分の準備運動";
+"achievement.10.desc" = "1 分のスコアアタックを 300 点以上で最後まで完了する。";
+"achievement.11.title" = "2 分の集中";
+"achievement.11.desc" = "2 分のスコアアタックを 600 点以上で最後まで完了する。";
+"achievement.12.title" = "3 分の巡航";
+"achievement.12.desc" = "3 分のスコアアタックを 900 点以上で最後まで完了する。";
+"achievement.13.title" = "初めてのゴール";
+"achievement.13.desc" = "300 点のスピードランを完了する。";
+"achievement.14.title" = "加速する指先";
+"achievement.14.desc" = "600 点のスピードランを完了する。";
+"achievement.15.title" = "長いスプリント";
+"achievement.15.desc" = "900 点のスピードランを完了する。";
+"achievement.16.title" = "一秒を争え";
+"achievement.16.desc" = "300 点のスピードランを 60 秒以内に完了する。";
+"achievement.17.title" = "百個からの一歩";
+"achievement.17.desc" = "すべてのモードで合計 100 個のブロックを消す。";
+"achievement.18.title" = "千個の熟練者";
+"achievement.18.desc" = "すべてのモードで合計 1,000 個のブロックを消す。";
+"achievement.19.title" = "万個の旅人";
+"achievement.19.desc" = "すべてのモードで合計 10,000 個のブロックを消す。";
+"achievement.20.title" = "挑戦の常連";
+"achievement.20.desc" = "スコアアタックかスピードランを合計 20 回完了する。0 点のスコアアタックは含まない。";
+"achievement.summary" = "実績 · %d/%d 達成";
+"achievement.view_all" = "すべて見る";
+"achievement.filter.all" = "すべて";
+"achievement.filter.locked" = "未達成";
+"achievement.filter.unlocked" = "達成済み";
+"achievement.category.beginner" = "はじめの一歩";
+"achievement.category.skill" = "操作テクニック";
+"achievement.category.mode" = "モードの挑戦";
+"achievement.category.lifetime" = "累計の記録";
+"achievement.state.locked" = "未達成";
+"achievement.state.unlocked" = "達成済み";
+"achievement.progress.best" = "自己ベスト：%@ / %@";
+"achievement.progress.total" = "累計：%@ / %@";
+"achievement.progress.no_time" = "300 点の完走記録なし · 目標 60 秒以内";
+"achievement.progress.time" = "最速：%.2f 秒 · 目標 %.0f 秒以内";
+"achievement.date" = "達成日時：%@";
+"achievement.toast.single" = "✓ 実績達成：%@ · 詳細";
+"achievement.toast.multiple" = "✓ 実績を %d 個達成 · 詳細";
+"achievement.empty" = "該当する実績はありません";
+"achievement.accessibility.locked" = "%@、未達成";
+"achievement.accessibility.unlocked" = "%@、達成済み";
+"achievement.progress.legacy" = "旧バージョンで達成済み。過去の進捗記録はありません";
```

### `Sources/Resources/ko.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ko.lproj/Localizable.strings b/Sources/Resources/ko.lproj/Localizable.strings
index 9283587..e5d16fa 100644
--- a/Sources/Resources/ko.lproj/Localizable.strings
+++ b/Sources/Resources/ko.lproj/Localizable.strings
@@ -73,3 +73,68 @@
 "rules.short.settlement.free" = "승패 판정이 없고 랭킹 집계도 하지 않습니다";
 "rules.short.settlement.score_attack" = "시간 종료 시 결산하며 최종 점수로 순위를 매깁니다";
 "rules.short.settlement.speed_run" = "목표 달성 즉시 결산하며 소요 시간으로 순위를 매깁니다";
+
+// 成就定义、进度、筛选与解锁反馈。
+"panel.achievements" = "업적";
+"achievement.1.title" = "작은 시작";
+"achievement.1.desc" = "아무 모드에서 한 판에 100점을 달성하세요.";
+"achievement.2.title" = "리듬의 시작";
+"achievement.2.desc" = "각 간격이 1.6초 이하가 되도록 점수를 얻는 교환을 3회 연속 수행하세요. 제거 없는 교환은 연속 기록을 끊습니다.";
+"achievement.3.title" = "끝까지 한 판";
+"achievement.3.desc" = "점수를 얻은 점수 도전 또는 스피드런 한 판을 정상 완료하세요.";
+"achievement.4.title" = "첫 불꽃";
+"achievement.4.desc" = "교환으로 처음 블록을 제거하세요.";
+"achievement.5.title" = "네 칸의 화음";
+"achievement.5.desc" = "한 번의 제거에서 같은 블록을 연속 4개 이상 제거하세요.";
+"achievement.6.title" = "다섯 칸의 공명";
+"achievement.6.desc" = "한 번의 제거에서 같은 블록을 연속 5개 이상 제거하세요.";
+"achievement.7.title" = "연쇄 반응";
+"achievement.7.desc" = "한 번의 교환으로 보충 후 자동 제거를 포함해 2회 이상 연쇄 제거하세요.";
+"achievement.8.title" = "멈추지 않는 여운";
+"achievement.8.desc" = "한 번의 교환으로 보충 후 자동 제거를 포함해 3회 이상 연쇄 제거하세요.";
+"achievement.9.title" = "한 수 한 수";
+"achievement.9.desc" = "한 판에서 블록을 제거하는 교환을 5회 연속 수행하세요. 교환 사이 시간 제한은 없습니다.";
+"achievement.10.title" = "1분 준비 운동";
+"achievement.10.desc" = "1분 점수 도전을 300점 이상으로 끝까지 완료하세요.";
+"achievement.11.title" = "2분 집중";
+"achievement.11.desc" = "2분 점수 도전을 600점 이상으로 끝까지 완료하세요.";
+"achievement.12.title" = "3분 순항";
+"achievement.12.desc" = "3분 점수 도전을 900점 이상으로 끝까지 완료하세요.";
+"achievement.13.title" = "첫 결승선";
+"achievement.13.desc" = "300점 스피드런을 완료하세요.";
+"achievement.14.title" = "속도를 높여";
+"achievement.14.desc" = "600점 스피드런을 완료하세요.";
+"achievement.15.title" = "긴 전력 질주";
+"achievement.15.desc" = "900점 스피드런을 완료하세요.";
+"achievement.16.title" = "매초가 소중해";
+"achievement.16.desc" = "300점 스피드런을 60초 이내에 완료하세요.";
+"achievement.17.title" = "백 칸의 시작";
+"achievement.17.desc" = "모든 모드에서 누적 100개 블록을 제거하세요.";
+"achievement.18.title" = "천 칸의 숙련자";
+"achievement.18.desc" = "모든 모드에서 누적 1,000개 블록을 제거하세요.";
+"achievement.19.title" = "만 칸의 여행자";
+"achievement.19.desc" = "모든 모드에서 누적 10,000개 블록을 제거하세요.";
+"achievement.20.title" = "도전 단골";
+"achievement.20.desc" = "점수 도전 또는 스피드런을 총 20판 정상 완료하세요. 0점인 점수 도전은 제외됩니다.";
+"achievement.summary" = "업적 · %d/%d 달성";
+"achievement.view_all" = "전체 보기";
+"achievement.filter.all" = "전체";
+"achievement.filter.locked" = "미달성";
+"achievement.filter.unlocked" = "달성";
+"achievement.category.beginner" = "시작하기";
+"achievement.category.skill" = "조작 기술";
+"achievement.category.mode" = "모드 도전";
+"achievement.category.lifetime" = "누적 기록";
+"achievement.state.locked" = "미달성";
+"achievement.state.unlocked" = "달성";
+"achievement.progress.best" = "최고 기록: %@ / %@";
+"achievement.progress.total" = "누적 진행: %@ / %@";
+"achievement.progress.no_time" = "300점 완주 기록 없음 · 목표 60초 이내";
+"achievement.progress.time" = "최고 시간: %.2f초 · 목표 %.0f초 이내";
+"achievement.date" = "달성 시간: %@";
+"achievement.toast.single" = "✓ 업적 달성: %@ · 보기";
+"achievement.toast.multiple" = "✓ 업적 %d개 달성 · 보기";
+"achievement.empty" = "이 필터에 해당하는 업적이 없습니다";
+"achievement.accessibility.locked" = "%@, 미달성";
+"achievement.accessibility.unlocked" = "%@, 달성";
+"achievement.progress.legacy" = "이전 버전에서 달성했습니다. 과거 진행 기록은 없습니다";
```

### `Sources/Resources/ru.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/ru.lproj/Localizable.strings b/Sources/Resources/ru.lproj/Localizable.strings
index 270b0c4..aa124b3 100644
--- a/Sources/Resources/ru.lproj/Localizable.strings
+++ b/Sources/Resources/ru.lproj/Localizable.strings
@@ -73,3 +73,68 @@
 "rules.short.settlement.free" = "Без победы/поражения и без рейтинга";
 "rules.short.settlement.score_attack" = "Завершение по таймеру, рейтинг по итоговому счёту";
 "rules.short.settlement.speed_run" = "Завершение сразу после цели, рейтинг по времени";
+
+// 成就定义、进度、筛选与解锁反馈。
+"panel.achievements" = "Достижения";
+"achievement.1.title" = "Первые шаги";
+"achievement.1.desc" = "Наберите 100 очков за одну игру в любом режиме.";
+"achievement.2.title" = "Поймать ритм";
+"achievement.2.desc" = "Выполните 3 обмена с очками подряд с интервалом не более 1,6 секунды. Обмен без удаления прерывает серию.";
+"achievement.3.title" = "До самого конца";
+"achievement.3.desc" = "Завершите игру на очки или на скорость с положительным счётом.";
+"achievement.4.title" = "Первая искра";
+"achievement.4.desc" = "Впервые удалите блоки обменом.";
+"achievement.5.title" = "Гармония четырёх";
+"achievement.5.desc" = "Удалите ряд из 4 или более одинаковых блоков за одну волну.";
+"achievement.6.title" = "Резонанс пяти";
+"achievement.6.desc" = "Удалите ряд из 5 или более одинаковых блоков за одну волну.";
+"achievement.7.title" = "Цепная реакция";
+"achievement.7.desc" = "Вызовите одним обменом не менее 2 волн удаления, включая автоматические волны после пополнения.";
+"achievement.8.title" = "Долгое эхо";
+"achievement.8.desc" = "Вызовите одним обменом не менее 3 волн удаления, включая автоматические волны после пополнения.";
+"achievement.9.title" = "Каждый ход в цель";
+"achievement.9.desc" = "Сделайте 5 обменов с удалением подряд за одну игру. Время между обменами не ограничено.";
+"achievement.10.title" = "Минутная разминка";
+"achievement.10.desc" = "Завершите минутную игру на очки, набрав не менее 300 очков.";
+"achievement.11.title" = "Две минуты внимания";
+"achievement.11.desc" = "Завершите двухминутную игру на очки, набрав не менее 600 очков.";
+"achievement.12.title" = "Три минуты полёта";
+"achievement.12.desc" = "Завершите трёхминутную игру на очки, набрав не менее 900 очков.";
+"achievement.13.title" = "Первый финиш";
+"achievement.13.desc" = "Завершите игру на скорость до 300 очков.";
+"achievement.14.title" = "Набирая скорость";
+"achievement.14.desc" = "Завершите игру на скорость до 600 очков.";
+"achievement.15.title" = "Длинный спринт";
+"achievement.15.desc" = "Завершите игру на скорость до 900 очков.";
+"achievement.16.title" = "Каждая секунда важна";
+"achievement.16.desc" = "Завершите игру на скорость до 300 очков за 60 секунд или быстрее.";
+"achievement.17.title" = "Первая сотня";
+"achievement.17.desc" = "Удалите суммарно 100 блоков во всех режимах.";
+"achievement.18.title" = "Тысяча блоков";
+"achievement.18.desc" = "Удалите суммарно 1 000 блоков во всех режимах.";
+"achievement.19.title" = "Десять тысяч блоков";
+"achievement.19.desc" = "Удалите суммарно 10 000 блоков во всех режимах.";
+"achievement.20.title" = "Завсегдатай испытаний";
+"achievement.20.desc" = "Завершите 20 игр на очки или на скорость. Игры на очки с нулевым счётом не учитываются.";
+"achievement.summary" = "Достижения · открыто %d/%d";
+"achievement.view_all" = "Все достижения";
+"achievement.filter.all" = "Все";
+"achievement.filter.locked" = "Закрытые";
+"achievement.filter.unlocked" = "Открытые";
+"achievement.category.beginner" = "Начало";
+"achievement.category.skill" = "Мастерство";
+"achievement.category.mode" = "Испытания режимов";
+"achievement.category.lifetime" = "Общий прогресс";
+"achievement.state.locked" = "Закрыто";
+"achievement.state.unlocked" = "Открыто";
+"achievement.progress.best" = "Личный рекорд: %@ / %@";
+"achievement.progress.total" = "Общий прогресс: %@ / %@";
+"achievement.progress.no_time" = "Нет финиша на 300 очков · Цель ≤ 60 секунд";
+"achievement.progress.time" = "Лучшее время: %.2f с · Цель ≤ %.0f с";
+"achievement.date" = "Открыто: %@";
+"achievement.toast.single" = "✓ Достижение: %@ · Подробнее";
+"achievement.toast.multiple" = "✓ Открыто достижений: %d · Подробнее";
+"achievement.empty" = "Нет достижений по этому фильтру";
+"achievement.accessibility.locked" = "%@, закрыто";
+"achievement.accessibility.unlocked" = "%@, открыто";
+"achievement.progress.legacy" = "Открыто в прежней версии; прошлый прогресс не записывался";
```

### `Sources/Resources/zh-Hans.lproj/Localizable.strings`

```diff
diff --git a/Sources/Resources/zh-Hans.lproj/Localizable.strings b/Sources/Resources/zh-Hans.lproj/Localizable.strings
index 3ec95b9..b7f31e3 100644
--- a/Sources/Resources/zh-Hans.lproj/Localizable.strings
+++ b/Sources/Resources/zh-Hans.lproj/Localizable.strings
@@ -80,7 +80,68 @@
 "rules.short.settlement.score_attack" = "倒计时归零后结算，以最终得分排名";
 "rules.short.settlement.speed_run" = "达到目标分数后立即结算，以用时排名";
 "panel.achievements" = "成就";
-"achievement.unlocked" = "已解锁：成就 %d";
-"achievement.title" = "成就 %d";
-"achievement.desc" = "这是第 %d 项成就的说明。完成条件：示例条件。";
 "action.ok" = "确定";
+
+// 成就定义、进度、筛选与解锁反馈。
+"achievement.1.title" = "小试身手";
+"achievement.1.desc" = "任意模式单局达到 100 分。";
+"achievement.2.title" = "节奏初现";
+"achievement.2.desc" = "连续 3 次交换均得分，相邻间隔不超过 1.6 秒；不消除的交换会中断。";
+"achievement.3.title" = "有始有终";
+"achievement.3.desc" = "正常完成一局有得分的竞分或竞速。";
+"achievement.4.title" = "指尖火花";
+"achievement.4.desc" = "首次通过交换触发消除。";
+"achievement.5.title" = "四格齐鸣";
+"achievement.5.desc" = "一轮消除中出现连续至少 4 个相同方块。";
+"achievement.6.title" = "五格共振";
+"achievement.6.desc" = "一轮消除中出现连续至少 5 个相同方块。";
+"achievement.7.title" = "连锁反应";
+"achievement.7.desc" = "一次交换触发至少 2 轮消除，包含补位后的自动消除。";
+"achievement.8.title" = "余波未平";
+"achievement.8.desc" = "一次交换触发至少 3 轮消除，包含补位后的自动消除。";
+"achievement.9.title" = "步步有解";
+"achievement.9.desc" = "单局连续 5 次交换均产生消除，不限操作间隔。";
+"achievement.10.title" = "一分钟热身";
+"achievement.10.desc" = "自然完成 1 分钟竞分，并达到 300 分。";
+"achievement.11.title" = "两分钟专注";
+"achievement.11.desc" = "自然完成 2 分钟竞分，并达到 600 分。";
+"achievement.12.title" = "三分钟巡航";
+"achievement.12.desc" = "自然完成 3 分钟竞分，并达到 900 分。";
+"achievement.13.title" = "初见终点";
+"achievement.13.desc" = "完成 300 分竞速。";
+"achievement.14.title" = "加速前进";
+"achievement.14.desc" = "完成 600 分竞速。";
+"achievement.15.title" = "长程冲刺";
+"achievement.15.desc" = "完成 900 分竞速。";
+"achievement.16.title" = "分秒必争";
+"achievement.16.desc" = "在 60 秒以内完成 300 分竞速。";
+"achievement.17.title" = "百格起步";
+"achievement.17.desc" = "全部模式累计消除 100 个方块。";
+"achievement.18.title" = "千格熟手";
+"achievement.18.desc" = "全部模式累计消除 1,000 个方块。";
+"achievement.19.title" = "万格旅人";
+"achievement.19.desc" = "全部模式累计消除 10,000 个方块。";
+"achievement.20.title" = "挑战常客";
+"achievement.20.desc" = "正常完成 20 局竞分或竞速；零分竞分不计入。";
+"achievement.summary" = "成就 · 已解锁 %d/%d";
+"achievement.view_all" = "查看全部";
+"achievement.filter.all" = "全部";
+"achievement.filter.locked" = "未解锁";
+"achievement.filter.unlocked" = "已解锁";
+"achievement.category.beginner" = "入门";
+"achievement.category.skill" = "操作技巧";
+"achievement.category.mode" = "模式挑战";
+"achievement.category.lifetime" = "累计里程碑";
+"achievement.state.locked" = "未解锁";
+"achievement.state.unlocked" = "已解锁";
+"achievement.progress.best" = "历史最佳：%@ / %@";
+"achievement.progress.total" = "累计进度：%@ / %@";
+"achievement.progress.no_time" = "尚未完成 300 分竞速 · 目标 ≤ 60 秒";
+"achievement.progress.time" = "最佳用时：%.2f 秒 · 目标 ≤ %.0f 秒";
+"achievement.date" = "解锁时间：%@";
+"achievement.toast.single" = "✓ 成就解锁：%@ · 点击查看";
+"achievement.toast.multiple" = "✓ 解锁 %d 枚成就 · 点击查看";
+"achievement.empty" = "此分类下暂无成就";
+"achievement.accessibility.locked" = "%@，未解锁";
+"achievement.accessibility.unlocked" = "%@，已解锁";
+"achievement.progress.legacy" = "旧版已解锁，历史进度未记录";
```

### `Sources/AchievementViews.swift`（新增）

```diff
diff --git a/Sources/AchievementViews.swift b/Sources/AchievementViews.swift
new file mode 100644
index 0000000..498a5dc
--- /dev/null
+++ b/Sources/AchievementViews.swift
@@ -0,0 +1,325 @@
+import Cocoa
+
+/// 统一生成徽章、详情和图鉴文案，语言切换时无需重建成就定义。
+enum AchievementText {
+    static func string(_ key: String) -> String { Localizer.shared.string(key) }
+    static func format(_ key: String, _ arguments: CVarArg...) -> String {
+        String(format: string(key), locale: Localizer.shared.locale, arguments: arguments)
+    }
+
+    static func title(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
+        // 按钮另外设置系统图标；文本同时包含状态，便于辅助功能读取。
+        return format(manager.isUnlocked(id: definition.id) ? "achievement.accessibility.unlocked" : "achievement.accessibility.locked", string(definition.titleKey))
+    }
+
+    static func progress(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
+        let progress = manager.progress(for: definition)
+        if definition.id <= 3, manager.isUnlocked(id: definition.id), progress.current < progress.target {
+            return string("achievement.progress.legacy")
+        }
+        if progress.isTime {
+            guard manager.hasTimedResult(for: definition) else { return string("achievement.progress.no_time") }
+            return format("achievement.progress.time", progress.current, progress.target)
+        }
+        switch definition.goal {
+        case .firstClear, .speedRun:
+            return string(manager.isUnlocked(id: definition.id) ? "achievement.state.unlocked" : "achievement.state.locked")
+        default:
+            let formatter = NumberFormatter()
+            formatter.locale = Localizer.shared.locale
+            formatter.numberStyle = .decimal
+            formatter.maximumFractionDigits = 0
+            let current = formatter.string(from: NSNumber(value: progress.current)) ?? "0"
+            let target = formatter.string(from: NSNumber(value: progress.target)) ?? "0"
+            let key: String
+            switch definition.goal {
+            case .totalCleared, .completedRounds: key = "achievement.progress.total"
+            default: key = "achievement.progress.best"
+            }
+            return format(key, current, target)
+        }
+    }
+
+    static func status(_ definition: AchievementDefinition, manager: AchievementsManager) -> String {
+        guard manager.isUnlocked(id: definition.id) else { return string("achievement.state.locked") }
+        guard let date = manager.unlockDate(id: definition.id) else { return string("achievement.state.unlocked") }
+        let formatter = DateFormatter()
+        formatter.locale = Localizer.shared.locale
+        formatter.dateStyle = .medium
+        formatter.timeStyle = .short
+        return format("achievement.date", formatter.string(from: date))
+    }
+}
+
+/// 面板不争夺主窗口焦点，点击筛选时仍保留 Touch Bar 的游戏棋盘。
+private final class AchievementPanel: NSPanel {
+    override var canBecomeKey: Bool { false }
+    override var canBecomeMain: Bool { false }
+}
+
+private final class AchievementDocumentView: NSView {
+    override var isFlipped: Bool { true }
+}
+
+final class AchievementsWindowController: NSWindowController {
+    private let manager: AchievementsManager
+    private let filter = NSSegmentedControl()
+    private let heading = NSTextField(labelWithString: "")
+    private let backButton = NSButton()
+    private let list = NSStackView()
+    private let scroll = NSScrollView()
+    private var detailID: Int?
+
+    init(manager: AchievementsManager) {
+        self.manager = manager
+        let panel = AchievementPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 580),
+                                     styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
+                                     backing: .buffered, defer: false)
+        panel.isReleasedWhenClosed = false
+        panel.hidesOnDeactivate = true
+        panel.minSize = NSSize(width: 480, height: 360)
+        super.init(window: panel)
+        buildContent()
+    }
+
+    required init?(coder: NSCoder) { nil }
+
+    func present(from parent: NSWindow?, detailID: Int? = nil) {
+        self.detailID = detailID
+        refresh()
+        window?.contentView?.layoutSubtreeIfNeeded()
+        scroll.contentView.scroll(to: .zero)
+        scroll.reflectScrolledClipView(scroll.contentView)
+        if let parent, let window {
+            parent.addChildWindow(window, ordered: .above)
+            if !window.isVisible {
+                window.setFrameOrigin(NSPoint(x: parent.frame.midX - window.frame.width / 2,
+                                               y: parent.frame.midY - window.frame.height / 2))
+            }
+        }
+        window?.orderFront(nil)
+    }
+
+    func refresh() {
+        window?.title = AchievementText.string("panel.achievements")
+        heading.stringValue = AchievementText.format("achievement.summary", manager.unlockedIDs().count, AchievementDefinition.all.count)
+        backButton.title = AchievementText.string("achievement.view_all")
+        backButton.isHidden = detailID == nil
+        filter.isHidden = detailID != nil
+        for (index, key) in ["all", "locked", "unlocked"].enumerated() {
+            filter.setLabel(AchievementText.string("achievement.filter.\(key)"), forSegment: index)
+        }
+        list.arrangedSubviews.forEach { view in
+            list.removeArrangedSubview(view)
+            view.removeFromSuperview()
+        }
+        let definitions = AchievementDefinition.all.filter { definition in
+            if let detailID { return definition.id == detailID }
+            switch filter.selectedSegment {
+            case 1: return !manager.isUnlocked(id: definition.id)
+            case 2: return manager.isUnlocked(id: definition.id)
+            default: return true
+            }
+        }
+        for category in AchievementCategory.allCases {
+            let group = definitions.filter { $0.category == category }
+            guard !group.isEmpty else { continue }
+            let label = NSTextField(labelWithString: AchievementText.string("achievement.category.\(category.rawValue)"))
+            label.font = .systemFont(ofSize: 13, weight: .bold)
+            label.textColor = .systemRed
+            list.addArrangedSubview(label)
+            for definition in group {
+                let row = makeRow(definition)
+                list.addArrangedSubview(row)
+                row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
+            }
+        }
+        if definitions.isEmpty {
+            list.addArrangedSubview(NSTextField(labelWithString: AchievementText.string("achievement.empty")))
+        }
+    }
+
+    private func buildContent() {
+        guard let content = window?.contentView else { return }
+        heading.font = .systemFont(ofSize: 16, weight: .semibold)
+        filter.segmentCount = 3
+        filter.trackingMode = .selectOne
+        filter.selectedSegment = 0
+        filter.target = self
+        filter.action = #selector(filterChanged)
+        backButton.bezelStyle = .rounded
+        backButton.target = self
+        backButton.action = #selector(showAll)
+        let actions = NSStackView(views: [filter, backButton])
+        actions.orientation = .horizontal
+        let toolbar = NSStackView(views: [heading, actions])
+        toolbar.orientation = .vertical
+        toolbar.alignment = .leading
+        toolbar.spacing = 8
+        toolbar.translatesAutoresizingMaskIntoConstraints = false
+        content.addSubview(toolbar)
+
+        scroll.translatesAutoresizingMaskIntoConstraints = false
+        scroll.hasVerticalScroller = true
+        scroll.autohidesScrollers = true
+        scroll.drawsBackground = false
+        content.addSubview(scroll)
+        let document = AchievementDocumentView()
+        document.translatesAutoresizingMaskIntoConstraints = false
+        scroll.documentView = document
+        list.orientation = .vertical
+        list.alignment = .leading
+        list.spacing = 12
+        list.translatesAutoresizingMaskIntoConstraints = false
+        document.addSubview(list)
+        NSLayoutConstraint.activate([
+            toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
+            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
+            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
+            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 14),
+            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
+            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
+            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
+            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
+            list.topAnchor.constraint(equalTo: document.topAnchor, constant: 16),
+            list.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
+            list.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
+            list.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
+        ])
+    }
+
+    private func makeRow(_ definition: AchievementDefinition) -> NSView {
+        let unlocked = manager.isUnlocked(id: definition.id)
+        let row = NSView()
+        row.wantsLayer = true
+        row.layer?.cornerRadius = 8
+        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
+        row.layer?.borderWidth = 1
+        row.layer?.borderColor = (unlocked ? NSColor.systemGreen : NSColor.separatorColor).cgColor
+        row.translatesAutoresizingMaskIntoConstraints = false
+        let name = NSTextField(wrappingLabelWithString: AchievementText.string(definition.titleKey))
+        name.font = .systemFont(ofSize: 14, weight: .semibold)
+        name.setAccessibilityLabel(AchievementText.title(definition, manager: manager))
+        let icon = NSImageView(image: NSImage(systemSymbolName: unlocked ? "checkmark.seal.fill" : "lock.fill", accessibilityDescription: nil) ?? NSImage())
+        icon.contentTintColor = unlocked ? .systemGreen : .secondaryLabelColor
+        icon.translatesAutoresizingMaskIntoConstraints = false
+        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
+        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
+        let titleRow = NSStackView(views: [icon, name])
+        titleRow.orientation = .horizontal
+        titleRow.spacing = 6
+        let condition = NSTextField(wrappingLabelWithString: AchievementText.string(definition.descriptionKey))
+        condition.textColor = .secondaryLabelColor
+        let progress = NSTextField(wrappingLabelWithString: AchievementText.progress(definition, manager: manager))
+        let status = NSTextField(wrappingLabelWithString: AchievementText.status(definition, manager: manager))
+        status.font = .systemFont(ofSize: 11)
+        status.textColor = unlocked ? .systemGreen : .secondaryLabelColor
+        let meter = NSProgressIndicator()
+        meter.style = .bar
+        meter.isIndeterminate = false
+        meter.minValue = 0
+        meter.maxValue = 1
+        meter.doubleValue = unlocked ? 1 : manager.progress(for: definition).fraction
+        meter.setAccessibilityLabel(progress.stringValue)
+        let stack = NSStackView(views: [titleRow, condition, progress, meter, status])
+        stack.orientation = .vertical
+        stack.alignment = .leading
+        stack.spacing = 7
+        stack.translatesAutoresizingMaskIntoConstraints = false
+        row.addSubview(stack)
+        for view in stack.arrangedSubviews {
+            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
+            view.setContentCompressionResistancePriority(.required, for: .vertical)
+        }
+        NSLayoutConstraint.activate([
+            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
+            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
+            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
+            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
+        ])
+        return row
+    }
+
+    @objc private func filterChanged() { refresh() }
+    @objc private func showAll() { detailID = nil; refresh() }
+}
+
+/// 提示是窗口内可点击按钮，显示三秒，不创建 modal 或替换 Touch Bar。
+final class AchievementToastPresenter: NSObject {
+    private weak var host: NSView?
+    private let onSelect: ([Int]) -> Void
+    private var queue = AchievementUnlockQueue()
+    private var button: NSButton?
+    private var activeIDs: [Int] = []
+    private var dismissWork: DispatchWorkItem?
+    private var isScheduled = false
+
+    init(host: NSView, onSelect: @escaping ([Int]) -> Void) {
+        self.host = host
+        self.onSelect = onSelect
+    }
+
+    deinit { dismissWork?.cancel() }
+
+    func enqueue(_ ids: [Int]) {
+        queue.enqueue(ids)
+        guard button == nil, !isScheduled else { return }
+        isScheduled = true
+        // 合并同一事件循环中的交换与结算解锁，再决定是否批量提示。
+        DispatchQueue.main.async { [weak self] in
+            self?.isScheduled = false
+            self?.showNext()
+        }
+    }
+
+    func refreshLanguage() {
+        guard let button else { return }
+        button.title = message(for: activeIDs)
+    }
+
+    private func message(for ids: [Int]) -> String {
+        if ids.count == 1, let definition = AchievementDefinition.all.first(where: { $0.id == ids[0] }) {
+            return AchievementText.format("achievement.toast.single", AchievementText.string(definition.titleKey))
+        }
+        return AchievementText.format("achievement.toast.multiple", ids.count)
+    }
+
+    private func showNext() {
+        guard button == nil, let host else { return }
+        activeIDs = queue.next()
+        guard !activeIDs.isEmpty else { return }
+        let toast = NSButton(title: message(for: activeIDs), target: self, action: #selector(selected))
+        toast.bezelStyle = .rounded
+        toast.font = .systemFont(ofSize: 12, weight: .semibold)
+        toast.contentTintColor = .systemGreen
+        toast.wantsLayer = true
+        toast.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
+        toast.layer?.cornerRadius = 8
+        toast.translatesAutoresizingMaskIntoConstraints = false
+        host.addSubview(toast)
+        NSLayoutConstraint.activate([
+            toast.centerXAnchor.constraint(equalTo: host.centerXAnchor),
+            toast.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -12),
+            toast.widthAnchor.constraint(lessThanOrEqualTo: host.widthAnchor, constant: -24),
+            toast.heightAnchor.constraint(equalToConstant: 42)
+        ])
+        button = toast
+        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
+        dismissWork = work
+        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
+    }
+
+    private func dismiss() {
+        dismissWork?.cancel()
+        dismissWork = nil
+        button?.removeFromSuperview()
+        button = nil
+        activeIDs = []
+        showNext()
+    }
+
+    @objc private func selected() {
+        onSelect(activeIDs)
+        dismiss()
+    }
+}
```

### `Tests/AchievementLocalizationTests.swift`（新增）

```diff
diff --git a/Tests/AchievementLocalizationTests.swift b/Tests/AchievementLocalizationTests.swift
new file mode 100644
index 0000000..39fb4f9
--- /dev/null
+++ b/Tests/AchievementLocalizationTests.swift
@@ -0,0 +1,33 @@
+import XCTest
+@testable import EliminateTeris1
+
+final class AchievementLocalizationTests: XCTestCase {
+    func testFiveLanguagesHaveCompleteKeysAndMatchingFormatArguments() throws {
+        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
+        var tables: [String: [String: String]] = [:]
+        let formatPattern = try NSRegularExpression(pattern: "%[0-9.]*[@df]")
+        for language in AppLanguage.allCases {
+            let url = root.appendingPathComponent("Sources/Resources/\(language.rawValue).lproj/Localizable.strings")
+            let data = try Data(contentsOf: url)
+            let table = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
+            tables[language.rawValue] = table
+            for definition in AchievementDefinition.all {
+                XCTAssertNotNil(table[definition.titleKey], "\(language.rawValue): \(definition.titleKey)")
+                XCTAssertNotNil(table[definition.descriptionKey])
+            }
+        }
+        let english = try XCTUnwrap(tables["en"])
+        let keys = english.keys.filter { $0.hasPrefix("achievement.") }
+        for table in tables.values {
+            for key in keys {
+                let value = try XCTUnwrap(table[key], key)
+                func arguments(_ text: String) -> [String] {
+                    formatPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
+                        String(text[Range($0.range, in: text)!])
+                    }
+                }
+                XCTAssertEqual(arguments(value), arguments(english[key]!), key)
+            }
+        }
+    }
+}
```

### `Tests/AchievementPresentationTests.swift`（新增）

```diff
diff --git a/Tests/AchievementPresentationTests.swift b/Tests/AchievementPresentationTests.swift
new file mode 100644
index 0000000..5d5f2a6
--- /dev/null
+++ b/Tests/AchievementPresentationTests.swift
@@ -0,0 +1,58 @@
+import Cocoa
+import XCTest
+@testable import EliminateTeris1
+
+final class AchievementPresentationTests: AchievementTestCase {
+    private func descendants(_ view: NSView) -> [NSView] {
+        [view] + view.subviews.flatMap(descendants)
+    }
+
+    func testLibraryFiltersAndPanelDoesNotTakeKeyboardFocus() throws {
+        XCTAssertTrue(Thread.isMainThread)
+        _ = NSApplication.shared
+        swap()
+        let panel = AchievementsWindowController(manager: manager)
+        defer { panel.close() }
+        panel.refresh()
+        let window = try XCTUnwrap(panel.window)
+        XCTAssertFalse(window.canBecomeKey)
+        XCTAssertFalse(window.canBecomeMain)
+        let content = try XCTUnwrap(window.contentView)
+        let filter = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
+        func progressBars() -> Int { descendants(content).filter { $0 is NSProgressIndicator }.count }
+        XCTAssertEqual(progressBars(), 20)
+        filter.selectedSegment = 2
+        XCTAssertTrue(filter.sendAction(filter.action, to: filter.target))
+        XCTAssertEqual(progressBars(), 1)
+        filter.selectedSegment = 1
+        filter.sendAction(filter.action, to: filter.target)
+        XCTAssertEqual(progressBars(), 19)
+    }
+
+    func testLibraryRowsHaveUsableLayoutForEveryLanguage() throws {
+        _ = NSApplication.shared
+        let original = Localizer.shared.language
+        defer { Localizer.shared.setLanguage(original) }
+        let panel = AchievementsWindowController(manager: manager)
+        defer { panel.close() }
+        let window = try XCTUnwrap(panel.window)
+        let content = try XCTUnwrap(window.contentView)
+        for language in AppLanguage.allCases {
+            Localizer.shared.setLanguage(language)
+            XCTAssertNotEqual(Localizer.shared.string("achievement.1.title"), "achievement.1.title")
+            panel.refresh()
+            for width: CGFloat in [480, 600] {
+                window.setContentSize(NSSize(width: width, height: 580))
+                content.layoutSubtreeIfNeeded()
+                let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }.first)
+                let document = try XCTUnwrap(scroll.documentView)
+                document.layoutSubtreeIfNeeded()
+                XCTAssertGreaterThan(document.frame.height, scroll.contentView.bounds.height)
+                for meter in descendants(document).compactMap({ $0 as? NSProgressIndicator }) {
+                    XCTAssertGreaterThan(meter.frame.width, 300, language.rawValue)
+                    XCTAssertGreaterThan(meter.frame.height, 0)
+                }
+            }
+        }
+    }
+}
```

### `Tests/AchievementsTests.swift`（新增）

```diff
diff --git a/Tests/AchievementsTests.swift b/Tests/AchievementsTests.swift
new file mode 100644
index 0000000..9ccdfec
--- /dev/null
+++ b/Tests/AchievementsTests.swift
@@ -0,0 +1,225 @@
+import XCTest
+@testable import EliminateTeris1
+
+/// 每条用例使用独立存储域，不读取或修改玩家的真实成就。
+class AchievementTestCase: XCTestCase {
+    var defaults: UserDefaults!
+    var suite: String!
+    var manager: AchievementsManager!
+    var round: UUID!
+    let date = Date(timeIntervalSince1970: 1_000_000)
+
+    override func setUp() {
+        super.setUp()
+        suite = "EliminateTeris1Tests.\(UUID().uuidString)"
+        defaults = UserDefaults(suiteName: suite)!
+        manager = AchievementsManager(defaults: defaults)
+        round = UUID()
+        manager.beginRound(id: round)
+    }
+
+    override func tearDown() {
+        manager = nil
+        defaults.removePersistentDomain(forName: suite)
+        defaults = nil
+        super.tearDown()
+    }
+
+    func progress(_ id: Int) -> Double {
+        manager.progress(for: AchievementDefinition.all.first { $0.id == id }!).current
+    }
+
+    func swap(at seconds: Double = 0, count: Int = 3, waves: Int = 1, longest: Int = 3, score: Int = 30, id: UUID = UUID()) {
+        manager.recordSwap(roundID: round, swapID: id,
+                           result: SwapResolution(isValidSwap: true, clearedCount: count, cascadeCount: waves, longestRun: longest),
+                           score: score, at: date.addingTimeInterval(seconds))
+    }
+
+    func newRound() {
+        round = UUID()
+        manager.beginRound(id: round)
+    }
+}
+
+final class AchievementsTests: AchievementTestCase {
+    func testAllDefinitionsHaveStableIDs() {
+        XCTAssertEqual(AchievementDefinition.all.map(\.id), Array(1...20))
+        XCTAssertEqual(AchievementCategory.allCases.map { c in AchievementDefinition.all.filter { $0.category == c }.count }, [4, 5, 7, 4])
+    }
+
+    func testOneSwapUnlocksEveryReachedMilestoneAndPersistsBeforeNotification() {
+        var batches: [[Int]] = []
+        let observer = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: nil, queue: nil) { [self] note in
+            guard note.object as? AchievementsManager === manager else { return }
+            let ids = note.userInfo?["ids"] as! [Int]
+            batches.append(ids)
+            let reloaded = AchievementsManager(defaults: defaults)
+            XCTAssertTrue(ids.allSatisfy { reloaded.isUnlocked(id: $0) })
+        }
+        defer { NotificationCenter.default.removeObserver(observer) }
+        swap(count: 10_000, waves: 3, longest: 5, score: 100_000)
+        XCTAssertEqual(batches, [[1, 4, 5, 6, 7, 8, 17, 18, 19]])
+        XCTAssertEqual(manager.unlockDate(id: 19), date)
+        swap(at: 1)
+        XCTAssertEqual(batches.count, 1)
+    }
+
+    func testDuplicateAndInvalidSwapEventsDoNotCount() {
+        let id = UUID()
+        swap(id: id)
+        swap(id: id)
+        manager.recordSwap(roundID: UUID(), swapID: UUID(), result: .invalid, score: 1000, at: date)
+        manager.recordSwap(roundID: round, swapID: UUID(), result: .invalid, score: 1000, at: date)
+        XCTAssertEqual(progress(17), 3)
+        XCTAssertFalse(manager.isUnlocked(id: 1))
+    }
+
+    func testRhythmIncludesExactBoundary() {
+        swap()
+        swap(at: 1.6)
+        swap(at: 3.2)
+        XCTAssertTrue(manager.isUnlocked(id: 2))
+    }
+
+    func testRhythmExpiresWhileSuccessfulSwapStreakHasNoTimeout() {
+        for i in 0..<5 { swap(at: Double(i) * 1.601) }
+        XCTAssertFalse(manager.isUnlocked(id: 2))
+        XCTAssertTrue(manager.isUnlocked(id: 9))
+    }
+
+    func testNonClearingSwapBreaksBothStreaks() {
+        swap()
+        swap(at: 0.1)
+        swap(at: 0.2, count: 0, waves: 0, longest: 0)
+        swap(at: 0.3)
+        swap(at: 0.4)
+        XCTAssertFalse(manager.isUnlocked(id: 2))
+        XCTAssertEqual(progress(9), 2)
+    }
+
+    func testRestartClearsStreakButRetainsLifetimeProgress() {
+        swap()
+        swap(at: 0.1)
+        newRound()
+        swap(at: 0.2)
+        swap(at: 0.3)
+        XCTAssertFalse(manager.isUnlocked(id: 2))
+        XCTAssertEqual(progress(17), 12)
+        XCTAssertEqual(progress(9), 2)
+    }
+
+    func testFinishIsIdempotentAndDoesNotRequireRankingEntry() {
+        // 排行、seed 和是否进入前九名都不是成就事件的输入。
+        defaults.set(["seed": true], forKey: "mode_records_v1")
+        for _ in 0..<20 {
+            newRound()
+            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 60, at: date)
+            manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 30, elapsed: 61, at: date)
+        }
+        XCTAssertEqual(progress(20), 20)
+        XCTAssertTrue(manager.isUnlocked(id: 20))
+    }
+
+    func testZeroScoreAndPrematureFinishesDoNotCount() {
+        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 59.99, at: date)
+        XCTAssertEqual(progress(20), 0)
+        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 0, elapsed: 60, at: date)
+        manager.finishRound(id: round, mode: .scoreAttack(duration: 60), score: 300, elapsed: 61, at: date)
+        XCTAssertEqual(progress(20), 0)
+        newRound()
+        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 290, elapsed: 10, at: date)
+        manager.finishRound(id: round, mode: .free, score: 1000, elapsed: 100, at: date)
+        XCTAssertEqual(progress(20), 0)
+    }
+
+    func testEachScoreAttackTierRequiresItsOwnFinishedRound() {
+        for (minutes, id) in [(1, 10), (2, 11), (3, 12)] {
+            newRound()
+            swap(score: minutes * 300)
+            XCTAssertFalse(manager.isUnlocked(id: id))
+            manager.finishRound(id: round, mode: .scoreAttack(duration: Double(minutes * 60)), score: minutes * 300, elapsed: Double(minutes * 60), at: date)
+            XCTAssertTrue(manager.isUnlocked(id: id))
+        }
+    }
+
+    func testSpeedRunTiersAndSixtySecondBoundary() {
+        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 60.001, at: date)
+        XCTAssertTrue(manager.isUnlocked(id: 13))
+        XCTAssertFalse(manager.isUnlocked(id: 16))
+        newRound()
+        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 330, elapsed: 60, at: date)
+        XCTAssertTrue(manager.isUnlocked(id: 16))
+        for (target, id) in [(600, 14), (900, 15)] {
+            newRound()
+            manager.finishRound(id: round, mode: .speedRun(targetScore: target), score: target, elapsed: 90, at: date)
+            XCTAssertTrue(manager.isUnlocked(id: id))
+        }
+        let best = AchievementDefinition.all.first { $0.id == 16 }!
+        XCTAssertEqual(manager.progress(for: best).current, 60)
+    }
+
+    func testReloadRetainsMetricsAndTimeButStartsNewStreak() {
+        swap()
+        swap(at: 0.1)
+        let unlockDate = manager.unlockDate(id: 4)
+        manager = AchievementsManager(defaults: defaults)
+        manager.beginRound(id: round)
+        swap(at: 0.2)
+        XCTAssertFalse(manager.isUnlocked(id: 2))
+        XCTAssertEqual(progress(17), 9)
+        XCTAssertEqual(manager.unlockDate(id: 4), unlockDate)
+    }
+
+    func testOnlyLegacyOneToThreeMigrateAndMigrationIsOneTime() {
+        defaults.removeObject(forKey: AchievementsManager.storageKey)
+        defaults.set([1, 2, 3, 4, 20], forKey: "AchievementsManager.unlockedIds")
+        defaults.set(["1": date.timeIntervalSince1970, "4": date.timeIntervalSince1970], forKey: "AchievementsManager.unlockTimestamps")
+        manager = AchievementsManager(defaults: defaults)
+        XCTAssertEqual(manager.unlockedIDs(), [1, 2, 3])
+        XCTAssertEqual(manager.unlockDate(id: 1), date)
+        XCTAssertEqual(progress(17), 0)
+        defaults.set([], forKey: "AchievementsManager.unlockedIds")
+        manager = AchievementsManager(defaults: defaults)
+        XCTAssertEqual(manager.unlockedIDs(), [1, 2, 3])
+    }
+
+    func testDamagedFieldsPreserveReadableMetrics() {
+        defaults.set(["unlocked": [1, 99], "metrics": ["totalCleared": 99, "bestScore": "broken", "rhythm": -1, "cascades": true], "timestamps": "broken"], forKey: AchievementsManager.storageKey)
+        manager = AchievementsManager(defaults: defaults)
+        manager.beginRound(id: round)
+        XCTAssertEqual(manager.unlockedIDs(), [1])
+        XCTAssertEqual(progress(17), 99)
+        XCTAssertEqual(progress(8), 0)
+        swap()
+        XCTAssertTrue(manager.isUnlocked(id: 17))
+    }
+
+    func testUnlockQueueOrdersDeduplicatesAndCombinesLargeBatches() {
+        var queue = AchievementUnlockQueue()
+        queue.enqueue([8, 1, 3, 3])
+        XCTAssertEqual(queue.next(), [1])
+        XCTAssertEqual(queue.next(), [3])
+        XCTAssertEqual(queue.next(), [8])
+        XCTAssertEqual(queue.next(), [])
+        queue.enqueue([9, 2])
+        queue.enqueue([6, 4, 2])
+        XCTAssertEqual(queue.next(), [2, 4, 6, 9])
+    }
+
+    func testObjectFilteredNotificationReachesTheInterface() {
+        var received = false
+        let observer = NotificationCenter.default.addObserver(forName: AchievementsManager.didUnlockNotification, object: manager, queue: .main) { _ in received = true }
+        defer { NotificationCenter.default.removeObserver(observer) }
+        swap()
+        XCTAssertTrue(received)
+    }
+
+    func testZeroSecondSpeedRunIsDistinguishedFromMissingResult() {
+        manager.finishRound(id: round, mode: .speedRun(targetScore: 300), score: 300, elapsed: 0, at: date)
+        XCTAssertTrue(manager.isUnlocked(id: 16))
+        manager = AchievementsManager(defaults: defaults)
+        let definition = AchievementDefinition.all.first { $0.id == 16 }!
+        XCTAssertTrue(manager.hasTimedResult(for: definition))
+        XCTAssertEqual(manager.progress(for: definition).current, 0)
+    }
+}
```

### `Tests/GameBoardControllerTests.swift`（新增）

```diff
diff --git a/Tests/GameBoardControllerTests.swift b/Tests/GameBoardControllerTests.swift
new file mode 100644
index 0000000..6628fc8
--- /dev/null
+++ b/Tests/GameBoardControllerTests.swift
@@ -0,0 +1,69 @@
+import XCTest
+@testable import EliminateTeris1
+
+final class GameBoardControllerTests: AchievementTestCase {
+    func testLastSwapIsRecordedBeforeFinishAndRepeatedSnapshotsDoNotCount() {
+        var now = date
+        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
+        let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+        let controller = GameBoardController(columns: 4, achievements: manager, now: { now }) { _ in
+            var index = 0
+            let refill = [b, b, b, c, c, c, d, a, b, a]
+            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
+                defer { index += 1 }
+                return refill[index]
+            }
+        }
+        controller.configure(mode: .speedRun(targetScore: 100))
+        controller.startRound()
+        now = date.addingTimeInterval(2)
+        controller.performSwap(from: 2, to: 3)
+        XCTAssertTrue(manager.isUnlocked(id: 1))
+        XCTAssertTrue(manager.isUnlocked(id: 3))
+        XCTAssertTrue(manager.isUnlocked(id: 8))
+        for _ in 0..<10 { _ = controller.snapshot(); controller.tick() }
+        XCTAssertEqual(progress(20), 1)
+        XCTAssertEqual(progress(17), 10)
+        controller.performSwap(from: 0, to: 1)
+        XCTAssertEqual(progress(17), 10)
+    }
+
+    func testRestartAndModeChangeDoNotFinishAbandonedRounds() {
+        let controller = GameBoardController(columns: 4, achievements: manager, now: { self.date })
+        controller.configure(mode: .scoreAttack(duration: 60))
+        controller.startRound()
+        controller.startRound()
+        controller.configure(mode: .free)
+        XCTAssertEqual(progress(20), 0)
+        XCTAssertFalse(manager.isUnlocked(id: 3))
+    }
+
+    func testExpirationRefusesLateSwapAndZeroScoreDoesNotCount() {
+        var now = date
+        let controller = GameBoardController(columns: 4, achievements: manager, now: { now })
+        controller.configure(mode: .scoreAttack(duration: 60))
+        controller.startRound()
+        let original = controller.tiles()
+        now = date.addingTimeInterval(60)
+        controller.performSwap(from: 0, to: 1)
+        XCTAssertEqual(controller.tiles(), original)
+        XCTAssertTrue(controller.snapshot().isFinished)
+        XCTAssertEqual(progress(20), 0)
+        XCTAssertEqual(progress(17), 0)
+    }
+
+    func testFreeModeTracksClearsWithoutCompletedRounds() {
+        let a = PieceKind.orangeRicky, b = PieceKind.blueRicky
+        let c = PieceKind.clevelandZ, d = PieceKind.rhodeIslandZ
+        let controller = GameBoardController(columns: 4, achievements: manager, stateFactory: { _ in
+            var index = 0
+            return GameState(columns: 4, initialKinds: [a, a, b, a]) {
+                defer { index += 1 }
+                return [c, d, c][index]
+            }
+        })
+        controller.performSwap(from: 2, to: 3)
+        XCTAssertTrue(manager.isUnlocked(id: 4))
+        XCTAssertEqual(progress(20), 0)
+    }
+}
```

### `Tests/GameStateTests.swift`（新增）

```diff
diff --git a/Tests/GameStateTests.swift b/Tests/GameStateTests.swift
new file mode 100644
index 0000000..20fa39a
--- /dev/null
+++ b/Tests/GameStateTests.swift
@@ -0,0 +1,61 @@
+import XCTest
+@testable import EliminateTeris1
+
+final class GameStateTests: XCTestCase {
+    private let a = PieceKind.orangeRicky
+    private let b = PieceKind.blueRicky
+    private let c = PieceKind.clevelandZ
+    private let d = PieceKind.rhodeIslandZ
+
+    func state(_ board: [PieceKind], refill: [PieceKind]) -> GameState {
+        var index = 0
+        return GameState(columns: board.count, initialKinds: board) {
+            XCTAssertLessThan(index, refill.count, "补位次数超出预期，可能出现额外连消")
+            defer { index += 1 }
+            return refill[index % refill.count]
+        }
+    }
+
+    func testSingleTripleAndScore() {
+        let game = state([a, a, b, a], refill: [c, d, c])
+        XCTAssertTrue(game.swapAndResolve(2, 3))
+        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 3, cascadeCount: 1, longestRun: 3))
+        XCTAssertEqual(game.score, 30)
+        XCTAssertEqual(game.tiles.map(\.kind), [c, d, c, b])
+    }
+
+    func testTwoTriplesInSameWaveAreNotFourOrFiveInARow() {
+        let game = state([b, b, a, b, a, a, c, d], refill: [a, b, c, d, a, b])
+        XCTAssertTrue(game.swapAndResolve(2, 3))
+        XCTAssertEqual(game.lastResolution.clearedCount, 6)
+        XCTAssertEqual(game.lastResolution.cascadeCount, 1)
+        XCTAssertEqual(game.lastResolution.longestRun, 3)
+    }
+
+    func testRefillCanMakeFiveInARow() {
+        let game = state([c, c, a, a, b, a], refill: [c, c, c, a, b, c, d, a])
+        XCTAssertTrue(game.swapAndResolve(4, 5))
+        XCTAssertEqual(game.lastResolution.clearedCount, 8)
+        XCTAssertEqual(game.lastResolution.cascadeCount, 2)
+        XCTAssertEqual(game.lastResolution.longestRun, 5)
+        XCTAssertEqual(game.score, 80)
+    }
+
+    func testThreeCascadesIncludeTheInitialWave() {
+        let game = state([a, a, b, a], refill: [b, b, b, c, c, c, d, a, b, a])
+        XCTAssertTrue(game.swapAndResolve(2, 3))
+        XCTAssertEqual(game.lastResolution, SwapResolution(isValidSwap: true, clearedCount: 10, cascadeCount: 3, longestRun: 4))
+        XCTAssertEqual(game.score, 100)
+    }
+
+    func testNonClearingSwapRemainsOnBoardWhileAttemptSwapRollsBack() {
+        let game = state([a, b, c, d], refill: [a])
+        XCTAssertFalse(game.swapAndResolve(0, 1))
+        XCTAssertTrue(game.lastResolution.isValidSwap)
+        XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
+        XCTAssertFalse(game.attemptSwap(0, 1))
+        XCTAssertEqual(game.tiles.map(\.kind), [b, a, c, d])
+        XCTAssertFalse(game.swapAndResolve(-1, 0))
+        XCTAssertEqual(game.lastResolution, .invalid)
+    }
+}
```
