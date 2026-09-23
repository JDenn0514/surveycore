# Ship — PR 2 — oracle-rule-evidence

**Branch**: `docs/oracle-rule-evidence` (type `docs/`, not `feature/` — a rules-file change)
**PR URL**: https://github.com/JDenn0514/surveycore/pull/282
**Merged**: 2026-09-22 16:04:22 UTC (10:04:21 -0600)
**Merge commit**: `e61518a42681f87d92f52b32ec527f10a9461877`
**Base at merge**: `70bfe5495c1362284d13d3a56ec07c12e6ea1eff` — PR #281's merge commit
**Head merged**: `c4c23f20c3c056add324eaa8fecdf6611b5aba42`
**Commit tree**: `51b1aee208097c6452bc58d86f750c0a0c7011bb` — the squash commit carries the same tree `audit.md` and `review.md` record, so the merge changed no byte
**Diff**: `1 file changed, 54 insertions(+)` — `.claude/rules/testing-surveycore.md`

## Timeline

- 15:53 pushed to `origin/docs/oracle-rule-evidence`; PR #282 opened against `develop`
- 15:53 first `mergeStateStatus` read `BLOCKED` (CI pending), `mergeable` read `MERGEABLE`
- 16:04 CI green — all seven checks pass, measured at the leader level; `mergeState` read `CLEAN`
- 16:04 squash merged
- 16:05 remote branch deleted, worktree detached at `origin/develop`, local branch deleted

Nothing landed on `develop` while CI ran, so no branch update was needed and the merge took one cycle.

## CI gates

| Check | Result | Time |
|---|---|---|
| `ubuntu-latest (release)` | PASS | 7m9s |
| `ubuntu-latest (devel)` | PASS | 7m54s |
| `macos-latest (release)` | PASS | 6m35s |
| `windows-latest (release)` | PASS | 10m12s |
| `pkgdown` | PASS | 3m30s |
| `test-coverage` | PASS | 4m34s |
| `codecov/patch` | PASS | — |

No re-run, no flake. `state` read `MERGED` after the merge.

## Local gates — not re-run, and why

`review.md` §Gate carry-forward cleared them, and re-measured the identity itself
on eight subtrees rather than taking `gates.md` on trust: `R`, `tests`, `man`,
`NAMESPACE`, `DESCRIPTION`, `vignettes`, `_pkgdown.yml` and `.Rbuildignore` are
all byte-identical from base to head. The only differing path is
`.claude/rules/testing-surveycore.md`, and `.Rbuildignore` line 8 excludes
`^\.claude$` from the build. Every `.claude` reference in `R/` and `tests/` is a
comment; none opens a file. So gates 1 to 7 would read identical inputs.

The figures in `gates.md` stand: `FAIL 0 | WARN 256 | SKIP 4 | PASS 11941`,
coverage 96.15% against a 96.15% baseline and a 95% floor.

This shipper ran no `devtools::test()`, no `devtools::check()` and no `covr`.

## Squash commit

One Conventional Commit line plus the PR number:

    docs(testing): add the oracle rule's per-type evidence and scope (#282)

Its body is the `Co-Authored-By: Claude Opus 5 (1M context)` trailer.

## Post-merge

- [x] Plan checkbox marked — both copies, line 295, and the two files stay byte-identical: `md5` matched before the edit (`bd585e72`) and matches after it (`6f719e55`), and `cmp` is silent on both readings
  - `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/implementation-plan.md` [no such file]
  - `plans/implementation-plan-replicate-oracle-tests.md` [no such file]
- [x] Remote branch deleted — `git push origin --delete docs/oracle-rule-evidence` reported `[deleted]`, and `git ls-remote --heads origin docs/oracle-rule-evidence` now returns nothing
- [x] Local branch deleted — `git branch -D docs/oracle-rule-evidence` (was `c4c23f2`)
- [x] Worktree moved to a detached head at `origin/develop` = `e61518a`
- [x] The five untracked `plans/` files stay untracked and unstaged, and the modified `plans/pr-budget-calibration.md` is untouched by this ship

## Operational notes for the seven PRs that follow

Both notes from PR 1's ship record held again, so they are confirmed twice:

1. **Do not pass `--delete-branch` to `gh pr merge` from this worktree.**
   `develop` is checked out in another worktree at `C:\Users\jdennen\surveycore`.
   Merge without the flag, then run `git push origin --delete {branch}`.
2. **Move off the merged branch with `git checkout --detach origin/develop`**, not
   `git checkout develop`, for the same worktree reason.

One thing to keep doing: read the merge result from
`gh pr view {n} --json state,mergeCommit`, not from the exit code. Here the exit
code was 0 and the state read `MERGED`, so the two agreed — but PR 1's note
records a case where they did not.

## Rule text shipping status after this PR

The oracle rule ships in three parts. PR #281 shipped the core, this PR shipped
the per-type evidence table and the scope subsection, and PR 9 adds the
sanctioned exceptions plus the `**Version:**` bump that `review.md` §3 defers to
it. PR #281's two forward references now resolve.
