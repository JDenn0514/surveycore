# Implementation — PR 2 — replicate-jkn-rscales-required

Worktree: `C:/Users/jdennen/surveycore/.claude/worktrees/agent-a22a01f5dd0c99e74`
Branch: `worktree-agent-a22a01f5dd0c99e74`
Base: `f2aba103a65edd437eb93b65e7b3a32814301304` (tree `468af501113e796ba06d4a27f1b6606fa1e0ba97`), verified before work.
Head: `c5d762137b84f3574c6094af13228185cdc8b98d` (one commit).

## Write surface
- `R/core-constructors.R` — modified (one hunk inside `as_survey_replicate()`, after `.validate_rscales()` and before the Fay/`rho` step)
- `tests/testthat/test-constructors.R` — modified
- `tests/testthat/_snaps/constructors.md` — modified (one new entry, no existing entry changed)

## Summary
- `as_survey_replicate()` now aborts with `surveycore_error_stratified_jk_rscales_unset` when `identical(type, "JKn")` and `rscales` is `NULL`. The message is the three-bullet template of spec §III "Errors", word for word.
- The check is step 7 of spec §III: it runs after `.validate_rscales()` and before the `rho` step, so a JKn call that also passes `rho` raises the error and no `rho` warning.
- Two new blocks replace the deleted block "as_survey_replicate() JKn with rscales = NULL stores scale = 1": the refusal (dual pattern, on F1), and the refusal before the `rho` warning (`expect_no_warning(expect_error(...))`, on F1 with `rho = 0.3`). They sit where the deleted block was.
- Nine existing blocks that built JKn with no `rscales` now pass `rep(1, R)` (or `rscales = 1` on the one-column call). The loops pass `rscales = if (identical(ty, "JKn")) rep(1, 20) else NULL`; the two-phase loop uses `rep(1, 5)`. The nine-type helper gained the formal `rscales = NULL`. No assertion changed.
- `as_survey_nonprob()` and `.is_stratified_jk()` are untouched. The only `R/` hunk against `origin/develop` is at `@@ -873,0 +874,25 @@ as_survey_replicate`.

## Task checklist
- [x] 1. Failing test "as_survey_replicate() refuses JKn with no rscales" (expect_error class + expect_snapshot error = TRUE).
- [x] 2. Failing test "as_survey_replicate() refuses JKn with no rscales before the rho warning".
- [x] 3. Step 7 implemented in `as_survey_replicate()`.
- [x] 4. Ten blocks retargeted: X4 deleted, the other nine given `rscales`.
- [x] 5. New snapshot entry read: it shows the three bullets beginning "`type = \"JKn\"` requires `rscales`.", "JKn replicate weights are combined weights" and "Pass `rscales` with one entry per replicate column". Existing `as_survey_nonprob()` snapshots for the same class are unchanged.

## Signals raised
- None.

## Notes for tester
- `air format --check tests/testthat/test-constructors.R` reports "Would reformat", and so does the same file on `origin/develop`. The set of changes air proposes is identical before and after this PR (all in pre-existing `data.frame(x = 1:5, wt = ..., r1 = ...)` literals near line 3515). The file was not reformatted, so that criterion 6's changed-line list holds. `R/core-constructors.R` passes `air format --check`.
- `git diff -U0 origin/develop...HEAD -- tests/testthat/test-constructors.R | grep '^-[^-]' | grep -c 'expect_'` returns 4.
- The banned-call count over added non-comment test lines (`suppressWarnings(` / `expect_failure(`) is 0.
- No roxygen changed, so `devtools::document()` was not run.
- A full test run rewrote line endings in 30 other `_snaps/` files; they were restored with `git checkout --` before the commit.
