# Implementation — PR 9: fay-rho-news

**Branch**: `docs/fay-rho-news`
**Base**: `da052d246d27ad4c756a8d7e2908b77b7126bdff` (tree `4109fb32ea236a0061db32a3a0733815ea39d760`). The worktree opened on `d4d1db2`; it was reset to the base before any edit.
**Head**: `30c5d49`

## Write surface

Modified (no file created or deleted):

- `NEWS.md`
- `vignettes/creating-survey-objects.Rmd`
- `CLAUDE.md`
- `.claude/rules/testing-surveycore.md`

`git diff --name-only da052d2...HEAD` lists exactly these four files. No `R/`, `man/` or test file changed, so `devtools::document()` was not needed.

## Summary

- `NEWS.md`: rewrote the `## Bug fixes` Fay export entry in place with the spec §VIII.1 text. It now says the route passes the stored `rho`, and it names `surveycore_error_fay_rho_unrecoverable` for a design with no `rho`. References are `(#198, #250, #243)`.
- `NEWS.md`: added two `## Breaking changes` items at the top of that section, above PR 8's two-phase item, which stays unchanged. The first item covers the `rho` argument and the moved Fay SE. The second covers the formal order.
- Vignette: line 299 now reads "The Fay shrinkage factor (`rho`)" and gains the sentence "`as_survey_replicate()` requires `rho` when `type = "Fay"`." (new line 302). In the table row at line 874, the "Maps to" cell `fay_rho =` became `rho =`, padded to keep the column width.
- `CLAUDE.md` line 89: replaced only the phrase that §VIII.3 names. `git diff --word-diff` shows `[-recovers-]{+recovered+}` and `{+until issue #243 replaced the recovery with a stored `rho`+}`, and nothing else changed.
- `.claude/rules/testing-surveycore.md`: deleted the whole `### Sanctioned exceptions in test-variance-replicate.R` section, including its heading, the JKn/bootstrap paragraph and the Fay bullet. One paragraph replaces it. The paragraph says the file has no sanctioned exceptions, the last one was the Fay block, the Fay comparisons are now ordinary oracle tests since #243 added `rho`, and `expect_failure()` wrappers must not come back. It does not call the remaining survey-refusal guard block an oracle test. The per-type table's Fay row is unchanged. The Quick Reference oracle row names no exception, so it is unchanged.

## Tasks

- [x] 1. Rewrite the NEWS Bug fixes Fay export entry; keep the issue references; add #243
- [x] 2. Add the two Breaking changes items
- [x] 3. Vignette lines 299 and 874 (line numbers confirmed before the edit)
- [x] 4. CLAUDE.md line 89, one phrase only
- [x] 5. testing-surveycore.md: replace the section with one paragraph
- [x] 6. Searches (below). The orchestrator runs criterion G.

## Search checks

Each command ran from the worktree root on the head commit.

| Criterion | Command | Result |
|---|---|---|
| 1 | `grep -rn "fay_rho" vignettes/` | no match |
| 1 | `grep -n "Fay shrinkage factor (\`rho\`)\|requires \`rho\` when" vignettes/creating-survey-objects.Rmd` | lines 299 and 302 |
| 2 | (read) NEWS.md Bug fixes | one Fay export entry. It says "passes the design's stored `rho`" and has no recovery wording. Breaking item 1 says "the old one divided by `1 - rho`" and names `surveycore_error_fay_rho_missing` |
| 3 | (read) NEWS.md Breaking changes | item 2 says "after `type` and before `scale`" and lists the six moved arguments |
| 4 | `git diff --word-diff CLAUDE.md` | only the §VIII.3 phrase changed |
| 5 | `grep -n -i "sanctioned" .claude/rules/testing-surveycore.md` | one hit, line 299: "has no sanctioned exceptions to"; no section heading |
| 5 | `grep -n '^\| Fay' .claude/rules/testing-surveycore.md` | line 251: `\| Fay \| \`1/(R * (1 - rho)^2)\` \| discard, no warning \| honoured \|` |
| 6 / gate 7 | `grep -rnw "fay_rho" R/ man/ vignettes/ NEWS.md CLAUDE.md` | no match |
| 6 / gate 7 | `grep -rn "fay_rho" R/ man/ vignettes/ NEWS.md CLAUDE.md` (substring) | matches only the class names `surveycore_error_fay_rho_missing`, `_invalid`, `_unrecoverable` and the internal helper `.fay_rho_to_print()`; no argument named `fay_rho` |
| 6 / gate 7 | `grep -rniE "recover\|deriv" R/ man/ vignettes/ NEWS.md \| grep -i "rho\|fay\|shrinkage"` | only the class name `surveycore_error_fay_rho_unrecoverable` (R/methods-conversion.R:416, NEWS.md:243) |
| 6 / gate 7 | `grep -rniE "(recover\|deriv)[a-z]* .{0,40}(rho\|shrinkage)\|(rho\|shrinkage).{0,40}from the (recorded \|stored )?scale" R/ man/ vignettes/ NEWS.md CLAUDE.md` | one hit, CLAUDE.md:89. This is the past-tense §VIII.3 wording ("recovered ... until issue #243 replaced the recovery with a stored `rho`"), so it does not say surveycore recovers `rho` |
| 6 / gate 8 | `grep -rni "judkins" R/ man/` | four hits (R/core-classes.R:652, R/core-constructors.R:778, man/as_survey_replicate.Rd:240, man/survey_replicate.Rd:95). Every one cites *Journal of Official Statistics* 6(3) |
| 6 / gate 8 | `grep -rni "american statistical\|JASA" R/ man/` | the hits are Deville and Sarndal (1992), Deville, Sarndal and Sautory (1993), the quantiles and calibration references, and the nonprob references. None is Judkins |

## HOLDs

None.

## Notes for tester

- `.claude/settings.local.json` was modified in the worktree before the reset. It was backed up and restored, and it is not committed.
- NEWS.md has lines longer than 80 characters near lines 609-627. They were there before this PR, and this PR did not touch them.
