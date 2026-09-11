# Spec review — as-svydesign-domain

## Spec Review: as-svydesign-domain — Pass 1 (2026-09-09)

**Verdict: NEEDS-DECISION**

Three BLOCKING findings and nine REQUIRED findings after de-duplication, which
alone would read FAIL. One of the three BLOCKING findings is a judgment call
the orchestrator cannot settle from the artifacts, so the verdict is
NEEDS-DECISION per `.claude/skills/pipeline-shared/references/signals.md`
§Review verdicts. The user decides B-1; the rest resolve in Stage 3r.

Six lenses ran in parallel against `spec.md` and `test-spec.md`, each against
one criterion. Findings below are de-duplicated across lenses, with the
originating lens named. Two lenses reproduced measurements independently and
agreed with `findings-edge-cases.md`, which was measured by the orchestrator
before the lenses returned; where two instruments agree, the finding says so.

### Lens results before de-duplication

| Lens | BLOCKING | REQUIRED | SUGGESTION |
|---|--:|--:|--:|
| 1 — DRY | 0 | 1 | 0 |
| 2 — Test completeness | 0 | 4 | 1 |
| 3 — Contract completeness | 0 | 1 | 1 |
| 4 — Edge cases | 2 | 2 | 1 |
| 5 — Engineering level | 0 | 0 | 2 |
| 6 — API coherence | 1 | 3 | 1 |
| Orchestrator measurement, F8 to F11 | 1 new | 1 new | 0 |

### What the lenses confirmed as correct

Recorded so Stage 3r does not re-open settled ground.

- Three call sites cover five routes. Lenses 1 and 5 both read
  `R/methods-conversion.R` and confirmed the two `survey_nonprob` branches at
  lines 148 and 169 dispatch into the Taylor and replicate helpers and build no
  object of their own.
- The change adds no ninth copy of the `survey_nonprob` routing predicate that
  issue #246 tracks.
- All five error and warning classes the spec names exist verbatim in the source
  and each has a row in `plans/error-messages.md`. Lens 3 checked every name and
  every line: `surveycore_error_not_survey_object` at `:177`,
  `surveycore_error_repweights_empty` at `:246`,
  `surveycore_error_fay_rho_unrecoverable` at `:324`,
  `surveycore_warning_nonprob_srs_conversion` at `:167`,
  `surveycore_warning_replicate_fpc_dropped` at `:366`.
- Each of those five fires before an object exists to restrict, so the
  restriction cannot reach them. Lens 3 verified the firing order in the source
  rather than accepting the claim.
- The write-surface correction from `NEWS.md` to
  `changelog/fix-as-svydesign-domain.md` is right. Lens 5 checked the
  `changelog/` directory, `changelog/docs-changelog-workflow-flat-path.md`, and
  `/merge-main` step 2, which reads
  `git diff <last-tag>..develop --name-only | grep "^changelog/"`. `impact.md`
  is the document in error.
- The vignette stays out of the write surface. It contains no occurrence of
  "domain".
- Every factual claim `test-spec.md` makes about the existing test suite holds.
  Lens 2 verified all five: the `test_invariants()` placement, the absence of
  any pre-existing filtered-design test anywhere under `tests/`, the integer
  marker at `test-analysis-quantiles.R:460`, the availability of `nhanes_2017`,
  and the export of `SURVEYCORE_DOMAIN_COL` at `NAMESPACE:41`.
- `SURVEYCORE_DOMAIN_COL` is exported and documented, so naming it in
  `test-spec.md` breaks no two-artifact rule.
- No "TBD" and no GAP marker in either document.
- The pipeline tier `recommended` is the correct value.
- The roughly 32 planned test blocks are proportionate, not padding. Lens 5 was
  asked for a straight answer and gave one.

### New Issues

#### BLOCKING

**Issue B-1: The restriction is silent for an ordinary domain, and the spec extends D5 to a case D5 never argued**

Severity: BLOCKING — JUDGMENT_CALL, needs a user decision
Section: `spec.md` §Function contracts → `as_svydesign(x)` → Warnings; `decisions.md` D5
Lens 6. Violates the API-coherence bar "technically correct but will cause user
error in a realistic workflow".

`CLAUDE.md` draws surveycore's own line: `filter()` marks a domain and keeps
every row; `subset()` removes rows and issues a strong warning. This change
makes `as_svydesign()` remove rows while keeping `filter()`'s silence.

The spec states: "The restriction itself raises no condition on any route and
for any domain, including the empty one (D5)." D5 argued only the **empty**
domain, and its reason was that `surveytidy::filter()` has already warned at
filter time. No such upstream warning exists for an ordinary partial domain.
`decisions.md` records no decision that argues the ordinary case on its own
terms; it was swept in under D5's heading.

The workflow Lens 6 traced: a user filters a design to flag a subgroup, keeps
the object, and later calls `as_svydesign()` on it to reach a `survey` function
surveycore does not wrap. Before this change they got the full sample. After it
they get the domain, silently. The current roxygen at
`R/methods-conversion.R:88-101` documents the full-sample behaviour as intended
and tells the caller to subset by hand, so a user relying on it is following the
documentation and not only the bug.

Options:

- **A** Emit a `cli::cli_inform()` line when the restriction is non-trivial, that is when `0 < n_domain < n_total`, naming the row count before and after. No new condition class, so `plans/error-messages.md` stays untouched. — Effort: low. Risk: low, but it fires on every conversion of a filtered design, including inside `as_tbl_svy()`, and `cli_inform()` output is not suppressible with `suppressWarnings()`. Impact: closes the gap the `subset()` convention exists to prevent. Maintenance: one more condition for roughly 30 new test blocks to tolerate.
- **B** Stay silent, and record a new decision D7 that argues the ordinary case on its own terms rather than folding it under D5. Carry the behaviour change prominently in `changelog/fix-as-svydesign-domain.md`, which is where a user meets a breaking change. — Effort: low. Risk: low. Impact: the choice becomes traceable and deliberate; the user still gets no signal at the call site. Maintenance: none.
- **C** Add a typed warning class. — Effort: medium. Risk: low. Impact: strongest signal. Maintenance: a new row in `plans/error-messages.md`, a new dual-pattern test, and a warning on a call that is now doing the correct thing, which reads as punishing the fixed behaviour. Contradicts `spec.md` §Out.

**Recommendation: B.** The conversion is now correct, and warning on correct
behaviour trains users to ignore the warning. What the user needs is to learn
once, at upgrade time, that the output changed, which is a changelog entry and
not a per-call message. Option A also carries a cost the lens did not price:
`cli_inform()` on every filtered conversion would have to be tolerated by every
one of the roughly 30 new test blocks.

---

**Issue B-2: The two-phase route does not remove rows, so §Scope and test row B-3 assert something measurably false**

Severity: BLOCKING
Section: `spec.md` §Scope → In; §Function contracts → Route matrix; `test-spec.md` B-3
Orchestrator measurement, `findings-edge-cases.md` §F8. No lens found this.

`[.twophase` takes two paths. On a calibrated design, or with `drop = FALSE`,
it keeps every row and sets the excluded rows' probability to `Inf`:

```r
if (is.logical(i)) {
    x$prob[!i] <- Inf
    x$phase2$prob[!i] <- Inf
}
```

The measured fixture takes that path. With 12 of 29 phase-2 rows marked:

| Quantity | After `sv[rs, ]` |
|---|--:|
| `phase1$sample` rows | 29 |
| rows with infinite probability | 17 |
| `svymean(~y1, .)` | 58.06658 |

The estimate is right. The row count does not change. `subset()` behaves
identically here, so this is a property of the two-phase design and not of the
operator D1 chose.

`spec.md` §Scope says the two-phase route delivers "The converted object carries
only the rows the domain marks". `test-spec.md` B-3 asserts "The converted
object's phase-1 sample carries one row per marked phase-2 row" and would get
29 against 12.

Options:

- **A** Correct both documents. §Scope says the two-phase route applies the domain by zero-weighting, with the row count unchanged; B-3 asserts that the count of finite probabilities equals the marked count, which is the observable carrying the meaning. — Effort: low. Risk: low. Impact: the documents describe what the operator does. Maintenance: none.
- **B** Force row removal on the two-phase route, by `drop = TRUE` semantics or by rebuilding the object. — Effort: high. Risk: high; it would diverge from what `survey`'s own `subset()` does on a two-phase design, and the estimate is already correct without it. Impact: uniform row semantics across five routes. Maintenance: a hand-rolled path `survey` does not support.
- **C** Do nothing. The spec ships a false scope claim and one test row fails on the first run.

**Recommendation: A.** The estimate is already correct on that route. Only the
description of the mechanism is wrong.

---

**Issue B-3: A factor marker column builds a corrupt object, so the claim that `r & !is.na(r)` is the whole coercion is wrong**

Severity: BLOCKING
Section: `spec.md` §Function contracts → `.restrict_to_domain()` → Row mask, Errors, Warnings
Lens 4 Issue 2 and orchestrator measurement `findings-edge-cases.md` §F10,
measured independently, agreeing.

The spec covers logical, integer and double, and asserts the helper "raises no
condition of its own". Measured on the 200-row Taylor fixture, 107 rows marked:

| Marker column | Rows after the mask | Condition |
|---|--:|---|
| logical | 107 | none |
| integer `0`/`1` | 107 | none |
| double `0`/`1` | 107 | none |
| character | — | error: `operations are possible only for numeric, logical or complex types` |
| factor | 200 | warning: `'&' not meaningful for factors` |

The character column raises an unclassed base error out of `as_svydesign()`,
which contradicts "raises no condition of its own". The factor column is worse:
`&` returns an all-`NA` mask, and indexing with it yields a 200-row object whose
probability vector is neither finite nor infinite. Estimating on it then dies
three frames down inside `survey` with `invalid 'type' (list) of argument`.

The state is reachable. Nothing constrains the column's type, no validator
checks it, and the package's own suite writes a non-logical marker at
`test-analysis-quantiles.R:460`.

Options:

- **A** Coerce with `as.logical()` before the mask: read `r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])`, then index by `r & !is.na(r)`. Measured correct on all five types — logical, integer, double, character, and a `FALSE`/`TRUE` factor — and an unrelated factor becomes an empty domain, which is safe and inspectable. Needs no new class, so §Out holds. — Effort: trivial, one word. Risk: low. Impact: removes both the corrupt-object path and the character error. Maintenance: none.
- **B** Document the trap without closing it, naming both failure modes. — Effort: low. Risk: leaves a reachable corrupt-object path in a function whose contract says it raises nothing. Impact: none on behaviour.
- **C** Validate the type and refuse with a new error class. — Effort: medium. Risk: low. Impact: loudest. Maintenance: a new row in `plans/error-messages.md` and a dual-pattern test; contradicts §Out.

**Recommendation: A.** It is one word, measured correct on every reachable
type, and it keeps the no-new-class scope. The same defect in the analysis path
is now issue #262, whose suggested fix is the same expression inside
`.apply_domain()`.

---

#### REQUIRED

**Issue R-1: `.restrict_to_domain()` is a third reader of the marker column, and the three disagree on `NA`**

Severity: REQUIRED
Section: `spec.md` §Architecture → Functions added; §Function contracts → `.restrict_to_domain()`
Lens 1. Violates `.claude/rules/engineering-preferences.md` §1.

Two readers already exist. `.apply_domain()` at `R/analysis-helpers.R:482-488`
returns the column raw, with no `NA` resolution and no coercion.
`.print_domain_info()` at `R/methods-print.R:170-185` treats `NA` as outside the
domain, through `na.rm = TRUE`. The new helper resolves `NA` explicitly. The
spec names neither existing reader and gives no reason for a third.

Lens 1 also found that the raw pass-through in `.apply_domain()` is a live
defect and not only an inconsistency. The orchestrator measured it and filed
**issue #262**: five grouped `get_*()` functions silently report the wrong group
when the column holds integers, because eleven call sites index a data frame
with the raw mask.

Options:

- **A** Consolidate now: one primitive that all three readers call. — Effort: medium; reaches `R/analysis-helpers.R` and `R/methods-print.R`, both outside the declared write surface. Risk: medium; it changes behaviour the analysis suite pins today. Impact: one source of truth.
- **B** Keep the helper separate — it takes a bare frame and a `survey`-package object, not an S7 design, so it cannot call `.apply_domain(design)` as typed — and add one paragraph to its contract naming both existing readers, saying why neither is reused, and citing issue #262 for the divergence. — Effort: low, spec text only. Risk: low. Impact: the duplication is recorded rather than silent. Maintenance: none.
- **C** Do nothing. Three unreferenced readers of one column, two of which disagree on `NA`.

**Recommendation: B.** Consolidation is right and belongs with #262, which now
owns the analysis-path half. This spec should name the divergence and point at
it.

---

**Issue R-2: An empty domain does not give zero with a zero standard error on three of five routes**

Severity: REQUIRED
Section: `spec.md` §Documentation contract item 6; §Function contracts edge-case table; `test-spec.md` D-2, D-5
Lens 4 Issue 1 and orchestrator measurement `findings-edge-cases.md` §F9,
measured independently, agreeing.

| Route | rows after the mask | `svymean()` |
|---|--:|---|
| Taylor | 0 | 0, SE 0 |
| replicate | 0 | **errors**: `All replicates contained NAs` |
| two-phase | 29, see B-2 | **NaN** |

`as_svydesign()` stays silent on every route, so D5's decision holds as a
statement about the conversion. What is wrong is the claim about what happens
next, which the spec plans to put into user-facing roxygen and pins in test row
D-2 with no route named.

Options:

- **A** Scope the documentation and the test rows per route: Taylor and both non-probability shapes give zero with a zero standard error; the replicate route converts silently and then errors inside `survey` on estimation; the two-phase route gives `NaN`. — Effort: low, text only. Risk: low. Impact: the documentation becomes true. Maintenance: D-2 becomes three rows.
- **B** Narrow the roxygen to state only that the conversion is silent, and drop the claim about what `survey` then reports. — Effort: low. Risk: low. Impact: shorter and still true; the user learns less.
- **C** Do nothing, and ship roxygen that is false for three of five routes.

**Recommendation: A.**

---

**Issue R-3: `[.twophase` warns about single-PSU strata, so "raises no condition" and G-1's `expect_no_condition()` are both false on that route**

Severity: REQUIRED
Section: `spec.md` §Function contracts → `as_svydesign(x)` → Warnings; `test-spec.md` G-1
Orchestrator measurement `findings-edge-cases.md` §F11.

The same branch of `[.twophase` continues:

```r
index <- is.finite(x$prob)
psu <- !duplicated(x$phase2$cluster[index, 1])
tt <- table(x$phase2$strata[index, 1][psu])
if (any(tt == 1)) {
    warning(sum(tt == 1), " strata have only one PSU in this subset.")
}
```

A domain that thins a stratum to one PSU makes the conversion warn, with an
untyped `simpleWarning` from `survey`. The measured fixture did not trigger it.
A narrower domain on a stratified two-phase design would.

Options:

- **A** Name it as a pre-existing untyped condition from `survey`, the way the existing two-phase blocks in `test-conversion.R` already handle one with `suppressWarnings()`. G-1 keeps `expect_no_condition()` for the Taylor, replicate and non-probability routes and drops the claim for two-phase. — Effort: low. Risk: low. Impact: the contract stops asserting something false.
- **B** Do nothing. G-1 passes on the fixture that does not trigger it, and fails whenever someone writes a narrower two-phase domain.

**Recommendation: A.**

---

**Issue R-4: G-1's cross-reference for the two-phase route points at a row that does not cover it, and no idiom is given for the check it promises**

Severity: REQUIRED
Section: `test-spec.md` §two-phase route, §Error paths (G-1)
Lens 2 Issue 1.

The B-row preamble says the rows "assert separately that no new typed condition
appears (see G-1)". G-1 names only the Taylor, replicate and non-probability
routes. And `expect_no_condition()` cannot be used on the two-phase route at
all, because the pre-existing untyped warning would fail it. No technique is
described for "tolerate the known untyped warning, fail on any typed one", so a
tester has to invent one. R-3 compounds this by adding a second untyped warning
on that route.

Options:

- **A** Add a two-phase line to G-1 stating the technique concretely: assert that no condition whose class matches `^surveycore_` fires, which tolerates the untyped `survey` warnings by construction. — Effort: low. Risk: low.
- **B** Drop the cross-reference and put a concrete assertion inline in B-1.
- **C** Do nothing. The tester chooses, and the row may pass or fail on interpretation.

**Recommendation: A.**

---

**Issue R-5: Rows D-1 to D-6 and D-8 name no route, and the riskiest combination is untested**

Severity: REQUIRED
Section: `test-spec.md` §edge cases
Lens 2 Issue 4 and Lens 4 Issue 4, independently.

Only D-7 names its routes. Given R-2, the outcome of D-2 and D-5 genuinely
differs by route, so an unscoped row is ambiguous: written once against the
implicit Taylor default, the suite stays silent about the divergence. The
all-`FALSE` and all-`NA` cases on the two-phase route are the specific gap. That
route is the one the spec itself flags as special-cased, and B-2 shows its row
semantics differ.

Options:

- **A** Add a route column to the D table, and add two-phase variants of D-2 and D-5. — Effort: low. Risk: low. Impact: closes the combination both lenses independently identified.
- **B** State that D-1 to D-6 run on Taylor, and justify why the shared helper makes the other routes redundant. — Effort: low. Risk: leaves B-2's divergence untested.
- **C** Do nothing.

**Recommendation: A.**

---

**Issue R-6: The "marker column kept on every route" quality gate is tested on two of five routes**

Severity: REQUIRED
Section: `spec.md` §Quality gates; `test-spec.md` D-7
Lens 2 Issue 3.

The gate reads "The marker column is a name of the converted object's data on
every route, after the restriction." D-7 covers Taylor and two-phase. Rows A-2,
A-3 and A-4 assert numeric parity only and never check the column.

Options:

- **A** Add the two assertions — column present, every value `TRUE` — to A-2, A-3 and A-4. — Effort: low. Risk: low.
- **B** Narrow the gate's wording to the two routes actually tested, which weakens a stated guarantee rather than checking it.
- **C** Do nothing.

**Recommendation: A.**

---

**Issue R-7: Category 2, the numerical oracle, has no scenario for `as_tbl_svy()` and no written N/A**

Severity: REQUIRED
Section: `test-spec.md` §`as_tbl_svy()`
Lens 2 Issue 2.

E-1 and E-2 assert row counts and warning propagation. Neither compares an
estimate off the returned `tbl_svy` against an oracle. The wrapper-equivalence
argument — the body is unchanged and delegates wholly — is a legitimate reason,
but it is never written down, so the category is simply absent.

Options:

- **A** Add one oracle row on a filtered Taylor design. — Effort: low. Risk: low.
- **B** Write the N/A justification into the section: unmodified body, full delegation, and the five underlying shapes already carry oracle rows. — Effort: trivial.

**Recommendation: B**, with A welcome.

---

**Issue R-8: Call preservation is stated as D1's rationale, never as the helper's own return contract**

Severity: REQUIRED
Section: `spec.md` §Function contracts → `.restrict_to_domain()` → Returns
Lens 3 Issue 1.

The guarantee that the restriction operator preserves the stored call appears
only under the Restriction operator bullet, framed as the reason for choosing
`[` over `subset()`. It reappears at the caller's level and in the quality
gates, and never in the helper's own Returns. A maintainer reading that contract
in isolation — the one place they would look before changing the helper — has to
reconstruct the guarantee from a different decision's rationale. This is the
guarantee whose loss D1 measured.

Options:

- **A** Add one line to Returns: the returned object's stored call is identical to the input's, because the `[` operator never rewrites it. — Effort: trivial.
- **B** Leave it scattered across three places and absent from the helper's contract.

**Recommendation: A.**

---

**Issue R-9: The row-count narrowing never reaches `@return`, and two documentation consequences are unstated**

Severity: REQUIRED
Section: `spec.md` §Documentation contract
Lens 6 Issues 2, 3 and 4, merged.

Three gaps in the planned roxygen:

1. `@return` at `R/methods-conversion.R:43-50` says nothing about row count, and
   the spec keeps it untouched: "The rewrite replaces that one `@section` block
   and nothing else in the roxygen." The change fires on every filtered
   conversion, and the fact lands only in the fourth `@section`, after two
   narrower topics.
2. After a round trip, the rebuilt design's row count is its new total. The
   original N is unrecoverable from the object, and the print line
   `Domain: n of n rows` looks identical to a design that was never filtered.
   `survey_data()`'s own documentation at `R/utils.R:171` promises that printing
   a filtered design shows both, which now degenerates to the same number twice.
3. `as_tbl_svy()` hands a pre-restricted `tbl_svy` to `srvyr`, which has its own
   `filter()` with the opposite row semantics. A user chaining surveycore's
   `filter()` into `srvyr::filter()` meets two different verbs under one name,
   with no signal between them.

Options:

- **A** One sentence in `@return` pointing at the section; an eighth bullet on the round trip's row count; one sentence on the `srvyr::filter()` interaction. — Effort: low, three sentences, no code change. Risk: none.
- **B** Take only the `@return` sentence and leave 2 and 3 to discovery.
- **C** Do nothing.

**Recommendation: A.**

---

#### SUGGESTION

**Issue S-1: `.restrict_to_domain()` should derive the frame from the converted object rather than take it as an argument**

Severity: SUGGESTION
Section: `spec.md` §Function contracts → `.restrict_to_domain(converted, frame)`
Lens 5 Issue 1, reinforced by B-2.

The correct frame is a deterministic function of the converted object's class in
all three cases, and `from_svydesign()` already proves the data is recoverable:
it reads `x$variables` at lines 638 and 736 to rebuild `@data`. The
two-argument signature asks each call site to supply what the object already
carries, and D2 records the one time this went wrong, an unclassed
`logical subscript too long`. B-2 strengthens the case: the two-phase route
needs class-specific handling anyway, because its row semantics differ.

Recommendation: collapse to a one-argument helper that branches internally on
the two-phase class. That removes the argument which can be passed wrongly,
rather than documenting how to pass it rightly.

**Issue S-2: The two-phase marker column reaching the phase-1 sample variables is structural, not incidental**

Severity: SUGGESTION
Section: `spec.md` §Function contracts → Route matrix
Lens 4 Issue 5, verified across `method = "full"`, `"simple"` and `"approx"`.
The phase-1 sample variables are always a row-subset of the same `data`
argument, so any column in `@data` survives regardless of method. Calling it
"measured on one fixture" understates the guarantee and may prompt a needless
defensive check.

**Issue S-3: The pipeline-tier justification undercounts its disqualifiers**

Severity: SUGGESTION
Section: `spec.md` §Pipeline tier
Lens 5 Issue 2. The `optional` bar fails on two of four criteria and not one:
four files exceeds three, and the change is a contract and numerical change. The
verdict `recommended` is right either way.

**Issue S-4: No row covers domain restriction combined with labelled columns**

Severity: SUGGESTION
Section: `test-spec.md`
Lens 2 Issue 5. The file already carries labelled round-trip rows on unfiltered
designs. Row-indexing a labelled column ordinarily preserves its attributes, so
the risk is low. The lens recommends recording the reasoning rather than adding
the row, so the absence does not read as an oversight.

**Issue S-5: `surveycore_error_pkg_not_installed` is omitted from the error table**

Severity: SUGGESTION
Section: `spec.md` §Function contracts → `as_svydesign(x)` → Errors
Lens 3 Issue 2. `R/methods-conversion.R:118-128` raises it before dispatch. It
is `nocov`-marked boilerplate, and the table's point — that the restriction
reaches none of these — holds for it too. Lens 3 recommends leaving it out.

## Summary (Pass 1)

| Severity | Count |
|---|--:|
| BLOCKING | 3 |
| REQUIRED | 9 |
| SUGGESTION | 5 |

**Total issues:** 17, de-duplicated from 20 raw lens findings.

**Overall assessment:** the spec is well built on the ground it covers. Every
class name, firing order, call-site count and claim about the existing test
suite that a lens checked against the source held up, which is unusual. Its
three blocking problems are all the same kind: a fact measured on the Taylor
route, then written as though it held on all five. The two-phase route does not
remove rows, an empty domain does not give zeros outside the Taylor route, and
the row mask coerces only three of the five column types it can meet. Two of the
three have text-only fixes and the third is one word. The single genuine
judgment call is B-1: whether a conversion that now silently returns fewer rows
should say so.

---

## Spec Review: as-svydesign-domain — Pass 2, delta (2026-09-09)

A delta pass per the review-loop budget: two agents, not six, reading only the
sections Stage 3r changed plus the findings they verify. Neither read a whole
document.

### Prior issues (Pass 1)

| # | Title | Status |
|---|---|---|
| B-1 | Silence for an ordinary domain | ✅ Resolved — option B, D7 recorded |
| B-2 | Two-phase route does not remove rows | ✅ Resolved — option A |
| B-3 | Factor marker builds a corrupt object | ✅ Resolved — option A, D9 |
| R-1 | Third reader of the marker column | ✅ Resolved — option B, D10, cites #262 |
| R-2 | Empty domain outcome per route | ✅ Resolved — option A |
| R-3 | Two-phase single-PSU warning | ✅ Resolved — option A |
| R-4 | Broken G-1 cross-reference | ✅ Resolved — option A |
| R-5 | Unstated route on the D rows | ✅ Resolved — option A |
| R-6 | Marker gate tested on two of five routes | ✅ Resolved — option A |
| R-7 | No oracle scenario for `as_tbl_svy()` | ✅ Resolved — option B, N/A written down |
| R-8 | Call preservation absent from Returns | ✅ Resolved — option A |
| R-9 | Narrowing never reaches `@return` | ✅ Resolved — option A, all three parts |
| S-1 | Helper should derive its own frame | ✅ Resolved — applied, D11 |
| S-2 | Phase-1 sample arrival is structural | ✅ Resolved — applied |
| S-3 | Tier justification undercounts | ✅ Resolved — applied |
| S-4 | No labelled-column row | ✅ Resolved — applied, reasoning recorded |
| S-5 | `surveycore_error_pkg_not_installed` omitted | ✅ Resolved — left out, as recommended |

Both agents returned PASS. The two-artifact rule and the four-file write surface
were checked separately and are clean.

### What the resolver did beyond the findings

Two things, both correct, both flagged by the resolver rather than slipped in.

1. **It refused R-2's recommended wording.** The finding said "Taylor and both
   non-probability shapes give 0 with a zero standard error". The resolver
   declined to write an unmeasured claim into user-facing roxygen and marked the
   cell as a GAP instead. The orchestrator then measured it — `findings-edge-cases.md`
   §F12 — and the finding's wording was wrong: the split follows the converted
   class, not the input class. Three outcomes across five routes. Both GAP
   markers are now closed with the measurement.
2. **It scoped the all-`TRUE` marker claim in four places no finding named**,
   because the two-phase route removes no rows and so keeps `FALSE` values in
   the column. This was a consequence of B-2 that B-2 did not enumerate.

### New issues

**Issue P2-1: The round-trip claims are written in Taylor terms and are false for the two-phase route**

Severity: BLOCKING
Section: `spec.md` §Function contracts → `from_svydesign(x)`; §Documentation contract item 8
Raised by the orchestrator after both delta agents returned. Delta agent A
explicitly declined to judge this text, as it sat outside its three named
targets.

`from_svydesign()` dispatches on the two-phase class at
`R/methods-conversion.R:614`, so that shape does make the round trip. Four
claims were unscoped and all four are false for it. Measured in
`findings-edge-cases.md` §F13: the restricted object holds 29 phase-1 sample
rows with 12 `TRUE`, and the rebuilt design holds 60 rows with 28 `TRUE`,
printing `Domain: 12 of 29 Phase 2 rows`.

Resolved: all four claims scoped to the routes that remove rows, the two-phase
behaviour stated beside them, decision **D12** recorded, and test row **F-6**
added to pin it.

## Summary (Pass 2)

| Severity | Count |
|---|--:|
| BLOCKING | 1 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total new issues:** 1, resolved in the same pass.

---

## Spec Review: as-svydesign-domain — Pass 3, targeted sweep (2026-09-09)

The last pass in the budget, spent on one question rather than six lenses. P2-1
was the fourth claim written from the Taylor route and stated as though it held
on all five. Four separate discoveries of one defect shape is a pattern, not a
coincidence, so this pass swept both documents for a fifth — and for the inverse
no earlier pass had looked at: a claim correctly scoped to the row-removing
routes whose two-phase counterpart is then never stated at all.

The agent read both documents in full and reported its sweep by claim family:
roughly 10 row-count claims, 8 marker-column claims, 9 condition claims, 6
estimate-and-oracle claims, 6 stored-call and round-trip claims, every test row,
and all 13 quality gates.

### Prior issues (Pass 2)

| # | Title | Status |
|---|---|---|
| P2-1 | Round-trip claims false for the two-phase route | ✅ Resolved — D12, test row F-6 |

### New issues

**Issue P3-1: One quality gate is scoped to the row-removing routes and states no two-phase counterpart**

Severity: REQUIRED
Section: `spec.md` §Quality gates

> "The marker column is a name of the converted object's data on every route,
> after the restriction. On the four routes that remove rows, every value in it
> is `TRUE`."

The presence claim covers every route and is right. The value claim is scoped
and is right. Nothing then says what the two-phase route's marker values are.
Every other use of that same scoping in the document pairs it with an explicit
two-phase sentence — the `as_svydesign()` Returns bullet, the `from_svydesign()`
contract, and documentation contract items 4 and 8. This gate was the only place
the pattern broke, and it is the gate a tester consults to know what to assert
about the marker column.

Resolved: the counterpart sentence added, in the wording the document already
uses elsewhere — on the two-phase route the column is unchanged and still holds
`FALSE` for the zero-weighted rows.

### The inverse check, first run in this pass

Five occurrences of the row-removing scoping in `spec.md`. Four already paired.
The fifth was P3-1. `test-spec.md` carries no unpaired occurrence.

## Summary (Pass 3)

| Severity | Count |
|---|--:|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 0 |

**Total new issues:** 1, resolved in the same pass.

**Verdict across all three passes: PASS.** 18 findings raised, 18 resolved. No
finding remains open and no GAP marker remains in either document.

**The one thing a later reader should know.** Six of the twelve decisions exist
because a fact measured on the Taylor route was written as though it held on all
five, and the pattern was found four separate times before a pass went looking
for it deliberately. The documents are correct now. That correctness came from
measurement, not from drafting, so anyone adding a claim about what the
converted object carries should check the two-phase route before writing it.
