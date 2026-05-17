#!/usr/bin/env python3
"""Generate a clean 'ding' notification sound — two harmonically-related
sine waves (C6 + F6) with a quick attack and exponential decay."""
import math, wave, struct, sys

SAMPLE_RATE = 44100
DURATION    = 0.70   # seconds
F1, F2      = 1046.5, 1396.9   # C6, F6
DECAY       = 6.0    # higher = shorter ring

n_samples = int(SAMPLE_RATE * DURATION)
amp_peak  = 0.78     # leave a little headroom

samples = []
for i in range(n_samples):
    t = i / SAMPLE_RATE
    # Quick 5 ms attack, then exponential decay
    attack = min(t / 0.005, 1.0)
    env    = attack * math.exp(-DECAY * t)
    # F2 is quieter — gives a "bell" colour without sounding muddy
    s = math.sin(2 * math.pi * F1 * t) + 0.45 * math.sin(2 * math.pi * F2 * t)
    samples.append(int(amp_peak * env * (s / 1.45) * 32767))

out = sys.argv[1] if len(sys.argv) > 1 else 'ding.wav'
with wave.open(out, 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SAMPLE_RATE)
    w.writeframes(b''.join(struct.pack('<h', s) for s in samples))

print(f'Wrote {out} ({n_samples} samples, {DURATION:.2f}s)')
