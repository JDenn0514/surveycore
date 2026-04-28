# chore/cran-resubmit-0.8.2 — CRAN Resubmission Fixes

**Branch:** `chore/cran-resubmit-0.8.2`
**Date:** 2026-04-27

## Summary

Addresses CRAN feedback on the 0.8.1 submission. Two issues were flagged:
test runtime exceeded 10 minutes (Uwe Ligges) and a "possibly misspelled
words" NOTE for `surveyverse` in the `Description` field. After these
changes `R CMD check --as-cran` runs in ~2 minutes (test step in 48
seconds, down from ~11 minutes), and the spell-check NOTE no longer
appears.

## Changes

### `tests/testthat/` (11 files, +1 line each)

Added `skip_on_cran()` at the top level of each numerical-oracle and
heavy-integration test file. testthat treats a top-level `skip()` as a
file-level skip; these files continue to run on every push in CI and
locally with `devtools::test()`.

- `test-analysis-t-test-numerical.R`
- `test-analysis-diffs-numerical.R`
- `test-analysis-diffs-marginaleffects.R`
- `test-glm-numerical.R`
- `test-glm-anova-numerical.R`
- `test-glm-marginaleffects.R`
- `test-analysis-corr-latent.R`
- `test-analysis-corr-latent-variance.R`
- `test-analysis-variance-twophase-nonprob.R`
- `test-variance-vendored-saddlepoint.R`
- `test-variance-twophase.R`

### `DESCRIPTION`

- Bumped `Version` from `0.8.1.9000` to `0.8.2`.
- Single-quoted `'surveyverse'` in `Description` to match the convention
  already used for `'S7'`, `'tidyselect'`, and `'haven'`. This silences
  the CRAN spell-check NOTE.

### `NEWS.md`

- Added `# surveycore 0.8.2` section documenting the resubmission.

### `cran-comments.md`

- Rewrote as a resubmission cover letter explaining how each of the two
  issues from the 0.8.1 submission was addressed.
