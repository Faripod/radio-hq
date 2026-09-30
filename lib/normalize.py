#!/usr/bin/env python3
# Bring a mono 16-bit WAV to the same peak as the rest of the kit, so no effect is much louder than another.
# Usage: normalize.py in.wav out.wav
import struct, sys, wave

PEAK = 0.89

src, dst = sys.argv[1], sys.argv[2]
with wave.open(src) as w:
    rate, n = w.getframerate(), w.getnframes()
    samples = struct.unpack('<%dh' % n, w.readframes(n))
gain = PEAK * 32767 / (max(abs(x) for x in samples) or 1)
with wave.open(dst, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(struct.pack('<%dh' % n, *[max(-32768, min(32767, round(x * gain))) for x in samples]))
