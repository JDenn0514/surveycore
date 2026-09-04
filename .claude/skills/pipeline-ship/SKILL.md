---
name: pipeline-ship
description: >
  Executes a PLAN_READY implementation plan PR by PR, one PR at a time,
  through builder, tester, reviewer and shipper. Use when the user says "ship
  the plan", "execute the plan", "run the PRs", or after pipeline-implement
  has reached PLAN_READY.
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
for each PR, one at a time, in dependency order:
   │
   ├─ builder (worktree) → implementation.md
   │     │
   │     ▼
   │   merge-back to main checkout
   │     │
   │     ▼
   ├─ tester (merged checkout) → audit.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder → HOLD on 3rd BLOCK
   │     └─ verdict=PASS → continue
   │
   ├─ reviewer (all artifacts) → review.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder or pipeline-spec
   │     ├─ verdict=STOP → HOLD pipeline; user override required
   │     └─ verdict=PASS → pre-PR gate ↓
   │
   ├─ pre-PR gate (devtools::check + pkgdown::check_pkgdown)
   │     │
   │     ├─ fails → HOLD pre-pr-check-failure; fix → re-run gate
   │     └─ passes → continue
   │
   ├─ shipper → PR, CI, merge → plan[x]
   │
   └─ post-PR verification → next PR

all PRs DONE → pipeline-ship returns
```

## Step 0 — Baseline check

Before any PR starts:

```bash
Rscript -e 'devtools::test()'
Rscript -e 'devtools::check()'
Rscript -e 'covr::package_coverage()'
```

If tests or check fail, HOLD with classification `dirty-baseline`. Do not begin.

Cache the baseline results (tests passing count, coverage %) for Before/After comparison in each audit.

## Step 1 — Dependency ordering

Parse `implementation-plan.md` PR map. For each PR, extract the Files touched write surface.

Put the PRs in one order:

- PR A comes before PR B when B builds on A's output.
- PR A comes before PR B when their write surfaces overlap. Overlap fixes the
  order — it never lets both run at once.
- Otherwise keep the plan's own PR numbers.

Output: one ordered list of PRs.

Each PR runs its whole cycle — builder, tester, reviewer, pre-PR gate,
shipper, merge, post-PR verification — before the next PR's builder starts.

### Why one PR at a time

Two builders at once cost the same tokens as two in sequence, because the work
is identical. The cost appears when a PR needs a fix. Every one of the first three PRs in
the `dataset-level-metadata` run took at least one fix cycle, four BLOCKs in
all. With two PRs live, that is two BLOCK cycles, two re-audits, and two
reviewer passes to hold in this session's context at the same time — and that
is where a finding gets attached to the wrong PR (issue #165).

Disjoint write surfaces are a weaker guarantee than they look. In the same run,
PR 3 shipped a `make_dataset_design()` state vocabulary that PR 6 needed and
could not repair, because `helper-test-data.R` sat outside PR 6's write
surface. A file-level overlap test cannot see that coupling. The reviewer,
reading spec and test-spec together, caught it.

One PR at a time also cannot break an ordering constraint, so the default
carries no correctness risk.

### Parallel dispatch on request

Dispatch two builders at once when the user asks for it in this run, and say
the cost first: each extra PR in flight adds a BLOCK cycle, a re-audit and a
reviewer pass to carry at the same time, and a dependency found mid-flight can
still force the PR to wait after its builder tokens are spent.

## Step 2 — Per-PR cycle

Take the first PR in the order. Run 2a to 2f for that PR and merge it. Then
take the next PR.

### 2a. Dispatch the builder

Tell the user: "Dispatching the builder for PR {N} ({slug}). It runs in an isolated worktree — expect 10–25 min."

Dispatch one `builder` agent with `isolation: "worktree"`:

> PR: {number} — {slug}
> Spec: {path to workspace spec.md}
> Write surface: {exact files from plan}
> Tasks: {tasks from plan}
> Acceptance criteria: {from plan}
> Read: .claude/agents/builder.md, r-package-profile.md (rules auto-load — do not re-read .claude/rules/)
> DO NOT read test-spec.md. DO NOT read any other PR's implementation.md.

The builder returns `implementation.md` with the PR's write surface changes merged back via the worktree protocol.

### 2b. Merge back and dispatch the tester

Tell the user: "The builder returned for PR {N}. Merging back and dispatching the tester."

After the builder returns:

1. Verify the worktree merged back cleanly (no conflicts)
2. Verify the `implementation.md` write surface matches the plan
3. Remove the builder's worktree: `git worktree remove --force <worktree-path>` then `git worktree prune`

Then dispatch one `tester` agent (not in a worktree; the tester reads the merged checkout):

> PR: {number} — {slug}
> Test-spec: {path to workspace test-spec.md}
> Baseline results: {from step 0}
> Read: .claude/agents/tester.md, r-package-profile.md
> DO NOT read spec.md. DO NOT read implementation.md.

The tester returns `audit.md` with verdict PASS or BLOCK.

### 2c. BLOCK handling

If the audit returns BLOCK:

1. Increment BLOCK counter for that PR
2. If counter < 3: send the BLOCK body (NOT the full audit.md, NOT
   test-spec.md, per signals.md) to the SAME builder agent via SendMessage —
   it keeps its context and warm cache. The message MUST state: "Your
   worktree was merged back and removed. Work in the main checkout at
   {path}; run `git status` there before editing." Dispatch a fresh builder
   only if the original agent is no longer available (e.g., session
   restart), passing the BLOCK body in the dispatch prompt.
3. If counter = 3: emit HOLD classification `repeated-block`; pause the pipeline for user decision (limit defined in signals.md §BLOCK)

### 2d. Dispatch the reviewer (after the audit passes)

Tell the user: "The tester returned for PR {N} ({slug}). Dispatching the reviewer — expect 5–10 min."

With audit verdict=PASS, dispatch one `reviewer`:

> PR: {number} — {slug}
> All artifacts: spec.md, test-spec.md, implementation.md, audit.md, comprehension.md (if present)
> Read: .claude/agents/reviewer.md, plus signals.md, artifact-schemas.md, and r-package-profile.md from pipeline-shared/references

The reviewer returns `review.md` with verdict PASS / BLOCK / STOP.

### 2e. Review verdict handling

Tell the user: "Reviewer returned for PR {N} ({slug}) — verdict: {PASS/BLOCK/STOP}."

- **PASS** → proceed to pre-PR gate (2e.5)
- **BLOCK** → re-dispatch the target the reviewer identified: builder (code fix) or pipeline-spec (spec defect). Increment the BLOCK counter; same limit as 2c.
- **STOP** → pipeline halts. Write HOLD to `decisions.md`. User must resolve before resume.

### 2e.5. Pre-PR gate

Skip check first: read `Tree:` from this PR's `audit.md` and compare to
`git rev-parse 'HEAD^{tree}'` on the feature branch. If they match, the
tester already ran these gates on this exact tree — skip the rerun and
proceed to the shipper (log "pre-PR gate: SKIPPED — tree unchanged since
audit"). If they differ (or `audit.md` has no `Tree:` line), run the gate
as below.

Before dispatching the shipper, run on the feature branch:

```bash
Rscript -e 'devtools::check()'
Rscript -e 'pkgdown::check_pkgdown()'
```

If either fails → HOLD with classification `pre-pr-check-failure`. Diagnose
and fix (re-dispatch builder if a code change is needed; fix `_pkgdown.yml`
directly if it is a reference-index issue). Re-run the gate after the fix.
Do not dispatch the shipper until both commands exit clean.

### 2f. Dispatch the shipper

With review verdict=PASS, dispatch one `shipper`:

> PR: {number} — {slug}
> Review: {path to workspace review.md}
> Plan: {path to workspace implementation-plan.md}
> Read: .claude/agents/shipper.md

The shipper opens the PR, monitors CI, merges, and marks `[x]` in the plan.

## Step 3 — Post-PR verification

After the shipper returns:

1. `git checkout develop && git pull`
2. Re-run `devtools::test()` on the updated develop
3. If any test fails that was passing in the baseline → HOLD with classification `post-merge-regression`

Only then start the next PR's builder.

## Step 4 — Advance to DONE

After every PR is merged and all plan checkboxes are `[x]`:

1. Append `DONE` to `status.md`
2. Proceed to Step 5 before returning to the user

## Step 5 — Archive planning docs

After DONE is written:

1. Run the archive procedure in
   `.claude/skills/pipeline-shared/references/archive-plans.md`. The slug comes
   from the implementation plan filename
   (`plans/implementation-plan-{slug}.md`), or from the run directory name
   when no plan file exists.

2. The procedure's step 4 stops closeout when a cited document resolves to no
   file. HOLD with classification `unarchived-citation` and the script's
   output. The user decides which exit each name takes; the two are in
   `archive-plans.md` step 4.

3. **Return to user** with summary: PRs merged, coverage delta, any STOPs, which files were archived, and any citation marked in step 4.

## Signal handling

- **HOLD** — any stage. Pause, write to decisions.md, ask user.
- **BLOCK** (from tester) — route back to builder per 2c.
- **BLOCK** (from reviewer) — route back to builder or pipeline-spec per 2e.
- **STOP** (from reviewer) — halt pipeline. HOLD with full STOP body. User must override in decisions.md to resume.

BLOCK cycle limit and body schemas: signals.md.

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/r-package-profile.md`
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/skills/pipeline-shared/references/archive-plans.md`
- `.claude/agents/builder.md`, `tester.md`, `reviewer.md`, `shipper.md`
