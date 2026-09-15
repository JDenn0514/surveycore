# Audit — PR 5 — fix/restrict-to-domain-coercion

**Verdict**: PASS
**Date**: 2026-09-15 (commit `ead5691`, tree `50b9a88`)

Scope audited: `test-spec.md` §5, rows 5.1 to 5.5 only. §6 belongs to PR 6.

---

## Per-Test Result Table

All five rows assert classes, row counts and structure. §Tolerances of the
test-spec states that no tolerance applies to section 5, so every comparison
below is exact (`expect_identical()`). No tolerance was changed.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 5.1 `as_svydesign() keeps only the marked rows of a logical Taylor marker` — nrow, rownames, marker all TRUE | 3 expectations pass | rows equal `which(mask)` | exact | ✓ |
| 5.2 `as_svydesign() drops an NA marker row on the Taylor route` — nrow equals `sum(pair$mask)` | 148 | 148 | exact | ✓ |
| 5.2 — rownames, NA rows absent, no NA marker survives | 5 expectations pass | — | exact | ✓ |
| 5.3 `as_svydesign() voids rather than removes the excluded two-phase rows` — `nrow(phase1$sample$variables)` and `length(prob)` | 74, 74 | `sum(subset)` = 74 | exact | ✓ |
| 5.3 — `sum(is.finite(prob))` equals `sum(mask & subset)` | 52 | 52 | exact | ✓ |
| 5.3 — `in_domain_and_phase2 < sum(mask)` | 52 < 149 | strict | exact | ✓ |
| 5.4 `as_svydesign() drops an NA marker row on the replicate route` — nrow, rownames, NA rows absent, `nrow(repweights)` | 148 rows, 148 repweight rows | 148 | exact | ✓ |
| 5.5 `as_svydesign() keeps every row of a design with no marker column` — `expect_no_condition`, nrow, rownames | 50 rows, unchanged | 50 rows | exact | ✓ |

Baseline run on the shipped code: 5 of 5 blocks pass, 21 expectations,
0 failures, 0 errors. That agrees with the +21 PASS delta in gate 2.

### Row 5.3 and the documented test-spec correction (D25)

The §5 preamble says `sum(mask)` gives the expected count for rows 5.2 to 5.4,
and row 5.3 asks for "the count of finite probabilities equals the count of
TRUE elements". `decisions.md` D25 records that this is wrong for row 5.3.

Measured independently at tree `50b9a88`, R 4.6.1, `survey` 4.4-2, on the
`make_domain_pair("twophase")` fixture:

| Quantity | Value |
|---|---|
| `sum(pair$mask)` (in-domain rows) | 149 |
| `sum(df$subset)` (phase-2 rows) | 74 |
| `sum(pair$mask & df$subset)` | 52 |
| `sum(is.finite(prob))`, `method = "full"` | 52 |
| `sum(is.finite(prob))`, `method = "approx"` (the fixture's own design) | 74 |
| class, `method = "approx"` | `twophase`, `survey.design` |
| class, `method = "full"` | `twophase2`, `survey.design` |

My measurement agrees with D25 in every figure. The two-phase route removes no
row and writes `Inf` into an excluded row's probability, and a row outside
phase 2 already carries an infinite probability. So the finite count is
`sum(mask & subset)` = 52, and not `sum(mask)` = 149. The block asserts 52.

This is a documented correction to a defective test-spec row, and not a
relaxed tolerance. No entry in §Tolerances was touched. The correction
tightens: 149 is not reachable on this route by any implementation, and 52 is
reachable only by a correct restriction.

**The expectation is derived, not hardcoded.** The block computes
`in_phase2 <- sum(df$subset)` and
`in_domain_and_phase2 <- sum(pair$mask & df$subset)` from the fixture frame it
reads in the same block. No literal count appears.
`expect_lt(in_domain_and_phase2, sum(pair$mask))` proves on the data that the
two candidate expectations are different numbers, so the row cannot pass by
the two counts coinciding.

**The block is honest about the `approx` gap (issue #276).** It builds a
`method = "full"` design from the fixture's frame and marker. Its comment
states in full that `make_domain_pair("twophase")` ships `method = "approx"`,
that `.restrict_to_domain()` tests `inherits(converted, "twophase2")`, that an
`approx` object fails that test and comes back unrestricted, and that the gap
is deliberately not pinned here. No assertion in the block touches the
`approx` route, and nothing in it reads as covering that route. I confirmed
the gap myself: `as_svydesign()` on the fixture's own `approx` design reports
74 finite probabilities, which is the unrestricted phase-2 count.

One staleness, not a defect: the comment says the gap "is raised as a HOLD
against this PR". D25 settled that HOLD and filed it as issue #276. The
comment names no issue number.

---

## Non-vacuity probe

Rows 5.2 to 5.4 are regression rows and held before the production change. A
regression row is worth nothing if it also holds under a broken helper, so I
replaced `.restrict_to_domain()` in the loaded namespace and re-ran the five
blocks unchanged. The probe copy was deleted afterwards;
`git status --porcelain R/ tests/` prints nothing.

| Block | Shipped helper | Break A: helper returns `converted` unchanged | Break B: helper always drops row 1 |
|---|---|---|---|
| 5.1 | 3 pass | 3 fail | 3 fail |
| 5.2 | 5 pass | 4 fail | 4 fail |
| 5.3 | 4 pass | 1 fail (`sum(is.finite(prob))` 73 against 52) | 1 fail |
| 5.4 | 5 pass | 4 fail | 4 fail |
| 5.5 | 4 pass | 4 pass (correct: a design with no marker must come back unchanged) | 2 fail |

Every row fails under at least one break. Row 5.5 pins the early return on the
name test. It cannot fail under Break A, because Break A is the right answer
for a design with no marker column, so Break B is the break that matters for
it, and it fails there. Row 5.3 fails under Break A by the margin D25
predicts.

---

## Directed checks from the dispatch

| Check | Result |
|---|---|
| All five blocks call `skip_if_not_installed("survey")` inside the block | PASS — line 2 of each block; `test-conversion.R` carries no file-level skip |
| `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` | PASS — no match. The only `as.logical` left in `R/methods-conversion.R` is the word inside the new comment |
| `r & !is.na(r)` survives | PASS — `R/methods-conversion.R:85` reads `converted[r & !is.na(r), ]`, with `r <- frame[[SURVEYCORE_DOMAIN_COL]]` above it |
| `grep -rn "no validator checks its type" R/` | PASS — no match |
| The replacement note states both facts | PASS — the `survey_base` validator rejects every type but logical "on construction and on every later write to `@data`" (issue #262), and `!is.na(r)` "stays, and is still load-bearing" because the validator forbids a non-logical column but does not forbid `NA` |
| No new `test_invariants()` call (§Invariants) | PASS — the diff adds none |
| Snapshots | Untouched. Correct: §5 asserts structure, not CLI text |
| Two older comments that cited `as.logical()` as load-bearing | Both rewritten to name the validator; both now match the shipped code |

---

## Before/After Comparison

The Before column is the dispatch baseline at `b2fa7e1` (the `origin/develop`
tip). It was not reconstructed.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11891 | 11912 | +21 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 (the pre-existing AAPOR small-cell warnings, D12) |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0 |
| R CMD check notes | 2 | 2 | 0 |
| R CMD check errors / warnings | 0 / 0 | 0 / 0 | 0 |

Coverage holds at 96.15%, above the 95% BLOCK floor and unchanged, so no HOLD
is due. `R/methods-conversion.R` is at 99.77%. Its one uncovered line, 636, is
`} # nocov` inside `.find_col_by_value()`, outside `.restrict_to_domain()`. I
confirmed that by reading lines 630 to 640. Every line of
`.restrict_to_domain()` is covered.

The covr line "changed R/ files: 3" is the known stale-`develop`-ref artifact
(D22). The true changed-`R/` set is one file, `R/methods-conversion.R`,
confirmed by `git diff b2fa7e1..HEAD --name-only`.

---

## Profile gates

The gates ran before dispatch under the low-memory rule and were not re-run.
Logs: `.surveycore-workspace/runs/2026-09-12-domain-marker-logical/gates/pr-5/`.
The table is copied from `gates/pr-5/summary.log`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | `FAIL 0 | WARN 256 | SKIP 4 | PASS 11912` |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | `surveycore_1.1.0.9000.tar.gz` |
| R CMD check --as-cran | PASS | Status: 2 NOTEs, reviewed below |
| pkgdown | PASS | site built |
| covr | PASS | 96.15% |
| CRAN cookbook scan | PASS | no violations |

Tree: 50b9a88eb887d975eb7175feff43f04441f1925c

NOTE review, read from `gates/pr-5/gate-5-check.log`:

1. `checking CRAN incoming feasibility` — on the pre-approved list in
   `.claude/rules/r-package-conventions.md`.
2. `checking for hidden files and directories`, reporting `.git` — caused by
   the worktree layout, present on clean `develop`, recorded as pre-existing
   in `archive/as-svydesign-bridge/`. This PR neither causes it nor can fix
   it.

Neither NOTE changed in count or in text across the PR.

---

## CRAN cookbook violations

| File | Line | Violation | Class |
|---|---|---|---|

None. I scanned the added lines of `R/methods-conversion.R`, the only changed
`R/` file, against all nine patterns in
`r-package-profile.md §CRAN cookbook scan`, then scanned the whole file for
the seven patterns that can sit outside a diff. Zero hits.

Style: two added `test_that()` description lines run to 83 characters. `air`
does not break a string literal, so this is not an `air` finding, and 96 lines
of the pre-PR `test-conversion.R` are already over 80 for the same reason.

---

## BLOCKs

None.

## HOLDs

None. D25 answers the only open question in §5, and my own measurement
reproduces every figure in it.

## For the reviewer

One non-blocking observation, recorded above: the two-phase block's comment
says the `approx` gap "is raised as a HOLD against this PR". D25 settled that
HOLD and filed issue #276. A later reader of the comment has no issue number
to follow.
