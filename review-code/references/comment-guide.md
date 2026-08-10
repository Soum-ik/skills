# Writing findings authors act on

A finding is a claim about a defect, addressed to someone who knows the code better than you do.

## Every finding has four parts

1. **Location** — `file:line`. Not "in the auth module".
2. **Claim** — what is wrong, in one sentence, stated as a fact about the code.
3. **Consequence** — the concrete failure: which inputs or state, which wrong outcome. If you cannot write this, you do not have a finding.
4. **Fix** — the smallest change that resolves it. Code if it fits on three lines.

## Good vs bad

Bad: *"This error handling could be improved."*
Good: *`sync.py:112` — the bare `except` swallows `KeyError` from `payload["id"]`, so a malformed webhook is recorded as processed and never retried. Catch `RequestError` specifically and let the rest propagate.*

Bad: *"Consider using a set here for performance."*
Good: *`report.ts:44` — `allowedIds.includes(row.id)` inside a loop over `rows` makes this O(n·m); with the ~40k rows this report pulls, that's ~10⁸ comparisons. Build `new Set(allowedIds)` once above the loop.*

Bad: *"Are you sure this is thread-safe?"*
Good: *`counter.go:31` — `c.total++` runs from multiple goroutines with no lock, so counts are lost under concurrency. Use `atomic.AddInt64` or guard with `c.mu`.*

## Rules of tone

- Address the code, not the author: "this returns", not "you forgot".
- No hedging stacks. "It seems like it might possibly be the case that" → say it or drop it.
- No praise padding before a criticism. If the design is good, say so once, in Notes.
- Ask a real question only when you genuinely don't know — and say what answer would change your view: *"Is `orgId` guaranteed set by the middleware here? If not, this query returns cross-tenant rows."*
- State severity explicitly. An author cannot tell a nit from a data-loss bug by tone alone.

## Calibration

- Do not report the same issue at five call sites. Report it once, note that it recurs, list the lines.
- Do not report what the linter, formatter, or type checker already reports.
- Do not restate the diff back as a finding.
- If you looked at something risky and it was fine, say that in Notes. Coverage is information.
- When you are unsure, label it: *"Unverified — I could not find where `retryCount` is reset; if it isn't, this loops forever."* That is honest and useful. A confident-sounding guess is neither.

## Ordering

Most severe first, always. Within a severity, group by file so the author reads each file once. Nits last, or omitted.
