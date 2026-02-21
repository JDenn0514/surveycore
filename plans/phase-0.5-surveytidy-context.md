# Phase 0.5 Transition: surveytidy Context Document

**Version:** 1.0
**Written:** February 2026
**Status:** Phase 0 complete — ready for surveytidy implementation

This document gives the Phase 0.5 implementer everything they need to build
`surveytidy` on top of the completed `surveycore` foundation. It covers what
was built in Phase 0, the contracts that surveytidy must respect, and the
critical implementation patterns discovered during Phase 0.

---

## 1. Phase 0 Completion Status

**Phase 0 is fully complete.** All 14 implementation steps have been merged to
`main`. The package builds cleanly: 0 errors, 0 warnings in `R CMD check`.
There are 2017 tests passing.

### What was shipped

| Step | Branch | File(s) | Status |
|------|--------|---------|--------|
| 1 | feature/test-helpers | tests/testthat/helper-test-data.R | ✅ merged |
| 2 | feature/s7-classes | R/00-s7-classes.R | ✅ merged |
| 3 | feature/metadata-system | R/01-metadata-system.R | ✅ merged |
| 4 | feature/validators | R/02-validators.R | ✅ merged |
| 5 | feature/as-survey | R/03-constructors.R | ✅ merged |
| 6 | feature/as-survey-rep | R/03-constructors.R | ✅ merged |
| 7 | feature/as-survey-twophase | R/03-constructors.R | ✅ merged |
| 8 | feature/update-design | R/08-update-design.R | ✅ merged |
| 9 | feature/print-methods | R/04-methods-print.R | ✅ merged |
| 10 | feature/utils | R/07-utils.R | ✅ merged |
| 11 | feature/conversion-to-survey | R/05-methods-conversion.R | ✅ merged |
| 12 | feature/conversion-from-survey | R/05-methods-conversion.R | ✅ merged |
| 13 | feature/variance-taylor | R/06-variance-estimation.R | ✅ merged |
| 14 | feature/variance-replicate | R/06-variance-estimation.R | ✅ merged |

---

## 2. surveycore Public API (Complete Export List)

These are the exact symbols exported by `surveycore` as of Phase 0 completion.
`surveytidy` can call any of these without `:::`.

### S7 Classes

| Symbol | Type | Description |
|--------|------|-------------|
| `survey_base` | S7 abstract class | Base class; use for `S7::S7_inherits()` checks |
| `survey_taylor` | S7 class | Taylor series / linearization design |
| `survey_replicate` | S7 class | Replicate weight design (BRR, JK, bootstrap) |
| `survey_twophase` | S7 class | Two-phase (double) sampling design |
| `survey_metadata` | S7 class | Metadata container (labels, notes) |

### Constructors

| Symbol | Returns | Description |
|--------|---------|-------------|
| `as_survey()` | `survey_taylor` | Create design from data frame |
| `as_survey_rep()` | `survey_replicate` | Create replicate weight design |
| `as_survey_twophase()` | `survey_twophase` | Create two-phase design |

### Metadata Getters

| Symbol | Description |
|--------|-------------|
| `extract_var_label(x, var)` | Get variable label for one variable |
| `extract_val_labels(x, var)` | Get value labels (named vector) for one variable |
| `extract_question_preface(x, var)` | Get question preface text |
| `extract_var_note(x, var)` | Get variable note |

### Metadata Setters (Single Variable)

| Symbol | Description |
|--------|-------------|
| `set_var_label(x, var, label)` | Set variable label; returns `invisible(x)` |
| `set_val_labels(x, var, labels)` | Set value labels; returns `invisible(x)` |
| `set_question_preface(x, var, preface)` | Set question preface |
| `set_var_note(x, var, note)` | Set variable note |

### Metadata Setters (All Variables)

| Symbol | Description |
|--------|-------------|
| `set_variable_labels(x, ...)` | Set multiple variable labels at once |
| `set_value_labels(x, ...)` | Set multiple value label sets at once |
| `set_question_prefaces(x, ...)` | Set multiple question prefaces at once |
| `set_variable_notes(x, ...)` | Set multiple variable notes at once |

### Analysis Functions (Phase 0 Stubs)

| Symbol | Supports | Description |
|--------|---------|-------------|
| `get_means(design, var, na.rm)` | `survey_taylor`, `survey_replicate` | Weighted mean + SE + CI |
| `get_totals(design, var, na.rm)` | `survey_taylor`, `survey_replicate` | Weighted total + SE + CI |

Both functions throw `surveycore_error_unsupported_class` for `survey_twophase`
(Phase 1 scope).

### Conversion Functions

| Symbol | Description |
|--------|-------------|
| `as_svydesign(x)` | surveycore → `survey::svydesign` / `svrepdesign` |
| `as_tbl_svy(x)` | surveycore → `srvyr::tbl_svy` |
| `from_svydesign(x)` | `survey::svydesign` / `svrepdesign` → surveycore |
| `from_tbl_svy(x)` | `srvyr::tbl_svy` → surveycore |

### Utility Functions and Constants

| Symbol | Description |
|--------|-------------|
| `survey_data(x)` | Accessor: returns `x@data` with type checking |
| `update_design(x, ...)` | Modify design variable columns; returns `invisible(x)` |
| `.get_design_vars_flat(design)` | (keyword-internal) flat character vector of all design column names |
| `SURVEYCORE_DOMAIN_COL` | Constant: `"..surveycore_domain.."` — column name filter() adds |

---

## 3. S7 Class Hierarchy (Actual Implementation)

The roadmap's class diagram is outdated. Here is the actual implementation.

### survey_metadata

```r
survey_metadata <- S7::new_class("survey_metadata", properties = list(
  variable_labels  = S7::new_property(S7::class_list, default = quote(list())),
  value_labels     = S7::new_property(S7::class_list, default = quote(list())),
  question_prefaces = S7::new_property(S7::class_list, default = quote(list())),
  transformations  = S7::new_property(S7::class_list, default = quote(list())),
  notes            = S7::new_property(S7::class_list, default = quote(list()))
))
```

All properties are named lists (variable name → value). They default to empty
lists, so `x@metadata@variable_labels[["age"]]` returns `NULL` for unset
variables — never errors.

### survey_base (abstract)

```r
survey_base <- S7::new_class("survey_base", abstract = TRUE, properties = list(
  data      = S7::new_property(S7::class_data.frame, default = quote(data.frame())),
  metadata  = S7::new_property(class = survey_metadata, default = quote(survey_metadata())),
  variables = S7::new_property(S7::class_list, default = quote(list())),
  groups    = S7::new_property(S7::class_character, default = quote(character(0))),
  call      = S7::new_property(default = NULL)
))
```

Key notes:
- `@data`: the raw data frame. All columns, including design columns, live here.
- `@metadata`: a `survey_metadata` object. Surveyors can ignore it; operations
  on `@data` must keep `@metadata` consistent (see Section 6).
- `@variables`: a named list of design variable names (strings, never actual
  column values). Structure differs by subclass (see Section 4).
- `@groups`: **RESERVED for Phase 0.5**. Always `character(0)` in Phase 0.
  `group_by()` will store grouping variable names here.
- `@call`: the matched call that created the object.

### survey_taylor (subclass of survey_base)

No additional S7 properties. All design information lives in `@variables`:

```r
# @variables keys for survey_taylor (ALL keys always present; unspecified = NULL)
list(
  ids            = NULL | character,  # PSU column name(s), NULL = SRS
  weights        = character,         # weight column name (required)
  strata         = NULL | character,  # stratum column name, NULL = unstratified
  fpc            = NULL | character,  # FPC column name, NULL = infinite pop
  nest           = logical,           # TRUE if PSU IDs are nested in strata
  probs_provided = logical,           # TRUE if user passed probs= (not weights=)
  visible_vars   = NULL | character   # set by select(); shown in print()
)
```

When `as_survey()` is called with no weights (SRS), a synthetic column named
`"..surveycore_wt.."` is added to `@data` and `weights = "..surveycore_wt.."`.

### survey_replicate (subclass of survey_base)

```r
# @variables keys for survey_replicate
list(
  weights      = character,           # base weight column name (required)
  repweights   = character,           # replicate weight column names (vector)
  type         = character,           # "JK1","JK2","JKn","BRR","Fay","bootstrap","ACS","successive-difference","other"
  scale        = numeric,             # global scaling factor
  rscales      = NULL | numeric,      # per-replicate scaling (length = n_rep), or NULL
  fpc          = NULL | character,    # FPC column name
  fpctype      = character,           # "fraction" or "correction"
  mse          = logical,             # TRUE = MSE-based variance (default)
  visible_vars = NULL | character
)
```

The replicate weight matrix is **not stored**. It is computed on demand:
`as.matrix(design@data[, design@variables$repweights])`.

### survey_twophase (subclass of survey_base)

```r
# @variables keys for survey_twophase
list(
  phase1 = list(   # full @variables list from the phase1 survey_taylor object
    ids, weights, strata, fpc, nest, probs_provided, visible_vars
  ),
  phase2 = list(   # phase2 design info (may be NULL for all slots)
    ids     = NULL | character,
    strata  = NULL | character,
    probs   = NULL | character,
    fpc     = NULL | character
  ),
  subset = character,   # name of logical column marking phase2 membership
  method = character    # "full", "approx", or "simple"
)
```

For `survey_twophase`, `.get_design_vars_flat()` returns columns from both
`phase1` and `phase2` variables.

---

## 4. Five Formal Invariants (Must Hold After Every surveytidy Operation)

Every verb in surveytidy that modifies a survey object MUST preserve these
invariants:

1. **`x@data` is a `data.frame`** with at least 1 row.
2. **`x@data` has at least 1 column.**
3. **All `@variables` keys are always present** in the list. Never delete a key;
   set it to `NULL` if it no longer applies.
4. **All design column names referenced in `@variables` exist in `x@data`.**
   The weight column, PSU column(s), strata column, etc. must still be present
   even if the user's `select()` call did not request them explicitly.
5. **`x@metadata` is a `survey_metadata` object.** It may be empty but never
   `NULL`.

`test_invariants(design)` in `helper-test-data.R` asserts all five. Call it in
every test block that creates or modifies a survey object.

---

## 5. The dplyr Dispatch Problem and Its Solution (CRITICAL)

**This is the most important implementation detail for surveytidy.**

### The problem

S7 uses namespaced class names. When you inspect `class()` on a survey object:

```r
d <- as_survey(df, weights = w)
class(d)
#> [1] "surveycore::survey_taylor" "surveycore::survey_base" "S7_object"
```

Standard S3 dispatch (`UseMethod("filter")`) will look for a method named
`filter.surveycore::survey_taylor` — which is not a legal R function name
(contains `:`). It will never be found. This means:

- You CANNOT use `#' @export` + `filter.survey_taylor <- function(...)` — R
  won't dispatch to it.
- You CANNOT register via NAMESPACE (roxygen `@exportS3Method` won't work).
- `dplyr::filter(d)` will silently fall through to the data.frame method and
  return a plain data.frame, destroying the survey design.

### The solution

Register S3 methods **dynamically** in `.onLoad()` using `registerS3method()`.
The trick: use the class string `"surveycore::survey_base"` as the class
argument — R's S3 dispatch matches it against `class(x)`, and the colon is fine
in a string.

```r
# In R/zzz.R of surveytidy:
.onLoad <- function(libname, pkgname) {
  S7::methods_register()

  # Register dplyr verb methods for survey_base (catches all subclasses)
  register <- function(generic, method, pkg) {
    registerS3method(generic, "surveycore::survey_base", method,
                     envir = asNamespace(pkg))
  }

  register("filter",             filter.survey_base,             "dplyr")
  register("select",             select.survey_base,             "dplyr")
  register("mutate",             mutate.survey_base,             "dplyr")
  register("rename",             rename.survey_base,             "dplyr")
  register("relocate",           relocate.survey_base,           "dplyr")
  register("arrange",            arrange.survey_base,            "dplyr")
  register("group_by",           group_by.survey_base,           "dplyr")
  register("ungroup",            ungroup.survey_base,            "dplyr")
  register("pull",               pull.survey_base,               "dplyr")
  register("dplyr_reconstruct",  dplyr_reconstruct.survey_base,  "dplyr")
  # tidyr verbs
  register("drop_na",            drop_na.survey_base,            "tidyr")
  # base R
  registerS3method("subset", "surveycore::survey_base", subset.survey_base,
                   envir = baseenv())
}
```

### Naming and documentation rules for these methods

- Function names: `filter.survey_base`, `select.survey_base`, etc. (the class
  part is the S7 base class, not the subclass — registering on the base class
  catches all three design types).
- Documentation: use plain `#' @noRd` above each function — **no `@export`**,
  because NAMESPACE registration doesn't work for these. They are registered
  dynamically.
- **Exception**: `subset.survey_base` uses `#' @export` because the base R
  `subset` generic is dispatched differently.
- Add `@importFrom dplyr filter select mutate rename relocate arrange group_by
  ungroup pull` (and the tidyr equivalents) in your `surveytidy-package.R` file
  to satisfy R CMD check's "not imported from" note.

### dplyr_reconstruct

`dplyr` calls `dplyr_reconstruct(data, template)` after certain internal
operations to rebuild the object from a modified data frame. You must register a
method for it:

```r
#' @noRd
dplyr_reconstruct.survey_base <- function(data, template) {
  # Rebuild a survey object from a dplyr-modified data frame.
  # `data` is the new data.frame; `template` is the original survey object.
  # Called by dplyr verbs after modifying @data.
  template@data <- data
  template
}
```

This is the reconstruction path dplyr uses internally — without it, verbs like
`mutate()` will return a plain data.frame.

---

## 6. Metadata Lifecycle Contracts (surveytidy Must Implement These)

These rules are defined in `CLAUDE.md` and the formal specification. They are
not yet enforced — Phase 0 built the metadata system but only surveycore's own
operations (update_design) respect them. surveytidy must enforce all of them.

### Rule 1: rename() must update metadata keys

When a column is renamed, its metadata entries must be renamed too.

```r
# User calls: d |> rename(age_years = age)
# surveytidy must call internally:
# .rename_metadata_keys(design, old_name = "age", new_name = "age_years")
```

`R/02-validators.R` exports `.rename_metadata_keys(design, old, new)` for this.

### Rule 2: select() must delete metadata for dropped columns

When a column is dropped via `select()`, its metadata entries must be removed.

```r
# User calls: d |> select(age, income)
# Any metadata for dropped variables must be purged:
# x@metadata@variable_labels[dropped_vars] <- NULL
# x@metadata@value_labels[dropped_vars] <- NULL
# etc. for all metadata slots
```

### Rule 3: mutate() should track transformations

When a column is created or modified by `mutate()`, record the operation in
`x@metadata@transformations[[var_name]]`. The exact format is flexible, but
storing the expression as a string is sufficient for Phase 0.5.

### Rule 4: Design variables are NEVER dropped by select()

`select(d, age, income)` shows only `age` and `income`, but all design columns
(`psu`, `strata`, `weights`, etc.) must remain in `@data`. The display is
controlled by `@variables$visible_vars`:

```r
# select() sets visible_vars to the user's selection (excluding design vars)
x@variables$visible_vars <- selected_non_design_cols
# Design columns remain in @data but are not shown in print()
```

The print method in `R/04-methods-print.R` already respects `visible_vars` —
it only displays columns listed there (plus design columns) if set.

---

## 7. filter() and the Domain Estimation Contract

**This is the second most important design decision for surveytidy.**

### filter() → domain estimation (NOT physical subsetting)

When a user calls `filter(d, age > 18)`, the rows with `age <= 18` must
**remain in `@data`**. They are marked as outside the domain by a logical
column:

```r
# filter() implementation contract:
# 1. Evaluate the filter expression to a logical vector
# 2. Add (or update) the domain indicator column in @data:
d@data[[SURVEYCORE_DOMAIN_COL]] <- age > 18   # full-length logical vector
# 3. Return the modified object (ALL rows still present)
```

`SURVEYCORE_DOMAIN_COL` is exported from surveycore and equals
`"..surveycore_domain.."`.

When analysis functions (`get_means()`, etc.) encounter a design object where
`@data[[SURVEYCORE_DOMAIN_COL]]` exists, they restrict estimation to those rows
while keeping the full design for variance computation. (This is Phase 1 scope,
but surveytidy's filter() must lay the groundwork.)

### Chained filter() calls

Each call to `filter()` should AND its condition with any existing domain column:

```r
# d |> filter(age > 18) |> filter(income > 30000)
# should be equivalent to d |> filter(age > 18 & income > 30000)
```

Implementation: if `SURVEYCORE_DOMAIN_COL` already exists in `@data`, new
filter expressions should be ANDed with the existing logical column.

### subset() → physical subsetting (removes rows, warns strongly)

`subset(d, region == "West")` physically removes non-matching rows from `@data`.
This is the escape hatch for cases where the user genuinely wants to restrict
the design. It must emit a strong warning:

```r
cli::cli_warn(
  c(
    "!" = "{.fn subset} physically removes rows from the survey design.",
    "i" = "Variance estimates will be based on the subset only.",
    "i" = "Use {.fn filter} for domain estimation with correct standard errors."
  ),
  class = "surveycore_warning_physical_subset"
)
```

---

## 8. The @groups Property (Phase 0.5 Activation)

`@groups` is `character(0)` in all Phase 0 objects. Phase 0.5 activates it:

```r
# group_by() stores grouping variable names in @groups
x@groups <- c("region", "sex")

# ungroup() clears it
x@groups <- character(0)
```

**Analysis functions in Phase 1** will read `@groups` to perform grouped
estimation. Phase 0.5 is responsible for getting the data into `@groups`;
Phase 1 is responsible for using it.

**Important**: Phase 0's validators and methods never read `@groups`. Phase 0.5
is free to set it without any risk of interaction with Phase 0 code.

---

## 9. Design Variable Protection in Surveytidy

`.get_design_vars_flat(design)` (exported from surveycore with `@keywords
internal`) returns a character vector of all column names that are referenced
as design variables. surveytidy uses this to ensure those columns are never
dropped or renamed silently.

```r
# Usage pattern in select():
protected <- surveycore::.get_design_vars_flat(design)
user_selection <- tidyselect::eval_select(expr, design@data)
# Force-include protected columns that the user didn't select:
final_selection <- union(names(user_selection), protected)
# But only show user_selection in print:
design@variables$visible_vars <- setdiff(names(user_selection), protected)
```

For `rename()`, check that the user isn't trying to rename a design variable:

```r
if (any(names(renaming_map) %in% protected)) {
  cli::cli_warn(
    c(
      "!" = "Renaming design variable(s): {.field {intersect(names(renaming_map), protected)}}.",
      "i" = "The design has been updated to use the new column name(s)."
    ),
    class = "surveycore_warning_design_var_renamed"
  )
  # Then update @variables via .update_design_var_names() from R/02-validators.R
}
```

---

## 10. surveycore Helper Functions surveytidy Can Use

These internal helpers are in surveycore and can be accessed via `:::` or
(for the `@keywords internal` exported ones) via `::`:

| Function | Location | Purpose |
|----------|----------|---------|
| `.get_design_vars_flat(design)` | R/07-utils.R | Exported (`@keywords internal`); flat character vector of all design column names |
| `.get_design_vars(design)` | R/07-utils.R | Internal; named list of slot → col(s), NULL slots omitted |
| `.rename_metadata_keys(design, old, new)` | R/02-validators.R | Internal; renames a key in all metadata slots |
| `.update_design_var_names(design, old, new)` | R/02-validators.R | Internal; renames a column name in @variables |
| `.resolve_tidy_select(expr, data)` | R/07-utils.R | Internal; resolves quosure → char vec; NULL for NULL quosure |
| `SURVEYCORE_DOMAIN_COL` | R/07-utils.R | Exported; the domain column name constant |

Use `:::` sparingly and only for truly internal helpers. Prefer the exported
`@keywords internal` symbols where available.

---

## 11. surveycore Dependencies (What surveytidy Inherits)

surveycore's `DESCRIPTION` imports:

```
Imports:
    S7 (>= 0.1.0)
    rlang (>= 1.0.0)
    tidyselect (>= 1.2.0)
    cli (>= 3.6.0)
    tibble (>= 3.1.0)
    stats
```

`dplyr` and `tidyr` are in `Suggests` for surveycore. surveytidy will promote
them to `Imports`.

**surveycore has NO runtime dependency on `survey` or `srvyr`** — those are
`Suggests` (test-only). surveytidy should follow the same pattern.

---

## 12. Phase 0.5 (surveytidy) Scope and Priorities

surveytidy is a separate R package that depends on surveycore. Build it as a
new package with its own `DESCRIPTION`, `NAMESPACE`, tests, etc. It does NOT
modify surveycore source files.

### Priority 1: Core dplyr verbs (must ship in Phase 0.5)

| Verb | Key Behavior |
|------|-------------|
| `filter()` | Domain estimation (adds `..surveycore_domain..`, keeps all rows) |
| `select()` | Preserves design vars; sets `visible_vars` |
| `rename()` | Updates `@variables` and `@metadata` keys |
| `mutate()` | Passes through to data frame; records in `@metadata@transformations` |
| `relocate()` | Pure column reordering; no design implications |
| `arrange()` | Pure row reordering; no design implications |
| `group_by()` | Stores var names in `@groups` |
| `ungroup()` | Clears `@groups` |
| `pull()` | Returns a plain vector (not a survey object) |

### Priority 2: subset() and glimpse()

| Verb | Key Behavior |
|------|-------------|
| `subset()` | Physical subsetting; strong warning; removes rows from @data |
| `glimpse()` | Pretty print of @data (dplyr's glimpse generic) |

### Priority 3: tidyr verbs (Phase 0.5 stretch goals)

`drop_na()`, `unite()`, `separate_wider_delim()`, `separate_longer_delim()`.
These all pass through to the underlying data frame; the main work is preserving
design and metadata.

### Intentionally OUT of Phase 0.5 scope

- `*_join()` operations — complex design semantics, defer to Phase 3
- `bind_rows()` / `bind_cols()` — defer to Phase 3
- `pivot_longer()` / `pivot_wider()` — defer to Phase 3
- `slice()` / `distinct()` — defer to Phase 3
- `group_by()` + `summarise()` — `summarise()` produces estimates; that is
  Phase 1 scope (analysis functions)

---

## 13. surveytidy Package Structure

Use the same file-naming conventions as surveycore:

```
surveytidy/
├── R/
│   ├── 00-verbs-filter.R       # filter(), subset() — domain estimation
│   ├── 01-verbs-select.R       # select(), relocate(), pull(), glimpse()
│   ├── 02-verbs-mutate.R       # mutate(), transmute()
│   ├── 03-verbs-rename.R       # rename(), rename_with()
│   ├── 04-verbs-arrange.R      # arrange()
│   ├── 05-verbs-groups.R       # group_by(), ungroup()
│   ├── 06-verbs-tidyr.R        # drop_na(), unite(), separate_*()
│   └── zzz.R                   # .onLoad: registerS3method() calls
├── tests/testthat/
│   ├── helper-test-data.R      # re-use or import from surveycore
│   ├── test-verbs-filter.R
│   ├── test-verbs-select.R
│   ├── test-verbs-mutate.R
│   ├── test-verbs-rename.R
│   ├── test-verbs-arrange.R
│   ├── test-verbs-groups.R
│   └── test-verbs-tidyr.R
└── DESCRIPTION
```

### DESCRIPTION template

```
Package: surveytidy
Title: Tidy Verbs for Survey Design Objects
Version: 0.0.0.9000
Depends: R (>= 4.3.0)
Imports:
    surveycore (>= 0.1.0),
    S7 (>= 0.1.0),
    rlang (>= 1.0.0),
    dplyr (>= 1.1.0),
    tidyr (>= 1.3.0),
    tidyselect (>= 1.2.0),
    cli (>= 3.6.0)
Suggests:
    testthat (>= 3.0.0),
    withr,
    haven
```

### surveytidy-package.R import stubs

R CMD check will complain about "not imported from" for dplyr and tidyr verbs
that are used but only registered dynamically. Add import stubs:

```r
# In surveytidy-package.R:
#' @importFrom dplyr filter select mutate rename relocate arrange
#' @importFrom dplyr group_by ungroup pull glimpse
#' @importFrom dplyr dplyr_reconstruct
#' @importFrom tidyr drop_na
#' @importFrom S7 S7_inherits
NULL
```

---

## 14. Known Gotchas from Phase 0 (surveytidy Must Avoid These)

1. **`S7::inherits()` does not exist in S7 v0.2.1.** Use `S7::S7_inherits(x,
   ClassName)`. The class argument is the class object (e.g., `survey_base`),
   never a string.

2. **`super()` does not work with S3 generics.** If you need to call a print
   method on the data frame inside a print method, use `x@data` directly.

3. **Do NOT add `#'` roxygen blocks above `S7::method() <-` assignments.**
   There is no named object to attach them to. Use plain `#` comments instead.

4. **`S7::methods_register()` is required in `.onLoad()`** for external generic
   methods (print, summary, etc.) to work in installed packages. Add it to
   `R/zzz.R` in surveytidy.

5. **R CMD check cannot detect `::` usage inside `S7::method() <-` bodies.**
   If you use `tibble::as_tibble()` or similar inside an S7 method, move the
   call into a regular helper function outside the method body so R CMD check
   sees the namespace dependency.

6. **The `@variables$visible_vars` key must be in the `@variables` list** for
   surveytidy to work correctly. All three design types initialize it to `NULL`.
   surveytidy's `select()` method sets it; surveycore's print method respects it.

7. **Never call `.validate_psu_strata()` during any surveytidy operation.** The
   S7 validator fires it automatically on object modification. Calling it
   explicitly causes double-warnings.

8. **`registerS3method()` with `envir=asNamespace("dplyr")` may fail if dplyr
   isn't installed.** Guard with `if (requireNamespace("dplyr", quietly = TRUE))`.
   Same for tidyr.

9. **`@importFrom dplyr filter` (and other verbs) in `surveytidy-package.R` is
   required** even though the methods are registered dynamically. Without these
   `@importFrom` stubs, R CMD check emits "object 'filter' not found" or "not
   imported from" notes.

---

## 15. Test Data Available in surveycore

The test helper `tests/testthat/helper-test-data.R` in surveycore is not
exported. surveytidy needs its own test data helpers. You can either:

- Copy `make_survey_data()` into surveytidy's own `helper-test-data.R`
- Or use inline data frames for all surveytidy tests (simpler)

For surveytidy, test behavior rather than numeric accuracy — you don't need NHANES
for verb tests. Simple synthetic data frames are sufficient:

```r
df <- data.frame(
  psu    = rep(1:10, each = 10),
  strata = rep(c("A", "B"), 50),
  wt     = runif(100, 0.5, 2),
  age    = sample(18:80, 100, replace = TRUE),
  income = rnorm(100, 50000, 15000),
  region = sample(c("North", "South", "East", "West"), 100, replace = TRUE)
)
d <- surveycore::as_survey(df, ids = psu, weights = wt, strata = strata)
```

### What to test for every verb

1. **Happy path**: returns an object of the same class (`survey_taylor`,
   `survey_replicate`, or `survey_twophase`).
2. **Formal invariants**: call `test_invariants(result)` (copy from surveycore
   or reimplement it).
3. **Design variable preservation**: design columns still in `@data` after the
   operation.
4. **Metadata preservation**: labels set before the operation survive it.
5. **`@groups` preservation**: `group_by()` state survives through other verbs.
6. **Works for all three design types**: test each verb with `survey_taylor`,
   `survey_replicate`, and `survey_twophase` designs.
