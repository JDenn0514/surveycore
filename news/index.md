# Changelog

## surveycore 0.6.1

### Bug fixes

- `survey_nonprob` validator now accepts zero weights when at least one
  positive weight exists, unblocking the surveywts
  `adjust_nonresponse()` workflow. Previously, any zero weight triggered
  an error. Negative weights are still rejected.

## surveycore 0.6.0

### Breaking changes

- `survey_srs` class and `as_survey_srs()` constructor have been
  removed. SRS designs are now created via
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  with no `ids` or `strata` — this produces a `survey_taylor` with no
  cluster/strata structure. All estimates are numerically identical.

### New features

- [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)
  estimates treatment effects (differences from a reference group) via
  survey-weighted regression. Supports bivariate and multivariate
  models, Gaussian and non-Gaussian families, and optional subgroup
  analysis. Two estimation paths: direct coefficients for simple models,
  and
  [`marginaleffects::avg_slopes()`](https://rdrr.io/pkg/marginaleffects/man/slopes.html)
  /
  [`avg_predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html)
  for models with covariates or non-Gaussian AMEs. Returns a
  `survey_diffs` tibble with optional `mean`, `pct_change`, `n_weighted`
  columns, significance stars, and p-value adjustment. `marginaleffects`
  moved from Suggests to Imports.

- [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  now supports multi-column FPC for multi-stage designs (e.g.,
  `fpc = c(fpc_stage1, fpc_stage2)`). Each FPC column corresponds to one
  ID stage. Per-stage FPC is validated for NAs, non-positive values, and
  within-cluster constancy.

- [`print()`](https://rdrr.io/r/base/print.html) for `survey_taylor` now
  displays per-stage FPC bullets for multi-stage designs (e.g.,
  `FPC (stage 1): fpc`, `FPC (stage 2): fpc2`).

### Bug fixes

- SRS variance estimation now uses Taylor (HT) linearization via
  `.build_cluster_matrices()`, correct for any weight structure.
  Previously used unweighted sample variance which was incorrect for
  non-proportional weights.

- [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  now correctly indexes weights when `na.action = na.omit` drops
  non-contiguous rows.

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
  now routes `survey_nonprob` designs through the Horvitz-Thompson
  variance path, consistent with the other five analysis functions.

- [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
  now accepts `survey_replicate` and SRS `survey_taylor` objects as the
  phase-1 design (previously restricted to stratified/clustered
  `survey_taylor` only).

- [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  SRS fallback downgraded from warning to message.

### Internal infrastructure

- `.build_cluster_matrices()` extracts multi-stage cluster, strata, and
  FPC matrix construction into a shared helper, used across the Taylor
  variance engine, analysis cell estimators, and GLM sandwich variance.

## surveycore 0.5.0

### Breaking changes

- [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
  replaces `as_survey_repweights()`. The constructor name now matches
  the underlying `survey_replicate` class.

- `survey_nonprob` and
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
  replace `survey_calibrated` and `as_survey_calibrated()`. “Calibrated”
  implies a post-processing step on a probability sample; `nonprob`
  accurately reflects the design type.

- `survey_srs` and `as_survey_srs()` have been removed. SRS designs are
  now created via
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  with no `ids` or `strata` — this produces a `survey_taylor` with no
  cluster/strata structure. All estimates are numerically identical.
  Print output now says “Taylor series linearization” instead of “simple
  random sample”.

- Single-row data frames are now rejected at construction time
  (previously a warning). This matches
  [`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html)
  behavior.

- The positional setter form `set_var_label(svy, age, "label")` has been
  removed. Use the named form `set_var_label(svy, age = "label")`
  instead.

- [`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
  [`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
  and
  [`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md)
  now return a named character vector. `extract_var_label(svy, age)` now
  returns `c(age = "Age in years")` rather than `"Age in years"`.

- [`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
  now returns a named list. `extract_val_labels(svy, sex)` now returns
  `list(sex = c(Male = 1L, Female = 2L))` rather than
  `c(Male = 1L, Female = 2L)`.

- `set_variable_labels()`, `set_value_labels()`,
  `set_question_prefaces()`, and `set_variable_notes()` have been
  removed. Use
  [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
  [`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
  and
  [`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md)
  respectively — all four now accept multiple variables via named `...`.

### New features

- [`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md)
  and
  [`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md)
  set and retrieve universe (eligibility) annotations for survey
  variables.

- [`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md)
  and
  [`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md)
  set and retrieve missing value code vectors for survey variables.

- [`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md)
  returns all metadata fields (`variable_label`, `value_labels`,
  `question_preface`, `note`, `universe`, `missing_codes`,
  `transformations`) for one or more variables as a named list.

### Enhancements

- All setter functions now support three call conventions: named `...`
  (e.g., `set_var_label(svy, age = "Age in years")`), a single named
  vector/list in `...`, or explicit `variable =` / content-argument
  pairs. All setters also now work on plain `data.frame`s.

- All extractor functions accept multiple variables via `...`, support
  three output formats (`"named_vector"`, `"list"`, `"data_frame"`), and
  accept a `fill` argument to include variables with no metadata in the
  output.

## surveycore 0.4.0

### New features

- [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  fits survey-weighted generalized linear models for all four design
  classes (`survey_taylor`, `survey_replicate`, `survey_twophase`,
  `survey_nonprob`); returns a `survey_glm_fit` object with design-based
  (Binder 1983 sandwich) standard errors and degrees of freedom.

- [`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md)
  converts a `survey_glm_fit` to a tidy `survey_glm_tidy` tibble with
  one row per coefficient, design-based confidence intervals, structured
  metadata, and optional reference rows for factor predictors.

- `survey_glm_fit` objects support 20 S3 methods:
  [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`vcov()`](https://rdrr.io/r/stats/vcov.html),
  [`predict()`](https://rdrr.io/r/stats/predict.html),
  [`fitted()`](https://rdrr.io/r/stats/fitted.values.html),
  [`residuals()`](https://rdrr.io/r/stats/residuals.html),
  [`confint()`](https://rdrr.io/r/stats/confint.html),
  [`formula()`](https://rdrr.io/r/stats/formula.html),
  [`terms()`](https://rdrr.io/r/stats/terms.html),
  [`model.matrix()`](https://rdrr.io/r/stats/model.matrix.html),
  [`model.frame()`](https://rdrr.io/r/stats/model.frame.html),
  [`deviance()`](https://rdrr.io/r/stats/deviance.html),
  [`df.residual()`](https://rdrr.io/r/stats/df.residual.html),
  [`nobs()`](https://rdrr.io/r/stats/nobs.html),
  [`hatvalues()`](https://rdrr.io/r/stats/influence.measures.html),
  [`logLik()`](https://rdrr.io/r/stats/logLik.html),
  [`AIC()`](https://rdrr.io/r/stats/AIC.html),
  [`BIC()`](https://rdrr.io/r/stats/AIC.html), and
  [`update()`](https://rdrr.io/r/stats/update.html).

- `survey_glm_fit` integrates with the `marginaleffects` package; when
  `marginaleffects` is installed,
  [`avg_slopes()`](https://rdrr.io/pkg/marginaleffects/man/slopes.html),
  [`avg_predictions()`](https://rdrr.io/pkg/marginaleffects/man/predictions.html),
  and the full marginaleffects API work directly on `survey_glm_fit`
  objects.

- [`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) is
  supported for `survey_glm_fit` objects via a shim that delegates to
  [`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md).

- `as_survey_rep()` has been renamed to
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
  to avoid a namespace clash with the `srvyr` package.

### Bug fixes

- [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
  variance estimation (`method = "approx"` and `"full"`) now uses the
  correct PSU-level Phase 2 stratum sampling fraction instead of a
  row-level fraction, resolving an approximately 2× variance
  underestimation.

## surveycore 0.3.3

### New features

- [`print()`](https://rdrr.io/r/base/print.html) methods for all four
  survey design classes (`survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`) now display a
  `Domain: <n> of <N> rows` line when `surveytidy::filter()` has been
  applied. The line appears after the sample size line and before the
  `Groups:` line. For two-phase designs, domain counts reflect Phase 2
  rows only.

## surveycore 0.3.0

### New features

- [`names()`](https://rdrr.io/r/base/names.html) now works on survey
  design objects, returning the column names of the underlying data
  frame. This enables IDE column-name autocomplete in RStudio and
  Positron when piping into analysis functions (e.g.,
  `design |> get_means(`).

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
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
  and
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
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

- [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
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
  `set_variable_labels()`,
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
  `set_value_labels()`,
  [`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
  `set_question_prefaces()`,
  [`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
  `set_variable_notes()`. Single-variable setters automatically import
  haven `"label"` / `"labels"` attributes from the data frame column.

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
