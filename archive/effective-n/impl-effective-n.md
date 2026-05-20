# Implementation Plan — `get_effective_n()`

**Spec:** `plans/spec-effective-n.md` (v0.3)
**Plan version:** 1.0
**Date:** 2026-05-04
**Target branch:** `develop`

---

## Overview

This plan delivers `get_effective_n()`, a new exported analysis function that
computes effective sample size using either the Kish (1965) weight-only
approximation or the full design-effect-based formula. It follows the same
structural pattern as all other `get_*()` analysis functions in the package
— one new source file, one test file, and minor additions to `analysis-helpers.R`.
All shared helpers are reused as-is; the only new internal computation is
`.kish_effective_n()`.

---

## PR Map

- [x] PR 1: `feature/effective-n` — implement `get_effective_n()` with both
  methods, print method, tests, and docs

---

## Implementor Notes (read before writing any code)

### EN-1 error class discrepancy
The spec's error table lists `surveycore_error_not_survey_object` for EN-1.
The existing `.check_unsupported_class()` helper (in `R/analysis-helpers.R:805`)
throws **`surveycore_error_unsupported_class`** — not `not_survey_object`.
Do not invent a new class. Call `.check_unsupported_class(design, "get_effective_n")`
and update `plans/error-messages.md` row EN-1 to record the actual class
`surveycore_error_unsupported_class`. This class is already exercised in tests
for other `get_*()` functions; the snapshot test for EN-1 in this file verifies
the message text is unchanged.

### Print method location
The spec says `methods-print.R`. The established codebase pattern for result-class
S3 print methods is co-location in the analysis source file (see
`analysis-t-test.R:497`, `glm-anova.R:1048`). Define `print.survey_effective_n()`
at the bottom of `R/analysis-effective-n.R`, not in `methods-print.R`.

### META_KEYS location
The spec mentions `analysis-meta.R` for the `EFFECTIVE_N_META_KEYS` constant.
`analysis-meta.R` contains no `*_META_KEYS` constants — those all live in
`analysis-helpers.R` (line 105+). Add `EFFECTIVE_N_META_KEYS` to
`R/analysis-helpers.R` alongside the other constants.

### Validation of `decimals` and `na.rm`
`get_effective_n()` has no `variance`, `conf_level`, or `name_style` arguments,
so the full `.validate_shared_args()` signature is awkward. Pass dummy valid
values:
```r
.validate_shared_args(NULL, 0.95, "surveycore", decimals = decimals, na.rm = na.rm)
```
This validates `decimals` and `na.rm` without triggering errors on the
placeholder positional args. Confirm this pattern by running the relevant
snapshot tests.

### `x` NSE argument for `method = "kish"`
When `method = "kish"` and `x` is supplied, issue `rlang::inform()` (not
`cli_warn()`) because the call is still valid. The inform has no `class=`
requirement — this is not a warning.

### `.dispatch_over_collection()` and `method = "kish"`
For `method = "kish"`, `x` is `NULL` and `.if_missing_var` is irrelevant (no
variable to be missing). The collection dispatch works as-is: each survey is
passed to `get_effective_n()` with all arguments forwarded via `...`. No
special handling is needed.

### `get_means()` call for `method = "deff"`
The implementation inlines the call using `rlang::inject()` + `!!rlang::sym()`.
This is the established codebase pattern for forwarding an already-resolved NSE
argument (see `analysis-t-test.R:756–769` where `get_pairwise()` calls
`get_t_test()` the same way):
```r
means_result <- rlang::inject(get_means(
  design,
  !!rlang::sym(x_name),
  group = !!group_quo,
  variance = "deff",
  na.rm = na.rm,
  min_cell_n = min_cell_n,
  ...
))
```
Where `x_name` is the character name already resolved earlier via
`rlang::as_name(rlang::ensym(x))`.

### `n_eff = n / deff` guard
Use `ifelse(is.finite(deff) & deff > 0, n / deff, NA_real_)` (vectorized over group rows).
The two-condition guard is required: `is.finite(0)` is `TRUE` in R, so without `deff > 0`
a zero deff would produce `Inf` rather than `NA_real_`; negative deff would produce a
negative `n_eff`. This covers Inf, NaN, NA, 0, and negative deff.

---

## PR 1: `feature/effective-n`

**Branch:** `feature/effective-n`
**Depends on:** none

**Files (TDD order):**
- `tests/testthat/test-effective-n.R` — full test suite (written first, all red)
- `R/analysis-helpers.R` — add `EFFECTIVE_N_META_KEYS` constant
- `R/analysis-effective-n.R` — new; `.kish_effective_n()`, `get_effective_n()`,
  `print.survey_effective_n()`
- `plans/error-messages.md` — add EN-1 through EN-4 rows
- `NEWS.md` — add entry for `get_effective_n()`
- `DESCRIPTION` — version bump (0.8.3 → 0.8.4 or `.9000` increment as appropriate)
- `changelog/feature-effective-n.md` — new; changelog entry in established format

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] Kish happy paths pass: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`, SRS (uniform weights → `n_eff == n`,
  `deff_kish == 1.0`)
- [ ] DEFF happy paths pass: all five design types + `survey_collection`
- [ ] Numerical oracle: Kish matches manual formula (tolerance 1e-10); DEFF
  matches `get_means(variance = "deff")` (tolerance 1e-10); DEFF matches
  `survey::svymean(deff=TRUE)` (tolerance 1e-10)
- [ ] Error paths: EN-2 and EN-3 use dual pattern (class= + snapshot); EN-1
  snapshot verifies `surveycore_error_unsupported_class` message unchanged
- [ ] Edge cases: `n == 0` domain, `deff` non-finite, uniform weights, kish +
  x supplied, `decimals` applied to `n_eff`/`deff` but not `n`, `na.rm = FALSE`
- [ ] `survey_collection` dispatch: both methods, including `.if_missing_var = "skip"`
  for DEFF
- [ ] Result class: inherits `c("survey_effective_n", "survey_result", "tbl_df", "tbl", "data.frame")`
- [ ] `meta(result)$method` is `"kish"` or `"deff"`; `meta(result)$x` is `NULL`
  for kish, variable meta list for deff
- [ ] Print snapshots captured for both methods (grouped and ungrouped)
- [ ] `plans/error-messages.md` updated with EN-1 through EN-4
- [ ] Line coverage on `R/analysis-effective-n.R` ≥ 98% (verified via `covr::file_coverage()` or `devtools::test_coverage_file()`)

---

## Detailed Task Steps

### Step 1: Write the failing test file

Create `tests/testthat/test-effective-n.R`. Structure follows spec §IV exactly.
Write all sections before running any tests. Use `make_survey_data()` from
`helper-test-data.R` for unit tests; use `nhanes_2017` only for numerical
oracle blocks.

Sections (flat `test_that()` blocks — no `describe()`):

**Section 1 — Kish happy paths**
- `survey_taylor`, no grouping: verify `n_eff`, `deff_kish` columns present;
  check formula manually with `weights(d)` for a few rows
- `survey_taylor`, with `group`: one row per level, all rows have finite `n_eff`
- `survey_replicate`, no grouping: produces finite `n_eff`
- `survey_twophase`, no grouping: produces finite `n_eff`
- `survey_nonprob`, no grouping: produces finite `n_eff`
- SRS design (uniform weights): `n_eff == n` exactly, `deff_kish == 1.0`

**Section 2 — DEFF happy paths**
- `survey_taylor`, no grouping: `n`, `n_eff`, `deff` columns present; no
  `deff_kish`
- `survey_taylor`, with group: one row per level
- `survey_replicate`, no grouping: finite `deff`
- `survey_twophase`, no grouping: finite `deff`
- `survey_nonprob`, no grouping: finite `deff`
- `survey_collection`, no grouping: `.id` column present
- Numerical match: `deff` from `get_effective_n()` matches `deff` from
  `get_means(variance = "deff")` (tolerance 1e-10)
- Parametrized check (all five design types return finite `deff`)

**Section 3 — Error paths (dual pattern for each)**
- EN-1: `get_effective_n(list(x = 1))` — class= `surveycore_error_unsupported_class`
  + snapshot
- EN-2: `get_effective_n(d, method = "deff")` (x = NULL) — class= +
  snapshot
- EN-3: `get_effective_n(d, c(ridageyr, bmxbmi), method = "deff")` — class=
  + snapshot
- EN-4: `get_effective_n(d, method = "ols")` — base-R `match.arg()` error;
  `expect_error()` only (no class=, no snapshot)

**Section 4 — Edge cases**
- `n == 0` domain after `na.rm`: `n_eff = NA`, `deff = NA`
- `deff` non-finite (method = "deff"): `n_eff = NA` for Inf, NaN, negative
- Uniform weights (kish): `n_eff == n` exactly, `deff_kish == 1.0`
- `method = "kish"`, x supplied → `rlang::inform()` fires, result identical to
  kish without x
- `decimals` applied to `n_eff` and deff-family columns, NOT to `n`
- `na.rm = FALSE` for Kish: NA weight → `n_eff = NA`, `deff_kish = NA`; NA
  group value treated as distinct level (per `.apply_domain()` semantics)

**Section 5 — `survey_collection` dispatch**
- `method = "kish"`: each survey's `n_eff` computed independently; `.id` column
  identifies surveys
- `method = "deff"`: collection dispatches; `.if_missing_var = "skip"` drops
  surveys missing `x`

**Section 6 — Result class and structure**
- Class inheritance chain correct
- `meta(result)$method == "kish"` and `meta(result)$x == NULL` for kish
- `meta(result)$method == "deff"` and `meta(result)$x` is named list for deff
- Print snapshots: kish ungrouped, kish grouped, deff ungrouped, deff grouped

**Numerical oracle blocks** (each inside `test_that()` with
`skip_if_not_installed("survey")` inside):
```r
# Kish oracle
d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                  strata = sdmvstra, nest = TRUE)
result <- get_effective_n(d_sc)
w <- weights(d_sc)
expected_n_eff <- sum(w)^2 / sum(w^2)
expect_equal(result$n_eff, expected_n_eff, tolerance = 1e-10)

# DEFF oracle (vs get_means)
result_deff <- get_effective_n(d_sc, ridageyr, method = "deff")
means_result <- get_means(d_sc, ridageyr, variance = "deff")
expect_equal(result_deff$deff, means_result$deff, tolerance = 1e-10)

# DEFF oracle (vs survey::svymean)
d_sv <- survey::svydesign(ids = ~sdmvpsu, weights = ~wtmec2yr,
                           strata = ~sdmvstra, data = nhanes_2017, nest = TRUE)
sv_est <- survey::svymean(~ridageyr, d_sv, deff = TRUE, na.rm = TRUE)
expect_equal(result_deff$deff, survey::deff(sv_est)[["ridageyr"]],
             tolerance = 1e-10)
```

### Step 2: Run tests and confirm all new tests fail

```r
devtools::test(filter = "effective-n")
```

Verify the error is "could not find function `get_effective_n`" or similar, not
a test logic error. All blocks should fail red.

### Step 3: Add `EFFECTIVE_N_META_KEYS` to `R/analysis-helpers.R`

After the `T_TEST_META_KEYS` and `PAIRWISE_META_KEYS` lines (around line 115),
add:
```r
EFFECTIVE_N_META_KEYS <- c(FAMILY_META_KEYS, "method")
```
The meta shape uses `group` (standard), `x` (NULL for kish), and `method`
(extra field distinguishing the two formula variants).

### Step 4: Write `R/analysis-effective-n.R`

Structure of the file:

```
# R/analysis-effective-n.R
# Effective sample size for survey designs.
# Exported function: get_effective_n()

# ── .kish_effective_n() [internal] ───────────────────────────────────────────

# ── get_effective_n() ─────────────────────────────────────────────────────────

# ── print.survey_effective_n() ────────────────────────────────────────────────
```

#### `.kish_effective_n(weights)`

```r
.kish_effective_n <- function(weights) {
  if (length(weights) == 0L) return(NA_real_)
  sum(weights)^2 / sum(weights^2)
}
```

No `@noRd` needed since it has no roxygen block; just a comment header.

#### `get_effective_n()` — implementation skeleton

```
1. Collection dispatch (same pattern as get_means() lines 106-116)
2. .check_unsupported_class(design, "get_effective_n")
3. method <- match.arg(method)
4. .validate_shared_args(NULL, 0.95, "surveycore", decimals = decimals,
   na.rm = na.rm)
5. If method = "deff": validate x not NULL (EN-2), resolve x tidy-select,
   check length == 1 (EN-3), call .precheck_vars_present()
6. If method = "kish" and !is.null(x): rlang::inform("x is ignored when
   method = 'kish'")
7. resolve groups, apply domain
8. Branch on method:
   - "kish": loop over group combos, extract weights, call .kish_effective_n(),
     fire surveycore_warning_small_cell when n < min_cell_n
   - "deff": call get_means() with variance = "deff", extract n and deff,
     compute n_eff = ifelse(is.finite(deff) & deff > 0, n / deff, NA_real_)
9. Assemble output tibble using .make_result_tibble() with EFFECTIVE_N_META_KEYS
10. .apply_decimals() on n_eff and deff columns only
11. Return result
```

**Column assembly for output tibble:**
- `method = "kish"`: `col_vecs = list(n = acc_n, n_eff = acc_n_eff, deff_kish = acc_n / acc_n_eff)`
- `method = "deff"`: `col_vecs = list(n = extracted_n, n_eff = computed_n_eff, deff = extracted_deff)`

Note: `n` should be `as.integer(n)` to match the type contract.

**Weight extraction for Kish:**
```r
# Get full analysis weights from the design
all_weights <- weights(design)
# Domain mask is already in domain_mask
# For each group combo, build the in-domain + in-group row mask,
# then subset all_weights
```
For `survey_replicate`: `weights(design)` returns the main (analysis) weights.
For `survey_twophase`: `weights(design)` returns the combined final weights.

**`na.rm` handling for Kish:**
When `na.rm = TRUE`: before computing the Kish formula for a domain, drop
any observations where the weight is NA. `n` = number of non-NA weights.
When `na.rm = FALSE`: include all weights; NA propagates naturally.

#### `print.survey_effective_n()`

```r
print.survey_effective_n <- function(x, ...) {
  m <- attr(x, ".meta")
  cls <- class(x)[1L]
  dims <- paste(nrow(x), "×", ncol(x))
  method_str <- paste("method:", m$method)
  x_str <- if (!is.null(m$x)) paste(" x:", names(m$x)[1L]) else ""
  cat(sprintf("# A <%s> [%s]  %s%s\n", cls, dims, method_str, x_str))
  NextMethod()
  invisible(x)
}
```

Register as `@method print survey_effective_n` with `@export`.

#### Roxygen for `get_effective_n()`

- `@family analysis`
- `@export`
- `@examples` using `nhanes_2017` (both methods, basic call)
- `@return` describing the `survey_effective_n` tibble with all columns
- `@seealso` not required (not a constructor)
- All `@param` docs for each argument

### Step 5: Run tests and confirm green

```r
devtools::test(filter = "effective-n")
```

All sections should pass. Fix any failures before proceeding.

### Step 6: Update `plans/error-messages.md`

Add rows EN-1 through EN-4 to the error table. Use `surveycore_error_unsupported_class`
for EN-1 (not `surveycore_error_not_survey_object` — see Implementor Notes above).

### Step 7: Run `devtools::document()`

```r
devtools::document()
```

Verify `NAMESPACE` includes `export(get_effective_n)` and
`S3method(print, survey_effective_n)`. Verify `man/get_effective_n.Rd` is
generated.

### Step 8: Run `devtools::check()` and fix any issues

```r
devtools::check()
```

Target: 0 errors, 0 warnings, ≤2 notes (the pre-approved NSE and CRAN notes).

### Step 9: Update `NEWS.md` and bump version in `DESCRIPTION`

Add an entry under the current dev version heading in `NEWS.md`:
```
* `get_effective_n()` computes the effective sample size of a survey design
  using the Kish (1965) weight approximation (`method = "kish"`) or the full
  design effect for a specified variable (`method = "deff"`). Supports all
  design types and `survey_collection`.
```

Bump `DESCRIPTION` version from `0.8.3` to `0.8.4.9000` (new feature on
`develop`).

### Step 10: Commit and open PR

```bash
git add R/analysis-effective-n.R R/analysis-helpers.R \
        tests/testthat/test-effective-n.R \
        plans/error-messages.md \
        NEWS.md DESCRIPTION NAMESPACE man/get_effective_n.Rd \
        changelog/feature-effective-n.md
```

Commit message:
```
feat(analysis): add get_effective_n() for Kish and DEFF effective N (#NNN)
```

Target: `develop` branch.

---

## Open Questions / Decisions to Log

Before implementation begins, confirm or decide:

1. ~~**`x` forwarding in DEFF branch**~~ **RESOLVED** — Use
   `rlang::inject(get_means(design, !!rlang::sym(x_name), ...))`. This matches
   `analysis-t-test.R:756–769` (`get_pairwise()` → `get_t_test()`). The
   Implementor Notes section has been updated with the exact calling pattern.

2. **`min_cell_n` type validation**: No explicit validation of `min_cell_n` type
   exists in other `get_*()` functions — the arg is used directly in a
   comparison. Follow the same convention (no explicit validation; unexpected
   types produce informative R errors naturally).

3. **`decimals` application for DEFF method**: `.apply_decimals()` rounds
   all numeric columns in the result. Since for DEFF the numeric columns are
   `n_eff` and `deff`, and `n` is integer, confirm `.apply_decimals()` skips
   integer columns automatically before relying on it.
