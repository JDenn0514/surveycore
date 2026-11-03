# Stage 0 measurement script for issue #243 (replicate-fay-rho).
#
# Run from the worktree root:
#   Rscript .surveycore-workspace/runs/2026-09-30-replicate-fay-rho/measure-fay.R \
#     > .surveycore-workspace/runs/2026-09-30-replicate-fay-rho/measure-fay-output.txt 2>&1
#
# The script changes no file. It prints every value comprehension.md marks
# as PENDING, under the section numbers M1 to M9 that comprehension.md uses.

pkgload::load_all(".", quiet = TRUE, helpers = TRUE)
if (!exists("make_survey_data")) {
  source("tests/testthat/helper-test-data.R")
}

say <- function(...) cat(..., "\n", sep = "")
show_try <- function(label, expr) {
  warns <- character(0)
  res <- withCallingHandlers(
    tryCatch(expr, error = function(e) paste("ERROR:", conditionMessage(e))),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  say("-- ", label)
  if (length(warns) > 0L) say("   warnings: ", paste(warns, collapse = " | "))
  res
}
src_lines <- function(fn, pattern) {
  txt <- deparse(fn)
  hit <- grep(pattern, txt)
  for (i in hit) say(sprintf("%4d: %s", i, txt[[i]]))
}

say("== M0 versions")
say("R: ", R.version.string)
say("survey: ", as.character(utils::packageVersion("survey")))
say("surveycore: ", as.character(utils::packageVersion("surveycore")))

say("\n== M1 survey:::svrepdesign.default, lines naming rho, Fay or scale")
src_lines(survey:::svrepdesign.default, "rho|Fay|scale")

say("\n== M1b survey:::svrVar, whole body")
print(survey:::svrVar)

say("\n== M1c as.svrepdesign source, lines naming rho, Fay or type")
asrep <- tryCatch(
  getFromNamespace("as.svrepdesign.default", "survey"),
  error = function(e) survey::as.svrepdesign
)
src_lines(asrep, "rho|Fay|type")

# Fixture: the same frame as the current Fay block in
# tests/testthat/test-variance-replicate.R (seed 15, R = 10).
d <- make_survey_data(
  n = 200,
  n_psu = 20,
  n_strata = 4,
  design = "replicate",
  type = "fay",
  seed = 15
)
cols <- grep("^repwt_", names(d), value = TRUE)
R <- length(cols)
say("\n== fixture: make_survey_data(n = 200, n_psu = 20, n_strata = 4, ",
    "design = 'replicate', type = 'fay', seed = 15); R = ", R)

sv_fay <- function(rho, mse = TRUE, ...) {
  survey::svrepdesign(
    weights = d$wt, repweights = d[, cols], type = "Fay", rho = rho,
    mse = mse, data = d, ...
  )
}
sc_fay <- function(rho, mse = TRUE) {
  as_survey_replicate(
    d, weights = wt, repweights = tidyselect::all_of(cols), type = "Fay",
    scale = 1 / (R * (1 - rho)^2), mse = mse
  )
}

say("\n== M2 SE agreement: survey Fay(rho) vs surveycore scale 1/(R(1-rho)^2)")
for (mse in c(TRUE, FALSE)) {
  for (rho in c(0, 0.3, 0.5, 0.9)) {
    sv <- show_try(sprintf("svrepdesign Fay rho=%s mse=%s", rho, mse),
                   sv_fay(rho, mse))
    sm <- survey::svymean(~y1, sv)
    ci <- confint(sm)
    sc <- get_means(sc_fay(rho, mse), y1, variance = c("se", "ci"))
    say(sprintf(
      "   sv$scale=%.15g sv$rho=%s formula=%.15g",
      sv$scale, format(sv$rho), 1 / (R * (1 - rho)^2)
    ))
    say(sprintf(
      "   mean diff=%.3e  se sv=%.15g sc=%.15g diff=%.3e  ci diffs=%.3e %.3e",
      sc$mean - coef(sm)[[1]], survey::SE(sm)[[1]], sc$se,
      sc$se - survey::SE(sm)[[1]], sc$ci_low - ci[1], sc$ci_high - ci[2]
    ))
  }
}

say("\n== M3 rho = 0 Fay equals BRR on the survey side")
sv_brr <- show_try("svrepdesign BRR", survey::svrepdesign(
  weights = d$wt, repweights = d[, cols], type = "BRR", mse = TRUE, data = d
))
say(sprintf(
  "   BRR se=%.15g  Fay(0) se=%.15g  BRR$rho=%s  names has rho: %s",
  survey::SE(survey::svymean(~y1, sv_brr))[[1]],
  survey::SE(survey::svymean(~y1, sv_fay(0)))[[1]],
  format(sv_brr$rho), "rho" %in% names(sv_brr)
))

say("\n== M4 a supplied scale with type = 'Fay'")
sv <- show_try("Fay rho=0.3 scale=99", sv_fay(0.3, scale = 99))
say("   sv$scale=", format(sv$scale, digits = 15))

say("\n== M5 rho supplied for other types")
for (ty in c("BRR", "JK1", "JK2", "bootstrap", "ACS", "other")) {
  sv <- show_try(paste("type", ty, "rho = 0.3"), survey::svrepdesign(
    weights = d$wt, repweights = d[, cols], type = ty, rho = 0.3,
    mse = TRUE, data = d
  ))
  if (!is.character(sv)) say("   $rho=", format(sv$rho), " $scale=", sv$scale)
}

say("\n== M6 survey's own validation of rho for type = 'Fay'")
for (bad in list(1, -0.2, 1.5, NA_real_, c(0.1, 0.2), "a", 0L, TRUE)) {
  sv <- show_try(paste("rho =", deparse(bad)), sv_fay(bad))
  if (is.character(sv)) say("   ", sv) else say("   $scale=", sv$scale)
}

say("\n== M7 as.svrepdesign on a Taylor design")
set.seed(421L)
td <- data.frame(
  strata = rep(1:6, each = 10L), psu = rep(1:12, each = 5L),
  wt = runif(60, 1, 4), y1 = rnorm(60, 10, 2)
)
tay <- survey::svydesign(
  ids = ~psu, strata = ~strata, weights = ~wt, data = td, nest = TRUE
)
for (args in list(
  list(type = "Fay", fay.rho = 0.3),
  list(type = "BRR"),
  list(type = "BRR", fay.rho = 0.3)
)) {
  src <- show_try(deparse(args), do.call(
    survey::as.svrepdesign, c(list(tay), args)
  ))
  if (!is.character(src)) {
    say(sprintf(
      "   $type=%s $rho=%s $scale=%.15g combined.weights=%s R=%d",
      src$type, format(src$rho), src$scale, src$combined.weights,
      ncol(src$repweights)
    ))
  } else {
    say("   ", src)
  }
}

say("\n== M8 surveycore today: from_svydesign on a survey Fay design")
src <- survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)
imp <- from_svydesign(src)
say("   @variables names: ", paste(names(imp@variables), collapse = ", "))
say("   @variables$scale=", format(imp@variables$scale, digits = 15))
say("   @variables$rho present: ", "rho" %in% names(imp@variables))
say(sprintf(
  "   imported SE=%.15g  survey SE=%.15g",
  get_means(imp, y1, variance = "se")$se,
  survey::SE(survey::svymean(~y1, src))[[1]]
))

say("\n== M9 surveycore today: as_survey_replicate(type = 'Fay'), no rho")
leg <- as_survey_replicate(
  d, weights = wt, repweights = tidyselect::all_of(cols), type = "Fay"
)
say("   stored scale=", format(leg@variables$scale, digits = 15),
    " (1/R = ", 1 / R, ")")
for (rho in c(0.3, 0.5)) {
  se_old <- get_means(leg, y1, variance = "se")$se
  se_new <- get_means(sc_fay(rho), y1, variance = "se")$se
  say(sprintf(
    "   rho=%s: old se=%.15g new se=%.15g ratio new/old=%.15g 1/(1-rho)=%.15g",
    rho, se_old, se_new, se_new / se_old, 1 / (1 - rho)
  ))
}
say("   print() of the legacy design:")
print(leg)
