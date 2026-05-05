## Spec Review: effective-n — Pass 1 (2026-05-04)

### New Issues

#### Section: I. Scope

No issues found.

---

#### Section: II. Architecture

**Issue 1: `.deff_effective_n()` existence contradicts surrounding prose**
Severity: BLOCKING
Violates engineering-preferences.md §1 (DRY) and engineering-preferences.md §5 (explicit over clever).

The spec says: "The `method = "deff"` path does NOT introduce a new computation helper. Instead, it delegates to the mean estimation pipeline:" and then immediately defines a new helper `.deff_effective_n()`. A builder reading this paragraph cannot know whether to:
- Inline the `get_means()` call directly in the `method = "deff"` branch (no new helper)
- Define `.deff_effective_n()` as an internal function (new helper)

The contradiction arises because the prose makes a claim and the code block refutes it. The intent appears to be "the DEFF *math* is not reimplemented — it delegates to `get_means()`" but a named helper IS introduced.

Options:
- **[A]** Remove `.deff_effective_n()` from the spec. Inline the delegation logic directly in the DEFF branch, and delete the prose claim. Callers are then just calling `get_means()` with `variance = "deff"` in one spot. — Effort: low, Risk: low, Impact: cleaner builder guidance, Maintenance: none
- **[B]** Keep `.deff_effective_n()`, correct the prose to say "The method = 'deff' path introduces a thin wrapper that delegates to `get_means()`." — Effort: low, Risk: low, Impact: consistent prose/code, Maintenance: none
- **[C] Do nothing** — builder guesses; risks either double-wrapping or no helper at all.

**Recommendation: A** — Inline delegation is simpler and avoids a helper with a single call site.

---

**Issue 2: `survey_collection` output structure unspecified**
Severity: BLOCKING
Violates testing-standards.md §2 (contract completeness) and the behavior of all other `get_*()` functions.

The spec says `.dispatch_over_collection()` is reused as-is, which implies the collection-dispatch result includes a `.id` column identifying each constituent survey (the standard behavior for all other `get_*()` functions). But the output contract in §III specifies columns only as: `[group_cols...]`, `n`, `n_eff`, `deff_kish` or `deff`. There is no mention of a `.id` column, its type, or when it appears.

A builder who reads the output contract will not know whether to include `.id` in the output for collection dispatch. This is especially important because the test plan (§5a, 5b) tests collection dispatch without specifying what the expected output structure is.

Options:
- **[A]** Add a row to the output column table: `[.id]` | character | `design` is a `survey_collection` and `.id` is not `NULL` | Identifies each constituent survey. Follow the same convention as other `get_*()` functions. — Effort: low, Risk: low, Impact: unambiguous builder guidance
- **[B]** Explicitly state "collection dispatch follows `.dispatch_over_collection()` semantics exactly — the `.id` column is added automatically by the shared helper" and add a reference. — Effort: low, Risk: low
- **[C] Do nothing** — builder infers from the helper behavior; likely correct but not guaranteed.

**Recommendation: A** — The output contract must be complete. Add the `.id` row to the table.

---

**Issue 3: `deff = Inf`, `deff = NaN`, `deff = NA` cases not covered**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The DEFF behavior rule 5 specifies: "When `deff <= 0` (degenerate or numerically unstable), return `n_eff = NA_real_`." But this leaves three cases unaddressed:

- `deff = Inf`: can occur when `Var_SRS = 0` and `Var_design > 0` (all sample values for `x` are identical, but design variance is not). In R, `n / Inf = 0`, not `NA`. That is a wrong result.
- `deff = NaN`: can occur when `Var_SRS = 0` and `Var_design = 0`. In R, `n / NaN = NaN`, not `NA`.
- `deff = NA_real_`: can occur when `get_means()` returns `NA` for deff in empty-domain rows. In R, `n / NA = NA`, which propagates correctly — but should be explicitly stated.

Options:
- **[A]** Change rule 5 to: "When `deff` is non-finite (≤ 0, Inf, NaN, or NA), return `n_eff = NA_real_` for that row. Use `is.finite(deff)` as the guard." — Effort: low, Risk: low, Impact: correct behavior in all degenerate cases
- **[B]** Document only the known cases that arise in practice and note that `get_means()` returns numeric DEFF so edge cases are bounded. — Effort: low, Risk: medium (`Var_SRS = 0` does arise with constant variables)
- **[C] Do nothing** — tests may catch this, or may not.

**Recommendation: A** — `is.finite(deff)` is a one-line fix that eliminates all non-finite cases.

---

#### Section: III. Function Spec

**Issue 4: Argument order description contradicts the signature**
Severity: REQUIRED
Violates code-style.md §4 (argument order rule: optional NSE before optional scalar).

The spec's description states: "Argument order follows `code-style.md`: `design` first → required NSE (`x`) → **required scalar (`method`)** → **optional NSE (`group`)** → optional scalars."

But the signature provided has:
```r
design, x = NULL, group = NULL, method = c("kish", "deff"), ...
```

`group` (optional NSE) appears **before** `method` (optional scalar) in the signature — which is consistent with `code-style.md §4` ("optional NSE → optional scalar") and matches the `get_means()` precedent (`group` before `variance`). The description has it backwards.

Additionally, the description calls `method` a "required scalar" — but `method` has a default value of `c("kish", "deff")` (resolves to `"kish"` via `match.arg()`), making it an *optional* scalar.

The signature is correct; the description is wrong on both counts.

Options:
- **[A]** Correct the description to: "`design` first → NSE (`x`) → optional NSE (`group`) → optional scalars (`method`, `na.rm`, `decimals`, `min_cell_n`) → `...` → named-only control args." — Effort: trivial, Risk: none
- **[B] Do nothing** — builder follows the signature, ignores the description, and the code is correct. But the spec as a reference document is misleading.

**Recommendation: A** — Fix the description; the signature is already right.

---

**Issue 5: `min_cell_n` warning ownership unspecified for `method = "deff"`**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The "Shared behavior" section states: "`min_cell_n` fires `surveycore_warning_small_cell` for any domain where `n < min_cell_n`, matching the family-wide convention."

For `method = "deff"`, the spec delegates to `get_means(design, x, ..., min_cell_n = min_cell_n)`. `get_means()` already fires `surveycore_warning_small_cell` internally. The builder must decide:

1. Fire the warning again in `get_effective_n()` after `get_means()` returns → double warning for DEFF
2. Suppress the warning from `get_means()` and re-fire in `get_effective_n()` → complex
3. Rely on `get_means()` to fire it for DEFF; fire it directly only for Kish → correct but not stated

Option 3 is almost certainly the right answer, but the spec does not say so. The "Shared behavior" section implies `get_effective_n()` always fires the warning itself, which would mean double-warning for DEFF.

Options:
- **[A]** Add a sentence to the Shared behavior section: "For `method = 'deff'`, the warning is fired by `get_means()` internally and is not re-fired by `get_effective_n()`. For `method = 'kish'`, `get_effective_n()` fires it directly." — Effort: trivial, Risk: none
- **[B] Do nothing** — builder guesses; likely fires it twice or omits it for Kish.

**Recommendation: A** — One sentence resolves the ambiguity completely.

---

**Issue 6: `na.rm = FALSE` behavior for Kish not defined**
Severity: REQUIRED
Violates engineering-preferences.md §4 (edge cases) and §5 (explicit over clever).

The argument table says: "For `method = 'kish'`: exclude observations with `NA` in any group variable before computing weight sums." This describes the `na.rm = TRUE` behavior. Behavior rule 1 adds the parenthetical "when `na.rm = TRUE`."

What happens when `na.rm = FALSE`?
- NA weights: `sum(w)` and `sum(w^2)` propagate NA → `n_eff = NA`, `deff_kish = NA`
- NA group values: observations with NA groups are not excluded, so they are included in the overall domain or in an NA group level (depending on how `.apply_domain()` handles them)

Neither outcome is specified. The spec should state:
1. Whether `na.rm = FALSE` means "include observations with NA weights" (producing NA n_eff)
2. Whether `na.rm = FALSE` means "include observations with NA group values" (placing them in an NA group bucket or the overall total)

Options:
- **[A]** Add to the Kish behavior rules: "When `na.rm = FALSE`, NA weights are NOT excluded; if any weight is NA, `n_eff = NA_real_` and `deff_kish = NA_real_` for that domain. NA group values are treated as a distinct group level (following `.apply_domain()` semantics)." — Effort: low, Risk: low
- **[B]** Restrict `na.rm = FALSE` behavior to DEFF (where it already passes through to `get_means()`) and note Kish always excludes NAs. — Effort: low, Risk: medium (breaks the single-argument interface)
- **[C] Do nothing** — builder guesses; undefined behavior at a real boundary condition.

**Recommendation: A** — State it; it's one paragraph and eliminates ambiguity.

---

**Issue 7: `survey_twophase` weights for Kish unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle edge cases explicitly).

The spec notes for `survey_replicate`: "`.kish_effective_n()` operates on the main (analysis) weights only; replicate weights are not used." No analogous note exists for `survey_twophase`.

Twophase designs have phase-1 and phase-2 weights. The combined final analysis weight is the product (or ratio) of phase weights. It is not obvious from the spec whether `.kish_effective_n()` should use:
- The final combined analysis weight (most likely correct, analogous to the main weight in replicate designs)
- Phase-1 weights only
- Phase-2 weights only

Options:
- **[A]** Add a sentence to the Shared behavior or Kish section: "For `survey_twophase` designs, `.kish_effective_n()` operates on the full combined analysis weights (phase-1 × phase-2), not phase-specific weights. This mirrors how `survey::svydesign()` exposes twophase weights." — Effort: trivial, Risk: none
- **[B] Do nothing** — builder infers "the analysis weights" but may not know how to extract them from a `survey_twophase` object.

**Recommendation: A** — One sentence. The twophase test in §IV.1d validates that the right weights are used.

---

**Issue 8: Error test pattern not specified for EN-1, EN-2, EN-3**
Severity: REQUIRED
Violates testing-standards.md §3 (Layer 3 errors require dual pattern: class= + snapshot).

The test plan (§IV, section 3) says: "Error paths (one block per error class)." It does not specify whether the dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`) is required for each error block.

Per `testing-standards.md §3`: "User-facing input validation errors require two assertions: (1) typed class check — verifies the right error class is thrown; (2) Snapshot — verifies the CLI message text has not changed." EN-1 through EN-3 all come from `cli_abort()` calls in a user-facing exported function. They are Layer 3 errors and must use the dual pattern.

The test plan should explicitly state this requirement so the builder doesn't implement class= only.

Options:
- **[A]** Annotate section 3 in the test plan: "Each error-path block uses the dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`. See testing-standards.md §3." — Effort: trivial, Risk: none
- **[B] Do nothing** — builder follows the shared standard. Risk: they may not know to apply it here.

**Recommendation: A** — One line closes a test-completeness gap.

---

**Issue 9: Numerical validation code uses raw weight vector — potential mismatch**
Severity: REQUIRED
Violates testing-standards.md §2 (numerical oracle must match the implementation path).

The Kish numerical validation test in §IV uses:
```r
w <- nhanes_2017$wtmec2yr
expected_n_eff <- sum(w)^2 / sum(w^2)
```

If `nhanes_2017$wtmec2yr` contains any `NA` values, `sum(w)` returns `NA`, and `expected_n_eff = NA`. The test would then assert `result$n_eff == NA` using `expect_equal()`, which is a non-trivial comparison. Meanwhile, `get_effective_n()` with `na.rm = TRUE` (the default) would exclude NA-weight observations and return a finite `n_eff`. The comparison would fail.

Even if the dataset is known to be NA-free, the test should use `weights(d_sc)` — the design-level weights — rather than the raw column. The design may perform internal transformations on weights (e.g., scaling, trimming) that cause a discrepancy.

Options:
- **[A]** Change the test to use `w <- weights(d_sc)` (the analysis-weight vector from the survey design object). — Effort: trivial, Risk: none, Impact: test is robust to NA weights and internal weight transformations
- **[B]** Add `w <- nhanes_2017$wtmec2yr[!is.na(nhanes_2017$wtmec2yr)]` as a workaround. — Effort: low, Risk: medium (doesn't handle design-level weight modifications)
- **[C] Do nothing** — test works if the dataset is confirmed NA-free, fails silently otherwise.

**Recommendation: A** — `weights(d_sc)` is the exact set of analysis weights the function uses.

---

#### Section: IV. Testing

**Issue 10: Test section 4 missing `na.rm = FALSE` edge case**
Severity: REQUIRED
Violates testing-standards.md §2 (edge cases category).

Issue 6 above identifies that `na.rm = FALSE` behavior is undefined in the spec. Once it is defined (Issue 6 resolution), a test must cover it. The current test section 4 (edge cases) does not include:
- `na.rm = FALSE` for Kish with an NA weight → `n_eff = NA`
- `na.rm = FALSE` for Kish with NA in a group variable

This is contingent on resolving Issue 6, but the test plan should be updated regardless.

Options:
- **[A]** Add to section 4: "f. na.rm = FALSE for Kish: NA weight → n_eff = NA, deff_kish = NA; NA group value included or bucketed per .apply_domain() semantics." — Effort: trivial
- **[B] Do nothing** — test is added during Stage 4 resolution of Issue 6.

**Recommendation: A** — Document the test now; implementation follows.

---

#### Section: V. Quality Gates / VI. Integration

No issues found.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 8 |
| SUGGESTION | 0 |

**Total issues:** 10

**Overall assessment:** The spec is structurally solid and methodology is clear, but has two blocking ambiguities (the `.deff_effective_n()` existence contradiction and the missing `survey_collection` output column spec) that would force implementer guesses. Six of the eight REQUIRED issues are one-sentence fixes to edge case behavior and test-pattern specifications — none require architectural changes. The spec can be ready for implementation after a focused Stage 4 pass.
