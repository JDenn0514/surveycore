# Baseline — `pipeline-ship` Step 0

**Measured:** 2026-09-08
**Tree:** `f19d2de2ddcc380e34a34f6935dd7b95ce1f6056`
**Commit:** `df3a481` — `develop`, up to date with `origin/develop`
**Command:** `bash .claude/scripts/run-gates.sh .surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/baseline`
**Result:** ALL GATES PASS (exit 0)

| Gate | Result | Before value |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift |
| `devtools::test()` | PASS | `FAIL 0 | WARN 256 | SKIP 4 | PASS 10872` |
| `devtools::run_examples()` | PASS | every example ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | 2 NOTEs |
| `pkgdown::build_site()` | PASS | site built |
| `covr::package_coverage()` | PASS | **96.19%** |

## The two NOTEs — both pre-existing, neither blocks

| NOTE | Standing |
|---|---|
| `checking CRAN incoming feasibility` — maintainer, and "Version contains large components (1.1.0.9000)" | Pre-approved in `r-package-conventions.md`. The package is not on CRAN, and `.9000` is the development version the branching model requires |
| `checking for hidden files and directories` — found `.git` | A local artifact of checking in the source tree. Present on a clean `develop`, so it is part of the baseline, not something a pull request introduced |

A third NOTE, of any pattern, is a new NOTE and blocks.

## Before column for every audit

| Measure | Before |
|---|---|
| Test failures | 0 |
| Test warnings | 256 — all the AAPOR small-cell warning; see D12 |
| Tests skipped | 4 |
| Tests passing | 10872 |
| Package line coverage | 96.19% |
| `R CMD check` NOTEs | 2, both named above |
