**Does:** Applies a filtered design's domain restriction to the object `as_svydesign()` returns. Today the converted object answers for the whole sample.
**When:** Now. PR #259 merged in `6c31492`, so the file is free.
**Decision:** Locked. Subset on `SURVEYCORE_DOMAIN_COL` in each of the four routes.
**Write surface:** `R/methods-conversion.R`, `tests/testthat/test-conversion.R`

**This is the only open issue where a point estimate is wrong, not just a
standard error.** 58.176655 against 50.761561 on the measurement below.

## Summary

`as_svydesign()` carries a filtered design's domain column across as an ordinary
variable and never installs it as the converted object's own restriction. The
converted object answers for the whole sample. The point estimate is wrong, not
only the standard error.

Measured on `develop` at `a7a52c0`, survey 4.5, R 4.6.1, Windows.
`make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 3)`, built with
`as_survey(ids = psu, weights = wt, strata = strata)`, then
`surveytidy::filter(d, y1 > 50)`.

| Call | mean | SE |
|---|--:|--:|
| surveycore `get_means()` on the filtered design | 58.176655 | 0.725342 |
| `survey::svymean()` on `as_svydesign()`'s output | 50.761561 | 0.614837 |
| the same, after `subset()` on `..surveycore_domain..` | 58.176655 | 0.725342 |

Row 3 reproduces row 1 exactly, so the information is present in the converted
object. It is simply not applied.

## Root cause

surveycore marks domain membership as a column, `..surveycore_domain..`
(`SURVEYCORE_DOMAIN_COL`, `R/utils.R:344`). `.apply_domain()` at
`R/analysis-helpers.R:482-488` reads it and defaults to all-`TRUE` when it is
absent, so every `get_*()` function restricts its estimation sum while keeping
the full frame. This is the documented split in `CLAUDE.md`: `filter()` marks a
domain and keeps every row, `subset()` removes rows.

None of the conversion helpers reads the column. `.as_svydesign_taylor()`,
`.as_svydesign_replicate()` and `.as_svydesign_twophase()` each pass
`data = x@data` whole, with no `subset()` applied. `survey` keeps its own
subsetting in the object's internal probability and index state, not in a data
column, so an inert column changes nothing.

## Consequence

`as_svydesign()`'s own documentation says it is "Useful for accessing `survey`
package estimation functions". A user who filters a design, converts it, and
calls `survey::svymean()` on the result gets an answer for the whole sample. No
warning, no error, and no marker on the object recording that a domain was ever
set. Every route is affected, including the two nonprob routes added in #237.

## Scope

All four routes of `as_svydesign()`, and `as_tbl_svy()` through it.

## Suggested fix

Subset the constructed object on `SURVEYCORE_DOMAIN_COL` before returning it,
when the column is present, in each route. `survey::subset.survey.design` and
its replicate counterpart both exist for this.

Two questions this issue does not decide:

1. Whether the domain column should also be dropped from the converted object's
   variables once it has been applied, so it cannot be mistaken for data.
2. Whether the reverse direction should recover a domain at all. It cannot:
   `survey` records a subset, not a domain marker, so a round trip through
   `from_svydesign()` returns a design with fewer rows rather than a marked one.

## Verification

- A filtered Taylor design converts to an object whose `survey::svymean()`
  matches surveycore's own `get_means()` on the filtered design, to the SE
  tolerance in `.claude/rules/testing-surveycore.md`.
- The same for a filtered replicate design, a filtered twophase design, and
  both nonprob shapes.
- An unfiltered design converts unchanged, and gains no subsetting.
- `as_tbl_svy()` inherits the fix.

Found while measuring the methods review for the `as_svydesign()` bridge fix
(#198, #237). Out of scope there by decision: that PR documents the limitation
and files this issue.


