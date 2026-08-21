# surveycore Package Development

**Part of the [surveyverse ecosystem](../survey-standards/ECOSYSTEM.md) — see there for ecosystem vision, architecture, and how surveycore relates to other packages.**

surveycore is the foundation package of the surveyverse ecosystem — a modern, tidyverse-compatible
replacement for `survey` and `srvyr`. It provides S7-based survey design objects, a
metadata/label system, and vendored variance estimation code. License: GPL-3.

---

The package API is stable. All core functionality is complete. New analysis
functions may be added but the existing structure will not change in breaking ways.
For implementation history, see `git log`, release tags (`v0.1.0`–`v1.0.0`), and `archive/` planning directories.

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

See `.claude/rules/github-strategy.md` for branching model, branch naming, and Conventional Commits format. See `.claude/rules/r-package-conventions.md` for `devtools::document()` and `devtools::check()` cadence.

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
- `archive/` — completed phase docs, one directory per shipped feature (spec, impl plan, decisions); `ls archive/` lists them and `git log` has the PR numbers
- `.claude/rules/` — code style, testing standards, R package conventions, GitHub strategy
- `.claude/references/` — worked examples and rationale moved out of `.claude/rules/`; read when a rule's application is unclear
