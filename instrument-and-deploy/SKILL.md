---
name: instrument-and-deploy
description: Add telemetry so a change can be watched in production, write release notes, and run the launch checklist. Use when the user asks to add logging/metrics/tracing or alerts, prepare a release or changelog, plan or execute a deploy, define rollback, or verify a change after it ships. Triggers include "add monitoring", "instrument this", "release notes", "changelog", "ship it", "deploy checklist", "rollback plan", "post-deploy verification".
---

# Instrument & Deploy

Turn a merged change into a shipped, observable change. Three phases, in order — instrument before you deploy, because the deploy is what you need to watch.

Ask which phases are wanted if it isn't clear. Instrumenting is safe to do unprompted; **deploying is not** — see Rules.

---

## Phase 1 — Instrument

Work out what you'd need to answer *"is this change working in production?"* at 3am, then add exactly that.

1. **Name the change's failure modes.** For each: how would we notice? If the answer is "a user tells us", it needs instrumentation.
2. **Pick the signal type** per `references/telemetry-guide.md`:
   - **Metric** — a number you'd graph or alert on (rate, latency, error count, queue depth, business counter).
   - **Log** — a discrete event you'd need context for while debugging. Structured fields, not string interpolation.
   - **Trace span** — a step in a request whose latency or failure you'd want attributed.
   - **Event** — a product/business action for analytics.
3. **Follow the codebase's existing conventions.** Find the current logger, metric client, and naming scheme first; do not introduce a second telemetry stack.
4. **Define alerts** on user-visible symptoms (error rate, latency, success rate), not on causes (CPU, restart count). Every alert needs a threshold, a window, and a stated action — an alert nobody can act on gets muted and then ignored.
5. **Add a dashboard row or panel** covering the change: request rate, error rate, p95 latency, and the change's own key counter.

Rules for instrumentation:
- **Never log secrets, tokens, passwords, full PII, card data, or raw request bodies.** Log identifiers, not contents.
- Bound cardinality: no user ids, emails, request ids, or raw URLs as metric labels.
- Don't log inside a hot loop; sample or aggregate.
- Telemetry must not break the request — no unhandled exceptions from a metrics call, no blocking network write on the critical path.
- Log levels mean something: `error` = someone must act, `warn` = degraded but handled, `info` = state change worth keeping, `debug` = off in production.

## Phase 2 — Release notes

Write from the reader's point of view, not the commit log's. Use `assets/release-notes-template.md`.

```bash
git log --oneline <last-tag>..HEAD
gh pr list --state merged --base main --limit 30 --json number,title,labels
```

- Group as **Added / Changed / Fixed / Deprecated / Removed / Security**.
- One line per user-visible change, in plain language. Drop pure refactors, chores, and test-only commits.
- Call out breaking changes at the top with the migration step.
- Note anything behind a feature flag and its default.
- Credit contributors and link PRs/issues.
- Version per semver: breaking → major, additive → minor, fix-only → patch.

## Phase 3 — Launch

Run `references/launch-checklist.md`. The short form:

**Before:** CI green on the exact commit · migrations reviewed and backward-compatible · rollback path known and tested · flags at intended defaults · secrets/config present in the target environment · telemetry from Phase 1 deployed and confirmed reporting · owner on point · stakeholders told.

**Deploy:** smallest safe increment (canary → percentage → full) · watch the Phase 1 dashboard through each step · migrate schema before code that needs it, expand-then-contract · do not batch an unrelated change into a risky deploy.

**After:** verify the specific behavior that changed, in production, deliberately — not "the site loads" · compare error rate, latency, and the change's counter against the pre-deploy baseline · hold a watch window (15–60 min by risk) before declaring done · then update the changelog/tag/docs and close out.

**If it goes wrong:** roll back first, diagnose after. Say plainly what happened, what the impact was, and what the next attempt changes.

---

## Rules

- **Deploying is an outward-facing, hard-to-reverse action. Confirm with the user before running any deploy, release, tag-push, or migration command, unless they have explicitly told you to proceed without asking.** Approval for one deploy is not approval for the next.
- Report the deploy honestly. If a check failed, was skipped, or you could not verify a step, say which and why. Never describe a deploy as verified when you only confirmed it started.
- Don't invent metric names, dashboard URLs, alert destinations, or environment names. Find them in the repo/config, or ask.
- Post-deploy verification means observing the changed behavior. Absence of alerts is not verification.

## Reference

- `references/telemetry-guide.md` — what to instrument, naming, cardinality, alerting
- `references/launch-checklist.md` — full pre/during/post checklist with rollback and incident steps
- `assets/release-notes-template.md` — release notes skeleton
- `scripts/preflight.sh` — mechanical pre-deploy checks (branch, CI, migrations, secrets, changelog)
