# Review — PR 0 — nonprob-domain-se-correction

**Verdict**: PASS
**Date**: 2026-09-10 13:16
**Branch**: `fix/nonprob-domain-se-correction` @ `3a9b2c8`
**Tree reviewed**: `34b15df1bd90b6611df9c48bfb42dfa03eaa4e98` — equals the tree
`audit.md` records, and equals `git rev-parse 'HEAD^{tree}'` now. The gates ran
on the code I read.

## What stands in for the missing artifacts

PR 0 is not in the frozen plan. There is no `spec.md` and no `test-spec.md` for
it. The authority I reviewed against is:

- `decisions.md` — the PR 1 HOLD of 2026-09-10 18:05, its Resolution (option 2),
  and D15, D16, D17.
- `.claude/rules/testing-surveycore.md` §Variance estimation numerical
  tolerances, for the tolerance figures.
- `r-package-profile.md`, for the gate table and the pre-approved NOTEs.

`audit.md` was written by the orchestrator, not a tester agent. It says so in
its own header. See §Does orchestrator-written audit weaken the case.

## Convergence checks

| Check | Result |
|---|---|
| Authority coverage — every claim D15 makes is pinned by a test | y |
| Test coverage of the authority — every domain size D15 cites has a block | y |
| Tolerance integrity — SE 1e-8, point 1e-10, nothing looser | y |
| Scope discipline — write surface matches the brief exactly | y |
| Regression safety — no test outside PR scope changed state | y |
| Profile gates — all seven have a result, no skip | y |
| Coverage floor — 96.25%, above 95%, and rose 0.01 | y |
| `audit.md` verdict | PASS |

## 1. Write surface

Two files, as the brief closes it to:

```
9	2	R/analysis-means-helpers.R
153	0	tests/testthat/test-analysis-means.R
```

`git diff develop...HEAD --quiet` reports no change for `NAMESPACE`, `NEWS.md`,
`DESCRIPTION`, `man/` or `plans/error-messages.md`. All five are byte-identical
to `develop`. `tests/testthat/_snaps/` has zero files in the diff.

The test file has **0 deleted lines**. Both deletions in the diff are in the R
file — the old comment line and the old `var_ybar` line. No existing test was
edited, weakened or removed, and no snapshot drifted. That is the single
strongest integrity signal in this PR: the fix moves a published number and it
did so without touching one pinned assertion, because nothing anywhere pinned a
filtered or grouped non-probability SE. D15's blast-radius paragraph says
exactly that, and `logs/blast-radius/test.log` confirms it — one failure,
`test-conversion.R:3181`, which is PR 1's own ratio-identity block.

## 2. Is the production change minimal and correct

The whole hunk is one added variable, one rewritten expression, and a six-line
comment. Lines 327-328:

```r
  n_full <- nrow(data)
  var_ybar <- (n_full / (n_full - 1L)) * sum(w_sub^2 * (y_sub - ybar)^2) / N_d^2
```

`data <- design@data` is the first line of `.calibrated_mean_cell()`, so
`nrow(data)` is `nrow(design@data)` — the quantity the brief names.

Checked and unchanged:

- The `n_d == 0L` early return (lines 291-299) — untouched.
- The `n_d == 1L` early return (lines 308-316) — untouched.
- `se_srs` still reads `n_d`, in both the `s2` divisor and the `sqrt(s2 / n_d)`
  (lines 331-336). Correct: `se_srs` is the SRS-equivalent for the design
  effect, a different estimand, and it should stay on the domain count.
- `n = n_d` in the returned list — untouched.
- No other function in the file moved. The diff is one hunk.

The consistency claim in the new comment holds. `.taylor_mean_cell()` at line
52 reads `n_full <- nrow(data)`, and `.twophase_mean_cell()` at line 252 reads
`n_total <- nrow(data)`. All three cell functions now take the count from the
full frame. Before this PR the calibrated one was the odd one out.

## 3. Do the tests pin the claim, or restate it

They pin it. Two independent reasons.

**The named guard exists and does what the builder claims.** Block 2,
"get_means() calibrated domain SE rejects a domain-sized correction factor
[oracle]", computes the domain-factor SE in closed form from the same rows:

```r
  se_domain_factor <- sqrt(
    (n_d / (n_d - 1L)) * sum(w_d^2 * (y_d - ybar)^2) / nhat^2
  )

  expect_equal(sc_est$se[[1L]], sv_se, tolerance = 1e-8)
  expect_gt(abs(se_domain_factor - sv_se), 1e-8)
```

The pair is the right shape. The first assertion pins the shipped value to the
oracle; the second proves the two candidate factors are distinguishable at that
tolerance, which is what stops the first from passing vacuously. Re-base the
factor on the domain and the first assertion fails.

**Block 1 fails independently.** It runs domain sizes 50, 20, 10, 5 and 2 of
100. At 2 of 100 the two factors differ by 40.7% (`implementation.md`
§Parity measurements). A re-base breaks five SE assertions there before block 2
is reached. The guard is redundant, which is the correct amount of redundancy
for a term someone might "simplify" later.

One note, not a finding. `expect_gt(abs(...), 1e-8)` is an absolute comparison
while `expect_equal(tolerance = 1e-8)` is relative in testthat 3e. On an SE of
3.59 the relative tolerance admits an absolute difference of about 3.6e-8, so
in principle a value could satisfy both. The actual difference is 0.404 — seven
orders of magnitude clear — and block 1 covers the same ground, so there is no
practical exposure. Worth knowing if anyone later shrinks the margin.

**The blocks ran; they did not skip.** Arithmetic: block 1 gives 5x3 = 15
expectations, block 2 gives 2, block 3 gives 3x2 = 6, block 4 gives 3, block 5
gives 3 — 29 total. `audit.md` Before/After records 11606 to 11635, exactly
+29, and SKIP stays at 4 in both runs. Every new assertion executed and passed.
A `skip_if_not_installed("survey")` that had fired would have shown as a higher
skip count and a lower expectation count.

## 4. Oracle shape

Correct in all five blocks, and no rebuilt-design oracle appears anywhere:

```r
  sv <- survey::svydesign(ids = ~1, weights = ~wt, data = df)
  sv_est <- survey::svymean(~y1, subset(sv, dom))
```

`svydesign()` always receives the **full** `df`; the restriction is applied
afterwards by `subset()`. That is the shape D15 ground 3 requires:
`[.survey.design2` subsets `design$fpc$sampsize` by row and never recomputes
it, so each retained row still carries the full sample's count. A design built
on `df[df$dom, ]` would recompute `sampsize` from the retained rows, reproduce
the domain factor, and pass vacuously. It is not present. Block 3 does rebuild
`sv` inside its loop, but from the whole `df` each time, then subsets on `sel`
— that is the same correct shape, not a rebuild on filtered rows.

## 5. Tolerance integrity

No violation. No relaxation anywhere.

| Assertion class | Used | Rule figure | Verdict |
|---|---|---|---|
| SE | `tolerance = 1e-8` (5 sites) | 1e-8 | equal |
| Point estimate | `tolerance = 1e-10` (5 sites) | 1e-10 | equal |
| Row counts `n` | `expect_identical()` | exact | tighter than required |

No hand-computed value is used as an expected value where the oracle was
available. Block 2's `se_domain_factor` is hand-computed and used only as a
negative control; the positive assertion in the same block goes to the oracle.
Block 4's `n_complete` is a row count, not an estimand, and is asserted with
`expect_identical()`.

`suppressWarnings()` wraps each `get_means()` call. That is the pre-existing
pattern in this file — four sites on `develop` at lines 939, 944, 1014 and 1032,
all oracle-comparison blocks. The two warnings involved
(`surveycore_warning_nonprob_srs_fallback` and the AAPOR small-cell warning) are
covered elsewhere, and the run's warning count holds at 256 before and after, so
the suppression hides nothing new. Blanket suppression is weaker than
`expect_warning(class = )`, but these blocks assert numbers and the rule reserves
the typed form for blocks that assert warnings.

The direct `sc@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- ...` assignment is
also the house pattern, not a novelty: 18 pre-existing sites across
`test-analysis-means.R`, `test-analysis-freqs.R` and `test-analysis-corr.R`.
`SURVEYCORE_DOMAIN_COL` is exported (`NAMESPACE:41`).

## 6. Profile gates and CRAN cookbook

Every gate has a result. Nothing skipped — pkgdown ran, correctly, because the
write surface touches `R/`. I read the logs rather than re-running.

| Gate | Result | Log evidence |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; `man/` and `NAMESPACE` identical to `develop` |
| `devtools::test()` | PASS | `FAIL 0`, `WARN 256`, `SKIP 4`, `PASS 11635` |
| `devtools::run_examples()` | PASS | no error lines; matches on "Error" are printed factor levels and column headers |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` |
| `pkgdown::build_site()` | PASS | "Finished building pkgdown site" |
| `covr::package_coverage()` | 96.25% | baseline 96.24% |

Both NOTEs are accounted for. `checking CRAN incoming feasibility` is
pre-approved in `r-package-profile.md`. `checking for hidden files and
directories` — found `.git` — is pre-existing and caused by `.Rbuildignore`;
`archive/as-svydesign-bridge/` records the same NOTE under AC-6 for the same
reason. No new NOTE pattern appeared, so no escalation is due.

CRAN cookbook: `audit.md` reports clean on both changed files, and its verdict
is PASS. Consistent — a PASS audit with violations would itself be a STOP.

## 7. Coverage floor

96.25% against a 96.24% baseline. Above the 95% floor, and up, not down.

The two lines this PR adds are both covered. I verified the three uncovered
lines in the changed file are outside the diff:

| Line | Content | Status |
|---|---|---|
| 180 | `return(list(` in the `.nonprob_rep_na_warn()` branch | pre-existing |
| 268 | the `0` in `se_srs`'s `else` arm, `.twophase_mean_cell()` | pre-existing |
| 336 | the `0` in `se_srs`'s `else` arm, `.calibrated_mean_cell()` | pre-existing |

Lines 268 and 336 are unreachable: `n_d == 0L` and `n_d == 1L` both return
early, so `n_d >= 2L` always holds by the time `se_srs` is computed. They are
dead branches carrying no `# nocov` comment, which
`.claude/rules/testing-standards.md` asks for. Both pre-date this PR and neither
is in its write surface. Recorded, not charged to this PR.

## 8. Does anything exceed what D15 authorises

No. D15 authorises one change: take the finite correction in
`.calibrated_mean_cell()` from `nrow(data)` in place of the domain count. The
diff is that change, its comment, and five test blocks that pin it. No new
function, no new argument, no new warning class, no signature change, no
behavioural change to any other branch. Scope discipline is clean.

## 9. D17 — legitimate deferral, but the reasoning is not the strongest one

I agree with the outcome and disagree with one of its grounds.

D17 keeps `se = NA_real_` for a one-row calibrated domain where `survey`
returns `0`. The deferral is legitimate, for reasons D17 states correctly:

- Nothing regresses. The branch returned `NA` before the fix and returns `NA`
  after it. Behaviour on that path is unchanged.
- An existing block pins it — "get_means() calibrated single-row domain returns
  mean with NA se (covers n_d=1 path)" — and that block is untouched.
- None of PR 0's parity blocks reaches `n_d == 1L`; the smallest domain is 2.
- `spec.md` §Edge cases already assigns downstream estimation on a
  single-marked-row conversion to `survey`.

Where I push back: ground 2, "`NA` is the more honest report", is the weaker
argument, and the stronger counter-argument goes unanswered. The real issue is
not parity with `survey` — it is internal consistency, which is the principle
D15 itself invokes ("it makes the non-probability path behave exactly like
`.taylor_mean_cell()` under every operation"). `.taylor_mean_cell()` has **no**
`n_d == 1L` early return. It computes through. So after this fix the calibrated
path and the Taylor path agree on the variance factor and still disagree on a
one-row domain, in the one place the fix just made comparable.

That does not change my verdict. It does change what the follow-up should ask.
Frame the issue as "what does a one-row domain report, on every cell function"
— not as "should we match `survey`" — and have it settle
`.taylor_mean_cell()`'s answer at the same time. Deciding the calibrated path
alone would leave the two out of step either way.

Two deferrals here carry no issue number: D17, and both findings in D16 (the
`degf()`/factor distinction, and the Taylor path's latent `subset()` gap at
`R/utils.R:1081-1097`). D16 says one of them "needs its own issue" and names
none. The arc's own precedent is to name the number — D3 filed #261, `spec.md`
filed #262, and the neighbouring archive lists four. Unnumbered, these are
likely to be lost when the run directory is archived. That is bookkeeping, not
safety, so it does not bear on the verdict.

## Does orchestrator-written audit weaken the case

Somewhat, and less than it might. Saying so plainly, since the brief asked.

What is genuinely weaker: `audit.md` is not an independent verdict. The
orchestrator resolved the HOLD that authorised the fix, then graded the fix. A
tester agent that had never seen D15 would have been a better check on whether
the tests pin the claim or merely restate the orchestrator's own conclusion.
That is the structural cost of shipping a PR outside the frozen plan.

What compensates, in descending order of weight:

1. **The gates are machine output, not judgment.** I read the logs and every
   figure in `audit.md` reproduces: `FAIL 0`, `WARN 256`, `SKIP 4`,
   `PASS 11635`, `COVERAGE_PCT=96.25`, `Status: 2 NOTEs`, and the three
   uncovered line numbers. The tree hash in `audit.md` matches `HEAD^{tree}`
   now. Nothing here depends on who ran it.
2. **Two measurements, independent in the way that matters.** The builder
   measured on `make_survey_data()` at seeds 701-705 with domains of 50, 20,
   10, 5 and 2 of 100; the orchestrator measured earlier on a hand-built 40-row
   frame at domains of 40, 20, 10, 5, 3 and 2. Different frames, different
   seeds, different domain sizes, same conclusion to 4.44e-16. The builder also
   reports the domain-factor value for every case, so the discriminating
   comparison is on the record and not just the passing one.
3. **The oracle is a third party.** `survey` 4.5 is not either agent's code,
   and D15 ground 3 traces the mechanism through `survey:::onestrat` to
   `design$fpc$sampsize` rather than resting on the numerical agreement alone.
   Ground 2 cites Lumley's own statement of the rule. A wrong fix would have to
   be wrong in a way that `survey`'s source, `survey`'s output and the package
   author's prose all endorse.
4. **The builder was free to refute and said so.** `implementation.md` records
   the premise as "**confirmed**, not refuted", reports a finding the brief did
   not anticipate (the `NA`-row count question, with the four candidate counts
   measured and three of them ruled out), and raised a HOLD against the brief's
   own scope rather than absorbing the one-row discrepancy silently. That is
   the behaviour of an agent testing a claim, not one confirming it.

On balance: the missing tester costs this PR an independent reading of the test
design, and I have supplied that reading myself in §3 and §4 above — which is
the check that was missing, and it comes out clean. It does not cost the PR any
of its numerical evidence.

## Decision

PASS. The write surface is exactly the two authorised files with five
untouched-file checks confirming it; the production change is one term plus a
comment with the `n_d == 0L`, `n_d == 1L` and `se_srs` paths verified intact;
the tests pin the claim against a `subset()`-shaped oracle at the rule's own
tolerances and would fail on a re-base; every gate passed on the tree I read;
and coverage rose. Nothing in the diff exceeds D15.

## Prerequisites for the shipper — not caveats on the verdict

Both sit downstream of review by workflow design, so neither blocks PASS.

1. **Add `changelog/fix-nonprob-domain-se.md` before opening the PR.**
   `.claude/skills/changelog-workflow.md` requires one file per branch, created
   last on the branch, and warns that "a branch that adds no file is invisible
   to the release notes." This fix moves published numbers — every
   non-probability domain and grouped SE from `get_means()` changes, by up to
   40% on a small domain — so it must reach the release notes. The closest
   precedent is `changelog/fix-jk2-default-scale.md` (#258), also a
   numbers-moving fix. Leave `NEWS.md` alone: `.claude/agents/shipper.md:195`
   assigns it to `/merge-main` at the develop→main boundary, which is why
   byte-identical is the right state for it here.
2. **PR 1's builder must rewrite `test-conversion.R:3181`** once this lands. It
   is the ratio-identity block written to record the gap this PR closes, and it
   is the one failure in `logs/blast-radius/test.log`. D15 flags it; noting it
   here so the sequencing is not lost between PRs.
