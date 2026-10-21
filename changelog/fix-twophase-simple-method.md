# Changelog: fix/twophase-simple-method

**Branch:** `fix/twophase-simple-method`
**Status:** Complete
**Date:** 2026-10-21
**Issue:** #330

## Summary

Refs #330. `method = "simple"` on a `survey_twophase` design gave
different standard errors from `survey` on the same design. In survey 4.5
the two names are one method: `?survey::twophase` says `"simple"` or
`"approx"` "(the two are the same)", and `survey::twophase()` never
branches on `"simple"`. surveycore computed a method of its own.
`.twophasevar()` returned the Phase 1 term alone, from `.svy_recvar()` on
the raw influence values, and skipped the Phase 2 term.

`"simple"` now runs the `"approx"` variance. The design still records
`"simple"`, and `print()` still shows it, but every estimate, standard
error and interval equals the `"approx"` one. The estimates never differed;
only the variance did.

`surveycore_warning_simple_clustered` is gone. It warned that `"simple"`
ignores the Phase 1 clusters, and with the `"approx"` formula that is no
longer true. The `as_survey_twophase()` help and the "Creating survey
objects" vignette now describe both methods as `survey` does. The old text
said `"approx"` "ignores Phase 1 sampling variability", which was also
wrong: it adds a Phase 1 term and a Phase 2 term.

### Published numbers move

Every `method = "simple"` standard error, CI, CV and margin of error moves,
in every analysis function and in `survey_glm()`. On a 400-row, 40-PSU,
8-stratum design with 167 phase-2 rows:

| Estimate | SE before | SE after = `survey` |
|---|---|---|
| `get_means()` of `y1` | 0.8512 | 0.8688 |
| `get_totals()` of `y1` | 14310.87 | 14342.03 |

`"approx"` and `"full"` do not change.

## Files Modified

- `R/variance-twophase.R` — removes the `"simple"` branches from
  `.twophasevar()` and `.twophase_phase1_var()`, and drops the latter's now
  unused `method` argument
- `R/core-constructors.R` — removes warning 24 and rewrites the `method`
  documentation for `"approx"` and `"simple"`
- `man/as_survey_twophase.Rd` — regenerated
- `vignettes/creating-survey-objects.Rmd` — the same correction to the
  method list
- `plans/error-messages.md` — row 24 marked retired
- `tests/testthat/test-variance-twophase.R` — oracle blocks against
  `svymean()`, `svytotal()`, `svyglm()` and `svyquantile()` under
  `"simple"`
- `tests/testthat/test-constructors.R`, `tests/testthat/_snaps/constructors.md`
  — the three warning-24 blocks and their snapshot replaced by one block
  asserting no warning

## Changes

- Make two-phase `method = "simple"` an alias of `"approx"`, so its
  standard errors match `survey`
- Remove `surveycore_warning_simple_clustered` and correct the method docs
