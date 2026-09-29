# Request — replicate-scale-jkn-bootstrap

> **On the `[not archived]` marker in this file.** The Wolter chapter 4
> source it cites is an extracted copy of a copyrighted textbook chapter and
> lives outside this repository. It was deliberately not archived here rather
> than lost by the pipeline: copying it into a public GPL-3 repository would
> not be appropriate. The marker is the closer of the two the citation
> checker accepts. The file was present and read in full when the
> comprehension was written.

## Intent

Make `as_survey_replicate()` return the same default `scale` as
`survey::svrepdesign()` for two replicate types. JKn moves from `(R-1)/R` to
`1`. Bootstrap moves from `1/R` to `1/(R-1)`. This is PR 3 of the
replicate-scale arc (#257), after #242 fixed JK2. Decisions D1, D2 and D5 in
`plans/issue-cleanup.md` are locked, so the target values are settled and the
work is to land them, document them, and pin them with oracle tests.

`as_survey_nonprob()` keeps `bootstrap = 1/R`. `survey` has no
non-probability design class, so it is not an oracle for one (D1).

Both changes move a published standard error by `1/sqrt((R-1)/R)`.

## Acceptance criteria

- `as_survey_replicate(type = "JKn", rscales = <per-stratum>)` with no
  `scale` stores `scale = 1`.
- `as_survey_replicate(type = "bootstrap")` with no `scale` stores
  `1/(R-1)`.
- `get_means()` on each design matches `survey::svymean()` on a hand-built
  `survey::svrepdesign()` of the same type from the same columns, at the SE
  and CI tolerances in `.claude/rules/testing-surveycore.md`.
- The three `testthat::expect_failure()` wrappers in the JKn oracle block and
  the three in the bootstrap oracle block of
  `tests/testthat/test-variance-replicate.R` are gone, and both blocks pass
  without them.
- `as_survey_nonprob(type = "bootstrap")` still stores `1/R`, and its help
  page states `survey`'s value and why surveycore's differs.
- `@param scale` on `as_survey_replicate()` lists the corrected default for
  JKn and for bootstrap, and records that `bootstrap.average` has no
  surveycore equivalent.
- One migration note covers #242, #253 and #243 together, per #257.
- `as_survey_replicate()` and `as_survey_nonprob()` agree with each other for
  JKn on the same frame.

## Attachments

- Wolter, K. M. (2007). *Introduction to Variance Estimation*, 2nd ed.,
  chapter 4 "The Jackknife Method":
  `C:\Users\jdennen\analysis-sops\knowledge\raw\books\wolter_2007\wolter_2007_ch04_jackknife.md` [not archived].
  §4.5 "Usage in Stratified Sampling" is the section the JKn claim rests on.
  The issue's own comment asks that `JKn = 1` be confirmed against this
  chapter before shipping, because the change moves published numbers.
- GitHub issue #253 (body and one comment) — the measured tables, the
  `survey` source line numbers, and the root cause.
- GitHub issue #257 — the arc tracker and the nine-type audit.
- `plans/issue-cleanup.md` — locked decisions D1, D2, D5.
