# Shipper — PR 5 — as-svydesign-domain (docs)
> Citations of `plans/*-as-svydesign-domain.md` below carry `[no such file]`: those four files were moved into `archive/as-svydesign-domain/` at archive time (2026-09-11), so the path they name no longer exists. The documents are beside this one.

**Status**: PR opened, not merged. Merge awaits a leader instruction (CI is watched by the dispatching session, not this agent).

## Gate

`review.md` verdict: PASS (read in full before proceeding).

## Pre-PR gate

Skipped — tree unchanged since audit. Audit tree
`677a9f3fadf6da9fab20b9bfb42d1c709124a236` equals HEAD tree at push time.

## Branch and commits

- Branch: `docs/as-svydesign-domain`
- Commit (builder's, no new commit made by this agent):
  - `eb602c0` — `docs(conversion): document the domain restriction as_svydesign() applies`
- Cut from `develop` at `d5dcca4` (= `origin/develop` at push time), 1 commit ahead, 0 behind.
- Pushed with `git push -u origin docs/as-svydesign-domain`.

## Worktree state at push time

Tree was clean apart from the arc's planning artifacts, left untouched per instruction:
- Untracked: `plans/decisions-as-svydesign-domain.md` [no such file], `plans/implementation-plan-as-svydesign-domain.md`, `plans/spec-as-svydesign-domain.md`, `plans/test-spec-as-svydesign-domain.md` [no such file]
- Modified: `plans/pr-budget-calibration.md`

None of these five were staged, committed, or reverted.

## PR

- Number: 270
- URL: https://github.com/JDenn0514/surveycore/pull/270
- Base: `develop`
- Title: `docs(conversion): document the domain restriction as_svydesign() applies`

## CI

Checked once immediately after opening via `gh pr checks 270`: all six required
checks (`macos-latest (release)`, `pkgdown`, `test-coverage`,
`ubuntu-latest (devel)`, `ubuntu-latest (release)`,
`windows-latest (release)`) were `pending`. Not polled further by this agent —
monitoring and merge are deferred to the orchestrator per instruction.

## Not done (out of scope for this step)

- No merge
- No squash
- No branch deletion
- No `implementation-plan.md` checkbox update (deferred until merge — orchestrator's job)

## Arc note

This is PR 5, the last PR of the as-svydesign-domain arc. review.md's
"Arc closeout" section records the five deferred items and confirms no
`spec.md` gate was left undelivered.

## Merge — 2026-09-11

- Coordinator confirmed CI 7/7 pass, `mergeStateStatus=CLEAN`,
  `mergeable=MERGEABLE`, and `origin/develop` unmoved at `d5dcca4`
  (0 behind / 1 ahead). Re-verified independently before merging via
  `gh pr checks 270` (all 7 checks `pass`: codecov/patch, macos-latest
  release, pkgdown, test-coverage, ubuntu-latest devel, ubuntu-latest
  release, windows-latest release) and
  `gh pr view 270 --json state,mergeStateStatus,mergeable`
  (`OPEN`/`CLEAN`/`MERGEABLE`).
- Squash merged with `gh pr merge 270 --squash --subject "docs(conversion): document the domain restriction as_svydesign() applies (#270)" --body ""`
  — no `--delete-branch` flag (worktree hazard avoided).
- Squash commit message: `docs(conversion): document the domain restriction as_svydesign() applies (#270)`
- Merge commit SHA: `d889c86d8d14fa999a02dc5cfdf53ad46e5f3d05`
- Confirmed via `gh pr view 270 --json state,mergeCommit,mergedAt`:
  `state=MERGED`, `mergedAt=2026-09-11T21:18:34Z`.
- Remote branch delete: `git push origin --delete docs/as-svydesign-domain` — succeeded.
- CI cycle count: 1. `develop` never moved under this PR; no rebase or
  update-branch cycle was needed.
- No `git checkout develop` performed (main checkout has it open elsewhere)
  — local branch/tip sync left to the coordinator/leader as instructed.
- No local branch deleted, `plans/` untouched, `implementation-plan.md`
  checkbox left for the orchestrator, as instructed.
