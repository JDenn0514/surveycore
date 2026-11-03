# Audit — PR 7 — test/replicate-oracle-other

**Verdict**: PASS. Every profile gate passes on this tree, and the three
allocated rows the tester can measure pass. Three further rows are deferred
to the reviewer, not passed and not failed. See §Deferred rows.
**Date**: 2026-09-22
**Branch**: `test/replicate-oracle-other` at `c8cb70b`
**Base**: `f127082`
**Diff**: `+59/-0`, one file, `tests/testthat/test-variance-replicate.R`,
append-only with zero deletions (`git diff --stat f127082 HEAD`).

Tree: 11b2f6b7485aa15ea5945d219918b3fc69fbe5d9

---

## Instruments

The tester ran no R. Every count below is textual, and the instrument is
named per row. The gate figures in §Profile gates come from the leader's
detached pass on this same tree.

| Instrument | What it is | Where used |
|---|---|---|
| I1 — awk comment-stripper | An awk script that removes `#` to end of line while it respects single and double quoted strings, and keeps one output line per input line so line numbers hold | All construct counts |
| I2 — `grep -Fxc` on the exact 99-character comment | Exact whole-line match against the one stored-scale comment string | Row 2.18 count |
| I3 — `sed -n` plus `awk 'length($0)==99'` | Reads the single line above each assertion and its width | Row 2.18 placement |
| I4 — `git diff` / `git show` | The diff and the base copy of the file | Diff shape, base counts |
| I5 — `air format --check` (CLI, not R) | Formatter conformance on the one touched file | Format conformance |

**I1 validated against the two known trap counts in the dispatch.** The
stripper reproduces both:

| Token | `grep -c` (raw text) | I1 (code only) | Dispatch says |
|---|--:|--:|--:|
| `expect_failure` | 12 | **6** | 6 |
| `svrepdesign(` | 15 | **13** | 13 |

Both agree, so I1 is trustworthy for the remaining counts.

---

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| Row 2.17 — JK1, JK2 and `other` each assert exactly one warning | 3 of 3 | 3 of 3 | exact count | ✓ |
| Row 2.18 — stored-scale comments, count | 13 | 13 | exact count | ✓ |
| Row 2.18 — each comment carries all three elements | 13 of 13 | 13 of 13 | exact | ✓ |
| Row 3.1.8 — `other` block asserts one warning with the named fragment | 1 warning, fragment `scale or rscales not specified, set to 1`, `fixed = TRUE` | same | exact | ✓ |
| Row 3.1.8 — point estimate assertion | `tolerance = 1e-10` | `1e-10` | 1e-10 | ✓ |
| Row 3.1.8 — standard error assertion | `tolerance = 1e-8` | `1e-8` | 1e-8 | ✓ |
| Row 3.1.8 — both confidence bounds | `tolerance = 1e-6` on `ci_low` and `ci_high` | `1e-6` | 1e-6 | ✓ |
| Row 3.1.8 — `survey`'s stored scale against `1` | `expect_equal(sv$scale, 1, tolerance = 1e-8)` | `1` at `1e-8` | 1e-8 | ✓ |
| Row 3.1.8 — no `expect_failure()` wrapper in the block | 0 wrappers | 0 | exact | ✓ |
| Row 3.1.8 — fixture mode and `R` | `type = "jk1"`, `n_psu = 20` → `R = 20` | `jk1`, `R = 20` | exact | ✓ |
| Row 3.1.8 — no `rscales` to either side | absent on both sides | absent | exact | ✓ |
| Row 4.1 | not measured | difference `0` | n/a | deferred |
| Row 4.2 | not measured | factor `sqrt(2)`, above `1e-8` | n/a | deferred |
| Row 4.3 | not measured | both bounds move, above `1e-6` | n/a | deferred |

**No tolerance was changed, widened or substituted.** Every tolerance in the
table is the literal read out of the delivered file, compared against
`test-spec.md` §8 and §3.1.

---

## Row 2.17 — evidence

Instrument I1. The file holds three `capture_warnings()` calls, three
`expect_length()` calls and three `expect_match()` calls in code, and **zero**
`expect_warning()` calls. The three triples sit one per fragment-matching
block, and each `capture_warnings()` wraps the design-building
`survey::svrepdesign()` call:

| Block | Title line | `capture_warnings` | `expect_length` | `expect_match` |
|---|--:|--:|--:|--:|
| JK1 | 96 | 122 | 131 | 132 |
| JK2 | 150 | 179 | 188 | 189 |
| `other` | 967 | 998 | 1007 | 1008 |

Each count assertion is `1L`, not a bare match:

```r
  expect_length(jk1_warnings, 1L)
  expect_length(jk2_warnings, 1L)
  expect_length(other_warnings, 1L)
```

The fragment match follows the count in each block, with `fixed = TRUE`:

```r
  expect_match(
    other_warnings,
    "scale or rscales not specified, set to 1",
    fixed = TRUE
  )
```

`suppressWarnings` appears zero times in code (I1), so nothing hides a
condition. **3 of 3. Row 2.17 passes.**

---

## Row 2.18 — evidence

Instrument I2 for the count, I3 for the placement, I1 for the denominator.

- `sv$scale` assertions in code: **13** (lines 44, 85, 139, 196, 270, 345,
  434, 476, 518, 560, 855, 931, 1015). So the denominator is 13, which
  matches `test-spec.md` §3.2's 13 numerical oracle blocks.
- `grep -Fxc` on the exact comment string: **13** on this branch, **12** on
  the base `f127082`. The PR adds exactly one.
- I3 on each of the 13: the line immediately above every assertion is that
  exact string, and it is 99 characters wide. 13 of 13, no exception.

The comment, read once in full, carries all three required elements:

```r
  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
```

| Element §2.18 requires | The text that supplies it |
|---|---|
| The assertion guards `survey`'s own default | `Guards survey's default` |
| A failure means `survey` changed, not that surveycore regressed | `a failure means survey changed, not surveycore` |
| The tolerance is the standard-error and variance row | `SE/variance row, 1e-8` |

All 13 comments are the same string, so all 13 carry all three. **13 of 13.
Row 2.18 passes.**

The 99-character width is over the 80-column limit and is not reported as a
defect: decisions S4 and S5 settle it, and `air format --check` passes on the
file (I5, exit 0) because `air` does not rewrap comments.

**Not among the 13 — recorded, not judged.** Three lines assert
*surveycore's* own stored scale and read `sc@variables$scale`, not `sv$scale`:
lines 174, 379 and 400. None of the three carries an explicit `tolerance`
argument. Row 2.18 counts `survey`'s stored scale only, so these three are
outside it. The dispatch records one of them as finding N2, known and
deliberately untouched. This PR adds none of them and edits none of them.

---

## Row 3.1.8 — evidence

The whole block is new, lines 967–1024. Delivered lines quoted:

```r
test_that("get_means() replicate SE matches survey::svymean() — other design", {
  skip_if_not_installed("survey")
```

Fixture — mode `jk1`, and `R = 20`:

```r
  d <- make_survey_data(
    n = 200, n_psu = 20, n_strata = 4, design = "replicate",
    type = "jk1", seed = 15
  )
```

The fixture arguments are byte-identical to the JK1 block's (lines 99–107),
which `test-spec.md` §3.1 also fixes at `R = 20`. `R = 20` is confirmed
structurally, without running R: `tests/testthat/helper-test-data.R` sets the
replicate count with a `switch()` in which `jk1` falls through to `n_psu`
(`jk1 = ,` … default `n_psu`), against `n_psu %/% 2L` for BRR and Fay. With
`n_psu = 20`, `R = 20`.

Both sides, same inputs, `mse` explicit to each, no `scale` and no `rscales`
to either:

```r
  sc <- as_survey_replicate(
    d, weights = wt, repweights = all_of(repwt_cols),
    type = "other", mse = TRUE
  )
  other_warnings <- testthat::capture_warnings(
    sv <- survey::svrepdesign(
      weights = d$wt, repweights = d[, repwt_cols],
      type = "other", mse = TRUE, data = d
    )
  )
```

The five assertions of §3.2, all present, each on its own tolerance row:

```r
  expect_equal(sv$scale, 1, tolerance = 1e-8)
  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
```

`expect_failure` count inside the block: **zero** (I1). The six wrappers in
the file sit at lines 865, 868, 871 (JKn block, opens 806) and 942, 949, 952
(bootstrap block, opens 886). None is at or after line 967. This matches
§3.1.8's "yes" in the agree column: the two sides agree for `other`, so the
block is unpinned.

**Row 3.1.8 passes on both halves.** The textual half is proved above: the
five assertions are present, aimed at the right quantities, and carry the
tolerances §8 names. The numerical half is proved by gate 2 on this exact
tree, `FAIL 0` with 12003 passes. That distinction carries more weight here
than on the two pinned blocks: the `other` block has no `expect_failure()`
wrapper, so its assertions have to pass on their own rather than being
consumed by a wrapper.

---

## Deferred rows — 4.1, 4.2, 4.3

**Not independently verifiable by the tester; the evidence is the builder's,
for the reviewer to check.**

Why. `test-spec.md` §4 says the probe runs in a scratch script and needs no
change to the package. It is therefore not a property of the delivered file,
and no assertion in the diff carries it. Re-running it needs R, and the
dispatch forbade starting any R process while the leader's gate pass was in
flight on this tree. The scratch script is deliberately absent from the
repository, so there is nothing textual to read either. These three rows are
neither passed nor failed here. The reviewer reads `implementation.md` and
settles them.

**What the tester can state — the delivered block is the sensitive shape.**
§4's arithmetic says a wrong stored scale leaves the point estimate untouched
and moves only the standard error and the bounds. A block that asserted the
point estimate alone would therefore be blind to a scale defect. The `other`
block asserts all four quantities — point estimate, standard error, lower
bound, upper bound — plus `survey`'s stored scale, five of five. So it is not
blind by construction.

**No contradiction found with the numbers the dispatch quotes.** Set against
the tolerances the block actually carries:

| Builder's probe figure | The block's tolerance | Margin |
|---|---|---|
| `Δ mean` exactly `0` on all eight types | `1e-10` on the point estimate | agreement is exact; the point estimate cannot see the scale |
| SE ratio `sqrt(2)` to within one machine epsilon, `2.22e-16` | — | consistent with the scale entering the variance only |
| Smallest SE move `0.0228` | `1e-8` on the standard error | about six orders of magnitude above |
| Smallest bound move `0.0447` | `1e-6` on each bound | about four and a half orders above |

Every figure is consistent with the delivered assertions and with §3.2. None
of it is the tester's own measurement.

---

## Conformance checks alongside the allocated rows

| Check | Source | Result |
|---|---|---|
| `test_invariants(` appears exactly once in the file | §10 verdict rule, row 2.19; `testing-surveycore.md` | ✓ 1 occurrence, line 31, in the file's first `as_survey_replicate()` block. The new block does not repeat it (I1). |
| No third file in the diff | §10 verdict rule | ✓ one file, `tests/testthat/test-variance-replicate.R` (I4) |
| Append-only, zero deletions | dispatch | ✓ `+59/-0` (I4) |
| `mse` passed explicitly to both sides | oracle rule 1; dispatch | ✓ `mse = TRUE` on both |
| `scale` passed to neither side | oracle rule 2 | ✓ absent from both calls in the block |
| `rscales` not passed for a non-JKn type | oracle rule 3 | ✓ absent |
| `survey`'s condition asserted, not silenced | oracle rule 5 | ✓ `capture_warnings()`, and `suppressWarnings` appears 0 times in code |
| Message text, not class, matches the condition | `testing-surveycore.md`; §10 "do not BLOCK" | ✓ `expect_match(..., fixed = TRUE)`; the absent `class =` is correct here |
| `air format --check` on the touched file | row 2.14's authority; §9 note 6 | ✓ exit 0 (I5) |

---

## CRAN cookbook violations

None.

The write surface holds no file under `R/`. The scan ran anyway over the 59
added lines, comment-stripped with I1, for every pattern in
`r-package-profile.md §CRAN cookbook scan`: `T`/`F` as logicals,
`set.seed(`, bare `print(`/`cat(`, `options(warn = -1)`,
`installed.packages(`, `<<-`, unrestored `par(`/`options(`/`setwd(`, writes to
`getwd()` or `~`, and more than two cores. Zero hits on all ten.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | none | — |

---

## Profile gates

The leader ran the whole set as one detached pass on tree
`11b2f6b7485aa15ea5945d219918b3fc69fbe5d9` — the tree the `Tree:` line above
records. This agent started no R process, not even a one-line probe: two
agents running R at once corrupted a whole log set on an earlier arc.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | `document()` wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12003 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran --no-manual` | PASS | Status: 2 NOTEs |
| pkgdown | SKIPPED — scope | one test file; `NAMESPACE` diff empty |
| `covr` | PASS | 96.15% |
| CRAN cookbook scan | PASS | zero violations, measured above |
| `air format --check` | PASS | exit 0 on `tests/testthat/test-variance-replicate.R` (CLI, not R) |

Logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr7/`

**The pkgdown skip is within the documented condition.** The write surface is
one file under `tests/`. It touches no file under `R/`, no vignette, neither
README, not `_pkgdown.yml` and not `DESCRIPTION`. The hard no-skip rule does
not fire either: the `NAMESPACE` diff is empty, so no export was added,
removed or renamed.

**Both NOTEs are pre-existing. Read gate 5 as "2 NOTEs, and these two".**

| NOTE | Why it does not block |
|---|---|
| `checking CRAN incoming feasibility` | Pre-approved in `r-package-conventions.md`; the package is not on CRAN |
| `checking for hidden files and directories` | `R CMD build` finds `.git`; `.Rbuildignore` causes it. Present on the clean baseline and unfixable by this arc |

Both appear identically on the baseline and on PRs 1 to 6. The second is not
a new pattern and needs no escalation. A **third** NOTE would block.

**`WARN 256` reads as "no new warning"** (§9 note 3). Those are the
pre-existing unasserted small-cell warnings, issue #167, and the count is
unchanged from the baseline. Not this PR's work.

Tree: 11b2f6b7485aa15ea5945d219918b3fc69fbe5d9

---

## Before/After Comparison

The Before columns come from `baseline.md` at `7800ea9` and from the arc
chain the dispatch supplies. The After column comes from the gate pass on
this tree. The pre-PR state was not reconstructed: no `git stash`, no
`git apply`, no checkout of an older tree.

| Metric | Baseline (`7800ea9`) | PR 6 | This PR | Δ vs PR 6 |
|---|---|---|---|---|
| tests passing | 11941 | 11996 | 12003 | **+7** |
| failures | 0 | 0 | 0 | 0 |
| warnings | 256 | 256 | 256 | 0 |
| skips | 4 | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 96.15% | 0.00 |
| R CMD check notes | 2 pre-approved | 2 | 2 | 0 |

Coverage is flat, as §9 note 2 expects: the PR adds test code and no source
line. It sits above the 95% floor, so no HOLD applies. No regression in
tests-passing, failures, skips or notes.

---

## BLOCKs

None.

---

## Tally

| Allocated row | Outcome |
|---|---|
| 2.17 | verified directly — pass |
| 2.18 | verified directly — pass |
| 3.1.8 | verified directly — pass |
| 4.1 | deferred to the reviewer |
| 4.2 | deferred to the reviewer |
| 4.3 | deferred to the reviewer |

Three of six verified directly. Three deferred. Zero failed. No tolerance
touched. All gates pass.
