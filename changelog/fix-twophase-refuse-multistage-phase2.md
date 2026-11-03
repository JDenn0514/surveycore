# Changelog: fix/twophase-refuse-multistage-phase2

**Branch:** `fix/twophase-refuse-multistage-phase2`
**Status:** Complete
**Date:** 2026-11-02
**Issue:** #338

## Summary

Refs #338, option 2: refuse a multi-stage phase 2 rather than support it. The
two-phase variance in `R/variance-twophase.R` reads one phase 2 cluster column
(`ph2_vars$ids[[1L]]`), one strata column and one fpc column. A multi-stage
`ids2` used to build and got a standard error from its first stage alone, and
`from_svydesign()` kept only the first stage of a phase 2 `strata` or `fpc`
formula. On the issue's fixture the SE came out 0.7825 against `survey`'s
0.8285, about 5.6% too small, with no condition.

All three routes that can install a phase 2 now raise one typed error,
`surveycore_error_twophase_multistage_phase2`:

- `as_survey_twophase()` refuses an `ids2` that resolves to more than one
  column. `strata2` and `fpc2` already went through `.resolve_single_col()`,
  which refuses more than one column with `surveycore_error_strata_multiple`
  and `surveycore_error_fpc_multiple`, so they needed no new check.
- `from_svydesign()` counts the stages of the phase 2 `id`, `strata` and
  `fpc` formulas in `x$phase2$call`, or the columns of the evaluated cluster,
  strata and population-size slots when there is no call, and refuses before
  phase 1 is converted. On survey 4.5, `survey::twophase()` refuses a
  multi-stage phase 2 `strata` or `fpc` with a single-stage `id` ("need at
  least as many id as fpc stages"), for both `"full"` and `"approx"`, so every
  reachable case has a multi-stage `id`.
- The `survey_twophase` S7 validator refuses more than one name in
  `@variables$phase2$ids`, `$strata` or `$fpc`. That covers the exported
  class constructor and every `@variables` assignment. `update_design()`
  already refuses every `survey_twophase`. No guard was added to the variance
  engine: no public route reaches it with a multi-stage phase 2.

The generated-column numbering `..surveycore_ids2_1..`, which only a
multi-stage `ids2` reached, is removed as dead code.

## Files Modified

- `R/utils.R` — new `.abort_twophase_multistage_phase2()`, shared by the
  three call sites
- `R/core-constructors.R` — the `ids2` check in `as_survey_twophase()`; the
  `@param ids2`, `strata2` and `fpc2` docs state the limit
- `R/methods-conversion.R` — new `.twophase_phase2_stages()` and the check in
  `.from_svydesign_twophase()`; the multi-stage numbering removed from
  `.from_svydesign_phase2()`; the two-phase section of `from_svydesign()`
  states the limit
- `R/core-classes.R` — the stage check in the `survey_twophase` validator
- `plans/error-messages.md` — row TP-3; the from-svydesign-twophase note no
  longer mentions the `_k` numbering
- `man/as_survey_twophase.Rd`, `man/from_svydesign.Rd` — regenerated
- `tests/testthat/test-constructors.R` — the block asserting a two-column
  `ids2` was stored now asserts the refusal (dual pattern), plus `"approx"`,
  tidyselect-helper and single-column blocks
- `tests/testthat/test-conversion.R` — the block asserting the
  `..surveycore_ids2_1..` numbering now asserts the refusal; six more blocks
  cover the issue's reproduction, `"approx"`, a single-stage strata, a strata
  expression, a two-stage fpc and the no-call path
- `tests/testthat/test-s7-classes.R` — four validator blocks (class only)
- `tests/testthat/_snaps/constructors.md`, `_snaps/conversion.md` — four new
  snapshots

## Changes

- Refuse a multi-stage phase 2 in `as_survey_twophase()`, `from_svydesign()`
  and the `survey_twophase` validator, with
  `surveycore_error_twophase_multistage_phase2`
