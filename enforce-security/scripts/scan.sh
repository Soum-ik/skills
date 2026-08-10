#!/usr/bin/env bash
# Best-effort security sweep. Runs whichever tools exist; never fails the whole
# run because one tool is missing. Output is LEADS, not verdicts — every hit
# must be traced by hand before it becomes a finding.
#
# Usage: scripts/scan.sh [base-ref]
#   base-ref defaults to origin/HEAD, then HEAD.

set -uo pipefail

BASE="${1:-}"
have() { command -v "$1" >/dev/null 2>&1; }
hdr() { printf '\n=== %s ===\n' "$1"; }
skip() { printf '  [skipped] %s\n' "$1"; }

if [ -z "$BASE" ]; then
  if git rev-parse --verify -q origin/HEAD >/dev/null 2>&1; then
    BASE="origin/HEAD"
  else
    BASE="HEAD"
  fi
fi

hdr "Scope"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ "$BASE" = "HEAD" ]; then
    RANGE=""
    FILES=$(git diff --name-only HEAD; git ls-files --others --exclude-standard)
  else
    RANGE="$BASE...HEAD"
    FILES=$(git diff --name-only "$RANGE")
  fi
  FILES=$(printf '%s\n' "$FILES" | sed '/^$/d' | sort -u)
  printf 'base: %s\nfiles:\n' "$BASE"
  printf '%s\n' "$FILES" | sed 's/^/  /'
else
  echo "not a git repository — scanning working directory"
  FILES=""
fi

hdr "Secrets (high-signal grep)"
# Deliberately narrow: known key prefixes and assignment of a long literal to a
# secret-ish name. Broad keyword greps drown the real hits.
PATTERNS='(AKIA[0-9A-Z]{16})|(ASIA[0-9A-Z]{16})|(gh[pousr]_[A-Za-z0-9]{20,})|(github_pat_[A-Za-z0-9_]{20,})|(sk-[A-Za-z0-9]{20,})|(sk-ant-[A-Za-z0-9_-]{20,})|(xox[abprs]-[A-Za-z0-9-]{10,})|(AIza[0-9A-Za-z_-]{30,})|(-----BEGIN [A-Z ]*PRIVATE KEY-----)|((secret|password|passwd|token|api[_-]?key|private[_-]?key)["\x27]?\s*[:=]\s*["\x27][^"\x27]{12,}["\x27])|((postgres|postgresql|mysql|mongodb\+srv|redis|amqp)://[^:@/\s]+:[^@/\s]+@)'
NOISE='(example|sample|dummy|placeholder|changeme|your[_-]?(key|token)|xxx+|redacted|fake)'
if have rg; then
  if [ -n "$FILES" ]; then
    printf '%s\n' "$FILES" | tr '\n' '\0' \
      | xargs -0 -r rg -nP --no-heading -i -e "$PATTERNS" 2>/dev/null
  else
    rg -nP --no-heading -i -e "$PATTERNS" . 2>/dev/null
  fi | grep -viE "$NOISE" | head -50 | grep . || echo "  no hits"
else
  # Fallback: GNU grep. -P if available (same pattern), else a reduced ERE.
  if echo x | grep -qP x 2>/dev/null; then GFLAG=-P; GPAT="$PATTERNS"; else
    GFLAG=-E
    GPAT='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(ant-)?[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(secret|password|passwd|token|api[_-]?key|private[_-]?key)["'\'']?[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{12,}["'\'']|(postgres|postgresql|mysql|mongodb\+srv|redis|amqp)://[^:@/[:space:]]+:[^@/[:space:]]+@'
  fi
  if [ -n "$FILES" ]; then
    printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 -r grep -n $GFLAG -i -e "$GPAT" 2>/dev/null
  else
    grep -rn $GFLAG -i -e "$GPAT" . 2>/dev/null
  fi | grep -viE "$NOISE" | head -50 | grep . || echo "  no hits"
fi

hdr "Secrets (dedicated scanners)"
ran=0
if have gitleaks; then gitleaks detect --no-banner --redact 2>&1 | tail -30; ran=1; fi
if have trufflehog; then trufflehog git file://. --only-verified --no-update 2>&1 | tail -30; ran=1; fi
[ "$ran" -eq 0 ] && skip "gitleaks / trufflehog not installed"

hdr "Committed secret-bearing files"
if [ -n "$FILES" ]; then
  printf '%s\n' "$FILES" | grep -E '(^|/)(\.env(\..*)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|id_rsa|.*credentials.*\.json)$' \
    || echo "  none"
else
  skip "no file list"
fi

hdr "Dependency advisories"
ran=0
[ -f package.json ] && have npm && { npm audit --omit=dev 2>&1 | tail -40; ran=1; }
{ [ -f requirements.txt ] || [ -f pyproject.toml ]; } && have pip-audit && { pip-audit 2>&1 | tail -40; ran=1; }
[ -f Cargo.toml ] && have cargo && cargo audit --version >/dev/null 2>&1 && { cargo audit 2>&1 | tail -40; ran=1; }
[ -f go.mod ] && have govulncheck && { govulncheck ./... 2>&1 | tail -40; ran=1; }
[ -f Gemfile.lock ] && have bundle && { bundle audit check --update 2>&1 | tail -40; ran=1; }
have osv-scanner && { osv-scanner scan source -r . 2>&1 | tail -40; ran=1; }
[ "$ran" -eq 0 ] && skip "no dependency auditor available for this project"

hdr "Static analysis"
ran=0
if have semgrep; then
  if [ "$BASE" != "HEAD" ]; then
    semgrep --config=p/security-audit --config=p/secrets --error --quiet --baseline-commit "$BASE" 2>&1 | tail -60
  else
    semgrep --config=p/security-audit --config=p/secrets --quiet 2>&1 | tail -60
  fi
  ran=1
fi
have bandit && [ -d . ] && { bandit -q -r . -ll 2>&1 | tail -40; ran=1; }
have gosec && { gosec -quiet ./... 2>&1 | tail -40; ran=1; }
[ "$ran" -eq 0 ] && skip "semgrep / bandit / gosec not installed"

hdr "Dangerous sinks in changed files"
SINKS='\b(eval|exec|execSync|new Function|dangerouslySetInnerHTML|innerHTML|document\.write|pickle\.loads|yaml\.load|unserialize|ObjectInputStream|shell=True|os\.system|child_process\.exec)\b|verify\s*=\s*False|rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true|Math\.random\(\)|md5|sha1\b'
if [ -n "$FILES" ]; then
  if have rg; then
    printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 -r rg -nP --no-heading -e "$SINKS" 2>/dev/null
  else
    printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 -r grep -nE -e "$SINKS" 2>/dev/null
  fi | head -60 | grep . || echo "  no hits"
else
  skip "no changed-file list"
fi

hdr "Done"
echo "Every hit above is a lead. Trace entry point -> sink before reporting it."
