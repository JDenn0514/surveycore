# Review — PR 1 — replicate-scale-jkn-bootstrap-defaults

**Verdict**: PASS
**Date**: 2026-09-29 10:40

Branch `fix/replicate-scale-jkn-bootstrap-defaults`, HEAD `e8f10de`, tree
`24f9594dfb030b8fe70edfc4a29cd5c24de59023`, base `develop` at `fd621a1`.

This review ran no gate and started no R process. Every numerical verdict
comes from
`.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-1/`,
whose `Tree:` line is the tree above. Every structural verdict comes from
reading the diff.

## Convergence checks

- **Spec coverage**: y. PR 1 owns five test-spec rows — §2 rows 2.1 and 2.2,
  §4 rows 4.1, 4.3 and 4.4. `audit.md`'s Per-Test Result Table carries a row
  for each observable of all five and for nothing else. The spec contract
  items PR 1 does not carry (§Edge cases E1 to E7, the nine-type table, the
  two cross-constructor gates) belong to PRs 2, 3 and 4 by the plan's own
  map, so their absence here is the arc's shape and not a gap.
- **Test coverage of spec**: y. Every item of `spec.md` §Function contracts
  reaches a `test-spec.md` row: the two switch values reach rows 1.1, 1.7,
  2.1 and 2.2; behaviour rules 1 to 4 reach rows 1.2, 1.3, 1.4 and 1.5; rule
  6 reaches row 1.1; rule 8 reaches row 1.9; rule 5 and rule 7's domain
  clause are negatives with a written rationale (D-11, `test-spec.md` §1);
  F-1 to F-8, RS-1 and FP-1 reach row 4.1; D1's note reaches row 4.2.
- **Tolerance integrity**: y. Detail below.
- **Scope discipline**: y, on the settled authorisation. Detail below.
- **Regression safety**: y. The only state change outside the two named test
  files is the two blocks the HOLD identified, both inside the widened
  surface. The four skips in gate 2 are
  `test-glm-anova-numerical.R:287`, `test-glm-anova.R:481` and `:531`, and
  `test-srr-compliance.R:294` — read from `gate-2-test.log`, four at the
  baseline and four here, and none of them an oracle or a constructor block.
  No test was skipped to make a gate pass.

## Step 1 — convergence between implementation and audit

The two artifacts were written without sight of each other. They agree on
every load-bearing number, and three of the agreements are independent
derivations rather than copies.

| Fact | `implementation.md` | `audit.md` | Agree |
|---|---|---|---|
| Write surface | six files, named | six files, named | yes |
| Baseline / final suite | 12005 → 12004, WARN 256, SKIP 4 | same | yes |
| Net expectation delta | −2 ratios, 0 wrappers, +1 corr = −1 | −2 across the oracle blocks, 0 nonprob, +1 corr = −1 | yes, by two different decompositions |
| Nonprob SE ratio | `0.97467943448089656` vs `0.97467943448089633` | quotes the block's own figures | yes |
| Fisher-z ratio | `0.94868329805051332` vs `0.94868329805051377`, dev `4.4e-16` | same, and checks the r-space gap arithmetically at `7.769e-05` | yes |
| `air format --check` | two files fail, identically at base | two files fail, identically at base | yes, independently |
| `tests/testthat/_snaps/` | 30 files dirtied by line endings, all reverted, none dirty at the end | `git diff --stat develop..HEAD -- tests/testthat/_snaps/` empty | yes, by two methods |
| `man/as_survey_nonprob.Rd` unchanged | correct, PR 4's work | not in the write surface | yes |

The expectation-count decomposition is the strongest of these. The builder
counts the six wrappers as replaced one for one (net 0) and the two ratio
assertions as deleted (−2). The tester counts each oracle block as losing
four and gaining three (−1 each, −2 across the two). Different arithmetic,
same total, and the total reconciles against the measured suite counts.

**One disagreement, and the audit is right.** `implementation.md` §Gates
says "No added line over 80 columns — Pass across all six files; longest
added line is 78." Measured on the diff: the longest added line in
`tests/testthat/test-constructors.R` is 79, which the builder's own `air`
row states correctly two lines later, and the regenerated
`man/as_survey_replicate.Rd` carries added lines to 107 columns.
`audit.md` scopes the same claim to "every added line in `R/` and `tests/`",
which measures true — 0 lines over 80, longest 79. `.Rd` is a
`devtools::document()` artifact and `code-style.md`'s 80-column rule governs
R source, so nothing is wrong in the tree. The builder's sentence is.
Recorded, not a finding.

## Step 2 — tolerance integrity

No tolerance in this PR is looser than `test-spec.md` §Tolerances specifies.

| Assertion | Tolerance in tree | Test-spec row | Verdict |
|---|---|---|---|
| `survey`'s stored scale, both oracle blocks | `1e-8` | SE / variance | equal |
| Point estimate, both oracle blocks | `1e-10` | point estimate | equal |
| Standard error, both oracle blocks | `1e-8` | SE / variance | equal |
| Both confidence bounds, both oracle blocks | `1e-6` | CI bounds | equal |
| Nonprob-to-replicate SE ratio | `1e-8` | SE ratio → SE / variance | equal |
| Polychoric `r` equality | `1e-10` | point estimate | equal |
| Fisher-z half-width ratio | `1e-8` | see below | equal or tighter |

The z-space half-width ratio admits two readings. Read as a ratio of two
standard errors — which is what it is, because the z-space half-width is the
critical value times `se_z` — it takes the SE row, `1e-8`, and the audit's
mapping is exact. Read as a ratio of two confidence bounds it would take
`1e-6`, and `1e-8` is then tighter. Neither reading is a relaxation. The
assertion it replaced was a `ci_low` equality at `1e-6`; the replacement is
tighter and pins a magnitude the equality never did.

## Step 3 — scope discipline

`implementation-plan.md` PR 1 §Files touched names four files. The tree
touches six. The two extra files are
`tests/testthat/test-nonprob-bootstrap-variance.R` and
`tests/testthat/test-analysis-corr.R`, authorised by the user's option-A
resolution of the builder's HOLD in `decisions.md`, with errata E-1, E-2 and
E-3 SETTLED. Not re-argued here.

**What I did check: that nothing else crept in under their cover.** Read both
diffs line by line.

- `test-nonprob-bootstrap-variance.R`: one title, one `n_rep` binding, one
  file-header bullet, one section header, one assertion traded for one, and
  the comment that explains it. The `get_ratios()` `NULL`-versus-`NULL` block
  at line 183 is untouched, which is right — it is issue #292.
- `test-analysis-corr.R`: one title, one `n_rep` binding, one comment block,
  `expect_gt` added, and the `ci_low` equality traded for the z ratio.

No other block in either file changed. No third file appeared. Both blocks
now encode the divergence `spec.md` quality gate 6 and decision D1 require,
in place of the identity they encoded before, and both name D1 in a comment
so a later reader does not file the gap as a defect.

**The two commits.** `125722b` is the builder's. `e8f10de` is the
orchestrator's, four lines, all comment, inside a file already in the write
surface. It closes exactly the gap the builder flagged in
`implementation.md` §Notes for tester — that the z assertion "will fail if
`get_corr()` stops building the polychoric bound on Fisher's z, even with the
scale correct ... but the failure message will not say so." Making it
directly was right: it is a tier-0 change by `github-strategy.md`, it changes
no behaviour, and the gates were re-run on the resulting tree, which is the
tree this review reads. A pipeline rule the edit would have breached — an
orchestrator writing code or a spec — is not in play for a comment.

## Step 4 — CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None", and the audit verdict is
PASS, so there is no tester-classification error to escalate.

Every profile gate has a result. `summary.md` in the gate directory reports
`ALL GATES PASS`, `EXIT=0`, on tree `24f9594`. No gate was skipped: pkgdown
ran, and its skip condition would not have applied anyway, because the write
surface touches `R/`.

Two NOTEs. `checking CRAN incoming feasibility` is pre-approved in
`r-package-profile.md`. `checking for hidden files and directories` is not on
that list; the audit reviewed and accepted it as the `.git` note
`.Rbuildignore` causes, present on the baseline and recorded in
`archive/as-svydesign-bridge/` as unfixable by one PR. I agree, and the count
is unchanged against the baseline. No new NOTE pattern appeared.

**One gate reading, convergent and documented.** `air format --check` fails on
`test-constructors.R` and `test-nonprob-bootstrap-variance.R`. Both fail
identically at the base commit, and every site `air` would rewrite is
pre-existing code outside this PR's hunks. `test-spec.md` §How to read three
gates already narrows this gate to "the files this work touches pass";
`implementation.md` and `audit.md` independently narrow it one step further,
to "the PR's own lines pass", which is the reading
`archive/svydesign-replicate-bridge/` D16 records. Two agents reached the
same reading with the same evidence and neither hid it. Documented deviation,
not an undocumented skip.

## Step 5 — coverage

96.15% at the baseline and 96.15% here, against a 95% floor. No drop, so the
95-to-98 HOLD band does not apply.

The one changed file under `R/` reads 96.63% with three uncovered lines —
414, 1868 and 1959, read from `gate-7-covr.log`. This PR's hunks in that file
are at 601–659 and 843–864. All three uncovered lines sit outside both
ranges and are pre-existing. Every line this PR adds to `R/` is covered, so
the new-code clause does not fire.

## Step 6 — comprehension alignment

`comprehension.md` carries eleven gotchas and six assumptions. Each reaches
`spec.md` or `test-spec.md`.

| Item | Where it lands |
|---|---|
| G1 — `scale = 1` alone loses the per-stratum factor | spec §Why `1` is right for JKn, F-3, E6 |
| G2 — `rscales` shape unchecked | spec E6 |
| G3 — the JKn oracle block's uniform `rscales` | test-spec §Decision — the JKn oracle row keeps a uniform `rscales` literal |
| G4 — the fixture is no real jackknife family | test-spec §What the oracle rows prove, and what they do not |
| G5 — `R = 1` makes the scale infinite | D-1, spec E1, F-4, rows 1.3 and 2.3 |
| G6 — `NA` replicates do not re-derive `scale` | spec §Edge cases, closing paragraph |
| G7 — zero `rscales` with `mse = FALSE` | same paragraph |
| G8 — the FPC cannot reach the factor | F-7, RS-1, FP-1 |
| G9 — the two constructors diverge | F-8, D1's note, rows 3.2 and 4.2 |
| G10 — no `bootstrap.average` equivalent | F-5 |
| G11 — a single-stratum frame hides the defect | spec §Why `1` is right, point 2 |
| A — one replicate per deleted PSU | spec §Why `1` is right, point 1 |
| A — the caller knows `n_h` | F-7's symbol key and provenance clause |
| A — with-replacement or negligible fraction | F-3, F-7, decision D-2 |
| A — `mse` is out | spec §Out, decision D-3 |
| A — degrees of freedom stay at `Inf` | spec §Out, test-spec rule 4's precondition |
| A — the change is not backward compatible | spec §A runtime transition signal was weighed and declined, and the NEWS migration note |

No gotcha and no assumption is unaccounted for.

## The three things the dispatch asked me to judge

### The two switch-line comments carry their facts, as pointers

The JKn comment at `R/core-constructors.R` carries all four facts of
`spec.md` §The two switch lines — the estimator's name, the factor belonging
in `rscales`, `(R-1)/R` naming `"JK1"` only, and `survey`'s `1` with the
pointer to `@param scale` for the formula and its with-replacement condition.
It writes out neither `q_h` nor the correction, so it is a pointer and not a
derivation, which is what D-8 requires.

The bootstrap comment carries all three — `survey`'s
`bootstrap.average / (R - 1)`, the missing argument making the line always
`1 / (R - 1)`, and `as_survey_nonprob()` keeping `1 / R` by D1 with the
pointer. Also a pointer.

Every line of both comments is inside 80 columns; the longest added line in
that file is 75.

### The `@param scale` rewrite delivers F-1 to F-8, RS-1 and FP-1

Read against the roxygen diff rather than against the audit's table. All ten
observables land, and the two that could have gone wrong did not: F-5 states
the missing argument and the preserved scale in both directions, and makes no
claim that a `bootstrap.average != 1` design cannot round-trip — the claim
measurement M4 falsified. F-8 names the other constructor, its value and the
decision clause, and carries no percentage, which row 4.1 calls a second copy
and a finding.

One removal worth naming, because no artifact mandated it: the old `fpc`
sentence "Used by some replicate methods to adjust the variance estimator"
is gone. FP-1 contradicts it, so leaving it would have shipped two opposite
statements in one block. The builder recorded the removal in
`implementation.md` §Summary. Correct call.

### The Fisher-z assertion is sound, in scope, and adequately warned

**Sound.** The polychoric bound is built symmetric in `z`, and `se_z` scales
with the square root of the stored `scale`. So the ratio of the two z-space
half-widths is `sqrt(scale_np / scale_rep)`, which is
`sqrt((1/R) / (1/(R-1)))`, which is `sqrt((R-1)/R)` exactly. The r-space
ratio cannot be exact, because `tanh` is not linear, and the builder's
`7.8e-05` miss is the size that non-linearity produces on this fixture. The
builder measured both readings before choosing, rather than assuming either.
That is the right order of work.

One property the assertion leans on that no comment names: the block computes
`z <- atanh(result_nonprob$r)` and uses that one value in both the numerator
and the denominator. That is valid only because `r` is identical on the two
sides. It is asserted two lines above at `1e-10`, not at `tolerance = 0`, so
the premise is guarded but not exactly. A drift of `1e-10` in `r` would move
the ratio by about `1e-10`, two orders inside the `1e-8` the ratio carries,
so the assertion cannot pass on a broken premise. No action; recorded so a
later reader does not have to re-derive it.

**In scope.** It sits inside a file the settled errata authorise, inside the
block E-1 names, and it replaces the assertion the default move broke. The
minimum retarget was `expect_gt` alone, which fixes a direction and no
magnitude. The arc's own measurement — P2 in `archive/replicate-oracle-tests/`
— is that a block asserting no magnitude reports green on a wrong scale, and
that is how issue #242 survived 22 releases. Adding the magnitude is the arc
applying its own finding, not scope creep.

**Adequately warned, after `e8f10de` and not before.** The builder's comment
recorded the measurement and the reason the r-space ratio misses. It did not
say what a later reader does when the block turns red. The orchestrator's
three lines say it: if `get_corr()` moves off Fisher's z the ratio stops
holding and the block turns red with no scale defect behind it, so read the
CI construction before the scale. That is the same shape as the
degrees-of-freedom clause in `.claude/rules/testing-surveycore.md`, and the
gap is now closed.

## PR 4 needs no re-scoping

PR 4's AC-4, from test-spec row 3.2, now overlaps PR 1's new nonprob
assertion. The overlap is partial and the two should both stay.

- Row 3.2 carries two claims. The first — the replicate design stores
  `1 / (n_rep - 1)` and the nonprob design stores `1 / n_rep`, each against
  its own literal — appears nowhere else in the arc. Only PR 4 has it.
- The second claim, the SE ratio at `sqrt((n_rep - 1) / n_rep)`, is now
  asserted twice: in `test-constructors.R` on a `make_survey_data` frame by
  PR 4, and in `test-nonprob-bootstrap-variance.R` on a
  `.make_nonprob_rep(n = 200, R = 20, seed = 42)` frame by PR 1. Different
  files, different fixtures, same mathematical claim.

Deleting PR 4's copy would cost row 3.2 its stored-scale half unless PR 4's
builder splits the criterion, which is more churn than the duplicate costs.
Deleting PR 1's copy would leave the nonprob block asserting the point
estimate alone — the exact shape P2 proved worthless against a scale defect.
So keep both.

What PR 4 should do is cheap and worth doing now: its builder writes one
comment naming the sibling assertion in
`tests/testthat/test-nonprob-bootstrap-variance.R`, so a later reader who
changes one finds the other. That is a note to add to PR 4's task list, not
a re-scope, and it needs no erratum.

## Findings — none blocking

**F-A — the errata set is one item short, and PR 5 is where it bites.**
E-1, E-2 and E-3 widen the file list. They do not reach two closed-set
clauses that the same widening makes unreachable:

- `test-spec.md` row 4.4: "confirm the diff touched no other line holding
  either literal". The two new assertions in the extra files each hold
  `sqrt((n_rep - 1) / n_rep)`, which contains the literal
  `(n_rep - 1) / n_rep`. Six changed lines carry one of the two literals;
  row 4.4's wording admits only two shapes and four of the six are neither.
- `implementation-plan.md` PR 1 AC-5, which repeats the same clause.

`audit.md` found this, listed all six lines, accounted for each, and recorded
it as a documented deviation rather than a pass with a violation. That is the
right classification and it is why this is a finding and not a BLOCK — the
behaviour is correct, the deviation is measured, and no agent can fix a
wording defect by writing code. Recommend the orchestrator record it as E-4
in `decisions.md` before PR 5 runs, on the same reasoning E-3 gives: a closed
count stated in one artifact that another artifact's prose makes unreachable
becomes a tester BLOCK if nobody writes it down first. This is the same shape
as D12 and D16 in `archive/svydesign-replicate-bridge/` and S3, S6 and N3 in
`archive/replicate-oracle-tests/`.

**F-B — `implementation.md`'s 80-column claim overreaches.** Covered under
Step 1. The tree is clean; the sentence is not. No action beyond the record.

**F-C — the `z` premise guard.** Covered under the Fisher-z judgment. No
action.

## Decision

PASS. All seven checks are clean: the spec's contract items for this PR reach
audit rows, `test-spec.md` covers the spec, no tolerance is looser than
specified, the write surface matches the plan plus two files a settled user
decision authorises and nothing more, the CRAN cookbook scan is empty with a
PASS audit behind it, every profile gate has a result with its one narrowed
reading documented in both artifacts, coverage holds at 96.15% with every
added `R/` line covered, and every comprehension gotcha and assumption lands
in the spec or the test-spec. `audit.md`'s verdict is PASS and I agree with
it. The three findings above are records for later readers; none of them
changes what ships.
