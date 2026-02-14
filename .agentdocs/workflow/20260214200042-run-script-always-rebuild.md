# 启动脚本改为每次编译后再启动

## 背景与目标
- 用户反馈：`./run.sh` 启动的仍可能是旧版本。
- 目标：每次执行 `run.sh` 都先重新编译，再启动最新可执行文件。

## 约束与原则
- 保持脚本使用方式不变（仍然是 `./run.sh`）。
- 优先最小改动，只调整构建与可执行文件定位逻辑。
- 不引入额外依赖工具。

## 阶段与 TODO
- [x] 修改 `run.sh` 为每次先编译。
- [x] 改用 `swift build --show-bin-path` 计算实际启动路径。
- [x] 补充 `DEVELOPER_DIR` 兜底，降低本机环境差异影响。
- [x] 更新 `.gitignore`，忽略 `.agentdocs`。
- [x] 更新 `AGENTS.md` 与索引文档。

## 关键风险
- 每次启动都会编译，启动耗时会比以前更长。
- 若本地 Xcode/Swift 环境异常，会在启动前直接暴露构建错误（属预期）。

## 当前进展
- `run.sh` 已改为“每次先编译，再启动”。
- 已改为动态读取 bin 目录，避免架构目录变化导致找不到二进制。

## git记录
- branch：main
- commit：待提交（本次对话自动提交）

## 代码变更
- .gitignore
```diff
@@ -1,2 +1,3 @@
 /.build
-/.history
\ No newline at end of file
+/.history
+/.agentdocs
```

- AGENTS.md
```diff
+ # 项目认知记录
+
+ ## 2026-02-14
+ - 项目通过 `run.sh` 启动可执行程序，当前策略已改为“每次启动前强制重新编译”，避免启动到旧构建产物。
+ - `run.sh` 会优先使用 `/Applications/Xcode.app/Contents/Developer` 作为 `DEVELOPER_DIR`（若用户未手动设置）。
+ - 启动路径通过 `swift build --show-bin-path` 计算，避免手写架构目录导致路径偏差。
```

- run.sh
```diff
@@
 ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
 APP_NAME="Eliminate Teris 1"
 
-find_app_binary() {
-  find "$ROOT_DIR/.build" -maxdepth 3 -type f -name "$APP_NAME" -perm -111 2>/dev/null | head -n 1
-}
-
-APP_PATH="$(find_app_binary)"
-if [[ -z "$APP_PATH" ]]; then
-  echo "[run.sh] 未找到已构建程序，正在执行 swift build..."
-  (cd "$ROOT_DIR" && swift build --disable-sandbox)
-  APP_PATH="$(find_app_binary)"
-fi
-
-if [[ -z "$APP_PATH" ]]; then
+if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
+  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
+fi
+
+echo "[run.sh] 正在重新编译..."
+(cd "$ROOT_DIR" && swift build --disable-sandbox)
+
+BIN_PATH="$(cd "$ROOT_DIR" && swift build --show-bin-path)"
+APP_PATH="$BIN_PATH/$APP_NAME"
+
+if [[ ! -x "$APP_PATH" ]]; then
   echo "[run.sh] 启动失败：未找到可执行文件 '$APP_NAME'。"
   exit 1
 fi
```

## 测试用例
### TC-001 启动脚本强制编译
- 类型：功能测试
- 前置条件：修改任意代码
- 操作步骤：执行 `./run.sh`
- 预期结果：终端先出现“正在重新编译...”，随后启动最新程序

### TC-002 二进制路径定位
- 类型：兼容性测试
- 操作步骤：执行 `./run.sh`，观察脚本无硬编码架构路径错误
- 预期结果：可正确定位并启动可执行文件

### TC-003 构建验证
- 类型：构建测试
- 操作步骤：执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`
- 预期结果：构建成功
