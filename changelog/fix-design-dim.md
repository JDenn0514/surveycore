# Changelog: fix/design-dim

**Branch:** `fix/design-dim`
**Status:** Complete
**Date:** 2026-09-08

## Summary

Refs #203. `nrow()`, `ncol()` and `dim()` returned `NULL` on every survey
design class. `NULL` is the one return value that fails silently: the objects
print like data frames, `NULL` is not an error, and nothing signalled that the
answer was wrong.

The cost was measured downstream before the fix. A surveywts example called
`nrow(design)` before and after `adjust_nonresponse()` to show that
nonrespondent rows are dropped, with a comment claiming the two counts differ.
Both printed nothing. `R CMD check` passed, and CI passed on six platforms,
because `NULL` is not an error. A human reading the rendered output caught it.

Two `S7::method(dim, ...)` registrations close it. `survey_base` delegates to
the stored data frame. `survey_collection` raises, because it declares no
parent, holds `@surveys` rather than a `@data` frame, and has no single pair of
dimensions to return; `length()` and `names()` already answer the two
container-shaped questions for that class.

**This fixes five functions, not the three the issue named.** `nrow()`,
`ncol()`, `NROW()` and `NCOL()` are not generic. They read `dim()` internally,
so registering `dim()` reaches all of them.

The column count is the width of the stored frame. It includes the weight
column, the cluster and stratum ids, `fpc`, the domain flag when present, and
every replicate-weight column. It also ignores `@variables$visible_vars`:
`print()` shows fewer columns when that key is set, and `ncol()` reports the
frame.

`length()` on a design still returns `1`. The issue recorded that and set it
aside as defensible for an S7 object. It is tracked separately in #235.

The governing spec deferred two follow-ups. The user-facing note about the
stored row count shipped afterwards in PR #240. The `length()` question is
open in #235.

## Files Modified

- `R/methods-compat.R` — two `S7::method(dim, ...)` registrations, one
  delegating for `survey_base` and one raising for `survey_collection`
- `plans/error-messages.md` — row C16 for
  `surveycore_error_collection_no_dim`
- `plans/spec-design-dim.md` — the governing spec
- `plans/test-spec-design-dim.md` — the test spec
- `plans/decisions-design-dim.md` — the decisions record
- `tests/testthat/test-methods-compat.R` — new file
- `tests/testthat/_snaps/methods-compat.md` — snapshot for the collection
  error

## Changes

- Register `dim()` for `survey_base`, delegating to the stored data frame, so
  `nrow()`, `ncol()`, `dim()`, `NROW()` and `NCOL()` all report real numbers
  instead of `NULL`
- Register `dim()` for `survey_collection`, raising
  `surveycore_error_collection_no_dim` with a message that names one member
  and points at `[[`
- Add the error class to `plans/error-messages.md` as row C16
- Ship the spec, test-spec and decisions documents alongside the
  implementation

## Tests

New file `tests/testthat/test-methods-compat.R`, with a snapshot for the
`survey_collection` error. Covers all four design classes, the five affected
functions, and the collection path.
