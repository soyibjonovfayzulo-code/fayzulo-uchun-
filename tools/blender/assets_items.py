"""Item models (world drop models + icon sources). Run: bmcp.py assets_items.py [id ...]
Exports assets/items/<id>.glb. Real-world sizes; the game scales dropped items up slightly.
"""
import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import rzlib  # noqa: E402

importlib.reload(rzlib)
from rzlib import Part, mat  # noqa: E402

H = math.pi / 2


def can(p, r, h, body, label, top="#a8aaa8", band=None):
    tin = mat("tin", top, rough=0.4, metal=0.6)
    p.cyl(r, h, (0, 0, h / 2), tin, seg=12)
    p.cyl(r * 1.02, h * 0.72, (0, 0, h / 2), mat(label, body), seg=12)
    if band:
        p.cyl(r * 1.03, h * 0.18, (0, 0, h * 0.55), mat(label + "_band", band), seg=12)
    p.cyl(r * 0.98, 0.004, (0, 0, h + 0.001), tin, seg=12)


def bottle(p, r, h, glass_col, cap, label, label_col):
    g = mat("GlassBottle_" + label, glass_col, rough=0.15, alpha=0.75)
    p.cyl(r, h * 0.7, (0, 0, h * 0.35), g, seg=10)
    p.cyl(r, h * 0.2, (0, 0, h * 0.78), g, r2=r * 0.35, seg=10)
    p.cyl(r * 0.33, h * 0.12, (0, 0, h * 0.94), g, seg=8)
    p.cyl(r * 0.36, h * 0.05, (0, 0, h * 1.0), mat("cap_" + label, cap), seg=8)
    p.cyl(r * 1.03, h * 0.3, (0, 0, h * 0.38), mat("label_" + label, label_col), seg=10)


def box_pack(p, size, col, stripe=None, stripe_col="#d8d0b0"):
    p.box(size, (0, 0, size[2] / 2), mat("pack_" + col, col), bevel=0.004)
    if stripe:
        p.box((size[0] * 1.01, size[1] * 1.01, size[2] * stripe), (0, 0, size[2] * 0.55), mat("stripe_" + stripe_col, stripe_col))


def tushenka(p):
    can(p, 0.05, 0.11, "#c8b070", "lbl_tush", band="#7a2a22")


def kilka(p):
    tin = mat("tin", "#a8aaa8", rough=0.4, metal=0.6)
    p.cyl(0.045, 0.035, (0, 0, 0.0175), tin, seg=12)
    p.cyl(0.046, 0.025, (0, 0, 0.0175), mat("lbl_kilka", "#b83a2a"), seg=12)
    p.cyl(0.02, 0.002, (0.0, 0.0, 0.036), mat("lbl_kilka_ring", "#d8c060"), seg=8)


def sgushenka(p):
    can(p, 0.038, 0.08, "#5a8ac0", "lbl_sgush", band="#e8e4d8")


def bread(p):
    crust = mat("bread_crust", "#7a4a24")
    p.box((0.22, 0.11, 0.08), (0, 0, 0.04), crust, bevel=0.025)
    p.box((0.2, 0.1, 0.02), (0, 0, 0.083), mat("bread_top", "#5e361a"), bevel=0.008)


def water(p):
    bottle(p, 0.045, 0.32, "#a8c8d8", "#2a5a9a", "water", "#4a8ac8")


def soda(p):
    bottle(p, 0.035, 0.26, "#6a8a4a", "#c8a040", "soda", "#e8b040")


def kvas(p):
    bottle(p, 0.05, 0.3, "#5a3a20", "#c84a2a", "kvas", "#d8b060")


def vodka(p):
    bottle(p, 0.038, 0.3, "#d8e0e0", "#c8c8c0", "vodka", "#e8e8e0")
    p.cyl(0.04, 0.03, (0, 0, 0.13), mat("vodka_red", "#b02a20"), seg=10)


def chocolate(p):
    p.box((0.16, 0.075, 0.012), (0, 0, 0.006), mat("choc_wrap", "#d8c8a0"))
    p.box((0.1, 0.077, 0.013), (0.02, 0, 0.0065), mat("choc_red", "#b0302a"))
    p.box((0.04, 0.03, 0.014), (-0.05, 0, 0.007), mat("choc_face", "#e8d8b8"))


def buckwheat(p):
    box_pack(p, (0.12, 0.06, 0.17), "#b88a4a", 0.3, "#e8e0c8")


def macaroni(p):
    box_pack(p, (0.11, 0.05, 0.19), "#3a6aa0", 0.25, "#e8c860")


def sausage(p):
    s = mat("sausage", "#c87a72")
    p.cyl(0.035, 0.26, (0, 0, 0.035), s, rot=(0, H, 0), seg=10)
    p.cyl(0.01, 0.02, (0.14, 0, 0.035), mat("twine", "#c8b080"), rot=(0, H, 0), seg=6)


def pickles(p):
    g = mat("GlassJar", "#a8c8a8", rough=0.15, alpha=0.6)
    p.cyl(0.055, 0.15, (0, 0, 0.075), g, seg=12)
    p.cyl(0.05, 0.13, (0, 0, 0.07), mat("pickle_green", "#4a6a2a"), seg=10)
    p.cyl(0.05, 0.02, (0, 0, 0.16), mat("lid_gold", "#c8a040", metal=0.6, rough=0.4), seg=12)


def apple(p):
    p.sphere(0.04, (0, 0, 0.04), mat("apple", "#a83a2a"), seg=10, rings=7)
    p.cyl(0.004, 0.02, (0, 0, 0.085), mat("stem", "#4a3020"), seg=4)


def crackers(p):
    p.box((0.14, 0.05, 0.18), (0, 0, 0.09), mat("cracker_bag", "#d8a848"), bevel=0.01, taper=(0.8, 0.6))


def bandage(p):
    p.cyl(0.03, 0.06, (0, 0, 0.03), mat("bandage", "#e8e8e0"), seg=12)
    p.cyl(0.031, 0.015, (0, 0, 0.03), mat("bandage_pack", "#4a7ab0"), seg=12)


def first_aid(p):
    p.box((0.22, 0.08, 0.15), (0, 0, 0.075), mat("aid_orange", "#c86030"), bevel=0.012)
    p.box((0.06, 0.082, 0.02), (0, 0, 0.08), mat("aid_cross", "#e8e8e0"))
    p.box((0.02, 0.082, 0.06), (0, 0, 0.08), mat("aid_cross", "#e8e8e0"))
    p.box((0.08, 0.02, 0.012), (0, 0, 0.155), mat("aid_handle", "#2a2a2a"))


def zelenka(p):
    g = mat("GlassVial", "#2a8a4a", rough=0.15, alpha=0.8)
    p.cyl(0.013, 0.06, (0, 0, 0.03), g, seg=8)
    p.cyl(0.008, 0.015, (0, 0, 0.068), mat("cap_black", "#1a1a1a"), seg=6)
    p.cyl(0.0135, 0.025, (0, 0, 0.03), mat("lbl_zel", "#e8e8e0"), seg=8)


def iodine(p):
    g = mat("GlassVialBrown", "#5a2a10", rough=0.15, alpha=0.85)
    p.cyl(0.013, 0.06, (0, 0, 0.03), g, seg=8)
    p.cyl(0.008, 0.015, (0, 0, 0.068), mat("cap_black", "#1a1a1a"), seg=6)
    p.cyl(0.0135, 0.025, (0, 0, 0.03), mat("lbl_iod", "#d8c060"), seg=8)


def analgin(p):
    p.box((0.1, 0.04, 0.02), (0, 0, 0.01), mat("pill_strip", "#c8c8c0", metal=0.4, rough=0.4))
    for i in range(5):
        p.cyl(0.006, 0.006, (-0.04 + i * 0.02, 0, 0.022), mat("pill", "#f0f0e8"), seg=6)


def plaster(p):
    p.cyl(0.025, 0.015, (0, 0, 0.0075), mat("plaster_roll", "#d8b890"), seg=10)
    p.cyl(0.01, 0.016, (0, 0, 0.0075), mat("plaster_core", "#e8e0c8"), seg=8)


def knife(p):
    p.box((0.11, 0.022, 0.018), (-0.055, 0, 0.009), mat("knife_handle", "#5a3a22"), bevel=0.004)
    p.box((0.15, 0.03, 0.004), (0.075, 0, 0.009), mat("steel", "#c8ccd0", rough=0.3, metal=0.7), taper=(1.0, 0.3))


def bat(p):
    w = mat("bat_wood", "#b08a5a", rough=0.6)
    p.cyl(0.035, 0.5, (0.25, 0, 0.035), w, rot=(0, H, 0), r2=0.016, seg=10)
    p.cyl(0.016, 0.32, (-0.15, 0, 0.035), w, rot=(0, H, 0), seg=8)
    p.cyl(0.02, 0.02, (-0.31, 0, 0.035), w, rot=(0, H, 0), seg=8)
    p.cyl(0.017, 0.14, (-0.22, 0, 0.035), mat("grip_tape", "#2a2a2a"), rot=(0, H, 0), seg=8)


def axe(p):
    p.cyl(0.016, 0.62, (0, 0, 0.018), mat("axe_handle", "#9a7a4a"), rot=(0, H, 0), seg=8)
    head = mat("axe_head", "#5a5e62", rough=0.4, metal=0.7)
    p.box((0.05, 0.03, 0.04), (0.29, 0, 0.018), head)
    p.box((0.04, 0.016, 0.14), (0.3, 0, 0.07), head, taper=(1.0, 0.4))
    p.box((0.042, 0.017, 0.02), (0.3, 0, 0.13), mat("axe_edge", "#c8ccd0", metal=0.7, rough=0.3))


def hammer(p):
    p.cyl(0.013, 0.3, (0, 0, 0.015), mat("hammer_handle", "#a8865a"), rot=(0, H, 0), seg=8)
    p.box((0.03, 0.03, 0.11), (0.15, 0, 0.03), mat("steel_dark", "#3e4246", rough=0.4, metal=0.7))


def crowbar(p):
    s = mat("crowbar_paint", "#8a2a22", rough=0.5, metal=0.4)
    p.cyl(0.011, 0.6, (0, 0, 0.012), s, rot=(0, H, 0), seg=6)
    p.cyl(0.011, 0.08, (0.32, 0, 0.04), s, rot=(0.0, 0.5, 0), seg=6)
    p.cyl(0.011, 0.06, (-0.31, 0, 0.03), s, rot=(0.0, -1.0, 0), seg=6)


def pipe(p):
    p.cyl(0.018, 0.55, (0, 0, 0.018), mat("pipe_rust", "#6a4a3a", rough=0.7, metal=0.4), rot=(0, H, 0), seg=8)


def pistol(p):
    m = mat("gun_metal", "#2a2c2e", rough=0.35, metal=0.7)
    p.box((0.16, 0.028, 0.035), (0.02, 0, 0.1), m, bevel=0.004)
    p.box((0.035, 0.028, 0.09), (-0.04, 0, 0.05), mat("gun_grip", "#3a2a22"), rot=(0, -0.25, 0), bevel=0.004)
    p.box((0.03, 0.01, 0.012), (0.0, 0, 0.07), m)


def ammo(p):
    p.box((0.08, 0.05, 0.035), (0, 0, 0.0175), mat("ammo_box", "#6a7a4a"), bevel=0.003)
    for i in range(4):
        p.cyl(0.0045, 0.025, (-0.025 + i * 0.016, 0, 0.045), mat("brass", "#c8a040", metal=0.7, rough=0.3), seg=6)


def screwdriver(p):
    p.cyl(0.013, 0.09, (-0.045, 0, 0.013), mat("sd_handle", "#c8302a", rough=0.4), rot=(0, H, 0), seg=8)
    p.cyl(0.004, 0.11, (0.055, 0, 0.013), mat("steel", "#c8ccd0", rough=0.3, metal=0.7), rot=(0, H, 0), seg=6)


def pliers(p):
    st = mat("steel_dark", "#3e4246", rough=0.4, metal=0.7)
    p.box((0.07, 0.012, 0.01), (0.06, 0, 0.006), st, taper=(1.0, 0.6))
    for s in (-1, 1):
        p.box((0.11, 0.012, 0.01), (-0.03, s * 0.012, 0.006), mat("pliers_grip", "#2a5aa0"), rot=(0, 0, s * 0.12))


def saw(p):
    p.box((0.32, 0.002, 0.08), (0.08, 0, 0.04), mat("steel", "#c8ccd0", rough=0.3, metal=0.7), taper=(1.0, 0.6))
    p.box((0.1, 0.025, 0.1), (-0.12, 0, 0.05), mat("saw_handle", "#3a2a1e"), bevel=0.01)


def wrench(p):
    st = mat("steel", "#c8ccd0", rough=0.3, metal=0.7)
    p.box((0.2, 0.012, 0.02), (0, 0, 0.006), st)
    p.cyl(0.02, 0.012, (0.11, 0, 0.006), st, rot=(H, 0, 0), seg=8)
    p.cyl(0.018, 0.012, (-0.11, 0, 0.006), st, rot=(H, 0, 0), seg=8)


def backpack(p):
    c = mat("backpack", "#4a5a3a")
    p.box((0.3, 0.18, 0.42), (0, 0, 0.21), c, bevel=0.05)
    p.box((0.22, 0.06, 0.18), (0, -0.11, 0.15), mat("backpack_pocket", "#3e4c30"), bevel=0.02)
    p.box((0.3, 0.19, 0.06), (0, 0, 0.41), mat("backpack_top", "#3a4a2c"), bevel=0.02)


def sportbag(p):
    p.box((0.42, 0.22, 0.22), (0, 0, 0.11), mat("sportbag", "#2a3a6a"), bevel=0.06)
    p.box((0.43, 0.05, 0.05), (0, 0, 0.18), mat("sportbag_stripe", "#e8e8e0"))
    p.cyl(0.01, 0.2, (0, 0, 0.25), mat("strap", "#1a1a1a"), rot=(0, H, 0), seg=6)


def telogreika(p):
    c = mat("telogreika", "#3a3e36")
    p.box((0.42, 0.3, 0.05), (0, 0, 0.025), c, bevel=0.015)
    for i in range(5):
        p.box((0.43, 0.012, 0.052), (0, -0.12 + i * 0.06, 0.026), mat("telo_stitch", "#2a2e28"))
    p.box((0.14, 0.1, 0.03), (0.26, 0.05, 0.02), c)
    p.box((0.14, 0.1, 0.03), (-0.26, 0.05, 0.02), c)


def sweater(p):
    p.box((0.36, 0.28, 0.04), (0, 0, 0.02), mat("sweater", "#8a3a34"), bevel=0.015)
    p.box((0.37, 0.04, 0.042), (0, -0.05, 0.021), mat("sweater_band", "#d8c8a8"))


def tracksuit(p):
    p.box((0.36, 0.28, 0.04), (0, 0, 0.02), mat("tracksuit", "#2a3a8a"), bevel=0.015)
    for s in (-1, 1):
        p.box((0.02, 0.28, 0.042), (s * 0.12, 0, 0.021), mat("track_stripe", "#e8e8e0"))


def flashlight(p):
    b = mat("flashlight", "#c8a030", rough=0.4, metal=0.3)
    p.cyl(0.018, 0.14, (0, 0, 0.02), b, rot=(0, H, 0), seg=10)
    p.cyl(0.026, 0.04, (0.085, 0, 0.026), b, rot=(0, H, 0), r2=0.03, seg=10)
    p.cyl(0.024, 0.004, (0.106, 0, 0.026), mat("lens", "#e8e8d8", emit=0.5), rot=(0, H, 0), seg=10)


def batteries(p):
    for i in range(2):
        p.cyl(0.007, 0.05, (-0.01 + i * 0.02, 0, 0.007), mat("battery", "#2a4a8a"), rot=(0, H, 0), seg=8)
        p.cyl(0.0072, 0.015, (0.016 - 0.0 + i * 0.0, (i - 0.5) * 0.02, 0.007), mat("battery_cap", "#c8c8c0", metal=0.6), rot=(0, H, 0), seg=8)


def matches(p):
    p.box((0.05, 0.035, 0.015), (0, 0, 0.0075), mat("match_box", "#c8b080"))
    p.box((0.052, 0.036, 0.004), (0, 0, 0.016), mat("match_label", "#3a5a8a"))


def lighter(p):
    p.box((0.022, 0.012, 0.075), (0, 0, 0.0375), mat("lighter", "#b03a2a", rough=0.3), bevel=0.004)
    p.box((0.022, 0.012, 0.012), (0, 0, 0.081), mat("lighter_top", "#a8aaa8", metal=0.6))


def cigarettes(p):
    p.box((0.055, 0.022, 0.085), (0, 0, 0.0425), mat("cig_pack", "#d8d0b8"), bevel=0.002)
    p.box((0.056, 0.023, 0.03), (0, 0, 0.06), mat("cig_band", "#b03a2a"))


def keys(p):
    st = mat("key_brass", "#c8a848", rough=0.3, metal=0.7)
    p.cyl(0.015, 0.003, (0, 0, 0.002), mat("key_ring", "#a8aaa8", metal=0.7), seg=12)
    p.box((0.05, 0.008, 0.003), (0.035, 0, 0.002), st)
    p.box((0.045, 0.008, 0.003), (0.02, 0.03, 0.002), mat("key_steel", "#a8aaa8", metal=0.7), rot=(0, 0, 0.9))


def newspaper(p):
    p.box((0.24, 0.17, 0.01), (0, 0, 0.005), mat("newspaper", "#d8d4c0"))
    p.box((0.2, 0.03, 0.011), (0, -0.06, 0.0055), mat("news_head", "#3a3a3a"))


# --- v0.3 survival items ------------------------------------------------------------------
def _pot_body(p):
    al = mat("pot_alu", "#a8aca8", rough=0.35, metal=0.7)
    p.cyl(0.09, 0.11, (0, 0, 0.055), al, seg=16)
    p.cyl(0.092, 0.008, (0, 0, 0.112), al, seg=16)
    for x in (-0.105, 0.105):
        p.box((0.03, 0.018, 0.012), (x, 0, 0.1), mat("pot_handle", "#2a2a2a"))
    return al


def pot(p):
    _pot_body(p)
    p.cyl(0.082, 0.003, (0, 0, 0.1165), mat("pot_inside", "#4a4c4a", metal=0.5), seg=16)


def _pot_food(p, col, name):
    _pot_body(p)
    p.cyl(0.082, 0.006, (0, 0, 0.117), mat(name, col), seg=16)


def pot_buckwheat(p):
    _pot_food(p, "#7a4a2a", "kasha_buckwheat")


def pot_macaroni(p):
    _pot_food(p, "#e0c070", "kasha_macaroni")


def pot_navy(p):
    _pot_food(p, "#6a3a24", "kasha_navy")
    for i in range(5):
        a = i * 1.26
        p.box((0.025, 0.02, 0.012), (math.cos(a) * 0.045, math.sin(a) * 0.045, 0.121), mat("stew_meat", "#8a3a2a"))


def can_opener(p):
    st = mat("opener_steel", "#b8bab8", rough=0.3, metal=0.8)
    p.box((0.11, 0.012, 0.006), (0, 0, 0.003), mat("opener_handle", "#5a3a24"), bevel=0.002)
    p.box((0.04, 0.01, 0.005), (0.07, 0, 0.003), st)
    p.box((0.012, 0.01, 0.012), (0.09, 0, 0.008), st, rot=(0, 0.5, 0))


def antibiotics(p):
    p.box((0.09, 0.035, 0.05), (0, 0, 0.025), mat("amox_box", "#e8e4dc"), bevel=0.002)
    p.box((0.091, 0.036, 0.014), (0, 0, 0.034), mat("amox_band", "#3a8a8a"))
    p.box((0.02, 0.037, 0.02), (-0.03, 0, 0.018), mat("amox_red", "#c83a2a"))


def coffee(p):
    g = mat("GlassCoffee", "#5a3a20", rough=0.2, alpha=0.85)
    p.cyl(0.035, 0.09, (0, 0, 0.045), g, seg=12)
    p.cyl(0.036, 0.04, (0, 0, 0.045), mat("coffee_label", "#c8282a"), seg=12)
    p.cyl(0.033, 0.015, (0, 0, 0.097), mat("coffee_lid", "#c8a040", metal=0.5, rough=0.4), seg=12)


def sleeping_pills(p):
    p.box((0.07, 0.025, 0.035), (0, 0, 0.0175), mat("dimedrol_box", "#d8e0e8"), bevel=0.002)
    p.box((0.071, 0.026, 0.01), (0, 0, 0.025), mat("dimedrol_band", "#3a5aa8"))


def empty_bottle(p):
    g = mat("GlassBottle_empty", "#c8d8e0", rough=0.15, alpha=0.5)
    r, h = 0.045, 0.32
    p.cyl(r, h * 0.7, (0, 0, h * 0.35), g, seg=10)
    p.cyl(r, h * 0.2, (0, 0, h * 0.78), g, r2=r * 0.35, seg=10)
    p.cyl(r * 0.33, h * 0.12, (0, 0, h * 0.94), g, seg=8)
    p.cyl(r * 0.36, h * 0.05, (0, 0, h * 1.0), mat("cap_water", "#2a5a9a"), seg=8)


def firewood(p):
    bark = mat("birch_bark", "#d8d4c8")
    cut = mat("wood_cut", "#c8a070")
    for i, (x, y, z) in enumerate([(-0.04, 0, 0.035), (0.04, 0, 0.035), (0, 0, 0.1)]):
        p.cyl(0.035, 0.3, (0, y + x, z), bark, rot=(0, H, 0), seg=8)
        p.cyl(0.033, 0.002, (0.151, y + x, z), cut, rot=(0, H, 0), seg=8)
        p.box((0.004, 0.06, 0.01), (0.02 * i - 0.05, y + x, z + 0.03), mat("birch_mark", "#2a2a2a"))


# --- v0.4 items --------------------------------------------------------------------------------
def potato(p):
    sk = mat("potato_skin", "#9a7a4a")
    for i, (x, y) in enumerate([(-0.04, 0), (0.04, 0.02), (0.0, -0.04), (0.02, 0.05)]):
        p.sphere(0.035, (x, y, 0.03), sk, scale=(1.3, 1.0, 0.85), seg=7, rings=5)
    p.box((0.2, 0.16, 0.01), (0, 0, 0.002), mat("sack", "#a89a70"))


def pot_potato(p):
    _pot_food(p, "#d8c078", "kasha_potato")
    for i in range(4):
        a = i * 1.57
        p.sphere(0.025, (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.122), mat("potato_boiled", "#e0cc88"), seg=6, rings=4)


def jam(p):
    g = mat("GlassJar", "#a8c8a8", rough=0.15, alpha=0.6)
    p.cyl(0.04, 0.1, (0, 0, 0.05), g, seg=12)
    p.cyl(0.037, 0.085, (0, 0, 0.045), mat("jam_red", "#6a1a1a"), seg=10)
    p.cyl(0.042, 0.012, (0, 0, 0.105), mat("jam_cloth", "#c8c0a0"), seg=10)


def planks(p):
    wd = mat("plank_new", "#8a7458")
    for i in range(3):
        p.box((0.9, 0.12, 0.025), (0, (i - 1) * 0.13, 0.0125 + (i % 2) * 0.025), wd, bevel=0.003)


def nails(p):
    p.box((0.08, 0.05, 0.03), (0, 0, 0.015), mat("nail_box", "#6a6a8a"))
    st = mat("nail_steel", "#a8aaa8", metal=0.7, rough=0.3)
    for i in range(4):
        p.cyl(0.002, 0.06, (0.06 + i * 0.008, 0.0, 0.004), st, rot=(0, H, 0.3 * i), seg=4)


def shotgun(p):
    wd = mat("gun_wood", "#5a3a22")
    st = mat("gun_steel", "#3a3c3e", metal=0.6, rough=0.4)
    p.box((0.32, 0.04, 0.07), (-0.22, 0, 0.035), wd, bevel=0.01, taper=(0.7, 1.0))
    p.box((0.12, 0.045, 0.05), (-0.02, 0, 0.04), st)
    for y in (-0.012, 0.012):
        p.cyl(0.011, 0.62, (0.35, y, 0.045), st, rot=(0, H, 0), seg=8)
    p.box((0.25, 0.035, 0.025), (0.15, 0, 0.022), wd)


def shells(p):
    for i in range(5):
        p.cyl(0.01, 0.06, (-0.04 + i * 0.022, 0, 0.03), mat("shell_red", "#a82a22"), seg=8)
        p.cyl(0.0105, 0.012, (-0.04 + i * 0.022, 0, 0.006), mat("shell_brass", "#c8a040", metal=0.7, rough=0.3), seg=8)


def jerrycan(p):
    c = mat("jerrycan", "#5a6a3a", rough=0.5, metal=0.2)
    p.box((0.34, 0.16, 0.46), (0, 0, 0.23), c, bevel=0.02)
    p.box((0.2, 0.06, 0.04), (-0.04, 0, 0.48), c)
    p.cyl(0.025, 0.05, (0.12, 0, 0.48), mat("jerry_cap", "#3a3a3a"), seg=8)
    p.box((0.3, 0.165, 0.02), (0, 0, 0.3), mat("jerry_x", "#4a5830"), rot=(0, 0.6, 0))


def car_key(p):
    p.box((0.035, 0.012, 0.05), (0, 0, 0.006), mat("key_fob", "#1e1e1e"))
    p.box((0.06, 0.006, 0.012), (0.045, 0, 0.006), mat("key_steel", "#a8aaa8", metal=0.7))
    p.cyl(0.012, 0.004, (-0.025, 0, 0.006), mat("key_ring", "#a8aaa8", metal=0.7), seg=10)


ITEMS = {n: globals()[n] for n in """
tushenka kilka sgushenka bread water soda kvas vodka chocolate buckwheat macaroni sausage pickles apple crackers bandage first_aid zelenka iodine analgin plaster knife bat axe hammer crowbar pipe pistol ammo screwdriver pliers saw wrench backpack sportbag telogreika sweater tracksuit flashlight batteries matches lighter cigarettes keys newspaper
pot pot_buckwheat pot_macaroni pot_navy can_opener antibiotics coffee sleeping_pills empty_bottle firewood
potato pot_potato jam planks nails shotgun shells jerrycan car_key
""".split()}


def run(names):
    out = []
    for n in names:
        rzlib.reset()
        p = Part("Item")
        ITEMS[n](p)
        out.append(rzlib.export("assets/items/%s.glb" % n))
    return out


if __name__ == "__main__":
    _names = sys.argv[1:] or sorted(ITEMS.keys())
    result = {"exported": [o["file"] for o in run(_names)]}
