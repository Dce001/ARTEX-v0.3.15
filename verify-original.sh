#!/usr/bin/env bash
# ============================================================
# ARTEX v0.3.15 官方原版 · 完整性自证脚本
#
# 用法：在仓库根目录执行 bash verify-original.sh
# 原理：对「工作树里的官方 600 个文件」复现 Go dirhash.Hash1，
#       与 sum.golang.org 的带签名记录比对；一致即密码学证明
#       内容与原作者发布时逐字节相同。
# 注意：官方 .gitattributes 会让 git 在对象里规范化换行，
#       所以必须对 checkout 后的工作树文件计算，而不是 git blob。
# ============================================================
set -u
cd "$(dirname "$0")"

python3 - <<'PYEOF'
import os, subprocess, hashlib, base64

OFFICIAL = "h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE="
ADDED = {"ORIGIN.md", "docker-compose.override.yml",
         "build-local-image.sh", "verify-original.sh"}
PREFIX = "github.com/Autumn-27/artex@v0.3.15/"
IOCS = ["verifyCaptcha", 'json:"captcha"', "tomicdd", "ce85d8369ccc"]

print("=== ARTEX v0.3.15 官方原版核验 ===\n")

# ---- 1. 官方文件清单 ----
files = None
src = ""
if os.path.isdir(".git"):
    try:
        out = subprocess.check_output(
            ["git", "-c", "core.quotepath=false", "ls-tree", "-r",
             "--name-only", "-z", "v0.3.15-official"],
            stderr=subprocess.DEVNULL)
        files = sorted(s.decode("utf-8") for s in out.split(b"\0") if s)
        src = "git tag v0.3.15-official"
    except Exception:
        pass
if not files:
    files = []
    for base, dirs, fs in os.walk("."):
        dirs[:] = [d for d in dirs if d != ".git"]
        for f in fs:
            rel = os.path.relpath(os.path.join(base, f), ".").replace(os.sep, "/")
            if rel not in ADDED:
                files.append(rel)
    files = sorted(files)
    src = "目录扫描（已排除 4 个加固层文件）"

print("[1/4] 官方文件清单：%s" % src)
print("      文件数 %d  %s" % (len(files), "OK" if len(files) == 600 else "警告：期望 600"))

# ---- 2. 复现 dirhash.Hash1 ----
h = hashlib.sha256()
missing = []
for rel in files:
    p = os.path.join(".", rel)
    if not os.path.isfile(p):
        missing.append(rel)
        continue
    d = open(p, "rb").read()
    h.update(("%s  %s\n" % (hashlib.sha256(d).hexdigest(),
                            PREFIX + rel)).encode("utf-8"))
h1 = "h1:" + base64.b64encode(h.digest()).decode()
ok = (h1 == OFFICIAL and not missing)
print("\n[2/4] 复现 Go dirhash.Hash1")
print("      本地复现  : " + h1)
print("      sumdb 官方: " + OFFICIAL)
print("      结果      : " + ("OK  完全一致，工作树与原作者发布内容逐字节相同"
                              if ok else "FAIL 不一致，文件已被改动"))
if missing:
    print("      缺失      : " + ", ".join(missing[:5]))

# ---- 3. 投毒特征扫描 ----
print("\n[3/4] 投毒特征扫描（仅官方 600 文件，应全部零命中）")
for pat in IOCS:
    found = []
    for rel in files:
        p = os.path.join(".", rel)
        if not os.path.isfile(p):
            continue
        try:
            if pat in open(p, "rb").read().decode("utf-8", "ignore"):
                found.append(rel)
        except Exception:
            pass
    print("      %-24s %s" % (pat, "OK  零命中" if not found
                              else "FAIL 命中 " + ", ".join(found[:3])))

# ---- 4. 镜像链路加固层 ----
print("\n[4/4] 镜像链路加固层")
ov = "docker-compose.override.yml"
if not os.path.isfile(ov):
    print("      FAIL 缺少 override，官方 compose 会拉可变 tag 镜像")
else:
    t = open(ov, encoding="utf-8").read()
    a = "artex:local" in t
    b = "pull_policy: never" in t
    print("      image 锁定 artex:local : " + ("OK" if a else "FAIL"))
    print("      pull_policy: never     : " + ("OK" if b else "FAIL"))
    print("      结论: " + ("OK  不会拉取任何第三方 ARTEX 镜像"
                            if a and b else "FAIL 加固层被改动，请检查"))

main = "docker-compose.yml"
if os.path.isfile(main):
    m = open(main, encoding="utf-8").read()
    print("      官方主 compose 仍为原文: " +
          ("OK" if "autumn27/artex:${ARTEX_TAG:-latest}" in m else "注意 已被修改"))

print("\n=== 核验结束 ===")
PYEOF
