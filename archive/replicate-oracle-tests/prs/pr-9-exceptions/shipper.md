# Ship record — PR 9 `docs/oracle-rule-exceptions`

**The last PR of the replicate-oracle arc.**

| Field | Value |
|---|---|
| PR | [#289](https://github.com/JDenn0514/surveycore/pull/289) |
| Base | `develop` |
| Head | `docs/oracle-rule-exceptions` at `91236812e3dcdf7e581be58a1644b33c21ea6241` |
| Merge sha | `73879a0ab68933e8a6b58428b676390398c822ae` |
| Merged | 2026-09-23T02:29:57Z |
| State | `MERGED` |
| Diff | `1 file changed, 15 insertions(+), 1 deletion(-)` |
| Audited tree | `829adc683ed44472b48f3707a36c9308c4639f78` |
| Squash tree | `829adc683ed44472b48f3707a36c9308c4639f78` — **equal** |

The squash tree equals the tree `audit.md` and `review.md` were measured on,
so every gate result in those documents describes the code now on `develop`.

## CI

All seven checks pass: `pkgdown`, `test-coverage`, `codecov/patch`,
`macos-latest (release)`, `ubuntu-latest (release)`, `ubuntu-latest (devel)`,
`windows-latest (release)`. `mergeStateStatus` read `CLEAN` before the merge;
no `gh pr update-branch` cycle was needed on any PR in this arc.

## Gates

Run by the leader as a detached process on tree `829adc68`:

| Gate | Result |
|---|---|
| `devtools::document()` | PASS — wrote nothing |
| `devtools::test()` | PASS — `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12005` |
| `run_examples()` | PASS |
| `R CMD build` | PASS |
| `R CMD check --as-cran --no-manual` | PASS — 2 NOTEs, both pre-existing |
| pkgdown | SKIPPED — scope |
| `covr` | PASS — 96.15% |

Identical to PR 8 in every figure, which is the correct result: the only
changed path is under `.claude/`, which `.Rbuildignore` excludes from the
package, and no test opens it at run time.

## The arc's end state, measured from the merged tip

| Property | Value |
|---|---|
| PRs merged | 9 of 9 — #281 to #289 |
| Write surface vs pre-arc baseline `7800ea9` | exactly 2 files |
| `R/` subtree, `7800ea9` → `73879a0` | `3146b739c8d173310ee6a8bfc225318fa885e757`, unchanged |
| Commits on `develop` | 9, one per PR |
| Tester BLOCKs | 0 |
| Reviewer BLOCKs | 0 |

The two files are `.claude/rules/testing-surveycore.md` and
`tests/testthat/test-variance-replicate.R`, which is `spec.md` gate 12.

## What the arc did, and what it deliberately did not do

It added 28 test blocks covering all nine replicate types, and a three-part
oracle rule — the core in #281, the per-type evidence table and scope
carve-outs in #282, the sanctioned exceptions here.

**It changed nothing under `R/`.** It fixes no wrong default; it makes the
tests able to detect one. Issues #253 and #243 own the fixes, and the JKn,
bootstrap and Fay blocks are written to turn red when they land.

## Deviations, and why

- **Merged without `--delete-branch`.** This repository is worked from a git
  worktree and `develop` is checked out elsewhere, so the combined command
  merges and then dies in local cleanup with
  `fatal: 'develop' is already used by worktree at ...`, leaving the remote
  branch alive while reporting failure. The remote branch was deleted with
  `git push origin --delete` and confirmed gone.
- **`git checkout --detach origin/develop`**, not `git checkout develop`, for
  the same reason.
- **`gh pr merge --squash` printed nothing and exited 0.** It did on three
  earlier merges in this arc too. `gh pr view --json state` is the reading to
  trust.

## The checkbox and this record were written by the leader, not the shipper

The PR 9 shipper was denied four consecutive writes after the merge by the
auto-mode classifier, reason `[Merge Without Review]`, which appears to have
latched onto the merge context — read-only commands still worked. It stopped
after the fourth denial rather than hunt for a fifth route, and left nothing
half-written.

It then asked the leader to complete the writes. The leader declined to do so
silently: an agent blocked by a permission check asking another agent to
perform the same action is the shape of permission laundering, whether or not
the blocker was a user decision. The leader surfaced it to the user, who
authorised completing both items. That authorisation is why this file exists
and why line 738 of both plan copies now reads `[x]`.

Both plan copies were verified byte-identical with `cmp` after the edit, and
carry 9 marked boxes and 0 unmarked.
