# Nationscape Wave 1: July 18, 2019

The first weekly wave of the Democracy Fund + UCLA Nationscape survey,
fielded July 18–24, 2019. Approximately 6,250 completed online
interviews drawn from the Lucid respondent exchange platform using a
non-probability quota design, with raking weights calibrated to ACS
demographic targets and 2016 presidential vote choice.

## Usage

``` r
ns_wave1
```

## Format

A data frame with approximately 6,250 rows and 171 variables (170 survey
variables plus `wave_id` added by the prepare script).

- response_id:

  Unique respondent ID (integer).

- start_date:

  Interview date (character, `"YYYY-MM-DD"` format).

- wave_id:

  Wave identifier: `"ns20190718"` for all rows in this dataset.

- weight:

  Raking weight calibrated to ACS demographic targets and 2016
  presidential vote choice. Use for all population-level estimates.

- right_track:

  Country direction: `1` = Right direction, `2` = Wrong track, `3` = Not
  sure.

- economy_better:

  Economy outlook: `1` = Better, `2` = Worse, `3` = Same, `4` = Not
  sure.

- interest:

  Political interest (4-pt): `1` = Very interested, `4` = Not at all
  interested.

- registration:

  Voter registration: `1` = Registered, `2` = Not registered, `3` = Not
  eligible.

- pres_approval:

  Trump presidential approval: `1` = Strongly approve, `2` = Somewhat
  approve, `3` = Somewhat disapprove, `4` = Strongly disapprove.

- vote_intention:

  2020 vote intention: `1` = Trump, `2` = Democratic candidate, `3` =
  Other, `4` = Don't plan to vote, `5` = Not sure.

- vote_2016:

  2016 presidential vote. See labels.

- vote_2016_other_text:

  Write-in for `vote_2016` "other" choice.

- consider_trump:

  Would consider voting for Trump: `1` = Yes, `2` = No.

- not_trump:

  Reason for not considering Trump (open text).

- primary_party:

  Primary vote party: `1` = Democratic, `2` = Republican, `3` = Other.

- dem_vote_intent:

  Democratic primary vote intention. See labels.

- dem_vote_intent_TEXT:

  Write-in for `dem_vote_intent` "other".

- rank_dems_1:

  Top-ranked Democratic presidential candidate. See labels.

- rank_dems_2:

  Second-ranked Democratic candidate. See labels.

- rank_dems_3:

  Third-ranked Democratic candidate. See labels.

- replace_trump:

  Wants non-Trump Republican nominee: `1` = Yes, `2` = No, `3` = Not
  sure.

- house_intent:

  U.S. House vote intention: `1` = Democrat, `2` = Republican, `3` =
  Other, `4` = Won't vote, `5` = Not sure.

- senate_intent:

  U.S. Senate vote intention. Same codes as `house_intent`.

- governor_intent:

  Governor vote intention. Same codes as `house_intent`.

- news_sources_facebook:

  Used social media for political news in past week: `1` = Selected, `2`
  = Not selected. See `"question_preface"` attribute for shared question
  stem. Same coding for all `news_sources_*` variables.

- news_sources_cnn:

  Used CNN for political news.

- news_sources_msnbc:

  Used MSNBC for political news.

- news_sources_fox:

  Used Fox News for political news.

- news_sources_network:

  Used network news (ABC/CBS/NBC/PBS).

- news_sources_localtv:

  Used local TV news.

- news_sources_telemundo:

  Used Telemundo or Univision.

- news_sources_npr:

  Used NPR.

- news_sources_amtalk:

  Used AM talk radio.

- news_sources_new_york_times:

  Used a national newspaper.

- news_sources_local_newspaper:

  Used a local newspaper.

- news_sources_other:

  Used another news source: `1` = Selected, `2` = Not selected.

- news_sources_other_TEXT:

  Write-in for `news_sources_other`.

- group_favorability_whites:

  Favorability toward Whites: `1` = Very favorable, `2` = Somewhat
  favorable, `3` = Somewhat unfavorable, `4` = Very unfavorable, `5` =
  Not sure. Same coding for all `group_favorability_*` variables.

- group_favorability_blacks:

  Favorability toward Blacks.

- group_favorability_latinos:

  Favorability toward Latinos.

- group_favorability_asians:

  Favorability toward Asians.

- group_favorability_christians:

  Favorability toward Christians.

- group_favorability_socialists:

  Favorability toward Socialists.

- group_favorability_muslims:

  Favorability toward Muslims.

- group_favorability_labor_unions:

  Favorability toward labor unions.

- group_favorability_the_police:

  Favorability toward the police.

- group_favorability_undocumented:

  Favorability toward undocumented immigrants.

- group_favorability_lgbt:

  Favorability toward gays and lesbians.

- group_favorability_republicans:

  Favorability toward Republicans.

- group_favorability_democrats:

  Favorability toward Democrats.

- cand_favorability_trump:

  Favorability toward Donald Trump. Same 5-point scale as
  `group_favorability_*` variables.

- cand_favorability_obama:

  Favorability toward Barack Obama.

- cand_favorability_cortez:

  Favorability toward Alexandria Ocasio-Cortez.

- cand_favorability_biden:

  Favorability toward Joe Biden.

- cand_favorability_harris:

  Favorability toward Kamala Harris.

- cand_favorability_buttigieg:

  Favorability toward Pete Buttigieg.

- cand_favorability_warren:

  Favorability toward Elizabeth Warren.

- cand_favorability_sanders:

  Favorability toward Bernie Sanders.

- cand_favorability_pence:

  Favorability toward Mike Pence.

- trump_biden:

  Trump vs. Biden head-to-head: `1` = Trump, `2` = Biden, `3` = Not
  sure. Same coding for all `trump_*` matchup variables.

- trump_sanders:

  Trump vs. Sanders.

- trump_harris:

  Trump vs. Harris.

- trump_warren:

  Trump vs. Warren.

- trump_buttigieg:

  Trump vs. Buttigieg.

- trump_booker:

  Trump vs. Cory Booker.

- trump_castro:

  Trump vs. Julian Castro.

- trump_gabbard:

  Trump vs. Tulsi Gabbard.

- trump_gillibrand:

  Trump vs. Kirsten Gillibrand.

- trump_orourke:

  Trump vs. Beto O'Rourke.

- pence_biden:

  Pence vs. Biden head-to-head: `1` = Pence, `2` = Biden, `3` = Not
  sure. Same coding for all `pence_*` matchup variables.

- pence_buttigieg:

  Pence vs. Buttigieg.

- pence_harris:

  Pence vs. Harris.

- pence_sanders:

  Pence vs. Sanders.

- pence_warren:

  Pence vs. Warren.

- cand_truth_donald_trump:

  Whether Donald Trump cares about telling the truth: `1` = Yes, `2` =
  No, `3` = Not sure. Same coding for all `cand_truth_*` variables.

- cand_truth_elizabeth_warren:

  Whether Elizabeth Warren cares about the truth.

- cand_truth_joe_biden:

  Whether Joe Biden cares about the truth.

- cand_truth_bernie_sanders:

  Whether Bernie Sanders cares about the truth.

- cand_truth_pete_buttigieg:

  Whether Pete Buttigieg cares about the truth.

- cand_truth_kamala_harris:

  Whether Kamala Harris cares about the truth.

- cand_facts_donald_trump:

  Whether Donald Trump relies on facts vs. hunches: `1` = Facts and
  evidence, `2` = Hunches, `3` = Not sure. Same coding for all
  `cand_facts_*` variables.

- cand_facts_elizabeth_warren:

  Whether Elizabeth Warren relies on facts.

- cand_facts_joe_biden:

  Whether Joe Biden relies on facts.

- cand_facts_bernie_sanders:

  Whether Bernie Sanders relies on facts.

- cand_facts_pete_buttigieg:

  Whether Pete Buttigieg relies on facts.

- cand_facts_kamala_harris:

  Whether Kamala Harris relies on facts.

- racial_attitudes_tryhard:

  Agree/disagree: minorities should work their way up without special
  favors. `1` = Strongly agree, `2` = Agree, `3` = Neither, `4` =
  Disagree, `5` = Strongly disagree. Same scale for all
  `racial_attitudes_*` and `gender_attitudes_*` variables.

- racial_attitudes_generations:

  Agree/disagree: generations of slavery make it difficult for Blacks to
  work out of the lower class.

- racial_attitudes_marry:

  Agree/disagree: I prefer close relatives marry someone from the same
  race.

- racial_attitudes_date:

  Agree/disagree: it's alright for Blacks and Whites to date.

- gender_attitudes_maleboss:

  Agree/disagree: more comfortable with a male boss than female boss.

- gender_attitudes_logical:

  Agree/disagree: women are just as capable of thinking logically as
  men.

- gender_attitudes_opportunity:

  Agree/disagree: increased opportunities for women have improved
  quality of life.

- gender_attitudes_complain:

  Agree/disagree: women who complain about harassment cause more
  problems than they solve.

- discrimination_blacks:

  Perceived discrimination against Blacks: `1` = A great deal, `2` = A
  lot, `3` = A little, `4` = None at all, `5` = Not sure. Same scale for
  all `discrimination_*` variables.

- discrimination_whites:

  Perceived discrimination against Whites.

- discrimination_muslims:

  Perceived discrimination against Muslims.

- discrimination_christians:

  Perceived discrimination against Christians.

- discrimination_women:

  Perceived discrimination against Women.

- discrimination_men:

  Perceived discrimination against Men.

- sen_knowledge:

  U.S. Senate knowledge question. See labels.

- sc_knowledge:

  U.S. Supreme Court knowledge question. See labels.

- pid3:

  3-category party ID: `1` = Democrat, `2` = Republican, `3` =
  Independent, `4` = Something else.

- pid7_legacy:

  7-point party ID (legacy coding). See labels.

- strength_democrat:

  Strength of Democratic ID (conditional on `pid3 == 1`). See labels.

- strength_republican:

  Strength of Republican ID (conditional on `pid3 == 2`). See labels.

- lean_independent:

  Partisan lean of Independents (conditional on `pid3 == 3`). See
  labels.

- ideo5:

  5-point ideological self-placement: `1` = Very liberal, `5` = Very
  conservative.

- employment:

  Employment status (selected choice). See labels.

- employment_other_text:

  Write-in for `employment` "other".

- foreign_born:

  Born outside the U.S.: `1` = Yes, `2` = No.

- language:

  Primary language at home. See labels.

- religion:

  Religious affiliation (selected choice). See labels.

- religion_other_text:

  Write-in for `religion` "other".

- is_evangelical:

  Born-again or evangelical Christian: `1` = Yes, `2` = No.

- orientation_group:

  Sexual orientation. See labels.

- in_union:

  Labor union membership: `1` = Yes, `2` = No, `3` = Non-union
  household, `4` = Not sure.

- household_gun_owner:

  Household gun ownership: `1` = Yes, `2` = No, `3` = Not sure.

- wall:

  Support building a wall on the southern U.S. border: `1` = Strongly
  support, `2` = Somewhat support, `3` = Somewhat oppose, `4` = Strongly
  oppose, `5` = Not sure. Same scale for all policy items through
  `limit_magazines`. See `"question_preface"` attribute on each variable
  for the exact shared question stem.

- cap_carbon:

  Support capping carbon emissions.

- environment:

  Support large-scale government investment in environmental technology.

- guns_bg:

  Support requiring background checks for all gun purchases.

- mctaxes:

  Support cutting taxes for families making \< \$100K/year.

- estate_tax:

  Support eliminating the estate tax.

- raise_upper_tax:

  Support raising taxes on families making \> \$600K.

- college:

  Support ensuring all students can graduate from state colleges
  debt-free.

- abortion_waiting:

  Support requiring a waiting period and ultrasound before an abortion.

- abortion_never:

  Support never permitting abortion.

- abortion_conditions:

  Support permitting abortion in cases other than rape/incest/life at
  risk.

- late_term_abortion:

  Support permitting late-term abortion.

- abortion_insurance:

  Support allowing employers to decline abortion coverage.

- guaranteed_jobs:

  Support guaranteeing jobs for all Americans.

- green_new_deal:

  Support enacting a Green New Deal.

- gun_registry:

  Support creating a public registry of gun ownership.

- immigration_separation:

  Support separating children from parents prosecuted for illegal border
  crossing.

- immigration_system:

  Support shifting to a merit-based immigration system.

- immigration_wire:

  Support requiring proof of citizenship to wire money internationally.

- impeach_trump:

  Support impeaching President Trump.

- israel:

  Support withdrawing military support for Israel.

- marijuana:

  Support legalizing marijuana.

- maternityleave:

  Support requiring 12 weeks of paid maternity leave.

- medicare_for_all:

  Support Medicare-for-All.

- military_size:

  Support reducing the size of the U.S. military.

- minwage:

  Support raising the minimum wage to \$15/hour.

- muslimban:

  Support banning people from predominantly Muslim countries.

- oil_and_gas:

  Support removing barriers to domestic oil and gas drilling.

- reparations:

  Support granting reparations to descendants of slaves.

- right_to_work:

  Support allowing people to work in unionized workplaces without paying
  union dues.

- ten_commandments:

  Support displaying the Ten Commandments in public schools and
  courthouses.

- trade:

  Support limiting trade with other countries.

- trans_military:

  Support allowing transgender people to serve in the military.

- uctaxes2:

  Support raising taxes on families making \> \$250K.

- vouchers:

  Support providing tax-funded vouchers for private or religious
  schools.

- gov_insurance:

  Support providing government-run health insurance to all Americans.

- public_option:

  Support providing the option to purchase government-run insurance.

- health_subsidies:

  Support subsidizing health insurance for lower income people not on
  Medicaid.

- path_to_citizenship:

  Support creating a path to citizenship for all undocumented
  immigrants.

- dreamers:

  Support a path to citizenship for DREAMers.

- deportation:

  Support deporting all undocumented immigrants.

- ban_guns:

  Support banning all guns.

- ban_assault_rifles:

  Support banning assault rifles.

- limit_magazines:

  Support limiting gun magazines to 10 bullets.

- age:

  Respondent age in years.

- gender:

  Gender: `1` = Male, `2` = Female, `3` = Other.

- census_region:

  Census region: `1` = Northeast, `2` = Midwest, `3` = South, `4` =
  West.

- hispanic:

  Hispanic or Latino origin: `1` = Yes, `2` = No.

- race_ethnicity:

  Race/ethnicity (6 categories). See labels.

- household_income:

  Household income (7 brackets). See labels.

- education:

  Educational attainment (6 categories). See labels.

- state:

  U.S. state of residence (2-letter abbreviation).

- congress_district:

  Congressional district.

## Source

Democracy Fund Voter Study Group / UCLA. Nationscape Data Set, version
December 2021. <https://www.voterstudygroup.org/data/nationscape> (free
download; academic research use). Prepared by
`data-raw/prepare-nationscape-phase1.R`.

For full methodology, see the Nationscape User Guide and the
Representative Assessment report in
`data-raw/nationscape/Nationscape-User-Guide-2021Dec.pdf`.

## Details

This dataset is the first of 77 weekly waves collected from July 2019
through January 2021. The full survey ran in three phases:

|         |       |                             |           |
|---------|-------|-----------------------------|-----------|
| Phase   | Weeks | Dates                       | Approx. N |
| Phase 1 | 1–24  | Jul 18, 2019 – Dec 26, 2019 | 150,000   |
| Phase 2 | 25–50 | Jan 2, 2020 – Jun 25, 2020  | 162,500   |
| Phase 3 | 51–77 | Jul 2, 2020 – Jan 12, 2021  | 168,750   |

Only Wave 1 is bundled in the package because 77 waves × ~6,250 rows
would be prohibitively large. To obtain the full dataset by phase, use
the prepare scripts in `data-raw/` (see the Source section).

**Survey design:** The Nationscape is a calibrated non-probability
sample (quota design with raking weights). Use
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
— it is designed specifically for this use case and will gain bootstrap
re-calibration variance in Phase 2.5:

    svy <- as_survey_nonprob(ns_wave1, weights = weight)

**Metadata:** All substantive columns carry variable labels (`"label"`
attribute) set during data preparation. Battery items additionally carry
a `"question_preface"` attribute with the shared question stem. Value
labels (`"labels"` attribute) are present for all coded response items.

**Battery structure:** Most multi-item question groups follow a
`{battery}_{item}` naming convention. All items within a battery share
an identical `"question_preface"` attribute:

|                        |                                        |         |
|------------------------|----------------------------------------|---------|
| Battery prefix         | Preface summary                        | N items |
| `news_sources_*`       | News sources used in past week         | 13      |
| `group_favorability_*` | Favorability toward named groups       | 13      |
| `cand_favorability_*`  | Favorability toward named candidates   | 9       |
| `trump_*`              | Trump head-to-head matchups            | 10      |
| `pence_*`              | Pence head-to-head matchups            | 5       |
| `cand_truth_*`         | Whether each candidate tells the truth | 6       |
| `cand_facts_*`         | Whether each candidate relies on facts | 6       |
| `racial_attitudes_*`   | Agree/disagree racial attitude items   | 4       |
| `gender_attitudes_*`   | Agree/disagree gender attitude items   | 4       |
| `discrimination_*`     | Perceived discrimination by group      | 6       |

Three policy batteries share the same Agree/Disagree/Neither scale:
`wall`, `cap_carbon`, `environment`, `guns_bg`, `mctaxes`, `estate_tax`,
`raise_upper_tax`, `college`, `abortion_waiting`, `abortion_never`,
`abortion_conditions`, `late_term_abortion`, `abortion_insurance`,
`guaranteed_jobs`, `green_new_deal`, `gun_registry`,
`immigration_separation`, `immigration_system`, `immigration_wire`,
`impeach_trump`, `israel`, `marijuana`, `maternityleave`,
`medicare_for_all`, `military_size`, `minwage`, `muslimban`,
`oil_and_gas`, `reparations`, `right_to_work`, `ten_commandments`,
`trade`, `trans_military`, `uctaxes2`, `vouchers`, `gov_insurance`,
`public_option`, `health_subsidies`, `path_to_citizenship`, `dreamers`,
`deportation`, `ban_guns`, `ban_assault_rifles`, `limit_magazines`.

## References

Tausanovitch, Chris and Lynn Vavreck. 2021. Democracy Fund + UCLA
Nationscape, October 10–17, 2019 (version 20210301). Retrieved from
voterstudygroup.org/data/nationscape.

Rivers, Douglas and Delia Bailey. 2009. "Inference from matched samples
in the 2008 U.S. national elections." Proceedings of the Joint
Statistical Meetings, Social Statistics Section.

## Examples

``` r
# Design variables
head(ns_wave1[, c("response_id", "weight", "age", "gender")])
#> # A tibble: 6 × 4
#>   response_id weight   age gender
#>   <chr>        <dbl> <dbl>  <dbl>
#> 1 00100002    1.75      37      1
#> 2 00100003    0.144     45      2
#> 3 00100004    0.213     24      1
#> 4 00100005    0.0506    26      1
#> 5 00100007    0.137     60      1
#> 6 00100008    0.0653    55      2

# Inspect a battery item's metadata
attr(ns_wave1$group_favorability_blacks, "label")
#> [1] "Blacks"
attr(ns_wave1$group_favorability_blacks, "question_preface")
#> [1] "Here are the names of some groups that are in the news from time to time. How favorable is your impression of each?"
attr(ns_wave1$news_sources_cnn, "labels")
#> Yes  No 
#>   1   2 

# Create a calibrated survey design (correct approach for raked
# non-prob samples)
svy <- as_survey_nonprob(ns_wave1, weights = weight)
get_freqs(svy, pres_approval)
#> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
#>   use an SRS approximation that underestimates calibration uncertainty.
#> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
#> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
#>   use an SRS approximation that underestimates calibration uncertainty.
#> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
#> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
#>   use an SRS approximation that underestimates calibration uncertainty.
#> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
#> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
#>   use an SRS approximation that underestimates calibration uncertainty.
#> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
#> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
#>   use an SRS approximation that underestimates calibration uncertainty.
#> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
#> # A tibble: 5 × 3
#>   pres_approval          pct     n
#>   <fct>                <dbl> <int>
#> 1 Strongly approve    0.184   1222
#> 2 Somewhat approve    0.206   1295
#> 3 Somewhat disapprove 0.152    871
#> 4 Strongly disapprove 0.415   2799
#> 5 Not sure            0.0445   230

# Party identification distribution
table(ns_wave1$pid3)
#> 
#>    1    2    3    4 
#> 2291 1819 1868  437 
```
