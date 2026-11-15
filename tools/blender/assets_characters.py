"""Human rig (rigid parts pivoting at joints) for the player and, later, zombies.

Node names are relied on by scripts/player/character_animator.gd:
Hips > Torso > Head, Torso > ArmL/ArmR > ForearmL/ForearmR, Hips > LegL/LegR > ShinL/ShinR.
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import rzlib  # noqa: E402

importlib.reload(rzlib)
from rzlib import Part, mat  # noqa: E402

PALETTES = {
    "player": dict(top="#4b5240", top_dark="#3b4133", legs="#3e4c63", shoes="#2b2724", skin="#c49a80",
                   hair="#3a2a1e", collar="#8a8478"),
    "zombie_a": dict(top="#6b5a4a", top_dark="#4e4136", legs="#3a3f4a", shoes="#2a2622", skin="#8e9a7a",
                     hair="#2a2420", collar="#5a3a30"),
    "zombie_b": dict(top="#3c4e6a", top_dark="#2c3a50", legs="#2e2e30", shoes="#3a2a22", skin="#9aa088",
                     hair="#6a6058", collar="#7a2e28"),
    "zombie_c": dict(top="#7a3a34", top_dark="#5a2a26", legs="#4a4a3a", shoes="#222222", skin="#86927a",
                     hair="#1e1a18", collar="#4a2a24"),
    # Yard keeper in an orange safety vest.
    "zombie_d": dict(top="#4a4a44", top_dark="#c8642a", legs="#3a3a36", shoes="#2a2622", skin="#909c80",
                     hair="#5a5650", collar="#c8642a", vest=True),
    # Militia officer: grey-blue uniform and peaked cap.
    "zombie_e": dict(top="#4a5668", top_dark="#384252", legs="#3a4252", shoes="#1a1a1a", skin="#8a967c",
                     hair="#2a2420", collar="#a83a2a", cap=True),
    # Conscript in camo with a helmet (the failed evacuation).
    "zombie_f": dict(top="#55603e", top_dark="#3e4630", legs="#4e5638", shoes="#1e1c1a", skin="#86927a",
                     hair="#2a2420", collar="#3e4630", helmet=True),
    # Babushka: headscarf, dark coat, skirt.
    "zombie_g": dict(top="#4a3a40", top_dark="#2e2428", legs="#3a3036", shoes="#2a2622", skin="#9aa08a",
                     hair="#b8b0a0", collar="#7a3a3a", scarf="#8a3a3a", skirt=True),
    # Doctor in a white coat from the town hospital.
    "zombie_h": dict(top="#c8c8bc", top_dark="#a8a89c", legs="#3a4a5a", shoes="#2a2622", skin="#8e9a7e",
                     hair="#3a3028", collar="#6a8a9a", coat=True),
}


def human(key):
    c = PALETTES[key]
    m_top = mat(key + "_top", c["top"])
    m_top2 = mat(key + "_top_dark", c["top_dark"])
    m_legs = mat(key + "_legs", c["legs"])
    m_shoe = mat(key + "_shoes", c["shoes"], rough=0.7)
    m_skin = mat(key + "_skin", c["skin"], rough=0.8)
    m_hair = mat(key + "_hair", c["hair"])
    m_col = mat(key + "_collar", c["collar"])
    m_eye = mat("eye_dark", "#1a1614")

    hips = Part("Hips", loc=(0, 0, 0.95))
    hips.box((0.33, 0.2, 0.2), (0, 0, -0.03), m_legs, bevel=0.02)
    hips.box((0.34, 0.21, 0.035), (0, 0, 0.065), m_shoe)

    torso = Part("Torso", hips, (0, 0, 0.06))
    torso.box((0.34, 0.2, 0.48), (0, 0, 0.24), m_top, bevel=0.025, taper=(1.18, 1.08))
    torso.box((0.025, 0.01, 0.38), (0, -0.112, 0.22), m_top2)           # zipper
    torso.box((0.36, 0.215, 0.07), (0, 0, 0.035), m_top2, bevel=0.01)   # jacket hem
    torso.box((0.22, 0.17, 0.06), (0, 0.0, 0.48), m_col, bevel=0.015)   # collar
    torso.box((0.09, 0.012, 0.07), (0.09, -0.11, 0.12), m_top2)         # pockets
    torso.box((0.09, 0.012, 0.07), (-0.09, -0.11, 0.12), m_top2)

    head = Part("Head", torso, (0, 0, 0.48))
    head.cyl(0.05, 0.09, (0, 0, 0.04), m_skin, seg=8)
    head.sphere(0.1, (0, 0, 0.17), m_skin, scale=(0.95, 1.05, 1.15), seg=12, rings=8)
    head.sphere(0.108, (0, 0.02, 0.215), m_hair, scale=(1.0, 1.05, 0.72), seg=12, rings=7)
    head.box((0.19, 0.07, 0.12), (0, 0.075, 0.17), m_hair, bevel=0.02)  # back of the head
    head.box((0.026, 0.01, 0.014), (0.036, -0.1, 0.185), m_eye)
    head.box((0.026, 0.01, 0.014), (-0.036, -0.1, 0.185), m_eye)
    head.box((0.024, 0.03, 0.042), (0, -0.106, 0.158), m_skin)          # nose
    head.box((0.02, 0.03, 0.045), (0.098, 0, 0.17), m_skin)             # ears
    head.box((0.02, 0.03, 0.045), (-0.098, 0, 0.17), m_skin)
    zombie = key.startswith("zombie")
    blood = mat("blood", "#4a0e0a", rough=0.5)
    if zombie:
        torso.box((0.12, 0.012, 0.1), (0.05, -0.112, 0.3), blood)
        torso.box((0.07, 0.012, 0.14), (-0.08, -0.113, 0.18), blood)
        head.box((0.05, 0.012, 0.03), (0.02, -0.106, 0.12), blood)
        head.box((0.03, 0.012, 0.012), (-0.035, -0.101, 0.185), mat("eye_white", "#c8c8b0"))
        head.box((0.03, 0.012, 0.012), (0.035, -0.101, 0.185), mat("eye_white", "#c8c8b0"))
    if c.get("vest"):
        torso.box((0.37, 0.215, 0.26), (0, 0, 0.3), m_top2, taper=(1.12, 1.05))
        torso.box((0.375, 0.218, 0.03), (0, 0, 0.26), mat("vest_reflect", "#d8d8c8"))
    if c.get("cap"):
        head.cyl(0.115, 0.06, (0, 0.0, 0.29), m_top, seg=12)
        head.cyl(0.12, 0.012, (0, 0.0, 0.32), m_top2, seg=12)
        head.box((0.16, 0.08, 0.01), (0, -0.1, 0.27), mat("cap_visor", "#111111"))
        head.box((0.13, 0.01, 0.02), (0, -0.112, 0.3), m_col)

    if c.get("helmet"):
        head.sphere(0.13, (0, 0.0, 0.26), mat("helmet_green", "#3e4a30", rough=0.6), scale=(1.0, 1.05, 0.65), seg=12, rings=6)
        head.cyl(0.14, 0.02, (0, 0, 0.23), mat("helmet_green", "#3e4a30", rough=0.6), seg=12)
        torso.box((0.38, 0.23, 0.3), (0, 0, 0.28), mat("vest_bulletproof", "#3a4230"), taper=(1.1, 1.05))
    if c.get("scarf"):
        sc = mat(key + "_scarf", c["scarf"])
        head.sphere(0.118, (0, 0.01, 0.2), sc, scale=(1.0, 1.05, 1.05), seg=12, rings=7)
        head.box((0.1, 0.06, 0.12), (0, 0.1, 0.07), sc, rot=(0.4, 0, 0))
        head.box((0.12, 0.02, 0.12), (0, -0.098, 0.175), m_skin)
    if c.get("skirt"):
        hips.box((0.4, 0.28, 0.5), (0, 0, -0.25), m_top2, taper=(1.25, 1.2))
    if c.get("coat"):
        torso.box((0.37, 0.22, 0.5), (0, 0, 0.22), m_top, taper=(1.15, 1.06))
        hips.box((0.38, 0.23, 0.4), (0, 0, -0.18), m_top, taper=(1.05, 1.0))
        torso.box((0.07, 0.012, 0.09), (0.1, -0.12, 0.34), mat("badge_red", "#a83a2a"))
        torso.box((0.1, 0.01, 0.16), (-0.08, -0.115, 0.1), blood)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        arm = Part("Arm" + side, torso, (0.225 * sx, 0, 0.44))
        arm.sphere(0.066, (0, 0, -0.01), m_top, seg=8, rings=6)
        arm.cyl(0.05, 0.30, (0, 0, -0.15), m_top, seg=8, r2=0.062)
        fore = Part("Forearm" + side, arm, (0, 0, -0.30))
        fore.cyl(0.043, 0.25, (0, 0, -0.125), m_top, seg=8, r2=0.051)
        fore.cyl(0.047, 0.035, (0, 0, -0.235), m_top2, seg=8)
        fore.box((0.055, 0.085, 0.1), (0, -0.008, -0.305), m_skin, bevel=0.015)
        leg = Part("Leg" + side, hips, (0.095 * sx, 0, -0.06))
        leg.cyl(0.066, 0.44, (0, 0, -0.22), m_legs, seg=8, r2=0.082)
        shin = Part("Shin" + side, leg, (0, 0, -0.44))
        shin.cyl(0.05, 0.38, (0, 0, -0.19), m_legs, seg=8, r2=0.064)
        shin.box((0.1, 0.25, 0.08), (0, -0.045, -0.41), m_shoe, bevel=0.02)
        shin.box((0.104, 0.254, 0.02), (0, -0.045, -0.44), mat("sole", "#4a4440"))


def run(keys):
    out = []
    for k in keys:
        rzlib.reset()
        human(k)
        out.append(rzlib.export("assets/characters/%s.glb" % k))
    return out


result = {"exported": run(sys.argv[1:] or ["player"])}
