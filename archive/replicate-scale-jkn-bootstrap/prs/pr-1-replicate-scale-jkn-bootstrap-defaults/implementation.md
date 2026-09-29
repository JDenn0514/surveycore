# Implementation — PR 1 — replicate-scale-jkn-bootstrap-defaults

**Branch**: `fix/replicate-scale-jkn-bootstrap-defaults`
**Base**: `fd621a1` (tree `915316c9`), verified before any edit
**Date**: 2026-09-28, revised 2026-09-29 after the HOLD was resolved

## Write surface

Six files. Four were in the original surface; the last two were added when
the user resolved this PR's HOLD with option A.

- `R/core-constructors.R` — modified
- `man/as_survey_replicate.Rd` — modified (regenerated, never hand-edited)
- `tests/testthat/test-variance-replicate.R` — modified
- `tests/testthat/test-constructors.R` — modified
- `tests/testthat/test-nonprob-bootstrap-variance.R` — modified (added by the
  HOLD resolution)
- `tests/testthat/test-analysis-corr.R` — modified (added by the HOLD
  resolution)

No other file changed. No file under `tests/testthat/_snaps/` changed:
`devtools::document()` and the first test runs left 30 snapshot files dirty
with line-ending rewrites, and all 30 were reverted with `git checkout --`.
The final full-suite run left none dirty.

## Summary

- `R/core-constructors.R:807` now reads `JKn = 1,` and `:813` now reads
  `bootstrap = 1 / (n_rep - 1L),`. Both sit inside the existing
  `if (is.null(scale))` branch, so an explicit `scale` is still stored
  verbatim. No branch was added and no validator was touched.
- Each changed switch line carries a short comment in the style of the `JK2`
  comment above it — four facts for JKn, three for the bootstrap, both
  pointers to `@param scale` rather than derivations.
- `@param scale` was rewritten to carry F-1 to F-8, keeping the JK2 sentences
  PR #258 added. `@param rscales` gained RS-1's cross-reference and
  `@param fpc` gained FP-1's clause. The old `fpc` sentence "Used by some
  replicate methods to adjust the variance estimator" was removed, because
  FP-1 contradicts it.
- The two oracle blocks in `tests/testthat/test-variance-replicate.R` lost
  eight lines: three `expect_failure()` wrappers and one closing ratio
  assertion per block. The six assertions the wrappers held now run
  unwrapped. Both titles moved from "disagrees with" to "matches".
- Three blocks that asserted the old numbers were retargeted: the stored
  bootstrap default in `test-constructors.R`, and the two cross-constructor
  blocks that the HOLD identified.

## Task checklist

- [x] 1. Cut the branch from the verified base; run the full suite and record
  the baseline: `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12005 ]`, matching the
  orchestrator's figure exactly.
- [x] 2. Change `:807` to `JKn = 1,` and `:813` to
  `bootstrap = 1 / (n_rep - 1L),`.
- [x] 3. Re-run and read the red set. The red set was **eleven**, not nine.
  Reported as a HOLD; see §The HOLD and its resolution.
- [x] 4. Delete the six `expect_failure()` wrappers and the two closing ratio
  assertions — eight lines, four per block.
- [x] 5. Correct both block titles and both opening comments.
- [x] 6. Retarget `tests/testthat/test-constructors.R:676-692` to
  `1 / (n_rep - 1)`, title included.
- [x] 7. Run the full suite and reconcile the pass count. See §Measurements.
- [x] 8. Add one comment above each changed switch line.
- [x] 9. Rewrite `@param scale` to carry F-1 to F-8.
- [x] 10. Add RS-1 to `@param rscales` and FP-1 to `@param fpc`.
- [x] 11. Run `devtools::document()`; commit the regenerated
  `man/as_survey_replicate.Rd` with the roxygen change.
  `man/as_survey_nonprob.Rd` did not change, which is correct — D1's note is
  PR 4's work.
- [x] 12. Read the rendered help page against acceptance criterion 6. See
  §Criterion 6.
- [x] 13. Run the gates that are mine. See §Gates.
- [x] 14. **(added by the HOLD resolution)** Retarget the two
  cross-constructor blocks, measuring before choosing each assertion. See
  §The two retargeted blocks.
- [x] 15. **(added by the HOLD resolution)** Mutation-check the three new
  assertions. See §Mutation check.

## Measurements

| Run | Result |
|---|---|
| Step 1 baseline, `devtools::test()` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12005 ]` |
| Step 7, before the HOLD was resolved | `[ FAIL 2 \| WARN 256 \| SKIP 4 \| PASS 12001 ]` |
| Final, `devtools::test()` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12004 ]` |

Warnings held at 256 throughout, so the change raises no warning the
baseline did not already raise.

The final pass count reconciles exactly. 12005 − 12004 = 1 net pass lost:

| Change | Net passes |
|---|---|
| Two deleted closing ratio assertions | −2 |
| Six `expect_failure()` wrappers replaced by six unwrapped assertions | 0 |
| `test-constructors.R` stored default retargeted | 0 |
| `test-nonprob-bootstrap-variance.R` — SE identity became the SE ratio; the mean identity stayed | 0 |
| `test-analysis-corr.R` — the `ci_low` equality became two assertions, and the `r` equality stayed | +1 |
| **Total** | **−1** |

Each `expect_failure()` wrapper counted as one expectation, and each
unwrapped assertion that replaced it counts as one, so those six are net
zero.

Full-suite budget: three runs, at steps 1, 7 and the end, which is the two
allowed plus the one the coordinator granted for the HOLD fix. Every other
run was filtered. The step 3 filter covered every test file naming `JKn` or
`bootstrap`, found with a case-insensitive `grep -ril` over
`tests/testthat/`, plus every `variance`, `invariants` and `update-design`
file. `testthat::set_max_fails(Inf)` was set on every verification run: the
default cap hid one assertion on the first step 3 run.

## The HOLD and its resolution

Step 3's red set was eleven, not the nine the plan predicted. Two blocks
outside the then-current write surface asserted that `as_survey_nonprob()`
and `as_survey_replicate()` agree numerically on a bootstrap design — the
identity `spec.md` quality gate 6 and decision D1 deliberately break. They
were reported, not fixed.

The user resolved the HOLD with option A: widen the write surface by the two
files and retarget both blocks here. Three errata are now settled in
`decisions.md`, and the operative parts are that `spec.md` §Test-file write
surface's "exactly one block" is scoped to *stored defaults* — three blocks
break in total, one stored-default and two derived-number — and that
`test-spec.md` row 4.5's closed file list becomes four files. The rest of
row 4.5 stands: no file under `tests/testthat/_snaps/` may change, and none
did.

## The two retargeted blocks

Both were measured before an assertion was chosen. Neither was deleted.

### `test-nonprob-bootstrap-variance.R` — the `get_means()` block

The SE identity became the SE ratio, as instructed. The mean identity stayed
as `expect_identical()`, because the scale enters the variance only.

- Measured at `R = 20`: `result_np$se / result_rep$se` is
  `0.97467943448089656` against `sqrt(19 / 20) = 0.97467943448089633`, a
  deviation of `2.2e-16`. Asserted at `1e-8`.
- Stored scales measured directly: `0.05` on the nonprob side and
  `0.052631578947368418` on the replicate side.
- The title moved from "SE is bitwise identical for survey_nonprob and
  survey_replicate with same data" to "get_means() nonprob SE is
  sqrt((R-1)/R) of the replicate SE". A comment names decision D1 as the
  reason the two diverge, so a later reader does not file it as a defect.
- Two comments outside the block said the same false thing and were
  corrected: the file header bullet "Bitwise identity with survey_replicate
  using same data", and the "Section 4" header. Both now say the point
  estimate is bitwise identical and the SE differs by the stored scale.

This is the same assertion PR 4's AC-4 makes, deliberately, so the two agree.

### `test-analysis-corr.R` — the polychoric block

**Option 1 fails and option 2 was used, with one measured addition.**

The `r` equality stayed at `1e-10`; measured `r` is bitwise identical on both
sides, difference exactly `0`.

Option 1, the half-width ratio taken in `r`, does **not** hold. Measured at
`R = 10`: `(r - ci_low_np) / (r - ci_low_rep)` is `0.94876099393154079`
against a target of `0.94868329805051377`, out by `7.8e-05` — five orders
of magnitude outside `1e-8`. The cause is that the interval is not symmetric
in `r`: the lower and upper half-widths differ by `2.8e-05` on the nonprob
side and `3.1e-05` on the replicate side.

So the fallback was used: `expect_gt(ci_low_np, ci_low_rep)`. Measured
`-0.1585654406848242` against `-0.15907885101534536`, so the smaller nonprob
SE does give the higher lower bound. This holds whatever the sign of `r`,
and `r` is negative on this fixture.

One further assertion was added, because measurement showed an exact
relation was available and a direction test alone does not pin a magnitude.
The bound is built on Fisher's z, which is symmetric in z and not in `r`.
Taken in z the ratio is exact: measured `0.94868329805051332` against
`sqrt(9 / 10) = 0.94868329805051377`, a deviation of `4.4e-16`, and the
lower and upper half-widths in z agree to exactly `0` on both sides.
Asserted at `1e-8`. The comment above it records the measurement and why the
ratio in `r` misses.

The title moved from "survey_nonprob with repweights matches
survey_replicate numerically" — now true of `r` only — to "get_corr()
polychoric nonprob r matches replicate, CI narrower".

`test-nonprob-bootstrap-variance.R:183`, the `get_ratios()` block that
compares `NULL` to `NULL`, was left exactly as it is. It is issue #292 and
out of scope.

## Mutation check

The three new assertions were written against behaviour this PR already
shipped, so each was shown able to fail. `R/core-constructors.R:813` was
edited back to `bootstrap = 1 / n_rep,` and the two files re-run.

| Assertion | Under the mutation |
|---|---|
| `test-analysis-corr.R:1737` — `expect_gt` on `ci_low` | red |
| `test-analysis-corr.R:1745` — the Fisher-z ratio | red |
| `test-nonprob-bootstrap-variance.R:171` — the SE ratio | red |

`[ FAIL 3 | WARN 14 | SKIP 0 | PASS 937 ]` under the mutation against
`[ FAIL 0 | WARN 14 | SKIP 0 | PASS 940 ]` without it. The two
point-estimate assertions stayed green under the mutation, which is the
expected signature of a scale change.

The mutation was reverted with `sed`, which rewrote the file with LF line
endings. `git diff` reported no content change, but the file was restored
with `git checkout -- R/core-constructors.R` to put the CRLF endings back.
`R/` is byte-identical to the commit.

## Criterion 6 — the rendered help page

Read from the regenerated `man/as_survey_replicate.Rd`. All ten items land.

| Fact | Where it lands |
|---|---|
| F-1 | Opening list: `1` for `"JKn"`, `"JK2"` and `"other"` |
| F-2 | Bootstrap paragraph: `1/(R-1)`, named as `survey::svrepdesign()`'s value at `bootstrap.average = 1` |
| F-3 (3 clauses) | JKn paragraph: factor belongs in `rscales`; factor is `(n_h - 1) / n_h` under with-replacement or negligible fraction; `rscales = NULL` leaves no jackknife factor |
| F-4 | Bootstrap paragraph: one replicate column gives `scale = Inf`, and `survey::svrepdesign()` stores `Inf` too |
| F-5 (2 elements) | Bootstrap paragraph: no `bootstrap.average` argument, so the default is always `1/(R-1)`; an imported `survey` design keeps its effective scale exactly, in both directions |
| F-6 | Closing paragraph: `scale = (R - 1) / R` for JKn, `scale = 1 / R` for bootstrap |
| F-7 (3 elements) | Without-replacement paragraph: entry `(n_h - 1) * (1 - n_h / N_h) / n_h`; symbol key for `n_h` and `N_h`; provenance — the caller supplies `N_h` from their own frame, `rscales` is the only route, `fpc` reaches the factor for no replicate type |
| F-8 (3 elements) | Divergence paragraph: names `as_survey_nonprob()`, its value `1/R`, and that the difference is a decision and not a defect, with the pointer to that page. **No percentage**, as the criterion requires |
| RS-1 | `\item{rscales}`: names the `scale` argument as the source of the entry to build. No formula, no symbol key |
| FP-1 | `\item{fpc}`: states the argument has no effect for a replicate design and sends the correction to `rscales`, with the pointer to `scale` |

## Gates

| Gate | Result |
|---|---|
| Full suite green | Pass — `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12004 ]` |
| No new warning | Pass — 256 in the baseline, 256 at the end |
| `devtools::document()` leaves nothing uncommitted under `man/` or in `NAMESPACE` | Pass. Only `man/as_survey_replicate.Rd` changed. `NAMESPACE` is unchanged |
| No file under `tests/testthat/_snaps/` changed | Pass |
| No added line over 80 columns | Pass across all six files; longest added line is 78 |
| `air format --check R/core-constructors.R` | Pass |
| `air format --check tests/testthat/test-variance-replicate.R` | Pass |
| `air format --check tests/testthat/test-analysis-corr.R` | Pass at file level |
| `air format --check tests/testthat/test-constructors.R` | **Fails, and fails identically at the base commit.** The call sites it wants to rewrap sit near base lines 1212, 2255 and 2271, none of which this PR touches. The 17-line block this PR edits passes on its own, longest line 79 |
| `air format --check tests/testthat/test-nonprob-bootstrap-variance.R` | **Fails, and fails identically at the base commit.** The 38-line block this PR edits passes on its own |
| `R CMD build`, `R CMD check`, `pkgdown`, `covr` | Not run. The orchestrator runs these in the foreground; this machine has about 1.9 GB free and concurrent heavy R runs corrupt each other's `.Rcheck` trees |

## Notes for tester

- `spec.md` §Edge cases E1 says a one-column bootstrap design stores `Inf`
  and raises nothing. The arithmetic reaches that value — `1 / (1L - 1L)` is
  `1 / 0L`, and R returns `Inf` — and no guard was written. The constructor
  has one `if (is.null(scale))` branch and no `else`, so nothing inspects
  the computed value before it is stored.
- The two switch lines keep integer arithmetic on the denominator.
  `n_rep - 1L` is an integer and `1 / <integer>` returns a double, so
  `@variables$scale` keeps the type it has today for every type.
- `man/as_survey_nonprob.Rd` is unchanged and that is correct. D1's note on
  that constructor is PR 4's roxygen edit.
- PR 4's AC-4 asserts the same nonprob-to-replicate SE ratio this PR now
  asserts in `test-nonprob-bootstrap-variance.R`. That duplication is
  deliberate per the HOLD resolution, but PR 4 should check whether it wants
  two copies of the assertion or one.
- The polychoric block's new z-space assertion reads the interval's
  construction: it will fail if `get_corr()` stops building the polychoric
  bound on Fisher's z, even with the scale correct. That is a real change
  worth catching, but the failure message will not say so. The comment above
  the assertion records the measurement that justifies it.
- The snapshot gap `spec.md` §Errors and warnings records as item 3 — no
  snapshot anywhere covers `as_survey_replicate()` raising
  `surveycore_error_weights_all_zero` — is still open and belongs to issue
  #291.
