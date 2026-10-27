# Little Minds Mobile (`apps/mobile`)

Flutter + Flame bootstrap for the Kids App and native Parent Gate/Settings stubs (**LMP-24**).

## What this is

- Adaptive phone/tablet shell (F-034) with window-driven layout (not device-model hardcoding).
- ADR-018 orientation wiring for Child Hub / profile (landscape-only) and Parent Gate/Settings (portrait + landscape).
- Flame host + empty `ActivityRegistry` stub (no real mini-games).
- QA-UI-001 widget tests under `test/`.

## What this is not

- Real Kids Hub UX, audio nav, content packs, auth/GSM OTP, OpenAPI Dart client, flavors, Crashlytics, or LMP-21 backend work.
- Product locks for min OS / breakpoints — numbers below are **TECHNICAL ASSUMPTION** only (see `docs/device-support-matrix.md`).

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

This Cloud Agent environment is **Linux**. iOS Simulator is **not available** here. Android SDK/emulator may also be absent. Compensating evidence for PRs:

1. `flutter analyze` + `flutter test` (required; also run in CI once `pubspec.yaml` exists).
2. Android emulator and/or iOS Simulator runs on a developer Mac when available.
3. Reviewer acknowledgment that runtime simulator evidence may follow on macOS if not attachable in-agent.

## Local commands

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test

# Where the host provides devices:
flutter devices
flutter run -d <ios-simulator-id>
flutter run -d <android-emulator-id>
```

## Project layout

```text
lib/
  main.dart / app.dart
  config/          # TECHNICAL ASSUMPTION breakpoints / viewports
  orientation/     # ADR-018 policy + binder
  shell/           # Adaptive phone/tablet chrome
  surfaces/        # Hub / profile / parent-gate / settings stubs
  game/            # Flame host + empty activity registry
test/              # QA-UI-001 widget + unit tests
```
