# Measurements — as-svydesign-bridge

Repo: `C:/Users/jdennen/orca/workspaces/surveycore/as_svydesign-fix`
Branch: `JDenn0514/as_svydesign-fix`, HEAD `a7a52c0`
`survey` source read: CRAN mirror `cran/survey` at `master` (issue #198 and #237
both measured against survey 4.5).
Date: 2026-09-08

## How to read this file

Each row carries one of three labels.

- **GIVEN** — a number measured by the author of issue #198 or #237. The task
  brief instructs the planner to treat these as given.
- **DERIVED** — a number that follows by algebra from source quoted in this
  file. No run produced it.
- **NOT RUN** — a number the brief asked for that this session could not
  produce.

## Session limit — no shell

The Bash tool was disabled for this session, in this agent and in any subagent
("No such tool available: Bash"). So `Rscript`, `pkgload::load_all()`, `gh` and
`grep -c` could not run. Two items in the brief asked for a fresh measurement:

1. the three-way SE table on a small synthetic JKn design (f = 0.05, 8
   replicates, 60 rows);
2. `survey::degf()` on the two converted shapes of a 40-row nonprob design.

Both appear below as DERIVED, with the source lines that force the result. Both
are exact consequences of the quoted code, not estimates. A run should still
confirm them. The test-spec is the right place to pin them, because a test that
asserts the ratio is a permanent instrument, and a one-off console run is not.

---

## D1 — The FPC scale factor on the replicate route

### The two formulas

surveycore, `R/variance-replicate.R:26-46`:

```r
.svy_rep_var <- function(thetas, scale, rscales, mse = TRUE, coef = NULL) {
  ...
  sum((thetas - meantheta)^2 * rscales) * scale
```

survey, `svrepdesign.default`, the whole `fpc` block, verbatim:

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

survey applies the same product form. From `svrVar`, the scalar branch:

```r
    v<- sum( (thetas-meantheta)^2*rscales)*scale
```

That is the same expression as `R/variance-replicate.R:46`, term for term. The
fpc block changes exactly one input to it, `rscales`.

### The algebra

Let `f` be the sampling fraction, constant across replicates, `fpctype =
"fraction"`. Then `rscales' = rscales * (1 - f)`, so:

```
V_with_fpc = scale * sum_r rscales_r * (1 - f) * (theta_r - centre)^2
           = (1 - f) * V_no_fpc
SE_with_fpc / SE_no_fpc = sqrt(1 - f)
```

`(1 - f) > 0`, so the `rscales > 0` mask that selects the centre under
`mse = FALSE` does not change either. The ratio holds for `mse = TRUE` and
`mse = FALSE`.

surveycore's own replicate estimator never reads `@variables$fpc` (see D3), so
`SE_surveycore = SE_no_fpc` for the same design.

### The table (f = 0.05, R = 8, n = 60, type = "JKn", mse = TRUE)

| Route | SE | Ratio to surveycore |
|---|---|---|
| surveycore `get_means()` on the design that names the FPC column | `S` | 1 |
| `survey::svymean()` on `svrepdesign(fpc = rep(0.05, 8), fpctype = "fraction")` | `S * 0.974679434480896` | 0.974679434480896 |
| `survey::svymean()` on the same design with no `fpc` | `S` | 1 |

`sqrt(0.95) = 0.974679434480896`. The converted object reports an SE 2.5321%
below surveycore's own SE for the same design. Label: **DERIVED**. The absolute
value `S` is **NOT RUN**; only the ratio is needed, and the ratio is exact.

### Why the per-replicate vector is not generally computable

A replicate design's `@variables` list holds no `strata` key and no `ids` key.
`R/core-constructors.R:811-821` builds it with nine keys: `weights`,
`repweights`, `type`, `scale`, `rscales`, `fpc`, `fpctype`, `mse`,
`visible_vars`. `R/utils.R:521-528` confirms the same view: for a replicate
design the design variables are `weights` and `repweights` only.

So the object carries no map from replicate `r` to the sampling unit or stratum
that replicate `r` perturbs. A per-row FPC column can be reduced to one value
per replicate only when the column is constant. When the column varies by
stratum, which is the normal Taylor case, no rule in the object recovers which
row belongs to which replicate. Label: **DERIVED** from the two source lists.

## D2 — Degrees of freedom on the two converted nonprob shapes

Design: 40 rows, `as_survey_nonprob()`, all weights positive. Replicate shape
carries 8 bootstrap columns.

### Plain shape → `survey.design2`

`.as_svydesign_taylor()` passes `ids = ~1` (`R/methods-conversion.R:102-106`,
because `@variables$ids` is `NULL`), `strata = NULL` and `fpc = NULL`.

survey, `svydesign.default`:

```r
    if (ncol(ids)==0) ## formula was ~1
      ids<-data.frame(id=1:nrow(ids))
...
    strata<-na.strata(as.data.frame(matrix(1, nrow=NROW(ids),
                                           ncol=NCOL(ids))))
```

survey, `degf.survey.design2`:

```r
degf.survey.design2<-function(design,...){
  inset<- weights(design,"sampling")!=0
  length(unique(design$cluster[inset, 1])) - length(unique(design$strata[inset, 1]))
}
```

40 distinct clusters minus 1 stratum level: **df = 39**. Label: **DERIVED**.

### Replicate shape → `svyrep.design`

`.as_svydesign_replicate()` passes no `degf` argument. `svrepdesign.default`
computes and caches the value at construction, with the second to last of its
eleven `rval$` assignments:

```r
rval$degf<-degf(rval)
```

and the method it calls is:

```r
degf.svyrep.design<-function(design,tol=1e-5,...){
  ...
  rval<-design$degf ##cached version
  if(is.null(rval))
    rval<-qr(weights(design,"analysis"), tol=1e-5)$rank-1
  rval
}
```

At the construction call `design$degf` is still absent, so the `qr` branch
runs, and the result is cached. The analysis-weight matrix is 40 x 8. Eight
linearly independent replicate columns give rank 8: **df = 7**. Collinear
replicate columns give less. Label: **DERIVED**.

The same list of eleven assignments holds no `rval$fpc`. `svrepdesign()` keeps
no separate FPC field: the fpc block folds the value into `rscales` and nothing
records that it did.

### surveycore's own figure

`R/analysis-helpers.R:1095-1096` returns `Inf` for a `survey_nonprob` design.
`R/analysis-helpers.R:1059-1061` records that the `get_*()` functions do not
call `.degf()` at all; they use `Inf` directly.

| Object | df | Source |
|---|---|---|
| surveycore `survey_nonprob`, either shape | `Inf` | `R/analysis-helpers.R:1096` |
| converted `survey.design2` (plain shape) | 39 | `degf.survey.design2` |
| converted `svyrep.design` (replicate shape) | 7 | `degf.svyrep.design` |

### How df reaches a confidence interval

survey, `R/confint.R`:

```r
confint.svystat<-function (object, parm, level = 0.95, df=Inf,...) {
  tconfint(object, parm, level,df)
}
confint.svrepstat<-confint.svystat
```

The default is `df = Inf`, so `confint(svymean(...))` on either converted
object uses the normal quantile 1.959964 and matches surveycore's default
interval. The df difference reaches a user only when the user passes
`df = degf(design)`, or calls a survey function that reads `degf()` itself
(`svyglm`, `svyttest`, `svyby` with a df argument, `svycontrast`).

Two-sided 95% quantiles, for the size of the gap when it does appear:

| df | quantile | ratio to `df = Inf` |
|---|---|---|
| `Inf` | 1.959964 | 1.0000 |
| 39 | 2.022691 | 1.0320 |
| 7 | 2.364624 | 1.2065 |

Label: **DERIVED** (standard t quantiles).

## D3 — surveycore's replicate estimator ignores `@variables$fpc`

| Instrument | Result |
|---|---|
| `Grep "fpc"` in `R/variance-replicate.R`, count mode | 0 matches |
| `Grep "variables\$fpc"` across `R/` | 16 hits in 7 files, listed below |

Every hit, with its role:

| Site | Role | Replicate route? |
|---|---|---|
| `R/core-classes.R:435` | `survey_taylor` validator, column-exists check | no |
| `R/glm.R:907` | warns when a response names a design column | no |
| `R/methods-conversion.R:100` | `.as_svydesign_taylor()` builds `fpc = ~col` | no |
| `R/methods-conversion.R:134-136` | `.as_svydesign_replicate()`, the defect | yes |
| `R/methods-print.R:279, 327, 406, 409, 781, 828, 830` | print and summary output | display only |
| `R/update-design.R:138` | writes a new `fpc` key | no |
| `R/utils.R:473, 518` | Taylor branch of the design-variable helpers | no |

No hit computes a variance. `R/variance-replicate.R:46` is the whole replicate
variance formula and it reads `scale` and `rscales` only. Label: **DERIVED**
from the two greps plus the estimator body.

A consequence worth recording: `R/utils.R:475-479` and `R/utils.R:521-528`
exclude `fpc` from a replicate design's design variables. So surveycore does
not protect a replicate FPC column from `select()` or `rename()` either. The
column is inert on this design class.

## D4 — Which replicate types accept an `fpc`

From the survey block quoted in D1, and from surveycore's own type set at
`R/core-constructors.R:714-724`.

| survey behaviour | Type strings | In surveycore's `as_survey_replicate()` set? |
|---|---|---|
| accepts `fpc` (length and range checked) | `JK1`, `JKn`, `other` | yes, all three |
| `stop("fpc not available for this type")` | `BRR`, `Fay`, `JK2`, `ACS`, `successive-difference` | yes, all five |
| `stop("Separate fpc not needed for bootstrap")` | `bootstrap` | yes |

Both sets hold the same nine strings. survey's `match.arg` vector is
`c("BRR","Fay","JK1","JKn","bootstrap","ACS","successive-difference","JK2","other")`.
surveycore's default vector is
`c("JK1","JK2","JKn","BRR","Fay","bootstrap","ACS","successive-difference","other")`.
Same nine, different order. So no surveycore type is unknown to survey, and no
`match.arg` failure can occur on this route.

surveycore's `as_survey_nonprob()` accepts a narrower set,
`c("bootstrap","JK1","JK2","JKn")` plus the alias `"jackknife"` mapped to
`"JK1"` (`R/core-constructors.R:1465-1493`). Of those four, only `JK1` would
accept an `fpc`, and a nonprob design always has `fpc = NULL`
(`R/core-constructors.R:1620` and `R/core-constructors.R:1656`).

Statement order inside `svrepdesign.default`, from the same source:

| # | Statement |
|---|---|
| 21 | `if (type == "BRR")` |
| 29 | `if (is.null(rscales)) rscales<-rep(1,NCOL(repweights))` |
| 30 | `if (!is.null(fpc)){` |

So `rscales` is always filled before the length check. `length(rscales)` equals
the replicate count `R` on every path, and the check compares the row count
against `R`. The failure is unconditional whenever `nrow(data) != R`.

## M1 — Route decides the estimator on a nonprob design (GIVEN, issue #237)

40-row nonprob design, replicate shape with 8 bootstrap columns, surveycore
1.1.0.9000, R 4.6.1, survey 4.5.

| Call | Result |
|---|---|
| `.as_svydesign_taylor()` on the plain shape | `survey.design2` |
| `.as_svydesign_taylor()` on the replicate shape | `survey.design2`, drops all 8 replicate columns from the design role |
| `.as_svydesign_replicate()` on the replicate shape | `svyrep.design` |
| `.as_svydesign_replicate()` on the plain shape | `Error: missing value where TRUE/FALSE needed` |

| Route | `SE(svymean(~y1, .))` |
|---|---|
| via `.as_svydesign_taylor()` | 1.8210856321 |
| via `.as_svydesign_replicate()` | 0.2434150530 |

Issue #237 states the gap's direction is an artefact of synthetic replicate
weights drawn tightly around the base weight. The fact it establishes is that
the route, not the data, picks the variance method.

## M2 — The FPC failure (GIVEN, issue #198)

`develop` at `0ef5442`, survey 4.5, 60 rows, 8 replicates, `type = "JKn"`,
`fpc_col = rep(0.05, 60)`.

| `@variables$fpc` | Result |
|---|---|
| `NULL` | converts, `length(rscales)` 8 |
| `"fpc_col"` | `Error: fpc is wrong length` |

Condition classes: `simpleError`, `error`, `condition`. No surveycore class.

## M3 — Replication factors versus finished weights (GIVEN, issue #198)

`gss_2024`/`wtssps`, 50 bootstrap replicates, through the unmodified bridge.

| Columns handed to the bridge | SE of mean `age` |
|---|---|
| replication factors | 0.279983 |
| finished weights (factors x base weight) | 0.428678 |
| `survey::svymean()` on survey's own bootstrap design | 0.428678 |

Issue #198 assigns this to the producer, `surveywts`
(`JDenn0514/surveywts#101`), not to `.as_svydesign_replicate()`. It is recorded
here because `combined.weights` is the one `svrepdesign()` argument the bridge
still does not pass, and a reader of the FPC decision will ask about it.

## What a run must confirm

1. D1's ratio, `SE_converted / SE_surveycore = sqrt(1 - f)`, on a JKn design
   with a constant FPC column. Best held as a test, not a console run.
2. D2's two df values, with `survey::degf()` on both converted shapes.
3. D4's three type groups, by calling the bridge once per type with an FPC
   present, and reading which condition arrives.

---

# Measured run — 2026-09-08

Run in the session that drafted this spec, from the worktree
`as_svydesign-fix` at `a7a52c0`, with `pkgload::load_all()`. R 4.6.1,
survey 4.5, srvyr 1.3.1, Windows. Every figure below is a console run, not a
derivation. The three items under "What a run must confirm" above are now all
confirmed. D1 to D4 were correct as derived.

## R1 — The FPC changes survey's answer and never changes surveycore's

`type = "JKn"`, `n = 60`, `R = 8`, `rscales = rep(1, 8)`, `scale = 1`,
`mse = TRUE`, `fpc_col = rep(0.05, 60)`, `fpctype = "fraction"`, seed 1.
surveycore figures from `get_means(d, y, variance = "se")$se`; survey figures
from `SE(svymean(~y, .))`.

| Object | SE of mean `y` |
|---|--:|
| surveycore, design names `fpc_col` | 0.029046583425 |
| surveycore, design has no FPC | 0.029046583425 |
| survey, hand-built `svrepdesign()`, no `fpc` | 0.029046583425 |
| survey, hand-built `svrepdesign()`, `fpc = rep(0.05, 8)` | 0.028311107506 |

- surveycore's two figures are `identical()`. The field does not reach the
  estimator.
- surveycore's figure matches survey's no-FPC figure. Difference -6.245e-17,
  `all.equal()` TRUE at `tolerance = 1e-12`.
- Ratio of survey's two figures: 0.974679434481. `sqrt(1 - 0.05)`:
  0.974679434481. Equal to twelve digits. D1 confirmed.
- `as_svydesign()` on the FPC design, unmodified code:
  `Error: fpc is wrong length`. M2 reproduced.

This is the fact that settled decision D-1. Option B makes the third and first
rows agree; option A would have made the fourth row the bridge's answer.

## R2 — Which replicate types accept an FPC in survey 4.5

One `svrepdesign()` call per type, `fpc = rep(0.05, 8)`,
`fpctype = "fraction"`, all other arguments held.

| `type` | Result |
|---|---|
| `JK1` | accepted |
| `JKn` | accepted |
| `other` | accepted |
| `JK2` | `Error: fpc not available for this type` |
| `BRR` | `Error: fpc not available for this type` |
| `ACS` | `Error: fpc not available for this type` |
| `successive-difference` | `Error: fpc not available for this type` |
| `bootstrap` | `Error: Separate fpc not needed for bootstrap` |
| `Fay` | `Error: With type='Fay' you must supply the correct rho` |

Three of surveycore's nine types accept an FPC. `Fay` sits in survey's own
refusal list at `svrepdesign.default` line 136, but its `rho` check fires
first, so the FPC message never appears for it. D4 confirmed, with that one
extra detail.

Under decision D-1 (option B) the bridge passes no `fpc`, so none of these
gates is ever reached and all nine types convert. The table is kept because it
records what option A would have had to refuse.

## R3 — The nonprob shapes, the route, and the df

40 rows, 8 bootstrap replicate columns, seed 7. `cal_wt` uniform on
[0.5, 2.5]; each `bw_i` is `cal_wt` times a uniform draw on [0.9, 1.1].

Both shapes carry `@variables$fpc` `NULL`, and neither carries an `fpctype`
key at all. `.as_svydesign_replicate()` already defaults a missing `fpctype`
to `"fraction"` (`R/methods-conversion.R:135-139`), so the nonprob branch
needs no change there.

| Call | Result |
|---|---|
| `.as_svydesign_taylor()` on the plain shape | `survey.design2` |
| `.as_svydesign_taylor()` on the replicate shape | `survey.design2`, all 8 `bw_` columns still in `$variables` |
| `.as_svydesign_replicate()` on the replicate shape | `svyrep.design`, 8 replicate columns |
| `.as_svydesign_replicate()` on the plain shape | `Error: missing value where TRUE/FALSE needed` |

Issue #237's helper table is reproduced. One refinement: the Taylor helper on a
replicate-shaped design does not delete the replicate columns from the frame.
It leaves them as ordinary variables, and the returned `survey.design2` gives
them no part in the variance. The measured consequence is the same.

### The route picks the estimator, and one route matches surveycore

`SE(svymean(~y1, .))` on the converted objects, against surveycore's own
`get_means(., y1, variance = "se")$se` on the source design.

| Shape | Route | Converted SE | surveycore's own SE |
|---|---|--:|--:|
| replicate | `.as_svydesign_replicate()` | 0.0200827192 | 0.0200827192 |
| replicate | `.as_svydesign_taylor()` | 0.5630671378 | 0.0200827192 |
| plain | `.as_svydesign_taylor()` | 0.5630671378 | 0.5630671378 |

Routing on `@variables$repweights` reproduces surveycore's own SE in both
shapes. Sending the replicate shape through the Taylor helper answers 28 times
too large here. The size of that gap is an artefact of replicate weights drawn
tightly around the base weight, as issue #237 says. The agreement in rows 1
and 3 is not an artefact: it is the same estimator on both sides.

### Degrees of freedom

| Design | df |
|---|--:|
| surveycore, plain shape, `.degf()` | `Inf` |
| surveycore, replicate shape, `.degf()` | `Inf` |
| `survey::degf()` on the converted `survey.design2` | 39 |
| `survey::degf()` on the converted `svyrep.design` | 7 |

39 is `n - 1`. 7 is `R - 1`. D2 confirmed.

Effect on a two-sided 95% interval, if the caller passes the df:

| Comparison | t / z ratio |
|---|--:|
| `qt(0.975, 39) / qnorm(0.975)` | 1.032004 |
| `qt(0.975, 7) / qnorm(0.975)` | 1.206463 |

The larger gap, 1.206463, belongs to the replicate shape, which is the shape
that does not warn. That is what settled decision D-3: the note goes in the
documentation, where it covers both shapes.

## R4 — The nonprob round trip loses the class

`from_svydesign()` on the converted replicate-shaped nonprob design returns
`surveycore::survey_replicate`. The nonprob identity is gone, as issue #237
predicts. Asserted as a test row, not assumed.

---

# Methods review sweep — 2026-09-08

Run by the orchestrator during Stage 2, in the same session and the same
worktree as the Measured run above. Every figure is a console run. Two lenses
reported findings R5 and R6 independently; R7 and R8 are the orchestrator's own
follow-up, and neither lens reported them.

## R5 — The nine types at surveycore's own defaults, FPC dropped

`n = 60`, `R = 8`, seed 11, `fpc_col = rep(0.05, 60)` present on every design.
surveycore figures from `get_means(d, y, variance = "se")$se`. Converted
figures from `SE(svymean(~y, .as_svydesign_replicate(d)))`, which is the
post-D-1 call shape: no `fpc`, no `fpctype`. Every design built by
`as_survey_replicate()` with no `scale` and no `rscales` argument, so each type
takes surveycore's own default.

| `type` | surveycore SE | converted SE | ratio | verdict |
|---|--:|--:|--:|---|
| JK1 | 0.0202974520 | 0.0202974520 | 1.000000 | agrees |
| JK2 | 0.0202974520 | 0.0216988889 | 1.069045 | disagrees |
| JKn | 0.0202974520 | none | none | no conversion |
| BRR | 0.0076717157 | 0.0076717157 | 1.000000 | agrees |
| Fay | 0.0076717157 | none | none | no conversion |
| bootstrap | 0.0076717157 | 0.0076717157 | 1.000000 | agrees |
| ACS | 0.0153434315 | 0.0153434315 | 1.000000 | agrees |
| successive-difference | 0.0153434315 | 0.0153434315 | 1.000000 | agrees |
| other | 0.0216988889 | 0.0216988889 | 1.000000 | agrees |

JK2's ratio is `sqrt(R/(R-1))` = 1.069045 exactly. The two failures carry
survey's own bare messages: `Must provide rscales for combined JKn weights` and
`With type='Fay' you must supply the correct rho`.

Six types convert and agree. One converts and disagrees. Two do not convert.
"All nine replicate types convert" is false.

Note on JKn. Issue #198's reproduction and the R1 design above both pass
`rscales = rep(1, R)` explicitly, which is why neither saw this. At
surveycore's default, `@variables$rscales` is `NULL` for every one of the nine
types, and survey refuses to guess for JKn alone.

## R6 — JK2: the two constructors disagree, and the nonprob one matches survey

Same frame. `mse = TRUE` on all three, which matters: survey's own default is
`getOption("survey.replicates.mse")`, and the bridge passes `mse` explicitly.

| Source | JK2 `scale` | SE of mean `y` |
|---|--:|--:|
| `as_survey_nonprob()`, `rscales = rep(1, 8)` | 1 | 0.021698888900 |
| `survey::svrepdesign()`, hardcoded | 1 | 0.021698888900 |
| `as_survey_replicate()` | 0.875 | 0.020297451984 |

Ratio of the third row to the second: 0.9354143467. `sqrt(0.875)`:
0.9354143467.

`R/core-constructors.R:794-796` sets `JK1 = JK2 = JKn = (n_rep - 1L) / n_rep`.
`R/core-constructors.R:1240` documents the nonprob JK2 default as 1.
`survey:::svrepdesign.default` sets `rscales <- rep(1, ncol(repweights))` and
`scale <- 1` for JK2 unconditionally, after warning that both arguments are
ignored.

This is a surveycore-internal disagreement. The bridge only made it visible,
because converting hands survey the same columns and survey answers with its
own constant.

## R7 — Fay computes BRR

Same frame.

| Design | scale | SE of mean `y` |
|---|--:|--:|
| surveycore BRR | 0.125 | 0.007671715743 |
| surveycore Fay | 0.125 | 0.007671715743 |
| survey Fay, `rho = 0.3` | 0.255102 | 0.010959593918 |

surveycore's Fay standard error is `identical()` to its BRR standard error.
`grep -rc rho R/*.R` returns hits only in `analysis-corr.R` and
`analysis-corr-latent.R`, both unrelated to replicate variance. Fay's scale is
set to `1/R`, which is BRR's. survey's Fay scale is `1/(R*(1-rho)^2)`, which is
0.255102 at `rho = 0.3` and `R = 8`.

So `type = "Fay"` in surveycore is BRR under another name, which is Fay at
`rho = 0`. Nothing records that.

## R8 — JKn without rscales computes JK1

Same frame.

| Design | SE of mean `y` |
|---|--:|
| surveycore JKn, `rscales` NULL | 0.020297451984 |
| surveycore JK1 | 0.020297451984 |

`identical()`. `R/variance-replicate.R:92` and `:210` both read
`if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep)`, so a stratified
jackknife with no per-stratum factors silently becomes an unstratified one.
`as_survey_nonprob()` refuses this case with
`surveycore_error_stratified_jk_rscales_unset`;
`R/core-constructors.R:1167` holds the `.is_stratified_jk()` helper that gates
it, and its comment records one call site.

## R9 — degf under replicate-column collinearity

40 rows, 8 bootstrap replicate columns, seed 7, `bw_8` set to an exact copy of
`bw_1`.

| Design | qr rank | `survey::degf()` |
|---|--:|--:|
| 8 independent replicate columns | 8 | 7 |
| 8 columns, one duplicated | 7 | 6 |

`survey::degf.svyrep.design` computes
`qr(weights(design, "analysis"), tol = 1e-5)$rank - 1`. So `R - 1` holds only
at full column rank.

## R10 — The dropped domain restriction

`make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 3)`, built with
`as_survey(ids = psu, weights = wt, strata = strata)`, then
`surveytidy::filter(d, y1 > 50)`.

| Call | mean | SE |
|---|--:|--:|
| surveycore `get_means()` on the filtered design | 58.176655 | 0.725342 |
| `survey::svymean()` on `as_svydesign()`'s output | 50.761561 | 0.614837 |
| the same, after `subset()` on `..surveycore_domain..` | 58.176655 | 0.725342 |

Row 3 reproduces row 1 exactly. The domain column reaches the converted object
as an ordinary variable and is never installed as that object's restriction.
This measurement is independent of the Lens 4 agent's own run, which used a
different fixture and reported the same structure.

---

# R11 — Which types honour a passed `scale` (orchestrator, Stage 2r delta check)

Run 2026-09-08, same session and worktree. This replaces the Lens 2 figure the
spec cited, which gave its ratio in the opposite direction and so read
ambiguously beside the other tables here.

`n = 60`, `R = 8`, seed 11. Every design built by `as_survey_replicate()` with
`scale = 0.9` and `rscales = rep(1, 8)` supplied explicitly. `0.9` equals no
type's hardcoded value at `R = 8`, which matters: a first attempt used
`scale = 0.5`, and `4/R` is exactly 0.5 at `R = 8`, so `ACS` and
`successive-difference` returned a ratio of 1.000000 and looked as if they
honoured the value. They do not.

Ratio is the converted standard error over surveycore's own, the same direction
as every other table in this file.

| `type` | `scale` survey used | Ratio | Honours the passed `scale` |
|---|--:|--:|---|
| `JK1` | 0.900000 | 1.000000 | yes |
| `bootstrap` | 0.900000 | 1.000000 | yes |
| `JKn` | 0.900000 | 1.000000 | yes |
| `other` | 0.900000 | 1.000000 | yes |
| `BRR` | 0.125000 | 0.372678 | no, survey uses `1/R` |
| `ACS` | 0.500000 | 0.745356 | no, survey uses `4/R` |
| `successive-difference` | 0.500000 | 0.745356 | no, survey uses `4/R` |
| `JK2` | 1.000000 | 1.054093 | no, survey uses 1 |

Each ratio is the square root of survey's constant over the passed 0.9:
`sqrt(0.125/0.9)` = 0.372678, `sqrt(0.5/0.9)` = 0.745356,
`sqrt(1/0.9)` = 1.054093.

Four types discard a passed `scale`: `BRR`, `ACS`, `successive-difference` and
`JK2`. `Fay` discards one too, and silently, but it cannot convert at all (R7),
so no caller reaches that state through the bridge.

Note on `BRR`. `.as_svydesign_replicate()` already suppresses `scale` for `BRR`
and `Fay`, so the passed 0.9 never reaches survey for `BRR`. survey computes
`1/R` itself. The end state is the same, and the caveat holds either way.

Note on `JKn`. With `rscales` supplied it converts and honours the `scale`. Its
failure in R5 comes from `rscales` being `NULL` at surveycore's default, not
from the `scale` (#244).

---

# R12 — A zero-weight row IS reachable on a nonprob design

Run 2026-09-08 by the orchestrator, during the Stage 3 spec review. This
reverses the Stage 2r resolution of finding B-3, which recorded the zero-weight
case as unreachable on every class. It is unreachable on two classes and
reachable on the third.

## The asymmetry

`n = 40`, seed 7. One weight set to 0.

| Action | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| Construct with a zero weight | blocked, `surveycore_error_weights_nonpositive` | blocked, `surveycore_error_weights_nonpositive` |
| Assign `@data` with a zero weight after construction | blocked, `surveycore_error_weights_nonpositive` | **accepted** |

`.validate_weights()` blocks every constructor, which is what the Stage 2r
resolution measured. The S7 validators are what differ, and only the
assignment path reaches them:

- `survey_taylor`'s validator, `R/core-classes.R:688` region, raises
  `surveycore_error_weights_nonpositive` for `wt_col <= 0`. Note the line lies
  inside the `survey_replicate` validator block, which begins at
  `R/core-classes.R:631`; `survey_taylor` begins at 422 and carries its own
  copy. The Stage 2r text cited 688 as the `survey_nonprob` check. It is not.
- `survey_nonprob`'s validator begins at `R/core-classes.R:1193` and checks two
  weaker conditions only: condition 4a rejects a negative weight
  (`surveycore_error_weights_negative`), and condition 4b rejects a column with
  no positive value at all (`surveycore_error_weights_all_zero`). Its own
  message says "All non-NA weights must be non-negative (>= 0)". A single zero
  passes both.

`plans/error-messages.md` row 33 already records this on purpose: "No longer
thrown by `survey_nonprob` validator (see row 101,
`surveycore_error_weights_negative`)." The permissiveness is deliberate.

## What the conversion then does

Same frame, one zero weight, reached by assignment. The plain shape has no
replicate columns; the replicate shape carries 8.

| Shape | Converts to | `survey::degf()` | surveycore `.degf()` | `svymean()` SE | surveycore's own SE |
|---|---|--:|--:|--:|--:|
| plain | `survey.design2` | 38 | `Inf` | 0.5296146428 | 0.5296146428 |
| replicate | `svyrep.design` | 7 | `Inf` | 0.2422736303 | 0.2422736303 |

Two findings.

1. **Both shapes convert, and the standard errors still agree exactly.** The
   zero-weight row costs the bridge nothing. No new guard is needed.
2. **`survey::degf()` gives 38, not `n - 1` = 39.** `survey` excludes a
   zero-weight row on the Taylor path. So the roxygen sentence for the plain
   shape needs a second qualifier: the figure is `n - 1` less the number of
   zero-weight rows. The replicate shape is unaffected, at `R - 1` = 7, because
   `degf.svyrep.design` reads the rank of the replicate weight matrix and not
   the row count.

Both qualifiers on that one roxygen sentence now come from measurement: R9 for
replicate-column collinearity, R12 for zero-weight rows.

---

# R13 — The `@data` assignment loophole is wider than the weight sign

Run 2026-09-08 by the orchestrator, after the Stage 3r resolver reported that
`R/core-classes.R` holds no `nrow()` call. It does not: `grep -c "nrow\|NROW"`
returns 0. R12 found the loophole for the weight sign on one class. It is wider.

`n = 40`, seed 7. Each design built normally, then handed a different frame
through `@data <-`.

| Frame assigned after construction | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| 1 row | accepted | accepted |
| 0 rows | accepted | blocked, `surveycore_error_weights_all_zero` |
| a zero weight (R12) | blocked, `surveycore_error_weights_nonpositive` | accepted |

The one block on the 0-row nonprob case is incidental, not a row-count guard: a
zero-row weight column has no positive value, so condition 4b fires for a
reason unrelated to the row count.

Construction refuses both frames on every class:

| Constructor call | Result |
|---|---|
| `as_survey()` on a 1-row frame | `surveycore_error_single_row` |
| `as_survey()` on a 0-row frame | `surveycore_error_empty_data` |

The guards live in `R/core-validators.R:77-80` and `:100-109`, which the
constructors call. No S7 validator repeats them.

## What a 1-row design does on the bridge

```
nrow(@data) after assignment: 1
.as_svydesign_taylor():       Error: Design has only one primary sampling unit
```

Another bare `survey` `stop()` reaching a user with no surveycore class on it,
which is the failure mode issue #198 exists to remove.

## What this means for the spec

Three edge-case rows claimed "not reachable" on the strength of a constructor
guard: the zero weight, the empty frame and the single row. All three are
reachable through `@data` assignment. The right phrasing names the constructor
guard, says no S7 validator repeats it, and says the assignment route is
untested and tracked. Issue **#248** holds the root cause.

Nothing here asks the bridge for a new guard. A design in this state is already
malformed before `as_svydesign()` sees it, and the fix belongs in the
validators.

---

# R14 — Re-measured on base `40700e3`, after the FPC arc shipped

Run 2026-09-09 by the orchestrator. The base moved twice more during the plan
stage, and the neighbouring arc's last two PRs merged:

- `8c99271 fix(conversion): drop the FPC on the replicate export route (#198) (#249)`
- `4440de1 fix(conversion): recover Fay's shrinkage factor on the export route (#250)`

Issue #198 is closed. D-9 handed that half over one day before it shipped.

## What still holds

The same 40-row fixture as R3, seed 7, eight `bw_` columns.

| Claim | R3, base `a7a52c0` | R14, base `40700e3` |
|---|--:|--:|
| Replicate shape converts to | `svyrep.design`, 8 columns | `svyrep.design`, 8 columns |
| Replicate SE, converted against surveycore's own | 0.0200827192 both | 0.0200827192 both |
| Plain SE, converted against surveycore's own | 0.5630671378 both | 0.5630671378 both |
| `survey::degf()`, plain then replicate | 39, 7 | 39, 7 |

Every figure the narrowed spec cites is unchanged. The nonprob replicate route
raises no FPC warning, because a nonprob design carries `fpc` `NULL` in both
shapes.

## What changed

**The plain shape through the replicate helper now fails with a typed error.**

| Base | Condition classes | Message |
|---|---|---|
| `a7a52c0` (R3) | `simpleError, error, condition` | `missing value where TRUE/FALSE needed` |
| `40700e3` | `surveycore_error_repweights_empty, rlang_error, error, condition` | `The design names no replicate weight column.` |

PR #249 added the guard, and its own comment gives the same reason R3 recorded:
the bare message came from inside survey's `combined.weights` heuristic and
carried no class.

This changes the evidence for §Why the nonprob branch needs two routes, not the
conclusion. The plain shape still cannot use the replicate helper. It now says
so with a surveycore class instead of a bare one.

**Row B-7 is no longer vacuous.**
`surveycore_warning_replicate_fpc_dropped` exists on this base, raised at
`R/methods-conversion.R:277`. The row asserted an absence that could not fail
before. It can fail now, and it passes: measured above, neither nonprob shape
raises it.

## Citations this moved

| Item | Was | Now |
|---|--:|--:|
| `as_tbl_svy()` `@param x`, two lines | 217, 218 | 348, 349 |
| `surveycore_error_not_survey_object` in `as_tbl_svy()` | 271 | 402 |
| `from_svydesign()` `@return` | 364 | 495 |
| `from_tbl_svy()` `@return` | 750 | 881 |
| `tests/testthat/_snaps/conversion.md` | 41 lines, 4 blocks | 84 lines, 8 blocks |
| The `fpctype` default block in the replicate helper | 135-139 | gone; PR #249 rewrote that region |

Unmoved, and re-verified: `as_svydesign()` at 63, `.as_svydesign_taylor()` at
96, `.as_svydesign_replicate()` at 131, the dispatch chain's
`surveycore_error_not_survey_object` at 88, and roxygen lines 33, 41 and 42.

`plans/error-messages.md` now holds five CB rows, CB-1 to CB-5, with the
pending-rows note removed. `CN` is still free at zero rows. The file's last
subsection is still `### svydesign-replicate-bridge rows (2026-09-04)`.
