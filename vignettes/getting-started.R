## ----setup, include=FALSE-----------------------------------------------------
library(surveycore)
knitr::opts_chunk$set(
  comment = "#>"
)
has_surveytidy <- requireNamespace("surveytidy", quietly = TRUE)

## ----as_survey----------------------------------------------------------------
gss_svy <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssps
)

gss_svy


## ----replicate----------------------------------------------------------------
pew_jewish_svy <- as_survey_replicate(
  pew_jewish_2020,
  weights = extweight,
  repweights = extweight1:extweight100,
  type = "JK1"
)

pew_jewish_svy

## ----srs----------------------------------------------------------------------
set.seed(101)
N <- 400 # total schools in district
n <- 80 # schools sampled

school_survey <- data.frame(
  school_id = sample(seq_len(N), n),
  avg_score = round(rnorm(n, mean = 72, sd = 11), 1),
  pct_frpl = round(runif(n, 0.10, 0.85), 2), # % free/reduced price lunch
  enrollment = round(runif(n, 180, 850)),
  sw = N / n, # equal sampling weight = 400/80 = 5.0
  fpc = N # population size for FPC
)

school_svy <- as_survey(
  school_survey,
  weights = sw, # each sampled school represents 5 schools in the population
  fpc = fpc # reduces SEs: we sampled 20% of the population
)

school_svy

## ----calibrated---------------------------------------------------------------
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

ns_wave1_svy

## ----nwtco, eval=requireNamespace("survival", quietly=TRUE)-------------------
nwtco <- survival::nwtco

# in.subcohort is stored as 0/1 — must be logical for as_survey_twophase()
nwtco$in.subcohort <- as.logical(nwtco$in.subcohort)

# Phase 1: all 4,028 enrolled patients (each patient is their own unit)
phase1 <- as_survey(nwtco, ids = seqno)

# Phase 2: subcohort, with Phase 2 sampling stratified by relapse status
nwtco_svy <- as_survey_twophase(
  phase1,
  strata2 = rel, # Phase 2 strata: cases (rel=1) vs. non-cases (rel=0)
  subset = in.subcohort, # Logical column: TRUE = selected into Phase 2
  method = "full"
)

nwtco_svy

## ----freqs-basic--------------------------------------------------------------

get_freqs(ns_wave1_svy, consider_trump)


## ----freqs-multi--------------------------------------------------------------
get_freqs(ns_wave1_svy, c(news_sources_facebook:news_sources_other))


## -----------------------------------------------------------------------------
ns_wave1_svy |>
  get_freqs(
    c(news_sources_facebook:news_sources_other),
    names_to = "news_source",
    values_to = "choice"
  )


## ----means-basic--------------------------------------------------------------
# Mean discrimination against blacks
get_means(ns_wave1_svy, discrimination_blacks)

## -----------------------------------------------------------------------------

get_totals(ns_wave1_svy)


## -----------------------------------------------------------------------------

get_totals(pew_jewish_svy)


## -----------------------------------------------------------------------------
get_totals(pew_jewish_svy, group = age4cat)

## ----corr-basic, eval=has_surveytidy------------------------------------------


ns_wave1_svy |>
  # drop NAs
  drop_na(cand_favorability_trump, cand_favorability_biden) |>
  # remove "Not sure" responses (coded 999)
  filter_out(cand_favorability_trump == 999 | cand_favorability_biden == 999) |>
  # calculate correlations
  get_corr(c(cand_favorability_trump, cand_favorability_biden))


## ----corr-multi, eval=has_surveytidy------------------------------------------
ns_wave1_svy |>
  drop_na(c(cand_favorability_trump:cand_favorability_pence)) |>
  # filter out any respondents who said "Not sure"
  filter_out(
    dplyr::if_any(
      c(cand_favorability_trump:cand_favorability_pence),
      ~ .x == 999
    )
  ) |>
  get_corr(c(cand_favorability_trump:cand_favorability_pence))

## ----corr-wide, eval=has_surveytidy-------------------------------------------
ns_wave1_svy |>
  drop_na(c(cand_favorability_trump:cand_favorability_pence)) |>
  # filter out any respondents who said "Not sure"
  filter_out(
    dplyr::if_any(
      c(cand_favorability_trump:cand_favorability_pence),
      ~ .x == 999
    )
  ) |>
  get_corr(c(cand_favorability_trump:cand_favorability_pence), format = "wide")

## ----ratios-basic, eval=has_surveytidy----------------------------------------
ns_wave1_svy |>
  # drop NAs
  drop_na(cand_favorability_trump, cand_favorability_biden) |>
  # remove people who don't know enough about Trump or Biden
  filter_out(cand_favorability_trump == 999 | cand_favorability_biden == 999) |>
  # get the ratio of favorability
  get_ratios(
    numerator = cand_favorability_trump,
    denominator = cand_favorability_biden
  )

## ----quantiles-basic----------------------------------------------------------
# Quartiles and median of age (default probs = c(0.25, 0.5, 0.75))
get_quantiles(ns_wave1_svy, age)

## ----quantiles-median---------------------------------------------------------
get_quantiles(ns_wave1_svy, age, probs = 0.5)

## ----quantiles-deciles--------------------------------------------------------
get_quantiles(ns_wave1_svy, age, probs = seq(0.1, 0.9, 0.1))

## ----group-means--------------------------------------------------------------
get_freqs(ns_wave1_svy, consider_trump, group = pid3)

## ----variance-options---------------------------------------------------------
get_means(
  ns_wave1_svy,
  age,
  variance = c("se", "ci", "moe"),
  conf_level = 0.9
)


## ----n-weighted---------------------------------------------------------------
get_freqs(pew_jewish_svy, age4cat, n_weighted = TRUE)


## ----eval=FALSE---------------------------------------------------------------
# pak::pak("jacobdennen/surveytidy")

## ----eval=has_surveytidy------------------------------------------------------

ns_wave1_svy |>
  # rename the variable
  rename(fav_biden = cand_favorability_biden) |>
  # let's start with a simple example of adding 1 to favorability of Biden
  mutate(fav_biden_1 = fav_biden + 1) |>
  # now let's look at the results
  select(fav_biden, fav_biden_1)


## ----eval=has_surveytidy------------------------------------------------------
ns_wave1_svy <- ns_wave1_svy |>
  # rename trump favorability
  rename(fav_trump = cand_favorability_trump) |>
  mutate(
    # convert favorability of Trump to a 3 level factor
    fav_trump_f3 = dplyr::recode_values(
      fav_trump,
      c(1:2) ~ "Favorable",
      c(3:4) ~ "Unfavorable",
      999 ~ "Haven't heard enough"
    ),
    age_f4 = dplyr::case_when(
      age < 30 ~ "18-29",
      age < 50 ~ "30-49",
      age < 65 ~ "50-64",
      age > 64 ~ "65+",
      .default = NA_character_
    )
  )

ns_wave1_svy |> select(fav_trump, fav_trump_f3, age, age_f4)


## ----surveytidy-group_by, eval=has_surveytidy---------------------------------
ns_wave1_svy |>
  group_by(age_f4) |>
  get_freqs(fav_trump_f3)

ns_wave1_svy |>
  get_freqs(fav_trump_f3, group = age_f4)


## ----filter, eval=has_surveytidy----------------------------------------------
ns_wave1_svy |>
  # keep only people under 30 in the domain
  filter(age < 30) |>
  # calculate frequencies
  get_freqs(fav_trump_f3)
