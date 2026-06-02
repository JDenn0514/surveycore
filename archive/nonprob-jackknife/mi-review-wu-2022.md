# Adversarial Literature Review: Wu (2022)

## Citation

Wu, Changbao (2022). "Statistical inference with non-probability survey samples."
*Survey Methodology*, Vol. 48, No. 2, pp. 283–311. Statistics Canada, Catalogue No. 12-001-X.
Released December 15, 2022.

## Paper Summary

This paper provides a critical review of statistical inference with non-probability survey
samples (NPS), structured around four explicit assumptions (A1–A4). The paper presents three
inferential frameworks: model-based prediction (the ξp framework, which includes mass
imputation), propensity-based inverse probability weighting (the qp framework), and doubly
robust estimation. Throughout, the formal theoretical targets are population means μ_y. The
paper covers variance estimation strategies, quota surveys and poststratification, assumption
verification, and identifies open research problems. The paper was delivered as the 2021 SSC
Special Presidential Invited Address and constitutes one of the field's most authoritative
review papers on NPS inference.

---

## Findings That Challenge or Restrict the Claim

### Finding 1: The entire formal theory is scoped explicitly to the population mean

**Page 284, Section 2:** "Let μ_y = N⁻¹ Σᵢ₌₁ᴺ yᵢ be the population mean which is the
parameter of interest." This sentence opens the technical framework and is never broadened.

**Page 302, Section 7 (opening paragraph):** "Our discussions on estimation procedures for
non-probability survey samples are under the assumptions A1-A4 and the focuses are on the
validity and efficiency of estimators for the **finite population mean** under three inferential
frameworks."

This is a direct, explicit acknowledgment by the author that the theoretical guarantees
developed in the paper — consistency, asymptotic variance formulas, doubly robust properties —
are established only for μ_y (the finite population mean). No comparable theorem is developed
for proportions, ratios, differences between subgroup means, or test statistics. The claim
that MI "works for most of the standard survey estimand family" extrapolates beyond what Wu
formally establishes.

**Adversarial bite:** The claim relies on the intuition that proportions are special cases of
means and ratios are smooth functions of means. That intuition may be correct, but Wu does not
validate it. The paper provides no theorems, no asymptotic derivations, and no empirical
demonstrations for non-mean estimands. A reader who relies on Wu (2022) as the theoretical
grounding for MI applied to ratios, differences, or t-tests would be citing a paper that
explicitly restricts its scope to means.

---

### Finding 2: The transportability assumption (A1) is specified in terms of conditional
means, creating a scope limitation for non-mean estimands

**Page 286, Section 3.1:** The outcome regression model is:

> E_ξ(yᵢ | xᵢ) = m(xᵢ, β), and V_ξ(yᵢ | xᵢ) = v(xᵢ)σ², i = 1, 2, ..., N

**Page 288, Section 3.3:** Under A1, "the assumption A1 implies the so-called model
transportability by Kim, Park, Chen and Wu (2021): the model which is built for the
non-probability sample can be used for prediction with the reference probability sample."

The transportability condition is stated in terms of the conditional mean function m(·). It
ensures that E_ξ(yᵢ | xᵢ, Rᵢ = 1) = E_ξ(yᵢ | xᵢ), i.e., the mean regression model fit in
the NPS can be applied to the reference sample. This is sufficient for estimating μ_y (a
population mean) but does not directly guarantee transportability of higher moments, quantile
functions, or joint distributions of (y₁, y₂) for two separate outcome variables.

**Adversarial bite:** For ratios (μ_y / μ_z), the delta method argument that this is a smooth
function of two means requires both μ_y and μ_z to be consistently estimated. Wu establishes
consistency for each mean separately, but the joint asymptotic theory for two MI estimators
applied simultaneously to two different outcomes from the same NPS is not addressed. Whether
the two-sample variance formula extends cleanly is unstated.

---

### Finding 3: The mass imputation section explicitly raises the open question of whether
MI can support general statistical inference — and declares it unanswered

**Page 289, Section 3.3 (emphasis added):**

> "The mass imputation approach to analyzing non-probability survey samples leads to an
> interesting research question that is currently under investigation by a doctoral student at
> University of Waterloo: **Is it theoretically feasible and practically useful to create a
> mass-imputed dataset {(yᵢ*, xᵢ, dᵢᴮ), i ∈ Sᴮ} based on the reference probability survey
> sample that can be used for general statistical inferences? The answer clearly depends on the
> types of inferential problems to be conducted over the imputed dataset.**"

This is the most direct challenge to the claim. Wu is not asserting that MI works for general
estimands — he is treating that as an open research question at the time of writing, explicitly
flagging that the answer depends on the type of inferential problem.

**Continuing (page 289):**

> "A minimum requirement is that the **conditional distribution of the study variable y given
> the covariates x is preserved** for the mass-imputed dataset. The nearest neighbor imputation
> method and the **random regression imputation method** can be useful for this purpose.
> **Fractional imputation is another possibility, especially for binary or ordinal study
> variables.** Multiple imputation is also potentially useful in this direction..."

This passage contains two critical points for the claim:

1. **The conditional distribution — not just the conditional mean — must be preserved** for
   general inference. Standard deterministic regression imputation (Ŷ = x'β̂), which is what
   the MI estimator in equation (3.5) uses, only preserves the conditional mean. Wu explicitly
   identifies this as insufficient for general inference, and points to random regression
   imputation, fractional imputation, and multiple imputation as alternatives that better
   preserve the conditional distribution.

2. **Binary or ordinal study variables require special treatment** (fractional imputation).
   Logistic regression imputation producing predicted probabilities is different from the
   linear-predictor MI setup that the formal theory covers. Wu flags this as a distinct case
   requiring a distinct method, not a straightforward extension of the continuous-y framework.

**Adversarial bite:** The standard MI estimator μ̂_yMI uses deterministic imputed values
yᵢ* = m(xᵢ, β̂). Wu's own analysis shows this is not sufficient for inference beyond the
mean without additional conditions. The claim that MI works for proportions and t-tests may
implicitly require random/fractional imputation rather than deterministic regression imputation —
a non-trivial methodological distinction that requires separate validation.

---

### Finding 4: Variance estimation theory for MI is derived specifically for the mean
estimator, and the bootstrap recommendation is tied to this specific form

**Page 298, Section 6.1:**

> "Variance estimation for the model-based prediction estimator μ̂_y involves first deriving
> the asymptotic variance formula for Var(μ̂_y − μ_y) under the assumed outcome regression
> model or the imputation model ξ and the probability sampling design p..."

The entire variance derivation in Section 6.1 is for the estimator μ̂_yMI as an estimator of
μ_y. The two-step Taylor linearization (linearizing at β*, then decomposing into two variance
components from the NPS model and the reference sample design) is specific to this estimand.

**Page 298:**

> "A bootstrap variance estimator turns out to be more attractive for practical applications.
> See Kim et al. (2021) for further details."

The bootstrap recommendation here is motivated by the complexity of the analytical variance
formula for the mean estimator specifically. Wu does not discuss whether bootstrap correctly
captures variance for MI applied to ratios, differences, or t-statistics. For a ratio estimator
built from two separately-imputed outcomes, the bootstrap would need to resample both NPS
and reference sample jointly, and the variance components would differ from those for a single
mean. This is not analyzed anywhere in the paper.

**Adversarial bite:** The claim states that "normal probability-sample estimation" applies
once Ŷ values replace Y. But the two-source variance structure (one component from the NPS
outcome model, one from the reference sample design) does not disappear for non-mean
estimands. A ratio of two MI means has variance that involves the covariance between the two
MI estimators across bootstrap resamples of both samples — a materially different calculation
than what Section 6.1 covers.

---

### Finding 5: The domain/subgroup estimation problem is not addressed for MI; it is
addressed only implicitly through the poststratification framework

The paper's Section 5 on quota surveys and poststratification discusses subgroup estimation,
but in the context of the IPW estimator (equation 5.1), not the MI estimator. The estimator
in (5.1) is a weighted sum of within-subgroup means, each requiring adequate subgroup sample
sizes (the paper recommends m_A ≥ 30 per post-stratum, page 297).

For domain estimation under MI, the paper provides no guidance. If a domain d is defined
(say, a particular demographic group), the MI estimator for the domain mean would be:

   μ̂_d,MI = (N̂_d,B)⁻¹ Σ_{i ∈ S_B, i ∈ d} dᵢᴮ yᵢ*

This requires either (a) knowing domain membership for all i ∈ S_B from the reference sample,
or (b) estimating domain membership. The variance formula for this domain estimator involves
additional terms reflecting uncertainty in domain size estimation. Wu does not derive this.
The claim that MI works for "differences between group means" glosses over these additional
requirements.

**Adversarial bite:** The conditions under which MI produces valid domain estimates are
materially different from (and more demanding than) the conditions for the overall mean. In
particular, the semiparametric model (3.1) fit in the NPS must hold within each domain, and
the reference sample must have adequate representation of each domain. Neither condition is
discussed for the MI case.

---

### Finding 6: Variance estimation for doubly robust estimators is described as a
"challenging problem" even for the mean, with no solved solution for μ̂_DR2

**Page 299–302, Section 6.3:**

> "It turns out that variance estimation for the doubly robust estimator is a **challenging
> problem**. While double robustness is a desirable property for point estimation, it creates a
> dilemma for variance estimation."

For μ̂_DR2, Wu writes (page 302):

> "A doubly robust variance estimator for the commonly used μ̂_DR2 **is not available in the
> literature**. A practical solution is to use bootstrap methods."

Even for the mean, the doubly robust variance problem is unsolved analytically. Wu's
bootstrap recommendation for μ̂_DR2 is accompanied by the caveat that standard with-replacement
bootstrap "will arise complications when the probability sample S_B uses stratified multi-stage
sampling methods."

**Adversarial bite:** If variance estimation is "challenging" and analytically unsolved even
for the mean under doubly robust estimation, and if the bootstrap has known complications with
complex reference sample designs, then extending MI inference to non-mean estimands compounds
an already-difficult variance problem. The claim treats variance estimation as solved — Wu
does not.

---

### Finding 7: The A1 (MAR) assumption underlies all MI theory and is untestable —
this problem is potentially more severe for non-mean estimands

**Page 285, Section 2.1:** A1 states that Rᵢ ⊥ yᵢ | xᵢ — the NPS selection mechanism is
ignorable given observed x.

**Page 302, Section 7:** "Assumption A1 is the most crucial assumption for the validity of
the pseudo maximum likelihood estimator... It is equivalent to the missing at random (MAR)
assumption in the missing data literature. It is well understood that the MAR assumption cannot
be tested using the sample data itself."

**Page 303, Section 7.1:** "Assumption A1 leads to the conclusion that the **conditional
distribution** of y given x for units in the non-probability sample is the same as the
conditional distribution of y given x for units in the target population."

This is a stronger statement than just equality of conditional means. For MI to support
inference on a proportion (which is a marginal mean of a 0/1 variable), A1 must hold for that
variable specifically. For a difference in means between groups, A1 must hold within each
group. For each additional estimand, A1 must be assumed to hold in the relevant marginal or
conditional sense. Wu does not discuss how violations of A1 propagate differently across
estimands.

**Adversarial bite:** Selection bias from unobserved confounders (A1 violation) may be
estimand-specific. The NPS might be representative on continuous outcomes but severely biased
on attitudinal binary outcomes. The claim that MI works for proportions assumes that A1 holds
for each specific variable being analyzed — an assumption that must be assessed separately per
variable, and which Wu warns is fundamentally untestable.

---

### Finding 8: The PEL section notes proportion-specific properties — suggesting proportions
are not fully interchangeable with continuous means

**Page 295–296, Section 4.4:** Chen, Li, Rao and Wu (2022) study "simulation studies on the
performances of PEL ratio confidence intervals **on a finite population proportion**." This
is the one place in the paper where proportions are explicitly mentioned as a distinct
estimand. The fact that proportions require their own simulation study and specific PEL
confidence interval analysis implies they are not simply subsumed under "means of y."

In the PEL framework, the model-calibration constraint (4.14) is derived for the outcome
regression model ξ. Whether this constraint behaves identically for a logistic regression
model (natural for a binary y) versus a linear regression model (for continuous y) is
discussed only through the Chen et al. (2022) reference, which is listed as "accepted" at
time of writing and whose full results are not reproduced here.

---

## Passages That Support the Claim

### Support 1: The semiparametric model framework covers logistic regression

**Page 287, Section 3.1:**

> "The quasi maximum likelihood estimation theory covers **linear or nonlinear regression
> models** with the weighted least square estimators, the **logistic regression model** and
> other generalized linear models."

This confirms that the imputation model ξ can in principle be a logistic regression model,
appropriate for binary y. The formal framework is not restricted to linear regression, which
means MI for proportions using logistic regression is at least contemplated within the
semiparametric model family.

### Support 2: The research question on general inference is framed positively

**Page 289:** Wu frames the question "Is it theoretically feasible and practically useful to
create a mass-imputed dataset... for general statistical inferences?" as a research question
"currently under investigation," implying the answer is expected to be affirmative under
appropriate conditions. He identifies nearest neighbor and random regression imputation as
methods "useful for this purpose," suggesting the problem is solvable rather than fundamentally
intractable.

### Support 3: The paper's scope is means but the methods are mean-generalizable

The IPW framework (Section 4.2) is presented in terms of μ_y but the Hájek estimator form in
(4.8) is identical to a standard probability-sample weighted mean, which is routinely extended
to any smooth function of means (ratios, differences) via the delta method in classical survey
sampling. Wu does not make this extension explicit, but the building blocks are present.

### Support 4: Poststratification covers domain means implicitly

Section 5's poststratification estimator (5.1) is a weighted sum of within-subgroup means,
which covers domain estimation for discrete domains defined by the calibration variables x.
For the specific case where differences between group means are estimated within a
poststratification framework, the framework technically applies, subject to the per-stratum
sample size requirements (m_A ≥ 30).

---

## Summary Assessment

**Wu (2022) complicates — and in one passage directly undercuts — the claim, while providing
no formal support for it.**

The paper's theoretical scope is explicitly and repeatedly restricted to the population mean
μ_y. Every consistency proof, variance formula, and doubly robust property is developed for
the mean estimator and only for the mean estimator. The paper does not contain a single
theorem, simulation, or empirical result for proportions, ratios, subgroup differences, or
t-statistics under MI.

More specifically, Wu raises the question of whether MI can support "general statistical
inferences" as an **open research problem** (p. 289), not a settled result. His answer is
that it "clearly depends on the types of inferential problems" and identifies preserving the
**conditional distribution** (not just the conditional mean) as the minimum requirement. This
directly challenges the claim: standard deterministic regression imputation (Ŷ = x'β̂) used
in the canonical MI estimator preserves only the conditional mean, which Wu identifies as
insufficient for general inference without additional modifications.

The claim's reasoning — that any estimand expressible as a weighted mean of Y values can
use Ŷ — is an intuitive argument that surveycore would be extending beyond Wu's paper. The
argument may be correct for smooth functions of means (proportions, ratios, differences) via
the delta method under regularity conditions, but:

1. Wu provides no such extension.
2. Wu explicitly treats this extension as an open question at time of writing.
3. Wu flags that variance estimation is already "challenging" for means and "not available in
   the literature" for μ̂_DR2, which complicates variance estimation for derived estimands.
4. Wu identifies the conditional distribution requirement, which standard deterministic MI does
   not satisfy, as the minimum bar for general inference.
5. Binary outcomes (proportions) are flagged as requiring special treatment (fractional
   imputation).

**Verdict:** Wu (2022) provides strong theoretical grounding for MI applied to population
means. It does **not** provide grounding for the broader claim. The claim's exceptions
(quantiles, cross-outcome correlations) are well-justified by the paper's logic, but the
paper's own logic also raises questions about proportions (distribution preservation),
domain differences (subgroup model validity), and variance estimation for non-mean estimands
that the claim does not acknowledge. A well-defended version of the claim would need to cite
Kim et al. (2021) for the asymptotic MI theory, the Chen et al. (2022) PEL paper for
proportions, and would need to note that the variance calculation for ratios and differences
is not directly covered by existing NPS MI literature as of Wu's writing.

---

## Cross-Check Review

*Independently verified against the paper by a second reader. Each original note finding is
assessed in turn, followed by corrections and missed findings.*

---

### Confirmed Findings

**Finding 1 confirmed.** The notes correctly quote page 284: "Let μ_y = N⁻¹ Σᵢ₌₁ᴺ yᵢ be
the population mean which is the parameter of interest." This sentence is accurate and the
observation that the framework never broadens its formal target is correct. The Section 7
opening (p. 302) quote is also accurate: "Our discussions on estimation procedures for
non-probability survey samples are under the assumptions A1-A4 and the focuses are on the
validity and efficiency of estimators for the **finite population mean** under three
inferential frameworks." The word "focuses" (not "focus") matches the paper exactly.

**Finding 2 confirmed.** The model (3.1) on page 286 specifies E_ξ(yᵢ | xᵢ) = m(xᵢ, β)
and V_ξ(yᵢ | xᵢ) = v(xᵢ)σ², and the transportability observation is correct. The notes
accurately characterize what A1 implies via model transportability (p. 288).

**Finding 3 confirmed — with one precision correction (see Corrections below).** The
research question passage on page 289 is accurately transcribed and the surrounding
interpretation is sound. The conditional distribution requirement and the list of
alternative methods (nearest neighbor, random regression, fractional imputation, multiple
imputation) are all present in the paper exactly as quoted.

**Finding 4 confirmed.** Section 6.1 (p. 298) is indeed scoped to the MI estimator of μ_y,
and the Kim et al. (2021) bootstrap recommendation is correctly characterized. The
two-variance-component structure (one from the NPS outcome model, one from the reference
sample design) is confirmed on p. 298 and elaborated in Section 6.2 (p. 299).

**Finding 5 confirmed — with a scope clarification (see Corrections below).** The
poststratification estimator (5.1) is in the IPW section, not the MI section. The notes
correctly state that domain estimation under MI receives no guidance from the paper.

**Finding 6 confirmed.** The "challenging problem" phrase is on p. 299 (Section 6.3 opening
sentence): "It turns out that variance estimation for the doubly robust estimator is a
challenging problem." The "not available in the literature" quote for μ̂_DR2 is on p. 302:
"A doubly robust variance estimator for the commonly used μ̂_DR2 is not available in the
literature." Both are accurate. The bootstrap complication with stratified multi-stage
sampling is also confirmed on p. 302.

**Finding 7 confirmed.** The A1 / MAR equivalence and untestability are confirmed on p. 302
(Section 7.1). The stronger statement that A1 implies equality of the **conditional
distribution** (not just conditional means) is confirmed on p. 303: "Assumption A1 leads to
the conclusion that the conditional distribution of y given x for units in the non-probability
sample is the same as the conditional distribution of y given x for units in the target
population."

**Finding 8 confirmed.** Section 4.4 (pp. 295–296) does discuss PEL ratio confidence
intervals on a finite population proportion via Chen, Li, Rao and Wu (2022), and the paper
confirms this is treated as a distinct result.

**Support 1 confirmed.** The quote on p. 287 ("The quasi maximum likelihood estimation
theory covers linear or nonlinear regression models with the weighted least square
estimators, the logistic regression model and other generalized linear models") is accurate.

**Support 2 confirmed.** The characterization of the research question as framed
"positively" is a fair reading of the passage tone.

**Support 3 confirmed.** The IPW Hájek estimator (4.8) has the standard form; the notes'
point about the delta method building blocks being present is reasonable.

**Support 4 confirmed.** Section 5's poststratification estimator (5.1) is a weighted sum
of within-subgroup means. The m_A ≥ 30 recommendation is on p. 297.

---

### Corrections

**Correction 1: Minor misattribution of the "challenging problem" sentence.**
The notes attribute the doubly robust variance difficulty passage to "Page 299–302,
Section 6.3." This is slightly misleading: the opening sentence "It turns out that variance
estimation for the doubly robust estimator is a challenging problem" appears on p. 299
(which is the first page of Section 6.3). The "not available in the literature" sentence for
μ̂_DR2 appears on p. 302. The notes present both as if they were in the same contiguous
block, which is accurate in substance — they are in the same section — but a precise
citation would distinguish p. 299 from p. 302. No error in meaning, but imprecision in
page attribution.

**Correction 2: The mass-imputed dataset notation in the research question is
misquoted.**
The notes reproduce the research question as asking about the dataset
"{(yᵢ*, xᵢ, dᵢᴮ), i ∈ Sᴮ}". The paper (p. 289) uses the notation
{(yᵢ*, xᵢ, dᵢᴮ), i ∈ Sᴮ} where the asterisk on y is present — this matches. However,
the notes describe the subscript "MI" as indicating "Mass Imputation (not Multiple
Imputation)" correctly citing p. 288, but the research question passage the notes reproduce
is verbatim accurate. No error here on closer examination — the notation is faithfully
reproduced. This is a false alarm.

**Correction 3: The notes slightly overstate what the bootstrap caveat says about μ̂_DR2.**
The notes write: "Wu's bootstrap recommendation for μ̂_DR2 is accompanied by the caveat
that standard with-replacement bootstrap 'will arise complications when the probability
sample S_B uses stratified multi-stage sampling methods.'" The paper (p. 302) reads: "Chen
et al. (2022) demonstrated that standard with-replacement bootstrap procedures applied
separately to S_A and S_B provide doubly robust confidence intervals using the pseudo
empirical likelihood approach to non-probability survey samples when the reference sample
is selected by single stage unequal probability sampling designs. Complications will arise
when the probability sample S_B uses stratified multi-stage sampling methods." The context
is specifically the PEL-based bootstrap from Chen et al. (2022), not Wu's own bootstrap
recommendation for general DR variance estimation. The notes conflate Wu's general
recommendation with the specific Chen et al. (2022) result. The substantive point — that
bootstrap has complications with complex reference designs — is correct, but the
attribution is slightly off.

**Correction 4: Finding 5 mischaracterizes where the m_A ≥ 30 guidance applies.**
The notes state the paper "recommends m_A ≥ 30 per post-stratum, page 297." The paper
(p. 297) states "A practical guidance for the choice of K is to ensure that m_A ≥ 30 for
the poststratified samples." This is guidance on minimum stratum size for the
poststratified IPW estimator — specifically tied to the choice of K strata. The notes
correctly cite the page but could more precisely note this is guidance for the K-strata
version of the IPW estimator (Section 5), not a general per-stratum requirement for MI.
This is a framing imprecision, not a factual error.

**Correction 5: The paper was presented at the SSC Annual Meeting, not just as a general
address.**
The notes' summary says the paper "was delivered as the 2021 SSC Special Presidential
Invited Address." The Acknowledgements (p. 307) confirm: "An early version of the paper
was presented at the SSC 2021 Annual Meeting as the Special Presidential Invited Address
by the Survey Methods Section of the SSC." The notes are accurate; noting for completeness
that it was specifically by the Survey Methods Section of the SSC.

---

### Missed Findings

**Missed Finding 1: Section 8 (Concluding Remarks) contains an explicit statement
restricting the paper's framework to means.**
Page 302, Section 7 opening (accurately quoted in Finding 1) is the notes' strongest
citation. However, the notes miss a functionally identical statement in Section 8 (p. 306):
"Standard statistical concepts and inferential procedures, however, can be built into a
suitable framework for valid and efficient inference with non-probability survey samples."
This is a forward-looking assertion, not a claim that the paper itself delivers such a
framework for general estimands. The concluding remarks reinforce rather than expand the
scope. This supports the notes' argument but the notes do not cite it.

**Missed Finding 2: The paper explicitly identifies two reference probability sample
selection criteria that favor MI over IPW (p. 305).**
Page 305 states: "It was shown by Chen et al. (2020) that two reference probability survey
samples with the same set of common auxiliary variables tend to produce very similar IPW
estimators but the one with a larger sample size leads to better mass imputation
estimators." This is a practical comparative advantage for MI not discussed in the notes,
and it is relevant context for understanding when MI is the preferred approach — but since
the notes focus on estimand scope rather than estimator choice, this omission does not
undermine any claim.

**Missed Finding 3: The paper raises A2 (positivity) as "highly problematic" in a way
that compounds the notes' A1 argument.**
Section 7.2 (pp. 303–304) discusses assumption A2 (all population units have non-zero
propensity scores) and describes the "deterministic undercoverage" scenario where, for
example, 20% of the population has zero probability of appearing in the NPS due to lack
of internet access. Wu calls this scenario one for which "there is no simple fix to the
inferential procedures developed under A2." The notes focus on A1 untestability (Finding 7)
but do not discuss A2 violations. For non-mean estimands, A2 violations are equally
relevant: if a demographic group is entirely absent from the NPS, no imputation model will
produce valid estimates for that group's characteristics. This is an additional constraint
on the claim that MI supports subgroup differences and t-tests. The notes' Finding 5
(domain estimation) touches the edges of this but does not invoke A2.

**Missed Finding 4: Section 6.3 contains a positive result for doubly robust variance
estimation for μ̂_DR1 that the notes do not acknowledge.**
Pages 300–302 show that, via the Kim and Haziza (2014) technique, a doubly robust variance
estimator *can* be constructed for μ̂_DR1 (though Wu notes it "has various issues for
practical applications"). The notes accurately report that the analogous estimator for
μ̂_DR2 is "not available in the literature," but the notes characterize the DR variance
problem as uniformly unsolved. This is an overstatement: μ̂_DR1 has a workable (if
impractical) analytical variance estimator. The correct characterization is that DR
variance estimation is solved for μ̂_DR1 in principle, and unsolved for μ̂_DR2 analytically.
For the notes' adversarial purpose this distinction is secondary, but it is a mild
overstatement.

**Missed Finding 5: The paper's discussion of the "reverse sample matching" estimator
(p. 288) implies that directly using y_i from S_A — rather than imputing — is also
under active investigation.**
Wu notes the "reverse matched estimator" μ̂_yA on p. 288 and states: "Theoretical
properties of the reverse matched estimator μ̂_yA using the nearest neighbor j ∈ S_B to
match d_i* with d_j^B have not been formally investigated in the existing literature." This
suggests the MI framework's theoretical foundations are still being actively developed even
for the mean estimator at time of writing. The notes do not cite this passage, which
provides additional evidence that the field is unsettled even for means — strengthening the
notes' argument about non-mean estimands.

**Missed Finding 6: The paper explicitly states that "the dataset most likely contains
multiple study variables" (p. 284) but then restricts analysis to a single y.**
The exact sentence is: "The discussions focus on a single y but the dataset most likely
contains multiple study variables." This sentence is on p. 284 and directly acknowledges
the multi-variable reality while simultaneously flagging it as outside the paper's scope.
The notes do not cite this sentence. It is directly relevant to the claim being investigated
because MI in practice is applied variable-by-variable across a survey battery, and Wu's
acknowledgment that he is restricting to a single y is an explicit marker that multi-variable
inference (including ratios of two separately-imputed variables and correlations) is not
within his theoretical purview.

---

### Overall Assessment of the Notes

The notes are accurate and thorough. Every direct quote verified against the paper is
correct. The interpretations are fair and do not overreach what the paper says. The
adversarial findings are well-supported by the text.

The three areas where the notes could be strengthened:

1. The "not available in the literature" statement for μ̂_DR2 variance should be
   distinguished from the partial solution available for μ̂_DR1 (Missed Finding 4).
2. The A2 (positivity) violation problem for subgroup estimation is a second line of
   argument supporting Finding 5 that the notes do not exploit (Missed Finding 3).
3. The explicit "discussions focus on a single y" acknowledgment on p. 284 is a clean
   one-sentence citation that directly supports the paper's scope restriction and is
   more economical than the longer Finding 1 argument (Missed Finding 6).

The notes' overall verdict — that Wu (2022) does not provide theoretical grounding for the
broader claim and treats general MI inference as an open research question — is fully
supported by the paper text.
