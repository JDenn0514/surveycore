# Changelog: fix/visible-vars-nocov

**Branch:** `fix/visible-vars-nocov`
**Status:** Complete
**Date:** 2026-11-02
**Issue:** #234

## Summary

Refs #234. Two `# nocov` markers in `R/methods-print.R` said the
`visible_vars` print path was "only set by surveytidy". A direct
`d@variables[["visible_vars"]] <- ...` reaches it with no suggested package,
and #248 settled that post-construction property assignment is a supported
route. Both markers are removed and the path is tested on all four print
methods.

Measuring the path found a defect next to it: with `visible_vars` set,
`print(x, full = TRUE)` still showed only the visible columns and printed the
note "Use `print(x, full = TRUE)` to show all variables" again. `full` switched
on the info sections and never reached the column filter. By the maintainer's
decision, `full = TRUE` now shows every column, so the note's advice holds and
the note does not fire under `full = TRUE`. The default print is unchanged.

## Files Modified

- `R/methods-print.R` — both `nocov` markers removed and their comments
  corrected; `.data_for_print()` takes `full` and ignores `visible_vars` when
  it is `TRUE`; the four print methods pass `full`; their `@param full`
  comments say it shows every column
- `tests/testthat/test-methods-print.R` — four blocks: the column filter and
  the hidden-variable note on all four classes, `full = TRUE` showing every
  column on all four classes, and one snapshot of both prints
- `tests/testthat/_snaps/methods-print.md` — the new snapshot; no existing
  snapshot changed
- `NEWS.md` — Bug fixes bullet

## Changes

- Remove the two `nocov` markers on the `visible_vars` print path and test it
- `print(x, full = TRUE)` shows every data column whatever `visible_vars`
  holds
