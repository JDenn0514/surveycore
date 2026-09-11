# Implementation — PR 3 — as-svydesign-domain-replicate-nonprob

**Branch**: `fix/as-svydesign-domain-replicate-nonprob`
**HEAD**: `8c86c5fc4a49c66aace3cd0d6f65ce11b979c2d1`
**Base**: `67914a0024b03059f2dfeae2618f5b0d7fa99a15` (verified before any read or write)

## Write surface

- `R/methods-conversion.R` — modified, one call site
- `tests/testthat/test-conversion.R` — modified, one new section

`git diff --stat origin/develop HEAD` names those two files and nothing else.
`NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION`, `plans/error-messages.md` and
`tests/testthat/_snaps/` are byte-identical to `develop`. `devtools::document()`
ran and wrote nothing — this PR changes no roxygen. The four planning files
under `plans/` stay uncommitted.

## Summary

- `.as_svydesign_replicate()` assigns the object `survey::svrepdesign()` builds
  to `converted`, then returns `.restrict_to_domain(converted)`. That is the
  whole production diff: two lines changed, signature unchanged, helper
  unchanged. The dispatch in `as_svydesign()` is untouched, so no branch reads
  `x@variables$repweights` and no ninth copy of the routing predicate exists.
- One call site reaches two input shapes. A `survey_replicate` design arrives
  through the class branch; a `survey_nonprob` design that names replicate
  weights arrives through the weight-shape branch already in `as_svydesign()`.
  A `survey_nonprob` design that names none reaches the Taylor call site PR 1
  shipped, after its SRS warning.
- `as_tbl_svy()` gained the restriction on all three shapes with no body edit:
  it calls `as_svydesign()` and wraps the result.
- No new condition class. The two pre-existing warnings both fire before the
  object exists — `surveycore_warning_nonprob_srs_conversion` in
  `as_svydesign()` before dispatch, `surveycore_warning_replicate_fpc_dropped`
  inside the replicate route before `svrepdesign()` runs — so the restriction
  can neither double one nor suppress one. Two blocks pin that ordering.
- `tests/testthat/test-conversion.R` gains two fixtures and 14 blocks under a
  new `# ── Domain restriction on the replicate route and both nonprob shapes ──`
  heading: three parity blocks, three unfiltered-baseline blocks, three
  empty-domain blocks, one `as_tbl_svy()` block, two condition blocks, and the
  FPC-ordering block. No existing block changed.

## Task checklist

- [x] 1. Base sha confirmed as `67914a0`; the existing call-site diff verified
  against the spec's §Route matrix and committed unmodified as `843b33e`
- [x] 2. Failing test for the filtered BRR replicate parity. Confirmed failing
  with the restriction disabled in place (the `.restrict_to_domain()` line
  replaced by `converted` and then restored — no `git stash`): 50 rows against
  29, mean 50.1 against 57.2, SE 0.122 against 0.079. Passes with the
  restriction. A second block runs the same parity on a
  `surveytidy::filter()` marker rather than a hand-written one
- [x] 3. The same parity on a filtered `survey_nonprob` design naming replicate
  weights — failing first at 40 rows against 20, mean 47.7 against 54.9. Both
  parity blocks also assert the marker column is a name of the converted
  object's variables and that every value left in it is `TRUE`
- [x] 4. Three unfiltered shapes: a replicate design carrying no FPC, a
  `survey_nonprob` with replicate weights, a `survey_nonprob` without. Each
  gives one row per design row, carries no marker column, and raises only the
  condition its shape already raises
- [x] 5. Empty domain. An all-`FALSE` marker on the replicate route gives zero
  rows and a silent conversion, and `survey::svymean()` on that object then
  errors. That error is `survey`'s and untyped, so the block asserts it by
  message with no `class =` and no snapshot. Both nonprob shapes with an
  all-`FALSE` marker give zero rows and raise nothing beyond the SRS warning
- [x] 6. `as_tbl_svy()` on a filtered plain-shaped nonprob returns a `tbl_svy`
  with the domain row count; the SRS warning is captured off the call. No
  snapshot added
- [x] 7. `expect_no_condition()` on the filtered replicate design and on the
  filtered nonprob-with-replicates design. The filtered nonprob shape naming no
  replicate weights raises the SRS warning exactly once and nothing else
- [x] 8. A filtered replicate design carrying an FPC raises
  `surveycore_warning_replicate_fpc_dropped` exactly once and no other
  condition; the result is read off the warned call and the domain row count is
  asserted on it. No snapshot added
- [x] 9. `devtools::test(filter = "conversion")` run repeatedly; the full suite
  run once, in the foreground, redirected to `.test-full.log`, which was deleted
  before the commit. No `devtools::check()`, no `covr`, no `pkgdown`
- [x] 10. This file

`air format --check` passes on both files.

## Measurements

| Run | Result |
|---|---|
| `devtools::test(filter = "conversion")` | FAIL 0, WARN 0, SKIP 0, PASS 739 |
| `devtools::test()` (full, once) | FAIL 0, WARN 256, SKIP 4, PASS 11749 |

The 256 warnings are the pre-existing AAPOR small-cell count that clean
`develop` already carries (`archive/svydesign-replicate-bridge/` D12). This PR
adds none: the filtered conversion section passes `min_cell_n = 1L` wherever a
domain falls below the default threshold of 30.

## Signals raised

None. No HOLD.

## Notes for tester

- `surveytidy` and `srvyr` are both installed on this machine, so the two
  blocks that need them run rather than skip. Each carries its own
  `skip_if_not_installed()`.
- The "exactly once and nothing else" blocks use
  `expect_no_warning(expect_warning(x <- fn(d), class = ...))`. The inner
  expectation consumes the matching warning and re-raises anything it does not
  match, so the outer one fails on a second copy or on any other warning. I
  checked the pattern is not vacuous: with a function raising two warnings of
  different classes, the same nesting reports one failure. No `tryCatch()` and
  no `withCallingHandlers()` appears in any block.
- Four blocks pass `min_cell_n = 1L` to `get_means()`. The domains hold 25, 29
  and 20 rows against a default threshold of 30. The argument does not move the
  estimate.
- The empty-domain replicate block is the one place a block asserts an untyped
  message. `survey::svymean()` on a zero-row `svyrep.design` stops with
  `All replicates contained NAs`, which belongs to `survey`, so it gets no class
  and no snapshot.
