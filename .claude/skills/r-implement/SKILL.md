---
name: r-implement
description: >
  Implements R package code for surveycore from an approved implementation plan.
  Three modes: (A) single-session implementation of one plan section with TDD,
  (B) CI failure diagnosis and fix after a failed push, (C) subagent-driven
  execution with fresh subagents per section and two-stage spec compliance and
  code quality review. Trigger when the user says "implement", "start coding",
  "write the code", "start the PR", "let's build this", or "subagent mode".
  Also triggers when commit-and-pr produces a CI Failure handoff block.
---

# R Implementation Skill

---

## Entry Mode — Determine This First

**Mode A: Normal** — implementing a single plan section in this session.
Signs: "implement", "start coding", "let's build this".
→ Go to **Pre-flight**.

**Mode B: CI-Fix** — fixing a CI failure after a push.
Signs: user provides a "CI Failure — Handoff to r-implement" block, or
"CI is failing", "fix the CI failure", "commit-and-pr handed off to you".
→ Read `references/ci-fix.md`. Skip Pre-flight entirely.

**Mode C: Subagent-Driven** — dispatching fresh subagents per plan section.
Signs: "subagent mode", "drive it yourself", "auto-implement the plan".
→ Read `references/mode-c-subagent.md`. Skip Pre-flight.

---

## Pre-flight (Mode A — do these FIRST, before writing any code)

### Step 1: Check the branch

```bash
git branch --show-current
```

**If on `main`:** Stop. Tell the user:

> "Feature branches must start from `develop`. Run `git checkout develop`
> and re-invoke `/r-implement`."

**If on `develop`:**
1. Ask for the implementation plan path if not provided
2. Read the plan → find the first unchecked `- [ ]` section
3. Show: "I'll create branch `feature/X` from `develop` — is that right?"
4. On confirmation: `git checkout -b feature/X`

**If already on a feature branch:** continue to Step 2.

### Step 2: Read the implementation plan

Find the **first unchecked `- [ ]` section**. That section is the entire scope
for this session. Do not implement anything outside it.

If all sections are checked: report "All sections complete — nothing left to
implement." and stop.

### Step 3: Read the spec section

Verify before writing any code:

- Every function's behavior is fully specified (inputs, outputs, errors)
- All error conditions exist in `plans/error-messages.md`
- All argument types and defaults are defined
- All edge cases are explicitly handled

**If anything is ambiguous or underspecified: STOP. Ask the user to clarify
before writing a single line of code.**

### Step 4: Update `plans/error-messages.md`

Add any new error/warning classes **before** writing code that uses them.

---

## TDD Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over. No exceptions.

Do not keep it "as reference" — delete means delete. Implement fresh from tests.

| Rationalization | Reality |
|---|---|
| "Too simple to need a test" | Simple code breaks. The test takes 2 minutes. |
| "I'll add tests after" | Tests written after pass immediately, proving nothing. |
| "I already know it works" | Tests-first force edge case discovery. Tests-after verify memory. |
| "Just this once" | That's how untested code accumulates. |
| "I manually tested it" | Manual testing is ad-hoc, unrepeatable, and undocumented. |

---

## Implementation

Follow TDD order — tests before source, always.

1. Write the test file (from the spec's test categories for this section)
2. Run `devtools::test()` — **confirm all new tests fail (red phase)**
   - If a new test unexpectedly passes, stop and investigate before proceeding
3. Write the R source file to make the tests pass
4. Run `devtools::document()` if any roxygen2 tags changed
5. Update `_pkgdown.yml` if any new functions were exported — add them to the
   correct `reference:` section (match the `@family` tag used in roxygen)

---

## Verification

Run both checks after implementation:

```r
devtools::test()
devtools::check()
```

**If either fails:** diagnose and fix, then re-run. After **3 failed attempts
on the same failure**, stop and report the exact error, what was tried, and
why it is still failing. Do not mark the section complete.

### Two-Stage Review (required before marking `[x]`)

After both checks pass, complete both review stages before marking the
section complete:

**Stage 1 — Spec Compliance:** Does the code match what the spec said?

- [ ] Every function signature matches the spec's argument table
- [ ] Every error class from the spec's error table is present in the code
- [ ] Every output column matches the spec's output contract
- [ ] No behavior added beyond the spec's scope

**Stage 2 — Code Quality:** Does the code follow surveycore rules?

- [ ] No `UseMethod()` on S7 objects — uses `S7::S7_inherits()` instead
- [ ] `class=` on every `cli_abort()` and `cli_warn()` call
- [ ] No `@importFrom` — all external calls use `::`
- [ ] `test_invariants(design)` is first assertion in every constructor test block
- [ ] Dual pattern (class= + snapshot) on all Layer 3 errors

If either stage finds issues, fix them before marking complete.

---

## Completion

When both checks and both review stages pass:

1. Mark the section complete in the implementation plan: `- [ ]` → `- [x]`
2. Report:

> "Section complete. Start a new session with `/commit-and-pr` to create the PR."

---

## Done Criteria

Do not mark the section complete until ALL are true:

- [ ] `devtools::test()` — no failures
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run (if roxygen2 changed); `_pkgdown.yml` updated (if new exports)
- [ ] `plans/error-messages.md` updated (if new error classes added)
- [ ] Stage 1 spec compliance review: all items checked
- [ ] Stage 2 code quality review: all items checked
- [ ] Implementation plan section marked `[x]`
