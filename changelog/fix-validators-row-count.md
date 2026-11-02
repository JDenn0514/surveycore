# Changelog: fix/validators-row-count

**Branch:** `fix/validators-row-count`
**Status:** Complete
**Date:** 2026-11-02
**Issue:** #248

## Summary

Refs #248. The S7 validators did not repeat the constructors' row-count rule,
so `@data <-` could install a 0-row or 1-row frame on any design class, and the
malformed design failed later — on `as_svydesign()`, with an untyped `survey`
error. The maintainer's answer to the issue's underlying question is that
post-construction property assignment is a supported route: `@data` is
reachable through the documented API, so the validators must catch malformed
states.

**Part 1 (the omission).** The two row-count guards in
`.validate_data_frame()` are extracted into `.validate_not_empty()` and
`.validate_not_single_row()` in `R/core-validators.R`, and each of the four
design-class validators (`survey_taylor`, `survey_replicate`,
`survey_twophase`, `survey_nonprob`) calls both first, with `call = NULL`. One
rule, one implementation. The checks sit in each child validator rather than in
`survey_base`, because S7 runs a child validator before its parent's: on a
0-row frame the `survey_nonprob` validator would otherwise raise
`surveycore_error_weights_all_zero` first. They stay two functions so that
`.validate_data_frame()` keeps its order (0 rows, duplicate names, 1 row), and
constructor calls raise the same classes and messages as before.

For `survey_twophase` the count is `nrow(@data)`, the full phase 1 sample. The
phase 2 subset is not counted: no constructor applies a row-count rule to it,
and `as_survey_twophase()`'s subset rule (`surveycore_error_subset_degenerate`)
is a different rule, kept at Layer 3.

**Part 2 (the weight-sign rule).** No behaviour change. The difference between
`.validate_weights()` (strict, every constructor) and the `survey_nonprob`
validator (zeros allowed, negatives and an all-zero column refused) is
deliberate: surveywts's `adjust_nonresponse()` writes zero nonrespondent
weights into `@data` after construction (`archive/nonprob-zero-weights/`,
#80). Both sites, the `make_nonprob_zero_wt()` fixture and
`plans/error-messages.md` rows 10, 33 and 101 now record that.

## Files Modified

- `R/core-validators.R` — new `.validate_not_empty()` and
  `.validate_not_single_row()`, called by `.validate_data_frame()`; comment on
  `.validate_weights()` recording the intended difference
- `R/core-classes.R` — the row-count calls in the four design-class
  validators; the twophase rule stated at its site; comment on the
  `survey_nonprob` weight conditions
- `R/core-constructors.R` — `as_survey_nonprob()` `@param data` says "at least
  two rows" (it said one, but a 1-row frame was always refused);
  `@param weights` says zeros may appear after a surveywts adjustment
- `man/as_survey_nonprob.Rd` — regenerated
- `plans/error-messages.md` — rows 2, 4, 10, 33, 101
- `tests/testthat/test-s7-classes.R` — eleven new blocks: 0 rows and 1 row on
  each of the four classes (class only), a 2-row boundary, the twophase
  counting rule, and a refused write leaving the design unchanged; two
  domain-marker blocks moved from a 0-row design to a 2-row one
- `R/methods-conversion.R` — the zero-row replicate comment in
  `.from_svydesign_replicate()` notes the validator would also refuse it
- `tests/testthat/test-conversion.R` — the `make_nonprob_zero_wt()` comment
  points to the recorded reason; new block: `from_svydesign()` refuses a
  zero-row Taylor `survey.design`, which used to convert to a zero-row
  `survey_taylor`
- `tests/testthat/test-methods-compat.R` — E1c measured the size functions on
  a 1-row design written through `@data <-`; it now asserts the write is
  refused and the design keeps two rows
- `tests/testthat/test-analysis-helpers.R` — the block asserting
  `.apply_domain()` returns `logical(0)` on a zero-row design now asserts the
  zero-row write is refused on a marked design
- `NEWS.md` — Breaking changes bullet

## Changes

- Refuse a 0-row or 1-row `@data` in all four design-class validators, with
  `surveycore_error_empty_data` and `surveycore_error_single_row`
- Record the deliberate weight-sign difference for `survey_nonprob`
