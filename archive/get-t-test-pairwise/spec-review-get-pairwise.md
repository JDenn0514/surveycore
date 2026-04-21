# Spec Review: get-pairwise

## Spec Review: get-pairwise — Pass 1 (2026-03-24)

### New Issues

#### Section: II. Architecture (File Organization)

**Issue 1: `.stars_pval()` lives in `analysis-diffs-helpers.R` but will be used by 2+ files**
Severity: REQUIRED
Violates `code-style.md §4`: "Helper used in 2+ source files → `R/07-utils.R`"

The spec lists `.stars_pval()` under `analysis-diffs-helpers.R` with the note
"already exists, shared." But `code-style.md §4` requires that helpers used by
more than one source file be promoted to a shared location (`analysis-helpers.R`
for analysis functions). Since `get_pairwise()` in `analysis-pairwise.R` also
calls `.stars_pval()`, it must be moved.

Options:
- **[A]** Promote `.stars_pval()` to `analysis-helpers.R` as a prerequisite
  step in the implementation plan — Effort: low, Risk: low, Impact: correct
  helper placement, Maintenance: none
- **[B] Do nothing** — Implementation imports across file boundaries in
  violation of the established pattern

**Recommendation: A** — One-line move; aligns with the existing pattern for
shared analysis helpers like `.extract_var_meta()`.

---

#### Section: III.8 Clean Path

**Issue 2: Section title and description understate the clean path's scope**
Severity: REQUIRED
Violates `engineering-preferences.md §5` (explicit over clever)

Section 3.8 is titled "Estimation: Clean Path (Bivariate + Gaussian + No
Group)" and the first sentence says "For the simple case." But the routing
logic in Section 7.2 routes **non-Gaussian + `scale = "link"` + no covariates
+ no group** through the clean path as well:

```r
use_marginaleffects <- has_covariates ||
  has_group ||
  (family_name != "gaussian" && scale == "ame")
# scale = "link" + non-gaussian → FALSE → clean path
```

For a logistic model on the link scale with no covariates/groups, the
coefficients ARE the log-odds pairwise contrasts. The clean path is
mathematically correct. But the section title misleads the implementer into
thinking the clean path is Gaussian-only.

Options:
- **[A]** Rename section to "Clean Path (No Covariates + No Group +
  (Gaussian OR Link Scale))" and add a paragraph explaining that for
  non-Gaussian link-scale models, coefficients are link-scale contrasts and
  means are suppressed per Section 3.2 — Effort: low, Risk: low,
  Impact: correct documentation, Maintenance: none
- **[B] Do nothing** — Implementer may add an unnecessary Gaussian guard to
  the clean path, breaking the link-scale route

**Recommendation: A** — Clarifies intent with no code change needed.

---

#### Section: VII. Execution Flow

**Issue 3: Step 6a (empty treatment cell check) runs before NA removal (Step 8)**
Severity: BLOCKING
Violates `engineering-preferences.md §5` (explicit over clever)

Step 6a says: "Check for empty treatment cells: if any treatment level has zero
in-domain observations **after NA removal**, raise
`surveycore_error_empty_treatment_cell`."

But NA removal happens inside `survey_glm()` at Step 8 (via `na.action`).
Step 6a is positioned at Step 6, before the model fit. The spec is internally
inconsistent about when this check runs, and the implementer cannot resolve
this ambiguity without a design decision.

Three approaches:
1. Manually remove NAs from `x`, `treats`, and `group` columns before Step 6a,
   then pass clean data to `survey_glm()` with `na.action = na.pass`
2. Move Step 6a after Step 8 — but by then, `survey_glm()` has already errored
   on the singular model matrix, defeating the purpose of the check
3. Check cell counts on pre-NA-removal data at Step 6a (catches the "level has
   literally zero rows" case but misses "level has rows but all have NA in x")

This also affects `n_a`/`n_b` computation (Issue 7).

Options:
- **[A]** Add explicit NA removal step before Step 6a: compute
  `working_data <- design@data[complete.cases(x, treats, group), ]` (or
  `design@data` filtered for domain + non-NA). Use `working_data` for Step 6a
  cell counts AND for `n_a`/`n_b` computation. Pass `na.action = na.omit` to
  `survey_glm()` as before (redundant but safe) — Effort: low, Risk: low,
  Impact: correct cell validation, Maintenance: low
- **[B]** Move Step 6a to after Step 8, catching the singularity error from
  `survey_glm()` and re-raising it as `surveycore_error_empty_treatment_cell`
  — Effort: medium, Risk: medium (catching and re-throwing errors is fragile),
  Impact: clearer error message, Maintenance: medium
- **[C] Do nothing** — Implementer guesses; likely picks approach 3 (pre-NA
  check) which misses the "all observations of level B have NA in x" case

**Recommendation: A** — Cleanest approach; establishes a `working_data`
variable that serves both cell validation and n-computation.

---

#### Section: IV. `.meta` Contract

**Issue 4: `design_type` values incomplete**
Severity: REQUIRED
Violates `engineering-preferences.md §5` (explicit over clever)

The `.meta` contract lists `design_type` values as `"taylor"`, `"replicate"`,
`"twophase"`, or `"calibrated"`. But `.build_meta()` produces 5 possible
values: `"taylor"`, `"replicate"`, `"twophase"`, `"srs"`, `"calibrated"`.
The `"srs"` value is emitted when the design is a `survey_taylor` with no
`ids`/`strata` (simple random sample).

Options:
- **[A]** Add `"srs"` to the design_type values list — Effort: trivial,
  Risk: none, Impact: spec matches reality, Maintenance: none
- **[B] Do nothing** — Spec is incomplete; implementer discovers the mismatch
  during testing

**Recommendation: A** — One word added to the table.

---

**Issue 5: `estimate_scale` has no value for marginaleffects link-scale path**
Severity: REQUIRED
Violates contract completeness (Lens 3)

The `.meta` contract specifies `estimate_scale` with two values:
`"coefficient"` (clean path) and `"ame"` (marginaleffects path). But when
`scale = "link"` and the marginaleffects path is active (e.g., non-Gaussian +
covariates), the estimates are on the link scale — neither "coefficient" nor
"ame" is accurate.

`"ame"` specifically means "average marginal effect on the response scale."
Labeling a link-scale contrast as `"ame"` is methodologically misleading.

Options:
- **[A]** Add a third value `"link"` for the marginaleffects link-scale path.
  Mapping: clean path → `"coefficient"`, marginaleffects + `scale="ame"` →
  `"ame"`, marginaleffects + `scale="link"` → `"link"` — Effort: low,
  Risk: low, Impact: correct metadata, Maintenance: none
- **[B]** Rename `"coefficient"` to `"link"` and use it for both clean-path
  link-scale and marginaleffects link-scale — confusing since clean-path
  Gaussian coefficients are not typically called "link scale"
- **[C] Do nothing** — `"ame"` used for link-scale contrasts; misleading

**Recommendation: A** — Three distinct values for three distinct estimation
modes. Note: this same gap exists in `get_diffs()`.

---

#### Section: III.9.4 Assembly (Marginaleffects Path)

**Issue 6: Contrast column parsing is fragile for level names containing " - "**
Severity: REQUIRED
Violates `engineering-preferences.md §4` (handle more edge cases)

Section 3.9.4 Step 1 says to parse the `contrast` column from
`avg_comparisons()` (format `"B - A"` → `level_a = "A"`, `level_b = "B"`).
Splitting on `" - "` will break when treatment level names contain the
substring `" - "` (e.g., `"Pre - Test"`, `"Ages 18 - 24"`).

Real survey data frequently has level names with hyphens and dashes.

Options:
- **[A]** Specify a robust parsing strategy: join the `avg_comparisons()`
  output with the known level names from `.build_pair_labels()` rather than
  parsing the contrast string. Match rows by the `term` column and the
  known pair combinations — Effort: medium, Risk: low, Impact: handles
  all level names, Maintenance: none
- **[B]** Document that level names must not contain `" - "` and add a
  validation check — Effort: low, Risk: medium (restricts valid data),
  Impact: breaks on real data, Maintenance: ongoing user friction
- **[C] Do nothing** — Silent wrong results for affected level names

**Recommendation: A** — The robust approach avoids both runtime errors and
silent incorrect results. `marginaleffects::avg_comparisons()` returns the
original factor levels in its output; use those rather than string parsing.

---

#### Section: V.2 Output Columns / VII. Execution Flow

**Issue 7: `n_a` / `n_b` computation details missing**
Severity: REQUIRED
Violates contract completeness (Lens 3)

Section 5.2 defines `n_a` and `n_b` as "Unweighted in-domain count for
level_a (within group if applicable)" but does not specify:
1. Which data is used — original `design@data` or post-NA-removal data?
2. How domain filtering is applied — `..surveycore_domain..` column?
3. How group membership is intersected with treatment level membership

This ties directly to Issue 3: if a `working_data` variable is established
before the model fit, `n_a`/`n_b` should be computed from it.

Options:
- **[A]** Add a subsection specifying: `n_a` = `nrow(working_data[treats ==
  level_a & group == group_value, ])` where `working_data` is domain-filtered +
  NA-removed. Same for `n_b`. `n_a_weighted` = `sum(weights)` over the same
  subset — Effort: low, Risk: low, Impact: unambiguous contract,
  Maintenance: none
- **[B] Do nothing** — Implementer infers from `get_diffs()` pattern

**Recommendation: A** — The spec should be self-contained for n computation
since this interacts with Issue 3 (NA removal timing).

---

#### Section: IX. Testing Requirements

**Issue 8: Missing test for non-Gaussian + `scale = "link"` on the clean path**
Severity: REQUIRED
Violates `testing-standards.md` (every estimation path must be tested)

Per the routing logic (Section 7.2), `scale = "link"` + non-Gaussian + no
covariates + no group routes through the clean path. This produces link-scale
contrasts (e.g., log-odds differences for logistic models). No test in
Section 9.1 explicitly covers this path.

The edge case test "`scale = "link"` + non-gaussian" only verifies that
`mean_a` / `mean_b` are suppressed, not that the clean-path estimates are
correct link-scale contrasts.

Options:
- **[A]** Add a test: "Non-gaussian + `scale = 'link'` + clean path" that
  (a) verifies the clean path is used (`meta(result)$estimate_method ==
  "contrast_matrix"`), (b) verifies estimates match the model coefficients'
  pairwise differences, (c) verifies means are suppressed — Effort: low,
  Risk: low, Impact: closes coverage gap, Maintenance: none
- **[B] Do nothing** — Clean path for non-Gaussian link scale is untested

**Recommendation: A** — This is a real estimation path, not a hypothetical
edge case.

---

**Issue 9: Missing combined test for non-Gaussian + group + covariates**
Severity: REQUIRED
Violates `testing-standards.md` (every estimation path combination tested)

The test categories list "With covariates and group" and "Non-gaussian family
(quasibinomial)" as separate tests. No test covers the combination:
non-Gaussian + group + covariates. This is the most complex marginaleffects
call (`avg_comparisons()` with `by = group_names`, `type = "response"`, on a
non-linear model with covariates). It exercises the delta method, the survey
vcov, group-by-group contrast extraction, and p-value adjustment within each
group simultaneously.

Options:
- **[A]** Add "Non-gaussian + group + covariates" to the happy path tests —
  Effort: low, Risk: low, Impact: covers the most complex path,
  Maintenance: none
- **[B] Do nothing** — Assumes separate tests are sufficient; interaction
  bugs between non-Gaussian + groups may slip through

**Recommendation: A** — One additional test block; high value for coverage.

---

#### Section: II. Architecture / III. Function Specification

**Issue 10: Shared validation logic between `get_diffs()` and `get_pairwise()` will be duplicated**
Severity: SUGGESTION
Per `engineering-preferences.md §1` (DRY)

Steps 1–4a of `get_pairwise()` (validate shared args, check design class,
resolve x/treats/group, validate x is numeric, validate treats has >= 2 levels,
validate covariates/pval_adj) are nearly identical to `get_diffs()`. The spec
says "Reuse from `get_diffs()`" for error classes, implying the same validation
code, but doesn't specify a shared validation helper.

When both functions are implemented, the validation logic will be duplicated
across `analysis-diffs.R` and `analysis-pairwise.R`.

Options:
- **[A]** Extract a `.validate_comparison_args()` helper in
  `analysis-helpers.R` that validates: x is single numeric column, treats is
  single column with >= 2 levels, covariates is character or NULL, pval_adj is
  valid. Both `get_diffs()` and `get_pairwise()` call it — Effort: medium,
  Risk: low, Impact: DRY, Maintenance: reduces future divergence
- **[B]** Note the duplication and defer extraction to a follow-up refactor
  PR — Effort: low now / medium later, Risk: low, Impact: deferred DRY,
  Maintenance: temporary duplication
- **[C] Do nothing** — Duplication accepted

**Recommendation: A** — The shared helper has two call sites on day one; this
is not premature abstraction.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 8 |
| SUGGESTION | 1 |

**Total issues:** 10

**Overall assessment:** The spec is well-structured and correctly models the
relationship to `get_diffs()`. The single blocking issue (Step 6a timing vs NA
removal) requires a small design decision about when NA rows are excluded. The
required issues are mostly documentation gaps (clean path scope, `.meta`
values, n-computation details) and test coverage holes (non-Gaussian link-scale
clean path, combined non-Gaussian + group + covariates). No architectural
redesign is needed — resolution is straightforward for all issues.
