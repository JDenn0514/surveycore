# Implementation plan — nonprob-jackknife

## PR map

- [ ] PR 1: `feature/nonprob-jackknife-core` — Scale helper + type validation + rscales guard
- [ ] PR 2: `feature/nonprob-jackknife-display` — Calibration conditional + print/summary display *(depends on PR 1)*
- [ ] PR 3: `feature/nonprob-jackknife-analysis` — Analysis helpers + roxygen docs + dispatch + verification *(depends on PR 2)*

---

## PR 1: `feature/nonprob-jackknife-core`

Scale helper + type validation + rscales guard (~12 tasks)

**Depends on**: none (first PR in the chain)

### Tasks (2–5 min each, TDD sub-steps explicit)

#### Gate 0 — pre-implementation (must be the FIRST commit; no `.R` source touched yet)

1. Open `plans/error-messages.md`. In the nonprob-jackknife section (lines
   310–324), confirm that NB-1 has been updated to
   `surveycore_error_type_unsupported_for_nonprob`, NB-3 message text reads
   "Replicate variance requires", NB-9 (`surveycore_error_stratified_jk_rscales_unset`)
   is present, and NB-10 (`surveycore_error_scale_negative`) is present.
   These rows were added during spec review; verify the file already reflects
   the final state. If any row is missing or stale, update it now.
   Commit: `docs(plans): finalize error-messages.md for nonprob-jackknife gate`.

   **Commit this change alone before starting any `.R` source changes. Do not
   proceed to Task 2 until this commit is made.**

#### Task group 1 — `.compute_nonprob_scale()` helper (`R/utils.R`)

2. **Write failing test** — in `tests/testthat/test-utils.R`, add a
   `test_that()` block: "`.compute_nonprob_scale()` returns correct default
   for each type". Assert:
   - `bootstrap` with R = 5 → `1 / 5`
   - `JK1` with R = 4 → `3 / 4`
   - `JK2` with R = 10 → `1`
   - `JKn` with R = 10 → `1`
   Run tests; confirm the block fails (function does not exist).

3. **Implement** — add `.compute_nonprob_scale(type, R)` to `R/utils.R`
   using `switch()` on `type` with arms `bootstrap`, `JK1`, `JK2`, `JKn`.
   No export, no roxygen `@export`. Function is not exported.

4. **Verify** — run the new `test-utils.R` block; confirm it passes with
   zero warnings.

#### Task group 2 — type validation in `as_survey_nonprob()` (error paths first)

5. **Write failing tests (NB-1 error class)** — in
   `tests/testthat/test-constructors.R`, add one `test_that()` block for
   each unsupported type that must raise
   `surveycore_error_type_unsupported_for_nonprob`:
   - `type = "BRR"` — dual pattern (`expect_error(class=)` + `expect_snapshot`).
   - `type = "Fay"` — dual pattern (separate snapshot to pin `{type}` interpolation).
   - `type = "bootstrap2"` — dual pattern (near-miss misspelling).
   - `type = c("JK1", "JK2")` — vector input, dual pattern.
   - `type = NA_character_` — dual pattern.
   - `type = "jk1"` — lowercase, dual pattern (case-sensitivity guard).
   - `type = 1` (numeric) — `expect_error(class=)` only (no snapshot needed;
     edge-case numeric input).
   Run; all blocks fail (existing code raises `surveycore_error_type_invalid`
   or a different class).

6. **Write failing test (NB-3 message text)** — add a `test_that()` block:
   "`surveycore_error_repweights_single` message is type-agnostic". Call
   `as_survey_nonprob()` with `type = "JK1"` and 1 replicate column; also
   with `type = "bootstrap"` and 1 replicate column. For each:
   - `expect_error(class = "surveycore_error_repweights_single")`
   - `expect_snapshot(error = TRUE, ...)` — snapshot must read "Replicate
     variance requires >= 2 replicates", not "Bootstrap variance requires".
   Run; snapshot tests fail because the current message says "Bootstrap".

7. **Implement type normalization and type validation block** — in
   `R/core-constructors.R`, within `as_survey_nonprob()`, replace the
   existing `if (!identical(type, "bootstrap"))` block (line ~1299) with
   the two-step sequence from the spec:
   - Step 8: `if (type == "jackknife") type <- "JK1"`.
   - Step 9: validate `type %in% c("bootstrap", "JK1", "JK2", "JKn")`;
     if not, raise `surveycore_error_type_unsupported_for_nonprob` with the
     NB-1 message template.
   Also update the `"i"` bullet in the `surveycore_error_repweights_single`
   block (line ~1277) from "Bootstrap variance requires" to "Replicate
   variance requires".

8. **Verify** — run the blocks written in tasks 5 and 6. All must pass.
   Run the full existing constructor test suite; no regressions.

#### Task group 3 — JK2/JKn rscales guard and scale computation

9. **Write failing tests (NB-9 and NB-10)** — add `test_that()` blocks:
   - "`surveycore_error_stratified_jk_rscales_unset` fires for JK2 with
     rscales = NULL" — dual pattern.
   - "`surveycore_error_stratified_jk_rscales_unset` fires for JKn with
     rscales = NULL" — dual pattern (separate snapshot for `{type}`
     interpolation).
   - "`surveycore_error_scale_negative` fires for explicit negative scale
     with JK1" — dual pattern (test `scale = -0.5` and `scale = -1e-10`
     in the same block).
   Run; all fail.

10. **Write failing tests (scale defaults and rscales defaults)** — add
    `test_that()` blocks for the happy paths that are not yet passing:
    - "JK1 type stored and scale defaults to (R-1)/R": 4 replicates →
      `scale == 0.75`, `rscales == rep(1, 4)`.
    - "jackknife alias normalizes to JK1": 3 replicates → `type == "JK1"`,
      `scale == 2/3`.
    - "JK2 with explicit rscales: scale defaults to 1".
    - "JKn with explicit rscales: type stored, scale defaults to 1".
    - "Bootstrap unchanged: scale = 1/R, rscales = rep(1, R)".
    - "Explicit scale overrides default for JK1".
    - "scale = 0 accepted".
    Run; blocks fail (the normalization or `.compute_nonprob_scale()` call
    is not yet wired).

11. **Implement steps 10–12 of the decision tree** — in
    `R/core-constructors.R`, after the type-validation block:
    - Add `.is_stratified_jk(type)` inline helper: `type %in% c("JK2", "JKn")`.
      **Note**: inline in `R/core-constructors.R` per code-style rule (used in
      only 1 file). Not exported. No separate test needed; covered by the
      JK2/JKn rscales-guard tests in task 9.
    - Step 10: `if (.is_stratified_jk(type) && is.null(rscales))` →
      raise `surveycore_error_stratified_jk_rscales_unset`.
    - Step 11: replace the hardcoded `scale <- if (is.null(scale)) 1 / R else scale`
      with:
      ```r
      if (is.null(scale)) {
        scale <- .compute_nonprob_scale(type, R)
      } else if (scale < 0) {
        # raise surveycore_error_scale_negative
      }
      ```
    - Step 12: `if (is.null(rscales)) rscales <- rep(1, R)`.

12. **Verify** — run all blocks written in tasks 9 and 10. All must pass.
    Run the full existing constructor test suite; no regressions.

### Acceptance criteria — observable outcomes before merge

1. `test_that("`.compute_nonprob_scale()` returns correct default for each type")` passes.
2. All six `surveycore_error_type_unsupported_for_nonprob` dual-pattern blocks pass (BRR, Fay, bootstrap2, vector input, NA, jk1 lowercase).
3. `surveycore_error_repweights_single` dual-pattern blocks for JK1 and bootstrap both pass; snapshot text reads "Replicate variance requires >= 2 replicates".
4. `surveycore_error_stratified_jk_rscales_unset` dual-pattern blocks pass for JK2 and JKn.
5. `surveycore_error_scale_negative` dual-pattern block passes for `scale = -0.5` and `scale = -1e-10`.
6. JK1 happy-path block: `design@variables$type == "JK1"`, `design@variables$scale == 0.75` (R = 4), `design@variables$rscales == rep(1, 4)`.
7. jackknife alias block: `design@variables$type == "JK1"` (never `"jackknife"`), `design@variables$scale == 2/3` (R = 3).
8. JK2 block: `design@variables$scale == 1`, `design@variables$rscales` equals supplied vector.
9. JKn block: `design@variables$type == "JKn"`, `design@variables$scale == 1`.
10. Bootstrap block: `design@variables$type == "bootstrap"`, `design@variables$scale == 1/5` (R = 5). Existing bootstrap tests unchanged.
11. `devtools::check()` produces 0 errors, 0 warnings.

### Files touched

| File | Change |
|------|--------|
| `plans/error-messages.md` | Gate 0: verify/finalize NB-1, NB-3, NB-9, NB-10 (already updated during spec review; confirm in gate commit) |
| `R/utils.R` | Add `.compute_nonprob_scale(type, R)` |
| `R/core-constructors.R` | NB-3 message text update; type normalization (step 8); type validation (step 9, NB-1); `.is_stratified_jk()` inline helper; rscales guard (step 10, NB-9); scale computation via `.compute_nonprob_scale()` (step 11, NB-10); rscales default (step 12) |
| `tests/testthat/test-utils.R` | New block for `.compute_nonprob_scale()` |
| `tests/testthat/test-constructors.R` | New blocks: NB-1 error variants, NB-3 message text, NB-9, NB-10, happy-path scale/rscales defaults |
| `tests/testthat/_snaps/` | New snapshot files created by `testthat::snapshot_review()` after test runs (constructor snapshots only) |

**Pipeline split**: recommended

---

## PR 2: `feature/nonprob-jackknife-display`

Calibration conditional + print/summary display (~9 tasks)

**Depends on**: PR 1 merged first.

### Tasks (2–5 min each, TDD sub-steps explicit)

#### Task group 4 — calibration conditional (jackknife bypass for bootstrap check)

13. **Write failing tests** — add `test_that()` blocks:
    - "JK1 with calibration having only R field: no error" — assert
      `as_survey_nonprob(df, weights = wt, repweights = ..., type = "JK1",
      calibration = list(R = 4L))` constructs without error.
    - "JK1 with calibration having bootstrap = FALSE: no error" — assert
      `calibration = list(bootstrap = FALSE, R = 4L)` is accepted for JK1.
    - "JK1 with calibration having bootstrap = TRUE: no error" — assert
      `calibration = list(bootstrap = TRUE, R = 4L)` is accepted for JK1
      (bootstrap field is type-gated).
    - "`surveycore_error_provenance_not_bootstrap` still fires for bootstrap
      type with calibration$bootstrap = FALSE" — dual pattern (regression
      guard: NB-6 behavior must be preserved; must not be silenced by the
      calibration-conditional change).
    - "`surveycore_error_provenance_R_mismatch` fires for JK1 with mismatched
      calibration$R" — dual pattern (regression guard: NB-7 behavior must
      fire for jackknife types, not be silenced by the calibration-conditional
      change; 3 repweights columns, `calibration$R = 5L`).
    - "`calibration = list()` with type = 'bootstrap' raises
      `surveycore_error_provenance_not_bootstrap`" — dual pattern.
    - "`calibration = list()` with type = 'JK1' accepted" — assert no error.
    Run; the "no error" JK1 blocks fail (current code unconditionally checks
    `calibration$bootstrap`).

14. **Implement calibration conditional** — in `R/core-constructors.R`,
    replace the existing unconditional `if (!isTRUE(calibration$bootstrap))`
    block (line ~1332) with the gated structure from the spec:
    ```r
    if (!is.null(calibration)) {
      if (type == "bootstrap") {
        if (!isTRUE(calibration$bootstrap)) { ... NB-6 ... }
      }
      if (!is.null(calibration$R) && calibration$R != R) { ... NB-7 ... }
    }
    ```

15. **Verify** — run all blocks from task 13. All must pass. Run the full
    constructor test suite; no regressions.

#### Task group 5 — constructor edge-case tests

16. **Write and verify remaining constructor edge-case tests** — add
    `test_that()` blocks for edge cases that are now implementable:
    - "zero-row data raises `surveycore_error_empty_data`" — dual pattern.
    - "single-row data constructs valid JK1 object with `test_invariants()`".
    - "JK1 with one zero-valued rscale entry accepted" — `rscales = c(1, 0, 1, 1)`.
    - "`type = 'jackknife'` not stored: `design@variables$type == 'JK1'`".
    - "jackknife alias with explicit non-uniform rscales" — type normalizes
      before rscales accepted.
    - "JK1 scale exact value for R = 10: `9/10` exactly".
    - "JK2 default scale = 1 exactly".
    - "JKn default scale = 1 exactly".
    - "repweights = NULL ignores type = 'BRR'" — no error; all rep vars NULL.
    - "repweights = NULL ignores type = 'jackknife'" — no error; `type == NULL`.
    - "`surveycore_error_rscales_length` fires for wrong-length rscales with
      JK1" — dual pattern (rscales of length 2 for 4 replicates).
    - "`surveycore_error_rscales_na` fires for NA in rscales with JK1" —
      dual pattern.
    - "`surveycore_error_reference_sample_nonprob` fires for non-taylor
      reference_sample with JK1" — dual pattern.
    Run all; verify pass.

#### Task group 6 — print and summary methods (`R/methods-print.R`)

17. **Write failing tests for `print.survey_nonprob`** — in
    `tests/testthat/test-methods-print.R`, add `test_that()` blocks:
    - "JK1 header contains 'JK1' and not 'BOOTSTRAP'":
      `expect_output(print(jk1_design), "JK1")` +
      `expect_false(grepl("BOOTSTRAP", capture.output(print(jk1_design))))`.
    - "JK2 header contains 'JK2'".
    - "JKn header contains 'JKN' (uppercased)".
    - "Bootstrap header still contains 'BOOTSTRAP'" (regression guard).
    - "SRS-mode header contains 'non-probability' but not 'JK' or 'BOOTSTRAP'".
    - "return value is the input object, invisibly" — `expect_identical(print(d), d)`.
    - `expect_snapshot(print(jk1_design))` — snapshot JK1 full output.
    - `expect_snapshot(print(jk2_design))`.
    - `expect_snapshot(print(jkn_design))`.
    - `expect_snapshot(print(bootstrap_design))` (regression snapshot).
    Each block must call `test_invariants(design)` before assertions.
    Run; header-content blocks fail because the header hard-codes `"BOOTSTRAP"`.

18. **Implement `print.survey_nonprob` header change** — in
    `R/methods-print.R`, in the `S7::method(print, survey_nonprob)`
    function, locate the header-line string for the repweights branch.
    Replace the hard-coded `"BOOTSTRAP"` with `toupper(x@variables$type)`.
    No other changes to the print method body.

19. **Verify** — run all `print` blocks from task 17. Approve new snapshots
    via `testthat::snapshot_review()`. Confirm bootstrap snapshot matches
    its previous output.

20. **Write failing tests for `summary.survey_nonprob`** — add `test_that()`
    blocks in `test-methods-print.R`:
    - "JK1 summary type line contains 'JK1'":
      `expect_output(capture.output(summary(jk1_design)), "JK1")`.
    - "JKn summary type line contains 'JKN' (uppercased)".
    - "Bootstrap summary type line contains 'BOOTSTRAP'" (regression guard).
    - "SRS summary type line does not contain 'JK' or 'BOOTSTRAP'".
    - `expect_snapshot(summary(jk1_design))`.
    - `expect_snapshot(summary(jk2_design))`.
    - `expect_snapshot(summary(jkn_design))`.
    Run; blocks fail (summary currently always prints the non-replicate form
    or does not branch on type).

21. **Implement `summary.survey_nonprob` type line** — in `R/methods-print.R`,
    in `S7::method(summary, survey_nonprob)`, branch on
    `!is.null(object@variables$repweights)`. In the repweights branch,
    output `"Type: non-probability, {toupper(object@variables$type)} replicates [experimental]"`.
    The null branch outputs the existing `"Type: non-probability [experimental]"`.

22. **Verify** — run all summary blocks from task 20. Approve new snapshots.
    Confirm bootstrap summary snapshot is unchanged relative to the
    pre-PR baseline.

### Acceptance criteria — observable outcomes before merge

1. Calibration blocks: JK1 with `calibration = list(R = 4L)` and `calibration = list(bootstrap = FALSE)` construct without error; `calibration = list()` with JK1 constructs without error.
2. `surveycore_error_provenance_not_bootstrap` (NB-6) dual-pattern block passes for bootstrap + `calibration$bootstrap = FALSE`: this regression guard must still fire and must not be silenced by the calibration-conditional change.
3. `surveycore_error_provenance_R_mismatch` (NB-7) dual-pattern block passes for JK1 with mismatched `calibration$R`: this regression guard must still fire for jackknife types and must not be silenced by the calibration-conditional change.
4. `calibration = list()` + `type = "bootstrap"` still raises `surveycore_error_provenance_not_bootstrap`.
5. All constructor edge-case blocks from task group 5 pass.
6. `print(jk1_design)` output contains `"JK1"` and does not contain `"BOOTSTRAP"`.
7. `print(jk2_design)` output contains `"JK2"`.
8. `print(jkn_design)` output contains `"JKN"`.
9. Bootstrap print snapshot is unchanged from pre-PR baseline.
10. `summary(jk1_design)` output contains `"JK1 replicates"`.
11. `summary(jkn_design)` output contains `"JKN replicates"`.
12. Bootstrap summary snapshot is unchanged from pre-PR baseline.
13. `devtools::check()` produces 0 errors, 0 warnings.

### Files touched

| File | Change |
|------|--------|
| `R/core-constructors.R` | Calibration conditional block only (calibration provenance gating) |
| `R/methods-print.R` | `print.survey_nonprob` header: `toupper(x@variables$type)` instead of hard-coded `"BOOTSTRAP"`; `summary.survey_nonprob` type line branching |
| `tests/testthat/test-constructors.R` | New blocks: calibration happy paths, NB-6/NB-7 regression guards, edge-case tests |
| `tests/testthat/test-methods-print.R` | New blocks: print and summary for JK1, JK2, JKn, bootstrap regression guards |
| `tests/testthat/_snaps/` | New snapshot files created by `testthat::snapshot_review()` after test runs (print/summary snapshots) |

**Pipeline split**: recommended

---

## PR 3: `feature/nonprob-jackknife-analysis`

Analysis helpers + roxygen docs + dispatch + verification (~16 tasks)

**Depends on**: PR 2 merged first.

### Tasks (2–5 min each, TDD sub-steps explicit)

#### Task group 7 — `.nonprob_rep_na_warn()` message text (`R/analysis-helpers.R`)

23. **Write failing test** — in `tests/testthat/test-analysis-helpers.R`
    (or the appropriate test file for `analysis-helpers.R`), add a block:
    "`.nonprob_rep_na_warn()` domain-NA warning does not say 'bootstrap'
    for JK1 design". Construct a JK1 nonprob design (20 replicates, n = 50)
    where one domain has 2 of 20 replicates with no observations (10% NA
    rate, above the 5% threshold). Call `get_means(design, y, group = grp)`.
    Assert:
    - `surveycore_warning_domain_replicates_na` fires.
    - Snapshot the warning message; it must not contain the word `"bootstrap"`.
    Run; the snapshot block fails because the current message says
    "bootstrap replicates".

24. **Write additional warning-threshold test** — add a block: "domain-NA
    warning does NOT fire at exactly 5% NA rate (boundary)". Construct JK1
    with 20 replicates and 1 NA replicate in one domain (5% — not above
    threshold). Assert no warning fires (`expect_no_warning()`).

25. **Implement message text change** — in `R/analysis-helpers.R`, locate
    `.nonprob_rep_na_warn()`. In the `"!"` bullet, change the word
    `"Bootstrap"` (or `"bootstrap"`) in the phrase "Bootstrap replicates"
    to `"Replicates"` (or `"Replicates"`). The class
    `surveycore_warning_domain_replicates_na` is unchanged.

26. **Verify** — run tasks 23 and 24. Approve updated snapshot. Confirm the
    warning class has not changed.

#### Task group 8 — roxygen documentation (`R/core-classes.R`, `R/core-constructors.R`)

27. **Update `survey_nonprob` `@section Design variables`** — in
    `R/core-classes.R`, locate the roxygen `@section Design variables` block
    for `survey_nonprob`. Add `"JK1"`, `"JK2"`, `"JKn"`, and `"jackknife"`
    to the documented valid `type` values. No validator changes, no property
    changes — roxygen only.

28. **Update `as_survey_nonprob()` `@param type`** — in
    `R/core-constructors.R`, replace the existing `@param type` line(s)
    with the `\describe{\item{...}}` block from the spec (the five-item list
    covering `"bootstrap"`, `"JK1"`, `"jackknife"`, `"JK2"`, `"JKn"`).

29. **Regenerate documentation** — run `devtools::document()`. Confirm
    `man/as_survey_nonprob.Rd` and `man/survey_nonprob.Rd` are updated.
    Confirm NAMESPACE is unchanged (no new exports). Stage the updated
    `.Rd` files.

#### Task group 9 — analysis dispatch and numerical parity tests

30. **Write dispatch happy-path tests** — in a relevant analysis test file
    (e.g., `test-analysis-means.R` or a new `test-analysis-helpers.R`
    section), add `test_that()` blocks:
    - "`get_means()` on JK1 nonprob: no error, returns tibble with finite
      positive se".
    - "`get_totals()` on JK1 nonprob: no error, returns tibble with finite
      positive se".
    - "`get_freqs()` on JK1 nonprob with factor column: no error".
    - "`get_means()` on JK2 nonprob with explicit rscales: no error".
    Run; these should pass without any additional implementation (the variance
    engine is unchanged). If any fail, investigate the dispatch path — no
    engine change is needed.

31. **Write edge-case dispatch tests** — add `test_that()` blocks:
    - "Category 6 — all-NA outcome for JK1 nonprob: no error, mean is NA".
    - "Category 7 — single-level grouping for JK1 nonprob: no error".
    - "Category 8 — zero-weight domain for JK1 nonprob: no error".
    - "SRS fallback warning still fires for JK1 nonprob without replicates"
      — `surveycore_warning_nonprob_srs_fallback` (regression guard).
    Run; verify all pass.

32. **Write numerical parity tests** — add a `test_that()` block with
    `skip_if_not_installed("survey")` at block level. Construct inline data:
    n = 100, R = 20, `set.seed(42)`, delete-one JK1 replicates (full-sample
    weight × n / (n - 1) for included units; 0 for omitted unit). Build
    surveycore JK1 nonprob design and `survey::svrepdesign(type = "JK1",
    combined.weights = TRUE)` from same data.
    - "`get_means()` SE matches `survey::svymean()` SE within 1e-8".
    - "`get_means()` point estimate matches within 1e-10".
    - "`get_totals()` SE matches `survey::svytotal()` SE within 1e-8".
    - "`get_totals()` point estimate matches within 1e-10".
    Run; verify passes.

33. **Write bootstrap regression guard** — add a `test_that()` block:
    "bootstrap SE is unchanged by this PR". Construct a bootstrap nonprob
    design from the same inline data. Call `get_means()`. Snapshot the
    SE value. This confirms no regression in the bootstrap path.

#### Task group 10 — final verification

34. **Run full test suite** — `devtools::test()`. Zero failures. Approve any
    new snapshots via `testthat::snapshot_review()` (do not blindly accept
    all; review each diff).

35. **Run `devtools::check()`** — confirm 0 errors, 0 warnings, notes
    reviewed (pre-approved notes only).

36. **Run `devtools::run_examples()`** — confirm all examples execute
    without error.

37. **Coverage check** — `covr::package_coverage()` >= 95% (pipeline gate);
    target 98%. If any new branch is uncovered, add a targeted test or
    document the exclusion with `# nocov` + explanatory comment.

38. **Run `pkgdown::build_site()`** — confirm no build errors.

### Acceptance criteria — observable outcomes before merge

1. Domain-NA warning message for JK1 does not contain the word "bootstrap".
2. Domain-NA warning threshold test: no warning at 5% (1/20) NA rate.
3. Warning class `surveycore_warning_domain_replicates_na` is unchanged.
4. `devtools::document()` produces no errors; `man/as_survey_nonprob.Rd` and `man/survey_nonprob.Rd` are regenerated with updated content.
5. `get_means()` on JK1 nonprob: no error, returns tibble with finite positive se.
6. `get_totals()` on JK1 nonprob: no error, returns tibble with finite positive se.
7. `get_freqs()` on JK1 nonprob with factor column: no error.
8. `get_means()` on JK2 nonprob with explicit rscales: no error.
9. All-NA outcome for JK1 nonprob: no error, mean is NA.
10. Single-level grouping for JK1 nonprob: no error.
11. Zero-weight domain for JK1 nonprob: no error.
12. SRS fallback warning `surveycore_warning_nonprob_srs_fallback` still fires for JK1 nonprob without replicates (regression guard).
13. JK1 numerical parity: `get_means()` SE matches `survey::svymean()` SE within `1e-8`; point estimate within `1e-10`.
14. JK1 numerical parity: `get_totals()` SE matches `survey::svytotal()` SE within `1e-8`; point estimate within `1e-10`.
15. Bootstrap SE snapshot (regression guard) is unchanged.
16. `devtools::check()` produces 0 errors, 0 warnings.
17. `covr::package_coverage()` >= 95% (pipeline gate); target 98%.

### Files touched

| File | Change |
|------|--------|
| `R/analysis-helpers.R` | `.nonprob_rep_na_warn()` `"!"` bullet: "Replicates" in place of "Bootstrap replicates" |
| `R/core-classes.R` | `survey_nonprob` `@section Design variables` roxygen only |
| `R/core-constructors.R` | `@param type` roxygen only |
| `man/as_survey_nonprob.Rd` | Regenerated via `devtools::document()` |
| `man/survey_nonprob.Rd` | Regenerated via `devtools::document()` |
| `tests/testthat/test-analysis-helpers.R` | New blocks: `.nonprob_rep_na_warn()` message text, threshold boundary |
| `tests/testthat/_snaps/` | New snapshot files created by `testthat::snapshot_review()` after test runs (warning snapshots only) |

**Pipeline split**: recommended
