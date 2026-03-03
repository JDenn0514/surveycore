# chore(structure): remove stale file, fix headers, simplify .degf()

**Date**: 2026-03-02
**Branch**: worktree-chore/simplify
**Phase**: Phase 1

## Changes

- Delete `R/14-analysis-ratios.R` — stale duplicate left over from the PR #20
  rename refactoring; `get_ratios()` and its helpers already live in
  `analysis-ratios.R` / `analysis-ratios-helpers.R`
- Update 10 file header comments from old numeric-prefix names
  (e.g. `R/00-s7-classes.R`) to current semantic names (e.g. `R/core-classes.R`)
- Simplify `.degf()` in `analysis-helpers.R`: all 5 design-class branches
  returned `Inf`, so collapse to a single `survey_base` guard + `return Inf`

## Files Modified

- `R/14-analysis-ratios.R` — deleted (stale duplicate of `analysis-ratios.R`)
- `R/analysis-helpers.R` — simplify `.degf()` and fix file header comment
- `R/analysis-meta.R` — fix file header comment
- `R/core-classes.R` — fix file header comment
- `R/core-constructors.R` — fix file header comment
- `R/core-metadata.R` — fix file header comment
- `R/core-validators.R` — fix file header comment
- `R/methods-conversion.R` — fix file header comment
- `R/methods-print.R` — fix file header comment
- `R/update-design.R` — fix file header comment
- `R/utils.R` — fix file header comment
