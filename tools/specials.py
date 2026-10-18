"""Blend the start and end of the blender-made specials onto the stance idle, so they come out of
and go back into the guard without a pop, then write them in the importer's json format.

  python tools/specials.py build/anims/specials_raw.json build/anims/tier1_parts.json build/anims/specials.json

both inputs are raw bone matrices sampled in blender. each part's move from rest is what the
importer wants (it applies that to its own rest)."""
import json, sys

from parts_to_keyframes import inv, mul
from retime import blend_ends

PARTS = ["HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]
# name: idle it starts and ends on, frames to blend in, frames to blend out, impact frame
SPECIALS = {
    "RollRight": ("PaBIdle", 2, 3, 9),
    "RollLeft": ("PaBIdle", 2, 3, 9),
    "LungeUppercut": ("PaBIdle", 2, 4, 12),
    "StepCounter": ("Idle", 2, 4, 8),
}


def deltas(frames, rest):
    return [{p: mul(f[p], inv(rest[p])) for p in PARTS} for f in frames]


def main():
    raw = json.load(open(sys.argv[1]))
    tier1 = json.load(open(sys.argv[2]))
    out = {"fps": 30, "anims": {}}
    for name, (idle_name, lead, tail, impact) in SPECIALS.items():
        idle = deltas([tier1["anims"][idle_name]["frames"][0]], tier1["rest"])[0]
        frames = blend_ends(deltas(raw["anims"][name]["frames"], raw["rest"]), idle, lead, tail)
        out["anims"][name] = {"loop": False, "frames": frames, "key_frames": list(range(len(frames))), "impact_frame": impact}
        print(f"{name}: {len(frames)} frames, impact frame {impact} ({(impact - 1) / 30:.3f}s), ends on {idle_name}")
    json.dump(out, open(sys.argv[3], "w"))


if __name__ == "__main__":
    main()
