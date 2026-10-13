# Changelog: fix/replicate-supplied-args

**Branches:** `fix/replicate-export-ignored-args`,
`fix/replicate-jkn-rscales-required`, `fix/replicate-scale-discard`,
`fix/replicate-rscales-discard`, `test/replicate-supplied-scale-oracle`,
`fix/replicate-rho-class-and-docs`
**PRs:** #311, #312, #314, #315, #316, and this PR
**Issues:** #255, #244
**Status:** Complete
**Date:** 2026-10-13

## Summary

Closes #255. `as_survey_replicate()` now treats a supplied `scale`, `rscales`
and `rho` the way `survey::svrepdesign()` does.

- A supplied `scale` is stored as given for `"JK1"`, `"JKn"`, `"bootstrap"`
  and `"other"`. For `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`
  it is ignored: the design stores the type's own value and the call warns
  with `surveycore_warning_replicate_arg_ignored`. `"Fay"` already ignored a
  supplied `scale` with no warning, and still does.
- A supplied `rscales` is ignored for `"JK2"`, `"ACS"` and
  `"successive-difference"` with the same warning, and the design stores
  `NULL`, which the variance treats as `rep(1, R)`. The length and value
  checks still run on it first. The other types store it as given.
- One call raises one discard warning, which names every ignored argument.
  surveycore warns only when the caller supplies `scale` or `rscales`;
  `survey` warns on every `"JK2"` call.
- The `rho` warning, `surveycore_warning_rho_ignored`, now also carries the
  class `surveycore_warning_replicate_arg_ignored`. It fires before the
  discard warning.
- `type = "JKn"` now requires `rscales` and refuses `rscales = NULL` with
  `surveycore_error_stratified_jk_rscales_unset`, as `survey` refuses
  combined JKn weights without it. Before, the design built with `rep(1, R)`
  and left the jackknife factor out of the variance (#244). `"JK2"` with no
  `rscales` still builds.

A caller who passed one of the ignored arguments now gets the standard error
`survey` computes, which differs from the one surveycore returned before. A
caller who passed neither sees no change.

On export, `as_svydesign()` no longer passes `scale` to `svrepdesign()` for
`"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` and `"successive-difference"`, or
`rscales` for `"JK2"`, `"ACS"` and `"successive-difference"`. `survey`
computes those values itself, so the exported design gives the same numbers.
`survey` no longer warns about ignored arguments for `"ACS"` and
`"successive-difference"`; it still warns for every `"JK2"` design.

## Files Modified

- `plans/error-messages.md` — rows RS-1, RS-2 and RS-3, and the updated
  trigger note for FR-3
- `R/utils.R` — the predicates `.replicate_ignores_scale()` and
  `.replicate_ignores_rscales()`
- `R/core-constructors.R` — the JKn refusal, the discard step and the
  second class on the `rho` warning in `as_survey_replicate()`; roxygen for
  `as_survey_replicate()` and `as_survey_nonprob()`
- `R/methods-conversion.R` — the `scale` and `rscales` arguments that
  `.as_svydesign_replicate()` passes to `svrepdesign()`
- `man/as_survey_replicate.Rd` — regenerated
- `man/as_survey_nonprob.Rd` — regenerated
- `NEWS.md` — two Breaking-changes entries and one Bug-fixes entry
- `tests/testthat/test-constructors.R` — discard, refusal and `rho` class
  blocks, and the retargeted blocks
- `tests/testthat/test-conversion.R` — export-route blocks and one retarget
- `tests/testthat/test-variance-replicate.R` — oracle blocks for a supplied
  `scale` and `rscales`
- `tests/testthat/_snaps/constructors.md` — new snapshot entries only
- `vignettes/creating-survey-objects.Rmd` — section 3.4 states which types
  ignore or require `scale` and `rscales` (added to the last PR by decision
  S-1)

## Changes

- Stop passing `scale` and `rscales` that `survey` overrides on export, and
  add the register rows and the two predicates (#311)
- Refuse JKn with no `rscales` in `as_survey_replicate()` (#312)
- Discard a supplied `scale` for BRR, JK2, ACS and successive-difference
  (#314)
- Discard a supplied `rscales` for JK2, ACS and successive-difference (#315)
- Add oracle blocks against `survey` for a supplied `scale` on all nine
  replicate types (#316)
- Give the `rho` warning the second class, and document the change in the
  help pages, `NEWS.md`, this file and the vignette (this PR)

## Verification

- The oracle blocks compare surveycore against `survey::svrepdesign()` at
  these tolerances: point estimate 1e-10, standard error 1e-8, confidence
  bounds 1e-6.
- `devtools::test()` on this PR's branch reports 13017 expectations, no
  failure, 4 skips and 256 warnings, the count of AAPOR small-cell warnings
  already on `develop`.
- Package coverage with `NOT_CRAN=true`: COVERAGE_PENDING (from the gate 6
  run).
