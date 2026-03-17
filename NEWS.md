# surveycore 0.5.0.9000 (development)

## New features

* Infrastructure for `get_diffs()`: `.stars_pval()` internal helper for
  significance star annotations, `DIFFS_META_KEYS` constant,
  `print.survey_diffs()` method with design/family/treatment header, and
  `exclude` parameter on `.apply_name_style()` for column-rename control.
  Nine new error/warning classes registered in the error message table
  (rows 92--100).

# surveycore 0.5.0

## Breaking changes

* `as_survey_replicate()` replaces `as_survey_repweights()`. The constructor
  name now matches the underlying `survey_replicate` class.

* `survey_nonprob` and `as_survey_nonprob()` replace `survey_calibrated` and
  `as_survey_calibrated()`. "Calibrated" implies a post-processing step on a
  probability sample; `nonprob` accurately reflects the design type.

* `survey_srs` and `as_survey_srs()` have been removed. SRS designs are now
  created via `as_survey()` with no `ids` or `strata` — this produces a
  `survey_taylor` with no cluster/strata structure. All estimates are
  numerically identical. Print output now says "Taylor series linearization"
  instead of "simple random sample".

* Single-row data frames are now rejected at construction time (previously
  a warning). This matches `survey::svydesign()` behavior.

* The positional setter form `set_var_label(svy, age, "label")` has been
  removed. Use the named form `set_var_label(svy, age = "label")` instead.

* `extract_var_label()`, `extract_question_preface()`, and `extract_var_note()`
  now return a named character vector. `extract_var_label(svy, age)` now
  returns `c(age = "Age in years")` rather than `"Age in years"`.

* `extract_val_labels()` now returns a named list. `extract_val_labels(svy, sex)`
  now returns `list(sex = c(Male = 1L, Female = 2L))` rather than
  `c(Male = 1L, Female = 2L)`.

* `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, and
  `set_variable_notes()` have been removed. Use `set_var_label()`,
  `set_val_labels()`, `set_question_preface()`, and `set_var_note()`
  respectively — all four now accept multiple variables via named `...`.

## New features

* `set_universe()` and `extract_universe()` set and retrieve universe
  (eligibility) annotations for survey variables.

* `set_missing_codes()` and `extract_missing_codes()` set and retrieve missing
  value code vectors for survey variables.

* `extract_metadata()` returns all metadata fields (`variable_label`,
  `value_labels`, `question_preface`, `note`, `universe`, `missing_codes`,
  `transformations`) for one or more variables as a named list.

## Enhancements

* All setter functions now support three call conventions: named `...`
  (e.g., `set_var_label(svy, age = "Age in years")`), a single named
  vector/list in `...`, or explicit `variable =` / content-argument pairs.
  All setters also now work on plain `data.frame`s.

* All extractor functions accept multiple variables via `...`, support three
  output formats (`"named_vector"`, `"list"`, `"data_frame"`), and accept a
  `fill` argument to include variables with no metadata in the output.

# surveycore 0.4.0

## New features

* `survey_glm()` fits survey-weighted generalized linear models for all four
  design classes (`survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`); returns a `survey_glm_fit` object
  with design-based (Binder 1983 sandwich) standard errors and degrees of
  freedom.

* `clean()` converts a `survey_glm_fit` to a tidy `survey_glm_tidy` tibble
  with one row per coefficient, design-based confidence intervals, structured
  metadata, and optional reference rows for factor predictors.

* `survey_glm_fit` objects support 20 S3 methods: `print()`, `summary()`,
  `coef()`, `vcov()`, `predict()`, `fitted()`, `residuals()`, `confint()`,
  `formula()`, `terms()`, `model.matrix()`, `model.frame()`, `deviance()`,
  `df.residual()`, `nobs()`, `hatvalues()`, `logLik()`, `AIC()`, `BIC()`, and
  `update()`.

* `survey_glm_fit` integrates with the `marginaleffects` package; when
  `marginaleffects` is installed, `avg_slopes()`, `avg_predictions()`, and the
  full marginaleffects API work directly on `survey_glm_fit` objects.

* `broom::tidy()` is supported for `survey_glm_fit` objects via a shim that
  delegates to `clean()`.

* `as_survey_rep()` has been renamed to `as_survey_replicate()` to avoid a
  namespace clash with the `srvyr` package.

## Bug fixes

* `as_survey_twophase()` variance estimation (`method = "approx"` and
  `"full"`) now uses the correct PSU-level Phase 2 stratum sampling fraction
  instead of a row-level fraction, resolving an approximately 2× variance
  underestimation.

# surveycore 0.3.3

## New features

* `print()` methods for all four survey design classes (`survey_taylor`,
  `survey_replicate`, `survey_twophase`, `survey_nonprob`)
  now display a `Domain: <n> of <N> rows` line when `surveytidy::filter()`
  has been applied. The line appears after the sample size line and before
  the `Groups:` line. For two-phase designs, domain counts reflect Phase 2
  rows only.

# surveycore 0.3.0

## New features

* `names()` now works on survey design objects, returning the column names of
  the underlying data frame. This enables IDE column-name autocomplete in
  RStudio and Positron when piping into analysis functions (e.g.,
  `design |> get_means(`).

# surveycore 0.2.0

## New features

* `get_freqs()` computes weighted frequency tables for categorical survey
  variables across all five design types, with domain estimation, value-label
  support, and AAPOR small-cell warnings.

* `get_means()` returns survey-weighted means with design-correct standard
  errors for all five design types, including grouped and domain estimation.

* `get_totals()` returns survey-weighted population totals (and population
  size when called without `x`) for all five design types.

* `get_corr()` computes survey-weighted Pearson correlation using the
  delta-method variance approach, with optional `group` parameter for
  per-group correlations and Fisher Z confidence intervals.

* `get_quantiles()` estimates survey-weighted quantiles using the Woodruff
  (1952) linearization method; supports multiple `probs` in a single call and
  five CI interval methods.

* `get_ratios()` estimates survey-weighted ratios (numerator total /
  denominator total) with design-correct SEs via the delta method (Taylor,
  SRS, calibrated, two-phase) or direct per-replicate computation (replicate
  designs).

* All six analysis functions gain a `decimals` argument to round numeric
  output columns to a fixed number of decimal places.

* `na.rm = FALSE` now includes rows where a grouping variable is `NA` as a
  separate group row in all six analysis functions' output.

* `infer_question_prefaces()` auto-detects shared battery prefaces from
  variable labels using separator-based and longest-common-prefix detection.

* `survey_weighting_history()` returns the weighting history stored in a
  survey design object's metadata; `as_survey()`, `as_survey_replicate()`, and
  `as_survey_nonprob()` now promote `"weighting_history"` attributes from the
  input data frame automatically.

* Two-phase variance estimation (`as_survey_twophase()`) is now fully
  supported in `get_means()` and `get_totals()`, using the `"full"`,
  `"approx"`, and `"simple"` methods vendored from the `survey` package.

## Bug fixes

* `get_freqs()` no longer crashes when the `group` variable contains `NA`
  values.

* `get_freqs()` now outputs `pct` as a proportion (0–1) rather than a
  percentage (0–100); `se` and `se_srs` are on the same scale.

# surveycore 0.1.0

## New features

* `as_survey()` creates `survey_taylor` objects with a tidy-select interface
  (`ids`, `weights`, `strata`, `fpc`, `probs`); supports Taylor linearization
  for stratified, clustered, and SRS designs.

* `as_survey_replicate()` creates `survey_replicate` objects; supports BRR, Fay BRR,
  JK1, JK2, JKn, bootstrap, ACS, and successive-difference replicate schemes.

* `as_survey_twophase()` creates `survey_twophase` objects; supports "full",
  "approx", and "simple" two-phase variance estimation methods.

* `update_design()` modifies design variables on an existing survey object
  without reconstructing from scratch; respects `validate = TRUE/FALSE`.

* `get_means()` returns a weighted mean and standard error via Taylor
  linearization or replicate weights; respects
  `getOption("survey.lonely.psu")` for single-PSU strata.

* `get_totals()` returns a weighted total and standard error using the same
  dispatch as `get_means()`.

* Metadata setters: `set_var_label()`, `set_variable_labels()`,
  `set_val_labels()`, `set_value_labels()`, `set_question_preface()`,
  `set_question_prefaces()`, `set_var_note()`, `set_variable_notes()`.
  Single-variable setters automatically import haven `"label"` / `"labels"`
  attributes from the data frame column.

* Metadata extractors: `extract_var_label()`, `extract_val_labels()`,
  `extract_question_preface()`, `extract_var_note()`.

* Conversion utilities: `as_svydesign()`, `from_svydesign()`, `as_tbl_svy()`,
  `from_tbl_svy()` — round-trip conversion between surveycore objects,
  `survey::svydesign` / `survey::svrepdesign`, and `srvyr::tbl_svy`.

* `print()` and `summary()` S7 methods for all survey design classes display
  design type, sample size, and a tibble-style data preview.

## Internal infrastructure

* S7 class hierarchy: abstract `survey_base` → `survey_taylor`,
  `survey_replicate`, `survey_twophase`; `survey_metadata` for label storage.

* Three-layer validation: S7 structural validators, Layer 2 input validators,
  Layer 3 constructor validators; all errors use typed `class=` for
  programmatic handling.

* Variance estimation vendored from the `survey` package (Thomas Lumley,
  GPL-2/GPL-3) — see `VENDORED.md` for full attribution.
