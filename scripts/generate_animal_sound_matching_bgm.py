#!/usr/bin/env python3
"""Generate original "Animal Garden" Animal Sound Matching BGM (seamless loop).

Commercial-safe preschool instrumental: warm marimba / xylophone / soft piano.
Pure synthesis only — no vocals, no third-party samples, no copyrighted music.

Distinct from "Colorful Orchard" (Color Sorting): 98 BPM, G–Em–C–D loop,
different melody contour.

Target: ~98 BPM, ~57.6 s seamless loop, compressed MP3 for audioplayers
(iOS AVPlayer + Android ExoPlayer compatible).

Usage:
  python3 scripts/generate_animal_sound_matching_bgm.py
"""

from __future__ import annotations

import hashlib
import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 98.0
BEAT = 60.0 / BPM
BARS = 24
DURATION = BARS * 4 * BEAT
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "apps/mobile/assets/audio/animal_sound_matching/bgm"
STEM = "animal_garden_loop"


def midi_hz(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    env = np.zeros(n, dtype=np.float64)
    if n == 0:
        return env
    a_n = max(1, int(a * n))
    d_n = max(1, int(d * n))
    r_n = max(1, int(r * n))
    sustain_n = max(0, n - a_n - d_n - r_n)
    i = 0
    env[i : i + a_n] = np.linspace(0.0, 1.0, a_n, endpoint=False)
    i += a_n
    env[i : i + d_n] = np.linspace(1.0, s, d_n, endpoint=False)
    i += d_n
    if sustain_n:
        env[i : i + sustain_n] = s
        i += sustain_n
    rem = n - i
    if rem > 0:
        env[i:] = np.linspace(s, 0.0, rem)
    return env


def marimba(freq: float, dur: float, amp: float = 0.28) -> np.ndarray:
    """Bright wooden-bar strike: inharmonic partials + fast decay."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    partials = (
        1.00 * np.sin(2 * math.pi * freq * t),
        0.42 * np.sin(2 * math.pi * freq * 4.02 * t),
        0.17 * np.sin(2 * math.pi * freq * 9.05 * t),
        0.07 * np.sin(2 * math.pi * freq * 13.9 * t),
    )
    sig = sum(partials)
    env = adsr(n, a=0.007, d=0.19, s=0.21, r=0.54)
    return amp * env * sig * np.exp(-1.55 * t / max(dur, 1e-6))


def soft_piano(freq: float, dur: float, amp: float = 0.16) -> np.ndarray:
    """Gentle felt-piano pad note for harmonic warmth."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = (
        np.sin(2 * math.pi * freq * t)
        + 0.33 * np.sin(2 * math.pi * freq * 2 * t)
        + 0.11 * np.sin(2 * math.pi * freq * 3 * t)
        + 0.055 * np.sin(2 * math.pi * freq * 4.02 * t)
    )
    env = adsr(n, a=0.042, d=0.23, s=0.44, r=0.36)
    return amp * env * sig * np.exp(-0.52 * t / max(dur, 1e-6))


def xylo_tick(freq: float, dur: float, amp: float = 0.12) -> np.ndarray:
    """Light xylophone sparkle."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.sin(2 * math.pi * freq * t) + 0.22 * np.sin(
        2 * math.pi * freq * 2.84 * t
    )
    env = adsr(n, a=0.002, d=0.11, s=0.075, r=0.72)
    return amp * env * sig * np.exp(-3.0 * t / max(dur, 1e-6))


def place(buf: np.ndarray, start: float, clip: np.ndarray) -> None:
    i0 = int(start * SR)
    i1 = min(len(buf), i0 + len(clip))
    if i0 >= len(buf) or i0 < 0:
        return
    buf[i0:i1] += clip[: i1 - i0]


# Animal Garden: G major loop — G, Em, C, D (distinct from Colorful Orchard).
CHORD_TONICS = [67, 64, 60, 62]
PENTATONIC = [0, 2, 4, 7, 9]


def chord_third_semitones(bar_idx: int) -> int:
    """G and Em and C and D: only Em needs a minor third in this loop."""
    return 3 if (bar_idx % 4) == 1 else 4


# 16-beat melody phrase (different contour / rhythm from Colorful Orchard)
MELODY_PHRASE = [
    (0.0, 4, 0.75),
    (0.75, 2, 0.5),
    (1.25, 0, 1.0),
    (2.25, 4, 0.5),
    (2.75, 3, 0.5),
    (3.25, 4, 1.0),
    (4.25, 1, 0.5),
    (4.75, 2, 0.5),
    (5.25, 4, 1.0),
    (6.25, 0, 0.5),
    (6.75, 1, 0.5),
    (7.25, 2, 1.0),
    (8.25, 3, 0.5),
    (8.75, 4, 0.5),
    (9.25, 2, 1.0),
    (10.25, 0, 1.0),
    (11.25, 4, 1.0),
    (12.25, 2, 0.5),
    (12.75, 4, 0.5),
    (13.25, 3, 1.0),
    (14.25, 1, 0.5),
    (14.75, 0, 0.5),
    (15.25, 2, 0.75),
]


def build() -> np.ndarray:
    n = int(round(DURATION * SR))
    buf = np.zeros(n, dtype=np.float64)

    for bar in range(BARS):
        chord = CHORD_TONICS[bar % 4]
        t0 = bar * 4 * BEAT
        third = chord_third_semitones(bar)
        for midi, amp in (
            (chord - 12, 0.095),
            (chord, 0.13),
            (chord + third, 0.10),
            (chord + 7, 0.085),
        ):
            place(buf, t0, soft_piano(midi_hz(midi), dur=3.5 * BEAT, amp=amp))

        for beat_off, deg in ((0.0, 1), (1.0, 3), (2.0, 0), (3.0, 4)):
            midi = chord + PENTATONIC[deg % len(PENTATONIC)]
            place(
                buf,
                t0 + beat_off * BEAT,
                marimba(midi_hz(midi + 12), dur=1.35 * BEAT, amp=0.19),
            )

    phrase_len_beats = 16.0
    phrase_count = int((BARS * 4) / phrase_len_beats)
    for p in range(phrase_count):
        base = p * phrase_len_beats * BEAT
        chord_for = CHORD_TONICS[(p * 4) % 4]
        for beat_off, deg, dur_beats in MELODY_PHRASE:
            midi = 72 + PENTATONIC[deg] + (0 if p % 2 == 0 else -12)
            if deg in (0, 2, 4):
                midi = chord_for + 12 + PENTATONIC[deg]
            place(
                buf,
                base + beat_off * BEAT,
                marimba(midi_hz(midi), dur=dur_beats * BEAT * 1.12, amp=0.25),
            )
            if deg in (1, 3, 4):
                place(
                    buf,
                    base + beat_off * BEAT + 0.07,
                    xylo_tick(
                        midi_hz(midi + 12),
                        dur=0.5 * BEAT,
                        amp=0.068,
                    ),
                )

    t = np.arange(n) / SR
    hum = 0.032 * np.sin(2 * math.pi * midi_hz(43) * t)  # G1 — garden floor
    hum *= 0.5 + 0.5 * np.sin(2 * math.pi * (1.0 / (BARS * 4 * BEAT)) * t)
    buf += hum

    fade = int(0.080 * SR)
    if fade * 2 < n:
        w_out = np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
        w_in = np.sin(np.linspace(0, math.pi / 2, fade)) ** 2
        head = buf[:fade].copy()
        tail = buf[-fade:].copy()
        buf[-fade:] = tail * w_out + head * w_in
        buf[:fade] = head * w_in + tail * w_out

    peak = float(np.max(np.abs(buf))) or 1.0
    buf *= 0.88 / peak
    return buf


def write_wav(path: Path, samples: np.ndarray) -> None:
    pcm = np.clip(samples * 32767.0, -32767, 32767).astype(np.int16)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def encode_mp3(wav_path: Path, mp3_path: Path) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(wav_path),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "160k",
            "-ar",
            "44100",
            "-ac",
            "1",
            str(mp3_path),
        ],
        check=True,
        capture_output=True,
    )


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def write_provenance(mp3_path: Path, digest: str, duration: float) -> None:
    text = f"""# Animal Garden BGM — provenance

| Field | Value |
|-------|-------|
| Title | Animal Garden (Animal Sound Matching loop) |
| File | `{mp3_path.name}` |
| Generator | `scripts/generate_animal_sound_matching_bgm.py` |
| Method | Original programmatic synthesis (numpy additive / marimba + soft piano + xylo) |
| Tempo | {BPM:.0f} BPM |
| Duration | {duration:.2f} s seamless loop |
| Sample rate | {SR} Hz mono |
| Codec | MPEG-1 Audio Layer III (MP3), 160 kbps CBR via ffmpeg libmp3lame |
| SHA-256 | `{digest}` |
| Vocals | None |
| Third-party samples | None |
| Copyrighted music | None — original composition synthesized for Little Minds |
| License intent | Original work for Little Minds product use |
| Compatible player | Flutter `audioplayers` AssetSource (iOS + Android) |

Regenerate:
```bash
python3 scripts/generate_animal_sound_matching_bgm.py
```
"""
    (mp3_path.parent / "PROVENANCE.md").write_text(text, encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    samples = build()
    duration = len(samples) / SR
    mp3_path = OUT_DIR / f"{STEM}.mp3"

    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / f"{STEM}.wav"
        write_wav(wav_path, samples)
        encode_mp3(wav_path, mp3_path)

    digest = sha256(mp3_path)
    write_provenance(mp3_path, digest, duration)
    size = mp3_path.stat().st_size
    print(f"Wrote {mp3_path} ({size} bytes, {duration:.2f}s, sha256={digest})")
    print(f"Wrote {OUT_DIR / 'PROVENANCE.md'}")


if __name__ == "__main__":
    main()
