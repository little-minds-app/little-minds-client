# Child Hub audio cues (offline / local only)

**Blueprint:** F-004 audio guidance · locale-tagged offline assets · no network audio.

## Path convention

```text
assets/audio/hub/<locale>/<cue_id>.wav
```

| Locale tag | Example |
|---|---|
| `en-US` | `assets/audio/hub/en-US/welcome.wav` |
| `tr-TR` | `assets/audio/hub/tr-TR/welcome.wav` |

### Cue IDs (`HubAudioCue`)

| Cue | File stem |
|---|---|
| Welcome | `welcome` |
| Passive / not ready | `passive_unavailable` |
| Playable select | `playable_select` |
| Parent exit | `parent_exit` |

## Current V1 status

**No pedagogy-approved voice packs are shipped yet.**  
`LocalAssetHubAudioGuidance` probes the asset bundle and **no-ops gracefully** when files are missing. The Child Hub remains fully usable offline.

Do **not** add unreviewed child-facing voice content. Production cues require content/pedagogy review before `is_offline_ready` claims.

## Placeholder directory

This folder (and locale subfolders if empty) exists so `pubspec.yaml` asset declarations resolve. Add approved `.wav` files later without changing the API.
