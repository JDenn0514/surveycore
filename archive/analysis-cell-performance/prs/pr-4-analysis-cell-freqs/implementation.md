# Implementation — PR 4: `refactor/analysis-cell-freqs`

**Builder**: opus, 2026-11-12. Branch `refactor/analysis-cell-freqs` at
`f05a9f9`. Nothing is committed.

## Files changed

| File | Change |
|---|---|
| `R/analysis-helpers.R` | `.cell_context()` gains `check_rep_finite = FALSE`; `.taylor_cell_se()` gains `v = NULL` and rule 2; `.joint_vcov()` gains `mats = NULL`; `.attach_joint_vcov()` gains `v = NULL`; the `.joint_vcov()` diagonal comment is rewritten (§III.7) |
| `R/analysis-freqs.R` | `get_freqs()`: call context, `rep_N_d` once per combination, the Taylor SE step after the loop, `.vcov` from the SE step's matrix |
| `R/analysis-freqs-helpers.R` | New signatures of `.taylor_freq_cell()`, `.replicate_freq_cell()`, `.freq_cell()`; adds `.freq_rep_total()` |
| `tests/testthat/test-analysis-cell-equivalence.R` | 5 new blocks |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | 4 new entries |

`DESCRIPTION`, `man/`, `NAMESPACE` and the golden fixture do not change.
No roxygen changed, so I did not run `devtools::document()`. All four `.R`
files were `air`-clean on the base and pass `air format --check` now.

## What each change does

- `.cell_context(design, check_rep_finite = FALSE)`: `rep_finite` is
  `replicate && check_rep_finite && all(is.finite(rep_mat))`, as §II.2.
- `.taylor_cell_se(vals, mats, lonely.psu, v = NULL)`: rule 1 sets
  `ok <- all(is.finite(vals))`. Rule 2: `ok` and `v` given returns
  `unname(sqrt(pmax(0, diag(v))))`. Rule 4 (`!ok`) is unchanged and ignores
  `v`. Rule 3 now runs only when `ok` and `v` is `NULL`.
- `.joint_vcov(design, joint, mats = NULL)`: uses `mats` when given, builds
  it when `NULL` (the other callers, unchanged).
- `.attach_joint_vcov(result, design, joint, v = NULL)`: keeps the zero-row
  early return before any read of `v`. With `v` given it attaches `v` with
  the coefficient names and does not call `.joint_vcov()`.
- `.taylor_freq_cell(design, num, denom, mats)`: no matrix build, no
  `.svy_recvar()`; returns `se = NA_real_` and the projected influence
  column in `joint`, as before.
- `.replicate_freq_cell(design, num, denom, rep_mat, rep_finite, rep_N_d)`:
  takes `rep_mat` and `rep_N_d` from the caller; `rep_Y` from
  `.freq_rep_total(num, rep_mat, rep_finite)`.
- `.freq_rep_total(ind, rep_mat, rep_finite)` (hand-written, see below):
  `TRUE` gives `as.numeric(rep(1, length(idx)) %*% rep_mat[idx, , drop =
  FALSE])` with `idx <- which(ind > 0)`; `FALSE` gives
  `as.numeric(ind %*% rep_mat)`. The exact forms of §III.5; no `colSums()`.
- `.freq_cell(design, num, denom, ctx, rep_N_d)`: `ctx$mats` to the Taylor
  cell; `ctx$rep_mat`, `ctx$rep_finite`, `rep_N_d` to the replicate cell on
  both replicate classes; the nonprob SRS and two-phase cells get none.
- `get_freqs()`: `ctx <- .cell_context(design, check_rep_finite = TRUE)`
  just before the loop. Per variable and combination, after `denom`:
  `rep_N_d <- .freq_rep_total(denom, ...)` when `ctx$replicate`, else
  `NULL`. After the loop, before the small-cell warning, on `ctx$taylor`:
  `v_all <- .joint_vcov(design, acc_joint, mats = ctx$mats)`; when any cell
  is live, `acc_se[live] <- .taylor_cell_se(vals, ctx$mats, ctx$lonely.psu,
  v = v_all[live, live, drop = FALSE])`. Then
  `.attach_joint_vcov(result, design, acc_joint, v = v_all)`; `v_all` is
  `NULL` off the Taylor route, so the replicate `.vcov` is computed as
  before. With zero cells `.joint_vcov()` returns a 0 x 0 matrix with no
  variance call, the `any(live)` guard skips the SE step, and the zero-row
  early return attaches nothing.

## Tests added (test-spec row ids)

All five written and run on the unchanged code first; all passed there.

| Row | Block | Assertion |
|---|---|---|
| 5.2.4 | "get_freqs() errors when every replicate weight is NA on a row outside the domain" | dual, `surveycore_error_all_replicates_na` |
| 5.3.1 | "get_freqs() errors on a single-PSU stratum when lonely.psu is fail" | dual, `surveycore_error_lonely_psu` |
| 5.3.7 | "get_freqs() errors on a single-PSU stratum when lonely.psu is an unknown value" | dual, `surveycore_error_lonely_psu_unknown_option` |
| 5.5.3 | "get_freqs() still errors when a base weight is Inf" | `simpleError`, no snapshot |
| 5.7.2 | "get_freqs() errors on an all-NA variable when na.rm is FALSE" | dual, `surveycore_error_all_na` |

Base-commit probe (scratch session, `withCallingHandlers()` +
`tryCatch()`): none of the five calls raises a warning, so no block needs
`expect_warning_count()` (D18). Row 5.5.3 raises
`"simpleError" "error" "condition"`, message "missing value where
TRUE/FALSE needed". For the PR description.

## Snapshot entries added (4)

Recorded on the unchanged code; the file is byte-identical (`cmp`) after
the `R/` change.

| Row | Message |
|---|---|
| 5.2.4 | Error in `.svy_rep_var()`: "All replicates produced NA estimates." |
| 5.3.1 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.7 | Error in `.svy_onestrat()`: "Unknown `lonely.psu` value: "unknown_value"." |
| 5.7.2 | Error in `get_freqs()`: "All values of y_allna are `NA`." plus the `i` bullet |

No other `_snaps/` file changed.

## Call counts (criterion 5, scratch session, `trace()` counters)

| Scenario | Before: `.build_cluster_matrices()` / `.svy_recvar()` | After |
|---|---|---|
| `freqs/tay` | 16 / 16 (15 cells + 1 in `.joint_vcov()`) | 1 / 1 |
| `freqs/rep` | 0 / 0 | 0 / 0 |

Both "after" values match criterion 5.

## Test runs (`NOT_CRAN=true`, `devtools::load_all()` + `testthat::test_file()`)

Equivalence file:

| Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| base, before task 1 (PR 3 record) | 29 | 2866 | 0 | 0 |
| base + new blocks (2nd run) | 34 | 2875 | 0 | 0 |
| changed | 34 | 2875 | 0 | 0 |

The first run with the new blocks reported 4 warnings: the four "Adding new
snapshot" notices.

Other affected files, each run on a `git archive HEAD` copy of the base and
on the changed tree. Every figure is identical on both:

| File | Blocks | Expectations | Failed | Warnings | Skipped |
|---|---|---|---|---|---|
| `test-analysis-freqs.R` | 112 | 518 | 0 | 51 | 0 |
| `test-analysis-helpers.R` | 147 | 365 | 0 | 2 | 0 |
| `test-analysis-methods-coef-vcov.R` | 128 | 341 | 0 | 0 | 0 |
| `test-labelled-analysis.R` | 52 | 236 | 0 | 0 | 0 |
| `test-nonprob-bootstrap-variance.R` | 27 | 85 | 0 | 3 | 0 |
| `test-variance-taylor.R` | 67 | 216 | 0 | 3 | 0 |
| `test-edge-conditions.R` | 28 | 39 | 0 | 2 | 1 |
| `test-analysis-variance.R` | 47 | 250 | 0 | 2 | 0 |

The full suite was not run.

## Break-it check

Each break applied alone, the equivalence file run, then the file restored
from a byte copy. After the last restore: `cmp` against the copies passes
for all three `R/` files, the snapshot file matches the task-1 copy, and
`git diff --ignore-cr-at-eol --stat` is the same as before the breaks (5
files, 281 insertions, 53 deletions).

| Break | Result |
|---|---|
| B1 rule 2: `diag(v) * (1 + 1e-9)` | RED: freqs quiet golden (21), freqs noisy golden (1) |
| B2 `check_rep_finite` branch: `rep_finite` without `all(is.finite(rep_mat))` | RED: freqs quiet golden (3), freqs noisy golden (3), row 5.2.4 (2: the error no longer fires) |
| B3 guarded subset sum: `which(ind > 0)[-1L]` | RED: freqs quiet golden (5) |
| B4 Taylor SE step skipped (`if (FALSE)`) | RED: freqs quiet golden (21), freqs noisy golden (1) |
| B5 `.attach_joint_vcov(..., v = v_all * 2)` | RED: freqs quiet golden (11), plus 4 blocks error on non-Taylor routes (`NULL * 2` is `numeric(0)`) |
| B6 `get_freqs()` passes `check_rep_finite = FALSE` (never subset sums) | GREEN, as expected: see E-5 |

D23 (removed in-loop flush in `get_variance()`): no PR 4 test covers it.
PR 4 does not touch the flush; gate 6 coverage stays its only guard.

## Errata

- **E-1 (spec §II.3, same shape as PR 3 E-1).** `.taylor_freq_cell()`
  takes a required `mats` that it never reads: the cell runs no variance
  call. Kept as the spec writes it.
- **E-2 (plan PR 4 task 2).** Task 2 says to commit the tests and
  snapshots before any `R/` change. The brief forbids commits. Ship as PR
  3 did: tests and `_snaps/` in the first commit, `R/` in the second, so
  criterion 3 (PR 3 criterion 4's check) passes. No `style:` commit is
  needed; all files were `air`-clean on the base.
- **E-3 (existing test, `test-analysis-freqs.R:2048`).** It calls
  `surveycore:::.freq_cell(list(fake = TRUE), c(1, 0), c(1, 1))` with three
  arguments. The new signature has five required arguments. The test still
  passes because the unsupported-class branch never reads `ctx` or
  `rep_N_d` (lazy evaluation). The file is unchanged, as gate 9 requires.
- **E-4 (rule 4 with `v` given).** Spec §IV: no known `get_freqs()` input
  fails the finite check. So the path "not `ok`, `v` supplied, `v`
  ignored" has no test through the public API. The rule 4 lines are
  covered by `get_variance()` (no `v`).
- **E-5 (B6, a speed-only change no test sees).** Forcing the full product
  (`check_rep_finite = FALSE`) keeps every result, and criterion 5 counts
  only Taylor calls. The subset sum exists for speed only, like the in-loop
  flush of D23. Gate 6 is again the guard: `.freq_rep_total()`'s `TRUE`
  branch goes uncovered if no call reaches it.
- **E-6 (scratch method, not the code).** My first counter run reset the
  counters with `ls(cnt)`, which hides the dot-named entries, so
  `freqs/rep` showed the cumulative 16 / 16. With
  `ls(cnt, all.names = TRUE)` it reads 0 / 0. A reviewer re-running counts
  should reset with `all.names = TRUE`.

## Hand-written additions (not dictated by the plan)

- `.freq_rep_total()` in `R/analysis-freqs-helpers.R`: the guarded sum runs
  at two sites (`rep_N_d` in `get_freqs()`, `rep_Y` in the cell), and one
  helper keeps the subset-or-full rule in one place, so `rep_N_d` and
  `rep_Y` always use the same form (§II.3 consistency rule; engineering
  preference 1). Both callers are in the `get_freqs()` family, so it sits
  in that family's helper file.
- `v_all <- NULL` before the `ctx$taylor` block, so the replicate,
  two-phase and nonprob SRS routes pass `v = NULL` to
  `.attach_joint_vcov()`.
- The `any(live)` guard in the SE step: with zero live cells
  `do.call(cbind, list())` is `NULL`, and spec §III.3 says no variance call
  runs then.
- `rep_N_d` is computed for every combination on the replicate route, also
  for a combination whose cells all return early (`n_g == 0`). It raises no
  condition and is not returned.
- Comments: the call-context comment, the `rep_N_d` comment, the SE-step
  section comment and the `.attach_joint_vcov()` comment in `get_freqs()`;
  the updated header and `@param` lines of the changed helpers; one header
  contents line for `.freq_rep_total()`.
- In 5.5.3, a one-line comment saying why the row has no snapshot (as PR
  3's 5.5.1).
