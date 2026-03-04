# surveycore 0.3.3

## New features

* `print()` methods for all five survey design classes (`survey_taylor`,
  `survey_srs`, `survey_replicate`, `survey_twophase`, `survey_calibrated`)
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
  survey design object's metadata; `as_survey()`, `as_survey_rep()`, and
  `as_survey_srs()` now promote `"weighting_history"` attributes from the
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

* `as_survey_rep()` creates `survey_replicate` objects; supports BRR, Fay BRR,
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
