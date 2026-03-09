# surveycore Phase 0 - Formal Specification

**Version:** 1.0  
**Date:** February 18, 2025  
**Status:** Approved for Implementation

---

## Document Purpose

This document provides the complete formal specification for Phase 0 of the surveycore package. Every design decision, invariant, and behavior is explicitly defined. This specification is **authoritative** - implementation must follow these rules exactly.

---

## I. Object Model & Invariants

### 1.1 Formal Definition of Valid Survey Objects

A survey object is **valid** if and only if ALL of the following invariants hold:

#### Invariant 1: Data Structure
```
data ∈ data.frame
data ≠ NULL
nrow(data) > 0
all(is.unique(names(data))) = TRUE
```

**Plain English:**
- `data` must be a data.frame (tibbles allowed as they inherit from data.frame)
- `data` cannot be NULL
- `data` must have at least one row
- All column names must be unique
- List-columns are permitted in `data`

#### Invariant 2: Design Variables
```
For all v ∈ design_variables:
  v ∈ names(data)
  is.atomic(data[[v]]) = TRUE
  length(data[[v]]) = nrow(data)
```

**Plain English:**
- All design variables (ids, strata, weights, fpc, repweights) must exist in data
- All design variables must be atomic vectors (no list-columns)
- All design variables must have length equal to number of rows

#### Invariant 3: Weights (survey_taylor and survey_replicate)
```
weights ∈ names(data)
is.numeric(data[[weights]]) = TRUE
all(data[[weights]] > 0 | is.na(data[[weights]])) = TRUE
```

**Plain English:**
- Weight variable must exist in data
- Weights must be numeric
- All non-NA weights must be positive (strictly > 0, no zeros)
- NA weights are permitted

#### Invariant 4: Replicate Weights (survey_replicate only)
```
For all rw ∈ repweights:
  rw ∈ names(data)
  is.numeric(data[[rw]]) = TRUE
```

**Plain English:**
- All replicate weight columns must exist in data
- All replicate weight columns must be numeric
- NA values permitted in replicate weights

#### Invariant 5: Metadata
```
metadata ∈ survey_metadata
all(names(metadata@variable_labels) ⊆ names(data) ∪ {}) = TRUE
```

**Plain English:**
- Metadata must be a survey_metadata object
- Variable labels can only reference variables that exist in data (or be empty)

---

### 1.2 Class Hierarchy

```
survey_base (abstract)
├── properties:
│   ├── data: data.frame
│   ├── metadata: survey_metadata
│   ├── variables: list
│   ├── groups: character  (names of active grouping variables; character(0) = ungrouped)
│   └── call: language | NULL
│
├── survey_taylor
│   └── variables contains:
│       ├── ids: character vector | NULL
│       ├── weights: character (length 1)
│       ├── strata: character (length 1) | NULL
│       ├── fpc: character (length 1) | NULL
│       ├── nest: logical (length 1)
│       └── probs_provided: logical (was probs provided by user?)
│
├── survey_replicate
│   └── variables contains:
│       ├── weights: character (length 1)
│       ├── repweights: character vector (names of rep weight cols)
│       │   # NOTE: repweight_matrix is NOT stored — computed on demand inside
│       │   # variance estimation from data[, repweights]. This avoids sync bugs
│       │   # when data is mutated. Add as cached property only if benchmarking
│       │   # shows a performance need (Phase 3+).
│       ├── type: character (one of: JK1, JK2, JKn, BRR, Fay, bootstrap, etc.)
│       ├── scale: numeric (length 1)
│       ├── rscales: numeric vector | NULL
│       └── ... (other type-specific parameters)
│
└── survey_twophase
    └── variables contains:
        ├── phase1: list (design spec for phase 1)
        ├── phase2: list (design spec for phase 2)
        ├── subset: character (column name for phase 2 indicator)
        └── method: character (one of: full, approx, simple)
```

---

### 1.3 Mutability Model

**Rule: Semi-Mutable with Explicit Updates**

Survey objects follow these mutability rules:

#### Data Mutability
```
✓ ALLOWED: Modifying non-design variables
✓ ALLOWED: Adding new variables
✓ ALLOWED: Modifying design variables WITH WARNING
✗ FORBIDDEN: Removing design variables (automatic preservation)
```

#### Design Mutability
```
✗ FORBIDDEN: Direct modification of @variables slot
✓ ALLOWED: Explicit updates via update_design() function
```

#### Metadata Mutability
```
✓ ALLOWED: Always mutable
```

**Implementation Pattern:**
```r
# Copy-on-modify for all operations
mutate.survey_base <- function(.data, ...) {
  new_data <- .data
  # Modify new_data
  # Validate invariants
  # Return new_data
}
```

---

## II. API Specification

### 2.1 Constructor Functions

#### as_survey()

**Signature:**
```r
as_survey(
  data,
  ids = NULL,
  probs = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE
)
```

**Argument Specification:**

| Argument | Type | Required | Tidy-Select | Description |
|----------|------|----------|-------------|-------------|
| `data` | data.frame | Yes | No | Survey data |
| `ids` | bare names | No* | Yes | Cluster IDs. Single: `ids = psu`. Multi: `ids = c(psu, ssu)`. Omit for SRS. |
| `probs` | bare name | No | Yes | Sampling probabilities. Converted to weights = 1/probs. |
| `weights` | bare name | No | Yes | Sampling weights. |
| `strata` | bare name | No | Yes | Stratification variable. |
| `fpc` | bare name | No | Yes | Finite population correction. |
| `nest` | logical | No | No | Are cluster IDs nested within strata? |

\* Either `ids`, `probs`, or `weights` must be provided (or omit all for SRS).

**Validation Rules:**

1. **Probs/Weights Exclusivity:**
   ```r
   if (!is.null(probs) && !is.null(weights)) {
     # Check consistency: abs(weights - 1/probs) < tolerance
     # If inconsistent, ERROR with cli::cli_abort()
   }
   ```

2. **Weight Conversion:**
   ```r
   if (!is.null(probs) && is.null(weights)) {
     weights <- 1/probs
     variables$probs_provided <- TRUE
   }
   ```

3. **Simple Random Sample:**
   ```r
   if (is.null(ids) && is.null(weights) && is.null(probs)) {
     # Create uniform weights and warn about limitations
     data[["..surveycore_wt.."]] <- rep(1L, nrow(data))
     weights_var <- "..surveycore_wt.."
     variables$probs_provided <- FALSE

     cli::cli_warn(c(
       "!" = "No weights or population size provided.",
       "i" = "Treating as equal-probability SRS with unknown population size.",
       "v" = "Valid: means, proportions, correlations, and their standard errors.",
       "x" = "Invalid: population totals (will equal sample totals, not population totals).",
       "i" = "To fix: provide {.arg fpc} = population size, or {.arg weights} = N / n."
     ))
   }
   ```

**Tidy-Select Evaluation:**
```r
# Capture expressions
ids_expr <- rlang::enquo(ids)
weights_expr <- rlang::enquo(weights)

# Evaluate to column names
if (!rlang::quo_is_null(ids_expr)) {
  ids_cols <- tidyselect::eval_select(ids_expr, data)
  variables$ids <- names(ids_cols)
}

# Support tidy-select helpers
repweights = starts_with("repwt")  # This works!
```

**Return Value:**
- Object of class `survey_taylor`
- All invariants satisfied
- Metadata extracted from haven if present

---

#### as_survey_repweights()

**Signature:**
```r
as_survey_repweights(
  data,
  weights,
  repweights,
  type = c("JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", 
           "ACS", "successive-difference", "other"),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE
)
```

**Repweights Storage:**
```r
# Store column names only — NOT the matrix.
# The matrix is computed on demand inside variance estimation functions:
#   as.matrix(design@data[, design@variables$repweights, drop = FALSE])
# This is the single source of truth and avoids sync bugs when data changes.
variables$repweights <- names(tidyselect::eval_select(repweights_expr, data))
```

**Return Value:**
- Object of class `survey_replicate`

---

#### as_survey_twophase()

**Signature:**
```r
as_survey_twophase(
  phase1,
  ids2    = NULL,
  strata2 = NULL,
  probs2  = NULL,
  fpc2    = NULL,
  subset,
  method  = c("full", "approx", "simple")
)
```

**Design:**
- `phase1` — an existing `survey_taylor` object. Its `@data` is the shared data frame
  containing ALL rows from both phases. Phase 1 design variables are already embedded.
- `ids2`, `strata2`, `probs2`, `fpc2` — tidy-select, evaluated against `phase1@data`.
  These specify the phase 2 design elements (cluster IDs, strata, etc.).
- `subset` — tidy-select (single logical column in `phase1@data`).
  `TRUE` = row was selected into phase 2; `FALSE` = phase 1 only.
- No list-of-formulas or list-of-bare-names syntax needed.

**Rationale:**
Both `survey::twophase()` and `srvyr::as_survey_twophase()` require a single data
frame containing all phase 1 rows, with a logical subset indicator for phase 2.
Passing two separate survey objects would lose the phase 1 context required for
variance estimation. This hybrid approach takes a validated phase 1 survey object
(familiar to users) and adds the phase 2 spec via the same tidy-select interface.

**Validation Rules:**

1. **Degenerate subset (ERROR):**
   ```r
   subset_vals <- phase1@data[[subset_var]]
   if (all(subset_vals) || !any(subset_vals)) {
     cli::cli_abort(c(
       "x" = "{.arg subset} column {.field {subset_var}} must contain both TRUE and FALSE values.",
       "i" = "Found {sum(subset_vals)} TRUE out of {length(subset_vals)} rows.",
       "i" = "For two-phase designs, Phase 2 must be a strict subset of Phase 1."
     ))
   }
   ```

2. **`method = "simple"` with clustered Phase 1 (WARNING):**
   ```r
   if (method == "simple" && !is.null(phase1@variables$ids)) {
     cli::cli_warn(c(
       "!" = "{.code method = \"simple\"} ignores the Phase 1 cluster design.",
       "i" = "Phase 1 has PSU variable(s): {.field {phase1@variables$ids}}.",
       "i" = "This understates variance for clustered Phase 1 designs.",
       "i" = "Use {.code method = \"full\"} or {.code method = \"approx\"} unless Phase 1 is truly unclustered."
     ))
   }
   ```

3. **`method = "full"` with no Phase 2 design information (WARNING):**
   ```r
   no_phase2_info <- is.null(ids2_var) && is.null(strata2_var) &&
                     is.null(probs2_var) && is.null(fpc2_var)
   if (method == "full" && no_phase2_info) {
     cli::cli_warn(c(
       "!" = "No Phase 2 design information provided with {.code method = \"full\"}.",
       "i" = "Phase 2 selection will be treated as simple random subsampling within Phase 1 strata.",
       "i" = "If Phase 2 inclusion probabilities are available, provide them via {.arg probs2}.",
       "i" = "Example: {.code probs2 = subsamprate} if your data has a subsampling rate column."
     ))
   }
   ```

4. **Phase 2 design columns all-NA within Phase 2 subset (WARNING — in S7 validator):**

   This check belongs in the `survey_twophase` S7 validator, not the constructor, because
   it requires inspecting actual data values rather than column names.

   ```r
   # In survey_twophase validator:
   phase2_rows <- self@data[[self@variables$subset]]
   for (var in c(self@variables$phase2$ids,
                 self@variables$phase2$strata,
                 self@variables$phase2$probs,
                 self@variables$phase2$fpc)) {
     if (!is.null(var) && all(is.na(self@data[[var]][phase2_rows]))) {
       cli::cli_warn(c(
         "!" = "Phase 2 design variable {.field {var}} is all NA within the Phase 2 subset.",
         "i" = "Check that {.field {var}} is populated for rows where {.field {self@variables$subset}} is TRUE."
       ))
     }
   }
   ```

**Return Value:**
- Object of class `survey_twophase`

**Example:**
```r
# Phase 1: full cohort
phase1 <- as_survey(pbc_data, ids = id, weights = phase1_wt)

# Two-phase design: phase 2 = randomized patients
d2 <- as_survey_twophase(
  phase1,
  subset  = randomized       # logical column in pbc_data
)

# With phase 2 stratification
d2_strat <- as_survey_twophase(
  phase1,
  strata2 = treatment_arm,  # phase 2 strata (column in phase1@data)
  subset  = in_phase2,
  method  = "full"
)

# GSS example: subsamprate column holds Phase 2 inclusion probabilities
phase1_gss <- as_survey(gss, ids = vpsu, strata = vstrat, weights = wtssnrps)
gss_twophase <- as_survey_twophase(
  phase1_gss,
  probs2 = subsamprate,     # Phase 2 inclusion probability (0.4 or 1.0)
  subset = in_phase2_module, # logical: TRUE if row answered the subsampled module
  method = "full"
)
```

---

### 2.2 Metadata Functions

#### Extract Functions

**Signatures:**
```r
extract_var_label(x, var)
extract_val_labels(x, var)
extract_question_preface(x, var)
extract_var_note(x, var)
```

**Behavior:**
- Returns metadata value if exists
- Returns `NULL` if not exists
- Never errors on non-existent variable (returns NULL)

---

#### Set Functions (Outside mutate)

**Single Variable:**
```r
set_var_label(x, var, label)
set_val_labels(x, var, labels)
set_question_preface(x, var, preface)
set_var_note(x, var, note)
```

**Behavior:**
- Takes bare name for `var` (tidy-eval)
- Returns modified survey object
- Errors if variable doesn't exist in data
- Validates value labels are named vector

**Multiple Variables:**
```r
set_variable_labels(x, ...)
set_value_labels(x, ...)
set_question_prefaces(x, ...)
set_variable_notes(x, ...)
```

**Syntax:**
```r
# Named arguments
survey_obj <- set_variable_labels(
  survey_obj,
  age = "Age in years",
  income = "Annual income",
  sex = "Biological sex"
)

# Programmatic via list
label_list <- list(age = "Age in years", income = "Annual income")
survey_obj <- set_variable_labels(survey_obj, !!!label_list)
```

**Unified Setter:**
```r
set_metadata(x, var, var_label = NULL, val_labels = NULL, 
             question_preface = NULL, note = NULL)
```

---

#### Set Functions (Inside mutate - Phase 0.5)

**Attribute Transport Mechanism:**

```r
# Phase 0: These functions attach attributes
set_var_label <- function(x, label) {
  if (!in_survey_context()) {
    cli::cli_abort(c(
      "x" = "{.fn set_var_label} can only be used on survey objects",
      "i" = "Use {.fn set_var_label(survey_obj, var, label)} outside {.fn mutate}",
      "i" = "Or use direct assignment: {.code survey_obj@metadata@variable_labels$var <- label}"
    ))
  }
  attr(x, "surveycore_pending_var_label") <- label
  x
}

# Phase 0.5: mutate.survey_base() extracts attributes
```

---

#### Value Label Validation

**Rule: Lenient with Warning**

```r
validate_val_labels <- function(var, labels) {
  unique_vals <- unique(var[!is.na(var)])
  label_vals <- names(labels)
  
  # Check for extra labels (allowed, no warning)
  extra <- setdiff(label_vals, as.character(unique_vals))
  # OK - allows documentation of full coding scheme
  
  # Check for missing labels (allowed, but warn)
  missing <- setdiff(as.character(unique_vals), label_vals)
  if (length(missing) > 0) {
    cli::cli_warn(c(
      "!" = "Not all values are labeled",
      "i" = "Unlabeled values: {.val {missing}}"
    ))
  }
}
```

---

### 2.3 Update Function

```r
update_design(
  x,
  weights = NULL,
  ids = NULL,
  strata = NULL,
  fpc = NULL,
  validate = TRUE
)
```

**Behavior:**
- Updates design variables on the object
- When `validate = TRUE` (default): re-runs ALL invariant checks from Section I on the updated object
- For `survey_replicate`: updates `repweights` column name list only — no matrix to rebuild
  (matrix is always computed on demand from `data[, repweights]` inside variance estimation)
- Issues `cli_inform()` noting which design variables were changed
- Use case: After modifying data, need to update design

**Example:**
```r
# Modified data externally
survey_obj@data$new_weights <- calculate_new_weights()

# Update design
survey_obj <- update_design(survey_obj, weights = new_weights)
```

---

### 2.4 Conversion Functions

#### To survey package

```r
as_svydesign(x)
```

**Behavior:**
- Converts survey_taylor → survey::svydesign()
- Converts survey_replicate → survey::svrepdesign()
- Converts survey_twophase → survey::twophase()
- Errors if survey package not installed

---

#### From survey package

```r
from_svydesign(x)
```

**Behavior:**
- Accepts svydesign, svyrep.design, twophase objects
- Extracts design components
- Preserves data exactly
- Does NOT extract metadata (survey package doesn't have metadata system)

---

#### To/From srvyr

```r
as_tbl_svy(x)
from_tbl_svy(x)
```

**Behavior:**
- Wraps survey package conversion
- May require both survey and srvyr installed

---

## III. Behavior Contracts

### 3.1 dplyr Verb Behavior (Phase 0.5 Preview)

These contracts define how surveytidy (Phase 0.5) will implement verbs:

#### select()

**Contract:**
```
Design variables are AUTOMATICALLY PRESERVED even if not selected.

If user explicitly selects design variables:
  Include them in output (visible)
Else:
  Preserve them internally (not visible in print, but present in data)
```

**Implementation:**
```r
select.survey_base <- function(.data, ...) {
  # Evaluate selection
  selected <- tidyselect::eval_select(rlang::expr(c(...)), .data@data)
  
  # Get design variable names
  design_vars <- get_design_vars(.data)
  
  # Preserve design vars
  all_vars <- union(names(selected), design_vars)
  
  # Update data
  .data@data <- .data@data[, all_vars]

  # Track which columns are user-visible (for print suppression of design vars)
  # Store in @variables, not via attr() — attr() is not idiomatic for S7 objects
  .data@variables$visible_vars <- names(selected)

  .data
}
```

---

#### mutate()

**Contract for Weight Modification:**
```
If user modifies weight column:
  ALLOW with WARNING
  
Warning message:
  "Modifying weight variable '{var}' may invalidate survey design.
   Consider using update_design() if this is intentional."
```

**Implementation:**
```r
mutate.survey_base <- function(.data, ...) {
  # Set context for set_var_label() etc
  set_survey_context(TRUE)
  on.exit(set_survey_context(FALSE))
  
  # Check if weight column is being modified
  weight_var <- .data@variables$weights
  exprs <- rlang::enquos(...)
  
  if (weight_var %in% names(exprs)) {
    cli::cli_warn(c(
      "!" = "Modifying weight variable {.field {weight_var}}",
      "i" = "This may invalidate the survey design",
      "i" = "Use {.fn update_design} to explicitly update weights"
    ))
  }
  
  # Evaluate mutations
  # Extract metadata attributes
  # Update data
  # Return modified object
}
```

---

#### rename()

**Contract for Design Variables:**
```
If user renames a design variable:
  ALLOW + AUTO-UPDATE @variables to reflect new column name
  Issue cli_inform() confirming the update (not a warning — this is valid)
```

Renaming is a legitimate operation. Erroring would be unnecessarily restrictive.
The design specification is automatically kept in sync with column names.

**Implementation:**
```r
S7::method(rename, survey_base) <- function(.data, ...) {
  renames <- tidyselect::eval_rename(rlang::expr(c(...)), .data@data)
  # renames is a named integer vector: new_name -> position

  # Build old_name -> new_name lookup
  rename_map <- setNames(names(.data@data)[renames], names(renames))

  # Detect if any design variables are being renamed
  design_vars <- .get_design_vars(.data)  # returns named list: slot -> col_name(s)
  renamed_design <- intersect(unlist(design_vars), names(rename_map))

  if (length(renamed_design) > 0) {
    new_names <- rename_map[renamed_design]
    cli::cli_inform(c(
      "i" = "Design variable{?s} renamed and design specification updated:",
      " " = "{.field {renamed_design}} -> {.field {new_names}}"
    ))

    # Update @variables to use new column names
    .data <- .update_design_var_names(.data, rename_map)
  }

  # Perform the actual column rename
  names(.data@data)[renames] <- names(renames)

  # Update metadata keys to match renamed columns
  .data@metadata <- .rename_metadata_keys(.data@metadata, rename_map)

  .data
}
```

---

#### filter() and filter_out()

**Contract: Domain Estimation**

```
Both filter() and filter_out() use DOMAIN ESTIMATION:
  - Keep all rows in data
  - Mark domain membership
  - Estimation functions respect domain
  
filter():     domain = (condition is TRUE), ANDed with any existing domain
filter_out(): domain = (condition is FALSE), ANDed with any existing domain

Neither function physically removes rows. Chained calls compose as AND:
  filter(A) |> filter(B)  →  domain = A & B
  filter(A) |> filter_out(B)  →  domain = A & !B
```

**Implementation:**
```r
S7::method(filter, survey_base) <- function(.data, ..., .preserve = FALSE) {
  # Evaluate new filter condition against the data
  new_cond <- rlang::eval_tidy(
    rlang::expr(...),
    data = .data@data
  )

  if (!is.logical(new_cond) || length(new_cond) != nrow(.data@data)) {
    cli::cli_abort("filter() condition must evaluate to a logical vector of length {nrow(.data@data)}.")
  }

  domain_col <- "..surveycore_domain.."

  if (!is.null(.data@variables$domain)) {
    # AND with existing domain (chained filter() calls compose as AND)
    .data@data[[domain_col]] <- .data@data[[domain_col]] & new_cond
  } else {
    # First filter() call — create the domain column
    .data@data[[domain_col]] <- new_cond
    .data@variables$domain <- domain_col
  }

  # Physical rows are NOT removed; all data is kept.
  # Analysis functions check @variables$domain to restrict estimation.
  .data
}
```

**Chaining behavior (AND logic):**
```r
svy |>
  filter(sex == "Women") |>    # domain = sex == "Women"
  filter(age < 50)             # domain = sex == "Women" & age < 50

# Equivalent to:
svy |> filter(sex == "Women" & age < 50)
```

**Domain column name:** Always `"..surveycore_domain.."`. Using a fixed name (rather
than a unique generated name) allows chained filters to update the same column.
Users should not create columns with this name in their data.

---

#### subset()

**Contract: Physical Subsetting**

```
subset() performs PHYSICAL SUBSETTING:
  - Removes rows from data
  - Updates design accordingly
  - Issues BIG WARNING about variance implications
  
This is dangerous but sometimes necessary.
Use filter() for subpopulation analysis instead.
```

**Implementation:**
```r
subset.survey_base <- function(x, subset, ...) {
  cli::cli_warn(c(
    "!" = "{.fn subset} performs physical subsetting",
    "!" = "This gives INCORRECT variance estimates for subpopulations",
    "i" = "Use {.fn filter} for subpopulation analysis instead",
    "i" = "See {.url https://notstatschat.rbind.io/2021/07/22/subsets-and-subpopulations-in-survey-inference}"
  ))
  
  # Evaluate subset condition
  # Physically remove rows
  # Return modified object
}
```

---

### 3.2 Metadata Lifecycle

**Rules:**

1. **Variable Deletion:** Metadata auto-deletes
   ```r
   survey_obj <- survey_obj |> select(-age)
   # Metadata for 'age' is automatically removed
   ```

2. **Variable Rename:** Metadata auto-renames
   ```r
   survey_obj <- survey_obj |> rename(age_years = age)
   # Metadata moves from 'age' to 'age_years'
   ```

3. **Variable Mutation:** Metadata copies (simple rules in Phase 0)
   ```r
   # Phase 0: Basic copying if single source
   survey_obj <- survey_obj |> mutate(age_decades = age / 10)
   # Metadata copies: "Age" → "Age in decades"
   
   # Phase 0.5: Smart detection of transformations
   ```

4. **Transformation Tracking:** Always track
   ```r
   # metadata@transformations$new_var records:
   # - Source variable(s)
   # - Transformation expression
   # - Timestamp
   ```

---

## IV. Variance Estimation (Phase 0 Scope)

### 4.1 Vendored Code Requirements

**Source:** survey package by Thomas Lumley (GPL-2/GPL-3)

**License Compliance:**
```r
# In DESCRIPTION
License: GPL-3

# In each file with vendored code
# This file contains code adapted from the survey package
# by Thomas Lumley (https://cran.r-project.org/package=survey)
# licensed under GPL-2 | GPL-3.
#
# Modifications have been made to integrate with S7 classes while
# maintaining numerical equivalence with the original implementation.
```

**Attribution:**
```r
# In package documentation and README
## Attribution
The variance estimation code in surveycore is adapted from the survey 
package by Thomas Lumley, with modifications to integrate with the S7 
object system. We are grateful for Thomas Lumley's pioneering work in 
survey statistics in R.
```

**Functions to Vendor:**
- Taylor series variance for totals
- Taylor series variance for means
- Replicate variance estimation
- Variance combination for domains
- Core linearization functions

**Testing Requirement:**
```
For all vendored functions:
  surveycore_result ≈ survey_result within tolerance = 1e-10
```

---

## V. Error Philosophy & Messaging

### 5.1 Error Categories

#### ERRORS (fail fast)
- Invalid design construction
- Missing required design variables
- Negative or zero weights
- Removing design variables (design vars are auto-preserved; explicit drop is forbidden)
- Specifying both probs and weights (inconsistent values)
- Setting metadata for non-existent variables
- Type mismatches
- Degenerate `subset` in `as_survey_twophase()` (all TRUE or all FALSE)

#### WARNINGS
- Modifying weight column in mutate()
- Physical subsetting with subset()
- Missing value labels for some values
- Unusual design patterns (single PSU strata)
- Missing metadata when expected
- SRS created without weights or population size (totals will be wrong)
- `method = "simple"` in `as_survey_twophase()` when Phase 1 has PSUs (understates variance)
- `method = "full"` in `as_survey_twophase()` when no Phase 2 design info provided (probs2, strata2, ids2, fpc2 all NULL)
- Phase 2 design variable is all-NA within Phase 2 subset rows (in S7 validator)

#### INFORMS (informational messages, not warnings)
- Design variable renamed and @variables automatically updated
- Automatic corrections applied (e.g., probs converted to weights)

#### MESSAGES
- Informational only
- Automatic corrections
- Default behavior applied

---

### 5.2 Error Message Format

**Use cli package for all errors/warnings:**

```r
# Good error
cli::cli_abort(c(
  "x" = "Weight variable {.field {var}} not found in data",
  "i" = "Available variables: {.field {names(data)}}",
  "i" = "Did you mean {.field {suggest_variable(var, names(data))}}?"
))

# Good warning
cli::cli_warn(c(
  "!" = "Modifying weight variable {.field wt}",
  "i" = "This may invalidate the survey design"
))

# Avoid overly long errors
# Maximum ~5 lines
```

**Principles:**
1. **Be specific** - What went wrong?
2. **Suggest fix** - How to fix it?
3. **Be concise** - No walls of text
4. **Use formatting** - {.field}, {.fn}, {.code}
5. **LLM-friendly** - Clear, parseable error structure

---

## VI. Testing Requirements

### 6.1 Coverage Target

**100% Code Coverage**

Exceptions (only if truly impossible to test):
- Unreachable defensive code
- Platform-specific code on unavailable platforms

**Measurement:**
```r
covr::package_coverage()
# Target: 100%
# Minimum acceptable: 98%
```

---

### 6.2 Test Categories

#### Unit Tests
- Each function in isolation
- Mock dependencies
- Edge cases
- Error conditions
- Boundary values

#### Integration Tests
- Workflows across multiple functions
- Constructor → validator → methods
- Metadata propagation through operations
- Round-trip conversions

#### Validation Tests
- Numerical comparison with survey package
- Tolerance: 1e-10 for point estimates
- Tolerance: 1e-8 for variance estimates

#### Property Tests (if time permits)
- Invariants hold after operations
- Metadata lifecycle correctness

---

### 6.3 Test Data

Create in `tests/testthat/helper-test-data.R`:

```r
# Simple random sample
test_data_srs <- data.frame(...)

# Stratified sample
test_data_strat <- data.frame(...)

# Cluster sample  
test_data_cluster <- data.frame(...)

# Two-stage cluster
test_data_twostage <- data.frame(...)

# With haven labels
test_data_labeled <- haven::labelled(...)

# With replicate weights
test_data_repweights <- data.frame(...)

# Edge cases
test_data_single_psu <- data.frame(...)
test_data_with_nas <- data.frame(...)
```

---

## VII. Dependencies

### 7.1 Required Dependencies

```r
Imports:
  S7 (>= 0.1.0),
  rlang (>= 1.0.0),
  tidyselect (>= 1.2.0),
  cli (>= 3.6.0),
  stats,
  methods

Suggests:
  testthat (>= 3.0.0),
  survey (>= 4.0),
  srvyr (>= 1.0),
  haven (>= 2.5.0),
  covr,
  knitr,
  rmarkdown
```

**Rationale:**
- `S7`: Core object system
- `rlang`: Tidy evaluation
- `tidyselect`: Column selection
- `cli`: Error messages
- `stats`, `methods`: Base R functionality
- `survey`, `srvyr`: Testing and conversion only
- `haven`: In Suggests only — surveycore does NOT import haven at runtime

---

### 7.2 Haven Metadata Extraction

**Design Rule:** `haven` is in `Suggests`, never in `Imports`. surveycore must not call any `haven::` function at runtime. Instead, inspect column attributes directly using base R `attr()`.

**Contract for `extract_haven_metadata(data)`:**

```r
extract_haven_metadata <- function(data) {
  labels <- list()
  val_lab <- list()

  for (col_name in names(data)) {
    col <- data[[col_name]]

    # haven stores variable labels as attr(x, "label") (length-1 character)
    var_lbl <- attr(col, "label", exact = TRUE)
    if (!is.null(var_lbl) && nzchar(var_lbl)) {
      labels[[col_name]] <- as.character(var_lbl)
    }

    # haven stores value labels as attr(x, "labels") (named numeric/character)
    val_labels <- attr(col, "labels", exact = TRUE)
    if (!is.null(val_labels) && length(val_labels) > 0) {
      val_lab[[col_name]] <- val_labels
    }
  }

  survey_metadata(
    variable_labels = labels,
    value_labels    = val_lab
  )
}
```

**Why `attr()` not `haven::`:**
- Avoids mandatory haven install for all surveycore users
- The `"label"` and `"labels"` attributes are plain R attributes — any package or user can set them
- haven is only needed in tests that create `haven::labelled()` vectors

**Behaviour:**
- Returns a `survey_metadata` object (empty metadata if no haven attributes found)
- Called automatically in `as_survey()`, `as_survey_repweights()`, `as_survey_twophase()`
- No warning if no haven attributes present (silent no-op)

**Edge Cases (all must be handled explicitly in implementation):**

1. **`label = character(0)` (zero-length string vector):**
   Treat as `NULL` — do not store in `variable_labels`.
   ```r
   if (!is.null(var_lbl) && length(var_lbl) > 0 && nzchar(var_lbl)) { ... }
   # NOT: if (!is.null(var_lbl) && nzchar(var_lbl))  ← crashes on character(0)
   ```

2. **`labels` attribute with `NA` as a key:**
   Preserve as-is. R allows `NA` as a vector name (`c(NA = 1L, "Yes" = 2L)`).
   haven uses `NA`-keyed entries to represent user-defined missing values.
   Do NOT drop entries with `NA` names during extraction.
   ```r
   # Correct: just store val_lbl as-is
   val_lab[[col_name]] <- val_lbl  # NA-keyed entries preserved
   ```

3. **`haven_labelled_spss` with `na_values` / `na_range` attributes:**
   SPSS files read by haven may have additional attributes `na_values` (a
   numeric/character vector of declared missing codes) and `na_range` (a
   length-2 numeric vector giving a range of missing codes). Extract and store
   these under a new `missing_values` key in `@metadata`:
   ```r
   na_vals  <- attr(col, "na_values", exact = TRUE)
   na_range <- attr(col, "na_range",  exact = TRUE)
   if (!is.null(na_vals) || !is.null(na_range)) {
     metadata@missing_values[[col_name]] <- list(
       na_values = na_vals,
       na_range  = na_range
     )
   }
   ```
   **Note:** This requires adding a `missing_values` property to `survey_metadata`
   (type `class_list`, default `list()`). Add this in `00-s7-classes.R`.

4. **`labels` attribute present but empty (`named integer(0)`):**
   Treat as no labels — do not store in `value_labels`.
   The guard `length(val_lbl) > 0` in the reference implementation already
   handles this, but it must be tested explicitly.
   ```r
   # named integer(0) → length = 0 → condition fails → not stored. Correct.
   if (!is.null(val_lbl) && length(val_lbl) > 0) { ... }
   ```

---

### 7.3 Namespace Management

**Selective imports:**
```r
# NAMESPACE
importFrom(rlang, enquo, enquos, quo_is_null, eval_tidy, expr)
importFrom(tidyselect, eval_select)
importFrom(cli, cli_abort, cli_warn, cli_inform)
importFrom(S7, new_class, new_property, class_list, ...)
```

**No wholesale imports:**
```r
# AVOID
import(dplyr)
import(tidyverse)
```

---

## VIII. Output Formatting

### 8.1 print() for survey objects

> **S7 Method Syntax:** Print methods must be registered via `S7::method()`,
> NOT as S3 methods (`print.survey_taylor <- ...`). S3 syntax is silently ignored
> for S7 objects. Use:
> ```r
> S7::method(print, survey_taylor) <- function(x, n = 10, ...) { ... }
> S7::method(print, survey_replicate) <- function(x, n = 10, ...) { ... }
> S7::method(print, survey_twophase) <- function(x, n = 10, ...) { ... }
> ```
> The same applies to `summary` methods:
> ```r
> S7::method(summary, survey_taylor) <- function(object, ...) { ... }
> ```

**Effective signature (parameters are the same for all design types):**
```r
# S7::method(print, survey_taylor) <- function(
#   x,
#   n            = 10,
#   design_info  = FALSE,
#   weights_info = FALSE,
#   strata_info  = FALSE,
#   cluster_info = FALSE,
#   metadata_info = FALSE,
#   full         = FALSE,
#   ...
# )
```

**Default Output:**
```
Survey Design (survey_taylor)
Sample size: 1,000

# A tibble: 1,000 × 5
   age income sex   education region
 <dbl>  <dbl> <chr>     <dbl> <chr> 
1    45  50000 M             3 North
2    32  45000 F             2 South
... with 990 more rows
```

**Full Output (full = TRUE):**
```
Survey Design (survey_taylor)
Sample size: 1,000
Weighted N: 5,000,000

Design specification:
• IDs: psu
• Strata: region (4 strata)
• Weights: wt (range: 0.5 - 2.3, mean: 1.0)
• Weights provided as: sampling weights        # or "sampling probabilities (converted)"
• FPC: Not specified
• Nesting: FALSE

Design variables:
• psu, region, wt

Metadata: 3 variables labeled

# A tibble: 1,000 × 8
    psu region     wt   age income sex   education other_var
  <dbl> <chr>   <dbl> <dbl>  <dbl> <chr>     <dbl> <dbl>    
... with 990 more rows
```

**Design Variables in Print:**
- If user selected design vars: Show them
- If user didn't select design vars: Hide from print (but present in data)
- Indicate hidden design vars in output

**probs_provided in Full Output (`survey_taylor` only):**
- `variables$probs_provided == TRUE` → `• Weights provided as: sampling probabilities (converted)`
- `variables$probs_provided == FALSE` and user supplied `weights` → `• Weights provided as: sampling weights`
- SRS auto-weights (`..surveycore_wt..`): omit the "Weights provided as:" line entirely

---

### 8.2 summary.survey_base()

**Returns structured summary object:**
```r
summary(survey_obj)

Survey Design Summary
Type: Taylor series linearization
Sample size: 1,000
Weighted N: 5,000,000

Design:
  IDs: psu (30 PSUs)
  Strata: region (4 strata)
  Weights: wt
    • Range: 0.5 - 2.3
    • Mean: 1.0
    • Coefficient of variation: 0.15
  
Effective sample size: 850
Average design effect: 1.18

Metadata: 3 of 5 variables labeled
```

---

## IX. Estimation Functions (Phase 1 Preview)

### 9.1 Return Structure

**S3 Class Built on Tibble:**

```r
# Define constructor
new_survey_estimate <- function(data, type = c("mean", "total", "freq", "ratio")) {
  type <- match.arg(type)
  
  structure(
    tibble::as_tibble(data),
    class = c(paste0("survey_", type), "survey_estimate", "tbl_df", "tbl", "data.frame"),
    estimate_type = type,
    survey_design = attr(data, "survey_design"),  # Reference to original design
    timestamp = Sys.time()
  )
}

# Example output structure
get_means(survey_obj, income)
# Returns:
# A tibble: 1 × 8
#   variable  mean    se ci_lower ci_upper    df    cv     n  n_eff
#   <chr>    <dbl> <dbl>    <dbl>    <dbl> <dbl> <dbl> <int>  <dbl>
# 1 income  50000  1500    47000    53000    45  0.03  1000    850
# 
# # With class: survey_mean, survey_estimate, tbl_df, tbl, data.frame
```

**Columns (standardized across estimate types):**
- `variable`: Variable name (character)
- `estimate`: Point estimate (varies by type: mean, total, proportion, etc.)
- `se`: Standard error (numeric)
- `ci_lower`: Lower confidence bound (numeric)
- `ci_upper`: Upper confidence bound (numeric)
- `df`: Degrees of freedom (numeric)
- `cv`: Coefficient of variation (numeric)
- `n`: Unweighted sample size (integer)
- `n_eff`: Effective sample size (numeric)

**Additional columns for specific estimate types:**
- Frequencies: `count`, `proportion`
- Quantiles: `quantile`, `value`
- Ratios: `numerator`, `denominator`

---

### 9.2 Methods for Estimate Objects

```r
# Print method
print.survey_estimate <- function(x, ...) {
  cat(cli::style_bold("Survey Estimate"), "\n")
  cat("Type:", attr(x, "estimate_type"), "\n\n")
  NextMethod()
}

# Plot method (Phase 2+)
plot.survey_estimate <- function(x, ...) {
  # Create appropriate visualization
}

# dplyr methods (preserve class)
mutate.survey_estimate <- function(.data, ...) {
  result <- NextMethod()
  class(result) <- class(.data)
  attributes(result) <- attributes(.data)
  result
}
```

---

### 9.3 Grouped Estimation

**Contract: Respect Grouping**

```r
survey_obj |>
  group_by(region) |>
  get_means(income)

# Returns:
# A tibble: 4 × 9
# Groups: region [4]
#   region variable  mean    se ci_lower ci_upper    df    cv     n  n_eff
#   <chr>  <chr>    <dbl> <dbl>    <dbl>    <dbl> <dbl> <dbl> <int>  <dbl>
# 1 North  income  52000  2000    48000    56000    12  0.04   250    210
# 2 South  income  48000  1800    44400    51600    13  0.04   250    215
# 3 East   income  51000  2100    46800    55200    11  0.04   250    205
# 4 West   income  49000  1900    45200    52800    14  0.04   250    220
```

---

## X. Phase 0 Exit Criteria

### 10.1 Completion Checklist

Phase 0 is **COMPLETE** when ALL of the following are TRUE:

- [ ] All S7 classes defined (survey_metadata, survey_base, survey_taylor, survey_replicate, survey_twophase)
- [ ] All S7 validators implemented and tested
- [ ] Constructor functions work for all design types (as_survey, as_survey_repweights, as_survey_twophase)
- [ ] Tidy-select fully implemented in constructors
- [ ] Metadata system fully implemented (extract_*, set_*, set_*_labels())
- [ ] Metadata extraction from haven works
- [ ] Print methods implemented for all types
- [ ] Summary methods implemented for all types
- [ ] Conversion to survey package works (as_svydesign)
- [ ] Conversion from survey package works (from_svydesign)
- [ ] Conversion to/from srvyr works (as_tbl_svy, from_tbl_svy)
- [ ] Round-trip conversions preserve data exactly
- [ ] Variance estimation code vendored with proper attribution
- [ ] update_design() function implemented
- [ ] All validators use cli for error messages
- [ ] 100% test coverage achieved (or 98%+ with justified exceptions)
- [ ] All tests pass on all platforms (Windows, Mac, Linux)
- [ ] R CMD check passes with 0 errors, 0 warnings, 0 notes
- [ ] All exported functions have complete roxygen2 documentation
- [ ] All functions have working examples in documentation
- [ ] README.md complete with installation and basic usage
- [ ] NEWS.md documents Phase 0 features
- [ ] CI/CD workflows operational (R-CMD-check, test-coverage)
- [ ] pkgdown site builds successfully

---

### 10.2 Explicitly NOT in Phase 0

The following are **EXPLICITLY EXCLUDED** from Phase 0 scope:

- ❌ Any dplyr verb implementations (mutate, filter, select, etc.)
- ❌ Any estimation functions (get_means, get_totals, get_freqs, etc.)
- ❌ Any regression functions (survey_glm, etc.)
- ❌ Crosstabs (get_crosstab, svychisq)
- ❌ Domain estimation implementation (design only)
- ❌ Performance optimization
- ❌ Vignettes (defer to Phase 2)
- ❌ Advanced metadata features (smart transformation detection)
- ❌ Grouped survey objects (infrastructure only, no group_by implementation)
- ❌ Comparison functions (compare_surveys, etc.)

These are reserved for future phases.

---

## XI. survey_glm Structure (Phase 2 Preview)

### 11.1 Class Definition

```r
survey_glm_fit <- S7::new_class(
  "survey_glm_fit",
  properties = list(
    # Key components as properties
    coefficients = S7::class_numeric,
    vcov = S7::class_matrix,
    residuals = S7::class_numeric,
    fitted_values = S7::class_numeric,
    
    # Model specification
    family = S7::class_family,
    formula = S7::class_formula,
    
    # Survey design reference
    survey_design = survey_base,
    
    # Everything else in details list
    details = S7::class_list  # Contains: aic, deviance, qr, df.residual, etc.
  )
)
```

### 11.2 S3 Compatibility

```r
# Provide S3 methods for compatibility
# Note: survey_glm() is the constructor function; survey_glm_fit is the S7 class.
# S3 methods use the class name (survey_glm_fit), not the function name.
S7::method(coef, survey_glm_fit) <- function(object, ...) object@coefficients
S7::method(vcov, survey_glm_fit) <- function(object, ...) object@vcov
S7::method(residuals, survey_glm_fit) <- function(object, ...) object@residuals
S7::method(fitted, survey_glm_fit) <- function(object, ...) object@fitted_values
S7::method(predict, survey_glm_fit) <- function(object, ...) { ... }
S7::method(summary, survey_glm_fit) <- function(object, ...) { ... }

# Extract from details list
S7::method(AIC, survey_glm_fit) <- function(object, ...) object@details$aic
S7::method(deviance, survey_glm_fit) <- function(object, ...) object@details$deviance
```

### 11.3 Compatibility Goal

Users should be able to:
```r
model <- survey_glm(formula, design = survey_obj)
# model is a survey_glm_fit object (S7 class); survey_glm() is the constructor function

# All of these should work
coef(model)
vcov(model)
summary(model)
predict(model, newdata)
AIC(model)
model@details$aic  # Access via S7 slot ($ does not apply to S7 properties)
```

---

## XII. Documentation Standards

### 12.1 Function Documentation Template

```r
#' Function Title (Active Voice, Imperative Mood)
#'
#' Detailed description paragraph explaining what the function does.
#' Include information about when to use this function and what it returns.
#' Use multiple paragraphs if needed for clarity.
#'
#' @param data Data frame containing survey data. Must include all variables
#'   referenced in design specification.
#' @param ids <[`tidy-select`][tidyselect::tidyselect]> Cluster IDs.
#'   For single-stage designs, use bare name (e.g., `ids = psu`).
#'   For multi-stage designs, use `c()` (e.g., `ids = c(psu, ssu)`).
#'   Omit for simple random sample.
#'
#' @return Object of class `survey_taylor`. Contains the survey data,
#'   design specification, and metadata in a validated structure.
#'
#' @section Design Variables:
#' Design variables (ids, strata, weights, fpc) are automatically preserved
#' through dplyr operations even if not explicitly selected. This ensures
#' the survey design remains statistically valid.
#'
#' @examples
#' # Simple random sample
#' srs <- as_survey(my_data, weights = wt)
#'
#' # Stratified sample
#' strat <- as_survey(my_data, weights = wt, strata = region)
#'
#' # Two-stage cluster sample
#' cluster <- as_survey(my_data, ids = c(psu, ssu), weights = wt)
#'
#' # Using tidy-select helpers
#' # (if you have repwt1, repwt2, ..., repwt80)
#' rep_design <- as_survey_repweights(
#'   my_data,
#'   weights = wt,
#'   repweights = starts_with("repwt"),
#'   type = "JK1"
#' )
#'
#' @seealso 
#' [as_survey_repweights()] for replicate weight designs,
#' [as_survey_twophase()] for two-phase designs,
#' [update_design()] to modify design after construction
#'
#' @export
as_survey <- function(data, ids = NULL, ...) {
  # Implementation
}
```

---

### 12.2 Error Message Documentation

All error messages should be documented in function help:

```r
#' @section Errors:
#' This function will error if:
#' * Design variables do not exist in `data`
#' * Weights are negative or zero
#' * Both `probs` and `weights` are provided but inconsistent
#'
#' Use [cli::cli_abort()] for all errors to ensure clear, formatted messages.
```

---

## XIII. Implementation Notes

### 13.1 Code Organization

Follow the file structure exactly as specified in implementation plan:
```
R/
├── 00-s7-classes.R          # All S7 class definitions
├── 01-metadata-system.R     # Metadata functions
├── 02-validators.R          # Validation helpers
├── 03-constructors.R        # as_survey* functions
├── 04-methods-print.R       # Print and summary methods
├── 05-methods-conversion.R  # Conversion functions
├── 06-variance-estimation.R # Vendored variance code
├── 07-utils.R               # Helper utilities
└── surveycore-package.R     # Package documentation
```

---

### 13.2 Timing & Performance

**Phase 0 Requirement: Basic Timing Only**

```r
# In tests, include basic timing
test_that("constructor is reasonably fast", {
  timing <- system.time({
    design <- as_survey(large_data, ids = psu, weights = wt)
  })
  
  # No formal benchmark, just sanity check
  expect_lt(timing["elapsed"], 5)  # Should take < 5 seconds for large data
})
```

**No formal benchmarking in Phase 0.** Performance optimization is Phase 3+.

---

### 13.3 Platform Testing

**Must test on:**
- Windows (latest)
- macOS (latest)
- Ubuntu (latest LTS)

**R versions:**
- R-release
- R-devel
- R-oldrel (if time permits)

**Handled by GitHub Actions CI/CD**

---

## XIV. Glossary

**Design Variables:** Variables that define the survey design (ids, strata, weights, fpc, repweights). Must always be present in data.

**Domain:** A subpopulation of interest. Domain estimation keeps all data but analyzes only the domain.

**Physical Subset:** Removing rows from data (dangerous for variance estimation).

**Domain Estimation:** Analyzing a subpopulation while keeping all data (correct for variance).

**Tidy-Select:** R's column selection syntax supporting helpers like `starts_with()`, `contains()`, etc.

**Invariant:** A condition that must always be true for a valid object.

**Contract:** A promise about how a function behaves.

**Semi-Mutable:** Object can be modified but only in controlled ways.

---

## XV. Change Log

**Version 1.0 (February 18, 2025):**
- Initial formal specification
- Based on comprehensive design discussions
- Incorporates all critical decisions
- Ready for implementation

---

**END OF FORMAL SPECIFICATION**

This document is authoritative. Implementation must follow these specifications exactly. Any deviations require explicit approval and documentation.
