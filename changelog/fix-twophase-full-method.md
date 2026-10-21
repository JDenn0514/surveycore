# Changelog: fix/twophase-full-method

**Branch:** `fix/twophase-full-method`
**Status:** Complete
**Date:** 2026-10-21
**Issues:** #329, #261

## Summary

Closes #329; #261 was closed as its duplicate. A two-phase design built with
`method = "full"` returned the `"approx"` standard error. `.twophasevar()`
used the method only to raise an error, and then sent `"full"` and
`"approx"` through the same `svyrecvar.phase1` formula, which is
`survey::twophase()`'s approximation. `"full"` now computes the
double-expansion Horvitz-Thompson variance of `survey::twophase2()`
(Breslow and Chatterjee, 1999). Every analysis function on a `"full"` design
reaches it: `get_means()`, `get_totals()`, `get_freqs()`, `get_variance()`,
`get_corr()`, the covariance helpers and `survey_glm()`.

The point-estimate gaps both issues reported were not in `get_means()`.
`survey::twophase(method = "full")` refuses a `weights` argument, and both
`as_svydesign()` and #329's reproduction gave it no phase-1 weights or
probabilities, so `survey` read phase 1 as equal-probability. `as_svydesign()`
now passes the phase-1 weights as `probs = ~I(1 / w)`. Built that way, `survey`
agrees with surveycore's estimate to 1e-10, and the standard errors agree to
1e-8.

### Published results move

- Every `method = "full"` standard error and confidence interval changes. On
  #329's fixture, the SE of the mean moves from 0.8881 to 0.8200, and the SE
  of the total from 14,446 to 36,479.
- Under `ids2` without `probs2` or `fpc2`, the phase-2 inclusion probability
  is now the fraction of clusters selected in each phase-2 stratum, as in
  `survey`. It used to be the fraction of rows. Means are unchanged, because
  the factor cancels. Totals change under every method, `"approx"` and
  `"simple"` included.
- `fpc2` now sets the phase-2 probability for the point estimate too. It used
  to reach the variance only.
- A phase 1 with no weights, probs, strata or `fpc`, and no repeated cluster,
  is an iid sample under `"full"`, as in `survey` (`phase1_is_iid`). A phase 1
  with weights of 1 is a census and contributes no phase-1 variance.

### Where surveycore deliberately differs from survey 4.5

`survey:::Dcheck_multi_subset()` passes `Dcheck_subset()` a row-length
`sampsize` vector, which `Dcheck_subset()` indexes by cluster. When a phase-1
`fpc` meets strata holding unequal numbers of clusters, `survey` reads each
stratum's cluster count from the wrong rows. On one measured design its
variance of a total is negative. surveycore uses each stratum's own count.
Correcting that one index makes `survey` reproduce surveycore's value.

## Files Modified

- `R/variance-twophase.R` — adds `.twophase_full_var()`, the `twophase2`
  check-matrix variance reduced to grouped sums; dispatches `"full"` to it;
  `.compute_phase2_probs()` uses the cluster fraction under `ids2` and honours
  `fpc2`
- `R/utils.R` — adds `.twophase_phase1_is_iid()`, shared by the variance
  engine and the conversion
- `R/methods-conversion.R` — `as_svydesign()` passes the phase-1 weights as
  `probs` for `"full"`, passes `probs2`, and passes an all-`NULL` `fpc` as
  `NULL` so `survey` takes the iid branch
- `R/core-constructors.R`, `man/as_survey_twophase.Rd`, `man/as_svydesign.Rd`
  — documents the `"full"` estimator, the `ids2` probability and the
  conversion
- `tests/testthat/test-variance-twophase.R` — the four pbc and nwtco `"full"`
  blocks now compare against `survey`'s `"full"` object. They had built the
  `"approx"` one, so they passed only while the defect stood. Adds Section 6:
  oracle blocks for `get_means()`, `get_totals()` and `survey_glm()` under
  `strata2` and `ids2`, unfiltered and filtered, a phase-1 `fpc` block, an
  `fpc2` block, and a pairwise Horvitz-Thompson block for the design `survey`
  gets wrong
- `tests/testthat/test-analysis-variance-twophase-nonprob.R` — the pbc
  `"full"` `get_variance()` block compares against `survey`'s `"full"`
  object
- `tests/testthat/test-conversion.R` — the block that pinned #261's gap now
  asserts that `get_means()` and `svymean()` agree on the estimate and the SE

## Changes

- Compute the `method = "full"` two-phase variance as `survey::twophase2()`
  does, the double-expansion Horvitz-Thompson estimator, instead of the
  `"approx"` formula
- Use the phase-2 cluster fraction under `ids2`, and honour `fpc2`, in the
  phase-2 inclusion probability
- Pass the phase-1 weights to `survey::twophase(method = "full")` as `probs`
  in `as_svydesign()`
- Replace the `"full"` oracle blocks that compared against `survey`'s
  `"approx"` object, and add `"full"` oracle blocks for means, totals and GLMs

## Verification

Each of the 22 new or rewritten blocks fails against the pre-fix `R/` and
passes after the fix.
