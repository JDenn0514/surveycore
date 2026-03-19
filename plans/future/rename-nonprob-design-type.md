# Future: Rename `survey_nonprob` design_type from "calibrated" to "nonprob"

**Status:** Not started
**Scope:** Small refactor PR targeting `develop`

## Problem

`.build_meta()` in `R/analysis-helpers.R` maps `survey_nonprob` to
`design_type = "calibrated"`. This is a leftover from when the class was named
`survey_calibrated`. The class has since been renamed to `survey_nonprob`, but
the design_type string was never updated.

## What to change

1. `R/analysis-helpers.R` line ~351: change `"calibrated"` to `"nonprob"`
2. `R/analysis-meta.R` (`print.survey_diffs()` and `print.survey_result()`):
   update display name maps to use `"nonprob" -> "Non-probability"`
3. `R/glm-methods.R`: check for any branching on `design_type` strings
4. Update all snapshot tests that capture `design_type = "calibrated"`
5. Update any downstream code that branches on `design_type == "calibrated"`

## Why not now

This affects all six existing `get_*()` functions, their snapshots, and any
code branching on the `"calibrated"` string. It's a cross-cutting rename that
should be its own PR, not bundled into `get_diffs()`.
