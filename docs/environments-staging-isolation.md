# Staging Isolation Summary (LMP-19 / F-028)

**Status of rules below:** **LOCKED** (Blueprint §26.1 / F-028)  
**Purpose:** Record the isolation boundary for the LMP-19 architecture package. Provisioning is **out of scope** for LMP-19 (see LMP-29 and related infrastructure tasks).

---

## Non-negotiable isolation (**LOCKED**)

Staging must **not** share with production:

- Database
- Object-storage bucket
- Auth tenant / identity project
- Signing secrets
- Payment / store credentials

Additional **LOCKED** rules:

- Do **not** copy real child profiles or raw production activity data into staging.
- Use **synthetic** fixtures only.
- Protect staging web/admin with authentication; restrict test enrollment.
- Mobile flavors `development` / `staging` / `production` each use separate API base URL, app identifiers where needed, storage/cache namespace, and purchase test configuration.

Source: Blueprint §26.1.

---

## Matrix embedding

The [device support matrix](./device-support-matrix.md) includes a staging-flavor column for each mobile cell. Web Parent and Admin staging deployments follow the same isolation rules.

---

## TECHNICAL ASSUMPTIONS (not provisioned here)

| Item | Class | Notes |
|---|---|---|
| Exact hosting vendor / region | TECHNICAL ASSUMPTION ⏳ | Chosen when staging is provisioned |
| Exact staging hostnames | TECHNICAL ASSUMPTION ⏳ | Document in env runbooks at provision time |
| Synthetic seed month set (24, 32, 47, 59, 71) | Blueprint guidance (**LOCKED** intent) | Implementation of seed job is a later task |

---

## Related

- Device matrix: [device-support-matrix.md](./device-support-matrix.md)
- ADR boundaries: [adr/README.md](./adr/README.md)
- Blueprint §26, F-028
