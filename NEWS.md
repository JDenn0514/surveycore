# surveycore (development version)

## Phase 0 — Core Infrastructure

### New features

**Survey design constructors**

- `as_survey()` — create `survey_taylor` objects with tidy-select interface
  (`ids`, `weights`, `strata`, `fpc`, `probs`); supports Taylor linearization
  for stratified, clustered, and SRS designs
- `as_survey_rep()` — create `survey_replicate` objects with `repweights`
  tidy-select; supports BRR, Fay BRR, JK1, JK2, JKn, bootstrap, ACS, and
  successive-difference replicate schemes
- `as_survey_twophase()` — create `survey_twophase` objects; supports
  "full", "approx", and "simple" two-phase variance estimation methods
- `update_design()` — modify design variables on an existing survey object
  without reconstructing from scratch; respects `validate = TRUE/FALSE`

**Variance estimation**

- `get_means()` — weighted mean and standard error via Taylor linearization
  or replicate weights; respects `getOption("survey.lonely.psu")` for
  single-PSU strata
- `get_totals()` — weighted total and standard error; same dispatch

**Metadata system**

- `set_var_label()` / `set_variable_labels()` — assign variable labels
  (single or bulk); automatically imports haven `"label"` attributes on load
- `set_val_labels()` / `set_value_labels()` — assign value labels
  (single or bulk); automatically imports haven `"labels"` attributes
- `set_question_preface()` / `set_question_prefaces()` — assign question
  preface text (single or bulk)
- `set_var_note()` / `set_variable_notes()` — assign variable notes
  (single or bulk)
- `extract_var_label()`, `extract_val_labels()`, `extract_question_preface()`,
  `extract_var_note()` — retrieve metadata for a single variable

**Conversion utilities**

- `as_svydesign()` — convert `survey_taylor`, `survey_replicate`, or
  `survey_twophase` to `survey::svydesign` / `survey::svrepdesign`
- `from_svydesign()` — convert a `survey::svydesign` or `survey::svrepdesign`
  back to a surveycore object
- `as_tbl_svy()` — convert to `srvyr::tbl_svy`
- `from_tbl_svy()` — convert from `srvyr::tbl_svy`

**Print and summary**

- `print()` / `summary()` S7 methods for `survey_taylor`, `survey_replicate`,
  and `survey_twophase`; display design type, sample size, and a tibble-style
  data preview

### Internal infrastructure

- S7 class hierarchy: abstract `survey_base` → `survey_taylor`,
  `survey_replicate`, `survey_twophase`; `survey_metadata` for label storage
- Variance estimation vendored from the `survey` package (Thomas Lumley,
  GPL-2/GPL-3) — see `VENDORED.md` for attribution
- Three-layer validation: S7 structural validator, Layer 2 input validators,
  Layer 3 constructor validators; all errors use typed `class=` for programmatic
  handling
