---
name: review-code
description: Final human-quality review of new code — checks that design, security, and performance rules were actually followed, and that the change is correct, readable, and tested. Use when the user asks to review code, review a PR or diff, do a final quality check before merge, or asks "does this look right". Triggers include "review this", "code review", "PR review", "final check", "ready to merge".
---

# Review Code

The last check before merge. Two questions, in order:

1. **Is it correct?** Will it do the wrong thing for some real input or state?
2. **Should it look like this?** Design, clarity, reuse, performance, tests.

Correctness outranks everything else. A clean design that returns wrong results is worse than an ugly one that works.

## Procedure

**1. Get the diff and the intent.**

```bash
git log --oneline -10
git diff --stat origin/HEAD...HEAD 2>/dev/null || git diff --stat HEAD
git diff origin/HEAD...HEAD 2>/dev/null || git diff HEAD
```

For a PR: `gh pr view <n> --json title,body,files` and `gh pr diff <n>`. Read the description first — a change can only be judged against what it was meant to do. If intent is unclear, ask rather than guess.

**2. Read surrounding code, not just the diff.** Open the files the diff touches and the callers of anything it changes. Most real bugs live in the interaction between new and existing code, which a diff hides. Check whether a helper already exists for what the change reimplements.

**3. Review against `references/rubric.md`.** Correctness → security → performance → design → readability → tests. Note candidates as you go; don't report yet.

**4. Verify every candidate.** For each one, try to prove it wrong: read the code again, check the types, look for the guard upstream, run the test. Write the concrete failure scenario — specific inputs or state producing a specific wrong outcome. If you can't, drop it. This step is what separates a useful review from a noisy one.

**5. Report** using the format below, most severe first.

## Severity

- **Blocking** — wrong behavior, data loss, security hole, breaks an existing caller, or removes coverage of something that matters.
- **Should fix** — real problem with a bounded cost: a missed edge case, an N+1 on a hot path, a design choice that will be expensive to unwind.
- **Consider** — genuine improvement the author may reasonably decline.
- **Nit** — style/naming. Cap these; three nits maximum, and drop them entirely if a formatter or linter would catch them.

## Output format

```
## Review: <what changed, one line>
Verdict: REQUEST CHANGES | APPROVE WITH COMMENTS | APPROVE
Scope: <N files reviewed, commit range or PR>

### [Blocking] <the claim, stated as a defect>
path/to/file.ts:88
<Why it is wrong.>
Fails when: <concrete inputs/state → wrong output>
Suggested: <smallest correct fix, code if short>

### [Should fix] ...
### [Consider] ...

### Notes
<What you verified and found sound — the design decision you agree with, the
edge case that is already handled. One or two lines. This tells the author what
was actually looked at.>
```

## Rules

- Every finding names a file and line and states a defect, not a feeling. "This is confusing" is not a finding; "this returns `None` when the list is empty and the caller at `x.py:20` indexes it" is.
- Judge against the codebase's existing conventions, not your preferences. If the surrounding code does it another way, follow the surrounding code.
- Don't ask for scope the change didn't claim. Missing features are not defects; missing correctness for the claimed feature is.
- If you're unsure whether something is a bug, say so explicitly and say what would settle it. Don't launder uncertainty as a confident finding.
- Approve when it's right. A review that always finds something teaches the author to ignore reviews.
- Don't edit the code unless the user asks for fixes to be applied.

## Reference

- `references/rubric.md` — full review rubric by dimension
- `references/comment-guide.md` — how to write findings authors act on
- `assets/review-template.md` — output skeleton
