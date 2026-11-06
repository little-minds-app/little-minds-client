#!/usr/bin/env python3
"""Generate stylized preschool animal vocalization cues (PCM WAV).

Short (~0.4–0.9 s) recognizable gestures — pure synthesis, not field realism.
Commercial-safe: no third-party samples, no recorded animals.

Outputs under `apps/mobile/assets/audio/animal_sound_matching/animals/`.

Usage:
  python3 scripts/generate_animal_sound_matching_animals.py
"""

from __future__ import annotations

import hashlib
import math
import wave
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "apps/mobile/assets/audio/animal_sound_matching/animals"


def write_wav(path: Path, samples: np.ndarray) -> None:
    pcm = np.clip(samples * 32767.0, -32767, 32767).astype(np.int16)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def env_length(dur: float) -> tuple[int, np.ndarray]:
    n = max(1, int(SR * dur))
    t = np.linspace(0.0, 1.0, n, dtype=np.float64)
    # Smooth fade in/out for preschool-friendly tails
    return n, np.sin(math.pi * t) ** 1.35


def normalize_peak(x: np.ndarray, peak: float = 0.92) -> np.ndarray:
    m = float(np.max(np.abs(x))) or 1.0
    return (x / m) * peak


def cat_meow() -> np.ndarray:
    """Two-part meowish glide: mid squeak then softer fall."""
    dur = 0.58
    n, ev = env_length(dur)
    t = np.arange(n) / SR
    # Pitch glides down then slight up-tail
    f0 = 680.0 * np.exp(-2.1 * t / dur) + 220.0
    phase = np.cumsum(2 * math.pi * f0 / SR)
    sig = 0.55 * np.sin(phase) + 0.18 * np.sin(2 * phase)
    sig *= ev
    return normalize_peak(sig)


def dog_woof() -> np.ndarray:
    """Short damped bursts — cartoon bark."""
    rng = np.random.default_rng(seed=42)
    dur = 0.42
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Three energy lumps
    env = (
        np.exp(-((t - 0.035) ** 2) / (2 * 0.012**2))
        + 0.55 * np.exp(-((t - 0.13) ** 2) / (2 * 0.014**2))
        + 0.35 * np.exp(-((t - 0.24) ** 2) / (2 * 0.016**2))
    )
    noise = rng.standard_normal(n).astype(np.float64)
    lp = 0.0
    out = np.zeros(n, dtype=np.float64)
    fc = 420.0 + 180.0 * np.exp(-t * 9.0)
    for i in range(n):
        a = math.exp(-2 * math.pi * fc[i] / SR)
        lp = a * lp + (1 - a) * noise[i]
        out[i] = lp
    carrier = np.sin(2 * math.pi * 155.0 * t)
    sig = 0.62 * out * carrier + 0.22 * np.sin(2 * math.pi * 210.0 * t) * env
    sig *= env
    return normalize_peak(sig)


def cow_moo() -> np.ndarray:
    """Low hum with gentle vibrato."""
    dur = 0.78
    n = int(SR * dur)
    t = np.arange(n) / SR
    vib = 1.0 + 0.045 * np.sin(2 * math.pi * 4.2 * t)
    f0 = 98.0 * vib
    phase = np.cumsum(2 * math.pi * f0 / SR)
    sig = 0.6 * np.sin(phase) + 0.25 * np.sin(2 * phase)
    env = 0.5 * (1 - np.cos(math.pi * t / dur))
    env *= np.exp(-0.65 * t / dur)
    sig *= env
    return normalize_peak(sig)


def duck_quack() -> np.ndarray:
    """Band-limited pulse with downward chirp."""
    dur = 0.52
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 340.0 * np.exp(-4.0 * t / dur) + 160.0
    phase = np.cumsum(2 * math.pi * f / SR)
    buzz = np.sign(np.sin(phase)) * 0.85 + 0.15 * np.sin(phase)
    env = np.exp(-((t - 0.06) ** 2) / (2 * 0.04**2)) + 0.35 * np.exp(
        -((t - 0.18) ** 2) / (2 * 0.055**2)
    )
    return normalize_peak(buzz * env * 0.75)


def bird_chirp() -> np.ndarray:
    """Quick bright chirplets."""
    dur = 0.48
    n = int(SR * dur)
    out = np.zeros(n, dtype=np.float64)
    starts = [0.02, 0.11, 0.22]
    for s in starts:
        i0 = int(s * SR)
        seg_n = int(0.045 * SR)
        if i0 + seg_n > n:
            continue
        tt = np.arange(seg_n) / SR
        f0 = 2600.0 + 350.0 * s
        ph = np.cumsum(2 * math.pi * (f0 + 1200.0 * tt / (seg_n / SR)) / SR)
        env = np.exp(-tt * 95.0)
        out[i0 : i0 + seg_n] += 0.42 * np.sin(ph) * env
    return normalize_peak(out)


def sheep_baa() -> np.ndarray:
    """Narrow buzz with waver."""
    dur = 0.68
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 265.0 + 18.0 * np.sin(2 * math.pi * 5.0 * t)
    phase = np.cumsum(2 * math.pi * f / SR)
    saw = 2 * (t * f % 1.0) - 1.0
    soft = 0.55 * np.sin(phase) + 0.35 * saw * np.exp(-t * 6.0)
    env = np.sin(math.pi * np.minimum(t / 0.15, 1.0)) * np.exp(-1.1 * t / dur)
    return normalize_peak(soft * env)


def frog_croak() -> np.ndarray:
    """Rough descending chirp."""
    dur = 0.55
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = 190.0 * np.exp(-2.8 * t / dur) + 85.0
    phase = np.cumsum(2 * math.pi * f0 / SR)
    rough = np.sin(phase) + 0.4 * np.sin(2 * phase + 1.1 * np.sin(phase * 0.5))
    env = np.exp(-((t - 0.04) ** 2) / (2 * 0.03**2)) * np.exp(-0.9 * t / dur)
    env += 0.25 * np.exp(-((t - 0.15) ** 2) / (2 * 0.05**2))
    return normalize_peak(rough * env)


def horse_neigh() -> np.ndarray:
    """Whistle-like slide with flutter."""
    dur = 0.86
    n = int(SR * dur)
    t = np.arange(n) / SR
    rise = 0.18
    f0 = 520.0 + 980.0 * np.minimum(t / rise, 1.0) ** 0.55
    f0 = f0 * (1.0 + 0.03 * np.sin(2 * math.pi * 8.0 * t))
    phase = np.cumsum(2 * math.pi * f0 / SR)
    sig = 0.45 * np.sin(phase) + 0.2 * np.sin(2 * phase)
    env = np.clip(np.sin(math.pi * t / dur) ** 1.2, 0.0, 1.0) * np.exp(-0.55 * t / dur)
    return normalize_peak(sig * env)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def write_provenance(files: dict[str, Path]) -> None:
    rows = []
    for label, p in sorted(files.items()):
        digest = sha256_file(p)
        rows.append(f"| `{p.name}` | {label} | `{digest}` |")

    table = "\n".join(rows)
    text = f"""# Animal Sound Matching — animal cue provenance

Short, stylized preschool recognition cues. **Original digital synthesis only**
(algorithmic waveforms — not field recordings, not third-party samples).
**Not intended as biologically accurate animal recordings.**

| File | Description | SHA-256 |
|------|-------------|---------|
{table}

Commercial-safe for Little Minds product use.
Regenerate:

```bash
python3 scripts/generate_animal_sound_matching_animals.py
```
"""
    (OUT / "PROVENANCE.md").write_text(text, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    gens = {
        "Stylized meow glide (two-part sine FM contour)": (OUT / "cat.wav", cat_meow),
        "Cartoon bark (filtered noise bursts)": (OUT / "dog.wav", dog_woof),
        "Low moo hum with slow vibrato": (OUT / "cow.wav", cow_moo),
        "Quackish down-chirp on pulses": (OUT / "duck.wav", duck_quack),
        "Bright chirplets (short rising glides)": (OUT / "bird.wav", bird_chirp),
        "Buzzing baa with pitch waver": (OUT / "sheep.wav", sheep_baa),
        "Croak — rough descending chirp": (OUT / "frog.wav", frog_croak),
        "Neigh-ish whistle slide with flutter": (OUT / "horse.wav", horse_neigh),
    }

    written: dict[str, Path] = {}
    for desc, (path, gen) in gens.items():
        write_wav(path, gen())
        written[desc] = path
        with wave.open(str(path)) as w:
            dur = w.getnframes() / w.getframerate()
        print(f"{path.name:10} {dur:.3f}s  {path.stat().st_size:7} B")

    write_provenance(written)
    print(f"Wrote {OUT / 'PROVENANCE.md'}")


if __name__ == "__main__":
    main()
