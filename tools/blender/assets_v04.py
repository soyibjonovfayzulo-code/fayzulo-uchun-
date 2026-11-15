"""v0.4 assets: private sector (izba furniture, fences, sheds, wells), roads and infrastructure, a military
checkpoint, a gas station, wrecks, drivable cars (body + separate wheel) and a helicopter.
Run: bmcp.py assets_v04.py [name ...]  (no names = all). Front of every model faces Blender -Y (Godot +Z).
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


def M():
    return dict(
        wood=mat("wood", "#6b4e35"), wood_d=mat("wood_dark", "#4a3526"), wood_l=mat("wood_light", "#9a7a56"),
        wood_grey=mat("wood_grey", "#7a7266"), wood_grey_d=mat("wood_grey_dark", "#565048"),
        metal=mat("metal", "#6f7273", rough=0.6, metal=0.3), metal_d=mat("metal_dark", "#3e4042", rough=0.6, metal=0.3),
        rust=mat("rust", "#7a4a32"), chrome=mat("chrome", "#a8aaa8", rough=0.35, metal=0.6),
        white=mat("whitewash", "#d8d2c2"), brick=mat("brick_red", "#8a4a36"), black=mat("black", "#222222"),
        rubber=mat("rubber", "#1e1e1e", rough=1.0), concrete=mat("concrete", "#8c8a84"),
        concrete_d=mat("concrete_dark", "#6e6c67"), glass=mat("Glass", "#3a4a55", rough=0.1, alpha=0.5),
        soot=mat("soot", "#262220"), char=mat("charcoal", "#1a1816"), ash=mat("ash", "#4a4440"),
        army=mat("army_green", "#4e5a3a"), army_d=mat("army_green_dark", "#3a4430"), canvas=mat("canvas", "#6a6a4a"),
        sand=mat("sandbag", "#a8986e"), red=mat("paint_red", "#8a3a30"), red_w=mat("paint_red_bright", "#b03a2a"),
        white_p=mat("paint_white", "#d8d4c8"), green=mat("paint_green", "#4f6b4a"), blue=mat("paint_blue", "#4a6278"),
        yellow=mat("paint_yellow", "#b89a3a"), leaves=mat("Leaves_apple", "#4f6a36"), pine=mat("Leaves_pine", "#2f4a32"),
        bark=mat("bark", "#4a3a2a"), birch=mat("birch_bark", "#d8d4c8"), dirt=mat("soil", "#4a3a2a"),
        plant=mat("Leaves_veg", "#5a7a3a"), lamp=mat("Lamp", "#f0e0b0", emit=2.0),
    )


# ------------------------------------------------------------------------------------------------ izba interior
def russian_stove(m):
    """Whitewashed Russian stove (печь) with a firebox, a bench on top and a chimney."""
    b = Part("RussianStove")
    w = m["white"]
    b.box((1.3, 1.6, 1.55), (0, 0, 0.775), w, bevel=0.03)
    b.box((1.34, 1.64, 0.08), (0, 0, 1.56), mat("whitewash_dirty", "#bab2a0"))
    b.box((0.55, 0.05, 0.45), (0, -0.81, 0.85), m["char"])              # firebox mouth
    b.box((0.62, 0.06, 0.06), (0, -0.815, 1.1), m["soot"])
    b.box((0.3, 0.04, 0.2), (-0.35, -0.81, 0.35), m["soot"])            # ash pit
    b.box((0.5, 0.5, 0.95), (0.35, 0.45, 2.0), w)                       # chimney stack
    b.box((0.06, 0.06, 0.8), (-0.55, -0.6, 0.4), m["metal_d"])          # poker
    b.box((0.4, 0.3, 0.02), (0, -0.4, 1.6), mat("quilt", "#8a3a3a"))     # rag on the bench


def chest(m):
    b = Part("Chest")
    b.box((0.9, 0.5, 0.45), (0, 0, 0.225), m["wood"], bevel=0.01)
    b.box((0.92, 0.52, 0.08), (0, 0, 0.47), m["wood_d"], bevel=0.01)
    for x in (-0.3, 0.0, 0.3):
        b.box((0.04, 0.53, 0.52), (x, 0, 0.255), m["metal_d"])
    b.box((0.08, 0.02, 0.1), (0, -0.26, 0.38), m["chrome"])


def cellar_hatch(m):
    b = Part("CellarHatch")
    b.box((0.9, 0.9, 0.03), (0, 0, 0.015), m["wood_d"])
    for x in (-0.3, 0, 0.3):
        b.box((0.02, 0.9, 0.035), (x, 0, 0.017), m["black"])
    b.cyl(0.05, 0.015, (0, -0.25, 0.04), m["metal_d"], rot=(H, 0, 0), seg=8)


def icon_corner(m):
    b = Part("IconCorner")
    b.box((0.35, 0.25, 0.03), (0, 0, 0.0), m["wood_d"])
    b.box((0.18, 0.02, 0.24), (0, 0.05, 0.13), mat("icon_gold", "#b8902a", metal=0.5, rough=0.4))
    b.box((0.12, 0.022, 0.16), (0, 0.045, 0.13), mat("icon_face", "#7a4a2a"))
    b.cyl(0.015, 0.05, (0.12, 0, 0.04), mat("Lamp_candle", "#d8783a", emit=0.8), seg=6)


def gun_safe(m):
    b = Part("GunSafe")
    b.box((0.6, 0.45, 1.6), (0, 0, 0.8), mat("safe_grey", "#5a6058", metal=0.4, rough=0.5), bevel=0.01)
    b.box((0.02, 0.02, 1.4), (0.0, -0.23, 0.8), m["black"])
    b.cyl(0.04, 0.03, (0.18, -0.235, 0.9), m["chrome"], rot=(H, 0, 0), seg=8)


# ------------------------------------------------------------------------------------------------ yards
def fence_wood(m, color="#7a8a6a", seed=1):
    """2 m of picket fence (штакетник), weathered paint."""
    rnd = random.Random(seed)
    b = Part("FenceWood")
    paint = mat("fence_paint_%s" % color.strip("#"), color)
    for y in (0.35, 0.95):
        b.box((2.0, 0.04, 0.08), (0, 0.03, y), m["wood_grey"])
    for i in range(10):
        x = -0.9 + i * 0.2
        if rnd.random() < 0.08:
            continue
        h = 1.25 + rnd.uniform(-0.06, 0.06)
        tilt = rnd.uniform(-0.06, 0.06)
        b.box((0.09, 0.025, h), (x, 0, h / 2), paint if rnd.random() > 0.2 else m["wood_grey"], rot=(0, tilt, 0))
    b.box((0.1, 0.1, 1.4), (-1.0, 0.04, 0.7), m["wood_grey_d"])


def shed(m):
    """Plank shed (сарай) with a lean-to roof of sheets."""
    b = Part("Shed")
    pl = mat("planks_shed", "#6a6258")
    b.box((3.0, 2.4, 2.1), (0, 0, 1.05), pl, bevel=0.01)
    for x in range(-14, 15, 2):
        b.box((0.02, 2.42, 2.1), (x * 0.1, 0, 1.05), m["wood_grey_d"])
    b.box((3.4, 2.9, 0.06), (0, 0.1, 2.35), m["rust"], rot=(0.18, 0, 0))
    b.box((0.9, 0.04, 1.8), (0.6, -1.22, 0.9), m["wood_d"])
    b.box((0.06, 0.03, 0.15), (0.2, -1.25, 1.0), m["metal_d"])


def outhouse(m):
    b = Part("Outhouse")
    pl = mat("planks_shed", "#6a6258")
    b.box((1.0, 1.1, 2.0), (0, 0, 1.0), pl)
    b.box((1.2, 1.35, 0.05), (0, 0.05, 2.1), m["rust"], rot=(0.15, 0, 0))
    b.box((0.75, 0.04, 1.8), (0, -0.56, 0.92), m["wood_d"])
    b.box((0.12, 0.05, 0.1), (0, -0.58, 1.6), m["black"])


def well(m):
    """Log-cabin well with a little roof and a windlass."""
    b = Part("Well")
    lg = mat("logs_well", "#5a4a38")
    for i in range(5):
        z = 0.1 + i * 0.18
        for sx in (-0.55, 0.55):
            b.cyl(0.09, 1.3, (sx, 0, z), lg, rot=(H, 0, 0), seg=7)
            b.cyl(0.09, 1.3, (0, sx, z + 0.09), lg, rot=(0, H, 0), seg=7)
    b.cyl(0.45, 0.02, (0, 0, 0.9), mat("well_water", "#1a2430", rough=0.1), seg=12)
    for sx in (-0.6, 0.6):
        b.box((0.08, 0.08, 1.4), (sx, 0, 1.6), m["wood_d"])
    b.cyl(0.07, 1.2, (0, 0, 1.55), m["wood_l"], rot=(0, H, 0), seg=8)
    b.box((0.04, 0.3, 0.04), (0.65, -0.15, 1.55), m["metal_d"])
    for s in (-1, 1):
        b.box((1.5, 0.75, 0.04), (0, s * 0.33, 2.45), m["wood_grey"], rot=(s * 0.6, 0, 0))
    b.cyl(0.12, 0.2, (0.0, -0.3, 1.25), m["metal"], seg=8)


def woodpile(m):
    b = Part("Woodpile")
    for row in range(5):
        for i in range(9):
            x = -0.9 + i * 0.22 + (0.11 if row % 2 else 0)
            b.cyl(0.1, 0.5, (x, 0, 0.1 + row * 0.19), m["birch"] if (i + row) % 3 else m["wood_l"], rot=(H, 0, 0), seg=6)
    b.box((2.3, 0.9, 0.04), (0, 0.05, 1.2), m["rust"], rot=(0.1, 0, 0))
    for x in (-1.05, 1.05):
        b.box((0.06, 0.06, 1.2), (x, 0.0, 0.6), m["wood_grey_d"])


def garden_bed(m, seed=3):
    rnd = random.Random(seed)
    b = Part("GardenBed")
    b.box((3.0, 1.0, 0.18), (0, 0, 0.09), m["dirt"])
    for x in (-1.5, 1.5):
        b.box((0.04, 1.02, 0.2), (x, 0, 0.1), m["wood_grey_d"])
    for i in range(10):
        x = -1.3 + i * 0.29
        for y in (-0.25, 0.25):
            if rnd.random() < 0.25:
                continue
            s = rnd.uniform(0.09, 0.16)
            b.sphere(s, (x, y, 0.2 + s * 0.4), m["plant"], scale=(1, 1, 0.6), seg=6, rings=4)


def dog_booth(m):
    b = Part("DogBooth")
    b.box((0.9, 1.0, 0.75), (0, 0, 0.375), m["wood"])
    for s in (-1, 1):
        b.box((1.05, 0.62, 0.04), (0, s * 0.25, 0.92), m["wood_d"], rot=(s * 0.7, 0, 0))
    b.box((0.4, 0.04, 0.45), (0, -0.51, 0.3), m["black"])
    b.cyl(0.18, 0.06, (0.7, -0.6, 0.03), m["metal"], seg=10)


def barrel_rust(m):
    b = Part("BarrelRust")
    b.cyl(0.29, 0.88, (0, 0, 0.44), m["rust"], seg=12)
    for z in (0.15, 0.73):
        b.cyl(0.3, 0.04, (0, 0, z), mat("rust_dark", "#5a3424"), seg=12)
    b.cyl(0.27, 0.01, (0, 0, 0.885), mat("barrel_water", "#2a2a24", rough=0.2), seg=12)


def power_pole(m):
    """Wooden power pole with a crossbar and glass insulators (wires are drawn by the game)."""
    b = Part("PowerPole")
    b.cyl(0.11, 7.5, (0, 0, 3.75), mat("pole_wood", "#4a3e32"), seg=8, r2=0.09)
    b.box((1.6, 0.1, 0.1), (0, 0, 7.0), m["wood_d"])
    for x in (-0.7, -0.25, 0.25, 0.7):
        b.cyl(0.04, 0.12, (x, 0, 7.12), mat("insulator", "#8aa0a0", rough=0.2), seg=6)
    b.box((0.06, 0.06, 1.2), (0.4, 0, 6.5), m["wood_d"], rot=(0, 0.6, 0))


def apple_tree(m, seed=7):
    rnd = random.Random(seed)
    b = Part("AppleTree")
    b.cyl(0.11, 1.6, (0, 0, 0.8), m["bark"], seg=7, r2=0.08)
    for i in range(6):
        a = i * 1.05 + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(0.6, 1.0)
        b.sphere(rnd.uniform(0.7, 1.0), (math.cos(a) * r * 0.7, math.sin(a) * r * 0.7, 2.0 + rnd.uniform(-0.2, 0.4)),
                 m["leaves"], scale=(1, 1, 0.8), seg=8, rings=6)
    for i in range(14):
        a = rnd.uniform(0, 2 * PI)
        b.sphere(0.05, (math.cos(a) * 1.2, math.sin(a) * 1.2, rnd.uniform(1.5, 2.5)), mat("apple_red", "#a83a2a"), seg=5, rings=4)


def pine(m, seed=5):
    rnd = random.Random(seed)
    b = Part("Pine")
    b.cyl(0.18, 6.0, (0, 0, 3.0), m["bark"], seg=7, r2=0.1)
    for i in range(6):
        z = 2.2 + i * 1.0
        r = 1.7 - i * 0.26 + rnd.uniform(-0.1, 0.1)
        b.cyl(r, 1.4, (0, 0, z), m["pine"], seg=8, r2=0.08)


# ------------------------------------------------------------------------------------------------ checkpoint, ruins
def sandbags(m):
    b = Part("Sandbags")
    for row in range(3):
        for i in range(5):
            x = -0.8 + i * 0.4 + (0.2 if row % 2 else 0)
            if x > 0.95:
                continue
            b.box((0.42, 0.5, 0.2), (x, 0, 0.1 + row * 0.19), m["sand"], bevel=0.06)


def concrete_block(m):
    b = Part("ConcreteBlock")
    b.box((1.2, 0.6, 0.6), (0, 0, 0.3), m["concrete"], bevel=0.02)
    b.box((1.22, 0.01, 0.12), (0, -0.3, 0.45), m["red_w"])
    b.box((0.4, 0.01, 0.12), (0, -0.305, 0.45), m["white_p"])


def barrier_gate(m):
    b = Part("BarrierGate")
    b.box((0.3, 0.3, 1.0), (-2.2, 0, 0.5), m["metal_d"])
    for i in range(8):
        b.box((0.55, 0.08, 0.08), (-1.9 + i * 0.55, 0, 0.95), m["red_w"] if i % 2 == 0 else m["white_p"])
    b.box((0.08, 0.1, 0.9), (2.3, 0, 0.45), m["metal_d"])


def army_tent(m):
    b = Part("ArmyTent")
    b.box((4.0, 3.0, 1.4), (0, 0, 0.7), m["army"])
    for s in (-1, 1):
        b.box((4.1, 1.85, 0.05), (0, s * 0.72, 1.85), m["army_d"], rot=(s * 0.55, 0, 0))
    b.box((1.0, 0.05, 1.6), (0, -1.52, 0.8), m["char"])
    b.box((0.3, 0.02, 0.3), (0, -1.53, 1.1), mat("red_cross", "#a83a2a"))


def army_truck(m):
    """Abandoned army truck with a canvas body."""
    b = Part("ArmyTruck")
    a = m["army"]
    b.box((2.3, 2.0, 1.4), (0, -2.4, 1.4), a, bevel=0.05)
    b.box((2.1, 0.05, 0.6), (0, -3.42, 1.75), m["glass"])
    b.box((2.4, 4.5, 0.25), (0, 0.6, 0.95), m["army_d"])
    b.box((2.35, 4.4, 1.6), (0, 0.6, 1.95), m["canvas"], bevel=0.12)
    for y in (-2.6, 0.0, 1.8):
        for x in (-1.0, 1.0):
            b.cyl(0.5, 0.35, (x, y, 0.5), m["rubber"], rot=(0, H, 0), seg=12)
    b.box((1.2, 0.3, 0.3), (0, -3.45, 0.85), m["metal_d"])
    b.box((0.25, 0.02, 0.25), (0.8, -3.46, 1.35), mat("star_red", "#a83a2a"))


def bus_burned(m):
    """A burned-out city bus."""
    b = Part("BusBurned")
    s = m["soot"]
    b.box((2.5, 11.0, 0.9), (0, 0, 0.95), s, bevel=0.06)
    for i in range(11):
        y = -5.0 + i * 1.0
        for x in (-1.22, 1.22):
            b.box((0.08, 0.12, 1.1), (x, y, 1.95), s)
    b.box((2.5, 11.0, 0.12), (0, 0, 2.55), mat("rust_burnt", "#4a2a1a"), bevel=0.04)
    b.box((2.3, 0.1, 1.0), (0, -5.5, 1.9), m["char"])
    for y in (-3.6, 3.4):
        for x in (-1.15, 1.15):
            b.cyl(0.45, 0.3, (x, y, 0.45), m["char"], rot=(0, H, 0), seg=10)
    b.box((2.0, 9.0, 0.05), (0, 0, 0.6), m["ash"])


def car_burned(m):
    b = Part("CarBurned")
    s = m["soot"]
    b.box((1.62, 4.1, 0.55), (0, 0, 0.55), s, bevel=0.05)
    b.box((1.45, 2.0, 0.5), (0, 0.15, 1.08), mat("rust_burnt", "#4a2a1a"), bevel=0.06, taper=(0.9, 0.85))
    for y in (-1.3, 1.3):
        for x in (-0.75, 0.75):
            b.cyl(0.28, 0.15, (x, y, 0.22), m["char"], rot=(0, H, 0), seg=8)
    b.box((1.3, 1.2, 0.05), (0, -1.4, 0.84), m["ash"])


def fuel_pump(m):
    b = Part("FuelPump")
    b.box((0.7, 0.45, 1.7), (0, 0, 0.85), mat("pump_white", "#d0ccc0"), bevel=0.02)
    b.box((0.72, 0.47, 0.3), (0, 0, 1.55), m["red_w"])
    b.box((0.45, 0.02, 0.25), (0, -0.235, 1.2), mat("Lamp_display", "#2a3a2a", emit=0.2))
    b.cyl(0.03, 0.6, (0.38, -0.1, 0.9), m["black"], seg=6)
    b.box((0.08, 0.12, 0.2), (0.38, -0.2, 1.15), m["metal_d"])
    b.box((1.2, 0.8, 0.15), (0, 0, 0.075), m["concrete"])


def gas_canopy(m):
    """Gas station canopy on four pillars with the АЗС fascia."""
    b = Part("GasCanopy")
    for x in (-4.2, 4.2):
        for y in (-2.2, 2.2):
            b.box((0.35, 0.35, 4.6), (x, y, 2.3), mat("pillar_grey", "#9a9890"))
    b.box((10.0, 6.0, 0.4), (0, 0, 4.8), mat("canopy_white", "#d8d4c8"))
    b.box((10.1, 6.1, 0.35), (0, 0, 4.55), m["red_w"])
    for x in (-3.0, 0.0, 3.0):
        b.box((1.2, 0.3, 0.04), (x, 0, 4.58), mat("Lamp_canopy", "#f0e8d0", emit=0.4))
    b.text("АЗС", 0.32, (0, -3.07, 4.58), mat("sign_white", "#e8e4d8"), depth=0.03)


def traffic_light(m):
    b = Part("TrafficLight")
    b.cyl(0.06, 3.0, (0, 0, 1.5), m["metal_d"], seg=8)
    b.box((0.3, 0.25, 0.85), (0, -0.05, 3.2), m["black"], bevel=0.02)
    for i, c in enumerate(("#3a1a1a", "#3a3a1a", "#1a3a1a")):
        b.cyl(0.08, 0.04, (0, -0.18, 3.5 - i * 0.27), mat("tl_lens_%d" % i, c, rough=0.2), rot=(H, 0, 0), seg=10)


def trash_pile(m, seed=9):
    rnd = random.Random(seed)
    b = Part("TrashPile")
    cols = ["#2a2a2a", "#3a4a3a", "#4a3a2a", "#6a6a5a", "#2a3040"]
    for i in range(14):
        a = rnd.uniform(0, 2 * PI)
        r = rnd.uniform(0, 1.0)
        s = rnd.uniform(0.2, 0.42)
        b.sphere(s, (math.cos(a) * r, math.sin(a) * r, s * 0.6), mat("trash_%d" % (i % 5), cols[i % 5], rough=0.4),
                 scale=(1, 1.1, 0.7), seg=6, rings=4)
    b.box((0.6, 0.4, 0.3), (0.5, -0.4, 0.15), mat("cardboard", "#a8885a"), rot=(0, 0, 0.4))
    b.cyl(0.2, 0.25, (-0.6, 0.5, 0.1), m["rubber"], rot=(H, 0, 0), seg=10)


def suitcase(m):
    b = Part("Suitcase")
    b.box((0.6, 0.2, 0.42), (0, 0, 0.1), mat("suitcase_brown", "#5a3a26"), rot=(H, 0, 0.3), bevel=0.02)
    b.box((0.2, 0.03, 0.03), (0, -0.25, 0.22), m["black"], rot=(0, 0, 0.3))


def plank(m):
    """One board for barricades and boarded-up windows."""
    b = Part("Plank")
    b.box((1.3, 0.035, 0.16), (0, 0, 0.0), mat("plank_new", "#8a7458"), bevel=0.005)
    for x in (-0.55, 0.55):
        b.cyl(0.012, 0.01, (x, -0.02, 0.0), m["metal_d"], rot=(H, 0, 0), seg=5)


def ruin_house(m, seed=4):
    """A burned izba: brick chimney, the stove, charred logs."""
    rnd = random.Random(seed)
    b = Part("RuinHouse")
    b.box((6.5, 7.0, 0.15), (0, 0, 0.075), m["ash"])
    b.box((1.3, 1.5, 1.4), (1.2, 0.8, 0.7), mat("whitewash_burnt", "#6a645a"))
    b.box((0.55, 0.55, 3.6), (1.5, 1.1, 1.8), m["brick"])
    for i in range(16):
        x = rnd.uniform(-3, 3)
        y = rnd.uniform(-3.3, 3.3)
        b.cyl(0.12, rnd.uniform(1.2, 3.2), (x, y, 0.18), m["char"], rot=(H, 0, rnd.uniform(0, PI)), seg=6)
    for x, y in ((-3.1, -3.4), (3.1, -3.4), (-3.1, 3.4)):
        h = rnd.uniform(0.6, 1.6)
        b.box((0.3, 0.3, h), (x, y, h / 2), m["char"])
    b.box((1.0, 0.1, 1.2), (-3.0, -3.45, 0.6), m["char"], rot=(0, 0.2, 0))


# ------------------------------------------------------------------------------------------------ vehicles
def _wheel(m):
    b = Part("Wheel")
    b.cyl(0.3, 0.2, (0, 0, 0), m["rubber"], rot=(0, H, 0), seg=14)
    b.cyl(0.18, 0.21, (0, 0, 0), mat("rim", "#8a8a84", metal=0.5, rough=0.4), rot=(0, H, 0), seg=10)
    b.box((0.21, 0.06, 0.3), (0, 0, 0), m["metal_d"])


def wheel(m):
    _wheel(m)


def sedan_body(m, color="#8a6a3a", key="sedan"):
    """Boxy Soviet-era sedan body (wheels are separate). Length along Y, front at -Y."""
    b = Part("Body")
    paint = mat("CarBody_%s" % key, color, rough=0.45, metal=0.2)
    b.box((1.62, 4.15, 0.6), (0, 0, 0.62), paint, bevel=0.04)
    b.box((1.45, 2.05, 0.52), (0, 0.25, 1.18), paint, bevel=0.05, taper=(0.92, 0.88))
    g = m["glass"]
    b.box((1.36, 0.05, 0.42), (0, -0.82, 1.17), g, rot=(-0.45, 0, 0))
    b.box((1.36, 0.05, 0.4), (0, 1.3, 1.17), g, rot=(0.45, 0, 0))
    for x in (-0.73, 0.73):
        b.box((0.02, 1.75, 0.36), (x, 0.25, 1.2), g)
    b.box((1.66, 0.12, 0.18), (0, -2.1, 0.45), m["chrome"])
    b.box((1.66, 0.12, 0.18), (0, 2.1, 0.45), m["chrome"])
    for x in (-0.55, 0.55):
        b.cyl(0.09, 0.04, (x, -2.08, 0.68), mat("Lamp_head", "#d8d4c0", emit=0.0), rot=(H, 0, 0), seg=10)
        b.box((0.25, 0.04, 0.12), (x, 2.09, 0.7), mat("taillight", "#8a1a1a", rough=0.3))
    b.box((0.7, 0.04, 0.16), (0, -2.09, 0.62), m["metal_d"])                    # grille
    for y in (-1.3, 1.3):
        for x in (-0.82, 0.82):
            b.box((0.06, 0.7, 0.3), (x, y, 0.42), m["black"])                       # wheel arches
    b.box((1.2, 1.0, 0.04), (0, 0.4, 0.97), mat("seat", "#4a3a30"))


def uaz_body(m):
    """Militia off-roader (УАЗ-like), white-blue."""
    b = Part("Body")
    paint = mat("CarBody_uaz", "#c8c4b4", rough=0.5)
    blue = mat("CarBody_uaz_blue", "#3a5a8a", rough=0.5)
    b.box((1.8, 4.0, 0.75), (0, 0, 0.85), paint, bevel=0.04)
    b.box((1.78, 2.6, 0.85), (0, 0.6, 1.6), paint, bevel=0.04)
    b.box((1.82, 4.02, 0.15), (0, 0, 0.95), blue)
    g = m["glass"]
    b.box((1.6, 0.05, 0.55), (0, -0.72, 1.62), g, rot=(-0.12, 0, 0))
    for x in (-0.9, 0.9):
        b.box((0.02, 2.0, 0.4), (x, 0.55, 1.7), g)
    b.box((1.84, 0.15, 0.2), (0, -2.05, 0.6), m["metal_d"])
    b.box((0.8, 0.3, 0.12), (0, 0.4, 2.1), mat("Lamp_siren", "#3a5ac8", emit=0.3))
    for x in (-0.6, 0.6):
        b.cyl(0.1, 0.04, (x, -2.02, 0.95), mat("Lamp_head", "#d8d4c0", emit=0.0), rot=(H, 0, 0), seg=10)
    for y in (-1.35, 1.35):
        for x in (-0.9, 0.9):
            b.box((0.06, 0.75, 0.35), (x, y, 0.5), m["black"])
    b.cyl(0.32, 0.22, (0, 2.12, 1.2), m["rubber"], rot=(H, 0, 0), seg=12)   # spare wheel


def helicopter_body(m):
    """Military transport helicopter (rotor is separate)."""
    b = Part("Body")
    a = mat("heli_green", "#4a5a3e", rough=0.6)
    b.box((2.4, 9.0, 2.4), (0, 0, 1.6), a, bevel=0.5)
    b.box((2.0, 1.6, 1.6), (0, -5.0, 1.4), m["glass"], bevel=0.4)
    b.box((0.7, 7.0, 0.8), (0, 7.5, 2.3), a, bevel=0.2, taper=(0.6, 0.6))
    b.box((0.15, 1.4, 2.0), (0, 11.0, 3.0), a)
    b.box((1.2, 2.5, 0.6), (0, 0.5, 3.0), mat("heli_engine", "#3a4430"), bevel=0.2)
    for x in (-1.1, 1.1):
        b.box((0.12, 4.0, 0.12), (x, 0, 0.1), m["metal_d"])
    b.box((0.3, 0.02, 0.3), (1.21, -1.0, 2.0), mat("star_red", "#a83a2a"))
    b.box((0.3, 0.02, 0.3), (-1.21, -1.0, 2.0), mat("star_red", "#a83a2a"))


def helicopter_rotor(m):
    b = Part("Rotor")
    b.cyl(0.25, 0.3, (0, 0, 0), m["metal_d"], seg=8)
    for i in range(5):
        a = i * 2 * PI / 5
        b.box((8.0, 0.4, 0.05), (math.cos(a) * 4.0, math.sin(a) * 4.0, 0), m["metal_d"], rot=(0, 0, a))


ASSETS = {
    "furniture/russian_stove": russian_stove, "furniture/chest": chest, "furniture/cellar_hatch": cellar_hatch,
    "furniture/icon_corner": icon_corner, "furniture/gun_safe": gun_safe,
    "environment/fence_wood_1": lambda m: fence_wood(m, "#7a8a6a", 1),
    "environment/fence_wood_2": lambda m: fence_wood(m, "#6a7a8a", 2),
    "environment/fence_wood_3": lambda m: fence_wood(m, "#8a7a5a", 3),
    "environment/shed": shed, "environment/outhouse": outhouse, "environment/well": well,
    "environment/woodpile": woodpile, "environment/garden_bed": garden_bed, "environment/dog_booth": dog_booth,
    "environment/barrel_rust": barrel_rust, "environment/power_pole": power_pole,
    "environment/apple_tree": apple_tree, "environment/pine_1": lambda m: pine(m, 5), "environment/pine_2": lambda m: pine(m, 11),
    "environment/sandbags": sandbags, "environment/concrete_block": concrete_block, "environment/barrier_gate": barrier_gate,
    "environment/army_tent": army_tent, "environment/fuel_pump": fuel_pump, "environment/gas_canopy": gas_canopy,
    "environment/traffic_light": traffic_light, "environment/trash_pile": trash_pile, "environment/suitcase": suitcase,
    "environment/plank": plank, "environment/ruin_house": ruin_house,
    "vehicles/army_truck": army_truck, "vehicles/bus_burned": bus_burned, "vehicles/car_burned": car_burned,
    "vehicles/wheel": wheel,
    "vehicles/sedan_body_ochre": lambda m: sedan_body(m, "#8a6a3a", "ochre"),
    "vehicles/sedan_body_green": lambda m: sedan_body(m, "#4a6a5a", "green"),
    "vehicles/sedan_body_white": lambda m: sedan_body(m, "#c8c4b8", "white"),
    "vehicles/uaz_body": uaz_body,
    "aircraft/helicopter_body": helicopter_body, "aircraft/helicopter_rotor": helicopter_rotor,
}


def run(names):
    out = []
    for name in names:
        rzlib.reset()
        ASSETS[name](M())
        out.append(rzlib.export("assets/%s.glb" % name))
    return out


_names = sys.argv[1:] or list(ASSETS.keys())
result = {"exported": [o["file"] for o in run(_names)]}
