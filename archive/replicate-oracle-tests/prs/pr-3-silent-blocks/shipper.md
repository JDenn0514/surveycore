# Ship — PR 3 — silent-blocks

**Branch**: `test/replicate-oracle-silent-blocks` (type `test/`, not `feature/` — a test-only change)
**PR URL**: https://github.com/JDenn0514/surveycore/pull/283
**Merged**: 2026-09-22 17:42:04 UTC (11:42:04 -0600)
**Merge commit**: `bf47f79f4f8de9aeead6ddce47a8472d89556eaf`
**Base at merge**: `e61518a42681f87d92f52b32ec527f10a9461877` — PR #282's merge commit
**Head merged**: `dadfb2b64d111f0ba48509eeb7a32530898ca285`
**Commit tree**: `2ac094bf91835d3af71e31aab10bc28e19882c15` — the squash commit carries the same tree `audit.md` and `review.md` record, so the merge changed no byte
**Diff**: `1 file changed, 90 insertions(+), 48 deletions(-)` — `tests/testthat/test-variance-replicate.R`

## For the budget ledger

The write surface is one file under `tests/`, so the additions formula returns a
non-zero number for the first time in this arc:

| Field | Value |
|---|--:|
| Files changed | 1 |
| Insertions | 90 |
| Deletions | 48 |
| Net lines | +42 |
| Files under `R/` | 0 |

48 of the deletions are the eight `survey::svrepdesign()` call bodies re-indented
one level inside the new wrapper, not removed content — `review.md` §Tolerance
integrity lists all 48 line for line.

## Timeline

- 17:23 pushed to `origin/test/replicate-oracle-silent-blocks`; PR #283 opened against `develop`
- 17:23 first `mergeStateStatus` read `BLOCKED` (CI pending), `mergeable` read `MERGEABLE`
- 17:41 CI green — all seven checks pass; `mergeStateStatus` read `CLEAN`
- 17:42 squash merged; `state` read `MERGED`
- 17:43 remote branch deleted, worktree detached at `origin/develop`, local branch deleted

`origin/develop` sat at the branch base `e61518a` at push time and nothing landed
on it while CI ran, so no `gh pr update-branch` was needed. One cycle.

## CI gates

| Check | Result | Time |
|---|---|---|
| `ubuntu-latest (release)` | PASS | 5m21s |
| `ubuntu-latest (devel)` | PASS | 7m27s |
| `macos-latest (release)` | PASS | 8m37s |
| `windows-latest (release)` | PASS | 9m43s |
| `pkgdown` | PASS | 3m18s |
| `test-coverage` | PASS | 6m57s |
| `codecov/patch` | PASS | 1s |

No re-run, no flake.

**This is the arc's first PR whose CI exercised the change.** PRs #281 and #282
moved rule text only. The eight new no-warning and stored-scale assertions ran on
all four `R CMD check` platforms, not only against the local `survey` 4.5, and
passed on each. The per-type scale table in `.claude/rules/testing-surveycore.md`
therefore holds on every platform CI builds.

## Local gates — not re-run, and why

The pre-PR gate was skipped on the dispatch's instruction, and the identity it
rests on was verified twice: `git rev-parse 'HEAD^{tree}'` on the branch head read
`2ac094bf91835d3af71e31aab10bc28e19882c15`, matching the `Tree:` line in
`audit.md`, in `review.md` and in `logs/pr3/runner.log`. The merge commit carries
that same tree. The seven gates ran on exactly these bytes.

The figures in the gate log stand: `FAIL 0 | WARN 256 | SKIP 4 | PASS 11977`
against a baseline of 11941, coverage 96.15% against a 96.15% baseline and a 95%
floor, `R CMD check` 2 NOTEs both pre-existing, pkgdown SKIPPED for scope with an
empty `NAMESPACE` diff.

This shipper ran no `devtools::test()`, no `devtools::check()` and no `covr`.

## Squash commit

One Conventional Commit line plus the PR number:

    test(variance): assert the silent oracle blocks' conditions and stored scales (#283)

Its body is the `Co-Authored-By: Claude Opus 5 (1M context)` trailer.

## Post-merge

- [x] Remote branch deleted — `git push origin --delete test/replicate-oracle-silent-blocks`
- [x] Local branch deleted — `git branch -D test/replicate-oracle-silent-blocks` (was `dadfb2b`)
- [x] Worktree moved to a detached head at `origin/develop` = `bf47f79`
- [x] PR 3 marked `[x]` at line 343 in both plan copies; `cmp` reads them byte-identical after the edit
- [x] The five untracked `plans/` files stay untracked and unstaged, and the modified `plans/pr-budget-calibration.md` is untouched by this ship

## Operational notes for the six PRs that follow

Both notes from the PR 1 and PR 2 ship records held a third time:

1. **Do not pass `--delete-branch` to `gh pr merge` from this worktree.**
   `develop` is checked out in another worktree at `C:\Users\jdennen\surveycore`.
   Merge without the flag, then run `git push origin --delete {branch}`.
2. **Move off the merged branch with `git checkout --detach origin/develop`**, not
   `git checkout develop`, for the same worktree reason.

One note specific to this PR's successors. **PR 4 inherits two live breaches and
one open style question.** The JK1 block still passes a `scale` argument and both
the JK1 and JK2 blocks still wrap their `survey` call in `suppressWarnings()`;
they were left whole here so PR 4 rewrites them without colliding with a partial
repair. Separately, `review.md` §Ruling records that the stored-scale comment
ships at 99 characters against an 80-column `.lintr` setting no pipeline gate
reads, and names PR 4 as the cheap place to fix one canonical comment text for all
13 blocks — a leader's call, not a defect carried forward.
