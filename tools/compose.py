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


def torso_turn(lean=0.0, twist=0.0, side=0.0, drop=0.0, fwd=0.0, swing=None, lift=0.0, plant=None, slide=0.0, spread=None):
    """a torso move in roblox's world axes around the hips: lean - is forward, twist + turns left,
    side + leans left, drop + sinks, fwd + carries the body forward (studs). swing is handled in
    build (per joint), it's accepted here so a key can carry it"""
    def rot(axis, deg):
        a = math.radians(deg)
        c, s = math.cos(a), math.sin(a)
        if axis == "x":
            return [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]
        if axis == "y":
            return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]
        return [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    r = mul(mul(rot("y", twist), rot("x", lean)), rot("z", side))
    # pivot at the hips (a stud under the torso's centre), not the middle of the torso, or leaning
    # forward swings the hips back and drags both feet behind
    hip = [0.0, -1.0, 0.0]
    for i in range(3):
        r[i][3] = hip[i] - sum(r[i][k] * hip[k] for k in range(3))
    r[0][3] += slide
    r[1][3] -= drop
    r[2][3] -= fwd
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


def swing_joint(joint, degrees):
    """swing a limb forward (+) or back (-) from its hip or shoulder, around the torso's left-right
    axis. used for the lunge stride and to push a punch further out"""
    c0 = JOINTS[joint][1]
    rot = [row[:3] + [0] for row in c0[:3]] + [[0, 0, 0, 1]]
    a = math.radians(degrees)
    rx = [[1, 0, 0, 0], [0, math.cos(a), -math.sin(a), 0], [0, math.sin(a), math.cos(a), 0], [0, 0, 0, 1]]
    return mul(mul(inv(rot), rx), rot)


def swing_leg_world(pose, leg, degrees, axis="x"):
    """swing a leg forward (+) or back (-) around the world's left-right axis at its hip, or with
    axis "z" out to the side (+ moves the foot to the right). the torso is usually leaned and
    twisted, so swinging in its own axes tilted the legs out sideways"""
    _, c0, c1 = JOINTS[leg]
    w = part_worlds(pose)
    hip = mul(w["Torso"], c0)
    p = [hip[i][3] for i in range(3)]
    a = math.radians(degrees)
    if axis == "z":
        rx = [[math.cos(a), -math.sin(a), 0, 0], [math.sin(a), math.cos(a), 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    else:
        rx = [[1, 0, 0, 0], [0, math.cos(a), -math.sin(a), 0], [0, math.sin(a), math.cos(a), 0], [0, 0, 0, 1]]
    to, back = identity(), identity()
    for i in range(3):
        to[i][3], back[i][3] = p[i], -p[i]
    want = mul(mul(mul(to, rx), back), w[leg])
    out = dict(pose)
    out[leg] = mul(mul(mul(inv(c0), inv(w["Torso"])), want), c1)
    return out


def leg_low(pose, leg):
    w = part_worlds(pose)
    m = w[leg]
    return min(
        m[1][0] * cx + m[1][1] * cy + m[1][2] * cz + m[1][3]
        for cx in (-0.5, 0.5)
        for cy in (-1.0, 1.0)
        for cz in (-0.5, 0.5)
    )


def lowest_foot(pose):
    """lowest corner of either leg block (roblox y)"""
    w = part_worlds(pose)
    low = 99.0
    for leg in ("Right Leg", "Left Leg"):
        m = w[leg]
        for cx in (-0.5, 0.5):
            for cy in (-1.0, 1.0):
                for cz in (-0.5, 0.5):
                    low = min(low, m[1][0] * cx + m[1][1] * cy + m[1][2] * cz + m[1][3])
    return low


def settle(pose, floor):
    """move the whole body up or down so the lowest foot sits on the floor. hand set drops never
    matched what the rigid R6 legs actually do, a split stance needs exactly its own drop"""
    gap = lowest_foot(pose) - floor
    out = dict(pose)
    out["Torso"] = mul(torso_turn(drop=gap), pose["Torso"])
    return out


def keyed_pose(lib, n, af, mv, floor=None):
    pose = with_torso(lib.pose(n, af), torso_turn(**{k: v for k, v in mv.items() if k != "drop"}))
    for joint, deg in (mv.get("swing") or {}).items():
        if joint.endswith("Leg"):
            pose = swing_leg_world(pose, joint, deg)
        else:
            pose[joint] = mul(swing_joint(joint, deg), pose[joint])
    # legs out to the side, a wide stance drops the hips the same way a split does
    for leg, deg in (mv.get("spread") or {}).items():
        pose = swing_leg_world(pose, leg, deg, "z")
    if floor is not None and mv:
        pose = settle(pose, floor)
        # legs that should both stand: nudge each one's swing until its foot is on the floor too
        # (a foot hangs in the air when the leg is swung further from straight down than the other)
        for leg in mv.get("plant") or []:
            best = (abs(leg_low(pose, leg) - floor), 0)
            for d in [x * 0.5 for x in range(-60, 61)]:
                trial = settle(swing_leg_world(pose, leg, d), floor)
                err = abs(leg_low(trial, leg) - floor)
                if err < best[0]:
                    best = (err, d)
            pose = settle(swing_leg_world(pose, leg, best[1]), floor)
        # a key can still lift off on purpose (the trailing foot at contact)
        if mv.get("lift"):
            pose = dict(pose)
            pose["Torso"] = mul(torso_turn(drop=-mv["lift"]), pose["Torso"])
    return pose


def build(keys, lib):
    """keys: (frame, anim, anim frame, torso move dict, ease into this key). every key is settled so
    its lowest foot stands where the first key's does"""
    floor = lowest_foot(lib.pose(keys[0][1], keys[0][2]))
    poses = [(f, keyed_pose(lib, n, af, mv, floor), e) for f, n, af, mv, e in keys]
    frames = []
    for (f0, p0, _), (f1, p1, e) in zip(poses, poses[1:]):
        for f in range(f0, f1):
            frames.append(blend(p0, p1, ease(e, (f - f0) / (f1 - f0))))
    frames.append(poses[-1][1])
    return frames


SPECIALS = {
    # weave roll right, off a front on dempsey roll workout shot and a wikihow step: the whole body
    # shifts low to one side over that leg with the knees wide, head dropping under the punch line,
    # then comes up out the other side with the weight over the other leg and the hook from there.
    # slide moves the body sideways, spread widens the legs (which is what drops the hips on R6)
    "RollRight": [
        (1, "PaBIdle", 1, {}, "linear"),
        (5, "PaBIdle", 1, dict(lean=-18, side=14, twist=-10, slide=-0.6, spread={"Right Leg": 18, "Left Leg": -8}, plant=["Right Leg"]), "smooth"),
        (9, "PaBHook", 6, dict(lean=-8, side=-10, twist=6, slide=0.4, spread={"Right Leg": 6, "Left Leg": -16}), "in"),
        (13, "PaBIdle", 1, {}, "smooth"),
    ],
    # lunge uppercut, from real references (patterson and tyson fight photos, inoue's airborne one,
    # an illustrated side view sequence): sink into a long split stance with the front knee bent and
    # the back leg stretched behind, torso low and forward, hand chambered. then spring forward off
    # the back leg into one long diagonal, back leg trailing on the toe, uppercut out at head height.
    # R6 legs are rigid, so the split itself is what drops the hips: about 2 * (1 - cos(angle)) studs
    # per leg, the drop below matches it so the feet stay on the floor. the body leads forward, then
    # the game's 2.4 stud push carries the fighter after contact
    "LungeUppercut": [
        (1, "PaBIdle", 1, {}, "linear"),
        # an even split so both feet plant. tyson's side dip is in his upper body, a single R6 torso
        # can't bend there without tilting the hips and lifting a foot, so only a little of it
        (6, "PaBUppercut", 5, dict(lean=-30, side=3, twist=-10, swing={"Right Leg": -34, "Left Leg": 34}, plant=["Right Leg"]), "smooth"),
        (9, "PaBUppercut", 7, dict(lean=-24, twist=2, fwd=0.7, swing={"Right Leg": -40, "Left Leg": 26}), "in"),
        (12, "PaBUppercut", 9, dict(lean=-26, side=-4, twist=12, fwd=1.3, lift=0.12, swing={"Right Leg": -48, "Left Leg": 16, "Right Arm": -25}), "in"),
        (14, "PaBUppercut", 10, dict(lean=-16, twist=12, fwd=0.6, swing={"Right Leg": -35, "Left Leg": 14, "Right Arm": -18}), "linear"),
        (17, "PaBUppercut", 13, dict(lean=-8, twist=8, fwd=0.1, swing={"Right Leg": -15, "Left Leg": 8}), "smooth"),
        (22, "PaBIdle", 1, {}, "smooth"),
    ],
    # step counter, off an old boxing manual's cross counter and a stepping cross counter photo: slip
    # low and off the line, then step in with the lead foot and bring the cross over the top of
    # their arm, rear heel up, leaning in with the head still off the centre line
    "StepCounter": [
        (1, "Idle", 1, {}, "linear"),
        (4, "Idle", 1, dict(lean=-14, side=12, twist=-10, slide=-0.3, swing={"Right Leg": -16, "Left Leg": 16}, spread={"Left Leg": -8}, plant=["Right Leg"]), "smooth"),
        (8, "Cross", 7, dict(lean=-18, side=8, twist=6, fwd=0.6, swing={"Right Leg": -32, "Left Leg": 24, "Right Arm": 8}, plant=["Right Leg"]), "in"),
        (11, "Cross", 8, dict(lean=-14, side=6, twist=6, fwd=0.5, swing={"Right Leg": -28, "Left Leg": 20, "Right Arm": 6}, plant=["Right Leg"]), "linear"),
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
