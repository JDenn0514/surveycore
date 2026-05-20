# Extract Question Prefaces

Returns question preface text for one or more variables in a survey
design object or data frame.

## Usage

``` r
extract_question_preface(x, ..., format = "named_vector", fill = NULL)
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

  `character(1)`. Output format: `"named_vector"` (default), `"list"`,
  or `"data_frame"`.

- fill:

  Scalar or `NULL`. How to handle variables with no preface: `NULL`
  (default) omits them; `NA_character_` includes them with `NA`.

## Value

- `"named_vector"` (default): named character vector. Empty:
  `character(0)`.

- `"list"`: named list of character scalars. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: tibble with columns `variable` and `preface`. Empty:
  zero-row tibble.

## See also

[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md)
to set a question preface

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
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
d <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
               strata = vstrat, nest = TRUE)
d <- set_question_preface(d, happy = "Taken all together...")
extract_question_preface(d, happy)
#>                   happy 
#> "Taken all together..." 
```
