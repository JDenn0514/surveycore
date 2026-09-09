# shipper.md — PR 3 — svydesign-replicate-bridge

**PR**: https://github.com/JDenn0514/surveycore/pull/247
**Title**: fix(conversion): refuse four unusable replicate sources on import (#197)
**Branch**: `fix/svydesign-replicate-guards` (deleted from origin post-merge)
**Base**: `develop`
**Merge strategy**: squash
**Merge commit SHA**: `1f15d35b82d569c6a560e2a42c2068724cbbc07f`
**Pre-merge commit (unamended)**: `c9c93ca`
**Merged at**: 2026-09-08T21:47:53Z

## Gate summary (per orchestrator; not re-run by shipper)

- `document()`: no drift
- `devtools::test()`: FAIL 0 | WARN 256 | SKIP 4 | PASS 11366 (base: 11343)
- `run_examples()`: clean
- `R CMD build`: clean
- `R CMD check --as-cran --no-manual`: Status 2 NOTEs, both pre-existing
- `pkgdown`: built
- `covr`: 96.22% (up from 96.20%); `R/methods-conversion.R` 99.40% (up from 99.19%)

## CI (PR #247, all terminal and passing before merge)

| Check | Result | Duration |
|---|---|---|
| codecov/patch | pass | — |
| macos-latest (release) | pass | 7m0s |
| pkgdown | pass | 4m13s |
| test-coverage | pass | 6m44s |
| ubuntu-latest (devel) | pass | 8m15s |
| ubuntu-latest (release) | pass | 14m12s |
| windows-latest (release) | pass | 9m29s |

## Post-merge actions

- Marked PR 3 `[x]` in `archive/svydesign-replicate-bridge/implementation-plan-svydesign-replicate-bridge.md` (untracked file, edit not committed)
- Deleted remote branch `fix/svydesign-replicate-guards` (squash merge did not auto-delete; local branch left for the coordinator — this is a linked worktree checked out on that branch)
- Did not run `git checkout develop` in this worktree (develop is held by a sibling worktree)

## HOLDs

None. Review verdict was PASS, CI was green and mergeStateStatus CLEAN before merge, plain `gh pr merge --squash` succeeded without any bypass flag.
