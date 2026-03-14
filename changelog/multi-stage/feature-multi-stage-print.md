# PR 7: Update `print.survey_taylor` Per-Stage FPC Display

**Branch:** `feature/multi-stage-print`
**Merged:** 2026-03-14

## Summary

Updated `print.survey_taylor` to display multi-column FPC with one bullet
per stage (e.g., `FPC (stage 1): fpc`, `FPC (stage 2): fpc2`) instead of
collapsing all column names into a single line.

## Changes

### `R/methods-print.R`
- Updated FPC display section in `print.survey_taylor`: when
  `length(fpc_var) > 1`, renders one `FPC (stage j): col_name` bullet per
  stage; single-column FPC unchanged (`FPC: col_name`)

### `tests/testthat/test-methods-print.R`
- Added snapshot test: 2-stage design with `fpc = c(fpc, fpc2)` shows
  per-stage FPC bullets in `design_info = TRUE` output
- Added content test: single-stage design still shows `FPC: fpc` (no
  `(stage N)` suffix)

### `tests/testthat/_snaps/methods-print.md`
- Added snapshot for per-stage FPC display
