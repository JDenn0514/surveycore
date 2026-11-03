# Implementation — PR 7: fay-rho-oracle

**Branch**: `test/fay-rho-oracle`
**Base**: `dbe8b9352c9564844a5e9d98009879d78ece2ce8` (tree `43958277b43d0f9e2e3ee6839bae51339351e6a2`)
**Head**: `ad1350f0ca5fce212d419dd2238dc361759230f3`
**Installed survey version**: 4.5 (`packageVersion("survey")`)

## Write surface

- Modified: `tests/testthat/test-variance-replicate.R`
- Created: none
- Deleted: none

`git rev-parse HEAD:R` = `cfa0dbedba19edfdfddd07e3411d3f66a0ea6175` = `git rev-parse dbe8b93:R`. No file under `R/` changed, so `R/variance-replicate.R` is byte-identical.

## Summary

- The block "survey::svrepdesign() refuses Fay without rho — Fay design" keeps its one assertion of survey's refusal, matched by message text. Its stored-scale assertion and its "compares nothing" comment are gone.
- A new section, Block 24b, holds a file-local helper `make_fay_oracle_pair(rho, mse)`. It builds fixture FA and both designs, passes `rho` and `mse` to both sides as the same literal, passes `scale` to neither, and wraps both constructors in `expect_no_warning()`.
- Seven oracle blocks: `get_means()` against `svymean()` at rho 0.3, 0, 0.5, 0.9 (mse = TRUE) and at rho 0.3 with mse = FALSE; `get_totals()` against `svytotal()`; grouped `get_means()` against `svyby()`, rows matched by group level. Each block asserts each side's stored scale against the literal `1 / (10 * (1 - rho)^2)` (written `1 / 10` at rho 0), then the estimate (1e-10), SE (1e-8) and both bounds (1e-6).
- The section header carries the degrees-of-freedom precondition comment.
- Block 24c, surveycore only: Fay rho 0 against BRR (SEs equal, both scales 1 / 10); Fay rho 0.5 against BRR (SE ratio 2, means equal); `rscales = rep(2, 10)` (SE ratio sqrt(2)); an inline 8-row all-NA frame, Fay rho 0.3 against BRR (both return, identical NA positions in `mean` and `se`, identical `n`).

## Tasks

- [x] 1. Rewrite the Fay refusal block
- [x] 2. Oracle discipline in every comparison
- [x] 3. Degrees-of-freedom comment
- [x] 4. Five mean comparisons
- [x] 5. Total comparison
- [x] 6. Grouped comparison
- [x] 7. Surveycore-only Fay/BRR/rscales tests
- [x] 8. All-NA outcome test
- [x] 9. No new `test_invariants()` call (file count stays at 1)
- [x] 10. Verify survey version, `R/` unchanged, gate 2

## Gates run here

- `devtools::test(filter = "variance-replicate")`: FAIL 0, WARN 1 (the pre-existing AAPOR warning from the `get_corr()` block), PASS 257.
- Full suite, `NOT_CRAN=true devtools::test()`: FAIL 0, WARN 256, SKIP 4, PASS 12350. The warning count equals the 256 on clean `develop`.
- `air format --check` on the changed file: clean. The base file was air-clean, so `air format` changed only the new lines. No new line passes 80 columns.
- Not run, by instruction: R CMD check, pkgdown, covr, `run_examples()`. No roxygen changed, so `devtools::document()` has nothing to do.
- `_snaps/`: the test run rewrote line endings in about 30 files; all were reverted with `git checkout --`. This PR adds no snapshot.

## HOLDs

None.

## Notes for tester

- Parse-data counts (`SYMBOL_FUNCTION_CALL`) on the head file: `svrepdesign` 17 (base 16, not the 14 the brief gives), `expect_no_warning` 14 (base 12), `expect_failure` 0, `test_invariants` 1, `suppressWarnings` 0. The helper holds the one new `svrepdesign()` call and is called 7 times.
- On FA, all four rho values and both mse settings give an SE gap near 1e-14 and no warning from either constructor.
- The all-NA case returns on both types with `mean`, `se`, `ci_low` and `ci_high` all `NA` and `n = 0`; no error is raised.
