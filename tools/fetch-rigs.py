#!/usr/bin/env python3
"""Find, download and audit an R6 rig for every character module.

    python3 -I tools/fetch-rigs.py --quarantine DIR [--only Name,Name] [--skip Name,Name]
                                   [--per-name N] [--report FILE] [--dry-run]

For each module in src/ReplicatedStorage/Characters/{Killers,Survivors}:
  1. skip it if a rig already exists at the path the game looks it up
     (ReplicatedStorage.Assets.Characters.<Killer|Survivor>.<Name>)
  2. search the Creator Store (tools/search-models.sh), verified creators first
  3. download up to N candidates into the quarantine DIR (never under src/)
  4. inspect each (tools/inspect-rbxm.py): must pass the R6 rig check
     and have no flagged scripts; script-free models are preferred
  5. copy the winner to src/ReplicatedStorage/Assets/Characters/<Role>/<Name>.rbxm

ROBLOX_API_KEY is only inherited by the child scripts; it is never read or printed here.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
CHARS = os.path.join(ROOT, "src", "ReplicatedStorage", "Characters")
RIGS = os.path.join(ROOT, "src", "ReplicatedStorage", "Assets", "Characters")
ROLE_DIRS = {"Killers": "Killer", "Survivors": "Survivor"}
# Extra children a specific character's code indexes on the rig.
EXPECT = {"Commander": ["Grenade", "Deagle/FirePart"]}


def modules():
    for folder, role in ROLE_DIRS.items():
        d = os.path.join(CHARS, folder)
        for f in sorted(os.listdir(d)):
            if f.endswith(".luau"):
                name = f[:-5]
                src = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
                m = re.search(r'Config\s*=\s*\{.*?\bName\s*=\s*"([^"]+)"', src, re.S)
                yield name, role, (m.group(1) if m else name)


def rig_exists(name, role):
    base = os.path.join(RIGS, role, name)
    return any(os.path.exists(base + ext) for ext in ("", ".rbxm", ".rbxmx", ".model.json"))


def search(query, count=30):
    p = subprocess.run([os.path.join(TOOLS, "search-models.sh"), query, str(count)],
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip())
    rows = []
    for line in p.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 5 and parts[0].isdigit():
            rows.append({"id": parts[0], "name": parts[1], "creator": parts[2],
                         "verified": parts[3] == "verified", "scripts": parts[4]})
    return rows


def inspect(path, expect):
    cmd = [sys.executable, "-I", os.path.join(TOOLS, "inspect-rbxm.py"), path, "--rig", "--scripts", "--json"]
    for e in expect:
        cmd += ["--expect", e]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode == 2:
        return {"error": p.stderr.strip()}
    return json.loads(p.stdout)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quarantine", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--skip", default="")
    ap.add_argument("--per-name", type=int, default=8)
    ap.add_argument("--report", default=None)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    q = os.path.abspath(a.quarantine)
    if q.startswith(os.path.join(ROOT, "src")):
        sys.exit("quarantine must be outside src/")
    only = {x for x in a.only.split(",") if x}
    skip = {x for x in a.skip.split(",") if x}
    report = []

    for name, role, display in modules():
        if (only and name not in only) or name in skip:
            continue
        entry = {"name": name, "role": role, "display": display,
                 "target": os.path.relpath(os.path.join(RIGS, role, name + ".rbxm"), ROOT)}
        report.append(entry)
        if rig_exists(name, role):
            entry["status"] = "exists"
            print(f"[{name}] rig already present, skipped", flush=True)
            continue
        queries = [f"{display} R6", f"{display} rig", display]
        seen, cands = set(), []
        try:
            for qq in queries:
                for r in search(qq):
                    if r["id"] not in seen:
                        seen.add(r["id"]); cands.append(r)
                if len(cands) >= a.per_name * 2:
                    break
        except RuntimeError as e:
            entry["status"] = "search-failed"; entry["error"] = str(e)
            print(f"[{name}] search failed: {e}", flush=True)
            if "HTTP 401" in str(e) or "HTTP 403" in str(e) or "not set" in str(e):
                break
            continue
        # verified creators first, then models reporting no scripts; otherwise keep search order
        cands.sort(key=lambda r: (not r["verified"], r["scripts"] not in ("scripts:0",)))
        entry["candidates"] = []
        best_clean, best_scripted = None, None
        qdir = os.path.join(q, name)
        os.makedirs(qdir, exist_ok=True)
        for r in cands[: a.per_name]:
            path = os.path.join(qdir, r["id"] + ".rbxm")
            c = dict(r)
            entry["candidates"].append(c)
            if a.dry_run:
                continue
            p = subprocess.run([os.path.join(TOOLS, "fetch-model.sh"), r["id"], path],
                               capture_output=True, text=True)
            if p.returncode != 0:
                c["result"] = "download-failed: " + p.stderr.strip(); continue
            info = inspect(path, EXPECT.get(name, []))
            if "error" in info:
                c["result"] = "unparseable: " + info["error"]; continue
            probs = info["rig"]["problems"]
            flagged = [s for s in info["scripts"] if s["flags"]]
            c["rig_problems"] = probs
            c["rig_notes"] = info["rig"]["notes"]
            c["scripts_found"] = [f'{s["class"]} {s["path"]}' for s in info["scripts"]]
            c["flagged"] = [{"path": s["path"], "flags": s["flags"]} for s in flagged]
            if probs:
                c["result"] = "rejected: not a compatible R6 rig"
            elif flagged:
                c["result"] = "rejected: suspicious scripts"
            elif not info["scripts"]:
                c["result"] = "compatible, no scripts"
                best_clean = best_clean or (r, path)
            else:
                c["result"] = "compatible, has scripts (unflagged)"
                best_scripted = best_scripted or (r, path)
            print(f"[{name}] {r['id']} {r['name']!r} by {r['creator']}: {c['result']}", flush=True)
            if best_clean:
                break
        pick = best_clean or best_scripted
        if pick and not a.dry_run:
            dest = os.path.join(ROOT, entry["target"])
            shutil.copyfile(pick[1], dest)
            entry["status"] = "installed"
            entry["picked"] = pick[0]
            print(f"[{name}] -> installed {pick[0]['id']} at {entry['target']}", flush=True)
        elif not a.dry_run:
            entry["status"] = "no-compatible-rig"
            print(f"[{name}] no compatible rig among {len(entry['candidates'])} candidates", flush=True)

    if a.report:
        with open(a.report, "w") as f:
            json.dump(report, f, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
