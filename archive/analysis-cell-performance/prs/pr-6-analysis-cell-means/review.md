PASS

# Review — PR 6: `refactor/analysis-cell-means`

Reviewer: opus, 2026-11-13. Diff `origin/develop...HEAD` at `ad03ff5`
(tree `838863a`, the tree the gates ran on). No FIX-BEFORE-MERGE finding.

## Scope and write surface

- `git diff --name-only`: the three `R/` files and two test files of PR 6
  Files touched, `DESCRIPTION` (D26, roxygen 8.1.0 to 8.1.1, not a
  finding), and three `plans/` files (leader bookkeeping, D22).
- No path under `.surveycore-workspace/`. The fixture rds is not in the
  diff. `--diff-filter=M -- tests` lists only
  `test-analysis-cell-equivalence.R` and its `_snaps/` file, both created
  in PR 1.
- `_snaps/analysis-cell-equivalence.md`: three added entries only (5.2.5,
  5.3.2, 5.3.8). No existing entry changes.
- `air format --check` passes on all four changed `.R` files.

## Tasks and acceptance criteria

| Item | Result |
|---|---|
| Task 1, ten blocks | All present, titles and calls as the plan writes them |
| Task 2, tests before `R/` | Yes: `3f34486` (tests, snaps) precedes `ad03ff5` (`R/`) |
| Task 4, §II.3 signatures with defaults | Exact match for all three cells |
| Task 4, the `.mean_cell()` call | Exact match, `R/analysis-means.R:241-248` |
| Task 4, SE step of §III.3 row 1 | Exact match, `R/analysis-means.R:267-285` |
| Task 4, one `crossprod()` of §III.2 | `R/analysis-means-helpers.R:207` |
| Task 4, cell df rules of §V | `R/analysis-means-helpers.R:116-140` |
| Task 4, `get_quantiles()` call untouched | `R/analysis-quantiles-helpers.R:154` not in diff |
| Task 5, `.degf_taylor()` comment | `R/analysis-helpers.R:347-350` |
| Task 5, §III.7 stale comment | `R/analysis-means-helpers.R:44-46` |
| Criterion 1-3 | Pass in my run of the equivalence file (51 blocks, 2920 expectations, 0 failed) |
| Criterion 4 | Snapshot entries are additions only; builder reports byte-identical after `R/` |
| Criterion 5 | Builder counts: 1/1, 1/1, 0/0, 0 `.degf_taylor()`. Not re-measured. |
| Criterion 6 | Golden blocks green (my run) |
| Criterion 7 (G) | Gate 2: FAIL 0, WARN 254 (= D21 baseline). Gate 5: `Status: 1 NOTE`, CRAN incoming only. covr 96.65%. Gate 7 lists `R/analysis-means-helpers.R:317` and `:385` as uncovered; neither is in an added hunk (added hunks span 44-64, 96-110, 124-161, 169-177, 201-210, 396-432). |

## Results cannot move: independent comparison

Script `cmp_means.R` (scratchpad) ran the same 2412 calls on a
`git archive origin/develop` copy and on HEAD, each in its own R process,
and compared with `identical()` (result tibble with every attribute,
`.vcov` included, and the ordered list of warnings, or the error class and
message).

- Designs: 31 golden designs (Taylor with and without FPC, probs, SRS,
  strata only, two-stage, lonely, five calibrated shapes, replicate with
  `NA`/`Inf`/zero/all-`NA` replicate weights, nonprob replicate and SRS,
  two-phase, every `*_dom` filtered design, empty domain, `NA` and `Inf`
  base weights) plus two of mine: calibrated `nest = FALSE`, and calibrated
  `nest = TRUE` with PSU labels reused across strata.
- Variables: `y1`, `y1_na`, `y1_inf`, `y1_c_zero`, `y1_c_na`, `y_allna`,
  `y1_gap`; groups none, `group`, `group_na`, `g_one` (single level),
  `single`; `na.rm` TRUE and FALSE; all six `variance` columns.
- `get_quantiles()` ungrouped and grouped on every design.
- `survey.lonely.psu` = remove, adjust, average, certainty, fail and an
  unknown value, on `lonely`, `tay`, `multi`, with `y1` and `y1_na`.

Result: 0 mismatches. 333 calls error on both trees with the same class and
message; 1340 warnings match in order; 1682 results carry `.vcov`, all
identical with dimnames. Zero-weight rows cannot reach a Taylor design: the
constructor refuses non-positive weights and the S7 setter refused my
`@data` write, so `rep_zero` is the only zero-weight case.

Why df cannot move, by class:

- Uncalibrated Taylor, replicate, nonprob, two-phase: `get_means()` reads
  `acc_df` only when `has_calibration` (`R/analysis-means.R:305-308, 323,
  362`). The base value was computed and dropped; the skip changes nothing.
  `get_quantiles()` reads only `mean` and `se`.
- Calibrated Taylor: `.degf_taylor()` reads only `ids[[1L]]`, `strata` and
  `nest` (`R/analysis-helpers.R:357-393`), and rows stay `domain > 0`. The
  four branches are covered by `cal_srs`, `cal_strat`, `cal_ids`, `cal`
  and `cal_multi`, plus my two nest variants; all identical.
- The cell predicate drops `S7_inherits(design, survey_taylor)`; the cell is
  reached only through the `survey_taylor` branch of `.mean_cell()`, and
  `survey_nonprob` has parent `survey_base`, not `survey_taylor`.

Replicate `crossprod()`: R 4.6.1 here reports no external BLAS
(`La_library()` empty), so the reference BLAS runs `dgemv` (old) and
`dgemm` with `transa = "T"` (new), which both add over rows in the same
order. With a non-finite operand both forms take R's internal loop. The
`rep_na`, `rep_inf`, `rep_allna` and `np_rep*_na` calls are identical. The
§III.2 caveat stands: an optimised BLAS is not covered by this proof, only
by the 1e-12 golden tolerance.

Condition order: under `lonely.psu = "fail"` the abort now fires after the
loop; §X.1 accepts it. On the calls I ran the warning lists matched, so no
case here produced a visible change.

## E-1: test-spec note on row 5.1.10

The builder is right; the note is wrong. Measured on the base commit:

| Design | Group A `se^2` | `.vcov[A, A]` |
|---|---|---|
| `tay` (uncalibrated) | 0.5283716 | `Inf` |
| `tay_nofpc` | 0.5327107 | `Inf` |
| `strat` | 0.6402274 | `Inf` |
| `multi` | 0.3082293 | `Inf` |
| `cal` | 0.5133067 | `Inf` |

Mechanism: for a mean, the `NA` in group B makes `ybar` `NA`, so the whole
influence column is `NA` (out-of-domain rows give `0 * NA`). Every stratum
then drops from the stacked call and the clean diagonals are `Inf`. The
"finite but rescaled" case of §X.2 is `get_totals()`, whose column has one
`NA` row only. The note appears to be carried over from the totals row.

The row as written asserts the right thing: finite `se`, and a stored
diagonal that is not `se^2`. `isTRUE(all.equal(Inf, x))` is `FALSE`, so it
passes, and builder break B2 shows it turns red when the SE is read from
the diagonal. A stronger form would add `expect_false(is.finite(...))`, but
that pins a value the spec calls kept, not required. NOTE only: correct the
note in `test-spec.md` at archive time.

## E-2: the copied SE step

The two copies are byte-identical: `diff` of `R/analysis-freqs.R:401-419`
against `R/analysis-means.R:267-285` prints nothing (comment, `v_all`,
`kinds`, `live`, `vals`, the `.taylor_cell_se()` call, all 19 lines).

Verdict: acceptable to defer from this PR, NOTE, with a decision needed
before PR 7 starts. Reasons:

1. `spec.md` §II.2 closes the list of added helpers (`TAYLOR_SE_BLOCK`,
   `.cell_context()`, `.taylor_cell_se()`), and §III.3 "The SE step per
   function" writes the step out per function. Extracting a fourth helper
   is a spec change, not a builder or reviewer call.
2. Extracting now means editing `R/analysis-freqs.R`, which is outside
   PR 6 Files touched (gate 9). Extracting into `R/analysis-helpers.R` with
   only `get_means()` calling it leaves the freqs copy and removes nothing.
3. PR 7 adds the third identical copy (`get_totals()`, same §III.3 row).
   That is the point where one change removes all three.

But PR 7's Files touched do not name `R/analysis-freqs.R` or
`R/analysis-means.R` either, so "PR 7" is not yet a plan; it needs a
decision. Recommendation (D27, leader or user): amend PR 7 to add, in
`R/analysis-helpers.R`,

```r
.taylor_se_step <- function(design, acc_joint, acc_se, ctx)
# returns list(se = acc_se, v = v_all)
```

and to replace the three copies, adding the two files to PR 7 Files
touched. `get_ratios()`, `get_variance()` and `get_covariance()` run
different SE steps (blocks, flush buffer) and stay outside it. Engineering
preference 1 says not to defer DRY; the spec fixed this shape, so the
record of why it waits one PR belongs in `decisions.md`.

The calibration predicate (`!is.null(design@calibration) &&
length(design@calibration) > 0L`) now has a fourth copy at
`R/analysis-means-helpers.R:118` (others: `R/calibration.R:450, 468`,
`R/analysis-means.R:305-307`). NOTE: a `.has_calibration()` in
`R/calibration.R` is outside every PR's write surface; raise an issue.

## E-4: `test-effective-n.R` alone

Refuted as a defect, confirmed as an artifact. Gate 2 ends
`[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16719 ]`; its only `test-effective-n.R`
entries are warnings (lines 1652-1690), not failures, and
`_snaps/effective-n.md` is not in the diff. The committed snapshot holds
two header lines: `print.survey_effective_n` at
`R/analysis-effective-n.R:384` and a second from the `survey_result` print
at `R/analysis-meta.R:117`. The second appears only when that method is
dispatched, which holds under `devtools::test()` and not under the
builder's `load_all()` + `test_file()`. The builder saw the same four
failures on the base tree, so this PR does not cause it. NOTE: it is an
order or registration dependence in a pre-existing snapshot; worth an issue,
not a blocker.

## Other errata

- E-3 (B5 green): confirmed in kind by my K2 and K4 below. Only the
  criterion 5 call counts guard the performance claims. Same as PR 4 E-5.
- E-5 (titles over 80 columns): plan fixes the titles; `air` passes. NOTE.
- E-6, E-7: as D26 and PRs 3-5. No finding.

## Findings

- NOTE `test-spec.md` row 5.1.10: the "finite but rescaled" note is wrong
  for means (E-1 above).
- NOTE `R/analysis-means.R:267-285`: byte-identical copy of
  `R/analysis-freqs.R:401-419`. Needs a D27 before PR 7 (E-2 above).
- NOTE `R/analysis-means-helpers.R:118`: fourth copy of the calibration
  predicate.
- NOTE `R/analysis-means-helpers.R:207`: the `crossprod()` equivalence is
  proved for the reference BLAS only; an optimised BLAS is held to the
  1e-12 golden tolerance, not to `identical()`.

## Break-it check

Each break was applied alone with `sed`, then only
`test-analysis-cell-equivalence.R` was run (`load_all()` + `test_file()`,
one R process at a time), then both files were restored from byte copies.

| Break | Target | Result |
|---|---|---|
| K1 | `.degf_taylor()` on all rows, not `domain > 0` | RED: means quiet golden (6), noisy golden (2) |
| K2 | calibrated-only condition replaced by `TRUE` (df on every Taylor design) | GREEN: df is unused for uncalibrated designs; only call counts see it (E-3 family) |
| K2b | condition replaced by `FALSE` (no df on calibrated designs) | RED: means quiet (7), noisy (2) |
| K3 | SE step passes `v = v_all`, not `v_all[live, live]` | RED: means quiet golden (1) |
| K4 | `.attach_joint_vcov()` without `v = v_all` (second stacked call) | GREEN: same values; only call counts see it (E-3 family) |
| K6 | `NA` replicate weights set to 0 before `crossprod()` | RED: means quiet golden (1) |
| K7 | `dimnames(ctx$mats$clusters_mat) <- NULL` | GREEN: harmless, names are not read |

Clean-tree proof after the last restore: `git status --short` shows only
`?? plans/proposal-slim-pipeline.md`; `git diff --stat` is empty; no
`.new.md` [no such file] file under `tests/testthat/_snaps/`.

## Blind tester comparison

No tester `audit.md` [no such file] exists for PR 6 in the run directory, so there is
nothing to compare. My independent checks (the 2412-call `identical()`
comparison and the seven breaks) agree with the builder's write-up and the
leader's gate summary on every point they share. The one disagreement is
with `test-spec.md`, not with the builder: row 5.1.10's note (E-1).
