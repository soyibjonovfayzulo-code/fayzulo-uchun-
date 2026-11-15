"""Procedural sound effects (mono 22050 Hz WAV) for the prototype. Run with Blender's bundled Python:
  "<blender>/5.2/python/bin/python.exe" tools/audio/gen_sounds.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1)


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
    a = np.clip(tt / max(attack, 1e-4), 0, 1)
    return a * np.exp(-tt / max(decay, 1e-4))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(sec):
    return rng.standard_normal(int(SR * sec))


# Footsteps --------------------------------------------------------------------------------
for i in range(1, 5):
    n = noise(0.16)
    x = lowpass(n, 900 + i * 120) * env(len(n), 0.002, 0.03) + lowpass(noise(0.16), 3000) * env(len(n), 0.001, 0.008) * 0.4
    save("step_concrete_%d" % i, x, 0.55)
    g = highpass(noise(0.22), 1500) * env(int(SR * 0.22), 0.01, 0.06) + lowpass(noise(0.22), 600) * env(int(SR * 0.22), 0.004, 0.03)
    save("step_grass_%d" % i, g, 0.4)
    f = lowpass(noise(0.18), 500 + i * 60) * env(int(SR * 0.18), 0.002, 0.04)
    tt = t(0.18)
    f += np.sin(2 * np.pi * (90 + i * 7) * tt) * env(len(tt), 0.002, 0.03) * 0.5
    save("step_floor_%d" % i, f, 0.55)

# Door creak / close / locked --------------------------------------------------------------
tt = t(0.75)
freq = 180 + 90 * np.sin(2 * np.pi * 2.2 * tt) + 40 * np.sin(2 * np.pi * 7.0 * tt)
phase = np.cumsum(2 * np.pi * freq / SR)
creak = (np.sign(np.sin(phase)) * 0.4 + np.sin(phase * 2.01) * 0.3) * np.clip(np.sin(np.pi * tt / 0.75), 0, 1) ** 0.6
creak = lowpass(creak, 2200) + lowpass(noise(0.75), 1200) * 0.05
save("door_open", creak, 0.5)
tt = t(0.35)
thud = np.sin(2 * np.pi * 70 * tt) * env(len(tt), 0.002, 0.08) + lowpass(noise(0.35), 1500) * env(len(tt), 0.001, 0.03)
save("door_close", thud, 0.8)
lk = np.zeros(int(SR * 0.45))
for k in range(4):
    s = int(SR * (0.02 + k * 0.09))
    c = highpass(noise(0.03), 1800) * env(int(SR * 0.03), 0.001, 0.008)
    lk[s:s + len(c)] += c
save("door_locked", lk, 0.6)

# Window / glass -------------------------------------------------------------------------------
w = lowpass(noise(0.4), 700) * np.clip(np.sin(np.pi * t(0.4) / 0.4), 0, 1)
save("window_open", w, 0.5)
gl = highpass(noise(1.2), 2500) * env(int(SR * 1.2), 0.001, 0.25)
for k in range(40):
    s = int(rng.uniform(0, 0.9) * SR)
    f0 = rng.uniform(2500, 7000)
    tt = t(0.12)
    ping = np.sin(2 * np.pi * f0 * tt) * env(len(tt), 0.0005, 0.03) * rng.uniform(0.2, 0.8)
    gl[s:s + len(ping)] += ping
gl[:int(SR * 0.08)] += lowpass(noise(0.08), 800) * env(int(SR * 0.08), 0.001, 0.03) * 2
save("glass_break", gl, 0.9)
cl = np.zeros(int(SR * 0.6))
for k in range(6):
    s = int(rng.uniform(0, 0.5) * SR)
    tt = t(0.05)
    p = np.sin(2 * np.pi * rng.uniform(3000, 6000) * tt) * env(len(tt), 0.0005, 0.015)
    cl[s:s + len(p)] += p
save("glass_clear", cl, 0.4)

# Furniture ------------------------------------------------------------------------------------
tt = t(0.3)
ph = np.cumsum(2 * np.pi * (300 + 120 * tt) / SR)
save("cabinet_open", lowpass(np.sign(np.sin(ph)) * np.clip(np.sin(np.pi * tt / 0.3), 0, 1), 1800) * 0.6
     + lowpass(noise(0.3), 900) * env(len(tt), 0.005, 0.1), 0.45)
save("drawer", lowpass(noise(0.35), 500) * np.clip(np.sin(np.pi * t(0.35) / 0.35), 0, 1), 0.45)
save("tv_click", highpass(noise(0.05), 1500) * env(int(SR * 0.05), 0.0005, 0.01), 0.5)
save("tv_static", highpass(noise(1.6), 800) * 0.6 + lowpass(noise(1.6), 3000) * 0.4, 0.25)

# Body / combat --------------------------------------------------------------------------------
tt = t(0.3)
sw = highpass(noise(0.3), 600) * np.sin(np.pi * tt / 0.3) ** 2
save("swing", lowpass(sw, 2500), 0.4)
save("thud", np.sin(2 * np.pi * 55 * t(0.4)) * env(int(SR * 0.4), 0.002, 0.12) + lowpass(noise(0.4), 600) * env(int(SR * 0.4), 0.001, 0.05), 0.9)
tt = t(0.4)
hurt = (np.sin(2 * np.pi * (220 - 80 * tt) * tt) + 0.3 * np.sin(2 * np.pi * (440 - 160 * tt) * tt)) * env(len(tt), 0.02, 0.15)
save("hurt", lowpass(hurt + lowpass(noise(0.4), 1200) * 0.2 * env(len(tt), 0.01, 0.1), 2000), 0.5)
save("climb", lowpass(noise(0.9), 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * t(0.9))) * np.sin(np.pi * t(0.9) / 0.9), 0.45)

# Ambience: wind bed with gusts and distant city hum (seamless loop by cross-fade) --------------
L = 12.0
n = noise(L + 1.0)
wind = lowpass(n, 380)
gust = 0.55 + 0.45 * np.sin(2 * np.pi * t(L + 1.0) / 6.0) * np.sin(2 * np.pi * t(L + 1.0) / 2.3 + 1.0)
wind = wind * gust + highpass(lowpass(noise(L + 1.0), 2500), 900) * 0.05 * gust
fade = int(SR * 1.0)
loop = wind[:int(SR * L)].copy()
ramp = np.linspace(0, 1, fade)
loop[:fade] = loop[:fade] * ramp + wind[int(SR * L):int(SR * L) + fade] * (1 - ramp)
save("wind_loop", loop, 0.6)
print("sounds written to", os.path.abspath(OUT))

# ---------------------------------------------------------------------------------------- M4-M6
def reson(x, f, q=8.0):
    """Two-pole resonator (formant filter)."""
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


def voice(sec, f0, f0_end, formants, rough=0.4, seed=0):
    tt = t(sec)
    lr = np.random.default_rng(seed)
    f = np.linspace(f0, f0_end, len(tt)) * (1 + 0.06 * np.sin(2 * np.pi * 5.5 * tt) + 0.03 * lr.standard_normal(len(tt)).cumsum() / np.sqrt(len(tt)))
    ph = np.cumsum(2 * np.pi * f / SR)
    src = (ph / np.pi % 2 - 1) + lowpass(lr.standard_normal(len(tt)), 3000) * rough
    out = sum(reson(src, fr, 6) * g for fr, g in formants)
    return out * np.clip(np.sin(np.pi * tt / sec), 0, 1) ** 0.5


for i in range(1, 5):
    g = voice(1.1 + i * 0.15, 95 + i * 12, 70 + i * 8, [(450 + i * 40, 1.0), (1100 - i * 60, 0.6), (2500, 0.2)], 0.6, i)
    save("zombie_groan_%d" % i, lowpass(g, 2600), 0.55)
save("zombie_alert", lowpass(voice(0.9, 170, 120, [(600, 1.0), (1500, 0.7), (2700, 0.3)], 0.9, 9), 3500), 0.7)
save("zombie_attack", lowpass(voice(0.5, 210, 140, [(700, 1.0), (1700, 0.8)], 1.0, 11), 4000), 0.75)
save("zombie_hurt", lowpass(voice(0.35, 160, 110, [(520, 1.0), (1300, 0.5)], 0.8, 12), 3000), 0.6)
save("zombie_die", lowpass(voice(1.0, 120, 60, [(400, 1.0), (1000, 0.5)], 0.7, 13), 2200), 0.6)
tt = t(0.45)
save("body_fall", np.sin(2 * np.pi * 50 * tt) * env(len(tt), 0.003, 0.12) + lowpass(noise(0.45), 500) * env(len(tt), 0.002, 0.06), 0.9)
tt = t(0.25)
save("hit_blunt", np.sin(2 * np.pi * 90 * tt) * env(len(tt), 0.001, 0.05) + lowpass(noise(0.25), 1600) * env(len(tt), 0.001, 0.04) * 1.5, 0.9)
save("hit_sharp", highpass(noise(0.2), 1500) * env(int(SR * 0.2), 0.001, 0.03) + lowpass(noise(0.2), 700) * env(int(SR * 0.2), 0.002, 0.05), 0.8)
tt = t(0.9)
shot = lowpass(noise(0.9), 3500) * env(len(tt), 0.0005, 0.06) * 2 + lowpass(noise(0.9), 400) * env(len(tt), 0.001, 0.35) + np.sin(2 * np.pi * 60 * tt) * env(len(tt), 0.001, 0.1)
save("gunshot", shot, 1.0)
save("gun_empty", highpass(noise(0.05), 2000) * env(int(SR * 0.05), 0.0005, 0.008), 0.5)
rl = np.zeros(int(SR * 0.6))
for k, at in enumerate((0.05, 0.3, 0.45)):
    c = highpass(noise(0.05), 1200) * env(int(SR * 0.05), 0.0005, 0.012)
    s0 = int(SR * at)
    rl[s0:s0 + len(c)] += c * (1.0 if k else 0.7)
save("gun_reload", rl, 0.6)
save("weapon_break", lowpass(noise(0.4), 2500) * env(int(SR * 0.4), 0.001, 0.08) + highpass(noise(0.4), 3000) * env(int(SR * 0.4), 0.001, 0.02), 0.8)
tt = t(0.45)
bang = np.sin(2 * np.pi * 65 * tt) * env(len(tt), 0.002, 0.1) + lowpass(noise(0.45), 1200) * env(len(tt), 0.001, 0.05) * 1.4
save("door_bang", bang, 0.9)
tt = t(1.1)
brk = lowpass(noise(1.1), 1800) * env(len(tt), 0.002, 0.25) + np.sin(2 * np.pi * 45 * tt) * env(len(tt), 0.002, 0.2)
for k in range(8):
    s0 = int(rng.uniform(0.05, 0.7) * SR)
    c = highpass(noise(0.06), 1500) * env(int(SR * 0.06), 0.001, 0.02)
    brk[s0:s0 + len(c)] += c * 0.6
save("door_break", brk, 1.0)
tt = t(0.5)
save("eat", lowpass(noise(0.5), 1400) * (np.sin(2 * np.pi * 7 * tt) > 0.3) * np.sin(np.pi * tt / 0.5), 0.4)
tt = t(0.8)
save("drink", lowpass(noise(0.8), 600) * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * tt)) * np.sin(np.pi * tt / 0.8), 0.4)
save("pickup", lowpass(noise(0.15), 2000) * env(int(SR * 0.15), 0.002, 0.04), 0.5)
# Two-tone siren, seamless 2 s loop.
tt = t(2.0)
fs = np.where((tt % 1.0) < 0.5, 950.0, 720.0)
alarm = np.sign(np.sin(np.cumsum(2 * np.pi * fs / SR))) * 0.6 + np.sin(np.cumsum(2 * np.pi * fs * 2 / SR)) * 0.2
save("car_alarm", lowpass(alarm, 3000), 0.5)
print("M4-M6 sounds written")

