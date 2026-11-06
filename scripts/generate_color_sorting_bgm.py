#!/usr/bin/env python3
"""Generate original "Colorful Orchard" Color Sorting BGM (seamless loop).

Commercial-safe preschool instrumental: warm marimba / xylophone / soft piano.
Pure synthesis only — no vocals, no third-party samples, no copyrighted music.

Target: ~100 BPM, ~57.6 s seamless loop, compressed MP3 for audioplayers
(iOS AVPlayer + Android ExoPlayer compatible).

Usage:
  python3 scripts/generate_color_sorting_bgm.py
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
BPM = 104.0
BEAT = 60.0 / BPM  # 0.6 s
BARS = 24  # 24 bars * 4 beats = 57.6 s
DURATION = BARS * 4 * BEAT
ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "apps/mobile/assets/audio/color_sorting/bgm"
STEM = "colorful_orchard_loop"


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
    # Slight inharmonicity for wooden bar character.
    partials = (
        1.00 * np.sin(2 * math.pi * freq * t),
        0.45 * np.sin(2 * math.pi * freq * 3.99 * t),
        0.18 * np.sin(2 * math.pi * freq * 9.2 * t),
        0.08 * np.sin(2 * math.pi * freq * 14.1 * t),
    )
    sig = sum(partials)
    # Soft attack, quick bright decay — marimba-like.
    env = adsr(n, a=0.008, d=0.18, s=0.22, r=0.55)
    # Extra exponential decay on higher partials already baked via short sustain.
    return amp * env * sig * np.exp(-1.6 * t / max(dur, 1e-6))


def soft_piano(freq: float, dur: float, amp: float = 0.16) -> np.ndarray:
    """Gentle felt-piano pad note for harmonic warmth."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = (
        np.sin(2 * math.pi * freq * t)
        + 0.35 * np.sin(2 * math.pi * freq * 2 * t)
        + 0.12 * np.sin(2 * math.pi * freq * 3 * t)
        + 0.05 * np.sin(2 * math.pi * freq * 4.01 * t)
    )
    env = adsr(n, a=0.04, d=0.22, s=0.45, r=0.35)
    return amp * env * sig * np.exp(-0.55 * t / max(dur, 1e-6))


def xylo_tick(freq: float, dur: float, amp: float = 0.12) -> np.ndarray:
    """Light xylophone sparkle for garden glitter."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(
        2 * math.pi * freq * 2.76 * t
    )
    env = adsr(n, a=0.002, d=0.12, s=0.08, r=0.7)
    return amp * env * sig * np.exp(-3.2 * t / max(dur, 1e-6))


def place(buf: np.ndarray, start: float, clip: np.ndarray) -> None:
    i0 = int(start * SR)
    i1 = min(len(buf), i0 + len(clip))
    if i0 >= len(buf) or i0 < 0:
        return
    buf[i0:i1] += clip[: i1 - i0]


# Colorful Orchard progression — C major pentatonic / diatonic, preschool-friendly.
# Chord roots as MIDI (C4=60): C, G, Am, F — classic warm loop.
CHORD_TONICS = [65, 60, 62, 67]  # F C Dm G
PENTATONIC = [0, 2, 4, 7, 9]  # major pentatonic degrees
MELODY_PHRASE = [
    # Distinct Colorful Orchard phrase (same instrument family, new contour)
    (0.0, 0, 0.5),
    (0.5, 2, 0.5),
    (1.0, 4, 1.0),
    (2.0, 3, 0.5),
    (2.5, 2, 0.5),
    (3.0, 4, 1.0),
    (4.0, 1, 1.0),
    (5.0, 0, 0.5),
    (5.5, 1, 0.5),
    (6.0, 2, 1.0),
    (7.0, 4, 1.0),
    (8.0, 2, 0.5),
    (8.5, 3, 0.5),
    (9.0, 4, 1.0),
    (10.0, 3, 1.0),
    (11.0, 1, 1.0),
    (12.0, 2, 0.5),
    (12.5, 4, 0.5),
    (13.0, 3, 1.0),
    (14.0, 2, 0.5),
    (14.5, 0, 0.5),
    (15.0, 1, 1.0),
]


def build() -> np.ndarray:
    n = int(round(DURATION * SR))
    buf = np.zeros(n, dtype=np.float64)

    # Soft low pad / bass pulse every half-bar for garden heartbeat.
    for bar in range(BARS):
        chord = CHORD_TONICS[bar % 4]
        t0 = bar * 4 * BEAT
        # Soft piano chord: root + fifth + third (or minor third for Am).
        third = 3 if chord == 69 else 4
        for midi, amp in (
            (chord - 12, 0.10),
            (chord, 0.14),
            (chord + third, 0.11),
            (chord + 7, 0.09),
        ):
            place(buf, t0, soft_piano(midi_hz(midi), dur=3.6 * BEAT, amp=amp))

        # Light marimba arpeggio on beats 1 and 3.
        for beat_off, deg in ((0.0, 0), (1.0, 2), (2.0, 4), (3.0, 2)):
            midi = chord + PENTATONIC[deg % len(PENTATONIC)]
            place(
                buf,
                t0 + beat_off * BEAT,
                marimba(midi_hz(midi + 12), dur=1.4 * BEAT, amp=0.20),
            )

    # Lead marimba melody — 16-beat phrase, repeated 1.5× across 24 bars.
    phrase_len_beats = 16.0
    phrase_count = int((BARS * 4) / phrase_len_beats)
    for p in range(phrase_count):
        base = p * phrase_len_beats * BEAT
        chord_for = CHORD_TONICS[(p * 4) % 4]  # phrase spans 4 bars
        for beat_off, deg, dur_beats in MELODY_PHRASE:
            # Transpose melody relative to current phrase tonic family.
            # Use absolute C-major pentatonic colors; shift octave lightly.
            midi = 72 + PENTATONIC[deg] + (0 if p % 2 == 0 else -12)
            # Keep consonant with local chord by occasional chord-tone snaps.
            if deg in (0, 2, 4):
                midi = chord_for + 12 + PENTATONIC[deg]
            place(
                buf,
                base + beat_off * BEAT,
                marimba(midi_hz(midi), dur=dur_beats * BEAT * 1.15, amp=0.26),
            )
            # Soft xylo echo an octave up for garden sparkle.
            if deg in (2, 4):
                place(
                    buf,
                    base + beat_off * BEAT + 0.08,
                    xylo_tick(
                        midi_hz(midi + 12),
                        dur=0.55 * BEAT,
                        amp=0.07,
                    ),
                )

    # Very soft low hum (sine) for warmth — not a drone wall.
    t = np.arange(n) / SR
    hum = 0.035 * np.sin(2 * math.pi * midi_hz(36) * t)  # C2
    hum *= 0.5 + 0.5 * np.sin(2 * math.pi * (1.0 / (BARS * 4 * BEAT)) * t)
    buf += hum

    # Seamless loop: equal-power crossfade last/first 80 ms.
    fade = int(0.080 * SR)
    if fade * 2 < n:
        w_out = np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
        w_in = np.sin(np.linspace(0, math.pi / 2, fade)) ** 2
        head = buf[:fade].copy()
        tail = buf[-fade:].copy()
        buf[-fade:] = tail * w_out + head * w_in
        buf[:fade] = head * w_in + tail * w_out

    # Normalize with headroom (BGM plays at ~20% software gain).
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
    text = f"""# Colorful Orchard BGM — provenance

| Field | Value |
|-------|-------|
| Title | Colorful Orchard (Color Sorting loop) |
| File | `{mp3_path.name}` |
| Generator | `scripts/generate_color_sorting_bgm.py` |
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
python3 scripts/generate_color_sorting_bgm.py
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
