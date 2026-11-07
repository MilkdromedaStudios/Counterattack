#!/usr/bin/env python3
"""Inspect a Roblox model/place file (.rbxm/.rbxl, binary or XML) without Studio.

    python3 -I tools/inspect-rbxm.py <file> [--tree] [--rig] [--scripts]
                                     [--dump-scripts DIR] [--expect PATH ...] [--json]

--tree           print every instance (Class "Name")
--rig            check the R6 character rig requirements from RIG_SETUP.md
--scripts        list every Script/LocalScript/ModuleScript and flag suspicious code
--dump-scripts   write each script's source to DIR for reading
--expect PATH    require a descendant of the root model, '/'-separated (e.g. Deagle/FirePart/Burst)
--json           machine-readable summary instead of text

Default (no flags): --rig --scripts.  Exit status 0 = rig OK and no red flags,
1 = problems found, 2 = could not parse.

Pure standard library. LZ4 chunks are decoded here; zstd chunks are reported as
unsupported. Treat the input as untrusted: this only parses bytes, never runs them.
"""
import argparse
import json
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

BIN_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
R6_JOINTS = ["Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip"]


class ParseError(Exception):
    pass


class Inst:
    __slots__ = ("ref", "cls", "props", "children", "parent")

    def __init__(self, ref, cls):
        self.ref, self.cls, self.props, self.children, self.parent = ref, cls, {}, [], None

    @property
    def name(self):
        return self.props.get("Name", "")

    def child(self, name):
        for c in self.children:
            if c.name == name:
                return c
        return None

    def descendants(self):
        for c in self.children:
            yield c
            yield from c.descendants()

    def path(self):
        parts, n = [], self
        while n is not None:
            parts.append(n.name or n.cls)
            n = n.parent
        return ".".join(reversed(parts))


# ---------------------------------------------------------------- binary format

def lz4_block(src, out_len):
    dst = bytearray()
    i, n = 0, len(src)
    while i < n:
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255:
                    break
        dst += src[i:i + lit]; i += lit
        if i >= n:
            break
        off = src[i] | (src[i + 1] << 8); i += 2
        if off == 0 or off > len(dst):
            raise ParseError("corrupt LZ4 data")
        ml = token & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255:
                    break
        ml += 4
        start = len(dst) - off
        for k in range(ml):
            dst.append(dst[start + k])
    if len(dst) != out_len:
        raise ParseError("LZ4 length mismatch")
    return bytes(dst)


class R:
    def __init__(self, b):
        self.b, self.i = b, 0

    def take(self, n):
        if self.i + n > len(self.b):
            raise ParseError("unexpected end of chunk")
        v = self.b[self.i:self.i + n]; self.i += n
        return v

    def u8(self):
        return self.take(1)[0]

    def u32(self):
        return struct.unpack("<I", self.take(4))[0]

    def string(self):
        return self.take(self.u32())

    def interleaved(self, count, width=4):
        raw = self.take(count * width)
        return [int.from_bytes(bytes(raw[j * count + k] for j in range(width)), "big")
                for k in range(count)]

    def i32s(self, count):
        return [(v >> 1) ^ -(v & 1) for v in self.interleaved(count)]

    def refs(self, count):
        out, acc = [], 0
        for d in self.i32s(count):
            acc += d; out.append(acc)
        return out


def parse_binary(data):
    if not data.startswith(BIN_MAGIC):
        raise ParseError("not a binary Roblox file")
    r = R(data)
    r.take(len(BIN_MAGIC) + 2)  # magic + version
    r.take(4); r.take(4); r.take(8)  # class count, instance count, reserved
    classes, insts = {}, {}
    parents = []
    while r.i < len(data):
        name = r.take(4).rstrip(b"\0").decode("ascii", "replace")
        clen, ulen = r.u32(), r.u32(); r.take(4)
        raw = r.take(clen if clen else ulen)
        if clen:
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                raise ParseError("zstd-compressed chunk: unsupported without the zstandard module")
            raw = lz4_block(raw, ulen)
        c = R(raw)
        if name == "INST":
            cid = c.u32(); cls = c.string().decode("utf-8", "replace"); c.u8()
            n = c.u32(); refs = c.refs(n)
            classes[cid] = (cls, refs)
            for ref in refs:
                insts[ref] = Inst(ref, cls)
        elif name == "PROP":
            cid = c.u32(); prop = c.string().decode("utf-8", "replace"); t = c.u8()
            if cid not in classes:
                continue
            refs = classes[cid][1]; n = len(refs)
            try:
                if t in (0x01, 0x1D) and prop in ("Name", "Source", "LinkedSource"):
                    vals = [c.string() for _ in range(n)]
                    for ref, v in zip(refs, vals):
                        insts[ref].props[prop] = v.decode("utf-8", "replace")
                elif t == 0x02 and prop in ("Anchored", "Disabled", "Enabled"):
                    for ref, v in zip(refs, c.take(n)):
                        insts[ref].props[prop] = bool(v)
                elif t == 0x12 and prop in ("RigType", "RunContext"):
                    for ref, v in zip(refs, c.interleaved(n)):
                        insts[ref].props[prop] = v
                elif t == 0x13 and prop in ("Part0", "Part1", "PrimaryPart"):
                    for ref, v in zip(refs, c.refs(n)):
                        insts[ref].props[prop] = v
            except ParseError:
                pass
        elif name == "PRNT":
            c.u8(); n = c.u32()
            parents = list(zip(c.refs(n), c.refs(n)))
        elif name == "END":
            break
    roots = []
    for child, parent in parents:
        ch = insts.get(child)
        if ch is None:
            continue
        p = insts.get(parent)
        if p is None:
            roots.append(ch)
        else:
            ch.parent = p; p.children.append(ch)
    return roots, insts


# ---------------------------------------------------------------- XML format

def parse_xml(data):
    if len(data) > 64 * 1024 * 1024 or b"<!ENTITY" in data[:4096]:
        raise ParseError("refusing XML with entity declarations or > 64 MB")
    root = ET.fromstring(data)
    insts, roots, counter = {}, [], [0]
    refmap = {}

    def walk(el, parent):
        counter[0] += 1
        inst = Inst(counter[0], el.get("class", "?"))
        refmap[el.get("referent")] = inst.ref
        insts[inst.ref] = inst
        props = el.find("Properties")
        if props is not None:
            for p in props:
                nm = p.get("name")
                if nm in ("Name", "Source", "LinkedSource"):
                    inst.props[nm] = p.text or ""
                elif nm in ("Anchored", "Disabled", "Enabled"):
                    inst.props[nm] = (p.text or "").strip() == "true"
                elif nm in ("RigType", "RunContext"):
                    inst.props[nm] = int((p.text or "0").strip())
                elif nm in ("Part0", "Part1", "PrimaryPart"):
                    inst.props[nm] = (p.text or "").strip()
        if parent is None:
            roots.append(inst)
        else:
            inst.parent = parent; parent.children.append(inst)
        for ch in el.findall("Item"):
            walk(ch, inst)

    for it in root.findall("Item"):
        walk(it, None)
    for inst in insts.values():  # resolve XML referent strings
        for k in ("Part0", "Part1", "PrimaryPart"):
            if isinstance(inst.props.get(k), str):
                inst.props[k] = refmap.get(inst.props[k])
    return roots, insts


def load(path):
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith(BIN_MAGIC):
        return parse_binary(data)
    if data.lstrip()[:7] == b"<roblox":
        return parse_xml(data)
    raise ParseError("not a Roblox model file")


# ---------------------------------------------------------------- checks

SUSPICIOUS = [
    (r"\brequire\s*\(\s*[0-9]", "require(<number>): loads remote code by asset ID"),
    (r"\brequire\s*\(\s*tonumber", "require(tonumber(...)): disguised remote require"),
    (r"\bgetfenv\b|\bsetfenv\b", "getfenv/setfenv"),
    (r"\bloadstring\b", "loadstring"),
    (r"HttpService|GetAsync|PostAsync|RequestAsync|HttpGet", "HTTP calls"),
    (r"InsertService|LoadAsset", "InsertService/LoadAsset"),
    (r"MarketplaceService|PromptPurchase|PromptGamePass", "MarketplaceService prompts"),
    (r"TeleportService", "TeleportService"),
    (r":Kick\s*\(", "kicks players"),
    (r"string\.char\s*\(|\\x[0-9a-fA-F]{2}|(\\\d{2,3}){8,}", "byte-escape / string.char obfuscation"),
    (r"[A-Za-z0-9+/]{200,}={0,2}", "long base64-like blob"),
    (r"\bServerScriptService\b|\bServerStorage\b", "reaches into server services"),
    (r"\bgame\s*:\s*GetService\s*\(\s*[\"']Players[\"']\s*\)\s*:\s*ClearAllChildren|:Destroy\(\)\s*end\s*end", "mass destroy pattern"),
]


def scan_source(src):
    flags = []
    for pat, why in SUSPICIOUS:
        if re.search(pat, src):
            flags.append(why)
    lines = src.splitlines() or [""]
    if max(len(l) for l in lines) > 1000:
        flags.append("very long line (possible obfuscation)")
    idents = re.findall(r"\b[A-Za-z_]\w*\b", src)
    if len(idents) > 50:
        weird = sum(1 for x in idents if re.fullmatch(r"[Il1_]{6,}|_0x[0-9a-f]+|[a-zA-Z]{1,2}\d{3,}", x))
        if weird / len(idents) > 0.1:
            flags.append("meaningless identifiers (possible obfuscation)")
    return flags


def rig_check(model, insts, expect):
    problems, notes = [], []
    if model.cls != "Model":
        problems.append(f"root is a {model.cls}, not a Model")
    hum = next((c for c in model.children if c.cls == "Humanoid"), None)
    hrp = model.child("HumanoidRootPart")
    head = model.child("Head")
    torso = model.child("Torso")
    if not hum:
        problems.append("no Humanoid in the root of the model")
    else:
        rt = hum.props.get("RigType")
        if rt == 1:
            problems.append("Humanoid.RigType is R15 (code needs R6)")
        elif rt is None:
            notes.append("Humanoid.RigType not stored: Roblox default is R6, check limbs below")
    if not hrp:
        problems.append("no HumanoidRootPart in the root of the model")
    if not head:
        problems.append("no Head")
    if not torso:
        if model.child("UpperTorso"):
            problems.append("has UpperTorso instead of Torso (an R15 body)")
        else:
            problems.append("no Torso")
    else:
        for j in R6_JOINTS:
            m = torso.child(j)
            if not m or m.cls != "Motor6D":
                problems.append(f'Torso has no Motor6D named "{j}"')
    for limb in ("Left Arm", "Right Arm", "Left Leg", "Right Leg"):
        if not model.child(limb):
            problems.append(f'no "{limb}"')
    pp = model.props.get("PrimaryPart")
    if hrp and pp != hrp.ref:
        notes.append("PrimaryPart not set to HumanoidRootPart (game fixes this at spawn)")
    anchored = sum(1 for d in model.descendants() if d.props.get("Anchored"))
    if anchored:
        notes.append(f"{anchored} anchored part(s) (game unanchors at spawn)")
    if hum and not any(c.cls == "Animator" for c in hum.children):
        notes.append("no Animator in Humanoid (game adds one at spawn)")
    for p in expect:
        node = model
        for step in p.split("/"):
            node = node.child(step) if node else None
        if not node:
            problems.append(f"missing expected descendant {p}")
    return problems, notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--tree", action="store_true")
    ap.add_argument("--rig", action="store_true")
    ap.add_argument("--scripts", action="store_true")
    ap.add_argument("--dump-scripts")
    ap.add_argument("--expect", action="append", default=[])
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    if not (a.tree or a.rig or a.scripts or a.dump_scripts):
        a.rig = a.scripts = True
    try:
        roots, insts = load(a.file)
    except (ParseError, ET.ParseError, struct.error, IndexError, OSError) as e:
        print(f"inspect-rbxm: cannot parse {a.file}: {e}", file=sys.stderr)
        return 2

    out = {"file": a.file, "roots": [f"{r.cls} {r.name!r}" for r in roots],
           "instances": len(insts)}
    bad = False

    if a.tree:
        def pr(n, d):
            print("  " * d + f"{n.cls} {n.name!r}")
            for c in n.children:
                pr(c, d + 1)
        for r in roots:
            pr(r, 0)

    if a.rig:
        model = roots[0] if len(roots) == 1 else None
        if model is None:
            out["rig"] = {"problems": [f"{len(roots)} root instances, expected exactly 1 Model"], "notes": []}
        else:
            p, n = rig_check(model, insts, a.expect)
            out["rig"] = {"problems": p, "notes": n, "rootName": model.name}
        bad |= bool(out["rig"]["problems"])

    scripts = [i for i in insts.values() if i.cls in SCRIPT_CLASSES]
    if a.scripts or a.dump_scripts:
        rows = []
        for s in sorted(scripts, key=lambda s: s.path()):
            src = s.props.get("Source", "")
            flags = scan_source(src)
            if s.props.get("LinkedSource"):
                flags.append("LinkedSource set (code loaded from elsewhere)")
            rows.append({"class": s.cls, "path": s.path(), "bytes": len(src.encode()),
                         "lines": src.count("\n") + 1 if src else 0,
                         "disabled": s.props.get("Disabled", False), "flags": flags})
            bad |= bool(flags)
        out["scripts"] = rows
        if a.dump_scripts:
            os.makedirs(a.dump_scripts, exist_ok=True)
            for k, s in enumerate(sorted(scripts, key=lambda s: s.path())):
                safe = re.sub(r"[^A-Za-z0-9._-]+", "_", s.path())[:150]
                with open(os.path.join(a.dump_scripts, f"{k:03d}_{safe}.luau"), "w") as f:
                    f.write(s.props.get("Source", ""))

    if a.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"{a.file}: {out['instances']} instances, root(s): {', '.join(out['roots'])}")
        if "rig" in out:
            r = out["rig"]
            print("  RIG: " + ("OK (R6-compatible)" if not r["problems"] else "PROBLEMS"))
            for p in r["problems"]:
                print("    x " + p)
            for n in r["notes"]:
                print("    - " + n)
        if "scripts" in out:
            print(f"  SCRIPTS: {len(out['scripts'])}")
            for s in out["scripts"]:
                tag = " [disabled]" if s["disabled"] else ""
                print(f"    {s['class']:<12} {s['path']}  ({s['lines']} lines){tag}")
                for f in s["flags"]:
                    print(f"      !! {f}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
