# Set Reverse-Coded Flag

Marks one or more variables as reverse-coded in a survey design object
or data frame. Uses the same two-convention pattern as
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md).

## Usage

``` r
set_reverse_coded(x, ..., variable = NULL, reverse_coded = TRUE)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to mark. Cannot be combined with `variable`.

- variable:

  `character`. Alternative programmatic interface: character vector of
  variable names. Cannot be combined with `...`.

- reverse_coded:

  `logical(1)`. `TRUE` (default) marks variables as reverse-coded;
  `FALSE` removes the flag. `NA` is not accepted.

## Value

The modified object, invisibly.

## Details

**Convention A (tidy-select `...`)** — recommended:

    design |> set_reverse_coded(anxiety, worry)

**Convention B (`variable` = character vector)** — programmatic:

    vars <- c("anxiety", "worry")
    design |> set_reverse_coded(variable = vars)

Setting `reverse_coded = FALSE` removes the flag.

## See also

[`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md)
to retrieve reverse-coded flags

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
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
d <- set_reverse_coded(d, bpxsy1, ridageyr)
d <- set_reverse_coded(d, bpxsy1, reverse_coded = FALSE)
```
