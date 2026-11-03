# Implementation — PR 1 — as-svydesign-domain-taylor

**Branch**: `fix/as-svydesign-domain-taylor`
**HEAD**: `49e17bbc6cbbcd19fe538878230c7730e76c623f`
**Base**: `a5455054c95092813d337cd9793b790dec99b77b` (verified before any read or write)

## Write surface

- `R/methods-conversion.R` — modified
- `tests/testthat/test-conversion.R` — modified

No other file changed. `devtools::document()` wrote nothing: the helper carries
`@noRd`, so `NAMESPACE` and `man/` are untouched. `plans/error-messages.md`,
`NEWS.md` and `DESCRIPTION` are byte-identical to `develop`.

## Summary

- `.restrict_to_domain(converted)` is new, internal, one argument, under the
  existing `# ── Internal helpers ──` heading. It reads the marker column off
  `converted$variables`, returns `converted` unchanged when the column is
  absent, and otherwise indexes with `[`. It has no two-phase frame branch —
  that belongs to a later PR — and its comment says which class it serves today.
- The row mask is `r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])` then
  `r & !is.na(r)`. `as.logical()` first is what keeps the helper's "raises no
  condition" contract true for a character or factor marker column.
- `.as_svydesign_taylor()` assigns the object `survey::svydesign()` builds to
  `converted`, then returns `.restrict_to_domain(converted)`. Signature
  unchanged. The input design `x` is not touched, and no other route changed.
- The change reaches two input shapes through one call site: a `survey_taylor`
  design, and a `survey_nonprob` design that names no replicate weights, which
  `as_svydesign()` dispatches here after its SRS warning.
- `tests/testthat/test-conversion.R` gains one fixture and 14 blocks under a new
  `# ── Domain restriction on the Taylor route ──` heading: four parity blocks,
  two baseline blocks, one input-unchanged block, three round-trip blocks, one
  `expect_no_condition()` block, and four marker-column edge-case blocks
  (five column types, an unconvertible factor, an `NA` row, an all-`FALSE`
  marker).

## Task checklist

- [x] 1. Cut `fix/as-svydesign-domain-taylor` from `develop` at the stated sha
- [x] 2. Failing test for the Taylor parity scenario, hand-marked domain —
  confirmed failing on the old behaviour: 50 rows against 25, mean 50.1
  against 58.2, SE 1.46 against 0.57
- [x] 3. `.restrict_to_domain(converted)`, one argument, presence check, `[`
- [x] 4. Row mask with `as.logical()` first, then `r & !is.na(r)`
- [x] 5. One call site in `.as_svydesign_taylor()`, immediately before the return
- [x] 6. Task-2 test passes
- [x] 7. Parity on a `surveytidy::filter()` marker and on `nhanes_2017` — both
  pass with no further code change
- [x] 8. Filtered `survey_nonprob` design naming no replicate weights, warning
  captured off the call, marker column present and every value `TRUE` — see
  the signal below on the standard error
- [x] 9. Unfiltered baseline, and an all-`TRUE` marker
- [x] 10. Input design's row count and marker column unchanged; second call
  returns the same row count
- [x] 11. Three round-trip blocks
- [x] 12. `expect_no_condition()` on a filtered Taylor conversion
- [x] 13. `devtools::document()` run — no output file changed

Beyond the task list, and inside the write surface: four edge-case blocks for
the marker column's type, an `NA` row and an empty domain. Nothing else guarded
the `as.logical()` call that task 4 names load-bearing.

`air format --check` passes on both files.

## Signals raised

**HOLD — acceptance criterion 1, the non-probability clause only.** AC-1 asks
for SE agreement to 1e-8 on a filtered `survey_nonprob` design that names no
replicate weights. That agreement does not hold, and the cause sits outside
this write surface.

Measured on the file's 40-row `make_nonprob("plain")` fixture with a 20-row
domain:

| Quantity | Value |
|---|--:|
| `get_means()` SE | 1.235709 |
| `survey::svymean()` SE on the converted object | 1.219763 |
| ratio | 1.013072 |
| `sqrt((20/19) / (40/39))` | 1.013072 |

`.calibrated_mean_cell()` at `R/analysis-means-helpers.R:288` takes its finite
correction from the domain size, `n_d / (n_d - 1)`. `survey`'s `[` keeps each
retained row's recorded stratum sample size, so `survey::svymean()` takes the
same correction from the full sample, `n / (n - 1)` — and so does surveycore's
own `.taylor_mean_cell()`. The two standard errors stand in exactly that ratio.

Three facts place the difference in the fallback estimator and not in this
change:

1. The point estimate agrees to 1e-10 on that design.
2. The identical frame with the identical domain, built with `as_survey()`
   instead of `as_survey_nonprob()`, agrees with the same 20-row converted
   object to 1e-8. The test block asserts this cross-check.
3. The unfiltered agreement is unchanged — the pre-existing block "reproduces a
   plain nonprob's mean and SE" still passes at 1e-8.

`subset()` would give the same numbers, because `subset.survey.design2` calls
`x[r, ]`, so this is not a consequence of D1's choice of operator.

The fix would edit `R/analysis-means-helpers.R`, which is outside the write
surface, and it would change a number the analysis suite pins today. So the
block asserts the ratio identity above rather than a tolerance, which pins the
present behaviour of both estimators and fails loudly if either moves. The
other three parity scenarios in AC-1 hold as written. Someone with authority
over the analysis path should decide whether the fallback's domain-based
correction is a defect; it looks like a sibling of issue #262.

## Notes for tester

- `surveytidy` is installed on this machine, so the `filter()`-marker block runs
  rather than skips. It carries its own `skip_if_not_installed("surveytidy")`.
- Two blocks pass `min_cell_n = 1L` to `get_means()`. The domains hold 25 and 20
  rows against a default threshold of 30, and the argument keeps the pre-existing
  AAPOR small-cell warning out of a block that is not about it. It does not
  affect the estimate.
- The `nhanes_2017` block uses a hand-written marker, so it needs `survey` only.
- I ran `devtools::test(filter = "conversion")` and `devtools::document()`. Per
  the dispatch instruction on this memory-constrained machine I ran no full
  suite, no `devtools::check()`, no `covr` and no `pkgdown`.

---

## BLOCK 1 — resolved

**Date**: 2026-09-10
**Commit**: `a65674e0511ebc76a99d9d52fd3164418337de09`
**Classification**: incomplete-test. Test-only fix; no production code changed.

The unfiltered-Taylor conversion block called `as_svydesign(d)` bare, so a
condition raised on an unfiltered design would have passed the test. The block
now wraps the call in `expect_no_condition()`, which matches the filtered block,
and keeps its two existing assertions in place and unchanged. An unfiltered
design carries no marker column, so there is no pre-existing condition to
tolerate and nothing at all may fire.

`devtools::test(filter = "conversion")`: 676 pass, 0 fail — one more than the
675 this PR reported before the BLOCK. No other block was touched.

### Two changes made on the branch while I was away

Recorded here so a later reader is not misled by the HOLD above.

1. The HOLD's cause was fixed rather than deferred. `.calibrated_mean_cell()`
   now takes its finite correction from the full sample, as PR #263 on
   `develop`. My ratio measurement stands, and the standard-error agreement
   AC-1 asks for on the non-probability shape now holds.
2. The coordinator replaced the ratio-identity assertion in the filtered
   nonprob block with a plain parity check at 1e-8 (commit `478b09d`), and my
   branch was rebased onto the new `develop`. The HOLD above is closed; it is
   left in place as the record of why #263 exists.
