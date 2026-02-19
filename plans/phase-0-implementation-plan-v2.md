# Phase 0 Implementation Plan: surveycore Package (Version 2.0)

**Version:** 2.0 (Revised)
**Created:** February 18, 2025  
**Status:** Ready for Implementation
**Formal Specification:** See `surveycore-phase0-formal-specification.md`

---

## IMPORTANT: Read the Formal Specification First

**This implementation plan must be read in conjunction with the formal specification document.**

The formal specification (`surveycore-phase0-formal-specification.md`) contains:
- Complete invariant definitions
- All API contracts
- Behavior specifications
- Error handling rules
- Testing requirements

**This plan provides:** Implementation details, code templates, file organization, and step-by-step build instructions.

**The formal spec provides:** What to build and how it should behave.

---

## Executive Summary

This plan provides detailed implementation instructions for Phase 0 of the surveycore package. Phase 0 establishes the foundation: S7 class system, metadata infrastructure with tidy-select interface, object creation functions, and conversion utilities.

**Estimated Timeline:** 16-18 days

### Key Changes from Version 1.0

**Major Updates:**
1. ✅ **Tidy-Select Interface** - No formulas, use bare names throughout
2. ✅ **Enhanced Metadata API** - Both single and plural setter functions
3. ✅ **CLI Error Messages** - All errors/warnings use `cli` package
4. ✅ **Formal Specification** - Complete behavioral contracts defined
5. ✅ **Lenient Value Labels** - Allow extra labels, warn on missing
6. ✅ **Update Function** - `update_design()` for post-construction updates
7. ✅ **Minimal Dependencies** - Only rlang, tidyselect (not dplyr)

### Success Criteria
[Same as before, see formal specification Section X]

---

## Development Approach

[Same as Version 1.0 - see previous plan]

---

## Project Structure

### Repository Setup

```
surveycore/
├── .github/
│   └── workflows/
│       ├── R-CMD-check.yaml
│       ├── test-coverage.yaml
│       └── pkgdown.yaml
├── R/
│   ├── 00-s7-classes.R
│   ├── 01-metadata-system.R
│   ├── 02-validators.R
│   ├── 03-constructors.R
│   ├── 04-methods-print.R
│   ├── 05-methods-conversion.R
│   ├── 06-variance-estimation.R
│   ├── 07-utils.R
│   ├── 08-update-design.R          # NEW
│   └── surveycore-package.R
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── test-s7-classes.R
│       ├── test-metadata-system.R
│       ├── test-validators.R
│       ├── test-constructors.R
│       ├── test-tidy-select.R      # NEW
│       ├── test-methods-print.R
│       ├── test-conversion.R
│       ├── test-variance-estimation.R
│       ├── test-update-design.R    # NEW
│       └── helper-test-data.R
├── man/
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── README.md
├── NEWS.md
└── .Rbuildignore
```

### Package Infrastructure Files

#### DESCRIPTION

```
Package: surveycore
Title: Core Survey Analysis Infrastructure
Version: 0.0.0.9000
Authors@R: 
    person("Your", "Name", , "your.email@example.com", role = c("aut", "cre"),
           comment = c(ORCID = "YOUR-ORCID-ID"))
Description: Provides S7-based infrastructure for survey analysis including
    design objects, metadata preservation, and variance estimation. Forms the
    foundation of the surveyverse ecosystem. Uses tidy-select interface for
    intuitive design specification.
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.1
Depends:
    R (>= 4.3.0)
Imports:
    S7 (>= 0.1.0),
    rlang (>= 1.0.0),
    tidyselect (>= 1.2.0),
    cli (>= 3.6.0),
    stats,
    methods
Suggests:
    testthat (>= 3.0.0),
    survey,
    srvyr,
    haven (>= 2.5.0),
    dplyr,
    covr,
    knitr,
    rmarkdown
Config/testthat/edition: 3
URL: https://github.com/yourusername/surveycore
BugReports: https://github.com/yourusername/surveycore/issues
```

**Note:** dplyr is now in Suggests (not Imports). Phase 0.5 (surveytidy) will depend on dplyr.

---

## Component 1: S7 Class System

### File: `R/00-s7-classes.R`

#### survey_metadata Class

```r
survey_metadata <- S7::new_class(
  "survey_metadata",
  properties = list(
    variable_labels   = S7::new_property(S7::class_list,    default = quote(list())),
    value_labels      = S7::new_property(S7::class_list,    default = quote(list())),
    question_prefaces = S7::new_property(S7::class_list,    default = quote(list())),
    notes             = S7::new_property(S7::class_list,    default = quote(list())),
    transformations   = S7::new_property(S7::class_list,    default = quote(list()))
  )
)
```

#### survey_base Class (Abstract)

```r
survey_base <- S7::new_class(
  "survey_base",
  abstract = TRUE,
  properties = list(
    data      = S7::new_property(S7::class_data.frame),
    metadata  = S7::new_property(class = survey_metadata,
                                 default = quote(survey_metadata())),
    variables = S7::new_property(S7::class_list,    default = quote(list())),
    # RESERVED: Phase 0.5 (group_by support in surveytidy).
    # DO NOT use @groups in Phase 0 validators or methods — it is always
    # character(0) during Phase 0. Phase 0.5 will populate it via group_by().
    # The property is included here so Phase 0.5 can use it without a breaking
    # class definition change (any existing serialized objects would break).
    groups    = S7::new_property(S7::class_character, default = quote(character(0))),
    call      = S7::new_property(default = NULL)
  )
)
```

**Note on `groups` (RESERVED):** Always `character(0)` in Phase 0. Set by `group_by()` in Phase 0.5 (surveytidy). Estimation functions in Phase 1+ use `@groups` to apply subgroup analysis. Print shows `Groups: var1, var2` when non-empty (mirroring dplyr). **Phase 0 validators must not check or condition on `@groups`.**

#### Updated: survey_taylor Class

```r
#' Taylor Series Linearization Survey Design
#'
#' Survey design using Taylor series linearization for variance estimation.
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list with design specification
#' @slot call Language object storing creation call
#'
#' @section Design Variables:
#' The `variables` slot contains:
#' \describe{
#'   \item{ids}{Character vector of cluster ID column names, or NULL for SRS}
#'   \item{weights}{Character string naming weight column}
#'   \item{strata}{Character string naming strata column, or NULL}
#'   \item{fpc}{Character string naming FPC column, or NULL}
#'   \item{nest}{Logical, are IDs nested within strata?}
#'   \item{probs_provided}{Logical, did user provide probs instead of weights?}
#' }
#'
#' @examples
#' # Simple random sample (omit ids)
#' srs <- as_survey(my_data, weights = wt)
#'
#' # Single-stage cluster
#' cluster <- as_survey(my_data, ids = psu, weights = wt)
#'
#' # Two-stage cluster
#' twostage <- as_survey(my_data, ids = c(psu, ssu), weights = wt)
#'
#' # Stratified
#' strat <- as_survey(my_data, weights = wt, strata = region)
#'
#' @export
survey_taylor <- S7::new_class(
  "survey_taylor",
  parent = survey_base,
  properties = list(
    # Inherits from survey_base
  ),
  validator = function(self) {
    # Validate design variables exist in data
    design_vars <- c(
      self@variables$ids,
      self@variables$weights,
      self@variables$strata,
      self@variables$fpc
    )
    design_vars <- design_vars[!sapply(design_vars, is.null)]
    
    missing <- setdiff(design_vars, names(self@data))
    if (length(missing) > 0) {
      cli::cli_abort(c(
        "x" = "Design variables not found in data",
        "i" = "Missing: {.field {missing}}"
      ))
    }
    
    # Validate weights are positive
    wt_col <- self@data[[self@variables$weights]]
    if (!is.numeric(wt_col)) {
      cli::cli_abort(c(
        "x" = "Weights must be numeric",
        "i" = "Column {.field {self@variables$weights}} has class {.cls {class(wt_col)}}"
      ))
    }
    
    if (any(wt_col <= 0, na.rm = TRUE)) {
      cli::cli_abort(c(
        "x" = "Weights must be positive",
        "i" = "Found {sum(wt_col <= 0, na.rm = TRUE)} non-positive weight(s)"
      ))
    }
    
    # Validate design variables are atomic
    for (var in design_vars) {
      if (!is.atomic(self@data[[var]])) {
        cli::cli_abort(c(
          "x" = "Design variables must be atomic vectors",
          "i" = "{.field {var}} is a list-column"
        ))
      }
    }
  }
)
```

#### Updated: survey_replicate Class

```r
#' Replicate Weights Survey Design
#'
#' Survey design using replicate weights for variance estimation.
#'
#' @slot data Data frame containing survey data
#' @slot metadata survey_metadata object
#' @slot variables Named list with design specification
#' @slot call Language object storing creation call
#'
#' @section Design Variables:
#' The `variables` slot contains:
#' \describe{
#'   \item{weights}{Character string naming weight column}
#'   \item{repweights}{Character vector naming replicate weight columns.
#'     The replicate weight matrix is computed on demand from these column names
#'     inside variance estimation — it is not stored as a property.}
#'   \item{type}{Character string: JK1, JK2, JKn, BRR, Fay, bootstrap, etc.}
#'   \item{scale}{Numeric scaling factor}
#'   \item{rscales}{Numeric vector of replicate-specific scales, or NULL}
#' }
#'
#' @examples
#' # Jackknife with tidy-select
#' jk_design <- as_survey_rep(
#'   my_data,
#'   weights = wt,
#'   repweights = starts_with("repwt"),
#'   type = "JK1"
#' )
#'
#' # Bootstrap with explicit columns
#' boot_design <- as_survey_rep(
#'   my_data,
#'   weights = wt,
#'   repweights = c(rep1, rep2, rep3, rep4, rep5),
#'   type = "bootstrap"
#' )
#'
#' @export
survey_replicate <- S7::new_class(
  "survey_replicate",
  parent = survey_base,
  properties = list(
    # Inherits from survey_base
  ),
  validator = function(self) {
    # Similar validation structure
    # Check weights, repweights exist
    # Check all are numeric
    # Check type is valid
    # Check matrix dimensions match data
  }
)
```

---

## Component 2: Metadata System (UPDATED)

### File: `R/01-metadata-system.R`

**See Formal Specification Section II.2 for complete API**

This file implements the enhanced metadata system with both singular and plural functions.

#### 2.1 Extraction Functions (Singular)

[Same as Version 1.0 for extract_var_label, extract_val_labels, extract_question_preface, extract_var_note]

#### 2.2 Setting Functions - Singular (Outside mutate)

```r
#' Set Variable Label
#'
#' Set the variable label for a single variable in a survey object.
#'
#' @param x Survey object
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable to label (bare name)
#' @param label Character string with variable label
#'
#' @return Modified survey object
#'
#' @examples
#' survey_obj <- set_var_label(survey_obj, age, "Age in years")
#' survey_obj <- set_var_label(survey_obj, income, "Annual household income")
#'
#' # Pipe-friendly
#' survey_obj <- survey_obj |>
#'   set_var_label(age, "Age in years") |>
#'   set_var_label(income, "Annual household income")
#'
#' @seealso [set_variable_labels()] for setting multiple labels at once
#'
#' @export
set_var_label <- function(x, var, label) {
  UseMethod("set_var_label")
}

#' @export
set_var_label.survey_base <- function(x, var, label) {
  # Capture variable name
  var_name <- rlang::as_name(rlang::enquo(var))
  
  # Check variable exists
  if (!var_name %in% names(x@data)) {
    cli::cli_abort(c(
      "x" = "Variable {.field {var_name}} not found in data",
      "i" = "Available variables: {.field {names(x@data)}}"
    ))
  }
  
  # Set label
  x@metadata@variable_labels[[var_name]] <- label
  
  x
}
```

**Similar implementations for:**
- `set_val_labels(x, var, labels)`
- `set_question_preface(x, var, preface)`
- `set_var_note(x, var, note)`

#### 2.3 Setting Functions - Plural (Multiple Variables)

```r
#' Set Multiple Variable Labels
#'
#' Set variable labels for multiple variables using named arguments.
#'
#' @param x Survey object
#' @param ... Named arguments where names are variable names (unquoted) and
#'   values are labels
#'
#' @return Modified survey object
#'
#' @examples
#' # Named arguments
#' survey_obj <- set_variable_labels(
#'   survey_obj,
#'   age = "Age in years",
#'   income = "Annual household income",
#'   sex = "Biological sex"
#' )
#'
#' # Programmatic with list
#' labels <- list(age = "Age in years", income = "Annual income")
#' survey_obj <- set_variable_labels(survey_obj, !!!labels)
#'
#' @seealso [set_var_label()] for setting a single label
#'
#' @export
set_variable_labels <- function(x, ...) {
  UseMethod("set_variable_labels")
}

#' @export
set_variable_labels.survey_base <- function(x, ...) {
  labels <- rlang::list2(...)
  
  # Check all variables exist
  var_names <- names(labels)
  missing <- setdiff(var_names, names(x@data))
  
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "x" = "Variables not found in data",
      "i" = "Missing: {.field {missing}}"
    ))
  }
  
  # Set all labels
  for (var_name in var_names) {
    x@metadata@variable_labels[[var_name]] <- labels[[var_name]]
  }
  
  x
}
```

**Similar implementations for:**
- `set_value_labels(x, ...)` - Multiple value label assignments
- `set_question_prefaces(x, ...)` - Multiple question prefaces
- `set_variable_notes(x, ...)` - Multiple notes

#### 2.4 Value Label Validation

```r
#' Validate Value Labels
#'
#' Check value labels against actual values in variable. Issues warning
#' if labels are missing for some values.
#'
#' @param var Variable vector
#' @param labels Named vector of value labels
#' @param strict Logical. If TRUE, error on mismatches. Default FALSE (warn only).
#'
#' @return Invisibly returns TRUE if validation passes
#'
#' @keywords internal
validate_val_labels <- function(var, labels, strict = FALSE) {
  unique_vals <- unique(var[!is.na(var)])
  label_vals <- names(labels)
  
  # Check for extra labels (allowed - documents full coding scheme)
  extra <- setdiff(label_vals, as.character(unique_vals))
  # No warning for extra labels
  
  # Check for missing labels (warn)
  missing <- setdiff(as.character(unique_vals), label_vals)
  if (length(missing) > 0) {
    if (strict) {
      cli::cli_abort(c(
        "x" = "Not all values are labeled",
        "i" = "Unlabeled values: {.val {missing}}"
      ))
    } else {
      cli::cli_warn(c(
        "!" = "Not all values are labeled",
        "i" = "Unlabeled values: {.val {missing}}",
        "i" = "This is allowed but may be unintentional"
      ))
    }
  }
  
  invisible(TRUE)
}
```

Use this in `set_val_labels()`:
```r
set_val_labels.survey_base <- function(x, var, labels) {
  var_name <- rlang::as_name(rlang::enquo(var))
  
  # Validate labels is named
  if (is.null(names(labels)) || any(names(labels) == "")) {
    cli::cli_abort("Value labels must be a fully named vector")
  }
  
  # Validate against actual values
  validate_val_labels(x@data[[var_name]], labels, strict = FALSE)
  
  # Set labels
  x@metadata@value_labels[[var_name]] <- labels
  
  x
}
```

[Continue with remaining metadata functions from Version 1.0, updated with cli errors]

#### 2.5 Haven Metadata Extraction

```r
#' Extract haven-style metadata from a data frame
#'
#' Inspects each column for `"label"` and `"labels"` attributes set by haven
#' (or any other package/user following the same convention). Does NOT import
#' or call any haven functions — only uses base R `attr()`.
#'
#' @param data A data frame
#' @return A `survey_metadata` object (empty if no haven attributes found)
#' @keywords internal
extract_haven_metadata <- function(data) {
  var_labels <- list()
  val_labels <- list()

  for (col_name in names(data)) {
    col <- data[[col_name]]

    # haven stores variable labels as attr(x, "label") — length-1 character
    var_lbl <- attr(col, "label", exact = TRUE)
    if (!is.null(var_lbl) && is.character(var_lbl) && nzchar(var_lbl)) {
      var_labels[[col_name]] <- var_lbl[[1L]]
    }

    # haven stores value labels as attr(x, "labels") — named numeric or character
    val_lbl <- attr(col, "labels", exact = TRUE)
    if (!is.null(val_lbl) && length(val_lbl) > 0 && !is.null(names(val_lbl))) {
      val_labels[[col_name]] <- val_lbl
    }
  }

  survey_metadata(
    variable_labels = var_labels,
    value_labels    = val_labels
  )
}
```

**Key design decisions:**
- Uses `attr(col, "label", exact = TRUE)` not `haven::var_label()` — avoids runtime haven dependency
- `exact = TRUE` prevents partial matching
- `haven` stays in `Suggests`; this code works even if haven is not installed
- Works with any package that sets these attribute conventions (sjlabelled, labelled, etc.)

---

---

## Validator Architecture (3-Layer Contract)

Before implementing constructors and validators, understand the strict separation
of concerns across three layers. **No logic from one layer may be duplicated in
another.**

### Layer 1 — S7 Class Validator (`R/00-s7-classes.R`)

**Scope:** Structural invariants only. Checks that the stored object is internally
consistent AFTER construction. Called automatically by S7 on assignment.

**What to check:**
- Design variable column names exist in `@data`
- Weight column is numeric
- Non-NA weights are strictly positive
- Replicate weight columns are numeric
- Metadata variable names are a subset of `names(@data)`
- Design variables are atomic (not list-columns)

**What NOT to check:**
- User input parsing (that's Layer 3)
- Cross-field business rules like `nest = TRUE` requiring `strata` (Layer 3)
- `@groups` — always `character(0)` in Phase 0; **never validate in Phase 0**

### Layer 2 — Helper Validators (`R/02-validators.R`)

**Scope:** Reusable validation functions called by constructors and update_design().
Return `TRUE` invisibly on success; call `cli_abort()` or `cli_warn()` on failure.

**Functions to implement:**
- `.validate_weights(weights_var, data)` — existence, numeric, positive check
- `.validate_design_vars(vars, data)` — all named columns exist + are atomic
- `.validate_fpc(fpc_var, data)` — existence, no NAs
- `.validate_repweights(repweights_vars, data)` — existence, all numeric
- `.validate_psu_strata(ids, strata, data)` — cross-stratum PSU warning
- `.validate_rscales(rscales, n_rep)` — length match check

**Naming convention:** All helpers are internal (not exported), prefixed with `.`.

### Layer 3 — Constructor Input Parsing (`R/03-constructors.R`)

**Scope:** User-facing input validation only. Converts user-supplied arguments to
the canonical form expected by Layer 1. Runs BEFORE the S7 object is created.

**What to handle:**
- Tidy-select resolution (quosures → column name strings)
- Mutual exclusion: cannot specify both `probs` and `weights` inconsistently
- Conversion: `probs` → `weights = 1/probs` column
- SRS fallback: no ids/weights/probs → create `..surveycore_wt..` column + warn
- Business rules requiring cross-argument checks:
  - `nest = TRUE` requires `strata` (ERROR if strata is NULL)
  - `weights` all-zero check (ERROR)
  - `data` has 0 rows (ERROR) or 1 row (WARN)
  - `strata` has only 1 unique value (WARN)
  - `fpc` has NAs (ERROR)
  - `scale`/`rscales` length mismatch (ERROR)

---

## Constructor Error Case Table

Reference: `plans/error-messages.md` (canonical message text and error classes).
The table below maps conditions to implementation location within `as_survey()`,
`as_survey_rep()`, and `as_survey_twophase()`. All uses of `cli_abort()` must
pass a `class = "surveycore_error_<condition>"` argument.

| # | Condition | Level | Constructor | Layer |
|---|-----------|-------|-------------|-------|
| 1 | `data` not a data frame | ERROR | `as_survey()`, `as_survey_rep()`, `as_survey_twophase()` | 3 |
| 2 | `data` has 0 rows | ERROR | all | 3 |
| 3 | `data` has duplicate column names | ERROR | all | 3 |
| 4 | `data` has 1 row | WARN | all | 3 |
| 5 | Both `probs` and `weights`, inconsistent | ERROR | `as_survey()` | 3 |
| 6 | Both `probs` and `weights`, consistent | INFO | `as_survey()` | 3 |
| 7 | No weights/probs/ids (SRS fallback) | WARN | `as_survey()` | 3 |
| 8 | `weights` matches 0 columns | ERROR | all | 3 |
| 9 | `weights` matches >1 column | ERROR | all | 3 |
| 10 | `weights` all zero | ERROR | all | 3 (via `.validate_weights`) |
| 11 | `strata` matches >1 column | ERROR | `as_survey()` | 3 |
| 12 | `strata` has 1 unique value | WARN | `as_survey()` | 3 (via `.validate_design_vars`) |
| 13 | `fpc` matches >1 column | ERROR | `as_survey()` | 3 |
| 14 | `fpc` column has NAs | ERROR | `as_survey()` | 3 (via `.validate_fpc`) |
| 15 | `nest = TRUE` without `strata` | ERROR | `as_survey()` | 3 |
| 16 | `repweights` matches 0 columns | ERROR | `as_survey_rep()` | 3 |
| 17 | `rscales` length ≠ number of repweights | ERROR | `as_survey_rep()` | 3 (via `.validate_rscales`) |
| 18 | `type` not valid (match.arg) | ERROR | `as_survey_rep()` | 3 |
| 19 | `phase1` not `survey_taylor` | ERROR | `as_survey_twophase()` | 3 |
| 20 | `subset` missing | ERROR | `as_survey_twophase()` | 3 |
| 21 | `subset` matches >1 column | ERROR | `as_survey_twophase()` | 3 |
| 22 | `subset` column not logical | ERROR | `as_survey_twophase()` | 3 |
| 23 | `subset` all TRUE or all FALSE | ERROR | `as_survey_twophase()` | 3 |
| 24 | `method = "simple"` + clustered Phase 1 | WARN | `as_survey_twophase()` | 3 |
| 25 | `method = "full"` + no Phase 2 design info | WARN | `as_survey_twophase()` | 3 |
| 26 | Phase 2 design var all-NA in Phase 2 rows | WARN | S7 validator | 1 |
| 27–35 | (validators, metadata — see error-messages.md) | various | Layer 2 / Layer 1 | — |

---

## Component 3: Constructors (UPDATED - Tidy-Select)

### File: `R/03-constructors.R`

**See Formal Specification Section II.1 for complete API**

#### 3.1 as_survey() - Taylor Series Design

```r
#' Create Taylor Series Survey Design
#'
#' Create a survey design object using Taylor series linearization for
#' variance estimation. Uses tidy-select interface for intuitive specification.
#'
#' @param data Data frame containing survey data
#' @param ids <[`tidy-select`][tidyselect::tidyselect]> Cluster IDs.
#'   \itemize{
#'     \item Single-stage: Use bare name (e.g., `ids = psu`)
#'     \item Multi-stage: Use `c()` (e.g., `ids = c(psu, ssu)`)
#'     \item Simple random sample: Omit argument
#'   }
#' @param probs <[`tidy-select`][tidyselect::tidyselect]> Sampling probabilities.
#'   Converted to weights = 1/probs. Cannot specify both probs and weights.
#' @param weights <[`tidy-select`][tidyselect::tidyselect]> Sampling weights.
#' @param strata <[`tidy-select`][tidyselect::tidyselect]> Stratification variable.
#' @param fpc <[`tidy-select`][tidyselect::tidyselect]> Finite population correction
#'   (population sizes or sampling fractions).
#' @param nest Logical. If TRUE, cluster IDs are nested within strata.
#'   PSU-stratum integrity is always checked automatically (no argument needed).
#'
#' @return Object of class `survey_taylor`
#'
#' @section Tidy-Select:
#' This function supports tidy-select syntax for all design variables:
#' \itemize{
#'   \item Bare names: `ids = psu` or `ids = c(psu, ssu)`
#'   \item Helpers: `repweights = starts_with("repwt")`
#'   \item All tidyselect functions work
#' }
#'
#' @examples
#' library(surveycore)
#' 
#' # Simple random sample (omit ids)
#' srs <- as_survey(my_data, weights = wt)
#' 
#' # Stratified sample
#' strat <- as_survey(my_data, weights = wt, strata = region)
#' 
#' # Single-stage cluster
#' cluster <- as_survey(my_data, ids = psu, weights = wt)
#' 
#' # Two-stage cluster
#' twostage <- as_survey(my_data, ids = c(psu, ssu), weights = wt)
#' 
#' # With finite population correction
#' fpc_design <- as_survey(my_data, weights = wt, fpc = population_size)
#' 
#' # Using sampling probabilities instead of weights
#' prob_design <- as_survey(my_data, ids = psu, probs = selection_prob)
#'
#' @export
as_survey <- function(data,
                      ids = NULL,
                      probs = NULL,
                      weights = NULL,
                      strata = NULL,
                      fpc = NULL,
                      nest = FALSE) {
  
  # Capture call
  call <- match.call()
  
  # Validate data
  if (!is.data.frame(data)) {
    cli::cli_abort(c(
      "x" = "{.arg data} must be a data frame",
      "i" = "Got object of class {.cls {class(data)}}"
    ))
  }
  
  if (nrow(data) == 0) {
    cli::cli_abort("{.arg data} must have at least one row")
  }
  
  # Check for duplicate column names
  if (any(duplicated(names(data)))) {
    dupes <- names(data)[duplicated(names(data))]
    cli::cli_abort(c(
      "x" = "Column names must be unique",
      "i" = "Duplicate names: {.field {unique(dupes)}}"
    ))
  }
  
  # Initialize variables list
  variables <- list(nest = nest)
  
  # Evaluate tidy-select expressions
  # IDs
  ids_quo <- rlang::enquo(ids)
  if (!rlang::quo_is_null(ids_quo)) {
    ids_cols <- tidyselect::eval_select(ids_quo, data)
    variables$ids <- names(ids_cols)
  } else {
    variables$ids <- NULL
  }
  
  # Probs
  probs_quo <- rlang::enquo(probs)
  if (!rlang::quo_is_null(probs_quo)) {
    probs_cols <- tidyselect::eval_select(probs_quo, data)
    if (length(probs_cols) != 1) {
      cli::cli_abort(c(
        "x" = "{.arg probs} must select exactly one column",
        "i" = "Selected {length(probs_cols)} columns"
      ))
    }
    probs_var <- names(probs_cols)
    variables$probs_provided <- TRUE
  } else {
    probs_var <- NULL
    variables$probs_provided <- FALSE
  }
  
  # Weights
  weights_quo <- rlang::enquo(weights)
  if (!rlang::quo_is_null(weights_quo)) {
    weights_cols <- tidyselect::eval_select(weights_quo, data)
    if (length(weights_cols) != 1) {
      cli::cli_abort(c(
        "x" = "{.arg weights} must select exactly one column",
        "i" = "Selected {length(weights_cols)} columns"
      ))
    }
    weights_var <- names(weights_cols)
  } else {
    weights_var <- NULL
  }
  
  # Check probs/weights exclusivity
  if (!is.null(probs_var) && !is.null(weights_var)) {
    # Check consistency
    computed_weights <- 1 / data[[probs_var]]
    provided_weights <- data[[weights_var]]
    
    if (!isTRUE(all.equal(computed_weights, provided_weights, tolerance = 1e-6))) {
      cli::cli_abort(c(
        "x" = "Cannot specify both {.arg probs} and {.arg weights}",
        "i" = "Provided values are inconsistent",
        "i" = "weights should equal 1/probs"
      ))
    }
    
    # Use weights, note that probs was also provided
    cli::cli_inform("Using {.arg weights}; {.arg probs} is consistent")
  }
  
  # Convert probs to weights if needed
  if (!is.null(probs_var) && is.null(weights_var)) {
    weights_var <- "..surveycore_wt.."
    data[[weights_var]] <- 1 / data[[probs_var]]
  }
  
  # Handle simple random sample — allow but warn about limitations
  if (is.null(variables$ids) && is.null(weights_var) && is.null(probs_var)) {
    weights_var <- "..surveycore_wt.."
    data[[weights_var]] <- rep(1L, nrow(data))

    cli::cli_warn(c(
      "!" = "No weights or population size provided.",
      "i" = "Treating as equal-probability SRS with unknown population size.",
      "v" = "Valid: means, proportions, correlations, and their standard errors.",
      "x" = "Invalid: population totals (will equal sample totals, not population totals).",
      "i" = "To fix: provide {.arg fpc} = population size, or {.arg weights} = N / n."
    ))
  }
  
  # Weights required at this point
  if (is.null(weights_var)) {
    cli::cli_abort(c(
      "x" = "Must provide either {.arg weights}, {.arg probs}, or {.arg ids}",
      "i" = "For simple random sample, omit all three"
    ))
  }
  
  variables$weights <- weights_var
  
  # Strata
  strata_quo <- rlang::enquo(strata)
  if (!rlang::quo_is_null(strata_quo)) {
    strata_cols <- tidyselect::eval_select(strata_quo, data)
    if (length(strata_cols) != 1) {
      cli::cli_abort(c(
        "x" = "{.arg strata} must select exactly one column",
        "i" = "Selected {length(strata_cols)} columns"
      ))
    }
    variables$strata <- names(strata_cols)
  } else {
    variables$strata <- NULL
  }
  
  # FPC
  fpc_quo <- rlang::enquo(fpc)
  if (!rlang::quo_is_null(fpc_quo)) {
    fpc_cols <- tidyselect::eval_select(fpc_quo, data)
    if (length(fpc_cols) != 1) {
      cli::cli_abort(c(
        "x" = "{.arg fpc} must select exactly one column",
        "i" = "Selected {length(fpc_cols)} columns"
      ))
    }
    variables$fpc <- names(fpc_cols)
  } else {
    variables$fpc <- NULL
  }
  
  # Extract metadata from haven if present
  metadata <- extract_haven_metadata(data)
  
  # Create survey_taylor object
  obj <- survey_taylor(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
  )
  
  # Validator will check invariants
  
  obj
}
```

#### 3.2 as_survey_rep() - Replicate Weights Design

```r
#' Create Replicate Weights Survey Design
#'
#' Create a survey design object using replicate weights for variance estimation.
#'
#' @param data Data frame containing survey data
#' @param weights <[`tidy-select`][tidyselect::tidyselect]> Sampling weights (single column)
#' @param repweights <[`tidy-select`][tidyselect::tidyselect]> Replicate weights.
#'   Can use tidy-select helpers like `starts_with("repwt")`.
#' @param type Character string specifying replicate weight type. One of:
#'   "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", 
#'   "successive-difference", "other"
#' @param scale Numeric. Scaling factor for variance estimation. If NULL,
#'   determined from type
#' @param rscales Numeric vector of replicate-specific scaling factors
#' @param fpc Finite population correction (for some bootstrap types)
#' @param fpctype Character. "fraction" or "correction"
#' @param mse Logical. Use MSE estimates?
#'
#' @return Object of class `survey_replicate`
#'
#' @examples
#' library(surveycore)
#' 
#' # Jackknife with explicit columns
#' jk_design <- as_survey_rep(
#'   my_data,
#'   weights = wt,
#'   repweights = c(repwt1, repwt2, repwt3),
#'   type = "JK1"
#' )
#' 
#' # Bootstrap with tidy-select helper
#' boot_design <- as_survey_rep(
#'   my_data,
#'   weights = wt,
#'   repweights = starts_with("repwt"),
#'   type = "bootstrap"
#' )
#'
#' @export
as_survey_rep <- function(data,
                          weights,
                          repweights,
                          type = c("JK1", "JK2", "JKn", "BRR", "Fay", 
                                   "bootstrap", "ACS", "successive-difference",
                                   "other"),
                          scale = NULL,
                          rscales = NULL,
                          fpc = NULL,
                          fpctype = c("fraction", "correction"),
                          mse = TRUE) {
  
  # Match type
  type <- match.arg(type)
  fpctype <- match.arg(fpctype)
  
  # Capture call
  call <- match.call()
  
  # [Similar validation as as_survey]
  
  # Evaluate tidy-select for weights
  weights_quo <- rlang::enquo(weights)
  weights_cols <- tidyselect::eval_select(weights_quo, data)
  if (length(weights_cols) != 1) {
    cli::cli_abort(c(
      "x" = "{.arg weights} must select exactly one column",
      "i" = "Selected {length(weights_cols)} columns"
    ))
  }
  weights_var <- names(weights_cols)
  
  # Evaluate tidy-select for repweights
  repweights_quo <- rlang::enquo(repweights)
  repweights_cols <- tidyselect::eval_select(repweights_quo, data)
  if (length(repweights_cols) == 0) {
    cli::cli_abort("{.arg repweights} must select at least one column")
  }
  repweights_vars <- names(repweights_cols)
  # NOTE: repweight_matrix is NOT stored. The matrix is computed on demand
  # inside variance estimation:  as.matrix(design@data[, design@variables$repweights])
  # This is the single source of truth and avoids sync bugs when data changes.

  # Set default scale based on type if not provided
  if (is.null(scale)) {
    scale <- switch(type,
      "JK1" = 1,
      "JK2" = 1,
      "JKn" = 1,
      "BRR" = 1,
      "Fay" = 1,
      "bootstrap" = 1,
      1  # default
    )
  }
  
  # Build variables list
  variables <- list(
    weights    = weights_var,
    repweights = repweights_vars,  # column names only; no cached matrix
    type       = type,
    scale      = scale,
    rscales    = rscales,
    fpc        = fpc,
    fpctype    = fpctype,
    mse        = mse
  )
  
  # Extract metadata
  metadata <- extract_haven_metadata(data)
  
  # Create survey_replicate object
  obj <- survey_replicate(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
  )
  
  obj
}
```

#### 3.3 as_survey_twophase() — Phase 1 Object + Phase 2 Tidy-Select

```r
#' Create Two-Phase Survey Design
#'
#' @param phase1 A \code{survey_taylor} object representing the phase 1 design.
#'   Its \code{@data} must contain ALL rows from both phases, including a logical
#'   column indicating phase 2 membership.
#' @param ids2 <[\`tidy-select\`][tidyselect::tidyselect]> Phase 2 cluster IDs.
#'   Optional — omit if phase 2 has no clustering.
#' @param strata2 <[\`tidy-select\`][tidyselect::tidyselect]> Phase 2 stratification.
#' @param probs2 <[\`tidy-select\`][tidyselect::tidyselect]> Phase 2 sampling probs.
#' @param fpc2 <[\`tidy-select\`][tidyselect::tidyselect]> Phase 2 FPC.
#' @param subset <[\`tidy-select\`][tidyselect::tidyselect]> Single logical column.
#'   \code{TRUE} = row selected into phase 2. \code{FALSE} = phase 1 only.
#' @param method One of \code{"full"} (default), \code{"approx"}, \code{"simple"}.
#'
#' @return Object of class \code{survey_twophase}
#'
#' @examples
#' # Phase 1: full cohort
#' phase1 <- as_survey(pbc_data, ids = id, weights = phase1_wt)
#'
#' # Minimal two-phase (no phase 2 clustering/stratification)
#' d2 <- as_survey_twophase(phase1, subset = randomized)
#'
#' # With phase 2 stratification
#' d2_strat <- as_survey_twophase(
#'   phase1,
#'   strata2 = treatment_arm,
#'   subset  = in_phase2
#' )
#'
#' @export
as_survey_twophase <- function(phase1,
                               ids2    = NULL,
                               strata2 = NULL,
                               probs2  = NULL,
                               fpc2    = NULL,
                               subset,
                               method  = c("full", "approx", "simple")) {

  method <- match.arg(method)
  call   <- match.call()

  # Validate phase1
  if (!S7::inherits(phase1, survey_taylor)) {
    cli::cli_abort(c(
      "x" = "{.arg phase1} must be a {.cls survey_taylor} object.",
      "i" = "Create it first with {.fn as_survey}."
    ))
  }

  data <- phase1@data

  # Evaluate subset (required)
  subset_quo <- rlang::enquo(subset)
  if (rlang::quo_is_missing(subset_quo)) {
    cli::cli_abort("{.arg subset} is required: a logical column indicating phase 2 membership.")
  }
  subset_cols <- tidyselect::eval_select(subset_quo, data)
  if (length(subset_cols) != 1) {
    cli::cli_abort(c(
      "x" = "{.arg subset} must select exactly one column.",
      "i" = "Selected {length(subset_cols)} columns."
    ))
  }
  subset_var <- names(subset_cols)

  if (!is.logical(data[[subset_var]])) {
    cli::cli_abort(c(
      "x" = "{.arg subset} column {.field {subset_var}} must be logical.",
      "i" = "Got class {.cls {class(data[[subset_var]])}}."
    ))
  }

  # Evaluate optional phase 2 design elements
  .eval_optional <- function(quo, data, arg_name) {
    if (rlang::quo_is_null(quo)) return(NULL)
    cols <- tidyselect::eval_select(quo, data)
    if (length(cols) == 0) {
      cli::cli_abort("{.arg {arg_name}} matched no columns.")
    }
    names(cols)
  }

  phase2_vars <- list(
    ids    = .eval_optional(rlang::enquo(ids2),    data, "ids2"),
    strata = .eval_optional(rlang::enquo(strata2), data, "strata2"),
    probs  = .eval_optional(rlang::enquo(probs2),  data, "probs2"),
    fpc    = .eval_optional(rlang::enquo(fpc2),    data, "fpc2")
  )

  # Build variables list
  variables <- list(
    phase1  = phase1@variables,   # phase 1 design spec (already validated)
    phase2  = phase2_vars,        # phase 2 design spec
    subset  = subset_var,
    method  = method
  )

  # Inherit metadata from phase1
  metadata <- phase1@metadata

  survey_twophase(
    data      = data,
    metadata  = metadata,
    variables = variables,
    call      = call
  )
}
```

---

## Component 4: Update Design Function (NEW)

### File: `R/08-update-design.R`

```r
#' Update Survey Design
#'
#' Update design variables in an existing survey object. Use this when you've
#' modified the data and need to update the design specification accordingly.
#'
#' @param x Survey object
#' @param weights <[`tidy-select`][tidyselect::tidyselect]> New weight variable
#' @param ids <[`tidy-select`][tidyselect::tidyselect]> New cluster IDs
#' @param strata <[`tidy-select`][tidyselect::tidyselect]> New strata variable
#' @param fpc <[`tidy-select`][tidyselect::tidyselect]> New FPC variable
#' @param validate Logical. If TRUE (default), revalidate entire object after update.
#'
#' @return Modified survey object with updated design
#'
#' @section Warning:
#' Updating the survey design after data manipulation may affect the statistical
#' validity of your analysis. Only use this function if you understand the
#' implications for variance estimation.
#'
#' @examples
#' # Modify data, then update design
#' survey_obj@data$new_wt <- calculate_new_weights()
#' survey_obj <- update_design(survey_obj, weights = new_wt)
#'
#' # Update multiple design variables
#' survey_obj <- update_design(
#'   survey_obj,
#'   weights = new_wt,
#'   strata = new_strata
#' )
#'
#' @export
update_design <- function(x, 
                         weights = NULL,
                         ids = NULL,
                         strata = NULL,
                         fpc = NULL,
                         validate = TRUE) {
  UseMethod("update_design")
}

#' @export
update_design.survey_taylor <- function(x,
                                       weights = NULL,
                                       ids = NULL,
                                       strata = NULL,
                                       fpc = NULL,
                                       validate = TRUE) {
  
  cli::cli_warn(c(
    "!" = "Updating survey design",
    "i" = "This may affect statistical validity",
    "i" = "Ensure you understand the implications for variance estimation"
  ))
  
  # Update weights
  weights_quo <- rlang::enquo(weights)
  if (!rlang::quo_is_null(weights_quo)) {
    weights_cols <- tidyselect::eval_select(weights_quo, x@data)
    if (length(weights_cols) != 1) {
      cli::cli_abort("{.arg weights} must select exactly one column")
    }
    x@variables$weights <- names(weights_cols)
  }
  
  # Update ids
  ids_quo <- rlang::enquo(ids)
  if (!rlang::quo_is_null(ids_quo)) {
    ids_cols <- tidyselect::eval_select(ids_quo, x@data)
    x@variables$ids <- names(ids_cols)
  }
  
  # Update strata
  strata_quo <- rlang::enquo(strata)
  if (!rlang::quo_is_null(strata_quo)) {
    strata_cols <- tidyselect::eval_select(strata_quo, x@data)
    if (length(strata_cols) != 1) {
      cli::cli_abort("{.arg strata} must select exactly one column")
    }
    x@variables$strata <- names(strata_cols)
  }
  
  # Update fpc
  fpc_quo <- rlang::enquo(fpc)
  if (!rlang::quo_is_null(fpc_quo)) {
    fpc_cols <- tidyselect::eval_select(fpc_quo, x@data)
    if (length(fpc_cols) != 1) {
      cli::cli_abort("{.arg fpc} must select exactly one column")
    }
    x@variables$fpc <- names(fpc_cols)
  }
  
  # Revalidate if requested
  if (validate) {
    # Force S7 to run the class validator by re-assigning the object.
    # This checks ALL invariants (Invariants 1-5 from formal spec Section I).
    # Any violation triggers cli_abort() from the validator function.
    S7::S7_validate(x)
  }

  x
}

#' @export
update_design.survey_replicate <- function(x,
                                           weights = NULL,
                                           repweights = NULL,
                                           validate = TRUE) {
  cli::cli_warn(c(
    "!" = "Updating replicate survey design",
    "i" = "This may affect statistical validity"
  ))

  # Update weights
  weights_quo <- rlang::enquo(weights)
  if (!rlang::quo_is_null(weights_quo)) {
    w_cols <- tidyselect::eval_select(weights_quo, x@data)
    if (length(w_cols) != 1) cli::cli_abort("{.arg weights} must select exactly one column")
    x@variables$weights <- names(w_cols)
  }

  # Update repweights column name list
  repweights_quo <- rlang::enquo(repweights)
  if (!rlang::quo_is_null(repweights_quo)) {
    rw_cols <- tidyselect::eval_select(repweights_quo, x@data)
    x@variables$repweights <- names(rw_cols)
    # NOTE: No matrix to rebuild — repweight_matrix is not stored.
    # Variance estimation computes: as.matrix(x@data[, x@variables$repweights])
  }

  if (validate) {
    S7::S7_validate(x)
  }

  x
}

# update_design.survey_twophase: similar pattern, no repweight_matrix
```

---

## Component 5: Print Methods (UPDATED)

### File: `R/04-methods-print.R`

> **S7 Method Syntax — REQUIRED for ALL print/summary/format methods:**
>
> All method definitions for S7 classes must use S7 registration syntax.
> S3 method naming (`generic.class <- function(...)`) is **silently ignored**
> for S7 objects — `print(design_obj)` will fall back to default S7 printing
> with no error, making this the worst kind of bug to diagnose.
>
> **WRONG (S3 — silently ignored for S7 classes):**
> ```r
> print.survey_taylor   <- function(x, ...) { ... }
> summary.survey_taylor <- function(object, ...) { ... }
> ```
>
> **CORRECT (S7 — required):**
> ```r
> S7::method(print,   survey_taylor)   <- function(x, n = 10, ...) { ... }
> S7::method(summary, survey_taylor)   <- function(object, ...) { ... }
> S7::method(print,   survey_replicate) <- function(x, n = 10, ...) { ... }
> S7::method(summary, survey_replicate) <- function(object, ...) { ... }
> S7::method(print,   survey_twophase)  <- function(x, n = 10, ...) { ... }
> S7::method(summary, survey_twophase)  <- function(object, ...) { ... }
> ```
>
> This applies to ALL generics being dispatched on S7 classes, including
> `print`, `summary`, `format`, `str`, and any dplyr generics in Phase 0.5.
> The ONLY exception: functions using `UseMethod()` with a custom S3 generic
> (e.g., `set_var_label.survey_base`) are legitimate S3 dispatch on S7 objects.

```r
#' Print Survey Design
#'
#' @param x Survey design object
#' @param n Number of data rows to print (default 10)
#' @param design_info Show design specification details?
#' @param weights_info Show weight distribution?
#' @param strata_info Show strata details?
#' @param cluster_info Show cluster details?
#' @param metadata_info Show metadata summary?
#' @param full Show all information (overrides other arguments)
#' @param ... Additional arguments (currently unused)
#'
#' @return x invisibly
#'
# NOTE: Use S7 method registration, not S3 syntax.
# The function body below is correct; only the definition line changes.
S7::method(print, survey_taylor) <- function(x, 
                               n = 10,
                               design_info = FALSE,
                               weights_info = FALSE,
                               strata_info = FALSE,
                               cluster_info = FALSE,
                               metadata_info = FALSE,
                               full = FALSE,
                               ...) {
  
  # If full = TRUE, show everything
  if (full) {
    design_info <- weights_info <- strata_info <- 
      cluster_info <- metadata_info <- TRUE
  }
  
  # Header
  cli::cli_h1("Survey Design")
  cli::cli_text("{.cls survey_taylor} (Taylor series linearization)")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  # Show active groups (mirroring dplyr grouped tibble)
  if (length(x@groups) > 0) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }
  
  if (weights_info || full) {
    wts <- x@data[[x@variables$weights]]
    cli::cli_text("Weighted N: {.val {round(sum(wts, na.rm = TRUE))}}")
  }
  
  cli::cli_text("")
  
  # Design specification
  if (design_info || full) {
    cli::cli_h2("Design specification")
    
    if (!is.null(x@variables$ids)) {
      cli::cli_bullets(c(
        "*" = "IDs: {.field {x@variables$ids}}"
      ))
    }
    
    if (!is.null(x@variables$strata)) {
      n_strata <- length(unique(x@data[[x@variables$strata]]))
      cli::cli_bullets(c(
        "*" = "Strata: {.field {x@variables$strata}} ({n_strata} strata)"
      ))
    }
    
    # Show weight column name
    cli::cli_bullets(c(
      "*" = "Weights: {.field {x@variables$weights}}"
    ))

    # Show whether user supplied probs or weights (only if not SRS auto-weight)
    wt_var <- x@variables$weights
    if (!identical(wt_var, "..surveycore_wt..")) {
      wt_source <- if (isTRUE(x@variables$probs_provided)) {
        "sampling probabilities (converted)"
      } else {
        "sampling weights"
      }
      cli::cli_bullets(c(
        "*" = "Weights provided as: {wt_source}"
      ))
    }

    if (!is.null(x@variables$fpc)) {
      cli::cli_bullets(c(
        "*" = "FPC: {.field {x@variables$fpc}}"
      ))
    }
    
    cli::cli_bullets(c(
      "*" = "Nesting: {.val {x@variables$nest}}"
    ))
    
    cli::cli_text("")
  }
  
  # Weight distribution
  if (weights_info || full) {
    wts <- x@data[[x@variables$weights]]
    cli::cli_h2("Weight distribution")
    cli::cli_bullets(c(
      "*" = "Range: {.val {round(min(wts, na.rm=TRUE), 2)}} - {.val {round(max(wts, na.rm=TRUE), 2)}}",
      "*" = "Mean: {.val {round(mean(wts, na.rm=TRUE), 2)}}",
      "*" = "CV: {.val {round(sd(wts, na.rm=TRUE)/mean(wts, na.rm=TRUE), 3)}}"
    ))
    cli::cli_text("")
  }
  
  # Metadata summary
  if (metadata_info || full) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
    cli::cli_text("")
  }
  
  # Data
  cli::cli_h2("Data")
  
  # Determine which columns to show
  # If user selected certain columns, show those
  # Otherwise show all non-design columns
  visible_vars <- attr(x, "visible_vars")
  if (!is.null(visible_vars)) {
    data_to_print <- x@data[, visible_vars, drop = FALSE]
  } else {
    data_to_print <- x@data
  }
  
  # Print as tibble
  print(tibble::as_tibble(data_to_print), n = n)
  
  # Note about hidden design variables
  design_vars <- unique(c(
    x@variables$ids,
    x@variables$weights,
    x@variables$strata,
    x@variables$fpc
  ))
  hidden_vars <- setdiff(design_vars, names(data_to_print))
  
  if (length(hidden_vars) > 0) {
    cli::cli_text("")
    cli::cli_bullets(c(
      "i" = "Design variables preserved but hidden: {.field {hidden_vars}}",
      "i" = "Use {.code print(x, full = TRUE)} to show all variables"
    ))
  }
  
  invisible(x)
}

# Similar for survey_replicate and survey_twophase
```

---

## Component 6: Validators (UPDATED - CLI)

### File: `R/02-validators.R`

Update all validators to use `cli` for errors/warnings:

```r
#' Validate Survey Design Variables
#'
#' Internal validation functions for checking design specifications.
#'
#' @name validators
#' @keywords internal
NULL

#' @describeIn validators Validate ID specification
validate_ids <- function(ids, data, nest = FALSE) {
  if (is.null(ids)) return(TRUE)
  
  # Check ids columns exist
  missing <- setdiff(ids, names(data))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "x" = "Cluster ID variables not found in data",
      "i" = "Missing: {.field {missing}}",
      "i" = "Available: {.field {names(data)}}"
    ))
  }
  
  # Check for duplicates if not nested
  if (!nest && length(ids) > 0) {
    id_combos <- do.call(paste, c(data[ids], sep = "_"))
    if (any(duplicated(id_combos))) {
      cli::cli_warn(c(
        "!" = "Duplicate cluster ID combinations found",
        "i" = "Consider setting {.code nest = TRUE} if IDs are nested within strata"
      ))
    }
  }
  
  TRUE
}

#' @describeIn validators Validate weights
validate_weights <- function(weights, data) {
  # Check exists
  if (!weights %in% names(data)) {
    cli::cli_abort(c(
      "x" = "Weight variable {.field {weights}} not found in data",
      "i" = "Available: {.field {names(data)}}"
    ))
  }
  
  wt_col <- data[[weights]]
  
  # Check numeric
  if (!is.numeric(wt_col)) {
    cli::cli_abort(c(
      "x" = "Weights must be numeric",
      "i" = "{.field {weights}} has class {.cls {class(wt_col)}}"
    ))
  }
  
  # Check positive
  if (any(wt_col <= 0, na.rm = TRUE)) {
    n_bad <- sum(wt_col <= 0, na.rm = TRUE)
    cli::cli_abort(c(
      "x" = "Weights must be positive",
      "i" = "Found {n_bad} non-positive weight(s) in {.field {weights}}"
    ))
  }
  
  # Warn about extreme weights
  cv <- sd(wt_col, na.rm = TRUE) / mean(wt_col, na.rm = TRUE)
  if (cv > 1) {
    cli::cli_warn(c(
      "!" = "Highly variable weights detected",
      "i" = "Coefficient of variation: {.val {round(cv, 2)}}",
      "i" = "This may indicate issues with the weighting scheme"
    ))
  }
  
  TRUE
}

# Similar updates for validate_fpc, validate_repweights

#' @describeIn validators Check PSU-stratum integrity (replaces check.strata argument)
#' Issues a warning if any PSU appears in more than one stratum.
#' Called automatically from the survey_taylor validator — no user argument needed.
#' @keywords internal
validate_psu_strata <- function(ids, strata, data) {
  if (is.null(ids) || is.null(strata)) return(invisible(TRUE))

  # Use first-stage PSU only
  psu_col    <- data[[ids[[1]]]]
  strata_col <- data[[strata]]

  # Find PSUs that appear in more than one stratum
  psu_strata <- tapply(as.character(strata_col), psu_col, function(x) length(unique(x)))
  multi_strata_psus <- names(psu_strata)[psu_strata > 1]

  if (length(multi_strata_psus) > 0) {
    cli::cli_warn(c(
      "!" = "Some PSUs appear in more than one stratum.",
      "i" = "Affected PSUs: {.val {head(multi_strata_psus, 5)}}{if (length(multi_strata_psus) > 5) ' ...' else ''}",
      "i" = "If PSUs are nested within strata this is expected — set {.code nest = TRUE}.",
      "i" = "Otherwise this may indicate a data error."
    ))
  }

  invisible(TRUE)
}

#' @describeIn validators Update design variable names after rename()
#' Called by rename.survey_base() when a design variable is renamed.
#' @param x Survey object
#' @param rename_map Named character vector: old_name -> new_name
#' @keywords internal
.update_design_var_names <- function(x, rename_map) {
  vars <- x@variables

  # Update scalar design variables (weights, strata, fpc)
  for (slot in c("weights", "strata", "fpc")) {
    if (!is.null(vars[[slot]]) && vars[[slot]] %in% names(rename_map)) {
      vars[[slot]] <- rename_map[[vars[[slot]]]]
    }
  }

  # Update ids (character vector, may have multiple stages)
  if (!is.null(vars$ids)) {
    vars$ids <- ifelse(vars$ids %in% names(rename_map), rename_map[vars$ids], vars$ids)
  }

  # Update replicate weight column names (survey_replicate only)
  if (!is.null(vars$repweights)) {
    vars$repweights <- ifelse(
      vars$repweights %in% names(rename_map),
      rename_map[vars$repweights],
      vars$repweights
    )
    # NOTE: No repweight_matrix to update — it is not stored.
    # Variance estimation computes the matrix on demand from the column names.
  }

  x@variables <- vars
  x
}

#' @describeIn validators Update metadata keys after rename()
#' Keeps metadata in sync when column names change.
#' @keywords internal
.rename_metadata_keys <- function(metadata, rename_map) {
  slot_names <- c(
    "variable_labels", "value_labels", "question_prefaces",
    "transformations", "notes"
  )
  for (s in slot_names) {
    vals <- metadata@.Data[[s]]  # adjust based on actual S7 property access
    if (length(vals) > 0 && !is.null(names(vals))) {
      names(vals) <- ifelse(
        names(vals) %in% names(rename_map),
        rename_map[names(vals)],
        names(vals)
      )
      metadata@.Data[[s]] <- vals
    }
  }
  metadata
}
```

---

## Testing Updates

---

### Test Helper Specification (`tests/testthat/helper-test-data.R`)

This file must be implemented before any other test files. It provides the
synthetic data generators and shared helpers used across the test suite.

#### `make_survey_data()` — Synthetic Survey Data Generator

```r
#' Create synthetic survey data for testing
#'
#' Generates realistic but artificial survey data with known design structure.
#' Use this for unit tests. Use example package datasets (nhanes_2017, etc.)
#' only for numerical validation tests that compare against the survey package.
#'
#' @param n        Total rows (respondents). Default 500.
#' @param n_psu    Number of primary sampling units. Default 50.
#'                 PSU sizes vary (not uniform — more realistic).
#' @param n_strata Number of strata. Default 5.
#'                 PSUs are distributed across strata; weights vary by stratum.
#' @param design   One of "taylor", "replicate", "twophase".
#' @param type     Replicate type if design = "replicate". Default "brr".
#' @param with_labels  Logical. If TRUE, add haven-style label attributes
#'                     (requires haven in Suggests; uses skip_if_not_installed).
#'
#' @return A plain data.frame (never a tibble) with:
#'   - Design columns: psu, ssu, strata, wt (and repwt_* if design="replicate")
#'   - 3 numeric outcome vars: y1, y2, y3
#'   - 1 categorical var: group (values "A", "B", "C")
#'   - 1 logical var: phase2_ind (if design = "twophase")
#'
#' @keywords internal
make_survey_data <- function(
  n           = 500L,
  n_psu       = 50L,
  n_strata    = 5L,
  design      = c("taylor", "replicate", "twophase"),
  type        = "brr",
  with_labels = FALSE
) {
  design <- match.arg(design)
  set.seed(42L)  # reproducible across tests

  # ... implementation ...
}
```

**Design rules for `make_survey_data()`:**
- PSU sizes must VARY (not equal) — use `sample(5:15, n_psu, replace = TRUE)`
- Weights must VARY (not uniform) — generate stratum-specific weights
- The data must make statistical sense (weights sum to reasonable population size)
- For `design = "replicate"` with `type = "brr"`: generate `n_psu / 2` replicate
  weights (BRR requires even number of PSUs, so ensure `n_psu` is even)
- For `design = "twophase"`: create a logical `phase2_ind` column with ~40% TRUE

**Dataset policy:**
| Data source | When to use |
|-------------|-------------|
| `make_survey_data()` | All unit tests, validator tests, constructor tests |
| `nhanes_2017` (package dataset) | Numerical comparison vs. `survey` package (Taylor SE) |
| `acs_pums_wy` (package dataset) | Numerical comparison vs. `survey` package (replicate SE) |
| Inline `data.frame(...)` | Edge cases: 1-row data, all-NA column, single PSU, etc. |

**`skip_if_not_installed` convention:**
All tests that use `survey` or `srvyr` packages must begin with:
```r
skip_if_not_installed("survey")
```
All tests that create `haven::labelled()` vectors must begin with:
```r
skip_if_not_installed("haven")
```

---

#### `test_invariants()` — Invariant Checker

```r
#' Assert all 5 formal invariants on a survey object
#'
#' Call this after EVERY test that produces a survey object to verify the
#' object satisfies all invariants from formal spec Section I.
#'
#' @param design A survey_taylor, survey_replicate, or survey_twophase object
#' @keywords internal
test_invariants <- function(design) {
  # Invariant 1: Data structure
  expect_true(is.data.frame(design@data))
  expect_true(!is.null(design@data))
  expect_gte(nrow(design@data), 1L)
  expect_true(!anyDuplicated(names(design@data)))

  # Invariant 2: Design variables exist and are atomic
  design_vars <- .get_design_vars_flat(design)  # returns character vector
  for (v in design_vars) {
    expect_true(v %in% names(design@data),
                info = paste("Design var", v, "missing from data"))
    expect_true(is.atomic(design@data[[v]]),
                info = paste("Design var", v, "is not atomic"))
  }

  # Invariant 3: Weights are numeric and positive
  wt_var <- design@variables$weights
  if (!is.null(wt_var)) {
    wt_col <- design@data[[wt_var]]
    expect_true(is.numeric(wt_col))
    expect_true(all(wt_col[!is.na(wt_col)] > 0))
  }

  # Invariant 4: Replicate weights are numeric (survey_replicate only)
  if (inherits(design, "survey_replicate")) {
    for (rw in design@variables$repweights) {
      expect_true(is.numeric(design@data[[rw]]),
                  info = paste("Replicate weight", rw, "is not numeric"))
    }
  }

  # Invariant 5: Metadata variable names subset of data names
  meta_vars <- names(design@metadata@variable_labels)
  if (length(meta_vars) > 0) {
    expect_true(all(meta_vars %in% names(design@data)),
                info = "Metadata references variables not in data")
  }

  invisible(design)
}
```

**Rule:** `test_invariants(design)` must be called in every `test_that()` block
that creates or modifies a survey object.

---

### `test-variance-estimation.R` Template

This file validates that vendored variance functions produce results numerically
equivalent to the `survey` package. It is the core correctness test for Phase 0.

```r
# test-variance-estimation.R
# Numerical validation: surveycore variance == survey package variance
# Tolerance: 1e-10 for point estimates, 1e-8 for variance estimates

# ---------------------------------------------------------------------------
# Block 1: Taylor Series Linearization
# ---------------------------------------------------------------------------

test_that("Taylor SE matches survey package — NHANES stratified cluster", {
  skip_if_not_installed("survey")

  # Build surveycore design
  sc_design <- as_survey(
    nhanes_2017,
    ids     = sdmvpsu,
    strata  = sdmvstra,
    weights = wtmec2yr
  )

  # Build survey package design (for comparison)
  sv_design <- survey::svydesign(
    ids     = ~sdmvpsu,
    strata  = ~sdmvstra,
    weights = ~wtmec2yr,
    data    = nhanes_2017,
    nest    = TRUE
  )

  # Point estimate comparison
  sc_mean <- get_mean(sc_design, bpxsy1)
  sv_mean <- survey::svymean(~bpxsy1, sv_design, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   SE(sv_mean)[["bpxsy1"]],   tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 2: Replicate Weights
# ---------------------------------------------------------------------------

test_that("Replicate SE matches survey package — ACS PUMS BRR", {
  skip_if_not_installed("survey")

  # ACS PUMS Wyoming uses BRR replicate weights (repwt1..repwt80)
  sc_rep <- as_survey_rep(
    acs_pums_wy,
    weights    = pwgtp,
    repweights = starts_with("pwgtp"),
    type       = "BRR"
  )

  sv_rep <- survey::svrepdesign(
    weights    = ~pwgtp,
    repweights = acs_pums_wy[, grep("^pwgtp[0-9]", names(acs_pums_wy))],
    type       = "BRR",
    data       = acs_pums_wy
  )

  sc_total <- get_total(sc_rep, agep)
  sv_total <- survey::svytotal(~agep, sv_rep, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["agep"]], tolerance = 1e-10)
  expect_equal(sc_total$se,    SE(sv_total)[["agep"]],   tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 3: Two-Phase Design
# ---------------------------------------------------------------------------

test_that("Two-phase SE matches survey package — synthetic", {
  skip_if_not_installed("survey")

  # Use synthetic two-phase data for reproducibility
  d <- make_survey_data(n = 500, design = "twophase")
  phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)

  sc_two <- as_survey_twophase(phase1, subset = phase2_ind)
  sv_two <- survey::twophase(
    id     = list(~psu, ~1),
    strata = list(~strata, NULL),
    weights = list(~wt, NULL),
    subset  = ~phase2_ind,
    data    = d
  )

  sc_mean <- get_mean(sc_two, y1)
  sv_mean <- survey::svymean(~y1, sv_two, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   SE(sv_mean)[["y1"]],   tolerance = 1e-8)
})
```

---

### Error Path Sections for Test Files

Each test file below includes an "Error Paths" section that maps to the
canonical error table in `plans/error-messages.md`. Use BOTH:
- `expect_error(..., class = "surveycore_error_<condition>")` — typed error class
- `expect_snapshot(error = TRUE, ...)` — exact CLI message text (golden test)

#### `test-constructors.R` — Error Paths

Covers error table rows 1–26 from `error-messages.md`:

```r
# --- Error Paths: as_survey() ---

test_that("as_survey errors: data not a data frame [row 1]", {
  expect_error(
    as_survey(list(x = 1:5), weights = x),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(error = TRUE,
    as_survey(list(x = 1:5), weights = x)
  )
})

test_that("as_survey errors: empty data [row 2]", {
  expect_error(
    as_survey(data.frame(), weights = x),
    class = "surveycore_error_empty_data"
  )
})

test_that("as_survey errors: nest=TRUE without strata [row 15]", {
  d <- data.frame(psu = 1:10, wt = rep(1, 10), y = rnorm(10))
  expect_error(
    as_survey(d, ids = psu, weights = wt, nest = TRUE),
    class = "surveycore_error_nest_without_strata"
  )
})

test_that("as_survey warns: single stratum [row 12]", {
  d <- data.frame(st = rep("A", 10), wt = rep(1, 10), y = rnorm(10))
  expect_warning(
    as_survey(d, weights = wt, strata = st),
    class = "surveycore_warning_single_stratum"
  )
})

# --- Error Paths: as_survey_rep() ---

test_that("as_survey_rep errors: rscales length mismatch [row 17]", {
  d <- make_survey_data(design = "replicate")
  expect_error(
    as_survey_rep(d, weights = wt, repweights = starts_with("repwt"),
                  type = "BRR", rscales = c(1, 2)),  # wrong length
    class = "surveycore_error_rscales_length"
  )
})

# --- Error Paths: as_survey_twophase() ---

test_that("as_survey_twophase errors: degenerate subset [row 23]", {
  d <- make_survey_data(design = "twophase")
  d$all_true <- TRUE
  phase1 <- as_survey(d, ids = psu, weights = wt)
  expect_error(
    as_survey_twophase(phase1, subset = all_true),
    class = "surveycore_error_subset_degenerate"
  )
})
```

#### `test-validators.R` — Error Paths

Covers error table rows 27–35:

```r
test_that("set_var_label errors: variable not in data [row 27]", {
  design <- as_survey(make_survey_data(), weights = wt)
  expect_error(
    set_var_label(design, nonexistent_var, "A label"),
    class = "surveycore_error_var_not_found"
  )
})

test_that("S7 validator errors: non-positive weight [row 33]", {
  # Force a bad weight past the constructor by direct property assignment
  d <- make_survey_data()
  d$wt[1] <- -1
  expect_error(
    survey_taylor(data = d, variables = list(weights = "wt", ids = NULL,
                  strata = NULL, fpc = NULL, nest = FALSE, probs_provided = FALSE)),
    class = "surveycore_error_weights_nonpositive"
  )
})
```

---

### File: `tests/testthat/test-tidy-select.R` (NEW)

```r
# Test tidy-select interface

test_that("as_survey accepts bare names", {
  design <- as_survey(test_data, ids = cluster, weights = wt)
  
  expect_s7_class(design, "survey_taylor")
  expect_equal(design@variables$ids, "cluster")
  expect_equal(design@variables$weights, "wt")
})

test_that("as_survey accepts c() for multi-stage", {
  design <- as_survey(test_data_twostage, ids = c(psu, ssu), weights = wt)
  
  expect_equal(design@variables$ids, c("psu", "ssu"))
})

test_that("as_survey works without ids for SRS", {
  data <- data.frame(x = 1:10, wt = runif(10, 0.5, 2))
  design <- as_survey(data, weights = wt)
  
  expect_null(design@variables$ids)
})

test_that("as_survey_rep supports tidy-select helpers", {
  # Data with repwt1, repwt2, ..., repwt20
  design <- as_survey_rep(
    test_data_repweights,
    weights = wt,
    repweights = starts_with("repwt"),
    type = "JK1"
  )
  
  expect_equal(length(design@variables$repweights), 20)
  expect_true(all(startsWith(design@variables$repweights, "repwt")))
})

test_that("tidy-select errors on non-existent columns", {
  expect_error(
    as_survey(test_data, ids = nonexistent, weights = wt),
    "not found"
  )
})

test_that("probs and weights exclusivity validated", {
  data <- data.frame(
    x = 1:10,
    prob = runif(10, 0.1, 0.3),
    wt = runif(10, 3, 10)
  )
  
  expect_error(
    as_survey(data, probs = prob, weights = wt),
    "Cannot specify both"
  )
})

test_that("probs converted to weights automatically", {
  data <- data.frame(
    x = 1:10,
    prob = rep(0.2, 10)
  )
  
  design <- as_survey(data, probs = prob)
  
  # Weights should be 1/probs = 5
  expect_equal(design@data[[design@variables$weights]], rep(5, 10))
})
```

---

## Documentation Updates

### README.md

Update usage example:

```markdown
## Usage

```r
library(surveycore)

# Create a survey design (tidy-select interface)
my_survey <- as_survey(
  data = my_data,
  ids = cluster_id,      # Bare name
  weights = weight,      # Bare name
  strata = stratum       # Bare name
)

# Multi-stage design
complex_survey <- as_survey(
  data = my_data,
  ids = c(psu, ssu),     # Multiple IDs with c()
  weights = wt,
  strata = region
)

# Replicate weights with tidy-select helper
rep_survey <- as_survey_rep(
  data = my_data,
  weights = wt,
  repweights = starts_with("repwt"),  # Tidy-select helper!
  type = "JK1"
)

# Set metadata
my_survey <- my_survey |>
  set_variable_labels(
    age = "Age in years",
    income = "Annual household income",
    sex = "Biological sex"
  )

# Extract metadata
extract_var_label(my_survey, age)
```
```

---

## CI/CD Updates

[Same as Version 1.0]

---

## Development Workflow

### Implementation Order (UPDATED)

1. **Setup (Day 1)**
   - Create GitHub repository
   - Initialize R package structure
   - Set up CI/CD workflows
   - Create DESCRIPTION with updated dependencies

2. **S7 Classes (Days 2-3)**
   - Implement survey_metadata class
   - Implement survey_base abstract class
   - Implement survey_taylor with updated validator (cli)
   - Implement survey_replicate with matrix storage
   - Implement survey_twophase class
   - Write comprehensive tests

3. **Metadata System (Days 3-5)**
   - Implement extractors (extract_var_label, etc.)
   - Implement singular setters (set_var_label, etc.)
   - Implement plural setters (set_variable_labels, etc.)
   - Implement value label validation (lenient with warning)
   - Implement haven extraction
   - Implement metadata propagation
   - Write comprehensive tests

4. **Validators (Day 5)**
   - Update all validators to use cli
   - Test error and warning conditions
   - Verify error messages are clear and helpful

5. **Constructors (Days 6-9)** [Extended for tidy-select]
   - Implement as_survey() with tidy-select
   - Implement as_survey_rep() with tidy-select
   - Implement as_survey_twophase()
   - Integrate metadata extraction
   - Write comprehensive tests
   - Test tidy-select helpers extensively

6. **Update Function (Day 10)** [NEW]
   - Implement update_design()
   - Test for all design types
   - Verify warnings issued appropriately

7. **Print/Summary Methods (Day 11)**
   - Implement print methods with cli formatting
   - Implement summary methods
   - Test output formatting
   - Test `full` option

8. **Conversion Utilities (Days 12-13)**
   - Implement as_svydesign() for all types
   - Implement from_svydesign() for all types
   - Implement srvyr conversion
   - Test round-trip conversions

9. **Variance Estimation (Days 14-15)**
   - Vendor core variance functions from survey
   - Adapt to S7 classes
   - Write numerical comparison tests
   - Document attribution

10. **Documentation (Days 16-17)**
    - Complete all roxygen2 documentation
    - Update all examples to use tidy-select
    - Emphasize tidy-select in vignettes (Phase 2)
    - Create README with tidy-select examples
    - Ensure pkgdown site builds

11. **Testing & Refinement (Days 17-18)**
    - Achieve 100% test coverage
    - Run R CMD check on all platforms
    - Fix any issues
    - Polish documentation
    - Create NEWS.md entry

---

## Quality Gates

Before considering Phase 0 complete, verify:

- [ ] All S7 classes defined with validators using cli
- [ ] Tidy-select works in all constructors
- [ ] Tidy-select helpers work (starts_with, etc.)
- [ ] All metadata functions implemented (singular + plural)
- [ ] Value label validation is lenient with warning
- [ ] update_design() function works
- [ ] All error messages use cli with clear formatting
- [ ] Print methods support `full` option
- [ ] All exported functions documented with tidy-select examples
- [ ] 100% test coverage (or 98%+ with justification)
- [ ] R CMD check passes on all platforms
- [ ] Round-trip conversions preserve data
- [ ] Variance estimation vendored with attribution
- [ ] README shows tidy-select interface
- [ ] Formal specification followed exactly

---

## References

**Primary Reference:** `surveycore-phase0-formal-specification.md`

**Survey Package:**
- Lumley T (2024). survey: analysis of complex survey samples.
- https://cran.r-project.org/package=survey

**Tidy-Select:**
- https://tidyselect.r-lib.org/

**CLI Package:**
- https://cli.r-lib.org/

---

**END OF IMPLEMENTATION PLAN VERSION 2.0**

This plan supersedes Version 1.0. All implementation must follow both this plan AND the formal specification document.
