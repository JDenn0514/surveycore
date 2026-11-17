# Impact — analysis-cell-performance

## Estimated scope
- Files touched: about 13. `R/analysis-freqs.R`, `R/analysis-freqs-helpers.R`,
  `R/analysis-means.R`, `R/analysis-means-helpers.R`, `R/analysis-totals.R`,
  `R/analysis-totals-helpers.R`, `R/analysis-variance.R`,
  `R/analysis-variance-helpers.R`, `R/analysis-covariance.R`,
  `R/analysis-covariance-helpers.R`, `R/analysis-ratios.R`,
  `R/analysis-ratios-helpers.R`, `R/analysis-helpers.R`, plus their test files.
- Exported functions added/changed: none in signature. Six exported functions
  change internally: `get_freqs()`, `get_means()`, `get_totals()`,
  `get_variance()`, `get_covariance()`, `get_ratios()`.
- New dependencies: none.
- CRAN-relevant: no. A `NEWS.md` entry for the speed-up.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Rationale: more than 3 files, and the joint-variance change alters how the
  variance is computed even though the numbers do not change.
