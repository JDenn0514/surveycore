# Set Value Labels

Sets value labels for one or more variables using one of three
conventions.

## Usage

``` r
set_val_labels(x, ..., variable = NULL, labels = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is a
  fully named vector of value labels. Supports `!!!` list splicing.

- variable:

  A character vector of variable names.

- labels:

  A list of named vectors, one per element of `variable`. When
  `variable` has length 1, a bare named vector is also accepted.

## Value

The modified object, invisibly.

## Details

**Convention 1 (named `...`)** — recommended:

    set_val_labels(x, sex = c(Male = 1L, Female = 2L))

**Convention 2 (single named list in `...`)**:

    set_val_labels(x, list(sex = c(Male = 1L, Female = 2L)))

**Convention 3 (`variable` + `labels`)**:

    set_val_labels(x, variable = "sex", labels = c(Male = 1L, Female = 2L))

## See also

[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
to retrieve value labels

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
d <- set_val_labels(d, riagendr = c(Male = 1L, Female = 2L))
```
