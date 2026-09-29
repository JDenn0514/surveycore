# Implementation — PR 2 — replicate-scale-stored-default-tests

**Branch**: `fix/replicate-scale-stored-default-tests`
**Base**: `d11d1f8`, tree `ee0fb4eac0e4c6386b057923d2ee2f7ccce5eb43`

## Write surface

- `tests/testthat/test-constructors.R` — modified (+171 lines, 0 deletions)

Nothing else. `git status` shows one modified file and nothing under `R/`.

## Summary

- Five `test_that()` blocks sit beside the existing per-type blocks, after
  the pre-existing `bootstrap default scale = 1/(R-1)` block and before
  `stores repweights as column names`.
- Block 1 pins both changed defaults on one 20-column frame: JKn stores `1`,
  bootstrap stores `1 / (R - 1)`, each differs from and exceeds its old
  value, and each ratio to its old value equals `R / (R - 1)` at `1e-8`.
  Both constructions run inside `expect_no_condition()`.
- Block 2 pins spec E6: a non-uniform `rscales` of the right length leaves
  `scale` at `1` and is stored element for element.
- Block 3 pins spec E1, E2 and E3 by selecting replicate columns with
  `all_of()` rather than building a degenerate frame: two bootstrap columns
  store `1`; one bootstrap column stores `Inf`, asserted both with
  `expect_true(is.infinite(...))` and against the literal `Inf`, and raises
  no condition; one JKn column stores `1`.
- Block 4 pins spec E4 (an explicit `scale` is stored verbatim for both
  changed types) and block 5 pins spec E5 (`type = "JKn"` with
  `rscales = NULL` stores `scale = 1`, keeps `rscales` `NULL`, raises
  nothing).

## Task checklist

- [x] 1. Cut the branch from `develop` and record the baseline.
- [x] 2. Write the block for row 1.1. Run it. It passes.
- [x] 3. Mutation-check row 1.1 on both switch lines. Revert. Re-run green.
- [x] 4. Write the block for row 1.2. Run it. It passes.
- [x] 5. Write the block for row 1.3. Run it. It passes.
- [x] 6. Mutation-check row 1.3. Revert. Re-run green.
- [x] 7. Write the block for row 1.4. Run it. It passes. No mutation check —
  the row asserts behaviour both defaults share.
- [x] 8. Write the block for row 1.5. Run it. It passes.
- [x] 9. `git status` shows no change under `R/`.
- [x] 10. Run the full suite and the light gates.

## The mutation check

Each mutation was made with `sed` on one line of `R/core-constructors.R`,
run, then reverted. Both switch lines were restored and the file is byte
identical to `HEAD`.

### Mutation A — `R/core-constructors.R:851` set to `(n_rep - 1L) / n_rep`

`[ FAIL 7 | WARN 16 | SKIP 0 | PASS 712 ]` against `FAIL 0 | PASS 719`.
All seven red assertions are JKn assertions in the new blocks:

| Line | Assertion | Block |
|---|---|---|
| 727 | `expect_equal(d_jkn@variables$scale, 1)` | 1.1 |
| 730 | `expect_false(isTRUE(all.equal(scale, jkn_old)))` | 1.1 |
| 733 | `expect_gt(d_jkn@variables$scale, jkn_old)` | 1.1 |
| 736 | ratio equals `n_rep / (n_rep - 1L)` at `1e-8` | 1.1 |
| 767 | `expect_equal(d@variables$scale, 1)`, non-uniform `rscales` | 1.2 |
| 809 | `expect_equal(d_jkn_one@variables$scale, 1)`, one column | 1.3 |
| 861 | `expect_equal(d@variables$scale, 1)`, `rscales = NULL` | 1.5 |

No bootstrap assertion moved. Line 809 is red because the old JKn default
evaluates to `0` at one replicate column.

### Mutation B — `R/core-constructors.R:861` set to `1 / n_rep`

`[ FAIL 8 | WARN 16 | SKIP 0 | PASS 711 ]`. Seven of the eight are new
bootstrap assertions; the eighth is the pre-existing block PR 1 retargeted.

| Line | Assertion | Block |
|---|---|---|
| 691 | `expect_equal(d@variables$scale, 1 / (n_rep - 1))` | pre-existing |
| 728 | `expect_equal(d_boot@variables$scale, 1 / (n_rep - 1L))` | 1.1 |
| 731 | `expect_false(isTRUE(all.equal(scale, boot_old)))` | 1.1 |
| 734 | `expect_gt(d_boot@variables$scale, boot_old)` | 1.1 |
| 741 | ratio equals `n_rep / (n_rep - 1L)` at `1e-8` | 1.1 |
| 790 | `expect_equal(d_two@variables$scale, 1)`, two columns | 1.3 |
| 800 | `expect_true(is.infinite(d_one@variables$scale))` | 1.3 |
| 801 | `expect_equal(d_one@variables$scale, Inf)` | 1.3 |

No JKn assertion moved. Lines 800 and 801 are the row 1.3 assertions that
exist only at the new default: the old `1 / R` gives a finite `1` at one
replicate column.

### Revert

`sed -n '851p;861p' R/core-constructors.R` reads `JKn = 1,` and
`bootstrap = 1 / (n_rep - 1L),`. `git diff --numstat -- R/` is empty and
`git show HEAD:R/core-constructors.R | cmp -` reports the bytes identical.

## Signals raised

None. No HOLD.

## Notes for tester

- Blocks 1.1 and 1.2 build a 20-column frame with
  `make_survey_data(type = "jkn")`, where the generator sets `R = n_psu`.
  Block 1.1 asserts `n_rep == 20L` before it uses the count, so a change to
  the generator turns that line red rather than silently moving the ratio.
- Block 1.3 reaches one and two replicate columns with
  `repweights = all_of(...)` on an ordinary ten-PSU frame, not with a
  one-PSU frame. A one-PSU frame makes several strata empty in the
  generator, which is a second variable the row does not need.
- `test_invariants()` still appears four times in the file, at lines 22,
  479, 1393 and 1754. The new blocks add none.
- `air format --check tests/testthat/test-constructors.R` reports
  "Would reformat", and it does so on the base commit too. Formatting the
  file in a scratch copy and diffing gives 28 hunks, the first at line 1380.
  The added block spans lines 694 to 864, so no hunk falls inside it.
- No file under `tests/testthat/_snaps/` changed. Running the suite marks
  about 30 of them modified in `git status` with an empty content diff;
  `git checkout -- tests/testthat/_snaps/` clears the flag. That is the
  known CRLF stat churn of issue #161, not a snapshot change.
- `sed -i` on a file under `R/` rewrites it with LF endings, and this
  repository checks `R/*.R` out as CRLF. The content diff stays empty but
  `git status` keeps reporting the file modified. Restoring the file with
  `git checkout --` clears it.
