# surveycore Code Style Guide

**Version:** 1.1
**Status:** Decided — do not re-litigate without updating this document

## Quick Reference

| Decision | Choice |
|----------|--------|
| Indentation | 2 spaces |
| Line length | 80 characters |
| Auto-formatter | `air` (Posit's R formatter) |
| Pipe operator | Native `\|>` only |
| Style guide | tidyverse style (via air) |
| Property access | Direct `@` everywhere; accessor functions for `@data` and `@metadata` only |
| S7 method file org | Methods grouped by type in dedicated files (`04-methods-print.R`, etc.) |
| Class membership test | `S7::S7_inherits(x, survey_taylor)` — class object, never a string |
| `@variables` absent keys | All keys always present; unspecified values as `NULL` |
| Setter return values | `invisible(x)` |
| Getter return values | Visible (no `invisible()`) |
| Argument order | `x`/`data` first → required NSE → required scalar → optional NSE → optional scalar → `...` → named-only control args |
| Internal helper placement | Inline if used in 1 file; `07-utils.R` if used in 2+ files |
| Dispatch rule | `S7::method()` for extending existing generics; plain function + `S7::S7_inherits()` for surveycore-owned generics |
| Error structure | `"x"` + `"i"` + optional `"v"` bullets; `class=` on every `cli_abort()` |
| Warning classes | `class=` on every `cli_warn()` too |
| Message language | Declarative for `"x"`/`"i"` bullets; imperative for `"v"` bullet |

## General R style

- `<-` for all assignments; `=` only for function arguments.
- Run `air::format_package()` before opening a PR; reformat-only commits stay
  separate from functional changes.

## S7 patterns

- `@data` and `@metadata` have exported accessors (`survey_data()`,
  `survey_metadata()`); all other properties use `@` directly in internal
  code. Never show `@` in user-facing docs or examples.
- Method files: `00-s7-classes.R` holds class definitions + validators only;
  print/summary methods in `04-methods-print.R`; conversion methods in
  `05-methods-conversion.R`. Every method registration carries a comment
  pointing to the class definition file.
- Membership tests: always `S7::S7_inherits(x, ClassObject)` with the class
  object — never a string (`inherits(x, "name")`) and never S4 `is()`.
- Every constructor initializes ALL `@variables` keys (`ids`, `weights`,
  `strata`, `fpc`, `nest`, `probs_provided`), using `NULL` for "not
  specified". Code relies on `is.null(x@variables$key)` checks.
- `@groups` is RESERVED for Phase 0.5: never read, write, or branch on it in
  Phase 0 code.

## Errors and warnings

Standard structure — `class=` is required on EVERY `cli_abort()` and
`cli_warn()` call, no exceptions:

```r
cli::cli_abort(
  c(
    "x" = "What went wrong (declarative).",      # always present
    "i" = "Context or diagnosis.",                # usually present
    "v" = "How to fix it (imperative)."           # when fixable
  ),
  class = "surveycore_error_{condition}"
)
```

- Class naming: `surveycore_error_{snake_case_condition}` /
  `surveycore_warning_{snake_case_condition}`.
- The canonical class list is `plans/error-messages.md`. Adding a new error:
  add the table row there first, use that class in code, add an
  `expect_error(class = ...)` test.
- Register: `"x"` declarative with the object as subject; `"i"` declarative
  with the system as subject; `"v"` imperative. Never address the user
  ("You must...").

### cli inline markup

| Showing | Markup | Renders as |
|---------|--------|------------|
| Function argument | `{.arg weights}` | `weights` |
| Column / variable name | `{.field {var}}` | `var` |
| Function name | `{.fn as_survey}` | `as_survey()` |
| Code snippet | `{.code nest = TRUE}` | `nest = TRUE` |
| A value | `{.val "brr"}` | `"brr"` |
| A class name | `{.cls survey_taylor}` | `<survey_taylor>` |

## Function design

Return visibility:

| Function type | Return |
|---------------|--------|
| Setters: `set_var_label()`, `set_variable_labels()`, `update_design()` | `invisible(x)` |
| Constructors: `as_survey()`, `as_survey_rep()` | Visible (the new object) |
| Extractors: `extract_var_label()`, `extract_val_labels()` | Visible |
| Print/summary: `S7::method(print, ...)` | `invisible(x)` |
| Validators (internal): `.validate_weights()` etc. | `invisible(TRUE)` on success |

Argument order precedence:

1. `x` / `data` — always mandatory, always first
2. Required NSE/tidy-select arguments
3. Required scalar arguments
4. Optional NSE/tidy-select arguments (`ids = NULL`, ...)
5. Optional scalar control arguments (`nest = FALSE`, ...)
6. `...`
7. Named-only control args after `...` (`.id`, `.on_missing`, `group`, ...)

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

Dispatch — one rule: who owns the generic?

| Situation | Use |
|-----------|-----|
| Extending an existing generic (`print`, `summary`, `filter`, ...) | `S7::method(generic, class) <- function(...) { }` |
| New generic owned by surveycore (`set_var_label`, `as_survey`, ...) | Plain function + `S7::S7_inherits()` type check |

**S3 dispatch does NOT work for S7 objects.** S7 uses namespaced class names
(`"surveycore::survey_base"`); `UseMethod()` would look for a method named
`set_var_label.surveycore::survey_base`, which is not a legal R function
name. Use a plain function with explicit `S7::S7_inherits()` type checking
instead.

Internal helpers: not exported, `.`-prefixed. Defined at the top of the one
file that uses them; promoted to `R/07-utils.R` in the same PR that adds a
second call site.

---
Worked examples and rationale: `.claude/references/code-style-detail.md`.
Read it when writing new code covered by these rules and the correct
application is not obvious from the tables above. Tooling configs (`.lintr`,
`.editorconfig`) are in the package root — read them there.
