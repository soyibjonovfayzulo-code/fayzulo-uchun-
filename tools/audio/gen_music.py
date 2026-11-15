"""Main menu theme: a slow, cold ambient loop (minor pads, wind, a lonely detuned piano), ~48 s, seamless.
  "<blender>/5.2/python/bin/python.exe" tools/audio/gen_music.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(77)
L = 48.0
N = int(SR * L)
t = np.arange(N) / SR


def lowpass(x, cutoff):
    # Vectorised one-pole via cumulative trick is unstable; use blocked loop (fast enough at 22 kHz).
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def note(f):
    return 440.0 * 2 ** ((f - 69) / 12.0)


# Chords (MIDI): Am, F, C, Em — 12 s each.
chords = [[45, 57, 60, 64], [41, 53, 57, 60], [48, 55, 60, 64], [40, 52, 55, 59]]
pad = np.zeros(N)
seg = N // len(chords)
for ci, ch in enumerate(chords):
    s0 = ci * seg
    n = seg + SR * 3  # overlap for crossfade
    tt = np.arange(n) / SR
    env = np.clip(tt / 3.5, 0, 1) * np.clip((n / SR - tt) / 3.5, 0, 1)
    sig = np.zeros(n)
    for m in ch:
        f = note(m)
        for det in (-0.12, 0.0, 0.13):
            ph = 2 * np.pi * f * (1 + det / 100.0) * tt
            sig += (np.sin(ph) + 0.35 * np.sin(2 * ph + 0.3) + 0.15 * np.sin(3 * ph)) * 0.25
    sig *= env * (0.85 + 0.15 * np.sin(2 * np.pi * 0.07 * tt))
    end = min(s0 + n, N)
    pad[s0:end] += sig[:end - s0]
    if s0 + n > N:
        pad[:s0 + n - N] += sig[end - s0:]
pad = lowpass(pad, 900)

wind = lowpass(rng.standard_normal(N), 350) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 16.0) ** 2) * 1.6

# Sparse piano: decaying partials, slightly out of tune, with echoes.
piano = np.zeros(N)
melody = [(2.0, 76), (5.5, 72), (9.0, 74), (14.5, 72), (18.0, 69), (23.5, 71), (26.0, 67), (31.0, 69),
          (35.5, 72), (39.0, 71), (43.0, 64)]
for at, m in melody:
    f = note(m) * (1 + rng.uniform(-0.003, 0.003))
    n = int(SR * 4.0)
    tt = np.arange(n) / SR
    tone = sum(np.sin(2 * np.pi * f * k * tt) * np.exp(-tt * (1.2 + k * 0.9)) / k for k in (1, 2, 3, 4))
    tone *= np.clip(tt / 0.004, 0, 1)
    s0 = int(SR * at)
    for d, g in ((0.0, 1.0), (0.37, 0.35), (0.81, 0.18), (1.4, 0.08)):
        a = (s0 + int(SR * d)) % N
        seg2 = tone * g
        e = min(a + n, N)
        piano[a:e] += seg2[:e - a]
        if a + n > N:
            piano[:a + n - N] += seg2[e - a:]

mix = pad * 0.55 + wind * 0.25 + piano * 0.32
# Gentle fade at the loop seam.
f = int(SR * 1.5)
r = np.linspace(0, 1, f)
mix[:f] = mix[:f] * r + mix[-f:] * (1 - r)
mix = mix[:-f]
mix = mix / (np.max(np.abs(mix)) or 1) * 0.7
with wave.open(os.path.join(OUT, "menu_theme.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print("menu_theme.wav", len(mix) / SR, "s")
