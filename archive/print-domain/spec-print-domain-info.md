# Spec: Domain Info Line in Print Methods

**Version:** 1.0
**Date:** 2026-03-03
**Status:** Draft
**Branch pattern:** `feature/print-domain-info`

---

## Document Purpose

This is the authoritative specification for adding a domain membership line
to the header section of all five `print()` methods in `R/methods-print.R`.
When surveytidy's `filter()` has been applied to a survey design object, a
`..surveycore_domain..` column is present in `@data`. This spec defines when,
where, and how that information is surfaced during printing.

All behavior in this spec is authoritative. Implementation must not deviate
without updating this document.

---

## I. Scope

### What this delivers

| Deliverable | Description |
|-------------|-------------|
| `.print_domain_info()` helper | Internal helper; reads `SURVEYCORE_DOMAIN_COL` from `@data` and renders one `cli_text()` line when the column is present |
| Call-site changes (×5) | Insert `.print_domain_info(x)` after the sample size line(s) in each of the five `print()` S7 methods |
| Snapshot updates | Existing snapshot tests updated to include the domain line |
| New snapshot tests | Two new `test_that()` blocks per design type: one verifying the line appears after `filter()`, one verifying it is absent without `filter()` |

### What this does NOT deliver

- Changes to any `summary()` method (out of scope; can be added separately)
- Changes to any analysis function output
- Changes to `@data` structure or `SURVEYCORE_DOMAIN_COL` definition (already defined in `R/utils.R`)
- New exported functions or S7 classes
- Changes to `survey_nonprob` `summary()` method

### Design type support matrix

| Design class | `print()` updated? | `summary()` updated? |
|---|---|---|
| `survey_taylor` | Yes | No |
| `survey_srs` | Yes | No |
| `survey_replicate` | Yes | No |
| `survey_twophase` | Yes | No |
| `survey_nonprob` | Yes | No |

---

## II. Architecture

No new files. One helper added to `R/methods-print.R`; five call sites added
in the same file.

### File change summary

```
R/methods-print.R
  ├── # ── Internal helpers ──
  │     └── [ADD] .print_domain_info(x)   ← new helper, after ~line 68
  ├── S7::method(print, survey_taylor)     ← add call after sample size line
  ├── S7::method(print, survey_srs)        ← add call after sample size line
  ├── S7::method(print, survey_replicate)  ← add call after sample size line
  ├── S7::method(print, survey_twophase)   ← add call after BOTH phase size lines
  └── S7::method(print, survey_nonprob) ← add call after sample size line

tests/testthat/test-methods-print.R       ← new test blocks; snapshot updates
tests/testthat/_snaps/methods-print.md    ← updated by snapshot_review()
```

### `.print_domain_info()` — signature

```r
# @param x Any survey_base subclass.
# @return invisible(NULL)
# @noRd
.print_domain_info <- function(x)
```

---

## III. Helper Specification: `.print_domain_info()`

### Behavior

1. Check whether `SURVEYCORE_DOMAIN_COL` (`"..surveycore_domain.."`) is a
   column name in `x@data`.
2. If **absent**: do nothing (return `invisible(NULL)` silently).
3. If **present**: compute `n_domain` and `n_total` as follows:

   **All design types except `survey_twophase`:**
   - `n_domain <- sum(x@data[[SURVEYCORE_DOMAIN_COL]], na.rm = TRUE)` —
     count of in-domain rows (logical TRUE values in the domain indicator column)
   - `n_total <- nrow(x@data)` — total rows in `@data`
   - Row label: `"rows"`

   **`survey_twophase` exception:** Analysis and variance estimation operate
   on Phase 2 rows that are in-domain (see `analysis-means-helpers.R`
   `.twophase_mean_cell()`). Use Phase 2 counts so the domain line is
   consistent with what the analysis computes:
   - `ph2_mask <- x@data[[x@variables$subset]]`
   - `n_domain <- sum(x@data[[SURVEYCORE_DOMAIN_COL]][ph2_mask], na.rm = TRUE)` —
     Phase 2 rows that are in-domain
   - `n_total <- sum(ph2_mask, na.rm = TRUE)` — Phase 2 sample size
   - Row label: `"Phase 2 rows"`
4. Emit exactly one line via `cli::cli_text()`:

   ```
   Domain: <n_domain> of <n_total> rows
   ```

   using `{.val}` markup for both numbers and `{?s}` pluralization per
   `code-style.md` cli inline markup conventions:

   ```r
   cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} {row_label}")
   ```

   where `row_label` is `"rows"` for all design types except `survey_twophase`,
   which uses `"Phase 2 rows"` (no `{?s}` needed — the label is already explicit).

   For non-twophase designs the format with pluralization is:
   ```r
   cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} row{?s}")
   ```

### Placement in each print method

The line must appear **after** the final sample size line and **before** the
`@groups` check. This ordering is: total rows → domain subset of those rows →
group variables.

**`survey_taylor` header block:**
```
Sample size: <N>
Domain: <n_domain> of <n_total> rows    ← inserted here
Groups: <groups>                         ← existing (conditional)
```

**`survey_srs` header block:**
```
Sample size: <N>
Domain: <n_domain> of <n_total> rows    ← inserted here
Groups: <groups>                         ← existing (conditional)
```

**`survey_replicate` header block:**
```
Sample size: <N>
Domain: <n_domain> of <n_total> rows    ← inserted here
Groups: <groups>                         ← existing (conditional)
```

**`survey_twophase` header block** (two phase-size lines exist):
```
Phase 1 sample size: <n_phase1>
Phase 2 sample size: <n_phase2>                          ← conditional (only if !is.na)
Domain: <n_domain_ph2> of <n_phase2> Phase 2 rows        ← inserted after BOTH phase lines
Groups: <groups>                                          ← existing (conditional)
```

**`survey_nonprob` header block:**
```
Sample size: <N>
Domain: <n_domain> of <n_total> rows    ← inserted here
Groups: <groups>                         ← existing (conditional)
```

### Edge cases

| Scenario | Behavior |
|---|---|
| No `filter()` applied — `SURVEYCORE_DOMAIN_COL` absent | No domain line rendered |
| `filter()` applied — all rows in domain (`n_domain == n_total`) | Line shown: `Domain: 100 of 100 rows` |
| `filter()` applied — zero rows in domain (`n_domain == 0`) | Line shown: `Domain: 0 of 100 rows` |
| Domain indicator column has NAs | `na.rm = TRUE` treats NAs as not-in-domain; count reflects only `TRUE` values |
| 0-row `@data` (`nrow(x@data) == 0`) | Not reachable via public API — constructors validate `nrow >= 1`; no special handling needed |

### Error conditions

None. `.print_domain_info()` is read-only and defensive. It never errors.
All branches are safe by construction (`%in%` + `na.rm = TRUE`).

---

## IV. Verbatim Console Output Examples

### Without domain filter

```
── Survey Design ──────────────────────────────────────────────────────────────
<survey_taylor> (Taylor series linearization)
Sample size: 50
# A tibble: 50 × 7
   psu strata   fpc    wt    y1      y2     y3
   ...
```

*(No domain line appears.)*

### With domain filter applied via surveytidy

```
── Survey Design ──────────────────────────────────────────────────────────────
<survey_taylor> (Taylor series linearization)
Sample size: 50
Domain: 35 of 50 rows
# A tibble: 50 × 8
   psu strata   fpc    wt    y1      y2     y3    ..surveycore_domain..
   ...
```

### With domain filter + groups

```
── Survey Design ──────────────────────────────────────────────────────────────
<survey_taylor> (Taylor series linearization)
Sample size: 50
Domain: 35 of 50 rows
Groups: strata
# A tibble: 50 × 8
   ...
```

---

## V. Testing

### Snapshot update protocol

Existing snapshot tests for each print method will have their snapshots
invalidated by this change only when a domain column is present. The existing
default-output and `full = TRUE` snapshots use `make_taylor_design()` etc.,
which do not inject `SURVEYCORE_DOMAIN_COL` — those snapshots are **unchanged**.

Run after implementing:

```r
devtools::test()             # identify which snapshots changed
testthat::snapshot_review()  # review each diff individually and accept
devtools::test()             # confirm all pass
```

### New test blocks required (×5 design types)

For each of the five design types, add two new `test_that()` blocks. Test data
must inject the domain column directly into `@data` (without requiring
surveytidy to be installed), consistent with the `testing-standards.md` rule
that external packages use `skip_if_not_installed()` at block level.

**Pattern for injecting domain column without surveytidy:**
```r
# Direct @data injection — no surveytidy dependency
d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
```

**Block 1 — domain line appears after filter:**

All five Block 1 tests must set console width before snapshotting, matching
the pattern established in every existing snapshot test in the file:

```r
test_that("print.survey_taylor() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

**Block 2 — domain line absent without filter:**

```r
test_that("print.survey_taylor() shows no domain line without domain column", {
  d <- make_taylor_design()
  # No domain column — no surveytidy filter applied
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
  expect_snapshot(print(d))  # existing snapshot; should pass unchanged
})
```

Block 2 for each design type is covered by the existing default-output
snapshot test. Add the `expect_false()` assertion to the existing block
rather than duplicating it.

**`survey_srs` note:** The existing `make_srs_design()` fixture creates a
`survey_taylor`, not a `survey_srs` (see comment in the test file: "Directly
constructed to bypass SRS dispatch"). For the `survey_srs` Block 1 domain test,
use inline construction matching the existing #18–27 pattern:

```r
test_that("print.survey_srs() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- as_survey_srs(make_survey_data(n = 30, seed = 42), weights = wt)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

Do **not** use `make_srs_design()` for the `survey_srs` domain test — it would
silently test the wrong class.

### `survey_nonprob` — net-new blocks required

There are currently **zero** snapshot tests for `print.survey_nonprob` in
`test-methods-print.R` (the file ends at test #27). For `survey_nonprob`,
the implementer must create **both** a domain-absent baseline block AND a
domain-present Block 1 — these are net-new tests, not updates to existing ones.

Suggested inline fixture (no `make_calibrated_design()` exists):

```r
# survey_nonprob inline fixture
d_cal <- {
  d <- make_taylor_design()
  pop_totals <- c(`(Intercept)` = nrow(d@data))
  survey::calibrate(
    as_svydesign(d),
    formula = ~1,
    population = pop_totals
  ) |> from_svydesign()
}
```

Two blocks required for `survey_nonprob`:

```r
# Block 1 — domain-absent baseline (net-new, not an update)
test_that("print.survey_nonprob() default output", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- d_cal  # inline fixture above
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
  expect_snapshot(print(d))
})

# Block 1 domain — domain line present (snapshot)
test_that("print.survey_nonprob() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- d_cal
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})
```

### NA edge case test

The `na.rm = TRUE` behavior in `.print_domain_info()` is the only non-obvious
computation in the helper. Add one test block that verifies NAs are excluded
from the in-domain count:

```r
test_that(".print_domain_info() excludes NAs from domain count", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  # Inject domain column with NAs — NAs should count as not-in-domain
  mask <- rep(c(TRUE, FALSE, NA), length.out = nrow(d@data))
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- mask
  # Snapshot captures exact count (NAs excluded)
  expect_snapshot(print(d))
})
```

This test can share the `survey_taylor` fixture; it does not need to be
repeated for all five design types.

### Domain + groups ordering test

§IV shows a verbatim example with domain and groups on consecutive lines.
Add one snapshot test verifying this ordering. `@groups` can be set directly
without surveytidy:

```r
test_that(".print_domain_info() domain line appears before groups line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  d@groups <- "strata"
  expect_snapshot(print(d))
})
```

### Fixture name reference

| Design type | Fixture function |
|---|---|
| `survey_taylor` | `make_taylor_design()` |
| `survey_srs` | inline `as_survey_srs()` — see `survey_srs` note above |
| `survey_replicate` | `make_rep_design()` (**not** `make_replicate_design()`) |
| `survey_twophase` | `make_twophase_design()` |
| `survey_nonprob` | inline — see `survey_nonprob` subsection above |

### Test file section additions

Add under a new section comment in `test-methods-print.R`:

```
# ── Domain info line ────────────────────────────────────────────────────────
# 28. print.survey_taylor — domain line present (snapshot)
# 29. print.survey_taylor — domain count excludes NAs (snapshot)
# 30. print.survey_taylor — domain line appears before groups line (snapshot)
# 31. print.survey_srs — domain line present (snapshot)
# 32. print.survey_replicate — domain line present (snapshot)
# 33. print.survey_twophase — domain line present (snapshot)
# 34. print.survey_nonprob — default output (snapshot; net-new baseline)
# 35. print.survey_nonprob — domain line present (snapshot)
```

Block 2 ("no domain line") is validated by reinforcing existing default-output
snapshot tests with an `expect_false()` assertion — no new snapshot block
needed (except for `survey_nonprob`, which requires the net-new baseline
block #33 above).

### Coverage requirement

The helper `.print_domain_info()` has two branches:

| Branch | Covered by |
|---|---|
| Column absent — no output | Block 2 tests (default-output, no filter) |
| Column present — line emitted | Block 1 tests (domain column injected) |

Both branches must reach 100% coverage. No `# nocov` is warranted — both
branches are easily exercised.

---

## VI. Quality Gates

All conditions must be met before this PR is merged:

- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::test()` passes — all snapshots accepted via `snapshot_review()`
- [ ] New domain-present snapshot tests exist for all five design types
- [ ] Existing default-output snapshots are **unchanged** (domain column not injected in existing fixtures)
- [ ] `.print_domain_info()` has 100% line coverage
- [ ] No change to any `summary()` method
- [ ] `SURVEYCORE_DOMAIN_COL` referenced via the exported constant, not the literal string `"..surveycore_domain.."`

---

## VII. Integration Contracts

### surveytidy → surveycore

`surveytidy`'s `filter.survey_base()` sets `SURVEYCORE_DOMAIN_COL` in
`@data` as a logical vector (`TRUE` = in-domain, `FALSE` or `NA` = excluded).
The column name is the exported constant `SURVEYCORE_DOMAIN_COL` from `R/utils.R`.

This spec does not change the surveytidy contract. surveycore's print methods
are consumers of the column — they must not write to or remove it.

### `@data` invariant

This change must not alter `@data`. `.print_domain_info()` is strictly
read-only. Domain column is never removed from, added to, or modified in
`@data` by the print path.
