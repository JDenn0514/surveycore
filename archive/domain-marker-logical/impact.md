# Impact — domain-marker-logical

## Estimated scope

- Files touched: 8
  - `R/core-classes.R` — add a validator to `survey_base`
  - `R/analysis-helpers.R` — `.apply_domain()` resolves `NA` to `FALSE`
  - `R/methods-conversion.R` — remove the dead `as.logical()` coercion
  - `plans/error-messages.md` — new row 102
  - `tests/testthat/test-s7-classes.R` — new validator blocks
  - `tests/testthat/test-analysis-helpers.R` — new `NA` marker blocks
  - `tests/testthat/test-analysis-quantiles.R` — two blocks change to logical
  - `tests/testthat/test-conversion.R` — one block changes to expect the error
- Exported functions added/changed: none. The change is a class validator,
  so every constructor and every `@data` write gains a new failure mode.
- New dependencies: none.
- CRAN-relevant: no. No DESCRIPTION change, no export change, no new
  vignette.

## Risk notes

- The validator runs on every `@data` assignment on every design object, so
  it sits on a hot path that the whole package crosses.
- Eleven analysis call sites read the mask. The validator fixes all of them
  at once, and no call site is edited.
- Eleven test files assign to `design@data[[SURVEYCORE_DOMAIN_COL]]`
  directly. Any that writes a non-logical column starts failing. The issue
  names three; the spec must confirm the full count.
- This reverses one decision shipped under #245.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)

- Result: full-required
- Rationale: the change touches 8 files, not ≤3, and it adds a new error
  class, which is a public contract change.
