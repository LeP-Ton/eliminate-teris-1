# macOS 通用二进制打包

## 背景与目标
- 当前 `dist/Eliminate Teris 1.app` 的可执行文件是 `x86_64`，压缩后发给 M1 Touch Bar MacBook 可能因架构或 Rosetta 环境导致“应用意外退出”。
- 本次目标是让打包脚本默认生成 `x86_64 + arm64` 通用 `.app`，同时兼容 Intel 与 Apple Silicon 机器。

## 方案
- `package.sh` 默认按 `x86_64 arm64` 两套架构分别构建。
- 使用 `lipo` 把两套可执行文件合成为一个通用 Mach-O。
- 打包时打印最终可执行文件架构，方便验证发出的包是否真的是通用二进制。
- 新增 `PACKAGE_ARCHS` 覆盖入口，例如 `PACKAGE_ARCHS="arm64" ./package.sh` 可只打 Apple Silicon 包。
- `.gitignore` 忽略 `/.build-*`，避免手工交叉编译 scratch 目录干扰变更列表。

## 代码变更
- .gitignore
```diff
diff --git a/.gitignore b/.gitignore
index 8aeed9a..afa8657 100644
--- a/.gitignore
+++ b/.gitignore
@@ -1,3 +1,4 @@
 /.build
+/.build-*
 /.history
 /dist
```

- package.sh
```diff
diff --git a/package.sh b/package.sh
index 0aa89d8..fd996e1 100755
--- a/package.sh
+++ b/package.sh
@@ -10,6 +10,15 @@ APP_DIR="$DIST_DIR/$APP_NAME.app"
 STAGING_DIR="$DIST_DIR/dmg-staging"
 DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
 ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
+PACKAGE_ARCHS_STRING="${PACKAGE_ARCHS:-x86_64 arm64}"
+PACKAGE_MIN_MACOS="${PACKAGE_MIN_MACOS:-12.0}"
+TEMP_BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/eliminate-package.XXXXXX")"
+read -r -a PACKAGE_ARCHS <<< "$PACKAGE_ARCHS_STRING"
+
+cleanup() {
+  rm -rf "$TEMP_BUILD_ROOT"
+}
+trap cleanup EXIT
 
 if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
   export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
@@ -19,29 +28,63 @@ if [[ -z "${HOME:-}" || ! -w "${HOME:-/}" ]]; then
   export HOME="/tmp"
 fi
 
-echo "[package.sh] 开始构建 $BUILD_CONFIG 产物..."
-(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --disable-sandbox)
-
-BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --show-bin-path)"
-EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
-
-if [[ ! -x "$EXECUTABLE_PATH" ]]; then
-  echo "[package.sh] 打包失败：未找到可执行文件 $EXECUTABLE_PATH"
+build_for_arch() {
+  local arch="$1"
+  local triple="${arch}-apple-macosx${PACKAGE_MIN_MACOS}"
+  local scratch_path="$TEMP_BUILD_ROOT/$arch"
+  local executable_path
+  local bin_dir
+
+  # 构建日志输出到标准错误，避免污染后续用于捕获路径的标准输出。
+  echo "[package.sh] 开始构建 $arch 架构..." >&2
+  (cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --triple "$triple" --scratch-path "$scratch_path" --disable-sandbox) >&2
+
+  bin_dir="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --triple "$triple" --scratch-path "$scratch_path" --show-bin-path)"
+  executable_path="$bin_dir/$APP_NAME"
+
+  if [[ ! -x "$executable_path" ]]; then
+    echo "[package.sh] 打包失败：未找到 $arch 可执行文件 $executable_path"
+    exit 1
+  fi
+
+  echo "$bin_dir"
+}
+
+find_resource_bundle() {
+  local bin_dir="$1"
+  if [[ -d "$bin_dir/${TARGET_NAME}_${TARGET_NAME}.bundle" ]]; then
+    echo "$bin_dir/${TARGET_NAME}_${TARGET_NAME}.bundle"
+    return
+  fi
+  if [[ -d "$bin_dir/$TARGET_NAME.bundle" ]]; then
+    echo "$bin_dir/$TARGET_NAME.bundle"
+  fi
+}
+
+if [[ ${#PACKAGE_ARCHS[@]} -eq 0 ]]; then
+  echo "[package.sh] 打包失败：未配置任何目标架构。"
   exit 1
 fi
 
+declare -a BIN_DIRS=()
+declare -a EXECUTABLE_PATHS=()
 RESOURCE_BUNDLE_PATH=""
-if [[ -d "$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle" ]]; then
-  RESOURCE_BUNDLE_PATH="$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle"
-elif [[ -d "$BIN_DIR/$TARGET_NAME.bundle" ]]; then
-  RESOURCE_BUNDLE_PATH="$BIN_DIR/$TARGET_NAME.bundle"
-fi
 
-echo "[package.sh] 生成 .app 包..."
-rm -rf "$APP_DIR"
+for arch in "${PACKAGE_ARCHS[@]}"; do
+  BIN_DIR="$(build_for_arch "$arch")"
+  BIN_DIRS+=("$BIN_DIR")
+  EXECUTABLE_PATHS+=("$BIN_DIR/$APP_NAME")
+
+  if [[ -z "$RESOURCE_BUNDLE_PATH" ]]; then
+    RESOURCE_BUNDLE_PATH="$(find_resource_bundle "$BIN_DIR")"
+  fi
+done
+
+echo "[package.sh] 生成通用 .app 包..."
+rm -rf "$APP_DIR" "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
 mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
 
-cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
+lipo -create "${EXECUTABLE_PATHS[@]}" -output "$APP_DIR/Contents/MacOS/$APP_NAME"
 chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
 
 if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
@@ -86,8 +129,10 @@ PLIST
 echo "[package.sh] 执行 ad-hoc 签名..."
 codesign --force --deep --sign - "$APP_DIR" >/dev/null
 
+echo "[package.sh] 当前可执行文件架构："
+file "$APP_DIR/Contents/MacOS/$APP_NAME"
+
 echo "[package.sh] 生成可分发 DMG..."
-rm -rf "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
 mkdir -p "$STAGING_DIR"
 cp -R "$APP_DIR" "$STAGING_DIR/"
 ln -s /Applications "$STAGING_DIR/Applications"
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 006735f..b002133 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -42,3 +42,4 @@
 - 已新增 `package.sh` 打包脚本：构建 release 后生成 `.app`，自动拷贝 SwiftPM 资源 Bundle、写入 `Info.plist`、执行 ad-hoc 签名，并优先输出 DMG（失败时自动回退 ZIP）。
 - 曾尝试以“release 默认公开路径”规避打包版 Touch Bar 黑屏（`ELIMINATE_TOUCHBAR_MODAL=1` 可强制私有 modal）；当前策略已迭代为默认私有 modal + 显式关闭开关。
 - Touch Bar 展示策略已升级为“默认私有 modal + 可显式关闭”：默认启用私有 modal 保持左侧贴边，设置 `ELIMINATE_TOUCHBAR_MODAL=0` 可回退公开路径；同时在挂载后调用 `prepareForDisplay` 并开启 `layerContentsRedrawPolicy = .onSetNeedsDisplay`，降低打包版黑屏概率。
+- `package.sh` 现在默认构建 `x86_64 + arm64` 通用二进制，并通过 `lipo` 合成为单个 `.app`，用于同时兼容 Intel 与 Apple Silicon（M1/M2/M3）Mac；可用 `PACKAGE_ARCHS` 覆盖目标架构。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index 004e8e2..d912993 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260418231251-universal-macos-package.md` - 打包脚本改为默认生成 `x86_64 + arm64` 通用 `.app`，解决发给 M1 机器后架构不匹配导致的崩溃风险。
 `workflow/20260301160231-touchbar-modal-and-black-screen-balance.md` - 同时兼顾左侧贴边与打包黑屏：默认私有 modal，增加显式回退开关与强制重绘预热。
 `workflow/20260301153306-release-touchbar-modal-fallback.md` - 修复打包版 Touch Bar 黑屏：release 默认回退公开 Touch Bar 路径，并保留环境变量开关启用私有 modal。
 `workflow/20260301151213-macos-package-script.md` - 新增 macOS 打包脚本，产出 `.app` 并优先生成 DMG（失败回退 ZIP）。
@@ -42,6 +43,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要排查“压缩 `.app` 发给 M1 后应用意外退出/架构不匹配”时，优先读取 `20260418231251` 文档。
 - 需要同时处理“左侧空白间距 + 打包黑屏”时，优先读取 `20260301160231` 文档。
 - 需要排查“打包后 Touch Bar 黑屏”时，优先读取 `20260301153306` 文档。
 - 需要确认“如何打包成可安装 macOS 应用（.app/.dmg/.zip）”时，优先读取 `20260301151213` 文档。
@@ -84,6 +86,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 当前打包脚本默认输出通用二进制：分别构建 `x86_64` 与 `arm64`，再用 `lipo` 合成，最终 `file dist/Eliminate Teris 1.app/Contents/MacOS/Eliminate Teris 1` 应显示 `Mach-O universal binary with 2 architectures`。
 - Touch Bar 当前默认仍启用私有 modal（用于维持左侧贴边），但增加了 `ELIMINATE_TOUCHBAR_MODAL=0` 显式回退开关；挂载后会执行 `prepareForDisplay` 且开启 `onSetNeedsDisplay` 重绘策略，缓解打包版黑屏。
 - 打包版 Touch Bar 策略已更新：默认启用私有 modal 以保持左侧贴边，若需规避兼容性问题可显式设置 `ELIMINATE_TOUCHBAR_MODAL=0` 回退公开 `window.touchBar` 路径。
 - 当前通过 `package.sh` 一键打包：`swift build -c release` 后组装 `.app`（含资源 Bundle + Info.plist + ad-hoc 签名），并尝试生成 DMG；若 DMG 不可用则自动回退为 ZIP。
```

## 测试用例
### TC-001 Bash 语法检查
- 类型：静态检查
- 操作步骤：执行 `bash -n package.sh`
- 预期结果：无语法错误。
- 是否通过：已通过。

### TC-002 通用二进制打包
- 类型：构建测试
- 操作步骤：执行 `./package.sh`
- 预期结果：生成 `dist/Eliminate Teris 1.app` 与 ZIP/DMG，并输出 `x86_64` 与 `arm64` 两套架构。
- 是否通过：已通过，输出显示 `Mach-O universal binary with 2 architectures`。

### TC-003 Apple Silicon 实机验证
- 类型：兼容性测试
- 前置条件：将本次新生成的 `dist/Eliminate Teris 1.zip` 发到 M1 Touch Bar MacBook。
- 操作步骤：
  1. 在 M1 机器解压 ZIP。
  2. 启动 `Eliminate Teris 1.app`。
  3. 观察应用是否正常打开，Touch Bar 是否正常显示。
- 预期结果：不再因只包含 `x86_64` 架构导致意外退出。
- 是否通过：待用户在 M1 机器确认。
