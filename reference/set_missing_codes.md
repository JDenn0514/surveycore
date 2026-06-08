# Set Missing Code(s)

Sets missing-value codes for one or more variables. Missing codes are
atomic vectors documenting which data values represent missing data
(e.g., `c(Refused = -2L, DontKnow = -1L)`).

## Usage

``` r
set_missing_codes(x, ..., variable = NULL, codes = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is a
  named atomic vector of missing codes. Supports `!!!` list splicing.

- variable:

  A character vector of variable names. Use with `codes`.

- codes:

  A list of named atomic vectors, one per element of `variable`. When
  `variable` has length 1, a bare named atomic vector is also accepted.

## Value

The modified object, invisibly.

## Details

Supports Conventions 1, 2, and 3 — see
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
for details on the calling conventions. For Convention 3 with a single
variable, a bare named atomic vector is accepted in addition to a list.

## See also

[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md)
to retrieve missing value codes

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
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
d <- set_missing_codes(d, happy = c(Refused = -1L, DK = -2L))
extract_missing_codes(d, happy)
#> $happy
#> Refused      DK 
#>      -1      -2 
#> 
```
