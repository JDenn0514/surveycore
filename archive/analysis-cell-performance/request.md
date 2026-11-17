# Request — analysis-cell-performance

## Intent
Make six analysis functions faster by moving work that does not depend on the
cell out of the per-cell loop: `get_freqs()`, `get_means()`, `get_totals()`,
`get_variance()`, `get_covariance()` and `get_ratios()`. A cell is one level,
one group, or one level-by-group combination. The results must not change.

## Acceptance criteria
- Each function builds the cluster, strata and FPC matrices
  (`.build_cluster_matrices()`) at most once per call on the Taylor path,
  including the build that `.joint_vcov()` does now
  (`R/analysis-helpers.R:1229`).
- On the Taylor path, each function runs `.svy_recvar()` once per call on the
  stacked influence columns. Each cell's SE is `sqrt(pmax(0, diag(v)))` of
  that matrix, and the same matrix is attached as `.vcov`. Where a function's
  current structure does not allow this, the spec says why.
- On the replicate path, each function converts the replicate weight columns
  to a matrix once per call, not once per cell. A denominator that is the same
  for every level in a group is computed once per group.
- `get_means()` computes `.degf_taylor()` only for calibrated designs, and
  subsets only the columns `.degf_taylor()` reads. The cell-level df from
  issue #326 is kept.
- Every result, including the `.vcov` attribute and every `variance =` option,
  equals the result before the change. Tests assert
  `expect_equal(tolerance = 1e-12)` against the old values. `identical()`
  held on R's reference BLAS in the prototypes; an optimized BLAS may differ
  in the last bit.
- Taylor, replicate, two-phase, nonprob and calibrated designs keep their
  results. Two-phase and nonprob paths were not profiled; the spec decides
  whether they change or stay as they are.
- Measured speed-up on the scenarios in `measurements.md`, recorded before
  and after.

## Out of scope (decided 2026-11-10)
- The single `rowsum()` pass that computes every replicate cell at once. The
  user deferred it: its gain was measured on the inner step only, and it
  removes the cell loop instead of moving work out of it.

## Attachments
- `measurements.md` — profiling results for `get_freqs()` and `get_means()`.
- `evidence/freqs/`, `evidence/means/` — the prototype and profiling scripts
  (`.R` files are not archived; `measurements.md` is).
