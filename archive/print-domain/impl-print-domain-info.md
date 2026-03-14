# Implementation Plan: Domain Info Line in Print Methods

**Spec:** `plans/spec-print-domain-info.md`
**Decisions:** `plans/decisions-print-domain-info.md`
**Date:** 2026-03-03

---

## Overview

This plan delivers the `.print_domain_info()` helper and its five call sites in
`R/methods-print.R`, plus a new suite of snapshot tests in
`tests/testthat/test-methods-print.R`. No new files are created; no exported
functions are added. When a `..surveycore_domain..` column is present in `@data`
(placed there by surveytidy's `filter()`), all five `print()` methods surface a
`Domain: <n_domain> of <n_total> row(s)` line immediately after the sample size
line and before the `Groups:` line.

---

## PR Map

- [x] PR 1: `feature/print-domain-info` — add `.print_domain_info()` helper, five call sites, and snapshot tests

---

## PR 1: Domain info line in print methods

**Branch:** `feature/print-domain-info`
**Depends on:** none

### Files (in TDD order — tests first)

- `tests/testthat/test-methods-print.R` — add test blocks 28–36 plus
  `expect_false()` assertions in existing default-output blocks
- `R/methods-print.R` — add `.print_domain_info()` helper and insert call
  after sample size in each of the five `print()` methods
- `changelog/feature-print-domain-info.md` — changelog entry for this PR

### Acceptance criteria

- [ ] All new snapshot tests confirmed **absent** (no snapshot file entry) before
  implementation began — the helper does not exist yet, so `expect_snapshot()`
  on a domain-present design would produce an error, not a snapshot
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync (no doc changes
  expected, but verify)
- [ ] `devtools::test()` passes — all new snapshot entries accepted via
  `testthat::snapshot_review()`
- [ ] Domain-present snapshot tests exist for all five design types (tests
  28, 31, 32, 33, 35) and zero-domain edge case test 36 passes
- [ ] Existing default-output snapshots (tests 1, 7, 10, 18) are unchanged —
  none inject `SURVEYCORE_DOMAIN_COL`, so those snapshots must not change
- [ ] `.print_domain_info()` has 100% line coverage: column-absent branch
  covered by reinforced Block 2 tests; column-present branch covered by Block 1
  tests
- [ ] No change to any `summary()` method
- [ ] Changelog entry committed in `changelog/feature-print-domain-info.md` on this branch

---

### Implementation notes

#### `.print_domain_info()` placement in `R/methods-print.R`

Insert after the closing `}` of `.print_weight_distribution()` (~line 68),
before the `# ── print.survey_taylor` section comment. The helper is
file-scoped (used only in `methods-print.R`), so inline placement per
`code-style.md` §4.

```r
# @param x Any survey_base subclass.
# @return invisible(NULL)
# @noRd
.print_domain_info <- function(x) {
  if (!SURVEYCORE_DOMAIN_COL %in% names(x@data)) return(invisible(NULL))

  if (S7::S7_inherits(x, survey_twophase)) {
    ph2_mask <- x@data[[x@variables$subset]]
    n_domain <- sum(x@data[[SURVEYCORE_DOMAIN_COL]][ph2_mask], na.rm = TRUE)
    n_total  <- sum(ph2_mask, na.rm = TRUE)
    cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} Phase 2 rows")
  } else {
    n_domain <- sum(x@data[[SURVEYCORE_DOMAIN_COL]], na.rm = TRUE)
    n_total  <- nrow(x@data)
    cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} row{?s}")
  }
  invisible(NULL)
}
```

Note on cli pluralization: `{?s}` must appear as a **literal token** in the
`cli_text()` format string — it is NOT processed when stored inside a variable
and then interpolated with `{var}`. The two-branch structure above is required:
the twophase branch emits "Phase 2 rows" (always plural, no `{?s}` needed);
the non-twophase branch uses literal `row{?s}` which cli pluralizes based on
the preceding `{.val {n_total}}` count.

#### Call site insertion in each print method

The call `.print_domain_info(x)` must be inserted **after** the final sample
size `cli_text()` line and **before** the `if (length(x@groups) > 0L)` block
in each method. The five insertions are:

| Method | After this line | Before this block |
|---|---|---|
| `survey_taylor` | `cli_text("Sample size: ...")` (line ~104) | `if (length(x@groups) > 0L)` (line ~106) |
| `survey_srs` | `cli_text("Sample size: ...")` (line ~231) | `if (length(x@groups) > 0L)` (line ~233) |
| `survey_replicate` | `cli_text("Sample size: ...")` (line ~348) | `if (length(x@groups) > 0L)` (line ~350) |
| `survey_twophase` | `if (!is.na(n_phase2)) { ... }` block (line ~455) | `if (length(x@groups) > 0L)` (line ~458) |
| `survey_nonprob` | `cli_text("Sample size: ...")` (line ~564) | `if (length(x@groups) > 0L)` (line ~566) |

For `survey_twophase`, the call must come after the closing `}` of the
`if (!is.na(n_phase2))` block (both phase size lines printed), not just after
the Phase 1 line.

#### Test block structure

Add a new section comment at the end of `test-methods-print.R`:

```r
# ── Domain info line ────────────────────────────────────────────────────────
# 28. print.survey_taylor — domain line present (snapshot)
# 29. print.survey_taylor — domain count excludes NAs (snapshot)
# 30. print.survey_taylor — domain line appears before groups line (snapshot)
# 31. print.survey_srs — domain line present (snapshot)
# 32. print.survey_replicate — domain line present (snapshot)
# 33. print.survey_twophase — domain line present (snapshot)
# 34. print.survey_nonprob — default output (snapshot; net-new baseline)
# 35. print.survey_nonprob — domain line present (snapshot)
# 36. print.survey_taylor — zero rows in domain (snapshot)
```

**Test 28 — survey_taylor domain present:**
```r
test_that("print.survey_taylor() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

**Test 29 — NA exclusion:**
```r
test_that("print.survey_taylor() domain count excludes NAs", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  mask <- rep(c(TRUE, FALSE, NA), length.out = nrow(d@data))
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- mask
  expect_snapshot(print(d))
})
```

**Test 30 — domain before groups:**
```r
test_that("print.survey_taylor() domain line appears before groups line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  d@groups <- "strata"
  expect_snapshot(print(d))
})
```

**Test 31 — survey_srs domain present (inline construction — no `make_srs_design()`):**
```r
test_that("print.survey_srs() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- as_survey_srs(
    make_survey_data(n = 30L, n_psu = 6L, n_strata = 2L, seed = 42L),
    weights = wt
  )
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

`make_srs_design()` creates a `survey_taylor` (see existing comment in fixture
block) — do NOT use it for `survey_srs` domain tests. When calling
`make_survey_data()` for SRS fixtures, always specify `n_psu` and `n_strata`
explicitly — the defaults (`n_psu = 50L`, `n_strata = 5L`) will crash when
`n < n_psu`.

**Test 32 — survey_replicate domain present (`make_rep_design()`):**
```r
test_that("print.survey_replicate() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_rep_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

**Test 33 — survey_twophase domain present (`make_twophase_design()`):**
```r
test_that("print.survey_twophase() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_twophase_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

**Tests 34 & 35 — survey_nonprob (net-new; no existing baseline):**

A `survey_nonprob` inline fixture must be created. There is no
`make_calibrated_design()` helper in the test file. Use inline construction
from the spec's §V pattern. Note: `survey` package is required; use
`skip_if_not_installed("survey")` at block level.

```r
test_that("print.survey_nonprob() default output", {
  skip_if_not_installed("survey")
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- {
    base <- make_taylor_design()
    pop_totals <- c(`(Intercept)` = nrow(base@data))
    survey::calibrate(
      as_svydesign(base),
      formula = ~1,
      population = pop_totals
    ) |> from_svydesign()
  }
  test_invariants(d)
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
  expect_snapshot(print(d))
})

test_that("print.survey_nonprob() shows domain line when domain column is present", {
  skip_if_not_installed("survey")
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- {
    base <- make_taylor_design()
    pop_totals <- c(`(Intercept)` = nrow(base@data))
    survey::calibrate(
      as_svydesign(base),
      formula = ~1,
      population = pop_totals
    ) |> from_svydesign()
  }
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

**Test 36 — zero rows in domain:**
```r
test_that("print.survey_taylor() shows domain line when zero rows are in domain", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- FALSE
  expect_snapshot(print(d))
})
```

This test verifies: (a) the domain line still renders when `n_domain == 0`
(no early-return on zero count), and (b) correct pluralization of "rows" for
`n_total > 1`. It is listed in spec §III edge cases.

#### Block 2 reinforcement (existing tests — no new snapshot)

Add `expect_false()` assertions to existing default-output test blocks to
explicitly document the no-domain-column invariant:

- Test 1 (`print.survey_taylor default output`): add
  `expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))` before
  `expect_snapshot()`
- Test 7 (`print.survey_replicate default output`): same pattern
- Test 10 (`print.survey_twophase default output`): same pattern
- Test 18 (`print.survey_srs default output`): same pattern

These assertions confirm the existing snapshots are domain-absent. They do NOT
invalidate the existing snapshot content (domain column not present → no domain
line rendered).

#### Snapshot workflow

After implementing:

```r
devtools::test()             # new tests create new snapshot entries; confirm
testthat::snapshot_review()  # review each diff; accept new entries
devtools::test()             # confirm all pass
```

The existing snapshots (tests 1, 7, 10, 18) must not change — verify this
during `snapshot_review()`.

#### Fixture reference

| Design type | Fixture |
|---|---|
| `survey_taylor` | `make_taylor_design()` |
| `survey_srs` | inline `as_survey_srs(make_survey_data(n=30L, n_psu=6L, n_strata=2L, seed=42L), weights=wt)` — NOT `make_srs_design()` |
| `survey_replicate` | `make_rep_design()` — NOT `make_replicate_design()` |
| `survey_twophase` | `make_twophase_design()` |
| `survey_nonprob` | inline — see tests 34 & 35 above |
