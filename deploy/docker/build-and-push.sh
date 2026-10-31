#!/usr/bin/env bash
# 紫微斗数 —— 一键构建 + 本地冒烟 + 推送 Docker Hub
#
# 用法：
#   DOCKERHUB_USER=你的用户名 DOCKERHUB_TOKEN=你的token ./build-and-push.sh
#   DOCKERHUB_USER=xxx ./build-and-push.sh            # 已登录过则无需 token
#   DOCKERHUB_USER=xxx ./build-and-push.sh --multi    # 构建 amd64+arm64 并直接推送
#   DOCKERHUB_USER=xxx ./build-and-push.sh --no-push  # 只构建+验证，不推送
#
# 环境变量：
#   NEXT_PUBLIC_SITE_URL  站点根地址，构建期固化进 sitemap/robots（默认 http://localhost:3000）
#   注意：改这个值必须重新构建，容器启动后再改环境变量无效。
set -euo pipefail

IMAGE_NAME="ziwei-doushu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

MULTI=0
PUSH=1
for arg in "$@"; do
  case "$arg" in
    --multi)   MULTI=1 ;;
    --no-push) PUSH=0 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

# ── 前置检查 ──
if ! docker info >/dev/null 2>&1; then
  echo "✗ Docker 引擎未就绪。请先启动 Docker Desktop / dockerd。" >&2
  exit 1
fi

: "${DOCKERHUB_USER:?请设置 DOCKERHUB_USER=你的Docker Hub用户名}"
REF="$DOCKERHUB_USER/$IMAGE_NAME"

SITE_URL="${NEXT_PUBLIC_SITE_URL:-http://localhost:3000}"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
DATE_TAG="$(date +%Y%m%d)"
REF_DATE_SAFE="${DATE_TAG}-${GIT_SHA}"

echo "镜像仓库: $REF"
echo "站点地址: $SITE_URL  （构建期固化）"
echo "版本标记: latest / $GIT_SHA / $REF_DATE_SAFE"
echo "----------------------------------------"

# ── 登录 ──
if [ -n "${DOCKERHUB_TOKEN:-}" ]; then
  echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
fi

if [ "$MULTI" -eq 1 ]; then
  # ── 多架构：buildx 直接推，本地无法 docker run 验证 ──
  echo "模式: 多架构 (linux/amd64,linux/arm64) → 直接推送"
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f deploy/docker/Dockerfile \
    --build-arg "NEXT_PUBLIC_SITE_URL=$SITE_URL" \
    -t "$REF:latest" \
    -t "$REF:$GIT_SHA" \
    -t "$REF:$REF_DATE_SAFE" \
    --push \
    .
  echo "✓ 多架构镜像已推送"
  echo "  拉取: docker run -d -p 3000:3000 $REF:latest"
  exit 0
fi

# ── 单架构：构建 → 冒烟 → 推送 ──
echo "模式: 单架构（本机架构）"
docker build \
  -f deploy/docker/Dockerfile \
  --build-arg "NEXT_PUBLIC_SITE_URL=$SITE_URL" \
  -t "$REF:latest" \
  -t "$REF:$GIT_SHA" \
  -t "$REF:$REF_DATE_SAFE" \
  .

echo "----------------------------------------"
echo "启动临时容器做冒烟验证 ..."
HOST_PORT="${SMOKE_PORT:-13000}"
CID="$(docker run -d --rm -p "127.0.0.1:${HOST_PORT}:3000" "$REF:$GIT_SHA")"
cleanup() { docker rm -f "$CID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 等健康检查通过（镜像自带 HEALTHCHECK，start-period 25s）
health="starting"
for _ in $(seq 1 40); do
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CID" 2>/dev/null || echo none)"
  [ "$health" = "healthy" ] && break
  sleep 2
done

if [ "$health" != "healthy" ]; then
  echo "✗ 健康检查未通过（状态: $health），最近日志：" >&2
  docker logs --tail 40 "$CID" >&2
  exit 1
fi
echo "✓ 容器健康检查通过"

EXPECT_DOMAIN="$(echo "$SITE_URL" | sed -E 's#^https?://##')" \
  bash deploy/docker/verify.sh "http://127.0.0.1:${HOST_PORT}"

cleanup
trap - EXIT

if [ "$PUSH" -eq 1 ]; then
  echo "----------------------------------------"
  echo "推送镜像 ..."
  docker push --all-tags "$REF"
  echo "✓ 已推送: $REF:{latest,$GIT_SHA,$REF_DATE_SAFE}"
else
  echo "----------------------------------------"
  echo "已跳过推送（--no-push）"
fi

cat <<EOF

────────────────────────────────────────
使用方式：
  docker run -d --name ziwei -p 3000:3000 \\
    --read-only --tmpfs /tmp:size=64m --tmpfs /app/.next/cache:size=128m \\
    $REF:latest

  # 或 compose（deploy/docker/docker-compose.yml 里把 build 换成 image）
  浏览器打开 http://127.0.0.1:3000

回滚：
  docker run ... $REF:<上一个提交SHA>
────────────────────────────────────────
EOF
