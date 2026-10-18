"""The reverse of parts_to_keyframes: read KeyframeSequence .rbxmx files and write where every
R6 part sits on each 30 fps frame, in blender space, so the blender rig can be posed to match.

  python tools/keyframes_to_parts.py build/anims/import.json build/anims/Idle.rbxmx build/anims/Guard.rbxmx ...

poses missing from a keyframe get filled in between the keyframes around them (linear, slerp
for rotation), which is close to what roblox does for the linear and cubic eases these use."""
import json, math, os, sys
import xml.etree.ElementTree as ET

from parts_to_keyframes import A, JOINTS, REST, identity, inv, mul

FPS = 30


def prop(it, n):
    p = it.find("Properties")
    for c in p if p is not None else []:
        if c.get("name") == n:
            return c


def read_cframe(c):
    v = {ch.tag: float(ch.text) for ch in c}
    r = [v[k] for k in ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
    return [r[0:3] + [v["X"]], r[3:6] + [v["Y"]], r[6:9] + [v["Z"]], [0, 0, 0, 1]]


def to_quat(m):
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        return [0.25 * s, (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s]
    if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2
        return [(m[2][1] - m[1][2]) / s, 0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s]
    if m[1][1] > m[2][2]:
        s = math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2
        return [(m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s]
    s = math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2
    return [(m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s]


def from_quat(q, pos):
    w, x, y, z = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), pos[0]],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), pos[1]],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), pos[2]],
        [0, 0, 0, 1],
    ]


def slerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0:
        b, d = [-x for x in b], -d
    if d > 0.9995:
        q = [x + (y - x) * t for x, y in zip(a, b)]
    else:
        th = math.acos(d)
        q = [(x * math.sin((1 - t) * th) + y * math.sin(t * th)) / math.sin(th) for x, y in zip(a, b)]
    n = math.sqrt(sum(x * x for x in q))
    return [x / n for x in q]


def lerp_cf(a, b, t):
    pos = [a[i][3] + (b[i][3] - a[i][3]) * t for i in range(3)]
    return from_quat(slerp(to_quat(a), to_quat(b), t), pos)


def read_sequence(path):
    root = ET.parse(path).getroot()
    ks = next(it for it in root.iter("Item") if it.get("class") == "KeyframeSequence")
    loop = (prop(ks, "Loop").text or "") == "true" if prop(ks, "Loop") is not None else False
    keys = {joint: [] for joint in JOINTS}
    times = set()
    length = 0.0
    for kf in ks.findall("Item"):
        if kf.get("class") != "Keyframe":
            continue
        t_el = prop(kf, "Time")
        t = float(t_el.text) if t_el is not None else 0.0
        length = max(length, t)
        times.add(round(t * FPS))
        for pose in kf.iter("Item"):
            if pose.get("class") != "Pose":
                continue
            name = prop(pose, "Name").text
            c = prop(pose, "CFrame")
            if name in keys and c is not None:
                keys[name].append((t, read_cframe(c)))
    for k in keys.values():
        k.sort(key=lambda e: e[0])
    return keys, length, loop, sorted(times)


def sample(keys, t):
    if not keys:
        return identity()
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            return lerp_cf(a, b, (t - t0) / (t1 - t0) if t1 > t0 else 0)
    return keys[-1][1]


def part_worlds(transforms):
    w = {"HumanoidRootPart": identity()}
    w["HumanoidRootPart"][1][3] = REST["HumanoidRootPart"][1]
    for part in ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"):
        parent, c0, c1 = JOINTS[part]
        w[part] = mul(mul(mul(w[parent], c0), transforms[part]), inv(c1))
    return w


def to_blender(m):
    return mul(mul(inv(A), m), A)


def main():
    out, paths = sys.argv[1], sys.argv[2:]
    result = {"fps": FPS, "anims": {}}
    for path in paths:
        name = os.path.splitext(os.path.basename(path))[0]
        keys, length, loop, key_frames = read_sequence(path)
        frames = []
        for i in range(int(round(length * FPS)) + 1):
            w = part_worlds({j: sample(keys[j], i / FPS) for j in JOINTS})
            # each part's move from its rest spot, in blender space. the blender side applies it to
            # its own rest matrices, so bone axes don't have to match roblox part axes
            delta = {}
            for part, pos in REST.items():
                base = identity()
                base[0][3], base[1][3], base[2][3] = pos
                delta[part] = to_blender(mul(w[part], inv(base)))
            frames.append(delta)
        # the original keyframe spots, so the blender side keys only those and the curves stay clean
        result["anims"][name] = {"loop": loop, "length": length, "frames": frames, "key_frames": key_frames}
        print(f"{name}: {len(frames)} frames, {length:.2f}s, loop {loop}, keys at {key_frames}")
    json.dump(result, open(out, "w"))


if __name__ == "__main__":
    main()
