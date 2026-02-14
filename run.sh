#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Eliminate Teris 1"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "[run.sh] 正在重新编译..."
(cd "$ROOT_DIR" && swift build --disable-sandbox)

BIN_PATH="$(cd "$ROOT_DIR" && swift build --show-bin-path)"
APP_PATH="$BIN_PATH/$APP_NAME"

if [[ ! -x "$APP_PATH" ]]; then
  echo "[run.sh] 启动失败：未找到可执行文件 '$APP_NAME'。"
  exit 1
fi

exec "$APP_PATH"
