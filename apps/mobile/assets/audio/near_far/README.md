# Near/Far spoken labels (offline / local only)

**Blueprint:** §5.2 / §22 spoken "near"/"far" · F-020 locales · ADR-015 fixtures  
**Jira:** LMP-45 (digital labels) · **LMP-120** (all deferred voice / SFX / offline playback)  
**LMP-46 note:** mission handoff/skip is **on-screen text only** — no placeholder or fake mission audio.

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

`OPENAI_API_KEY` is **present** in the Cloud Agent environment (2026-10-27 fresh
boot), but OpenAI Audio Speech generation **failed** with HTTP **429**
`insufficient_quota` / `credit_balance_exhausted`. **No** `near.wav` / `far.wav`
files are committed. Do **not** treat empty locale directories or `.gitkeep` as
spoken readiness.

### Exact blocker

| Need | Status in this environment |
|---|---|
| `OPENAI_API_KEY` (OpenAI Audio Speech) | **present** — auth OK (`GET /v1/models`); Speech `POST /v1/audio/speech` → **429 `credit_balance_exhausted`** |
| OpenAI organization billing / usable Speech credits | **exhausted** — add credits at platform.openai.com billing |
| `AZURE_SPEECH_KEY` / Azure Speech region | **unset** |
| `GOOGLE_APPLICATION_CREDENTIALS` / Cloud TTS | **unset** |
| `AWS_ACCESS_KEY_ID` (+ Polly) | **unset** |
| `ELEVENLABS_API_KEY` / `CARTESIA_API_KEY` / `DEEPGRAM_API_KEY` | **unset** |
| Pedagogy-approved pre-licensed voice packs in repo | **absent** |

Without usable commercial TTS credits (or reviewed licensed packs), agents must
**not** invent/fake WAV recordings or claim the spoken-label AC.

### Commercial terms verified (OpenAI API Speech — preferred path)

Intended provider once billing is restored:

| Field | Value |
|---|---|
| Provider | OpenAI **API** Audio Speech (`POST /v1/audio/speech`) — **not** ChatGPT Voice |
| Planned model | `gpt-4o-mini-tts` (or `tts-1-hd` fallback) |
| Planned voice | `nova` (calm built-in voice; adult voice only) |
| Planned texts | en-US: “Near” / “Far”; tr-TR: “Yakın” / “Uzak” |
| Output ownership | OpenAI Business / Services Agreement: customer **owns Output** from the API (`Customer Content` / Output assignment). Distribution in a commercial app is permitted subject to the Agreement and Usage Policies. |
| Terms (cite) | [OpenAI Service Terms](https://openai.com/policies/service-terms/) (updated 2026-10-16); [Business terms](https://openai.com/policies/aug-2023-business-terms/) §3.1 (customer owns Output); TTS guide disclosure requirement |
| **Not** used | **ChatGPT Voice Output** — Service Terms §8: non-commercial; may not be distributed/repackaged as standalone audio |
| AI disclosure | Usage Policies / TTS docs require clear disclosure that the voice is **AI-generated** (not a human recording). Preserve any OpenAI AI-origin indicators. Do not impersonate a real person’s voice. |
| Provenance | SHA-256 + generation metadata will be filled in this README **after** successful Speech generation |

### Options evaluated (not used — rights, quality, or credits)

| Candidate | Why not used |
|---|---|
| **OpenAI Audio Speech** (`gpt-4o-mini-tts` / `tts-1-hd`) | Preferred commercial API path (customer owns Output; AI-voice disclosure). **Blocked: org credit balance exhausted (429).** |
| **Azure AI Speech / Amazon Polly / Google Cloud TTS** | Commercial cloud TTS with paid redistribution under provider agreements. **Blocked: no credentials.** |
| **Microsoft Edge / `edge-tts` unofficial client** | Not an approved commercial redistribution path for shipped app audio; consumer Edge Read Aloud terms are not a verified commercial license. **Not used.** |
| **Piper `tr_TR-dfki-medium`** | Dataset license **CC BY-NC-SA 4.0** + Lessac fine-tune lineage → **non-commercial risk**. **Not used.** |
| **espeak-ng** | Available locally but **not** native-quality AI TTS. **Not used.** |

### Provenance policy (when unblocked)

When usable credits or packs are supplied, document in this README **before** claiming spoken AC:

1. Provider + model / voice id  
2. License / terms URL + commercial redistribution statement (verbatim cite; no unverified claims)  
3. Generation date, locale, prompt text, sample rate, SHA-256 of each WAV  
4. Offline player wiring + tests green  
5. AI-disclosure note (required for OpenAI TTS)

### Runtime readiness (code)

- On-screen text labels (`Near`/`Far`, `Yakın`/`Uzak`) still work offline.
- **Asset presence ≠ readiness.** `areAssetsPresent` only probes files.
- `areSpokenLabelsReady` requires assets **and** `NearFarLabelPlayer.canPlay == true`.
- Default `UnavailableNearFarLabelPlayer` has `canPlay == false` and never reports spoken readiness.
- Spoken AC stays **BLOCKED** until commercial-cleared en-US/tr-TR WAVs **and** a working offline WAV player are integrated and tested.

## Placeholder directories

`en-US/` and `tr-TR/` exist so asset declarations can resolve once packs land. Only add reviewed, commercial-cleared `.wav` files (no secrets in repo).

## LMP-46 → LMP-120 audio requirements (document only)

LMP-46 ships the optional real-world mission Start/Try / Skip / Back / calm-done **flow without audio**. When LMP-120 resumes the final audio pass, add pedagogy-approved, commercially redistributable offline WAVs (or equivalent) for:

| Cue id (proposed) | Locale | Suggested spoken text | Trigger |
|---|---|---|---|
| `mission_invite` | en-US | “Try it in the room with a grown-up.” | Mission offered |
| `mission_invite` | tr-TR | “Odada bir büyükle dene.” | Mission offered |
| `mission_try` | en-US | “Try together.” | Start/Try pressed (optional SFX/voice) |
| `mission_try` | tr-TR | “Birlikte dene.” | Start/Try pressed |
| `mission_step_near` | en-US | “Put the sock and soft toy near.” | Active guidance step 2 |
| `mission_step_near` | tr-TR | “Çorabı ve yumuşak oyuncağı yaklaştırın.” | Active guidance step 2 |
| `mission_step_far` | en-US | “Now put them far apart.” | Active guidance step 3 |
| `mission_step_far` | tr-TR | “Şimdi onları uzaklaştırın.” | Active guidance step 3 |
| `mission_skipped` | en-US | “That’s okay. You can try another time.” | Skip |
| `mission_skipped` | tr-TR | “Sorun değil. Başka zaman deneyebilirsiniz.” | Skip |
| `mission_done` | en-US | “Nice exploring together.” | Optional We’re done |
| `mission_done` | tr-TR | “Birlikte güzel keşfettiniz.” | Optional Bitirdik |

Also still required from LMP-45 carry-over: `near.wav` / `far.wav` for en-US and tr-TR, plus a real offline player with mute / pause / resume / restart / dispose. **No network TTS in Kids Mode. No fake WAVs.**
