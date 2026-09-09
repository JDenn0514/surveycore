# Review — PR 1 — svydesign-replicate-bridge

**Verdict**: PASS
**Date**: 2026-09-08 12:40

Scope judged: `spec.md` §I.1 rows 1, 2 and 3 — in §III.2 terms, steps 2, 4, 5,
6, 10, 11, 12 and 13. Steps 1, 3, 7, 8 and 9, all of §IV, and the
`from_svydesign()` roxygen rewrite belong to PRs 2 to 5 and are not scored
here.

Tree reviewed: `4d19b55c841d731f4fe902c38ca0dc8e98df66ad`. This equals the tree
`audit.md` names, verified with `git rev-parse 'HEAD^{tree}'`. The branch
commit is `15434a7`, parent `c21f9a5`.

## Convergence checks

- Spec coverage: **y**. Every in-scope step has an `audit.md` row. Step 4 —
  I-3 (compressed) and I-4 (uncompressed) with their storage-form
  preconditions. Step 5 — I-5. Step 6 — I-8 and I-9 for the generated branch,
  I-3 for the pass-through branch, because `test-spec.md` §5 measures cell C as
  named. Step 10 — I-10 and I-21. Step 11 — I-5, I-6. Step 12 — I-5, I-11.
  Step 13 — the `test_invariants()` row.
- Test coverage of spec: **y**. The ten rows `implementation-plan.md` §Test row
  allocation gives PR 1 (I-3, I-4, I-5 to I-11, I-21) are exactly the ten rows
  `audit.md` §Scope declares in scope. No in-scope spec step lacks a row.
- Tolerance integrity: **y**. See below.
- Scope discipline: **y**. See below.
- Regression safety: **y**. `FAIL 0` before and after, `WARN 256` before and
  after, `SKIP 4` before and after. See the baseline note below.
- Comprehension alignment: **y**. Each of the ten gotchas in
  `comprehension.md` either lands in this diff (unnamed columns on both
  `compress` values; `repweights_compressed` is a list; `as.matrix()` dispatch
  under `requireNamespace()`; `as.matrix()` returns a classed object, so
  `unclass()` is required; mechanism 1 raises nothing at conversion), carries a
  `test-spec.md` row in a later pull request (zero replicate weights — I-15,
  I-16; generated names can collide — C-4, C-5; the factor form — I-1, I-2,
  I-13; the FPC — E-3 to E-7), or is a rule the tests obey (no row asserts a
  direction or a ratio for mechanism 2 — checked against every added block).
  All four assumptions appear in `spec.md` §III.2 step 9, §III.4 and §III.6.
- `audit.md` verdict: PASS.

## Tolerance integrity

`test-spec.md` §4 sets point `1e-10`, standard error `1e-8`, confidence bounds
`1e-6`, matrix comparison `1e-12`. Every numerical row in `audit.md` reports
the matching figure.

| Row | Audit tolerance | Test-spec | Verdict |
|---|---|---|---|
| I-3 point, I-4 point, I-21 point | 1e-10 | 1e-10 | equal |
| I-3 SE, I-4 SE, I-21 SE | 1e-8 | 1e-8 | equal |
| Structural rows | `identical` / n/a | `expect_identical()` | equal |

No row is looser. No confidence-bound row appears, and none should:
`test-spec.md` §6.1 gives the bound comparison to I-1 alone, which lands in
PR 2. The committed blocks run **tighter** than required in three places —
`tolerance = 0` on the stored-column comparisons in R-4, R-9 and R-10, where §4
permits `1e-12`. Noted, not a finding.

Independent corroboration: gate 2 reports `FAIL 0` with the committed R-1 and
R-2 blocks in the suite, and those blocks assert the same parity at the same
two tolerances as the audit's I-3 and I-4 rows.

## Scope discipline

`git diff --name-only c21f9a5 HEAD` returns exactly two paths:
`R/methods-conversion.R`, `tests/testthat/test-conversion.R`. That is
`implementation-plan.md` PR 1 §Files touched, with nothing added and nothing
missing. No `man/`, no `NAMESPACE`, no `NEWS.md`, no
`plans/error-messages.md`, no `tests/testthat/_snaps/conversion.md`.

The R diff adds 54 lines and nothing outside PR 1's scope. Grepping every added
line for `cli_abort`, `cli_warn`, `pweights` arithmetic, `nrow`, `is.na`,
`nzchar`, `unique`, `%in%`, `x$type`, `fpc` and `rho` returns comment text
only. The four deferred guards, the fold-in and the export route are all
absent, as they must be.

`tests/testthat/test-conversion.R` carries one hunk, `@@ -1122,3 +1122,298 @@`,
pure addition. No pre-existing block is edited or deleted.

**Step 10 before step 11 — verified in the merged source.**
`R/methods-conversion.R` calls `.find_col_by_value(data, x$pweights)` at line
488 and runs the `for (j in seq_len(n_rep))` write loop at line 500. The base
weight search therefore never sees the replicate block, which is what
`spec.md` §III.2 step 10 requires. R-10 pins it: a design whose first
replicate equals the base weights exactly, with no weight column in the data,
gives `@variables$weights` the value `"..surveycore_wt.."`.

**The unconditional write — verified.** The loop has no `if`, no
`%in% names(data)` test and no condition, so the route writes every replicate
column on every conversion. This is `spec.md` §III.2 step 11 as written.

`names_generated` is assigned and not yet read. `spec.md` §III.2 step 6 and
plan task 11 both require the branch to be recorded, and PR 3's collision
check consumes it. This is a deliberate forward reference, not dead code left
by accident.

## Coverage

| Measure | Value | Floor | Verdict |
|---|---|---|---|
| Package | 96.20% | 95% | PASS |
| `R/methods-conversion.R` | 99.18% | — | — |
| `# nocov` added | none | none | PASS |

I recounted the added line numbers from the diff on my own: 440–456, 461–479,
481–484, 486–489, 496–505. `gate-7-covr.log` reports exactly two uncovered
lines in the file, 138 and 305. Neither falls in any added range, and both are
pre-existing:

- line 138 — the `"fraction"` else-arm of the `fpctype` default in
  `.as_svydesign_replicate()`, on the export route this pull request does not
  touch;
- line 305 — the early `return(NULL)` in `.find_col_by_value()`, which already
  carries a `# nocov` rationale on the following line.

So every line PR 1 added is reached. There is no coverage regression in new
code.

## Profile gates

Every gate in `r-package-profile.md` has a result and none is skipped. pkgdown
ran, which the profile requires because the write surface touches `R/`. I read
the figures back out of the logs and matched them to `audit.md`.

| Gate | Log evidence |
|---|---|
| `document()` | no `NAMESPACE` or `man/` drift; `git status` on the worktree confirms it on its own |
| `test()` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11209 ]` |
| `run_examples()` | 0 occurrences of `^Error` or `^Execution halted` |
| `R CMD build` | tarball produced |
| `R CMD check --as-cran` | `Status: 2 NOTEs` — `checking CRAN incoming feasibility` and `checking for hidden files and directories`, both in the baseline; 0 ERROR, 0 WARNING, no third NOTE |
| pkgdown | site finished, no errored page |
| covr | `COVERAGE_PCT=96.20`, `UNCOVERED_COUNT=2` |

CRAN cookbook: `audit.md` reports None and the audit verdict is PASS. I
rescanned the 54 added R lines against all nine patterns — zero hits, and no
`@importFrom` in the file. Consistent.

`SKIP 4` is unchanged from the baseline, so no test was skipped to reach a
pass. The `skip_if_not_installed("survey")` guard on every new block is the
`testing-surveycore.md` house rule, and `survey` is installed on the gate
machine.

## Cross-consistency notes

`implementation.md` and `audit.md` agree everywhere I could test them.

- Test count. `implementation.md` reports `PASS 10982` on the pre-rebase base
  `df3a481`; `audit.md` reports 11209 on the shipping tree and gives the extra
  227 to commit `74c0913` (#238). `git log df3a481..c21f9a5` confirms #238 sits
  between the two bases, and 10982 + 227 = 11209. The two accounts reconcile
  exactly.
- Coverage. 96.19% against 96.20%, from those same two bases, with the same
  99.18% file figure and the same conclusion that the uncovered lines are
  pre-existing.
- Every structural claim in `implementation.md` reads true against the merged
  source: the helper above its only call site, the `@noRd` tag, the
  `unclass()`, the single name-resolution branch, the step order, the
  unconditional write, `repweights = rep_cols` with no other key changed, and
  metadata and construction untouched.

Four process facts, recorded rather than flagged.

1. **`implementation.md` is a reconstruction (D13).** I weighed it as the
   dispatch directs: the diff is the ground truth. Every claim in the document
   that the diff can test, the diff confirms. It is weaker evidence of intent
   than a contemporaneous account, and no conclusion in this review rests on
   intent alone.
2. **The gates were run by the orchestrator, not the tester (D12).** This
   departs from `tester.md` Step 1 and I record it here. It is not an
   integrity violation: all seven gates ran, one at a time in the foreground,
   on tree `4d19b55`, and the surviving log set is self-consistent with the
   figures in `audit.md`. Nothing was skipped or waived.
3. **Gate 2's warning arm reads as "no new warning" (D12).** Clean `develop`
   carries 256, the shipping tree carries 256, and `run-gates.sh` scores the
   gate on the `FAIL` count. The gate as literally written in `spec.md` §VII
   and `test-spec.md` §12 cannot be met, and D12 records the user's reading.
4. **Test-spec row IDs were stripped from the builder's task list (D11).** The
   committed blocks are named R-1 to R-10, not I-3 to I-21, and no acceptance
   criterion that counts blocks is literally checkable. I judged behaviour
   instead, per D11 and the dispatch.

Two thin spots in the **committed** suite, both on behaviour this pull request
does not change, and both measured directly by the tester on the merged tree.
Neither is a finding against PR 1. Both are worth naming in PR 2's builder
dispatch so a permanent guard lands.

- I-11 — `@variables$fpc` is `NULL` and `@variables$fpctype` is `"fraction"`
  after a replicate import. `audit.md` measured both. No committed block
  asserts either, and no pre-existing block covers the replicate import case:
  the one at line 809 asserts the pair on a Taylor round trip. `spec.md` §III.3
  marks both keys Unchanged.
- I-21's oracle parity. R-10 asserts the manufactured weight column and its
  values but no parity against `survey`. `audit.md` measured point and standard
  error parity for the row, and R-1 and R-2 carry parity on the same route, so
  the property is not unguarded.

I-10 is covered indirectly and well enough: R-4's
`expect_identical(ncol(d@data), ncol(df) + ncol(rep_mat))` fails if the route
manufactures a weight column instead of matching the existing `wt`.

Two shipping notes, neither a defect in the change.

- `origin/develop` has moved to `2f3f4c4` since the gates ran, one commit past
  the `c21f9a5` base. The branch needs a rebase before it opens, and
  `git diff origin/develop` currently reports two `.claude/skills/` pipeline
  documents that belong to that commit, not to this pull request. Against the
  base the gates used, the write surface is the two files above.
- `R/methods-conversion.R` lines 444 and 445 run to 83 and 85 characters. Both
  are the `.repwt_col_names()` usage examples, copied word for word from
  `spec.md` §II.2. `air` does not reflow comments, so the gate's "no diff" is
  correct, and this is a cosmetic nit against the 80-column rule in
  `code-style.md`.

## Decision

All seven checks are clean. The two behaviours PR 1 exists to fix are in the
merged source and correct: the route expands `x$repweights` through
`unclass(as.matrix())` and writes one column per replicate unconditionally,
with the base weight search ahead of the write, so `@variables$repweights`
names columns that hold the replicate weights. No tolerance was relaxed, no
guard or fold-in or export change landed early, coverage rose and every added
line is reached, and no test outside PR 1's scope changed state. PASS.
