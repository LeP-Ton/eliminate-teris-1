#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Eliminate Teris 1"

find_app_binary() {
  find "$ROOT_DIR/.build" -maxdepth 3 -type f -name "$APP_NAME" -perm -111 2>/dev/null | head -n 1
}

APP_PATH="$(find_app_binary)"
if [[ -z "$APP_PATH" ]]; then
  echo "[run.sh] 未找到已构建程序，正在执行 swift build..."
  (cd "$ROOT_DIR" && swift build --disable-sandbox)
  APP_PATH="$(find_app_binary)"
fi

if [[ -z "$APP_PATH" ]]; then
  echo "[run.sh] 启动失败：未找到可执行文件 '$APP_NAME'。"
  exit 1
fi

exec "$APP_PATH"
