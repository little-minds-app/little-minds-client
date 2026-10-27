# Little Minds — AI Agent Instructions (Client)

## 1. Mandatory Product Blueprint

Before starting any implementation, read the latest Product Blueprint:

`docs/LITTLE_MINDS_PRODUCT_BLUEPRINT_v2.6.md`

The Blueprint is the source of truth for product requirements, architecture, quality standards, and Definition of Done.

Do not implement behavior that contradicts the Blueprint.

## 2. Jira Task Requirements

Before implementing a task:

- Retrieve the relevant `LMP-XXX` issue using Jira MCP when available.
- Review its description, acceptance criteria, and Epic context.
- Identify the relevant Blueprint requirements.
- Do not invent missing requirements. Ask for clarification when necessary.

## 3. Mandatory Automated Testing — QA-UI-001

Follow Blueprint Section 28.9 for every implementation task.

- Flutter and Flame UI changes require meaningful automated Widget Tests and/or Integration Tests.
- Next.js UI changes require appropriate Component Tests and/or E2E Tests.
- Test relevant success, validation, loading, error, empty, and recovery states.
- Test applicable phone and tablet layouts according to F-034.
- Non-UI changes require appropriate automated tests instead of unnecessary UI tests.
- Bug fixes should include regression tests when feasible.
- Document any justified testing exception in the Pull Request and obtain human reviewer approval.

Tests must be implemented as part of the same Jira task and Pull Request.

## 4. Git and Pull Request Standards

- Use a dedicated branch for each Jira implementation task.
- Every Jira-linked implementation commit must follow the Blueprint commit convention, starting with the actual `[LMP-123]` issue key and a present-tense imperative verb.
- Do not use placeholder issue keys in real commits.
- Include the Jira issue reference and testing evidence in the Pull Request.
- Documentation-only changes without a Jira issue may use the agreed `[DOCS]` prefix.

## 5. CI and Definition of Done

- Run all applicable automated tests.
- Ensure required GitHub Actions checks pass.
- Report test commands and their actual results; never claim tests passed without executing them.
- Do not mark a Jira task Done before the required tests pass and the Pull Request is reviewed and merged.
- Never silently skip required test jobs.

## 6. Agent Operating Rules

- Read the Blueprint and Jira task before changing code.
- Keep changes within the task scope.
- Preserve existing architecture and conventions.
- Never commit secrets, credentials, or real child personal data.
- Request human approval for destructive or irreversible operations.
