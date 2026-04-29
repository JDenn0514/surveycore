# CRAN resubmission 0.8.3 — spec

**Status:** approved (2026-04-29)
**Target version:** 0.8.3
**Branch:** `chore/cran-resubmit-0.8.3` (off `develop`)
**Source:** CRAN reviewer feedback on the 0.8.2 submission

---

## Problem

CRAN rejected the 0.8.2 submission with four issues. This spec addresses all
four in a single resubmission. Each change is small and mechanical; the
combined diff is expected to be under ~50 lines of source change plus the
release artifacts (NEWS, DESCRIPTION, cran-comments).

The four CRAN flags:

1. **Missing references in `Description`.** CRAN policy requires methods
   references in the `Description:` field formatted as `Author (Year) <doi:...>`.
2. **Commented-out code in `\examples{}`.** Three `# svy <- as_survey(...)`
   lines in dataset man pages (`gss_2024.Rd`, `pew_npors_2025.Rd`, and the
   reviewer also referenced `as_survey.Rd`).
3. **Modification of `.GlobalEnv`.** `R/glm.R:822` assigns `globalenv()` as
   the formula environment.
4. CRAN flagged `as_survey.Rd` alongside the data man pages; the actual
   commented-out construct is the dangling `# tidy-select helpers also work
   (e.g., starts_with())` line in the `\section{Tidy-select}` `\preformatted{}`
   block. Bundled here under issue 2.

---

## Out of scope

* No new exported functions. No new tests beyond what `\examples{}` exercises
  via `R CMD check`. No internal refactoring beyond the four flagged sites.
* `anes_2024.Rd` was not flagged by CRAN but contains the same
  `# svy <- as_survey(anes_2024, ...)` pattern. Fixing it is in scope to
  avoid a future round of CRAN feedback.

---

## Change 1 — `DESCRIPTION` references

Replace the current `Description:` field with the version below. Adds two
DOIs (Lumley 2004 for variance estimation; Mannan 2025 for polychoric /
polyserial correlation), which together cover all methods in the package.
Also removes the `'surveyverse'` ecosystem pointer and trims the estimator
list to three exemplars.

```
Description: Provides 'S7'-based infrastructure for survey analysis.
    Supports Taylor series, replicate weight, and two-phase designs following
    the methods in Lumley (2004) <doi:10.18637/jss.v009.i08>. Includes
    design-based estimators such as means, frequencies, and regression
    models, with weighted polychoric and polyserial correlation following
    Mannan (2025) <doi:10.2139/ssrn.6580480>. A metadata system automatically
    preserves 'haven'-style variable labels, value labels, and
    question-preface attributes through all operations. Uses a 'tidyselect'
    interface for design specification.
```

CRAN format compliance:
- `Author (Year) <doi:...>` form
- No space after `doi:`
- Angle brackets for auto-linking
- Both DOIs already validated by the existing roxygen `\doi{}` calls in
  `man/as_survey.Rd` and `man/get_corr.Rd`

---

## Change 2 — `R/data.R` `@examples` and `@details`

Three `as_survey()` calls are currently commented out in `@examples` blocks.
The fix uncomments them and — for the two designs with non-globally-unique
PSU IDs — adds `nest = TRUE` so the calls run without emitting warnings. The
prose `@details` blocks for those two datasets are updated to match.

### 2a — `anes_2024` (R/data.R lines 282–283 in `@examples`; also `@details`)

Before:
```r
#' # Create pre-election design
#' # svy <- as_survey(anes_2024, ids = v240103c, strata = v240103d,
#' #                  weights = v240103a)
```

After:
```r
#' # Create pre-election design
#' svy <- as_survey(
#'   anes_2024,
#'   ids = v240103c,
#'   strata = v240103d,
#'   weights = v240103a,
#'   nest = TRUE
#' )
```

Update the `@details` prose code-sketch to also include `nest = TRUE`.
Verified runtime: 0.030s (well under the 5s `\donttest{}` threshold).

### 2b — `gss_2024` (R/data.R line 405 in `@examples`; also `@details`)

Before:
```r
#' # Create survey design
#' # svy <- as_survey(gss_2024, ids = vpsu, strata = vstrat, weights = wtssps)
```

After:
```r
#' # Create survey design
#' svy <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   strata = vstrat,
#'   weights = wtssps,
#'   nest = TRUE
#' )
```

Update the `@details` prose code-sketch to also include `nest = TRUE`.
Verified runtime: 0.080s.

### 2c — `pew_npors_2025` (R/data.R line 566 in `@examples`)

Before:
```r
#' # Create survey design (no PSU for ABS design)
#' # svy <- as_survey(pew_npors_2025, strata = stratum, weights = weight)
```

After:
```r
#' # Create survey design (no PSU for ABS design)
#' svy <- as_survey(
#'   pew_npors_2025,
#'   strata = stratum,
#'   weights = weight
#' )
```

No `nest = TRUE` needed — no PSU in this design. Verified runtime: 0.002s.

---

## Change 3 — `R/core-constructors.R` `\section{Tidy-select}` and `@examples`

### 3a — Convert `\section{Tidy-select}` to prose-only

Drop the `\preformatted{}` code sketch (which contains the dangling `#
tidy-select helpers also work...` comment that triggered the CRAN flag).
Keep the same content as inline-coded prose.

Before (R/core-constructors.R:57–66):
```r
#' @section Tidy-select:
#' All design variable arguments (`ids`, `probs`, `weights`, `strata`, `fpc`)
#' support tidy-select syntax:
#' ```r
#' # Bare name
#' as_survey(df, weights = wt)
#' # c() for multi-stage ids
#' as_survey(df, ids = c(psu, ssu), weights = wt)
#' # tidy-select helpers also work (e.g., starts_with())
#' ```
```

After:
```r
#' @section Tidy-select:
#' All design variable arguments (`ids`, `probs`, `weights`, `strata`,
#' `fpc`) support tidy-select syntax: bare column names, `c()` to combine
#' multiple columns (multi-stage `ids = c(psu, ssu)`, multi-stage `fpc`),
#' and tidyselect helpers like `starts_with()`. See the Examples section
#' below for runnable demonstrations.
```

### 3b — Extend `@examples` with `c()` and `starts_with()` demos

The existing NHANES example (which already demonstrates bare-name
tidy-select) stays unchanged. Append two new examples:

```r
#' # c() to combine multiple columns — sketched on a synthetic two-stage frame
#' df <- data.frame(
#'   psu = rep(1:5, each = 4),
#'   ssu = 1:20,
#'   wt  = runif(20, 0.5, 2)
#' )
#' d_ms <- as_survey(df, ids = c(psu, ssu), weights = wt)
#'
#' # Tidy-select helpers like starts_with() also work
#' d_h <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   strata = vstrat,
#'   weights = starts_with("wtssn"),
#'   nest = TRUE
#' )
```

Verification during implementation:
* `starts_with("wtssn")` must resolve to exactly one column (`wtssnrps`).
  `as_survey()` requires single-column weights; if `starts_with("wtssn")`
  matched both `wtssps` and `wtssnrps` we would get an error.
* The synthetic two-stage frame must satisfy the `as_survey()` validator —
  `ssu = 1:20` is unique within each PSU, which the validator accepts.
* Both new examples should run in well under 1s combined.

---

## Change 4 — `R/glm.R:822` `globalenv()` → `baseenv()`

Single-line source change plus a comment update. The formula environment is
used by `model.frame()` for symbol lookup outside `data`; `baseenv()` retains
access to base R operators (`+`, `:`, `I`, `log`) that formulas may rely on,
while not modifying or referencing `.GlobalEnv`.

Before (R/glm.R:819–822):
```r
# Reset environment: reformulate() inherits survey_glm()'s frame, which
# would embed all local variables in the stored object. Use globalenv()
# so the stored formula is portable.
environment(formula) <- globalenv()
```

After:
```r
# Reset environment: reformulate() inherits survey_glm()'s frame, which
# would embed all local variables in the stored object. Use baseenv() so
# the stored formula is portable and CRAN-policy compliant (no reliance
# on .GlobalEnv).
environment(formula) <- baseenv()
```

The existing comment at R/glm.R:1046–1049 already documents that the formula
environment is mostly cosmetic in this code path because `do.call()` embeds
the weights vector directly. No further code changes needed.

---

## Implementation order

1. Create branch `chore/cran-resubmit-0.8.3` from `develop`.
2. Apply Change 4 first (smallest, lowest risk).
3. Apply Change 1 (`DESCRIPTION`).
4. Apply Change 2 (`R/data.R` — three `@examples` blocks + two `@details`
   blocks).
5. Apply Change 3 (`R/core-constructors.R`).
6. Run `air::format_file()` on each touched R file.
7. Run `devtools::document()` to regenerate the four affected `.Rd` files
   (`as_survey.Rd`, `anes_2024.Rd`, `gss_2024.Rd`, `pew_npors_2025.Rd`).
8. Verify `starts_with("wtssn")` resolves to a single column on `gss_2024`.
9. Run `devtools::test()` — all existing tests must still pass.
10. Run `devtools::check()` — must be clean (0 errors, 0 warnings, ≤2
    pre-approved notes).
11. Bump `DESCRIPTION` Version: `0.8.2.9000` → `0.8.3`.
12. Add `# surveycore 0.8.3` section to `NEWS.md` documenting the four
    fixes.
13. Rewrite `cran-comments.md` as a resubmission cover letter that responds
    to each of CRAN's four flags point-by-point.
14. Add a `changelog/chore-cran-resubmit-0.8.3.md` file describing the work.
15. Run `devtools::check_win_devel()` to validate against R-devel before
    resubmission.
16. Open PR `chore/cran-resubmit-0.8.3` → `develop`. Wait for CI green and
    win-devel email green.
17. Merge to `develop`. Open release PR `develop` → `main`. Tag `v0.8.3`.
    Run `devtools::submit_cran()` from `main`. Bump `develop` to
    `0.8.3.9000`.

---

## Verification gates

| Gate | Threshold |
|---|---|
| `devtools::test()` | All existing tests pass |
| `devtools::check()` | 0 errors, 0 warnings, ≤2 notes (env timestamps + "New submission") |
| `devtools::check_win_devel()` | 0 errors, 0 warnings, 1 note (New submission) |
| Examples runtime (combined) | < 5s (verified <0.5s for the new examples) |
| `air::format_file()` on touched R files | No diff after format |

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `starts_with("wtssn")` matches more than one column → `as_survey()` errors at build time | Low | Verified manually; `gss_2024` columns starting with `wtssn` are exactly `wtssnrps`. |
| `baseenv()` change breaks a `survey_glm()` test | Low | Existing test-glm-* tests cover both formula and response/predictors interfaces. Run `devtools::test()` after the change. |
| `nest = TRUE` change to `gss_2024`/`anes_2024` examples produces a different design than what users have been running locally | Low | The change makes the design *correct*; the previous (warning-emitting) design was misspecified. Documented in NEWS.md. |
| CRAN reviewer flags additional issues on resubmission | Medium | Cover letter explicitly addresses all four flags. Win-devel pre-check should catch most surprises. |

---

## Files changed

| File | Change |
|---|---|
| `DESCRIPTION` | Description field (Change 1) + Version bump |
| `R/data.R` | Three `@examples` + two `@details` blocks (Change 2) |
| `R/core-constructors.R` | `\section{Tidy-select}` + `\examples{}` (Change 3) |
| `R/glm.R` | Line 822 + surrounding comment (Change 4) |
| `man/anes_2024.Rd` | Regenerated by `document()` |
| `man/gss_2024.Rd` | Regenerated by `document()` |
| `man/pew_npors_2025.Rd` | Regenerated by `document()` |
| `man/as_survey.Rd` | Regenerated by `document()` |
| `man/survey_glm.Rd` | Regenerated by `document()` |
| `NEWS.md` | New `# surveycore 0.8.3` section |
| `cran-comments.md` | Rewritten as resubmission cover letter |
| `changelog/chore-cran-resubmit-0.8.3.md` | New file |
