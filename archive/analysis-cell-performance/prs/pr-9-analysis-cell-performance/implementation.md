# Implementation — PR 9: `refactor/analysis-cell-performance`

**Builder**: opus, 2026-11-17. Branch `refactor/analysis-cell-performance`,
start `1eb5bd6`. Two commits, not pushed:

- `32de4c5` perf(analysis): set the Taylor SE block size from the measured table
  (`R/analysis-helpers.R`, `changelog/refactor-analysis-cell-performance.md`)
- `ae73ecb` docs: add the analysis-cell-performance NEWS entry and speed table
  (`NEWS.md`, `changelog/refactor-analysis-cell-performance.md`)

Measurement files in this directory (none committed): `timing.R`,
`compare.R`, `table.R`, `run_speed.sh`, `run_test.sh`, `wait_clear.sh`;
logs `before_blk.log`, `block.log`, `speed.log`, `test3.log`; results in
`before_blk/`, `after_blk/`, `out_before/`, `out_after/`; the generated
table in `table.md`. Libraries `lib_before/`, `lib_after/`; sources
`src_before/`, `src_after/` (from `git archive`).

## Environment

- R: R version 4.6.1 (2026-06-24 ucrt), Windows 11
- `extSoftVersion()[["BLAS"]]`: `""` (reference BLAS)
- `La_library()`: `""` (reference LAPACK)
- `getOption("matprod")`: `"default"`
- Base sha: `0c0a98752351b1ce3991aa7fdbdc513d8654085d`. PR #364's
  description and the fixture's `provenance$base_sha` agree.
- Installed in `<lib_after>` for the §XII run:
  `32de4c530b569df7e0a42dbf24b8821a1aee269d` (the size commit; `ae73ecb`
  changes only `NEWS.md` and the changelog). Block-size run: `1eb5bd6`.
- Both libraries built with `R CMD INSTALL --no-test-load --library=<lib>`
  from a `git archive` of the commit. The default library was not touched.

## Block-size table (task 2)

Medians of 3 runs after one warm-up (every warm-up > 1 s), seconds.

| `B` | V3 | C2 | R4 | Sum | V3 vs base | C2 vs base | R4 vs base |
|---|---|---|---|---|---|---|---|
| 16 | 1.55 | 2.23 | 4.03 | 7.81 | identical | identical | identical |
| 32 | 1.55 | 2.21 | 3.37 | 7.13 | identical | identical | identical |
| 64 | 1.51 | 2.21 | 3.62 | 7.34 | identical | identical | identical |

Smallest sum 7.13 (B = 32); 5% bound 7.49. B = 16 (7.81) is out. **Selected
B = 32.** `TAYLOR_SE_BLOCK <- 32L` in `R/analysis-helpers.R:1315`, with a
two-line comment naming the rule and the changelog.

## §XII table (task 5)

| Scenario | Rows | Before (s) | After (s) | After/before | Counts before | Counts after | `identical()` |
|---|---|---|---|---|---|---|---|
| F1 | 8 | 0.23 | 0.03 | 0.13 | 9 / 9 | 1 / 1 | TRUE |
| F2 | 24 | 0.65 | 0.06 | 0.09 | 25 / 25 | 1 / 1 | TRUE |
| F3 | 22 | 0.58 | 0.03 | 0.05 | 23 / 23 | 1 / 1 | TRUE |
| F4 | 10 | 0.44 | 0.05 | 0.11 | 11 / 11 | 1 / 1 | TRUE |
| F5 | 40 | 1.61 | 0.20 | 0.12 | 41 / 41 | 1 / 1 | TRUE |
| F6 | 25 | 1.08 | 0.13 | 0.12 | 26 / 26 | 1 / 1 | TRUE |
| F7 | 10 | 0.38 | 0.11 | 0.29 | 0 / 0 | 0 / 0 | TRUE |
| F8 | 40 | 1.44 | 0.21 | 0.15 | 0 / 0 | 0 / 0 | TRUE |
| F9 | 25 | 0.89 | 0.29 | 0.33 | 0 / 0 | 0 / 0 | TRUE |
| M1 | 1 | 0.06 | 0.02 | 0.33 | 2 / 2 | 1 / 1 | TRUE |
| M2 | 5 | 0.16 | 0.03 | 0.19 | 6 / 6 | 1 / 1 | TRUE |
| M3 | 6 | 0.22 | 0.03 | 0.14 | 7 / 7 | 1 / 1 | TRUE |
| M4 | 5 | 0.17 | 0.04 | 0.24 | 6 / 6 | 1 / 1 | TRUE |
| M5 | 1 | 0.09 | 0.03 | 0.33 | 2 / 2 | 1 / 1 | TRUE |
| M6 | 20 | 1.03 | 0.13 | 0.13 | 21 / 21 | 1 / 1 | TRUE |
| M7 | 60 | 2.75 | 0.48 | 0.17 | 61 / 61 | 1 / 1 | TRUE |
| M8 | 1 | 0.05 | 0.03 | 0.60 | 0 / 0 | 0 / 0 | TRUE |
| M9 | 20 | 0.79 | 0.37 | 0.47 | 0 / 0 | 0 / 0 | TRUE |
| T1 | 5 | 0.16 | 0.03 | 0.19 | 6 / 6 | 1 / 1 | TRUE |
| T2 | 20 | 0.89 | 0.14 | 0.16 | 21 / 21 | 1 / 1 | TRUE |
| T3 | 20 | 0.56 | 0.28 | 0.50 | 0 / 0 | 0 / 0 | TRUE |
| V1 | 40 | 1.62 | 0.23 | 0.14 | 40 / 40 | 1 / 2 | TRUE |
| V2 | 20 | 0.52 | 0.23 | 0.44 | 0 / 0 | 0 / 0 | TRUE |
| V3 | 180 | 7.64 | 1.12 | 0.15 | 180 / 180 | 1 / 6 | TRUE |
| C1 | 20 | 0.85 | 0.14 | 0.16 | 20 / 20 | 1 / 1 | TRUE |
| C2 | 360 | 13.52 | 1.56 | 0.12 | 360 / 360 | 1 / 12 | TRUE |
| C3 | 20 | 0.68 | 0.37 | 0.54 | 0 / 0 | 0 / 0 | TRUE |
| R1 | 5 | 0.40 | 0.11 | 0.27 | 16 / 16 | 1 / 12 | TRUE |
| R2 | 20 | 2.36 | 0.83 | 0.35 | 61 / 61 | 1 / 42 | TRUE |
| R3 | 20 | 1.84 | 0.96 | 0.52 | 0 / 0 | 0 / 0 | TRUE |
| R4 | 60 | 7.23 | 2.44 | 0.34 | 181 / 181 | 1 / 123 | TRUE |

Counts are `.build_cluster_matrices()` / `.svy_recvar()`. The R-process
count inside `timing.R` read 2 (the run itself) at the start and end of
every scenario of both timing passes.

## Criterion 4 (call counts, B = 32)

- `.build_cluster_matrices()` = 1 on every Taylor scenario: yes.
- `.svy_recvar()` = 1 on F1 to F6, M1 to M7, T1, T2: yes.
- `ceiling(k / 32)`: V1 k = 40 → 2; V3 180 → 6; C1 20 → 1; C2 360 → 12.
  All match.
- `get_ratios()`: R1 (k = 5, the five `degree` cells) 5 + 5 + 1 + 1 = 12;
  R2 20 + 20 + 1 + 1 = 42; R4 60 + 60 + 2 + 1 = 123. All match.
- Both 0 on F7 to F9, M8, M9, T3, V2, C3, R3: yes.

## Gate 9

No scenario is flagged: every after time is below its before time. No
re-run was needed.

## NEWS fields (task 7)

- No development section existed (`DESCRIPTION` is `1.2.0.9000`; `NEWS.md`
  started at `# surveycore 1.2.0`), so `# surveycore (development
  version)` and `## Performance` were added above it.
- `{functions}`: all six qualify (each has a scenario with before ≥ 0.1 s
  and after/before ≤ 0.9; the largest such ratio is C3 0.54). Listed in
  §I.2 order.
- `{M7 before}` = 2.75, `{M7 after}` = 0.48.
- No fallback applied.
- `{ref}`: left literal, 2 occurrences in `NEWS.md`. The leader fills it
  with the PR number in a follow-up commit.

## `devtools::test()` (task 4)

At `TAYLOR_SE_BLOCK = 32` (`32de4c5` tree):
`[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16750 ]` — warnings equal the D21
baseline. The golden file `test-analysis-cell-equivalence.R` ran (no
`NOT_CRAN` skip under `devtools::test()`), `blk16` to `blk65_*` and
`variance/blk65_gap` included. Log: `test3.log`. Run without
`LANG=C.UTF-8` (E-1).

## Criterion 2

`git merge-base --is-ancestor 32de4c5 32de4c5` exits 0. The size commit is
the installed commit itself.

## Errata and decisions

- **E-1 (environment, affects the gate command).** `LANG=C.UTF-8
  LC_ALL=C.UTF-8` does not work on this Windows R: R warns "Setting
  LC_CTYPE=C.UTF-8 failed" and runs in the C locale, with
  `l10n_info()$"UTF-8"` FALSE. The suite then fails 10 expectations, all
  UTF-8 output (`×` in print headers): `test-analysis-diffs-helpers.R:187`,
  `test-analysis-diffs.R:438`, `test-analysis-helpers.R:1546`,
  `test-analysis-t-test.R:287, :756`, `test-effective-n.R:460, :468, :476,
  :484`, `test-glm-methods.R:623` (then "Maximum number of failures
  exceeded"). Confirmed on `test-glm-methods.R` alone: 1 failure with the
  variables, 0 without. The counted run used plain `Rscript -e
  'devtools::test()'` in the default `English_United States.utf8` locale.
  The `.new.md` [no such file] snapshot files from the two failed runs were deleted.
- **E-2 (another session's R).** An R process from another session
  (`capture.R` in a different scratchpad) was alive during the first base
  run of V3, C2 and R4 (`before_blk.log`). Those times are discarded; the
  saved results are used only for the equality check, which does not
  depend on timing. Every later R run waited until no other R process was
  alive (`wait_clear.sh`), and the §XII timing passes also count R
  processes per scenario (always 2, the run itself). The block-size run was
  checked clear before and after, with no per-scenario check.
- **E-3 (selection margin).** The selection rests on R4 alone: V3 and C2
  differ by 0.04 s or less across sizes, and R4 at B = 64 (one SE block)
  read 0.25 s slower than at B = 32 (two blocks), which more blocks should
  not cause. That is likely run-to-run noise, but the rule was applied once
  as written and not re-run (no tuning). Memory per stacked call is lower
  at 32 than at 64 (D12), so the selection costs nothing in memory.
- **E-4.** §XII.1 says `git worktree add`; the libraries were built from
  `git archive` extracts, as the leader's brief allowed.
- **E-5.** The block-size table was measured on `1eb5bd6`, before the size
  commit; the constant was set per size with `assignInNamespace()`, so the
  installed value (64) did not matter.
- **E-6.** The §XII run uses the warm-up rule per library, so M7, F5, F6
  and others take 3 runs before and 5 after. The spec allows this.
- **E-7.** R1's live cell count is not in the spec's table; it is 5 (the
  `degree` levels, all non-empty), which gives the expected 12.
- **E-8.** The three §XIII changelog sentences are placed under Summary,
  word for word. "Files Modified" lists this PR's files only, as the house
  shape does per PR.
- **E-9.** Task 8 "Put the §XII table in the PR description too" is the
  leader's step; the table is in `table.md` and the changelog.
- **E-10.** Gates G were not run by this builder (leader runs them).
  `air format --check R/analysis-helpers.R` passes.

## Hand-written additions

- Two comment lines above `TAYLOR_SE_BLOCK` naming the selection rule and
  the changelog file.

## HOLD

None. Every result is `identical()` to the base commit at every block size
and in all 31 scenarios, and gate 9 flags no scenario.

`git status --short` at the end: only the three files of the other session
(`.claude/skills/pipeline-ship/SKILL.md`,
`.claude/skills/pipeline-simplified/SKILL.md`,
`plans/proposal-slim-pipeline.md`).
