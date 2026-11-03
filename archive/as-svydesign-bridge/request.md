# Request — as-svydesign-bridge

## Intent
Fix two defects in `as_svydesign()` (`R/methods-conversion.R`) together, on one
branch (`fix/as-svydesign-bridge`) targeting `develop`, as two commits and one PR.

- Issue #198: `.as_svydesign_replicate()` passes the per-row FPC column to
  `survey::svrepdesign()`, which takes one value per replicate. Every replicate
  design that names an FPC column fails with survey's bare
  `stop("fpc is wrong length")`.
- Issue #237: `as_svydesign()` refuses a `survey_nonprob` design and the refusal
  message contradicts itself. It should convert, routing on
  `@variables$repweights`.

## Acceptance criteria
- A replicate design with a populated `@variables$fpc` either returns a
  `svyrep.design` or fails with a surveycore condition class that names `fpc`.
  survey's bare `stop()` never reaches the user.
- `type = "bootstrap"` with an FPC raises a surveycore condition, not survey's
  `"Separate fpc not needed for bootstrap"`.
- A replicate-shaped `survey_nonprob` design converts to `svyrep.design` and
  keeps every replicate column.
- A plain-shaped `survey_nonprob` design converts to `survey.design2` and warns
  with the SRS-approximation caution.
- `as_tbl_svy()` accepts both nonprob shapes.
- The nonprob round trip (`as_svydesign()` then `from_svydesign()`) returns a
  probability design; the nonprob identity is lost. Asserted in a test and
  stated in the docs.
- `plans/error-messages.md` gains a row for `surveycore_error_not_survey_object`
  (raised at four sites today, absent from the table) and a row for every new
  class, before any code uses it.
- Roxygen lines 33, 41, 42, 217, 218 of `R/methods-conversion.R` change.
  Lines 344 and 535 do not.
- `NEWS.md` gains entries for both issues under the development version.
- `devtools::document()` runs and the regenerated `man/` pages ship with the source.

## Attachments
- GitHub issue #198 (full body read at spec time)
- GitHub issue #237 (full body read at spec time)
