# Changelog: chore/marginaleffects-floor

**Branch:** `fix/diffs-na-guards-marginaleffects-floor` (PR #361)
**Status:** Complete
**Date:** 2026-11-02

## Summary

Raises the `marginaleffects` floor in `Imports` from `0.18.0` to `0.24.0`
(refs #294). Releases before 0.24.0 do not work with surveycore's
`get_diffs()`, so the old floor let an incompatible version install without
complaint.

Releases before 0.24.0 label `avg_slopes()` contrasts as
`mean(A) - mean(Control)`, and 0.24.0 onward labels them `A - Control`.
`.extract_me_estimates()` gets the level name by removing `" - <ref>"` from
the label, so the old format matches no level in `avg_predictions()`. The
marginaleffects NEWS does not mention the label change.

Measured by installing each archived release and running
`devtools::test(filter = "analysis-diffs|glm")` against `develop`:

- 0.18.0 to 0.20.0: 12 failures. Every grouped `get_diffs()` test aborts with
  `subscript out of bounds`.
- 0.20.1 to 0.23.0: 20 failures. The ungrouped path also returns wrong
  level names.
- 0.24.0, 0.25.0, 0.32.0 and 1.0.0: 0 failures.

The `rowid` fix (#174, `changelog/fix-marginaleffects-rowid.md`) works with
every version tested, so it does not set the floor. Every marginaleffects
function and method surveycore calls or registers exists in 0.18.0, so its
interface does not set the floor either. No upper bound was added.

## Files Modified

- `DESCRIPTION`: `marginaleffects (>= 0.18.0)` → `marginaleffects (>= 0.24.0)`

## Changes

- `marginaleffects` 0.24.0 or later is now required. Releases before 0.24.0
  give wrong level names or errors in `get_diffs()`.
