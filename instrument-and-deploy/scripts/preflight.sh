#!/usr/bin/env bash
# Mechanical pre-deploy checks. Read-only — deploys nothing, changes nothing.
# Reports PASS / WARN / FAIL per check and exits non-zero if anything FAILed.
#
# Usage: scripts/preflight.sh [base-ref]

set -uo pipefail

BASE="${1:-}"
FAILED=0
have() { command -v "$1" >/dev/null 2>&1; }
pass() { printf '  PASS  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
hdr()  { printf '\n== %s ==\n' "$1"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repository"; exit 1; }

if [ -z "$BASE" ]; then
  git rev-parse --verify -q origin/HEAD >/dev/null 2>&1 && BASE="origin/HEAD" || BASE="HEAD"
fi

hdr "Commit under deploy"
SHA=$(git rev-parse HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
printf '  commit: %s\n  branch: %s\n' "$SHA" "$BRANCH"

hdr "Working tree"
if [ -z "$(git status --porcelain)" ]; then
  pass "clean"
else
  fail "uncommitted changes — the deployed commit would not match your tree"
  git status --short | sed 's/^/        /'
fi

hdr "Sync with remote"
if git rev-parse --verify -q "@{u}" >/dev/null 2>&1; then
  git fetch --quiet 2>/dev/null
  AHEAD=$(git rev-list --count "@{u}..HEAD")
  BEHIND=$(git rev-list --count "HEAD..@{u}")
  [ "$AHEAD" -eq 0 ] && pass "nothing unpushed" || fail "$AHEAD commit(s) not pushed"
  [ "$BEHIND" -eq 0 ] && pass "up to date with upstream" || warn "$BEHIND commit(s) behind upstream"
else
  warn "no upstream branch configured"
fi

hdr "CI status for this commit"
if have gh; then
  OUT=$(gh run list --commit "$SHA" --limit 10 \
        --json conclusion,status,name 2>/dev/null)
  if [ -z "$OUT" ] || [ "$OUT" = "[]" ]; then
    warn "no CI runs found for $SHA"
  else
    printf '%s' "$OUT" | grep -q '"conclusion":"failure"' && fail "a CI run failed on this commit" || true
    printf '%s' "$OUT" | grep -q '"status":"in_progress"' && warn "CI still running" || true
    printf '%s' "$OUT" | grep -qE '"conclusion":"(failure|cancelled|timed_out)"' || pass "no failed CI runs on this commit"
    have jq && printf '%s' "$OUT" | jq -r '.[] | "        \(.name): \(.status)/\(.conclusion // "-")"'
  fi
else
  warn "gh not installed — verify CI manually"
fi

hdr "Migrations in this change"
MIGS=$(git diff --name-only "$BASE...HEAD" 2>/dev/null \
       | grep -iE '(migrat|schema|alembic|liquibase|flyway|prisma/migrations)' || true)
if [ -z "$MIGS" ]; then
  pass "no migration files touched"
else
  warn "migrations present — confirm backward compatibility, lock behavior, and rollback"
  printf '%s\n' "$MIGS" | sed 's/^/        /'
  RISKY=$(git diff "$BASE...HEAD" -- $MIGS 2>/dev/null \
          | grep -inE '^\+.*(DROP (TABLE|COLUMN)|NOT NULL|ALTER COLUMN|RENAME|TRUNCATE|CREATE (UNIQUE )?INDEX(?! CONCURRENTLY))' || true)
  if [ -n "$RISKY" ]; then
    fail "potentially locking or destructive DDL — review each line"
    printf '%s\n' "$RISKY" | sed 's/^/        /'
  fi
fi

hdr "New configuration keys"
NEWENV=$(git diff "$BASE...HEAD" 2>/dev/null \
         | grep -E '^\+' \
         | grep -oE '(process\.env\.[A-Z0-9_]+|os\.environ(\.get\()?\[?["'\'']?[A-Z0-9_]+|getenv\(["'\'']?[A-Z0-9_]+)' \
         | grep -oE '[A-Z][A-Z0-9_]{2,}' | sort -u || true)
if [ -z "$NEWENV" ]; then
  pass "no new env var references"
else
  warn "confirm these exist in the target environment:"
  printf '%s\n' "$NEWENV" | sed 's/^/        /'
fi

hdr "Debug leftovers in changed files"
CHANGED=$(git diff --name-only "$BASE...HEAD" 2>/dev/null | sed '/^$/d')
if [ -n "$CHANGED" ] && have rg; then
  HITS=$(git diff "$BASE...HEAD" -- $CHANGED 2>/dev/null \
         | grep -nE '^\+.*(console\.log|debugger;|binding\.pry|pdb\.set_trace|breakpoint\(\)|fmt\.Println|dd\(|var_dump|TODO: ?remove|XXX)' || true)
  [ -z "$HITS" ] && pass "none found" || { warn "possible leftovers:"; printf '%s\n' "$HITS" | head -20 | sed 's/^/        /'; }
else
  warn "skipped (no changed files or rg unavailable)"
fi

hdr "Telemetry added"
TEL=$(git diff "$BASE...HEAD" 2>/dev/null \
      | grep -cE '^\+.*(logger\.|log\.(info|warn|error)|metrics\.|statsd|prometheus|histogram|counter|tracer\.|span|captureException|track\()' || true)
[ "${TEL:-0}" -gt 0 ] && pass "$TEL telemetry line(s) added" \
  || warn "no telemetry added — can this change be observed in production?"

hdr "Changelog / release notes"
if git diff --name-only "$BASE...HEAD" 2>/dev/null | grep -qiE '(CHANGELOG|RELEASE[_-]?NOTES|changes\.md)'; then
  pass "changelog updated"
else
  warn "no changelog entry in this range"
fi

hdr "Version tag"
LAST=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
printf '  last tag: %s\n' "$LAST"
[ "$LAST" != "none" ] && printf '  commits since: %s\n' "$(git rev-list --count "$LAST"..HEAD)"

hdr "Rollback target"
PREV=$(git rev-parse --short HEAD~1 2>/dev/null || echo "unknown")
printf '  previous commit: %s\n' "$PREV"
echo "  Write the actual rollback command for your platform before deploying."

hdr "Summary"
if [ "$FAILED" -eq 0 ]; then
  echo "  No FAILs. Review every WARN before proceeding."
else
  echo "  FAILs present — do not deploy until resolved."
fi
echo "  Mechanical checks only. The human items (rollback tested, owner watching,"
echo "  stakeholders notified, baseline recorded) are in references/launch-checklist.md."
exit "$FAILED"
