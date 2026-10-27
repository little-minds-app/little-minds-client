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

## Current V1 status — probe only, not playback

**This is not full spoken audio guidance.**

`LocalAssetHubAudioGuidance`:

1. Looks up the expected local asset path in the Flutter asset bundle **once per locale+cue**.
2. Caches presence **or** absence so Simulator/debug does not re-probe or spam logs for expected-missing V1 packs.
3. Returns whether the file **exists**.
4. Does **not** decode or play WAV/PCM (no speakers, no `AudioPlayer`).
5. No-ops when the file is missing (current default — no pedagogy-approved packs shipped). Missing paths are **not** repeatedly debug-logged.

Do **not** tell QA or users that Kids Mode “has audio cues” in the playback sense until approved voice packs land **and** a real player is wired.

Do **not** add unreviewed child-facing voice content. Production cues require content/pedagogy review before any `is_offline_ready` claims.

## Placeholder directory

This folder (and locale subfolders) exists so `pubspec.yaml` asset declarations resolve. Add approved `.wav` files later without changing the path API.
