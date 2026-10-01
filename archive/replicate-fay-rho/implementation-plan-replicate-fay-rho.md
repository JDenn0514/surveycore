# Implementation plan — replicate-fay-rho

**Status**: PLAN_READY
**Date**: 2026-09-30
**Issue**: #243
**Input state**: SPEC_READY
**PR count**: 9
**Test-spec rows**: 81, each given to exactly one PR (§Row assignment)

## How to read this plan

- The builder reads `spec.md` and this plan. The builder never reads
  `test-spec.md`. So every task below writes out the fixture, the value, the
  list and the count it needs. A task never says "see row n" as its only
  source.
- The row ids (1.1, 3.1a, 7.4 and so on) in the **Budget** and **Acceptance
  criteria** lines are for the tester and the reviewer. Do not put a row id
  in a `test_that()` title.
- All R code in tests follows `.claude/rules/code-style.md`.
- Every new test block goes in the test file the task names. Tests that
  compare against `survey` start with `skip_if_not_installed("survey")`
  inside the block.
- Tolerances: point estimate 1e-10; SE, variance and stored scale 1e-8; CI
  bounds 1e-6; a ratio of two SEs 1e-8.

## Order and concurrency

```
PR 1 ──┬── PR 2 ── PR 3 ──┐
       ├── PR 4 ── PR 5 ──┼── PR 8 ──┐
       ├── PR 6 ──────────┼──────────┼── PR 9
       └── PR 7 ──────────┴──────────┘
```

- PR 1 merges first. Every other PR needs the `rho` argument.
- After PR 1: PR 2, PR 4, PR 6 and PR 7 can run at the same time. Their
  write surfaces are disjoint.
- PR 3 follows PR 2 (both write `tests/testthat/test-constructors.R`).
- PR 5 follows PR 4 (both write `R/methods-conversion.R` and
  `tests/testthat/test-conversion.R`). PR 4 must come first: after PR 5 the
  export route reads the stored `rho`, so a `survey` Fay object must import
  with `rho` or the existing Fay round-trip blocks fail.
- PR 3 and PR 5 can run at the same time.
- PR 8 follows PR 3 (shared `R/core-constructors.R`,
  `tests/testthat/test-constructors.R`, `tests/testthat/_snaps/constructors.md`)
  and PR 5 (shared `plans/error-messages.md`). PR 8 also needs PR 1, because
  its nine-type refusal test builds a Fay phase 1 with `rho = 0.3`.
- PR 9 merges last. It describes behaviour that PRs 4, 5, 6 and 7 ship, and
  it shares `NEWS.md` with PR 8. Its `NEWS.md` item says `print()` and
  `summary()` show `rho`, which is false before PR 6. Its edit to
  `.claude/rules/testing-surveycore.md` says the Fay block is an ordinary
  oracle test, which is false before PR 7.

Update each branch from `develop` before you open its PR. Branch protection
needs an up-to-date head branch.

## Standard gates (criterion G)

Every PR lists criterion **G**. It holds when all of these are true on the
PR's head commit:

1. `devtools::document()` leaves no diff. `NAMESPACE` and `man/` are in
   sync with the roxygen.
2. `devtools::test()` (run with `NOT_CRAN=true`): 0 failures. The warning
   count is not higher than on `develop` at the branch point. Clean
   `develop` carries 256 pre-existing AAPOR small-cell warnings, so the gate
   is "no new warning", not "0 warnings".
3. `devtools::run_examples()` runs clean.
4. `R CMD check --as-cran`: 0 errors, 0 warnings. Notes: only the
   pre-approved note and the pre-existing `.git` hidden-file note. This is
   the package's usual bar (`.claude/rules/r-package-conventions.md`
   §Package check hygiene).
5. `pkgdown::build_site()` builds with no errored page.
6. `covr::package_coverage()` with `NOT_CRAN=true` is 95% or more.
7. `air format --check` passes on the `.R` files this PR changes. `air` is a
   command-line tool here, not an R package.
8. Snapshots change only through `testthat::snapshot_review()`, with each
   diff read. `git diff` over `tests/testthat/_snaps/` shows only the
   entries this PR's tasks name.
9. `git diff --name-only develop...HEAD` lists only files in this PR's
   **Files touched**.

## Fixtures

The builder builds these in the test block that needs them.

| Id | Build | Replicate columns |
|---|---|---|
| FA | `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "fay", seed = 15)` | 10: `repwt_1` to `repwt_10`. Outcome `y1`; grouping column `group` |
| FT | `make_survey_data(n = 200, n_psu = 20, design = "replicate", type = "jkn", seed = 259)` | 20: `repwt_1` to `repwt_20`. This is the frame of the existing block "as_survey_replicate() stores the default scale of all nine types" |
| FC | the existing helper `make_rep_type()` in `tests/testthat/test-conversion.R` (`n = 50`, `n_psu = 10`, `n_strata = 2`, seed 430) | 5 |
| FS | the existing helper `make_taylor_source()` in `tests/testthat/test-conversion.R`, then `survey::svydesign(ids = ~psu, strata = ~strata, weights = ~wt, data = df, nest = TRUE)`, then `survey::as.svrepdesign()` | 8 |
| FP | `make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 20L)`, then `df$in_phase2 <- c(rep(TRUE, 50), rep(FALSE, 50))` | as the generator gives |

The eight types other than Fay, used in several tasks: `"JK1"`, `"JK2"`,
`"JKn"`, `"BRR"`, `"bootstrap"`, `"ACS"`, `"successive-difference"`,
`"other"`.

## PR map

- [x] PR 1: `feature/fay-rho-constructor` — `as_survey_replicate()` gains `rho`; Fay requires it and gets the Fay scale
  - **Budget** — 11 test-spec rows | 8 criteria
    - Rows: §1 1.1, 1.2, 1.4a, 1.5, 1.7, 1.10, 1.11; §6 6.1, 6.8, 6.9, 6.14
  - **Tasks**
    1. Add register rows FR-1, FR-2 and FR-3 to `plans/error-messages.md`.
       Take the row text word for word from the planning copy of that file
       (the FR block, rows FR-1 to FR-3). Do not add TP-1 or change CB-4 or
       row 19 here.
    2. Write a failing test in `tests/testthat/test-constructors.R`: the
       formal names of `as_survey_replicate`, in order, are identical to
       `c("data", "weights", "repweights", "type", "rho", "scale", "rscales", "fpc", "fpctype", "mse", "calibration")`.
    3. Write a failing test: on FT, `type = "Fay"`, `rho = 0.3` stores
       `@variables$rho` equal to 0.3, `@variables$scale` equal to
       `1 / (20 * (1 - 0.3)^2)`, and `@variables$type` identical to `"Fay"`.
    4. Edit the existing block "as_survey_replicate() stores the default
       scale of all nine types". Its local helper `stored()` gains the
       argument `rho = NULL` and passes it to `as_survey_replicate()`. Its
       Fay line calls `stored("Fay", rho = 0.3)` and expects
       `1 / (n_rep * (1 - 0.3)^2)`. The other eight lines do not change.
       The title may change to say Fay takes `rho`.
    5. Write failing tests for FR-1 on FT, `type = "Fay"`, no `rho`:
       `expect_error(class = "surveycore_error_fay_rho_missing")` and
       `expect_snapshot(error = TRUE, ...)`. The message names `rho`.
    6. Write failing tests for FR-2 on FT, `type = "Fay"`, `rho = 1.5`:
       `expect_error(class = "surveycore_error_fay_rho_invalid")` and
       `expect_snapshot(error = TRUE, ...)`.
    7. Write a failing test on FT for each of the eight other types with
       `rho = 0.3`:
       `expect_warning(d <- ..., class = "surveycore_warning_rho_ignored")`;
       `d@variables$rho` is `NULL`; `d@variables$scale` is identical
       (`expect_identical()`) to the scale of the same call with no `rho`.
    8. Write a failing test on FT, `type = "BRR"`, `rho = 0.3`:
       `expect_snapshot()` of the warning.
    9. Implement `.is_valid_rho()` in `R/utils.R` exactly as spec §II.
    10. Implement spec §II and §III in `as_survey_replicate()`: the formal
        order, the order of checks, the FR-1, FR-2 and FR-3 conditions with
        their templates and bindings, `as.double(rho)` with no names for a
        valid Fay `rho`, the Fay scale `1 / (n_rep * (1 - rho)^2)`, the
        deletion of the `Fay` entry from the default-scale switch, and the
        `rho` key in the `@variables` list for every type.
    11. Write the roxygen of spec §III §Documentation in
        `R/core-constructors.R`: `@param rho` after `@param type`, with the
        layout sentence and the `rho = 0` sentence; the `@param scale` and
        `@param type` edits; the Fay example as the last `@examples` block.
        Leave `@references` for PR 2. Run `devtools::document()`.
    12. Keep the existing Fay blocks green. The constructor now refuses a Fay
        call with no `rho`, so make exactly these edits:
        - `tests/testthat/test-conversion.R`, helper `make_rep_type()`: add
          the argument `rho = NULL` after `type` and pass `rho = rho` to
          `as_survey_replicate()`.
        - Block "as_svydesign() recovers rho = 0 from the default Fay
          scale": call `make_rep_type(type = "Fay", seed = 422L, rho = 0)`.
          Change nothing else in the block. PR 5 removes it.
        - Block "as_svydesign() refuses a Fay design whose scale yields no
          rho": delete it. A supplied Fay scale is now discarded, so its
          state cannot be built. Delete its entry in
          `tests/testthat/_snaps/conversion.md` through
          `testthat::snapshot_review()`.
        - Block "every accepted replicate type crosses both conversion
          routes": pass `rho = if (ty == "Fay") 0.3 else NULL` to
          `make_rep_type()`. Add no assertion here; PR 4 adds one.
        - `tests/testthat/test-variance-replicate.R`, block
          "survey::svrepdesign() refuses Fay without rho — Fay design": add
          `rho = 0` to the `as_survey_replicate()` call. Keep the
          `1 / n_rep` assertion: at `rho = 0` the Fay scale is the BRR
          scale. Replace the comment text that says surveycore has no `rho`
          argument with one that says `rho = 0` gives the BRR scale and that
          a later PR of issue #243 rewrites the block into an oracle
          comparison. PR 7 rewrites it.
    13. Verify: the new tests pass, the snapshots are reviewed, and G holds.
  - **Acceptance criteria**
    1. The formal names of `as_survey_replicate()` are, in order, `data`,
       `weights`, `repweights`, `type`, `rho`, `scale`, `rscales`, `fpc`,
       `fpctype`, `mse`, `calibration` (1.4a).
    2. On FT, Fay with `rho = 0.3` stores `rho` 0.3, scale
       `1 / (20 * (1 - 0.3)^2)` and type `"Fay"`; the nine-type default
       block passes with its Fay line at `rho = 0.3` and its other eight
       lines unchanged (1.1, 1.2).
    3. A Fay call with no `rho` raises `surveycore_error_fay_rho_missing`,
       and its snapshot shows the FR-1 text (1.5).
    4. A Fay call with `rho = 1.5` raises
       `surveycore_error_fay_rho_invalid`, and its snapshot shows the FR-2
       text (1.7).
    5. Each of the eight other types with `rho = 0.3` raises
       `surveycore_warning_rho_ignored`, stores `rho` as `NULL` and stores
       the same scale as the call with no `rho`; the BRR warning snapshot
       shows the FR-3 text (1.10, 1.11).
    6. `?as_survey_replicate` documents `rho`: Fay requires it, the range is
       `[0, 1)`, the Fay scale is `1 / (R * (1 - rho)^2)`, the layout is
       two PSUs per stratum with Hadamard-balanced half samples that
       surveycore does not check, the scale is exact for totals and
       first-order for means and ratios, and `type` stays `"Fay"` at
       `rho = 0` unlike `survey::as.svrepdesign()`; the Fay example runs
       under `devtools::run_examples()` (6.1, 6.8, 6.9, 6.14).
    7. The three kept Fay blocks named in task 12 pass; the block "as_svydesign()
       refuses a Fay design whose scale yields no rho" and its snapshot entry
       no longer exist.
    8. G.
  - **Files touched**
    - `R/utils.R`
    - `R/core-constructors.R`
    - `man/as_survey_replicate.Rd` (generated)
    - `plans/error-messages.md`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
    - `tests/testthat/test-conversion.R`
    - `tests/testthat/_snaps/conversion.md`
    - `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] PR 2: `test/fay-rho-constructor-conditions` — the `rho` key, the positional call, the remaining condition tests, and the class documentation
  - **Budget** — 10 test-spec rows | 7 criteria
    - Rows: §1 1.3, 1.4, 1.4b, 1.6, 1.8, 1.9, 1.12, 1.13; §6 6.2, 6.3
  - **Tasks**
    1. Write tests in `tests/testthat/test-constructors.R` for the `rho`
       key. On FT, for each of the eight other types with no `rho`:
       `"rho" %in% names(d@variables)` is `TRUE` and `d@variables$rho` is
       identical to `NULL`. On FT, Fay with `rho = 0.3`:
       `"rho" %in% names(d@variables)` is `TRUE`.
    2. Write a test for the positional call on FT:
       `as_survey_replicate(df, wt, starts_with("repwt_"), "Fay", 0.3)`
       stores `rho` equal to 0.3 and scale equal to
       `1 / (20 * (1 - 0.3)^2)`.
    3. Write a test on FT, Fay, `rho = NULL` passed explicitly:
       `expect_error(class = "surveycore_error_fay_rho_missing")`. No
       snapshot.
    4. Write tests on FT, Fay, `rho = "0.5"`:
       `expect_error(class = "surveycore_error_fay_rho_invalid")` and
       `expect_snapshot(error = TRUE, ...)`. The snapshot shows the class
       `character`. Add two more FR-2 snapshots in the same block, to pin
       the `rho_txt` binding of spec §III: `rho = numeric(0)` renders
       "a value of length 0", and `rho = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6)`
       renders only the first five values, joined by ", ".
    5. Write a test on FT, Fay, for each of these 14 values of `rho`:
       `-0.1`, `1`, `NA`, `NA_real_`, `NaN`, `Inf`, `-Inf`, `numeric(0)`,
       `c(0.1, 0.2)`, `TRUE`, `factor("0.5")`, `list(0.5)`, `matrix(0.3)`,
       `array(0.3, c(1, 1, 1))`. Each raises
       `surveycore_error_fay_rho_invalid`. Class only, no snapshot.
    6. Write a test on FT, for each of the eight other types with no `rho`:
       `expect_no_warning()`.
    7. Write a test on FT, `type = "BRR"`, `rho = "a"`: the call raises
       `surveycore_warning_rho_ignored` and no error.
    8. Edit the roxygen of spec §III (`@references` only) and spec §IV:
       the Judkins entry in `R/core-constructors.R` and `R/core-classes.R`
       becomes "Judkins, D.R. (1990) Fay's method for variance estimation.
       \emph{Journal of Official Statistics} \bold{6}(3), 223--239."; in
       `R/core-classes.R`, `@param variables` lists "weights, repweights,
       type, scale, rscales, fpc, fpctype, mse, rho", and
       `@section Design variables` gains the `rho` item after `mse`. Run
       `devtools::document()`.
    9. Verify: each test passes against the PR 1 code. A test that fails
       shows a PR 1 defect: fix `R/core-constructors.R` in this PR and say
       so in `implementation.md`. Then check G.
  - **Acceptance criteria**
    1. Every design from `as_survey_replicate()` on FT has the key `rho`:
       `NULL` for the eight other types, present for Fay (1.3, 1.4).
    2. The positional call with `"Fay", 0.3` in fourth and fifth place
       stores `rho` 0.3 and scale `1 / (20 * (1 - 0.3)^2)` (1.4b).
    3. `rho = NULL` passed explicitly with Fay raises
       `surveycore_error_fay_rho_missing` (1.6).
    4. `rho = "0.5"` raises `surveycore_error_fay_rho_invalid` with a
       snapshot that names `character`; the `numeric(0)` snapshot reads
       "a value of length 0" and the six-value snapshot shows five values;
       and each of the 14 listed values
       raises the same class (1.8, 1.9).
    5. The eight other types raise no warning with no `rho`; BRR with
       `rho = "a"` raises only `surveycore_warning_rho_ignored` (1.12,
       1.13).
    6. `man/as_survey_replicate.Rd` and `man/survey_replicate.Rd` cite
       Judkins (1990) in the *Journal of Official Statistics* 6(3), 223-239
       and never in the *Journal of the American Statistical Association*;
       `man/survey_replicate.Rd` lists `rho` among the design variables
       (6.2, 6.3).
    7. G.
  - **Files touched**
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
    - `R/core-constructors.R` (roxygen `@references` only, unless task 9
      finds a defect)
    - `R/core-classes.R` (roxygen only)
    - `man/as_survey_replicate.Rd`, `man/survey_replicate.Rd` (generated)
  - **Pipeline tier**: recommended

- [x] PR 3: `test/fay-rho-constructor-edges` — edge cases of `rho` and the order of checks
  - **Budget** — 12 test-spec rows | 7 criteria
    - Rows: §1 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23,
      1.24, 1.25
  - **Tasks** — all tests go in `tests/testthat/test-constructors.R`.
    1. Write tests for the accepted values on FT, Fay:
       - `rho = 0`: `rho` equals 0, scale equals `1 / 20`, type identical
         to `"Fay"` (not `"BRR"`).
       - `rho = 0L`: `@variables$rho` is identical to `0` (a double).
       - `rho = c(a = 0.3)`: `names(d@variables$rho)` is `NULL`; the value
         equals 0.3.
       - `rho = 0.999`: scale equals `1 / (20 * (1 - 0.999)^2)`.
    2. Write a test on FT, Fay, `rho = 0.3`, `scale = 99`:
       `expect_no_warning()`; scale equals `1 / (20 * (1 - 0.3)^2)`, not 99.
    3. Write tests on FT, Fay, `rho = 0.3`: with `rscales = rep(2, 20)`,
       `@variables$rscales` is identical to `rep(2, 20)` and the scale equals
       `1 / (20 * (1 - 0.3)^2)`; with `mse = FALSE`, the design builds and
       `@variables$mse` is `FALSE`.
    4. Write a test with an inline frame that has one replicate column, Fay,
       `rho = 0.5`: the design builds and the scale equals
       `1 / (1 - 0.5)^2`, that is 4.
    5. Write tests for the order of checks, Fay, no `rho`:
       - a zero-row frame with the FT columns (`df[0, ]`) raises
         `surveycore_error_empty_data`, not the missing-`rho` error;
       - a one-row frame (`df[1, ]`) raises `surveycore_error_single_row`;
       - FT with `rscales` of length 3 raises
         `surveycore_error_rscales_length`.
    6. Write a test on FT with `df$wt2 <- df$wt * 1.05` added before
       construction, Fay, `rho = 0.3`, then
       `suppressMessages(update_design(d, weights = wt2))`, the form the
       existing `update_design()` weight tests in
       `tests/testthat/test-update-design.R` use: `@variables$rho` still
       equals 0.3.
    7. Verify: each test passes against the PR 1 code. A test that fails
       shows a PR 1 defect: fix it in this PR, add `R/core-constructors.R`
       to the write surface, and say so in `implementation.md`. Then check G.
  - **Acceptance criteria**
    1. Fay accepts `rho = 0` (scale `1 / 20`, type `"Fay"`), `0L` (stored
       as double 0), `c(a = 0.3)` (stored unnamed) and `0.999` (scale
       `1 / (20 * (1 - 0.999)^2)`) (1.14, 1.15, 1.16, 1.17).
    2. Fay with `scale = 99` raises no warning and stores
       `1 / (20 * (1 - 0.3)^2)` (1.18).
    3. Fay keeps `rscales = rep(2, 20)` and accepts `mse = FALSE` (1.19,
       1.20).
    4. Fay with one replicate column and `rho = 0.5` stores scale 4 (1.21).
    5. A zero-row frame raises `surveycore_error_empty_data`, a one-row
       frame raises `surveycore_error_single_row`, and a wrong `rscales`
       length raises `surveycore_error_rscales_length`, each before the
       missing-`rho` error (1.22, 1.23, 1.24).
    6. `update_design(weights = wt2)` keeps `rho` 0.3 (1.25).
    7. G.
  - **Files touched**
    - `tests/testthat/test-constructors.R`
  - **Pipeline tier**: optional — tests only, one file, no contract change

- [x] PR 4: `feature/fay-rho-import` — `from_svydesign()` stores `survey`'s `rho` for Fay and `NULL` otherwise
  - **Budget** — 5 test-spec rows | 5 criteria
    - Rows: §4 4.1, 4.2, 4.3, 4.4, 4.6
  - **Tasks** — all tests go in `tests/testthat/test-conversion.R`.
    1. Write a failing test on FS,
       `src <- survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)`,
       `d <- from_svydesign(src)`: `d@variables$rho` equals 0.3;
       `d@variables$scale` equals `src$scale` at 1e-10; the SE of
       `get_means(d, y1, variance = "se")` equals the SE of
       `survey::svymean(~y1, src)` at 1e-8.
    2. Write a failing test on FS,
       `survey::as.svrepdesign(tay, type = "BRR")` (its `$rho` is 0): the
       imported design has the key `rho` and `@variables$rho` is identical
       to `NULL`.
    3. Write a failing test on FA through
       `survey::svrepdesign(type = "BRR", rho = 0.3, ...)`. The source build
       raises `survey`'s warning "type='BRR' does not use 'rho=' argument";
       match it by message text, not by class. The imported
       `@variables$rho` is `NULL`.
    4. Write a failing test on FS,
       `survey::as.svrepdesign(tay, type = "BRR", fay.rho = 0.3)`. `survey`
       relabels it `"Fay"`. The imported `@variables$type` is `"Fay"` and
       `@variables$rho` equals 0.3.
    5. Edit the existing block "the round trip reproduces a Fay source's
       mean, SE and CI" (`fay.rho = 0.5`): import into `d` first, assert
       `d@variables$rho` equals 0.5, then export `d`. Its existing
       assertions do not change.
    6. Edit the existing block "every accepted replicate type crosses both
       conversion routes": for the Fay pass only, assert that the re-imported
       design has `@variables$rho` equal to 0.3 (`expect_equal()`). The
       other eight passes do not change.
    7. Implement spec §V in `.from_svydesign_replicate()`: store `x$rho`
       unchanged when `x$type == "Fay"`, and `NULL` for every other type. No
       new condition. The stored scale stays `x$scale`.
    8. Verify: the new tests pass and G holds.
  - **Acceptance criteria**
    1. A `survey` Fay design built with `fay.rho = 0.3` imports with `rho`
       0.3, the source's scale at 1e-10, and the source's SE at 1e-8 (4.1).
    2. A `survey` BRR design imports with the key `rho` present and `NULL`,
       both from `as.svrepdesign()` (source `$rho` 0) and from
       `svrepdesign(rho = 0.3)` (4.2, 4.3).
    3. `as.svrepdesign(type = "BRR", fay.rho = 0.3)` imports as type
       `"Fay"` with `rho` 0.3 (4.4).
    4. The Fay round-trip block (`fay.rho = 0.5`) passes and its intermediate
       design has `rho` 0.5; the all-types block's Fay pass re-imports with
       `rho` 0.3 (4.6).
    5. G.
  - **Files touched**
    - `R/methods-conversion.R`
    - `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended

- [x] PR 5: `fix/fay-rho-export` — `as_svydesign()` passes the stored `rho`; the scale inversion is deleted; CB-4 is restated
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §3 3.1, 3.1a, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7; §4 4.5, 4.5a, 4.5b,
      4.7
  - **Tasks** — all tests go in `tests/testthat/test-conversion.R`.
    1. Write failing tests for the Fay export on FC (5 replicates):
       - Fay, `rho = 0.3`: `expect_no_warning(sv <- as_svydesign(d))`;
         `sv` inherits `svyrep.design`; `sv$rho` equals 0.3; `sv$scale`
         equals `1 / (5 * (1 - 0.3)^2)` at 1e-8; the SE of
         `survey::svymean(~y1, sv)` equals the SE of `get_means()` at 1e-8
         and the mean at 1e-10.
       - Fay, `rho = 0`: `sv$rho` equals 0; `sv$scale` equals `1 / 5`.
       - BRR, no `rho`: `expect_no_warning()`; `sv$rho` is `NULL`.
    2. Write a failing test on FA with a domain column added before
       construction: `df[[SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)`,
       Fay, `rho = 0.3`, `sv <- as_svydesign(d)`: `sv$rho` equals 0.3;
       `sv$scale` equals `1 / (10 * (1 - 0.3)^2)` at 1e-8; the SE of
       `survey::svymean(~y1, sv)` equals the SE of
       `get_means(d, y1, variance = "se")` at 1e-8 and the mean at 1e-10.
    3. Write failing tests for CB-4 on designs built by hand with
       `survey_replicate()` on the FC data, `type = "Fay"`:
       - `scale = 1 / 5` and a `variables` list with no `rho` key:
         `expect_error(class = "surveycore_error_fay_rho_unrecoverable")`
         and `expect_snapshot(error = TRUE, ...)`; the message contains
         `rho` and names `as_survey_replicate`.
       - the same with the key `rho = NULL` present: class only.
       - the same with `rho = 1.5` stored: class only.
    4. Rewrite the existing block "as_svydesign() refuses a Fay design that
       records no scale" (no `scale` key, no `rho` key): it asserts
       `surveycore_error_fay_rho_unrecoverable`. Remove its assertion that
       the message contains "none". Its snapshot entry in
       `tests/testthat/_snaps/conversion.md` now shows the new CB-4 text,
       through `testthat::snapshot_review()`.
    5. Write failing tests for an unusable imported `rho`, each on FA
       through `survey::svrepdesign(type = "Fay", ...)`:
       - `rho = 1.5`: `from_svydesign()` raises no condition and stores
         `rho` 1.5; `as_svydesign()` on the result raises
         `surveycore_error_fay_rho_unrecoverable`.
       - `rho = 0.3`, then `src$rho <- NA` by hand: the import raises no
         condition and stores `NA`; the export raises CB-4.
       - `rho = 0.3`, then `src$rho <- NULL` by hand: the import raises no
         condition; `@variables$rho` is `NULL`; the export raises CB-4.
    6. Remove the existing block "as_svydesign() recovers rho = 0 from the
       default Fay scale". The `rho = 0` export test of task 1 replaces it.
    7. In the existing block "as_svydesign() exports a Fay design with its
       scale and SE" (`fay.rho = 0.3`), change no assertion. Rewrite its
       comments, and the X-8 to X-11 lines of the section header list, so
       that they say `rho` is carried and never that it is recovered from the
       scale. Do the same for the comment above the block "as_svydesign()
       warns and converts for every replicate type carrying an FPC" that
       says Fay needs the recovered shrinkage factor.
    8. Implement spec §VI.1 in `.as_svydesign_replicate()`: delete the
       recovery and its comments; for Fay, abort with CB-4 (the template of
       spec §VI.3) when `.is_valid_rho(x@variables$rho)` is `FALSE`, else
       pass `rho = x@variables$rho` and no `scale`; pass `rho = NULL` for
       every other type. The empty-replicate refusal stays first, and the
       FPC drop stays after the Fay check.
    9. Restate row CB-4 in `plans/error-messages.md` with the condition and
       template of spec §VI.3. Remove `{scale_txt}` from the
       svydesign-replicate-bridge binding paragraph. Add under the CB block:
       "CB-4 was restated by issue #243: the export route reads `rho` from
       `@variables$rho` and no longer derives it from the scale."
    10. Verify: the new tests pass, the snapshot is reviewed, and G holds.
  - **Acceptance criteria**
    1. A Fay design built with `rho = 0.3` exports with no warning,
       `$rho` 0.3 and `$scale` `1 / (R * (1 - 0.3)^2)`, and its `survey`
       mean and SE match `get_means()`; this holds on FC and on FA with a
       domain column (3.1, 3.1a).
    2. A Fay design with `rho = 0` exports with `$rho` 0 and `$scale`
       `1 / 5`; a BRR design exports with no warning and `$rho` `NULL`
       (3.2, 3.3).
    3. A hand-built Fay design raises
       `surveycore_error_fay_rho_unrecoverable` when its `rho` key is
       absent (with a snapshot that contains `rho` and names
       `as_survey_replicate`), `NULL`, 1.5, or absent together with the
       `scale` key (3.4, 3.5, 3.6, 3.7).
    4. A `survey` Fay object with `rho` 1.5, `NA` or no `rho` element
       imports with no condition, and its export raises
       `surveycore_error_fay_rho_unrecoverable` (4.5, 4.5a, 4.5b).
    5. The block "as_svydesign() exports a Fay design with its scale and SE"
       passes with no assertion changed (4.7); the block "as_svydesign()
       recovers rho = 0 from the default Fay scale" no longer exists; the
       only change in `tests/testthat/_snaps/conversion.md` is the rewritten
       CB-4 entry and the new CB-4 entry.
    6. `plans/error-messages.md` row CB-4 carries the restated condition and
       template, `{scale_txt}` appears nowhere in the file, and the issue
       #243 sentence sits under the CB block.
    7. No text in `R/methods-conversion.R` says `rho` is recovered or
       derived from the scale.
    8. G.
  - **Files touched**
    - `R/methods-conversion.R`
    - `plans/error-messages.md`
    - `tests/testthat/test-conversion.R`
    - `tests/testthat/_snaps/conversion.md`
  - **Pipeline tier**: recommended

- [x] PR 6: `feature/fay-rho-print` — `print()` and `summary()` show `rho` for a Fay design
  - **Budget** — 5 test-spec rows | 6 criteria
    - Rows: §5 5.1, 5.2, 5.3, 5.4, 5.5
  - **Tasks** — all tests go in `tests/testthat/test-methods-print.R`.
    Fixture: FA built as Fay with `rho = 0.5` (scale 0.4).
    1. Write a failing test: `expect_snapshot(print(d))`. The class line
       reads `<survey_replicate> (FAY, 10 replicates, rho = 0.5)`.
    2. Write a failing test: `expect_snapshot(print(d, full = TRUE))`. The
       line `• Rho: 0.5` comes directly after `• Scale: 0.4`.
    3. Write a failing test: `expect_snapshot(summary(d))`. The type line
       reads `Type: replicate weights (FAY, 10 replicates, rho = 0.5)`, and
       `Rho: 0.5` comes directly after `Scale: 0.4`.
    4. Write a test on a Fay design built by hand with `survey_replicate()`
       and no `rho` key: `expect_snapshot()` of `print(d, full = TRUE)` and
       of `summary(d)`. The snapshot holds no `Rho:` line and no `rho =`
       text.
    5. Implement spec §II `.fay_rho_to_print()` and spec §VII in
       `R/methods-print.R`. Each method calls the helper once and builds the
       `, rho = {rho}` suffix and the `Rho:` line from its value, with
       `{.val {rho}}`.
    6. Verify: review the new snapshots with `testthat::snapshot_review()`.
       Confirm that `git diff` on `tests/testthat/_snaps/methods-print.md`
       shows added entries only. Check G.
  - **Acceptance criteria**
    1. The default print of a Fay design with `rho = 0.5` has the class line
       `<survey_replicate> (FAY, 10 replicates, rho = 0.5)` (5.1).
    2. The full print has `• Rho: 0.5` directly after `• Scale: 0.4` (5.2).
    3. `summary()` has the type line
       `Type: replicate weights (FAY, 10 replicates, rho = 0.5)` and
       `Rho: 0.5` directly after `Scale: 0.4` (5.3).
    4. A Fay design with no `rho` key prints and summarises with no `Rho:`
       line and no `rho =` text (5.4).
    5. `git diff` on `tests/testthat/_snaps/methods-print.md` shows added
       entries only; no existing snapshot changes (5.5).
    6. G.
  - **Files touched**
    - `R/methods-print.R`
    - `tests/testthat/test-methods-print.R`
    - `tests/testthat/_snaps/methods-print.md`
  - **Pipeline tier**: recommended

- [x] PR 7: `test/fay-rho-oracle` — the Fay block in the replicate variance tests becomes a real oracle comparison against `survey`
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §2 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11;
      §6 6.12
  - **Tasks** — all tests go in `tests/testthat/test-variance-replicate.R`.
    Fixture FA, 10 replicate columns.
    1. Rewrite the existing block "survey::svrepdesign() refuses Fay without
       rho — Fay design". It may keep its one assertion of `survey`'s refusal
       without `rho`, matched by the text "With type='Fay' you must supply
       the correct rho". Remove its assertion that surveycore stores `1 / R`
       and its comment that the block compares nothing.
    2. Obey the oracle rule of `.claude/rules/testing-surveycore.md` in
       every comparison below:
       - build both sides from the same frame, weight column and replicate
         columns;
       - pass `mse` explicitly to both sides;
       - pass `scale` to neither side;
       - pass `rho` to both sides as the same literal;
       - never read a number off the surveycore design and pass it to
         `survey`;
       - wrap `survey::svrepdesign()` in `expect_no_warning()`, and wrap
         `as_survey_replicate()` in `expect_no_warning()`;
       - assert each side's stored scale separately against the literal
         `1 / (10 * (1 - rho)^2)` for that comparison's `rho`, at 1e-8, and
         never one side against the other.
    3. Write a comment in the Fay oracle code that states the
       degrees-of-freedom precondition: the bounds agree only while both
       packages use the normal approximation (surveycore uses infinite
       degrees of freedom on the replicate path, and `survey`'s `confint()`
       defaults to `df = Inf`); a move to design-based degrees of freedom
       moves every bound while the mean and SE stay, and must be read as a
       degrees-of-freedom change, not a scale defect.
    4. Write the mean comparisons:
       `get_means(d, y1, variance = c("se", "ci"))` against
       `survey::svymean(~y1, sv)`, `survey::SE()` and `confint()`. Mean
       1e-10, SE 1e-8, `ci_low` and `ci_high` 1e-6. Five cases: `rho` 0.3,
       0, 0.5 and 0.9 with `mse = TRUE`, and `rho = 0.3` with `mse = FALSE`
       on both sides. Scale literals: `1 / (10 * (1 - 0.3)^2)`, `1 / 10`,
       `1 / (10 * (1 - 0.5)^2)`, `1 / (10 * (1 - 0.9)^2)`.
    5. Write the total comparison at `rho = 0.3`, `mse = TRUE`:
       `get_totals(d, y1)` against `survey::svytotal(~y1, sv)`. Total 1e-10,
       SE 1e-8, bounds 1e-6, plus the shared assertions of task 2.
    6. Write the grouped comparison at `rho = 0.3`, `mse = TRUE`:
       `get_means(d, y1, group = group)` against
       `survey::svyby(~y1, ~group, sv, survey::svymean)`. Match rows by group
       level. Per group: mean 1e-10, SE 1e-8, bounds 1e-6, plus the shared
       assertions of task 2.
    7. Write surveycore-only tests on FA:
       - Fay at `rho = 0` against BRR: the two SEs are equal at 1e-8, and
         each stored scale equals `1 / 10`.
       - Fay at `rho = 0.5` against BRR: the Fay SE divided by the BRR SE
         equals 2 at 1e-8; the two means are equal at 1e-10.
       - Fay at `rho = 0.3` with `rscales = rep(2, 10)` against the same
         design with no `rscales`: the first SE divided by the second equals
         `sqrt(2)` at 1e-8.
    8. Write a test on an inline frame with `y1` all `NA`, built as Fay with
       `rho = 0.3` and as BRR. `get_means()` gives the same outcome on both:
       either both return, with identical `NA` positions in `mean` and `se`,
       or both raise the same error class.
    9. Add no `test_invariants()` call. The file already has one for
       `as_survey_replicate()`.
    10. Verify: the tests pass on the installed `survey` version (record it
        in `implementation.md`), `R/variance-replicate.R` is unchanged, and G
        holds.
  - **Acceptance criteria**
    1. At `rho` 0, 0.3, 0.5 and 0.9 with `mse = TRUE`, and at `rho = 0.3`
       with `mse = FALSE`, surveycore's mean, SE and both bounds for `y1`
       match `survey::svymean()` at 1e-10, 1e-8 and 1e-6; both stored scales
       equal `1 / (10 * (1 - rho)^2)` at 1e-8; neither constructor raises a
       warning (2.1, 2.2, 2.3, 2.4, 2.5).
    2. At `rho = 0.3`, surveycore's total, SE and bounds match
       `survey::svytotal()` with the same shared assertions (2.6).
    3. At `rho = 0.3`, the per-group mean, SE and bounds match
       `survey::svyby()` by group level, with the same shared assertions
       (2.7).
    4. Fay at `rho = 0` gives the BRR SE with both scales `1 / 10`; Fay at
       `rho = 0.5` gives twice the BRR SE and the same mean (2.8, 2.9).
    5. `rscales = rep(2, 10)` multiplies the Fay SE by `sqrt(2)` (2.10).
    6. On an all-`NA` outcome, Fay and BRR give the same outcome from
       `get_means()` (2.11).
    7. `git diff develop...HEAD -- R/variance-replicate.R` is empty; the
       rewritten block holds no "compares nothing" comment and holds the
       degrees-of-freedom comment (6.12).
    8. G.
  - **Files touched**
    - `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended — tests only, but this is the numerical
    proof of the moved Fay standard error

- [x] PR 8: `fix/twophase-replicate-phase1` — `as_survey_twophase()` refuses a `survey_replicate` phase 1
  - **Budget** — 9 test-spec rows | 8 criteria
    - Rows: §7 7.1, 7.2, 7.3, 7.4, 7.5, 7.6; §1 1.26; §6 6.10, 6.11
  - **Tasks**
    1. Add register row TP-1 to `plans/error-messages.md`, word for word
       from the planning copy of that file. Restate row 19's template as
       spec §IX.4 gives it.
    2. In `tests/testthat/test-constructors.R`, rewrite the block
       "as_survey_twophase() accepts survey_replicate phase-1" as a failing
       refusal test on FP: phase 1 is
       `as_survey_replicate(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")`,
       then `as_survey_twophase(phase1, subset = in_phase2)`:
       `expect_error(class = "surveycore_error_twophase_replicate_phase1")`
       and `expect_snapshot(error = TRUE, ...)`. The message names
       `as_survey()`.
    3. Move that block's `test_invariants()` call into the block directly
       above it, "as_survey_twophase() accepts survey_taylor phase-1 (weights
       only, no ids/strata)", which still builds a `survey_twophase`. The file
       keeps exactly one `test_invariants()` call for `as_survey_twophase()`.
    4. Write a failing test on FP for a phase 1 of each of the nine types
       (the eight other types with no `rho`, and `"Fay"` with `rho = 0.3`;
       no `rscales`): each raises
       `surveycore_error_twophase_replicate_phase1`. Class only.
    5. Write a failing test on FP, JK1 phase 1, `as_survey_twophase(phase1)`
       with no `subset`: it raises
       `surveycore_error_twophase_replicate_phase1`, not
       `surveycore_error_subset_missing`.
    6. Write a failing test on FA with a logical column that selects half the
       rows (for example `df$half <- rep(c(TRUE, FALSE), length.out = nrow(df))`),
       phase 1 Fay with `rho = 0.3`, then `as_survey_twophase()` with that
       column as `subset`: it raises
       `surveycore_error_twophase_replicate_phase1`. Class only.
    7. Write a test on
       `make_survey_data(n = 200, design = "twophase", seed = 42L)`, phase 1
       `as_survey_nonprob(df, weights = wt)`, then
       `as_survey_twophase(phase1, subset = subset)`:
       `expect_no_error(..., class = "surveycore_error_twophase_replicate_phase1")`.
       Other conditions from the call are outside this test.
    8. Delete the block "as_survey_twophase() carries the phase-1 scale of
       both changed types" in `tests/testthat/test-constructors.R`.
    9. In `tests/testthat/test-variance-twophase.R`, delete the block
       "two-phase with survey_replicate phase-1 constructs and estimates".
       Rename the section header "Section 5: SRS / replicate phase-1
       designs" to "Section 5: SRS phase-1 designs". Add no
       `test_invariants()` call.
    10. Implement spec §IX.2 and §IX.3 in `as_survey_twophase()`: directly
        after the `surveycore_error_phase1_class` check and before any
        `subset` check, abort with the TP-1 template and class when
        `S7::S7_inherits(phase1, survey_replicate)`. Change the
        `surveycore_error_phase1_class` `"i"` bullet to
        `"i" = "Create it first with {.fn as_survey}."`.
    11. Update the snapshot of the existing block "as_survey_twophase()
        errors when phase1 is a data.frame [row 19]" through
        `testthat::snapshot_review()`: the `i` line reads "Create it first
        with `as_survey()`." and no longer names `as_survey_replicate()`.
    12. Write the roxygen of spec §IX.6 for `as_survey_twophase()`
        (`@param phase1` and `@seealso`). Run `devtools::document()`.
    13. Add the `NEWS.md` item of spec §IX.6 under `## Breaking changes` in
        the development version.
    14. Verify: the tests pass, the snapshots are reviewed, and G holds.
  - **Acceptance criteria**
    1. A JK1 phase 1 raises `surveycore_error_twophase_replicate_phase1`,
       and its snapshot shows the TP-1 text and names `as_survey()` (7.1).
    2. A phase 1 of each of the nine replicate types, Fay with `rho = 0.3`
       included, raises the same class, on FP and on FA with a half-rows
       `subset` (7.2, 1.26).
    3. A JK1 phase 1 with no `subset` raises the replicate refusal, not
       `surveycore_error_subset_missing` (7.3).
    4. The survey_taylor phase-1 block still builds a `survey_twophase` and
       holds the file's one `test_invariants()` call for
       `as_survey_twophase()`; a `survey_nonprob` phase 1 does not raise
       the replicate refusal (7.4, 7.5).
    5. A data-frame `phase1` still raises `surveycore_error_phase1_class`,
       and its snapshot `i` line reads "Create it first with
       `as_survey()`."; `plans/error-messages.md` holds row TP-1 and the
       restated row 19 (7.6).
    6. No test block, example, vignette chunk or helper builds a two-phase
       design on a replicate phase 1: the two deleted blocks are gone and
       the section header reads "Section 5: SRS phase-1 designs".
    7. `?as_survey_twophase` no longer says a `survey_replicate` phase 1 is
       accepted, and its See also section no longer links
       `as_survey_replicate()`; `NEWS.md` has a breaking-change item that
       names `surveycore_error_twophase_replicate_phase1` and says it
       reverses PR #74 (6.10, 6.11).
    8. G.
  - **Files touched**
    - `R/core-constructors.R`
    - `man/as_survey_twophase.Rd` (generated)
    - `plans/error-messages.md`
    - `NEWS.md`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
    - `tests/testthat/test-variance-twophase.R`
  - **Pipeline tier**: recommended

- [x] PR 9: `docs/fay-rho-news` — `NEWS.md`, the vignette, `CLAUDE.md` and the oracle rule
  - **Budget** — 5 test-spec rows | 7 criteria
    - Rows: §6 6.4, 6.5, 6.6, 6.7, 6.13
  - **Tasks** — documentation only. No test is written. The checks are
    searches over the files.
    1. `NEWS.md`, development version: rewrite in place the `## Bug fixes`
       entry that begins "`as_svydesign()` now exports a Fay replicate
       design", with the text of spec §VIII.1. Keep its issue references and
       add #243.
    2. `NEWS.md`: add the two `## Breaking changes` items of spec §VIII.1
       (the `rho` argument and the moved Fay SE; the formal order).
    3. `vignettes/creating-survey-objects.Rmd`: apply spec §VIII.2 at line
       299 and line 874.
    4. `CLAUDE.md` line 89: apply spec §VIII.3. Change nothing else in the
       line.
    5. `.claude/rules/testing-surveycore.md`: apply spec §VIII.4. Delete the
       section `### Sanctioned exceptions in test-variance-replicate.R` and
       put the one replacement paragraph in its place. Leave the per-type
       table's Fay row as it is. Change nothing else.
    6. Verify: run the searches in the criteria below, then check G.
  - **Acceptance criteria**
    1. No file under `vignettes/` contains `fay_rho`; line 299 names "The
       Fay shrinkage factor (`rho`)" and says `as_survey_replicate()`
       requires `rho` when `type = "Fay"` (6.4).
    2. `NEWS.md` holds one entry for the Fay export route, and it does not
       say `rho` is recovered from the scale; a breaking-change item says a
       Fay SE is the old SE divided by `1 - rho` and names
       `surveycore_error_fay_rho_missing` (6.5).
    3. `NEWS.md` has a breaking-change item that says `rho` sits after
       `type` and before `scale`, and that `scale`, `rscales`, `fpc`,
       `fpctype`, `mse` and `calibration` each move one position later
       (6.13).
    4. `CLAUDE.md` says the scale recovery was replaced by a stored `rho`
       (issue #243) (6.6).
    5. `.claude/rules/testing-surveycore.md` has no "Sanctioned exceptions"
       section that names a live exception, and its per-type table's Fay row
       still reads `1/(R * (1 - rho)^2)`, "discard, no warning", "honoured"
       (6.7).
    6. Across the arc: no text in `R/`, `man/`, `vignettes/`, `NEWS.md` or
       `CLAUDE.md` says surveycore recovers or derives `rho` from the scale
       or names `fay_rho`, and no text in `R/` or `man/` cites Judkins
       (1990) in the *Journal of the American Statistical Association*
       (spec quality gates 7 and 8).
    7. G.
  - **Files touched**
    - `NEWS.md`
    - `vignettes/creating-survey-objects.Rmd`
    - `CLAUDE.md`
    - `.claude/rules/testing-surveycore.md`
  - **Pipeline tier**: recommended — four files, and it states the moved
    standard error to users

## Write-surface overlap

| Pair | Shared file | Order |
|---|---|---|
| PR 1, PR 2 | `R/core-constructors.R`, `test-constructors.R`, `_snaps/constructors.md`, `man/as_survey_replicate.Rd` | PR 1 first |
| PR 1, PR 3 | `test-constructors.R` | PR 1 first |
| PR 1, PR 4 | `test-conversion.R` | PR 1 first |
| PR 1, PR 5 | `test-conversion.R`, `_snaps/conversion.md`, `plans/error-messages.md` | PR 1 first |
| PR 1, PR 7 | `test-variance-replicate.R` | PR 1 first |
| PR 1, PR 8 | `R/core-constructors.R`, `test-constructors.R`, `_snaps/constructors.md`, `plans/error-messages.md` | PR 1 first |
| PR 2, PR 3 | `test-constructors.R` | PR 2 first |
| PR 2, PR 8 | `R/core-constructors.R`, `test-constructors.R`, `_snaps/constructors.md` | PR 2 first |
| PR 3, PR 8 | `test-constructors.R` | PR 3 first |
| PR 4, PR 5 | `R/methods-conversion.R`, `test-conversion.R` | PR 4 first |
| PR 5, PR 8 | `plans/error-messages.md` | PR 5 first |
| PR 8, PR 9 | `NEWS.md` | PR 8 first |

Every other pair has disjoint write surfaces. PR 6 shares no file with any
other PR. PR 7 shares only `test-variance-replicate.R`, with PR 1.

## Row assignment

| Section | Rows | PR |
|---|---|---|
| §1 | 1.1, 1.2, 1.4a, 1.5, 1.7, 1.10, 1.11 | 1 |
| §1 | 1.3, 1.4, 1.4b, 1.6, 1.8, 1.9, 1.12, 1.13 | 2 |
| §1 | 1.14 to 1.25 (12 rows) | 3 |
| §1 | 1.26 | 8 |
| §2 | 2.1 to 2.11 (11 rows) | 7 |
| §3 | 3.1, 3.1a, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7 | 5 |
| §4 | 4.1, 4.2, 4.3, 4.4, 4.6 | 4 |
| §4 | 4.5, 4.5a, 4.5b, 4.7 | 5 |
| §5 | 5.1 to 5.5 (5 rows) | 6 |
| §6 | 6.1, 6.8, 6.9, 6.14 | 1 |
| §6 | 6.2, 6.3 | 2 |
| §6 | 6.4, 6.5, 6.6, 6.7, 6.13 | 9 |
| §6 | 6.10, 6.11 | 8 |
| §6 | 6.12 | 7 |
| §7 | 7.1 to 7.6 (6 rows) | 8 |

Totals by section: §1 28, §2 11, §3 8, §4 9, §5 5, §6 14, §7 6. Sum 81.
Totals by PR: 11, 10, 12, 5, 12, 5, 12, 9, 5. Sum 81.

The "Existing blocks that change" lists under test-spec §3 and §7 are not
rows. Their edits sit in PR 1 (task 12), PR 4 (tasks 5 and 6), PR 5 (tasks
4, 6 and 7) and PR 8 (tasks 2, 3, 8 and 9).
