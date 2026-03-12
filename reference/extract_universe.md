# Extract Universe Descriptions

Returns universe (eligibility) descriptions for one or more variables in
a survey design object or data frame.

## Usage

``` r
extract_universe(x, ..., format = "named_vector", fill = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable names (bare, unquoted). If empty, metadata for all variables
  is returned.

- format:

  `character(1)`. Output format: `"named_vector"` (default), `"list"`,
  or `"data_frame"`.

- fill:

  Scalar or `NULL`. How to handle variables with no universe: `NULL`
  (default) omits them; `NA_character_` includes them with `NA`.

## Value

- `"named_vector"` (default): named character vector. Empty:
  `character(0)`.

- `"list"`: named list of character scalars. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: tibble with columns `variable` and `universe`. Empty:
  zero-row tibble.

## See also

[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md)
to set a universe description

Other metadata:
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
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
d <- set_universe(d, ridageyr = "All participants 0+")
extract_universe(d)
#>              ridageyr 
#> "All participants 0+" 
extract_universe(d, ridageyr, format = "data_frame")
#> # A tibble: 1 × 2
#>   variable universe           
#>   <chr>    <chr>              
#> 1 ridageyr All participants 0+
```
