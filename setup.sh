#!/usr/bin/env bash
# 一键安装：从源码本地构建镜像并启动。
#
#   git clone <本仓库>.git && cd <本仓库> && ./setup.sh
#
# 前提：已装 Docker（Windows/macOS 装 Docker Desktop；Linux 脚本会自动装）。
# 幂等：重复执行不会覆盖已有 .env，也不会重置数据库。
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m错误:\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1) Docker ─────────────────────────────────────────────
if ! (command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1); then
  say "未检测到 Docker，尝试自动安装"
  if [ "$(uname -s)" = "Linux" ] && command -v curl >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
    if command -v sudo >/dev/null 2>&1; then
      sudo usermod -aG docker "$USER" 2>/dev/null || true
    fi
  else
    die "请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop/"
  fi
fi
docker compose version >/dev/null 2>&1 || die "Docker Compose 不可用，请升级 Docker"

# ── 2) .env（幂等，随机数据库密码）────────────────────────
if [ ! -f .env ]; then
  say "生成 .env（随机数据库密码）"
  PW="$(openssl rand -hex 24 2>/dev/null || tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PW/" .env.example > .env
  chmod 600 .env
  echo "  已写入 .env（权限 600）"
else
  echo "  已存在 .env，保持不变"
fi

# ── 3) 从源码构建并启动 ───────────────────────────────────
say "从源码构建并启动（首次约 10-20 分钟，取决于网络）"
docker compose up -d --build

# ── 4) 结果 ──────────────────────────────────────────────
say "安装完成"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$IP" ] || IP="localhost"
echo "  控制台    : http://localhost:8787"
echo "  局域网    : http://${IP}:8787"
echo "  MITM 代理 : 127.0.0.1:8788（仅本机监听）"
echo "  查看日志  : docker compose logs -f artex"
echo "  停止      : docker compose down"
echo
echo "  首次使用请在 /setup 页面创建管理员账号；LLM 密钥可在 .env 或界面里配置。"
