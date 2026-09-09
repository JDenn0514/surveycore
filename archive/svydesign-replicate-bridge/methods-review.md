# Methodology Review: svydesign-replicate-bridge — Pass 1 (2026-09-04)

## Scope assessment

The spec defines no estimator, no degrees-of-freedom formula and no domain
logic. It changes what reaches the variance machinery: the replicate weight
columns themselves, and whether a finite population correction crosses the
bridge. Lenses applied on that basis:

| Lens | Applied | Reason |
|---|---|---|
| 1 — Estimator specification | No | The spec defines no estimator. |
| 2 — Variance estimation | Yes | The fold-in changes the inputs to replicate variance; the FPC decision changes what survey applies. |
| 3 — Degrees of freedom and inference | No | The spec states no df formula and no CI construction. |
| 4 — Domain estimation | No | Neither conversion route reads a domain or a group. |
| 5 — Established practice | Yes | Both routes are bridges to `survey`; every behaviour has a `survey` counterpart to compare against. |
| 6 — Literature cross-check | Yes | `comprehension.md` exists and plays the role of the literature. |

## New issues

### Lens 2 — Variance estimation

**Issue 1: the recorded-but-unused FPC is visible only on the export path**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

A `survey_replicate` design's FPC is inert today, independent of this change.
A user who calls `as_survey_replicate(..., fpc = fpc_col)` and never exports
gets a design whose `print()` reports an FPC that enters no standard error,
and nothing warns at construction or at analysis. The warning this change adds
is the only place the fact becomes visible, and only for users who export.

Resolution: out of this write surface — `R/core-constructors.R` and
`R/variance-replicate.R` are excluded by §I.2. Recorded for a follow-up issue.
Does not block.

Lens 2 raised no BLOCKING and no REQUIRED issue. It independently confirmed
two things the spec asserts:

- The row-wise product is the correct inverse of the factor form for **all
  nine** replicate types `survey::svrepdesign()` supports, not only the three
  measured in `comprehension.md`. `combined.weights` is a design-level flag,
  not a per-type one, so every type defines a replicate weight the same way.
  `scale` and `rscales` are structural constants of the variance formula and
  depend on replicate count and design type, not on the units of the weight
  column, so passing them through unchanged is correct.
- No code path reads the FPC on the replicate route. Verified beyond
  `R/variance-replicate.R`: every `.replicate_*_cell()` helper in
  `R/analysis-means-helpers.R` and `R/analysis-totals-helpers.R`, and the
  `mats$fpcs` uses in `R/analysis-freqs-helpers.R`,
  `R/analysis-covariance-helpers.R`, `R/analysis-variance-helpers.R`,
  `R/analysis-corr-latent.R` and `R/glm.R`, all sit inside Taylor-only cell
  functions.

### Lens 5 — Established practice

Five ADVISORY records, no BLOCKING and no REQUIRED. Three carry facts that
strengthen the settled decisions and are folded into `comprehension.md` and
`decisions.md` in the resolution below.

**Issue 2: `combined.weights` is a live flag, and the export declaration is correct usage**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`weights.svyrep.design` reads the flag at call time:

```r
analysis = if (object$combined.weights) as.matrix(object$repweights)
           else as.matrix(object$repweights) * object$pweights
```

So the flag is functional, not documentation. Declaring `combined.weights` as
`TRUE` for a matrix that already holds finished weights is the flag's intended
value for that data shape, not an abuse of it. What does not survive a round
trip is the original design's literal boolean; nothing downstream depends on it
once the columns are normalized. Strengthens D2. Folded in.

**Issue 3: `survey` itself uses warn-and-drop for an FPC it cannot represent**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`survey::as.svrepdesign()` contains:

```r
else if (type %in% c("Fay", "BRR"))
  warning("Finite population correction dropped in conversion")
```

D3 is therefore not merely defensible — it repeats a pattern `survey` already
applies on its own conversion route: warn, name the field, drop, keep going.
The spec drops for every type rather than only Fay and BRR, because the per-row
and per-replicate quantities differ even for the types survey would accept, but
the pattern is survey's own. Strengthens D3. Folded in.

**Issue 4: a `svyrep.design` stores no raw FPC at all**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`svrepdesign.default`'s return list is
`list(type=, scale=, rscales=, rho=, call=, combined.weights=)`. The raw `fpc`
value is never stored — only its already-applied effect on `rscales` survives.
So the import route's `fpc = NULL` is not a choice; there is no field to read.
Folded into the reference mapping.

**Issue 5: generated column names conflict with no known convention**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`survey::svrepdesign()` has no reserved-prefix discovery mechanism; the caller
always names or selects columns explicitly. The export route passes a plain
data-frame slice rather than a formula, so the double-dot names never reach
`formula()` or `model.frame()`. The reviewing agent could not inspect
`srvyr::as_survey_rep()` in its session — introspection calls segfaulted five
times, unrelated to this change — so the srvyr half is marked `[verify]`.
Recorded as a confirmatory step, not a blocker: srvyr takes `repweights` via
an explicit tidyselect argument and does no name-pattern matching.

**Issue 6: Fay is the one remaining SE-divergent case, and BRR is not**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Verified against source: for Fay, `scale <- 1/(ncol(repweights) * (1 - rho)^2)`;
for BRR, `scale <- 1/ncol(repweights)`. BRR's scale has no free parameter, so
it reproduces exactly regardless of source. Fay's depends on `rho`, which
`survey_replicate` cannot store. That asymmetry is why the §IX gap is Fay-only.
Sharpens the gap statement. Folded in.

**Issue 7: how an FPC should combine with replication variance is unsettled in the wider literature**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`survey::svrepdesign()`'s public `fpc=` applies one scalar per replicate, while
its internal builders `jk1weights` and `jknweights` apply the correction at
stratum level. The two entry points treat the question differently. The general
debate is not settled `[verify]`. This does not touch D3: the argument holds
either way, because surveycore's replicate variance reads no FPC at all. Flagged
so a future reader does not read "warn and drop" as a claim that translation is
impossible in principle. It is impossible for this codebase's variance
formulas, which is the sufficient reason.

### Lens 6 — Literature cross-check

Clean on questions 1, 2, 4 and 5: the fold-in branch assignment matches
`comprehension.md` F1 with no reversed branch; all eight gotchas have a
corresponding treatment in the spec; all four assumptions are reflected or
deferred; D1, D2 and D3 are each implemented as stated, including D3's
documented divergence on bootstrap.

Four issues, all UNAMBIGUOUS.

**Issue 8: the `unclass()` claim had no counterpart in `comprehension.md`**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Spec §III.2 step 2 asserts that `as.matrix(x$repweights)` returns an object
still classed `"repweights"`, and makes that claim load-bearing for the ordered
steps. `comprehension.md` never recorded it and the measurement log had no
entry for it.

Resolution: the claim was measured in this run but not written down. Added to
`comprehension.md` §Gotchas and §Measurement log. Confirmed:
`class(as.matrix(x$repweights))` is `"repweights"` for an uncompressed source;
`is.matrix()` is then `FALSE` and `as.data.frame()` collapses the matrix to one
column.

**Issue 9: "about 35% too small" contradicts the measurement log**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Spec §III.1 attributes "about 35% too small" to "a measured JKn design", while
`comprehension.md` F1 records 0.1775 against 0.1633 on the JKn design measured
here — about 8%. The 35% figure comes from issue #197, measured on `gss_2024`
with 50 bootstrap replicates, a different design.

Resolution: correct, and the correction goes further than the issue asked.
Measuring five designs in this run shows the **direction** is design-dependent
too, not only the magnitude:

| Design | Correct SE | Buggy SE | Error |
|---|---|---|---|
| `gss_2024` bootstrap R=50 (issue #197) | 0.428678 | 0.279983 | 35% too small |
| JKn, 40 rows | 0.177500 | 0.163300 | 8% too small |
| JKn, 32 rows | 0.176645 | 0.183755 | 4% too large |
| BRR, 32 rows | 0.184410 | 0.201942 | 10% too large |
| JK1, no clustering | 0.190136 | 0.190269 | 0.1% too large |

Same replicate type, different draw, opposite direction. A weighted mean is
invariant to a constant rescaling of its weights, so the defect is not a
shrinkage: it depends on how the replication-factor pattern correlates with
the base weights. Where base weights barely vary the error nearly vanishes;
where they vary a lot it is large in either direction.

This retires the claim, carried in `comprehension.md` §Gotchas and in the issue
text, that the defect is "wrong in the direction that hides it". That is true of
the `gss_2024` case, not of the defect. Two consequences, both applied: the
narrative states the design-dependence, and no test row may assert a direction
or a ratio — only parity against the oracle.

**Issue 10: `error-messages.md` row 89 was cited but not traced**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec cites rows 62 and 89 as precedent; `comprehension.md` recorded only
row 62. Row 89 does exist and the claim is correct. Added to
`comprehension.md` §Reference mapping.

**Issue 11: the Fay `rho` gap rested on an unverified claim**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§IX defers a known defect on the strength of a claim about `x$rho` that
`comprehension.md` never recorded.

Resolution: measured in this run.
`survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)` stores `rho = 0.3`
and `"rho" %in% names(design)` is `TRUE`; `as.svrepdesign(type = "BRR")` stores
`rho = 0`. `survey_replicate` has no `rho` key. The gap stands, now measured
rather than asserted, and Lens 5's Issue 6 explains why it is Fay-only.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| ADVISORY | 8 |

**Total issues:** 11

**Assessment:** The statistical content is sound. The fold-in is the correct
inverse of the factor form for every replicate type, not only the three
measured, and dropping the FPC on export is the only choice consistent with
round-trip parity — a conclusion `survey`'s own `as.svrepdesign()` reaches for
the same kind of case, with the same warn-and-drop. All three REQUIRED issues
are traceability failures rather than errors of method: claims that were
measured but not recorded, or a magnitude carried over from the issue report
without reconciliation. One of them, the 35% figure, turned out to conceal a
substantive error — the defect's direction is design-dependent, so the
"fails in the hiding direction" framing is wrong as a general claim and has
been retired from all four artifacts.

**Verdict: PASS** after the UNAMBIGUOUS batch below is applied. No issue
requires a user decision.
