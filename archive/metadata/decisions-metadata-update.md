# Decisions Log — surveycore metadata-update

This file records planning decisions made during the metadata-update spec workflow.
Each entry corresponds to one planning session.

---

## 2026-03-10 — Stage 4: Resolve code review issues (spec-review-metadata-update.md)

### Context

Working through 15 issues identified in the adversarial code review (Pass 1).
Four were BLOCKING, seven REQUIRED, four SUGGESTION. All resolved in one session.

### Questions & Decisions

**Q: Issue 1 — How should `.parse_setter_input()` handle both old positional form detection (requires quosures) and Convention 2 type checking (requires evaluated values)?**
- Options considered:
  - **Option A:** Move old positional form detection to each setter caller using `rlang::enquos()`; `.parse_setter_input()` receives only evaluated values via `rlang::list2(...)`.
  - **Option B:** Pass both a quosures list and an evaluated list to `.parse_setter_input()`.
- **Decision:** Option A.
- **Rationale:** Separates NSE symbol detection (caller concern) from value parsing (shared helper concern). Clean, explicit, keeps the shared helper free of quosure mechanics.

**Q: Issue 2 — Should `.parse_setter_input()` have a `content_type` parameter to discriminate Convention 2 for scalar-content vs. vector-content setters?**
- Options considered:
  - **Option A:** Add `content_type = c("scalar", "vector")` parameter.
  - **Option B:** Remove Convention 2 detection from the helper entirely; handle per setter.
- **Decision:** Option A.
- **Rationale:** Minimal change, fully specifies the contract, keeps Convention 2 detection centralized.

**Q: Issue 4 — Should `.resolve_vars()` keep both `x` and `all_cols` parameters, or remove the redundant one?**
- Options considered:
  - **Option A:** Remove `all_cols`; compute via `.get_data_cols(x)` internally.
  - **Option B:** Remove `x`; callers pre-compute `all_cols`.
- **Decision:** Option A.
- **Rationale:** `x` is already available for data-masking context; internal computation is a one-liner.

**Q: Issue 8 — Should `extract_var_label()` and `extract_val_labels()` claim backward compatibility with old scalar/bare-vector return types?**
- Options considered:
  - **Option A:** Remove backward compat claim; document as breaking changes in NEWS.md.
  - **Option B:** Add `"scalar"` format option for single-variable calls.
- **Decision:** Option A.
- **Rationale:** The extractor signatures are changing substantially; acknowledging the break honestly is simpler and avoids a conditional return-type complexity.

**Q: Issue 13 — Should `extract_metadata()` always return all variables, or follow the same `fill = NULL` (omit) default as other extractors?**
- Options considered:
  - **Keep always-include design:** Add justification sentence only.
  - **Add `fill` argument:** `fill = NULL` (default) omits all-null variables; `fill = "include"` returns all.
- **Decision:** Add `fill` argument for consistency with other extractors.
- **Rationale:** User stated: "This should operate the same as other functions." Consistent API is more predictable. `fill = "include"` preserves the structural audit use case.

**Q: Issue 14 — Which dataset should replace `nhanes_2017` in Section 6.5 examples?**
- Options considered:
  - `gss_2024` (per CLAUDE.md convention).
  - `ns_wave1` (user preference — richer metadata including question_preface attributes).
- **Decision:** Use `ns_wave1`.
- **Rationale:** User stated `ns_wave1` has richer metadata, making it better for illustrating metadata API features (especially `question_preface` which NHANES and GSS lack in the dataset).

### Outcome

All 15 issues resolved. Spec updated to version 2.0 and approved. Breaking changes
(extractor return type changes + old positional setter removal) documented in
Section 8.3. `extract_metadata()` now has `fill` argument. `.parse_setter_input()`
clarified to receive only evaluated values; old positional detection moved to callers.
New error class `surveycore_error_setter_mixed_dots` (M-12) added.

---

## 2026-03-11 — Stage 4: Resolve code review issues Pass 2 (spec-review-metadata-update.md)

### Context

Working through 12 issues from the adversarial code review Pass 2 (all REQUIRED or SUGGESTION,
0 blocking). Issues concentrated in three areas: old-positional-form detection scope, underspecified
setter edge cases, and missing/incorrect test coverage.

### Questions & Decisions

**Q: Issue 16 — Should only `set_var_label()` do enquos + old-positional-form detection, or all six setters?**
- Options considered:
  - **Option A:** Restrict to `set_var_label()` only; other five setters use `rlang::list2(...)` directly.
  - **Option C:** Do nothing — five setters get dead quosure boilerplate.
- **Decision:** Option A.
- **Rationale:** Only `set_var_label()` had an old positional form. The five other setters never did. Consistent with the 2026-03-10 decision that moved old-positional detection to callers.

**Q: Issue 17 — Should `.parse_setter_input()` have an explicit `fn_name` parameter or recover caller name dynamically?**
- Options considered:
  - **Option A:** Add explicit `fn_name` string parameter.
  - **Option B:** Use `rlang::sys_call(-1L)` to recover dynamically (fragile).
- **Decision:** Option A.
- **Rationale:** Matches existing codebase pattern (`analysis-helpers.R`, `glm-methods.R`). Zero risk.

**Q: Issues 18 + 19 — Should scalar-content setters coerce non-character input, or always error?**
- Options considered:
  - **Coerce (Option A for 19):** Non-character scalars → `as.character()` with warning; length > 1 → error.
  - **Error only (Option B for 19):** Any non-character or length > 1 → `surveycore_error_label_not_scalar`.
- **Decision:** Error only (Issue 19 Option B). Unified rule added to Section 4.1 (Issue 18 Option A adjusted to error-only semantics). Sections 4.5, 4.6, 4.7 updated to reference Section 4.1.
- **Rationale:** Metadata setters should fail loudly. Silently converting `42L` to `"42"` hides likely typos. Simpler — one error class, no coercion logic.

**Q: Issue 20 — Should M-12 cover only mixed (some named, some unnamed) or any unnamed element in `...`?**
- Options considered:
  - **Option B:** Extend M-12 condition to `any(!has_name)` (any unnamed). Keep class name.
  - **Option A:** New M-14 for the all-unnamed case, keep M-12 for mixed-only.
- **Decision:** Option B.
- **Rationale:** "Unnamed elements in `...`" is a single coherent concept. Message already says "All `...` arguments must be named." No class rename needed.

**Q: Issue 21 — Convention 3 with `variable = character(0)`: silent no-op, error, or warn?**
- Options considered:
  - **Option A:** Silent no-op.
  - **Option B:** Error.
  - **User direction:** Issue a warning that nothing happened.
- **Decision:** Warn + no-op: issues `surveycore_warning_setter_empty_variables` (M-14) and returns `invisible(x)`.
- **Rationale:** Valid programmatic pattern when a filter produces zero entries at runtime. Warn so users are not silently confused if they expected something to happen.

**Q: Issue 22 — Should `set_missing_codes()` Convention 3 accept a bare atomic vector when `length(variable) == 1L`?**
- Options: Allow (parallel to `set_val_labels()`) vs. prohibit.
- **Decision:** Allow (Option A). Identical structure to `set_val_labels()` Section 4.4 exception.

**Q: Issue 23 — In `"list"` format, should `fill = NA_character_` yield `NA_character_` or `NULL` for scalar-content extractors?**
- Options: `NA_character_` for scalar fields, `NULL` for vector fields (Option A) vs. always `NULL` (Option B).
- **Decision:** Option A. `NA_character_` is meaningful for character scalar list entries. `NULL` reserved for vector fields where it signals "no labels set."

**Q: Issue 27 — Should `.format_list_result()` `fn_name` feed into M-6, or be removed as unused?**
- Options: Update M-6 to include `{fn_name}` (Option A) vs. remove unused param (Option B).
- **Decision:** Option A. More informative error messages. M-6 updated to `"{.fn {fn_name}} received an invalid {.arg format} value."`.

**Q: Issue 26 — Should invalid `fill` values produce an error?**
- Options: Add cross-reference + `surveycore_error_fill_invalid` validation (Option A) vs. do nothing.
- **Decision:** Option A. Validation prevents silent misbehavior when users mix `fill = "include"` and `fill = NA_character_` across the two function families.

### Outcome

All 12 Pass 2 issues resolved. Spec updated to version 3.0. New error/warning classes added:
`surveycore_error_label_not_scalar` (M-13), `surveycore_warning_setter_empty_variables` (M-14),
`surveycore_error_fill_invalid` (M-15). `.parse_setter_input()` gains `fn_name` parameter.
M-6 and M-12 message templates updated. Section 4.1 gains unified scalar-content validation
rule and documents extended M-12 and new M-14 behavior. Section 10.5 test plan expanded with
bare-vector exception tests, M-13/M-14 tests, data-frame M-9 test.

---

## 2026-03-11 — Stage 3: Resolve plan review issues (plan-review-metadata-update.md)

### Context

Working through 9 issues from the adversarial plan review (Pass 1): 1 BLOCKING, 5 REQUIRED,
3 SUGGESTIONS. All resolved in one session.

### Questions & Decisions

**Q: Issue 1 — Round-trip tests in PR 3 depend on PR 4's updated extractor API and cannot pass at PR 3 merge time. Where should they live?**
- Options considered:
  - **Option A:** Move the 6 round-trip test blocks to PR 4 Step 4.1.
  - **Option B:** Keep in PR 3 but write against the old scalar API; rewrite in PR 4.
- **Decision:** Option A.
- **Rationale:** The round-trip guarantee requires both setter (PR 3) and updated extractor (PR 4). The test belongs in the PR that completes the pair. Keeps both PRs independently mergeable and CI-passing.

**Q: Issue 2 — Changelog entries and NEWS.md breaking changes section were missing from all PRs. Add or skip?**
- **Decision:** Add. Changelog file added to each PR's Files section and acceptance criteria; NEWS.md step (Step 4.12) added to PR 4 with the 3 breaking changes from spec Section 8.3.
- **Rationale:** Required by the stage-2-review standard criteria and spec Section 8.3.

**Q: Issue 3 — `.resolve_vars()` had no direct tests in PR 2. Add or defer to PR 4?**
- Options considered:
  - **Option A:** Add direct test section in PR 2 Step 2.2 (5 blocks: empty → all cols, specified names, warning + skip, snapshot).
  - **Option B:** Move entirely to PR 4.
- **Decision:** Option A.
- **Rationale:** `.resolve_vars()` drives all extractor behavior. Its contracts must be verified at the PR where it is introduced.

**Q: Issue 4 — lifecycle dependency in PR 1 stated as fact with no verification step. Fix?**
- **Decision:** Changed PR 1 Notes to require an explicit `grep 'lifecycle' DESCRIPTION` check, with conditional DESCRIPTION update if missing.
- **Rationale:** Prevents opaque check failure at PR 3 with no guidance in the plan.

**Q: Issue 5 — 98%+ coverage gate absent from PRs 1–3. Add or leave only in PR 4?**
- Options considered:
  - **Option A:** Add `covr::package_coverage() ≥ 98%` to all three PRs.
  - **Option B:** Add only to PR 3.
- **Decision:** Option A.
- **Rationale:** Coverage is a per-PR gate, not a final-PR gate. Gaps should be caught early.

**Q: Issue 6 — `devtools::document()` missing from PR 2, PR 3, PR 4 acceptance criteria. Add?**
- **Decision:** Added to all three. PR 2 notes no .Rd changes expected; PR 3 notes 6 setter .Rd files; PR 4 notes new extractor .Rd files.
- **Rationale:** Required by r-package-conventions.md for any commit changing roxygen2 content.

**Q: Issue 7 — `air::format_package()` only in global Quality Gates footer, not per-PR criteria. Add?**
- **Decision:** Added to all four PR acceptance criteria.
- **Rationale:** Per-PR gate reduces risk of formatter being skipped under time pressure.

**Q: Issue 8 — PR 3 scope is large. Split into 3a (replacements) + 3b (new setters)?**
- Options considered:
  - **Option A:** Split into PR 3a + PR 3b.
  - **Option C:** Do nothing.
- **Decision:** Option C.
- **Rationale:** The step list is well-sequenced and the shared `.parse_setter_input()` infrastructure makes splitting awkward. Suggestion-only; no functional risk.

**Q: Issue 9 — No direct tests for `.format_scalar_result()` / `.format_list_result()` in PR 2. Add?**
- Options considered:
  - **Option A:** Add direct test sections (5 blocks for scalar, 4 for list).
  - **Option C:** Rely on indirect testing via PR 4 extractors.
- **Decision:** Option A.
- **Rationale:** Direct tests make debugging faster if an extractor test fails; the format helpers have non-trivial branching logic.

### Outcome

All 9 plan review issues resolved. Round-trip tests moved to PR 4. All four PRs now have
changelog, coverage, document, and formatter acceptance criteria. PR 2 gains direct test
sections for `.resolve_vars()`, `.format_scalar_result()`, and `.format_list_result()`.
PR 4 gains a NEWS.md step (Step 4.12) with the 3 breaking changes from spec Section 8.3.

---

## 2026-03-11 — Stage 3: Resolve plan review issues Pass 2 (plan-review-metadata-update.md)

### Context

Working through 7 issues from adversarial plan review Pass 2: 4 REQUIRED (Issues 10–13),
3 SUGGESTION (Issues 14–16). One REQUIRED issue (10) triggered a scope decision about
whether to deprecate or hard-delete the four plural setter functions.

### Questions & Decisions

**Q: Issue 10 — Should the four plural setters (`set_variable_labels()` etc.) be deprecated with `lifecycle::deprecate_soft()` wrappers, or deleted outright?**
- Options considered:
  - **Deprecate:** Wrap with `lifecycle::deprecate_soft()` wrappers (original plan). The `...`-forwarding bug in the template makes all four deprecated functions error on any real-world call with arguments.
  - **Delete:** Remove the four functions entirely. Package is pre-1.0, not on CRAN.
- **Decision:** Delete outright.
- **Rationale:** User stated deletion is simpler. Package is pre-1.0 with no CRAN release; no deprecation lifecycle is needed. Hard breaking removal is cleaner and avoids the `lifecycle` dependency entirely.

**Q: Issue 13 — Where should the `lifecycle` DESCRIPTION update go (PR 1 vs PR 3)?**
- **Decision:** Moot — `lifecycle` is never used (Issue 10 resolved by deletion). Removed the lifecycle DESCRIPTION check from PR 1 Notes entirely.
- **Rationale:** No `lifecycle::` calls anywhere in the plan means no `lifecycle` import is needed.

**Q: Issue 11 — Step 3.15 removes `.check_is_survey()` unconditionally. Make conditional?**
- **Decision:** Yes (Option A). Step 3.15 rewritten as two explicit sub-steps: run grep, remove ONLY if zero external callers found.
- **Rationale:** Prevents silent breakage of any caller outside the setter functions.

**Q: Issue 12 — Add `lintr::lint_package()` to Quality Gates and all PR criteria?**
- **Decision:** Yes (Option A). Added to the Quality Gates footer and to each of the four PR acceptance criteria.
- **Rationale:** Spec Section XI explicitly requires it; `air` does not enforce native pipe, snake_case, or `<-` assignment rules.

**Q: Issue 14 — Add `testthat::snapshot_review()` to PR 2 and PR 3 acceptance criteria?**
- **Decision:** Yes (Option A).
- **Rationale:** First-run snapshots auto-create and pass without review. PRs 2 and 3 generate 30+ new snapshots; per-PR review gate prevents unreviewed error text from being committed.

**Q: Issue 15 — Split PR 3 Step 3.2 (all 6 setters in one step) into per-setter TDD sub-steps?**
- **Decision:** Yes (Option A). Restructured into Steps 3.2a–3.2g, each followed by a confirm-fail run, then the implementation step, then a confirm-pass run.
- **Rationale:** Proper TDD cadence — one write/red/implement/green cycle per setter. Keeps each checkpoint small and diagnosable.

**Q: Issue 16 — Remove `extract_universe()` from the "Breaking Changes" NEWS.md item?**
- **Decision:** Yes (Option A). `extract_universe()` is a new function — it has no prior API to break. Moved to a new `### New Functions` section in Step 4.12 alongside `extract_missing_codes()` and `extract_metadata()`.
- **Rationale:** Accurate NEWS.md entries matter; inaccurate breaking-change listings confuse users.

### Outcome

All 7 Pass 2 issues resolved. Four plural setters (`set_variable_labels()` etc.) are now
hard-deleted rather than deprecated. `lifecycle` dependency removed from the plan entirely.
PR 3 steps restructured into per-setter TDD cycles (Steps 3.2a–3.2g). Step 4.12 now
produces both a `### Breaking Changes` section (4 items) and a `### New Functions` section
(5 functions). All four PR acceptance criteria include `lintr::lint_package()` and
`testthat::snapshot_review()`. Plan approved — ready for `/r-implement`.

---
