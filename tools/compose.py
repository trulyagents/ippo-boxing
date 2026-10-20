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


def torso_turn(lean=0.0, twist=0.0, side=0.0, drop=0.0, fwd=0.0, swing=None, lift=0.0, plant=None, slide=0.0, spread=None, arm_in=None):
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


def swing_joint(joint, degrees, axis="x"):
    """swing a limb forward (+) or back (-) from its hip or shoulder, around the torso's left-right
    axis. used for the lunge stride and to push a punch further out. axis "z" swings it in across
    the body (+) or out to the side (-) instead"""
    c0 = JOINTS[joint][1]
    rot = [row[:3] + [0] for row in c0[:3]] + [[0, 0, 0, 1]]
    a = math.radians(degrees)
    if axis == "z":
        rx = [[math.cos(a), -math.sin(a), 0, 0], [math.sin(a), math.cos(a), 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    else:
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
    # arms in across the body (+) or out (-). the right arm's sign is flipped so + is always inward
    for arm, deg in (mv.get("arm_in") or {}).items():
        pose[arm] = mul(swing_joint(arm, -deg if arm == "Right Arm" else deg, "z"), pose[arm])
    if floor is not None and mv:
        pose = settle(pose, floor)
        # legs that should both stand: nudge each one's swing until its foot is on the floor too
        # (a foot hangs in the air when the leg is swung further from straight down than the other)
        for leg in mv.get("plant") or []:
            best = (abs(leg_low(pose, leg) - floor), 0)
            for d in [x * 0.5 for x in range(-120, 121)]:
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


# punches that were missing their legs. off the neilarey and heavybjj punch charts (uppercuts sit
# down into the knees then drive the hips up) and evolve's level change body hook (wide, knees
# bent, leaning in). same frames and timing as the anim they're built on, only the legs and torso
# change: a split stance drops the hips with both feet down, then the uppercuts rise at impact
PUNCHES = {
    "Uppercut": [
        (1, "Uppercut", 1, {}, "linear"),
        (7, "Uppercut", 7, dict(lean=-12, side=6, twist=-6, swing={"Right Leg": -18, "Left Leg": 18}, plant=["Right Leg"]), "smooth"),
        (10, "Uppercut", 10, dict(lean=2, twist=6, swing={"Right Leg": -8, "Left Leg": 8}), "in"),
        (14, "Uppercut", 14, dict(swing={"Right Leg": -4, "Left Leg": 4}), "smooth"),
        (22, "Uppercut", 22, {}, "smooth"),
    ],
    "Body": [
        (1, "Body", 1, {}, "linear"),
        (5, "Body", 5, dict(lean=-10, side=6, swing={"Right Leg": -18, "Left Leg": 18}, plant=["Right Leg", "Left Leg"]), "smooth"),
        (7, "Body", 7, dict(lean=-16, side=8, swing={"Right Leg": -24, "Left Leg": 22}, plant=["Right Leg"]), "in"),
        (10, "Body", 10, dict(lean=-10, swing={"Right Leg": -14, "Left Leg": 12}, plant=["Right Leg"]), "linear"),
        (18, "Body", 18, {}, "smooth"),
    ],
    "PaBUppercut": [
        (1, "PaBUppercut", 1, {}, "linear"),
        (5, "PaBUppercut", 5, dict(lean=-6, swing={"Right Leg": -16, "Left Leg": 16}, plant=["Right Leg"]), "smooth"),
        (9, "PaBUppercut", 9, dict(lean=2, swing={"Right Leg": -6, "Left Leg": 6}), "in"),
        (13, "PaBUppercut", 13, dict(swing={"Right Leg": -3, "Left Leg": 3}), "smooth"),
        (21, "PaBUppercut", 21, {}, "smooth"),
    ],
}


# peek-a-boo guard stood bolt upright with the legs together. the tyson references are a wide
# crouched stance leaning in behind the gloves, so the whole loop gets that, keyed every 5 frames so
# g2's breathing between keys survives
CROUCH = dict(lean=-11, spread={"Right Leg": 9, "Left Leg": -9}, swing={"Right Leg": -10, "Left Leg": 10}, plant=["Right Leg", "Left Leg"])
# every key crouched, the first and last too, or it would pop up straight at every loop
PUNCHES["PaBGuard"] = [(f, "PaBGuard", f, CROUCH, "smooth") for f in [1] + list(range(6, 57, 5)) + [61]]
# g2's duck barely dipped. tyson's ducks bend nearly flat under the punch with the knees bent
PUNCHES["SlipDuck"] = [
    (1, "SlipDuck", 1, {}, "linear"),
    (4, "SlipDuck", 4, dict(lean=-20, swing={"Right Leg": -12, "Left Leg": 12}, spread={"Right Leg": 6, "Left Leg": -6}, plant=["Right Leg", "Left Leg"]), "smooth"),
    (8, "SlipDuck", 8, dict(lean=-34, swing={"Right Leg": -12, "Left Leg": 12}, spread={"Right Leg": 10, "Left Leg": -10}, plant=["Right Leg", "Left Leg"]), "smooth"),
    (12, "SlipDuck", 12, dict(lean=-16, swing={"Right Leg": -10, "Left Leg": 10}, plant=["Right Leg", "Left Leg"]), "smooth"),
    (16, "SlipDuck", 16, {}, "smooth"),
]


# the three new styles. each one is the orthodox loops with its own body shape on every key, so the
# footwork and breathing underneath stay. walks don't plant (their feet are mid step), loops do
STYLE_SHAPES = {
    # out-boxer: tall and bladed side on, lead hand low and loose for the jab, light on the toes
    "Out": dict(lean=3, twist=7, swing={"Left Arm": -22}, arm_in={"Left Arm": -6}),
    # slugger: wide and planted, sat down a little, square to the opponent, hands high and wide
    "Slug": dict(lean=-8, twist=-10, spread={"Right Leg": 9, "Left Leg": -9}, swing={"Right Arm": 10, "Left Arm": 10}, arm_in={"Right Arm": -10, "Left Arm": -10}),
    # philly shell: leaning back off the front foot, shoulder high, lead arm down across the belly,
    # rear glove up by the chin
    "Philly": dict(lean=7, side=5, twist=18, swing={"Left Arm": -72, "Right Arm": 12}, arm_in={"Left Arm": 36, "Right Arm": 14}),
}
STYLE_LOOPS = {"Idle": (49, 4), "Guard": (61, 5), "WalkForward": (16, 1), "WalkBack": (16, 1), "WalkLeft": (16, 1), "WalkRight": (16, 1)}
LOOPS = {"PaBGuard"}
for style, shape in STYLE_SHAPES.items():
    for base, (length, step) in STYLE_LOOPS.items():
        mv = dict(shape)
        if base.startswith("Walk"):
            mv.pop("spread", None)
        elif style != "Out":
            # the out-boxer's light twist keeps both feet down already, planting it shoots a leg out
            mv["plant"] = ["Right Leg", "Left Leg"]
        frames = sorted(set([1] + list(range(1, length + 1, step)) + [length]))
        PUNCHES[style + base] = [(f, base, f, mv, "smooth") for f in frames]
        LOOPS.add(style + base)

# their specials, built from the punches' own impact frames like the others
SPECIALS.update({
    # out-boxer pivot hook: step off to the side and turn the hook in from the new angle
    "PivotHook": [
        (1, "Idle", 1, {}, "linear"),
        (5, "Idle", 1, dict(twist=-22, slide=0.7, swing={"Right Leg": -14, "Left Leg": 10}, plant=["Right Leg"]), "smooth"),
        (9, "Hook", 6, dict(twist=14, slide=0.5, lean=-6, plant=["Right Leg"]), "in"),
        (14, "Idle", 1, {}, "smooth"),
    ],
    # slugger haymaker: sit back loading the rear hand, then throw the whole body over the top
    "Haymaker": [
        (1, "Idle", 1, {}, "linear"),
        (8, "Cross", 2, dict(lean=10, twist=-24, swing={"Right Arm": -30, "Right Leg": -12, "Left Leg": 12}, plant=["Right Leg", "Left Leg"]), "smooth"),
        (13, "Cross", 8, dict(lean=-26, twist=20, fwd=0.6, side=-6, swing={"Right Arm": 14, "Right Leg": -30, "Left Leg": 24}, plant=["Left Leg"]), "in"),
        (16, "Cross", 9, dict(lean=-22, twist=18, fwd=0.6, swing={"Right Leg": -26, "Left Leg": 20}, plant=["Left Leg"]), "linear"),
        (24, "Idle", 1, {}, "smooth"),
    ],
    # philly shoulder roll counter: roll the punch off the lead shoulder, come back with the cross
    "RollCounter": [
        (1, "Idle", 1, {}, "linear"),
        (5, "Idle", 1, dict(lean=10, side=8, twist=26, swing={"Left Arm": -40}, arm_in={"Left Arm": 30}, plant=["Right Leg", "Left Leg"]), "smooth"),
        (9, "Cross", 7, dict(lean=-10, twist=4, fwd=0.3, swing={"Right Leg": -20, "Left Leg": 16}, plant=["Right Leg"]), "in"),
        (16, "Idle", 1, {}, "smooth"),
    ],
    # philly check hook: pivot out on the front foot as they come in and hook on the turn
    "CheckHook": [
        (1, "Idle", 1, {}, "linear"),
        (6, "Hook", 6, dict(twist=34, lean=-4, slide=-0.5, swing={"Right Leg": 18, "Left Leg": -6}, plant=["Left Leg"]), "in"),
        (9, "Hook", 7, dict(twist=40, lean=-2, slide=-0.7, swing={"Right Leg": 24}, plant=["Left Leg"]), "linear"),
        (15, "Idle", 1, {}, "smooth"),
    ],
})


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
    for name, keys in list(SPECIALS.items()) + list(PUNCHES.items()):
        frames = build(keys, lib)
        if name in LOOPS:
            # foot planting can land a hair differently at each end, so the seam gets an exact copy
            frames[-1] = frames[0]
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
