"""Render an isometric preview of the asset scene (same 30deg/45deg angle as the game camera)."""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import rzlib  # noqa: E402

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(rzlib.PROJECT, "tools", "blender", "preview.png")
ortho = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
target = Vector((0, 0, float(sys.argv[3]) if len(sys.argv) > 3 else 0.9))

sc = rzlib.scene()
for ob in [o for o in sc.collection.objects if o.name.startswith("rz_prev")]:
    bpy.data.objects.remove(ob, do_unlink=True)

cam_data = bpy.data.cameras.new("rz_prev_cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = ortho
cam = bpy.data.objects.new("rz_prev_cam", cam_data)
sc.collection.objects.link(cam)
# Game camera: looks from +X/-Y(front) side... Godot camera sits at +X,+Z (Godot) = +X,-Y (Blender).
d = Vector((math.sin(math.radians(45)), -math.cos(math.radians(45)), math.tan(math.radians(30)))).normalized()
cam.location = target + d * 20
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()

sun_data = bpy.data.lights.new("rz_prev_sun", "SUN")
sun_data.energy = 3.0
sun = bpy.data.objects.new("rz_prev_sun", sun_data)
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
sc.collection.objects.link(sun)

sc.camera = cam
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = 480
sc.render.resolution_y = 480
sc.render.film_transparent = False
if sc.world is None:
    sc.world = bpy.data.worlds.new("rz_prev_world")
try:
    sc.world.use_nodes = True
except Exception:
    pass
bg = sc.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.35, 0.36, 0.33, 1)
    bg.inputs[1].default_value = 0.8
sc.render.filepath = out
win = bpy.context.window_manager.windows[0]
prev = win.scene
win.scene = sc
try:
    with bpy.context.temp_override(window=win, scene=sc):
        bpy.ops.render.render(write_still=True, scene=sc.name)
finally:
    win.scene = prev
for ob in [o for o in sc.collection.objects if o.name.startswith("rz_prev")]:
    bpy.data.objects.remove(ob, do_unlink=True)
result = {"preview": out}
