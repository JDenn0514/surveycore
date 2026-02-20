# surveycore Package Development

## Project Overview

surveycore is the foundation package of the surveyverse ecosystem — a
modern, tidyverse-compatible replacement for the `survey` and `srvyr`
packages in R. It provides S7-based survey design objects, a
metadata/label system, and vendored variance estimation code.

## Package Information

- **Name:** surveycore
- **Purpose:** Core survey infrastructure — S7 objects, metadata,
  variance estimation
- **Target Audience:** Anyone conducting survey research; tidyverse
  users
- **Current Status:** Phase 0 in progress (test helpers done; S7 classes
  next)
- **License:** GPL-3 (required by vendored survey package code)

## Vision & Goals

### Project Vision

Create a modern, tidyverse-compatible ecosystem for survey analysis in R
that prioritizes: 1. **Statistical Rigor** - Maintain exact statistical
accuracy with proper survey variance estimation 2. **Tidy
Integration** - Seamless integration with dplyr/tidyr workflows 3.
**Label Preservation** - Automatic preservation of haven-style metadata
throughout analysis 4. **User Experience** - Intuitive API that makes
complex survey analysis accessible

### Core Principles

- **Accuracy First**: Statistical correctness is non-negotiable;
  performance and convenience are secondary
- **Modular Design**: Separate packages with clear responsibilities,
  loadable together
- **Independence**: No runtime dependency on `survey` or `srvyr`
  packages (vendor variance code with attribution)
- **Modern R**: Built on S7 object system, requires R \>= 4.3.0
- **Full Replacement**: Designed as complete alternative to `survey` +
  `srvyr`, not a wrapper

## Key Design Decisions (Finalized)

- **S7 class system** — not S3 or R6. Use
  [`S7::new_class()`](https://rconsortium.github.io/S7/reference/new_class.html)
  and
  [`S7::method()`](https://rconsortium.github.io/S7/reference/method.html)
  syntax throughout.
- **Tidy-select interface** — bare names everywhere, no formula syntax
  (`ids = c(psu, ssu)` not `ids = ~psu+ssu`)
- **Metadata in a separate property** — not on data.frame columns
- **Vendor variance code** — copy from `survey` package with GPL
  attribution; no runtime dependency
- **CLI errors** — all errors/warnings use
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) /
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
- **Three packages** — surveycore, surveytidy, surveyverse (+
  surveyweights)

## S7 Method Syntax

**Important:** S7 does NOT use S3 method registration syntax. Use S7’s
own method dispatch:

``` r
# WRONG - S3 syntax does not work for S7
print.survey_taylor <- function(x, ...) { ... }

# CORRECT - S7 method registration
S7::method(print, survey_taylor) <- function(x, n = 10, ...) { ... }
```

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_metadata`
- GLM fit class: `survey_glm_fit` (the constructor function is
  `survey_glm()`)
- Result classes: `survey_mean`, `survey_total`, `survey_freq`, etc. (S3
  built on tibble)

## Naming Conventions

- Analysis functions: `get_freqs()`,
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
  `get_diffs()`, `get_corr()`,
  [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
  `get_quantiles()`, `get_ratios()`
- Metadata getters:
  [`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
  [`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
  [`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
  [`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md)
- Metadata setters (single):
  [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
  [`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
  [`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md)
- Metadata setters (plural):
  [`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
  [`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
  [`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
  [`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md)
- Internal helpers: prefix with `.` (e.g., `.extract_haven_labels()`)

## Architecture

### File Organization (R/)

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

### Test Organization (tests/testthat/)

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

- [`filter()`](https://rdrr.io/r/stats/filter.html) → domain estimation
  (keeps all rows, marks domain membership)
- [`subset()`](https://rdrr.io/r/base/subset.html) → physical subsetting
  (removes rows, issues strong warning)

### Internal Weight Column Name

When converting probs to weights internally, use `"..surveycore_wt.."`
to avoid colliding with user columns named `.weights`.

## Before Starting Any Implementation

**Read these files first — in this order — before writing any code:**

1.  `.claude/rules/code-style.md` — indentation, S7 method syntax, error
    conventions, function design
2.  `.claude/rules/testing-standards.md` — test structure, coverage
    requirements, assertion patterns
3.  `.claude/rules/r-package-conventions.md` — roxygen2, NAMESPACE,
    exports, R CMD check hygiene
4.  `.claude/rules/github-strategy.md` — branching model, commit format,
    PR workflow

**Then read the planning documents:**

5.  `plans/surveycore-phase0-formal-specification.md` — authoritative
    for WHAT to build and how it behaves
6.  `plans/phase-0-implementation-plan-v2.md` — authoritative for HOW to
    organize code and build order
7.  `plans/error-messages.md` — canonical table of all error/warning
    classes and CLI message templates

**Workflow requirements (non-negotiable):**

- Every non-trivial change lives on a feature branch — never commit
  implementation code directly to `main`
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/` (see
  github-strategy.md Section 4)
- All commits use Conventional Commits format:
  `feat(scope): description` (see github-strategy.md Section 6)
- One PR per test file granularity (see github-strategy.md Section 5 for
  the full component-to-PR map)
- Run `devtools::document()` before committing any file that changes
  roxygen2 content
- Run `devtools::check()` before opening a PR

**Phase 0 build order** (from implementation plan Component sequence):

1.  `feature/test-helpers` — `tests/testthat/helper-test-data.R` ✅ DONE
2.  `feature/s7-classes` — `R/00-s7-classes.R` ✅ DONE
3.  `feature/metadata-system` — `R/01-metadata-system.R` (extractors +
    setters) ✅ DONE
4.  `feature/validators` — `R/02-validators.R` ✅ DONE
5.  `feature/as-survey` — `R/03-constructors.R` (as_survey() only) ✅
    DONE
6.  `feature/as-survey-rep` — `R/03-constructors.R` (as_survey_rep()) ✅
    DONE
7.  `feature/as-survey-twophase` — `R/03-constructors.R`
    (as_survey_twophase()) ✅ DONE
8.  `feature/update-design` — `R/08-update-design.R` ✅ DONE
9.  `feature/print-methods` — `R/04-methods-print.R`
10. `feature/utils` — `R/07-utils.R`
11. `feature/conversion-to-survey` — `R/05-methods-conversion.R` (to
    svydesign/tbl_svy)
12. `feature/conversion-from-survey` — `R/05-methods-conversion.R` (from
    svydesign/tbl_svy)
13. `feature/variance-taylor` — `R/06-variance-estimation.R` (Taylor
    series)
14. `feature/variance-replicate` — `R/06-variance-estimation.R`
    (replicate weights)

------------------------------------------------------------------------

## Working With This Codebase

1.  **Follow established patterns** — consistency across the codebase
    matters
2.  **Provide complete code blocks** — ready to copy and use
3.  **Include tests** — always provide corresponding tests for new
    functions
4.  **Update documentation** — include roxygen2 comments with all code
5.  **Explain design decisions** — briefly note the “why” behind choices
6.  **Consider edge cases** — NA handling, empty groups, single PSU
    strata
7.  **Keep it simple** — prefer clear over clever code

## Reference Documents

All planning documents are in `plans/`: - `surveyverse-roadmap.md` —
ecosystem-level roadmap and architecture -
`surveycore-phase0-formal-specification.md` — authoritative spec for
Phase 0 behavior - `phase-0-implementation-plan-v2.md` — step-by-step
build instructions for Phase 0 - `GUIDE-using-phase0-docs.md` — how to
use the Phase 0 documents together - `error-messages.md` — canonical
error/warning class names and CLI message templates

All finalized decisions are in `.claude/rules/`: - `code-style.md` — R
style, S7 patterns, error conventions, function design -
`testing-standards.md` — test structure, coverage, assertion patterns,
test data - `r-package-conventions.md` — roxygen2, NAMESPACE, exports, R
CMD check hygiene - `github-strategy.md` — branching, commits, PRs,
CI/CD, release process

**The formal specification is authoritative for behavior.** **The
implementation plan is authoritative for file organization.** **The
rules files are authoritative for all style and workflow decisions.**
