"""Remake the hit reactions and blocks as short snap-and-recover anims, for each stance.

  python tools/reactions.py build/anims build/anims/polished

g2's reactions only key the joints they change (head hits key the head once and hold it for a
whole second, blocks key one arm), so the stance idle shows through for everything else. these
keep that, but move each keyed joint from the stance's own pose to g2's hit pose and back on a
snap, overshoot, settle curve. head hits also drag the torso a frame late. the peek-a-boo versions
start from the peek-a-boo guard, so blocks stop jumping to the orthodox arm spot."""
import math, os, sys

from keyframes_to_parts import read_sequence, sample, to_quat, from_quat
from parts_to_keyframes import JOINTS, cframe_xml, identity, inv, mul

FPS = 30
# share of the hit pose on each frame: two frame snap, a touch of overshoot, then it settles
ENVELOPE = [0.0, 0.62, 1.0, 1.08, 1.0, 0.86, 0.68, 0.5, 0.34, 0.2, 0.09, 0.0, -0.04, -0.02, 0.0]
# stunned holds as long as the hitstun lasts (up to about a second), so it snaps in then sways
# like you're dazed instead of freezing in one pose like g2's. the state ending fades it out
STUN_ENVELOPE = [0.0, 0.6, 1.0] + [1.0 + 0.12 * math.sin(i * 2 * math.pi / 14) for i in range(1, 28)] + [1.0]
TORSO_DRAG = 0.25  # head hits move the torso this much of the head, a frame late
BLOCK_KNOCK = 22  # degrees a blocked punch knocks the glove up and back toward the face


def knock_back(joint, degrees):
    """pitch the arm up and back around the shoulder, about the torso's left-right axis. g2's block
    swings the arm 35-57 degrees out to the side, which only fit its own guard"""
    c0 = JOINTS[joint][1]
    rot = [row[:3] + [0] for row in c0[:3]] + [[0, 0, 0, 1]]
    a = math.radians(degrees)
    rx = [[1, 0, 0, 0], [0, math.cos(a), -math.sin(a), 0], [0, math.sin(a), math.cos(a), 0], [0, 0, 0, 1]]
    return mul(mul(inv(rot), rx), rot)

REACTIONS = {
    # name: joints to key (from g2's file), extra torso drag, pose it plays over, how much of g2's hit
    "HitHeadLeft": (["Head"], True, "Idle", 0.8),
    "HitHeadRight": (["Head"], True, "Idle", 0.8),
    "HitHeadTop": (["Head"], True, "Idle", 0.8),
    "HitBody": (["Torso", "Right Leg", "Left Leg"], False, "Idle", 1.0),
    # blocks only ever play with the guard up, so they start from the guard (see knock_back)
    "BlockLeft": (["Left Arm"], False, "Guard", 1.0),
    "BlockRight": (["Right Arm"], False, "Guard", 1.0),
    "Stunned": (["Torso", "Right Leg", "Left Leg"], False, "Idle", 1.0),
}
STANCES = ["", "PaB"]


def scaled(m, e):
    """the rotation and offset of m, taken e of the way (e can overshoot past 1)"""
    q = to_quat(m)
    if q[0] < 0:
        q = [-x for x in q]
    angle = 2 * math.acos(max(-1.0, min(1.0, q[0])))
    s = math.sin(angle / 2)
    if s < 1e-8:
        axis, angle = [1.0, 0.0, 0.0], 0.0
    else:
        axis = [x / s for x in q[1:]]
    a = angle * e
    q2 = [math.cos(a / 2)] + [x * math.sin(a / 2) for x in axis]
    return from_quat(q2, [m[i][3] * e for i in range(3)])


def peak(keys):
    """g2's key that moves the joint furthest from where it starts"""
    if len(keys) == 1:
        return keys[0][1]
    first = keys[0][1]

    def far(m):
        d = mul(inv(first), m)
        q = to_quat(d)
        return abs(2 * math.acos(max(-1.0, min(1.0, abs(q[0]))))) + sum(d[i][3] ** 2 for i in range(3)) ** 0.5

    return max((k[1] for k in keys), key=far)


def build(name, poses):
    ref = [0]

    def item(cls, props, children=""):
        ref[0] += 1
        return f'<Item class="{cls}" referent="R{ref[0]}"><Properties>{props}</Properties>{children}</Item>'

    def pose(part, m, children=""):
        return item("Pose", cframe_xml(m) + f'<string name="Name">{part}</string><float name="Weight">1</float>', children)

    def empty(part, children=""):
        # an unkeyed joint, there only to hold the hierarchy, so the idle shows through
        return item("Pose", f'<string name="Name">{part}</string><float name="Weight">0</float>', children)

    keyframes = ""
    for i, frame in enumerate(poses):
        limbs = "".join(pose(p, frame[p]) for p in ("Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg") if p in frame)
        torso = pose("Torso", frame["Torso"], limbs) if "Torso" in frame else empty("Torso", limbs)
        keyframes += item("Keyframe", f'<float name="Time">{i / FPS:.6f}</float>', empty("HumanoidRootPart", torso))
    seq = item(
        "KeyframeSequence",
        f'<bool name="Loop">false</bool><string name="Name">{name}</string><token name="Priority">3</token>',
        keyframes,
    )
    return f'<roblox version="4">{seq}</roblox>'


def main():
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    orth_idle, *_ = read_sequence(os.path.join(out_dir, "Idle.rbxmx"))
    for prefix in STANCES:
        for name, (joints, drag, under, amount) in REACTIONS.items():
            idle, *_ = read_sequence(os.path.join(out_dir, prefix + under + ".rbxmx"))
            keys, *_ = read_sequence(os.path.join(src_dir, name + ".rbxmx"))
            frames = []
            # the hit is g2's move from its first key to its peak. head hits only have one key, so
            # theirs is measured from the orthodox idle. taken in the parent's frame so it pushes the
            # same way off any stance's pose
            hits = {}
            for j in joints:
                if name.startswith("Block"):
                    hits[j] = knock_back(j, BLOCK_KNOCK)
                    continue
                start = keys[j][0][1] if len(keys[j]) > 1 else sample(orth_idle[j], 0)
                hits[j] = scaled(mul(peak(keys[j]), inv(start)), amount)
            if drag:
                head = hits["Head"]
                hits["Torso"] = scaled(from_quat(to_quat(head), [0, 0, 0]), TORSO_DRAG)
            env = STUN_ENVELOPE if name == "Stunned" else ENVELOPE
            for f in range(len(env)):
                pose = {}
                for j, hit in hits.items():
                    # the torso drag lands a frame after the head
                    e = env[max(0, f - 1)] if (drag and j == "Torso") else env[f]
                    pose[j] = mul(scaled(hit, e), sample(idle[j], 0))
                frames.append(pose)
            out_name = prefix + name
            open(os.path.join(out_dir, out_name + ".rbxmx"), "w", encoding="utf-8").write(build(out_name, frames))
            print(f"wrote {out_name}: {len(frames)} frames, keys {sorted(hits)}")


if __name__ == "__main__":
    main()
