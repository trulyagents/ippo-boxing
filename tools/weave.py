"""Rebuild the Weave loop from its sparse keys (pulled from studio into build/anims/weave_keys.json)
as a smooth 30fps loop. the original was 9 linear keys, so the head moved round a stiff diamond.
here every part runs a looping catmull-rom through the same keys, and the torso leans into each
side it moves to, like a real weave under a hook.

  python tools/weave.py build/anims/weave_keys.json build/anims/Weave.rbxmx
"""
import json, math, sys

from keyframes_to_parts import from_quat, to_quat
import compose
from styles_export import write

LENGTH, LEAN = 0.8, 30.0  # seconds, degrees of lean per stud of side shift


def cyclic(keys, t):
    """looping catmull-rom over (time, values) keys spaced evenly across LENGTH"""
    keys = sorted(keys)[:-1] if abs(sorted(keys)[-1][0] - LENGTH) < 1e-3 else sorted(keys)
    n = len(keys)
    step = LENGTH / n
    u = (t % LENGTH) / step
    i = int(u) % n
    f = u - int(u)
    p0, p1, p2, p3 = (keys[(i + k) % n][1] for k in (-1, 0, 1, 2))
    return [0.5 * (2 * b + (c - a) * f + (2 * a - 5 * b + 4 * c - d) * f * f + (3 * b - a - 3 * c + d) * f ** 3) for a, b, c, d in zip(p0, p1, p2, p3)]


def main():
    raw = json.load(open(sys.argv[1]))
    tracks = {}
    for part, keys in raw.items():
        out = []
        ref = None
        for t, c in keys:
            m = [c[3:6] + [c[0]], c[6:9] + [c[1]], c[9:12] + [c[2]], [0, 0, 0, 1]]
            q = to_quat(m)
            if ref and sum(a * b for a, b in zip(q, ref)) < 0:
                q = [-x for x in q]
            ref = q
            out.append((t, [m[0][3], m[1][3], m[2][3]] + q))
        tracks[part] = out
    frames = []
    count = round(LENGTH * compose.FPS)
    for i in range(count + 1):
        t = i / compose.FPS
        frame = {}
        for part, keys in tracks.items():
            v = cyclic(keys, t)
            q = v[3:]
            norm = math.sqrt(sum(x * x for x in q))
            m = from_quat([x / norm for x in q], v[:3])
            if part == "Torso":
                a = math.radians(LEAN * v[0])
                c, s = math.cos(a), math.sin(a)
                r = [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]
                rot = [row[:3] + [0] for row in m[:3]] + [[0, 0, 0, 1]]
                rot = compose.mul(r, rot)
                for k in range(3):
                    rot[k][3] = m[k][3]
                m = rot
            frame[part] = m
        frames.append(frame)
    frames[-1] = frames[0]
    write("Weave", frames, True, sys.argv[2])
    print(f"Weave: {len(frames)} frames")


if __name__ == "__main__":
    main()
