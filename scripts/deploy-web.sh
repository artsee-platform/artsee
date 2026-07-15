#!/usr/bin/env bash
# 将 web/（Next.js standalone）构建、打包并部署到远程 ~/website/artsee。
# 远程会先清空目录（保留本次上传的压缩包），再解压；可选保留 .env*。
#
# 环境变量（可选）：
#   DEPLOY_USER   默认 root
#   DEPLOY_HOST   默认 artiqore.com
#   REMOTE_DIR    默认 ~/website/artsee
#   ARCHIVE_NAME  默认 artsee-web.tar.gz
#   SKIP_BUILD=1  跳过本地 npm run build（仅重新打包已有 .next）
#   PRESERVE_REMOTE_ENV=0  设为 0 时不备份/恢复 .env（默认 1）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEB_DIR="${REPO_ROOT}/web"
BUILD_DIR="${WEB_DIR}/.next/standalone"

DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_HOST="${DEPLOY_HOST:-artiqore.com}"
SSH_TARGET="${DEPLOY_USER}@${DEPLOY_HOST}"
REMOTE_DIR="${REMOTE_DIR:-~/website/artsee}"
ARCHIVE_NAME="${ARCHIVE_NAME:-artsee-web.tar.gz}"
ARCHIVE_PATH="${REPO_ROOT}/${ARCHIVE_NAME}"
PRESERVE_REMOTE_ENV="${PRESERVE_REMOTE_ENV:-1}"
SSH_KEY_FILE="${SSH_KEY_FILE:-}"

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=60)
if [[ -n "${SSH_KEY_FILE}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY_FILE}")
fi

log() { printf '%s\n' "$*"; }

require_dir() {
  if [[ ! -d "$1" ]]; then
    log "错误：缺少目录 $1"
    exit 1
  fi
}

require_dir "${WEB_DIR}"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  log "构建生产版本（Next.js standalone）..."
  (cd "${WEB_DIR}" && npm run build)
else
  log "跳过构建（SKIP_BUILD=1）"
fi

if [[ ! -d "${BUILD_DIR}" ]]; then
  log "错误：未找到 ${BUILD_DIR}，请先成功执行 next build（standalone）。"
  exit 1
fi

log "将静态资源与清单复制到 standalone 输出..."
# monorepo standalone：运行入口在 web/server.js，浏览器静态资源在 web/.next/static
mkdir -p "${BUILD_DIR}/web/.next"
rm -rf "${BUILD_DIR}/web/.next/static"
cp -r "${WEB_DIR}/.next/static" "${BUILD_DIR}/web/.next/static"
rm -rf "${BUILD_DIR}/public"
if [[ -d "${WEB_DIR}/public" ]]; then
  cp -r "${WEB_DIR}/public" "${BUILD_DIR}/public"
else
  mkdir -p "${BUILD_DIR}/public"
fi
cp "${WEB_DIR}/package.json" "${BUILD_DIR}/package.json"
[[ -f "${WEB_DIR}/package-lock.json" ]] && cp "${WEB_DIR}/package-lock.json" "${BUILD_DIR}/package-lock.json"
[[ -f "${WEB_DIR}/ecosystem.config.js" ]] && cp "${WEB_DIR}/ecosystem.config.js" "${BUILD_DIR}/ecosystem.config.js"

log "打包: ${ARCHIVE_NAME}"
rm -f "${ARCHIVE_PATH}"
# 避免 macOS 扩展属性写入 tarball，防止 Linux 上 tar 报 LIBARCHIVE.xattr 警告
COPYFILE_DISABLE=1 tar czf "${ARCHIVE_PATH}" -C "${BUILD_DIR}" .

log "确保远程目录存在..."
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "mkdir -p ${REMOTE_DIR}"

log "上传压缩包..."
# 使用 rsync 替代 scp，更稳定且支持断点续传
RSYNC_SSH_OPTS=""
for opt in "${SSH_OPTS[@]}"; do
  RSYNC_SSH_OPTS="${RSYNC_SSH_OPTS} ${opt}"
done
rsync -avz --progress --timeout=300 -e "ssh${RSYNC_SSH_OPTS}" "${ARCHIVE_PATH}" "${SSH_TARGET}:${REMOTE_DIR}/" || {
  log "rsync 失败，尝试使用 scp..."
  scp "${SSH_OPTS[@]}" "${ARCHIVE_PATH}" "${SSH_TARGET}:${REMOTE_DIR}/"
}

log "远程解压并清理旧文件..."
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" bash -s <<REMOTE_SCRIPT
set -euo pipefail
REMOTE_DIR_EXPANDED="\$(eval echo ${REMOTE_DIR})"
cd "\$REMOTE_DIR_EXPANDED"

ARCHIVE_NAME='${ARCHIVE_NAME}'
PRESERVE='${PRESERVE_REMOTE_ENV}'

if [[ "\$PRESERVE" == "1" ]]; then
  rm -f /tmp/artsee-deploy-env.tar
  if ls .env* >/dev/null 2>&1; then
    tar cf /tmp/artsee-deploy-env.tar .env*
  fi
fi

# 删除当前目录下除本次压缩包以外的所有内容（避免残留旧版本文件）
find . -mindepth 1 -maxdepth 1 ! -name "\$ARCHIVE_NAME" -exec rm -rf {} +

tar xzf "\$ARCHIVE_NAME"
rm -f "\$ARCHIVE_NAME"

if [[ "\$PRESERVE" == "1" ]] && [[ -f /tmp/artsee-deploy-env.tar ]]; then
  tar xf /tmp/artsee-deploy-env.tar
  rm -f /tmp/artsee-deploy-env.tar
fi

mkdir -p logs

echo "安装生产依赖（若 package.json 存在）..."
if [[ -f package.json ]]; then
  if [[ -x /usr/local/bin/npm24 ]]; then
    /usr/local/bin/npm24 install --omit=dev --no-audit --no-fund
  else
    npm install --omit=dev --no-audit --no-fund
  fi
fi

echo "重启 PM2..."
if [[ -x /usr/local/bin/pm2 ]]; then
  PM2=/usr/local/bin/pm2
else
  PM2=pm2
fi
# 先下线并从 PM2 移除，再释放 3000（避免孤儿 next-server 导致 EADDRINUSE）
\$PM2 delete artsee-web 2>/dev/null || true
if command -v fuser >/dev/null 2>&1; then
  fuser -k 3000/tcp 2>/dev/null || true
fi
sleep 1
\$PM2 start ecosystem.config.js --env production
\$PM2 save

echo "远程部署完成。"
REMOTE_SCRIPT

log "删除本地压缩包..."
rm -f "${ARCHIVE_PATH}"

log "全部完成。"
