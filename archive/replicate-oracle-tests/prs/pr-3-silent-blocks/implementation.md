# Implementation — PR 3 — silent-blocks

**Branch**: `test/replicate-oracle-silent-blocks`
**Base**: `e61518a42681f87d92f52b32ec527f10a9461877`
**Date**: 2026-09-22

## Write surface

- `tests/testthat/test-variance-replicate.R` — modified

No other file. Nothing under `R/`. No roxygen, so no `devtools::document()` run.

## Summary

- Each of the eight silent oracle blocks now wraps its
  `survey::svrepdesign()` call in `expect_no_warning()`, so the "Data do not
  look like combined weights" warning turns the block red instead of passing
  unseen.
- Each of the eight asserts `survey`'s stored scale against a formula in the
  replicate count read from the selected columns: `1 / R` in the four BRR
  blocks, `4 / R` in the two ACS and two successive-difference blocks.
- No block hard-codes `R`. Seven blocks read it as `length(repwt_cols)`; the
  `n_rep != 4` block reuses its own `n_rep <- length(repwt_cols)`.
- Every stored-scale assertion carries the same one-line comment above it,
  naming all three facts: the assertion guards `survey`'s own default, a
  failure means `survey` changed and not that surveycore regressed, and the
  tolerance is the standard-error and variance row, `1e-8`.
- One `test_invariants(sc)` call was added, in the block titled
  `get_means() replicate SE matches survey::svymean() — BRR design`. The file
  called the helper zero times before this PR.

## Probe results

Measured with `survey` 4.5 under R 4.6.1 (2026-06-24 ucrt). Each row builds
the block's own fixture, from the block's literal arguments and seed, and
collects every condition the `survey::svrepdesign()` call raises.

| Block (line on base) | Type | `mse` | Seed | `R` | `sv$scale` | Matches | Conditions raised |
|---|---|---|---|---|---|---|---|
| 12 `get_means() … BRR design` | BRR | TRUE | 7 | 10 | 0.1 | `1 / R` | none |
| 48 `get_totals() … BRR design` | BRR | TRUE | 7 | 10 | 0.1 | `1 / R` | none |
| 200 `get_means() … mse=FALSE` | BRR | FALSE | 22 | 5 | 0.2 | `1 / R` | none |
| 265 `get_means() BRR scale formula … n_rep != 4` | BRR | TRUE | 99 | 10 | 0.1 | `1 / R` | none |
| 354 `get_means() successive-difference …` | succ-diff | TRUE | 300 | 10 | 0.4 | `4 / R` | none |
| 391 `get_totals() successive-difference …` | succ-diff | TRUE | 301 | 10 | 0.4 | `4 / R` | none |
| 428 `get_means() ACS …` | ACS | TRUE | 302 | 10 | 0.4 | `4 / R` | none |
| 465 `get_totals() ACS …` | ACS | TRUE | 303 | 10 | 0.4 | `4 / R` | none |

All eight calls are silent: zero warnings and zero messages on each. The
probe captured messages as well as warnings, with
`withCallingHandlers()` and a muffle restart on both, so a message could not
have escaped counting. The ACS blocks stay on the silent path because they
pass `mse` explicitly; `survey` emits `mse=TRUE assumed for type="ACS"` only
when `mse` is omitted.

`R` is 10 on seven of the eight blocks and 5 on the `mse = FALSE` block,
which builds on 10 primary sampling units. The generator returns `n_psu / 2`
columns in the `brr` mode, so each figure is `n_psu / 2`. Every row was
measured, not assumed.

The mean replicate weight sits within 1.01 of the mean base weight on all
eight fixtures — between 1.0032 and 1.0081 — which is why `survey` reads them
as combined weights and stays silent.

## The eleventh `svrepdesign()` call does not exist

The dispatch said the file holds 11 `survey::svrepdesign()` calls across ten
blocks, so one block calls it twice. Measured: the file holds **ten** calls,
one per block, across ten blocks. Nothing to decide, and no second
design-building call is left unasserted.

`grep -c svrepdesign` returns 12 on the base file. Two of the twelve hits are
comment text, not calls: line 128 (`# survey::svrepdesign() fixes scale = 1
and rscales = rep(1, R) for JK2 and …`) and line 268 (`# … surveycore and
survey::svrepdesign agree at 1e-8.`). The count came from
`utils::getParseData()` on the parsed file, filtering to
`SYMBOL_FUNCTION_CALL` tokens named `svrepdesign`, then attributing each
token to the `test_that()` block whose source reference spans it. Every one
of the ten blocks returned a count of exactly 1.

## Task checklist

- [x] Probe each of the eight blocks and collect every condition raised —
      all eight silent
- [x] Probe the stored scale on each of the eight designs — four at `1 / R`,
      four at `4 / R`
- [x] Add the no-warning assertion and the stored-scale assertion, with the
      comment, to each of the eight blocks; change nothing else in them
- [x] Add one `test_invariants(sc)` call in the block at line 12, and no
      second call anywhere
- [x] Leave `mse = FALSE` on both sides of the block at line 200
- [x] Read the replicate count from the columns in every block
- [x] `NOT_CRAN=true Rscript -e 'testthat::test_local(filter =
      "variance-replicate")'` — `FAIL 0 | WARN 1 | SKIP 0 | PASS 138`
- [x] `grep -c 'test_invariants('` on the file returns 1; `air format
      --check` exits 0; `git diff --name-only e61518a` lists one file

## What was deliberately not touched

- The JK1 block at line 84 and the JK2 block at line 125. Both breach the
  oracle rule today, and PR 4 rewrites them.
- `scale =` at lines 558 and 573 of the base file. Those blocks call an
  internal variance routine and build no `survey` design.
- `rscales` at line 190 of the base file. That block compares two surveycore
  constructors and uses no oracle.
- `sv$scale` at line 169 of the base file. It belongs to the JK2 block, so it
  is PR 4's. This PR's eight assertions bring the file's `sv$scale` count to
  nine.

## Signals raised

None. No HOLD.

## Notes for tester

- The one `WARN` in the single-file run is pre-existing and comes from a
  block this PR does not touch: the AAPOR small-cell warning raised by
  `get_corr()` at `test-variance-replicate.R:771` (line 710 on the base
  file). It is one of the pre-existing AAPOR warnings on clean `develop`.
- The stored-scale comment runs to 99 characters, past the 80-character line
  limit in `.claude/rules/code-style.md`. Acceptance criterion 4 requires one
  line carrying all three facts, and the three do not fit in 80 characters in
  plain English. `air format --check` passes, because `air` does not rewrap
  comments. The longest comment line already in `tests/testthat/` is 95
  characters, and 130 comment lines there already pass 80.
- `expect_no_warning(sv <- survey::svrepdesign(...))` keeps the assignment
  visible to the rest of the block. This follows the file-set precedent —
  `tests/testthat/test-analysis-corr-latent.R:578` and
  `tests/testthat/test-analysis-diffs.R:921` both assign inside the wrapper.
- No `devtools::test()`, `devtools::check()`, `devtools::document()`,
  `run_examples()`, `pkgdown` or `covr` run was made from this worktree. The
  only R runs were the probe script and the single-file `test_local()` call.

## CRAN compliance

- [x] TRUE/FALSE used throughout
- [x] `::` used for external calls
- [x] No bare `print()`/`cat()`
- [x] `devtools::document()` not needed — no roxygen change, no file under
      `R/` touched
