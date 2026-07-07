#!/usr/bin/env python3
"""Synthesize Overlap's SFX as 16-bit mono WAVs (arcade/lo-fi character,
matches the flat-vector art; zero licensing). Deterministic — rerun any
time, tweak constants, commit the result:

    python3 tools/gen_sfx.py

Every *_loop sound is exactly LOOP_SECONDS long and seam-free (integer-Hz
partials, noise layers crossfaded), so the game sets WAV loop points at
runtime instead of relying on import metadata."""

import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
LOOP_SECONDS = 1.0
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
rng = random.Random(7)


def write_wav(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.82 / peak
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(
            struct.pack("<h", int(s * scale * 32767)) for s in samples))
    print(f"wrote {name} ({len(samples) / SR:.2f}s)")


def sine(freq: float, t: float) -> float:
    return math.sin(math.tau * freq * t)


def env_decay(t: float, tau: float) -> float:
    return math.exp(-t / tau)


def crossfade_loop(samples: list[float], fade: int) -> list[float]:
    """Blend the tail into the head so aperiodic layers loop seamlessly."""
    out = samples[:-fade]
    for i in range(fade):
        a = i / fade
        out[i] = samples[i] * a + samples[len(samples) - fade + i] * (1.0 - a)
    return out


def lowpass(samples: list[float], alpha: float) -> list[float]:
    out, acc = [], 0.0
    for s in samples:
        acc += alpha * (s - acc)
        out.append(acc)
    return out


def engine_loop() -> list[float]:
    # Harmonic stack on integer f0 → a whole number of periods per loop.
    f0 = 55
    out = []
    for i in range(int(SR * LOOP_SECONDS)):
        t = i / SR
        v = 0.0
        for n in range(1, 9):
            v += math.sin(math.tau * f0 * n * t + 0.7 * n) / n ** 1.15
        v += 0.5 * sine(28, t)  # sub rumble
        v *= 1.0 + 0.22 * sine(f0 / 5, t)  # slow chug
        out.append(v)
    return out


def drift_loop() -> list[float]:
    # Tonal squeal with 5 Hz vibrato (integer → loops) over band noise.
    # Human-tuned 2026-07-07: squeal dropped out of the ear's most
    # sensitive band (1150 → 950 Hz) and de-emphasized — it read as loud.
    n_total = int(SR * (LOOP_SECONDS + 0.15))
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n_total)], 0.35)
    deep = lowpass(noise, 0.04)
    band = [a - b for a, b in zip(noise, deep)]
    out = []
    phase = 0.0
    for i in range(n_total):
        t = i / SR
        phase += math.tau * (950 + 50 * sine(5, t)) / SR
        squeal = 0.6 * math.sin(phase) + 0.15 * math.sin(2.01 * phase)
        out.append(squeal * 0.35 + band[i] * 1.5)
    return crossfade_loop(out, int(0.15 * SR))


def offroad_loop() -> list[float]:
    # Brown-ish rumble: integrated white noise, DC-blocked, crossfaded.
    n_total = int(SR * (LOOP_SECONDS + 0.15))
    acc, prev, out = 0.0, 0.0, []
    for _ in range(n_total):
        acc += rng.uniform(-1, 1) * 0.08
        acc *= 0.997  # DC leak
        out.append(acc - prev * 0.95)
        prev = acc
    return crossfade_loop(lowpass(out, 0.25), int(0.15 * SR))


def splash() -> list[float]:
    out = []
    for i in range(int(SR * 0.6)):
        t = i / SR
        hiss = rng.uniform(-1, 1) * env_decay(t, 0.16)
        bloop = sine(500 * math.exp(-t * 6) + 110, t) * env_decay(t, 0.12)
        out.append(hiss * 0.7 + bloop * 0.8)
    return lowpass(out, 0.5)


def blips(notes: list[tuple[float, float, float]], length: float,
		shimmer: float = 0.0) -> list[float]:
    """notes: (freq, start, dur). Soft sine blips with optional sparkle."""
    out = []
    for i in range(int(SR * length)):
        t = i / SR
        v = 0.0
        for freq, start, dur in notes:
            if t < start:
                continue
            lt = t - start
            e = min(1.0, lt / 0.012) * env_decay(lt, dur)
            v += e * (sine(freq, lt) + shimmer * sine(freq * 2, lt)
                    + 0.15 * sine(freq * 3.01, lt))
        out.append(v)
    return out


def gate_open() -> list[float]:
    out = []
    for i in range(int(SR * 0.7)):
        t = i / SR
        thunk = sine(120 * math.exp(-t * 3), t) * env_decay(t, 0.1)
        rise = sine(180 + 540 * min(1.0, t / 0.5), t) * 0.4 \
                * min(1.0, t / 0.06) * env_decay(max(0.0, t - 0.45), 0.08)
        out.append(thunk + rise)
    return out


write_wav("engine_loop.wav", engine_loop())
write_wav("drift_loop.wav", drift_loop())
write_wav("offroad_loop.wav", offroad_loop())
write_wav("splash.wav", splash())
write_wav("click.wav", blips([(1800, 0.0, 0.02)], 0.06))
write_wav("purchase.wav", blips([(988, 0.0, 0.07), (1319, 0.09, 0.12)], 0.3, 0.3))
write_wav("gate_open.wav", gate_open())
write_wav("lap.wav", blips([(660, 0.0, 0.07)], 0.14))
write_wav("pb.wav", blips([(660, 0.0, 0.07), (990, 0.1, 0.12)], 0.32, 0.2))
write_wav("medal.wav", blips([(523, 0.0, 0.08), (659, 0.1, 0.08),
        (784, 0.2, 0.2), (1047, 0.32, 0.25)], 0.7, 0.25))
write_wav("discovery.wav", blips([(880, 0.0, 0.06), (1109, 0.07, 0.06),
        (1319, 0.14, 0.08), (1760, 0.22, 0.18)], 0.5, 0.35))
