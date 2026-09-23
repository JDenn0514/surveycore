# Impact — replicate-oracle-tests

## Estimated scope
- Files touched: 2 — `tests/testthat/test-variance-replicate.R`,
  `.claude/rules/testing-surveycore.md`
- Exported functions added/changed: none
- New dependencies: none
- CRAN-relevant: no — no DESCRIPTION change, no export change, no vignette

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Rationale: two files and no new export, but the spec must fix the correct
  per-type behaviour of `survey::svrepdesign()` for eight replicate types,
  including which arguments it overrides, which it discards and which warning
  it raises — a wrong reading produces a test that passes for the wrong reason.
