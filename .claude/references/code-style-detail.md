# Code Style — Worked Examples and Rationale

Detail moved out of `.claude/rules/code-style.md` and
`.claude/rules/engineering-preferences.md`. The rules themselves live there;
this file shows how to apply them. Read this when writing new code and the
correct application is not obvious from the rule tables.

---

## General R style examples

### Indentation (2 spaces)

Matches rlang, tidyselect, cli, and S7 source.

```r
# Correct
survey_taylor <- S7::new_class(
  "survey_taylor",
  parent = survey_base,
  validator = function(self) {
    if (is.null(self@variables$weights)) {
      cli::cli_abort("...")
    }
  }
)

# Wrong
survey_taylor <- S7::new_class(
    "survey_taylor",           # 4-space indent
    parent = survey_base,
```

### Line length (80 characters)

For long function signatures, break after the opening `(` and align arguments:

```r
# Good — break after (
as_survey <- function(
  data,
  ids = NULL,
  probs = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE
) {

# Also good for short signatures — keep on one line if under 80 chars
set_var_label <- function(x, var, label) {
```

For long `cli_abort()` calls, break the named vector across lines:

```r
cli::cli_abort(
  c(
    "x" = "Weight column {.field {weights_var}} must be numeric.",
    "i" = "Got class {.cls {class(wt_col)}}.",
    "v" = "Use {.code as.numeric({.field {weights_var}})} to convert."
  ),
  class = "surveycore_error_weights_not_numeric"
)
```

### Auto-formatter (`air`)

```r
# Install
pak::pak("posit-dev/air")

# Format the entire package
air::format_package()

# Format a single file (or use the RStudio/Positron addin)
air::format_file("R/03-constructors.R")
```

Run on save or before committing. Do not manually adjust spacing after
running `air`. If `air` output looks wrong, there's a syntax problem — don't
work around it. Run `air::format_package()` before opening a PR. Do not
commit `air`-reformatted files in the same commit as functional changes —
reformat first, then make the change.

### Pipe and assignment

```r
# Correct
survey_obj |>
  set_var_label(age, "Age in years") |>
  set_var_label(income, "Annual income")
weights_var <- names(weights_cols)

# Wrong
survey_obj %>%
  set_var_label(age, "Age in years")
weights_var = names(weights_cols)
```

Enforced by `lintr::pipe_consistency_linter("native")`.

---

## S7 pattern examples

### Property access accessors

```r
# Accessor functions (defined in 07-utils.R, exported)
survey_data     <- function(x) x@data
survey_metadata <- function(x) x@metadata

# Internal code always uses @ directly
wt_col <- x@data[[x@variables$weights]]
n_labels <- length(x@metadata@variable_labels)
```

### Method registration comment

Every method registration in the methods files must include a comment
pointing to the class definition:

```r
# Class defined in R/00-s7-classes.R
S7::method(print, survey_taylor) <- function(x, n = 10, ...) {
  ...
}
```

### Class membership testing

```r
# Correct — class object; rename caught at load time
if (!S7::S7_inherits(phase1, survey_taylor)) {
  cli::cli_abort(...)
}

# Wrong — string; rename silently breaks the check
if (!inherits(phase1, "survey_taylor")) {
  cli::cli_abort(...)
}

# Also wrong — S4 idiom in an S7 codebase
if (!is(phase1, "survey_taylor")) {
  cli::cli_abort(...)
}
```

### `@variables` list: all keys always present

```r
# Correct — all keys present
variables <- list(
  ids             = NULL,    # NULL means "not specified"
  weights         = weights_var,
  strata          = NULL,
  fpc             = NULL,
  nest            = nest,
  probs_provided  = FALSE
)

# Wrong — missing keys
variables <- list(
  weights = weights_var,
  nest    = nest
  # ids, strata, fpc absent — ambiguous: "not specified" or "forgot"?
)
```

Code throughout the codebase checks `is.null(x@variables$strata)` — this only
works reliably when keys are always present.

---

## Error and warning examples

### `cli_abort()` good vs bad

```r
# Good
cli::cli_abort(
  c(
    "x" = "{.arg fpc} column {.field {fpc_var}} contains {sum(is.na(fpc_col))} NA value(s).",
    "i" = "FPC must be fully observed for finite population correction.",
    "v" = "Remove rows with missing FPC or set {.arg fpc = NULL} to omit the correction."
  ),
  class = "surveycore_error_fpc_na"
)

# Bad — no class, no context
cli::cli_abort("FPC has NAs")
```

### `cli_warn()` structure

Same structure and same `class=` requirement as `cli_abort()`:

```r
cli::cli_warn(
  c(
    "!" = "What triggered the warning.",
    "i" = "Why this matters.",
    "i" = "What to do if this is unexpected."
  ),
  class = "surveycore_warning_{condition}"    # ALWAYS required
)
```

### Class name examples

```r
# Error class examples
"surveycore_error_not_data_frame"
"surveycore_error_weights_nonpositive"
"surveycore_error_subset_degenerate"

# Warning class examples
"surveycore_warning_srs_no_weights"
"surveycore_warning_single_stratum"
"surveycore_warning_psu_multi_strata"
```

For the full inline markup reference (50+ classes, pluralization, progress
bars, theming), see the `cli` skill in `.claude/skills/cli/`.

---

## Function design examples

### Return visibility

```r
# Setter — always invisible
set_var_label.survey_base <- function(x, var, label) {
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@variable_labels[[var_name]] <- label
  invisible(x)
}

# Getter — always visible
extract_var_label.survey_base <- function(x, var) {
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@variable_labels[[var_name]]
}
```

### Argument order

```r
# as_survey_rep: data (1), weights (2, required), repweights (2, required),
#                type (3, required scalar), then optional scalars
as_survey_rep <- function(
  data,
  weights,
  repweights,
  type = c("JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", ...),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE
)

# set_var_label: x (1), var (2, required NSE), label (3, required scalar)
set_var_label <- function(x, var, label)
```

Named-only control args go after `...` — R's argument-matching rule forces
named supply for any parameter after `...`, the tidyverse idiom for control
flags like `.id`, `.on_missing`, `group`, `names_to`, `values_to`. Examples:
`get_freqs(design, x, ..., group, names_to, values_to, variance)`;
`get_means(coll, y, ..., .id = ".survey", .on_missing = "error")`.

**Exception — unified per-variable metadata setters.** When `...` captures
Convention 1 (named arguments, one per variable) rather than acting as a
tidyselect/passthrough tail, it goes immediately after `x`, before the
optional scalar `variable`/content arguments: `set_var_label(x, ...,
variable = NULL, label = NULL)`. This is the established shape for every
unified setter (`set_var_label()`, `set_val_labels()`,
`set_question_preface()`, `set_var_note()`, `set_universe()`,
`set_missing_codes()`, `set_var_extra()`) — `variable`/content args are
Convention 3's alternative to `...`, not independent optional arguments
that should follow it.

### Dispatch rule

```r
# CORRECT — extending print (existing generic)
S7::method(print, survey_taylor) <- function(x, n = 10, ...) { ... }

# CORRECT — new surveycore-owned generic
# Plain function; S7::S7_inherits() validates the type explicitly.
set_var_label <- function(x, var, label) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c("x" = "{.arg x} must be a survey design object."),
      class = "surveycore_error_not_survey_object"
    )
  }
  # implementation
}

# WRONG — UseMethod() cannot find name.surveycore::survey_base methods
set_var_label <- function(x, var, label) UseMethod("set_var_label")
set_var_label.survey_base <- function(x, var, label) { ... }  # never dispatched

# WRONG — S3 dispatch silently ignored for S7 objects when generic is S7-aware
print.survey_taylor <- function(x, n = 10, ...) { ... }   # never dispatched
summary.survey_taylor <- function(object, ...) { ... }    # never dispatched
```

### Internal helper placement

```r
# In R/03-constructors.R — used only by as_survey()
.check_probs_weights_consistency <- function(probs_var, weights_var, data, tol = 1e-6) {
  ...
}

# In R/07-utils.R — used by constructors AND update_design()
.get_design_vars_flat <- function(design) {
  c(
    design@variables$ids,
    design@variables$weights,
    design@variables$strata,
    design@variables$fpc
  )
}
```

When a single-use inline helper grows a second call site, promote it to
`07-utils.R` in the same PR that adds the second call.

---

## Tooling configuration

### `.lintr` (in package root)

```yaml
linters: linters_with_defaults(
  line_length_linter(80),
  pipe_consistency_linter("native"),
  object_name_linter("snake_case"),
  assignment_linter()
)
exclusions: list("data-raw")
```

### `.editorconfig` (in package root)

```ini
root = true

[*.R]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{md,yaml,yml}]
indent_size = 2
```

---

## Engineering preferences — detail

The five principles live in `.claude/rules/engineering-preferences.md`.
Their sub-points:

### 1. DRY — flag repetition aggressively

- Repeated patterns in 2+ functions → extract a shared internal helper
- Repeated validation logic → consolidate into a single validator
- Repeated test setup → move to `helper-*.R`
- Do not defer DRY violations as "we can clean this up later." Surface them
  during spec review, not after the code is written.

### 2. Well-tested — more tests is better

- When unsure whether an edge case needs a test, write the test
- Never suggest removing coverage to hit a deadline
- 98%+ line coverage is the floor, not the target
- Every error class gets a test; every edge case in the spec gets a test

### 3. Engineered enough — not under, not over

**Under-engineered** (fragile, hacky): missing edge case handling; contracts
that don't specify behavior at the boundaries; validation that only checks
the happy path.

**Over-engineered** (premature abstraction, unnecessary complexity):
abstraction layers that don't yet have two real call sites; generalization
for hypothetical future requirements not in the roadmap; clever solutions
when a straightforward one works fine.

The right amount of engineering is determined by what's in the current spec,
not by what might be needed in a later phase.

### 4. Handle more edge cases, not fewer

- All-NA inputs, zero-weight rows, single-level groups, empty domains — these
  are not hypothetical; they appear in real survey data
- "That probably won't happen" is not a reason to skip an edge case
- Thoughtfulness > speed: a slower implementation that handles edge cases
  correctly is always preferred

### 5. Explicit over clever

- `S7::S7_inherits(x, ClassName)` not `inherits(x, "survey_taylor")`
- Named error classes on every `cli_abort()`, not bare messages
- Spell out behavior in the spec rather than relying on "the reader will infer"
- Document assumptions rather than leaving them implicit

### How to apply these during review

1. Read through with DRY as the first lens — find repetition before anything else
2. Check every error condition and edge case in the spec against the test plan
3. For each design decision, ask: is this the right level of abstraction for
   what's actually needed now?
4. For each boundary condition mentioned in the spec, ask: is the behavior
   fully specified, or is it left implicit?
5. For any "shortcut" in the implementation plan, ask: does this skip something
   that will need to be added back later anyway?
