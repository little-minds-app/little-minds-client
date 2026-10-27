# Near/Far spoken labels (offline / local only)

**Blueprint:** §5.2 / §22 spoken "near"/"far" · F-020 locales · ADR-015 fixtures  
**Jira:** LMP-45

## Path convention

```text
assets/audio/near_far/<locale>/<stem>.wav
```

| Locale | Near | Far |
|---|---|---|
| `en-US` | `assets/audio/near_far/en-US/near.wav` | `assets/audio/near_far/en-US/far.wav` |
| `tr-TR` | `assets/audio/near_far/tr-TR/near.wav` | `assets/audio/near_far/tr-TR/far.wav` |

## Current status — **BLOCKED for spoken AC**

Approved **licensed** pedagogy voice packs are **not** present in this repository.

- Do **not** commit unlicensed, synthetic, or placeholder spoken WAVs and claim the spoken-label AC.
- On-screen text labels (`Near`/`Far`, `Yakın`/`Uzak`) still work offline.
- **Asset presence ≠ readiness.** `areAssetsPresent` only probes files. `areSpokenLabelsReady` requires assets **and** `NearFarLabelPlayer.canPlay == true`.
- Default `UnavailableNearFarLabelPlayer` has `canPlay == false` and **never** reports spoken-label readiness, even if WAV files appear later.
- Spoken AC stays blocked until approved en-US/tr-TR packs **and** a working offline WAV player are integrated and tested.

## Placeholder directories

`en-US/` and `tr-TR/` exist so asset declarations can resolve once packs land. Only add reviewed, licensed `.wav` files.
