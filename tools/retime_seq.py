"""Second pass on finished one-shot anims, straight on the KeyframeSequence: re-time it with a
piecewise time map and/or push a joint further from its first pose. keeps only the parts the
source keys, so a hit reaction that only moves the head and torso still leaves the guard arms.

  python tools/retime_seq.py build/anims/polished build/anims/retimed
"""
import math, os, sys

from keyframes_to_parts import FPS, read_sequence, sample, slerp, to_quat, from_quat
from parts_to_keyframes import cframe_xml, mul, inv
from retime import ease

# name: (time map as (new frame, source frame, ease into it), {joint: amplify})
# frames are 0-based here, 30fps
PASSES = {
    # the return to guard was faster than the punch itself. a slower recovery reads heavier
    "PaBCross": ([(0, 0, "linear"), (10, 10, "linear"), (17, 14, "smooth")], {}),
    # the right arm whipped on the first two frames, ease into the roll instead
    "RollLeft": ([(0, 0, "linear"), (4, 2, "in"), (29, 27, "linear")], {}),
    # the right head snap was a third of the left one
    "HitHeadRight": ([(0, 0, "linear"), (14, 14, "linear")], {"Head": 2.2}),
}
PASSES["PaBHitHeadRight"] = PASSES["HitHeadRight"]


def time_map(segs, f):
    for (n0, s0, _), (n1, s1, e) in zip(segs, segs[1:]):
        if n0 <= f <= n1:
            return s0 + (s1 - s0) * ease(e, (f - n0) / (n1 - n0))
    return segs[-1][1]


def amplify(m, ref, k):
    """push m away from ref by k (1 = unchanged), rotation only"""
    q, r = to_quat(m), to_quat(ref)
    rel = to_quat(mul(inv(ref), m))
    if rel[0] < 0:
        rel = [-x for x in rel]
    ang = 2 * math.acos(min(1, rel[0]))
    if ang < 1e-6:
        return m
    s = math.sin(ang / 2)
    axis = [x / s for x in rel[1:]]
    a = ang * k
    big = from_quat([math.cos(a / 2)] + [x * math.sin(a / 2) for x in axis], [0, 0, 0])
    out = mul(ref, big)
    for i in range(3):
        out[i][3] = m[i][3]
    return out


def write(name, frames, parts, path, priority=3):
    ref = [0]

    def item(cls, props, children=""):
        ref[0] += 1
        return f'<Item class="{cls}" referent="R{ref[0]}"><Properties>{props}</Properties>{children}</Item>'

    def pose(part, m, children="", weight=1):
        return item("Pose", cframe_xml(m) + f'<string name="Name">{part}</string><float name="Weight">{weight}</float>', children)

    kfs = ""
    for i, t in enumerate(frames):
        limbs = "".join(pose(p, t[p]) for p in ("Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg") if p in parts)
        torso = pose("Torso", t["Torso"], limbs, 1 if "Torso" in parts else 0)
        root = item("Pose", '<string name="Name">HumanoidRootPart</string><float name="Weight">0</float>', torso)
        kfs += item("Keyframe", f'<float name="Time">{i / FPS:.6f}</float>', root)
    seq = item("KeyframeSequence", f'<bool name="Loop">false</bool><string name="Name">{name}</string><token name="Priority">{priority}</token>', kfs)
    open(path, "w", encoding="utf-8").write(f'<roblox version="4">{seq}</roblox>')


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for name, (segs, amp) in PASSES.items():
        keys, length, loop, _ = read_sequence(os.path.join(src, name + ".rbxmx"))
        parts = {j for j, k in keys.items() if k}
        first = {j: sample(keys[j], 0) for j in keys}
        frames = []
        for f in range(segs[-1][0] + 1):
            t = time_map(segs, f) / FPS
            fr = {j: sample(keys[j], t) for j in keys}
            for j, k in amp.items():
                fr[j] = amplify(fr[j], first[j], k)
            frames.append(fr)
        write(name, frames, parts, os.path.join(out, name + ".rbxmx"))
        print(f"{name}: {len(frames)} frames, parts {sorted(parts)}")


if __name__ == "__main__":
    main()
