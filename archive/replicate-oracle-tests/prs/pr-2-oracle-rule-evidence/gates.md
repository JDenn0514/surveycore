# Gate record — PR 2 `docs/oracle-rule-evidence`

**Branch**: `docs/oracle-rule-evidence` at `c4c23f20c3c056add324eaa8fecdf6611b5aba42`
**Base**: `70bfe5495c1362284d13d3a56ec07c12e6ea1eff` (`develop` with PR 1 merged)
**Tree**: `51b1aee208097c6452bc58d86f750c0a0c7011bb`
**Run by**: the leader, not the tester.

## The R gates carry forward — decision S1, re-measured on this branch

`git diff --name-status 70bfe54 HEAD` lists exactly one path:

```
M	.claude/rules/testing-surveycore.md
```

Every subtree that the R gates read is byte-identical from base to head,
measured with `git rev-parse <rev>:<path>`:

| Path | Base → head |
|---|---|
| `R` | IDENTICAL |
| `tests` | IDENTICAL |
| `man` | IDENTICAL |
| `NAMESPACE` | IDENTICAL |
| `DESCRIPTION` | IDENTICAL |

`.Rbuildignore` carries `^\.claude$`, so `R CMD build` excludes the changed
file from the tarball, and no test opens it at run time. So gates 1 to 7 would
run identical code over identical inputs. `decisions.md` §S1 records the policy
and its reasoning.

## Gate results

Carried from `baseline.md`, tree `e9a6c808f228388175b1b6892e7372d39e3e2fb8`.

| Gate | Result |
|---|---|
| `devtools::document()` | PASS — wrote nothing |
| `devtools::test()` | PASS — `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11941 ]` |
| `run_examples()` | PASS — all examples ran |
| `R CMD build` | PASS |
| `R CMD check --as-cran --no-manual` | PASS — 2 NOTEs, both pre-existing |
| pkgdown | SKIPPED — scope; `NAMESPACE` diff empty, so the hard rule does not bite |
| `covr` | PASS — 96.15% |

Baseline logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/baseline/`

## The probe is this PR's real measurement, and it is not a gate

PR 2's task 1 probed the installed `survey` for all nine replicate types at
`R = 20`, three ways each. `survey` is 4.5 under R 4.6.1 — the versions
`spec.md` §III.3 records as measured. The builder reports all nine rows
agreeing with the spec's table and the delivered table byte-identical to it.

Two rows could not be probed the way the other seven were, and the builder
recorded both:

- **Fay** refuses to build without a `rho`, so its row was measured at
  `rho = 0.3`.
- **JKn** aborts with `Must provide rscales for combined JKn weights`, so its
  default scale needed `rscales` supplied, and showing that it honours `scale`
  needed `scale` and `rscales` together.

The reviewer checks the probe against the delivered table. `implementation.md`
carries both tables side by side so that check needs no re-run.

## Standing gates the tester measures on the branch

1. `git diff --name-only` lists one file and no third file.
2. `air format --check .claude/rules/testing-surveycore.md` passes.
3. `tests/testthat/test-conversion.R` is unchanged — row 6.17.
4. Nothing under `R/` changed; no roxygen changed.
