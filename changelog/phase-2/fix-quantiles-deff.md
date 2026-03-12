# docs(analysis): document deff = NA by design for quantiles

**Date**: 2026-03-12
**Branch**: fix/quantiles-deff
**Phase**: Post-Phase-2 Audit Remediation (PR 8)

## Changes

- Document `deff = NA` as intentional for quantile estimates: computing DEFF
  requires a kernel density estimate at the quantile point (the Woodruff SRS
  approximation used by `survey::svyquantile(deff = TRUE)`), which is not
  implemented
- Add explanatory comment at `se_srs = NA_real_` in `analysis-quantiles-helpers.R`
  referencing the Woodruff approximation and the audit plan
- Update `@return` roxygen in `get_quantiles()` to note that `deff` is always
  `NA` and explain why
- Update inline comment in `get_quantiles()` DEFF block with implementation path

## Files Modified

- `R/analysis-quantiles-helpers.R` — expand `se_srs = NA_real_` comment with
  reference to Woodruff SRS approximation and non-implementation rationale
- `R/analysis-quantiles.R` — update `@return` and inline DEFF comment
- `man/get_quantiles.Rd` — regenerated with updated documentation
