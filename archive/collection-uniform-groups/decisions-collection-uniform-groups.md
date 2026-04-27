# Decisions Log — surveycore collection-uniform-groups

This file records planning decisions made during collection-uniform-groups.
Each entry corresponds to one planning session.

---

## [2026-04-22] — Stage 4: Resolve Stage 3 code-review issues

### Context

Worked through 15 issues from `plans/spec-review-collection-uniform-groups.md`
(Pass 1: 2 BLOCKING, 8 REQUIRED, 5 SUGGESTION) and updated the spec
(`plans/spec-collection-uniform-groups.md`) before handoff to
`/implementation-workflow`.

### Questions & Decisions

**Q: Issue 1 — can a single `.check_groups_match()` helper serve the constructor,
`add_survey()`, and `[[<-`?**
- Options considered:
  - **A (two helpers):** equality-only `.check_groups_match()` for validator + `[[<-`,
    plus `.propagate_or_match()` for `add_survey()`; constructor `group =` inlined
    because it needs override-with-warning semantics.
  - **B (tagged action):** single helper returning `list(action = "ok"|"propagate"|"error")`.
- **Decision:** A.
- **Rationale:** Two narrowly-scoped helpers each encode one acceptance rule clearly;
  string-tagged control flow (B) is the opaque pattern `engineering-preferences.md §5`
  explicitly rejects. Constructor with `group =` has a *third* rule (warn + override)
  after Issue 3 was decided, so inlining at that single site is preferable to widening
  either helper.

**Q: Issue 3 — when `as_survey_collection(group = X)` is supplied and a member already
has a non-empty `@groups` that differs from `X`, what happens?**
- Options considered:
  - **A (error):** reuse G2 / add a new divergence class; force user to `ungroup()` first.
    Symmetric with `[[<-`'s Decision 3 posture.
  - **B (silent override + new warning):** propagate `X` onto the member, discarding
    pre-existing groups, but emit `surveycore_warning_collection_group_overridden` (G8).
- **Decision:** B.
- **Rationale:** User chose override-with-warning over error. This treats
  `as_survey_collection(group =)` as a declarative "I want the collection grouped this
  way" and surfaces any silent data loss through a typed warning. A new class
  `surveycore_warning_collection_group_overridden` (G8) was added to the error table.
  The constructor is the one site on the spectrum where "validate, don't coerce"
  bends — `[[<-` keeps its stricter posture (G5 error).

**Q: Issue 4 — how do empty forms of `group =` behave? (`NULL`, `character(0)`,
`c()`, `all_of(character(0))`)**
- Options considered:
  - **A:** Treat all four as equivalent to `missing(group)` — falls to the
    adopt-from-members branch. Consistent with tidyselect conventions.
  - **B:** Error with a new `surveycore_error_collection_group_empty` class.
- **Decision:** A.
- **Rationale:** Tidyselect empty-resolution is a no-op everywhere else in the
  surveyverse; a user who programmatically builds up a `group` vector should not
  need a special case. Adding an error class for a rare, easily-handled case
  violates `engineering-preferences.md §3` (engineered enough).

**Q: Issue 5 — what mechanism detects a missing `group` argument?**
- Options considered:
  - **A:** `group = rlang::missing_arg()` with
    `rlang::quo_is_missing(rlang::enquo(group))`.
  - **B:** Base `missing(group)`.
- **Decision:** A.
- **Rationale:** Matches surveycore's other tidy-select arguments and cleanly
  threads the quosure into tidyselect evaluation when `group` is supplied.

**Q: Issue 6 — is `@groups` order part of the invariant?**
- Options considered:
  - **A:** Order IS part of the invariant — keep `identical()`; surveytidy must
    respect order when setting both sides.
  - **B:** Loosen to `setequal()`.
- **Decision:** A.
- **Rationale:** Order carries semantic meaning in `.resolve_groups()` at
  `R/analysis-helpers.R:441` (`unique(c(from_groups_prop, from_arg))`), which
  determines downstream column order in `get_means()` output. `group_by(region,
  stratum)` and `group_by(stratum, region)` produce different row orderings.
  Keeping `identical()` preserves that semantic link.

**Q: Issue 7 (BLOCKING) — does character `i` matching an existing member name
replace or append-with-repair?**
- Options considered:
  - **A:** Split: matching name → replace (base R `[[<-` semantics, length
    unchanged, no warning); non-matching name → append + name repair.
  - **B:** Reject matching-name character `i` entirely.
- **Decision:** A.
- **Rationale:** Standard base-R list semantics; symmetric with numeric `i`
  (`i %in% seq_len(length)` replaces, `i == length + 1L` appends). Also fixed
  the `i = ""` edge case (routed through append path).

**Q: Issue 9 — what does `coll[[i]] <- NULL` do?**
- Options considered:
  - **A:** Error with G6 — `[[<-` does not delete; use `remove_survey()`.
  - **B:** Delegate to `remove_survey()`.
- **Decision:** A.
- **Rationale:** Prevents silent data loss when an RHS variable accidentally
  becomes NULL (common R bug pattern); keeps `[[<-` single-purpose; preserves
  symmetry with every other non-`survey_base` value that already errors G6;
  and the explicit removal API (`remove_survey()`) already exists.

**Q: Issue 12 — split G7 into out-of-range vs. bad-type classes?**
- Options considered:
  - **A:** Split into `surveycore_error_collection_index_out_of_range` (G7) and
    `surveycore_error_collection_index_bad_type` (G7b).
  - **B:** Keep a single G7 class; distinguish via message text.
- **Decision:** A.
- **Rationale:** User chose finer-grained classes. This improves programmatic
  error handling at the cost of one extra class/row — a reasonable trade for
  an API that may be called from higher-level tooling.

**Q: Issue 15 — where does `S7::method("[[<-", survey_collection)` live?**
- Options considered:
  - **A:** Colocate with existing accessors `[[`, `length`, `names` in
    `R/methods-print.R`.
  - **B:** Colocate with `add_survey()` / `remove_survey()` in
    `R/survey-collection.R` (feature-group placement).
- **Decision:** A.
- **Rationale:** `code-style.md §2` prefers methods-grouped-by-type; the
  accessor family stays together. `R/methods-print.R`'s name is a historical
  artifact (it already houses non-print methods) — a rename is out of scope
  for this spec.

### Outcome

Spec v0.2 is methodology-locked and code-review-resolved: two new internal
helpers with a documented call-site map; constructor `group =` uses
`rlang::missing_arg()` dispatch and warns-then-overrides via new G8; empty
`group =` forms collapse to `missing`; validator and `[[<-` use order-sensitive
`identical()`; character `i` matching an existing name replaces (base-R
semantics); NULL assignment errors G6; G7 split into G7 (range) and G7b
(type); test plan now covers all decided behaviors explicitly; `[[<-` is
implemented next to `[[` in `R/methods-print.R`.

---

## [2026-04-23] — Stage 4: Resolve Stage 3 Pass 2 code-review issues

### Context

Worked through the 6 issues raised in Pass 2 of
`plans/spec-review-collection-uniform-groups.md` (1 REQUIRED, 5 SUGGESTION)
after v0.2 was written. These arose from reading v0.2 as an integrated
whole and are additive to Pass 1's resolutions. Spec bumped to v0.3.

### Questions & Decisions

**Q: Issue 16 (REQUIRED) — propagation paths (`add_survey()`, `[[<-`) do
not validate that the grouping columns exist in the incoming member's
`@data`. How is the gap closed?**
- Options considered:
  - **A (per-site check):** add a column-existence check inside
    `.propagate_or_match()` and at the `[[<-` site; reuses or extends G3.
    Leaves direct S7 construction as a gap.
  - **B (validator extension):** add a second invariant to the S7 class
    validator that cross-checks every member's `@groups` against
    `names(member@data)`; new error class
    `surveycore_error_collection_group_not_in_member_data` (G1b).
- **Decision:** B.
- **Rationale:** Validator is already the "final backstop" per §II; a
  second invariant catches every entry path (direct S7 construction,
  `as_survey_collection()`, `add_survey()`, `[[<-`, future surveytidy
  methods) with one rule. Keeping G1 and G1b as separate classes
  preserves the distinction between "divergence across members" and
  "column not present in data," which is valuable for programmatic
  error handling. Matches `engineering-preferences.md §4` (handle more
  edge cases) and §5 (explicit over clever).

**Q: Issue 17 — G5 hint is only actionable for the append path, not the
replace path introduced by Pass 1's Issue 7 resolution. How is this fixed?**
- Options considered:
  - **A:** refine the G5 `"v"` bullet to cover both paths in one message.
  - **B:** split G5 into `_on_replace` and `_on_append` classes with
    per-path tailored hints.
- **Decision:** B.
- **Rationale:** User chose finer-grained classes. Replace and append
  have genuinely different user remedies (`value@groups <- x@groups`
  before assignment for replace; `add_survey()` for append), and
  programmatic callers benefit from being able to distinguish the two
  failure modes. The `[[<-` body is restructured so the replace/append
  classification happens before the `@groups` check, which lets us
  raise the correct class with no extra cost.

**Q: Issue 18 — `@groups` element-level content is unconstrained by
`S7::class_character` (allows `NA`, empty string, duplicates). How is
this tightened?**
- Options considered:
  - **A:** extend the validator to reject these; new class
    `surveycore_error_collection_groups_malformed` (G1c) with one
    `"i"` bullet per failing condition.
  - **B:** trust tidyselect upstream; leave the validator permissive.
- **Decision:** A.
- **Rationale:** Direct S7 construction bypasses tidyselect; the
  normal path would never produce these, but test fixtures and
  tooling can. Cheap to add, prevents cryptic failures downstream in
  `.resolve_groups()` and duplicate output columns. Matches
  `engineering-preferences.md §4` (handle more edge cases).

**Q: Issue 19 — if `add_survey()` is called with multiple new surveys
and one errors, is the call atomic or partial?**
- Options considered:
  - **A:** document atomicity explicitly in §V.
  - **B:** leave implied; current implementation pattern already does
    the right thing.
- **Decision:** A.
- **Rationale:** Trivial to state; prevents a future refactor from
  silently changing observable behavior by reordering the loop around
  the final constructor call. Matches `engineering-preferences.md §5`
  (explicit over clever).

**Q: Issue 20 — §X uses the phrase "dual `class=` + snapshot where
applicable" without enumerating the subset. Enumerate explicitly?**
- Options considered:
  - **A:** add a per-class table in §X listing the assertion pattern
    (Layer 1 → `class=`-only; Layer 3 → dual; G8 → `expect_warning()` +
    snapshot).
  - **B:** leave the rule in `testing-surveycore.md` and trust the
    implementer.
- **Decision:** A.
- **Rationale:** Enumerating in the spec removes an ad-hoc decision
  point at implementation time and matches the format used in other
  surveycore specs. Zero extra runtime cost.

**Q: Issue 21 — `[[<-` uses `identical()` (order-sensitive) but §VI
doesn't restate the consequence. Add an explicit note + test?**
- Options considered:
  - **A:** one sentence in §VI step 4 plus one new `[[<-` test block
    for same-set-different-order.
  - **B:** leave implied from §III.
- **Decision:** A.
- **Rationale:** Three lines of spec + test close the last gap in the
  test matrix and make the consequence visible at the site where users
  will encounter it.

### Outcome

Spec v0.3 adds two new Layer 1 validator invariants (column resolvability
in member `@data` → G1b; well-formed `@groups` contents → G1c), splits
G5 into `_on_replace` (G5) and `_on_append` (G5b) with path-specific
hints, documents `add_survey()` atomicity, enumerates the test-layer
mechanics per error class in a §X table, and adds the order-sensitivity
note + test for `[[<-`. `[[<-` behavior is restructured to classify the
call as replace vs. append before the `@groups` check so the correct
class can be raised. Error table now runs G1, G1b, G1c, G2, G3, G4, G5,
G5b, G6, G7, G7b, G8.

---

## [2026-04-23] — Stage 3 (implementation-workflow): Resolve plan-review Pass 1 issues

### Context

Worked through the 19 issues in
`plans/plan-review-collection-uniform-groups.md` (Pass 1: 8 BLOCKING,
6 REQUIRED, 5 SUGGESTION). Root cause: the implementation plan at
`/Users/jacobdennen/surveycore/plans/impl-collection-uniform-groups.md`
was drafted against spec v0.1/v0.2 and never re-synced with v0.3.
Goal for this session was to bring the plan forward so Stage 4 handoff
to `/r-implement` or `/auto-ship` can proceed.

### Questions & Decisions

Every issue was resolved in favor of the review's recommended option
(Option A) — each recommendation was a direct transcription of an
already-locked spec or prior-decisions-log choice. No new architectural
questions arose. Summary of what the plan gained:

**Q: Issues 1, 7 — How should plan Decision 4 and task §2.2 describe
the three member-handling sub-cases for supplied `group =`?**
- **Decision:** A (rewrite to enumerate: empty member → silent
  propagate; identical → no-op; non-empty divergent → propagate + one
  G8 warning per divergent member).
- **Rationale:** Locked in Pass 1 Q-Issue-3; plan was missing G8
  entirely.

**Q: Issue 2 — Where does `S7::method("[[<-", survey_collection)` live?**
- **Decision:** A (`R/methods-print.R` adjacent to existing `[[`,
  `length`, `names` at lines 796–798).
- **Rationale:** Locked in Pass 1 Q-Issue-15; `code-style.md §2`
  methods-grouped-by-type. Plan §Files / §4 header originally pointed
  at `R/survey-collection.R`.

**Q: Issue 3 — Plan doesn't describe the two internal helpers
`.check_groups_match()` / `.propagate_or_match()`. Add a dedicated
task?**
- **Decision:** A (new task §0 at the top of the step-by-step list
  implementing both helpers per spec §II).
- **Rationale:** Spec §II requires them with documented signatures and
  a call-site map; plan must cite to prevent implementer reinventing
  at each site. Locked in Pass 1 Q-Issue-1.

**Q: Issue 4 — Validator task covered only Invariant 1. Expand to
three?**
- **Decision:** A (G1 equality + G1b `@data` resolvability + G1c
  well-formedness, with one `"i"` bullet per failing G1c condition).
- **Rationale:** Pass 2 Q-Issue-16 (G1b) and Q-Issue-18 (G1c) both
  chose validator extension over per-site checks; plan was missing
  both.

**Q: Issue 5 — How should task §2.1 specify the
missing-argument-detection mechanism?**
- **Decision:** A (name `rlang::missing_arg()` default + detect via
  `rlang::quo_is_missing(rlang::enquo(group))`; explicitly reject
  bare `missing(group)`).
- **Rationale:** Locked in Pass 1 Q-Issue-5.

**Q: Issue 6 — How should task §2.2 handle empty tidy-select
resolutions of `group =`?**
- **Decision:** A (collapse `NULL` / `character(0)` / `c()` /
  `all_of(character(0))` to the adopt-from-members branch, identical
  to `missing(group)`).
- **Rationale:** Locked in Pass 1 Q-Issue-4; tidyselect no-op
  semantics.

**Q: Issue 8 — Should `add_survey()` task explicitly state
atomicity?**
- **Decision:** A (add atomicity sub-step pointing at §8 regression
  test).
- **Rationale:** Locked in Pass 2 Q-Issue-19; trivial to state;
  prevents silent regression by future refactor.

**Q: Issues 9, 10, 11 — `[[<-` task body didn't classify path before
the `@groups` check and used the pre-v0.3 merged error class. How to
restructure?**
- **Decision:** A (seven-step restructure: (1) validate `value` kind
  G6; (2) validate `i` shape G7b; (3) classify replace vs. append;
  (4) path-specific `@groups` check raising G5 or G5b; (5) handle
  replace-by-name / append-with-repair / `i == ""` / numeric
  `1:length` / numeric `length+1`; (6) re-validate via constructor;
  (7) roxygen stub).
- **Rationale:** Pass 2 Q-Issue-17 locked the G5 / G5b split; Pass 1
  Q-Issue-7 locked replace-by-name; Pass 1 Q-Issue-9 locked NULL =
  G6; Pass 1 Q-Issue-12 locked G7b bad-type split.

**Q: Issue 12 — Plan §7 error-class table was five rows short of spec
§VIII. Transcribe?**
- **Decision:** A (direct transcription of all twelve rows: G1, G1b,
  G1c, G2, G3, G4, G5, G5b, G6, G7, G7b, G8).
- **Rationale:** Spec §XI quality gate requires exactly these rows in
  `plans/error-messages.md`.

**Q: Issues 13, 14 — Plan §8 test list was ~two-thirds short of spec
§X. Transcribe?**
- **Decision:** A (full transcription preserving spec §X grouping; new
  preamble requiring `test_invariants(coll)` + `test_collection_groups_invariant(coll)`
  as the first two assertions in every constructor block; new helper
  added to `tests/testthat/helper-test-data.R`).
- **Rationale:** Spec §XI coverage gates ≥ 98% on new code paths; the
  missing blocks covered G1b, G1c, G8, atomicity, replace-by-name,
  collision-repair, `i == ""`, NULL assignment, `survey_collection`
  as value, G7b bad-type matrix, same-set-different-order, dispatch
  column-order — most of which test classes that would otherwise
  have no coverage at all.

**Q: Issue 15 — Plan Decision 10 said `remove_survey()` needed no code
change; spec §VII requires a one-line change. Reconcile which way?**
- **Decision:** A (fix the plan: update Decision 10 and add a
  dedicated task §3.5 "pass `groups = x@groups` through to the
  reconstructed `survey_collection()` call").
- **Rationale:** Without the one-line change, every `remove_survey()`
  call silently de-groups the collection (the reconstructed
  `survey_collection()` defaults `@groups` to `character(0)` without
  it). Spec is correct; plan was wrong.

**Q: Issue 16 — Should the NEWS bullet flag the breaking change and
should the commit use `feat(classes)!:`?**
- **Decision:** A (add explicit **Breaking change** NEWS bullet; add
  `feat(classes)!:` prefix requirement to §10 Verification).
- **Rationale:** Spec §XI quality gates require both; the `!` is the
  Conventional Commits marker for breaking changes.

**Q: Issue 17 — Plan §10 Verification was thin vs. spec §XI Quality
Gates. Expand?**
- **Decision:** A (direct transcription of all eight gates with
  explicit per-file coverage thresholds and a pointer to spec §XI as
  authoritative).
- **Rationale:** Plan §10 is the implementer's daily reference;
  surfacing all gates here (snapshot-stability, error-messages rows,
  decisions log presence, coverage thresholds, commit prefix)
  prevents ad-hoc gate inference at PR time.

**Q: Issue 18 — Single-PR scope is correct but should the plan warn
reviewers about diff size?**
- **Decision:** A (add one sentence to §PR Map noting this is an
  atomically-scoped single PR touching ~3 R files + helpers + ~2
  test files).
- **Rationale:** Splitting would create a broken-invariant window
  (Decision 1 spans validator + mutators); flagging the size warns
  reviewers without suggesting a split.

**Q: Issue 19 — Should plan §5 (Dispatch, no code change) cite the
exact contract line the invariant relies on?**
- **Decision:** A (reference `R/analysis-helpers.R:441`
  `unique(c(from_groups_prop, from_arg))` and point at the §8 dispatch
  column-order regression test).
- **Rationale:** Trivial to state; prevents the "no code change"
  comment from drifting off the actual contract.

### Outcome

Plan v1 → v2. All 19 plan-review issues resolved. Plan now: (a) carries
the v0.3 spec decisions verbatim (G1b, G1c, G5/G5b split, G8 override
warning, G7b bad-type split, replace-by-name, atomicity); (b) has a
dedicated task §0 for the two internal helpers; (c) places `[[<-` in
`R/methods-print.R` per `code-style.md §2`; (d) has a task §3.5 for
the one-line `remove_survey()` fix that was previously claimed as
"no code change"; (e) mirrors spec §X in the test plan with a
`test_collection_groups_invariant(coll)` helper addition; (f) carries
all twelve error classes in §7 and all eight quality gates in §10.
Ready for handoff to `/r-implement` or `/auto-ship`.

---

## [2026-04-23] — Stage 3 (implementation-workflow): Resolve plan-review Pass 2 issues

### Context

Pass 2 of `plans/plan-review-collection-uniform-groups.md` surfaced 7
second-order issues (0 BLOCKING, 3 REQUIRED, 5 SUGGESTION — later
recorded as 4 SUGGESTION after consolidation) against plan v2. Pass 1
had closed every spec-coverage gap; Pass 2 caught issues the plan
edits themselves introduced or left behind: helper signature
ambiguity, an unnamed final constructor call in §2, and an incomplete
Decision 2 matrix. All 7 issues resolved in favor of the review's
recommended option.

### Questions & Decisions

**Q: Issue 20 (REQUIRED) — How does `.check_groups_match()` select
between G1 / G5 / G5b when spec §II gives only a `context` argument
and the sibling `.propagate_or_match()` takes `error_class` directly?**
- Options considered:
  - **A:** Grow the signature to
    `(candidate_groups, target_groups, error_class, context = NULL)`.
    Deliberate deviation from spec §II documented in the plan.
  - **B:** Keep the 3-arg spec signature; implement an internal
    `context → class` lookup.
- **Decision:** A.
- **Rationale:** Asymmetry with `.propagate_or_match()` is itself a
  smell; explicit `error_class` keeps control flow in the caller,
  matches the sibling helper, and aligns with
  `engineering-preferences.md §5` ("explicit over clever"). Plan §0
  now documents the deviation from spec §II along with the call-site
  class mapping (validator → G1, `[[<-` replace → G5, `[[<-` append
  → G5b).

**Q: Issue 21 (REQUIRED) — Plan §2 step 2 ends at per-member
`member@groups <- target` propagation without naming the final
`survey_collection(surveys = …, groups = target)` construction
call. Leave implicit?**
- Options considered:
  - **A:** Insert new §2 step 3 naming the construction call
    explicitly; renumber roxygen to step 4.
  - **B:** Leave implicit; trust spec §IV.behavior.3.
- **Decision:** A.
- **Rationale:** The spec's explicit construction step is what Pass 1
  Issue 15 closed for `remove_survey()` — omitting `groups = target`
  silently defaults `@groups` to `character(0)` and de-groups the
  collection. Same footgun applies to the constructor; naming the
  step removes the ambiguity once and for all.

**Q: Issue 22 (REQUIRED) — Plan Decision 2 enumerates only the
non-empty `coll@groups` branch (3 rows). Spec §V has a 5-row matrix.
Fix the Decision block?**
- Options considered:
  - **A:** Extend Decision 2 with the full 5-row matrix.
  - **B:** Leave as-is; task §3 step 1 handles every case correctly.
- **Decision:** A.
- **Rationale:** Decision blocks are the plan's standing summary of
  intended behavior; a reader who reads Decision 2 in isolation must
  get a complete model. Task §3 execution was already correct but the
  summary was misleading. Decision block now names which branches
  `.propagate_or_match()` covers vs. which are inlined.

**Q: Issues 23–26 (SUGGESTION) — §Files completeness, validator
iteration structure, `add_survey()` helper-call explicit naming,
print task line numbers. Fix all four?**
- **Decision:** A on each.
- **Rationale:** All are trivial edits that sharpen the plan for the
  implementer without changing semantics.
  - Issue 23: added three §Files Modified bullets
    (`helper-test-data.R`, `_snaps/methods-print.md`, `NEWS.md`).
  - Issue 24: §1 Invariant 1 now names the loop + early-exit +
    `.check_groups_match()` call structure.
  - Issue 25: §3 step 1 now explicitly invokes
    `.propagate_or_match()` with an `error_class` argument on the
    grouped-coll branch; ungrouped-coll branch stays inline (noted
    in Decision 2 extension).
  - Issue 26: §6 print task cites the exact insertion line numbers
    (`R/methods-print.R:772` for the header; `760–767` for
    `.fmt_collection_line()`).

### Outcome

Plan v2 → v3. All 7 Pass-2 issues resolved. Plan now: (a) uses an
explicit `error_class` argument for `.check_groups_match()` and
documents the deviation from spec §II; (b) names the final
`survey_collection()` construction call in §2 step 3; (c) carries the
full 5-row Decision 2 matrix; (d) has a complete §Files list
including `helper-test-data.R`, `_snaps/methods-print.md`, and
`NEWS.md`; (e) describes the validator Invariant 1 loop structure; (f)
invokes `.propagate_or_match()` explicitly from §3 step 1; (g) cites
print insertion line numbers. Ready for handoff to `/r-implement` or
`/auto-ship`.

---

## [2026-04-23] — Implementation: defer `[[<-`

### Context

During `/r-implement` execution of the collection-uniform-groups plan,
`devtools::check()` surfaced a persistent WARNING from the
`R CMD check` "replacement functions" check:

```
* checking replacement functions ... WARNING
Error in get(f, envir = code_env) : invalid first argument
Calls: <Anonymous> -> Filter -> unlist -> lapply -> FUN -> get
Execution halted
The argument of a replacement function which corresponds to the right
hand side must be named 'value'.
```

Root cause traced to `tools::checkReplaceFuns()`:

1. When called via `tools::checkReplaceFuns("surveycore")` (the path
   R CMD check uses on the installed package), it pulls S3methods
   metadata via `.getNamespaceInfo(code_env, "S3methods")`.
2. S7's `method("[[<-", survey_collection) <- function(x, i, ..., value)`
   stores the method in that table with the **function object itself** in
   column 3, not a character name (unlike classical S3 registration
   which stores e.g. `"print.survey_taylor"`).
3. The check attempts coercion:
   ```r
   ind <- vapply(ns_S3_methods, is.character, NA)
   ns_S3_methods[!ind] <- ""
   ns_S3_methods <- as.character(ns_S3_methods)
   ```
   The function entry becomes `""`. The `""` then flows into `Filter`
   which calls `get("", envir = code_env)` — which errors with
   "invalid first argument."

Reproduced locally with `tools::checkReplaceFuns("surveycore")` (after
installing the package and loading the namespace). Passing
`dir = "<source dir>"` does NOT reproduce because that path sources R
files into a plain env without building the S3methods metadata. So the
warning is specific to how R CMD check interacts with S7's method
registration for replacement functions. The function itself runs
correctly — all 126 tests for `[[<-` passed before the method was
removed.

### Questions & Decisions

**Q: How should we resolve the check warning?**
- Options considered:
  - **A (defer `[[<-`):** Remove the S7 registration, the
    `.validate_sub_assign_index()` helper, G5/G5b/G6/G7/G7b error
    classes, and all `[[<-` tests. Users mutate via `add_survey()` /
    `remove_survey()`. Add a clear note in spec + error-messages.md
    pointing at the blocker and the workaround path.
  - **B (S4 `setMethod`):** Register `[[<-` via S4 `setMethod` with
    signature `"surveycore::survey_collection"`. S7 classes register
    themselves in S4 under the hood, so dispatch works. Locally
    verified — one line `setMethod("[[<-", ...)` inside `.onLoad`
    bypasses the S3methods metadata path entirely.
  - **C (custom exported function):** Provide `replace_survey(coll, i,
    value)` / `insert_survey(coll, i, value)` instead of `coll[[i]] <-
    value`. No replacement-function syntax anywhere; same functionality.
  - **D (patch check upstream):** File a bug against R tools; wait for
    a fix. Unknown timeline.
- **Decision: A.**
- **Rationale:** The user prefers to scrap `[[<-` over introducing S4
  (option B, "hacky") or a new exported verb (option C, which grows
  surface area just to dodge the warning). The existing `add_survey()`
  / `remove_survey()` pair already covers the common mutation cases
  and preserves `@groups` correctly after the plan §3.5 one-line fix.
  The scrap is localized (one R source block, one section of tests,
  five error rows) and reversible: if option B or D becomes viable
  later, the method and its error classes can be added without
  breaking any existing caller.

**Q: What do we lose by deferring `[[<-`?**
- Base-R-style `coll[["wave3"]] <- new_survey` assignment. Users must
  instead write `coll <- add_survey(coll, wave3 = new_survey)` for
  append, or build a fresh collection from scratch for replace. No
  user-visible functionality loss beyond syntactic convenience —
  `add_survey()` / `remove_survey()` / `as_survey_collection()` cover
  every documented workflow in spec §IX.

**Q: Where does the deferral live in the package-level docs?**
- NEWS.md §"New features" — `[[<-` bullet removed; `add_survey()` /
  `remove_survey()` bullet now mentions groups propagation explicitly.
- `plans/error-messages.md` — G5/G5b/G6/G7/G7b rows removed with an
  italic trailing note explaining the deferral and pointing at this
  decisions entry.
- `plans/spec-collection-uniform-groups.md` — bumped to v0.4 with
  amendment log pointing here; §I Scope moves `[[<-` to a new
  "Deferred" subtable.
- `R/methods-print.R` — the block where the method would have been
  registered gets a block comment explaining why there is no
  registration and pointing to `add_survey()` / `remove_survey()`.
- `tests/testthat/test-collection-groups.R` — header comment
  describes the deferral and the check-warning reason.

### Outcome

`[[<-` and its five error classes (G5, G5b, G6, G7, G7b) are deferred.
All 7 remaining error classes (G1, G1b, G1c, G2, G3, G4, G8) ship.
`devtools::check()` now passes with 0E / 0W / 2N (both notes
pre-existing and unrelated). Full test suite: 8639 PASS / 0 FAIL / 4
SKIP. Spec bumped to v0.4 with amendment log. If a workaround (S4,
R-tools patch, or S7 API change) lands later, `[[<-` can be reinstated
without a breaking-change cycle — `add_survey()` / `remove_survey()`
are additive to it.

---
