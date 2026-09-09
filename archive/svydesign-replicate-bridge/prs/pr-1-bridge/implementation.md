# Implementation — PR 1 — svydesign-replicate-bridge

**Reconstructed document.** The original `implementation.md` was lost with the
builder's worktree, so this file was written back from the merged diff. The code
it describes is the code that merged, at commit `15434a7` (`2cd9cc3` before the
orchestrator rebased it onto the moved `origin/develop`). The gate figures below
are the original builder's measurements on the pre-rebase base `df3a481`.

## Write surface

- `R/methods-conversion.R` — modified
- `tests/testthat/test-conversion.R` — modified

Both verified against the base commit `df3a481`. No other file changed: no
`man/` drift, no `NAMESPACE` drift.

Scope: spec §I.1 rows 1, 2 and 3 — in §III.2 terms, steps 2, 4, 5, 6, 10, 11,
12 and 13. Steps 1, 3, 7, 8 and 9, and the whole export route in §IV, belong to
later pull requests.

## Summary

- `.from_svydesign_replicate()` now expands `x$repweights` with
  `unclass(as.matrix(x$repweights))` before it reads anything from the object.
  `as.matrix()` covers both storage forms — a plain matrix and the
  `repweights_compressed` list that `survey`'s default `compress = TRUE`
  produces. It is called with no `survey::` prefix because the method is
  unexported; the `requireNamespace()` guard in `from_svydesign()` loads
  survey's namespace, which registers it for dispatch. The `unclass()` removes
  the `"repweights"` class that `survey::svrepdesign()` puts on the stored
  object and that `as.matrix()` keeps — with the class in place
  `as.data.frame()` collapses the whole matrix into one column and arithmetic
  propagates the class.
- A new inline helper `.repwt_col_names(n_rep)` builds the generated name
  block: `formatC()` zero-pads the index to the width of `n_rep`, so the names
  sort in replicate order, and the `..surveycore_repwt_N..` shape follows the
  existing `..surveycore_wt..` convention for a manufactured column. It sits
  above `.from_svydesign_replicate()`, its only call site, and carries `@noRd`.
- Name resolution branches once, on `length(colnames(x$repweights)) == 0L`.
  `survey::as.svrepdesign()` names no column of the matrix it builds, for any
  replicate type and either `compress` value, so that branch generates a block;
  otherwise survey's own names pass through unchanged and in order. The branch
  also records that the names were generated, for the collision check a later
  pull request adds.
- The route writes one column per replicate into `data`, on every conversion,
  with no branch and no condition:
  `data[[rep_cols[j]]] <- as.numeric(rep_mat[, j])`. `survey::svrepdesign()`
  cross-checks `variables` against `repweights` for neither name nor value, so
  a name in `colnames(x$repweights)` can also name a column of `x$variables`
  holding unrelated numbers. The write is what makes `@variables$repweights`
  true. The written columns are plain doubles in the row order of
  `x$variables`; zeros, negative values and `NA` all pass through untouched.
- Order is load-bearing and the code holds it: the base weight search runs
  before the replicate block is written, so it never sees a replicate column. A
  replicate that deletes nothing and scales nothing holds exactly `x$pweights`,
  and writing first would let the route name such a column as the base weight.
  `@variables` gains `repweights = rep_cols` and no other key changes;
  `.extract_haven_metadata(data)` and the `survey_replicate()` call are
  unchanged and now read the written columns, which carry no label attribute.

## Task checklist

- [x] Add `.repwt_col_names()` above `.from_svydesign_replicate()`, with the
      zero-padded index and the `@noRd` tag (spec §II.2)
- [x] Keep the data read unchanged —
      `.strip_labelled_columns(as.data.frame(x$variables))` (step 2)
- [x] Expand the replicate matrix with `unclass(as.matrix(x$repweights))`,
      covering the compressed and uncompressed forms (step 4)
- [x] Count the replicates as `n_rep <- ncol(rep_mat)` (step 5)
- [x] Resolve the column names: generate on a zero-length `colnames()`, pass
      survey's names through otherwise, and record which happened (step 6)
- [x] Leave the base weight search where it is, ahead of the replicate write
      (step 10)
- [x] Write one double column per replicate, unconditionally (step 11)
- [x] Store `repweights = rep_cols` in `@variables`, changing no other key
      (step 12)
- [x] Leave the metadata extraction and the `survey_replicate()` construction
      unchanged (step 13)
- [x] Tests R-1 and R-2 — numerical parity against `survey::svymean()` for an
      uncompressed and a compressed finished-weight source, each with a
      precondition that pins the storage form and the `combined.weights` flag
- [x] Test R-3 — a compressed factor-form source stores every replicate under a
      generated name; structure only, no standard-error parity, because the
      fold-in (step 9) is not in this pull request
- [x] Test R-4 — an uncompressed source, the case where `as.matrix()` keeps the
      `"repweights"` class, still yields `n_rep` separate double columns
- [x] Test R-5 — one existing data column per source replicate, no silent loss
- [x] Test R-6 — the regression guard for #197: `get_means()` runs on a design
      converted from `survey::as.svrepdesign()`
- [x] Tests R-7 and R-8 — generated names zero-pad at 20 replicates and stay
      unpadded at 4
- [x] Test R-9 — survey's own names pass through unchanged and in order, and
      every column of the expanded matrix still lands in the data
- [x] Test R-10 — when a replicate column holds exactly `x$pweights` and no
      data column does, the route manufactures `..surveycore_wt..`
- [x] Run `devtools::document()`; no roxygen content changed, so no `man/` or
      `NAMESPACE` diff resulted

## Signals raised

None. No HOLD was raised. This pull request adds no `cli_abort()` and no
`cli_warn()`, so it adds no row to `plans/error-messages.md`.

## Notes for tester

- The gate figures below were measured on the `df3a481` base, before the
  orchestrator rebased the work onto the moved `origin/develop`. Re-run them on
  the rebased tree.
  - `devtools::test()`: `FAIL 0 | WARN 256 | SKIP 4 | PASS 10982`. The baseline
    on `develop` was `FAIL 0 | WARN 256 | SKIP 4 | PASS 10872`.
  - `covr`: package 96.19%. `R/methods-conversion.R` at 99.18%; its two
    uncovered lines are pre-existing and sit outside this diff.
  - `R CMD check --as-cran`: 2 NOTEs, both pre-existing.
- The worktree arrived at `d4d1db2`, a merge commit on `main`, not at the
  `df3a481` base the dispatch named. It was reset to `df3a481` before any code
  was written. At `d4d1db2` the conversion route contradicted spec steps 2 and
  13.
- Every new test block calls `skip_if_not_installed("survey")`, and several open
  with `expect_*()` preconditions on the source design — the storage form, the
  `combined.weights` flag, whether survey named a column. Those preconditions
  fail loudly if a future `survey` release changes the shape the block assumes,
  rather than letting the block pass without testing anything.
- R-3 asserts structure only, on purpose. Spec §III.1 measures the
  standard-error error on a factor-form source at 35%, 8%, 4%, 10% and 0.1%
  across five designs. Step 9, the fold-in that removes it, is a later pull
  request.
