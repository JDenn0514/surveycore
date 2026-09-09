# Review — PR 2 — svydesign-replicate-bridge (`fix/svydesign-replicate-foldin`)

**Verdict**: PASS
**Date**: 2026-09-08

Scope judged: `spec.md` §I.1 rows 6 and 12 — in §III.2 terms, step 9, plus the
documentation surface in §II.3. Steps 1, 3, 7 and 8, the four import guards,
belong to PR 3. All of §IV, the export route, belongs to PRs 4 and 5. Neither
is scored here.

Tree reviewed: `badc400c2ac71ae8bc94738da2bcf2f3182532a8`. This equals the tree
`audit.md` names, verified with `git rev-parse 'HEAD^{tree}'`. HEAD `2825855`,
parent `a7a52c0`, which is `origin/develop`.

## Convergence checks

- Spec coverage: **y**. Step 9 has committed blocks on both branches — R-11
  (oracle parity on a factor-form source: point 1e-10, SE 1e-8, both CI bounds
  1e-6), R-12 (the stored product, per column, per row), R-13 (a
  finished-weight source passes through unmultiplied). §III.4's pass-through
  values have R-14 (zeros on JK1 and JKn), R-15 (`NA`), R-16 (negative and
  zero), R-17 (`surveycore_error_weights_nonpositive`). §III.6's name cases
  have R-18 (survey's names on a factor-form source), R-19 (a shadowed data
  column), R-20 (one and two replicate widths). §III.3 has R-21, and §VI
  property 12 has R-23. `audit.md` carries a Per-Test row for every one.
- Test coverage of spec: **y**. The fifteen rows `implementation-plan.md`
  §Test row allocation gives PR 2 (I-1, I-2, I-12 to I-20, I-22 to I-24, I-26)
  are exactly the fifteen `audit.md` §Scope declares in scope. I-25 is
  `test-spec.md` §6.4's recorded non-reachable state; its absence is not a gap.
  Row IDs are not in the committed blocks (D11), so I judged the behaviour each
  in-scope row describes, not the block names.
- Tolerance integrity: **y**. See below.
- Scope discipline: **y**. See below.
- Regression safety: **y**. `FAIL 0` before and after, `WARN 256` before and
  after, `SKIP 4` before and after, `PASS 11209 → 11343`. No test outside this
  pull request's scope changed state, and no skip was added to reach a pass.
- Comprehension alignment: **y**. The two gotchas this pull request owns land
  in the diff: `as.svrepdesign()` always reports the factor form — R-3, R-11,
  R-12, R-15, R-16, R-18, R-19, R-22 and R-23 each assert
  `expect_false(isTRUE(sv$combined.weights))` on their source; zero replicate
  weights are legal — R-14 and R-16. The rule that no row may assert a
  direction, a ratio or a percentage for mechanism 2 holds across every added
  block: R-11 and R-22 assert parity against the oracle and nothing else, and
  R-12's and R-13's `expect_gt(diff(range(sv$pweights)), 1)` is a statement
  about the fixture's weight spread, not about the standard error. Both
  assumptions this step rests on are reflected in the code and pinned by a
  block: `x$pweights` is the base weight for every row (row-wise recycling,
  checked per row in R-15 and R-19), and the row order of `@data` matches the
  matrix (R-15 puts the `NA` in row 2 and finds it in row 2). The collision
  gotcha and the FPC gotcha are deferred to PRs 3 and 4 with rows in
  `test-spec.md`.
- `audit.md` verdict: PASS.

## The changed assertion in PR 1's block — judged independently

PR 1's R-4 (`test-conversion.R:1240`, "writes one double column per replicate
for an uncompressed source") built its source with
`survey::as.svrepdesign(type = "JKn", compress = FALSE)` and asserted the
stored column equalled the raw source column at `tolerance = 0`. This pull
request changed the expectation to
`as.numeric(rep_mat[, j]) * as.numeric(sv$pweights)` at `tolerance = 1e-12`.

**The new expectation is correct and the old one was the pre-fix value.** I
decided this from the source of truth, not from the audit. Measured in a
single `Rscript` call on the installed `survey`, on the same construction:

| Quantity | Value |
|---|---|
| `sv$combined.weights` | `FALSE` |
| `max(unclass(as.matrix(sv$repweights)))` | 1.25 — factor scale, not weight scale |
| `max(sv$pweights)` | 4.97 |
| `max(abs(weights(sv, type = "analysis") - m * sv$pweights))` | 0 |

`survey`'s own finished replicate weights for this design are the raw matrix
times `pweights`, exactly. `spec.md` §III.2 step 9 requires that product when
`isTRUE(x$combined.weights)` is `FALSE`, and §VI property 10 states the stored
column is "the corresponding column of the expanded source matrix, times the
base weight when the source reported replication factors". `test-spec.md` §6.1
row I-2 writes the same comparison for the same cell. So the old assertion
encoded the defect #197 exists to remove, and correcting it was required, not
optional. No weakening, no bending to fit the implementation.

The tolerance move from `0` to `1e-12` is not a relaxation below anything.
`test-spec.md` §4 sets `1e-12` for this comparison; PR 1 chose `0` voluntarily,
and PR 1's review recorded that as tighter than required. `1e-12` restores the
document's own figure, and the tester measured the difference at 0, so no
headroom is in use.

**It was the only pre-existing assertion touched.** `git diff origin/develop`
reports 466 insertions and 7 deletions in `tests/testthat/test-conversion.R`
across three hunks. The 7 deletions are 5 comment lines in R-3's header, which
said the fold-in "is not in this change" and now points at R-11, plus the 2
lines of that one `expect_equal()`. The third hunk, `@@ -1417,3 +1419,460 @@`,
is pure addition. No other line of the pre-existing 1419 changed.

## Tolerance integrity

`test-spec.md` §4: point `1e-10`, standard error `1e-8`, confidence bounds
`1e-6`, the fold-in matrix comparison `1e-12`, structural assertions
`expect_identical()`.

| Comparison | Audit | Committed blocks | Test-spec | Verdict |
|---|---|---|---|---|
| Point | 1e-10 | R-11, R-22 | 1e-10 | equal |
| Standard error | 1e-8 | R-11, R-22 | 1e-8 | equal |
| CI bounds | 1e-6 | R-11, R-22 | 1e-6 | equal |
| Stored column / matrix | 1e-12 | R-4, R-12, R-15, R-16, R-18, R-19, R-22 | 1e-12 | equal |
| Structure | `identical` | `expect_identical()` | `expect_identical()` | equal |

No row in `audit.md` is looser than `test-spec.md` at any point. Two committed
comparisons run tighter than required — R-13's pass-through check and R-19's
precondition, both at `tolerance = 0` where §4 permits `1e-12`. Noted, not a
finding.

## Scope discipline

`git diff --name-only origin/develop` returns exactly three paths:
`R/methods-conversion.R`, `man/from_svydesign.Rd`,
`tests/testthat/test-conversion.R`. That is `implementation-plan.md` PR 2
§Files touched, with nothing added and nothing missing. No `NAMESPACE`, no
`NEWS.md`, no `plans/error-messages.md`, and
`tests/testthat/_snaps/conversion.md` does not exist — checked with `ls`.
`R/core-classes.R`, `R/core-constructors.R` and `R/variance-replicate.R` are
absent from the diff, so gate 11 holds.

The R diff is three hunks. Two are roxygen. The third adds 25 lines, of which
exactly three are executable:

```r
if (!isTRUE(x$combined.weights)) {
  rep_mat <- rep_mat * x$pweights
}
```

Grepping every added line for `cli_abort`, `cli_warn`, `nzchar`, `unique(`,
`nrow(`, `x$type`, `fpc`, `rho` and `svrepdesign(` returns two hits, both
comment or roxygen prose naming `survey::as.svrepdesign()`. So no guard, no
condition and no export-route change arrived early, and no row was owed to
`plans/error-messages.md`.

**The fold-in matches step 9 and is silent.** `!isTRUE(x$combined.weights)` is
step 9's stated trigger. The product is row-wise: `rep_mat` is a plain matrix
by then, `unclass()`ed at step 4, and a length-`n` vector recycles down each
column, so `[i, r]` becomes `R[i, r] * p[i]`. Neither branch raises anything —
`spec.md` §V.8 and §V.9. `scale`, `rscales`, `mse` and `type` pass into the
`variables` list unchanged at `R/methods-conversion.R:555–559`; no compensating
change was made to any of them.

**The placement is right.** The fold-in sits at line 526, after name
resolution at 500–504 and before the base weight search at 535. Steps 7 and 8
are PR 3's, so nothing sits between. The ordering that carries a number —
step 10's search before step 11's write, at 535 and 547 — is unchanged from
PR 1, and R-22 now pins its numerical consequence.

## Documentation surface

`man/from_svydesign.Rd` is the only page under `man/` that differs from the
base. `\usage` and `\value` are byte-identical, so no `@param` was added and
`@return` did not change (§II.3, plan task 13).

`spec.md` §VII gate 12 holds. The `\description` no longer says the replicate
weights are preserved — it reads "The data and the design variables are
preserved" — and the new `\section{Replicate weights}` carries all three facts
§II.3 requires:

1. On a design that reports replication factors the conversion "transforms the
   replicate weights rather than preserving them: it multiplies each replicate
   column by the base weight".
2. When the source names no replicate column the conversion "writes a
   generated block into the data, one column per replicate", on the
   `..surveycore_wt..` pattern, with the index zero-padded to the width of the
   replicate count.
3. "the `repweights` design variable of the returned object names those
   columns, in replicate order."

The metadata sentence is kept, and the section states the pass-through case for
a named source as well.

## Coverage

| Measure | Value | Floor | Verdict |
|---|---|---|---|
| Package | 96.20% | 95% | PASS |
| vs. this pull request's baseline | 96.20% → 96.20% | no drop | PASS |
| `R/methods-conversion.R` | 99.19% | — | — |
| `# nocov` added | none | none | PASS |

I recomputed the added line ranges from the diff hunk headers on my own:
330–332, 340–359 and 506–530. `gate-7-covr.log` reports exactly two uncovered
lines in the file, 138 and 305, and neither falls in any added range. I read
both in the source: 138 is the `"fraction"` else-arm of the `fpctype` default
in `.as_svydesign_replicate()`, on the export route this pull request does not
touch, and 305 is the early `return(NULL)` in `.find_col_by_value()`, which
already carries a `# nocov` rationale. Both are pre-existing, and PR 1's review
found the same two. The three executable lines this pull request adds are all
reached, so there is no coverage regression in new code.

## Profile gates

Every gate has a result and none is skipped. pkgdown ran, which
`r-package-profile.md` requires because the write surface touches `R/`. I read
each figure back out of the logs in
`.surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/pr-2/`
and matched it to `audit.md`.

| Gate | Log evidence |
|---|---|
| `document()` | no `Writing` line in the log, and `git status` on the shipping tree is clean of tracked changes, so `NAMESPACE` and `man/` did not drift |
| `test()` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11343 ]` |
| `run_examples()` | 0 occurrences of `^Error` or `^Execution halted` |
| `R CMD build` | `surveycore_1.1.0.9000.tar.gz` produced |
| `R CMD check --as-cran` | `Status: 2 NOTEs` — `checking CRAN incoming feasibility` and `checking for hidden files and directories`, both in `baseline.md`; 0 ERROR, 0 WARNING, no third NOTE |
| pkgdown | site finished, no errored page |
| covr | `COVERAGE_PCT=96.20`, `UNCOVERED_COUNT=2` |

CRAN cookbook: `audit.md` reports None and the audit verdict is PASS. I
rescanned the three added executable lines and the 22 added comment and roxygen
lines against all nine patterns — zero hits, and no `@importFrom` in the file.
Consistent.

## Cross-consistency notes

`implementation.md` and `audit.md` agree everywhere the diff can test them.
The write surface, the `if (!isTRUE(...))` shape, the step order, the absence
of any compensating change, the three documented facts, the single changed
assertion and the comment-only second edit all read true against the merged
source. `implementation.md` reports `PASS 11343` on the full run and `audit.md`
reports the same figure from the gate log.

The two leftover notes from PR 1's review both landed.

- The `fpc` and `fpctype` keys on an imported replicate design now have a
  committed block. R-21 builds a Taylor design **with** `fpc = ~fpc`, converts
  through `as.svrepdesign(type = "JKn")`, and asserts `@variables$fpc` is
  `NULL`, `@variables$fpctype` is `"fraction"`, and both keys are present.
  That is `spec.md` §III.3 for the two keys PR 1 left measured but unguarded.
- Oracle parity where a replicate column holds exactly `x$pweights` now has a
  committed block. R-22 goes further than the note asked: its source is
  factor-form with `rep_mat[, 1] <- 1`, so replicate 1 equals the base weights
  only **after** the fold-in. One block therefore pins step 9 and the
  step-10-before-step-11 order together, with point, standard error and both
  confidence bounds against `survey`.

Five process facts, recorded rather than flagged.

1. **Test-spec row IDs were stripped from the builder's task list (D11).** The
   committed blocks are named R-11 to R-23, not I-1 to I-26, so no acceptance
   criterion that counts blocks or names a row identity is literally checkable.
   I judged behaviour instead, per D11 and the dispatch. The plan's "15 blocks"
   criterion reads 13 committed blocks; the count is advisory under D11 and the
   behaviour of all fifteen in-scope rows is covered.
2. **The gates were run by the leader, not the tester (D12, D16).** This
   departs from `tester.md` Step 1 and I record it. It is not an integrity
   violation: all seven ran, one at a time in the foreground, on the shipping
   tree, and the log set is self-consistent with `audit.md`. Nothing was
   skipped or waived.
3. **Gate 2 reads as "no new warning" (D12), and gate 9 as "this pull
   request's own files pass `air format --check`" (D16).** Clean `develop`
   carries 256 warnings, all the pre-existing AAPOR small-cell `cli_warn()`,
   and this tree reports 256. `air` is a CLI here, so `air::format_package()`
   cannot run, and 24 files repo-wide are already not air-clean. Both readings
   are the user's, recorded before this pull request was built.
4. **The branch was rebased after the audit's first pass and the gates were
   re-run (D15).** PR #240 landed on `develop` mid-audit. It touches
   `R/utils.R` (roxygen only), `man/survey_data.Rd` and a changelog file, none
   of which this pull request writes. `git diff --name-only origin/develop` now
   returns the three expected paths and nothing else, and the audit's tree hash
   matches the tree I reviewed.
5. **The leader committed the builder's work.** The builder left the three
   files unstaged; the leader extracted them as a patch and committed. The
   content in the diff is the builder's, and every claim in
   `implementation.md` that the diff can test, the diff confirms.

Two thin spots, neither a finding against this pull request. Both are worth
naming in a later builder dispatch.

- **Committed oracle parity is narrower than `test-spec.md` writes it.** Nine
  in-scope rows attach a point or standard-error comparison to a structural
  behaviour — I-2, I-13, I-14, I-15, I-16, I-17, I-18, I-23 and I-24 — and the
  committed blocks for those behaviours assert the structure and the stored
  values but not the parity. The tester measured every one on the merged tree
  and all agree, so the behaviour is validated; it is the committed regression
  guard that is thinner. `implementation.md` gives the reason: `get_means()` on
  a design with fewer than 30 rows in a cell raises the AAPOR small-cell
  warning, which would push the suite's warning count above D12's ceiling of
  256 and fail gate 2, so parity lives in two dedicated `n = 40L` blocks
  (R-11, R-22) rather than inside every structural block. The property is not
  unguarded: R-4 pins the stored values for the uncompressed factor path
  exactly, per column, and the replicate variance is a deterministic function
  of the stored columns and the pass-through keys, which R-11 pins against
  `survey`. A future parity block in this file should use `n = 40L` for the
  same reason.
- **R-11 does not assert its storage-form precondition.** `test-spec.md` §5
  asks each cell to assert its own preconditions first. R-11 asserts the
  factor form but not that the source is compressed or unnamed; R-3 asserts
  both on the identical construction. I checked the installed `survey` in a
  single `Rscript` call: `as.svrepdesign(type = "JKn")` and
  `as.svrepdesign(type = "JK1")` both return a `repweights_compressed` object
  with a length-0 `colnames()`, so R-11 is in fact cell A. Cosmetic.

One housekeeping note for the shipper: `git status` lists six untracked files
under `plans/`, five of them this run's planning documents and one
`plans/pr-budget-calibration.md`. None is in the diff and none is this pull
request's write surface. They belong to the archive step, not to this merge.

## Decision

All seven checks are clean. Step 9 is in the merged source as `spec.md` writes
it — three executable lines, the stated trigger, row-wise, silent on both
branches, no compensating change to `scale`, `rscales`, `mse` or `type`, and
placed after name resolution and before the base weight search. The one
pre-existing assertion this pull request changed had to change: I confirmed
against the installed `survey` that the design in question reports replication
factors and that its finished weights are the raw matrix times `pweights`
exactly, so the old `tolerance = 0` raw-matrix expectation encoded the defect
and the new one encodes the fix, at the tolerance `test-spec.md` §4 states. No
tolerance is looser than the test-spec anywhere, no guard or export change
arrived early, the write surface is the plan's three files, coverage held at
96.20% with every added line reached, `man/from_svydesign.Rd` no longer states
the false contract and carries all three required facts, and no test outside
this pull request's scope changed state. PASS.
