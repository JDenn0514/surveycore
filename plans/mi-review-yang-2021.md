# Adversarial Literature Review: Yang, Kim, and Hwang (2021)

**Citation:** Yang, S., Kim, J.K., and Hwang, Y. (2021). Integration of data from probability surveys and big found data for finite population inference using mass imputation. *Survey Methodology*, 47(1), 29–58. Statistics Canada, Catalogue No. 12-001-X.

**Review purpose:** Stress-test the claim that mass imputation (MI) covers most of the standard survey estimand family — not just population means and totals, but also proportions, frequencies, ratios, differences between group means, and t-tests — with quantiles and cross-outcome correlations as the main exceptions.

---

## Summary of what the paper covers

Yang et al. (2021) develops a formal asymptotic framework for mass imputation when the study variable Y is observed only in a large non-probability "big data" sample (Sample B) and auxiliary covariates X are observed in both a probability survey (Sample A) and Sample B. The paper establishes consistency and asymptotic normality for three imputation strategies — nearest-neighbor (NNI), k-nearest-neighbor (kNNI), and generalized additive model (GAM) imputation — and proposes a regression calibration efficiency improvement when Sample B membership is observable throughout Sample A. All theoretical results target the general finite population parameter μ_g = N⁻¹ Σ g(Yᵢ) for a known transformation g(·). Empirical work uses population means and one conditional (domain) mean; no other estimand types are evaluated empirically.

---

## Findings that challenge or complicate the claim

### Finding 1: The paper's entire theoretical apparatus is built around a single scalar g(Y) — not vector-valued estimands

**Section 2.1 (p. 32):** The paper defines the target parameter as:

> "the general finite population parameter μ_g = N⁻¹ Σᵢ₌₁ᴺ g(Yᵢ) for some known g(·). For example, if g(Y) = Y, μ_g = N⁻¹ Σᵢ₌₁ᴺ Yᵢ is the population mean of Y. If g(Y) = 1(Y < c) for some constant c, μ_g = N⁻¹ Σᵢ₌₁ᴺ 1(Yᵢ < c) is the population proportion of Y less than c."

The framework is explicitly and exclusively a framework for estimating weighted averages of a scalar function of a single Y. All three theorems (Theorems 1, 2, 3) are stated and proved for this scalar μ_g target only.

**Adversarial implication:** Ratios, differences between group means, and t-tests are not scalar functions of a single Y; they are functions of two or more separate quantities. The paper provides no theoretical coverage of any estimand that requires combining two imputed quantities (e.g., a ratio of two separate means, or a mean difference across domains). The claim that MI "works for" ratios and domain mean differences relies on informal plug-in reasoning that the paper does not validate.

---

### Finding 2: The conditional mean (domain mean) is included in theory only implicitly — and the proof assumptions become stronger

**Section 6.1 (p. 40):** The paper demonstrates estimation of "the conditional population mean of Y₁ given Y₂ = 1." This is framed as one of the "parameters of interest" and results appear in Table 6.1.

However, this conditional mean is not treated separately in the theorem statements. The simulation uses it as a test case but the asymptotic theory (Theorems 1–3) does not explicitly address domain (subgroup) estimation. The conditional mean requires that the domain indicator (Y₂ = 1) and the outcome (Y₁) are both simultaneously imputed or that domain membership is observable, which is a structural requirement not discussed in the theoretical sections.

**Section 2.2 (p. 33):** Assumption 2 (common support) states:

> "The vector of covariates X ∈ Rᵖ has a compact and convex support, with its density bounded and bounded away from zero. There exist constants C_l and C_u such that C_l ≤ f(X)/f(X|δ_B = 1) ≤ C_u almost surely."

For domain estimation, the effective common-support requirement applies within each domain. If some domains are sparse in Sample B, positivity can fail locally even when the global positivity assumption holds. The paper does not acknowledge this complication, making domain estimation silently more demanding than population-level estimation.

---

### Finding 3: kNN imputation creates a structural tension for non-mean estimands

**Section 4.1 (p. 36):** The kNNI estimator averages g(Y) over k donors:

> "Impute the Y value for unit i by μ̂_g(Xᵢ) = k⁻¹ Σⱼ₌₁ᵏ g(Y_{i(j)})."

**Section 4.1 (p. 36), on variance:** The asymptotic variance of the kNNI estimator includes a term:

> V_knn = lim_{n→∞} (n/N²) [E[var_p{Σᵢ∈A πᵢ⁻¹ μ_g(Xᵢ)}] + E{(1 − π_B(X))/π_B(X) · σ_g²(X)}]

where σ_g²(X) = var{g(Y)|X}. This second term is the within-imputation-class residual variance of g(Y) given X. For non-mean estimands where g(Y) is nonlinear (e.g., g(Y) = Y² for variance estimation, or g(Y) = 1(Y < c) for a CDF value), this term picks up a different and larger residual variance than for the mean case. The paper notes this as an efficiency gain consideration but does not warn that for nonlinear g(·), the residual variance σ_g²(X) may be substantially larger relative to the signal, potentially degrading coverage.

**Adversarial implication for proportions:** When g(Y) = 1(Y < c), the imputed value μ̂_g(X) = E[1(Y < c)|X] = P(Y < c|X) is a conditional probability, which the kNN method approximates as the fraction of the k donors with Y < c. This is an averaging over a binary outcome, and the imputed value is a predicted probability in [0,1], not an indicator. This is technically valid as a mean estimator, but it means the individual imputed values used in downstream variance estimation are not 0/1 values — they are probabilities. Whether this causes problems for variance estimation in small domains is not addressed.

---

### Finding 4: The GAM assumption of additive effects is a potentially strong restriction for proportions and multi-modal outcomes

**Section 4.2 (p. 37):** The GAM imputation model assumes:

> "h⁻¹{μ_g(Xᵢ)} = f₁(Xᵢ¹) + f₂(Xᵢ²) + ... + fₚ(Xᵢᵖ)"

The paper itself flags this:

> "To close this subsection, it is worth commenting on the assumption of additive effects of X in model (4.3). This assumption may be fairly strong one."

For binary outcomes (proportions) or counts (frequencies), the relevant model is a logistic or Poisson GAM. The exponential family link function h(·) means interactions between covariates, if present, cannot be captured without explicit tensor product basis expansion. Proportions estimated from a misspecified additive logistic model can be systematically biased in subgroups even when the overall mean is approximately unbiased — a concern directly relevant to the domain estimation use case. The paper does not evaluate proportion estimation for domains or subgroups in its simulation.

---

### Finding 5: The regression calibration step introduces a new estimand-specific dependency — the calibration variables must include functions of both X and Y

**Section 5 (pp. 38–39):** The regression calibration estimator requires specifying calibration variables h(δ_B, X, Y). The paper uses:

> "h(δ_B, X, Y) = (δ_B, 1 − δ_B, δ_B X, δ_B Y)ᵀ"

The calibration constraints are N⁻¹ Σᵢ∈A ωᵢhᵢ* = H, where H is computable from Sample B. Critically, the δ_B Y component means the calibration step uses the imputed Y values as calibration variables. Theorem 3 shows this works asymptotically for μ_g, but the result depends on the imputed values being good predictors of g(Y). For a nonlinear g(·) (e.g., g(Y) = Y² or g(Y) = 1(Y < c)), the imputed values from a model for E[Y|X] are not predictions of g(Y) unless g is the identity. The paper does not state whether the calibration variable set h should be adapted to the specific g(·) being estimated, creating a silent model-estimand mismatch for non-mean estimands.

**Section 5 (p. 38), explicit statement of the limitation:**

> "Standard regression calibration requires all calibration variables to be observed in Sample A and Sample B, and thus rules out the possibility of using Y as the calibration variable due to lack of the outcome data from Sample B."

This constraint is resolved using imputed Y, but this fix was only analyzed for the mean estimand in the theorems. The variance reduction from calibration depends on how well h explains the variability of g(Y_i), which again is g-specific.

---

### Finding 6: The paper explicitly limits asymptotic normality to conditions that become more demanding in sparse domains

**Theorem 1 (p. 35):** Consistency and asymptotic normality require NN·N_B⁻¹ = O(1) — the big data sample must be large relative to the finite population. This is plausible for population-level estimation. For domain estimation in a domain of size N_d << N, the effective condition becomes N·N_{B,d}⁻¹ = O(1) where N_{B,d} is the number of Sample B units in the domain, which may fail for rare subgroups even when the global ratio is satisfied. The paper does not state this domain-level condition explicitly.

**Theorem 2 (p. 36):** For kNNI, the theorem requires n(k/N)^{4/p} → 0, k/n → 0, and k²/n → ∞. The dimension p appears in the exponent. For domain estimation, n is effectively replaced by the domain sample size n_d, making the condition k²/n_d → ∞ more stringent. The curse of dimensionality, already flagged by the paper at p. 34 ("In the presence of a large dimension of X, variable selection is necessary for the nearest neighbor imputation estimator to have good statistical properties"), becomes even more acute for sparse domains.

---

### Finding 7: The empirical evaluation never tests ratio, proportion-in-domain, or difference estimands

The simulation in Section 6 evaluates:
1. Population mean of Y₁ (continuous, Table 6.1 and 6.3)
2. Population mean of Y₂ (binary — a proportion, Table 6.1)
3. Conditional mean of Y₁ given Y₂ = 1 (a domain mean, Table 6.1)

The real-data application in Section 7 evaluates only population means and subgroup means of total cholesterol. No ratio, no difference between two group means with a t-test, no CDF estimand, no frequency distribution is evaluated.

**Adversarial implication:** The empirical coverage of the paper is exclusively means — including one binary mean (proportion) and one conditional mean (domain mean). The claim that MI covers ratios, differences, and t-tests has no empirical support in this paper; it relies entirely on the plug-in principle applied to the g(·) notation, which is only formally established for a fixed scalar g.

---

### Finding 8: The kNN and NN imputation for proportions retains the full Y distribution only approximately — not equivalently to observed data

**Section 3.1 (p. 34):** The paper states a key advantage of NN imputation:

> "Second, nearest neighbor imputation is donor-based, where the imputed value is a value that was actually measured and will always be within the bounds of observed values. Third, in contrast to regression imputation approaches, nearest neighbor imputation can retain the complex variance covariance structure of the data."

This statement is made in the context of the single-Y, single-estimand framework. For a proportion (g(Y) = 1(Y < c)), NNI retains the correct binary character of the imputed value (since Y_{i(1)} is an actual observed 0/1 value), which is indeed advantageous. However, for kNN, the imputed value is an average of k binary outcomes — a probability, not a 0/1 value. The variance covariance structure claim ("can retain the complex variance covariance structure") is stated informally and is not proven for non-identity g(·) or for joint distributions of multiple outcomes.

**Adversarial implication for correlations:** The paper's claim that NNI "retains the complex variance covariance structure" might seem to support cross-outcome correlation estimation. But the proof of Theorem 1 shows convergence only for the univariate μ_g. The joint distribution of (Y₁, Y₂) under NNI is not analyzed, and the assertion about retaining covariance structure is informal. The paper provides no theorem covering bivariate estimands such as Cov(Y₁, Y₂).

---

### Finding 9: Variable selection failure has asymmetric impacts across estimand types

**Section 3.1 (p. 34):**

> "In the presence of a large dimension of X, variable selection is necessary for the nearest neighbor imputation estimator to have good statistical properties. In this case, we suggest selecting important variables that are associated with the outcome in order to ensure Assumption 1 holds and also to increase estimation precision."

For population means, the cost of omitting a variable from X is that ignorability may be violated, introducing bias. For domain mean differences and t-tests, omitting an X variable that interacts with domain membership can cause a systematic bias specifically in within-domain comparisons even when the overall mean is unbiased. The paper does not address the differential sensitivity of different estimands to variable selection errors. The variable selection guidance is provided only for the mean estimand.

---

### Finding 10: The discussion explicitly limits the scope of the paper to the efficiency of the mean estimator

**Section 8 (p. 48):**

> "The mass imputation estimator is not necessarily efficient. In Section 5, we have described a method of using calibration weighting as a tool for efficient data integration with big data."

The efficiency discussion is entirely about the mean estimator. No statement is made about efficiency or even consistency for non-mean estimands. The paper closes by identifying two future research directions (combining MI with IPW when big data fraction is small, and allowing for MNAR), neither of which involves extending the estimand coverage.

---

## Passages that support the claim

**Support 1 — general g(·) notation (Section 2.1, p. 32):**
The paper's target parameter is μ_g = N⁻¹ Σ g(Yᵢ) with explicit examples: g(Y) = Y for the mean, and g(Y) = 1(Y < c) for a proportion. This framing is consistent with the claim that proportions (as means of 0/1 indicators) are covered by the same theory as means.

**Support 2 — binary Y simulation (Section 6.1, p. 40):**
The simulation includes Y₂ as a binary outcome and estimates its population mean, demonstrating that the NNI, kNNI, and GAM estimators work for binary Y (a proportion) with similar bias/coverage properties to continuous Y. This directly supports the claim that proportions are not a special exception.

**Support 3 — conditional mean simulation (Section 6.1, p. 40; Table 6.1, p. 42):**
The conditional mean of Y₁ given Y₂ = 1 is included as a parameter of interest and the estimators work well (low bias, good coverage). This is the domain mean use case most closely related to the claim that group mean differences are covered.

**Support 4 — asymptotic result applies to general g(·) satisfying continuity and bounded moments (Assumption 3, p. 35):**
Theorem 1's regularity conditions require only that μ_g(X) = E{g(Y)|X} is continuously differentiable and E{g(Y)^β|X} is bounded for β = 1, 2. These conditions hold for g(Y) = 1(Y < c) (since E{1(Y < c)|X} = P(Y < c|X) is bounded and the indicator has bounded second moment). This supports the formal validity of proportion estimation within the g(·) framework.

---

## Summary assessment

**Does the paper support, challenge, or complicate the claim?**

The paper **partially supports and substantially complicates** the claim, with the degree of complication varying by estimand type.

**Proportions (g(Y) = 1(Y < c)):** Well-supported. The g(·) framework formally covers any scalar function of Y including indicators, and the binary outcome simulation confirms good finite-sample performance. The claim holds for proportions with no meaningful caveat beyond those that apply to means.

**Domain (subgroup) means:** Partially supported empirically (one simulation case), but not covered by the formal theorems. The paper's theorems address only unconditional population-level μ_g. Domain estimation implicitly requires per-domain common support, and the kNN dimension/sparsity conditions become more stringent for small domains. The claim that domain means are covered is plausible but relies on informal extrapolation beyond the paper's stated results.

**Ratios:** Not addressed anywhere in the paper — not in theory, simulation, or application. Ratios require combining two imputed quantities (two separate applications of the μ_g framework), and the paper provides no theoretical or empirical basis for this extension. The plug-in principle works in practice but the paper does not validate it.

**Differences between group means (for t-tests):** Same situation as domain means: one empirical case supports it, but formal theoretical coverage is absent. A mean difference between two domains is a contrast of two domain estimators, each of which is only informally covered by the theorems.

**t-tests:** Not addressed. A t-test statistic is a ratio of a mean difference to a standard error, requiring valid variance estimation for the difference. The paper's variance estimators (Section 3.2) are designed for μ_g, not for differences or ratios of estimates.

**Quantiles and cross-outcome correlations:** The paper does not address these at all, consistent with them being exceptions. For quantiles, the g(Y) = 1(Y < c) approach can estimate CDF values at individual points c, and in principle the quantile is the inverse of this CDF — but the paper never makes this connection, and the CDF inversion step introduces approximation error not analyzed anywhere. The "retain covariance structure" remark about NNI is informal and unproven for joint bivariate estimands.

**Overall:** The paper's theoretical contributions are narrower than the claim requires. The formal results establish asymptotic validity only for scalar μ_g estimands, with consistency and normality proven under conditions that become more restrictive for sparse domains and high-dimensional X. The claim's optimistic list of covered estimands — ratios, differences, t-tests — goes beyond what Yang et al. (2021) formally establishes, and the paper provides no empirical demonstration of any of those cases. The claim is plausible on plug-in grounds, but this paper should not be cited as theoretical support for those extensions. A practitioner applying MI to a ratio or a mean difference is doing something the paper never validated.

---

## Cross-Check Review

**Reviewer:** adversarial cross-checker reading paper and notes independently
**Paper pages verified:** 29–58 (full paper, including proofs appendix pp. 48–52, references pp. 53–58)

---

### Confirmed findings

The following claims in the notes are accurate and well-grounded in the paper text:

**C1. The general g(·) target parameter (Finding 1, Support 1).**
Section 2.1 (p. 32) does define μ_g = N⁻¹ Σ g(Yᵢ) with the exact examples quoted. The notes correctly report the two explicit examples (g(Y) = Y for the mean; g(Y) = 1(Y < c) for a proportion). The characterization that all three theorems are stated only for this scalar framework is accurate.

**C2. The simulation parameters evaluated (Finding 7, Summary assessment).**
Section 6.1 (p. 40) and Table 6.1 (p. 42) confirm that exactly three parameters are evaluated in simulation 1: population mean of Y₁ (continuous), population mean of Y₂ (binary), and conditional mean of Y₁ given Y₂ = 1. Section 6.2 / Table 6.3 (pp. 43–44) evaluate only the population mean of sales Y in the retail trade context. The real-data application in Section 7 evaluates only population mean total cholesterol and subgroup means by age group and sex. The notes' claim that "no ratio, no difference between two group means with a t-test, no CDF estimand, no frequency distribution is evaluated" is accurate.

**C3. The "retain covariance structure" claim for NNI (Finding 8, Section 3.1, p. 34).**
The exact passage is present: "nearest neighbor imputation can retain the complex variance covariance structure of the data." The notes correctly identify this as an informal claim not proven in any theorem.

**C4. The additive effects caveat for GAM (Finding 4).**
Section 4.2 (p. 38) does contain the text: "To close this subsection, it is worth commenting on the assumption of additive effects of X in model (4.3). This assumption may be fairly strong one." The notes quote this accurately. The paper also notes a mitigation (tensor product basis for interactions), which is correctly characterized as a workaround rather than a proof.

**C5. The calibration variable specification (Finding 5).**
The calibration variable h(δ_B, X, Y) = (δ_B, 1 − δ_B, δ_BX, δ_BY)ᵀ is correctly reported from p. 39 (Section 5). The limitation about standard regression calibration ruling out Y is quoted accurately from p. 38.

**C6. The Theorem 2 kNN conditions (Finding 6).**
Theorem 2 (p. 36) does require n(k/N)^{4/p} → 0, k/n → 0, and k²/n → ∞. The notes correctly transcribe these conditions and correctly note that p appears in the exponent, worsening with dimension.

**C7. The discussion section future research directions (Finding 10).**
Section 8 (p. 48) does contain: "The mass imputation estimator is not necessarily efficient." The two future research topics identified in the notes — combining MI with IPW when big data fraction is small, and MNAR — are both present on p. 48. The notes correctly report that neither involves extending the estimand coverage.

**C8. Theorem 1 condition NN·N_B⁻¹ = O(1) (Finding 6).**
Theorem 1 (p. 35) states "Under Assumptions 1–3 and NN_B⁻¹ = O(1)." The notes correctly report this condition.

**C9. Variable selection guidance is outcome-specific only (Finding 9).**
The passage at p. 34 is quoted accurately: "we suggest selecting important variables that are associated with the outcome." The notes' inference that this guidance is framed exclusively for the mean estimand is correct given the surrounding context.

---

### Corrections

**E1. Section attribution for the kNNI variance formula (Finding 3).**
The notes attribute the kNNI asymptotic variance formula V_knn to "Section 4.1 (p. 36)" twice. This is correct — but the notes' transcription of the formula omits the lim_{n→∞} and writes it as "(n/N²)[...]" rather than lim_{n→∞} (n/N²) E[...]. The paper's Theorem 2 states V_knn as a limit expression: V_knn = lim_{n→∞} (n/N²)(E[var_p{Σ_{i∈A} πᵢ⁻¹ μ_g(Xᵢ)}] + E{(1 − π_B(X))/π_B(X) · σ_g²(X)}). The notes display this correctly in the text but attribute it to "Section 4.1 (p. 36), on variance" — the formula actually appears as part of Theorem 2 on p. 36, not as a standalone section-4.1 result. This is a minor attribution imprecision, not a substantive error.

**E2. The conditional mean parameter is described as "the conditional population mean of Y₁ given Y₂ = 1" (Finding 2, Support 3).**
The notes state (p. 40, Section 6.1) that the paper "demonstrates estimation of 'the conditional population mean of Y₁ given Y₂ = 1.'" This is accurate. However, the notes then say the asymptotic theory "does not explicitly address domain (subgroup) estimation" and that "the conditional mean is not treated separately in the theorem statements." This is correct, but the notes overstate the gap: the paper's introduction (p. 31) explicitly lists "demands include requests for estimates for domains with small sample sizes" as a motivating problem, and the simulation deliberately includes the conditional mean as a parameter of interest precisely to demonstrate domain applicability. The notes do not misrepresent the theory, but the framing slightly undersells the extent to which the paper consciously intends the conditional mean simulation as evidence of domain applicability — even if that intent is not formalized in the theorems.

**E3. Characterization of the real-data application as evaluating "only population means."**
The notes (Finding 7) state: "The real-data application in Section 7 evaluates only population means and subgroup means of total cholesterol." This is accurate for the inference results (Figure 7.1 and the discussion). However, Table 7.1 (p. 47) also evaluates RMSE, mean bias, and correlation of the imputed values at both individual and group mean levels — a prediction quality assessment. The notes do not mention this. This is not a harmful omission for the estimand-coverage question (prediction accuracy is not formal finite-population inference), but it is a missed finding about the scope of the empirical evaluation: the paper does present subgroup-level performance statistics aggregated over age group × sex subgroups, which is the closest it comes to a structured multi-domain evaluation.

**E4. The notes attribute the "parameters of interest" framing to "Section 6.1 (p. 40)"** but in the paper, the statement that the conditional mean is "one of the parameters of interest" is implicit in Table 6.1's structure rather than explicit in any sentence on p. 40. The table header labels simply list the three rows; no sentence on p. 40 uses the phrase "parameters of interest." This is a paraphrasing characterization in the notes rather than a direct quotation, and it is not wrong — but it should be read as the reviewer's inference from the table structure, not a verbatim paper statement.

**E5. The notes' claim about the Theorem 1 asymptotic bias order (Finding 1 / Section 3.1, p. 34).**
The notes do not discuss the asymptotic bias of the NNI estimator. The paper (p. 34) states: "The asymptotic bias of μ̂_{g,nni} is of order O_p(N_B^{-1/p}) (Abadie and Imbens, 2006), which is negligible when the number of continuous covariates is fixed at a reasonable number and the size of the matching donor pool is huge." This is a meaningful finding not captured in the notes. The bias goes to zero as N_B → ∞ at a rate determined by dimension p, so for fixed p and large N_B (big data), the NNI estimator is approximately unbiased for any g(·) satisfying Assumption 3. This provides some additional formal grounding for the g(·) generality claim that the notes do not credit the paper with.

---

### Missed findings

**M1. The paper explicitly endorses the same-dataset multi-estimand use case (Section 3.1, p. 34).**
The paper contains a statement the notes entirely miss: "Moreover, for the same imputed dataset, one can estimate different parameters by choosing reasonable g(·)." This is on p. 34, in the discussion of NNI advantages. This is direct textual support — stronger than the notes give credit for — for the proposition that a single MI exercise can produce multiple estimands by varying g(·). The notes characterize this as "informal extrapolation" but the paper explicitly makes this claim as a listed advantage of NNI. The notes should register this as stronger support, while still noting it is a claim rather than a proved theorem.

**M2. The Section 8 discussion mentions MNAR as a limitation but also points to existing work.**
Section 8 (p. 48) notes: "If the sampling mechanism is believed to be missing not at random, imputation techniques can be developed under the strong structural assumptions for the sampling mechanism (e.g., Riddles, Kim and Im, 2016; Morikawa and Kim, 2018) or the outcome model (e.g., Yang, Zeng and Wang, 2020)." The notes (Finding 10) identify MNAR as a future research topic but do not note that the paper actively cites existing approaches for MNAR — framing it slightly more as an open problem than the paper does.

**M3. The real-data application includes a linear regression model imputation estimator (LM) not discussed in the notes.**
Section 7.2 (p. 45) lists six estimators evaluated in the real-data application: HT, NN, kNN, GAM, LM (linear regression model imputation), IPW, and NAIVE. The notes (Finding 7) describe the real-data application as evaluating "population means and subgroup means of total cholesterol" and list only NN, kNN, GAM methods explicitly. The LM estimator is a parametric imputation method that the paper uses as an additional comparator in the real-data application; it performs competitively with GAM (Table 7.1, p. 47: RMSE 30.35 individual, 4.57 group mean vs. GAM's 29.15 and 4.33). This is relevant to the general claim because the LM estimator is a parametric model for E[Y|X] — the notes do not acknowledge that the paper demonstrates parametric imputation models as an alternative to the non-parametric methods that are the paper's focus.

**M4. The simulation uses a shared latent variable α_i to induce dependence between Y₁ and Y₂.**
Section 6.1 (p. 40–41) specifies Y₁ᵢ = 1 + X₁ᵢ + X₂ᵢ + αᵢ + εᵢ and P(Y₂ᵢ = 1 | X₁ᵢ, X₂ᵢ; αᵢ) with the same αᵢ. The paper states: "The variables αᵢ induce the dependence of Y₁ᵢ and Y₂ᵢ even adjusting for X₁ᵢ and X₂ᵢ." This is a deliberate residual confounding structure — Y₁ and Y₂ are not conditionally independent given X. This is directly relevant to the cross-outcome correlation issue (Finding 8): the simulation is designed with correlated outcomes, yet the paper does not estimate Cov(Y₁, Y₂) or any cross-outcome estimand. The notes mention this limitation but do not note that the simulation's data-generating mechanism was designed in a way that would have made cross-outcome estimation meaningful and testable, yet the authors chose not to do so.

**M5. The paper's asymptotic equivalence result (Theorem 1) has a stronger implication for g(·) generality than the notes credit.**
The notes (Finding 1) correctly state that Theorem 1 proves convergence for scalar μ_g. But the proof in Appendix A.1 (pp. 48–49) shows something slightly more: it proves that for any continuous and bounded g(y), g(Y_{i(1)}) converges in distribution to g(Yᵢ) given Xᵢ as N_B → ∞. This convergence-in-distribution result holds for any continuous bounded g — which, strictly speaking, covers the indicator g(y) = 1(y < c) only in the limit since indicators are not continuous. The proof uses continuity of μ_g(x) = E{g(Y)|X = x} (Assumption 3) rather than continuity of g itself. The notes do not discuss the proof content and therefore miss this nuance: the Assumption 3 condition (μ_g(x) continuously differentiable, E{g(Y)^β|X} bounded) is what does the work, and this condition is verifiable for the indicator function g(Y) = 1(Y < c) since P(Y < c | X) is a probability bounded in [0,1]. The notes acknowledge this in Support 4 but do not connect it to the proof mechanism.

**M6. The paper describes the matching estimator of Rivers (2007) as a special case.**
The abstract states: "The matching estimator of Rivers (2007) is also covered as a special case." The notes do not mention this. This is relevant context for understanding the paper's scope: NNI (the primary estimator) explicitly subsumes the earlier Rivers (2007) mass imputation approach. This does not affect the estimand-coverage question directly, but it establishes that the paper's framework is a generalization of an already-published practical approach.

---

### Overall cross-check verdict

The original notes are accurate in their factual claims about the paper's contents. The direct quotations checked against the paper text are correctly reproduced with one minor attribution imprecision (E1). The adversarial framings — particularly the findings that ratios, differences, and t-tests have no formal theoretical coverage in this paper — are well-supported and not overstated.

The two most significant gaps in the notes are:

1. The notes miss the explicit statement on p. 34 that "for the same imputed dataset, one can estimate different parameters by choosing reasonable g(·)" (M1). This is a direct authorial endorsement of multi-estimand use that the notes characterize only as informal plug-in reasoning.

2. The notes do not report the asymptotic bias order O_p(N_B^{-1/p}) for the NNI estimator (E5/M5), which provides formal grounding for the claim that bias is negligible for large N_B regardless of the choice of g(·) — subject to the regularity conditions on μ_g(x), not on g itself.

Neither gap changes the bottom-line assessment: the paper provides formal support for scalar g(·) estimands including proportions, provides suggestive empirical support for domain means, and provides no theoretical or empirical support for ratios, cross-domain differences, t-tests, or cross-outcome correlations. The notes' overall conclusion is sound.
