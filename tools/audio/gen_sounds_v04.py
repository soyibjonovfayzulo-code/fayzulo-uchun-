"""v0.4 sounds: helicopter rotor, car engine (loop, start, failed start), horn, crash, hammering.
  "<blender>/5.2/python/bin/python.exe" tools/audio/gen_sounds_v04.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(44)


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    x = x / (np.max(np.abs(x)) or 1.0) * gain
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, attack=0.005, decay=0.1):
    tt = np.arange(n) / SR
    return np.clip(tt / max(attack, 1e-4), 0, 1) * np.exp(-tt / max(decay, 1e-4))


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def seamless(x, fade=0.3):
    f = int(SR * fade)
    body = x[:-f].copy()
    r = np.linspace(0, 1, f)
    body[:f] = body[:f] * r + x[-f:] * (1 - r)
    return body


# Helicopter: blade slap at ~11 Hz modulating turbine whine and low rumble, seamless.
L = 4.0
tt = t(L + 0.3)
slap = (0.5 + 0.5 * np.cos(2 * np.pi * 11.0 * tt)) ** 6
rumble = lowpass(noise(L + 0.3), 180)
whine = np.sin(2 * np.pi * 1450 * tt) * 0.04 + np.sin(2 * np.pi * 2900 * tt) * 0.02
heli = rumble * (0.35 + slap * 1.8) + lowpass(noise(L + 0.3), 1200) * slap * 0.5 + whine
save("helicopter_loop", seamless(heli), 0.8)

# Engine idle/revs loop: firing pulses at ~28 Hz (pitch is raised in game with speed).
L = 2.0
tt = t(L + 0.3)
f0 = 28.0
pulse = np.sin(2 * np.pi * f0 * tt) + 0.6 * np.sin(2 * np.pi * f0 * 2 * tt + 0.5) + 0.3 * np.sin(2 * np.pi * f0 * 3 * tt)
rough = lowpass(noise(L + 0.3), 600) * 0.35
eng = lowpass(pulse * (1 + 0.15 * np.sin(2 * np.pi * 3.0 * tt)) + rough, 1100)
save("engine_loop", seamless(eng), 0.6)

# Starter cranking then the engine catching.
tt = t(1.6)
crank = np.zeros_like(tt)
for k in range(7):
    s0 = int(SR * (0.05 + k * 0.11))
    n = int(SR * 0.08)
    crank[s0:s0 + n] += lowpass(rng.standard_normal(n), 900) * env(n, 0.003, 0.03)
catch = np.sin(2 * np.pi * 30 * tt) * np.clip((tt - 0.85) / 0.1, 0, 1) * (1 + 0.5 * np.sin(2 * np.pi * 6 * tt))
save("engine_start", crank + lowpass(catch + noise(1.6) * 0.2 * np.clip((tt - 0.85) / 0.1, 0, 1), 1000), 0.7)

# Failed start: cranking that dies.
tt = t(1.0)
fail = np.zeros_like(tt)
for k in range(6):
    s0 = int(SR * (0.05 + k * 0.14))
    n = int(SR * 0.09)
    fail[s0:s0 + n] += lowpass(rng.standard_normal(n), 800) * env(n, 0.003, 0.035) * (1 - k * 0.12)
save("engine_fail", fail, 0.6)

# Soviet car horn: two detuned square-ish tones.
tt = t(0.7)
h = np.sign(np.sin(2 * np.pi * 410 * tt)) * 0.5 + np.sign(np.sin(2 * np.pi * 515 * tt)) * 0.5
save("horn", lowpass(h, 2200) * np.clip(tt / 0.02, 0, 1) * np.clip((0.7 - tt) / 0.05, 0, 1), 0.6)

# Crash: metal crunch and glass.
tt = t(1.0)
crash = lowpass(noise(1.0), 1500) * env(len(tt), 0.001, 0.12) * 2 + np.sin(2 * np.pi * 55 * tt) * env(len(tt), 0.002, 0.15)
for k in range(10):
    s0 = int(rng.uniform(0.02, 0.6) * SR)
    n = int(SR * 0.04)
    crash[s0:s0 + n] += (rng.standard_normal(n) - lowpass(rng.standard_normal(n), 2500)) * env(n, 0.001, 0.01) * 0.6
save("car_crash", crash, 0.9)

# Hammering nails: three knocks.
hm = np.zeros(int(SR * 1.2))
for k, at in enumerate((0.0, 0.38, 0.76)):
    n = int(SR * 0.18)
    tb = np.arange(n) / SR
    knock = np.sin(2 * np.pi * 180 * tb) * env(n, 0.0005, 0.03) + lowpass(rng.standard_normal(n), 3000) * env(n, 0.0005, 0.01)
    s0 = int(SR * at)
    hm[s0:s0 + n] += knock
save("hammer", hm, 0.8)
print("v0.4 sounds written")
