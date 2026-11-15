"""Pixel-art tileable textures (32 px per metre) for walls, floors and ground.

Run with any Python that has numpy (Blender's bundled one works):
  "<blender>/5.2/python/bin/python.exe" tools/textures/gen_textures.py
Writes PNGs to assets/textures/.
"""
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)


def write_png(name, img):
    img = np.clip(img, 0, 255).astype(np.uint8)
    h, w, c = img.shape
    ct = {3: 2, 4: 6}[c]
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(data)


def tnoise(w, h, cells, seed, octaves=3):
    """Tileable value noise in [0,1]."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cx, cy = cells * 2 ** o, max(1, int(cells * 2 ** o * h / w))
        grid = rng.random((cy, cx))
        ys = np.arange(h) * cy / h
        xs = np.arange(w) * cx / w
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        y1 = (y0 + 1) % cy
        x1 = (x0 + 1) % cx
        a = grid[y0][:, x0]
        b = grid[y0][:, x1]
        c = grid[y1][:, x0]
        d = grid[y1][:, x1]
        out += amp * (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)
        total += amp
        amp *= 0.5
    return out / total


def white(w, h, seed):
    return np.random.default_rng(seed).random((h, w))


def col(hexs):
    h = hexs.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def shade(base, f):
    """base colour (3,) * factor map (h,w) -> (h,w,3)"""
    return base[None, None, :] * f[:, :, None]


def quantize(img, step=6):
    return np.round(img / step) * step


# ---------------------------------------------------------------- exterior panel (3.0m x 2.8m)
def panel():
    w, h = 96, 90
    n = tnoise(w, h, 4, 1) * 0.12 + white(w, h, 2) * 0.06
    f = 0.88 + n
    streak = tnoise(w, 1, 12, 3, 2)[0]
    vert = np.clip((streak - 0.55) * 3, 0, 1)[None, :] * np.linspace(0.0, 0.12, h)[:, None]
    f -= vert
    img = shade(col("#a39d90"), f)
    seam = col("#5f5a52")
    img[0:2, :, :] = seam
    img[:, 0:2, :] = seam
    img[2, :, :] *= 0.9
    img[:, 2, :] *= 0.92
    write_png("panel", quantize(img))


def brick_white():
    w, h = 64, 64
    img = shade(col("#c9c2b2"), 0.92 + tnoise(w, h, 8, 5) * 0.1 + white(w, h, 6) * 0.05)
    for y in range(0, h, 3):
        img[y, :, :] = col("#8f887c")
        off = 4 if (y // 3) % 2 else 0
        for x in range(off, w, 8):
            img[y:y + 3, x, :] = col("#8f887c")
    write_png("brick_white", quantize(img))


def wallpaper(name, kind, seed):
    w, h = 32, 32
    f = 0.9 + tnoise(w, h, 4, seed) * 0.06
    img = shade(np.array([235.0, 235, 235]), f)
    if kind == "stripes":
        for x in range(0, w, 8):
            img[:, x:x + 2, :] *= 0.86
        for y in range(4, h, 8):
            for x in range(4, w, 8):
                img[y, x, :] *= 0.8
                img[y - 1, x, :] *= 0.88
                img[y + 1, x, :] *= 0.88
    elif kind == "flowers":
        for (cy, cx) in ((4, 4), (20, 20), (4, 20), (20, 4), (12, 12), (28, 12), (12, 28), (28, 28)):
            for dy, dx in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                img[(cy + dy) % h, (cx + dx) % w, :] *= 0.78 if (dy or dx) else 0.65
    elif kind == "damask":
        for y in range(h):
            for x in range(w):
                u, v = (x % 16) - 8, (y % 16) - 8
                if abs(abs(u) + abs(v) - 6) < 0.8:
                    img[y, x, :] *= 0.84
    age = np.clip(tnoise(w, h, 2, seed + 9) - 0.6, 0, 1) * 0.4
    img *= (1 - age)[:, :, None]
    write_png(name, quantize(img, 4))


def tile_wall():
    w, h = 40, 40
    img = shade(col("#d8dcd8"), 0.95 + white(w, h, 8) * 0.05)
    rng = np.random.default_rng(9)
    for ty in range(5):
        for tx in range(5):
            img[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8, :] *= 0.94 + rng.random() * 0.08
    img[0::8, :, :] = col("#9a9c98")
    img[:, 0::8, :] = col("#9a9c98")
    write_png("tile_wall", quantize(img, 4))


def linoleum():
    w, h = 64, 64
    base = col("#8a6a4a")
    f = 0.9 + tnoise(w, h, 4, 10) * 0.1
    img = shade(base, f)
    for y in range(h):
        for x in range(w):
            u, v = x % 16, y % 16
            if u in (0, 15) or v in (0, 15):
                img[y, x, :] *= 0.86
            elif 5 <= u <= 10 and 5 <= v <= 10:
                img[y, x, :] = img[y, x, :] * 0.6 + col("#a8885a") * 0.4
    wear = np.clip(tnoise(w, h, 3, 11) - 0.55, 0, 1) * 0.6
    img = img * (1 - wear[:, :, None]) + col("#b09a7a")[None, None, :] * wear[:, :, None]
    write_png("linoleum", quantize(img))


def parquet():
    w, h = 64, 64
    img = np.zeros((h, w, 3))
    rng = np.random.default_rng(12)
    for row in range(0, h, 4):
        x = int(rng.integers(0, 16))
        while x < w + 16:
            ln = int(rng.integers(14, 26))
            c = col("#7a5634") * (0.82 + rng.random() * 0.3)
            for xx in range(x, x + ln):
                img[row:row + 4, xx % w, :] = c
            img[row:row + 4, x % w, :] *= 0.7
            x += ln
        img[row, :, :] *= 0.75
    img *= (0.92 + tnoise(w, h, 8, 13) * 0.12)[:, :, None]
    write_png("parquet", quantize(img))


def floor_tile():
    w, h = 32, 32
    img = np.zeros((h, w, 3))
    for ty in range(4):
        for tx in range(4):
            c = col("#8a6450") if (tx + ty) % 2 else col("#c0b090")
            img[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8, :] = c
    img *= (0.9 + white(w, h, 14) * 0.1 + tnoise(w, h, 4, 15) * 0.06)[:, :, None]
    img[0::8, :, :] *= 0.8
    img[:, 0::8, :] *= 0.8
    write_png("floor_tile", quantize(img))


def concrete():
    w, h = 64, 64
    f = 0.82 + tnoise(w, h, 6, 16) * 0.16 + white(w, h, 17) * 0.06
    img = shade(col("#9a978e"), f)
    sp = white(w, h, 18) > 0.97
    img[sp] *= 0.8
    write_png("concrete", quantize(img))


def plaster():
    w, h = 32, 32
    f = 0.9 + tnoise(w, h, 4, 19) * 0.08 + white(w, h, 20) * 0.04
    write_png("plaster", quantize(shade(np.array([236.0, 234, 228]), f), 4))


def asphalt(name, base, seed, cracks=True):
    w, h = 128, 128
    f = 0.85 + tnoise(w, h, 8, seed) * 0.16 + white(w, h, seed + 1) * 0.1
    img = shade(col(base), f)
    rng = np.random.default_rng(seed + 2)
    patch = tnoise(w, h, 3, seed + 3) > 0.68
    img[patch] *= 0.85
    if cracks:
        for _ in range(7):
            x, y = rng.integers(0, w), rng.integers(0, h)
            ang = rng.random() * 6.28
            for _s in range(int(rng.integers(20, 60))):
                ang += rng.normal() * 0.5
                x = (x + np.cos(ang)) % w
                y = (y + np.sin(ang)) % h
                img[int(y), int(x), :] *= 0.55
    write_png(name, quantize(img))


def pavement():
    w, h = 64, 64
    img = shade(col("#a09d94"), 0.86 + tnoise(w, h, 6, 30) * 0.12 + white(w, h, 31) * 0.06)
    rng = np.random.default_rng(32)
    for ty in range(4):
        for tx in range(4):
            img[ty * 16:ty * 16 + 16, tx * 16:tx * 16 + 16, :] *= 0.93 + rng.random() * 0.1
    img[0::16, :, :] *= 0.7
    img[:, 0::16, :] *= 0.7
    write_png("pavement", quantize(img))


def grass():
    w, h = 128, 128
    n = tnoise(w, h, 6, 40)
    base = col("#5e6a3c") * (1 - n[:, :, None] * 0) if False else None
    # September grass: smooth blend of greens and straw (no hard patches), blade speckle, a few worn spots.
    c1, c2, c3 = col("#5a663a"), col("#666e40"), col("#787648")
    t = tnoise(w, h, 4, 41)
    k1 = np.clip((t - 0.35) / 0.3, 0, 1)[:, :, None]
    img = c1[None, None, :] * (1 - k1) + c2[None, None, :] * k1
    k2 = np.clip((tnoise(w, h, 7, 44) - 0.6) / 0.25, 0, 1)[:, :, None] * 0.6
    img = img * (1 - k2) + c3[None, None, :] * k2
    blades = white(w, h, 42)
    tufts = (white(w, h, 45) > 0.93)[:, :, None]
    img = img * (0.88 + blades[:, :, None] * 0.18)
    img = np.where(tufts, img * 0.78, img)
    dirt = tnoise(w, h, 3, 43) > 0.8
    img[dirt] = img[dirt] * 0.55 + col("#6e5e44") * 0.45
    write_png("grass", quantize(img))


def dirt():
    w, h = 64, 64
    f = 0.82 + tnoise(w, h, 6, 50) * 0.18 + white(w, h, 51) * 0.08
    img = shade(col("#6e5e46"), f)
    pebble = white(w, h, 52) > 0.95
    img[pebble] = col("#8a8478")
    write_png("dirt", quantize(img))


def sand():
    w, h = 64, 64
    f = 0.86 + tnoise(w, h, 6, 55) * 0.12 + white(w, h, 56) * 0.08
    img = shade(col("#b8a47e"), f)
    img[white(w, h, 57) > 0.96] *= 0.8
    write_png("sand", quantize(img))


def roof():
    w, h = 64, 64
    img = shade(col("#3a3836"), 0.85 + tnoise(w, h, 6, 60) * 0.2 + white(w, h, 61) * 0.06)
    img[0::32, :, :] *= 0.75
    write_png("roof", quantize(img, 4))


def grime():
    w, h = 64, 64
    f = 0.86 + tnoise(w, h, 4, 70) * 0.1 + white(w, h, 71) * 0.06
    write_png("grime", quantize(np.repeat(f[:, :, None] * 255, 3, axis=2), 3))


def carpet():
    """Classic red wall rug, 64 x 45 px for 2.0 x 1.4 m."""
    w, h = 64, 45
    red, dark, cream, blue = col("#8a2e26"), col("#4a1a18"), col("#c8b48a"), col("#2e3a5a")
    img = np.zeros((h, w, 3)) + red
    yy, xx = np.mgrid[0:h, 0:w]
    border = (xx < 4) | (xx >= w - 4) | (yy < 4) | (yy >= h - 4)
    img[border] = dark
    inner = (xx == 5) | (xx == w - 6) | (yy == 5) | (yy == h - 6)
    img[inner & ~border] = cream
    u = np.abs(xx - w / 2) / (w / 2 - 6)
    v = np.abs(yy - h / 2) / (h / 2 - 6)
    med = (u + v) < 0.55
    img[med & ~border] = blue
    img[((u + v) > 0.5) & ((u + v) < 0.58) & ~border] = cream
    pat = ((xx + yy) % 6 == 0) & ~med & ~border & ~inner
    img[pat] = img[pat] * 0.75 + cream * 0.25
    img[(xx % 4 == 2) & (yy < 4) & (yy > 0)] = cream
    img[(xx % 4 == 2) & (yy >= h - 4) & (yy < h - 1)] = cream
    img *= (0.9 + white(w, h, 80) * 0.1)[:, :, None]
    write_png("carpet", quantize(img, 4))


def leafmask():
    """RGBA: rgb = leaf colour variation (grey), a = coverage."""
    w, h = 32, 32
    n = tnoise(w, h, 6, 90, 2) * 0.6 + white(w, h, 91) * 0.4
    a = (n > 0.42).astype(float) * 255
    g = (0.75 + tnoise(w, h, 8, 92, 2) * 0.3 + white(w, h, 93) * 0.1) * 255
    img = np.stack([g, g, g, a], axis=2)
    write_png("leafmask", img)


for fn in (panel, brick_white, tile_wall, linoleum, parquet, floor_tile, concrete, plaster, pavement, grass, dirt,
           roof, grime, carpet, leafmask, sand):
    fn()
wallpaper("wallpaper_a", "stripes", 100)
wallpaper("wallpaper_b", "flowers", 101)
wallpaper("wallpaper_c", "damask", 102)
asphalt("asphalt", "#4a4a48", 20)
asphalt("asphalt_light", "#6a6862", 25, cracks=True)
print("textures written to", os.path.abspath(OUT))

# ---------------------------------------------------------------- v0.4: private sector, roads, ruins
def logs():
    """Horizontal log wall (сруб): 0.25 m logs, dark gaps of moss/caulk, weathered grey-brown."""
    w, h = 64, 64
    img = np.zeros((h, w, 3))
    base = col("#6e5a44")
    n = tnoise(w, h, 6, 200) * 0.18 + white(w, h, 201) * 0.06
    yy = np.arange(h)[:, None] % 8
    roundness = 1.0 - np.abs(yy - 3.5) / 3.5 * 0.35
    img = shade(base, (0.75 + n) * roundness)
    gap = (yy == 7) | (yy == 0)
    img[np.broadcast_to(gap, (h, w))] = col("#3a3226")
    grain = (tnoise(w, h, 24, 202, 1) > 0.62) & ~np.broadcast_to(gap, (h, w))
    img[grain] *= 0.88
    # Log ends every 2 m (a joint).
    img[:, 0, :] *= 0.8
    write_png("logs", quantize(img))


def planks():
    """Vertical weathered boards (sheds, fences, gables)."""
    w, h = 32, 64
    img = shade(col("#7a7266"), 0.8 + tnoise(w, h, 6, 210) * 0.2 + white(w, h, 211) * 0.08)
    for x in range(0, w, 6):
        img[:, x, :] = col("#3e3a34")
        img[:, (x + 1) % w, :] *= 0.85
    for x0 in range(0, w, 6):
        shift = (x0 * 7) % h
        img[shift:shift + 1, x0 + 2:x0 + 5, :] *= 0.7
    write_png("planks", quantize(img))


def tin_roof():
    """Corrugated sheet roof, grey with rust stains (tinted per house)."""
    w, h = 64, 64
    xx = np.arange(w)[None, :]
    rib = 0.8 + 0.2 * np.cos(xx / 4.0 * np.pi * 2) ** 2
    img = shade(col("#b8b8b0"), np.broadcast_to(rib, (h, w)) * (0.9 + tnoise(w, h, 4, 220) * 0.1))
    rust = (tnoise(w, h, 9, 221) > 0.74) & (np.arange(h)[:, None] % 32 > 20)
    img[rust] = img[rust] * 0.5 + col("#8a4a2a") * 0.5
    img[0::32, :, :] *= 0.7
    write_png("tin_roof", quantize(img))


def wood_floor():
    w, h = 64, 64
    img = shade(col("#8a6a48"), 0.82 + tnoise(w, h, 5, 230) * 0.14 + white(w, h, 231) * 0.06)
    for y in range(0, h, 6):
        img[y, :, :] = col("#4a3624")
    img[:, ::32, :] *= 0.85
    write_png("wood_floor", quantize(img))


def gravel():
    w, h = 64, 64
    f = 0.8 + tnoise(w, h, 7, 240) * 0.16 + white(w, h, 241) * 0.12
    img = shade(col("#7a7062"), f)
    img[white(w, h, 242) > 0.9] = col("#9a958a")
    img[white(w, h, 243) > 0.95] = col("#4a443a")
    rut = (np.abs(np.arange(w) - 16) < 3) | (np.abs(np.arange(w) - 48) < 3)
    img[:, rut, :] *= 0.82
    write_png("gravel", quantize(img))


def rust_metal():
    w, h = 64, 64
    img = shade(col("#7a5a44"), 0.75 + tnoise(w, h, 6, 250) * 0.3 + white(w, h, 251) * 0.08)
    img[tnoise(w, h, 8, 252) > 0.6] = col("#5a3a28")
    write_png("rust_metal", quantize(img))


def soot():
    """Burned walls and wrecks."""
    w, h = 64, 64
    img = shade(col("#2a2624"), 0.7 + tnoise(w, h, 5, 260) * 0.5 + white(w, h, 261) * 0.1)
    img[tnoise(w, h, 9, 262) > 0.7] = col("#6a5a4a")
    write_png("soot", quantize(img, 4))


for fn in (logs, planks, tin_roof, wood_floor, gravel, rust_metal, soot):
    fn()


# ---------------------------------------------------------------- v0.4 polish: ground detail and decals
def grass_tuft():
    """RGBA blades for grass/weed clumps: grey value for tinting, alpha = blade coverage (32x24 px)."""
    w, h = 48, 32
    img = np.zeros((h, w, 4))
    rng = np.random.default_rng(300)
    for b in range(26):
        x0 = rng.uniform(2, w - 3)
        hgt = rng.uniform(h * 0.45, h * 0.98)
        lean = rng.uniform(-6, 6)
        shade_v = rng.uniform(0.7, 1.05)
        for y in range(int(hgt)):
            k = y / hgt
            x = int(round(x0 + lean * k * k))
            if 0 <= x < w:
                yy = h - 1 - y
                img[yy, x, :3] = 255 * shade_v * (0.75 + 0.35 * k)
                img[yy, x, 3] = 255
                if k < 0.35 and x + 1 < w:
                    img[yy, x + 1, :3] = 255 * shade_v * 0.7
                    img[yy, x + 1, 3] = 255
    write_png("grass_tuft", img)


def decal_set():
    """Ground decals (RGBA): cracks, oil stain, damp stain, fallen leaves, scattered paper."""
    rng = np.random.default_rng(310)
    w = h = 64
    # Cracks: random walk lines.
    img = np.zeros((h, w, 4))
    for k in range(3):
        x, y = rng.uniform(10, 54), rng.uniform(10, 54)
        ang = rng.uniform(0, 6.28)
        for i in range(60):
            ang += rng.normal(0, 0.35)
            x += np.cos(ang)
            y += np.sin(ang)
            xi, yi = int(x) % w, int(y) % h
            img[yi, xi] = [25, 23, 20, 230]
            if rng.random() < 0.1:
                ang += rng.choice([-1.2, 1.2])
    write_png("decal_crack", img)
    # Oil stain: soft dark blob with a rim.
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - 32, yy - 32) / 30 + tnoise(w, h, 4, 311) * 0.5
    a = np.clip((1.0 - r) * 2.5, 0, 1)
    img = np.zeros((h, w, 4))
    img[..., :3] = [18, 18, 20]
    img[..., 3] = a * 200
    write_png("decal_oil", img)
    # Damp / dirt stain.
    a = np.clip((1.0 - np.hypot(xx - 32, yy - 32) / 31 - tnoise(w, h, 5, 312) * 0.6) * 2.0, 0, 1)
    img = np.zeros((h, w, 4))
    img[..., :3] = [60, 52, 40]
    img[..., 3] = a * 150
    write_png("decal_stain", img)
    # Fallen leaves: small yellow/orange/brown flecks.
    img = np.zeros((h, w, 4))
    cols = [(196, 150, 56), (170, 96, 40), (120, 80, 40), (150, 130, 60), (190, 120, 50)]
    for i in range(70):
        cx, cy = rng.integers(2, w - 3), rng.integers(2, h - 3)
        if np.hypot(cx - 32, cy - 32) > 30 + rng.uniform(-4, 2):
            continue
        c = cols[rng.integers(0, len(cols))]
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1) if rng.random() < 0.5 else (0, 0)):
            img[cy + dy, cx + dx] = [c[0], c[1], c[2], 255]
    write_png("decal_leaves", img)
    # Scattered paper sheets.
    img = np.zeros((h, w, 4))
    for i in range(6):
        cx, cy = rng.integers(8, 56), rng.integers(8, 56)
        sw, sh = rng.integers(3, 7), rng.integers(4, 8)
        tone = rng.uniform(190, 225)
        img[cy:cy + sh, cx:cx + sw] = [tone, tone * 0.97, tone * 0.9, 255]
        img[cy + 1:cy + sh - 1:2, cx + 1:cx + sw - 1] = [tone * 0.55, tone * 0.55, tone * 0.55, 255]
    write_png("decal_paper", img)


grass_tuft()
decal_set()
