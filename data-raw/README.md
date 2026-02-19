# data-raw/

Raw source data and download scripts for surveycore examples and tests.

Processed versions of these datasets (subsetted, renamed for clarity) live in
`tests/testthat/` as helper data or in `inst/extdata/` for vignette examples.

## Downloaded Datasets

### NHANES 2017-2018 (`nhanes/`)

| File | Size | Description |
|------|------|-------------|
| `DEMO_J.xpt` | 3.3 MB | Demographics, sample weights, design variables |
| `BPX_J.xpt` | 1.4 MB | Blood pressure examination |

**Download script:** `download-nhanes.R`
**Source:** [NCHS/CDC](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017)
**License:** Public domain (US Government work)

Design variables:
- **PSU:** `SDMVPSU` (masked variance unit)
- **Strata:** `SDMVSTRA` (masked variance stratum)
- **Weight:** `WTMEC2YR` (2-year exam weight), `WTINT2YR` (interview-only weight)
- **Design:** Stratified multi-stage cluster, unequal probability

```r
as_survey(data, ids = SDMVPSU, strata = SDMVSTRA, weights = WTMEC2YR)
```

---

### BRFSS 2023 (`brfss/`)

| File | Size | Description |
|------|------|-------------|
| `LLCP2023XPT.zip` | 89 MB | Compressed XPT |
| `LLCP2023.XPT` | 1.1 GB | Full BRFSS 2023 dataset |

**Download script:** `download-brfss.R`
**Source:** [CDC BRFSS](https://www.cdc.gov/brfss/annual_data/annual_2023.html)
**License:** Public domain (US Government work)

Design variables:
- **PSU:** `_PSU`
- **Strata:** `_STSTR`
- **Weight:** `_LLCPWT` (combined landline + cell phone weight)
- **Design:** Stratified sample with raking; weights account for non-response

```r
# Note: variable names starting with _ require backtick quoting
as_survey(data, ids = `_PSU`, strata = `_STSTR`, weights = `_LLCPWT`)
```

---

### ACS PUMS 2022 1-Year — Wyoming (`acs-pums/`)

| File | Size | Description |
|------|------|-------------|
| `csv_pwy.zip` | 1.2 MB | Compressed CSV |
| `psam_p56.csv` | 4.0 MB | Wyoming persons file (state FIPS 56) |
| `ACS2022_PUMS_README.pdf` | 176 KB | Census documentation |

**Download script:** `download-acs-pums.R`
**Source:** [Census Bureau ACS PUMS](https://www.census.gov/programs-surveys/acs/microdata/access.html)
**License:** Public domain (US Government work)

**Why Wyoming:** Smallest state → fastest file I/O in tests.

Design variables:
- **Cluster:** `PUMA` (Public Use Microdata Area)
- **Strata:** `ST` (state, all 56 for Wyoming)
- **Weight:** `PWGTP` (person weight)
- **Replicate weights:** `PWGTP1`–`PWGTP80` (successive difference replication)
- **Design:** Successive difference replication (SDR)

```r
as_survey_rep(
  data,
  weights    = PWGTP,
  repweights = starts_with("PWGTP") & !matches("^PWGTP$"),
  type       = "successive-difference"
)
```

---

## Datasets Requiring Accounts (Not Downloaded)

| Dataset | URL | Design Type | Notes |
|---------|-----|-------------|-------|
| Pew Research | https://www.pewresearch.org/datasets/ | Stratified + raking | Free account required |
| GSS | https://gss.norc.org/get-the-data | Stratified multi-stage | Free account required |
| IPUMS | https://ipums.org | Various | Free account required |

---

## Usage in surveycore

These datasets are used for:
1. **Vignette examples** — realistic workflows showing surveycore vs survey package
2. **Numerical validation tests** — confirming surveycore matches `survey::svymean()` etc.
3. **README examples** — quick start demonstrations

For unit tests, use the synthetic generators in `tests/testthat/helper-test-data.R`
instead of these real datasets (faster, no file I/O, fully controlled).
