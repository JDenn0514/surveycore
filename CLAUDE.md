# surveycore Package Development

## Project Overview

surveycore is the foundation package of the surveyverse ecosystem — a modern,
tidyverse-compatible replacement for the `survey` and `srvyr` packages in R.
It provides S7-based survey design objects, a metadata/label system, and
vendored variance estimation code.

## Package Information

- **Name:** surveycore
- **Purpose:** Core survey infrastructure — S7 objects, metadata, variance estimation
- **Target Audience:** Anyone conducting survey research; tidyverse users
- **Current Status:** Planning phase (Phase 0 not yet started)
- **License:** GPL-3 (required by vendored survey package code)

## Vision & Goals

### Project Vision
Create a modern, tidyverse-compatible ecosystem for survey analysis in R that prioritizes:
1. **Statistical Rigor** - Maintain exact statistical accuracy with proper survey variance estimation
2. **Tidy Integration** - Seamless integration with dplyr/tidyr workflows
3. **Label Preservation** - Automatic preservation of haven-style metadata throughout analysis
4. **User Experience** - Intuitive API that makes complex survey analysis accessible

### Core Principles
- **Accuracy First**: Statistical correctness is non-negotiable; performance and convenience are secondary
- **Modular Design**: Separate packages with clear responsibilities, loadable together
- **Independence**: No runtime dependency on `survey` or `srvyr` packages (vendor variance code with attribution)
- **Modern R**: Built on S7 object system, requires R >= 4.3.0
- **Full Replacement**: Designed as complete alternative to `survey` + `srvyr`, not a wrapper

## Key Design Decisions (Finalized)

- **S7 class system** — not S3 or R6. Use `S7::new_class()` and `S7::method()` syntax throughout.
- **Tidy-select interface** — bare names everywhere, no formula syntax (`ids = c(psu, ssu)` not `ids = ~psu+ssu`)
- **Metadata in a separate property** — not on data.frame columns
- **Vendor variance code** — copy from `survey` package with GPL attribution; no runtime dependency
- **CLI errors** — all errors/warnings use `cli::cli_abort()` / `cli::cli_warn()`
- **Three packages** — surveycore, surveytidy, surveyverse (+ surveyweights)

## S7 Method Syntax

**Important:** S7 does NOT use S3 method registration syntax. Use S7's own method dispatch:

```r
# WRONG - S3 syntax does not work for S7
print.survey_taylor <- function(x, ...) { ... }

# CORRECT - S7 method registration
S7::method(print, survey_taylor) <- function(x, n = 10, ...) { ... }
```

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_metadata`
- GLM fit class: `survey_glm_fit` (the constructor function is `survey_glm()`)
- Result classes: `survey_mean`, `survey_total`, `survey_freq`, etc. (S3 built on tibble)

## Naming Conventions

- Analysis functions: `get_freqs()`, `get_means()`, `get_diffs()`, `get_corr()`, `get_totals()`, `get_quantiles()`, `get_ratios()`
- Metadata getters: `extract_var_label()`, `extract_val_labels()`, `extract_question_preface()`, `extract_var_note()`
- Metadata setters (single): `set_var_label()`, `set_val_labels()`, `set_question_preface()`, `set_var_note()`
- Metadata setters (plural): `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, `set_variable_notes()`
- Internal helpers: prefix with `.` (e.g., `.extract_haven_labels()`)

## Architecture

### File Organization (R/)
```
R/
├── 00-s7-classes.R          # All S7 class definitions
├── 01-metadata-system.R     # Metadata functions
├── 02-validators.R          # Validation helpers (internal)
├── 03-constructors.R        # as_survey(), as_survey_rep(), as_survey_twophase()
├── 04-methods-print.R       # Print and summary methods
├── 05-methods-conversion.R  # as_svydesign(), from_svydesign(), as_tbl_svy(), from_tbl_svy()
├── 06-variance-estimation.R # Vendored variance code from survey package (internal)
├── 07-utils.R               # Helper utilities
├── 08-update-design.R       # update_design()
└── surveycore-package.R     # Package-level documentation
```

### Test Organization (tests/testthat/)
```
tests/testthat/
├── helper-test-data.R       # Test data generators
├── test-s7-classes.R
├── test-metadata-system.R
├── test-validators.R
├── test-constructors.R
├── test-tidy-select.R
├── test-methods-print.R
├── test-conversion.R
├── test-variance-estimation.R
└── test-update-design.R
```

## Key Implementation Details

### Design Variables Are Sacred
- Never remove design variables during operations
- Never silently allow renaming design variables
- Always warn when weight column is modified

### Metadata Lifecycle
- Auto-delete metadata when variable is removed via `select()`
- Auto-rename metadata when variable is renamed via `rename()`
- Track transformation history in `@metadata@transformations`

### Domain Estimation vs Physical Subsetting
- `filter()` → domain estimation (keeps all rows, marks domain membership)
- `subset()` → physical subsetting (removes rows, issues strong warning)

### Internal Weight Column Name
When converting probs to weights internally, use `"..surveycore_wt.."` to avoid
colliding with user columns named `.weights`.

## Working With This Codebase

1. **Follow established patterns** — consistency across the codebase matters
2. **Provide complete code blocks** — ready to copy and use
3. **Include tests** — always provide corresponding tests for new functions
4. **Update documentation** — include roxygen2 comments with all code
5. **Explain design decisions** — briefly note the "why" behind choices
6. **Consider edge cases** — NA handling, empty groups, single PSU strata
7. **Keep it simple** — prefer clear over clever code

## Reference Documents

All planning documents are in `plans/`:
- `surveyverse-roadmap.md` — ecosystem-level roadmap and architecture
- `surveycore-phase0-formal-specification.md` — authoritative spec for Phase 0 behavior
- `phase-0-implementation-plan-v2.md` — step-by-step build instructions for Phase 0
- `GUIDE-using-phase0-docs.md` — how to use the Phase 0 documents together

**The formal specification is authoritative for behavior.**
**The implementation plan is authoritative for file organization.**
