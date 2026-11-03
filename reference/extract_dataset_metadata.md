# Extract Dataset-Level Metadata

Returns whole-dataset metadata — the survey name, the display name, the
fielding vendor, and the field dates — from a survey design object or a
data frame.

## Usage

``` r
extract_dataset_metadata(x, ..., key = NULL, format = "list", fill = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  Keys to return, as bare names (`vendor`) or strings (`"vendor"`).
  Supports `!!!` splicing of a character vector of names. Matching is by
  plain name and is **not** tidy-select: a key is not a column, so
  selection helpers such as `all_of()` are rejected. Repeated requests
  are deduplicated, keeping the first position. If empty, returns every
  key that is set.

- key:

  `character` vector of key names, or `NULL` (default). A programmatic
  alternative to `...`; supplying both is an error. Must be supplied by
  name, because it follows `...`.

- format:

  `character(1)`. Output shape: `"list"` (default) or `"data_frame"`.
  Must be supplied by name, because it follows `...`.

- fill:

  `NULL` (default), `NA`, or `NA_character_`. Has two effects. For keys
  named in `...` or `key` that are not set: `NULL` omits them, while
  `NA` and `NA_character_` include them with a missing value. With an
  empty request, a non-`NULL` `fill` returns the full six-key schema
  with every absent key filled — the codebook idiom. Must be supplied by
  name, because it follows `...`.

## Value

- `"list"` (default): named list of the stored values, in request order,
  or canonical key order for an empty request. Date keys are `Date(1)`.
  A filled absent key is type-matched: `as.Date(NA)` for `field_start`
  and `field_end`, `NA_character_` for the four character keys. Empty
  result: [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: tibble with columns `key` and `value`, both character.
  A `Date` renders through
  [`format()`](https://rdrr.io/r/base/format.html) as `YYYY-MM-DD`, and
  a filled absent key is always `NA_character_` regardless of its type.
  Empty result: zero-row tibble with both columns.

## Details

The key vocabulary is closed. Exactly six keys are valid, and this is
their canonical order:

- `survey_name`:

  `character(1)`. Full formal survey name.

- `data_name`:

  `character(1)`. Display label for this dataset.

- `vendor`:

  `character(1)`. Fielding vendor.

- `field_start`:

  `Date(1)`. First day in the field.

- `field_end`:

  `Date(1)`. Last day in the field.

- `field_period`:

  `character(1)`. Prose field period, for display.

`survey_name` and `data_name` are independent. This function never reads
one to compute the other, and it never composes a label from the field
dates.

On a survey design object the stored metadata is the single source of
truth; attributes on the underlying data frame are not consulted. On a
data frame the six attribute names above are read directly, plus the
pre-1.2.0 name `dates`, which is read as `field_period` when no
`field_period` attribute is present. Any other attribute is ignored. An
attribute whose value fails the type rules above is dropped silently —
this function never warns.

A design object restored from a file written by surveycore 1.1.0 or
earlier reports no dataset metadata rather than failing.

[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md)
is deliberately separate: it reports per-variable fields only, and a
dataset-level key is not a variable.

Each key also has a convenience extractor that returns one scalar:
[`extract_survey_name()`](https://jdenn0514.github.io/surveycore/reference/extract_survey_name.md),
[`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
[`extract_vendor()`](https://jdenn0514.github.io/surveycore/reference/extract_vendor.md),
[`extract_field_dates()`](https://jdenn0514.github.io/surveycore/reference/extract_field_dates.md),
and
[`extract_field_period()`](https://jdenn0514.github.io/surveycore/reference/extract_field_period.md).

## See also

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_data_name()`](https://jdenn0514.github.io/surveycore/reference/extract_data_name.md),
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
[`extract_var_extra()`](https://jdenn0514.github.io/surveycore/reference/extract_var_extra.md),
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
# On a data frame, dataset metadata lives in whole-object attributes.
df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
attr(df, "survey_name") <- "Example Attitudes Survey 2026"
attr(df, "vendor") <- "Ipsos KnowledgePanel"
attr(df, "field_start") <- as.Date("2026-02-10")
attr(df, "field_end") <- as.Date("2026-03-04")

extract_dataset_metadata(df)
#> $survey_name
#> [1] "Example Attitudes Survey 2026"
#> 
#> $vendor
#> [1] "Ipsos KnowledgePanel"
#> 
#> $field_start
#> [1] "2026-02-10"
#> 
#> $field_end
#> [1] "2026-03-04"
#> 
extract_dataset_metadata(df, vendor)
#> $vendor
#> [1] "Ipsos KnowledgePanel"
#> 
extract_dataset_metadata(df, key = c("field_start", "field_end"))
#> $field_start
#> [1] "2026-02-10"
#> 
#> $field_end
#> [1] "2026-03-04"
#> 
extract_dataset_metadata(df, format = "data_frame")
#> # A tibble: 4 × 2
#>   key         value                        
#>   <chr>       <chr>                        
#> 1 survey_name Example Attitudes Survey 2026
#> 2 vendor      Ipsos KnowledgePanel         
#> 3 field_start 2026-02-10                   
#> 4 field_end   2026-03-04                   

# An unset key is omitted by default, or filled on request.
extract_dataset_metadata(df, data_name)
#> list()
extract_dataset_metadata(df, data_name, fill = NA)
#> $data_name
#> [1] NA
#> 

# A non-NULL fill plus an empty request gives the whole six-key schema.
extract_dataset_metadata(df, fill = NA, format = "data_frame")
#> # A tibble: 6 × 2
#>   key          value                        
#>   <chr>        <chr>                        
#> 1 survey_name  Example Attitudes Survey 2026
#> 2 data_name    NA                           
#> 3 vendor       Ipsos KnowledgePanel         
#> 4 field_start  2026-02-10                   
#> 5 field_end    2026-03-04                   
#> 6 field_period NA                           
```
