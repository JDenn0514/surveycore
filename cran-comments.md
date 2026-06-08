## Resubmission

This is a resubmission as version 1.0.0. The previous submission (0.8.3)
addressed four issues flagged by CRAN reviewers: missing `Description`
references, commented-out code in examples, modification of `.GlobalEnv`,
and use of single-quoted 'surveyverse'. Those changes are retained in full.

Since 0.8.3, the package has gained substantial new functionality: jackknife
variance for non-probability designs, calibration-adjusted variance
(`as_caldata()`, `@calibration` property), direction-of-improvement metadata
(`set_higher_is()`, `set_reverse_coded()`), expanded polychoric/polyserial
support for non-probability designs, and a new bundled dataset (`ca_api_2000`).
Several bug fixes and a thorough roxygen documentation audit (D1–D75, B1–B6)
have also been applied. See `NEWS.md` for the complete changelog.

## R CMD check results

Local macOS (arm64, R 4.5.2): 0 errors | 0 warnings | 0 notes.

win-builder R-devel (2026-06-06 r90114): 0 errors | 0 warnings | 0 notes.

Test runtime under `R CMD check --as-cran` is under 1 minute. Heavy
numerical-oracle tests (comparisons against the `survey` package,
polychoric/polyserial MLE, two-phase variance parity) are gated with
`skip_on_cran()` and run on every CI push and with `devtools::test()`
locally.

## Package size

Source tarball is approximately 6 MB; installed size is 7.0 MB,
of which the majority is the `data/` subdirectory. The package bundles survey
teaching datasets (ANES, NHANES, ACS PUMS, Pew Research, GSS, California API)
that are the primary examples for the package's functionality and are
referenced throughout the documentation and tests. All data is xz-compressed
(`LazyDataCompression: xz`).
