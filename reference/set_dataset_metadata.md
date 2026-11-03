# Set Dataset-Level Metadata

Sets whole-dataset metadata — the survey name, the display name, the
fielding vendor, and the field dates — on a survey design object or a
data frame, using one of three conventions.

## Usage

``` r
set_dataset_metadata(x, ..., key = NULL, value = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  Named arguments where the name is a dataset metadata key and the value
  is the value to store. A single named list is also accepted. Supports
  `!!!` list splicing. A `NULL` value deletes the key.

- key:

  `character` vector of key names, or `NULL` (default). Use with
  `value`. Must be supplied by name, because it follows `...`.

- value:

  A list with one element per element of `key`, or `NULL` (default). An
  atomic vector is coerced with
  [`as.list()`](https://rdrr.io/r/base/list.html). Names on `value` are
  ignored — `key` supplies the names. A `NULL` element deletes that one
  key; `value = NULL` deletes every key in `key` and skips the length
  check. Must be supplied by name, because it follows `...`.

## Value

The modified object, invisibly.

## Details

**Convention 1 (named `...`)** — recommended:

    set_dataset_metadata(x, vendor = "Ipsos", field_start = "2026-02-10")

**Convention 2 (single named list in `...`)**:

    set_dataset_metadata(x, list(vendor = "Ipsos"))

**Convention 3 (`key` + `value`)**:

    set_dataset_metadata(x, key = "vendor", value = "Ipsos")

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

Any other key is an error. The four character keys take one non-`NA`
string. The two date keys take a `Date` scalar or an ISO 8601 string
(`"YYYY-MM-DD"`), which is stored as a `Date`; a looser string such as
`"2026/02/10"` or `"2026-2-1"` is rejected. Stored keys are always kept
in the canonical order above.

`survey_name` and `data_name` are independent. This function never reads
one to fill or check the other.

Each key also has a convenience setter that takes one value:
[`set_survey_name()`](https://jdenn0514.github.io/surveycore/reference/set_survey_name.md),
[`set_data_name()`](https://jdenn0514.github.io/surveycore/reference/set_data_name.md),
[`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md),
[`set_field_dates()`](https://jdenn0514.github.io/surveycore/reference/set_field_dates.md),
and
[`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md).
Use
[`extract_dataset_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_dataset_metadata.md)
to read the keys back.

A `NULL` value deletes a key. Deleting a key that is not set does
nothing and raises no condition. A zero-length value such as
`character(0)` is not a deletion — it is an invalid value.

`field_start` must not be after `field_end`. The comparison uses the
*effective* value of each date: the new value when the call supplies
one, no value when the call supplies `NULL`, and the stored value
otherwise. So one call can repair a reversed stored pair by deleting one
date and setting the other. Every check runs before any write, so a
rejected call changes nothing.

On a survey design object the values go into the design's metadata,
which is the single source of truth on every read path; attributes on
the underlying data frame are neither read nor written. On a data frame
the values go into whole-object attributes, one per key, and the columns
are left untouched — even a column whose name matches a key.

`dates` is the pre-1.2.0 attribute name for the prose field period.
Setting it is an error that points at `field_period` and
[`set_field_period()`](https://jdenn0514.github.io/surveycore/reference/set_field_period.md).
Deleting it is allowed: `dates = NULL` is an alias for
`field_period = NULL`, and either spelling removes both the
`field_period` and the legacy `dates` attribute from a data frame.

A design object restored from a file written by surveycore 1.1.0 or
earlier cannot store dataset metadata. Reading such an object works, but
a write raises an error naming the remedy: rebuild the object with a
constructor.

## Attribute persistence

On a data frame, dataset metadata lives in whole-object attributes, and
those are fragile. Common operations return a new frame without them:

- base `[` when it selects columns, as in `df[, cols]`

- [`merge()`](https://rdrr.io/r/base/merge.html) and
  [`subset()`](https://rdrr.io/r/base/subset.html)

- [`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html),
  which has dropped them in some versions and keeps them in others, so
  neither behavior is safe to rely on

So set dataset metadata **last**, directly before `usethis::use_data()`.
Or set it on the survey design instead: there it lives in the design's
metadata, where no data-frame operation can drop it.

A constructor **copies** these attributes into the design; it never
strips them. The data frame inside a design therefore still carries the
values it was built with. A later
[`set_vendor()`](https://jdenn0514.github.io/surveycore/reference/set_vendor.md)
call, or a deletion, changes the design's metadata only. Rebuilding a
design from the data frame that
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md)
returns re-promotes the original attributes, so an edited or deleted key
comes back. Avoid that round trip and keep working with the design
object.

## See also

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
[`extract_var_extra()`](https://jdenn0514.github.io/surveycore/reference/extract_var_extra.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`extract_vendor()`](https://jdenn0514.github.io/surveycore/reference/extract_vendor.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_data_name()`](https://jdenn0514.github.io/surveycore/reference/set_data_name.md),
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
df <- set_dataset_metadata(
  df,
  survey_name = "Example Attitudes Survey 2026",
  vendor = "Ipsos KnowledgePanel"
)
extract_dataset_metadata(df)
#> $survey_name
#> [1] "Example Attitudes Survey 2026"
#> 
#> $vendor
#> [1] "Ipsos KnowledgePanel"
#> 

# An ISO 8601 string is stored as a Date.
df <- set_dataset_metadata(df, field_start = "2026-02-10")
extract_dataset_metadata(df, field_start)
#> $field_start
#> [1] "2026-02-10"
#> 

# Convention 2: one named list.
df <- set_dataset_metadata(df, list(field_end = "2026-03-04"))

# Convention 3: key plus value.
df <- set_dataset_metadata(
  df,
  key = c("data_name", "field_period"),
  value = list("Example (February-March 2026)", "February-March 2026")
)
extract_dataset_metadata(df, format = "data_frame")
#> # A tibble: 6 × 2
#>   key          value                        
#>   <chr>        <chr>                        
#> 1 survey_name  Example Attitudes Survey 2026
#> 2 data_name    Example (February-March 2026)
#> 3 vendor       Ipsos KnowledgePanel         
#> 4 field_start  2026-02-10                   
#> 5 field_end    2026-03-04                   
#> 6 field_period February-March 2026          

# A NULL value deletes a key.
df <- set_dataset_metadata(df, vendor = NULL)
extract_dataset_metadata(df, vendor, fill = NA)
#> $vendor
#> [1] NA
#> 

# The same API works on a survey design object.
d <- as_survey(df, weights = w)
d <- set_dataset_metadata(d, vendor = "Cint")
extract_dataset_metadata(d, vendor)
#> $vendor
#> [1] "Cint"
#> 
```
