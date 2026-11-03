# Changelog: fix/diffs-na-guards

**Branch:** `fix/diffs-na-guards-marginaleffects-floor` (PR #361)
**Status:** Complete
**Date:** 2026-11-02

## Summary

`get_diffs()` no longer aborts with `missing value where TRUE/FALSE needed`
when a comparison row has an `NA` estimate (refs #294). The guards in
`.build_diffs_output()` that read `estimate` used a bare `if` on
`estimate != 0` or `estimate == 0`, and the group-matching loops used
`TRUE && (a == b)`, so an `NA` reached an `if`. This is how the grouped
`get_diffs()` failures under marginaleffects 1.0.0 that led to CRAN
archiving surveycore 1.0.0 showed up. The underlying `rowid` defect was
fixed in #174.

A row with an `NA` estimate now:

- keeps its `NA` estimate in the output;
- is left out of `pval_adj` adjustment;
- gets an `NA` `pct_change`;
- triggers the new warning `surveycore_warning_diffs_na_estimate`, raised
  once per call and naming each affected level once.

No supported model produces an `NA` difference today. A perfectly collinear
covariate is refused earlier with `surveycore_error_singular_model_matrix`.
So the guards affect only upstream defects. For input without an `NA`, the
new predicates give the same answers as the old checks, and no output
changes.

## Files Modified

- `R/analysis-diffs-helpers.R`: three new internal predicates replace the
  inline checks. `.diffs_is_ref_row()` tests `isTRUE(estimate == 0)`.
  `.diffs_is_comparison_row()` tests `!is.na(estimate) && estimate != 0`.
  `.diffs_same_group()` uses `%in%` per group column, so `NA` matches `NA`
  and the check never returns `NA`. The new warning is raised from
  `.build_diffs_output()`.
- `tests/testthat/test-analysis-diffs-helpers.R`: Category 8, 13 blocks.
  They cover the typed warning, the `NA` estimate, adjusted p-values,
  `pct_change`, and naming each level once, grouped and ungrouped. They
  also check that nothing warns when no estimate is `NA`, and test the
  three predicates directly.
- `plans/error-messages.md`: row DN-1 for
  `surveycore_warning_diffs_na_estimate`.
- `NEWS.md`: bug fix entry.

## Changes

- `get_diffs()` keeps a comparison with an `NA` estimate rather than
  aborting. It leaves that row out of p-value adjustment, gives it an `NA`
  percentage change, and warns with `surveycore_warning_diffs_na_estimate`.
