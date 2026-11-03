# Spec Review: svydesign-replicate-bridge — Pass 1 (2026-09-04)

Six lenses, one Explore agent each. Every factual claim below was
re-verified against survey 4.5 in this worktree before being accepted; the
verification column says so. Three lens claims failed re-verification and are
recorded as rejected at the end.

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 5 |
| REQUIRED | 9 |
| SUGGESTION | 6 |

**Total:** 20

**Assessment:** The three settled decisions survive review intact. What review
found is a ring of unhandled states around them. Five are hard failures: one
condition template that cannot raise its own class, two replicate types that
cross the import route and then throw a bare `survey` error on export, a
degenerate design the spec calls unreachable and is not, and a Fay export that
throws today and would still throw after this change ships. Four of the five
were invisible to the drafting pass because they need a `survey` call to see.

## BLOCKING

**B1 — `surveycore_error_repwt_name_collision` cannot raise its own class**
Lens 3. Verified: reproduced.

§V.2's `"v"` bullet carries `{?s}` with no quantity in that bullet. cli
evaluates each bullet as its own string, so `cli_abort()` throws
`simpleError: Cannot pluralize without a quantity` before the typed condition
is constructed. No `expect_error(class = "surveycore_error_repwt_name_collision")`
could ever pass. CB-1 and CB-3 were checked the same way and render correctly.

Resolution: reworded and re-verified in both numbers. See §Applied.

**B2 — `subbootstrap` and `mrbbootstrap` cross the import route and then break export**
Lens 4. Verified: reproduced.

`survey::as.svrepdesign()` accepts
`c("auto", "JK1", "JKn", "BRR", "bootstrap", "subbootstrap", "mrbbootstrap", "Fay")`
and stores the literal string. `survey::svrepdesign()` accepts a different set
that excludes `subbootstrap` and `mrbbootstrap`. `.from_svydesign_replicate()`
calls the bare S7 constructor, whose validator does not check `type`, so import
stores the value silently; export then fails with
`'arg' should be one of "BRR", "Fay", ...` — a bare `simpleError`.

This falsifies the spec's own Observable Property 8, "Every replicate type
converts in both directions."

**B3 — a zero-row `svyrep.design` is reachable, and the spec says it is not**
Lens 4. Verified: reproduced.

§III.6 declines a guard on the stated ground that "`survey::svrepdesign()` and
the `survey_replicate` validator both need at least one row". The validator in
`R/core-classes.R` has no row-count check; that check lives in
`.validate_data_frame()`, which only `as_survey_replicate()` calls, and the
import route does not. Built directly: a zero-row `survey.design` through
`as.svrepdesign(type = "JK1")` gives `nrow(variables) == 0`, a 0x0 replicate
matrix and `length(pweights) == 0`. The route returns an empty but valid
object, raising nothing.

**B4 — zero replicate columns on export produce a bare `survey` error**
Lens 4. Verified: reproduced.

§IV.6 has no row for `@variables$repweights` of length 0, a state B3 can
produce. `survey::svrepdesign()` with a zero-column matrix fails with
`missing value where TRUE/FALSE needed`, from inside its own
`combined.weights` heuristic. The same class of outcome §IV.7 treats as
unacceptable elsewhere.

**B5 — Fay export throws a hard error today, and §IX mischaracterizes it**
Lens 5. Verified: reproduced, and the proposed fix verified exact.

§IX describes the Fay gap as a design that "leaves the bridge with a different
scale factor". The real behaviour is a hard stop:
`svrepdesign.default` contains
`if (type == "Fay" && is.null(rho)) stop("With type='Fay' you must supply the correct rho")`,
and the export route passes no `rho`. Reproduced: `ERR With type='Fay' you must
supply the correct rho`.

§IX also claims closing it needs a new key on `survey_replicate`, reaching
`R/core-classes.R` and the constructors. That is false. `rho` is recoverable
from the `scale` the import route already stores:

```
scale = 1 / (n_rep * (1 - rho)^2)   =>   rho = 1 - sqrt(1 / (scale * n_rep))
```

Verified: stored `rho` 0.3 recovers as 0.3 exactly; rebuilding gives scale
0.170068 against the source's 0.170068, and SE 0.1841391 against the source's
0.1841391. The computation sits entirely inside
`.as_svydesign_replicate()`, on the declared write surface.

## REQUIRED

**R1 — step 9's "leave the column" branch can name a column of unrelated values**
Lens 5.

`survey::svrepdesign()` takes `variables` and `repweights` as independent
arguments with no cross-check, so a repweights column name can coincide with a
data column holding different values. Under the spec's rules — names came from
survey, so the collision check is skipped; `combined.weights` is `TRUE`, so no
fold-in; the name is already a column, so step 9 writes nothing — the design
would store `@variables$repweights` naming a column of unrelated data. That is
the silent-wrong-SE failure #197 exists to remove, reintroduced in a corner of
the new logic. Harmless in the common case where `variables` carries the same
columns by construction.

**R2 — §V.1 lists a state that cannot reach the check**
Lens 5, and the drafting pass said the same. Step 4 intercepts a zero-length
`colnames()` and generates names, which are `n_rep` distinct non-empty strings
by construction. So "zero names" never reaches step 5. Only a partly named or
duplicate-named vector does.

**R3 — `{.arg data}` names an argument that does not exist**
Lens 3. `from_svydesign(x)` takes only `x`. `data` is an internal local.
`{.arg data}` renders as `data` and tells the caller they can pass it.

**R4 — the warning's `"v"` bullet addresses the user**
Lens 3. "when you need" is second person, which `code-style.md` forbids.

**R5 — `NA` in `x$pweights` propagates to every replicate column**
Lens 4. Reachable: `survey::svydesign()` has an `na_weights` argument and
`na_weights = "allow"` accepts NA weights (confirmed in the formals). The
validator's non-positive check excludes NA, so construction passes. The fold-in
`rep_mat * x$pweights` then turns the whole row NA across all `R` columns, not
just the weight column. The spec addresses NA in the matrix, not in `pweights`.

**R6 — negative replicate weights are not addressed**
Lens 4. The validator checks replicate columns for numeric only, not sign;
only the base weight column is checked for positivity. Negative replicate
weights occur in some calibrated replicate files. Behaviour is pass-through but
unstated.

**R7 — the metadata path over the newly written columns has no test row**
Lens 2, with a correction. Lens 2 proposed asserting that metadata "produces
entries for every name in `repweights`". That assertion would fail:
`.extract_haven_metadata()` records an entry only for a column carrying a label
attribute, and the generated columns are plain doubles. The true claim behind
step 11's ordering is that appending `n_rep` columns before metadata is built
leaves the base columns' labels intact and adds no entries of its own.

**R8 — the "named by survey but absent from data" branch has no test row**
Lens 2. Verified constructible: a named replicate matrix passed to
`svrepdesign()` whose names are not columns of `data` builds and keeps its
`colnames`. That combination exercises the second half of step 9's write
condition on the pass-through branch, which no current row reaches.

**R9 — the roxygen contract becomes false, and new columns go undocumented**
Lens 6. `?from_svydesign` states "The data, design variables, and replicate
weights are preserved". On the fold-in branch the replicate weights are
transformed, not preserved. The docstring is also silent on the generated
column block, which for a JK1 or JKn design is one column per PSU. The same
docstring already documents the `..surveycore_wt..` precedent, so it is exactly
where a reader would look. §II.1 and Quality gate 8 currently forbid any
`man/` change.

## SUGGESTION

- **S1** — each condition's trigger is restated in four places with nothing
  tying them together (Lens 1). Partly applied: one location per condition is
  marked normative and §V.4 is flagged as a paraphrase. The branch tables keep
  their predicates, because replacing them with pointers defeats what the
  tables are for.
- **S2** — the collision message says "rename the conflicting column" without
  naming the only realistic cause, a previous conversion's columns still in the
  data (Lens 6).
- **S3** — the spec never states why the fold-in is silent while the FPC drop
  warns. The distinction is correction against information loss; saying so
  forecloses the question (Lens 6).
- **S4** — `.repwt_col_names()`'s stated contract requires `n_rep >= 1`, but
  step 4 can call it with 0 (Lens 4). Ties to B3.
- **S5** — the manufactured `..surveycore_wt..` column gets no collision guard
  while generated replicate names get a typed error (Lens 4). Pre-existing
  behaviour, more conspicuous beside the new guard.
- **S6** — the `is.matrix()` claim in §III.2 step 2 is wrong (Lens 5).
  Verified: `is.matrix()` returns `TRUE` on a `"repweights"`-classed matrix,
  because it tests the `dim` attribute, not the class. The `as.data.frame()`
  collapse to one column is real and is sufficient justification on its own.

## Claims rejected on re-verification

- Lens 2's proposed metadata assertion would fail as written. Corrected in R7.
- Lens 3's proposed fix for B1 renders "1 generated name is already column of",
  dropping the article. A phrase-level plural was substituted and verified in
  both numbers.
- Lens 5's `is.matrix()` correction is right, but it was filed as a minor
  rationale error; it also invalidates a sentence added during Stage 2
  resolution, so it is tracked as S6 and fixed.

## Verdict

**NEEDS-DECISION.** B1, R1 to R8 and S1 to S6 are UNAMBIGUOUS and are applied
without a question. B2, B3 with B4, B5 and R9 each expand the change beyond the
three decisions the request settled, and each admits more than one defensible
answer. They go to the user.

---

# Delta Pass 2 (2026-09-04)

Two Explore agents, changed sections only, per the review-loop budget.

## `spec.md` — clean

The agent traced every "step N" cross-reference against the renumbered
13-step §III.2 and 7-step §IV.2 lists and found all of them correct. It
confirmed the new type check and row-count check sit before the matrix
expansion, that the base-weight search still precedes the replicate write, and
that the metadata build cites both. It tested the two new cli templates in R,
checked the paste-ready block against the real `plans/error-messages.md` for
column layout and identifier collisions, and found no stale Fay-gap,
`is.matrix()` or "leave a column" text. No issues.

## `test-spec.md` — three issues, all confirmed by re-measurement

**D1 — an `NA` base weight cannot reach the conversion. BLOCKING.**

Row I-25 asserted that a design carrying an `NA` base weight converts and
turns the whole replicate row `NA`. Not reachable. `survey::svydesign()` drops
every row whose weight is `NA`, on all three `na_weights` settings:

```r
if (any(is.na(pre_weights))) { data <- data[!is.na(pre_weights), ]
```

Only `"fail"` stops before that line; `"warn"` warns and drops, `"allow"`
drops in silence. Measured: a 10-row frame with one `NA` weight gives a 9-row
design and no `NA` in the base weights. Passing such a matrix straight to
`survey::svrepdesign()` fails inside its own `combined.weights` heuristic.

This retires spec-review Pass 1 finding R5, which was accepted on the strength
of `na_weights` appearing in the formals. That proved the argument exists, not
that it keeps an `NA` in the design. The false claim had reached `spec.md`
§III.4 and §III.6 and `test-spec.md` I-25. All three are corrected: the state
is now recorded as unreachable, with the source line and the measurement.

**D2 — the metadata row called a constructor as an accessor. BLOCKING.**

Row I-22 read the metadata as `names(survey_metadata(d)@variables)`.
`survey_metadata` is the S7 class constructor, not an accessor: handed a
design it aborts with `@variable_labels must be <list>, not
<surveycore::survey_replicate>`. A `survey_metadata` object also has no
`@variables` property — its properties are `variable_labels`, `value_labels`,
`question_prefaces`, `notes`, `var_extra`, `universe`, `missing_codes` and
others. Corrected to `d@metadata@variable_labels`, verified to read back
`"y1"` on a labelled fixture.

Worth noting for a future reader: `.claude/rules/code-style.md` states that
`@data` and `@metadata` "have exported accessors (`survey_data()`,
`survey_metadata()`)". `survey_data()` works. `survey_metadata()` does not
behave as an accessor. The rule file is inaccurate on that half. Out of scope
here; recorded in §IX.1 as a follow-up.

**D3 — the fixture rationale was false. REQUIRED.**

§3.5 justified a separate balanced fixture on the ground that
`make_survey_data()` "produces imbalanced strata on purpose", and R-5 claimed
"the §3.1 fixture cannot build a Fay design". Measured: `make_survey_data()`
allocates PSUs by integer division with no random part, so `n_psu = 12` over
`n_strata = 3` gives 4 PSUs in every stratum, and both Fay and BRR build on
§3.1 with no error and no warning.

The underlying constraint is real — an odd PSU count per stratum fails with
`Can't split with odd numbers of PSUs in a stratum` — but §3.1 already
satisfies it. The fixture is kept for isolation, so a BRR or Fay row does not
depend on §3.1's parameters continuing to divide evenly, and both rationales
are rewritten to say that.

## One issue found outside the delta agents

**D4 — both arms of the Fay condition are reachable. REQUIRED.**

The Stage 3r resolver corrected a claim in decision D4, reporting that a Fay
design with no recorded scale is unreachable because `as_survey_replicate()`
fills `scale = 1 / n_rep`. It instructed the builder to treat that arm as
defensive and mark it `# nocov`, and told the test-spec to write no row.

Half right. The premise holds — measured, `as_survey_replicate(type = "Fay")`
records `scale = 0.125` on 8 replicates and recovers `rho = 0`, which is
legal. The conclusion does not. `survey_replicate` is exported
(`NAMESPACE:113`), its `variables` argument is an untyped list, and its
validator checks neither `scale` nor `type`. Measured: the bare constructor
accepts a `"Fay"` design with no `scale` key and returns an object with
`@variables$scale` `NULL`. Issue #198's own reproduction uses exactly that
construction.

So both arms are reachable by different routes, neither needs a coverage
exemption, and the test-spec gains rows C-17 and C-18. See decision D8.

## Verdict

**PASS.** Every finding was UNAMBIGUOUS and is applied. The row count moves
from 57 to 58: I-25 becomes a recorded non-row, C-17 and C-18 are added.
