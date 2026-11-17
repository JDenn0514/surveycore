# Plan review — analysis-cell-performance

## Pass 1 (full panel, 5 lenses, 2026-11-10)

**Verdict: NEEDS-DECISION.** 2 required findings, 1 user decision (HOLD-1),
1 user decision on test additions (Q-2), 16 suggestions.

| Lens | Result |
|---|---|
| PR Budget | PASS. 63 rows, each to one PR. Figures 12/8, 12/8, 7/8, 5/7, 6/7, 10/7, 6/7, 5/7, 0/8 recount exactly. |
| Dependency Ordering | PASS with 2 suggestions. |
| Acceptance Criteria | 1 required, 7 suggestions. Transcription of H.1–H.7 (261 scenarios, 37 noisy ids and their classes, helper signatures, 1e-12) matches `test-spec.md`. |
| Spec Coverage | 1 required (HOLD-1), 3 suggestions. |
| File Completeness | PASS with 2 suggestions. |

### Required

- **R-1 (AC lens).** PR 8 task 2 says "five new snapshot entries". The Row
  assignment footer and the four blocks (5.2.6, 5.3.6, 5.3.12, 5.7.1) give
  four. Fix: "four".
- **R-2 (Spec Coverage lens) = HOLD-1.** Gate 6 asks for "rule 3 with more
  than one block". Every caller passes at most `TAYLOR_SE_BLOCK` columns, so
  `.taylor_cell_se()`'s own split never runs a second block through the
  public API. The planner's description is accurate. User decision.

### User decision Q-2

Spec Coverage suggestions S-2 and S-3 name spec behaviour that no
`test-spec.md` row checks. Adding blocks means a test-spec erratum, because
the tester reads only the test-spec.

- S-2: §VII / §III.4. A cell under the `na.rm = FALSE` override must still
  join the flush buffer, because under `survey.lonely.psu = "fail"` its
  variance call is the one that aborts. No row fails if a builder skips
  override cells.
- S-3: kept errors with no block. Grouped `get_totals()` and grouped
  `get_ratios()` with an `Inf` base weight (§X.3 row 3); calibrated
  `get_means()` with `Inf` in `x` (§V); calibrated `get_ratios()` with `NA`
  in either variable (§IX).

### Suggestions

Dependency Ordering:
- D-1. After PR 8, the `mats = NULL` build branch of `.joint_vcov()` has no
  Taylor caller left. Fix: PR 8 lists unreached lines of
  `R/analysis-helpers.R` from the G.6 `zero_coverage` run in its description.
- D-2. After PR 8, the `mats = NULL` and `rep_mat = NULL` branches of
  `.taylor_total_cell()` and `.replicate_total_cell()` have no caller. Spec
  §II.3 (settled) sets these defaults. Fix: as D-1, for
  `R/analysis-totals-helpers.R`; no signature change.

Acceptance Criteria:
- A-2. Define "dual" (`expect_error(class = )` plus
  `expect_snapshot(error = TRUE)`) once in "How to read this plan".
- A-3. PR 1: add an observable criterion for the generator's guard (an edit
  under `<dir>/R` stops the run and names the check).
- A-4. PR 3 and PR 5: name the full in-loop flush (`blk64`) and the partial
  final flush (`blk65`) in the coverage criterion (gate 6).
- A-5. PR 3 criterion 7: state the observable NAMESPACE check and cite
  §II.2. PR 4 criterion 6: cite gate 12.
- A-6. G item 2: state the warning count in the PR description
  (test-spec §8).
- A-7. PR 9: a criterion that the suite passes at the committed
  `TAYLOR_SE_BLOCK`, naming the `variance/blk*`, `covariance/blk*` and
  `ratios/blk*` ids.
- A-8. `simpleError` rows: the PR description quotes the class observed on
  the base commit.

Spec Coverage:
- S-4. PR 9 task 7: name the two §XIII fallback branches; "add or extend"
  the development heading; fill `{ref}` after the PR opens.

File Completeness:
- F-1. The `plans/` copies PR 1 commits must be the PLAN_READY versions.
- F-2. `data-raw/README.md`: no change.

Planner notes carried: test-spec §2.4 versus the fixed 261 (plan forbids
fixture changes after PR 1); row 5.2.7 versus §3.3 (PR 1 task 5 reports it);
spec header reads DRAFT and lists D1–D13 (cosmetic); the §XII timing script
stays in the run directory.

## Resolution of pass 1 (planner, revision 2)

All required findings, HOLD-1 (D15) and Q-2 (D16, erratum E-1: rows 5.3.16,
5.3.17, 5.5.6 to 5.5.9) resolved. All suggestions applied except F-2 (no
change, as worded). Total rows 63 → 69.

## Pass 2 (delta, 2 agents, 2026-11-10)

**Verdict: PASS.** No required findings.

- Plan sections: every pass-1 item resolved; budgets recount exactly
  (12/8, 12/8, 8/8, 5/7, 7/7, 11/7, 7/7, 7/7, 0/8); 69 rows, each to one
  PR; the six new rows are fully transcribed into builder tasks.
- Erratum rows: probed on base `develop` at `0c0a987`. 5.3.16 and 5.3.17
  raise `surveycore_error_lonely_psu` from the override cell's own variance
  call. 5.5.6 to 5.5.9 raise `simpleError`. No existing row changed.
- Four wording suggestions, applied by the orchestrator with no structural
  change: P-8's budget sentence; the lonely-PSU snapshot names the stratum
  by index (test-spec §5.3, plan PR 3); the §5.5 note and P-8 rationale for
  5.5.6, 5.5.7 and 5.5.9 (see D16 correction). PR 4 criterion 2 re-wrap is
  cosmetic and left as is. No pass 3 is needed.
