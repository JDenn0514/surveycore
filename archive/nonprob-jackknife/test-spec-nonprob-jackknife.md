# Test-spec — nonprob-jackknife

---

## Reference oracle

- `survey` package >= 4.2 — `survey::svydesign()` + `survey::svyrep.design()`
  for numerical parity checks
- `survey::svymean()`, `survey::svytotal()`, `survey::svyvar()` — oracle
  estimators for jackknife SE comparison

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| Inline synthetic (constructed per test) | Constructor happy paths, error paths, edge cases |
| `make_survey_data(seed = N)` via `helper-test-data.R` | Multi-row realistic data for print and analysis dispatch tests |
| `survey::svrepdesign(type = "JK1", ...)` with matching data | Numerical parity: jackknife SE for means and totals |

For numerical parity tests: construct a small data frame with known values,
build a `survey_nonprob` JK1 design AND a `survey::svrepdesign` JK1 design
from the same data and weights, then compare `get_means()` SE against
`survey::svymean()` SE.

---

## Per-function test plan

### `as_survey_nonprob()` — constructor

#### Happy paths

- **JK1 via explicit type**: supply a data frame with a weight column and 4
  replicate columns, call with `type = "JK1"`. Assert:
  - `test_invariants(design)` passes (first assertion).
  - `S7::S7_inherits(design, survey_nonprob)` is TRUE.
  - `design@variables$type == "JK1"`.
  - `design@variables$scale == (4 - 1) / 4` (i.e., `0.75`).
  - `design@variables$rscales` equals `rep(1, 4)`.
  - `design@variables$mse == TRUE`.
  - `length(design@variables$repweights) == 4`.

- **jackknife alias normalizes to JK1**: call with `type = "jackknife"` and 3
  replicate columns. Assert:
  - `test_invariants(design)` passes.
  - `design@variables$type == "JK1"` (not `"jackknife"`).
  - `design@variables$scale == (3 - 1) / 3`.

- **JK2 with explicit rscales**: supply 4 replicate columns, explicit
  `rscales = c(0.75, 0.75, 0.75, 0.75)`, `type = "JK2"`. Assert:
  - `test_invariants(design)` passes.
  - `design@variables$type == "JK2"`.
  - `design@variables$scale == 1` (JK2 default scale).
  - `design@variables$rscales` equals the supplied vector.

- **JKn with explicit rscales**: same as JK2 but `type = "JKn"`. Assert:
  - `design@variables$type == "JKn"`.

- **Bootstrap unchanged**: call with `type = "bootstrap"` and 5 replicate
  columns. Assert:
  - `design@variables$type == "bootstrap"`.
  - `design@variables$scale == 1 / 5`.
  - `design@variables$rscales` equals `rep(1, 5)`.

- **Explicit scale overrides default**: call JK1 with `scale = 0.5`. Assert
  `design@variables$scale == 0.5`.

- **Explicit rscales accepted for JK1**: call JK1 with non-uniform
  `rscales = c(1, 1, 0.5, 1)`. Assert `design@variables$rscales` equals
  the supplied vector.

- **JK1 with calibration provenance (R field only)**: supply `calibration =
  list(R = 4L)` with 4 replicate columns and `type = "JK1"`. Assert no error.
  (The bootstrap field is absent; should not trigger `provenance_not_bootstrap`.)

- **JK1 with calibration having bootstrap = FALSE**: supply
  `calibration = list(bootstrap = FALSE, R = 4L)` with 4 JK1 replicate
  columns. Assert no error. (bootstrap flag only checked for bootstrap type.)

- **JK1 with calibration having bootstrap = TRUE**: supply
  `calibration = list(bootstrap = TRUE, R = 4L)` with 4 JK1 replicate
  columns. Assert no error. The `bootstrap = TRUE` field is ignored for
  jackknife types — the check is type-gated, so `TRUE` or `FALSE` both
  produce no error when `type != "bootstrap"`.

- **mse = FALSE accepted**: call JK1 with `mse = FALSE`. Assert
  `design@variables$mse == FALSE`.

- **repweights = NULL ignores type**: call with `repweights = NULL` and
  `type = "JK1"`. Assert no error and all four rep-related variables are NULL:
  - `design@variables$type == NULL`
  - `design@variables$scale == NULL`
  - `design@variables$rscales == NULL`
  - `design@variables$mse == NULL`

#### Error paths

Each error test applies the dual pattern:
1. `expect_error(..., class = "<class_name>")` — typed class check
2. `expect_snapshot(error = TRUE, ...)` — golden message text

- **`surveycore_error_type_unsupported_for_nonprob`** (NB-1): call with
  `type = "BRR"` and 3 replicate columns. Expect this error class and a
  matching snapshot.

- **`surveycore_error_type_unsupported_for_nonprob`** — `type = "Fay"`: same
  dual pattern. Verify the same class fires for a different unsupported type.
  (Snapshot is separate to pin the actual value interpolation.)

- **`surveycore_error_type_unsupported_for_nonprob`** — `type = "bootstrap2"`:
  verify a near-miss misspelling also fires this error (not some other class).

- **`surveycore_error_type_unsupported_for_nonprob`** — `type = c("JK1", "JK2")`:
  vector-valued `type` must raise the same error. Dual pattern.

- **`surveycore_error_type_unsupported_for_nonprob`** — `type = NA_character_`:
  NA type raises the same error class. Snapshot will display `{.val NA}`. Dual
  pattern.

- **`surveycore_error_type_unsupported_for_nonprob`** — `type = "jk1"`:
  verify that lowercase variants (case-sensitivity) raise this error, not a
  type normalization. Dual pattern.

- **`surveycore_error_stratified_jk_rscales_unset`** (NB-9) — `type = "JK2"` with
  `rscales = NULL`: dual pattern.

- **`surveycore_error_stratified_jk_rscales_unset`** — `type = "JKn"` with `rscales = NULL`:
  dual pattern. (Separate snapshot to pin `{type}` interpolation.)

- **`surveycore_error_repweights_single`** (NB-3) with jackknife type: call
  with `type = "JK1"` and exactly 1 replicate column. Verify:
  - class is `surveycore_error_repweights_single`.
  - Snapshot captures the updated message "Replicate variance requires >= 2
    replicates" (not "Bootstrap variance requires >= 2 replicates").

- **`surveycore_error_repweights_single`** with bootstrap type (regression
  guard): call with `type = "bootstrap"` and exactly 1 replicate column.
  Same class, same updated message text. Ensures the message change is
  type-agnostic.

- **`surveycore_error_repweights_empty`** (row 16): call with `repweights =
  starts_with("jk")` when no columns match. Dual pattern.

- **`surveycore_error_scale_negative`** (NB-10): call JK1 with `scale = -0.5`
  and 4 replicate columns. Dual pattern. (Also test `scale = -1e-10` — very
  small negatives are still rejected.)

- **`surveycore_error_rscales_length`** (row 17): call JK1 with
  `rscales = c(1, 1)` and 4 replicate columns. Dual pattern.

- **`surveycore_error_rscales_na`** (NB-8): call JK1 with
  `rscales = c(1, NA, 1, 1)` and 4 replicate columns. Dual pattern.

- **`surveycore_error_provenance_not_bootstrap`** (NB-6): call with
  `type = "bootstrap"` and `calibration = list(bootstrap = FALSE)`.
  Dual pattern. (Regression guard — ensure this error still fires for bootstrap.)

- **`surveycore_error_provenance_R_mismatch`** (NB-7): call with `type = "JK1"`,
  3 replicate columns, and `calibration = list(R = 5L)`. Dual pattern.
  (Ensures R-count check applies to jackknife too.)

- **`surveycore_error_reference_sample_nonprob`** (NB-5): call with JK1 and
  `reference_sample = data.frame(x = 1)`. Dual pattern.

#### Edge cases

- **zero-row data raises `surveycore_error_empty_data`** (dual pattern):
  ```r
  empty_df <- data.frame(wt = numeric(0))
  expect_error(as_survey_nonprob(empty_df, weights = wt),
               class = "surveycore_error_empty_data")
  expect_snapshot(error = TRUE, as_survey_nonprob(empty_df, weights = wt))
  ```

- **single-row data constructs valid object**:
  ```r
  single_df <- data.frame(y = 1, wt = 1, j1 = 0.5, j2 = 0.5)
  d1 <- as_survey_nonprob(single_df, weights = wt,
                          repweights = starts_with("j"), type = "JK1")
  test_invariants(d1)
  expect_equal(nrow(d1@data), 1L)
  ```

- **`type = 1` (numeric) raises `surveycore_error_type_unsupported_for_nonprob`**:
  ```r
  expect_error(
    as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"), type = 1),
    class = "surveycore_error_type_unsupported_for_nonprob"
  )
  ```

- **JK1 with one zero-valued rscale entry accepted**:
  ```r
  rsc <- c(1, 0, 1, 1)
  d <- as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"),
                         type = "JK1", rscales = rsc)
  test_invariants(d)
  expect_equal(d@variables$rscales, rsc)
  ```

- **`calibration = list()` with `type = "bootstrap"` raises `surveycore_error_provenance_not_bootstrap`**:
  ```r
  expect_error(
    as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"),
                      type = "bootstrap", calibration = list()),
    class = "surveycore_error_provenance_not_bootstrap"
  )
  ```

- **`calibration = list()` with `type = "JK1"` accepted**:
  ```r
  d <- as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"),
                         type = "JK1", calibration = list())
  test_invariants(d)
  ```

- **`scale = 0` accepted**: call JK1 with `scale = 0` and 4 replicates. Assert
  no error and `design@variables$scale == 0`. (Zero scale produces zero
  variance, which is valid.)

- **`type = "jackknife"` not stored**: after constructing with
  `type = "jackknife"`, assert `identical(design@variables$type, "JK1")` and
  `!identical(design@variables$type, "jackknife")`.

- **`type = "jackknife"` alias with explicit non-uniform rscales**: call with
  `type = "jackknife"` and `rscales = c(1, 1, 0.5, 1)`. Assert
  `design@variables$type == "JK1"` and `design@variables$rscales` equals the
  supplied vector. (Confirms alias normalization occurs before rscales check.)

- **JK1 scale exact value**: for R = 10 replicates, assert
  `design@variables$scale == 9 / 10` exactly (not approximately).

- **JK2 default scale = 1**: for JK2 with explicit rscales, assert
  `design@variables$scale == 1` exactly.

- **JKn default scale = 1**: same assertion for `type = "JKn"`.

- **repweights = NULL, type = "BRR"**: assert no error is raised (type is
  ignored when repweights is NULL).

- **repweights = NULL, type = "jackknife"**: assert no error and
  `design@variables$type == NULL`.

- **calibration = list(bootstrap = FALSE) with JK1**: assert no error.
  Ensures the bootstrap provenance check is type-gated.

- **calibration = list(R = 4L) with JK1, 4 replicates**: assert no error
  (R count matches, no bootstrap check needed).

- **calibration = list(R = 3L) with JK1, 4 replicates**: assert
  `surveycore_error_provenance_R_mismatch` fires. (R check applies to JK.)

---

### `print.survey_nonprob`

#### Happy paths

- **JK1 header text**: construct a JK1 nonprob design with 5 replicates. Call
  `print(design)`. Assert the output contains `"JK1"` and does not contain
  `"BOOTSTRAP"`. Use `expect_output()` or `expect_snapshot()`.

- **JK2 header text**: construct a JK2 nonprob design. Assert output contains
  `"JK2"`.

- **JKn header text**: construct a JKn nonprob design. Assert output contains
  `"JKN"` (uppercased).

- **Bootstrap header text unchanged**: construct a bootstrap nonprob design.
  Assert output still contains `"BOOTSTRAP"`. (Regression guard.)

- **No replicates header text unchanged**: construct an SRS-mode nonprob design
  (no repweights). Assert output contains `"non-probability"` but not
  `"BOOTSTRAP"` and not `"JK"`.

- **Snapshot for JK1 print**: `expect_snapshot(print(jk1_design))`.

- **Snapshot for JK2 print**: `expect_snapshot(print(jk2_design))`. (Prevents
  undetected regressions in header formatting for JK2.)

- **Snapshot for JKn print**: `expect_snapshot(print(jkn_design))`. (Prevents
  undetected regressions in header formatting for JKn.)

- **Snapshot for bootstrap print**: `expect_snapshot(print(bootstrap_design))`.
  (Regression guard — full print output must not change.)

#### Invariants

- `test_invariants(design)` before each print test construction.
- Return value is the input object, invisibly:
  `expect_identical(print(design), design)`.

---

### `summary.survey_nonprob`

#### Happy paths

- **JK1 summary type line**: construct a JK1 nonprob design, call
  `summary(design)`. Assert output contains `"JK1"` (toupper of `"JK1"` is
  `"JK1"`).

- **JKn summary type line uppercased**: construct a JKn nonprob design, call
  `summary(design)`. Assert output contains `"JKN"` (not `"JKn"`).

- **Bootstrap summary type line uppercased**: construct a bootstrap nonprob
  design, call `summary(design)`. Assert output contains `"BOOTSTRAP"` (not
  `"bootstrap"`). (Regression guard — confirms toupper() applied consistently.)

- **SRS summary type line unchanged**: construct SRS-mode (no repweights),
  call `summary(design)`. Assert output does not contain `"JK"` or
  `"BOOTSTRAP"`.

- **Snapshot for JK1 summary**: `expect_snapshot(summary(jk1_design))`.

- **Snapshot for JK2 summary**: `expect_snapshot(summary(jk2_design))`.
  (Pins the `"JK2"` type string in the summary header; consistent with JK2
  snapshot policy used for `print`.)

- **Snapshot for JKn summary**: `expect_snapshot(summary(jkn_design))`.
  (Pins the `"JKN"` uppercased type string; consistent with JKn snapshot
  policy used for `print`.)

---

### Analysis functions with jackknife nonprob designs

These tests verify that `get_means()`, `get_totals()`, and `get_freqs()` do
not error on JK1 nonprob designs, and that the SEs produced match the
`survey` package oracle within tolerance.

#### Happy paths — dispatch does not error

- **`get_means()` on JK1 nonprob**: construct a JK1 nonprob design, call
  `get_means(design, y)` where `y` is a numeric column. Assert:
  - No error, no warning about type.
  - Result is a tibble.
  - `result$se` is a finite positive numeric value.

- **`get_totals()` on JK1 nonprob**: same structure.

- **`get_freqs()` on JK1 nonprob**: construct with a factor column `grp`,
  call `get_freqs(design, grp)`. Assert no error.

- **`get_means()` on JK2 nonprob with explicit rscales**: assert no error.

#### Edge case dispatch — categories 6, 7, 8

These tests verify JK1 designs do not error on edge-case analysis inputs. The
variance engine code path is shared with bootstrap, but JK1 uses different
`scale`/`rscales`, so dedicated tests add real coverage (RJ-1 decision).

- **Category 6 — all-NA outcome**: construct a JK1 nonprob design where the
  outcome variable `y` is all NA. Call `get_means(design, y)`. Assert no
  error is thrown and `result$mean` is NA (or the function handles gracefully
  per existing behavior).

- **Category 7 — single-level grouping**: construct a JK1 nonprob design with
  a factor column `grp` having only one level. Call
  `get_means(design, y, group = grp)`. Assert no error is thrown.

- **Category 8 — zero-weight domain**: construct a JK1 nonprob design where
  all units in one domain have zero main weight. Call `get_means(design, y,
  group = grp)`. Assert no error (domain estimates may be `NaN`/`NA`; no
  hard error expected).

#### Warning regression guards — `.nonprob_rep_na_warn()` message is type-agnostic

These tests verify that the updated warning message in `R/analysis-helpers.R`
does not mention "bootstrap" for non-bootstrap designs.

- **Domain-NA warning fires for JK1 with > 5% sparse replicates**: construct a
  JK1 nonprob design (20 replicates, `n = 50`) where one subgroup (`grp == "A"`,
  containing 1 unit) has exactly 0 weight in 2 of the 20 replicates (10% NA
  rate). Call `get_means(design, y, group = grp)`. Assert:
  - `surveycore_warning_domain_replicates_na` fires.
  - The warning message does **not** contain the word `"bootstrap"` (snapshot
    this message to pin the type-agnostic text).

- **Domain-NA warning does NOT fire for JK1 at exactly 5% NA rate**: construct a
  JK1 design where a domain has exactly 1 NA replicate out of 20 (5% — at the
  strict threshold). Assert no warning fires (`na_frac > 0.05` is the condition;
  `0.05` is not `> 0.05`).

#### SRS-vs-stratified contrast (Category 10)

The JK1 happy-path test (unclustered, `rscales = rep(1, R)`, `scale =
(R-1)/R`) and JK2 happy-path test (stratified, explicit `rscales`, `scale =
1`) constitute a sufficient SRS-vs-stratified contrast at the constructor level.
The two designs store different `scale` and `rscales` values, which ARE the
structural difference between unclustered and stratified jackknife. Analysis-
level divergence testing (showing JK1 and JK2 produce different SEs for the
same data) belongs in a future numerical validation PR.

#### Numerical parity with `survey` package (JK1)

These tests require `skip_if_not_installed("survey")` inside each block.

Test setup (inline, not from a generator):
```
n  <- 100
R  <- 20
set.seed(42)
y  <- rnorm(n, mean = 5)
wt <- runif(n, 0.8, 1.2)

# Build R jackknife replicates: delete-one pseudo-weights
# For JK1, replicate r omits unit r and redistributes weight uniformly
# Full-sample weight * n / (n - 1) for included units; 0 for omitted unit
rep_mat <- matrix(0, nrow = n, ncol = R)
for (r in seq_len(R)) {
  rep_mat[, r] <- wt * n / (n - 1)
  rep_mat[r, r] <- 0
}
df <- data.frame(y = y, wt = wt)
df[paste0("jk", seq_len(R))] <- as.data.frame(rep_mat)
```

- **`get_means()` SE matches `survey::svymean()`**:
  - Build surveycore JK1 nonprob design:
    `as_survey_nonprob(df, weights = wt, repweights = starts_with("jk"), type = "JK1")`
  - Build oracle `survey::svrepdesign(data = df, repweights = rep_mat, weights = ~wt, type = "JK1", combined.weights = TRUE)`
  - Compute `get_means(sc_design, y)` and `survey::svymean(~y, sv_design)`
  - Assert SE matches within tolerance 1e-8 (`expect_equal(sc_se, sv_se, tolerance = 1e-8)`).
  - Assert point estimate matches within tolerance 1e-10.

- **`get_totals()` SE matches `survey::svytotal()`**:
  - Same data setup.
  - Assert total SE matches within tolerance 1e-8.
  - Assert total point estimate matches within tolerance 1e-10.

#### Regression guard — bootstrap SE unchanged

- Construct a bootstrap nonprob design from the same data frame (using
  bootstrap replicate scheme). Assert `get_means()` SE is identical to what
  was produced before this PR (use a snapshot, not a specific numeric value,
  since this is an end-to-end check on existing behavior).

---

### `surveycore_warning_nonprob_srs_fallback` — SRS warning still fires

- **Warning still fires for JK1 design without replicates**: construct a
  `survey_nonprob` with no repweights and call `get_means()`. Assert the
  warning class `surveycore_warning_nonprob_srs_fallback` fires. (Regression
  guard — SRS fallback path is not affected by this PR.)

---

## Tolerances

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total, proportion) | 1e-10 |
| SE / variance | 1e-8 |
| CI bounds | 1e-6 |

No deviations from standard surveycore tolerances are required. JK1 jackknife
variance for a simple delete-one scheme is numerically identical in both
packages (no approximation differences expected).

---

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() >= 95% (target 98%)
- [ ] CRAN cookbook scan clean
