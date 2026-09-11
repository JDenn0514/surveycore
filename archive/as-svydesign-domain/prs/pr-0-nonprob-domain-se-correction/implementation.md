# Implementation — PR 0 — nonprob-domain-se-correction
> Citations of `plans/*-as-svydesign-domain.md` below carry `[no such file]`: those four files were moved into `archive/as-svydesign-domain/` at archive time (2026-09-11), so the path they name no longer exists. The documents are beside this one.

## Write surface

- `R/analysis-means-helpers.R` — modified (one term plus its comment, inside `.calibrated_mean_cell()`)
- `tests/testthat/test-analysis-means.R` — modified (five new blocks, appended as Category 19)

Nothing else changed. `git status --porcelain` after `devtools::document()` lists
only these two files. `NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION` and
`plans/error-messages.md` are byte-identical to `develop`.

## Summary

- `.calibrated_mean_cell()` now takes its `n/(n - 1)` finite correction from
  `nrow(design@data)`, the full sample, in place of the domain row count. This
  is the one-term change that arrived applied; I measured it and kept it.
- The premise is **confirmed**, not refuted. `survey` 4.5 agrees with the
  full-sample factor to machine epsilon at every domain size I tried, and
  disagrees with the domain factor by up to 40% at a domain of 2 of 100 rows.
  Every absolute difference in the table below is at or below 4.5e-16, which is
  7 orders of magnitude inside the 1e-8 SE tolerance.
- Five new oracle blocks pin the behaviour: parity across five domain sizes,
  parity per group on a grouped call, parity with `NA` outcomes, parity on the
  full sample with no domain, and one block that computes the domain-factor SE
  by hand and asserts it does **not** match `survey`. That last block is the
  regression guard — it fails if anyone re-bases the factor on the domain.
- The `NA` count question resolves in favour of the shipped code. `survey`
  counts every row of the design in `n`, including rows that `na.rm = TRUE`
  drops from the estimate. Detail under §The NA finding.
- One-row domains are a separate open question. `survey::svymean()` returns a
  finite `0` where `.calibrated_mean_cell()` returns `NA_real_`. I did not
  change it. See §Signals raised.

## Parity measurements

Oracle: `survey` 4.5, `svymean(~y1, subset(svydesign(ids = ~1, weights = ~wt, data = df), dom))`.
`subset()` is the correct oracle shape, not a rebuilt design on the filtered
rows — `subset()` keeps each retained row's recorded stratum sample size, which
is exactly the property the fix relies on.

Data: `make_survey_data()` at the seeds the test blocks use. The "pre-fix SE"
column is the domain-factor value, computed in closed form from the same rows.

| Case | surveycore SE | survey SE | abs diff | pre-fix SE (domain factor) |
|---|---|---|---|---|
| domain 50 of 100 (seed 701) | 1.552416211029 | 1.552416211029 | 2.220e-16 | 1.560316599003 |
| domain 20 of 100 (seed 701) | 2.674043291912 | 2.674043291912 | 0.000e+00 | 2.729758510960 |
| domain 10 of 100 (seed 701) | 2.997866455176 | 2.997866455176 | 4.441e-16 | 3.144188863821 |
| domain 5 of 100 (seed 701) | 3.591948311088 | 3.591948311088 | 4.441e-16 | 3.995790244562 |
| domain 2 of 100 (seed 701) | 2.775095188510 | 2.775095188510 | 0.000e+00 | 3.904905062159 |
| group a, n = 90 of 150 (seed 703) | 1.062841700851 | 1.062841700851 | 2.220e-16 | 1.065227431576 |
| group b, n = 50 of 150 (seed 703) | 1.569936986967 | 1.569936986967 | 2.220e-16 | 1.580580749452 |
| group c, n = 10 of 150 (seed 703) | 2.781060842550 | 2.781060842550 | 4.441e-16 | 2.921707532305 |
| NA outcome, domain 30, n = 25 (seed 704) | 2.229214622028 | 2.229214622028 | 4.441e-16 | 2.263778150191 |
| full sample, no domain (seed 705) | 0.970061315665 | 0.970061315665 | 1.110e-16 | 0.970061315665 |

Point estimates matched at 1e-10 or better in every row; the largest mean
difference I saw was 2.8e-17.

The error the fix removes grows as the domain shrinks. On the seed-701 rows the
pre-fix SE was 0.51% high at a domain of 50, 2.1% at 20, 4.9% at 10, 11.2% at 5
and 40.7% at 2. On the full sample the two factors coincide and the pre-fix
value is bit-identical to the post-fix value — the last row of the table shows
that, and it is why the defect stayed invisible until a domain was involved.

An independent 40-row check on a hand-built frame gave the same result: the
full-sample factor reproduced `survey` at domain sizes 40, 20, 10, 5, 3 and 2,
and the domain factor reproduced none of them below 40.

## The NA finding

The brief asked whether the full-sample count should include the `NA` rows. It
should. `survey` counts them.

Measured on a 40-row frame with 5 `NA` outcomes and a domain of 20 rows (4 of
them `NA`), against `svymean(..., na.rm = TRUE)` on the subset design:

| Count used in the factor | SE | Matches survey |
|---|---|---|
| 40 — all rows | 0.2433998 | yes, exactly |
| 35 — non-`NA` rows | 0.2438469 | no |
| 20 — domain rows, `NA` included | 0.2465817 | no |
| 16 — domain rows, `NA` excluded | 0.2482201 | no |

`survey`'s SE was 0.2433998. So the count is the design's full row count, and
`nrow(design@data)` in the shipped code is right without further filtering.
`na.rm` affects only the domain, through `.mean_domain_vec()`, which zeroes the
influence of an `NA` row. The reported `n` stays the count of complete domain
rows — 25 of 30 in the seed-704 case — and the test asserts that separately.

## Task checklist

- [x] Confirm the branch and read the applied diff
- [x] Measure the fix against `survey` independently, before writing any test
- [x] Establish the correct oracle shape (`subset()`, not a rebuilt design)
- [x] Block 1 — parity across domain sizes 50, 20, 10, 5, 2
- [x] Block 2 — regression guard: the domain factor must fail parity
- [x] Block 3 — parity per group on `get_means(d, y1, group = g)`
- [x] Block 4 — parity with `NA` outcomes, and the `NA` count question answered
- [x] Block 5 — no-change guard on the full sample with no domain
- [x] Investigate the one-row domain against `survey` and report
- [x] `devtools::test(filter = "analysis-means")` — 0 failures
- [x] Downstream callers of `.mean_cell()` re-run — 0 failures
- [x] `devtools::document()` writes nothing
- [x] `air format --check` clean on both changed files

## Signals raised

### HOLD — builder — 2026-09-10 14:30

**Where**: `R/analysis-means-helpers.R`, `.calibrated_mean_cell()`, the
`n_d == 1L` early return; pinned by the existing block in
`tests/testthat/test-analysis-means.R` named "get_means() calibrated
single-row domain returns mean with NA se (covers n_d=1 path)".

**What**: `.calibrated_mean_cell()` returns `se = NA_real_` for a one-row
domain, where `survey::svymean()` returns a finite `0`. Which of the two is
surveycore's contract?

**Why I can't decide**: There is no spec for this PR, and the brief scopes the
one-row domain out. An existing test asserts the `NA`, so changing it is a
behavioural change to a pinned contract, not a fix to this PR's defect.

**Measured** (seed 706, 100 rows, domain of row 1 only):

| Source | mean | se |
|---|---|---|
| surveycore | 56.974548387242 | `NA` |
| `survey` 4.5 | 56.974548387242 | `0` |

The means agree. `survey`'s `0` is exact, not small: with one row `ybar` equals
`y_1`, so the single influence value `w_1 * (y_1 - ybar) / N_hat` is exactly
zero and the sum of squares is zero. The full-sample factor is finite and
multiplies zero, so `survey` reports zero. The domain factor was `1/0`, which is
why the early return existed before the fix — under the old code a one-row
domain had no computable variance at all. Under the new code it does, and the
computable value is `0`.

**Options**:

1. Keep `NA_real_`. A single observation carries no information about spread, so
   `0` is a degenerate artifact of the linearization, and reporting it as a
   standard error invites a reader to treat the estimate as certain. Costs
   parity with `survey` on this one cell.
2. Return `0` to match `survey`. Gains exact parity and removes a special case
   from the function, at the price of publishing a zero SE.
3. Keep `NA_real_` and warn. Parity is still lost; this adds a warning class,
   which this PR's write surface forbids.

**What I need**: A decision on whether a one-row calibrated domain reports
`NA_real_` or `0` for `se`, as its own change with its own test update.

## Notes for tester

- The new blocks mark the domain by assigning `SURVEYCORE_DOMAIN_COL` directly
  on `@data`. That is the pattern the neighbouring blocks in this file already
  use, and `.apply_domain()` reads nothing else. I first tried `dplyr::filter()`
  and it does not dispatch under `devtools::load_all()` in a bare `Rscript` —
  the S7 method registration for the dplyr generic is not in place at that
  point. It works inside `devtools::test()`; the direct assignment keeps the
  blocks independent of that.
- The blocks call `suppressWarnings()` around `get_means()`. A `survey_nonprob`
  design with no replicate weights always raises
  `surveycore_warning_nonprob_srs_fallback`, and the small domains also raise
  the pre-existing AAPOR small-cell warning. Both are covered elsewhere; these
  blocks assert numbers. The new blocks add 0 warnings to the file's run.
- `devtools::test(filter = "analysis-means")` goes from 301 to 330 passing
  expectations, 0 failures. The file's 20 warnings all come from pre-existing
  blocks above line 1271.
- `.mean_cell()` has two callers, `R/analysis-means.R:227` and
  `R/analysis-quantiles-helpers.R:190`. I re-ran `analysis-quantiles`,
  `analysis-diffs`, `analysis-t-test`, `effective-n`, `nonprob-bootstrap`,
  `variance-twophase-nonprob` and `analysis-helpers` together: 1527 passing,
  0 failures. I did not run the full suite, per the gate restriction in the
  brief.
- The comment claim that `.taylor_mean_cell()` agrees checks out. That function
  also reads `n_full <- nrow(data)` and builds a full-length influence vector.
- The HOLD above is recorded here only. The PR's write surface is closed to two
  files, so I did not write to `plans/decisions-as-svydesign-domain.md` [no such file]. Someone
  with that file in scope should transcribe it.

## CRAN compliance

- [x] TRUE/FALSE used throughout — no `T`/`F` in either file
- [x] `::` used for external calls — `survey::`, `surveycore::`
- [x] No bare `print()`/`cat()`
- [x] No randomness added to `R/`; test data comes from `make_survey_data(seed = )`
- [x] No `par()`, `options()` or `setwd()` touched
- [x] No file I/O
- [x] `devtools::document()` run; it wrote nothing
- [x] `air format --check` passes on both changed files
