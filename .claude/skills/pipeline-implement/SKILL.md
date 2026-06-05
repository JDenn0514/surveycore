---
name: pipeline-implement
description: >
  Orchestrates implementation plan drafting for surveycore after SPEC_READY.
  Dispatches planner to draft a PR map with per-PR acceptance criteria, runs a
  5-lens plan review, resolves findings, and advances to PLAN_READY. Produces
  implementation-plan.md that pipeline-ship executes PR-by-PR. Use when the
  user says "draft the plan", "implementation plan", "build the plan", or after
  pipeline-spec has reached SPEC_READY.
---

# Skill: pipeline-implement

Drive a request from SPEC_READY → PLAN_READY. Produce `implementation-plan.md` with a PR map that pipeline-ship can execute PR-by-PR.

## When to use

After `pipeline-spec` has advanced the request to SPEC_READY. Before any code is written.

## Preconditions

- Current state = SPEC_READY
- `spec.md`, `test-spec.md` exist and are copied into `plans/`
- Any HOLDs from spec phase are resolved

## Stage routing

| Stage | Purpose | Output | Next state |
|---|---|---|---|
| 1 | Draft PR map | `implementation-plan.md` | DRAFT |
| 2 | Plan review (5 lenses) | `plan-review.md` | REVIEWED |
| 3 | Resolve findings | updated plan | DRAFT (loop) |
| 4 | Freeze & advance | status → PLAN_READY | PLAN_READY |

## Stage Routing (user prompt)

Determine which stage the user wants from context (current `status.md` state,
what they just said, what artifacts exist). If unclear:

```
question: "Which stage of the implementation workflow?"
header: "Stage"
options:
  - label: "Stage 1 — Draft the plan"
    description: "Write the PR map from the finalized spec."
  - label: "Stage 2 — Adversarial review"
    description: "Full batch pass over the plan; saves issues to plan-review.md."
  - label: "Stage 3 — Resolve issues"
    description: "Work through issues and log decisions."
```

Then jump directly to that stage.

## Stage 1 — Draft

Dispatch `planner`:

> Draft `implementation-plan.md` per artifact-schemas.md §implementation-plan.md. Read `spec.md` and `test-spec.md`. For each logical unit of change:
> - One PR entry with a branch name, tasks (2–5 min each with TDD sub-steps), acceptance criteria, write surface, and pipeline-split flag (recommended | optional)
> - Acceptance criteria are observable outcomes (test names, metric values), not implementation hints
> - Write surfaces of concurrent PRs do not overlap

## Stage 2 — Plan review

Dispatch 5 Explore subagents in parallel:

1. **PR Granularity lens** — is each PR a single logical unit? Are any PRs too large (>10 tasks, >5 files) or too small (1 task, 1 line)?
2. **Dependency Ordering lens** — does the PR order respect dependencies? Later PRs must not require changes to earlier PRs' tested behavior.
3. **Acceptance Criteria lens** — is every acceptance criterion observable? Does each criterion map to a row in `test-spec.md`?
4. **Spec Coverage lens** — does the union of all PR acceptance criteria cover every item in `spec.md §Function contracts`? Are any contract items unscheduled?
5. **File Completeness lens** — does the union of all write surfaces include every file implied by the spec (source, tests, NAMESPACE, man/, NEWS.md)? Are any files missing?

Aggregate into `plan-review.md` with verdict PASS / BLOCK / HOLD (same rules as spec review).

## Stage 3 — Resolve

BIG mode (>8 findings) or SMALL mode (≤8). Same routing as pipeline-spec Stage 3r.

Loop until plan-review.md verdict=PASS.

## Stage 4 — Freeze

On PASS:

1. Copy `implementation-plan.md` from workspace into `plans/implementation-plan-{slug}.md` (slug only — no date prefix)
2. Append `PLAN_READY` to `status.md`
3. Return to user with summary (PR count, estimated shipping sequence) and next step (`pipeline-ship`)

## Common Shortcuts to Resist

| Rationalization | Why it fails |
|-----------------|-------------|
| "The plan is clear, Stage 2 would just nitpick" | Stage 2 catches missing error paths, wrong task order, and DRY violations. |
| "We can figure out edge cases during implementation" | Edge cases discovered in implementation are plan bugs. Resolve here. |
| "Some issues are minor, I'll resolve them later" | `decisions.md` must be populated before handing off. |

## Signal handling

- **HOLD** from planner or any lens → AskUserQuestion, resolve, resume
- Never BLOCK or STOP here (those are pipeline-ship signals)

## References

- `skills/pipeline-shared/references/state-model.md`
- `skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/agents/planner.md`
