# Launch checklist

Confirm with the user before executing any step that changes a live environment.

## Pre-deploy

**Code and CI**
- [ ] The exact commit being deployed is identified (`git rev-parse HEAD`) and CI is green *on that commit*, not on the branch generally.
- [ ] Review complete; no unresolved blocking findings.
- [ ] No debug code, commented-out blocks, or temporary logging left in.
- [ ] Version bumped and tagged per semver; changelog entry written.

**Data and schema**
- [ ] Migrations are backward-compatible with the currently-running code (expand now, contract in a later release).
- [ ] No `NOT NULL` add, column type change, or index build that locks a large table during traffic — use the online/concurrent variant.
- [ ] Migration tested against a production-sized copy; runtime estimated.
- [ ] Backfills are batched, resumable, and rate-limited.
- [ ] A backup or restore point exists, and you know the restore procedure.
- [ ] Down-migration written, or documented as intentionally irreversible with the reason.

**Configuration**
- [ ] New env vars, secrets, and config keys exist in the target environment, with the right values.
- [ ] Feature flags at their intended launch defaults (usually: off, enabled by percentage after).
- [ ] Third-party credentials, quotas, and webhooks configured for the target environment.
- [ ] Infrastructure changes (queues, buckets, cron, workers, scaling limits) applied first.

**Observability** — from Phase 1
- [ ] Metrics, logs, traces for the change are deployed and confirmed reporting.
- [ ] Dashboard panel exists; pre-deploy baseline values recorded (error rate, p95, key counter) so "after" has something to compare to.
- [ ] Alerts created and their routing verified.

**Rollback**
- [ ] The rollback command is written down before deploying, not improvised after.
- [ ] Rollback is safe with the migration already applied — if not, the change must be split.
- [ ] Kill switch or flag exists to disable the new behavior without a redeploy.
- [ ] Rollback tested in staging if this is a high-risk change.

**People**
- [ ] Deploy window is appropriate — not Friday evening, not during a peak or a marketing push, unless it's a fix for something worse.
- [ ] A named person is watching, with time to watch.
- [ ] Support, on-call, and any dependent teams notified of what is changing and what to look for.
- [ ] Docs, API reference, and status/announcement copy ready if user-visible.

## During deploy

- [ ] Deploy the smallest safe increment: one canary instance → 5% → 25% → 100%, or staging → production.
- [ ] Migrations run before the code that requires them; contracting migrations run after the old code is gone.
- [ ] Watch the dashboard between increments — error rate, latency, and the change's own counter. Do not advance on a clean *deploy log*; advance on clean *signals*.
- [ ] Tail error logs for new exception types, not just for volume.
- [ ] Do not bundle unrelated changes into a risky deploy — it destroys your ability to attribute a regression.
- [ ] Record the deploy time so the dashboard annotation lines up.

Abort criteria, decided in advance: error rate above the baseline by X, p95 above Y, any new exception class, or the domain counter not moving.

## Post-deploy verification

Verification means **observing the specific behavior that changed**.

- [ ] Exercise the changed path in production deliberately — the new endpoint, the new flow, the new job — and confirm the correct result.
- [ ] Confirm the new telemetry is emitting real data (not zero, not the pre-deploy baseline).
- [ ] Compare against the recorded baseline: error rate, p95/p99 latency, throughput, domain counter.
- [ ] Check dependents: downstream services, queue depth and consumer lag, DB CPU and slow-query log, cache hit rate.
- [ ] Check the previous version's traffic drained (no stragglers on old instances holding stale schema assumptions).
- [ ] Hold a watch window before declaring success: **15 min** low-risk, **1 hour** normal, **through the next peak** for high-risk or migration-bearing changes.
- [ ] For a flagged rollout, enable by percentage and re-verify at each step rather than treating 5% success as done.

**"No alerts fired" is not verification.** Alerts cover the failures you predicted; you deployed to change behavior, so go look at the behavior.

## Close-out

- [ ] Changelog published; tag pushed; release notes shared where users will see them.
- [ ] Docs, runbook, and architecture notes updated.
- [ ] Feature flag cleanup scheduled (a flag with no removal date becomes permanent complexity).
- [ ] Contracting migration scheduled if the deploy used expand-then-contract.
- [ ] Anything deferred during launch filed as an issue with an owner.
- [ ] Report to the user: what shipped, what was verified and how, what remains open.

## If it goes wrong

1. **Roll back or flip the kill switch first.** Diagnose after service is restored. Time spent debugging a live regression is time users spend broken.
2. Preserve evidence before it ages out: logs, traces, metric screenshots, error samples, the affected id range.
3. Assess blast radius: how many users, which data, for how long. Was anything written incorrectly? Does it need a repair backfill?
4. Communicate: tell on-call, support, and affected stakeholders what happened and what the current state is. Do not minimize it.
5. Fix forward only if the fix is small, understood, and testable; otherwise stay rolled back.
6. Write down the cause, the detection gap (why didn't we see it sooner?), and the specific change to the next attempt — a check, a test, an alert, or a smaller increment.
