## ----setup, include=FALSE-----------------------------------------------------
library(surveycore)
knitr::opts_chunk$set(comment = "#>")

has_survey <- requireNamespace("survey", quietly = TRUE)
has_srvyr <- requireNamespace("srvyr", quietly = TRUE)
has_surveytidy <- requireNamespace("surveytidy", quietly = TRUE)

if (has_survey) {
  library(survey)
  data(api) # loads apisrs, apistrat, apiclus1
}
if (has_srvyr) {
  library(srvyr)
}

## ----srs-survey, eval=has_survey----------------------------------------------
srs_sv <- svydesign(ids = ~1, fpc = ~fpc, weights = ~pw, data = apisrs)
srs_sv

## ----srs-srvyr, eval=has_survey && has_srvyr----------------------------------
srs_srvyr <- apisrs |> as_survey_design(ids = 1, fpc = fpc, weights = pw)
srs_srvyr

## ----srs-sc, eval=has_survey--------------------------------------------------
srs_sc <- as_survey_srs(apisrs, weights = pw, fpc = fpc)
srs_sc

## ----strat-survey, eval=has_survey--------------------------------------------
strat_sv <- svydesign(
  ids = ~1,
  strata = ~stype,
  weights = ~pw,
  fpc = ~fpc,
  data = apistrat
)
strat_sv

## ----strat-srvyr, eval=has_survey && has_srvyr--------------------------------
strat_srvyr <- apistrat |>
  as_survey_design(strata = stype, weights = pw, fpc = fpc)
strat_srvyr

## ----strat-sc, eval=has_survey------------------------------------------------
strat_sc <- as_survey(apistrat, strata = stype, weights = pw, fpc = fpc)
strat_sc

## ----clus-survey, eval=has_survey---------------------------------------------
clus_sv <- svydesign(ids = ~dnum, fpc = ~fpc, weights = ~pw, data = apiclus1)
clus_sv

## ----clus-srvyr, eval=has_survey && has_srvyr---------------------------------
clus_srvyr <- apiclus1 |>
  as_survey_design(ids = dnum, fpc = fpc, weights = pw)
clus_srvyr

## ----clus-sc, eval=has_survey-------------------------------------------------
clus_sc <- as_survey(apiclus1, ids = dnum, fpc = fpc, weights = pw)
clus_sc

## ----repwt-acs-survey, eval=has_survey----------------------------------------
acs_sv <- svrepdesign(
  data = acs_pums_wy,
  weights = ~pwgtp,
  repweights = "pwgtp[0-9]+", # regex string
  type = "successive-difference",
  combined.weights = TRUE
)
acs_sv

## ----repwt-acs-srvyr, eval=has_survey && has_srvyr----------------------------
acs_srvyr <- acs_pums_wy |>
  as_survey_replicate(
    weights = pwgtp,
    repweights = matches("^pwgtp[0-9]+$"), # tidyselect
    type = "successive-difference",
    combined_weights = TRUE
  )
acs_srvyr

## ----repwt-acs-sc-------------------------------------------------------------
acs_sc <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = tidyselect::matches("^pwgtp[0-9]+$"), # tidyselect
  type = "successive-difference"
)
acs_sc

## ----repwt-pew-sc-------------------------------------------------------------
pew_sc <- as_survey_replicate(
  pew_jewish_2020,
  weights = extweight,
  repweights = extweight1:extweight100,
  type = "JK1"
)
pew_sc

## ----calib-survey, eval=has_survey--------------------------------------------
# No way to signal this is calibrated or non-probability
ns_sv <- svydesign(ids = ~1, weights = ~weight, data = ns_wave1)

## ----calib-srvyr, eval=has_survey && has_srvyr--------------------------------
ns_srvyr <- ns_wave1 |> as_survey_design(weights = weight)

## ----calib-sc-----------------------------------------------------------------
# as_survey_nonprob() makes the design type explicit
ns_sc <- as_survey_nonprob(ns_wave1, weights = weight)
ns_sc

## ----means-survey, eval=has_survey--------------------------------------------
svyby(~discrimination_blacks, ~pid3, ns_sv, svymean, na.rm = TRUE)

## ----means-srvyr, eval=has_survey && has_srvyr--------------------------------
ns_srvyr |>
  group_by(pid3) |>
  summarise(
    m = survey_mean(discrimination_blacks, vartype = "ci", na.rm = TRUE)
  )

## ----means-sc-----------------------------------------------------------------
get_means(ns_sc, discrimination_blacks, group = pid3)

## ----freqs-survey, eval=has_survey--------------------------------------------
svymean(~ factor(consider_trump), ns_sv, na.rm = TRUE)

## ----freqs-srvyr, eval=has_survey && has_srvyr--------------------------------
ns_srvyr |>
  group_by(consider_trump) |>
  summarise(pct = survey_mean(na.rm = TRUE))

## ----freqs-sc-----------------------------------------------------------------
get_freqs(ns_sc, consider_trump)
