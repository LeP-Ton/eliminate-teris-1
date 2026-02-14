# 挑战记录对齐修复与测试 seed 分布调整

## 背景与目标
- 用户反馈：
  1. 序号 Tag 与同行文字仍未中线对齐，要求可直接下移 4px。
  2. 测试数据需要支持“满 9 条”以及“0~1 条”的模式场景，便于验证空态与极少条目场景。

## 约束与原则
- 维持挑战记录面板现有交互与滚动行为。
- 不改动业务玩法规则，仅调整展示对齐和测试 seed 生成策略。
- 保持历史数据兼容，seed 版本升级后可应用新分布。

## 阶段与 TODO
- [x] 序号 Tag 直接下移 4px。
- [x] 将 seed 版本升级并更新 seed 记录分布。
- [x] 保持每分桶上限为 9 条。
- [x] 增加 seed 分桶替换逻辑，保证老 seed 可更新到新策略。
- [x] 编译验证通过。

## 关键风险
- 序号 Tag 下移为固定像素值，在不同系统字体渲染下仍可能有轻微视觉偏差。
- 如果某分桶已有真实玩家记录（非 seed），不会被 seed 强制覆盖，属于保护用户数据的预期行为。

## 当前进展
- 序号 Tag 已按要求下移 4px。
- seed 记录分布已改为“9条 + 0/1条混合”。
- 构建通过：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`。

## git记录
- branch：main
- commit：待提交（本次对话自动提交）

## 代码变更
- AGENTS.md
```diff
@@ -4,3 +4,8 @@
 - 项目通过 `run.sh` 启动可执行程序，当前策略已改为“每次启动前强制重新编译”，避免启动到旧构建产物。
 - `run.sh` 会优先使用 `/Applications/Xcode.app/Contents/Developer` 作为 `DEVELOPER_DIR`（若用户未手动设置）。
 - 启动路径通过 `swift build --show-bin-path` 计算，避免手写架构目录导致路径偏差。
+- 挑战记录标题区域已去掉模式/细分 Tag，仅保留标题文本，减少头部视觉干扰。
+- 模式记录每个分桶的最大条数调整为 9，初始化时会对历史数据做排序与截断归一化。
+- 挑战记录行内序号 Tag 通过 `baselineOffset` 与附件 bounds 微调，实现与分数/日期文本的中线对齐。
+- 序号 Tag 当前按视觉反馈下移 4px（`attachment.bounds.y = -4`）以贴齐同一行文本。
+- 测试 seed 数据采用“9条 + 0/1条混合”策略：竞分 1分钟=9、2分钟=1、3分钟=0；竞速 300分=9、600分=1、900分=0。
```

- Sources/GameViewController.swift
```diff
@@ -985,7 +955,8 @@
         let attachment = NSTextAttachment()
         let image = rankTagImage(rank: rank)
         attachment.image = image
-        attachment.bounds = NSRect(x: 0, y: -1, width: image.size.width, height: image.size.height)
+        // 根据视觉反馈，将序号 Tag 整体向下平移 4px，避免与同行文本中线错位。
+        attachment.bounds = NSRect(x: 0, y: -4, width: image.size.width, height: image.size.height)
         return NSAttributedString(attachment: attachment)
     }
```

- Sources/ModeRecordStore.swift
```diff
@@ -23,8 +23,8 @@
     private let storageKey = "mode_records_v1"
     private let seedVersionKey = "mode_records_seed_version"
-    private let seedVersion = 4
+    private let seedVersion = 5
     private let maxRecordsPerScope = 9
@@ -127,6 +130,15 @@
     private func ensureSeedRecords(for mode: ModeRecordKey, detailValue: Int, seeds: [ModeRecord]) {
         let scopeID = Self.scopeID(mode: mode, detailValue: detailValue)
         var bucket = recordsByScope[scopeID] ?? []
+
+        // 仅包含 seed 的旧分桶直接替换，确保 seed 策略升级后可生效。
+        if bucket.isEmpty || bucket.allSatisfy({ Self.isSeedRecordID($0.id) }) {
+            bucket = seeds
+            sortAndTrim(&bucket, for: mode)
+            recordsByScope[scopeID] = bucket
+            return
+        }
@@ -141,8 +153,9 @@
     private func makeScoreAttackSeedRecords(durationMinutes: Int) -> [ModeRecord] {
         let baseTime = Date().addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970 + Double(durationMinutes * 100)
         let baseScore = 420 - durationMinutes * 12
+        let seedCount = seedRecordCount(for: .scoreAttack, detailValue: durationMinutes)
 
-        return (0..<maxRecordsPerScope).map { rank in
+        return (0..<seedCount).map { rank in
@@ -162,8 +175,9 @@
         ]
         let baseElapsed = baseElapsedByTarget[targetScore] ?? max(45, targetScore / 6)
         let baseTime = Date().addingTimeInterval(-6 * 24 * 60 * 60).timeIntervalSince1970 + Double(targetScore)
+        let seedCount = seedRecordCount(for: .speedRun, detailValue: targetScore)
 
-        return (0..<maxRecordsPerScope).map { rank in
+        return (0..<seedCount).map { rank in
@@ -175,6 +189,38 @@
         }
     }
+
+    private func seedRecordCount(for mode: ModeRecordKey, detailValue: Int) -> Int {
+        switch mode {
+        case .scoreAttack:
+            switch detailValue {
+            case 1:
+                return maxRecordsPerScope
+            case 2:
+                return 1
+            case 3:
+                return 0
+            default:
+                return maxRecordsPerScope
+            }
+
+        case .speedRun:
+            switch detailValue {
+            case 300:
+                return maxRecordsPerScope
+            case 600:
+                return 1
+            case 900:
+                return 0
+            default:
+                return maxRecordsPerScope
+            }
+        }
+    }
+
+    private static func isSeedRecordID(_ id: String) -> Bool {
+        return id.hasPrefix("seed_score_attack_") || id.hasPrefix("seed_speed_run_")
+    }
```

## 测试用例
### TC-001 序号 Tag 下移生效
- 类型：UI测试
- 前置条件：挑战记录至少 1 条
- 操作步骤：观察序号 Tag 与同一行分数/日期
- 预期结果：序号 Tag 相比上一版整体下移，视觉上更贴合中线

### TC-002 seed 分布验证（9条与 0/1 条）
- 类型：功能测试
- 前置条件：首次启动或 seed 版本更新后
- 操作步骤：切换不同细分模式查看挑战记录
- 预期结果：
  - 竞分 1分钟/竞速 300分：可见 9 条 seed
  - 竞分 2分钟/竞速 600分：可见 1 条 seed
  - 竞分 3分钟/竞速 900分：可见 0 条 seed（空态）

### TC-003 编译验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
