# Implementation — PR 1 (plan PRs 1 and 2): `test/analysis-cell-golden`

**Builder**: opus, 2026-11-12
**Branch**: `test/analysis-cell-golden`, HEAD `0c0a98752351b1ce3991aa7fdbdc513d8654085d` (= `origin/develop`). Nothing committed.
**Base commit recorded in the fixture**: `0c0a98752351b1ce3991aa7fdbdc513d8654085d`.

## Files

| File | Status | Lines |
|---|---|---|
| `tests/testthat/helper-cell-golden.R` | new | 1204 (after `air format`; the 76-entry noisy table is about 300 of them) |
| `tests/testthat/test-analysis-cell-equivalence.R` | new | 217 |
| `data-raw/analysis-cell-golden.R` | new | 140 |
| `tests/testthat/fixtures/analysis-cell-golden.rds` | new, generated | 182,472 bytes |
| `plans/{spec,test-spec,decisions,comprehension,implementation-plan}-analysis-cell-performance.md` | copied from the run directory, byte-identical (`cmp`); `decisions` holds D1 to D17 | — |

No file under `R/` changed: `git diff --quiet --ignore-cr-at-eol origin/develop -- R` exits 0. No existing test file changed. No `_snaps/` file changed (the CRLF-only rewrites were restored). `air format --check` passes on the three `.R` files. `plans/proposal-slim-pipeline.md` is untracked and was not touched.

## Fixture

- 261 scenarios: 185 quiet, 76 noisy (after reconciliation).
- `xz`-compressed, 182,472 bytes (under the 300 KB budget).
- `provenance$base_sha` = `0c0a98752351b1ce3991aa7fdbdc513d8654085d`; R 4.6.1 (ucrt); `matprod` "default"; `blas` and `lapack` record `""` on this Windows build.
- Generated from a scratch worktree at the base commit (`git worktree add`), which was removed afterwards (`git worktree remove`).
- Generator run time: about 25 s. No scenario errored.

**Guard check (task 4).** With `# guard test` appended to `<dir>/R/utils.R`, the generator stopped before `load_all()` and wrote no fixture:

```
Error: Check `git status --porcelain -- R` failed: C:/Users/jdennen/AppData/Local/Temp/claude/.../scratchpad/base has changes under R/:
 M R/utils.R
No fixture written.
```

The edit was reverted, `git -C <dir> status --porcelain` printed nothing, and the clean run wrote the fixture.

**Perturbation check (task 7).** `fixture$results[["means/tay"]]` with `se[1]` multiplied by `1 + 1e-10` fails `expect_matches_golden()`: "Expected means/tay to equal `expected`", `se` 0.726891744430 against 0.726891744357.

## Noisy-table reconciliation (task 5)

The fixture's recorded warnings replaced the plan's table. `cell_golden_noisy` is now written as literals from the fixture.

- **36 covariance ids moved into the noisy table**, each with one `surveycore_warning_cv_undefined`: all 20 core ids (`covariance/tay` ... `covariance/tay_fail`), and `tay_ungrouped`, `tay_full`, `tay_narm_false`, `tay_many`, `tay_c_na`, `gss`, `tay_y1_inf`, `nawt_out`, `rep_na`, `blk16`, `blk17`, `blk32`, `blk33`, `blk64`, `blk65`, `blk65_inf`. `covariance/tay_c_na` records 2 × `covariance_all_na` + 1 × `cv_undefined`.
- **3 ratios ids moved**: `ratios/blk64`, `ratios/blk65`, `ratios/blk65_na`, each 1 × `cv_undefined`.
- **1 variance id moved**: `variance/tay_c_na`, 1 × `variance_all_na`.
- **Counts changed**: `covariance/small_cell` adds 1 × `cv_undefined` (now 2 warnings); `covariance/np_rep10_na` adds 1 × `cv_undefined` (now 2); `ratios/np_rep10_na_dom` is 2 × `domain_replicates_na`, not 3.
- **1 id removed**: `totals/tay_allna` records no warning and is now quiet.
- 37 + 40 − 1 = 76 noisy. The total stays 261.
- `means/rep_y1_inf` and `means/np_rep_y1_inf` record no warning (quiet). PR 6 can rely on both. `freqs/rep_zero` is quiet.

Quiet/noisy split per function: freqs 32/4, means 43/7, totals 33/5, variance 37/9, covariance 2/43, ratios 34/8, quantiles 3/0, effn 1/0.

## Test results

`NOT_CRAN=true`, `testthat::test_file("tests/testthat/test-analysis-cell-equivalence.R")` after `devtools::load_all()`: **21 blocks, 3664 expectations, 0 failed, 0 warnings, 0 skipped, 0 errors**, about 50 s.

`tests/testthat/test-analysis-means.R` (to confirm the new helper file does not disturb existing tests): 348 expectations, 0 failed, 3 skipped (pre-existing), 0 errors.

Not run (leader's gates): full `devtools::test()`, `devtools::check()`, `covr`, `pkgdown`.

## Break-it checks

Each edit was reverted with `git checkout -- R/<file>`; afterwards `git diff --quiet --ignore-cr-at-eol origin/develop -- R` exited 0.

1. **Taylor**: `R/analysis-means-helpers.R`, `se <- sqrt(max(0, v[1L, 1L]))` → `* (1 + 1e-9)` inside the root. 34 failures, three blocks red:
   - get_means() quiet: 30 ids (every Taylor, calibrated, two-phase and domain means id);
   - get_quantiles()/get_effective_n(): `effn/tay`;
   - get_means() noisy: `means/single`, `means/small_cell`, `means/cal_srs_two`.
2. **Replicate**: `R/variance-replicate.R`, `.svy_rep_var()` final line `* scale` → `* scale * (1 + 1e-9)`. 43 failures, eleven blocks red: quiet freqs (8 ids), means (8), totals (6), variance (5), ratios (5); noisy freqs, means, totals, variance (1 each), covariance (6), ratios (1). `quantiles/rep` stayed green: `get_quantiles()` does not reach `.svy_rep_var()`.

The NA-marker blocks stay green under both edits, as expected: both sides run the current code.

## Row coverage

| Row | Block |
|---|---|
| 4.0 | "the golden fixture designs build and pass the design invariants" |
| 4.1 | "every golden scenario is asserted by at least one block" |
| 4.2 | "the six analysis functions keep their base-commit formals" |
| 4.3.1 / 4.3.2 | "get_freqs() matches ... every quiet scenario" / "get_freqs() raises ... every noisy scenario" |
| 4.4.1 / 4.4.2 | the same for get_means() |
| 4.5.1 / 4.5.2 | the same for get_totals() |
| 4.6.1 / 4.6.2 | the same for get_variance() |
| 4.7.1 / 4.7.2 | the same for get_covariance() (quiet block has 2 ids; see E-1) |
| 4.8.1 / 4.8.2 | the same for get_ratios() |
| 4.9.1 | "get_quantiles() and get_effective_n() match the base-commit results" (4 ids) |
| 5.2.1 | 9 ids in their function's quiet block; `covariance/rep_na` in the get_covariance() noisy block (E-2) |
| 5.2.2 | `freqs/rep_zero` in the get_freqs() quiet block |
| 5.2.3 | the five ids in their function's noisy block |
| 5.3.13 | "a call that errors under lonely.psu fail raises no small-cell warning" (6 entries) |
| 5.6.1 / 5.6.2 / 5.6.3 | "an NA domain marker gives the same results as FALSE on a Taylor / replicate / two-phase design" |
| 5.6.4 | "... on a nonprob design without replicate weights": observed count 3, equal to the reasoned count |

## Errata

- **E-1 (plan §H.4/§H.6, test-spec §2.7/§3).** `<std>` includes `"cv"`. `get_covariance()` warns `surveycore_warning_cv_undefined` once per call when any cell's covariance is 0 or negative. That is almost every covariance call, so 36 covariance ids are noisy, not quiet, and the quiet covariance block (4.7.1) covers only `covariance/tay_pair` and `covariance/tay_empty_dom`. The results are still compared, in 4.7.2. PR 5's builder should expect the noisy block, not the quiet block, to carry the covariance coverage. Three ratios block-size ids warn the same way.
- **E-2 (test-spec §5.2 row 5.2.1, plan PR 2 AC 3).** Row 5.2.1 says `covariance/rep_na` is "in the quiet loops". It records `cv_undefined`, so it is asserted by the noisy block. AC 3's wording ("asserted by the loop block of their function") still holds.
- **E-3 (test-spec row 4.6.3, later PR).** Row 4.6.3 reads `.vcov` from `variance/tay_c_na`, `covariance/tay_c_na` and `covariance/blk65`. All three are noisy now, so that block must run them through `expect_warning_count()` with their recorded warnings.
- **E-4 (plan §H.6 noisy table).** `totals/tay_allna` raises no warning; `ratios/np_rep10_na_dom` raises 2, not 3; `variance/tay_c_na` raises `variance_all_na`. All corrected from the fixture, as §H.6 directs.
- **E-5 (plan PR 2 task 5, test-spec §5.6).** The Taylor, replicate and two-phase NA-marker rows are not warning-free: `get_covariance()` raises 1 × `cv_undefined` on both `a` and `b`. Asserted with `expect_warning_count()` on both sides, as the task allows.
- **E-6 (plan §Shipping constraints).** It says `decisions.md` holds D1 to D16; the copy holds D1 to D17, as instructed.
- **E-7 (minor).** `provenance$blas` and `provenance$lapack` are `""` on this R build. Tests never read them.

## Departures from the plan

- **Scenario wrappers.** Extra scenarios call `.cg_std(fn, design, ...)` (adds `<std>`) or `.cg_raw(fn, design, ...)`, not a written-out call per id. Arguments reach the function through `...`, so tidy-eval sees the same expressions. Measured on `get_covariance(c(y1, y2), group = group)`: the stripped results are `identical()`. Only `.meta$call` differs, and it is stripped.
- **Loop bodies extracted.** The §H.7 quiet and noisy bodies are two functions at the top of the test file, `expect_quiet_golden(prefix)` and `expect_noisy_golden(prefix)`, with `golden_ids()` for the quiet/noisy split. Each block is one call. The NA-marker body is `expect_na_marker_matches(class, warnings)`. Each still asserts `expect_gt(length(ids), 0L)` first.
- **`cell_core_calls()`** uses the constant `.cg_variance` for the six variance options.
- **Generator error naming.** The generator wraps each scenario in `tryCatch()` to stop with the scenario id when it errors (none did).
- **Block order.** PR 2's quiet blocks sit after PR 1's quiet blocks, and its noisy blocks after PR 1's noisy blocks; the cross-function rows come last.
