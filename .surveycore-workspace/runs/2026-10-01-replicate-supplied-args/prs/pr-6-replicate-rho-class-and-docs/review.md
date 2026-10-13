# Review — PR 6 — replicate-rho-class-and-docs

**Verdict**: BLOCK
**Date**: 2026-10-13 16:46

Branch `fix/replicate-rho-class-and-docs`, HEAD `7593539`, tree
`4adbc7403a9bebc34b0181f2e3f5e72cbb821a1e`, base `origin/develop` `fa75e83`
(merge base equal to `fa75e83`).

## BLOCK — 2026-10-13 16:46

**Failing scenario**: caller item 4 — no `NEWS.md` entry may say anything
false about the PR 1–5 behaviour. Traceable to the planner: `spec.md` §IX is
a closed list of three new entries and gives no fact for the existing entries
that PR 3 made false, so the builder could not fix them without scope creep.
**Observed**: `NEWS.md` line 197–198, the issue #242 entry in the same
unreleased development section (`Version: 1.1.0.9000`, above
`# surveycore 1.1.0` at line 438), ends: "Pass `scale = (R-1)/R` explicitly
to reproduce the old numbers. (#242)". The entry is about
`as_survey_replicate(type = "JK2")`. Since PR 3 (#314), `R/core-constructors.R`
lines 1014–1047 discard a supplied `scale` for JK2, warn with
`surveycore_warning_replicate_arg_ignored`, and store `1`. The instruction now
gives a warning and the new number, not the old one. The new #255 entry 30
lines above says JK2 ignores a supplied `scale`, so the release notes
contradict each other.
**Expected**: the development section of `NEWS.md` states no instruction that
the shipped code refuses or ignores.
**Classification**: contract-miss (spec omission)
**What must change**: the planner adds an erratum to `spec.md` §IX and PR 6
task 8 that corrects the last sentence of the #242 entry; the builder then
applies it.

Facts for the planner (measured on HEAD, not wording):

1. JK2 old numbers. `R/variance-replicate.R` has no branch on `type`, and
   `"other"` stores a supplied `scale` and `rscales` as given. So
   `type = "other"` with `scale = (R-1)/R`, and the `rscales` the old call
   used, reproduces a pre-#242 JK2 number. `type = "JK2"` cannot.
2. JKn old numbers, same release. The #253 entry (NEWS line 205) and the
   kept `@param scale` sentence (spec §III roxygen fact 7) both say "pass
   `scale = (R-1)/R` for JKn". Since PR 2 (#312) a JKn call with no
   `rscales` is refused, so an old call that passed no `rscales` also needs
   `rscales = rep(1, R)` to reproduce its number. The sentences are not
   false, but followed alone they end in the refusal, whose "v" bullet leads
   to `(n_h - 1) / n_h` and a different number. Spec fact 7's rationale
   ("JKn and bootstrap, which both keep a supplied scale") misses this. Fix
   it in the same erratum.

## Convergence checks
- Spec coverage: y. PR 6 carries S7 (second class on the `rho` warning,
  `R/core-constructors.R` 995–998), S10 (roxygen, both Rd files) and S11
  (NEWS). Audit rows 5.22, 5.23, 5.26, 9.2–9.5 validate each.
- Test coverage of spec: y. Test-spec rows 5.22, 5.23, 5.26, 9.2–9.5 cover
  every PR 6 contract item. The gap above is in spec §IX, not test-spec.
- Tolerance integrity: y. Two new `expect_equal()` calls, both
  `tolerance = 1e-8` on a stored scale; plan and test-spec 5.23 say 1e-8.
- Scope discipline: y. Write surface = the 7 Files touched plus
  `vignettes/creating-survey-objects.Rmd` (decision S-1). The two `plans/`
  paths come from leader commit `2c25573`. No path under
  `.surveycore-workspace/` (count 0). The `as_survey_nonprob()` diff is one
  roxygen hunk; no code hunk (gate 10).
- Regression safety: y. `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12757 ]`
  against 12712 on develop; +45 equals the three new blocks. No existing
  snapshot entry changed.

## Profile gates, cookbook, coverage
- All seven gates ran on tree `8192c49`; `git diff --stat 8192c49
  'HEAD^{tree}'` is the changelog only, which `.Rbuildignore` excludes. No
  skip. `Status: 1 NOTE` in both check logs, CRAN incoming feasibility,
  pre-approved.
- CRAN cookbook: None, audit PASS. Consistent.
- Coverage 96.18%, unchanged. Uncovered lines 414, 2115, 2206 are the
  pre-existing three; the new code lines 995–998 are covered.
- Comprehension: no `comprehension.md`; not applicable.

## Rulings on the caller's items

1. Checklist items. R5a: ticked — `@param scale` gives the reason ("a warning
   that fires when the caller passed nothing tells the caller nothing, and
   warnings that no one asserts hide new ones"). R3: ticked — `@param
   rscales` says "For `"JKn"` and the other five types, `"JK1"`, `"BRR"`,
   `"Fay"`, `"bootstrap"` and `"other"`, a supplied `rscales` is stored as
   given". N1: ticked — the `"JK2"` item of `?as_survey_nonprob` says
   `as_survey_replicate()` accepts `"JK2"` with no `rscales`, as
   `survey::svrepdesign()` does.
2. "The other five types". The builder's text is correct: it names six
   types, the set spec §III Arguments gives for "stored as given". Spec
   roxygen fact 3 is also correct: it follows fact 1 (JKn) and fact 2 (the
   three that ignore), so "the other five" is nine minus those four. No
   erratum is needed. The fact is silent on JKn storing a supplied
   `rscales`; the §III Arguments table states it.
3. S-1. The vignette diff is one hunk, lines 345–362, under §3.4 only. Its
   type lists match the roxygen and the #255 NEWS entry: `scale` ignored for
   BRR, JK2, ACS, successive-difference; `rscales` ignored for JK2, ACS,
   successive-difference; the warning class; JKn requires `rscales`; Fay
   takes its scale from `rho`. No code chunk was added.
4. "leaves no jackknife factor" is gone from the roxygen and the Rd. No help
   text or vignette sentence is false about PRs 1–5. One NEWS sentence is
   false: see the BLOCK.
5. The three new NEWS entries are accurate. Entry 1 says a caller who passed
   an ignored argument gets a different standard error and now a warning.
   Entry 2 says JKn with no `rscales`, accepted before, now errors, with the
   class and the migration. Entry 3 matches spec §IV.
6. Commit `7593539` writes `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12757 ]`
   (gate-2-test.log line 3025) and 96.18% (gate-7-covr.log
   `COVERAGE_PCT=96.18`). Both match. It changes only
   `changelog/fix-replicate-supplied-args.md`.

## Cross-consistency notes

implementation.md and audit.md agree on the write surface, the three
blocks, the one snapshot entry, the gate figures and the gate 10 result.

Non-blocking findings:

1. `?as_survey_replicate`, JK2 paragraph (line 655, from `d11d1f8`, before
   this arc): "`survey::svrepdesign()` forces both, and
   [as_survey_nonprob()] agrees." `as_survey_nonprob()` requires `rscales`
   for JK2, and its `type` item now says so beside this PR's sentence. It
   agrees on the scale only. The planner can fold it into the erratum.
2. Vignette §3.4: "For the other types, override `scale` or `rscales`"
   leaves out that BRR and Fay keep a supplied `rscales`. Incomplete, not
   false.
3. `?as_survey_nonprob` `@param rscales` says the default `NULL` sets
   `rep(1, R)`, while its JK2 and JKn items say `rscales` is required.
   Older than this arc.

## Decision

BLOCK. The code, tests, gates, roxygen, vignette and the three new NEWS
entries meet the plan. The development section of `NEWS.md` still tells a
JK2 user to pass `scale = (R-1)/R`, which PR 3 made ineffective. The spec's
closed NEWS list left the builder no way to fix it. Route to the planner for
a §IX erratum, then re-dispatch the builder.
