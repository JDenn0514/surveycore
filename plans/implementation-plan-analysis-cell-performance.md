# Implementation plan — analysis-cell-performance

**Status**: DRAFT (planner, 2026-11-10)
**Revision**: 2 (plan review pass 1 applied: R-1, D15, D16, D-1, D-2, A-2 to
A-8, S-4, F-1, and the PR 6 title)
**Input state**: SPEC_READY (spec v1.3, test-spec Stage 3r with erratum E-1,
decisions D1 to D16)
**Base commit**: `develop` at `0c0a987`, or the later `develop` commit that
PR 1 is cut from. PR 1 records it.
**PR count**: 9
**Test-spec rows**: 69, each given to exactly one PR (§Row assignment). 63
rows at revision 1; erratum E-1 (decision D16) added 5.3.16, 5.3.17 and
5.5.6 to 5.5.9.

## HOLDs

None open. HOLD-1 of revision 1 is settled by D15 (option A). The reading
of gate 6 it fixes is written into the coverage criteria of PRs 3, 5 and 8.

## How to read this plan

- The builder reads `spec.md` and this plan. The builder never reads
  `test-spec.md`. So this plan writes out every helper, design, scenario id,
  count, class and tolerance the builder needs. §Golden harness reference
  holds the test-side material. Each PR's tasks hold the rest.
- Row ids (4.3.1, 5.2.9 and so on) in the **Budget** and **Acceptance
  criteria** lines are for the tester and the reviewer. Do not put a row id
  in a `test_that()` title.
- All R code, in `R/`, `tests/` and `data-raw/`, follows
  `.claude/rules/code-style.md`.
- Every numeric comparison in the new test file runs at `tolerance = 1e-12`
  (decision D3). It goes through `expect_matches_golden()` or
  `expect_groups_match_domain()`. No block asserts `identical()` on a
  result.
- **Dual** means two assertions on the same call:
  `expect_error(<call>, class = "<class>")` and
  `expect_snapshot(error = TRUE, <call>)`. Every task that says "dual" means
  this.
- A **`simpleError` row** asserts a base R error with
  `expect_error(<call>, class = "simpleError")` and no snapshot: the message
  is base R's and depends on the locale. Before the first `R/` commit, run
  the call on the unchanged code and read the class of the condition it
  raises (`class(tryCatch(<call>, error = identity))` in a scratch session,
  not in a test). The PR description quotes that class. If it is not
  `simpleError`, assert the observed class instead.
- Every warning a new block raises is asserted with
  `expect_warning_count()`. No `withCallingHandlers()`, no `tryCatch()`, no
  `suppressWarnings()` in a test. The generator in `data-raw/` is not a test
  and may use `withCallingHandlers()`.
- `test_invariants()` runs once per constructor, in the first block of the
  new test file (PR 1). No later block calls it.
- No existing test file changes in any PR. Every existing test must pass
  unchanged.
- The fixture `tests/testthat/fixtures/analysis-cell-golden.rds` is written
  once, in PR 1. No later PR writes it. If a later PR finds it needs a new
  scenario, stop and raise a HOLD. The total of 261 scenarios is pinned.

## Order and concurrency

```
PR 1 ── PR 2 ── PR 3 ── PR 4 ── PR 5 ── PR 6 ── PR 7 ── PR 8 ── PR 9
```

The order is strictly linear. One PR is open at a time. Every PR from PR 3
on edits `tests/testthat/test-analysis-cell-equivalence.R` and
`tests/testthat/_snaps/analysis-cell-equivalence.md`, and several share
`R/analysis-helpers.R`, so no two can run at the same time (`spec.md`
§II.6 item 5).

- **PR 1** changes no file under `R/` and captures the golden fixture on the
  base commit (§II.6 item 1). It adds the golden loops for four functions.
- **PR 2** changes no file under `R/` either. It adds the golden loops for
  the other two functions and the second callers, and the cross-function
  rows. After PR 2, every one of the 261 fixture scenarios is asserted
  before any production code changes. `spec.md` §XI checks gates 1 and 2 on
  every PR, so all six functions must be compared from the first production
  PR on. One PR cannot hold all of this inside the 12-row budget.
- **PR 3** (`get_variance()`) is the first production PR. It adds
  `TAYLOR_SE_BLOCK`, `.cell_context()` and `.taylor_cell_se()`, the first
  user of each (§II.6 item 2). Planner note P-1 says why variance comes first
  and why two arguments wait for PR 4.
- **PR 4** (`get_freqs()`) adds the last two helper arguments (`v` on
  `.taylor_cell_se()`, `check_rep_finite` on `.cell_context()`) and the new
  arguments of `.joint_vcov()` and `.attach_joint_vcov()`, with their first
  user.
- **PR 5** (`get_covariance()`) follows. It uses the helpers as PR 4 left
  them.
- **PR 6** (`get_means()`) and **PR 7** (`get_totals()`) follow.
- **PR 8** (`get_ratios()`) needs PR 7: calls 1, 2 and 3 pass `mats`,
  `compute_se` and `rep_mat` to `.total_cell()`, which PR 7 adds.
- **PR 9** runs the §XII.5 block-size measurement after PRs 3, 5 and 8 make
  all three block users use the blocks (§II.6 item 3). It commits the
  selected size, then runs the §XII.1 to §XII.4 speed run, then writes
  `NEWS.md` and the changelog file (§II.6 item 4).

Update each branch from `develop` before you open its PR. Branch protection
needs an up-to-date head branch.

## Shipping constraints

- No PR diff into `develop` may hold a path under `.surveycore-workspace/`.
  Check with `git diff --name-only origin/develop...HEAD`.
- The planning copies under `plans/` ship with PR 1:
  `plans/comprehension-analysis-cell-performance.md`,
  `plans/decisions-analysis-cell-performance.md`,
  `plans/spec-analysis-cell-performance.md`,
  `plans/test-spec-analysis-cell-performance.md` and
  `plans/implementation-plan-analysis-cell-performance.md`. The first four
  are untracked on `develop` today and hold older versions. When PR 1 is
  built, copy the PLAN_READY versions from the run directory over them:
  `spec.md`, `test-spec.md` (with erratum E-1), `decisions.md` (D1 to D16),
  `comprehension.md` and `implementation-plan.md`.
- The §XII timing script is a measurement script, not part of the package.
  No PR commits it. Keep it, and its output, in the run directory.

## Standard gates (criterion G)

Every PR lists criterion **G**. It holds when all of these are true on the
PR's head commit:

1. `devtools::document()` leaves no diff in `man/` or `NAMESPACE` (gate 8).
2. `LANG=C.UTF-8 LC_ALL=C.UTF-8 Rscript -e 'devtools::test()'`: 0 failures,
   and the warning count is exactly **369**, the `develop` baseline (gate 4).
   A PR that adds a snapshot runs the suite twice and reads the count on the
   second run: the first run reports each new snapshot. The PR description
   states the warning count measured (test-spec §8).
3. `devtools::run_examples()` runs clean.
4. `R CMD check --as-cran --no-manual`: read the `Status:` line. A run with
   no `Status:` line died and is not a pass, whatever `run-gates.sh` prints.
   0 errors, 0 warnings. Notes: only the notes a run on `develop` gives
   (gate 5).
5. `pkgdown::build_site()` builds with no errored page.
6. `NOT_CRAN=true Rscript -e "covr::package_coverage()"` is 95% or more. No
   new `# nocov`. Every line the PR adds under `R/` is reached. Check with
   `NOT_CRAN=true Rscript -e "cov <- covr::package_coverage(); z <- covr::zero_coverage(cov); print(z[grepl('^R/analysis-', z\$filename), c('filename', 'line')])"`,
   then compare with `git diff -U0 origin/develop...HEAD -- R`. No added line
   is in the list (gate 6).
7. `air format --check` passes on every `.R` file the PR adds or changes,
   in `R/`, `tests/` and `data-raw/`. `air` is a command-line tool here
   (gate 7).
8. Snapshots change only through `testthat::snapshot_review()`.
   `git diff origin/develop...HEAD -- tests/testthat/_snaps/` shows only the
   new entries the PR's tasks name. No existing entry changes.
9. `git diff --name-only origin/develop...HEAD` lists no path under
   `.surveycore-workspace/`. Every path it lists is in the PR's **Files
   touched**. From PR 2 on it does not list
   `tests/testthat/fixtures/analysis-cell-golden.rds`, and
   `git diff --name-only --diff-filter=M origin/develop...HEAD -- tests` lists
   no file that existed on `develop` before PR 1.
10. The CRAN cookbook scan is clean (`r-package-profile.md`).

## Golden harness reference (transcribed for the builder)

This section is the full content the PR 1 and PR 2 builders need. Later PRs
use the helpers it defines by name.

### H.1 Files

| File | Status | Content |
|---|---|---|
| `tests/testthat/helper-cell-golden.R` | new (PR 1) | Frame and design builders, the scenario list, the expected warnings, the comparison and warning-count helpers |
| `data-raw/analysis-cell-golden.R` | new (PR 1) | The generator. `data-raw/` is in `.Rbuildignore`, so it does not ship. |
| `tests/testthat/fixtures/analysis-cell-golden.rds` | new (PR 1) | The golden fixture |
| `tests/testthat/test-analysis-cell-equivalence.R` | new (PR 1), extended by PRs 2 to 8 | Every new test block |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | new (PR 3), extended by PRs 4 to 8 | Snapshots of the error rows |

The test file starts with a file-level `skip_on_cran()`. The reason is run
time only (decision D13). Write that reason in a comment above the call. Do
not add the fixture or the test file to `.Rbuildignore`: a local
`R CMD check` runs the file and fails when the fixture is missing.

The helper file defines functions and constants only. Nothing runs when it
is sourced. It is sourced before `helper-test-data.R` (name order), so its
functions call `make_survey_data()` only when they run. It calls no
`library()`.

### H.2 Frame builder: `cell_golden_cols(df)`

Takes a frame from `make_survey_data()` (columns `psu`, `strata`, `fpc`,
`wt`, `y1`, `y2`, `y3`, `group`) and returns it with these columns added.
`a1` is the first row with `group == "A"`; `b1` is the first row with
`group == "B"`. Every frame it gets has at least 300 rows.

| Column | Value |
|---|---|
| `f5` | `sample(letters[1:5], nrow(df), replace = TRUE)` inside `withr::with_seed(201L, ...)` |
| `f5_na` | `f5` with `NA` on 25 rows chosen by `sample.int(nrow(df), 25L)` in the same `with_seed()` call |
| `y1_na` | `y1` with `NA` at `b1` |
| `y1_inf` | `y1` with `Inf` at `b1` |
| `y3_na` | `y3` with `NA` at `b1` |
| `y1_c_na` | `y1` with `NA` on every `group == "C"` row |
| `y3_c_na` | `y3` with `NA` on every `group == "C"` row |
| `y1_c_zero` | `y1` with `0` on every `group == "C"` row |
| `y_allna` | `NA_real_` on every row |
| `y2_a_na` | `y2` with `NA` at `a1` |
| `wt_na_out` | `wt` with `NA` at `a1` |
| `wt_na_in` | `wt` with `NA` at `b1` |
| `wt_inf` | `wt` with `Inf` at `b1` |
| `cal_wt` | `wt * 1.01` |
| `p` | `1 / wt` |
| `single` | `"only"` on every row |
| `group_na` | `group` with `NA` at `a1` and at `b1` |
| `g_one` | `"Z"` on row 1, `"Y"` on every other row |
| `g_two` | `"Z"` on rows 1 and 2, `"Y"` on every other row |
| `g16`, `g17`, `g32`, `g33`, `g64`, `g65` | For `gm`: `rep_len(seq_len(m), nrow(df))`, an integer column. Level `j` holds rows `j`, `j + m`, `j + 2m`, and so on. |
| `y1_inf65` | `y1` with `Inf` at row 65 (level 65 of `g65`) |
| `y3_na65` | `y3` with `NA` at row 65 |
| `y1_gap` | `y1` with `NA` on every row where `g65 == 33`, except row 33 |

Use `withr::with_seed()`, not `set.seed()`, so the global random state does
not change. On the `tay` frame (500 rows) each level of `g65` holds 7 or 8
rows.

### H.3 Design builder: `cell_golden_design(name)`

Builds one design by name. Every scenario calls it, so the generator and the
tests build identical designs. All Taylor designs use `nest = TRUE`.
`.testhelper_mark_domain(design, keep)` and `make_all_na_group_design()` are
existing helpers in `tests/testthat/helper-test-data.R`. The domain marker
for every `_dom` design is written with `.testhelper_mark_domain()`
(decision D11).

| Name | Frame | Build |
|---|---|---|
| `tay` | `cell_golden_cols(make_survey_data(seed = 101L))` | `as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt, nest = TRUE)` |
| `tay_lab` | `cell_golden_cols(make_survey_data(seed = 101L, with_labels = TRUE))` | as `tay` |
| `tay_nofpc` | as `tay` | as `tay` without `fpc` |
| `tay_probs` | as `tay` | `as_survey(df, ids = psu, strata = strata, probs = p, nest = TRUE)` |
| `srs` | as `tay` | `as_survey(df, weights = wt)` |
| `strat` | as `tay` | `as_survey(df, strata = strata, weights = wt)` |
| `multi` | `cell_golden_cols(make_survey_data(n = 600L, n_psu = 30L, n_ssu = 3L, n_strata = 5L, seed = 102L))` | `as_survey(df, ids = c(psu, ssu), strata = strata, fpc = c(fpc, fpc2), weights = wt, nest = TRUE)` |
| `lonely` | as `tay`, then `df$strata[df$psu == "psu_1"] <- "stratum_lonely"` | `as_survey(df, ids = psu, strata = strata, weights = wt, nest = TRUE)` |
| `cal` | as `tay`; `cd <- as_caldata(df$wt, rep(1.01, nrow(df)), stats::model.matrix(~y2, df))` | `as_survey(df, ids = psu, strata = strata, weights = cal_wt, nest = TRUE, calibration = list(cd))` |
| `cal_srs` | as `cal` | `as_survey(df, weights = cal_wt, calibration = list(cd))` |
| `cal_strat` | as `cal` | `as_survey(df, strata = strata, weights = cal_wt, calibration = list(cd))` |
| `cal_ids` | as `cal` | `as_survey(df, ids = psu, weights = cal_wt, calibration = list(cd))` |
| `cal_multi` | as `multi`; `cd` built the same way on this frame | `as_survey(df, ids = c(psu, ssu), strata = strata, fpc = c(fpc, fpc2), weights = cal_wt, nest = TRUE, calibration = list(cd))` |
| `rep` | `cell_golden_cols(make_survey_data(n = 500L, n_psu = 50L, design = "replicate", type = "brr", seed = 103L))` (25 replicate columns) | `as_survey_replicate(df, weights = wt, repweights = tidyselect::starts_with("repwt_"), type = "BRR")` |
| `rep_na` | as `rep`, then `df$repwt_3[[b1]] <- NA` | as `rep` |
| `rep_inf` | as `rep`, then `df$repwt_3[[b1]] <- Inf` | as `rep` |
| `rep_zero` | as `rep`, then `df$repwt_3[df$group == "B"] <- 0` | as `rep` |
| `rep_allna` | as `rep`, then every `repwt_*` column `NA` at `b1` | as `rep` |
| `rep_allna_dom` | as `rep`, then every `repwt_*` column `NA` at `a1` | as `rep`, then the domain marker with `keep = seq_len(nrow(df)) != a1` |
| `np_rep` | as `rep` | `as_survey_nonprob(df, weights = wt, repweights = tidyselect::starts_with("repwt_"))` |
| `np_rep_na` | as `rep_na` | as `np_rep` |
| `np_rep10_na` | `cell_golden_cols(make_survey_data(n = 300L, n_psu = 20L, design = "replicate", type = "brr", seed = 104L))` (10 replicate columns), then `df$repwt_3[[a1]] <- NA` | as `np_rep` |
| `np_rep10_na_dom` | as `np_rep10_na` | `np_rep10_na`, then the domain marker with `keep = seq_len(nrow(df)) != a1` |
| `np_srs` | as `tay` | `as_survey_nonprob(df, weights = wt)` |
| `tph` | `cell_golden_cols(make_survey_data(n = 500L, n_psu = 50L, design = "twophase", seed = 105L))` | `as_survey_twophase(as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt, nest = TRUE), subset = subset, method = "approx")` |
| `tay_dom`, `rep_dom`, `cal_dom`, `np_rep_dom`, `np_srs_dom` | as the design without `_dom` | that design, then the domain marker with `keep = df$y2 > -0.5` |
| `tph_dom` | as `tph` | `tph`, then the domain marker with `keep = df$y2 > -0.5`, after `keep[which(!df$subset)[[1L]]] <- TRUE`, so at least one phase-1-only row is marked `TRUE` |
| `tay_empty_dom` | as `tay` | `tay`, then the domain marker with `keep = rep(FALSE, nrow(df))` |
| `nawt_out` | as `tay` | `as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt_na_out, nest = TRUE)` |
| `nawt_in` | as `tay` | as `nawt_out` with `weights = wt_na_in` |
| `infwt` | as `tay` | as `nawt_out` with `weights = wt_inf` |
| `gss` | `gss_2024`, recoded below | `as_survey(gss, ids = vpsu, strata = vstrat, weights = wtssps, nest = TRUE)` |
| `allna_grp` | — | `make_all_na_group_design()` (columns `y1`, `y2`, `y3`, and `grp`, which is `NA` on every row) |

GSS recode: for `age`, `educ`, `degree`, `race`, `sex`, `partyid` and
`happy`, replace the column with `as.numeric(unclass(v))` and set negative
values to `NA`. This also drops their label attributes.

`as_survey()` accepts an `NA` or `Inf` base weight (it checks only the
non-`NA` values for positivity), and the classes accept `NA` and `Inf`
replicate weights. All these designs build without error.

### H.4 Standard options `<std>`

Unless a scenario says otherwise, it passes:

```r
variance = c("se", "ci", "var", "cv", "moe", "deff"),
n_weighted = TRUE,
min_cell_n = 0L
```

This plan writes these three arguments as `<std>`. No scenario passes
`decimals`.

### H.5 Shared helpers (all in `tests/testthat/helper-cell-golden.R`)

**`cell_golden_fixture()`**: no arguments. Returns
`readRDS(testthat::test_path("fixtures", "analysis-cell-golden.rds"))`.
Calls `stop()` with a message that names the path when the file does not
exist. It never skips.

**`cell_golden_strip(x)`**: takes one result. Returns `x` with the `call`
element of `attr(x, ".meta")` removed:
`meta <- attr(x, ".meta"); meta$call <- NULL; attr(x, ".meta") <- meta`.
When `x` has no `.meta`, or its `.meta` has no `call`, it returns `x`
unchanged. It removes nothing else.

**`expect_matches_golden(object, expected, label)`**:

1. `object <- cell_golden_strip(object)`.
2. `expect_equal(object, expected, tolerance = 1e-12, label = label)`.
3. For every double column, and for `attr(, ".vcov")`:
   `expect_identical(is.nan(object_part), is.nan(expected_part))`. The
   tolerance comparison treats `NaN` and `NA` as equal; this step keeps the
   two apart.

`label` is the scenario id.

**`expect_warning_count(expr, class, n)`**: asserts that `expr` raises
exactly `n` warnings, one of each class in `class`, and returns the value of
`expr`. Write it as given:

```r
expect_warning_count <- function(expr, class, n) {
  class <- rep_len(class, n)
  value <- NULL
  nest <- function(i) {
    if (i > n) {
      value <<- expr
      return(invisible(NULL))
    }
    expect_warning(nest(i + 1L), class = class[[i]])
  }
  expect_no_warning(nest(1L))
  invisible(value)
}
```

`n = 0L` with `class = character(0)` asserts no warning.

**`cell_core_calls(d, freqs_x = "f5", min_cell_n = 0L)`**: a named list of
six zero-argument functions, `freqs`, `means`, `totals`, `variance`,
`covariance`, `ratios`. Each runs its core call (§H.6 table "Core call") on
`d` with `variance = c("se", "ci", "var", "cv", "moe", "deff")`,
`n_weighted = TRUE` and the given `min_cell_n`. The `freqs` entry selects its
variable with `tidyselect::all_of(freqs_x)`. Example entry:

```r
means = function() {
  get_means(
    d,
    y1,
    group = group,
    variance = c("se", "ci", "var", "cv", "moe", "deff"),
    n_weighted = TRUE,
    min_cell_n = min_cell_n
  )
}
```

**`expect_groups_match_domain(id, design, ungrouped, estimate, groups =
c("A", "C"))`**: runs scenario `id` (grouped). For each group `g`, it builds
`cell_golden_design(design)`, marks it with
`.testhelper_mark_domain(d, survey_data(d)$group == g)`, and runs
`ungrouped(marked)`. It asserts with `expect_equal(tolerance = 1e-12)` that
the `estimate` column and the `se` column of the grouped rows where
`group == g` equal those of the ungrouped result, row by row, names dropped.

**`cell_golden_scenarios()`**: a named list of zero-argument functions, one
per scenario id (§H.6). Each builds its design with `cell_golden_design()`
and returns the result.

**`cell_golden_noisy`**: a named list from noisy id to the character vector
of full warning classes, one element per warning (§H.6, table 3.3).

### H.6 Scenario catalogue (261 scenarios)

A scenario id is `"<function>/<name>"`. **261 scenarios**: 120 core, 104
extra, 37 noisy.

**Core set (120).** Core designs (20): `tay`, `tay_nofpc`, `tay_probs`,
`srs`, `strat`, `multi`, `lonely_remove`, `lonely_adjust`, `lonely_average`,
`lonely_certainty`, `cal`, `rep`, `np_rep`, `tph`, `tay_dom`, `rep_dom`,
`cal_dom`, `np_rep_dom`, `tph_dom`, `tay_fail`. The id is
`"<function>/<design>"`, for example `"variance/lonely_adjust"`.

- `lonely_<option>` is the `lonely` design with
  `withr::local_options(survey.lonely.psu = "<option>")` set inside the
  scenario function.
- `tay_fail` is the `tay` design (no single-PSU stratum) under
  `survey.lonely.psu = "fail"`, set the same way.

| Function | Core call |
|---|---|
| `freqs` | `get_freqs(d, f5, group = group, <std>)` |
| `means` | `get_means(d, y1, group = group, <std>)` |
| `totals` | `get_totals(d, y1, group = group, <std>)` |
| `variance` | `get_variance(d, c(y1, y2), group = group, <std>)` |
| `covariance` | `get_covariance(d, c(y1, y2, y3), group = group, <std>)` |
| `ratios` | `get_ratios(d, y3, y1, group = group, <std>)` |

**Extra scenarios (104).** In each call the design name stands for
`cell_golden_design("<name>")`.

`get_freqs()` (12):

| Id | Call |
|---|---|
| `freqs/tay_ungrouped` | `get_freqs(tay, f5, <std>)` |
| `freqs/tay_multi_na` | `get_freqs(tay, c(y3, f5_na), na.rm = FALSE, <std>)` |
| `freqs/tay_two_groups` | `get_freqs(tay, y3, group = c(group, f5), <std>)` |
| `freqs/tay_default_variance` | `get_freqs(tay, f5, group = group, min_cell_n = 0L)` |
| `freqs/cal_srs` | `get_freqs(cal_srs, f5, group = group, <std>)` |
| `freqs/gss` | `get_freqs(gss, partyid, group = race, <std>)` |
| `freqs/gss_multi` | `get_freqs(gss, c(partyid, happy), <std>)` |
| `freqs/rep_na` | `get_freqs(rep_na, f5, group = group, <std>)` |
| `freqs/rep_inf` | `get_freqs(rep_inf, f5, group = group, <std>)` |
| `freqs/rep_zero` | `get_freqs(rep_zero, f5, group = group, <std>)` |
| `freqs/np_rep_na` | `get_freqs(np_rep_na, f5, group = group, <std>)` |
| `freqs/lab_broom` | `get_freqs(tay_lab, y3, group = group, label_values = TRUE, label_vars = TRUE, name_style = "broom", <std>)` |

`get_means()` (23):

| Id | Call |
|---|---|
| `means/tay_ungrouped` | `get_means(tay, y1, <std>)` |
| `means/tay_two_groups` | `get_means(tay, y1, group = c(group, f5), <std>)` |
| `means/tay_default_variance` | `get_means(tay, y1, group = group, min_cell_n = 0L)` |
| `means/cal_srs` | `get_means(cal_srs, y1, group = group, <std>)` |
| `means/cal_strat` | `get_means(cal_strat, y1, group = group, <std>)` |
| `means/cal_ids` | `get_means(cal_ids, y1, group = group, <std>)` |
| `means/cal_multi` | `get_means(cal_multi, y1, group = group, <std>)` |
| `means/gss` | `get_means(gss, age, group = degree, <std>)` |
| `means/gss_two_groups` | `get_means(gss, age, group = c(sex, race), <std>)` |
| `means/tay_y1_na` | `get_means(tay, y1_na, group = group, na.rm = FALSE, <std>)` |
| `means/cal_y1_na` | `get_means(cal, y1_na, group = group, na.rm = FALSE, <std>)` |
| `means/multi_y1_na` | `get_means(multi, y1_na, group = group, na.rm = FALSE, <std>)` |
| `means/tay_y1_inf` | `get_means(tay, y1_inf, group = group, <std>)` |
| `means/tay_c_na` | `get_means(tay, y1_c_na, group = group, <std>)` |
| `means/tay_allna` | `get_means(tay, y_allna, <std>)` |
| `means/tay_empty_dom` | `get_means(tay_empty_dom, y1, <std>)` |
| `means/tay_group_na` | `get_means(tay, y1, group = group_na, na.rm = FALSE, <std>)` |
| `means/rep_na` | `get_means(rep_na, y1, group = group, <std>)` |
| `means/rep_inf` | `get_means(rep_inf, y1, group = group, <std>)` |
| `means/rep_y1_inf` | `get_means(rep, y1_inf, group = group, <std>)` |
| `means/np_rep_y1_inf` | `get_means(np_rep, y1_inf, group = group, <std>)` |
| `means/infwt` | `get_means(infwt, y1, <std>)` |
| `means/lab_broom` | `get_means(tay_lab, y1, group = group, label_values = TRUE, label_vars = TRUE, name_style = "broom", <std>)` |

`get_totals()` (12):

| Id | Call |
|---|---|
| `totals/tay_ungrouped` | `get_totals(tay, y1, <std>)` |
| `totals/tay_categorical` | `get_totals(tay, f5, group = group, <std>)` |
| `totals/tay_popsize` | `get_totals(tay, group = group, <std>)` |
| `totals/gss` | `get_totals(gss, age, group = degree, <std>)` |
| `totals/tay_y1_na` | `get_totals(tay, y1_na, group = group, na.rm = FALSE, <std>)` |
| `totals/multi_y1_na` | `get_totals(multi, y1_na, group = group, na.rm = FALSE, <std>)` |
| `totals/tay_y1_inf` | `get_totals(tay, y1_inf, group = group, <std>)` |
| `totals/tay_c_na` | `get_totals(tay, y1_c_na, group = group, <std>)` |
| `totals/tay_empty_dom` | `get_totals(tay_empty_dom, y1, <std>)` |
| `totals/rep_na` | `get_totals(rep_na, y1, group = group, <std>)` |
| `totals/rep_inf` | `get_totals(rep_inf, y1, group = group, <std>)` |
| `totals/infwt` | `get_totals(infwt, y1, <std>)` |

`get_variance()` (18):

| Id | Call |
|---|---|
| `variance/tay_one_cell` | `get_variance(tay, y1, <std>)` |
| `variance/tay_ungrouped` | `get_variance(tay, c(y1, y2), <std>)` |
| `variance/tay_listwise` | `get_variance(tay, c(y1, y1_na), group = group, na_handling = "listwise", <std>)` |
| `variance/tay_narm_false` | `get_variance(tay, c(y1, y1_na), group = group, na.rm = FALSE, <std>)` |
| `variance/tay_many` | `get_variance(tay, c(y1, y2, y3, y1_na, y2_a_na), group = c(group, f5), <std>)` |
| `variance/tay_c_na` | `get_variance(tay, c(y1, y1_c_na, y2), group = group, <std>)` |
| `variance/tay_empty_dom` | `get_variance(tay_empty_dom, c(y1, y2), <std>)` |
| `variance/gss` | `get_variance(gss, age, group = degree, <std>)` |
| `variance/tay_y1_inf` | `get_variance(tay, y1_inf, group = group, <std>)` |
| `variance/nawt_out` | `get_variance(nawt_out, y2_a_na, group = group, <std>)` |
| `variance/rep_na` | `get_variance(rep_na, c(y1, y2), group = group, <std>)` |
| `variance/blk16` | `get_variance(tay, y1, group = g16, <std>)` |
| `variance/blk17` | `get_variance(tay, y1, group = g17, <std>)` |
| `variance/blk32` | `get_variance(tay, y1, group = g32, <std>)` |
| `variance/blk33` | `get_variance(tay, y1, group = g33, <std>)` |
| `variance/blk64` | `get_variance(tay, y1, group = g64, <std>)` |
| `variance/blk65` | `get_variance(tay, y1, group = g65, <std>)` |
| `variance/blk65_inf` | `get_variance(tay, y1_inf65, group = g65, <std>)` |

`get_covariance()` (18):

| Id | Call |
|---|---|
| `covariance/tay_pair` | `get_covariance(tay, c(y1, y2), <std>)` |
| `covariance/tay_ungrouped` | `get_covariance(tay, c(y1, y2, y3), <std>)` |
| `covariance/tay_full` | `get_covariance(tay, c(y1, y2, y3), group = group, redundant = TRUE, diagonal = TRUE, <std>)` |
| `covariance/tay_narm_false` | `get_covariance(tay, c(y1, y1_na, y2), group = group, na.rm = FALSE, <std>)` |
| `covariance/tay_many` | `get_covariance(tay, c(y1, y2, y3), group = c(group, f5), diagonal = TRUE, <std>)` |
| `covariance/tay_c_na` | `get_covariance(tay, c(y1, y1_c_na, y2), group = group, <std>)` |
| `covariance/tay_empty_dom` | `get_covariance(tay_empty_dom, c(y1, y2), <std>)` |
| `covariance/gss` | `get_covariance(gss, c(age, educ), group = degree, <std>)` |
| `covariance/tay_y1_inf` | `get_covariance(tay, c(y1_inf, y2), group = group, <std>)` |
| `covariance/nawt_out` | `get_covariance(nawt_out, c(y2_a_na, y1), group = group, <std>)` |
| `covariance/rep_na` | `get_covariance(rep_na, c(y1, y2), group = group, <std>)` |
| `covariance/blk16` | `get_covariance(tay, c(y1, y2), group = g16, <std>)` |
| `covariance/blk17` | `get_covariance(tay, c(y1, y2), group = g17, <std>)` |
| `covariance/blk32` | `get_covariance(tay, c(y1, y2), group = g32, <std>)` |
| `covariance/blk33` | `get_covariance(tay, c(y1, y2), group = g33, <std>)` |
| `covariance/blk64` | `get_covariance(tay, c(y1, y2), group = g64, <std>)` |
| `covariance/blk65` | `get_covariance(tay, c(y1, y2), group = g65, <std>)` |
| `covariance/blk65_inf` | `get_covariance(tay, c(y1_inf65, y2), group = g65, <std>)` |

`get_ratios()` (17):

| Id | Call |
|---|---|
| `ratios/tay_ungrouped` | `get_ratios(tay, y3, y1, <std>)` |
| `ratios/gss` | `get_ratios(gss, educ, age, group = degree, <std>)` |
| `ratios/tay_num_na` | `get_ratios(tay, y3_na, y1, group = group, na.rm = FALSE, <std>)` |
| `ratios/tay_den_na` | `get_ratios(tay, y3, y1_na, group = group, na.rm = FALSE, <std>)` |
| `ratios/multi_num_na` | `get_ratios(multi, y3_na, y1, group = group, na.rm = FALSE, <std>)` |
| `ratios/tay_c_zero_den` | `get_ratios(tay, y3_c_na, y1_c_zero, group = group, na.rm = FALSE, <std>)` |
| `ratios/tay_c_na` | `get_ratios(tay, y3_c_na, y1, group = group, <std>)` |
| `ratios/tay_empty_dom` | `get_ratios(tay_empty_dom, y3, y1, <std>)` |
| `ratios/tay_allna` | `get_ratios(tay, y_allna, y1, <std>)` |
| `ratios/rep_na` | `get_ratios(rep_na, y3, y1, group = group, <std>)` |
| `ratios/blk16` | `get_ratios(tay, y3, y1, group = g16, <std>)` |
| `ratios/blk17` | `get_ratios(tay, y3, y1, group = g17, <std>)` |
| `ratios/blk32` | `get_ratios(tay, y3, y1, group = g32, <std>)` |
| `ratios/blk33` | `get_ratios(tay, y3, y1, group = g33, <std>)` |
| `ratios/blk64` | `get_ratios(tay, y3, y1, group = g64, <std>)` |
| `ratios/blk65` | `get_ratios(tay, y3, y1, group = g65, <std>)` |
| `ratios/blk65_na` | `get_ratios(tay, y3_na65, y1, group = g65, na.rm = FALSE, <std>)` |

Second callers (4):

| Id | Call |
|---|---|
| `quantiles/tay` | `get_quantiles(tay, y1, group = group, variance = c("se", "ci"), min_cell_n = 0L)` |
| `quantiles/rep` | as above on `rep` |
| `quantiles/cal` | as above on `cal` |
| `effn/tay` | `get_effective_n(tay, y1, group = group, method = "deff", min_cell_n = 0L)` |

**Noisy scenarios (37).** Each raises warnings on the base commit. The
"Expected warnings" column is the starting content of `cell_golden_noisy`.
Every class starts with `surveycore_warning_`; write the full class in the
helper.

| Id | Call | Expected warnings |
|---|---|---|
| `freqs/np_srs` | `get_freqs(np_srs, y3, <std>)` | 2 × `nonprob_srs_fallback` |
| `freqs/single` | `get_freqs(tay, f5, group = single, <std>)` | 1 × `single_level` |
| `freqs/np_rep10_na_dom` | `get_freqs(np_rep10_na_dom, y3, <std>)` | 2 × `domain_replicates_na` |
| `freqs/tay_empty_dom` | `get_freqs(tay_empty_dom, f5, <std>)` | 1 × `all_na_freqs` |
| `means/np_srs` | `get_means(np_srs, y1, group = group, <std>)` | 3 × `nonprob_srs_fallback` |
| `means/single` | `get_means(tay, y1, group = single, <std>)` | 1 × `single_level` |
| `means/zero_combos` | `get_means(allna_grp, y1, group = grp, <std>)` | 1 × `single_level` |
| `means/small_cell` | `get_means(tay, y1, group = c(group, f5), variance = c("se", "ci", "var", "cv", "moe", "deff"), n_weighted = TRUE, min_cell_n = 1000L)` | 1 × `small_cell` |
| `means/np_rep_y1_na` | `get_means(np_rep, y1_na, group = group, na.rm = FALSE, <std>)` | 1 × `domain_replicates_na` |
| `means/np_srs_dom` | `get_means(np_srs_dom, y1, group = group, <std>)` | 3 × `nonprob_srs_fallback` |
| `means/cal_srs_two` | `get_means(cal_srs, y1, group = g_two, <std>)` | 1 × `zero_df_after_calibration` |
| `totals/np_srs` | `get_totals(np_srs, y1, group = group, <std>)` | 3 × `nonprob_srs_fallback` |
| `totals/single` | `get_totals(tay, y1, group = single, <std>)` | 1 × `single_level` |
| `totals/zero_combos` | `get_totals(allna_grp, y1, group = grp, <std>)` | 1 × `single_level` |
| `totals/small_cell` | `get_totals(tay, y1, group = group, variance = c("se", "ci", "var", "cv", "moe", "deff"), n_weighted = TRUE, min_cell_n = 1000L)` | 1 × `small_cell` |
| `totals/tay_allna` | `get_totals(tay, y_allna, <std>)` | 1 × `all_na_totals` |
| `totals/np_rep10_na_dom` | `get_totals(np_rep10_na_dom, y1, <std>)` | 1 × `domain_replicates_na` |
| `variance/np_srs` | `get_variance(np_srs, y1, <std>)` | 1 × `nonprob_srs_fallback` |
| `variance/single` | `get_variance(tay, y1, group = single, <std>)` | 1 × `single_level` |
| `variance/zero_combos` | `get_variance(allna_grp, c(y1, y2), group = grp, <std>)` | 1 × `single_level` |
| `variance/small_cell` | `get_variance(tay, y1, group = group, variance = c("se", "ci", "var", "cv", "moe", "deff"), n_weighted = TRUE, min_cell_n = 1000L)` | 1 × `small_cell` |
| `variance/tay_allna` | `get_variance(tay, y_allna, <std>)` | 1 × `variance_all_na` |
| `variance/tay_one` | `get_variance(tay, y1, group = g_one, <std>)` | 1 × `variance_insufficient_n` |
| `variance/np_rep10_na` | `get_variance(np_rep10_na, y1, group = group, <std>)` | 1 × `domain_replicates_na` |
| `variance/blk65_gap` | `get_variance(tay, y1_gap, group = g65, <std>)` | 1 × `variance_insufficient_n` |
| `covariance/np_srs` | `get_covariance(np_srs, c(y1, y2), <std>)` | 1 × `nonprob_srs_fallback` |
| `covariance/single` | `get_covariance(tay, c(y1, y2), group = single, <std>)` | 1 × `single_level` |
| `covariance/zero_combos` | `get_covariance(allna_grp, c(y1, y2), group = grp, <std>)` | 1 × `single_level` |
| `covariance/small_cell` | `get_covariance(tay, c(y1, y2), group = group, variance = c("se", "ci", "var", "cv", "moe", "deff"), n_weighted = TRUE, min_cell_n = 1000L)` | 1 × `small_cell` |
| `covariance/tay_allna` | `get_covariance(tay, c(y_allna, y1), <std>)` | 1 × `covariance_all_na` |
| `covariance/tay_one` | `get_covariance(tay, c(y1, y2), group = g_one, <std>)` | 1 × `covariance_insufficient_n` |
| `covariance/np_rep10_na` | `get_covariance(np_rep10_na, c(y1, y2), group = group, <std>)` | 1 × `domain_replicates_na` |
| `ratios/np_srs` | `get_ratios(np_srs, y3, y1, <std>)` | 3 × `nonprob_srs_fallback` |
| `ratios/single` | `get_ratios(tay, y3, y1, group = single, <std>)` | 1 × `single_level` |
| `ratios/zero_combos` | `get_ratios(allna_grp, y3, y1, group = grp, <std>)` | 1 × `single_level` |
| `ratios/small_cell` | `get_ratios(tay, y3, y1, group = group, variance = c("se", "ci", "var", "cv", "moe", "deff"), n_weighted = TRUE, min_cell_n = 1000L)` | 1 × `small_cell` |
| `ratios/np_rep10_na_dom` | `get_ratios(np_rep10_na_dom, y3, y1, <std>)` | 3 × `domain_replicates_na` |

**The fixture's recorded warnings win.** Many counts above are reasoned,
not measured. After the generator runs, compare `cell_golden_noisy` with the
fixture's `warnings` entry and correct the helper to the recorded classes
and counts. If a core or extra scenario records a warning, move it into
`cell_golden_noisy`. If a noisy scenario records none, take it out. The
total of 261 does not change. List every correction in the PR description.

### H.7 Quiet ids, noisy ids, and the two loop bodies

- A **quiet id** has an empty `fixture$warnings` entry and is not in
  `cell_golden_noisy`. A **noisy id** is in `cell_golden_noisy`.
- **Quiet loop body.** For each quiet id of the function (ids that start
  with `"<function>/"`): `r <- expect_warning_count(scenarios[[id]](),
  character(0), 0L)`, then `expect_matches_golden(r, fixture$results[[id]],
  id)`.
- **Noisy loop body.** For each noisy id of the function:
  `r <- expect_warning_count(scenarios[[id]](), cell_golden_noisy[[id]],
  length(cell_golden_noisy[[id]]))`, then `expect_matches_golden(r,
  fixture$results[[id]], id)`.
- **Loop rule.** Every block that loops over ids first asserts
  `expect_gt(length(ids), 0L)`.
- Every block reads the fixture with `fixture <- cell_golden_fixture()` and
  the scenarios with `scenarios <- cell_golden_scenarios()`.

## PR map

- [ ] PR 1: `test/analysis-cell-golden-fixture` — the golden harness, the
  fixture captured on the base commit, and the golden loops of
  `get_freqs()`, `get_means()`, `get_totals()` and `get_variance()`
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §4 4.0, 4.1, 4.2, 4.3.1, 4.3.2, 4.4.1, 4.4.2, 4.5.1, 4.5.2,
      4.6.1, 4.6.2; §5 5.2.2
  - **Tasks**
    1. Copy the PLAN_READY run-directory versions of `spec.md`,
       `test-spec.md`, `decisions.md`, `comprehension.md` and
       `implementation-plan.md` to the five `plans/` paths of §Shipping
       constraints, over the older untracked copies, and commit them. Record
       the base commit: `git rev-parse origin/develop` at the moment the branch
       is cut. Write it in the PR description (decision D14).
    2. Write `tests/testthat/helper-cell-golden.R` with every function and
       constant of §H.2, §H.3 and §H.5, the catalogue of §H.6 in
       `cell_golden_scenarios()`, and the noisy table in `cell_golden_noisy`.
       Each scenario function takes no argument and builds its design inside
       the function.
    3. Write `data-raw/analysis-cell-golden.R`. Run as
       `git worktree add <dir> <base-sha>`, then
       `Rscript data-raw/analysis-cell-golden.R <dir> <base-sha>` from the
       root of the working tree. In order, it:
       1. reads the source-tree path from its first argument and the base
          commit from its second;
       2. stops, naming the check, if `git -C <dir> rev-parse HEAD` is not
          the commit `git -C <dir> rev-parse <base-sha>` gives; if
          `git -C <dir> status --porcelain -- R` prints anything; or if
          `git -C <dir> diff --quiet <base-sha> -- R` exits non-zero;
       3. runs `pkgload::load_all(<dir>, helpers = FALSE, quiet = TRUE)`;
       4. sources `tests/testthat/helper-test-data.R` and
          `tests/testthat/helper-cell-golden.R` from the current tree;
       5. runs every scenario. It records the first class of every warning
          a scenario raises, in order, and muffles it
          (`withCallingHandlers()` is allowed here). If a scenario errors,
          it stops and names the id;
       6. applies `cell_golden_strip()` to each result and saves, with
          `saveRDS(compress = "xz")`, to
          `tests/testthat/fixtures/analysis-cell-golden.rds`:

       ```r
       list(
         provenance = list(
           base_sha = <git -C dir rev-parse HEAD>,
           r_version = R.version.string,
           blas = extSoftVersion()[["BLAS"]],
           lapack = La_library(),
           matprod = getOption("matprod"),
           created = <UTC timestamp>
         ),
         formals = <named list: formals() of the six functions>,
         results = <named list: one result per scenario id>,
         warnings = <named list: character vector of warning classes per id>
       )
       ```

       The `formals` names are `get_freqs`, `get_means`, `get_totals`,
       `get_variance`, `get_covariance`, `get_ratios`.
    4. Check the guard first: add one line to any file under `<dir>/R` and
       run the generator. It stops before it loads the package, and its
       message names the `status --porcelain` check. Copy the message into
       the PR description. Remove the edit, confirm `git -C <dir> status
       --porcelain` prints nothing, and run the generator clean.
       Size budget for the fixture: 300 KB. Report a larger file in the PR
       description.
    5. Reconcile `cell_golden_noisy` with the fixture's `warnings` entry, as
       §H.6 "The fixture's recorded warnings win" states. In the PR
       description, list each id moved and each count changed. Also state
       whether `means/rep_y1_inf` and `means/np_rep_y1_inf` recorded no
       warning; PR 6 relies on both being quiet.
    6. Write `tests/testthat/test-analysis-cell-equivalence.R`, starting with
       the file-level `skip_on_cran()` and its comment. Write these blocks,
       in this order:
       - "the golden fixture designs build and pass the design invariants":
         `test_invariants()` once each on `cell_golden_design("tay")`
         (`as_survey()`), `cell_golden_design("rep")`
         (`as_survey_replicate()`), `cell_golden_design("tph")`
         (`as_survey_twophase()`) and `cell_golden_design("np_srs")`
         (`as_survey_nonprob()`).
       - "every golden scenario is asserted by at least one block": with
         `fixture <- cell_golden_fixture()`:
         (a) `expect_setequal(names(fixture$results), names(cell_golden_scenarios()))`;
         (b) `expect_length(fixture$results, 261L)`;
         (c) `expect_setequal(names(fixture$warnings), names(fixture$results))`;
         (d) `expect_setequal(names(cell_golden_noisy), names(Filter(length, fixture$warnings)))`;
         (e) for each noisy id,
         `expect_identical(sort(cell_golden_noisy[[id]]), sort(fixture$warnings[[id]]))`.
       - "the six analysis functions keep their base-commit formals": for
         each of the six names, `expect_identical(formals(fn),
         fixture$formals[[name]])`.
       - The quiet loop body of §H.7 for `freqs`, `means`, `totals`,
         `variance`, one block each, titles: "get_freqs() matches the
         base-commit results on every quiet scenario", "get_means() matches
         the base-commit results on every quiet scenario", "get_totals()
         matches the base-commit results on every quiet scenario",
         "get_variance() matches the base-commit results on every quiet
         scenario".
       - The noisy loop body of §H.7 for the same four functions, titles:
         "get_freqs() raises the base-commit warnings and results on every
         noisy scenario", and the same with `get_means()`, `get_totals()`,
         `get_variance()`.
    7. Run the new file on the unchanged code. Every block passes. In a
       scratch session (not committed), load one fixture result, multiply
       one `se` value by `1 + 1e-10`, and confirm `expect_matches_golden()`
       fails on it. Write the result in the PR description.
    8. Verify: every block passes, `freqs/rep_zero` is a quiet id, and G
       holds.
  - **Acceptance criteria**
    1. "the golden fixture designs build and pass the design invariants"
       and "the six analysis functions keep their base-commit formals" pass
       (4.0, 4.2).
    2. "every golden scenario is asserted by at least one block" passes,
       with the fixture holding 261 results (4.1).
    3. The generator guard works: with one line added under `<dir>/R`, the
       generator stops, writes no fixture, and its message names the
       `status --porcelain` check. The PR description quotes the message.
    4. The four quiet blocks for `get_freqs()`, `get_means()`,
       `get_totals()` and `get_variance()` pass, and `freqs/rep_zero` is
       among the quiet ids of the `get_freqs()` block (4.3.1, 4.4.1, 4.5.1,
       4.6.1, 5.2.2).
    5. The four noisy blocks for the same functions pass (4.3.2, 4.4.2,
       4.5.2, 4.6.2).
    6. The fixture's `provenance$base_sha` equals the base commit in the PR
       description, and that commit is `origin/develop` at branch cut. The
       fixture is `xz`-compressed, and its size is 300 KB or less or is
       reported. The PR description lists the noisy-table corrections and
       the perturbation check of task 7.
    7. `git diff --name-only origin/develop...HEAD -- R` prints nothing.
    8. G.
  - **Files touched**
    - `plans/comprehension-analysis-cell-performance.md`
    - `plans/decisions-analysis-cell-performance.md`
    - `plans/spec-analysis-cell-performance.md`
    - `plans/test-spec-analysis-cell-performance.md`
    - `plans/implementation-plan-analysis-cell-performance.md`
    - `tests/testthat/helper-cell-golden.R` (new)
    - `data-raw/analysis-cell-golden.R` (new)
    - `tests/testthat/fixtures/analysis-cell-golden.rds` (new)
    - `tests/testthat/test-analysis-cell-equivalence.R` (new)
  - **Pipeline tier**: recommended

- [ ] PR 2: `test/analysis-cell-golden-cross` — the golden loops of
  `get_covariance()`, `get_ratios()` and the second callers, and the
  cross-function rows
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §4 4.7.1, 4.7.2, 4.8.1, 4.8.2, 4.9.1; §5 5.2.1, 5.2.3, 5.3.13,
      5.6.1, 5.6.2, 5.6.3, 5.6.4
  - **Tasks**
    1. In `tests/testthat/test-analysis-cell-equivalence.R`, write the quiet
       loop body of §H.7 for `covariance` and `ratios`, titles
       "get_covariance() matches the base-commit results on every quiet
       scenario" and "get_ratios() matches the base-commit results on every
       quiet scenario".
    2. Write the noisy loop body for the same two, titles "get_covariance()
       raises the base-commit warnings and results on every noisy scenario"
       and "get_ratios() raises the base-commit warnings and results on
       every noisy scenario".
    3. Write "get_quantiles() and get_effective_n() match the base-commit
       results": the quiet loop body over the ids `quantiles/tay`,
       `quantiles/rep`, `quantiles/cal` and `effn/tay`.
    4. Write "a call that errors under lonely.psu fail raises no small-cell
       warning": `withr::local_options(survey.lonely.psu = "fail")`; for each
       entry `fn` of
       `cell_core_calls(cell_golden_design("lonely"), min_cell_n = 1000L)`:
       `expect_no_warning(expect_error(fn(), class =
       "surveycore_error_lonely_psu"))`.
    5. Write four `NA`-marker blocks. These are not in the fixture: both
       sides run the current code. `make_domain_pair(class)` is an existing
       helper in `tests/testthat/helper-test-data.R`; it returns `a` (marker
       with `NA` on three rows) and `b` (each `NA` written as `FALSE`).
       Body for the first three: `pair <- make_domain_pair(class)`,
       `ca <- cell_core_calls(pair$a, freqs_x = "y3")`,
       `cb <- cell_core_calls(pair$b, freqs_x = "y3")`, then for each name
       `fn` of the six:
       `expect_matches_golden(ca[[fn]](), cell_golden_strip(cb[[fn]]()), fn)`.
       If a call warns, wrap each side in `expect_warning_count()` with the
       observed classes and count, the same on `a` and `b`.
       - "an NA domain marker gives the same results as FALSE on a Taylor
         design": `class = "taylor"`.
       - "an NA domain marker gives the same results as FALSE on a replicate
         design": `class = "replicate"`.
       - "an NA domain marker gives the same results as FALSE on a two-phase
         design": `class = "twophase"`.
       - "an NA domain marker gives the same results as FALSE on a nonprob
         design without replicate weights": `class = "nonprob"`, the `means`
         entry only. Run each side inside
         `expect_warning_count(..., "surveycore_warning_nonprob_srs_fallback", 3L)`,
         then compare as above. The count 3 is reasoned (one per cell, three
         groups). If the observed count differs, assert the observed count on
         both sides and record it in the PR description.
    6. Run the file on the unchanged code. Every block passes.
    7. Verify: every block passes, and G holds.
  - **Acceptance criteria**
    1. The quiet blocks for `get_covariance()` and `get_ratios()` and
       "get_quantiles() and get_effective_n() match the base-commit results"
       pass (4.7.1, 4.8.1, 4.9.1).
    2. The noisy blocks for `get_covariance()` and `get_ratios()` pass
       (4.7.2, 4.8.2).
    3. These ten ids are asserted by the loop block of their function:
       `freqs/rep_na`, `freqs/rep_inf`, `freqs/np_rep_na`, `means/rep_na`,
       `means/rep_inf`, `totals/rep_na`, `totals/rep_inf`,
       `variance/rep_na`, `covariance/rep_na`, `ratios/rep_na`. These five
       are noisy ids, asserted by a noisy block: `freqs/np_rep10_na_dom`,
       `totals/np_rep10_na_dom`, `ratios/np_rep10_na_dom`,
       `variance/np_rep10_na`, `covariance/np_rep10_na`. Check membership
       with `names(cell_golden_noisy)` and `fixture$warnings` (5.2.1, 5.2.3).
    4. "a call that errors under lonely.psu fail raises no small-cell
       warning" passes for all six entries (5.3.13).
    5. The Taylor, replicate and two-phase `NA`-marker blocks pass for all
       six functions (5.6.1, 5.6.2, 5.6.3).
    6. The nonprob `NA`-marker block passes, and the PR description states
       the warning count observed (5.6.4).
    7. `git diff --name-only origin/develop...HEAD -- R` prints nothing.
    8. G.
  - **Files touched**
    - `tests/testthat/test-analysis-cell-equivalence.R`
  - **Pipeline tier**: optional (no exported function, no numerical method,
    no contract change, one file)

- [ ] PR 3: `refactor/analysis-cell-variance` — `get_variance()` builds its
  context once and takes its Taylor SEs from stacked calls in blocks; adds
  `TAYLOR_SE_BLOCK`, `.cell_context()` and `.taylor_cell_se()`
  - **Budget** — 8 test-spec rows | 8 criteria
    - Rows: §4 4.6.3; §5 5.1.8, 5.2.9, 5.3.4, 5.3.10, 5.3.14, 5.3.16,
      5.5.1
  - **Tasks**
    1. Write these blocks in `tests/testthat/test-analysis-cell-equivalence.R`
       on the unchanged code. `<std>` is §H.4.
       - "get_variance() and get_covariance() results carry no stored
         covariance matrix": for each id of `variance/tay_c_na`,
         `variance/blk65`, `covariance/tay_c_na`, `covariance/blk65`:
         `r <- expect_warning_count(cell_golden_scenarios()[[id]](),
         character(0), 0L)`, then `expect_null(attr(r, ".vcov"))`.
       - "get_variance() gives each clean group the SE of its own domain
         when another group has an Inf":
         `expect_groups_match_domain("variance/tay_y1_inf", "tay",
         function(d) get_variance(d, y1_inf, <std>), "variance")`.
       - "get_variance() errors when every replicate weight is NA on a row
         inside a cell": on `cell_golden_design("rep_allna")`, the call
         `get_variance(d, y1, group = group, <std>)` in
         `expect_error(class = "surveycore_error_all_replicates_na")` and in
         `expect_snapshot(error = TRUE, ...)`.
       - "get_variance() errors on a single-PSU stratum when lonely.psu is
         fail": `calls <- cell_core_calls(cell_golden_design("lonely"))`;
         `withr::local_options(survey.lonely.psu = "fail")`;
         `expect_error(calls$variance(), class =
         "surveycore_error_lonely_psu")` and
         `expect_snapshot(error = TRUE, calls$variance())`. The snapshot
         names the stratum by index and the stage. On the base commit it
         reads "Stratum 6 has only one PSU at stage 1.".
       - "get_variance() errors on a single-PSU stratum when lonely.psu is
         an unknown value": as above with
         `survey.lonely.psu = "unknown_value"` and class
         `surveycore_error_lonely_psu_unknown_option`.
       - "get_variance() errors on a single-PSU stratum under fail when the
         call has 65 cells": on `cell_golden_design("lonely")`, under
         `"fail"`, `get_variance(d, y1, group = g65, <std>)` in
         `expect_error(class = "surveycore_error_lonely_psu")` and
         `expect_snapshot(error = TRUE, ...)`.
       - "get_variance() errors on a single-PSU stratum under fail when its
         only cell has an NA and na.rm = FALSE": on
         `cell_golden_design("lonely")`, under
         `withr::local_options(survey.lonely.psu = "fail")`, the call
         `get_variance(d, y1_na, na.rm = FALSE, <std>)`, dual, class
         `surveycore_error_lonely_psu`. The call is ungrouped, so its one
         cell is the only cell that reaches the variance step, and that cell
         has an `NA` (at `b1`) in its active domain. It is the cell the
         `na.rm = FALSE` override flag marks. If the flush skipped it, the
         call would raise nothing.
       - "get_variance() still errors when a base weight inside a cell is
         NA": on `cell_golden_design("nawt_in")`,
         `get_variance(d, y1, group = group, <std>)`, a `simpleError` row
         (§How to read this plan).
    2. Run the file. Every block passes, and five snapshot entries are
       recorded. Commit the tests and the snapshot file alone, before any
       change under `R/`.
    3. In a scratch session (`devtools::load_all()`, then source
       `tests/testthat/helper-test-data.R` and
       `tests/testthat/helper-cell-golden.R`), count the calls to
       `.build_cluster_matrices()` and `.svy_recvar()` for the scenarios of
       criterion 6, with `trace(..., where = asNamespace("surveycore"),
       print = FALSE)` and a counter tracer. Record the before counts.
    4. Implement in `R/analysis-helpers.R`, as `spec.md` §II.2 and §III.3
       state, with the two deferrals of planner note P-1:
       - `TAYLOR_SE_BLOCK <- 64L`, internal, not exported;
       - `.cell_context(design)`: the six elements of the §II.2 table, with
         `rep_finite` always `FALSE` in this PR. PR 4 adds the argument
         `check_rep_finite = FALSE` and the branch that computes it;
       - `.taylor_cell_se(vals, mats, lonely.psu =
         getOption("survey.lonely.psu", "remove"))`: §III.3 rules 1, 3 and
         4, rule 3 applying whenever `ok` is `TRUE`. The return carries no
         names. PR 4 adds `v = NULL` and rule 2.
    5. Implement `get_variance()` as `spec.md` §VII states, with §II.3
       (`.taylor_variance_cell(design, y_col, domain, mats)`,
       `.replicate_variance_cell(design, y_col, domain, rep_mat)`,
       `.variance_cell(design, y_col, domain, ctx)`, all required, no
       default; the Taylor cell returns `infl` and `se = NA_real_`), §II.5,
       the §III.3 flush buffer with the `na.rm = FALSE` override flag, and
       §III.4. No `.vcov` is attached.
    6. Verify: every block passes with no snapshot diff, the call counts of
       criterion 6 hold, and G holds.
  - **Acceptance criteria**
    1. "get_variance() and get_covariance() results carry no stored
       covariance matrix" and "get_variance() gives each clean group the SE
       of its own domain when another group has an Inf" pass (4.6.3,
       5.1.8).
    2. "get_variance() errors when every replicate weight is NA on a row
       inside a cell" passes with `surveycore_error_all_replicates_na`, and
       "get_variance() still errors when a base weight inside a cell is NA"
       passes with the class the PR description quotes from the base
       commit (5.2.9, 5.5.1).
    3. The four lonely-PSU blocks pass: three with
       `surveycore_error_lonely_psu`, one with
       `surveycore_error_lonely_psu_unknown_option` (5.3.4, 5.3.10, 5.3.14,
       5.3.16).
    4. The snapshots were recorded on the unchanged code and did not move.
       With `t=$(git log --reverse --format=%H origin/develop..HEAD -- tests/testthat/_snaps | head -1)`:
       `git show --name-only --format= "$t"` lists no path under `R/`;
       `git diff --quiet "$t" HEAD -- tests/testthat/_snaps` exits 0.
    5. Every golden block written by PRs 1 and 2 passes unchanged, the
       `variance/blk*` and `variance/tay_many` ids included (gate 1).
    6. Scratch-session call counts with `TAYLOR_SE_BLOCK` at 64, recorded
       before and after in the PR description. After:
       `variance/blk65` gives 1 `.build_cluster_matrices()` call and 2
       `.svy_recvar()` calls; `variance/blk64` gives 1 and 1;
       `variance/rep_na` gives 0 and 0.
    7. `TAYLOR_SE_BLOCK`, `.cell_context()` and `.taylor_cell_se()` are
       defined in `R/analysis-helpers.R` and are internal (`spec.md`
       §II.2): `git diff --quiet origin/develop...HEAD -- NAMESPACE` exits
       0, and `grep -cE 'TAYLOR_SE_BLOCK|cell_context|taylor_cell_se'
       NAMESPACE` prints 0.
    8. G. G item 6 (gate 6) reads as decision D15 states: the clause "rule 3
       with more than one block" is met when a calling function runs more
       than one block, here `variance/blk65` at size 64. The
       `zero_coverage` run lists no added line of `.taylor_cell_se()`
       (rules 1, 3, 4) or `.cell_context()`. `variance/blk64` reaches the
       full in-loop flush, and `variance/blk65` reaches the partial final
       flush. Rule 2 and `check_rep_finite` are not in this PR (planner
       note P-1).
  - **Files touched**
    - `R/analysis-helpers.R`
    - `R/analysis-variance.R`
    - `R/analysis-variance-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md` (new)
  - **Pipeline tier**: recommended

- [ ] PR 4: `refactor/analysis-cell-freqs` — `get_freqs()` builds its context
  once, takes its Taylor SEs and `.vcov` from one stacked call, and uses
  guarded replicate subset sums; completes the shared helpers
  - **Budget** — 5 test-spec rows | 7 criteria
    - Rows: §5 5.2.4, 5.3.1, 5.3.7, 5.5.3, 5.7.2
  - **Tasks**
    1. Write these blocks on the unchanged code:
       - "get_freqs() errors when every replicate weight is NA on a row
         outside the domain": on `cell_golden_design("rep_allna_dom")`,
         `get_freqs(d, f5, <std>)` in
         `expect_error(class = "surveycore_error_all_replicates_na")` and
         `expect_snapshot(error = TRUE, ...)`.
       - "get_freqs() errors on a single-PSU stratum when lonely.psu is
         fail": `calls$freqs()` on
         `cell_core_calls(cell_golden_design("lonely"))` under `"fail"`,
         class `surveycore_error_lonely_psu`, dual (class and snapshot).
       - "get_freqs() errors on a single-PSU stratum when lonely.psu is an
         unknown value": the same under `"unknown_value"`, class
         `surveycore_error_lonely_psu_unknown_option`, dual.
       - "get_freqs() still errors when a base weight is Inf": on
         `cell_golden_design("infwt")`, `get_freqs(d, f5, <std>)`, a
         `simpleError` row.
       - "get_freqs() errors on an all-NA variable when na.rm is FALSE": on
         `cell_golden_design("tay")`,
         `get_freqs(d, y_allna, na.rm = FALSE, <std>)` in
         `expect_error(class = "surveycore_error_all_na")` and
         `expect_snapshot(error = TRUE, ...)`.
    2. Run the file. Every block passes; four new snapshot entries. Commit
       the tests and snapshots alone, before any change under `R/`.
    3. Record the before call counts of criterion 5 (scratch session as in
       PR 3 task 3).
    4. Complete the helpers in `R/analysis-helpers.R`:
       - `.cell_context(design, check_rep_finite = FALSE)`: `rep_finite` is
         `all(is.finite(rep_mat))` when `replicate` and `check_rep_finite`,
         else `FALSE` (§II.2);
       - `.taylor_cell_se()` gains `v = NULL` as its last argument and
         §III.3 rule 2, before rule 3; rule 3 now applies when `ok` and `v`
         is `NULL`;
       - `.joint_vcov(design, joint, mats = NULL)` and
         `.attach_joint_vcov(result, design, joint, v = NULL)` as §II.3 and
         §III.3 (last paragraphs) state;
       - rewrite the comment at the `.joint_vcov()` diagonal note (base
         lines 1208 to 1210) as §III.7 states: the Taylor diagonal equals
         each cell's `se^2` only when every live column is finite; the
         replicate diagonal equals it in exact arithmetic only.
    5. Implement `get_freqs()` as `spec.md` §IV states: §II.3 signatures
       (`.taylor_freq_cell(design, num, denom, mats)`,
       `.replicate_freq_cell(design, num, denom, rep_mat, rep_finite,
       rep_N_d)`, `.freq_cell(design, num, denom, ctx, rep_N_d)`), §II.5
       with `check_rep_finite = TRUE`, the row-1 SE step of §III.3, and the
       exact sum forms of §III.5.
    6. Verify: every block passes with no snapshot diff, criterion 5 holds,
       and G holds.
  - **Acceptance criteria**
    1. "get_freqs() errors when every replicate weight is NA on a row
       outside the domain" passes with
       `surveycore_error_all_replicates_na` (5.2.4).
    2. The two `get_freqs()` lonely-PSU blocks pass with their classes
       (5.3.1, 5.3.7). "get_freqs() still errors when a base weight is Inf"
       passes with the class the PR description quotes (5.5.3). "get_freqs() errors on an all-NA variable when na.rm
       is FALSE" passes with `surveycore_error_all_na` (5.7.2).
    3. The snapshots were recorded on the unchanged code and did not move:
       the check of PR 3 criterion 4.
    4. Every golden block passes unchanged, the `freqs/rep_na`,
       `freqs/rep_inf`, `freqs/rep_zero` and `freqs/np_rep_na` ids included
       (gate 1).
    5. Scratch-session call counts, before and after in the PR description.
       After: `freqs/tay` gives 1 `.build_cluster_matrices()` call and 1
       `.svy_recvar()` call; `freqs/rep` gives 0 and 0.
    6. Gate 12: the comment of task 4 names both conditions (finite columns
       for the Taylor diagonal; exact arithmetic only for the replicate
       diagonal). `.taylor_cell_se()` and `.cell_context()` have the
       signatures of `spec.md` §II.2.
    7. G. In this PR the coverage check of G item 6 also reaches §III.3
       rule 2 and both sum forms of §III.5.
  - **Files touched**
    - `R/analysis-helpers.R`
    - `R/analysis-freqs.R`
    - `R/analysis-freqs-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md`
  - **Pipeline tier**: recommended

- [ ] PR 5: `refactor/analysis-cell-covariance` — `get_covariance()` builds
  its context once and takes its Taylor SEs from stacked calls in blocks
  - **Budget** — 7 test-spec rows | 7 criteria
    - Rows: §5 5.1.9, 5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17, 5.5.2
  - **Tasks**
    1. Write these blocks on the unchanged code:
       - "get_covariance() gives each clean group the SE of its own domain
         when another group has an Inf":
         `expect_groups_match_domain("covariance/tay_y1_inf", "tay",
         function(d) get_covariance(d, c(y1_inf, y2), <std>),
         "covariance")`.
       - "get_covariance() errors when every replicate weight is NA on a row
         inside a cell": on `cell_golden_design("rep_allna")`,
         `get_covariance(d, c(y1, y2), group = group, <std>)`, class
         `surveycore_error_all_replicates_na`, dual.
       - "get_covariance() errors on a single-PSU stratum when lonely.psu is
         fail": `calls$covariance()`, `"fail"`, class
         `surveycore_error_lonely_psu`, dual.
       - "get_covariance() errors on a single-PSU stratum when lonely.psu is
         an unknown value": `"unknown_value"`, class
         `surveycore_error_lonely_psu_unknown_option`, dual.
       - "get_covariance() errors on a single-PSU stratum under fail when
         the call has 65 cells": on `cell_golden_design("lonely")`, under
         `"fail"`, `get_covariance(d, c(y1, y2), group = g65, <std>)`, class
         `surveycore_error_lonely_psu`, dual.
       - "get_covariance() errors on a single-PSU stratum under fail when
         its only pair has an NA and na.rm = FALSE": on
         `cell_golden_design("lonely")`, under
         `withr::local_options(survey.lonely.psu = "fail")`, the call
         `get_covariance(d, c(y1_na, y2), na.rm = FALSE, <std>)`, dual,
         class `surveycore_error_lonely_psu`. Ungrouped with two variables,
         so the one pair `y1_na`–`y2` is the only cell, and it carries the
         `na.rm = FALSE` override flag. If the flush skipped it, the call
         would raise nothing.
       - "get_covariance() still errors when a base weight inside a cell is
         NA": on `cell_golden_design("nawt_in")`,
         `get_covariance(d, c(y1, y2), group = group, <std>)`, a
         `simpleError` row.
    2. Run the file. Every block passes; five new snapshot entries. Commit
       the tests and snapshots alone, before any change under `R/`.
    3. Record the before call counts of criterion 5.
    4. Implement `get_covariance()` as `spec.md` §VIII states, with §II.3
       (`.covariance_pair_taylor(design, x_col, y_col, domain, na.rm,
       mats)`, `.covariance_pair_replicate(design, x_col, y_col, domain,
       na.rm, rep_mat)`, `.covariance_pair_result(design, x_col, y_col,
       domain, na.rm, ctx)`), the flush buffer of §III.3 with the
       `(ci_idx, key)` locator, and §III.4. `.cell_context()` is called with
       `check_rep_finite = FALSE`. No `.vcov` is attached.
    5. Verify: every block passes with no snapshot diff, criterion 5 holds,
       and G holds.
  - **Acceptance criteria**
    1. "get_covariance() gives each clean group the SE of its own domain
       when another group has an Inf" passes (5.1.9).
    2. "get_covariance() errors when every replicate weight is NA on a row
       inside a cell" passes with `surveycore_error_all_replicates_na`, and
       "get_covariance() still errors when a base weight inside a cell is
       NA" passes with the class the PR description quotes (5.2.10, 5.5.2).
    3. The four `get_covariance()` lonely-PSU blocks pass with their
       classes (5.3.5, 5.3.11, 5.3.15, 5.3.17).
    4. The snapshots were recorded on the unchanged code and did not move:
       the check of PR 3 criterion 4.
    5. Scratch-session call counts, before and after in the PR description.
       After, with `TAYLOR_SE_BLOCK` at 64: `covariance/blk65` gives 1
       `.build_cluster_matrices()` call and 2 `.svy_recvar()` calls;
       `covariance/blk64` gives 1 and 1; `covariance/rep_na` gives 0 and 0.
    6. Every golden block passes unchanged, the `covariance/blk*`,
       `covariance/tay_many` and `covariance/tay_narm_false` ids included
       (gate 1).
    7. G. G item 6 (gate 6) reads as decision D15 states: the clause "rule 3
       with more than one block" is met when a calling function runs more
       than one block, here `covariance/blk65` at size 64. The
       `zero_coverage` run lists no line this PR adds. `covariance/blk64`
       reaches the full in-loop flush, and `covariance/blk65` reaches the
       partial final flush.
  - **Files touched**
    - `R/analysis-covariance.R`
    - `R/analysis-covariance-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md`
  - **Pipeline tier**: recommended

- [ ] PR 6: `refactor/analysis-cell-means` — `get_means()` builds its context
  once, takes its Taylor SEs and `.vcov` from one stacked call, narrows the
  columns it passes to `.degf_taylor()` and skips the call on an
  uncalibrated design, comments `.degf_taylor()`, and merges the replicate
  products
  - **Budget** — 11 test-spec rows | 7 criteria
    - Rows: §5 5.1.1, 5.1.2, 5.1.3, 5.1.4, 5.1.10, 5.2.5, 5.2.7, 5.3.2,
      5.3.8, 5.5.5, 5.5.8
  - **Tasks**
    1. Write these blocks on the unchanged code:
       - "get_means() gives each clean group the SE of its own domain when
         another group has an NA and na.rm = FALSE":
         `expect_groups_match_domain("means/tay_y1_na", "tay", function(d)
         get_means(d, y1_na, na.rm = FALSE, <std>), "mean")`.
       - "get_means() gives each clean group the SE of its own domain when
         another group has an NA and na.rm = FALSE, calibrated design": as
         above with `"means/cal_y1_na"` and design `"cal"`.
       - "get_means() gives each clean group the SE of its own domain when
         another group has an NA and na.rm = FALSE, two-stage design with
         FPC": as above with `"means/multi_y1_na"` and design `"multi"`.
       - "get_means() gives each clean group the SE of its own domain when
         another group has an Inf": `"means/tay_y1_inf"`, design `"tay"`,
         `function(d) get_means(d, y1_inf, <std>)`, `"mean"`.
       - "get_means() keeps a stored variance that differs from se^2 for a
         clean group when another group has an NA and na.rm = FALSE": run
         `means/tay_y1_na` inside `expect_warning_count(..., character(0),
         0L)`; `i <- which(r$group == "A")`;
         `expect_true(is.finite(r$se[[i]]))`;
         `expect_false(isTRUE(all.equal(attr(r, ".vcov")[i, i],
         r$se[[i]]^2)))`.
       - "get_means() errors when x is NA in a cell with na.rm = FALSE on a
         replicate design": on `cell_golden_design("rep")`,
         `get_means(d, y1_na, group = group, na.rm = FALSE, <std>)`, class
         `surveycore_error_all_replicates_na`, dual.
       - "get_means() errors on a single-PSU stratum when lonely.psu is
         fail" and "get_means() errors on a single-PSU stratum when
         lonely.psu is an unknown value": `calls$means()`, as in PR 3, with
         `surveycore_error_lonely_psu` and
         `surveycore_error_lonely_psu_unknown_option`, dual.
       - "grouped get_means() still errors when a base weight is Inf": on
         `cell_golden_design("infwt")`,
         `get_means(d, y1, group = group, <std>)`, a `simpleError` row.
       - "get_means() still errors on a calibrated design when x is Inf": on
         `cell_golden_design("cal")`,
         `get_means(d, y1_inf, group = group, <std>)`, a `simpleError` row.
         The calibration projection aborts in `qr.resid()` on the `Inf` in
         group B (`spec.md` §V, edge case "`Inf` in `x`, calibrated
         Taylor").
    2. Run the file. Every block passes; three new snapshot entries. Commit
       the tests and snapshots alone, before any change under `R/`.
    3. Record the before call counts of criterion 5, and the count of
       `.degf_taylor()` calls.
    4. Implement `get_means()` as `spec.md` §V states: §II.3 signatures with
       defaults (`.taylor_mean_cell(design, y_col, domain, mats = NULL,
       compute_se = TRUE)`, `.replicate_mean_cell(design, y_col, domain,
       rep_mat = NULL)`, `.mean_cell(design, y_col, domain, mats = NULL,
       compute_se = TRUE, rep_mat = NULL)`); the call
       `.mean_cell(design, x_name, domain, mats = ctx$mats, compute_se =
       FALSE, rep_mat = ctx$rep_mat)`; the row-1 SE step of §III.3; the one
       `crossprod()` of §III.2; the cell `df` rules of §V. Leave the
       `get_quantiles()` call to `.mean_cell()` untouched.
    5. In `R/analysis-helpers.R`, add the comment at `.degf_taylor()` that
       §V asks for: it names the columns the function reads
       (`vars$ids[[1L]]`, `vars$strata`, `vars$nest`) and says a caller may
       pass a frame holding only those columns. In
       `R/analysis-means-helpers.R`, correct the stale comment of §III.7
       (base lines 44 to 45): the nonprob SRS route goes to the calibrated
       cell, not the Taylor cell.
    6. Verify: every block passes with no snapshot diff, criterion 5 holds,
       and G holds.
  - **Acceptance criteria**
    1. The four self-consistency blocks and "get_means() keeps a stored
       variance that differs from se^2 for a clean group when another group
       has an NA and na.rm = FALSE" pass (5.1.1, 5.1.2, 5.1.3, 5.1.4,
       5.1.10).
    2. "get_means() errors when x is NA in a cell with na.rm = FALSE on a
       replicate design" passes with `surveycore_error_all_replicates_na`.
       After the change, `means/np_rep_y1_na` passes in the noisy block, and
       `means/rep_y1_inf` and `means/np_rep_y1_inf` pass in the quiet block
       (5.2.5, 5.2.7).
    3. The two `get_means()` lonely-PSU blocks pass with their classes.
       "grouped get_means() still errors when a base weight is Inf" and
       "get_means() still errors on a calibrated design when x is Inf" pass
       with the classes the PR description quotes (5.3.2, 5.3.8, 5.5.5,
       5.5.8).
    4. The snapshots were recorded on the unchanged code and did not move:
       the check of PR 3 criterion 4.
    5. Scratch-session counts, before and after in the PR description.
       After: `means/tay` gives 1 `.build_cluster_matrices()` call and 1
       `.svy_recvar()` call; `means/tay_ungrouped` gives 1 and 1;
       `means/rep_na` gives 0 and 0; `means/tay` gives 0 `.degf_taylor()`
       calls.
    6. Every golden block passes unchanged, the calibrated `means/cal*` ids
       (their `df` column included), `quantiles/*` and `effn/tay` included.
       The two comments of task 5 are in place (gate 1, gate 12).
    7. G.
  - **Files touched**
    - `R/analysis-helpers.R`
    - `R/analysis-means.R`
    - `R/analysis-means-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md`
  - **Pipeline tier**: recommended

- [ ] PR 7: `refactor/analysis-cell-totals` — `get_totals()` builds its
  context once and takes its Taylor SEs and `.vcov` from one stacked call
  - **Budget** — 7 test-spec rows | 7 criteria
    - Rows: §5 5.1.5, 5.1.6, 5.2.8, 5.3.3, 5.3.9, 5.5.4, 5.5.6
  - **Tasks**
    1. Write these blocks on the unchanged code:
       - "get_totals() gives each clean group the SE of its own domain when
         another group has an NA and na.rm = FALSE":
         `expect_groups_match_domain("totals/tay_y1_na", "tay", function(d)
         get_totals(d, y1_na, na.rm = FALSE, <std>), "total")`.
       - "get_totals() gives each clean group the SE of its own domain when
         another group has an NA and na.rm = FALSE, two-stage design with
         FPC": as above with `"totals/multi_y1_na"` and design `"multi"`.
       - "get_totals() errors when every replicate weight is NA on a row
         outside the domain": on `cell_golden_design("rep_allna_dom")`,
         `get_totals(d, y1, <std>)`, class
         `surveycore_error_all_replicates_na`, dual.
       - "get_totals() errors on a single-PSU stratum when lonely.psu is
         fail" and "get_totals() errors on a single-PSU stratum when
         lonely.psu is an unknown value": `calls$totals()`, as in PR 3,
         dual.
       - "get_totals() still errors on a calibrated design when x is NA and
         na.rm = FALSE": on `cell_golden_design("cal")`,
         `get_totals(d, y1_na, group = group, na.rm = FALSE, <std>)`, a
         `simpleError` row.
       - "grouped get_totals() still errors when a base weight is Inf": on
         `cell_golden_design("infwt")`,
         `get_totals(d, y1, group = group, <std>)`, a `simpleError` row
         (`spec.md` §X.3, row 3).
    2. Run the file. Every block passes; three new snapshot entries. Commit
       the tests and snapshots alone, before any change under `R/`.
    3. Record the before call counts of criterion 5.
    4. Implement `get_totals()` as `spec.md` §VI states: §II.3 signatures
       with defaults (`.taylor_total_cell(design, y_col, domain, mats =
       NULL, compute_se = TRUE)`, `.replicate_total_cell(design, y_col,
       domain, rep_mat = NULL)`, `.total_cell(design, y_col, domain, mats =
       NULL, compute_se = TRUE, rep_mat = NULL)`); the call with `mats =
       ctx$mats, compute_se = FALSE, rep_mat = ctx$rep_mat`; step 2 after
       the indicator columns for a categorical `x`; the row-1 SE step of
       §III.3. Leave the three `get_ratios()` call sites of `.total_cell()`
       untouched; the defaults keep their base-commit behaviour.
    5. In `R/analysis-totals-helpers.R`, correct the two stale comments of
       §III.7: base lines 19 to 20 (the nonprob SRS route goes to the
       calibrated cell, not the Taylor cell) and base lines 12 to 13
       (`.quantile_woodruff_cell()` uses `.mean_cell()`, not
       `.total_cell()`).
    6. Verify: every block passes with no snapshot diff, criterion 5 holds,
       and G holds.
  - **Acceptance criteria**
    1. The two `get_totals()` self-consistency blocks pass (5.1.5, 5.1.6).
    2. "get_totals() errors when every replicate weight is NA on a row
       outside the domain" passes with
       `surveycore_error_all_replicates_na`. "get_totals() still errors on a
       calibrated design when x is NA and na.rm = FALSE" and "grouped
       get_totals() still errors when a base weight is Inf" pass with the
       classes the PR description quotes (5.2.8, 5.5.4, 5.5.6).
    3. The two `get_totals()` lonely-PSU blocks pass with their classes
       (5.3.3, 5.3.9).
    4. The snapshots were recorded on the unchanged code and did not move:
       the check of PR 3 criterion 4.
    5. Scratch-session counts, before and after in the PR description.
       After: `totals/tay` gives 1 `.build_cluster_matrices()` call and 1
       `.svy_recvar()` call; `totals/rep` gives 0 and 0.
    6. Every golden block passes unchanged, the `ratios/*` ids included
       (they reach `.total_cell()` with the defaults). The two comments of
       task 5 are corrected (gate 1, gate 12).
    7. G.
  - **Files touched**
    - `R/analysis-totals.R`
    - `R/analysis-totals-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md`
  - **Pipeline tier**: recommended

- [ ] PR 8: `refactor/analysis-cell-ratios` — `get_ratios()` builds its
  context once for all three per-cell calls and takes its Taylor SEs from
  stacked calls in blocks
  - **Budget** — 7 test-spec rows | 7 criteria
    - Rows: §5 5.1.7, 5.2.6, 5.3.6, 5.3.12, 5.5.7, 5.5.9, 5.7.1
  - **Tasks**
    1. Write these blocks on the unchanged code:
       - "get_ratios() gives each clean group the SE of its own domain when
         another group's numerator is NA":
         `expect_groups_match_domain("ratios/tay_num_na", "tay", function(d)
         get_ratios(d, y3_na, y1, na.rm = FALSE, <std>), "ratio")`.
       - "get_ratios() errors when the numerator is NA in a cell with na.rm
         = FALSE on a replicate design": on `cell_golden_design("rep")`,
         `get_ratios(d, y3_na, y1, group = group, na.rm = FALSE, <std>)`,
         class `surveycore_error_all_replicates_na`, dual.
       - "get_ratios() errors on a single-PSU stratum when lonely.psu is
         fail" and "get_ratios() errors on a single-PSU stratum when
         lonely.psu is an unknown value": `calls$ratios()`, as in PR 3,
         dual.
       - "get_ratios() errors when a group's denominator total is zero": on
         `cell_golden_design("tay")`,
         `get_ratios(d, y3, y1_c_zero, group = group, <std>)`, class
         `surveycore_error_ratio_zero_denominator`, dual.
       - "grouped get_ratios() still errors when a base weight is Inf": on
         `cell_golden_design("infwt")`,
         `get_ratios(d, y3, y1, group = group, <std>)`, a `simpleError` row
         (`spec.md` §X.3, row 3).
       - "get_ratios() still errors on a calibrated design when either
         variable is NA and na.rm = FALSE": on `cell_golden_design("cal")`,
         two calls, each a `simpleError` row: the numerator call
         `get_ratios(d, y3_na, y1, group = group, na.rm = FALSE, <std>)`
         and the denominator call
         `get_ratios(d, y3, y1_na, group = group, na.rm = FALSE, <std>)`.
         The projection aborts in call 2 for the first and in call 1 for the
         second (`spec.md` §IX, edge case "Calibrated Taylor with an `NA` in
         either variable"). Quote the class of each call in the PR
         description.
    2. Run the file. Every block passes; four new snapshot entries. Commit
       the tests and snapshots alone, before any change under `R/`.
    3. Record the before call counts of criterion 5.
    4. Implement `get_ratios()` as `spec.md` §IX states: calls 1 and 2 pass
       `mats = ctx$mats` or `rep_mat = ctx$rep_mat` and keep
       `compute_se = TRUE`; call 3 on the Taylor route is
       `.delta_ratio_cell(design, y_vec, x_vec, domain, ratio_est, total_x,
       tmp_col, mats = ctx$mats, compute_se = FALSE)`, which returns `infl`
       and a joint element with `value = NULL`; call 3 on the replicate
       route is `.replicate_ratio_cell(design, y_vec, x_vec, domain,
       ratio_est, total_x, rep_mat = ctx$rep_mat)`; on the nonprob SRS and
       two-phase routes `.delta_ratio_cell(..., mats = NULL, compute_se =
       TRUE)`. Both cell functions take their new arguments with no
       default. After the loop, the SE step of §III.3 row 2: blocks of at
       most `TAYLOR_SE_BLOCK`, SE divided by `abs(total_x)`, the scaled
       column written to `acc_joint[[j]]$value` and `acc_infl[j] <-
       list(NULL)` (never `acc_infl[[j]] <- NULL`), then one `.joint_vcov()`
       with `mats = ctx$mats` and `.attach_joint_vcov(..., v = v_all)`.
    5. Verify: every block passes with no snapshot diff, criterion 5 holds,
       and G holds.
  - **Acceptance criteria**
    1. "get_ratios() gives each clean group the SE of its own domain when
       another group's numerator is NA" passes (5.1.7).
    2. "get_ratios() errors when the numerator is NA in a cell with na.rm =
       FALSE on a replicate design" passes with
       `surveycore_error_all_replicates_na`. "grouped get_ratios() still
       errors when a base weight is Inf" and "get_ratios() still errors on a
       calibrated design when either variable is NA and na.rm = FALSE" pass
       with the classes the PR description quotes (5.2.6, 5.5.7, 5.5.9).
    3. The two `get_ratios()` lonely-PSU blocks pass with their classes, and
       "get_ratios() errors when a group's denominator total is zero" passes
       with `surveycore_error_ratio_zero_denominator` (5.3.6, 5.3.12,
       5.7.1).
    4. The snapshots were recorded on the unchanged code and did not move:
       the check of PR 3 criterion 4.
    5. Scratch-session counts, before and after in the PR description.
       After, with `TAYLOR_SE_BLOCK` at 64: `ratios/tay_ungrouped` gives 1
       `.build_cluster_matrices()` call and 4 `.svy_recvar()` calls (1 + 1
       + 1 + 1); `ratios/blk65` gives 1 and 133 (65 + 65 + 2 + 1);
       `ratios/rep_na` gives 0 and 0.
    6. Every golden block passes unchanged, the `ratios/blk*`,
       `ratios/np_srs` (3 `surveycore_warning_nonprob_srs_fallback`
       warnings) and `ratios/tay_c_zero_den` ids included (gate 1, gate 2).
    7. G, with two readings:
       - G item 6 (gate 6) reads as decision D15 states: the clause "rule 3
         with more than one block" is met when a calling function runs more
         than one block, here `ratios/blk65` at size 64. The `zero_coverage`
         run lists no line this PR adds.
       - After this PR, three default branches of `spec.md` §II.3 have no
         caller left: the `mats = NULL` build branch of `.joint_vcov()`, and
         the `mats = NULL` and `rep_mat = NULL` branches of
         `.taylor_total_cell()` and `.replicate_total_cell()`. §II.3 sets
         these defaults, so no signature changes. The PR description lists
         every unreached line of `R/analysis-helpers.R` and
         `R/analysis-totals-helpers.R` from the G item 6 `zero_coverage`
         run, and names the branch each line belongs to.
  - **Files touched**
    - `R/analysis-ratios.R`
    - `R/analysis-ratios-helpers.R`
    - `tests/testthat/test-analysis-cell-equivalence.R`
    - `tests/testthat/_snaps/analysis-cell-equivalence.md`
  - **Pipeline tier**: recommended

- [ ] PR 9: `refactor/analysis-cell-performance` — the measured block size,
  the speed table, `NEWS.md` and the changelog
  - **Budget** — 0 test-spec rows | 8 criteria
    - Rows: none. Speed is measured outside the test suite.
  - **Tasks**
    1. Build the two libraries of `spec.md` §XII.1: the base commit (the
       sha in PR 1's description and in the fixture's provenance) in
       `<lib_before>`, the branch head in `<lib_after>`. Write one timing
       script that takes a library path and an output path, attaches
       `surveycore` with `library(surveycore, lib.loc = lib)`, builds the
       §XII.2 designs (`gss_d`, `gss_cal`, `a_tay`, `a_rep`, `b_tay`,
       `b_rep`, with the code and seeds `spec.md` §XII.2 gives) and runs the
       scenarios. Keep the script in the run directory, out of the PR diff.
       Run in the foreground, with no other R process running.
    2. Block size (§XII.5). On `<lib_after>`, for each `B` in 16, 32, 64:
       `utils::assignInNamespace("TAYLOR_SE_BLOCK", B, "surveycore")`; time
       V3, C2 and R4 (one warm-up call, then the median of 5
       `system.time(...)[["elapsed"]]` runs, 3 runs when the warm-up takes
       more than 1 s); save each result with `saveRDS()` and compare it
       with the `<lib_before>` result: `identical()`, and when `FALSE`,
       equality at `tolerance = 1e-12`. Sum the three medians per `B`.
       Select the smallest `B` whose sum is within 5% of the smallest sum.
       A result that differs at any `B` blocks the selection until it is
       explained: raise a HOLD.
       - V3: `get_variance(b_tay, c(y1, y2, y3), group = c(g20, g3))`
       - C2: `get_covariance(b_tay, c(y1, y2, y3), group = c(g20, g3), diagonal = TRUE)`
       - R4: `get_ratios(b_tay, y1, y2, group = c(g20, g3))`
    3. Set `TAYLOR_SE_BLOCK` to the selected value in
       `R/analysis-helpers.R` (no edit when it is 64). Create
       `changelog/refactor-analysis-cell-performance.md` with the block-size
       table: `B`, the three medians, the sum, and the equality result per
       scenario. Commit these two together, before task 5.
    4. Run `devtools::test()`. Every golden block passes at the selected
       size; the `blk16` to `blk65` ids cover each size and one past it.
    5. Reinstall the branch head into `<lib_after>`. Run the §XII.4 protocol
       on all 31 scenarios of §XII.3 (F1 to F9, M1 to M9, T1 to T3, V1 to
       V3, C1 to C3, R1 to R4), with both libraries, one after the other.
       Record R version, `extSoftVersion()[["BLAS"]]`, `La_library()` and
       `getOption("matprod")`, and the commit sha installed in
       `<lib_after>`. In a separate pass per library, count
       `.build_cluster_matrices()` and `.svy_recvar()` calls with `trace()`;
       remove the traces before timing. Save each result and report
       `identical(before, after)`.
    6. Apply gate 9: a scenario is flagged when its before time is at least
       0.1 s and its after time exceeds the before time by more than 10%
       and by more than 0.02 s. Run a flagged scenario once more on both
       libraries. If it is still flagged, raise a HOLD for the user and do
       not change any result.
    7. Write the `NEWS.md` entry of `spec.md` §XIII. Add the heading
       `# surveycore (development version)` above `# surveycore 1.2.0`, or,
       when a development section already exists on `develop`, extend it
       with a `## Performance` section. Fill the fields by the rules of
       §XIII:
       - `{functions}` lists, in §I.2 order, each function with a scenario
         whose before time is at least 0.1 s and whose after/before ratio is
         0.9 or less.
       - `{M7 before}` and `{M7 after}` are scenario M7's times to two
         decimal places.
       - Fallback 1: when `get_means()` does not qualify, replace the
         example sentence with the qualifying scenario that has the largest
         before time, described in the same words; when no scenario
         qualifies, drop the example sentence.
       - Fallback 2: when no function qualifies, drop the speed sentence and
         the example sentence, and start the first bullet with the
         replacement text §XIII gives ("The analysis functions ... were
         restructured internally. ..."). Keep the sentence about results and
         rounding.
       - `{ref}` is the issue number the work closes. When there is no
         issue, it is this PR's number: open the PR first, then fill
         `{ref}` in a follow-up commit on the branch.
       No `{` field is left at merge.
    8. Complete the changelog file in the house shape (branch, status, date,
       summary, files modified, changes) with: the §XII table (scenario,
       rows, before, after, after/before, counts before and after,
       `identical()`); the block-size table of task 3; the `identical()`
       evidence of `spec.md` §XV; the two sentences and the D13 lifecycle
       line §XIII quotes, word for word. Put the §XII table in the PR
       description too.
    9. Verify: G holds.
  - **Acceptance criteria**
    1. The changelog file holds the block-size table for `B` = 16, 32 and
       64, with each scenario's result identical or equal within 1e-12 at
       every size, and `TAYLOR_SE_BLOCK` holds the size the §XII.5 rule
       selects from that table (gate 13).
    2. The commit that sets the size and adds the block-size table is an
       ancestor of the commit installed for the speed run:
       `git merge-base --is-ancestor <size-commit> <installed-sha>` exits 0.
    3. The §XII table has 31 rows with every column filled, and the
       environment lines (R, BLAS, LAPACK, `matprod`).
    4. Call counts after, with `B` the selected size and `k` the live
       Taylor cells: `.build_cluster_matrices()` 1 on every Taylor
       scenario; `.svy_recvar()` 1 on F1 to F6, M1 to M7, T1 and T2;
       `ceiling(k / B)` on V1, V3, C1, C2; for R1, R2, R4 one per non-empty
       call-1 and call-2 total cell, plus `ceiling(k / B)`, plus 1; both 0
       on F7 to F9, M8, M9, T3, V2, C3, R3 (gate 10).
    5. No scenario stays flagged by gate 9, or a HOLD for the user is open
       and named in the PR description (gate 9).
    6. Gate 11: `NEWS.md` holds the development section and both bullets
       of §XIII, with every field filled by the rules of task 7 and no `{`
       field left; and the changelog file holds every item of task 8.
    7. At the committed `TAYLOR_SE_BLOCK`, `devtools::test()` passes, the
       golden ids `variance/blk16` to `variance/blk65_inf`,
       `covariance/blk16` to `covariance/blk65_inf`, `ratios/blk16` to
       `ratios/blk65_na` and `variance/blk65_gap` included. The PR
       description states the committed value.
    8. G.
  - **Files touched**
    - `R/analysis-helpers.R` (only when the selected size is not 64)
    - `NEWS.md`
    - `changelog/refactor-analysis-cell-performance.md` (new)
  - **Pipeline tier**: recommended

## Row assignment

69 rows. Each appears once. The six rows of erratum E-1 (decision D16) are
5.3.16, 5.3.17 and 5.5.6 to 5.5.9.

| PR | Rows | Rows count | Criteria |
|---|---|---|---|
| 1 | 4.0, 4.1, 4.2, 4.3.1, 4.3.2, 4.4.1, 4.4.2, 4.5.1, 4.5.2, 4.6.1, 4.6.2, 5.2.2 | 12 | 8 |
| 2 | 4.7.1, 4.7.2, 4.8.1, 4.8.2, 4.9.1, 5.2.1, 5.2.3, 5.3.13, 5.6.1, 5.6.2, 5.6.3, 5.6.4 | 12 | 8 |
| 3 | 4.6.3, 5.1.8, 5.2.9, 5.3.4, 5.3.10, 5.3.14, 5.3.16, 5.5.1 | 8 | 8 |
| 4 | 5.2.4, 5.3.1, 5.3.7, 5.5.3, 5.7.2 | 5 | 7 |
| 5 | 5.1.9, 5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17, 5.5.2 | 7 | 7 |
| 6 | 5.1.1, 5.1.2, 5.1.3, 5.1.4, 5.1.10, 5.2.5, 5.2.7, 5.3.2, 5.3.8, 5.5.5, 5.5.8 | 11 | 7 |
| 7 | 5.1.5, 5.1.6, 5.2.8, 5.3.3, 5.3.9, 5.5.4, 5.5.6 | 7 | 7 |
| 8 | 5.1.7, 5.2.6, 5.3.6, 5.3.12, 5.5.7, 5.5.9, 5.7.1 | 7 | 7 |
| 9 | none | 0 | 8 |

By section: §4 rows 4.0 to 4.9.1 (17), §5.1 (10), §5.2 (10), §5.3 (17),
§5.5 (9), §5.6 (4), §5.7 (2). §5.4 and §9 hold rules, not rows.

New snapshot entries, by PR, and no others: PR 3 five (5.2.9, 5.3.4,
5.3.10, 5.3.14, 5.3.16); PR 4 four (5.2.4, 5.3.1, 5.3.7, 5.7.2); PR 5 five
(5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17); PR 6 three (5.2.5, 5.3.2, 5.3.8);
PR 7 three (5.2.8, 5.3.3, 5.3.9); PR 8 four (5.2.6, 5.3.6, 5.3.12, 5.7.1).
The `simpleError` rows (5.5.1 to 5.5.9) add no snapshot.

## Planning notes

**P-1. `get_variance()` goes first, and two helper arguments wait one PR.**
`spec.md` §XI checks gate 6 on every PR, and gate 6 asks that every rule
branch of `.taylor_cell_se()` and both sum forms of §III.5 are reached. No
single function reaches all of them. `get_freqs()`, `get_means()` and
`get_totals()` pass `v` (rule 2); `get_variance()`, `get_covariance()` and
`get_ratios()` pass none (rule 3); only `get_freqs()` passes
`check_rep_finite = TRUE`; and `spec.md` §IV says no known `get_freqs()`
input fails the finite check (rule 4). So the helpers land in two steps,
each with its first user (§II.6 item 2):

- PR 3 adds `TAYLOR_SE_BLOCK`, `.cell_context(design)` and
  `.taylor_cell_se(vals, mats, lonely.psu)` with rules 1, 3 and 4.
  `get_variance()` reaches all of them, both flush kinds and more than one
  block.
- PR 4 adds `check_rep_finite = FALSE` to `.cell_context()` and `v = NULL`
  with rule 2 to `.taylor_cell_se()`. Both are trailing arguments with
  defaults, so PR 3's calls do not change. `get_freqs()` reaches both.

After PR 4 both helpers have the exact signatures of `spec.md` §II.2. A
reviewer of PR 3 should read the two missing arguments as planned.

**P-2. Two test-only PRs come first.** Gates 1 and 2 are checked on every
PR, so the golden loops of all six functions, and of `get_quantiles()` and
`get_effective_n()`, must exist before the first production PR. Those 15
rows do not fit one PR with the harness rows. PR 1 holds the harness and
four functions' loops; PR 2 holds the rest. No production change lands
between them.

**P-3. Every function's own rows are written on its unchanged code.** Each
production PR commits its new blocks and snapshot entries before its first
`R/` commit. The snapshots then record the base-commit message, and
criterion "snapshots did not move" proves the class and message survive the
change.

**P-4. Call counts are the only criteria that see the speed-up.** The golden
rows would pass if a builder changed nothing. Each production PR therefore
records `.build_cluster_matrices()` and `.svy_recvar()` counts in a scratch
session. The expected values come from `spec.md` §XII.4 at
`TAYLOR_SE_BLOCK = 64`. The scratch code is not committed.

**P-5. PR 9 joins the block-size measurement and the documentation.** §II.6
item 3 wants the block-size result committed before the speed run, and item
4 wants the changelog to land last. One PR with two ordered commits meets
both: the first commit sets the size and starts the changelog with the
block-size table; the speed run installs a descendant of that commit; the
second commit adds the §XII table and `NEWS.md`. When the selected size is
64, the PR touches no file under `R/`.

**P-6. PR 1 is large in lines.** The 261-scenario catalogue must be complete
when the fixture is generated, so the helper file cannot be split across
PRs. The row budget holds (12). Expect PR 1's additions to sit well above
the usual figure for 12 rows.

**P-7. Inconsistencies found while planning.**

- `spec.md` §III.3 rule 3 splits `vals` into blocks inside
  `.taylor_cell_se()`. But every caller that uses rule 3 already passes at
  most `TAYLOR_SE_BLOCK` columns: `get_variance()` and `get_covariance()`
  flush at the block size, and `get_ratios()` splits before it calls. So
  the helper's own split never makes more than one block through the
  public API. Gate 6 asks for "rule 3 with more than one block". Settled by
  D15: the clause is met by caller blocks (`variance/blk65`,
  `covariance/blk65`, `ratios/blk65`). PRs 3, 5 and 8 state this reading in
  their G criterion.
- `test-spec.md` §2.4 lets a later PR add a scenario and regenerate against
  the base commit, while §3.3 and row 4.1 pin the total at 261. This plan
  forbids fixture changes after PR 1; a needed scenario is a HOLD.
- `test-spec.md` row 5.2.7 needs `means/np_rep_y1_inf` to be quiet ("no
  domain-replicates warning may fire"), while §3.3 says the fixture's
  recorded warnings win. PR 1 task 5 reports the recorded state, so a
  conflict shows before PR 6.
- `spec.md` §I lists decisions D1 to D13; `decisions.md` also holds D14,
  which this plan applies in PR 1. `spec.md` still reads **Status**: DRAFT
  while `status.md` records SPEC_READY.
- `spec.md` §II.1 sets no home for the §XII timing script. This plan keeps
  it in the run directory and out of every PR diff.
- `data-raw/README.md` does not change (plan review F-2).

**P-8. Erratum E-1 rows (decision D16).** Plan review pass 1 found spec
behaviour that no row checked. The six added rows go to the PR of their
function, and each is written and passes on the unchanged code before that
PR's first `R/` commit, like every other row of the PR:

- 5.3.16 (PR 3) and 5.3.17 (PR 5): an ungrouped call on the `lonely` design
  whose only cell carries the `na.rm = FALSE` override flag. Under
  `"fail"`, the abort must still fire, so a flush that skipped override
  cells turns the row red (`spec.md` §VII, §VIII, §III.4).
- 5.5.6 (PR 7), 5.5.7 (PR 8), 5.5.8 (PR 6), 5.5.9 (PR 8): kept base R errors
  that must still fire (`spec.md` §X.3 row 3, §V, §IX). They are
  `simpleError` rows. Only 5.5.8 may now fire later than the moved
  lonely-PSU abort (§X.1). The `get_ratios()` abort does not move
  (§III.4), and the 5.5.6 error fires before any variance call. The base
  commit raises `simpleError` on all four: "missing value where TRUE/FALSE
  needed" for 5.5.6 and 5.5.7, "NA/NaN/Inf in foreign function call
  (arg 5)" for 5.5.8 and both 5.5.9 calls (plan review pass 2 probe).

No PR exceeds the budget. PR 1 and PR 2 sit at the 12-row limit, and PR 6
at 11 rows is the largest production PR.
