---
name: pipeline-ship
description: Drives an implementation plan end-to-end through pipelined agents. For each PR: baseline check, dispatch builder (spec.md only) in a worktree, dispatch tester (test-spec.md only) after merge-back, dispatch reviewer (all artifacts) for convergence verdict, dispatch shipper for branch/commit/PR/CI/merge. Supports parallel PR dispatch when write surfaces are disjoint. Marks plan [x] on merge.
---

# Skill: pipeline-ship

Drive a request from PLAN_READY → DONE by executing each PR in `implementation-plan.md` through the pipelined agent sequence: builder → tester → reviewer → shipper.

## When to use

After `pipeline-implement` has advanced the request to PLAN_READY.

## Preconditions

- Current state = PLAN_READY
- `implementation-plan.md` exists with a PR map
- Working tree is clean
- `develop` branch is up-to-date with origin

## High-level flow

```
PLAN_READY
   │
   ▼
baseline check (tests + R CMD check on current develop)
   │
   ▼
for each PR (sequential or parallel per topology):
   │
   ├─ builder (worktree) → implementation.md
   │     │
   │     ▼
   │   merge-back to main checkout
   │     │
   │     ▼
   ├─ tester (merged checkout) → audit.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder (max 3 cycles) → HOLD on 4th
   │     └─ verdict=PASS → continue
   │
   ├─ reviewer (all artifacts) → review.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder or pipeline-spec
   │     ├─ verdict=STOP → HOLD pipeline; user override required
   │     └─ verdict=PASS → continue
   │
   └─ shipper → PR, CI, merge → plan[x]

all PRs DONE → pipeline-ship returns
```

## Step 0 — Baseline check

Before any PR starts:

```bash
Rscript -e 'devtools::test()'
Rscript -e 'devtools::check()'
```

If either fails, HOLD with classification `dirty-baseline`. Do not begin.

Cache the baseline results (tests passing count, coverage %) for Before/After comparison in each audit.

## Step 1 — Topology analysis

Parse `implementation-plan.md` PR map. For each PR, extract the Files touched write surface.

Build a dependency graph:

- PR A blocks PR B if A's write surface overlaps B's (would produce merge conflicts)
- Otherwise, A and B can dispatch in parallel

Output: a sequence of "batches". Each batch contains PRs that can dispatch in parallel.

## Step 2 — Dispatch loop

For each batch in order:

### 2a. Dispatch builders (parallel)

For each PR in the batch, dispatch `builder` agent with `isolation: "worktree"`:

> PR: {number} — {slug}
> Spec: {path to workspace spec.md}
> Write surface: {exact files from plan}
> Tasks: {tasks from plan}
> Acceptance criteria: {from plan}
> Read: .claude/agents/builder.md, .claude/rules/, r-package-profile.md
> DO NOT read test-spec.md. DO NOT read any other PR's implementation.md.

Each builder returns `implementation.md` with the PR's write surface changes merged back via the worktree protocol.

### 2b. Merge-back and dispatch testers (parallel)

After all builders in the batch return:

1. Verify each worktree merged back cleanly (no conflicts)
2. Verify each `implementation.md` write surface matches the plan

Then dispatch `tester` agent for each PR (not in a worktree; tester reads the merged checkout):

> PR: {number} — {slug}
> Test-spec: {path to workspace test-spec.md}
> Baseline results: {from step 0}
> Read: .claude/agents/tester.md, r-package-profile.md
> DO NOT read spec.md. DO NOT read implementation.md.

Each tester returns `audit.md` with verdict PASS or BLOCK.

### 2c. BLOCK handling

If an audit returns BLOCK:

1. Increment BLOCK counter for that PR
2. If counter ≤ 3: re-dispatch builder for that PR with the BLOCK body (NOT the full audit.md, NOT test-spec.md) per signals.md
3. If counter = 4: emit HOLD classification `repeated-block`; pause the pipeline for user decision

### 2d. Dispatch reviewer (sequential per PR, after its audit passes)

For each PR with audit verdict=PASS, dispatch `reviewer`:

> PR: {number} — {slug}
> All artifacts: spec.md, test-spec.md, implementation.md, audit.md, comprehension.md (if present)
> Read: .claude/agents/reviewer.md, ALL references from pipeline-shared

Reviewer returns `review.md` with verdict PASS / BLOCK / STOP.

### 2e. Review verdict handling

- **PASS** → proceed to shipper
- **BLOCK** → re-dispatch the agent reviewer identified (builder or planner). Increment BLOCK counter. Max 3 cycles per PR.
- **STOP** → pipeline halts. Write HOLD to `decisions.md`. User must resolve before resume.

### 2f. Dispatch shipper

For each PR with review verdict=PASS:

> PR: {number} — {slug}
> Review: {path to workspace review.md}
> Plan: {path to workspace implementation-plan.md}
> Read: .claude/agents/shipper.md

Shipper opens the PR, monitors CI, merges, and marks `[x]` in the plan.

## Step 3 — Post-batch verification

After every shipper in a batch returns:

1. `git checkout develop && git pull`
2. Re-run `devtools::test()` on the updated develop
3. If any test fails that was passing in the baseline → HOLD with classification `post-merge-regression`

Only then proceed to the next batch.

## Step 4 — Advance to DONE

After all batches complete and all plan checkboxes are `[x]`:

1. Append `DONE` to `status.md`
2. Return to user with summary: PRs merged, coverage delta, any STOPs encountered

## Signal handling

- **HOLD** — any stage. Pause, write to decisions.md, ask user.
- **BLOCK** (from tester) — route back to builder. Max 3 per PR.
- **BLOCK** (from reviewer) — route back to builder OR pipeline-spec depending on classification. Max 3 per PR.
- **STOP** (from reviewer) — halt pipeline. HOLD with full STOP body. User must override in decisions.md to resume.

## References

- `skills/pipeline-shared/references/state-model.md`
- `skills/pipeline-shared/references/signals.md`
- `skills/pipeline-shared/references/pipeline-isolation.md`
- `skills/pipeline-shared/references/artifact-schemas.md`
- `skills/pipeline-shared/references/r-package-profile.md`
- `skills/pipeline-shared/references/workspace-layout.md`
- `.claude/agents/builder.md`, `tester.md`, `reviewer.md`, `shipper.md`

## Must not

- Dispatch a tester before the corresponding builder's worktree has merged back
- Dispatch a reviewer before the corresponding tester's audit.md is written
- Dispatch a shipper without review.md verdict=PASS
- Dispatch two builders in parallel on overlapping write surfaces
- Advance to DONE while any PR checkbox is `[ ]`
