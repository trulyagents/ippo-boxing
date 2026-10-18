"""Runs inside blender (through the mcp) on the R6 V2.22 rig: poses its controls so the
InternalArmature parts land where an imported anim puts them, and keys that into an action.

  import blender_match_pose as m
  m.import_anim(r"...\\build\\anims\\import.json", "Idle")

the json comes from tools/keyframes_to_parts.py (each part's move from rest, blender space).
each control gets a small least squares solve against the part it drives, done with finite
differences because the rig's Child Of and IK constraints make the maths awkward to do by hand."""
import json

import bpy
from mathutils import Matrix, Quaternion, Vector

ARM = "__PrimaryArmature"
INTERNAL = "InternalArmature"
PARTS = ["Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]

# control, part it drives, solve rotation, solve location, weight of the part's position error.
# imports run with the legs in FK and head tracking off (set_import_mode), since the bought anims
# pose legs and head directly. the bought anims also slide the arms forward from the shoulder,
# so shoulders get location too. punches also push the head forward off the neck, so the head does too
CHAIN = [
    ("LowerTorso-FK", "Torso", True, True, 2.0),
    ("Head", "Head", True, True, 2.0),
    ("RightShoulder", "Right Arm", True, True, 2.0),
    ("LeftShoulder", "Left Arm", True, True, 2.0),
    ("RightUpperLeg", "Right Leg", True, True, 2.0),
    ("LeftUpperLeg", "Left Leg", True, True, 2.0),
]


def set_import_mode(fk=True):
    """FK legs and no head tracking for imports, IK legs and tracking back for authoring"""
    for side in ("Right Leg", "Left Leg"):
        bpy.data.objects[side]["IK/FK"] = 0.0 if fk else 1.0
    bpy.data.objects["Head"]["Track Object"] = 0.0 if fk else 1.0
    for o in ("Right Leg", "Left Leg", "Head", ARM):
        bpy.data.objects[o].update_tag()
    bpy.context.view_layer.update()


def _arm():
    return bpy.data.objects[ARM], bpy.data.objects[INTERNAL]


def _part_world(internal, part):
    return internal.matrix_world @ internal.pose.bones[part].matrix


def _reset(arm):
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def rest_parts():
    arm, internal = _arm()
    action = arm.animation_data.action if arm.animation_data else None
    if arm.animation_data:
        arm.animation_data.action = None
    _reset(arm)
    bpy.context.view_layer.update()
    rest = {p: _part_world(internal, p).copy() for p in PARTS}
    if action:
        arm.animation_data.action = action
    return rest


def _residual(internal, part, target, pos_weight):
    cur = _part_world(internal, part)
    rot = (target.to_quaternion() @ cur.to_quaternion().inverted())
    if rot.w < 0:
        rot = -rot
    axis, angle = rot.to_axis_angle()
    r = list(axis * angle)
    if pos_weight > 0:
        r += list((target.translation - cur.translation) * pos_weight)
    return r


def _apply(pb, base_q, base_l, p, use_rot, use_loc):
    i = 0
    if use_rot:
        v = Vector(p[0:3])
        pb.rotation_quaternion = (Quaternion(v.normalized(), v.length) if v.length > 1e-9 else Quaternion()) @ base_q
        i = 3
    if use_loc:
        pb.location = base_l + Vector(p[i : i + 3])


def _linsolve(m, b):
    # gaussian elimination with partial pivoting, mathutils matrices stop at 4x4
    n = len(b)
    a = [row[:] + [b[i]] for i, row in enumerate(m)]
    for c in range(n):
        piv = max(range(c, n), key=lambda r: abs(a[r][c]))
        if abs(a[piv][c]) < 1e-12:
            return None
        a[c], a[piv] = a[piv], a[c]
        for r in range(c + 1, n):
            f = a[r][c] / a[c][c]
            for k in range(c, n + 1):
                a[r][k] -= f * a[c][k]
    x = [0.0] * n
    for r in range(n - 1, -1, -1):
        x[r] = (a[r][n] - sum(a[r][k] * x[k] for k in range(r + 1, n))) / a[r][r]
    return x


def solve_control(arm, internal, ctrl, part, target, use_rot, use_loc, pos_weight, iters=30):
    pb = arm.pose.bones[ctrl]
    n = (3 if use_rot else 0) + (3 if use_loc else 0)
    base_q, base_l = pb.rotation_quaternion.copy(), pb.location.copy()
    p = [0.0] * n
    eps = 1e-3
    for _ in range(iters):
        _apply(pb, base_q, base_l, p, use_rot, use_loc)
        bpy.context.view_layer.update()
        r0 = _residual(internal, part, target, pos_weight)
        if sum(x * x for x in r0) < 1e-10:
            break
        cols = []
        for k in range(n):
            q = list(p)
            q[k] += eps
            _apply(pb, base_q, base_l, q, use_rot, use_loc)
            bpy.context.view_layer.update()
            r1 = _residual(internal, part, target, pos_weight)
            cols.append([(a - b) / eps for a, b in zip(r1, r0)])
        # damped normal equations, J is rows x n
        jt_j = [[sum(cols[a][i] * cols[b][i] for i in range(len(r0))) for b in range(n)] for a in range(n)]
        for a in range(n):
            jt_j[a][a] += 1e-4
        jt_r = [sum(cols[a][i] * r0[i] for i in range(len(r0))) for a in range(n)]
        step = _linsolve(jt_j, jt_r)
        if step is None:
            break
        p = [x - s for x, s in zip(p, step)]
    _apply(pb, base_q, base_l, p, use_rot, use_loc)
    bpy.context.view_layer.update()
    err = _residual(internal, part, target, pos_weight)
    return sum(x * x for x in err) ** 0.5


def import_anim(json_path, name, action_name=None, rest=None, every_frame=False):
    arm, internal = _arm()
    data = json.load(open(json_path))["anims"][name]
    set_import_mode(True)
    rest = rest or rest_parts()
    action = bpy.data.actions.get(action_name or name) or bpy.data.actions.new(action_name or name)
    action.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = action
    # start every import from the rig's neutral pose so leftovers don't leak in
    _reset(arm)
    worst = 0.0
    # fast one-shots (punches, slips) drift between sparse keys, so those get a key on every frame
    key_frames = list(range(len(data["frames"]))) if every_frame else data["key_frames"]
    for kf in key_frames:
        frame = kf + 1
        bpy.context.scene.frame_set(frame)
        delta = data["frames"][kf]
        for ctrl, part, use_rot, use_loc, pos_weight in CHAIN:
            target = Matrix(delta[part]) @ rest[part]
            worst = max(worst, solve_control(arm, internal, ctrl, part, target, use_rot, use_loc, pos_weight))
            pb = arm.pose.bones[ctrl]
            if use_rot:
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=ctrl)
            if use_loc:
                pb.keyframe_insert("location", frame=frame, group=ctrl)
    for fc in action.fcurves if hasattr(action, "fcurves") else []:
        for k in fc.keyframe_points:
            k.interpolation = "BEZIER"
            k.handle_left_type = k.handle_right_type = "AUTO_CLAMPED"
    return {"action": action.name, "keys": [k + 1 for k in key_frames], "worst_error": round(worst, 4)}


def check(json_path, name, rest=None):
    """how far the keyed action strays from the source on every frame, not just the keys"""
    arm, internal = _arm()
    data = json.load(open(json_path))["anims"][name]
    rest = rest or rest_parts()
    worst = {}
    for i, delta in enumerate(data["frames"]):
        bpy.context.scene.frame_set(i + 1)
        for part in PARTS:
            target = Matrix(delta[part]) @ rest[part]
            cur = _part_world(internal, part)
            d = (target.translation - cur.translation).length
            worst[part] = max(worst.get(part, 0), round(d, 3))
    return worst


def import_checked(json_path, name, action_name=None, every_frame=False):
    """import, then report the worst position (studs) and rotation (degrees) miss over every frame"""
    action_name = action_name or name + "_src"
    old = bpy.data.actions.get(action_name)
    if old:
        bpy.data.actions.remove(old)
    set_import_mode(True)
    rest = rest_parts()
    import_anim(json_path, name, action_name, rest, every_frame)
    arm, internal = _arm()
    data = json.load(open(json_path))["anims"][name]
    pos, rot = 0.0, 0.0
    for i, delta in enumerate(data["frames"]):
        bpy.context.scene.frame_set(i + 1)
        for part in PARTS:
            t = Matrix(delta[part]) @ rest[part]
            c = _part_world(internal, part)
            pos = max(pos, (t.translation - c.translation).length)
            a = t.to_quaternion().rotation_difference(c.to_quaternion()).angle * 57.2958
            rot = max(rot, min(a, 360 - a))
    return {"action": action_name, "frames": len(data["frames"]), "worst_studs": round(pos, 3), "worst_deg": round(rot, 1)}


def _fcurves(action):
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def _curve(action, bone, path, index):
    for fc in _fcurves(action):
        if fc.data_path == f'pose.bones["{bone}"].{path}' and fc.array_index == index:
            return fc
    return None


def polish_loop(name, end, step, bob=0.0, bob_cycles=1, sway=0.0, twist=0.0, arm_lag=2, arm_bob=0.0, head_lag=3, head_nod=0.0):
    """resample a looping action every `step` frames and layer breathing/bounce, sway, arm overlap
    and head settle on top. every offset is a whole number of sine cycles over the loop, so the
    loop stays seamless. the last frame becomes an exact copy of the first and the curves go cyclic"""
    import math

    arm, _ = _arm()
    src = bpy.data.actions[name + "_src"]
    action = bpy.data.actions.get(name) or bpy.data.actions.new(name)
    action.use_fake_user = True
    # start from a clean copy of the import
    for fc in list(_fcurves(action)):
        try:
            action.fcurves.remove(fc)
        except Exception:
            pass
    arm.animation_data.action = src
    length = end - 1
    frames = list(range(1, end, step))
    bones = {"LowerTorso-FK", "Head", "RightShoulder", "LeftShoulder", "RightUpperLeg", "LeftUpperLeg"}
    samples = {}
    for f in frames:
        bpy.context.scene.frame_set(f)
        samples[f] = {b: (arm.pose.bones[b].location.copy(), arm.pose.bones[b].rotation_quaternion.copy()) for b in bones}

    def wave(f, lag=0, cycles=1):
        return math.sin(2 * math.pi * cycles * ((f - 1 - lag) % length) / length)

    arm.animation_data.action = action
    for f in frames + [end]:
        base = samples[f if f in samples else 1]
        for b in bones:
            loc, rot = base[b][0].copy(), base[b][1].copy()
            if b == "LowerTorso-FK":
                # local y is up on this control
                loc.y += bob * wave(f, 0, bob_cycles)
                rot = Quaternion((0, 0, 1), math.radians(sway) * wave(f, 0, 1)) @ rot
                rot = Quaternion((0, 1, 0), math.radians(twist) * wave(f, 0, 1)) @ rot
            elif b in ("RightShoulder", "LeftShoulder"):
                sign = 1 if b == "RightShoulder" else -1
                # arms ride the torso a couple of frames late, so they read as weight not a rigid block
                rot = Quaternion((0, 1, 0), sign * math.radians(arm_bob) * wave(f, arm_lag, bob_cycles)) @ rot
            elif b == "Head":
                rot = Quaternion((1, 0, 0), math.radians(head_nod) * wave(f, head_lag, bob_cycles)) @ rot
            pb = arm.pose.bones[b]
            pb.location, pb.rotation_quaternion = loc, rot
            pb.keyframe_insert("location", frame=f, group=b)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=b)
    # exact seam, then cyclic so the handles at the loop point line up
    for fc in _fcurves(action):
        pts = fc.keyframe_points
        pts[-1].co.y = pts[0].co.y
        for k in pts:
            k.interpolation = "BEZIER"
            k.handle_left_type = k.handle_right_type = "AUTO_CLAMPED"
        if not any(mod.type == "CYCLES" for mod in fc.modifiers):
            fc.modifiers.new("CYCLES")
        fc.update()
    return {"action": action.name, "keys": len(frames) + 1, "curves": len(_fcurves(action))}
