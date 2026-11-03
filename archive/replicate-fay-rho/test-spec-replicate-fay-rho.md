# Test-spec — replicate-fay-rho

**Status**: DRAFT
**Date**: 2026-09-30
**Issue**: #243

This document tells the tester what to prove about the Fay shrinkage factor
`rho`. `as_survey_replicate()` gains a `rho` argument, required for
`type = "Fay"`. The Fay scale becomes `1 / (R * (1 - rho)^2)`, where `R` is
the number of replicate columns. Every `survey_replicate` design carries the
key `rho` in `@variables`: the number for Fay, `NULL` for every other type.
`as_svydesign()` passes the stored `rho` to `survey`, `from_svydesign()`
brings `survey`'s `rho` back, and `print()` and `summary()` show it.
Separately, `as_survey_twophase()` now refuses a `survey_replicate` phase 1
(§7); that part does not depend on `rho`.

## Reference oracle

- `survey::svrepdesign(type = "Fay", rho = , mse = )` with
  `survey::svymean()`, `survey::svytotal()`, `survey::svyby()`,
  `survey::SE()` and `confint()`. Recorded on `survey` 4.5 under R 4.6.1.
- `survey::as.svrepdesign(type = "Fay" | "BRR", fay.rho = )` as the source
  for the import rows.
- The oracle rule in `.claude/rules/testing-surveycore.md` governs every row
  marked **[oracle]**. For those rows:
  - Build both sides from the same frame, weight column and replicate
    columns.
  - Pass `mse` explicitly to both sides.
  - Pass `scale` to neither side.
  - Pass `rho` to both sides as the same literal.
  - Never read a number off the surveycore design and pass it to `survey`.
  - Assert the SE and both confidence bounds, not the point estimate alone.
  - Assert each side's stored scale against the literal
    `1 / (R * (1 - rho)^2)`, never against each other.
  - Assert that `survey::svrepdesign()` raises no warning. On `survey` 4.5
    it raises none for `type = "Fay"` with `rho` supplied.
- Rows marked **[round trip]** check that a conversion carries a design's own
  values across. The oracle rule does not reach them.

Before you write an oracle block, confirm the installed `survey` version.
A red oracle block on a newer `survey` can mean `survey` moved.

## Datasets

All fixtures are synthetic. `make_survey_data()` lives in the test helpers.

| Id | Build | Replicates | Use |
|---|---|---|---|
| FA | `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "fay", seed = 15)` | `R = 10` (`repwt_1` to `repwt_10`) | oracle rows, print rows, analysis rows |
| FT | `make_survey_data(n = 200, n_psu = 20, design = "replicate", type = "jkn", seed = 259)` | `R = 20` | constructor rows (the frame of the existing nine-type default block) |
| FC | the existing `make_rep_type()` fixture in `test-conversion.R` (`n = 50`, `n_psu = 10`, `n_strata = 2`, seed 430) | `R = 5` | export rows |
| FS | the existing `make_taylor_source()` frame in `test-conversion.R` through `survey::svydesign(ids = ~psu, strata = ~strata, weights = ~wt, nest = TRUE)` | `R = 8` after `as.svrepdesign()` | import rows |

Edge-case frames are built inline in the block that needs them.

Measured on FA (`survey` 4.5, R 4.6.1), for a sanity check of a new block.
These numbers are not assertion literals: every oracle row compares against
a live `survey` call.

| `rho` | `mse` | `survey` scale | `survey` SE of `y1` mean |
|---|---|---|---|
| 0 | TRUE | 0.1 | 0.0476228676217971 |
| 0.3 | TRUE | 0.204081632653061 | 0.0680326680311388 |
| 0.5 | TRUE | 0.4 | 0.0952457352435943 |
| 0.9 | TRUE | 10 | 0.476228676217972 |
| 0.3 | FALSE | 0.204081632653061 | 0.0675807327299933 |

A BRR design on FA gives SE 0.0476228676217971, the same as Fay at
`rho = 0`.

## Per-function test plan

Row ids name rows in this document only. Do not put them in test titles.

### 1. `as_survey_replicate()` — file `tests/testthat/test-constructors.R`

**Happy path**

| Row | Scenario | Assertion |
|---|---|---|
| 1.1 | FT, `type = "Fay"`, `rho = 0.3` | `@variables$rho` equals 0.3; `@variables$scale` equals `1 / (20 * (1 - 0.3)^2)`; `@variables$type` is `"Fay"` |
| 1.2 | The existing block "as_survey_replicate() stores the default scale of all nine types" | Its Fay line calls with `rho = 0.3` and expects `1 / (n_rep * (1 - 0.3)^2)`. The other eight lines do not change. The block title may change to say Fay takes `rho` |
| 1.3 | FT, each of the eight other types, no `rho` | `"rho" %in% names(d@variables)` is `TRUE` and `d@variables$rho` is identical to `NULL` |
| 1.4 | FT, `type = "Fay"`, `rho = 0.3` | `"rho" %in% names(d@variables)` is `TRUE` |
| 1.4a | The formal order | `expect_identical(names(formals(as_survey_replicate)), c("data", "weights", "repweights", "type", "rho", "scale", "rscales", "fpc", "fpctype", "mse", "calibration"))` |
| 1.4b | FT, all arguments by position: `as_survey_replicate(df, wt, starts_with("repwt_"), "Fay", 0.3)` | the fifth positional value binds to `rho`: `@variables$rho` equals 0.3 and `@variables$scale` equals `1 / (20 * (1 - 0.3)^2)` |

**Error paths** — dual pattern: `expect_error(class = )` and
`expect_snapshot(error = TRUE)`.

| Row | Scenario | Class | Snapshot |
|---|---|---|---|
| 1.5 | FT, `type = "Fay"`, no `rho` | `surveycore_error_fay_rho_missing` | yes. The message names `rho` |
| 1.6 | FT, `type = "Fay"`, `rho = NULL` passed explicitly | `surveycore_error_fay_rho_missing` | no |
| 1.7 | FT, `type = "Fay"`, `rho = 1.5` | `surveycore_error_fay_rho_invalid` | yes |
| 1.8 | FT, `type = "Fay"`, `rho = "0.5"` | `surveycore_error_fay_rho_invalid` | yes. The message shows the class `character` |
| 1.9 | FT, `type = "Fay"`, `rho` each of `-0.1`, `1`, `NA`, `NA_real_`, `NaN`, `Inf`, `-Inf`, `numeric(0)`, `c(0.1, 0.2)`, `TRUE`, `factor("0.5")`, `list(0.5)`, `matrix(0.3)`, `array(0.3, c(1, 1, 1))` | `surveycore_error_fay_rho_invalid` for each | no |

**Warning paths**

| Row | Scenario | Assertion |
|---|---|---|
| 1.10 | FT, each of `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`, `"bootstrap"`, `"ACS"`, `"successive-difference"`, `"other"`, with `rho = 0.3` | `expect_warning(d <- ..., class = "surveycore_warning_rho_ignored")`; `d@variables$rho` is `NULL`; `d@variables$scale` equals that type's default with no `rho` (build the same call without `rho` and compare the two scales with `expect_identical`). Bootstrap is in the list on purpose: `survey` does not warn there, surveycore does |
| 1.11 | FT, `type = "BRR"`, `rho = 0.3` | `expect_snapshot()` of the warning |
| 1.12 | FT, each of the same eight types, no `rho` | `expect_no_warning()` |
| 1.13 | FT, `type = "BRR"`, `rho = "a"` | only `surveycore_warning_rho_ignored`; no error. A discarded value is not checked |

**Edge cases**

| Row | Scenario | Assertion |
|---|---|---|
| 1.14 | FT, Fay, `rho = 0` | `rho` equals 0; `scale` equals `1 / 20`; `type` is `"Fay"`, not `"BRR"` |
| 1.15 | FT, Fay, `rho = 0L` | `@variables$rho` is identical to `0` (a double) |
| 1.16 | FT, Fay, `rho = c(a = 0.3)` | `names(d@variables$rho)` is `NULL`; value 0.3 |
| 1.17 | FT, Fay, `rho = 0.999` | `scale` equals `1 / (20 * (1 - 0.999)^2)` |
| 1.18 | FT, Fay, `rho = 0.3`, `scale = 99` | `expect_no_warning()`; `scale` equals `1 / (20 * (1 - 0.3)^2)`, not 99 |
| 1.19 | FT, Fay, `rho = 0.3`, `rscales = rep(2, 20)` | `@variables$rscales` identical to `rep(2, 20)`; scale as in 1.1 |
| 1.20 | FT, Fay, `rho = 0.3`, `mse = FALSE` | builds; `@variables$mse` is `FALSE` |
| 1.21 | Inline frame, one replicate column, Fay, `rho = 0.5` | builds; `scale` equals `1 / (1 - 0.5)^2`, that is 4 |
| 1.22 | Zero-row frame with the FT columns, Fay, no `rho` | `surveycore_error_empty_data`, not the missing-`rho` error |
| 1.23 | One-row frame, Fay, no `rho` | `surveycore_error_single_row`, not the missing-`rho` error |
| 1.24 | FT, Fay, no `rho`, `rscales` of length 3 | `surveycore_error_rscales_length`, not the missing-`rho` error |
| 1.25 | FT, Fay, `rho = 0.3`, then `update_design(d, weights = wt2)` where `wt2` is a positive copy of `wt` added to the frame | `@variables$rho` still equals 0.3. Handle the call's existing message or warning as the existing `update_design()` tests do |
| 1.26 | FA with a logical column selecting half the rows, phase 1 = Fay with `rho = 0.3`, then `as_survey_twophase()` with that column as `subset` | `surveycore_error_twophase_replicate_phase1`; class only. A Fay phase 1 is refused like every other replicate type (§7) |

**Invariants**: `test-constructors.R` already calls `test_invariants()` for
`as_survey_replicate()`. Add no new call. The `as_survey_twophase()` call
moves blocks (row 7.4).

### 2. Variance for a Fay design — file `tests/testthat/test-variance-replicate.R`

The existing block "survey::svrepdesign() refuses Fay without rho — Fay
design" becomes a real comparison. It may keep its one assertion of
`survey`'s refusal ("With type='Fay' you must supply the correct rho",
matched by message text). Its old assertion that surveycore stores `1 / R`
for Fay is removed. Its comment that the block compares nothing is removed.

**Assertions every oracle row (2.1 to 2.7) carries**, in addition to the
ones its own row lists:

- `survey::svrepdesign()` raises no warning (`expect_no_warning()` round
  the call).
- `as_survey_replicate()` raises no warning.
- Each side's stored scale equals the literal `1 / (10 * (1 - rho)^2)` for
  that row's `rho`, at 1e-8, asserted separately for each side.

**Degrees-of-freedom precondition for the oracle rows (2.1 to 2.7).** The
confidence-bound assertions hold only while both packages build the interval
from the normal approximation. surveycore uses infinite degrees of freedom on
the replicate path, and `survey`'s `confint()` defaults to `df = Inf`. Write
this precondition as a comment in the Fay oracle block. If either package
moves the replicate path to design-based degrees of freedom, every bound in
these rows moves while the mean and SE stay, and the rows must be revisited
in the same PR. Read such a failure as a degrees-of-freedom change, not as a
scale defect.

| Row | Scenario | Assertion |
|---|---|---|
| 2.1 **[oracle]** | FA, `rho = 0.3`, `mse = TRUE`; `get_means(y1, variance = c("se", "ci"))` against `survey::svymean(~y1)` | mean 1e-10; SE 1e-8; `ci_low` and `ci_high` 1e-6; both stored scales equal `1 / (10 * (1 - 0.3)^2)` at 1e-8; `survey::svrepdesign()` raises no warning; `as_survey_replicate()` raises no warning |
| 2.2 **[oracle]** | As 2.1 at `rho = 0` | as 2.1, scale literal `1 / 10` |
| 2.3 **[oracle]** | As 2.1 at `rho = 0.5` | as 2.1 |
| 2.4 **[oracle]** | As 2.1 at `rho = 0.9` | as 2.1, scale literal `1 / (10 * (1 - 0.9)^2)` |
| 2.5 **[oracle]** | As 2.1 with `mse = FALSE` on both sides | as 2.1 |
| 2.6 **[oracle]** | FA, `rho = 0.3`, `mse = TRUE`; `get_totals(y1)` against `survey::svytotal(~y1)` | total 1e-10; SE 1e-8; bounds 1e-6; the three shared assertions above, scale literal `1 / (10 * (1 - 0.3)^2)` |
| 2.7 **[oracle]** | FA, `rho = 0.3`, `mse = TRUE`; `get_means(y1, group = group)` against `survey::svyby(~y1, ~group, survey::svymean)` | per-group mean 1e-10, SE 1e-8, bounds 1e-6; match rows by group level; the three shared assertions above, scale literal `1 / (10 * (1 - 0.3)^2)` |
| 2.8 | FA, surveycore only: Fay at `rho = 0` against BRR | SE equal at 1e-8; each stored scale equals `1 / 10` |
| 2.9 | FA, surveycore only: Fay at `rho = 0.5` against BRR | Fay SE divided by BRR SE equals 2 at 1e-8; the two means are equal at 1e-10 |
| 2.10 | FA, surveycore only: Fay `rho = 0.3` with `rscales = rep(2, 10)` against the same design with no `rscales` | the first SE divided by the second equals `sqrt(2)` at 1e-8 |
| 2.11 | Inline frame with `y1` all `NA`, built as Fay `rho = 0.3` and as BRR | `get_means()` on the two designs gives the same outcome: either both return, with identical `NA` positions in `mean` and `se`, or both raise the same error class |

**Invariants**: the file already calls `test_invariants()` for
`as_survey_replicate()`. Add no new call.

### 3. `as_svydesign()` — file `tests/testthat/test-conversion.R`

| Row | Scenario | Assertion |
|---|---|---|
| 3.1 **[round trip]** | FC, Fay, `rho = 0.3` | `expect_no_warning(sv <- as_svydesign(d))`; `sv` inherits `svyrep.design`; `sv$rho` equals 0.3; `sv$scale` equals `1 / (5 * (1 - 0.3)^2)` at 1e-8; `survey::svymean(~y1, sv)` SE equals surveycore's `get_means()` SE at 1e-8 and mean at 1e-10 |
| 3.2 | FC, Fay, `rho = 0` | `sv$rho` equals 0; `sv$scale` equals `1 / 5` |
| 3.3 | FC, BRR, no `rho` | `expect_no_warning()`; `sv$rho` is `NULL` |
| 3.4 | A `survey_replicate()` built by hand on FC with `type = "Fay"`, `scale = 1 / 5`, and a `variables` list with no `rho` key (the shape of a design saved before this change) | `surveycore_error_fay_rho_unrecoverable`; `expect_snapshot(error = TRUE)`; the message contains `rho` and names `as_survey_replicate` |
| 3.5 | As 3.4 with the key `rho = NULL` present | `surveycore_error_fay_rho_unrecoverable`; class only |
| 3.6 | As 3.4 with `rho = 1.5` stored | `surveycore_error_fay_rho_unrecoverable`; class only |
| 3.1a **[round trip]** | FA with the domain column added before construction: `df[[SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)`; build Fay with `rho = 0.3`; `sv <- as_svydesign(d)` | `sv$rho` equals 0.3; `sv$scale` equals `1 / (10 * (1 - 0.3)^2)` at 1e-8; `survey::svymean(~y1, sv)` SE equals `get_means(d, y1, variance = "se")` SE at 1e-8 and mean at 1e-10. The domain column name comes from the exported constant `SURVEYCORE_DOMAIN_COL` |
| 3.7 | As 3.4 with no `scale` key and no `rho` key (the shape of the existing block "as_svydesign() refuses a Fay design that records no scale") | `surveycore_error_fay_rho_unrecoverable`. That block is rewritten to this assertion; its old assertion that the message contains "none" is removed |

Existing blocks that change:

- "as_svydesign() recovers rho = 0 from the default Fay scale" is removed.
  Row 3.2 replaces it.
- "as_svydesign() refuses a Fay design whose scale yields no rho" is
  removed. A supplied Fay scale is now discarded at construction (row 1.18),
  so its state cannot be built through `as_survey_replicate()`.
- The two old CB-4 snapshot entries in `_snaps/conversion.md` go through
  `testthat::snapshot_review()`: the removed block's entry is deleted, and
  the rewritten entry shows the new text.
- "every accepted replicate type crosses both conversion routes": the Fay
  pass builds with `rho = 0.3` and also asserts that the re-imported design
  has `@variables$rho` equal to 0.3. The other eight passes do not change.

### 4. `from_svydesign()` — file `tests/testthat/test-conversion.R`

| Row | Scenario | Assertion |
|---|---|---|
| 4.1 **[round trip]** | FS, `survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)` | imported `@variables$rho` equals 0.3; `@variables$scale` equals the source's `$scale` at 1e-10; `get_means(y1)` SE equals the source's `survey::svymean()` SE at 1e-8 |
| 4.2 | FS, `survey::as.svrepdesign(tay, type = "BRR")`; the source's `$rho` is 0 | imported `@variables$rho` is identical to `NULL`; the key is present |
| 4.3 | FA through `survey::svrepdesign(type = "BRR", rho = 0.3, ...)`; the source build raises `survey`'s warning "type='BRR' does not use 'rho=' argument", matched by text | imported `@variables$rho` is `NULL` |
| 4.4 | FS, `survey::as.svrepdesign(tay, type = "BRR", fay.rho = 0.3)`; `survey` relabels the source as `"Fay"` | imported `@variables$type` is `"Fay"`; `@variables$rho` equals 0.3 |
| 4.5 | FA through `survey::svrepdesign(type = "Fay", rho = 1.5, ...)` | the import raises no condition and stores `rho` 1.5; `as_svydesign()` on the result raises `surveycore_error_fay_rho_unrecoverable` |
| 4.5a | FA through `survey::svrepdesign(type = "Fay", rho = 0.3, ...)`, then `src$rho <- NA` by hand | the import raises no condition and stores `rho` as `NA`; `as_svydesign()` on the result raises `surveycore_error_fay_rho_unrecoverable` |
| 4.5b | As 4.5a, then `src$rho <- NULL` by hand (the element is removed) | the import raises no condition; `@variables$rho` is `NULL`; `as_svydesign()` on the result raises `surveycore_error_fay_rho_unrecoverable` |
| 4.6 **[round trip]** | The existing block "the round trip reproduces a Fay source's mean, SE and CI" (`fay.rho = 0.5`) | keeps passing unchanged; additionally the intermediate surveycore design has `@variables$rho` equal to 0.5 |
| 4.7 **[round trip]** | The existing block "as_svydesign() exports a Fay design with its scale and SE" (`fay.rho = 0.3`) | keeps passing unchanged. Its comments that speak of recovering `rho` from the scale are updated to say `rho` is carried |

### 5. `print()` and `summary()` — file `tests/testthat/test-methods-print.R`

Fixture: FA built as Fay with `rho = 0.5` (scale 0.4).

| Row | Scenario | Assertion |
|---|---|---|
| 5.1 | `print(d)` | `expect_snapshot()`. The class line reads `<survey_replicate> (FAY, 10 replicates, rho = 0.5)` |
| 5.2 | `print(d, full = TRUE)` | `expect_snapshot()`. `• Rho: 0.5` is the line directly after `• Scale: 0.4` |
| 5.3 | `summary(d)` | `expect_snapshot()`. The type line reads `Type: replicate weights (FAY, 10 replicates, rho = 0.5)`; `Rho: 0.5` is the line directly after `Scale: 0.4` |
| 5.4 | A hand-built Fay `survey_replicate()` with no `rho` key; `print(d, full = TRUE)` and `summary(d)` | `expect_snapshot()`; the snapshot holds no `Rho:` line and no `rho =` text |
| 5.5 | Every snapshot of a non-Fay design already in `_snaps/methods-print.md` | unchanged. `git diff` on that file shows added entries only |

### 7. `as_survey_twophase()` refuses a replicate phase 1 — files `tests/testthat/test-constructors.R` and `tests/testthat/test-variance-twophase.R`

This section does not depend on `rho`, except row 7.2's Fay pass.

Fixture FP: `make_survey_data(n = 100, n_psu = 10L, design = "replicate",
seed = 20L)` with `in_phase2 <- c(rep(TRUE, 50), rep(FALSE, 50))` added, the
frame of the existing block it replaces.

| Row | Scenario | Assertion |
|---|---|---|
| 7.1 | FP, phase 1 = `as_survey_replicate(type = "JK1")`, then `as_survey_twophase(phase1, subset = in_phase2)` | `expect_error(class = "surveycore_error_twophase_replicate_phase1")` and `expect_snapshot(error = TRUE)`. The message names `as_survey()` |
| 7.2 | FP, phase 1 of each of the nine replicate types (Fay with `rho = 0.3`) | `surveycore_error_twophase_replicate_phase1` for each; class only |
| 7.3 | FP, JK1 phase 1, `as_survey_twophase(phase1)` with no `subset` | `surveycore_error_twophase_replicate_phase1`, not `surveycore_error_subset_missing` |
| 7.4 | The existing block "as_survey_twophase() accepts survey_taylor phase-1 (weights only, no ids/strata)" | still builds a `survey_twophase`. It now holds the file's one `test_invariants()` call for `as_survey_twophase()`, moved from the block that 7.1 replaces |
| 7.5 | `make_survey_data(n = 200, design = "twophase", seed = 42L)`, phase 1 = `as_survey_nonprob(df, weights = wt)` (no replicate weights), then `as_survey_twophase(phase1, subset = subset)` | does not raise `surveycore_error_twophase_replicate_phase1`. Assert with `expect_no_error(class = "surveycore_error_twophase_replicate_phase1")`; other conditions from that call are outside this row |
| 7.6 | `as_survey_twophase(df, subset = subset)` on a plain data frame (the existing row-19 block) | still `surveycore_error_phase1_class`. Its snapshot changes through `testthat::snapshot_review()`: the `i` line reads "Create it first with `as_survey()`." and no longer names `as_survey_replicate()` |

Existing blocks that change:

- `test-constructors.R`, "as_survey_twophase() accepts survey_replicate
  phase-1": rewritten as row 7.1. Its `test_invariants()` call moves to row
  7.4's block.
- `test-constructors.R`, "as_survey_twophase() carries the phase-1 scale of
  both changed types": deleted. The JKn and bootstrap stored defaults stay
  pinned by the nine-type default block, and row 7.2 covers the refusal.
- `test-variance-twophase.R`, "two-phase with survey_replicate phase-1
  constructs and estimates": deleted. Its section header "SRS / replicate
  phase-1 designs" becomes "SRS phase-1 designs".

No other test block, example, vignette chunk, helper or snapshot builds a
two-phase design on a replicate phase 1.

**Invariants**: row 7.4 carries the one `as_survey_twophase()` call in
`test-constructors.R`. `test-variance-twophase.R` gains none.

### 6. Documentation checks

Run these by search over the built package sources. They are gates, not
`test_that()` blocks.

| Row | Check |
|---|---|
| 6.1 | `?as_survey_replicate` documents `rho`, says Fay requires it, gives the range `[0, 1)`, and gives the Fay scale `1 / (R * (1 - rho)^2)` |
| 6.2 | `man/as_survey_replicate.Rd` and `man/survey_replicate.Rd` cite Judkins (1990) in the *Journal of Official Statistics* 6(3), 223-239, and nowhere in the *Journal of the American Statistical Association* |
| 6.3 | `man/survey_replicate.Rd` lists `rho` among the design variables |
| 6.4 | No file under `vignettes/` contains `fay_rho` |
| 6.5 | `NEWS.md` holds one entry for the Fay export route and it does not say `rho` is recovered from the scale; a breaking-change entry states that a Fay SE is the old SE divided by `1 - rho` and names `surveycore_error_fay_rho_missing` |
| 6.6 | `CLAUDE.md` says the scale recovery was replaced by a stored `rho` (issue #243) |
| 6.7 | `.claude/rules/testing-surveycore.md` has no "Sanctioned exceptions" section that names a live exception; its per-type table's Fay row still reads `1/(R * (1 - rho)^2)`, "discard, no warning", "honoured" |
| 6.8 | The `as_survey_replicate()` help page's examples include a Fay design with `rho`, and `devtools::run_examples()` runs it |
| 6.9 | `?as_survey_replicate` says, in the `rho` entry, that the Fay scale assumes a two-PSU-per-stratum Hadamard-balanced layout that surveycore does not check, and that it is exact for totals and first-order for means and ratios |
| 6.10 | `?as_survey_twophase` no longer says a `survey_replicate` phase 1 is accepted, and its See also section no longer links `as_survey_replicate()` |
| 6.11 | `NEWS.md` has a breaking-change item for the replicate phase-1 refusal that names `surveycore_error_twophase_replicate_phase1` and says it reverses PR #74 |
| 6.12 | The replicate variance engine is not edited. Take the source file that `.claude/rules/testing-surveycore.md` §File mapping maps to `tests/testthat/test-variance-replicate.R`. `git diff <base>...HEAD` over that file is empty, where `<base>` is the branch point from `develop` |
| 6.13 | `NEWS.md` has a breaking-change item saying `rho` sits after `type` and before `scale`, and that `scale`, `rscales`, `fpc`, `fpctype`, `mse` and `calibration` each move one position later |
| 6.14 | `?as_survey_replicate` says, in the `rho` entry, that `type` stays `"Fay"` at `rho = 0`, unlike `survey::as.svrepdesign()`, which relabels it `"BRR"` |

### Input modes

No function in this work takes both a survey design and a plain data frame.
No row names a mode.

### Gotchas out of scope, with the reason

- A `rho` that does not match the replicate columns: no function can detect
  it, so no row tests it.
- A saved Fay design in the analysis functions: it keeps its old scale with
  no condition, by decision. Rows 3.4 to 3.7 cover its export.
- Degrees of freedom: unchanged. The confidence-bound assertions in rows 2.1
  to 2.7 catch a change in either package's degrees of freedom.
- Degenerate strata: a replicate design reads no strata.
- Domain estimation: the Fay design shares every domain code path with the
  other replicate types, and only the stored scale differs. The existing
  domain tests cover those paths.

## Tolerances

- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Stored scale against its literal: 1e-8, the SE/variance row, because the
  scale enters the variance only
- Ratios of two SEs (rows 2.9, 2.10): 1e-8, the SE row
- Deviations (with justification): none. On FA the measured difference
  between the two packages is below 2e-13 for the SE and the bounds at every
  `rho` from 0 to 0.9

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
