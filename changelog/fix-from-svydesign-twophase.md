# Changelog: fix/from-svydesign-twophase

**Branch:** `fix/from-svydesign-twophase`
**Status:** Complete
**Date:** 2026-10-22
**Issue:** #335

## Summary

Refs #335. `from_svydesign()` on a `survey::twophase()` object kept the
phase 1 design and threw the phase 2 design away. `.from_svydesign_twophase()`
wrote `phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL)`
whatever the source held. A `twophase2` object (`method = "full"`) then raised
`surveycore_error_full_requires_phase2` on every estimate. A `twophase` object
(`method = "approx"`) estimated without its phase 2 strata, and on the issue's
example gave mean 50.1 and SE 0.869 against `survey`'s 50.032 and 0.8881.

Both classes keep the phase 2 formulas as written in `x$phase2$call`, and the
route now reads `ids2`, `strata2`, `probs2` and `fpc2` from them. A formula
that names columns directly keeps the names. Any other formula (`~I(1/w2)`,
`~interaction(a, b)`) is evaluated on the phase 1 data, as `survey` evaluates
it, and goes into a generated column named `..surveycore_{key}2..`. An approx
phase 2 `weights` formula goes in the same way, as probabilities, because
surveycore records no phase 2 weights. A phase 2 design with no stored call is
rebuilt from the values `survey` evaluated on the phase 2 rows. None of these
raises a condition, following the `..surveycore_wt..` precedent; the one new
condition is `surveycore_error_phase2_name_collision`, for a generated name
that already names a data column. The phase 1 weight column of a `twophase2`
object is read from its `probs = ~I(1/w)` formula, the form `as_svydesign()`
writes since #332, and no longer by value matching.

### Method

`survey::twophase()` stores no method. The route now takes it from the class
alone: `twophase2` is `"full"` and `twophase` is `"approx"`, which also covers
`"simple"` (#330). `surveycore_warning_twophase_method_unknown` fired on every
approx object, with its default printed in doubled quotes. It is retired, and
row 62 of `plans/error-messages.md` is marked so.

The route also never wrote the `visible_vars` key that `as_survey_twophase()`
writes; `test_invariants()` caught it, and the key is now present.

## Files Modified

- `R/methods-conversion.R` — `.from_svydesign_twophase()` reads the phase 2
  design and the subset column from the stored calls and sets the method from
  the class; new helpers `.from_svydesign_phase2()`, `.formula_cols()`,
  `.plus_terms()`, `.eval_design_formula()` and
  `.weights_from_probs_formula()`; `from_svydesign()` gains a two-phase
  roxygen section
- `man/from_svydesign.Rd` — regenerated
- `plans/error-messages.md` — row 62 retired; row TP-1 added
- `tests/testthat/test-conversion.R` — the method-warning block replaced; 23
  new blocks: structural recovery, the value-match fallbacks for the phase 1
  weights and the subset column, `svymean()`/`svytotal()`/`svyglm()` oracles
  for full and approx with `strata2` and with `ids2`, filtered and unfiltered,
  the `as_svydesign()` round trip, the generated-column fallbacks and the
  collision error
- `tests/testthat/_snaps/conversion.md` — the collision error snapshot

## Changes

- Recover the phase 2 design of a two-phase `survey` object in
  `from_svydesign()`, with a silent generated-column fallback
- Read the `twophase2` phase 1 weights from `probs = ~I(1/w)`
- Set the two-phase method from the class and retire
  `surveycore_warning_twophase_method_unknown`
- Write the `visible_vars` key on the two-phase route
