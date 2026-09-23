# Measurements — replicate-oracle-tests

Every number in `comprehension.md` that is not marked `[unverified]` comes from
a run recorded here. The previous session had no shell, so it read the source
and could run nothing. This file closes that gap.

## Environment

| Item | Value |
|---|---|
| R | 4.6.1 (2026-06-24 ucrt), `C:/Users/jdennen/AppData/Local/Programs/R/R-4.6.1` |
| `survey` | 4.5 |
| `testthat` | 3.3.2 |
| surveycore | the worktree, branch `JDenn0514/replicate-oracle-tests-feed-surveycore-its-own-s` |
| Date | 2026-09-16 |

Command to read the versions:

```r
cat(R.version.string, "\n")
cat(as.character(packageVersion("survey")), "\n")
cat(as.character(packageVersion("testthat")), "\n")
```

```
R version 4.6.1 (2026-06-24 ucrt) 
4.5 
3.3.2
```

---

## M0 — the installed `svrepdesign.default`, deparsed

```r
src <- deparse(survey:::svrepdesign.default)
writeLines(src, "<scratch>/svrepdesign-installed.R")
writeLines(paste0(seq_along(src), ": ", src), "<scratch>/svrepdesign-numbered.R")
cat(length(src), "lines\n")
```

Output: `172 lines`.

Every line number in `comprehension.md` and in `plans/issue-cleanup.md` D2 and
D7 refers to this deparse. The numbered dump follows.

```r
1: function (variables = NULL, repweights = NULL, weights = NULL, 
2:     data = NULL, degf = NULL, type = c("BRR", "Fay", "JK1", "JKn", 
3:         "bootstrap", "ACS", "successive-difference", "JK2", "other"), 
4:     combined.weights = TRUE, rho = NULL, bootstrap.average = NULL, 
5:     scale = NULL, rscales = NULL, fpc = NULL, fpctype = c("fraction", 
6:         "correction"), mse = getOption("survey.replicates.mse"), 
7:     ...) 
8: {
9:     type <- match.arg(type)
10:     if (type == "Fay" && is.null(rho)) 
11:         stop("With type='Fay' you must supply the correct rho")
12:     if (type %in% c("JK1", "JKn", "ACS", "successive-difference", 
13:         "JK2") && !is.null(rho)) 
14:         warning("rho not relevant to JK1 design: ignored.")
15:     if (type %in% c("other") && !is.null(rho)) 
16:         warning("rho ignored.")
17:     if (is.null(variables)) 
18:         variables <- data
19:     if (inherits(variables, "formula")) {
20:         mf <- substitute(model.frame(variables, data = data, 
21:             na.action = na.pass))
22:         variables <- eval.parent(mf)
23:     }
24:     variables <- detibble(variables)
25:     if (inherits(repweights, "formula")) {
26:         mf <- substitute(model.frame(repweights, data = data))
27:         repweights <- eval.parent(mf)
28:     }
29:     if (is.character(repweights)) {
30:         wtcols <- grep(repweights, names(data))
31:         repweights <- data[, wtcols]
32:     }
33:     if (is.null(repweights)) 
34:         stop("You must provide replication weights")
35:     if (anyNA(repweights)) 
36:         stop("Missing values not allowed in 'repweights'")
37:     repweights <- detibble(repweights)
38:     if (inherits(weights, "formula")) {
39:         mf <- substitute(model.frame(weights, data = data))
40:         weights <- eval.parent(mf)
41:         if (anyNA(weights)) 
42:             stop("Missing values not allowed in 'weights'")
43:         weights <- drop(as.matrix(weights))
44:     }
45:     if (is.null(weights)) {
46:         warning("No sampling weights provided: equal probability assumed")
47:         weights <- rep(1, NROW(repweights))
48:     }
49:     if (!is.null(degf)) {
50:         if (!is.numeric(degf)) 
51:             stop("degf must be NULL or numeric")
52:         if (degf > ncol(repweights)) 
53:             warning(paste0("degf (", degf, ") is larger than number of replicates (", 
54:                 ncol(repweights), ")"))
55:         if (degf <= 1) 
56:             warning("degf is <=1")
57:         attr(degf, "set-by-user") <- TRUE
58:     }
59:     repwtmn <- mean(apply(repweights, 2, mean))
60:     wtmn <- mean(weights)
61:     probably.combined.weights <- (repwtmn > 5) & (wtmn/repwtmn < 
62:         5)
63:     probably.not.combined.weights <- (repwtmn < 5) & (wtmn/repwtmn > 
64:         5)
65:     if (combined.weights & probably.not.combined.weights) 
66:         warning(paste("Data do not look like combined weights: mean replication weight is", 
67:             repwtmn, " and mean sampling weight is", wtmn))
68:     if (!combined.weights & probably.combined.weights) 
69:         warning(paste("Data look like combined weights: mean replication weight is", 
70:             repwtmn, " and mean sampling weight is", wtmn))
71:     if (!is.null(rscales) && !(length(rscales) %in% c(1, ncol(repweights)))) {
72:         stop(paste("rscales has length ", length(rscales), ", should be ncol(repweights)", 
73:             sep = ""))
74:     }
75:     if (type %in% c("ACS", "successive-difference")) {
76:         if (!is.null(scale) | !is.null(rscales)) 
77:             warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))
78:     }
79:     if (type == "BRR") {
80:         if (!is.null(scale)) 
81:             warning("type='BRR' does not use 'scale=' argument")
82:         if (!is.null(rho)) 
83:             warning("type='BRR' does not use 'rho=' argument, you may want type='Fay'")
84:         scale <- 1/ncol(repweights)
85:     }
86:     if (type == "Fay") 
87:         scale <- 1/(ncol(repweights) * (1 - rho)^2)
88:     if (type == "bootstrap") {
89:         if (is.null(bootstrap.average)) 
90:             bootstrap.average <- 1
91:         if (is.null(scale)) 
92:             scale <- bootstrap.average/(ncol(repweights) - 1)
93:         if (is.null(rscales)) 
94:             rscales <- rep(1, ncol(repweights))
95:     }
96:     if (type == "JK1" && is.null(scale)) {
97:         if (!combined.weights) {
98:             warning("scale (n-1)/n not provided: guessing from weights")
99:             scale <- 1/max(repweights[, 1])
100:         }
101:         else {
102:             probably.n = ncol(repweights)
103:             scale <- (probably.n - 1)/probably.n
104:             warning("scale (n-1)/n not provided: guessing n=number of replicates")
105:         }
106:     }
107:     if (type == "JKn" && is.null(rscales)) {
108:         if (!combined.weights) {
109:             warning("rscales (n-1)/n not provided:guessing from weights")
110:             rscales <- 1/apply(repweights, 2, max)
111:         }
112:         else stop("Must provide rscales for combined JKn weights")
113:     }
114:     if (type %in% c("ACS", "successive-difference")) {
115:         rscales <- rep(1, ncol(repweights))
116:         scale <- 4/ncol(repweights)
117:     }
118:     if (type == "JK2") {
119:         warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))
120:         rscales <- rep(1, ncol(repweights))
121:         scale <- 1
122:     }
123:     if (type == "other" && (is.null(rscales) || is.null(scale))) {
124:         if (is.null(rscales)) 
125:             rscales <- rep(1, NCOL(repweights))
126:         if (is.null(scale)) 
127:             scale <- 1
128:         warning("scale or rscales not specified, set to 1")
129:     }
130:     if (is.null(rscales)) 
131:         rscales <- rep(1, NCOL(repweights))
132:     if (!is.null(fpc)) {
133:         if (missing(fpctype)) 
134:             stop("Must specify fpctype")
135:         fpctype <- match.arg(fpctype)
136:         if (type %in% c("BRR", "Fay", "JK2", "ACS", "successive-difference")) 
137:             stop("fpc not available for this type")
138:         if (type %in% "bootstrap") 
139:             stop("Separate fpc not needed for bootstrap")
140:         if (length(fpc) != length(rscales)) 
141:             stop("fpc is wrong length")
142:         if (any(fpc > 1) || any(fpc < 0)) 
143:             stop("Illegal fpc value")
144:         fpc <- switch(fpctype, correction = fpc, fraction = 1 - 
145:             fpc)
146:         rscales <- rscales * fpc
147:     }
148:     if (is.null(scale)) 
149:         scale <- 1
150:     rval <- list(type = type, scale = scale, rscales = rscales, 
151:         rho = rho, call = sys.call(), combined.weights = combined.weights)
152:     rval$variables <- variables
153:     rval$pweights <- weights
154:     if (!inherits(repweights, "repweights")) 
155:         class(rval) <- "repweights"
156:     rval$repweights <- repweights
157:     class(rval) <- "svyrep.design"
158:     if (!is.null(degf)) 
159:         rval$degf <- degf
160:     else rval$degf <- degf(rval)
161:     if (type == "ACS") {
162:         if (missing(mse) && !mse) {
163:             mse <- TRUE
164:             message("mse=TRUE assumed for type=\"ACS\"")
165:         }
166:         else if (!mse) {
167:             warning("The ACS uses MSE standard errors but you have specified mse=FALSE")
168:         }
169:     }
170:     rval$mse <- mse
171:     rval
172: }
```

### Agreement with the CRAN mirror

The previous session read
`https://raw.githubusercontent.com/cran/survey/master/R/surveyrep.R`. Every
behaviour its per-type table claims appears in the dump above, at the line
numbers the table gives. The two sources agree on all nine types, on both
refusals, and on every warning text.

### Agreement with `plans/issue-cleanup.md` D2 and D7

D2 and D7 cite deparse lines. Each one matches the dump:

| Cited in | Lines cited | Lines observed | Agree? |
|---|--:|--:|---|
| D2 JK1 | 96-106 | 96-106 | yes |
| D2 JK2 | 118-121 | 118-121 | yes |
| D2 JKn | 107-112, 148 | 107-112, 148 | yes |
| D2 BRR | 79-84 | 79-84 | yes |
| D2 Fay | 86-87 | 86-87 | yes |
| D2 bootstrap | 88-95 | 88-95 | yes |
| D2 ACS | 114-116 | 114-116 | yes |
| D2 successive-difference | 114-116 | 114-116 | yes |
| D2 other | 123-128 | 123-128 | yes |
| D6 Fay refusal | 10-11 | 10-11 | yes |
| D7 ACS / successive-difference warn | 75-77 | 75-77 | yes |
| D7 JK1 / JKn `rho` | 12-14 | 12-14 | yes |
| D7 `other` `rho` | 15-16 | 15-16 | yes |

No observed number disagrees with D2 or D7.

---

## M1 — per type: scale, rscales, conditions

Script:

```r
set.seed(15)
n <- 200; R <- 20
wt <- rep(c(8, 12, 10, 15), length.out = n) * exp(rnorm(n, 0, 0.2))
rw <- as.data.frame(matrix(wt * exp(rnorm(n * R, 0, 0.1)), nrow = n, ncol = R))
names(rw) <- paste0("repwt_", seq_len(R))
d <- data.frame(y1 = rnorm(n, 50, 10), wt = wt)
d <- cbind(d, rw)
rwn <- names(rw)

probe <- function(type, ...) {
  w <- NULL
  des <- withCallingHandlers(
    survey::svrepdesign(weights = d$wt, repweights = d[, rwn],
                        type = type, mse = TRUE, data = d, ...),
    warning = function(cnd) { w <<- c(w, list(cnd)); invokeRestart("muffleWarning") }
  )
  list(scale = des$scale, rscales = unique(des$rscales),
       msgs = vapply(w, conditionMessage, ""),
       classes = paste(unlist(lapply(w, function(x) paste(class(x), collapse = "/"))), collapse = " | "))
}
show <- function(lab, x) {
  cat("\n## ", lab, "\n", sep = "")
  cat("  scale   = ", format(x$scale, digits = 15), "\n", sep = "")
  cat("  rscales = unique(", paste(x$rscales, collapse = ","), ") len=", length(x$rscales), "\n", sep = "")
  if (length(x$msgs)) for (m in x$msgs) cat("  WARN: ", m, "\n", sep = "") else cat("  WARN: <none>\n")
  cat("  WARN classes: ", if (nzchar(x$classes)) x$classes else "<none>", "\n", sep = "")
}
cat("R =", R, " 1/R =", format(1/R, digits=15), " (R-1)/R =", format((R-1)/R, digits=15),
    " 1/(R-1) =", format(1/(R-1), digits=15), " 4/R =", format(4/R, digits=15), "\n")
cat("getOption('survey.replicates.mse') = "); print(getOption("survey.replicates.mse"))

cat("\n===== BARE CALLS (caller supplies nothing) =====\n")
for (ty in c("BRR", "JK1", "JK2", "bootstrap", "ACS", "successive-difference", "other")) {
  show(ty, probe(ty))
}
show("Fay (rho = 0.3 supplied; required)", probe("Fay", rho = 0.3))
show("JKn (rscales = rep(0.95, R) supplied; required)", probe("JKn", rscales = rep(0.95, R)))

cat("\n===== REFUSALS =====\n")
e1 <- tryCatch(survey::svrepdesign(weights = d$wt, repweights = d[, rwn], type = "Fay", data = d),
               error = function(e) e)
cat("Fay, no rho:  class = ", paste(class(e1), collapse = "/"), "\n  msg = ", conditionMessage(e1), "\n", sep = "")
e2 <- tryCatch(suppressWarnings(survey::svrepdesign(weights = d$wt, repweights = d[, rwn], type = "JKn", data = d)),
               error = function(e) e)
cat("JKn, no rscales: class = ", paste(class(e2), collapse = "/"), "\n  msg = ", conditionMessage(e2), "\n", sep = "")

cat("\n===== SUPPLIED scale = 0.123, rscales = rep(0.77, R) =====\n")
for (ty in c("BRR", "JK1", "JK2", "JKn", "bootstrap", "ACS", "successive-difference", "other")) {
  show(ty, probe(ty, scale = 0.123, rscales = rep(0.77, R)))
}
show("Fay(rho=.3)", probe("Fay", rho = 0.3, scale = 0.123, rscales = rep(0.77, R)))

cat("\n===== SUPPLIED rho = 0.3 on non-Fay types =====\n")
for (ty in c("BRR", "JK1", "JK2", "JKn", "bootstrap", "ACS", "successive-difference", "other")) {
  x <- try(probe(ty, rho = 0.3, rscales = if (ty == "JKn") rep(1, R) else NULL), silent = TRUE)
  if (inherits(x, "try-error")) cat("\n## ", ty, "\n  ERROR: ", conditionMessage(attr(x, "condition")), "\n", sep = "")
  else show(ty, x)
}
```

Output:

```
R = 20  1/R = 0.05  (R-1)/R = 0.95  1/(R-1) = 0.0526315789473684  4/R = 0.2 
getOption('survey.replicates.mse') = NULL

===== BARE CALLS (caller supplies nothing) =====

## BRR
  scale   = 0.05
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## JK1
  scale   = 0.95
  rscales = unique(1) len=1
  WARN: scale (n-1)/n not provided: guessing n=number of replicates
  WARN classes: simpleWarning/warning/condition

## JK2
  scale   = 1
  rscales = unique(1) len=1
  WARN: with type JK2 scale= and rscales= are not needed and will be ignored
  WARN classes: simpleWarning/warning/condition

## bootstrap
  scale   = 0.0526315789473684
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## ACS
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## successive-difference
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## other
  scale   = 1
  rscales = unique(1) len=1
  WARN: scale or rscales not specified, set to 1
  WARN classes: simpleWarning/warning/condition

## Fay (rho = 0.3 supplied; required)
  scale   = 0.102040816326531
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## JKn (rscales = rep(0.95, R) supplied; required)
  scale   = 1
  rscales = unique(0.95) len=1
  WARN: <none>
  WARN classes: <none>

===== REFUSALS =====
Fay, no rho:  class = simpleError/error/condition
  msg = With type='Fay' you must supply the correct rho
JKn, no rscales: class = simpleError/error/condition
  msg = Must provide rscales for combined JKn weights

===== SUPPLIED scale = 0.123, rscales = rep(0.77, R) =====

## BRR
  scale   = 0.05
  rscales = unique(0.77) len=1
  WARN: type='BRR' does not use 'scale=' argument
  WARN classes: simpleWarning/warning/condition

## JK1
  scale   = 0.123
  rscales = unique(0.77) len=1
  WARN: <none>
  WARN classes: <none>

## JK2
  scale   = 1
  rscales = unique(1) len=1
  WARN: with type JK2 scale= and rscales= are not needed and will be ignored
  WARN classes: simpleWarning/warning/condition

## JKn
  scale   = 0.123
  rscales = unique(0.77) len=1
  WARN: <none>
  WARN classes: <none>

## bootstrap
  scale   = 0.123
  rscales = unique(0.77) len=1
  WARN: <none>
  WARN classes: <none>

## ACS
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: with type ACS scale= and rscales= are not needed and will be ignored
  WARN classes: simpleWarning/warning/condition

## successive-difference
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: with type successive-difference scale= and rscales= are not needed and will be ignored
  WARN classes: simpleWarning/warning/condition

## other
  scale   = 0.123
  rscales = unique(0.77) len=1
  WARN: <none>
  WARN classes: <none>

## Fay(rho=.3)
  scale   = 0.102040816326531
  rscales = unique(0.77) len=1
  WARN: <none>
  WARN classes: <none>

===== SUPPLIED rho = 0.3 on non-Fay types =====

## BRR
  scale   = 0.05
  rscales = unique(1) len=1
  WARN: type='BRR' does not use 'rho=' argument, you may want type='Fay'
  WARN classes: simpleWarning/warning/condition

## JK1
  scale   = 0.95
  rscales = unique(1) len=1
  WARN: rho not relevant to JK1 design: ignored.
  WARN: scale (n-1)/n not provided: guessing n=number of replicates
  WARN classes: simpleWarning/warning/condition | simpleWarning/warning/condition

## JK2
  scale   = 1
  rscales = unique(1) len=1
  WARN: rho not relevant to JK1 design: ignored.
  WARN: with type JK2 scale= and rscales= are not needed and will be ignored
  WARN classes: simpleWarning/warning/condition | simpleWarning/warning/condition

## JKn
  scale   = 1
  rscales = unique(1) len=1
  WARN: rho not relevant to JK1 design: ignored.
  WARN classes: simpleWarning/warning/condition

## bootstrap
  scale   = 0.0526315789473684
  rscales = unique(1) len=1
  WARN: <none>
  WARN classes: <none>

## ACS
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: rho not relevant to JK1 design: ignored.
  WARN classes: simpleWarning/warning/condition

## successive-difference
  scale   = 0.2
  rscales = unique(1) len=1
  WARN: rho not relevant to JK1 design: ignored.
  WARN classes: simpleWarning/warning/condition

## other
  scale   = 1
  rscales = unique(1) len=1
  WARN: rho ignored.
  WARN: scale or rscales not specified, set to 1
  WARN classes: simpleWarning/warning/condition | simpleWarning/warning/condition
```

---

## M2 — the ACS `mse` path, the combined-weights heuristic, surveycore's defaults

Script:

```r
setwd("C:/Users/jdennen/orca/workspaces/surveycore/replicate-oracle-tests-feed-surveycore-its-own-s")
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-test-data.R")

cat("===== G5: ACS with mse omitted =====\n")
d0 <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "jk1", seed = 15)
rwn <- grep("^repwt_", names(d0), value = TRUE)
r <- tryCatch(
  withCallingHandlers(
    survey::svrepdesign(weights = d0$wt, repweights = d0[, rwn], type = "ACS", data = d0),
    warning = function(w) { cat("  WARN:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") },
    message = function(m) { cat("  MSG:", conditionMessage(m)); invokeRestart("muffleMessage") }),
  error = function(e) { cat("  ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(r)) cat("  mse =", format(r$mse), " scale =", r$scale, "\n")

cat("\n===== G6: combined-weights heuristic on make_survey_data() =====\n")
for (ty in c("brr", "jk1", "jkn", "bootstrap")) {
  dd <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = ty, seed = 15)
  rn <- grep("^repwt_", names(dd), value = TRUE)
  rm_ <- mean(apply(as.matrix(dd[, rn]), 2, mean)); wm <- mean(dd$wt)
  cat(sprintf("  %-10s R=%2d repwtmn=%.4f wtmn=%.4f ratio=%.4f  fires=%s\n",
      ty, length(rn), rm_, wm, wm/rm_, (rm_ < 5) & (wm/rm_ > 5)))
}

cat("\n===== surveycore default scale per type (R = 20) =====\n")
d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "jk1", seed = 15)
rwn <- grep("^repwt_", names(d), value = TRUE)
R <- length(rwn); cat("  R =", R, "\n")
sc_one <- function(type, ...) {
  des <- as_survey_replicate(d, repweights = tidyselect::all_of(rwn), weights = wt, type = type, mse = TRUE, ...)
  des@variables$scale
}
for (ty in c("BRR", "JK1", "JK2", "JKn", "bootstrap", "ACS", "successive-difference", "other", "Fay")) {
  v <- tryCatch(sc_one(ty), error = function(e) paste("ERROR:", conditionMessage(e)))
  cat(sprintf("  %-22s surveycore scale = %s\n", ty, format(v, digits = 15)))
}
```

Output:

```
===== G5: ACS with mse omitted =====
  MSG: mse=TRUE assumed for type="ACS"
  mse = TRUE  scale = 0.2 

===== G6: combined-weights heuristic on make_survey_data() =====
  brr        R=10 repwtmn=11.9312 wtmn=11.8389 ratio=0.9923  fires=FALSE
  jk1        R=20 repwtmn=11.9183 wtmn=11.8389 ratio=0.9933  fires=FALSE
  jkn        R=20 repwtmn=11.9183 wtmn=11.8389 ratio=0.9933  fires=FALSE
  bootstrap  R=20 repwtmn=11.9183 wtmn=11.8389 ratio=0.9933  fires=FALSE

===== surveycore default scale per type (R = 20) =====
  R = 20 
  BRR                    surveycore scale = 0.05
  JK1                    surveycore scale = 0.95
  JK2                    surveycore scale = 1
  JKn                    surveycore scale = 0.95
  bootstrap              surveycore scale = 0.05
  ACS                    surveycore scale = 0.2
  successive-difference  surveycore scale = 0.2
  other                  surveycore scale = 1
  Fay                    surveycore scale = 0.05
```

---

## M3 — the standard errors on a real fixture

Script:

```r
setwd("C:/Users/jdennen/orca/workspaces/surveycore/replicate-oracle-tests-feed-surveycore-its-own-s")
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-test-data.R")
loadNamespace("survey")
cat("getOption('survey.replicates.mse') after survey loads: "); print(getOption("survey.replicates.mse"))

cmp <- function(type, sv_type, extra_sc = list(), extra_sv = list()) {
  d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate",
                        type = tolower(type), seed = 15)
  rwn <- grep("^repwt_", names(d), value = TRUE); R <- length(rwn)
  sc <- do.call(as_survey_replicate, c(list(d, repweights = tidyselect::all_of(rwn),
        weights = quote(wt), type = type, mse = TRUE), extra_sc))
  sv <- suppressWarnings(do.call(survey::svrepdesign, c(list(weights = d$wt,
        repweights = d[, rwn], type = sv_type, mse = TRUE, data = d), extra_sv)))
  m_sc <- get_means(sc, y1, variance = c("se", "ci"))
  m_sv <- survey::svymean(~y1, sv)
  se_sc <- m_sc$se[1]; se_sv <- as.numeric(survey::SE(m_sv))
  cat(sprintf("\n## %s  (R = %d)\n", type, R))
  cat(sprintf("  scale   surveycore = %.15g   survey = %.15g\n", sc@variables$scale, sv$scale))
  cat(sprintf("  mean    surveycore = %.15g   survey = %.15g   diff = %.3g\n",
              m_sc$mean[1], as.numeric(coef(m_sv)), m_sc$mean[1] - as.numeric(coef(m_sv))))
  cat(sprintf("  SE      surveycore = %.15g   survey = %.15g\n", se_sc, se_sv))
  cat(sprintf("  SE ratio sc/sv = %.15g   sqrt((R-1)/R) = %.15g   sqrt((R-1)/R^?)\n",
              se_sc/se_sv, sqrt((R-1)/R)))
  cat(sprintf("  relative SE gap = %.6f%%\n", 100*(se_sc/se_sv - 1)))
  invisible(NULL)
}
cmp("JKn", "JKn", extra_sc = list(rscales = rep(1, 20)), extra_sv = list(rscales = rep(1, 20)))
cmp("bootstrap", "bootstrap")
cmp("JK2", "JK2")
cmp("JK1", "JK1")
cmp("BRR", "BRR")
```

Output:

```
<environment: namespace:survey>
getOption('survey.replicates.mse') after survey loads: [1] FALSE

## JKn  (R = 20)
  scale   surveycore = 0.95   survey = 1
  mean    surveycore = 50.4365426841604   survey = 50.4365426841604   diff = 0
  SE      surveycore = 0.240186788963527   survey = 0.2464264459334
  SE ratio sc/sv = 0.974679434480991   sqrt((R-1)/R) = 0.974679434480896   sqrt((R-1)/R^?)
  relative SE gap = -2.532057%
Warning message:
Using `all_of()` outside of a selecting function was deprecated in tidyselect
1.2.0.
ℹ See details at
  <https://tidyselect.r-lib.org/reference/faq-selection-context.html> 

## bootstrap  (R = 20)
  scale   surveycore = 0.05   survey = 0.0526315789473684
  mean    surveycore = 50.4365426841604   survey = 50.4365426841604   diff = 0
  SE      surveycore = 0.0551026284560812   survey = 0.0565341039389252
  SE ratio sc/sv = 0.974679434480991   sqrt((R-1)/R) = 0.974679434480896   sqrt((R-1)/R^?)
  relative SE gap = -2.532057%

## JK2  (R = 20)
  scale   surveycore = 1   survey = 1
  mean    surveycore = 50.4365426841604   survey = 50.4365426841604   diff = 0
  SE      surveycore = 0.246426445933424   survey = 0.2464264459334
  SE ratio sc/sv = 1.0000000000001   sqrt((R-1)/R) = 0.974679434480896   sqrt((R-1)/R^?)
  relative SE gap = 0.000000%

## JK1  (R = 20)
  scale   surveycore = 0.95   survey = 0.95
  mean    surveycore = 50.4365426841604   survey = 50.4365426841604   diff = 0
  SE      surveycore = 0.240186788963527   survey = 0.240186788963503
  SE ratio sc/sv = 1.0000000000001   sqrt((R-1)/R) = 0.974679434480896   sqrt((R-1)/R^?)
  relative SE gap = 0.000000%

## BRR  (R = 10)
  scale   surveycore = 0.1   survey = 0.1
  mean    surveycore = 50.4365426841604   survey = 50.4365426841604   diff = 0
  SE      surveycore = 0.0476228676218052   survey = 0.0476228676217971
  SE ratio sc/sv = 1.00000000000017   sqrt((R-1)/R) = 0.948683298050514   sqrt((R-1)/R^?)
  relative SE gap = 0.000000%
```

---

## M4 — `testthat::expect_failure()` composition

Script:

```r
library(testthat)
cat("testthat version:", as.character(packageVersion("testthat")), "\n")
cat("edition in effect for this script:", testthat::edition_get(), "\n\n")
try_ef <- function(lab, f) {
  r <- tryCatch({ f(); "PASSES" },
                error = function(e) paste0("FAILS: ", sub("\n.*", "", conditionMessage(e))),
                warning = function(w) paste0("WARNING ESCAPES: <", paste(class(w), collapse="/"), "> ",
                                             conditionMessage(w)))
  cat(sprintf("%-52s -> %s\n", lab, r))
}
ef <- testthat::expect_failure
try_ef("1 failing expectation", function() ef(expect_equal(1, 2)))
try_ef("2 failing expectations", function() ef({ expect_equal(1, 2); expect_equal(3, 4) }))
try_ef("1 failing + 1 passing", function() ef({ expect_equal(1, 1); expect_equal(1, 2) }))
try_ef("1 passing only", function() ef(expect_equal(1, 1)))
try_ef("0 expectations", function() ef(invisible(NULL)))
try_ef("expect_equal(tolerance=) fails -> composes",
       function() ef(expect_equal(1, 1.1, tolerance = 1e-8)))
try_ef("expect_equal(tolerance=) passes -> wrapper fails",
       function() ef(expect_equal(1, 1.0000000001, tolerance = 1e-8)))
try_ef("R warning raised inside, plus a failing expectation",
       function() ef({ warning("a bare R warning"); expect_equal(1, 2) }))
try_ef("expect_warning() INSIDE expect_failure()",
       function() ef(expect_warning(expect_equal(1, 2), "nope")))
try_ef("expect_failure() INSIDE expect_warning()",
       function() expect_warning(ef(expect_equal(1, 2)), "a bare R warning"))
try_ef("expect_warning(expr) with warning, wrapping failing expect",
       function() expect_warning(ef({ warning("a bare R warning"); expect_equal(1, 2) }),
                                 "a bare R warning"))
cat("\n--- inside test_that(), edition 3 ---\n")
testthat::local_edition(3)
res <- testthat::test_that("probe: warning inside expect_failure", {
  testthat::expect_failure({ warning("bare R warning inside"); testthat::expect_equal(1, 2) })
})
cat("test_that returned:", format(res), "\n")
```

Output:

```
testthat version: 3.3.2 
edition in effect for this script: 2 

1 failing expectation                                -> PASSES
2 failing expectations                               -> FAILS: Expected 0 successes and 1 failure.
1 failing + 1 passing                                -> FAILS: Expected 0 successes and 1 failure.
1 passing only                                       -> FAILS: Expected 0 successes and 1 failure.
0 expectations                                       -> FAILS: Expected 0 successes and 1 failure.
expect_equal(tolerance=) fails -> composes           -> PASSES
expect_equal(tolerance=) passes -> wrapper fails     -> FAILS: Expected 0 successes and 1 failure.
R warning raised inside, plus a failing expectation  -> WARNING ESCAPES: <simpleWarning/warning/condition> a bare R warning
expect_warning() INSIDE expect_failure()             -> FAILS: Expected 0 successes and 1 failure.
expect_failure() INSIDE expect_warning()             -> FAILS: Expected `ef(expect_equal(1, 2))` to produce warnings.
expect_warning(expr) with warning, wrapping failing expect -> PASSES

--- inside test_that(), edition 3 ---
── Warning: probe: warning inside expect_failure ───────────────────────────────
bare R warning inside
Backtrace:
    ▆
 1. └─testthat::expect_failure(...)
 2.   └─testthat:::capture_success_failure(expr)
 3.     └─base::withCallingHandlers(...)
Test passed with 1 success 🥇.
test_that returned: TRUE 
Ran 1/1 deferred expressions
```

The `Error in deferred_run(env)` at the tail is an artefact of calling
`test_that()` outside a testthat run. It comes after every measurement and
changes none of them.

Script, the two nesting orders and the three-wrapper shape:

```r
library(testthat); testthat::local_edition(3)
r <- function(lab, f) {
  out <- tryCatch({ f(); "PASSES" },
    error = function(e) paste0("FAILS: ", sub("\n.*", "", conditionMessage(e))),
    warning = function(w) paste0("WARNING ESCAPES: ", conditionMessage(w)))
  cat(sprintf("%-64s -> %s\n", lab, out))
}
# The two nesting orders, each with a real warning present.
r("expect_failure(expect_warning(<warns; fails>, 'boom'))",
  function() expect_failure(expect_warning({ warning("boom"); expect_equal(1, 2) }, "boom")))
r("expect_warning(expect_failure(<warns; fails>), 'boom')",
  function() expect_warning(expect_failure({ warning("boom"); expect_equal(1, 2) }), "boom"))
# Three separate wrappers, the JKn/bootstrap shape.
r("three separate expect_failure() wrappers",
  function() { expect_failure(expect_equal(1, 1.1, tolerance = 1e-8))
               expect_failure(expect_equal(2, 2.2, tolerance = 1e-6))
               expect_failure(expect_equal(3, 3.3, tolerance = 1e-6)) })
r("one wrapper round three failing expectations",
  function() expect_failure({ expect_equal(1, 1.1, tolerance = 1e-8)
                              expect_equal(2, 2.2, tolerance = 1e-6)
                              expect_equal(3, 3.3, tolerance = 1e-6) }))
```

Output:

```
expect_failure(expect_warning(<warns; fails>, 'boom'))           -> FAILS: Expected 0 successes and 1 failure.
expect_warning(expect_failure(<warns; fails>), 'boom')           -> PASSES
three separate expect_failure() wrappers                         -> PASSES
one wrapper round three failing expectations                     -> FAILS: Expected 0 successes and 1 failure.
Error in deferred_run(env) : could not find function "deferred_run"
Calls: <Anonymous>
```

---

## M5 — the current test file

```
NOT_CRAN=false Rscript -e 'r <- testthat::test_local(filter = "variance-replicate", reporter = "summary"); print(as.data.frame(r)[, c("file","test","nb","failed","skipped","warning")])'
```

24 blocks, 0 failed, 0 skipped. Block 24
(`get_corr() replicate returns NA for domain with fewer than 2 paired obs`)
carries 1 warning; it is pre-existing and touches no oracle block. The JK2
oracle block is green, which confirms G9.

## M6 — the stale line number

```
grep -n "scale_arg" R/methods-conversion.R
```

```
372:  scale_arg <- if (isTRUE(x@variables$type %in% c("BRR", "Fay"))) {
494:    scale = scale_arg,
```

`plans/issue-cleanup.md` D10 cites `R/methods-conversion.R:166`. The real site
is line 494, inside the `svrepdesign()` call. The BRR and Fay exclusion sits at
line 372. D10's claim is right; its line number is stale.

---

## M7 — the confidence-bound premise: both sides use the normal approximation

Every numerical block compares both confidence bounds. That comparison holds
only while both packages build the interval from the same distribution and the
same degrees of freedom. This section measures that they do.

### The probe

```r
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-test-data.R")

print(args(survey:::confint.svrepstat))
print(args(survey:::confint.svystat))
print(survey:::tconfint)

cat(sprintf("qt(0.975, df = Inf)  = %.17f\n", stats::qt(0.975, df = Inf)))
cat(sprintf("qnorm(0.975)         = %.17f\n", stats::qnorm(0.975)))
cat("identical: ", identical(stats::qt(0.975, df = Inf), stats::qnorm(0.975)), "\n")

d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                      design = "replicate", type = "jk1", seed = 15)
rc <- grep("^repwt_", names(d), value = TRUE)
sv <- survey::svrepdesign(weights = d$wt, repweights = d[, rc],
                          type = "JK1", mse = TRUE, data = d)
m <- survey::svymean(~y1, sv, na.rm = TRUE)
ci_default <- stats::confint(m)
ci_inf     <- stats::confint(m, df = Inf)
ci_degf    <- stats::confint(m, df = survey::degf(sv))

sc <- as_survey_replicate(d, weights = wt, repweights = all_of(rc),
                          type = "JK1", mse = TRUE)
mm <- get_means(sc, y1, variance = c("se", "ci"))
```

### The output, verbatim

```
--- 1. survey's confint methods: the df argument ---
function (object, parm, level = 0.95, df = Inf, ...) 
NULL
function (object, parm, level = 0.95, df = Inf, ...) 
NULL

--- 2. survey:::tconfint ---
function (object, parm, level = 0.95, df = Inf) 
{
    ...
    a <- (1 - level)/2
    a <- c(a, 1 - a)
    pct <- format.perc(a, 3)
    fac <- qt(a, df = df)
    ...
    ci[] <- cf[parm] + ses %o% fac
    ci
}

--- 3. qt(0.975, df = Inf) against qnorm(0.975) ---
qt(0.975, df = Inf)  = 1.95996398454005361
qnorm(0.975)         = 1.95996398454005361
identical:  TRUE 

--- 4. a JK1 design: confint() default against df = Inf and df = degf() ---
R = 20 
survey::degf(sv) = 19 
confint(m)                   = [49.965785228229571, 50.907300140091145]
confint(m, df = Inf)         = [49.965785228229571, 50.907300140091145]
confint(m, df = degf(sv))    = [49.933825957308656, 50.939259411012060]
identical(default, Inf):   TRUE 
max |default - degf|  = 0.031959270920915

--- 5. surveycore's bound against survey's default bound ---
surveycore ci_low  = 49.965785228229521   survey ci_low  = 49.965785228229571
surveycore ci_high = 50.907300140091195   survey ci_high = 50.907300140091145
max |surveycore - survey(default)| = 4.974e-14
max |surveycore - survey(degf)|    = 3.196e-02
```

The `svrepdesign()` call also raised the JK1 guess warning, as M1 records. The
deparse of `tconfint` is elided at the two `...` marks; the elided lines build
the parameter names and the result array and touch no distribution.

### What the numbers say

| Claim | Evidence |
|---|---|
| `survey` uses the normal approximation by default | `confint.svrepstat` and `confint.svystat` both carry `df = Inf`; `tconfint` calls `qt(a, df = df)` |
| `qt` at infinite df is `qnorm` | The two critical values are bit-identical |
| The default is not the design-based interval | `confint(m)` equals `confint(m, df = Inf)` and differs from `confint(m, df = degf(sv))` by `0.0319` |
| surveycore matches the default, not the design-based one | `4.974e-14` against the default; `3.196e-02` against `degf(sv) = 19` |

### surveycore's side of the premise

`grep -rn "degf <- Inf" R/` returns six sites, one per Phase 1 analysis file:

```
R/analysis-covariance.R:241:  degf <- Inf # Normal approximation; matches get_variance() / svyvar()
R/analysis-freqs.R:173:  degf <- Inf # Normal approximation; matches survey::svymean() default
R/analysis-means.R:166:  degf <- Inf # Normal approximation; matches survey::svymean() default
R/analysis-ratios.R:207:  degf <- Inf # Normal approximation; matches survey::svyratio() default
R/analysis-totals.R:166:  degf <- Inf # Normal approximation; matches survey::svytotal() default
R/analysis-variance.R:192:  degf <- Inf # Normal approximation; matches survey::svyvar() default
```

The assignment is unconditional at each site. No branch reads the design class.

`.degf(design)`, which computes design-based degrees of freedom, has nine call
sites. Seven of them fill the `cell_df` attribute of the result, and each one
sits inside an `is_taylor_like` guard:

```
R/analysis-corr.R:836        R/analysis-covariance.R:621
R/analysis-freqs.R:509       R/analysis-means.R:327
R/analysis-quantiles.R:432   R/analysis-ratios.R:427
R/analysis-totals.R:324
```

The guard is the same two lines at every site:

```r
is_taylor_like <- S7::S7_inherits(design, survey_taylor) ||
  S7::S7_inherits(design, survey_twophase)
```

A replicate design takes the else branch, which writes `NULL` and leaves the
attribute at `Inf`. The eighth call site is `R/glm.R:587`, inside
`survey_glm()`, which no oracle block builds. The ninth is a comment. So the
replicate path reaches `.degf()` through no analysis function the blocks call.

### The forward risk

The premise is a fact about today's source and nothing enforces it. A later PR
that moves the replicate path to design-based df breaks every confidence-bound
assertion in the file at once, by about `3.2e-02` against a `1e-6` tolerance —
roughly four orders of magnitude above it. The failure looks the same as a wrong
scale: the point estimate holds, the bounds move. Such a PR must revisit the
oracle blocks and the tolerance section with it.

---

## M8 — `type = "other"`: the two sides agree

M1 measures each side's stored scale for `other` on its own. This section builds
both sides on one fixture and compares the four numbers a numerical oracle block
compares. No `other` block exists in the test file today, so nothing else
measures this.

### The probe

```r
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-test-data.R")

d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                      design = "replicate", type = "jk1", seed = 15)
rc <- grep("^repwt_", names(d), value = TRUE)

sc <- as_survey_replicate(d, weights = wt, repweights = all_of(rc),
                          type = "other", mse = TRUE)
sv <- survey::svrepdesign(weights = d$wt, repweights = d[, rc],
                          type = "other", mse = TRUE, data = d)

m  <- get_means(sc, y1, variance = c("se", "ci"))
sm <- survey::svymean(~y1, sv, na.rm = TRUE)
ci <- stats::confint(sm)
```

The `svrepdesign()` warning is captured with a calling handler, so the probe can
print it and still continue.

### The output, verbatim

```
R = 20 

surveycore stored scale = 1 
survey warnings on build:
[1] "scale or rscales not specified, set to 1"
survey stored scale = 1 
survey rscales[1:3] = 1 1 1 

point    surveycore = 50.436542684160358   survey = 50.436542684160358   diff = 0.000e+00
se       surveycore = 0.246426445933424   survey = 0.246426445933400   diff = 2.393e-14
ci_low   surveycore = 49.953555725292638   survey = 49.953555725292688   diff = 4.974e-14
ci_high  surveycore = 50.919529643028078   survey = 50.919529643028028   diff = 4.974e-14
```

### What the numbers say

| Quantity | Absolute difference | Tolerance for that quantity | Margin |
|---|---|---|---|
| Point estimate | `0` | `1e-10` | exact |
| Standard error | `2.393e-14` | `1e-8` | about 6 orders below |
| Lower bound | `4.974e-14` | `1e-6` | about 8 orders below |
| Upper bound | `4.974e-14` | `1e-6` | about 8 orders below |

Both sides store `scale = 1`, and `survey` fills `rscales` with `1`. The warning
text is `scale or rscales not specified, set to 1`, which matches the fragment
the `other` block asserts. So the `other` block is a plain oracle block: it needs
no `expect_failure()` wrapper.

The surveycore standard error, `0.246426445933424`, is the number M3 records for
JK2 at `R = 20`. That follows: M3's JK2 row runs on the same `jk1` columns at the
same seed, and both types store `scale = 1`. The `other` block still asserts
against `survey`, never against the JK2 block.
