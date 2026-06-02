# Adversarial Literature Review: Kim, Park, Chen & Wu (2021)

**Citation:** Kim, J.K., Park, S., Chen, Y., & Wu, C. (2021). Combining non-probability and
probability survey samples through mass imputation. *Journal of the Royal Statistical Society:
Series A (Statistics in Society)*, 184(3), 941–963. https://doi.org/10.1111/rssa.12696

**Paper summary:** This paper establishes asymptotic theory for mass imputation (MI) as a method
for integrating non-probability and probability samples. A prediction model for the study variable
Y is trained on the non-probability sample B (which has both Y and covariates X), then applied to
every unit in the probability sample A (which has X only) to produce imputed values Ŷ. The
Horvitz–Thompson/Hájek-type estimator applied to those imputed values yields the mass imputation
estimator θ̂_I. The paper proves consistency (Theorem 1) and develops linearization and bootstrap
variance estimators (Theorem 2), under a positivity assumption and a transportability assumption
on the conditional mean function. The real-data application estimates population means for four
binary and continuous outcomes using the 2015 Pew Research Centre non-probability sample.

---

## Findings That Challenge or Complicate the Claim

### Finding 1 (Critical): The entire theoretical apparatus is built for the population mean — and the authors say so explicitly

The paper is unambiguous about its scope. In the Concluding Remarks (Section 8, p. 961):

> "The theoretical results on mass imputation presented in this paper **focus on the estimation of
> finite population means**. This is in line with traditional approaches in survey sampling where
> the basic theory is developed for the Horvitz–Thompson estimator. **Inferences on other finite
> population parameters under mass imputation remain to be a research topic for future
> development.**"

This is the sharpest finding. The authors themselves treat the extension to other estimands — ratios,
diffs, t-tests, proportions, quantiles, correlations — as *open future work*, not as a solved
problem. The claim under review asserts that MI works for "most of the standard survey estimand
family." The paper provides zero theoretical support for that claim. It provides one theorem for
the mean and explicitly defers everything else.

The formal estimator of record throughout (Equation 6) is:

> θ̂_I = (1/N) Σ_{i∈A} w_i ŷ_i

This is a weighted mean of imputed values. Every piece of theory — Theorem 1, the linearization
variance formula (Equations 13–17), Theorem 2, and the bootstrap variance estimator — is derived
for this single estimand.

---

### Finding 2: The semiparametric model is specified as a *mean model*, not a full distributional model

The prediction model is defined (Equation 4, p. 946) as:

> E(Y | X = x) = m(x; β₀)

This is explicitly a **conditional mean model**. The paper gives three examples:
- Linear regression for continuous Y
- Logistic regression for binary Y
- Log-linear model for count Y

Crucially, these models specify E[Y|X] — the first moment only. They do not model the full
conditional distribution f(y|x). The imputed values are point predictions ŷ_i = m(x_i; β̂), which
are estimates of E[Y|X=x_i].

**Why this matters for the claim:** Any estimand that requires more than the first conditional
moment cannot be recovered from ŷ_i = E[Y|X]. Quantiles require the conditional CDF. Correlations
between two imputed outcomes require their joint conditional distribution. But even beyond these
acknowledged exceptions, the mean-model framing raises questions for the other claimed estimands:

- **Proportions as special case of means:** The paper does treat binary Y via logistic regression,
  and the PRC application includes three binary outcomes (Y₁, Y₂, Y₃). The estimated quantity
  (Table 5 and Table 9) is the population proportion, reported as a mean. So proportions are
  handled — but only because they *are* means of 0/1 indicators. The theoretical machinery is
  still the mean theorem.

- **Ratios:** A ratio R = Ȳ/X̄ is a ratio of two weighted means. Applying MI to numerator and
  denominator separately and then dividing yields an estimator, but Theorem 1 as stated does not
  cover this. A delta-method extension would be needed. The paper does not provide it.

- **Subgroup differences (diffs):** A difference D = θ̄_1 − θ̄_2 between subgroup means can in
  principle be constructed from two separate MI estimators, but again Theorem 1 is stated only for
  the overall population mean. The variance formula would require the joint distribution of the
  two subgroup estimators, which the paper does not derive.

---

### Finding 3: The variance decomposition is derived for the mean only — its form would change for other estimands

The paper derives the asymptotic variance as V(θ̂_I − θ_N) = V_A + V_B (Equations 13–14, p. 948),
where:

- V_A is the design-based variance from the probability sample A (Equation 13)
- V_B is the model-based variance from the non-probability sample B (Equation 14)

This decomposition is obtained via a Taylor linearization of Equation (6) around β*. The
linearization term (Equation 8) contains g(x_i; β*) = h(x_i; β*)ᵀc, which is specific to the
gradient of the mean estimator with respect to β.

For a different estimand — say a ratio or a quantile — the Taylor linearization would produce
different influence functions, a different decomposition, and potentially different conditions for
the V_B term to dominate or be negligible. The paper provides no guidance on this. The
claim's implicit assumption that the V_A + V_B decomposition "works" for other estimands is not
supported.

The bootstrap variance estimator (Theorem 2, Equation 20–21) is also derived specifically for
θ̂_I as defined in Equation (6). The bootstrap replicate (Equation 19) is:

> θ̂_I^(k) = (1/N) Σ_{i∈A} w_i^(k) ŷ_i^(k)

This is the mean structure applied to bootstrap resamples. For a ratio or a subgroup difference,
the replicate formula would need to change, and consistency of the bootstrap (Theorem 2) would
need to be re-established.

---

### Finding 4: Positivity requirement becomes more restrictive for subgroup estimation

The positivity assumption (Equation 1, p. 945–946) states:

> P(δ = 1 | X = x) > 0 for all x in the support of X.

This must hold over the **entire covariate support** of the finite population. For overall mean
estimation, this means every covariate pattern in the population must have some representation in
the non-probability sample B.

For **subgroup differences**, the requirement becomes strictly harder. If one wants to estimate a
mean difference D = E[Y | Group=1] − E[Y | Group=2], and the subgroup indicator is not itself a
covariate in X, then the imputation model must generalize across the subgroup boundary. If the
subgroup variable is in X (e.g., gender), then positivity must hold *within each subgroup*:

> P(δ = 1 | X = x, Group = g) > 0 for all x, g.

The paper does not discuss this subgroup positivity requirement. In practice, small or rare
subgroups may have thin or zero representation in the non-probability sample, causing the
positivity assumption to fail locally. The paper's treatment of positivity (p. 946) only addresses
the overall population-level condition and briefly notes that "Crump et al. (2009) proposed a
systematic way of subsampling to handle the cases with limited overlaps" — a causal inference
reference that is not integrated into the MI theory here.

---

### Finding 5: The transportability assumption applies to a *univariate* response — multivariate outcomes require separate models and separate assumptions

The paper states in Section 3 (p. 946):

> "In this paper, we consider a semi-parametric model for sample B with the first conditional
> moment specified as E(Y | X = x) = m(x; β₀) for some unknown p×1 vector β₀."

And in the Concluding Remarks (p. 961):

> "The main theoretical results are also based on deterministic imputation under the semiparametric
> model (4), and the model is imposed for **a univariate response variable**. One research topic is
> to explore the use of random imputation, including multiple imputation (Rubin, 1987) and
> fractional imputation (Kim, 2011), for analysing non-probability survey samples. **Another
> research topic is on how to ensure consistency when the analysis involves multivariate response
> variables.**"

This is a direct acknowledgment that handling multiple study variables simultaneously is an
**unsolved problem** as of the paper's writing. The claim under review involves estimands like
correlations between two separately imputed outcomes and t-tests comparing groups — both of which
involve multivariate structure. The paper explicitly flags multivariate consistency as future work.

---

### Finding 6: The model for β is estimated from Sample B with unknown sampling mechanism — this introduces a difficulty for non-mean estimands

The estimating equation (Equation 5, p. 946) is:

> Û(β) = (1/n_B) Σ_{i∈B} {y_i − m(x_i; β)} h(x_i; β) = 0

The consistency of β̂ for β₀ (Equation 7) is shown under the transportability condition (Equation
2), specifically because E{Û(β₀)} = 0 holds under that condition. This is Equation (5) of a
quasi-score estimating equation for a mean model.

For a ratio estimand R_N = Ȳ_N / X̄_N, one would need a model for both Y and X. But X is
observed in both samples A and B, so imputation of X is not needed — but the sampling variance of
the denominator must be accounted for. The paper's β-estimation framework does not extend to this
case, and no adjusted estimating equation is derived.

For a t-test, one would need a test statistic involving a difference of subgroup means divided by
an estimated standard error. The paper's linearization results do not produce the relevant
influence function for this statistic. Whether the bootstrap variance estimator of Section 5 would
correctly capture the variance of a t-statistic is not addressed.

---

### Finding 7: The sensitivity analysis reveals that transportability is outcome-specific and non-transitive — this is a structural problem for multi-estimand inference

Section 7.4 (pp. 957–960) presents a sensitivity analysis where variables Z₁, Z₂, Z₃ that are
observed in both the probability sample and the non-probability sample are treated as study
variables (to check whether MI recovers a Hájek reference estimate).

The key finding (p. 960):

> "Note that results from the sensitivity analysis do not formally prove or disprove the validity of
> the model transportability assumption. For instance, **the transportability of the model f(x₂|x₁)
> does not imply the transportability of the model f(y|x₁, x₂)**. The interpretations of the
> results are further complicated by the mode effect as well as various non-sampling characteristics
> that differ in the two surveys."

This matters for the claim because transportability must be separately asserted for **each study
variable** Y. If one is estimating a difference in means between two outcomes Y₁ and Y₂ (or a
t-test based on such a difference), the transportability assumption must hold for both models
simultaneously, and the joint failure modes are harder to diagnose. The paper offers no framework
for joint transportability across multiple study variables.

---

### Finding 8: The simulation study and empirical application are restricted to means — no evidence for other estimands

The simulation study (Section 6) evaluates bias, variance, and ReMSE for the mass imputation
estimator of θ_N = N⁻¹ Σ y_i exclusively. The three data-generating models (Models I–III, p. 952)
are all set up to compare mean estimators:

> 1. θ̂_A = n_A⁻¹ Σ_{i∈A} y_i (gold standard)
> 2. θ̂_B = n_B⁻¹ Σ_{i∈B} y_i (naive)
> 3. θ̂_I (mass imputation)
> 4. θ̂_IPW (inverse probability weighting)

No ratio, no subgroup difference, no t-statistic is evaluated. The empirical application
(Section 7) estimates population means for four outcomes (Table 5, Table 9, Table 10, Table 11).
The paper provides no empirical evidence that MI works correctly for any estimand beyond the mean.

Three of the four study variables (Y₁, Y₂, Y₃) are binary, and their means are population
proportions. This does provide *indirect* evidence that MI handles proportions — but it does so by
treating them as means of 0/1 variables, which is exactly what the underlying theory covers.
There is no separate treatment of proportions as a distinct estimand class.

---

### Finding 9: Mode effects and non-sampling differences contaminate the estimate — a practical threat to *any* estimand

Section 7.4 (p. 960) identifies a fundamental practical problem: the non-probability sample (PRC,
web-based) and the probability samples (BRFSS, telephone; CPS, mixed-mode) differ in measurement
mode. For binary outcomes like Z₁ (Smoke everyday) and Z₂ (Smoke never), the MI estimate was
closer to the naive (non-probability) sample mean than to the Hájek estimator from the probability
sample:

> "The mass imputation estimator of Z₁ and Z₂ using BRFSS is closer to the naive estimator
> instead of the Hájek estimator, which seems to contradict the theory presented in Section 4."

The authors attribute this to mode effects. The critical implication: **even for the estimand the
paper's theory covers (the population mean), MI can fail in practice when the transportability
assumption is violated by non-sampling differences**. For more complex estimands like group
differences or t-tests, these non-sampling contamination effects would compound — the difference
between two group means could be inflated or deflated by differential mode effects across groups.
The paper offers no remedy beyond sensitivity analysis that is "often inconclusive" (p. 960).

---

### Finding 10: Asymptotic normality is not explicitly proven — only the leading-term expression is established

Theorem 1 (p. 947) states that:

> θ̂_I = θ̄_I + o_p(n_B^{−1/2})

where θ̄_I is the first-order linearization. This establishes the leading term and implies
consistency, but asymptotic normality (√n (θ̂_I − θ_N) →_d N(0, V)) is not stated as a theorem.
It is implied by the linearization under standard central limit theorem conditions, but is not
formally established in the main text. The paper notes proofs are in the Supplementary Material,
which was not available for this review.

For a more complex estimand — say a ratio or a subgroup difference — a full asymptotic normality
result would require: (a) a consistent linearization, (b) a CLT for the linearized term, and (c)
correct variance estimation. Only step (a) is partly addressed in the paper's framework, and only
for the mean.

---

## Passages That Support the Claim

**Binary outcomes as proportions:** The paper's practical application to binary Y₁, Y₂, Y₃
(pp. 953–960) — estimated via logistic regression for the imputation model — does provide empirical
support for the claim that MI handles proportions. The logistic model with ŷ_i = logit⁻¹(x_i'β̂)
produces predictions in [0,1], and their weighted mean is a design-consistent proportion estimator.
This is directly supported by the paper.

**Logistic regression model discussed alongside linear regression:** In Section 3 (p. 946), the
paper explicitly states: "If Y is binary, we can use a logistic regression model." This supports
treating binary outcomes (and hence proportions and frequencies for binary variables) as a covered
case.

**Bias-reduction framing supports the "works for most estimands" intuition:** Equations (11)–(12)
show that the MI estimator reduces bias relative to the naive mean when the prediction model
explains variation in Y. This bias-reduction property is general — it does not depend on the mean
being the estimand. Intuitively, any estimator that substitutes ŷ for y benefits from reduced
residual variation.

**Bootstrap variance estimator is general-purpose in design:** The bootstrap procedure (Section 5)
resamples from both A and B and re-estimates β̂ in each replicate. In principle, a user could
compute *any* replicate-based statistic from the bootstrap imputed values, not just the mean. The
paper's theoretical guarantees for the bootstrap only cover the mean (Theorem 2), but the bootstrap
machinery itself is general.

---

## Summary Assessment

**Does Kim et al. (2021) support, challenge, or complicate the claim?**

**It substantially complicates the claim, and partially challenges it.**

**What the paper actually covers:** The paper's theoretical contributions are restricted to the
population mean, with binary outcomes treated as a special case (proportions as means). This is
stated explicitly: "Inferences on other finite population parameters under mass imputation remain
to be a research topic for future development" (p. 961). The entire theorem-and-variance machinery
— Theorem 1, the V_A + V_B decomposition, Theorem 2, the bootstrap consistency proof — is derived
for one estimand only.

**How this challenges the claim:** The claim states that MI "works for most of the standard survey
estimand family — not just population means and totals, but also proportions, frequencies, ratios,
differences between group means, and t-tests." Kim et al. (2021) provides no theory for ratios,
differences between group means, or t-tests. For these estimands, extending MI is a reasonable
*conjecture* but it is not a proven result in this paper or, by the authors' own statement, in the
literature as of 2021.

**How this complicates rather than fully refutes the claim:** The intuition behind the claim is
sound. Any linear functional of the population distribution (means, proportions, totals, and linear
combinations of these like ratios-by-definition or group differences) can be expressed as a
function of individual imputed values, and the bootstrap variance machinery could in principle be
extended. The paper's framework does not *prohibit* these extensions — it simply does not provide
them. A practitioner applying MI to group differences is extrapolating beyond what the formal
theory covers, without a variance formula that accounts for the additional sources of error specific
to those estimands.

**Strength of the challenge:** Strong on ratios, group differences, and t-tests (no theory
provided, explicitly deferred). Moderate on proportions/frequencies (supported empirically and as
a special case of means, but only because the estimand reduces to a mean). Strong on
multi-outcome consistency (explicitly flagged as unsolved). The mode-effect finding in the
empirical analysis is a practical warning: even for the mean, MI can fail when non-sampling
differences between modes violate transportability, and this failure is harder to detect and correct
for complex estimands.

**Bottom line for implementation:** A surveycore implementation of MI for non-mean estimands
should either (a) restrict the documented scope to means and proportions (the proven case), or
(b) document that extension to ratios, group differences, and t-tests is based on analogy rather
than formal theory, with variance estimates that are heuristic rather than justified by the
Kim et al. (2021) results. The paper's own authors would agree with this framing.

---

## Cross-Check Review

**Reviewer:** Adversarial cross-check against the original paper (Kim, Park, Chen & Wu, 2021, JRSS-A 184(3), 941–963).

**Verdict summary:** The notes are factually reliable and the core analytical thrust is correct. Most
quotes are accurate and in context. Several minor inaccuracies and one significant omission are
documented below.

---

### Confirmed Findings

**Finding 1 — Quote accuracy confirmed.** The Section 8 (p. 961) quote on "finite population means"
and future work is reproduced accurately and in full. Bolding is the reviewer's, not the original
paper's, but this is clearly a stylistic choice and does not misrepresent the text.

**Finding 2 — Equation 4 and model family confirmed.** The paper (p. 946) defines the semiparametric
model as E(Y | X = x) = m(x; β₀) and explicitly names linear regression (continuous Y), logistic
regression (binary Y), and log-linear model (count Y) as the three example specifications. The
notes' characterization of this as "a conditional mean model" specifying only the first moment is
accurate.

**Finding 3 — Variance decomposition confirmed.** Equations (13)–(14) on p. 948 are correctly
described as a V_A + V_B decomposition via Taylor linearization of Equation (6) around β*.
The notes' identification of g(x_i; β*) = h(x_i; β*)'c as the gradient-specific linearization
term (Equation 8, p. 947) is accurate.

**Finding 4 — Positivity assumption confirmed.** Equation (1) on p. 945–946 reads exactly as
quoted: P(δ = 1 | X = x) > 0. The Crump et al. (2009) causal-inference reference is correctly
identified and its context (limited overlap handling) is accurately characterized.

**Finding 5 — Univariate model scope confirmed.** The Section 8 (p. 961) passage about
"a univariate response variable" and "multivariate response variables" as future work is quoted
accurately. The two research topics (random imputation and multivariate consistency) are correctly
identified.

**Finding 7 — Sensitivity analysis quote confirmed.** The Section 7.4 (p. 960) passage about
transportability of f(x₂|x₁) not implying transportability of f(y|x₁, x₂) is reproduced
accurately. The phrase "often inconclusive" is a reasonable paraphrase of "results are often
inconclusive" (p. 960, last sentence of Section 7.4).

**Finding 8 — Simulation estimands confirmed.** The four estimators listed for the simulation
study are correctly drawn from p. 952: the sample mean from A (gold standard), naive sample mean
from B, MI estimator, and IPW estimator of Chen et al. (2020). All simulation outcomes are
means of Y_i, not ratios or differences.

**Finding 9 — Mode effect finding confirmed.** The passage about Z₁ (Smoke everyday) and Z₂
(Smoke never) being closer to the naive estimator is confirmed (p. 960, Table 11). The paper
explicitly attributes this to mode effects, exactly as the notes describe.

**Finding 10 — Asymptotic normality claim confirmed.** Theorem 1 (p. 947) states θ̂_I = θ̄_I +
o_p(n_B^{−1/2}) — a leading-term linearization result — without explicitly stating an asymptotic
normality theorem in the main text. The notes' characterization of this as "implied but not formally
stated" is accurate. The paper does say "Proof of Theorem 1 is presented in the online Supplementary
Material" (p. 947), so full normality proofs may exist there, but this is correctly flagged as not
verifiable from the main text.

---

### Corrections

**Correction 1 (Minor): The study variables include one continuous outcome, not four binary ones.**

The notes in the paper summary state the application "estimates population means for four binary
and continuous outcomes." This is accurate as a combined description, but Finding 8 refers to
"Y₁, Y₂, Y₃" as "binary" without noting that Y₄ (Days had at least one drink last month) is
continuous. More importantly, on p. 944, the paper states: "among them three are binary variables:
Talk with neighbours frequently (Y₁), Participated in school groups (Y₂), Participated in service
organizations (Y₃), and one is treated as a continuous variable: Days had at least one drink last
month (Y₄)." Finding 8's sentence "The paper provides no empirical evidence that MI works correctly
for any estimand beyond the mean" is correct, but the implicit framing throughout several findings
that the application is restricted to binary outcomes understates the scope — the continuous Y₄
is included in every table (Tables 5, 6, 9, 10) and is an important part of the empirical results.
This is a minor framing issue, not a factual error.

**Correction 2 (Minor): The sensitivity analysis variables are labeled Z₁, Z₂, Z₃ in the paper,
not Y₁, Y₂, Y₃.**

Finding 7 refers to "variables Z₁, Z₂, Z₃" which is correct — the paper uses Z notation for the
sensitivity analysis study variables (Section 7.4, p. 958–960) specifically to distinguish them
from the primary study variables Y₁–Y₄. Finding 9 also correctly uses Z₁ and Z₂. However, the
notes in Finding 7's second paragraph refer to "Y₁ and Y₂" as variables in a "difference in means"
example. This is a hypothetical constructed example in the notes, not a claim about the paper, so
it does not constitute a misreading — but the shift in notation from Z back to Y in a counterfactual
is potentially confusing to a reader cross-referencing the paper.

**Correction 3 (Moderate): The characterization of the bootstrap replicate formula
(Equation 19) is slightly imprecise.**

The notes (Finding 3) state that the bootstrap replicate is θ̂_I^(k) = (1/N) Σ_{i∈A} w_i^(k) ŷ_i^(k).
This is correct per Equation (19) on p. 951. However, the notes describe this as "the mean
structure applied to bootstrap resamples." This is accurate but elides a critical design feature:
the bootstrap in Theorem 2 additionally requires the ignorability assumption (Equation 3), whereas
Theorem 1 does not require it. Specifically, Theorem 2 (p. 951) states: "assume that the sampling
mechanism for sample B is ignorable as defined in Equation (3)." This is a strictly stronger
condition than Theorem 1 requires, and it is not mentioned in the notes. The practical implication
is that the bootstrap variance estimator has a more restrictive scope of validity than the
linearization variance estimator — an important distinction the notes do not draw.

**Correction 4 (Moderate): The description of β* and the bias expression conflates two cases.**

In Finding 6, the notes describe the estimating equation (Equation 5, p. 946) and state that
consistency of β̂ for β₀ is shown "under the transportability condition (Equation 2)." This is
a slight mischaracterization. The paper (p. 947) defines β* = plim β̂ where the reference
distribution is the sampling mechanism for sample B. Under the ignorability condition (Equation 3),
β* = β₀. But under the weaker transportability condition alone, β* ≠ β₀ in general — the paper
explicitly notes "The theorem does not imply that the estimator is unbiased" (p. 948). The bias
expression (Equations 10–12) is derived specifically to characterize the bias when β* ≠ β₀. The
notes' framing in Finding 6 that "consistency of β̂ for β₀ is shown under the transportability
condition" overstates what Equation (7) establishes: Equation (7) shows β̂ − β* = O_p(n_B^{−1/2}),
which is consistency for β*, not for β₀. This distinction is implicit in the notes' broader
argument but is not called out, and it is directly relevant to the bias discussion in Finding 6.

---

### Missed Findings

**Missed Finding A: The paper explicitly discusses the Hájek-type estimator as an alternative
to the HT estimator in Equation (6), and this matters for the notes' scope claim.**

The paper's abstract refers to "inferences on the parameters of interest," and Equation (6) is
described as using survey weights w_i for sample A. The notes correctly identify this as a
weighted mean, but do not note that the paper discusses (p. 947) that if N is unknown, it can be
estimated by N̂ = Σ_{i∈A} w_i, giving a Hájek-type estimator. This Hájek version is what is used
throughout the empirical application (Table 5 explicitly presents MI estimates alongside Hájek
estimates). The distinction between HT and Hájek is immaterial for the main critique, but the
notes' paper summary says "Horvitz-Thompson/Hájek-type estimator" which slightly overstates the
dual nature — the theoretical results are developed primarily for Equation (6), and the Hájek
adjustment is treated as a practical note rather than a separate theorem.

**Missed Finding B: The paper makes an important positive practical observation about
sample-size insensitivity that partially cuts against the notes' pessimism.**

Section 7.1 (p. 955) and Table 5 show that using the very large BRFSS sample (n_A = 441,456) and
a subsampled BRFSS^(1) (n_A* = 80,000) produce "almost identical results." The paper concludes
(p. 955): "The size of the probability sample is less crucial as long as it is not too small."
This practical finding — that MI estimates are robust to substantial reductions in the probability
sample size — is relevant context for implementation. If anything, it slightly strengthens the
practical case for MI: the V_A component becomes negligible when n_A is large relative to n_B,
which the notes mention algebraically (in Finding 3) but do not connect to the concrete empirical
evidence in Table 5.

**Missed Finding C: The paper's Introduction explicitly categorizes MI as one of three approaches,
the other two being IPW and doubly robust — and notes that all three share the ignorability
assumption.**

The Introduction (p. 942) states: "there are three possible approaches to analysing non-probability
survey samples: (i) inverse probability weighting (IPW) using estimated propensity scores;
(ii) model-based prediction using an outcome regression model; and (iii) doubly robust procedures
involving both the propensity scores and the outcome regression model." This framing is relevant
to the claim under review: the notes focus exclusively on MI as a method, but the paper itself
positions MI within a comparative framework and notes (p. 942) that "All approaches require the
ignorability assumption." The comparison with IPW in Sections 6 and 7.3 is relevant to evaluating
MI's scope — notably, MI outperforms IPW in simulation (Table 3, ReMSE always lower) and produces
comparable estimates in the real data (Table 10). The notes mention the IPW comparison in passing
(Finding 8) but do not note that the paper frames MI as superior on variance grounds for all
three simulation models, which is relevant context for any claim about MI's practical utility.

**Missed Finding D: The paper explicitly raises the question of which probability sample to use
when multiple are available, and the answer depends on covariate availability — this is a
structural constraint on MI for any estimand.**

Section 7.2 (pp. 955–956) and Tables 7–9 show that the choice of covariates (ξ(Partial), ξ(All),
ξ(Select)) has substantial impact on point estimates. The observation in Table 9 that ξ(All)
"behave quite differently" from ξ(Partial) for some outcomes (e.g., Y₁ with CPS drops from 0.458
to 0.404) is a finding the notes do not address. This matters for the extended claim: even for the
mean, MI estimates are sensitive to covariate selection. For more complex estimands like ratios or
group differences, covariate-sensitivity would compound. The backward variable selection approach
(ξ(Select)) is only briefly mentioned in the notes' summary and is not analyzed as a complication
for any estimand beyond the mean.

**Missed Finding E: Theorem 2 requires the ignorability condition (Equation 3), which is strictly
stronger than what Theorem 1 requires — this means the bootstrap variance estimator has narrower
applicability than the linearization estimator.**

As noted in Correction 3 above, this is a material finding that the notes miss entirely. The
practical consequence is: a user applying MI with a heuristic variance estimate (using the
bootstrap) for a non-mean estimand is implicitly relying on an assumption that is (a) stronger
than the consistency theorem requires, and (b) untestable from the data. The notes' discussion
in the "Passages That Support the Claim" section states that "the bootstrap machinery itself is
general" — this is true but incomplete, because the theoretical justification for the bootstrap
requires ignorability, not just transportability.

---

### Overall Assessment of the Notes

The notes are analytically sound and the core conclusions are well-supported. The key quote
(Section 8, p. 961) is reproduced accurately and is unambiguously the most important single
finding. The notes correctly identify the theoretical scope restriction, the mean-model framing,
and the mode-effect problem in the empirical application. The three corrections above are minor
in the context of the overall argument. Missed Findings C and D provide useful additional context
but do not reverse any of the notes' conclusions. Missed Finding E (Theorem 2's ignorability
requirement) is the most substantively important omission — it strengthens the notes' argument
that the bootstrap variance estimator has narrower validity than the notes imply when they describe
it as "general-purpose."
