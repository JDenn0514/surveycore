---
name: pipeline-simplified
description: Fast-path workflow for small routine changes (≤3 files, no new export, no algorithmic change). Runs lightweight planner → builder → tester → shipper without comprehension, without spec/test-spec split, without separate reviewer. Tester is the quality gate. Escalates to full pipeline on repeated BLOCK or scope creep. Offers choice to user at request start.
---

# Skill: pipeline-simplified

Drive a small change from NEW → DONE with minimal overhead. Sequence: planner-lite → builder → tester → shipper. No separate reviewer (tester is the quality gate). No pipeline-isolation between spec and test-spec (there is no split). Escalates to full workflow if scope grows.

## When to offer

This skill is not invoked silently. The leader MUST check smallness criteria against the request before offering.

### Smallness criteria (ALL must hold)

| Criterion | Test |
|---|---|
| Few files | Change touches ≤3 files |
| No algorithmic change | No variance, estimator, linearization, DoF, or numerical method changed |
| No new exported function | The exported API surface does not grow |
| No public contract change | No existing function's arguments, return shape, or error classes change |
| No attached material | User did not upload papers, PDFs, or reference implementations |
| Routine pattern | Pattern is in the allowed list below |

### Routine patterns (examples)

- Fix a typo in a docstring or error message
- Bump version in DESCRIPTION
- Add `@export` tag
- Fix lint violation
- Add a parameter with a safe default to an existing function
- Fix broken `@examples`
- Update a URL in docs
- Add `.Rbuildignore` entry
- Fix a broken `@importFrom` by switching to `::`

### NOT simplified

- New exported function
- Any variance or estimator change
- Any change referencing a paper or PDF
- Any change expected to alter numerical output
- Changes spanning multiple domain areas (classes + constructors + variance)

## Offer protocol

Leader uses AskUserQuestion with:

> This looks like a small change (≤3 files, routine pattern, no algorithmic change). Use simplified workflow?
>
> - **Simplified (faster)**: planner-lite → builder → tester → shipper. No separate reviewer; tester gates quality.
> - **Full workflow**: pipeline-spec → pipeline-implement → pipeline-ship with full reviewer convergence.

Default to Full when the smallness test is ambiguous.

## Preconditions

- Current state = NEW
- `request.md` exists
- `impact.md` exists with `smallness-test` result = `eligible-simplified`

## State chain

```
NEW → PLANNED → DONE
```

See `.claude/skills/pipeline-shared/references/state-model.md §Simplified workflow`.

## Step 1 — Planned (planner-lite)

Dispatch `planner` with simplified prompt:

> Simplified workflow. Write a lightweight `request.md` extension (not spec.md) with:
> - Clear description of the change
> - Acceptance criteria (what "done" looks like, as observable outcomes)
> - Affected files (the write surface, ≤3)
> - Expected validation outcome (which tests should still pass, which new assertion)
> Do NOT write spec.md, test-spec.md, or implementation-plan.md. Do NOT run comprehension protocol.

**In the same turn as the planner dispatch**, start the baseline capture in
the background (the tree is still clean — builder has not run):
`bash .claude/scripts/run-gates.sh {workspace-run-dir}/logs-baseline --baseline`
with `run_in_background: true`. Its summary is the tester's Before column.
Do not wait for it here; collect the result before dispatching the tester.

On return, verify `request.md` has all four sections. Append `PLANNED` to `status.md`.

## Step 2 — Pipelines complete (builder + tester)

### 2a. Dispatch builder

Dispatch `builder` agent WITHOUT worktree isolation (small change; overhead not justified):

> Simplified workflow.
> Request: {path to request.md}
> Write surface: {files from request.md}
> Acceptance criteria: {from request.md}
> Read: .claude/agents/builder.md, r-package-profile.md (§Builder compliance rules only). Rules auto-load — do not re-read .claude/rules/.
> Exception: you MAY read test code in tests/testthat/ in case you need to update a test alongside the code. Pipeline isolation is relaxed for simplified workflow.

Builder implements, updates docs if needed, writes `implementation.md`.

### 2b. Dispatch tester

Dispatch `tester` agent:

> Simplified workflow.
> Request: {path to request.md with acceptance criteria}
> Baseline results: {summary from the background baseline capture}
> Read: .claude/agents/tester.md, r-package-profile.md
> Validate that:
> 1. Each acceptance criterion from request.md holds
> 2. All profile gates pass (devtools::test, run_examples, R CMD check --as-cran, pkgdown if in scope, covr)
> 3. CRAN cookbook scan is clean on the modified files
> 4. No regression in tests that were passing before the PR
> Write audit.md with verdict PASS or BLOCK.
> Exception: pipeline isolation relaxed — you may infer acceptance criteria from context.

BLOCK routing: re-dispatch builder with the BLOCK body. Cycle limit: signals.md §BLOCK (the 3rd BLOCK escalates — see below).

### 2c. Advance

With audit verdict=PASS, proceed to Step 3 (tester is the quality gate; no
separate reviewer in simplified mode).

## Step 3 — Ship

Dispatch `shipper` agent as in pipeline-ship §2f. Shipper still requires a PASS quality gate — in simplified mode, this is the audit.md verdict=PASS.

Shipper opens PR, monitors CI, merges, marks `[x]` in the plan (or just in the workspace `request.md` if no plan exists).

Append `DONE` to `status.md`.

## Escalation to full workflow

If AT ANY POINT:

- Builder emits HOLD more than once (spec ambiguity on what was supposed to be a small change)
- Tester emits a 3rd BLOCK on the same issue
- The change turns out to affect more than 3 files
- A CRAN cookbook violation is found that requires design-level change (not just syntax)
- Acceptance criteria turn out to depend on methodology the user didn't describe

Leader MUST escalate:

1. Dispatch `planner` with full-workflow prompt: comprehension (if now applicable), `spec.md`, `test-spec.md`
2. Transition state to COMPREHENDED (auto-entered for non-methods requests)
3. Continue from `pipeline-spec` Stage 1 onward
4. Append to `status.md`: `ESCALATED — {reason}`

Preserve all work done so far. The partial implementation in the working tree may need to be discarded; the planner writes a fresh spec with the accumulated context.

## Signal handling

- **HOLD** — any agent. Pause, AskUserQuestion, resolve, resume OR escalate if resolution suggests full workflow is needed.
- **BLOCK** — tester only in simplified mode. Cycle limit per signals.md §BLOCK; the 3rd BLOCK escalates to full workflow.
- **STOP** — not valid in simplified mode (no reviewer). If tester finds something STOP-worthy (e.g., coverage dropped below 95% on new code), that's an ESCALATION trigger, not a STOP.

## Workspace layout

Simpler than full:

```
.surveycore-workspace/runs/{request-id}/
├── status.md
├── request.md          (planner-lite extended this)
├── impact.md
├── decisions.md
├── implementation.md
└── audit.md
```

No `spec.md`, no `test-spec.md`, no `comprehension.md`, no `implementation-plan.md`, no `review.md`.

## What you sacrifice by using simplified

| Sacrifice | Mitigation |
|---|---|
| No methods review lenses | Smallness test excludes methods changes |
| No pipeline isolation | Smallness test excludes algorithmic changes; builder can be nudged by reading tests, but there's no numerical oracle to protect |
| No separate reviewer | Tester is the quality gate; profile gates + cookbook scan catch most issues |
| No comprehension document | Smallness test excludes paper-driven work |
| No architecture record | Small changes don't warrant plans/archive entries |
| No PR map | Single PR; plan isn't needed |

## References

- `.claude/skills/pipeline-shared/references/state-model.md` §Simplified workflow
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md` §Simplified workflow exception
- `.claude/skills/pipeline-shared/references/r-package-profile.md`
- `.claude/agents/planner.md`, `builder.md`, `tester.md`, `shipper.md`
