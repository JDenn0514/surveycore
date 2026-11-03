---
name: pipeline-implement
description: >
  Use when a surveycore request stands at SPEC_READY and needs an
  implementation plan — the user says "draft the plan", "implementation plan",
  or "build the plan" — or when an existing plan needs its PR map reviewed,
  its findings resolved, or its state advanced to PLAN_READY.
---

# Skill: pipeline-implement

Drive a request from SPEC_READY → PLAN_READY. Produce `implementation-plan.md` with a PR map that pipeline-ship can execute PR-by-PR.

## When to use

After `pipeline-spec` has advanced the request to SPEC_READY. Before any code is written.

## Preconditions

- Current state = SPEC_READY
- `spec.md` and `test-spec.md` exist in the run directory, with copies in
  `plans/` (`spec-{slug}.md`, `test-spec-{slug}.md` — made at SPEC_READY)
- Any HOLDs from spec phase are resolved

## Stage routing

| Stage | Purpose | Output | Next state |
|---|---|---|---|
| 1 | Draft PR map | `implementation-plan.md` | DRAFT |
| 2 | Plan review (5 lenses) | `plan-review.md` | REVIEWED |
| 3 | Resolve findings | updated plan | DRAFT (loop) |
| 4 | Freeze & advance | status → PLAN_READY | PLAN_READY |

## Stage selection (user prompt)

Determine which stage the user wants from context (current `status.md` state,
what they just said, what artifacts exist). If unclear:

```
question: "Which stage of the implementation workflow?"
header: "Stage"
options:
  - label: "Stage 1 — Draft the plan"
    description: "Write the PR map from the finalized spec."
  - label: "Stage 2 — Plan review (5 lenses)"
    description: "Full batch pass over the plan; saves issues to plan-review.md."
  - label: "Stage 3 — Resolve findings"
    description: "Work through issues and log decisions."
  - label: "Stage 4 — Freeze & advance"
    description: "Copy the plan to plans/ and mark PLAN_READY (requires plan-review PASS)."
```

Then jump directly to that stage.

## Stage 1 — Draft

Dispatch `planner`:

> Draft `implementation-plan.md` per artifact-schemas.md §implementation-plan.md, including §PR budget. Read `spec.md` and `test-spec.md`.
>
> Each PR entry carries a branch name, its two budget figures, tasks with explicit TDD sub-steps, acceptance criteria, a write surface, and a pipeline tier. Cite the test-spec rows each PR covers by section and row, and give every row in `test-spec.md` to exactly one PR.
> - Split the work so every entry sits inside the PR budget. A unit of change that does not fit becomes two or more PRs.
> - Acceptance criteria are observable outcomes (test names, metric values), not implementation hints
> - Write surfaces of concurrent PRs do not overlap
>
> Done when every PR entry states both budget figures and both sit inside the bound.

## Review-loop budget (applies to Stages 2 and 3)

Measured cost of unbounded loops: one feature ran 7 review passes (~$300
API-equivalent). These rules cap the loop:

1. **Maximum 3 passes** per review stage. If findings remain open after
   pass 3, HOLD — ask the user instead of running pass 4.
2. **Pass 1 is the only full-panel pass** (all lenses, whole document).
3. **Passes 2+ are delta passes**: at most 2 Explore agents. They review
   ONLY the sections changed by the resolver (the resolver lists changed
   section headings at the top of its response) plus the specific findings
   they verify. They do not re-read the whole document.
4. **Early exit**: a pass whose findings require no change to the artifact
   ends the loop — the verdict is PASS.

## Stage 2 — Plan review

Dispatch 5 Explore subagents in parallel:

1. **PR Budget lens** — recompute both budget figures for each PR (artifact-schemas.md §PR budget): count its acceptance criteria, and resolve its cited test-spec rows against `test-spec.md`. Report every entry whose stated figure reads lower than your recomputed one, every entry that is over-budget, every cited row that does not exist, and every row claimed by two PRs. Report any PR of one task and one row, which merges into its neighbour.
2. **Dependency Ordering lens** — does the PR order respect dependencies? Later PRs must not require changes to earlier PRs' tested behavior.
3. **Acceptance Criteria lens** — is every acceptance criterion observable? Does each criterion map to a row in `test-spec.md`?
4. **Spec Coverage lens** — does the union of all PR acceptance criteria cover every item in `spec.md §Function contracts`? Are any contract items unscheduled?
5. **File Completeness lens** — does the union of all write surfaces include every file implied by the spec (source, tests, NAMESPACE, man/, NEWS.md)? Are any files missing?

Pass `model: "sonnet"` on every lens dispatch — lens agents scan a document against one named criterion and do not need the session model.

Aggregate into `plan-review.md` with verdict PASS / FAIL / NEEDS-DECISION per
`.claude/skills/pipeline-shared/references/signals.md §Review verdicts`.

## Stage 3 — Resolve

BIG mode (>8 findings) or SMALL mode (≤8), per
`.claude/skills/spec-workflow/references/stage-4-resolve.md`.

Loop until plan-review.md verdict=PASS. Respect the Review-loop budget above.

### Over-budget findings

Stage 3 splits every over-budget PR before the stage reaches PASS. A split costs
no pass from the Review-loop budget: resolve it inside the pass that raised it
and leave the pass counter where it was.

To split PR {n}:

1. Group its acceptance criteria into sets that each sit inside the budget. Each set becomes one PR.
2. Give each new PR the tasks that produce its own criteria, and a write surface holding only the files those tasks touch.
3. Order the new PRs so each one's tests pass on merge without a later PR's code.
4. Renumber the map, then re-derive every concurrent PR's write surface so they stay disjoint.
5. Log the split in `decisions-{slug}.md` with the figure that triggered it.

## Stage 4 — Freeze

On PASS:

1. Copy `implementation-plan.md` from workspace into `plans/implementation-plan-{slug}.md` (slug only — no date prefix), and refresh `plans/decisions-{slug}.md`
2. Append `PLAN_READY` to `status.md`
3. Return to user with the budget table — one row per PR: number, branch, test-spec rows, acceptance criteria — then the shipping sequence and the next step (`pipeline-ship`)

## Common Shortcuts to Resist

| Rationalization | Why it fails |
|-----------------|-------------|
| "The plan is clear, Stage 2 would just nitpick" | Stage 2 catches missing error paths, wrong task order, and DRY violations. |
| "We can figure out edge cases during implementation" | Edge cases discovered in implementation are plan bugs. Resolve here. |
| "Some issues are minor, I'll resolve them later" | `decisions.md` must be populated before handing off. |
| "PR 3 is over budget, but splitting renumbers the whole map" | Renumbering costs minutes inside the plan. An over-budget PR costs revision rounds after merge. |
| "This unit is atomic — it cannot be split" | Group the acceptance criteria and the split follows. Twelve criteria are two PRs. |

## Signal handling

- **HOLD** from planner, or a NEEDS-DECISION verdict → AskUserQuestion,
  resolve, resume
- Never BLOCK or STOP here (those are pipeline-ship execution signals; plan
  reviews use FAIL)

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/agents/planner.md`
