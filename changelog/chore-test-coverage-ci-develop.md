# Changelog: chore/test-coverage-ci-develop

**Branch:** `JDenn0514/test-coverage-workflow-never-runs-on-develop-prs`
**Status:** Complete
**Date:** 2026-09-03

## Summary

Closes #159. `.github/workflows/test-coverage.yaml` ran on `main` only, and it
had no failure condition:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

Feature branches target `develop` (`.claude/rules/github-strategy.md`), so no
feature PR was ever coverage-checked. The job measured coverage, converted it
to Cobertura and uploaded it to Codecov. Nothing read the number back, so a
drop left CI green.

The 95% floor and 98% target in `.claude/rules/testing-standards.md` were
therefore enforced by the local pipeline gate alone — `run-gates.sh` gate 7
and the reviewer's Step 5. A contributor who skips the local pipeline could
merge a regression into `develop` with CI fully green.

Three changes: `develop` on both triggers, `NOT_CRAN=true` on the coverage
step, and a step that fails below the floor.

### The floor check reads covr, not Codecov

#159 left this open — a Codecov status check with a target, or a step that
reads `covr::percent_coverage()`. This PR uses the covr step:

- It reuses the same floor and the same instrument as `run-gates.sh` gate 7,
  so the local gate and CI cannot disagree about what 95% means.
- It needs no Codecov project settings and no `CODECOV_TOKEN`. The existing
  upload step already treats a missing token as tolerable on a PR, and a
  status check gated on that token would inherit the same hole.
- The threshold lives next to the tests it measures, in the repository, under
  review.

The check runs after the Codecov upload, so the report still lands when
coverage drops.

### `NOT_CRAN` is what makes the number honest

Eleven test files carry a file-level `skip_on_cran()`. `covr` does not set
`NOT_CRAN`, so without it those files skip, their source reads as untested,
and the package total lands several points low — a false failure against the
floor. Commit `7cf0704` fixed the same defect in `run-gates.sh` gate 7.
`.claude/rules/testing-surveycore.md` states the rule and cites this issue.

#159 says ten files. The repository has eleven, which matches the rule file:

```
tests/testthat/test-analysis-corr-latent-variance.R
tests/testthat/test-analysis-corr-latent.R
tests/testthat/test-analysis-diffs-marginaleffects.R
tests/testthat/test-analysis-diffs-numerical.R
tests/testthat/test-analysis-t-test-numerical.R
tests/testthat/test-analysis-variance-twophase-nonprob.R
tests/testthat/test-glm-anova-numerical.R
tests/testthat/test-glm-marginaleffects.R
tests/testthat/test-glm-numerical.R
tests/testthat/test-variance-twophase.R
tests/testthat/test-variance-vendored-saddlepoint.R
```

## Files Modified

- `.github/workflows/test-coverage.yaml` — `develop` added to the `push` and
  `pull_request` branch lists, matching `R-CMD-check.yaml`; `NOT_CRAN: true`
  on the coverage step, with a comment naming the eleven files and the issue;
  the step gains `id: coverage` and writes `percent` to `$GITHUB_OUTPUT`; a
  new "Check the coverage floor" step reads that output and exits 1 when the
  figure is below 95 or when coverage did not run
- `changelog/chore-test-coverage-ci-develop.md` — this entry

## Changes

- Run the coverage workflow on `develop` pushes and on PRs that target
  `develop`, so feature PRs are coverage-checked before they merge
- Set `NOT_CRAN=true` for `covr::package_coverage()`, so the eleven
  `skip_on_cran()` files run and the reported total is the true one
- Fail the job when coverage is below the 95% floor, and fail it when the
  coverage step produced no figure at all

## Verification

`.Rbuildignore` excludes both changed paths — `.github` (line 4) and
`changelog` (line 5) — so the built package is byte-identical and no package
gate figure can move. `devtools::check()` and `devtools::test()` were not run
for that reason.

What was checked locally:

| # | Assertion | Result |
|---|---|---|
| 1 | The file parses as YAML; `on:` lists both branches | pass |
| 2 | The eight steps read back in the intended order | pass |
| 3 | The floor comparison passes 96.0938 and 95 | pass |
| 4 | It fails 94.9 and an empty figure | pass |

Assertions 3 and 4 ran the step's `awk` expression and its empty-value guard
directly, not the workflow. The workflow runs on GitHub only, so the first CI
run on this PR is the real check — and it is also the first run of the job on
a `develop`-targeted PR.
