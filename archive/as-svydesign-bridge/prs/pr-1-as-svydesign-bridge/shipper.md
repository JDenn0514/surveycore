# Ship record — PR 1, as-svydesign-bridge

**PR**: [#259](https://github.com/JDenn0514/surveycore/pull/259)
**Title**: `fix(conversion): route a survey_nonprob design on its weight shape (#237)`
**Base**: `develop`
**Branch**: `fix/as-svydesign-bridge` — deleted on origin and locally
**Merge**: squash, `6c31492ff1ad5a5bd57ef3179cb2e19fad91d34a`
**Merged**: 2026-09-09T17:31:36Z
**Review verdict at ship time**: PASS

## Diff as merged

Eight files, 733 insertions, 22 deletions.

| File | + | - |
|---|--:|--:|
| `R/methods-conversion.R` | 100 | 11 |
| `changelog/fix-as-svydesign-bridge.md` | 145 | 0 |
| `man/as_svydesign.Rd` | 69 | 9 |
| `man/as_tbl_svy.Rd` | 2 | 2 |
| `plans/error-messages.md` | 26 | 0 |
| `tests/testthat/_snaps/conversion.md` | 19 | 0 |
| `tests/testthat/test-conversion.R` | 341 | 0 |
| `vignettes/surveycore-vs-survey.Rmd` | 31 | 0 |

`NEWS.md`, `NAMESPACE`, `DESCRIPTION`, `R/core-constructors.R`,
`R/methods-print.R` and `tests/testthat/_snaps/methods-print.md` show no diff,
as the spec's quality gates require.

## CI

Seven required checks, all `pass`, on three separate runs. The first two runs
were discarded by branch updates, not by failures.

| Check | Result |
|---|---|
| `pkgdown` | pass |
| `codecov/patch` | pass |
| `test-coverage` | pass |
| `ubuntu-latest (release)` | pass |
| `ubuntu-latest (devel)` | pass |
| `macos-latest (release)` | pass |
| `windows-latest (release)` | pass |

## The merge took three CI cycles, and none of them failed

Branch protection on this repository requires the head branch to be up to date
with the base, and repository auto-merge is disabled
(`enablePullRequestAutoMerge` is refused). Two other sessions were merging into
`develop` at the same time, from two other live worktrees. So each time CI went
green the PR had fallen behind and needed `gh pr update-branch`, which restarted
CI.

| Cycle | Head | Went green | Then |
|---|---|---|---|
| 1 | `e45aee2` | 7/7 pass | `develop` had gained `f88d42b` and `dbff0d9` |
| 2 | `8d6f350` | 7/7 pass | `develop` had gained `d354af6` |
| 3 | `02b9bac` | 7/7 pass | merged |

The three commits that arrived meanwhile:

- `f88d42b fix(pipeline): gate 1 compares man/ before and after document() (#233) (#252)`
- `dbff0d9 docs(changelog): document the flat changelog path and real entry format`
- `d354af6 fix(constructors): default JK2 scale to 1, not (R-1)/R (#242) (#258)`

The first two touch only `.claude/` tooling and two `changelog/` files. The
third touches package source — `R/core-constructors.R`, two test files,
`man/as_survey_replicate.Rd` and `NEWS.md` — and it is issue **#242**, which
this feature's `spec.md` §Out named as out of scope and assigned elsewhere. It
was absorbed by cycle 3's update and revalidated by cycle 3's CI. After the
update the branch was 0 commits behind `develop` and its diff against `develop`
was still exactly the eight files above, so nothing was duplicated.

**Worth carrying forward.** Updating the branch immediately before opening the
PR, rather than after CI has already passed, would have cost one cycle instead
of three. On a repository with these two settings and concurrent sessions, a PR
that waits through another merge always pays a full CI cycle.

## What the orchestrator did, not the shipper

Two departures from `.claude/agents/shipper.md`, both recorded so a later
reader does not read them as skipped steps.

1. **Step 6, CI monitoring.** The contract specifies `ScheduleWakeup`, which is
   not in a subagent's toolset. In the previous pipeline run three shippers and
   three testers went silent waiting on background children that had been
   killed. The orchestrator held the CI watch instead, and the shipper ran
   `gh pr checks` once and returned.
2. **Step 7 and Step 8.** `gh pr merge --squash --delete-branch` succeeded in
   merging but its local cleanup failed with
   `fatal: 'develop' is already used by worktree at 'C:/Users/jdennen/surveycore'`,
   because `develop` is checked out in the main checkout and cannot be checked
   out again here. The remote branch deletion did not run, so the orchestrator
   deleted it with `git push origin --delete`, detached this worktree onto the
   `develop` tip, deleted the local branch, and wrote this record. The shipper
   had already refused the merge once, correctly, when branch protection
   rejected a behind branch.

## Post-merge verification

`NOT_CRAN=true devtools::test()` on the merged `develop` at `6c31492`:

```
[ FAIL 0 | WARN 256 | SKIP 4 | PASS 11606 ]
```

No test that passed in the baseline fails now. PASS rose from 11538 at the
baseline to 11606: 57 from this PR and 11 from `#258`. WARN held at 256
throughout, so no new warning arrived.
