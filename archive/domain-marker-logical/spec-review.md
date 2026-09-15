# Spec Review — domain-marker-logical — Pass 1 (2026-09-12)

Six lenses ran in parallel over `spec.md` and `test-spec.md`. Each lens read
the real source, not the spec's description of it. The findings below are
deduplicated: two pairs of lenses reported the same defect from different
directions, and both merges are recorded.

## New issues

### BLOCKING

**Issue 1: A fourth existing test block writes a non-logical marker column, and the spec's "measured" claim denies it**

Severity: BLOCKING
Section: `spec.md` §Scope → Out; `test-spec.md` §Existing blocks that change
Found by: Lens 6 (API coherence) and Lens 3 (contract completeness), independently
Rule violated: the spec's own quality gate 3, and the error-ordering rule in `code-style.md`

`tests/testthat/test-conversion.R:3313` holds the block
"as_svydesign() selects the same rows for every marker column type". It builds
a five-element `markers` list — logical, integer, double, character, factor —
and for each one it runs `d@data <- df` and then `expect_no_condition()`.

Under the validator, four of the five iterations abort at the assignment. The
block fails outright, not one assertion inside it.

The test-spec states, under "Measured, 2026-09-12": "These three are the only
non-logical writers among the fourteen test files." That is false. The
test-spec also tells the builder not to re-run the grep to decide scope, and
to run it only at the end as gate 3. A builder who obeys finds this block
after the scope is closed. Gate 3 and gate 7 then both fail for a reason the
plan never named.

The comment above the block states the premise this work removes: "Nothing in
the package guarantees the column is logical, no validator checks its type."
The #245 reversal is therefore wider than the issue records. The issue's §Fix
names only the factor block at `:3357`. The real reversal is the cross-type
coercion contract this loop pins for four wrong types.

The orchestrator read the block in the source and confirms it.

Options:

- **A** Add a fourth row, E.4. Rewrite the block so the logical iteration keeps
  the row-count and probability assertions, and each non-logical iteration
  asserts `surveycore_error_domain_not_logical` at the write. Rename the block
  for what it now asserts. Correct the "Measured" note to four. — Effort: low,
  Risk: low.
- **B** Delete the block. Rows 1.5 to 1.8 already cover the four wrong types on
  a Taylor design, so the block's surviving purpose is the probability-vector
  check on the one legal type. — Effort: low, Risk: low.
- **C** Do nothing — the suite goes red on a block nobody was told to touch,
  and a false measured claim ships in the spec.

**Recommendation: A** — it keeps the block's original regression value for the
one type that stays legal, and it follows the rewrite pattern the spec already
set for E.3.

---

**Issue 2: The spec commits to one PR that its own test surface puts four times over the PR budget**

Severity: BLOCKING
Section: `spec.md` header ("PR range: PR 1"); §Pipeline tier
Found by: Lens 5 (engineering level)
Rule violated: `artifact-schemas.md` §PR budget

The bound is 12 test-spec rows per PR. The count here is 45 new rows plus 3
modified blocks, 48 in all. The rule states that a PR past either bound
"splits before the plan reaches PLAN_READY", and no exception is written
anywhere in the pipeline-shared references.

The spec's reason for one PR is that the existing blocks "fail on the line
that adds the validator", so they cannot land in a separate PR without leaving
the suite red between them. That argument binds the existing blocks to the
validator. It does not bind the `.apply_domain()` `NA` resolution, the
conversion-helper cleanup, or forty-five test rows to the same PR.

This is a JUDGMENT_CALL. It sets how every other finding is grouped, so it is
resolved first.

Options:

- **A** Split into two PRs. PR 1: the validator, the error class, the
  `plans/error-messages.md` row, and the fix to the existing blocks, with §1
  and §2 as its test surface. PR 2: `.apply_domain()`'s `NA` to `FALSE`
  resolution, the conversion-helper cleanup, and §3 to §6. — Effort: medium,
  Risk: low. Both halves are independently coherent. PR 2 may still need a
  further split.
- **B** Ship one PR with a written exception recorded against the calibration
  ledger, on the ground that the row count is inflated by near-identical
  invariance rows rather than by real complexity. — Effort: low, Risk: medium.
  No exception mechanism exists in the rule today.
- **C** Do nothing — the plan stage rejects the PR range and the work returns
  here.

**Recommendation: A** — split by dependency, not by topic. The "cannot go red"
constraint binds only the validator to the existing blocks.

---

### REQUIRED

**Issue 3: No shared test fixture helper is specified for roughly thirty duplicated blocks**

Severity: REQUIRED
Section: `test-spec.md` §1, §2, §3
Found by: Lens 1 (DRY)
Rule violated: `engineering-preferences.md` §1 — "do not defer DRY violations to later"

§3 says "One fixture serves every row in this section. Build it once per
block," then gives a four-step build: a Taylor design, a mask, design A with
one `TRUE` changed to `NA`, and design B with that element changed to `FALSE`.
That build is meant to run in thirteen blocks. The spec names no helper, so
the wording reads as an instruction to author the same four steps thirteen
times.

§1 and §2 carry the same gap across roughly eighteen rows: read the data out,
put a marker column of the named type on it, and assign it back.

Options:

- **A** Name the helpers in the test-spec — one that returns the A and B
  fixture pair, one that sets a marker column of a named type — and say where
  each is defined. — Effort: low, Risk: low.
- **B** Leave the spec silent and trust the builder to extract them. — Effort:
  none, Risk: medium.
- **C** Do nothing — about thirty inline copies land, and a later pass unwinds
  them.

**Recommendation: A** — name the helper, so the duplication is never written.

---

**Issue 4: The two-phase branch of the printed domain line has no test**

Severity: REQUIRED
Section: `test-spec.md` §4
Found by: Lens 5 (engineering level) and Lens 4 (edge cases). Lens 4 rated it
SUGGESTION and Lens 5 rated it REQUIRED. The higher rating stands, because the
issue names the line itself.

`.print_domain_info()` at `R/methods-print.R:170-186` has two branches. The
two-phase branch at line 177 indexes the marker column by the phase-2 mask:
`sum(x@data[[SURVEYCORE_DOMAIN_COL]][ph2_mask], na.rm = TRUE)`. The plain
branch at line 181 does not index. Rows 4.1 to 4.3 all use a Taylor design, so
line 177 runs nowhere in this plan, and no existing test prints a two-phase
design that carries a marker column.

§4's stated purpose is that the printed line agrees with the analysis count.
That is unverified for the one class whose print line takes a different route.

Options:

- **A** Add one row: print a two-phase design with an `NA` marker row and a
  phase-2 mask, and assert the count matches the same design with that row
  `FALSE`. — Effort: low, Risk: low.
- **B** Leave it. Both branches carry `na.rm = TRUE`, so the risk is low by
  inspection. — Effort: none, Risk: low to medium.
- **C** Do nothing.

**Recommendation: A** — one row, and the issue cites this line number itself.

---

### SUGGESTION

**Issue 5: The rationale for excluding the four `as.logical()` calls is wrong for one of the four**

Severity: SUGGESTION
Section: `spec.md` §Scope → Out
Found by: Lens 1. Lens 5 traced the same four sites and agreed the exclusion
is right, so only the stated reason is at fault.

The spec says all four calls in `R/analysis-corr-latent.R` "coerce a mask that
`.apply_domain()` already produced, so this change makes them no-ops". That
holds for lines 1295, 1378 and 1441, which receive `pair_active`, already a
logical vector. It does not hold for line 1776. That call reads
`.corr_latent_pair()`'s own `active_domain` parameter, and its caller at
`R/analysis-corr.R:450` runs `active_domain <- as.numeric(active_mask)`. The
incoming value is numeric, so the call is a real conversion and stays needed.

The exclusion is correct either way. Only the reason needs a correction, so a
later reader does not delete line 1776 as dead code.

**Recommendation:** correct the sentence to separate line 1776 from the other
three.

---

**Issue 6: The "no new `test_invariants()` call" justification is false for two constructors**

Severity: SUGGESTION
Section: `test-spec.md` §Invariants
Found by: Lens 2 (test completeness)

The test-spec says every file it names "already calls the helper for the
constructors it uses". `tests/testthat/test-s7-classes.R` calls
`test_invariants()` seven times, for Taylor and for non-probability only. It
never calls it for a replicate or a two-phase design, though it builds both
repeatedly. New rows 1.2, 1.3 and 2.4 build exactly those two.

**Recommendation:** correct the justification to name the pre-existing gap.
Closing the gap is a low-cost bonus and sits outside the stated scope.

---

**Issue 7: The single-bullet precedent cites the wrong row**

Severity: SUGGESTION
Section: `spec.md` §Function contracts → Errors
Found by: Lens 3 (contract completeness)

The spec cites row 22, `surveycore_error_subset_not_logical`, as "the model
row for this check". Row 22 is the `as_survey_twophase()` constructor's own
pre-construction check — Layer 3 — and its message uses `{.arg subset}`. The
S7-validator analog that carries the same class is row 38, and its message
shape matches the new one. Both rows carry one `"x"` bullet, so the
substantive claim holds.

**Recommendation:** cite row 38.

---

**Issue 8: No case covers a `class()` vector longer than one**

Severity: SUGGESTION
Section: `spec.md` §Edge cases; `test-spec.md` §1
Found by: Lens 3 and Lens 4. The two lenses disagree on the fix: Lens 3
recommends adding the row, and Lens 4 recommends leaving it.

Row 1.7 tests an unordered factor. An ordered factor returns
`c("ordered", "factor")` from `class()`. Lens 3 confirmed against cli that
`{.cls {col_class}}` renders it as `<ordered/factor>`, so there is no
rendering defect. Lens 4 confirmed `is.logical()` returns `FALSE` for an
ordered factor, a complex vector and a raw vector, so the generic check
already rejects all three.

**Recommendation:** add one line to the edge-case table naming the rendering.
The extra test row is optional — the check is generic, and five types already
establish it.

---

**Issue 9: The accept path is proved on one or two classes, not four**

Severity: SUGGESTION
Section: `test-spec.md` §2
Found by: Lens 4 (edge cases)

§1 proves the reject path on all four concrete classes. §2 proves the accept
path mostly on Taylor, with only row 2.4 repeated on replicate. Two-phase and
non-probability never see an accept-path row.

**Recommendation:** state in the spec why one class stands in for four on the
accept path, or add one two-phase row.

---

**Issue 10: The "five readers" list counts two writers as readers**

Severity: SUGGESTION
Section: `spec.md` §Scope → Out
Found by: Lens 4 (edge cases)

`R/analysis-t-test.R:314` and `:810` both assign to the marker column. They are
writers. The spec lists them among five readers, next to the separate claim
that `surveytidy::filter()` is "the only intended producer". Both statements
cannot hold. The values written are logical, so nothing breaks.

**Recommendation:** name the two internal writes as writers, and narrow the
"only producer" claim to external producers.

---

**Issue 11: `is.logical()` accepts a matrix-shaped or classed logical column**

Severity: SUGGESTION
Section: `spec.md` §Edge cases
Found by: Lens 4, confirmed empirically

`is.logical()` returns `TRUE` for a one-column logical matrix, and for a
logical vector that carries any class attribute other than `haven_labelled`,
which the `@data` setter strips. Neither case appears in the spec. Ad hoc
indexing and `sum()` behave correctly on a one-column logical matrix.

**Recommendation:** add one line stating the check tests storage type only, and
that it accepts any object for which `is.logical()` is `TRUE`. Rejecting a
matrix shape would widen the contract and needs its own row.

---

**Issue 12: `get_anova()` is a named reader and is absent from the invariance battery**

Severity: SUGGESTION
Section: `test-spec.md` §3
Found by: Lens 5 (engineering level)

The spec names the ANOVA refit check at `R/glm-anova.R:61` as one of five
readers. §3 lists thirteen functions and omits `get_anova()`. Invariance
likely holds transitively, because `get_anova()` builds its statistics from
repeated `survey_glm()` fits and row 3.13 covers `survey_glm()`.

**Recommendation:** add one row, or record the transitive argument.

---

**Issue 13: Seven rows in §3 assert a fact the shared helper already proves**

Severity: SUGGESTION
Section: `test-spec.md` §3, rows 3.1 to 3.13
Found by: Lens 5 (engineering level)

Nine of the thirteen functions read the mask through the identical one-line
call `domain_mask <- .apply_domain(design)`, with no further `NA`-sensitive
logic before they index. `get_t_test()` and `get_pairwise()` build bespoke
mask combinations and earn their own rows. `survey_glm()` is the base case.

Lens 5 would cut rows 3.2, 3.3, 3.5, 3.6, 3.7, 3.8 and 3.9, taking §3 from 15
rows to 8. Cutting them stops catching only a caller-specific regression where
one function reads the raw column in place of the helper.

This finding pulls against `engineering-preferences.md` §2, "more tests is
better". §1 of the same file, DRY, is the stated tiebreaker. It also interacts
with Issue 2: cutting seven rows moves the row count toward the budget.

**Recommendation:** resolve with Issue 2, not on its own.

---

**Issue 14: The near-identical "not logical" check bodies now number seven**

Severity: SUGGESTION
Section: `spec.md` §Function contracts
Found by: Lens 1 (DRY)

The codebase carries at least six inline "is this logical, if not abort"
blocks of the same shape, in `R/core-classes.R`, `R/core-constructors.R`,
`R/core-metadata.R` (three) and `R/utils.R`. This work adds a seventh.

Lens 1 confirmed the new validator does **not** duplicate the two-phase
`subset` check at `R/core-classes.R:800-816`. That check reads a per-instance
column name relevant to one class, and the new one reads a fixed constant
relevant to all four. The spec's refusal to copy the check into four subclass
validators is the right call.

**Recommendation:** no change in this PR. Inline and explicit matches the house
convention and `engineering-preferences.md` §5. Recorded for a future
consolidation.

---

**Issue 15: Row 1.11 does not build the mixed-write case it describes**

Severity: SUGGESTION
Section: `test-spec.md` §1 row 1.11
Found by: Lens 4 (edge cases)

The spec's edge-case table says a failed assignment leaves the design at its
previous value. Row 1.11 asserts only that the data holds no marker column. It
does not write one frame that both adds a bad marker column and changes an
unrelated column, and it does not assert the unrelated column reverted.

Lens 4 confirmed the rollback empirically against a minimal S7 class. The
guarantee comes from S7's replacement semantics, not from this work.

**Recommendation:** no change required. Extending the fixture is cheap if the
builder wants the proof.

---

**Issue 16: The message names the column but not the failing write**

Severity: SUGGESTION
Section: `spec.md` §Function contracts → Errors
Found by: Lens 6 (API coherence)

The `"i"` bullet points at the producer, `surveytidy::filter()`, not at the
call site. R's own backtrace supplies the call context.

**Recommendation:** no change. Two bullets are enough for the developer
audience the spec names.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 2 |
| SUGGESTION | 12 |

**Total issues:** 16, after two duplicate pairs merged.

**Verdict: NEEDS-DECISION.** Issue 2, the PR split, is a JUDGMENT_CALL, and it
decides how every other finding is grouped. Issue 1 is a factual error in the
spec's own measured claim, and it routes to Stage 3r after the split is
settled.

**Overall assessment:** the mechanism is sound. Every S7 claim the spec makes
about validator timing, rollback and parent dispatch was checked against the
real source or a minimal reproduction, and all of them hold. The spec's
weakness is its inventory of what the change breaks, not its design. It misses
a fourth test block that its own verification grep finds, and it commits to a
single PR four times over the documented budget.

## Lens tallies before deduplication

| Lens | Blocking | Required | Suggestion |
|---|---|---|---|
| 1 — DRY | 0 | 1 | 2 |
| 2 — Test completeness | 0 | 0 | 1 |
| 3 — Contract completeness | 0 | 1 | 2 |
| 4 — Edge cases | 0 | 0 | 6 |
| 5 — Engineering level | 1 | 2 | 2 |
| 6 — API coherence | 1 | 0 | 1 |

Merges: Lens 6 issue 1 with Lens 3 issue 1, kept at the higher severity as
Issue 1 above. Lens 5 issue 2 with Lens 4 issue 1, kept at the higher severity
as Issue 4 above.

One lens reached a wrong answer. Lens 2 re-checked the "three non-logical
writers" claim and confirmed it, having checked only the three blocks the
claim names. Lens 3 and Lens 6 found the fourth. The orchestrator read the
block in the source and confirms the fourth exists.

---

## Spec Review: domain-marker-logical — Pass 2 (2026-09-12)

A delta pass, per the review-loop budget. Two Explore agents, not six. Each
read only the sections the resolver changed, plus the findings it verified.
Neither re-read a whole document.

### Prior issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | A fourth existing test block writes a non-logical marker column | Resolved — E.4 added, measured note corrected to four |
| 2 | One PR, four times over the PR budget | Resolved — three PRs, per D1 |
| 3 | No shared test fixture helper | Resolved — two helpers named and placed |
| 4 | The two-phase printed domain line has no test | Resolved — row 4.4 added |
| 5 | The `as.logical()` rationale is wrong for one of four | Resolved — line 1776 separated |
| 6 | The `test_invariants()` justification is false | Resolved — gap named, not closed |
| 7 | The single-bullet precedent cites the wrong row | Resolved — now row 38 |
| 8 | No case covers a `class()` vector longer than one | Resolved — documented, no row, per D13 |
| 9 | The accept path is proved on one or two classes | Resolved — row 2.8 added |
| 10 | The reader list counts two writers as readers | Resolved — four readers, two writers |
| 11 | `is.logical()` accepts a matrix or classed column | Resolved — storage-type line added |
| 12 | `get_anova()` absent from the invariance battery | Resolved — transitive argument recorded, per D14 |
| 13 | Seven rows in §3 assert a fact already proved | Resolved — cut, per D2. See new issue 17 |
| 14 | The "not logical" check bodies now number seven | No change, as decided |
| 15 | Row 1.11 does not build the mixed-write case | No change, as decided |
| 16 | The message names no failing call site | No change, as decided |

### New issues

#### REQUIRED

**Issue 17: The row cut cited a gate that does not cover the regression**
Severity: REQUIRED
Section: `test-spec.md` §3, "Six functions, not thirteen"
Found by: delta agent 2

The paragraph justifying the seven-row cut said "a package-wide source sweep
looks for exactly that pattern, and it is one of this work's quality gates".
The regression it names is a direct read: an analysis function that stops
calling the shared helper and reads the raw marker column.

Gate 2 greps for `SURVEYCORE_DOMAIN_COL]] <-`. That matches an assignment. A
read is not an assignment, so gate 2 never sees it. No other gate in the list
of twelve covered it, and no rule file or CI check in the repository did
either. The paragraph named no command, where every other sweep in both
documents quotes one.

**Resolution applied in this pass.** Gate 13 was added to `spec.md` and the
paragraph was rewritten. See [[D17]] in `decisions.md`.

```
grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R
```

It must return exactly `R/analysis-helpers.R`, `R/analysis-t-test.R` and
`R/glm-anova.R`. A fourth file means an analysis function names the column
directly. The gate runs on PR 2 and PR 3.

Measured 2026-09-12 on this branch: the command returns those three files and
no other. None of the seven cut functions lives in any of them, so a
regression in one would add a fourth file and fail the gate.

`decisions.md` D2 carried the same superseded claim. It now points at D17.

---

### What Pass 2 verified, beyond the fixes

Both agents checked claims against the source rather than against the
documents. Worth recording, because two Pass 1 defects came from unchecked
claims:

- **Every PR leaves the test suite green on its own.** This is the constraint
  that drove the split, and it was not verified when the split was chosen. It
  holds. No existing test puts an unresolved `NA` through the analysis mask —
  the one test that reads the helper uses a `TRUE`/`FALSE` mask. The
  conversion helper's coercion can receive nothing non-logical once PR 1's
  validator lands, so removing it in PR 3 breaks nothing in between.
- **The four non-logical writers are the only four.** A third independent
  sweep returned the same four sites.
- **Row 4.4 reaches the branch it targets.** The two-phase branch indexes the
  marker column by the phase-2 mask, and the row's assertion matches that
  code.
- **Row 38 is the S7-validator row** carrying `surveycore_error_subset_not_logical`,
  and row 22 is the constructor-layer row.
- **`<ordered/factor>` renders as stated.** Confirmed by calling cli directly.
- **Six `test_invariants()` calls** in `test-s7-classes.R`, not seven. The
  seventh string occurrence is a block description. Both documents and
  `decisions.md` now say six.
- **`as.numeric(active_mask)` sits at `R/analysis-corr.R:451`**, not 450.
  Corrected in `decisions.md`.
- **No `R/` path survives in `test-spec.md`.** The two-artifact rule holds.

### Row counts, stated honestly

| PR | Sections | Rows | Against the 12-row bound |
|---|---|---|---|
| 1 | §1 (11), §2 (8), E.1–E.4 (4) | 23 | 11 over |
| 2 | §3 (8) | 8 | clears |
| 3 | §4 (4), §5 (5), §6 (4) | 13 | 1 over |

Total 44, down from 48. Both agents counted the rows independently and confirm
these figures. PR 1 cannot shrink by moving the four existing blocks — they
fail the moment the validator lands. Its remaining size is the product of four
wrong types across four design classes.

This is a known, stated overrun, not a hidden one. The plan stage decides
whether to split PR 1 further.

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 0 |

**Total new issues:** 1, resolved in this pass.

**Verdict: PASS.** The one finding required a change, the change is applied,
and the gate behind it was measured rather than assumed. The loop closes at
pass 2 of the 3 the budget allows. A third pass would read one added gate and
one rewritten paragraph, both already verified against the source.

**Overall assessment:** the artifacts now match the source on every claim two
delta agents could check. The one figure a reader should not skip is the PR 1
row count: 23 against a bound of 12, stated in the test-spec itself, with the
reason it cannot shrink.
