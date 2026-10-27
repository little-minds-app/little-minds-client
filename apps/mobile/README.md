# Little Minds Mobile (`apps/mobile`)

Flutter + Flame Kids App with **Child Hub v1** (LMP-43), Flame lifecycle (LMP-44), and Near/Far Slice B demo (LMP-45).

## What this is

- **Child Hub v1** — calm Kids Mode preschool home: landscape-only (ADR-018), phone **carousel** / tablet **3×2** (F-034), `tr-TR` / `en-US` (F-020), original CustomPainter card art, large targets, reduced-motion aware.
- Activity catalog for the six V1 engines as **Coming Soon / Yakında** passive tiles until a playable `LearningActivity` is registered (no fake games / progress).
- Offline-safe **audio cue hook** (asset-path probe + graceful no-op). See `assets/audio/hub/README.md` — **not** full spoken playback in V1.
- Env/API diagnostics are **not** child-facing; reveal only via `forceShowEnvBadge` / debug long-press on brand.
- Parent exit → **Parent Gate** only; settings stay behind the gate.
- Flame host + `ActivityRegistry` retained for future playable launches.
- **LMP-44** reusable Flame activity session lifecycle (enter/exit, pause/resume, foreground/background, restart/dispose, orientation state preserve, hitbox scaling, scoring-neutral outcomes). Production registry stays empty — Hub cards remain Coming Soon.
- **LMP-45 Near/Far** — dedicated Kids Mode demo route (not a Hub catalog / seventh game): 32-month offline drag-position sock + soft toy, versioned local §14 event fixtures, safe mission handoff contract, F-009 mentor adjacency metadata only. Entry: Parent Settings → “Try Near/Far demo”.
- LMP-28 public env config badge (non-release / tests).
- QA-UI-001 widget tests under `test/`.

## What this is not

- Playable Hub mini-game mechanics among the six engines (F-005 engines) — Shape Matching = LMP-55 (blocked until LMP-45 Done).
- Full Real World Mission skip/feedback UI (**LMP-46**), parent mentor card UI (**LMP-47/48**), production telemetry (**LMP-50**).
- **Spoken near/far WAV packs** — commercial AI TTS generation is **blocked** in Cloud Agent (no TTS API credentials); no `near.wav`/`far.wav` shipped. Spoken-label AC remains blocked. On-screen Near/Far text labels still work. See `assets/audio/near_far/README.md`.
- **Real hub audio playback** — `LocalAssetHubAudioGuidance` only probes whether a local WAV path exists; it does not play sound.
- Real Parent Gate OTP / auth, OpenAPI wiring into hub, store flavors (LMP-30), Crashlytics.
- Product locks for min OS / breakpoints — numbers below remain **TECHNICAL ASSUMPTION** (see `docs/device-support-matrix.md`).

## Environment config (LMP-28)

Public build-time config only — `LM_ENV` + `LM_API_BASE_URL`. Never put secrets in the binary.

| Env | Default API URL |
|---|---|
| `development` | `http://localhost:3000` |
| `staging` / `production` | Required via `--dart-define` (HTTPS) |

```bash
flutter run

flutter run \
  --dart-define=LM_ENV=development \
  --dart-define=LM_API_BASE_URL=http://10.0.2.2:3000
```

Full matrix: [`docs/client-environment-config.md`](../../docs/client-environment-config.md).

## Scaffolding assumptions (not PO-approved locks)

| Item | Temporary value | Class |
|---|---|---|
| Bundle / application id | `com.littleminds.little_minds_mobile` | Scaffolding |
| Display name | Little Minds | Scaffolding |
| Breakpoints | Compact `<600` · Medium `600–839` · Expanded `≥840` | TECHNICAL ASSUMPTION ⏳ |
| CI test viewports | ~390×844 · ~430×932 · ~1024×1366 | TECHNICAL ASSUMPTION ⏳ |
| Proposed min OS | iOS 16.0+ · Android API 29+ | TECHNICAL ASSUMPTION ⏳ |
| State management | Flutter built-ins | Scaffolding until ADR-003 |

## Prerequisites

- Flutter **stable** (CI uses `subosito/flutter-action` channel `stable`).
- For device runs: Xcode + iOS Simulator (macOS) and/or Android SDK + emulator.

### Cloud Agent / Linux hosts

This Cloud Agent environment is **Linux**. iOS Simulator is **not available** here. Compensating evidence for PRs:

1. `flutter analyze` + `flutter test` (required; also run in CI).
2. Android emulator and/or iOS Simulator runs on a developer Mac when available.
3. Reviewer acknowledgment that runtime simulator evidence may follow on macOS if not attachable in-agent.

### iOS Simulator manual steps (iPhone 15 — visual reference)

```bash
cd apps/mobile
flutter pub get
open -a Simulator
xcrun simctl boot "iPhone 15" || true
flutter run -d "iPhone 15"
# Rotate to landscape (Child Hub is landscape-only).
# Confirm: brand + greeting, six passive Soon tiles, Grown-ups → Parent Gate,
# no settings from hub, no external links.
```

## Local commands

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter analyze
flutter test

flutter devices
flutter run -d <ios-simulator-id>
flutter run -d <android-emulator-id>
```

## Project layout

```text
lib/
  main.dart / app.dart
  l10n/            # en + tr ARB + generated localizations
  child_hub/       # catalog, cards, audio guidance
  near_far/        # LMP-45 Near/Far demo (not Hub catalog)
  config/          # LMP-28 AppConfig + TECHNICAL ASSUMPTION breakpoints
  orientation/     # ADR-018 policy + binder
  shell/           # Adaptive phone/tablet chrome (Parent surfaces)
  surfaces/        # Child Hub / NearFar demo / profile / parent-gate / settings
  game/            # Flame host, ActivityRegistry, LMP-44 session lifecycle
assets/audio/hub/       # Offline hub cue convention (WAV packs TBD)
assets/audio/near_far/  # Spoken near/far convention (licensed packs blocked)
test/              # QA-UI-001 widget + unit tests (lifecycle + near/far)
```

### Near/Far demo (LMP-45) — Mac simulator follow-on

```bash
cd apps/mobile
flutter run -d "iPhone 15"
# Grown-ups → Settings → Try Near/Far demo
# Landscape: drag sock + soft toy near, then far; mission invitation appears.
# Confirm: Hub still has six Coming Soon cards only; no seventh catalog tile.
# Spoken audio: expect on-screen blocker note until licensed WAVs are added.
flutter run -d "iPad (10th generation)"   # same journey, tablet layout
```
