# refactor(analysis): apply shared meta helpers to all analysis functions

**Date**: 2026-02-26
**Branch**: feature/analysis-label-meta-apply-all
**Phase**: Phase 1

## Changes

- Refactor `get_freqs()`, `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`, and `get_ratios()` to use the shared `.extract_var_meta()`, `.build_group_meta()`, and `.apply_group_labels()` helpers introduced in the prior commit
- Migrate all functions from the flat meta structure (`variable`, `variable_label`, `question_preface`, `value_labels`, `group_names`, `group_labels`) to the nested structure (`x`, `group`) per the new meta-key constants (`FREQS_META_KEYS`, `MEANS_META_KEYS`, etc.)
- Apply `.apply_group_labels()` in `get_means()`, `get_totals()`, and `get_corr()` to convert coded group columns to labelled factors in the `group_combos` output
- Update `test-analysis-{freqs,means,totals,corr,quantiles,ratios}.R`, `test-constructors.R`, `test-variance-replicate.R`, and `test-variance-srs.R` to reflect new nested meta key paths (e.g. `names(meta(result)$x)` instead of `meta(result)$variable`)
- Add new tests for nested meta structure in each analysis function test file (label assignment, group meta, value label conversion)
- Expand `vignettes/getting-started.Rmd` with new sections covering `get_quantiles()`, `get_corr()`, and `get_ratios()`

## Files Modified

- `R/analysis-freqs.R` — use `.extract_var_meta()` for pre-collection; emit nested `x` / `group` meta keys
- `R/analysis-means.R` — replace inline metadata collection with `.extract_var_meta()`, `.build_group_meta()`, `.apply_group_labels()`; emit nested meta
- `R/analysis-totals.R` — same refactor as `analysis-means.R`
- `R/analysis-corr.R` — replace inline metadata collection with shared helpers; emit nested meta
- `R/analysis-quantiles.R` — same refactor; emit nested meta
- `R/analysis-ratios.R` — same refactor; emit nested meta (with `numerator`/`denominator` under `x`)
- `R/analysis-helpers.R` — minor fixes to `.extract_var_meta()` and `.apply_group_labels()` surface from integration work
- `R/analysis-corr-helpers.R` — update internal meta key references to use new nested constants
- `tests/testthat/helper-test-data.R` — minor test-data generator updates for new meta structure
- `tests/testthat/test-analysis-freqs.R` — update meta assertions to nested structure; add new label tests
- `tests/testthat/test-analysis-means.R` — same
- `tests/testthat/test-analysis-totals.R` — same
- `tests/testthat/test-analysis-corr.R` — same
- `tests/testthat/test-analysis-quantiles.R` — same
- `tests/testthat/test-analysis-ratios.R` — same
- `tests/testthat/test-analysis-helpers.R` — additional edge-case coverage for helpers
- `tests/testthat/test-constructors.R` — update meta key assertions
- `tests/testthat/test-variance-replicate.R` — update meta key assertions
- `tests/testthat/test-variance-srs.R` — update meta key assertions
- `vignettes/getting-started.Rmd` — add sections for `get_quantiles()`, `get_corr()`, `get_ratios()`
- `vignettes/creating-survey-objects.Rmd` — minor YAML and whitespace fixes
- `plans/analysis-label-meta-refactor-implementation-plan.md` — mark all checkboxes complete
