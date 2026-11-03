# Request — replicate-fay-rho

## Intent
Issue #243. `as_survey_replicate(type = "Fay")` computes BRR: surveycore has
no `rho`, and it sets Fay's scale to `1/R`. Add a `rho` argument, required for
Fay, derive Fay's scale as `1/(R * (1 - rho)^2)`, store `rho` in
`@variables`, and make `as_svydesign()` pass the stored `rho` in place of the
scale inversion that PR #250 shipped. Decisions D6, D7, D8 and D10 in
`plans/issue-cleanup.md`, as settled by the user in `decisions.md` S1 to S3.

## Acceptance criteria
- `as_survey_replicate(type = "Fay", rho = 0.3)` stores `rho` and a scale of
  `1/(R * (1 - rho)^2)`.
- `as_survey_replicate(type = "Fay")` with no `rho` raises a typed surveycore
  error that names `rho`. The error has a register row in
  `plans/error-messages.md`, added before the code.
- `rho` outside `[0, 1)`, or not a single finite number, raises a typed error.
- `rho` supplied for any other type raises a typed warning and is discarded
  (S1). No warning when the caller supplied no `rho` (D8).
- A `scale` supplied with `type = "Fay"` is discarded with no warning, as
  `survey` does (D7, S2).
- `get_means()` on a Fay design matches `survey::svymean()` on a directly built
  `survey::svrepdesign(type = "Fay", rho = , mse = TRUE)` at several values of
  `rho`, asserting the SE and the confidence bounds (oracle rule,
  `.claude/rules/testing-surveycore.md`).
- Fay at `rho = 0` matches BRR on the same frame.
- `as_svydesign()` on a Fay design passes `@variables$rho`, returns a
  `svyrep.design`, and reproduces surveycore's SE. The scale inversion in
  `R/methods-conversion.R` is deleted.
- A Fay design with no stored `rho` (built before this change) is refused by
  `as_svydesign()` with `surveycore_error_fay_rho_unrecoverable`, register row
  CB-4 restated for that case (S3).
- `from_svydesign()` on a `survey` Fay design carries its `rho` across.
- The Fay block in `tests/testthat/test-variance-replicate.R`, the one
  sanctioned exception in the oracle rule, becomes a real comparison, and the
  exception text in `.claude/rules/testing-surveycore.md` is retired.
- DESCRIPTION's Fay claim is true, checked by the oracle test above.
- `NEWS.md` records the moved standard errors and the new error.

## Attachments
- GitHub issue #243 and its three comments.
- `plans/issue-cleanup.md` D6, D7, D8, D10.
- Judkins (1990), "Fay's method for variance estimation", Journal of Official
  Statistics — cited in the issue, not attached.
