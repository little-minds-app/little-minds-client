# Little Minds Parent Web — LMP-38 (development preview)

This Next.js server-side authentication prototype is **not production ready**. LMP-25 web bootstrap is an outstanding prerequisite. No approved legal privacy notice copy is bundled.

Run locally with Node 22 and a backend configured for development:

```sh
cd apps/web
npm install
npm run dev
```

Visit http://localhost:3000 (run backend on 3001 or Next on 3002 with `npm run dev -- -p 3002`). Set `LM_API_BASE_URL=http://127.0.0.1:3001` to the backend address. Never point a production deployment at a development backend.

The browser calls same-origin /api/auth endpoints only. Access/refresh tokens stay in HttpOnly SameSite cookies on the web origin; the Next server talks to the backend. OTP code is **not returned by the API**. Development fake SMS requires a separate local harness. Backend /v1/parent/me verifies the bearer and refresh rotates tokens on 401. Logout clears cookies on server response even if backend revocation fails (returns 503 and warns the user); if the browser never reaches the Next server, cookies cannot be cleared and the UI instructs the user to retry.

**Before merge / production:** Finish LMP-25 with reproducible lockfile + CI Next.js job, replace per-process refresh deduplication with cross-instance coordination or a backend-owned web session, complete CSRF/security review, legal notice approval, real browser E2E for OTP / session / refresh / logout / guarded page and staging deployment. `app/parent` route is server-validated and redirects to the sign-in page for expired access; the root page can refresh the session without auto-redirect loops. This recovery is limited until a server-managed session architecture is implemented. This branch is a first implementation slice, not evidence of those checks passing.
