# Security review checklist

Walk each section. Skip a section only when the diff cannot reach it, and say so in "Checked and clear".

## 1. Authentication
- [ ] New endpoints/routes/handlers require auth by default; the framework's default is not "public".
- [ ] Session/token validation is on the server, not inferred from a client-supplied claim.
- [ ] Token expiry, audience, issuer, and signature algorithm are all verified (no `alg: none`, no `verify=False`).
- [ ] Password/credential comparison is constant-time; hashing is bcrypt/scrypt/argon2, not SHA-*.
- [ ] Login, reset, and MFA flows are rate-limited and do not leak account existence.

## 2. Authorization
- [ ] Every read and write scopes by the caller's identity — `WHERE tenant_id = :caller`, not just `WHERE id = :id`.
- [ ] Object IDs from the request are authorized, not trusted (IDOR).
- [ ] Role checks happen server-side; hiding UI is not authorization.
- [ ] Privilege escalation paths: can a user set their own `role`, `is_admin`, `plan`, or `owner_id` via mass-assignment?

## 3. Injection
- [ ] SQL: parameterized queries or ORM bindings; no string-built WHERE/ORDER BY. Dynamic identifiers use an allowlist.
- [ ] NoSQL: user input cannot supply operators (`$ne`, `$gt`, `$where`).
- [ ] Shell: no user data in `exec`/`system`/`sh -c`; use argv arrays. No `shell=True` with interpolation.
- [ ] Templates/eval: no `eval`, `new Function`, `pickle.loads`, `yaml.load` (unsafe loader) on untrusted input.
- [ ] Path: user-supplied filenames are normalized and confined to a base dir (no `../`, no absolute paths, no symlink escape).
- [ ] Deserialization of untrusted data uses a schema, not arbitrary type reconstruction.

## 4. Output handling
- [ ] HTML escaping is on by default; any `dangerouslySetInnerHTML` / `v-html` / `|safe` / `innerHTML` has a sanitizer.
- [ ] URLs built from input are validated against a scheme allowlist (`javascript:`, `data:` blocked).
- [ ] Redirects use a destination allowlist (no open redirect).
- [ ] Content-Type and `X-Content-Type-Options` are correct for user-uploaded content; uploads are not served from the app origin when avoidable.

## 5. Server-side request forgery & outbound calls
- [ ] URLs fetched by the server are validated: scheme allowlist, DNS resolution checked against private/link-local ranges, redirects not blindly followed.
- [ ] Cloud metadata endpoints are unreachable from user-influenced fetches.

## 6. Secrets & configuration
- [ ] No credentials, tokens, private keys, or connection strings in source, tests, fixtures, or committed config.
- [ ] Secrets come from env/secret manager; `.env` and key files are gitignored.
- [ ] Debug modes, verbose errors, stack traces, and permissive CORS (`*` with credentials) are not enabled for production paths.
- [ ] Default/sample credentials are not accepted at runtime.

## 7. Data protection & privacy
- [ ] Sensitive fields (passwords, tokens, PII, payment data) are absent from logs, analytics events, error reports, and API responses.
- [ ] TLS is required for outbound calls; certificate verification is not disabled.
- [ ] Encryption at rest where required; keys are not co-located with ciphertext.
- [ ] Data retention/deletion honored for anything new that is stored.

## 8. Session & browser surface
- [ ] Cookies: `HttpOnly`, `Secure`, `SameSite` set appropriately; session rotates on privilege change and login.
- [ ] State-changing requests are CSRF-protected (token or `SameSite` + non-GET + no CORS wildcard).
- [ ] CSP present and not defeated by `unsafe-inline`/`unsafe-eval` on pages rendering user content.
- [ ] `postMessage` handlers verify `event.origin`.

## 9. Dependencies & supply chain
- [ ] New dependencies: are they needed, maintained, and correctly named (typosquat check)?
- [ ] Lockfile updated; no install-time scripts added from an untrusted package.
- [ ] Known advisories in added/upgraded packages triaged (reachable or not).
- [ ] Pinned versions or integrity hashes for anything fetched at build time.

## 10. Denial of service & resource limits
- [ ] Request body, upload, and pagination sizes are bounded.
- [ ] No unbounded loops/recursion/regex backtracking on user input (ReDoS).
- [ ] Expensive operations behind auth and rate limits; timeouts set on outbound calls.

## 11. Cryptography
- [ ] No custom crypto. Standard library or vetted library only.
- [ ] Randomness for tokens/IDs/salts is cryptographically secure (`crypto.randomBytes`, `secrets`, `os.urandom` — not `Math.random`/`rand`).
- [ ] Correct modes and unique IVs/nonces; MAC or AEAD used, verified before decryption.

## 12. Infrastructure-as-code & CI (if the diff touches it)
- [ ] No publicly open storage buckets, security groups, or databases.
- [ ] CI workflows do not expose secrets to untrusted PR triggers (`pull_request_target` + checkout of PR head).
- [ ] Least-privilege IAM; no wildcard `*` actions on `*` resources.
- [ ] Container images pinned by digest where practical; no running as root without reason.

## 13. Tests & guardrails
- [ ] Security-relevant behavior has a negative test (unauthorized caller gets 403, malformed token rejected).
- [ ] Fixtures do not contain real credentials or real PII.
