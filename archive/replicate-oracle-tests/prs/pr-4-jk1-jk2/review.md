# Review — PR 4 — test/replicate-oracle-jk1-jk2

**Verdict**: PASS
**Date**: 2026-09-22

Head `d266759ba26b4a52ac6e98922069ddca93f7a9ab`, base
`bf47f79f4f8de9aeead6ddce47a8472d89556eaf`, tree
`77ba0ec4cd3e0cf5427e9ba15aaf72c101668147`. Diff: 1 file, +48/-21.

## Convergence checks

- Spec coverage: **y**. `spec.md` §V.2, §V.3 and §IV.1–§IV.3 each map to a row
  in `audit.md`. Seven rows verified by the tester, three (5.1–5.3) deferred to
  me and settled below.
- Test coverage of spec: **y**. §V.2's three removals reach rows 2.2, 2.5 and
  2.25; §V.3's requirements reach row 3.1.3; §IV.3's five assertions and the
  warning count reach rows 3.1.2 and 3.1.3; the power proof reaches §5.
- Tolerance integrity: **y**. No tolerance widened, none dropped.
- Scope discipline: **y**. One file, the one the plan names.
- Regression safety: **y**. No test outside this PR's scope changed state.

## Rows 5.1, 5.2 and 5.3 — settled, and re-run first-hand

The tester could not measure these and said so. I did two things: checked the
builder's record for internal consistency, then reproduced the experiment.

### The record is arithmetically sound

The builder reports a standard error moving from `0.2402` to `0.2464` and
bounds from `49.966`/`50.907` to `49.954`/`50.920`. Changing the stored scale
from `(R-1)/R` to `1` at `R = 20` multiplies the variance by `20/19`, so the
standard error multiplies by `1/sqrt(0.95) = 1.0259784`:

| Quantity | Predicted from the clean value | Builder reported |
|---|---|---|
| SE | `0.2402 x 1.0259784 = 0.24644` | `0.2464` |
| `ci_low` | `50.4365 - 0.4705 x 1.0259784 = 49.95378` | `49.954` |
| `ci_high` | `50.4365 + 0.4705 x 1.0259784 = 50.91922` | `50.920` |

Three quantities agree to the reported precision under one ratio. Half-widths
recovered from the clean bounds give `z = 1.9588`, the normal critical value,
which also confirms §IV.3's bound premise held during the run.

### I reproduced it

I edited `R/core-constructors.R` line 799 from
`      JK1 = (n_rep - 1L) / n_rep,` to `      JK1 = 1,` and ran the file.

| Run | Result |
|---|---|
| Broken default | `[ FAIL 3 \| WARN 1 \| SKIP 0 \| PASS 140 ]` |
| After `git restore` | `[ FAIL 0 \| WARN 1 \| SKIP 0 \| PASS 143 ]` |

The three failures are at lines 145, 146 and 147 — the standard error and both
bounds — with the values the builder recorded, to the digit:

```
1. Failure ('test-variance-replicate.R:145:3')  actual 0.2464  expected 0.2402
2. Failure ('test-variance-replicate.R:146:3')  actual 49.954  expected 49.966
3. Failure ('test-variance-replicate.R:147:3')  actual 50.920  expected 50.907
```

| Row | Ruling | Evidence |
|---|---|---|
| 5.1 | **established** | 3 failures, all inside the JK1 block: SE and both bounds |
| 5.2 | **established** | line 144, the point estimate, is absent from the failure list |
| 5.3 | **established** | pass count 143 → 140, exactly 3; warning count held at 1; no other line number appeared |

Line 799 is the JK1 default, inside `switch(type, ...)` under
`if (is.null(scale))` in `as_survey_replicate()`, and `(n_rep - 1L) / n_rep` is
the constant the block's stored-scale assertion pins at line 138.

**I reverted with `git restore R/core-constructors.R`.** Afterwards
`git status --porcelain -- R/` returns nothing, line 799 reads the original
text at the original number, `git diff --name-only bf47f79 HEAD -- R/` lists
zero files, and the `R/core-constructors.R` blob is `066389be` on base and on
head. The tree is back at `77ba0ec4`, the audited tree. Rows 5.4 and 5.5 hold
after my run as they did before it.

## §V.2's three removals — all hold in the JK1 block

| Removal | State | Evidence |
|---|---|---|
| No `scale` to `svrepdesign()` | gone | parse walk: 10 `svrepdesign` calls, 0 with `scale`, 0 with `rscales`, all 10 with the identical arg set `data, mse, repweights, type, weights` |
| No `suppressWarnings()` | gone | 0 hits in the file |
| No line restating `(n_rep - 1L) / n_rep` | gone | the deleted line is `jk1_scale <- (n_rep - 1L) / n_rep` with its `scale = jk1_scale` argument |

**The builder removed the computing line and kept the assertion literal, not
the reverse.** Line 108 keeps `n_rep <- length(repwt_cols)`, which row 2.24
requires. Line 139 keeps `expect_equal(sv$scale, (n_rep - 1) / n_rep,
tolerance = 1e-8)`, which §IV.3 item 5 requires. No line in the block computes
the scale for use as an argument. This is the argument-versus-literal
distinction the oracle rule draws, applied the right way round.

## §V.3's requirements in the JK2 block

| Requirement | State |
|---|---|
| `suppressWarnings()` gone | yes |
| Warning asserted by fragment | yes, line 189–193 |
| Warning asserted by count | yes, `expect_length(jk2_warnings, 1L)` at line 188 |
| Existing comment on the JK2 scale kept | yes, lines 153–158, unchanged by the diff |
| Existing assertion that surveycore stores `scale = 1` kept | yes, line 174 |
| `survey`'s stored scale asserted against `1` | yes, line 196, now with the guard comment and `1e-8` |

### The `rscales` wording — clean

The kept comment says:

```r
  # survey::svrepdesign() fixes scale = 1 and rscales = rep(1, R) for JK2 and
  # warns that it ignores both arguments. The constructor left scale at the
  # delete-one factor (R-1)/R, so every JK2 design built without an explicit
  # scale reported a standard error low by sqrt((R-1)/R) (issue #242).
```

That states what `survey` does with the arguments. It does **not** say JK2's
per-stratum factors belong in `rscales`. The wording PR #280 corrected out of
the package is not reintroduced, in this block or anywhere in the diff. A
repo-wide grep for `per-stratum` returns only PR #280's corrected form — "the
per-stratum factor is already inside the replicate weights" — at
`R/core-constructors.R:608` and `:801`, `man/as_survey_replicate.Rd:46` and
`tests/testthat/test-constructors.R:631`.

## The fragments — right, and `fixed = TRUE` does settle the parenthesis

**`fixed = TRUE` makes the parenthesis concern moot.** `expect_match()` passes
the flag to `grepl()`, which disables regular-expression parsing entirely, so
`(n-1)/n` would have matched as literal text. §V.2's ban on the full warning
text is therefore a second guard on a hazard the flag already closes, not a
live constraint. The builder honoured both, which costs nothing.

The fragments are specific on their own merits. Measured against `survey` 4.5
on this machine, by deparsing `survey:::svrepdesign.default`:

| Fragment | Source | Judgement |
|---|---|---|
| `guessing n=number of replicates` | one `warning()` call, `warning("scale (n-1)/n not provided: guessing n=number of replicates")` | specific. It carries no regex metacharacter even without the flag. §V.2's hazard — `rho not relevant to JK1 design: ignored.` — does not contain it, so the fragment cannot reach that branch. |
| `with type JK2 scale= and rscales= are not needed` | `warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))`, at two call sites | specific, and better than the obvious alternative. The template is generic in `type`, so the tail alone would also match the same warning raised for ACS and successive-difference. Embedding the literal `JK2` between `with type` and `scale=` discriminates on the type. |

Neither fragment matches on a bare type name, which is what §V.2 forbids.

## Tolerance Integrity

`test-spec.md` §8 allows no deviation and calls both a widened tolerance and an
omitted one a defect. The diff's 21 deletions carry exactly one assertion:

```
-  expect_equal(sv$scale, 1)
+  expect_equal(sv$scale, 1, tolerance = 1e-8)
```

That is a tightening — `expect_equal()`'s default is `sqrt(.Machine$double.eps)`,
about `1.49e-8`. Every other deletion is a `suppressWarnings()` wrapper line, a
comment, a blank line or the `jk1_scale` assignment. Both rewritten blocks
carry the full set at the standing values:

| Quantity | Test-spec | JK1 (lines 144–147) | JK2 (lines 201–204) |
|---|---|---|---|
| Point estimate | `1e-10` | `1e-10` | `1e-10` |
| Standard error | `1e-8` | `1e-8` | `1e-8` |
| `ci_low` | `1e-6` | `1e-6` | `1e-6` |
| `ci_high` | `1e-6` | `1e-6` | `1e-6` |
| `survey`'s stored scale | `1e-8` | `1e-8`, line 139 | `1e-8`, line 196 |

No violation.

## Settled conventions

- **Decision S4, the stored-scale comment.** `grep -c -F` on the full literal
  with the two-space indent returns 10, and the line measures 99 characters.
  The two new ones are character-identical to the eight the base carried.
- **Finding N1, `mse` to both sides.** JK1: constructor line 115, `svrepdesign`
  line 127. JK2: constructor line 172, `svrepdesign` line 184. The JK2
  constructor-side `mse = TRUE` is added by this PR — the N1 fix landing. The
  parse walk confirms all 10 `svrepdesign` calls in the file receive `mse`.

## Scope, gates, coverage

`git diff --name-only bf47f79 HEAD` lists
`tests/testthat/test-variance-replicate.R` and nothing else. The plan's Files
touched names that one file. Match.

Gates read from `logs/pr4/runner.log` on tree `77ba0ec4`, the head tree:
`document()` wrote nothing; `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 11982 ]`;
examples clean; build clean; `R CMD check --as-cran` `Status: 2 NOTEs`, the
two pre-approved ones (`CRAN incoming feasibility` and `hidden files and
directories`), both present on the baseline; `covr` 96.15%.

The pkgdown skip is allowed. The write surface touches no file under `R/`, no
vignette, no `README`, no `_pkgdown.yml` and no `DESCRIPTION`, and the
`NAMESPACE` diff is empty, so the hard rule on export changes does not apply.

Coverage: 96.15%, flat against the baseline and against PR 3. Above the 95%
floor. The PR adds no source line, so there are no new lines to leave
uncovered.

CRAN cookbook: `audit.md` reports None, and the audit verdict is PASS. The scan
target set is empty because no `R/` file changed; the 48 added lines were
scanned for the file-agnostic patterns with zero hits.

## Comprehension alignment

Four `comprehension.md` gotchas reach this PR, and each is carried into an
artifact the builder or tester works from:

| Gotcha | Where it lands |
|---|---|
| G3 — the point estimate cannot detect a scale defect | `test-spec.md` row 5.2; proved above |
| G4 — JK2 warns even when the caller supplies nothing | `spec.md` §V.3; row 3.1.3 |
| G4b — `survey`'s `rho` warning names JK1 for five types | `spec.md` §V.2's "do not match on `JK1` alone"; honoured by the fragment |
| G12 — both packages build the bound from the normal distribution | `test-spec.md` §8's bound premise |

G1 (no typed condition from `survey`) is reconciled in `spec.md` §IV.3 and §VI.
No gap.

## Cross-consistency notes

`implementation.md` and `audit.md` agree everywhere they overlap, and my own
measurements agree with both. Three independent instruments now report the same
call inventory for row 2.2 — the builder's `getParseData()` walk, the tester's
`awk` depth walker and my `parse()` walk — at 10 calls and 0 with `scale`.

One point where the builder's wording is loose and the outcome is right.
`spec.md` §V.2 removal 1 says "the two lines that compute `(n_rep - 1L) /
n_rep`", but only one line computed it; the second removed line was its
explanatory comment. Row 2.25 asks for zero computing lines, which is what
shipped. Not a defect in either artifact.

## Observation — line 174 carries no explicit tolerance

`expect_equal(sc@variables$scale, 1)` at line 174 asserts **surveycore's**
stored scale. `spec.md` §IV.3 item 5, `test-spec.md` §3.2 item 5 and §8 all
scope the stored-scale tolerance to `survey`'s value, so none of them reaches
this line, and quality gate 7 does not either. The line is unchanged from the
base, and the plan's criterion 4 says the block **keeps** it.

**It should carry `tolerance = 1e-8`, and that is not this PR's business.** The
argument for adding it is symmetry: line 196 two assertions later asserts the
same quantity on the other side at `1e-8`, and a reader who meets one bare and
one guarded will wonder which is deliberate. The argument for leaving it is
that the value is a literal `1` set by a `switch()` arm, so the default
tolerance of about `1.49e-8` can never be the thing that decides the
assertion — there is no numerical risk to close. On that balance it is a
readability note, not a defect, and the plan told the builder to keep the line
as it found it. Record it for PR 9's sweep, or for a later arc; do not reopen
PR 4 for it.

## Decision

PASS. The three removals of §V.2 and the six requirements of §V.3 all hold in
the delivered blocks; the fragments are specific and `fixed = TRUE` closes the
metacharacter hazard; no tolerance was widened or dropped; the write surface is
the one file the plan names; every gate passes on the head tree with coverage
flat at 96.15%. Rows 5.1, 5.2 and 5.3 — the arc's power proof, which no other
agent could settle — are established both by the internal arithmetic of the
builder's record and by my own re-run, which reproduced `FAIL 3` with the same
three assertions and the same values and reverted clean to `FAIL 0 | PASS 143`.
