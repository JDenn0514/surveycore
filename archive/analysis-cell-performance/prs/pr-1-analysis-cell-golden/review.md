# Review — PR 1 (plan PRs 1 and 2): `test/analysis-cell-golden`

**Reviewer**: opus, 2026-11-12, single reviewer under D17 (no tester).
**Tree reviewed**: working tree on `test/analysis-cell-golden`, HEAD and
merge-base `0c0a98752351b1ce3991aa7fdbdc513d8654085d` (= `origin/develop`).

Verdict: PASS

The verdict holds on the condition that the two FIX-BEFORE-MERGE items
below are done before the commit. Neither changes a block that runs in this
PR, so the leader's gate results stay valid.

## Findings

### F-1 FIX-BEFORE-MERGE — `DESCRIPTION:72`, an unrelated roxygen version bump

- **What**: the working tree changes `Config/roxygen2/version: 8.1.0` to
  `8.1.1`. The local roxygen2 wrote it.
- **Why**: `DESCRIPTION` is not in the PR's Files touched. Gate G item 9
  fails if it ships.
- **Fix**: `git checkout -- DESCRIPTION` before the commit. Do not stage it.

### F-2 FIX-BEFORE-MERGE — `tests/testthat/helper-cell-golden.R:469-499`, `expect_groups_match_domain()` fails on the unchanged code for rows 5.1.8 and 5.1.9

- **What**: the helper compares `unname(grouped[[estimate]][rows])` with
  `unname(single[[estimate]])`. The `[rows]` subset drops the column's
  `label` attribute; the ungrouped side keeps it. On `get_variance()` and
  `get_covariance()` the estimate column carries `label` ("Variance",
  "Covariance"), and so does `se` ("SE"). I ran rows 5.1.1, 5.1.2, 5.1.4,
  5.1.5, 5.1.7, 5.1.8 and 5.1.9 on the unchanged code in a scratch session.
  5.1.8 and 5.1.9 fail with "`attr(expected, 'label')` is a character
  vector". The numbers agree exactly (max abs diff 0 for both groups). The
  other five pass.
- **Why**: no block in this PR calls the helper, so the gates are green.
  PR 3 (row 5.1.8) and PR 5 (row 5.1.9) must write their block on the
  unchanged code and see it pass. Neither PR lists the helper file in Files
  touched, so each builder would have to edit outside scope or raise a HOLD.
  The defect is in the plan's §H.5 text, which the builder transcribed.
- **Fix**: compare values without attributes on both sides, for both the
  estimate and the `se` comparison:
  `as.vector(grouped[[estimate]][rows])` and
  `as.vector(single[[estimate]])` (and the same for `se`). `as.vector()`
  drops names too, so `unname()` is no longer needed. Record it as a
  planner erratum against §H.5 (text below).

### F-3 NOTE — `tests/testthat/test-analysis-cell-equivalence.R:33,44`, a warning-count failure does not name its scenario

- **What**: `expect_matches_golden()` labels every failure with the id. The
  `expect_warning_count()` call before it does not: an extra warning fails
  `expect_no_warning(nest(1L))`, and a missing one fails
  `expect_warning(nest(i + 1L), ...)`. Neither message holds the id. The
  warning text usually tells the reader which call, but not always (a
  `cv_undefined` warning is the same text on 43 covariance ids).
- **Why**: this is the plan's §H.7 loop body, and the extraction into
  `expect_quiet_golden()` did not cause it. An inline loop has the same gap.
- **Fix (optional, any later PR that touches the file)**: give
  `expect_warning_count()` an `info` argument and pass it to each nested
  `expect_warning()`, so a missing warning names the id. An extra warning
  still fails in `expect_no_warning()`, which takes no `info`. Not required
  for this PR.

### F-4 NOTE — `data-raw/analysis-cell-golden.R:28`, `%||%` needs R 4.4

- **What**: the generator uses base `%||%` before `load_all()` runs. Base R
  has it from 4.4.0. `DESCRIPTION` says `R (>= 4.3.0)`.
- **Why**: a contributor on R 4.3 cannot regenerate the fixture. It does not
  ship (`^data-raw$` is in `.Rbuildignore`).
- **Fix (optional)**: `if (is.null(attr(out, "status"))) 0L else ...`.

### F-5 NOTE — `data-raw/analysis-cell-golden.R:31-69`, the guard checks `R/` only

- **What**: the three checks are the ones `test-spec.md` §2.4 names. They
  prove `<dir>/R` is the base commit. They do not check `<dir>/data`,
  `DESCRIPTION` or `NAMESPACE`, which `load_all()` also reads. `gss_2024`
  comes from `<dir>/data`.
- **Why**: a worktree made with `git worktree add` is clean everywhere, so
  the documented procedure is safe. The gap matters only if someone points
  the generator at a hand-edited tree. Low risk.
- **Fix (optional)**: run `git -C <dir> status --porcelain` with no path,
  so any change anywhere stops it.

### F-6 NOTE — test titles over 80 columns

`test-analysis-cell-equivalence.R` lines 100 to 211: 18 `test_that()`
titles run 82 to 112 columns. The plan fixes every title text, so the limit
in `code-style.md` cannot be met. `air format --check` passes; it does not
rewrap strings. This is the same case as `archive/replicate-oracle-tests/`
S4 and S5. No action.

## Check 1 — coverage of the PR 1 and PR 2 rows

All 24 rows are covered by a block that can fail.

| Rows | Block | Can it fail? |
|---|---|---|
| 4.0 | invariants block, four constructors | yes |
| 4.1 | integrity block (a) to (e) | yes: (d) also stops an id that warns but is missing from the literal noisy table from dropping out of both loops |
| 4.2 | formals block | yes |
| 4.3.1 to 4.8.1, 4.9.1 | the seven quiet blocks | yes, break-it below |
| 4.3.2 to 4.8.2 | the six noisy blocks | yes, break-it below |
| 5.2.1, 5.2.2, 5.2.3 | the loops, with membership pinned by the literal `cell_golden_noisy` table and row 4.1 (d) | yes: an id that changes sides fails 4.1 or its loop |
| 5.3.13 | lonely-fail block | yes, if a call warns before it aborts |
| 5.6.1 to 5.6.4 | four NA-marker blocks | yes; both sides run current code, so they catch only an NA/FALSE disagreement, as designed |

Weak spots, none a BLOCK:

- The quiet `get_covariance()` block holds 2 ids (`tay_pair`,
  `tay_empty_dom`). The other 43 covariance ids, the core set included, are
  compared in the noisy block. The comparison is the same; only the block
  name differs.
- Row 5.3.13 has no control that shows each call would warn
  `small_cell` without `"fail"`. The noisy `*/small_cell` ids show it on
  `tay` for five of the six functions, which is enough.
- I checked all 104 extra and 37 noisy scenario wrappers against §H.6 by
  hand. Each passes the arguments the catalogue gives.

## Check 2 — the errata

| Erratum | Reading right? | Handling right? |
|---|---|---|
| E-1 | Yes. `R/analysis-helpers.R:953-969` warns `surveycore_warning_cv_undefined` once per call when any cell estimate is 0 or negative, and `<std>` asks for `cv`. | Yes. The fixture records it; the literal table carries it. |
| E-2 | Yes. `covariance/rep_na` records one `cv_undefined`. | Yes. AC 3's wording holds. |
| E-3 | Yes, and it reaches further than the builder said (see erratum text). | — |
| E-4 | Yes; the fixture wins by §H.6. | Yes. |
| E-5 | Yes. | Yes; the counts are asserted on both sides. |
| E-6 | Yes; D17 postdates the plan. | Yes. |
| E-7 | Yes; tests never read it. | Yes. |

## Check 3 — the two departures

- **`.cg_std()` / `.cg_raw()`**: sound. Arguments pass through `...`, and
  rlang's `enquo()` sees the caller's expression through forwarded dots.
  The generator and the tests use the same wrappers, so any difference would
  be the same on both sides. The only stored trace, `.meta$call`, is
  stripped. My break-it runs moved results through these wrappers, so the
  wrappers do not hide a change.
- **Loop bodies in functions**: sound. Each block still asserts one
  behaviour (one function, quiet or noisy), as the plan's own titles define.
  Each still runs `expect_gt(length(ids), 0L)` first. Result failures name
  the id through `label`. The warning-count gap (F-3) exists with or
  without the extraction.

## Check 4 — the fixture generator

- `provenance$base_sha` is `0c0a98752351b1ce3991aa7fdbdc513d8654085d`. It
  equals `git rev-parse origin/develop`, `HEAD`, and
  `git merge-base HEAD origin/develop`. D14 holds.
- The guard runs all three §2.4 checks before `load_all()`. The builder's
  guard test produced the porcelain message, so AC 3 holds.
- Could the fixture encode the current tree? Not in a way that matters
  here: `git diff --quiet --ignore-cr-at-eol origin/develop -- R` exits 0,
  so the base tree and the current tree have the same `R/`. The fixture's
  values are the base commit's values whichever tree loaded them. The risk
  is for later regenerations, and F-5 covers the one gap.
- Fixture: 182,472 bytes, `xz`, 261 results, 76 noisy.

## Check 5 — rules

- Warnings: every warning a block raises goes through
  `expect_warning_count()` with a class. No `suppressWarnings()`,
  `tryCatch()` or `withCallingHandlers()` in the helper or the test file.
  The generator uses `tryCatch()` and `withCallingHandlers()`, which the
  plan allows.
- `test_invariants()`: once per constructor, in the first block only.
- Tolerance: every numeric comparison passes `tolerance = 1e-12`
  (`expect_matches_golden()`, `expect_groups_match_domain()`).
- `skip_if_not_installed()`: none needed. `withr` and `tidyselect` are used
  across the suite with no skip; no `survey` call.
- Code style: `|>`, `<-`, `::` for external calls, `air` clean. Titles: F-6.

## Check 6 — break-it (targets the builder did not touch)

Each edit was reverted with `git checkout -- R/<file>`. After each,
`git diff --quiet --ignore-cr-at-eol origin/develop -- R` exited 0. No
`_snaps/` file changed.

| Edit | Red | Green |
|---|---|---|
| `R/analysis-ratios.R:358`, `ratio_est * (1 + 1e-11)` (a point estimate) | 39 failures: `get_ratios()` quiet 32, noisy 7 | every other block; the ratio ids that stay green have an all-NA estimate |
| `R/analysis-helpers.R:1277`, `.vcov` set to `v * (1 + 1e-10)` (attribute only, no column) | 133 failures in 8 blocks: quiet and noisy `get_freqs()`, `get_means()`, `get_totals()`, `get_ratios()` | variance and covariance blocks (they attach no `.vcov`), NA-marker blocks (both sides move) |
| `R/analysis-helpers.R:967`, warning class `..._cv_undefined_x` | 94 failures: noisy `get_covariance()` 76, noisy `get_ratios()` 6, NA-marker Taylor, replicate, two-phase 4 each | quiet blocks (no `cv_undefined` there) |

Every break turned the expected blocks red. No BLOCK.

## Check 7 — scope

- `R/`: no change (exit 0 above).
- Existing test files: none changed (`git diff --ignore-cr-at-eol --stat --
  tests` is empty).
- `.surveycore-workspace/` is in `.Rbuildignore` and untracked; nothing
  under it is staged. The five `plans/` copies are byte-identical to the run
  directory (`cmp`).
- Do not stage `plans/proposal-slim-pipeline.md` or `DESCRIPTION` (F-1).
- The fixture and the helper ship in the tarball. The file-level
  `skip_on_cran()` keeps the run off CRAN; the 182 KB fixture is within
  budget.

## Erratum text for later PRs

Record as one erratum against `implementation-plan.md` and `test-spec.md`.

**E-x (PR 1 review, 2026-11-12). The `cv` option makes most covariance
scenarios noisy, and the self-consistency helper compared attributes.**

1. Quiet and noisy sets (builder E-1, E-2). `get_covariance()` and
   `get_ratios()` warn `surveycore_warning_cv_undefined` once per call when
   any cell estimate is 0 or negative. The fixture's noisy set is 76 ids,
   not 37: 43 covariance ids, 8 ratios ids. The `get_covariance()` quiet
   block holds only `covariance/tay_pair` and `covariance/tay_empty_dom`.
   Wherever the plan or test-spec says a covariance id is "in the quiet
   loop", read "in the loop block of its function". This changes PR 5
   criterion 6 in wording only: the `covariance/blk*`, `tay_many` and
   `tay_narm_false` ids pass in the noisy block. PR 8's `ratios/blk64`,
   `ratios/blk65` and `ratios/blk65_na` likewise pass in the noisy block.
2. PR 3, row 4.6.3 (builder E-3). Replace the body
   `expect_warning_count(cell_golden_scenarios()[[id]](), character(0), 0L)`
   with `expect_warning_count(cell_golden_scenarios()[[id]](),
   cell_golden_noisy[[id]] %||% character(0),
   length(cell_golden_noisy[[id]]))` or an explicit per-id list. Recorded
   warnings: `variance/tay_c_na` 1 × `variance_all_na`;
   `variance/blk65` none; `covariance/tay_c_na` 2 × `covariance_all_na`
   + 1 × `cv_undefined`; `covariance/blk65` 1 × `cv_undefined`.
3. `expect_groups_match_domain()` (plan §H.5, test-spec §2.6). Compare with
   `as.vector()` on both sides, not `unname()`, for the estimate and the
   `se` column. The `[rows]` subset drops the column's `label` attribute and
   the ungrouped side keeps it, so rows 5.1.8 and 5.1.9 fail on the
   unchanged code as written. Fixed in PR 1 (review F-2).
4. PR 5, row 5.1.9. `expect_groups_match_domain("covariance/tay_y1_inf",
   ...)` raises 2 × `surveycore_warning_cv_undefined` on the unchanged code
   (the grouped call 1, one of the two ungrouped calls 1). Wrap the call in
   `expect_warning_count(..., "surveycore_warning_cv_undefined", 2L)`.
   Rows 5.1.1, 5.1.2, 5.1.4, 5.1.5, 5.1.7 and 5.1.8 raise no warning;
   5.1.3 and 5.1.6 were not probed. Each PR that writes a 5.1 row runs it on
   the unchanged code and wraps it if it warns.
5. PR 5, rows 5.3.5, 5.3.11, 5.3.15, 5.3.17. These `get_covariance()`
   calls abort under `"fail"`. Row 5.3.13 shows the core call raises no
   warning before the abort today. If the moved abort (D6) lets
   `cv_undefined` fire first, `expect_error()` still passes and the warning
   leaks into the suite count. Check the warning count stays at the
   baseline (gate G item 2).
6. PR 6 may rely on `means/rep_y1_inf` and `means/np_rep_y1_inf` being
   quiet: both record no warning (test-spec row 5.2.7 holds).

## Would a tester have caught more?

- **What the old tester would likely have caught**: F-1 (`DESCRIPTION`), by
  gate 9's Files-touched check. It reads the same diff list I did. I see
  nothing else in this PR's own rows that a test-spec-only tester would
  have found and this review missed. The tester also re-ran gates; here the
  leader ran them once, which is enough for a test-only PR.
- **What this review caught that the tester would not have**: F-2. The
  helper is defined in this PR but first used in PRs 3 and 5. A tester
  scoped to this PR's rows never calls it. Finding it took a cross-PR read
  of the plan and a scratch run of later rows, which the tester's brief
  does not include. The same is true of erratum items 4 and 5, and of the
  E-3 reach into rows 5.1.9 and 5.3.x.
- **Break-it**: the old tester ran no break-it check. The three breaks here
  (a point estimate, an attribute-only change, a warning class) show the
  blocks can fail on paths the builder's two breaks did not reach.
- **What neither caught**: no evidence either way on optimized-BLAS drift
  at 1e-12; this machine's BLAS string is empty (E-7).
