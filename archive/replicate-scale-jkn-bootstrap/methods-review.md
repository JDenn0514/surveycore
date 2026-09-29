# Methodology Review: replicate-scale-jkn-bootstrap — Pass 1 (2026-09-23)

Protocol: `.claude/skills/spec-workflow/references/stage-2-methods-review.md`.
Six lenses, one Explore agent each, run in parallel. Lens 6 ran because
`comprehension.md` exists.

Trigger condition met: the spec changes a variance multiplier and asserts
standard errors and confidence bounds.

Both `spec.md` and `test-spec.md` went to every lens. Pipeline isolation
constrains the builder, the tester and the shipper; the planner and reviewer
roles read everything, and the tolerances and the oracle construction live in
the test-spec, which is where a methods error would hide.

Twelve issues after merging. Four raw findings merged into two.

---

## Verdict: NEEDS-DECISION

Per `.claude/skills/pipeline-shared/references/signals.md` §Review verdicts.
Both triggers fire:

- FAIL condition: five REQUIRED-UNAMBIGUOUS findings (issues 1, 4, 5, 6, 7).
- NEEDS-DECISION condition: seven JUDGMENT_CALL findings (issues 2, 3, 8, 9,
  10, 11, 12).

**No BLOCKING finding.** No lens found a mathematical error in the target
values. `JKn = 1` and `bootstrap = 1/(R-1)` both survive the review. Every
issue is about a condition the spec dropped, an epistemic status it flattened,
or a consequence it claims but does not test.

Resolution is BIG mode — twelve findings, over the eight-finding threshold in
`.claude/skills/spec-workflow/references/stage-4-resolve.md`.

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 8 |
| ADVISORY | 4 |

| Lens | Issues | Clean |
|---|---|---|
| 1 — Estimator specification | 2 | the invariance claim itself |
| 2 — Variance estimation | 3 | Q5 and Q6 fully clean |
| 3 — Degrees of freedom | 2 (both ADVISORY) | Q1, Q2, Q3, Q5 clean |
| 4 — Domain estimation | 1 (ADVISORY) | 4 of 5 questions clean |
| 5 — Established practice | 5 | — |
| 6 — Literature cross-check | 1 | 7 of 8 checks clean |

**Assessment.** The two target values are right and the spec's internal
reasoning is careful. Its failure mode is uniform: it states
`comprehension.md`'s conclusions without the conditions
`comprehension.md` attached to them. Stage 0 returned "confirmed with
conditions" and the spec reads as "confirmed". Four separate lenses found an
instance of that one pattern, each in a different place.

---

## Merges

| Raw findings | Merged into | Reason |
|---|---|---|
| Lens 1 issue 2 (REQUIRED) + Lens 3 issue 1 (ADVISORY) | Issue 5 | Same gap from two angles: E1 claims the infinite scale reaches the standard error, and no row tests the standard error. Higher severity kept. |
| Lens 2 issue 2 (REQUIRED) + Lens 5 issue 2 (REQUIRED) | Issue 1 | One root cause, two locations: the spec prose and the NEWS entry both present a convention alignment as a defect fix. |

Issues 4 and 6 (Lens 2) and issue 2 (Lens 6) are the same *shape* — a dropped
condition — but name different conditions, so they stay separate.

---

## Issue 1 — the bootstrap change is a convention alignment, not a defect fix, and neither the spec nor NEWS says so

Lenses: 2, 5. Severity: REQUIRED. Resolution: UNAMBIGUOUS.

The spec's own reasoning separates the two changes correctly. §"Why `1` is
right for JKn" grounds JKn in Wolter chapter 4 and then disclaims the
bootstrap: "Chapter 4 of Wolter covers the jackknife only ... it supports no
part of the bootstrap change. The bootstrap target rests on D5."

Two places flatten that back out.

- The spec never records that `1/R` is itself a standard, literature-backed
  convention — the population form, and the value `as_survey_nonprob()` keeps
  on D1 under Wu (2022) and Chen et al. (2021). Presented in one table with
  one "Changed: yes" column and one shared SE-ratio rule, the bootstrap row
  reads as well-founded as the JKn row. It is not: JKn's old default is wrong
  for every stratified design; the bootstrap's old default is a different
  legitimate divisor that `survey` does not happen to use.
- §NEWS and changelog sends the entry under the same `## Bug fixes` heading as
  #242, and the changelog file is named `fix-…`. None of the five required
  NEWS elements says the bootstrap move aligns a convention. A user who chose
  `1/R` deliberately reads "Bug fixes" and concludes their published numbers
  were wrong.

**Fix.** One sentence in the bootstrap paragraph recording that `1/R` is also
standard and that D5 picks `survey` as the oracle rather than proving
`1/(R-1)` more correct. One sixth element in the NEWS entry drawing the same
line: JKn corrects a formula error, the bootstrap matches `survey`'s
convention.

Source: `spec.md` §"Why `1` is right for JKn" against §NEWS and changelog;
`comprehension.md` F11; `plans/issue-cleanup.md` D1, D5.

---

## Issue 2 — `(n_h - 1)/n_h` is the with-replacement form, and the shipped roxygen states it unconditionally

Lens: 6. Severity: REQUIRED. Resolution: JUDGMENT CALL.

**The best finding of the pass.** The spec attributes the per-stratum factor
`(n_h - 1)/n_h` to Wolter eqs. 4.5.3 to 4.5.6. Those equations are written
`q_h / n_h`, where `q_h = (n_h - 1)(1 - n_h/N_h)` without replacement and
`q_h = (n_h - 1)` with replacement. The two forms coincide only for
with-replacement sampling, or when the sampling fraction is negligible.

The lens verified this in the chapter: the general `q_h/n_h` form at lines
1335 to 1386, and the `(n_h - 1)/n_h` restatement only at 1416 and 1537 to
1551, gated on "when the sampling fractions are negligible". The §4.6
eq. 4.6.4a citation genuinely is `(n_h - 1)/n_h`, so that half of the
citation is sound.

`comprehension.md` A3 records the condition. The spec drops it, and F-3
promotes the unconditional form into shipped user-facing roxygen.

**Why it matters.** A caller sampling PSUs without replacement at a
non-negligible fraction who follows F-3 literally builds `rscales` from
`(n_h - 1)/n_h`, omits `(1 - n_h/N_h)`, and understates the standard error —
the same defect this PR exists to close, moved onto a different population.
`comprehension.md` G8 already says the `@param rscales` text should say so,
because D12 refuses the `fpc` argument rather than documenting it, which
leaves folding the correction into `rscales` as the caller's only route.

Judgment call: whether the caveat goes on the exported help page or only in an
internal comment. The lens recommends the help page.

Source: `comprehension.md` §Assumptions A3 and §Gotchas G8; Wolter chapter
lines 1335-1386 against 1416 and 1537-1551; `spec.md` F-3.

---

## Issue 3 — the `mse` scope exclusion uses a jackknife-only theorem to license silence about the bootstrap

Lens: 2. Severity: REQUIRED. Resolution: JUDGMENT CALL.

`1/(R-1)` is the unbiased divisor of a sample variance taken about the
*sample mean* of the replicate estimates. surveycore defaults to
`mse = TRUE`, which centres on the full-sample estimate — a value the
replicates did not pay a degree of freedom to compute.

For the jackknife that is settled: Wolter's Theorem 4.5.3 gives `v_2`
(replicate-mean centred) and `v_4` (full-sample centred) one second-order
expectation. No equivalent is cited for the bootstrap anywhere in this run,
and `comprehension.md` F11 says so explicitly — Theorem 4.5.3 is the nearest
support "for the jackknife, not for the bootstrap".

The spec's §Out table nonetheless scopes `mse` out for the whole PR with one
sentence: "Both centrings sit in Wolter's set of four and share one
second-order expectation, so the default `scale` is decidable without settling
`mse`." Wolter's set of four is the stratified-jackknife family. Using it to
cover the bootstrap is a misapplication of a jackknife-specific rescue.

The behaviour is inherited, not new — `survey` also sets the bootstrap scale
without consulting `mse` — so this is a documentation and scoping defect, not
a numerical one. Note the asymmetry the documents never mention: a bootstrap
design at `mse = FALSE` gets the textbook-consistent pairing and has no open
question, and no oracle row exercises it.

Options the lens gave: document it and re-scope the citation to the jackknife
(recommended); the same plus an `mse = FALSE` bootstrap oracle row; or file a
follow-up issue asking whether the bootstrap scale should ever consult `mse`
and cite that issue in place of the theorem.

Source: `comprehension.md` F11 and F6; `spec.md` §Out `mse` row; `test-spec.md`
§2 rows 2.1 to 2.3, all at `mse = TRUE`.

---

## Issue 4 — the JKn justification drops two of F9's four conditions

Lens: 2. Severity: REQUIRED. Resolution: UNAMBIGUOUS.

The spec states flatly that surveycore reaches `v_4` under `mse = TRUE` and
`v_2` under `mse = FALSE`. `comprehension.md` F9 states the same conclusion
under four conditions: C1 one replicate per deleted PSU covering every PSU in
every stratum; C2 `rscales` carrying `q_h/n_h`; C3 replicate weights of
eq. 4.6.7's inflate-and-zero shape; C4 a stated centring.

The spec's E6 covers C2 and its `mse` mapping covers C4. C1 and C3 appear
nowhere. Stage 0's verdict was "confirmed with conditions"; the spec reads
"confirmed".

This compounds with G4: the package's own fixture fails C1 and C3, because no
replicate column drops a PSU and none is inflated by `n_h/(n_h - 1)`. A reader
of the spec alone could take the oracle rows for statistical validation of the
estimator, which G4 says they are not.

**Fix.** One sentence naming C1 and C3: correctness also needs the replicate
columns to form a genuine one-per-deleted-PSU family with weights built per
eq. 4.6.7, not only a correct `rscales`.

Source: `comprehension.md` F9 and G4; `spec.md` §"Why `1` is right for JKn".

---

## Issue 5 — `R = 1` bootstrap: the spec claims the infinite scale reaches the standard error, and nothing tests it

Lenses: 1, 3. Severity: REQUIRED. Resolution: UNAMBIGUOUS.

Spec E1 states the constructor stores `Inf`, raises no condition, and the
infinite scale reaches the standard error. Test row 1.3 asserts only the
stored property, through `expect_true(is.infinite(...))` and
`expect_equal(..., Inf)`. No row computes an estimate on such a design.

Two things follow.

- **The claim is conditional, and stated unconditionally.** With one replicate
  the sum has one term. If that replicate estimate equals the full-sample
  estimate the deviation is zero, and `Inf * 0` is `NaN` under IEEE 754, not
  `Inf`. A `NaN` standard error would reach `SE()`, the confidence bounds and
  the print methods with no condition raised, by E1's own blanket wording.
- **The case is new.** Lens 3 established that the old bootstrap default at
  `R = 1` was `1/R = 1`, finite. This PR introduces the infinite-scale
  construction, so it is not inherited behaviour.

The fixture jitters weights lognormally, so an exact-zero deviation is
improbable and the suite will not surface this. That is the reason to specify
it rather than leave it to the data.

**Fix.** Correct E1 to state both outcomes and which condition selects each.
Extend row 1.3, or add one row, to compute an estimate on an `R = 1` bootstrap
design and assert the standard error and both bounds — including a fixture
that forces the zero deviation, with `survey` asserted to do the same, since
D5 makes `survey` the authority for this input.

This does not reopen D-1. D-1 settles that the constructor stores `Inf` and
raises nothing. These findings are about what the spec claims downstream and
what the suite proves.

Source: `spec.md` E1 and quality gate 4; `test-spec.md` §1 row 1.3;
`decisions.md` D-1.

---

## Issue 6 — the point-estimate invariance row asserts a tolerance where exact equality is correct

Lens: 1. Severity: REQUIRED. Resolution: UNAMBIGUOUS.

`test-spec.md` says the two moves "leave the point estimate bit-for-bit
identical". Row 2.3, the row that proves it, asserts the two point estimates
are "identical (tolerance `1e-10`)".

The `1e-10` comes from the blanket tolerance table, which is calibrated for
cross-implementation comparison against `survey`, where different code paths
may legitimately agree only to a tolerance. Row 2.3 is not that: it builds two
surveycore designs on one frame differing only in `scale`, a value the point
estimator never reads. The same code runs on the same inputs, so the results
are bit-for-bit equal.

A regression that leaked `scale` into the point-estimate path by less than
`1e-10` would pass this row silently.

**Fix.** Assert exact equality in row 2.3's point-estimate clause. Leave the
standard-error ratio at `1e-8`.

Source: `test-spec.md` §"What this work changes", §2 row 2.3, §Tolerances.

---

## Issue 7 — the nine-row table marks Fay unchanged without saying it still diverges from `survey`

Lens: 5. Severity: REQUIRED. Resolution: UNAMBIGUOUS.

The default-scale table carries Before, After and Changed columns only. Fay
reads `1/R` → `1/R` → no.

`survey`'s Fay default is `1/(R(1 - rho)^2)`, per the per-type table in
`.claude/rules/testing-surveycore.md` and D2. surveycore's `1/R` coincides
with it only at `rho = 0`. So of the seven rows marked unchanged, six agree
with `survey` and one does not.

The spec names the gap in §Out and assigns it to #243. The table does not, and
the table is what a reader treats as the post-change status of all nine types.

**Fix.** Annotate the Fay row: unchanged, still divergent, owned by #243 and
D6. The same table is mirrored in `test-spec.md`, so both need it.

Source: `.claude/rules/testing-surveycore.md` §The oracle rule per-type table;
`plans/issue-cleanup.md` D2 and D6; `R/core-constructors.R:812`.

---

## Issue 8 — the `as_survey_nonprob()` divergence sentence gives the reason but not the size

Lens: 5. Severity: REQUIRED. Resolution: JUDGMENT CALL.

The one required sentence names `survey`'s value, names the sibling
constructor, and gives the reason. It never states the consequence: on the
same frame, `as_survey_nonprob()`'s bootstrap standard error is smaller than
`as_survey_replicate()`'s by `sqrt((R-1)/R)` — 2.6% at `R = 20`.

The spec computes that factor in behaviour rule 6 and `test-spec.md` row 3.2
asserts it between the two constructors, so nothing new needs deriving. A user
who builds both designs and sees a 2 to 3% gap gets the reason the code
differs and no number to check against.

Judgment call: whether one required sentence should carry four elements
instead of three.

Source: `spec.md` behaviour rule 6, §Documentation, quality gate 6;
`test-spec.md` §3 row 3.2.

---

## Issue 9 — the Wu (2022) and Chen et al. (2021) divisor attribution is unverified and becomes load-bearing

Lens: 5. Severity: ADVISORY. Resolution: JUDGMENT CALL.

`R/core-constructors.R:1308-1311` attributes `as_survey_nonprob()`'s `1/R` to
Wu (2022), *Survey Methodology* 48(2), and Chen, Li and Wu (2021), *JASA*
115(532). The attribution is pre-existing and the spec keeps it.

The new D1 sentence puts that citation in direct contrast with `survey`'s
`1/(R-1)` for the first time. A reader will infer the two papers specifically
endorse the population-form divisor for calibrated non-probability bootstrap
replicates. The lens could not verify that divisor-specific claim from the
papers; the journals and titles are plausible. Marked `[verify]`.

Cheap to check, and the new sentence raises the cost of it being wrong.

Source: `R/core-constructors.R:1269`, `1308-1311`, `1340-1345` `[verify]`.

---

## Issue 10 — the rescaling-bootstrap objection to a single hard-coded divisor is not on the record

Lens: 5. Severity: ADVISORY. Resolution: JUDGMENT CALL.

The lens raises Rao and Wu (1988), *JASA* 83(401), 231-241 `[verify]`: a
Rao-Wu rescaling bootstrap builds replicate weights on the assumption that the
variance estimator divides by `R`, so applying a uniform `1/(R-1)` to such
weights introduces a small known bias.

That is a defensible objection to `survey`'s single hard-coded default, and
the review brief asked for any such objection to be recorded without
reopening D5. It is not in either document.

The citation is unverified. `comprehension.md` F11 already records that Rao,
Wu and Yue (1992) is absent from Wolter chapter 4 and marks the surrounding
argument `[recalled]`.

Source: Rao and Wu (1988) `[verify]`; `comprehension.md` F11.

---

## Issue 11 — the JKn `rscales` and domain-stratum interaction has no §Out row

Lens: 4. Severity: ADVISORY. Resolution: JUDGMENT CALL.

A domain restriction can empty a stratum, so a JKn design's per-stratum
`rscales` may stop matching the strata realised in the domain's replicate
deviations.

Nothing in this work touches it. `rscales` storage, the variance engine and
`filter()`/`subset()` are all outside the write surface, and behaviour rule 7
correctly states that `scale` multiplies after the domain restriction and the
grouping split. The lens confirmed that against the source: `scale` is
computed once in the constructor from `type` and `n_rep`, before any domain
marking exists.

The gap is that §Out lists eight items each with an owner, and this one is
absent and unowned, while the spec discusses `rscales` and stratum semantics
in depth at F-3, E5 and E6.

Source: `spec.md` behaviour rule 7, §Out, F-3, E5, E6.

---

## Issue 12 — `spec.md` does not carry the rule file's "revisit the test file in the same PR" warning

Lens: 3. Severity: ADVISORY. Resolution: JUDGMENT CALL.

`.claude/rules/testing-surveycore.md` warns that a later PR moving the
replicate path to design-based degrees of freedom must revisit
`tests/testthat/test-variance-replicate.R` in the same PR, because every
confidence-bound assertion fails at once and the failure reads as a scale
defect.

`test-spec.md` carries it at lines 88-92. `spec.md` carries the underlying
fact in §Out but not the instruction, and `spec.md` is the document whose
write surface unwraps those very assertions.

**The lens recommends no change**: the warning's authoritative home is the
rule file, `test-spec.md` duplicates it, and `spec.md`'s job is the value
change. Recorded for visibility.

Source: `.claude/rules/testing-surveycore.md:239-243`; `test-spec.md:88-92`;
`spec.md:49`.

---

## What the review confirmed

Worth recording, because it is the larger part of the result.

- **Both target values stand.** No lens challenged `JKn = 1` or
  `bootstrap = 1/(R-1)`.
- **Lens 2 Q5 and Q6 are fully clean.** `scale` is a design-level constant
  passed unchanged into the variance engine whatever the domain, the grouping
  or the NA drop — verified against `R/variance-replicate.R:26-46` and
  `R/analysis-means-helpers.R:150-192`. Only the JKn and bootstrap branches of
  the `switch()` change; the other seven are untouched literals, and the
  spec's table matches the source line for line.
- **The point-estimate invariance is stated correctly everywhere.** No
  sentence in either document implies a point estimate moves.
- **The confidence-bound precondition is stated.** `test-spec.md` records that
  both sides use the normal approximation at `df = Inf` and that this work
  moves neither.
- **Every variance-to-standard-error conversion is right.** Lens 3 checked
  each stated ratio and found no place where a variance ratio was reported as
  a standard-error ratio or inverted.
- **No `v_1` inheritance.** The spec states `v_4` and `v_2` and explicitly not
  Jones's `v_1` — the error an earlier `comprehension.md` draft carried and
  that adversarial verification corrected.
- **No Wolter citation for the bootstrap.** Lens 6 confirmed the spec
  disclaims the chapter for that change, which F11 requires.
- **G1 and G4 are both honoured.** The `rscales = NULL` window is stated with
  #255 as owner, and neither document claims the oracle rows validate the
  estimator.
- **Q3 is resolved in writing**, with a stated reason, in `test-spec.md`.

---

## Routing

Stage 2r (resolve) in BIG mode. Five REQUIRED-UNAMBIGUOUS findings resolve as
a batch. Seven JUDGMENT_CALL findings need the user, and issues 2, 3 and 8 are
the three that change what ships.

**Paused before Stage 2r at the user's instruction, 2026-09-23.** No finding
has been applied. `spec.md` and `test-spec.md` are unchanged since Stage 1.

---

# Methodology Review: replicate-scale-jkn-bootstrap — Pass 2 (2026-09-23)

Delta pass, per the review-loop budget: two Explore agents on opus, scoped to
the eighteen headings the Stage 2r resolver reported as changed. Split by
finding rather than by document, so each agent could check its fixes against a
source. Neither re-read a whole document.

## Prior issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | bootstrap is a convention alignment, not a defect fix | 2, 5 | Resolved |
| 2 | `(n_h-1)/n_h` is the with-replacement form | 6 | Resolved, with two follow-on defects |
| 3 | `mse` exclusion used a jackknife-only theorem | 2 | Resolved |
| 4 | JKn justification dropped F9's C1 and C3 | 2 | Resolved |
| 5 | `R = 1` infinite scale claimed but untested | 1, 3 | Resolved, with two follow-on defects |
| 6 | point-estimate row asserted a tolerance | 1 | Resolved, with one follow-on defect |
| 7 | Fay row marked unchanged without noting divergence | 5 | Resolved |
| 8 | nonprob sentence lacked the magnitude | 5 | Resolved, with one follow-on defect |
| 9 | Wu / Chen divisor attribution unverified | 5 | Open by decision — D-5 |
| 10 | rescaling-bootstrap objection not on record | 5 | Resolved |
| 11 | domain-stratum gap had no §Out row | 4 | Resolved |
| 12 | df warning absent from `spec.md` | 3 | No change, by decision — D-5 |

Ten of twelve resolved. Issue 9 stays open as a verification item for the
user. Issue 12 needed no change.

## New issues — seven follow-on defects

None changes a target value. All seven are one-line or one-word edits, except
FIX C, which the user resolved by adding a file to the write surface.

**The two that only a measured check would find.** Both concern `test-spec.md`
row 2.4, added in Stage 2r for issue 5.

- **Frame B's mechanism does not hold.** The row sets the single replicate
  weight column equal to the base weight to force a zero deviation. The two
  estimates take different accumulation routes:
  `R/variance-replicate.R:106-112` computes the full-sample statistic as
  `sum(y * w) / sum(w)`, base `sum()` in long double, and the replicate
  statistic as `as.numeric(y %*% rep_mat) / colSums(rep_mat)`, a BLAS product
  in double. Measured at `n = 40` with lognormal weights, the deviation is
  `1.776e-15`, not zero, so the standard error is `Inf` and the row's `NaN`
  assertions fail. The row is BLAS-dependent and data-dependent as written.
  A measured frame that works: `y = c(1, 2, 3, 4)`, `w = c(1, 1, 2, 2)`. The
  reason the deviation is zero is that no rounding occurs on either route.
- **Frame A's mechanism is insufficient.** A weighted mean is invariant to a
  proportional rescaling of the weight column, so a replicate column of
  `3 * w` differs at every element and still gives a deviation of exactly
  zero. Frame A would silently produce frame B's outcome and fail its own
  `is.infinite()` assertions. It needs a non-proportional difference.
  Measured working case: `w = c(1, 1, 2, 2)` against `c(5, 1, 2, 2)` gives a
  deviation of `-0.733`.

**The one that moves a published number.** The nonprob note said the standard
error is smaller by `sqrt((R-1)/R)`, "2.6% at `R = 20`". Measured:
`sqrt(19/20) = 0.9746794`, so the fall is 2.5% and the rise in the other
direction is 2.6%. Behaviour rule 6 states the rise and its 2.6% is right; the
nonprob note states the fall and needs 2.5%. The transposition came from D-4's
own instruction to reuse behaviour rule 6's figure instead of recomputing it —
right about the factor, wrong about the percentage, because the two directions
do not share one number. The orchestrator had repeated the error in
`decisions.md` and to the user before the review caught it; D-4 now carries
the correction.

**The other four.**

- `N_h` was defined as a stratum element count while `n_h` was defined as a
  sample PSU count — Wolter §4.5 line 1102 paired with §4.6 line 1597. F-7
  asks a caller to compute `1 - n_h/N_h` by hand, so a two-stage design would
  divide PSUs sampled by elements in the stratum. `N_h` is population PSUs.
- F-7 shipped with both symbols undefined on the rendered page, and with no
  statement of where `N_h` comes from. Because D12 refuses `fpc`, surveycore
  never holds it and the caller must supply it. The user chose to define both
  symbols and state the provenance.
- G8 asks for the correction in `@param rscales`; the resolver put it in
  `@param scale` for a sound reason and did not record the override, leaving
  `@param rscales` with no pointer. The user chose to keep F-7 where it is and
  add a cross-reference clause, which adds a third roxygen edit to the write
  surface and extends quality gate 7.
- `expect_identical()` breaches `.claude/rules/testing-standards.md`
  §Assertions, whose `expect_equal()` column names "any calculated numeric
  result" and "estimates" categorically, with no carve-out for an exact claim.
  `expect_equal(tolerance = 0)` is both rule-conformant and the repo's
  dominant pattern — `tests/testthat/test-conversion.R:837-838`.

Plus two stale details and one spillover: §In still called the nonprob note a
"sentence", the two-sentence licence cited a line-length bound that does not
exist for prose, and issue 1's new paragraph asserted independent literature
support for `1/R`, which is exactly what issue 9 records as unverified.

## What Pass 2 confirmed

- **Issues 1, 3, 4, 7, 10 and 11 landed correct**, each checked word for word
  against `comprehension.md` or the rule file.
- **Every `q_h` definition matches Wolter** — chapter lines 1184-1186 — and
  F-7's `(n_h - 1)(1 - n_h/N_h)/n_h` is exactly `q_h/n_h` without
  replacement.
- **Numbered fact 2's added clause is right.** At `L = 1`,
  `q_h/n_h = ((R-1)/R)(1 - n/N)`, which equals `(R-1)/R` only when
  `n/N = 0`. The coincidence does need the condition.
- **All six of issue 3's claims check out** against F11 and F6, neither
  overstated nor understated.
- **The six other unchanged types do agree with `survey`** — BRR, JK2, ACS,
  successive-difference, `other` and JK1, the last in the
  `combined.weights = TRUE` branch that is surveycore's mode. Fay is the only
  divergent row, as issue 7's annotation now says.
- **Row 2.4's claim is true even though its construction was wrong.** The
  agent built both frames against installed `survey` 4.5 and confirmed both
  sides reach the same two outcomes, with no warning raised.
- **Row 2.4 is a genuine oracle row** under
  `.claude/rules/testing-surveycore.md` §What the rule covers, and obeys all
  five rules. Comparing a predicate rather than a number to a tolerance does
  not take it out of scope.
- **The §2 preamble narrowing was necessary.** The old blanket claim was
  false: row 2.3 passes the old `scale` explicitly, which rule 2 forbids
  outright, and makes no `svrepdesign()` call, so rules 3 and 5 are vacuous
  for it.
- **The three moved counts match one-to-one**, item by item and not only in
  the numeral — the check a numeral-only grep cannot make.
- **Isolation holds.** `spec.md` carries no tolerance, dataset or scenario and
  never names the other document; `test-spec.md` carries no path under `R/`.

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 7 |
| ADVISORY | 0 |

**Assessment.** Stage 2r resolved ten of twelve findings cleanly and
introduced seven follow-on defects, five of them clerical and two of them
real: a test row whose two fixtures could not produce the outcomes they
assert, and a percentage stated in the wrong direction. Both were caught by
running the arithmetic rather than by reading the prose. The pattern from
Pass 1 — conclusions stated without their conditions — did not recur.

Fix round dispatched. One targeted verification follows, which is pass 3 of
the three-pass budget.

---

# Methodology Review: replicate-scale-jkn-bootstrap — Pass 3 (2026-09-23)

Final pass. One Explore agent on opus, scoped to the eight corrections the
fix round applied to Pass 2's seven defects. Pass 3 of the three the
review-loop budget allows.

Before dispatching it the orchestrator verified mechanically: both
percentages in the right directions, `RS-1` present, three roxygen edits in
§Files touched, quality gate 7 extended, `expect_equal(tolerance = 0)` in row
2.3, isolation intact both ways. It also ran row 2.4's pinned frames — see
`measurements.md` M3.

## Result — six of eight clean, two defects, both in one cell

**FIX B, C, D, F, G and the spillover: clean.** Each checked against its
source. Notable confirmations:

- Every `N_h` occurrence in both documents now reads as population PSUs,
  fourteen sites in `spec.md` and one in `test-spec.md`, and row 4.1 marks
  the element reading wrong.
- The Wolter adaptation is stated honestly. Chapter line 1102, under §4.5,
  writes `N_h` for the size of the stratum; line 1597, under §4.6, writes `N`
  and `n` for PSU counts in the population and the sample. §4.6 writes the
  symbol unsubscripted, and `spec.md:214` says to read `N_h` as the §4.6
  quantity rather than attributing a subscripted PSU `N_h` to Wolter.
- `RS-1` did its job: seven facts stay seven, no `F-8` exists in either
  document, and row 4.1 carries the cross-reference as explicitly outside the
  seven. §Documentation's three roxygen targets are distinct and none is
  claimed twice.
- F-7's Pass 2 narrowing is fixed — row 4.1 fact (7) now carries the entry,
  the symbol key and the provenance. F-2's narrowing is unchanged and not
  worsened; the dropped clause survives elsewhere in the document.
- All three §Tolerances counts match their own lists. The fix round's cited
  line numbers had gone stale; the counts had not.

## The two defects, both introduced by the frame pinning

Both verified by the orchestrator against the source before applying.

**Row 2.4 asserts a standard error the call does not return.**
`get_means()`'s `variance` argument defaults to `"ci"`
(`R/analysis-means.R:101`), which returns the two bounds and no standard
error. The row asserts a standard error four times — one premise and one
conclusion per frame — and never named the argument. Pass 2 had flagged this
as cosmetic and was half right: the bounds do come back unasked, the standard
error does not.

**The four-row frames trip the small-cell warning.** `min_cell_n` defaults to
`30L` (`R/analysis-means.R:105`) and the warning fires for any cell with
`0 < n < min_cell_n` (`:229-230`). Every one of the four `get_means()` calls
on a four-row frame raises `surveycore_warning_small_cell`, so the row's
"neither construction and neither estimate raises a condition" clause was
false. It was false only because the fix round replaced the `n = 40` frames
with four-row ones — the defect was created by the previous fix.

**Applied by the orchestrator**, directly, as two edits in one cell:
`get_means(variance = c("se", "ci"), min_cell_n = 1L)`, with a sentence
stating that both arguments are required, that neither is the default, and
why each is needed. The no-condition clause now says it holds only with
`min_cell_n = 1L` and is false at the default. `min_cell_n = 1L` silences the
warning at its source rather than asserting it, because the small cell is a
property of these fixtures and not of the behaviour under test.

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| ADVISORY | 0 |

Both resolved.

---

# Stage 2 verdict: PASS

Twenty-one findings raised across three passes. Nineteen resolved, one open
by the user's decision, one closed as no-change.

| Pass | Raised | Resolved | Carried |
|---|---|---|---|
| 1 — six lenses | 12 | 10 | issue 9 open by decision, issue 12 no change |
| 2 — delta, two agents | 7 | 7 | — |
| 3 — delta, one agent | 2 | 2 | — |

**No pass challenged either target value.** `JKn = 1` and
`bootstrap = 1/(R-1)` stand as Stage 0 confirmed them.

## Two caveats on this PASS, stated plainly

1. **The two Pass 3 fixes carry no independent review.** The three-pass
   budget was spent, and the rule caps review passes rather than the
   application of verified findings. The orchestrator verified both against
   `R/analysis-means.R` and applied them itself. No agent has read the
   result. A Stage 3 lens that happens to read row 2.4 may see them; none is
   assigned to.
2. **Issue 9 stays open, and it is the user's to close.** The
   `bootstrap = 1/R` attribution to Wu (2022) and Chen et al. (2021) is
   pre-existing shipped text, and D1's new note puts it in direct contrast
   with `survey`'s value for the first time. Neither paper was attached to
   this run, so the divisor-specific claim is unverified. `decisions.md` D-5
   records it. It blocks nothing, and it should be answered before the
   sentence ships.

## What changed across the three passes

The spec began stating Stage 0's conclusions without Stage 0's conditions.
Four lenses each found an instance. It now carries:

- the verdict as "confirmed with conditions", with C1 and C3 named;
- `q_h / n_h` as the form Wolter's equations use, with `q_h` defined both
  ways and the with-replacement condition stated in four places;
- the bootstrap change marked a convention alignment rather than a defect
  fix, in the prose and in a sixth NEWS element;
- the `mse` exclusion scoped to the jackknife, with the bootstrap pairing
  documented as inherited from `survey` and unproven in this run;
- Fay marked unchanged and still divergent;
- both `R = 1` outcomes, `Inf` and `NaN`, with a test row that proves its
  premise before its conclusion;
- a without-replacement instruction that ships with its symbols defined and
  its provenance stated.

Nothing in that list changes a number the package computes. All of it
changes what the package tells a reader about the numbers it computes.
