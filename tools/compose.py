"""Build a new anim out of key poses taken from anims that already look right, plus torso moves
on top, blended joint by joint. writes the importer's json so blender can check and preview it.

  python tools/compose.py build/anims/polished build/anims/composed.json

my first specials set the arms by angle off the shoulder, and with the torso twisted that aimed
every punch across the body. taking the arms from good punches at their impact frame fixes that,
since arms ride the torso the same way they did in the punch they came from."""
import json, math, os, sys

from keyframes_to_parts import FPS, from_quat, read_sequence, sample, slerp, to_quat, part_worlds, to_blender
from parts_to_keyframes import JOINTS, REST, identity, inv, mul
from retime import ease

ROOT_C0 = JOINTS["Torso"][1]


def torso_turn(lean=0.0, twist=0.0, side=0.0, drop=0.0):
    """a torso move in roblox's world axes around the hips: lean - is forward, twist + turns left,
    side + leans left, drop + sinks (studs)"""
    def rot(axis, deg):
        a = math.radians(deg)
        c, s = math.cos(a), math.sin(a)
        if axis == "x":
            return [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]
        if axis == "y":
            return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]
        return [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    r = mul(mul(rot("y", twist), rot("x", lean)), rot("z", side))
    r[1][3] = -drop
    c0r = [row[:3] + [0] for row in ROOT_C0[:3]] + [[0, 0, 0, 1]]
    return mul(mul(inv(c0r), r), c0r)


class Library:
    def __init__(self, folder):
        self.folder, self.cache = folder, {}

    def pose(self, name, frame):
        if name not in self.cache:
            # polished versions first, then the raw pulls and my own blender ones next to them
            path = os.path.join(self.folder, name + ".rbxmx")
            if not os.path.exists(path):
                path = os.path.join(os.path.dirname(self.folder.rstrip("/\\")), name + ".rbxmx")
            self.cache[name] = read_sequence(path)[0]
        keys = self.cache[name]
        return {j: sample(keys[j], (frame - 1) / FPS) for j in JOINTS}


def with_torso(pose, move):
    """move the torso, but keep each leg pointing the way it did in the world. R6 legs hang off
    the torso, so without this every lean or twist swings the legs and kicks a foot out"""
    out = dict(pose)
    out["Torso"] = mul(move, pose["Torso"])
    before, after = part_worlds(pose), part_worlds(out)
    for leg in ("Right Leg", "Left Leg"):
        _, c0, c1 = JOINTS[leg]
        want = [row[:] for row in after[leg]]
        for i in range(3):
            for k in range(3):
                want[i][k] = before[leg][i][k]
        out[leg] = mul(mul(mul(inv(c0), inv(after["Torso"])), want), c1)
    return out


def blend(a, b, t):
    out = {}
    for j in JOINTS:
        qa, qb = to_quat(a[j]), to_quat(b[j])
        pos = [a[j][i][3] + (b[j][i][3] - a[j][i][3]) * t for i in range(3)]
        out[j] = from_quat(slerp(qa, qb, t), pos)
    return out


def build(keys, lib):
    """keys: (frame, anim, anim frame, torso move dict, ease into this key)"""
    poses = [(f, with_torso(lib.pose(n, af), torso_turn(**mv)), e) for f, n, af, mv, e in keys]
    frames = []
    for (f0, p0, _), (f1, p1, e) in zip(poses, poses[1:]):
        for f in range(f0, f1):
            frames.append(blend(p0, p1, ease(e, (f - f0) / (f1 - f0))))
    frames.append(poses[-1][1])
    return frames


SPECIALS = {
    # weave roll right: from the guard dip down and under to the left, then come up out the right
    # side with the peek-a-boo hook. impact on frame 9
    "RollRight": [
        (1, "PaBIdle", 1, {}, "linear"),
        (5, "PaBIdle", 1, dict(lean=-16, side=12, twist=-10, drop=0.06), "smooth"),
        # frame 6 is where g2's hook is in front of the chin, by 7 it has swung on past
        (9, "PaBHook", 6, dict(lean=-6, side=-8, twist=6), "in"),
        (13, "PaBIdle", 1, {}, "smooth"),
    ],
    # gazelle style: sink deep with the hand chambered low, then drive up through the uppercut
    "LungeUppercut": [
        (1, "PaBIdle", 1, {}, "linear"),
        (6, "PaBUppercut", 5, dict(lean=-12, twist=-6, drop=0.08), "smooth"),
        (12, "PaBUppercut", 9, dict(lean=4, twist=6), "in"),
        (16, "PaBUppercut", 13, dict(lean=4, twist=8), "smooth"),
        (22, "PaBIdle", 1, {}, "smooth"),
    ],
    # step counter: slip off to the left, then step in behind the cross. impact on frame 8
    "StepCounter": [
        (1, "Idle", 1, {}, "linear"),
        (4, "Idle", 1, dict(lean=-10, side=12, twist=-8, drop=0.04), "smooth"),
        (8, "Cross", 7, dict(lean=-10, twist=4), "in"),
        (11, "Cross", 8, dict(lean=-8, twist=4), "linear"),
        (18, "Idle", 1, {}, "smooth"),
    ],
}


def mirror_roll(keys):
    """the left roll: the same moves with the side flipped and g2's peek-a-boo left hook"""
    out = []
    for f, n, af, mv, e in keys:
        mv = dict(mv)
        for k in ("side", "twist"):
            if k in mv:
                mv[k] = -mv[k]
        # the left hook is in front of the chin a frame earlier than the right
        out.append((f, "PaBHookLeft", 5, mv, e) if n == "PaBHook" else (f, n, af, mv, e))
    return out


S = [[-1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
SWAP = {"Right Arm": "Left Arm", "Left Arm": "Right Arm", "Right Leg": "Left Leg", "Left Leg": "Right Leg"}


def mirror_frames(json_frames):
    """flip a whole anim left for right, in blender space (x is the side axis there too).
    g2's peek-a-boo left hook flares the other arm out like a shrug, so the left roll is the right
    roll mirrored instead"""
    out = []
    for d in json_frames:
        m = {}
        for part, mat in d.items():
            src = SWAP.get(part, part)
            m[part] = mul(mul(S, d[src]), S)
        out.append(m)
    return out


def to_json(frames):
    out = []
    for t in frames:
        w = part_worlds(t)
        d = {}
        for part, pos in REST.items():
            b = identity()
            b[0][3], b[1][3], b[2][3] = pos
            d[part] = to_blender(mul(w[part], inv(b)))
        out.append(d)
    return out


def main():
    lib = Library(sys.argv[1])
    result = {"fps": FPS, "anims": {}}
    for name, keys in SPECIALS.items():
        frames = build(keys, lib)
        result["anims"][name] = {"loop": False, "frames": to_json(frames), "key_frames": list(range(len(frames)))}
        print(f"{name}: {len(frames)} frames")
    # mirrored, then the ends put back on the real idle so it doesn't start on a flipped guard
    from retime import blend_ends

    idle = to_json([lib.pose("PaBIdle", 1)])[0]
    left = blend_ends(mirror_frames(result["anims"]["RollRight"]["frames"]), idle, 3, 3)
    result["anims"]["RollLeft"] = {"loop": False, "frames": left, "key_frames": list(range(len(left)))}
    print(f"RollLeft: {len(left)} frames, mirror of RollRight")
    json.dump(result, open(sys.argv[2], "w"))


if __name__ == "__main__":
    main()
