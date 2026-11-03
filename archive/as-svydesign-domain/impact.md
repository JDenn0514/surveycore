# Impact — as-svydesign-domain

## Estimated scope
- Files touched: 4 — `R/methods-conversion.R`, `tests/testthat/test-conversion.R`,
  `man/as_svydesign.Rd` (regenerated), `NEWS.md`. The issue names the first two;
  the roxygen section at `R/methods-conversion.R:88-101` documents the current
  behaviour and must change, which regenerates the `.Rd`.
- Exported functions added/changed: none added. Behaviour changes in
  `as_svydesign()` and, through it, `as_tbl_svy()`.
- New dependencies: none.
- CRAN-relevant: no DESCRIPTION change, no export change, no new vignette.
  `vignette("surveycore-vs-survey")` may need a line if it repeats the
  limitation.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Rationale: the change alters which rows the returned object estimates over,
  which is an estimation-semantics change and not a routine edit; it carries
  four open decisions and a documentation section that currently states the
  opposite of the new behaviour.
