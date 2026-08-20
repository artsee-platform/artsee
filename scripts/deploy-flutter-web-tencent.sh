#!/usr/bin/env bash
# 将 Flutter Web 构建并部署到腾讯云服务器（静态文件托管）
#
# 环境变量（必需）：
#   TENCENT_HOST      腾讯云服务器地址
#   TENCENT_USER      SSH 用户名（默认 ubuntu）
#   TENCENT_KEY       SSH 密钥文件路径（默认 ~/tom.pem）
#   FLUTTER_WEB_DIR   远程部署目录（默认 ~/website/artsee-app）
#
# 可选环境变量：
#   SKIP_BUILD=1      跳过本地构建
#   API_BASE_URL      后端 API 地址（默认 https://artiqore.com）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"
BUILD_DIR="${APP_DIR}/build/web"

# 腾讯云配置
TENCENT_HOST="${TENCENT_HOST:-}"
TENCENT_USER="${TENCENT_USER:-ubuntu}"
TENCENT_KEY="${TENCENT_KEY:-${HOME}/tom.pem}"
FLUTTER_WEB_DIR="${FLUTTER_WEB_DIR:-~/website/artsee-app}"
API_BASE_URL="${API_BASE_URL:-https://artiqore.com}"
ARCHIVE_NAME="artsee-flutter-web.tar.gz"
ARCHIVE_PATH="${REPO_ROOT}/${ARCHIVE_NAME}"

# 检查必需参数
if [[ -z "${TENCENT_HOST}" ]]; then
  echo "错误：请设置 TENCENT_HOST 环境变量"
  echo "示例：TENCENT_HOST=artiqore.com $0"
  exit 1
fi

if [[ ! -f "${TENCENT_KEY}" ]]; then
  echo "错误：SSH 密钥文件不存在: ${TENCENT_KEY}"
  exit 1
fi

chmod 600 "${TENCENT_KEY}"

SSH_TARGET="${TENCENT_USER}@${TENCENT_HOST}"
SSH_OPTS=(-i "${TENCENT_KEY}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

log() { printf '%s\n' "$*"; }

log "========================================="
log "Flutter Web 部署到腾讯云"
log "========================================="
log "服务器: ${TENCENT_HOST}"
log "用户: ${TENCENT_USER}"
log "远程目录: ${FLUTTER_WEB_DIR}"
log "API 地址: ${API_BASE_URL}"
log "========================================="

# 测试 SSH 连接
log "测试 SSH 连接..."
if ! ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "echo '连接成功'" 2>/dev/null; then
  log "错误：无法连接到腾讯云服务器"
  exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  log "构建 Flutter Web 生产版本..."
  
  # 检查 Flutter 是否安装
  if ! command -v flutter >/dev/null 2>&1; then
    log "错误：Flutter 未安装"
    exit 1
  fi
  
  cd "${APP_DIR}"

  # Tencent's Flutter Web bridge expects the pinned JS SDK files under web/node_modules.
  npm ci --prefix web --omit=dev --no-audit --no-fund
  
  # 清理旧构建
  rm -rf build/web
  
  # 构建生产版本
  flutter build web \
    --release \
    --dart-define=API_BASE_URL="${API_BASE_URL}" \
    --dart-define=DEV_MODE=false
  
  log "✅ Flutter Web 构建完成"
else
  log "跳过构建（SKIP_BUILD=1）"
fi

if [[ ! -d "${BUILD_DIR}" ]]; then
  log "错误：未找到构建目录 ${BUILD_DIR}"
  exit 1
fi

log "打包构建产物..."
rm -f "${ARCHIVE_PATH}"
COPYFILE_DISABLE=1 tar czf "${ARCHIVE_PATH}" -C "${BUILD_DIR}" .

log "上传到腾讯云..."
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "mkdir -p ${FLUTTER_WEB_DIR}"
scp "${SSH_OPTS[@]}" "${ARCHIVE_PATH}" "${SSH_TARGET}:${FLUTTER_WEB_DIR}/"

log "远程解压..."
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" bash -s <<REMOTE_SCRIPT
set -euo pipefail
REMOTE_DIR_EXPANDED="\$(eval echo ${FLUTTER_WEB_DIR})"
cd "\$REMOTE_DIR_EXPANDED"

ARCHIVE_NAME='${ARCHIVE_NAME}'

# 备份旧版本
if [[ -d "current" ]]; then
  BACKUP_NAME="backup-\$(date +%Y%m%d-%H%M%S)"
  mv current "\$BACKUP_NAME"
  echo "已备份旧版本到 \$BACKUP_NAME"
fi

# 创建新目录并解压
mkdir -p current
tar xzf "\$ARCHIVE_NAME" -C current
rm -f "\$ARCHIVE_NAME"

echo "========================================="
echo "Flutter Web 部署完成！"
echo "========================================="
ls -lh current/
REMOTE_SCRIPT

log "删除本地压缩包..."
rm -f "${ARCHIVE_PATH}"

log "========================================="
log "部署完成！"
log "========================================="
log "访问地址: http://${TENCENT_HOST}/app/"
log ""
log "下一步：配置 Nginx"
log "  1. SSH 登录: ssh -i ${TENCENT_KEY} ${SSH_TARGET}"
log "  2. 编辑 Nginx 配置，添加："
log ""
log "    location /app/ {"
log "        alias ${FLUTTER_WEB_DIR}/current/;"
log "        try_files \$uri \$uri/ /app/index.html;"
log "    }"
log ""
log "  3. 重启 Nginx: sudo systemctl reload nginx"
log "========================================="
