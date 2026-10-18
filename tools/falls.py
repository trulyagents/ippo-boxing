"""Fix the knockdown and KO falls and their loops, from the importer's part json.

  python tools/falls.py build/anims/import4.json build/anims/falls.json

g2's falls stand still for 7 frames after the punch, drift down, then drop a full stud in 3
frames and end half a stud under the floor. here: a 2 frame hang, then the body falls faster and
faster (it should look sudden, not delayed), a small bounce when it lands, and every frame gets
lifted so no part goes under the floor. the loops get the same lift so the fall flows into them."""
import json, sys

from retime import PARTS, at, ease
from parts_to_keyframes import identity, mul

# R6 part sizes in blender axes (x, depth, height) and where each sits at rest
SIZE = {
    "Torso": (2, 1, 2),
    "Head": (1.2, 1.2, 1.2),
    "Right Arm": (1, 1, 2),
    "Left Arm": (1, 1, 2),
    "Right Leg": (1, 1, 2),
    "Left Leg": (1, 1, 2),
}
REST = {
    "Torso": (0, 0, 3),
    "Head": (0, 0, 4.5),
    "Right Arm": (1.5, 0, 3),
    "Left Arm": (-1.5, 0, 3),
    "Right Leg": (0.5, 0, 1),
    "Left Leg": (-0.5, 0, 1),
}
# new frame, source frame, ease. the source holds frames 1-7, drifts to 19, drops by 22
FALL = [(1, 1, "linear"), (3, 3, "linear"), (12, 19, "in"), (14, 22, "in")]
BOUNCE = [0.0, 0.16, 0.2, 0.12, 0.04, 0.0]  # extra lift on the frames right after landing
STAND_FEET = -0.07  # how far the feet already sit in the floor standing, leave that alone


def lowest(frame):
    z = 99.0
    for part, (sx, sy, sz) in SIZE.items():
        d = frame[part]
        px, py, pz = REST[part]
        for cx in (-sx / 2, sx / 2):
            for cy in (-sy / 2, sy / 2):
                for cz in (-sz / 2, sz / 2):
                    x, y, zz = px + cx, py + cy, pz + cz
                    z = min(z, d[2][0] * x + d[2][1] * y + d[2][2] * zz + d[2][3])
    return z


def lift(frame, dz):
    t = identity()
    t[2][3] = dz
    return {p: mul(t, frame[p]) for p in PARTS}


def floor_fix(frame, extra=0.0):
    under = STAND_FEET - lowest(frame)
    return lift(frame, max(0.0, under) + extra)


def main():
    src = json.load(open(sys.argv[1]))["anims"]
    out = {"fps": 30, "anims": {}}
    for kind in ("Down", "KO"):
        fall = src[kind + "Fall"]["frames"]
        new = []
        for (f0, s0, _), (f1, s1, k) in zip(FALL, FALL[1:]):
            for f in range(f0, f1):
                new.append(at(fall, s0 + (s1 - s0) * ease(k, (f - f0) / (f1 - f0))))
        land = len(new)
        # then the rest of g2's fall after it lands, with the bounce laid on top
        for i, s in enumerate(range(22, len(fall) + 1)):
            new.append(at(fall, s))
        new = [floor_fix(f, BOUNCE[i - land] if 0 <= i - land < len(BOUNCE) else 0.0) for i, f in enumerate(new)]
        loop = [floor_fix(f) for f in src[kind + "Loop"]["frames"]]
        out["anims"][kind + "Fall"] = {"loop": False, "frames": new, "key_frames": list(range(len(new)))}
        out["anims"][kind + "Loop"] = {"loop": True, "frames": loop, "key_frames": list(range(len(loop)))}
        lows = [round(lowest(f), 2) for f in new]
        print(f"{kind}Fall: {len(fall)} -> {len(new)} frames, lands on frame {land + 1}, lowest point per frame {lows}")
        print(f"{kind}Loop: lowest {round(min(lowest(f) for f in loop), 2)}")
    json.dump(out, open(sys.argv[2], "w"))


if __name__ == "__main__":
    main()
