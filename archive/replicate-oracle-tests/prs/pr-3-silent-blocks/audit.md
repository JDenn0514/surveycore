# Audit — PR 3 — silent-blocks

**Verdict**: PASS (7 of 7 allocated rows)
**Date**: 2026-09-22 10:32 (gates pasted in 2026-09-22 10:58)
**Branch**: `test/replicate-oracle-silent-blocks`
**Range read**: `git diff e61518a HEAD`
**Diff size**: +90 / -48 in one file

Tree: `2ac094bf91835d3af71e31aab10bc28e19882c15`

## Scope

This audit judges seven rows and no others: §2 rows 2.13, 2.14, 2.19, 2.24 and
§3.1 rows 3.1.1, 3.1.6, 3.1.7. Rows §3.1.2 and §3.1.3 (JK1, JK2) belong to PR 4
and still breach the oracle rule on this tree — the JK1 block passes a `scale`
argument at line 123 and both blocks wrap the `survey` call in
`suppressWarnings()` at lines 119 and 162. This PR was told not to touch them,
so they are recorded here and not counted against it. Rows §3.1.4, §3.1.5,
§3.1.8, §3.1.9, all §4 and §5 rows, the remaining §2 rows and every §6 row
belong to other PRs in the arc.

**The eight blocks this PR edited**, by line number on HEAD: 12 and 55 (BRR
means, BRR totals), 212 (BRR `mse = FALSE`), 282 (BRR `n_rep != 4`), 376 and
418 (successive-difference means, totals), 460 and 502 (ACS means, totals). The
diff carries exactly eight hunks and every one lands in one of those eight
bodies.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 2.13 — write surface lists no third file | `tests/testthat/test-variance-replicate.R` (1 entry) | no third file appears | n/a | ✓ |
| 2.14 — `air format --check` on the touched file | exit 0, no output, `air 0.11.0` | pass | n/a | ✓ |
| 2.19 — `test_invariants(` count and placement | 1 hit, line 31, inside the block opened at line 12 | 1 hit, in the BRR means block | n/a | ✓ |
| 2.24 — no block hard-codes a replicate count | every block derives `R` from `repwt_cols`; 0 literal counts | pass | n/a | ✓ |
| 3.1.1 — BRR stored scale, four blocks | lines 44, 85, 243 `1 / length(repwt_cols)`; line 318 `1 / n_rep` | `1 / R` | 1e-8 | ✓ |
| 3.1.6 — ACS stored scale, two blocks | lines 491, 533 `4 / length(repwt_cols)` | `4 / R` | 1e-8 | ✓ |
| 3.1.7 — successive-difference stored scale, two blocks | lines 407, 449 `4 / length(repwt_cols)` | `4 / R` | 1e-8 | ✓ |

Tally: **7 of 7 pass.** No tolerance in this audit was changed from what
`test-spec.md` states. Every stored-scale assertion carries `tolerance = 1e-8`,
which is the standard-error and variance row §3.2 assertion 5 requires; none
uses `1e-10`.

### Row 2.13 — evidence

```
$ git diff --name-only e61518a HEAD
tests/testthat/test-variance-replicate.R
```

One entry. Per the dispatch, the test-spec's "exactly two files" is the arc's
total write surface across nine PRs, so the per-PR reading is "no third file
appears". One entry satisfies it. The working tree also carries five untracked
`plans/` files and one modified tracked file, `plans/pr-budget-calibration.md`;
those are pipeline bookkeeping and sit outside the commit range read here.

### Row 2.14 — evidence

```
$ air format --check tests/testthat/test-variance-replicate.R
EXIT=0
```

No output and exit 0, so `air` reports the file already formatted. `air` is a
CLI on this machine, not an R package, and the check starts no R process.
Several files repo-wide are already unclean, so the gate reads as "the file this
PR touches passes".

### Row 2.19 — evidence

One `test_invariants(` hit in the file:

```
31:  test_invariants(sc)
```

Line 31 sits inside the body opened at line 12 by:

```
test_that("get_means() replicate SE matches survey::svymean() — BRR design", {
```

The next `test_that(` opens at line 55, so the call is inside the named block.
The file exercises `as_survey_replicate()` only, so one call is the whole
requirement of the once-per-constructor-per-file rule.

### Row 2.24 — evidence

Every block in the file derives its replicate count from the columns it
selected. The pattern at each of the eight edited blocks is:

```
repwt_cols <- grep("^repwt_", names(d), value = TRUE)
```

and the count enters the assertion either as `length(repwt_cols)` (lines 44, 85,
243, 407, 449, 491, 533) or through one named binding (line 297,
`n_rep <- length(repwt_cols) # should be 10 (n_psu / 2)`, used at line 318).

A scan for a literal replicate count returned one hit, and it is not a defect:

```
283:  # Verifies that scale = 1/n_rep (not 1/4) is the correct BRR formula.
```

That is a comment naming the wrong formula the block disproves, not code. Two
further literals, `rep(1L, 5L)` at lines 597 and 611, sit in the Block 16
`.svy_rep_var()` direct-call tests. They match a hand-written five-element
`thetas` vector in the same body, build no `survey` design and read nothing from
the generator, so they are not a generator column count.

The `mse = FALSE` block is the case row 3.1.1 singles out: it builds on
`n_psu = 10` and so gets 5 replicate columns, not 10. Its assertion reads
`1 / length(repwt_cols)` and needs no change when the count moves.

### Rows 3.1.1, 3.1.6, 3.1.7 — the delivered assertions

Eight assertions, each preceded by the same one-line comment. Delivered text,
quoted:

| Line | Block | Assertion |
|---|---|---|
| 44 | BRR means | `expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)` |
| 85 | BRR totals | `expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)` |
| 243 | BRR `mse = FALSE` | `expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)` |
| 318 | BRR `n_rep != 4` | `expect_equal(sv$scale, 1 / n_rep, tolerance = 1e-8)` |
| 407 | successive-difference means | `expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)` |
| 449 | successive-difference totals | `expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)` |
| 491 | ACS means | `expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)` |
| 533 | ACS totals | `expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)` |

Each reads `survey`'s stored scale against a formula literal. None reads the
surveycore design's stored scale, so none is a round trip. The two blocks at
lines 334 and 355 assert `sc@variables$scale` against `4 / n_rep`; they build no
`survey` design, use no oracle, and are untouched by this PR.

The comment above all eight, delivered text:

```
  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
```

Count: 8 hits, one per assertion.

### The two checks the rows imply

**Each of the eight asserts its `survey::svrepdesign()` call raises no
warning.** `expect_no_warning(` appears 8 times in the file — lines 33, 74, 232,
307, 396, 438, 480, 522 — and each wraps the `sv <- survey::svrepdesign(...)`
call of one of the eight blocks. This matches §3.1's "none — the block asserts
no warning fires" for BRR, ACS and successive-difference. Zero is a count, so
these eight need no separate warning-count assertion.

**The `mse = FALSE` block still passes `mse = FALSE` to both sides.** Read by
eye at lines 212 to 251. The surveycore side:

```
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR",
    mse = FALSE
  )
```

The `survey` side, inside the new `expect_no_warning()` wrapper:

```
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "BRR",
      mse = FALSE,
      data = d
    )
```

Both sides read `FALSE`. The wrapper did not flip either one, so the centred
branch of the replicate variance expression keeps its only test.

## The 99-character stored-scale comment

**On content the comment satisfies its row.** It carries all three facts
`test-spec.md` §3.2 assertion 5 and row 2.18 require:

| Required fact | Delivered words |
|---|---|
| The assertion guards `survey`'s own default | `Guards survey's default` |
| A failure means `survey` changed, not that surveycore regressed | `a failure means survey changed, not surveycore` |
| The tolerance is the standard-error and variance row | `SE/variance row, 1e-8` |

**On line length, no row I hold mentions it.** Rows 2.13, 2.14, 2.19, 2.24,
3.1.1, 3.1.6 and 3.1.7 say nothing about columns, and row 2.14 — the one
formatting row in my set — is `air format --check`, which passes at exit 0
because `air` does not rewrap comments. I therefore record the breach and do
**not** BLOCK for it. The rule question belongs to the reviewer.

Measurement, so the reviewer rules on numbers and not on an impression:

| Measure | Value |
|---|---|
| Length of the comment | 99 characters, identical at all 8 sites |
| Limit in `.claude/rules/code-style.md` | 80 characters |
| `.lintr` setting | `line_length_linter(80)`; `exclusions: list("data-raw")`, so `tests/` is in scope |
| Lines over 80 in this file on the base `e61518a` | 11 |
| Lines over 80 in this file on HEAD | 19 |
| Of the 19, added by this PR | 8, all the same comment |
| Is `lintr` one of the seven profile gates? | No — gates 1 to 7 are `document`, `test`, `run_examples`, `build`, `check --as-cran`, `pkgdown`, `covr` |

So the file already carried 11 over-length lines before this PR, three of them
comments. The PR adds 8 more of one kind. No gate in the profile measures column
width, which is why `air` passing and the rule being breached can both be true.

## CRAN cookbook violations

None.

The write surface touches no file under `R/`, so the scan has no target by the
letter of the rule. I ran it on the PR's 90 added lines anyway: zero hits for
`T`/`F` as logicals, `set.seed(`, bare `print(`/`cat(`, `options(warn = -1)`,
`installed.packages(`, `<<-`, `mc.cores >= 3` and `makeCluster(>= 3)`.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | none | — |

## Before/After Comparison

Baseline measured on `develop` at `7800ea9`, before PR 1 of this arc, and
recorded in `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/baseline.md` [no such file].
The pre-PR state was not reconstructed here — no `git stash`, no `git apply`, no
checkout of an old tree.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11941 | 11977 | +36 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00 |
| R CMD check notes | 2 | 2 | 0 |

The +36 expectations are this PR's eight blocks: one no-warning assertion and
one stored-scale assertion in each, plus the single `test_invariants()` call,
which carries several expectations of its own.

Coverage is flat to the hundredth. This PR adds test code and no source line, so
the denominator never moved. 96.15% clears the 95% floor, and a flat reading
triggers neither the HOLD condition (a drop of 0.5 point or more taking coverage
below 98%) nor the BLOCK condition (below 95%).

## Profile gates

Run by the leader on tree `2ac094bf91835d3af71e31aab10bc28e19882c15` — the same
tree this audit's `Tree:` line records, so the results are of the code audited
here and not of a later version.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11977 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs — see below |
| pkgdown | SKIPPED — scope | write surface is one test file; `NAMESPACE` diff empty, so the hard rule on export changes does not bite |
| `covr` | PASS | 96.15% |
| `air format --check` (touched file) | PASS | exit 0, no output, `air 0.11.0` |
| CRAN cookbook scan | PASS | no `R/` file in the write surface; 90 added lines scanned clean |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr3/`

### The two NOTEs — both pre-existing, neither is new

Read gate 5 as "2 NOTEs, and these two". A third NOTE would block.

| # | NOTE | Standing |
|---|---|---|
| 1 | `checking CRAN incoming feasibility` | Pre-approved in `.claude/rules/r-package-conventions.md` and in `r-package-profile.md` §Pre-approved NOTEs. |
| 2 | `checking for hidden files and directories` | `R CMD build` finds `.git`. **Not** on the pre-approved list in `r-package-profile.md`, but it fires on the clean baseline tree with nothing applied, and `.Rbuildignore` causes it. No PR in this arc can fix it. |

Both appeared identically on the baseline run at `7800ea9`. The second is a
pre-existing condition of the repository, not a new pattern this PR introduced,
so it is no ground for escalation.

### What the gate run settles

Rows 3.1.1, 3.1.6 and 3.1.7 claim that the point estimate, the standard error
and both confidence bounds agree with `survey`. This audit proved the assertions
present, correctly targeted and correctly toleranced; gate 2 is what proved they
pass. Gate 2 reports zero failures across 11977 passing expectations, so no
block naming one of those three rows reversed. I started no R process myself —
the leader's pass was already in flight on this tree, and two concurrent R
processes corrupted a whole log set on an earlier arc.

## BLOCKs

None.

## Final state

This audit is final. Verdict **PASS**, 7 of 7 allocated rows, all gates clean or
skipped on scope, no BLOCKs, no HOLDs.
