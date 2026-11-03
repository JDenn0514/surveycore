# Shipper — PR 3 — as-svydesign-domain-replicate-nonprob
> Citations of `plans/*-as-svydesign-domain.md` below carry `[no such file]`: those four files were moved into `archive/as-svydesign-domain/` at archive time (2026-09-11), so the path they name no longer exists. The documents are beside this one.

**Status**: PR opened, not merged. Merge awaits a leader instruction (CI is watched by the dispatching session, not this agent).

## Gate

`review.md` verdict: PASS (read in full before proceeding).

## Pre-PR gate

Skipped — tree unchanged since audit. Audit tree
`5819738648687bc08c7a7fa40204826aaec51864` equals HEAD tree at push time.

## Branch and commits

- Branch: `fix/as-svydesign-domain-replicate-nonprob`
- Commits (both by the builder, no new commit made by this agent):
  - `843b33e` — `fix(conversion): restrict a converted replicate design to the active domain`
  - `8c86c5f` — `test(conversion): pin the domain restriction on the replicate and nonprob routes`
- Cut from `develop` at `67914a0` (= `origin/develop` at push time), 2 commits ahead, 0 behind.
- Pushed with `git push -u origin fix/as-svydesign-domain-replicate-nonprob`.

## Worktree state at push time

Tree was clean apart from the arc's planning artifacts, left untouched per instruction:
- Untracked: `plans/decisions-as-svydesign-domain.md` [no such file], `plans/implementation-plan-as-svydesign-domain.md`, `plans/spec-as-svydesign-domain.md`, `plans/test-spec-as-svydesign-domain.md` [no such file]
- Modified: `plans/pr-budget-calibration.md`

None of these five were staged, committed, or reverted.

## PR

- Number: 268
- URL: https://github.com/JDenn0514/surveycore/pull/268
- Base: `develop`
- Title: `fix(conversion): restrict a converted replicate design to the active domain`

## CI

Checked once immediately after opening via `gh pr checks 268`: all six required
checks (`macos-latest (release)`, `pkgdown`, `test-coverage`,
`ubuntu-latest (devel)`, `ubuntu-latest (release)`,
`windows-latest (release)`) were `pending`. Not polled further by this agent —
monitoring and merge are deferred to the orchestrator per instruction.

## Not done (out of scope for this step)

- No merge
- No squash
- No branch deletion
- No `implementation-plan.md` checkbox update (deferred until merge)

## Merge — 2026-09-11

- Coordinator confirmed CI 7/7 pass, `mergeStateStatus=CLEAN`,
  `mergeable=MERGEABLE`, re-verified independently via `gh pr checks 268`
  (all 7 checks `pass`: codecov/patch, macos-latest release, pkgdown,
  test-coverage, ubuntu-latest devel, ubuntu-latest release, windows-latest
  release) and `gh pr view 268 --json state,mergeStateStatus,mergeable`
  (`OPEN`/`CLEAN`/`MERGEABLE`) before merging.
- Squash merged with `gh pr merge 268 --squash --subject "fix(conversion): restrict a converted replicate design to the active domain (#268)" --body ""`
  — no `--delete-branch` flag (worktree hazard avoided).
- Squash commit message: `fix(conversion): restrict a converted replicate design to the active domain (#268)`
- Merge commit SHA: `9625c1866d861855b1f31e9b70a8f13318b70e8f`
- Confirmed via `gh pr view 268 --json state,mergeCommit,mergedAt`:
  `state=MERGED`, `mergedAt=2026-09-11T18:36:13Z`.
- Remote branch delete: `git push origin --delete fix/as-svydesign-domain-replicate-nonprob` — succeeded.
- CI cycle count: 1. `develop` never moved under this PR; no rebase or
  update-branch cycle was needed.
- No `git checkout develop` performed (main checkout has it open elsewhere)
  — local branch/tip sync left to the coordinator/leader as instructed.
- No R gate run. `NEWS.md` untouched. `plans/` untracked/modified files left
  untouched throughout.
