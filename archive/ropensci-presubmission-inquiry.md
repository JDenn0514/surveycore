# rOpenSci Pre-Submission Inquiry — surveycore

Open an issue at https://github.com/ropensci/software-review/issues/new/choose
and select **"Pre-submission Inquiry"**. Paste the content below.

---

**Submitting Author:** Jacob Dennen (@JDenn0514)
**Repository:** https://github.com/JDenn0514/surveycore
**Version:** 0.6.2

---

## Pre-submission Inquiry: surveycore

### Package overview

**surveycore** provides S7-based infrastructure for survey analysis in R, including design objects, a metadata/label system, and variance estimation. It is the foundation of the **surveyverse ecosystem** — a modern, tidyverse-compatible replacement for the `survey` and `srvyr` packages.

The package supports:
- Taylor series linearization (`survey_taylor`)
- Replicate weight designs — BRR, Jackknife, Fay's BRR, bootstrap (`survey_replicate`)
- Two-phase designs (`survey_twophase`)
- Non-probability samples (`survey_nonprob`)

All design types share a unified tidy-select constructor interface (`ids = psu`, `weights = wt`, `strata = strata`) and an automatic metadata system that preserves `haven`-style variable and value labels throughout all operations.

Analysis functions — `get_freqs()`, `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`, `get_ratios()`, `get_diffs()` — return tidy tibbles annotated with label metadata, enabling downstream label-aware display (e.g., with `gt`). The package also provides `survey_glm()` for survey-weighted GLMs with `marginaleffects`-backed confidence intervals.

---

### DESCRIPTION

```
Package: surveycore
Title: Core Survey Analysis Infrastructure
Version: 0.6.2
Authors@R:
    person(
        "Jacob", "Dennen",
        email = "jdenn0514@gmail.com",
        role = c("aut", "cre", "cph"),
        comment = c(ORCID = "0000-0003-3006-7364")
    )
Description: Provides 'S7'-based infrastructure for survey analysis including
    design objects, metadata preservation, and variance estimation. Forms the
    foundation of the surveyverse ecosystem. Supports Taylor series, replicate
    weight, and two-phase designs with a 'tidyselect' interface for intuitive
    design specification. Automatic preservation of 'haven'-style variable and
    value labels throughout all operations.
License: GPL (>= 3)
URL: https://github.com/JDenn0514/surveycore, https://jdenn0514.github.io/surveycore/
BugReports: https://github.com/JDenn0514/surveycore/issues
Depends:
    R (>= 4.3.0)
Imports:
    S7 (>= 0.1.0),
    rlang (>= 1.0.0),
    tidyselect (>= 1.2.0),
    cli (>= 3.6.0),
    tibble (>= 3.1.0),
    dplyr (>= 1.1.0),
    marginaleffects (>= 0.18.0),
    stats,
    graphics
Suggests:
    testthat (>= 3.0.0),
    withr (>= 2.5.0),
    survey (>= 4.0),
    survival,
    srvyr (>= 1.0),
    haven (>= 2.5.0),
    lifecycle (>= 1.0.0),
    broom (>= 1.0.0),
    covr,
    knitr,
    rmarkdown
VignetteBuilder: knitr
Encoding: UTF-8
RoxygenNote: 7.3.3
Roxygen: list(markdown = TRUE)
```

---

### Category selection and justification

I am requesting review under **two statistical categories**:

- **EA — Exploratory Data Analysis and Summary Statistics:** The core of the package is the suite of analysis functions (`get_freqs()`, `get_means()`, `get_totals()`, `get_corr()`, `get_quantiles()`, `get_ratios()`, `get_diffs()`) which compute design-consistent point estimates and confidence intervals for complex probability samples. These directly match the EA category's scope of summary statistics with uncertainty quantification.

- **RE — Regression and Supervised Learning:** The `survey_glm()` function fits survey-weighted generalized linear models (logistic, linear, Poisson, etc.) using Taylor-series or replicate-weight variance estimation. Coefficients, standard errors, and confidence intervals are design-consistent. This maps to the RE category.

There is no dedicated "survey statistics" category in rOpenSci. I believe EA + RE best captures the package's scope, and I am seeking editorial confirmation before proceeding with a full submission.

---

### Target audience and scientific applications

**Primary users:** Survey researchers and methodologists who analyse complex probability samples — stratified, clustered, replicate-weight, and two-phase designs — and need design-consistent variance estimates. Also applicable to social scientists, epidemiologists, and public health researchers working with population surveys such as NHANES, ACS, GSS, Pew Research datasets, or custom organizational surveys.

**Scientific applications:** Any domain that requires population inference from survey microdata with correct standard errors: public health surveillance (NHANES), social science research (GSS, ANES), labor economics (CPS, SIPP), political polling, and custom probability samples.

---

### Relationship to existing packages

The two existing packages for complex survey analysis in R are `survey` (Lumley, 2004) and `srvyr` (Ellis & Lumley). surveycore is a ground-up reimplementation — not a wrapper — that addresses three limitations in the current landscape:

| Feature | `survey` | `srvyr` | `surveycore` |
|---------|----------|---------|--------------|
| Object system | S3/S4 | S3 wrapping survey | S7 (modern, formal) |
| Interface | Formula syntax (`~var`) | dplyr verbs | Tidy-select bare names |
| Label preservation | None | None | Automatic (haven-style) |
| Analysis output | Numeric vectors | Tibbles (partial) | Annotated tibbles with label metadata |
| Ecosystem design | Monolithic | Wrapper only | Foundation + companion packages |

A `vignette("surveycore-vs-survey")` provides a side-by-side comparison with code examples.

surveycore's variance engines are **vendored** from the `survey` package (GPL-3, Thomas Lumley) with his attribution preserved in `VENDORED.md`. The numerical results are identical to `survey` — this is by design and verified in 2,600+ tests. The improvement is in the object model, interface ergonomics, and label infrastructure.

---

### Statistical standards compliance

Yes — the package incorporates `srr` statistical standards annotations throughout the source code. As of the submitted version:

- `@srrstats`: 108 tags (standards met, with explanations)
- `@srrstatsNA`: 42 tags (standards not applicable, with justifications)
- `@srrstatsTODO`: 0 (all resolved)

Standards span General (G), EDA (EA), and Regression (RE) categories. `srr::srr_stats_pre_submit()` passes cleanly.

---

### Ethics and data privacy

surveycore analyses existing survey microdata; it does not collect data. No personally identifiable information is processed in the package itself. The bundled datasets (`nhanes_2017`, `ns_wave1`, `pew_jewish_2020`) are either publicly released by federal agencies (NHANES: CDC/NCHS) or are teaching datasets derived from published public polls with no individual identifiers. The package does not interact with any web service, API, or external system.

---

### Additional notes

- The package is not currently on CRAN. This rOpenSci review would precede CRAN submission.
- The companion package `surveytidy` (dplyr verbs for survey objects) is under development and would be submitted separately after surveycore is accepted.
- All pkgcheck **(R)** required checks pass. The only outstanding items are optional **(S)** goodpractice linter notes (a small number of lines exceeding 80 characters after recent refactors) and informational duplicate-name notes (e.g., `get_totals` also exists in the `gt` package).

A few things I would appreciate early guidance on before opening a full submission:

1. **Scope confirmation:** Is EA + RE the right category mapping for a complex survey analysis package?
2. **Vendored code:** The GPL-3 variance engines vendored from `survey` are a structural dependency. Is this approach acceptable under rOpenSci policy, given full attribution in `VENDORED.md` and `Authors@R`?
3. **Ecosystem packages:** Should `surveytidy` be submitted jointly or separately?

---

Thank you for your time. I'm happy to provide any additional information.
