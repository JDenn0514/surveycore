# Methods review — replicate-oracle-tests

**Pass**: 1 of a maximum 3 (full panel)
**Date**: 2026-09-16
**Verdict**: FAIL — three REQUIRED findings, all UNAMBIGUOUS. Route to Stage 2r.

## Scope assessment

The spec changes no estimator and ships no source file. It does fix the scale
each of nine replicate types must use, and it compares standard errors and
confidence bounds between two packages. Lens triggers met: standard errors,
confidence intervals, replicate scale formulas.

| Lens | Applies | Outcome |
|---|---|---|
| 1 — Estimator specification | yes | no issues |
| 2 — Variance estimation | yes | 1 REQUIRED, 1 ADVISORY |
| 3 — Degrees of freedom and inference | yes | 1 REQUIRED, 1 ADVISORY |
| 4 — Domain estimation | no | not applicable: the spec touches no domain path |
| 5 — Established practice | yes | 3 ADVISORY |
| 6 — Literature cross-check | yes | 1 REQUIRED, 1 ADVISORY |

## Issue 1 — `mse = TRUE` in the common contract deletes the only `mse = FALSE` test

Lens: 2
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

`spec.md` §IV.1 item 3 fixes `mse = TRUE` for every one of blocks 1 to 8, as an
unconditional literal with no carve-out. `spec.md` §V.1 tells the builder to edit
the four existing BRR blocks in place and "change nothing else".

One of those four is `test-variance-replicate.R:200`, which builds both sides with
`mse = FALSE`. It is the only block in the file that reaches the
`mean(thetas[rscales > 0])` centering branch of the shared variance expression.
`comprehension.md` §G8 lists it.

A builder who follows §IV.1.3 literally flips that block to `mse = TRUE` and
deletes the branch's only test. The flipped block still passes, because BRR's
scale agrees on both sides whatever the centering. No gate catches the loss. That
is the same silent-coverage failure this PR exists to close, reproduced inside the
fix.

**Fix**: generalise §IV.1.3 to `mse` fixed per block, `TRUE` unless the §V row
says otherwise. Add a note to §V.1 naming the block that keeps `mse = FALSE` on
both sides.

## Issue 2 — the CI comparison rests on an unrecorded premise

Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Every numerical block asserts both confidence bounds agree to `1e-6`. That holds
only while both packages build the interval from the same distribution and the
same degrees of freedom.

Measured, and true today:

- `survey:::confint.svrepstat` and `confint.svystat` both carry `df = Inf`, so
  `survey:::tconfint` calls `qt(a, df = Inf)`, which equals `qnorm(a)`.
- surveycore reads `degf <- Inf` unconditionally on the replicate path, in
  `R/analysis-means.R:166` and five sibling files. `.degf(design)` reaches only
  the `cell_df` attribute of Taylor and two-phase designs, which no block here
  builds.
- Empirical: on a JK1 design at `R = 10`, `confint(m)` equals
  `confint(m, df = Inf)` and differs from `confint(m, df = degf(sv))`.

Neither `spec.md`, `comprehension.md` nor `measurements.md` records any of this. A
grep of all three for `degf`, `confint`, `qt`, `qnorm` and "normal approximation"
returns nothing. The document holds every other claim to a measured standard and
leaves this one unstated.

The forward risk is concrete. If a later arc PR moves the replicate path to
design-based df, every CI assertion in the file fails in a shape identical to the
scale failures the file exists to catch, and no document explains why the blocks
ever agreed.

**Fix**: record the measurement as a new section in `measurements.md`, state it in
`comprehension.md`, and name it in the oracle rule as a precondition of the
confidence-bound clause.

## Issue 3 — the spec describes closed work as pending

Lens: 6
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

`spec.md` §V.3 says the wrong JK2 wording "is issue #260's work at two other
sites". `comprehension.md` §G9 says the same and quotes the wrong text as current
at `R/core-constructors.R:602-611`.

Verified at HEAD by the leader:

- Issue #260 is CLOSED, at 2026-09-16T07:32:40Z, by PR #280, commit `7800ea9`.
- `R/core-constructors.R:602-611` now reads "the per-stratum factor is already
  inside the replicate weights: `rscales` stays at `rep(1, R)`".
- `grep` for the wrong wording across `R/`, `man/` and `tests/` returns nothing.

The deliverable does not change — the instruction not to write the wrong wording
stays sound either way. The cost is trust: the claim is false, and one `git log`
falsifies it, which invites doubt about the measured claims that are sound.

**Fix**: correct §V.3 to record #260 as closed by PR #280, and reframe the clause
as hygiene rather than a pointer to open work. Correct `comprehension.md` §G9 the
same way.

## Issue 4 — no forward guard on the CI distribution

Lens: 3
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The same premise as Issue 2, seen forward. Folded into Issue 2's fix: the oracle
rule states the precondition, so a later PR that changes df handling is warned.

## Issue 5 — the `other` block's agreement is inferred, not measured

Lens: 2
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`spec.md` §V.8 states the two sides agree for `type = "other"`. No oracle block
for `other` exists today, and no probe ever built both sides and compared the SE.
The claim rests on two measured components — both scales are `1`, and the JK1
fixture gives matching replicate estimates — joined by inference.

The inference is strong, and a disagreement would surface loudly on the block's
first run rather than silently. The lens recommended leaving it.

**Leader decision: close it by measurement.** The probe is cheap, and the run's
own standard is that a claim is measured or marked unverified. One inferred cell
in a document built to remove inferred cells is not worth defending.

## Issue 6 — literature anchor for JKn and bootstrap

Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The lens confirmed `survey` is right by the literature on both types, not merely
different. Wolter (2007) Ch. 4 gives the stratified jackknife a per-replicate
factor keyed to the PSU count of the dropped stratum, which is why `survey`
carries it in `rscales` and refuses JKn without one. surveycore's `(R-1)/R`
substitutes the total replicate count for the per-stratum count, so it stays wrong
under unequal stratum sizes even after the 2.53% gap closes.

**Accepted as recommended — defer.** This PR ships no scale change. The citation
belongs in PR 3's spec, where the fix lands. Recorded here so PR 3 inherits it.

## Issue 7 — `type = "other"` has no methodological content

Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`type = "other"` is a passthrough with no prescribed variance formula. Block 8
checks that surveycore's fallback constant has not drifted from `survey`'s. It
proves parity, not correctness.

**Accepted as recommended — leave.** `plans/issue-cleanup.md` D11 and
`comprehension.md` §O4 both record it, and the spec claims no more than parity.

## Issue 8 — D8 is operative on the JK2 row but never named

Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

§V.2 cites D9 and the bootstrap row cites D5. §V.3 cites no decision, though D8 is
the decision that makes the JK2 block assert only `survey`'s warning and not
surveycore's silence.

**Fix**: name D8 in §V.3. It makes all three warning-asymmetry decisions traceable
rather than two of three.

## Issue 9 — G7, `rscales` of length 1

Lens: 6
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`survey` accepts `rscales` of length 1 or length `R`. §V.4 says "one per
replicate", which already forecloses a scalar.

**Accepted as recommended — leave.** The wording is unambiguous.

## What Stage 2r must do

Batch, all UNAMBIGUOUS. No user decision required.

1. Issue 1 — `spec.md` §IV.1.3 and §V.1.
2. Issues 2 and 4 — new measurement, `comprehension.md`, `spec.md` §III oracle
   rule, `test-spec.md` tolerance section.
3. Issue 3 — `spec.md` §V.3 and `comprehension.md` §G9.
4. Issue 5 — run the `other` probe, record it, update `spec.md` §V.8.
5. Issue 8 — `spec.md` §V.3.
6. Issue 6 — record for PR 3. No edit to this spec.

Issues 7 and 9 need no change.

---

# Pass 2 — delta

**Date**: 2026-09-16
**Scope**: the sections Stage 2r changed. Two agents, per the review-loop budget.
**Verdict**: PASS. Every fix verified. No new issue. No artifact change needed,
which is the early exit.

## Agent A — Issues 1, 2, 4, 5

All RESOLVED.

- §IV.1 item 3 carves out the exception and still requires the same `mse` on
  both sides. Every `mse` hit in `spec.md` checked; only §IV.1.3 ever carried the
  unconditional literal.
- §V.1 names the block by title and says why flipping it would delete the
  centred branch silently.
- The `R` row is corrected. BRR gives half as many replicate columns as primary
  sampling units, so `n_psu = 10` gives `R = 5` and the other three blocks give
  `R = 10`. The leader measured `R = 5` independently.
- §M7 is internally consistent: `qt(0.975, df = Inf)` and `qnorm(0.975)` both
  read `1.95996398454005361`, `identical()` is `TRUE`, and the `degf = 19`
  interval sits `0.031959270920915` from the default. The same figure appears in
  §G12 and in `test-spec.md` §8.
- The precondition sits inside the rule blockquote, so it ships into the rules
  file.
- The eight `.degf()` call sites are confirmed by grep. Seven sit behind the
  `is_taylor_like` guard. The eighth, `R/glm.R:587`, is reached only from
  `analysis-diffs.R`, `analysis-t-test.R`, `glm-anova-dispatch.R` and
  `glm-anova.R` — never from `get_means()`.
- §M8 builds both sides as two independent calls. Neither passes `scale` or
  `rscales`, and neither reads a value off the other.

## Agent B — Issues 3, 6, 8, and the two-artifact rule

All RESOLVED. The rule HOLDS.

- §V.3 names PR #280 and commit `7800ea9`, reframes the clause as hygiene, and
  does not write the wrong wording itself. §G9 carries the same correction and
  says an earlier draft was wrong.
- Every `260` hit in both documents is a corrected, closed-issue statement.
- The three warning-asymmetry rows cite D9, D8 and D5.
- §G13 holds the Wolter material, marked `[verify]`. `spec.md` and `test-spec.md`
  contain no hit for "Wolter", so the anchor stays out of this spec and travels
  to PR 3.
- No stale `M0 to M6` range survives.
- `spec.md` names no tolerance value and does not mention `test-spec.md`.
  `test-spec.md` names no file under `R/` and does not mention `spec.md`. Zero
  hits in both directions.

## Stage 2 verdict

**PASS.** Route to Stage 3.
