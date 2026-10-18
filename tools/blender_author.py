"""Posing helpers for keyframing new anims on the R6 V2.22 rig through the blender mcp.

  import blender_author as a
  a.key("WeaveRollR", 9, hips=[("Y", 22), ("X", -8)], right=("a", 65, 95), left=("t", (-0.45, 1.2, 4.1)))

arms take ("a", inward, raise) in degrees off the shoulder, or ("t", (x, y, z)) to put the fist
on a point (solved). hips take a list of (axis, degrees) on LowerTorso-FK: X- leans forward,
Y+ turns left, Z+ leans left. legs stay IK so the feet stay planted."""
import math

import bpy
from mathutils import Quaternion, Vector

import animation_tools
import blender_match_pose as m

AXES = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}


def Q(axis, degrees):
    return Quaternion(Vector(AXES[axis] if isinstance(axis, str) else axis), math.radians(degrees))


def _arm():
    return bpy.data.objects["__PrimaryArmature"]


def fist(side):
    o = bpy.data.objects[side + " Arm_MBlocky"].evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = o.to_mesh()
    loc = [v.co.copy() for v in me.vertices]
    o.to_mesh_clear()
    zmin = min(v.z for v in loc)
    b = [o.matrix_world @ v for v in loc if v.z < zmin + 0.05]
    return sum(b, Vector()) / len(b)


def arm_q(side, spec):
    arm = _arm()
    sign = 1 if side == "Right" else -1
    pb = arm.pose.bones[side + "Shoulder"]
    if spec[0] == "a":
        q = Q("X", spec[1]) @ Q("Y", sign * spec[2])
        pb.rotation_quaternion = q
        bpy.context.view_layer.update()
        return q
    target = Vector(spec[1])
    best = None

    def test(a, b):
        pb.rotation_quaternion = Q("X", a) @ Q("Y", sign * b)
        bpy.context.view_layer.update()
        return (fist(side) - target).length

    for b in range(40, 181, 10):
        for a in range(-30, 91, 10):
            d = test(a, b)
            if not best or d < best[0]:
                best = (d, a, b)
    for step in (4, 1):
        _, a0, b0 = best
        for b in range(b0 - 2 * step, b0 + 2 * step + 1, step):
            for a in range(a0 - 2 * step, a0 + 2 * step + 1, step):
                d = test(a, b)
                if d < best[0]:
                    best = (d, a, b)
    q = Q("X", best[1]) @ Q("Y", sign * best[2])
    pb.rotation_quaternion = q
    bpy.context.view_layer.update()
    return q


def key(action, frame, hips=(), loc=(0, -0.04, 0), right=("t", (0.45, 1.2, 4.1)), left=("t", (-0.45, 1.2, 4.1))):
    arm = _arm()
    bpy.context.scene.frame_set(frame)
    hb = arm.pose.bones["LowerTorso-FK"]
    q = Quaternion()
    for axis, deg in hips:
        q = q @ Q(axis, deg)
    hb.rotation_quaternion = q
    hb.location = loc
    bpy.context.view_layer.update()
    qr, ql = arm_q("Right", right), arm_q("Left", left)
    r = animation_tools.apply_pose(
        {
            "armature": "__PrimaryArmature",
            "action": action,
            "frame": frame,
            "interpolation": "CONSTANT",
            "bones": {
                "LowerTorso-FK": {"rotation_quaternion": list(q), "location": list(loc)},
                "RightShoulder": {"rotation_quaternion": list(qr)},
                "LeftShoulder": {"rotation_quaternion": list(ql)},
            },
        }
    )
    return tuple(round(x, 2) for x in fist("Right")), tuple(round(x, 2) for x in fist("Left"))


def start(action):
    """fresh action in authoring mode (IK legs, head tracking on), any old copy dropped"""
    m.set_import_mode(False)
    old = bpy.data.actions.get(action)
    if old:
        bpy.data.actions.remove(old)
    arm = _arm()
    act = bpy.data.actions.new(action)
    act.use_fake_user = True
    arm.animation_data.action = act
    m._reset(arm)
    return act
