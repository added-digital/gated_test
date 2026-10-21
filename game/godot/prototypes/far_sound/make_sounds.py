"""Makes the two sounds of toy 3, Far sound, next to this file:

  chime.wav   20 s of soft wind-chime tones: decaying sines around 880, 1320
              and 1760 Hz struck at irregular intervals. It carries WAV loop
              points (a 'smpl' chunk) over its whole length, so Godot's
              importer ("Detect From WAV") loops it end to end; a tone that
              rings past the end wraps round to the start, so the seam is silent.
  chord.wav   one resolved chord (A major, 3 s), played once on arrival.

44.1 kHz, 16-bit mono, peaks at half scale: gentle, nothing clips.
Run:  python make_sounds.py      (needs numpy; the seed is fixed, so the
                                  same chime comes out every time)
"""
import struct
from pathlib import Path

import numpy as np

RATE = 44100
HERE = Path(__file__).resolve().parent
rng = np.random.default_rng(3)


def tone(freq, seconds, amp, decay):
    """A struck tube: a sine with a faint, faster-dying high partial, 5 ms attack."""
    t = np.arange(int(seconds * RATE)) / RATE
    env = np.exp(-t / decay) * np.minimum(1.0, t / 0.005)
    partial = 0.2 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.3))
    return amp * env * (np.sin(2 * np.pi * freq * t) + partial)


def add_wrapped(out, start, s):
    """Add s into out from start, wrapping past the end (the loop's seam)."""
    n = len(out)
    start %= n
    first = min(len(s), n - start)
    out[start:start + first] += s[:first]
    out[:len(s) - first] += s[first:]


def chime(seconds=20.0):
    out = np.zeros(int(seconds * RATE))
    t = 0.0
    strikes = 0
    while t < seconds:
        freq = rng.choice([880.0, 1320.0, 1760.0]) * (1 + rng.uniform(-0.004, 0.004))
        add_wrapped(out, int(t * RATE), tone(freq, 4.0, rng.uniform(0.12, 0.3), rng.uniform(0.5, 1.3)))
        strikes += 1
        t += 0.08 + rng.exponential(0.7)   # irregular gaps, never two strikes at once
    print(f"chime: {strikes} strikes in {seconds:.0f} s")
    return out


def chord(seconds=3.0):
    t = np.arange(int(seconds * RATE)) / RATE
    env = np.exp(-t / 1.1) * np.minimum(1.0, t / 0.03)
    out = np.zeros_like(t)
    for freq, amp in [(220.0, 1.0), (277.18, 0.8), (329.63, 0.8), (440.0, 0.6), (659.25, 0.25)]:
        out += amp * np.sin(2 * np.pi * freq * t)
    return env * out


def write_wav(path, samples, peak, loop):
    """16-bit mono WAV scaled so the loudest sample is `peak`; loop points over all of it if asked."""
    samples = samples / np.max(np.abs(samples)) * peak
    data = (samples * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt, b"data" + struct.pack("<I", len(data)) + data]
    if loop:
        header = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)   # one loop, no sampler data
        one_loop = struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)          # forward, start, end
        chunks.append(b"smpl" + struct.pack("<I", len(header) + len(one_loop)) + header + one_loop)
    body = b"WAVE" + b"".join(chunks)
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"{path.name}: {len(samples) / RATE:.1f} s, peak {np.max(np.abs(samples)):.2f}, loop {'yes' if loop else 'no'}")


write_wav(HERE / "chime.wav", chime(), 0.5, loop=True)
write_wav(HERE / "chord.wav", chord(), 0.5, loop=False)
