# Set Universe Description(s)

Sets the universe description for one or more variables. The universe
describes the population to which a variable applies (e.g.,
`"Adults 18+"`).

## Usage

``` r
set_universe(x, ..., variable = NULL, universe = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is the
  universe description string. Supports `!!!` list splicing.

- variable:

  A character vector of variable names. Use with `universe`.

- universe:

  A character vector of universe description strings, one per element of
  `variable`.

## Value

The modified object, invisibly.

## Details

Supports Conventions 1, 2, and 3 — see
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
for details.

## See also

Other metadata:
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)
