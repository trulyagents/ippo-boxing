"""Write the three new styles' loops and their specials (built in compose.py) straight to
KeyframeSequence .rbxmx files. compose works in Motor6D Transforms, the same numbers a
KeyframeSequence stores, so there's no trip through blender for these.

  python tools/styles_export.py build/anims/polished build/anims/styles
"""
import os, sys

import compose
from parts_to_keyframes import cframe_xml

NAMES = [s + b for s in compose.STYLE_SHAPES for b in compose.STYLE_LOOPS] + ["PivotHook", "Haymaker", "RollCounter", "CheckHook"]


# same priority as the anim each one is built on: idle 0, walks and weave 1, guard 2, punches and specials 3
def priority(name):
    for base, p in (("Idle", 0), ("Walk", 1), ("Weave", 1), ("Guard", 2)):
        if base in name:
            return p
    return 3


def write(name, frames, loop, path):
    ref = [0]

    def item(cls, props, children=""):
        ref[0] += 1
        return f'<Item class="{cls}" referent="R{ref[0]}"><Properties>{props}</Properties>{children}</Item>'

    def pose(part, m, children=""):
        return item("Pose", cframe_xml(m) + f'<string name="Name">{part}</string><float name="Weight">1</float>', children)

    keyframes = ""
    for i, t in enumerate(frames):
        limbs = "".join(pose(p, t[p]) for p in ("Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"))
        torso = pose("Torso", t["Torso"], limbs)
        root = item("Pose", '<string name="Name">HumanoidRootPart</string><float name="Weight">0</float>', torso)
        keyframes += item("Keyframe", f'<float name="Time">{i / compose.FPS:.6f}</float>', root)
    seq = item(
        "KeyframeSequence",
        f'<bool name="Loop">{"true" if loop else "false"}</bool><string name="Name">{name}</string>'
        f'<token name="Priority">{priority(name)}</token>',
        keyframes,
    )
    open(path, "w", encoding="utf-8").write(f'<roblox version="4">{seq}</roblox>')


def main():
    lib = compose.Library(sys.argv[1])
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    every = dict(compose.SPECIALS, **compose.PUNCHES)
    for name in NAMES:
        loop = name in compose.LOOPS
        frames = compose.build(every[name], lib, loop)
        if loop:
            frames[-1] = frames[0]
        write(name, frames, loop, os.path.join(out, name + ".rbxmx"))
        print(f"{name}: {len(frames)} frames{' loop' if loop else ''}")


if __name__ == "__main__":
    main()
