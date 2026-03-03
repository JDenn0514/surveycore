## Plan Review: group-na-rows — Pass 1 (2026-03-02)

### New Issues

#### Section: All PRs — Acceptance Criteria

---

**Issue 1: Warning class mismatch and wrong condition for Test Block 6**
Severity: BLOCKING
Violates: spec-coverage (plan inherits spec error); testing-surveycore.md (error class must match code)

Test Block 6 in every PR expects `class = "surveycore_warning_single_group_level"`, but
this class does not exist anywhere in the codebase. The actual warning class in all 6
analysis functions is `surveycore_warning_single_level`. A `grep` across `R/` and
`tests/testthat/` confirms no occurrence of `surveycore_warning_single_group_level`.

A second, deeper problem: the existing warning condition in all 6 functions is
`if (length(uniq_lvls) == 1L)` — exactly one non-NA unique value. For an all-NA group
variable, `unique(gv_vals[!is.na(gv_vals)])` returns `character(0)` — length **0**, not 1.
The condition `0 == 1L` is `FALSE`, so the warning does **not** fire. This means:
- `expect_warning(..., class = "surveycore_warning_single_group_level")` would fail
  because (a) the class doesn't exist and (b) no warning fires at all.
- The result-row count assertion `expect_equal(nrow(result), 1L)` might still pass
  (the NA-group row is produced via `.build_group_combos()`), giving false confidence
  that Test Block 6 passed.

Both the spec (§VI, Test Block 6) and the plan propagate this error unchanged across all
5 function PRs. An implementer following the plan as written will produce 30+ test
assertions (6 functions × 5 design classes worth of context) that silently reference a
non-existent warning class.

Options:
- **[A]** Change the warning condition in all 6 source files from `length(uniq_lvls) == 1L`
  to `length(uniq_lvls) < 2L`. Keep the existing `surveycore_warning_single_level` class
  (no new class needed). Update Test Block 6 in the plan to use
  `class = "surveycore_warning_single_level"`. Add the `< 2L` condition change to PR 1's
  acceptance criteria and file list (it touches all 6 functions, so it can be deferred to
  the relevant function PR or done as a standalone first-pass on each function PR).
  — Effort: low, Risk: low, Impact: correct warning fires for 0-level and 1-level groups
- **[B]** Introduce a new `surveycore_warning_single_group_level` class fired only when
  `length(uniq_lvls) < 1L` (the all-NA case), alongside the existing warning for the
  `== 1L` case. Update `plans/error-messages.md`. — Effort: medium, Risk: medium,
  Impact: separates the two cases but adds API surface
- **[C] Do nothing** — Test Block 6 fails to find the warning class; implementer must
  debug; the all-NA case is undertested.

**Recommendation: A** — Widening the existing condition to `< 2L` is the minimal correct
fix. It requires no new error class, no `plans/error-messages.md` update, and aligns
the warning semantics consistently across 0-level and 1-level cases.

---

**Issue 2: `.apply_group_labels()` not updated for Test Block 7b (haven-tagged NA → factor level)**
Severity: BLOCKING
Violates: spec coverage (§III "Output column types"), engineering-preferences.md #2 (well-tested)

Test Block 7b requires that haven-tagged NAs (e.g., `haven::tagged_na("r")` with label
"Refused") become factor **levels** (not `NA`) when `label_values = TRUE`. The acceptance
criteria in PRs 2–5 include this test. But the plan adds no change to `.apply_group_labels()`
in `analysis-helpers.R`, which is the only place that converts coded group columns to factors.

The current `.apply_group_labels()` implementation does:
```r
label_map[as.character(col)]
```
For any flavor of `NA` (tagged or plain), `as.character(NA)` returns the string `"NA"`.
`label_map["NA"]` returns `NA` (no label key named `"NA"`). So tagged NAs remain `NA` in
the factor output. Test Block 7b would fail.

Making Test Block 7b pass requires detecting tagged NAs in `col` and mapping them to their
label strings — which requires `haven::is_tagged_na()` or `attr(col, "na_tag")`. Since
`haven` is in `Suggests` (not `Imports`), this code path needs a `requireNamespace` guard.
This is a non-trivial addition not mentioned anywhere in the plan.

Options:
- **[A]** Remove Test Block 7b from the plan scope for this iteration. Document it as a
  known limitation ("haven tagged-NA → factor level conversion is not yet implemented").
  Track it as a follow-on enhancement in a separate issue. Keep Test Block 7a (regular NA
  stays `NA` in factor output) since that works today with no code changes.
  — Effort: low (remove from plan), Risk: low, Impact: scopes the feature correctly
- **[B]** Add `.apply_group_labels()` update to PR 1 (or to each function PR): detect
  tagged NAs via `attr(val, "na_tag")` (no `haven` import needed; tagged NAs store the
  tag as an attribute on the double value), look them up in `labels`, convert to factor
  levels. Add `tests/testthat/test-analysis-helpers.R` coverage for this path.
  — Effort: high, Risk: medium (haven dependency, edge cases), Impact: full 7b coverage
- **[C] Do nothing** — Test Block 7b appears in acceptance criteria but will fail;
  creates a broken PR.

**Recommendation: A** — Scope creep. Haven tagged-NA factor conversion is an independent
concern from NA group rows. Remove 7b from this iteration's acceptance criteria. Leave
the 7b test-block note as a comment ("TODO: tracked as issue #X") so it isn't forgotten.

---

#### Section: All PRs — File Completeness (Changelog Missing)

---

**Issue 3: Changelog entries missing from all 5 PR acceptance criteria and file lists**
Severity: REQUIRED
Violates: stage-2-review.md Lens 3 ("Changelog entry written and committed on this branch")

The `changelog/` directory exists in the repo (`changelog/phase-0/`, `changelog/phase-0.75/`,
`changelog/phase-1/`). All 5 PRs omit:
1. A `changelog/` file in the file list
2. "Changelog entry written and committed on this branch" in the acceptance criteria

Options:
- **[A]** Add a `changelog/phase-1/fix-group-na-rows-helpers.md` (or similar) file to PR 1's
  file list and acceptance criteria. For PRs 2–5, add per-PR changelog file entries.
  — Effort: low, Risk: low
- **[B]** Add a single `changelog/phase-1/fix-group-na-rows.md` entry to PR 1 covering
  the entire feature (all 5 PRs together), with a note that PRs 2–5 update the same file.
  — Effort: low, Risk: low
- **[C] Do nothing** — changelog falls out of sync with the feature.

**Recommendation: B** — Single changelog file for the whole fix set is cleaner. Add it
to PR 1's file list and acceptance criteria. PRs 2–5 acceptance criteria note "changelog
already created in PR 1; no additional entry needed" or optionally update it with each PR.

---

#### Section: PR 2 — `get_freqs()` (and PRs 3–5)

---

**Issue 4: Test Block 8 missing `skip_if_not_installed("surveytidy")`**
Severity: REQUIRED
Violates: testing-standards.md §4 (`skip_if_not_installed` required at block level for
external packages), testing-surveycore.md (established pattern in existing test files)

Test Block 8 calls `surveytidy::group_by()`. The existing codebase consistently uses
`skip_if_not_installed("surveytidy")` for all such tests (confirmed in
`test-analysis-corr.R:208`). The plan's Test Block 8 template and cross-cutting notes
do not mention this skip.

Without this skip, Test Block 8 will error (not fail — *error*) in CI environments where
`surveytidy` is not available (e.g., CRAN checks, fresh installs).

Options:
- **[A]** Add `skip_if_not_installed("surveytidy")` to the Test Block 8 implementation
  note in the cross-cutting notes section, and note it as required for every function's
  Test Block 8. — Effort: trivial, Risk: none
- **[B]** Add it per-function in PRs 2–5 individually. — Effort: trivial × 5
- **[C] Do nothing** — tests error instead of skip in environments without surveytidy.

**Recommendation: A** — Document once in the cross-cutting notes. All 5 function PRs
reference that section for Test Block 8.

---

#### Section: PR 4 — `get_corr()` and `get_quantiles()`

---

**Issue 5: `get_corr()` oracle test notation passes `y` as the `group` argument**
Severity: REQUIRED
Violates: spec coverage (oracle test would be testing the wrong thing)

The PR 4 implementation notes say:

> For the oracle test, subset to `is.na(grp)` and call `get_corr(na_design, x, y)`.

`get_corr()`'s second positional argument is `x` (the tidy-select variable selector) and
its third positional argument is `group`. `get_corr(na_design, x, y)` passes `y` as the
`group` argument — not as a second focal variable. The correct call is:
```r
get_corr(na_design, c(y1, y2))
```
The same shorthand notation appears in the "Test Blocks 2–6" note ("use `y1` and `y2` as
the two focal variables"), which is clear enough in context — but the oracle note uses
positional notation that is concretely wrong.

Options:
- **[A]** Replace `get_corr(na_design, x, y)` with `get_corr(na_design, c(y1, y2))` in the
  PR 4 oracle test implementation note. — Effort: trivial
- **[B]** Add a clarifying parenthetical: "`get_corr(na_design, x, y)` — here `x` and `y`
  are dataset column names; the actual call is `get_corr(na_design, c(y1, y2))`."
- **[C] Do nothing** — implementer passes `y1` as group, oracle silently tests wrong thing.

**Recommendation: A** — Fix the call notation directly. One line change.

---

#### Section: Cross-cutting Notes

---

**Issue 6: Outer `set.seed()` in oracle setup is redundant and misleading**
Severity: SUGGESTION
Violates: engineering-preferences.md #5 (explicit over clever)

In the cross-cutting notes oracle setup:
```r
set.seed(42L)
df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 42L)
df$grp <- sample(c("A", "B", NA_character_), 100L, replace = TRUE)
```
`make_survey_data()` internally calls `set.seed(seed)`. This overrides the outer
`set.seed(42L)` immediately. The `sample()` call for `df$grp` uses the RNG state after
`make_survey_data()` finishes, which is deterministic regardless of the outer `set.seed`.
The outer call is redundant and suggests the implementer needs to match seeds when in
fact only `make_survey_data(seed = 42L)` drives reproducibility.

The same pattern appears in `make_na_group_design()` in the PR 1 implementation notes.

Options:
- **[A]** Remove the outer `set.seed(42L)` from oracle setup and from the
  `make_na_group_design()` fixture notes. — Effort: trivial
- **[B]** Use a distinct outer seed (e.g., `set.seed(99L)`) to make clear that the
  `df$grp` assignment uses a separate seed from `make_survey_data`. — Effort: trivial,
  explicitly separates the two sources of randomness
- **[C] Do nothing** — works but confuses readers.

**Recommendation: A** — Remove the outer `set.seed()`. Add a one-line comment: "# grp
assignment uses RNG state from make_survey_data() — reproducible at seed = 42L".

---

**Issue 7: Spec pattern classification is inaccurate; plan has correct analysis**
Severity: SUGGESTION
Violates: engineering-preferences.md #5 (explicit over clever — implicit corrections
without noting the discrepancy create confusion)

The spec (§II) states Pattern A is used by `get_means()` and `get_totals()`, and Pattern B
by `get_quantiles()`. Checking the actual source:
- `analysis-means.R`: bare `unique(domain_data)` — no NA filter (neither Pattern A nor B)
- `analysis-totals.R`: bare `unique(domain_data)` — same
- `analysis-quantiles.R`: Pattern A (`complete.cases`) — not Pattern B

The plan correctly identifies these discrepancies in PR 3 ("Important behavioral note")
and PR 4 ("currently uses Pattern A") but does so silently, leaving the implementer to
reconcile the spec and plan for each function.

Options:
- **[A]** Add a "Spec correction" callout at the top of the implementation notes section
  summarizing the three inaccuracies in spec §II. Direct implementers to use the plan's
  code analysis, not the spec's pattern table. — Effort: trivial
- **[B] Do nothing** — the plan's function-level notes are accurate; the discrepancy is
  visible to a careful reader.

**Recommendation: A** — A two-line callout prevents the implementer from checking the
spec and second-guessing the correct pattern for each function.

---

**Issue 8: `get_freqs()` oracle uses continuous `y1` — produces excessive rows**
Severity: SUGGESTION
Violates: engineering-preferences.md #3 (engineered enough — unnecessary complexity
in the test setup)

The oracle test for `get_freqs()` uses `y1` (continuous numeric, `rnorm(n, mean=50, sd=10)`)
as the focal variable. With `n = 100L`, `y1` will have ~100 unique float values, so
`get_freqs(na_design, y1)` returns ~20 rows (one per unique `y1` value among NA-group rows
with ~20 observations) and the oracle comparison runs on a 20-element vector. The test is
technically correct but slow, verbose, and tests a degenerate use case of `get_freqs()`.

Using `y3` (binary 0/1, 2 levels) or the existing `group` column ("A"/"B"/"C", 3 levels)
would produce 2 or 3 rows, make the test readable, and test `get_freqs()` in its primary
use case (categorical focal variable). The oracle comparison also becomes more interpretable.

Options:
- **[A]** Replace `y1` with `y3` as the focal variable in the `get_freqs()` oracle test
  throughout the plan. — Effort: trivial, affects oracle setup only
- **[B]** Replace `y1` with the existing `group` column (already present in
  `make_survey_data()` output). — Effort: trivial (but `group` may share name with the
  new `grp` variable — pick whichever is cleaner)
- **[C] Do nothing** — functionally correct, just verbose.

**Recommendation: A** — `y3` (binary) is the clearest choice: it gives 2 rows in the
oracle comparison and is a standard `get_freqs()` use case.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The plan is structurally sound — PR sequencing is correct,
helper design matches spec architecture, and the per-function code changes are
accurately described. Two blocking issues prevent implementation: the non-existent
warning class propagated from the spec (Issue 1) and the missing `.apply_group_labels()`
update required for Test Block 7b (Issue 2). Both are resolvable in Stage 3 with clear
decisions — Issue 1 by widening the `== 1L` condition to `< 2L`, Issue 2 by descoping
Test Block 7b from this iteration. The plan is ready to implement after resolving the
two blockers and three required fixes.

---

## Plan Review: group-na-rows — Pass 2 (2026-03-02)

### Context

Full re-review of the implementation plan after Stage 3 resolution. Issues are
organized by section. Architecture and Code Quality issues trace to the same
underlying root causes found in the spec; Tests and Edge Cases issues are
plan-specific additions. All 16 issues resolved in-session.

### New Issues

---

#### Section: PR Map

**Issue 4 (Architecture): PR dependency sequencing not explicit**
Severity: SUGGESTION

The "depends on" label in the PR map does not explicitly state that PRs 2–5 must
wait for PR 1 to merge before branching. A developer cutting `fix/group-na-rows-freqs`
before PR 1 merges will get compile failures with no obvious cause.

Resolution: Added preamble note to PR map; added "branch from `develop` only
after PR 1 is merged" to each of PR 2–5 headers.

---

#### Section: PR 1 — Shared helpers and test fixtures

**Issue 1 (Architecture): `.apply_group_labels()` tagged-NA integration test is deferred to PR 2**
Severity: SUGGESTION

The `.apply_group_labels()` tagged-NA path is implemented in PR 1 but only
exercised via integration (Test Block 7b) in PR 2. A subtle bug in the helper
would only surface one PR later.

Resolution: Added checkbox to PR 1 acceptance criteria for a direct unit test
(synthetic vector with `na_tag` attribute — no full design required).

---

**Issue 2 (Architecture): `make_na_group_design()` RNG depends on `make_survey_data()` internal state**
Severity: REQUIRED

The `grp` and `grp2` assignments' `sample()` calls depend on whatever RNG state
`make_survey_data()` leaves. If `make_survey_data()` ever changes internally,
the NA indices shift silently, potentially invalidating oracle numerical values.

Resolution: Added `set.seed(seed + 1L)` after `make_survey_data()` call in the
fixture. Oracle correctness comparisons are not affected (both sides rebuild from
the same shifted `grp`), but structural stability is preserved.

---

**Issue 8 (Code Quality): `get_na_group_rows()` shared test helper not specified in PR 1**
Severity: SUGGESTION

The `na_row <- result[is.na(result$grp), ]` pattern was expected to be repeated
~48 times across 6 test files with no shared extraction helper.

Resolution: Added `get_na_group_rows(result, group_col)` to `helper-test-data.R`
fixture specification and PR 1 acceptance criteria.

---

#### Section: PR 1 — Implementation Notes (`.build_group_combos()`)

**Issue 5 (Code Quality): `rownames` ordering bug in `.build_group_combos()` code block**
Severity: REQUIRED

`rownames(combos) <- NULL` was placed before `combos[ord, , drop = FALSE]`. The
subsetting operation restores non-sequential rownames from the original row
positions. Fixed by assigning `combos <- combos[ord, , drop = FALSE]` then
resetting rownames.

Resolution: Fixed in both spec and impl plan code blocks.

---

**Issue 7 (Code Quality): `do.call(order, sort_args)` name collision with `order()` formals**
Severity: SUGGESTION

Named list from `lapply(names(combos), ...)` could collide with `order()`'s
named parameters (`decreasing`, `method`, `na.last`) if a group variable shares
that name.

Resolution: Changed to `unname(lapply(...))` + `c(sort_vecs, list(na.last = TRUE))`.

---

#### Section: PRs 2–5 — Oracle Tests

**Issue 6 (Code Quality): Oracle tests use `subset()` which emits surveycore warning**
Severity: REQUIRED

`subset(design_oracle, is.na(grp))` emits a `surveycore_warning_subset` on every
call. With 5 design classes × 6 functions = 30 oracle blocks, this produces 30
spurious warnings per `devtools::test()` run and may fail CI under `options(warn = 2)`.

Resolution: All oracle patterns updated to pre-filter the data frame:
`na_df <- df[is.na(df$grp), ]` then `as_survey(na_df, ...)`.

---

**Issue 9 (Tests): Oracle tests only compare point estimate, not SE**
Severity: REQUIRED

SE uses a separate variance engine path. A bug producing correct estimates but
wrong SEs would be invisible.

Resolution: Added `expect_equal(na_row$se, expected$se, tolerance = 1e-8)` to
all oracle blocks.

---

#### Section: Cross-cutting Oracle Notes

**Issue 10 (Tests): Multi-group oracle not specified**
Severity: REQUIRED

No oracle test existed for the two-column NA matching path in `.match_group_combo()`.

Resolution: Multi-group oracle section added for all 5 design classes per function.
30 additional oracle blocks total. Updated cross-cutting oracle notes with
multi-group example patterns.

---

#### Section: Quality Gates

**Issue 3 (Architecture): `< 2L` widening not in quality gates**
Severity: SUGGESTION

Resolution: Added grep-based gate to both spec §VII and impl plan quality gates.

---

**Issue 16 (Edge Cases): `testing-surveycore.md` says `weight` but actual column is `wt`**
Severity: BLOCKING (would cause 30 oracle construction failures at runtime)

Audited `helper-test-data.R` directly: weight column is `wt` (line 119:
`wt = wt`). The impl plan was already correct. `testing-surveycore.md` had the
wrong name.

Resolution: Fixed `testing-surveycore.md` — `weight` → `wt` in column layout
description and example code.

---

### Resolution Summary

| Issue | Section | Severity | Resolution |
|---|---|---|---|
| 1 | PR 1 acceptance criteria | SUGGESTION | `.apply_group_labels()` direct unit test added |
| 2 | PR 1 fixture | REQUIRED | `set.seed(seed + 1L)` added |
| 3 | Quality gates | SUGGESTION | `< 2L` grep gate added |
| 4 | PR map + PR 2–5 headers | SUGGESTION | Explicit branching note added |
| 5 | PR 1 `.build_group_combos()` | REQUIRED | `rownames` ordering fixed |
| 6 | PRs 2–5 oracle patterns | REQUIRED | `subset()` → pre-filtered data frame |
| 7 | PR 1 `.build_group_combos()` | SUGGESTION | `unname()` + positional `c()` |
| 8 | PR 1 fixtures | SUGGESTION | `get_na_group_rows()` helper added |
| 9 | PRs 2–5 oracle | REQUIRED | SE comparison added |
| 10 | Cross-cutting oracle notes | REQUIRED | Multi-group oracle specified |
| 16 | `testing-surveycore.md` | BLOCKING | `weight` → `wt` |

**Overall assessment:** Pass 1 caught the two blocking issues that would have
prevented implementation. Pass 2 found 3 additional required issues (RNG
fragility, `rownames` bug, `subset()` warnings), 1 blocking issue in a rules
file (`wt` column name), and 7 suggestions. All resolved. Plan is ready for
implementation.

---

## Plan Review: group-na-rows — Pass 3 (2026-03-02)

### Context

Six additional issues identified after the structured Pass 2 review that the
4-per-section cap prevented from being raised. All 6 resolved in the same
session.

### New Issues

---

**Issue 17 (Impl plan): Twophase oracle construction fully absent**
Severity: REQUIRED

The cross-cutting oracle notes had only a single-line note: "Add `grp` to
`df_p` before calling `as_survey_twophase()`." No code was shown. An implementer
writing the twophase oracle would have no guidance on the two-step
`phase1 → as_survey_twophase()` construction required for both the full design
and the oracle design.

Resolution: Expanded the "Twophase note" into a full implementation note with
both full design and oracle design construction code. Added note about
verifying the `phase2_flag` column name.

---

**Issue 18 (Impl plan): `na.rm = NA` validation not in PR 1 scope**
Severity: REQUIRED

The `surveycore_error_na_rm_not_logical` error class added to spec §V was not
reflected in the impl plan: no PR 1 acceptance criteria checkbox, no
implementation note for `.validate_shared_args()`, and no Test Block 8c
checkboxes in PRs 2–5.

Resolution: Added `.validate_shared_args()` acceptance criteria checkbox and
implementation note (with code) to PR 1. Added Test Block 8c checkbox to
PRs 2–5 acceptance criteria.

---

**Issue 19 (Impl plan): Block 5 reference not updated to 5a/5b**
Severity: REQUIRED

PR 2 acceptance criteria still said "Test Block 5: multi-group" (singular).
The spec split Block 5 into 5a/5b; the impl plan needed to match.

Resolution: PR 2 acceptance criteria updated to list Blocks 5a and 5b
separately.

---

**Issue 20 (Impl plan): Code blocks duplicated without sync annotation**
Severity: SUGGESTION

The impl plan contains verbatim copies of `.build_group_combos()`,
`.match_group_combo()`, the `make_na_group_design()` fixture, and the
`.validate_shared_args()` snippet. Future maintainers have no signal that
the spec is authoritative and the impl plan is a copy.

Resolution: "Sync note: spec §II/§V/§VI is authoritative" comments added
above each duplicated code block.

---

**Issue 21 (Impl plan): Blocks 7a/7b call sites absent for PRs 3, 4, 5**
Severity: REQUIRED

PR 3 had only "same fixture construction as PR 2"; PRs 4 and 5 had no
Blocks 7a/7b note at all. The call signatures differ per function.

Resolution: Explicit call sites added to PR 3 (get_means, get_totals),
PR 4 (get_corr with `c(y1, y2)`, get_quantiles with `probs = 0.5`), and
PR 5 (get_ratios with separate `y1, y2` arguments).

---

**Issue 22 (Impl plan): `n` column absent from oracle examples**
Severity: REQUIRED

PR 2 oracle example, cross-cutting single-group oracle, and multi-group oracle
all lacked `expect_equal(na_row$n, expected$n)`. Also, residual `subset()`
calls in PR 4 and PR 5 oracle notes had not been fixed.

Resolution: `expect_equal(...$n, expected$n)` added to all oracle examples.
Residual `subset()` calls in PR 4 and PR 5 replaced with pre-filtered data
frame construction (with `n` check included).

---

### Resolution Summary

| Issue | Section | Severity | Resolution |
|---|---|---|---|
| 17 | Cross-cutting notes | REQUIRED | Twophase oracle fully specified |
| 18 | PRs 1–5 scope | REQUIRED | `.validate_shared_args()` in PR 1; Block 8c in PRs 2–5 |
| 19 | PR 2 acceptance criteria | REQUIRED | Block 5 → 5a/5b |
| 20 | PR 1 code blocks | SUGGESTION | Sync note comments added |
| 21 | PRs 3–5 notes | REQUIRED | Explicit 7a/7b call sites added |
| 22 | PRs 2–5 oracles | REQUIRED | `n` column + `subset()` fixes |

**Overall assessment:** Pass 3 found 5 required issues and 1 suggestion
missed by the structured review cap. The most critical were the absent
twophase oracle construction (would cause runtime failures during
implementation) and the missing `na.rm = NA` impl plan scope (would leave
the fix incomplete). All resolved. Plan is now fully ready for
`/r-implement`.
