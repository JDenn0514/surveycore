# Ship — PR 8 — test/replicate-oracle-fay

**Branch**: `test/replicate-oracle-fay`
**PR URL**: https://github.com/JDenn0514/surveycore/pull/288
**Merged**: 2026-09-23 01:06 UTC
**Merge commit**: `d6d30c7a89c1704cf1eb35fc3520065ee3e6366d`
**Squash parent**: `d389bdaf514ce59c97523c63499639c532b1e519`
**Head merged**: `d8c50cd37346631c6dbda4221f89858b22d187d6`

## Tree integrity

The squash commit's tree equals the audited tree.

```
git rev-parse d6d30c7^{tree}  = c23121ef6ad6423375765ffaaa277d2c4ac530eb
audit.md / review.md tree     = c23121ef6ad6423375765ffaaa277d2c4ac530eb
```

The squash carried the reviewed content across with no drift. `git diff --stat
d389bda d6d30c7` reads one file, 49 insertions, 0 deletions — the same shape the
branch carried. The squash commit has one parent, so nothing else landed inside it.

## Timeline

- branch created — before this agent ran; the builder left one commit, `d8c50cd`
- pushed — `git push -u origin test/replicate-oracle-fay`, new branch, no force
- PR opened — #288, base `develop`, head `test/replicate-oracle-fay`
- CI green — seven checks, reported by the coordinator
- merged — 2026-09-23 01:06:41 UTC, squash

No `gh pr update-branch` was needed at any point. `origin/develop` sat at
`d389bda` when the branch went up and still sat there when CI finished, so the
head branch never went stale. Earlier PRs in this arc lost cycles to exactly that;
this one did not.

## CI gates

- `pkgdown`: PASS
- `test-coverage`: PASS
- `codecov/patch`: PASS
- `macos-latest (release)`: PASS
- `ubuntu-latest (release)`: PASS
- `ubuntu-latest (devel)`: PASS
- `windows-latest (release)`: PASS

Merge state before merging read `mergeStateStatus=CLEAN mergeable=MERGEABLE`.

## Pre-merge gate results

Measured by the tester on tree `c23121ef` — the tree that merged. The shipper ran
no gates.

```
document()      PASS — wrote nothing
test()          PASS — FAIL 0 | WARN 256 | SKIP 4 | PASS 12005   (PR 7 left 12003, so +2)
run_examples()  PASS
R CMD build     PASS
R CMD check     PASS — 2 NOTEs, both pre-existing on the baseline
pkgdown         SKIPPED — scope, NAMESPACE diff empty
covr            PASS — 96.15%, flat
```

The +2, against the +7 each comparing block contributed, is itself evidence the
Fay block compares nothing: two assertions, where a comparing block carries five
plus its condition.

## The test file is final at this commit

`tests/testthat/test-variance-replicate.R` takes no further change in this arc.
PR 9 writes only `.claude/rules/testing-surveycore.md`.

Its finished state, measured twice by two different instruments — an awk
comment-and-string stripper and a `utils::getParseData()` parse walk — which
agreed on every figure:

| Property | Value |
|---|---|
| `test_that()` blocks | 28 |
| Replicate types with an oracle block | 9 of 9 |
| `test_invariants()` calls | 1 |
| `suppressWarnings()` calls | 0 |
| `scale` arguments to `svrepdesign()` | 0 |
| `rscales` arguments | 1, in JKn, same literal both sides |
| Canonical stored-scale comments | 13 |
| Titles claiming no match | 3 |

**Count these by parsing, not by `grep`.** Textual counting gives wrong answers
on this file and misled six agents: `grep` reads `expect_failure` at 12 against 6
real calls, and `svrepdesign` at 18 against 14. A stripper that removes comments
but keeps string contents still reads 15, because one occurrence sits inside the
Fay block's own title. Strip comments *and* string contents, or parse.

## Post-merge

- [x] Plan checkbox marked — PR 8, line 670, in both copies:
      `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/implementation-plan.md` [no such file]
      and `plans/implementation-plan-replicate-oracle-tests.md` [no such file]. Edited with the
      `Edit` tool, not `sed -i`. `cmp` reports the two files byte-identical
      afterwards. Eight boxes are marked; only PR 9 stays open.
- [x] Branch deleted, remote — `git push origin --delete test/replicate-oracle-fay`
- [x] Branch deleted, local — `git branch -D test/replicate-oracle-fay` (was `d8c50cd`)

Two deviations from the default shipper steps, both deliberate and both because
this is a worktree while `develop` is checked out at `C:\Users\jdennen\surveycore`:

1. `gh pr merge` ran **without** `--delete-branch`. The combined form merges and
   then fails in local cleanup, which leaves the remote branch alive while
   reporting failure. The remote delete ran as its own command instead.
2. The checkout is `git checkout --detach origin/develop`, not `git checkout
   develop`. HEAD is detached at `d6d30c7`.

`gh pr merge` printed nothing and exited 0. That is its third silent success in
this arc; `gh pr view 288 --json state` reading `MERGED` is the evidence, not the
exit code.

Nothing under `plans/` was staged or committed. The five untracked `plans/` files
and the modified `plans/pr-budget-calibration.md` stay as they were, apart from
the one checkbox above.
