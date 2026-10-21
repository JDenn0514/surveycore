# Changelog: test/guard-surveytidy-suggests

**Branch:** `claude/upbeat-keller-perzmo`
**Status:** Complete
**Date:** 2026-10-21

## Summary

Refs #294. Four test blocks called `surveytidy::` functions without
`skip_if_not_installed("surveytidy")`. Where surveytidy is not installed,
each one errors with `there is no package called 'surveytidy'`. The
resubmission in #294 drops `surveytidy` from `Suggests` because it is not on
CRAN. Without this fix, the suite would error on any machine without
surveytidy.

Two of the blocks are in `test-glm.R`, which has no file-level
`skip_on_cran()`. They would have errored on every CRAN flavour. That is the
same kind of failure that got surveycore 1.0.0 archived. The other two are in
`test-analysis-corr-latent.R`. That file skips on CRAN, so those two failed
only under `NOT_CRAN=true` (`devtools::test()`, CI).

The four blocks now run without surveytidy instead of skipping, so the
behaviour they check stays tested on CRAN. A new test helper,
`.testhelper_mark_domain()`, writes the `..surveycore_domain..` column that
`surveytidy::filter()` writes. The `surveytidy::mutate()` call became a
column added to the data frame before the design is built. Every assertion
is unchanged.

**No behaviour changes.** Test files only.

## Files Modified

- `tests/testthat/helper-test-data.R` — adds `.testhelper_mark_domain()`,
  which marks domain membership without surveytidy
- `tests/testthat/test-analysis-corr-latent.R` — the two PC-15 domain blocks
  build their domain with the helper instead of `surveytidy::filter()`
- `tests/testthat/test-glm.R` — the nonprob binomial block adds `y_bin` to
  the data frame before construction, and the nonprob domain oracle block
  builds its domains with the helper

## Changes

- Add `.testhelper_mark_domain()` to mark a domain on a design without
  surveytidy
- Replace `surveytidy::filter()` with the helper in the PC-15 "Inf row
  outside the domain" and "Inf row the domain keeps" blocks
- Replace `surveytidy::mutate()` and `surveytidy::filter()` in two
  `survey_glm()` nonprob replicate blocks, which had no surveytidy guard and
  no CRAN skip

## Verification

- A parse-based sweep of `tests/testthat/` found 35 remaining `surveytidy::`
  calls. Each one sits inside a `test_that()` block that calls
  `skip_if_not_installed("surveytidy")` before it.
- Before the fix, with surveytidy not installed and `NOT_CRAN=true`, the two
  files gave 4 errors: 2 in `test-analysis-corr-latent.R` and 2 in
  `test-glm.R`.
