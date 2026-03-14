## Spec Review: multi-stage — Pass 1 (2026-03-12)

### Prior Issues (methodology review)

All 14 issues from the methodology review (Pass 1 of `spec-methods-review-multi-stage.md`) are
resolved in v0.2. The spec correctly incorporates: the full-data cluster matrix strategy (Issue 1),
FPC fraction constant-within-parent validation (Issue 2), sampsize broadcast explanation (Issue 3),
estimand-agnostic framing (Issue 4), per-stage stratification exclusion (Issue 5), no-FPC
justification (Issue 6), partial-FPC citation and Inf semantics (Issues 7–8), internal
consistency assertion (Issue 9), design df section (Issue 10), lonely PSU specification
(Issue 11), CI approximation note (Issue 12), citation for parent-cluster-as-stratum (Issue 13),
FPC=1.0 edge case note (Issue 14).

---

### New Issues

#### Section: V — `.build_cluster_matrices()` Algorithm

---

**Issue 1: `c(psu_id, lapply(2:k, ...))` produces a list for k≥2 — `matrix()` call fails**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases correctly)

The spec §V Step 4 shows:

```r
clusters_mat <- matrix(
  data = c(psu_id, lapply(2:k, function(j) data[[vars$ids[[j]]]])),
  nrow = n,
  ncol = k
)
```

In R, `c(vector, list(vector))` produces a **list**, not a vector:

```r
> c(1:3, list(4:6))
[[1]]  [[2]]  [[3]]  [[4]]
1      2      3      4 5 6        # 4-element list, not 6-element vector
```

For k=2 with n=500, `c(psu_id, list(ssu_id))` produces a list of n+1 elements (n scalars + 1
vector). `matrix(data=list_of_n+1, nrow=n, ncol=2)` fails:

```
Error in matrix(...): 'data' is not an atomic vector
```

or fails with a dimension mismatch. The code is structurally correct only for k=1 because
`lapply(2:1, ...)` returns an empty list, and `c(vector, list())` preserves the vector.

**Same bug is present in the strata_mat construction:**
```r
strata_mat <- matrix(
  data = c(strata_id, lapply(2:k, function(j) clusters_mat[, j - 1L])),
  nrow = n, ncol = k
)
```
`clusters_mat[, j-1L]` is a vector; same `c(vector, list(vector))` issue.

**Fix:** Replace `lapply` with `unlist(lapply(...))` so that `c()` receives a plain vector:

```r
clusters_mat <- matrix(
  data = c(psu_id, unlist(lapply(2:k, function(j) data[[vars$ids[[j]]]]))),
  nrow = n, ncol = k
)

strata_mat <- matrix(
  data = c(strata_id, unlist(lapply(2:k, function(j) clusters_mat[, j - 1L]))),
  nrow = n, ncol = k
)
```

Or equivalently, using `do.call(cbind, ...)` which avoids the fill-by-column dependency:

```r
clusters_mat <- do.call(cbind, c(list(psu_id), lapply(2:k, function(j) data[[vars$ids[[j]]]])))
strata_mat   <- do.call(cbind, c(list(strata_id), lapply(2:k, function(j) clusters_mat[, j - 1L])))
```

Options:
- **[A]** Use `unlist(lapply(...))` in both `matrix()` calls. — Effort: minimal, Risk: low,
  Impact: algorithm works for k≥2, Maintenance: none
- **[B]** Use `do.call(cbind, ...)` pattern. — Effort: minimal, Risk: low, Impact: same,
  Maintenance: slightly clearer intent
- **[C] Do nothing** — the helper silently fails for every 2-stage or 3-stage design;
  all oracle tests will error.

**Recommendation: [A]** — minimal diff from current spec text; clearest connection to
existing pseudocode style.

---

**Issue 2: `keep` parameter is implemented, documented, and always called with `NULL` — API trap**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever); creates inconsistency across spec sections

The spec §V documents `keep` as "Row filter for na.rm paths" and implements it in Step 1:
```r
if (!is.null(keep)) {
  data <- data[keep, , drop = FALSE]
}
```

However, §VI (`.taylor_build_inputs()`) and §VII (all 6 analysis helpers) both pass `keep = NULL`.
The methodology review (Issue 1) established that physically filtering rows before building cluster
matrices produces **biased sampsize counts** — exactly the bug this parameter was designed to enable.

The `keep` parameter is simultaneously:
- Documented as a row-filter mechanism
- Implemented to filter rows (Step 1)
- Never called with a non-NULL value
- Wrong to use (per methodology review)

Any future developer who reads the signature, sees "Row filter for na.rm paths", and passes
`keep = !is.na(y)` will reintroduce the Stage-2 sampsize bias bug.

Options:
- **[A]** Remove `keep` from the signature and from the Step 1 algorithm. Both call sites
  already pass `NULL`; removing it makes the API honest. — Effort: minimal, Risk: none,
  Maintenance: eliminates an API trap
- **[B]** Keep `keep` but add a `# nocov` comment and warning that it produces biased
  sampsize when used. — Effort: low, Risk: medium (comment may be ignored), Maintenance: ongoing
- **[C] Do nothing** — the parameter exists, works as documented, and produces wrong results
  when a future developer uses it as intended.

**Recommendation: [A]** — a function parameter that is never used and produces wrong results
when used should not exist.

---

#### Section: II / VII — File Inventory and Analysis Helper Updates

---

**Issue 3: §II and §VII list 6 analysis helper files — 3 of them have no inline matrix-building pattern**
Severity: REQUIRED
Factual error in the spec; will cause implementer confusion and wasted effort

The spec §VII states: "Each of the following functions contains an identical inline
matrix-building block that must be replaced" and lists all 6 analysis helper files.

Actual state (verified by code inspection):

| File | Has inline matrix-building? | Actual path |
|------|---------------------------|-------------|
| `R/analysis-means-helpers.R` | ✅ Yes — `.taylor_mean_cell()` lines 95–114 | Direct refactor target |
| `R/analysis-freqs-helpers.R` | ✅ Yes — `.taylor_freq_cell()` lines 111–114 | Direct refactor target |
| `R/analysis-totals-helpers.R` | ✅ Yes — `.taylor_totals_cell()` lines 82–114 | Direct refactor target |
| `R/analysis-corr-helpers.R` | ❌ No | Delegates to `.vcov_pair_taylor()` (covered by §VIII) |
| `R/analysis-quantiles-helpers.R` | ❌ No | `.quantile_woodruff_cell()` delegates to `.mean_cell()` (covered by §VII means) |
| `R/analysis-ratios-helpers.R` | ❌ No | `.delta_ratio_cell()` delegates to `.total_cell()` (covered by §VII totals) |

`get_corr()`, `get_quantiles()`, and `get_ratios()` on Taylor designs automatically benefit from
the refactor through their delegation chains. The implementer cannot find the "identical inline
block" in these three files because it does not exist there.

The §II architecture table has the same error (lists all 6 analysis helper files as needing changes).

Options:
- **[A]** Update §II and §VII to list only the 3 files with direct inline patterns. Add a
  note explaining how corr/quantiles/ratios benefit indirectly. — Effort: low, Risk: none,
  Maintenance: none
- **[C] Do nothing** — implementer spends time searching for a pattern that isn't there;
  confusion, not error.

**Recommendation: [A]** — the spec should describe what actually exists in the codebase.

---

#### Section: II — Architecture (GLM Call Site)

---

**Issue 4: `glm.R` has an inline matrix-building block that is not listed in the file change inventory**
Severity: BLOCKING
Direct consequence of the `@variables$fpc` schema change; creates a runtime error for multi-stage GLM

The spec changes `@variables$fpc` from `character(1)|NULL` to `character(k)|NULL`. The spec
states: "Code that reads `data[[vars$fpc]]` is replaced in this phase by
`.build_cluster_matrices()`." The architecture table (§II) lists 8 call sites.

Code inspection of `R/glm.R` line 262:

```r
popsize_mat <- if (!is.null(vars$fpc)) {
  fpc_vals <- data[[vars$fpc]]    # ← NOT in the spec's list
  ...
}
```

When `vars$fpc = c("fpc1", "fpc2")` (multi-stage), `data[[c("fpc1","fpc2")]]` performs
recursive indexing (`data[["fpc1"]][["fpc2"]]`), producing an error:
> subscript out of bounds

Any user who creates a multi-stage Taylor design and calls `survey_glm()` will hit this
immediately. Phase 2 (GLM) is described as "concurrently in-flight" — this incompatibility
would break GLM on multi-stage designs as soon as GLM is merged.

Options:
- **[A]** Add `R/glm.R` to the §II file change inventory. Replace the inline block in `glm.R`
  with `.build_cluster_matrices()`. — Effort: low, Risk: low, Impact: GLM works on multi-stage
  designs, Maintenance: none
- **[B]** Add to §I "What this phase does NOT deliver": "Multi-stage support for `survey_glm()`".
  Add a runtime check in `glm.R` that emits `surveycore_error_multistage_glm_unsupported`
  when `length(vars$ids) > 1`. — Effort: low, Risk: low, Impact: explicit error instead of
  cryptic subscript error, Maintenance: temporary (until Phase 2.1 extends GLM)
- **[C] Do nothing** — GLM silently errors for multi-stage designs; no user-facing explanation.

**Recommendation: [B]** — The GLM multi-stage path is non-trivial (GLM uses a different
linearization approach). Explicitly scoping it out with a clear error is safer than
silently adding untested multi-stage GLM support in this phase.

---

#### Section: IV — FPC Validation

---

**Issue 5: `surveycore_error_fpc_smaller_than_n` — "sample size n" is ambiguous for multi-stage FPC columns**
Severity: REQUIRED
Violates contract completeness (Lens 3); edge case behavior underspecified

§IV Rule 4: "No population-size column has values smaller than the sample size — error
`surveycore_error_fpc_smaller_than_n`."

The existing validator was written for single-stage designs where "sample size" = number of
in-scope rows. For multi-stage FPC columns:

- **Stage-1 FPC** (population-size column): correct "n" = **number of PSUs sampled in the stratum**
  (e.g., 50 PSUs from a population of 500 PSUs). Using `nrow(data)` (e.g., 2000 records) would
  falsely pass a stage-1 FPC of 100, even though the stratum had 50 PSUs sampled from 100 PSUs
  total (where `fpc = 100 < 50_PSUs_sampled` is correct). Wait — the check is `fpc_popsize >=
  sample_size`, so the failure mode is different: if `nrow(data) = 2000` and `fpc1 = 100` (100
  PSUs in population), the check `100 < 2000` would incorrectly **reject** a valid FPC value.

- **Stage-2 FPC** (population-size column): correct "n" = **number of SSUs sampled in the PSU**.

The existing validator likely uses `nrow(data)` for "n". For multi-column FPC, this must be
the stage-j cluster count in the appropriate parent group — which differs per row.

The spec §IV says "each column is validated independently" but does not update Rule 4 to
clarify what "n" means for a multi-stage population-size column. An incorrect "n" will either
false-reject valid multi-stage FPC values or false-pass invalid ones.

Options:
- **[A]** Update §IV Rule 4 to specify: "For a population-size FPC column at stage j, the
  comparison is: `popsize_j ≥ n_j_per_parent` where `n_j_per_parent` is the count of stage-j
  clusters within each stage-(j-1) parent group (i.e., `sampsize_j_vec` from §V Step 6).
  Use the per-row comparison `data[[fpc_col_j]] >= sampsize_j_vec`."
  — Effort: low, Risk: low, Impact: correct validation for multi-stage FPCs
- **[C] Do nothing** — may falsely reject valid multi-stage FPC population-size columns;
  oracle tests would pass only because `make_survey_data()` generates safe values.

**Recommendation: [A]**

---

#### Section: XI — Testing Requirements

---

**Issue 6: Oracle tests missing for `get_corr()`, `get_quantiles()`, `get_ratios()` on 2-stage designs**
Severity: REQUIRED
Violates testing-standards.md §2 (Numerical oracle — required for every exported function)

The spec §VII states all 6 analysis functions are affected by the refactor. The oracle test table
in §XI only covers `get_means()`, `get_freqs()`, and `get_totals()`.

A regression in the delegation chain for `get_corr()` (via `.vcov_pair_taylor()`),
`get_quantiles()` (via `.mean_cell()`), or `get_ratios()` (via `.total_cell()`) on a 2-stage
design would go undetected. The only signal would be if an existing single-stage oracle test
broke — which provides no multi-stage coverage.

At minimum, one oracle comparison test per omitted function (2-stage, no FPC) is required:

```r
test_that("get_corr() matches survey::svycor() for 2-stage design [oracle]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
  sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
  # ...compare get_corr(sc, y1, y2) vs survey::svycor(...)
})
```

Options:
- **[A]** Add oracle tests for `get_corr()`, `get_quantiles()`, `get_ratios()` using 2-stage
  design, no FPC. — Effort: low, Risk: none, Impact: catches regressions in delegation chains,
  Maintenance: none
- **[C] Do nothing** — delegation-chain regressions go undetected; multi-stage corr/quantile/
  ratio SEs are untested.

**Recommendation: [A]**

---

**Issue 7: `surveycore_error_fpc_not_constant` (row 90) has no test in §XI**
Severity: REQUIRED
Violates testing-standards.md §2 (Error paths — every row in error table must be tested)

§X adds `surveycore_error_fpc_not_constant` as a new error class (row 90). §XI lists the
following FPC-related tests:
- "Partial FPC: verify `surveycore_inform_fpc_partial_stages` is emitted" ✅
- "Too many FPC columns → error `surveycore_error_fpc_too_many_stages`" ✅

But `surveycore_error_fpc_not_constant` — emitted when a sampling-fraction FPC column has
different values within the same stage-j parent group — is absent from §XI entirely. This
is a new error class that requires the dual-pattern test (class= + snapshot per
testing-surveycore.md Layer 3 rules).

Options:
- **[A]** Add to §XI error-path tests:
  ```r
  test_that("as_survey() rejects non-constant stage-1 FPC fraction [error]", {
    df <- make_survey_data(n = 200, n_psu = 10, n_ssu = 5, seed = 1)
    # Assign different FPC fractions within the same PSU for stage-2 FPC
    df$fpc2_bad <- runif(nrow(df), 0.1, 0.9)  # varies within PSU
    expect_error(
      as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)),
      class = "surveycore_error_fpc_not_constant"
    )
    expect_snapshot(error = TRUE,
      as_survey(df, ids = c(psu, ssu), weights = wt, fpc = c(fpc, fpc2_bad)))
  })
  ```
  — Effort: low, Maintenance: none
- **[C] Do nothing** — new error class is untested; the dual-pattern rule is violated.

**Recommendation: [A]**

---

**Issue 8: Inform-level message testing not specified for `surveycore_inform_fpc_partial_stages`**
Severity: REQUIRED
Violates testing-standards.md §3 (assertion patterns) — `expect_warning()` cannot capture inform messages

§XI says: "Verify `surveycore_inform_fpc_partial_stages` is emitted." The spec does not specify
how to test this. `cli::cli_inform()` produces a message (not a warning), so:

- `expect_warning(class=)` will NOT capture it
- `expect_message(class=)` IS the correct pattern for `cli_inform()` conditions

The spec must specify the test pattern explicitly. A developer following the existing
`expect_warning()` pattern from error tests will write a test that always passes (since no
warning is emitted) and falsely conclude the inform fires correctly.

Options:
- **[A]** Update §XI to show:
  ```r
  test_that("as_survey() informs for partial FPC (stage-1 only with 2-stage ids)", {
    df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
    expect_message(
      as_survey(df, ids = c(psu, ssu), weights = wt, fpc = fpc),
      class = "surveycore_inform_fpc_partial_stages"
    )
  })
  ```
  — Effort: low, Maintenance: none
- **[C] Do nothing** — the test pattern is undefined; a developer may write a test that
  always passes regardless of whether the inform fires.

**Recommendation: [A]**

---

**Issue 9: `test_invariants()` absent from the oracle test examples in §XI**
Severity: REQUIRED
Violates testing-surveycore.md: "`test_invariants()` required as first assertion in every constructor test block"

The example test code in §XI (oracle tests) creates `survey_taylor` objects via `as_survey()`:

```r
df <- make_survey_data(n = 500, n_psu = 50, n_ssu = 10, seed = 42)
sc <- as_survey(df, ids = c(psu, ssu), weights = wt, strata = strata)
```

None of the §XI example blocks include `test_invariants(sc)` as the first assertion.
`testing-surveycore.md` is unambiguous: every block that creates a design object must
call `test_invariants()` first.

Options:
- **[A]** Add `test_invariants(sc)` as the first line after `sc <- as_survey(...)` in every
  §XI code example. — Effort: minimal, Maintenance: none
- **[C] Do nothing** — implementer creates tests without the mandatory invariant check;
  structural issues in multi-stage objects go undetected.

**Recommendation: [A]**

---

#### Section: XI — Edge Cases (Additional)

---

**Issue 10: `fpc_smaller_than_n` for per-column validation not tested**
Severity: SUGGESTION
Test completeness gap for a modified validation path

§IV adds per-column FPC validation for multi-stage columns. All 5 rules are listed. The §XI
test table includes tests for `fpc_too_many_stages` and `fpc_partial_stages`, but does not
include an explicit test for per-column validation errors on stage-2 FPC columns:
- `fpc_na` in a stage-2 column (not just stage-1)
- `fpc_nonpositive` in a stage-2 column
- `fpc_smaller_than_n` for stage-2 column

The existing single-stage error path tests will not exercise the new per-column loop.

Options:
- **[A]** Add one test per new validation path for multi-column FPC (stage-2 column NA,
  stage-2 nonpositive, stage-2 fpc_smaller_than_n). — Effort: low, Maintenance: none
- **[C] Do nothing** — per-column validation for stage-2+ FPC goes untested; the loop
  only exercises column 1 paths in existing tests.

**Recommendation: [A]**

---

**Issue 11: Grouped analysis test missing for 2-stage designs**
Severity: SUGGESTION
Test completeness (category 3 — Grouped analysis — not covered for multi-stage)

§XI oracle tests cover: basic 2-stage estimates, FPC variants, `get_freqs()`, `get_totals()`,
3-stage. None include a `group` argument. The `group` path goes through the same cell estimators,
but a grouping bug introduced during the refactor (e.g., `mats` built outside the group loop,
groups losing domain indicator interaction) would not be caught.

Options:
- **[A]** Add one test: `get_means(sc_2stage, y1, group = strata)` vs.
  `survey::svyby(~y1, ~strata, sv_2stage, svymean)`. — Effort: low, Maintenance: none
- **[C] Do nothing** — grouped 2-stage estimates go untested; a grouping-loop regression is
  not caught by any oracle test.

**Recommendation: [A]**

---

#### Section: IX — Print Output for Multi-Stage Designs

---

**Issue 12: `print()` output for multi-stage designs is unspecified**
Severity: SUGGESTION
Missing from §II file inventory; print behavior is underspecified

The current `print.survey_taylor` implementation does:
```r
fpc_var <- x@variables$fpc
if (!is.null(fpc_var)) {
  cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}}"))
}
```

For `fpc_var = c("fpc1", "fpc2")`, cli formats both column names inline:
`FPC: fpc1 fpc2` (or similar). This is cosmetically odd and doesn't convey
"stage-1 FPC column: fpc1; stage-2 FPC column: fpc2."

Similarly, the multi-column `ids` display already works (it shows all ID columns), so this
is a display quality issue rather than a correctness issue. But the spec is silent on whether
the print output should change for multi-stage designs.

Options:
- **[A]** Add to §II a note: "No print method changes in this phase; multi-column FPC
  displays as `FPC: fpc1 fpc2` (acceptable for now; a cleaner per-stage display is deferred)."
  — Effort: minimal
- **[B]** Update `methods-print.R` to show per-stage FPC: `FPC (stage 1): fpc1  FPC (stage 2): fpc2`.
  — Effort: medium
- **[C] Do nothing** — print output is implicitly unchanged; the gap is minor.

**Recommendation: [A]** — An explicit note clarifies this is a deliberate deferral, not
an oversight.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total issues:** 12

| # | Title | Section | Severity |
|---|---|---|---|
| 1 | `c(psu_id, lapply(...))` produces list for k≥2 — matrix construction fails | §V | BLOCKING |
| 2 | `keep` parameter: implemented, documented, always NULL, produces wrong results when used | §V | REQUIRED |
| 3 | §II/§VII file inventory: 3 of 6 analysis helper files have no inline pattern | §II/§VII | REQUIRED |
| 4 | `glm.R` inline FPC access not listed as a call site — errors for multi-stage GLM | §II | BLOCKING |
| 5 | `fpc_smaller_than_n` "n" is ambiguous for multi-stage cluster-level FPC columns | §IV | REQUIRED |
| 6 | Oracle tests missing for `get_corr()`, `get_quantiles()`, `get_ratios()` | §XI | REQUIRED |
| 7 | `surveycore_error_fpc_not_constant` has no test | §XI | REQUIRED |
| 8 | Inform-level message testing pattern not specified (`expect_message()` vs `expect_warning()`) | §XI | REQUIRED |
| 9 | `test_invariants()` absent from oracle test examples | §XI | REQUIRED |
| 10 | Per-column FPC validation (stage-2) not tested | §XI | SUGGESTION |
| 11 | Grouped analysis test missing for 2-stage designs | §XI | SUGGESTION |
| 12 | `print()` output for multi-stage designs unspecified | §IX | SUGGESTION |

**Overall assessment:** The spec has correct statistical foundations and all methodology issues
from Pass 1 are resolved. However, two blocking issues prevent implementation: the core matrix
construction algorithm uses `c(vector, lapply(...))` which produces a list for k≥2, causing
`matrix()` to fail for every multi-stage design; and `glm.R` has an undocumented inline FPC
access that will error on multi-stage designs. The REQUIRED issues are primarily test coverage
gaps and one contract ambiguity (`fpc_smaller_than_n` semantics). Neither blocking issue
requires architectural rethinking — both have minimal, localized fixes. Resolve Issues 1 and
4 first, then the REQUIRED set, before handing off to `/implementation-workflow`.
