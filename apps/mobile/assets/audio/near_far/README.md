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

## Target WAV tech

- 16-bit PCM mono WAV
- 44.1 kHz or 48 kHz
- Calm child-friendly spoken labels: en “Near”/“Far”, tr “Yakın”/“Uzak”
- Normalize + trim excess silence
- Offline playback only (no network during play)

## Current status — **BLOCKED for spoken AC**

Approved commercial AI TTS generation **could not run** in this Cloud Agent environment
(2026-10-27). **No** `near.wav` / `far.wav` files are committed. Do **not** treat empty
locale directories or `.gitkeep` as spoken readiness.

### Exact blocker

| Need | Status in this environment |
|---|---|
| `OPENAI_API_KEY` (OpenAI Audio Speech) | **unset** |
| `AZURE_SPEECH_KEY` / Azure Speech region | **unset** |
| `GOOGLE_APPLICATION_CREDENTIALS` / Cloud TTS | **unset** |
| `AWS_ACCESS_KEY_ID` (+ Polly) | **unset** |
| `ELEVENLABS_API_KEY` / `CARTESIA_API_KEY` / `DEEPGRAM_API_KEY` | **unset** |
| Pedagogy-approved pre-licensed voice packs in repo | **absent** |

Without a commercial-cleared TTS credential (or reviewed licensed packs), agents must
**not** invent/fake WAV recordings or claim the spoken-label AC.

### Options evaluated (not used — rights or quality not verified for ship)

| Candidate | Why not used |
|---|---|
| **OpenAI Audio Speech** (`tts-1-hd` / `gpt-4o-mini-tts`) | Preferable commercial API path under OpenAI Service Terms (API customers own Output; AI-voice disclosure required). **Blocked: no API key.** |
| **Azure AI Speech / Amazon Polly / Google Cloud TTS** | Commercial cloud TTS with paid redistribution under provider agreements. **Blocked: no credentials.** |
| **Microsoft Edge / `edge-tts` unofficial client** | Not an approved commercial redistribution path for shipped app audio; consumer Edge Read Aloud terms are not a verified commercial license. **Not used.** |
| **Piper `tr_TR-dfki-medium`** | Dataset license **CC BY-NC-SA 4.0** + Lessac fine-tune lineage → **non-commercial risk**. **Not used.** |
| **espeak-ng** | Available locally but **not** native-quality AI TTS. **Not used.** |

### Provenance policy (when unblocked)

When credentials or packs are supplied, document in this README **before** claiming spoken AC:

1. Provider + model / voice id  
2. License / terms URL + commercial redistribution statement (verbatim cite; no unverified claims)  
3. Generation date, locale, prompt text, sample rate, SHA-256 of each WAV  
4. Offline player wiring + tests green  
5. AI-disclosure note if required by provider terms (e.g. OpenAI TTS)

### Runtime readiness (code)

- On-screen text labels (`Near`/`Far`, `Yakın`/`Uzak`) still work offline.
- **Asset presence ≠ readiness.** `areAssetsPresent` only probes files.
- `areSpokenLabelsReady` requires assets **and** `NearFarLabelPlayer.canPlay == true`.
- Default `UnavailableNearFarLabelPlayer` has `canPlay == false` and never reports spoken readiness.
- Spoken AC stays **BLOCKED** until commercial-cleared en-US/tr-TR WAVs **and** a working offline WAV player are integrated and tested.

## Placeholder directories

`en-US/` and `tr-TR/` exist so asset declarations can resolve once packs land. Only add reviewed, commercial-cleared `.wav` files (no secrets in repo).
