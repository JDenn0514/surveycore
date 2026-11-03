# Implementation — PR 5: fay-rho-export

**Branch**: `fix/fay-rho-export`
**Base**: `0b7e6239c1e2989d8de28e62bc7ee4742947db47` (tree `dd70f9ed`)
**Commits**: `d94803f` (code, tests, snapshot), `da79200` (register)

## Write surface

Modified:

- `R/methods-conversion.R`
- `plans/error-messages.md`
- `tests/testthat/test-conversion.R`
- `tests/testthat/_snaps/conversion.md`

Created: none. Deleted: none. No roxygen change, so `man/` and `NAMESPACE`
do not change (`devtools::document()` left no diff).

## Summary

- `.as_svydesign_replicate()` no longer recovers `rho` from the stored
  scale. The recovery, its comments and the `scale_txt` binding are gone.
- For `type == "Fay"` the route reads `x@variables[["rho"]]`. When
  `.is_valid_rho()` is `FALSE` (key absent, `NULL`, `NA`, 1.5 and so on) it
  aborts with `surveycore_error_fay_rho_unrecoverable` and the spec §VI.3
  template. Otherwise it passes that `rho` and no `scale`.
- Every other type passes `rho = NULL`. The empty-replicate refusal still
  runs first; the FPC drop still follows the Fay check.
- Row CB-4 in `plans/error-messages.md` carries the restated condition and
  template; `{scale_txt}` is removed from the binding paragraph; the issue
  #243 sentence sits under the CB table.

## Tasks

- [x] 1. Fay `rho = 0.3` and `rho = 0` export blocks on FC; BRR block with
  `sv$rho` `NULL`.
- [x] 2. Fay `rho = 0.3` export on FA with a domain column, mean and SE
  against `get_means()`.
- [x] 3. CB-4 on hand-built designs (helper `make_fay_by_hand()`): no `rho`
  key (class, snapshot, message contains `rho` and `as_survey_replicate`),
  `rho = NULL` key, `rho = 1.5`.
- [x] 4. Block "as_svydesign() refuses a Fay design that records no scale"
  asserts the CB-4 class; the "none" assertion is removed; the snapshot
  entry shows the new text.
- [x] 5. FA through `survey::svrepdesign(type = "Fay")` (helper
  `make_fay_svrep()`): `rho = 1.5`, `rho` set to `NA`, `rho` element
  removed. Each import raises no condition; each export raises CB-4.
- [x] 6. Block "as_svydesign() recovers rho = 0 from the default Fay scale"
  removed.
- [x] 7. Comments in the `fay.rho = 0.3` block, the X-8 to X-11 header
  lines and the X-4 comment rewritten; no assertion changed.
- [x] 8. Spec §VI.1 implemented.
- [x] 9. CB-4 restated.
- [x] 10. Verified (see below).

## Verification run by the builder

- `devtools::test(filter = "conversion")`: 0 failures.
- One full `devtools::test()` with `NOT_CRAN=true`: 0 failures, 256
  warnings (the pre-existing AAPOR count).
- `air format --check` passes on both changed `.R` files.
- Snapshots: two entries changed in `_snaps/conversion.md`, one new
  ("as_svydesign() refuses a Fay design with no rho key") and one rewritten
  ("... that records no scale"). Both diffs were read against the §VI.3
  template before `snapshot_accept("conversion")`; `snapshot_review()` needs
  an interactive session. The line-ending churn in 30 other `_snaps/`
  files was reverted and is not committed.
- Not run: R CMD check, pkgdown, covr, `run_examples()`.

## HOLDs

None.

## Notes for tester

- `survey::svrepdesign(type = "Fay", rho = 1.5)` on survey 4.5 raises no
  condition and stores scale 0.4 for 10 replicates.
- The existing block "every accepted replicate type crosses both
  conversion routes" still passes, including its Fay `rho` 0.3 assertion.
