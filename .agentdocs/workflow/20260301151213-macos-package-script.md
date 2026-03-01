# macOS 可安装应用打包脚本

## 背景与目标
- 目标是把当前 SwiftPM 工程打包成可分发的 macOS 应用。
- 期望交付物至少包含 `.app`，并尽可能给出可安装分发格式（DMG 或 ZIP）。

## 方案说明
- 新增 `package.sh` 一键打包脚本：
  - 先构建 release 二进制；
  - 组装 `.app`（可执行文件、资源 Bundle、Info.plist）；
  - 执行 ad-hoc 签名；
  - 优先输出 DMG，若当前环境无法创建 DMG，则自动回退输出 ZIP。
- `.gitignore` 增加 `/dist`，避免打包产物进入版本控制。

## 代码变更
- .gitignore
```diff
diff --git a/.gitignore b/.gitignore
index c9d6deb..8aeed9a 100644
--- a/.gitignore
+++ b/.gitignore
@@ -1,2 +1,3 @@
 /.build
 /.history
+/dist
```

- package.sh
```diff
diff --git a/package.sh b/package.sh
new file mode 100755
index 0000000..0aa89d8
--- /dev/null
+++ b/package.sh
@@ -0,0 +1,109 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
+APP_NAME="Eliminate Teris 1"
+TARGET_NAME="EliminateTeris1"
+BUILD_CONFIG="release"
+DIST_DIR="$ROOT_DIR/dist"
+APP_DIR="$DIST_DIR/$APP_NAME.app"
+STAGING_DIR="$DIST_DIR/dmg-staging"
+DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
+ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
+
+if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
+  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
+fi
+
+if [[ -z "${HOME:-}" || ! -w "${HOME:-/}" ]]; then
+  export HOME="/tmp"
+fi
+
+echo "[package.sh] 开始构建 $BUILD_CONFIG 产物..."
+(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --disable-sandbox)
+
+BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --show-bin-path)"
+EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
+
+if [[ ! -x "$EXECUTABLE_PATH" ]]; then
+  echo "[package.sh] 打包失败：未找到可执行文件 $EXECUTABLE_PATH"
+  exit 1
+fi
+
+RESOURCE_BUNDLE_PATH=""
+if [[ -d "$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle" ]]; then
+  RESOURCE_BUNDLE_PATH="$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle"
+elif [[ -d "$BIN_DIR/$TARGET_NAME.bundle" ]]; then
+  RESOURCE_BUNDLE_PATH="$BIN_DIR/$TARGET_NAME.bundle"
+fi
+
+echo "[package.sh] 生成 .app 包..."
+rm -rf "$APP_DIR"
+mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
+
+cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
+chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
+
+if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
+  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/Contents/Resources/"
+else
+  echo "[package.sh] 警告：未找到 SwiftPM 资源 Bundle，多语言资源可能无法加载。"
+fi
+
+cat > "$APP_DIR/Contents/Info.plist" <<PLIST
+<?xml version="1.0" encoding="UTF-8"?>
+<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
+<plist version="1.0">
+<dict>
+  <key>CFBundleDevelopmentRegion</key>
+  <string>en</string>
+  <key>CFBundleDisplayName</key>
+  <string>$APP_NAME</string>
+  <key>CFBundleExecutable</key>
+  <string>$APP_NAME</string>
+  <key>CFBundleIdentifier</key>
+  <string>com.lepton.eliminate-teris-1</string>
+  <key>CFBundleInfoDictionaryVersion</key>
+  <string>6.0</string>
+  <key>CFBundleName</key>
+  <string>$APP_NAME</string>
+  <key>CFBundlePackageType</key>
+  <string>APPL</string>
+  <key>CFBundleShortVersionString</key>
+  <string>1.0.0</string>
+  <key>CFBundleVersion</key>
+  <string>1</string>
+  <key>LSMinimumSystemVersion</key>
+  <string>12.0</string>
+  <key>NSHighResolutionCapable</key>
+  <true/>
+  <key>NSPrincipalClass</key>
+  <string>NSApplication</string>
+</dict>
+</plist>
+PLIST
+
+echo "[package.sh] 执行 ad-hoc 签名..."
+codesign --force --deep --sign - "$APP_DIR" >/dev/null
+
+echo "[package.sh] 生成可分发 DMG..."
+rm -rf "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
+mkdir -p "$STAGING_DIR"
+cp -R "$APP_DIR" "$STAGING_DIR/"
+ln -s /Applications "$STAGING_DIR/Applications"
+
+if hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null 2>&1; then
+  rm -rf "$STAGING_DIR"
+  echo "[package.sh] 打包完成："
+  echo "  - APP: $APP_DIR"
+  echo "  - DMG: $DMG_PATH"
+  exit 0
+fi
+
+echo "[package.sh] 警告：当前环境无法创建 DMG，改为输出 ZIP。"
+rm -rf "$STAGING_DIR"
+ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
+
+echo "[package.sh] 打包完成："
+echo "  - APP: $APP_DIR"
+echo "  - ZIP: $ZIP_PATH"
```

- AGENTS.md
```diff
diff --git a/AGENTS.md b/AGENTS.md
index 6c8fe01..ce63011 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -39,3 +39,4 @@
 - 已按“答-25”回退动画时序：取消两阶段串联，恢复为单阶段过渡（`0.28s`），保留增强后的消除光晕/外环与缩放淡出效果。
 - 动画时序现已按最新需求调整为三阶段：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；通过 `lastSwapPair + transitionPhases` 串联，确保“先交换、再消除、后补位”。
 - 已新增程序化音效系统 `GameAudioSystem`：自由/竞分/竞速模式会自动切换不同 BGM，且在三阶段动画中按阶段触发移动、消除、补位音效；音频由运行时合成 WAV，不依赖外部资源文件。
+- 已新增 `package.sh` 打包脚本：构建 release 后生成 `.app`，自动拷贝 SwiftPM 资源 Bundle、写入 `Info.plist`、执行 ad-hoc 签名，并优先输出 DMG（失败时自动回退 ZIP）。
```

- .agentdocs/index.md
```diff
diff --git a/.agentdocs/index.md b/.agentdocs/index.md
index a86d4db..1121c8a 100644
--- a/.agentdocs/index.md
+++ b/.agentdocs/index.md
@@ -1,6 +1,7 @@
 # Agent 文档索引
 
 ## 当前变更文档
+`workflow/20260301151213-macos-package-script.md` - 新增 macOS 打包脚本，产出 `.app` 并优先生成 DMG（失败回退 ZIP）。
 `workflow/20260221200836-audio-system-bgm-sfx.md` - 新增程序化音效系统：按模式切换 BGM，并按动画阶段播放移动/消除/补位音效。
 `workflow/20260221193822-touchbar-three-phase-animation-sequence.md` - Touch Bar 动画改为三阶段：先交换，再消除，最后左侧补位。
 `workflow/20260221192738-touchbar-animation-rollback-to-answer25.md` - 按“答-25”回退 Touch Bar 动画时序，取消两阶段串联并恢复单阶段过渡。
@@ -39,6 +40,7 @@
 `workflow/20260214200042-run-script-always-rebuild.md` - 启动脚本改为每次先编译再启动，避免旧版本残留。
 
 ## 读取场景
+- 需要确认“如何打包成可安装 macOS 应用（.app/.dmg/.zip）”时，优先读取 `20260301151213` 文档。
 - 需要确认“模式切换 BGM + 交换/消除/补位音效”是否已接入时，优先读取 `20260221200836` 文档。
 - 需要确认“交换后才消除、消除后才补位”是否落地时，优先读取 `20260221193822` 文档。
 - 需要确认“已回退到答-25的动画时序”时，优先读取 `20260221192738` 文档。
@@ -78,6 +80,7 @@
 - 需要确认启动脚本中构建与二进制定位策略时，优先读取此文档。
 
 ## 关键记忆
+- 当前通过 `package.sh` 一键打包：`swift build -c release` 后组装 `.app`（含资源 Bundle + Info.plist + ad-hoc 签名），并尝试生成 DMG；若 DMG 不可用则自动回退为 ZIP。
 - 已新增 `GameAudioSystem` 程序化音频链路：自由/竞分/竞速模式切换会切 BGM，且仅在“交换触发”的三阶段过渡中按阶段播放移动、消除、补位音效，避免模式切换/重置触发误报声。
 - Touch Bar 动画时序当前为三阶段链路：交换位移（0.16s）→ 消除反馈（0.20s）→ 左侧补位（0.24s）；交换对由 `GameBoardController.lastSwapPair` 提供，渲染端以 `transitionPhases` 顺序执行。
 - Touch Bar 动画时序已回退到答-25：单阶段过渡（`0.28s`），保留消除光晕/外环与放大缩放淡出，取消两阶段 pending 串联逻辑。
```

## 测试与验证
### TC-001 一键打包
- 类型：功能测试
- 操作步骤：执行 `./package.sh`
- 预期结果：生成 `.app`，并生成 DMG；若 DMG 失败则回退 ZIP。
- 实际结果：当前环境 DMG 创建失败，已自动回退并生成 ZIP。

### TC-002 产物检查
- 类型：产物验证
- 操作步骤：
  1. 检查 `dist/Eliminate Teris 1.app`
  2. 检查 `dist/Eliminate Teris 1.zip`（或 DMG）
- 预期结果：产物存在，可用于分发安装。
