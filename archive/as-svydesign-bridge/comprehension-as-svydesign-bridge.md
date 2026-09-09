# Comprehension — as-svydesign-bridge

**Paths rewritten at archive time.** Two citations named this document's
sources by their run-directory paths, which the archive move retired. They
now name `request.md` and `measurements-as-svydesign-bridge.md`, both
beside this file in `archive/as-svydesign-bridge/`. No document was lost
and no other text changed.

Sources read in full: `request.md`,
GitHub issues #198 and #237, `R/methods-conversion.R`, `R/core-constructors.R`,
`R/variance-replicate.R`, `R/variance-taylor.R`, `R/analysis-means-helpers.R`,
`R/analysis-helpers.R`, `R/core-validators.R`, `R/utils.R`,
`plans/error-messages.md`, `tests/testthat/test-conversion.R`, and the `survey`
package source (`R/surveyrep.R`, `R/multistage.R`, `R/confint.R`) from the CRAN
mirror `cran/survey` at `master`.

Measured and derived evidence:
`measurements-as-svydesign-bridge.md`.
Items are cited below as M1, M2, M3 (given by the issues) and D1 to D4 (derived
from quoted source). That file also records the session limit: no shell was
available, so nothing new was executed.

## Problem

`as_svydesign()` hands a surveycore design to the `survey` package. Two of its
four paths are wrong. First, a replicate design that names an FPC column always
fails, because surveycore stores the FPC as one value per row and
`survey::svrepdesign()` wants one value per replicate (M2). The two shapes are
not just different lengths. They correct for different things, so no reshape is
automatically right. Second, `as_svydesign()` refuses a `survey_nonprob` design
with a message that says it is not a survey design object, which is false: the
class inherits `survey_base`. A nonprob design holds weights, and it can hold
replicate weights, so both shapes have a natural target in `survey`. The route
picks the variance estimator, so the bridge has to route on the same key that
surveycore's own analysis code routes on (M1). Around both defects sits a
documentation and register problem: five roxygen lines describe the old
behaviour, and the error class the refusal raises is missing from
`plans/error-messages.md`.

## Formulas

### F1 — Replicate variance, in both packages

surveycore, `R/variance-replicate.R:46`:

```r
sum((thetas - meantheta)^2 * rscales) * scale
```

survey, `svrVar`, scalar branch:

```r
    v<- sum( (thetas-meantheta)^2*rscales)*scale
```

The same expression, term for term.

| Symbol | Meaning | Bound to |
|---|---|---|
| `theta_r` | estimate from replicate r | `thetas[r]`; surveycore builds it from `@data[, @variables$repweights]` |
| `R` | replicate count | `length(x@variables$repweights)` |
| `centre` | deviation centre | `coef` when `@variables$mse` is `TRUE`, else `mean(thetas[rscales > 0])` |
| `rscales_r` | per-replicate scale | `x@variables$rscales`, or `rep(1, R)` when `NULL` (`R/variance-replicate.R:92`) |
| `scale` | overall scale | `x@variables$scale`; the type-specific default is set at `R/core-constructors.R:791-807` |
| `V` | variance of the estimate | the value of the expression above |

### F2 — What `svrepdesign()` does with an `fpc`

The whole block, verbatim from `svrepdesign.default`:

```r
  if (!is.null(fpc)){
      if (missing(fpctype)) stop("Must specify fpctype")
      fpctype<-match.arg(fpctype)
      if (type %in% c("BRR","Fay","JK2","ACS","successive-difference"))
        stop("fpc not available for this type")
      if (type %in% "bootstrap") stop("Separate fpc not needed for bootstrap")
      if (length(fpc)!=length(rscales)) stop("fpc is wrong length")
      if (any(fpc>1) || any(fpc<0)) stop("Illegal fpc value")
      fpc<-switch(fpctype,correction=fpc,fraction=1-fpc)
      rscales<-rscales*fpc
  }
```

So, under `fpctype = "fraction"`:

```
rscales_r' = rscales_r * (1 - f_r)
V' = (1 - f) * V            when f is constant
SE' / SE = sqrt(1 - f)      when f is constant
```

| Symbol | Meaning | Bound to |
|---|---|---|
| `fpc` (survey) | one value per replicate | the vector `.as_svydesign_replicate()` passes; today `x@data[[fpc_var]]`, length `nrow(@data)` (`R/methods-conversion.R:156`) |
| `fpctype` | how to read `fpc` | `x@variables$fpctype`, or `"fraction"` when the key is absent (`R/methods-conversion.R:135-139`) |
| `f_r` | sampling fraction charged to replicate r | no surveycore field holds this; see G2 |
| `rscales` | per-replicate scale | `x@variables$rscales`, already filled to `rep(1, R)` by survey before this block (D4) |
| `scale` | overall scale | `x@variables$scale`, untouched by the block |

What it corrects for: the replicate FPC shrinks each replicate's contribution
to the variance. It is a scale factor on an already-formed resampling variance.
It says nothing about any row.

### F3 — What `svydesign()` does with a per-row `fpc`

Two steps. `as.fpc` turns the column into a population size per stratum:

```r
  if (ispopsize){
    ...
    popsize<-fpc
  } else {
    popsize<-sampsize/(fpc)
  }
```

`ispopsize` is `any(df > 1)`; the function refuses a mix
(`stop("Must have all fpc>=1 or all fpc<=1")`). Then `onestrat` forms the
correction:

```r
  if (is.null(fpc))
      f<-rep(1,NROW(x))
  else{
      f<-ifelse(fpc==Inf, 1, (fpc-nPSU)/fpc)
  }

  if (nPSU>1)
      scale<-f*nPSU/(nPSU-1)
  else
      scale<-f
  ...
      return(crossprod(x*sqrt(scale)))
```

```
f_h = (N_h - n_h) / N_h = 1 - n_h/N_h
scale_h = f_h * n_h / (n_h - 1)
V = sum_h crossprod(u_h * sqrt(scale_h))
```

| Symbol | Meaning | Bound to |
|---|---|---|
| `N_h` | population PSU count in stratum h | `popsize` from `as.fpc`; the per-row column `@data[[@variables$fpc]]` supplies it directly or as a fraction |
| `n_h` | sampled PSU count in stratum h | `nPSU`, counted from `@variables$ids` inside the stratum |
| `u_h` | influence-function totals per PSU in stratum h | built from `@variables$weights` and the outcome column |
| `f_h` | the correction | `1 - n_h/N_h` |

What it corrects for: the FPC removes the part of the between-PSU variance that
does not exist, because the sample covers a known share of a finite stratum. It
is a per-stratum property of the sampling stage, read off per-row data.

surveycore's own Taylor estimator applies the identical formula. Vendored at
`R/variance-taylor.R:38`:

```r
    f <- ifelse(fpc == Inf, 1, (fpc - nPSU) / fpc)
```

So the same stored field, `@variables$fpc`, is honoured on `survey_taylor` and
inert on `survey_replicate` (D3).

### F4 — Degrees of freedom

```r
degf.survey.design2<-function(design,...){
  inset<- weights(design,"sampling")!=0
  length(unique(design$cluster[inset, 1])) - length(unique(design$strata[inset, 1]))
}
degf.svyrep.design<-function(design,tol=1e-5,...){
  ...
  rval<-design$degf ##cached version
  if(is.null(rval))
    rval<-qr(weights(design,"analysis"), tol=1e-5)$rank-1
  rval
}
```

`svrepdesign.default` calls `rval$degf<-degf(rval)` at construction, so the
`qr` branch runs once and the value is cached on the object.

For a 40-row nonprob design, all weights positive (D2):

| Object | df |
|---|---|
| surveycore `survey_nonprob`, either shape (`R/analysis-helpers.R:1096`) | `Inf` |
| converted `survey.design2`, plain shape | 39 |
| converted `svyrep.design`, replicate shape, 8 columns | 7 |

`confint.svystat` and `confint.svrepstat` both default to `df = Inf`, so the
default interval from `survey::svymean()` matches surveycore's. The gap appears
only when the caller passes `df = degf(design)`, or calls a survey function
that reads `degf()` itself. Two-sided 95% quantiles: 1.959964 at `Inf`,
2.022691 at 39, 2.364624 at 7 (D2).

### F5 — What the SRS approximation computes

`.calibrated_mean_cell()`, `R/analysis-means-helpers.R:321`:

```r
  var_ybar <- (n_d / (n_d - 1L)) * sum(w_sub^2 * (y_sub - ybar)^2) / N_d^2
```

That is the Horvitz-Thompson linearised variance of a weighted mean under
with-replacement sampling of independent units: no clusters, no strata, no FPC,
with an `n/(n-1)` small-sample factor. It treats the calibration weights as
fixed constants, so it charges nothing for the uncertainty the weighting itself
introduced. The converted `survey.design2` from the plain shape computes the
same quantity, because `survey::svydesign(ids = ~1, weights = ~w)` reduces
`onestrat` to one stratum of `n` single-unit PSUs, with `f = 1` and
`scale = n/(n-1)`. `onestrat` also sweeps out `colMeans(x)`, and that step
changes nothing here: the contributions `z_i = w_i (y_i - ybar) / N` sum to
zero by construction, so their mean is zero.

## Repo facts the spec will need

### One error row covers four sites

All four raise the same two bullets, byte for byte:

```r
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
```

| Site (current file state) | Function | Guard |
|---|---|---|
| `R/methods-conversion.R:83-89` | `as_svydesign()` | the `else` of the dispatch chain |
| `R/methods-conversion.R:266-272` | `as_tbl_svy()` | `!S7::S7_inherits(x, survey_base)` |
| `R/utils.R:258-264` | `survey_data()` | `!S7::S7_inherits(x, survey_base)` |
| `R/utils.R:322-328` | `survey_weighting_history()` | `!S7::S7_inherits(x, survey_base)` |

Issue #237 cites these as lines 88, 271, 243 and 307. The first two match; the
`utils.R` pair has moved by 20 lines since the issue was written.

### `plans/error-messages.md` row format

Column order, used by every table in the file:

```
| # | Function | Condition | Level | Error Class | cli Message Template |
```

Numbering: the original table runs to 102, with letter suffixes in use (`11b`,
`13b`, `23b`). Every feature since then adds a dated subsection,
`### {slug} rows (YYYY-MM-DD)`, with its own ID prefix. Prefixes already taken:
`M`, `A`, `T`, `P`, `S`, `D`, `V`, `CV`, `PC`, `EN`, `HI`, `RC`, `FA`, `PP`,
`NB`, `CAL`, `SCR`, `DF`, `DM`. `CV` is covariance, not conversion. A new
conversion block needs a free prefix. A grep for lines that begin with a pipe
returns 340, which includes each table's header and separator.

`surveycore_error_not_survey_object` appears nowhere in the file. A grep for it
returns zero hits. The only near neighbour is row 78 at line 118, a different
class for a different guard:

```
| 78 | `infer_question_prefaces()` | `x` is not a survey object or data frame | ERROR | `surveycore_error_not_survey_or_df` | `"{.arg x} must be a survey design object or a data frame, not {.cls {class(x)[[1L]]}}."` |
```

### `tests/testthat/test-conversion.R` today

- No file-level `skip_on_cran()`. The header comment at line 7 states the
  policy: "All blocks that exercise survey/srvyr use `skip_if_not_installed()`."
- `skip_if_not_installed("survey")` appears in every block. Blocks that also
  need srvyr add `skip_if_not_installed("srvyr")`: the `as_tbl_svy()` pair, the
  `from_tbl_svy()` pair, and the labelled round-trip block.
- `test_invariants(d)` is called at lines 121, 754 and 1157.
- No `expect_snapshot()` call anywhere in the file, and no
  `tests/testthat/_snaps/conversion.md` exists. The two Layer 3 refusals are
  tested by class only, at lines 285 and 316. Block titles:
  "as_svydesign() rejects a plain data.frame" and
  "as_tbl_svy() rejects a plain data.frame".
- No block mentions `nonprob`. There is no nonprob coverage on either bridge
  direction.
- Fixtures, at lines 61-113: `make_taylor()` (names an `fpc` column),
  `make_srs()`, `make_rep()` (`type = "BRR"`, no `fpc`),
  `make_twophase()`. So no existing block converts a replicate design that
  carries an FPC, which is why #198 survived.

### The seven roxygen lines, quoted from the current file

| Line | Current text |
|---|---|
| 33 | `#' Converts a `survey_taylor`, `survey_replicate`, or `survey_twophase` object` |
| 41 | `#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.` |
| 42 | `#' @return A `survey::svydesign`, `survey::svrepdesign`, or `survey::twophase`` |
| 217 | `#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.` |
| 218 | `#'   `survey_nonprob` is not supported and will error.` |
| 344 | `#' @return A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.` |
| 535 | `  subset_var <- .find_col_by_value(phase1_data, as.numeric(x$subset))` |

Lines 33, 41, 42, 217, 218 and 344 match issue #237 exactly. Line 535 does not.
The issue calls 535 the `from_tbl_svy()` `@return`; that line now sits at 588
and reads
`#' @return A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.`.
PR #239 added lines inside `.from_svydesign_replicate()`, which sits above
`from_tbl_svy()`, and shifted everything after it. Line 33 continues into 34-36,
and line 42 continues into 43-46, so the spec should state whole blocks rather
than single lines.

### The nonprob design's fields

`as_survey_nonprob()` builds `@variables` in two branches,
`R/core-constructors.R:1610-1623` (replicate shape) and 1646-1659 (plain shape).

| Key | Replicate shape | Plain shape |
|---|---|---|
| `weights` | the resolved column | the resolved column |
| `repweights` | the resolved columns | `NULL` |
| `type` | one of `bootstrap`, `JK1`, `JK2`, `JKn` | `NULL` |
| `scale` | type default or user value | `NULL` |
| `rscales` | always non-`NULL`; defaults to `rep(1, R)` at line 1539-1541 | `NULL` |
| `mse` | `isTRUE(mse)` | `NULL` |
| `probs_provided` | `FALSE` | `FALSE` |
| `ids`, `strata`, `fpc` | `NULL` | `NULL` |
| `nest` | `FALSE` | `FALSE` |
| `visible_vars` | `NULL` | `NULL` |

There is no `fpctype` key in either branch. `.as_svydesign_replicate()` guards
that with `is.null()` at `R/methods-conversion.R:135-139` and substitutes
`"fraction"`, so a missing key raises nothing. The substituted value is never
read either, because `fpc` is `NULL` on every nonprob design, so survey's fpc
block does not run.

### The dispatch surveycore itself uses

`R/analysis-means-helpers.R:351-370`:

```r
  } else if (S7::S7_inherits(design, survey_nonprob)) {
    if (!is.null(design@variables$repweights)) {
      .replicate_mean_cell(design, y_col, domain)
    } else {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.cls survey_nonprob} object has no bootstrap replicate ",
            "weights. Standard errors use an SRS approximation that ",
            "underestimates calibration uncertainty."
          ),
          "i" = paste0(
            "Run {.fn surveywts::create_bootstrap_weights} on this ",
            "design for correct SEs."
          )
        ),
        class = "surveycore_warning_nonprob_srs_fallback"
      )
      .calibrated_mean_cell(design, y_col, domain)
    }
```

The class is already in the register, as row NB-2 of
`plans/error-messages.md:305`, with the same two bullets.

## Gotchas

- **G1 — The FPC means two different things, so no reshape is neutral.** On the
  Taylor side the FPC is a per-stratum sampling-stage property, read per row,
  and it enters as `1 - n_h/N_h` inside each stratum's contribution (F3). On
  the replicate side it is a scalar multiplier on an already-formed resampling
  variance, one per replicate (F2). Making the length fit does not make the
  quantity right. The length error the user sees today is the smaller half of
  the defect.

- **G2 — A replicate design carries no map from a row to a replicate.** Its
  `@variables` list holds nine keys and none of them is `ids` or `strata`
  (`R/core-constructors.R:811-821`, and `R/utils.R:521-528` takes the same
  view). So a varying FPC column cannot be reduced to one value per replicate
  by any rule the object supports. Only a constant column has an unambiguous
  reduction, `rep(f, R)` (D1).

- **G3 — Five of the nine replicate types refuse an FPC, and a sixth refuses it
  with a different message.** survey rejects `BRR`, `Fay`, `JK2`, `ACS` and
  `successive-difference` with `"fpc not available for this type"`, and
  `bootstrap` with `"Separate fpc not needed for bootstrap"`. Only `JK1`, `JKn`
  and `other` accept one (D4). surveycore accepts an `fpc` argument with all
  nine: `.validate_fpc()` (`R/core-validators.R:240-276`) checks existence and
  `NA` only, with no type gate and no range check. The default fixture in the
  test file is `BRR` (line 92), which is a refusing type. Note the check order:
  the type checks run before the length check, so a `BRR` design with an FPC
  reports "fpc not available for this type", not "fpc is wrong length".

- **G4 — surveycore's replicate estimator never reads the FPC, so the bridge
  can disagree with the package that owns it.** `R/variance-replicate.R`
  contains zero occurrences of `fpc`, and every read of `@variables$fpc` in
  `R/` belongs to a validator, a printer, the Taylor route, or the bridge
  itself (D3). If the bridge passes an FPC, the converted object reports an SE
  `sqrt(1 - f)` times surveycore's own SE for the same design: 2.5321% lower at
  `f = 0.05` (D1). The constructor's documentation already promises otherwise.
  `R/core-constructors.R:610-612` says the `fpc` column is "Used by some
  replicate methods to adjust the variance estimator". No surveycore code
  applies it.

- **G5 — The Taylor helper accepts a replicate-shaped nonprob design and
  silently loses the replicate role.** `.as_svydesign_taylor()` reads only
  `ids`, `strata`, `weights`, `fpc` and `nest`
  (`R/methods-conversion.R:96-125`). On a nonprob design the first four are
  `NULL`, so it builds `svydesign(ids = ~1, weights = ~w)`. The replicate
  columns stay in the data as ordinary columns and stop being replicate
  weights. Nothing errors, nothing warns, and `svymean()` answers with the SRS
  approximation instead of the replicate variance. Measured at an order of
  magnitude apart on a 40-row design: 1.8210856321 against 0.2434150530 (M1).

- **G6 — The plain shape breaks the replicate helper for a reason worth
  knowing.** `.as_svydesign_replicate()` on a plain nonprob design passes
  `repweights = x@data[, NULL, drop = FALSE]`, a zero-column frame. survey then
  computes `repwtmn<-mean(apply(repweights,2,mean))`, which is `NaN`, and runs

  ```r
  probably.not.combined.weights<-(repwtmn<5) & (wtmn/repwtmn>5)
  if (combined.weights & probably.not.combined.weights)
  ```

  `TRUE & NA` is `NA`, and `if (NA)` raises
  `Error: missing value where TRUE/FALSE needed` (M1). So a single-helper
  route is not available: each helper works only on the shape it should serve.

- **G7 — The round trip loses more than the class.** Neither
  `.from_svydesign_taylor()` nor `.from_svydesign_replicate()` calls
  `as_survey_nonprob()`, and neither passes a `calibration` argument
  (`R/methods-conversion.R:432-436` and 519-523). A `survey` object records
  nothing that marks the sample as non-probability. So the round trip returns
  `survey_taylor` or `survey_replicate`, and drops the `survey_nonprob` class,
  the `@calibration` provenance and the `@reference_sample`. The next
  `get_means()` call then reports design-based SEs with no SRS-fallback
  warning, on data that has not changed. The variance settings do survive the
  replicate round trip: `type`, `scale`, `rscales` and `mse` are read back off
  the survey object.

- **G8 — `.from_svydesign_replicate()` already drops the FPC in the reverse
  direction.** It sets `fpc = NULL` and `fpctype = "fraction"`
  unconditionally, `R/methods-conversion.R:506-517`. There is nothing to read
  back either: `svrepdesign.default` makes eleven `rval$` assignments and none
  of them is `rval$fpc`, because the fpc block folded the value into `rscales`
  and recorded nothing (F2). So a full round trip cannot return the
  FPC column's role today, whatever the outbound direction does. If the
  outbound direction folds the FPC into `rscales`, the return trip brings back
  a design whose `rscales` already carry the correction and whose `fpc` key is
  `NULL`. A second outbound pass would then not double-apply it, but the
  design's own `get_means()` would report the corrected SE with no field
  saying why.

- **G9 — Adjacent, not part of this issue: `combined.weights` and JKn
  `rscales`.** The bridge passes neither `combined.weights` nor `degf`, so
  survey uses `combined.weights = TRUE`. Two consequences sit next to the FPC
  block. A `JKn` design with `rscales = NULL` hits
  `stop("Must provide rscales for combined JKn weights")` before the fpc block
  runs, another bare survey `stop()`. A `JK2` design triggers survey's warning
  `"with type JK2 scale= and rscales= are not needed and will be ignored"`,
  because the bridge always passes both for types other than BRR and Fay
  (`R/methods-conversion.R:143-147`). Issue #198 assigns the
  `combined.weights` question to the producer package (M3).

## Option cost — the FPC decision

The user chooses. Each option below lists what the converted object computes,
whether it agrees with surveycore, which types still need refusing, and what
the user loses.

### Option A — derive the per-replicate vector and pass it

- **Computes:** `V' = (1 - f) * V`, the resampling variance shrunk by the
  sampling fraction (F2). Correct as a finite-population correction only when
  the design really is a with-replacement resample of a known fraction of a
  finite population, and when that fraction is the same for every replicate.
- **Agreement with surveycore:** none. Every SE is `sqrt(1 - f)` times
  surveycore's own SE for the same design, because surveycore's estimator
  ignores the field (D1, G4). The bridge would become the only place in the
  package where the replicate FPC changes an answer. Two objects that describe
  one design would then disagree by a fixed factor.
- **Types still refused:** six of nine. `BRR`, `Fay`, `JK2`, `ACS`,
  `successive-difference` and `bootstrap` (D4). Each needs a surveycore
  condition that names `fpc` and the type, raised before the call to
  `svrepdesign()`, so survey's bare `stop()` never reaches the user.
- **Also refused:** any FPC column that is not constant, because no reduction
  rule exists (G2). And any column whose values fall outside `[0, 1]` under
  `fpctype = "fraction"`, which includes every population-size column that
  `as_survey()` documents as valid input (`R/core-constructors.R:45-47`);
  survey raises `"Illegal fpc value"` for those.
- **User loses:** the guarantee that `get_means(d)` and
  `svymean(~y, as_svydesign(d))` report the same SE. Also loses the
  varying-FPC case entirely: those designs convert today (with a bare error)
  and would convert tomorrow with a surveycore error, but never successfully.

### Option B — do not pass `fpc`, and warn that it is dropped

- **Computes:** `V`, the uncorrected resampling variance. The same quantity
  surveycore's own estimator computes (F1).
- **Agreement with surveycore:** exact, for every type and every FPC column
  shape. The bridge would then match the package's own answer by construction,
  which is what the four existing numerical round-trip blocks in
  `test-conversion.R` assert for the other design classes.
- **Types still refused:** none. With no `fpc` argument, survey's whole block
  is skipped, so all nine types convert. G9's `JKn` and `JK2` issues stay, and
  they are separate from this decision.
- **User loses:** the FPC's effect in the converted object. For a real
  finite-population replicate design the converted SEs are then conservative,
  larger than they need to be, by `1/sqrt(1 - f)`. The user also loses nothing
  they have today, because no surveycore route applies the field. The warning
  is the whole cost of honesty here: it tells the user that a field they set
  has no effect, which is true of surveycore's own estimator too.

### Option C — refuse the conversion with an error that names `fpc`

Not offered by the brief. Acceptance criterion 1 in `request.md` permits it:
"either returns a `svyrep.design` or fails with a surveycore condition class
that names `fpc`".

- **Computes:** nothing. The user gets no converted object.
- **Agreement with surveycore:** not applicable.
- **Types still refused:** all nine, whenever an FPC is present.
- **User loses:** the conversion, for every replicate design that names an FPC
  column. The workaround is `update_design()` to clear the `fpc` key, which is
  more work than Option B does for the user, for the same end state. What the
  user gains is a loud statement that surveycore has not decided what the field
  means on this class.

### The three facts that constrain the choice most

1. surveycore's replicate estimator does not read `@variables$fpc` at all (D3,
   G4). So Option A makes the bridge disagree with the package by a fixed
   `sqrt(1 - f)`, and Option B makes it agree exactly.
2. A replicate design holds no `strata` and no `ids` key (G2). So Option A is
   only definable for a constant FPC column, and the varying case has to be
   refused whatever else is decided.
3. Six of the nine replicate types refuse an FPC in survey (D4, G3), and
   surveycore's constructor accepts an FPC with all nine and never checks its
   range (G3). So Option A adds at least two new condition classes and a range
   check; Option B adds one warning class.

## Reference mapping

- `survey::svrepdesign.default`, the `fpc` block → the failure is
  unconditional, and the fix must decide a semantic, not a length. `rscales` is
  already filled to `rep(1, R)` before the length check, so the check always
  compares the row count against the replicate count (D4).
- `survey::svrepdesign.default`, the type gates → the exact list of type
  strings surveycore must refuse before calling survey, and the two distinct
  messages it must replace.
- `survey::svrVar` → the FPC enters the variance linearly through `rscales`, so
  the SE ratio is exactly `sqrt(1 - f)` and the option cost is quantifiable
  without a run (D1).
- `survey::as.fpc` and `survey::onestrat` → what a per-row FPC means on the
  Taylor side, and why `R/variance-taylor.R:38` is the same formula. Justifies
  leaving `.as_svydesign_taylor()` alone, as issue #198 states.
- `survey::degf.survey.design2` and `survey::degf.svyrep.design` → the two df
  values a converted nonprob design carries, 39 and 7 against surveycore's
  `Inf` (D2, F4).
- `survey::confint.svystat`, default `df = Inf` → the df difference does not
  change a default `confint()` result. It changes a result only when the caller
  supplies `degf(design)` or calls a survey function that reads it. This sizes
  the docs-or-warning question rather than answering it.
- `survey::svydesign.default`, the `ids = ~1` branch → each row becomes its own
  PSU and the single stratum is a column of ones. Grounds the df = n - 1 result
  and the claim in F5 that the converted plain shape computes the SRS
  approximation.
- `R/analysis-means-helpers.R:351-370` → the routing key for the nonprob
  branch, `!is.null(@variables$repweights)`, and the exact warning bullets to
  re-emit.
- `R/analysis-helpers.R:1055-1067` and `:1096` → `Inf` for nonprob, and the
  documented fact that the `get_*()` functions never call `.degf()`.
- `.claude/rules/code-style.md` §Errors and warnings → every new condition
  needs a `class=`, a row in `plans/error-messages.md` written before the code,
  and an `expect_error(class = ...)` test.
- `.claude/rules/testing-surveycore.md` §S7 error testing layers → these are
  Layer 3 constructor-style errors, so they take the dual pattern: `class=`
  plus a snapshot. The file has no snapshot yet, so the first such test creates
  `tests/testthat/_snaps/conversion.md`.

## Assumptions

- **The bridge should reproduce the estimator surveycore would have used.**
  Issue #237 states this for the nonprob branch. The four existing numerical
  round-trip blocks in `test-conversion.R` already hold the other classes to
  it. Neither the request nor the issues state it as a rule for the FPC
  decision, and Option A above breaks it.
- **A constant FPC column is the only case worth converting.** Implicit in
  #198's reproduction, which uses `rep(0.05, n)`. The varying case is the
  normal Taylor case and has no definable reduction (G2).
- **`fpctype = "correction"` is in scope.** `as_survey_replicate()` accepts it
  (`R/core-constructors.R:728`), and survey reads the vector unchanged under
  it. Neither issue mentions it. Under `"correction"` the values are already
  multipliers, so the `[0, 1]` range check still applies but the `1 - f` step
  does not.
- **The nonprob branch does not need a new warning class.**
  `surveycore_warning_nonprob_srs_fallback` exists, is registered as NB-2, and
  its bullets name `get_*()` behaviour rather than conversion. Issue #237
  offers both re-emitting it and a conversion-specific class. Either satisfies
  the request; the choice changes one row in `plans/error-messages.md` and one
  snapshot.
- **`as_tbl_svy()` needs no logic change.** Its guard is
  `S7::S7_inherits(x, survey_base)` at `R/methods-conversion.R:265`, which a
  nonprob design already passes. It starts working when `as_svydesign()` does.
  Its `@param` text at lines 217-218 still has to change.
- **The plain-shape conversion is honest only if the user knows what it
  approximates.** The converted `survey.design2` computes the same HT
  linearisation as `.calibrated_mean_cell()` (F5), and it charges nothing for
  calibration uncertainty. `survey` objects carry no marker for that, so the
  only carrier is the warning or the documentation.
- **No FPC decision changes the Taylor path.** `.as_svydesign_taylor()` passes
  the per-row column, which is the shape `svydesign()` wants (F3). Issue #198
  says the same.

## Open questions

- **Which FPC option to take.** Laid out above. This is the user's judgment
  call, and it decides how many new condition classes the spec needs: two or
  more for Option A, one for Option B, one for Option C.
- **Whether `R/core-constructors.R:610-612` gets corrected in the same PR.**
  That `@param fpc` line tells the user the column adjusts the replicate
  variance estimator. No surveycore code does that (G4). Under Option B the
  line becomes actively misleading. `impact.md` lists six files and
  `R/core-constructors.R` is not one of them, so fixing it widens the write
  surface by one file and one `man/` page.
- **Whether the df difference belongs in the warning, the docs, or nowhere.**
  The mechanism is settled: the default `confint()` is unaffected, and the gap
  reaches 1.2065x on the t quantile for an 8-replicate design when the caller
  passes `degf(design)` (F4, D2). Which of the three places to use is an
  editorial call the request does not make.
- **Whether the nonprob round-trip loss needs a warning as well as a test.**
  The request asks for a test and a doc sentence. G7 shows the loss is wider
  than the class: `@calibration` and `@reference_sample` go too, and the
  rebuilt design stops warning about the SRS approximation. Nobody has decided
  whether the inbound direction should say so.
- **Nothing was executed in this session.** No shell was available, so D1 to D4
  are derivations from quoted source rather than fresh runs. The three items a
  run must confirm are listed at the end of `measurements.md`.
