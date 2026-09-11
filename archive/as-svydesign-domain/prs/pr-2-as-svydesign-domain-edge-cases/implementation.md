# Implementation — PR 2 — as-svydesign-domain-edge-cases

## Write surface

- `tests/testthat/test-conversion.R` — modified

No other file changed. `R/`, `NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION`
and `plans/error-messages.md` are byte-identical to `develop`.
`git diff --stat origin/develop...HEAD` reports one file, 119 insertions.
This PR adds no production code, so `devtools::document()` was not needed.

Commit: `7ee6d53b2a61e82ce32071b28f306b19540cf477` on branch
`test/as-svydesign-domain-edge-cases`.

## Summary

- Extended the existing five-marker-type loop with a probability assertion.
  The loop's row count and its `expect_no_condition()` both pass on a corrupt
  object, so neither one closed the hole `spec.md`
  §`.restrict_to_domain(converted)` → Row mask measured: `&` on a factor
  marker returned an all-`NA` mask, and the object that mask selected carried
  a probability vector that was neither finite nor infinite. The added
  expectation is `is.numeric(sv$prob) && all(is.finite(sv$prob))`, one
  expectation rather than two so that a list-valued vector fails the block
  instead of erroring inside `is.finite()`.
- Added the two marker edge cases the section did not carry: exactly one
  `TRUE` gives a one-row object with no condition raised, and an all-`NA`
  marker gives a zero-row object whose `survey::svymean()` answers 0 with a
  standard error of 0 — the Taylor-route outcome in `spec.md` §Documentation
  contract item 6.
- Added `as_tbl_svy()` on a filtered Taylor design: it returns a `tbl_svy`
  whose `variables` carry one row per marked row, with no edit to that
  function's body.
- Added the round trip's numbers: `from_svydesign(as_svydesign(d))` on a
  filtered Taylor design agrees with the converted object on the point
  estimate (1e-10), the standard error (1e-8) and both confidence bounds
  (1e-6). One `get_means(variance = c("se", "ci"))` call supplies all four.
- Added the round trip's marker and print line: the rebuilt design carries an
  all-`TRUE` marker column and prints `Domain: 25 of 25 rows`, the same
  number twice, because the original N is unrecoverable from a `survey`
  object.

## Blocks extended versus blocks added

| Block | State |
|---|---|
| `as_svydesign() selects the same rows for every marker column type` | extended — one expectation added inside the loop |
| `as_svydesign() converts a single-TRUE marker to a one-row object` | new |
| `as_svydesign() converts an all-NA marker to a zero-row object` | new |
| `as_tbl_svy() inherits the restriction on a filtered Taylor design` | new |
| `the round trip on a filtered Taylor design agrees on the numbers [numerical]` | new |
| `the round trip on a filtered Taylor design prints n of n rows` | new |

No block restates one of the six the earlier PRs shipped (all-`FALSE`
marker, `NA` marker row, the five-type loop's own assertions, the
unconvertible factor, the parity, unfiltered-baseline, all-`TRUE`,
input-unchanged, stored-call and round-trip-variables blocks).

## Task checklist

- [x] 1. Finish the marker-column-type coverage with a finite-probability
      assertion, placed inside the existing loop
- [x] 2. A marker with exactly one `TRUE`; nothing asserted about estimating
      on the one-row object
- [x] 3. An all-`NA` marker; zero rows, silent conversion, 0 with a standard
      error of 0
- [x] 4. `as_tbl_svy()` on a filtered Taylor design, behind
      `skip_if_not_installed("srvyr")`
- [x] 5. The round trip's point estimate, standard error and both confidence
      bounds at the three tolerances
- [x] 6. The round trip's all-`TRUE` marker and its `Domain: n of n rows`
      print line

Each new block carries its own `skip_if_not_installed()` for what it needs.

## Signals raised

None. No HOLD.

## Notes for tester

- `NOT_CRAN=true Rscript -e 'devtools::test(filter = "conversion")'` reports
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 696`, against 676 before this PR.
- The print block captures two streams: the inner
  `invisible(capture.output(...))` takes the tibble on stdout and the outer
  `capture.output(..., type = "message")` takes the cli text. Without the
  inner capture the run leaks 14 lines of tibble output into the reporter.
- `air format --check` on the file passes. One line I added is 91 characters
  — a `test_that()` description string, which `air` does not break; the file
  already carries several longer ones.
- The full suite, `devtools::check()`, `covr` and `pkgdown` were not run.
  This machine had about 1.4 GB free and a low-memory watchdog kills
  concurrent R processes; the dispatching session runs those gates.
