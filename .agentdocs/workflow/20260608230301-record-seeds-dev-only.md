# 挑战记录测试数据改为仅开发模式注入

## 背景与目标
- 当前竞分模式与竞速模式的挑战记录仍会自动注入测试 seed 数据，用于验证 0/1/9 条记录等边界展示。
- 这些 seed 在开发阶段有价值，但不应该出现在正式体验或打包版本中。
- 本次目标是将测试数据改为“仅开发模式注入”，并在非开发模式启动时自动清理旧 seed。

## 约束与原则
- 保留现有 seed 分布策略（竞分 1/2/3 分钟与竞速 300/600/900 分的 9/1/0 测试分布），但只在开发模式启用。
- 不改变真实挑战记录的排序、上限与保存方式。
- 最小改动：核心逻辑集中在 `Sources/ModeRecordStore.swift`，并通过 `run.sh` 显式声明开发模式。

## 阶段与 TODO
- [x] 为记录 seed 增加“开发模式”判定。
- [x] 将 seed 注入从“默认注入”改为“仅开发模式注入”。
- [x] 在非开发模式启动时清理旧 seed，防止历史调试数据残留。
- [x] 让 `run.sh` 显式导出开发模式环境变量。
- [x] 重新编译验证项目可通过构建。

## 关键风险
- 如果只关闭新 seed 注入，而不清理旧 seed，那么本机历史调试数据仍会继续显示在正式模式里。
- 如果完全删除 seed 逻辑，会损失当前用于验证挑战记录空态与边界排版的开发便利性。
- 若开发模式判定只依赖编译宏，不同启动方式下可能不够稳定，因此本次同时引入环境变量兜底。

## 当前进展
- `ModeRecordStore` 已新增开发模式判定：优先读取 `ELIMINATE_DEVELOPMENT_MODE`，其次回退到 `#if DEBUG`。
- 开发模式下会同步 seed；非开发模式下会自动移除旧 seed。
- `run.sh` 已显式导出 `ELIMINATE_DEVELOPMENT_MODE=1`，保证本地开发启动仍保留测试记录。
- 已执行 `swift build --disable-sandbox`，构建通过。

## 代码变更
- `Sources/ModeRecordStore.swift`
```diff
@@
+    private static let developmentModeEnvironmentKey = "ELIMINATE_DEVELOPMENT_MODE"
+
+    private static var shouldInjectDevelopmentSeedRecords: Bool {
+        let rawValue = ProcessInfo.processInfo.environment[developmentModeEnvironmentKey]?
+            .trimmingCharacters(in: .whitespacesAndNewlines)
+            .lowercased()
+
+        switch rawValue {
+        case "1", "true", "yes", "on", "debug":
+            return true
+        case "0", "false", "no", "off", "release":
+            return false
+        default:
+#if DEBUG
+            return true
+#else
+            return false
+#endif
+        }
+    }
@@
-        if normalizeBucketsToMaxCount() {
-            save()
-        }
-        seedTestRecordsIfNeeded()
+        var shouldSave = normalizeBucketsToMaxCount()
+
+        if Self.shouldInjectDevelopmentSeedRecords {
+            if synchronizeDevelopmentSeedRecords() {
+                shouldSave = true
+            }
+        } else {
+            if removeSeedRecordsIfNeeded() {
+                shouldSave = true
+            }
+        }
+
+        if shouldSave {
+            save()
+        }
@@
-    private func seedTestRecordsIfNeeded() {
-        guard defaults.integer(forKey: seedVersionKey) < seedVersion else { return }
+    private func synchronizeDevelopmentSeedRecords() -> Bool {
+        ...
+    }
@@
-    private func ensureSeedRecords(for mode: ModeRecordKey, detailValue: Int, seeds: [ModeRecord]) {
+    private func ensureSeedRecords(for mode: ModeRecordKey, detailValue: Int, seeds: [ModeRecord]) -> Bool {
+        ...
+    }
+
+    private func removeSeedRecordsIfNeeded() -> Bool {
+        ...
+    }
```

- `run.sh`
```diff
@@
 if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
   export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
 fi
+
+export ELIMINATE_DEVELOPMENT_MODE=1
 
 echo "[run.sh] 正在重新编译..."
```

## 测试用例
### TC-001 开发模式仍会注入挑战记录测试数据
- 类型：手动功能测试
- 优先级：高
- 关联模块：`Sources/ModeRecordStore.swift`、`run.sh`
- 前置条件：通过 `./run.sh` 启动应用
- 操作步骤：
1. 运行 `./run.sh`
2. 进入竞分或竞速模式查看挑战记录
- 预期结果：
- 仍可看到用于调试的 seed 分布（如 9/1/0）
- 是否通过：待人工验证

### TC-002 非开发模式不再显示 seed
- 类型：手动功能测试
- 优先级：高
- 关联模块：`Sources/ModeRecordStore.swift`
- 前置条件：不设置 `ELIMINATE_DEVELOPMENT_MODE`，或显式设为 `0`
- 操作步骤：
1. 以非开发模式启动应用
2. 进入竞分或竞速模式查看挑战记录
- 预期结果：
- 不再自动灌入测试数据
- 若本机之前已有旧 seed，也会被自动清理
- 是否通过：待人工验证

### TC-003 构建验证
- 类型：构建验证
- 优先级：高
- 关联模块：`Sources/ModeRecordStore.swift`、`run.sh`
- 前置条件：本机已安装 Swift/Xcode 构建环境
- 操作步骤：
1. 在项目根目录执行 `swift build --disable-sandbox`
- 预期结果：
- 项目构建成功，无 `ModeRecordStore` 相关编译错误
- 是否通过：已通过
