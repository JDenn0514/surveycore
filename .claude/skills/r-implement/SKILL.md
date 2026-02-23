---
name: r-implement
description: >
  Use when it's time to write R implementation code for surveycore or other
  surveyverse packages. Trigger when the user says "implement", "code this up",
  "start coding", "write the code", "start the PR", or "let's build this".
---

# R Implementation Skill

You are implementing R package code for the surveyverse ecosystem.

---

## Pre-flight (do these FIRST, before writing any code)

### Step 1: Check the branch

```bash
git branch --show-current
```

**If on `main`:**

1. Ask the user for the implementation plan path if not already provided
2. Read the plan and find the first unchecked `- [ ]` section
3. Determine the branch name from that section's entry
4. Show: "I'll create branch `feature/X` from `main` — is that right?"
5. On confirmation: `git checkout -b feature/X`
6. Continue to Step 2

**If already on a feature branch:** continue to Step 2.

### Step 2: Read the implementation plan

Ask the user for the path if not provided (e.g., `plans/phase-1-implementation-plan.md`).

Find the **first unchecked `- [ ]` section**. That section defines the scope for this
entire session. Do not implement anything outside that scope.

If all sections are checked: report "All sections complete — nothing left to implement."
and stop.

### Step 3: Read the spec section

Read the spec file for the section you are about to implement. Before writing any code,
verify:

- Every function's behavior is fully specified (inputs, outputs, errors)
- All error conditions exist in `plans/error-messages.md`
- All argument types and defaults are defined
- All edge cases are explicitly handled

**If anything is ambiguous or underspecified: STOP. Ask the user to clarify before
writing a single line of code.** Do not make architectural guesses — surface the question.

### Step 4: Update `plans/error-messages.md`

Add any new error/warning classes you will need **before** writing code that uses them.

---

## Implementation

1. Write the R source file
2. Write the test file (source and tests in the same session)
3. Run `devtools::document()` if any roxygen2 tags changed

---

## Verification

Run both checks after implementation:

```r
devtools::test()
devtools::check()
```

**If either fails:** attempt to diagnose and fix, then re-run. After **3 failed attempts
on the same failure**, stop and report:

- The exact error output
- What was tried
- Why it is still failing

Do not mark the section complete until both pass.

---

## Completion

When `devtools::test()` and `devtools::check()` both pass:

1. Mark the section complete in the implementation plan: `- [ ]` → `- [x]`
2. Report:

> "Section complete. Start a new session with `/commit-and-pr` to create the PR."

---

## Conventions (always in context — no need to re-read)

All surveyverse coding conventions are in the rule files loaded at session start.
Quick index:

| What you need | Where it is |
|---|---|
| S7 patterns, dispatch, `@variables` keys | `code-style.md §2` |
| `cli_abort()` / `cli_warn()` structure and `class=` | `code-style.md §3` |
| Argument order, return visibility, helper placement | `code-style.md §4` |
| `::` everywhere, no `@importFrom`, roxygen2 | `r-package-conventions.md §2` |
| Naming patterns, `@family`, `@seealso` | `surveycore-conventions.md` |
| Test structure, error patterns, invariants, tolerances | `testing-standards.md` + `testing-surveycore.md` |
| Error class names | `plans/error-messages.md` — update this file BEFORE using any new class |

---

## Done Criteria

Do not mark the section complete until ALL are true:

- [ ] `devtools::test()` — no failures
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run (if roxygen2 content changed)
- [ ] `plans/error-messages.md` updated (if new error classes added)
- [ ] No `UseMethod()` patterns on S7 objects
- [ ] No `cli_abort()` or `cli_warn()` calls missing `class=`
- [ ] No `@importFrom` in any file
- [ ] `test_invariants(design)` called first in every constructor test block
- [ ] Dual pattern (`class=` + snapshot) on all Layer 3 error tests
- [ ] Implementation plan section marked `[x]`
