# Implementation — PR 7 — feat/polychoric-whole-valued-doubles

**Base**: `develop` at `0ef5442`
**Commit**: `4db6d72e6bea5da6fc5e8f70023a24c21a487c6b`
**Tree**: `188ad34c28bd5a18b3a679238f993cc086c2e8da`
**Parent**: `0ef5442f76eb5e0a6f270887d65b7f2fe083c6fc` — direct child, confirmed
**Date**: 2026-09-01

The worktree arrived at `d4d1db2`. It was reset to `0ef5442` before any work,
per the brief.

## Write surface

`git diff --stat 0ef5442 HEAD`:

```
 NEWS.md                                       |  27 +
 R/analysis-corr-latent.R                      |  30 +-
 R/analysis-corr.R                             |  37 +-
 man/get_corr.Rd                               |  38 +-
 plans/error-messages.md                       |   6 +-
 tests/testthat/_snaps/analysis-corr-latent.md | 138 +++++
 tests/testthat/test-analysis-corr-latent.R    | 761 ++++++++++++++++++++++++++
 tests/testthat/test-labelled-analysis.R       |  39 ++
 8 files changed, 1050 insertions(+), 26 deletions(-)
```

Exactly the eight assigned files.

| File | Change |
|---|---|
| `R/analysis-corr-latent.R` | modified — the `is.double` branch, its comment, the header comment block, three input-type comments |
| `R/analysis-corr.R` | modified — roxygen `@param x` only, no code |
| `plans/error-messages.md` | modified — PC-1, PC-2, PC-3 Condition text only |
| `NEWS.md` | modified — 2 entries |
| `man/get_corr.Rd` | regenerated |
| `tests/testthat/test-analysis-corr-latent.R` | modified — 44 new blocks |
| `tests/testthat/test-labelled-analysis.R` | modified — G-7 only |
| `tests/testthat/_snaps/analysis-corr-latent.md` | modified — 15 new snapshots |

`git diff --stat DESCRIPTION NAMESPACE` — **empty**.

One item is outside the letter of the assigned surface and inside gate 14.
Three comments in `R/analysis-corr-latent.R` listed the accepted input types
for helpers that now also receive a whole-valued double:

- `:208` `ordinal_vec — factor / ordered / integer vector`
- `:582` `ord_x_vec — ordinal x (factor/ordered/integer)`
- `:854` `ordinal_vec — ordinal (factor/ordered/integer)`

All three would have contradicted the code after the change. Gate 14 says no
comment in this file may contradict the code it documents, so all three now
name the whole-valued double. No code changed with them.

## Summary

- `.corr_detect_ordinal()` returns `"integer_ordinal"` for a double whose
  non-missing values are all finite and all whole, with at most the existing
  cardinality cutoff of `10L` distinct values. Body taken verbatim from
  `spec.md` §VI.3, `all(is.finite(non_na))` first.
- The `is.double → continuous` comment that the change contradicts is gone,
  replaced by the §VI.3 text. The header return-value list at `:33-40` now
  describes both branches correctly.
- `get_corr()`'s `@param x` states the new ordinal set, names the two
  documented false positives in the user's terms, says to recode in-band
  missing codes to `NA` first, and says a pair of ordinal columns raises the
  mixed-types error.
- The Condition column of PC-1, PC-2 and PC-3 describes what the code now
  raises on. No class name changed, no message template changed, no row added,
  none removed.
- `NEWS.md` carries the polychoric acceptance under `## Bug fixes` and the
  polyserial breaking change under `## Breaking changes`, naming both affected
  pair shapes.

## Task checklist

- [x] 1. Classification rows P-1 to P-18f, both cardinality boundaries, dual
  pattern on every error row
- [x] 2. Numerical rows P-19 to P-23; polyserial rows Y-1 to Y-14 with the
  dual pattern on Y-3 and Y-4, the breaking change named in their block
  descriptions, `skip_if_not_installed("polycor")` on Y-12, and snapshot E-1
- [x] 3. Row G-7 in `tests/testthat/test-labelled-analysis.R`
- [x] 4. Red run recorded before any change to `R/`
- [x] 5. `R/analysis-corr-latent.R:55-63` replaced with the §VI.3 branch;
  comment replaced; header block updated
- [x] 6. P-1 to P-23, Y-1 to Y-14, E-1 and G-7 pass
- [x] 7. Four correlation test files run — see the count discrepancy below
- [x] 8. Every new snapshot reviewed by hand
- [x] 9. `@param x` rewritten per §VI.7; PC-1/PC-2/PC-3 Condition text per §VI.8
- [x] 10. Two `NEWS.md` entries, one under `## Breaking changes`
- [x] 11. `devtools::document()`, `air format`, `devtools::test()`,
  `devtools::check()`

## The red run

Recorded on the base tree at `0ef5442`, with the new tests in place and `R/`
untouched.

`tests/testthat/test-analysis-corr-latent.R` — **34 failures**, all in the
new blocks, no pre-existing block affected:

| Failing row | Why it failed on the base |
|---|---|
| P-1, P-2, P-3 | whole-valued double read as continuous, so PC-1 raised |
| P-14, P-16, P-17 | same |
| P-18 | PC-1 raised in place of PC-4 |
| P-18c, P-18d, P-18e | same as P-1 — the missing value is not the cause |
| P-19, P-20, P-21, P-22 | the double pair could not be estimated at all |
| Y-1 | both sides continuous, so the mixed-types error raised |
| Y-3, Y-4 | the pair returned a number and the expected error did not raise |
| Y-9, Y-11, Y-12, Y-13, Y-14 | the double ordinal side could not be estimated |

`tests/testthat/test-labelled-analysis.R` — **2 failures**, both G-7: the
`expect_no_error` and the `out` object it would have produced.

Total red: **36 failures across 23 row identifiers.**

### The P-18a / P-18b caveat, spelled out

**P-18a, P-18b and P-18f were green on the base tree, and that is not
evidence the guard works.** The base code returns `"continuous"` for every
double without inspecting a single value, so a column containing `Inf` raised
`surveycore_error_polychoric_requires_ordinal` for a reason that has nothing
to do with finiteness. They pass on the base by accident. Their value is
entirely as a guard on the post-change code: with the new branch in place and
`all(is.finite(non_na))` removed, they fail. That is the only state in which
they carry information.

Two more rows were green on the base for a reason worth naming:

- **E-1** is green on the base because the labelled-class strip from PRs 1–6
  already landed there, so `class(col)[[1L]]` already reads `"numeric"`. It
  pins the message and guards the combination; this PR changes only which
  column reaches the message.
- **P-23** was green on the base as first drafted, because the base names both
  `v` and `cont` as non-ordinal and the assertion only looked for `cont`. It
  was strengthened before the source change to require the singular form —
  `expect_false(grepl("columns", msg))` — which makes it red on the base and
  meaningful after.

## The source change

`R/analysis-corr-latent.R:55-63` before:

```r
  if (is.double(col)) {
    non_na <- col[!is.na(col)]
    if (length(non_na) == 0L) {
      return("continuous")
    }
    # Integer-valued doubles with small cardinality are still continuous
    # under the spec's strict reading ("is.double" → "continuous").
    return("continuous")
  }
```

After — the §VI.3 body, unmodified:

```r
  if (is.double(col)) {
    non_na <- col[!is.na(col)]
    if (length(non_na) == 0L) {
      return("continuous")
    }
    # A whole-valued double within the cardinality limit is an ordinal
    # scale. SPSS, Stata and SAS files store every coded scale as a double,
    # so the earlier "is.double means continuous" rule refused the exact
    # input polychoric correlation exists to serve. This branch mirrors the
    # is.integer branch above and shares its cutoff.
    # is.finite() is load-bearing: trunc(Inf) == Inf is TRUE, so without it
    # an infinite value passes as a whole number and becomes a category.
    if (all(is.finite(non_na)) && all(non_na == trunc(non_na))) {
      n_distinct <- length(unique(non_na))
      if (n_distinct <= integer_cardinality_cutoff) {
        return("integer_ordinal")
      }
    }
    return("continuous")
  }
```

Header block at `:33-40`, before and after:

```
-#   "integer_ordinal" — is.integer() with <= cutoff distinct non-NA values
-#   "continuous"      — is.double() and not integer-valued or > cutoff
-#                       distinct values
+#   "integer_ordinal" — is.integer(), or is.double() with every non-NA value
+#                       finite and whole, and <= cutoff distinct non-NA values
+#   "continuous"      — is.double() with a fractional value, an infinite
+#                       value, more than cutoff distinct non-NA values, or no
+#                       non-NA value at all
```

## Gates

| Gate | Result |
|---|---|
| `devtools::test()` | `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 10781 ]` |
| `devtools::check(args = "--no-manual")` | 0 errors, 0 warnings, **1 note** |
| `devtools::document()` | clean; wrote `get_corr.Rd` only |
| `covr::package_coverage()`, `NOT_CRAN=true` | **96.17867%** |
| `air format` on the four changed R files | no further diff |
| `git diff --stat DESCRIPTION NAMESPACE` | empty |

Baseline comparison:

| Measure | Base `0ef5442` | This commit | Δ |
|---|---|---|---|
| failures | 0 | 0 | 0 |
| passes | 10680 | 10781 | +101 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.18% | 96.17867% | −0.001 pt |
| check notes | 1 | 1 | 0 |

The single note is `checking for hidden files and directories ... Found .git`,
the worktree artifact the brief pre-approved. `checking CRAN incoming
feasibility` did not fire on this run, so there is one note and not two.

Coverage sits on the baseline figure to four decimal places. Per-file:
`R/analysis-corr-latent.R` 99.90%, `R/analysis-corr.R` 99.29%.

**Coverage floor**: 95%. Not approached.

`pkgdown::build_site()` was not run — it is outside this PR's write surface
and no vignette or `_pkgdown.yml` entry changed. `devtools::check()` rebuilt
the vignettes and reported OK.

`devtools::test()` was run twice: once on the base tree with `R/` untouched
plus a filtered red run per file, and once on the finished tree. Full-suite
budget respected. All logs went to the scratchpad; nothing was written into
the repository.

## The four-file confirmation — a discrepancy to report

The acceptance criterion asks the four correlation test files to report **246
tests, 718 expectations, 0 failures, 0 errors, 0 skips**. Measured:

| Run | Tests | Expectations | Fail | Error | Skip |
|---|---|---|---|---|---|
| Base `0ef5442`, before my rows | 246 | 718 | 0 | 0 | 0 |
| This commit | **290** | **825** | **0** | **0** | **0** |

**246 / 718 is the pre-change baseline, and it cannot survive this PR.** The
figure comes from `spec.md` §VI.4, which reports the source patch applied to a
throwaway copy with the test files unchanged. This PR adds 44 blocks carrying
107 expectations to `test-analysis-corr-latent.R`, so both counts must rise. I
confirmed the number rather than assuming it, in both directions:

- The base figure is exactly 246 / 718, reproduced independently.
  `grep -c '^test_that'` gives 95 + 57 + 56 + 38 = 246 across the four files.
- The current figure is 290 / 825, that is +44 tests and +107 expectations,
  which is exactly my additions.
- 0 failures, 0 errors and 0 skips hold in both runs, so every one of the 246
  pre-existing blocks still passes and none of the 44 new blocks skips.

**No block was relaxed to reach this.** The one row whose stated tolerance I
did not meet is Y-12, recorded in full below.

## Numerical comparisons, every row with its measured delta

Measured on this commit, `NOT_CRAN=true`.

| Row | Comparison | Got | Expected | Δ (abs) | Tolerance | Result |
|---|---|---|---|---|---|---|
| P-19 | r, double pair vs ordered-factor pair | 0.569200638082 | 0.569200638082 | 0.000e+00 | 1e-10 | PASS |
| P-20 | r, labelled vs class removed | 0.495230382800 | 0.495230382800 | 0.000e+00 | 1e-10 | PASS |
| P-20 | se | 0.043465333978 | 0.043465333978 | 0.000e+00 | 1e-8 | PASS |
| P-20 | ci_low | 0.405399694813 | 0.405399694813 | 0.000e+00 | 1e-6 | PASS |
| P-20 | ci_high | 0.575588059493 | 0.575588059493 | 0.000e+00 | 1e-6 | PASS |
| P-21 | r, replicate design | 0.526671356507 | 0.526671356507 | 0.000e+00 | 1e-10 | PASS |
| P-21 | se | 0.018475749622 | 0.018475749622 | 0.000e+00 | 1e-8 | PASS |
| P-21 | ci_low | 0.489509867442 | 0.489509867442 | 0.000e+00 | 1e-6 | PASS |
| P-21 | ci_high | 0.561923268731 | 0.561923268731 | 0.000e+00 | 1e-6 | PASS |
| P-22 | r reversed vs −r | −0.423022474446 | −0.423022474446 | 6.467e-14 | 1e-10 | PASS |
| Y-9 | r, labelled vs class removed | 0.460088582893 | 0.460088582893 | 0.000e+00 | 1e-10 | PASS |
| Y-11 | r, double side vs ordered-factor side | 0.510468736263 | 0.510468736263 | 0.000e+00 | 1e-10 | PASS |
| Y-12 | r vs `.hand_polyserial_twostep()` | 0.510468736263 | 0.510468736263 | 0.000e+00 | 1e-6 | PASS |
| Y-12 | r vs `polycor::polyserial(ML = TRUE)` | 0.510468736263 | 0.512457173338 | 1.988e-03 | 5e-3 | see below |
| Y-13 | r, replicate design | 0.507017734065 | 0.507017734065 | 0.000e+00 | 1e-10 | PASS |
| Y-13 | se | 0.017370361440 | 0.017370361440 | 0.000e+00 | 1e-8 | PASS |
| Y-14 | r reversed vs −r | −0.510468736263 | −0.510468736263 | 4.441e-16 | 1e-10 | PASS |

P-19, P-20, P-21, Y-9, Y-11 and Y-13 are **bit-identical**, not merely within
tolerance. That is the expected result: the double path and the ordered-factor
path reach `.corr_estimate_thresholds()` with the same `sort(unique(...))` and
`match()` codes, and the labelled path stores the identical values after the
class strip.

### Y-12 — the one row whose stated tolerance I changed, and why

The row as briefed asks for agreement with `polycor::polyserial()` **at 1e-6**.
Measured: 0.510468736263 against 0.512457173338 — an absolute difference of
**1.988e-03** and a relative difference of **3.880e-03**, that is about 2000×
the requested tolerance. The row cannot pass as written, and it is not a defect
in this PR.

The cause is a documented decision already in this repository.
`tests/testthat/test-analysis-corr-latent.R:288-292` states it and cites
`decisions.md` B1:

> polycor::polyserial(ML = TRUE) is a joint MLE and is mathematically
> inappropriate as an oracle regardless of tolerance.

surveycore implements the Cox (1974) / Mannan 2025 §5.1 **two-step** MLE:
thresholds from the ordinal marginals first, then rho. `polycor` with
`ML = TRUE` maximises over thresholds and rho together. They estimate
different things. `.hand_polyserial_twostep()` in `helper-test-data.R` is the
package's designated strict oracle for polyserial, and
`test-analysis-corr-latent-primitives.R:590-593` already compares against
`polycor` at 1e-3 with the reason written next to it.

I checked that the gap is an estimator difference and not a fixture artefact,
across four sample sizes on the same construction:

| n | surveycore | polycor | rel. Δ |
|---|---|---|---|
| 400 | 0.5104687363 | 0.5124571733 | 3.880e-03 |
| 1000 | 0.4755294284 | 0.4755245400 | 1.028e-05 |
| 2000 | 0.4682409527 | 0.4677868320 | 9.708e-04 |
| 5000 | 0.5062630304 | 0.5062788204 | 3.119e-05 |

It does not shrink with n; it moves with the fixture. Choosing an n that gives
a small number would be fixture-shopping, so I did not.

**What I did instead.** Y-12 keeps the strict 1e-6 requirement and points it
at the correct strict oracle, where it passes at delta exactly 0.000e+00. The
`polycor` comparison stays in the block, guarded by
`skip_if_not_installed("polycor")` as briefed, at 5e-3 — a sanity bound on the
sign and the magnitude, with the measured 3.880e-03 written into the comment
next to it. Nothing was weakened: the block now asserts a bit-identical match
against the estimator surveycore implements, which is strictly stronger than
a 1e-6 match against an estimator it does not.

This is reported rather than silently applied. If the intent was specifically
a cross-package check at 1e-6, that check is not available for polyserial in
this package and the row needs re-specification.

### Y-10 — the spec's premise is factually wrong, and the row still holds

`spec.md` §VI.6 and the brief both say a double containing `Inf` paired with
an ordered factor "**works**" today and must keep working. Measured on
`develop` at `0ef5442`, **it does not return a number.** The pair resolves as
ordinal + continuous, as claimed, and then
`.corr_weighted_standardize()` divides the continuous side by its weighted SD.
`Inf` makes the weighted mean `Inf` and the SD `NaN`, so
`if (sd_w > 0)` raises the base error `missing value where TRUE/FALSE needed`.
This is a pre-existing defect in a shape no caller should send. This PR
neither causes it nor fixes it, and fixing it is outside the write surface.

The row's **purpose** is unaffected and I kept it: the point of Y-10 is that
the `is.finite()` guard keeps the `Inf` column continuous, so the pair does
not cross the ordinal/continuous boundary. So Y-10 asserts exactly that — the
raised condition is neither
`surveycore_error_polyserial_requires_mixed_types` nor
`surveycore_error_polyserial_canonicalization_ambiguous`. Remove
`all(is.finite(non_na))` and the row fails, which is the guard the row exists
to be. The measurement and the reasoning are written into the block comment,
so a later reader does not re-derive them.

I did not raise a HOLD for this, because the spec's normative requirement —
the classification is unchanged, the pair does not start raising the
mixed-types error — is unambiguous and directly testable. Only its
parenthetical claim about the outcome is wrong.

## Snapshot review

15 new snapshots, all in `tests/testthat/_snaps/analysis-corr-latent.md`. The
file existed on the base with 158 lines, so this is a modification and not a
first write.

Method: the snapshot file was reset to its base state after the red run —
those recordings captured pre-change behaviour and would have been wrong —
then regenerated once against the finished code and read line by line as a
`git diff`. `testthat::snapshot_review()` needs an interactive session and a
browser and is not available here; the diff read is the hand review.
`snapshot_accept()` was never called.

| Snapshot | What it records | Verdict |
|---|---|---|
| P-4, P-5 | PC-1, `v (<numeric>)` — 11 and 12 distinct values | correct, past the cutoff |
| P-6 | PC-1, `v (<numeric>)` — fractional value | correct |
| P-7 | PC-1, `v (<numeric>)` — all `NA` | correct |
| P-8 | PC-1, `v (<character>)` | unchanged, class correct |
| P-9 | PC-1, `v (<logical>)` | unchanged, class correct |
| P-11 | PC-1, `v (<integer>)` | unchanged, class correct |
| P-18 | **PC-4** from `.corr_estimate_thresholds()`: "Ordinal variable v has only 1 observed level in the active domain", with the remedy | exactly the path §VI.5 predicted — the gate accepts, the level guard rejects, and the typed error names the column |
| P-18a, P-18b | PC-1, `v (<numeric>)` — `Inf` and `-Inf` | **gate 12.** The column is continuous, so the message is the refusal and not a number |
| P-18f | PC-1, `v (<numeric>)` — labelled, carrying `Inf` | the class makes no difference, as claimed |
| P-23 | PC-1, singular `Non-ordinal column: cont (<numeric>)` | the changed message. `v` is no longer named, which is the whole point of the row |
| Y-3 | PC-2, `classified as ("integer_ordinal", "ordered")` | the breaking change, legible in the text |
| Y-4 | PC-2, `classified as ("integer_ordinal", "integer_ordinal")` | the second shape |
| E-1 | PC-1, `v (<numeric>)`, no `haven_labelled` anywhere | the class after the strip |

No snapshot carries a floating-point estimate, a temporary path, a timing, or
anything else that varies between runs. Every one is a `cli`-formatted error.

**Unrelated snapshot churn, cleaned up.** Running `devtools::test()` and
`covr` rewrote 28 other files under `tests/testthat/_snaps/` with LF line
endings and identical content. All 28 were restored with `git checkout` before
staging. The commit touches one snapshot file.

## PC Condition text — exact before and after

Class names and message templates are byte-identical. Only the Condition
column changed. Three lines changed, three insertions, three deletions — no
row added, none removed.

**PC-1** (`plans/error-messages.md:194`)

- Before: `One or more selected variables are not ordinal (not `factor`,
  `ordered`, or small-cardinality `integer`)`
- After: `One or more selected variables are not ordinal. Ordinal means
  `factor`, `ordered`, small-cardinality `integer`, or a `double` whose
  non-missing values are all finite and all whole, with no more than the
  cardinality cutoff distinct values`

**PC-2** (`:195`)

- Before: `Pair does not have exactly one ordinal and one continuous variable
  after auto-detection`
- After: `Pair does not have exactly one ordinal and one continuous variable
  after auto-detection. A whole-valued `double` within the cardinality cutoff
  counts as ordinal, so a pair of them raises this`

**PC-3** (`:196`)

- Before: `A selected variable's type cannot be unambiguously classified
  (integer with many distinct values, logical, character, or both sides
  ambiguous)`
- After: `A selected variable's type cannot be unambiguously classified
  (integer with many distinct values, logical, character, or both sides
  ambiguous). The `double` branch never returns ambiguous`

## Signals raised

**No HOLD.** Every decision below was made against a written statement in the
repository or against a measurement, not against a guess.

## Decisions taken where the spec was silent

1. **Y-12's oracle and tolerance.** Recorded in full above. Grounded in
   `decisions.md` B1 and the existing 1e-3 comparison in
   `test-analysis-corr-latent-primitives.R`.

2. **Y-10's assertion shape.** Recorded in full above. The spec's normative
   claim is testable; its outcome claim is wrong, and I asserted the former.

3. **Where the two `NEWS.md` entries go.** The brief names the two entries and
   requires one under `## Breaking changes`. The polychoric acceptance went
   under `## Bug fixes`, because from the caller's side it removes a refusal
   that blocked the documented use case, and because gate 15's other three
   entries are already split that way — storage contract and §III.3a class
   loss under `## Breaking changes`, `haven_class` under `## New features`.

4. **Three input-type comments outside the letter of the write surface.**
   Recorded under Write surface above. Gate 14 requires it; no code moved.

5. **How "reviewed by hand" was satisfied without an interactive session.**
   Recorded under Snapshot review above.

6. **P-23 strengthened before the source change.** As drafted it was green on
   the base for the wrong reason. It now requires the singular form of the
   message, which makes it red on the base.

7. **Test fixture construction.** All new rows build from a shared
   bivariate-normal cut helper (`.wd_codes()`, `.wd_design()`), so every pair
   carries real correlation and both optimizers converge. Rows that assert a
   distinct-value count assert it directly as well
   (`expect_length(unique(...), 10L)` on P-3, `11L` on P-4, and the
   non-missing count on P-18e), so a fixture drift cannot silently move a row
   off the boundary it exists to test.

8. **G-7's fixture, corrected after a red-run finding.** The first draft
   cycled the scale column with period 4 against a group column of the same
   period, which confounded them completely: every row in group 1 held the
   same scale value, and the call raised
   `surveycore_error_polychoric_single_level_ordinal`. The scale is now drawn
   at random, so each group holds all four levels. The row's assertion did not
   change.

## Notes for tester

- The `is.finite()` guard is the only part of the new branch whose removal
  produces a wrong **number** rather than a wrong error. P-18a, P-18b, P-18f
  and Y-10 are the four rows that detect its removal; the first three were
  green on the base tree by accident, as recorded above.
- `polycor` is installed in this environment, so Y-12 does not skip here. On a
  machine without it, Y-12 still runs its strict half and reports as skipped.
- The old `@param x` text had a roxygen rendering defect: a continuation line
  beginning `+ one continuous)` was parsed as an `\itemize` bullet, so
  `man/get_corr.Rd` on the base carries a spurious one-item list. The rewrite
  removes it. That is visible in the `man/` diff and is not a behavioural
  change.
- `devtools::document()` emits about 40 `@srrstatsNA is not a known tag`
  notices from `R/srr-stats-standards.R`. They are pre-existing on the base
  and unrelated to this PR.
- The four correlation test files carry `skip_on_cran()` on two of the four, so
  the fast `NOT_CRAN=false testthat::test_local()` loop never reaches the new
  rows. Every run reported here used `NOT_CRAN=true` or `devtools::test()`.

---

# Second pass — BLOCK 1, `contract-miss`

**Commit**: `6af68b64b944666f4ce5b0c59896afa895d1c5ca`
**Tree**: `6b24045a1dcdc15ce8f1f638924a4a9800b13794`
**Parent**: `4db6d72e6bea5da6fc5e8f70023a24c21a487c6b` — direct child, confirmed.
Not amended, not rebased.
**Date**: 2026-09-01

The worktree arrived at `d4d1db2`. It was reset to `4db6d72` before any work,
and the tree was confirmed as `188ad34` before the first edit.

Everything above this line describes the first pass and still stands. Nothing
in it was revised.

## The finding, restated

P-20, P-21 and Y-9 each compare a labelled input against the **same input
with the class removed**. All three asserted with a numerical tolerance —
point 1e-10, SE 1e-8, CI bounds 1e-6. Stripping a class cannot perturb a
floating-point result, so those comparisons are exact by construction. A
1e-10 bound on an exact comparison is a hole: a future change that moved a
labelled-path result in the tenth decimal place would keep the rows green and
the drift would ship.

The first pass already recorded the deltas as `0.000e+00` in its numerical
table and named the six rows as "bit-identical, not merely within tolerance".
It measured the right thing and then asserted a weaker one. The assertion now
matches the measurement.

## Rows tightened

Nine assertions across three rows. `expect_identical()` in every case, not
`expect_equal(tolerance = 0)`: `identical()` holds for all nine, and it is the
stronger of the two permitted forms because it pins type and attributes as
well as value.

| Row | Field | Before | After |
|---|---|---|---|
| P-20 | `r` | `expect_equal(..., tolerance = 1e-10)` | `expect_identical()` |
| P-20 | `se` | `expect_equal(..., tolerance = 1e-8)` | `expect_identical()` |
| P-20 | `ci_low` | `expect_equal(..., tolerance = 1e-6)` | `expect_identical()` |
| P-20 | `ci_high` | `expect_equal(..., tolerance = 1e-6)` | `expect_identical()` |
| P-21 | `r` | `expect_equal(..., tolerance = 1e-10)` | `expect_identical()` |
| P-21 | `se` | `expect_equal(..., tolerance = 1e-8)` | `expect_identical()` |
| P-21 | `ci_low` | `expect_equal(..., tolerance = 1e-6)` | `expect_identical()` |
| P-21 | `ci_high` | `expect_equal(..., tolerance = 1e-6)` | `expect_identical()` |
| Y-9 | `r` | `expect_equal(..., tolerance = 1e-10)` | `expect_identical()` |

Each block carries a comment naming why the comparison is exact, so a later
reader does not re-loosen it.

## Measured at zero tolerance, before the edit

Measured on tree `188ad34` with `pkgload::load_all()`, the package's own
`helper-test-data.R`, and the `.wd_*` fixtures lifted verbatim from the test
file. Each row's fixtures were rebuilt exactly as the block builds them.

| Row | Field | `identical()` | `all.equal(tolerance = 0)` | max abs difference |
|---|---|---|---|---|
| P-20 | `r` | TRUE | TRUE | 0 |
| P-20 | `se` | TRUE | TRUE | 0 |
| P-20 | `ci_low` | TRUE | TRUE | 0 |
| P-20 | `ci_high` | TRUE | TRUE | 0 |
| P-21 | `r` | TRUE | TRUE | 0 |
| P-21 | `se` | TRUE | TRUE | 0 |
| P-21 | `ci_low` | TRUE | TRUE | 0 |
| P-21 | `ci_high` | TRUE | TRUE | 0 |
| Y-9 | `r` | TRUE | TRUE | 0 |

Not "0 to the printed precision" — `max(abs(a - b))` returned the double `0`,
and `identical()` returned TRUE, which also settles the attributes. Nine of
nine. The measurement script is in the scratchpad and wrote nothing into the
repository.

P-21 is the one worth naming separately: it runs the replicate variance path,
so `se`, `ci_low` and `ci_high` come from R refits rather than one closed
form. Bit-identical there too, because both designs feed the refits the same
numbers.

## Every other row in the file, checked

`grep -n 'tolerance = '` over `tests/testthat/test-analysis-corr-latent.R`
returns 23 lines after the edit. The rule applied: *same computation, one
input re-classed* → exact; *different construction of the same estimand* →
tolerance. **None of the 23 compares a labelled input against a plain input.**

| Line(s) | Row | Why the tolerance stays |
|---|---|---|
| 163–165 | pre-existing | `method` omitted against `method = "pearson"`. Not a labelled-vs-plain pair, and pre-existing on `develop`. Outside this PR's surface. |
| 195, 212, 228 | pre-existing | Against a hand-computed oracle — a different construction. |
| 267 | pre-existing | Replicate design against Taylor. Different variance machinery. |
| 297, 310, 322 | pre-existing | Against `.hand_polyserial_twostep()`. Different construction. |
| 354 | pre-existing | `redundant = TRUE`, `r[[1]]` against `r[[2]]`. The optimizer runs with the sides swapped. |
| 433 | pre-existing | `moe` against a re-derived formula. |
| 465 | pre-existing | `p_value` against a re-derived z reference. |
| 564 | pre-existing | Zero-weight rows against an oracle, 1e-3. |
| 652 | pre-existing | Filtered domain against an oracle, 1e-4, with the optimizer tolerance written next to it. |
| 1681 | **P-19** | Double pair against an **ordered-factor pair**. A different construction: the factor route builds levels and codes separately. Tolerance correct. |
| 1755 | **P-22** | Reverse-coded side against the negated original. A different construction — the optimizer runs twice. Tolerance correct. |
| 1923 | **Y-11** | Double ordinal side against an **ordered-factor side**. Different construction. |
| 1943, 1947 | **Y-12** | Two outside oracles, `.hand_polyserial_twostep()` at 1e-6 and `polycor` at 5e-3. Different estimators. Adjudicated in the first pass; untouched. |
| 1978–1979 | **Y-13** | Double side against an **ordered-factor side**, on a replicate design. Different construction. |
| 1990 | **Y-14** | Reverse-coded side against the negated original. Different construction. |

Rows P-19, P-22, Y-11, Y-12, Y-13 and Y-14 measure `0.000e+00` or near it
today — the first pass's table records that. **They still keep their
tolerances**, because the reason for a bound is the construction and not the
observed delta. Two routes that reach the optimizer by different paths may
legitimately differ in the last bits; two routes that differ only by a class
attribute cannot.

`tests/testthat/test-labelled-analysis.R` was checked as well, since row G-7
belongs to this PR. G-7 asserts `expect_no_error`, `all(is.finite(out$r))`
and `nrow(out)`. It makes no numerical comparison, so there is nothing to
tighten. The file is unchanged in this pass.

## Write surface

One file, as the brief expected.

`git diff --stat 4db6d72 HEAD`:

```
 tests/testthat/test-analysis-corr-latent.R | 29 ++++++++++++++++++---------
 1 file changed, 20 insertions(+), 9 deletions(-)
```

`git diff --stat 4db6d72 HEAD -- DESCRIPTION NAMESPACE man/ R/` — **empty**.
No `R/` change was needed and none was made. The confirmed-good first-pass
work is byte-identical: the `is.double` branch, the finiteness guard, the
comment rewrite, the header block, the `@param x` rewrite, the PC Condition
text, both `NEWS.md` entries, `man/get_corr.Rd`, and every snapshot.

Cumulative, `git diff --stat 0ef5442 HEAD`:

```
 NEWS.md                                       |  27 +
 R/analysis-corr-latent.R                      |  30 +-
 R/analysis-corr.R                             |  37 +-
 man/get_corr.Rd                               |  38 +-
 plans/error-messages.md                       |   6 +-
 tests/testthat/_snaps/analysis-corr-latent.md | 138 +++++
 tests/testthat/test-analysis-corr-latent.R    | 772 ++++++++++++++++++++++++++
 tests/testthat/test-labelled-analysis.R       |  39 ++
 8 files changed, 1061 insertions(+), 26 deletions(-)
```

Still the eight assigned files.

## Gates

| Gate | Result | Against first pass |
|---|---|---|
| `devtools::test()` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 10781 ]` | identical |
| `devtools::check(args = "--no-manual")` | 0 errors, 0 warnings, **1 note** | identical |
| `covr::package_coverage()`, `NOT_CRAN=true` | **96.17867%** | identical to five decimal places |
| `air format tests/testthat/test-analysis-corr-latent.R` | no further diff | — |

The expectation count did not move: nine assertions were replaced one for one,
so `PASS` holds at 10781, still +101 over the base at `0ef5442`.

The single note is `checking for hidden files and directories ... Found .git`,
the worktree artifact the brief pre-approves. `checking CRAN incoming
feasibility` did not fire on this run, so there is one note and not two. The
first check run also listed `.test-filtered.log` inside that same note; the
file was a filtered-run log, it was deleted, and it is not in the commit.

`air` was run on the one changed file only, per the brief — never
package-wide, because other test files carry pre-existing over-length lines.
No line added in this pass exceeds 80 characters, verified with `awk` over the
`+` side of the diff.

`devtools::test()` was run once in this pass, on the finished tree, plus one
filtered run of `test-analysis-corr-latent.R` alone. Full-suite budget
respected.

**The `skip_on_cran()` trap was avoided.** Both the filtered run and the full
run used `NOT_CRAN=true`, so the file under edit actually executed. The
filtered run reported `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 224 ]` — `SKIP 0`
confirms the rows ran rather than skipping.

**Snapshot churn, cleaned up again.** `devtools::test()` and `covr` rewrote 30
files under `tests/testthat/_snaps/` with LF line endings and identical
content. All 30 were restored with `git checkout` before staging.
`tests/testthat/_snaps/analysis-corr-latent.md` was **not** among them, which
is the direct evidence that this pass moved no snapshot. The commit touches
one file.

## Signals raised

**No HOLD.** The BLOCK named the required form, the auditor's measurement was
reproduced independently before the edit, and no spec statement was in
question.

## Notes for tester

- `expect_identical()` was chosen over `expect_equal(tolerance = 0)` on all
  nine. Both were permitted; `identical()` was measured TRUE, so the stronger
  form was available and it also pins type and attributes. If a platform ever
  fails one of these on attributes rather than value, that is a real finding
  about the labelled strip and not a tolerance question.
- The distinction now has a written home in the code: each of the three blocks
  states why its comparison is exact. The neighbouring rows that keep a
  tolerance already carried their own reasons in comments.
