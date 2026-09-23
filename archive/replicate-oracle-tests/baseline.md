# Baseline — replicate-oracle-tests

**Measured**: 2026-09-22, before PR 1's builder started.
**Tree**: `e9a6c808f228388175b1b6892e7372d39e3e2fb8`
**Commit**: `7800ea9730acdcf03ae33dc24bb9a008a8920e33` (`develop`, level with `origin/develop`)
**Command**: `bash .claude/scripts/run-gates.sh <log-dir> --skip-pkgdown`
**Logs**: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/baseline/`

This is the Before column for every audit in the arc.

## Gate results

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11941 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs |
| pkgdown | SKIPPED | scope — no PR in this arc touches `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or `DESCRIPTION` |
| `covr` | PASS | 96.15% |

## The four figures an audit compares against

| Figure | Baseline |
|---|---|
| Failures | 0 |
| Warnings | 256 |
| Skips | 4 |
| Passes | 11941 |
| Coverage | 96.15% |

Warnings read as "no new warning", not "0 warnings". The 256 are the
pre-existing AAPOR small-cell warnings of issue #167, and the plan's standing
gate 3 states the same reading.

Coverage is expected flat across the whole arc. Every PR adds test code or
documentation and no source line, so the denominator never moves.

## The two NOTEs are both pre-existing

Neither is this arc's work, and neither is new.

1. **`checking CRAN incoming feasibility`** — pre-approved in
   `.claude/rules/r-package-conventions.md`. The body reports the maintainer
   and "Version contains large components (1.1.0.9000)", which is the
   development version scheme `.claude/rules/github-strategy.md` prescribes.
2. **`checking for hidden files and directories`** — `R CMD build` finds
   `.git` and reports it. This NOTE is **not** on the pre-approved list in
   `r-package-profile.md`, and it appears on this clean baseline tree with no
   change applied. `.Rbuildignore` causes it and no PR in this arc can fix it.

The second one matters to a tester and a reviewer. `r-package-profile.md`
§Pre-approved NOTEs says any other NOTE is reviewed, and
`signals.md` §STOP lets a reviewer halt the pipeline when "a new NOTE pattern
appears that isn't in the pre-approved list". This pattern is not new. The same
NOTE was recorded on the `as-svydesign-bridge` arc, where it broke an
acceptance criterion that asked for "the two pre-approved notes only". Read
gate 5 in this arc as: **2 NOTEs, and these two.** A third NOTE blocks.
