# surveycore R Package Conventions

**Version:** 1.1
**Status:** Decided — extends `r-package-conventions.md` with
surveycore-specific rules. Read that file first.

## Quick Reference (surveycore-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| `@param` examples | Fuller for survey-specific args | `nest`, `fpc`, `type` get longer docs |
| Entry points | Constructor functions | `as_survey()`, `as_survey_rep()`, `as_survey_twophase()` |
| `@seealso` | Constructors only | Only constructors link to each other |
| `@family` groups | By operational category | `constructors`, `metadata`, `validators`, `conversion` |
| Setters return | Always `invisible(x)` | `set_var_label()`, `set_variable_labels()` |
| Getters return | Always visible | `extract_var_label()`, `extract_val_labels()` |

## Naming

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_metadata`. Result classes built on tibble:
  `survey_mean`, `survey_total`, `survey_freq`, `survey_quantiles`, etc.

| Category | Pattern | Example |
|----------|---------|---------|
| Analysis functions | `get_*` | `get_means()`, `get_totals()`, `get_freqs()` |
| Metadata extractors | `extract_*` | `extract_var_label()`, `extract_val_labels()` |
| Metadata setters (single) | `set_*` | `set_var_label()` |
| Metadata setters (plural) | `set_*` (also accept vector) | `set_variable_labels()` |
| Internal helpers | prefix `.` | `.validate_weights()`, `.resolve_tidy_select()` |

`@family` groups: `constructors`, `metadata`, `validators`, `conversion`.

## Export policy

- Export: constructors, `extract_*()`, `set_*()`, `get_*()`, S7 classes,
  and utilities (`update_design()`, `as_svydesign()`, `from_svydesign()`).
- Do NOT export: `.`-prefixed validators and helpers, internal S7 generics,
  vendored variance code.

## `haven` handling

`haven` is in `Suggests`, not `Imports`. At runtime extract label attributes
with base R — `attr(col, "label", exact = TRUE)` and
`attr(col, "labels", exact = TRUE)` — never `haven::var_label()`. `haven` is
only used in `data-raw/` scripts to read `.xpt` files.

---
Worked documentation examples (survey-specific `@param` blocks, `@seealso`
format, the pre-commit documentation checklist):
`.claude/references/r-package-detail.md` §surveycore documentation examples.
Read it when documenting constructors or survey-specific arguments.
