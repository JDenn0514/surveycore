# Design Plan: Dataset-Level Metadata

**Status:** Proposed. Not started.
**Target version:** surveycore 1.2.0 (minor bump — see section 8)
**Scope:** One feature branch off `develop`. Touches `R/core-classes.R`,
`R/core-metadata.R`, `R/utils.R`, `R/methods-print.R`, `NAMESPACE`,
`_pkgdown.yml`, tests, and one vignette.

---

## 1. Problem statement

The `survey_metadata` class stores metadata for variables only. It stores
nothing about the dataset as a whole.

### Evidence from the source

`survey_metadata` is defined at `R/core-classes.R:77-129`. It declares 11
properties. Every one is an `S7::class_list` with `default = quote(list())`:

| Property | Line |
|---|---|
| `variable_labels` | `R/core-classes.R:80` |
| `value_labels` | `R/core-classes.R:84` |
| `question_prefaces` | `R/core-classes.R:88` |
| `notes` | `R/core-classes.R:92` |
| `universe` | `R/core-classes.R:96` |
| `missing_codes` | `R/core-classes.R:100` |
| `sata` | `R/core-classes.R:104` |
| `higher_is` | `R/core-classes.R:108` |
| `reverse_coded` | `R/core-classes.R:112` |
| `transformations` | `R/core-classes.R:116` |
| `weighting_history` | `R/core-classes.R:124` |

The roxygen block at `R/core-classes.R:28-59` documents each one as "A named
list mapping variable names to ...". Ten of the eleven are keyed by variable
name. Only `weighting_history` is not keyed by variable name, and it records
weighting operations, not dataset identity.

The class has **no validator**. `S7::new_class()` at `R/core-classes.R:77`
receives only a `properties` argument.

### Consequence for the companion data package

The `adldata` package ships 39 datasets. Each dataset is a tibble. Several
carry dataset-level information as raw whole-object attributes:

- `attr(aaa_ipsos, "data_name") <- "AAA Ipsos (February-March 2026)"` —
  `adldata/data-raw/aaa/aaa_ipsos/aaa_ipsos.R:1302-1305`
- `attr(aaa_ipsos, "vendor") <- "Ipsos KnowledgePanel Omnibus"` —
  `adldata/data-raw/aaa/aaa_ipsos/aaa_ipsos.R:1307`
- `attr(ny_buffer_zones, "data_name") <- "NY Buffer Zones Survey (Feb 2026)"` —
  `adldata/data-raw/ny_buffer_zones/ny_buffer_zones.R:715`
- `attr(ny_buffer_zones, "vendor") <- "GrowProgress"` —
  `adldata/data-raw/ny_buffer_zones/ny_buffer_zones.R:716`
- `attr(cpost, "dates") <- "April-May 2024"` —
  `adldata/data-raw/cpost/cpost.R:316`

Vendor values in use include Ipsos, Cint, Prolific, Grow Progress, and Burson.
See `adldata/data-raw/epstein_class/epstein_class.R:453` and
`adldata/data-raw/jrp/jrp_bsg.R:1235`.

Field dates appear in exactly one script as a separate attribute
(`adldata/data-raw/cpost/cpost.R:316`). In every other script the field period
sits inside the `data_name` string, for example "(February-March 2026)".

I measured the 39 shipped `.rda` objects by running R against
`adldata/data/`. The counts are:

| Attribute | Datasets that set it |
|---|---|
| `data_name` | 13 |
| `vendor` | 10 |
| `dates` | 1 |
| `survey_name` | 0 |

Two facts follow from that measurement.

1. No dataset carries a formal survey name today. The field is new.
2. The `data_name` strings hold a short display label plus a prose period, for
   example "AAA Ipsos (February-March 2026)"
   (`adldata/data-raw/aaa/aaa_ipsos/aaa_ipsos.R:1305`) and "NY Buffer Zones
   Survey (Feb 2026)" (`adldata/data-raw/ny_buffer_zones/ny_buffer_zones.R:715`).
   They do not hold the full formal survey name.

### What breaks today

`as_survey()` reads per-column attributes only. `.extract_haven_metadata()`
(`R/core-metadata.R:2511-2595`) loops over `names(data)` at
`R/core-metadata.R:2519` and reads six per-column attributes: `label`,
`labels`, `question_preface`, `note`, `universe`, and `missing_codes`. It never
reads an attribute of the data frame itself.

I verified the behavior by running R against installed surveycore 1.1.0:

- A data frame that carries `attr(df, "data_name")` keeps that attribute inside
  `@data` after `as_survey()`. The attribute survives only because S7 stores
  the data frame unchanged.
- No exported function reads it. `extract_metadata()`
  (`R/core-metadata.R:891-966`) returns seven per-variable fields and nothing
  else.
- The print methods never show it. See section 7.

So the information is present but invisible, unvalidated, and undocumented. Any
operation that rebuilds `@data` can drop it without notice.

### The one existing precedent

`.promote_weighting_history()` (`R/utils.R:351-357`) already hoists one
whole-data-frame attribute into a metadata slot:

```r
history <- attr(data, "weighting_history", exact = TRUE)
if (is.list(history) && length(history) > 0L) {
  metadata@weighting_history <- history
}
```

`survey_weighting_history()` (`R/utils.R:104-115`) is the matching accessor. It
takes a survey object only. It rejects a data frame with the error class
`surveycore_error_not_survey_object` (`R/utils.R:111`).

This plan follows both patterns.

---

## 2. Proposed design

### The three options

**(a) Individual scalar properties.** Add `@survey_name`, `@data_name`,
`@vendor`, `@field_start`, and `@field_end` to `survey_metadata`.

**(b) One extensible list property.** Add `@dataset_metadata`, a named list of
arbitrary key-value pairs.

**(c) Hybrid.** Add named typed properties for the known fields, plus an
extensible slot for everything else.

### Evaluation

| Criterion | (a) Scalars | (b) One list | (c) Hybrid |
|---|---|---|---|
| Type safety at the S7 layer | Strong | None | Mixed |
| Validator complexity | Low per field, grows linearly | Low and fixed | Highest — two code paths |
| Discoverability (`m@vendor` vs a lookup) | Best | Weakest | Good |
| Forward compatibility | Poor — each new field is a class change | Best | Good |
| Consistency with the existing class | Poor — no scalar property exists today | Best | Middling |
| Number of code paths in setters and extractors | 1 per field | 1 | 2 |

Two facts decide this.

**Fact 1 — the existing class is not strongly typed.** All 11 properties are
`S7::class_list` (`R/core-classes.R:80-127`). Type enforcement happens in the
setter layer, not in the class. Examples:

- `.validate_scalar_content()` (`R/core-metadata.R:975-996`) rejects a
  non-scalar label.
- `set_higher_is()` rejects a value other than `"better"` or `"worse"` at
  `R/core-metadata.R:1880-1890`.

So option (a) would introduce a new and inconsistent typing style.

**Fact 2 — adding an S7 property breaks old serialized objects.** I verified
this by running R:

1. Create an S7 object. Save it with `saveRDS()`.
2. Redefine the class with one more property.
3. Read the object back.

The object keeps a frozen copy of the old class in its `S7_class` attribute.
Reading the new property fails with `Can't find property <cls>@b`. After I
replaced the stored class definition with the new one, the property read as
`NULL` rather than the declared default.

Each class change therefore costs something. Option (a) pays that cost every
time a new dataset-level field appears. Option (b) pays it once.

### Recommendation

**Adopt option (c), implemented as a single slot with a reserved-key schema.**

Add exactly one property to `survey_metadata`:

```r
dataset_metadata = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

Then define a documented set of **reserved keys** with declared types:

| Key | Type | Meaning | Example |
|---|---|---|---|
| `survey_name` | `character(1)` | Full formal survey name. No dates. | `"Antisemitic Attitudes in America 2026"` |
| `data_name` | `character(1)` | Human-readable display label for this dataset. Usually a short name plus the field period. | `"AAA Ipsos (February-March 2026)"` |
| `vendor` | `character(1)` | Fielding vendor | `"Ipsos KnowledgePanel Omnibus"` |
| `field_start` | `Date(1)` | First day in the field | `as.Date("2026-02-10")` |
| `field_end` | `Date(1)` | Last day in the field | `as.Date("2026-03-04")` |
| `field_period` | `character(1)` | Prose field period, for display | `"February-March 2026"` |

Any other key is permitted. Any other key has no type restriction.

Section 2.1 explains why both `survey_name` and `data_name` are stored.

This is a hybrid in substance:

- Reserved keys give the type safety, discoverability, and print support of
  option (a).
- The open key space gives the forward compatibility of option (b).
- The storage layer stays a plain named list, which matches all 11 existing
  properties.
- A new field (for example `mode`, `sample_source`, or `margin_of_error`)
  needs no class change and breaks no serialized object.

The cost is that a user writes `extract_vendor(d)` rather than `d@metadata@vendor`.
Named accessor functions remove most of that cost. Section 4 defines them.

---

## 2.1 `survey_name` and `data_name` — the redundancy question

### The problem

`data_name` looks derivable. In principle it is the survey name plus the field
period:

```
"Antisemitic Attitudes in America 2026" + "February-March 2026"
  → "Antisemitic Attitudes in America 2026 (February-March 2026)"
```

Three storage models are possible.

**(a) Store all three independently.** `survey_name`, `data_name`, and the field
dates are separate keys. No rule connects them.

**(b) Store `survey_name` and the dates only.** Derive `data_name` on demand in
`extract_data_name()`.

**(c) Store all three, and validate consistency.** The validator rejects a
`data_name` that does not match the composed string.

### Evaluation

| Criterion | (a) Independent | (b) Derived | (c) Validated |
|---|---|---|---|
| Migration cost for the 13 existing labels | None | High — every label changes | High — every label must match |
| Can a dataset keep a custom display label? | Yes | No | No |
| Can the two values drift apart? | Yes | No | No |
| Works when the field dates are unset? | Yes | No | Partly |
| Number of code paths in the extractor | 1 | 2 | 1 |
| New failure mode at construction | None | None | Yes — a legacy label errors |

### Recommendation

**Adopt option (a). Store all three keys independently. Do not validate
consistency.**

Four reasons, in order of weight.

1. **The existing labels are not derivable.** The measured corpus in section 1
   shows this. The stored `data_name` for `aaa_ipsos` is "AAA Ipsos
   (February-March 2026)"
   (`adldata/data-raw/aaa/aaa_ipsos/aaa_ipsos.R:1305`). The formal survey name
   is "Antisemitic Attitudes in America 2026". The label uses a short name and
   the vendor, not the formal name. No composition rule produces one from the
   other. Option (b) would rename 13 datasets. Option (c) would reject all 13.
2. **The field dates are often absent.** Only one dataset carries a date
   attribute today (`adldata/data-raw/cpost/cpost.R:316`). Section 3 keeps
   `field_period` as a prose fallback and accepts that some datasets will set
   neither. A derived `data_name` would then be a bare survey name, which is a
   worse label than the one the author already wrote.
3. **The plan already refuses to parse `data_name`.** Section 3 states two
   migration rules: do not parse dates out of `data_name`, and do not
   auto-populate `field_period` from it. Deriving `data_name` is the same
   problem in reverse. It assumes a string format that the corpus does not
   follow.
4. **A display label must stay overridable.** A wave with an odd name, a pilot,
   or a re-release needs a custom label. Options (b) and (c) both remove that
   control.

The cost of option (a) is real: the two values can drift. A user can change
`survey_name` and leave a stale `data_name`. The plan accepts that cost. The
drift is cosmetic, it is visible in the print output (section 7), and the
author edits both values in the same `data-raw/` script.

### One refinement, not a fourth option

`extract_data_name()` stays strict. It reads the stored key only. It returns
`NA_character_` when the key is unset. It never composes a string.

The **print header** falls back. When `data_name` is unset and `survey_name` is
set, the header prints the survey name. See section 7. This gives a useful
default without inventing a format and without writing a value the user did not
set.

---

## 3. Field dates

### Recommendation

Store **structured dates**, and keep a prose fallback.

- `field_start` and `field_end` hold `Date` scalars.
- `field_period` holds the prose string, for display and for the cases where
  the exact days are unknown.

Reasons:

1. A structured pair supports comparison, sorting, and duration. A prose string
   does not. A user who holds a `survey_collection` of waves
   (`R/core-classes.R:791`) wants to order the waves by field date.
2. The prose corpus is not machine-readable. The existing values are
   "April-May 2024" (`adldata/data-raw/cpost/cpost.R:316`) and
   "(February-March 2026)" inside a name string
   (`adldata/data-raw/aaa/aaa_ipsos/aaa_ipsos.R:1305`). Month-level precision
   cannot become a day-level `Date` without inventing the day.
3. Dropping the prose entirely would force the author to fabricate day
   precision. Keeping `field_period` avoids that.

### Migration

The plan must not guess. Three rules:

1. **Do not parse dates out of `data_name`.** The strings are inconsistent, and
   a wrong start date is worse than a missing one.
2. **Do not auto-populate `field_period` from `data_name`.** The name is a
   display label. Splitting it is lossy.
3. **Do not auto-populate `survey_name` from `data_name`.** The label holds a
   short name, not the formal one. See section 2.1.

The migration is a manual, one-time edit in `adldata`:

- For each of the 39 datasets, set `survey_name` to the full formal name. Omit
  the field dates from that string. No dataset sets this attribute today.
- For each of the 39 datasets, set `field_start` and `field_end` where the
  author knows the exact days.
- Where the author knows only the months, set `field_period` and leave the
  dates unset.
- Move `attr(cpost, "dates")` (`adldata/data-raw/cpost/cpost.R:316`) to
  `field_period`. Keep the string value unchanged.
- Leave `data_name` untouched. Users expect the period inside the name.

surveycore ships a deprecation-free path: the legacy attribute name `dates` is
read at construction as `field_period`. See section 5.

---

## 4. API surface

### Design decision — dual-mode behavior on a plain data frame

**Yes. A plain data frame gets whole-object attributes, one attribute per key.**

`set_dataset_metadata(df, vendor = "Ipsos")` writes `attr(df, "vendor")`.

Reasons:

1. Every per-variable setter already writes one attribute per concept.
   `set_var_label()` writes `attr(x[[var]], "label")`
   (`R/core-metadata.R:1115`). `set_val_labels()` writes `"labels"`
   (`R/core-metadata.R:1226`). `set_higher_is()` writes `"higher_is"`
   (`R/core-metadata.R:1893`). A single packed list attribute would be a new
   and different convention.
2. It matches what `adldata` already writes. The 13 datasets that set
   `data_name` and the 10 that set `vendor` need no edit for those two keys.
   Only `survey_name` and the field dates need new lines.
3. It keeps the round trip trivial: write the attribute in `data-raw/`, then
   `as_survey()` hoists it (section 5).

The risk is a key name that collides with a base data frame attribute. The
setter rejects a key in `c("names", "row.names", "class", "dim", "dimnames",
"comment", "levels", "tsp")` with the error class
`surveycore_error_dataset_key_reserved`.

### Setters

```r
set_dataset_metadata(x, ..., key = NULL, value = NULL)
```

- `x` — a survey design object or a data frame.
- `...` — named arguments. The name is the key. The value is the content.
  Supports `!!!` splicing.
- `key` — a character vector of keys. Use with `value`.
- `value` — a list of values, one per element of `key`.

This is the same three-convention interface as every existing setter. It
reuses `.parse_setter_input()` (`R/core-metadata.R:86-213`) with
`content_type = "vector"` and `content_arg_name = "value"`. Two differences
from a per-variable setter:

- It does **not** call `.get_data_cols()` (`R/core-metadata.R:67-69`), because
  a key is not a column. The "variable not found" warning
  (`surveycore_warning_var_not_found`, `R/core-metadata.R:1106`) does not apply.
- A `NULL` value deletes the key, matching the per-variable convention at
  `R/core-metadata.R:164-167`.

Reserved-key type checks run in the setter, before the write. This follows the
Layer 3 rule stated at `R/core-classes.R:13-15`.

Four convenience setters wrap the general one:

```r
set_survey_name(x, name)
set_data_name(x, name)
set_vendor(x, vendor)
set_field_dates(x, start = NULL, end = NULL, period = NULL)
```

`set_survey_name()` and `set_data_name()` are separate functions with the same
shape. They write different keys. Neither one writes the other key, and neither
one reads it. Section 2.1 gives the reason.

`set_field_dates()` accepts a `Date`, or a `character` string in ISO 8601
format which it coerces with `as.Date()`. It rejects any other format with
`surveycore_error_field_date_invalid`. It errors when `start > end`.

### Extractors

```r
extract_dataset_metadata(x, ..., format = "list", fill = NULL)
```

- `x` — a survey design object or a data frame.
- `...` — bare or quoted key names. If empty, returns every key.
- `format` — `"list"` (default) or `"data_frame"`.
- `fill` — `NULL` (default) omits absent keys; `NA` includes them.

`format = "data_frame"` returns a tibble with columns `key` and `value`, where
`value` is coerced to character. This mirrors `.format_scalar_result()`
(`R/core-metadata.R:219-257`) but keys the first column `key` rather than
`variable`.

`...` uses plain name matching, not `tidyselect::eval_select()`. The existing
extractors select against columns (`R/core-metadata.R:457-461`). A key is not a
column, so tidy-select cannot resolve it.

Four convenience extractors:

```r
extract_survey_name(x)   # character(1) or NA_character_
extract_data_name(x)     # character(1) or NA_character_
extract_vendor(x)        # character(1) or NA_character_
extract_field_dates(x)   # list(start = <Date>, end = <Date>, period = <chr>)
```

Each returns `NA` for an unset reserved key rather than `NULL`. This matches
`extract_higher_is()` (`R/core-metadata.R:1933`), which returns
`NA_character_` for an unset variable.

`extract_data_name()` reads the stored `data_name` key only. It does not
compose a label from `survey_name` and the field dates. Section 2.1 gives the
reason.

### Type guard

All new functions call `.check_is_survey_or_df()`
(`R/core-metadata.R:44-62`). None call `.check_is_survey()`
(`R/core-metadata.R:345-363`), because they all accept a data frame.

### File placement

All new exported functions live in `R/core-metadata.R`, after
`classify_question_type()` (`R/core-metadata.R:2442`) and before the internal
helper section (`R/core-metadata.R:2445`). The new internal hoist helper lives
in `R/utils.R`, beside `.promote_weighting_history()` (`R/utils.R:351`).

---

## 5. Changes to `.extract_haven_metadata()`

### Decision

**Yes. Construction hoists the data-frame-level attributes into the new slot.**
But the hoist lives in a **separate helper**, not inside
`.extract_haven_metadata()`.

### Reasoning

1. `.extract_haven_metadata()` (`R/core-metadata.R:2511-2595`) has a single
   responsibility: loop over columns and read per-column attributes. Its
   roxygen block says so at `R/core-metadata.R:2495-2498`. A whole-object read
   does not belong in that loop.
2. The package already separates the two concerns.
   `.promote_weighting_history()` (`R/utils.R:351-357`) reads the whole-object
   attribute. The constructors chain the two calls:
   `R/core-constructors.R:547-548` and `R/core-constructors.R:804-805`.
3. Without the hoist the feature is unusable for `adldata`. The 39 datasets
   ship as tibbles carrying the attributes. If `as_survey()` ignores them, the
   user must re-set the metadata after every construction.

### The new helper

```r
.promote_dataset_metadata(data, metadata)
```

It reads, in order:

1. `attr(data, "survey_name")` → key `survey_name`
2. `attr(data, "data_name")` → key `data_name`
3. `attr(data, "vendor")` → key `vendor`
4. `attr(data, "field_start")` → key `field_start`
5. `attr(data, "field_end")` → key `field_end`
6. `attr(data, "field_period")` → key `field_period`
7. `attr(data, "dates")` → key `field_period`, **only when `field_period` is
   not already set**. This is the legacy name used at
   `adldata/data-raw/cpost/cpost.R:316`.
8. Every other attribute listed in `attr(data, "surveycore_dataset_keys")`, a
   character vector that `set_dataset_metadata()` maintains on a data frame so
   that non-reserved keys survive construction.

It skips a key whose value is `NULL` or zero-length. It returns the metadata
object unchanged when no attribute is present. It does not error on a
wrong-typed value; it warns with `surveycore_warning_dataset_metadata_dropped`
and skips the key. A constructor must not fail because of a cosmetic label.

The helper reads `survey_name` and `data_name` as two independent attributes.
It never derives one from the other, and it never fills one from the other.

### Call sites to change

Insert the call after the existing metadata lines:

| Constructor | Line to follow | Currently calls `.promote_weighting_history()`? |
|---|---|---|
| `as_survey()` | `R/core-constructors.R:548` | Yes |
| `as_survey_replicate()` | `R/core-constructors.R:805` | Yes |
| `as_survey_nonprob()` | `R/core-constructors.R:1384` | **No** |

`as_survey_nonprob()` calls `.extract_haven_metadata()` at
`R/core-constructors.R:1384` but never calls `.promote_weighting_history()`.
That is an existing inconsistency. Fix it in the same branch, or record it as a
separate issue. Do not repeat the omission for the new helper.

`as_survey_twophase()` needs no change. It inherits the metadata object whole
from phase 1 at `R/core-constructors.R:1114-1116`.

`from_svydesign()` and `from_tbl_svy()` build an empty `survey_metadata()`
(`R/methods-conversion.R:419`, `:453`, `:505`). Leave them empty. The `survey`
package carries no metadata, as the documentation states at
`R/methods-conversion.R:315-316`.

---

## 6. Validator changes in `R/core-classes.R`

`survey_metadata` has no validator today (`R/core-classes.R:77-129`). Add one.

### What the validator checks

The validator checks structure only, plus the reserved-key types:

1. `@dataset_metadata` is a list. (S7 enforces this through `class_list`.)
2. When the list is non-empty, every element has a name.
   Error class: `surveycore_error_dataset_metadata_unnamed`.
3. No name is `NA` or an empty string. Same error class.
4. No name is duplicated.
   Error class: `surveycore_error_dataset_metadata_duplicate_key`.
5. `survey_name`, when present, is a `character` of length 1 and is not `NA`.
   Error class: `surveycore_error_dataset_metadata_bad_type`.
6. `data_name`, when present, obeys the same rule. Same error class.
7. `vendor`, when present, obeys the same rule. Same error class.
8. `field_period`, when present, obeys the same rule. Same error class.
9. `field_start` and `field_end`, when present, each inherit from `Date` and
   have length 1. Same error class.
10. When both `field_start` and `field_end` are present and neither is `NA`,
    `field_start <= field_end`.
    Error class: `surveycore_error_field_dates_reversed`.

The validator does **not** compare `survey_name` with `data_name`. Section 2.1
gives the reason: the two values are independent, and the existing labels do not
follow a composition rule.

Checks 5 to 10 go beyond the Layer 1 rule stated at `R/core-classes.R:13-15`,
which reserves validators for structural invariants. The justification is that
the reserved keys form part of the class contract. The print method reads them
(section 7). A wrong type there would break printing, which is worse than a
construction error.

**Alternative, if the author prefers strict Layer 1 discipline:** keep checks 1
to 4 in the validator, move checks 5 to 10 into `set_dataset_metadata()` only,
and make the print method defensive against a wrong type. Record the choice in
the decisions file.

### Other changes in the same file

- Add a `@param dataset_metadata` entry to the roxygen block at
  `R/core-classes.R:28-59`.
- Add a `dataset_metadata` example to the `@examples` block at
  `R/core-classes.R:63-74`.
- Add an inline comment beside the new property that names the reserved keys.
- Do **not** change `survey_base` (`R/core-classes.R:160-184`). The new
  property sits inside `survey_metadata`, which `survey_base@metadata` already
  holds (`R/core-classes.R:168-171`).

All new error class names follow the format `surveycore_error_<snake_case>`
required by `plans/error-messages.md:21-22`. Add every new row to that table.

---

## 7. Print method changes

### Current behavior

There are four print methods:

| Class | Line |
|---|---|
| `survey_taylor` | `R/methods-print.R:108` |
| `survey_replicate` | `R/methods-print.R:249` |
| `survey_twophase` | `R/methods-print.R:354` |
| `survey_nonprob` | `R/methods-print.R:478` |

Each has an always-on header block. For `survey_taylor` it runs at
`R/methods-print.R:124-132` and shows the class, the sample size, the domain
information, and the groups.

Each has a metadata section that runs only when `metadata_info = TRUE` or
`full = TRUE`. For `survey_taylor` it runs at `R/methods-print.R:209-215` and
prints one line: the count of labeled variables. The other three do the same at
`R/methods-print.R:319-323`, `:431-435`, and `:558-562`.

There are also four summary methods (`R/methods-print.R:583`, `:624`, `:678`,
`:721`). Each prints one metadata line at `R/methods-print.R:610-612`,
`:664-666`, `:707-709`, and `:773-775`.

### Recommendation

**Yes, show dataset-level metadata. Split it across two places.**

**In the always-on header**, print one line:

```
Dataset: AAA Ipsos (February-March 2026)
```

Rules for that line:

- Print `data_name` when it is set.
- Print `survey_name` when `data_name` is unset and `survey_name` is set. This
  is the fallback from section 2.1. The header shows a name rather than
  nothing.
- Print no line when both keys are unset.

Place the line immediately after the class line and before the sample size
line. For `survey_taylor` the class line is `R/methods-print.R:126` and the
sample size line is `R/methods-print.R:127`, so the new line goes between them.
Use the matching position in the other three methods. A dataset name answers "which survey am I
looking at?". That is identity, not detail. Printing nothing when both keys are
unset keeps the default output unchanged for every existing user.

**In the `metadata_info` section**, print the remaining keys:

```
Survey: Antisemitic Attitudes in America 2026
Vendor: Ipsos KnowledgePanel Omnibus
Field dates: 2026-02-10 to 2026-03-04
Other keys: mode, sample_source
```

Rules for that block:

- Print `Survey:` from `survey_name` when it is set **and** the header did not
  already print it. This avoids one name on two lines.
- Print `Field dates` from `field_start` and `field_end` when both are set.
- Otherwise print `field_period` when it is set.
- Print a single `Other keys:` line naming the non-reserved keys. Do not print
  their values. A value may be arbitrarily long.
- Print nothing at all when `@dataset_metadata` is empty.

The two name lines can disagree, because section 2.1 permits drift. That is the
intended behavior. The print output shows both values, so a stale `data_name` is
visible to the author.

**In the four summary methods**, add one name line only, on its own line above
the existing metadata line. Use the same `data_name` then `survey_name`
fallback as the header. Keep the summary short.

Add a snapshot test for each of the four print methods, in three states:

- With no dataset metadata.
- With `data_name` set.
- With `survey_name` set and `data_name` unset, to lock the header fallback.

---

## 8. Backward compatibility

### Survey objects created before this change

Two cases, and they behave differently.

**Case 1 — an object built in the current session.** No issue. The object uses
the current class definition and gets the default `list()`.

**Case 2 — an object restored from `saveRDS()` or `.rda`.** This one needs
care. I verified the behavior by running R:

- An S7 object serializes a copy of its class in an `S7_class` attribute.
- After the class gains a property, reading that property on the restored
  object fails with `Can't find property <cls>@b`.
- After the stored class definition is replaced with the current one, the
  missing property reads as `NULL`, not the declared default.

So `x@metadata@dataset_metadata` can error on an object restored from an old
file. Every read path must therefore go through one guarded helper:

```r
.dataset_metadata_or_empty <- function(metadata) {
  if (!"dataset_metadata" %in% S7::prop_names(metadata)) {
    return(list())
  }
  metadata@dataset_metadata
}
```

`S7::prop_names()` reads the class stored on the object, so it returns the old
11 names for an old object, and the helper returns `list()`. Every extractor
and both print paths use this helper. A restored old object then prints and
extracts cleanly, and simply reports no dataset metadata.

A write to an old object still fails. Document that clearly: the user must
rebuild the survey object with `as_survey()` to gain the new slot. Do not
attempt to rewrite the `S7_class` attribute automatically. That is fragile and
silent.

### Data frames created before this change

No issue. Thirteen `adldata` tibbles already carry `data_name` and ten carry
`vendor` as raw attributes (section 1). The new hoist helper reads them
(section 5). No edit is needed for those two keys. `survey_name` is new: no
dataset sets it, so every dataset needs one new line in `data-raw/`.

### Existing exported API

No signature changes. No behavior changes for any existing function. Every
change is additive:

- One new property on `survey_metadata`.
- One new validator on a class that had none.
- Ten new exported functions.
- New print lines that appear only when the new keys are set.

### Version bump

**Minor: 1.1.0 → 1.2.0.**

`DESCRIPTION` currently reads `Version: 1.1.0`. The package reached a stable
API at 1.0.0, and `CLAUDE.md` states the existing structure will not change in
breaking ways.

This change does not break the API. It adds to it. Under semantic versioning
that is a minor bump.

The one honest caveat: an S7 class-layout change is not free, as case 2 above
shows. But the failure is confined to a slot that no old object could have
used, and the guarded reader removes it from every code path surveycore
controls. Record the caveat in `NEWS.md` under a "Notes" heading. Do not treat
it as a major bump — a major bump would signal removed or changed behavior,
and there is none.

---

## 9. OPEN QUESTIONS

> The two items below are **unresolved**. They are sketches only. They wait on
> the package author's decision. Do not implement either one from this plan.

### OPEN QUESTION 1 — Per-variable provenance

**Status: UNRESOLVED. Pending the package author's decision.**

**The problem.** The user's cleaning convention keeps the original vendor
column, adds a semantically renamed copy, and then adds one or more derived
variants. Common suffixes are `_f`, `_f2`, `_b`, and `_rev`. Nothing in the
object records which is which.

Measured evidence from `adldata`:

| Dataset | Columns | `_f` | `_f2` | `_b` |
|---|---|---|---|---|
| `aaa_ipsos` | 533 | 83 | 81 | 97 |
| `cc` | 1228 | not measured | not measured | not measured |
| `jrp_bsg` | 747 | not measured | not measured | not measured |

A 200-item instrument becomes an object with several hundred columns. A
downstream consumer cannot tell a raw vendor column from a renamed copy from a
derived variant.

**Sketch of a possible property.** A twelfth `survey_metadata` property, keyed
by variable name, holding a small list per variable:

```r
provenance = S7::new_property(S7::class_list, default = quote(list()))

# Shape of one entry:
list(
  role   = "derived",   # one of "raw", "renamed", "derived"
  parent = "adl4_1",    # source column name; NULL when role == "raw"
  method = "factor"     # optional free text describing the derivation
)
```

Matching API, following the existing conventions:

```r
set_provenance(x, adl4_1_f = list(role = "derived", parent = "adl4_1"))
extract_provenance(x, ..., format = "data_frame")
```

**Points the author must settle before this can be planned:**

1. Is `role` a closed vocabulary of exactly three values, or is it open?
2. Does a renamed copy point at its parent, or is `parent` only for derived
   columns? A rename chain (`raw` → `renamed` → `derived`) has two links.
3. Should `@metadata@transformations` (`R/core-classes.R:116`) absorb this
   instead? It already tracks transformation history, and the two overlap.
4. Should `as_survey()` infer the role from a suffix pattern? Inference is
   convenient and it is also a guess. A wrong `parent` is worse than none.
5. Should a `select()` that removes a parent warn that a child now has a
   dangling `parent`? That would need a change in `surveytidy`, which I did not
   read. **Not verified.**

### OPEN QUESTION 2 — Free-text marker

**Status: UNRESOLVED. Pending the package author's decision.**

**The problem.** There is no way to mark a column as open-ended free text. Any
downstream code that sweeps `where(is.character)` will treat free text as a
categorical variable and recode it silently.

Measured evidence from `adldata`:

| Dataset | Character columns | Columns named `*_text` / `*_txt` / `*_oe` |
|---|---|---|
| `aaa_ipsos` | 7 | 2 |
| `jrp_bsg` | 78 | 0 |
| `asi` | 32 | 13 |
| `pol_pos` | 15 | 2 |

`jrp_bsg` has 78 character columns and no naming signal at all. A name-based
heuristic cannot find the free-text columns there.

**Option A — a boolean per-variable property.** A new property shaped exactly
like `sata` (`R/core-classes.R:104`), `higher_is` (`R/core-classes.R:108`), and
`reverse_coded` (`R/core-classes.R:112`). Only marked variables appear in the
list. Absence means "not free text".

```r
free_text = S7::new_property(S7::class_list, default = quote(list()))

set_free_text(x, ..., variable = NULL, free_text = TRUE)
extract_free_text(x, ..., format = "named_vector", fill = FALSE)
```

`set_sata()` (`R/core-metadata.R:1601`) and `extract_sata()`
(`R/core-metadata.R:1714`) are the templates. The work is small and the pattern
is proven.

**Option B — one broader variable-role property.** A single property holding a
role string per variable, for example `"free_text"`, `"categorical"`,
`"ordinal"`, `"continuous"`, `"identifier"`, or `"weight"`. One property would
then answer several questions at once, and `classify_question_type()`
(`R/core-metadata.R:2265`) could read it instead of inferring from prefaces and
SATA flags.

**Points the author must settle before this can be planned:**

1. Does the package want a full role vocabulary, or one narrow flag? Option B
   is more powerful and much larger. It also overlaps
   `classify_question_type()`, which returns `"single"`, `"sata"`, or
   `"battery"` (`R/core-metadata.R:2243`).
2. If Option B wins, does `free_text` become a role, or does it stay a separate
   orthogonal flag? A free-text column can also be an identifier.
3. Does the marker change any analysis function's behavior, or is it purely
   documentary? For example, should `get_freqs()` refuse a free-text column?
4. Should Option A and Option B ship together, with the flag as a shortcut into
   the role property? That risks two sources of truth.
5. Should `set_free_text()` write a per-column attribute on a data frame, as
   every other setter does? Presumably yes, but confirm the attribute name.
   `"free_text"` is the obvious choice.

---

## 10. Implementation checklist

Work in this order. Each step is small and testable.

### Phase 1 — The class

1. Add the `dataset_metadata` property to `survey_metadata` in
   `R/core-classes.R`, after `weighting_history` (`R/core-classes.R:124-127`).
2. Add the `@param dataset_metadata` roxygen entry to the block at
   `R/core-classes.R:28-59`.
3. Add a `dataset_metadata` line to the `@examples` block at
   `R/core-classes.R:63-74`.
4. Add the validator to `survey_metadata`, with checks 1 to 10 from section 6.
5. Add every new error class to `plans/error-messages.md`. Follow the format
   rule at `plans/error-messages.md:21-22`.
6. Write class-level tests in a new file
   `tests/testthat/test-dataset-metadata.R`:
   - The default is `list()`.
   - Each validator check fires, with the right error class.
   - A valid object with all six reserved keys constructs cleanly.
   - An object with `survey_name` and a `data_name` that does not match it
     constructs cleanly. The validator must not compare the two.
7. Run `devtools::document()`. Confirm `man/survey_metadata.Rd` updates.

### Phase 2 — The guarded reader and the hoist

8. Add `.dataset_metadata_or_empty()` to `R/utils.R`, beside
   `.promote_weighting_history()` (`R/utils.R:351`).
9. Add `.promote_dataset_metadata()` to `R/utils.R`, with the read order from
   section 5.
10. Wire the hoist into the three constructors:
    - `R/core-constructors.R:548` (`as_survey()`)
    - `R/core-constructors.R:805` (`as_survey_replicate()`)
    - `R/core-constructors.R:1384` (`as_survey_nonprob()`)
11. Decide whether to also fix the missing `.promote_weighting_history()` call
    in `as_survey_nonprob()` in this branch, or to open a separate issue.
12. Test the hoist:
    - Legacy `data_name` and `vendor` attributes are hoisted.
    - A `survey_name` attribute is hoisted.
    - A data frame with `survey_name` but no `data_name` leaves `data_name`
      unset. The hoist must not derive it.
    - The legacy `dates` attribute lands in `field_period`.
    - An explicit `field_period` beats a legacy `dates`.
    - A wrong-typed attribute warns and is skipped; construction succeeds.
    - `as_survey_twophase()` inherits the keys from phase 1
      (`R/core-constructors.R:1114-1116`).
    - `from_svydesign()` produces an empty slot
      (`R/methods-conversion.R:419`).

### Phase 3 — The setters

13. Add `set_dataset_metadata()` to `R/core-metadata.R`, after
    `classify_question_type()` (`R/core-metadata.R:2442`). Reuse
    `.parse_setter_input()` (`R/core-metadata.R:86-213`) and
    `.check_is_survey_or_df()` (`R/core-metadata.R:44-62`).
14. Add the reserved-name collision check, with the error class
    `surveycore_error_dataset_key_reserved`.
15. Add the reserved-key type checks in the setter.
16. Add the data frame branch. It writes one attribute per key, and it
    maintains `attr(x, "surveycore_dataset_keys")`.
17. Add `set_survey_name()`, `set_data_name()`, `set_vendor()`, and
    `set_field_dates()`.
18. Test all three setter conventions for `set_dataset_metadata()`, on a survey
    object and on a data frame. Test key deletion with `NULL`. Test the
    reversed-date error.
19. Test that `set_survey_name()` leaves `data_name` unchanged, and that
    `set_data_name()` leaves `survey_name` unchanged.

### Phase 4 — The extractors

20. Add `extract_dataset_metadata()`, with `format` and `fill`.
21. Add `extract_survey_name()`, `extract_data_name()`, `extract_vendor()`, and
    `extract_field_dates()`.
22. Route every read through `.dataset_metadata_or_empty()`.
23. Test both formats, both `fill` values, the empty case, and the unknown-key
    case, on a survey object and on a data frame.
24. Test that `extract_data_name()` returns `NA_character_` when `data_name` is
    unset, even when `survey_name` and the field dates are set. It must not
    compose a label.

### Phase 5 — Printing

25. Add the `Dataset:` line to the header of all four print methods
    (between `R/methods-print.R:126` and `:127`, and at the matching positions
    near `:249`, `:354`, `:478`). Include the `survey_name` fallback from
    section 7.
26. Add the survey name, vendor, field dates, and other-keys lines to the four
    `metadata_info` blocks (`R/methods-print.R:209-215`, `:319-323`,
    `:431-435`, `:558-562`).
27. Add the name line to the four summary methods
    (`R/methods-print.R:610-612`, `:664-666`, `:707-709`, `:773-775`). Use the
    same fallback.
28. Add snapshot tests for all four classes, in the three states from
    section 7.
29. Re-record the existing print snapshots only if they change. They must not
    change when no dataset metadata is set. Confirm that.

### Phase 6 — Backward compatibility

30. Add a test that builds a `survey_metadata` object without the new property,
    then confirms that `.dataset_metadata_or_empty()` returns `list()`.
31. Add a test that prints a survey object whose metadata lacks the property.
    The print must succeed.

### Phase 7 — Documentation and release

32. Add the new functions to `NAMESPACE` through `devtools::document()`. Do not
    edit `NAMESPACE` by hand; line 1 forbids it.
33. Add the new functions to `_pkgdown.yml`:
    - Setters go in the "Metadata — setters" section (`_pkgdown.yml:93-108`).
    - Extractors go in the "Metadata — extractors" section
      (`_pkgdown.yml:110-125`).
34. Add a "Dataset-level metadata" section to
    `vignettes/creating-survey-objects.Rmd`. Show the `data-raw` workflow: set
    the attributes on the tibble, then call `as_survey()`. Show `survey_name`
    and `data_name` side by side, and state that the two are independent.
35. Update the `Description` field in `DESCRIPTION`. The current text says the
    metadata system "preserves 'haven'-style variable labels, value labels, and
    question-preface attributes". Add dataset-level metadata.
36. Add a `NEWS.md` entry under a new `# surveycore 1.2.0` heading. Include the
    serialization caveat from section 8.
37. Bump `Version:` to `1.2.0` in `DESCRIPTION`.
38. Run `devtools::check()`. It must pass with no new notes.

### Phase 8 — Downstream

39. Migrate `adldata`. In each of the 39 `data-raw/` scripts, replace the raw
    `attr()` calls with `set_dataset_metadata()`, and add field dates by hand
    per section 3.
40. Add `survey_name` to each of the 39 `data-raw/` scripts. No script sets it
    today. Write the formal name by hand. Do not derive it from `data_name`.
41. Check whether `surveytidy` needs any change. Its `select()` and `rename()`
    verbs maintain per-variable metadata. Dataset-level metadata is not keyed
    by variable, so probably no change is needed. **Not verified — I did not
    read the `surveytidy` source.**
42. Check whether `surveywts` writes to `@metadata`. **Not verified.**

### No change needed

- `R/zzz.R`. `.onLoad()` calls `S7::methods_register()` (`R/zzz.R:17`) and then
  registers 22 S3 methods for `survey_glm_fit`. A new property needs no
  registration. No new S3 generic is introduced.
- `survey_base` (`R/core-classes.R:160-184`). It already holds the metadata
  object at `R/core-classes.R:168-171`.
- `update_design()` in `R/update-design.R`. It mutates `@variables` in place and
  never rebuilds `@metadata`.

---

## Verification notes

Every claim about current behavior above cites a file and a line. Three claims
come from running R against installed surveycore 1.1.0 rather than from reading
source, and they are labeled as such in sections 1, 2, and 8:

1. A data-frame-level attribute survives into `@data` but no API reads it.
2. Reading a newly added S7 property on a restored old object errors with
   `Can't find property`.
3. After the stored class definition is refreshed, the missing property reads
   as `NULL`, not the declared default.

One more claim comes from running R against `adldata/data/`. The attribute
counts in section 1 are measured, not estimated: 39 objects in total, 13 with
`data_name`, 10 with `vendor`, 1 with `dates`, and 0 with `survey_name`. A
grep of `adldata/data-raw/` returns 13 lines that mention `data_name`, which
agrees with the object count. The name `survey_name` appears nowhere in
`surveycore/R/` or in `adldata/data-raw/`.

Three items are marked **not verified**: the `surveytidy` metadata lifecycle,
whether `surveywts` writes to `@metadata`, and the `_f` / `_f2` / `_b` counts
for `cc` and `jrp_bsg`.
