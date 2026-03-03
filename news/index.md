# Changelog

## surveycore 0.2.0

### New features

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
  computes weighted frequency tables for categorical survey variables
  across all five design types, with domain estimation, value-label
  support, and AAPOR small-cell warnings.

- [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
  returns survey-weighted means with design-correct standard errors for
  all five design types, including grouped and domain estimation.

- [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
  returns survey-weighted population totals (and population size when
  called without `x`) for all five design types.

- [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
  computes survey-weighted Pearson correlation using the delta-method
  variance approach, with optional `group` parameter for per-group
  correlations and Fisher Z confidence intervals.

- [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md)
  estimates survey-weighted quantiles using the Woodruff

  1952. linearization method; supports multiple `probs` in a single call
        and five CI interval methods.

- [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
  estimates survey-weighted ratios (numerator total / denominator total)
  with design-correct SEs via the delta method (Taylor, SRS, calibrated,
  two-phase) or direct per-replicate computation (replicate designs).

- All six analysis functions gain a `decimals` argument to round numeric
  output columns to a fixed number of decimal places.

- `na.rm = FALSE` now includes rows where a grouping variable is `NA` as
  a separate group row in all six analysis functions’ output.

- [`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md)
  auto-detects shared battery prefaces from variable labels using
  separator-based and longest-common-prefix detection.

- [`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)
  returns the weighting history stored in a survey design object’s
  metadata;
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
  and
  [`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md)
  now promote `"weighting_history"` attributes from the input data frame
  automatically.

- Two-phase variance estimation
  ([`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md))
  is now fully supported in
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
  and
  [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
  using the `"full"`, `"approx"`, and `"simple"` methods vendored from
  the `survey` package.

### Bug fixes

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
  no longer crashes when the `group` variable contains `NA` values.

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
  now outputs `pct` as a proportion (0–1) rather than a percentage
  (0–100); `se` and `se_srs` are on the same scale.

## surveycore 0.1.0

### New features

- [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  creates `survey_taylor` objects with a tidy-select interface (`ids`,
  `weights`, `strata`, `fpc`, `probs`); supports Taylor linearization
  for stratified, clustered, and SRS designs.

- [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
  creates `survey_replicate` objects; supports BRR, Fay BRR, JK1, JK2,
  JKn, bootstrap, ACS, and successive-difference replicate schemes.

- [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
  creates `survey_twophase` objects; supports “full”, “approx”, and
  “simple” two-phase variance estimation methods.

- [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md)
  modifies design variables on an existing survey object without
  reconstructing from scratch; respects `validate = TRUE/FALSE`.

- [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
  returns a weighted mean and standard error via Taylor linearization or
  replicate weights; respects `getOption("survey.lonely.psu")` for
  single-PSU strata.

- [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
  returns a weighted total and standard error using the same dispatch as
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md).

- Metadata setters:
  [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
  [`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
  [`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
  [`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
  [`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
  [`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
  [`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md).
  Single-variable setters automatically import haven `"label"` /
  `"labels"` attributes from the data frame column.

- Metadata extractors:
  [`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
  [`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
  [`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
  [`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md).

- Conversion utilities:
  [`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md),
  [`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md),
  [`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
  [`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)
  — round-trip conversion between surveycore objects,
  [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html) /
  [`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html),
  and [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md).

- [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) S7 methods for all
  survey design classes display design type, sample size, and a
  tibble-style data preview.

### Internal infrastructure

- S7 class hierarchy: abstract `survey_base` → `survey_taylor`,
  `survey_replicate`, `survey_twophase`; `survey_metadata` for label
  storage.

- Three-layer validation: S7 structural validators, Layer 2 input
  validators, Layer 3 constructor validators; all errors use typed
  `class=` for programmatic handling.

- Variance estimation vendored from the `survey` package (Thomas Lumley,
  GPL-2/GPL-3) — see `VENDORED.md` for full attribution.
