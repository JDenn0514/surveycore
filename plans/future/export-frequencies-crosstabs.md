# Export Frequencies & Cross-Tabs — Design Notes

**Created:** 2026-03-20
**Status:** Early design — not yet specced

---

## Motivation

Create functions that export survey frequencies in formats matching industry conventions,
balancing interpretability (for report consumers) and methodological rigor (for researchers).

---

## Industry Research Summary

Research covered Pew Research, NORC/GSS, Gallup, AAPOR, Ipsos, SSRS/CNN, YouGov,
Morning Consult, Marist, NYT/Siena, Fox News, ABC/WaPo, CBS/YouGov, NBC/Hart/POS,
Quinnipiac, Monmouth, Emerson, FiveThirtyEight, and RealClearPolitics.

### Universal Conventions

| Element | Convention |
|---------|-----------|
| Percentages | Whole integers dominant; 1 decimal in academic/codebook contexts |
| Sub-0.5% values | Asterisk (`*`) — Pew, Fox News, Gallup, most others |
| Zero values | Dash (`-`) in some orgs (Fox News) |
| DK/Refused | Always shown as explicit row(s), included in percentage base |
| Rounding note | "Percentages may not add to 100% due to rounding" — universal |
| Column percentages | Cross-tabs always show column % (subgroup sums to 100%), never row % |
| MOE | Reported at overall level, not per-cell; notes design-effect adjustment |
| Question text | Verbatim wording always accompanies results |

### Two Distinct Output Types in Industry

**1. Topline Questionnaire** (Pew, Fox News, ABC/WaPo, Gallup)
- One question at a time, question text above, response categories with percentages below
- Single column of results (sometimes with trend columns for prior waves)
- No demographic breaks — just marginals
- Overall N and MOE in a header block

**2. Banner Cross-Tab** (Ipsos, YouGov, SSRS, Morning Consult, Quinnipiac)
- Response categories as rows, demographic subgroups as columns
- Column banners: Total | Gender | Age | Race | Education | Party ID | ...
- Unweighted N (or weighted N) at top of each column
- Optional: letter-based significance testing (Ipsos, YouGov)
- Optional: net scores (Morning Consult)
- 15–30 banner columns per question

### Plus a third from academic/codebook contexts:

**3. SPSS/Codebook Frequency Table** (GSS, `pollster` R package)
- Value code, Label, Frequency, Percent, Valid Percent, Cumulative Percent
- 1 decimal place standard
- Distinguishes IAP/DK/NA as separate missing types

### Detailed Findings by Organization

#### Pew Research Center
- Header: panel name, wave, field dates, N, mode breakdown
- Boilerplate: "ALL NUMBERS ARE PERCENTAGES... LESS THAN 0.5% REPLACED BY ASTERISK (*)"
- Percentages: whole integers, `*` for <0.5%
- "No answer" is catch-all for DK/Refused/skipped, always last row, in base
- Trend data: side-by-side columns by date
- No per-question N (overall N in header)
- Battery/grid: response categories as column headers, items as rows
- No cross-tabs in topline PDF; demographics in report body; microdata released separately
- Format: PDF

#### NORC / GSS
- GSS codebook: Value, Label, Frequency, Percent, Valid Percent, Cumulative Percent
- Missing codes: IAP (inapplicable), DK (don't know), NA (no answer)
- 1 decimal place standard
- AP-NORC toplines: weighted percentages, whole integers, DK/skipped/refused → "Other"
- MOE: ±4.0pp at 95% CI including design effect
- GSS Data Explorer: interactive cross-tabs with chi-square tests

#### Gallup
- Sample: ~1,000 adults, MOE ±4pp, 95% CI
- Percentages: whole integers
- "No opinion" as residual category, in base
- Trend data side-by-side
- Tabs: banner cross-tabs by gender, age, race, education, region, party, income
- Subgroup MOE warnings for small N (e.g., N=104 → ±9.6%)

#### AAPOR Standards
- Process requirements (what to disclose), not format requirements
- Required: sponsor, question wording, population, sampling method, mode, dates,
  sample size, precision discussion, weighting, response rates
- For probability samples: MOE with design effect disclosure
- For non-probability: precision measures only with full model description

#### Ipsos
- Banner cross-tabs: response rows × demographic columns
- Letter-based significance testing (95% CI)
- Weighted percentages, whole integers
- Column bases (weighted and/or unweighted N) at top
- DK/Refused as separate categories

#### SSRS/CNN
- Trend data prominent (prior waves as adjacent columns)
- Subgroup breaks inline (Dem/Rep/Ind below full sample)
- Question wording verbatim with interviewer instructions
- Filter/skip patterns noted with subgroup N

#### YouGov
- Most detailed public releases: full cross-tabs (100–200+ pages)
- 20–30+ banner columns including 2020/2024 vote recall
- Letter-based significance testing, sometimes color-coded
- Both unweighted and weighted N shown
- 0–1 decimal places depending on report series

#### Morning Consult
- Very large samples (N=2,000–10,000+)
- Net scores shown inline (Favorable minus Unfavorable)
- Shows weighted N (not unweighted) in many reports
- Time-series tracking tables

#### Political Polling (media partnerships, campaign pollsters, university polls)
- Topline questionnaire: verbatim question wording + percentage table
- `*` for <0.5%, `-` for zero, `(VOL.)` for volunteered responses
- Cross-tabs: column percentages, banner format
- Separate RV (registered voters) and LV (likely voters) columns
- Standard banners: Party ID, Gender, Age, Race, Education, Region
- DK/NA as explicit response rows
- University polls (Quinnipiac, Monmouth, Emerson) suppress subgroups with small N

---

## Proposed Functions

### `export_topline()` — Publication Topline

Renders one-question-at-a-time output matching the Pew/Gallup format.

```r
export_topline(
  design,
  x = c(q1, q2, q3),         # multiple questions, rendered sequentially
  format = "gt",              # "gt", "flextable", "data.frame"
  pct_scale = 100,            # display as 0-100
  decimals = 0,               # whole integers (Pew/Gallup) or 1 (academic)
  show_n = "header",          # "header" (overall N) or "row" (per-response)
  show_question_text = TRUE,  # from .meta$x$question_preface
  show_moe = TRUE,            # overall MOE in header
  na_label = "No answer",     # label for NA category
  sub_half_pct = "*",         # replace <0.5% with asterisk
  include_dk_in_base = TRUE   # DK/Refused in denominator
)
```

### `export_crosstab()` — Banner Cross-Tab

Pivots frequencies into the wide banner format used by Ipsos/YouGov/SSRS.

```r
export_crosstab(
  design,
  x = c(q1, q2, q3),                     # multiple questions
  banner = c(gender, age_grp, party_id),  # demographic break variables
  format = "gt",                          # "gt", "flextable", "data.frame", "xlsx"
  pct_scale = 100,
  decimals = 0,
  show_n = "column_header",              # unweighted N at top of each column
  show_question_text = TRUE,
  significance = NULL,                   # NULL, "letters", or "stars"
  conf_level = 0.95,
  net = NULL,                            # e.g., list("Net Fav" = c("Very fav", "Somewhat fav"))
  min_cell_n = 30L,
  suppress_small = TRUE                  # suppress cells below min_cell_n
)
```

Both functions accept multiple `x` variables and iterate over them, producing one
table block per variable (or per `question_preface` group).

---

## Variable Type Detection Logic

The export functions detect variable type from metadata and render accordingly:

```
For each group of x variables sharing a question_preface:
  ┌─ question_preface is NULL or unique to 1 variable
  │   → Standard frequency table
  │
  ├─ question_preface shared by 2+ variables AND sata == TRUE
  │   → SATA block: show % yes only, footnote about >100%
  │
  └─ question_preface shared by 2+ variables AND sata == FALSE
      → Battery/grid: response categories as columns, variables as rows
```

No guessing — `question_preface` + `sata` metadata fully determine rendering.

---

## Output Mockups

### Scenario 1: Standard single-response — topline

```r
design |> export_topline(x = c(direction, pres_approve))
```

```
─────────────────────────────────────────────────────────
 National Survey of U.S. Adults
 Field dates: March 1-8, 2026  |  N = 1,203  |  MOE: ±3.4pp
─────────────────────────────────────────────────────────

 Q1. Generally speaking, would you say things in this
     country are heading in the right direction, or are
     they off on the wrong track?

                              %
  Right direction            32
  Wrong track                61
  Don't know                  7
  No answer                   *

 Q2. Do you approve or disapprove of the way the
     president is handling his job?

                              %
  Strongly approve           22
  Somewhat approve           19
  Somewhat disapprove        14
  Strongly disapprove        39
  Don't know                  5
  No answer                   1

─────────────────────────────────────────────────────────
 * = less than 0.5%. Percentages may not sum to 100%
   due to rounding.
```

### Scenario 2: Standard single-response — crosstab

```r
design |> export_crosstab(x = pres_approve, banner = c(party_id, gender, age_grp))
```

```
 Q2. Do you approve or disapprove of the way the president
     is handling his job?

                  Total  │ Dem   Ind   Rep  │ Male  Female │ 18-34 35-49 50-64  65+
  Base (unwt N)   (1203) │(398) (361) (444) │(583)  (620)  │(287) (301) (318) (297)
  ─────────────────────────────────────────────────────────────────────────────────
  Str. approve       22  │   5   14    45   │  25     19   │  18    20    24    26
  Smwt. approve      19  │   8   22    27   │  21     18   │  21    19    18    20
  Smwt. disapprove   14  │  18   19     6   │  13     15   │  16    15    13    12
  Str. disapprove    39  │  64   38    17   │  36     42   │  37    40    40    38
  Don't know          5  │   4    7     4   │   4      5   │   8     6     4     3
  No answer           1  │   1    *     1   │   1      1   │   *     *     1     1
```

### Scenario 3: Select-all-that-apply — topline

Variables `news_tv`, `news_online`, etc. share a `question_preface` and have `sata = TRUE`.

```r
design |> export_topline(x = c(news_tv, news_online, news_radio, news_print, news_social))
```

```
 Q7. Where do you get most of your news?
     (Select all that apply) †

                              %
  Television                 54
  Online news sites          48
  Social media               37
  Radio                      19
  Print newspapers            8

─────────────────────────────────────────────────────────
 † Select all that apply. Percentages sum to more than
   100% because respondents could choose multiple options.
```

Key behaviors:
- Only "% yes" shown (not "% no")
- Row labels from each variable's `variable_label`
- Block header from shared `question_preface`
- Automatic footnote about summing > 100%

### Scenario 4: Select-all-that-apply — crosstab

```r
design |> export_crosstab(
  x = c(news_tv, news_online, news_radio, news_print, news_social),
  banner = c(age_grp, gender)
)
```

```
 Q7. Where do you get most of your news? †

  % who selected    Total │ 18-34  35-49  50-64   65+  │ Male  Female
  Base (unwt N)     (1203)│ (287)  (301)  (318)  (297) │ (583)  (620)
  ──────────────────────────────────────────────────────────────────
  Television           54 │   31     48     64     72  │   52     56
  Online news sites    48 │   62     55     40     33  │   50     46
  Social media         37 │   64     42     24     16  │   33     41
  Radio                19 │   15     21     22     18  │   22     16
  Print newspapers      8 │    2      5      9     17  │    9      7

 † Select all that apply. Columns do not sum to 100%.
```

### Scenario 5: Battery/grid — topline

Variables `worry_economy`, `worry_crime`, etc. share a `question_preface` and `sata == FALSE`.

```r
design |> export_topline(x = c(worry_economy, worry_crime, worry_climate, worry_immigration))
```

```
 Q10. How worried are you about each of the following?

                     Very    Somewhat  Not too   Not at all  Don't
                    worried  worried   worried    worried     know
  The economy         42       33        16          7         2
  Crime               28       35        24         11         2
  Climate change      31       22        18         26         3
  Immigration         37       29        19         13         2
```

Response categories become column headers; each variable becomes a row using its
`variable_label`.

### Scenario 6: Battery/grid — crosstab

Each grid item becomes its own sub-table sharing the same banner columns:

```r
design |> export_crosstab(x = c(worry_economy, worry_crime, worry_climate), banner = party_id)
```

```
 Q10. How worried are you about each of the following?

 a. The economy
                     Total │ Dem   Ind   Rep
  Base (unwt N)      (1203)│(398) (361) (444)
  ──────────────────────────────────────────
  Very worried          42 │  48    40    38
  Somewhat worried      33 │  32    34    33
  Not too worried       16 │  13    17    19
  Not at all worried     7 │   5     7     9
  Don't know             2 │   2     2     1

 b. Crime
                     Total │ Dem   Ind   Rep
  Base (unwt N)      (1203)│(398) (361) (444)
  ──────────────────────────────────────────
  Very worried          28 │  22    26    36
  Somewhat worried      35 │  34    36    35
  Not too worried       24 │  26    24    21
  Not at all worried    11 │  16    12     6
  Don't know             2 │   2     2     2
```

### Scenario 7: Mixed variable types in one call

```r
design |> export_topline(x = c(
  direction, pres_approve,                                     # single-response
  news_tv, news_online, news_radio, news_print, news_social,   # SATA
  worry_economy, worry_crime, worry_climate                     # battery
))
```

Groups by `question_preface`, checks `sata`, renders each block in the appropriate
format — all in one call, producing a sequential document.

---

## Prerequisite: `sata` Metadata Property

Before implementing the export functions, the metadata system needs a `sata` property.
See the companion handoff document for details.

### Proposed API

```r
# Setter
design <- design |> set_sata(c(q5_a, q5_b, q5_c), TRUE)

# Getter
extract_sata(design, q5_a)  # TRUE

# Bulk setter
design <- set_sata_vars(design, c(q5_a, q5_b, q5_c))
```

### Why metadata, not an export argument

- The variable *is* SATA regardless of how you export it — property of the data, not the output
- Can be auto-detected at import time (haven SPSS, Qualtrics naming conventions)
- Removes ambiguity from the export API
- Set once, used by `get_freqs()`, `export_topline()`, `export_crosstab()`, etc.

---

## Open Questions

1. **Return type for multi-variable calls:** List of gt tables vs. single stacked table?
2. **Trend data:** Should toplines support side-by-side trend columns (Pew/Gallup style)?
3. **Significance testing details:** Which test(s) for letter-based testing? Chi-square? Z-test of proportions?
4. **Net scores:** How to specify which categories to net? Named list seems right.
5. **gt vs. flextable:** Primary render target? gt for HTML/PDF, flextable for Word/PowerPoint?
6. **Where do these functions live?** In surveycore, or in a new surveyreport package?
7. **Column-level labels for gt:** Should `get_freqs()` itself set these, or only the export functions?
