# surveycore Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveycore relates to other packages.**

surveycore is the foundation package of the surveyverse ecosystem — a modern, tidyverse-compatible
replacement for `survey` and `srvyr`. It provides S7-based survey design objects, a
metadata/label system, and vendored variance estimation code. License: GPL-3.

---

## Implementation Status

The package API is stable. All core functionality is complete. New analysis
functions may be added but the existing structure will not change in breaking ways.

| Component | Status | Notes |
|-----------|--------|-------|
| S7 classes, metadata, constructors, variance (Taylor + replicate), print, conversion | ✅ Complete | v0.1.0 |
| surveytidy dplyr verbs (`filter`, `select`, `mutate`, `group_by`) | ✅ Complete | Separate `surveytidy` package |
| SRS support | ✅ Complete | Absorbed into `survey_taylor`; no ids/strata |
| Two-phase variance | ✅ Complete | v0.2.x |
| Analysis functions (`get_freqs`, `get_means`, `get_totals`, `get_corr`, `get_quantiles`, `get_ratios`) | ✅ Complete | v0.3.0 |
| Regression (`survey_glm_fit`, `survey_glm()`) | ✅ Complete | v0.6.x |
| T-tests and pairwise (`get_t_test()`, `get_pairwise()`) | ✅ Complete | PR #88; see `archive/get-t-test-pairwise/` |
| Effective sample size (`get_effective_n()`) | ✅ Complete | PR #122; see `archive/effective-n/` |
| Design variance (`get_variance()`) | ✅ Complete | PRs #103, #104; see `archive/get-variance/` |
| SATA metadata (`set_sata()`, `classify_question_type()`) | ✅ Complete | PRs #89, #90, #91, #92 |
| Design-based ANOVA (`get_anova()`, `anova.survey_glm_fit()`) | ✅ Complete | PRs #93, #94, #95, #96 |
| `survey_collection` container + `get_*()` dispatch | ✅ Complete | PRs #97, #98 |
| Polychoric / polyserial correlation (`get_corr(method = ...)`) | ✅ Complete | PRs #107, #108, #109 |
| Variable direction metadata (`set_higher_is()`, `set_reverse_coded()`, `get_diffs(show_favorability)`) | ✅ Complete | PRs #124, #125, #126; see `archive/variable-direction/` |
| Non-probability bootstrap variance (`as_survey_nonprob(repweights = ...)`, bootstrap dispatch in `get_*()`) | ✅ Complete | PRs #127, #130, #131; planning docs in `plans/` |

---

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_metadata`, `survey_nonprob`
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

## Git Workflow

- When asked to commit and create a PR, always target the `develop` branch unless explicitly told otherwise. Never assume `main` is the target.
- When the user asks for a simple git push, just push. Do not invoke the full commit/PR skill workflow unless explicitly requested.

## CI / Package Development

- For R package CI (pkgdown, R CMD check): always guard vignette chunks that depend on optional/in-development packages with `eval = requireNamespace("pkg", quietly = TRUE)`. Test locally before pushing.

## R Package Conventions

- Use the GSS dataset (not NHANES or gss_2024) for examples and tests unless told otherwise. Use rlang patterns over deparse().
- All R code written in any context — `.R` source files, roxygen2 `@examples` blocks, and ` ```r ``` ` blocks in `.md` spec and plan documents — must follow the rules in `.claude/rules/code-style.md`.

## General Behavior

- Before reading many files, check if the user's question can be answered from context already available. Prefer concise answers over exhaustive file exploration.

## Project Structure

- Skills are located in `.claude/skills/` (e.g., `.claude/skills/spec-workflow/`). Always check there first when referencing or modifying skills.

## R CMD Check Gotchas

**Examples must load Imports packages explicitly.** R CMD check runs examples in a fresh session
with only `library(surveycore)` loaded. If an example calls a bare function from an Imports
package, add `library(pkg)` at the top of the block. In practice surveycore examples only call
its own exported API, so this rarely bites — but keep it in mind.

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names and CLI message templates
- `archive/get-t-test-pairwise/` — spec, plan, and decisions for `get_t_test()` + `get_pairwise()` (shipped; PR #88)
- `archive/sata-metadata/` — SATA metadata spec, plan, and decisions (shipped; PRs #89–#92)
- `archive/get-anova/` — design-based ANOVA spec, plan, and decisions (shipped; PRs #93, #94, #95)
- `archive/get-anova-polymorphic/` — polymorphic `object` dispatch for `get_anova()` (shipped; PR #96)
- `archive/survey-collection/` — `survey_collection` container + `get_*()` dispatch spec, plan, and decisions (shipped; PRs #97, #98)
- `archive/get-covariance/` — `get_covariance()` spec, plan, decisions, and test spec (shipped; PR #105)
- `archive/collection-uniform-groups/` — uniform `@groups` enforcement across `survey_collection` (shipped; PR #106)
- `archive/polychoric-corr/` — polychoric / polyserial correlation spec, plan, decisions, and test spec (shipped; PRs #107, #108, #109)
- `archive/variable-direction/` — `set_higher_is()`, `set_reverse_coded()`, and `get_diffs(show_favorability)` spec, plan, and decisions (shipped; PRs #124, #125, #126)
- `archive/` — completed phase docs (specs, impl plans, decisions — all historical)
- `.claude/rules/` — code style, testing standards, R package conventions, GitHub strategy
