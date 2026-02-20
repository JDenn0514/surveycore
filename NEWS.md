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
