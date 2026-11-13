# Decisions — analysis-cell-performance

## D1 — scope is six functions (SETTLED, user, 2026-11-10)
`get_freqs()`, `get_means()`, `get_totals()`, `get_variance()`,
`get_covariance()`, `get_ratios()`. Only the first two were profiled.

## D2 — the single rowsum() pass is deferred (SETTLED, user, 2026-11-10)
Its gain was measured on the inner step only, and it replaces the cell loop
instead of moving work out of it. It needs its own spec.

## D3 — tests assert tolerance 1e-12 against the old path (SETTLED, user, 2026-11-10)
`identical()` held on R's reference BLAS in the prototypes. An optimized BLAS
may differ in the last bit, so the tests use `expect_equal(tolerance = 1e-12)`.
The spec records the `identical()` result as evidence, not as a test.

## D4 — get_freqs() replicate fix uses a guarded subset sum (SETTLED, user, 2026-11-10)
Use the subset sum over the cell's rows only when `all(is.finite(rep_mat))`,
checked once per call. Otherwise keep today's full n x R products. Nothing
rejects an NA or Inf replicate weight today (`verification-comprehension.md`
§NA replicate weights and the round-2 correction).

## D5 — get_ratios() Taylor uses two stacked calls (SETTLED, user, 2026-11-10)
One stacked call on the unscaled `z` columns for the SEs, one on the scaled
columns for `.vcov`. Exact on the reference BLAS.

## D6 — the lonely-PSU abort may move after the cell loop (SETTLED, user, 2026-11-10)
Under `survey.lonely.psu = "fail"` the abort raises the same class
(`surveycore_error_lonely_psu`). Warnings raised by later cells may now print
before it. The spec records this as an accepted change in condition order.

## D7 — the stacked diagonal gives no SE when any live column is not finite (SETTLED, orchestrator, 2026-11-10)
Follows from comprehension.md condition 1, verified in two rounds. Per call,
one `all(is.finite())` test on the stacked influence columns after the
calibration projection. When it fails, each SE comes from its own
`.svy_recvar()` call on the shared matrices, and the stacked call still
gives `.vcov`. Today's `.vcov` / `se^2` mismatch in that case is kept (D3).

## D8 — defaults taken without a user question (orchestrator, 2026-11-10; the user may reopen)
- `get_ratios()` calls 1 and 2 keep running: fix 1 and fix 3 apply to them,
  but their SE work is not removed. Removing it changes how many times the
  nonprob-SRS warning fires, which moves the 369-warning baseline.
- Two-phase hoists are out of scope: not profiled, and each needs new
  arguments in `R/variance-twophase.R`. Two-phase results must not change.
- Existing defects found in round 2 (NA base weight in variance/covariance,
  Inf base weight) are out of scope. The change keeps today's behaviour for
  each.

## D9 — D6 also covers errors raised by later cells (SETTLED, user, 2026-11-10)
Under `survey.lonely.psu = "fail"`, an error that a later cell raises inside
the loop now comes before the lonely-PSU abort and replaces it. Known cases:
`surveycore_error_all_na` in `get_freqs()` for a later all-`NA` variable under
`na.rm = FALSE`, and base R's calibration-projection error in a calibrated
`get_totals()` for a later cell with `NA` or `Inf` in `x`. The call still
aborts. Resolves the GAP in spec §X.1. Option not taken: a design-level
lonely-PSU check before the cell loop.

## D10 — Taylor SE calls run in blocks of at most 64 cells for three functions (SETTLED, user, 2026-11-10)
`get_variance()`, `get_covariance()` and the `get_ratios()` SE step need only
the diagonal. One stacked call over all `k` cells uses memory that grows with
`k^2` per stratum. Blocks of 64 give the same results for finite columns. So
"one variance call per call" does not hold for these three, and D5's SE call
becomes `ceiling(k / 64)` calls. Options not taken: one stacked call; no
stacking for these three.

## D11 — domain-restricted test designs use the existing test helper (planner default, 2026-11-10; the user may reopen)
Resolves comprehension.md §Open questions, domain-filtered designs. Tests set
the domain marker with `.testhelper_mark_domain()` in
`tests/testthat/helper-test-data.R`. It writes the same logical marker column
that `surveytidy::filter()` writes, through `@data`, so the validator runs.
`filter()` also appends to `@variables$domain`, which no code in `R/` reads.

### D9 applied in Stage 2r (orchestrator, 2026-11-10)
Methods review issue 3 found more conditions of the same kind: a base R
error from a later `get_means()` cell, a base R error for an `NA` base weight
in a later `get_variance()` / `get_covariance()` cell, and
`surveycore_error_lonely_psu_unknown_option`, which moves with the
lonely-PSU abort. D9 is read in general form: any condition that a later
cell raises may now come before the moved abort.

## D12 — get_variance() and get_covariance() flush the SE step per block, with a measured block size (SETTLED, user, 2026-11-10)
Spec review issue 8. Holding all `k` live influence columns before the SE step
needs an `n x k` matrix (about 2.9 GB at 1,000,000 rows and 360 cells). Today
these two functions hold one column at a time. The SE step therefore runs
inside the cell loop, once per block of live columns, with its own finite
check per block. A clean block uses the stacked diagonal. A block that fails
the check gives each of its cells its own `.svy_recvar()` call. Both forms are
exact. For these two functions, D7's "one finite check per call" becomes "one
per block". The block size is measured, not fixed at 64. The speed protocol
times sizes 16, 32 and 64 on the largest scenarios. The builder fixes the
constant at the smallest size within 5% of the fastest and records the
measurement. D10's blocks for the `get_ratios()` SE step use the same
constant. `get_ratios()` already holds `n x k` today for `.vcov`, so its SE
step need not flush inside the loop. The user asked whether 64 was fastest
and most memory-efficient. The answer: per-cell uses the least memory, block
size barely changes speed, and 64 was not measured.

## D13 — the golden fixture stays as a regression test (SETTLED, user, 2026-11-10)
Spec review issue 33. The fixture, its test file and the `data-raw/`
generator stay after the PR series. A later change that moves a result on
purpose regenerates the fixture with the generator. The file-level
`skip_on_cran()` stays, with runtime and tarball size as its reason. The
1e-12 tolerance already absorbs BLAS last-bit differences, so the BLAS reason
is dropped.

### D13 correction (orchestrator, 2026-11-10)
The skip does not make the tarball smaller: the fixture still ships under
`tests/`. It cannot go in `.Rbuildignore`, because a local `R CMD check` runs
the file with `NOT_CRAN = "true"` and fails when the fixture is missing. The
reason for `skip_on_cran()` is run time only.

## D14 — base-commit check for the golden fixture (orchestrator default, 2026-11-10; the user may reopen)
Spec review pass 2. The generator checks that the worktree HEAD equals the
sha passed in and that `R/` is clean against it. That does not prove the sha
is the true base. The first PR records the base sha in its description, and
the reviewer checks that it equals `develop` at branch cut. Option not taken:
a further `git log` check inside the generator.

## D15 — gate 6 "rule 3 with more than one block" means caller blocks (SETTLED, user, 2026-11-10)
Plan review pass 1, HOLD-1. Every caller of `.taylor_cell_se()` passes at
most `TAYLOR_SE_BLOCK` columns, so the helper's own split never runs a
second block through the public API. Gate 6's clause is met when a calling
function runs more than one block (`variance/blk65`, `covariance/blk65`,
`ratios/blk65`). Line coverage reaches every line of rule 3. No direct test
of the helper, no spec change. Options not taken: a direct helper test with
a test-spec erratum (B); removing the split from spec §III.3 rule 3 (C).

## D16 — test-spec erratum adds rows for unchecked spec behaviour (SETTLED, user, 2026-11-10)
Plan review pass 1, Spec Coverage S-2 and S-3. Add `test-spec.md` rows,
each written on the unchanged code before the PR's first `R/` commit:
- a `get_variance()` and a `get_covariance()` cell under the `na.rm = FALSE`
  override still joins the flush buffer, so under
  `survey.lonely.psu = "fail"` it raises `surveycore_error_lonely_psu`
  (spec §VII, §VIII, §III.4);
- kept errors that move relative to the lonely-PSU abort: grouped
  `get_totals()` and grouped `get_ratios()` with an `Inf` base weight
  (§X.3 row 3), calibrated `get_means()` with `Inf` in `x` (§V), calibrated
  `get_ratios()` with `NA` in either variable (§IX).
Options not taken: the override row only; no rows.

### D16 correction (orchestrator, 2026-11-10)
Plan review pass 2 probed the six rows on the base commit (`0c0a987`). All
six raise what the rows assert. D16's phrase "kept errors that move relative
to the lonely-PSU abort" holds for 5.5.8 only. 5.5.6 fires in the first
cell before any variance call, and 5.5.7 and 5.5.9 fire in `get_ratios()`
calls 1 and 2, whose abort does not move (spec §III.4). The rows stay as
proof that each kept error still fires. The same probe showed the
lonely-PSU message names the stratum by index ("Stratum 6"), not by label;
test-spec §5.3 and plan PR 3 are corrected.

## D17 — slim-pipeline trial on this arc (SETTLED, user, 2026-11-12)
The user approved a trial of `plans/proposal-slim-pipeline.md` on this arc.
The spec phase already ran under the old pipeline, so the trial covers the
ship phase only. Changes from the PLAN_READY plan:
- The builder reads `spec.md`, `test-spec.md`, the plan and this file. The
  isolation rule in plan §How to read this plan no longer applies. The two
  spec documents stay separate; they are not merged mid-arc.
- No tester and no shipper agent. Per PR: builder (opus) → leader runs the
  gates in the foreground → one reviewer (opus) reads everything, with the
  gate results → leader ships with `commit-and-pr` and watches CI.
- Plan PRs 1 and 2 ship as one PR, `test/analysis-cell-golden`. Plan note:
  the split existed only for the 12-row budget, and both are test-only.
  PRs 3 to 9 keep their plan entries; a later merge of two of them may be
  proposed under the advisory budget.
- For the trial comparison, record per PR: errata, BLOCKs/STOPs, CI cycles,
  hand-written additions, and anything the old tester would have caught
  that the reviewer did not.

## D18 — PR 1 (plan PRs 1+2) errata for later PRs (SETTLED, orchestrator, 2026-11-12)
Builder errata E-1 to E-7 (`prs/pr-1-analysis-cell-golden/implementation.md`)
and the reviewer's erratum list (`prs/pr-1-analysis-cell-golden/review.md`,
§Erratum for later PRs) stand as written. Each later builder reads both. The
points that change later PRs:
- `<std>` includes `"cv"`, so `get_covariance()` warns `cv_undefined` on most
  calls. The noisy set holds 76 ids, not 37. The covariance comparison sits in
  the noisy block (row 4.7.2), not the quiet one (4.7.1).
- PR 3, row 4.6.3: three of its four ids warn; assert their warnings.
- PR 5, row 5.1.9: wrap the call in
  `expect_warning_count(..., "surveycore_warning_cv_undefined", 2L)`. Every PR
  that writes a 5.1 row runs it on the unchanged code first and wraps it if it
  warns.
- PR 5, rows 5.3.5, 5.3.11, 5.3.15, 5.3.17: after the abort moves (D6), check
  that no `cv_undefined` warning fires before the lonely-PSU error.
- Plan §H.5 `expect_groups_match_domain()`: compare with `as.vector()`, not
  `unname()`. The `[rows]` subset drops the `label` attribute. Fixed in PR 1
  (review F-2).
- Review NOTEs F-3 to F-6 are not fixed. F-4 (`%||%` needs R 4.4) was fixed
  in the generator anyway; the guard (F-5) checks `R/` only.

## D19 — NaN check leaves out the interval columns (SETTLED, orchestrator, 2026-11-12)
PR #364 CI: Linux and macOS each failed 16 expectations, all
`is.nan(ci_high)` or `is.nan(moe)`, on 8 scenarios where an `NA` estimate
meets a `NaN` SE (`means/tay_y1_na`, `ratios/tay_c_zero_den` and six more).
The fixture, captured on Windows, holds `NaN` there; Linux and macOS give
`NA`. R does not fix which one arithmetic on `NA` and `NaN` returns (`?NA`).
`se`, the estimate and `.vcov` agreed on all three platforms.
Fix: `expect_matches_golden()` keeps the NaN-versus-NA check for every
double column except `ci_low`, `ci_high` and `moe`. The tolerance comparison
still asserts that those are missing in the same cells. The test file now
carries 2,838 expectations, not 3,664. Plan §H.5 and test-spec §5 step 298
("is.nan on every part") read with this exception. For the trial: the gates
ran on Windows only, so no local gate could catch this; CI did.

## D20 — PR 3 errata and trial record (SETTLED, orchestrator, 2026-11-12)
Builder errata E-1 to E-6 (`prs/pr-3-analysis-cell-variance/implementation.md`)
stand as written. The reviewer (`prs/pr-3-analysis-cell-variance/review.md`,
verdict PASS) agrees with E-1, E-2, E-3, E-5 and E-6, and in part with E-4.
- E-1: `spec.md` §II.3 gives `.taylor_variance_cell()` a `mats` argument it
  never reads. Kept as written.
- E-2: `R/analysis-helpers.R` and `R/analysis-variance-helpers.R` were not
  `air`-clean on `develop`. The reformat ships as its own `style:` commit.
- E-3: row 4.6.3 asserts the recorded warnings of three of its four ids (D18).
- E-4: criterion 4 checks that the first commit touching `_snaps/` holds no
  `R/` file and that the snapshots did not move after it. It does not check
  order on its own; task 2 asks for tests first. The leader committed
  style, then tests and snapshots, then `R/`. Criterion 4 passes.
- E-5: rule 3 runs one block per call inside `.taylor_cell_se()`; the case of
  more than one block comes from the caller (D15).
- E-6: rule 4 is guarded only by `variance/tay_y1_inf` and row 5.1.8.
- Row 5.5.1 raises `simpleError` on the base commit; the PR states it.

## D21 — warning baseline on this machine is 254 (SETTLED, orchestrator, 2026-11-12)
Plan §Standard gates, `test-spec.md` §8 and `CLAUDE.md` say 369. That figure
is for a library without `surveytidy` and `srr`. This machine has both, and
clean `develop` gives 254. PR 3 measured 254: no new warning. Later PRs on
this machine compare against 254.

## D22 — gate-script tree line and roxygen bump (SETTLED, orchestrator, 2026-11-12)
- `run-gates.sh` prints `Tree:` from `HEAD^{tree}`, so on an uncommitted
  tree it names the base commit, not the content it tested. The PR 3 gates
  tested the working tree that the three PR commits now hold.
- The gate run's `devtools::document()` bumped `Config/roxygen2/version` in
  `DESCRIPTION` to 8.1.1. The leader reverted it; it is not part of the PR.
- Gate 9: the branch also carries the PR 1 and 2 bookkeeping edits to
  `plans/implementation-plan-analysis-cell-performance.md` and
  `plans/pr-budget-calibration.md`, as a separate `docs:` commit by the
  leader's instruction. They are outside PR 3's Files touched.

## D23 — PR 3 reviewer NOTE carried forward (OPEN, orchestrator, 2026-11-12)
No test catches a removed in-loop flush in `get_variance()`: the reviewer
disabled it and the equivalence file stayed green. Only the gate 6 coverage
check catches it, because the line goes uncovered. A later PR that touches
the flush should add a scenario with more than 64 cells and a partial
buffer, or accept coverage as the guard.

Trial measures, PR 3: errata 6 (builder) plus D21 and D22 (leader); BLOCKs 0;
STOPs 0; hand-written additions by the leader: the `style:` commit split and
the DESCRIPTION revert, no code; CI cycles: recorded at ship time.
PR 3 shipped as #365, squash-merged to `develop` as `20d180c` on 2026-11-12. CI: 1 cycle, 7 of 7 checks passed on the first run.

## D24 — PR 4 errata and trial record (SETTLED, orchestrator, 2026-11-12)
Builder errata E-1 to E-6 (`prs/pr-4-analysis-cell-freqs/implementation.md`)
stand. The reviewer (`prs/pr-4-analysis-cell-freqs/review.md`, PASS, no
FIX-BEFORE-MERGE) agrees with all six.
- E-1 / N-3: `.taylor_freq_cell()` takes `mats` and never reads it, as the
  spec writes it (same shape as PR 3 E-1).
- E-2: tests and `_snaps/` ship in one commit, `R/` in a second. Done.
- E-3 / N-1: the direct `.freq_cell()` call at
  `tests/testthat/test-analysis-freqs.R:2048` passes 3 of 5 arguments and
  passes only because that branch reads neither `ctx` nor `rep_N_d`. A later
  edit that reads `ctx` first breaks it. That file predates PR 1, so gate 9
  keeps it out of this arc.
- E-4 / N-4: rule 4 with a supplied `v` cannot be reached through the API.
- E-5 / N-2: the guarded subset sum and `check_rep_finite` change speed
  only. Forcing the full product, or setting the `.cell_context()` default
  to `TRUE`, stays green. Only the gate 6 coverage check guards them.
- E-6: reset `trace()` counters with `ls(all.names = TRUE)`.
- N-5: three new test titles pass 80 columns; the plan fixes the titles.
- Row 5.5.3 raises `simpleError` on the base commit; the PR states it.
- No `style:` commit: all four `.R` files were `air`-clean on the base.
- The gate run bumped `Config/roxygen2/version` again (D22); reverted.
- Gate 6: the leader read the uncovered lines from `gate-7-covr.log`
  (`UNCOVERED_LINE`) instead of a second `covr` run. None is an added line.
- The PR commits were made before the gates, so the `Tree:` line names the
  tested tree (D22 does not recur).

Trial measures, PR 4: errata 6 (builder); BLOCKs 0; STOPs 0; hand-written
additions by the leader: none; CI cycles: recorded at ship time.
PR 4 shipped as #366, squash-merged to `develop` on 2026-11-13. CI: 1 cycle, 7 of 7 checks passed on the first run.

## D25 — PR 5 errata, leader edit and trial record (SETTLED, orchestrator, 2026-11-13)
Builder errata E-1 to E-5 (`prs/pr-5-analysis-cell-covariance/implementation.md`)
stand. The reviewer (`prs/pr-5-analysis-cell-covariance/review.md`, PASS, no
FIX-BEFORE-MERGE) agrees with all five.
- E-1 / N-3: `mats` is required and not read, as in PRs 3 and 4.
- E-2: `.variance_flush_se()` gained a second caller, `get_covariance()`.
  `code-style.md` §Internal helpers moves such a helper to a shared file in
  the same PR. **Leader edit:** a separate `refactor(analysis)` commit moved
  it, body byte-identical, from `R/analysis-variance-helpers.R` to
  `R/analysis-helpers.R`, beside `.taylor_cell_se()`, and updated both file
  headers and the pointer comment in `R/analysis-covariance.R`. Both files
  are outside PR 5's Files touched; the reviewer accepted the gate 9
  exception, because a copy would duplicate the override rule.
- E-3: D23 recurs for `get_covariance()`'s in-loop flush.
- E-4: tests and `_snaps/` in one commit, `R/` after. Done.
- E-5 / N-4: six of the seven new titles pass 80 columns; the plan fixes them.
- Row 5.5.2 raises `simpleError` on the base commit; the PR states it.
- N-1: no scenario puts an `na.rm = FALSE` override pair into a full block
  of 64, so an in-loop flush that ignored the override flag stays green
  (break K5). Carried with D23: both are flush paths that only coverage
  guards. A later PR may add a 65-cell `na.rm = FALSE` scenario.
- N-2: removing `res$infl <- NULL` stays green; it saves memory only.
- D18: the equivalence file runs with 0 warnings, so no `cv_undefined`
  fires before the moved lonely-PSU abort (D6).

Trial measures, PR 5: errata 5 (builder); BLOCKs 0; STOPs 0; hand-written
additions by the leader: the helper move (one commit, 20 lines moved, 4
comment lines changed); CI cycles: recorded at ship time.

## D26 — keep the roxygen version bump (SETTLED, user via the parent session, 2026-11-13)
From PR 6 on, do not revert the `Config/roxygen2/version` bump (8.1.0 to
8.1.1) that the gate run's `devtools::document()` writes to `DESCRIPTION`.
Commit it with the PR as its own `chore:` commit, and name `DESCRIPTION` in
the reviewer's write surface. Supersedes the revert in D22, D24 and D25.
PR #367 shipped without it; no change there.

PR 5 shipped as #367, squash-merged to `develop` on 2026-11-13. CI: 1 cycle, 7 of 7 checks passed on the first run.
