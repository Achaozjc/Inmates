# 临时脚本:计算磁盘 luau 文件的 djb2 哈希,与 Studio 导出结果对比
import os, sys

ROOT = r"D:\RobloxProject\axe"
ROOTS = ["ReplicatedCode", "ServerCode", "StarterPlayerScripts", "StarterGui"]

def djb2(s: bytes) -> int:
    h = 5381
    for b in s:
        h = (h * 33 + b) & 0xFFFFFFFF
    return h

def classify(fname: str):
    # 返回 (逻辑名, 类名);Rojo 命名约定
    if fname.endswith(".server.luau"):
        return fname[:-len(".server.luau")], "Script"
    if fname.endswith(".client.luau"):
        return fname[:-len(".client.luau")], "LocalScript"
    if fname.endswith(".luau"):
        return fname[:-len(".luau")], "ModuleScript"
    return None, None

disk = {}
for root_name in ROOTS:
    base = os.path.join(ROOT, root_name)
    if not os.path.isdir(base):
        continue
    for dirpath, dirs, files in os.walk(base):
        for f in files:
            name, cls = classify(f)
            if name is None:
                continue
            full = os.path.join(dirpath, f)
            with open(full, "rb") as fh:
                data = fh.read()
            data = data.replace(b"\r", b"").rstrip(b"\n")
            rel_dir = os.path.relpath(dirpath, ROOT).replace("\\", "/")
            if name == "init":
                # init.luau 代表父目录本身
                logical = rel_dir
            else:
                logical = rel_dir + "/" + name
            disk[logical] = (cls, len(data), djb2(data))

# 读取 Studio 导出
studio = {}
with open(os.path.join(ROOT, "tools", "studio_dump.txt"), encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        path, cls, ln, h = line.rsplit("|", 3)
        studio[path] = (cls, int(ln), int(h))

only_disk = sorted(set(disk) - set(studio))
only_studio = sorted(set(studio) - set(disk))
diff = []
for k in sorted(set(disk) & set(studio)):
    if disk[k][1] != studio[k][1] or disk[k][2] != studio[k][2]:
        diff.append((k, disk[k], studio[k]))

print(f"磁盘脚本总数: {len(disk)}  Studio脚本总数: {len(studio)}")
print(f"\n=== 仅磁盘存在 ({len(only_disk)}) ===")
for k in only_disk:
    print(f"  {k}  ({disk[k][0]}, {disk[k][1]} bytes)")
print(f"\n=== 仅Studio存在 ({len(only_studio)}) ===")
for k in only_studio:
    print(f"  {k}  ({studio[k][0]}, {studio[k][1]} bytes)")
print(f"\n=== 内容不一致 ({len(diff)}) ===")
for k, d, s in diff:
    print(f"  {k}  磁盘:{d[1]}B/{d[2]}  Studio:{s[1]}B/{s[2]}")
