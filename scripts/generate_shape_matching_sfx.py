#!/usr/bin/env python3
"""Generate original preschool-friendly Shape Matching SFX (PCM WAV).

Commercial-safe: pure synthesis only — no third-party samples, no voice,
no copyrighted music. Deterministic LCG noise for clap bursts.

Usage:
  python3 scripts/generate_shape_matching_sfx.py
"""

from __future__ import annotations

import hashlib
import math
import struct
import wave
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "apps/mobile/assets/audio/shape_matching/sfx"


def clamp(x: float) -> int:
    return max(-32767, min(32767, int(x)))


def write_wav(name: str, samples: list[float]) -> Path:
    path = OUT / name
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", clamp(s * 32767.0)) for s in samples)
        w.writeframes(frames)
    return path


def env_adsr(i: int, n: int, a=0.01, d=0.08, s=0.55, r=0.25) -> float:
    t = i / max(n - 1, 1)
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t < 1.0 - r:
        return s
    return s * max(0.0, (1.0 - t) / r)


def tone(
    freq: float,
    dur: float,
    amp=0.45,
    a=0.01,
    d=0.08,
    s=0.5,
    r=0.3,
) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        sig = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(
            4 * math.pi * freq * t
        )
        out.append(amp * env_adsr(i, n, a, d, s, r) * sig)
    return out


def noise_burst(dur: float, amp=0.35, bright=0.5) -> list[float]:
    n = int(SR * dur)
    out = []
    state = 0xA5A5_C0DE
    prev = 0.0
    for i in range(n):
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        white = ((state / 0xFFFFFFFF) * 2.0) - 1.0
        prev = prev * (1.0 - bright) + white * bright
        out.append(amp * env_adsr(i, n, 0.002, 0.05, 0.25, 0.55) * prev)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max((len(t) for t in tracks), default=0)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max((abs(v) for v in out), default=1.0) or 1.0
    if peak > 0.95:
        out = [v * (0.95 / peak) for v in out]
    return out


def concat(*parts: list[float], gap_ms: float = 0.0) -> list[float]:
    gap = [0.0] * int(SR * gap_ms / 1000.0)
    out: list[float] = []
    for i, p in enumerate(parts):
        if i:
            out.extend(gap)
        out.extend(p)
    return out


def pad(samples: list[float], lead_ms=0.0, trail_ms=20.0) -> list[float]:
    return (
        [0.0] * int(SR * lead_ms / 1000.0)
        + samples
        + [0.0] * int(SR * trail_ms / 1000.0)
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    tap = mix(
        tone(880, 0.045, amp=0.38, a=0.002, d=0.05, s=0.2, r=0.6),
        tone(1320, 0.03, amp=0.18, a=0.001, d=0.04, s=0.1, r=0.7),
    )
    write_wav("tap_pop.wav", pad(tap, trail_ms=30))

    bounce = concat(
        tone(320, 0.07, amp=0.32, a=0.005, d=0.08, s=0.25, r=0.55),
        tone(420, 0.05, amp=0.22, a=0.004, d=0.07, s=0.2, r=0.6),
        gap_ms=18,
    )
    write_wav("drag_bounce.wav", pad(bounce, trail_ms=40))

    chime = concat(
        tone(523.25, 0.14, amp=0.42, a=0.01, d=0.12, s=0.45, r=0.4),
        tone(659.25, 0.18, amp=0.40, a=0.01, d=0.12, s=0.4, r=0.45),
        gap_ms=55,
    )
    write_wav("correct_chime.wav", pad(chime, trail_ms=50))

    clap = concat(
        noise_burst(0.055, amp=0.42, bright=0.65),
        noise_burst(0.045, amp=0.28, bright=0.55),
        gap_ms=70,
    )
    write_wav("soft_clap.wav", pad(clap, trail_ms=40))

    wrong = concat(
        tone(392.0, 0.12, amp=0.28, a=0.015, d=0.1, s=0.35, r=0.45),
        tone(311.13, 0.16, amp=0.24, a=0.015, d=0.12, s=0.3, r=0.5),
        gap_ms=40,
    )
    write_wav("wrong_soft.wav", pad(wrong, trail_ms=50))

    jingle_core = concat(
        tone(523.25, 0.11, amp=0.38, a=0.01, d=0.1, s=0.4, r=0.4),
        tone(659.25, 0.11, amp=0.36, a=0.01, d=0.1, s=0.4, r=0.4),
        tone(783.99, 0.12, amp=0.36, a=0.01, d=0.1, s=0.4, r=0.4),
        tone(1046.5, 0.22, amp=0.40, a=0.01, d=0.12, s=0.35, r=0.5),
        gap_ms=45,
    )
    sparkle = mix(
        tone(1568.0, 0.08, amp=0.12, a=0.002, d=0.05, s=0.15, r=0.7),
        tone(2093.0, 0.06, amp=0.08, a=0.002, d=0.04, s=0.1, r=0.75),
    )
    jingle = mix(jingle_core, [0.0] * int(SR * 0.32) + sparkle)
    write_wav("complete_jingle.wav", pad(jingle, trail_ms=60))

    twinkle = concat(
        tone(1318.5, 0.05, amp=0.18, a=0.002, d=0.04, s=0.2, r=0.7),
        tone(1760.0, 0.06, amp=0.14, a=0.002, d=0.04, s=0.15, r=0.75),
        tone(2093.0, 0.05, amp=0.10, a=0.002, d=0.03, s=0.1, r=0.8),
        gap_ms=35,
    )
    write_wav("twinkle.wav", pad(twinkle, trail_ms=40))

    for p in sorted(OUT.glob("*.wav")):
        data = p.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        with wave.open(str(p)) as w:
            dur = w.getnframes() / w.getframerate()
        print(f"{p.name:22} {len(data):6}B  {dur:.3f}s  sha256={sha}")


if __name__ == "__main__":
    main()
