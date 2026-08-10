---
name: enforce-security
description: Run safety and vulnerability checks on pending code before it is merged. Use when the user asks to security-review a change, check for vulnerabilities, scan dependencies or secrets, verify authn/authz, or gate a merge on security. Triggers include "security check", "is this safe to merge", "vuln scan", "secrets check", "OWASP", "harden this endpoint".
---

# Enforce Security

Security gate for code that is about to merge. Goal: find exploitable defects in **the changed code and the paths it touches**, then return a merge verdict. Not a general codebase audit.

## Scope first

Determine the diff before reading anything else:

```bash
git diff --stat origin/HEAD...HEAD 2>/dev/null || git diff --stat HEAD
git diff origin/HEAD...HEAD 2>/dev/null || git diff HEAD
```

If not a git repo or there is no diff, ask what to treat as the change set. Do not silently fall back to scanning everything.

## Procedure

1. **Automated sweep.** Run `scripts/scan.sh` (secrets, dependency advisories, static analysis — skips tools that are absent). Treat its output as leads, not verdicts.
2. **Read the diff against the checklist.** Work through `references/checklist.md`. For each changed file, ask which categories it can even reach — a CSS change cannot have SQL injection.
3. **Trace, don't pattern-match.** For every candidate finding, follow the data from an attacker-controlled entry point to the dangerous sink. If you cannot name the entry point, it is not a finding yet.
4. **Verify each finding survives scrutiny.** Try to refute it: is there an upstream validator, a framework escape, a type constraint, a deploy-time guard? Drop anything you cannot defend with a concrete failure scenario.
5. **Report.** Use the format below.

## Severity

| Level | Meaning | Merge |
|---|---|---|
| Critical | Remote unauthenticated impact, auth bypass, RCE, secret in repo history | Block |
| High | Authenticated data exposure across tenants/users, injection, broken access control | Block |
| Medium | Exploitable only with unusual preconditions; missing defense-in-depth on a sensitive path | Fix or file an issue |
| Low | Hardening, hygiene, noisy-but-harmless | Note only |
| Info | Observation, no defect claimed | Note only |

## Output format

```
VERDICT: BLOCK | PASS WITH FIXES | PASS
Scope: <N files, commit range>
Tools run: <names> (skipped: <names, why>)

## Findings
### [SEVERITY] <one-line claim>
- Location: path/to/file.ts:42
- Entry point: <how attacker-controlled input reaches this>
- Failure scenario: <concrete inputs → concrete impact>
- Fix: <smallest correct change>

## Checked and clear
<categories reviewed with nothing found — one line each, so reviewers know coverage>
```

If nothing is found, say so plainly and still list what was checked. An empty findings list with no coverage statement is not a useful gate.

## Rules

- Never write a secret value into the report, logs, or a file. Reference it as `path:line — <credential type>`.
- If a secret was ever committed, the fix is **rotate**, not just remove — say so.
- Do not auto-apply security fixes unless the user asks. Propose the diff.
- Do not run exploit payloads against live or shared systems. Reason statically; local test-only reproduction is fine when the user asks for proof.
- Report honestly: if a tool failed or a path was too large to review, say which and why.

## Reference

- `references/checklist.md` — category-by-category review checklist
- `references/threat-patterns.md` — common vulnerable patterns and their safe forms
- `scripts/scan.sh` — best-effort automated sweep
