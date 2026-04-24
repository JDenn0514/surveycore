# Plan Review: collection-uniform-groups

Source plan: `/Users/jacobdennen/surveycore/plans/impl-collection-uniform-groups.md`
Spec: `plans/spec-collection-uniform-groups.md` (v0.3, approved)
Decisions: `plans/decisions-collection-uniform-groups.md` (Pass 1 + Pass 2)

---

## Plan Review: collection-uniform-groups — Pass 1 (2026-04-23)

### New Issues

#### Section: Decision block (plan §Design Decisions)

**Issue 1: Plan Decision 4 contradicts spec v0.3 / decisions log Issue 3**
Severity: BLOCKING
Violates spec coverage (Lens 4) and dependency ordering (Lens 2).

The plan's Decision 4 (lines 136–143) describes the `group =` / adopt-from-members fork but **omits the third case** that spec v0.3 §IV.behavior.2 and `decisions-...md` 2026-04-22 Q-Issue-3 resolved: when `group =` is supplied AND a member carries non-empty divergent `@groups`, the constructor must **override + warn G8** (`surveycore_warning_collection_group_overridden`), not error and not silently overwrite. The plan describes only "propagates `"region"` onto each member and errors if any member is missing the column" — which collapses override and error into the same branch and never references G8.

This blocks implementation: the implementer reading only the plan would write the pre-v0.2 behavior and miss the entire G8 warning path.

Options:
- **[A]** Rewrite plan Decision 4 to mirror spec §IV.behavior.2 exactly: enumerate the three sub-cases (empty member → silent propagate; identical → propagate; non-empty divergent → override + emit G8 warning, one per divergent member). Add an explicit back-reference to `decisions-...md` 2026-04-22 Q-Issue-3. — Effort: low, Risk: low, Impact: unblocks constructor task §2.
- **[B]** Delete Decision 4 from the plan and rely on the spec alone.
- **[C] Do nothing** — implementer silently reverts to Pass-1 behavior; G8 never lands; tests that expect G8 fail.

**Recommendation: A** — plan must carry the finalized decision verbatim; the decisions log already has the rationale to cite.

---

#### Section: PR Map / Files

**Issue 2: Plan places `[[<-` in `R/survey-collection.R`; spec says `R/methods-print.R`**
Severity: BLOCKING
Violates spec coverage (Lens 4) and file completeness (Lens 5).

- Plan §Files (line 77) says: `R/survey-collection.R — ... add S7::method("[[<-", survey_collection)`.
- Plan §Step-by-Step Tasks §4 header: `4. [[<- setter (R/survey-collection.R)`.
- Spec §II file map (line 77–80): `methods-print.R [MODIFY] ... add S7::method("[[<-", survey_collection) next to existing [[, length, names`.
- `decisions-...md` Q-Issue-15 Decision: A (colocate with existing `[[`, `length`, `names` in `R/methods-print.R`).
- Confirmed by source: `R/methods-print.R:796–798` holds `[[`, `length`, `names` for `survey_collection`.

Options:
- **[A]** Update plan §Files and §4 header to `R/methods-print.R`. Move the task description so the implementer knows the method goes next to `R/methods-print.R:796–798`. — Effort: low, Risk: low, Impact: aligns plan with spec.
- **[B]** Revisit Q-Issue-15 and move to `R/survey-collection.R`; update the spec and decisions log accordingly.
- **[C] Do nothing** — implementer picks the plan's wrong location, violates methods-grouped-by-type (`code-style.md §2`).

**Recommendation: A** — the decision is locked; plan must reflect it.

---

**Issue 3: Internal helpers `.check_groups_match()` and `.propagate_or_match()` are missing from the plan entirely**
Severity: BLOCKING
Violates spec coverage (Lens 4) and file completeness (Lens 5).

Spec §II (lines 94–160) requires two named internal helpers with documented signatures, placement (`R/survey-collection.R`), and a call-site mapping table explicitly cited in the decisions log (Q-Issue-1, Decision A). The plan never mentions these helpers — neither in §Files nor in the step-by-step tasks. The implementer would either reinvent them ad-hoc at each call site (re-introducing the DRY violation the spec explicitly closed) or attempt the string-tagged single-helper pattern that was explicitly rejected.

Options:
- **[A]** Add a new first task `§0. Internal helpers (R/survey-collection.R)` that implements `.check_groups_match()` and `.propagate_or_match()` per spec §II, followed by the existing tasks referring to these helpers by name. Update the §Files list to note helpers live in `R/survey-collection.R`. — Effort: low, Risk: low, Impact: closes DRY gap and unblocks constructor / add_survey / [[<- tasks.
- **[B]** Inline the logic at each site (explicitly regresses the Q-Issue-1 decision).
- **[C] Do nothing** — implementer will improvise; DRY violation returns.

**Recommendation: A** — the helpers are a spec deliverable with documented signatures; plan must mirror.

---

#### Section: Step-by-Step Tasks §1 (class definition / validator)

**Issue 4: Validator task only implements Invariant 1; missing Invariants 2 (G1b) and 3 (G1c)**
Severity: BLOCKING
Violates spec coverage (Lens 4).

Spec §III (lines 174–246) defines **three** validator invariants:
- Invariant 1 — equality across members (G1) ✓ covered by plan §1.2
- Invariant 2 — every column in `coll@groups` exists in each member's `@data` (G1b) ✗ absent from plan
- Invariant 3 — `@groups` is well-formed (no `NA`, no `""`, no duplicates) (G1c) ✗ absent from plan

The Pass 2 decisions log (Q-Issue-16, Q-Issue-18) explicitly chose "validator extension" over per-site checks for exactly these cases. Without them, propagation paths in `add_survey()` / `[[<-` can assign a mirrored `@groups` onto a member whose `@data` lacks the column (the G1b gap the spec calls out), and direct S7 construction can slip malformed vectors through.

Options:
- **[A]** Expand plan §1.2 into three numbered invariants matching spec §III: equality (G1 naming first divergent member), resolvability-in-`@data` (G1b naming first failing member and first missing column), well-formedness (G1c with one `"i"` bullet per failing condition). — Effort: low, Risk: low, Impact: closes all three invariant gaps.
- **[B]** Move G1b/G1c to a follow-up PR. Rejected by spec §IX and Pass 2 decisions.
- **[C] Do nothing** — spec gates fail (spec §XI quality-gate line "error classes G1, G1b, G1c, G2, G3, G4, G5, G5b, G6, G7, G7b, G8").

**Recommendation: A**.

---

#### Section: Step-by-Step Tasks §2 (constructor)

**Issue 5: Plan doesn't specify the `rlang::missing_arg()` / `quo_is_missing()` mechanism**
Severity: REQUIRED
Violates spec coverage (Lens 4) and "explicit over clever" (`engineering-preferences.md §5`).

Spec §IV signature (lines 280–298) and decisions log Q-Issue-5 lock in `group = rlang::missing_arg()` with absence detected via `rlang::quo_is_missing(rlang::enquo(group))`. Plan §2 says only "Add `group` parameter … named-only" without naming the mechanism. A naive implementer reaches for bare `missing(group)` (option B in Q-Issue-5, explicitly rejected), which does not compose with tidyselect quosure threading.

Options:
- **[A]** Add an explicit sub-step to §2.1 naming the `missing_arg()` default and the `quo_is_missing(enquo(group))` detection idiom.
- **[B]** Leave it to the implementer — they'll consult the spec anyway.
- **[C] Do nothing** — likely regression to bare `missing()`.

**Recommendation: A**.

---

**Issue 6: Constructor task doesn't describe the empty-resolution collapse**
Severity: REQUIRED
Violates spec coverage (Lens 4).

Spec §IV.arguments table and decisions log Q-Issue-4 lock in: `group = NULL`, `group = character(0)`, `group = c()`, and `group = all_of(character(0))` **all behave identically to `missing(group)`** — they fall through to the adopt-from-members branch. Plan §2.2 currently splits only on "If `group` supplied" vs "Else", which an implementer could read either way.

Options:
- **[A]** Rewrite §2.2's "If `group` supplied" line to "If `group` is supplied AND resolves to a non-empty character vector" and add one sentence noting empty resolutions collapse to the adopt-from-members branch. — Effort: low.
- **[B]** Add a dedicated sub-step enumerating the four empty forms.
- **[C] Do nothing** — implementer likely writes `if (!rlang::quo_is_missing(q))` and treats every supplied-but-empty resolution as a hard-error "no columns selected."

**Recommendation: A**.

---

**Issue 7: Constructor task missing the G8 override-warning sub-step**
Severity: BLOCKING
Violates spec coverage (Lens 4). Pairs with Issue 1.

Plan §2.2 covers "If `group` supplied: validate every member has all named columns; propagate to each member; set `coll@groups`." It skips the sub-case where a member already carries a non-empty `@groups` that differs from the resolved target — that path must emit G8 per spec §IV.behavior.2 / decisions log Q-Issue-3.

Options:
- **[A]** Inside §2.2 "If `group` supplied", split member handling into three branches: empty-member → silent propagate; identical → no-op; non-empty-divergent → propagate AND emit one G8 warning naming the member, its dropped groups, and the new target. — Effort: low, Risk: low.
- **[B]** Leave implicit; rely on spec.
- **[C] Do nothing** — G8 test block in spec §X fails.

**Recommendation: A**.

---

#### Section: Step-by-Step Tasks §3 (`add_survey()`)

**Issue 8: Atomicity guarantee from spec §V is not surfaced in the plan**
Severity: SUGGESTION
Violates "explicit over clever" (`engineering-preferences.md §5`).

Spec §V.atomicity (lines 368–372) and decisions log Q-Issue-19 explicitly state: "If any new survey errors during per-survey processing, no member is added and `coll` is unchanged." Plan §3 describes per-survey validation but doesn't articulate the atomicity contract. Current implementation pattern likely already satisfies it (errors raised before the single final `survey_collection()` construction), but an explicit note prevents a future refactor from moving mutation into the loop.

Options:
- **[A]** Add a one-line note to §3 ("Build the full validated member list first; only call `survey_collection()` once at the end so errors leave `coll` untouched") plus a pointer to the atomicity test in §8.
- **[B]** Leave implicit.

**Recommendation: A** — trivial to add, material for the regression test.

---

#### Section: Step-by-Step Tasks §4 (`[[<-` setter)

**Issue 9: Plan uses single `surveycore_error_collection_group_mismatch`; spec splits into G5 / G5b**
Severity: BLOCKING
Violates spec coverage (Lens 4) and "explicit over clever" (`engineering-preferences.md §5`).

Pass 2 decisions log Q-Issue-17 resolves Issue 17 by splitting:
- Replace path → `surveycore_error_collection_group_mismatch_on_replace` (G5)
- Append path → `surveycore_error_collection_group_mismatch_on_append` (G5b)

The plan §4.2 bullet 2 cites only `surveycore_error_collection_group_mismatch`, which is not a spec class at all. The plan §7 error-class table row for `[[<-` also uses the merged old name. And the plan does not describe the "classify replace-vs-append before groups check" restructuring required by spec §VI step 3 / decisions log Q-Issue-17 rationale ("the `[[<-` body is restructured so the replace/append classification happens before the `@groups` check").

Options:
- **[A]** Restructure plan §4 body into explicit steps: (1) validate `value` is `survey_base` (G6); (2) validate `i` shape (G7b); (3) **classify path** (character-matching-name or numeric-in-range → replace; otherwise → append with name repair); (4) validate `@groups` with the **path-specific error class** (G5 for replace, G5b for append); (5) assign + re-validate via constructor. Update the error table in §7 accordingly. — Effort: medium, Risk: low.
- **[B]** Single-class approach — explicitly regresses Q-Issue-17.
- **[C] Do nothing** — implementer likely writes one error class; tests that `expect_error(class = "..._on_append")` / `"..._on_replace"` fail.

**Recommendation: A**.

---

**Issue 10: Plan §4 does not describe replace-by-name (Pass 1 Issue 7A)**
Severity: BLOCKING
Violates spec coverage (Lens 4).

Spec §VI step 3 (lines 401–420) and decisions log Q-Issue-7 lock in: **character `i` matching an existing name replaces; does NOT run name repair; does NOT warn.** Plan §4.2 bullet 3 says "If character and new, run it through `.repair_collection_names()` alongside existing names and warn on repair" — this describes only the append sub-branch; it never mentions that matching-name character `i` should take a different path. An implementer reading the plan would run every character `i` through name repair.

Also missing from plan §4: `i == ""` (empty string) → route through append path; NULL assignment (`coll[[i]] <- NULL`) → error G6.

Options:
- **[A]** Rewrite plan §4.2 index-validation bullet into the spec's three character sub-branches (matching name → replace, no repair; new name → append + repair; `""` → append path) and two numeric sub-branches (`1:length` → replace; `length+1` → append + auto-name + repair). Add an explicit bullet: "`value = NULL` errors G6 before any shape check." — Effort: medium, Risk: low, Impact: closes spec §VI gap.
- **[B]** Point the implementer at spec §VI without rewriting.
- **[C] Do nothing** — implementer writes a single character-`i` branch; replace-by-name semantics regress.

**Recommendation: A**.

---

**Issue 11: Plan §4 missing `i`-shape validation (G7b)**
Severity: REQUIRED
Violates spec coverage (Lens 4).

Spec §VI step 2 requires an explicit `i` shape check rejecting multi-length, `NA`, logical, factor, zero-length, `NULL`, non-integer double, and negative — erroring G7b (`surveycore_error_collection_index_bad_type`). Plan §4.2 covers only "character or numeric in range", which would pass `i = factor("wave1")`, `i = 1.5`, `i = TRUE`, etc., through to the subsequent logic.

Options:
- **[A]** Add an explicit sub-step in §4 before classification: "Validate `i` is a length-1 atomic of class `character` or integerish-`numeric` (non-negative, non-`NA`). Anything else errors G7b." — Effort: low.
- **[B]** Inline the check inside the character/numeric split.

**Recommendation: A** — consolidating the type check ahead of classification matches spec §VI step 2.

---

#### Section: Step-by-Step Tasks §7 (error-message table)

**Issue 12: Plan error table is out of sync with spec §VIII on five rows**
Severity: BLOCKING
Violates spec coverage (Lens 4) and file completeness (Lens 5).

Spec §VIII runs G1, G1b, G1c, G2, G3, G4, G5, G5b, G6, G7, G7b, G8. Plan §7 runs G1, G2, G3 (divergent only), one merged G5-like row (`..._group_mismatch`), G6 (`not_survey_base`), and G7 (`index_out_of_range`). Missing rows:
- G1b (`..._group_not_in_member_data`)
- G1c (`..._groups_malformed`)
- G5 split into `..._group_mismatch_on_replace` and `..._group_mismatch_on_append`
- G7b (`..._index_bad_type`)
- G8 warning (`..._group_overridden`)

Plan §7 also notes `surveycore_error_not_survey_base` as "new; no existing row in error-messages.md" — this is fine; confirm row is added.

Options:
- **[A]** Replace plan §7 with a verbatim copy (or direct include) of spec §VIII rows, preserving `#` column so test blocks can cite them. — Effort: low, Risk: low.
- **[B]** Leave as-is; rely on spec.
- **[C] Do nothing** — spec §XI quality-gate check ("error-messages.md contains rows G1, G1b, G1c, …, G8") fails.

**Recommendation: A**.

---

#### Section: Step-by-Step Tasks §8 (tests)

**Issue 13: Test plan is missing ~two-thirds of the blocks spec §X requires**
Severity: BLOCKING
Violates spec coverage (Lens 4) and acceptance criteria (Lens 3).

Spec §X enumerates explicit test blocks. The plan's §8 is missing:
- Order-sensitivity Invariant 1 test (member `@groups = c("b","a")` vs coll `c("a","b")` → G1).
- G1b tests (direct construction; `add_survey()` propagation onto a member lacking the column; `[[<-` ditto).
- G1c tests (`NA`, `""`, duplicate `@groups`; multi-failure vector reporting multiple `"i"` bullets in one error).
- G8 warning tests (supplied `group =` over divergent members; mixed-members case emitting exactly one G8).
- Empty-`group =` forms block (NULL / `character(0)` / `c()` / `all_of(character(0))` → adopt-from-members).
- Atomicity test for `add_survey()` (multi-survey call, mid-loop failure, `coll` unchanged).
- Replace-by-name test (Issue 7A: existing name, length unchanged, no warning).
- Append-by-name with collision repair test.
- Empty-string name test (`coll[[""]] <- new`).
- NULL assignment test (`coll[[i]] <- NULL` → G6 for character and numeric `i`).
- `survey_collection` as `value` test (`coll[["x"]] <- other_collection` → G6).
- Bad-type `i` tests (G7b: `length > 1`, `NA_character_`, `TRUE`, factor, `1.5`, `-1L`, `integer(0)`, `NULL`).
- Same-set-different-order replace test (G5 with `c("region","stratum")` vs `c("stratum","region")`).
- Dispatch column-order assertion (`c(".survey", "region", "party", …)`).
- Helper additions to `helper-test-data.R`: `test_collection_groups_invariant()` (spec §X).

Options:
- **[A]** Replace plan §8 with the full list of spec §X test blocks, preserving their grouping (class invariant / constructor happy / constructor override / constructor error / add_survey matrix / `[[<-` matrix / `remove_survey` / dispatch / print snapshot). Add a line "Helper `test_collection_groups_invariant(coll)` added to `tests/testthat/helper-test-data.R`." — Effort: low (it's mostly paraphrasing spec §X), Risk: low.
- **[B]** Keep plan §8 terse and rely on spec §X.
- **[C] Do nothing** — implementer writes the shorter test suite; coverage gates and spec §XI fail.

**Recommendation: A** — the plan is the day-to-day reference the implementer uses; spec coverage must be explicit here.

---

**Issue 14: Plan §8 lists `test_invariants()` nowhere**
Severity: REQUIRED
Violates `testing-surveycore.md` (every constructor test must open with `test_invariants(design)`) and the spec §X helper note.

Spec §X requires both `test_invariants(coll)` (existing) and the new `test_collection_groups_invariant(coll)` as the first two assertions in every constructor-producing block. Plan §8 doesn't mention either — easy to forget under time pressure.

Options:
- **[A]** Add a standing bullet at the top of §8: "Every test block constructing a `survey_collection` calls `test_invariants(coll)` and `test_collection_groups_invariant(coll)` as its first two assertions." — Effort: low.
- **[B]** Leave to `testing-surveycore.md`.

**Recommendation: A**.

---

#### Section: Step-by-Step Tasks §10 (Decision 10, `remove_survey()`)

**Issue 15: Plan says "no code change" but spec §VII requires a one-line change**
Severity: REQUIRED
Violates spec coverage (Lens 4).

Spec §VII (lines 451–464) states: "**Code change required:** `remove_survey()` must pass `groups = x@groups` through to the reconstructed `survey_collection()` call, or the reconstruction loses the collection-level grouping. One-line change." Plan Decision 10 (lines 207–212) says "Uniform-groups invariant is preserved trivially after removal … No behavior change … No new code. Add a regression test." These disagree directly.

If the implementer follows the plan, `remove_survey()` drops to `survey_collection(new_list)` without passing `groups`, which defaults `@groups` to `character(0)` — silently de-grouping the collection on every remove.

Options:
- **[A]** Rewrite plan Decision 10 to mirror spec §VII: "Pass `groups = x@groups` through the reconstructed `survey_collection()` call. One-line change. Still no new error class; invariant preserved by propagation." Add an explicit implementation step in the task list (e.g., new §3.5 or §5.5 "Update `remove_survey()` (R/survey-collection.R)"). — Effort: low, Risk: low, Impact: closes the silent-degrouping bug.
- **[B]** Reconcile by updating the spec. Rejected — the spec is correct; the reconstruction currently defaults `@groups` to `character(0)`.
- **[C] Do nothing** — silently broken; regression test in plan §8 catches it, but it catches a bug that the plan's own code instructions didn't prevent.

**Recommendation: A**.

---

#### Section: Step-by-Step Tasks §9 (NEWS / docs)

**Issue 16: NEWS entry doesn't flag the breaking change; commit prefix not specified**
Severity: REQUIRED
Violates spec §XI quality gates (Lens 3 and 4).

Spec §XI requires:
- NEWS.md entry "lists: new `@groups` property, new `group =` argument, new `[[<-` method, **breaking change** that construction from divergent-grouped members now errors."
- Squash-merge conventional commit is `feat(classes)!:` (the `!` flags the breaking change per Conventional Commits).

Plan §9.1 lists three bullets but doesn't say "BREAKING CHANGE" anywhere, and plan §10 Verification doesn't mention the `feat(classes)!:` commit message requirement.

Options:
- **[A]** Add a fourth NEWS bullet explicitly headed "**Breaking change:** constructing a `survey_collection` from members with divergent `@groups` now errors (previously produced a mixed-output patchwork via dispatch)." Add a line to §10 Verification: "Squash-merge commit uses `feat(classes)!:` prefix to flag the breaking change." — Effort: low.
- **[B]** Leave to the release notes stage. Rejected — the bullet goes in the branch's commit.

**Recommendation: A**.

---

#### Section: Plan — acceptance criteria / verification

**Issue 17: §10 Verification is thin compared to spec §XI Quality Gates**
Severity: SUGGESTION
Violates acceptance-criteria completeness (Lens 3).

Spec §XI enumerates 8 gates. Plan §10 Verification cites only 4 bullets (`devtools::test()`, `devtools::check()`, `covr::package_coverage()`, manual smoke). Missing from the plan's verification:
- "All existing collection tests pass without snapshot updates beyond the grouped-print block."
- "Every new error class has `expect_error(class = ...)` + matching `expect_snapshot(error = TRUE)` for Layer 3."
- "`plans/error-messages.md` contains rows G1, G1b, G1c, G2, G3, G4, G5, G5b, G6, G7, G7b, G8."
- "`plans/decisions-...md` exists and captures every Stage 3 resolution." (already ✓ in repo, but the gate itself should be listed.)
- Coverage thresholds per-file (≥98% on changed files, ≥95% package-wide).

Options:
- **[A]** Replace plan §10 Verification with a direct transcription of spec §XI's 8 gates (or add a pointer: "See spec §XI for the authoritative quality-gate checklist; this section lists the local commands to run before the PR opens"). — Effort: low.
- **[B]** Leave the thin list; implementer consults spec §XI.

**Recommendation: A** — plan is the implementer's daily reference; gates should be visible there.

---

#### Section: PR granularity

**Issue 18: Single-PR scope is correct but should state the PR-size expectation**
Severity: SUGGESTION
Violates PR granularity (Lens 1) only mildly.

The single-PR decision is right: splitting the validator from the mutators creates a broken-invariant window. The PR is on the larger side for this repo, though — 3 modified R files + 1 new test file + `error-messages.md` + NEWS + `NAMESPACE` + helper-test-data.R addition + 2 snapshot files + 12 error-class rows + ~40 test blocks. Flag this explicitly so reviewers expect size; no split is warranted.

Options:
- **[A]** Add one sentence to plan §PR Map: "This is an atomically-scoped PR that touches ~3 R files and ~2 test files; reviewers should expect a larger diff than typical for this repo." — Effort: trivial.
- **[B]** Leave unstated.

**Recommendation: A**.

---

#### Section: Dispatch (§5)

**Issue 19: Dispatch "no code change" claim is worth an explicit regression-test hook**
Severity: SUGGESTION
Violates "explicit over clever" (`engineering-preferences.md §5`).

Plan §5 says a comment will be added at the top of `.dispatch_over_collection()` explaining the invariant. Good. But there's no verification the comment was actually added — no test can assert that — and `.resolve_groups()` at `R/analysis-helpers.R:441` is the actual contract point that must not regress. Plan §8's dispatch regression test already covers the happy path; consider naming `analysis-helpers.R:441` in §5 so the implementer knows which line to read before writing the comment.

Options:
- **[A]** Extend plan §5 with a reference: "Read `R/analysis-helpers.R:441` (`unique(c(from_groups_prop, from_arg))`) to confirm the contract before writing the comment; the dispatch test in §8 exercises column-order preservation."
- **[B]** Leave implicit.

**Recommendation: A** — cheap, prevents contract drift.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 8 |
| REQUIRED | 6 |
| SUGGESTION | 5 |

**Total issues:** 19

**Overall assessment:** The plan was drafted against spec v0.1/v0.2 and has not been brought forward to v0.3. Every Pass-2 decisions-log entry (2026-04-23: Issues 16–21 → G1b, G1c, G5/G5b split, atomicity doc, per-class test mechanics, order sensitivity) and one Pass-1 entry (Q-Issue-3 → G8 override warning) is absent from the plan. The error table, constructor, validator, and `[[<-` tasks all need rewrites to match spec v0.3, and the `remove_survey()` decision directly contradicts the spec. The plan's structural shape (single PR, task sequence) is sound and doesn't need rework — the content does. Resolve the 8 blocking issues and the plan is ready to hand to `/r-implement` or `/auto-ship`.

---

## Plan Review: collection-uniform-groups — Pass 2 (2026-04-23)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Plan Decision 4 contradicts spec v0.3 / decisions log Issue 3 | ✅ Resolved |
| 2 | Plan places `[[<-` in `R/survey-collection.R`; spec says `R/methods-print.R` | ✅ Resolved |
| 3 | Internal helpers missing from the plan entirely | ✅ Resolved |
| 4 | Validator task only implements Invariant 1 | ✅ Resolved |
| 5 | Plan doesn't specify `rlang::missing_arg()` / `quo_is_missing()` mechanism | ✅ Resolved |
| 6 | Constructor task doesn't describe empty-resolution collapse | ✅ Resolved |
| 7 | Constructor task missing G8 override-warning sub-step | ✅ Resolved |
| 8 | Atomicity guarantee not surfaced in the plan | ✅ Resolved |
| 9 | Plan uses single `..._group_mismatch`; spec splits G5 / G5b | ✅ Resolved |
| 10 | Plan §4 did not describe replace-by-name | ✅ Resolved |
| 11 | Plan §4 missing `i`-shape validation (G7b) | ✅ Resolved |
| 12 | Error table out of sync with spec §VIII | ✅ Resolved |
| 13 | Test plan missing ~two-thirds of spec §X | ✅ Resolved |
| 14 | Plan §8 lists `test_invariants()` nowhere | ✅ Resolved |
| 15 | `remove_survey()` "no code change" contradicts spec §VII | ✅ Resolved |
| 16 | NEWS doesn't flag breaking change; commit prefix not specified | ✅ Resolved |
| 17 | §10 Verification thin vs. spec §XI Quality Gates | ✅ Resolved |
| 18 | Single-PR scope fine but size expectation not stated | ✅ Resolved |
| 19 | Dispatch "no code change" claim worth an explicit contract reference | ✅ Resolved |

### New Issues

#### Section: §0 Internal helpers / `[[<-` cross-reference

**Issue 20: `.check_groups_match()` signature inherits a spec-level ambiguity on how it picks between G1 / G5 / G5b**
Severity: REQUIRED
Violates "explicit over clever" (`engineering-preferences.md §5`).

Spec §II gives `.check_groups_match(candidate_groups, target_groups, context)` with `@return "invisible(TRUE) on match; errors with the caller-appropriate class otherwise"` — no `error_class` parameter. But the helper is called from three sites that each raise a *different* class:

- Validator → G1 (`surveycore_error_collection_groups_invariant`)
- `[[<-` replace path → G5 (`surveycore_error_collection_group_mismatch_on_replace`)
- `[[<-` append path → G5b (`surveycore_error_collection_group_mismatch_on_append`)

Plan §0 step 1 mirrors spec §II verbatim. Plan §4 step 5 then calls `.check_groups_match(value@groups, x@groups, context = ...)` without saying how `context` is mapped to G5 vs G5b. An implementer reading this will either (a) invent an internal context-to-class lookup (hidden control flow the plan never documents) or (b) quietly grow the signature to take an explicit `error_class` argument (diverging from spec §II). The sibling helper `.propagate_or_match()` already takes `error_class` directly, which underlines the asymmetry.

Options:
- **[A]** Grow `.check_groups_match()` signature to `(candidate_groups, target_groups, error_class, context = NULL)` — `error_class` mandatory, `context` purely for message text. Update plan §0 step 1 to name the argument and plan §4 step 5 to pass `error_class = "..._on_replace"` / `"..._on_append"` explicitly. Validator passes `error_class = "..._groups_invariant"`. — Effort: low, Risk: low, Impact: removes the ambiguity and aligns with `.propagate_or_match()`.
- **[B]** Keep the spec §II signature and document an internal context → class lookup table inside the helper body (e.g., `"validator" → G1`, `"[[<- replace" → G5`, `"[[<- append" → G5b`). — Effort: low; adds hidden control flow the spec didn't explicitly bless.
- **[C] Do nothing** — implementer improvises one of A or B inconsistently with the other helpers.

**Recommendation: Option A** — asymmetry with `.propagate_or_match()` is itself a smell; explicit `error_class` matches the sibling helper and makes the call site unambiguous.

---

#### Section: §2 Constructor task body

**Issue 21: Constructor task doesn't name the final `survey_collection(surveys = …, groups = target)` construction step**
Severity: REQUIRED
Violates spec coverage (Lens 4).

Spec §IV.behavior.3 is explicit: "Construct `survey_collection(surveys = ..., groups = target)`; the validator re-asserts the invariant as a final backstop." Plan §2 step 2 ends with per-member `member@groups <- target` propagation in both branches but never names the final constructor call. Plan §2 step 3 is roxygen. The implementer must infer the construction step from context.

This is the same footgun `remove_survey()` hit before Pass 1 Issue 15 was resolved: if the implementer forgets to pass `groups = target` to the final constructor, the collection silently defaults to `@groups = character(0)` and the validator never fires at the correct level.

Options:
- **[A]** Insert a new §2 step 3 "Construct `survey_collection(surveys = propagated_members, groups = target)`; the validator backstop re-asserts G1 / G1b / G1c on construction" and renumber roxygen to step 4. — Effort: low, Risk: low.
- **[B]** Leave implicit; trust spec §IV.
- **[C] Do nothing** — risk the same silent-default regression Issue 15 just closed.

**Recommendation: Option A**.

---

#### Section: Plan Decision 2

**Issue 22: Plan Decision 2 omits the "ungrouped coll + grouped new → G4" case**
Severity: REQUIRED
Violates spec coverage (Lens 4) and decisions-block consistency.

Plan Decision 2 (lines 123–137) enumerates only the `coll@groups` non-empty branch:

> When `coll@groups` is non-empty and a caller runs `add_survey(coll, new)`:
> - If `new@groups` is already `identical(coll@groups)`: no-op, insert.
> - If `new@groups` is empty: propagate.
> - If `new@groups` is non-empty and differs: error G4.

Spec §V (the canonical 5-row Decision 2 matrix) includes the missing case "`coll@groups == character(0)` AND `new@groups` non-empty → error G4." Task §3 step 1 catches the case correctly ("If `.collection@groups` is empty and any new survey has non-empty `@groups`: error G4"), but the Decision block never names it. A reader who audits the plan top-down by reading each Decision in isolation ends up with an incomplete model.

Options:
- **[A]** Extend plan Decision 2 with the full 5-row matrix (empty/empty → insert; empty/non-empty → G4; non-empty/empty → propagate; non-empty/match → insert; non-empty/differ → G4). — Effort: low, Risk: low.
- **[B]** Leave the Decision 2 text as-is; task §3 already handles the case.
- **[C] Do nothing** — Decision block stays misleading; risk of regression in a later refactor that reads Decision 2 alone.

**Recommendation: Option A** — Decision blocks are the plan's standing summary of intended behavior; they must be complete.

---

#### Section: Plan §Files (Modified / Created)

**Issue 23: `tests/testthat/helper-test-data.R`, `tests/testthat/_snaps/`, and `NEWS.md` are touched by tasks but missing from §Files**
Severity: SUGGESTION
Violates file completeness (Lens 5).

Plan §8 adds a `test_collection_groups_invariant()` helper to `tests/testthat/helper-test-data.R`; plan §6.2 updates the `test-methods-print.R` snapshot (which lives under `tests/testthat/_snaps/`); plan §9 adds four `NEWS.md` bullets. None of these three files appears in §Files Modified. Not load-bearing — the implementer will touch each file when the corresponding task fires — but the §Files list is the fastest way to scope the diff before reading task-by-task.

Options:
- **[A]** Add three bullets to §Files Modified: `tests/testthat/helper-test-data.R` (new helper), `tests/testthat/_snaps/methods-print.md` (grouped-collection snapshot), `NEWS.md` (breaking-change bullets). — Effort: trivial.
- **[B]** Leave implicit.

**Recommendation: Option A**.

---

#### Section: §1 Validator task

**Issue 24: Validator task §1 doesn't describe the iteration structure for Invariant 1 (how to find the first divergent member)**
Severity: SUGGESTION
Violates "explicit over clever" (`engineering-preferences.md §5`).

Plan §1 step 2 Invariant 1 says "For each `self@surveys[[i]]`, assert `identical(self@surveys[[i]]@groups, self@groups)` … naming the **first divergent member by name** (not index)." But the plan doesn't say the implementation is a loop that early-exits on first mismatch, versus a vectorised `vapply()` over all members then picks the first `FALSE`. Either works; for large collections the early-exit loop is cheaper. If the implementer reaches for `.check_groups_match()` (task §0), which is per-pair equality, the loop structure emerges naturally.

Options:
- **[A]** One-sentence note in §1 step 2 Invariant 1: "Iterate `seq_along(self@surveys)` and call `.check_groups_match()` per member; exit on first mismatch, naming that member (by name, not index) in the G1 error." — Effort: trivial.
- **[B]** Leave implicit.

**Recommendation: Option A**.

---

#### Section: §3 `add_survey()` task

**Issue 25: `add_survey()` step 1 doesn't explicitly name the `.propagate_or_match()` call site**
Severity: SUGGESTION
Violates DRY / "explicit over clever".

Plan §3 step 1 inlines the decision-2 logic ("If `.collection@groups` is empty and any new survey has non-empty `@groups`: error G4. If `.collection@groups` is non-empty: for each new survey, propagate when its `@groups` is empty, error on mismatch."). The second branch is exactly what `.propagate_or_match()` from task §0 does. Naming the helper explicitly reinforces the call-site mapping in spec §II and prevents the implementer from inlining the equality check a third time.

Options:
- **[A]** Rewrite §3 step 1 bullet 2 to: "If `.collection@groups` is non-empty: for each new survey, call `.propagate_or_match(new@groups, .collection@groups, name, 'surveycore_error_collection_group_conflict')` and replace `new@groups` with the return value."
- **[B]** Leave implicit.

**Recommendation: Option A**.

---

#### Section: §6 Print method task

**Issue 26: §6 could cite the exact insertion line numbers**
Severity: SUGGESTION

Spec §III Print method names the relevant line numbers (`R/methods-print.R:772` for the header line; `.fmt_collection_line()` at `R/methods-print.R:760–767` for the member listing). Plan §6 says "print a `Groups:` line under the collection header" without the line references. Not a gap — the implementer can grep — but trivially small edit.

Options:
- **[A]** Add parenthetical "(insert after the header line at `R/methods-print.R:772` and before the `.fmt_collection_line()` output at lines 760–767)". — Effort: trivial.
- **[B]** Leave implicit.

**Recommendation: Option A**.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 4 |

**Total issues:** 7

**Overall assessment:** Pass 1 closed every spec-coverage gap. Pass 2 issues are all second-order: signature ambiguity in `.check_groups_match()`, an unnamed final constructor call in §2, and an incomplete Decision 2 matrix (three REQUIRED items where the plan is consistent with the spec but could misdirect a close-reading implementer), plus four small tightening suggestions. No architectural rework needed — resolve the three REQUIRED items and the plan is ready to hand to `/r-implement` or `/auto-ship`.
