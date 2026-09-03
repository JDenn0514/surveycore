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

Two fixes: `develop` on both triggers, and a step that fails below the floor.
A third change, `NOT_CRAN=true` on the coverage step, pins a value the job
already had — see below.

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

### `NOT_CRAN` was already set — this pins it

#159 says the CI workflow does not set `NOT_CRAN`, and infers that CI coverage
read several points low. The first half is true of the workflow file. The
inference is wrong: `r-lib/actions/setup-r` exports `NOT_CRAN=true` job-wide,
so the value was already in place for `covr::package_coverage()`.

Measured against the run before this change — `main`, 2026-06-28, run
28338451338:

| Observation | Value |
|---|---|
| Coverage the job printed | 95.90% |
| `NOT_CRAN` occurrences in its log | 22 |

95.90% is the honest figure, not the ~93.7% a skipped run gives. So the
explicit `NOT_CRAN: true` in this PR fixes no live defect. It is kept for one
reason: the floor check now reads that number and fails on it, so the job
should state the variable it depends on rather than inherit it from a third
party's default.

Eleven test files carry a file-level `skip_on_cran()`. `covr` does not set
`NOT_CRAN` itself — that part of #159 holds, and it is why
`run-gates.sh` gate 7 sets it explicitly (commit `7cf0704`) and why
`.claude/rules/testing-surveycore.md` states the rule for local runs:

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

#159 says ten files. The repository has eleven, which matches the rule file.

## Files Modified

- `.github/workflows/test-coverage.yaml` — `develop` added to the `push` and
  `pull_request` branch lists, matching `R-CMD-check.yaml`; `NOT_CRAN: true`
  pinned on the coverage step, with a comment saying it restates a value
  `setup-r` already exports;
  the step gains `id: coverage` and writes `percent` to `$GITHUB_OUTPUT`; a
  new "Check the coverage floor" step reads that output and exits 1 when the
  figure is below 95 or when coverage did not run
- `changelog/chore-test-coverage-ci-develop.md` — this entry

## Changes

- Run the coverage workflow on `develop` pushes and on PRs that target
  `develop`, so feature PRs are coverage-checked before they merge
- Pin `NOT_CRAN=true` for `covr::package_coverage()`. `setup-r` already
  exported it, so no reported total moves; the job now states the variable its
  floor check depends on
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
directly, not the workflow.

The workflow itself runs on GitHub only, so this PR's own CI run is the real
check. Run 33792891286 confirmed all three parts:

| Assertion | Result |
|---|---|
| The job triggers on a `develop`-targeted PR | pass — first such run in the repository |
| The coverage step hands the floor step a figure | pass — `COVERAGE_PERCENT: 96.1878` |
| The floor step reads it and does not pass vacuously | pass — "coverage 96.1878% meets the 95% floor" |

96.1878% against 95.90% on the June `main` run is drift from tests added
since, not an effect of this change.
