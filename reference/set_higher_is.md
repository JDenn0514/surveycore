# Set Direction-of-Improvement Attribute

Records whether a higher value is better (`"better"`) or worse
(`"worse"`) for one or more variables in a survey design object or data
frame. This metadata is used by
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)
when `show_favorability = TRUE`.

## Usage

``` r
set_higher_is(x, ..., variable = NULL, direction = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  Named arguments where the name is the variable and the value is the
  direction (`"better"` or `"worse"`). Supports Convention 1 (named
  args: `bpxsy1 = "worse"`) and Convention 2 (named character vector:
  `c(bpxsy1 = "worse", lbxtc = "better")`). Mutually exclusive with
  `variable`.

- variable:

  `character`. Variable name(s) — Convention 3 alternative to `...`.
  Mutually exclusive with `...`.

- direction:

  `character`. Direction value(s) for Convention 3. Must be `"better"`,
  `"worse"`, or `NULL` (to remove the attribute). Same length as
  `variable`, or `NULL` to remove.

## Value

The modified object, invisibly.

## See also

[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md)
to retrieve direction attributes

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
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
d <- set_higher_is(d, bpxsy1 = "worse")
extract_higher_is(d, bpxsy1)
#>  bpxsy1 
#> "worse" 
```
