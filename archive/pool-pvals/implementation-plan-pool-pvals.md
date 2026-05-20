# Implementation plan — pool-pvals

**Slug**: `2026-04-29-pool-pvals`
**Target version**: 0.8.3.9000
**Target branch**: `develop`
**PR count**: 1

## PR map

- [x] PR 1: `feature/pool-pvals` — Add `pool_pvals()` for cross-DV
      multiplicity correction over a list of surveycore analysis
      result tibbles, plus its S3 print method, S3 class, `.meta`
      attribute, and a shared `pval_adj` validator refactor across
      `get_diffs()` and `get_pairwise()`.

  - **Pipeline split**: recommended

  - **Files touched** (write surface — exhaustive)
    - `R/analysis-pool-pvals.R` — created
    - `R/analysis-helpers.R` — modified
    - `R/analysis-diffs.R` — modified
    - `R/analysis-t-test.R` — modified
    - `tests/testthat/test-analysis-pool-pvals.R` — created
    - `man/pool_pvals.Rd` — generated
    - `man/print.survey_pooled_pvals.Rd` — generated
    - `_pkgdown.yml` — modified
    - `NEWS.md` — modified
    - `NAMESPACE` — generated

    Out of scope for this PR (already landed in Stage 3r):
    `plans/error-messages.md`. Do not edit it in this PR.

  - **Tasks** (2–5 minutes each, strict TDD: red → green → verify)

    ### Phase 1 — Bootstrap (no behavior changes)

    1. Append a `pool_pvals()` entry to `NEWS.md` under the
       `# surveycore 0.8.3.9000` header (one bullet summarizing the
       new function and shared validator refactor).
    2. Create `R/analysis-pool-pvals.R` with file-level header
       comment and an empty stub `pool_pvals <- function(...)
       stop("not implemented")`. No roxygen yet.
    3. Run `devtools::load_all()` and confirm the package still
       loads (no syntax errors in the new file).

    ### Phase 2 — Private helpers (red → green per helper)

    4. In `tests/testthat/test-analysis-pool-pvals.R`, write the
       happy-path "named list returns a tibble" test as a failing
       test (no implementation yet); run `devtools::test_active_file()`
       and confirm it fails with "not implemented".
    5. In `R/analysis-helpers.R`, add `.is_plain_list(x)` returning
       `is.list(x) && !inherits(x, "data.frame")`. Roxygen with
       `@keywords internal` + `@noRd`.
    6. In the test file, add a direct test for `.is_plain_list()`:
       `expect_true(.is_plain_list(list()))`,
       `expect_false(.is_plain_list(tibble::tibble()))`,
       `expect_false(.is_plain_list(c(1, 2)))`,
       `expect_false(.is_plain_list(NULL))`. Confirm passing via
       `devtools::test_active_file()`.
    7. In `R/analysis-helpers.R`, add
       `.validate_pval_adjustment_method(method, arg_name = "method",
       call = rlang::caller_env(), class = "surveycore_error_invalid_pval_adj")`.
       Body: assert single character string; assert membership in
       `stats::p.adjust.methods`; on failure call `cli::cli_abort()`
       with the supplied `class` and `call`. Roxygen with
       `@keywords internal` + `@noRd`.
    8. Verify the helper indirectly: write a test that calls
       `pool_pvals(list(tibble::tibble(p_value = 0.5)),
       method = "fancy")` and `expect_error(class =
       "surveycore_error_pool_pvals_invalid_method")`. Test fails
       (no `pool_pvals` body yet).
    9. In `R/analysis-helpers.R`, add `.validate_list_columns(results,
       col_names, id_col)`. Body: walk `seq_along(results)`, collect
       names of elements (or character indices when names are
       missing) where `col_names` are absent or `id_col` is present.
       Return `list(missing_pcol = character(), id_collision =
       character())`. Roxygen with `@keywords internal` + `@noRd`.

    ### Phase 3 — `pool_pvals()` validation precedence

    10. Write a failing test for error 1: `pool_pvals(NULL)` raises
        `surveycore_error_pool_pvals_not_list`. Add the dual-pattern
        snapshot test.
    11. Implement check 1 in `pool_pvals()`: if `!.is_plain_list(results)`,
        `cli::cli_abort()` with class
        `surveycore_error_pool_pvals_not_list` and a message naming
        the offending top-level type (`data.frame`, `NULL`, or the
        atomic `typeof()`). Confirm test passes.
    12. Add and pass dual-pattern tests for the tibble and atomic-vector
        triggers of the same class
        (`pool_pvals(tibble::tibble(p_value = 0.05))` and
        `pool_pvals(c(0.01, 0.05))`). Both must hit the same class
        as `NULL`.
    13. Write a failing test for error 2 (`pool_pvals(list())`) and
        the dual-pattern snapshot.
    14. Implement check 2: empty-list early exit raising
        `surveycore_error_pool_pvals_empty`. Confirm pass.
    15. Write failing tests for error 3 (`method = "fancy"` and
        `method = c("BH", "holm")`) including dual-pattern snapshot.
    16. Implement check 3: call
        `.validate_pval_adjustment_method(method, arg_name = "method",
        class = "surveycore_error_pool_pvals_invalid_method")`. Do
        NOT pass `call =` — rely on the helper's
        `call = rlang::caller_env()` default so the error appears to
        originate from `pool_pvals()` (per spec §Architecture lines
        381–383). Confirm pass.
    17. Write a failing test for error 4: list of two tibbles where
        the second omits `p_value`. Dual-pattern snapshot. Assert
        message names the offending element.
    18. Implement check 4: call `.validate_list_columns(results,
        col_names = p_col, id_col = id_col)`. If `missing_pcol` is
        non-empty, `cli::cli_abort()` class
        `surveycore_error_pool_pvals_missing_pcol` listing offenders
        (names where present, 1-based indices coerced to character
        otherwise). Confirm pass.
    19. Write a failing test for error 5: list of two tibbles where
        the first contains a `source` column already. Dual-pattern
        snapshot. Assert message names offending element. Assert no
        partial output is leaked (no side effects).
    20. Implement check 5: same `.validate_list_columns()` return
        carries `id_collision`; raise
        `surveycore_error_pool_pvals_id_col_collision` listing
        offenders and suggesting `id_col =` rename. Confirm pass.
    21. Write failing tests for the warning path with
        `strip_within_adj = FALSE`: list of two tibbles, the first
        has a pre-existing `p_value_adj` column. Use
        `expect_warning(class =
        "surveycore_warning_pool_pvals_input_pre_adjusted")` and
        capture return value. Assert output has both `p_value_adj`
        (pooled-adjusted) and `p_value_adj_within` (renamed
        pre-existing) columns; assert NA padding for the second
        element in `p_value_adj_within`.
    22. Write a parallel passing test for `strip_within_adj = TRUE`
        with the same input: `expect_no_warning()`; assert the
        output contains only `p_value_adj` (the pooled-adjusted
        one); no `p_value_adj_within`.
    23. Implement check 6: per-element `new_col` detection. If
        `strip_within_adj = FALSE` and at least one element contains
        `new_col`, rename per element to
        `paste0(new_col, "_within")` and emit
        `cli::cli_warn()` class
        `surveycore_warning_pool_pvals_input_pre_adjusted` once
        listing offending elements. If `strip_within_adj = TRUE`,
        silently drop the column from each offending element. Confirm
        both tests pass.

    ### Phase 4 — `pool_pvals()` happy-path return shape

    24. Write a failing happy-path test (named list, default args):
        result is a tibble; `nrow(result) == sum(input nrows)`;
        column union present; `source` and `p_value_adj` present.
    25. Implement step 7: `bound <- dplyr::bind_rows(results, .id =
        id_col)`. (This satisfies the column-union and `source`
        construction; NA-fills heterogeneous columns automatically.)
    26. Write a failing test for error 8: list with one element
        containing `p_value = 1.5`. Dual-pattern snapshot. Assert
        message lists offending row identifiers (`source` value plus
        within-source row index). Use a fresh inline tibble (not the
        missing-pcol fixture).
    27. Implement check 8: after the bind, validate
        `bound[[p_col]]` — non-NA values must be in `[0, 1]`. On
        violation, raise
        `surveycore_error_pool_pvals_invalid_pvalues` with offending
        rows enumerated by `(source, row index within source)`.
        Confirm pass.
    28. Write a failing happy-path test asserting numerical
        equivalence with `stats::p.adjust()` element-wise (default
        `method = "BH"`).
    29. Implement step 9: `bound[[new_col]] <-
        stats::p.adjust(bound[[p_col]], method = method)`. Confirm
        pass.
    30. Write a failing test for the warning path
        `surveycore_warning_pool_pvals_no_pvalues_available`: list
        of tibbles where every `p_value` is `NA`.
        `expect_warning(class = ...)`; capture and assert output is
        still returned with all-NA `new_col`.
    31. Implement check 10: after `stats::p.adjust()`, if
        `all(is.na(bound[[p_col]]))`, emit
        `surveycore_warning_pool_pvals_no_pvalues_available`. The
        bound result still returns. Confirm pass.
    32. Write a failing test for explicit column ordering: assert
        `names(result)` ends with `id_col`, `new_col`, and (in the
        warning case) `paste0(new_col, "_within")`, in that order;
        the prefix is the union of input columns in input-union
        order.
    33. Implement column reordering: after `stats::p.adjust()`,
        construct the output with the columns in the order
        prescribed in the spec Returns section. Use
        `dplyr::relocate()` or direct subscript. Confirm pass.
    34. Write a failing test for the S3 class hierarchy:
        `class(result)` exactly equals `c("survey_pooled_pvals",
        "tbl_df", "tbl", "data.frame")`.
    35. Implement: `class(out) <- c("survey_pooled_pvals",
        class(out))` after relocate (which preserves tibble class).
        Confirm pass.
    36. Write a failing test for the `.meta` attribute: assert
        `is.list(attr(result, ".meta"))` and that the eight required
        keys are present with the specified values.
    37. Implement: build `.meta` list with `method`, `family_size`,
        `n_total`, `n_na`, `n_significant_05`, `id_col`, `p_col`,
        `new_col`. Attach via `attr(out, ".meta") <- meta`. Confirm
        pass.

    ### Phase 5 — `print.survey_pooled_pvals()`

    38. Write a failing snapshot test for the full print output of a
        small representative input (3 elements, 2 of which carry
        non-trivial p-values; default args). Use
        `expect_snapshot()`.
    39. Implement `print.survey_pooled_pvals(x, n = 10, ...)` in
        `R/analysis-pool-pvals.R`: build the cli header from the
        `.meta` list:
        `<survey_pooled_pvals: method = "{m}", family_size = {N},
        {K} significant at α = 0.05>`. Print with
        `cli::cli_text()`. Then call `NextMethod()` to delegate to
        `print.tbl_df`. After tibble body, if `attr(x, ".meta")$n_na
        > 0`, print
        `# {n_na} p-values were NA and excluded from the family`.
        Return `invisible(x)`.
    40. Write a failing snapshot test of the header line in
        isolation (capture via `withr::with_output_sink()` or the
        existing `expect_snapshot()` snippet pattern).
    41. Confirm header snapshot passes.
    42. Write a failing snapshot test of the NA footer when
        `n_na > 0` and confirm absence when `n_na == 0`.
    43. Confirm footer snapshot passes.
    44. Write a failing test
        `expect_invisible(print(result))`. Confirm pass.

    ### Phase 6 — Refactor `get_diffs()` and `get_pairwise()`

    45. Locate the inline `pval_adj` validation block in
        `R/analysis-diffs.R`. Replace it with a call to
        `.validate_pval_adjustment_method(pval_adj, arg_name =
        "pval_adj", class = "surveycore_error_invalid_pval_adj")`.
        Do NOT pass `call =` — rely on the helper's
        `call = rlang::caller_env()` default. Preserve the existing
        error class and message text exactly.
    46. Run `devtools::test_active_file("test-analysis-diffs.R")`.
        Confirm the existing
        `_snaps/test-analysis-diffs.md` snapshot for the invalid
        `pval_adj` case still matches verbatim. If the snapshot
        diverges, fix the helper's message construction; do NOT
        update the snapshot.
    47. Locate the inline `pval_adj` validation block in
        `R/analysis-t-test.R` inside `get_pairwise()`. Replace
        with an analogous call to
        `.validate_pval_adjustment_method(pval_adj, arg_name =
        "pval_adj", class = "surveycore_error_invalid_pval_adj")`.
        Do NOT pass `call =` — rely on the helper's
        `call = rlang::caller_env()` default. Preserve the existing
        error class and message text exactly.
    48. Run `devtools::test_active_file("test-analysis-t-test.R")`.
        Confirm the existing
        `_snaps/test-analysis-t-test.md` snapshot for the invalid
        `pval_adj` case still matches verbatim.

    ### Phase 7 — Edge cases and parametrized tests

    49. Add the parametrized round-trip oracle test: loop over each
        `m` in `stats::p.adjust.methods`, build a list of three
        tibbles with `p_value` vectors including `0`, `1`, `NA`, and
        intermediate values, call `pool_pvals(list, method = m)`,
        and `expect_equal(result$p_value_adj,
        stats::p.adjust(c(input p vectors), m), tolerance = 1e-12)`.
    50. Add the parametrized `m = 1` identity test: loop over each
        `m` in `stats::p.adjust.methods`, single-element list with
        one non-NA `p_value`; assert `result$p_value_adj` equals the
        input `p_value`; assert `expect_no_warning()`.
    51. Add edge tests: zero-row tibble in input (no rows
        contributed, no warning); some-NA pooled `p_col` (NA
        positions preserved); heterogeneous columns (column-union,
        NA-fill).
    52. Add edge tests: heterogeneous `p_col` types (one integer,
        one double — bind coerces to double; pool runs without
        error; result `p_value` is numeric).
    53. Add the attribute non-preservation edge test: attach
        `attr(x$p_value, "variable_label") <- "Outcome 1"` to one
        input element; pool; assert `attr(result$p_value,
        "variable_label")` is `NULL`.
    54. Add the custom `new_col = "fdr_q"` collision edge test
        (`strip_within_adj = FALSE`, pre-existing `fdr_q` in one
        element): assert output has both `fdr_q` and `fdr_q_within`;
        assert warning fires.
    55. Add the `method = "none"` edge test:
        `expect_equal(result$p_value_adj, raw_p, tolerance = 1e-12)`.
    56. Add the sequential-call independence edge test: two
        `pool_pvals()` calls on the same list with different
        methods; assert outputs are independent (no shared state).
    57. Add the heterogeneous-column shape test (synthesized
        `get_diffs()`-shape and `get_pairwise()`-shape tibbles):
        assert the output column union, NA-fill on each side, and
        column ordering ends with `source` then `p_value_adj`.
    58. Add the unnamed-list test: assert `source` column equals
        `c("1", "2", "3")` (character).
    59. Add the mixed-named-list test: assert names appear verbatim
        where present and integer-coerced indices elsewhere.
    60. Add custom-`p_col`, custom-`new_col`, and custom-`id_col`
        happy-path tests.

    ### Phase 8 — Integration test with `gss_2024`

    61. Add an integration test: `skip_on_cran()` and
        `skip_if_not_installed("survey")` if needed; build
        `as_survey(gss_2024, ...)`; call `get_diffs()` for two
        distinct DVs with `pval_adj = NULL`; pool with default args;
        assert the output is a tibble, has `source` and
        `p_value_adj`, `p_value_adj` element-wise equals
        `stats::p.adjust(c(r1$p_value, r2$p_value), "BH")` within
        `1e-12`, and `inherits(result, "survey_pooled_pvals")`.

    ### Phase 9 — Roxygen, NAMESPACE, pkgdown

    62. In `R/analysis-pool-pvals.R`, add the full roxygen block
        for `pool_pvals()`: `@title`, `@description`, `@param` for
        each argument, `@return` describing the
        `survey_pooled_pvals` class and `.meta` attribute, the
        `@details` block organized with the 12 numbered sub-headers
        (Method choice; Default method justification; Recommended
        workflow; Statistical caveat about double-adjustment;
        Worked NA-denominator example; Column-shape user-owned risk;
        Cross-design pooling caveat; Small-m regime; `"fdr"` alias
        note; Discrete p-value caveat; Collection workflow note;
        See also), `@references` listing the five primary citations
        with `\doi{}` markup where applicable, an `@examples` block
        demonstrating multi-DV pooling, and `@export`.
    63. Add a roxygen block for `print.survey_pooled_pvals(x, n,
        ...)`: `@title`, `@param`, `@return` (`invisible(x)`),
        `@export`, `@method print survey_pooled_pvals`.
    64. Run `devtools::document()`. Confirm no warnings; confirm
        `man/pool_pvals.Rd`, `man/print.survey_pooled_pvals.Rd`,
        and `NAMESPACE` (with `export(pool_pvals)` and
        `S3method(print, survey_pooled_pvals)`) are regenerated.
    65. Edit `_pkgdown.yml`: add a new top-level reference section
        titled `Post-hoc / multiplicity correction` with
        `contents: [pool_pvals, print.survey_pooled_pvals]`. Place
        it after the existing `get_*` analysis section. Confirm
        `pool_pvals` is NOT listed under the analysis family.

    ### Phase 10 — Final verification gates

    66. Run `devtools::document()` once more and confirm no
        regenerated diffs (idempotent).
    67. Run `devtools::test()` — confirm full suite passes,
        including all new `pool_pvals` tests AND the existing
        `test-analysis-diffs.R` and `test-analysis-t-test.R` tests
        (the refactor is invisible to those snapshots).
    68. Confirm
        `tests/testthat/_snaps/test-analysis-diffs.md` and
        `tests/testthat/_snaps/test-analysis-t-test.md` are byte-
        identical to their pre-PR state via `git diff`.
    69. Run `devtools::run_examples()` — confirm the `pool_pvals()`
        example runs without error in a fresh session.
    70. Run `pkgdown::build_site()` locally — confirm the new
        section renders and `pool_pvals` and
        `print.survey_pooled_pvals` reference pages build.
    71. Run `R CMD check --as-cran` (or the package CI equivalent) —
        confirm 0 errors, 0 warnings, ≤2 pre-approved notes.
    72. Run `covr::package_coverage()` on the changed files —
        confirm coverage ≥ 95% (target 98%).

  - **Acceptance criteria** — observable outcomes before merge

    *Mapping: each bullet below ties one or more test-spec rows or
    spec contract items to an observable post-merge state.*

    **Happy-path (covers test-spec §Happy path)**

    - `pool_pvals(named_list)` returns a tibble with
      `nrow == sum(input nrows)` and column union plus `source` and
      `p_value_adj`.
    - For every `m` in `stats::p.adjust.methods`, the round-trip
      oracle test passes: `result$p_value_adj` equals
      `stats::p.adjust(pooled_raw, m)` element-wise within `1e-12`.
    - For every `m` in `stats::p.adjust.methods`, the `m = 1`
      identity test passes (no warning emitted).
    - Unnamed list yields `source = c("1", "2", ...)`; mixed-named
      list interleaves names and indices verbatim.
    - Custom `p_col`, custom `new_col`, custom `id_col` all behave
      identically to defaults at the renamed positions.
    - Column ordering test passes: `names(result)` ends with
      `id_col`, `new_col`, and (when applicable)
      `paste0(new_col, "_within")`, prefix is input-union order.

    **S3 class & `.meta` (covers test-spec §S3 class and `.meta`)**

    - `inherits(result, "survey_pooled_pvals")` and
      `inherits(result, "tbl_df")` both `TRUE`.
    - `class(result)` exactly equals
      `c("survey_pooled_pvals", "tbl_df", "tbl", "data.frame")`.
    - `attr(result, ".meta")` is a list with the eight expected keys
      (`method`, `family_size`, `n_total`, `n_na`,
      `n_significant_05`, `id_col`, `p_col`, `new_col`); each value
      matches the spec.

    **Print method (covers test-spec §`print.survey_pooled_pvals`)**

    - Snapshot of the full print output for the representative
      3-element input is stable.
    - Header snapshot matches
      `<survey_pooled_pvals: method = "{m}", family_size = {N}, {K}
      significant at α = 0.05>`.
    - NA footer snapshot fires when `n_na > 0` and is absent when
      `n_na == 0`.
    - `expect_invisible(print(result))` passes.

    **Error paths (covers test-spec §Error paths — six classes,
    dual-pattern)**

    - `pool_pvals(NULL)`, `pool_pvals(c(0.01, 0.05))`, and
      `pool_pvals(tibble::tibble(p_value = 0.05))` all raise
      `surveycore_error_pool_pvals_not_list` with stable snapshot.
    - `pool_pvals(list())` raises
      `surveycore_error_pool_pvals_empty` with stable snapshot.
    - `method = "fancy"` and `method = c("BH", "holm")` raise
      `surveycore_error_pool_pvals_invalid_method` with stable
      snapshot.
    - List with one element omitting `p_value` raises
      `surveycore_error_pool_pvals_missing_pcol` (message names the
      offending element) with stable snapshot.
    - List with `p_value = 1.5` in one element raises
      `surveycore_error_pool_pvals_invalid_pvalues` (message lists
      offending row identifiers as `(source, within-source index)`)
      with stable snapshot.
    - List with one element pre-containing a `source` column raises
      `surveycore_error_pool_pvals_id_col_collision` *before* any
      bind work; stable snapshot.

    **Warning paths (covers test-spec §Warning paths)**

    - List with pre-existing `p_value_adj` and
      `strip_within_adj = FALSE` emits
      `surveycore_warning_pool_pvals_input_pre_adjusted`; output
      contains both `p_value_adj` and `p_value_adj_within`; NA
      padding correct for elements lacking the pre-existing column.
    - List with all-NA `p_value` emits
      `surveycore_warning_pool_pvals_no_pvalues_available`; output
      is still returned with all-NA `p_value_adj`.

    **Edge cases (covers test-spec §Edge cases)**

    - Single-element list returns input unchanged for every
      method, no warning.
    - Zero-row tibble in input contributes no rows.
    - Some-NA `p_col`: NA positions preserved; non-NA positions
      match `stats::p.adjust()` (which uses `n = sum(!is.na(p))`).
    - Heterogeneous columns: union present, NA-fill correct,
      ordering correct.
    - Heterogeneous types: bind coerces; result `p_value` numeric.
    - Attribute non-preservation: `variable_label` attribute on
      input `p_value` does not survive bind (matches
      `dplyr::bind_rows()` default).
    - `strip_within_adj = TRUE` with pre-existing `p_value_adj`:
      no warning; output has only `p_value_adj` (the pooled-
      adjusted one).
    - Custom `new_col = "fdr_q"` with pre-existing `fdr_q`,
      `strip_within_adj = FALSE`: output has `fdr_q` and
      `fdr_q_within`; warning fires.
    - `method = "none"`: `result$p_value_adj` equals raw `p_col`
      element-wise within `1e-12`.
    - Sequential `pool_pvals()` calls with different methods on the
      same input: outputs independent (no shared state).

    **Heterogeneous-column shape test**

    - The `get_diffs()`-shape vs `get_pairwise()`-shape pool test
      passes: output column union present; NA-fill correct on each
      side; ordering ends with `source` then `p_value_adj`.

    **Integration test**

    - `gss_2024` integration test passes: `pool_pvals()` over two
      `get_diffs()` results with `pval_adj = NULL` yields the same
      `p_value_adj` as direct `stats::p.adjust(c(r1$p_value,
      r2$p_value), "BH")` within `1e-12`; output inherits
      `survey_pooled_pvals`. Test is `skip_on_cran()`.

    **Refactor regression (covers test-spec §Refactor regression)**

    - `git diff` on `tests/testthat/_snaps/test-analysis-diffs.md`
      and `tests/testthat/_snaps/test-analysis-t-test.md` shows no
      changes after the refactor.
    - Existing tests for invalid `pval_adj` in `get_diffs()` and
      `get_pairwise()` still pass with class
      `surveycore_error_invalid_pval_adj`.

    **Profile gates (covers test-spec §Profile gates)**

    - [ ] `devtools::document()` clean
    - [ ] `devtools::test()` all pass
    - [ ] `devtools::run_examples()` all pass
    - [ ] `R CMD check --as-cran` — 0 err, 0 warn, ≤2 pre-approved
          notes
    - [ ] `pkgcheck` PASS
    - [ ] `pkgdown::build_site()` clean (new section renders,
          reference pages build)
    - [ ] `covr::package_coverage()` ≥ 95% (target 98%)
    - [ ] CRAN cookbook scan clean

## Sequencing notes

- Helpers are added before `pool_pvals()` so each downstream check
  test can be made green by a self-contained edit.
- `pool_pvals()` validation precedence (errors 1–10 in spec
  §Errors) is implemented in source-of-execution order so that each
  test in Phase 3 fails for the right reason at the right time.
- The refactor of `get_diffs()` / `get_pairwise()` (Phase 6) runs
  *after* `pool_pvals()` is fully implemented and tested, because
  the shared validator's behavior is exercised through `pool_pvals()`
  first; the refactor is purely a change-of-call-site.
- Roxygen and NAMESPACE regeneration (Phase 9) runs *after* all
  source code lands so a single `devtools::document()` invocation
  produces the final `.Rd` files and `NAMESPACE`.
- Final verification gates (Phase 10) run last and only after every
  prior phase is green.

## Dependencies

- No new package dependencies. Implementation uses `stats`, `dplyr`,
  `cli`, and `rlang` (all currently in `Imports`).
- `plans/error-messages.md` already contains rows PP-1 through PP-8
  (added in Stage 3r); this PR consumes them, does not modify them.
