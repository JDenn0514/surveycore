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
- `archive/dataset-level-metadata/` — dataset-level metadata: the `@dataset_metadata` property, twelve exported setters and extractors, construction promotion, and print/summary output (shipped; PRs #162, #163, #164, #166, #168, #170, #171)
- `archive/polychoric-performance/` — polychoric speed fix: vectorised CDF grid, lean refit mode, delta refit setup; 30x on the issue #177 benchmark, bit-identical results (shipped; PR #181)
- `archive/var-extension-slot/` — per-variable extension slot: the `var_extra` property on `survey_metadata`, `set_var_extra()`/`extract_var_extra()`, and rename/delete lifecycle wiring (shipped; PR #185)
- `archive/test-suite-simplification/` — test suite simplification: the `_snaps/` line-ending rule, `test_invariants()` narrowed to one call per constructor per file (645 calls → 70), and the two-speed local test workflow; its polychoric investigation became issue #177 and shipped separately as PR #181 (shipped; issues #161, #169). Read the ARCHIVED block at the top first: the checkboxes were never marked, one task was deliberately dropped, and every measurement in the file predates #181
- `archive/haven-labelled/` — `haven_labelled` handling: designs strip the class on every `@data` write and on entry to all four constructors, `survey_data(haven_class = TRUE)` rebuilds it, the `survey`-package conversion routes capture metadata, `set_val_labels()` accepts a labelled column, and polychoric accepts whole-valued doubles (shipped; PRs #186–#204). Read `decisions-haven-labelled.md` first: it records seven SETTLED decisions, D1 to D7, and three of them resolve a HOLD. The planning documents were corrected nine times against measurement during the build. Nine documents the decisions cite are not in the repository — the pipeline archived no measurement artifacts until issue #217. Every citation of them carries `[not archived]`, and each affected file lists them below its title
- `archive/svydesign-replicate-bridge/` — the two replicate conversion routes in `R/methods-conversion.R`: `from_svydesign()` now expands survey's compressed replicate matrix, generates column names when survey supplies none, writes one column per replicate on every conversion, folds the base weight into a factor-form matrix, and refuses four unusable sources; `as_svydesign()` drops the FPC with a typed warning, refuses a design naming no replicate column, and recovers Fay's shrinkage factor from the recorded scale (shipped; issues #197, #198; PRs #239, #241, #247, #249, #250). Read `decisions-svydesign-replicate-bridge.md` first: it holds 19 decisions, D11 to D19 all recorded during the build rather than the planning. Four matter to anyone reading the gates. D12: gate 2's "0 warnings" is unmeetable — clean `develop` carries 256 pre-existing AAPOR small-cell warnings, so the gate reads as "no new warning". D16: gate 9 cannot run as written — `air` is a CLI here, not an R package, and 24 files repo-wide are already not air-clean, so the gate reads as "the PR's own files pass `air format --check`". D17: `spec.md` §V.2 carried a `{qty()}` erratum that would have made a typed-condition test impossible to pass; the spec copy here is corrected and says so under §Errata applied at archive time. D11: test-spec row ids were stripped from every builder task list, so no test block is named after a row
- `archive/as-svydesign-bridge/` — `as_svydesign()` and `as_tbl_svy()` accept a `survey_nonprob` design: a fourth dispatch branch routes on the shape of the weights, sending a design that names replicate weights to the replicate helper and one that names none to the Taylor helper behind the new warning `surveycore_warning_nonprob_srs_conversion`; `as_tbl_svy()` gained the input class with no body edit, because its guard already tested `survey_base` (shipped; issue #237; PR #259). Read `decisions-as-svydesign-bridge.md` first, then §Out of the spec — that section is unusually load-bearing, because D-9 narrowed this work from two issues to one and moved the replicate FPC to the neighbouring arc. Four things a later reader needs. **The spec names four deferred issues, none of them a defect in this PR:** #245 the dropped domain restriction, #246 the consolidation of eight in-place copies of the nonprob routing predicate, #248 a class validator weaker than the constructor that feeds it, and #251 two documentation corrections that had to wait for the warning they describe. **Two planner errata survive in the plan and test-spec:** both write `ncol(survey::weights(converted, "analysis"))`, which cannot run — `survey` registers a method for the base `weights` generic and exports no function of that name — so the shipped block uses `stats::weights()`; and AC-6 asks for "the two pre-approved notes only" where the run has one pre-approved note plus a pre-existing `.git` hidden-file note that `.Rbuildignore` causes and this PR cannot fix. **The coverage Before column is empty:** both baseline attempts were killed by a low-memory watchdog at 2.06 GB free, so judge the 95% floor, which the measured 96.24% clears, and not a delta. **The merge took three CI cycles and none of them failed:** branch protection requires an up-to-date head branch, repository auto-merge is refused, and two other sessions merged into `develop` meanwhile — see `prs/pr-1-as-svydesign-bridge/shipper.md`, which records that updating the branch before opening the PR would have cost one cycle instead of three
- `.claude/rules/` — code style, testing standards, R package conventions, GitHub strategy
- `.claude/references/` — worked examples and rationale moved out of `.claude/rules/`; read when a rule's application is unclear
