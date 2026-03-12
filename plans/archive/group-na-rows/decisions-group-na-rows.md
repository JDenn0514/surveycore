# Decisions Log — surveycore group-na-rows

This file records planning decisions made during group-na-rows.
Each entry corresponds to one planning session.

---

## 2026-03-02 — Stage 3 Spec Resolution (Issues 1–4)

### Context

Working through the Stage 2 adversarial review (`plans/spec-review-group-na-rows.md`).
Resolving the first four issues: a sort-order bug, a misleading stability comment,
a scope ambiguity about which functions need `.match_group_combo()`, and a missing
call-site example for `data_cols` construction.

### Questions & Decisions

**Q: Issue 1 — Should `rev()` be removed from `.build_group_combos()`?**
- Options considered:
  - **[A] Remove `rev()`:** Sort order matches §III example and existing Pattern A behavior (leftmost group var is primary key). Low effort, low risk.
  - **[B] Keep `rev()`, update example:** Documents a different sort order than current behavior. Low effort but diverges from existing convention.
- **Decision:** A — remove `rev()`
- **Rationale:** The §III example is clearly the intended behavior; `rev()` was a transcription error. Removing it aligns with the existing sort pattern in `analysis-freqs.R` lines 205–208.

**Q: Issue 2 — Should the "stable within each group" comment be dropped?**
- Options considered:
  - **[A] Add `method = "radix"`:** Guarantees stability explicitly.
  - **[B] Drop "stable" language:** `unique()` before `order()` eliminates true duplicates; the guarantee is vacuous. Honest contract.
- **Decision:** B — drop the "stable within each group" language; replaced with explicit note that leftmost group variable is the primary sort key.
- **Rationale:** Per engineering-preferences.md §5 (explicit over clever): a comment that promises something the code doesn't deliver is worse than no comment.

**Q: Issue 3 — Do all 6 functions actually have the inline `!is.na(gv_col) & (gv_col == cv)` loop?**
- Options considered:
  - **[A] Audit before writing spec:** Confirm scope explicitly; prevents implementer from guessing.
  - **[B] Leave to implementer:** Audit at implementation time.
- **Decision:** A — audited all 6 functions.
- **Rationale:** Audit confirmed all 6 functions (`get_freqs()`, `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`, `get_ratios()`) have the identical inline loop pattern. The QA gate is accurate; spec updated to state this explicitly.

**Q: Issue 4 — How should `data_cols` be constructed when calling `.match_group_combo()`?**
- Options considered:
  - **[A] Add call-site example in §II:** Shows `as.list(design@data[group_vars])` (full-length) with `active_mask <- domain_mask & group_match`. Eliminates all ambiguity.
  - **[B] Strengthen `@param` description only:** Partial clarity; still requires reader inference.
- **Decision:** A — added explicit call-site example to §II.
- **Rationale:** Two plausible interpretations existed (full-length vs. domain-filtered). Current code uses full-length; domain filter applied after via `&`. A concrete example removes the 50/50 ambiguity. Per engineering-preferences.md §5 (explicit over clever).

### Outcome

`.build_group_combos()` sort order corrected (leftmost group var = primary key); misleading "stable" comment removed; all 6 functions confirmed to have the inline loop; `data_cols` construction pattern made explicit with a call-site example in §II.

---

## 2026-03-02 — Stage 3 Spec Resolution (Issues 5–8)

### Context

Continuing through the Stage 2 adversarial review. Resolving four issues:
domain + NA group interaction contract, Test Block 6 missing `expect_warning()`,
`(NA, NA)` multi-group combination undocumented, and `@param na.rm` imprecision
for `get_freqs()`.

### Questions & Decisions

**Q: Issue 5 — Should the domain + NA group interaction be stated explicitly in §III?**
- Options considered:
  - **[A] Add one sentence to §III:** "When domain estimation is active, the NA group row is derived from domain-eligible rows only." Low effort, closes a BLOCKING ambiguity.
  - **[B] Add a test block instead:** Documents via tests; leaves spec prose ambiguous.
- **Decision:** A — added to §III after the `na.rm = FALSE` behavioral paragraph.
- **Rationale:** The behavior was already implied by `.build_group_combos()` taking `domain_data` (pre-filtered), but §III is where users look for the behavioral contract. Per engineering-preferences.md §5 (explicit over clever).

**Q: Issue 6 — Should Test Block 6 wrap the call in `expect_warning()`?**
- Options considered:
  - **[A] Wrap with `expect_warning(class = "surveycore_warning_single_group_level")`:** Correct per §III's unchanged warning trigger condition. The warning necessarily fires when all group values are NA (0 non-NA unique values < 2).
  - **[B] Suppress the warning for all-NA groups when `na.rm = FALSE`:** Cleaner UX but contradicts §III.
- **Decision:** A — Test Block 6 updated to use `expect_warning()` per testing-standards.md §3 warning capture pattern.
- **Rationale:** The warning firing is correct behavior per the spec's "unchanged" contract. The test was simply missing the capture.

**Q: Issue 7 — Should the `(NA, NA)` multi-group case be stated explicitly?**
- Options considered:
  - **[A] Add one sentence to §III multi-variable section:** Clarifies that simultaneous NAs across multiple group vars produce a single `(NA, NA, ...)` row.
  - **[B] Add a `(NA, NA)` case to Test Block 5 instead:** Documents via tests.
- **Decision:** A — added one sentence after the multi-variable group example table.
- **Rationale:** Common reader question; behavior follows naturally from `unique()` but is not obvious without the explicit statement. Per engineering-preferences.md §5.

**Q: Issue 8 — Should `get_freqs()` get a separate `@param na.rm` doc text?**
- Options considered:
  - **[A] Add `get_freqs()`-specific note in §IV:** Clarifies that `na.rm = FALSE` surfaces NA focal-variable values as a dedicated row, not just "included in calculations."
  - **[B] Accept unified text; flag as doc debt for the function body.**
- **Decision:** A (user preference) — §IV now specifies two templates: a unified one for 5 functions and a `get_freqs()`-specific extended version.
- **Rationale:** The behavioral difference (NA focal values → dedicated row vs. included in count) is significant enough to warrant separate doc text rather than leaving the distinction to the function body.

### Outcome

§III now specifies domain-first behavior for NA group rows; Test Block 6 correctly
captures the single-level group warning; the `(NA, NA)` multi-group case is
explicitly documented; and §IV provides separate `@param na.rm` text for
`get_freqs()` vs. the other five functions.

---

## 2026-03-02 — Stage 3 Spec Resolution (Issues 9–12)

### Context

Continuing through the Stage 2 adversarial review. Resolving: unresolved
`<estimate_col>` placeholders in two test blocks, missing multi-design-class
oracle test coverage, under-specified `label_values = TRUE` + haven-labeled NA
behavior, and DRY violation from per-file fixture construction.

### Questions & Decisions

**Q: Issue 9 — Should `<estimate_col>` placeholders be filled in per function?**
- Options considered:
  - **[A] Replace with actual column names per function:** Makes both Test Block 4 and the numerical oracle block copy-pasteable. Per-function lines added inline.
  - **[B] Add a reference table only:** Still requires manual substitution.
- **Decision:** A — both blocks now include per-function `expect_equal`/`expect_true` lines plus a reference table before §VI.
- **Rationale:** Per testing-standards.md §2; prevents 12 copy-paste errors across 6 test files.

**Q: Issue 10 — How should multi-design-class coverage be required?**
- Options considered:
  - **[C] Require numerical oracle test for each design class:** 5 classes × 6 functions = 30 targeted oracle comparisons. Targeted, practical.
  - **[A] Add a 7th test block per class:** Too many blocks.
- **Decision:** C — numerical oracle section updated to require repetition for all 5 design classes (`survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_srs`, `survey_nonprob`).
- **Rationale:** Oracle tests cover the variance path — the most likely source of per-class bugs — without multiplying all 7 test blocks by 5.

**Q: Issue 11 — Should the `label_values = TRUE` + NA group rows contract be extended for haven-labeled NAs?**
- Options considered:
  - **Original [A]:** One test block asserting regular NA remains `NA` in the factor.
  - **User extension:** Two test blocks — (7a) regular NA remains `NA`, (7b) haven-labeled NA (tagged NA with a value label, e.g., "Refused") is converted to a factor level using its label.
- **Decision:** Both test blocks added (7a and 7b). §III "Output column types" updated to explicitly distinguish between regular `NA` (no label → remains `NA`) and haven-labeled `NA` (has label → becomes factor level).
- **Rationale:** User-directed. Haven-labeled NAs carry semantic meaning (coded refusals, don't-knows) and should behave like any other labeled value under `label_values = TRUE`. The spec was silent on this case; the distinction is non-obvious and affects implementation.

**Q: Issue 12 — Should shared fixtures be specified in the spec?**
- Options considered:
  - **[A] Specify `make_na_group_design()` and `make_all_na_group_design()` helpers in §VI:** One definition shared across 6 test files.
  - **[B] Inline instructions per file:** Still duplicated.
- **Decision:** A — two helper function signatures added to §VI with implementation sketches. Both added to Quality Gates.
- **Rationale:** Per testing-standards.md §4 (repeated test setup → `helper-*.R`) and engineering-preferences.md §1 (DRY).

### Outcome

Test Blocks 4 and numerical oracle now have per-function column names; oracle
test required for all 5 design classes; §III distinguishes regular NA vs.
haven-labeled NA under `label_values = TRUE`; two new test blocks (7a, 7b) cover
both cases; shared fixtures specified in §VI and added to Quality Gates.

---

## 2026-03-02 — Stage 3 Spec Resolution (Issues 13–16)

### Context

Final batch of the Stage 2 adversarial review. Resolving: missing `group_by()`
integration test, `survey_nonprob` absent from the scope matrix, Test Block 6
fixture reference, and a wrong `code-style.md` citation.

### Questions & Decisions

**Q: Issue 13 — Should a test block for the `group_by()` code path be required?**
- Options considered:
  - **[A] Add required test block 8:** Calls `surveytidy::group_by(design, grp) |> get_X(x, na.rm = FALSE)`; asserts `anyNA(result$grp)`. Closes the `.resolve_groups()` integration gap.
  - **[B] Remove §VIII; state `group_by()` groups resolve into `group=` before processing.** Architectural change.
- **Decision:** A — test block 8 added.
- **Rationale:** §VIII makes a behavioral assertion about a distinct code path. A test is needed to verify that path works. Per engineering-preferences.md §2 (more tests is better) and testing-standards.md §3 (one behavior per block).

**Q: Issue 14 — Should `survey_nonprob` be added to the §I support matrix?**
- Options considered:
  - **[A] Add as 5th column:** Accurate — the class is already implemented and dispatched.
  - **[B] Explicitly exclude:** Misleading since it already exists.
- **Decision:** A — `survey_nonprob` added to the support matrix (now 5 design classes).
- **Rationale:** Scope statements must match reality. Omitting a dispatched class misleads reviewers into accepting code that breaks it.

**Q: Issue 15 — Should Test Block 6 reference `make_all_na_group_design()`?**
- Options considered:
  - **[A] Wire up the reference:** Replace inline `design_all_na_group` variable with `make_all_na_group_design(n = 100, seed = 1)` call.
  - **[C] Do nothing:** Issue 12's fixture is defined; the reference already exists by name.
- **Decision:** A — Test Block 6 updated to call the shared helper directly for self-documentation.
- **Rationale:** Self-contained test blocks per testing-standards.md §4. The helper is now defined; using it makes the test copy-pasteable.

**Q: Issue 16 — Should the wrong `code-style.md §4` citation be corrected?**
- Options considered:
  - **[A] Fix the citation in the spec:** Replace `code-style.md §4` with explicit prose stating analysis helpers live in `analysis-helpers.R`, not `utils.R`.
  - **[B] Update `code-style.md §4`:** Broader fix; appropriate as a separate PR.
- **Decision:** A — spec citation fixed. Separate issue filed mentally to update `code-style.md §4` when convenient.
- **Rationale:** A wrong rule reference sends the implementer to the wrong file. Low-effort fix; high leverage.

### Outcome

All 16 issues from the Stage 2 adversarial review are resolved. The spec now has:
10 required test blocks per function (8 numbered + helper unit tests + oracle),
oracle tests required for all 5 design classes, `survey_nonprob` in the scope
matrix, correct helper placement guidance, and self-contained Test Block 6.

---

## 2026-03-02 — Pass 2 Review: Architecture, Code Quality, Tests, Edge Cases (Issues 1–16)

### Context

Full adversarial re-review of both `spec-group-na-rows.md` and
`impl-group-na-rows.md` after the initial Stage 3 resolution sessions. Covered
four sections: Architecture (Issues 1–4), Code Quality (Issues 5–8), Tests
(Issues 9–12), Edge Cases (Issues 13–16). All decisions are Option A (recommended)
unless noted.

### Architecture Issues

**Q: Issue 1 — `.apply_group_labels()` tagged-NA path: add direct unit test in PR 1?**
- Decision: A — add a direct unit test (synthetic vector, no full design) in PR 1's
  acceptance criteria.
- Rationale: Catches bugs in `.apply_group_labels()` before PR 2 integration. Low
  effort, zero risk.

**Q: Issue 2 — RNG state chaining in `make_na_group_design()`: add `set.seed(seed + 1L)` after `make_survey_data()`?**
- Decision: A — add `set.seed(seed + 1L)` immediately after `make_survey_data()`
  call, before the `sample()` calls for `grp` and `grp2`.
- Rationale: Severs the fragile RNG dependency on `make_survey_data()` internals.
  One-line fix; oracle values change once on first run, then stabilize permanently.

**Q: Issue 3 — Warning condition widening (`== 1L` → `< 2L`) missing from §VII quality gates?**
- Decision: B (quality gate) — add `grep "uniq_lvls == 1L" R/analysis-*.R` gate
  to spec §VII and impl plan quality gates.
- Rationale: Single sentence creating a permanent safety net without adding
  per-PR acceptance criteria.

**Q: Issue 4 — PR dependency sequencing not explicit?**
- Decision: A — add branching note to PR map preamble and each of PR 2–5 headers.
- Rationale: Prevents a confusing compile failure if PRs 2–5 branch before PR 1
  merges.

### Code Quality Issues

**Q: Issue 5 — `rownames(combos) <- NULL` placed before subsetting (rownames bug)?**
- Decision: A — fix in both spec and impl plan: move `rownames(combos) <- NULL`
  to after `combos[ord, , drop = FALSE]`, assigning result to `combos` first.
- Rationale: Real spec error; returns data.frame with non-sequential rownames
  if copied verbatim.

**Q: Issue 6 — Oracle tests use `subset()` which emits surveycore warnings?**
- Decision: A — replace all `subset(design_oracle, is.na(grp))` patterns with
  pre-filtered data frame construction: `na_df <- df[is.na(df$grp), ]` then
  `as_survey(na_df, ...)`.
- Rationale: Eliminates 30 spurious warnings per test run; prevents CI failure
  under `options(warn = 2)`.

**Q: Issue 7 — `do.call(order, sort_args)` name collision with `order()` formals?**
- Decision: A — change to `unname(lapply(...))` + `c(sort_vecs, list(na.last = TRUE))`.
- Rationale: Two-line fix that permanently eliminates collision with `decreasing`,
  `method`, or `na.last` group variable names.

**Q: Issue 8 — `na_row` extraction pattern repeated ~48 times without a shared helper?**
- Decision: A — add `get_na_group_rows(result, group_col)` to `helper-test-data.R`.
- Rationale: Per engineering-preferences.md §1 (DRY). Single point of change for
  future evolution of NA-row extraction logic.

### Test Issues

**Q: Issue 9 — Oracle tests only verify point estimate, not SE?**
- Decision: A — add `expect_equal(na_row$se, expected$se, tolerance = 1e-8)` to
  every oracle block (single-group and multi-group).
- Rationale: SE uses a separate variance engine path; a bug producing correct
  estimates but wrong SEs would be invisible without this check.

**Q: Issue 10 — Multi-group oracle only for Taylor class, not all 5?**
- Decision: User directed — expand to all 5 design classes (same as single-group
  oracle). 5 × 6 = 30 additional multi-group oracle blocks.
- Rationale: Per-class variance path bugs are equally likely in multi-group
  paths as single-group paths.

**Q: Issue 11 — Test Block 6 (all-NA group) never verifies estimate value?**
- Decision: A — add `is.finite()` check + ungrouped oracle comparison to Block 6.
- Rationale: A bug producing `NA_real_` in the estimate passes all existing Block 6
  assertions. Oracle: ungrouped estimate should equal all-NA-group grouped estimate.

**Q: Issue 12 — Test Block 8 (`group_by()` path) missing `na.rm = TRUE` regression guard?**
- Decision: A — add Test Block 8b: `group_by()` + `na.rm = TRUE` (default).
- Rationale: Test Block 1 only guards the `group =` argument path. The `group_by()`
  path through `.resolve_groups()` is untested for the default behavior.

### Edge Case Issues

**Q: Issue 13 — Domain estimation + NA group interaction has no test block?**
- Decision: A (with clarification) — domain estimation in surveycore is via
  `surveytidy::filter()`, not a `domain =` argument. Test Block 9 uses
  `surveytidy::filter(design, y1 > 0)` to set the domain, then verifies NA group
  rows reflect only domain-eligible rows. Confirmed via `analysis-means.R:119`:
  `domain_mask <- .apply_domain(design)`.
- Rationale: The `active_mask <- domain_mask & group_match` interaction is the
  highest-risk unexercised code path in the spec.

**Q: Issue 14 — Zero-eligible combo behavior unspecified and untested?**
- Decision: A — add sentence to spec §III: "More generally, if `active_mask`
  selects zero rows for any group combo (NA or non-NA), that combo is silently
  dropped from the output." Test block added per function.
- Rationale: Closes a behavioral ambiguity that could manifest as NaN or crashes
  in production.

**Q: Issue 15 — `get_freqs()` focal-NA × group-NA combination untested?**
- Decision: A — add `get_freqs()`-only Test Block 10.
- Rationale: The cross-product of focal-variable NA rows within the NA-group row
  is a unique `get_freqs()` execution path not covered by any other test.

**Q: Issue 16 — `wt` vs `weight` column name contradiction?**
- Decision: A — audited `helper-test-data.R` directly. Confirmed: column is `wt`.
  Fixed `testing-surveycore.md` (said `weight`, now says `wt`). Impl plan was
  already correct.

### Outcome

All 16 issues resolved. Key changes:
- `.build_group_combos()` corrected (rownames ordering, `unname()` for `order()`
  collision safety)
- All oracle tests now use pre-filtered data frame construction (no `subset()`)
- SE comparison added to all oracle blocks (tolerance `1e-8`)
- Multi-group oracle expanded to all 5 design classes
- `get_na_group_rows()` shared test helper added
- Test Blocks 6, 8b, 9, 10 added to spec and impl plan
- Branching sequencing made explicit across PR map and PR 2–5 headers
- `testing-surveycore.md` weight column name corrected (`weight` → `wt`)

---

## 2026-03-02 — Stage 3 Plan Resolution (Issues 1–8)

### Context

Working through the Stage 2 adversarial review of the implementation plan
(`plans/plan-review-group-na-rows.md`). Resolving 8 issues: two blocking
(warning class mismatch, missing `.apply_group_labels()` update), three required
(changelog missing, `skip_if_not_installed` missing, wrong oracle call), and
three suggestions (redundant `set.seed()`, spec pattern table inaccuracy,
continuous focal variable in oracle).

### Questions & Decisions

**Q: Issue 1 — Warning class mismatch (`surveycore_warning_single_group_level` doesn't exist; condition `== 1L` doesn't fire for 0-level groups)**
- Options considered:
  - **[A] Widen existing condition to `< 2L`; use `surveycore_warning_single_level`:** No new class, minimal change, correct for both 0-level and 1-level cases.
  - **[B] Introduce a new warning class for the all-NA case:** More API surface; separate treatment of 0-level vs. 1-level.
- **Decision:** A — condition widened to `< 2L` in all 6 function PRs; correct class used throughout plan and spec.
- **Rationale:** Minimal correct fix. No new class needed. Per engineering-preferences.md §3 (engineered enough, not over).

**Q: Issue 2 — Should Test Block 7b (haven-tagged NA → factor level) be descoped or implemented?**
- Options considered:
  - **[A] Descope 7b:** Scope creep risk; tagged-NA conversion is an independent concern.
  - **[B] Implement `.apply_group_labels()` update in PR 1:** Keep the feature; use `attr(val, "na_tag")` (no `haven` runtime import needed).
- **Decision:** B (user preference) — PR 1 now includes `.apply_group_labels()` update with tagged-NA detection via `attr()`.
- **Rationale:** Tagged NAs carry semantic meaning (coded refusals, don't-knows) and should behave like other labeled values. The tagged-NA attribute approach avoids a runtime `haven` dependency. User explicitly wanted this included.

**Q: Issue 3 — One changelog file for the whole fix set, or one per PR?**
- Options considered:
  - **[A] Per-PR changelog files (5 total).**
  - **[B] Single file in PR 1; PRs 2–5 reference it.**
- **Decision:** A (user preference) — PR 2 creates `changelog/phase-1/fix-group-na-rows.md`; PRs 3–5 note "changelog created in PR 1."
- **Rationale:** User preference for one-per-PR consistency.

**Q: Issue 7 — Fix spec pattern table, or add a callout to the plan?**
- Options considered:
  - **[A] Add spec correction callout to plan.**
  - **[User direction] Fix the spec directly.**
- **Decision:** Fixed spec §II directly: Pattern A now correctly lists `get_freqs()`, `get_quantiles()`, `get_ratios()`; Pattern B lists `get_corr()` only; Pattern C (bare `unique()`) added for `get_means()` and `get_totals()`.
- **Rationale:** Correct primary source is better than a workaround note. Per engineering-preferences.md §5 (explicit over clever).

### Outcome

All 8 plan review issues resolved. Plan and spec are now consistent and correct.
Key changes: warning class and condition corrected across all 6 function PRs and
spec; `.apply_group_labels()` tagged-NA path added to PR 1 scope; spec pattern
table corrected; `get_freqs()` oracle updated to use `y3` (binary); redundant
`set.seed()` removed; `get_corr()` oracle call fixed.

---

## 2026-03-02 — Pass 3 Review: Six Additional Issues

### Context

After all 16 Pass 2 issues were resolved, 6 additional issues were identified
that the 4-per-section cap had prevented from being raised during the structured
review. All 6 applied to both the spec and the impl plan. User said "Apply fixes
for all six."

### Questions & Decisions

**Q: Issue 1/17 — Twophase oracle construction materially underspecified**
- Decision: A — add explicit two-step twophase oracle construction pattern to
  both spec §VI (numerical accuracy section) and impl plan cross-cutting notes.
  Includes full code showing `phase1 → as_survey_twophase()` construction for
  both the full design and the NA-filtered oracle design.
- Rationale: `as_survey_twophase()` requires a two-step construction that no
  other design class uses. Without an explicit example, implementers would either
  guess wrong or use `subset()` (which emits a warning). The note about
  `phase2_flag` column name verification prevents a silent runtime error.

**Q: Issue 2/18 — `na.rm = NA` unspecified and unhandled**
- Decision: A — add `surveycore_error_na_rm_not_logical` error class to spec §V
  with validation code in `.validate_shared_args()`; add to PR 1 acceptance
  criteria and implementation notes; add Test Block 8c checkbox to PRs 2–5.
- Rationale: `na.rm = NA` passes `isTRUE()`/`isFALSE()` checks silently and
  could propagate into subsetting logic as `NA`, causing wrong output or a
  cryptic error deep in the variance engine. A typed error with a clear message
  is always better than a silent wrong answer.

**Q: Issue 3/19 — Reverse multi-group NA case untested**
- Decision: A — split spec Test Block 5 into 5a (NA in first group var) and 5b
  (NA in second group var with inline fixture). Update PR 2 acceptance criteria
  to list Blocks 5a/5b separately.
- Rationale: The `for (gv in names(combo_row))` iteration order in
  `.match_group_combo()` is exercised differently depending on which column
  carries the NA. Block 5a exercises the first-column NA branch; Block 5b
  exercises the second-column NA branch. Without 5b, a name-ordering bug in the
  multi-group matching path would be invisible.

**Q: Issue 4/20 — Spec and impl plan duplicate all code blocks**
- Decision: A — add "Sync note: spec §II/§V/§VI is authoritative" comments
  above each duplicated code block in the impl plan (`.build_group_combos()`,
  `.match_group_combo()`, fixtures, `.validate_shared_args()`). Spec blocks
  remain the single authoritative source.
- Rationale: Duplication is unavoidable for impl plan readability, but the
  impl plan should not be treated as independent. Sync notes make the
  direction of authority explicit and prevent future divergence.

**Q: Issue 5/21 — Test Blocks 7a/7b underspecified for PRs 3–5**
- Decision: A — add explicit call sites to PR 3, PR 4, and PR 5 implementation
  notes, showing the exact function name + arguments + focal variable for each
  Block 7a/7b invocation.
- Rationale: The impl plan said "same fixture construction as PR 2" for each
  of PRs 3–5, but the call sites differ by function (`get_means()` takes `y1`,
  `get_corr()` takes `c(y1, y2)`, `get_ratios()` takes `y1, y2`, etc.). An
  implementer copying from PR 2 would use `get_freqs()` syntax and get compile
  errors or wrong behavior.

**Q: Issue 6/22 — `n` column on NA group rows never verified**
- Decision: A — add `expect_equal(na_row$n, expected$n)` to all oracle blocks
  in spec §VI and impl plan: PR 2 oracle example, cross-cutting single-group
  oracle, and cross-cutting multi-group oracle. Also add to PR 4 and PR 5
  oracle code examples.
- Rationale: `n` is the unweighted row count, computed by a separate counting
  path from the point estimate and SE. A bug that produces correct estimates
  but wrong row counts (e.g., returning 0 or total-design `n` instead of
  NA-group-only `n`) would be invisible without this check.

### Outcome

All 6 additional issues resolved. Key changes:
- Spec: twophase oracle construction pattern added to §VI; `make_na_group_design()`
  updated with `set.seed(seed + 1L)` (consistency with impl plan fix); Block 5
  split into 5a/5b; `na.rm = NA` error class added to §V; `n` column added to
  oracle blocks; multi-group oracle comment updated to reference two-step pattern
- Impl plan: twophase oracle fully specified in cross-cutting notes; `.validate_shared_args()`
  update added to PR 1 scope; Test Block 8c checkboxes added to PRs 2–5; Block 5
  updated to 5a/5b in PR 2 acceptance criteria; sync notes added to all duplicated
  code blocks; 7a/7b call sites added to PRs 3, 4, 5; `n` column added to PR 2
  oracle + cross-cutting oracle notes; residual `subset()` calls fixed in PR 4
  and PR 5 oracle notes

---
