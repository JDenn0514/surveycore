# Implementation — PR 1: nonprob-jackknife-core

## Summary

- Added `.compute_nonprob_scale(type, R)` to `R/utils.R`: a `switch()`-based helper returning type-specific variance scale defaults (bootstrap: `1/R`, JK1: `(R-1)/R`, JK2/JKn: `1`).
- Updated `error-messages.md`: NB-1 class renamed to `surveycore_error_type_unsupported_for_nonprob` with expanded valid type set; NB-3 message updated from "Bootstrap variance" to "Replicate variance"; NB-9 (`surveycore_error_stratified_jk_rscales_unset`) and NB-10 (`surveycore_error_scale_negative`) rows added.
- Replaced the existing `if (!identical(type, "bootstrap"))` block in `as_survey_nonprob()` with two-step normalization (step 8: "jackknife" alias → "JK1") and validation (step 9: error `surveycore_error_type_unsupported_for_nonprob` for all other invalid types).
- Added `.is_stratified_jk()` inline helper and steps 10–12: rscales guard for JK2/JKn (NB-9), scale computation via `.compute_nonprob_scale()` (NB-10 includes negative-scale guard), and rscales default.
- Updated the old `surveycore_error_type_invalid` test to use the new class; updated two snapshot entries for changed message text.

## Files created/modified/deleted

| File | Change |
|------|--------|
| `plans/error-messages.md` | Gate 0: updated NB-1 class/message, NB-3 message text, added NB-9 and NB-10 rows |
| `R/utils.R` | Added `.compute_nonprob_scale(type, R)` internal helper |
| `R/core-constructors.R` | NB-3 message text update; `.is_stratified_jk()` inline helper; type normalization (step 8); type validation (step 9, NB-1); rscales guard (step 10, NB-9); scale computation (step 11, NB-10); rscales default (step 12) |
| `tests/testthat/test-utils.R` | New block: `.compute_nonprob_scale()` returns correct default for each type |
| `tests/testthat/test-constructors.R` | New blocks: 7 NB-1 error variants, 2 NB-3 message-text blocks, 2 NB-9 blocks, NB-10 block, 7 happy-path blocks (JK1, jackknife alias, JK2, JKn, bootstrap, explicit scale, scale=0); updated 1 existing test to use new class |
| `tests/testthat/_snaps/constructors.md` | Updated 2 existing snapshots (NB-3 message text, old NB-1 snapshot); new NB-1/NB-9/NB-10 snapshots auto-created on first run |

## Task checklist

- [x] Gate 0: error-messages.md finalized (NB-1, NB-3, NB-9, NB-10)
- [x] Task group 1: `.compute_nonprob_scale()` implemented and tested
- [x] Task group 2: type normalization and validation (NB-1, NB-3) implemented and tested
- [x] Task group 3: `.is_stratified_jk()` helper, rscales guard (NB-9), scale computation (NB-10), rscales default implemented and tested

## Tests added

- 1 block in `test-utils.R` (4 assertions)
- 17 new blocks in `test-constructors.R` (error paths + happy paths)
- Full suite: 11168 pass, 0 fail

## CRAN compliance

- [x] TRUE/FALSE used throughout (no T/F)
- [x] `::` used for all external calls
- [x] No bare `print()`/`cat()` in non-print-method code
- [x] No randomness introduced (no `seed =` needed)
- [x] No `par()`/`options()` modification
- [x] No file writing
- [x] `devtools::document()` run — no NAMESPACE or .Rd changes (no new exports)
- [x] `devtools::check()` — 0 errors, 0 warnings, 1 pre-existing note (`.git` dir in worktree)

## HOLDs raised

None.

## Notes for tester

- The `.git` NOTE in `devtools::check()` is a worktree artifact, not introduced by this PR.
- The `type = 1` (numeric) test uses `class=` only (no snapshot) per the implementation plan.
- The existing test "as_survey_nonprob() rejects type != 'bootstrap'" was renamed with "(legacy — superseded by NB-1 blocks)" to clarify the relationship between old and new blocks; its class was updated from `surveycore_error_type_invalid` to `surveycore_error_type_unsupported_for_nonprob`.
