# Implementation — PR 5: `refactor/analysis-cell-covariance`

**Builder**: opus, 2026-11-13. Branch `refactor/analysis-cell-covariance`
at `32ed479`. Nothing is committed.

## Files changed

| File | Change |
|---|---|
| `R/analysis-covariance.R` | `get_covariance()`: call context, flush buffer with the `(ci_idx, key)` locator, end-of-loop flush |
| `R/analysis-covariance-helpers.R` | New signatures of `.covariance_pair_taylor()`, `.covariance_pair_replicate()`, `.covariance_pair_result()` |
| `tests/testthat/test-analysis-cell-equivalence.R` | 7 new blocks, under a new "get_covariance() rows" section |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | 5 new entries |

`DESCRIPTION`, `man/`, `NAMESPACE`, the golden fixture and every pre-PR-1
test file do not change. No roxygen changed, so I did not run
`devtools::document()`. All three `.R` files were `air`-clean on the base
and pass `air format --check` now, so no `style:` commit is needed.

## What each change does

- `.covariance_pair_taylor(design, x_col, y_col, domain, na.rm, mats)`: no
  matrix build, no option read, no `.svy_recvar()`. A pair that reaches the
  variance step returns `se = NA_real_` and `infl = unname(u)`. `se_srs` is
  still computed in the pair. Early returns are unchanged and have no
  `infl`. `mats` is required and not read (E-1).
- `.covariance_pair_replicate(..., na.rm, rep_mat)`: takes `rep_mat` from
  the context in place of converting the replicate columns per pair. The
  `rep_mat[active, ]` subset and the `colSums()` calls stay (§III.2).
- `.covariance_pair_result(..., na.rm, ctx)`: `ctx$mats` to the Taylor
  pair; `ctx$rep_mat` to the replicate pair on both replicate classes; the
  two-phase and nonprob SRS pairs get neither. The nonprob SRS warning
  stays where it was.
- `get_covariance()`: `ctx <- .cell_context(design)` just before the combo
  loop (`check_rep_finite = FALSE` by default). Per pair: take `infl` off
  the result, set the override flag where the `na.rm = FALSE` block sets
  `NaN`, store the result in `pair_results_this[[key]]`, then push `infl`,
  `ci_idx`, `key` and the flag into the buffer. At `TAYLOR_SE_BLOCK`
  entries the buffer flushes: SEs from `.variance_flush_se()`, written to
  `pair_results_this[[key]]$se` when the entry's `ci_idx` is the current
  one, else to `all_pair_results[[ci_idx]][[key]]$se`. After the combo
  loop, before step 11, a non-empty partial buffer flushes into
  `all_pair_results`. No `.vcov`.

## Tests added (test-spec row ids)

All seven written and run on the unchanged code first; all passed there.

| Row | Block | Assertion |
|---|---|---|
| 5.1.9 | "get_covariance() gives each clean group the SE of its own domain when another group has an Inf" | `expect_groups_match_domain()` inside `expect_warning_count(..., "surveycore_warning_cv_undefined", 2L)` (D18) |
| 5.2.10 | "get_covariance() errors when every replicate weight is NA on a row inside a cell" | dual, `surveycore_error_all_replicates_na` |
| 5.3.5 | "get_covariance() errors on a single-PSU stratum when lonely.psu is fail" | dual, `surveycore_error_lonely_psu` |
| 5.3.11 | "get_covariance() errors on a single-PSU stratum when lonely.psu is an unknown value" | dual, `surveycore_error_lonely_psu_unknown_option` |
| 5.3.15 | "get_covariance() errors on a single-PSU stratum under fail when the call has 65 cells" | dual, `surveycore_error_lonely_psu` |
| 5.3.17 | "get_covariance() errors on a single-PSU stratum under fail when its only pair has an NA and na.rm = FALSE" | dual, `surveycore_error_lonely_psu` |
| 5.5.2 | "get_covariance() still errors when a base weight inside a cell is NA" | `simpleError`, no snapshot |

Base-commit probe (scratch session, `withCallingHandlers()` +
`tryCatch()`):

| Call | Warnings | Condition |
|---|---|---|
| 5.1.9 grouped (`covariance/tay_y1_inf`) | 1 × `cv_undefined` | none |
| 5.1.9 ungrouped, group A | 1 × `cv_undefined` | none |
| 5.1.9 ungrouped, group C | none | none |
| 5.2.10 | none | `surveycore_error_all_replicates_na` |
| 5.3.5 | none | `surveycore_error_lonely_psu` |
| 5.3.11 | none | `surveycore_error_lonely_psu_unknown_option` |
| 5.3.15 | none | `surveycore_error_lonely_psu` |
| 5.3.17 | none | `surveycore_error_lonely_psu` |
| 5.5.2 | none | `"simpleError" "error" "condition"`, "missing value where TRUE/FALSE needed" (for the PR description) |

D18 check for 5.3.5, 5.3.11, 5.3.15, 5.3.17: the same calls under the
default `"remove"` raise `cv_undefined` (5.3.5 and 5.3.15) or nothing
(5.3.17). After the change, the equivalence file reports 0 warnings, so no
`cv_undefined` fires before the moved abort. The warning comes from the
variance columns (step 16), after the final flush, so the abort always
comes first.

## Snapshot entries added (5)

Recorded on the unchanged code. After the `R/` change the file is
byte-identical (`cmp`) to the copy taken after task 1. Only additions in
`git diff`; the file stays LF.

| Row | Message |
|---|---|
| 5.2.10 | Error in `.svy_rep_var()`: "All replicates produced NA estimates." |
| 5.3.5 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.11 | Error in `.svy_onestrat()`: "Unknown `lonely.psu` value: "unknown_value"." |
| 5.3.15 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.17 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |

## Call counts (criterion 5, scratch session, `trace()` counters, reset with `ls(all.names = TRUE)`)

| Scenario | Before: `.build_cluster_matrices()` / `.svy_recvar()` | After |
|---|---|---|
| `covariance/blk65` | 65 / 65 | 1 / 2 |
| `covariance/blk64` | 64 / 64 | 1 / 1 |
| `covariance/rep_na` | 0 / 0 | 0 / 0 |

All three "after" values match criterion 5.

## Test runs (`NOT_CRAN=true`, `devtools::load_all()` + `testthat::test_file()`)

Equivalence file:

| Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| base, before task 1 (PR 4 record) | 34 | 2875 | 0 | 0 |
| base + new blocks, 1st run | 41 | 2898 | 0 | 5 (the five "Adding new snapshot" notices) |
| base + new blocks, 2nd run | 41 | 2893 | 0 | 0 |
| changed | 41 | 2893 | 0 | 0 |

Other files that call `get_covariance()`, each run on a `git archive HEAD`
copy of the base and on the changed tree. Every figure is identical:

| File | Blocks | Expectations | Failed | Warnings | Skipped |
|---|---|---|---|---|---|
| `test-analysis-covariance.R` | 69 | 246 | 0 | 5 | 0 |
| `test-analysis-methods-coef-vcov.R` | 128 | 341 | 0 | 0 | 0 |
| `test-collection-if-missing-var-rename.R` | 11 | 18 | 0 | 7 | 0 |
| `test-labelled-analysis.R` | 52 | 236 | 0 | 0 | 0 |
| `test-nonprob-bootstrap-variance.R` | 27 | 85 | 0 | 3 | 0 |

The full suite was not run (D21 baseline 254 is the leader's gate).

## Break-it check

Each break applied alone with Edit, the equivalence file run, then
`R/analysis-covariance.R` restored from a byte copy (`cmp`). After the last
restore, `cmp` passes for both `R/` files, the test file and the snapshot
file against their copies, and `git diff --ignore-cr-at-eol --stat` shows
the same 4 files, 290 insertions, 25 deletions.

| Break | Result |
|---|---|
| B1 moved abort (D6): override pairs kept out of the buffer (`!is.null(infl) && !override`) | RED: 5.3.17 (2: class and snapshot) |
| B2 assembly: in-loop flush drops the write to an earlier combination | RED: covariance noisy golden (4) |
| B3 assembly: final flush writes `se * (1 + 1e-9)` | RED: covariance quiet golden (1), noisy golden (30) |
| B4 in-loop full-block flush disabled (`== TAYLOR_SE_BLOCK + 100000L`) | GREEN: see E-3 |
| B5 final flush ignores the override flag | RED: covariance noisy golden (3: the `na.rm = FALSE` ids) |

`.vcov`: no `.vcov` is assembled for this function. Row 4.6.3 (PR 3)
asserts `expect_null(attr(r, ".vcov"))` on `covariance/tay_c_na` and
`covariance/blk65`, and stays green.

## Errata

- **E-1 (spec §II.3, same shape as PR 3 E-1 and PR 4 E-1).**
  `.covariance_pair_taylor()` takes a required `mats` that it never reads:
  the pair runs no variance call. Kept as the spec writes it.
- **E-2 (helper placement; plan Files touched against `code-style.md`
  §Internal helpers).** The flush reuses `.variance_flush_se()` from
  `R/analysis-variance-helpers.R`, so the `NaN` override rule stays in one
  place (engineering preference 1). That helper now has callers in two
  files. `code-style.md` says to promote it to a shared file in the PR that
  adds the second call site, and PR 3's write-up proposed
  `R/analysis-helpers.R`. Both files are outside PR 5's Files touched, so I
  did not move it. Its header comment still says "get_variance()'s Taylor
  buffer". A comment in `get_covariance()` names the cross-file call. The
  leader decides: allow a small move and rename in this PR (for example
  `.taylor_flush_se()` in `R/analysis-helpers.R`, which PR 6 also touches),
  or defer it. The other option, a copy in the covariance helpers, would
  duplicate the override rule.
- **E-3 (D23 repeats for `get_covariance()`).** B4 stays green: with the
  in-loop flush disabled, every column waits for the final flush,
  `.taylor_cell_se()` splits it into blocks, and every result and snapshot
  stays the same. 5.3.15 also stays green, because the final flush aborts.
  Only gate 6 coverage guards the in-loop flush. `covariance/blk64` reaches
  the full in-loop flush (the current-combination branch), and
  `covariance/blk65` reaches the earlier-combination branch and the partial
  final flush (criterion 7).
- **E-4 (plan PR 5 task 2).** The brief forbids commits. Ship as PRs 3 and
  4 did: tests and `_snaps/` in the first commit, `R/` in the second.
- **E-5 (minor, title length).** Six of the seven new `test_that()` titles
  pass 80 columns. The plan fixes the titles; `air` does not wrap strings
  (PR 3 F-7, PR 4 N-5).

## Hand-written additions (not dictated by the plan)

- The buffer is four parallel vectors (`buf_infl`, `buf_ci`, `buf_key`,
  `buf_override`); the spec names the entry contents, not the structure.
- The push sits after `pair_results_this[[key]] <- res`, so the flush can
  write to the stored result.
- The final flush writes only to `all_pair_results`: every combination is
  stored when the loop ends.
- `se_blk` as the local name for the flushed SEs.
- Comments: the call-context comment, the buffer comment (with the
  cross-file note of E-2), the final-flush comment, the updated header and
  `@param`/`@return` lines of the three changed helpers.
- In 5.1.9, a two-line comment saying where the two warnings come from; in
  5.3.17, a three-line comment saying why the row exists; in 5.5.2, the
  one-line no-snapshot comment of PRs 3 and 4.
- Rows 5.3.5, 5.3.11, 5.3.15 and 5.3.17 are not wrapped in
  `expect_no_warning()`; the file's 0-warning count is the D18 check.
