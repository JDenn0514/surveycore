# Comprehension — replicate-fay-rho

Issue #243. Stage 0 of the spec workflow. Inputs: `request.md`, `impact.md`,
`decisions.md` (S1 to S3, binding), `plans/issue-cleanup.md` D6 to D10.

## Measurement record

Script: `measure-fay.R`, in this run directory. Output:
`measure-fay-output.txt`, same directory. The orchestrator ran it from the
worktree root, exit 0. Section tags M0 to M9 below point to the output.

- M0 versions: R 4.6.1 (2026-06-24 ucrt), `survey` 4.5, surveycore
  1.1.0.9000.
- Fixture A (M2 to M6, M9): `make_survey_data(n = 200, n_psu = 20,
  n_strata = 4, design = "replicate", type = "fay", seed = 15)`. This is the
  frame of the current Fay block in `tests/testthat/test-variance-replicate.R`
  (line 987). The generator gives `n_psu %/% 2` replicate columns in `"fay"`
  mode, so `R = 10`. Outcome `y1`.
- Fixture B (M7, M8): the `make_taylor_source()` frame from
  `tests/testthat/test-conversion.R:2335` (seed 421, 60 rows, 6 strata, 12
  PSUs), through `survey::svydesign(ids = ~psu, strata = ~strata,
  weights = ~wt, nest = TRUE)` and `survey::as.svrepdesign()`. `R = 8`.

The replicate columns in fixture A are random perturbations of `wt`, not
real Fay weights. That is enough for these measurements: both packages apply
the same formula to the same columns.

Adversarial verification ran on 2026-09-30 (two independent verifiers). Its
findings are fixed in this revision.

## Problem

Fay's method is a variant of balanced repeated replication (BRR). BRR builds
each replicate by doubling the weight of one PSU in each stratum and setting
the weight of the other PSU to zero. Fay's method softens this. It multiplies
one PSU by `2 - rho` and the other by `rho`, with `0 <= rho < 1`. No PSU
drops out, so domain estimates and ratio estimates stay defined in every
replicate. The softer perturbation makes each replicate estimate sit closer
to the full-sample estimate, by a factor of `1 - rho`. The variance formula
must undo that shrinkage, so it divides by `(1 - rho)^2`.

surveycore accepts `type = "Fay"` but has no `rho`. It stores the BRR scale
`1/R` (`R/core-constructors.R:856`; M9: stored scale 0.1 at `R = 10`). Every
standard error from a Fay design built with `as_survey_replicate()` is too
small by the factor `1 - rho`. The work adds `rho`, derives the Fay scale
from it, stores it, and passes it to `survey` on export.

## Formulas

### F1. Fay replicate variance

$$
\hat v_{\text{Fay}}(\hat\theta)
  = \frac{1}{R\,(1-\rho)^2}\sum_{r=1}^{R} c_r\,(\hat\theta_r - \bar\theta)^2
$$

- `mse = TRUE`: $\bar\theta = \hat\theta$, the full-sample estimate.
- `mse = FALSE`: $\bar\theta$ is the mean of the replicate estimates over the
  replicates with $c_r > 0$.

| Symbol | Meaning | Bound to |
|---|---|---|
| $R$ | replicate count | `length(design@variables$repweights)` (`n_rep` in `as_survey_replicate()`) |
| $\rho$ | Fay shrinkage factor | new argument `rho`; stored as `design@variables$rho` |
| $c_r$ | per-replicate factor | `design@variables$rscales`; `rep(1, R)` when `NULL` |
| $1/(R(1-\rho)^2)$ | overall scale | `design@variables$scale` |
| $\hat\theta_r$ | estimate under replicate $r$ | computed from `design@data[[repweights[r]]]` |
| $\hat\theta$ | full-sample estimate | computed from `design@data[[design@variables$weights]]` |
| mse flag | centring choice | `design@variables$mse` |

### F2. The engine is type-blind

`R/variance-replicate.R:26-46`, `.svy_rep_var()`, computes
`sum((thetas - center)^2 * rscales) * scale`. The matrix form at lines 142
and 215-258 computes `scale * sum_r(rscales_r * dev_r[j] * dev_r[k])`. No
line in the file reads `@variables$type`. survey's `svrVar()` (M1b) has the
same two forms, `sum((thetas - meantheta)^2 * rscales) * scale` and a
`crossprod()` form, and also reads no type. So Fay differs from BRR only
through the stored `scale`. **`R/variance-replicate.R` needs no change.**

M2 measures this directly. surveycore built with `type = "Fay"` and
`scale = 1/(R(1 - rho)^2)` against `survey::svrepdesign(type = "Fay",
rho = )` on the same columns, fixture A, outcome `y1`:

| rho | mse | survey `$scale` | survey SE | SE diff | CI bound diff |
|---|---|---|---|---|---|
| 0 | TRUE | 0.1 | 0.0476228676217971 | 8.0e-15 | 1.4e-14 |
| 0.3 | TRUE | 0.204081632653061 | 0.0680326680311388 | 1.1e-14 | 2.1e-14 |
| 0.5 | TRUE | 0.4 | 0.0952457352435943 | 1.6e-14 | 3.6e-14 |
| 0.9 | TRUE | 10 | 0.476228676217972 | 8.0e-14 | 1.6e-13 |
| 0 | FALSE | 0.1 | 0.0473065129109953 | 7.5e-15 | 1.4e-14 |
| 0.3 | FALSE | 0.204081632653061 | 0.0675807327299933 | 1.1e-14 | 2.1e-14 |
| 0.5 | FALSE | 0.4 | 0.0946130258219906 | 1.5e-14 | 2.8e-14 |
| 0.9 | FALSE | 10 | 0.473065129109953 | 7.5e-14 | 1.4e-13 |

The mean difference is exactly 0 in all eight rows. survey's `$scale`
equals the formula in all eight rows, and `$rho` holds the value passed.

The floating-point difference is a fixed fraction of the SE. SE diff over
SE is about 1.69e-13 in every `mse = TRUE` row: 8.035e-15 on 0.0476 at
`rho = 0`, 8.032e-14 on 0.476 at `rho = 0.9`, and the same ratio at 0.3 and
0.5. The absolute difference grows only because the SE grows, by
`1/(1 - rho)`. At `rho = 0.9` the SE difference is 8.0e-14 and the CI bound
difference is 1.6e-13. Both are far inside the 1e-8 SE and 1e-6 CI
tolerances.

### F3. Why `(1 - rho)^2` (recalled, not read)

Source: Judkins, D.R. (1990) "Fay's method for variance estimation",
*Journal of Official Statistics* 6(3), 223-239. The citation is confirmed by
the orchestrator and matches `vignettes/references.bib:64-72`. The mechanism
below is recalled; the paper is not attached and was not read.

In a two-PSU stratum, BRR multiplies the two PSUs by `1 + 1` and `1 - 1`.
Fay multiplies them by `1 + (1 - rho)` and `1 - (1 - rho)`, which are
`2 - rho` and `rho`. The weight perturbation is the BRR perturbation times
`1 - rho`. For a linear estimator the replicate deviation is linear in the
perturbation, so

$$
\hat\theta_r^{\text{Fay}} - \hat\theta = (1-\rho)\,(\hat\theta_r^{\text{BRR}} - \hat\theta).
$$

Squaring gives `(1 - rho)^2`, and dividing by it recovers the BRR variance.
For a smooth non-linear estimator the identity holds to first order. At
`rho = 0` the factors are 2 and 0, and Fay is BRR exactly. M3 confirms this
on the survey side: `type = "BRR"` and `type = "Fay", rho = 0` give the
identical SE, 0.0476228676217971.

### F4. Size of the change for users

The old default is `1/R`; the new scale is `1/(R(1 - rho)^2)`. By algebra,
the ratio of new SE to old SE is `1/(1 - rho)`. M9 measures it on fixture A:
old SE 0.0476228676218052; new SE 0.0680326680311503 at `rho = 0.3` (ratio
1.42857142857143) and 0.0952457352436104 at `rho = 0.5` (ratio exactly 2).
Both ratios equal `1/(1 - rho)` to all printed digits. The point estimate
does not move.

## survey's Fay behaviour

### `survey:::svrepdesign.default` (M1, survey 4.5)

Line numbers are lines of `deparse()` output.

- Line 4: `rho = NULL` is a formal argument.
- Lines 10-11: `if (type == "Fay" && is.null(rho)) stop("With type='Fay' you
  must supply the correct rho")`. Also measured by CI:
  `tests/testthat/test-variance-replicate.R:1000-1009` asserts this message.
- Lines 12-14: `if (type %in% c("JK1", "JKn", "ACS",
  "successive-difference", "JK2") && !is.null(rho))
  warning("rho not relevant to JK1 design: ignored.")`. M5 ran JK1, JK2 and
  ACS, and all three raise this warning.
- Lines 15-16: `type = "other"` with a non-`NULL` `rho` warns `"rho
  ignored."`.
- Lines 80-84, the BRR branch: a supplied `scale` warns `"type='BRR' does not
  use 'scale=' argument"`; a supplied `rho` warns `"type='BRR' does not use
  'rho=' argument, you may want type='Fay'"`; then `scale <- 1/ncol(repweights)`.
- Lines 86-87: `if (type == "Fay") scale <- 1/(ncol(repweights) * (1 -
  rho)^2)`. No test of `is.null(scale)` guards it, so a supplied scale is
  overwritten. M4: `rho = 0.3, scale = 99` returns `$scale`
  0.204081632653061 and raises no warning.
- Lines 150-151: `rval <- list(type = type, scale = scale, rscales =
  rscales, rho = rho, ...)`. survey stores the `rho` it received on every
  type, including the ones it warned about. M5: `$rho` is 0.3 on BRR, JK1,
  JK2, bootstrap, ACS and other. M3: a BRR design built with no `rho` has a
  `rho` element whose value is `NULL`.
- `rscales` is honoured for Fay: no Fay line touches it, and line 130-131
  fills `rep(1, R)` only when it is `NULL`.
- The bootstrap branch (lines 88-95; lines 91-94 set its defaults) has no
  `rho` check. M5: `type =
  "bootstrap", rho = 0.3` raises no warning.

### survey does not validate `rho` (M6)

For `type = "Fay"` on fixture A (`R = 10`):

| `rho` | Result |
|---|---|
| `1` | `$scale` = `Inf` |
| `-0.2` | `$scale` = 0.06944444, accepted |
| `1.5` | `$scale` = 0.4, accepted (the same scale as `rho = 0.5`, because `(1 - 1.5)^2 = (1 - 0.5)^2`) |
| `NA_real_` | `$scale` = `NA` |
| `c(0.1, 0.2)` | a length-2 `$scale` (0.1234568, 0.15625) |
| `"a"` | error: "non-numeric argument to binary operator" |
| `0L` | `$scale` = 0.1, accepted |
| `TRUE` | `$scale` = `Inf` (`TRUE` coerces to 1) |

### `survey::as.svrepdesign()` (M1c, M7)

- Formal `fay.rho = 0` (line 2). `type` accepts `"BRR"` and `"Fay"`.
- Lines 64-79: for BRR or Fay it builds the replicates with `fay.rho`, then
  sets `type <- "BRR"` when `fay.rho == 0`, else `"Fay"`, and sets
  `scale <- 1/(ncol(repweights) * (1 - fay.rho)^2)`.
- Line 128: the result stores `rho = fay.rho`.
- M7 on fixture B (`R = 8`, `combined.weights = FALSE` in all three):

| Call | `$type` | `$rho` | `$scale` |
|---|---|---|---|
| `type = "Fay", fay.rho = 0.3` | `"Fay"` | 0.3 | 0.255102040816327 |
| `type = "BRR"` | `"BRR"` | 0 | 0.125 |
| `type = "BRR", fay.rho = 0.3` | `"Fay"` | 0.3 | 0.255102040816327 |

So a BRR object from `as.svrepdesign()` carries `$rho = 0`. A BRR object
from `svrepdesign()` carries `$rho = NULL` (M3). A BRR object from
`svrepdesign(rho = 0.3)` carries `$rho = 0.3` (M5). `from_svydesign()` must
read `x$rho` for Fay only. Otherwise a BRR import stores a non-`NULL` `rho`,
which S1 says a non-Fay design never keeps.

### surveycore today (M8, M9)

- M8: `from_svydesign()` on the fixture-B Fay object stores the keys
  weights, repweights, type, scale, rscales, mse, fpc, fpctype,
  probs_provided, visible_vars. It stores no `rho`. It stores survey's scale,
  0.255102040816327, so the imported SE (0.318786100006704) matches survey's
  (0.3187861000067). Only the `rho` key is missing.
- M9: `print()` of a Fay design shows `<survey_replicate> (FAY, 10
  replicates)` and no `rho`. The default print shows no scale either.

## Deliberate divergences from survey

The spec must record each of these as a decision, with its reason.

1. **`rho` on bootstrap warns.** survey raises nothing for `type =
   "bootstrap", rho = 0.3` (M5). S1 makes surveycore warn for every non-Fay
   type, bootstrap included.
2. **`rho` on a non-Fay type is not stored.** survey keeps `$rho` on the
   object for every type (M5). S1 makes surveycore discard it, so the
   stored key is `NULL`.
3. **`rho` is validated.** survey accepts any value that survives the
   arithmetic (M6). surveycore requires a single finite number in `[0, 1)`
   (D6, request).
4. **No warning when nothing was supplied (D8).** survey's `rho` warnings
   fire only on a non-`NULL` `rho` (lines 12-16, 82-83), so there is no
   divergence for `rho`. D8 matters for `scale` and `rscales`, which S2
   leaves with issue #255.

Where surveycore agrees with survey: `rho` is required for Fay; the Fay
scale formula; a supplied Fay `scale` is discarded with no warning (S2, M4);
`rscales` is honoured for Fay.

## Places in R/ that must change

| File | Location | Change |
|---|---|---|
| `R/core-constructors.R` | signature, lines 754-775 | add `rho = NULL`. Argument order puts it with the optional scalars; after `type` or next to `scale` is a spec choice |
| `R/core-constructors.R` | lines 833-866 | validate `rho`; Fay: require it, compute `1/(n_rep * (1 - rho)^2)`, discard a supplied `scale` with no warning (S2). Other types: warn and set `rho` to `NULL` when supplied (S1, D8). The Fay override must run even when `scale` is not `NULL`, so it cannot stay inside the `if (is.null(scale))` switch |
| `R/core-constructors.R` | lines 870-880 | add the `rho` key to `variables`, `NULL` for non-Fay |
| `R/core-constructors.R` | roxygen 595-645 | `@param rho`; `@param scale` Fay line (604-605) now says Fay's scale comes from `rho` and a supplied one is discarded; `@param type` Fay entry |
| `R/core-constructors.R` | lines 737-739 | correct the Judkins citation to *Journal of Official Statistics* 6(3), 223-239 (1990) |
| `R/core-classes.R` | roxygen 583-610 | list `rho` under `@variables` for `survey_replicate` |
| `R/core-classes.R` | lines 650-652 | correct the Judkins citation, as above |
| `R/core-classes.R` | validator 669- | has no key list; no forced change. Whether to validate `rho` here is open |
| `R/methods-conversion.R` | lines 370-447 | delete the inversion (378-447 and its comments); pass `x@variables$rho`; restate CB-4 for an absent or `NULL` `rho` on a Fay design (S3) |
| `R/methods-conversion.R` | line 495 | `rho = rho_arg` stays, fed from `@variables$rho` |
| `R/methods-conversion.R` | lines 1012-1023 | `from_svydesign()` replicate route: add `rho`, read from `x$rho` when `x$type` is `"Fay"`, `NULL` otherwise (M7) |
| `plans/error-messages.md` | row CB-4 (line 533) | restate trigger and template per S3; add rows for the new error(s) and the new warning |
| `NEWS.md` | lines 215-221 | this entry describes the inversion. It sits under "development version", so the inversion never reached a release. Rewrite this entry in place, rather than add a second entry that reverses it |
| `DESCRIPTION` | line 19 | the Fay claim becomes true; no text change needed unless the spec wants one |
| `vignettes/creating-survey-objects.Rmd` | line 299 and line 874 | both name an argument `fay_rho` that does not exist. Documentation error, in scope for this work (orchestrator). Change to `rho` |
| `man/as_survey_replicate.Rd` | line 43 (Fay `1/R` text), line 197 (JASA citation) | rebuilt by `devtools::document()` from the roxygen above; never hand-edited |
| `man/survey_replicate.Rd` | `@variables` list, Judkins citation | rebuilt by `devtools::document()` |
| `CLAUDE.md` | line 89, the `archive/svydesign-replicate-bridge/` note | says `as_svydesign()` "recovers Fay's shrinkage factor from the recorded scale". False after this work |
| `R/methods-print.R` | lines 397-404 (print, full view) and line 825 (`summary()`) | the two `Scale:` lines for a `survey_replicate`. Line 659 is a third `Scale:` line, but it is in the `survey_nonprob` print, which never holds a Fay design |

Files checked that need **no** change:

- `R/variance-replicate.R`: no type branch (F2, M2).
- `as_survey()`: builds Taylor `@variables`; no replicate keys.
- `as_survey_twophase()` (`R/core-constructors.R:1198-1204`): copies
  `phase1@variables` whole, so a Fay phase 1 carries `rho` with no edit.
- `as_survey_nonprob()` (lines 1675-1724): refuses `type = "Fay"`
  (`surveycore_error_type_unsupported_for_nonprob`, pinned at
  `tests/testthat/test-constructors.R:3443`). Whether its two `variables`
  lists gain a `rho = NULL` key for uniformity is a spec choice.
- `update_design()` (`R/update-design.R:166-213`): copies `x@variables` and
  edits `weights` and `repweights` only, so `rho` survives. It does not
  recompute `scale` when the replicate count changes; that is true today for
  every type and is not new.
- `.get_design_vars()` (`R/utils.R:510`): column names only; `rho` is a
  scalar and is not a design column.
- `R/glm-anova.R:942`: reads `type` only.

## Places in tests/ and rules that move (for the planner)

These are not builder inputs, but the plan's write surface must hold them.

- `tests/testthat/helper-test-data.R` `test_invariants()` (line 679): it
  checks no replicate key at all. The only key loop (line 743) is for
  `survey_nonprob`. So no edit is forced. `impact.md` assumed a replicate key
  list exists; it does not.
- Every call of `as_survey_replicate(type = "Fay")` with no `rho` will error
  after the change:
  - `tests/testthat/test-constructors.R:1003`, `stored("Fay")`, in the
    nine-type default table block.
  - `tests/testthat/test-conversion.R:2413` (X-9, recovers `rho = 0` from the
    default scale): the premise dies; the block retires or is rewritten.
  - `tests/testthat/test-conversion.R:2447` (X-10, `scale = 0.05`, refused as
    unrecoverable): the premise dies twice, since the scale is discarded and
    no inversion exists.
  - `tests/testthat/test-conversion.R:2482` (X-11, no scale key): stays a
    reachable refusal, but the message and the reason change under S3.
  - `tests/testthat/test-conversion.R:2651` (X-17, all nine types through
    `make_rep_type()`): the Fay pass needs a `rho`.
  - `tests/testthat/test-variance-replicate.R:1015` (the sanctioned Fay
    block): becomes the oracle comparison.
- `tests/testthat/_snaps/conversion.md:72-92`: two CB-4 snapshots whose text
  changes.
- `.claude/rules/testing-surveycore.md`: the "Sanctioned exceptions" section
  and its Fay bullet retire. The per-type table's Fay row already reads
  `1/(R * (1 - rho)^2)`, "discard, no warning", "honoured"; M4 confirms it,
  and it stays. The bullet's "surveycore has no `rho` argument" becomes
  false.

## Gotchas

- **`rho` absent for Fay.** survey stops with a bare error (M1 lines 10-11).
  surveycore must raise a typed error that names `rho` (request).
- **`rho = 0`.** Legal. The scale is `1/R` and Fay equals BRR (M3). survey
  accepts it: its check is `is.null(rho)` only.
- **`rho` near 1.** The scale grows as `1/(1 - rho)^2`: 10 at `rho = 0.9`
  with `R = 10` (M2), and 10^6/R at 0.999. The formula stays correct. The
  floating-point difference against survey stays a fixed fraction of the SE,
  about 1.69e-13 (M2), so it is not amplified beyond the SE itself.
  `rho = 1` gives an infinite scale in survey (M6); the
  request's `[0, 1)` excludes it.
- **`rho < 0` or `rho > 1`.** survey accepts both (M6). `rho = 1.5` gives the
  same scale as `rho = 0.5`, so an out-of-range value can look plausible.
  surveycore refuses (divergence 3).
- **Type of `rho`.** `0L` is numeric and survey accepts it (M6). `TRUE` gives
  survey an infinite scale; `is.numeric(TRUE)` is `FALSE`, so a numeric check
  refuses it. `NA_real_` and `Inf` are numeric and not finite. A length-2
  vector gives survey a length-2 scale; refuse it.
- **Wrong `rho`.** surveycore does not build replicate weights; it trusts the
  caller's `rho` to match the value that built the columns. A wrong `rho`
  scales every SE by `(1 - rho_true)/(1 - rho_given)`, silently. The ratio
  `repwt / wt` would sit in `{rho, 2 - rho}` for raw Fay weights, but not
  after raking, so a general check is not possible.
- **Supplied `scale` with Fay.** Discarded with no warning (S2, D7, M4). A
  user who worked round the old defect by passing `scale = 1/(R(1-rho)^2)`
  with `type = "Fay"` now gets the missing-`rho` error and must add `rho`.
  The result is then unchanged if their scale was right.
- **`rho` on a non-Fay type.** Warn and set it to `NULL` (S1). No warning
  when the caller passed no `rho` (D8). Divergences 1 and 2 apply.
- **`rscales` with Fay.** Honoured, as in survey. The final variance is
  `scale * sum(rscales * dev^2)`.
- **`mse`.** Changes only the centre of the deviations. It does not interact
  with `rho`: M2 agrees to 1e-14 at both values.
- **Degrees of freedom.** Not affected. surveycore sets `degf <- Inf` in the
  Phase 1 analysis files and survey's `confint()` defaults to `df = Inf`
  (oracle rule, `.claude/rules/testing-surveycore.md`). The CI bounds inherit
  the SE change only; M2's bound differences track its SE differences.
- **Designs with no stored `rho` (S3).** Two sources:
  1. A `survey_replicate` saved (for example with `saveRDS()`) by a build
     before this change. Its `@variables` has no `rho` key.
  2. The exported `survey_replicate()` constructor, whose `variables` list is
     untyped (X-11 builds one today).
  In both, `x@variables$rho` is `NULL`. `$` does partial matching on lists,
  but no current key starts with `rho`, so `NULL` is the result.
  `as_svydesign()` refuses them (S3). The analysis functions do not: a
  legacy Fay object keeps its stored `1/R` and keeps returning BRR-sized
  SEs with no condition (M9: stored scale 0.1). See Open questions.
- **Release history.** The inversion of PR #250 is listed under
  "development version" in `NEWS.md`, so no release carried it. In every
  released version, `as_svydesign()` on a Fay design failed with survey's
  bare "you must supply the correct rho" error. The S3 refusal replaces a
  failure every release already had.
- **Two-phase with a Fay phase 1.** `phase1@variables` is copied whole, so
  `rho` rides along. The two-phase export route goes through
  `survey::twophase()`, not `svrepdesign()`, so it never reads `rho`.
- **`from_svydesign()` on a survey object.** The import already gives the
  right SE, because it copies survey's scale (M8). A BRR object from
  `as.svrepdesign()` carries `$rho = 0`, and a BRR object from
  `svrepdesign(rho = )` carries the supplied value (M5, M7). The route must
  store `x$rho` for Fay only. A survey Fay object can also carry a `rho`
  surveycore would refuse (M6), for example `1.5`.
- **Empty, single-row, all-NA, zero-weight, single-level.** None of these
  touch `rho`. They reach the same constructor checks as every type
  (`.validate_data_frame()` refuses a single-row frame before the scale is
  computed; see `archive/replicate-scale-jkn-bootstrap/` E-7). A zero-weight
  row stays zero-weight in every replicate and adds nothing to any
  deviation. A single replicate column gives a finite Fay scale
  `1/(1-rho)^2`, unlike bootstrap's `1/(R-1)`.
- **Degenerate strata.** Not reachable: surveycore reads no strata for a
  replicate design.

## Reference mapping

- Judkins (1990) *Journal of Official Statistics* 6(3) 223-239 (citation
  confirmed; content recalled) → the `(1 - rho)^2` divisor and the
  `rho = 0` equals BRR identity (F3).
- `survey:::svrepdesign.default` lines 10-11 (M1) → `rho` is required for
  Fay; surveycore raises a typed error in place of survey's bare one.
- `survey:::svrepdesign.default` lines 86-87 (M1) → the Fay scale formula,
  and the silent discard of a supplied Fay `scale` (S2, M4).
- `survey:::svrepdesign.default` lines 12-16 and 82-83 (M1, M5) → survey
  warns on `rho` for every non-Fay type except bootstrap. S1 goes further
  (divergence 1).
- `survey:::svrepdesign.default` lines 150-151 (M1, M5) → survey keeps
  `rho` on every type. S1 discards it (divergence 2).
- `survey:::svrVar` (M1b) → the engine is type-blind on both sides (F2).
- `survey::as.svrepdesign` lines 64-79 and 128 (M1c, M7) → `from_svydesign()`
  reads `x$rho` for `type = "Fay"` only.
- D7 table, `rho` column → confirmed for BRR, JK1, JK2, ACS and other by M5.
  D7 lists bootstrap as "—", which matches M5's silence.
- D8 → no warning when the caller supplied no `rho`.
- D10 → the export route passes `rho` from `@variables$rho`; the inversion at
  `R/methods-conversion.R:378-447` retires (D10 says 171-235; the lines have
  moved since).
- `plans/error-messages.md` CB-4 as it reads today (line 533): trigger
  "`@variables$type` is `"Fay"` and the recorded scale is missing,
  non-finite or non-positive, or yields a shrinkage factor outside
  `[0, 1)`"; class `surveycore_error_fay_rho_unrecoverable`; template
  `"x" = "{.fn as_svydesign} cannot recover the {.val Fay} shrinkage factor
  for this design."`, `"i" = "{.fn survey::svrepdesign} requires {.arg rho}
  for {.code type = \"Fay\"}, and surveycore derives it from the recorded
  scale."`, `"i" = "The recorded scale is {.val {scale_txt}} and yields no
  value in {.code [0, 1)}."`, `"v" = "Rebuild the design with
  {.fn as_survey_replicate} and pass the {.arg scale} the {.val Fay}
  replicates were built with."`. S3 keeps the class and restates the
  trigger as "absent or `NULL` `@variables$rho`"; the `"v"` bullet names
  `as_survey_replicate(rho = )`. The second `"i"` bullet and `scale_txt`
  have no meaning after the change.
- `.claude/rules/testing-surveycore.md` per-type table, Fay row → the
  oracle's expected survey behaviour; M4 confirms it.
- `.claude/rules/testing-surveycore.md` "Sanctioned exceptions" → names
  issue #243 as the closing issue; retires with this work.
- `tests/testthat/test-variance-replicate.R:975-1022` → the block that
  becomes the Fay oracle. It already carries fixture A, on which M2 agrees.
- `tests/testthat/test-conversion.R` X-8 and X-13 → CI evidence that survey
  stores `$rho` and that the import and export routes reproduce survey's
  Fay SE.

## Assumptions

- The replicate columns already hold Fay weights built with the `rho` the
  caller passes. surveycore neither builds nor checks them.
- `R` in the scale is the number of replicate columns, the same count survey
  uses (`ncol(repweights)`, M1 line 87). For a design imported from a
  compressed survey matrix, `from_svydesign()` expands to the full column
  count first.
- The Fay design is a two-PSU-per-stratum BRR layout with Hadamard-balanced
  half samples. surveycore cannot see this and does not check it; the
  variance formula assumes it.
- `rho` is one number for the whole design. survey supports no per-replicate
  `rho`.
- The identity in F3 is exact for linear estimators (totals) and first-order
  for ratios and means. Both sides of the oracle use the same formula, so
  the test agrees to machine precision either way (M2).

## Open questions

- **Legacy objects in analysis.** S3 refuses a `rho`-less Fay design on
  export only. `get_means()` and the other analysis functions keep using its
  stored `1/R` with no condition, so a saved legacy object keeps returning
  the old, too-small SE. Should analysis warn? Not settled by S1 to S3.
- **Validation in the class validator.** Should `survey_replicate`'s
  validator check `rho` (type `"Fay"` needs a valid `rho`; others need
  `NULL`)? That would also refuse a legacy object at read time, which
  conflicts with S3's plan to refuse at export. The constructor check alone
  leaves the exported `survey_replicate()` route open.
- **Consistency of `scale` and `rho`.** After construction, `scale` equals
  `1/(R(1-rho)^2)`. A `survey_replicate()` call or an `@variables` edit can
  break that. Export passes `rho` only, and survey overwrites the scale from
  `rho` (lines 86-87), so the exported SE can differ from surveycore's.
  Check at export, or accept?
- **Imported `rho`.** Should `from_svydesign()` apply the constructor's
  `[0, 1)` check to a survey Fay object's `$rho`? survey accepts values such
  as `1.5` (M6).
- **Argument position of `rho`.** Before or after `scale`. A spec choice.
- **Print.** Show `rho` for Fay designs, or not (M9: not shown today).
- **`as_survey_nonprob()` keys.** Add `rho = NULL` to its `variables` lists
  for uniformity, or leave them (nonprob refuses Fay).

## Conflicts for the orchestrator

Resolved by the orchestrator on 2026-09-30:

- Judkins citation: the correct one is *Journal of Official Statistics*
  6(3), 223-239 (1990). The JASA 85(410) citation at
  `R/core-constructors.R:737-739` and `R/core-classes.R:650-652` is wrong;
  the spec corrects it.
- Vignette `fay_rho`: a documentation error in scope for this work,
  `vignettes/creating-survey-objects.Rmd` lines 299 and 874.
- D7's `rho` column: M5 confirms it. The divergences from S1 are recorded
  above under "Deliberate divergences from survey".

Still open:

1. **`test_invariants()` has no replicate key list.** `impact.md` lists
   `tests/testthat/helper-test-data.R` to extend that list. Only the
   `survey_nonprob` branch has one (line 743). Adding a replicate list would
   be a new invariant, not an edit.
2. **`NEWS.md` entry for PR #250 is unreleased.** The request says "record
   the moved standard errors and the new error". The existing entry at
   `NEWS.md:215-221` describes the inversion this work deletes, in the same
   unreleased section. Rewriting it is cleaner than adding a reversal; the
   request does not say which.
3. **The vignette is outside `impact.md`'s write surface.** Now in scope, so
   the file count in `impact.md` (about 12) goes up by one.
4. Closed: adversarial verification ran on 2026-09-30 with two independent
   verifiers. Their four findings (the floating-point claim in F2 and its
   gotcha, the bootstrap line range, the JKn hedge, four missed sites) are
   fixed in this revision.
