# Decisions — as-svydesign-domain
> Citations of `plans/*-as-svydesign-domain.md` below carry `[no such file]`: those four files were moved into `archive/as-svydesign-domain/` at archive time (2026-09-11), so the path they name no longer exists. The documents are beside this one.

Append-only. Every decision names the measurement that forced it. Measurements
live in `findings-preflight.md` in this directory.

## D1 — Restrict with `x[r, ]`, not `subset()` — SETTLED 2026-09-09

**Raised by:** preflight measurement, before Stage 1 drafting.

**Question:** Issue #245 §Suggested fix names `survey::subset.survey.design`
and its replicate counterpart. Should the implementation call `subset()`?

**Decision:** No. Use the `[` operator with a logical row vector.

**Why:** all three `survey` subset methods end with `x$call <- sys.call(-1)`,
which overwrites the stored call. `.as_svydesign_taylor()` builds that call
deliberately with `bquote()` so `from_svydesign()` can read the design
variables back out of it, and every read there is wrapped in a `tryCatch` that
returns `NULL` on failure. Measured: a round trip through `subset()` loses
`ids` and `strata` silently, with no error, and the confidence interval shifts
from 56.8-59.6 to 56.9-59.5. The same round trip through `[` keeps every
design variable. See `findings-preflight.md` §F1.

**Consequence:** the implementation carries `r & !is.na(r)` itself, which
`subset()` would have done. Cost is one expression. See §F6.

## D2 — Read the twophase domain vector off the converted object — SETTLED 2026-09-09

**Raised by:** preflight measurement.

**Question:** which vector indexes the twophase route?

**Decision:** the domain column read from `sv$phase1$sample$variables`, not the
one in `x@data`.

**Why:** `@data` holds one row per phase-1 row, 60 in the measured design. The
converted object's phase-1 sample holds only the phase-2 rows, 29. Indexing
with the `@data`-side vector raises an unclassed
`logical subscript too long (60, should be 29)`. The column does reach the
phase-1 sample variables, so nothing extra has to be carried across. The other
four routes take the `@data`-side vector unchanged. See §F2.

## D3 — The twophase route gets its own oracle; the weighting gap is issue #261 — SETTLED 2026-09-09

**Raised by:** preflight measurement. Asked of the user, who chose this option.

**Question:** issue #245 §Verification asks that a filtered twophase design
convert to an object whose `survey::svymean()` matches surveycore's
`get_means()`. Measured, it does not: 58.067 against 58.458.

**Decision:** the twophase route's criterion becomes two measurable claims. The
restricted object equals what a caller gets by restricting the converted object
by hand. The unfiltered gap does not move. The weighting gap itself is filed as
issue #261 and cited from `spec.md`.

**Why:** the gap is pre-existing and independent of the domain. The identical
gap sits on the unfiltered design, 48.9 against 49.203. Reproduced by hand:
`get_means()` weights by the phase-1 weight column and survey's twophase object
weights by `1 / design$prob`. Nothing inside this issue's write surface closes
it. See §F3.

## D4 — Keep the domain column in the converted object — SETTLED 2026-09-09

**Raised by:** issue #245 §Scope, open question 1. Asked of the user, who chose
this option.

**Question:** once the domain is applied, is `..surveycore_domain..` dropped
from the converted object's variables?

**Decision:** it stays, now all-`TRUE`.

**Why:** round trips through `from_svydesign()` keep working with no change,
and no route has to decide when removal is safe — the twophase route would have
had to drop it from two places. The cost is that a `survey` user can see an
internal column and read it as data. The roxygen section covers that.

## D5 — An empty domain restricts and stays silent — SETTLED 2026-09-09

**Raised by:** preflight measurement. Asked of the user, who chose this option.

**Question:** a filter matching nothing keeps every row with 0 marked. What
does `as_svydesign()` do?

**Decision:** restrict anyway, return the zero-row object, raise nothing.
`survey` then answers `mean 0, SE 0`. `test-spec.md` pins the zero-row shape.

**Why:** `surveytidy::filter()` already warns at filter time that the domain is
empty and that variance estimation will fail. A second warning on conversion
repeats a warning the user has seen. Pinning the shape in a test records the
behaviour as chosen rather than accidental. See §F5.

## D6 — `NA` in the domain column resolves to FALSE — SETTLED 2026-09-09

**Raised by:** preflight measurement.

**Question:** can the domain column hold `NA`, and if so what does it mean?

**Decision:** carry `r & !is.na(r)`, which treats `NA` as "not in the domain".

**Why:** measured, `surveytidy::filter()` never leaves `NA` in the column — on
a design whose `y1` holds three `NA` values the column comes back with
`anyNA()` FALSE. That closes the question for every column surveytidy writes,
and not for one written by hand into `@data`, which nothing forbids. The
expression costs nothing and matches what `survey` does. See §F6.

## D7 — The restriction is silent for an ordinary domain too — SETTLED 2026-09-09

**Raised by:** spec review Pass 1, finding B-1 (Lens 6, API coherence). Asked of
the user, who chose this option.

**Question:** D5 settled silence for the empty domain, on the grounds that
`surveytidy::filter()` has already warned. Nothing warns for an ordinary partial
domain. `CLAUDE.md` says removing rows warns loudly. Does the conversion signal
that it returned fewer rows than the design it was called on?

**Decision:** No. The conversion stays silent for every domain, ordinary and
empty. The behaviour change is carried by
`changelog/fix-as-svydesign-domain.md`, prominently, as a change to what an
exported function returns.

**Why:** the conversion is now doing the correct thing. A warning on correct
behaviour teaches users to ignore the warning. What a user needs is to learn
once, at upgrade time, that the output changed, and a changelog entry is where
they meet that. The rejected alternative, `cli::cli_inform()` on a non-trivial
restriction, also carries a cost the lens did not price: it fires on every
filtered conversion including inside `as_tbl_svy()`, `cli_inform()` output is
not suppressible with `suppressWarnings()`, and roughly 30 new test blocks plus
the file's existing conversion blocks would all have to tolerate it.

**What this decision does not cover:** the three documentation gaps finding R-9
raised. Those are resolved on their own terms and not by this decision. Silence
at the call site is only defensible if the documentation is clear, so R-9's
three sentences are a condition of this decision and not an optional extra.

## D8 — The two-phase route applies the domain by zero-weighting — SETTLED 2026-09-09

**Raised by:** spec review Pass 1, finding B-2. Orchestrator measurement,
`findings-edge-cases.md` §F8. No lens found it.

**Question:** the drafted spec said every route returns an object carrying only
the marked rows. Does the two-phase route?

**Decision:** No, and the spec is corrected rather than the behaviour.
`[.twophase` sets the excluded rows' probability to `Inf` and keeps every row.
§Scope and the route matrix say so, and test row B-3 asserts the count of finite
probabilities rather than the row count.

**Why:** measured, with 12 of 29 phase-2 rows marked, the restricted object
keeps 29 rows, 17 of them with infinite probability, and `svymean()` answers
58.06658 — the correct domain estimate. `subset()` behaves identically, so this
is a property of the two-phase design and not of the operator D1 chose. Forcing
row removal would diverge from what `survey` itself does, for an estimate that
is already right.

## D9 — Coerce the marker column with `as.logical()` before masking — SETTLED 2026-09-09

**Raised by:** spec review Pass 1, finding B-3. Lens 4 and orchestrator
measurement `findings-edge-cases.md` §F10, independently, agreeing.

**Question:** D6 chose `r & !is.na(r)` as the row mask, and the spec called that
expression the whole coercion. Is it?

**Decision:** No. Read `r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])` first,
then mask with `r & !is.na(r)`. This supersedes D6's expression and keeps D6's
meaning: `NA` is outside the domain.

**Why:** measured, `&` alone handles logical, integer and double, and fails on
the two remaining reachable types. A character column raises an unclassed base
error out of `as_svydesign()`, contradicting the helper's "raises no condition"
contract. A factor column warns, yields an all-`NA` mask, and builds a 200-row
object whose probability vector is neither finite nor infinite; estimating on it
dies inside `survey` with `invalid 'type' (list) of argument`. `as.logical()` is
correct on all five types, turns an unrelated factor into an empty domain rather
than a corrupt object, and needs no new error class, so §Out holds. The state is
reachable: nothing constrains the column's type and the package's own suite
writes a non-logical marker at `test-analysis-quantiles.R:460`.

## D10 — The helper is the third reader of the marker column, and says so — SETTLED 2026-09-09

**Raised by:** spec review Pass 1, finding R-1 (Lens 1, DRY).

**Question:** `.apply_domain()` and `.print_domain_info()` already read
`SURVEYCORE_DOMAIN_COL`. Should the conversion reuse one of them?

**Decision:** No. The helper stays separate, because it takes a bare frame and a
`survey`-package object rather than an S7 design, so it cannot call
`.apply_domain(design)` as that function is typed. Its contract names both
existing readers, says why neither is reused, and cites issue #262.

**Why:** consolidating all three reaches `R/analysis-helpers.R` and
`R/methods-print.R`, both outside this write surface, and would change behaviour
the analysis suite pins today. The divergence is real and now has an owner:
`.apply_domain()` returns the column raw, and the orchestrator measured that
eleven call sites index a data frame with it, so five grouped `get_*()`
functions silently report the wrong group on an integer column. That is filed as
**issue #262** with the same `as.logical()` fix D9 adopts here. Recording the
divergence and pointing at #262 is the resolution; silence about two existing
readers was the finding.

## D11 — The helper takes one argument and derives the frame itself — SETTLED 2026-09-09

**Raised by:** spec review Pass 1, finding S-1 (Lens 5), reinforced by B-2.

**Question:** should the helper take the frame as a second argument, as drafted,
or derive it from the converted object?

**Decision:** one argument. The helper branches internally on the two-phase
class to pick the frame.

**Why:** the correct frame is a deterministic function of the converted object's
class in all three cases, and `from_svydesign()` already proves the data is
recoverable — it reads `x$variables` at `R/methods-conversion.R:638` and `:736`
to rebuild `@data`. A second argument asks each call site to supply what the
object already carries, and D2 records the one time that went wrong: an
unclassed `logical subscript too long (60, should be 29)`. D8 settles that the
two-phase route needs class-specific handling regardless, so the branch has to
exist somewhere; putting it inside the helper removes the argument that can be
passed wrongly instead of documenting how to pass it rightly.

## D12 — The two-phase round trip recovers the domain, and the spec says so — SETTLED 2026-09-09

**Raised by:** the orchestrator, closing the one place delta pass A declined to
judge. Measurement in `findings-edge-cases.md` §F13.

**Question:** the `from_svydesign()` contract and §Documentation contract item 8
both described the round trip in Taylor terms — an all-`TRUE` marker travels
back, the row count is the new total, the original N is unrecoverable, the print
line reads `Domain: n of n rows`. Does any of that hold for the two-phase route?

**Decision:** none of it. All four claims are scoped to the four routes that
remove rows, and the two-phase behaviour is stated beside them. A test row F-6
pins it.

**Why:** `from_svydesign()` dispatches on the two-phase class at
`R/methods-conversion.R:614`, so that shape does make the round trip. Because
D8's restriction removes no row, there is nothing for the round trip to lose.
Measured: the restricted object holds 29 phase-1 sample rows with 12 `TRUE`, and
the rebuilt design holds 60 rows with 28 `TRUE`, printing
`Domain: 12 of 29 Phase 2 rows`. The original N is recoverable, the row count is
not the new total, and the print line names two different numbers.

**The pattern this closes.** F13 is the fourth consequence of F8 to surface,
after the scope claim, the empty-domain outcome and the all-`TRUE` marker claim.
Every claim in this spec written from the Taylor route has needed a two-phase
qualifier. A later editor adding a claim about what the converted object carries
should check the two-phase route before writing it, not after.

## D13 — Row A-4 moves to PR 1, because PR 1 changes that route — SETTLED 2026-09-10

**Question:** PR 1 was scoped as "the helper and the Taylor route". Its rows
test only the Taylor route. Is that the whole footprint of the merge?

**Decision:** no, and A-4 moves from PR 3 to PR 1 to match. PR 1's scope line
now discloses the second route.

**Why:** `as_svydesign()` dispatches a `survey_nonprob` design that names no
replicate weights into `.as_svydesign_taylor()`, at
`R/methods-conversion.R:169` and in `spec.md` §Route matrix row 5. That is the
function PR 1 edits, so merging PR 1 changes what two shapes return. With A-4
in PR 3, `develop` would carry an untested behaviour change on the second shape
for the whole of PR 2. A-4 is that shape's parity row and it captures the SRS
warning off the call, so moving it makes PR 1 assert both the estimate and the
warning on every route it touches. G-2's stricter claim — exactly once, and
nothing else — stays in PR 3 with the rest of that shape's rows.

Raised by the Dependency Ordering lens, plan review pass 1.

## D14 — Add test-spec row G-3 for the FPC warning on a filtered design — SETTLED 2026-09-10

**Question:** `spec.md` §`as_svydesign(x)` → Warnings says
`surveycore_warning_replicate_fpc_dropped` is "unchanged in every respect" on
the replicate route. PR 3 puts the restriction inside
`.as_svydesign_replicate()`, the function that fires it. No test-spec row put a
filtered FPC-bearing design through that path: C-2 and G-1b both name a
replicate design carrying **no** FPC, because G-1b needs
`expect_no_condition()` and an FPC-bearing design would break it. Close the gap
or accept it?

**Decision:** close it. `test-spec.md` gains row G-3 — a filtered replicate
design carrying an FPC column raises the warning exactly once and nothing else
— and PR 3 carries it, at 11 rows and 8 criteria, both inside the bound. Both
copies of the test-spec were amended, the run copy and
`plans/test-spec-as-svydesign-domain.md` [no such file].

**Why:** the arc makes an explicit contract claim about that warning, on the
one route it edits, and scheduled nothing that checks it. G-2 already sets the
precedent for the other warning on the arc, asserting it "fires exactly once,
and no other condition fires" on a filtered design. The asymmetry had no
defence beyond the accident that G-1b needed an FPC-free fixture.

**What lowers the risk, and why the row still earns its place.** Measured in
source: the warning fires at `R/methods-conversion.R:347-368` and
`survey::svrepdesign()` — the call whose value the restriction wraps — is the
last expression of the function at line 370. The warning therefore precedes the
restriction structurally, and no mechanism doubles or suppresses it. The row
costs one test block and pins that ordering instead of leaving it to a reading
of the source.

**Cost of the alternative.** Accepting the gap would have left a spec contract
claim unscheduled, which is the failure mode the Spec Coverage lens exists to
catch. Sending the run back to pipeline-spec would have cost a full phase for
one row.

Raised by the Spec Coverage lens, plan review pass 1. Amending a SPEC_READY
artifact was the user's call, taken 2026-09-10.

---

## HOLD — builder, PR 1 — 2026-09-10 18:05

**Where**: PR 1 (`fix/as-svydesign-domain-taylor`); test-spec row A-4's SE
clause; acceptance criterion 1's non-probability clause.

**What**: A-4 requires `survey::svymean()` on the converted object to agree
with `get_means()` on the filtered design to SE 1e-8, on a `survey_nonprob`
design that names no replicate weights. That agreement does not hold, and the
cause sits outside this PR's write surface.

**Measured** (orchestrator's independent run, a 20-row domain on the 40-row
`make_nonprob("plain")` frame; the builder measured the same identity on a
different 20-row split):

| Quantity | Value |
|---|--:|
| rows converted | 20 of 40 |
| point estimate, `get_means()` vs `svymean()` | agree, diff 0.000e+00 |
| SE, `get_means()` | 1.838668300 |
| SE, `svymean()` on the converted object | 1.814942554 |
| ratio observed | 1.013072450 |
| `sqrt((n_d/(n_d-1)) / (n/(n-1)))` | 1.013072450 |
| `svymean()` SE, nonprob route vs Taylor route on the same frame | diff 0.000e+00 |

**Cause**: `.calibrated_mean_cell()` at `R/analysis-means-helpers.R:321` writes
`(n_d / (n_d - 1L))`, taking the finite correction from the domain size. The
function's own doc comment at line 281 states the estimator as
`Var(ybar_w) = n/(n-1) * sum(z_i^2)` and claims it matches
`survey::svydesign(ids = ~1)`. `survey`'s `[` keeps each retained row's
recorded stratum sample size, so `svymean()` takes the correction from the full
sample, and so does surveycore's own `.taylor_mean_cell()`. The code therefore
contradicts its documented intent on a domain, and agrees with it only on the
full sample — which is why the pre-existing unfiltered block passes at 1e-8.

**Why the restriction is not implicated**: the point estimate agrees exactly;
`survey`'s SE is byte-identical on the nonprob and the Taylor conversion of the
same frame and domain; and `subset()` would give the same numbers, because
`subset.survey.design2` calls `x[r, ]`. D1's choice of operator is not the
cause. The defect is pre-existing and this change only makes it observable —
before it, a filtered nonprob design converted to the full sample, so no domain
SE comparison was possible.

**Why the builder could not decide**: the fix edits
`R/analysis-means-helpers.R`, outside the closed write surface, and changes a
number the analysis suite pins today. Narrowing A-4 instead amends an artifact
frozen at SPEC_READY, which is the user's call.

**Options**:

1. Narrow A-4's SE clause to the ratio identity, and file an issue against
   `.calibrated_mean_cell()`. PR 1 ships as built. Matches the arc's own
   precedent for a pre-existing estimator gap: D3 deferred the two-phase
   weighting gap to issue #261, and the spec names issue #262 for
   `.apply_domain()`'s raw pass-through.
2. Widen the write surface and fix `.calibrated_mean_cell()` in this PR.
3. Drop the non-probability shape from A-4's SE assertion, point estimate only.

**What I need**: which of the three, and if option 1, confirmation that
amending A-4 is authorised.

## Resolution — 2026-09-10 18:40

**Signal resolved**: HOLD — builder, PR 1 — 2026-09-10 18:05
**Decision**: Option 2 — fix the finite correction in `.calibrated_mean_cell()`.
It ships as its own PR, landing BEFORE PR 1.
**Authorized by**: user
**Resume from state**: PLAN_READY

### D15 — the non-probability domain SE takes its correction from the full sample

**SETTLED.** `.calibrated_mean_cell()` at `R/analysis-means-helpers.R:321` took
the finite correction from the domain size. It now takes it from the full
sample, `nrow(data)`.

**Three independent grounds, in the order they were established.**

1. **Numerical parity with the oracle.** The full-sample factor reproduces
   `survey::svymean()` on the converted object exactly, at every domain size
   measured — 5, 13, 20, 31, 39 and 40 of 40 rows, absolute difference at most
   4.44e-16. The domain factor does not, and its error grows as the domain
   shrinks: 1.3% at 20 of 40, 10.4% at 5 of 40. At the full sample the two
   agree exactly, which is why every pre-existing unfiltered test passed.

2. **The author's stated rule.** Thomas Lumley, "Subsets and subpopulations in
   survey inference" (notstatschat, 2021-07-22), gives the variance as
   `V = sum_h n_h/(n_h - 1) * sum_i (Z_hi - Zbar_h)^2`, where `n_h` is "the
   number of clusters sampling in stratum h" — the count the design sampled,
   before any subpopulation restriction. On the package: "The `subset` method
   for surveys drops the records that are not in the subpopulation (saving
   memory) but keeps track of how many sampling units it has discarded, and the
   variance computations put the zeroes back in."

3. **survey's traced source.** `survey:::onestrat` computes
   `scale <- f * nPSU/(nPSU - 1)`, then pads: `if (nsubset < nPSU) x <-
   rbind(x, matrix(0, ncol = ncol(x), nrow = nPSU - nrow(x)))`. `nPSU` traces
   through `onestage` and `multistage` to `design$fpc$sampsize[, 1]`.
   `[.survey.design2` subsets that field by row and never recomputes it, so
   each retained row still carries the full sample's count. Measured on a
   40-row design with a 20-row domain: `svymean()` variance
   0.0508895266497642; `40/39 * sum(z^2)` gives the same to the last digit;
   `20/19 * sum(z^2)` gives 0.0522287247194949. `subset()` and `[` agree, and
   `fpc$sampsize` still reads `40 40 40 ...` after subsetting.

**Why the sum and the factor must use the same count.** Outside the domain
`z_i = 0`, and `sum_i w_i (y_i - ybar_d) = 0` over the domain rows, so
`Zbar = 0` over the full sample. `sum_i (z_i - Zbar)^2` therefore runs over all
`n` rows and equals `sum z_i^2` over the domain rows alone. The `n - n_d` zeros
contribute nothing to the sum but remain terms in it. Pairing a sum over `n`
terms with `n_d/(n_d - 1)` was the inconsistency.

**Why `nrow(data)` and not a recorded original N.** It makes the
non-probability path behave exactly like `.taylor_mean_cell()` under every
operation: `filter()` keeps all rows, so both read the full sample; `subset()`
removes rows, so both read the reduced sample. The builder's cross-check
measured that agreement, and D15 preserves it.

**Blast radius, measured.** Full suite on the fixed tree: FAIL 1, PASS 11655,
WARN 256, SKIP 4, against a baseline of FAIL 0, PASS 11606, WARN 256, SKIP 4.
The single failure is PR 1's own ratio-identity block at
`test-conversion.R:3181`, written to record the gap this decision closes. No
pre-existing test broke and no snapshot drifted — no test anywhere pinned a
filtered or grouped non-probability SE against `survey`, which is the coverage
gap that let the defect survive. The fix therefore lands with one test block to
rewrite, and that block is one this arc created.

**Consequence for the frozen artifacts: none.** Landing this before PR 1 makes
test-spec row A-4's "SE 1e-8" clause true as written. No frozen artifact is
amended and no tolerance is relaxed. This is why the fix ships first rather
than alongside.

### D16 — two findings recorded, neither fixed here

**`degf()` and the variance factor use different counts, by design.** `survey`
returns `degf() == 19` on the design whose variance factor is `40/39`. They are
distinct quantities. D15 changes only the variance factor, so any t-quantile
built on `n_d - 1` degrees of freedom is unaffected and stays correct.

**surveycore's Taylor path carries the same latent gap on `subset()`.**
`.build_cluster_matrices()` (`R/utils.R:1081-1097`) computes `sampsize` fresh
from the rows `@data` holds at call time, so it keeps no memory of a larger
original sample. Under `filter()`, which keeps every row, it matches `survey`.
Under `subset()`, which removes rows, it yields `n_d/(n_d - 1)` where `survey`
yields `n/(n - 1)`. The vendored `R/variance-taylor.R:41` reproduces survey's
expression faithfully — the divergence is upstream, in how `nPSU` is built, and
the `# nocov` at line 51 asserting `nsubset == nPSU` is consistent with it:
survey's zero-padding branch is unreachable here. Outside this arc's write
surface; needs its own issue and its own decision about whether surveycore's
`subset()` is meant to re-baseline the sample.

## HOLD — builder, PR 0 — 2026-09-10 14:30 (transcribed by the orchestrator)

The builder's write surface was closed to two files, so it recorded this HOLD
in `prs/pr-0-nonprob-domain-se-correction/implementation.md` and asked for it
to be transcribed here. Full body and measurements are in that file.

**What**: `.calibrated_mean_cell()` returns `se = NA_real_` for a one-row
domain, where `survey::svymean()` returns a finite `0`. Measured (seed 706,
100 rows, domain of row 1 only): means agree at 56.974548387242; surveycore
`se = NA`, `survey` `se = 0`.

`survey`'s `0` is exact rather than small. With one row `ybar` equals `y_1`, so
the single influence value `w_1 * (y_1 - ybar) / N_hat` is exactly zero and the
sum of squares is zero. Under the OLD domain factor the multiplier was `1/0`, so
a one-row domain had no computable variance at all and the early return was
forced. Under D15's full-sample factor the multiplier is finite, so the value
becomes computable — and it is `0`.

### D17 — a one-row calibrated domain keeps `NA_real_`. DEFERRED, not fixed.

**Decision**: keep the existing behaviour. Orchestrator's call, on scope
grounds, with the statistical argument below. Reversible on request.

**Why keep it.**

1. **It is out of PR 0's scope.** PR 0 fixes one term in a finite correction.
   The `n_d == 1L` early return is a different branch, pre-dates the defect, and
   is pinned by an existing block in `tests/testthat/test-analysis-means.R`
   named "get_means() calibrated single-row domain returns mean with NA se
   (covers n_d=1 path)". Changing it is a behavioural change to a deliberate
   contract, not a repair of D15's defect.
2. **`NA` is the more honest report.** One observation carries no information
   about spread. `survey`'s `0` is an artifact of the linearization, not a
   measurement, and a standard error of `0` tells a reader the estimate is
   certain. That is the wrong thing to publish.
3. **Nothing in this arc needs the parity.** `spec.md` §Edge cases says of the
   single-marked-row conversion: "Whatever `survey` raises when a caller later
   estimates on it belongs to `survey`." Test-spec row D-3 asserts only that the
   conversion returns one row and raises nothing. PR 0's own parity blocks run
   at domain sizes 50, 20, 10, 5 and 2 — none reaches the `n_d == 1L` branch.

**What it costs.** Exact parity with `survey` on this one cell, and a special
case that stays in the function. Both are visible and neither is load-bearing.

**If it is ever revisited**, it is a change to a pinned contract and wants its
own decision: whether a degenerate zero-variance cell reports `0`, `NA`, or `NA`
plus a typed warning. Option 3 in the builder's HOLD would add a warning class,
which needs a row in `plans/error-messages.md`.

**Resume**: PR 0 proceeds unchanged.

## Issue numbers for D15, D16 and D17

Filed 2026-09-10, after PR 0 was opened as **#263**.

| Decision | Disposition | Issue |
|---|---|---|
| D15 — the calibrated domain SE takes its correction from the full sample | FIXED in PR #263 | — |
| D16 — `subset()` on the Taylor path re-bases the same correction | DEFERRED | **#264** |
| D16 — `degf()` and the variance factor use different counts | No action; correct as it stands | — |
| D17 — a one-row calibrated domain reports `NA`, not `0` | DEFERRED | **#265** |

#264 records that its finding is traced from source and NOT measured end to
end, and names the measurement that would confirm it. It also carries the open
question of whether surveycore's `subset()` is meant to re-baseline the sample,
which decides whether the finding is a defect at all.

## Carry-forward into PR 2 — from the PR 1 review, 2026-09-10

PR 1's builder wrote four marker-column blocks beyond its task list, covering
rows the plan assigned to PR 2. The builder could not know: it never read
`test-spec.md` or the plan's row ledger. The plan anticipated the coupling and
says PR 2 "adds no production code; it pins marker-column behaviour PR 1
already delivers."

**The reviewer ruled it is not scope creep**, and the reasoning is worth
keeping. The blocks add no production code, they sit inside `spec.md`'s own
edge-case table, and they land in PR 1's own two files. The issue #165 failure
mode needs the later PR *locked out of the file* — there, PR 6 could not repair
a helper vocabulary because `helper-test-data.R` sat outside its write surface.
PR 2's write surface **is** `tests/testthat/test-conversion.R`, so PR 2 can
repair or extend anything PR 1 wrote. The coupling is therefore benign.

### What PR 2 must do differently from the plan as written

| Row | Disposition |
|---|---|
| D-2a, D-4, D-6, D-6a, D-6c | Satisfied by PR 1's blocks. PR 2 marks them satisfied and does NOT duplicate them |
| **D-6b** | **Only half covered — PR 2 must finish it** |
| D-3, D-5a, E-1, F-4, F-5 | PR 2's remaining original work |

**D-6b is the live gap.** PR 1's five-type loop asserts the row count and that
no condition fires, but never asserts `all(is.finite(sv$prob))`. That assertion
is the test-spec's named guard on the corrupt-probability path, and it is the
one that would catch the failure `spec.md` §D9 measured: a factor marker under
`&` alone yields an object whose probability vector is neither finite nor
infinite, and estimating on it dies inside `survey` with
`invalid 'type' (list) of argument`. Row count and silence both pass on that
corrupt object. Verified in source at the block "selects the same rows for
every marker column type" — its only assertions are `expect_no_condition()` and
`expect_identical(nrow(...), sum(mask))`.

So PR 2's row budget falls from 11 to 6 by content, but the plan's warning that
"row headroom is thin on PR 2" no longer binds: the headroom problem inverts.

### Also noted by the reviewer, and accepted

`develop` carries roxygen that contradicts the shipped behaviour until PR 5
lands. `R/methods-conversion.R`'s `@section A filtered design's domain:` still
tells the caller to subset the returned object by hand and says the converted
object answers for every row. Both claims are false from PR 1 onward. This is
the plan's deliberate ordering — documentation lands last, in PR 5 — and the
window is the length of this arc. Recorded so it is a known state and not a
discovery.

---

## PR 3 record — 2026-09-11

Branch `fix/as-svydesign-domain-replicate-nonprob`, cut from `develop` at
`67914a0`, two builder commits (`843b33e` fix, `8c86c5f` test), tree
`5819738`. Tester PASS, reviewer PASS, both on the first pass. BLOCK counts:
tester 0, reviewer 0.

**Pre-PR gate: SKIPPED — tree unchanged since audit.** The audit's `Tree:`
line equals `git rev-parse 'HEAD^{tree}'` on the branch, so the seven gates
the orchestrator ran (`logs/pr-3/`) already cover this exact tree. pkgdown ran
and was not skipped: the write surface touches `R/`.

Three reviewer notes, none a verdict item:

1. `implementation.md` says the test section adds 14 blocks. The file holds
   13. The PR body says 13.
2. The audit's row table omits the extra `filter()`-marked parity block the
   builder added beside A-2. It is a second block on the same row, not a gap.
3. The helper comment at `R/methods-conversion.R:37-43` names only
   `survey.design2`. See carry-forward item 1.

The covr summary line in `run-gates.sh` reported "changed R/ files: 2" — the
stale local `develop` ref again. Against `origin/develop` the PR changes one
`R/` file, and its one uncovered line (573) is a pre-existing `# nocov` branch.

## Carry-forward into PR 4 and PR 5 — from the PR 3 review, 2026-09-11

1. **PR 4 rewrites the helper comment** at `R/methods-conversion.R:37-43`. It
   now serves `survey.design2` and `svyrep.design`; after PR 4 it serves the
   two-phase class too. Name all three.
2. **PR 5's criterion 8 counts three call sites.** Two exist after PR 3
   (`:260` and `:427`). The count reaches three only after PR 4 lands, so PR 5
   cannot run before PR 4 merges.
3. **Do not copy PR 3's condition idiom onto the two-phase route.**
   `expect_no_warning(expect_warning(..., class = ))` works on the replicate
   and non-probability routes because each raises at most one typed warning.
   On the two-phase route `survey` emits untyped warnings of its own, so the
   outer expectation would fail on that noise. `test-spec.md` §G-1c gives the
   class-pattern technique and forbids `expect_no_condition()` there.
4. **`test_invariants()` for `as_survey_twophase()`.** The file carries no
   call for that constructor. PR 4 adds exactly one, in its first block.
5. **Small domains move the warning count.** Four PR 3 blocks pass
   `min_cell_n = 1L` to `get_means()` because their domains hold 20 to 29 rows.
   Without it the suite's warning total leaves 256. If PR 4's domain falls
   below 30 rows, pass the same argument.
6. **Fixtures PR 4 can reuse**: `make_filtered_taylor()`,
   `make_filtered_rep()`, `make_filtered_nonprob()` in `test-conversion.R`.
   PR 4 needs its own filtered two-phase fixture; `test-spec.md` §B-4 warns the
   file's two-phase builder names no phase-2 cluster identifier.
7. **Known untested state, not a gap PR 3 introduced.** `spec.md` says the
   stored call survives the restriction on every route; F-2 pins it on the
   Taylor route only. The filtered replicate round trip is untested. One block
   if a later reader wants it.

---

## PR 4 gate run — two memory-watchdog kills, no code defect — 2026-09-11

Branch `fix/as-svydesign-domain-twophase`, two builder commits (`7533c12`
fix, `0e15135` test), tree `d9d7a16`.

The first `run-gates.sh` call lost gate 4. The `R CMD INSTALL` child that
`R CMD build` runs to build vignettes died at 12:59:35 with a bare
`ERROR: package installation failed` and no R error above it, at the same
second the watchdog killed the harness task. Gate 5 was then skipped for want
of a tarball. The runner shell itself survived, ran pkgdown and covr, and
printed its summary at 13:10: gates 1, 2, 3, 6, 7 PASS; 4 FAIL; 5 skipped.

A second attempt at gates 4 and 5 built the tarball and then lost the check
at "Running testthat.R" (13:13), again a kill with no error text. A third
attempt launched `R CMD check --as-cran --no-manual` on that tarball as a
detached process outside the harness's task list and waited in the
foreground. It finished at 13:23: `Status: 2 NOTEs`, tests 237s OK. All seven
gates therefore PASS on tree `d9d7a16`; the corrected table is appended to
`logs/pr-4-summary.txt` and the check log is `logs/pr-4/gate-5-00check.log`.

Two operational facts for the next PR:

- The harness's low-memory watchdog kills its own background task tree, and
  `R CMD check`'s test phase is the step it hits. A process launched with
  PowerShell `Start-Process` is not in that tree and survived at 1.5 GB free.
- Free memory during the runs sat between 1.5 and 1.8 GB of 14.7 GB. No
  surveycore process was the consumer; the pressure is the host's.

## PR 4 tester BLOCK 1 of 3 — contract-miss — 2026-09-11 14:20

Three two-phase blocks (unfiltered, all-`FALSE` marker, all-`NA` marker)
wrapped the conversion in bare `suppressWarnings()` and asserted nothing about
conditions. The test-spec rows for the two empty-domain cases each name "no
surveycore condition from the conversion" as an assertion, and the unfiltered
row names "no condition beyond the untyped one from `survey`". The builder's
own report corroborated the observation: it said every two-phase call in the
section wraps in `suppressWarnings()` and named a collector in the final block
only. Routed to the same builder with the BLOCK body; asked for the collector
technique the final block already uses, factored into one helper if it now
appears four times. Tester BLOCK count for PR 4: 1. Reviewer BLOCK count: 0.

## PR 4 BLOCK 1 resolved — 2026-09-11 14:35

Builder commit `9daf70e` (test file only) added `collect_surveycore_classes()`
once at the top of the two-phase section; the unfiltered, all-`FALSE` and
all-`NA` blocks call it in place of `suppressWarnings()` and assert
`character(0L)`, and the final no-surveycore-condition block shares it. Tree
`4889ae0`. The full runner ran again on that tree in one detached call and all
seven gates passed (`logs/pr-4-fix/`): 11800 passing, 256 warnings, 96.25%.
Tester re-audit PASS. Pre-PR gate for this PR: audit `Tree:` equals the branch
tree, so it is skipped as tree-unchanged. Final counts for the ledger: tester
BLOCKs 1, reviewer BLOCKs pending the review.

## PR 4 review PASS — 2026-09-11, and carry-forward into PR 5

Reviewer PASS, 0 BLOCKs. Final ledger counts for PR 4: tester BLOCKs 1,
reviewer BLOCKs 0. The reviewer confirmed the structural state PR 5's
criterion 8 will read: one `.restrict_to_domain` definition (line 68), one
argument, three call sites (271, 438, 484: Taylor, replicate, two-phase), and
one copy each of the frame branch (69–73), the presence check (75) and the
mask (79–80), all inside the helper.

Seven items PR 5 must carry:

1. **The plan's roxygen line numbers are stale.** The `@section A filtered
   design's domain:` block is at 143–155, not 88–100; `@return` is at 98–105,
   not 43–50. Find both by tag, not by line.
2. **The section still documents the defect as intended.** It says the
   converted object represents the full stored sample and tells the caller to
   run `subset(converted, ..surveycore_domain..)`. Both sentences must go.
3. **Criterion 8's counts** are those above. `grep -rn restrict_to_domain R/`
   returns nothing outside `R/methods-conversion.R`. PR 5's diff must show no
   change under `tests/`.
4. **The helper comment covers half of documentation item 7.** It records the
   infinite-probability mechanism but not the estimator gap. PR 5 takes the gap
   from `spec.md` §Out (58.458 against 58.067 filtered; 48.9245 against
   49.20304 unfiltered) and cites no issue number in user-facing text.
5. **The two-phase round trip is the exception item 8 needs.** F-6 measured it:
   all 60 phase-1 rows and the mixed marker come back, so the rebuilt design
   prints two different counts where the other four routes print the same
   number twice.
6. **Still unpinned, carried from PR 3.** The stored call surviving the
   restriction is asserted on the Taylor route only. PR 5 adds no test block.
7. PR 5 is Tier optional in the plan. It runs the full cycle anyway: the
   roxygen rewrite is the user-facing statement of the whole arc.

## PR 4 merged — 2026-09-11

PR #269 squash-merged as `d5dcca4` at 2026-09-11T20:25Z, one CI cycle, all
seven checks green. The squash commit's tree equals the audited tree
`4889ae0`, so the gate run on that tree is `develop`'s state and no post-merge
suite run was needed. Remote branch deleted. Ledger row appended: 10 rows,
336 additions, tester BLOCKs 1, reviewer BLOCKs 0. Checkbox ticked in both
plan copies. `develop` now carries the restriction on all five shapes and
roxygen that still describes the old behaviour; PR 5 closes that window.

## PR 5 tester PASS, reviewer PASS — 2026-09-11

Branch `docs/as-svydesign-domain`, one commit `eb602c0`, tree `677a9f3`. All
seven gates passed in one detached runner call (`logs/pr-5/`). Tester BLOCKs
0, reviewer BLOCKs 0. Pre-PR gate skipped as tree-unchanged since audit.

One register question, ruled a note. The rewritten section says "Keep the
original design when you need the original row count", where `spec.md` item 8
says "a caller who needs the original N keeps the original design". The
reviewer ruled: `code-style.md`'s "never address the user" rule sits under
§Errors and warnings and governs `cli_abort()`/`cli_warn()` bullets, not
roxygen; the untouched `@section A non-probability design:` eleven lines above
already ends "Keep the original object when you need any of that", so a BLOCK
would split the voice of one help page for no change in fact. Accepted.

## Arc closeout notes for the archive — from the PR 5 review, 2026-09-11

Two facts a later reader cannot rebuild from the archived files:

1. **Deferred item with no GitHub issue.** `spec.md` says the restriction
   preserves the stored call on every route. Row F-2 pins it on the Taylor
   route only. The helper has one body and one `[` operator, so the property
   generalises by construction, but no block asserts it on the replicate,
   two-phase or either non-probability shape. The other four deferrals carry
   issues #246, #261, #262 and #265; this one does not. The orchestrator did
   not file an issue for it, because filing is an outward action nobody asked
   for. Raise it if the arc is reopened, or file it as one test-only issue.
2. **A rounding note.** The roxygen and the changelog state the unfiltered
   two-phase pair as 48.9245 against 49.20304. Those figures come from the B-2
   block's measurement in PR 4 and are one rounding step finer than any
   figure the planning documents logged (`spec.md` §Out gives 48.9 against
   49.203).

## PR 5 merged — arc complete — 2026-09-11

PR #270 squash-merged as `d889c86` at 2026-09-11T21:18Z, one CI cycle, all
seven checks green. The squash tree equals the audited tree `677a9f3`, so no
post-merge run was needed. Remote branch deleted. Ledger row appended: 58
additions, no rows, 0/0 BLOCKs. All five plan checkboxes are `[x]`.

Arc totals: issue #245 closed by PRs #266, #267, #268, #269 and #270, with
#263 as the prerequisite fix. Every PR merged in one CI cycle. One tester
BLOCK in the whole arc (PR 4), no reviewer BLOCK, no STOP, no HOLD after the
two PR 0/PR 1 HOLDs the planning phase recorded.
