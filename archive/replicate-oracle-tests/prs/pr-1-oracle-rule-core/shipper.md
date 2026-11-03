# Ship — PR 1 — oracle-rule-core

**Branch**: `docs/oracle-rule-core` (type `docs/`, not `feature/` — a rules-file change)
**PR URL**: https://github.com/JDenn0514/surveycore/pull/281
**Merged**: 2026-09-22 08:45
**Merge commit**: `70bfe5495c1362284d13d3a56ec07c12e6ea1eff`
**Base at merge**: `7800ea9730acdcf03ae33dc24bb9a008a8920e33`
**Head merged**: `1879a34b06b9dc02969d407eb8e36e31726bea7d`
**Commit tree**: `5152c6eb4e07b28c4a149b2294fceec0b5a8ef15` — equals the tree `audit.md` and `review.md` record
**Diff**: `1 file changed, 81 insertions(+)` — `.claude/rules/testing-surveycore.md`

## Timeline

- 08:18 branch commit `1879a34` created (by the builder, before this shipper ran)
- 08:32 pushed to `origin/docs/oracle-rule-core`
- 08:33 PR #281 opened against `develop`
- 08:44 CI green — all seven checks pass
- 08:45 squash merged
- 08:46 remote branch deleted, worktree detached, local branch deleted

## CI gates

| Check | Result | Time |
|---|---|---|
| `ubuntu-latest (release)` | PASS | 7m3s |
| `ubuntu-latest (devel)` | PASS | 8m24s |
| `macos-latest (release)` | PASS | 5m17s |
| `windows-latest (release)` | PASS | 10m55s |
| `pkgdown` | PASS | 3m14s |
| `test-coverage` | PASS | 6m55s |
| `codecov/patch` | PASS | — |

No re-run, no flake. `mergeStateStatus` read `CLEAN` and `mergeable` read `MERGEABLE` before the merge, and `state` read `MERGED` after it.

## Local gates — not re-run, and why

`review.md` §Step 4 cleared the carry-forward. The only differing path is
`.claude/rules/testing-surveycore.md`, `.Rbuildignore` line 8 excludes
`^\.claude$` from the build, and no test opens the file at run time. The `R`,
`tests` and `man` subtree hashes are identical from base to head, so gates 1 to 7
would run identical code over identical inputs. The figures in `gates.md` stand:
`FAIL 0 | WARN 256 | SKIP 4 | PASS 11941`, coverage 96.15%.

This shipper ran no `devtools::test()`, no `devtools::check()` and no `covr`. The
host had about 1.8 GB free and a memory watchdog that kills R processes.

## Squash commit

The squash commit is one Conventional Commit line plus the PR number:

    docs(testing): add the oracle rule's core to the testing rules (#281)

Its body carries the three-part shipping note, the two open breaches in
`tests/testthat/test-variance-replicate.R` that PR 4 closes, `Refs #256, #257`,
and the `Co-authored-by` trailer.

## Post-merge

- [x] Plan checkbox marked — both copies, line 232, and the two files stay byte-identical (`md5` matched before the edit and `diff` is empty after it):
  - `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/implementation-plan.md` [no such file]
  - `plans/implementation-plan-replicate-oracle-tests.md` [no such file]
- [x] Remote branch deleted — `git push origin --delete docs/oracle-rule-core` reported `[deleted]`, and `git ls-remote --heads origin docs/oracle-rule-core` now returns nothing
- [x] Local branch deleted — `git branch -D docs/oracle-rule-core` (was `1879a34`)
- [x] Worktree moved to a detached head at `origin/develop` = `70bfe54`
- [x] The five untracked `plans/` files stay untracked and unstaged

## Two operational notes for the eight PRs that follow

1. **Do not pass `--delete-branch` to `gh pr merge` from this worktree.** `develop`
   is checked out in another worktree at `C:\Users\jdennen\surveycore`. On an
   earlier arc the flag merged the PR and then died in local cleanup with
   `fatal: 'develop' is already used by worktree at ...`, which left the remote
   branch alive while reporting failure. Merge without the flag, then delete the
   remote branch with `git push origin --delete {branch}`.
2. **Move off the merged branch with `git checkout --detach origin/develop`**, not
   `git checkout develop`, for the same worktree reason.
