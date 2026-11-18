#!/usr/bin/env bash
# 源码完整性校验：复现 Go dirhash.Hash1 并与 sum.golang.org 记录比对。
# 用法：在仓库根目录执行 bash verify-original.sh
set -u
cd "$(dirname "$0")"

python3 - <<'PYEOF'
import os, subprocess, hashlib, base64

OFFICIAL = "h1:maolFfGTu2/JCOSR1Lua75lNdA/DC9nfAYKonsmc/wE="
ADDED = {"docker-compose.override.yml",
         "Dockerfile.build", "setup.sh",
         "build-local-image.sh", "verify-original.sh"}
# 本地修订过的文件：哈希取 .pristine/ 中的原始内容计算。
MODIFIED = {"README.md": ".pristine/README.md"}
PREFIX = "github.com/Autumn-27/artex@v0.3.15/"
IOCS = ["verifyCaptcha", 'json:"captcha"', "tomicdd", "ce85d8369ccc"]

def official_bytes(rel):
    """被修订文件取 pristine 副本，其余取工作树。"""
    p = MODIFIED.get(rel, rel)
    p = os.path.join(".", p)
    if not os.path.isfile(p):
        return None
    return open(p, "rb").read()

print("=== ARTEX v0.3.15 源码完整性校验 ===\n")

# ---- 1. 基线文件清单 ----
files = None
src = ""
if os.path.isdir(".git"):
    try:
        out = subprocess.check_output(
            ["git", "-c", "core.quotepath=false", "ls-tree", "-r",
             "--name-only", "-z", "v0.3.15"],
            stderr=subprocess.DEVNULL)
        files = sorted(s.decode("utf-8") for s in out.split(b"\0") if s)
        src = "git tag v0.3.15"
    except Exception:
        pass
if not files:
    files = []
    for base, dirs, fs in os.walk("."):
        dirs[:] = [d for d in dirs if d not in (".git", ".pristine")]
        for f in fs:
            rel = os.path.relpath(os.path.join(base, f), ".").replace(os.sep, "/")
            if rel not in ADDED:
                files.append(rel)
    files = sorted(files)
    src = "目录扫描（已排除 6 个加固层文件）"

print("[1/4] 基线文件清单：%s" % src)
print("      文件数 %d  %s" % (len(files), "OK" if len(files) == 600 else "警告：期望 600"))
print("      本地修订  : " + ", ".join(sorted(MODIFIED)) +
      "（原始内容存于 .pristine/，哈希按原始内容计算）")

# ---- 2. 复现 dirhash.Hash1 ----
h = hashlib.sha256()
missing = []
for rel in files:
    d = official_bytes(rel)
    if d is None:
        missing.append(rel)
        continue
    h.update(("%s  %s\n" % (hashlib.sha256(d).hexdigest(),
                            PREFIX + rel)).encode("utf-8"))
h1 = "h1:" + base64.b64encode(h.digest()).decode()
ok = (h1 == OFFICIAL and not missing)
print("\n[2/4] 复现 Go dirhash.Hash1")
print("      本地复现  : " + h1)
print("      sumdb 官方: " + OFFICIAL)
print("      结果      : " + ("OK  与发布时的哈希记录一致"
                              if ok else "FAIL 不一致，文件已被改动"))
if missing:
    print("      缺失      : " + ", ".join(missing[:5]))

# ---- 3. 异常特征扫描 ----
print("\n[3/4] 异常特征扫描（基线文件，应全部零命中）")
for pat in IOCS:
    found = []
    for rel in files:
        d = official_bytes(rel)
        if d is None:
            continue
        try:
            if pat in d.decode("utf-8", "ignore"):
                found.append(rel)
        except Exception:
            pass
    print("      %-24s %s" % (pat, "OK  零命中" if not found
                              else "FAIL 命中 " + ", ".join(found[:3])))

# ---- 4. 本地构建配置检查 ----
print("\n[4/4] 本地构建配置检查")
ov = "docker-compose.override.yml"
if not os.path.isfile(ov):
    print("      FAIL 缺少 docker-compose.override.yml")
else:
    t = open(ov, encoding="utf-8").read()
    a = "artex:local" in t
    b = "pull_policy: never" in t
    c = "Dockerfile.build" in t and os.path.isfile("Dockerfile.build")
    print("      image 锁定 artex:local  : " + ("OK" if a else "FAIL"))
    print("      pull_policy: never      : " + ("OK" if b else "FAIL"))
    print("      build → Dockerfile.build: " + ("OK" if c else "FAIL"))
    print("      结论: " + ("OK  镜像为本地构建"
                            if a and b and c else "FAIL 配置被改动，请检查"))

main = "docker-compose.yml"
if os.path.isfile(main):
    m = open(main, encoding="utf-8").read()
    print("      主 compose 未改动     : " +
          ("OK" if "autumn27/artex:${ARTEX_TAG:-latest}" in m else "注意 已被修改"))

print("\n=== 核验结束 ===")
PYEOF
