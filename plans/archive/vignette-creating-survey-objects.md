# Vignette Plan: Creating Survey Objects

**Version:** 0.1 (Skeleton)
**Written:** February 2026
**Status:** Planning — not yet implemented

---

## Purpose

This vignette serves as a definitive, self-contained guide for creating survey
design objects in surveycore. The goal: a researcher can open a codebook (or
examine their data), read this vignette, and know exactly which constructor
to use, which arguments to supply, and why.

Target audience: applied researchers who conduct survey research but may not
have formal training in survey methodology. Assumes basic R literacy but not
familiarity with survey package conventions.

---

## Design Principles

- **Citation-backed**: every methodological claim has a legitimate citation
  (peer-reviewed journals, published books, credible institutional sources,
  or the survey package documentation)
- **Codebook-grounded**: examples walk through real codebook language and
  connect it to function arguments
- **Real data**: NHANES 2017-2018, ACS PUMS Wyoming 2022, and/or Pew Jewish
  Americans 2020 used throughout
- **Scoped**: this vignette covers only object creation. Estimation
  (get_means, get_totals, etc.) belongs in a separate vignette.

---

## Proposed Structure

### 0. Introduction (~200 words)

- What is a survey design object and why does it matter
- The three design types surveycore supports: Taylor series, replicate
  weights, two-phase
- Overview of the decision process: how to read your codebook and end up
  at the right constructor
- Note on scope: creation only; estimation covered elsewhere

### 1. Decision Guide: Which Constructor Do You Need?

- A decision table or flowchart — primary entry point for most readers
- Three branches:
  1. "My data has explicit replicate weights (repwt_1, repwt_2, ...)" → `as_survey_rep()`
  2. "My data has two phases of sampling" → `as_survey_twophase()`
  3. "Everything else" → `as_survey()`
- Quick-reference table: common survey programs and which constructor they use
  | Survey | Constructor | Why |
  |--------|-------------|-----|
  | NHANES | `as_survey()` | Stratified cluster, no provided replicates |
  | BRFSS | `as_survey_rep()` | Provides pre-computed raking weights as replicates |
  | ACS PUMS | `as_survey_rep()` | Provides 80 replicate weights (pwgtp1-pwgtp80) |
  | CPS ASEC | `as_survey_rep()` | Provides replicate weights |
  | ANES | `as_survey()` | Stratified; no provided replicates |
  | GSS | `as_survey()` | Complex cluster design |
  | Lucid/Dynata | See §5 | Non-probability; special considerations |

### 2. `as_survey()` — Taylor Series Designs

The workhorse constructor for probability surveys without pre-computed
replicate weights.

#### 2.1 Core arguments: `ids`, `weights`, `strata`

- What each argument does
- How to identify each in a codebook
- Example: NHANES — SDMVPSU (PSU), WTMEC2YR (weight), SDMVSTRA (strata)
- The SRS case: what happens when you omit `ids` and `strata`

#### 2.2 The `nest` argument

- Why PSU IDs are often not globally unique (common in government surveys)
- `nest = TRUE`: PSU 1 in stratum A ≠ PSU 1 in stratum B
- `nest = FALSE` (default): PSU IDs are assumed globally unique
- How to detect which you need: look at PSU ID range vs number of PSUs
- Citation: Lumley (2010) ch. 2; survey package documentation

#### 2.3 The `fpc` argument — finite population correction

- What FPC does: reduces variance when you've sampled a large fraction of
  the population
- Two forms: population size (integer) or sampling fraction (0–1)
- When it matters: small populations, high sampling rates
- When it doesn't matter: large populations (NHANES, BRFSS — skip FPC)
- When to set it to NULL: when you're not sure, or when sampling fraction
  is small (< 5%)
- Citation: Lohr (2022) §2.8; Cochran (1977) §2.8

#### 2.4 Multi-level clustering: `ids = c(psu, ssu)`

- What multi-stage sampling means
- How to specify two-stage designs
- Common examples: schools + students, counties + households

#### 2.5 Full worked example: NHANES 2017-2018

- Show the actual codebook entry
- Walk through each argument choice
- Produce a survey_taylor object
- Annotate what the print output means

### 3. `as_survey_rep()` — Replicate Weight Designs

#### 3.1 What are replicate weights and why do surveys provide them?

- The problem replicate weights solve: variance estimation for complex designs
  that's computationally convenient and matches official estimates
- How replicate weights are created (conceptually): delete groups of
  observations or re-scale weights and recompute
- Why you should use them when provided: agencies tune these for their design
- Citation: Wolter (2007) Introduction to Variance Estimation;
  Judkins (1990) for Fay's BRR

#### 3.2 The `type` argument — the most common source of confusion

The critical section. For each type: what it is, when it appears, how to
identify it in a codebook.

| Type | Full Name | Identifying Signs in Codebook | Common Surveys |
|------|-----------|-------------------------------|----------------|
| `"JK1"` | Jackknife-1 | "jackknife replication" or "JK1"; one PSU dropped per replicate | NHES, some state surveys |
| `"JK2"` | Jackknife-2 | "jackknife replication"; paired PSU design; typically exactly 2 PSUs per stratum | NCES surveys (NAEP, PISA), many education surveys |
| `"JKn"` | Jackknife-n | "jackknife" with varying number of replicates; one stratum dropped per replicate | Less common; some multi-PSU-per-stratum designs |
| `"BRR"` | Balanced Repeated Replication | "BRR" or "balanced half-sample replication"; requires exactly 2 PSUs per stratum | NHANES (if using provided replicates), some CPS variants |
| `"Fay"` | Fay's Modified BRR | "Fay's method" or "Fay BRR"; BRR variant with epsilon factor | ACS PUMS (epsilon=0.5), some Census Bureau surveys |
| `"bootstrap"` | Bootstrap | "bootstrap replication weights"; typically 100-500 replicates | BRFSS, some IPUMS-derived weights |
| `"successive-difference"` | Successive Difference | "SDNR" or "successive difference" | ACS 1-year estimates; some Census surveys |
| `"ACS"` | ACS variant | Specific to American Community Survey | ACS 5-year PUMS |

- The Fay epsilon parameter: what it controls, how to find its value in
  technical documentation
- Citation: Fay (1989); Judkins (1990); US Census Bureau ACS Design and
  Methodology

#### 3.3 The `scale` and `rscales` arguments

- Why they exist: scales the variance formula
- Default values by type (when to use the default vs override)
- When the codebook specifies a custom scale: use that value
- Citation: survey package documentation

#### 3.4 Worked example: ACS PUMS (Fay BRR)

- Codebook: PWGTP (weight), PWGTP1-PWGTP80 (replicate weights)
- Identify: type = "Fay", rscales = 1, scale = 4/80, or use package defaults
- Using tidy-select for the 80 replicate weight columns: `repweights = starts_with("pwgtp")`

#### 3.5 Worked example: BRFSS (bootstrap)

- Codebook: _LLCPWT (weight), _WGT... columns (replicate weights)

### 4. `as_survey_twophase()` — Two-Phase Designs

Note at top: "If you're not sure whether your design is two-phase, it
almost certainly isn't. Skip to §2 or §3."

#### 4.1 What two-phase sampling is

- Phase 1: large, cheap sample of the population (may measure only basic
  variables)
- Phase 2: subsample from phase 1, with more expensive measurements
- The key: you must have retained the phase 1 data and know which units
  were subsampled
- Common contexts: case-control studies with expensive outcomes,
  validation studies, NHS-style health surveys
- Citation: Lumley (2010) ch. 9; Breslow & Cain (1988); Saegusa & Wellner (2013)

#### 4.2 Arguments

- `phase1`: must already be a `survey_taylor` object
- `subset`: the logical column identifying phase 2 membership
- `ids2`, `strata2`, `probs2`, `fpc2`: the phase 2 design
- `method`: "full", "approx", "simple" — when each is appropriate

#### 4.3 Brief worked example

- Use synthetic data (make_survey_data) rather than a real dataset; this
  design type is uncommon enough that a real example may confuse more than
  it clarifies

### 5. Non-Probability and Quota-Based Samples

This section is important because many researchers use non-probability
samples and may not realize the implications.

#### 5.1 The fundamental distinction

- Probability samples: every unit has a known, positive inclusion probability
- Non-probability samples: inclusion probabilities are unknown
- Common non-probability designs in research: opt-in online panels (Lucid,
  Dynata, Cint, Prolific), MTurk convenience samples, quota samples,
  matched samples (YouGov)
- Citation: Baker et al. (2013) AAPOR Task Force on Non-Probability Sampling;
  AAPOR (2016) Standard Definitions

#### 5.2 What vendor-provided weights actually are

- They are calibration/raking weights, not design weights
- They adjust for known demographic imbalances (age, sex, race, education,
  region) against a reference population (Census)
- They reduce bias from known confounders but cannot correct for unknown
  selection mechanisms
- Citation: Mercer et al. (2017); Valliant & Dever (2018) ch. 10

#### 5.3 What happens when you use `as_survey()` with calibration weights

- Point estimates: calibrated to known marginals; reasonable approximation
  if your outcome is correlated with the calibration variables
- Standard errors: computed under SRS assumption; technically invalid;
  tend to underestimate true uncertainty
- This is what most applied researchers do in practice; it should be
  disclosed in methods sections
- Not recommended for inference on rare subgroups where calibration cells
  are thin

#### 5.4 Better approaches

- Calibration raking (available in surveyweights, Phase 2.5): formally
  creates calibration weights with better variance properties
- Propensity score weighting: estimate selection propensity against a
  reference probability sample; cite Elliott & Valliant (2017)
- `nonprobsvy` R package: purpose-built for non-probability inference
- When to just be transparent about limitations vs. seeking better estimates

#### 5.5 Current recommendation for surveycore users

If you have calibration weights from a vendor:
- Use `as_survey(data, weights = your_weights)` (SRS — no ids or strata)
- Understand that SEs are approximate and likely underestimated
- Report in your methods section that you used a non-probability sample
  with calibration weights
- Cite the vendor's weighting methodology document

### 6. Reference: Common Codebook Variables and What They Mean

A lookup table for common codebook terms and how they map to arguments.

| Codebook Term | Maps To | Notes |
|---------------|---------|-------|
| "sampling weight", "survey weight", "person weight" | `weights =` | |
| "PSU", "primary sampling unit", "cluster ID" | `ids =` | |
| "stratum", "design stratum", "sampling stratum" | `strata =` | |
| "FPC", "finite population correction", "population size" | `fpc =` | |
| "replicate weights", "bootstrap weights", "BRR weights" | `repweights =` | → use `as_survey_rep()` |
| "base weight", "design weight" | `weights =` in `as_survey_rep()` | |
| "Fay coefficient", "Fay factor" | `fay_rho =` | With `type = "Fay"` |
| "number of replicates" | Count of repweight columns | Used to verify `repweights =` resolved correctly |

---

## Citations to Acquire

Priority sources to locate before writing:

- Baker, R., et al. (2013). Summary report of the AAPOR task force on
  non-probability sampling. *Journal of Survey Statistics and Methodology*, 1(2), 90–143.
- Cochran, W.G. (1977). *Sampling Techniques* (3rd ed.). Wiley.
- Elliott, M.R., & Valliant, R. (2017). Inference for nonprobability samples.
  *Statistical Science*, 32(2), 249–264.
- Fay, R.E. (1989). Theory and application of replicate weighting for
  variance calculations. *Proceedings of the Survey Research Methods Section, ASA*, 212–217.
- Judkins, D.R. (1990). Fay's method for variance estimation.
  *Journal of Official Statistics*, 6(3), 223–239.
- Lohr, S.L. (2022). *Sampling: Design and Analysis* (3rd ed.). CRC Press.
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley.
- Mercer, A., et al. (2017). For weighting online opt-in samples, what matters most?
  Pew Research Center Technical Report.
- Valliant, R., & Dever, J.A. (2018). *Survey Weights: A Step-by-Step Guide
  to Calculation*. Stata Press.
- Wolter, K.M. (2007). *Introduction to Variance Estimation* (2nd ed.). Springer.

---

## Implementation Notes (for when writing begins)

- Vignette filename: `vignettes/creating-survey-objects.Rmd`
- Output: `html_vignette`
- All examples must use data available in the package: `nhanes_2017`,
  `acs_pums_wy`, `pew_jewish_2020`
- No `make_survey_data()` in vignette (test helper only); use inline `data.frame()`
  for illustrative edge cases
- Keep each section independently readable — researchers will jump to the
  section for their specific survey program
- Version note: update the common surveys table as new data is added

---

## Open Questions (to resolve before writing)

1. Should §3.2 (replicate weight types) include a "how to look up what
   type your survey uses" sub-section with links to official technical docs?
2. Should §5 (non-probability) reference the planned `as_survey_nonprob()`
   constructor (Phase 2.5) or keep to current capabilities only?
3. Is there a better real dataset in the package for demonstrating `as_survey_twophase()`?
   The NHES or NSFG would be ideal but are not currently included.
