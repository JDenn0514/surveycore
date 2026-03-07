## Democracy Fund + UCLA Nationscape — Phase 1 (Waves 1–24)
## Prepare survey data with cleaned metadata
##
## Source: Democracy Fund Voter Study Group / UCLA
## URL: https://www.voterstudygroup.org/data/nationscape
## License: Academic research use; see data-raw/nationscape/ for user guide.
##
## Phase 1 coverage: July 18, 2019 – December 26, 2019 (24 weekly waves)
## Waves: ns20190718 through ns20191226
## Sample: ~6,250 completed interviews per wave (~150,000 total)
## Mode: Online (Lucid respondent exchange platform)
## Design: Non-probability quota sample with raking weights
##   Weight variable: weight (calibrated to ACS + 2016 vote targets)
##   No cluster or strata variables
##
## Output: A named list `ns_phase1` with one entry per wave (each is a
##   data frame with cleaned metadata). Each list entry is named by wave ID.
##
## On variance estimation:
##   The Nationscape is a calibrated non-probability sample. Use
##   as_survey_calibrated(data, weights = weight) — designed for exactly this
##   use case. Current variance uses a conservative SRS approximation
##   (Rivers & Bailey 2009); bootstrap re-calibration variance (Deville &
##   Sarndal 1992) will be available in Phase 2.5 via surveywts.
##
## Run from the package root: source("data-raw/prepare-nationscape-phase1.R")

library(haven)
library(stringr)
devtools::load_all(here::here(), quiet = TRUE)
source(file.path(here::here(), "data-raw", "prepare-nationscape-helpers.R"))

PHASE1_DIR <- file.path(here::here(), "data-raw", "nationscape", "phase_1_v20210301")

if (!dir.exists(PHASE1_DIR)) {
  stop(
    "Phase 1 data not found at: ", PHASE1_DIR, "\n",
    "Download the Nationscape data from:\n",
    "  https://www.voterstudygroup.org/data/nationscape\n",
    "and extract to data-raw/nationscape/."
  )
}

## ---- Phase 1 battery definitions ----
##
## Maps variable names to item labels and shared question prefaces.
## Source: codebook_ns*.pdf files in each wave's folder.
## Labels are in sentence case; proper nouns preserved per PROPER_NOUN_LABELS.

BATTERIES_PHASE1 <- list(

  ## News sources (select-all-that-apply)
  news_sources = list(
    preface = "We're interested in where you might have heard news about politics in the last week. Please indicate which of the following sources you used.",
    vars = c(
      news_sources_facebook       = "Social media (e.g., Facebook, Twitter)",
      news_sources_cnn            = "CNN",
      news_sources_msnbc          = "MSNBC",
      news_sources_fox            = "Fox News (cable)",
      news_sources_network        = "Network news (ABC, CBS, NBC) or PBS",
      news_sources_localtv        = "Local TV station",
      news_sources_telemundo      = "Telemundo or Univision",
      news_sources_npr            = "NPR",
      news_sources_amtalk         = "AM talk radio station",
      news_sources_new_york_times = "National newspaper (e.g., New York Times, Wall Street Journal, USA Today)",
      news_sources_local_newspaper = "Local newspaper",
      news_sources_other          = "Other",
      news_sources_other_TEXT     = "Other (write-in)"
    )
  ),

  ## Group favorability ratings
  group_fav = list(
    preface = "Here are the names of some groups that are in the news from time to time. How favorable is your impression of each?",
    vars = c(
      group_favorability_whites       = "Whites",
      group_favorability_blacks       = "Blacks",
      group_favorability_latinos      = "Latinos",
      group_favorability_asians       = "Asians",
      group_favorability_christians   = "Christians",
      group_favorability_socialists   = "Socialists",
      group_favorability_muslims      = "Muslims",
      group_favorability_labor_unions = "Labor unions",
      group_favorability_the_police   = "The police",
      group_favorability_undocumented = "Undocumented immigrants",
      group_favorability_lgbt         = "Gays and lesbians",
      group_favorability_republicans  = "Republicans",
      group_favorability_democrats    = "Democrats"
    )
  ),

  ## Candidate favorability ratings
  cand_fav = list(
    preface = "How favorable is your impression of each of the following people?",
    vars = c(
      cand_favorability_trump     = "Donald Trump",
      cand_favorability_obama     = "Barack Obama",
      cand_favorability_cortez    = "Alexandria Ocasio-Cortez",
      cand_favorability_biden     = "Joe Biden",
      cand_favorability_harris    = "Kamala Harris",
      cand_favorability_buttigieg = "Pete Buttigieg",
      cand_favorability_warren    = "Elizabeth Warren",
      cand_favorability_sanders   = "Bernie Sanders",
      cand_favorability_pence     = "Mike Pence"
    )
  ),

  ## Trump head-to-head matchups
  trump_matchup = list(
    preface = "If the general election for president of the United States was a contest between Donald Trump and the following candidate, who would you vote for?",
    vars = c(
      trump_biden      = "Joe Biden",
      trump_sanders    = "Bernie Sanders",
      trump_harris     = "Kamala Harris",
      trump_warren     = "Elizabeth Warren",
      trump_buttigieg  = "Pete Buttigieg",
      trump_booker     = "Cory Booker",
      trump_castro     = "Julian Castro",
      trump_gabbard    = "Tulsi Gabbard",
      trump_gillibrand = "Kirsten Gillibrand",
      trump_orourke    = "Beto O'Rourke"
    )
  ),

  ## Pence head-to-head matchups
  ##
  ## Note: the raw .sav uses variable names (e.g. "pence_biden") as labels —
  ## no meaningful label was stored. Set them explicitly here.
  pence_matchup = list(
    preface = "If the general election for president of the United States was a contest between Mike Pence and the following candidate, who would you vote for?",
    vars = c(
      pence_biden      = "Joe Biden",
      pence_buttigieg  = "Pete Buttigieg",
      pence_harris     = "Kamala Harris",
      pence_sanders    = "Bernie Sanders",
      pence_warren     = "Elizabeth Warren"
    )
  ),

  ## Candidate truth-telling
  cand_truth = list(
    preface = "Do you think the following candidates care about telling the truth, or not?",
    vars = c(
      cand_truth_donald_trump     = "Donald Trump",
      cand_truth_elizabeth_warren = "Elizabeth Warren",
      cand_truth_joe_biden        = "Joe Biden",
      cand_truth_bernie_sanders   = "Bernie Sanders",
      cand_truth_pete_buttigieg   = "Pete Buttigieg",
      cand_truth_kamala_harris    = "Kamala Harris"
    )
  ),

  ## Candidate facts vs. hunches
  cand_facts = list(
    preface = "Do you think the following candidates rely on their hunches when making decisions, or do they rely on facts and evidence?",
    vars = c(
      cand_facts_donald_trump     = "Donald Trump",
      cand_facts_elizabeth_warren = "Elizabeth Warren",
      cand_facts_joe_biden        = "Joe Biden",
      cand_facts_bernie_sanders   = "Bernie Sanders",
      cand_facts_pete_buttigieg   = "Pete Buttigieg",
      cand_facts_kamala_harris    = "Kamala Harris"
    )
  ),

  ## Racial attitudes (agree/disagree scale)
  racial_attitudes = list(
    preface = "Please tell us whether you agree or disagree with the following statements.",
    vars = c(
      racial_attitudes_tryhard     = "Irish, Italians, Jewish, and many other minorities overcame prejudice and worked their way up. Blacks should do the same without any special favors.",
      racial_attitudes_generations = "Generations of slavery and discrimination have created conditions that make it difficult for Blacks to work their way out of the lower class.",
      racial_attitudes_marry       = "I prefer that my close relatives marry spouses from their same race.",
      racial_attitudes_date        = "I think it's alright for Blacks and Whites to date each other."
    )
  ),

  ## Gender attitudes (agree/disagree scale)
  gender_attitudes = list(
    preface = "Please tell us how much you agree or disagree with the following statements about gender.",
    vars = c(
      gender_attitudes_maleboss    = "I would be more comfortable having a man as a boss than a woman.",
      gender_attitudes_logical     = "Women are just as capable of thinking logically as men.",
      gender_attitudes_opportunity = "Increased opportunities for women have significantly improved the quality of life in our society.",
      gender_attitudes_complain    = "Women who complain about harassment often cause more problems than they solve."
    )
  ),

  ## Discrimination perceptions
  discrimination = list(
    preface = "How much discrimination is there in the United States today against each of the following groups?",
    vars = c(
      discrimination_blacks     = "Blacks",
      discrimination_whites     = "Whites",
      discrimination_muslims    = "Muslims",
      discrimination_christians = "Christians",
      discrimination_women      = "Women",
      discrimination_men        = "Men"
    )
  ),

  ## Policy battery 1: agreement/disagreement
  policy_1 = list(
    preface = "We'd like to know whether you agree or disagree with the following policies.",
    vars = c(
      wall              = "Build a wall on the southern US border",
      cap_carbon        = "Cap carbon emissions to combat climate change",
      environment       = "Make a large-scale government investment in technology to protect the environment",
      guns_bg           = "Require background checks for all gun purchases",
      mctaxes           = "Cut taxes for families making less than $100,000 per year",
      estate_tax        = "Eliminate the estate tax",
      raise_upper_tax   = "Raise taxes on families making over $600,000",
      college           = "Ensure that all students can graduate from state colleges debt free",
      abortion_waiting  = "Require a waiting period and ultrasound before an abortion can be obtained",
      abortion_conditions = "Permit abortion in cases other than rape, incest, or when the woman's life is at risk",
      abortion_insurance  = "Allow employers to decline coverage of abortions in insurance plans",
      gun_registry           = "Create a public government registry of gun ownership",
      immigration_separation = "Separate children from their parents when parents can be prosecuted for illegal border crossing",
      immigration_system     = "Shift from a more family-based to a more merit-based immigration system",
      immigration_wire       = "Require proof of citizenship or legal residence to wire money to another country",
      maternityleave    = "Require companies to provide 12 weeks of paid maternity leave for employees",
      muslimban         = "Ban people from predominantly Muslim countries from entering the United States",
      oil_and_gas       = "Remove barriers to domestic oil and gas drilling",
      right_to_work     = "Allow people to work in unionized workplaces without paying union dues",
      ten_commandments  = "Allow the display of the Ten Commandments in public schools and courthouses",
      trans_military    = "Allow transgender people to serve in the military",
      vouchers          = "Provide tax-funded vouchers to be used for private or religious schools"
    )
  ),

  ## Policy battery 2: "And what about these policies?"
  policy_2 = list(
    preface = "And what about these policies?",
    vars = c(
      guaranteed_jobs  = "Guarantee jobs for all Americans",
      green_new_deal   = "Enact a Green New Deal",
      impeach_trump    = "Impeach President Trump",
      israel           = "Withdraw military support for the state of Israel",
      marijuana        = "Legalize marijuana",
      medicare_for_all = "Enact Medicare-for-All",
      military_size    = "Reduce the size of the US military",
      minwage          = "Raise the minimum wage to $15/hour",
      uctaxes2         = "Raise taxes on families making over $250,000",
      reparations      = "Grant reparations payments to the descendants of slaves",
      trade            = "Limit trade with other countries"
    )
  ),

  ## Policy battery 3: "Finally, what about these policies?"
  policy_3 = list(
    preface = "Finally, what about these policies?",
    vars = c(
      abortion_never      = "Never permit abortion",
      late_term_abortion  = "Permit late term abortion",
      deportation         = "Deport all undocumented immigrants",
      ban_guns            = "Ban all guns",
      ban_assault_rifles  = "Ban assault rifles",
      limit_magazines     = "Limit gun magazines to 10 bullets",
      gov_insurance       = "Provide government-run health insurance to all Americans",
      public_option       = "Provide the option to purchase government-run insurance to all Americans",
      health_subsidies    = "Subsidize health insurance for lower income people not receiving Medicaid",
      path_to_citizenship = "Create a path to citizenship for all undocumented immigrants",
      dreamers            = "Create a path to citizenship for undocumented immigrants brought here as children (DREAMers)"
    )
  ),

  ## Democratic primary candidate ranking
  rank_dems = list(
    preface = "Please rank your top 3 Democratic presidential candidates.",
    vars = c(
      rank_dems_1 = "Rank 1",
      rank_dems_2 = "Rank 2",
      rank_dems_3 = "Rank 3"
    )
  ),

  ## Religion question (selected choice + write-in split into two variables)
  religion = list(
    preface = "What is your present religion, if any?",
    vars = c(
      religion            = "Selected choice",
      religion_other_text = "Write-in (something else)"
    )
  ),

  ## Vote in 2016 (selected choice + write-in)
  vote_2016 = list(
    preface = "Now take a minute and think back to the 2016 Presidential election. In that election, who did you vote for?",
    vars = c(
      vote_2016           = "Selected choice",
      vote_2016_other_text = "Write-in (other)"
    )
  ),

  ## Party identification follow-ups
  ##
  ## pid3 (Democrat / Republican / Independent / Something else) is a
  ## standalone question. These three variables are follow-ups asked
  ## conditionally based on the pid3 response.
  pid_followup = list(
    preface = "Follow-up to party identification question (pid3).",
    vars = c(
      strength_democrat   = "Strength of Democratic identification",
      strength_republican = "Strength of Republican identification",
      lean_independent    = "Partisan lean of independents"
    )
  ),

  ## Employment question (selected choice + write-in)
  employment = list(
    preface = "Which of the following best describes your current employment status?",
    vars = c(
      employment            = "Selected choice",
      employment_other_text = "Write-in (other)"
    )
  )
)

## ---- Main: load and process all Phase 1 waves ----

ns_phase1 <- load_phase_waves(PHASE1_DIR, BATTERIES_PHASE1, "Phase 1")

## ---- Save Wave 1 as package data ----
##
## Bundle the first wave (ns20190718, July 18, 2019) as `ns_wave1` for use
## in package examples, vignettes, and tests. Only one wave is bundled
## because 24 waves × ~6,250 rows would be too large for a CRAN package.
## For cross-wave analysis, use saveRDS() locally (see usage notes below).

ns_wave1 <- ns_phase1[["ns20190718"]]

message("Saving ns_wave1 to data/...")
usethis::use_data(ns_wave1, overwrite = TRUE)
message(
  "Done. ns_wave1: ", nrow(ns_wave1), " rows x ", ncol(ns_wave1), " cols\n",
  "  Design: as_survey(ns_wave1, weights = weight)\n",
  "  Document with: ?ns_wave1"
)

## ---- Survey design and usage notes ----
##
## To create a survey design for a single wave:
##
##   wave1 <- ns_phase1[["ns20190718"]]
##   d <- as_survey_calibrated(wave1, weights = weight)
##   get_freqs(d, pres_approval)
##
## To combine all Phase 1 waves for cross-wave analysis:
##
##   phase1_combined <- dplyr::bind_rows(ns_phase1)
##   d_all <- as_survey_calibrated(phase1_combined, weights = weight)
##
## NOTE: When combining waves, variables not asked in a given wave are NA.
## Use Nationscape-Variables-2021Dec.csv to identify which variables are
## present in each wave before combining.
##
## Save the processed data locally for reuse:
##
##   saveRDS(ns_phase1, "data-raw/nationscape/ns_phase1.rds")
