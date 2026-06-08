# Extract Missing Value Codes

Returns missing value sentinel codes for one or more variables in a
survey design object or data frame.

## Usage

``` r
extract_missing_codes(x, ..., format = "list", fill = NULL)
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

  Scalar or `NULL`. How to handle variables with no codes: `NULL`
  (default) omits them; `NA_character_` includes them as `NULL` entries
  in `"list"` format. In `"data_frame"` format, variables with no codes
  are always excluded regardless of `fill`.

## Value

- `"list"` (default): named list of atomic vectors. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: long-format tibble with columns `variable`,
  `description` (`NA` if codes vector is unnamed), `code` (coerced to
  character). Empty: zero-row tibble.

## See also

[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md)
to set missing value codes

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
d <- set_missing_codes(d, ridageyr = c("Not applicable" = 999L))
extract_missing_codes(d, ridageyr)
#> $ridageyr
#> Not applicable 
#>            999 
#> 
extract_missing_codes(d, ridageyr, format = "data_frame")
#> # A tibble: 1 × 3
#>   variable description    code 
#>   <chr>    <chr>          <chr>
#> 1 ridageyr Not applicable 999  
```
