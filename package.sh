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

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [[ -z "${HOME:-}" || ! -w "${HOME:-/}" ]]; then
  export HOME="/tmp"
fi

echo "[package.sh] 开始构建 $BUILD_CONFIG 产物..."
(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --disable-sandbox)

BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIG" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "[package.sh] 打包失败：未找到可执行文件 $EXECUTABLE_PATH"
  exit 1
fi

RESOURCE_BUNDLE_PATH=""
if [[ -d "$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle" ]]; then
  RESOURCE_BUNDLE_PATH="$BIN_DIR/${TARGET_NAME}_${TARGET_NAME}.bundle"
elif [[ -d "$BIN_DIR/$TARGET_NAME.bundle" ]]; then
  RESOURCE_BUNDLE_PATH="$BIN_DIR/$TARGET_NAME.bundle"
fi

echo "[package.sh] 生成 .app 包..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
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

echo "[package.sh] 生成可分发 DMG..."
rm -rf "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
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
