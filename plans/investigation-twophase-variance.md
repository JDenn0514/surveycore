# Investigation: Twophase Variance Underestimation

**Filed:** 2026-03-09
**Priority:** High — affects all Phase 1 analysis functions + GLM for twophase designs
**Status:** Fixed — `R/variance-twophase.R` (2026-03-09)

---

## Symptom

For `survey_twophase` designs, surveycore computes approximately **half** the
correct variance for all estimands.

```r
df_p <- make_survey_data(design = "twophase", seed = 42)
ph1  <- as_survey(df_p, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
d_sc <- as_survey_twophase(ph1, subset = subset, method = "approx")
d_sv <- as_svydesign(d_sc)   # oracle

get_means(d_sc, y1, variance = "se")$se          # 0.577  ← surveycore
survey::SE(survey::svymean(~y1, d_sv))            # 0.810  ← survey (correct)
```

Variance ratio: `0.333 / 0.657 ≈ 0.507 ≈ 1/2`
SE ratio: `0.577 / 0.810 ≈ 0.712 ≈ 1/sqrt(2)`

The underestimation is consistent across multiple synthetic datasets and
multiple estimands (mean, total, etc.).

---

## Affected Functions

All Phase 1 analysis functions that call `.twophasevar()`:
- `get_means()` via `.twophase_mean()`
- `get_totals()` via `.twophase_total_cell()`
- `get_freqs()` via `.twophase_freq_cell()`
- `get_corr()` via `.twophase_corr_cell()` (if exists)
- `get_quantiles()` via quantile twophase path
- `get_ratios()` via ratio twophase path
- `survey_glm()` via `.twophase_var_score_matrix()`

---

## Suspected Location

`R/variance-twophase.R`, function `.twophase_phase1_var()` (lines ~80–186).

The formula for `method = "approx"` (and `"full"`) implements:

```r
# Current surveycore formula (per stratum s):
v1_total <- v1_total + sum((x_scaled / sqrt(pi2_agg))^2) * scale_s
# where scale_s = f_s * nPSUfull_s / (nPSUfull_s - 1L)
```

The survey package's `onestrat.phase1()` function uses:

```
nPSUfull * (nPSUfull/(nPSUfull-1)) * scale * crossprod(x/sqrt(pi2)) / nPSU
```

This includes an extra `nPSUfull / nPSU` factor. For the synthetic data,
`nPSUfull/nPSU ≈ 1.04` (not ≈ 2), so this factor alone does not explain the
2x variance discrepancy. The root cause likely lies elsewhere — possibly in:

1. The influence function construction (`.twophase_build_inputs()`)
2. The xcenter computation (`xcenter_s <- mean(x_agg * nPSU_s / nPSUfull_s)`)
3. The x_scaled formula (`x_scaled <- x_agg * pi2_agg - xcenter_s`)
4. The phase 2 variance component (`.twophase_phase2_var()`)

---

## Investigation Plan

1. **Isolate V1 vs V2:** Determine if the underestimation comes from the Phase 1
   component, Phase 2 component, or both. Already partially done:
   - `v1 = 0.307, v2 = 0.026, total = 0.333` (surveycore, `method = "approx"`)
   - Survey total = 0.657
   - So V1 is the primary source of underestimation.

2. **Compare influence vectors:** Compute the influence vector for `y1` mean
   using surveycore's `.twophase_build_inputs()` and compare to the survey
   package's linearized influence (via `survey::svyrecvar()` or manual
   computation). They should be identical if the influence is correct.

3. **Step through `.twophase_phase1_var()`:** For a single stratum, compute
   `v1_s` manually and compare to survey's `onestrat.phase1()` output.

4. **Check `method = "simple"` separately:** The `simple` path uses
   `.svy_recvar()` directly with raw influence — this may or may not share the
   same bug.

5. **Write oracle tests** for `variance-twophase.R` comparing against
   `survey::svymean()`, `survey::svytotal()` for all three methods
   (`simple`, `approx`, `full`).

---

## Oracle for Verification

```r
devtools::load_all()

df_p <- make_survey_data(design = "twophase", seed = 42)
ph1  <- as_survey(df_p, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
d_sc <- as_survey_twophase(ph1, subset = subset, method = "approx")
d_sv <- as_svydesign(d_sc)  # survey equivalent via as_svydesign()

# Mean oracle
m_sc <- get_means(d_sc, y1, variance = "se")
m_sv <- survey::svymean(~y1, design = d_sv, na.rm = TRUE)
cat("SC SE:", m_sc$se, "| Survey SE:", survey::SE(m_sv), "\n")

# Total oracle
t_sc <- get_totals(d_sc, y1, variance = "se")
t_sv <- survey::svytotal(~y1, design = d_sv, na.rm = TRUE)
cat("SC SE:", t_sc$se, "| Survey SE:", survey::SE(t_sv), "\n")
```

---

## Notes

- This bug was NOT introduced in any specific PR — it originates from Phase 0.75
  (two-phase variance vendoring). The Phase 0.75 implementation did not include
  numerical oracle tests against `survey`.
- The `survey_glm()` twophase SE oracle is written with a relaxed criterion
  (no crash, SEs positive finite) in PR 6 precisely because of this bug.
- Fixing this bug will require re-running `devtools::test()` and potentially
  updating snapshot tests if twophase variance outputs are snapshotted.
