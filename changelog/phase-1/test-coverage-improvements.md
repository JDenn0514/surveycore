# test(analysis): improve test coverage across analysis and variance modules

**Date**: 2026-03-04
**Branch**: test/coverage-improvements
**Phase**: Phase 1

## Changes

- Add tests for analysis helper edge cases (`analysis-helpers`) including empty group results and `.meta` structure validation
- Expand `get_freqs()` tests: NA handling, `show_na`, `show_unweighted`, domain-only levels, single-level vars, label propagation
- Expand `get_means()` tests: domain estimation, grouped means with labels, `vartype` options, multi-var means
- Expand `get_totals()` tests: grouped totals, domain estimation, FPC correction, multi-var totals
- Expand `get_corr()` tests: grouped correlation, `method` argument, `.meta` structure
- Expand `get_quantiles()` tests: grouped quantiles, multi-prob, domain estimation
- Expand `get_ratios()` tests: grouped ratios, `vartype` options, `.meta` structure
- Expand `test-metadata-infer.R`: additional edge cases for inferred labels
- Expand `test-methods-print.R`: print output for SRS, replicate, twophase designs; domain info line
- Expand `test-s7-classes.R`: S7 property and validator edge cases
- Expand `test-utils.R`: utility function edge cases
- Expand variance tests: `test-variance-srs.R`, `test-variance-taylor.R`, `test-variance-replicate.R`, `test-variance-twophase.R` — additional numerical comparisons and edge cases
- Add snapshot for `utils` test output

## Files Modified

- `tests/testthat/test-analysis-helpers.R` — edge case tests for shared analysis helpers
- `tests/testthat/test-analysis-freqs.R` — expanded `get_freqs()` coverage
- `tests/testthat/test-analysis-means.R` — expanded `get_means()` coverage
- `tests/testthat/test-analysis-totals.R` — expanded `get_totals()` coverage
- `tests/testthat/test-analysis-corr.R` — expanded `get_corr()` coverage
- `tests/testthat/test-analysis-quantiles.R` — expanded `get_quantiles()` coverage
- `tests/testthat/test-analysis-ratios.R` — expanded `get_ratios()` coverage
- `tests/testthat/test-metadata-infer.R` — additional infer-labels edge cases
- `tests/testthat/test-methods-print.R` — print method coverage across design types
- `tests/testthat/test-s7-classes.R` — S7 class property and validator edge cases
- `tests/testthat/test-utils.R` — utility function edge cases
- `tests/testthat/test-variance-srs.R` — SRS variance numerical tests
- `tests/testthat/test-variance-taylor.R` — Taylor variance additional coverage
- `tests/testthat/test-variance-replicate.R` — replicate variance additional coverage
- `tests/testthat/test-variance-twophase.R` — two-phase variance additional coverage
- `tests/testthat/_snaps/utils.md` — new snapshot for utils tests
