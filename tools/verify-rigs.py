#!/usr/bin/env python3
"""Check a built place has a usable rig at every path the game looks one up.

    rojo build -o test.rbxl && python3 -I tools/verify-rigs.py test.rbxl

For every character module, looks for ReplicatedStorage.Assets.Characters.<Role>.<Name>
(or the ServerStorage fallback) in the built place and runs the R6 rig check on it.
Exit 0 only if every rig is present and passes.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load(mod, file):
    spec = importlib.util.spec_from_file_location(mod, os.path.join(HERE, file))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


ins = load("inspect_rbxm", "inspect-rbxm.py")
fr = load("fetch_rigs", "fetch-rigs.py")


def find(root, dotted):
    node = root
    for step in dotted.split("."):
        node = node.child(step) if node else None
    return node


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: verify-rigs.py <built.rbxl>")
    roots, insts = ins.load(sys.argv[1])
    if len(roots) == 1 and roots[0].cls == "DataModel":
        dm = roots[0]
    else:  # .rbxl: services are top-level instances
        dm = ins.Inst(0, "DataModel")
        dm.children = roots
    ok = True
    print(f"{'Name':<15} {'Status':<8} Path / problems")
    for name, role, _ in fr.modules():
        path = f"ReplicatedStorage.Assets.Characters.{role}.{name}"
        node = find(dm, path)
        if node is None:
            alt = f"ServerStorage.Assets.Characters.{role}.{name}"
            node = find(dm, alt)
            path = alt if node else path
        if node is None:
            ok = False
            print(f"{name:<15} MISSING  {path}")
            continue
        probs, _ = ins.rig_check(node, insts, fr.EXPECT.get(name, []))
        ok &= not probs
        print(f"{name:<15} {'OK' if not probs else 'BROKEN':<8} {path}" + ("" if not probs else "  <- " + "; ".join(probs)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
