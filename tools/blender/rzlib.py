"""Asset-building helpers executed inside Blender (through the MCP socket server).

Conventions (Blender space): Z up, model front faces -Y, 1 unit = 1 metre.
After glTF export the model faces +Z in Godot and stands on y = 0.
"""
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

PROJECT = r"D:\AI Projects\Project_Zomboid\Claude"
SCENE_NAME = "RZ_AssetBuild"

_parts = []


def scene():
    sc = bpy.data.scenes.get(SCENE_NAME)
    if sc is None:
        sc = bpy.data.scenes.new(SCENE_NAME)
    return sc


def reset():
    sc = scene()
    for ob in list(sc.collection.all_objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for cu in list(bpy.data.curves):
        if cu.users == 0:
            bpy.data.curves.remove(cu)
    _parts.clear()


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mat(name, color, rough=0.9, metal=0.0, emit=0.0, alpha=1.0):
    """Material named RZ_<name>. The Godot importer keys special shaders off the name."""
    key = "RZ_" + name
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = None
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
    if bsdf is None:
        bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        out = m.node_tree.nodes.get("Material Output") or m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        m.node_tree.links.new(bsdf.outputs[0], out.inputs[0])
    rgb = hexcol(color) if isinstance(color, str) else color
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    m.diffuse_color = (*rgb, alpha)
    return m


class Part:
    """One exported node. Geometry is accumulated into a bmesh relative to the node origin."""

    def __init__(self, name, parent=None, loc=(0, 0, 0)):
        self.name = name
        self.parent = parent
        self.loc = Vector(loc)
        self.bm = bmesh.new()
        self.mats = []
        self.smooth_faces = set()
        self.ob = None
        _parts.append(self)

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _finish(self, verts, m, smooth=False, bevel=0.0):
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        if bevel > 0:
            edges = set()
            for f in faces:
                edges.update(f.edges)
            res = bmesh.ops.bevel(self.bm, geom=list(edges) + list(verts), offset=bevel, segments=1,
                                  affect="EDGES", profile=0.5, clamp_overlap=True)
            faces.update(res.get("faces", []))
            for v in res.get("verts", []):
                faces.update(v.link_faces)
        idx = self._mi(m)
        for f in faces:
            if f.is_valid:
                f.material_index = idx
                f.smooth = smooth
        return self

    def box(self, size, center=(0, 0, 0), m=None, rot=(0, 0, 0), bevel=0.0, taper=None):
        """Axis box of `size` centred at `center`. taper=(sx, sy) scales the top face."""
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        if taper:
            for v in verts:
                if v.co.z > 0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        mtx = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
        bmesh.ops.transform(self.bm, matrix=mtx, verts=verts)
        return self._finish(verts, m, bevel=bevel)

    def cyl(self, r, h, center=(0, 0, 0), m=None, rot=(0, 0, 0), seg=10, r2=None, smooth=True, cap=True):
        """Cylinder along local Z (rotate with `rot`)."""
        mtx = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4()
        geom = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r,
                                     radius2=r if r2 is None else r2, depth=h, matrix=mtx)
        return self._finish(geom["verts"], m, smooth=smooth)

    def sphere(self, r, center=(0, 0, 0), m=None, scale=(1, 1, 1), seg=10, rings=7, smooth=True, rot=(0, 0, 0)):
        mtx = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1.0))
        geom = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r, matrix=mtx)
        return self._finish(geom["verts"], m, smooth=smooth)

    def blob(self, r, center=(0, 0, 0), m=None, scale=(1, 1, 1), seed=0, rough=0.25, subdiv=1, smooth=False):
        """Irregular icosphere (foliage clumps, garbage bags)."""
        import random
        rnd = random.Random(seed)
        geom = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r)
        verts = geom["verts"]
        for v in verts:
            k = 1.0 + (rnd.random() - 0.5) * 2.0 * rough
            v.co *= k
        mtx = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((*scale, 1.0))
        bmesh.ops.transform(self.bm, matrix=mtx, verts=verts)
        return self._finish(verts, m, smooth=smooth)

    def poly_prism(self, pts2d, depth, m=None, center=(0, 0, 0), rot=(0, 0, 0)):
        """Extruded polygon: pts2d in local XZ plane, extruded along Y by depth (centred)."""
        mtx = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4()
        front = [self.bm.verts.new(mtx @ Vector((x, -depth / 2, z))) for x, z in pts2d]
        back = [self.bm.verts.new(mtx @ Vector((x, depth / 2, z))) for x, z in pts2d]
        n = len(pts2d)
        self.bm.faces.new(list(reversed(front)))
        self.bm.faces.new(back)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new([front[i], front[j], back[j], back[i]])
        return self._finish(front + back, m)

    def text(self, body, size, center=(0, 0, 0), m=None, depth=0.02, font="arialbd.ttf", rot=(math.pi / 2, 0, 0)):
        """Extruded text mesh (Cyrillic-capable system font), facing -Y by default."""
        cu = bpy.data.curves.new("rz_txt", type="FONT")
        cu.body = body
        cu.size = size
        cu.extrude = depth / 2
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        fpath = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", font)
        if os.path.exists(fpath):
            cu.font = bpy.data.fonts.load(fpath, check_existing=True)
        tob = bpy.data.objects.new("rz_txt", cu)
        scene().collection.objects.link(tob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
        tmp = bmesh.new()
        tmp.from_mesh(me)
        mtx = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=mtx, verts=tmp.verts)
        # Copy geometry by hand: bm.from_mesh() on a non-empty bmesh resets existing material indices.
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            try:
                self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                pass
        new_verts = list(vmap.values())
        tmp.free()
        bpy.data.objects.remove(tob, do_unlink=True)
        bpy.data.meshes.remove(me)
        bpy.data.curves.remove(cu)
        return self._finish(new_verts, m)


def build():
    sc = scene()
    for p in _parts:
        me = bpy.data.meshes.new(p.name)
        p.bm.normal_update()
        p.bm.to_mesh(me)
        p.bm.free()
        for m in p.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(p.name, me)
        sc.collection.objects.link(ob)
        if p.parent is not None:
            ob.parent = p.parent.ob
        ob.location = p.loc
        p.ob = ob
    return [p.ob for p in _parts]


def export(relpath):
    """Build parts and export the asset scene as GLB (+ a .blend source next to tools)."""
    objs = build()
    path = os.path.join(PROJECT, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc = scene()
    win = bpy.context.window_manager.windows[0]
    prev_scene = win.scene
    win.scene = sc
    try:
        with bpy.context.temp_override(window=win, scene=sc, view_layer=sc.view_layers[0]):
            bpy.ops.export_scene.gltf(
                filepath=path, export_format="GLB", use_active_scene=True, use_selection=False,
                export_apply=True, export_yup=True, export_cameras=False, export_lights=False,
                export_animations=False, export_materials="EXPORT", export_extras=False,
            )
    finally:
        win.scene = prev_scene
    src_dir = os.path.join(PROJECT, "tools", "blender", "source")
    os.makedirs(src_dir, exist_ok=True)
    blend = os.path.join(src_dir, os.path.splitext(os.path.basename(relpath))[0] + ".blend")
    bpy.data.libraries.write(blend, set(objs), fake_user=True, compress=True)
    tris = 0
    for ob in objs:
        tris += sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
    return {"file": relpath, "objects": len(objs), "tris": tris}
