# Impact — replicate-supplied-args

## Estimated scope
- Files touched: about 8 — `R/core-constructors.R`,
  `R/methods-conversion.R`, `plans/error-messages.md`,
  `man/as_survey_replicate.Rd`, `NEWS.md`, and tests in
  `tests/testthat/test-constructors.R`, `test-conversion.R`,
  `test-variance-replicate.R` (plus snapshots). The `as_survey_nonprob()`
  roxygen and its `.Rd` may also change.
- Exported functions added/changed: `as_survey_replicate()` (behaviour),
  `as_svydesign()` (behaviour). No new export.
- New dependencies: none
- CRAN-relevant: no export change; behaviour change recorded in `NEWS.md`.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Reason: more than 3 files, a new typed warning class, a new typed refusal
  on an exported constructor, and a change to which numbers the exported
  `survey` design reproduces.
