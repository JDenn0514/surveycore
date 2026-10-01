# Review — PR 9 — fay-rho-news

**Verdict**: PASS
**Date**: 2026-09-30

Branch `docs/fay-rho-news`, HEAD `30c5d49`, tree `5f4642bd`. Base `develop` `da052d2`.

## Convergence checks
- Spec coverage: y. The PR carries spec §VIII.1 to §VIII.4. Audit rows 6.4, 6.5, 6.6, 6.7 and 6.13 check each item.
- Test coverage of spec: y. Test-spec rows 6.4 to 6.7 and 6.13 cover §VIII. The §IX.6 NEWS item shipped in PR 8 and is still in place (NEWS.md lines 94-98).
- Tolerance integrity: y. All rows are exact text checks. The PR has no numeric row.
- Scope discipline: y. `git diff --stat da052d2 HEAD` lists four files: `NEWS.md`, `vignettes/creating-survey-objects.Rmd`, `CLAUDE.md`, `.claude/rules/testing-surveycore.md`. These are the plan's Files touched. No file is extra and no file is missing.
- Regression safety: y. Tests 12353/12353, 256 warnings, 4 skips, coverage 96.17% before and after. R CMD check gives 2 approved notes.

## Checks against develop as merged

NEWS.md, §VIII.1:
- All three items match the §VIII.1 text word for word.
- `rho` sits after `type` and before `scale` (R/core-constructors.R:809). After it, in order: `scale`, `rscales`, `fpc`, `fpctype`, `mse`, `calibration`.
- `surveycore_error_fay_rho_missing`, `surveycore_warning_rho_ignored` and `surveycore_error_fay_rho_unrecoverable` exist at R/core-constructors.R:895 and :933, and at R/methods-conversion.R:416.
- For Fay, the code sets `scale` from `rho` and discards a supplied `scale` with no condition.
- v1.1.0 stored `Fay = 1 / n_rep`, so "used the BRR scale 1/R" is true.
- The variance ratio is 1/(1-rho)^2, so the SE ratio is 1/(1-rho): 1/0.7 = 1.4286 (1.43), and 1/0.5 = 2. The point estimate does not use the scale.
- A saved design keeps its stored `@variables$scale`, so "keeps the old scale" is true.
- `from_svydesign()` copies a Fay `rho` (methods-conversion.R:984). `print()` and `summary()` show `rho` through `.fay_rho_to_print()`.

Other files:
- The vignette matches §VIII.2: lines 299, 302 and 875.
- CLAUDE.md line 89 matches §VIII.3. Only the named phrase changed.
- testing-surveycore.md matches §VIII.4. The section is removed and one paragraph replaces it. The Fay row of the per-type table is unchanged.

## Quality gates across the arc
- Gate 7: no match for `fay_rho` as an argument name. The recover/derive hits are the class name `..._unrecoverable` and the past-tense CLAUDE.md:89 wording, which §VIII.3 requires.
- Gate 8: the Judkins (1990) citations are R/core-classes.R:652, R/core-constructors.R:778 and the two `.Rd` files. All four cite *Journal of Official Statistics* 6(3). The vignette bib entry gives the same journal.
- Gate 9: the file names no live exception. The one "sanctioned" hit (line 299) says the file has none.

## Cross-consistency notes
Tester note: the refusal block at test-variance-replicate.R:975 asserts only that `survey` refuses Fay without `rho`. I judge the new paragraph accurate with this block in place:
- The oracle rule covers tests that ask "is surveycore's number right" (§What the rule covers). The refusal block asks nothing about a surveycore number. It is outside the rule, so it is not an exception to the rule.
- The old exception was an oracle block that could not compare. The comparisons now run in the seven blocks at lines 1063-1188, which pass `rho` to both sides. So "the Fay comparisons ... are now ordinary oracle tests" is true.
- The block's own comment says it guards the behaviour of `survey`. Rule 5 supports a block that asserts a `survey` condition by message text.
- The file has no `expect_failure()` call in code. The two hits (lines 812, 869) are comments.

Possible later wording, not required: "A block that asserts only a `survey` refusal guards `survey`, not surveycore, and is outside the rule." This adds content that §VIII.4 does not list, so I do not route it as a BLOCK.

## Decision
PASS. The four files match §VIII.1 to §VIII.4 exactly. Every NEWS claim is true of the merged code. Gates 7, 8 and 9 hold across the arc, and the audit's gates are clean with no change from the baseline.
