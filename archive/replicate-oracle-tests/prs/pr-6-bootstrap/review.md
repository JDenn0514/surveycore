# Review — PR 6 — test/replicate-oracle-bootstrap

**Verdict**: PASS
**Date**: 2026-09-22 16:40

Reviewed at commit `e4d8657f0df9cf7ffc340dfb28346fc3de5019b7`, tree
`a8455700b9ae18c642daad8c5911799eb020ce4d`, base
`bbafed090cb93a63915dd5704d1f361228e2032d`. `git diff --numstat bbafed0 HEAD`:
one file, `tests/testthat/test-variance-replicate.R`, **+81 / −0**.
`git status --porcelain -- tests R` is empty.

Scope of this verdict: rows 3.1.5, 2.9, 2.10, 2.11, 2.15, 2.16, 3.6.1, 3.6.2,
3.6.3, 3.6.4 — the plan's ten allocated rows — and PR 6's eight acceptance
criteria. Nine of the ten rows read the JKn and the bootstrap block together,
and I read both.

## Convergence checks

- Spec coverage: **y** — every element of `spec.md` §V.5 and §IV.3 "The pinned
  blocks" has a row or criterion in `audit.md`, and each is delivered and
  independently re-measured below.
- Test coverage of spec: **y** — `test-spec.md` row 3.1.5, §3.4, §3.6 and §3.7
  cover §V.5. No §V.5 element lacks a scenario.
- Tolerance integrity: **y** — see §Tolerance integrity.
- Scope discipline: **y** — `implementation.md` §Write surface names one file;
  the plan's PR 6 "Files touched" names the same file; `git diff --name-only`
  names the same file and nothing else.
- Regression safety: **y** — gate 2 on this tree reads
  `FAIL 0 | WARN 256 | SKIP 4 | PASS 11996`. PR 5 left 11989, so **+7**, which
  is exactly the new block's seven expectations: the no-warning assertion, the
  stored scale, the point estimate, three wrappers, the ratio. Warnings and
  skips unchanged. No test outside the PR's surface changed state.

## Independent verification — the third instrument

I did not trust the builder's parser or the tester's awk. I wrote a
character-level R lexer in Python
(`scratchpad/rlex.py`): a state machine over every byte of the file that tracks
double-quoted, single-quoted and backtick strings with escape handling and
comment-to-end-of-line, emits code characters only, then walks `(`, `[`, `{`
to build a call tree keyed on the identifier immediately left of each `(`. A
construct named in a comment or inside a string literal can therefore never be
counted. Depth 2 is the `test_that()` body; depth 3 is inside a body-level call.

Whole-file counts, my instrument against naive line counting:

| Construct | `grep -c` lines | My code calls | Builder's parser | Tester's awk |
|---|--:|--:|--:|--:|
| `expect_failure` | 12 | **6** | 6 | 6 |
| `svrepdesign` | 15 (`svrepdesign(`: 14) | **12** | 12 | 12 |
| `test_that` | 26 | 26 | — | — |
| `suppressWarnings` | 0 | **0** | — | 0 |
| `test_invariants` | 1 | **1** | — | — |

Three instruments now agree on 6 and 12. The counting trap is real and I hit
none of it.

Per-block structure, measured:

| Property | JKn block, 806–884 | bootstrap block, 886–965 |
|---|---|---|
| `expect_failure()` wrappers at depth 2 | 3, at 865 / 868 / 871 | 3, at 942 / 949 / 952 |
| Direct `expect_*` children per wrapper | 1, 1, 1 (866, 869, 872) | 1, 1, 1 (943, 950, 953) |
| Total `expect_*` inside each wrapper | 1, 1, 1 | 1, 1, 1 |
| Point estimate, depth 2, unwrapped | 861, `1e-10` | 937, `1e-10` |
| `survey` stored scale, depth 2, unwrapped | 855, `1` at `1e-8` | 931, `1 / (n_rep - 1)` at `1e-8` |
| `expect_no_warning(` / `svrepdesign(` | 843 at d2 / 844 at d3 — inside no wrapper | 920 at d2 / 921 at d3 — inside no wrapper |
| Unwrapped ratio assertion (`expect_equal` carrying `/` and `sqrt`) | 1, at 879–883, depth 2 | 1, at 960–964, depth 2 |
| `scale =` / `rho =` / `bootstrap.average` / `combined.weights` / `suppressWarnings` in block | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |
| `rscales` occurrences | 2 (one literal per side) | **0** — row 3.1.5 asks for none |
| `mse =` occurrences | 2 (both sides) | 2 (both sides, N1 honoured) |
| Tolerances present | `1e-10`, `1e-8`, `1e-6` | `1e-10`, `1e-8`, `1e-6` |

All six `expect_failure()` calls in the file sit in these two blocks: the
file-wide code count is 6 and these two blocks hold 3 each. "Three and three"
and "one and one" hold. All four §IV.3 mechanics hold on both blocks.

## The ratio assertion, scrutinised

Delivered at 960–964 as
`expect_equal(sc_mean$se / as.numeric(survey::SE(sv_mean)), sqrt((n_rep - 1) / n_rep), tolerance = 1e-8)`,
at depth 2, inside no wrapper. Right pair, right order — surveycore over
`survey`, below 1 because surveycore's scale is the smaller — against a literal
formula, with `n_rep <- length(repwt_cols)` read from the selected `^repwt_`
columns (907–908). No `20` is hard-coded anywhere in the block's assertions.

**The residual is bit-identical to the JKn block's, and that is what these
inputs must produce.** I recomputed it from the builder's 17-digit bootstrap
probe in IEEE double arithmetic, independently of the JKn numbers:

| Quantity | Value | Hex |
|---|---|---|
| `0.055102628456081222 / 0.056534103938925245` | `0.9746794344809909` | `0x1.f3092ece5bf89p-1` |
| `0.24018678896352669 / 0.24642644593339988` (JKn) | `0.9746794344809909` | `0x1.f3092ece5bf89p-1` |
| `sqrt(19/20)` | `0.9746794344808963` | `0x1.f3092ece5bc35p-1` |
| bootstrap residual | `9.459100169806334e-14` | — |
| JKn residual | `9.459100169806334e-14` | — |

The bootstrap SE pair — two numbers four times smaller than JKn's — lands on the
same double as the JKn pair. Had the builder copied the JKn residual while the
bootstrap inputs produced a different one, this recomputation would have
disagreed. It does not. The cause is structural, not coincidental: the
replicate columns at seed 15 are the same draws in the `jkn` and `bootstrap`
generator modes (comprehension M2 records identical `repwtmn` 11.9183 for both),
so the sum of squared replicate deviations is identical, and both ratios reduce
to the same rounding chain. Reconstructing that sum from each block's own
numbers gives `0.060725993255378634` from bootstrap and `0.06072599325537864`
from JKn, and `SE_jkn / SE_boot = 4.358898943540673` against
`sqrt(19) = 4.358898943540674`, one ulp apart. The residual's size, about 437
ulps, comes from a systematic `~1.9e-13` relative difference between the two
packages' variance sums, which is the same on both fixtures for the same reason.

**Four facts say the bootstrap numbers were measured, not transcribed.**

1. The reported SEs carry 17 significant digits — `...456081222`,
   `...938925245` — where `spec.md` §V.5 prints 15. The extra digits exist in no
   upstream artifact.
2. The four bootstrap confidence bounds appear in no artifact before
   `implementation.md`. All four reconstruct exactly as
   `50.436542684160358 ± qnorm(0.975) * SE` from the bootstrap SEs: implied
   `50.328543516932946` / `50.54454185138777` against reported
   `50.328543516932946` / `50.54454185138777`, and the same for the `survey`
   side. The identical reconstruction holds for PR 5's JKn bounds from the JKn
   SEs. Bounds that reconstruct from their own block's SEs are a run, not a copy.
3. `sv$scale` reads `0.052631578947368418`, which is `1/19` exactly at 17
   digits, distinct from the JKn block's `1`. surveycore's stored scale reads
   `0.050000000000000003`, which is `1/20` exactly. Both are genuine R
   `digits = 17` renderings.
4. The block asserts `1 / (n_rep - 1)` where the JKn block asserts `1`, so the
   two stored-scale assertions cannot be the same line copied.

`bootstrap.average` is passed to neither side, and the comment at 918–919 says
why and cites `plans/issue-cleanup.md` D5.

## The four-line comment and the title

Lines 889–898 name issue #253 twice and read "When issue #253 lands, delete FOUR
lines: the three expect_failure() wrapper lines and the ratio assertion at the
end of this block. Deleting only the three leaves the ratio assertion to fail
against the corrected default." Count, which four, and the failure mode the
count prevents — all three present (row 2.16).

Title: `get_means() bootstrap SE disagrees with survey::svymean() — issue #253`.
Names the disagreement, names the issue, claims no match; the verb is
"disagrees".

**Ruling on the 85-character opening line: the builder resolved it correctly.**
The line is 85 characters (87 bytes; the dash is an em dash). `air` cannot break
it, because the overflow sits inside a string literal, and `air format --check`
exits 0 — row 2.14 makes `air` the formatting authority, and `lintr` appears in
none of the seven profile gates and none of the seven CI checks. A compliant
form does exist, unlike the S4 case: dropping the word "issue" gives 79
characters. I judge that the wrong trade. The pinned pair's contract is
word-for-word symmetry — nine of this PR's ten rows read both blocks, PR 3 will
delete four lines from each, and PR 9's row 6.15 quotes both titles — and an
asymmetric pair invites a later reader to think one was edited. The file already
carries 24 lines over 80, 12 of them the stored-scale comment that decision S4
accepted on the same reasoning. Reopening the PR to buy six characters would
cost a builder cycle and a full gate pass for a limit nothing automated reads.
The line stays. This extends S4 rather than breaching it; the leader may want to
record that as a decision.

## The JKn block was not modified

Confirmed three ways, not one:

- `git diff --numstat` reports `81 0` — zero deletions.
- `diff` of lines 806–884 at base against HEAD: identical.
- `md5sum` of lines 1–884 at base and at HEAD: both
  `e89123ae743413cc034f983cdd5788dd`.

So criteria 2 to 6 are satisfied on the JKn side by bytes the base branch
already carried, and the builder's report of finding no discrepancy is
consistent with what I measured on the JKn block itself.

## Placement, and room for PRs 7 and 8

The `^# Block ` header list is byte-identical at base and HEAD — seven headers,
at lines 9, 358, 572, 619, 652, 751, 803. No new header, none renumbered. The
file grew from 884 to 965 lines and every added byte sits after line 884, so the
bootstrap block sits under the existing `# Block 24:` header, after the JKn
block, at the end of the file. §II's order is intact — JKn then bootstrap — and
`other` then Fay can append beneath in that order with no interleaving.
Line endings: 965 CRLF, 0 bare LF, all 81 added lines CRLF, trailing newline
present.

## Tolerance integrity

| Assertion | Delivered (bootstrap) | `test-spec.md` §8 | Verdict |
|---|---|---|---|
| Point estimate (937) | `1e-10` | `1e-10` | equal |
| Standard error, wrapped (943–947) | `1e-8` | `1e-8` | equal |
| Lower bound, wrapped (950) | `1e-6` | `1e-6` | equal |
| Upper bound, wrapped (953) | `1e-6` | `1e-6` | equal |
| `survey` stored scale (931) | `1e-8` | `1e-8`, SE/variance row | equal |
| Standard-error ratio (960–963) | `1e-8` | `1e-8`, SE/variance row | equal |

No tolerance is looser than specified, none is omitted, and none is on the wrong
row — the stored scale and the ratio both sit on the SE/variance row, as §8
requires. The diff carries 0 deletions, so no pre-existing tolerance could have
been widened; line ~174's missing tolerance (finding N2) is untouched and out of
scope. The JKn block's six tolerances are unchanged by construction.

The gap the wrappers rely on is `1.43e-3` absolute on the standard error against
a `1e-8` tolerance, five orders above it, so the three wrapped assertions fail
reliably and the three wrappers pass. The ratio's `9.46e-14` residual sits five
orders inside `1e-8`, so the ratio assertion passes today and turns red the
moment either default moves.

## Profile gates

`audit.md` §Profile gates and the After column of §Before/After read **pending**
— the gate pass was in flight and the tester was barred from starting an R
process. I ran no gate. I read the leader's completed run in
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr6/`, whose
`Tree:` line reads `a8455700b9ae18c642daad8c5911799eb020ce4d` — the tree the
audit records and the tree at HEAD.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing |
| `devtools::test()` | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11996`; +7 on PR 5 |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` — `checking CRAN incoming feasibility` and `checking for hidden files and directories` (`.git`); both on the baseline tree per `baseline.md`, neither new, no third NOTE |
| pkgdown | SKIPPED — scope | write surface is one test file; no `R/`, `vignettes/`, `README*`, `_pkgdown.yml`, `DESCRIPTION`; NAMESPACE diff empty, so the hard rule in `r-package-profile.md` does not bite |
| `covr` | 96.15% | equal to baseline 96.15%; clears the 95% floor |
| `air format --check` | PASS | exit 0 on the one changed file |
| CRAN cookbook scan | PASS | no violations; no file under `R/` touched |

Coverage is flat and the PR adds no source line, so a new-code coverage drop is
impossible. Every gate has a result and the one skip is an allowed one, logged
with its reason.

## Comprehension alignment

The bootstrap gotchas are discharged. M3's measured figures — SE
`0.0551026284560812` against `0.0565341039389252`, ratio `0.974679434480991`,
gap `-2.532057%` — match the builder's probe to every digit both print. M1/M2:
`type = "bootstrap"` is silent on a bare call and the "combined weights" check
fails by a wide margin (`repwtmn` 11.9183 against a threshold of 5), which is
why the block asserts no warning rather than a fragment. D5's
`bootstrap.average` gap is recorded in `spec.md` §V.5 as out of scope and the
block passes the argument to neither side. O3 — four quantities cannot sit in
one wrapper — is the shape delivered.

## Cross-consistency notes

`implementation.md` and `audit.md` agree with each other and with every figure I
re-measured: three wrappers at 942 / 949 / 952, one assertion each, the ratio at
960 outside every wrapper, the 99-character comment 11 → 12 by `grep -Fxc`, the
`9.46e-14` residual, seven headers unchanged, `+81 / −0`.

Three observations, none of them a defect and none conditioning this verdict:

1. **`audit.md` bookkeeping.** Its §Profile gates and the After column of
   §Before/After should be replaced with the table above before the arc is
   archived — the same item PR 5's review raised. The verdict does not depend on
   it: the gate evidence exists in `logs/pr6/` on the identical tree and I
   checked it directly.
2. **The two bound wrappers stay attributable only through the ratio
   assertion**, which compares standard errors. A misnamed `ci_low` would still
   produce a failing assertion and a passing wrapper. That is the shape
   `spec.md` §IV.3 and `test-spec.md` §3.6 specify, so it is a property of the
   design and not of this build. It now holds in two blocks rather than one.
3. **Block count is 26** — 24 before the arc plus JKn and bootstrap. Row 3.5.2
   expects 28 once `other` and Fay land in PRs 7 and 8.

## Decision

PASS. Every §V.5 and §IV.3 requirement is delivered and independently
re-measured with a third instrument: three wrappers of one assertion each in
both pinned blocks, six in the file and all six inside those two blocks, the
point estimate and the design call and its no-warning assertion outside every
wrapper, and one unwrapped ratio assertion per block against the literal
`sqrt((R - 1) / R)` with `R` read from the columns. The bit-identical residual
is what the bootstrap inputs produce — I recomputed it from the bootstrap SE
pair alone and it lands on the same double — and the 17-digit SEs, the
self-consistent bounds and the `1/19` stored scale show the numbers were
measured, not transcribed. Tolerances match `test-spec.md` on all six
assertions, the diff has zero deletions so the JKn block is byte-identical to
the base, placement leaves PRs 7 and 8 the order §II fixes, and the gates pass
on the reviewed tree with coverage flat at 96.15%.
