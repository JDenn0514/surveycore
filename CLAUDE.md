# surveycore Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveycore relates to other packages.**

surveycore is the foundation package of the surveyverse ecosystem — a modern, tidyverse-compatible
replacement for `survey` and `srvyr`. It provides S7-based survey design objects, a
metadata/label system, and vendored variance estimation code. License: GPL-3.

---

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_metadata`, `survey_calibrated`
- GLM fit class: `survey_glm_fit` (constructor function is `survey_glm()`)
- Result classes: `survey_mean`, `survey_total`, `survey_freq`, etc. (S3 built on tibble)

## Naming Conventions

- Analysis functions: `get_freqs()`, `get_means()`, `get_diffs()`, `get_corr()`, `get_totals()`, `get_quantiles()`, `get_ratios()`
- Metadata getters: `extract_var_label()`, `extract_val_labels()`, `extract_question_preface()`, `extract_var_note()`
- Metadata setters (single): `set_var_label()`, `set_val_labels()`, `set_question_preface()`, `set_var_note()`
- Metadata setters (plural): `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, `set_variable_notes()`
- Internal helpers: prefix with `.` (e.g., `.extract_haven_labels()`)

## Key Implementation Rules

**Design variables are sacred** — never remove or silently rename design variables. Always warn
when weight column is modified.

**Metadata lifecycle** — auto-delete metadata on `select()` removal; auto-rename on `rename()`;
track transformation history in `@metadata@transformations`.

**Domain estimation vs physical subsetting** — `filter()` keeps all rows and marks domain
membership; `subset()` removes rows and issues a strong warning.

**Internal weight column name** — use `"..surveycore_wt.."` when converting probs to weights
internally (avoids collision with user columns named `.weights`).

## Workflow Requirements

- Every non-trivial change lives on a feature branch — never commit implementation code to `main`
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/`
- All commits use Conventional Commits format: `feat(scope): description`
- Run `devtools::document()` before committing any file with roxygen2 changes
- Run `devtools::check()` before opening a PR

## R CMD Check Gotchas

**Examples must load Imports packages explicitly.** R CMD check runs examples in a fresh session
with only `library(surveycore)` loaded. If an example calls a bare function from an Imports
package, add `library(pkg)` at the top of the block. In practice surveycore examples only call
its own exported API, so this rarely bites — but keep it in mind.

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names and CLI message templates
- `plans/surveycore-phase0-formal-specification.md` — authoritative Phase 0 spec
- `plans/phase-0-implementation-plan-v2.md` — Phase 0 build order (all complete as of v0.1.0)
- `.claude/rules/` — code style, testing standards, R package conventions, GitHub strategy
- `.claude/projects/-Users-jacobdennen-surveycore/memory/MEMORY-phase0.md` — Phase 0 implementation details (archived)
