# Architecture Decision Records — Index & Boundaries (LMP-19)

**Canonical location:** `little-minds-app/little-minds-client`  
**Normative text:** Product Blueprint `docs/LITTLE_MINDS_PRODUCT_BLUEPRINT_v2.6.md`  
**Companion matrix:** [Device support matrix](../device-support-matrix.md)  
**Staging:** [Staging isolation](../environments-staging-isolation.md)

This index records **ADR boundaries** for V1 planning. It does not invent new product scope. Status labels:

| Status | Meaning |
|---|---|
| **Approved / Accepted** | Normative for implementation |
| **Resolved direction** | Architecture direction fixed; detail work remains |
| **Open** | Must be decided before or during related implementation; not permission to drop P0 features |

---

## Approved / Accepted ADRs (boundary for implementers)

| ADR | Title | Blueprint section | Boundary summary |
|---|---|---|---|
| **ADR-013** | Cost-aware pluggable observability | §31 | Core error capture always on; optional vendors/adapters gated OFF by default; no child PII in telemetry |
| **ADR-014** | Separate client & backend repos | §32 | Two private repos; one Jira LMP; pinned OpenAPI; **no diverging Blueprint copies** |
| **ADR-015** | AI content only; developer-owned mechanics | §33 | AI may generate content data; must not generate executable game code in V1 |
| **ADR-016** | Multi-device offline screen time & entitlements | §35 | Trusted time / single-active-device / offline entitlement boundaries |
| **ADR-017** | Pedagogical metrics, PII lifecycle, cache & events | §36 | Pedagogy firewall; no performance-derived punitive difficulty; PII lifecycle |
| **ADR-018** | Screen orientation policy | §40 | **LOCKED** surface orientation table; F-034 phone+tablet Day-1 unchanged; state preservation; QA-UI-001 orientation coverage |

### ADR-018 quick reference (**LOCKED**)

| Surface | Policy |
|---|---|
| Child Hub; educational mini-games; game results/rewards; child profile selection | Landscape-only |
| Native Parent Gate & Parent Settings | Portrait + landscape |
| Next.js Parent Dashboard | Responsive; no orientation lock |

---

## Resolved direction (detail still open)

| ADR | Notes |
|---|---|
| **ADR-002** | Self-hosted NestJS `IdentityModule` with extraction-ready boundaries (implementation/security design remains) |

---

## Open ADR queue (Blueprint §20)

`ADR-001`, `ADR-003`–`ADR-012` remain open product/engineering choices. Existing identifier reservations apply (e.g. ADR-004 hosting vs ADR-013 observability; ADR-005 screen-time sync vs ADR-014 repos).

Agents must **not** silently close open ADRs or contradict Approved ADRs.

---

## Backend mirror

`little-minds-backend` keeps a pointer copy of this index (and the device matrix) so ADR-014 Blueprint/docs discovery works in both repos. Normative edits land in **client** first; backend stays in sync.

---

## LMP-19 doc tests

Structure checks: `scripts/check-lmp19-docs.sh` (client) and the backend pointer equivalent.
