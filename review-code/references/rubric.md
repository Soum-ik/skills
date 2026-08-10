# Review rubric

Ordered by what actually causes damage. Spend your attention proportionally — most of it on §1.

## 1. Correctness

- **Boundaries.** Empty collection, single element, exactly-at-limit, one past the limit. Off-by-one in slices, ranges, pagination.
- **Nullability.** Can this be null/None/undefined here? What does the caller do with it? Optional chaining that silently yields `undefined` into arithmetic.
- **Error paths.** Every `catch`/`except`: does it swallow something the caller needed? Is a partial write left behind? Is the error surfaced or logged and forgotten?
- **State machines and ordering.** Can the operations happen in a different order? Is a field read before it is set?
- **Concurrency.** Shared mutable state without a lock; read-modify-write without a transaction or compare-and-set; `await` between a check and its dependent action; unbounded parallelism.
- **Idempotency and retries.** If this runs twice (retry, duplicate webhook, at-least-once queue), what breaks? Does it need a dedupe key?
- **Transactions.** Are the writes that must succeed together actually in one transaction? Is external I/O (email, webhook, charge) inside a transaction that may roll back?
- **Time and timezones.** Naive vs aware datetimes, DST, clock skew, expiry compared in the wrong unit (s vs ms).
- **Numerics.** Float money, integer division, overflow, rounding direction, unit mismatch.
- **Migrations.** Is the schema change backward-compatible with the running code during deploy? Does a `NOT NULL` add lock the table? Is there a rollback?
- **Backward compatibility.** Changed signature, response shape, enum value, default, or error code — who else consumes it? Grep the callers.
- **Comment/name vs behavior.** Where they disagree, one of them is a bug. Say which.

## 2. Security

Full checklist lives in the `enforce-security` skill. In a general review, always check:

- New endpoint or handler: is it authenticated and authorized, with the tenant/user scope in the query?
- Any user input reaching SQL, shell, a path, a template, a URL fetch, or `eval`?
- Secrets, tokens, or PII newly present in source, logs, or responses?
- Escape hatches: `innerHTML`, `raw()`, `shell=True`, `verify=False`, `Math.random()` for tokens.

Anything found here is Blocking by default.

## 3. Performance

Care only where it is reachable at real scale — say which path and roughly how often it runs.

- **N+1 queries / requests** — a query or fetch inside a loop over user-sized data.
- **Unbounded results** — a query with no `LIMIT`, loading a whole table or file into memory.
- **Missing index** for a new query's filter/sort columns.
- **Accidental quadratic** — `list.includes` inside a loop, repeated string concatenation, re-sorting per iteration.
- **Repeated work** — the same computation or call inside a loop that could be hoisted; a cache that is never hit because the key varies.
- **Blocking the event loop / request thread** — sync file or CPU-heavy work in an async handler.
- **Payload size** — over-fetching fields, missing pagination, no compression on a large response.
- **Frontend** — render in a loop without memo/key, layout thrash, a dependency array that makes an effect fire every render, bundle growth from a heavyweight import.

Do not report micro-optimizations on cold paths.

## 4. Design

- **Right place.** Does this logic belong in this layer? Business rules in a controller, HTTP concerns in a domain model, and SQL in a view are all misplacements.
- **Reuse.** Does an existing helper, type, or constant already do this? Duplicated logic that must change together is a defect, not a style issue.
- **Abstraction altitude.** One caller does not justify an interface; three near-copies do justify extraction. Flag both over- and under-abstraction, but only when it has a concrete cost.
- **Coupling.** New import direction that inverts the layering; a module reaching into another's internals; a shared mutable singleton.
- **Interface shape.** Booleans that should be enums, four positional parameters, a function that returns different types by branch, a required argument that is always the same value.
- **Dead ends.** Unused parameters, unreachable branches, flags with one value, code behind a permanently-false condition.
- **Configuration.** Magic numbers that should be named; hardcoded environment values; a new env var with no default and no documentation.
- **Dependencies.** A new package for something the stdlib does; a heavy dependency for one function.

## 5. Readability

- Names say what the thing is, in the domain's vocabulary; no `data`, `tmp`, `helper2`, `flag`.
- Control flow is shallow — early returns over nesting; a function that needs a scroll to understand.
- Comments explain *why*, never *what*. Delete comments that restate the code; require them where a choice is non-obvious.
- Consistency with the surrounding file: same error style, same async style, same naming, same import order.
- No commented-out code, leftover debug prints, or TODOs without an owner or issue.

## 6. Tests

- Does a test actually fail without the change? If not, the change isn't covered.
- Are the *edge cases from §1* tested, not just the happy path?
- Negative tests for auth and validation.
- No assertions on implementation details that make refactoring painful; no `sleep` for synchronization; no shared mutable fixtures across tests; no dependence on test ordering, wall-clock time, or network.
- Fixtures contain no real credentials or real user data.
- If the change is a bug fix, there is a regression test that reproduces the original bug.

## 7. Operability

- New failure modes are logged with enough context to debug (ids, not just messages) and without secrets.
- Metrics or alerts for anything whose silent failure would matter — handoff to the `instrument-and-deploy` skill.
- Feature-flagged or otherwise reversible if the blast radius is large.
- Docs, changelog, or runbook updated when behavior visible to others changed.
