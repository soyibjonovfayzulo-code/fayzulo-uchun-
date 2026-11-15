"""Environment / furniture / vehicle props. Run: bmcp.py assets_props.py [name ...] (no names = all).

Animated sub-parts for containers are separate nodes named anim_door_L / anim_door_R (rotate about
their origin = hinge) and anim_drawer_N (slide toward the front). Material names drive Godot shaders:
RZ_Leaves*, RZ_Glass*, RZ_Lamp*, RZ_Screen, RZ_Carpet*, RZ_CarBody.
"""
import importlib
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import rzlib  # noqa: E402

importlib.reload(rzlib)
from rzlib import Part, mat  # noqa: E402

PI = math.pi
H = PI / 2

# --- palette -------------------------------------------------------------------------------
def M():
    return dict(
        concrete=mat("concrete", "#8c8a84"), concrete_d=mat("concrete_dark", "#6e6c67"),
        rust=mat("rust", "#7a4a32"), metal=mat("metal", "#6f7273", rough=0.6, metal=0.3),
        metal_d=mat("metal_dark", "#3e4042", rough=0.6, metal=0.3), chrome=mat("chrome", "#a8aaa8", rough=0.35, metal=0.6),
        green=mat("paint_green", "#4f6b4a"), green_d=mat("paint_green_dark", "#3d5239"),
        blue=mat("paint_blue", "#4a6278"), red=mat("paint_red", "#8a3a30"), yellow=mat("paint_yellow", "#b89a3a"),
        wood=mat("wood", "#6b4e35"), wood_d=mat("wood_dark", "#4a3526"), polish=mat("wood_polished", "#5a3824", rough=0.5),
        wood_l=mat("wood_light", "#9a7a56"), white=mat("enamel", "#d8d4c8", rough=0.5), white_d=mat("enamel_dirty", "#bdb6a4", rough=0.6),
        black=mat("black", "#222222"), rubber=mat("rubber", "#1e1e1e", rough=1.0), fabric=mat("fabric_brown", "#6a4a3a"),
        fabric_g=mat("fabric_green", "#4e5a44"), glass=mat("Glass", "#3a4a55", rough=0.1, alpha=0.5),
        glass_l=mat("GlassLight", "#8fa4ad", rough=0.1, alpha=0.35), lamp=mat("Lamp", "#f0e0b0", emit=2.0),
        brick=mat("brick_white", "#c8c0b0"), orange=mat("paint_orange", "#b0603a"), cream=mat("paint_cream", "#cfc4a0"),
    )


def fridge(m):
    body = Part("Fridge")
    body.box((0.6, 0.6, 0.12), (0, 0, 0.06), m["metal_d"])
    body.box((0.6, 0.58, 1.38), (0, 0.01, 0.81), m["white"], bevel=0.04)
    body.cyl(0.29, 0.58, (0, 0.01, 1.5), m["white"], rot=(H, 0, 0), seg=12)  # rounded top (ZIL style)
    door = Part("anim_door_R", body, (-0.3, -0.29, 0.13))   # hinge on the right edge (viewer's left)
    door.box((0.6, 0.04, 1.36), (0.3, -0.02, 0.68), m["white"], bevel=0.02)
    door.box((0.04, 0.05, 0.28), (0.53, -0.06, 0.95), m["chrome"], bevel=0.01)
    door.box((0.3, 0.012, 0.05), (0.3, -0.042, 1.25), m["chrome"])


def stove(m):
    b = Part("Stove")
    b.box((0.5, 0.56, 0.85), (0, 0, 0.425), m["white"], bevel=0.015)
    b.box((0.5, 0.56, 0.02), (0, 0, 0.86), m["white_d"])
    for x, y in ((-0.12, -0.12), (0.12, -0.12), (-0.12, 0.12), (0.12, 0.12)):
        b.cyl(0.075, 0.02, (x, y, 0.875), m["black"], seg=10)
        b.cyl(0.035, 0.03, (x, y, 0.89), m["metal_d"], seg=8)
    b.box((0.4, 0.02, 0.36), (0, -0.285, 0.38), m["white_d"], bevel=0.01)
    b.box((0.36, 0.022, 0.18), (0, -0.29, 0.42), m["glass"])
    b.box((0.3, 0.03, 0.025), (0, -0.305, 0.6), m["chrome"])
    for i in range(4):
        b.cyl(0.018, 0.03, (-0.15 + i * 0.1, -0.29, 0.76), m["black"], rot=(H, 0, 0), seg=8)
    b.box((0.5, 0.04, 0.5), (0, 0.27, 1.12), m["white_d"])  # back splash panel


def kitchen_cabinet(m, sink=False):
    b = Part("KitchenSink" if sink else "KitchenCabinet")
    b.box((0.6, 0.58, 0.08), (0, 0.01, 0.04), m["black"])
    b.box((0.6, 0.56, 0.78), (0, 0.02, 0.47), m["cream"], bevel=0.01)
    b.box((0.62, 0.62, 0.04), (0, 0, 0.88), m["wood_l"])
    if sink:
        b.box((0.46, 0.4, 0.03), (0, 0.0, 0.905), m["chrome"])
        b.box((0.38, 0.32, 0.02), (0, 0.0, 0.92), m["metal_d"])
        b.cyl(0.015, 0.25, (0, 0.24, 1.0), m["chrome"], seg=6)
        b.cyl(0.012, 0.15, (0, 0.17, 1.12), m["chrome"], rot=(H, 0, 0), seg=6)
    door = Part("anim_door_L", b, (0.29, -0.27, 0.1))
    door.box((0.57, 0.025, 0.72), (-0.285, -0.012, 0.36), m["cream"], bevel=0.008)
    door.box((0.12, 0.02, 0.02), (-0.47, -0.035, 0.62), m["chrome"])


def wall_cabinet(m):
    b = Part("WallCabinet")
    b.box((0.6, 0.32, 0.62), (0, 0.0, 0.31), m["cream"], bevel=0.01)
    door = Part("anim_door_L", b, (0.29, -0.165, 0.02))
    door.box((0.57, 0.02, 0.58), (-0.285, -0.01, 0.29), m["cream"], bevel=0.006)
    door.box((0.02, 0.02, 0.1), (-0.52, -0.03, 0.12), m["chrome"])


def kitchen_table(m):
    b = Part("KitchenTable")
    b.box((0.92, 0.62, 0.03), (0, 0, 0.74), mat("oilcloth", "#a88a6a"))
    b.box((0.94, 0.64, 0.02), (0, 0, 0.725), mat("oilcloth_edge", "#8a6a50"))
    for x in (-0.42, 0.42):
        for y in (-0.27, 0.27):
            b.box((0.04, 0.04, 0.72), (x, y, 0.36), m["wood_d"])
    b.box((0.84, 0.02, 0.08), (0, -0.28, 0.67), m["wood_d"])
    b.cyl(0.05, 0.1, (0.2, 0.05, 0.8), m["white"], seg=8)  # kettle-ish mug
    b.cyl(0.11, 0.015, (-0.15, -0.05, 0.765), m["white_d"], seg=12)  # plate


def stool(m):
    b = Part("Stool")
    b.box((0.34, 0.34, 0.035), (0, 0, 0.46), m["wood_l"], bevel=0.008)
    for x in (-0.13, 0.13):
        for y in (-0.13, 0.13):
            b.box((0.035, 0.035, 0.45), (x, y, 0.225), m["wood"])
    b.box((0.26, 0.02, 0.03), (0, -0.13, 0.15), m["wood"])
    b.box((0.26, 0.02, 0.03), (0, 0.13, 0.15), m["wood"])


def chair(m):
    b = Part("Chair")
    b.box((0.42, 0.42, 0.05), (0, 0, 0.46), m["fabric"], bevel=0.01)
    for x in (-0.18, 0.18):
        for y in (-0.18, 0.18):
            b.box((0.035, 0.035, 0.45), (x, y, 0.225), m["wood_d"])
        b.box((0.035, 0.035, 0.48), (x, 0.19, 0.72), m["wood_d"])
    b.box((0.4, 0.03, 0.2), (0, 0.19, 0.83), m["wood_d"], bevel=0.008)


def bed(m):
    b = Part("Bed")
    b.box((0.94, 2.02, 0.22), (0, 0, 0.24), m["wood"], bevel=0.01)
    for y in (-0.98, 0.98):
        for x in (-0.44, 0.44):
            b.box((0.05, 0.05, 0.14), (x, y, 0.07), m["wood_d"])
    b.box((0.98, 0.05, 0.8), (0, 1.0, 0.4), m["polish"], bevel=0.01)
    b.box((0.98, 0.05, 0.5), (0, -1.0, 0.25), m["polish"], bevel=0.01)
    b.box((0.88, 1.92, 0.14), (0, 0.0, 0.42), mat("mattress", "#bdb3a0"), bevel=0.03)
    b.box((0.92, 1.4, 0.06), (0, -0.25, 0.5), mat("blanket", "#7a4a40"), bevel=0.02)
    b.box((0.94, 0.05, 0.26), (0, -0.96, 0.4), mat("blanket", "#7a4a40"))
    b.box((0.6, 0.38, 0.1), (0, 0.7, 0.53), mat("pillow", "#d8d0c0"), bevel=0.04)


def sofa(m):
    b = Part("Sofa")
    f = mat("fabric_sofa", "#6b5440")
    b.box((1.9, 0.82, 0.1), (0, 0, 0.12), m["wood_d"])
    b.box((1.7, 0.7, 0.22), (0, -0.04, 0.28), f, bevel=0.04)
    b.box((1.7, 0.22, 0.5), (0, 0.29, 0.6), f, bevel=0.05)
    for x in (-0.9, 0.9):
        b.box((0.12, 0.82, 0.32), (x, 0, 0.36), m["polish"], bevel=0.02)
    for x in (-0.85, 0.85):
        b.box((0.05, 0.05, 0.08), (x, -0.36, 0.04), m["wood_d"])


def wardrobe(m):
    b = Part("Wardrobe")
    b.box((1.0, 0.55, 1.9), (0, 0, 0.97), m["polish"], bevel=0.01)
    b.box((1.02, 0.57, 0.05), (0, 0, 1.94), m["wood_d"])
    b.box((0.98, 0.53, 0.06), (0, 0, 0.03), m["wood_d"])
    for side, sx in (("L", 1.0), ("R", -1.0)):
        d = Part("anim_door_" + side, b, (0.49 * sx, -0.28, 0.08))
        d.box((0.48, 0.025, 1.8), (-0.24 * sx, -0.012, 0.9), m["polish"], bevel=0.006)
        d.box((0.02, 0.02, 0.14), (-0.45 * sx, -0.035, 0.95), m["chrome"])


def stenka(m):
    """Soviet wall unit: glass cabinets with crockery, closed cupboards."""
    b = Part("Stenka")
    p = m["polish"]
    b.box((2.4, 0.45, 2.0), (0, 0.0, 1.0), p, bevel=0.01)
    b.box((2.42, 0.47, 0.05), (0, 0, 2.02), m["wood_d"])
    b.box((0.75, 0.02, 0.9), (0, -0.226, 1.35), m["glass_l"])
    b.box((0.72, 0.38, 0.02), (0, -0.0, 1.3), m["wood_l"])
    for i in range(5):
        b.cyl(0.04, 0.12, (-0.28 + i * 0.14, -0.05, 1.37), m["white"], seg=8)
        b.cyl(0.03, 0.1, (-0.28 + i * 0.14, -0.05, 0.95 + 0.06), mat("crystal", "#a0b0b8", rough=0.2))
    b.box((0.7, 0.02, 0.02), (0, -0.226, 0.9), m["wood_d"])
    for i, x in enumerate((-0.8, 0.8)):
        side = "L" if x > 0 else "R"
        sx = 1.0 if x > 0 else -1.0
        d = Part("anim_door_" + side, b, (x + 0.39 * sx, -0.23, 0.05))
        d.box((0.76, 0.025, 1.85), (-0.38 * sx, -0.012, 0.93), p, bevel=0.006)
        d.box((0.02, 0.02, 0.14), (-0.7 * sx, -0.035, 0.95), m["chrome"])
    d = Part("anim_drawer_1", b, (0, -0.23, 0.45))
    d.box((0.74, 0.025, 0.4), (0, -0.012, 0.0), p, bevel=0.006)
    d.box((0.14, 0.02, 0.02), (0, -0.035, 0.05), m["chrome"])


def dresser(m):
    b = Part("Dresser")
    b.box((0.9, 0.45, 0.85), (0, 0, 0.45), m["polish"], bevel=0.01)
    b.box((0.92, 0.47, 0.03), (0, 0, 0.89), m["wood_d"])
    for i in range(3):
        d = Part("anim_drawer_%d" % (i + 1), b, (0, -0.225, 0.2 + i * 0.26))
        d.box((0.84, 0.025, 0.23), (0, -0.012, 0.0), m["polish"], bevel=0.006)
        d.box((0.16, 0.02, 0.025), (0, -0.035, 0.03), m["chrome"])
    b.box((0.4, 0.02, 0.55), (0, 0.18, 1.2), m["glass_l"])  # mirror


def tv(m):
    b = Part("TV")
    b.box((0.6, 0.42, 0.04), (0, 0, 0.5), m["wood_d"])
    for x in (-0.25, 0.25):
        for y in (-0.16, 0.16):
            b.cyl(0.015, 0.5, (x, y, 0.25), m["metal_d"], seg=6)
    b.box((0.56, 0.44, 0.46), (0, 0.02, 0.76), m["polish"], bevel=0.02)
    b.box((0.4, 0.02, 0.32), (-0.05, -0.205, 0.78), mat("Screen", "#2a302c", rough=0.3))
    b.box((0.08, 0.02, 0.32), (0.23, -0.205, 0.78), m["metal_d"])
    for i in range(3):
        b.cyl(0.012, 0.02, (0.23, -0.22, 0.88 - i * 0.07), m["chrome"], rot=(H, 0, 0), seg=6)
    b.box((0.2, 0.25, 0.08), (0, 0.15, 1.02), m["black"])  # antenna base
    b.cyl(0.006, 0.4, (-0.1, 0.15, 1.2), m["chrome"], rot=(0, -0.5, 0), seg=4)
    b.cyl(0.006, 0.4, (0.1, 0.15, 1.2), m["chrome"], rot=(0, 0.5, 0), seg=4)


def carpet_wall(m):
    b = Part("CarpetWall")
    b.box((2.0, 0.025, 1.4), (0, 0, 0.7), mat("Carpet", "#7a2e28"))


def carpet_floor(m):
    b = Part("CarpetFloor")
    b.box((2.0, 1.4, 0.012), (0, 0, 0.006), mat("CarpetFloor", "#6a3a2a"))


def bathtub(m):
    b = Part("Bathtub")
    b.box((1.5, 0.7, 0.56), (0, 0, 0.28), m["white"], bevel=0.05)
    b.box((1.36, 0.56, 0.1), (0, 0, 0.53), m["white_d"])
    b.cyl(0.012, 0.3, (0.68, 0.38, 0.85), m["chrome"], seg=6)
    b.cyl(0.03, 0.08, (0.68, 0.33, 1.0), m["chrome"], seg=6, rot=(H, 0, 0))


def toilet(m):
    b = Part("Toilet")
    b.box((0.36, 0.5, 0.38), (0, -0.05, 0.19), m["white"], bevel=0.06, taper=(1.1, 1.05))
    b.box((0.4, 0.46, 0.03), (0, -0.07, 0.41), m["white_d"], bevel=0.01)
    b.box((0.4, 0.18, 0.36), (0, 0.22, 0.6), m["white"], bevel=0.03)
    b.cyl(0.01, 0.6, (0.15, 0.28, 1.1), m["chrome"], seg=4)


def washbasin(m):
    b = Part("Washbasin")
    b.cyl(0.06, 0.65, (0, 0.05, 0.33), m["white"], seg=10)
    b.box((0.5, 0.4, 0.16), (0, 0.0, 0.75), m["white"], bevel=0.04)
    b.box((0.4, 0.3, 0.03), (0, -0.02, 0.83), m["white_d"])
    b.cyl(0.012, 0.15, (0, 0.17, 0.9), m["chrome"], seg=6)
    b.box((0.45, 0.02, 0.55), (0, 0.2, 1.35), m["glass_l"])
    b.box((0.47, 0.025, 0.57), (0, 0.21, 1.35), m["metal"])


def radiator(m):
    b = Part("Radiator")
    for i in range(10):
        b.box((0.07, 0.1, 0.5), (-0.33 + i * 0.075, 0, 0.42), mat("radiator", "#bdb6a8", rough=0.7), bevel=0.012)
    b.cyl(0.015, 0.8, (0, 0.03, 0.2), m["metal"], rot=(0, H, 0), seg=6)
    b.cyl(0.015, 0.8, (0, 0.03, 0.64), m["metal"], rot=(0, H, 0), seg=6)


def shop_shelf(m):
    b = Part("ShopShelf")
    met = mat("shelf_metal", "#7d8486", rough=0.6, metal=0.2)
    b.box((1.8, 0.04, 1.8), (0, 0.23, 0.9), met)
    for x in (-0.88, 0.88):
        b.box((0.04, 0.5, 1.8), (x, 0, 0.9), met)
    rnd = random.Random(7)
    goods = [mat("goods_%d" % i, c) for i, c in enumerate(("#a83a2a", "#c8a03a", "#3a6a8a", "#6a8a3a", "#d8d0b8", "#8a5a3a"))]
    for lvl in range(4):
        z = 0.12 + lvl * 0.45
        b.box((1.72, 0.48, 0.03), (0, 0, z), met)
        x = -0.8
        while x < 0.78:
            w = rnd.choice((0.08, 0.1, 0.12, 0.16))
            h = rnd.choice((0.12, 0.18, 0.22, 0.28))
            if rnd.random() < 0.8:
                if rnd.random() < 0.5:
                    b.cyl(w * 0.45, h, (x + w / 2, -0.05, z + 0.015 + h / 2), rnd.choice(goods), seg=8)
                else:
                    b.box((w * 0.9, 0.2, h), (x + w / 2, -0.05, z + 0.015 + h / 2), rnd.choice(goods))
            x += w + 0.02


def shop_counter(m):
    b = Part("ShopCounter")
    b.box((1.6, 0.7, 0.9), (0, 0, 0.45), m["cream"], bevel=0.01)
    b.box((1.64, 0.74, 0.04), (0, 0, 0.92), m["wood_l"])
    b.box((1.56, 0.6, 0.3), (0, 0, 1.09), m["glass_l"])
    b.box((0.4, 0.3, 0.22), (0.5, 0.15, 1.05), m["metal_d"])  # cash register
    b.box((0.36, 0.2, 0.06), (0.5, 0.1, 1.18), m["black"])
    b.box((0.35, 0.05, 0.12), (0.5, 0.28, 1.22), mat("register_display", "#3a5a3a", emit=0.3))


def drink_fridge(m):
    b = Part("DrinkFridge")
    b.box((0.7, 0.62, 1.95), (0, 0, 0.975), mat("fridge_red", "#9a3a30"), bevel=0.02)
    b.box((0.6, 0.02, 1.5), (0, -0.312, 0.95), m["glass_l"])
    bottles = [mat("bottle_%d" % i, c, rough=0.2) for i, c in enumerate(("#3a6a3a", "#8a6a2a", "#b85a2a", "#2a4a6a"))]
    for lvl in range(4):
        z = 0.3 + lvl * 0.37
        for i in range(6):
            b.cyl(0.035, 0.26, (-0.24 + i * 0.095, -0.15, z + 0.13), bottles[(i + lvl) % 4], seg=8)
    b.box((0.7, 0.05, 0.2), (0, -0.31, 1.82), mat("Lamp_white", "#d8e0e0", emit=0.6))
    d = Part("anim_door_R", b, (-0.33, -0.33, 0.1))
    d.box((0.66, 0.03, 1.6), (0.33, -0.015, 0.85), m["glass"])
    d.box((0.03, 0.04, 0.4), (0.6, -0.05, 0.9), m["chrome"])


def pharm_shelf(m):
    b = Part("PharmShelf")
    w = mat("pharm_white", "#d0d4d0", rough=0.6)
    b.box((1.6, 0.4, 2.0), (0, 0.04, 1.0), w, bevel=0.01)
    b.box((1.5, 0.02, 1.4), (0, -0.16, 1.15), m["glass_l"])
    rnd = random.Random(3)
    meds = [mat("med_%d" % i, c) for i, c in enumerate(("#e0e0d8", "#c84a3a", "#4a7ab0", "#d8c050", "#5aa070", "#e8a0a0"))]
    for lvl in range(4):
        z = 0.55 + lvl * 0.34
        x = -0.7
        while x < 0.68:
            ww = rnd.choice((0.06, 0.08, 0.1))
            hh = rnd.choice((0.08, 0.12, 0.16))
            b.box((ww, 0.14, hh), (x + ww / 2, 0.0, z + hh / 2), rnd.choice(meds))
            x += ww + 0.025
        b.box((1.5, 0.32, 0.02), (0, 0.04, z - 0.01), w)
    d = Part("anim_drawer_1", b, (0, -0.16, 0.25))
    d.box((1.5, 0.02, 0.36), (0, -0.01, 0.0), w)
    d.box((0.2, 0.02, 0.02), (0, -0.03, 0.08), m["chrome"])


def pharm_counter(m):
    b = Part("PharmCounter")
    w = mat("pharm_white", "#d0d4d0", rough=0.6)
    b.box((2.0, 0.6, 1.0), (0, 0, 0.5), w, bevel=0.01)
    b.box((2.04, 0.64, 0.04), (0, 0, 1.02), mat("pharm_green", "#3a7a5a"))
    b.box((2.0, 0.04, 0.9), (0, -0.0, 1.5), m["glass_l"])
    b.box((0.4, 0.06, 0.18), (0, -0.0, 1.13), m["metal"])  # pass-through window
    b.box((0.3, 0.25, 0.2), (0.6, 0.1, 1.14), m["metal_d"])


def crate_army(m):
    """Green army crate with rope handles and stencil band (test room supplies)."""
    b = Part("CrateArmy")
    g = mat("crate_green", "#4e5a3a")
    gd = mat("crate_green_dark", "#3a4430")
    b.box((1.1, 0.62, 0.5), (0, 0, 0.25), g, bevel=0.01)
    for x in (-0.53, 0.53):
        b.box((0.05, 0.64, 0.52), (x, 0, 0.26), gd)
    for z in (0.08, 0.42):
        b.box((1.12, 0.64, 0.05), (0, 0, z), gd)
    b.box((1.14, 0.66, 0.05), (0, 0, 0.53), gd, bevel=0.005)
    b.box((0.5, 0.01, 0.12), (0, -0.316, 0.27), mat("crate_stencil", "#c8c0a0"))
    for x in (-0.58, 0.58):
        b.box((0.03, 0.2, 0.05), (x, 0, 0.32), mat("rope", "#a89060"))
    for x in (-0.35, 0.35):
        b.box((0.06, 0.03, 0.04), (x, -0.33, 0.48), m["metal_d"])


def campfire(m):
    """Ring of stones, birch logs and embers (flames are particles + light in Godot)."""
    b = Part("Campfire")
    stone = mat("stone", "#7a7872")
    stone_d = mat("stone_dark", "#5a5854")
    for i in range(9):
        a = i * 2 * PI / 9
        b.sphere(0.09, (math.cos(a) * 0.36, math.sin(a) * 0.36, 0.05), stone if i % 2 else stone_d,
                 scale=(1.2, 0.9, 0.7), seg=7, rings=5, rot=(0, 0, a))
    b.cyl(0.3, 0.02, (0, 0, 0.01), mat("ash", "#3a3634"), seg=12)
    b.cyl(0.18, 0.025, (0, 0, 0.03), mat("Lamp_ember", "#c84a1a", emit=1.5), seg=10)
    bark = mat("birch_bark", "#d8d4c8")
    char = mat("charcoal", "#1e1c1a")
    for i in range(5):
        a = i * 2 * PI / 5 + 0.3
        b.cyl(0.035, 0.42, (math.cos(a) * 0.08, math.sin(a) * 0.08, 0.12), bark if i % 2 else char,
              rot=(0.0, 1.05, a), seg=7)


def toolbox(m):
    b = Part("Toolbox")
    r = mat("toolbox_red", "#9a3a2a", rough=0.5, metal=0.4)
    b.box((0.45, 0.22, 0.2), (0, 0, 0.1), r, bevel=0.01)
    b.box((0.46, 0.225, 0.03), (0, 0, 0.2), mat("toolbox_lid", "#7a2a20", metal=0.4))
    b.box((0.2, 0.03, 0.04), (0, 0, 0.24), m["metal_d"])
    b.box((0.04, 0.23, 0.04), (0.18, 0, 0.12), m["chrome"])


def mailboxes(m):
    b = Part("Mailboxes")
    bl = mat("mailbox_blue", "#4a5e74", rough=0.7, metal=0.2)
    b.box((1.2, 0.2, 0.72), (0, 0, 0.36), bl, bevel=0.01)
    for r in range(3):
        for c in range(4):
            x, z = -0.45 + c * 0.3, 0.12 + r * 0.24
            b.box((0.26, 0.02, 0.2), (x, -0.105, z), mat("mailbox_door", "#5a6e84"))
            b.box((0.14, 0.022, 0.015), (x, -0.11, z + 0.06), m["black"])
            b.box((0.03, 0.025, 0.03), (x + 0.09, -0.115, z - 0.04), m["chrome"])


def intercom(m):
    b = Part("Intercom")
    b.box((0.14, 0.04, 0.26), (0, 0, 0.13), m["metal"], bevel=0.01)
    for r in range(4):
        for c in range(3):
            b.box((0.025, 0.012, 0.022), (-0.035 + c * 0.035, -0.024, 0.06 + r * 0.035), m["metal_d"])
    b.cyl(0.02, 0.012, (0, -0.024, 0.22), m["black"], rot=(H, 0, 0), seg=8)


def door_wood(m):
    """Interior door 0.8 x 2.0; node origin at the hinge (left edge seen from -Y)."""
    b = Part("anim_door_L")
    c = mat("door_paint", "#cfc6ae", rough=0.6)
    b.box((0.8, 0.04, 2.0), (-0.4, 0, 1.0), c, bevel=0.008)
    b.box((0.6, 0.046, 0.7), (-0.4, 0, 1.45), mat("door_panel", "#c2b89e", rough=0.6))
    b.box((0.6, 0.046, 0.7), (-0.4, 0, 0.55), mat("door_panel", "#c2b89e", rough=0.6))
    b.box((0.11, 0.07, 0.025), (-0.7, 0, 1.0), m["chrome"])


def door_metal(m):
    """Entrance (podъезд) metal door 1.0 x 2.05, painted brown with code lock."""
    b = Part("anim_door_L")
    c = mat("door_metal_paint", "#5a3a2a", rough=0.6, metal=0.3)
    b.box((1.0, 0.06, 2.05), (-0.5, 0, 1.025), c, bevel=0.01)
    for z in (0.3, 1.0, 1.75):
        b.box((0.9, 0.065, 0.03), (-0.5, 0, z), mat("door_metal_rib", "#4a2e22", metal=0.3))
    b.box((0.2, 0.09, 0.03), (-0.85, 0, 1.0), m["metal_d"])
    b.box((0.1, 0.075, 0.18), (-0.85, 0, 1.2), m["metal"])


def door_apartment(m):
    """Apartment entrance door 0.9 x 2.05, leatherette padded."""
    b = Part("anim_door_L")
    c = mat("door_leather", "#4a2e26", rough=0.8)
    b.box((0.9, 0.06, 2.05), (-0.45, 0, 1.025), c, bevel=0.01)
    for x in (-0.2, -0.45, -0.7):
        for z in (0.4, 0.9, 1.4, 1.8):
            b.cyl(0.012, 0.07, (x, 0, z), m["chrome"], rot=(H, 0, 0), seg=6)
    b.box((0.12, 0.08, 0.025), (-0.78, 0, 1.0), m["chrome"])
    b.cyl(0.012, 0.075, (-0.45, 0, 1.55), m["black"], rot=(H, 0, 0), seg=6)  # peephole


def door_glass(m):
    """Shop door 1.0 x 2.1 aluminium frame with glass."""
    b = Part("anim_door_L")
    al = mat("aluminium", "#8a8e8e", rough=0.4, metal=0.5)
    b.box((1.0, 0.05, 0.08), (-0.5, 0, 0.04), al)
    b.box((1.0, 0.05, 0.08), (-0.5, 0, 2.06), al)
    b.box((0.07, 0.05, 2.1), (-0.035, 0, 1.05), al)
    b.box((0.07, 0.05, 2.1), (-0.965, 0, 1.05), al)
    b.box((0.86, 0.02, 1.98), (-0.5, 0, 1.05), m["glass_l"])
    b.box((0.04, 0.08, 0.3), (-0.88, 0, 1.05), m["chrome"])


def door_balcony(m):
    b = Part("anim_door_L")
    w = mat("window_paint", "#d8d2c0", rough=0.6)
    b.box((0.75, 0.05, 2.05), (-0.375, 0, 1.025), w)
    b.box((0.55, 0.055, 1.1), (-0.375, 0, 1.4), m["glass_l"])
    b.box((0.04, 0.07, 0.12), (-0.68, 0, 1.0), m["chrome"])


def bench(m):
    b = Part("Bench")
    slat = mat("bench_slat", "#5d7350")
    for x in (-0.75, 0.75):
        b.box((0.08, 0.5, 0.42), (x, 0.0, 0.21), m["concrete"], bevel=0.01)
        b.box((0.06, 0.06, 0.45), (x, 0.24, 0.62), m["metal_d"], rot=(-0.2, 0, 0))
    for i in range(4):
        b.box((1.8, 0.085, 0.035), (0, -0.18 + i * 0.11, 0.44), slat, bevel=0.006)
    for i in range(3):
        b.box((1.8, 0.035, 0.09), (0, 0.27 + i * 0.012, 0.58 + i * 0.12), slat, bevel=0.006)


def dumpster(m):
    b = Part("Dumpster")
    g = mat("dumpster_green", "#4c5e44", rough=0.7, metal=0.2)
    b.box((1.3, 0.95, 1.0), (0, 0, 0.62), g, taper=(1.1, 1.12), bevel=0.02)
    b.box((1.46, 1.08, 0.05), (0, 0, 1.12), m["metal_d"])
    b.box((1.2, 0.08, 0.05), (0, -0.52, 0.5), m["rust"])
    for x in (-0.55, 0.55):
        for y in (-0.38, 0.38):
            b.cyl(0.06, 0.05, (x, y, 0.06), m["rubber"], rot=(0, H, 0), seg=8)
            b.box((0.04, 0.06, 0.08), (x, y, 0.13), m["metal_d"])
    b.blob(0.3, (0.3, 0.1, 1.2), mat("trashbag", "#1e2022", rough=0.4), scale=(1, 0.9, 0.6), seed=1)
    b.blob(0.25, (-0.25, -0.1, 1.18), mat("trashbag", "#1e2022", rough=0.4), scale=(1, 1, 0.6), seed=2)
    lid = Part("Lid", b, (0, 0.52, 1.15))
    lid.box((1.44, 1.06, 0.04), (0, -0.52, 0.02), g, rot=(0.0, 0, 0))


def trash_bag(m):
    b = Part("TrashBag")
    b.blob(0.28, (0, 0, 0.22), mat("trashbag", "#1e2022", rough=0.4), scale=(1, 0.9, 0.8), seed=4)
    b.cyl(0.04, 0.12, (0, 0, 0.48), mat("trashbag", "#1e2022", rough=0.4), seg=6)


def cardboard(m):
    b = Part("Cardboard")
    c = mat("cardboard", "#9a7a50")
    b.box((0.5, 0.4, 0.35), (0, 0, 0.175), c, bevel=0.005)
    b.box((0.5, 0.15, 0.01), (0, -0.25, 0.35), c, rot=(-0.6, 0, 0))
    b.box((0.4, 0.3, 0.28), (0.15, 0.05, 0.49), c, rot=(0, 0, 0.3), bevel=0.005)


def urn(m):
    b = Part("Urn")
    b.cyl(0.22, 0.5, (0, 0, 0.25), m["concrete"], r2=0.26, seg=10)
    b.cyl(0.21, 0.05, (0, 0, 0.48), mat("trashbag", "#1e2022", rough=0.4), seg=10)


def tire(m):
    b = Part("Tire")
    b.cyl(0.32, 0.2, (0, 0, 0.1), m["rubber"], seg=14)
    b.cyl(0.18, 0.21, (0, 0, 0.1), m["metal_d"], seg=10)


def car(m, key="sedan", color="#b8ab8a", wreck=False):
    body = mat("CarBody", color, rough=0.55, metal=0.2)
    b = Part("Car")
    trim = mat("car_trim", "#2a2a2a")
    b.box((1.62, 4.1, 0.5), (0, 0, 0.58), body, bevel=0.04)          # lower body (car length along Y)
    b.box((1.6, 1.05, 0.12), (0, -1.5, 0.86), body, bevel=0.02)      # bonnet
    b.box((1.6, 0.85, 0.1), (0, 1.62, 0.86), body, bevel=0.02)       # boot
    b.box((1.42, 2.0, 0.5), (0, 0.1, 1.08), body, bevel=0.03, taper=(0.97, 0.8))  # cabin
    gl = m["glass"] if not wreck else mat("Glass_broken", "#2a3238", alpha=0.7)
    b.box((1.24, 0.03, 0.42), (0, -0.83, 1.09), gl, rot=(-0.38, 0, 0))   # windscreen
    b.box((1.24, 0.03, 0.4), (0, 1.03, 1.09), gl, rot=(0.38, 0, 0))
    for sx in (-1, 1):
        b.box((0.02, 0.8, 0.32), (sx * 0.708, -0.3, 1.09), gl)
        b.box((0.02, 0.72, 0.32), (sx * 0.708, 0.56, 1.09), gl)
        b.box((0.03, 0.06, 0.4), (sx * 0.71, 0.13, 1.09), trim)
        b.box((0.025, 4.0, 0.06), (sx * 0.815, 0, 0.62), mat("chrome", "#a8aaa8", rough=0.35, metal=0.6))
    for y in (-2.06, 2.06):
        b.box((1.66, 0.08, 0.12), (0, y, 0.42), m["chrome"], bevel=0.02)
    for sx in (-0.55, 0.55):
        b.cyl(0.085, 0.04, (sx, -2.05, 0.66), mat("Lamp_head", "#d8d4c0", emit=0.0), rot=(H, 0, 0), seg=10)
        b.box((0.22, 0.04, 0.1), (sx, 2.05, 0.68), mat("taillight", "#8a2a22"))
    b.box((0.6, 0.03, 0.14), (0, -2.06, 0.66), trim)                # grille
    b.box((0.5, 0.03, 0.12), (0, 2.07, 0.5), mat("plate", "#d8d8d0"))
    for x in (-0.72, 0.72):
        for y in (-1.3, 1.3):
            flat = 0.06 if (wreck and x > 0 and y < 0) else 0.0
            b.cyl(0.3, 0.18, (x, y, 0.3 - flat), m["rubber"], rot=(0, H, 0), seg=14)
            b.cyl(0.16, 0.19, (x, y, 0.3 - flat), m["metal"], rot=(0, H, 0), seg=10)
    b.box((1.5, 3.9, 0.12), (0, 0, 0.3), trim)
    if wreck:
        rust = m["rust"]
        b.box((0.5, 0.6, 0.02), (0.3, -1.4, 0.93), rust)
        b.box((0.02, 0.6, 0.25), (0.81, 0.6, 0.6), rust)


def swing(m):
    b = Part("Swing")
    p = mat("pipe_blue", "#4a6a8a", rough=0.6, metal=0.3)
    for x in (-1.1, 1.1):
        b.cyl(0.04, 2.3, (x, -0.45, 1.1), p, rot=(-0.38, 0, 0), seg=8)
        b.cyl(0.04, 2.3, (x, 0.45, 1.1), p, rot=(0.38, 0, 0), seg=8)
    b.cyl(0.045, 2.3, (0, 0, 2.15), p, rot=(0, H, 0), seg=8)
    for x in (-0.25, 0.25):
        b.cyl(0.012, 1.6, (x, 0, 1.35), m["metal_d"], seg=4)
    b.box((0.6, 0.24, 0.04), (0, 0, 0.55), m["wood"], bevel=0.008)


def slide(m):
    b = Part("Slide")
    p = mat("pipe_red", "#8a4a3a", rough=0.6, metal=0.3)
    b.box((0.6, 0.6, 0.05), (0, 0.9, 1.4), m["wood"])
    for x in (-0.3, 0.3):
        for y in (0.6, 1.2):
            b.cyl(0.035, 1.4, (x, y, 0.7), p, seg=6)
        b.cyl(0.03, 1.0, (x, 0.9, 1.9), p, seg=6)
    for i in range(6):
        b.cyl(0.02, 0.6, (0, 1.2 + 0.05, 0.2 + i * 0.22), m["metal"], rot=(0, H, 0), seg=6)
    b.box((0.55, 2.2, 0.03), (0, -0.35, 0.72), mat("slide_steel", "#9a9c9a", rough=0.3, metal=0.6), rot=(-0.62, 0, 0))
    for x in (-0.29, 0.29):
        b.box((0.03, 2.2, 0.12), (x, -0.35, 0.78), p, rot=(-0.62, 0, 0))


def carousel(m):
    b = Part("Carousel")
    p = mat("pipe_yellow", "#b89a3a", rough=0.6, metal=0.3)
    b.cyl(0.95, 0.06, (0, 0, 0.35), mat("carousel_deck", "#6a4a3a"), seg=16, smooth=False)
    b.cyl(0.06, 0.4, (0, 0, 0.15), m["metal_d"], seg=8)
    b.cyl(0.04, 0.6, (0, 0, 0.7), p, seg=8)
    for i in range(4):
        a = i * H
        x, y = math.cos(a) * 0.45, math.sin(a) * 0.45
        b.cyl(0.025, 0.95, (x * 0.5, y * 0.5, 0.95), p, rot=(0, H, a), seg=6)
        b.cyl(0.025, 0.55, (x * 1.0, y * 1.0, 0.65), p, seg=6)


def sandbox(m):
    b = Part("Sandbox")
    b.box((2.0, 2.0, 0.08), (0, 0, 0.04), mat("sand", "#b0a078", rough=1.0))
    for (x, y, w, d) in ((0, -1.0, 2.1, 0.1), (0, 1.0, 2.1, 0.1), (-1.0, 0, 0.1, 2.1), (1.0, 0, 0.1, 2.1)):
        b.box((w, d, 0.3), (x, y, 0.15), m["wood"], bevel=0.01)
    b.cyl(0.05, 1.6, (0, 0, 0.8), m["wood_d"], seg=8)
    b.cyl(0.9, 0.35, (0, 0, 1.75), mat("mushroom_red", "#8a3a2a"), r2=0.05, seg=12, smooth=False)


def horizontal_bar(m):
    b = Part("HorizontalBar")
    p = mat("pipe_green", "#4f6b4a", rough=0.6, metal=0.3)
    for x in (-0.8, 0.8):
        b.cyl(0.04, 2.2, (x, 0, 1.1), p, seg=8)
    b.cyl(0.02, 1.6, (0, 0, 2.1), m["metal"], rot=(0, H, 0), seg=6)
    b.cyl(0.02, 1.6, (0, 0, 1.4), m["metal"], rot=(0, H, 0), seg=6)


def birch(m, seed=1):
    rnd = random.Random(seed)
    b = Part("Tree")
    bark = mat("birch_bark", "#d0cbbd")
    dark = mat("birch_mark", "#2a2622")
    h = 7.5 + rnd.random() * 2
    b.cyl(0.13, h * 0.75, (0, 0, h * 0.375), bark, r2=0.07, seg=8)
    for i in range(9):
        z = 0.4 + i * h * 0.075
        b.box((0.06 + rnd.random() * 0.06, 0.02, 0.05), (rnd.uniform(-0.05, 0.05), -0.11, z), dark)
        b.box((0.02, 0.06, 0.05), (0.11, rnd.uniform(-0.05, 0.05), z + 0.2), dark)
    for i in range(4):
        a = rnd.random() * 2 * PI
        b.cyl(0.04, 1.6, (math.cos(a) * 0.5, math.sin(a) * 0.5, h * 0.55 + i * 0.6), bark,
              rot=(math.sin(a) * 0.9, -math.cos(a) * 0.9, 0), seg=5)
    leaves = [mat("Leaves_birch", "#6f7d44"), mat("Leaves_birch2", "#8a8a4a")]
    for i in range(11):
        a = rnd.random() * 2 * PI
        r = rnd.uniform(0.3, 1.6)
        b.blob(rnd.uniform(0.9, 1.4), (math.cos(a) * r, math.sin(a) * r, h * 0.62 + rnd.uniform(0, h * 0.4)),
               rnd.choice(leaves), scale=(1, 1, 1.2), seed=seed * 31 + i, rough=0.22, subdiv=2, smooth=True)


def poplar(m, seed=2):
    rnd = random.Random(seed)
    b = Part("Tree")
    bark = mat("bark", "#5a5048")
    h = 11 + rnd.random() * 2
    b.cyl(0.25, h * 0.6, (0, 0, h * 0.3), bark, r2=0.12, seg=8)
    leaves = [mat("Leaves_poplar", "#56603a"), mat("Leaves_poplar2", "#646c40")]
    for i in range(13):
        a = rnd.random() * 2 * PI
        z = h * 0.35 + rnd.random() * h * 0.6
        r = rnd.uniform(0.2, 1.3) * (1.0 - (z / h - 0.35) * 0.5)
        b.blob(rnd.uniform(0.9, 1.3), (math.cos(a) * r, math.sin(a) * r, z), rnd.choice(leaves),
               scale=(1, 1, 1.4), seed=seed * 17 + i, rough=0.22, subdiv=2, smooth=True)


def dead_tree(m, seed=5):
    rnd = random.Random(seed)
    b = Part("Tree")
    bark = mat("bark_dry", "#4e463e")
    b.cyl(0.18, 5.0, (0, 0, 2.5), bark, r2=0.08, seg=7)
    for i in range(6):
        a = rnd.random() * 2 * PI
        z = 2.4 + i * 0.45
        b.cyl(0.05, 2.0, (math.cos(a) * 0.6, math.sin(a) * 0.6, z + 0.5), bark,
              rot=(math.sin(a) * 1.0, -math.cos(a) * 1.0, 0), seg=5, r2=0.02)


def bush(m, seed=3):
    rnd = random.Random(seed)
    b = Part("Bush")
    leaves = [mat("Leaves_bush", "#4e5c36"), mat("Leaves_bush2", "#5e6a3c")]
    for i in range(6):
        b.blob(rnd.uniform(0.45, 0.65), (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.4, 0.4), 0.5 + rnd.uniform(0, 0.3)),
               rnd.choice(leaves), scale=(1, 1, 0.85), seed=seed * 13 + i, rough=0.25, subdiv=2, smooth=True)


def streetlight(m):
    b = Part("Streetlight")
    b.cyl(0.13, 7.5, (0, 0, 3.75), m["concrete"], r2=0.08, seg=8)
    b.cyl(0.04, 1.6, (0, -0.7, 7.4), m["metal_d"], rot=(H - 0.2, 0, 0), seg=6)
    b.box((0.3, 0.55, 0.14), (0, -1.45, 7.55), m["metal_d"], bevel=0.03)
    b.box((0.24, 0.45, 0.04), (0, -1.45, 7.47), mat("Lamp_street", "#f0d8a0", emit=0.0))


def road_sign(m, kind="bus"):
    b = Part("RoadSign")
    b.cyl(0.035, 2.6, (0, 0, 1.3), mat("pole_stripe", "#c8c8c0", metal=0.2), seg=6)
    blue = mat("sign_blue", "#2a5a9a", rough=0.6)
    white = mat("sign_white", "#e0e0d8", rough=0.6)
    red = mat("sign_red", "#b03028", rough=0.6)
    if kind in ("bus", "crossing"):
        b.box((0.6, 0.03, 0.6), (0, -0.05, 2.35), blue, bevel=0.01)
        if kind == "bus":
            b.box((0.36, 0.035, 0.2), (0, -0.06, 2.38), white)
            b.box((0.3, 0.036, 0.06), (0, -0.065, 2.42), blue)
            for x in (-0.1, 0.1):
                b.cyl(0.035, 0.037, (x, -0.06, 2.26), white, rot=(H, 0, 0), seg=8)
        else:
            b.poly_prism([(-0.25, -0.2), (0.25, -0.2), (0.0, 0.24)], 0.035, white, center=(0, -0.06, 2.33))
            b.box((0.06, 0.037, 0.18), (0.0, -0.065, 2.3), mat("sign_black", "#1a1a1a"))
            b.cyl(0.03, 0.037, (0.0, -0.065, 2.42), mat("sign_black", "#1a1a1a"), rot=(H, 0, 0), seg=8)
    elif kind == "giveway":
        b.poly_prism([(-0.4, 0.4), (0.4, 0.4), (0.0, -0.3)], 0.03, red, center=(0, -0.05, 2.15))
        b.poly_prism([(-0.28, 0.33), (0.28, 0.33), (0.0, -0.16)], 0.035, white, center=(0, -0.06, 2.15))
    elif kind == "stop":
        pts = [(math.cos(i * PI / 4 + PI / 8) * 0.33, math.sin(i * PI / 4 + PI / 8) * 0.33) for i in range(8)]
        b.poly_prism(pts, 0.03, red, center=(0, -0.05, 2.3))
        b.text("STOP", 0.16, (0, -0.075, 2.3), white, depth=0.01)


def bus_stop(m):
    b = Part("BusStop")
    fr = mat("busstop_frame", "#4a6a7a", rough=0.6, metal=0.3)
    for x in (-1.9, 1.9):
        for y in (-0.6, 0.6):
            b.box((0.08, 0.08, 2.5), (x, y, 1.25), fr)
    b.box((4.1, 1.6, 0.08), (0, 0, 2.54), fr, rot=(-0.06, 0, 0))
    b.box((4.0, 0.04, 1.7), (0, 0.6, 1.35), m["glass_l"])
    b.box((0.04, 1.2, 1.7), (-1.9, 0, 1.35), m["glass_l"])
    b.box((0.04, 1.2, 1.7), (1.9, 0, 1.35), m["glass_l"])
    b.box((3.0, 0.35, 0.05), (0, 0.38, 0.48), m["wood"])
    for x in (-1.3, 0, 1.3):
        b.box((0.06, 0.3, 0.46), (x, 0.38, 0.23), m["metal_d"])
    b.box((1.6, 0.05, 0.3), (0, 0.65, 2.25), mat("sign_blue", "#2a5a9a", rough=0.6))
    b.text("ОСТАНОВКА", 0.16, (0, 0.62, 2.25), mat("sign_white", "#e0e0d8", rough=0.6), depth=0.01, rot=(H, 0, 0))
    b.box((4.4, 2.0, 0.1), (0, 0.0, 0.05), m["concrete_d"])


def kiosk(m):
    b = Part("Kiosk")
    k = mat("kiosk_paint", "#7a8a6a", rough=0.7, metal=0.2)
    b.box((2.6, 2.0, 2.4), (0, 0, 1.2), k, bevel=0.02)
    b.box((2.8, 2.2, 0.1), (0, 0, 2.45), m["metal_d"])
    b.box((1.8, 0.04, 0.9), (0, -1.0, 1.45), m["glass"])
    b.box((1.9, 0.06, 0.08), (0, -1.02, 0.98), m["metal_d"])
    b.box((0.4, 0.15, 0.04), (0, -1.08, 0.98), m["metal"])
    b.box((2.4, 0.06, 0.4), (0, -1.03, 2.15), mat("kiosk_sign", "#c8b880"))
    b.text("ТАБАК  ВОДА", 0.2, (0, -1.07, 2.15), mat("kiosk_text", "#7a2a22"), depth=0.01)
    b.box((1.6, 0.04, 0.6), (0, -1.025, 0.45), mat("kiosk_poster", "#a85a3a"))
    b.box((0.9, 0.02, 2.0), (1.31, 0.4, 1.0), m["metal_d"])


def garage(m, color="#5f6a6a"):
    b = Part("Garage")
    c = mat("garage_paint", color, rough=0.7, metal=0.3)
    b.box((3.2, 6.0, 2.5), (0, 0, 1.25), c)
    b.box((3.4, 6.2, 0.08), (0, 0.0, 2.54), mat("roof_tar", "#2e2c2a"))
    for x in (-0.76, 0.76):
        b.box((1.46, 0.05, 2.1), (x, -3.02, 1.05), mat("garage_gate", "#5a5040", rough=0.7, metal=0.3))
    b.box((0.06, 0.07, 0.25), (0.05, -3.06, 1.0), m["metal_d"])
    b.box((0.4, 0.02, 0.5), (-0.8, -3.06, 1.2), m["rust"])
    b.box((3.2, 0.06, 0.25), (0, -3.03, 2.3), c)


def concrete_fence(m):
    """PO-2 style concrete fence plate (diamond relief) 4m x 2.5m."""
    b = Part("ConcreteFence")
    c = mat("fence_concrete", "#8a877e")
    b.box((4.0, 0.14, 2.5), (0, 0, 1.25), c)
    for i in range(6):
        for j in range(3):
            b.box((0.42, 0.04, 0.42), (-1.68 + i * 0.67, -0.08, 0.6 + j * 0.65), mat("fence_relief", "#7e7b72"),
                  rot=(0, PI / 4, 0))
    b.box((0.25, 0.25, 2.6), (2.0, 0, 1.3), m["concrete_d"])


def transformer(m):
    b = Part("Transformer")
    b.box((3.0, 2.6, 2.9), (0, 0, 1.45), m["brick"])
    b.box((3.2, 2.8, 0.12), (0, 0, 2.95), mat("roof_tar", "#2e2c2a"))
    for x in (-0.6, 0.6):
        b.box((1.0, 0.05, 2.0), (x, -1.32, 1.0), mat("garage_gate", "#5a5040", rough=0.7, metal=0.3))
    b.poly_prism([(-0.15, 0.13), (0.15, 0.13), (0.0, -0.13)], 0.02, mat("sign_yellow", "#d8b030"),
                 center=(0.6, -1.36, 1.6), rot=(0, 0, 0))
    b.box((0.05, 0.03, 0.12), (0.6, -1.375, 1.6), mat("sign_black", "#1a1a1a"), rot=(0, 0.4, 0))


def billboard(m):
    b = Part("Billboard")
    for x in (-1.4, 1.4):
        b.box((0.12, 0.12, 3.4), (x, 0.1, 1.7), m["metal_d"])
    b.box((3.4, 0.12, 1.7), (0, 0, 3.3), m["metal"])
    b.box((3.3, 0.04, 1.6), (0, -0.07, 3.3), mat("billboard_paper", "#b8a888"))
    b.box((1.4, 0.045, 1.2), (-0.8, -0.075, 3.3), mat("billboard_img", "#6a8aa0"))
    b.text("МЕБЕЛЬ", 0.32, (0.75, -0.1, 3.55), mat("billboard_red", "#9a3a2a"), depth=0.01)
    b.text("ДЁШЕВО", 0.22, (0.75, -0.1, 3.05), mat("billboard_text", "#3a3530"), depth=0.01)
    b.box((1.2, 0.05, 0.5), (0.6, -0.08, 2.75), mat("billboard_torn", "#d0c8b0"), rot=(0, 0.1, 0))


def shop_sign(m, text="ПРОДУКТЫ", color="#3a5a7a", tcol="#e8e0c8", w=5.0, cross=False, key="shop"):
    b = Part("ShopSign")
    # ASCII material names: non-Latin names collide in the Godot glTF importer.
    b.box((w, 0.1, 0.8), (0, 0, 0.4), mat("sign_bg_" + key, color, rough=0.6), bevel=0.02)
    b.text(text, 0.5, (0.35 if cross else 0, -0.06, 0.4), mat("sign_text_" + key, tcol, emit=0.0), depth=0.03)
    if cross:
        g = mat("sign_cross", "#3aa060", emit=0.0)
        x0 = -w / 2 + 0.55
        b.box((0.5, 0.06, 0.16), (x0, -0.06, 0.4), g)
        b.box((0.16, 0.06, 0.5), (x0, -0.06, 0.4), g)


def balcony(m):
    """Panel-house balcony: slab + corrugated parapet. Origin at façade wall line, extends -Y."""
    b = Part("Balcony")
    b.box((3.0, 1.1, 0.16), (0, -0.55, 0.08), m["concrete"])
    b.box((3.0, 0.06, 1.0), (0, -1.08, 0.66), mat("balcony_panel", "#8a8270"))
    for i in range(14):
        b.box((0.05, 0.08, 0.95), (-1.4 + i * 0.215, -1.1, 0.66), mat("balcony_rib", "#7a7262"))
    for x in (-1.47, 1.47):
        b.box((0.06, 1.1, 1.0), (x, -0.55, 0.66), mat("balcony_panel", "#8a8270"))
    b.box((3.06, 0.12, 0.06), (0, -1.08, 1.18), m["metal_d"])
    b.box((1.8, 0.02, 0.02), (0.2, -0.3, 1.9), m["metal_d"])  # clothesline


def entrance_canopy(m):
    b = Part("Canopy")
    b.box((2.6, 1.4, 0.14), (0, -0.7, 0.0), m["concrete"])
    b.box((2.6, 0.08, 0.2), (0, -1.38, -0.04), m["concrete_d"])
    b.cyl(0.09, 0.1, (0.0, -0.4, -0.12), m["lamp"], seg=8)


def pallet(m):
    b = Part("Pallet")
    for i in range(5):
        b.box((1.2, 0.12, 0.025), (0, -0.36 + i * 0.18, 0.13), m["wood_l"])
    for x in (-0.5, 0, 0.5):
        b.box((0.1, 0.8, 0.1), (x, 0, 0.06), m["wood"])


def shards(m):
    b = Part("Shards")
    gl = m["glass_l"]
    rnd = random.Random(11)
    for i in range(14):
        a = rnd.random() * PI
        b.poly_prism([(0, 0), (rnd.uniform(0.04, 0.12), 0), (rnd.uniform(0, 0.06), rnd.uniform(0.05, 0.12))], 0.004, gl,
                     center=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.35, 0.35), 0.004), rot=(H, 0, a))


ASSETS = {
    "furniture/fridge": fridge, "furniture/stove": stove,
    "furniture/kitchen_cabinet": lambda m: kitchen_cabinet(m), "furniture/kitchen_sink": lambda m: kitchen_cabinet(m, True),
    "furniture/wall_cabinet": wall_cabinet, "furniture/kitchen_table": kitchen_table, "furniture/stool": stool,
    "furniture/chair": chair, "furniture/bed": bed, "furniture/sofa": sofa, "furniture/wardrobe": wardrobe,
    "furniture/stenka": stenka, "furniture/dresser": dresser, "furniture/tv": tv, "furniture/carpet_wall": carpet_wall,
    "furniture/carpet_floor": carpet_floor, "furniture/bathtub": bathtub, "furniture/toilet": toilet,
    "furniture/washbasin": washbasin, "furniture/radiator": radiator, "furniture/shop_shelf": shop_shelf,
    "furniture/shop_counter": shop_counter, "furniture/drink_fridge": drink_fridge, "furniture/pharm_shelf": pharm_shelf,
    "furniture/pharm_counter": pharm_counter, "furniture/mailboxes": mailboxes, "furniture/toolbox": toolbox, "furniture/crate_army": crate_army, "environment/campfire": campfire,
    "buildings/intercom": intercom, "buildings/door_wood": door_wood, "buildings/door_metal": door_metal,
    "buildings/door_apartment": door_apartment, "buildings/door_glass": door_glass, "buildings/door_balcony": door_balcony,
    "buildings/balcony": balcony, "buildings/canopy": entrance_canopy,
    "buildings/sign_produkty": lambda m: shop_sign(m, "ПРОДУКТЫ", "#3a5a7a", "#e8e0c8", 5.0, key="produkty"),
    "buildings/sign_apteka": lambda m: shop_sign(m, "АПТЕКА", "#d8d8d0", "#2a7a4a", 4.2, cross=True, key="apteka"),
    "environment/bench": bench, "environment/dumpster": dumpster, "environment/trash_bag": trash_bag,
    "environment/cardboard": cardboard, "environment/urn": urn, "environment/tire": tire, "environment/pallet": pallet,
    "environment/shards": shards,
    "environment/swing": swing, "environment/slide": slide, "environment/carousel": carousel,
    "environment/sandbox": sandbox, "environment/horizontal_bar": horizontal_bar,
    "environment/birch_1": lambda m: birch(m, 1), "environment/birch_2": lambda m: birch(m, 4),
    "environment/poplar_1": lambda m: poplar(m, 2), "environment/poplar_2": lambda m: poplar(m, 9),
    "environment/dead_tree": dead_tree,
    "environment/bush_1": lambda m: bush(m, 3), "environment/bush_2": lambda m: bush(m, 8),
    "environment/streetlight": streetlight, "environment/sign_bus": lambda m: road_sign(m, "bus"),
    "environment/sign_crossing": lambda m: road_sign(m, "crossing"), "environment/sign_giveway": lambda m: road_sign(m, "giveway"),
    "environment/sign_stop": lambda m: road_sign(m, "stop"),
    "environment/bus_stop": bus_stop, "environment/kiosk": kiosk, "environment/garage": garage,
    "environment/garage_rust": lambda m: garage(m, "#6a5444"), "environment/concrete_fence": concrete_fence,
    "environment/transformer": transformer, "environment/billboard": billboard,
    "vehicles/car_beige": lambda m: car(m, color="#b8ab8a"), "vehicles/car_red": lambda m: car(m, color="#8a3a32", wreck=True),
    "vehicles/car_blue": lambda m: car(m, color="#4a5a6a"), "vehicles/car_white": lambda m: car(m, color="#c8c4b8", wreck=True),
}


def run(names):
    out = []
    for name in names:
        rzlib.reset()
        ASSETS[name](M())
        out.append(rzlib.export("assets/%s.glb" % name))
    return out


_names = sys.argv[1:] or list(ASSETS.keys())
result = {"exported": run(_names)}
