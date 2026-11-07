#!/usr/bin/env python3
"""Bake the character-rig repairs into the .rbxm files, so every rig loads as-is.

    python3 -I tools/bake-rigs.py [--check] [NAME ...]

Rojo only syncs ReplicatedStorage.Assets.Characters (see default.project.json), so
the runtime fixer src/ServerScriptService/CharacterRigFixes.server.luau is no longer
part of what gets synced. This tool applies the exact same repairs offline instead:

  1. unwrap a rig nested inside a wrapper Model (same preference order as the Luau
     unwrap(): nested Model named like the character, then one that already works,
     then any R6 body);
  2. rebuild a classic R6 body's missing Humanoid (RigType R6), HumanoidRootPart and
     the six Motor6Ds (RootJoint, Neck, shoulders, hips) at the standard R6 positions,
     keeping the current pose and removing old welds that glued a limb to the Torso;
     PrimaryPart is set to the HumanoidRootPart;
  3. convert an R15 body to R6 (the game is R6-only: Animate exits on anything else).
     Invisible R6 Torso, arms and legs are added, each sized to the R15 parts it
     replaces (UpperTorso+LowerTorso, UpperArm+LowerArm+Hand, UpperLeg+LowerLeg+Foot);
     the R15 parts are renamed Body_<Name>, made massless and non-colliding, and
     welded onto them, and the R15 joints are removed. The R15 Head stays the Head.
     A stock `Animate` script in the root is removed (the game ships its own).
     Step 2 then adds the Humanoid/HumanoidRootPart/Motor6Ds;
  4. Commander only: the Grenade part and the Deagle model with FirePart and its four
     ParticleEmitters (Burst, Front, Smoke, Flash) that Survivors/Commander.luau uses.

The .rbxm is never patched byte by byte: Rojo converts it to XML, the XML is edited as
a Roblox instance tree, and Rojo writes it back as a fresh binary .rbxm. A rig that
already passes is left alone (file not rewritten). Ravel and Scrapheap are never touched.

--check   report what would change without writing anything (exit 1 if anything would)

Needs `rojo` on PATH (rokit.toml pins 7.7.0).
"""
import argparse
import base64
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = os.path.join(ROOT, "src", "ReplicatedStorage", "Assets", "Characters")
LEAVE_ALONE = {"Ravel", "Scrapheap"}  # hand-built rigs the owner asked to keep as they are

R6_PARTS = ["Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]
BASEPARTS = {"Part", "MeshPart", "UnionOperation", "WedgePart", "CornerWedgePart",
             "TrussPart", "SpawnLocation", "Seat", "VehicleSeat", "NegateOperation"}
JOINTS = {"Weld", "Snap", "Glue", "ManualWeld", "ManualGlue", "Motor", "Motor6D",
          "Rotate", "RotateP", "RotateV", "VelocityMotor", "WeldConstraint"}
REF_PAIRS = (("Part0", "Part1"), ("Part0Internal", "Part1Internal"))
CF_KEYS = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
# R6 limb -> the R15 parts it stands in for
R15_GROUPS = {
    "Torso": ["UpperTorso", "LowerTorso"],
    "Left Arm": ["LeftUpperArm", "LeftLowerArm", "LeftHand"],
    "Right Arm": ["RightUpperArm", "RightLowerArm", "RightHand"],
    "Left Leg": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"],
    "Right Leg": ["RightUpperLeg", "RightLowerLeg", "RightFoot"],
}
R15_PARTS = [n for group in R15_GROUPS.values() for n in group]


# ------------------------------------------------------------------ CFrame math
# A CFrame is (p, R) with p a 3-vector and R a row-major 3x3 rotation matrix.

def cf(x=0.0, y=0.0, z=0.0):
    return ([x, y, z], [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]])


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def cf_mul(a, b):
    (pa, ra), (pb, rb) = a, b
    p = [pa[i] + sum(ra[i][k] * pb[k] for k in range(3)) for i in range(3)]
    return (p, mat_mul(ra, rb))


def cf_inv(a):
    p, r = a
    rt = [[r[j][i] for j in range(3)] for i in range(3)]
    return ([-sum(rt[i][k] * p[k] for k in range(3)) for i in range(3)], rt)


def angles(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz): rotation X, then Y, then Z (R = Rx * Ry * Rz)."""
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return ([0.0, 0.0, 0.0], mat_mul(mat_mul(Rx, Ry), Rz))


def clean(v):
    v = round(v, 6)
    return 0.0 if v == 0 else v


# ------------------------------------------------------------- XML instance tree

class Tree:
    """The Roblox XML document (rbxmx) as written by Rojo, with a parent map."""

    def __init__(self, path):
        self.doc = ET.parse(path)
        self.root_el = self.doc.getroot()
        self.parent = {c: p for p in self.root_el.iter() for c in p}
        self.by_ref = {i.get("referent"): i for i in self.root_el.iter("Item")}
        self.counter = 0
        self.changes = []

    # instance helpers
    def props(self, item):
        p = item.find("Properties")
        if p is None:
            p = ET.Element("Properties")
            item.insert(0, p)
            self.parent[p] = item
        return p

    def prop(self, item, name):
        for e in self.props(item):
            if e.get("name") == name:
                return e
        return None

    def name(self, item):
        e = self.prop(item, "Name")
        return (e.text or "") if e is not None else ""

    def children(self, item):
        return [c for c in item if c.tag == "Item"]

    def child(self, item, name):
        return next((c for c in self.children(item) if self.name(c) == name), None)

    def descendants(self, item):
        for c in self.children(item):
            yield c
            yield from self.descendants(c)

    def cls(self, item):
        return item.get("class")

    def item_parent(self, item):
        p = self.parent.get(item)
        return p if p is not None and p.tag == "Item" else None

    def is_basepart(self, item):
        return item is not None and self.cls(item) in BASEPARTS

    def set_prop(self, item, tag, name, text=None, build=None):
        e = self.prop(item, name)
        if e is not None and e.tag != tag:
            self.props(item).remove(e)
            e = None
        if e is None:
            e = ET.SubElement(self.props(item), tag, {"name": name})
        for c in list(e):
            e.remove(c)
        e.text = text
        if build:
            build(e)
        return e

    def get_cf(self, item, name="CFrame"):
        e = self.prop(item, name)
        if e is None:
            return cf()
        v = [float(e.find(k).text) for k in CF_KEYS]
        return (v[0:3], [v[3:6], v[6:9], v[9:12]])

    def set_cf(self, item, name, c):
        p, r = c
        vals = p + r[0] + r[1] + r[2]

        def build(e):
            for k, v in zip(CF_KEYS, vals):
                ET.SubElement(e, k).text = repr(clean(v))
        self.set_prop(item, "CoordinateFrame", name, build=build)

    def get_size(self, item):
        e = self.prop(item, "size")
        if e is None:
            e = self.prop(item, "Size")
        if e is None:
            return [4.0, 1.2, 2.0]
        return [float(e.find(k).text) for k in "XYZ"]

    def set_vec(self, item, tag, name, vals, keys="XYZ"):
        def build(e):
            for k, v in zip(keys, vals):
                ET.SubElement(e, k).text = repr(clean(v))
        self.set_prop(item, tag, name, build=build)

    def get_ref(self, item, name):
        e = self.prop(item, name)
        if e is None or not e.text or e.text == "null":
            return None
        return self.by_ref.get(e.text)

    def set_ref(self, item, name, target):
        self.set_prop(item, "Ref", name, target.get("referent") if target is not None else "null")

    def new(self, cls, name, parent):
        self.counter += 1
        ref = f"RBXBAKE{self.counter:05d}"
        item = ET.SubElement(parent, "Item", {"class": cls, "referent": ref})
        self.parent[item] = parent
        self.by_ref[ref] = item
        props = ET.SubElement(item, "Properties")
        self.parent[props] = item
        ET.SubElement(props, "string", {"name": "Name"}).text = name
        return item

    def destroy(self, item):
        p = self.parent[item]
        p.remove(item)
        for d in [item, *self.descendants(item)]:
            self.by_ref.pop(d.get("referent"), None)

    def move(self, item, new_parent, index=None):
        self.parent[item].remove(item)
        if index is None:
            new_parent.append(item)
        else:
            new_parent.insert(index, item)
        self.parent[item] = new_parent

    def path(self, item):
        parts = []
        while item is not None:
            parts.append(self.name(item))
            item = self.item_parent(item)
        return ".".join(reversed(parts))

    def null_dangling_refs(self):
        """Refs that pointed into a removed wrapper would dangle: set them to nil."""
        for item in self.root_el.iter("Item"):
            for e in self.props(item):
                if e.tag == "Ref" and e.text and e.text != "null" and e.text not in self.by_ref:
                    e.text = "null"

    def write(self, path):
        ET.indent(self.doc, space="  ")
        self.doc.write(path, encoding="utf-8", xml_declaration=False)


# ----------------------------------------------- repairs (CharacterRigFixes port)

def has_r6_body(t, m):
    return all(t.is_basepart(t.child(m, n)) for n in R6_PARTS) and t.child(m, "UpperTorso") is None


def usable_root(t, m):
    return any(t.cls(c) == "Humanoid" for c in t.children(m)) and t.child(m, "HumanoidRootPart") is not None


def has_r15_body(t, m):
    return (t.child(m, "Torso") is None and t.is_basepart(t.child(m, "Head"))
            and all(t.is_basepart(t.child(m, n)) for n in R15_PARTS))


def unwrap(t, rig, rig_name):
    if usable_root(t, rig) or has_r6_body(t, rig) or has_r15_body(t, rig):
        return rig
    named = working = body = None
    for d in t.descendants(rig):
        if t.cls(d) == "Model" and (usable_root(t, d) or has_r6_body(t, d) or has_r15_body(t, d)):
            if named is None and t.name(d).lower() == rig_name.lower():
                named = d
            if working is None and usable_root(t, d):
                working = d
            body = body if body is not None else d
    d = named if named is not None else working if working is not None else body
    if d is None:
        return rig
    t.changes.append(f"unwrapped nested rig '{t.path(d)}'")
    top = t.parent[rig]
    index = list(top).index(rig)
    t.move(d, top, index)
    t.destroy(rig)
    t.set_prop(d, "string", "Name", rig_name)
    t.null_dangling_refs()
    return d


def remove_joints_between(t, scope, a, b):
    for j in list(t.descendants(scope)):
        if t.cls(j) not in JOINTS or j.get("referent") not in t.by_ref:
            continue
        for n0, n1 in REF_PAIRS:
            p0, p1 = t.get_ref(j, n0), t.get_ref(j, n1)
            if (p0 is a and p1 is b) or (p0 is b and p1 is a):
                t.changes.append(f"removed {t.cls(j)} '{t.name(j)}' between {t.name(a)} and {t.name(b)}")
                t.destroy(j)
                break


def ensure_motor(t, rig, parent, name, part0, part1, joint_world):
    existing = t.child(parent, name)
    if (existing is not None and t.cls(existing) == "Motor6D"
            and t.get_ref(existing, "Part0") is part0 and t.get_ref(existing, "Part1") is part1):
        return
    if existing is not None:
        t.destroy(existing)
    remove_joints_between(t, rig, part0, part1)
    m = t.new("Motor6D", name, parent)
    t.set_ref(m, "Part0", part0)
    t.set_ref(m, "Part1", part1)
    t.set_cf(m, "C0", cf_mul(cf_inv(t.get_cf(part0)), joint_world))
    t.set_cf(m, "C1", cf_mul(cf_inv(t.get_cf(part1)), joint_world))
    t.changes.append(f"added Motor6D '{name}' ({t.name(part0)} -> {t.name(part1)})")


def convert_r15(t, rig):
    """Give an R15 body an invisible R6 skeleton and weld the R15 parts onto it."""
    if not has_r15_body(t, rig):
        return
    t.changes.append("converted R15 body to R6")
    hrp = t.child(rig, "HumanoidRootPart")
    facing = t.get_cf(hrp if t.is_basepart(hrp) else t.child(rig, "LowerTorso"))[1]
    rot_t = [[facing[j][i] for j in range(3)] for i in range(3)]  # world -> facing frame

    r15 = {n: t.child(rig, n) for n in R15_PARTS}
    body = set(r15.values()) | {t.child(rig, "Head")}
    if t.is_basepart(hrp):
        body.add(hrp)

    # The R15 joints go; accessory welds (to parts outside the body) stay.
    for j in list(t.descendants(rig)):
        if t.cls(j) not in JOINTS or j.get("referent") not in t.by_ref:
            continue
        for n0, n1 in REF_PAIRS:
            p0, p1 = t.get_ref(j, n0), t.get_ref(j, n1)
            if p0 is not None and p1 is not None and p0 in body and p1 in body:
                t.destroy(j)
                break

    boxes = {}
    for limb, names in R15_GROUPS.items():
        lo, hi = [math.inf] * 3, [-math.inf] * 3
        for n in names:
            (pos, rot), size = t.get_cf(r15[n]), t.get_size(r15[n])
            for sx in (-0.5, 0.5):
                for sy in (-0.5, 0.5):
                    for sz in (-0.5, 0.5):
                        off = (sx * size[0], sy * size[1], sz * size[2])
                        w = [pos[i] + sum(rot[i][k] * off[k] for k in range(3)) for i in range(3)]
                        l = [sum(rot_t[i][k] * w[k] for k in range(3)) for i in range(3)]
                        lo = [min(a, b) for a, b in zip(lo, l)]
                        hi = [max(a, b) for a, b in zip(hi, l)]
        boxes[limb] = (lo, hi)
    # Stock R6 geometry: each leg runs from the bottom of the Torso to the sole of the
    # foot. An R6 Humanoid stands at leg height + half the root part's height, so this
    # puts the feet on the ground (R15 upper legs usually start inside the torso).
    torso_bottom = boxes["Torso"][0][1]
    for leg in ("Left Leg", "Right Leg"):
        boxes[leg][1][1] = torso_bottom

    for limb, names in R15_GROUPS.items():
        lo, hi = boxes[limb]
        centre_l = [(a + b) / 2 for a, b in zip(lo, hi)]
        centre = [sum(facing[i][k] * centre_l[k] for k in range(3)) for i in range(3)]
        part = t.new("Part", limb, rig)
        t.set_vec(part, "Vector3", "size", [max(b - a, 0.2) for a, b in zip(lo, hi)])
        t.set_cf(part, "CFrame", (centre, facing))
        t.set_prop(part, "float", "Transparency", "1")
        t.set_prop(part, "bool", "Anchored", "false")
        t.set_prop(part, "bool", "CanCollide", "true" if limb == "Torso" else "false")
        for n in names:
            vis = r15[n]
            t.set_prop(vis, "string", "Name", "Body_" + n)
            t.set_prop(vis, "bool", "Massless", "true")
            t.set_prop(vis, "bool", "CanCollide", "false")
            t.set_prop(vis, "bool", "Anchored", "false")
            w = t.new("Weld", "R6Weld", vis)
            t.set_ref(w, "Part0", part)
            t.set_ref(w, "Part1", vis)
            t.set_cf(w, "C0", cf_mul(cf_inv(t.get_cf(part)), t.get_cf(vis)))
            t.set_cf(w, "C1", cf())

    # The R6 HumanoidRootPart sits on the Torso, like a stock R6 rig.
    if t.is_basepart(hrp):
        torso = t.child(rig, "Torso")
        sx, sy, sz = t.get_size(torso)
        t.set_cf(hrp, "CFrame", t.get_cf(torso))
        t.set_vec(hrp, "Vector3", "size", [sx, sy, max(sz, 1.0)])
        t.set_prop(hrp, "bool", "CanCollide", "false")
        t.set_prop(hrp, "bool", "Anchored", "false")

    # R15 HipHeight is an absolute height; on R6 it is an extra offset on top of the legs.
    for hum in t.children(rig):
        if t.cls(hum) == "Humanoid":
            t.set_prop(hum, "float", "HipHeight", "0")

    for c in t.children(rig):
        if t.cls(c) in ("LocalScript", "Script") and t.name(c) == "Animate":
            t.destroy(c)
            t.changes.append(f"removed stock {t.cls(c)} 'Animate' (the game ships its own)")


def repair_r6(t, rig):
    if not has_r6_body(t, rig):
        return
    torso, head = t.child(rig, "Torso"), t.child(rig, "Head")
    ra, la = t.child(rig, "Right Arm"), t.child(rig, "Left Arm")
    rl, ll = t.child(rig, "Right Leg"), t.child(rig, "Left Leg")

    humanoid = next((c for c in t.children(rig) if t.cls(c) == "Humanoid"), None)
    if humanoid is None:
        humanoid = t.new("Humanoid", "Humanoid", rig)
        t.changes.append("added Humanoid")
    rt = t.prop(humanoid, "RigType")
    if rt is None or rt.text != "0":
        t.set_prop(humanoid, "token", "RigType", "0")  # Enum.HumanoidRigType.R6
        t.changes.append("set Humanoid.RigType = R6")

    hrp = t.child(rig, "HumanoidRootPart")
    if not t.is_basepart(hrp):
        if hrp is not None:
            t.destroy(hrp)
        sx, sy, sz = t.get_size(torso)
        hrp = t.new("Part", "HumanoidRootPart", rig)
        t.set_vec(hrp, "Vector3", "size", [sx, sy, max(sz, 1.0)])
        t.set_cf(hrp, "CFrame", t.get_cf(torso))
        t.set_prop(hrp, "float", "Transparency", "1")
        t.set_prop(hrp, "bool", "CanCollide", "false")
        t.set_prop(hrp, "bool", "Anchored", "false")
        t.changes.append("added HumanoidRootPart")

    sx, sy, _ = t.get_size(torso)
    tx, ty = sx / 2, sy / 2
    r = math.radians
    tc = t.get_cf(torso)
    neck_rot = angles(r(-90), 0, r(180))
    right, left = angles(0, r(90), 0), angles(0, r(-90), 0)
    ensure_motor(t, rig, hrp, "RootJoint", hrp, torso, cf_mul(tc, neck_rot))
    ensure_motor(t, rig, torso, "Neck", torso, head, cf_mul(cf_mul(tc, cf(0, ty, 0)), neck_rot))
    ensure_motor(t, rig, torso, "Right Shoulder", torso, ra, cf_mul(cf_mul(tc, cf(tx, ty / 2, 0)), right))
    ensure_motor(t, rig, torso, "Left Shoulder", torso, la, cf_mul(cf_mul(tc, cf(-tx, ty / 2, 0)), left))
    ensure_motor(t, rig, torso, "Right Hip", torso, rl, cf_mul(cf_mul(tc, cf(tx / 2, -ty, 0)), right))
    ensure_motor(t, rig, torso, "Left Hip", torso, ll, cf_mul(cf_mul(tc, cf(-tx / 2, -ty, 0)), left))

    if t.get_ref(rig, "PrimaryPart") is not hrp:
        t.set_ref(rig, "PrimaryPart", hrp)
        t.changes.append("set PrimaryPart = HumanoidRootPart")


# ----------------------------------------------------- Commander's ability parts

def color3uint8(r, g, b):
    return str((r << 16) | (g << 8) | b)


def hidden_part(t, name, size, parent):
    p = t.new("Part", name, parent)
    t.set_vec(p, "Vector3", "size", size)
    t.set_prop(p, "float", "Transparency", "1")
    for prop in ("CanCollide", "CanQuery", "CanTouch", "Anchored"):
        t.set_prop(p, "bool", prop, "false")
    t.set_prop(p, "bool", "Massless", "true")
    return p


def weld_to(t, part, limb, offset):
    t.set_cf(part, "CFrame", cf_mul(t.get_cf(limb), offset))
    w = t.new("Weld", "RigFixWeld", part)
    t.set_ref(w, "Part0", limb)
    t.set_ref(w, "Part1", part)
    t.set_cf(w, "C0", offset)
    t.set_cf(w, "C1", cf())


def color_seq(rgb):
    r, g, b = (round(c / 255, 6) for c in rgb)
    return f"0 {r} {g} {b} 0 1 {r} {g} {b} 0 "


def num_seq(a, b):
    return f"0 {a} 0 1 {b} 0 "


def emitter(t, name, parent, props):
    e = t.new("ParticleEmitter", name, parent)
    t.set_prop(e, "bool", "Enabled", "false")  # the ability only ever calls :Emit()
    for key, (tag, val) in props.items():
        if tag == "Vector2":
            t.set_vec(e, "Vector2", key, val, keys="XY")
        else:
            t.set_prop(e, tag, key, val)


def fix_commander(t, rig):
    left_arm, right_arm = t.child(rig, "Left Arm"), t.child(rig, "Right Arm")

    if t.child(rig, "Grenade") is None and t.is_basepart(left_arm):
        g = hidden_part(t, "Grenade", [0.5, 0.6, 0.5], rig)
        t.set_prop(g, "token", "shape", "0")  # Enum.PartType.Ball
        t.set_prop(g, "Color3uint8", "Color3uint8", color3uint8(70, 80, 60))
        weld_to(t, g, left_arm, cf(0, -1.1, 0))
        t.changes.append("added Grenade")

    deagle = t.child(rig, "Deagle")
    if deagle is None and t.is_basepart(right_arm):
        deagle = t.new("Model", "Deagle", rig)
        grip = hidden_part(t, "Grip", [0.25, 0.6, 0.35], deagle)
        t.set_prop(grip, "Color3uint8", "Color3uint8", color3uint8(40, 40, 40))
        weld_to(t, grip, right_arm, cf(0, -1.05, -0.2))
        barrel = hidden_part(t, "Barrel", [0.25, 0.3, 1.1], deagle)
        t.set_prop(barrel, "Color3uint8", "Color3uint8", color3uint8(150, 150, 155))
        weld_to(t, barrel, right_arm, cf(0, -0.8, -0.65))
        t.set_ref(deagle, "PrimaryPart", grip)
        t.changes.append("added Deagle")

    if deagle is not None and t.child(deagle, "FirePart") is None and t.is_basepart(right_arm):
        fire = hidden_part(t, "FirePart", [0.2, 0.2, 0.2], deagle)
        # Commander.luau keeps parts tagged "Transparent" invisible
        t.set_prop(fire, "BinaryString", "Tags", base64.b64encode(b"Transparent").decode())
        weld_to(t, fire, right_arm, cf(0, -0.8, -1.25))
        t.changes.append("added Deagle.FirePart")

    fire = t.child(deagle, "FirePart") if deagle is not None else None
    if fire is None:
        return
    flash = color_seq((255, 220, 120))
    specs = {
        "Burst": {"Color": ("ColorSequence", flash), "Lifetime": ("NumberRange", "0.05 0.1 "),
                  "Speed": ("NumberRange", "15 25 "), "SpreadAngle": ("Vector2", [25, 25]),
                  "Size": ("NumberSequence", num_seq(0.3, 0)), "LightEmission": ("float", "1")},
        "Front": {"Color": ("ColorSequence", flash), "Lifetime": ("NumberRange", "0.05 0.12 "),
                  "Speed": ("NumberRange", "30 45 "), "SpreadAngle": ("Vector2", [5, 5]),
                  "Size": ("NumberSequence", num_seq(0.2, 0)), "LightEmission": ("float", "1"),
                  "EmissionDirection": ("token", "5")},  # Enum.NormalId.Front
        "Smoke": {"Color": ("ColorSequence", color_seq((120, 120, 120))),
                  "Lifetime": ("NumberRange", "0.6 1 "), "Speed": ("NumberRange", "1 3 "),
                  "Size": ("NumberSequence", num_seq(0.4, 1.2)),
                  "Transparency": ("NumberSequence", num_seq(0.4, 1))},
        "Flash": {"Color": ("ColorSequence", flash), "Lifetime": ("NumberRange", "0.04 0.06 "),
                  "Speed": ("NumberRange", "0 0 "), "Size": ("NumberSequence", num_seq(1.2, 0)),
                  "LightEmission": ("float", "1")},
    }
    for name, props in specs.items():
        if t.child(fire, name) is None:
            emitter(t, name, fire, props)
            t.changes.append(f"added Deagle.FirePart.{name}")


ROLE_FIXES = {("Survivor", "Commander"): fix_commander}


# ---------------------------------------------------------------------- driver

def rojo_convert(src, dst, workdir, name):
    """Have Rojo read `src` (.rbxm/.rbxmx) and write it as `dst` (.rbxm/.rbxmx).

    The root instance is named `name` (the file name, which is also what Rojo calls it
    when syncing)."""
    ext = os.path.splitext(src)[1]
    staged = os.path.join(workdir, "model" + ext)
    shutil.copyfile(src, staged)
    proj = os.path.join(workdir, "convert.project.json")
    with open(proj, "w") as f:
        json.dump({"name": name, "tree": {"$path": "model" + ext}}, f)
    r = subprocess.run(["rojo", "build", proj, "-o", dst], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"rojo build failed for {src}:\n{r.stdout}{r.stderr}")


def bake(role, path, check):
    name = os.path.splitext(os.path.basename(path))[0]
    with tempfile.TemporaryDirectory() as work:
        xml = os.path.join(work, "in.rbxmx")
        rojo_convert(path, xml, work, name)
        t = Tree(xml)
        roots = t.children(t.root_el)
        if len(roots) != 1 or t.cls(roots[0]) != "Model":
            return name, ["skipped: root is not a single Model"]
        rig = unwrap(t, roots[0], name)
        convert_r15(t, rig)
        repair_r6(t, rig)
        fix = ROLE_FIXES.get((role, name))
        if fix:
            fix(t, rig)
        if not t.changes or check:
            return name, t.changes
        out_xml = os.path.join(work, "out.rbxmx")
        t.write(out_xml)
        out_bin = os.path.join(work, "out.rbxm")
        os.makedirs(os.path.join(work, "pass2"))
        rojo_convert(out_xml, out_bin, os.path.join(work, "pass2"), name)
        shutil.move(out_bin, path)
        return name, t.changes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", help="only these characters (default: all)")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if shutil.which("rojo") is None:
        sys.exit("bake-rigs: rojo is not on PATH")
    pending = False
    for role in ("Killer", "Survivor"):
        folder = os.path.join(CHARS, role)
        for fn in sorted(os.listdir(folder)):
            if not fn.endswith(".rbxm"):
                continue
            name = fn[:-5]
            if name in LEAVE_ALONE or (a.names and name not in a.names):
                continue
            name, changes = bake(role, os.path.join(folder, fn), a.check)
            if changes:
                pending = True
                verb = "would change" if a.check else "baked"
                print(f"{role}.{name}: {verb}")
                for c in changes:
                    print(f"    - {c}")
    if not pending:
        print("every rig already loads as-is; nothing to bake")
    return 1 if (a.check and pending) else 0


if __name__ == "__main__":
    sys.exit(main())
