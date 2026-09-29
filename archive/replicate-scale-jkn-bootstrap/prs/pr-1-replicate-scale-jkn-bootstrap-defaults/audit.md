# Audit — PR 1 — replicate-scale-jkn-bootstrap-defaults

> **On the `[no such file]` marker below.** The test-spec it cites sat in the
> plans directory while the arc was in flight. Archiving moved it in beside
> this file, under the same name, so the path in the citation no longer
> resolves although the document is right here. The marker is the closer of
> the two the citation checker accepts; neither can say "archived under a
> different path". Nothing was lost.

**Verdict**: PASS
**Date**: 2026-09-29 09:22

Branch `fix/replicate-scale-jkn-bootstrap-defaults`, HEAD `e8f10de`.

Rows audited: §2 rows 2.1 and 2.2, §4 rows 4.1, 4.3 and 4.4. No other row of
`plans/test-spec-replicate-scale-jkn-bootstrap.md` [no such file] belongs to this PR.

**Method.** The gates were run in the foreground by the orchestrator on tree
`24f9594`, and this audit ran no gate and started no R process. The numerical
verdicts on rows 2.1 and 2.2 come from gate 2, which reports `FAIL 0` with the
two oracle blocks running and not skipped — the four skips in that run are in
`test-glm-anova-numerical.R`, `test-glm-anova.R` and `test-srr-compliance.R`.
The structural verdicts come from reading the blocks and the diff.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 2.1 JKn — 20 replicate columns, `mse = TRUE` on both sides | 20 columns from `make_survey_data(n_psu = 20, type = "jkn")`, `mse = TRUE` written on both sides | same frame, same columns, `mse` explicit on both | n/a | ✓ |
| 2.1 JKn — `rscales` literal written once per side, read off no design | `rep(1, n_rep)` in the `as_survey_replicate()` call and again in the `svrepdesign()` call | same literal twice | n/a | ✓ |
| 2.1 JKn — no `scale` to either side | neither call names `scale` | absent on both sides | n/a | ✓ |
| 2.1 JKn — `survey`'s stored scale | `expect_equal(sv$scale, 1, tolerance = 1e-8)` passes | `1` | 1e-8 | ✓ |
| 2.1 JKn — point estimate vs `survey::svymean()` | assertion passes (gate 2, FAIL 0) | agreement | 1e-10 | ✓ |
| 2.1 JKn — standard error vs `survey::SE()` | assertion passes, unwrapped | agreement | 1e-8 | ✓ |
| 2.1 JKn — both confidence bounds vs `confint()` | both assertions pass, unwrapped | agreement | 1e-6 | ✓ |
| 2.1 JKn — `expect_no_warning()` round `svrepdesign()` | present, and passes | present | n/a | ✓ |
| 2.2 bootstrap — 20 replicate columns, `mse = TRUE` on both sides | 20 columns from `make_survey_data(type = "bootstrap")`, `mse = TRUE` on both | same | n/a | ✓ |
| 2.2 bootstrap — no `rscales` and no `scale` to either side | neither argument appears in either call | both absent | n/a | ✓ |
| 2.2 bootstrap — `survey`'s stored scale | `expect_equal(sv$scale, 1 / (n_rep - 1), tolerance = 1e-8)` passes | `1 / (n_rep - 1)` | 1e-8 | ✓ |
| 2.2 bootstrap — point estimate | assertion passes | agreement | 1e-10 | ✓ |
| 2.2 bootstrap — standard error | assertion passes, unwrapped | agreement | 1e-8 | ✓ |
| 2.2 bootstrap — both confidence bounds | both assertions pass, unwrapped | agreement | 1e-6 | ✓ |
| 2.2 bootstrap — `expect_no_warning()` round `svrepdesign()` | present, and passes | present | n/a | ✓ |
| 4.1 fact 1 — JKn default is `1` | "`1` for `"JKn"`, `"JK2"` and `"other"`" | present | n/a | ✓ |
| 4.1 fact 2 — bootstrap default is `1/(R-1)` | "`1/(R-1)` for `"bootstrap"`" | present | n/a | ✓ |
| 4.1 fact 3 — three clauses: factor in `rscales`; `rscales = NULL` means no factor; factor is `(n_h - 1) / n_h` under with-replacement or a negligible fraction | all three present in the `"JKn"` paragraph | three of three | n/a | ✓ |
| 4.1 fact 4 — one replicate column gives an infinite scale, and `survey` does the same | "gives `scale = Inf`, and `survey::svrepdesign()` stores `Inf` for the same input" | both elements | n/a | ✓ |
| 4.1 fact 5 — no `bootstrap.average`; imported scale preserved in both directions | both elements present; the page does **not** claim a `bootstrap.average != 1` design cannot round-trip | two of two, and no false claim | n/a | ✓ |
| 4.1 fact 6 — explicit `scale` reproduces the pre-change numbers | "`scale = (R - 1) / R` for `"JKn"` and `scale = 1 / R` for `"bootstrap"`" | present | n/a | ✓ |
| 4.1 fact 7 — corrected entry, symbol key, provenance | entry `(n_h - 1) * (1 - n_h / N_h) / n_h`; key makes both `n_h` and `N_h` counts of PSUs; "The caller supplies `N_h` from their own sampling frame"; `rscales` named the only route | three of three, both symbols PSU counts | n/a | ✓ |
| 4.1 fact 8 — other constructor's name, its value `1/R`, decision clause with pointer | all three present; no factor and no percentage rendered there | three of three, no second copy of the percentage | n/a | ✓ |
| 4.1 observable — `rscales` text points at `scale`, carries no formula | "the `scale` argument gives the entry to build here"; no formula | present | n/a | ✓ |
| 4.1 observable — `fpc` text: no effect for a replicate design, correction goes in `rscales`, pointer to `scale`, no formula | all four clauses present | present | n/a | ✓ |
| 4.3 — no `expect_failure()` call in either block | zero calls in the whole file; the only two textual hits are prose inside comments at lines 812 and 869 | zero calls | n/a | ✓ |
| 4.3 — no standard-error ratio against `sqrt((n_rep - 1) / n_rep)` in either block | zero; both ratio assertions deleted | zero | n/a | ✓ |
| 4.3 — the three formerly wrapped assertions present and passing unwrapped, per block | six assertions, three per block, all unwrapped and green | six | n/a | ✓ |
| 4.3 — neither title nor opening comment says the two sides disagree | titles read "SE matches survey::svymean()"; both opening comments state agreement, and name the old value only in the past tense | no claim of disagreement | n/a | ✓ |
| 4.4 — exactly one pre-existing block asserted `1 / n_rep` as the bootstrap stored default, retargeted | one, `test-constructors.R:676`; body moved to `1 / (n_rep - 1)` and the title with it | one, retargeted | n/a | ✓ |
| 4.4 — no block asserted the JKn old value | none in the diff, and none deleted | none | n/a | ✓ |
| 4.4 — every changed line holding `1 / n_rep` or `(n_rep - 1) / n_rep` is accounted for | six lines, all accounted for (table below) | closed set | n/a | ✓ |
| 4.4 — the diff touched no other line holding either literal | none | none | n/a | ✓ |

### Row 4.4 — the closed set of changed lines

| File | Change | Account |
|---|---|---|
| `test-constructors.R` | `1 / n_rep` → `1 / (n_rep - 1)`, plus the title | the retargeted block row 4.4 names |
| `test-variance-replicate.R` | two `sqrt((n_rep - 1) / n_rep)` ratio assertions deleted | required by row 4.3 |
| `test-analysis-corr.R` | one `sqrt((n_rep - 1) / n_rep)` assertion added | authorised by erratum E-1 / E-2 |
| `test-nonprob-bootstrap-variance.R` | one `sqrt((n_rep - 1) / n_rep)` assertion added | authorised by erratum E-1 / E-2 |

Row 4.4's wording admits "the retargeted block or a new block this work adds".
Four of the six lines are neither: two are deletions inside the two oracle
blocks, which row 4.3 requires, and two are additions inside pre-existing
blocks in the two extra files. The settled errata E-1 and E-2 authorise the
second pair. Recorded as a documented deviation from the row's wording, not a
finding.

### The two extra files — the red set at the switch

The builder measured eleven failing assertions at the switch against the nine
the artifacts predict. The tree resolves all eleven:

| Failing assertion at the switch | Count | Resolution in the tree |
|---|---|---|
| `expect_failure()` wrappers turning red as the inner assertion starts to pass | 6 | deleted; the inner assertions stand unwrapped |
| Closing ratio assertions in the two oracle blocks | 2 | deleted |
| The bootstrap stored-default block | 1 | retargeted to `1 / (n_rep - 1)` |
| `test-nonprob-bootstrap-variance.R` — `expect_identical(result_np$se, result_rep$se)` | 1 | retargeted to a ratio against `sqrt((n_rep - 1) / n_rep)` at `1e-8` |
| `test-analysis-corr.R` — nonprob and replicate `ci_low` equality | 1 | retargeted to a Fisher-z half-width ratio at `1e-8` |

### `test-analysis-corr.R` — the Fisher-z assertion

Checked as the dispatch asks.

- The block states its measured numbers: `0.94868329805051332` against
  `sqrt(9 / 10) = 0.94868329805051377`, and the r-space reading
  `0.94876099` against `0.94868330`, "out by 7.8e-05". The stated r-space
  gap is arithmetically consistent with the two numbers it quotes
  (7.769e-05).
- Its tolerance is `1e-8`, the test-spec's SE/variance row. The test-spec
  maps a ratio of two standard errors to that row. No tolerance is relaxed
  anywhere in this PR: `1e-8` is tighter than the `1e-6` CI-bounds row, so
  the mapping cannot be a relaxation in either reading.
- The block names its own dependency: a comment states that the assertion
  rests on the Fisher-z construction and turns red with no scale defect
  behind it if `get_corr()` moves off z.
- The sign clause is asserted separately and first —
  `expect_gt(result_nonprob$ci_low, result_rep$ci_low)`.

## Tolerance integrity

No tolerance in any audited block departs from `test-spec.md`. Measured
against the spec's table: point estimate `1e-10`, standard error `1e-8`, CI
bounds `1e-6`, stored scale and scale ratio `1e-8`, standard-error ratio
`1e-8`. Every assertion in the two oracle blocks and in the two extra files
carries the value its estimand maps to.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12005 | 12004 | −1 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00 |
| R CMD check notes | 2 | 2 | 0 |

Baseline: `develop`, tree `915316c`, supplied in the dispatch.

The −1 in passing tests is expected and accounted for. Each oracle block lost
four expectations (three `expect_failure()` wrappers and one ratio assertion)
and gained three, for −2 across the two. The nonprob block traded one
`expect_identical()` for one `expect_equal()`, net 0, and the corr block traded
one equality for one ratio plus one `expect_gt()`, net +1. The sum is −1.

Coverage is unmoved. The one changed file under `R/` reads 96.63% with three
uncovered lines (414, 1868, 1959), all outside this PR's hunk ranges and all
pre-existing.

## Profile gates

Run by the orchestrator in the foreground on tree `24f9594`. This audit
started no gate.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing; `man/` and `NAMESPACE` committed in sync |
| devtools::test() | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12004 ]` |
| devtools::run_examples() | PASS | all examples ran |
| R CMD build | PASS | `surveycore_1.1.0.9000.tar.gz` |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs, reviewed below |
| pkgdown | PASS | site built |
| covr | PASS | 96.15%, floor 95% |
| CRAN cookbook scan | PASS | no violations |

Logs:
`.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-1/`
(`summary.md`, `gate-1-document.log` … `gate-7-covr.log`).

Tree: 24f9594dfb030b8fe70edfc4a29cd5c24de59023

### NOTE review

| NOTE | Verdict |
|---|---|
| `checking CRAN incoming feasibility` | pre-approved in `r-package-profile.md` |
| `checking for hidden files and directories` | not on the pre-approved list, reviewed and accepted: the `.git` note that `.Rbuildignore` causes, present on the baseline and unchanged, and `archive/as-svydesign-bridge/` records that no single PR can fix it |

No third NOTE appeared. The warning gate reads as "no new warning": clean
`develop` carries 256 pre-existing AAPOR small-cell warnings and this PR holds
at exactly 256.

## CRAN cookbook violations

None.

Scanned the added lines of the one changed file under `R/`
(`R/core-constructors.R`) for all nine patterns: `T`/`F` as logicals,
`set.seed()`, bare `print()`/`cat()`, `options(warn = -1)`,
`installed.packages()`, `<<-`, unrestored `par()`/`options()`/`setwd()`,
writes to `getwd()` or home, and more than two cores. Zero hits. No
`@importFrom` was added, and `DESCRIPTION` is untouched.

## Other checks

| Check | Result |
|---|---|
| `tests/testthat/_snaps/` | unchanged — `git diff --stat develop..HEAD -- tests/testthat/_snaps/` returns empty, verified independently |
| `test_invariants()` calls | unchanged — the diff of `tests/` adds and removes none, so the once-per-constructor-per-file rule holds |
| New condition classes | none added, as the test-spec expects |
| Line length, added lines | every added line in `R/` and `tests/` is 80 characters or fewer |
| `air format --check` on the six touched files | two files report "would reformat": `test-constructors.R` and `test-nonprob-bootstrap-variance.R`. Both report the same at `develop`, and every site `air` would rewrite is pre-existing code outside this PR's hunks. The formatting gate reads as "the PR's own lines pass", and they do. Informational, not a finding |
| Write surface | six files. `implementation-plan.md` gives four; the two extra test files are authorised by the settled decision in `decisions.md` and by errata E-1 and E-2. Not scope creep |

Construct counts in `tests/testthat/test-variance-replicate.R` were taken by
reading the blocks and by `grep -n` with the line context inspected, never by
`grep -c`. Both textual hits for `expect_failure` in that file are prose inside
comments; zero real calls remain.

## BLOCKs

None.

## HOLDs

None.
