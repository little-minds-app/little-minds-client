# Little Minds Parent Web — LMP-38 (development preview)

This Next.js browser-auth implementation depends on backend PR #22 (ADR-023), which adds database-owned opaque web sessions. **Both PRs are Draft; do not merge or deploy until both contracts, PostgreSQL tests and real HTTP tests pass.** LMP-25 web bootstrap remains a separate dependency. Privacy notice copy is an engineering placeholder pending qualified legal approval.

## Run locally

Use Node 22. Run the **backend feature branch** on port 3001 with PostgreSQL migrated to the new `web_parent_sessions` table, and Next on port 3000:

```sh
cd apps/web
npm install
LM_API_BASE_URL=http://127.0.0.1:3001 npm run dev
```

No OTP code is ever returned by the API; the fake SMS development adapter needs a separate local test harness.

## Security model

Browser -> same-origin Next route handlers -> backend. The browser receives **only an opaque 256-bit web session cookie**. Next calls `/v1/auth/phone/verify` and exchanges the short-lived server-only access token at `/v1/auth/web/session`. Backend hashes the opaque handle in PostgreSQL and ties it to an active parent account and existing parent session. Every `GET /v1/auth/web/me` validates DB state, including expiry/revocation, across any replica. Browser web sessions **never rotate refresh tokens**. On exchange, the backend removes the associated native refresh hash so it cannot be used again.

Production cookie is `__Host-lm_web_session` (Secure/HttpOnly/SameSite=Strict/Path=/), with an explicit separate localhost development cookie. Backend remains source of truth for logout; Next clears cookies and reports an error if backend revocation cannot be confirmed. If no HTTP response reaches the browser, cookies cannot be deleted by JS. CSRF POST origin check is a defense-in-depth measure, not a substitute for a reviewed deployment proxy/TLS model.

## Required verification before merge

- Backend migration + Prisma generation + PostgreSQL DB integration suite; web Next.js build and actual HTTP integration tests.
- Browser E2E against real backend for OTP, session persistence, direct protected route, expiry, logout transport failure, and accessibility.
- Versioned OpenAPI contract pin/TypeScript client update for new backend API (backend PR #22).
- Commit `apps/web/package-lock.json` and replace fallback `npm install` with reproducible `npm ci` (cannot fetch the npm registry in this execution environment).
- LMP-25 bootstrap dependency, CSRF/proxy security review, qualified KVKK notice/legal approval and staging release review.

**Note:** Do not interpret a standalone client CI pass against mock backend as evidence that the still-unmerged backend contract is compatible. The two PRs must be tested together.
