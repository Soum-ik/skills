# <Product> v<X.Y.Z>

_<YYYY-MM-DD>_

<One or two sentences: what this release is about, from a user's point of view. Skip if the sections speak for themselves.>

## ⚠️ Breaking changes

<Delete this section if there are none. If there are any, they go first, always.>

- **<What broke>** — <what you must do to migrate>. (#PR)

## Added

- <New capability, in plain language — what a user can now do.> (#PR)

## Changed

- <Behavior that is different now, and what a user will notice.> (#PR)

## Fixed

- <The symptom the user experienced, not the internal cause.> (#PR)

## Deprecated

- <What is now discouraged, what replaces it, and when it will be removed.> (#PR)

## Removed

- <What is gone, and what to use instead.> (#PR)

## Security

- <Fixed vulnerability class and severity. No exploit details, no reproduction steps.> (CVE-… if assigned)

---

## Behind a flag

| Flag | Default | Notes |
|---|---|---|
| `<flag_name>` | off | <who it's enabled for, when it goes to 100%> |

## Upgrade notes

- <Required migration, config change, or new env var.>
- <Minimum version of a dependency or client.>
- <Expected migration runtime / downtime, if any.>

## Monitoring

- Dashboard: <link>
- Key signals to watch: <metric names>
- New alerts: <names>

## Contributors

<@handles, or "Thanks to …">

---

<!--
Writing notes:
- One line per user-visible change. Omit refactors, chores, dependency bumps
  with no user effect, and test-only work.
- Describe the effect, not the implementation. "Exports now include archived
  projects" — not "changed the WHERE clause in exportQuery".
- Lead each Fixed line with the symptom the user saw.
- Semver: breaking -> major, additive -> minor, fix-only -> patch.
- Generate the raw material with:
    git log --oneline <last-tag>..HEAD
    gh pr list --state merged --base main --limit 50 --json number,title,labels
  then rewrite it for humans. Do not paste the commit log.
-->
