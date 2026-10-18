"""Retime one-shot anims (punches, slips) from the importer's part json, and blend their ends into
the stance idle so they don't pop. writes a new json the blender importer reads the same way.

  python tools/retime.py build/anims/import2.json build/anims/import.json build/anims/tier2.json

each anim gets segments of (new frame, source frame, ease). frames are 1-based like blender.
ease "in" speeds up into the end of the segment (the strike), "smooth" eases both ends (the
pull back), "linear" is plain. source frames can be fractional, parts get slerped between."""
import json, math, sys

from keyframes_to_parts import from_quat, lerp_cf, slerp, to_quat

PARTS = ["HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]

PUNCH = {
    # name: (segments, new impact frame)
    "Jab": ([(1, 1, "linear"), (3, 3, "in"), (4, 4, "linear"), (9, 7, "smooth")], 3),
    "Cross": ([(1, 1, "linear"), (7, 7, "in"), (8, 8, "linear"), (15, 18, "smooth")], 7),
    "Hook": ([(1, 1, "linear"), (7, 7, "in"), (8, 8, "linear"), (14, 16, "smooth")], 7),
}
PUNCH["PaBJab"], PUNCH["PaBCross"], PUNCH["PaBHook"] = PUNCH["Jab"], PUNCH["Cross"], PUNCH["Hook"]
# slips keep their timing, but fade in from and back out to the idle pose over this many frames
SLIP_BLEND = {"SlipLeft": (0, 0), "SlipRight": (0, 6), "SlipDuck": (0, 0), "SlipBack": (3, 6)}


def ease(kind, u):
    if kind == "in":
        return u**1.7
    if kind == "smooth":
        return u * u * (3 - 2 * u)
    return u


def at(frames, s):
    """parts at a fractional source frame (1-based)"""
    s = min(max(s, 1), len(frames))
    i = int(math.floor(s)) - 1
    t = s - 1 - i
    a = frames[i]
    b = frames[min(i + 1, len(frames) - 1)]
    return {p: lerp_cf(a[p], b[p], t) for p in PARTS}


def mix(a, b, t):
    return {p: lerp_cf(a[p], b[p], t) for p in PARTS}


def retime(frames, segments):
    out = []
    for (f0, s0, _), (f1, s1, kind) in zip(segments, segments[1:]):
        for f in range(f0, f1):
            u = (f - f0) / (f1 - f0)
            out.append(at(frames, s0 + (s1 - s0) * ease(kind, u)))
    out.append(at(frames, segments[-1][1]))
    return out


def blend_ends(frames, idle, lead, tail):
    n = len(frames)
    out = list(frames)
    for i in range(lead):
        out[i] = mix(idle, frames[i], ease("smooth", i / lead))
    for k in range(tail):
        i = n - tail + k
        out[i] = mix(frames[i], idle, ease("smooth", (k + 1) / tail))
    return out


def main():
    src = json.load(open(sys.argv[1]))["anims"]
    idles = json.load(open(sys.argv[2]))["anims"]
    result = {"fps": 30, "anims": {}}
    for name, anim in src.items():
        frames = anim["frames"]
        idle = idles["PaBIdle" if name.startswith("PaB") else "Idle"]["frames"][0]
        impact = None
        if name in PUNCH:
            segments, impact = PUNCH[name]
            frames = retime(frames, segments)
            # punches already start and end on the idle, the blend just makes sure of it
            frames = blend_ends(frames, idle, 0, 1)
        elif name in SLIP_BLEND:
            lead, tail = SLIP_BLEND[name]
            frames = blend_ends(frames, idle, lead, tail)
        result["anims"][name] = {
            "loop": False,
            "length": (len(frames) - 1) / 30,
            "frames": frames,
            "key_frames": list(range(len(frames))),
            "impact_frame": impact,
        }
        extra = f", impact frame {impact} ({(impact - 1) / 30:.3f}s)" if impact else ""
        print(f"{name}: {len(anim['frames'])} -> {len(frames)} frames{extra}")
    json.dump(result, open(sys.argv[3], "w"))


if __name__ == "__main__":
    main()
