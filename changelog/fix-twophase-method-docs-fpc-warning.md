# Changelog: fix/twophase-method-docs-fpc-warning

**Branch:** `fix/twophase-method-docs-fpc-warning`
**Status:** Complete
**Date:** 2026-10-29
**Issues:** #339, #340

## Summary

Both two-phase variance methods match `survey::twophase()` exactly, and both
give standard errors that are too large (conservative) for some designs.
These are properties of the estimators, not porting defects, so no estimator
changes. This branch is the pre-submission minimum the two issues name:
documentation for both, and a typed warning for #340.

- **#339, `method = "approx"`.** Conservative when phase 1 is clustered and
  phase 2 subsamples rows within the phase-1 clusters (`ids2` absent or finer
  than the phase-1 cluster): about 2.4 times the variance, 1.55 times the SE.
  Close to unbiased when phase 2 draws whole phase-1 clusters or phase 1 is
  unclustered. Documented in `@param method`, with `method = "full"` and a
  phase-1 `fpc` as the alternative.
- **#340, `method = "full"` without a phase-1 `fpc`.** `twophase2var()`
  places `1 - p` on each phase-1 unit and nothing off the diagonal: Poisson
  sampling of units, with unit totals never centred. Documented in
  `@param method` and a new Details section, and warned at construction.

### The trigger rule, and why it is not "clustered or stratified"

The issue's option 2 proposed warning on a clustered or stratified phase 1.
A simulation on #340's finite population (200 replications per row, phase 2
a 50% SRS of phase-1 rows) measured the ratio of mean estimated variance to
empirical variance:

| Phase 1 | Total, no fpc | Total, fpc | Mean, no fpc | Mean, fpc |
|---|---|---|---|---|
| Clustered, stratified | 13.8 | 1.03 | 1.94 | 0.91 |
| Clustered only | 11.4 | 0.93 | 0.98 | 1.00 |
| Stratified only | 16.7 | 0.98 | 1.18 | 0.98 |
| Neither (weighted SRS) | 14.3 | 1.02 | 1.02 | 1.02 |

The overstatement of a total does not depend on clustering or
stratification, and on one draw of the last row surveycore and `survey`
agree to the digit (SE 8855.43), so it is the estimator. The maintainer chose
to warn on any weighted phase 1. The rule: `method = "full"`, the phase-1
`fpc` is `NULL`, and the phase-1 weights are not all 1. Weights of all 1 are
the no-weights fallback (iid under `"full"`) or a census (no phase-1
variance), and neither is overstated.

`survey` raises no condition here. `?survey::twophase` says only that without
a phase-1 `fpc` or `probs` totals "will not be correctly estimated, but
means ... will be correct". The mean column above shows that the claim about
means fails for a stratified phase 1.

### `from_svydesign()`

`.from_svydesign_twophase()` builds `survey_twophase()` directly and never
calls `as_survey_twophase()`. It raises the same warning under the same rule,
from the same helper: a `twophase2` object without a phase-1 `fpc` gets the
same conservative SE in surveycore, and a user who only converts would
otherwise never be told.

## Files Modified

- `R/utils.R` — adds `.warn_twophase_full_no_fpc()`, the one implementation
  of the trigger, shared by both call sites
- `R/core-constructors.R` — `as_survey_twophase()` warns after the design is
  built; `@param method` documents both issues; new Details section "Phase 1
  fpc and `method = "full"`"; both examples give phase 1 an `fpc`
- `R/methods-conversion.R` — `.from_svydesign_twophase()` warns after the
  design is built; the `from_svydesign()` two-phase section names the warning
- `R/core-classes.R` — the `survey_twophase()` example uses
  `method = "approx"`, so it stays warning-free
- `man/as_survey_twophase.Rd`, `man/from_svydesign.Rd`,
  `man/survey_twophase.Rd` — regenerated
- `plans/error-messages.md` — row TP-2,
  `surveycore_warning_twophase_full_no_fpc`
- `NEWS.md` — one bullet under the development version
- `tests/testthat/test-constructors.R` — nine new blocks: three phase-1
  shapes that warn (clustered and stratified, stratified only, clustered
  only), a message snapshot, four cases that must not warn (a phase-1 `fpc`,
  `method = "approx"`, an unweighted iid phase 1, a census), and one showing
  the warning fires at construction and not from `get_means()`
- `tests/testthat/test-conversion.R` — three new `from_svydesign()` blocks:
  warns, and does not warn with a phase-1 `fpc` or with no phase-1 `probs`
- Existing blocks: the new warning reached 65 blocks in 11 files. 30 build
  the design the warning is about and now assert it with
  `expect_warning(class = )`: the `from_svydesign(twophase2)` blocks, and the
  `"full"` oracle blocks in `test-variance-twophase.R` Section 7, which pin
  parity on the no-`fpc` branch (the `fpc` branch has its own blocks). 35
  test something else and gained a phase-1 `fpc`. No block was wrapped in
  `suppressWarnings()`, and no oracle block had an `fpc` added to one side
  only

## Changes

- Warn with `surveycore_warning_twophase_full_no_fpc` when a `"full"`
  two-phase design has a weighted phase 1 and no phase-1 `fpc`, in
  `as_survey_twophase()` and `from_svydesign()`
- Document that `"full"` without a phase-1 `fpc` and `"approx"` with
  row-level phase-2 subsampling within phase-1 clusters are conservative,
  with the measured sizes
