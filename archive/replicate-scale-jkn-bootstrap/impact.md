# Impact — replicate-scale-jkn-bootstrap

## Estimated scope

- Files touched: 7
  - `R/core-constructors.R` — two lines in the `scale` switch (807, 813),
    plus the `@param scale` roxygen and the variance-formula prose
  - `man/as_survey_replicate.Rd` — regenerated
  - `man/as_survey_nonprob.Rd` — regenerated
  - `tests/testthat/test-constructors.R` — stored-default assertions
  - `tests/testthat/test-variance-replicate.R` — delete six
    `expect_failure()` wrappers across two blocks
  - `NEWS.md` — the migration note
  - `changelog/` — one entry
- Exported functions added/changed: none added. `as_survey_replicate()`
  changes the default value of an existing argument. `as_survey_nonprob()`
  changes documentation only.
- New dependencies: none
- CRAN-relevant: yes — the default change moves numerical output for every
  JKn and bootstrap design built without an explicit `scale`, so it needs a
  NEWS entry a user can act on.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)

- Result: full-required
- Rationale: four criteria fail — the write surface is 7 files against a
  bound of 3, `scale` multiplies the variance so numerical output moves, the
  user attached Wolter chapter 4, and a default-scale correction is not in
  the routine-pattern list.
