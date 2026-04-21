# Extract Value Labels

Returns value labels for one or more variables in a survey design object
or data frame.

## Usage

``` r
extract_val_labels(x, ..., format = "list", fill = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to query. Supports selection helpers:
  [`tidyselect::starts_with()`](https://tidyselect.r-lib.org/reference/starts_with.html),
  [`tidyselect::all_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  [`tidyselect::matches()`](https://tidyselect.r-lib.org/reference/starts_with.html),
  etc. If empty, returns metadata for all variables. Use
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html)
  to silently skip missing variable names.

- format:

  `character(1)`. Output format: `"list"` (default) or `"data_frame"`.
  `"named_vector"` is not valid for this function.

- fill:

  Scalar or `NULL`. How to handle variables with no labels: `NULL`
  (default) omits them; `NA_character_` includes them as `NULL` entries
  in `"list"` format.

## Value

- `"list"` (default): named list of named vectors. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: long-format tibble with columns `variable`, `label`,
  `value` (codes coerced to character). Empty: zero-row tibble.

## See also

[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
to set value labels

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
extract_val_labels(d, riagendr)
#> named list()
extract_val_labels(d, riagendr, format = "data_frame")
#> # A tibble: 0 × 3
#> # ℹ 3 variables: variable <chr>, label <chr>, value <chr>
```
