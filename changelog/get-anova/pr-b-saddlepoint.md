# feat(variance): vendor saddlepoint CDF helpers from survey

**Date**: 2026-04-18
**Branch**: feature/variance-vendored-saddlepoint
**Plan**: `plans/impl-get-anova.md` — PR B

## Changes

- Vendor `.saddle()` and `.pchisqsum_sad()` byte-for-byte from
  `survey/R/pchisqsum.R` @ 4.4-8 (GPL-3 compatible with surveycore's
  GPL-3 license).
- Derive `.pFsum_sad()` per spec §V.5 with an added `mean.deff` scalar
  argument that makes the Rao-Scott rescaling visible at the call site
  (Pass 3 Issue 65). Under the default `mean.deff = mean(a)` the helper
  matches upstream.
- Add parity test grid vs `survey::pchisqsum(..., method = "saddlepoint")`
  and `survey::pFsum(..., method = "saddlepoint")` at absolute tolerance
  `1e-10` across five regimes: upper tail, mid-range, near zero, scalar
  `a`, large `df`.
- Add NA-regime parity at the root-finder level: `.saddle()` returns `NA`
  on the same inputs where `survey:::saddle()` returns `NA`.
- Both helpers are internal (no `@export`), dotted-name convention; no
  new package dependencies (`survey` is used via `skip_if_not_installed()`
  in tests only).

## Files Modified

- `R/variance-vendored-saddlepoint.R` — new file with `.saddle()`,
  `.pchisqsum_sad()`, `.pFsum_sad()` and GPL-3 attribution header
  pointing at `survey/R/pchisqsum.R` @ 4.4-8.
- `tests/testthat/test-variance-vendored-saddlepoint.R` — new parity
  test file with 8 `test_that()` blocks (5 `.pchisqsum_sad()` regimes,
  4 `.pFsum_sad()` regimes, 1 NA-regime root-finder parity test), all
  guarded by `skip_if_not_installed("survey")`.
