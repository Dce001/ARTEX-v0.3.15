# ARTEX v0.3.15 官方原版快照 · 来源与说明

> 本文件、`docker-compose.override.yml`、`Dockerfile.build`、`setup.sh`、
> `build-local-image.sh`、`verify-original.sh` 共 6 个文件是**后加的加固层**，
> 不属于原作者发布的源码。其余 600 个文件与原作者 Autumn-27 最后发布的
> v0.3.15 **逐字节相同**。

---

## 1. 这是什么

原作者 `Autumn-27/artex` 已于 2026 年 10 月删库停更，**最后一个公开版本就是
v0.3.15**（2026-10-07，commit `e6ec569`）。Go module proxy 会永久缓存它见过的
版本，且 `sum.golang.org` 是带签名的透明日志，缓存内容无法被任何人（包括 Fork
维护者、镜像站）篡改。本仓库的内容即从该不可变缓存取回，并做了密码学验证：

| 项 | 值 |
|---|---|
| 原始 Go module zip SHA-256 | `a7cc81dca72a6afe90efefc469f7a0537599aa7d57b3982dff0a2a1af6173ae3` |
| Go dirhash.Hash1（本地复现） | `h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE=` |
| sum.golang.org 官方记录 | `h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE=` ← **一致** |
| 文件数 | 600 |
| `v0.3.16` | 404，不存在（是投毒二进制伪造的版本号） |

不信任何人，就自己跑 `bash verify-original.sh`，它会本地复现上面的 h1。

## 2. 关于「后续 pull」

原版没有上游，也不会再有更新（上游已删库停更）。所以这个仓库就是一份
**固定、可复现的安装源**：`git clone` / `git pull` 拿到的永远是同一版
v0.3.15，再加上你之后自己推上去的提交。版本锁死意味着今天装和一年后装，
内容完全一致 —— 这正是重装系统时最需要的性质。

仓库按两层组织，方便随时看清「哪些是原版、哪些是后加的」：

| 层 | commit | 内容 |
|---|---|---|
| 基准 | tag `v0.3.15-official` | 纯官方 600 文件，逐字节 |
| 加固层 | `main` 上的后续 commit | 6 个新文件（本文件等） |

随时用 `git diff v0.3.15-official..HEAD` 查看所有非官方改动。

> 注：官方自带 `.gitattributes`（`*.bat text eol=crlf` / `*.sh text eol=lf`），
> 所以 `start.bat` 在 git 对象里以 LF 存储、clone 时自动还原成 CRLF。
> 这是 git 的标准行为，**checkout 后的工作树才是逐字节原版**。
> 因此 `verify-original.sh` 对**工作树文件**复现 h1，而不是对 git blob。

## 3. 新电脑一条命令安装

前提：装好 Docker（Windows / macOS 装 Docker Desktop；Linux 下脚本会尝试自动安装）。

```bash
git clone <本仓库地址>.git && cd <仓库名> && ./setup.sh
```

`setup.sh` 做四件事：

1. 检测 Docker，没有则在 Linux 上尝试自动安装；
2. 生成随机数据库密码写入 `.env`（已存在则不动，幂等，可反复执行）；
3. `docker compose up -d --build` —— 从源码在容器内完整构建镜像并启动；
4. 打印访问地址（控制台 `:8787`，MITM 代理 `127.0.0.1:8788`）。

首次构建约 10–20 分钟（要下载语言工具链和 Playwright 浏览器），之后
`docker compose up -d` 重启都是秒级。

**关于「拉镜像」的准确说法**：构建过程会拉取**官方基础镜像**
（python / node / golang / postgres）以及 npm、Go 依赖 —— 这些是构建必需的
公开依赖；被彻底禁掉的只有 `autumn27/artex:*` 这个来源不明的**应用镜像**。

## 4. 加固层做了什么

`docker-compose.override.yml`（Compose 默认自动加载）把 artex 服务指向本地
构建并禁止拉取：

```yaml
services:
  artex:
    image: artex:local
    build:
      context: .
      dockerfile: Dockerfile.build
    pull_policy: never
```

- `build` → `Dockerfile.build`：新增的三阶段构建文件（node 构建前端 →
  golang 编译内嵌单二进制 → 运行层）。**运行层与官方 Dockerfile 逐行一致**，
  只是把「COPY 预编译二进制」换成「COPY 上一步编译产物」。官方 Dockerfile
  本身要求预编译产物，直接用它构建会失败，所以不能直接复用。
- `image: artex:local` + `pull_policy: never`：覆盖官方 compose 里的
  `autumn27/artex:${ARTEX_TAG:-latest}`。这样无论执行 `docker compose pull`、
  `up -d` 还是官方 `install.sh` 的「① 全部 Docker」，都**不会拉取任何
  第三方 ARTEX 预构建镜像**。

官方 600 个文件一个字节都没动，所以 h1 依然成立。

## 5. 备选安装方式

**A. 完全不碰镜像（官方脚本，需本机 Go ≥ 1.26 + Node/npm）**

```bash
./install.sh          # 选「② 本地编译运行」
```

**B. 宿主机有 Go/Node，想手动构建本地镜像**

```bash
./build-local-image.sh && docker compose up -d
```

**C. 网络受限时加速依赖下载**

```bash
docker compose build --build-arg GOPROXY=https://goproxy.cn,direct
docker compose up -d
```

## 6. 不要这样做

- `docker compose -f docker-compose.yml up -d` —— 显式指定 `-f` 会跳过
  override，重新暴露可变 tag。
- 删除或改写 `docker-compose.override.yml`、把 `image` 改回 `autumn27/artex:*`。
- 在页面里点「一键更新」：官方 `selfupdate` 会从 GitHub Release 拉二进制，
  上游已删库，来源不可控。

## 7. 已知边界

- 本仓库**不含原作者的 git 提交历史**：Go module zip 只有某个版本的文件快照，
  没有 `.git`。因此它是「某个发布点的完整源码」，不是「带完整历史的 fork」。
- `Dockerfile.build` / `setup.sh` 是加固层新增文件，未经上游验证；若在你的
  环境构建失败，可改用第 5 节的方式 A。
- 快照是静态的，不会收到上游安全修复（上游已不存在）。请自行关注社区安全通告。

## 8. 自行核验

```bash
bash verify-original.sh
```

脚本做四件事：列出官方 600 文件 → 复现 dirhash.Hash1 与 sumdb 比对 →
扫描本次投毒事件的特征字符串 → 检查覆盖层是否仍锁死本地构建。
任何一项不通过都会明确标出。
