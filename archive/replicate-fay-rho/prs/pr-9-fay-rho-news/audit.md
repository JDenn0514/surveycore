# Audit — PR 9: fay-rho-news

**Verdict: PASS**

Branch `docs/fay-rho-news`, HEAD `30c5d49`, base `develop` `da052d2`.
This PR changes documentation only. The tester ran no gate. The
orchestrator ran the gates on this tree. The table below copies them from
`gates/summary.txt` and the dispatch.

## Profile gates

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | FAIL 0, WARN 256, SKIP 4, PASS 12353 |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran --no-manual | PASS | Status: 2 NOTEs. Both are approved: CRAN incoming feasibility (log line 14), and the hidden `.git` note that existed before (log line 37) |
| pkgdown | PASS | the site built, with the edited vignette |
| covr (NOT_CRAN=true) | PASS | 96.17% |

Tree: 5f4642bda46bd1d6793997ce967d8b6749cd6a05

`git rev-parse HEAD^{tree}` on the checkout gives the same hash.

## Per-test result table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 6.4: `fay_rho` under `vignettes/` | 0 hits. Line 299 reads "The Fay shrinkage factor (`rho`)" and adds "`as_survey_replicate()` requires `rho` when `type = "Fay"`" | 0 hits, and the line 299 text | exact | ✓ |
| 6.5: NEWS has one Fay export entry | 1 entry (line 240). It passes the stored `rho` and does not say `rho` is recovered | 1 entry, no "recovered" | exact | ✓ |
| 6.5: breaking-change item for the SE | Line 75: "the old one divided by `1 - rho`", and it names `surveycore_error_fay_rho_missing` | both present | exact | ✓ |
| 6.6: CLAUDE.md | Line 89: "recovered ... until issue #243 replaced the recovery with a stored `rho`" | present | exact | ✓ |
| 6.7: no live "Sanctioned exceptions" section | The heading is gone. The new paragraph (line 299) says there are no sanctioned exceptions | no live exception | exact | ✓ |
| 6.7: Fay row of the per-type table | `1/(R * (1 - rho)^2)`, discard, no warning, honoured | unchanged | exact | ✓ |
| 6.13: item for the order of formals | `rho` sits after `type` and before `scale`. It names `scale`, `rscales`, `fpc`, `fpctype`, `mse`, `calibration` as one position later | present | exact | ✓ |

## Acceptance criteria (implementation plan, PR 9)

| # | Check | Result |
|---|---|---|
| 1 | Row 6.4 | ✓ |
| 2 | Row 6.5 | ✓ |
| 3 | Row 6.13 | ✓ |
| 4 | Row 6.6 | ✓ |
| 5 | Row 6.7 | ✓ |
| 6 | Search over the whole arc (see below) | ✓ |
| 7 | G: see the gate table. There are no snapshot changes and no `.R` changes, so `air` does not apply. The diff lists only the four files in Files touched | ✓ |

### Criterion 6 search

- The search for the word `fay_rho` in `R/`, `man/`, `vignettes/`, `NEWS.md` and `CLAUDE.md` gave 0 hits. The `surveycore_error_fay_rho_*` class names are not this token.
- A search for recover or derive near `rho`, Fay or shrink gave three hits:
  - `CLAUDE.md:89` uses the past tense and says #243 replaced the recovery. Row 6.6 requires this text.
  - `R/methods-conversion.R:416` and `NEWS.md:243` are only the class name `surveycore_error_fay_rho_unrecoverable`.
  - No text says that surveycore recovers or derives `rho` now.
- Judkins (1990) appears at `R/core-classes.R:652`, `R/core-constructors.R:778`, `man/as_survey_replicate.Rd:240` and `man/survey_replicate.Rd:95`. All four cite the *Journal of Official Statistics* 6(3), 223-239. No citation names the *Journal of the American Statistical Association*.

## Specific checks from the dispatch

- **CLAUDE.md**: `git diff --word-diff da052d2 -- CLAUDE.md` changes one line, line 89. The diff makes two changes in one phrase: it replaces `recovers` with `recovered`, and it inserts "until issue #243 replaced the recovery with a stored `rho`". Nothing else changes. ✓
- **testing-surveycore.md**: only the section is deleted and the paragraph is put in its place. The paragraph names no live exception. ✓
- **test-variance-replicate.R as merged**:
  - The block at line 975, "survey::svrepdesign() refuses Fay without rho — Fay design", asserts only the `survey` refusal (message text, `fixed = TRUE`).
  - The paragraph calls "the Fay comparisons against survey" oracle tests. It does not give that name to the refusal block. Its claim is true: the seven blocks at lines 1063-1188 pass `rho` to both sides through `make_fay_oracle_pair()`, and assert the stored scale against a literal, the SE and both CI bounds.
  - A parse of the lines that are not comments finds no `expect_failure()` calls, so the paragraph's "do not reintroduce" matches the file. ✓
- **NEWS.md**:
  - It has one entry for the Fay export route (line 240).
  - PR 8's two-phase item is kept (lines 94-98: `surveycore_error_twophase_replicate_phase1`, "reverses PR #74").
  - The two §VIII.1 breaking-change items are added (lines 75 and 88). ✓

Note: the refusal block still "compares nothing", and the paragraph says the last exception was a Fay block that compared nothing. A reader could take the remaining block for the old exception. The block's own comment states that it guards the behaviour of `survey`. This does not block the PR.

## CRAN cookbook violations

None. The PR changes no file under `R/`.

## Before/After comparison

| Metric | Before PR (develop da052d2, tree 4109fb3) | After PR (tree 5f4642b) | Δ |
|---|---|---|---|
| tests passing | 12353 | 12353 | 0 |
| failures | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.17% | 96.17% | 0 |
| R CMD check notes | 2 | 2 | 0 |

## HOLDs

None.
