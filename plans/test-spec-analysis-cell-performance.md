# Test-spec — analysis-cell-performance

**Status**: DRAFT (Stage 3r: spec review pass 1 resolved, with D12 and D13)
**Date**: 2026-11-10
**Base commit**: `develop` at `0c0a987`, or the later `develop` commit the
first branch of this work is cut from. Section 2.4 says how to pin it.

## Errata

**E-1 (2026-11-10, decision D16).** Plan review pass 1 found spec behaviour
that no row checked. Six rows are added. No existing row changes or moves.
Each new row is written and passes on the unchanged code before the first
`R/` commit of its PR.

| Row | Section | What it checks |
|---|---|---|
| 5.3.16 | §5.3 | A `get_variance()` cell under the `na.rm = FALSE` override still reaches the variance step, so `"fail"` aborts |
| 5.3.17 | §5.3 | The same for a `get_covariance()` pair |
| 5.5.6 | §5.5 | Grouped `get_totals()` with an `Inf` base weight still errors |
| 5.5.7 | §5.5 | Grouped `get_ratios()` with an `Inf` base weight still errors |
| 5.5.8 | §5.5 | Calibrated `get_means()` with `Inf` in `x` still errors |
| 5.5.9 | §5.5 | Calibrated `get_ratios()` with `NA` in either variable still errors |

The cross-references in §4.4 to §4.8 and §6 name the new rows.

This document tells the tester what to prove and how. The change under test
makes six analysis functions faster: `get_freqs()`, `get_means()`,
`get_totals()`, `get_variance()`, `get_covariance()` and `get_ratios()`. The
claim to prove is that **nothing they return changes**: not an estimate, a
standard error, a derived column, the `df` column, nor the stored covariance
matrix (`attr(result, ".vcov")`). The claim covers every design class, every
`variance =` option, grouped and ungrouped calls, designs with a domain
marker, and calls with many cells. Conditions keep their class and their
count per call.

---

## 1. Reference oracle

### 1.1 Primary: the base commit's own results (golden fixture)

The oracle is the output of the six functions on the base commit, before any
production change. A generator script runs a fixed set of scenarios on the
base commit and stores every result in one fixture file. The tests run the
same scenarios on the current code and compare.

Why this oracle and not another:

- The change claims equality with the old code, and the old code is what the
  change replaces. After the first production PR the old code no longer
  exists in the tree. Only a stored copy of its output can still be compared.
- A frozen copy of the old computation inside `tests/` would mean copying
  well over a thousand lines of package internals into the test suite. It
  would drift, and it would test a copy, not the shipped code.
- `survey` agrees with surveycore only to 1e-8 on standard errors. That
  cannot detect a last-bit change. The existing `survey` oracle blocks stay
  as they are and keep their own tolerances.
- The generator uses exported functions and test helpers only. The tester
  can build it without reading package source.

The comparison tolerance is 1e-12 (decision D3). On R's reference BLAS the
results are expected to be `identical()`; an optimized BLAS may differ in
the last bit. Tests do not assert `identical()`.

The fixture stays after this work as a permanent regression test (decision
D13). §2.4 states its lifecycle.

### 1.2 Secondary: self-consistency (rows 5.1.x)

For calls where one group holds a non-finite value, each clean group's row
must equal an ungrouped call on a design whose domain marker selects only
that group. Both sides run the current code. Tolerance 1e-12.

### 1.3 Not used

No new `survey` oracle block. The oracle rule of
`.claude/rules/testing-surveycore.md` does not reach the golden comparison:
it compares surveycore with surveycore, and hands `survey` nothing.

---

## 2. Datasets and fixtures

### 2.1 Files

| File | Status | Content |
|---|---|---|
| `tests/testthat/helper-cell-golden.R` | new | Frame and design builders, the scenario list, the expected warnings, the comparison and warning-count helpers |
| `data-raw/analysis-cell-golden.R` | new | The generator script. `data-raw/` is in `.Rbuildignore`, so it does not ship. |
| `tests/testthat/fixtures/analysis-cell-golden.rds` | new | The golden fixture |
| `tests/testthat/test-analysis-cell-equivalence.R` | new | Every row of this document |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | new | Snapshots of the error rows |

The new test file starts with a file-level `skip_on_cran()`. Reason
(decision D13): run time. The file runs 261 scenarios and about 30
condition rows. The fixture still ships under `tests/`, because a local
`R CMD check` runs the file and fails when the fixture is missing. Do not
add it to `.Rbuildignore`. `devtools::test()` sets `NOT_CRAN = "true"`, so the file runs
locally and in CI. A last-bit difference on another BLAS is not a reason to
skip: the 1e-12 tolerance already allows it.

The helper file defines functions and constants only. Nothing runs when it
is sourced. (Helpers are sourced in name order, so `helper-cell-golden.R` is
sourced before `helper-test-data.R`; its functions call `make_survey_data()`
only when they run.)

No existing test file changes. Every existing test must still pass
unchanged.

### 2.2 Frame builder

`cell_golden_cols(df)` takes a frame from `make_survey_data()` (it has
`psu`, `strata`, `fpc`, `wt`, `y1`, `y2`, `y3`, `group`) and adds these
columns. `a1` is the first row with `group == "A"`; `b1` is the first row
with `group == "B"`. Every frame it receives has at least 300 rows.

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
| `g16`, `g17`, `g32`, `g33`, `g64`, `g65` | For `gm`, `rep_len(seq_len(m), nrow(df))`, an integer column. Level `j` holds rows `j`, `j + m`, `j + 2m`, and so on. |
| `y1_inf65` | `y1` with `Inf` at row 65 (level 65 of `g65`) |
| `y3_na65` | `y3` with `NA` at row 65 |
| `y1_gap` | `y1` with `NA` on every row where `g65 == 33`, except row 33 |

Use `withr::with_seed()`, not `set.seed()`, so the global random state is
not changed.

On the `tay` frame (500 rows) each level of `g65` holds 7 or 8 rows, so
every level is a cell with at least two rows.

### 2.3 Design builder

`cell_golden_design(name)` builds one design by name. Every scenario calls
it, so the generator and the tests build identical designs. All Taylor
designs use `nest = TRUE`.

| Name | Frame | Build |
|---|---|---|
| `tay` | `cell_golden_cols(make_survey_data(seed = 101L))` | `as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt, nest = TRUE)` |
| `tay_lab` | `cell_golden_cols(make_survey_data(seed = 101L, with_labels = TRUE))` | as `tay` |
| `tay_nofpc` | as `tay` | as `tay` without `fpc` |
| `tay_probs` | as `tay` | `as_survey(df, ids = psu, strata = strata, probs = p, nest = TRUE)` (the weight column is then internal) |
| `srs` | as `tay` | `as_survey(df, weights = wt)` |
| `strat` | as `tay` | `as_survey(df, strata = strata, weights = wt)` |
| `multi` | `cell_golden_cols(make_survey_data(n = 600L, n_psu = 30L, n_ssu = 3L, n_strata = 5L, seed = 102L))` | `as_survey(df, ids = c(psu, ssu), strata = strata, fpc = c(fpc, fpc2), weights = wt, nest = TRUE)` |
| `lonely` | as `tay`, then `df$strata[df$psu == "psu_1"] <- "stratum_lonely"` | `as_survey(df, ids = psu, strata = strata, weights = wt, nest = TRUE)` |
| `cal` | as `tay`; `cd <- as_caldata(df$wt, rep(1.01, nrow(df)), stats::model.matrix(~y2, df))` | `as_survey(df, ids = psu, strata = strata, weights = cal_wt, nest = TRUE, calibration = list(cd))` |
| `cal_srs` | as `cal` | `as_survey(df, weights = cal_wt, calibration = list(cd))` (no `ids`, no `strata`) |
| `cal_strat` | as `cal` | `as_survey(df, strata = strata, weights = cal_wt, calibration = list(cd))` (strata only) |
| `cal_ids` | as `cal` | `as_survey(df, ids = psu, weights = cal_wt, calibration = list(cd))` (ids only) |
| `cal_multi` | as `multi`; `cd` built the same way on this frame | `as_survey(df, ids = c(psu, ssu), strata = strata, fpc = c(fpc, fpc2), weights = cal_wt, nest = TRUE, calibration = list(cd))` (two-stage `ids`) |
| `rep` | `cell_golden_cols(make_survey_data(n = 500L, n_psu = 50L, design = "replicate", type = "brr", seed = 103L))` (25 replicate columns) | `as_survey_replicate(df, weights = wt, repweights = tidyselect::starts_with("repwt_"), type = "BRR")` |
| `rep_na` | as `rep`, then `df$repwt_3[[b1]] <- NA` | as `rep` |
| `rep_inf` | as `rep`, then `df$repwt_3[[b1]] <- Inf` | as `rep` |
| `rep_zero` | as `rep`, then `df$repwt_3[df$group == "B"] <- 0` | as `rep` |
| `rep_allna` | as `rep`, then every `repwt_*` column `NA` at `b1` | as `rep` |
| `rep_allna_dom` | as `rep`, then every `repwt_*` column `NA` at `a1` | as `rep`, then the domain marker of §2.5 with `keep = seq_len(nrow(df)) != a1` |
| `np_rep` | as `rep` | `as_survey_nonprob(df, weights = wt, repweights = tidyselect::starts_with("repwt_"))` |
| `np_rep_na` | as `rep_na` | as `np_rep` |
| `np_rep10_na` | `cell_golden_cols(make_survey_data(n = 300L, n_psu = 20L, design = "replicate", type = "brr", seed = 104L))` (10 replicate columns), then `df$repwt_3[[a1]] <- NA` | as `np_rep` |
| `np_rep10_na_dom` | as `np_rep10_na` | `np_rep10_na`, then the domain marker with `keep = seq_len(nrow(df)) != a1` |
| `np_srs` | as `tay` | `as_survey_nonprob(df, weights = wt)` |
| `tph` | `cell_golden_cols(make_survey_data(n = 500L, n_psu = 50L, design = "twophase", seed = 105L))` | `as_survey_twophase(as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt, nest = TRUE), subset = subset, method = "approx")` |
| `tay_dom`, `rep_dom`, `cal_dom`, `np_rep_dom`, `np_srs_dom` | as the design without `_dom` | that design, then the domain marker with `keep = df$y2 > -0.5` |
| `tph_dom` | as `tph` | `tph`, then the domain marker with `keep = df$y2 > -0.5`, after setting `keep[which(!df$subset)[[1L]]] <- TRUE` so at least one phase-1-only row is marked `TRUE` |
| `tay_empty_dom` | as `tay` | `tay`, then the domain marker with `keep = rep(FALSE, nrow(df))` |
| `nawt_out` | as `tay` | `as_survey(df, ids = psu, strata = strata, fpc = fpc, weights = wt_na_out, nest = TRUE)` |
| `nawt_in` | as `tay` | as `nawt_out` with `weights = wt_na_in` |
| `infwt` | as `tay` | as `nawt_out` with `weights = wt_inf` |
| `gss` | `gss_2024`, recoded below | `as_survey(gss, ids = vpsu, strata = vstrat, weights = wtssps, nest = TRUE)` |
| `allna_grp` | — | `make_all_na_group_design()` from `helper-test-data.R` (columns `y1`, `y2`, `y3`, and `grp`, which is `NA` on every row) |

GSS recode. The GSS stores missing values as negative codes. For `age`,
`educ`, `degree`, `race`, `sex`, `partyid` and `happy`, replace the column
with `as.numeric(unclass(v))` and set negative values to `NA`. This also
drops the label attributes, which these rows do not need.

`as_survey()` accepts an `NA` or `Inf` base weight; it checks only the
non-`NA` values for positivity. The class accepts `NA` and `Inf` replicate
weights. These designs build without error.

### 2.4 The golden fixture and its generator

The generator is `data-raw/analysis-cell-golden.R`. Run it from the root of
the working tree as:

```
git worktree add <dir> <base-sha>
Rscript data-raw/analysis-cell-golden.R <dir> <base-sha>
```

It does this, in order:

1. Takes the source-tree path from its first argument and the base commit
   from its second.
2. Stops, naming the check, if any of these is true:
   - `git -C <dir> rev-parse HEAD` is not the commit that
     `git -C <dir> rev-parse <base-sha>` gives;
   - `git -C <dir> status --porcelain -- R` prints anything;
   - `git -C <dir> diff --quiet <base-sha> -- R` exits with a non-zero
     status.

   These checks prove the generator ran on `<base-sha>`. They do not prove
   that `<base-sha>` is the right commit. So the first PR records the base
   SHA in its description, and the reviewer checks that it equals `develop`
   at the commit the branch was cut from (decision D14).
3. Runs `pkgload::load_all(<dir>, helpers = FALSE, quiet = TRUE)`, so the
   package code comes from the base commit.
4. Sources `tests/testthat/helper-test-data.R` and
   `tests/testthat/helper-cell-golden.R` from the current tree, so the
   scenario list is the current one.
5. Runs every scenario of §3. A generator is not a test, so it may use
   `withCallingHandlers()`: it records the class of every warning a scenario
   raises (the first class of each, in order) and muffles it. If a scenario
   errors, the generator stops and names it.
6. Strips the stored call from each result (§2.6) and saves:

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

with `saveRDS(compress = "xz")` to
`tests/testthat/fixtures/analysis-cell-golden.rds`. Budget: 300 KB. Report a
larger file in the PR.

**Reading the fixture.** Tests read it only through `cell_golden_fixture()`
(§2.6). A missing fixture fails every block that reads it; nothing skips.

**Lifecycle (D13).**

- During this work: generate once, in the first PR, before any production
  change. Every later PR must pass against the same fixture. Never
  regenerate from a tree that holds the change. If a later PR in this work
  must add a scenario, add it to the helper, then run the generator against
  a worktree at the base commit.
- After this work: the fixture, the test file and the generator stay. When a
  later change moves one of these results on purpose, regenerate the fixture
  with the generator, run against a worktree at that change's own commit,
  and say so in that PR.

Tests never assert the provenance.

### 2.5 Domain-restricted designs without surveytidy

`surveytidy::filter()` is not installed, so no test can call it. The route
used here:

- `surveytidy::filter()` stores domain membership as one logical column in
  the design's data, named by the exported constant
  `SURVEYCORE_DOMAIN_COL` (`"..surveycore_domain.."`). Rows stay in the
  data. `TRUE` marks a row inside the domain.
- surveycore's analysis functions read only that column. `filter()` also
  appends its condition to `@variables$domain`; surveycore never reads that
  entry.
- The existing test helper `.testhelper_mark_domain(design, keep)` in
  `tests/testthat/helper-test-data.R` writes exactly that column. It checks
  that `keep` is logical, has one value per row, and holds no `NA`.
  `tests/testthat/test-analysis-corr-latent.R` and `test-glm.R` already use
  it.
- The write goes through the design's `@data` property, so the
  `survey_base` validator runs and refuses a non-logical marker
  (`surveycore_error_domain_not_logical`). The marked design is a valid
  design, not a hand-built object.

Use `.testhelper_mark_domain()` for every `_dom` design and for the
group-selecting designs of §5.1. Its one-line equivalent is
`design@data[[SURVEYCORE_DOMAIN_COL]] <- keep`. This choice is decision D11
(planner default; the user may reopen it).

The route does not reproduce `@variables$domain`. For a marker with no `NA`,
the analysis functions see the same object as `filter()` gives:
`@variables$domain` is the only difference, and no analysis result reads
it.

**A marker that holds `NA`.** The validator accepts an `NA` in the marker,
and the analysis functions read it as `FALSE`. `.testhelper_mark_domain()`
refuses an `NA`, so the `_dom` designs never store one. For that case use
the existing test helper `make_domain_pair(class)` in
`tests/testthat/helper-test-data.R` (it writes the marker with
`set_domain_marker()` from the same file). It returns `a`, a design whose
marker holds `NA` on three rows, and `b`, the same design with each `NA`
written as `FALSE`. Its `class` is one of `"taylor"`, `"replicate"`,
`"twophase"` and `"nonprob"` (a `survey_nonprob` without replicate weights).
The `"twophase"` pair also marks a phase-1-only row `TRUE`. Its frame comes
from `make_survey_data()`, so it has `y1`, `y2`, `y3` and `group`, but none
of the §2.2 columns. §5.6 uses it.

### 2.6 Shared test helpers

All in `tests/testthat/helper-cell-golden.R`.

**`cell_golden_fixture()`**: no arguments. Returns the fixture list of §2.4,
read with `readRDS(testthat::test_path("fixtures",
"analysis-cell-golden.rds"))`. Calls `stop()` with a message that names the
path when the file does not exist. It never skips.

**`cell_golden_strip(x)`**: takes one result of the six functions (or of
`get_quantiles()` or `get_effective_n()`). Returns `x` with one change: the
`call` element of `attr(x, ".meta")` is removed, with
`meta <- attr(x, ".meta"); meta$call <- NULL; attr(x, ".meta") <- meta`.
When `x` has no `.meta` attribute, or its `.meta` has no `call`, it returns
`x` unchanged. It removes nothing else: every column and every other
attribute, `.vcov` and `.survey_result` included, stays. The generator
applies it to each result before it saves the fixture.

**`expect_matches_golden(object, expected, label)`**:

1. Applies `cell_golden_strip()` to `object`. `expected` was stripped the
   same way when the fixture was saved.
2. `expect_equal(object, expected, tolerance = 1e-12, label = label)`. This
   compares columns, column types, the class vector, and every attribute,
   `.vcov`, `.survey_result` and the rest of `.meta` included.
3. For every double column, and for `attr(, ".vcov")`:
   `expect_identical(is.nan(object_part), is.nan(expected_part))`. The
   tolerance comparison treats `NaN` and `NA` as equal. Several rows in this
   document produce `NaN`, and the distinction must stay.

`label` is the scenario id, so a failure names its scenario.

Why the call is removed: `.meta$call` stores the call as the caller wrote
it. The generator and the tests reach the same function through different
caller text, so the stored call differs by text alone. It holds no computed
value.

**`expect_warning_count(expr, class, n)`**: asserts that `expr` raises
exactly `n` warnings, one of each class in `class`, and returns the value of
`expr`. `class` is a character vector of length 1 (used `n` times) or of
length `n`. It nests one `expect_warning()` per warning inside one
`expect_no_warning()`:

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

Each `expect_warning()` takes one warning of its class, and any other
warning passes up to the next level. One warning more reaches
`expect_no_warning()` and fails the block; one warning fewer fails an
`expect_warning()`. `n = 0L` asserts that `expr` raises no warning. The
helper uses no `withCallingHandlers()` and no `tryCatch()`.

**`cell_core_calls(d, freqs_x = "f5", min_cell_n = 0L)`**: a named list of
six zero-argument functions, `freqs`, `means`, `totals`, `variance`,
`covariance`, `ratios`, each running the core call of §3.1 on `d` with
`variance = c("se", "ci", "var", "cv", "moe", "deff")`, `n_weighted = TRUE`
and the given `min_cell_n`. The `freqs` entry selects its variable with
`tidyselect::all_of(freqs_x)`. Example entry:

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

The §3.1 core scenarios use it, and so do §5.3 and §5.6.

**`expect_groups_match_domain(id, design, ungrouped, estimate,
groups = c("A", "C"))`**: runs scenario `id` (grouped). For each group `g`,
it builds `cell_golden_design(design)`, marks it with
`.testhelper_mark_domain(d, survey_data(d)$group == g)`, and runs
`ungrouped(marked)`. It asserts, with `expect_equal(tolerance = 1e-12)`, that
the `estimate` column and the `se` column of the grouped rows where
`group == g` equal those of the ungrouped result, row by row and with the
names dropped.

### 2.7 Standard options

Unless a row says otherwise, every scenario passes:

```r
variance = c("se", "ci", "var", "cv", "moe", "deff"),
n_weighted = TRUE,
min_cell_n = 0L
```

`min_cell_n = 0L` switches off the small-cell warning, so most scenarios
raise no warning. This document writes these three arguments as `<std>`.
No scenario passes `decimals`: rounding can turn a last-bit difference into
a visible one.

---

## 3. Scenario catalogue

A scenario id is `"<function>/<name>"`. `cell_golden_scenarios()` returns a
named list of zero-argument functions, one per id. Each builds its design
with `cell_golden_design()` and returns the result. The catalogue has **261
scenarios**: 120 in §3.1, 104 in §3.2, 37 in §3.3.

### 3.1 Core set: every function on every core design

Core designs (20): `tay`, `tay_nofpc`, `tay_probs`, `srs`, `strat`,
`multi`, `lonely_remove`, `lonely_adjust`, `lonely_average`,
`lonely_certainty`, `cal`, `rep`, `np_rep`, `tph`, `tay_dom`, `rep_dom`,
`cal_dom`, `np_rep_dom`, `tph_dom`, `tay_fail`.

`lonely_<option>` is the `lonely` design with
`withr::local_options(survey.lonely.psu = "<option>")` set inside the
scenario. `tay_fail` is the `tay` design (no single-PSU stratum) under
`survey.lonely.psu = "fail"`.

| Function | Core call (`cell_core_calls(d)`) |
|---|---|
| `freqs` | `get_freqs(d, f5, group = group, <std>)` |
| `means` | `get_means(d, y1, group = group, <std>)` |
| `totals` | `get_totals(d, y1, group = group, <std>)` |
| `variance` | `get_variance(d, c(y1, y2), group = group, <std>)` |
| `covariance` | `get_covariance(d, c(y1, y2, y3), group = group, <std>)` |
| `ratios` | `get_ratios(d, y3, y1, group = group, <std>)` |

20 designs times 6 functions: 120 scenarios.

### 3.2 Extra scenarios

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

| Id | Call | Cells that reach their variance step |
|---|---|---|
| `variance/tay_one_cell` | `get_variance(tay, y1, <std>)` | 1 |
| `variance/tay_ungrouped` | `get_variance(tay, c(y1, y2), <std>)` | 2 |
| `variance/tay_listwise` | `get_variance(tay, c(y1, y1_na), group = group, na_handling = "listwise", <std>)` | |
| `variance/tay_narm_false` | `get_variance(tay, c(y1, y1_na), group = group, na.rm = FALSE, <std>)` | |
| `variance/tay_many` | `get_variance(tay, c(y1, y2, y3, y1_na, y2_a_na), group = c(group, f5), <std>)` | 75 |
| `variance/tay_c_na` | `get_variance(tay, c(y1, y1_c_na, y2), group = group, <std>)` | 8; the `y1_c_na` cell of group C returns early, between live cells |
| `variance/tay_empty_dom` | `get_variance(tay_empty_dom, c(y1, y2), <std>)` | 0 |
| `variance/gss` | `get_variance(gss, age, group = degree, <std>)` | |
| `variance/tay_y1_inf` | `get_variance(tay, y1_inf, group = group, <std>)` | |
| `variance/nawt_out` | `get_variance(nawt_out, y2_a_na, group = group, <std>)` | |
| `variance/rep_na` | `get_variance(rep_na, c(y1, y2), group = group, <std>)` | |
| `variance/blk16` | `get_variance(tay, y1, group = g16, <std>)` | 16 |
| `variance/blk17` | `get_variance(tay, y1, group = g17, <std>)` | 17 |
| `variance/blk32` | `get_variance(tay, y1, group = g32, <std>)` | 32 |
| `variance/blk33` | `get_variance(tay, y1, group = g33, <std>)` | 33 |
| `variance/blk64` | `get_variance(tay, y1, group = g64, <std>)` | 64 |
| `variance/blk65` | `get_variance(tay, y1, group = g65, <std>)` | 65 |
| `variance/blk65_inf` | `get_variance(tay, y1_inf65, group = g65, <std>)` | 65; cell 65 is not finite |

`get_covariance()` (18):

| Id | Call | Cells that reach their variance step |
|---|---|---|
| `covariance/tay_pair` | `get_covariance(tay, c(y1, y2), <std>)` | 1: with the defaults `redundant = FALSE` and `diagonal = FALSE`, two variables give the one pair `y1`–`y2` |
| `covariance/tay_ungrouped` | `get_covariance(tay, c(y1, y2, y3), <std>)` | 3 |
| `covariance/tay_full` | `get_covariance(tay, c(y1, y2, y3), group = group, redundant = TRUE, diagonal = TRUE, <std>)` | |
| `covariance/tay_narm_false` | `get_covariance(tay, c(y1, y1_na, y2), group = group, na.rm = FALSE, <std>)` | |
| `covariance/tay_many` | `get_covariance(tay, c(y1, y2, y3), group = c(group, f5), diagonal = TRUE, <std>)` | 90 |
| `covariance/tay_c_na` | `get_covariance(tay, c(y1, y1_c_na, y2), group = group, <std>)` | 7; the two `y1_c_na` pairs of group C return early, between live pairs |
| `covariance/tay_empty_dom` | `get_covariance(tay_empty_dom, c(y1, y2), <std>)` | 0 |
| `covariance/gss` | `get_covariance(gss, c(age, educ), group = degree, <std>)` | |
| `covariance/tay_y1_inf` | `get_covariance(tay, c(y1_inf, y2), group = group, <std>)` | |
| `covariance/nawt_out` | `get_covariance(nawt_out, c(y2_a_na, y1), group = group, <std>)` | |
| `covariance/rep_na` | `get_covariance(rep_na, c(y1, y2), group = group, <std>)` | |
| `covariance/blk16` | `get_covariance(tay, c(y1, y2), group = g16, <std>)` | 16 |
| `covariance/blk17` | `get_covariance(tay, c(y1, y2), group = g17, <std>)` | 17 |
| `covariance/blk32` | `get_covariance(tay, c(y1, y2), group = g32, <std>)` | 32 |
| `covariance/blk33` | `get_covariance(tay, c(y1, y2), group = g33, <std>)` | 33 |
| `covariance/blk64` | `get_covariance(tay, c(y1, y2), group = g64, <std>)` | 64 |
| `covariance/blk65` | `get_covariance(tay, c(y1, y2), group = g65, <std>)` | 65 |
| `covariance/blk65_inf` | `get_covariance(tay, c(y1_inf65, y2), group = g65, <std>)` | 65; cell 65 is not finite |

`get_ratios()` (17):

| Id | Call | Cells that reach the ratio SE step |
|---|---|---|
| `ratios/tay_ungrouped` | `get_ratios(tay, y3, y1, <std>)` | 1 |
| `ratios/gss` | `get_ratios(gss, educ, age, group = degree, <std>)` | |
| `ratios/tay_num_na` | `get_ratios(tay, y3_na, y1, group = group, na.rm = FALSE, <std>)` | |
| `ratios/tay_den_na` | `get_ratios(tay, y3, y1_na, group = group, na.rm = FALSE, <std>)` | |
| `ratios/multi_num_na` | `get_ratios(multi, y3_na, y1, group = group, na.rm = FALSE, <std>)` | |
| `ratios/tay_c_zero_den` | `get_ratios(tay, y3_c_na, y1_c_zero, group = group, na.rm = FALSE, <std>)` | |
| `ratios/tay_c_na` | `get_ratios(tay, y3_c_na, y1, group = group, <std>)` | 2; group C is empty |
| `ratios/tay_empty_dom` | `get_ratios(tay_empty_dom, y3, y1, <std>)` | 0 |
| `ratios/tay_allna` | `get_ratios(tay, y_allna, y1, <std>)` | 0 |
| `ratios/rep_na` | `get_ratios(rep_na, y3, y1, group = group, <std>)` | |
| `ratios/blk16` | `get_ratios(tay, y3, y1, group = g16, <std>)` | 16 |
| `ratios/blk17` | `get_ratios(tay, y3, y1, group = g17, <std>)` | 17 |
| `ratios/blk32` | `get_ratios(tay, y3, y1, group = g32, <std>)` | 32 |
| `ratios/blk33` | `get_ratios(tay, y3, y1, group = g33, <std>)` | 33 |
| `ratios/blk64` | `get_ratios(tay, y3, y1, group = g64, <std>)` | 64 |
| `ratios/blk65` | `get_ratios(tay, y3, y1, group = g65, <std>)` | 65 |
| `ratios/blk65_na` | `get_ratios(tay, y3_na65, y1, group = g65, na.rm = FALSE, <std>)` | 65; cell 65 is not finite |

Second callers (4):

| Id | Call |
|---|---|
| `quantiles/tay` | `get_quantiles(tay, y1, group = group, variance = c("se", "ci"), min_cell_n = 0L)` |
| `quantiles/rep` | as above on `rep` |
| `quantiles/cal` | as above on `cal` |
| `effn/tay` | `get_effective_n(tay, y1, group = group, method = "deff", min_cell_n = 0L)` |

**Why the `blk` rows.** After this change, `get_variance()`,
`get_covariance()` and `get_ratios()` compute their Taylor standard errors
in groups of cells. The group size is 16, 32 or 64; a speed measurement made
during the build selects it. The live-cell counts 16, 17, 32, 33, 64 and 65
sit on each possible size and one cell past it, whichever size is selected.
The `_inf` and `_na` rows put one non-finite cell in the last group only, so
the earlier groups stay clean. `variance/blk65_gap` (§3.3) puts a cell that
returns early in the middle of the run.

The empty-cell entries in the count column are reasoned, not measured. The
golden comparison is the assertion; the column is for the reader.

### 3.3 Noisy scenarios (in the fixture, asserted in their own blocks)

These raise warnings on the base commit. Expected classes and counts. The
`surveycore_warning_` prefix is left out of the table to save width; write
the full class in the helper.

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
| `means/cal_srs_two` | `get_means(cal_srs, y1, group = g_two, <std>)` | 1 × `zero_df_after_calibration` (cell `"Z"`: 2 rows, df 1, calibration rank 2) |
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
| `variance/np_rep10_na` | `get_variance(np_rep10_na, y1, group = group, <std>)` | 1 × `domain_replicates_na` (group A holds `a1`) |
| `variance/blk65_gap` | `get_variance(tay, y1_gap, group = g65, <std>)` | 1 × `variance_insufficient_n` (cell 33 has one row; 64 live cells) |
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
| `ratios/np_rep10_na_dom` | `get_ratios(np_rep10_na_dom, y3, y1, <std>)` | 3 × `domain_replicates_na` (one per call in the cell) |

37 scenarios.

The helper stores this table as `cell_golden_noisy`: a named list from id to
the character vector of full classes, one element per warning.

**The fixture's recorded counts win.** Many counts above are reasoned, not
measured. The fixture's `warnings` entry is the authority. If it disagrees
with this table, correct `cell_golden_noisy` to the recorded classes and
counts, and note each difference in the PR. If a §3.1 or §3.2 scenario
records a warning, move it into `cell_golden_noisy`; it is then asserted as
a noisy scenario. If a §3.3 scenario records no warning, take it out of
`cell_golden_noisy`; it is then a quiet scenario. The pinned total of 261
does not change.

---

## 4. Per-function test plan

**Input modes.** The six functions take a design object. None takes a plain
data frame. Every row runs in one mode.

**Invariants.** The first block of the new test file (row 4.0) builds one
design per constructor and calls `test_invariants()` once on each:
`as_survey()` (`tay`), `as_survey_replicate()` (`rep`),
`as_survey_twophase()` (`tph`), `as_survey_nonprob()` (`np_srs`). No later
block repeats it.

**Quiet and noisy ids.** A quiet id has an empty `fixture$warnings` entry
and is not in `cell_golden_noisy`. A noisy id is in `cell_golden_noisy`.

**Loop rule.** Every block that loops over ids first asserts
`expect_gt(length(ids), 0L)`, so a loop over an empty set fails.

| Row | `test_that()` description | Assertion |
|---|---|---|
| 4.0 | "the golden fixture designs build and pass the design invariants" | `test_invariants()` on the four designs above |
| 4.1 | "every golden scenario is asserted by at least one block" | With `fixture <- cell_golden_fixture()`: (a) `expect_setequal(names(fixture$results), names(cell_golden_scenarios()))`; (b) `expect_length(fixture$results, 261L)`; (c) `expect_setequal(names(fixture$warnings), names(fixture$results))`; (d) `expect_setequal(names(cell_golden_noisy), names(Filter(length, fixture$warnings)))`; (e) for each noisy id, `expect_identical(sort(cell_golden_noisy[[id]]), sort(fixture$warnings[[id]]))`. Every quiet id is asserted by row 4.x.1 or 4.9.1, and every noisy id by row 4.x.2. |
| 4.2 | "the six analysis functions keep their base-commit formals" | For each function, `expect_identical(formals(fn), fixture$formals[[name]])` |

Rows 4.3.1 to 4.8.1 have the same body. For the quiet ids of the function:
`r <- expect_warning_count(scenario(), character(0), 0L)`, then
`expect_matches_golden(r, fixture$results[[id]], id)`.

Rows 4.3.2 to 4.8.2 have the same body. For the noisy ids of the function:
`r <- expect_warning_count(scenario(), cell_golden_noisy[[id]],
length(cell_golden_noisy[[id]]))`, then `expect_matches_golden()`.

### 4.3 `get_freqs()`

| Row | `test_that()` description |
|---|---|
| 4.3.1 | "get_freqs() matches the base-commit results on every quiet scenario" |
| 4.3.2 | "get_freqs() raises the base-commit warnings and results on every noisy scenario" |

Error rows: 5.2.4, 5.3.1, 5.3.7, 5.5.3, 5.7.2. Edge cases: §6.

### 4.4 `get_means()`

| Row | `test_that()` description |
|---|---|
| 4.4.1 | "get_means() matches the base-commit results on every quiet scenario" |
| 4.4.2 | "get_means() raises the base-commit warnings and results on every noisy scenario" |

The `df` column of a calibrated design is part of the comparison. Error
rows: 5.2.5, 5.3.2, 5.3.8, 5.5.5, 5.5.8. Edge cases: §6.

### 4.5 `get_totals()`

| Row | `test_that()` description |
|---|---|
| 4.5.1 | "get_totals() matches the base-commit results on every quiet scenario" |
| 4.5.2 | "get_totals() raises the base-commit warnings and results on every noisy scenario" |

Error rows: 5.2.8, 5.3.3, 5.3.9, 5.5.4, 5.5.6. Edge cases: §6.

### 4.6 `get_variance()`

| Row | `test_that()` description |
|---|---|
| 4.6.1 | "get_variance() matches the base-commit results on every quiet scenario" |
| 4.6.2 | "get_variance() raises the base-commit warnings and results on every noisy scenario" |
| 4.6.3 | "get_variance() and get_covariance() results carry no stored covariance matrix": `expect_null(attr(r, ".vcov"))` on `variance/tay_c_na`, `variance/blk65`, `covariance/tay_c_na` and `covariance/blk65` |

Error rows: 5.2.9, 5.3.4, 5.3.10, 5.3.14, 5.3.16, 5.5.1. Edge cases: §6.

### 4.7 `get_covariance()`

| Row | `test_that()` description |
|---|---|
| 4.7.1 | "get_covariance() matches the base-commit results on every quiet scenario" |
| 4.7.2 | "get_covariance() raises the base-commit warnings and results on every noisy scenario" |

Error rows: 5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17, 5.5.2. Edge cases: §6.

### 4.8 `get_ratios()`

| Row | `test_that()` description |
|---|---|
| 4.8.1 | "get_ratios() matches the base-commit results on every quiet scenario" |
| 4.8.2 | "get_ratios() raises the base-commit warnings and results on every noisy scenario" |

Error rows: 5.2.6, 5.3.6, 5.3.12, 5.5.7, 5.5.9, 5.7.1. Edge cases: §6.

### 4.9 Second callers

Row 4.9.1: "get_quantiles() and get_effective_n() match the base-commit
results". Loop over the `quantiles/*` and `effn/*` ids, with the body of
4.3.1.

### 4.10 Test categories

The thirteen categories of the review checklist, for all six functions.

| # | Category | Disposition |
|---|---|---|
| 1 | Happy path | Rows 4.x.1 on the core set |
| 2 | Numerical oracle | The golden comparison at 1e-12 on every scenario (§1.1). The existing `survey` oracle blocks stay unchanged. |
| 3 | Grouped analysis | Every core call is grouped; `*/tay_two_groups`, the `blk` rows |
| 4 | Domain estimation | The `_dom` core designs, `*/tay_empty_dom`, `rep_allna_dom`, `np_rep10_na_dom`, §5.6 |
| 5 | Variance argument | `<std>` passes all six options on every scenario; `freqs/tay_default_variance` and `means/tay_default_variance` use the default |
| 6 | `label_values` | `freqs/lab_broom` and `means/lab_broom` (value labels on `y3` and `group`). N/A for the other four functions: the change alters only how the standard errors are computed, and labels are applied to the finished result from the design's metadata, which the change does not touch. The golden comparison of every column would show a label change. |
| 7 | `label_vars` | As category 6 (variable labels on `y1`, `y3` and `group`) |
| 8 | `meta()` contract | Not a separate row: the golden comparison asserts `.meta` (all but the stored call) on every scenario |
| 9 | `name_style = "broom"` | `freqs/lab_broom`, `means/lab_broom`. N/A for the other four functions, for the reason of category 6 |
| 10 | Error paths | §5.2, §5.3, §5.5, §5.7 |
| 11 | Edge cases | §6 |
| 12 | Multi-variable | `freqs/tay_multi_na`, `freqs/gss_multi`, the core `variance` and `covariance` calls (two and three variables), `variance/tay_many`, `covariance/tay_many` |
| 13 | Print snapshot | N/A: no `print()` or `format()` method changes, and the golden comparison proves each result object equal to the base commit's, so it prints the same. The existing print snapshots stay. |

---

## 5. Cross-cutting rows

### 5.1 One group holds a non-finite value

These calls give one group (B; C for `ratios/tay_c_zero_den`, which is a
golden row only) a non-finite value: an `NA` in `x` with
`na.rm = FALSE`, an `NA` in the ratio numerator, or an `Inf` in `x`. On the
base commit each clean group (A and C) still gets a finite standard error.
For some of these calls the stored `.vcov` diagonal of a clean group is
`Inf`, `NaN`, or a value other than `se^2`. Both facts must stay.

Golden rows (in the quiet loops of §4): `means/tay_y1_na`,
`means/cal_y1_na`, `means/multi_y1_na`, `means/tay_y1_inf`,
`totals/tay_y1_na`, `totals/multi_y1_na`, `totals/tay_y1_inf`,
`variance/tay_y1_inf`, `covariance/tay_y1_inf`, `ratios/tay_num_na`,
`ratios/multi_num_na`, `ratios/tay_c_zero_den`, `variance/nawt_out`,
`covariance/nawt_out`, and the three `blk65` non-finite rows.

Self-consistency rows. Each block calls `expect_groups_match_domain()`
(§2.6) with the arguments in the table. `ungrouped` is
`function(d) <call>`; every call passes `<std>`.

| Row | `test_that()` description | `id` | `design` | Ungrouped call | `estimate` |
|---|---|---|---|---|---|
| 5.1.1 | "get_means() gives each clean group the SE of its own domain when another group has an NA and na.rm = FALSE" | `means/tay_y1_na` | `tay` | `get_means(d, y1_na, na.rm = FALSE)` | `mean` |
| 5.1.2 | the same, calibrated design | `means/cal_y1_na` | `cal` | `get_means(d, y1_na, na.rm = FALSE)` | `mean` |
| 5.1.3 | the same, two-stage design with FPC | `means/multi_y1_na` | `multi` | `get_means(d, y1_na, na.rm = FALSE)` | `mean` |
| 5.1.4 | "get_means() gives each clean group the SE of its own domain when another group has an Inf" | `means/tay_y1_inf` | `tay` | `get_means(d, y1_inf)` | `mean` |
| 5.1.5 | "get_totals() gives each clean group the SE of its own domain when another group has an NA and na.rm = FALSE" | `totals/tay_y1_na` | `tay` | `get_totals(d, y1_na, na.rm = FALSE)` | `total` |
| 5.1.6 | the same, two-stage design with FPC | `totals/multi_y1_na` | `multi` | `get_totals(d, y1_na, na.rm = FALSE)` | `total` |
| 5.1.7 | "get_ratios() gives each clean group the SE of its own domain when another group's numerator is NA" | `ratios/tay_num_na` | `tay` | `get_ratios(d, y3_na, y1, na.rm = FALSE)` | `ratio` |
| 5.1.8 | "get_variance() gives each clean group the SE of its own domain when another group has an Inf" | `variance/tay_y1_inf` | `tay` | `get_variance(d, y1_inf)` | `variance` |
| 5.1.9 | "get_covariance() gives each clean group the SE of its own domain when another group has an Inf" | `covariance/tay_y1_inf` | `tay` | `get_covariance(d, c(y1_inf, y2))` | `covariance` |

Kept-mismatch row:

| Row | `test_that()` description | Assertion |
|---|---|---|
| 5.1.10 | "get_means() keeps a stored variance that differs from se^2 for a clean group when another group has an NA and na.rm = FALSE" | On `means/tay_y1_na`, with `i <- which(r$group == "A")`: `expect_true(is.finite(r$se[[i]]))` and `expect_false(isTRUE(all.equal(attr(r, ".vcov")[i, i], r$se[[i]]^2)))`. On an uncalibrated design the stored diagonal is finite but rescaled, so the row does not assert that it is non-finite. |

### 5.2 Replicate weights that are NA, Inf, or zero

Today an `NA` or `Inf` in a replicate weight column makes that replicate
unusable in every cell of the call, including cells that do not contain the
row. That must stay.

| Row | `test_that()` description | Input | Assertion |
|---|---|---|---|
| 5.2.1 | in the quiet loops | `freqs/rep_na`, `freqs/rep_inf`, `freqs/np_rep_na`, `means/rep_na`, `means/rep_inf`, `totals/rep_na`, `totals/rep_inf`, `variance/rep_na`, `covariance/rep_na`, `ratios/rep_na` | `expect_matches_golden()` |
| 5.2.2 | in the quiet loop | `freqs/rep_zero` | `expect_matches_golden()` |
| 5.2.3 | in the noisy loops | `freqs/np_rep10_na_dom`, `totals/np_rep10_na_dom`, `ratios/np_rep10_na_dom`, `variance/np_rep10_na`, `covariance/np_rep10_na` | the recorded warnings, then `expect_matches_golden()` |
| 5.2.4 | "get_freqs() errors when every replicate weight is NA on a row outside the domain" | `get_freqs(rep_allna_dom, f5, <std>)` | dual |
| 5.2.5 | "get_means() errors when x is NA in a cell with na.rm = FALSE on a replicate design" | `get_means(rep, y1_na, group = group, na.rm = FALSE, <std>)` | dual |
| 5.2.6 | "get_ratios() errors when the numerator is NA in a cell with na.rm = FALSE on a replicate design" | `get_ratios(rep, y3_na, y1, group = group, na.rm = FALSE, <std>)` | dual |
| 5.2.7 | covered by the rows it lists | `get_means()` with a non-finite `y` on both replicate classes: `NA` in `y` with `na.rm = FALSE` on `survey_replicate` (row 5.2.5) and on replicate `survey_nonprob` (`means/np_rep_y1_na`, row 4.4.2); `Inf` in `y` on `survey_replicate` (`means/rep_y1_inf`) and on replicate `survey_nonprob` (`means/np_rep_y1_inf`), both in the quiet loop, so no domain-replicates warning may fire | as the rows state |
| 5.2.8 | "get_totals() errors when every replicate weight is NA on a row outside the domain" | `get_totals(rep_allna_dom, y1, <std>)` | dual |
| 5.2.9 | "get_variance() errors when every replicate weight is NA on a row inside a cell" | `get_variance(rep_allna, y1, group = group, <std>)` | dual |
| 5.2.10 | "get_covariance() errors when every replicate weight is NA on a row inside a cell" | `get_covariance(rep_allna, c(y1, y2), group = group, <std>)` | dual |

"Dual" means `expect_error(class = "surveycore_error_all_replicates_na")`
and `expect_snapshot(error = TRUE, ...)`.

Why rows 5.2.9 and 5.2.10 use a row inside a cell: these two functions
compute each replicate on the cell's own rows. A replicate weight on a row
outside every cell does not reach their estimate, so `rep_allna_dom` gives
them no error. The row inside group B does.

### 5.3 A stratum with one PSU under `survey.lonely.psu = "fail"` or an unknown value

The error class and message must not change. The tests assert the class
and the message. They do not assert the order of conditions: under these
options a warning from a later cell may now print before the error, and an
error from a later cell may replace it. That change is accepted (decisions
D6 and D9). The `lonely` design with the core calls raises no other
condition, so each block sees only the error.

Each block builds `calls <- cell_core_calls(cell_golden_design("lonely"))`.

Rows 5.3.1 to 5.3.6 set `withr::local_options(survey.lonely.psu = "fail")`
and run one entry of `calls`. Each asserts
`expect_error(class = "surveycore_error_lonely_psu")` and
`expect_snapshot(error = TRUE, ...)`. The snapshot names the stratum by
its index and the stage. On the base commit the message reads
"Stratum 6 has only one PSU at stage 1.", not the label `"stratum_lonely"`
(plan review pass 2, base-code probe).

| Row | `test_that()` description | Entry |
|---|---|---|
| 5.3.1 | "get_freqs() errors on a single-PSU stratum when lonely.psu is fail" | `calls$freqs()` |
| 5.3.2 | "get_means() errors on a single-PSU stratum when lonely.psu is fail" | `calls$means()` |
| 5.3.3 | "get_totals() errors on a single-PSU stratum when lonely.psu is fail" | `calls$totals()` |
| 5.3.4 | "get_variance() errors on a single-PSU stratum when lonely.psu is fail" | `calls$variance()` |
| 5.3.5 | "get_covariance() errors on a single-PSU stratum when lonely.psu is fail" | `calls$covariance()` |
| 5.3.6 | "get_ratios() errors on a single-PSU stratum when lonely.psu is fail" | `calls$ratios()` |

Rows 5.3.7 to 5.3.12 set
`withr::local_options(survey.lonely.psu = "unknown_value")` and run one entry
of `calls`. Each asserts
`expect_error(class = "surveycore_error_lonely_psu_unknown_option")` and
`expect_snapshot(error = TRUE, ...)`.

| Row | `test_that()` description | Entry |
|---|---|---|
| 5.3.7 | "get_freqs() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$freqs()` |
| 5.3.8 | "get_means() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$means()` |
| 5.3.9 | "get_totals() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$totals()` |
| 5.3.10 | "get_variance() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$variance()` |
| 5.3.11 | "get_covariance() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$covariance()` |
| 5.3.12 | "get_ratios() errors on a single-PSU stratum when lonely.psu is an unknown value" | `calls$ratios()` |

| Row | `test_that()` description | Call | Assertion |
|---|---|---|---|
| 5.3.13 | "a call that errors under lonely.psu fail raises no small-cell warning" | For each entry of `cell_core_calls(cell_golden_design("lonely"), min_cell_n = 1000L)`, under `"fail"` | `expect_no_warning(expect_error(fn(), class = "surveycore_error_lonely_psu"))`. Without the error, every one of these calls would warn `surveycore_warning_small_cell`. |
| 5.3.14 | "get_variance() errors on a single-PSU stratum under fail when the call has 65 cells" | `get_variance(lonely, y1, group = g65, <std>)` under `"fail"` | `expect_error(class = "surveycore_error_lonely_psu")` and `expect_snapshot(error = TRUE, ...)` |
| 5.3.15 | "get_covariance() errors on a single-PSU stratum under fail when the call has 65 cells" | `get_covariance(lonely, c(y1, y2), group = g65, <std>)` under `"fail"` | as 5.3.14 |
| 5.3.16 | "get_variance() errors on a single-PSU stratum under fail when its only cell has an NA and na.rm = FALSE" | `get_variance(lonely, y1_na, na.rm = FALSE, <std>)` under `"fail"`. Ungrouped, so the one cell is the only cell that reaches its variance step, and it has an `NA` (at `b1`) in its active domain. | as 5.3.14 |
| 5.3.17 | "get_covariance() errors on a single-PSU stratum under fail when its only pair has an NA and na.rm = FALSE" | `get_covariance(lonely, c(y1_na, y2), na.rm = FALSE, <std>)` under `"fail"`. Ungrouped, two variables: the one pair `y1_na`–`y2` is the only cell. | as 5.3.14 |

Why rows 5.3.16 and 5.3.17 (decision D16): under `na.rm = FALSE` a cell
with an `NA` in its active domain reports `NaN` for its SE, but its variance
step still runs. Under `"fail"` that step is the one that aborts when no
other cell reaches it. A call that skipped such a cell would return a result
and raise nothing, so the row fails.

The core-set scenarios `*/tay_fail` (in the quiet loops) prove that `"fail"`
on a design with no single-PSU stratum gives the base-commit results.

### 5.4 Warning counts per call

Every exact count uses `expect_warning_count()` (§2.6). No block writes the
nesting by hand.

### 5.5 Kept behaviour for existing defects

These inputs show defects that this work does not fix (decision D8). The
rows prove the behaviour does not move. Base R raises these errors with no
surveycore class, so each row asserts `class = "simpleError"` and has no
snapshot: the message is base R's, not a CLI message, and its text depends
on the locale.

| Row | `test_that()` description | Call | Assertion |
|---|---|---|---|
| 5.5.1 | "get_variance() still errors when a base weight inside a cell is NA" | `get_variance(nawt_in, y1, group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.2 | "get_covariance() still errors when a base weight inside a cell is NA" | `get_covariance(nawt_in, c(y1, y2), group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.3 | "get_freqs() still errors when a base weight is Inf" | `get_freqs(infwt, f5, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.4 | "get_totals() still errors on a calibrated design when x is NA and na.rm = FALSE" | `get_totals(cal, y1_na, group = group, na.rm = FALSE, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.5 | "grouped get_means() still errors when a base weight is Inf" | `get_means(infwt, y1, group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.6 | "grouped get_totals() still errors when a base weight is Inf" | `get_totals(infwt, y1, group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.7 | "grouped get_ratios() still errors when a base weight is Inf" | `get_ratios(infwt, y3, y1, group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.8 | "get_means() still errors on a calibrated design when x is Inf" | `get_means(cal, y1_inf, group = group, <std>)` | `expect_error(class = "simpleError")` |
| 5.5.9 | "get_ratios() still errors on a calibrated design when either variable is NA and na.rm = FALSE" | Two calls: `get_ratios(cal, y3_na, y1, group = group, na.rm = FALSE, <std>)` (numerator) and `get_ratios(cal, y3, y1_na, group = group, na.rm = FALSE, <std>)` (denominator) | `expect_error(class = "simpleError")` on each call |

Rows 5.5.6 to 5.5.9 are added by decision D16. Their sources: §X.3 row 3 of
the spec for 5.5.6 and 5.5.7; the calibrated `Inf` edge case of `get_means()`
for 5.5.8; the calibrated `NA` edge case of `get_ratios()` for 5.5.9. Each
proves that a kept error still fires. Only 5.5.8 may now fire later than
the moved lonely-PSU abort (§X.1). In 5.5.6 the error fires in the first
cell, before any variance call, now and after the change. In 5.5.7 and
5.5.9 it fires in `get_ratios()` calls 1 and 2, whose abort does not move
(spec §III.4).

The non-error side of the same defects is in the quiet loops:
`variance/nawt_out`, `covariance/nawt_out`, `totals/infwt`, `means/infwt`.

If any of these rows records a condition class other than `simpleError` on
the base commit, assert the recorded class instead and note it in the PR.

### 5.6 A domain marker that holds `NA`

These rows are not in the fixture. Both sides run the current code: `a`
(marker with `NA`) against `b` (the `NA`-free twin) from
`make_domain_pair(class)` (§2.5).

Rows 5.6.1 to 5.6.3 have one body. With `pair <- make_domain_pair(class)`,
`ca <- cell_core_calls(pair$a, freqs_x = "y3")` and
`cb <- cell_core_calls(pair$b, freqs_x = "y3")`, for each name `fn` of the
six: `expect_matches_golden(ca[[fn]](), cell_golden_strip(cb[[fn]]()),
fn)`. If a call warns, assert it with `expect_warning_count()` on both
sides.

| Row | `test_that()` description | `class` |
|---|---|---|
| 5.6.1 | "an NA domain marker gives the same results as FALSE on a Taylor design" | `"taylor"` |
| 5.6.2 | "an NA domain marker gives the same results as FALSE on a replicate design" | `"replicate"` |
| 5.6.3 | "an NA domain marker gives the same results as FALSE on a two-phase design" | `"twophase"` (a phase-1-only row is marked `TRUE`) |
| 5.6.4 | "an NA domain marker gives the same results as FALSE on a nonprob design without replicate weights" | `"nonprob"`: only the `means` entry, each side inside `expect_warning_count(..., "surveycore_warning_nonprob_srs_fallback", 3L)`, then as above |

The count of 3 in row 5.6.4 is reasoned (one warning per cell, three
groups), not measured. If the observed count differs, assert the observed
count on both `a` and `b`, and record it in the PR.

### 5.7 Error classes not reached above

| Row | `test_that()` description | Call | Assertion |
|---|---|---|---|
| 5.7.1 | "get_ratios() errors when a group's denominator total is zero" | `get_ratios(tay, y3, y1_c_zero, group = group, <std>)` | `expect_error(class = "surveycore_error_ratio_zero_denominator")` and `expect_snapshot(error = TRUE, ...)` |
| 5.7.2 | "get_freqs() errors on an all-NA variable when na.rm is FALSE" | `get_freqs(tay, y_allna, na.rm = FALSE, <std>)` | `expect_error(class = "surveycore_error_all_na")` and `expect_snapshot(error = TRUE, ...)` |

In row 5.7.1 group C has complete rows with a zero denominator, so the
error fires. `ratios/tay_c_zero_den` is the contrast: there group C has no
complete row and the call does not raise.

---

## 6. Gotcha coverage

Each gotcha the comprehension stage listed, and each edge case, with where
it is covered. §4 refers here.

| Gotcha or edge case | Covered by |
|---|---|
| Order of floating-point sums | Every replicate golden row at 1e-12, the variance and covariance replicate rows in particular; the `NaN` masks of §2.6 |
| `NA` and `Inf` replicate weights are allowed | §5.2 |
| Subset sums are exact only with finite replicate weights | 5.2.1 (`freqs/rep_na`, `freqs/rep_inf`, `freqs/np_rep_na`), 5.2.3, 5.2.4 |
| Zero replicate weights | `freqs/rep_zero` |
| `lonely.psu = "fail"` or an unknown value, and condition order | §5.3: class and message asserted on all six functions, order not asserted (accepted change, D6, D9) |
| The abort when a call has more cells than one group of the SE step | 5.3.14, 5.3.15 |
| Post-loop warnings do not fire when the abort fires | 5.3.13 |
| The option is read per cell today | Core rows `lonely_remove`, `lonely_adjust`, `lonely_average`, `lonely_certainty`, `tay_fail` |
| Per-cell warnings on the nonprob SRS route | The `*/np_srs` rows of §3.3, with exact counts |
| Cell-level df (issue #326) | `means/cal`, `means/cal_strat`, `means/cal_ids`, `means/cal_srs`, `means/cal_multi`, `means/cal_dom`, `means/cal_y1_na`; the zero-df warning in `means/cal_srs_two` |
| `sqrt(max(0, v))` against `sqrt(pmax(0, ...))` | `lonely_average` rows and §5.1 rows, with the `NaN` mask check |
| Standard errors computed in groups of cells | The `blk` rows of §3.2: 16, 17, 32, 33, 64 and 65 live cells for `get_variance()`, `get_covariance()` and `get_ratios()`; `variance/tay_many` (75), `covariance/tay_many` (90) |
| A non-finite cell in one group of the SE step only | `variance/blk65_inf`, `covariance/blk65_inf`, `ratios/blk65_na` |
| A cell that returns early between live cells | `variance/tay_c_na`, `covariance/tay_c_na`, `variance/blk65_gap` |
| One live cell | `variance/tay_one_cell`, `covariance/tay_pair`, `means/tay_ungrouped`, `totals/tay_ungrouped`, `ratios/tay_ungrouped` |
| All-NA outcome | `means/tay_allna`, `totals/tay_allna`, `variance/tay_allna`, `covariance/tay_allna`, `ratios/tay_allna`, `freqs/tay_empty_dom`, 5.7.2 |
| Empty cell | `means/tay_c_na`, `totals/tay_c_na`, `variance/tay_c_na`, `covariance/tay_c_na`, `ratios/tay_c_na`, `ratios/tay_den_na` |
| Empty domain | `*/tay_empty_dom` for all six functions |
| Zero group combinations (zero live cells) | `*/zero_combos` for `get_means()`, `get_totals()`, `get_variance()`, `get_covariance()`, `get_ratios()` |
| Too few rows in a cell | `variance/tay_one`, `covariance/tay_one`, `variance/blk65_gap` |
| Single-level groups | `*/single` for all six functions |
| Small cells | `*/small_cell` for `get_means()`, `get_totals()`, `get_variance()`, `get_covariance()`, `get_ratios()` |
| A group column that is partly `NA`, `na.rm = FALSE` | `means/tay_group_na` |
| Zero denominator | 5.7.1, `ratios/tay_c_zero_den` |
| Internal weight column | Core rows on `tay_probs` |
| Labels and broom names | `freqs/lab_broom`, `means/lab_broom` |
| Domain-filtered designs | Core rows on `tay_dom`, `rep_dom`, `cal_dom`, `np_rep_dom`, `tph_dom`; `means/np_srs_dom`; `rep_allna_dom`, `np_rep10_na_dom`; an `NA` marker on four routes (§5.6) |
| Second callers | 4.9.1; `get_ratios()` core rows |
| Non-finite values in one group (multistage effect included) | §5.1 |
| `get_variance()` / `get_covariance()` store no `.vcov`; the `na.rm = FALSE` override wins | 4.6.3; `variance/tay_narm_false`, `covariance/tay_narm_false` |
| A cell under the `na.rm = FALSE` override still reaches its variance step | 5.3.16, 5.3.17 |
| Existing defects (NA and Inf base weights) | §5.5 and their quiet-loop counterparts |
| Kept base R errors that may now come later in the call (calibration projection, `Inf` base weight) | 5.5.4 to 5.5.9 |
| Cost grows with the number of cells | Out of scope for tests: it is speed, not a result. The `blk` and `tay_many` rows prove large calls keep their results. |
| Stale source comments | Out of scope for tests: no observable behaviour. |

Out of scope, with reason:

- Empty input and single-row input: the constructors refuse both, so no
  analysis call can receive them. Existing constructor tests cover the
  refusal.
- Zero base weights: `as_survey()` refuses them
  (`surveycore_error_weights_nonpositive`). Zero replicate weights are
  covered (`freqs/rep_zero`).
- An optimized BLAS: CI runs whatever BLAS its runners have. D3's 1e-12
  allows a last-bit difference. No row forces a BLAS.
- Speed: measured outside the test suite. No test asserts time.

---

## 7. Tolerances

| Comparison | Tolerance | Justification |
|---|---|---|
| Golden rows (every column, `.vcov`, `.survey_result`, `.meta`) | 1e-12 | Decision D3. The comparison is against the same computation on the base commit, not an independent method, so the default 1e-10 / 1e-8 / 1e-6 would hide a change this work must not make. `identical()` is not asserted, so an optimized BLAS can differ in the last bit. |
| Self-consistency rows (§5.1) and `NA`-marker rows (§5.6) | 1e-12 | Both sides run the current code on the same domain values. |
| `NaN` masks, class vectors, column names, integer and character columns | exact | `expect_identical()` |

The defaults (point 1e-10, SE 1e-8, CI 1e-6) still apply to the existing
`survey` oracle blocks, which this work does not change.

---

## 8. Warning baseline

The full suite (`devtools::test()`) raises 369 warnings on `develop`
(`CLAUDE.md`). After each PR the count is still 369. Every warning a new
block triggers is asserted by class through `expect_warning_count()`, and
every quiet block asserts zero warnings the same way. Record the count in
each PR.

Coverage is measured as `.claude/rules/testing-surveycore.md` states, with
`NOT_CRAN=true`, so the new file runs.

---

## 9. Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
