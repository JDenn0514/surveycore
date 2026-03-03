# surveycore Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveycore relates to other packages.**

surveycore is the foundation package of the surveyverse ecosystem — a modern, tidyverse-compatible
replacement for `survey` and `srvyr`. It provides S7-based survey design objects, a
metadata/label system, and vendored variance estimation code. License: GPL-3.

---

## Current Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — S7 classes, metadata, constructors, variance (Taylor + replicate), print, conversion | ✅ Complete | Tagged v0.1.0 |
| Phase 0.5 — surveytidy dplyr verbs (`filter`, `select`, `mutate`, `group_by`) | ✅ Complete | Separate `surveytidy` package |
| Prereq PR 1 — `survey_srs` class + constructor + variance (`feature/survey-srs`) | ✅ Complete | See `plans/survey-srs-formal-specification.md` |
| Phase 0.75 — Two-phase variance vendoring (`feature/variance-twophase`) | ✅ Complete | Required before Phase 1 |
| Phase 1 — Analysis functions (`get_freqs`, `get_means`, `get_totals`, `get_corr`, `get_quantiles`, `get_ratios`) | ✅ Complete | Core functions on main (v0.3.0); nested `.meta` + group label refactor merged to develop (PR #22–23) |
| Phase 2 — Regression (`survey_glm_fit`, `survey_glm()`) | 🔜 Next | See `plans/phase-2-glm-formal-specification.md` |

**Next action:** Begin Phase 2 — Regression. Spec at `plans/phase-2-glm-formal-specification.md`.

---

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_srs`, `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_metadata`, `survey_calibrated`
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
- `plans/phase-2-glm-formal-specification.md` — authoritative Phase 2 spec (regression)
- `plans/claude-decisions-phase-2.md` — pre-implementation review decisions for Phase 2
- `plans/archive/phase-1/` — Phase 1 docs (spec, impl plan, decisions, reviews — all complete)
- `plans/survey-srs-formal-specification.md` — authoritative spec for `survey_srs` class + `as_survey_srs()` + SRS variance
- `plans/archive/` — completed phase docs (Phase 0 spec, Phase 0 impl plan, Phase 0.5 context)
- `.claude/rules/` — code style, testing standards, R package conventions, GitHub strategy
- `.claude/projects/-Users-jacobdennen-surveycore/memory/MEMORY-phase0.md` — Phase 0 implementation details (archived)
