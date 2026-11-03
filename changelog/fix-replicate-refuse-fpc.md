# Changelog: fix/replicate-refuse-fpc

**Branch:** `fix/replicate-refuse-fpc`
**PRs:** this PR
**Issues:** #251
**Status:** Complete
**Date:** 2026-10-16

## Summary

Closes #251, PR 6 of the replicate-scale arc (#257). `as_survey_replicate()`
now refuses `fpc` and `fpctype` with
`surveycore_error_replicate_fpc_unsupported` (register row RF-1), per
decision D12.

Neither argument ever changed a replicate standard error: `R/variance-replicate.R`
reads no FPC. No published number moves. The refusal's `"v"` bullet and the
`@param fpc,fpctype` entry give the working route: fold the correction into
`rscales` with `rscales = rscales * (1 - f)`. That is what
`survey::svrepdesign()` does with its own `fpc`, and a new oracle block pins
the equivalence against `survey` for `"JKn"`.

The refusal runs first, before the data frame is validated and before any
column is resolved, so a misspelled, multi-column or `NA`-holding `fpc` all
raise RF-1 rather than a column-level FPC error. An explicit `fpc = NULL` or
`fpctype = NULL` is accepted.

## One deliberate departure from the issue

#251 asked for three more removals, on the premise that no replicate design
can carry an FPC once the constructor refuses one. That premise does not hold:
the exported `survey_replicate()` constructor takes an untyped `variables`
list, and surveywts' `create_*_weights()` (`surveywts/R/replicate-utils.R`)
builds every replicate design that way, copying the source Taylor design's
`fpc` across. So these stay:

- `surveycore_warning_replicate_fpc_dropped` in `as_svydesign()` and its
  register row CB-3.
- The two replicate FPC lines in `print()` and `summary()`
  (`R/methods-print.R`).

The tests that exercise them now record the FPC on `@variables` after
construction, the state surveywts produces.

## Files Modified

| File | Change |
|---|---|
| `R/core-constructors.R` | RF-1 refusal; `fpctype` default `NULL`; column resolution and `.validate_fpc()` call removed; `@variables` stores `fpc = NULL`, `fpctype = "fraction"`; roxygen for `fpc`, `fpctype` and the `scale` cross-reference |
| `R/srr-stats-standards.R` | G2.2, G2.3, G2.3b no longer list `fpctype` as a `match.arg()` parameter |
| `man/as_survey_replicate.Rd` | regenerated |
| `plans/error-messages.md` | row RF-1; rows 13 and 13b no longer list `as_survey_replicate()` |
| `NEWS.md` | breaking-change entry |
| `tests/testthat/test-constructors.R` | RF-1 blocks (dual pattern), `rscales * (1 - f)` oracle block; four column-level replicate FPC blocks removed |
| `tests/testthat/test-conversion.R` | `make_rep_fpc()` records the FPC after construction |
| `tests/testthat/test-methods-print.R` | summary FPC block records the FPC after construction |
| `tests/testthat/test-labelled-storage.R` | S-23c retired |
| `tests/testthat/_snaps/constructors.md` | three RF-1 snapshots added, one obsolete snapshot removed |

## Verification

- `as_survey_replicate(fpc = )` and `as_survey_replicate(fpctype = )` raise
  `surveycore_error_replicate_fpc_unsupported`; both together name both.
- `rscales = rscales * (1 - f)` matches `survey::svrepdesign(fpc = f,
  fpctype = "fraction")` for `"JKn"`: mean to 1e-10, SE to 1e-8.
- `as_survey(fpc = )` is unchanged; the `survey_taylor` print sites are
  untouched.
