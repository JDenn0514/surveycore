# Changelog: feature/replicate-fpc-applied

**Branch:** `feature/replicate-fpc-applied`
**PRs:** this PR
**Issues:** #320
**Status:** Complete
**Date:** 2026-10-16

## Summary

Closes #320. Two things, as the issue specifies:

- Every `survey_replicate` design records whether its finite population
  correction reached the variance, and where, in a new key
  `@variables$fpc_applied` (`"rscales"`, `"repweights"`, `"none"`, or `NULL`).
  A second key, `@variables$fpc_fraction`, holds the per-replicate sampling
  fraction of a numeric `fpc`. `print()`, `summary()`, `as_svydesign()` and
  `from_svydesign()` read or set them. surveywts#130 depends on this: it will
  set `fpc_applied` on every design `create_*_weights()` builds.
- `as_survey_replicate()` accepts a numeric `fpc`, a number or one value per
  replicate, and folds it into `rscales` as `survey::svrepdesign()` does
  (`svrepdesign.default` lines 132-147). The column form stays refused (#251).

No replicate variance formula reads either key: `R/variance-replicate.R` is
byte-identical to `develop`. No existing number moves.

Decision D12 in `plans/issue-cleanup.md` is amended. The plan is
`plans/implementation-plan-replicate-fpc-applied.md`. The register rows are
RF-1 (restated), RF-1b, RF-2, RF-3a to RF-3g and RF-4, with CB-3's trigger
narrowed.

## Decisions confirmed before code

The issue carried three unreviewed decisions; the maintainer confirmed them,
with one reversal and two additions:

| # | Issue proposed | Shipped |
|---|---|---|
| a | `@variables$fpc_fraction` | As proposed, and the class validator checks it too (RF-4). |
| b | `fpctype` defaults to `"fraction"` | **Reversed.** `fpctype` is required whenever `fpc` is given, as in `survey`, and must match exactly. The same `0.9` reads as `f` or as `1 - f`. |
| c | A bare symbol naming a column is refused even when a same-named variable exists; `.env$f` gets around it | As proposed, plus: a single string naming a column is refused too, and an expression that fails to evaluate raises RF-3c with the R error as parent. |

### What survey stores, and `from_svydesign()`

The issue asked for `fpc_applied = "rscales"` "when the source carries one".
Deparsing `survey:::svrepdesign.default` (survey 4.5) shows `survey` keeps no
`fpc` field: it multiplies `rscales` and leaves the argument only in the
stored call. `as.svrepdesign()` keeps no trace at all; its call names the
source design only. So the import sets `"rscales"` when `x$call[["fpc"]]` is
not `NULL`, and `NULL` otherwise. The expression is not evaluated, so `fpc`
and `fpc_fraction` stay `NULL` and `print()` shows
`FPC: applied in replicate scales`.

## Behaviour changes inside the arc

These change behaviour #251 shipped, in the same development version:

- `fpc = no_such_column` and `fpc = starts_with("fpc")` raised RF-1 under
  #251. Neither is a bare column name, so both are now evaluated, fail, and
  raise `surveycore_error_replicate_fpc_invalid` (RF-3c). A misspelled
  column is reported as "could not be evaluated", with R's "object not found"
  as the parent.
- The RF-1 and RF-1b messages are rewritten for their narrower triggers. The
  class is unchanged.
- The CB-3 warning gains one `"i"` bullet and fires in the unknown state only.

A consequence worth knowing: a function that wraps `as_survey_replicate()`
and passes its own argument called `fpc` (`fpc = fpc`) has that argument read
as the data's `fpc` column whenever the data has one. It must write
`.env$fpc`. The new print test helper hit exactly this.

## Files Modified

| File | Change |
|---|---|
| `R/core-constructors.R` | RF-1/RF-1b at the top; FPC step after the Fay step (RF-2, RF-3 via `.resolve_replicate_fpc()`); `.replicate_fpc_column()`; both keys in `@variables`; roxygen for `fpc`, `fpctype`, the `scale` cross-reference and an example |
| `R/core-classes.R` | RF-4 checks in the `survey_replicate` validator; `@variables` docs |
| `R/methods-print.R` | `.print_replicate_fpc()`, called from `print()` and `summary()` |
| `R/methods-conversion.R` | CB-3 gated on `fpc_applied`; `from_svydesign()` sets both keys |
| `man/as_survey_replicate.Rd`, `man/survey_replicate.Rd` | regenerated |
| `plans/error-messages.md` | RF-1 restated, RF-1b, RF-2, RF-3a–g, RF-4; CB-3 row and trigger |
| `plans/issue-cleanup.md` | D12 amended |
| `plans/implementation-plan-replicate-fpc-applied.md` | new |
| `NEWS.md` | two New features bullets; the #251 Breaking changes bullet corrected |
| `tests/testthat/helper-test-data.R` | `test_invariants()` checks the FPC keys on replicate designs |
| `tests/testthat/test-constructors.R` | RF-1/RF-1b/RF-2/RF-3 blocks; stored-key blocks; oracle blocks for JK1, JKn, other; #251 blocks rewired; the by-hand oracle stops passing `scale` |
| `tests/testthat/test-s7-classes.R` | RF-4 blocks; `.rep_vars()` carries both keys |
| `tests/testthat/test-methods-print.R` | four-state snapshots for `print()` and `summary()`; numeric-fpc and keyless designs |
| `tests/testthat/test-conversion.R` | CB-3 in each state; no double application; `from_svydesign()` import |
| `tests/testthat/_snaps/` | `constructors.md`, `methods-print.md`, `conversion.md` |

## Verification

Run in a cloud session: R 4.6.1, survey 4.5, `LC_ALL=C.UTF-8`.

- Full suite, `NOT_CRAN=true testthat::test_local()`: 12,948 passed,
  0 failed, 39 skipped, 4 errors. All four errors are
  `there is no package called 'surveytidy'` (surveytidy is not installable
  here; CI runs them). The same four error on clean `develop`.
- Clean `develop` in the C locale also shows 10 print-snapshot failures
  (`<U+00D7>` and similar); they are locale artefacts and pass under
  `C.UTF-8`.
- `devtools::check(document = FALSE, args = c("--no-manual", "--no-tests"))`:
  0 errors, 0 warnings, 1 note ("Unable to verify current time", the
  sandbox's blocked network).
- `R/variance-replicate.R` is byte-identical to `develop`
  (`git diff --quiet develop -- R/variance-replicate.R`).
- `air format --check` passes on every R file this PR changes, except the
  lines already unformatted on `develop` in `test-constructors.R` and
  `helper-test-data.R`, which this PR leaves alone.
- `man/` regenerated with
  `roxygen2::roxygenise(roclets = c("rd", "namespace", "collate"))`: the srr
  roclet is not installed here, so `devtools::document()` fails.
- Every snapshot change was reviewed against its register template before
  it was accepted.
