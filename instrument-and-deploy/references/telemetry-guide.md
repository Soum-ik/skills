# Telemetry guide

## Choosing the signal

| You want to… | Use | Cost shape |
|---|---|---|
| Alert, graph a trend, compare to a baseline | **Metric** | cheap, but cardinality-limited |
| Reconstruct what happened for one request | **Log** | expensive per event, keep it structured |
| See where latency went inside a request | **Trace span** | sampled; attribute to a step |
| Answer a product question later | **Analytics event** | schema matters more than volume |

Rule of thumb: if you would ever put it on a graph, it is a metric. If you would only ever read it while debugging one case, it is a log.

## The four signals worth adding to almost any change

1. **Throughput** — how often does this path run? (`counter`)
2. **Errors** — how often does it fail, by failure class? (`counter` with a low-cardinality `reason` label)
3. **Latency** — how long does it take? (`histogram`, look at p50/p95/p99, never the mean alone)
4. **A domain counter** — the thing the change is actually for (orders placed, files indexed, emails sent).

For queues and background work add **depth** and **age of oldest item** — the two numbers that reveal a stuck consumer.

## Naming

- Follow whatever the codebase already does. Only if there is no convention:
  `<service>.<subsystem>.<thing>_<unit>` → `billing.invoice.render_duration_ms`, `billing.invoice.render_total`.
- Units in the name (`_ms`, `_bytes`, `_total`). No abbreviations that aren't already used in the domain.
- Counters are cumulative and monotonic; name them `_total` and let the query compute the rate.

## Cardinality — the main way metrics break

Every distinct label-value combination is a separate time series. Bounded values only.

**Safe labels:** `env`, `region`, `route` (the *template*, `/users/:id`), `method`, `status_class` (`2xx`), `error_reason` (from a fixed enum), `plan`, `feature_flag_variant`.

**Never labels:** user id, org id (unless you truly have few), email, request id, session id, raw URL or path with ids in it, full error message, timestamp, IP, SQL text.

Those belong in a log line or a trace attribute, where high cardinality is fine.

## Structured logging

```js
// Bad — unparseable, and it leaks
logger.info(`charging ${user.email} card ${card.number} for ${amt}`)

// Good — fields, ids not contents, one event name
logger.info('payment.charge.attempt', {
  userId: user.id, invoiceId: inv.id, amountCents: amt, currency: 'usd',
  cardLast4: card.last4, attempt: n,
})
```

- A stable event name plus fields. Never interpolate variables into the message string.
- Include the correlation/trace id on every line so a request can be reassembled.
- Log the *decision*, not just the entry and exit: which branch, and why.
- On error: log once, at the boundary that handles it. Logging and rethrowing at every layer produces four copies of one incident.

### Never log
Passwords, tokens, API keys, session cookies, auth headers, full card numbers or CVV, government ids, full request/response bodies on authenticated endpoints, decrypted PII. Redact at the logger with a field allowlist or denylist, so a future field can't leak by accident.

## Tracing

- One span per meaningful unit of work: an outbound HTTP call, a DB query group, a queue publish, an expensive computation.
- Span names are low-cardinality (`db.query.invoices_by_org`), ids go in attributes.
- Record the error on the span and set its status — a failed span with no error attribute tells you nothing.
- Propagate context across async boundaries and queue messages, or traces break exactly where you need them.

## Alerting

Alert on **symptoms users feel**:

- Error rate above X% of requests over N minutes.
- p95 latency above the SLO for N minutes.
- Success rate of a critical job below X% over a window.
- Queue oldest-item age above N minutes.
- A domain counter that should never be zero going to zero over a business-hours window.

Do **not** alert on CPU, memory, pod restarts, or a single failed request. Those are dashboard signals; they page you for things users never notice, and the noise trains everyone to ignore the real ones.

Every alert must state:

```
Name:        payment-charge-error-rate-high
Condition:   rate(payment.charge.error_total[5m]) / rate(payment.charge.total[5m]) > 0.02
For:         10m
Severity:    page | ticket
Impact:      customers cannot complete checkout
Action:      check provider status page; if provider is down, enable queue-and-retry flag
Dashboard:   <link>
Owner:       <team>
```

If you cannot fill in **Action**, it is not ready to be an alert.

Tune the window to the volume: a 2% threshold over 5 minutes fires constantly on a low-traffic endpoint. Use a longer window or an absolute-count floor.

## Dashboard

One row per change or feature, four panels: request rate, error rate (broken out by reason), latency percentiles, and the domain counter. Add an annotation marking the deploy so before/after is visible at a glance. Include a link to it in the release notes.

## Checklist

- [ ] Throughput, error, latency, and domain signals exist for the changed path
- [ ] Uses the codebase's existing logger/metric client and naming scheme
- [ ] No unbounded label values
- [ ] No secrets or PII in any log, label, span attribute, or event
- [ ] Errors logged once, at the handling boundary, with correlation id
- [ ] Alerts are symptom-based, with threshold, window, impact, and action
- [ ] Dashboard panel exists and was confirmed to be receiving data
- [ ] Telemetry cannot throw or block on the request path
