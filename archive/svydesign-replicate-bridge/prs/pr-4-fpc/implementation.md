# implementation.md — PR 4, `fix/svydesign-replicate-fpc`

Base: `1f15d35b82d569c6a560e2a42c2068724cbbc07f`. The worktree came up on
`d4d1db2`, as the dispatch warned. I ran `git reset --hard 1f15d35` before
writing any code.

## Write surface

Modified — four files, no others:

- `R/methods-conversion.R`
- `plans/error-messages.md`
- `tests/testthat/test-conversion.R`
- `tests/testthat/_snaps/conversion.md`

Created: none. Deleted: none. `git diff --name-only origin/develop` lists
exactly those four. `man/`, `NAMESPACE` and `NEWS.md` are untouched.

## Summary

- **The export route refuses a design that names no replicate column.**
  `.as_svydesign_replicate()` now opens with a `length(rep_vars) == 0L`
  guard that raises `surveycore_error_repweights_empty` with the
  route-specific message from spec §V.6. Row 16's own text names an argument
  this route does not have, so the route does not reuse it. Without the
  guard `survey::svrepdesign()` fails with `missing value where TRUE/FALSE
  needed` from inside its `combined.weights` heuristic — untyped.
- **The FPC drop warns.** When `x@variables$fpc` is not `NULL` the route
  raises `surveycore_warning_replicate_fpc_dropped` once per call, before
  the `survey::svrepdesign()` call, naming the dropped column. The message
  is spec §V.3 verbatim; the `paste0()` line breaks differ from the spec's
  wrapping but the rendered text is identical, checked against a live run.
- **`fpc` and `fpctype` no longer reach `survey`.** Both arguments are gone
  from the `survey::svrepdesign()` call, on both branches of the warning,
  and the local `fpctype` value the route used to compute is deleted. The
  FPC stays on the surveycore design: `@variables$fpc`,
  `@variables$fpctype` and the `@data` column are all untouched.
- **Step 3 and step 5 stay separate.** `scale_arg` is computed, then a blank
  line, then the FPC block. PR 5's Fay `rho` recovery inserts between them
  without moving either.
- **Seven test blocks added**, X-1 to X-7, at the end of
  `tests/testthat/test-conversion.R`, plus one local builder `make_rep_fpc()`.
  Two snapshots added to `_snaps/conversion.md`; the four PR 3 snapshots are
  byte-identical.

## Task checklist

- [x] CB-3 inserted into `### svydesign-replicate-bridge rows (2026-09-04)`
      in CB number order, verbatim from spec §V.7. Rows now read CB-1, CB-2,
      CB-3, CB-5.
- [x] Row 16's updated trigger note appended. Row 16 itself is byte-identical.
- [x] The pending-rows note narrowed to name CB-4 only.
- [x] Row CB-2's template corrected to `{cli::qty(n_collisions)}` — both
      occurrences — so the table matches the shipped code. Nothing else in
      that row changed.
- [x] Step 2 — the replicate count check, as the route's first check.
- [x] Step 5 — the FPC drop warning, once per call, before the
      `survey::svrepdesign()` call.
- [x] Step 6 — `survey::svrepdesign()` called without `fpc` and without
      `fpctype`; the local `fpctype` value removed.
- [x] Tests: warning fires and conversion succeeds; export parity with and
      without an FPC; every replicate type but Fay; no FPC, no warning;
      the drop is not destructive; the empty-replicate guard by class and by
      snapshot.
- [x] Dual pattern on both new conditions, class assertion and snapshot in
      the same block. Exactly two snapshots added.
- [x] One `test_invariants()` call for `as_survey_replicate()`, in X-1. The
      existing `from_svydesign()` call is untouched. X-7 carries none.

## Gates run

| Gate | Result |
|---|---|
| `air format --check R/methods-conversion.R tests/testthat/test-conversion.R` | exit 0 |
| `devtools::document()` | `NAMESPACE` and `man/` unchanged |
| `devtools::test()` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11430` |
| `git status --porcelain` after the full run | 30 `_snaps/*.md` files rewritten by line endings only; all restored except `_snaps/conversion.md` |
| `git diff --numstat tests/testthat/_snaps/conversion.md` | `21 0` — insertions only, nothing reformatted |
| `git diff --name-only origin/develop` | the four files above |

`run-gates.sh`, `R CMD check`, `pkgdown::build_site()` and `covr` were not
run, per the dispatch.

Baseline was `FAIL 0 | WARN 256 | SKIP 4 | PASS 11366`. Failures stayed 0,
the warning count did not move, and PASS rose by 64.

## HOLDs

None.

## Notes for tester

- **`survey` warns for three of the types X-4 exercises.** `"JK2"`, `"ACS"`
  and `"successive-difference"` produce survey's own `simpleWarning` — `with
  type JK2 scale= and rscales= are not needed and will be ignored`. That
  comes from step 3's `scale_arg`, which this PR does not change, and it
  fires whether or not an FPC is recorded. X-4 muffles it with
  `suppressWarnings(..., classes = "simpleWarning")` so it does not inflate
  the suite's warning count; `cli_warn()` produces an `rlang_warning`, not a
  `simpleWarning`, so the typed condition still reaches
  `expect_warning()`. No `tryCatch()` or `withCallingHandlers()` in any
  block.
- **`"JKn"` needs an explicit `rscales`,** for a reason unrelated to the
  FPC: `survey::svrepdesign()` refuses combined JKn weights without them
  (`Must provide rscales for combined JKn weights`). X-4 passes
  `rscales = rep(1, 5L)`; `make_survey_data(design = "replicate", type =
  "brr")` yields 5 replicate columns, and `.validate_rscales()` checks the
  length against that count.
- **`get_means()` reports no `se` column by default.** The parity blocks
  pass `variance = "se"`.
- **The empty-replicate design builds.** `survey_replicate()`'s validator
  runs `setdiff(character(0), names(data))`, which is empty, so
  `repweights = character(0)` passes construction. That is what makes the
  new guard reachable.
- **PR 5's insertion point** is the blank line between `scale_arg` and the
  `if (!is.null(fpc_var))` block. Nothing in this PR reads
  `@variables$scale` other than step 3.
