"""Turn per-frame R6 part transforms sampled in Blender into KeyframeSequence .rbxmx files.

  python tools/parts_to_keyframes.py build/anims/pab_parts.json build/anims

the json comes from the blender rig (InternalArmature bone matrices for every frame plus the
rest pose). each joint's Transform is worked out from where the parts end up, using the
standard R6 Motor6D C0/C1, so it plays on our characters the same as it looks in blender.
publish the output with tools/publish_anims.py like any other anim."""
import json, os, sys

# tiny 4x4 helpers so this runs on plain python (rigid transforms only)


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def inv(m):
    # rotation part is orthonormal, so the inverse is the transpose
    r = [[m[j][i] for j in range(3)] for i in range(3)]
    t = [-sum(r[i][k] * m[k][3] for k in range(3)) for i in range(3)]
    return [r[0] + [t[0]], r[1] + [t[1]], r[2] + [t[2]], [0, 0, 0, 1]]


def identity():
    return [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]

# blender is z up and the rig faces +y, roblox is y up and faces -z
A = [[1, 0, 0, 0], [0, 0, 1, 0], [0, -1, 0, 0], [0, 0, 0, 1]]


def cf(x, y, z, *r):
    return [list(r[0:3]) + [x], list(r[3:6]) + [y], list(r[6:9]) + [z], [0, 0, 0, 1]]


# part0, part1, C0, C1 for the stock R6 rig
JOINTS = {
    "Torso": ("HumanoidRootPart", cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "Head": ("Torso", cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "Right Arm": ("Torso", cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "Left Arm": ("Torso", cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
    "Right Leg": ("Torso", cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "Left Leg": ("Torso", cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
}
# where each part sits in the stock rig with no anim playing (roblox space)
REST = {
    "HumanoidRootPart": (0, 3, 0),
    "Torso": (0, 3, 0),
    "Head": (0, 4.5, 0),
    "Right Arm": (1.5, 3, 0),
    "Left Arm": (-1.5, 3, 0),
    "Right Leg": (0.5, 1, 0),
    "Left Leg": (-0.5, 1, 0),
}


def to_roblox(m):
    return mul(mul(A, m), inv(A))


def part_worlds(frame, rest):
    out = {}
    for part, pos in REST.items():
        # how the part moved since rest in blender, carried over to roblox space
        delta = to_roblox(mul(frame[part], inv(rest[part])))
        base = identity()
        base[0][3], base[1][3], base[2][3] = pos
        out[part] = mul(delta, base)
    return out


def transforms(frame, rest):
    w = part_worlds(frame, rest)
    out = {}
    for part, (parent, c0, c1) in JOINTS.items():
        out[part] = mul(mul(mul(inv(c0), inv(w[parent])), w[part]), c1)
    return out


def cframe_xml(m):
    names = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    rot = [m[i][j] for i in range(3) for j in range(3)]
    s = '<CoordinateFrame name="CFrame">'
    s += "".join(f"<{k}>{v:.9f}</{k}>" for k, v in zip("XYZ", (m[0][3], m[1][3], m[2][3])))
    s += "".join(f"<{k}>{v:.9f}</{k}>" for k, v in zip(names, rot))
    return s + "</CoordinateFrame>"


def build(name, anim, rest):
    ref = [0]

    def item(cls, props, children=""):
        ref[0] += 1
        return f'<Item class="{cls}" referent="R{ref[0]}"><Properties>{props}</Properties>{children}</Item>'

    def pose(part, m, children=""):
        return item("Pose", cframe_xml(m) + f'<string name="Name">{part}</string><float name="Weight">1</float>', children)

    keyframes = ""
    for i, frame in enumerate(anim["frames"]):
        t = transforms(frame, rest)
        limbs = "".join(pose(p, t[p]) for p in ("Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"))
        torso = pose("Torso", t["Torso"], limbs)
        root = item("Pose", '<string name="Name">HumanoidRootPart</string><float name="Weight">0</float>', torso)
        keyframes += item("Keyframe", f'<float name="Time">{i / anim["fps"]:.6f}</float>', root)
    seq = item(
        "KeyframeSequence",
        f'<bool name="Loop">{"true" if anim.get("loop") else "false"}</bool><string name="Name">{name}</string>'
        f'<token name="Priority">{anim.get("priority", 3)}</token>',
        keyframes,
    )
    return f'<roblox version="4">{seq}</roblox>'


def main():
    src, out = sys.argv[1], sys.argv[2]
    data = json.load(open(src))
    os.makedirs(out, exist_ok=True)
    for name, anim in data["anims"].items():
        path = os.path.join(out, name + ".rbxmx")
        open(path, "w", encoding="utf-8").write(build(name, anim, data["rest"]))
        # rest frame should come out as no movement at all
        t0 = transforms(anim["frames"][0], data["rest"])
        offset = [round(t0["Torso"][i][3], 3) for i in range(3)]
        print(f"wrote {path}: {len(anim['frames'])} keyframes, frame 1 torso offset {offset}")
    t = transforms(data["rest"], data["rest"])
    ident = identity()
    worst = max(abs(m[i][j] - ident[i][j]) for m in t.values() for i in range(4) for j in range(4))
    print("rest pose check (should be ~0):", round(float(worst), 6))


if __name__ == "__main__":
    main()
