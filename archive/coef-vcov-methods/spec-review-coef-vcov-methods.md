## Spec Review: coef-vcov-methods — Pass 1 (2026-06-22)

Six lenses run in parallel. Issues deduplicated across lenses; cross-lens references noted.

---

### New Issues

#### BLOCKING

---

**Issue 1: `survey_freqs` off-diagonal `vcov()` is not implementable from stored data**
Severity: BLOCKING
Section: §I (support matrix), §III.6 (`vcov()` — survey_freqs bullet)
Lens 5 (Engineering Level)

The spec claims `vcov()` for `survey_freqs` "computes the full cross-level within-group covariance matrix using joint influence-function estimation" by accumulating "a `p × R` influence matrix across all levels per group block." This is architecturally impossible with the current data model.

The stored result tibble contains only scalar `pct` and `se` values per cell. The per-row linearized influence functions (`u_i = num_i - p * denom_i`) computed inside `.taylor_freq_cell()` are discarded and not stored. `Cov(p_j, p_k)` for levels j and k within a group requires the joint influence vectors, which require either the original design object or the stored per-row influence vectors. Neither is available at `vcov()` call time — the result is a plain tibble with a metadata attribute and no reference to the design.

A builder who attempts to implement the spec as written will either try to call the design's variance estimator on data they do not have, or silently produce structural zeros and label them as joint estimates.

Options:
- **[A]** Acknowledge the limitation. Change the `survey_freqs` spec to: diagonal = `se^2`, off-diagonal = `NA_real_`, emit `surveycore_warning_vcov_incomplete` (matching `survey_corr` behavior). Update §I support matrix note, §III.6 step 3, and the error table. — Effort: low (spec edit only), Risk: low, Impact: honest and implementable; users who need the true joint covariance must use `survey::svymean(cbind(...))` on the original design.
- **[B]** Store per-row influence vectors in `.survey_result` attribute at `get_freqs()` time. Requires specifying storage format and adds memory proportional to `n × L × G`. — Effort: high (new architecture), Risk: high.
- **[C]** Do nothing — builder will hit this wall during implementation.

**Recommendation: A.** This is the only implementable option without a larger architectural change that needs its own spec.

---

**Issue 2: `get_diffs()` `group_cols` source field does not exist**
Severity: BLOCKING
Section: §VI (`get_diffs()` — requires a different approach)
Lenses 3 + 6 (confirmed by Lens 6 reading the actual source)

The spec says: "`group_cols` is extracted from `meta(result)$group_names`."

The actual `get_diffs()` stores group metadata under `meta_args$group` (via `.build_group_meta(design, group_names)`), not `meta_args$group_names`. `meta(result)$group_names` does not exist and returns `NULL` at runtime. A builder following this instruction will extract `NULL` for `group_cols` in all cases, causing `coef()` to produce ungrouped names for all `survey_diffs` results — even grouped ones — with no error.

Options:
- **[A]** Correct the spec: "`group_cols` is `names(attr(result, '.meta')$group)` — the group variable names are the keys of the `$group` named list." — Effort: minimal (spec edit), Risk: none.
- **[B]** Add a `group_names` field explicitly to `get_diffs()` meta_args alongside the existing `group` key. — Effort: low (code + spec), but changes the metadata schema.
- **[C]** Leave as-is — builder will discover the bug during testing.

**Recommendation: A.** Fix the field name before the builder begins.

---

**Issue 3: SCR-3, SCR-W1, SCR-W2 absent from `plans/error-messages.md`; write surface incomplete**
Severity: BLOCKING
Section: §V (error table), §X (write surface), `plans/error-messages.md`
Lenses 3 + 5

The spec's §V states "Must be added to `plans/error-messages.md` before implementation." However, inspecting `error-messages.md`, only SCR-1 is present. Three new rows are missing:
- `surveycore_error_invalid_df` (SCR-3)
- `surveycore_warning_vcov_incomplete` (SCR-W1)
- `surveycore_warning_vcov_cross_group` (SCR-W2)

The §X write surface also lists only "Add row SCR-1" — it does not mention SCR-3, SCR-W1, or SCR-W2. The §I scope table says "Two new error classes: SCR-1, SCR-2" — but there are four new rows (SCR-2 reuses an existing class; SCR-1, SCR-3, SCR-W1, SCR-W2 are new). A builder following the scope table or write surface would add only SCR-1 and leave three error classes unregistered.

Options:
- **[A]** Add SCR-3, SCR-W1, SCR-W2 to `error-messages.md` now; update §I scope table to "Four new error entries: SCR-1, SCR-3, SCR-W1, SCR-W2 (SCR-2 reuses existing class)"; update §X write surface to list all four new rows. — Effort: low, Risk: none.
- **[B]** Leave the omission and let the builder add them during implementation. — Risk: quality gate §VIII is unachievable without them.
- **[C]** Do nothing.

**Recommendation: A.** The error registry is a pre-implementation prerequisite per §V. Builder cannot write snapshot tests without the registered messages.

---

**Issue 4: `confint()` column label formula vulnerable to floating-point artifacts**
Severity: BLOCKING
Section: §III.8
Lens 3 (Contract Completeness)

The spec states: "Exact percentage labels are `paste0(100 * (1 - level) / 2, " %")` and `paste0(100 * (1 - (1-level)/2), " %")`."

Bare `paste0()` on a floating-point double can produce labels like `"2.5000000000001 %"` for edge-case levels due to IEEE 754 arithmetic. `stats::confint.default()` uses `format(100 * c(a, 1-a))` which strips trailing zeros and applies R's default numeric formatting to suppress float artifacts. The spec's formula does not mention `format()`.

For standard levels (0.80, 0.90, 0.95, 0.99) the arithmetic is clean and `paste0()` produces the correct string. For non-standard levels or levels computed from arithmetic (e.g., `level = 1 - 0.05`), floating-point residuals can produce ugly strings that will fail snapshot tests.

Options:
- **[A]** Specify: "Use `format(100 * (1-level)/2, trim=TRUE)` and `format(100 * (1-(1-level)/2), trim=TRUE)` to match `stats::confint.default()` behavior exactly." — Effort: minimal, Risk: none.
- **[B]** Keep bare `paste0()` and add a note that only standard levels are guaranteed to produce clean output.
- **[C]** Do nothing.

**Recommendation: A.** One-word change to the formula spec (`format()` wrapper). Prevents snapshot test failures on non-standard levels.

---

**Issue 5: `df = NA_real_` in attribute bypasses the guard and silently produces `NA` CI bounds**
Severity: BLOCKING
Section: §III.8 (`df` validation)
Lens 4 (Edge Cases)

The `df` validation guard: "check `is.finite(df[i]) && df[i] <= 0`. If any element fails, throw `surveycore_error_invalid_df`."

When `df[i]` is `NA_real_`, `is.finite(NA_real_)` returns `FALSE`, so the guard does NOT fire. But `qt(1 - (1-level)/2, df = NA_real_)` returns `NA_real_`, making both CI bounds `NA` silently. This is a legitimate value that could appear if `cell_df` threading (§VI) produces `NA` for a degenerate calibrated domain.

The spec defines this guard to catch bad df values — `NA_real_` is also a bad df value, and the guard should catch it.

Options:
- **[A]** Extend the guard: `if (is.na(df[i]) || (is.finite(df[i]) && df[i] <= 0))` — throw `surveycore_error_invalid_df` for `NA` as well. Add `df = NA_real_` to the §VII edge-case table. — Effort: minimal, Risk: none.
- **[B]** Treat `NA_real_` df as producing `NA_real_` CI bounds silently and document in §VII.
- **[C]** Do nothing.

**Recommendation: A.** The guard exists to prevent silent bad output. `NA_real_` df qualifies.

---

**Issue 6: No numerical oracle for `coef()` on five result classes**
Severity: BLOCKING
Section: §III.5, §VI, `plans/test-spec-coef-vcov-methods.md` §12–13
Lens 2 (Test Completeness)

Category 2 (Numerical Oracle) is REQUIRED and cannot be marked N/A for any function with numeric output. The test spec provides oracle comparisons only for `survey_totals` (§12, vs. `survey::svytotal`) and `survey_freqs` (§13). Five supported classes have no oracle:
- `survey_ratios` — vs. `survey::svyratio`
- `survey_quantiles` — vs. `survey::svyquantile`; the spec additionally notes `confint()` should "exactly reproduce Woodruff CI bounds algebraically," which is a verifiable identity
- `survey_covariance` — vs. `survey::svyvar`
- `survey_diffs` — vs. `survey::svycontrast` or direct contrast
- `survey_corr` (long format) — vs. `survey::svycor`

Options:
- **[A]** Add one oracle `test_that()` block per missing class using NHANES or `acs_pums_wy`. — Effort: medium (5 test blocks), Risk: low.
- **[B]** Add oracles for the three most architecturally distinct (ratios, quantiles, diffs) and mark corr/covariance as derivative. — Effort: low-medium, Risk: medium (leaves two classes without numerical validation).
- **[C]** Do nothing — BLOCKING: Category 2 is not waivable.

**Recommendation: A.** For `survey_quantiles` specifically, include a sub-assertion that `confint(result)` exactly equals stored `ci_low`/`ci_high` at tolerance `1e-10`.

---

**Issue 7: Eight SCR-1 error sub-paths untested in test spec**
Severity: BLOCKING
Section: §V (SCR-1), §III.5–III.8, `plans/test-spec-coef-vcov-methods.md` §7, §11
Lens 2 (Test Completeness)

SCR-1 (`surveycore_error_result_method_unsupported`) is thrown by all four methods under two conditions: unsupported class and missing attribute. The test spec covers: `coef()` on `survey_t_test` (§7.1), `coef()` on `survey_pairwise` (§7.2), `vcov()` on `survey_t_test` (§7.3), `coef()` with absent attribute (§7.5). Eight sub-paths are entirely absent:
- `SE()` on `survey_t_test` (§11 lists a snapshot but no §7 block exists)
- `confint()` on `survey_t_test` (§11 lists a snapshot but no §7 block exists)
- `vcov()` on `survey_pairwise` (not in §7 or §11)
- `SE()` on `survey_pairwise` (not in §7 or §11)
- `confint()` on `survey_pairwise` (not in §7 or §11)
- `vcov()` with absent attribute (not in §7)
- `SE()` with absent attribute (not in §7)
- `confint()` with absent attribute (not in §7)

At 98% line coverage required, branches in `SE.survey_result()` and `confint.survey_result()` cannot be covered without triggering these paths.

Options:
- **[A]** Add 8 test blocks (one per path), each with dual pattern (class= + snapshot). — Effort: medium (8 blocks), Risk: none.
- **[B]** Add the 5 missing unsupported-class tests and 2 of the 3 missing attribute-stripped tests (SE and confint both delegate to vcov, so the branches are similar). — Effort: low-medium, Risk: low.
- **[C]** Do nothing — BLOCKING: 98% line coverage is not achievable without these branches.

**Recommendation: A.** All 8 paths correspond to distinct code branches in 3 methods.

---

**Issue 8: No test for SCR-3 (`confint()` with invalid `df`)**
Severity: BLOCKING
Section: §V (SCR-3), §III.8, §VIII quality gate, `plans/test-spec-coef-vcov-methods.md`
Lens 2 (Test Completeness)

The spec defines `surveycore_error_invalid_df` (SCR-3) and §VIII explicitly lists it as a quality gate: "`confint()` with `df ≤ 0` stored in attribute throws `surveycore_error_invalid_df`." No test exists anywhere in the test spec — not in §7, §8, or §11. The snapshot list in §11 has no entry for this error class.

Options:
- **[A]** Add a test block: manually set `attr(result, ".survey_result")$df <- -1L` and call `confint(result)`. Assert class= and snapshot. Add to §11 snapshot list. — Effort: minimal (one block), Risk: none.
- **[B]** Do nothing — BLOCKING: quality gate in §VIII names this explicitly.

**Recommendation: A.** This is a 5-line test block.

---

#### REQUIRED

---

**Issue 9: `.survey_result` absent-guard prose restated independently in III.5, III.6, and VII**
Severity: REQUIRED
Section: §III.5, §III.6, §III.7, §III.8, §VII
Lens 1 (DRY)

The same absent-attribute guard is restated independently in §III.5 (`coef`) and §III.6 (`vcov`), referenced-but-not-defined in §III.7 and §III.8, and re-stated again in the §VII edge-case table. If a future change adds a third condition to the guard (e.g., `is.null(estimate_cols)`), all locations need simultaneous updates with no mechanical enforcement.

Options:
- **[A]** Add §III.0 "Shared preconditions" sub-section. Each method contract replaces its local guard prose with "See §III.0 preconditions." §VII row adds "(canonical: §III.0)." — Effort: low, Risk: none.
- **[B]** Keep §III.5 as canonical; add cross-references from §III.6 to §III.5 and from §VII to §III.5. — Effort: minimal.
- **[C]** Do nothing.

**Recommendation: A** (combined with Issue 10).

---

**Issue 10: Unsupported-classes check (`survey_t_test`, `survey_pairwise`) restated in III.5, III.6, and VII**
Severity: REQUIRED
Section: §III.5, §III.6, §VII
Lens 1 (DRY)

Same issue as Issue 9 but for the `inherits(object, c("survey_t_test", "survey_pairwise"))` check. The class list appears in §III.5 and is implied by §III.6 and §VII without cross-reference. If a third unsupported class is added, a builder reading only §VII would not know to update the `inherits()` call.

Options:
- **[A]** Fold into the §III.0 "Shared preconditions" proposed in Issue 9. One combined entry covers both checks.
- **[B]** Keep §III.5 canonical; cross-reference §VII to §III.5.
- **[C]** Do nothing.

**Recommendation: A** (combined with Issue 9).

---

**Issue 11: Scope table and write surface claim 2 new error entries; 5 are defined**
Severity: REQUIRED
Section: §I (scope table), §X (write surface)
Lens 3 (Contract Completeness)

§I says "Two new error classes: SCR-1, SCR-2 (see §VI)." §X lists only "Add row SCR-1." The actual §V defines five entries: SCR-1, SCR-2 (reused), SCR-3, SCR-W1, SCR-W2. The net-new rows are four: SCR-1, SCR-3, SCR-W1, SCR-W2. A builder following §I or §X would add only SCR-1 and omit SCR-3/SCR-W1/SCR-W2.

Options:
- **[A]** Update §I: "Four new error entries: SCR-1, SCR-3, SCR-W1, SCR-W2 (SCR-2 reuses `surveycore_error_invalid_conf_level`)." Update §X write surface to list all four rows.
- **[B]** Do nothing (covered by Issue 3's pre-implementation fix to error-messages.md, but §I/§X remain internally inconsistent).

**Recommendation: A** — fix the internal inconsistency in the spec regardless of Issue 3.

---

**Issue 12: S7 membership test uses `inherits()` string form, not `S7::S7_inherits()`**
Severity: REQUIRED
Section: §III.5, §III.6
Lens 3 (Contract Completeness)

§III.5 specifies: "Detected by checking `inherits(object, c('survey_t_test', 'survey_pairwise'))`." The project's `code-style.md §2` and `engineering-preferences.md §5` prohibit `inherits()` with string class names for S7 objects — the string form silently fails if a class is renamed. The canonical form is `S7::S7_inherits(object, ClassName)` with the class object.

Options:
- **[A]** Update §III.5 and §III.6 to specify: `S7::S7_inherits(object, survey_t_test) || S7::S7_inherits(object, survey_pairwise)`. Note that both class objects must be in scope. — Effort: minimal.
- **[B]** Do nothing — violates the codebase's class-membership standard.

**Recommendation: A.**

---

**Issue 13: `$var` slot — remove dead code or explicitly state always-present**
Severity: REQUIRED
Section: §II (attribute layout), §III.1 (`.build_survey_result_attr()`), §III.6
Lenses 3 + 5

The `$var` slot is always `NULL`, is explicitly stated to never be written ("no lazy caching"), and cannot be written in a way visible to the caller (copy-on-modify). It has no current purpose and creates two failure modes: (a) a builder inspecting the attribute structure may omit the key (since it's always `NULL`), breaking any code doing `attr(x, ".survey_result")$var`, and (b) a future builder who sees `$var = NULL` may incorrectly attempt caching via `<<-` and reproduce the exact bug the spec warns about.

Options:
- **[A]** Remove `$var` from the attribute layout entirely. `se^2` recomputation on each `vcov()` call is O(p) and negligible. — Effort: minimal (spec edit), Risk: none.
- **[B]** Keep `$var` but add an explicit statement: "The returned list always contains all five keys. `$var` is always `NULL` and never read." — Effort: minimal.
- **[C]** Do nothing.

**Recommendation: A.** Dead slots are maintenance liabilities. Remove it. If caching is ever needed (for large p), add it at that time with a concrete use case.

---

**Issue 14: No verbatim print example or explicit intentional-decision statement for §IV**
Severity: REQUIRED
Section: §IV
Lens 3 (Contract Completeness)

The Lens 3 rule: "For every result class with a `print()` or `format()` method: is the exact console output shown as a verbatim example block, or is an explicit intentional-decision statement made?" §IV says "No new print methods are added. The existing `print.survey_result()` (via tibble print) is unchanged." This is an intentional decision but is stated without confirming that the hidden attribute does not appear in print output.

Options:
- **[A]** Add one explicit sentence: "The `.survey_result` attribute is stored with a dot-prefixed name and is hidden from `print.survey_result()` output. No verbatim example is required because no new print method is introduced and the existing output is unchanged by this phase."
- **[B]** Do nothing.

**Recommendation: A.** One sentence satisfies the lens requirement without requiring a full verbatim block.

---

**Issue 15: `parm` argument: default column misleading; `missing()` detection not specified**
Severity: REQUIRED
Section: §III.8
Lens 3 (Contract Completeness)

The argument table shows `parm | Default: —` (no default), which a builder may read as "required." But the spec says "when missing, all parameters are returned," implying `missing(parm)` detection. The standard `confint()` generic signature has `parm` as a formal with no default, using `missing(parm)`. The spec does not tell the builder how to implement the missingness check.

Options:
- **[A]** Change `Default` to "all parameters (when absent)" and add a note: "Use `missing(parm)` to detect absence; do not assign a default value — `confint.default` uses `missing()` and surveycore must match."
- **[B]** Change signature to `parm = NULL` with explicit `if (is.null(parm)) parm <- seq_along(coef(object))`.
- **[C]** Do nothing.

**Recommendation: A.** `missing(parm)` is the R-idiomatic approach matching the base generic.

---

**Issue 16: `SE.default()` has no arguments table**
Severity: REQUIRED
Section: §III.4
Lens 3 (Contract Completeness)

Every other function contract in §III has an explicit argument table. §III.4 has a signature block and a returns block but no arguments table. The Lens 3 rule requires "All arguments documented with type, default, one-sentence description."

Options:
- **[A]** Add: `object | any | — | Object to extract standard errors from.` and `... | — | — | Forwarded to `vcov()`.`
- **[B]** Add a note: "Arguments are identical to `SE()` generic — see §III.3."

**Recommendation: A.** A complete table is cleaner.

---

**Issue 17: `vcov()` cross-group warning incorrectly fires for ungrouped `survey_freqs` with p > 1**
Severity: REQUIRED
Section: §III.6 (off-diagonal warning)
Lens 3 (Contract Completeness)

The warning trigger fires when "p > 1" (ungrouped multi-row result). But for ungrouped `survey_freqs`, the full covariance matrix is computed via joint estimation (per §III.6's spec for `survey_freqs`), so there are no structural zeros — it is not a "cross-group zeros" situation. The spec says "Exceptions: `survey_freqs` grouped blocks should NOT emit the warning for within-group blocks" — but doesn't address ungrouped `survey_freqs` with p > 1, where the entire matrix is correctly estimated.

**Note:** This issue becomes moot if Issue 1 (survey_freqs vcov not implementable) is adopted with Option A, which downgrades survey_freqs to NA_real_ off-diagonal. If Issue 1/Option A is adopted, the warning SHOULD fire for ungrouped survey_freqs too (since off-diagonals become NA_real_). The resolution here is contingent on Issue 1.

Options:
- **[A]** If Issue 1/Option A is adopted: no change needed — ungrouped freqs joins the NA_real_ path and the warning fires correctly. Add a note in §III.6 that this exception is removed by Issue 1's resolution.
- **[B]** If Issue 1's Option A is NOT adopted: add explicit text: "For ungrouped `survey_freqs` with p > 1, the full covariance matrix is estimated via joint estimation (no structural zeros); do NOT emit `surveycore_warning_vcov_cross_group` in this case."

**Recommendation: A** — contingent on Issue 1 resolution.

---

**Issue 18: `get_diffs()` df sourcing confused: references non-existent meta field; `.degf(design)` unavailable at vcov() time**
Severity: REQUIRED
Section: §VI (`get_diffs()`)
Lenses 3 + 5

The spec states: "The `df` value is read from `meta(result)$design_type` — for Taylor it is `meta(result)$df_residual` if present, otherwise `.degf(design)` must be called."

Two problems: (1) "read from `meta(result)$design_type`" then "it is `meta(result)$df_residual`" — these are two different fields and the first sentence is factually wrong (design_type is a string like `"taylor"`, not a numeric df). (2) "otherwise `.degf(design)` must be called" — the builder has no access to `design` at `vcov()` call time. The design is available inside `get_diffs()`, not during vcov() dispatch.

In the actual `get_diffs()` code, the GLM fit object (`fit`) has `fit@degf` representing residual df — but this is not stored in meta_args.

Options:
- **[A]** Specify: "At the point where the `.survey_result` attribute is attached (still inside `get_diffs()`), `fit` is in scope. Compute `df_val <- as.numeric(fit@degf)` and pass `cell_df = rep(df_val, p)` to `.build_survey_result_attr()`. Do not attempt to read `df_residual` from metadata." — Effort: minimal (spec edit), Risk: none.
- **[B]** Add `df_residual = fit@degf` to `meta_args` before calling `.build_survey_result_attr()`, then read from `meta(result)$df_residual`. Changes the meta schema but makes df accessible post-construction.
- **[C]** Use `rep(Inf, p)` — ignore GLM-derived df entirely, produce conservative CIs.

**Recommendation: A** for this phase. Storing df_residual in meta is a good long-term improvement (Option B) but requires a separate spec change for the meta schema.

---

**Issue 19: `SE()` masking: `SE.svyby` and `SE.svrepstat` dispatch is not covered by `SE.default`**
Severity: REQUIRED
Section: §III.3, §IX
Lens 6 (API Coherence)

The spec claims "`SE.default(object, ...) sqrt(diag(vcov(object)))` covers most cases from both packages." This is true for `svystat` objects but false for `svyby` objects. `survey::SE.svyby()` does not call `vcov()` — it reads the `vartype` flag and extracts SE columns by position. When `survey::SE` is masked by `surveycore::SE`, a user calling `SE()` on a `svyby` result with `vartype = "cvpct"` will get `SE.default()` → `vcov()` → incorrect or `NA` SEs.

Options:
- **[A]** Add to §IX: document the limitation explicitly in `SE()` roxygen with `@note` or `@section Details:` stating that `SE.default` is equivalent to `survey::SE.svystat` but NOT to `survey::SE.svyby` or `survey::SE.svrepstat`. — Effort: minimal.
- **[B]** Register thin passthrough methods inside `if (requireNamespace("survey", quietly = TRUE))` guards: `SE.svyby <- survey::SE.svyby; SE.svrepstat <- survey::SE.svrepstat`. — Effort: low, Risk: low (creates a dependency on survey internals).
- **[C]** Do nothing — accept the masking limitation.

**Recommendation: A** at minimum. Option B is better if the package expects users to mix surveycore and survey objects.

---

**Issue 20: Ambiguous 3-token colon names for grouped `survey_corr` and `survey_covariance`**
Severity: REQUIRED
Section: §III.5 (naming convention)
Lens 6 (API Coherence)

For `survey_corr` (long) and `survey_covariance`, the row identifier is `var1:var2`, so grouped names become `group_label:var1:var2` — three colon-delimited tokens. A user who does `strsplit(names(coef(result)), ":")` gets three tokens and cannot determine the split point between group and pair without out-of-band knowledge. This ambiguity is by construction for all grouped corr/covariance results.

The `survey_freqs` and `survey_quantiles` classes use `.` as the intra-row delimiter (`variable.level`, `variable.p25`), making them unambiguous under colon grouping.

Options:
- **[A]** Change the pair separator to `"."` for `survey_corr` and `survey_covariance`: `"age.income"` ungrouped, `"Northeast:age.income"` grouped. Consistent with the existing `.` intra-row convention for freqs/quantiles. — Effort: low (spec edit + one implementation change), Risk: low.
- **[B]** Change the group separator to `"/"`: `"Northeast/age:income"`. Visual distinctiveness at the cost of departing from `svyby` convention.
- **[C]** Accept the ambiguity and document a parsing note.

**Recommendation: A.** The `.` separator is already established for intra-row identifiers. Changing `var1:var2` to `var1.var2` for these two classes is the minimal consistent fix.

---

**Issue 21: `vcov_cross_group` warning fires on 1×1 matrices and has wrong name for ungrouped multi-parameter case**
Severity: REQUIRED
Section: §III.6 (off-diagonal warning), §V (SCR-W2)
Lens 6 (API Coherence)

Two coherence problems with the current warning trigger ("grouped OR p > 1"):

**Problem A:** A grouped result with one observed group level produces a 1×1 matrix with no off-diagonal elements. The warning fires saying "off-diagonal elements are structural zeros" when there are no off-diagonal elements at all.

**Problem B:** For ungrouped multi-parameter results (e.g., multiple quantiles), the warning class is `surveycore_warning_vcov_cross_group` but there are no groups and no "cross-group" structure. A test that catches `class = "surveycore_warning_vcov_cross_group"` on an ungrouped result is semantically misleading.

The real invariant is: "p > 1 and any off-diagonal element is a structural zero (not jointly estimated)."

Options:
- **[A]** Change the trigger to `p > 1` only (drop the "grouped" condition), and rename the warning class to `surveycore_warning_vcov_diagonal_only`. Update SCR-W2 in §V and the §VIII quality gate. — Effort: low, Risk: low. Eliminates both problems.
- **[B]** Keep grouped trigger but add a 1×1 matrix guard: do not emit when `p == 1`.
- **[C]** Do nothing.

**Recommendation: A.** "Emit when p > 1" is the correct invariant. Rename eliminates semantic confusion.

---

**Issue 22: Broom column-not-found: no error message template in error table**
Severity: REQUIRED
Section: §IX (broom integration), §V (error table)
Lenses 4 + 6

§IX says: "If a broom-renamed result is passed, the column may not be found — throw `surveycore_error_result_method_unsupported` with an explanatory message about name_style." The §V error table has two message templates for SCR-1, neither of which mentions `name_style` or column-not-found. A builder will either use the wrong template (telling the user "the attribute is absent" when it is present) or invent an unspecified message that will fail snapshot tests.

Options:
- **[A]** Add a third template variant to SCR-1: `"x" = "{.fn {fn_name}} cannot find estimate column {.field {estimate_col}} in {.cls {class(object)[1L]}}.", "i" = "Column was renamed by {.code name_style = \"broom\"}. The original column name {.field {estimate_col}} is stored in {.code attr(x, '.survey_result')$estimate_cols}.", "v" = "Call {.fn coef} before applying {.code name_style = \"broom\"}, or access the estimate directly."` — Effort: low.
- **[B]** Add a new row SCR-4 for this distinct condition.
- **[C]** Do nothing.

**Recommendation: A.** Adding a third variant to SCR-1 keeps the class consistent while giving the builder a precise message template.

---

**Issue 23: Wide-format `survey_corr` detection logic is indistinguishable from "attribute absent"**
Severity: REQUIRED
Section: §I (class support matrix), §III.5, §VI (`get_corr()`)
Lens 6 (API Coherence)

The spec says "Wide format is detected by the absence of `estimate_cols` from `attr(x, '.survey_result')`." But wide-format `survey_corr` objects do not have the `.survey_result` attribute at all — the detection path is `is.null(attr(x, ".survey_result"))`, identical to the "attribute absent" path. Both produce the same error message ("The `.survey_result` metadata attribute is absent"), even though the user's actual problem is that `coef()` is not supported for wide-format corr and they should use `format = "long"`.

Options:
- **[A]** Add a class-specific check before the generic absent-attribute throw: if `inherits(object, "survey_corr") && is.null(attr(object, ".survey_result"))`, throw SCR-1 with a message specifying "Use `format = 'long'` in `get_corr()` before calling `coef()`." Add this template as a fourth SCR-1 variant in §V. — Effort: low.
- **[B]** Attach the attribute to wide-format corr objects with `estimate_cols = NULL` as a sentinel, then detect by `is.null(attr(x, ".survey_result")$estimate_cols)`. Matches the spec's stated detection logic. — Effort: low-medium.
- **[C]** Do nothing — accept the confusing error message.

**Recommendation: A.** No storage change needed; one additional `inherits()` check in `coef.survey_result()` plus a fourth message template.

---

**Issue 24: Empty `parm` vector in `confint()` — return value unspecified**
Severity: REQUIRED
Section: §III.8
Lens 4 (Edge Cases)

The spec's `parm` resolution handles missing, character, and integer/logical cases. When `parm = character(0)` or `parm = integer(0)`, each path produces no selections, but the return value is not specified. Should it return a `0×2` matrix? Throw? The §VII zero-row table covers zero-row *objects*, not zero-length `parm` on a non-empty object.

Options:
- **[A]** Add to §VII: "`parm = character(0)` or `parm = integer(0)` — returns a `0×2` matrix with `dimnames = list(character(0), c('2.5 %', '97.5 %'))`." This matches `stats::confint.default` behavior.
- **[B]** Throw `surveycore_error_invalid_parm` for empty `parm`.
- **[C]** Leave to implementer.

**Recommendation: A.** Consistent with §VII's zero-row object behavior and matches base R semantics.

---

**Issue 25: `NA` in `parm` argument — behavior unspecified**
Severity: REQUIRED
Section: §III.8
Lens 4 (Edge Cases)

`parm = NA_character_` or `parm = c("age", NA_character_)`: `match(NA_character_, names(coef(object)))` returns `NA_integer_`, which when used as a row index produces a row with `rowname = NA`. The spec says "unmatched names produce a warning and are silently dropped," but `NA_character_` is not unmatched in the same sense — it is structurally missing.

Options:
- **[A]** Specify: "NA elements in `parm` (both character and integer) are dropped with a warning of class `surveycore_warning_parm_na` before parameter selection proceeds." — Effort: low.
- **[B]** State that NA in parm follows standard R indexing (produces an NA-named row).
- **[C]** Do nothing.

**Recommendation: A.** Consistent with the "unmatched names are dropped" behavior already specified.

---

**Issue 26: All-unmatched `parm` names — warning class not specified; all-dropped return value not specified**
Severity: REQUIRED
Section: §III.8
Lens 4 (Edge Cases)

The spec says unmatched names "produce a warning and are silently dropped" but does not specify: (1) the warning class (base `warning()` vs. `cli_warn()` with class?), and (2) what is returned when all `parm` names are unmatched (the complete-drop case — does it return a `0×2` matrix or throw?). Both are needed for testable behavior.

Options:
- **[A]** Add warning class `surveycore_warning_parm_unmatched` to the SCR-W table. Specify that all-unmatched returns a `0×2` matrix with `dimnames = list(character(0), c('2.5 %', '97.5 %'))`.
- **[B]** Specify base `warning()` (no class) — unspecified in a spec that otherwise requires classes on all warnings.
- **[C]** Do nothing.

**Recommendation: A.** The quality gate requires 98%+ coverage; the warning path must be testable by class.

---

**Issue 27: `NaN` in `se` column propagates as `NaN`, not `NA_real_`**
Severity: REQUIRED
Section: §III.6, §III.8
Lens 4 (Edge Cases)

The spec addresses `NA` in the `se` column (returns `NA_real_`). But `NaN` is a legitimate output from variance estimators for degenerate designs (e.g., single PSU per stratum). `sqrt(NaN^2) = NaN` propagates through `vcov()` and `confint()` as `NaN`, not `NA_real_`. The spec's `NA_real_` contract does not cover `NaN`.

Options:
- **[A]** Specify: "Any `NaN` values in the `se` column are coerced to `NA_real_` before squaring in `vcov()`. Apply `se[is.nan(se)] <- NA_real_` before the `se^2` step." Add a §VII row: "`NaN` in `se` column — treated identically to `NA_real_`." — Effort: minimal.
- **[B]** Specify that `NaN` propagates as `NaN` (document as intentional).
- **[C]** Do nothing.

**Recommendation: A.** The spec already declares `NA_real_` as the canonical missing-variance output. `NaN` should be coerced for consistency.

---

**Issue 28: `length(estimate_cols) > 1` has no guard; behavior undefined for current phase**
Severity: REQUIRED
Section: §III.5, §III.6, §I (scope)
Lens 4 (Edge Cases)

The spec describes multi-estimate-column naming rules in §III.5 but marks multi-column vcov() as DEFERRED. All current classes have `length(estimate_cols) == 1`. The spec does not specify what `coef()` or `vcov()` does if someone accidentally constructs a result with `length(estimate_cols) > 1` — proceed silently with the naming rules (which would work for coef but not vcov), or throw an internal error.

Options:
- **[A]** Add a guard in `coef()` and `vcov()`: "If `length(estimate_cols) > 1`, throw an internal error (`stop()` or `stopifnot()`) with message 'multi-estimate-column results are not yet supported.' Add to §VIII quality gates: assert that `length(estimate_cols) == 1L` for all supported classes."
- **[B]** Let `coef()` proceed using the §III.5 naming rules (the description is sufficient for an implementation) while `vcov()` throws.
- **[C]** Leave undefined.

**Recommendation: A.** Makes phase boundary explicit and prevents silent wrong output.

---

**Issue 29: `survey_freqs` all-NA `pct` — behavior in joint estimation path unspecified**
Severity: REQUIRED
Section: §III.6, §VII
Lens 4 (Edge Cases)

§VII's "All estimates are NA" row says `coef()` returns all-NA_real_. But `survey_freqs` has a special `vcov()` path per §III.6 (joint influence-function estimation). When `pct` is all `NA`, the spec does not say whether to attempt joint estimation (which would fail on missing data) or fall back to the `NA_real_` matrix. **Note:** If Issue 1/Option A is adopted, `survey_freqs` uses the same diagonal `se^2` path as other classes, making this a non-issue. The resolution is contingent on Issue 1.

Options:
- **[A]** If Issue 1/Option A is adopted: no change needed. The diagonal path handles all-NA naturally.
- **[B]** If Issue 1's Option A is NOT adopted: add to §VII: "For `survey_freqs` with all-NA `pct`, `vcov()` returns an all-`NA_real_` matrix (skips joint estimation)."

**Recommendation: A** — contingent on Issue 1 resolution.

---

**Issue 30: DEFERRED multi-estimate-column note is not guarded against accidental implementation**
Severity: REQUIRED
Section: §III.6 (DEFERRED bullet)
Lens 5 (Engineering Level)

The DEFERRED paragraph in §III.6 describes future vcov() assembly in enough normative detail (including "Structural zeros... are NOT acceptable") that a builder could read it as a current requirement. There is no explicit "DO NOT IMPLEMENT" label and no specified guard.

Options:
- **[A]** Add to §III.6 DEFERRED bullet: "**DO NOT IMPLEMENT in this phase.** If `length(estimate_cols) > 1` is encountered, `stopifnot(FALSE, msg = 'multi-estimate-column vcov not implemented in this phase')` must fire." Also add to §VIII quality gates: "DEFERRED multi-estimate path fires a hard stop when triggered."
- **[B]** Move the DEFERRED paragraph to a separate appendix section.
- **[C]** Do nothing.

**Recommendation: A.** The guard makes the phase boundary a runtime error rather than a reading comprehension task.

---

**Issue 31: `.build_survey_result_attr()` validation is absent for the `get_diffs()` call path**
Severity: REQUIRED
Section: §III.1, §VI
Lens 5 (Engineering Level)

§III.1 says "Errors: None — arguments are validated upstream in `.make_result_tibble()`." But `get_diffs()` bypasses `.make_result_tibble()` and calls `.build_survey_result_attr()` directly. This means no validation when the helper is called via `get_diffs()`. Unspecified boundary cases: `estimate_cols = character(0)`, `cell_df` of wrong length, `statistic = NA_character_`.

Options:
- **[A]** Add minimal internal guards to `.build_survey_result_attr()`: `stopifnot(length(estimate_cols) >= 1L, length(statistic) == 1L, !is.na(statistic))`. Document these as programmer-error guards. — Effort: minimal.
- **[B]** Add explicit validation to `get_diffs()` at the call site before calling `.build_survey_result_attr()`.
- **[C]** Do nothing — accept that `get_diffs()` is a trusted caller.

**Recommendation: A.** Self-enforcing contracts in helpers with multiple call paths.

---

**Issue 32: `cell_df` threading rule leaves three critical cases ambiguous**
Severity: REQUIRED
Section: §VI (`cell_df` threading rule)
Lens 5 (Engineering Level)

Three underspecified boundary cases:

1. **"p" mapping:** The spec says "per-cell df vector" without explicitly defining "cell" as row-aligned to the result tibble. For `get_means()` with 5 groups, `p = 5` and `cell_df[i]` must correspond to row `i`. This mapping is unstated.

2. **`NA_real_` df from empty calibrated domains:** When a calibrated Taylor design has empty-domain groups, the df for those cells may be `NA_real_`. Is this acceptable in the df vector, or should it be coerced to `Inf`?

3. **No CI requested:** The spec says the calibrated df vector is "already computed when building the `ci_low`/`ci_high` CI columns." But CI columns are only present when `variance = "ci"` is in the `variance` argument. If the user calls `get_means(design, x, variance = "se")` with no CI, the calibrated df computation may not have been run.

Options:
- **[A]** Add explicit prose: "For calibrated Taylor designs, the per-cell df vector is always computed regardless of the `variance` argument. The vector is row-aligned: `cell_df[i]` corresponds to result row `i`. `NA_real_` df values from empty domains should be replaced with `Inf` before passing to `.build_survey_result_attr()`."
- **[B]** Leave to the builder.

**Recommendation: A.** Three independent ambiguities that compound into hard-to-diagnose bugs.

---

**Issue 33: No numerical oracle for `vcov()` on replicate designs or `survey_freqs`**
Severity: REQUIRED
Section: §III.6, `plans/test-spec-coef-vcov-methods.md` §4.5–4.6
Lens 2 (Test Completeness)

`vcov()` oracle tests exist only for `survey_means` with Taylor designs on NHANES. Missing: replicate designs (architecturally distinct variance estimator; `acs_pums_wy` is named in the test spec datasets but unused for `vcov()`), and `survey_freqs` (spec's special joint-estimation case makes it higher priority for an oracle). **Note:** If Issue 1/Option A is adopted, the freqs oracle reduces to a simple diagonal SE² comparison.

Options:
- **[A]** Add `vcov()` oracle for replicate designs (`acs_pums_wy`, vs. `survey::vcov`) and for `survey_freqs` diagonal. — Effort: medium.
- **[B]** Add only the replicate oracle. — Effort: low.
- **[C]** Do nothing.

**Recommendation: A.**

---

**Issue 34: No `label_values` stability test for `coef()` on `survey_freqs`**
Severity: REQUIRED
Section: §III.5 (coef naming for survey_freqs)
Lens 2 (Test Completeness)

§III.5 explicitly states: "If the result has been processed with `label_values = TRUE`, the raw values are still used for `coef()` naming to guarantee stability." This is a named behavioral contract with no corresponding test. A binary variable coded 1/2 with labels "Male"/"Female" — after `label_values = TRUE`, `coef()` must still return `"sex.1"`, `"sex.2"`, not `"sex.Male"`, `"sex.Female"`.

Options:
- **[A]** Add one test: construct `survey_freqs` with labeled values; apply `label_values = TRUE`; assert `names(coef(result))` still use raw values. — Effort: low.
- **[B]** Do nothing.

**Recommendation: A.**

---

**Issue 35: No `meta()` contract test for any method**
Severity: REQUIRED
Section: §III.5 (names derived from `attr(object, ".meta")$x`), §VI
Lens 2 (Test Completeness)

No test verifies that `.meta` attribute is correctly read for `coef()` naming (which uses `attr(object, ".meta")$x` for variable names), or that `.meta` is unchanged after calling any method. For `get_diffs()`, `coef()` names use `meta(result)$reference_level` — not directly tested.

Options:
- **[A]** Add: (1) meta immutability tests — assert `meta(result)` is unchanged after calling each method; (2) one positive test for `survey_diffs` — assert `names(coef(result))` include the `reference_level` in the expected contrast format. — Effort: low.
- **[B]** Do nothing.

**Recommendation: A.**

---

**Issue 36: No `name_style = "broom"` error path test**
Severity: REQUIRED
Section: §IX
Lens 2 (Test Completeness)

§IX specifies a typed error when `name_style = "broom"` renames estimate columns before `coef()` is called. There is no test in the test spec for this error path — no `expect_error(class = "surveycore_error_result_method_unsupported")` and no snapshot.

Options:
- **[A]** Add: apply `name_style = "broom"` to a result, then call `coef()`, assert it throws SCR-1 with the broom-specific message (from Issue 22's resolution). Dual pattern (class= + snapshot). Also add a confirmation test that `coef()` works on the result *before* `name_style = "broom"`. — Effort: low.
- **[B]** Do nothing.

**Recommendation: A.**

---

**Issue 37: Snapshot inconsistency for `confint()` invalid `level` between §7.4 and §11**
Severity: REQUIRED
Section: `plans/test-spec-coef-vcov-methods.md` §7.4, §11
Lens 2 (Test Completeness)

§11 lists snapshots for both `confint() with level = 0` and `confint() with level = 1.1`. In §7.4's test body, only `level = 0` has an `expect_snapshot(error = TRUE, ...)` call. `level = 1` has `expect_error(class=...)` but no snapshot. `level = 1.1` is listed in §11 but has no `expect_snapshot()` in §7.4's body. An implementor reading §7 alone will not write these tests; one reading §11 will. This is a spec/test-spec inconsistency.

Options:
- **[A]** Add `expect_snapshot(error=TRUE, confint(result, level=1))` and `expect_snapshot(error=TRUE, confint(result, level=1.1))` to §7.4's test block.
- **[B]** Remove `level=1.1` from §11's required snapshot list.

**Recommendation: A.** Both boundary values should be snapshotted.

---

**Issue 38: No warning tests for SCR-W1 (`survey_corr` off-diagonal) and SCR-W2 (cross-group zeros)**
Severity: REQUIRED
Section: §V (SCR-W1, SCR-W2), §VIII quality gate
Lens 2 (Test Completeness)

§VIII explicitly lists both warnings as quality gates. Neither has an `expect_warning(class=)` test in the test spec. The project testing standard requires `expect_warning()` wrapping the call with `class=` specified.

Options:
- **[A]** Add three blocks: (1) `survey_corr` with 3+ variables → `expect_warning(vcov(result), class = "surveycore_warning_vcov_incomplete")`; (2) grouped means → `expect_warning(vcov(result), class = "surveycore_warning_vcov_cross_group")`; (3) ungrouped multi-quantile → `expect_warning(vcov(result), class = "surveycore_warning_vcov_cross_group")`.
- **[B]** Add only SCR-W1 and SCR-W2 (grouped trigger only).
- **[C]** Do nothing.

**Recommendation: A.**

---

**Issue 39: Zero-row result: `vcov()` `0×0` matrix and `SE()` `character(0)` names contract untested**
Severity: REQUIRED
Section: §VII, `plans/test-spec-coef-vcov-methods.md` §3.10, §6.8
Lens 2 (Test Completeness)

§VII precisely specifies `vcov()` returns a `0×0` matrix with `character(0)` dimnames (not `NULL`) for zero-row objects. The test spec covers `coef()` (§3.10) and `confint()` (§6.8) for this case. `vcov()` and `SE()` are untested. The `character(0)` dimnames requirement is especially important — `NULL` dimnames would be silently wrong and may not be caught without an explicit `identical(dimnames(vcov(result)), list(character(0), character(0)))` assertion.

Options:
- **[A]** Add to the existing zero-row test setup in §3.10/§6.8: assert `identical(dimnames(vcov(result)), list(character(0), character(0)))` and `identical(names(SE(result)), character(0))`.
- **[B]** Do nothing.

**Recommendation: A.**

---

**Issue 40: `test_invariants()` absent from all design-creating test blocks**
Severity: REQUIRED
Section: `.claude/rules/testing-surveycore.md`, `plans/test-spec-coef-vcov-methods.md` throughout
Lens 2 (Test Completeness)

The `testing-surveycore.md` rule requires `test_invariants(d)` as the **first assertion** in every `test_that()` block that creates a survey object via `as_survey()` or `as_survey_replicate()`. The test spec has ~15+ blocks that create design objects without this call (§1.4, §1.5, §3.1, §7.1, §7.4, §8.5, §8.6, §10, §12, §13, etc.).

Options:
- **[A]** Add `test_invariants(d)` as the first assertion in every block that creates a survey design. Effort: low (mechanical addition). — Risk: none.
- **[B]** Document an exception for method-testing blocks.

**Recommendation: A.** Project rule, no exceptions.

---

**Issue 41: §11 snapshot list has 3 entries with no matching test bodies**
Severity: REQUIRED
Section: `plans/test-spec-coef-vcov-methods.md` §7, §11
Lens 2 (Test Completeness)

§11 lists 8 required snapshots. Five have matching `test_that()` blocks in §7. Three are listed in §11 but have no corresponding `test_that()` block:
- `SE()` on `survey_t_test` — listed in §11, no body in §7
- `confint()` on `survey_t_test` — listed in §11, no body in §7
- `confint() with level = 1.1` — listed in §11, no snapshot call in §7.4's body

An implementor reading §7 alone will not write these tests; one reading §11 will find no implementation instructions to follow.

Options:
- **[A]** Add §7.6 (`SE()` on `survey_t_test`, dual pattern) and §7.7 (`confint()` on `survey_t_test`, dual pattern); add `expect_snapshot(error=TRUE, ...)` for `level=1.1` to §7.4. — Effort: low.
- **[B]** Remove the 3 items from §11. — Weakens coverage.

**Recommendation: A** (overlaps with Issue 7).

---

#### SUGGESTION

---

**Issue 42: §V error table re-states conditions already defined in function contracts**
Severity: SUGGESTION
Section: §V, §III.5, §III.6, §III.8, §VII
Lens 1 (DRY)

The SCR-1 and SCR-3 condition columns re-state behavior already in §III.5, §III.6, §III.8, and §VII. When a condition description changes, all copies require simultaneous updates. The §V table serves a distinct output purpose (error-messages.md rows), so some restatement is structurally justified — but adding "(canonical definition: §III.5)" in the condition cells would guide editors.

**Recommendation:** Low-priority. Add a parenthetical cross-reference in the §V condition cells on next revision.

---

**Issue 43: Absent-`se` vcov behavior restated in III.6 and VII**
Severity: SUGGESTION
Section: §III.6, §VII
Lens 1 (DRY)

The "absent `se` column → NA matrix" behavior appears in §III.6 and is partly restated in §VII. The §VII row extends to `SE()` and `confint()` (adding new information), but the `vcov()` clause is duplicated verbatim. If the absent-se behavior changes, both must be updated.

**Recommendation:** In §VII, replace the `vcov()` clause with "see §III.6 absent `se` column" and keep only the `SE()` and `confint()` cascade (the new information).

---

**Issue 44: `df = Inf` no-special-casing statement duplicated verbatim in III.8 and VII**
Severity: SUGGESTION
Section: §III.8, §VII
Lens 1 (DRY)

The formula `qt(1 - (1 - level)/2, df = Inf) = qnorm(1 - (1 - level)/2)` appears word-for-word in both §III.8 and §VII.

**Recommendation:** In §VII, replace the formula with "see §III.8 degrees of freedom — no special-casing needed."

---

**Issue 45: Zero-row `character(0)` dimnames requirement not cross-referenced from method contracts**
Severity: SUGGESTION
Section: §III.5, §III.6, §VII
Lens 1 (DRY)

The `character(0)` dimnames requirement (vs. `NULL`) for zero-row results appears only in §VII. Builders reading §III.5 or §III.6 contracts may miss this non-obvious detail.

**Recommendation:** Add to §III.5 and §III.6: "Zero-row results: see §VII for the required `character(0)` dimnames construction."

---

**Issue 46: SCR-2 message template references `{.arg conf_level}` but `confint()` uses `{.arg level}`**
Severity: SUGGESTION
Section: §III.8, §V (SCR-2)
Lens 3 (Contract Completeness)

Row 45a's template (reused by SCR-2) says `{.arg conf_level} must be a single number...`. The `confint.survey_result()` argument is `level`, not `conf_level`. A builder using the row 45a template verbatim will produce a message referencing the wrong argument name, which will fail snapshot tests.

**Recommendation:** Add a note to SCR-2: "Adapt the row 45a template — substitute `{.arg level}` for `{.arg conf_level}`."

---

**Issue 47: `SE.default()` body shown as prose, not code**
Severity: SUGGESTION
Section: §III.4
Lens 3 (Contract Completeness)

The implementation body `sqrt(diag(vcov(object, ...)))` is described in prose under "Returns." It should appear as a code block to remove any ambiguity about the exact implementation.

**Recommendation:** Add a one-line code block: `SE.default <- function(object, ...) sqrt(diag(vcov(object, ...)))`.

---

**Issue 48: Coverage Map in `error-messages.md` has no row for `test-analysis-coef-vcov.R`**
Severity: SUGGESTION
Section: `plans/error-messages.md` (Coverage Map)
Lens 3 (Contract Completeness)

Expected before-implementation omission. The test file does not yet exist, so the Coverage Map has no entry for it. Should be updated when the test file is created.

**Recommendation:** Add to §VIII quality gates: "Update `error-messages.md` Coverage Map to include `test-analysis-coef-vcov.R`."

---

**Issue 49: `stopifnot()` message mechanism for the `.make_result_tibble()` guard is unspecified**
Severity: SUGGESTION
Section: §III.2
Lens 3 (Contract Completeness)

The spec says the function "must call `stopifnot()` with a message." In R, `stopifnot()` with a custom message uses `stopifnot("message text" = condition)`. The exact invocation form is not specified, which will produce varying snapshot outputs.

**Recommendation:** Specify the exact form: `stopifnot("Both 'estimate_cols' and 'statistic' must be supplied together, or both must be NULL." = is.null(estimate_cols) == is.null(statistic))`.

---

**Issue 50: Wide-format `survey_corr` error behavior not explicitly restated for `vcov()`, `SE()`, `confint()`**
Severity: SUGGESTION
Section: §I (class support matrix), §VI (`get_corr()`)
Lens 4 (Edge Cases)

The spec says wide-format corr throws `surveycore_error_result_method_unsupported` via `coef()`. But §III.6, §III.7, and §III.8 do not explicitly state the same for `vcov()`, `SE()`, and `confint()`. These do throw via the standard attribute-absent guard, but a reader of those sections alone might not realize wide-format corr hits that path.

**Recommendation:** Add to §VI `get_corr()`: "All four methods on wide-format `survey_corr` throw `surveycore_error_result_method_unsupported` via the standard attribute-absent guard."

---

**Issue 51: Logical `parm` of wrong length — recycling semantics undocumented**
Severity: SUGGESTION
Section: §III.8
Lens 4 (Edge Cases)

`parm = c(TRUE, FALSE)` on a p=5 result will silently recycle in base R. The spec does not state whether recycling applies or is treated as an error.

**Recommendation:** Add: "Logical `parm` vectors must have length equal to `length(coef(object))`; if `length(parm) != p`, throw an error via `stopifnot()`." Consistent with the spec's general pattern of explicit validation.

---

**Issue 52: `level = NA_real_` passes the `strictly between 0 and 1` guard**
Severity: SUGGESTION
Section: §III.8
Lens 4 (Edge Cases)

`is.numeric(NA_real_)` is `TRUE`; `NA_real_ > 0` is `NA` (falsy), so `level = NA_real_` may slip through depending on how the validation is written, producing `NA` CI bounds with no error.

**Recommendation:** Add `is.na(level)` to the validation guard explicitly. One check; consistent with the spec's existing rigor on `level` validation.

---

**Issue 53: `survey_effective_n` and `survey_variance` absent from the scope matrix**
Severity: SUGGESTION
Section: §I.3 (result class support matrix)
Lens 5 (Engineering Level)

`get_effective_n()` produces `survey_effective_n` and `get_variance()` produces `survey_variance` — both inherit `survey_result` but are not listed in the support matrix (neither in-scope nor explicitly excluded). Since neither will receive `estimate_cols`, they will throw `surveycore_error_result_method_unsupported`. This is correct but undocumented, and a builder might add `estimate_cols` to their construction thinking it was an oversight.

**Recommendation:** Add rows to §I.3 for both classes: "Excluded by design — no `estimate_cols` passed; `coef()` throws `surveycore_error_result_method_unsupported`."

---

**Issue 54: `confint()` column label claim should reference the formula, not a finite list of levels**
Severity: SUGGESTION
Section: §III.8
Lens 6 (API Coherence)

The spec says the column labels "match `stats::confint.default()` for all standard confidence levels (0.80, 0.90, 0.95, 0.99)." The claim should be stated as a formula equivalence rather than an enumeration of levels.

**Recommendation:** Replace with: "Uses the same `paste0(format(...), ' %')` formula as `stats::confint.default()`, producing identical output for any level value."

---

**Issue 55: Warning tests for SCR-W2 not in grouped-analysis test section**
Severity: SUGGESTION
Section: `plans/test-spec-coef-vcov-methods.md` §3 (grouped analysis), §V (SCR-W2)
Lens 2 (Test Completeness)

Category 3 (grouped analysis) tests cover `coef()`, `vcov()`, and `confint()` for grouped results, but no block asserts the SCR-W2 warning is emitted. This is also addressed in Issue 38 — resolving Issue 38 covers this.

**Recommendation:** Covered by Issue 38/Option A.

---

**Issue 56: No domain-column test for `vcov()`, `SE()`, `confint()`**
Severity: SUGGESTION
Section: `plans/test-spec-coef-vcov-methods.md` §3.9
Lens 2 (Test Completeness)

The only domain estimation test (`coef()` NA propagation, §3.9) does not cover `vcov()`, `SE()`, or `confint()`. The spec notes cross-domain covariances are structural zeros in these cases. Resolved if Issue 38/Option A covers the SCR-W2 warning for domain-filtered results.

**Recommendation:** Defer to Issue 38 resolution.

---

**Issue 57: `SE()` omitted from §8.1 single-group edge case**
Severity: SUGGESTION
Section: `plans/test-spec-coef-vcov-methods.md` §8.1
Lens 2 (Test Completeness)

§8.1 asserts `coef()`, `vcov()`, and `confint()` for single-group results but omits `SE()`. Since `SE()` is defined as `sqrt(diag(vcov()))` and `vcov()` is already asserted, the risk is minimal — but the pattern is inconsistent.

**Recommendation:** Add `expect_equal(length(SE(result)), 1L)` to §8.1.

---

**Issue 58: No `vcov()` structure test for multi-prob quantile result**
Severity: SUGGESTION
Section: `plans/test-spec-coef-vcov-methods.md`
Lens 2 (Test Completeness)

`get_quantiles()` with 3 quantile values is an ungrouped p=3 case — the canonical SCR-W2 trigger for the ungrouped path. The test spec tests `coef()` naming for this case but not `vcov()` structure (diagonal, off-diagonal zeros) or the SCR-W2 warning. Resolved if Issue 38/Option A adds a multi-probs quantile block.

**Recommendation:** Covered by Issue 38/Option A.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 8 |
| REQUIRED | 33 |
| SUGGESTION | 17 |

**Total issues:** 58

**Overall assessment:** The spec has a solid foundation — the function contracts are detailed, the error table is mostly complete, and the naming conventions are well-specified. However, it has two critical architectural gaps (Issue 1: `survey_freqs` off-diagonal vcov is not implementable from stored data; Issue 2: `get_diffs()` references a metadata field that does not exist) that would cause builder failure or silent wrong output. The test spec has three blocking gaps in numerical oracle coverage (Issue 6) and error-path coverage (Issues 7–8). These 8 BLOCKING findings must be resolved before implementation begins.

---

## Spec Review: coef-vcov-methods — Pass 2 (2026-06-22)

All six lenses applied to spec v1.3 and test-spec v1.2.

---

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `survey_freqs` off-diagonal vcov not implementable from stored data | ✅ Resolved |
| 2 | `get_diffs()` `group_cols` source field does not exist | ✅ Resolved |
| 3 | SCR-3, SCR-W1, SCR-W2 absent from `error-messages.md`; write surface incomplete | ✅ Resolved |
| 4 | `confint()` column label formula vulnerable to floating-point artifacts | ✅ Resolved |
| 5 | `df = NA_real_` bypasses the guard and silently produces NA CI bounds | ✅ Resolved |
| 6 | No numerical oracle for `coef()` on five result classes | ✅ Resolved |
| 7 | Eight SCR-1 error sub-paths untested | ✅ Resolved |
| 8 | No test for SCR-3 (`confint()` with invalid `df`) | ✅ Resolved |
| 9 | Absent-attribute guard prose restated in §III.5, §III.6, and §VII | ✅ Resolved |
| 10 | Unsupported-classes check restated across three sections | ✅ Resolved |
| 11 | Scope table and write surface claim 2 new error entries; 5 are defined | ✅ Resolved |
| 12 | S7 membership test uses `inherits()` string form | ✅ Resolved |
| 13 | `$var` slot — remove dead code | ✅ Resolved |
| 14 | No verbatim print example or explicit intentional-decision in §IV | ✅ Resolved |
| 15 | `parm` default misleading; `missing()` detection not specified | ✅ Resolved |
| 16 | `SE.default()` has no arguments table | ✅ Resolved |
| 17 | `vcov()` warning fires incorrectly for ungrouped `survey_freqs` | ✅ Resolved (via Issue 1) |
| 18 | `get_diffs()` df sourcing confused; references non-existent meta fields | ✅ Resolved |
| 19 | `SE()` masking: `SE.svyby` dispatch not covered by `SE.default` | ✅ Resolved |
| 20 | Ambiguous 3-token colon names for grouped `survey_corr`/`survey_covariance` | ✅ Resolved |
| 21 | `vcov_cross_group` warning fires on 1×1 matrices; wrong class name | ✅ Resolved |
| 22 | Broom column-not-found: no message template in error table | ✅ Resolved |
| 23 | Wide-format `survey_corr` detection indistinguishable from absent attribute | ✅ Resolved |
| 24 | Empty `parm` vector — return value unspecified | ✅ Resolved |
| 25 | `NA` in `parm` — behavior unspecified | ✅ Resolved |
| 26 | All-unmatched `parm` names — warning class and return value unspecified | ✅ Resolved |
| 27 | `NaN` in `se` column propagates as `NaN` | ✅ Resolved |
| 28 | `length(estimate_cols) > 1` has no guard | ✅ Resolved |
| 29 | `survey_freqs` all-NA `pct` — behavior in joint estimation path | ✅ Resolved (via Issue 1) |
| 30 | DEFERRED multi-estimate-column note not guarded against accidental implementation | ✅ Resolved |
| 31 | `.build_survey_result_attr()` validation absent for `get_diffs()` call path | ✅ Resolved |
| 32 | `cell_df` threading rule leaves three critical cases ambiguous | ✅ Resolved |
| 33 | No numerical oracle for `vcov()` on replicate designs or `survey_freqs` | ✅ Resolved |
| 34 | No `label_values` stability test for `coef()` on `survey_freqs` | ✅ Resolved |
| 35 | No `meta()` contract test for any method | ✅ Resolved |
| 36 | No `name_style = "broom"` error path test | ✅ Resolved |
| 37 | Snapshot inconsistency for `confint()` invalid `level` | ✅ Resolved |
| 38 | No warning tests for SCR-W1 and SCR-W2 | ✅ Resolved |
| 39 | Zero-row result: `vcov()` 0×0 and `SE()` `character(0)` untested | ✅ Resolved |
| 40 | `test_invariants()` absent from all design-creating test blocks | ⚠️ Still open (partial) |
| 41 | §11 snapshot list has 3 entries with no matching test bodies | ✅ Resolved |
| 42 | §V error table re-states conditions already in function contracts | ⚠️ Still open (suggestion) |
| 43 | Absent-`se` `vcov()` behavior restated in §III.6 and §VII | ⚠️ Still open (suggestion) |
| 44 | `df = Inf` no-special-casing statement duplicated in §III.8 and §VII | ⚠️ Still open (suggestion) |
| 45 | Zero-row `character(0)` dimnames requirement not cross-referenced | ✅ Resolved |
| 46 | SCR-2 template references `{.arg conf_level}` but `confint()` uses `{.arg level}` | ✅ Resolved |
| 47 | `SE.default()` body shown as prose | ✅ Resolved |
| 48 | Coverage Map has no row for `test-analysis-coef-vcov.R` | ✅ Resolved |
| 49 | `stopifnot()` message mechanism for `.make_result_tibble()` guard unspecified | ✅ Resolved |
| 50 | Wide-format `survey_corr` error not restated for `vcov()`, `SE()`, `confint()` | ✅ Resolved |
| 51 | Logical `parm` of wrong length — recycling undocumented | ✅ Resolved |
| 52 | `level = NA_real_` passes the strict-between-0-and-1 guard | ✅ Resolved |
| 53 | `survey_effective_n` and `survey_variance` absent from scope matrix | ✅ Resolved |
| 54 | `confint()` column label claim should reference formula | ✅ Resolved |
| 55 | Warning tests for SCR-W2 not in grouped-analysis section | ✅ Resolved |
| 56 | No domain-column test for `vcov()`, `SE()`, `confint()` | ✅ Resolved (deferred per recommendation) |
| 57 | `SE()` omitted from §8.1 single-group edge case | ✅ Resolved |
| 58 | No `vcov()` structure test for multi-prob quantile result | ✅ Resolved |

---

### New Issues

#### REQUIRED

**Issue 59: Test spec §1.1 asserts `'var'` in attribute names — that field was removed**
Severity: REQUIRED
Section: `plans/test-spec-coef-vcov-methods.md` §1.1
Lens 2 (Test Completeness) / Lens 3 (Contract Completeness)

Issue 13 (Pass 1) was resolved by removing `$var` from the attribute layout. The spec §II now documents four fields: `estimate_cols`, `group_cols`, `statistic`, `df`. However, test spec §1.1 still asserts:

> "Asserts the attribute has names `c("estimate_cols", "group_cols", "statistic", "df", "var")`."

This assertion will fail: the `$var` field no longer exists. The implementer writing the test block using this spec assertion will produce a failing test immediately.

Options:
- **[A]** Remove `"var"` from the assertion in §1.1: change to `c("estimate_cols", "group_cols", "statistic", "df")`. — Effort: trivial, Risk: none.
- **[B]** Do nothing — builder hits a test failure on day 1.

**Recommendation: A.**

---

**Issue 60: SCR-W3 and SCR-W4 have no tests; confint() parm-warning branches are untestable at 98% coverage**
Severity: REQUIRED
Section: `plans/test-spec-coef-vcov-methods.md` §6, §7; spec §V (SCR-W3, SCR-W4)
Lens 2 (Test Completeness)

The spec §V defines SCR-W3 (`surveycore_warning_parm_na`) and SCR-W4 (`surveycore_warning_parm_unmatched`). Both are referenced in §III.8. The test spec §6 covers normal `parm` subsetting by name (§6.6) and integer (§6.7) but has no test blocks for:

1. `parm` containing `NA` elements — should emit SCR-W3 and drop them
2. `parm` with some unmatched character names — should emit SCR-W4 and drop them
3. `parm` with ALL unmatched character names — should emit SCR-W4 and return a 0×2 matrix

At 98% line coverage, the branches implementing these three paths in `confint.survey_result()` will be uncovered. The §VIII quality gate cannot be satisfied without these tests.

Options:
- **[A]** Add three test blocks to §6 (or a new §6.10): one per path, each with `expect_warning(class=...)` wrapping and (for error-adjacent paths) a dual pattern if snapshot is appropriate. Also add SCR-W3 and SCR-W4 entries to §11's snapshot/warning list. — Effort: low (three small blocks), Risk: none.
- **[B]** Mark SCR-W3 and SCR-W4 branches with `# nocov` — unacceptable; these are user-facing code paths.

**Recommendation: A.**

---

**Issue 61: §I scope table undercounts new error entries after SCR-W3/W4 were added**
Severity: REQUIRED
Section: §I (scope table)
Lens 3 (Contract Completeness)

Issue 11 (Pass 1) was resolved by updating §I to say "Four new error entries: SCR-1, SCR-3, SCR-W1, SCR-W2 (SCR-2 reuses `surveycore_error_invalid_conf_level`)." However, SCR-W3 and SCR-W4 were subsequently added to §V. The §I scope table was not updated. Current state: §I says 4 new entries; §V defines 6 new entries; §VIII quality gate and the §V closing note both correctly say 6. A builder using §I as a checklist for `error-messages.md` entries will add only 4 rows and miss SCR-W3 and SCR-W4.

Options:
- **[A]** Update §I to: "Six new error entries: SCR-1, SCR-3, SCR-W1, SCR-W2, SCR-W3, SCR-W4 (SCR-2 reuses `surveycore_error_invalid_conf_level`)." — Effort: trivial, Risk: none.
- **[B]** Do nothing.

**Recommendation: A.**

---

**Issue 62: §III.5 `coef()` naming contract silent on `.meta$x = NULL` (population-size totals)**
Severity: REQUIRED
Section: §III.5 (naming convention), §VI (`get_totals()`)
Lens 3 (Contract Completeness)

§III.5 states: "bare row identifier, derived from the variable name stored in `attr(object, '.meta')$x`." For `get_totals()` in no-variable mode (population size estimation), `.meta$x` is `NULL`. The resulting `coef()` name should be `"N"` — but this rule appears only in §VI (`get_totals()` call change section), not in §III.5's naming contract.

A builder implementing `coef.survey_result()` by reading §III.5 alone will encounter `NULL` for `.meta$x` and either crash (trying to use `NULL` as a name), produce an unnamed vector, or produce a wrong name. The test in §8.3 asserts `names(cv) == "N"` but the builder has no spec guidance in §III.5 on what `"N"` comes from.

Options:
- **[A]** Add to §III.5's naming convention: "When `.meta$x` is `NULL` (no-variable mode, `get_totals()` population size), the name is `'N'`." — Effort: one sentence, Risk: none.
- **[B]** Do nothing — builder reads §VI to discover the rule.

**Recommendation: A.** The naming contract in §III.5 must be self-contained.

---

**Issue 63: `SE.survey_result()` will emit `surveycore_warning_vcov_diagonal_only` as an undocumented side effect**
Severity: REQUIRED
Section: §III.7 (`SE.survey_result()`), §III.6 (off-diagonal warning)
Lens 6 (API Coherence)

§III.7 specifies that `SE.survey_result()` delegates to `vcov.survey_result()`. §III.6 specifies that `vcov.survey_result()` emits `surveycore_warning_vcov_diagonal_only` when `p > 1`. The combined result: calling `SE(result)` on any grouped result (p > 1) emits a warning about off-diagonal elements of `vcov()` — a function the user did not call. The spec §III.7 does not document this cascading warning behavior.

Users calling `SE(result)` to extract standard errors from a grouped mean will receive an unexpected warning telling them "`vcov()` off-diagonal elements are structural zeros" — confusing because they didn't ask for a covariance matrix. The spec is technically consistent but violates the principle "does the function do what its name implies without surprising the user?"

Options:
- **[A]** Specify that `SE.survey_result()` uses `suppressWarnings(vcov(object))` internally. The off-diagonal warning is irrelevant when only the diagonal is needed, and `SE()` docs already note the limitation. — Effort: one line added to §III.7, Risk: none.
- **[B]** Document the cascading warning explicitly in §III.7: "Note: `SE.survey_result()` delegates to `vcov()`, which emits `surveycore_warning_vcov_diagonal_only` when `p > 1`. Wrap with `suppressWarnings()` if the warning is not desired." — Effort: one sentence, leaves user burden intact.
- **[C]** Do nothing — accept the surprising cascade.

**Recommendation: A.** `SE()` is extracting a diagonal, not computing a full covariance matrix. The structural-zeros warning is noise for SE-only users and should be suppressed internally. Add a note in `SE.survey_result()` roxygen that the `se` column and `vcov()` diagonal are guaranteed to be consistent.

---

**Issue 64: Issue 40 partially resolved — `test_invariants()` still absent from 10+ complete code blocks**
Severity: REQUIRED
Section: `plans/test-spec-coef-vcov-methods.md` §7.1, §7.2, §7.3, §7.6, §7.7, §7.8, §12, §13, §14.1–14.6
Lens 2 (Test Completeness)

Issue 40 (Pass 1) was partially resolved — many blocks now include `test_invariants(d)`. However, the following complete code blocks that create survey designs still lack it:

- **§7.1** (`coef()` on `survey_t_test`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§7.2** (`coef()` on `survey_pairwise`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§7.3** (`vcov()` on `survey_t_test`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§7.6** (`SE()` on `survey_t_test`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§7.7** (`confint()` on `survey_t_test`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§7.8** (`vcov/SE/confint` on `survey_pairwise`): creates `d` via `as_survey()`, no `test_invariants(d)`.
- **§12** (numerical oracle — totals): creates `d_sc` via `as_survey_replicate()`, no `test_invariants(d_sc)`.
- **§13** (numerical oracle — freqs): creates `d_sc` via `as_survey()`, no `test_invariants(d_sc)`.
- **§14.1–14.5** (oracle blocks for ratios, quantiles, covariance, diffs, corr): each creates a design, no `test_invariants`.
- **§14.6** (vcov replicate oracle): creates `d_sc` via `as_survey_replicate()`, no `test_invariants(d_sc)`.
- **§4.5** (`vcov()` matches `survey::vcov.svystat`): creates `d_sc` via `as_survey()`, no `test_invariants(d_sc)`.
- **§4.6** (`vcov()` grouped, matches `survey::vcov.svyby`): creates `d_sc` via `as_survey()`, no `test_invariants(d_sc)`.
- **§5.3** (`SE()` matches `survey::SE`): creates `d_sc` via `as_survey()`, no `test_invariants(d_sc)`.
- **§6.5** (`confint()` matches `survey::confint.svystat`): creates `d_sc` via `as_survey()`, no `test_invariants(d_sc)`.

Project rule (`testing-surveycore.md`): `test_invariants(d)` is the **first** assertion in every `test_that()` block that creates a survey design.

Options:
- **[A]** Add `test_invariants(d_sc)` (or equivalent design variable name) as the first assertion in each of the 14+ affected code blocks. — Effort: low (mechanical), Risk: none.
- **[B]** Add a blanket exception for numerical oracle and unsupported-class test blocks.

**Recommendation: A.** The rule has no stated exceptions. The invariants catch structural regressions that would otherwise silently produce wrong oracle comparisons.

---

#### SUGGESTION

**Issue 65: §III.5 `coef()` naming doesn't specify how `var1`/`var2` are extracted from `.meta` for corr/covariance**
Severity: SUGGESTION
Section: §III.5 (naming convention)
Lens 3 (Contract Completeness)

For `survey_corr` (long) and `survey_covariance`, the row identifier is `var1.var2`. The §III.5 naming table gives example names (`"age.income"`) but does not specify how `var1` and `var2` are extracted from `attr(object, ".meta")`. The spec says all other naming derives from `.meta$x` — but for two-variable statistics, the meta structure holds something different (likely `meta$x` and `meta$y`, or a variable list). A builder reading §III.5 alone would need to inspect production code for these classes.

**Recommendation:** Add one sentence to §III.5 for corr/covariance: specify the exact `.meta` fields from which `var1` and `var2` are read (e.g., "`meta$x` and `meta$y`" or "`meta$vars`"). Alternatively, reference §VI where the meta structure is documented.

---

**Issue 66: `.build_survey_result_attr()` does not validate `cell_df` length**
Severity: SUGGESTION
Section: §III.1
Lens 5 (Engineering Level)

The programmer-error guards in §III.1 validate `estimate_cols` and `statistic` but not that `cell_df` has length `p` (the number of coefficients). An off-by-one or miscomputed `cell_df` vector passed from a future `get_*()` function would be stored silently, causing `confint()` to use wrong df values per parameter with no error. This is especially relevant because `get_diffs()` calls `.build_survey_result_attr()` directly.

**Recommendation:** Add `stopifnot(length(cell_df) == length(estimate_cols) * n_rows)` where `n_rows` is `nrow(result)` at the call site. Or specify the `p` variable clearly enough that the length invariant is obvious. Low priority for the initial implementation, but worth adding before the builder writes `get_diffs()`.

---

**Issue 67: `survey_diffs` reference level field uses "(or equivalent)" — leaves builder uncertain**
Severity: SUGGESTION
Section: §VI (`get_diffs()`)
Lens 5 (Engineering Level)

§VI says: "The reference level comes from `meta(result)$reference_level` (or equivalent). Builder should verify the field name in `get_diffs()` metadata." The phrase "or equivalent" + "Builder should verify" is a hedge that requires the builder to read production code before implementing `coef()` naming for `survey_diffs`. The spec should be definitive.

**Recommendation:** Read `get_diffs()` source to determine the exact field name (likely `attr(result, ".meta")$reference_level` or similar) and state it explicitly in the spec. Replace the "or equivalent" hedge with the canonical field path.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 3 |

**Total new issues:** 9

**Overall assessment:** All 8 BLOCKING findings from Pass 1 are resolved. The spec and test spec are in strong shape — the architectural and contract gaps that would have caused builder failure are closed. The 6 REQUIRED issues in this pass are narrow and correctable: two test spec attribute assertion mismatches (Issues 59, 64), two scope-table inconsistencies (Issues 61, 62), one undocumented cascade warning (Issue 63), and one missing test coverage category (Issue 60). None require architectural rethinking. Resolving these 6 issues produces an implementable spec pair.
