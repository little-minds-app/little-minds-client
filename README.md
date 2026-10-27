# little-minds-client

Little Minds mobile app, parent dashboard and content admin.

## Repository layout

| Path | Status |
|---|---|
| `apps/mobile` | Flutter + Flame Kids App bootstrap (LMP-24) |
| `apps/web` | Next.js Parent Web / Content Admin — not bootstrapped yet (LMP-25 / LMP-26) |
| `docs/` | Product Blueprint, ADR index, device support matrix |

## Mobile (Flutter + Flame)

See [`apps/mobile/README.md`](apps/mobile/README.md) for run instructions, scaffolding assumptions, and Cloud Agent / Linux simulator limits.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

## CI

`.github/workflows/ci.yml` detects `apps/mobile/pubspec.yaml` and runs Flutter analyze + test. Next.js checks activate when `apps/web` exists.
