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
EXPECT = {}  # Commander's Grenade/Deagle are baked in by tools/bake-rigs.py
# Other names a character is published under: used for both searching and title matching.
ALIASES = {
    "FreddyFazbear": ["Freddy", "FNAF Freddy"],
    "HuggyWuggy": ["Huggy", "Poppy Playtime Huggy"],
    "RainbowFriend": ["Rainbow Friends", "Blue Rainbow Friends"],
    "Creeper": ["Minecraft Creeper"],
    "Enderman": ["Minecraft Enderman"],
    "Knuckles": ["Sonic Knuckles", "Knuckles the Echidna"],
    "Tails": ["Sonic Tails", "Miles Tails Prower"],
    "Sans": ["Undertale Sans", "Sans skeleton"],
    "Patrick": ["Patrick Star", "Spongebob Patrick"],
    "Pikachu": ["Pokemon Pikachu"],
    "Minion": ["Minions", "Despicable Me Minion"],
    "Cuphead": ["Cuphead Mugman"],
    "Superman": ["Superman DC", "Man of Steel"],
    "Fog": ["Fog monster"],
    "Overseer": ["Overseer"],
    "Shrek": ["Shrek ogre", "Shrek R6 rig"],
    "SpongeBob": ["Spongebob Squarepants", "Sponge Bob"],
    "Commander": ["Soldier Commander", "Military Commander", "Army Commander"],
}


def modules():
    for folder, role in ROLE_DIRS.items():
        d = os.path.join(CHARS, folder)
        for f in sorted(os.listdir(d)):
            if f.endswith(".luau"):
                name = f[:-5]
                src = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
                m = re.search(r'Config\s*=\s*\{.*?\bName\s*=\s*"([^"]+)"', src, re.S)
                yield name, role, (m.group(1) if m else name)


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def rig_exists(name, role):
    base = os.path.join(RIGS, role, name)
    return any(os.path.exists(base + ext) for ext in ("", ".rbxm", ".rbxmx", ".model.json"))


def search(query, count=60):
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


def inspect(path, expect, rig_name=None):
    cmd = [sys.executable, "-I", os.path.join(TOOLS, "inspect-rbxm.py"), path, "--rig", "--scripts", "--json"]
    if rig_name:
        cmd += ["--rig-name", rig_name]
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
    ap.add_argument("--per-name", type=int, default=15)
    ap.add_argument("--report", default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--allow-repair", action="store_true",
                    help="accept rigs tools/bake-rigs.py can repair when no clean rig exists (run it after installing)")
    ap.add_argument("--exclude-ids", default="", help="comma-separated asset IDs never to pick")
    a = ap.parse_args()
    q = os.path.abspath(a.quarantine)
    if q.startswith(os.path.join(ROOT, "src")):
        sys.exit("quarantine must be outside src/")
    only = {x for x in a.only.split(",") if x}
    skip = {x for x in a.skip.split(",") if x}
    excluded = {x for x in a.exclude_ids.split(",") if x}
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
        aliases = ALIASES.get(name, [])
        queries = [f"{display} R6", f"{display} rig", display]
        for al in aliases:
            queries += [f"{al} R6", al]
        seen, cands = set(), []
        try:
            for qq in queries:
                for r in search(qq):
                    if r["id"] not in seen:
                        seen.add(r["id"]); cands.append(r)
                if len(cands) >= 400:
                    break
        except RuntimeError as e:
            entry["status"] = "search-failed"; entry["error"] = str(e)
            print(f"[{name}] search failed: {e}", flush=True)
            if "HTTP 401" in str(e) or "HTTP 403" in str(e) or "not set" in str(e):
                break
            continue
        # Only models whose title actually names the character: a rig check alone
        # happily accepts any random R6 avatar the search falls back to.
        keys = {norm(name), norm(display)} | {norm(x) for x in aliases}
        cands = [r for r in cands if any(k and k in norm(r["name"]) for k in keys)
                 and r["id"] not in excluded]
        # verified creators first, then models reporting no scripts; otherwise keep search order
        cands.sort(key=lambda r: (not r["verified"], r["scripts"] not in ("scripts:0",)))
        entry["candidates"] = []
        best_clean, best_scripted, best_repair = None, None, None
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
            info = inspect(path, EXPECT.get(name, []), name)
            if "error" in info:
                c["result"] = "unparseable: " + info["error"]; continue
            probs = info["rig"]["problems"]
            flagged = [s for s in info["scripts"] if s["flags"]]
            c["rig_problems"] = probs
            c["rig_notes"] = info["rig"]["notes"]
            c["scripts_found"] = [f'{s["class"]} {s["path"]}' for s in info["scripts"]]
            c["flagged"] = [{"path": s["path"], "flags": s["flags"]} for s in flagged]
            c["repair"] = info["rig"].get("repair"), info["rig"].get("repair_detail")
            if probs and not (a.allow_repair and c["repair"][0] == "repairable"):
                c["result"] = "rejected: not a compatible R6 rig"
            elif flagged:
                c["result"] = "rejected: suspicious scripts"
            elif info["scripts"]:
                c["result"] = "compatible, has scripts (unflagged)"
                best_scripted = best_scripted or (r, path)
            elif probs:
                c["result"] = "repairable by tools/bake-rigs.py: " + c["repair"][1]
                best_repair = best_repair or (r, path, c["repair"][1])
            else:
                c["result"] = "compatible, no scripts"
                best_clean = best_clean or (r, path)
            print(f"[{name}] {r['id']} {r['name']!r} by {r['creator']}: {c['result']}", flush=True)
            if best_clean:
                break
        # Scripted rigs are never auto-installed: a backdoor can pass every pattern
        # check. They are left in quarantine for the user to review.
        if best_scripted and not best_clean:
            entry["needs_review"] = best_scripted[0]
        pick = best_clean or best_repair
        if pick and not a.dry_run:
            if pick is best_repair and not best_clean:
                entry["runtime_repair"] = best_repair[2]
            dest = os.path.join(ROOT, entry["target"])
            shutil.copyfile(pick[1], dest)
            entry["status"] = "installed"
            entry["picked"] = pick[0]
            print(f"[{name}] -> installed {pick[0]['id']} at {entry['target']}", flush=True)
            if entry.get("runtime_repair"):
                print(f"[{name}]    needs repair: run tools/bake-rigs.py {name}", flush=True)
        elif not a.dry_run:
            entry["status"] = "no-compatible-rig"
            print(f"[{name}] no compatible rig among {len(entry['candidates'])} candidates", flush=True)

    if a.report:
        with open(a.report, "w") as f:
            json.dump(report, f, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
