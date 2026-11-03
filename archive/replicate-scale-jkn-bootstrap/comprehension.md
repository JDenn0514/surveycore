# Comprehension — replicate-scale-jkn-bootstrap

> **On the `[not archived]` marker in this file.** The Wolter chapter 4
> source it cites is an extracted copy of a copyrighted textbook chapter and
> lives outside this repository. It was deliberately not archived here rather
> than lost by the pipeline: copying it into a public GPL-3 repository would
> not be appropriate. The marker is the closer of the two the citation
> checker accepts. The file was present and read in full when the
> comprehension was written.

**Source read in full:** Wolter, K. M. (2007), *Introduction to Variance
Estimation*, 2nd ed., chapter 4 "The Jackknife Method", 2052 lines, at
`C:\Users\jdennen\analysis-sops\knowledge\raw\books\wolter_2007\wolter_2007_ch04_jackknife.md` [not archived].
Section numbers below are Wolter's own. Equation numbers are his.

**Provenance marks.** Every claim carries one:

- `[Wolter §x]` — read from the chapter at that section.
- `[measured-in-repo: path:line]` — read from a file in this worktree.
- `[recalled]` — from GitHub issue #253 or `plans/issue-cleanup.md`, not
  re-measured in this session. No R ran in this session.

**Verdict on the JKn claim: confirmed with conditions.** The conditions are
named in §Formulas F9 and repeated in §Gotchas G1 to G4.

---

## Problem

`as_survey_replicate()` chooses a default variance `scale` from the replicate
`type`. For `type = "JKn"` it stores `(R-1)/R`, where `R` is the number of
replicate weight columns [measured-in-repo:
`R/core-constructors.R:807`]. `(R-1)/R` is the correct overall factor for the
*unstratified* delete-one jackknife [Wolter §4.2.1 eq. 4.2.3, §4.3.1 eq.
4.3.5]. JKn is the *stratified* delete-one jackknife, and its factor is
`(n_h - 1) / n_h` per stratum `h`, not one overall factor [Wolter §4.5 eq.
4.5.3, §4.6 eq. 4.6.4]. The per-stratum factor belongs in `rscales`, one entry
per replicate, which leaves the overall `scale` at `1`. The two factors
coincide when there is exactly one stratum and differ otherwise, so the wrong
default reads as right on a single-stratum frame and understates every
standard error on a stratified one. The bootstrap default is a separate
defect of the same shape: surveycore stores `1/R` where
`survey::svrepdesign()` stores `1/(R-1)` [measured-in-repo:
`R/core-constructors.R:813`; `tests/testthat/test-variance-replicate.R:931`].
The work is to move both defaults to `survey`'s values, which are locked by
D2 and D5, and to state the estimator precisely enough that a builder can
land the two lines and a tester can prove them.

---

## Formulas

### F1 — What surveycore computes today

[measured-in-repo: `R/variance-replicate.R:26-46`]

```
V = scale * SUM_{r=1}^{R} rscales_r * (theta_r - c)^2

c = theta            when mse = TRUE
c = mean(theta_r)    when mse = FALSE, over the r with rscales_r > 0
```

`theta` is the full-sample estimate. `theta_r` is the estimate from replicate
weight column `r`. Replicates whose estimate is `NA` are dropped, together
with their `rscales` entry; `scale` is not re-derived after the drop
[measured-in-repo: `R/variance-replicate.R:28-38`].

### F2 — Wolter, unstratified delete-one-group jackknife

[Wolter §4.2.1 eq. 4.2.3, second form; §4.3.1 eq. 4.3.5]

```
v_1(theta_hat) = ((k - 1) / k) * SUM_{alpha=1}^{k} (theta_(alpha) - theta_(.))^2
```

`k` is the number of random groups. `theta_(alpha)` is the estimate with group
`alpha` deleted. `theta_(.)` is the mean of the `k` deleted-group estimates.
For a linear estimator `theta_(.)` equals the full-sample estimate [Wolter
§4.3.1 Lemma 4.3.1], so the centre is the same either way in that case; for a
nonlinear estimator it is not [Wolter §4.4].

This is the form whose factor is `(k - 1) / k`. With one replicate per group,
`k = R`, so the factor is `(R - 1) / R`.

### F3 — Wolter, stratified delete-one jackknife (Jones's estimator)

[Wolter §4.5 eq. 4.5.3]

```
v_1(theta_hat) = SUM_{h=1}^{L} (q_h / n_h)
                 * SUM_{i=1}^{n_h} (theta_(hi) - theta_(h.))^2

q_h = (n_h - 1) * (1 - n_h / N_h)   for sampling without replacement
q_h = (n_h - 1)                     for sampling with replacement
```

`L` is the number of strata. `n_h` is the sample size in stratum `h` — the
number of PSUs in stratum `h` once the ultimate-cluster rule applies [Wolter
§4.6]. `theta_(hi)` is the estimate with unit `(h, i)` deleted.
`theta_(h.)` is the mean of the `n_h` deleted-unit estimates *within stratum
h*. `N_h` is the stratum size in the population.

The factor is inside the sum over `h`. There is no overall multiplier. This is
the quoted answer to brief item 1.

For probability-proportional-to-size sampling with replacement inside strata,
Wolter writes the same estimator with `q_h = n_h - 1` substituted
[Wolter §4.5, the four estimators after eq. 4.5.8]:

```
v_1(theta_hat) = SUM_{h=1}^{L} ((n_h - 1) / n_h)
                 * SUM_{i=1}^{n_h} (theta_(hi) - theta_(h.))^2
```

**One warning about the source file.** Three lines of the markdown render
this same estimator with an extra `/ 2` on the squared deviation: the `v_1`
display at chapter line 1419, and both lines of the eq. 4.5.7 block at
chapter lines 1426 and 1427. That is an OCR artifact of the fraction, not a
factor. Eq. 4.5.3 at chapter line 1335 carries no such term, and Wolter's own
reduction at `n_h = 2` confirms it: he writes
`v_1(R_hat) = SUM_h (1/2) SUM_i (R_hat_(hi) - R_hat_(h.))^2`, where
`1/2 = q_h / n_h` and nothing else [Wolter §4.5 Example 4.5.1, the `n_h = 2`
case, chapter line 1485]. Read eq. 4.5.3 and Example 4.5.1 as the authority,
and ignore all three lines.

### F4 — Wolter, the same estimator for clustered samples

[Wolter §4.6 eq. 4.6.4a]

```
v(theta_hat) = SUM_{h=1}^{L} ((n_h - 1) / n_h)
               * SUM_{i=1}^{n_h} (theta_(hi) - theta_(h.))^2
```

with `n_h` now the number of sample PSUs in stratum `h`, and `theta_(hi)`
computed after deleting the `i`-th ultimate cluster from stratum `h`. This is
the form a survey practitioner implements. Its per-stratum factor and its
replicate construction are what JKn names. Its centre is `theta_(h.)`, so eq.
4.6.4a is Jones's `v_1` in the §4.5 list of four (F6), and surveycore reaches
the same factor with a different centre (F9).

### F5 — Wolter's jackknife replicate weights

[Wolter §4.6 eq. 4.6.7] The replicate weights that produce `theta_(hi)` from
an estimator of the form `Y_hat = SUM w_hij * y_hij` [eq. 4.6.5] are

```
w_(hi)h'i'j = w_h'i'j                    if h' != h
w_(hi)h'i'j = w_h'i'j * n_h / (n_h - 1)  if h' == h and i' != i
w_(hi)h'i'j = 0                          if h' == h and i' == i
```

These are full weights, not adjustment factors. That matches surveycore's
storage convention: surveycore always holds combined replicate weights
[measured-in-repo: `R/variance-replicate.R:51-53`].

Wolter notes that this simple route carries the parent sample's nonresponse
and calibration adjustments into every replicate, and that recomputing the
adjustments per replicate is "technically better" [Wolter §4.6, after eq.
4.6.7]. He runs both routes on the NLSY97 and reports 24 domain estimates. The
two jackknife columns differ by at most 0.06 points: Black non-Hispanic age 19
reads 3.24 without replicate reweighting and 3.18 with it, and Hispanic origin
age 19 reads 3.51 against 3.56 [Wolter §4.7 Table 4.7.1]. The mean standard
error moves from 1.86 to 1.85 and the median stays at 1.51 [Wolter §4.7, after
Table 4.7.1]. Wolter prefers the simple route because the two sets of figures
are so close [Wolter §4.7].

### F6 — The four centring variants, and which one surveycore has

[Wolter §4.5 eqs. 4.5.3 to 4.5.6] All four carry the identical per-stratum
factor `q_h / n_h` and differ only in the centre of the squared deviation:

| Wolter | Centre | Definition of the centre |
|---|---|---|
| `v_1` eq. 4.5.3 | `theta_(h.)` | mean of the deleted-unit estimates within stratum `h` |
| `v_2` eq. 4.5.4 | `theta_(.)` | `SUM_h SUM_i theta_(hi) / n` — mean over all deleted-unit estimates |
| `v_3` eq. 4.5.5 | `theta~_(.)` | `SUM_h theta_(h.) / L` — mean of the stratum means |
| `v_4` eq. 4.5.6 | `theta` | the full-sample estimate |

Wolter's Theorems 4.5.2 and 4.5.3 together give all four the same expectation
to second-order moments of the stratum means: 4.5.3 covers `v_2`, `v_3` and
`v_4`, and 4.5.2 covers `v_1` [Wolter §4.5, the sentence after Theorem 4.5.3].
His observation (iii) orders them
`v_4 >= v_3 = v_2 >= v_1` whenever the `n_h` are roughly equal, and calls
`v_2` and `v_3` conservative relative to `v_1` and `v_4` "very conservative"
[Wolter §4.5, list after eq. 4.5.7].

Mapping to surveycore's `mse` argument:

- `mse = TRUE` centres on the full-sample estimate, which is Wolter's `v_4`
  [F1; Wolter eq. 4.5.6]. Wolter's own worked example uses this centring:
  `v_J(R_hat) = SUM_{h=1}^{108} (1/2) SUM_{i=1}^{2} (R_hat_(hi) - R_hat)^2`
  [Wolter §4.7 Table 4.7.2], where `1/2 = q_h / n_h` at `n_h = 2`.
- `mse = FALSE` centres on the unweighted mean of the replicate estimates,
  which is Wolter's `v_2` [F1; Wolter eq. 4.5.4].
- Wolter's `v_1`, the Jones estimator, is unreachable in surveycore. It needs
  the per-stratum mean, and a `survey_replicate` design records no map from a
  replicate column to a stratum [measured-in-repo:
  `R/core-constructors.R:822-832` — `@variables` holds `repweights`, `type`,
  `scale`, `rscales`, `fpc`, `fpctype`, `mse`, and no stratum]. `survey` is in
  the same position: it requires `rscales` from the caller for JKn with
  combined weights rather than deriving the per-stratum factor itself
  [recalled — D4, `plans/issue-cleanup.md:110-120`].

### F7 — Symbol binding

| Wolter symbol | Meaning | Bound to |
|---|---|---|
| `theta_hat` | full-sample estimate | `full_stat_fn(y, w)`; the `mean` column of `get_means()` |
| `theta_(hi)` | estimate with unit `(h, i)` deleted | the estimate from one replicate weight column |
| `h` | stratum index | not stored on a `survey_replicate` design |
| `i` | unit index inside stratum `h` | not stored |
| `L` | number of strata | not stored |
| `n_h` | sample PSUs in stratum `h` | not stored; enters only through `rscales` |
| `N_h` | population size of stratum `h` | not stored |
| `n = SUM_h n_h` | total sample PSUs | equals `R` when every PSU gets one replicate |
| `k` | number of random groups (unstratified) | `R` |
| `q_h / n_h` | per-stratum factor | `rscales[r]` for every replicate `r` that drops a PSU from stratum `h` |
| `(k - 1) / k` | overall factor, unstratified | `scale` for `type = "JK1"` |
| — | overall factor, stratified | `scale = 1` for `type = "JKn"` |
| `w_hij` | parent-sample weight | the `weights` column |
| `w_(hi)h'i'j` | replicate weight, eq. 4.6.7 | one `repweights` column |
| `R` | replicate count | `length(repweights_vars)`, stored as `n_rep` |

### F8 — The unstratified case, and brief item 3

Issue #253's comment claims that `(R-1)/R` equals `(n_h-1)/n_h` only for a
single stratum, and that a single-stratum design is JK1 and not JKn.

The algebra holds. The chapter gives the two factors — F2's overall
`(k - 1) / k` and F3's per-stratum `q_h / n_h`. It does not mark `L = 1` as
the point where the two treatments meet. The equality is arithmetic from
eq. 4.5.3 and is not stated in the text.

The chapter's one remark about `L = 1` points the other way, and it is about
pseudovalues rather than about the variance factor. Footnote 1 of §4.5 sets
this section's pseudovalue, `theta_hat - (n-1)(1-f)(theta_(i) - theta_hat)`,
against the §4.3 one, which carries `(1-f)^{1/2}`. The two give the same
unbiased estimator for a linear `theta_hat` and do different things for a
nonlinear one: this section's removes bias of order `n^-1` and `N^-1`, and
§4.3's puts a finite-population correction into the variance instead
[Wolter §4.5 footnote 1, chapter lines 1203-1215]. So the footnote contrasts
the two treatments at `L = 1`; it does not join them. At
`L = 1` with with-replacement sampling, `q_h = n - 1` and `n_h = n`, so
`q_h / n_h = (n - 1) / n`. When every PSU supplies one replicate, `n = R`, so
the factor is `(R - 1) / R` — identical to F2's overall factor. For `L >= 2`
and `n_h >= 2`, `R = SUM_h n_h > n_h` strictly. The map
`n -> (n - 1) / n = 1 - 1/n` increases in `n`, so `(n_h - 1) / n_h` is
strictly **less** than `(R - 1) / R` for every `h`. At `n_h = 2` and `R = 4`
the two factors are 0.5 and 0.75. No overall factor reproduces the
per-stratum ones, and the per-stratum ones differ from each other whenever the
`n_h` differ.

The direction of the resulting error, stated once for the whole document. The
old default multiplies the whole sum by `(R - 1) / R`, which is less than 1,
on top of whatever `rscales` the caller supplied
[measured-in-repo: `R/core-constructors.R:807` for the old default, with the
multiply-through step from F1]. A caller who supplies the correct per-stratum
`rscales` therefore gets a variance too small by `(R - 1) / R` and a standard
error too small by `sqrt((R - 1) / R)`. This is the direction the Problem
section and F10 state, and the direction the two oracle ratio assertions
measure [measured-in-repo:
`tests/testthat/test-variance-replicate.R:877-883` and `958-964`]. A caller
who supplies no `rscales` gets a different comparison, which G1 covers.

Two qualifications:

1. The names are not Wolter's. Chapter 4 never writes "JK1" or "JKn". Those
   labels come from `survey::svrepdesign()`'s `type` argument. The chapter
   supports the mathematics of the claim and says nothing about the naming.
2. The coincidence at `L = 1` is exact only for with-replacement sampling, or
   for without-replacement sampling with a negligible sampling fraction.
   Without replacement, `q_h = (n_h - 1)(1 - n_h / N_h)` carries the finite
   population correction and the two factors differ by `(1 - n / N)` [Wolter
   §4.5 eq. 4.5.3; the condition `q_h ~= n_h - 1` is stated in §4.5 before eq.
   4.5.7].

### F9 — Does `scale = 1` plus per-stratum `rscales` reproduce Wolter?

It reproduces two of Wolter's four estimators exactly, under four conditions.
Substituting `scale = 1` and `rscales[r] = q_{h(r)} / n_{h(r)}` into F1 gives

```
V = SUM_{r=1}^{R} (q_{h(r)} / n_{h(r)}) * (theta_r - c)^2
```

This is the double sum over the pair `(h, i)` re-indexed to the single
replicate index `r`. It carries Wolter's per-stratum factor and no overall
multiplier. The centre `c` decides which of his estimators it is:

- `mse = TRUE` gives Wolter's `v_4` exactly [Wolter §4.5 eq. 4.5.6].
- `mse = FALSE` gives Wolter's `v_2` exactly [Wolter §4.5 eq. 4.5.4].
- Neither is Jones's `v_1` [Wolter §4.5 eq. 4.5.3; §4.6 eq. 4.6.4a]. `v_1`
  centres each replicate on the mean of its own stratum, and surveycore
  records no map from a replicate column to a stratum (F6).

The gap between `v_4` and `v_1` is not an edge case. Wolter's observation (i)
states `v_4 >= v_1` for every sample selected [Wolter §4.5, list after eq.
4.5.7]. A worked case that satisfies C1 to C3 below: `L = 2`, `n_h = 2`,
replicate estimates 1, 3, 5, 7, a full-sample estimate of 4, and
`rscales = 1/2` on each replicate. Then `v_1` is `1 + 1 = 2`, and the
expression above with `mse = TRUE` is `(1/2)(9 + 1 + 1 + 9) = 10`, which is
`v_4` on the same numbers.

The default scale is decidable without settling `mse`. Theorem 4.5.3 gives
`v_2`, `v_3` and `v_4` one expectation to second-order moments of the stratum
means, and Theorem 4.5.2 gives `v_1` the same one [Wolter §4.5]. So the
centring changes the number and not the claim of approximate unbiasedness.

The four conditions:

- **C1 — one replicate per deleted unit.** Each replicate column `r` deletes
  exactly one PSU from exactly one stratum `h(r)`, and the columns cover every
  PSU in every stratum, so `R = SUM_h n_h`. Then the double sum over `(h, i)`
  and the single sum over `r` run over the same terms [Wolter §4.5, §4.6].
  Wolter also permits grouping: the `n_h` units may be split into `k` random
  groups of size `m_h`, with `theta_(hi)` defined after deleting the `m_h`
  observations of the `i`-th group from stratum `h` [Wolter §4.5, paragraph
  after Example 4.5.1, chapter line 1492]. That paragraph states no factor for
  the grouped case, and this document states none either. The one grouped
  variant Wolter writes out is a different construction: eq. 4.5.9 deletes
  group `alpha` from every stratum, builds pseudovalues from the `k` group
  estimates, and uses the overall factor `1 / (k(k - 1))` [Wolter §4.5 eq.
  4.5.9]. That variant is not the estimator JKn names.
- **C2 — `rscales` carries the right factor.** `rscales[r] = (n_h - 1) / n_h`
  for with-replacement PSU selection, and
  `rscales[r] = (n_h - 1)(1 - n_h / N_h) / n_h` without replacement when the
  sampling fraction is not negligible [Wolter §4.5 eq. 4.5.3].
- **C3 — the replicate weights follow eq. 4.6.7.** Inflated by
  `n_h / (n_h - 1)` inside the stratum, zero for the deleted PSU, unchanged
  elsewhere [F5].
- **C4 — the centring is stated.** `mse = TRUE` names `v_4` (eq. 4.5.6 and
  the §4.7 worked example) and `mse = FALSE` names `v_2` (eq. 4.5.4). This
  condition fixes which estimator the number is. It is not a further
  restriction on the factor, for the reason given above.

An overall `scale` other than `1` cannot be right under C1 to C3, because the
per-stratum factors are already complete. That is the refutation of the old
default, and it holds whatever the strata look like. The `JKn = 1` conclusion
is confirmed: every form Wolter gives for the delete-one-unit jackknife in a
stratified design puts the factor inside the sum over strata, and none carries
an overall multiplier — eq. 4.5.3 to eq. 4.5.6, eq. 4.6.4a, and the worked
NLSY97 example at Table 4.7.2 [Wolter §4.5, §4.6, §4.7]. The one stratified
form with an overall factor, eq. 4.5.9, deletes a group from every stratum and
is a different estimator (C1).

### F10 — `survey`'s defaults, and the two target values

| Type | surveycore today | `survey` | Target |
|---|---|---|---|
| JKn | `(R-1)/R` | `1` | `1` |
| bootstrap | `1/R` | `1/(R-1)` | `1/(R-1)` |

surveycore's current values: [measured-in-repo:
`R/core-constructors.R:807,813`]. `survey`'s values are pinned by two passing
assertions in this worktree: `expect_equal(sv$scale, 1)` for JKn and
`expect_equal(sv$scale, 1 / (n_rep - 1))` for bootstrap [measured-in-repo:
`tests/testthat/test-variance-replicate.R:855,931`]. The source lines behind
them — `scale <- 1` at deparse line 148 for JKn, with the `rscales` branch at
deparse lines 107-112, and
`scale <- bootstrap.average / (ncol(repweights) - 1)` at deparse lines 88-95
for bootstrap — are [recalled] from D2 and D5 and were measured on `survey`
4.5 under R 4.6.1 on 2026-09-09 [measured-in-repo:
`plans/issue-cleanup.md:56-58` for the method,
`plans/issue-cleanup.md:89,92` for the two line ranges].

Effect on a published number: the standard error rises by
`1 / sqrt((R-1)/R)` for both types, because both moves multiply the variance
by `R / (R-1)`. The existing oracle blocks measure the ratio at `R = 20` as
0.974679434480991 against `sqrt(19/20) = 0.974679434480896` [measured-in-repo:
`tests/testthat/test-variance-replicate.R:877-883,958-964`].

### F11 — The bootstrap divisor: what the chapter does and does not say

Wolter chapter 4 covers the jackknife only. It contains no bootstrap variance
estimator, no bootstrap divisor and no discussion of `1/R` against `1/(R-1)`.
A text search of all 2052 lines returns three near-misses, none of them the
bootstrap: "Wu (1986)" and "Shao and Wu (1989)" at §4.2.4, cited for the
delete-`m` jackknife applied to the sample median, and "Rao (1965), Rao and
Webster (1966), Chakrabarty and Rao (1968), Rao and Rao (1971)" at §4.2.5,
cited for the choice of group count in ratio estimation. None is Rao, Wu and
Yue (1992). **The chapter supports no claim about the bootstrap divisor, and
this document draws none.**

The bootstrap decision rests on two other things, recorded here for
provenance and not endorsed by the attached text:

- D5 in `plans/issue-cleanup.md:122-130`: `survey` is the oracle for
  `as_survey_replicate()`, `survey` uses
  `bootstrap.average / (ncol(repweights) - 1)`, so surveycore moves to
  `1/(R-1)`. `as_survey_nonprob()` stays at `1/R` per D1. [measured-in-repo,
  as a locked decision.]
- The Rao, Wu and Yue (1992) argument recorded in issue #253 — that the `R-1`
  divisor is the divisor of a sample variance over `R` resampled estimates.
  [recalled — no copy of that paper was attached to this run, and no claim
  from it is verified here.]

One structural note that follows from F1 and needs no citation: a divisor of
`R-1` is the unbiased divisor of a sample variance taken *about the sample
mean* of the `R` replicate estimates. surveycore's default `mse = TRUE`
centres on the full-sample estimate instead [measured-in-repo:
`R/core-constructors.R:734`, `R/variance-replicate.R:40-44`], and `survey`
sets the bootstrap scale without consulting `mse` [recalled — D5's line range
88-95 precedes any `mse` branch]. So after the change the `R-1` divisor is
paired with a centre that is not the replicate mean whenever `mse = TRUE`.
This is `survey`'s convention, it is what the oracle rule requires surveycore
to match, and Wolter's Theorem 4.5.3 is the nearest support for treating the
two centrings as interchangeable to second order — for the jackknife, not for
the bootstrap.

---

## Gotchas

- **G1 — `scale = 1` alone loses the per-stratum factor.** F9 holds only when
  `rscales` carries `(n_h - 1)/n_h`. `as_survey_replicate()` accepts
  `rscales = NULL` for every type, stores it as `NULL`, and the variance path
  then substitutes `rep(1L, n_rep)` [measured-in-repo:
  `R/core-validators.R:374-377`, `R/core-constructors.R:827`,
  `R/variance-replicate.R:92`]. After this change, `type = "JKn"` with no
  `rscales` stores `scale = 1` and computes an unweighted sum of squared
  deviations — no jackknife factor at all, in either direction. Today the same
  input at least carries `(R-1)/R`. So this PR, taken alone, makes one input
  worse. `survey` refuses that input outright, and D4 moves
  `as_survey_replicate()` to the same refusal in issue #255, which absorbs
  #244 [measured-in-repo: `plans/issue-cleanup.md:110-120,525-528`]. Name the
  issue and not a PR number: `plans/issue-cleanup.md` contradicts itself on
  the arc's PR order. Its summary table calls #255 PR 4 and #243 PR 5
  [measured-in-repo: `plans/issue-cleanup.md:323-325`], while #255's own
  header says it ships after #243 [measured-in-repo:
  `plans/issue-cleanup.md:511`] and the same file calls #243 PR 4
  [measured-in-repo: `plans/issue-cleanup.md:530`]. The dependency is the
  reliable part: #255 ships after #243. The spec must state that the refusal
  is out of scope here and name the successor issue, so a reviewer does not
  read the window as a defect.
- **G2 — a caller-supplied `rscales` is not checked for shape.**
  `.validate_rscales()` checks length, numeric type, no `NA`, and
  non-negative. It cannot check that the values look like `(n_h - 1)/n_h`
  [measured-in-repo: `R/core-validators.R:374-410`]. Nothing in surveycore or
  `survey` can, because neither stores the strata. Correctness of a JKn
  standard error rests on the caller.
- **G3 — the existing JKn oracle block passes `rscales = rep(1, n_rep)` to
  both sides.** [measured-in-repo:
  `tests/testthat/test-variance-replicate.R:840,849`] That is a legitimate
  oracle comparison of the two implementations, and it is not a test of F9. A
  per-stratum `rscales` literal would test more, but see G4 — the fixture
  cannot support it.
- **G4 — the test fixture builds no real jackknife replicate weights.**
  `make_survey_data(design = "replicate")` sets the column count per type:
  `n_psu %/% 2L` for BRR and Fay, `n_psu` for the three jackknives and the
  bootstrap [measured-in-repo: `tests/testthat/helper-test-data.R:512-521`].
  What is identical across types is the column formula,
  `wt * exp(rnorm(n * R, 0, 0.1))` [measured-in-repo:
  `tests/testthat/helper-test-data.R:522-526`]. No column
  drops a PSU and no column is inflated by `n_h/(n_h-1)`, so the fixture
  violates C1 and C3 of F9. Consequence: an oracle block on this fixture
  proves that surveycore and `survey` agree on
  `scale * SUM rscales_r * dev_r^2` — the interface and the stored default.
  It cannot prove that either side estimates Wolter's `v_4`. The spec should
  not claim statistical validation from these tests, and the test-spec should
  not ask for it on this fixture.
- **G5 — `R = 1` makes the bootstrap scale infinite.** The constructor
  refuses zero replicate columns and accepts one
  [measured-in-repo: `R/core-constructors.R:763-768`; `.validate_repweights()`
  imposes no minimum, `R/core-validators.R:285-330`]. At `R = 1` the new
  default `1/(R-1)` is `1/0 = Inf`. No validator rejects a non-finite `scale`:
  `@variables$scale` is documented as "numeric scaling factor" with no
  finiteness check [measured-in-repo: `R/core-classes.R:604`]. Today the same
  input stores `1`. A variance then reads `Inf`, or `NaN` when the deviation
  is exactly zero. `decisions.md` D-1 settles the behaviour: the constructor
  stores `Inf`. See §Open questions.
- **G6 — `NA` replicates do not re-derive `scale`.** `.svy_rep_var()` drops
  replicates whose estimate is `NA`, and subsets `rscales` to match, but
  leaves `scale` as stored [measured-in-repo: `R/variance-replicate.R:28-38`].
  So a bootstrap design with `R = 20` and 5 `NA` replicates divides by 19 and
  not by 14. This is inherited from `survey:::svrVar`, it is not changed by
  this work, and it should be recorded so a reviewer does not read it as new.
- **G7 — zero `rscales` entries interact with `mse = FALSE`.** The centre is
  the mean over replicates with `rscales_r > 0` only
  [measured-in-repo: `R/variance-replicate.R:43`]. A design with some zero
  entries and `mse = FALSE` centres on a subset. Unchanged by this work.
- **G8 — the finite population correction cannot reach the factor.** Wolter's
  without-replacement `q_h` carries `(1 - n_h / N_h)` [Wolter §4.5 eq. 4.5.3].
  surveycore's replicate `fpc` argument changes no standard error for any of
  the nine types, and D12 decides to refuse it rather than document it
  [measured-in-repo: `plans/issue-cleanup.md:220-241`]. So a caller who needs
  the correction must fold it into `rscales` by hand. The `@param rscales`
  text should say so.
- **G9 — the two constructors diverge on the bootstrap after this change.**
  `as_survey_nonprob()` keeps `bootstrap = 1/R` [measured-in-repo:
  `R/utils.R:1184`], on D1's reasoning that `survey` has no non-probability
  design class. After this PR the same `type` string means a different divisor
  in the two constructors. D1 requires one roxygen sentence naming `survey`'s
  value and the reason surveycore differs. For JKn the two constructors
  *converge*: `.compute_nonprob_scale()` already returns `1`
  [measured-in-repo: `R/utils.R:1184` — the `switch()` that returns the value.
  `R/utils.R:1181` carries the same fact as a comment in the function
  header].
- **G10 — `survey`'s `bootstrap.average` has no surveycore equivalent.**
  `survey`'s bootstrap scale is `bootstrap.average / (R - 1)`, so the two
  sides agree only at `bootstrap.average = 1` [recalled — D5]. Neither side
  of the existing oracle block passes it [measured-in-repo:
  `tests/testthat/test-variance-replicate.R:918-928`]. D5 keeps it out of
  scope and asks for a roxygen note recording the gap in `as_svydesign()`
  round trips.
- **G11 — a single-stratum frame hides the JKn defect.** By F8 the old and new
  factors coincide at `L = 1`. Any check built on an unstratified fixture
  reports agreement either way. This is one reason the defect survived.

### Why no existing test caught either defect

Two mechanisms, both measured:

1. `survey::svrepdesign()` honours a supplied `scale` for JKn, bootstrap, JK1
   and `other` [measured-in-repo: the per-type table in
   `.claude/rules/testing-surveycore.md` §The oracle rule, measured on
   `survey` 4.5 under R 4.6.1]. A block that passes surveycore's stored scale
   into `svrepdesign()` gets the same number back and cannot disagree.
2. `as_svydesign()` passes the stored scale into `svrepdesign()` for every
   type except BRR and Fay [measured-in-repo: `R/methods-conversion.R:372-375`
   builds `scale_arg`, `R/methods-conversion.R:494` passes it]. A test that
   converts a surveycore design and compares it against `survey` is therefore
   a round-trip test, which the oracle rule's §What the rule covers exempts
   [measured-in-repo: `.claude/rules/testing-surveycore.md:277-294`]. It
   proves conversion fidelity and claims nothing about the default. Issue #255
   changes that call site per D10 [measured-in-repo:
   `plans/issue-cleanup.md:534-536`]. D10's own citation of
   `R/methods-conversion.R:166` is stale in this worktree — those lines are
   roxygen prose about a filtered design's domain.

Four JKn numerical tests exist, and each one is silent on the default:

| Test | Where | Why it is silent |
|---|---|---|
| `from_svydesign() matches survey on a JKn factor-form source [numerical]` | `tests/testthat/test-conversion.R:1455`; asserts the SE at 1487 and both bounds at 1488-1489 | It starts from a `survey` design, so surveycore never computes its own default. `from_svydesign()` stores `survey`'s scale [measured-in-repo: `R/methods-conversion.R:1016`]. |
| the JKn oracle block | `tests/testthat/test-variance-replicate.R:806` | It does compare the two defaults, and it does not touch `as_svydesign()`. Three `expect_failure()` wrappers pin the disagreement, so it reports the defect in place of failing on it. |
| `as_svydesign() reproduces surveycore's mean and SE for JKn [numerical]` | `tests/testthat/test-conversion.R:2616` | A round trip by mechanism 2: `as_svydesign()` hands `survey` surveycore's own scale. |
| the nine-type conversion loop | `tests/testthat/test-conversion.R:2636-2663` | It asserts the type string, the class, the replicate column count and the row count. It asserts no number. |

The bootstrap default is covered the same way. Its oracle block at
`tests/testthat/test-variance-replicate.R:886` pins the disagreement with
three wrappers, and the nine-type loop reaches the type without asserting a
number.

The five rules of `.claude/rules/testing-surveycore.md` §The oracle rule, and
what each one requires of the two blocks this work touches:

| Rule | Requirement on the JKn and bootstrap blocks |
|---|---|
| 1 — build both sides from the same inputs | Same frame, same weight column, same replicate columns, same `type`, `mse` passed explicitly to both sides. |
| 2 — pass `scale` to neither side | Neither block may pass `scale`. Both types honour a supplied `scale`, so passing it voids the comparison. Neither block passes it today [measured-in-repo: `tests/testthat/test-variance-replicate.R:834-852,910-928`], so rule 2 is not what these two defects defeated; they survived behind the round-trip route in mechanism 2. Rule 2's recorded casualty is issue #242 [measured-in-repo: `.claude/rules/testing-surveycore.md:181-187`]. |
| 3 — pass `rscales` to JKn only | The JKn block supplies the same literal to both sides, written out twice, never read off a design [measured-in-repo: `tests/testthat/test-variance-replicate.R:840` and `849`]. The bootstrap block supplies none. |
| 4 — assert the standard error, not the point estimate alone | The point estimate is identical under any `scale`. Both blocks must assert the standard error and both confidence bounds. |
| 5 — assert the condition `survey` raises | Both blocks wrap `svrepdesign()` in `expect_no_warning()` today [measured-in-repo: `tests/testthat/test-variance-replicate.R:843` and `920`]; a warning means `survey` computed the value itself. Do not silence it. |

Three further constraints from the same section apply [measured-in-repo:
`.claude/rules/testing-surveycore.md:202-225`]:

- Never assert one side's stored scale against the other side's. Assert each
  against a literal.
- A formula banned from a constructor call is still required in an assertion,
  so `1` and `1/(n_rep - 1)` are the literals the blocks assert.
- Match `survey`'s conditions by message text, not by class. Every condition
  in `svrepdesign()` is a bare `warning()` or `stop()`, so the only class is
  `simpleWarning` or `simpleError`, and that class also matches the "Data do
  not look like combined weights" warning.

The two blocks currently pin the wrong numbers with three
`testthat::expect_failure()` wrappers each, plus one ratio assertion naming
the factor, and each block's comment says to delete four lines when this work
lands [measured-in-repo:
`tests/testthat/test-variance-replicate.R:806-884` for JKn, with the wrappers
at 865, 868 and 871 and the ratio assertion at 879-883;
`tests/testthat/test-variance-replicate.R:886-965` for the bootstrap, with
the wrappers at 942, 949 and 952 and the ratio assertion at 960-964]. Those
wrappers are one of the two sanctioned exceptions named in
`.claude/rules/testing-surveycore.md` §Sanctioned exceptions, and this work
removes that one. The other exception is the Fay block, which uses no wrapper
and compares nothing; issue #243 closes it [measured-in-repo:
`.claude/rules/testing-surveycore.md:299-311`].

---

## Reference mapping

- Wolter (2007) §4.5 eq. 4.5.3 → the per-stratum factor `q_h / n_h` is inside
  the sum over strata, so JKn's overall `scale` is `1` and the factor belongs
  in `rscales`. Confirms issue #253's form. **Primary citation for the JKn
  change.**
- Wolter (2007) §4.5, the four estimators after eq. 4.5.8 → with
  probability-proportional-to-size selection with replacement inside strata,
  `q_h = n_h - 1`, so the factor is `(n_h - 1) / n_h`. This is the form the
  issue quotes.
- Wolter (2007) §4.6 eq. 4.6.4a and 4.6.4b → the same estimator for clustered
  designs, with `n_h` the sample PSU count per stratum. It carries the
  per-stratum factor JKn implements. Its centre is `theta_(h.)`, so it is
  Jones's `v_1` and surveycore reaches the factor with a different centre
  (F4, F9).
- Wolter (2007) §4.6 eq. 4.6.7 → the jackknife replicate weights: zero for the
  deleted PSU, `n_h / (n_h - 1)` inside the stratum, unchanged outside. These
  are full weights, which agrees with surveycore's combined-weights storage.
  Condition C3 of F9.
- Wolter (2007) §4.2.1 eq. 4.2.3 and §4.3.1 eq. 4.3.5 → the unstratified
  factor is `(k - 1) / k`, an overall multiplier. Identifies `(R-1)/R` as the
  right factor for the wrong type, and explains the defect.
- Wolter (2007) §4.5 eq. 4.5.3 at `L = 1` → the two factors coincide for a
  single stratum and only there. Confirms the algebra of issue #253's third
  claim. The coincidence is arithmetic; the chapter does not state it.
- Wolter (2007) §4.5 footnote 1 (chapter lines 1203-1215) → at `L = 1` the
  section's pseudovalue differs from the §4.3 one for a nonlinear estimator.
  It bears on bias removal and on where a finite-population correction
  enters, not on the variance factor. Cited so no later reader takes it for
  authority on the factor.
- Wolter (2007) §4.5 eqs. 4.5.3 to 4.5.6, Theorem 4.5.2 and Theorem 4.5.3 →
  four centring variants, one expectation to second-order moments.
  `mse = TRUE` is `v_4`, `mse = FALSE` is `v_2`, Jones's `v_1` is unreachable.
  Justifies leaving `mse` untouched by this work.
- Wolter (2007) §4.5, list after eq. 4.5.7 → the ordering. Observation (iii)
  gives `v_4 >= v_3 = v_2 >= v_1` only "whenever the `n_h` are roughly
  equal". Without that condition the chapter gives observation (i),
  `v_4 >= v_1`, and observation (ii), `v_3 >= v_2 >= v_1`; the equality
  `v_3 = v_2` needs equal `n_h`, because the fifth term of eq. 4.5.7 then
  vanishes. surveycore's two reachable centrings are the two conservative
  ones under either reading.
- Wolter (2007) §4.7 Table 4.7.2 → a worked stratified jackknife on real data
  with `n_h = 2`: `SUM_h (1/2) SUM_i (R_hat_(hi) - R_hat)^2`. Full-sample
  centring, per-stratum factor, no overall multiplier. The closest thing in
  the chapter to a reference implementation of the target.
- **Wolter (2007) chapter 4 → nothing about the bootstrap.** The chapter
  contains no bootstrap estimator and no divisor. It supports no part of the
  `1/R` to `1/(R-1)` change. Stated here so no later document cites it for
  that purpose.
- `plans/issue-cleanup.md` D1 → `as_survey_nonprob()` is out of oracle scope
  and keeps `bootstrap = 1/R`; each divergence gets one roxygen sentence.
- `plans/issue-cleanup.md` D2 → the nine-type target table. JKn `scale = 1`
  with `rscales` required from the caller; bootstrap `scale = 1/(R-1)` with
  `rscales = rep(1, R)`.
- `plans/issue-cleanup.md` D5 → bootstrap moves to `1/(R-1)` because
  `survey` computes `bootstrap.average / (ncol(repweights) - 1)`;
  `bootstrap.average` stays out of scope and is recorded as a known gap.
- `plans/issue-cleanup.md` D4 → JKn keeps its `rscales` requirement, and the
  refusal of `rscales = NULL` ships in issue #255, not here. Bounds G1. Cite
  the issue and not a PR number: the file contradicts itself on the arc's PR
  order (G1).
- `plans/issue-cleanup.md` D12 → the replicate `fpc` argument is to be
  refused, not documented. Bounds G8.
- `.claude/rules/testing-surveycore.md` §The oracle rule → rules 1 to 5,
  three further constraints, the per-type `scale` and `rscales` table, and two
  sanctioned exceptions. This work removes one of the two: the
  `expect_failure()` wrappers in the JKn and bootstrap blocks. The other
  exception is the Fay block, which compares nothing and belongs to issue
  #243.
- `survey:::svrepdesign.default` → `scale <- 1` for JKn and
  `scale <- bootstrap.average / (ncol(repweights) - 1)` for bootstrap. The
  values are pinned by two passing in-repo assertions; the deparse line
  numbers — 107-112 and 148 for JKn, 88-95 for bootstrap — are [recalled]
  from D2 and D5 [measured-in-repo: `plans/issue-cleanup.md:89,92`].
- Rao, Wu and Yue (1992) → cited in issue #253 for the `R-1` divisor.
  [recalled; not attached to this run and not verified here.] Do not promote
  this to a confirmed citation without reading the paper.
- Wu (2022), Chen et al. (2021) → cited in `as_survey_nonprob()`'s roxygen for
  `bootstrap = 1/R` [measured-in-repo: `R/core-constructors.R:1306-1311`].
  The same two papers appear in a plain `#` comment in
  `.compute_nonprob_scale()`'s own header, which is neither roxygen nor part
  of `as_survey_nonprob()` [measured-in-repo: `R/utils.R:1178`]. These are
  the reason the nonprob constructor does not follow D5.

---

## Assumptions

- **One replicate per deleted PSU.** F9's C1. Nothing in surveycore checks
  that the replicate columns form a complete delete-one family. A design with
  `R` columns that is not such a family gets the same `scale = 1` and no
  warning. The user's request did not state this; the estimator requires it.
- **The caller knows `n_h`.** `rscales` is the only route for the per-stratum
  factor, and the design stores no strata. This makes JKn the one type whose
  default is correct only in combination with an argument the caller must get
  right. `survey` takes the same position and refuses the type when `rscales`
  is absent.
- **With-replacement PSU selection, or a negligible sampling fraction.**
  `(n_h - 1)/n_h` is Wolter's `q_h / n_h` for with-replacement sampling. The
  without-replacement factor carries `(1 - n_h/N_h)` [Wolter §4.5 eq. 4.5.3].
  Survey practice treats the PSU selection as with-replacement — Wolter does
  this himself for the NLSY97, collapsing PSUs into pseudo-strata and treating
  the pair "as if they were selected via pps wr sampling within strata"
  [Wolter §4.7]. The conservative direction of the resulting bias is his
  Lemma 4.3.5 and §4.6.
- **`mse` is not part of this change.** surveycore defaults `mse = TRUE`
  [measured-in-repo: `R/core-constructors.R:734`] where `survey` defaults it
  from `getOption("survey.replicates.mse")`. Both centrings are in Wolter's
  set of four and share one second-order expectation, so the default scale is
  decidable without settling `mse`. Every oracle block must still pass `mse`
  explicitly to both sides — oracle rule 1.
- **Degrees of freedom stay at `Inf`.** The confidence-bound assertions in the
  two oracle blocks are valid only while both sides use the normal
  approximation. `.claude/rules/testing-surveycore.md` states that surveycore
  assigns `degf <- Inf` in each Phase 1 analysis file and `survey`'s
  `confint()` defaults to `df = Inf`. This work must not move either.
- **The change is not backward compatible and is meant not to be.** Every JKn
  and bootstrap design built without an explicit `scale` reports a standard
  error larger by `1/sqrt((R-1)/R)` after the change. A caller who needs the
  old number must pass `scale` explicitly. One migration note covers this PR
  together with #242 and #243, per #257.
- **No R ran in this session.** Every number in this document is read from a
  file. `survey`'s two defaults rest on two in-repo assertions that pass on
  `develop`; a reader who wants them first-hand should build a probe design on
  the installed `survey` version, as the oracle rule's snapshot warning
  requires.

---

## Open questions

- **SETTLED — `as_survey_replicate(type = "bootstrap")` with exactly one
  replicate column stores `Inf`.** Raised here as a HOLD and decided by the
  user; `decisions.md` D-1 holds the record, the measurement and the rejected
  alternatives. The constructor accepts `R = 1` today and stores `1`
  [measured-in-repo: `R/core-constructors.R:763-768,813`]. The new default
  `1/(R-1)` is `1/0 = Inf` at `R = 1`, and no validator rejects it (G5).
  `survey::svrepdesign()` stores `Inf` for the same input, signals no
  condition, and carries the infinite scale into the standard error, so
  surveycore stores `Inf` too [measured-in-repo: `decisions.md:19-25` in this
  run directory — the probe ran in the deciding session, not in this one].
  D5's rule for this constructor is that `survey` decides.

  One fact belongs beside the decision. A refusal was available and would have
  followed a shipped precedent rather than set a new one: `as_survey_nonprob()`
  already refuses a single replicate column with
  `surveycore_error_repweights_single` — "{.arg repweights} must name at least
  2 replicate weight columns." [measured-in-repo:
  `R/core-constructors.R:1460-1470`; tests at
  `tests/testthat/test-constructors.R:2103-2113,3008-3018`; register row NB-3
  at `plans/error-messages.md:307`]. `as_survey_replicate()` carries no such
  guard [measured-in-repo: `R/core-constructors.R:763-768`]. The user chose to
  match `survey` anyway, and D-1 sends the refusal question to a new issue. Do
  not re-argue it here.

- **Is `survey`'s JKn `rscales` guess the same factor Wolter gives?** D4
  records that `svrepdesign()` guesses `rscales` only when
  `combined.weights = FALSE`, and refuses otherwise. surveycore always stores
  combined weights, so the guessing branch is unreachable from surveycore and
  the question does not block this work. It would matter to
  `from_svydesign()`. Not resolvable without reading the `survey` source.

- **Should the JKn oracle block use a per-stratum `rscales` literal?** The
  request's acceptance criteria say `rscales = <per-stratum>`; the block today
  uses `rep(1, n_rep)` [measured-in-repo:
  `tests/testthat/test-variance-replicate.R:840` and `849`]. On this fixture
  the two choices test the same thing,
  because the fixture's replicate weights carry no stratum structure (G4). A
  per-stratum literal would read as a stronger test than it is. This is a
  test-spec decision, not a methods question, and it is recorded here so the
  drafting stage makes it deliberately.
