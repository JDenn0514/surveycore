# surveycore Package Development

**Part of the [surveyverse
ecosystem](https://jdenn0514.github.io/survey-standards/ECOSYSTEM.md) —
see there for ecosystem vision, architecture, and how surveycore relates
to other packages.**

surveycore is the foundation package of the surveyverse ecosystem — a
modern, tidyverse-compatible replacement for `survey` and `srvyr`. It
provides S7-based survey design objects, a metadata/label system, and
vendored variance estimation code. License: GPL-3.

------------------------------------------------------------------------

The package API is stable. All core functionality is complete. New
analysis functions may be added but the existing structure will not
change in breaking ways. For implementation history, see `git log`,
release tags (`v0.1.0`–`v1.0.0`), and `archive/` planning directories.

------------------------------------------------------------------------

## Class Naming Conventions

- S7 classes: `survey_base`, `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_metadata`, `survey_nonprob`
- GLM fit class: `survey_glm_fit` (constructor function is
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md))
- Result classes: `survey_mean`, `survey_total`, `survey_freq`, etc. (S3
  built on tibble)

## Naming Conventions

- Analysis functions:
  [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
  [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
  [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
  [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
  [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
  [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
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
- Metadata setters (plural): `set_variable_labels()`,
  `set_value_labels()`, `set_question_prefaces()`,
  `set_variable_notes()`
- Internal helpers: prefix with `.` (e.g., `.extract_haven_labels()`)

## Key Implementation Rules

**Design variables are sacred** — never remove or silently rename design
variables. Always warn when weight column is modified.

**Metadata lifecycle** — auto-delete metadata on `select()` removal;
auto-rename on `rename()`; track transformation history in
`@metadata@transformations`.

**Domain estimation vs physical subsetting** —
[`filter()`](https://rdrr.io/r/stats/filter.html) keeps all rows and
marks domain membership;
[`subset()`](https://rdrr.io/r/base/subset.html) removes rows and issues
a strong warning.

**Internal weight column name** — use `"..surveycore_wt.."` when
converting probs to weights internally (avoids collision with user
columns named `.weights`).

## Workflow Requirements

- Every non-trivial change lives on a feature branch — never commit
  implementation code to `main`

See `.claude/rules/github-strategy.md` for branching model, branch
naming, and Conventional Commits format. See
`.claude/rules/r-package-conventions.md` for `devtools::document()` and
`devtools::check()` cadence.

## Git Workflow

- When asked to commit and create a PR, always target the `develop`
  branch unless explicitly told otherwise. Never assume `main` is the
  target.
- When the user asks for a simple git push, just push. Do not invoke the
  full commit/PR skill workflow unless explicitly requested.

## CI / Package Development

- For R package CI (pkgdown, R CMD check): always guard vignette chunks
  that depend on optional/in-development packages with
  `eval = requireNamespace("pkg", quietly = TRUE)`. Test locally before
  pushing.

## R Package Conventions

- Use the GSS dataset (not NHANES or gss_2024) for examples and tests
  unless told otherwise. Use rlang patterns over deparse().
- All R code written in any context — `.R` source files, roxygen2
  `@examples` blocks, and ```` ```r ``` ```` blocks in `.md` spec and
  plan documents — must follow the rules in
  `.claude/rules/code-style.md`.

## General Behavior

- Before reading many files, check if the user’s question can be
  answered from context already available. Prefer concise answers over
  exhaustive file exploration.

## Project Structure

- Skills are located in `.claude/skills/` (e.g.,
  `.claude/skills/spec-workflow/`). Always check there first when
  referencing or modifying skills.

## R CMD Check Gotchas

**Examples must load Imports packages explicitly.** R CMD check runs
examples in a fresh session with only
[`library(surveycore)`](https://github.com/JDenn0514/surveycore) loaded.
If an example calls a bare function from an Imports package, add
[`library(pkg)`](https://rdrr.io/r/base/library.html) at the top of the
block. In practice surveycore examples only call its own exported API,
so this rarely bites — but keep it in mind.

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names and
  CLI message templates
- `archive/get-t-test-pairwise/` — spec, plan, and decisions for
  [`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md) +
  [`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md)
  (shipped; PR \#88)
- `archive/sata-metadata/` — SATA metadata spec, plan, and decisions
  (shipped; PRs \#89–#92)
- `archive/get-anova/` — design-based ANOVA spec, plan, and decisions
  (shipped; PRs \#93, \#94, \#95)
- `archive/get-anova-polymorphic/` — polymorphic `object` dispatch for
  [`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md)
  (shipped; PR \#96)
- `archive/survey-collection/` — `survey_collection` container +
  `get_*()` dispatch spec, plan, and decisions (shipped; PRs \#97, \#98)
- `archive/get-covariance/` —
  [`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md)
  spec, plan, decisions, and test spec (shipped; PR \#105)
- `archive/collection-uniform-groups/` — uniform `@groups` enforcement
  across `survey_collection` (shipped; PR \#106)
- `archive/polychoric-corr/` — polychoric / polyserial correlation spec,
  plan, decisions, and test spec (shipped; PRs \#107, \#108, \#109)
- `archive/variable-direction/` —
  [`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md),
  [`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md),
  and `get_diffs(show_favorability)` spec, plan, and decisions (shipped;
  PRs \#124, \#125, \#126)
- `archive/nonprob-bootstrap-variance/` — non-probability bootstrap
  variance spec, impl plans, and decisions (shipped; PRs \#127, \#130,
  \#131)
- `archive/nonprob-jackknife/` — non-probability jackknife variance
  spec, impl plan, comprehension, MI reviews, and decisions (shipped;
  PRs \#133–#136)
- `archive/corr-nonprob-latent/` — polychoric/polyserial on
  `survey_nonprob` with repweights: spec, impl plan, test spec, plan
  review (shipped; PR \#137)
- `archive/glm-nonprob-replicate/` —
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  nonprob replicate routing: spec, test spec, impl plan, plan review
  (shipped; PR \#138)
- `archive/calibrate-survey-taylor/` — calibration-adjusted variance
  ([`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
  GREG SE correction): spec, test spec, impl plan, comprehension, plan
  review, decisions (shipped; PRs \#139, \#140)
- `archive/surveywts-calibration/` — `calibration =` constructor
  validation (CAL-15, CAL-16) and raking oracle update: spec, test-spec,
  impl plan, comprehension, decisions, plan review (shipped; PRs \#141,
  \#142)
- `archive/doc-fixes/` — documentation corrections (D1–D75, W1–W3,
  S1–S7, T1–T5, M1–M4, X1–X13) across 40+ R files: spec, test-spec, impl
  plan, plan review, decisions (shipped; PRs \#143, \#144)
- `archive/coef-vcov-methods/` —
  [`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md)
  generic and `coef`/`vcov`/`SE`/`confint` methods for `survey_result`:
  spec, test-spec, impl plan, plan review, decisions (shipped; PRs
  \#148, \#149, \#150)
- `archive/` — completed phase docs (specs, impl plans, decisions — all
  historical)
- `.claude/rules/` — code style, testing standards, R package
  conventions, GitHub strategy
