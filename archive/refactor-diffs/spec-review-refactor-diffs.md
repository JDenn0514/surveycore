## Spec Review: refactor-diffs — Pass 1 (2026-04-01)

### New Issues

#### Section: III. Helper Specifications — General

**Issue 1: `show_means = FALSE` + `show_pct_change = TRUE` has no specified ref_mean source**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases explicitly) and the quality gate
("byte-for-byte identical").

Section 3.3.5 derives `ref_mean` as "the reference row mean for the same group combo."
But section 3.3.2 only builds a reference row "when `show_means = TRUE`." When
`show_means = FALSE`, no reference row exists in the row list, so this derivation is
undefined.

The current implementation handles `show_means = FALSE` differently across the two
existing branches — creating a behavioral inconsistency that the refactor would either
preserve or change:

- **No-group (current lines 672–682):** When `show_means = FALSE`, `ref_mean_for_pct`
  is still computed from the model output — `reference_mean` on the clean path,
  `preds_df$estimate[...]` on the ME path. `pct_change` is computed.
- **Grouped (current line 974):** `ref_mean_for_pct` initializes to `NA_real_` and is
  only updated by finding a reference row (`estimate == 0`) in `all_rows`. When
  `show_means = FALSE`, no such row exists, so `ref_mean_for_pct` stays `NA_real_` and
  `pct_change` is always `NA`.

If `.build_diffs_output()` strictly uses "reference row mean," it changes the no-group
behavior. The quality gate says byte-for-byte identical. This is a contradiction.

Options:
- **[A]** Spec `.build_diffs_output()` to fall back to `result$reference_mean`
  (clean path) or the matching `result$preds_df` row (ME path) when `show_means = FALSE`
  and `show_pct_change = TRUE` — preserving current no-group behavior and also fixing
  the grouped case to match. Effort: low, Risk: low, Impact: pct_change correct across
  all cases, Maintenance: one code path.
- **[B]** Spec that when `show_means = FALSE`, `pct_change` is always `NA_real_`
  — simpler unified rule, but it's a behavioral change for the no-group case that
  violates the quality gate. Effort: low, Risk: high, Impact: regression.
- **[C] Do nothing** — implementer must guess; the quality gate says byte-for-byte
  identical, but the spec contradicts this for `show_means = FALSE`.

**Recommendation: [A]** — Preserve observable behavior via explicit fallback spec.
Add a sub-step to §3.3.2 and §3.3.5: "When `show_means = FALSE` and
`show_pct_change = TRUE`, `ref_mean` is obtained from `result$reference_mean` (clean
path) or the matching row in `result$preds_df` (ME path); if neither is available,
`ref_mean = NA_real_`."

---

**Issue 2: `.apply_domain()` placement conflict between §II.2 and §3.3**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

§II.2 shared-helpers table entry:
> `.apply_domain()` | Step 12 (now inside `.build_diffs_output()`)

§3.3 `.build_diffs_output()` signature:
> `domain_mask | logical | Row mask from .apply_domain(design)`

§IV skeleton shows `domain_mask` as an argument passed into `.build_diffs_output()`,
meaning `.apply_domain()` is called externally in `get_diffs()` and the result is passed
in. §II.2 says the opposite — that `.apply_domain()` moves inside the helper.

An implementer reading §II.2 first concludes `.apply_domain()` should be called inside
the helper. Reading §3.3 contradicts this. The authoritative source is unclear.

Options:
- **[A]** Correct §II.2 to read "Step 12 (result passed into `.build_diffs_output()`
  as `domain_mask`)" — `domain_mask` is computed in `get_diffs()` just before the
  `.build_diffs_output()` call. Effort: low, Risk: low, Impact: eliminates ambiguity.
- **[B]** Move `.apply_domain()` inside `.build_diffs_output()` and remove
  `domain_mask` from the signature — consistent with §II.2. Effort: low, Risk: low,
  but requires `design` access inside the helper (which is already there via the
  `design` parameter). Maintenance: slightly less explicit parameter passing.
- **[C] Do nothing** — implementer must choose; gets it wrong 50% of the time.

**Recommendation: [A]** — §3.3's parameter is cleaner and already authoritative; fix
the §II.2 table entry to match.

---

#### Section: V. Testing

**Issue 3: Dual-pattern test not specified for `surveycore_error_reference_row_not_found`**
Severity: REQUIRED
Violates testing-standards.md §3 ("Constructor error testing: dual pattern") and
testing-surveycore.md §S7 error testing layers ("Layer 3 — user-facing errors from
`cli::cli_abort()` — test with the dual pattern").

§5.2 test table for `.extract_clean_estimates()` lists:
> Error: missing intercept | Aborts with `surveycore_error_reference_row_not_found`

This error is emitted via `cli::cli_abort()` and surfaces through `get_diffs()` to the
user. Per the testing standard, it requires both `expect_error(class = ...)` AND
`expect_snapshot(error = TRUE, ...)`. The snapshot captures the CLI-formatted message.
The spec should state explicitly whether the snapshot test is on the helper call directly
or on the `get_diffs()` call.

Since `.extract_clean_estimates()` is an internal helper, the snapshot test belongs on
the public API (`get_diffs()`), not on a direct call to the helper. The spec's §5.2
framing of "direct tests for helpers" may lead to a snapshot against the internal helper
instead.

Options:
- **[A]** Add a note to §5.2 under `.extract_clean_estimates()` errors: "Snapshot test
  goes on `get_diffs()` call, not the helper directly — the error surfaces via the
  public API." Effort: low, Risk: low.
- **[B]** Also add a snapshot-at-helper-level test — acceptable since the message is
  identical regardless of call site. Effort: low, Risk: low, minor duplication.
- **[C] Do nothing** — snapshot test is missing; R CMD check won't catch it but code
  review will.

**Recommendation: [A]** — Clarifies intent and keeps snapshot tests on the public API.

---

**Issue 4: `by` argument handling in `avg_slopes()` / `avg_predictions()` not specified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

§3.2 step 3 says: "When `group_names` is empty, `by` is omitted." `marginaleffects::avg_slopes()`
and `avg_predictions()` may behave differently with `by = NULL` vs. the argument absent
entirely. The current implementation uses two separate call sites (lines 423–438,
446–464) to avoid this ambiguity. The spec does not specify whether the implementation
should:

- Use a conditional call structure (`if (length(group_names) > 0L) { avg_slopes(..., by = group_names, ...) } else { avg_slopes(..., ...) }`)
- Pass `by = if (length(group_names) > 0) group_names else NULL`
- Use `do.call()` to conditionally include `by`

For `avg_predictions()`, the `by` argument has a slightly different signature: the
non-group case uses `by = treats_name` (a single variable), and the grouped case uses
`by = c(treats_name, group_names)`. The spec step 4 says "by = c(treats_name,
group_names_or_just_treats)" — this phrasing is informal and may confuse the implementer
into calling `c(treats_name, character(0))` which is just `treats_name`, which works.
But for `avg_slopes()`, "omit" is meaningfully different from `by = NULL`.

Options:
- **[A]** Specify the conditional call structure explicitly for both `avg_slopes()` and
  `avg_predictions()` — matching the current two-call-site pattern now inside one
  function. Effort: low, Risk: low.
- **[B]** Test empirically that `by = NULL` and no `by` behave identically in
  `marginaleffects`, document the equivalence, and use `by = if (length(group_names) > 0) group_names else NULL`. Effort: low, but requires verification.
- **[C] Do nothing** — implementer may use `by = NULL` and silently change behavior.

**Recommendation: [A]** — Explicit conditional call structure matches the current
implementation and avoids any `by = NULL` risk.

---

**Issue 5: Removal of defensive grouped branch not acknowledged**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever — spec should say what is
removed, not leave it implicit).

The current implementation contains a defensive branch at lines 808–813:
```r
} else {
  # Should not happen: has_group triggers ME path
  # Defensive: build from data
  unique_group_combos <- unique(
    design@data[domain_mask, group_names, drop = FALSE]
  )
}
```

§3.3.1 specifies that when `length(group_names) > 0`, `result$result_groups` is used
to derive `unique_group_combos`. This implicitly removes the defensive branch, but the
spec doesn't acknowledge the removal.

The quality gate says "No `list()` or `data.frame()` with `ncol == 0` edge cases are
handled differently from current behavior." While this branch is dead code, leaving it
unacknowledged means the implementer must decide independently whether to include it.

Options:
- **[A]** Add a sentence to §3.3.1: "The defensive branch for `!use_marginaleffects &&
  has_group` (current lines 808–813, labeled 'Should not happen') is intentionally
  removed by this refactor. The invariant that `has_group` always triggers the ME path
  is enforced by Step 10 of `get_diffs()`." Effort: low.
- **[B] Do nothing** — implementer likely removes it but it's undocumented.

**Recommendation: [A]** — Explicit removal acknowledgment is required for a refactor
spec; one sentence.

---

#### Section: III.2 / IV. — Architecture

**Issue 6: `estimate_method` / `mean_method` / `estimate_scale` variables absent from §IV skeleton**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The current code (lines 353–355, 413–415) sets `estimate_method`, `mean_method`, and
`estimate_scale` inside the `if (!use_marginaleffects)` / `else` block. These variables
are used in Step 20 (`.meta` construction). The §IV skeleton shows Step 11 as only
calling the new extract helpers, omitting these assignments. An implementer reading §IV
might relocate these or assume they're inside the helpers.

These variables are NOT absorbed into any helper — they remain in `get_diffs()` at the
same positions. The skeleton should show them explicitly, or add a note to Step 11 that
path-specific meta variables are set in the same block before calling the extract helper.

Options:
- **[A]** Add the variable assignments to the §IV Step 11 skeleton:
  ```
  Step 11     Extract estimates:
                if (!use_marginaleffects) {
                  estimate_method <- "coefficient"
                  mean_method     <- "intercept"
                  estimate_scale  <- "coefficient"
                  result <- .extract_clean_estimates(...)
                } else {
                  estimate_method <- "avg_slopes"
                  mean_method     <- "avg_predictions"
                  estimate_scale  <- if (scale == "link") "coefficient" else "ame"
                  result <- .extract_me_estimates(...)
                }
  ```
  Effort: low.
- **[B] Do nothing** — Implementer likely keeps them in place, but the skeleton is
  incomplete.

**Recommendation: [A]** — The skeleton is the primary implementation guide; omitting
these leaves a gap the quality gate would catch only at test time.

---

#### Section: V.2 — Test Completeness

**Issue 7: Helper-level test construction not specified for `.build_diffs_output()`**
Severity: SUGGESTION
Cross-reference: testing-standards.md §4 (test data — inline for edge cases).

§5.2's test table for `.build_diffs_output()` lists 11 test cases without specifying
how the `result` named list (the first argument) is constructed for direct helper tests.
The helper takes a list with 10 specific keys that come from either `.extract_clean_estimates()`
or `.extract_me_estimates()`. Testing the helper directly requires either:

1. Calling the extract helpers first (integration-style), or
2. Constructing a mock `result` list inline.

Option (2) is cleaner for unit testing the helper in isolation (edge cases like
`n == 0` don't require a full model fit). The spec should note which approach is
expected or recommend inline mock construction for edge cases while using the extract
helpers for happy-path tests.

Options:
- **[A]** Add a note to §5.2: "For `.build_diffs_output()` unit tests, construct
  mock `result` lists inline. For happy-path behavioral comparison, call
  `.extract_clean_estimates()` or `.extract_me_estimates()` first."
- **[B] Do nothing** — Implementer can infer this, low risk.

**Recommendation: [A]** — One sentence avoids any confusion.

---

#### Section: III. — Helper Specifications (Minor)

**Issue 8: `groups_df` nrow specification is overconstrained**
Severity: SUGGESTION

§3.3.6 states: "For the no-group case, it is a 0-column `data.frame` with `nrow` equal
to the number of rows." The current implementation produces `data.frame()` which is 0×0.
Downstream code (Step 17a, line 1136) only checks `ncol(groups_df) > 0L` — nrow of
`groups_df` is never used. Specifying nrow = N creates work without any observable
behavioral requirement.

The quality gate §VI also says "No `list()` or `data.frame()` with `ncol == 0` edge
cases are handled differently from current behavior" — the current behavior is 0×0, not
N×0.

Options:
- **[A]** Change §3.3.6 to: "For the no-group case, `groups_df` is a 0-column
  `data.frame` (e.g., `data.frame()`)." Remove the nrow constraint.
- **[B] Do nothing** — Implementer builds N×0 data.frame, which is harmless but
  requires extra work and diverges from current behavior.

**Recommendation: [A]** — Simpler and consistent with current behavior.

---

**Issue 9: No propagation note for external errors from `.extract_me_estimates()`**
Severity: SUGGESTION

`.extract_me_estimates()` calls `marginaleffects::avg_slopes()` and
`marginaleffects::avg_predictions()`, which can throw their own errors (e.g., model
convergence failures, incompatible `type` for the family). The spec has no error table
for this helper and no note about whether such errors are caught and re-wrapped or
propagated directly.

Options:
- **[A]** Add a one-line note: "Errors from `marginaleffects::avg_slopes()` and
  `avg_predictions()` propagate to the caller without wrapping."
- **[B] Do nothing** — Obvious to any implementer; propagation is the natural R
  behavior.

**Recommendation: [B]** — The behavior is obvious and doesn't need documentation.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 2 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total issues:** 9

**Overall assessment:** The spec correctly identifies the DRY problem and proposes a
sound unified helper design, but has two blocking gaps: the `show_means = FALSE` +
`show_pct_change = TRUE` ref_mean derivation is unspecified (creating a potential
behavioral regression the quality gate would catch), and §II.2 directly contradicts §3.3
on where `.apply_domain()` is called. Both are fixable with a few sentences. The
remaining required issues are one-line clarifications. The spec is close to implementable.

---

## Spec Review: refactor-diffs — Pass 2 (2026-04-01)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|-------|--------|
| 1 | `show_means = FALSE` + `show_pct_change = TRUE` has no specified ref_mean source | ✅ Resolved |
| 2 | `.apply_domain()` placement conflict between §II.2 and §3.3 | ✅ Resolved |
| 3 | Dual-pattern test not specified for `surveycore_error_reference_row_not_found` | ✅ Resolved |
| 4 | `by` argument handling in `avg_slopes()` / `avg_predictions()` not specified | ✅ Resolved |
| 5 | Removal of defensive grouped branch not acknowledged | ✅ Resolved |
| 6 | `estimate_method` / `mean_method` / `estimate_scale` variables absent from §IV skeleton | ✅ Resolved |
| 7 | Helper-level test construction not specified for `.build_diffs_output()` | ✅ Resolved |
| 8 | `groups_df` nrow specification is overconstrained | ✅ Resolved |
| 9 | No propagation note for external errors from `.extract_me_estimates()` | ⚠️ Still open — intentional (recommendation was [B] Do nothing) |

### New Issues

#### Section: III.2 — `.extract_me_estimates()` Return Spec

**Issue 10: `result_means` return type is wrong and no-group ME population is unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever) and §4 (handle edge cases).

Two related gaps in §3.2:

**Gap A — Return type.** The `result_means` row is absent from the "differences"
table in §3.2, so it inherits `double` from the clean-path return spec. But the
current implementation sets `result_means <- NULL` when `suppress_mean = TRUE`
(confirmed in `analysis-diffs.R` lines 490 and 534 — both the no-group and grouped
code paths). The §5.2 test table also explicitly tests `result_means is NULL` when
`suppress_mean = TRUE`. The return type table and the test spec are in conflict.

**Gap B — No-group ME population.** §3.2 Behavior step 7 says "When `group_names` is
non-empty and `!suppress_mean`, matches `result_means` row-by-row from `preds_df`
using `treats_name` + group columns as a composite key." The no-group ME case (when
`length(group_names) == 0` and `!suppress_mean`) is never described. The current code
handles this separately (lines 481–492): it builds a named vector from
`preds_df$estimate` keyed by `treats_name` column, then looks up each level. This
population mechanism is absent from the spec.

Options:
- **[A]** Add `result_means` to the differences table with type `double or NULL`, and
  add a step 6a (before step 7) covering the no-group ME population: "When
  `length(group_names) == 0` and `!suppress_mean`, populate `result_means` by
  matching each level in `result_levels` against the `treats_name` column of
  `preds_df`, using the corresponding `estimate` value. When `suppress_mean = TRUE`,
  set `result_means = NULL`." Effort: low, Risk: low.
- **[B] Do nothing** — Implementer infers NULL from the test table and guesses the
  no-group ME mechanism. High risk of divergence from current behavior.

**Recommendation: [A]** — Both gaps are one-to-two sentence fixes; together they give
a complete, unambiguous return contract.

---

#### Section: VI. Quality Gates

**Issue 11: Issue 1 resolution introduces a deliberate behavioral change; quality gate must acknowledge it**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The resolution to Pass 1 Issue 1 specifies that when `show_means = FALSE` and
`show_pct_change = TRUE`, `ref_mean` for the grouped ME path is obtained from
`result$preds_df` (filtered by `treats_name == ref_level` and matching group columns).
This diverges from the **current** grouped implementation, which initializes
`ref_mean_for_pct` to `NA_real_` and only updates it by scanning `all_rows` for a row
with `estimate == 0` (lines 974–987). When `show_means = FALSE`, no reference row is
ever added to `all_rows`, so `ref_mean_for_pct` stays `NA_real_` and `pct_change` is
always `NA` for the grouped path.

After the refactor, the grouped case with `show_means = FALSE` will return correct
`pct_change` values instead of `NA`. This is a deliberate behavioral fix embedded in
an otherwise pure-refactor spec.

The quality gate states: "`get_diffs()` output is byte-for-byte identical to current
output on the existing test suite." If any existing test exercises `show_means = FALSE`
with a grouped design and `show_pct_change = TRUE` (without `suppress_mean`), that
test would fail — not because the refactor is wrong, but because the current behavior
is a bug the spec is intentionally correcting.

Options:
- **[A]** Add a note to §VI: "Exception: the `show_means = FALSE` + grouped +
  `show_pct_change = TRUE` combination is excluded from the byte-for-byte quality gate.
  The current grouped implementation returns `NA` for `pct_change` in this case (a
  behavioral inconsistency vs. the no-group path); this refactor aligns the two paths.
  Before declaring the gate satisfied, verify no existing test exercises this exact
  combination." Effort: low, Risk: low.
- **[B]** Audit the existing diffs test file for this combination before implementing.
  If a test exists, update it to expect the corrected value rather than `NA`, and call
  this out explicitly in the spec as an intended test update. Effort: low.
- **[C] Do nothing** — Implementer encounters an unexpected test failure, investigates
  without context, and may revert the behavioral fix rather than update the test.

**Recommendation: [A] + [B]** — Add the gate exception note and do a one-time audit.
Both are low effort and prevent the implementer from being blindsided by a "byte-for-byte
identical" failure that is actually correct behavior.

---

#### Section: V.2 — Testing

**Issue 12: Warning tests do not confirm the correct assertion pattern**
Severity: SUGGESTION
Cross-reference: testing-standards.md §3 (Warning capture pattern).

The §5.2 test table entries for `.build_diffs_output()` warnings state what each
warning test should verify but not how. The spec also specifies the dual pattern
(class + snapshot) for the clean-path error, immediately above. An implementer
working through §5.2 top-to-bottom might incorrectly apply `expect_snapshot()` to
warning tests as well.

Per `testing-standards.md`, warnings use `expect_warning(class = ...)` only — no
`expect_snapshot()` (which is for `cli_abort()` errors only).

Options:
- **[A]** Add a note below the `.build_diffs_output()` warning rows: "Warning tests
  use `expect_warning(class = ...)` only — no snapshot — per testing-standards.md."
  Effort: trivial.
- **[B] Do nothing** — `testing-standards.md` is authoritative; the implementer is
  expected to know the pattern.

**Recommendation: [A]** — One sentence removes the ambiguity created by mixing dual-
pattern error specs and warning specs in the same table section.

---

## Summary (Pass 2)

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 1 |

**Total new issues:** 3

**Overall assessment:** All nine Pass 1 issues are resolved. The two required issues
are contained: the `result_means` return type and no-group population gap in §3.2 are
two-sentence additions, and the quality gate exception for the Issue 1 behavioral fix
is a single note plus a pre-implementation audit. One suggestion on warning test
pattern clarification. The spec is ready to implement after these three additions.
