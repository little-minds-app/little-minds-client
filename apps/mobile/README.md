# Little Minds Mobile (`apps/mobile`)

Flutter + Flame Kids App with **Child Hub v1** (LMP-43) on top of the LMP-24 bootstrap.

## What this is

- **Child Hub v1** — calm Kids Mode home: landscape-only (ADR-018), adaptive phone/tablet (F-034), `tr-TR` / `en-US` (F-020), large touch targets, safe areas, reduced-motion aware.
- Activity catalog for the six V1 engines as **passive** tiles until a playable `LearningActivity` is registered (no fake games / progress).
- Offline-safe **audio cue hook** (asset-path probe + graceful no-op). See `assets/audio/hub/README.md` — **not** full spoken playback in V1.
- Parent exit → **Parent Gate** only; settings stay behind the gate.
- Flame host + `ActivityRegistry` retained for future playable launches.
- LMP-28 public env config badge (non-release / tests).
- QA-UI-001 widget tests under `test/`.

## What this is not

- Playable mini-game mechanics (F-005) — deferred to later E03 tasks.
- **Real audio playback** — `LocalAssetHubAudioGuidance` only probes whether a local WAV path exists; it does not play sound. Pedagogy-approved voice packs are not shipped.
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
  config/          # LMP-28 AppConfig + TECHNICAL ASSUMPTION breakpoints
  orientation/     # ADR-018 policy + binder
  shell/           # Adaptive phone/tablet chrome (Parent surfaces)
  surfaces/        # Child Hub v1 / profile / parent-gate / settings
  game/            # Flame host + activity registry
assets/audio/hub/  # Offline cue convention (WAV packs TBD)
test/              # QA-UI-001 widget + unit tests
```
