# chore/cran-resubmit-0.8.3 — CRAN Resubmission Fixes

**Branch:** `chore/cran-resubmit-0.8.3`
**Date:** 2026-04-29

## Summary

Addresses CRAN feedback on the 0.8.2 submission. Four issues were
flagged: (1) missing methods references in `Description`, (2)
commented-out `as_survey()` calls in three dataset `@examples` blocks
plus one in `as_survey()`'s `\section{Tidy-select}`, (3) modification of
`.GlobalEnv` in `R/glm.R`. After these changes `devtools::check()` runs
clean (0 errors, 0 warnings, 1 environmental note); win-builder R-devel
clean (0 errors, 0 warnings, 1 "New submission" note).

## Changes

### `DESCRIPTION`

- Added two DOI references to the `Description` field:
  - Lumley (2004) `<doi:10.18637/jss.v009.i08>` for variance
    estimation methods (Taylor series, replicate, two-phase) and the
    design-based estimators built on top of them.
  - Mannan (2025) `<doi:10.2139/ssrn.6580480>` for weighted polychoric
    and polyserial correlation.
- Trimmed the analysis-functions enumeration to three exemplars
  (`means, frequencies, and regression models`) for brevity.
- Single-quoted `'Lumley'`, `'Mannan'`, `'polychoric'`, and
  `'polyserial'` in `Description` to silence the win-builder
  spell-check NOTE. This follows the same convention already used for
  `'S7'`, `'tidyselect'`, `'haven'`, and `'surveyverse'`.
- Removed the `'surveyverse'` ecosystem pointer; the package's role in
  the ecosystem is documented in `README.md` and the package-level
  `man/surveycore-package.Rd`, which is sufficient for CRAN purposes.
- Bumped `Version` from `0.8.2.9000` to `0.8.3`.

### `R/data.R`

- Uncommented the three `# svy <- as_survey(...)` lines in the
  `@examples` blocks of `anes_2024`, `gss_2024`, and `pew_npors_2025`
  so they run during `R CMD check`.
- Added `nest = TRUE` to the ANES and GSS calls (in both the
  `@examples` block and the `@details` prose code-sketch). Both
  datasets have non-globally-unique PSU IDs, so omitting `nest = TRUE`
  was producing a warning at every constructor call. With the change,
  the warning is gone and the design assumption is explicit.
- The `pew_npors_2025` example needs no `nest = TRUE` (no PSU in the
  ABS design).

### `R/core-constructors.R`

- Replaced the `\section{Tidy-select}` `\preformatted{}` code sketch
  with prose. The previous block contained a dangling
  `# tidy-select helpers also work (e.g., starts_with())` comment with
  no code following it — the construct CRAN's automated checker
  flagged.
- Added two new runnable demonstrations to the `@examples` block of
  `as_survey()`:
  - `c()` for multi-stage IDs, sketched on a small inline
    `data.frame` (we have no real multi-stage dataset in the package).
  - Tidy-select helpers via `starts_with("wtssn")` on `gss_2024`,
    which resolves uniquely to the `wtssnrps` non-response-adjusted
    weight column.

### `R/glm.R`

- Replaced `environment(formula) <- globalenv()` with
  `environment(formula) <- baseenv()` (line 822) and updated the
  surrounding comment to explain the choice. `baseenv()` retains
  access to base R operators that formulas may rely on (`+`, `:`,
  `I`, `log`, etc.) without referencing or modifying `.GlobalEnv`.
  The existing comment block at lines 1046–1049 already explains why
  the formula environment is mostly cosmetic in this code path —
  `do.call()` embeds the weights vector directly, bypassing the only
  place that the formula environment would have mattered for symbol
  lookup.

### `NEWS.md`

- Added `# surveycore 0.8.3` section documenting the four
  resubmission fixes.

### `cran-comments.md`

- Rewrote as a resubmission cover letter that responds to each of
  CRAN's four flags point-by-point, with a fresh `R CMD check`
  results summary and the win-builder R-devel result.
