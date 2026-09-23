# Request — replicate-oracle-tests

## Intent
Rewrite the replicate oracle tests in `tests/testthat/test-variance-replicate.R` so
that a wrong surveycore scale default makes a test fail. Today several blocks pass
surveycore's own `scale` into `survey::svrepdesign()`, which makes the comparison a
round trip that cannot disagree. Add the oracle rule that forbids this to
`.claude/rules/testing-surveycore.md`.

## Acceptance criteria
- One oracle block per replicate type in `tests/testthat/test-variance-replicate.R`,
  each building a surveycore design and a `survey::svrepdesign()` from the same
  columns with the same `mse`.
- No block passes a scale to either side. `rscales` is supplied to JKn only, as a
  literal, never read off the surveycore design.
- Each block asserts the point estimate, the SE and both CI bounds at the
  tolerances in `.claude/rules/testing-surveycore.md`.
- Each block asserts the warning `survey` raises, by class, rather than silencing it.
- The JK1 block at the current line 84 is rewritten, not added to.
- The JKn and bootstrap blocks wrap the SE assertion in `testthat::expect_failure()`
  with a comment naming issue #253, so the suite stays green while the wrong number
  stays pinned. PR 3 of the arc deletes the wrapper.
- The Fay block is out of scope — `survey` refuses `type = "Fay"` without `rho`,
  which issue #243 adds as PR 4 of the arc.
- `.claude/rules/testing-surveycore.md` carries the oracle rule.
- `grep` for `scale =` inside any `test_that()` block that calls `svrepdesign()`
  returns only blocks that pass the same literal to both sides.
- The full suite passes.

## Attachments
- GitHub issue #256 (JDenn0514/surveycore)
- `plans/issue-cleanup.md` — decisions D2, D4, D5, D7, D8, D9 are locked inputs
- Arc tracker: issue #257
