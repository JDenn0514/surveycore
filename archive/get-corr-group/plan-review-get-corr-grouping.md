## Plan Review: get-corr-grouping — Pass 1 (2026-02-27)

### New Issues

#### Section: PR Structure & Lens 1 (Granularity)

No issues. A single PR for a single-function grouping addition is appropriate.
The helper refactor (Step A) is tightly coupled to the wide-path change (Step B4)
and does not warrant its own PR.

---

#### Section: PR 1 — feature/get-corr-grouping

---

**Issue 1: `.corr_wide()` becomes dead code after Step B4**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY — flag dead code aggressively)

Step A updates `.corr_wide()` to call `.corr_build_matrix_col_vecs()` and adds a
`groups_df` parameter. Step B4 then replaces the entire wide-format path in
`get_corr()` with direct calls to `.corr_build_matrix_col_vecs()` +
`.make_result_tibble()` — never calling `.corr_wide()` at all. The result is that
`.corr_wide()` exists but has zero callers after implementation.

The plan's Step A narrative says "Simplify `.corr_wide()` to call the new helper...
so the no-groups case still works via `data.frame()`" — but Step B4's code handles
both cases without calling `.corr_wide()`. This inconsistency will confuse the
implementer and produce an unreachable function.

Options:
- **[A]** Remove `.corr_wide()` entirely in Step A (only define `.corr_build_matrix_col_vecs()`); Step B4's code calls the helper directly as written — Effort: low, Risk: low, Impact: eliminates dead code, plan is internally consistent
- **[B]** Keep `.corr_wide()` and have Step B4 call it for the ungrouped wide case, calling `.corr_build_matrix_col_vecs()` only inside the group loop — Effort: low, Risk: low, Impact: `.corr_wide()` stays alive, adds a small branching check
- **[C] Do nothing** — implementer ships a function with no callers; confusing during future maintenance

**Recommendation: [A]** — The no-groups case is a degenerate single-combo loop; `.corr_build_matrix_col_vecs()` handles it directly. Removing `.corr_wide()` is simpler.

---

**Issue 2: Long-format loop boundary ambiguity — group-independent logic may be wrapped inside the combo loop**
Severity: REQUIRED
Violates engineering-preferences.md §5 (Explicit over clever)

The plan says: "Wrap the existing long-format accumulation logic (Steps 10–12 in
current code) inside a `for (ci in seq_len(n_combos))` loop." Steps 10–12 in the
current code contain two distinct kinds of logic:

- **Group-independent** (constant across combos): expanding `row_i`/`row_j` from
  pair indices according to `redundant`/`diagonal`, building the `pair_idx_map`
  (p×p matrix), pre-allocating `acc_*` vectors.
- **Group-varying** (per-combo): the actual fill loop that reads
  `pair_results[[k]]$r`, `$se_r`, etc. from the current combo's results.

If the implementer wraps ALL of Steps 10–12 inside the combo loop (as the wording
implies), `row_i`, `row_j`, and `pair_idx_map` are recomputed `n_combos` times.
This is wasteful but — more importantly — the pre-allocated vectors
(`acc_var1 <- character(n_rows)`, etc.) would be overwritten each iteration rather
than accumulated across iterations, silently discarding all but the last combo's
results.

The only correct interpretation is: compute `row_i`, `row_j`, `pair_idx_map` once
before the combo loop; only the fill-and-accumulate step goes inside. The plan does
not make this explicit.

Options:
- **[A]** Rewrite the B5 section to split clearly into "pre-loop constants" and
  "inside-loop accumulation": list `row_i`/`row_j`/`pair_idx_map` outside; show
  only the fill-and-accumulate code inside — Effort: low, Risk: low, Impact: no ambiguity
- **[B]** Add a single bolded sentence: "Compute `row_i`, `row_j`, and
  `pair_idx_map` once before the combo loop; only the `acc_*` fill step goes
  inside" — Effort: very low, Risk: low, Impact: clarifies intent
- **[C] Do nothing** — implementer may correctly infer the intent, or may ship a
  silent per-combo overwrite bug

**Recommendation: [A]** — Show the exact boundary. The split is non-obvious when reading "wrap Steps 10–12."

---

**Issue 3: Oracle for numerical accuracy test is wrong — `skip_if_not_installed("survey")` is incorrect**
Severity: REQUIRED
Violates testing-standards.md §3 (every acceptance criterion must be verifiable)

Test #6 reads: "for each group level, correlation from grouped result matches
`get_corr()` run on a domain-subsetted design (tolerance 1e-10). Use
`skip_if_not_installed("survey")`."

The stated oracle is `get_corr()` on a subsetted `survey_taylor` design — not the
`survey` package. The `survey` package is not involved in that comparison at all.
`skip_if_not_installed("survey")` will cause this test to be silently skipped on
every machine where `survey` is not installed, even though the test itself needs
only base surveycore.

The existing numerical oracle tests in `test-analysis-corr.R` (lines 450–521) DO
require the `survey` package because they compare against `survey::svyvar()`. If
this test also validates against the `survey` package, the plan must say so.

Options:
- **[A]** Remove `skip_if_not_installed("survey")`; the oracle is `get_corr()` on a
  subsetted design (requires no external package) — Effort: low, Risk: low, Impact: test runs unconditionally
- **[B]** Keep `skip_if_not_installed("survey")` but extend the test to also compare
  against `survey` package output (consistent with existing oracle tests) — Effort:
  medium, Risk: low, Impact: stronger numerical guarantee
- **[C] Do nothing** — test is spuriously skipped; grouped numerical accuracy is not
  verified on machines without `survey`

**Recommendation: [A]** — The surveycore-vs-surveycore comparison is already strong
(same code path, different call site). Adding `survey` as oracle is optional; drop
the skip.

---

**Issue 4: No NEWS.md / changelog entry in "Files to Change"**
Severity: REQUIRED
Violates github-strategy.md ("every PR must include a changelog entry")

The plan's "Files to Change" table lists four files. `NEWS.md` (or a
`changelog/phase-1/feature-get-corr-grouping.md` entry) is not listed. Every PR
that adds user-visible functionality requires a changelog entry before merging.

Options:
- **[A]** Add `NEWS.md` to "Files to Change" with a one-line entry in
  `## Unreleased` — Effort: low, Risk: none, Impact: PR is complete
- **[B]** Add a `changelog/phase-1/feature-get-corr-grouping.md` entry if the
  project uses per-feature changelogs — Effort: low, Risk: none
- **[C] Do nothing** — PR merges without a changelog entry; release notes require
  manual reconstruction

**Recommendation: [A]** — NEWS.md is the standard surveycore format.

---

**Issue 5: 98%+ coverage requirement absent from acceptance criteria**
Severity: REQUIRED
Violates testing-standards.md ("PRs that drop coverage below 95% are blocked by CI")

The "Run Before Opening PR" section lists `devtools::check()` and `devtools::test()`
but does not state the 98%+ coverage requirement or name the CI gate (95% floor).
With three edge cases untested (Issues 6–8), coverage for the new group-path code
branches may fall short, and the implementer has no explicit signal to track it.

Options:
- **[A]** Add a line to "Run Before Opening PR": `covr::package_coverage()` — target
  ≥ 98% line coverage; CI blocks below 95% — Effort: low, Risk: none
- **[B]** Add a formal "Acceptance Criteria" section with the three verifiable items:
  0/0/≤2 check result, 98%+ coverage, no failing snapshots — Effort: low, Risk: none
- **[C] Do nothing** — implementer relies on CI to catch coverage regressions; may
  submit a PR that drops below 95%

**Recommendation: [B]** — A formal acceptance criteria section also clarifies the
`devtools::document()` + NAMESPACE sync requirement that is currently implied but not stated.

---

#### Section: Test Coverage Gaps

**Issue 6: Edge case "group combo with 0 in-domain rows" has no test**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer)

The edge cases table lists: "Group combo with 0 in-domain rows → `r = NA`, `n = 0L`;
fires `surveycore_warning_small_cell`." No corresponding test block appears in the
7 listed tests. This scenario arises when `group_by()` produces a combo that exists
in the data but is filtered out by a `filter()` domain mask — a realistic survey
scenario. The behavior (NA estimates, small-cell warning, not an error) should be
verified.

Options:
- **[A]** Add test #8: Create a design with `filter()` and two-group grouping where
  one group has 0 in-domain rows; verify `r = NA`, `n = 0L`, and
  `surveycore_warning_small_cell` fires — Effort: low
- **[B] Do nothing** — behavior is covered implicitly by the domain estimation tests;
  zero-row combo is an unlikely production scenario

**Recommendation: [A]** — The plan explicitly lists this edge case; it should have a test.

---

**Issue 7: Edge case "NA group values excluded" has no test**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases, not fewer)

The edge cases table says "NA values in group column → excluded from combinations."
The plan relies on standard R `unique()` behavior, but there is no test verifying
that rows where the group column is NA are silently excluded from group combos
(rather than producing an NA group row or throwing an error).

Options:
- **[A]** Add test #9: construct a group column with some NA values; verify the
  result has `n_unique_non_na_vals` rows (not `n_unique_non_na_vals + 1`) and no
  `NA` in the group column — Effort: low
- **[B] Do nothing** — `.resolve_groups()` / `unique()` handles this; testing
  standard R behavior is excessive

**Recommendation: [A]** — The behavior is documented in the edge cases table; a one-assertion test confirms it and prevents regression.

---

**Issue 8: `redundant = TRUE` and `diagonal = TRUE` with groups have no tests**
Severity: SUGGESTION

The edge cases table documents expected row counts for these combinations
(`n_combos × (2 × n_pairs)` and `n_combos × (n_pairs + p)`), but no test
verifies them. If `n_rows_per_combo` is miscalculated, `acc_grp_rows` will
have wrong length and `groups_df` will mismatch `col_vecs` length, causing a
silent rbind error or a `.make_result_tibble()` failure.

Options:
- **[A]** Add one test covering `redundant = TRUE, group = g` and one for
  `diagonal = TRUE, group = g`; check `nrow(result)` against expected count —
  Effort: low
- **[B] Do nothing** — formula is simple and visually correct; test adds little value

**Recommendation: [A]** — The formula involves a conditional, which is exactly the
kind of off-by-one risk that warrants a test.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The plan is structurally sound and implementable; the
grouping approach is correct and the pattern is well-established. However, five
required fixes are needed before coding starts: the dead `.corr_wide()` function
must be resolved (either removed or kept with callers), the long-format loop
boundary must be made explicit, the numerical test oracle is wrong, NEWS.md is
missing from the file list, and coverage requirements are unstated. The three
suggestion items are edge case tests that the engineering preferences explicitly
require ("when unsure whether an edge case needs a test, write the test").
