# R Package Profile

R-specific commands, gates, and CRAN-compliance rules. The tester agent runs these in order; builder respects them during implementation.

## Validation commands (tester runs in order)

| # | Command | Gate | On fail |
|---|---|---|---|
| 1 | `Rscript -e "devtools::document()"` | NAMESPACE and `man/` are byte-identical before and after the run — not compared against `HEAD`, because the gate runs before the shipper commits | BLOCK (builder forgot `document()`) |
| 2 | `Rscript -e "devtools::test()"` | all tests pass | BLOCK (numerical-miss or contract-miss) |
| 3 | removed | R CMD check (gate 5) runs every `@examples` block | — |
| 4 | `R CMD build . 2>&1` | tarball produced | BLOCK (build failure) |
| 5 | `R CMD check --as-cran --no-manual --no-tests <tarball> 2>&1` | 0 ERRORs, 0 WARNINGs; NOTEs reviewed; examples run clean | BLOCK on ERROR/WARNING |
| 6 | `Rscript -e "pkgdown::check_pkgdown()"` | every export is in the `_pkgdown.yml` reference index | BLOCK |
| 7 | `.claude/scripts/covr-report.R` | covr ran and no test failed; per-file % and uncovered lines for the changed `R/` files | BLOCK if covr did not run or a test failed; HOLD if a line the PR added is uncovered |

Gate 3 is gone. The other gate numbers and log names did not change, so
`gate-5-check.log` and the rest still match older audits.

Gate 5 does not run the tests. Gate 2 already ran them, and CI runs
`R CMD check` with tests on four operating systems.

Gate 7 has three cases:
- **No `R/` file changed** against `develop` (committed, uncommitted or
  untracked): covr does not run, and the row reads `SKIPPED`.
- **Each changed `R/` file has a test file:** covr runs only the mapped
  test files. A family is the first hyphen segment of a file name. A
  change to `R/analysis-means.R` runs every `test-analysis-*.R` file, plus
  the exact test files of every `R/analysis-*.R` file. A file with no
  family siblings in `R/` keeps the exact mapping: `R/foo.R` maps to
  `test-foo.R` and any `test-foo-*.R`, with the exceptions in
  `rules/testing-surveycore.md` §File mapping. `R/foo-helpers.R` with no
  test file of its own maps to the tests of `R/foo.R`.
- **A changed `R/` file has no test file:** covr runs the full suite, and
  the log says why.

A scoped run can over-report uncovered lines. A line that only a test file
outside the mapped set reaches reads as uncovered. Check such a line
against the full suite before you HOLD on it.

The 95% package coverage floor is enforced only by the CI test-coverage
job (`.github/workflows/test-coverage.yaml`). The local gate answers one
question: are this PR's changed lines tested.

### Canonical runner

Run the whole table with ONE background command:
`bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown]`. It logs
each gate to `<log-dir>`, prints one summary table plus a `Tree:` hash,
and exits 0 only when every gate passes. `--baseline` mode runs gate 2
and a full covr run with the package total and the 95% floor. Use it to
capture Before-column numbers on a clean tree. Never run the gates one
command at a time.

## Output discipline (all gates)

Redirect every gate's full output to `{workspace-run-dir}/logs/gate-{N}.log`.
Bring into context ONLY:
- `tail -25` of the log, and
- `grep -E "FAIL|ERROR|WARNING|NOTE"` of the log.

Record each log path in `audit.md` §Profile gates. Read a full log only when
diagnosing that gate's failure.

### pkgdown skip condition

Gate 6 runs `pkgdown::check_pkgdown()`. It reads `_pkgdown.yml` and does
not build the site, so it takes seconds. Run it on every PR. The CI
pkgdown job still builds the full site.

The tester MAY skip gate 6 with `--skip-pkgdown` only when the PR touches
none of these:
- `R/` (any source file)
- `NAMESPACE` or `man/`
- `_pkgdown.yml`
- `vignettes/`

Log a skip in the `audit.md` Profile gates table as `SKIPPED — scope`.

**Hard rule — no skip when exports change.** When the `NAMESPACE` diff
is not empty, gate 6 must run. `R CMD check --as-cran` does not find an
export that is missing from the `_pkgdown.yml` reference index.
`check_pkgdown()` does. A skipped pkgdown gate on an export-changing PR
once broke the pkgdown CI job (see
`prs/pr-1-collection-id-if-missing-var-class/shipper.md` for the
post-mortem).

## Pre-approved NOTEs

These NOTEs do NOT block:

| NOTE | Reason |
|---|---|
| `no visible binding for global variable 'X'` | Tidy-select bare names; pre-approved in rules/r-package-conventions.md |
| `checking CRAN incoming feasibility` | Package is not on CRAN yet |

Any other NOTE is reviewed by tester. Tester reports all NOTEs in `audit.md` Profile gates table. Reviewer escalates to STOP if a new NOTE pattern appears that isn't in the pre-approved list.

## CRAN cookbook scan

Tester greps for these in all changed `.R` files (implementation.md write surface):

| Violation | Pattern | BLOCK class |
|---|---|---|
| `T`/`F` as logicals | `(?<![a-zA-Z0-9._])[TF](?![a-zA-Z0-9._])` in code (not strings, not comments) | `surveycore_error_tf_abbrev` |
| Hardcoded `set.seed()` in non-test code | `set\.seed\(` in `R/` but not behind a `seed` arg | `surveycore_error_hardcoded_seed` |
| Bare `print()` or `cat()` | `^\s*(print\|cat)\(` in `R/` outside print/summary methods | `surveycore_error_bare_print` |
| `options(warn = -1)` | `options\(warn\s*=\s*-1` | `surveycore_error_suppress_warn_global` |
| `installed.packages()` | `installed\.packages\(` | `surveycore_error_installed_packages` |
| `<<-` outside Shiny | `<<-` | `surveycore_error_global_assign` |
| Unrestored `par()` / `options()` / `setwd()` | `par\(|options\(|setwd\(` without `on.exit()` in same fn | `surveycore_error_unrestored_state` |
| Writing to `getwd()` / home | `file.*(getwd\|path.expand\|~)` in write calls | `surveycore_error_home_write` |
| More than 2 cores | `mc.cores\s*=\s*[3-9]` or `makeCluster\([3-9]` | `surveycore_error_cores_gt_2` |

Each hit is a BLOCK. Tester reports in `audit.md`:

```
## CRAN cookbook violations
| File | Line | Violation | Class |
|---|---|---|---|
| R/get_anova.R | 42 | T as logical | surveycore_error_tf_abbrev |
```

## DESCRIPTION checks

Tester validates against `rules/r-package-conventions.md`:

- **Description field**: ≥ 2 sentences
- **Title**: Title Case (verify with `tools::toTitleCase()`)
- **Authors@R**: `person()` format; no deprecated `Author`/`Maintainer`
- **Imports versions**: lower-bound pins (`(>= x.y.z)`) on all entries
- **No `@importFrom`**: grep `^#' @importFrom` across `R/` → any hit is BLOCK (surveycore convention: use `::` everywhere)

## Builder compliance rules

Builder MUST follow these during implementation (from `rules/r-package-conventions.md` + CRAN cookbook):

1. Use `TRUE`/`FALSE`, never `T`/`F`
2. Call external functions with `::` (no `@importFrom`)
3. Use `message()` for informational output, not `print()`/`cat()`
4. Provide a `seed = NULL` arg for any function using randomness
5. Restore `par()` / `options()` with `on.exit()`
6. Use `tempdir()` for I/O; clean up with `on.exit(unlink(...))`
7. Cap parallel workers at 2 in examples/tests; expose `cores`/`nthreads` for user control
8. Run `devtools::document()` before committing roxygen changes
9. Use `requireNamespace("pkg", quietly = TRUE)` not `installed.packages()`
10. **When adding a new exported function, also add it to the matching
    section's `contents:` block in `_pkgdown.yml`.** Pkgdown enforces
    that every exported function appears in the reference index;
    omission breaks CI. If no existing section fits, create a new
    titled section near related functions. Add `_pkgdown.yml` to the
    PR's write surface.

Builder's `implementation.md` should note compliance at the bottom:

```
## CRAN compliance
- [x] TRUE/FALSE used throughout
- [x] :: used for external calls
- [x] No bare print()/cat()
- [x] devtools::document() run
```
