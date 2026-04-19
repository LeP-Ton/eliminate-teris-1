#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Eliminate Teris 1"
TARGET_NAME="EliminateTeris1"
BUILD_CONFIG="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
PACKAGE_ARCHS_STRING="${PACKAGE_ARCHS:-x86_64 arm64}"
PACKAGE_MIN_MACOS="${PACKAGE_MIN_MACOS:-12.0}"
TEMP_BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/eliminate-package.XXXXXX")"
read -r -a PACKAGE_ARCHS <<< "$PACKAGE_ARCHS_STRING"

cleanup() {
  rm -rf "$TEMP_BUILD_ROOT"
}
trap cleanup EXIT

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [[ -z "${HOME:-}" || ! -w "${HOME:-/}" ]]; then
  export HOME="/tmp"
fi

build_for_arch() {
  local arch="$1"
  local triple="${arch}-apple-macosx${PACKAGE_MIN_MACOS}"
  local scratch_path="$TEMP_BUILD_ROOT/$arch"
  local executable_path
  local bin_dir

  # 构建日志输出到标准错误，避免污染后续用于捕获路径的标准输出。
  echo "[package.sh] 开始构建 $arch 架构..." >&2
  (cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --triple "$triple" --scratch-path "$scratch_path" --disable-sandbox) >&2

  bin_dir="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --triple "$triple" --scratch-path "$scratch_path" --show-bin-path)"
  executable_path="$bin_dir/$APP_NAME"

  if [[ ! -x "$executable_path" ]]; then
    echo "[package.sh] 打包失败：未找到 $arch 可执行文件 $executable_path"
    exit 1
  fi

  echo "$bin_dir"
}

find_resource_bundle() {
  local bin_dir="$1"
  if [[ -d "$bin_dir/${TARGET_NAME}_${TARGET_NAME}.bundle" ]]; then
    echo "$bin_dir/${TARGET_NAME}_${TARGET_NAME}.bundle"
    return
  fi
  if [[ -d "$bin_dir/$TARGET_NAME.bundle" ]]; then
    echo "$bin_dir/$TARGET_NAME.bundle"
  fi
}

if [[ ${#PACKAGE_ARCHS[@]} -eq 0 ]]; then
  echo "[package.sh] 打包失败：未配置任何目标架构。"
  exit 1
fi

declare -a BIN_DIRS=()
declare -a EXECUTABLE_PATHS=()
RESOURCE_BUNDLE_PATH=""

for arch in "${PACKAGE_ARCHS[@]}"; do
  BIN_DIR="$(build_for_arch "$arch")"
  BIN_DIRS+=("$BIN_DIR")
  EXECUTABLE_PATHS+=("$BIN_DIR/$APP_NAME")

  if [[ -z "$RESOURCE_BUNDLE_PATH" ]]; then
    RESOURCE_BUNDLE_PATH="$(find_resource_bundle "$BIN_DIR")"
  fi
done

echo "[package.sh] 生成通用 .app 包..."
rm -rf "$APP_DIR" "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

lipo -create "${EXECUTABLE_PATHS[@]}" -output "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/Contents/Resources/"
else
  echo "[package.sh] 警告：未找到 SwiftPM 资源 Bundle，多语言资源可能无法加载。"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.lepton.eliminate-teris-1</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "[package.sh] 执行 ad-hoc 签名..."
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "[package.sh] 当前可执行文件架构："
file "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "[package.sh] 生成可分发 DMG..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null 2>&1; then
  rm -rf "$STAGING_DIR"
  echo "[package.sh] 打包完成："
  echo "  - APP: $APP_DIR"
  echo "  - DMG: $DMG_PATH"
  exit 0
fi

echo "[package.sh] 警告：当前环境无法创建 DMG，改为输出 ZIP。"
rm -rf "$STAGING_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "[package.sh] 打包完成："
echo "  - APP: $APP_DIR"
echo "  - ZIP: $ZIP_PATH"
