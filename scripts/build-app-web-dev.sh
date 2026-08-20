#!/bin/bash
# 使用 port-manager 分配端口并构建 Flutter Web + 启动本地静态服务器
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PORT=$(python3 "$PROJECT_ROOT/.kimi/skills/port-manager/scripts/portman.py" get "$PROJECT_ROOT" app-web)
WEB_PORT=$(python3 "$PROJECT_ROOT/.kimi/skills/port-manager/scripts/portman.py" get "$PROJECT_ROOT" web)
cd "$PROJECT_ROOT/app"
npm ci --prefix web --omit=dev --no-audit --no-fund
flutter build web \
  --dart-define=DEV_MODE=true \
  --dart-define=DEV_LOGIN=true \
  --dart-define=WEB_DEV_PORT="$WEB_PORT"
cd build/web
python3 -m http.server "$APP_PORT"
