# Decisions Log — surveycore survey-collection

This file records planning decisions made during survey-collection.
Each entry corresponds to one planning session.

---

## [2026-04-20] — survey_collection spec Stage 4 resolution

### Context

Stage 3 adversarial code review produced 19 issues against
`plans/spec-survey-collection.md` v0.1 (2 BLOCKING, 9 REQUIRED,
8 SUGGESTION). This session resolved every issue and locked the three
open questions from §IX.

### Questions & Decisions

**Q: How should `.on_missing` detect "variable not found" per survey?**
- Options considered:
  - **A — Catch `vctrs_error_subscript_oob`:** Low effort; couples to vctrs
    internal class. Dispatch-helper behavior depends on vctrs' error
    taxonomy remaining stable.
  - **B — New surveycore-owned `surveycore_error_variable_not_found`:**
    Every `get_*()` pre-checks tidy-select resolution and raises the class.
    Clean user-facing contract.
- **Decision:** B.
- **Rationale:** `.on_missing` is user-facing. Deterministic behavior trumps
  a couple of minutes saved; explicit over clever (engineering-preferences.md
  §5). New error class C10 added; each `get_*()` in §4.2 gains the
  pre-check.

**Q: Collision check runs after `.id` assignment, so it can never fire. Fix by
moving or replacing with `tibble::add_column()`?**
- Options considered:
  - **A — Move check before assignment:** Inspect first result's colnames
    before attaching `.id`; documented error class fires correctly.
  - **B — Use `tibble::add_column()`:** Let tibble catch the collision; wrap
    its error with the spec's class.
- **Decision:** A.
- **Rationale:** Simplest; keeps the surveycore-owned error class as the
  source of truth, no tibble-wording coupling.

**Q: `.meta` carry-over from first survey only silently drops surveys 2+
metadata. How to handle?**
- Options considered:
  - **A — Per-survey `.meta` under `$per_survey`:** Preserve each survey's
    meta; no information loss.
  - **B — Warn on divergence:** First-only carry-over but noisy warning.
  - **C — Error on divergence:** Too strict for real longitudinal survey
    data.
  - **D — Do nothing; document the limitation.**
- **Decision:** A + B combined.
- **Rationale:** A prevents silent data loss; B ensures users who don't
  introspect still see a warning. Downstream `clean()` / `gt()` helpers get
  a principled path to per-survey labels. New warning class C11 +
  `.warn_on_meta_divergence()` helper (§4.1.1). `.meta$collection` also
  gains `$survey_classes` (resolves Issue 19 Q2 at the same time).

**Q: Dispatch example signature uses `x` but actual `get_*()` uses `design`.**
- Options considered:
  - **A — Rewrite example using `design`:** Match implementation; add note
    about positional forwarding.
  - **B — Rename all `get_*()` first args to `x`:** Breaking change.
- **Decision:** A.
- **Rationale:** No reason to break the existing API for cosmetic
  consistency.

**Q: Is `get_diffs()` in the dispatch set?**
- Options considered:
  - **A — Include:** Takes a single design; does not call `survey_glm()`.
  - **B — Defer:** If `get_diffs()` internally used `survey_glm()`.
- **Decision:** A.
- **Rationale:** `get_diffs()` is domain-based Taylor linearization; no
  coupling to deferred regression work.

**Q: What should `.id` / `.on_missing` do when the first argument is a single
`survey_base` (not a collection)?**
- Options considered:
  - **A — Silently ignore; document explicitly:** Cleanest; no behavior
    change for existing callers.
  - **B — Emit info message on non-default:** Could be noisy.
  - **C — Always add `.id` constant column:** Breaking change to
    single-design return shape.
- **Decision:** A.
- **Rationale:** Backward compatible; each `@param .id` block explicitly
  says "Only used when first argument is a `survey_collection`; silently
  ignored otherwise."

**Q: Should `add_survey()` / `as_survey_collection()` error on duplicate
names, or auto-repair?**
- Options considered:
  - **A — Pre-check + error (Layer 3 dual):** Spec's original intent.
  - **B — Auto-suffix duplicates with `_N` and warn:** Matches
    `vctrs::vec_as_names(repair = "unique")` / `tibble::as_tibble` repair
    style.
- **Decision:** B (user-proposed during Issue 7; selected).
- **Rationale:** Better UX for real-world cases where users don't notice
  duplicate wave names. Warning surfaces the repair. Algorithm specified
  in §3.3.1. C2 becomes a validator-only backstop (direct
  `survey_collection(surveys = ...)` bypass); C2a is the new repair warning.

**Q: How should `survey_glm()` / `get_anova()` behave when called on a
`survey_collection` (they are explicitly deferred)?**
- Options considered:
  - **A — Dedicated error class:** `surveycore_error_collection_not_supported_by_fn`
    with deferral pointer.
  - **B — Rely on generic `surveycore_error_unsupported_class`.**
- **Decision:** A.
- **Rationale:** Specific, actionable error. Users discover the deferral
  rather than getting a generic "unsupported class" message. New class
  C12 added.

**Q: Should `add_survey()` accept a `survey_collection` for concatenation?**
- Options considered:
  - **A — No, keep simple:** Users splice via
    `as_survey_collection(!!!as.list(coll@surveys), ...)`.
  - **B — Yes, special-case collection input.**
- **Decision:** A.
- **Rationale:** Concatenation is rare enough that splicing is acceptable;
  keeps `add_survey()` single-purpose.

### Outcome

Spec reaches v1.0 (approved): 19 issues resolved, 3 new error classes
added to §VI (C10 `surveycore_error_variable_not_found`, C11
`surveycore_warning_collection_meta_divergence`, C12
`surveycore_error_collection_not_supported_by_fn`), one warning class
restructured (C2a `surveycore_warning_collection_duplicate_name_repaired`
replacing C2 as the common-case class; C2 retained as validator backstop
only). Test plan expanded with dispatch-identity oracles
(`get_means()`/`get_totals()`/`get_freqs()`), length-1 collection edge
test, `.meta` per-survey preservation + divergence warning tests, `.id`
collision dual-pattern test, `test_collection_invariants()` helper, and
coverage for all new error classes. Print method fully locked (big.mark,
class-name source, >20 abbreviation rule). Open questions in §IX closed.
Ready for `/implementation-workflow`.

---

## [2026-04-20] — survey_collection spec Stage 4 Pass 2 resolution

### Context

Stage 3 Pass 2 against `plans/spec-survey-collection.md` v1.0 produced 10
new issues (0 BLOCKING, 4 REQUIRED, 6 SUGGESTION). All 19 Pass 1 issues
were already resolved. This session closes the remaining 10.

### Questions & Decisions

**Q: `[[` method spec incorrectly claims integer OOB returns `NULL`.**
- Options considered:
  - **A — Correct the sentence + add tests:** Integer OOB errors (base list
    semantics); character OOB returns `NULL`.
  - **B — Force uniform NULL:** Override to diverge from base list semantics.
- **Decision:** A.
- **Rationale:** Matches what the method body (`x@surveys[[i]]`) already
  does. Diverging from base list semantics would be surprising.

**Q: Dispatch branch template must forward every named NSE arg, not rely on `...`.**
- Options considered:
  - **A — Expand template + NSE table + oracle tests:** Show
    `group = {{ group }}` forwarding explicitly; add `get_ratios()` as a
    second example; enumerate each function's NSE args; add NSE-exercising
    oracle tests.
  - **B — Move all NSE args into `...`:** Breaking refactor.
  - **C — Per-function appendix:** Show all 9 branches verbatim.
- **Decision:** A.
- **Rationale:** Named-NSE forwarding is the crux; an implementer copying
  the `x`-only template would silently drop `group` and produce wrong
  results. Oracle tests with `group =` set per function are the strongest
  safety net — if the template is wrong the oracle comparison fails.

**Q: `.id` / `.on_missing` — before or after `...`?**
- Options considered:
  - **A — After `...` (tidyverse named-only convention):** Matches existing
    `get_freqs(design, x, ..., group, names_to, ...)` placement and the
    §4.2 example. Update §4.3 wording; add a carve-out to
    `code-style.md §4`.
  - **B — Before `...` (strict read of current `code-style.md §4`):** Would
    create per-function inconsistency.
- **Decision:** A.
- **Rationale:** Post-`...` is already the package convention for
  named-only control args. The style rule was outdated. Added carve-out
  row 7 to `code-style.md §4` documenting that named-only control args go
  after `...`.

**Q: Scope of "requested variable" for `.on_missing` pre-check.**
- Options considered:
  - **A — Every declared NSE arg (x, group, numerator, denominator, by,
    treats, covariates):** Skip survey if any referenced var is absent.
  - **B — Only focal `x` counts.**
  - **C — Per-function decision table.**
- **Decision:** A.
- **Rationale:** A survey that can't supply every input the function
  requires cannot produce a comparable row; skipping whole rather than
  silently dropping group/covariate structure matches user intent. Added
  one illustrative test (`group = missing_in_s2`) to §7.1.5.

**Q: `.warn_on_meta_divergence()` — absence vs. presence policy.**
- Options considered:
  - **A — Absence counts as divergence (strict `identical()`); closed
    field set:** Warn for {value_labels, variable_label, question_preface}
    under $group$<var> and $x$<var>.
  - **B — Absence is non-divergent (only warn when both present and
    differ):** Quieter; misses "labels added in later wave."
  - **C — Field-aware severity tiers.**
- **Decision:** A.
- **Rationale:** Conservative; consistent with the already-specified
  strict `identical()`. Users adding labels in a later wave should be
  told earlier waves are unlabelled. Field set closed — future
  additions require explicit helper updates.

**Q: §IX Step 1 "add 9 rows" — fix the stale count.**
- **Decision:** Change to "every row in §VI" (resilient to future row
  additions).

**Q: §7.1 has 6/6a/7/7a numbering — renumber?**
- **Decision:** Renumber 1–11 clean.

**Q: Top-level `.meta` carry-over (first-survey) — is it load-bearing risk?**
- Options considered:
  - **A — Promote only when all surveys agree:** Empty top-level on
    divergence; consumers fall back to `$per_survey`.
  - **B — Document consumers:** Research required.
  - **C — Keep v1.0 policy:** First-survey top-level + `$per_survey` +
    divergence warning.
- **Decision:** C.
- **Rationale:** Divergence warning already fires; `$per_survey` is the
  documented principled path. Option A would require verifying
  downstream `clean()`/`gt()` handle empty top-level fields — extra
  implementation risk for marginal gain in v1.

**Q: C7 CLI template interpolates `{.id}` confusingly.**
- **Decision:** Add `id_name <- .id` local alias before the `cli_abort()`
  call; update C7 template accordingly. Cosmetic readability fix.

**Q: §IX Step 7 — PR granularity for nine per-function branches.**
- Options considered:
  - **A — One PR for all nine:** Mechanical change; reviewer inspects
    template once and scans consistency.
  - **B — Per-function PRs:** Nine PRs for ~27 lines of code; heavy
    overhead.
  - **C — Split by family:** No natural boundary.
- **Decision:** A.
- **Rationale:** Lighter review, all-or-nothing merge, reviewer can
  verify template consistency in one pass.

### Outcome

Spec advances to v1.1: §3.6 `[[` semantics corrected with base-list
integer-OOB behavior; §4.2 dispatch template expanded with explicit NSE
forwarding + per-function NSE arg table + `get_ratios()` second example;
§4.3 arg-order rewritten to document the post-`...` named-only convention
(with matching carve-out added to `code-style.md §4`); §III.4 scope
broadened to cover every declared NSE arg with illustrative §7.1.5 test;
§4.1.1 absence-vs-presence policy and closed field set documented; §IX
Step 1 count de-staled; §7.1 renumbered 1–11; C7 template readability
improved via local alias; §IX Step 7 locked as single bundled PR. Ready
for `/implementation-workflow`.

---

## [2026-04-20] — survey_collection implementation plan Stage 3 resolution

### Context

Stage 2 adversarial review of `plans/impl-survey-collection.md` produced
21 issues across two passes (4 BLOCKING, 8 REQUIRED, 9 SUGGESTION). This
session resolved every issue interactively. Spec `v1.1` was touched where
needed (real file paths in §II, test-file layout in §II, new error
classes C13/C14 in §VI, C10 pluralisation).

### Questions & Decisions

**Q: Numbered file paths (`R/00-s7-classes.R`, etc.) in plan are stale —
repo uses descriptive names.**
- **Decision:** Rewrite all paths to real names (`R/core-classes.R`,
  `R/core-constructors.R`, `R/methods-print.R`). Update spec §II and
  impl Tasks 1.0 / PR Files sections.
- **Rationale:** Stage-3-critical; `r-implement` would otherwise create
  files at wrong locations.

**Q: `get_pairwise()` listed in wrong file in PR 2 Files.**
- **Decision:** Co-locate with `get_t_test()` in `R/analysis-t-test.R`.
- **Rationale:** Matches shipped PR #88; avoids split.

**Q: C12 "collection not supported" guard is unreachable if placed after
`.check_unsupported_class()`.**
- **Decision:** C12 guard must be the literal first line of each of
  `survey_glm()` and `get_anova()`, above `.check_unsupported_class()`.
  Task 14.1 step 2 and Task 14.3 updated explicitly.
- **Rationale:** Specific C12 error beats generic "unsupported class"
  fallback; order is load-bearing.

**Q: Seven of the nine dispatched `get_*()` functions lack `...` in
their signatures, so `...`-forwarding dispatch template never matches
their real signatures.**
- **Decision:** Add `...` to all 9 signatures explicitly; new Task 14.0b
  provides a per-function before/after table. All nine edits commit
  together in Task 14.2.
- **Rationale:** Without `...`, `.id`/`.on_missing` cannot be
  forward-routed. Single commit keeps review mechanical.

**Q: S7 validator task pair (3.1 branch + 3.2 cli_abort conversion) is
DRY violation — existing validators use `cli_abort(..., class =)` inside
branches already.**
- **Decision:** Collapse into single Task 3.1 that writes the validator
  in its final form. Tasks renumbered (3.3 → 3.2, 3.4 → 3.3).
- **Rationale:** Verified against `R/core-classes.R` lines 225, 398,
  542 — existing pattern uses `cli_abort` directly in branches. No
  two-step transition needed.

**Q: `.precheck_vars_present()` needs to decide parent-frame vs NULL.**
- **Decision:** `parent = NULL`. Pseudocode pluralised with `{?s}` so
  one error lists all missing vars.
- **Rationale:** `.on_missing` is a user-facing contract; NULL parent
  gives a clean, stable call trace. Spec §VI C10 updated to match.

**Q: Caller-name extraction (`rlang::as_name(quo_get_expr(q))`) is
repeated in Tasks 5.1 and 9.1.**
- **Decision:** Extract `.resolve_caller_names(quosures)` helper in new
  Task 5.2b. Both call sites route through it.
- **Rationale:** DRY (engineering-preferences §1).

**Q: `.id` value must be validated (length-1 non-NA character).**
- **Decision:** Add C13 `surveycore_error_collection_invalid_id` in
  spec §VI. Task 13.1 step 0 validates `.id` via `.validate_id()`.
- **Rationale:** Sealing helper input contract; fails fast with typed
  error rather than cryptic downstream.

**Q: `vctrs::vec_rbind()` type-mismatch errors need surveycore wrapping.**
- **Decision:** Add C14 `surveycore_error_collection_bind_type_mismatch`
  in spec §VI. Task 13.1 step 7 wraps with `tryCatch` and rethrows as
  C14 carrying original condition.
- **Rationale:** Typed error class lets users handle this condition
  programmatically; keeps CLI message style consistent.

**Q: PR granularity — one code-style rule update blocks PR 2's nine
signature edits.**
- **Decision:** Split off PR 2a (`chore/code-style-named-only-carve-out`)
  as a tiny documentation-only PR landing before PR 2. Task 11.2 moved
  into PR 2a.
- **Rationale:** Un-blocks PR 2 review; PR 2a can merge in under a day.

**Q: `add_survey(coll)` no-arg behavior — silent no-op vs warn?**
- **Decision:** Silent no-op; document in `@details` roxygen.
- **Rationale:** Idempotent and consistent with tidyverse helpers; users
  who pass nothing almost always meant to, or the nothing came from a
  splat expansion.

**Q: Should tests written in Task 13.3 fail initially?**
- **Decision:** Yes — explicit RED-until-Task-14.6 comment. The test
  suite runs incrementally, so the dispatch tests stay RED through PR 2
  Tasks 13.x and only go GREEN once all nine per-function guards land in
  Task 14.6.
- **Rationale:** TDD discipline; the plan preserves the classic
  RED → GREEN sequence across the PR split.

### Outcome

Plan advances to approved status. Plan review file annotated with
resolution table for all 21 issues. Key artifacts added: PR 2a (tiny
code-style PR), new Tasks 5.2b / 14.0b, new error classes C13 + C14.
Spec §II paths corrected and test-file layout documented; §VI extended
to C14. Ready for `/r-implement` starting with PR 1 in the PR map.

---
