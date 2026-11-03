# Impact — replicate-fay-rho

## Estimated scope
- Files touched: about 12 — `R/core-constructors.R`, `R/core-classes.R`
  (a new `@variables` key, if the validator lists keys),
  `R/methods-conversion.R`, `R/variance-replicate.R` (to confirm no change),
  `plans/error-messages.md`, `NEWS.md`, `man/`, `tests/testthat/helper-test-data.R`
  (`test_invariants()` key list), `tests/testthat/test-constructors.R`,
  `tests/testthat/test-conversion.R`, `tests/testthat/test-variance-replicate.R`,
  `.claude/rules/testing-surveycore.md`
- Exported functions added/changed: `as_survey_replicate()` gains `rho`;
  `as_svydesign()` and `from_svydesign()` change behaviour for Fay
- New dependencies: none
- CRAN-relevant: yes — an exported argument, moved standard errors, and the
  DESCRIPTION Fay claim

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Rationale: a new argument on an exported constructor, a changed variance
  scale, and a new error and warning class.
