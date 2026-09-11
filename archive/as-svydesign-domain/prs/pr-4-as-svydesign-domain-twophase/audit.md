# Audit — PR 4 — as-svydesign-domain-twophase

**Verdict**: PASS
**Date**: 2026-09-11

Tree: `4889ae06f8dc60db7e376aa7cc122fcd180467f5`

## History

- First audit (tree `d9d7a16940b93893e31be43eb1647e0320e6ce38`): **BLOCK**
  (contract-miss) — rows C-3, D-2c, D-5b wrapped the conversion in a bare
  `suppressWarnings()` and never captured or inspected the conditions the
  call signalled, so the row-required "no condition beyond the pre-existing
  one" / "no surveycore condition" claim was unverified.
- Fix commit `9daf70e` (test file only, 52 insertions / 35 deletions):
  hoists a `collect_surveycore_classes(expr)` helper to the top of the
  two-phase section (~line 3826) and swaps the bare `suppressWarnings()` in
  C-3, D-2c and D-5b for `classes <- collect_surveycore_classes(sv <-
  as_svydesign(d)); expect_identical(classes, character(0L))`. G-1c's
  previously block-local `collect()` closure is replaced by a call to the
  same shared helper — same assertion, no behavior change. Every
  pre-existing assertion in all four blocks is otherwise untouched.
- This audit re-checks C-3, D-2c, D-5b and G-1c against the new tree,
  confirms the other seven rows and the invariants requirement are
  unaffected, and re-verifies scope and gates. **PASS.**

## Scope confirmation

`git diff origin/develop...9daf70e --stat`: `R/methods-conversion.R` (21
lines, unchanged since the first audit) and `tests/testthat/test-conversion.R`
(319 lines added net across both commits). Only these two files — confirmed
against `origin/develop`, not the stale local `develop` ref.
`git diff origin/develop...9daf70e -- tests/testthat/_snaps` is empty — no
snapshot added or changed, in either commit.
`git diff 0e15135 9daf70e -- tests/testthat/test-conversion.R` shows the fix
is confined to: the new `collect_surveycore_classes()` helper definition,
the three condition-capture swaps in C-3/D-2c/D-5b, and the G-1c block's
refactor to call the shared helper instead of its own local one. No other
line in the file changed.
`grep -c "test_invariants("`: 7 on this branch vs 6 on `origin/develop` —
still exactly one new call, unchanged from the first audit, at the B-1
block, for `as_survey_twophase()`.
`grep -n "expect_no_condition"` under the two-phase section: two hits, both
inside comments (lines 50 and 306 of the section) — no block uses
`expect_no_condition()` on this route, per the test-spec's explicit
prohibition for G-1c.

## Per-Test Result Table

Fresh `Rscript`/`devtools::load_all()` reproduction of every numeric and
condition-bearing row on the new tree (script retained in session
scratchpad `verify_pr4_fix.R`, plus the unchanged numerics from
`verify_pr4.R`/`verify_pr4b.R` since those blocks did not change).

| Test (row) | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| B-1 point | 57.18965 (sv) vs 57.18965 (hand) — diff 0 | equal | 1e-10 | ✓ |
| B-1 SE | 1.585101 vs 1.585101 — diff 0 | equal | 1e-8 | ✓ |
| B-1 `test_invariants(d)` present once | called once, for `as_survey_twophase()` | one call | exact | ✓ |
| B-2 `get_means()` vs by-hand phase-1-weight mean | 48.9245 vs 48.9245 | equal | 1e-10 | ✓ |
| B-2 `svymean()` vs by-hand reciprocal-probability mean | 49.20304 vs 49.20304 | equal | 1e-10 | ✓ |
| B-2 the two hand values differ | 48.9245 vs 49.20304 | must differ | — | ✓ |
| B-3 finite-probability count (no row-count assertion) | 14 | `sum(marker & subset)` = 14 | exact | ✓ |
| B-4 no error / class / finite-probability count | no error; `class = c("twophase2","survey.design")`; finite 14 = marked 14 | no error, two-phase object | — | ✓ |
| C-3 row counts / marker absence / all-finite / **no surveycore condition** | full 60=60, sample 29=29, marker absent, all finite TRUE, `collect_surveycore_classes()` → `character(0L)` | one row per design row, no marker, no condition beyond the shape's own | — | ✓ (was ✗) |
| D-2c row count unchanged / no finite / `is.nan` / **no surveycore condition** | sample 29=29 unchanged, no finite, `is.nan` TRUE, classes `character(0L)` | unchanged row count, no finite prob, `is.nan`, no surveycore condition | — | ✓ (was ✗) |
| D-5b row count unchanged / no finite / `is.nan` / **no surveycore condition** | sample 29=29 unchanged, no finite, `is.nan` TRUE, classes `character(0L)` | same as D-2c | — | ✓ (was ✗) |
| D-7 Taylor companion | marker present, all TRUE | presence, all TRUE | exact | ✓ |
| D-7 two-phase | marker present in phase-1 sample frame; values identical to `df[[col]][df$subset]`; not all TRUE; some TRUE | presence; mixed values preserved | exact | ✓ |
| F-6 row count / marker identity after round trip | rebuilt nrow 60 = original 60; marker vector `identical()` TRUE | row count and marker preserved | exact | ✓ |
| G-1c no `surveycore_`-classed condition | classes `character(0L)` via shared helper; no `expect_no_condition()` anywhere in the section | assert absence of `^surveycore_` class only | — | ✓ |

All four rows that use `collect_surveycore_classes()` (C-3, D-2c, D-5b, G-1c)
independently reproduce `character(0L)` on a fresh load — confirmed by
directly re-running the collector against each fixture outside the test
harness (`verify_pr4_fix_out.txt`). The BLOCK's root cause — a missing,
verifiable "no surveycore condition" assertion — is now closed identically
to G-1c's original technique, generalized into one shared helper (DRY,
consistent with `engineering-preferences.md` §1).

## Before/After Comparison

| Metric | Before PR (develop `9625c18`) | After PR (tree `4889ae0`) | Δ |
|---|---|---|---|
| tests passing | 11749 | 11800 | +51 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.25% | 96.25% | 0 |
| R CMD check NOTEs | 2 | 2 | 0 |

No regression in tests-passing or coverage. One `R/` file changed against
`origin/develop` (`R/methods-conversion.R`, 99.77% covered); its one
uncovered line (586) is the pre-existing `# nocov` branch this PR does not
touch.

## Profile gates

Gates were run by the orchestrator (full runner, all seven gates, one call,
no watchdog kill this time) on tree `4889ae0`. This audit accepts the
printed summary and does not re-run them.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | [ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11800 ] |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | ./surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran | PASS | Status: 2 NOTEs — CRAN incoming feasibility (pre-approved); hidden files `.git` (pre-existing) |
| pkgdown | PASS | site built |
| covr | PASS | 96.25%; one R/ file changed against origin/develop (`R/methods-conversion.R` at 99.77%); its one uncovered line (586) is the pre-existing `# nocov` branch |

Tree: `4889ae06f8dc60db7e376aa7cc122fcd180467f5`

Logs: `.surveycore-workspace/runs/2026-09-09-as-svydesign-domain/logs/pr-4-fix/`
— not read; no gate failed.

## CRAN cookbook violations

None. `R/methods-conversion.R` is unchanged since the first audit (21 lines:
a class-conditional frame lookup, a `converted <-` capture of
`survey::twophase()`'s return, and a `.restrict_to_domain(converted)` call).
No `T`/`F` abbreviation, no hardcoded `set.seed()`, no bare `print()`/
`cat()`, no `options(warn=-1)`, no `installed.packages()`, no `<<-` outside
the test helper's own `withCallingHandlers` closure (a test file, not `R/`,
and `<<-` there assigns into the closure's own `seen` list, not a global —
out of cookbook scope, which scans `R/` only), no unrestored `par()`/
`options()`/`setwd()`, no home-directory writes, no `mc.cores`/
`makeCluster` above 2.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | None | — |

## Tolerance integrity

Every numeric comparison audited (B-1 point/SE, B-2's two hand computations)
uses exactly the test-spec's tolerances: point 1e-10, SE 1e-8. No tolerance
was loosened or changed by the fix commit — it touched only condition
assertions, not numerics.

## Verdict

**PASS.** All ten claimed rows (B-1, B-2, B-3, B-4, C-3, D-2c, D-5b, D-7,
F-6, G-1c) and the invariants requirement are fully asserted and
numerically/structurally verified on tree `4889ae0`. The fix commit closes
the sole BLOCK from the first audit — C-3, D-2c and D-5b now use the shared
`collect_surveycore_classes()` helper to assert `character(0L)` in place of
a bare `suppressWarnings()`, matching the technique G-1c already used and
verifying the "no surveycore condition" claim the test-spec names for each
of them. No snapshot added. Scope confirmed against `origin/develop`: two
write-surface files only. No CRAN cookbook violations. No before/after
regression. All seven profile gates pass on a full, unkilled run.
