# surveycore Metadata API Update — Formal Specification

**Version:** 2.0
**Date:** March 2026
**Status:** Approved — code review resolved; ready for implementation

---

## Document Purpose

This document is the authoritative specification for the metadata API update to
the `surveycore` package. It covers two new `survey_metadata` fields (`universe`
and `missing_codes`), a unified setter API that consolidates the existing
singular/plural dichotomy, extended extractor functions, a new
`extract_metadata()` summary function, and data frame support across all
setters and extractors. Implementation must follow these rules exactly. Where a
rule is already defined in `code-style.md`, `r-package-conventions.md`, or
`surveycore-conventions.md`, this document references those rules rather than
restating them.

---

## I. Scope

### What This Spec Delivers

| Component | Description |
|-----------|-------------|
| `universe` property on `survey_metadata` | New named list field storing per-variable eligibility text |
| `missing_codes` property on `survey_metadata` | New named list field storing per-variable sentinel codes |
| Unified `set_var_label()` | Single function replacing the old positional-NSE form and `set_variable_labels()` |
| Unified `set_val_labels()` | Single function replacing the old positional-NSE form and `set_value_labels()` |
| Unified `set_question_preface()` | Single function replacing the old positional-NSE form and `set_question_prefaces()` |
| Unified `set_var_note()` | Single function replacing the old positional-NSE form and `set_variable_notes()` |
| `set_universe()` | New setter for universe descriptions |
| `set_missing_codes()` | New setter for missing value sentinel codes |
| Updated `extract_var_label()` | Multi-var support, `format`, `fill` arguments |
| Updated `extract_val_labels()` | Multi-var support, `format`, `fill` arguments |
| Updated `extract_question_preface()` | Multi-var support, `format`, `fill` arguments |
| Updated `extract_var_note()` | Multi-var support, `format`, `fill` arguments |
| `extract_universe()` | New extractor for universe descriptions |
| `extract_missing_codes()` | New extractor for missing value sentinel codes |
| `extract_metadata()` | New summary function returning all metadata fields per variable |
| Data frame support | All setters and extractors accept `data.frame` as `x` |
| Deprecations | `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, `set_variable_notes()` soft-deprecated |

### What This Spec Does NOT Deliver

- Analysis functions applying `missing_codes` (e.g., auto-exclusion of sentinels
  from `get_means()`) — deferred to a later phase
- Computational use of `universe` field — documentation metadata only
- `weighting_history` field changes — reserved for Phase 2.5 (surveywts)
- Tidy-select interface for `var` in setters — setters use named `...` / explicit
  `variable` + content; tidy-select is only for extractors where multi-variable
  selection is the primary use case

### Design Support Matrix

All setters and extractors operate on any object that is a `survey_base`
subclass or a plain `data.frame`.

| Class | Setter support | Extractor support |
|-------|---------------|-------------------|
| `survey_taylor` | Yes | Yes |
| `survey_replicate` | Yes | Yes |
| `survey_twophase` | Yes | Yes |
| `survey_srs` | Yes | Yes |
| `survey_nonprob` | Yes | Yes |
| `data.frame` | Yes (column attributes) | Yes (column attributes) |

---

## II. New `survey_metadata` Fields

### 2.1 `universe`

**Type:** Named list of character scalars.

**Key:** Variable name (character). **Value:** Free-text character string
describing the eligible population for that variable. Example:
`list(party_id = "Registered voters only", income = "Adults 18+ with non-zero earnings")`.

**Default:** `list()`.

**Computational role:** None in this phase. The field is documentation only.
Analysis functions do not read or apply `universe` values.

**Auto-population:** Never. Only set explicitly via `set_universe()`.

**Storage in S7 class:** New property on `survey_metadata`, type
`S7::class_list`.

**Data frame attribute name:** `"universe"` — stored as
`attr(df$party_id, "universe") <- "Registered voters only"`.

### 2.2 `missing_codes`

**Type:** Named list of atomic vectors.

**Key:** Variable name (character). **Value:** An atomic vector of sentinel
codes still present in the data. Named vectors (names = human-readable
descriptions) are preferred but not required. Examples:
- Named: `list(q5 = c("Refused" = 99, "Don't know" = 98))`
- Unnamed: `list(q5 = c(99, 98))`

**Default:** `list()`.

**Computational role:** Storage only in this phase. Analysis functions do not
apply missing codes to filter or recode values. A future spec will define
auto-exclusion behavior.

**Auto-population:** Never. Only set explicitly via `set_missing_codes()`.

**Validation:** Each entry must be an atomic vector (numeric, integer, character,
or logical). List-type entries are rejected with
`surveycore_error_missing_codes_not_vector`.

**Storage in S7 class:** New property on `survey_metadata`, type
`S7::class_list`.

**Data frame attribute name:** `"missing_codes"` — stored as
`attr(df$q5, "missing_codes") <- c("Refused" = 99, "Don't know" = 98)`.

### 2.3 Updated `survey_metadata` Constructor

The `survey_metadata` S7 class in `R/core-classes.R` gains two new properties:

```r
universe      = S7::new_property(S7::class_list, default = quote(list())),
missing_codes = S7::new_property(S7::class_list, default = quote(list()))
```

Both use `default = quote(list())` to match the pattern of the existing
`variable_labels`, `value_labels`, `question_prefaces`, and `notes` properties.
The `@param` documentation block on `survey_metadata` gains corresponding
entries. No S7 validator changes are needed — both fields accept any list
content (field-level validation is the setter's responsibility).

---

## III. Architecture

### 3.1 File Changes

| File | Change |
|------|--------|
| `R/core-classes.R` | Add `universe` and `missing_codes` properties to `survey_metadata` |
| `R/core-metadata.R` | Replace/update all setter and extractor functions; add `extract_metadata()`; add `.check_is_survey_or_df()`, `.resolve_vars()`, `.parse_setter_input()`, `.format_scalar_result()`, `.format_list_result()` internal helpers |
| `man/survey_metadata.Rd` | Regenerated by `devtools::document()` |
| `man/set_var_label.Rd` | Regenerated — new signature |
| (and other `man/` files) | Regenerated for all changed functions |

No new files are created. All changes land in the existing two files.

### 3.2 Internal Helpers (new or changed)

All helpers are defined at the top of `R/core-metadata.R` before their first
call site (single-file helpers per `code-style.md §4`).

#### `.check_is_survey_or_df(x, call)`

Replaces `.check_is_survey()` for all functions that gain data frame support.
All functions in this spec gain data frame support, so `.check_is_survey()` has
no remaining callers in `core-metadata.R` after implementation.

**Implementer action:** Before writing any code, search the entire codebase for
`.check_is_survey()` call sites (e.g., `grep -r ".check_is_survey(" R/`). If
no call sites exist outside `core-metadata.R`, remove `.check_is_survey()` from
`core-metadata.R` in the same PR. If call sites exist elsewhere (e.g.,
`infer_question_prefaces()` or other functions not updated by this spec), leave
`.check_is_survey()` in place and do not remove it.

```r
.check_is_survey_or_df <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base) && !is.data.frame(x)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a survey design object or a data frame,",
          " not {.cls {class(x)[[1L]]}}."
        ),
        "v" = paste0(
          "Create a survey object with {.fn as_survey},",
          " {.fn as_survey_replicate}, or {.fn as_survey_twophase}."
        )
      ),
      class = "surveycore_error_not_survey_or_df",
      call  = call
    )
  }
  invisible(NULL)
}
```

#### `.get_data_cols(x)`

Returns the names of columns available for variable validation. For survey
objects, returns `names(x@data)`. For data frames, returns `names(x)`.

```r
.get_data_cols <- function(x) {
  if (is.data.frame(x)) names(x) else names(x@data)
}
```

#### `.get_metadata(x)`

Returns the `survey_metadata` object for survey design objects; returns `NULL`
for data frames (which store metadata as column attributes, not in a
centralized object). Used internally to route setter logic.

```r
.get_metadata <- function(x) {
  if (S7::S7_inherits(x, survey_base)) x@metadata else NULL
}
```

#### `.parse_setter_input(dots, variable, content, content_arg_name, call)`

Shared parsing logic for all unified setters. Receives `dots` as an **evaluated
list** captured via `rlang::list2(...)` at the caller. Does NOT receive
quosures — old positional form detection is the caller's responsibility (see
Section 8.3). Implements the three calling convention detection logic described
in Section IV. Returns a named list mapping variable names to content values.
Errors with `surveycore_error_setter_ambiguous` if both `...` and
`variable`/content are provided; errors with `surveycore_error_setter_empty` if
neither is provided; errors with
`surveycore_error_setter_mismatched_lengths` if `variable` and content have
different lengths (convention 3); errors with
`surveycore_error_setter_mixed_dots` if `...` contains a mix of named and
unnamed elements (Section IX, M-12).

```r
.parse_setter_input <- function(
  dots,              # evaluated list from rlang::list2(...) at the caller
  variable,
  content,
  content_arg_name,
  content_type = c("scalar", "vector"),  # "scalar" for char setters; "vector" for list/code setters
  call = rlang::caller_env()
)
```

`content_type` controls Convention 2 detection:
- `"scalar"`: Convention 2 is a single unnamed element in `dots` that is a
  named **character vector**. Used by `set_var_label()`, `set_question_preface()`,
  `set_var_note()`, `set_universe()`.
- `"vector"`: Convention 2 is a single unnamed element in `dots` that is a
  named **list** (of vectors). Used by `set_val_labels()`, `set_missing_codes()`.

Returns a named list where names are variable name strings and values are the
content to set (character scalars, named vectors, etc. — depends on the field).
**`NULL` values are allowed** in the returned list and signal key deletion: each
setter that receives `list(age = NULL)` must remove `"age"` from the
corresponding metadata field (e.g., `x@metadata@variable_labels[["age"]] <- NULL`).
Convention 3 cannot produce `NULL` values via `variable` + character/list
content args (use Convention 1 or 2 to pass `NULL` for deletion).

#### `.format_scalar_result(result_list, format, empty_value)`

Converts a named list of scalar metadata values into the requested output
format. Used by `extract_var_label()`, `extract_question_preface()`,
`extract_var_note()`, and `extract_universe()`.

```r
.format_scalar_result <- function(
  result_list,  # named list of character scalars (or NAs)
  format,       # "named_vector", "list", or "data_frame"
  col_name,     # name of the content column in data_frame output
  empty_value   # NA_character_ or NULL
)
```

#### `.format_list_result(result_list, format, fn_name)`

Converts a named list of vector metadata values into the requested output
format. Used by `extract_val_labels()` and `extract_missing_codes()`.

```r
.format_list_result <- function(
  result_list,  # named list of named vectors (or NAs/NULLs)
  format,       # "list" or "data_frame"
  fn_name       # "extract_val_labels" or "extract_missing_codes"
)
```

#### `.resolve_vars(x, var_exprs, call)`

Resolves the `var` argument for extractors. Computes available column names
internally via `.get_data_cols(x)`. If `var` is missing (the quosure list has
length 0), returns all column names from `.get_data_cols(x)`. Otherwise,
evaluates the expressions as bare column names or character vectors. Issues
`surveycore_warning_var_not_found` for any specified variable not found in the
available columns and returns only the valid names.

```r
.resolve_vars <- function(
  x,         # survey object or data.frame (used for data-masking context;
             # available columns computed via .get_data_cols(x))
  var_exprs, # list of quosures from ...
  call = rlang::caller_env()
)
```

---

## IV. Setter API

### 4.1 Unified Calling Convention

Each unified setter function accepts one of three calling conventions. The
conventions are detected by inspecting the parsed `...` and the explicit
`variable` / content arguments.

**Convention 1 — Named `...` args:**
```r
set_var_label(svy, age = "Age in years", income = "Annual income")
```
Detection: `rlang::list2(...)` produces a non-empty named list (all elements
named) and `variable` is `NULL`.

**Convention 2 — Single named vector in `...`:**
```r
set_var_label(svy, c(age = "Age in years", income = "Annual income"))
```
Detection: `rlang::list2(...)` produces a list with exactly one unnamed element
that is itself a named vector.

**Convention 3 — Explicit `variable` + content arg:**
```r
set_var_label(
  svy,
  variable = c("age", "income"),
  label    = c("Age in years", "Annual income")
)
```
Detection: `variable` is non-NULL and `...` is empty.

**Ambiguity error:** If both `...` is non-empty AND `variable` is non-NULL,
error with `surveycore_error_setter_ambiguous`.

**Empty error:** If `...` is empty AND `variable` is NULL, error with
`surveycore_error_setter_empty`.

**Length mismatch (convention 3 only):** If `length(variable) != length(content)`,
error with `surveycore_error_setter_mismatched_lengths`.

**Variable not found:** If a variable name appears in the input but not in the
data (`x@data` or `names(x)` for data frames), issue a
`surveycore_warning_var_not_found` warning for each missing variable and skip
it. Do NOT error — this allows safe bulk operations on heterogeneous datasets.

**`!!!` splicing support:** All three conventions support `rlang::list2(...)`
semantics, so `!!!` works with convention 1 and 2 in the `...` position.

**Return:** `invisible(x)` always. The modified object is returned — for survey
objects, the `@metadata` property is updated. For data frames, column
attributes are updated.

### 4.2 Data Frame Setter Behavior

When `x` is a `data.frame`:
- Labels are stored as column attributes (haven-compatible)
- `attr(df$age, "label") <- "Age in years"` — for `set_var_label()`
- `attr(df$sex, "labels") <- c(Male = 1L, Female = 2L)` — for `set_val_labels()`
- `attr(df$q1, "question_preface") <- "Thinking about your health..."` — for `set_question_preface()`
- `attr(df$income, "note") <- "Imputed in 2020 wave"` — for `set_var_note()`
- `attr(df$party_id, "universe") <- "Registered voters only"` — for `set_universe()`
- `attr(df$q5, "missing_codes") <- c("Refused" = 99, "Don't know" = 98)` — for `set_missing_codes()`

When the modified data frame is later passed to `as_survey()`, the constructor
calls `.extract_haven_metadata()` which reads these attributes and populates
the `survey_metadata` object automatically. (`.extract_haven_metadata()` must
be updated to also read `"universe"` and `"missing_codes"` attributes.)

### 4.3 `set_var_label()`

**Purpose:** Set variable label(s) for one or more variables.

**Signature:**
```r
set_var_label(x, ..., variable = NULL, label = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named vector | empty | Convention 1 or 2: bare names = labels (strings). |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `label` | `character` or `NULL` | `NULL` | Convention 3: character vector of labels, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `variable_labels`.
For survey objects, `x@metadata@variable_labels` is updated. For data frames,
`attr(df[[var]], "label")` is updated for each variable.

**Behavior rules:**
- Each label value must be a single character string. Non-character or
  length > 1 values are coerced with a warning (using `as.character()`).
- `NULL` label removes an existing label entry (same as deleting the key from
  the named list).
- Variable not found in data → `surveycore_warning_var_not_found`, skip.

**Examples:**
```r
# Convention 1 — named ... args
svy <- set_var_label(svy, age = "Age in years", income = "Annual income")

# Convention 1 — with !!! splicing
lbls <- list(age = "Age in years", income = "Annual income")
svy <- set_var_label(svy, !!!lbls)

# Convention 2 — single named character vector in ...
svy <- set_var_label(svy, c(age = "Age in years", income = "Annual income"))

# Convention 3 — explicit variable + label
svy <- set_var_label(
  svy,
  variable = c("age", "income"),
  label    = c("Age in years", "Annual income")
)

# Data frame — attributes set haven-compatibly
df <- set_var_label(df, age = "Age in years")
# attr(df$age, "label") == "Age in years"
# as_survey(df, ...) picks up this label automatically

# Pipe-friendly
svy <- svy |>
  set_var_label(age = "Age in years") |>
  set_var_label(income = "Annual income")
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7.

### 4.4 `set_val_labels()`

**Purpose:** Set value labels for one or more variables.

**Signature:**
```r
set_val_labels(x, ..., variable = NULL, labels = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named list | empty | Convention 1 or 2: bare names = named vectors of value labels. |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `labels` | `list` or `NULL` | `NULL` | Convention 3: a list of named vectors, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `value_labels`.
For survey objects, `x@metadata@value_labels` is updated. For data frames,
`attr(df[[var]], "labels")` is updated (haven-compatible attribute name).

**Behavior rules:**
- Each labels entry must be a fully named vector — `is.null(names(entry)) ||
  any(names(entry) == "")` triggers `surveycore_error_labels_unnamed`.
- Extra labels (codes not present in the data) are silently allowed.
- Observed values without a label trigger `surveycore_warning_missing_labels`
  (same as existing behavior).
- `NULL` labels value removes the entry for that variable.
- Variable not found in data → `surveycore_warning_var_not_found`, skip.

**Convention 3 for `labels`:** `labels` argument must be a list of named
vectors (one per variable). A bare named vector (not wrapped in a list) for a
single variable is accepted when `length(variable) == 1L`.

**Examples:**
```r
# Convention 1 — named ... args
svy <- set_val_labels(
  svy,
  sex    = c(Male = 1L, Female = 2L),
  region = c(Northeast = 1L, South = 2L, Midwest = 3L, West = 4L)
)

# Convention 1 — with !!! splicing
all_labels <- list(
  sex    = c(Male = 1L, Female = 2L),
  region = c(Northeast = 1L, South = 2L, Midwest = 3L, West = 4L)
)
svy <- set_val_labels(svy, !!!all_labels)

# Convention 2 — single named list in ...
svy <- set_val_labels(
  svy,
  list(sex = c(Male = 1L, Female = 2L), region = c(Northeast = 1L, South = 2L))
)

# Convention 3 — explicit variable + labels
svy <- set_val_labels(
  svy,
  variable = c("sex", "region"),
  labels   = list(c(Male = 1L, Female = 2L), c(Northeast = 1L, South = 2L))
)

# Data frame — haven-compatible attribute
df <- set_val_labels(df, sex = c(Male = 1L, Female = 2L))
# attr(df$sex, "labels") == c(Male = 1L, Female = 2L)
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7, M-8, M-9.

### 4.5 `set_question_preface()`

**Purpose:** Set question preface text for one or more variables.

**Signature:**
```r
set_question_preface(x, ..., variable = NULL, preface = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named vector | empty | Convention 1 or 2: bare names = preface strings. |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `preface` | `character` or `NULL` | `NULL` | Convention 3: character vector of preface strings, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `question_prefaces`.
For survey objects, `x@metadata@question_prefaces` is updated. For data frames,
`attr(df[[var]], "question_preface")` is updated.

**Behavior rules:**
- Each preface value must be a single character string.
- `NULL` preface removes the entry for that variable.
- Variable not found in data → `surveycore_warning_var_not_found`, skip.

**Examples:**
```r
# Convention 1 — set the same preface for a battery of related questions
battery_preface <- "Now I'll ask you a few questions about your health..."
svy <- set_question_preface(
  svy,
  health_general    = battery_preface,
  health_physical   = battery_preface,
  health_mental     = battery_preface,
  health_social     = battery_preface
)

# Convention 2 — named character vector
svy <- set_question_preface(
  svy,
  c(q1 = "Thinking about the past 30 days...",
    q2 = "Thinking about the past 30 days...")
)

# Convention 3 — programmatic, from a data frame of metadata
meta_df <- data.frame(
  variable = c("q1", "q2", "q3"),
  preface  = c("Past 30 days...", "Past 30 days...", "Overall...")
)
svy <- set_question_preface(
  svy,
  variable = meta_df$variable,
  preface  = meta_df$preface
)
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7.

### 4.6 `set_var_note()`

**Purpose:** Set analyst notes for one or more variables.

**Signature:**
```r
set_var_note(x, ..., variable = NULL, note = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named vector | empty | Convention 1 or 2: bare names = note strings. |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `note` | `character` or `NULL` | `NULL` | Convention 3: character vector of notes, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `notes`.
For survey objects, `x@metadata@notes` is updated. For data frames,
`attr(df[[var]], "note")` is updated.

**Behavior rules:**
- `NULL` note removes the entry for that variable.
- Variable not found in data → `surveycore_warning_var_not_found`, skip.

**Examples:**
```r
# Convention 1
svy <- set_var_note(
  svy,
  income  = "Imputed using hot-deck for 2020 wave; flag in income_imputed",
  bpxsy1  = "Top-coded at 200 mm Hg in public-use file"
)

# Convention 3 — attach notes from an external codebook
codebook <- readr::read_csv("codebook.csv")  # has columns: variable, note
svy <- set_var_note(
  svy,
  variable = codebook$variable,
  note     = codebook$note
)
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7.

### 4.7 `set_universe()`

**Purpose:** Set universe (eligibility) descriptions for one or more variables.

**Signature:**
```r
set_universe(x, ..., variable = NULL, universe = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named vector | empty | Convention 1 or 2: bare names = universe strings. |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `universe` | `character` or `NULL` | `NULL` | Convention 3: character vector of universe descriptions, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `universe` in
`@metadata`. For data frames, `attr(df[[var]], "universe")` is updated.

**Behavior rules:**
- `NULL` universe removes the entry for that variable.
- Variable not found in data → `surveycore_warning_var_not_found`, skip.
- Universe strings are documentation only — no computational validation is
  applied to their content.

**Examples:**
```r
# Convention 1
svy <- set_universe(
  svy,
  party_id     = "Registered voters only",
  job_approval = "Adults 18+ who have heard of the respondent in the question"
)

# Convention 2
svy <- set_universe(svy, c(
  party_id     = "Registered voters only",
  job_approval = "Adults 18+ who have heard of the respondent in the question"
))

# Convention 3
svy <- set_universe(
  svy,
  variable = c("party_id", "job_approval"),
  universe = c("Registered voters only", "Adults 18+")
)
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7.

### 4.8 `set_missing_codes()`

**Purpose:** Set missing value sentinel codes for one or more variables.

**Signature:**
```r
set_missing_codes(x, ..., variable = NULL, codes = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to modify. |
| `...` | named args or single named list | empty | Convention 1 or 2: bare names = atomic vectors of sentinel codes. |
| `variable` | `character` or `NULL` | `NULL` | Convention 3: character vector of variable names. |
| `codes` | `list` or `NULL` | `NULL` | Convention 3: a list of atomic vectors, parallel to `variable`. |

**Output contract:** Returns `x` invisibly with updated `missing_codes`.
For survey objects, `x@metadata@missing_codes` is updated. For data frames,
`attr(df[[var]], "missing_codes")` is updated.

**Behavior rules:**
- Each codes entry must be an atomic vector (numeric, integer, character, or
  logical). A list entry triggers `surveycore_error_missing_codes_not_vector`.
- Named vectors (names = descriptions) are stored as-is. Unnamed vectors are
  also valid.
- `NULL` codes removes the entry for that variable.
- Variable not found in data → `surveycore_warning_var_not_found`, skip.
- No validation is done to check whether the sentinel values are actually
  present in the data. Presence checking is deferred to a future phase.

**Examples:**
```r
# Convention 1 — named sentinel codes (recommended)
svy <- set_missing_codes(
  svy,
  q5     = c("Refused" = 99L, "Don't know" = 98L, "Not applicable" = 97L),
  income = c("Refused" = -1L, "Don't know" = -2L)
)

# Convention 1 — unnamed codes (acceptable)
svy <- set_missing_codes(svy, q5 = c(99L, 98L, 97L))

# Convention 3 — programmatic setup
sentinel_list <- list(
  q5     = c("Refused" = 99L, "Don't know" = 98L),
  income = c("Refused" = -1L, "Don't know" = -2L)
)
svy <- set_missing_codes(
  svy,
  variable = names(sentinel_list),
  codes    = sentinel_list
)
```

**Error / warning rows:** See Section IX, rows M-1, M-3, M-4, M-5, M-7, M-10.

---

## V. Extractor API

### 5.1 Shared `var`, `format`, and `fill` Behavior

**`var` argument (all extractors):**

`var` is optional in all extractors. When omitted, the function returns
metadata for ALL variables in the object (the full `@data` column set for
survey objects, or all `names(x)` for data frames). When provided, `var`
accepts:
- One or more bare column names: `extract_var_label(svy, age, income)`
- A character vector via convention: `extract_var_label(svy, c("age", "income"))`

Variables specified in `var` that do not exist in the data issue a
`surveycore_warning_var_not_found` warning and are skipped (not included in
the result).

When `var` is omitted and there are many columns (e.g., 50+), the function
still returns all — no truncation or pagination is applied.

**`fill` argument:**

Controls treatment of variables that have no metadata set for the requested
field.

| `fill` value | Behavior |
|-------------|----------|
| `NULL` (default) | Variables with no metadata are OMITTED from the result. |
| `NA_character_` | Variables with no metadata are INCLUDED with the value `NA`. For `"named_vector"` output: `NA_character_`. For `"list"` output: `NULL` (since `NA` is not a meaningful list value for vector fields). For `"data_frame"` output: `NA` in the content column. |

**Note on `fill = NA_character_` in `"list"` format:** Users who pass
`fill = NA_character_` with `format = "list"` will receive `NULL` entries for
variables without metadata — not `NA_character_`. This is intentional: `NA`
has no meaningful interpretation as a placeholder for a named vector field (e.g.,
value labels). The `NULL` signals "no labels set" consistently with R list
semantics. If you need `NA` placeholders, use `format = "data_frame"`.

**`format` argument:**

Controls the output structure. Valid values depend on the function — see
per-function specs. Invalid values trigger `surveycore_error_format_invalid`.

### 5.2 `extract_var_label()`

**Purpose:** Extract variable labels.

**Signature:**
```r
extract_var_label(x, ..., format = "named_vector", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"named_vector"` | Output format. One of `"named_vector"`, `"list"`, `"data_frame"`. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no label; `NULL` omits them. |

**Valid `format` values:** `"named_vector"`, `"list"`, `"data_frame"`.

**Output contract:**
- `"named_vector"`: `c(age = "Age in years", income = "Annual income")` —
  named character vector. Empty result: `character(0)` with no names.
- `"list"`: `list(age = "Age in years", income = "Annual income")` — named
  list. Empty result: `list()`.
- `"data_frame"`: tibble with columns `variable` (character), `label`
  (character). Empty result: zero-row tibble with correct column types.

**For data frames:** Reads `attr(df[[var]], "label")` for each variable.

**Examples:**
```r
# All variables with labels (omit unlabeled — default)
extract_var_label(svy)
#> c(age = "Age in years", income = "Annual income", sex = "Sex of respondent")

# Specific variables
extract_var_label(svy, age, income)
#> c(age = "Age in years", income = "Annual income")

# Include unlabeled variables as NA
extract_var_label(svy, fill = NA_character_)
#> c(age = "Age in years", income = "Annual income", psu = NA_character_, ...)

# Data frame format
extract_var_label(svy, format = "data_frame")
#> # A tibble: 3 × 2
#>   variable label
#>   <chr>    <chr>
#> 1 age      Age in years
#> 2 income   Annual income
#> 3 sex      Sex of respondent
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

### 5.3 `extract_val_labels()`

**Purpose:** Extract value label vectors.

**Signature:**
```r
extract_val_labels(x, ..., format = "list", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"list"` | Output format. One of `"list"`, `"data_frame"`. `"named_vector"` is NOT valid. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no value labels; `NULL` omits them. |

**Valid `format` values:** `"list"`, `"data_frame"`.

**Output contract:**
- `"list"` (default): `list(sex = c(Male = 1L, Female = 2L), race = c(...))`.
  Empty result: `list()`.
- `"data_frame"`: long-format tibble with columns `variable` (character),
  `label` (character), `value` (character — codes coerced to character for
  consistent typing across mixed-type designs). One row per label-code pair.
  Empty result: zero-row tibble with columns `variable` (chr), `label` (chr),
  `value` (chr).

**Note on `"named_vector"` format:** Not valid for `extract_val_labels()` or
`extract_missing_codes()` because the value for each variable is itself a
vector; collapsing to a single named vector would conflate variable names and
label names.

**For data frames:** Reads `attr(df[[var]], "labels")` for each variable.

**Examples:**
```r
# All variables with value labels (list format — default)
extract_val_labels(svy)
#> $sex
#> Male Female
#>    1      2
#>
#> $region
#> Northeast    South  Midwest     West
#>         1        2        3        4

# Specific variable
extract_val_labels(svy, sex)
#> $sex
#> Male Female
#>    1      2

# Data frame format — long, one row per code
extract_val_labels(svy, sex, region, format = "data_frame")
#> # A tibble: 6 × 3
#>   variable label     value
#>   <chr>    <chr>     <chr>
#> 1 sex      Male      1
#> 2 sex      Female    2
#> 3 region   Northeast 1
#> 4 region   South     2
#> 5 region   Midwest   3
#> 6 region   West      4
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

### 5.4 `extract_question_preface()`

**Purpose:** Extract question preface text.

**Signature:**
```r
extract_question_preface(x, ..., format = "named_vector", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"named_vector"` | Output format. One of `"named_vector"`, `"list"`, `"data_frame"`. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no preface; `NULL` omits them. |

**Output contract:**
- `"named_vector"`: named character vector, names = variable names.
- `"list"`: named list of character scalars.
- `"data_frame"`: tibble with columns `variable` (chr), `preface` (chr).

**For data frames:** Reads `attr(df[[var]], "question_preface")`.

**Examples:**
```r
extract_question_preface(svy)
#> c(q1 = "Now I'll ask about your health...",
#>   q2 = "Now I'll ask about your health...",
#>   q3 = "Now I'll ask about your health...")

extract_question_preface(svy, format = "data_frame")
#> # A tibble: 3 × 2
#>   variable preface
#>   <chr>    <chr>
#> 1 q1       Now I'll ask about your health...
#> 2 q2       Now I'll ask about your health...
#> 3 q3       Now I'll ask about your health...
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

### 5.5 `extract_var_note()`

**Purpose:** Extract analyst notes.

**Signature:**
```r
extract_var_note(x, ..., format = "named_vector", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"named_vector"` | Output format. One of `"named_vector"`, `"list"`, `"data_frame"`. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no note; `NULL` omits them. |

**Output contract:**
- `"named_vector"`: named character vector.
- `"list"`: named list of character scalars.
- `"data_frame"`: tibble with columns `variable` (chr), `note` (chr).

**For data frames:** Reads `attr(df[[var]], "note")`.

**Examples:**
```r
extract_var_note(svy)
#> c(income  = "Imputed for 2020 wave",
#>   bpxsy1  = "Top-coded at 200 mm Hg")

extract_var_note(svy, income, format = "list")
#> $income
#> [1] "Imputed for 2020 wave"
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

### 5.6 `extract_universe()`

**Purpose:** Extract universe (eligibility) descriptions.

**Signature:**
```r
extract_universe(x, ..., format = "named_vector", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"named_vector"` | Output format. One of `"named_vector"`, `"list"`, `"data_frame"`. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no universe; `NULL` omits them. |

**Output contract:**
- `"named_vector"`: named character vector.
- `"list"`: named list of character scalars.
- `"data_frame"`: tibble with columns `variable` (chr), `universe` (chr).

**For data frames:** Reads `attr(df[[var]], "universe")`.

**Examples:**
```r
extract_universe(svy)
#> c(party_id     = "Registered voters only",
#>   job_approval = "Adults 18+ who have heard of the respondent")

extract_universe(svy, party_id, format = "data_frame")
#> # A tibble: 1 × 2
#>   variable  universe
#>   <chr>     <chr>
#> 1 party_id  Registered voters only
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

### 5.7 `extract_missing_codes()`

**Purpose:** Extract missing value sentinel codes.

**Signature:**
```r
extract_missing_codes(x, ..., format = "list", fill = NULL)
```

**Argument table:**

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to extract. If empty, all variables. |
| `format` | `character(1)` | `"list"` | Output format. One of `"list"`, `"data_frame"`. `"named_vector"` is NOT valid. |
| `fill` | scalar or `NULL` | `NULL` | Value for variables with no codes; `NULL` omits them. |

**Valid `format` values:** `"list"`, `"data_frame"`.

**Output contract:**
- `"list"` (default): `list(q5 = c("Refused" = 99, "Don't know" = 98))`.
  Unnamed vector entries are returned as-is.
  Empty result: `list()`.
- `"data_frame"`: long-format tibble with columns `variable` (chr),
  `description` (chr, `NA` if the codes vector is unnamed), `code` (chr —
  coerced from original type for consistent column typing). One row per code.
  Empty result: zero-row tibble with columns `variable` (chr),
  `description` (chr), `code` (chr).

**For data frames:** Reads `attr(df[[var]], "missing_codes")`.

**Examples:**
```r
extract_missing_codes(svy)
#> $q5
#> Refused Don't know Not applicable
#>      99         98             97

extract_missing_codes(svy, q5, income, format = "data_frame")
#> # A tibble: 5 × 3
#>   variable description    code
#>   <chr>    <chr>          <chr>
#> 1 q5       Refused        99
#> 2 q5       Don't know     98
#> 3 q5       Not applicable 97
#> 4 income   Refused        -1
#> 5 income   Don't know     -2
```

**Error / warning rows:** See Section IX, rows M-1, M-2, M-6.

---

## VI. `extract_metadata()`

### 6.1 Purpose

Returns a per-variable summary of all metadata fields in a single call.
Useful for auditing a design object's metadata state, for populating report
codebooks, or for passing to external metadata management tools.

### 6.2 Signature

```r
extract_metadata(x, ..., fill = NULL)
```

### 6.3 Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | survey object or `data.frame` | required | The object to query. |
| `...` | bare names or missing | empty | Variables to include. If empty, all variables. |
| `fill` | `NULL` or `"include"` | `NULL` | Controls whether variables with no metadata in any field are returned. `NULL` (default) omits variables where all six metadata fields are `NULL` (and `transformations` is `list()`). `"include"` returns all variables regardless of whether they have any metadata — useful for structural audits. Note: `extract_metadata()` does NOT have a `format` argument; the output structure is always a named list. |

`fill = "include"` is equivalent to the old always-include behavior. The
default `fill = NULL` follows the same "omit unset variables" convention as
all other extractors.

### 6.4 Output Contract

**Type:** Named list.
**Length:** One entry per variable (after resolving `var`).
**Names:** Variable names (character).
**Each entry:** A named list with the following keys in this order:

```
variable_label    — character scalar or NULL
value_labels      — named vector or NULL
question_preface  — character scalar or NULL
note              — character scalar or NULL
universe          — character scalar or NULL
missing_codes     — named or unnamed vector or NULL
transformations   — list (may be empty list(), never NULL)
```

Note: `weighting_history` is intentionally excluded (reserved for Phase 2.5).

**For variables with no metadata set in any field (all six fields `NULL`,
`transformations = list()`):**
- `fill = NULL` (default): the variable is **omitted** from the result.
- `fill = "include"`: the variable is **included** with all fields `NULL` and
  `transformations = list()`.

**Non-existent variables in `...`:** Issue `surveycore_warning_var_not_found`
and skip.

### 6.5 Behavior Rules

- `fill = NULL` (default): variables where all six metadata fields are NULL and
  `transformations = list()` are omitted from the result. Variables with at
  least one non-NULL metadata field are included.
- `fill = "include"`: all specified variables (or all columns if `...` omitted)
  are returned regardless of whether they have any metadata. This is the
  structural audit mode.
- `transformations` is always `list()` for variables with no recorded
  transformations, not `NULL`.
- Order of entries follows the order of columns in `x@data` (or `names(x)` for
  data frames) unless specific variables are requested via `...`, in which case
  the order matches the order variables were specified.
- For data frames: reads column attributes for each variable (`"label"`,
  `"labels"`, `"question_preface"`, `"note"`, `"universe"`,
  `"missing_codes"`). The `transformations` field is always `list()` for
  data frames (no transformation tracking on raw data frames).

### 6.6 Console Output Example

```r
# ns_wave1 already has rich metadata (labels, question_prefaces, value labels)
# Add universe and missing_codes to demonstrate new fields
d <- as_survey_nonprob(ns_wave1, weights = weight)
d <- set_universe(d, group_favorability_blacks = "All adults 18+")
d <- set_missing_codes(d, group_favorability_blacks = c("Refused" = -1L, "Don't know" = -2L))
d <- set_var_note(d, group_favorability_blacks = "7-point favorability thermometer")

extract_metadata(d, group_favorability_blacks, pid3)
#> $group_favorability_blacks
#> $group_favorability_blacks$variable_label
#> [1] "Favorability: Blacks"
#>
#> $group_favorability_blacks$value_labels
#> Very unfavorable         2         3         4         5         6 Very favorable
#>              1         2         3         4         5         6              7
#>
#> $group_favorability_blacks$question_preface
#> [1] "Now I'd like to get your feelings toward some groups..."
#>
#> $group_favorability_blacks$note
#> [1] "7-point favorability thermometer"
#>
#> $group_favorability_blacks$universe
#> [1] "All adults 18+"
#>
#> $group_favorability_blacks$missing_codes
#> Refused Don't know
#>      -1         -2
#>
#> $group_favorability_blacks$transformations
#> list()
#>
#>
#> $pid3
#> $pid3$variable_label
#> [1] "Party identification (3-category)"
#>
#> $pid3$value_labels
#> Democrat Independent Republican
#>        1          2          3
#>
#> $pid3$question_preface
#> NULL
#>
#> $pid3$note
#> NULL
#>
#> $pid3$universe
#> NULL
#>
#> $pid3$missing_codes
#> NULL
#>
#> $pid3$transformations
#> list()
```

### 6.7 Export

`extract_metadata()` is exported. It carries `@family metadata` and `@export`
roxygen2 tags.

---

## VII. Data Frame Support

### 7.1 Rationale

Allowing setters to operate on plain data frames lets users annotate their
data before passing it to a survey constructor. When `as_survey()` (or related
constructors) is subsequently called, `.extract_haven_metadata()` reads these
column attributes and populates the `survey_metadata` object automatically.
This pattern eliminates the need to re-annotate after construction.

### 7.2 Attribute Mapping

| Metadata field | Column attribute name | Haven compatibility |
|----------------|----------------------|---------------------|
| `variable_labels` | `"label"` | Yes — matches `haven::var_label()` |
| `value_labels` | `"labels"` | Yes — matches `haven::val_labels()` |
| `question_prefaces` | `"question_preface"` | No — surveycore extension |
| `notes` | `"note"` | No — surveycore extension |
| `universe` | `"universe"` | No — surveycore extension |
| `missing_codes` | `"missing_codes"` | Partial — haven uses `"na_values"` for missing, but codes vector structure differs |

### 7.3 `.extract_haven_metadata()` Update

The existing `.extract_haven_metadata()` internal helper in `R/core-metadata.R`
must be updated to also extract `"universe"` and `"missing_codes"` column
attributes. The logic follows the same pattern as the existing attribute reads:

- Read `attr(col, "universe", exact = TRUE)` — store if non-NULL character scalar
- Read `attr(col, "missing_codes", exact = TRUE)` — store if non-NULL atomic vector

**Confirm all six fields are read:** Before implementation, verify that
`.extract_haven_metadata()` already reads all four existing attributes:
`"label"`, `"labels"`, `"question_preface"`, and `"note"`. If `"note"` is not
currently read, add it in the same PR. The `survey_metadata()` constructor call
at the end of `.extract_haven_metadata()` must pass all six fields (the four
existing plus the two new ones).

### 7.4 Extractor Behavior on Data Frames

All extractors read column attributes directly when `x` is a data frame.
There is no `survey_metadata` object to query. The attribute name mapping from
Section 7.2 defines which attribute each extractor reads.

For `extract_metadata()` on data frames, `transformations` is always `list()`
(data frames have no transformation tracking mechanism).

### 7.5 Round-trip Guarantee

The following round-trip must hold exactly (tested in Section X):

```r
df  <- data.frame(age = c(25L, 40L, 55L), sex = c(1L, 2L, 1L))
df  <- set_var_label(df, age = "Age in years", sex = "Sex of respondent")
df  <- set_val_labels(df, sex = c(Male = 1L, Female = 2L))
df  <- set_question_preface(df, age = "Now I'll ask about your demographics...")
df  <- set_var_note(df, age = "Collected at intake")
df  <- set_universe(df, age = "All adults 18+")
df  <- set_missing_codes(df, sex = c("Refused" = 9L))

svy <- as_survey(df, weights = NULL)

extract_var_label(svy, age)         # c(age = "Age in years")
extract_var_label(svy, sex)         # c(sex = "Sex of respondent")
extract_val_labels(svy, sex)        # list(sex = c(Male = 1L, Female = 2L))
extract_question_preface(svy, age)  # c(age = "Now I'll ask about your demographics...")
extract_var_note(svy, age)          # c(age = "Collected at intake")
extract_universe(svy, age)          # c(age = "All adults 18+")
extract_missing_codes(svy, sex)     # list(sex = c("Refused" = 9L))
```

---

## VIII. Deprecations

### 8.1 Deprecated Functions

The following four plural setter functions are deprecated using
`lifecycle::deprecate_soft()`. They continue to work during the deprecation
period but emit a deprecation warning on each call.

| Deprecated function | Replacement |
|--------------------|-------------|
| `set_variable_labels(x, ...)` | `set_var_label(x, ...)` |
| `set_value_labels(x, ...)` | `set_val_labels(x, ...)` |
| `set_question_prefaces(x, ...)` | `set_question_preface(x, ...)` |
| `set_variable_notes(x, ...)` | `set_var_note(x, ...)` |

### 8.2 Deprecation Warning Pattern

Each deprecated function body is replaced with:

```r
set_variable_labels <- function(x, ...) {
  lifecycle::deprecate_soft(
    when  = "0.5.0",
    what  = "set_variable_labels()",
    with  = "set_var_label()",
    details = paste0(
      "set_var_label() accepts the same named ... syntax:\n",
      "  set_var_label(x, age = 'Age in years', income = 'Annual income')"
    )
  )
  set_var_label(x, ...)
}
```

The `when` argument uses the package version in which this spec is first
implemented (to be filled in at release time; use `"0.5.0"` as a placeholder).

The functions are NOT removed in this spec. They remain in `R/core-metadata.R`
as thin wrappers calling the unified setter.

### 8.3 Breaking Change: Old Positional NSE Setter Form

The old calling form `set_var_label(svy, age, "Age in years")` with three
positional arguments (where the second is a bare symbol) is a **breaking
change** in this spec. The new signature for `set_var_label()` is
`set_var_label(x, ..., variable = NULL, label = NULL)`. In the new form, the
second positional argument falls into `...` and is interpreted as convention 1
(named `...` args) or convention 2 (single named vector). A bare unquoted
symbol passed as `age` in `...` without a name (i.e., `set_var_label(svy, age,
"Age in years")`) would create an unnamed `...` entry that is not a named
vector — this triggers `surveycore_error_setter_empty` (neither convention
detects a valid input when an unnamed symbol and a string are passed as
separate positional args).

**Detection and error message:** Each setter captures `...` as quosures via
`rlang::enquos(...)` **before** evaluating them, and checks for the old
positional form at the top of the function body — before passing evaluated
values to `.parse_setter_input()`. Detection condition: the quosures list has
exactly two elements where the first is an unquoted symbol
(`rlang::is_symbol(rlang::quo_get_expr(qs[[1L]]))`) and the second is a scalar
string with no name. If detected, issue a targeted error with class
`surveycore_error_old_positional_setter` immediately (do not call
`.parse_setter_input()`). Only after passing this check should the setter
evaluate `...` via `rlang::list2(...)` and proceed to `.parse_setter_input()`.

```
x  The old positional calling form set_var_label(x, age, "label") is no
   longer supported.
i  The new unified setter uses named arguments.
v  Use set_var_label(x, age = "label") instead.
```

**NEWS.md entry:** The following breaking changes must be documented in a
`### Breaking Changes` section of NEWS.md for the release that includes this
spec:
1. Old positional setter form `set_var_label(svy, age, "label")` removed.
2. `extract_var_label()` and all scalar extractors now return a named vector
   (or list/data_frame per `format`) instead of a plain character scalar for
   single-variable calls.
3. `extract_val_labels()` now returns a named list (or data_frame per
   `format`) instead of a bare named vector for single-variable calls.

### 8.4 `lifecycle` Dependency

`lifecycle` must be added to `Imports` in `DESCRIPTION` if not already
present. Version minimum: `lifecycle (>= 1.0.0)`.

---

## IX. Error and Warning Table

All new error and warning classes introduced by this spec. Existing classes
(rows 27–30 from `plans/error-messages.md`) are reused where applicable and
noted.

| # | Function(s) | Condition | Level | Class | cli Message Template |
|---|-------------|-----------|-------|-------|----------------------|
| M-1 | all setters, all extractors, `extract_metadata()` | `x` is neither a survey design object nor a `data.frame` | ERROR | `surveycore_error_not_survey_or_df` | `"x" = "{.arg x} must be a survey design object or a data frame, not {.cls {class(x)[[1L]]}}."` (existing class from error-messages.md row 78 — reuse) |
| M-2 | all extractors, `extract_metadata()` | A variable specified in `...` does not exist in the data | WARN | `surveycore_warning_var_not_found` | `"!" = "{length(missing)} variable{?s} not found in {.arg x} and {?was/were} skipped: {.field {missing}}."` |
| M-3 | all setters | Both `...` and explicit `variable`/content args are provided simultaneously | ERROR | `surveycore_error_setter_ambiguous` | `"x" = "Provide variable names via {.arg ...} or via {.arg variable}, not both.", "i" = "Use named {.arg ...} args, a named vector in {.arg ...}, or {.arg variable} + {.arg {content_arg}} — not a mix."` |
| M-4 | all setters | Neither `...` nor `variable`/content args are provided | ERROR | `surveycore_error_setter_empty` | `"x" = "{.fn {fn_name}} requires at least one variable-label pair.", "v" = "Use named {.arg ...} args: {.code {fn_name}(x, age = 'Age in years')}."` |
| M-5 | all setters (convention 3) | `length(variable) != length(content)` | ERROR | `surveycore_error_setter_mismatched_lengths` | `"x" = "{.arg variable} has {length(variable)} element{?s} but {.arg {content_arg}} has {length(content)} element{?s}.", "i" = "They must be the same length (one content value per variable name)."` |
| M-6 | all extractors | `format` argument has an invalid value | ERROR | `surveycore_error_format_invalid` | `"x" = '{.arg format} must be one of {.val {valid_formats}}, not {.val {format}}.', "i" = "Got: {.val {format}}."` |
| M-7 | all setters | A variable specified in input is not found in `x@data` / `names(x)` | WARN | `surveycore_warning_var_not_found` | `"!" = "{length(missing)} variable{?s} not found in {.arg x} and {?was/were} skipped: {.field {missing}}.", "i" = "Check spelling. Available columns: {.field {head(all_cols, 10)}}{?.}"` |
| M-8 | `set_val_labels()`, `set_value_labels()` (deprecated) | A labels entry is not a fully named vector | ERROR | `surveycore_error_labels_unnamed` | `"x" = "Value labels for {.field {var_name}} must be a fully named vector.", "i" = "All elements must have names (e.g., {.code c(Male = 1L, Female = 2L)})."` (existing class — reuse row 29) |
| M-9 | `set_val_labels()` | Some observed data values have no corresponding label | WARN | `surveycore_warning_missing_labels` | `"!" = "Not all values of {.field {var_name}} are labeled.", "i" = "Unlabeled values: {.val {missing}}."` (existing class — reuse row 30) |
| M-10 | `set_missing_codes()` | A `codes` entry is not an atomic vector | ERROR | `surveycore_error_missing_codes_not_vector` | `"x" = "Missing codes for {.field {var_name}} must be an atomic vector, not {.cls {class(codes_entry)[[1L]]}}.", "i" = "Use a numeric, integer, or character vector (e.g., {.code c(Refused = 99L, {\"Don't know\"} = 98L)})."` |
| M-11 | `set_var_label()` | Old positional NSE form detected | ERROR | `surveycore_error_old_positional_setter` | `"x" = "The old positional calling form {.code {fn_name}(x, var, content)} is no longer supported.", "i" = "The new unified setter uses named arguments.", "v" = "Use {.code {fn_name}(x, {var_name} = {.val {content_val}})} instead."` |
| M-12 | all setters | `...` contains a mix of named and unnamed elements (matches no convention) | ERROR | `surveycore_error_setter_mixed_dots` | `"x" = "All {.arg ...} arguments must be named when using Convention 1.", "i" = "Got {sum(nzchar(names(dots)))} named and {sum(!nzchar(names(dots)))} unnamed element{?s}.", "v" = "Use {.code {fn_name}(x, age = 'Age', income = 'Annual income')} or a fully named vector."` |

**Notes:**
- M-2 and M-7 use the same warning class `surveycore_warning_var_not_found`
  because both represent "variable name present in input but not in object."
  The message template differs slightly (extractor context vs. setter context)
  but the class is shared so test infrastructure can match on class alone.
- `surveycore_error_not_survey_or_df` (M-1) already exists in
  `plans/error-messages.md` as row 78 (`infer_question_prefaces()`). Reuse it
  here.
- All new classes must be added to `plans/error-messages.md` before
  implementation begins.

---

## X. Testing Plan

### 10.1 File Mapping

| Source file | Test file |
|-------------|-----------|
| `R/core-classes.R` (new fields on `survey_metadata`) | `tests/testthat/test-s7-classes.R` |
| `R/core-metadata.R` (all setter/extractor changes) | `tests/testthat/test-metadata-system.R` |

All new test blocks are added to the existing test files following their
established section structure.

### 10.2 `survey_metadata` S7 Class Tests (`test-s7-classes.R`)

New blocks required:

- `survey_metadata()` stores `universe` property as empty list by default
- `survey_metadata()` stores `missing_codes` property as empty list by default
- `survey_metadata(universe = list(age = "All adults"))` stores the value correctly
- `survey_metadata(missing_codes = list(q5 = c(99L, 98L)))` stores the value correctly
- Setting `universe` on an existing object via `@` assignment round-trips correctly
- Setting `missing_codes` on an existing object via `@` assignment round-trips correctly

### 10.3 `.check_is_survey_or_df()` Tests

**Test migration note:** All existing `expect_error(class = "surveycore_error_not_survey")`
assertions in `test-metadata-system.R` must be updated to
`class = "surveycore_error_not_survey_or_df"` in the same PR that implements
this spec. Search `test-metadata-system.R` for the old class string before
writing new tests.

- Returns invisibly `NULL` for a `survey_taylor` object
- Returns invisibly `NULL` for a plain `data.frame`
- Errors with `surveycore_error_not_survey_or_df` for a list input
- Errors with `surveycore_error_not_survey_or_df` for a character input
- Snapshot test for the error message text

### 10.4 `.parse_setter_input()` Tests (direct unit tests)

- Convention 1 (named `...`): returns correct named list
- Convention 1 with `!!!` splicing: returns correct named list
- Convention 2 (single named vector in `...`): returns correct named list
- Convention 3 (`variable` + content): returns correct named list
- Convention 3 length mismatch: errors with `surveycore_error_setter_mismatched_lengths`
- Both `...` and `variable` provided: errors with `surveycore_error_setter_ambiguous`
- Neither `...` nor `variable` provided: errors with `surveycore_error_setter_empty`
- Snapshot tests for all three error messages

### 10.5 Unified Setter Tests (`test-metadata-system.R`)

For each of the six setters (`set_var_label`, `set_val_labels`,
`set_question_preface`, `set_var_note`, `set_universe`, `set_missing_codes`):

**Happy path blocks (one per calling convention):**
- Convention 1 sets correct metadata for one variable
- Convention 1 sets correct metadata for multiple variables
- Convention 1 with `!!!` splicing sets correct metadata
- Convention 2 (single named vector) sets correct metadata
- Convention 3 (explicit `variable` + content) sets correct metadata
- Return value is `invisible(x)` (test with `withVisible()`)
- Result survives pipe chain: three consecutive setter calls return valid object
- **NULL deletion (scalar-content setters: `set_var_label`, `set_question_preface`,
  `set_var_note`, `set_universe`):** set a label, then set `NULL` for the same
  variable; verify `!("age" %in% names(x@metadata@variable_labels))` (the key
  is absent, not NULL-valued)
- **NULL deletion (vector-content setters: `set_val_labels`, `set_missing_codes`):**
  set codes, then set `NULL`; verify the key is absent from the metadata list

**Error path blocks:**
- `x` is a list → `surveycore_error_not_survey_or_df` (class + snapshot)
- Both `...` and `variable` provided → `surveycore_error_setter_ambiguous` (class + snapshot)
- Neither provided → `surveycore_error_setter_empty` (class + snapshot)
- Convention 3 length mismatch → `surveycore_error_setter_mismatched_lengths` (class + snapshot)
- Old positional NSE form → `surveycore_error_old_positional_setter` (class + snapshot) [set_var_label only]

**Warning path blocks:**
- Variable not in data → `surveycore_warning_var_not_found` (class + snapshot)
- Variable skipped but other variables still set (result check on the returned object)
- `set_val_labels()` with partially labeled data → `surveycore_warning_missing_labels`
- `set_missing_codes()` with list-type codes entry → `surveycore_error_missing_codes_not_vector`

**Data frame blocks:**
- `set_var_label(df, age = "Age in years")` sets `attr(df$age, "label") == "Age in years"`
- `set_val_labels(df, sex = c(Male = 1L))` sets `attr(df$sex, "labels")`
- `set_universe(df, age = "All adults")` sets `attr(df$age, "universe")`
- `set_missing_codes(df, q5 = c(99L))` sets `attr(df$q5, "missing_codes")`
- Round-trip: set on df → `as_survey()` → extract from survey object (one block per field — all six fields: variable_labels, value_labels, question_prefaces, notes, universe, missing_codes)

### 10.6 Updated Extractor Tests (`test-metadata-system.R`)

For each extractor (`extract_var_label`, `extract_val_labels`,
`extract_question_preface`, `extract_var_note`, `extract_universe`,
`extract_missing_codes`):

**Happy path — single variable (new return type — not backward compatible):**
- `extract_var_label(svy, age)` with default `format = "named_vector"` returns
  `c(age = "Age in years")` — a named character vector of length 1, **not** a
  plain character scalar
- `extract_val_labels(svy, sex)` with default `format = "list"` returns
  `list(sex = c(Male = 1L, Female = 2L))` — a named list, **not** a bare
  named vector
- These are **breaking changes** vs. the old single-variable API. They are
  documented in NEWS.md (see Section 8.3 Breaking Changes note — add extractor
  return type changes alongside the positional setter removal)

**Happy path — multiple variables:**
- Returns result for all specified variables
- Correct output structure for each `format` option

**Happy path — no `var` argument (all variables):**
- Returns metadata for all data columns
- Returns empty result (correct empty type) when no variables have metadata

**`format` option tests (one block per format per function):**
- `"named_vector"` returns named character vector with correct names and values
- `"list"` returns named list with correct structure
- `"data_frame"` returns tibble with correct columns and types
- Empty result with correct types for each format

**`fill` option tests:**
- `fill = NULL` (default): variables with no metadata are absent from result
- `fill = NA_character_`: variables with no metadata appear with `NA` value
- Mix: some variables have metadata, some don't — correct filtering/inclusion

**Error / warning blocks:**
- `x` is a list → `surveycore_error_not_survey_or_df`
- `format = "invalid"` → `surveycore_error_format_invalid` (class + snapshot)
- `format = "named_vector"` on `extract_val_labels()` → `surveycore_error_format_invalid`
- Var specified but not in data → `surveycore_warning_var_not_found`, result excludes it

**Data frame blocks:**
- Each extractor reads the correct column attribute from a plain data frame
- Returns same structure as for survey objects

### 10.7 `extract_metadata()` Tests

**Happy path:**
- Single variable with all fields set: returns 7-key list with correct values
- Single variable with at least one field set: included with `fill = NULL` (default)
- Single variable with NO fields set: omitted with `fill = NULL` (default)
- `fill = "include"`: single variable with no fields set IS included with all-NULL fields
  and `transformations = list()`
- Multiple variables, mixed metadata: `fill = NULL` returns only annotated ones
- Multiple variables, mixed metadata: `fill = "include"` returns all
- No `var` argument with `fill = NULL`: returns only variables with at least one
  metadata field set
- No `var` argument with `fill = "include"`: returns one entry per column in `x@data`
- `transformations` is always `list()`, never `NULL`
- `weighting_history` is NOT present in any entry of the result

**Edge cases:**
- All variables with no metadata + `fill = NULL`: returns empty list (`list()`)
- All variables with no metadata + `fill = "include"`: returns full-length list
  with all-NULL entries
- Single-column data frame with `fill = "include"`: returns list with one entry

**Warning / error blocks:**
- `x` is a list → `surveycore_error_not_survey_or_df` (class + snapshot)
- Variable in `...` not found in data → `surveycore_warning_var_not_found`, skip

**Data frame blocks:**
- `extract_metadata(df, age)` reads column attributes correctly
- `transformations` is `list()` for all data frame variables

### 10.8 Deprecation Tests

- `set_variable_labels(svy, age = "Age in years")` emits a deprecation warning
  (class: `lifecycle_warning_deprecated`)
- `set_value_labels(svy, sex = c(Male = 1L))` emits a deprecation warning
- `set_question_prefaces(svy, q1 = "preface")` emits a deprecation warning
- `set_variable_notes(svy, income = "note")` emits a deprecation warning
- Each deprecated function still sets the metadata correctly despite the warning

### 10.9 Invariant Helpers

No new invariant helper is needed for this spec. The existing `test_invariants()`
in `tests/testthat/helper-test-data.R` checks `@metadata` is a `survey_metadata`
object — this remains valid after adding new fields.

An optional helper for the test file:

```r
# In test-metadata-system.R, defined at top of file
make_labeled_design <- function(seed = 42) {
  df  <- make_survey_data(n = 100, seed = seed)
  svy <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  svy <- set_var_label(svy, y1 = "Outcome 1", y2 = "Outcome 2")
  svy <- set_val_labels(svy, strata = setNames(seq_len(5L), paste0("Stratum ", seq_len(5L))))
  svy <- set_universe(svy, y1 = "All respondents")
  svy <- set_missing_codes(svy, y1 = c("Missing" = -1L))
  svy
}
```

This helper is used across the setter and extractor happy path blocks to
reduce repeated setup code.

---

## XI. Quality Gates

Before opening a PR for this spec's implementation, ALL of the following must
pass:

### Code Quality
- [ ] `devtools::document()` runs without error and regenerates NAMESPACE,
      `man/survey_metadata.Rd`, and all updated function `.Rd` files
- [ ] `air::format_package()` produces no diffs (all code is formatted)
- [ ] `lintr::lint_package()` produces 0 lints (80-char line length, native pipe,
      snake_case, `<-` assignment)

### R CMD Check
- [ ] `devtools::check()` produces 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] No new R CMD check notes introduced by this spec

### Tests
- [ ] All new `test_that()` blocks pass (no failures, no skip-and-forget)
- [ ] `covr::package_coverage()` ≥ 98% line coverage
- [ ] All snapshot tests match (no unreviewed snapshot diffs — run
      `testthat::snapshot_review()` before merge)
- [ ] Every new error class in Section IX has a matching
      `expect_error(class = "surveycore_error_...")` test
- [ ] Every new warning class in Section IX has a matching
      `expect_warning(class = "surveycore_warning_...")` test

### API Contracts
- [ ] Each setter with a data frame input stores the correct column attribute
      (verified by explicit `attr()` assertion in tests)
- [ ] Round-trip test passes: set metadata on data frame → `as_survey()` →
      extract from survey object returns identical values for all six fields
- [ ] `extract_metadata()` returns exactly 7 keys per variable (no more, no less)
- [ ] `extract_metadata()` never returns `weighting_history` in any entry
- [ ] `"named_vector"` format on `extract_val_labels()` and
      `extract_missing_codes()` triggers `surveycore_error_format_invalid`

### Deprecations
- [ ] All four deprecated functions emit `lifecycle_warning_deprecated` (not a
      custom class — lifecycle manages this)
- [ ] Deprecated functions still produce correct output after emitting the
      warning

### Documentation
- [ ] All six new/updated setters have complete roxygen2 blocks including
      `@return`, `@examples`, `@family metadata`, `@export`
- [ ] All six new/updated extractors have complete roxygen2 blocks
- [ ] `extract_metadata()` roxygen2 block includes a `@examples` block
      demonstrating the list output structure
- [ ] `survey_metadata` documentation updated to describe `universe` and
      `missing_codes` properties
- [ ] NEWS.md includes a `### Breaking Changes` entry for the old positional
      NSE setter form removal
- [ ] `plans/error-messages.md` has been updated with all new rows from
      Section IX before any code is committed
