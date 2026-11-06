# Animal Sound Matching — animal cue provenance

Short, stylized preschool recognition cues. **Original digital synthesis only**
(algorithmic waveforms — not field recordings, not third-party samples).
**Not intended as biologically accurate animal recordings.**

| File | Description | SHA-256 |
|------|-------------|---------|
| `bird.wav` | Bright chirplets (short rising glides) | `174485bee0643df35ed11c6659a03c0c7421128b995b3f3268fda4e1f0da92f2` |
| `sheep.wav` | Buzzing baa with pitch waver | `606f1515ee999e2faef1fbca68643b1b1d57333ac7bd68a5e23e42f943e8cb99` |
| `dog.wav` | Cartoon bark (filtered noise bursts) | `a00593e4058e12e5e8f9346ca814c4b9715c2850867d237594c815f8fa18e917` |
| `frog.wav` | Croak — rough descending chirp | `4684a99e7ec3446409bae0cc76727d108539976ee896d1c1ebba8936424966d0` |
| `cow.wav` | Low moo hum with slow vibrato | `41c87706b98beb114994b416799350d29ede83edb3704eb956fbcdb9a2c9e996` |
| `horse.wav` | Neigh-ish whistle slide with flutter | `7a9701bf394a4b56bad52016a392c364d8ed91dfede6f451c4de2c68e4e4b4ee` |
| `duck.wav` | Quackish down-chirp on pulses | `2349e4feb8825a8a45bc3419083b46ccc6a4b113ba25c6f9c246fb35b84e1a8f` |
| `cat.wav` | Stylized meow glide (two-part sine FM contour) | `3b002c58ddc616fb0e68f31ecf7c016a3c44ea4245b8c4e8d4038c47b72de351` |

Commercial-safe for Little Minds product use.
Regenerate:

```bash
python3 scripts/generate_animal_sound_matching_animals.py
```
