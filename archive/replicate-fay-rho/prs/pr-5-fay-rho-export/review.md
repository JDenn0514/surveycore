# Review — PR 5 — fay-rho-export

**Verdict**: PASS
**Date**: 2026-09-30

Branch `fix/fay-rho-export`, HEAD da79200, tree 8183fde. Base develop 0b7e623.

## Convergence checks

- Spec coverage: y. Spec §VI.1 items 1 to 4 and §VI.2 each map to a row in
  `audit.md`:
  - item 1 (delete the recovery): criterion 7 and the code diff;
  - item 2 (Fay, valid rho): rows 3.1, 3.1a and 3.2;
  - item 2 (Fay, invalid rho): rows 3.4 to 3.7 and 4.5 to 4.5b;
  - item 3 (other types pass `rho = NULL`): row 3.3;
  - item 4 (order unchanged): see the order check below.
- Test coverage of spec: y. Test-spec §3 rows 3.1 to 3.7 and §4 rows 4.5,
  4.5a, 4.5b and 4.7 cover §VI, including absent, `NULL`, `NA` and 1.5 values.
- Tolerance integrity: y. Each number in the audit table equals the value
  that `test-spec.md` §Tolerances sets: scale and SE 1e-8, mean 1e-10. The
  test-spec sets no tolerance for `rho`; the blocks use 1e-10, which is the
  tightest value in the table. No value is looser.
- Scope discipline: y. `git diff --stat 0b7e623..HEAD` lists four files:
  `R/methods-conversion.R`, `plans/error-messages.md`,
  `tests/testthat/test-conversion.R` and `tests/testthat/_snaps/conversion.md`.
  These four files are the plan's write surface and the four files in
  `implementation.md`.
- Regression safety: y. The full suite has 0 failures, and WARN stays at 256
  (Before 256). The number of passed expectations went from 12213 to 12242.

## Checks the orchestrator asked for

- **CB-4 template, word for word.** The four bullets in
  `.as_svydesign_replicate()` join to the §VI.3 text exactly. Row CB-4 in
  `plans/error-messages.md` carries the §VI.3 condition and template exactly.
  `{scale_txt}` occurs nowhere in `plans/` or `R/`. The #243 sentence is
  under the CB table and uses the §VI.3 text.
- **Order of checks (§VI.1 item 4).** In the function body:
  1. the `surveycore_error_repweights_empty` refusal (first);
  2. `scale_arg`, which is unchanged;
  3. the Fay `.is_valid_rho()` check and the CB-4 abort;
  4. the CB-3 FPC warning;
  5. `survey::svrepdesign(..., rho = rho_arg)`.
  `rho_arg` stays `NULL` for every type other than Fay.
- **Snapshots.** The diff of `_snaps/conversion.md` holds two entries only:
  one new entry and one rewritten entry. Both show the §VI.3 text. At
  0b7e623 the "scale yields no rho" block had no snapshot entry. That block
  was already gone from the test file, so no deletion was due. The builder
  used `snapshot_accept()` in place of `snapshot_review()`, because
  `snapshot_review()` needs an interactive session. The builder read both
  diffs, and the content I see matches the template, so the substitution
  changes no result.
- **All-types block, Fay pass.** "every accepted replicate type crosses both
  conversion routes" still builds the Fay pass with `rho = 0.3` and asserts
  `d2@variables$rho` equals 0.3 at 1e-10 (lines 2803 and 2818).

## CRAN cookbook and profile gates

- The audit lists no cookbook violations, and the audit verdict is PASS.
  The two agree.
- All seven gates have a result. None was skipped. R CMD check gives
  Status: 2 NOTEs (`gate-5-00check.log` line 98):
  - CRAN incoming feasibility: pre-approved;
  - the `.git` hidden-file note: present on develop before this PR, and
    caused by `.Rbuildignore`.

## Coverage

Package coverage is 96.16% Before and After. This is above the 95% floor
and did not drop. `R/methods-conversion.R` is at 99.76%. Its one uncovered
line, 621, comes from commit b1ef82dd (2026-04-01), so the PR adds no
uncovered line. The gate summary says "changed R/ files: 4". That number
counts against an older base. This PR changes one R/ file.

## Comprehension alignment

The gotcha "Designs with no stored `rho` (S3)" names two sources: a legacy
saved object and the untyped `survey_replicate()` constructor. Rows 3.4 and
3.7 cover both. The other gotchas in that file belong to other PRs.

## Cross-consistency notes

- One comment is stale and outside the plan's list. The X-13 comment above
  "the round trip reproduces a Fay source's mean, SE and CI"
  (`test-conversion.R` line 2683) still says the Fay leg "needs the
  recovered shrinkage factor twice". Plan task 7 lists the comments to
  rewrite, and this comment is not on that list. Criterion 7 applies to
  `R/methods-conversion.R` only, so no criterion fails. The comment is out
  of date: the export now carries the stored `rho` and no longer recovers
  it. Fix it in a later PR that already edits this file.
- The Fay fixtures by hand (`make_fay_by_hand()`) build on the FC frame:
  `make_survey_data(type = "brr", seed = 430)`, which is what
  `make_rep_type()` also uses. This matches "built by hand on FC" in rows
  3.4 to 3.7.

## Decision

The implementation, the tests and the audit agree on every §VI contract
item. The CB-4 text matches §VI.3 word for word, and the order of checks
matches item 4. No tolerance is looser than the test-spec, the write surface
matches the plan, and coverage held at 96.16% with no new uncovered line.
