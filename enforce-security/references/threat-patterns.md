# Vulnerable patterns → safe forms

Language-specific shapes to recognize in a diff. The left column is what to grep for; the right is the fix to propose.

## SQL injection

```python
# VULNERABLE
cur.execute(f"SELECT * FROM users WHERE email = '{email}'")
# SAFE
cur.execute("SELECT * FROM users WHERE email = %s", (email,))
```

```js
// VULNERABLE
db.query(`SELECT * FROM t ORDER BY ${col} ${dir}`)
// SAFE — identifiers need an allowlist, not a bind param
const COLS = {name: 'name', created: 'created_at'}
const DIRS = {asc: 'ASC', desc: 'DESC'}
db.query(`SELECT * FROM t ORDER BY ${COLS[col] ?? 'name'} ${DIRS[dir] ?? 'ASC'}`)
```

ORM escape hatches are still injection: `raw()`, `literal()`, `.whereRaw()`, `text()`, `extra()`.

## Broken object-level authorization (IDOR)

```js
// VULNERABLE — any authenticated user reads any invoice
const inv = await Invoice.findById(req.params.id)
// SAFE — ownership is part of the query, not a later check
const inv = await Invoice.findOne({_id: req.params.id, orgId: req.user.orgId})
if (!inv) return res.status(404).end()
```

Return 404 rather than 403 when existence itself is sensitive.

## Mass assignment / privilege escalation

```js
// VULNERABLE
await User.update(req.user.id, req.body)
// SAFE
const {displayName, timezone} = req.body
await User.update(req.user.id, {displayName, timezone})
```

## Command injection

```python
# VULNERABLE
subprocess.run(f"convert {path} out.png", shell=True)
# SAFE
subprocess.run(["convert", path, "out.png"], shell=False, timeout=30)
```

Even with argv arrays, validate that `path` cannot start with `-` (argument injection).

## Path traversal

```python
# VULNERABLE
open(os.path.join(BASE, user_name))
# SAFE
target = (BASE / user_name).resolve()
if not target.is_relative_to(BASE.resolve()):
    raise ValueError("path escape")
```

## XSS

```jsx
// VULNERABLE
<div dangerouslySetInnerHTML={{__html: comment.body}} />
// SAFE
<div>{comment.body}</div>                       // escaped by default
<div dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(comment.body)}} />  // if HTML is required
```

Attribute sinks matter too: `href={userUrl}` allows `javascript:`. Validate the scheme.

## SSRF

```js
// VULNERABLE
const r = await fetch(req.body.webhookUrl)
// SAFE
const u = new URL(req.body.webhookUrl)
if (u.protocol !== 'https:') throw new Error('scheme')
const {address} = await dns.promises.lookup(u.hostname)
if (isPrivate(address)) throw new Error('private range')
await fetch(u, {redirect: 'manual', signal: AbortSignal.timeout(5000)})
```

Resolve-then-connect races exist; prefer an egress proxy or allowlist for high-value paths.

## Weak randomness and timing

```js
// VULNERABLE
const token = Math.random().toString(36).slice(2)
if (token === expected) {...}
// SAFE
const token = crypto.randomBytes(32).toString('base64url')
crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expected))
```

## JWT misuse

```js
// VULNERABLE
jwt.decode(token)                                  // no signature check
jwt.verify(token, secret)                          // algorithm not pinned
// SAFE
jwt.verify(token, key, {algorithms: ['RS256'], issuer: ISS, audience: AUD})
```

## Deserialization

Unsafe: `pickle.loads`, `yaml.load(s)`, `Marshal.load`, Java `ObjectInputStream`, `unserialize()`.
Safe: `json.loads` + schema validation, `yaml.safe_load`, protobuf/typed decoders.

## ReDoS

```
# VULNERABLE — nested quantifier over user input
^(\s*\w+\s*,)+$
# SAFE — bound input length, simplify, or use a non-backtracking engine
```

## CI secret exposure

```yaml
# VULNERABLE — runs untrusted PR code with repo secrets in scope
on: pull_request_target
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with: {ref: "${{ github.event.pull_request.head.sha }}"}
      - run: npm test          # attacker-controlled, sees secrets
```

Use `pull_request` for untrusted code, or split into a privileged job that never checks out PR code.

## Secrets in history

Removing a secret in a new commit does not remove it from history. The fix is: rotate the credential, then (optionally) rewrite history. Always state rotation first.
