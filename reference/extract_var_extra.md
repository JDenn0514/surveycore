# Extract Extension Slot Payload(s)

Returns the extension-slot payload for one or more variables in a survey
design object or data frame. Read-only; performs no validation of
payload contents — values are returned exactly as stored, never coerced.

## Usage

``` r
extract_var_extra(x, ..., format = "list", fill = NULL)
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
  etc. If empty, returns the payload for every column in `x`. Use
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html)
  to silently skip missing variable names.

- format:

  `character(1)`. Output format: `"list"` (default) or `"data_frame"`.
  `"named_vector"` is not valid for this function (payloads are not
  scalar).

- fill:

  Scalar or `NULL`. How to handle variables with no payload: `NULL`
  (default) omits them; `NA_character_` includes them as `NULL` entries
  in `"list"` format. In `"data_frame"` format, variables with no
  payload are always excluded regardless of `fill`.

## Value

- `"list"` (default): named list. Keys are variable names; values are
  each variable's stored payload, or `NULL` for variables included via
  `fill = NA_character_` with no payload set. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: a tibble with columns `variable` (`character`), `key`
  (`character`), and `value` (a list-column, one raw payload value per
  row, unvalidated and untouched). One row per `(variable, key)` pair; a
  variable whose payload is [`list()`](https://rdrr.io/r/base/list.html)
  or unset contributes zero rows. Empty: a zero-row tibble typed as
  above.

## See also

[`set_var_extra()`](https://jdenn0514.github.io/surveycore/reference/set_var_extra.md)
to set an extension-slot payload

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
[`extract_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_dataset_metadata.md),
[`extract_field_dates()`](https://jdenn0514.github.io/surveycore/reference/extract_field_dates.md),
[`extract_field_period()`](https://jdenn0514.github.io/surveycore/reference/extract_field_period.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_survey_name()`](https://jdenn0514.github.io/surveycore/reference/extract_survey_name.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`extract_vendor()`](https://jdenn0514.github.io/surveycore/reference/extract_vendor.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_data_name()`](https://jdenn0514.github.io/surveycore/reference/set_data_name.md),
[`set_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/set_dataset_metadata.md),
[`set_field_dates()`](https://jdenn0514.github.io/surveycore/reference/set_field_dates.md),
[`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md),
[`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_survey_name()`](https://jdenn0514.github.io/surveycore/reference/set_survey_name.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_extra()`](https://jdenn0514.github.io/surveycore/reference/set_var_extra.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
d <- set_var_extra(d, age = list(role = "demographic"))
extract_var_extra(d, age)
#> $age
#> $age$role
#> [1] "demographic"
#> 
#> 
extract_var_extra(d, age, format = "data_frame")
#> # A tibble: 1 × 3
#>   variable key   value    
#>   <chr>    <chr> <list>   
#> 1 age      role  <chr [1]>
```
