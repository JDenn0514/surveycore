# Test-spec — pool-pvals

## Reference oracle

- `stats::p.adjust()` from base R (the same R version the package is
  built against). Every adjusted-p-value test calls `pool_pvals()`,
  extracts the pooled raw vector in row order, calls `stats::p.adjust(p,
  method)` on it directly, and compares element-wise. There is no
  external R package oracle — the function is a thin wrapper around
  `stats::p.adjust()` over a row-bound family, and `stats::p.adjust()`
  itself is the ground truth for every method.

## Datasets

- **Inline synthetic tibbles** via `tibble::tibble(p_value = ..., dv =
  ..., term = ...)` for all unit tests. Construct fresh tibbles per
  test; do not promote to a helper.
- **Heterogeneous-shape synthetic tibbles** — hand-build two tibbles
  with disjoint column sets (mimicking the `get_diffs()` shape and the
  `get_pairwise()` shape) for the heterogeneous-bind test. Do not call
  the real `get_*()` functions in this test; just synthesize the column
  shapes.
- **`gss_2024`** (already shipped with surveycore) for the integration
  test only. Build a survey design via `as_survey()` and call
  `get_diffs()` for two distinct DVs, pool the results.

## Per-function test plan

### `pool_pvals`

**Happy path**

- Named list of two tibbles, default arguments — output is a tibble,
  `nrow` equals sum of input nrows, columns include the union of input
  columns plus `source` (filled with input names) and `p_value_adj`.
- Parametrized over every value in `stats::p.adjust.methods` — for
  each method, `pool_pvals(list, method = m)$p_value_adj` equals
  `stats::p.adjust(pooled_raw, m)` element-wise within tolerance.
- **m = 1 identity, parametrized over each of the eight
  `stats::p.adjust.methods` values** — single-element list with one
  non-NA `p_value`; for every method, the `p_value_adj` value equals
  the input `p_value` exactly. No warning emitted.
- Unnamed list — `id_col` column (`source`) contains `"1"`, `"2"`, ...
  as character (matching `dplyr::bind_rows(.id = ...)` behavior).
- Mixed-named list (some elements named, some not) — names appear
  verbatim where present; integer-coerced indices appear elsewhere.
- Custom `p_col` — pooling on a column named e.g. `"pval"` instead of
  `"p_value"` works identically.
- Custom `new_col` — output column lands at the requested name; no
  `p_value_adj` column appears.
- Custom `id_col` — source identifier lands at the requested name; no
  `source` column appears.
- **Column ordering** — for a happy-path call, assert that
  `names(result)` ends with `id_col`, `new_col`, and (when applicable)
  `paste0(new_col, "_within")`, in that order; the prefix is the union
  of input columns in input-union order.

**S3 class and `.meta` attribute tests**

- `inherits(result, "survey_pooled_pvals")` is `TRUE`.
- `inherits(result, "tbl_df")` is `TRUE` (still a tibble).
- `class(result)` exactly equals `c("survey_pooled_pvals", "tbl_df",
  "tbl", "data.frame")`.
- `attr(result, ".meta")` is a list with the expected keys: `method`,
  `family_size`, `n_total`, `n_na`, `n_significant_05`, `id_col`,
  `p_col`, `new_col`. Each value matches the call args / input shape:
  - `.meta$method` equals the `method` argument.
  - `.meta$family_size` equals `sum(!is.na(pooled_p))`.
  - `.meta$n_total` equals `sum(input nrows)`.
  - `.meta$n_na` equals `sum(is.na(pooled_p))`.
  - `.meta$n_significant_05` equals `sum(result[[new_col]] < 0.05,
    na.rm = TRUE)`.
  - `.meta$id_col`, `.meta$p_col`, `.meta$new_col` equal the
    corresponding call arguments.

**`print.survey_pooled_pvals` tests**

- Snapshot test of full print output for a small representative input
  (3 elements, 2 of which have non-trivial p-values; default
  arguments).
- Snapshot test of the header line specifically — verify
  `<survey_pooled_pvals: method = "BH", family_size = N, K significant
  at α = 0.05>` form.
- Snapshot test of the NA-footer: when the input includes NA p-values,
  print includes `# K p-values were NA and excluded from the family`.
  When `n_na == 0`, no footer appears.
- `print()` returns `invisible(x)`: assert via
  `expect_invisible(print(result))`.

**Error paths** — each error path is a **dual-pattern** test. The
syntax is, for each of the six error classes:

```r
test_that("pool_pvals() throws <class> for <condition>", {
  expect_error(
    pool_pvals(<args triggering the error>),
    class = "<error class>"
  )
  expect_snapshot(
    error = TRUE,
    pool_pvals(<args triggering the error>)
  )
})
```

The six error classes:

| Class | Trigger |
|---|---|
| `surveycore_error_pool_pvals_empty` | `pool_pvals(list())` |
| `surveycore_error_pool_pvals_not_list` | `pool_pvals(tibble::tibble(p_value = 0.05))` (single tibble); separately, `pool_pvals(c(0.01, 0.05))` (atomic vector); and `pool_pvals(NULL)` — all three must throw the same class |
| `surveycore_error_pool_pvals_invalid_method` | `method = "fancy"`; also `method = c("BH", "holm")` (length > 1) |
| `surveycore_error_pool_pvals_missing_pcol` | List where one element omits the `p_value` column; assert message names the offending index |
| `surveycore_error_pool_pvals_invalid_pvalues` | List with one element containing a `p_value` of `1.5` (out of `[0, 1]`); assert message lists the offending row identifiers (`id_col` value plus row index within source). Use a fresh inline tibble; do not reuse the missing-pcol fixture |
| `surveycore_error_pool_pvals_id_col_collision` | List with one element containing a column already named `source` (the default `id_col`); assert message names the offending element. Also assert the error fires *before* any bind work is performed (no leaked partial output) |

**Warning paths** (each is `expect_warning(class = ...)`; capture the
return value and assert it is still a valid tibble)

| Class | Trigger |
|---|---|
| `surveycore_warning_pool_pvals_input_pre_adjusted` | List where one element already contains `p_value_adj`, `strip_within_adj = FALSE` — assert output has both `p_value_adj` and `p_value_adj_within` columns; assert NA padding for elements that did not have the pre-existing column |
| `surveycore_warning_pool_pvals_no_pvalues_available` | List of tibbles where `p_value` is all `NA` — assert output is returned with all-NA `p_value_adj` |

**Edge cases**

- Single-element list, default method — output equals the input row
  count; for `method = "BH"` with `m = 1` non-NA p-value, the adjusted
  value equals the raw value; no warning emitted.
- Zero-row tibble as one element — no rows contributed from that
  element; total output `nrow` equals nrow of the other elements; no
  warning.
- Some-NA pooled `p_col` — `new_col` is NA exactly where input `p_col`
  was NA; non-NA values match `stats::p.adjust(p_value, method)`
  applied to the full vector (which uses `n = sum(!is.na(p))` by
  default). No warning.
- Heterogeneous columns — two synthetic tibbles with disjoint extra
  columns: assert output contains the union, with NA-fill in rows
  whose source did not contribute that column. Assert the column
  ordering: union-of-input-columns first, then `source`, then
  `p_value_adj`.
- Heterogeneous `p_col` types (one element with integer `p_value`,
  one with double) — `bind_rows()` coerces to double; pooled values
  are numeric and `stats::p.adjust()` runs without error. Confirm
  output `p_value` is numeric.
- Attribute non-preservation — attach a `variable_label` attribute
  to the `p_value` column of one input element via
  `attr(x$p_value, "variable_label") <- "Outcome 1"`; pool; assert
  that the resulting `result$p_value` does NOT carry the
  `variable_label` attribute. This documents the
  `dplyr::bind_rows()` default behavior described in the spec
  Returns section.
- `strip_within_adj = TRUE` with pre-existing `p_value_adj` in input
  — no warning is emitted; output contains a single `p_value_adj`
  column (the pooled-adjusted one); no `p_value_adj_within` column
  appears.
- Custom `new_col = "fdr_q"` colliding with a pre-existing `fdr_q`
  column in one input, `strip_within_adj = FALSE` — output contains
  both `fdr_q` and `fdr_q_within`; warning fires.
- Method `"none"` — `new_col` equals raw `p_col` element-wise within
  tolerance.
- Pooling across two methods sequentially (call `pool_pvals()` twice
  on the same list with different methods, store outputs separately) —
  results are independent; second call does not see the first call's
  state.

**Round-trip oracle test (parametrized)**

For each method `m` in `stats::p.adjust.methods`:

1. Build a list of three tibbles with hand-chosen `p_value` vectors
   that include 0, 1, NA, and values in between.
2. Call `pool_pvals(list, method = m)`, extract `p_value_adj`.
3. Concatenate the original `p_value` vectors in input list order.
4. Call `stats::p.adjust(pooled_raw, method = m)`.
5. Assert element-wise equality within the tolerance below.

**Heterogeneous-column shape test**

Two tibbles: one mimicking `get_diffs()` (columns `term`, `estimate`,
`std_error`, `p_value`), one mimicking `get_pairwise()` (columns
`group1`, `group2`, `estimate`, `p_value`). Pool with default args.
Assert output has all six unique non-overlapping columns plus shared
`estimate` and `p_value`, plus `source` and `p_value_adj`. Assert
`get_diffs`-side rows have NA in `group1`/`group2` and vice versa.

**Integration test with `gss_2024`** (`skip_on_cran()`,
`skip_if_not_installed("survey")` if needed)

1. Build `as_survey(gss_2024, ...)` design.
2. Call `get_diffs(des, x = dv1, group = grp, pval_adj = NULL)` and
   `get_diffs(des, x = dv2, group = grp, pval_adj = NULL)`.
3. Pool with `pool_pvals(list(dv1 = r1, dv2 = r2))` defaulting to BH.
4. Assert the output is a tibble, has `source` and `p_value_adj`,
   and `p_value_adj` element-wise equals `stats::p.adjust(c(r1$p_value,
   r2$p_value), "BH")`.
5. Assert `inherits(result, "survey_pooled_pvals")`.

**Refactor regression — `get_diffs()` and `get_pairwise()`**

The shared validator `.validate_pval_adjustment_method()` is reused
by `get_diffs()` and `get_pairwise()`. The existing tests in
`test-analysis-diffs.R` and `test-analysis-t-test.R` for
`pval_adj` invalid-method errors must continue to pass without
snapshot updates:

- The error class is `surveycore_error_invalid_pval_adj` (unchanged).
- The error message text is unchanged (matches existing snapshots in
  `tests/testthat/_snaps/test-analysis-diffs.md` and
  `tests/testthat/_snaps/test-analysis-t-test.md`).

This is verified by running the full test suite after the refactor;
no new test cases are added to the existing files.

## Tolerances

- **Adjusted p-values**: `1e-12`. Justification: `pool_pvals()` is a
  pure pass-through to `stats::p.adjust()` over a row-bound numeric
  vector. There is no floating-point reordering, no design-based
  variance computation, no iterative solver. The only arithmetic is
  whatever `stats::p.adjust()` itself performs on identical inputs.
  Tighter than the default 1e-10 because the comparison is between
  two calls to the same base R function on the same vector — any
  difference larger than machine epsilon would indicate a real bug.
- **Standard tolerances** (point 1e-10, SE 1e-8, CI 1e-6) do not apply
  here — `pool_pvals()` does not estimate, only adjusts.

## Profile gates

- [ ] `devtools::document()` clean
- [ ] `devtools::test()` all pass
- [ ] `devtools::run_examples()` all pass
- [ ] `R CMD check --as-cran` (0 err, 0 warn, notes reviewed)
- [ ] `pkgcheck` PASS
- [ ] `pkgdown::build_site()` clean
- [ ] `covr::package_coverage()` ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see `r-package-profile.md`)
