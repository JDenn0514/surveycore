# surveycore R Package Conventions

**Version:** 1.0
**Created:** February 2025
**Status:** Detailed examples and guidance specific to surveycore

This document extends the **generic R package conventions** (in `../survey-standards/.claude/rules/r-package-conventions.md`) with surveycore-specific examples and detailed guidance.

**Read the generic conventions first, then this document for context.**

---

## Quick Reference (surveycore-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| `@param` examples | Fuller for survey-specific args | `nest`, `fpc`, `type` get longer docs |
| Entry points | Constructor functions | `as_survey()`, `as_survey_rep()`, `as_survey_twophase()` |
| `@seealso` | Constructors only | Only constructors link to each other |
| `@family` groups | By operational category | `constructors`, `metadata`, `validators`, `conversion` |
| Setters return | Always `invisible(x)` | `set_var_label()`, `set_variable_labels()` |
| Getters return | Always visible | `extract_var_label()`, `extract_val_labels()` |

---

## 1. Documentation Examples for surveycore

### `@param` for survey-specific arguments

Survey-specific arguments like `nest`, `fpc`, and `type` need fuller documentation because they have non-obvious behavior:

```r
#' Create a Taylor series survey design
#'
#' @param data A data.frame containing survey data.
#'
#' @param ids <[`tidy-select`][tidyselect::language]> Primary sampling unit IDs.
#'   Use bare column names (e.g., `psu`, or `c(psu1, psu2)` for multiple levels).
#'   Default `NULL` (assumed SRS within strata).
#'
#' @param weights <[`tidy-select`][tidyselect::language]> Column(s) for survey
#'   weights. If multiple columns specified, they are multiplied together.
#'   Cannot contain `NA` or non-positive values. Default `NULL` (uniform weights).
#'
#' @param strata <[`tidy-select`][tidyselect::language]> Stratum IDs.
#'   Use bare column names (e.g., `strata`). Default `NULL` (no stratification).
#'
#' @param fpc <[`tidy-select`][tidyselect::language]> Finite population
#'   correction column. Supply either:
#'   - An integer column with population size (e.g., stratum population)
#'   - A numeric column (0-1) with sampling fraction
#'   Cannot contain `NA`. If `NULL`, design assumes sampling from infinite
#'   population. Default `NULL`.
#'
#' @param nest Logical. If `TRUE`, PSU IDs are treated as nested within strata —
#'   i.e., the same PSU ID value in two different strata refers to two distinct
#'   PSUs. Set `nest = TRUE` when PSU IDs are not globally unique (e.g., NHANES
#'   uses IDs 1–30 within each stratum). Requires `strata` to be specified.
#'   Default `FALSE`.
#'
#' @examples
#' # Stratified cluster design with FPC (NHANES)
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtmec2yr,
#'   strata = sdmvstra,
#'   fpc = NULL,  # Assume infinite population
#'   nest = TRUE  # PSU IDs are nested within strata
#' )
#'
#' # Simple random sample with custom weights
#' df <- data.frame(id = 1:100, y = rnorm(100), w = runif(100, 0.5, 2))
#' d <- as_survey(df, weights = w)
#'
#' # Two-level cluster design (schools -> students)
#' d <- as_survey(
#'   schools_data,
#'   ids = c(school_id, student_id),
#'   weights = sampling_weight
#' )
```

### `@return` for survey objects

```r
#' @return A `survey_taylor` object — a complete survey design specification
#'   ready for variance estimation via Taylor series linearization.
#'   See [survey_taylor] for structure.
```

### `@seealso`: constructors only

Only the three constructors (`as_survey()`, `as_survey_rep()`, `as_survey_twophase()`) have `@seealso`:

```r
#' @seealso
#'   [as_survey_rep()] for replicate-weight designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [update_design()] to modify an existing design,
#'   [extract_var_label()] to retrieve variable labels
```

Getters, setters, validators, and other functions do **not** carry `@seealso`.

---

## 2. Naming Conventions (surveycore-specific)

### Class names
- **S7 classes**: `survey_base`, `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_metadata`
- **Result classes**: Built on tibble: `survey_mean`, `survey_total`, `survey_freq`, `survey_quantiles`, etc.

### Function families
Use these `@family` groups:

```r
#' @family constructors
as_survey <- function(...) { ... }

#' @family metadata
extract_var_label <- function(...) { ... }

#' @family validators
.validate_weights <- function(...) { ... }

#' @family conversion
as_svydesign <- function(...) { ... }
```

### Naming patterns

| Category | Pattern | Example |
|----------|---------|---------|
| Analysis functions | `get_*` | `get_means()`, `get_totals()`, `get_freqs()` |
| Metadata extractors | `extract_*` | `extract_var_label()`, `extract_val_labels()` |
| Metadata setters (single) | `set_*` | `set_var_label()`, `set_variable_labels()` |
| Metadata setters (plural) | `set_*` (also accept vector) | `set_variable_labels()` |
| Internal helpers | prefix `.` | `.validate_weights()`, `.resolve_tidy_select()` |

---

## 3. Return Value Visibility (surveycore-specific)

Return visibility rules are defined in `code-style.md §4` (the return value visibility table).
The surveycore-specific additions in the Quick Reference above (setters → `invisible(x)`,
getters → visible) are the same rules applied to surveycore's naming conventions.

---

## 4. Export Policy (surveycore-specific)

### What to export
- All constructors: `as_survey()`, `as_survey_rep()`, `as_survey_twophase()`
- All getter functions: `extract_*()` family
- All setter functions: `set_*()` family (return invisibly)
- All analysis functions: `get_*()` family
- All S7 classes: `survey_base`, `survey_taylor`, etc.
- Utility functions: `update_design()`, `as_svydesign()`, `from_svydesign()`, etc.

### What NOT to export
- All validator functions: `.validate_weights()`, `.validate_ids()`, etc. (internal only)
- Internal helpers: `.resolve_tidy_select()`, `.check_*()`, etc.
- Internal S7 generics: not part of public API
- Internal variance code: vendored from survey package

```r
# Export with @export
#' @export
extract_var_label <- function(x, var) { ... }

# Do NOT export (no @export tag)
.validate_weights <- function(weights) { ... }
```

---

## 5. `haven` Package Handling

`haven` is in `Suggests`, not `Imports`. Use base R to extract label attributes:

```r
# Correct — no haven needed at runtime
var_label <- attr(col, "label", exact = TRUE)
val_labels <- attr(col, "labels", exact = TRUE)

# Wrong — requires haven
var_label <- haven::var_label(col)
val_labels <- haven::val_labels(col)
```

`haven` is only needed in `data-raw/` scripts (to read `.xpt` files). At runtime, surveycore extracts label attributes directly.

---

## 6. Documentation Checklist for surveycore

Before committing any roxygen2 changes:

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@return`
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct
- [ ] Constructor functions have `@seealso`
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes

---

## Reference

**Generic conventions (all packages):**
`../survey-standards/.claude/rules/r-package-conventions.md`

**surveycore architecture:**
`CLAUDE.md` in this directory

**Planning & specifications:**
`plans/` directory in this repository
