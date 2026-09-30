#!/usr/bin/env python3
# Turn a mono 16-bit WAV of speech into a handheld-radio transmission:
# squelch open, band-limited overdriven voice over hiss, roger beep, squelch tail.
# Usage: radio.py in.wav out.wav
import math, random, struct, sys, wave

src, dst = sys.argv[1], sys.argv[2]
with wave.open(src) as w:
    rate = w.getframerate()
    voice = [x / 32768 for x in struct.unpack('<%dh' % w.getnframes(), w.readframes(w.getnframes()))]


def biquad(s, kind, f0, q=0.707):
    w0 = 2 * math.pi * f0 / rate
    a, c = math.sin(w0) / (2 * q), math.cos(w0)
    b = ((1 + c) / 2, -(1 + c), (1 + c) / 2) if kind == 'hp' else ((1 - c) / 2, 1 - c, (1 - c) / 2)
    a0, a1, a2 = 1 + a, -2 * c, 1 - a
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in s:
        y = (b[0] * x + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2) / a0
        out.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def noise(secs, amp):
    return [random.uniform(-amp, amp) for _ in range(int(secs * rate))]


def tone(freq, secs, amp=0.35):
    n = int(secs * rate)
    return [amp * math.sin(2 * math.pi * freq * i / rate) * min(1, i / 60, (n - i) / 60) for i in range(n)]


def squelch(secs, amp):
    s = biquad(noise(secs, amp), 'hp', 1800)
    n = len(s)
    return [x * (1 - i / n) ** 1.5 for i, x in enumerate(s)]


random.seed(3)
v = biquad(biquad(voice, 'hp', 380), 'lp', 2900)
peak = max(abs(x) for x in v) or 1.0
v = [math.tanh(2.6 * x / peak) * 0.75 for x in v]
v = [x + h for x, h in zip(v, biquad(noise(len(v) / rate, 0.06), 'hp', 900))]

out = (squelch(0.12, 0.55) + noise(0.05, 0.04) + v
       + tone(1200, 0.07) + [0.0] * int(0.03 * rate) + tone(1600, 0.09)
       + squelch(0.22, 0.5))

with wave.open(dst, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(struct.pack('<%dh' % len(out), *[int(max(-1.0, min(1.0, x)) * 32767) for x in out]))
