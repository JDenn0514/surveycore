# Plan Review: get-anova

## Plan Review: get-anova — Pass 1 (2026-04-18)

### New Issues

#### Section: PR Map

**Issue 1: PR A and PR B claim "merged to develop" but plan does not state where to verify**
Severity: SUGGESTION
Lens 2 (dependency ordering)

The "PR Map" header asserts both prerequisite PRs are shipped (`#94`, `#93`),
but PR C tasks reference outputs of those PRs (`@term_assign`,
`R/variance-vendored-saddlepoint.R`, `.pchisqsum_sad()`, `.pFsum_sad()`)
without a precondition step that verifies the prerequisites actually loaded
into `develop`. If a future implementer reads this file in isolation and
PR A/B were unmerged, every TDD cycle below silently fails on missing
symbols.

Options:
- **[A]** Add a one-line precondition task before Task 1.1: "Verify
  `survey_glm_fit@term_assign` exists and `R/variance-vendored-saddlepoint.R`
  defines `.pchisqsum_sad()` / `.pFsum_sad()` on the `develop` branch."
  Effort: low, Risk: low, Impact: catches a stale assumption immediately.
- **[B]** Do nothing — trust that the implementer reads the "merged" claim
  and infers the prerequisite. — what stays ambiguous: nothing fatal, but
  the cold-start path is rougher.

**Recommendation: A** — Cheap insurance against PR-A/B being reverted, or
against the implementer working from a stale branch.

---

#### Section: PR C, Files

**Issue 2: Cross-design helper reference is wrong — `make_survey_data()` only supports 3 of 5 design classes**
Severity: BLOCKING
Lens 5 (file completeness) / spec-coverage failure

Task 2.1 (sequential happy path) and Task 4.1 (comparison happy path) both
require:

> Cross-design smoke tests: one … happy-path block for each of
> `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`,
> `survey_srs`, constructed via `make_survey_data()`.

`make_survey_data()` (`tests/testthat/helper-test-data.R:62`) accepts
`design = c("taylor", "replicate", "twophase")` only. It cannot construct
a `survey_nonprob` or `survey_srs` directly. The correct fixture in this
repo is `make_all_designs()` (`helper-test-data.R:472`), which returns a
named list `srs / taylor / replicate / twophase / calibrated`. Implementer
following the plan literally will hit a `match.arg()` error on the first
nonprob/srs block.

Options:
- **[A]** Replace `make_survey_data()` with `make_all_designs()` in both
  Task 2.1 and Task 4.1 cross-design bullet lists; show how to iterate
  the returned list for the smoke tests. — Effort: low, Risk: low.
- **[B]** Spell out the per-design construction inline (e.g. for `srs`,
  call `as_survey(df, weights = wt)` on a `make_survey_data(design = "taylor")`
  output; for `nonprob`, call `as_survey_nonprob(...)`). — Effort: low,
  Risk: low; more verbose but self-contained.
- **[C] Do nothing** — Implementer guesses, gets it wrong, or invents a
  helper.

**Recommendation: A** — `make_all_designs()` is purpose-built for exactly
this iterate-over-all-five pattern.

---

**Issue 3: `.validate_shared_args()` reuse is signature-incompatible with `get_anova()`**
Severity: REQUIRED
Lens 5 (file completeness)

Task 3.1 step 4 says:

> `.validate_shared_args()` for `decimals`/`name_style`

`.validate_shared_args()` (`R/analysis-helpers.R:578`) has the signature
`function(variance, conf_level, name_style, decimals = NULL, na.rm = TRUE,
valid_variance = ...)`. The first three arguments are required; `variance`
and `conf_level` validate values that don't exist on `get_anova()`'s
surface. Calling it forces threading dummy values (`variance = NULL`,
`conf_level = 0.95`) that quietly satisfy the gate — wrong on principle
(the validator is checking arguments the caller doesn't expose) and
fragile (any change to the helper's required-arg list breaks `get_anova()`
at runtime).

Options:
- **[A]** In Task 1.x infrastructure, factor a smaller `.validate_decimals_namestyle(decimals, name_style)` helper out of the body of
  `.validate_shared_args()` and call it from both. — Effort: medium,
  Risk: low. Adds DRY discipline to existing code.
- **[B]** Inline the two validations in `get_anova()` directly (call
  the existing reused error classes `surveycore_error_invalid_decimals`
  / `surveycore_error_invalid_name_style`). — Effort: low, Risk: low.
  Trades DRY for clarity.
- **[C] Do nothing** — implementer threads dummy values; works until it
  doesn't.

**Recommendation: A** — DRY is project rule #1
(`engineering-preferences.md`); a focused validator gets reused as soon
as the next analysis function lands without the `variance` / `conf_level`
surface.

---

**Issue 4: Task 1.1 row count is off-by-one ("19 new rows" but list contains 18)**
Severity: SUGGESTION

Task 1.1 says "Append 19 new rows to `plans/error-messages.md` for the new
error/warning classes A-2 through A-20" and explicitly retires A-6. Counting
the listed classes A-2…A-5, A-7…A-20: that is 18 rows, not 19. The
divergence will trip a careful implementer who counts as they go.

Options:
- **[A]** Edit Task 1.1: "Append 18 new rows…". — Effort: trivial.
- **[B] Do nothing** — implementer probably notices.

**Recommendation: A**.

---

#### Section: PR C, TDD Cycle A

**Issue 5: Task 1.3 task ordering — registers a function defined in Task 3.2**
Severity: SUGGESTION
Lens 2 (dependency ordering)

Task 1.3 instructs adding a `registerS3method("anova",
"surveycore::survey_glm_fit", anova.survey_glm_fit, ...)` call to `R/zzz.R`.
`anova.survey_glm_fit` is defined later in Task 3.2. R doesn't care about
file order at install time, but if a curious implementer commits the
infrastructure section (Tasks 1.1–1.3) standalone, `devtools::load_all()`
will fail at `.onLoad()` with `object 'anova.survey_glm_fit' not found`.

Options:
- **[A]** Move Task 1.3 to come immediately after Task 3.2. — Effort:
  trivial.
- **[B]** Add a note to Task 1.3: "Do not commit this change separately
  from Task 3.2 — `.onLoad()` will fail until `anova.survey_glm_fit`
  exists." — Effort: trivial.

**Recommendation: B** — Keeps the natural "infrastructure first" reading
of the section while warning against an obvious commit-boundary trap.

---

**Issue 6: Order of `name_style` rename and column-label attachment is undefined**
Severity: REQUIRED
Lens 3 (acceptance criteria) / Lens 4 (spec coverage)

Task 3.1 step 4 lists, in order:

> `.apply_name_style()`, column labels per §3.7.3 …

§3.7.3 enumerates labels keyed on the **surveycore** column names
(`p_value`, `ddf`, …). If `.apply_name_style()` runs first, the columns
are already named `p.value` / `df_residual` and the label-attachment
loop will silently skip them (or attach to the wrong column). Conversely,
if labels are attached first, they survive the rename only because R
`data.frame` rename preserves attributes — which is implementation-dependent
on how `.apply_name_style()` is written.

Options:
- **[A]** Specify the order in Task 3.1: "Attach column-level labels
  per §3.7.3 (using surveycore column names) **before**
  `.apply_name_style()`. Verify that `.apply_name_style()` preserves
  `attr(col, 'label')` (it does — see `R/analysis-helpers.R:.apply_name_style`)."
  — Effort: low.
- **[B]** Specify the inverse order plus a §3.7.3 mapping table for
  broom names. — Effort: medium.
- **[C] Do nothing** — implementer guesses, snapshot tests catch a
  symptom but the ordering bug is subtle.

**Recommendation: A** — Other `get_*()` functions in the codebase
attach labels before applying `name_style`; matching that idiom keeps
the family consistent.

---

**Issue 7: Sequential nonprob happy-path test will fire A-14 — needs explicit warning capture**
Severity: REQUIRED
Lens 4 (spec coverage)

Task 2.1 lists "Cross-design smoke tests: one sequential happy-path block
for each of … `survey_nonprob` …". §3.6 step 6a guarantees that
`get_anova()` on a `survey_nonprob` fit fires
`surveycore_warning_nonprob_inference` exactly once per call. A bare
happy-path block will fail with an unexpected-warning error (testthat 3
treats unexpected warnings as failures by default).

The same issue surfaces in the comparison-mode cross-design block
(Task 4.1) on `survey_nonprob`.

Options:
- **[A]** In both Task 2.1 and Task 4.1, add a sentence: "The
  `survey_nonprob` smoke test must wrap the `get_anova()` call in
  `expect_warning(class = 'surveycore_warning_nonprob_inference')` and
  capture the result inline." — Effort: low.
- **[B]** Note the gotcha once at the top of the cross-design bullet
  and cross-reference. — Effort: low.

**Recommendation: A** — Cycle B repeats the error; spelling it out at
both sites avoids the implementer having to remember the §3.6 step 6a
contract while writing tests.

---

**Issue 8: A-19 (replicate nonconvergence) trigger is hand-wavy**
Severity: REQUIRED
Lens 3 (acceptance criteria)

Task 2.1 lists A-19 with the trigger: "replicate design with a
pathological replicate (e.g., JK1 dropping all rows for one factor
level); warning fires once per affected refit (not once per replicate)".
Constructing this trigger reproducibly is non-trivial. A factor level
present in only one PSU plus a JK1 design that drops that PSU produces
the failure — but the spec doesn't pin the construction recipe, and
floating-point luck across CI versions can cause the GLM to converge
anyway in some environments.

Options:
- **[A]** Pin a deterministic construction recipe (e.g., synthesize
  a 50-row dataset with a binary factor where one level appears in
  exactly 1 PSU, build a JK1 design with `n_strata = n_psu`, fit
  a `binomial(logit)` GLM where the rare level is the only positive
  case — guaranteed separation when that PSU is dropped). Add to
  `helper-test-data.R` as `make_replicate_nonconverger()`. — Effort:
  medium, Risk: low (more upfront work, deterministic test).
- **[B]** Mark the test as `skip_on_cran()` and label it as
  best-effort, accepting flakiness in CI. — Effort: low, Risk: high
  (intermittent reds, tracker noise).
- **[C] Do nothing** — implementer guesses and the test is flaky from
  day one.

**Recommendation: A** — `make_replicate_nonconverger()` is reusable for
future regression tests of replicate-fit failure paths.

---

**Issue 9: A-20 (domain mismatch) trigger requires test-only mutation; helper not specified**
Severity: REQUIRED
Lens 3 (acceptance criteria)

Task 2.1 says A-20 is triggered by "fit the full model, then overwrite
`fit@design@data$..surveycore_domain..` on the stored fit (test-only
helper); call `get_anova(fit)` and assert the typed error". Mutating a
deeply-nested S7 slot is not a one-liner — `fit@design` is itself an S7
object and `fit@design@data` is a property; reassigning needs
`S7::set_props()` or the `<-` shortcut on the immediate parent. There is
no test-only helper in the repo that does this today.

Options:
- **[A]** Add a `.testhelper_clobber_domain(fit, value)` function to
  `helper-test-data.R` (kept private; used only by the A-20 test)
  showing the exact `S7::set_props()` invocation. — Effort: low, Risk:
  low.
- **[B]** Spell out the mutation inline in the test (`design2 <-
  S7::set_props(fit@design, data = ...); fit2 <- S7::set_props(fit,
  design = design2)`). — Effort: low.
- **[C] Do nothing** — implementer attempts `fit@design@data$col <-
  value` and is surprised by S7 semantics.

**Recommendation: A** — A reusable helper documents the supported
mutation pattern for any future negative-test that needs to perturb
`@design@data`.

---

**Issue 10: Non-default-contrasts edge case test does not specify `options()` cleanup**
Severity: REQUIRED
Lens 3 (acceptance criteria)

Task 2.1 lists: "Non-default contrasts (`options(contrasts = c('contr.sum',
…))`): sequential refit produces a coherent ANOVA table…". `options()`
mutations leak into subsequent test_that() blocks if not reset. The
project's other tests use `withr::local_options()` for this; the plan
should pin that idiom.

Options:
- **[A]** Add to the bullet: "Use `withr::local_options(contrasts =
  c('contr.sum', 'contr.poly'))` to scope the change to the test
  block." — Effort: trivial.
- **[B] Do nothing** — implementer probably knows the convention but
  may forget.

**Recommendation: A**.

---

**Issue 11: Task 3.1 step 1 mis-summarizes the n-invariance check**
Severity: SUGGESTION
Lens 4 (spec coverage)

Task 3.1 step 1 (the bullet on `.reg_term_test()` implementation) says:

> n-invariance `stopifnot()` on `length(@weights)`

§V.1 step 5 of the spec says the primary check is `identical(rownames(model.frame(@fit_)), …)` (typed error A-12 on mismatch); the
`stopifnot(length(@weights) == length(reduced@weights))` is described as
a belt-and-suspenders defensive check that runs *after* the rownames
identity holds. The plan's wording elides the rownames check entirely at
this layer; a literal reading suggests rownames-comparison happens only
in `.anova_sequential()` step c (which is also true), but the
`.reg_term_test()` defensive check is also part of the spec.

Options:
- **[A]** Reword step 1 bullet: "n-invariance defensive
  `stopifnot(length(@weights) == length(reduced@weights))` per §V.1
  step 5 (the primary rownames-identity A-12 check lives in
  `.anova_sequential()` and `.anova_compare()`)." — Effort: trivial.
- **[B] Do nothing** — the spec is authoritative; a careful implementer
  will read both.

**Recommendation: A** — Cheap clarity win; prevents the implementer
from skipping the defensive `stopifnot()`.

---

**Issue 12: Task 3.4 says "Comparison-mode blocks should still fail" but Task 4.1 hasn't written them yet**
Severity: SUGGESTION
Lens 2 (dependency ordering)

Task 3.4 (end of Cycle A): "Confirm all sequential-mode blocks pass GREEN.
Fix any failures before proceeding. Comparison-mode blocks (added in
Cycle B) should still fail." But Cycle B's tests (Task 4.1) are written
*after* Task 3.4. There are no comparison-mode blocks in the test file
at the point Task 3.4 runs, so the instruction's second sentence is
vacuously true and reads as a contradiction.

Options:
- **[A]** Strike the "Comparison-mode blocks (added in Cycle B) should
  still fail" sentence. — Effort: trivial.
- **[B] Do nothing**.

**Recommendation: A**.

---

#### Section: PR C, TDD Cycle B

**Issue 13: A-5 design-mismatch happy-path test described twice with conflicting framing**
Severity: SUGGESTION
Lens 4 (spec coverage)

Task 4.1's A-5 bullet describes: "two fits on designs with different
`@data` or `@variables` slots (but same shape); must NOT fire when
`@metadata@transformations` differ". Spec §3.5 step 4 confirms the
content-based comparison. The plan correctly tests both the negative
case (firing) and the regression case (must NOT fire when only
`@metadata@transformations` differ). Both belong to the *same* test
class A-5 but exercise opposite assertions; the plan should split them
into two distinct `test_that()` blocks for clarity.

Options:
- **[A]** Split A-5 into "fires when @data differs" and "does NOT fire
  when only @metadata@transformations differ (Pass 3 Issue 71
  regression)". — Effort: trivial.
- **[B] Do nothing** — implementer will probably split them anyway.

**Recommendation: A**.

---

#### Section: PR C, Numerical Oracle Tests

**Issue 14: Two-phase oracle test setup not specified**
Severity: REQUIRED
Lens 5 (file completeness)

Task 6.1 lists a "Two-phase oracle: on `make_survey_data(design =
'twophase')`, `method = 'LRT'`, `test = 'F'`: parity with
`survey::anova.svyglm()` after the refit re-applies the phase-2 subset."
For this oracle to succeed, the same two-phase design must be reproducibly
constructible in both surveycore (`as_survey_twophase()`) and `survey`
(`survey::twophase()`). The `make_survey_data(design = "twophase")`
output ships a `subset` and `phase1_prob` column but the plan does not
spell out the corresponding `survey::twophase()` call shape.

Options:
- **[A]** Add a note: "Construct the matching `survey::twophase()`
  design via `survey::twophase(id = list(~psu, ~psu), strata = list(~strata,
  ~strata), subset = ~subset, data = df)` (see `survey`'s `pbc` example
  in `?twophase`)." — Effort: low.
- **[B]** Use `survey::pbc` directly as the oracle fixture, skip the
  synthetic two-phase. — Effort: medium (requires `survey` as a hard
  test dep, but it is already needed for the oracle anyway).
- **[C] Do nothing** — implementer figures it out.

**Recommendation: A** — Keeps the synthetic-data discipline and
removes one trial-and-error loop from implementation.

---

**Issue 15: Fay-BRR oracle uses argument name that doesn't exist**
Severity: REQUIRED
Lens 5 (file completeness)

Task 6.1 references "synthetic design via `make_survey_data(design =
'replicate', type = 'BRR')` with a Fay coefficient ρ = 0.3". The
`make_survey_data()` signature accepts `type` ∈ "brr" / "fay" (lowercase;
see `helper-test-data.R:75`) — `type = "fay"` is the path that should
generate the ρ-scaled replicate weights. The plan says `type = 'BRR'`
with a separate ρ argument that doesn't exist in `make_survey_data()`.
Spec §VII says `as_survey_repweights(..., type = 'Fay', rho = 0.3)`,
which is yet a third construction path (and uses an exported constructor,
not the test helper).

Options:
- **[A]** Reword Task 6.1 to match the spec's `as_survey_repweights(...,
  type = 'Fay', rho = 0.3)` recipe verbatim, on top of a synthetic data
  frame from `make_survey_data(design = 'replicate', type = 'fay')`. —
  Effort: low.
- **[B]** Extend `make_survey_data()` with a `rho` argument. — Effort:
  medium (touches a shared helper; out of scope for this PR).
- **[C] Do nothing** — implementer hits an "unused argument" error and
  falls through to one of [A] or [B] anyway.

**Recommendation: A** — Spec is authoritative; pin the recipe.

---

#### Section: PR C, Final Checks

**Issue 16: `MEMORY.md` update — repo or auto-memory?**
Severity: SUGGESTION
Lens 4 (spec coverage)

Task 7.3 lists "`MEMORY.md` updated to reflect `get_anova()` as shipped"
as a quality gate. There is no `MEMORY.md` at the repo root. The
auto-memory `MEMORY.md` lives in
`~/.claude/projects/-Users-jacobdennen-surveycore/memory/MEMORY.md` and
is updated by the assistant out-of-band, not as part of a PR. The spec
§VIII Quality Gates uses the same wording.

Options:
- **[A]** Reword Task 7.3: "Update the Implementation Status table in
  `CLAUDE.md` to mark `get_anova()` as shipped (the in-repo equivalent
  of the spec's `MEMORY.md` reference)." — Effort: trivial.
- **[B]** Drop the line entirely; rely on Task 7.3's already-listed
  `CLAUDE.md` Implementation Status update. — Effort: trivial.

**Recommendation: B** — `CLAUDE.md` is already in the list and is
the durable, in-repo source of truth.

---

**Issue 17: Task 7.3 missing `R/zzz.R` modification check**
Severity: SUGGESTION
Lens 5 (file completeness)

Task 7.3 enumerates Quality Gates but does not explicitly verify that
Task 1.3's `R/zzz.R` change shipped — i.e., that
`registerS3method("anova", "surveycore::survey_glm_fit", ...)` is in
place. A trivial smoke check is `getS3method("anova",
"surveycore::survey_glm_fit")` returning the function.

Options:
- **[A]** Add a checklist item: "[ ] `getS3method('anova',
  'surveycore::survey_glm_fit')` returns a function (verifies dynamic
  S3 registration in `R/zzz.R::.onLoad()`)." — Effort: trivial.
- **[B] Do nothing** — covered indirectly by the comparison-mode S3
  test (`anova(fit1, fit2)` produces same result as `get_anova()`).

**Recommendation: A** — One-line gate, much faster signal than
discovering the registration was missed via a downstream snapshot
diff.

---

#### Section: Notes for the Implementor

**Issue 18: Implementor note on "@fit_ dependencies at a glance" is contradicted by Pass 2 Issue 16**
Severity: SUGGESTION
Lens 4 (spec coverage)

The implementor note table reads:

> Sequential Wald — does NOT need `@fit_` (serialization-safe)

This is correct for sequential Wald specifically, but the note above the
table doesn't restate the **comparison-mode** caveat from spec §3.3.1
("Comparison-mode caveat") — which is that comparison Wald *does* need
`@fit_` on both models for the n-invariance check, regardless of method.
A reader skimming the implementor notes for the rules-of-thumb table
might miss this and write a brittle test.

Options:
- **[A]** Add a row to the note's table: "Comparison Wald — needs
  `@fit_` on both models (n-invariance check; A-11 in comparison
  mode)." — Effort: trivial.
- **[B] Do nothing** — the table already has "Comparison, any method"
  row that says "needs @fit_ on both models". (Re-reading: yes, this
  row exists. The "@fit_ dependencies at a glance" table covers all
  three cases correctly.)

**Recommendation: B** — On second read, the table is accurate. No
change needed. Logging this issue as resolved-on-rereview to document
the audit.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 8 |
| SUGGESTION | 9 |

**Total issues:** 18

**Overall assessment:** The plan is methodologically sound and faithful
to the spec, but ships with one blocking accuracy bug (Issue 2:
`make_survey_data()` cannot construct nonprob/srs designs) plus several
required clarifications around test-fixture construction (A-19, A-20,
two-phase oracle, Fay-BRR oracle) and a real signature mismatch on
`.validate_shared_args()`. Once the blocking and required issues are
resolved in Stage 3, the plan is ready to hand off to `/auto-ship`.

---

## Plan Review: get-anova — Pass 2 (2026-04-18)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Precondition check for PR A/B outputs | ✅ Resolved (Task 1.0 added) |
| 2 | `make_survey_data()` can't build nonprob/srs | ✅ Resolved (`make_all_designs()`) |
| 3 | `.validate_shared_args()` signature mismatch | ✅ Resolved (Task 1.2 factors helper) |
| 4 | "19 new rows" off-by-one | ✅ Resolved (18 rows) |
| 5 | Task 1.3 commit-boundary trap | ✅ Resolved (explicit warning) |
| 6 | label attach vs name_style ordering | ✅ Resolved (labels first) |
| 7 | nonprob happy-path unexpected warning | ✅ Resolved (expect_warning added) |
| 8 | A-19 trigger hand-wavy | ✅ Resolved (`make_replicate_nonconverger()`) |
| 9 | A-20 mutation helper unspecified | ✅ Resolved (`.testhelper_clobber_domain`) |
| 10 | Non-default contrasts `options()` leak | ✅ Resolved (`withr::local_options`) |
| 11 | n-invariance wording imprecise | ✅ Resolved |
| 12 | Task 3.4 self-contradiction | ✅ Resolved (sentence struck) |
| 13 | A-5 dual assertion split | ✅ Resolved (two blocks) |
| 14 | Two-phase oracle setup unspecified | ✅ Resolved (`survey::twophase()` pinned) |
| 15 | Fay-BRR arg name mismatch | ⚠️ Partially (recipe pinned, API gap still open) |
| 16 | `MEMORY.md` quality-gate line | ✅ Resolved (dropped) |
| 17 | `R/zzz.R` smoke check missing | ✅ Resolved (`getS3method()` added) |
| 18 | `@fit_` table contradiction | ✅ Resolved on re-review |

### New Issues

#### Section: PR C, Numerical Oracle Tests

**Issue 19: Fay-BRR oracle still has an unresolved API gap — blocks handoff**
Severity: BLOCKING
Lens 3 (acceptance criteria) / Lens 5 (file completeness)

Task 6.1's Fay-BRR oracle block (lines 425-439) resolves the "wrong arg
name" problem from Pass 1 Issue 15 by pinning the recipe, but leaves a
genuinely open question in the plan body:

> **Gap:** `as_survey_replicate()` has no `rho` argument (spec §VII
> references a nonexistent `as_survey_repweights(..., rho =)` API). …
> If `make_survey_data(type = "fay")` does not already encode ρ = 0.3,
> flag this to spec review before implementing this oracle block.

The `decisions-get-anova.md` entry confirms this was punted: "may need
to return to spec review." Per the skill's HARD-GATE rule, Stage 3 is
not complete until all issues are resolved and `decisions-{id}.md` is
populated with answers. "May need to return to spec review" is not an
answer — it is an unresolved question that the implementer will hit at
Task 6.1 and have to escalate mid-implementation.

Options:
- **[A]** Inspect `make_survey_data(type = "fay")` (`helper-test-data.R`)
  before handoff and make the determination now: does it encode ρ = 0.3?
  If yes, strike the "may need spec review" caveat. If no, decide now
  whether to (i) extend the fixture in this PR, (ii) compute Fay weights
  inline in the test, or (iii) drop the Fay-BRR oracle entirely. Record
  the answer in `decisions-get-anova.md`. — Effort: low, Risk: low.
- **[B]** Defer the Fay-BRR oracle to a follow-up PR; strike it from
  Task 6.1 and add a FIXME tracker. — Effort: trivial, Risk: low. Ships
  PR C without Fay coverage.
- **[C] Do nothing** — implementer hits the gap, stops, escalates,
  breaks the "autonomous handoff" contract of `/auto-ship`.

**Recommendation: A** — The determination is one `grep` away; resolving
it now costs a minute, vs. stalling a multi-hour auto-ship run.

---

#### Section: PR C, Infrastructure

**Issue 20: Task 1.2 refactor of `.validate_shared_args()` needs a regression safety-net**
Severity: REQUIRED
Lens 3 (acceptance criteria)

Task 1.2 factors a shared helper out of `.validate_shared_args()` (used
by every existing `get_*()` analysis function). This is a refactor of
a load-bearing shared helper. The plan does not list "all existing
analysis tests still pass" as a gate before proceeding to Cycle A.
If the refactor silently changes behavior (e.g., error-class order,
environment capture via `call = rlang::caller_env()`, or which argument
triggers the `invalid_decimals` error in mixed-bad-input scenarios),
every downstream `get_*()` test could go red and mask ANOVA-specific
failures during TDD cycles.

Options:
- **[A]** Add a sub-step to Task 1.2: "After refactor, run
  `devtools::test(filter = 'analysis')` (or equivalent — cover all
  `get_*()` test files); all must pass GREEN before Task 1.3." — Effort:
  trivial.
- **[B]** Fold the regression check into Task 7.2 (`devtools::check()`).
  — Effort: trivial, but discovers breakage much later.
- **[C] Do nothing** — breakage surfaces during Cycle A and is confusing
  to triage.

**Recommendation: A** — Fail fast; the shared-helper refactor is the
highest-blast-radius change in the PR.

---

#### Section: PR C, TDD Cycle B

**Issue 21: A-12 comparison-mode trigger should reference `.testhelper_clobber_domain()`**
Severity: SUGGESTION
Lens 5 (file completeness)

Task 4.1 lists the A-12 comparison-mode trigger as:

> A-12 (`surveycore_error_n_mismatch`): two fits on the same design but
> different row subsets (construct via `..surveycore_domain..` mutation)

The A-20 trigger (Task 2.1, lines 175-181) adds a
`.testhelper_clobber_domain(fit, value)` helper for exactly this
mutation pattern. Task 4.1's A-12 block should reuse it rather than
leaving the implementer to reinvent the `S7::set_props()` chain.

Options:
- **[A]** Update Task 4.1's A-12 bullet: "…construct by calling
  `.testhelper_clobber_domain()` (defined in Task 2.1) on one of the two
  fits to produce a mismatched row-count slice." — Effort: trivial.
- **[B] Do nothing** — implementer will probably find the helper and
  reuse it.

**Recommendation: A** — Zero cost; prevents parallel reinvention.

---

**Issue 22: Label preservation through `name_style = "broom"` rename is tested implicitly, not asserted**
Severity: SUGGESTION
Lens 4 (spec coverage)

Task 2.1 tests `name_style = "broom"` renaming and separately tests that
column-level `label` attributes are attached per §3.7.3 using surveycore
column names. The ordering fix (Pass 1 Issue 6) requires labels to be
attached *before* `.apply_name_style()` runs, which only works correctly
if `.apply_name_style()` preserves `attr(col, "label")`. The plan
mentions in passing ("`.apply_name_style()` preserves
`attr(col, 'label')`") but lists no explicit test:

- With `name_style = "broom"`, assert `attr(result$p.value, "label")`
  equals `"P-Value"` (the label was attached under name `p_value` and
  survived the rename to `p.value`).

Without the explicit assertion, a future refactor of `.apply_name_style()`
that drops attributes would break `get_anova()` label rendering silently.

Options:
- **[A]** Add to Task 2.1's label block: "With `name_style = 'broom'`,
  `attr(result$p.value, 'label')` equals `'P-Value'` and
  `attr(result$df_residual, 'label')` equals `'Denom df'` — proves
  label preservation through the rename." — Effort: trivial.
- **[B] Do nothing** — relies on `.apply_name_style()` never regressing
  and on the plan's informal claim.

**Recommendation: A**.

---

**Issue 23: A-8 and A-13 triggers remain hand-wavy (same class as resolved Pass 1 Issue 8)**
Severity: SUGGESTION
Lens 3 (acceptance criteria)

Pass 1 Issue 8 got A-19 pinned via `make_replicate_nonconverger()`
because "extremely heterogeneous eigenvalues" and "floating-point luck
across CI versions" are real reproducibility hazards. The same class of
hazard remains for A-8 and A-13:

- A-8: "construct a fit where the saddlepoint root-finder returns `NA`
  (extremely heterogeneous eigenvalues)" (line 188-190)
- A-13: "near-singular V₀ via a near-collinear factor interaction"
  (line 193-194)

Both require pathological numerical conditions. They may be reproducible
in practice (more so than quasi-separation, because the triggers are
geometric rather than optimizer-dependent) but the plan does not pin
deterministic recipes the way it now does for A-19.

Options:
- **[A]** Pin a recipe for each: for A-8, a synthetic V₀ with an
  eigenvalue spread of `c(1, 1e-16)` (or similar) that drives
  `.saddle()` past its iteration cap; for A-13, a factor interaction
  with a combination containing exactly one observation in the design
  (guaranteed singular `V0[idx, idx]`). Add corresponding fixtures if
  non-trivial. — Effort: medium.
- **[B]** Accept that both are harder to pin deterministically than
  A-19 and mark the tests with `skip_on_cran()` + a comment noting
  the empirical trigger. — Effort: low.
- **[C] Do nothing** — most likely outcome: flaky tests on one CI
  platform, caught in review of Cycle A.

**Recommendation: A** — A-13 in particular (singleton cell) is trivial
to construct deterministically; A-8 is harder but still pinnable via
direct `.saddle()` call with a controlled eigenvalue vector, which
could live as a unit test on the vendored saddlepoint helper itself.

---

### Section: Other parts of the plan

No new issues found in PR Map, Files, Task 1.0-1.3 (beyond Issue 20),
Task 3.1-3.4, Task 5.1-5.2, Task 7.1-7.4, Acceptance Criteria, or
Notes for the Implementor.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 3 |

**Total new issues:** 5
**Pass 1 issues still open:** 1 (Issue 15, partial — the Fay-BRR API
gap, elevated to Pass 2 Issue 19 as BLOCKING)

**Overall assessment:** Pass 1's resolutions held; the only real
regression is the Fay-BRR oracle's unresolved spec gap (Issue 19), which
per the HARD-GATE rule blocks handoff to `/r-implement` or `/auto-ship`.
Issue 20 (post-refactor regression check for `.validate_shared_args()`)
is a cheap required insurance policy. Issues 21-23 are trivial quality
wins. Once Issue 19 is answered in `decisions-get-anova.md` and Issue 20
is added to Task 1.2, the plan is handoff-ready.
