"""Render 64x64 inventory icons for every item model (transparent, 1px dark outline).
Run: bmcp.py render_icons.py [id ...]  -> assets/items/icons/<id>.png
"""
import importlib
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import rzlib  # noqa: E402

importlib.reload(rzlib)
_requested = sys.argv[1:]
import assets_items  # noqa: E402

importlib.reload(assets_items)

SIZE = 64
OUT = os.path.join(rzlib.PROJECT, "assets", "items", "icons")


def render(name):
    rzlib.reset()
    p = rzlib.Part("Item")
    assets_items.ITEMS[name](p)
    objs = rzlib.build()
    sc = rzlib.scene()
    pts = [ob.matrix_world @ Vector(c) for ob in objs for c in ob.bound_box]
    lo = Vector((min(v.x for v in pts), min(v.y for v in pts), min(v.z for v in pts)))
    hi = Vector((max(v.x for v in pts), max(v.y for v in pts), max(v.z for v in pts)))
    center = (lo + hi) / 2
    d = Vector((math.sin(math.radians(45)), -math.cos(math.radians(45)), math.tan(math.radians(40)))).normalized()
    cam_data = bpy.data.cameras.new("rz_icon_cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("rz_icon_cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = center + d * 5
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    # Fit: project corners onto the camera plane.
    rot = cam.rotation_euler.to_matrix()
    right, up = rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0))
    ext = max(max(abs((v - center).dot(right)) for v in pts), max(abs((v - center).dot(up)) for v in pts))
    cam_data.ortho_scale = ext * 2.25
    sun_data = bpy.data.lights.new("rz_icon_sun", "SUN")
    sun_data.energy = 3.2
    sun = bpy.data.objects.new("rz_icon_sun", sun_data)
    sun.rotation_euler = (math.radians(40), 0, math.radians(20))
    sc.collection.objects.link(sun)
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = SIZE
    sc.render.resolution_y = SIZE
    sc.render.film_transparent = True
    sc.render.filter_size = 0.5
    if sc.world is None:
        sc.world = bpy.data.worlds.new("rz_prev_world")
    bg = sc.world.node_tree.nodes.get("Background") if sc.world.node_tree else None
    if bg:
        bg.inputs[0].default_value = (0.5, 0.5, 0.48, 1)
        bg.inputs[1].default_value = 0.9
    path = os.path.join(OUT, name + ".png")
    sc.render.filepath = path
    win = bpy.context.window_manager.windows[0]
    prev = win.scene
    win.scene = sc
    try:
        with bpy.context.temp_override(window=win, scene=sc):
            bpy.ops.render.render(write_still=True, scene=sc.name)
    finally:
        win.scene = prev
    for ob in (cam, sun):
        bpy.data.objects.remove(ob, do_unlink=True)
    _outline(path)
    return path


def _outline(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    a = px[:, :, 3] > 0.35
    grown = a.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown |= np.roll(np.roll(a, dy, 0), dx, 1)
    edge = grown & ~a
    px[a, 3] = 1.0
    px[~a & ~edge] = 0.0
    px[edge] = (0.08, 0.07, 0.06, 1.0)
    img.pixels = px.flatten().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


os.makedirs(OUT, exist_ok=True)
result = {"icons": [os.path.basename(render(n)) for n in (_requested or sorted(assets_items.ITEMS))]}
