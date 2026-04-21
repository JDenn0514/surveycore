# Decisions Log — surveycore sata-metadata

This file records planning decisions made during sata-metadata.
Each entry corresponds to one planning session.

---

## 2026-04-16 — Stage 4 Code Review Resolution

### Context

Working through 11 issues raised by the Stage 3 adversarial code review of
`plans/spec-sata-metadata.md`. All issues resolved in a single session.

### Questions & Decisions

**Q: Should `.get_data_for_select()` be a named helper or inlined?**
- Options considered:
  - **Reuse `.get_data_cols()` + `rlang::set_names()`:** Avoids new helper; character vector workaround.
  - **Named helper in `R/utils.R`:** `if (is.data.frame(x)) x else x@data`; two call sites (set_sata + extract_sata) meet the threshold.
  - **Inline everywhere:** No helper, simplest approach.
- **Decision:** Named helper `.get_data_for_select()` in `R/utils.R`.
- **Rationale:** Two confirmed call sites (set_sata + extract_sata) meet code-style.md §4's threshold for helper promotion. Clearer than the `set_names(seq_along(...))` workaround.

**Q: Should `sata = NA` be rejected or treated as FALSE?**
- Options considered:
  - **Reject with error:** `!is.na(sata)` added to validation.
  - **Treat NA as FALSE (unmark):** Silent coercion.
- **Decision:** Reject NA — error with `surveycore_error_sata_not_logical`.
- **Rationale:** NA has no meaningful interpretation as a SATA flag; silent coercion would confuse users.

**Q: Should `variable = character(0)` error or be a no-op?**
- Options considered:
  - **Error (same as "neither provided"):** Fail fast.
  - **No-op:** Permissive, mirrors R's for-loop behavior.
- **Decision:** Error — triggers `surveycore_error_sata_no_vars`.
- **Rationale:** Empty vector almost certainly indicates a logic error in the calling code.

**Q: Should `extract_sata()` use `.check_extractor_fill()` / `.format_scalar_result()`?**
- Options considered:
  - **Separate logical helpers:** `extract_sata()` uses inline fill validation + new `.format_logical_result()`.
  - **Extend shared helpers:** Modify existing infrastructure to accept logicals.
- **Decision:** Separate logical helpers — `extract_sata()` does NOT use `.check_extractor_fill()` or `.format_scalar_result()`.
- **Rationale:** Logical extractors are genuinely different from character extractors. Overloading shared helpers increases complexity and regression risk.

**Q: What happens with `fill = NULL` when specific variables are named in `...`?**
- Options considered:
  - **Allow, omit non-SATA vars from result:** Document explicitly; variables not marked SATA are absent from the returned vector/list/tibble.
  - **Disallow `fill = NULL` with explicit `...`:** Error if combined.
- **Decision:** Allow; omit non-SATA variables from result. Documented explicitly in behavior rule 1 and in a test case.
- **Rationale:** Coherent semantics; fix is documentation, not prohibition.

**Q: Should `extract_sata()` use tidyselect or `.resolve_vars()` for `...`?**
- Options considered:
  - **tidyselect (`eval_select`):** Matches `set_sata()`, supports `starts_with()`, `all_of()`, etc.
  - **`.resolve_vars()`:** Matches other extractors; bare names only.
- **Decision:** tidyselect — matching `set_sata()`.
- **Rationale:** Symmetric set/get API; users learn one, they learn the other.

**Q: Should `classify_question_type()` have a `variable =` programmatic interface?**
- Options considered:
  - **Add `variable = NULL`:** Mirrors `set_sata()` and `extract_sata()`; export functions pass character vectors naturally.
  - **Keep `...`-only:** Document `rlang::inject()` workaround.
- **Decision:** Add `variable = NULL`.
- **Rationale:** Export functions (the primary documented consumer) build variable lists programmatically. `...`-only forces awkward `rlang::inject()` contortions.

**Q: Should the function be named `detect_question_type()` or `classify_question_type()`?**
- Options considered:
  - **Keep `detect_question_type()`:** Established prefix; update description to match.
  - **Rename to `classify_question_type()`:** More precise; "classify" implies applying a rule to known information.
- **Decision:** Rename to `classify_question_type()`.
- **Rationale:** The function classifies based on explicit metadata (`sata` flags + `question_preface`); "detect" implies auto-discovery. Updated all spec references.

### Outcome

Spec v1.0 approved. All 11 code review issues resolved (3 blocking, 6 required,
2 suggestions). Ready for `/implementation-workflow`.

---

## 2026-04-16 — Stage 3 Implementation Plan Review Resolution

### Context

Working through 6 issues raised by the Stage 2 adversarial review of
`plans/impl-sata-metadata.md`. All resolved in a single session.

### Questions & Decisions

**Q: Should `fill = TRUE` be a valid value for `extract_sata()`?**
- Options considered:
  - **Restrict to `FALSE`/`NULL` only:** Error on `fill = TRUE` with `surveycore_error_sata_not_logical`. Simpler API; no untested path.
  - **Implement `fill = TRUE`:** Flip unmarked vars to `TRUE`; add logic + test.
- **Decision:** Restrict to `FALSE`/`NULL`; `fill = TRUE` errors.
- **Rationale:** No meaningful use case for `fill = TRUE`. Removing it eliminates an untested code path and a spec ambiguity.

**Q: Should warning snapshot tests be included for `classify_question_type()` warnings?**
- Options considered:
  - **Remove snapshot blocks:** Apply testing-standards.md consistently (warnings need `expect_warning(class=)` only).
  - **Keep as-is:** Extra coverage for warning message text regression.
- **Decision:** Remove warning snapshot blocks; use `expect_warning(class=)` only.
- **Rationale:** Consistency with testing-standards.md. Extra snapshots add maintenance overhead without a clear rule authorizing them.

### Outcome

Implementation plan approved. All 6 review issues resolved (1 blocking, 3 required,
2 suggestions). Added: coverage criteria to all 4 PRs, `fill = TRUE` error path,
`not_survey_or_df` tests for `set_sata()` and `extract_sata()`, explicit Step 4.4b
with line reference, corrected PR 4 dependency comment.

---
