## Resubmission

This is a resubmission of surveycore 0.8.1 as 0.8.2. The previous
submission was flagged for two issues:

1. **Test runtime exceeded 10 minutes** (Uwe Ligges, "Please reduce the
   test timings"). Numerical oracle tests against the `survey` package,
   `marginaleffects` integration tests, polychoric/polyserial MLE tests,
   vendored saddlepoint parity tests, and two-phase variance parity tests
   (11 test files in total) are now gated with `skip_on_cran()`. These
   continue to run on every push in CI and locally during development.
   Test runtime under `R CMD check --as-cran` is now ~50 seconds,
   down from ~11 minutes.

2. **"Possibly misspelled words" NOTE for `surveyverse`.** The word is
   the proper name of the package ecosystem this package founds; it is
   now single-quoted in `Description` to match the convention already
   used for `'S7'`, `'tidyselect'`, and `'haven'`. The NOTE no longer
   appears in the local check.

## R CMD check results

Local macOS (arm64, R 4.5.2): 0 errors | 0 warnings | 2 notes.

  * "New submission" (CRAN incoming feasibility) — expected for a
    first-time submission and returned by win-builder as well.
  * "Skipping checking HTML validation: 'tidy' doesn't look like recent
    enough HTML Tidy." — local macOS toolchain issue; does not appear on
    CRAN's check infrastructure.

## Package size

Source tarball is 5.8 MB; installed size is 6.4 MB, of which 5.1 MB is the
`data/` subdirectory. The package bundles several survey teaching datasets
(ANES, NHANES, ACS PUMS, Pew Research) that are the primary examples for
the package functionality and are referenced throughout the documentation
and tests. The data is already xz-compressed (`LazyDataCompression: xz`).

## Method references

There are no published references describing the methods in this package
beyond the standard survey sampling literature (e.g., Lohr 2022,
"Sampling: Design and Analysis"). The variance estimation code is vendored
from the 'survey' package (Thomas Lumley, GPL-2/GPL-3) with full
attribution in `VENDORED.md`.
