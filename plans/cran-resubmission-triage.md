# CRAN resubmission triage

**Date:** 2026-09-09 (rewritten; first written earlier the same day)
**Base:** `develop` at `dbff0d9`
**On CRAN:** 1.1.0
**Development version:** 1.1.0.9000
**Open issues:** 21 (was 24; see `plans/issue-cleanup.md`)

> **Corrected 2026-09-09 by `plans/issue-cleanup.md`.** That file locks the
> decisions this one left open, closes four issues and rewrites twenty. Read it
> for the PR order. This file answers only "what blocks CRAN". Every section
> below carries its correction inline.

Open issues ranked by what blocks the next CRAN submission.

The test for tier 1 is one question: does an exported function return a wrong
number without saying so? A silent wrong answer is worse than an error, because
nothing tells the analyst to look.

**What changed since the first version of this file.** Issue #257 audited all
nine replicate types against `survey::svrepdesign()` and filed five new issues.
The replicate-scale cluster grew from three issues to seven, and one of the new
ones (#255) is a different defect from all of them. #233 shipped as PR #252.

---

## The replicate-scale cluster — read #257 first

#257 is the tracking issue. It holds the audit, the verdicts against the
literature, and the account of how the defaults were never specified. Its
central finding is good news:

> The variance estimator is correct and type-agnostic. Given the same `scale`,
> `rscales` and `mse`, surveycore and `survey` return the identical standard
> error for every type `survey` does not override, to 1e-8. Every divergence
> found is in the default-scale lookup, or in what happens to an explicit
> scale. None is in the formula.

Nine types, default `scale`, n = 60, R = 8, seed 11, `mse = TRUE`, survey 4.5:

| Type | surveycore | `survey` | Status |
|---|--:|--:|---|
| JK1 | 0.875 | 0.875 | agree |
| JK2 | 0.875 | 1 | #242 — fix written, not landed |
| JKn | 0.875 | 1 | #253 |
| BRR | 0.125 | 0.125 | agree — was 1/4, fixed in PR #14 |
| Fay | 0.125 | 0.25510204 | #243 |
| bootstrap | 0.125 | 0.14285714 | #254 — document, do not change |
| ACS | 0.5 | 0.5 | agree — was 1/R, fixed in PR #150 |
| successive-difference | 0.5 | 0.5 | agree — was 2/R, fixed in PR #150 |
| other | 1 | 1 | agree |

Every divergent row differs by `sqrt((R-1)/R)`, except Fay, whose error is
`(1 - rho)`.

**Why 22 releases missed this — #256.** The oracle tests pass surveycore's own
`scale` into `survey::svrepdesign()` for exactly the four types where `survey`
would otherwise compute its own, so the comparison is a round trip that cannot
disagree. `survey` overrides the caller's scale for BRR, Fay, JK2, ACS and
successive-difference, and uses it for JK1, JKn, bootstrap and other. Every
default corrected so far was in the first group, caught by that override. Every
default still wrong is in the second group, or had no test at all.

---

## Tier 1 — blockers: exported functions return wrong numbers, silently

### #242 — JK2 default scale `(R-1)/R`, should be 1

`R/core-constructors.R:794-796` groups JK2 with JK1 and JKn and gives all three
the delete-one factor. `survey` fixes JK2 at 1; `as_survey_nonprob()` already
uses 1. Every JK2 design that leaves `scale` at its default reports an SE 6.5%
low at R = 8.

**Corrected: the fix is pushed and PR #258 is open.** It carries the source
change, the roxygen, the regenerated `man/` page, 121 lines of new tests, and
`changelog/fix-jk2-default-scale.md`. Two things to settle before it merges:
its new `@param scale` text gives the wrong reason for the right value (#260,
and D3), and the `NEWS.md` question below.

This blocks more than itself: #253, #254 and #255 all record their measurements
as "on this branch, with #242's fix applied", so none of their numbers
reproduce from `develop` until it lands. Push it first.

One open point on that branch: it edits `NEWS.md`, which
`.claude/agents/builder.md:138` and `.claude/agents/shipper.md:195` both forbid
inside a PR. Its entry is a well-written breaking-change migration note. Decide
between keeping the entry and correcting the two contracts — which five recent
PRs already contradict — or moving the text into the fragment for `/merge-main`
to lift. Keeping it is the better answer: the person who measured the change
writes a better note than the release step can reconstruct.

### #253 — JKn default scale `(R-1)/R`, should be 1

The same defect one line down the same switch. The stratified jackknife puts
`(n_h - 1) / n_h` in `rscales`, per stratum, and leaves the overall scale at 1.
R is the sum of `n_h`, so `(R-1)/R` matches only in a single-stratum design,
which is JK1. No design makes it right (Wolter 2007, chapter 4).

Measured: `survey` 0.100066639203, surveycore 0.0936037699363, ratio
`sqrt((R-1)/R)`.

**Ship this with #242, in one PR.** They are adjacent lines in one switch, both
breaking by the same factor, and they share a migration note. #257's suggested
order pairs #253 with #244 instead; that reasoning holds for #244, but
splitting #242 from #253 buys two breaking releases for one switch.

### #243 — `type = "Fay"` computes BRR

surveycore has no `rho` anywhere in its design code and sets Fay's scale to
1/R, which is BRR's. A Fay design and a BRR design built from the same columns
return `identical()` SEs, and nothing records that Fay was reduced to
`rho = 0`. Fay's replicates are shrunk by `(1 - rho)`, so the estimator divides
by `(1 - rho)^2` (Judkins 1990); 1/R omits the divisor entirely.

**This one also reaches package metadata.** DESCRIPTION advertises "replicate
weights (BRR, Fay, jackknife, bootstrap)". CRAN reviewers read DESCRIPTION, and
the Fay claim is not true today.

**Decided: add `rho`, and require it for Fay.** D6 in
`plans/issue-cleanup.md`. `survey` requires it (`svrepdesign.default` lines
10-11), and `survey` is the oracle for this constructor.

That reconciles with PR #250, which made `.as_svydesign_replicate()` recover
`rho` by inverting the recorded scale and registered
`surveycore_error_fay_rho_unrecoverable` as row CB-4. With a stored `rho` the
inversion is redundant: pass `@variables$rho` straight through, delete the
inversion, and remove or restate CB-4. #243's body now carries this.

### #255 — an explicit scale is honoured for the five types `survey` overrides

Not a defaults issue. `survey::svrepdesign()` discards a supplied `scale` and
`rscales` for BRR, Fay, JK2, ACS and successive-difference and computes its
own; `as_survey_replicate()` honours them for all nine. The same explicit
arguments give different standard errors in the two packages, and surveycore
raises nothing. Fixing every default leaves this untouched.

Measured with `scale = 0.6` on both sides: the four use-types agree at
0.09633605611; JK2, BRR and Fay differ.

### #244 — `type = "JKn"` with `rscales = NULL` computes JK1

A stratified jackknife needs one factor per stratum. The fallback at
`R/variance-replicate.R:92` and `:210` fills ones, so the stratification has no
effect. JKn and JK1 return `identical()` SEs. `as_survey_nonprob()` already
refuses this case at `R/core-constructors.R:1167`, so there is a template to
copy and the two constructors currently disagree.

### #245 — `as_svydesign()` drops a filtered design's domain

The converted object answers for the whole sample. **The point estimate is
wrong, not only the standard error** — the only issue on this list where that
is true.

| Call | mean | SE |
|---|--:|--:|
| `get_means()` on the filtered design | 58.176655 | 0.725342 |
| `survey::svymean()` on the converted object | 50.761561 | 0.614837 |
| the same, after `subset()` on the domain column | 58.176655 | 0.725342 |

Row 3 reproduces row 1, so the information crosses the bridge and is never
applied as a restriction.

---

## Tier 2 — fix before submitting, but no wrong number

### #256 — rewrite the replicate oracle tests so a wrong default fails

The methodology fix behind the whole cluster. Ship it before the value fixes,
so #253, #243 and #255 land as failing tests going green rather than as
assertions written after the fact.

### ~~#254~~ — closed into #253; the bootstrap default changes

**Corrected: this is tier 1, and it is not a documentation job.** D5 in
`plans/issue-cleanup.md` moves `as_survey_replicate()` to `1/(R-1)`, matching
`survey` (`svrepdesign.default` line 92). Both conventions are standard —
1/B about the full-sample estimate (Rao, Wu and Yue 1992) and 1/(B-1) about
the replicate mean — but `survey` is the oracle for this constructor, so it
decides.

`as_survey_nonprob()` keeps `1/R` on Wu (2022) and documents the divergence
(D1). `survey` has no non-probability design class, so it is not an oracle for
one. #254 closed into #253, which ships both changed defaults under one
migration note.

### #251 — a replicate `fpc` does nothing, and gets refused

**Corrected: this is not the documentation half of PR #249.** `survey` *does*
apply a replicate FPC — `rscales <- rscales * fpc` at
`svrepdesign.default` line 146, for JK1, JKn and `other` — and refuses it for
the other six types. surveycore's is inert for all nine, so "the field changes
no standard error" is the divergence rather than a fact to document.

D12 refuses the argument. It stays tier 2 — no caller's number moves, because
the field has never affected a replicate SE in any release — but the scope
grows to five files, and PR #249's warning plus two dead print branches come
out with it.

Measured: `R/variance-replicate.R` holds zero occurrences of `fpc`, and the SE
is `identical()` with and without the field.

### #248 — S7 validators do not repeat the constructors' checks

`@data <-` after construction installs a 1-row frame, a 0-row frame, or a zero
weight. Construction refuses all three on every class. Runs against "design
variables are sacred" in `CLAUDE.md`.

### #237 — `as_svydesign()` refuses a `survey_nonprob` design

**Corrected: PR #259 is open**, on `fix/as-svydesign-bridge`. Merge it before
#248 answers its weight-sign question — PR #259's `make_nonprob_zero_wt()`
fixture depends on the current permissiveness. Write surface:
`R/methods-conversion.R`, `plans/error-messages.md`, `test-conversion.R`,
`_snaps/conversion.md`, `vignettes/surveycore-vs-survey.Rmd`, a changelog
fragment, and two `man/` pages.

---

## Tier 3 — CRAN-check-adjacent hygiene

- **#218** — no test runs with `haven` genuinely absent. CRAN has a
  no-Suggests flavor. The runtime guard `.haven_available()` is correct; the
  branch it guards is never exercised.
- **#235** — `length()` returns 1 while `length(names(x))` returns the column
  count. The last loose end from #203.

---

## Not CRAN work

| Issue | Why it waits |
|---|---|
| #246 | Eight duplicated routing tests want a shared helper — internal |
| #234 | `nocov` markers with a wrong stated reason — coverage hygiene |
| #200 | No k x k covariance matrix — enhancement, driven by surveywts |
| #199 | `get_totals()` rejects factors — enhancement |
| #183, #182 | Analytic influence function for polychoric — performance |
| #180 | `test-dataset-metadata.R` section numbering — test hygiene |
| #167 | 256 unasserted small-cell warnings — test hygiene |
| #165 | `pipeline-ship` PR dispatch — pipeline tooling |
| ~~#184~~ | Closed 2026-09-09. `covr::package_coverage()` completes on `develop` at `dbff0d9`: 96.2397%, exit code 0 |
| ~~#183~~ | Closed 2026-09-09. Superseded by #182 |

---

## Order

Superseded by the PR map in `plans/issue-cleanup.md`, which #257 now carries.
Repeated here for the CRAN reader:

1. **PR 1 — #256.** The oracle-test rewrite, so the rest land as red going
   green.
2. **PR 2 — #242, with #260.** PR #258 is open. Settle the roxygen and the
   NEWS.md question on the way through.
3. **PR 3 — #253.** JKn and bootstrap defaults, one migration note with PR 2.
4. **PR 4 — #243.** Fay gets a required `rho`; PR #250's inversion retires.
5. **PR 5 — #255.** Per-type argument handling, including #244's JKn refusal.
6. **PR 6 — #251.** The `fpc` refusal.
7. **#245** — after PR #259 merges, because both write
   `R/methods-conversion.R`.
8. **#248** Part 1, then Part 2's decision, then #234.
9. Tier 3, then the backlog by the trigger in each issue.

#242, #253 and #254 each move published numbers. Ship them in one release with
one migration note rather than three.

**Parallel-safe while the #237 worktree runs:** #235, #234, #218. Avoid #167,
which reaches `test-conversion.R`, and anything that appends to
`plans/error-messages.md`, the one file the #237 plan flags as exposed.

---

## Release steps, after the tiers above

1. Write the changelog fragment for every arc. `/merge-main` drafts the NEWS.md
   section from `changelog/` fragments added since the last tag, so a PR with
   no fragment is invisible to the release notes. Three were backfilled on
   2026-09-09 in `40700e3`.
2. Close #257 when every row of its audit reads "agree" and a test pins it.
3. Re-check DESCRIPTION's Description field against what the package does. The
   Fay claim is the known case; #257's account suggests reading the whole field
   against the code.
4. `R CMD build .` then `R CMD check --as-cran` on the tarball.
5. `devtools::check_win_devel()` at minimum.
6. Version bump, then `cran-comments.md`. The current file is written as a
   resubmission of 1.0.0 and needs rewriting for this release.
