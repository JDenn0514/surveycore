# Audit — PR 7 fay-rho-oracle

**Verdict**: PASS
**Branch**: `test/fay-rho-oracle`, HEAD `ad1350f`
**Base**: `develop` `dbe8b93` (tree `4395827`)
**Tree**: 872352e946030db0cb0e8021db2fbd6a8dab046d
**survey**: 4.5

## Profile gates

The orchestrator ran the gates on tree 872352e. The tester did not re-run
them (low memory). Logs: `prs/pr-7-fay-rho-oracle/gates/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12350 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | 0 errors, 0 warnings, 2 NOTEs |
| pkgdown | PASS | site built |
| covr (NOT_CRAN=true) | PASS | 96.16% |
| air format --check (changed .R files) | PASS | exit 0 on `test-variance-replicate.R` |

Tree: 872352e946030db0cb0e8021db2fbd6a8dab046d

NOTEs:

| NOTE | Status |
|---|---|
| checking CRAN incoming feasibility | pre-approved |
| hidden files and directories: `.git` | pre-existing; named as allowed in criterion G item 4 |

Tester foreground run: `devtools::test(filter = "variance-replicate")`
with `NOT_CRAN=true` passed with 0 failures. Its one warning is the
pre-existing AAPOR warning at line 798, outside the diff.

## Per-test result table

Measured on fixture FA (R = 10). "Got" is the surveycore value; "Expected"
is the live `survey` value or the literal. Max |diff| is shown where both
sides are floats.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 2.1 mean, rho 0.3 mse TRUE | |diff| 0 | svymean | 1e-10 | ✓ |
| 2.1 SE | 0.0680326680312 | 0.0680326680311 (|diff| 1.2e-14) | 1e-8 | ✓ |
| 2.1 ci_low / ci_high | |diff| 2.1e-14 | confint | 1e-6 | ✓ |
| 2.1 scale, each side | 0.204081632653 / 0.204081632653 | 1 / (10 * 0.7^2) | 1e-8 | ✓ |
| 2.2 rho 0: mean / SE / bounds | 0 / 8.0e-15 / 1.4e-14 | svymean | 1e-10 / 1e-8 / 1e-6 | ✓ |
| 2.2 scale, each side | 0.1 / 0.1 | 1 / 10 | 1e-8 | ✓ |
| 2.3 rho 0.5: mean / SE / bounds | 0 / 1.6e-14 / 3.6e-14 | svymean | 1e-10 / 1e-8 / 1e-6 | ✓ |
| 2.3 scale, each side | 0.4 / 0.4 | 1 / (10 * 0.5^2) | 1e-8 | ✓ |
| 2.4 rho 0.9: mean / SE / bounds | 0 / 8.0e-14 / 1.6e-13 | svymean | 1e-10 / 1e-8 / 1e-6 | ✓ |
| 2.4 scale, each side | 10 / 10 | 1 / (10 * 0.1^2) | 1e-8 | ✓ |
| 2.5 rho 0.3 mse FALSE: mean / SE / bounds | 0 / 1.1e-14 / 2.1e-14 | svymean | 1e-10 / 1e-8 / 1e-6 | ✓ |
| 2.5 scale, each side | 0.204081632653 | 1 / (10 * 0.7^2) | 1e-8 | ✓ |
| 2.6 total | 119422.367149 | 119422.367149 | 1e-10 | ✓ |
| 2.6 SE / bounds | 1909.05297894 / |diff| 1.5e-11 | svytotal, confint | 1e-8 / 1e-6 | ✓ |
| 2.6 scale, each side | 0.204081632653 | 1 / (10 * 0.7^2) | 1e-8 | ✓ |
| 2.7 svyby, 3 groups matched by level: mean / SE / bounds | max 0 / 1.6e-14 / 2.8e-14 | svyby | 1e-10 / 1e-8 / 1e-6 | ✓ |
| 2.7 scale, each side | 0.204081632653 | 1 / (10 * 0.7^2) | 1e-8 | ✓ |
| 2.1–2.7 no warning, both constructors | none | none | n/a | ✓ |
| 2.8 Fay rho 0 SE vs BRR SE | 0.0476228676218 | 0.0476228676218 | 1e-8 | ✓ |
| 2.8 scales | 0.1 / 0.1 | 1 / 10 | 1e-8 | ✓ |
| 2.9 SE ratio Fay 0.5 / BRR | 2 | 2 | 1e-8 | ✓ |
| 2.9 means | |diff| 0 | equal | 1e-10 | ✓ |
| 2.10 SE ratio, rscales rep(2, 10) | 1.41421356237 | sqrt(2) | 1e-8 | ✓ |
| 2.11 all-NA y1, Fay vs BRR | both return; NA positions in mean and se identical; n identical | same outcome | exact | ✓ |
| 6.12 `git diff dbe8b93...HEAD -- R/` | empty; `HEAD:R` = `dbe8b93:R` = cfa0dbed | empty | exact | ✓ |
| Survey refusal kept, matched by text | "With type='Fay' you must supply the correct rho" | text match | exact | ✓ |

Tolerances set in the code, from `getParseData()` over every
`expect_equal()` in a Fay-titled block: 8 at 1e-10 (means, total), 26 at
1e-8 (SE, stored scale, two SE ratios), 14 at 1e-6 (bounds). Every value
equals the test-spec value. No tolerance is relaxed. No `expect_equal()` in
these blocks uses the default tolerance.

## Oracle discipline

| Check | Result |
|---|---|
| Same frame, weight column, replicate columns on both sides | ✓ `make_fay_oracle_pair()` builds FA once and gives `d$wt` and `d[, repwt_cols]` to survey, `wt` and the same columns to surveycore |
| `mse` explicit on both sides | ✓ the helper's `mse` argument goes to both calls |
| `scale` passed to neither side | ✓ no `scale =` in any new block; the 4 `scale =` argument names in the file are all pre-existing |
| `rho` the same literal on both sides | ✓ each block calls the helper with a literal; the helper passes that argument to both |
| No surveycore number passed to survey | ✓ the `svrepdesign()` call reads only `d`, `repwt_cols`, `rho`, `mse` |
| Both constructors inside `expect_no_warning()` | ✓ |
| Stored scale against the literal, each side alone | ✓ `pair$sc@variables$scale` and `pair$sv$scale` each against `1 / (10 * (1 - rho)^2)`; no side-against-side assertion |
| survey conditions matched by text, not suppressed | ✓ 0 `suppressWarnings()` calls in the file |
| DoF precondition comment | ✓ lines 1018–1024 |
| "compares nothing" comment removed | ✓ no match in the file |
| No new `test_invariants()` | ✓ 1 call on develop, 1 on the branch |

Construct counts (`utils::getParseData()`, SYMBOL_FUNCTION_CALL):

| Construct | develop dbe8b93 | branch | Δ |
|---|---|---|---|
| `svrepdesign` | 16 | 17 | +1 (the helper) |
| `expect_no_warning` | 12 | 14 | +2 (the helper) |
| `suppressWarnings` | 0 | 0 | 0 |
| `test_invariants` | 1 | 1 | 0 |
| `expect_failure` | 0 | 0 | 0 |
| `test_that` | 30 | 41 | +11 |
| `make_fay_oracle_pair` | 0 | 7 | +7 (1 definition is not a call; 7 calls) |

The builder's `svrepdesign` count (16, then 17) is confirmed.

Per-type table, Fay row, probed on survey 4.5: the default scale is
`1/(R * (1 - rho)^2)` (0.2040816 at rho 0.3, R 10); a supplied
`scale = 99` is discarded with no warning; a supplied `rscales` is honoured.
The table row is correct for 4.5.

## Acceptance criteria (PR 7)

| # | Result |
|---|---|
| 1 | ✓ rows 2.1–2.5 |
| 2 | ✓ row 2.6 |
| 3 | ✓ row 2.7 |
| 4 | ✓ rows 2.8, 2.9 |
| 5 | ✓ row 2.10 |
| 6 | ✓ row 2.11 |
| 7 | ✓ R/ tree hash unchanged; DoF comment present; no "compares nothing" |
| 8 (G) | ✓ items 1–7 per gate table; item 8: no `_snaps/` change; item 9: the diff lists only `tests/testthat/test-variance-replicate.R`, the one file in Files touched |

## CRAN cookbook violations

None. The PR modifies no file under `R/`.

## Before/After comparison

| Metric | Before PR (dbe8b93) | After PR (872352e) | Δ |
|---|---|---|---|
| tests passing | 12284 | 12350 | +66 |
| test failures | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.16% | 96.16% | 0 |
| R CMD check NOTEs | 2 | 2 | 0 |

## Signals

No HOLD. No BLOCK.
