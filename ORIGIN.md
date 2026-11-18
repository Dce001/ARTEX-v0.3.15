# ARTEX v0.3.15 官方原版快照 · 来源与说明

> 本文件、`docker-compose.override.yml`、`build-local-image.sh`、`verify-original.sh`
> 共 4 个文件是**后加的加固层**，不属于原作者发布的源码。
> 其余 600 个文件与原作者 Autumn-27 最后发布的 v0.3.15 **逐字节相同**。

---

## 1. 这是什么

原作者 `Autumn-27/artex` 已于 2026 年 10 月删库停更，**最后一个公开版本就是 v0.3.15**
（2026-10-07，commit `e6ec569`）。Go module proxy 会永久缓存它见过的版本，且
`sum.golang.org` 是带签名的透明日志，缓存内容无法被任何人（包括 Fork 维护者、镜像站）
篡改。本仓库的内容即从该不可变缓存取回，并做了密码学验证：

| 项 | 值 |
|---|---|
| 原始 Go module zip SHA-256 | `a7cc81dca72a6afe90efefc469f7a0537599aa7d57b3982dff0a2a1af6173ae3` |
| Go dirhash.Hash1（本地复现） | `h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE=` |
| sum.golang.org 官方记录 | `h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE=` ← **一致** |
| 文件数 | 600 |
| `v0.3.16` | 404，不存在（是投毒二进制伪造的版本号） |

不信任何人，就自己跑 `bash verify-original.sh`，它会本地复现上面的 h1。

## 2. 关于「后续 pull」必须说清

**原版没有上游，也不会再有更新。** 上游仓库已删除，原作者停更，
所以 `git pull` 拉不到「新版原版」—— 能 pull 到的是**你自己或协作者往这个仓库推的提交**。

仓库按两层组织，方便你随时看清「哪些是原版、哪些是后加的」：

| 层 | commit | 内容 |
|---|---|---|
| 基准 | tag `v0.3.15-official` | 纯官方 600 文件，逐字节 |
| 加固层 | `main` 上的后续 commit | 4 个新文件（本文件等） |

随时用 `git diff v0.3.15-official..HEAD` 查看所有非官方改动。
以后你自己的修改继续往 `main` 提，`git pull` 就是拉这些。

> 注：官方自带 `.gitattributes`（`*.bat text eol=crlf` / `*.sh text eol=lf`），
> 所以 `start.bat` 在 git 对象里以 LF 存储、clone 时自动还原成 CRLF。
> 这是 git 的标准行为，**checkout 后的工作树才是逐字节原版**。
> 因此 `verify-original.sh` 对**工作树文件**复现 h1，而不是对 git blob。

## 3. 为什么加了 `docker-compose.override.yml`

官方 `docker-compose.yml` 第 18 行是
`image: autumn27/artex:${ARTEX_TAG:-latest}`，**没有 `build:` 段**；
官方 `install.sh` 的「① 全部 Docker」还会执行 `docker compose pull`。
作者删库后，`latest` 是可变 tag、内容不可验证，正是本次供应链投毒的载体。

覆盖层把镜像改成 `artex:local` 并设 `pull_policy: never`：
Compose 默认自动加载 `docker-compose.override.yml`，于是无论执行
`docker compose pull` / `up -d` / `install.sh ①`，都**不会拉取任何第三方 ARTEX 镜像**。
本地没有 `artex:local` 时会直接报错，而不是静默下载来源不明的镜像。

官方 600 个文件一个字节都没动，所以 h1 依然成立。

## 4. 怎么部署（二选一，都安全）

**A. 推荐：完全不碰 ARTEX 镜像**

```bash
./install.sh          # 选「② 本地编译运行」
```
它会本地 `go build` 出二进制，只用一个官方 `postgres:16-alpine` 容器起数据库。
需要本机 Go >= 1.26 + Node/npm。

**B. 想用 compose 管理**

```bash
./build-local-image.sh                 # 从源码构建 artex:local
cp .env.example .env                   # 设置 POSTGRES_PASSWORD
docker compose up -d                   # 用本地镜像
```

`build-local-image.sh` 只是把官方 Dockerfile 注释里写的 4 步手动流程自动化
（构建前端 → 放到 Go embed 目录 → 编译单二进制 → `docker build`），
产物只在本机，不联网拉 ARTEX 镜像。

**不要这样做：**

- `docker compose -f docker-compose.yml up -d` —— 显式指定 `-f` 会跳过 override，重新暴露可变 tag。
- 删除或改写 `docker-compose.override.yml`、把 `image` 改回 `autumn27/artex:*`。
- 在页面里点「一键更新」：官方 `selfupdate` 会从 GitHub Release 拉二进制，上游已删库，来源不可控。

## 5. 已知边界

- 本仓库**不含原作者的 git 提交历史**：Go module zip 只有某个版本的文件快照，没有 `.git`。
  因此它是「某个发布点的完整源码」，不是「带完整历史的 fork」。
- 加固层只处理了**镜像拉取链路**。官方代码本身的自动更新、技能加载等机制保持原样，
  使用前请自行评估。
- 快照是静态的，不会收到上游安全修复（上游已不存在）。请自行关注社区安全通告。

## 6. 自行核验

```bash
bash verify-original.sh
```

脚本做四件事：列出官方 600 文件 → 复现 dirhash.Hash1 与 sumdb 比对 →
扫描本次投毒事件的特征字符串 → 检查覆盖层是否仍锁死本地镜像。
任何一项不通过都会明确标出。
