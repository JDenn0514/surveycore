## Resubmission

This is a resubmission of surveycore, as version 1.2.0. CRAN archived
surveycore 1.0.0 on 2026-09-27 because the tests of grouped `get_diffs()`
failed under marginaleffects 1.0.0.

Cause: marginaleffects 1.0.0 requires the `rowid` column of `newdata` to be
preserved by the model's predict method. surveycore's
`get_predict.survey_glm_fit()` did not preserve it, so rows went missing from
grouped results, and the missing rows left `NA` comparisons that reached a
bare `if` in the `get_diffs()` output code.

Fixes:

* `get_predict.survey_glm_fit()` now preserves `newdata$rowid` (GitHub #174).
* The `get_diffs()` output code no longer passes an `NA` estimate to a bare
  `if`. A comparison that cannot be estimated is kept with an `NA` estimate,
  left out of p-value adjustment, and reported with a classed warning
  (GitHub #361).
* The marginaleffects floor in Imports is raised from 0.18.0 to 0.24.0. We
  ran the affected tests against every marginaleffects release from 0.18.0
  to 1.0.0. Releases before 0.24.0 label contrasts as
  `mean(A) - mean(Control)` rather than `A - Control`, which surveycore's
  grouped and ungrouped `get_diffs()` paths cannot match. 0.24.0 and every
  later release tested, including 1.0.0, pass (GitHub #361).

The full test suite passes with marginaleffects 1.0.0, the current CRAN
version.

surveytidy, which Imports surveycore, was archived on the same day as a
consequence. We will resubmit surveytidy once surveycore is back on CRAN.

## Suggested package not on CRAN

surveytidy is in Suggests and is currently not on CRAN (see above). It is
available from the repository named in `Additional_repositories`
(https://jdenn0514.r-universe.dev). Every use of it is conditional: each
test that calls it starts with `skip_if_not_installed("surveytidy")`, the
vignette that uses it sets `eval = requireNamespace("surveytidy", quietly =
TRUE)`, and no example or code under `R/` calls it. The package checks
cleanly with surveytidy not installed and `_R_CHECK_FORCE_SUGGESTS_=false`.

## R CMD check results

Local: Ubuntu 24.04.5 LTS, R 4.6.2 (2026-10-29), x86_64-pc-linux-gnu.
`R CMD check --as-cran --no-manual` (LaTeX was not available for the manual)
on the built tarball, with surveytidy not installed and
`_R_CHECK_FORCE_SUGGESTS_=false`:

    Status: 2 NOTEs

0 errors | 0 warnings | 2 notes

* `checking CRAN incoming feasibility ... NOTE`: package was archived on
  CRAN (see Resubmission above); surveytidy is a suggested package not in
  the mainstream repositories but available from `Additional_repositories`
  (the check reports "surveytidy yes https://jdenn0514.r-universe.dev").
  The same NOTE listed every URL, DOI and ORCID iD as unreachable and
  flagged the development version number; the URLs failed only because the
  check machine's network blocks most outbound hosts, and the version
  number is set to 1.2.0 for submission.
* `checking for future file timestamps ... NOTE`: "Unable to verify current
  time", also caused by the check machine's network.

Tests: `[ FAIL 0 | WARN 340 | SKIP 623 | PASS 12365 ]`, taking about 4
minutes (248 s elapsed). Heavy numerical-oracle tests (comparisons against
the `survey` package, polychoric/polyserial MLE, two-phase variance parity)
are gated with `skip_on_cran()` and run on every CI push.

win-builder R-devel and R-release: not yet run. TO BE FILLED IN by the
maintainer from the win-builder emails before submission.

## Package size

The source tarball is 5.9 MB and the installed size is 6.5 MB, of which
4.3 MB is the `data/` subdirectory. The package bundles survey
teaching datasets (ANES, NHANES, ACS PUMS, Pew Research, GSS, California API)
that are the primary examples for the package's functionality and are
referenced throughout the documentation and tests. All data is xz-compressed
(`LazyDataCompression: xz`).

## Reverse dependencies

surveytidy is the only reverse dependency. It was archived together with
surveycore and will be resubmitted after this submission is accepted.
`tools::package_dependencies("surveycore", reverse = TRUE, which = "all")`
against the current CRAN index finds no other package.
