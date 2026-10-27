# Mentor card content (client mirror)

Canonical contract lives on **backend** LMP-47. See [PIN.md](./PIN.md).

This directory mirrors:

- `schemas/v1.schema.json` — JSON Schema `1.0.0` (reference; Dart validates structurally)
- `fixtures/near-far.*.v1.json` — Near/Far `en-US` + `tr-TR` examples
- `VERSION` — `1.0.0`

Flutter loads the fixtures from `apps/mobile/assets/content/mentor_cards/` (kept identical to `fixtures/`).
