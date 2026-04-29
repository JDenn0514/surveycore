## Resubmission

This is a resubmission of surveycore 0.8.2 as 0.8.3. The previous
submission was flagged for four issues. Each is addressed below.

1. **Missing references in `Description`.** Two DOI references have been
   added that together describe the methods in the package:

   * Lumley (2004) `<doi:10.18637/jss.v009.i08>` for Taylor series
     linearization, replicate-weight, and two-phase variance estimation
     (and the design-based estimators built on top of them — means,
     totals, frequencies, quantiles, ratios, t-tests, ANOVA, and
     generalized linear models).
   * Mannan (2025) `<doi:10.2139/ssrn.6580480>` for weighted polychoric
     and polyserial correlation under complex survey designs.

   Both DOIs already appear in the package's roxygen `\references`
   blocks and have been validated by the existing CRAN-style URL
   checker.

2. **Commented-out code in examples.** Three `# svy <- as_survey(...)`
   lines have been uncommented in the `@examples` blocks of
   `anes_2024`, `gss_2024`, and `pew_npors_2025` (the third file —
   `anes_2024` — was not flagged in the reviewer note but had the same
   pattern and is fixed in the same change). All three calls now run
   during `R CMD check` and complete in well under one second combined.

   The `as_survey.Rd` man page was also flagged. The actual offending
   construct was a dangling `# tidy-select helpers also work...` comment
   inside a `\section{Tidy-select}` `\preformatted{}` block. That
   `\preformatted{}` block has been replaced with prose, and two
   additional runnable examples (the `c()` multi-column pattern and the
   `starts_with()` tidyselect helper) have been added to the main
   `@examples` block.

3. **Modification of `.GlobalEnv` in `R/glm.R`.** The single occurrence
   was an `environment(formula) <- globalenv()` assignment used to
   detach a programmatically-built formula from the calling frame. This
   has been changed to `environment(formula) <- baseenv()`, which
   achieves the same goal (a portable formula not embedding caller
   variables) without modifying or referencing `.GlobalEnv`.

## R CMD check results

Local macOS (arm64, R 4.5.2): 0 errors | 0 warnings | 1 note.

  * "Skipping checking HTML validation: 'tidy' doesn't look like recent
    enough HTML Tidy." — local macOS toolchain issue; does not appear on
    CRAN's check infrastructure.

win-builder R-devel (run before submission): 0 errors | 0 warnings | 1
note ("New submission") — expected for a package not yet on CRAN.

Test runtime under `R CMD check --as-cran` remains under 1 minute, with
heavy numerical-oracle tests gated by `skip_on_cran()` (introduced in
0.8.2 and unchanged in this submission).

## Package size

Source tarball is 5.8 MB; installed size is 6.4 MB, of which 5.1 MB is
the `data/` subdirectory. The package bundles survey teaching datasets
(ANES, NHANES, ACS PUMS, Pew Research, GSS) that are the primary
examples for the package functionality and are referenced throughout
the documentation and tests. The data is already xz-compressed
(`LazyDataCompression: xz`).
