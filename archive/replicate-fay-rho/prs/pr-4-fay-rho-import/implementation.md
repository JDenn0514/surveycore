# Implementation — PR 4: fay-rho-import

**Branch**: `feature/fay-rho-import`
**Base**: `d9d38ee` (tree `b652628`)
**Head**: `8aa215e`
**Spec section**: §V

## Write surface

- Modified: `R/methods-conversion.R`
- Modified: `tests/testthat/test-conversion.R`
- Created: none. Deleted: none.

## Summary

- `.from_svydesign_replicate()` now writes the key `rho` into
  `@variables` for every type, between `mse` and `fpc`.
- A source with `x$type == "Fay"` stores `x$rho` unchanged. Every other
  type stores `NULL`, whatever `x$rho` holds.
- The stored scale is still `x$scale`. No new condition.
- Four new test blocks and two edited blocks in `test-conversion.R`.

## Tasks

- [x] 1. FS, `as.svrepdesign(type = "Fay", fay.rho = 0.3)`: `rho` 0.3,
  scale equals `src$scale` at 1e-10, SE equals the `svymean()` SE at 1e-8.
- [x] 2. FS, `as.svrepdesign(type = "BRR")` (source `$rho` is 0): key
  present, value identical to `NULL`.
- [x] 3. FA through `svrepdesign(type = "BRR", rho = 0.3, ...)`: the
  source warning is captured with `expect_warning(..., "does not use
  'rho=' argument", fixed = TRUE)`; the key is present and the imported
  `rho` is `NULL`.
- [x] 4. FS, `as.svrepdesign(type = "BRR", fay.rho = 0.3)`: imports as
  `"Fay"` with `rho` 0.3.
- [x] 5. Fay round-trip block (`fay.rho = 0.5`): imports into `d`, asserts
  `d@variables$rho` is 0.5, then exports `d`. Existing assertions unchanged.
- [x] 6. All-types block: the Fay pass asserts the re-imported `rho` is
  0.3 at 1e-10. The other eight passes are unchanged.
- [x] 7. Spec §V implemented in `.from_svydesign_replicate()`.
- [x] 8. Verified (see notes).

## HOLDs

None.

## Notes for tester

- Installed `survey` version: 4.5.
- The FA source in task 3 uses `data = df` and `repweights = "^repwt_"`.
  `survey::svrepdesign()` reads a regex `repweights` only from `data`.
  With `variables = df` it stops with "You must provide replication
  weights". The build raises exactly one warning.
- In the all-types block, the Fay pass exports through the scale
  inversion that PR 5 removes, so the re-imported 0.3 can carry a rounding
  error. The assertion is `expect_equal()` at 1e-10.
- Every numeric `expect_equal()` added has an explicit tolerance.
- `devtools::document()` left no diff. `air format --check` passes on both
  files. No `_snaps/` change is committed.
