# Little Minds V1 — Device Support Matrix (LMP-19)

**Jira:** [LMP-19](https://little-minds-app.atlassian.net/browse/LMP-19) — *Confirm V1 architecture decisions and device support matrix*  
**Epic:** [LMP-6](https://little-minds-app.atlassian.net/browse/LMP-6) — *V1 | Foundation & Platform*  
**Canonical repo:** `little-minds-app/little-minds-client`  
**Blueprint:** `docs/LITTLE_MINDS_PRODUCT_BLUEPRINT_v2.6.md` (document status V2.7 content; filename retained)  
**Related:** [ADR index](./adr/README.md) · [Staging isolation](./environments-staging-isolation.md) · ADR-018 (Blueprint §40)

---

## Legend — decision classes

| Label | Meaning |
|---|---|
| **LOCKED** | Product / Blueprint decision. Do not reopen or weaken in implementation. |
| **TECHNICAL ASSUMPTION** | Proposed Day-1 engineering value. **Needs Product Owner approval** before treating as contract. Marked `⏳` in tables. |
| **OUT OF SCOPE (this doc)** | Tracked elsewhere; listed only for boundary clarity. |

---

## 1. LOCKED product decisions

| ID | Decision | Source |
|---|---|---|
| L1 | **Phone + tablet Day 1 (F-034 P0).** iPhone, iPad, Android phone, and Android tablet are first-class. Stretch/center of phone UI on tablet does **not** satisfy the requirement. Applies to Kids Mode and embedded Parent Dashboard. | Blueprint F-034, §39 |
| L2 | **Adaptive layout** driven by window constraints / safe areas / a11y — not device model alone. Tablet recomposes intentionally; game aspect ratio and hitboxes stay aligned. | Blueprint §39.1 |
| L3 | **ADR-018 orientation (PO Approved / Accepted 2026-10-27):** see §2. | Blueprint §40 / ADR-018 |
| L4 | **Preserve app state** across orientation transitions (and permitted window-size changes). | ADR-018 |
| L5 | **QA-UI-001** must cover relevant orientations for each surface; F-034 phone+tablet viewport/safe-area cases remain mandatory for UI work. | ADR-018, §28.9, §39.2 |
| L6 | **Web Parent Dashboard** is responsive on desktop + mobile browsers; **no orientation lock**. | ADR-018, §39 |
| L7 | **Operations Admin Console** is a separate V1 protected web surface (not Kids Mode). | Blueprint Target, F-027 |
| L8 | **F-020** Day-1 locales `tr-TR` + `en-US`; a11y (reduced motion, touch targets, parent screen reader, contrast, sound-off) equal on phone and tablet. | F-020, §39.1 |
| L9 | **F-022 / ADR-013:** core error capture ON; optional vendor/adapters OFF by default; no child profiling for observability. | F-022, §31, ADR-013 |
| L10 | **Staging isolation (F-028 / §26.1):** staging must not share prod DB, bucket, auth tenant, signing secret, or payment credentials; no real child data in staging. | F-028, §26.1 |
| L11 | **Two private repos (ADR-014):** client + backend; one Jira LMP; pinned OpenAPI; Blueprint must not diverge. | ADR-014 |
| L12 | CI represents compact phone, large phone, and tablet viewports; launch QA includes ≥1 physical phone + ≥1 tablet **per** platform. | §39.2 |

**Non-negotiable:** Little Minds V1 supports **both phone and tablet**. This matrix does not authorize deferring tablet.

---

## 2. LOCKED orientation policy (ADR-018)

| Surface | Orientation policy | Class |
|---|---|---|
| Child Hub | Landscape-only | **LOCKED** |
| All educational mini-games | Landscape-only | **LOCKED** |
| Game results and rewards | Landscape-only | **LOCKED** |
| Child profile selection | Landscape-only | **LOCKED** |
| Native Parent Gate & Parent Settings | Portrait + landscape | **LOCKED** |
| Next.js Parent Dashboard | Responsive; no orientation lock | **LOCKED** |

State preservation and QA-UI-001 orientation coverage are **LOCKED** (ADR-018).

---

## 3. TECHNICAL ASSUMPTIONS — need PO approval

Blueprint §39.2 item 4 leaves numeric min OS, breakpoints, and some matrix values to Day-1 documentation. Until PO approves, treat the following as **assumptions only**.

### 3.1 Minimum OS — TECHNICAL ASSUMPTION ⏳

| Platform | Proposed min | Notes | PO |
|---|---|---|---|
| iOS (iPhone + iPad) | **iOS 16.0+** | Modern Flutter/plugin baseline; multitasking APIs | ☐ Approve / ☐ Change: ___ |
| Android (phone + tablet) | **Android 10 (API 29)+** | Scoped storage / security balance | ☐ Approve / ☐ Change: ___ |

Not specified here (open): upper OS ceiling, named oldest physical device SKUs, foldable as a separate class.

### 3.2 Adaptive breakpoints (logical width) — TECHNICAL ASSUMPTION ⏳

Driven by **available window width**, not device model:

| Class | Logical width (dp / CSS px) | Use |
|---|---|---|
| Compact (phone) | `< 600` | Single column; Kids + Parent compact |
| Medium (large phone / small tablet window) | `600 – 839` | Transition; controlled Parent expansion |
| Expanded (tablet) | `≥ 840` | Parent multi-column; Kids tablet recompose |

Web Parent / Admin: same class logic via CSS/container queries; desktop typically Expanded+.

☐ Approve · ☐ Change: ___

### 3.3 CI viewport set — TECHNICAL ASSUMPTION ⏳

| Class | Proposed logical size | PO |
|---|---|---|
| Compact phone | ~390×844 | ☐ |
| Large phone | ~430×932 | ☐ |
| Tablet | ~1024×1366 | ☐ |

### 3.4 Other Day-1 matrix values — TECHNICAL ASSUMPTION ⏳

| Area | Proposal | PO |
|---|---|---|
| Text scale QA | At least 100% and one larger accessibility scale per form factor | ☐ |
| Multitasking | iPad Stage Manager / split; Android multi-window — “where supported”; P0 journeys must not break | ☐ |
| Pixel density | 1x / 2x / 3x assets; no blurry tablet upscale (§39.1) | ☐ (aligned with LOCKED L2) |
| Physical QA models | ≥1 iPhone + ≥1 iPad; ≥1 Android phone + ≥1 Android tablet — **models TBD by PO** | ☐ models: ___ |
| Content Admin browser QA | Desktop-first; tablet/mobile browser “usable” but not primary Day-1 matrix cell | ☐ confirm |

---

## 4. Device support matrix

**Legend:** ✅ = V1 P0 first-class · 🔶 = responsive / supported surface · ⏳ = TECHNICAL ASSUMPTION · — = N/A

### 4.1 Mobile — Kids Mode + embedded Parent Dashboard (F-034)

| Platform | Form factor | Min OS | Orientation | Breakpoint class | F-020 | F-022 boundary | Staging flavor |
|---|---|---|---|---|---|---|---|
| iOS | Phone | iOS 16+ ⏳ | ADR-018 (**LOCKED**) | Compact / Medium ⏳ | tr-TR, en-US; a11y | Core ON; adapters OFF default | `development` / `staging` / `production` |
| iOS | Tablet | iOS 16+ ⏳ | ADR-018 (**LOCKED**) | Expanded (by window) ⏳ | Same | Same | Same |
| Android | Phone | API 29+ ⏳ | ADR-018 (**LOCKED**) | Compact / Medium ⏳ | Same | Same | Same |
| Android | Tablet | API 29+ ⏳ | ADR-018 (**LOCKED**) | Expanded ⏳ | Same | Same | Same |

### 4.2 Web

| Surface | Support | Orientation | Notes |
|---|---|---|---|
| Next.js Parent Dashboard | 🔶 Desktop + mobile browser | No lock (**LOCKED** ADR-018) | F-015; KPI/consent parity with mobile |
| Operations Admin Console | 🔶 Protected web | N/A / browser | F-027; mobile-admin Day-1 priority is **TECHNICAL ASSUMPTION** (§3.4) |

### 4.3 Staging isolation (embedded)

Every mobile flavor and web staging deployment uses **separate** API URL, app id (where needed), auth tenant, secret store, and bucket. No production credentials. Synthetic seed only. See [environments-staging-isolation.md](./environments-staging-isolation.md).

---

## 5. Feature mapping

| Feature / ADR | Role in this matrix |
|---|---|
| **F-034** | Four mobile cells + adaptive + orientation + CI/physical QA |
| **ADR-018** | Orientation rows (**LOCKED**) |
| **F-020** | Locale + a11y equality per cell |
| **F-022 / ADR-013** | Observability boundary |
| **F-028 / §26** | Staging column + isolation |
| **ADR-014** | Client canonical matrix; backend pointer doc |
| **QA-UI-001 §28.9** | LMP-19 ships non-UI doc/structure checks; Flutter/Next viewport tests belong to UI tasks (e.g. LMP-24/31+) |

---

## 6. Testing notes for LMP-19 (non-UI)

This task does **not** scaffold Flutter or Next.js UI. Per QA-UI-001 non-UI path:

- Automated checks: required docs exist; LOCKED vs TECHNICAL ASSUMPTION labels present; ADR-018 surfaces listed; F-034 four mobile cells present; ADR index lists Approved ADRs.
- Justified exception: phone/tablet **widget/E2E** orientation suites deferred until UI exists; reviewers must accept this exception on the PR.

---

## 7. Change log

| Date | Change |
|---|---|
| 2026-10-27 | Initial LMP-19 matrix: LOCKED F-034 + ADR-018; TECHNICAL ASSUMPTIONS for min OS, breakpoints, CI viewports. |
