# Spec: SATA Metadata Property & Variable Type Detection

**Version:** 0.1 (draft)
**Date:** 2026-03-20
**Status:** Draft — pending review
**Package:** surveycore
**Branch ID:** `sata-metadata`

---

## Document Purpose

This is the source of truth for the `sata` (select-all-that-apply) metadata
property and the `detect_question_type()` helper function. Together they let
downstream code (analysis functions, export functions) distinguish three common
survey variable patterns: single-response, select-all-that-apply (SATA), and
battery/grid — without guessing.

---

## I. Scope

### What this phase delivers

| Component | Description |
|-----------|-------------|
| `sata` property on `survey_metadata` | Named logical list storing per-variable SATA flags |
| `set_sata()` | Setter: mark variables as SATA (or unmark) |
| `extract_sata()` | Getter: retrieve SATA status for variables |
| `detect_question_type()` | Classify variables into `"single"`, `"sata"`, or `"battery"` using `question_preface` + `sata` metadata |
| Metadata lifecycle integration | `sata` propagated through `select()`, `rename()`, `mutate()`, `filter()` — same as all other per-variable metadata |
| `.extract_var_meta()` integration | Analysis helper includes `sata` in per-variable metadata output |

### What this phase does NOT deliver

- Export functions (`export_topline()`, `export_crosstab()`) — separate spec
- Auto-detection of SATA from data patterns or SPSS metadata — future enhancement
- Changes to `get_freqs()` output format — `get_freqs()` already works; the
  export functions consume its output and use `detect_question_type()` to
  decide rendering
- `infer_sata()` analogous to `infer_question_prefaces()` — future enhancement

### Design support matrix

All four design classes support `sata` metadata identically (it lives on
`survey_metadata`, which is shared by all designs). No design-specific behavior.

---

## II. Architecture

### File organization

No new files. All changes go into existing files:

```
R/core-classes.R          — add `sata` property to survey_metadata
R/core-metadata.R         — add set_sata(), extract_sata(), detect_question_type()
R/core-validators.R       — add "sata" to .rename_metadata_keys()
R/analysis-helpers.R      — add sata to .extract_var_meta() output
tests/testthat/
  test-metadata-system.R  — tests for set_sata(), extract_sata()
  test-sata-detection.R   — tests for detect_question_type()  [NEW file]
```

### Integration touchpoints (surveytidy — no changes required if pattern holds)

The surveytidy `select()` cleanup loop and `rename()` via `.rename_metadata_keys()`
both enumerate metadata properties explicitly. Adding `sata` to `survey_metadata`
requires updating:

1. `.rename_metadata_keys()` in `R/core-validators.R` — add `metadata@sata`
2. surveytidy `select()` cleanup loop — add `x@metadata@sata[[col]] <- NULL`
3. surveytidy `.METADATA_ATTR_MAP` — add `sata = "sata"` entry

Items 2–3 are surveytidy changes and are **out of scope** for this spec. They
will be tracked as a follow-up. Until then, `sata` metadata survives `select()`
(orphaned keys are harmless) but is not propagated through `mutate()`.

> **Note:** `.rename_metadata_keys()` lives in surveycore's `R/core-validators.R`
> and IS in scope.

---

## III. `sata` Property on `survey_metadata`

### Storage

Add a new property to the `survey_metadata` S7 class:

```r
sata = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

The `sata` property is a **named list** mapping variable names to `TRUE`.
Only variables explicitly marked as SATA appear in this list. Absence from the
list means the variable is not SATA (i.e., `FALSE` is the default). Setting a
variable's SATA status to `FALSE` or `NULL` removes it from the list.

**Rationale for storing only `TRUE`:** Most variables in a survey are not SATA.
Storing only positive flags keeps the list sparse and consistent with how
`question_prefaces`, `notes`, `universe`, etc. store only set values (absent =
not set). This also means `length(x@metadata@sata)` gives the count of SATA
variables directly.

### Data frame support

For plain data frames (non-survey objects), SATA status is stored as a
column-level attribute:

```r
attr(df$news_tv, "sata")  # TRUE or NULL
```

This parallels how `question_preface` uses `attr(col, "question_preface")`.

---

## IV. `set_sata()` — Setter

### Signature

```r
set_sata(x, ..., variable = NULL, sata = TRUE)
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | (required) | The object to modify |
| `...` | bare variable names | (none) | Variables to mark. Unquoted, supports `c()` and `!!!` |
| `variable` | `character` | `NULL` | Alternative: character vector of variable names |
| `sata` | `logical(1)` | `TRUE` | `TRUE` to mark as SATA; `FALSE` to unmark |

### Conventions

`set_sata()` uses a **simplified setter pattern** — not the 3-convention
pattern from `set_var_label()`. The 3-convention pattern maps variable names
to heterogeneous content values (each variable gets its own label string).
SATA is a uniform flag: all listed variables get the same boolean value. This
is closer to a "tag" operation than a "label" operation.

**Convention A (tidy-select `...`)** — recommended:
```r
design |> set_sata(news_tv, news_online, news_radio, news_print)
design |> set_sata(c(news_tv, news_online, news_radio, news_print))
design |> set_sata(starts_with("news_"))
```

**Convention B (character vector via `variable`)** — programmatic:
```r
sata_vars <- c("news_tv", "news_online", "news_radio", "news_print")
design |> set_sata(variable = sata_vars)
```

**Unmarking:**
```r
design |> set_sata(news_tv, sata = FALSE)          # unmark one
design |> set_sata(variable = sata_vars, sata = FALSE)  # unmark several
```

### Behavior rules

1. When `sata = TRUE`: add each resolved variable name to `x@metadata@sata`
   with value `TRUE`. For data frames, set `attr(x[[var]], "sata") <- TRUE`.
2. When `sata = FALSE`: remove each resolved variable name from
   `x@metadata@sata` (set to `NULL`). For data frames, set
   `attr(x[[var]], "sata") <- NULL`.
3. Variables not found in `x` produce a warning (class
   `surveycore_warning_var_not_found`) and are skipped — same pattern as
   `set_question_preface()`.
4. Both `...` and `variable` provided: error (class
   `surveycore_error_sata_ambiguous_input`).
5. Neither `...` nor `variable` provided: error (class
   `surveycore_error_sata_no_vars`).
6. `sata` argument is not a scalar logical: error (class
   `surveycore_error_sata_not_logical`).
7. Returns `invisible(x)` — setter convention.

### Tidy-select resolution

`...` is resolved via `tidyselect::eval_select()` against the column names of
`x` (or `x@data` for survey objects). This allows selection helpers like
`starts_with()`, `matches()`, `all_of()`, etc.

```r
# Internal resolution
pos <- tidyselect::eval_select(rlang::expr(c(...)), data = .get_data_for_select(x))
var_names <- names(pos)
```

Where `.get_data_for_select()` returns `x` for data frames or `x@data` for
survey objects.

### Error table

| Condition | Level | Error Class | Message |
|-----------|-------|-------------|---------|
| Both `...` and `variable` provided | ERROR | `surveycore_error_sata_ambiguous_input` | `"Provide variable names via {.arg ...} or via {.arg variable}, not both."` |
| Neither `...` nor `variable` provided | ERROR | `surveycore_error_sata_no_vars` | `"{.fn set_sata} requires at least one variable name."` |
| `sata` is not scalar logical | ERROR | `surveycore_error_sata_not_logical` | `"{.arg sata} must be {.code TRUE} or {.code FALSE}, not {.cls {class(sata)[[1L]]}} of length {length(sata)}."` |
| Variable not found in `x` | WARN | `surveycore_warning_var_not_found` | `"Variable {.field {var_name}} not found in {.arg x} and was skipped."` (reuses existing class) |

---

## V. `extract_sata()` — Getter

### Signature

```r
extract_sata(x, ..., format = "named_vector", fill = FALSE)
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | (required) | The object to query |
| `...` | bare variable names | (none) | Variables to query. If empty, returns all variables with SATA metadata |
| `format` | `character(1)` | `"named_vector"` | Output format: `"named_vector"`, `"list"`, or `"data_frame"` |
| `fill` | scalar | `FALSE` | Value for variables with no SATA metadata. `FALSE` (default) includes them with `FALSE`. `NULL` omits them. |

### Output contract

The `fill` default differs from other extractors (`NULL` in
`extract_var_label()`, etc.). For SATA, the natural "not set" value is `FALSE`,
not `NULL` — a variable either is or isn't SATA. When the user asks "is
`news_tv` SATA?", the answer should be `TRUE` or `FALSE`, not `NULL`.

When `...` is empty and `fill = FALSE` (default): returns a named logical
vector with one entry per column in `x`, all `FALSE` except those marked SATA.
This matches the mental model of "show me the SATA status of all my variables."

When `...` is empty and `fill = NULL`: returns only variables explicitly marked
SATA (sparse view). This matches how `extract_var_label()` with `fill = NULL`
returns only labeled variables.

**Format outputs:**

- `"named_vector"`: named logical vector. Names are variable names, values are
  `TRUE`/`FALSE`. Empty: `logical(0)`.
- `"list"`: named list of logical scalars. Empty: `list()`.
- `"data_frame"`: tibble with columns `variable` (character) and `sata`
  (logical). Empty: zero-row tibble.

### Behavior rules

1. When specific variables are requested via `...`: return their SATA status.
   Variables not in `@metadata@sata` get the `fill` value.
2. When `...` is empty and `fill = FALSE`: return all columns with their SATA
   status (dense view).
3. When `...` is empty and `fill = NULL`: return only columns marked
   `TRUE` (sparse view).
4. Variables not found in `x` produce a warning (class
   `surveycore_warning_var_not_found`) and are skipped.
5. For data frames: reads `attr(x[[var]], "sata", exact = TRUE)`.
6. Return is visible (getter convention).

### Error table

| Condition | Level | Error Class | Message |
|-----------|-------|-------------|---------|
| Invalid `format` | ERROR | `surveycore_error_format_invalid` | (reuses existing class/message) |
| Variable not found | WARN | `surveycore_warning_var_not_found` | (reuses existing class/message) |

---

## VI. `detect_question_type()` — Variable Type Classifier

### Purpose

Classifies a set of variables into three types based on their `question_preface`
and `sata` metadata. This is the single source of truth for the variable type
detection logic described in the export design notes.

### Signature

```r
detect_question_type(x, ...)
```

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | (required) | The object containing the variables |
| `...` | bare variable names | (required) | Variables to classify. At least one required. |

### Output contract

Returns a tibble with class `c("tbl_df", "tbl", "data.frame")` containing:

| Column | Type | Description |
|--------|------|-------------|
| `variable` | character | Variable name |
| `question_preface` | character | The variable's question preface, or `NA_character_` if none |
| `type` | character | One of `"single"`, `"sata"`, or `"battery"` |
| `group` | integer | Group number — variables sharing the same non-NA `question_preface` get the same group number. Variables with `type == "single"` each get their own unique group number. |

### Classification logic

For each variable in `...`:

1. Extract `question_preface` from metadata (or column attribute for data frames).
2. Extract `sata` status from metadata (or column attribute).

Then group variables by `question_preface`:

```
For each variable:
  IF question_preface is NA/NULL OR question_preface is unique among the requested variables:
    → type = "single"
  ELSE IF question_preface is shared by 2+ variables AND any variable in the group has sata = TRUE:
    → type = "sata" (for ALL variables in the group)
  ELSE (question_preface is shared by 2+ variables AND no variable has sata = TRUE):
    → type = "battery" (for ALL variables in the group)
```

**Important:** When a `question_preface` group contains a mix of `sata = TRUE`
and `sata = FALSE` variables, the entire group is classified as `"sata"`. This
is a pragmatic choice: SATA sets are typically marked uniformly, and a mixed
group almost certainly means some variables were missed during `set_sata()`.
A warning is issued (see error table).

### Group numbering

Groups are numbered sequentially in order of first appearance in `...`:

```r
detect_question_type(d, q1, news_tv, news_online, worry_econ, worry_crime)
# variable       question_preface                type      group
# q1             NA                              single        1
# news_tv        "Where do you get your news?"   sata          2
# news_online    "Where do you get your news?"   sata          2
# worry_econ     "How worried are you about..."  battery       3
# worry_crime    "How worried are you about..."  battery       3
```

### Behavior rules

1. `x` must be a survey object or data frame (validated with
   `.check_is_survey_or_df()`).
2. At least one variable must be provided in `...`. Error if empty.
3. Variables not found in `x` produce a warning and are omitted from the output.
4. If all requested variables are not found, return a zero-row tibble.
5. Variables with no `question_preface` always get `type = "single"` regardless
   of `sata` status. A variable marked `sata = TRUE` but with no shared
   `question_preface` is classified as `"single"` with a warning.

### Error table

| Condition | Level | Error Class | Message |
|-----------|-------|-------------|---------|
| `x` is not survey or data frame | ERROR | `surveycore_error_not_survey_or_df` | (reuses existing) |
| No variables provided in `...` | ERROR | `surveycore_error_detect_no_vars` | `"{.fn detect_question_type} requires at least one variable name in {.arg ...}."` |
| Variable not found | WARN | `surveycore_warning_var_not_found` | (reuses existing) |
| SATA variable has no shared `question_preface` | WARN | `surveycore_warning_sata_no_preface` | `"Variable {.field {var_name}} is marked SATA but has no shared {.code question_preface} with other variables in {.arg ...}. Classified as {.val single}."` |
| Mixed SATA status within a `question_preface` group | WARN | `surveycore_warning_sata_mixed_group` | `"Variables sharing {.code question_preface} {.val {preface}} have mixed SATA status. Treating entire group as {.val sata}. Use {.fn set_sata} to mark all variables in the group."` |

---

## VII. `.extract_var_meta()` Integration

The internal helper `.extract_var_meta()` in `R/analysis-helpers.R` currently
returns `variable_label`, `question_preface`, and `value_labels` for a single
variable. Add `sata` to this output:

```r
# Current return:
list(
  variable_label   = variable_label,
  question_preface = question_preface,
  value_labels     = value_labels
)

# Updated return:
list(
  variable_label   = variable_label,
  question_preface = question_preface,
  value_labels     = value_labels,
  sata             = sata
)
```

Where `sata` is `TRUE` if the variable is in `x@metadata@sata`, `FALSE`
otherwise.

This makes `sata` status available in the `.meta` attribute of all analysis
function results without changing any analysis function signatures or output
columns.

---

## VIII. `.rename_metadata_keys()` Integration

Add `sata` to the existing rename helper in `R/core-validators.R`:

```r
# Add after existing properties:
metadata@sata <- .rename_list_keys(metadata@sata, rename_map)
```

This ensures that `rename()` in surveytidy propagates SATA flags when columns
are renamed.

---

## IX. Testing

### `test-metadata-system.R` — `set_sata()` and `extract_sata()`

**Happy path:**

- `set_sata()` marks variables as SATA on a survey object
- `set_sata()` marks variables as SATA on a plain data frame
- `set_sata(sata = FALSE)` removes SATA flag
- `set_sata()` with tidy-select helpers (`starts_with()`, `all_of()`)
- `set_sata()` with `variable` argument (Convention B)
- `extract_sata()` returns `TRUE` for marked variables
- `extract_sata()` returns `FALSE` (default fill) for unmarked variables
- `extract_sata()` with `fill = NULL` returns only marked variables
- `extract_sata()` with `format = "data_frame"` returns correct tibble
- `extract_sata()` with `format = "list"` returns correct list
- `extract_sata()` on data frame reads column attributes
- Roundtrip: `set_sata()` then `extract_sata()` recovers the flags

**Error paths:**

- `set_sata()` with both `...` and `variable` → `surveycore_error_sata_ambiguous_input`
- `set_sata()` with neither `...` nor `variable` → `surveycore_error_sata_no_vars`
- `set_sata()` with `sata` not scalar logical → `surveycore_error_sata_not_logical`
- `set_sata()` with non-existent variable → warning `surveycore_warning_var_not_found`
- `extract_sata()` with invalid format → `surveycore_error_format_invalid`

**Edge cases:**

- `set_sata()` on variable already marked SATA (idempotent)
- `set_sata(sata = FALSE)` on variable not marked (no-op, no warning)
- `extract_sata()` with no `...` on object with no SATA metadata → all FALSE
- `extract_sata()` with no `...` and `fill = NULL` on object with no SATA → empty result
- Survey object with zero SATA variables: `length(x@metadata@sata) == 0L`

### `test-sata-detection.R` — `detect_question_type()`

**Happy path:**

- Single-response variables (no `question_preface`) → `type = "single"`
- SATA variables (shared `question_preface` + `sata = TRUE`) → `type = "sata"`
- Battery variables (shared `question_preface` + `sata = FALSE`) → `type = "battery"`
- Mixed types in one call → each group classified correctly
- Group numbering is sequential by first appearance
- Output tibble has correct columns and types

**Error paths:**

- No variables in `...` → `surveycore_error_detect_no_vars`
- Non-survey, non-data-frame input → `surveycore_error_not_survey_or_df`

**Edge cases:**

- Single variable with `question_preface` (no peers) → `type = "single"`
- SATA variable with no shared `question_preface` → `type = "single"` + warning
- Mixed SATA/non-SATA in same `question_preface` group → `type = "sata"` + warning
- All requested variables not found → zero-row tibble
- Variables with same `question_preface` but only one requested → `type = "single"` (grouping is among requested vars only)
- Data frame input (no survey object) → works via column attributes

### `.rename_metadata_keys()` integration test

- Rename a SATA-flagged variable → flag follows the new name
- In existing `test-metadata-system.R` rename tests, add `sata` to the
  properties being checked

### `.extract_var_meta()` integration test

- In existing analysis helper tests, verify `sata` key is present and correct
  in the returned list

---

## X. Quality Gates

- [ ] `sata` property exists on `survey_metadata` with `list()` default
- [ ] `set_sata()` exported and documented with `@family metadata`
- [ ] `extract_sata()` exported and documented with `@family metadata`
- [ ] `detect_question_type()` exported and documented with `@family metadata`
- [ ] `.rename_metadata_keys()` includes `sata`
- [ ] `.extract_var_meta()` returns `sata` key
- [ ] All error classes added to `plans/error-messages.md`
- [ ] All error paths tested with `expect_error(class = ...)`
- [ ] All new error messages tested with `expect_snapshot(error = TRUE)`
- [ ] `devtools::check()` passes with 0 errors, 0 warnings
- [ ] Coverage for new code ≥ 98%

---

## XI. Downstream Contracts

### For `export_topline()` / `export_crosstab()` (future spec)

These functions will call `detect_question_type()` to determine rendering
format. They depend on:

1. `detect_question_type()` returning a tibble with `variable`, `type`, and
   `group` columns
2. `type` values being exactly `"single"`, `"sata"`, or `"battery"`
3. Group numbers being consistent (same `question_preface` → same group)

### For `get_freqs()` `.meta` attribute (existing)

The `.meta$x` entries will include `sata = TRUE/FALSE` via the updated
`.extract_var_meta()`. Export functions can read this directly without
calling `detect_question_type()` when working from `get_freqs()` output.

### For surveytidy (follow-up)

Two changes needed in surveytidy (tracked separately):

1. `select()` cleanup: add `x@metadata@sata[[col]] <- NULL` to the drop loop
2. `.METADATA_ATTR_MAP`: add `sata = "sata"` entry for `mutate()` propagation
