# Methods Review — as-svydesign-bridge — Pass 1 (2026-09-08)

Six lenses ran in parallel against `spec.md` and `test-spec.md`. Lens 6 ran
because `comprehension.md` exists.

Every numerical finding below was re-run by the orchestrator before it was
accepted. Two lenses found the same two defects independently, and the
orchestrator's own sweep found a third that neither reported.

## Verdict

**FAIL — 4 BLOCKING, 4 REQUIRED, 4 SUGGESTION.**

Route to Stage 2r. None of the four settled decisions D-1 to D-4 is disturbed.
Two new decisions, D-5 and D-6, were taken by the user during this pass and are
recorded in `decisions.md`.

## New measurement this pass

`measurements.md` §"Methods review sweep — 2026-09-08" holds it. The headline:
at surveycore's own defaults, with the FPC dropped per D-1, six of nine
replicate types convert and agree with surveycore to 1e-17. Three do not.

| `type` | Result |
|---|---|
| JK1, BRR, bootstrap, ACS, successive-difference, other | convert, agree exactly |
| JK2 | converts, SE high by `sqrt(R/(R-1))` = 1.069045 |
| JKn at default `rscales` | does not convert: `Must provide rscales for combined JKn weights` |
| Fay | does not convert: `With type='Fay' you must supply the correct rho` |

The root cause is not the bridge. It is three scale defaults in
`as_survey_replicate()`. See `decisions.md` D-5.

## BLOCKING

### B-1 — "All nine replicate types convert" is false (Lens 1, Lens 2)

Sites: `spec.md:239`, `spec.md:266`, `spec.md:559-560` (roxygen §1),
`spec.md:684-686` (NEWS entry).

Measured: six convert and agree, JK2 converts and disagrees, JKn and Fay do not
convert. Correct every one of the four sites to the measured truth. Do not
promise a count the code cannot deliver.

### B-2 — The CN-2 warning promises SE equality it cannot deliver (Lens 1, Lens 2)

Site: `spec.md:380-388` (warning body) and `spec.md:393` (register row). The
bullet reads "The converted design reports the same standard errors as this
design does."

For a JK2 design that bullet is false by 6.9%. Worse: before this change an
FPC-bearing JK2 design errored outright, so D-1 turns a hard failure into a
silent wrong answer with a reassuring message attached. Remove the
unconditional promise. State the agreement where it holds and name the
exception.

### B-3 — The zero-weight edge case is unreachable (Lens 3)

Sites: `spec.md:189`; `test-spec.md:89-93` (Fixture 3), `test-spec.md:227`
(row B-8), `test-spec.md:304` (edge-case table).

`.validate_weights()` rejects any non-positive weight at construction with
`surveycore_error_weights_nonpositive`. Verified on `as_survey()` and
`as_survey_nonprob()`. No design object can hold a zero-weight row, so
Fixture 3 cannot be built and row B-8 would fail at setup.

Correct `spec.md:189` to "Not reachable", with the validator cited. Drop
Fixture 3, row B-8 and the edge-case line.

### B-4 — `as_svydesign()` drops a filtered design's domain restriction (Lens 4)

Neither artifact mentions domain state. Measured by the lens and re-measured by
the orchestrator on an independent fixture:

| Call on a design filtered to `y1 > 50` | mean | SE |
|---|--:|--:|
| surveycore `get_means()` on the filtered design | 58.176655 | 0.725342 |
| `survey::svymean()` on `as_svydesign()`'s output | 50.761561 | 0.614837 |
| the same after subsetting the output on the domain column | 58.176655 | 0.725342 |

The domain column crosses as inert data and is never installed as the converted
object's own restriction, so the object answers for the whole sample. The point
estimate is wrong, not only the standard error. Pre-existing, all four routes.

Resolved by D-6: document it and file a follow-up issue. No code change.

## REQUIRED

### R-1 — `R - 1` is false under replicate-column collinearity (Lens 3, Lens 5)

Site: `spec.md:610-612` (roxygen §3).

`survey::degf.svyrep.design` computes `qr(weights(design, "analysis"), tol =
1e-5)$rank - 1`. Verified: eight replicate columns with one an exact duplicate
give `degf()` 6, not 7, at qr rank 7. Qualify the sentence with the rank, and
keep `R - 1` as the full-rank case.

### R-2 — Roxygen §1 says the two FPC mechanisms "correct for different things" (Lens 5)

Site: `spec.md:564-566`.

Both correct for the same phenomenon, sampling a non-negligible fraction of a
finite population without replacement, at different levels of aggregation.
`?svrepdesign` uses the same term, "finite population correction", for both.
The second half of the sentence, "a multiplier on an already-formed resampling
variance", holds only for a constant FPC: survey applies
`rscales <- rscales * fpc` before the sum, so a varying FPC changes the
weighted sum itself. Reword to describe the granularity difference.

### R-3 — A custom `scale` is silently ignored for four types (Lens 2)

`survey::svrepdesign()` overrides `scale` and `rscales` unconditionally for BRR,
ACS, successive-difference and JK2. Agreement holds at surveycore's own
type-specific defaults, which happen to match survey's hardcoded values for
BRR, ACS and successive-difference, and not for JK2. A caller who supplies a
non-default `scale` on any of the four gets a converted SE that differs by a
fixed ratio. Measured by the lens: BRR at `scale = 0.5` gives ratio 2.0.

State the caveat wherever the artifacts promise agreement.

### R-4 — Only JKn carries a numerical SE row (Lens 2, Lens 3)

Site: `test-spec.md:180-207`. Rows A-4 and A-5 assert an absence of error text
and never a number, so both B-1 and R-3 would ship green. Add numerical rows
covering at least JK2 and one agreeing type other than JKn, and rows pinning
the two non-conversions.

## SUGGESTION

### S-1 — The round-trip roxygen claim is wider than the test (Lens 6)

`spec.md:588-595` states the rebuilt design "no longer warns about the
approximation". `test-spec.md` row D-1 asserts only the class change. Add a row
that rebuilds and asserts no `surveycore_warning_nonprob_srs_fallback` fires.

### S-2 — §Out does not carry G8's rationale (Lens 6)

`spec.md:57-59` says the reverse direction does not change, without saying why
D-1 needs no inbound change: `.from_svydesign_replicate()` already sets
`fpc = NULL` unconditionally and `svrepdesign.default` records no `rval$fpc`.
One sentence.

### S-3 — "Files touched — eight" heads a nine-row table (Lens 6)

`spec.md:82`. Make the header agree with the table.

### S-4 — The default `confint()` claim has no test (Lens 3)

`spec.md:614-618` states a default `confint()` on the converted object matches
surveycore's interval. Lens 3 verified it true on both shapes to machine
precision. Unlike the two df figures, this is surveycore behaviour and not the
oracle's arithmetic. One row per shape, reusing the B-5 and B-6 fixtures.

## Verified and closed with no finding

- The dispatch table is mutually exclusive and exhaustive. The four design
  classes are siblings under `survey_base` with no diamond inheritance
  (Lens 1).
- The plain nonprob route computes what `.calibrated_mean_cell()` computes.
  Lens 1 measured exact agreement, SE 0.5496033 both ways.
- Passing no `fpc` makes survey's whole FPC block unreachable. Lens 6 scanned
  every function in the `survey` namespace for `fpctype` and confirmed the six
  other hits are unreachable from this call route, because `svrepdesign`
  dispatches on `data` and no `svrepdesign.data.frame` method exists.
- `fpctype` is dead on both sides after D-1, so `"fraction"` against
  `"correction"` cannot diverge (Lens 1).
- The SE-agreement promise does not depend on the replicate columns holding
  finished weights rather than replication factors. Lens 2 built a
  factor-shaped design and measured agreement at 0.178527505 both ways. The
  `combined.weights` out-of-scope statement is accurate.
- `confint.svystat` and `confint.svrepstat` are identical and both default to
  `df = Inf`. `svyglm()` and `svyttest()` do read `degf()` themselves. The
  `get_*()` functions never call `.degf()` for a nonprob design (Lens 3).
- Converting a calibrated nonprob sample through
  `svydesign(ids = ~1, weights = ...)` matches established practice, and CN-3's
  stated deficiency matches what `NonProbEst`'s own documentation states for
  the analytic route (Lens 5, R Journal RJ-2020-015).
- Warn-and-drop for an argument the target call cannot honour matches survey's
  own house convention for `rho` and for `scale`/`rscales` (Lens 5).
- All nine `comprehension.md` gotchas are addressed or consciously retired.
  All five open questions are resolved (Lens 6).
- `@groups` is never read by `as_svydesign()`, consistent with the RESERVED
  rule (Lens 4).

## Gaps the lenses could not close

- `srvyr`'s own convention for an argument it cannot honour. The installed
  package ships only a lazy-load binary database, so Lens 5 could not grep it.
  The `survey`-side precedent is established, so the conclusion does not rest
  on this.
- `nonprobsvy` and `NonProbEst` PDF manuals would not decode. Lens 5 used the
  CRAN README and the R Journal HTML rendering instead.
