# Changelog: fix/nonprob-domain-se

**Branch:** `fix/nonprob-domain-se-correction`
**Status:** Complete
**Date:** 2026-09-10

## Summary

Refs #245. `get_means()` reported a standard error that was too large for any
domain of a `survey_nonprob` design that carries no replicate weights. The
error grew as the domain shrank: 0.51% on a domain of 50 rows out of 100, 4.9%
at 10 rows, and 40.7% at 2 rows. Point estimates were always correct.

`.calibrated_mean_cell()` computes a Horvitz-Thompson Taylor linearization,
`Var(ybar) = n/(n-1) * sum(z_i^2)`. It took that `n` from the domain row count.
The function's own comment states the factor as `n/(n-1)` and claims it matches
`survey::svydesign(ids = ~1)`, so the code contradicted its documented intent.
On the full sample the domain count and the sample count are the same number,
which is why every existing test passed and why the defect stayed invisible for
so long.

The correction now comes from `nrow()` of the stored data, the full sample.

### Why the full sample is the right count

Outside the domain the influence value `z_i` is zero, and the weighted
residuals inside the domain sum to zero, so the mean of `z` over the full
sample is zero. The sum of squares therefore runs over all `n` rows and equals
the sum over the domain rows alone: the `n - n_d` zeros contribute nothing to
the total but they are still terms in it. A sum over `n` terms takes the factor
`n/(n-1)`. Pairing it with the domain count was the inconsistency.

The `survey` package works the same way, and does so deliberately.
`survey:::onestrat` computes `nPSU/(nPSU - 1)` from `design$fpc$sampsize`, and
`[.survey.design2` subsets that field by row without recomputing it, so every
retained row still carries the full sample's count. `onestrat` then pads the
matrix back to `nPSU` rows with zeros. Thomas Lumley describes the design in
"Subsets and subpopulations in survey inference" (notstatschat, 2021-07-22):
the subset method "keeps track of how many sampling units it has discarded, and
the variance computations put the zeroes back in".

`.taylor_mean_cell()` already read the full sample count, so this change also
removes a disagreement between the two estimators inside surveycore.

### What did not change

`se_srs`, the SRS-equivalent standard error used for a design effect, still
uses the domain count. It is a different estimand and its count is correct.

A one-row domain still reports `se = NA_real_`, where `survey` reports an exact
`0`. Under the old factor the multiplier was `1/0` and no variance was
computable; under the new one the value is computable and it is zero. A single
observation carries no information about spread, so the zero is an artifact of
the linearization rather than a measurement, and reporting it as a standard
error would tell a reader the estimate is certain. The existing behaviour is
kept and tracked separately.

## Files Modified

- `R/analysis-means-helpers.R` — `.calibrated_mean_cell()` takes its finite
  correction from `nrow(data)` in place of the domain row count; the comment
  above it records which count and why
- `tests/testthat/test-analysis-means.R` — five oracle blocks: parity across
  five domain sizes, parity per group on a grouped call, parity with `NA`
  outcomes, parity on the full sample, and a negative control that computes the
  domain-count value by hand and asserts it does not match `survey`

## Changes

- Base the calibrated domain standard error on the full sample size, matching
  `survey::svymean()` and `.taylor_mean_cell()`
- Pin the behaviour with five oracle blocks against `survey`, including a
  negative control that fails if the factor is ever re-based on the domain

## Verification

Measured against `survey` 4.5, using `svymean()` on `subset(svydesign(...))`.
That oracle shape matters: a design rebuilt from the filtered rows would
reproduce the defect and agree with the old code.

| Case | surveycore | `survey` | abs diff | old value |
|---|---|---|---|---|
| domain 50 of 100 | 1.552416211029 | 1.552416211029 | 2.22e-16 | 1.560316599003 |
| domain 20 of 100 | 2.674043291912 | 2.674043291912 | 0.00e+00 | 2.729758510960 |
| domain 10 of 100 | 2.997866455176 | 2.997866455176 | 4.44e-16 | 3.144188863821 |
| domain 5 of 100 | 3.591948311088 | 3.591948311088 | 4.44e-16 | 3.995790244562 |
| domain 2 of 100 | 2.775095188510 | 2.775095188510 | 0.00e+00 | 3.904905062159 |
| grouped, n = 10 of 150 | 2.781060842550 | 2.781060842550 | 4.44e-16 | 2.921707532305 |
| `NA` outcomes, domain 30 | 2.229214622028 | 2.229214622028 | 4.44e-16 | 2.263778150191 |
| full sample, no domain | 0.970061315665 | 0.970061315665 | 1.11e-16 | 0.970061315665 |

Every difference is at or below 4.5e-16, seven orders of magnitude inside the
1e-8 tolerance. The last row is bit-identical old and new, which is the
regression guard: an unfiltered estimate does not move.

The count includes rows that `na.rm = TRUE` drops from the estimate. Measured
on a 40-row frame with 5 `NA` outcomes and a 20-row domain, `survey` answered
0.2433998; only the 40-row count reproduces it, while 35, 20 and 16 do not.

Suite: 11635 passing, 0 failures, against a baseline of 11606 and 0. Coverage
96.25%, from 96.24%. No pre-existing test changed and no snapshot moved.
