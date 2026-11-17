## Spec Review: analysis-cell-performance — Pass 1 (2026-11-10)

Six lens agents (DRY, test completeness, contract, edge cases, engineering
level, API coherence) read spec v1.1 and the test-spec, and checked claims
against `R/`. Each issue is listed once. Where two lenses found the same
problem, both are named. The "Route" column says how the orchestrator
resolves it: **fix** means one answer follows from the house rules or the
request, **user** means a JUDGMENT_CALL put to the user, and **keep** means
no change, with the reason.

Callers checked by lenses 3 and 6: every new argument is trailing with a
default that keeps today's behaviour. The only callers outside the six
functions are `get_quantiles()` (`.mean_cell()`) and `get_ratios()`
(`.total_cell()`). `.build_cluster_matrices()` also has a caller in
`R/analysis-corr-latent.R:1385`, which the spec leaves alone. Every
condition class the spec names is in `plans/error-messages.md`.

### REQUIRED

| # | Issue | Lens | Section | Route |
|---|---|---|---|---|
| 1 | Per-call context (`mats`, `rep_mat`, `rep_finite`) is written in three places and would be coded six times. Add one internal helper that returns them by route. Step 2 calls it. §III.1 and §III.2 keep only their extra rules. | 1 | §II.5, §III.1, §III.2, §II.3 | fix (engineering-preferences #1) |
| 2 | The per-function Warnings and Errors blocks repeat shared conditions. Add a "Common conditions" table. Each function lists only its own. | 1 | §IV–§IX | fix |
| 3 | Exact-warning-count nesting is written in about 14 blocks. Add `expect_warning_count(expr, class, n)` to the test helper. | 1 | test-spec §2.6, §4, §5 | fix |
| 4 | Same-procedure blocks are not parameterised: the 5.1 self-consistency check, the 5.3 lonely-PSU loop, and the six calls of 5.6. Name shared helpers or loops. | 1 | test-spec §5.1, §5.3, §5.6 | fix |
| 5 | The spec states ordering rules for the PRs in pieces: fixture first, shared helpers next, `NEWS.md` and the speed table last. Collect them in one "PR constraints" paragraph. The plan still sets the split. | 5 | header, §II.1, §XI | fix (collect existing rules; no new split) |
| 6 | `NULL` defaults for `mats` / `rep_mat` on cell functions with one caller give dead branches that gate 6 cannot cover. Make the arguments required there. Keep `NULL` defaults only on `.mean_cell()`, `.total_cell()` and the cell functions under them. | 5 | §II.3, §XI gate 6 | fix |
| 7 | The speed HOLD rule trips on noise for scenarios near 0.02–0.1 s. Apply HOLD only to scenarios with a before time of at least 0.1 s. Re-run a flagged scenario once before HOLD. | 5 | §XI gate 9, §XII | fix (keep the scenarios and call counts: request acceptance criteria 1–3 and 7 require them) |
| 8 | `get_variance()` / `get_covariance()` now hold one `n x k` matrix of all live columns, where today they hold one column at a time. At `n = 10^6` and `k = 360` that is about 2.9 GB. | 5 | §III.3, §VII, §VIII | **user** |
| 9 | The influence-column field name is not given for `.taylor_variance_cell`, `.covariance_pair_taylor` and `.delta_ratio_cell`. The last needs the unscaled `z`. | 3 | §II.3, §VII–§IX | fix (name it `infl`) |
| 10 | How `vals` is built for freqs/means/totals is not stated. The invariant that every Taylor cell has a non-`NULL` joint is not stated. The case of `.joint_vcov()` returning `NULL` is not handled. | 3 | §III.3, §II.5 | fix |
| 11 | The order of the `na.rm = FALSE` override in variance/covariance is ambiguous ("after the SE step, or leave such cells out"). | 3 | §VII, §VIII, §XII.4 | fix: after the SE step, which is the base-commit path. Those columns are finite (methods pass 1, lens 2). |
| 12 | Inconsistent `rep_finite` / `rep_mat` / `rep_N_d` combinations have no stated behaviour. | 3 | §II.3 | fix |
| 13 | `mats` on `.attach_joint_vcov()` has no call site. | 3 | §II.3 | fix (remove) |
| 14 | The `NEWS.md` entry is not checkable: no issue number, unbound `[before]` / `[after]`, no named scenario. Gate 11 passes with placeholders left. | 3, 6 | §XIII, §XI | fix |
| 15 | The pass criteria of gates 1 and 9 are ambiguous. Gate 1 is `expect_equal(tolerance = 1e-12)`, with `identical()` recorded only. In gate 9, "and" means both conditions must hold. | 3 | §XI | fix |
| 16 | `NEWS.md` understates D9: a later cell's error can replace the abort, and the unknown-option abort moves too. | 6 | §XIII | fix |
| 17 | The `NEWS.md` "do not change" claim contradicts D3. Add "beyond floating-point rounding; an optimized BLAS can differ in the last bit". | 6 | §XIII | fix |
| 18 | `NEWS.md` says the Taylor variance step runs "once per call". D10, D8 and the replicate route contradict this. | 6 | §XIII | fix |
| 19 | The `NEWS.md` speed claim names four functions that were never profiled. Make its wording depend on the §XII table, and name only functions that measured a gain. | 6 | §XIII, §XI | fix |
| 20 | Fixture truncation passes silently. Add `expect_setequal` against `cell_golden_scenarios()`, a pinned count, a non-empty loop check, and a hard failure when the fixture is missing. | 2 | test-spec §2.4, 4.1 | fix |
| 21 | The generator does not check that it ran on the base commit. Pass the base sha, and stop on a mismatch or on a diff under `R/`. | 2 | test-spec §2.4 | fix |
| 22 | Categories 6–9 and 13 have no disposition. Add an N/A table with reasons. Add one labelled scenario with `name_style = "broom"` for `get_means()` and for `get_freqs()`. | 2 | test-spec §1, §4 | fix (more tests: engineering-preferences #2) |
| 23 | Error classes without a firing row: `ratio_zero_denominator`; `all_na` (freqs); `lonely_psu_unknown_option` outside means; `all_replicates_na` for totals, variance and covariance. Each needs the dual pattern. | 2 | test-spec §4, §5 | fix (or state why the row cannot be reached) |
| 24 | Warning classes without a scenario: `zero_df_after_calibration`, the variance and covariance `all_na` / `insufficient_n` warnings, `all_na_totals`, `domain_replicates_na` outside freqs and means, `small_cell` and `single_level` outside freqs and means. | 2, 4 | test-spec §3.3 | fix |
| 25 | Degenerate cells are covered for means and freqs only. Add all-NA, empty-cell, empty-domain and zero-live-cell scenarios for totals, variance, covariance and ratios. Put an early-return cell between live cells for variance and covariance. | 2, 4 | test-spec §3.2 | fix |
| 26 | No row sits on the block boundary (64 / 65 live cells). No `get_ratios()` scenario has more than 64 live cells. | 4, 2 | test-spec §3.2 | fix |

### SUGGESTION

| # | Issue | Lens | Route |
|---|---|---|---|
| 27 | "Finite check fails" edge rows are repeated in four functions. Point to §III.3 rule 4. | 1 | fix |
| 28 | §X.1 restates §III.4. Keep the D9 rule and the case table, and point to §III.4. | 1 | fix |
| 29 | The `rep_N_d` rule is written three times. §IV points to §III.5. | 1 | fix |
| 30 | Gates 5, 7 and 8 and the coverage figures restate `.claude/rules/`. Make them one-line pointers. Keep the 369 count and the branch-coverage claim. | 1 | fix |
| 31 | Coverage is listed three times in the test-spec. Keep §6 as the traceability table, and reduce §4's edge bullets to row ids. | 1 | fix |
| 32 | Trim the golden catalogue to about 70 core scenarios. | 5 | keep: engineering-preferences #2 (more tests is better), and lenses 2 and 4 ask for more scenarios, not fewer |
| 33 | The file-level `skip_on_cran()` reason contradicts D3, and the fixture's life after the PR series is not stated. | 5 | **user** |
| 34 | Per-PR `R CMD check`, coverage, `run_examples()`, pkgdown and the cookbook scan cost more than they prove. | 5 | keep: `r-package-conventions.md` requires `devtools::check()` before every PR, and the profile gates come from the project's pipeline. The spec may not lower them. |
| 35 | Say in the changelog that a failing call under `"fail"` now runs every cell first. | 6 | fix (changelog only) |
| 36 | Under `options(warn = 2)`, a later warning becomes an error and replaces the lonely-PSU abort. | 6 | fix (one sentence in §X.1 and the changelog) |
| 37 | Gate 1's exemption for "the stored call" is unclear. | 6 | fix |
| 38 | Ungrouped Taylor `get_variance()` / `get_covariance()` (one live cell) have no scenario. | 4 | fix |
| 39 | A partly `NA` group column with `na.rm = FALSE` has no scenario. | 4 | fix (one `means/tay_group_na` row) |
| 40 | §IX says `total_x` can be 0 for a live cell. Say that a finite `z` with `total_x == 0` cannot reach call 3, and why. | 4 | fix |
| 41 | Enumerate the call sites of each modified helper (13 sites). | 3 | fix |
| 42 | The §XII.4 `get_ratios()` count misses cells that stop after call 1, and the zero-live case. | 3 | fix |
| 43 | Justify placing `.taylor_cell_se()` in `R/analysis-helpers.R` (the analysis-family shared file, beside `.joint_vcov()`). | 3 | fix |
| 44 | Row 4.1 says "exactly one block". Change it to "at least one". | 2 | fix |
| 45 | Post-loop warning suppression under `"fail"` is never tested, because `<std>` sets `min_cell_n = 0`. Run one 5.3 row with a high `min_cell_n`. | 2 | fix |

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 26 |
| SUGGESTION | 19 |

**Total issues:** 45

**Verdict: NEEDS-DECISION** (issues 8 and 33 are JUDGMENT_CALLs; the
REQUIRED-UNAMBIGUOUS findings would also make it FAIL).

**Overall assessment:** the spec is implementable and every lens confirmed
the main design against the code. The test-spec needs more condition and
degenerate-cell rows. The internal contracts need named fields and fixed
argument rules. The `NEWS.md` entry claims more than the change does.

---

## Spec Review: analysis-cell-performance — Pass 2, delta (2026-11-10)

Two agents: one on the changed spec sections (v1.2), with a D12 mini-check
of the method, and one on the changed test-spec sections. Decisions made
before this pass: D12 (issue 8, user), D13 (issue 33, user) and the D13
correction (the skip reason is run time only).

### Prior issues (Pass 1)

All 45 resolved, except these three:

| # | Status |
|---|---|
| 5 | ⚠️ §II.6 step 3 leaves out `get_ratios()` |
| 8 | ⚠️ D12 is applied, but a stored `infl` field keeps `n x k` alive |
| 38 | ⚠️ No variance or covariance scenario has exactly one live cell |

The D12 mini-check found the method exact. A clean block's diagonal equals
each cell's own variance. A failing block falls back per cell inside that
block. A partial final block, including `k = 1`, is exact. The abort location
(first flush) is stated the same way everywhere and agrees with D6 and D9. The
scenario total of 259 matched the rows listed.

### New issues

| # | Issue | Severity | Route |
|---|---|---|---|
| 46 | `infl` stays on stored cell results, so `n x k` is held again; the buffer must carry the cell index | REQUIRED | fix |
| 47 | §II.1 "No other file changes" contradicts the fixture, generator and test files | REQUIRED | fix |
| 48 | §II.6 step 3 omits `get_ratios()` | REQUIRED | fix |
| 49 | No one-live-cell scenario for variance or covariance (issue 38 still open) | REQUIRED | fix |
| 50 | `{functions}` in `NEWS.md` has no text when no function qualifies | SUGGESTION | fix (drop the speed sentence) |
| 51 | Block-size equality is not checked at 16 and 32 | SUGGESTION | fix |
| 52 | §I.5 D7 row is stale after D10 and D12 | SUGGESTION | fix |
| 53 | `get_ratios()` holds unscaled and scaled `n x k` together | SUGGESTION | fix: derive the scaled columns from the unscaled ones only if bit-identical, else state the cost |
| 54 | The generator cannot prove the sha is the true base | SUGGESTION | D14 (orchestrator default) |
| 55 | `cell_golden_fixture()` and `cell_golden_strip()` lack signature lines | SUGGESTION | fix |

**Verdict: FAIL** (four REQUIRED-UNAMBIGUOUS). Route to 3r, then pass 3
(the last pass allowed) on the changed sections only.

---

## Spec Review: analysis-cell-performance — Pass 3, delta (2026-11-10)

One agent read the changed sections of spec v1.3 and the test-spec. It
checked two claims against the R source.

- Issues 46 to 55: all ✅ resolved.
- `get_ratios()`: deriving the scaled column later is bit-identical. It is
  the same division of the same projected column
  (`R/analysis-ratios-helpers.R:133`, `.joint_infl()`) by the same
  `total_x` double. A check per block gives the same SEs as a check per
  call. The lonely-PSU abort stays in call 1, as §III.4 says.
- Variance and covariance locators: they reach every stored result,
  including pairs that move from `pair_results_this` to
  `all_pair_results`.
- The count of 261 matches every place it appears. No "259" is left.

### New issues

| # | Issue | Severity | Route |
|---|---|---|---|
| 56 | `acc_infl[[j]] <- NULL` deletes the list element and moves every later position | REQUIRED | fix: `acc_infl[j] <- list(NULL)`, with the reason in the text |
| 57 | The §III.3 table says the `get_ratios()` `.vcov` runs "after every block"; §IX says after the last block | REQUIRED | fix: "after the last block, once" |

Both are one-line corrections with one correct answer, and neither changes a
method or a test row. The orchestrator applied them to spec §III.3 and
checked the edited lines against §IX. Under the review-loop budget, findings
left open after pass 3 go to the user as a HOLD. These were closed, not left
open, so no HOLD and no pass 4.

**Verdict: PASS.** Spec v1.3 is frozen.
