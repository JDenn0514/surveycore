# PR 9 — docs/oracle-rule-exceptions

## Write surface

| File | Action |
|---|---|
| `.claude/rules/testing-surveycore.md` | Modified |

That is the only file. `tests/testthat/test-variance-replicate.R` is
untouched; this PR validates it without editing it.

## Summary

- Appended the "Sanctioned exceptions in `test-variance-replicate.R`"
  subsection to the oracle rule, after "What the rule covers". The text is
  `spec.md` §III.2's final subsection, changed in formatting only: the
  block-quote markers are removed and nothing else.
- The subsection names the two sanctioned exceptions with the issues that
  close them — the JKn and bootstrap blocks that wrap three failing
  assertions in `testthat::expect_failure()` (issue #253), and the Fay block
  that compares nothing (issue #243) — and says anything else that breaks
  the shape is a violation.
- Bumped the file header from `**Version:** 1.2` to `**Version:** 1.3`: one
  bump at the arc's end for the three PRs that added rule text (decision
  S2). Nothing else in the header changed.
- Validated the finished test file without editing it. Four measurements
  follow.

## Measurement 1 — the test file with `survey` installed

Command:

    NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'

Result: `[ FAIL 0 | WARN 1 | SKIP 0 | PASS 166 ]`.

Zero failures and zero skips. The one warning is the pre-existing AAPOR
small-cell warning from `get_corr()` at `test-variance-replicate.R:798:3`,
in the block "get_corr() replicate returns NA for domain with fewer than 2
paired obs". It is not new, it touches no oracle block, and it is reported
rather than fixed. No no-warning assertion fired.

## Measurement 2 — the test file with `survey` unreachable

Method, stated exactly because it must be repeatable. I did not uninstall
`survey` and did not modify the real library. I built a scratch library that
holds one directory, `survey/`, containing a `DESCRIPTION` for a stub
package with no code:

    Package: survey
    Version: 0.0.0.9000
    Title: Shadow stub that fails to load
    ...

I then put that scratch library in front of the real one with `R_LIBS`.
`find.package()` stops at the first library that holds a `survey/DESCRIPTION`,
so it resolves to the stub; `loadNamespace()` then fails on it, and
`requireNamespace("survey", quietly = TRUE)` returns `FALSE` instead of
searching on. The real library is never read for `survey` and never written.

Probe, before the run:

    requireNamespace: FALSE
    rlang::is_installed: FALSE

Run:

    NOT_CRAN=true R_LIBS=<scratch-lib> Rscript -e \
      'testthat::test_local(filter = "variance-replicate", reporter = "summary")'

Result: 14 blocks skipped, reason `{survey} cannot be loaded`; no failures
and no errors in the log. The 14 are exactly the 14 blocks that call
`survey::` (measurement 3 counts them the same way from the parse tree):

1. get_means() replicate SE matches survey::svymean() — BRR design
2. get_totals() replicate SE matches survey::svytotal() — BRR design
3. get_means() replicate SE matches survey::svymean() — JK1 design
4. get_means() replicate SE matches survey::svymean() — JK2 design
5. get_means() replicate: mse=FALSE matches survey with mse=FALSE
6. get_means() BRR scale formula 1/n_rep is correct for n_rep != 4
7. get_means() successive-difference SE matches survey::svymean()
8. get_totals() successive-difference SE matches survey::svytotal()
9. get_means() ACS SE matches survey::svymean()
10. get_totals() ACS SE matches survey::svytotal()
11. get_means() JKn SE disagrees with survey::svymean() — issue #253
12. get_means() bootstrap SE disagrees with survey::svymean() — issue #253
13. get_means() replicate SE matches survey::svymean() — other design
14. survey::svrepdesign() refuses Fay without rho — Fay design

The AAPOR warning at line 798 still fires in this run; its block calls no
`survey` function and does not skip.

## Measurement 3 — block count and type count, by parsing

Instrument: `utils::getParseData()` on `parse(file, keep.source = TRUE)`,
plus a walk over the parsed top-level expressions. Textual counting is
wrong on this file, and the run shows why:

| Token | `getParseData()` | `grep` on lines |
|---|---|---|
| `test_that` calls | 28 | — |
| `expect_failure` calls | 6 | 12 |
| `svrepdesign` calls | 14 | 18 |

28 `test_that()` blocks: the 24 the file held before the arc plus the four
the arc added (JKn, bootstrap, other, Fay).

Types with at least one oracle block: 9 of 9. A block counts as an oracle
block when its parse tree holds a `survey::` call; its type comes from the
string constants in the same tree.

    ACS, bootstrap, BRR, Fay, JK1, JK2, JKn, other, successive-difference

Missing: none.

The same walk confirms the two wrapper blocks the new subsection describes
carry three `testthat::expect_failure()` calls each, 6 in total:

- 3 — get_means() JKn SE disagrees with survey::svymean() — issue #253
- 3 — get_means() bootstrap SE disagrees with survey::svymean() — issue #253

## Measurement 4 — full suite, warning comparison

Command: `Rscript -e 'devtools::test()'`, output to a log, log deleted
after reading.

Result: `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12005 ]`.

256 warnings, the expected count, unchanged against the base branch. The
comparison is exact rather than approximate: this PR's diff holds one
markdown file, so every file under `R/` and `tests/` is byte-identical to
`d6d30c7`, and the suite this run exercised is the base branch's suite.

Warnings attributable to `test-variance-replicate.R`: 1, the AAPOR
small-cell warning at line 798 already reported under measurement 1. The
largest contributors elsewhere are `test-analysis-freqs.R` (51) and
`test-survey-collection-dispatch.R` (41). No no-warning assertion fired
anywhere in the run.

The full suite rewrote every file under `tests/testthat/_snaps/` with
different line endings. `git diff` reported no content change for any of
them, and `git checkout -- tests/testthat/_snaps` restored the timestamps,
so none of them reaches the commit.

## Checks

- Block titles against the spec: the subsection describes the three blocks
  by type and quotes no title, so no title could mismatch. All three exist
  on disk, and each matches its description — the JKn and bootstrap blocks
  wrap three `testthat::expect_failure()` calls each and name issue #253 in
  their titles; the Fay block asserts `survey`'s refusal on one side and
  the stored scale `1 / n_rep` on the other, and its comment names issue
  #243. No HOLD.
- The rule section records no exact expectation total and no run time. The
  only number in it that could read as a count is "issue #242 survived 22
  releases", which is PR 1's text and is neither.
- `air format --check .claude/rules/testing-surveycore.md` — exit 0.
- `git diff --name-only d6d30c7` — `.claude/rules/testing-surveycore.md`,
  one file.
- Not run, by instruction: `devtools::check()`, `devtools::document()`,
  `devtools::run_examples()`, `pkgdown`, `covr`. The leader runs those.

## Tasks

- [x] 1. Append the sanctioned-exceptions subsection from `spec.md` §III.2.
- [x] 2. Read the rule section back; no expectation total, no run time.
- [x] 3. Confirm the three blocks exist and match their descriptions.
- [x] 4. Run the file with `survey` installed — 0 failures, 0 skips.
- [x] 5. Run the file with `survey` unreachable — 14 skips, 0 failures.
- [x] 6. Count blocks and types by parsing — 28 and 9 of 9.
- [x] 7. Run the full suite — 256 warnings, unchanged.
- [x] 8. `air format --check` and `git diff --name-only`.
- [x] 9. Package gates left to the leader.
- [x] S2. Version header bumped 1.2 to 1.3.

## HOLDs

None.

## Notes for tester

- The scratch stub library in measurement 2 lives in the session scratchpad
  and is not part of the repository. Rebuild it from the DESCRIPTION above
  to repeat the run.
- `.claude/rules/testing-surveycore.md` is checked out with CRLF endings
  under `core.autocrlf=true`. The edit wrote LF into the working tree; git
  normalises both to LF in the index, so the diff is the one changed
  version line plus the appended subsection and nothing else.
