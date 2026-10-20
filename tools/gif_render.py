"""Render every baked anim (build/anims/gif/all.json, world matrices in blender space) on copies of
the R6 rig's blocky body meshes, one png per frame. run inside blender through the mcp:
  exec(open(path).read()); setup(); render(["Jab", ...])
"""
import json, os
import bpy
from mathutils import Matrix

ROOT = r"C:\Users\itsge\OneDrive\Desktop\Ippo Boxing\build\anims\gif"
PARTS = ["Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]
# roblox (x, y, z) to blender (x, -z, y)
TO_BL = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def setup():
    sc = bpy.data.scenes.get("GIF") or bpy.data.scenes.new("GIF")
    bpy.context.window.scene = sc
    for p in PARTS:
        name = "GIF_" + p
        if name in bpy.data.objects:
            continue
        src = bpy.data.objects[p + "_MBlocky"]
        me = src.data.copy()
        me.transform(TO_BL)
        o = bpy.data.objects.new(name, me)
        sc.collection.objects.link(o)
    if "GIF_Floor" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=10)
        bpy.context.object.name = "GIF_Floor"
    cam = bpy.data.objects.get("GIF_Cam")
    if not cam:
        cam = bpy.data.objects.new("GIF_Cam", bpy.data.cameras.new("GIF_Cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.4
    cam.location = (6.8, 8.8, 4.8)
    from mathutils import Vector
    cam.rotation_euler = (Vector((0, 0, 2.55)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    r = sc.render
    try:
        r.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_shadows = True
    sc.display.shading.show_cavity = True
    r.resolution_x = r.resolution_y = 384
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    r.film_transparent = False
    world = sc.world or bpy.data.worlds.new("GIF_World")
    sc.world = world
    return "ok"


def render(names):
    data = json.load(open(os.path.join(ROOT, "all.json")))
    sc = bpy.context.scene
    done = []
    for n in names:
        folder = os.path.join(ROOT, "png", n)
        os.makedirs(folder, exist_ok=True)
        for i, fr in enumerate(data[n]["frames"]):
            for p in PARTS:
                bpy.data.objects["GIF_" + p].matrix_world = Matrix(fr[p])
            sc.render.filepath = os.path.join(folder, "%03d.png" % i)
            bpy.ops.render.render(write_still=True)
        done.append(n)
    return done
