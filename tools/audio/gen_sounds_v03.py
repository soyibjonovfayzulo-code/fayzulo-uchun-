"""v0.3 survival & atmosphere sounds (mono 22050 Hz WAV). Run with Blender's bundled Python:
  "<blender>/5.2/python/bin/python.exe" tools/audio/gen_sounds_v03.py
Rain, thunder, campfire, boiling pot, heartbeat, crows, dogs, distant gunfire and screams, the
air-raid siren, the power going out, coughing, a match strike and tap water.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(33)


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, decay=0.1):
    tt = np.arange(n) / SR
    return np.clip(tt / max(attack, 1e-4), 0, 1) * np.exp(-tt / max(decay, 1e-4))


def lowpass(x, cutoff, passes=1):
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(passes):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def echo(x, delays=((0.11, 0.35), (0.23, 0.22), (0.41, 0.12)), tail=0.0):
    out = np.concatenate([x, np.zeros(int(SR * (max(d for d, _ in delays) + tail)))])
    for d, g in delays:
        s0 = int(SR * d)
        out[s0:s0 + len(x)] += x * g
    return out


def seamless(x, fade_sec=0.4):
    """Crossfade the tail into the head so the clip loops without a click."""
    f = int(SR * fade_sec)
    body = x[:-f].copy()
    ramp = np.linspace(0, 1, f)
    body[:f] = body[:f] * ramp + x[-f:] * (1 - ramp)
    return body


def reson(x, f, q=8.0):
    w = 2 * np.pi * f / SR
    r = 1 - w / (2 * q)
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y0 = v - a1 * y1 - a2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y * (1 - r)


def voice(sec, f0s, formants, rough=0.4, seed=0, q=6):
    tt = t(sec)
    lr = np.random.default_rng(seed)
    f = np.interp(tt, np.linspace(0, sec, len(f0s)), f0s) * (1 + 0.02 * lr.standard_normal(len(tt)).cumsum() / np.sqrt(len(tt)))
    ph = np.cumsum(2 * np.pi * f / SR)
    src = (ph / np.pi % 2 - 1) + lowpass(lr.standard_normal(len(tt)), 4000) * rough
    return sum(reson(src, fr, q) * g for fr, g in formants)


# Rain: a dense hiss with droplet ticks and a soft rumble, seamless 6 s loop.
L = 6.4
hiss = bandpass(noise(L), 900, 5500) * 0.8 + lowpass(noise(L), 260) * 0.5
drops = np.zeros(int(SR * L))
for k in range(900):
    s0 = int(rng.uniform(0, L - 0.02) * SR)
    c = highpass(rng.standard_normal(int(SR * 0.006)), 2500) * env(int(SR * 0.006), 0.0003, 0.0015)
    drops[s0:s0 + len(c)] += c * rng.uniform(0.2, 1.0)
rain = hiss * (0.85 + 0.15 * np.sin(2 * np.pi * 0.31 * t(L))) + drops * 0.35
save("rain_loop", seamless(rain, 0.4), 0.55)

# Thunder: a crack then a long rolling rumble.
tt = t(5.0)
rumble = lowpass(noise(5.0), 140, 2) * (np.exp(-tt / 1.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.9 * tt) ** 2))
crack = lowpass(noise(5.0), 1800) * env(len(tt), 0.002, 0.12)
save("thunder", rumble * 3.0 + crack * 0.6, 0.9)

# Campfire: low roar plus random crackles and pops, seamless 4 s loop.
L = 4.4
roar = lowpass(noise(L), 320, 2) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t(L)))
crk = np.zeros(int(SR * L))
for k in range(130):
    s0 = int(rng.uniform(0, L - 0.05) * SR)
    n = int(SR * rng.uniform(0.003, 0.02))
    c = highpass(rng.standard_normal(n), 1200) * env(n, 0.0002, n / SR / 4)
    crk[s0:s0 + n] += c * rng.uniform(0.2, 1.0) ** 2
save("fire_loop", seamless(roar * 1.6 + crk * 0.8, 0.4), 0.6)

# Boiling pot: many small bubbles.
L = 3.0
bub = np.zeros(int(SR * L))
for k in range(220):
    s0 = int(rng.uniform(0, L - 0.05) * SR)
    n = int(SR * 0.03)
    f = rng.uniform(250, 700)
    tb = np.arange(n) / SR
    c = np.sin(2 * np.pi * f * (1 + 2.5 * tb / 0.03) * tb) * env(n, 0.001, 0.008)
    bub[s0:s0 + n] += c * rng.uniform(0.3, 1.0)
save("boil", bub * np.clip(t(L) / 0.6, 0, 1) * np.clip((L - t(L)) / 0.5, 0, 1) + lowpass(noise(L), 500) * 0.15, 0.55)

# Heartbeat: lub-dub.
hb = np.zeros(int(SR * 0.55))
for at, f, g in ((0.0, 52, 1.0), (0.17, 64, 0.7)):
    n = int(SR * 0.16)
    tb = np.arange(n) / SR
    s0 = int(SR * at)
    hb[s0:s0 + n] += np.sin(2 * np.pi * f * tb) * env(n, 0.004, 0.035) * g
save("heartbeat", lowpass(hb, 300), 0.9)

# Crows: three harsh caws with distance.
cw = np.zeros(int(SR * 1.9))
for k, at in enumerate((0.0, 0.55, 1.15)):
    v = voice(0.32, [780, 700, 560], [(1100, 1.0), (2100, 0.6), (3200, 0.25)], 1.4, 20 + k, q=4)
    v *= np.sin(np.pi * t(0.32) / 0.32) ** 0.6
    s0 = int(SR * at)
    cw[s0:s0 + len(v)] += v
save("crow", echo(lowpass(cw, 3200), ((0.18, 0.25), (0.4, 0.12))), 0.7)

# Dog barking far away (a yard dog on a chain).
db = np.zeros(int(SR * 1.6))
for k, at in enumerate((0.0, 0.32, 0.95)):
    v = voice(0.16, [380, 300, 220], [(700, 1.0), (1500, 0.5), (2600, 0.2)], 1.2, 40 + k, q=4)
    v *= env(len(v), 0.008, 0.06)
    s0 = int(SR * at)
    db[s0:s0 + len(v)] += v
save("dog_bark", echo(lowpass(db, 1800), ((0.14, 0.3), (0.31, 0.16)), 0.2), 0.6)

# Distant gunfire: muffled report with a slapback from the panel blocks.
tt = t(0.6)
shot = lowpass(noise(0.6), 700, 2) * env(len(tt), 0.001, 0.08) + np.sin(2 * np.pi * 45 * tt) * env(len(tt), 0.001, 0.12) * 0.4
save("distant_shot", echo(shot, ((0.25, 0.45), (0.52, 0.25), (0.9, 0.12)), 0.3), 0.7)

# Far scream.
sc = voice(1.4, [420, 680, 720, 520, 380], [(900, 1.0), (1800, 0.5), (2900, 0.2)], 0.5, 51)
sc *= np.sin(np.pi * t(1.4) / 1.4) ** 0.7
save("scream_far", echo(lowpass(sc, 1600), ((0.2, 0.3), (0.45, 0.15)), 0.3), 0.55)

# Air-raid siren: slow wail up and down, heard across the town.
L = 9.0
tt = t(L)
f = 280 + 420 * np.clip(np.sin(np.pi * tt / L) * 1.2, 0, 1)
ph = np.cumsum(2 * np.pi * f / SR)
sir = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
sir *= np.clip(tt / 1.0, 0, 1) * np.clip((L - tt) / 1.5, 0, 1)
save("siren", echo(lowpass(sir, 1400), ((0.3, 0.3), (0.7, 0.15)), 0.2), 0.45)

# Power going out: transformer hum winding down and a relay clunk.
tt = t(2.2)
f = 100 * np.exp(-tt / 0.9) + 20
ph = np.cumsum(2 * np.pi * f / SR)
hum = (np.sin(ph) + 0.5 * np.sin(2 * ph)) * np.exp(-tt / 1.1)
clk = lowpass(noise(2.2), 1500) * env(len(tt), 0.001, 0.03)
save("power_down", hum + clk * 1.5, 0.75)

# Cough (sickness, vomiting).
cg = np.zeros(int(SR * 0.9))
for k, at in enumerate((0.0, 0.38)):
    n = int(SR * 0.22)
    v = bandpass(rng.standard_normal(n), 300, 2200) * env(n, 0.004, 0.06)
    v += voice(0.22, [180, 150], [(600, 1.0), (1300, 0.5)], 2.0, 60 + k)[:n] * env(n, 0.004, 0.05) * 0.3
    s0 = int(SR * at)
    cg[s0:s0 + n] += v
save("cough", cg, 0.6)

# Match strike: scratch then a whoosh of flame.
tt = t(0.7)
scratch = highpass(noise(0.7), 2500) * env(len(tt), 0.001, 0.05)
whoosh = bandpass(noise(0.7), 300, 2000) * np.clip((tt - 0.06) / 0.05, 0, 1) * np.exp(-np.clip(tt - 0.06, 0, None) / 0.25)
save("match", scratch + whoosh * 0.8, 0.6)

# Tap water filling a bottle (pitch rises as it fills).
L = 2.6
tt = t(L)
stream = bandpass(noise(L), 600, 3500)
gl = np.sin(np.cumsum(2 * np.pi * (300 + 500 * tt / L) / SR)) * 0.15
save("tap_water", (stream + gl) * np.clip(tt / 0.1, 0, 1) * np.clip((L - tt) / 0.3, 0, 1), 0.5)
print("v0.3 sounds written to", os.path.abspath(OUT))
