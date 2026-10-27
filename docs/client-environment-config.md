# Client Environment Configuration (LMP-28)

**Status:** Implemented for Flutter public build-time config; Next.js Parent Dashboard documented for future (not scaffolded).  
**Blueprint:** §26 Environments · F-022 · F-028 · F-034 · ADR-018  
**Jira:** [LMP-28](https://little-minds-app.atlassian.net/browse/LMP-28)

---

## Cross-repo contract

| Item | Value |
|---|---|
| Environment names | `development` \| `staging` \| `production` |
| Client payload | **Public only:** environment name + API base URL |
| Forbidden in mobile binary | Service-role keys, DB credentials, backend private tokens, JWT signing secrets, store signing passwords |
| OpenAPI pin | Unchanged — see [`contracts/pin.json`](../contracts/pin.json) (LMP-23 / `0.1.0`) |

Backend owns runtime secrets and fail-fast validation for private env vars. This client repo never receives those values.

---

## Flutter (`apps/mobile`) — build-time defines

| Define | Required | Notes |
|---|---|---|
| `LM_ENV` | Default `development` | Exact wire names above |
| `LM_API_BASE_URL` | Required for `staging` / `production` | Absolute `http(s)://` URL |

### Defaults and matrix

| Env | Default API base URL | HTTPS | Notes |
|---|---|---|---|
| `development` | `http://localhost:3000` | HTTP allowed for local hosts only (`localhost`, `127.0.0.1`, `10.0.2.2`, `*.local`) | Blueprint §27 — iOS Simulator → host NestJS |
| `staging` | *(none — must pass define)* | **HTTPS required** | Hostname is a **TECHNICAL ASSUMPTION** until staging is provisioned (LMP-29) |
| `production` | *(none — must pass define)* | **HTTPS required** | Not provisioned in this task |

Android emulator loopback (pass explicitly):

```bash
flutter run \
  --dart-define=LM_ENV=development \
  --dart-define=LM_API_BASE_URL=http://10.0.2.2:3000
```

Example staging-shaped build (placeholder host — not a real deployment):

```bash
flutter run \
  --dart-define=LM_ENV=staging \
  --dart-define=LM_API_BASE_URL=https://api.staging.example.test
```

### Security controls

1. Allowlist: only `LM_ENV` and `LM_API_BASE_URL` may be supplied as client defines (`SecretKeyDenylist`).
2. Keys containing `SECRET`, `PASSWORD`, `TOKEN`, `DATABASE`, `SERVICE_ROLE`, `API_KEY`, etc. are rejected.
3. Staging/production reject cleartext `http` and local hosts.
4. Invalid or missing required public config → `FormatException` at startup (`AppConfig.fromEnvironment()`).
5. `.env` / `.env.*` remain gitignored (repo root). Do not commit credentials.
6. Full Android product flavors / iOS schemes / Firebase distribution → **LMP-30**.

Code: `apps/mobile/lib/config/`.

---

## Future Next.js Parent Dashboard (docs only — no `apps/web` yet)

When LMP-25 bootstraps Parent Web, use the **same** environment names:

| Concern | Guidance |
|---|---|
| Public browser config | `NEXT_PUBLIC_LM_ENV`, `NEXT_PUBLIC_API_BASE_URL` only |
| Secrets | Server-only env / GitHub Environments — never `NEXT_PUBLIC_*` |
| Staging | Separate deployment + auth gate; no production credentials |
| Local | Align with API `http://localhost:3000` (Blueprint §27) |

Do not scaffold `apps/web` under LMP-28.

---

## iOS Simulator verification (manual — macOS)

This Linux Cloud Agent image has **no Flutter SDK and no iOS Simulator**. Run on a developer Mac:

1. Start local API on port `3000` (backend Docker / NestJS).
2. `cd apps/mobile && flutter pub get`
3. `flutter devices` — pick an iOS Simulator.
4. Development (default):

   ```bash
   flutter run -d <ios-simulator-id>
   ```

   Expect Child Hub debug badge: `env=development api=http://localhost:3000`.

5. Explicit defines:

   ```bash
   flutter run -d <ios-simulator-id> \
     --dart-define=LM_ENV=development \
     --dart-define=LM_API_BASE_URL=http://localhost:3000
   ```

6. Negative check (should fail before UI):

   ```bash
   flutter run -d <ios-simulator-id> \
     --dart-define=LM_ENV=staging
   ```

7. Confirm ADR-018 landscape Child Hub and F-034 phone/tablet chrome still behave.

Automated evidence without simulator: `flutter analyze` + `flutter test` (CI Flutter Analysis job).

---

## Related

- Staging isolation rules: [environments-staging-isolation.md](./environments-staging-isolation.md)
- Mobile README: [`apps/mobile/README.md`](../apps/mobile/README.md)
- Device matrix: [device-support-matrix.md](./device-support-matrix.md)
