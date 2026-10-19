"""g2's boxer skip (JumpRopeAnim2) with the feet lifted out of the floor.

  python tools/jumprope.py build/anims/jumprope_parts.json build/anims/jumprope_fixed.json

g2 keyed the torso up to a quarter stud low, so both feet sat in the floor between skips. every
frame gets lifted just enough that the lowest foot is on the floor, the skips themselves stay."""
import json, sys

from falls import floor_fix, lowest
from parts_to_keyframes import identity
from retime import PARTS


def main():
    src = json.load(open(sys.argv[1]))["anims"]["JumpRope2"]
    frames = []
    for f in src["frames"]:
        fixed = floor_fix(f)
        # the root has to stay put, everything is posed relative to it
        fixed["HumanoidRootPart"] = f["HumanoidRootPart"]
        frames.append(fixed)
    print("lowest before", round(min(lowest(f) for f in src["frames"]), 2), "after", round(min(lowest(f) for f in frames), 2))
    # frames are moves from rest, so rest is no move at all
    rest = {p: identity() for p in PARTS}
    json.dump({"fps": 30, "rest": rest, "anims": {"JumpRope": {"fps": 30, "loop": True, "frames": frames, "key_frames": list(range(len(frames)))}}}, open(sys.argv[2], "w"))


if __name__ == "__main__":
    main()
