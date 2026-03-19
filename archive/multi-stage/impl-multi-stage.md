# Implementation Plan — Multi-Stage Sampling Support

**Plan ID:** `multi-stage`
**Spec:** `plans/spec-multi-stage.md` (v0.3 — approved)
**Decisions:** `plans/decisions-multi-stage.md`
**Date:** 2026-03-12

---

## Overview

This plan delivers multi-stage sampling support for `survey_taylor` designs: a
shared `.build_cluster_matrices()` helper that replaces five identical inline
matrix-building blocks, Taylor series variance for 2- and 3-stage designs,
multi-column FPC support in `as_survey()`, updated GLM and print methods, and a
complete oracle test suite comparing against `survey::svydesign()`. Seven PRs
in dependency order; PRs 3, 4, and 6 can run in parallel once PR 2 merges;
PR 7 must wait for PR 3.

---

## PR Map

- [x] PR 1: `feature/multi-stage-test-helper` — Extend `make_survey_data()` with `n_ssu` and `n_unit` parameters
- [x] PR 2: `feature/build-cluster-matrices` — Add `.build_cluster_matrices()` shared helper to `R/utils.R` with unit tests
- [x] [parallel-ok] PR 3: `feature/multi-stage-constructor` — Update `as_survey()` multi-column FPC resolution; add per-column and count validations; update `plans/error-messages.md`
- [x] [parallel-ok] PR 4: `feature/multi-stage-variance-taylor` — Refactor `R/variance-taylor.R` to use helper; remove `# nocov` from `.svy_multistage()` multi-stage path; add regression tests
- [x] PR 5: `feature/multi-stage-analysis` — Refactor `R/analysis-means-helpers.R`, `R/analysis-freqs-helpers.R`, `R/analysis-totals-helpers.R`; add full oracle test suite
- [x] [parallel-ok] PR 6: `feature/multi-stage-glm` — Replace inline FPC block in `R/glm.R`; add GLM oracle tests
- [x] PR 7: `feature/multi-stage-print` — Update `R/methods-print.R` per-stage FPC display; add snapshot test

**Dependency graph:**

```
PR 1 → PR 2 → PR 3 → PR 7
       PR 2 → PR 4 → PR 5
       PR 2 → PR 6
```

---

---

## PR 1: Extend `make_survey_data()`

**Branch:** `feature/multi-stage-test-helper`
**Depends on:** none

**Files (TDD order):**
- `tests/testthat/helper-test-data.R` — Add `n_ssu` and `n_unit` parameters

**TDD steps:**

1. **Write failing tests** in `tests/testthat/test-constructors.R` (new section
   "make_survey_data() extension"):
   - `make_survey_data(n = 100, n_psu = 10, n_ssu = 5, seed = 1)` produces a
     data.frame with columns `ssu` (character, format `"{psu}_s{j}"`, unique
     within each PSU) and `fpc2` (integer, constant within each PSU = `n_ssu * 2L`)
   - `make_survey_data(n = 100, n_psu = 10, n_ssu = 5, n_unit = 3, seed = 1)`
     additionally produces `unit` (character, format `"{ssu}_u{j}"`) and `fpc3`
     (integer, constant within each SSU = `n_unit * 2L`)
   - `make_survey_data(n_unit = 3)` throws with `stop()` (no `n_ssu`)
   - Calling with no `n_ssu`/`n_unit` produces identical output to the current
     function (no new columns; `set.seed(seed)` result unchanged)
   - Run `devtools::test("test-constructors")` — confirm tests fail.

2. **Implement** `n_ssu` and `n_unit` parameters per spec §XI `make_survey_data()`
   extension section:
   - Add after existing `df <- data.frame(...)` block, guarded by `if (!is.null(n_ssu))`
   - `n_ssu` block: assign `ssu` column (`paste0(psu_col, "_s", ssu_index)` where
     `ssu_index` is assigned round-robin within each PSU), add `fpc2 = n_ssu * 2L`
   - `n_unit` block: same pattern with `unit` column and `fpc3 = n_unit * 2L`;
     `stop()` guard when `is.null(n_ssu)`

3. **Run** `devtools::test()` — all tests pass.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] New columns (`ssu`, `fpc2`, `unit`, `fpc3`) have correct types and formats
- [ ] `fpc2` is constant within each PSU; `fpc3` is constant within each SSU
- [ ] No new columns appear when `n_ssu = NULL` (default)
- [ ] `devtools::test()` passes; `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed on this branch

---

## PR 2: Add `.build_cluster_matrices()`

**Branch:** `feature/build-cluster-matrices`
**Depends on:** PR 1

**Files (TDD order):**
- `tests/testthat/test-variance-taylor.R` — Unit tests for `.build_cluster_matrices()`
- `R/utils.R` — Add `.build_cluster_matrices(data, vars)`
- `R/variance-srs.R` — Replace inline FPC/matrix blocks in `.vcov_pair_srs()` (two call sites) with `.build_cluster_matrices()`
- `tests/testthat/test-variance-srs.R` — Add regression oracle test confirming output unchanged post-refactor

**TDD steps:**

1. **Write failing unit tests** in `test-variance-taylor.R` (new section
   `.build_cluster_matrices()` unit tests):

   ```r
   # Single-stage structure
   test_that(".build_cluster_matrices() returns n×1 matrices for single-stage design [unit]", {
     df <- make_survey_data(n = 100, n_psu = 10, seed = 1)
     sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
     test_invariants(sc)
     mats <- .build_cluster_matrices(sc@data, sc@variables)
     expect_identical(dim(mats$clusters_mat),  c(100L, 1L))
     expect_identical(dim(mats$strata_mat),    c(100L, 1L))
     expect_identical(dim(mats$fpcs$sampsize), c(100L, 1L))
     expect_identical(dim(mats$fpcs$popsize),  c(100L, 1L))
   })

   # 2-stage structure
   test_that(".build_cluster_matrices() returns n×2 matrices for 2-stage design [unit]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     vars <- list(ids = c("psu", "ssu"), weights = "wt", strata = "strata",
                  fpc = c("fpc", "fpc2"), nest = TRUE)
     mats <- .build_cluster_matrices(df, vars)
     expect_identical(dim(mats$clusters_mat),  c(200L, 2L))
     expect_identical(dim(mats$strata_mat),    c(200L, 2L))
     expect_identical(dim(mats$fpcs$sampsize), c(200L, 2L))
     expect_identical(dim(mats$fpcs$popsize),  c(200L, 2L))
   })

   # 3-stage structure
   test_that(".build_cluster_matrices() returns n×3 matrices for 3-stage design [unit]", {
     df <- make_survey_data(n = 300, n_psu = 10, n_ssu = 5, n_unit = 3, seed = 1)
     vars <- list(ids = c("psu", "ssu", "unit"), weights = "wt",
                  strata = "strata", fpc = NULL, nest = FALSE)
     mats <- .build_cluster_matrices(df, vars)
     expect_identical(dim(mats$clusters_mat),  c(300L, 3L))
     expect_null(mats$fpcs$popsize)
   })

   # No ids — each row is its own PSU
   test_that(".build_cluster_matrices() assigns each row its own PSU when ids is NULL [unit]", {
     df <- make_survey_data(n = 50, seed = 1)
     vars <- list(ids = NULL, weights = "wt", strata = NULL, fpc = NULL, nest = FALSE)
     mats <- .build_cluster_matrices(df, vars)
     expect_identical(mats$clusters_mat[, 1L], seq_len(50L))
   })

   # nest = TRUE applies only to stage 1
   test_that(".build_cluster_matrices() applies nest adjustment only at stage 1 [unit]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     vars_nest <- list(ids = c("psu", "ssu"), weights = "wt", strata = "strata",
                       fpc = NULL, nest = TRUE)
     vars_no_nest <- list(ids = c("psu", "ssu"), weights = "wt", strata = "strata",
                          fpc = NULL, nest = FALSE)
     mats_nest    <- .build_cluster_matrices(df, vars_nest)
     mats_no_nest <- .build_cluster_matrices(df, vars_no_nest)
     # Stage 1 differs (nest interaction changes PSU IDs)
     expect_false(identical(mats_nest$clusters_mat[, 1L], mats_no_nest$clusters_mat[, 1L]))
     # Stage 2 col 2 is globally unique in both cases — different because col1 differs
   })

   # Partial FPC: j > n_fpc gets Inf
   test_that(".build_cluster_matrices() fills Inf for stages beyond n_fpc [unit]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     vars <- list(ids = c("psu", "ssu"), weights = "wt", strata = "strata",
                  fpc = "fpc", nest = FALSE)  # only stage-1 FPC
     mats <- .build_cluster_matrices(df, vars)
     expect_true(all(mats$fpcs$popsize[, 2L] == Inf))
   })

   # sampsize col 1: PSUs per stratum; col 2: SSUs per PSU
   test_that(".build_cluster_matrices() sampsize matches PSU/SSU counts [unit]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     vars <- list(ids = c("psu", "ssu"), weights = "wt", strata = "strata",
                  fpc = NULL, nest = FALSE)
     mats <- .build_cluster_matrices(df, vars)
     # Col 2: each row gets the number of SSUs in its PSU
     psu_col <- mats$clusters_mat[, 1L]
     ssu_col <- mats$clusters_mat[, 2L]
     expected_ssu_n <- tapply(ssu_col, psu_col, function(x) length(unique(x)))
     actual <- mats$fpcs$sampsize[, 2L]
     expect_identical(actual, as.integer(expected_ssu_n[as.character(psu_col)]))
   })
   ```

   Run `devtools::test("test-variance-taylor")` — confirm new tests fail.

2. **Implement** `.build_cluster_matrices(data, vars)` in `R/utils.R` per spec §V
   algorithm. Critical implementation notes:
   - Step 3 (clusters matrix): use `if (k > 1L) { lapply(seq(2L, k), ...) } else { list() }`.
     Never `lapply(2:k, ...)` — in R, `2:1` evaluates to `c(2L, 1L)` not an empty vector.
   - Column assembly: `c(psu_id, unlist(extra_cols))` — never `c(psu_id, lapply(...))`.
     `c(vector, list(vector))` produces a list, causing `matrix()` to fail.
   - Stage j > 1 IDs: `as.integer(interaction(clusters_mat[, j-1L], data[[vars$ids[[j]]]], drop = TRUE))`
   - `sampsize_j_vec` lookup: `as.integer(units_per_parent[as.character(parent_j)])` —
     `as.character()` required because `tapply()` names are always character.
   - Partial FPC: `if (j <= n_fpc) { ... } else { rep(Inf, n) }` for `popsize_mat` columns.
   - `stopifnot()` internal consistency assertion at the end per spec §V.

3. **Write regression oracle test** in `test-variance-srs.R` for the `variance-srs.R`
   refactor — confirms the inline block replacement produces identical output:

   ```r
   test_that("get_means() on SRS design matches survey::svymean() after refactor [regression oracle]", {
     skip_if_not_installed("survey")
     df <- make_survey_data(n = 200, seed = 1)
     sc <- as_survey_srs(df, weights = wt)
     sv <- survey::svydesign(id = ~1, weights = ~wt, data = df)
     expect_equal(
       get_means(sc, y1)$mean,
       coef(survey::svymean(~y1, sv))[[1L]],
       tolerance = 1e-10
     )
     expect_equal(
       get_means(sc, y1)$se,
       SE(survey::svymean(~y1, sv))[[1L]],
       tolerance = 1e-8
     )
   })
   ```

   Run — confirm test passes before touching `variance-srs.R` (establishes the pre-refactor oracle).

4. **Implement** the `variance-srs.R` refactor: replace the two inline FPC/matrix
   blocks in `.vcov_pair_srs()` with `.build_cluster_matrices(data, vars)` calls, using
   `mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs` in place of the inline equivalents.

5. **Run** `devtools::test()` — all tests pass, including existing tests unchanged.
   Run `devtools::check()` — 0/0/≤2.

**Acceptance criteria:**
- [ ] All new unit tests confirmed failing before implementation
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync (no roxygen changes expected; verify clean)
- [ ] `2:k` guard present in implementation (comment explaining the `2:1` issue)
- [ ] `unlist(lapply(...))` pattern used (not raw `c(vector, lapply(...))`)
- [ ] Internal `stopifnot()` assertion present
- [ ] `R/variance-srs.R` inline blocks replaced; regression oracle passes
- [ ] Changelog entry written and committed

---

## PR 3: Update `as_survey()` Multi-Column FPC

**Branch:** `feature/multi-stage-constructor`
**Depends on:** PR 2 (for `.build_cluster_matrices()` used in `sampsize_j_vec` validation)

**Files (TDD order):**
- `tests/testthat/test-constructors.R` — New tests for all new error/warn/inform classes
- `plans/error-messages.md` — Add rows 88–91; split row 13b
- `R/core-constructors.R` — Replace `.resolve_single_col()` for FPC; add per-column validation loop; add count vs ID check; update `@param fpc` roxygen
- `man/as_survey.Rd` — Updated by `devtools::document()`

**TDD steps:**

1. **Write failing tests** in `test-constructors.R` (new section "as_survey()
   multi-stage FPC"):

   ```r
   test_that("as_survey() accepts multi-column fpc and stores as character vector", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata,
                     fpc = c(fpc, fpc2))
     test_invariants(sc)   # always first
     expect_identical(sc@variables$fpc, c("fpc", "fpc2"))
   })

   test_that("as_survey() stores single-column fpc as character(1) [backward compat]", {
     df <- make_survey_data(n = 200, n_psu = 20, seed = 1)
     sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
     test_invariants(sc)
     expect_identical(sc@variables$fpc, "fpc")
   })

   test_that("as_survey() errors when fpc has more columns than ID stages", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     expect_error(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2, fpc)),
       class = "surveycore_error_fpc_too_many_stages"
     )
     expect_snapshot(error = TRUE,
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2, fpc)))
   })

   test_that("as_survey() warns for partial FPC (stage-1 col with 2-stage ids)", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     expect_warning(
       as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata, fpc = fpc),
       class = "surveycore_warning_fpc_partial_stages"
     )
   })

   test_that("as_survey() rejects NA in stage-2 FPC column [dual-pattern]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     df$fpc2_bad <- df$fpc2
     df$fpc2_bad[1L] <- NA_integer_
     expect_error(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
       class = "surveycore_error_fpc_na"
     )
     expect_snapshot(error = TRUE,
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)))
   })

   test_that("as_survey() rejects nonpositive stage-2 FPC value [dual-pattern]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     df$fpc2_bad <- df$fpc2
     df$fpc2_bad[1L] <- 0L
     expect_error(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
       class = "surveycore_error_fpc_nonpositive"
     )
     expect_snapshot(error = TRUE,
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)))
   })

   test_that("as_survey() rejects stage-2 FPC smaller than stage-2 cluster count [dual-pattern]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     df$fpc2_bad <- 2L  # population = 2 SSUs; but each PSU samples 5 SSUs → fpc_smaller_than_n
     expect_error(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
       class = "surveycore_error_fpc_smaller_than_n"
     )
     expect_snapshot(error = TRUE,
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)))
   })

   test_that("as_survey() rejects non-constant stage-2 FPC fraction within PSU [dual-pattern]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     set.seed(99)
     df$fpc2_bad <- runif(nrow(df), 0.1, 0.9)  # varies within PSU
     expect_error(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
       class = "surveycore_error_fpc_not_constant"
     )
     expect_snapshot(error = TRUE,
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)))
   })

   test_that("as_survey() warns when FPC population size varies within stage parent [warn]", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     # Assign slightly different popsize values within the same PSU for stage-2
     df$fpc2_vary <- df$fpc2 + sample(0:2, nrow(df), replace = TRUE)
     expect_warning(
       as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_vary)),
       class = "surveycore_warning_fpc_popsize_varies_within_stratum"
     )
   })

   # Note: check test-constructors.R for an existing surveycore_error_fpc_multiple
   # test before adding this one — if a snapshot already exists, remove the
   # duplicate rather than adding a second.
   test_that("as_survey_replicate() still rejects multi-column fpc", {
     df <- make_survey_data(n = 100, n_psu = 10, design = "replicate", seed = 1)
     repwt_cols <- grep("^repwt_", names(df), value = TRUE)
     expect_error(
       as_survey_replicate(df, weights = wt,
                           repweights = tidyselect::all_of(repwt_cols),
                           type = "BRR", fpc = c(fpc, fpc)),
       class = "surveycore_error_fpc_multiple"
     )
     expect_snapshot(error = TRUE,
       as_survey_replicate(df, weights = wt,
                           repweights = tidyselect::all_of(repwt_cols),
                           type = "BRR", fpc = c(fpc, fpc)))
   })
   ```

   Run — confirm failing.

2. **Update `plans/error-messages.md`**: add rows 88–91 per spec §X; split row 13b.

3. **Implement** in `R/core-constructors.R`:
   - Replace the `.resolve_single_col()` call for `fpc` (lines 418–424) with
     `tidyselect::eval_select()` pattern per spec §IV. No change to `.resolve_single_col()`
     for `strata`, `weights`, `probs`, or `ids`.
   - Replace the single `.validate_fpc(fpc_var, data)` call (line 517) with a
     per-column loop over `fpc_vars`. Each column gets the existing FPC checks
     (NA, nonpositive, mixed-type) plus the new stage-j-aware checks
     (`fpc_smaller_than_n` using `sampsize_j_vec` from `.build_cluster_matrices()`;
     `fpc_not_constant` for fraction columns; `fpc_popsize_varies_within_stratum`
     for popsize columns).
   - Add count-vs-ID validation after FPC resolution (error
     `surveycore_error_fpc_too_many_stages`, warn
     `surveycore_warning_fpc_partial_stages`).
   - Update `@variables$fpc` from `fpc_var` (character(1) or NULL) to `fpc_vars`
     (character vector or NULL). Store result identically for single-column case
     to preserve backward compatibility.
   - Update `@param fpc` roxygen: mention multi-column support and stage semantics.

4. **Run** `devtools::document()` — verify `man/as_survey.Rd` updated.
   Run `devtools::test()` — all pass. `devtools::check()` — 0/0/≤2.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation
- [ ] `sc@variables$fpc` is a character vector of length k for k-stage FPC
- [ ] Single-column FPC (`character(1)`) behavior unchanged from pre-refactor
- [ ] All new error/warn/inform classes tested with dual-pattern or `expect_message()`
- [ ] `plans/error-messages.md` has rows 88–91 and updated row 13b
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed

---

## PR 4: Refactor `R/variance-taylor.R`

**Branch:** `feature/multi-stage-variance-taylor`
**Depends on:** PR 2

**Files (TDD order):**
- `tests/testthat/test-variance-taylor.R` — Regression test (single-stage unchanged) + `.taylor_build_inputs()` shape test
- `R/variance-taylor.R` — Replace inline blocks in `.taylor_build_inputs()` and `.vcov_pair_taylor()`; remove `# nocov` from `.svy_multistage()` multi-stage path

**TDD steps:**

1. **Write regression oracle test** in `test-variance-taylor.R` comparing against
   `survey::svymean()` directly — if the refactor produces values that don't match
   the survey oracle, that signals a bug, not an expected change:

   ```r
   test_that("get_means() on single-stage NHANES matches survey::svymean() [regression oracle]", {
     skip_if_not_installed("survey")
     sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                     strata = sdmvstra, nest = TRUE)
     test_invariants(sc)
     sv <- survey::svydesign(
       id = ~sdmvpsu, weights = ~wtmec2yr, strata = ~sdmvstra,
       data = nhanes_2017, nest = TRUE
     )
     expect_equal(
       get_means(sc, bpxsy1)$mean,
       coef(survey::svymean(~bpxsy1, sv, na.rm = TRUE))[["bpxsy1"]],
       tolerance = 1e-10
     )
     expect_equal(
       get_means(sc, bpxsy1)$se,
       SE(survey::svymean(~bpxsy1, sv, na.rm = TRUE))[["bpxsy1"]],
       tolerance = 1e-8
     )
   })
   ```

   Run — confirm test passes before any code changes (single-stage already correct).

   Also write a test verifying `.taylor_build_inputs()` produces n×1 matrices for
   the current single-stage design (structural shape test). Run — passes.

   Now write a test that will fail once we introduce multi-stage support:

   ```r
   test_that(".taylor_build_inputs() returns n×2 matrices for 2-stage design [shape]", {
     df <- make_survey_data(n = 300, n_psu = 30, n_ssu = 5, seed = 1)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
     test_invariants(sc)
     inp <- .taylor_build_inputs(sc, "y1")
     expect_identical(ncol(inp$clusters), 2L)
     expect_identical(ncol(inp$stratas),  2L)
     expect_identical(ncol(inp$fpcs$sampsize), 2L)
   })
   ```

   Run — confirms failure (current code returns n×1 for multi-stage designs).

2. **Implement** in `R/variance-taylor.R`:

   a. **`.taylor_build_inputs()` (lines 186–265):** Replace the inline matrix
      block (lines 196–264) with the pattern from spec §VI:
      ```r
      keep_y <- if (na.rm) !is.na(y) else seq_along(y)
      mats   <- .build_cluster_matrices(design@data, design@variables)
      y      <- y[keep_y]
      w      <- data[[vars$weights]][keep_y]
      mats$clusters_mat  <- mats$clusters_mat[keep_y, , drop = FALSE]
      mats$strata_mat    <- mats$strata_mat[keep_y, , drop = FALSE]
      mats$fpcs$sampsize <- mats$fpcs$sampsize[keep_y, , drop = FALSE]
      if (!is.null(mats$fpcs$popsize))
        mats$fpcs$popsize <- mats$fpcs$popsize[keep_y, , drop = FALSE]
      ```
      Return `mats$clusters_mat` as `clusters`, `mats$strata_mat` as `stratas`,
      `mats$fpcs` as `fpcs` per spec §VI return value table.

   b. **`.vcov_pair_taylor()` (lines ~389–427):** Replace the inline block
      (lines 391–427) with `mats <- .build_cluster_matrices(data, vars)` and
      update all references to use `mats$clusters_mat`, `mats$strata_mat`,
      `mats$fpcs`.

   c. **`.svy_multistage()` (lines 141 and 157):** Remove the `# nocov start`
      marker (line 141) and `# nocov end` marker (line 157). Do not remove the
      `# nocov start/end` markers in `.svy_onestrat()` (lines 43–48 and 55–59)
      — those guard a different `nsubset < nPSU` branch that remains unreachable.

3. **Run** `devtools::test()` — regression test and shape tests pass.
   Line coverage for `.svy_multistage()` multi-stage path should now increase
   (verified via `covr::package_coverage()` or by checking test output).

**Acceptance criteria:**
- [ ] Regression oracle test passes (single-stage NHANES values match `survey::svymean()`, point 1e-10, SE 1e-8)
- [ ] `# nocov start/end` removed from `.svy_multistage()` lines 141 and 157 only
- [ ] `.svy_onestrat()` `# nocov` markers untouched (different branch)
- [ ] `.taylor_build_inputs()` returns n×k matrices for k-stage designs
- [ ] `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed

**Notes:** The `sampsize` behavioral change (now computed from full data before
`na.rm` filter rather than post-filter) is intentional and matches `survey` package
semantics (sampsize is a design property, not an outcome property). The regression
oracle test always compares against `survey::svymean()` — if post-refactor values
diverge from the oracle, that indicates a bug in the implementation, not an
expected shift.

---

## PR 5: Refactor Analysis Helpers + Full Oracle Suite

**Branch:** `feature/multi-stage-analysis`
**Depends on:** PR 2, PR 4

**Files (TDD order):**
- `tests/testthat/test-variance-taylor.R` — Full oracle suite (§XI) + edge case tests
- `R/analysis-means-helpers.R` — Replace inline block in `.taylor_mean_cell()` (lines 78–114)
- `R/analysis-freqs-helpers.R` — Replace inline block in `.taylor_freq_cell()` (lines 83–123)
- `R/analysis-totals-helpers.R` — Replace inline block in `.taylor_totals_cell()` (lines 57–94)

**TDD steps:**

1. **Write all failing oracle tests** in `test-variance-taylor.R`. Every oracle
   block follows the pattern:
   - `skip_if_not_installed("survey")`
   - Create `df` with `make_survey_data()` using `n_ssu` or `n_unit` as needed
   - `sc <- as_survey(...)` → `test_invariants(sc)` → `get_*(sc, ...)`
   - Create equivalent `survey::svydesign()` → `survey::svymean()` etc.
   - `expect_equal(..., tolerance = 1e-10)` for point estimates
   - `expect_equal(..., tolerance = 1e-8)` for SEs

   **Required oracle comparisons** (all from spec §XI table):

   ```r
   # 2-stage, no FPC — get_means()
   test_that("get_means() matches survey::svymean() for 2-stage, no FPC [oracle]", {
     skip_if_not_installed("survey")
     df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
     test_invariants(sc)
     sv <- survey::svydesign(id = ~psu + ssu, weights = ~wt, strata = ~strata,
                             data = df, nest = TRUE)
     expect_equal(get_means(sc, y1)$mean, coef(survey::svymean(~y1, sv))[[1L]], tolerance = 1e-10)
     expect_equal(get_means(sc, y1)$se,   SE(survey::svymean(~y1, sv))[[1L]],   tolerance = 1e-8)
   })

   # 2-stage, FPC at stage 1 only — get_means()
   # 2-stage, FPC at both stages — get_means()
   # 2-stage, get_freqs() vs survey::svymean(~y3, ...)
   # 2-stage, get_totals() vs survey::svytotal(~y1, ...)
   # 2-stage, get_corr() vs survey::svycor(~y1+y2, ...)
   # 2-stage, get_quantiles() vs survey::svyquantile(~y1, ..., quantiles = 0.5)
   # 2-stage, get_ratios() vs survey::svyratio(~y1, ~y2, ...)
   # 3-stage, no FPC — get_means() (verifies 3-col matrix builds without error)
   # 3-stage, FPC at stage 1 only — get_means()
   # 3-stage, FPC at all stages — get_means()
   ```

   See spec §XI for reference `survey::svydesign()` call patterns for each
   FPC variant. Tolerance: point 1e-10, SE 1e-8.

   **Required edge case tests** (all from spec §XI edge cases table):

   ```r
   # 2-stage with nest = TRUE (PSU IDs reused across strata)
   # 2-stage, single SSU per PSU (lonely PSU at stage 2)
   # 2-stage with na.rm = TRUE
   # 2-stage na.rm = TRUE, all-NA PSU (behavioral change: PSU counted in sampsize)
   # 2-stage with domain estimation (filter() before get_means())
   # 2-stage domain AND na.rm = TRUE
   # Grouped estimate: get_means(sc_2stage, y1, group = strata) vs survey::svyby()
   # Single-stage unchanged [regression guard]
   ```

   Run `devtools::test("test-variance-taylor")` — confirm all new tests fail.

2. **Implement** the three inline block replacements:

   For each of `.taylor_mean_cell()`, `.taylor_freq_cell()`, `.taylor_totals_cell()`:
   Replace the block starting with `strata_id <- if (!is.null(vars$strata)) ...`
   through `fpcs <- list(...)` with:
   ```r
   mats <- .build_cluster_matrices(data, vars)
   ```
   Then replace `clusters_mat`, `strata_mat`, `fpcs` references with
   `mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs`.

   Do NOT change `analysis-corr-helpers.R`, `analysis-quantiles-helpers.R`, or
   `analysis-ratios-helpers.R` — they have no inline matrix-building block and
   gain multi-stage support transitively through `.vcov_pair_taylor()` (PR 4)
   and the means/totals cell functions updated here.

3. **Run** `devtools::test()` — all oracle and edge case tests pass.
   `devtools::check()` — 0/0/≤2.

**Acceptance criteria:**
- [ ] All new oracle/edge tests confirmed failing (red) before implementation
- [ ] All 11 oracle comparisons from spec §XI table pass (point 1e-10, SE 1e-8)
- [ ] 2-stage grouped estimate matches `survey::svyby()` oracle
- [ ] Single-stage regression guard passes (values unchanged)
- [ ] `analysis-corr-helpers.R`, `analysis-quantiles-helpers.R`, `analysis-ratios-helpers.R` not modified
- [ ] `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed

---

## PR 6: Refactor `R/glm.R`

**Branch:** `feature/multi-stage-glm`
**Depends on:** PR 2

**Files (TDD order):**
- `tests/testthat/test-glm.R` — Multi-stage GLM oracle test
- `R/glm.R` — Replace inline FPC block in the Taylor variance-score function

**TDD steps:**

1. **Write failing oracle test** per spec §VIII.5:

   ```r
   test_that("survey_glm() matches survey::svyglm() for 2-stage design [oracle]", {
     skip_if_not_installed("survey")
     df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
     test_invariants(sc)
     test_glm_fit_invariants(survey_glm(y1 ~ y2, design = sc))
     sv <- survey::svydesign(id = ~psu + ssu, weights = ~wt, strata = ~strata,
                             data = df, nest = TRUE)
     sc_fit <- survey_glm(y1 ~ y2, design = sc)
     sv_fit <- survey::svyglm(y1 ~ y2, design = sv)
     expect_equal(coef(sc_fit), coef(sv_fit), tolerance = 1e-10)
     expect_equal(SE(sc_fit),   SE(sv_fit),   tolerance = 1e-8)
   })
   ```

   Also write a smoke test that `survey_glm()` on a 2-stage design with
   multi-column FPC doesn't error (even before checking numeric correctness):
   ```r
   test_that("survey_glm() accepts multi-stage design without error [smoke]", {
     df <- make_survey_data(n = 300, n_psu = 30, n_ssu = 5, seed = 1)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata,
                     fpc = c(fpc, fpc2))
     expect_no_error(survey_glm(y1 ~ y2, design = sc))
   })
   ```

   Run — confirm both fail (the `data[[vars$fpc]]` errors for multi-stage).

2. **Identify** the inline FPC block in `R/glm.R`. The block spans approximately
   lines 225–272 (inside the `.taylor_var_score_matrix()` or equivalent function
   that calls `.svy_recvar()`). The problematic line is:
   ```r
   fpc_vals <- data[[vars$fpc]]    # errors when vars$fpc is character vector
   ```

3. **Implement** the replacement per spec §VIII.5:
   ```r
   mats      <- .build_cluster_matrices(design@data, design@variables)
   popsize_mat <- mats$fpcs$popsize
   ```
   Use `mats$clusters_mat` and `mats$strata_mat` in place of the inline equivalents.
   The second FPC reference in `R/glm.R` (line ~486, `fpc_var <- if (S7::S7_inherits(design, survey_srs)) vars$fpc else NULL`) handles SRS-specific logic only and must NOT be changed.

4. **Run** `devtools::test()` — oracle and smoke tests pass.
   `devtools::check()` — 0/0/≤2.

**Acceptance criteria:**
- [ ] Oracle test and smoke test confirmed failing before implementation
- [ ] `survey_glm()` on 2-stage design (with and without FPC) produces no error
- [ ] GLM coefficients and SEs match `survey::svyglm()` oracle (1e-10 / 1e-8)
- [ ] SRS-specific FPC reference at line ~486 unchanged
- [ ] `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed

---

## PR 7: Update `print.survey_taylor` Per-Stage FPC Display

**Branch:** `feature/multi-stage-print`
**Depends on:** PR 3 (for multi-column `@variables$fpc` to be set by constructor)

**Files (TDD order):**
- `tests/testthat/test-methods-print.R` — Snapshot test for per-stage FPC
- `R/methods-print.R` — Update FPC display section in `print.survey_taylor`

**TDD steps:**

1. **Write failing snapshot test** per spec §IX.5:

   ```r
   test_that("print.survey_taylor shows per-stage FPC for 2-stage design", {
     df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
     sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata,
                     fpc = c(fpc, fpc2))
     expect_snapshot(print(sc))
   })
   ```

   Run `testthat::snapshot_review()` (or `devtools::test("test-methods-print")`) —
   test fails (current output shows `FPC: fpc fpc2` not per-stage bullets).

2. **Implement** in `R/methods-print.R`. In the `print.survey_taylor` method,
   the FPC display section (lines 178–183):

   Replace:
   ```r
   fpc_var <- x@variables$fpc
   if (!is.null(fpc_var)) {
     cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}}"))
   } else {
     cli::cli_bullets(c("*" = "FPC: not specified"))
   }
   ```

   With:
   ```r
   fpc_var <- x@variables$fpc
   if (!is.null(fpc_var)) {
     if (length(fpc_var) == 1L) {
       cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}}"))
     } else {
       for (j in seq_along(fpc_var)) {
         cli::cli_bullets(c("*" = "FPC (stage {j}): {.field {fpc_var[[j]]}}"))
       }
     }
   } else {
     cli::cli_bullets(c("*" = "FPC: not specified"))
   }
   ```

   Verify that `design_vars_spec` (line 187) still concatenates correctly for
   multi-column `fpc_var` — `c(ids_vars, wts_var, strata_var, fpc_var)` with
   `fpc_var = c("fpc", "fpc2")` produces the correct flat vector. ✓ No change needed.

3. **Run** `devtools::test("test-methods-print")` — snapshot fails (new output
   differs). Run `testthat::snapshot_review()` to inspect the new per-stage output
   and accept it. Re-run — snapshot passes.

4. **Run** `devtools::check()` — 0/0/≤2.

**Acceptance criteria:**
- [ ] Snapshot test confirmed failing before implementation
- [ ] `print(sc)` with 2-stage FPC shows two bullets: `FPC (stage 1): fpc` and `FPC (stage 2): fpc2`
- [ ] `print(sc)` with single-stage FPC shows unchanged format: `FPC: fpc`
- [ ] `print(sc)` with no FPC shows unchanged: `FPC: not specified`
- [ ] Snapshot accepted via `testthat::snapshot_review()` (not `snapshot_accept()`)
- [ ] `devtools::check()` 0/0/≤2
- [ ] Changelog entry written and committed

---

## Quality Gates (All PRs)

Before opening each PR:
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()` all existing tests green, all new tests green
- [ ] `air::format_package()` run; no formatting diffs in committed code
- [ ] Changelog entry committed on the feature branch at `changelog/multi-stage/feature-<branch-name>.md`

Before opening the final PR (PR 7):
- [ ] Line coverage ≥ 98% (`.svy_multistage()` multi-stage path now covered — no `# nocov`)
- [ ] All 11 oracle comparisons from §XI pass (PRs 4 + 5)
- [ ] No inline matrix-building pattern remains in any of the 5 direct call sites
- [ ] `plans/error-messages.md` has rows 88–91 and updated row 13b

---

## Implementation Notes

**Do not** run PRs out of dependency order. The `.build_cluster_matrices()` helper
(PR 2) must be merged before any of the refactor PRs can branch from `develop`.
PRs 3, 4, and 6 can run in parallel once PR 2 merges; PR 7 must wait for PR 3
(needs PR 3's multi-column constructor merged first to write the snapshot test
with a real 2-stage design object).

**Coverage**: The `# nocov` markers removed in PR 4 expose the `.svy_multistage()`
multi-stage recursion path. This path is exercised by the 2-stage FPC oracle tests
in PR 5 (`fpc = c(fpc, fpc2)` → `popmat` is non-NULL → recursion fires). Confirm
coverage picks this up before submitting PR 5.

**Behavioral change**: `.taylor_build_inputs()` now computes `sampsize` from the
full dataset before `na.rm` filtering. This matches `survey` package semantics
(sampsize is a design property, not an outcome property). The PR 4 regression
oracle test against `survey::svymean()` confirms the change is correct.
