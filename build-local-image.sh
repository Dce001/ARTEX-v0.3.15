#!/usr/bin/env bash
# 从本仓库源码构建本地镜像 artex:local（不联网拉取任何 ARTEX 预构建镜像）
#
# 步骤与官方 Dockerfile 注释、install.sh「② 本地编译运行」完全一致，
# 只是把产物打成镜像，好让 docker compose 能直接用。
# 前置：Go >= 1.26、Node/npm、Docker（含 buildx）。
set -euo pipefail
cd "$(dirname "$0")"

case "$(uname -m)" in
  x86_64|amd64)  GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) echo "不支持的架构: $(uname -m)" >&2; exit 1 ;;
esac

for c in go npm docker; do
  command -v "$c" >/dev/null 2>&1 || { echo "缺少依赖: $c" >&2; exit 1; }
done

echo "[1/4] 构建前端静态产物"
( cd web && npm ci && npm run build:static )

echo "[2/4] 放入 Go embed 目录"
mkdir -p server/webui
rm -rf server/webui/dist
cp -r web/out server/webui/dist

echo "[3/4] 编译内嵌前端的单二进制 (GOARCH=$GOARCH)"
mkdir -p "dist/$GOARCH"
CGO_ENABLED=0 GOARCH="$GOARCH" go build -tags embedui -trimpath -o "dist/$GOARCH/artex" ./cmd/artex

echo "[4/4] 构建镜像 artex:local"
docker build -t artex:local .

echo
echo "完成。接下来："
echo "  cp .env.example .env        # 务必设置 POSTGRES_PASSWORD"
echo "  docker compose up -d        # 用 artex:local，不拉取任何第三方镜像"
