# feat(print): update survey_nonprob print method for bootstrap repweights

**Date**: 2026-05-19
**Branch**: feature/nonprob-bootstrap-print
**Plan**: nonprob-bootstrap-variance (PR 3)

## Changes

- Update `print.survey_nonprob` header line: when `@variables$repweights`
  is non-`NULL`, display `<survey_nonprob> (non-probability, BOOTSTRAP,
  N replicates) [experimental]`; otherwise display
  `<survey_nonprob> (non-probability) [experimental]` followed by a
  bullet noting the SRS variance approximation.
- Add replicate weight detail bullets in the `design_info` block (shown
  when `design_info = TRUE`): replicate count + column names, type, and
  scale.

## Files Modified

- `R/methods-print.R` — conditional header for `survey_nonprob` with/
  without repweights; add replicate detail bullets in `design_info` block.
- `tests/testthat/test-methods-print.R` — add three snapshot tests:
  `survey_nonprob` with repweights, without repweights, and with
  repweights + `design_info = TRUE`.
- `tests/testthat/_snaps/methods-print.md` — three new snapshots;
  existing nonprob-without-repweights snapshots updated with SRS bullet.
- `tests/testthat/_snaps/constructors.md` — updated snapshots from PR 3
  print changes propagating through constructor error output.
