## Democracy Fund + UCLA Nationscape — Phase 2 (Waves 25–50)
## Prepare survey data with cleaned metadata
##
## Source: Democracy Fund Voter Study Group / UCLA
## URL: https://www.voterstudygroup.org/data/nationscape
## License: Academic research use; see data-raw/nationscape/ for user guide.
##
## Phase 2 coverage: January 2, 2020 – June 25, 2020 (26 weekly waves)
## Waves: ns20200102 through ns20200625
## Sample: ~6,250 completed interviews per wave (~162,500 total)
## Mode: Online (Lucid respondent exchange platform)
## Design: Non-probability quota sample with raking weights
##   Weight variable: weight (calibrated to ACS + 2016 vote targets)
##   No cluster or strata variables — use as_survey_calibrated()
##
## Phase 2 content changes vs. Phase 1:
##   - Some Phase 1 matchup candidates removed (Booker, Castro, Gabbard, etc.)
##   - Bloomberg added as matchup candidate (early Phase 2 waves)
##   - Klobuchar and Abrams added to candidate favorability
##   - Senate primary questions added (primary_sen_*): 47 Republican senators
##   - New discrimination items: Jews, Asians
##   - New group favorability items: Evangelical Christians, White Men, Jews
##   - COVID-19 behaviors and policies added from Wave 37 (March 26, 2020)
##   - Statements battery added (statements_*)
##   - Forced choice items added (fc_smallgov, fc_trad_val)
##
## Run from the package root: source("data-raw/prepare-nationscape-phase2.R")

library(haven)
library(stringr)
devtools::load_all(here::here(), quiet = TRUE)
source(file.path(here::here(), "data-raw", "prepare-nationscape-helpers.R"))

PHASE2_DIR <- file.path(here::here(), "data-raw", "nationscape", "phase_2_v20210301")

if (!dir.exists(PHASE2_DIR)) {
  stop(
    "Phase 2 data not found at: ", PHASE2_DIR, "\n",
    "Download the Nationscape data from:\n",
    "  https://www.voterstudygroup.org/data/nationscape\n",
    "and extract to data-raw/nationscape/."
  )
}

## ---- Phase 2 battery definitions ----

BATTERIES_PHASE2 <- list(

  ## News sources (unchanged from Phase 1)
  news_sources = list(
    preface = "We're interested in where you might have heard news about politics in the last week. Please indicate which of the following sources you used.",
    vars = c(
      news_sources_facebook        = "Social media (e.g., Facebook, Twitter)",
      news_sources_cnn             = "CNN",
      news_sources_msnbc           = "MSNBC",
      news_sources_fox             = "Fox News (cable)",
      news_sources_network         = "Network news (ABC, CBS, NBC) or PBS",
      news_sources_localtv         = "Local TV station",
      news_sources_telemundo       = "Telemundo or Univision",
      news_sources_npr             = "NPR",
      news_sources_amtalk          = "AM talk radio station",
      news_sources_new_york_times  = "National newspaper (e.g., New York Times, Wall Street Journal, USA Today)",
      news_sources_local_newspaper = "Local newspaper",
      news_sources_other           = "Other",
      news_sources_other_TEXT      = "Other (write-in)"
    )
  ),

  ## Group favorability ratings (Phase 2 adds Evangelicals, White Men, Jews)
  group_fav = list(
    preface = "Here are the names of some groups that are in the news from time to time. How favorable is your impression of each?",
    vars = c(
      group_favorability_whites        = "Whites",
      group_favorability_blacks        = "Blacks",
      group_favorability_latinos       = "Latinos",
      group_favorability_asians        = "Asians",
      group_favorability_christians    = "Christians",
      group_favorability_socialists    = "Socialists",
      group_favorability_muslims       = "Muslims",
      group_favorability_labor_unions  = "Labor unions",
      group_favorability_the_police    = "The police",
      group_favorability_undocumented  = "Undocumented immigrants",
      group_favorability_lgbt          = "Gays and lesbians",
      group_favorability_republicans   = "Republicans",
      group_favorability_democrats     = "Democrats",
      ## Phase 2 additions
      group_favorability_evangelicals  = "Evangelical Christians",
      group_favorability_white_men     = "White men",
      group_favorability_jews          = "Jews"
    )
  ),

  ## Candidate favorability (Phase 2 adds Klobuchar and Abrams)
  cand_fav = list(
    preface = "How favorable is your impression of each of the following people?",
    vars = c(
      cand_favorability_trump      = "Donald Trump",
      cand_favorability_obama      = "Barack Obama",
      cand_favorability_cortez     = "Alexandria Ocasio-Cortez",
      cand_favorability_biden      = "Joe Biden",
      cand_favorability_harris     = "Kamala Harris",
      cand_favorability_buttigieg  = "Pete Buttigieg",
      cand_favorability_warren     = "Elizabeth Warren",
      cand_favorability_sanders    = "Bernie Sanders",
      cand_favorability_pence      = "Mike Pence",
      ## Phase 2 additions
      cand_favorability_klobuchar  = "Amy Klobuchar",
      cand_favorability_abrams     = "Stacey Abrams"
    )
  ),

  ## Trump head-to-head matchups (Phase 2: Bloomberg replaces most others)
  trump_matchup = list(
    preface = "If the general election for president of the United States was a contest between Donald Trump and the following candidate, who would you vote for?",
    vars = c(
      trump_biden      = "Joe Biden",
      trump_sanders    = "Bernie Sanders",
      trump_harris     = "Kamala Harris",
      trump_warren     = "Elizabeth Warren",
      trump_buttigieg  = "Pete Buttigieg",
      trump_bloomberg  = "Michael Bloomberg"
    )
  ),

  ## Pence head-to-head matchups
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

  ## Senate primary questions (asked of respondents in relevant states)
  ##
  ## Each question asks whether the Republican Party should nominate a
  ## challenger to the incumbent senator. Variable labels are set here
  ## because SPSS labels are truncated and do not preserve the senator name.
  primary_sen = list(
    preface = "Thinking about your state's U.S. Senate race, should the Republican Party nominate a candidate to challenge the incumbent senator, or should they nominate someone else?",
    vars = c(
      primary_sen_barrasso    = "John Barrasso (WY)",
      primary_sen_blackburn   = "Marsha Blackburn (TN)",
      primary_sen_blunt       = "Roy Blunt (MO)",
      primary_sen_boozman     = "John Boozman (AR)",
      primary_sen_braun       = "Mike Braun (IN)",
      primary_sen_cassidy     = "Bill Cassidy (LA)",
      primary_sen_collins     = "Susan Collins (ME)",
      primary_sen_cornyn      = "John Cornyn (TX)",
      primary_sen_cotton      = "Tom Cotton (AR)",
      primary_sen_cramer      = "Kevin Cramer (ND)",
      primary_sen_crapo       = "Mike Crapo (ID)",
      primary_sen_cruz        = "Ted Cruz (TX)",
      primary_sen_daines      = "Steve Daines (MT)",
      primary_sen_ernst       = "Joni Ernst (IA)",
      primary_sen_fischer     = "Deb Fischer (NE)",
      primary_sen_gardner     = "Cory Gardner (CO)",
      primary_sen_graham      = "Lindsey Graham (SC)",
      primary_sen_grassley    = "Chuck Grassley (IA)",
      primary_sen_hawley      = "Josh Hawley (MO)",
      primary_sen_hoeven      = "John Hoeven (ND)",
      primary_sen_hydesmith   = "Cindy Hyde-Smith (MS)",
      primary_sen_inhofe      = "Jim Inhofe (OK)",
      primary_sen_lankford    = "James Lankford (OK)",
      primary_sen_lee         = "Mike Lee (UT)",
      primary_sen_mcconnell   = "Mitch McConnell (KY)",
      primary_sen_mcsally     = "Martha McSally (AZ)",
      primary_sen_moorecapito = "Shelley Moore Capito (WV)",
      primary_sen_moran       = "Jerry Moran (KS)",
      primary_sen_murkowski   = "Lisa Murkowski (AK)",
      primary_sen_neelykennedy = "John Kennedy (LA)",
      primary_sen_paul        = "Rand Paul (KY)",
      primary_sen_perdue      = "David Perdue (GA)",
      primary_sen_portman     = "Rob Portman (OH)",
      primary_sen_risch       = "James Risch (ID)",
      primary_sen_romney      = "Mitt Romney (UT)",
      primary_sen_rounds      = "Mike Rounds (SD)",
      primary_sen_rubio       = "Marco Rubio (FL)",
      primary_sen_sasse       = "Ben Sasse (NE)",
      primary_sen_scott_rick  = "Rick Scott (FL)",
      primary_sen_scott_tim   = "Tim Scott (SC)",
      primary_sen_shelby      = "Richard Shelby (AL)",
      primary_sen_sullivan    = "Dan Sullivan (AK)",
      primary_sen_thune       = "John Thune (SD)",
      primary_sen_tillis      = "Thom Tillis (NC)",
      primary_sen_toomey      = "Pat Toomey (PA)",
      primary_sen_wicker      = "Roger Wicker (MS)",
      primary_sen_young       = "Todd Young (IN)"
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

  ## Gender attitudes
  gender_attitudes = list(
    preface = "Please tell us how much you agree or disagree with the following statements about gender.",
    vars = c(
      gender_attitudes_maleboss    = "I would be more comfortable having a man as a boss than a woman.",
      gender_attitudes_logical     = "Women are just as capable of thinking logically as men.",
      gender_attitudes_opportunity = "Increased opportunities for women have significantly improved the quality of life in our society.",
      gender_attitudes_complain    = "Women who complain about harassment often cause more problems than they solve."
    )
  ),

  ## Discrimination perceptions (Phase 2 adds Jews and Asians)
  discrimination = list(
    preface = "How much discrimination is there in the United States today against each of the following groups?",
    vars = c(
      discrimination_blacks     = "Blacks",
      discrimination_whites     = "Whites",
      discrimination_muslims    = "Muslims",
      discrimination_christians = "Christians",
      discrimination_women      = "Women",
      discrimination_men        = "Men",
      ## Phase 2 additions
      discrimination_jews       = "Jews",
      discrimination_asians     = "Asians"
    )
  ),

  ## Policy battery 1
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
      guaranteed_jobs      = "Guarantee jobs for all Americans",
      green_new_deal       = "Enact a Green New Deal",
      impeach_trump        = "Impeach President Trump",
      israel               = "Withdraw military support for the state of Israel",
      marijuana            = "Legalize marijuana",
      medicare_for_all     = "Enact Medicare-for-All",
      military_size        = "Reduce the size of the US military",
      minwage              = "Raise the minimum wage to $15/hour",
      uctaxes2             = "Raise taxes on families making over $250,000",
      reparations          = "Grant reparations payments to the descendants of slaves",
      trade                = "Limit trade with other countries",
      ## Phase 2 additions
      abortion_any_time        = "Permit abortion at any time during the pregnancy",
      abolish_priv_insurance   = "Abolish private health insurance and replace with government-run health insurance",
      china_tariffs            = "Impose trade tariffs on Chinese goods",
      criminal_immigration     = "Charge immigrants who enter the U.S. illegally with a federal crime",
      immigration_insurance    = "Provide government-financed health insurance to immigrants who enter the U.S. illegally",
      saudi_arabia             = "Withdraw military support for Saudi Arabia",
      egypt                    = "Withdraw military support for Egypt"
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

  ## COVID-19 behaviors battery (added Wave 37, March 26, 2020)
  ##
  ## "Have you done any of the following things in response to concerns
  ## about the coronavirus/COVID-19 pandemic?"
  covid_behaviors = list(
    preface = "Have you done any of the following things in response to concerns about the coronavirus/COVID-19 pandemic?",
    vars = c(
      extra_covid_wash           = "Washed your hands more often than you typically do",
      extra_covid_cancel_travel  = "Cancelled travel plans for work or pleasure",
      extra_covid_stock_goods    = "Bought extra groceries or household supplies",
      extra_covid_visit_family   = "Stopped visiting family or friends",
      extra_covid_quarantine     = "Not left my home for a prolonged period of time",
      extra_covid_hospital       = "Visited a medical facility",
      extra_covid_worn_mask           = "Worn a mask when going out in public",
      extra_covid_socialize_distance  = "Socialized with people not living in my household while maintaining social distance",
      extra_covid_socialize_no_dist   = "Socialized with people not living in my household without maintaining social distance",
      extra_covid_nonessential_goods  = "Left my house for non-essential goods or services"
    )
  ),

  ## COVID-19 policy battery
  ##
  ## "As you may know, some state and local governments have issued
  ## orders requiring..." — agreement/disagreement
  covid_policy = list(
    preface = "As you may know, some state and local governments have issued orders related to the COVID-19 pandemic. Do you support or oppose each of the following?",
    vars = c(
      extra_covid_cancel_meet   = "Cancel all meetings or gatherings of more than 10 people",
      extra_covid_close_business = "Close certain businesses where larger numbers of people gather",
      extra_covid_close_schools  = "Close schools and universities",
      extra_covid_work_home      = "Require people who can work from home to work from home",
      extra_covid_restrict_home  = "Restrict all non-essential travel outside the home",
      extra_covid_testing        = "Test people for a fever before letting them enter public buildings"
    )
  ),

  ## Statements battery (Phase 2 addition)
  ##
  ## "Please tell us how much you agree or disagree with the following
  ## statements." (different statement types combined in one battery)
  statements = list(
    preface = "Please tell us how much you agree or disagree with the following statements.",
    vars = c(
      statements_protect_traditions  = "Politicians should do more to protect America's way of life",
      statements_defense_burden      = "America is carrying too much of the burden for the defense of itself and its allies",
      statements_trade_effects       = "US trade with other countries has a mostly positive effect on jobs for US workers",
      statements_christianity_assault = "Traditional Christian religious beliefs are under assault",
      statements_gender_identity     = "There are only two genders, male and female",
      statements_american_loss       = "America is at risk of losing what we have in common with each other",
      statements_imm_assimilate      = "Immigrants should hold on to their traditions even if it means they do not fully assimilate into American society",
      statements_gun_rights          = "It is more important for the government to control who owns guns than it is to protect the right to own guns",
      statements_confront_china      = "It is important to protect the US economy even if it means letting China become more powerful",
      statements_foreign_interests   = "Politicians often put the interests and feelings of foreigners above those of American citizens"
    )
  ),

  ## Democratic primary ranking
  rank_dems = list(
    preface = "Please rank your top 3 Democratic presidential candidates.",
    vars = c(
      rank_dems_1 = "Rank 1",
      rank_dems_2 = "Rank 2",
      rank_dems_3 = "Rank 3"
    )
  ),

  ## Religion
  religion = list(
    preface = "What is your present religion, if any?",
    vars = c(
      religion            = "Selected choice",
      religion_other_text = "Write-in (something else)"
    )
  ),

  ## Vote in 2016
  vote_2016 = list(
    preface = "Now take a minute and think back to the 2016 Presidential election. In that election, who did you vote for?",
    vars = c(
      vote_2016            = "Selected choice",
      vote_2016_other_text = "Write-in (other)"
    )
  ),

  ## Party identification follow-ups
  pid_followup = list(
    preface = "Follow-up to party identification question (pid3).",
    vars = c(
      strength_democrat   = "Strength of Democratic identification",
      strength_republican = "Strength of Republican identification",
      lean_independent    = "Partisan lean of independents"
    )
  ),

  ## Employment
  employment = list(
    preface = "Which of the following best describes your current employment status?",
    vars = c(
      employment            = "Selected choice",
      employment_other_text = "Write-in (other)"
    )
  )
)

## ---- Main: load and process all Phase 2 waves ----

ns_phase2 <- load_phase_waves(PHASE2_DIR, BATTERIES_PHASE2, "Phase 2")

## ---- Usage notes ----
##
##   wave25 <- ns_phase2[["ns20200102"]]
##   d <- as_survey_calibrated(wave25, weights = weight)
##   get_freqs(d, pres_approval)
##
## Save locally: saveRDS(ns_phase2, "data-raw/nationscape/ns_phase2.rds")
