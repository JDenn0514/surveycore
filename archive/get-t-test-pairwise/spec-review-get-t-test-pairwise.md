## Spec Review: get-t-test-pairwise — Pass 1 (2026-04-13)

### New Issues

---

#### Section: II — File Organization / get_pairwise() Execution (§4.3)

**Issue 1: `surveytidy::filter()` in `get_pairwise()` creates a circular package dependency**
Severity: BLOCKING
Violates r-package-conventions.md (import policy) and the ecosystem dependency graph

The spec (§4.3, step 1) reads:
> "Create `design_ab` by applying a domain filter to rows where `by %in% c(a, b)`.
> Use `surveytidy::filter()` or equivalent domain-indicator approach…"

surveycore is the *dependency* of surveytidy, not the other way around. Calling
`surveytidy::filter()` from inside `get_pairwise()` would introduce a circular
dependency: surveytidy → surveycore → surveytidy. This is not an incidental
style issue — it would make the package uninstallable.

The "equivalent domain-indicator approach" is already used throughout the
codebase. `survey_glm()` uses `.apply_domain()` for all domain estimation. The
pair-subset must be implemented by writing a domain column into `design_ab@data`
(the `..surveycore_domain..` pattern) or by constructing an `active_mask`
analogous to the one built in step 9.a of `get_t_test()`, then zeroing
out-of-domain score contributions inside the GLM call — not by calling
`surveytidy::filter()`.

Options:
- **[A]** Replace the `surveytidy::filter()` reference with the internal
  domain-masking mechanism: set `design_ab@data[["..surveycore_domain.."]]` to a
  logical vector where `by %in% c(a, b)` and any domain already active in
  `design@data`, then pass `design_ab` to `get_t_test()`. Document the exact
  property-mutation pattern. — Effort: medium (requires specifying S7 data
  mutation), Risk: low, Impact: closes the circular-dependency hole and is
  consistent with how `survey_glm()` already handles domains, Maintenance: none
- **[B]** Have `get_pairwise()` call an internal unexported function
  `.run_pairwise_glm()` that accepts a pre-built mask rather than going through
  `get_t_test()`. This bypasses NSE entirely (see Issue 2). — Effort: medium,
  Risk: low, Impact: cleaner internals but diverges from the stated design,
  Maintenance: two implementations of the same GLM path to keep in sync
- **[C] Do nothing** — Implementer cannot build this without violating the
  dependency graph.

**Recommendation: [A]** — The `.apply_domain()` / domain-column pattern is
already the surveycore idiom. Spec must name it explicitly and remove the
`surveytidy::filter()` reference.

---

**Issue 2: NSE forwarding from `get_pairwise()` to `get_t_test()` — mechanism unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever)

The spec (§4.5, step 8c) says:
> "Call `get_t_test(design_ab, x = x, by = by, group = group, ...)`"

`get_pairwise()` captures `x`, `by`, and `group` via NSE (`rlang::enquo()`).
When it tries to call `get_t_test()` using those captured quosures, passing them
as-is is incorrect — `get_t_test()` would re-capture them, receive a quosure
instead of a bare symbol, and either error or produce silently wrong column
names.

The spec must say one of:
- Use `rlang::inject(get_t_test(design_ab, x = !!x_sym, by = !!by_sym, ...))`
  after converting quosures to symbols via `rlang::as_name()`, or
- Convert `x_name` and `by_name` to symbols and call via injection.

This is a pure specification gap — the NSE forwarding pattern is standard in the
rlang ecosystem but the spec is silent on which form to use, leaving each
implementer to guess independently.

Options:
- **[A]** Specify rlang injection in §4.5 step 8c:
  `rlang::inject(get_t_test(design_ab, x = !!rlang::sym(x_name), by = !!rlang::sym(by_name), group = !!group_sym, ...))`
  Effort: low, Risk: low, Impact: makes calling convention explicit,
  Maintenance: none
- **[B]** Move the shared computation into an internal helper `.fit_t_test()`
  that operates on resolved names rather than NSE symbols, and have both
  `get_t_test()` and `get_pairwise()` call it. — Effort: medium, Risk: low,
  Impact: cleaner architecture, avoids NSE forwarding entirely, Maintenance:
  single implementation maintained in one place
- **[C] Do nothing** — All rlang users know the injection pattern; it is
  implied.

**Recommendation: [A or B]** — [B] is architecturally cleaner (avoids NSE
forwarding entirely and keeps all GLM-fitting logic DRY) but requires a spec
change to the function organization section. [A] is a one-sentence fix if the
current structure is kept. Either is acceptable; the choice must be recorded.

---

**Issue 3: `by` re-leveling mechanism in `get_pairwise()` — target object not named**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever)

§4.5 step 8b reads:
> "Re-level `by` factor: `factor(by, levels = c(a, b))`."

This code snippet creates a new factor but doesn't say which object is modified.
The relevel must be applied to `design_ab@data[[by_name]]` so that the modified
factor is visible to the subsequent `get_t_test()` call. But `design_ab` is an
S7 object — assigning into `design_ab@data` requires the appropriate S7 mutation
pattern (e.g., `design_ab@data[[by_name]] <- factor(...)`). The spec must state:

1. That the target of the relevel is `design_ab@data[[by_name]]`.
2. That the assignment syntax is `design_ab@data[[by_name]] <-
   factor(design_ab@data[[by_name]], levels = c(a, b))`.
3. Whether this triggers any S7 validator for `survey_taylor`/`survey_replicate`
   (it should not, since `by` is not a design variable).

Options:
- **[A]** Add one sentence to step 8b: "Assign back:
  `design_ab@data[[by_name]] <- factor(design_ab@data[[by_name]], levels = c(a, b))`.
  This does not trigger S7 validators because `by` is not a design variable."
  — Effort: low, Risk: low, Impact: unambiguous, Maintenance: none
- **[C] Do nothing** — Experienced S7 users will infer this; the spec is
  "close enough."

**Recommendation: [A]** — S7 property mutation has subtle rules; one sentence
removes the ambiguity.

---

#### Section: III — `get_t_test()` Specification (§3.1–3.7)

**Issue 4: `name_style` absent from signature; `.validate_shared_args()` requires it as a positional argument**
Severity: REQUIRED
Violates code-style.md §4 (argument order rule) and DRY principle

§3.6 step 2 says: "Validate `na.rm`, `conf_level`, `decimals` via
`.validate_shared_args()`." But the existing `.validate_shared_args()` signature
(R/analysis-helpers.R:573) is:

```r
.validate_shared_args <- function(
  variance, conf_level, name_style, decimals = NULL, na.rm = TRUE, ...
)
```

`name_style` is a **required positional argument** (no default). Calling
`.validate_shared_args(variance, conf_level, decimals = decimals, na.rm = na.rm)`
without passing `name_style` is a runtime error. Every other analysis function
(including `get_diffs()`) passes `name_style` because it's part of their
signature.

The spec must either:
(a) add `name_style = "surveycore"` to `get_t_test()` and `get_pairwise()`, or
(b) modify `.validate_shared_args()` to default `name_style = NULL` (skip
    name_style validation when NULL), or
(c) have these functions call a narrower validator that omits name_style.

Options:
- **[A]** Add `name_style = "surveycore"` to both function signatures (§3.1,
  §4.1). Update step 2 to include it in the `.validate_shared_args()` call and
  step 12 to call `.apply_name_style()`. This preserves API uniformity across
  all `get_*()` functions. — Effort: low, Risk: low, Impact: full broom
  compatibility, uniform API, Maintenance: none
- **[B]** Make `name_style` optional in `.validate_shared_args()` by defaulting
  it to `NULL` and skipping its validation when `NULL`. These two functions
  would not offer `name_style`. — Effort: low, Risk: low, Impact: breaks API
  uniformity; broom users cannot normalize column names, Maintenance: two tiers
  of the same validator
- **[C] Do nothing** — The function will throw an error the first time a
  developer calls `.validate_shared_args()` without `name_style`.

**Recommendation: [A]** — API uniformity across the `get_*()` family is a
documented goal (MEMORY.md). Every other analysis function supports
`name_style`. Adding it here is trivial; omitting it fragments the API.

---

**Issue 5: `label_vars` absent from both function signatures — breaks `get_*()` API uniformity**
Severity: REQUIRED
Violates API Coherence (Lens 6)

Every other analysis function in the `get_*()` family accepts `label_vars =
TRUE`. Some functions use it meaningfully; others accept it "for API uniformity"
(see R/analysis-means.R:45, R/analysis-quantiles.R:49, R/analysis-ratios.R:56).
These two functions omit it entirely.

The practical effect: code that iterates over the `get_*()` family with a fixed
set of arguments will fail when it reaches `get_t_test()` with
`"unused argument (label_vars = TRUE)"`. Users who read one `get_*()` function
signature and expect the same arguments across the family will be surprised.

Options:
- **[A]** Add `label_vars = TRUE` to both signatures, accepted but unused (like
  `get_means()`). Document with: "Accepted for API uniformity; has no visible
  effect because all variable labels are managed through `label_values`." —
  Effort: low, Risk: low, Impact: uniform API, Maintenance: none
- **[B]** Explicitly document in §I.Scope: "`label_vars` is not supported; use
  `label_values` for label display." Add a `label_vars` entry in §V that maps
  it to a warning when supplied. — Effort: low, Risk: low, Impact: user gets
  feedback instead of silent failure, Maintenance: none
- **[C] Do nothing** — These functions are distinct enough that the difference
  is acceptable.

**Recommendation: [A]** — Zero-effort fix; the precedent from `get_means()` is
already in the codebase.

---

**Issue 6: `surveycore_error_empty_domain` absent from reused classes table**
Severity: REQUIRED
Violates Contract Completeness (Lens 3)

When `survey_glm()` is called on a design where the active mask leaves 0
in-domain rows, it throws `surveycore_error_empty_domain` (error-messages.md
row 83). This condition can arise in `get_t_test()` if the domain mask
(inherited from a prior `surveytidy::filter()` call) combined with the
`na.rm`-based active mask results in 0 rows — even before the per-level empty
cell check fires.

The §V "Reused classes" table does not include `surveycore_error_empty_domain`.
An implementer writing tests will not know to expect this error, and a user
seeing it will have no hint in the `get_t_test()` documentation.

Options:
- **[A]** Add `surveycore_error_empty_domain` to the "Reused classes" table in
  §V with note: "Via `survey_glm()` when domain has 0 in-domain rows after
  applying `active_mask` and NA removal." — Effort: low, Risk: low, Impact:
  test coverage reminder, Maintenance: none
- **[C] Do nothing** — The error fires from inside `survey_glm()`, not from
  `get_t_test()` directly; it propagates naturally.

**Recommendation: [A]** — Reused classes must be documented so tests can cover
them. Omitting it leaves a gap in the error-path test plan (§VI).

---

**Issue 7: `level_a`/`level_b` label-conversion mechanism not named**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever)

§3.4 step 5 says:
> "When `label_values = TRUE` and the `by` column has value labels in
> `design@metadata`, the `level_a` and `level_b` output columns show label
> strings instead of raw codes."

And §3.7 confirms `level_a`/`level_b` are `character` type. But the spec never
names a helper for this conversion. The existing `.apply_group_labels()` helper
converts group-column factor values — it doesn't directly map a scalar factor
level to its label string. A new lookup pattern is needed (e.g., `labels[[as.character(code)]]`).

Without naming the mechanism, different implementers will write different code
(e.g., one may use `haven::as_factor()`, another may use a raw lookup from
`design@metadata@value_labels`).

Options:
- **[A]** Add a sentence to §3.4 step 5: "Use the `value_labels` entry from
  `.extract_var_meta(design, by_name)` to map each active level string to its
  label; if no label exists for a level, use the level string unchanged." —
  Effort: low, Risk: low, Impact: single authoritative lookup path, Maintenance:
  none
- **[B]** Extract a new internal helper `.level_to_label(level, by_meta)` for
  this lookup and reference it in §3.4. — Effort: low, Risk: low, Impact:
  explicitly named helper, DRY if used in both `level_a` and `level_b`, 
  Maintenance: none
- **[C] Do nothing** — The lookup is simple enough that any implementer will do
  it the same way.

**Recommendation: [A]** — One sentence; removes the ambiguity about the lookup
source.

---

**Issue 8: Model matrix inspection mechanism after `survey_glm()` not specified**
Severity: REQUIRED
Violates Contract Completeness (Lens 3)

§3.6 step 9.d says:
> "Inspect the model matrix: verify exactly 2 columns with a binary second
> column."

`survey_glm_fit` objects do not expose the model matrix as a named slot. The
spec does not say how to retrieve it. Three options exist:
1. `length(coef(fit)) == 2L` — checks coefficient count (proxy for 2-column
   model matrix); doesn't verify the binary constraint.
2. `ncol(fit@fit_$qr$qr) == 2L` — inspects internal IRWLS QR decomposition;
   fragile, implementation-dependent.
3. `ncol(stats::model.matrix(fit@fit_)) == 2L` — uses the standard R method on
   the internal fit object; most robust.

The "binary second column" check (values all in `{0, 1}`) adds an additional
constraint on top of the column count check. The spec must specify which
post-fit mechanism is used and how strictly the binary constraint is enforced.

Options:
- **[A]** Replace the abstract description with a concrete check: "Verify
  `length(coef(fit)) == 2L`. If not, throw `surveycore_error_by_not_two_levels`.
  The binary constraint on the second column is guaranteed by factor coercion
  in step 6 — no additional check is needed." — Effort: low, Risk: low, Impact:
  unambiguous, consistent with R GLM conventions, Maintenance: none
- **[B]** Inspect the actual model matrix via `model.matrix(fit@fit_)` and
  verify both column count and binary constraint. — Effort: low, Risk: medium
  (relies on `@fit_` being accessible; may break if the internal slot is
  renamed), Impact: fully specified, Maintenance: tied to internal `survey_glm_fit`
  structure
- **[C] Do nothing** — Leave mechanism as "inspect model matrix" without
  specifying how.

**Recommendation: [A]** — Checking coefficient count is correct, minimal, and
does not depend on internal `survey_glm_fit` structure. The binary constraint
falls out of factor coercion and doesn't need a runtime check.

---

#### Section: IV — `get_pairwise()` Specification (§4.2–4.5)

**Issue 9: Empty group strata after pair-subsetting — behavior not specified**
Severity: REQUIRED
Violates Edge Cases (Lens 4) and engineering-preferences.md §4

When `get_pairwise()` subsets the design to rows where `by %in% c(a, b)` (step
8a) and then calls `get_t_test(..., group = group, ...)` (step 8c), some
`group` strata may have zero rows for one or both `by` levels after that
subset. This condition triggers `surveycore_error_by_empty_cell` inside
`get_t_test()`.

The spec does not say what `get_pairwise()` should do when `get_t_test()`
errors on a specific group stratum:
- Propagate the error (abort the entire `get_pairwise()` call)?
- Skip the pair-stratum and emit a `NA` row with a warning?
- Silently omit the failing stratum from the output?

This is not an exotic edge case — in stratified data, rare levels of `by` may
exist only in some group strata. Users will hit this in real analyses.

Options:
- **[A]** Propagate: let `get_t_test()` errors bubble up unchanged. Document:
  "If any pair-stratum combination has an empty cell, `get_pairwise()` aborts
  with `surveycore_error_by_empty_cell`. Filter the design or the `group`
  variable to exclude problematic strata before calling." — Effort: low
  (default behavior), Risk: low, Impact: predictable; user must fix input,
  Maintenance: none
- **[B]** Skip and warn: catch `surveycore_error_by_empty_cell`, emit a `NA`
  row for that pair-stratum with a `surveycore_warning_empty_pair_stratum`
  warning. — Effort: medium, Risk: medium (complex NA handling), Impact: more
  resilient, Maintenance: requires a new warning class
- **[C] Do nothing** — Leave behavior undefined; implementer decides.

**Recommendation: [A]** — Propagating errors is the safest default for a
statistical function. Document the behavior explicitly so users know what to
do. Option B can be added in a future version if demand exists.

---

**Issue 10: `na.rm = FALSE` and active-level computation in `get_pairwise()` — inconsistency**
Severity: REQUIRED
Violates Edge Cases (Lens 4)

§4.5 step 5 defines active levels as: "those with ≥ 1 non-NA observation
after applying the domain mask." But `na.rm = FALSE` means the calling
convention intends to keep NA rows. The phrase "non-NA observation" in the
active-levels check would exclude all NA rows from the count regardless of
`na.rm`.

Concretely: if `by` has 2 non-NA levels ("A", "B") plus some `NA` values,
with `na.rm = FALSE`, is `NA` a third active level (→ `surveycore_error_by_one_level`
if it's the only thing present after domain masking)?

The spec should define: "Active levels are those with ≥ 1 non-NA `by`
observation in the domain mask. `na.rm` affects whether NA rows in `x` are
included in the GLM fit, not whether NA `by` values define an active level."
i.e., NA `by` values are never a valid level regardless of `na.rm`.

Options:
- **[A]** Add a clarifying sentence to §4.5 step 5: "NA values in `by` are
  excluded from the active-level count regardless of `na.rm`. NA `by` rows are
  always excluded from the GLM fit." — Effort: low, Risk: low, Impact:
  eliminates ambiguity, Maintenance: none
- **[C] Do nothing** — "Non-NA observation" implicitly excludes NA `by` values;
  the edge case is unlikely.

**Recommendation: [A]** — The ambiguity is small but specific, and `na.rm =
FALSE` is listed in §VI edge cases, so this case will be tested.

---

**Issue 11: Empty-cell check order — warning fires for n=0 before error**
Severity: REQUIRED
Violates engineering-preferences.md §4 (edge cases)

§3.6 step 9.b says:
> "Check `min_cell_n`: warn if either active `by` level has fewer than
> `min_cell_n` in-mask rows. Warning: `surveycore_warning_small_cell`.
> Then check for empty cells: if either active `by` level has zero in-mask rows,
> error immediately."

When a cell has n=0, the small-cell warning fires first (0 < 30 = `min_cell_n`
default), then the empty-cell error fires. This means the user sees both a
warning and an error for the same condition. The warning is misleading — "fewer
than 30 observations" is vacuously true for an empty cell, but the real problem
is that the cell is empty.

Options:
- **[A]** Reverse the check order: check for empty cells first; if any cell is
  empty, error immediately without issuing the small-cell warning. Then check
  `min_cell_n` for non-empty cells only. — Effort: low, Risk: low, Impact:
  cleaner diagnostics, Maintenance: none
- **[B]** Skip the small-cell warning when n=0 (add a guard: warn only when
  `0 < n < min_cell_n`). Order stays as written. — Effort: low, Risk: low,
  Impact: same clean outcome, Maintenance: none
- **[C] Do nothing** — The warning fires and then the error fires; one is
  suppressed in normal error handling.

**Recommendation: [A]** — Reversing the order makes the spec more readable and
matches the logical hierarchy: existence check before size check.

---

#### Section: VI — Testing Requirements

**Issue 12: `.meta` contract not in test plan — missing test category 8**
Severity: REQUIRED
Violates testing-standards.md (13 mandatory test categories, category 8: meta()
contract)

The testing requirements (§VI) cover happy paths, error paths, and edge cases,
but do not include any test for the `.meta` content — neither `T_TEST_META_KEYS`
structure, the `by.levels` subkey, nor the `pval_adj` key in `PAIRWISE_META_KEYS`.

The project standard mandates: for every result class with a `.meta` contract,
there must be at least one test that checks `meta(result)` keys match the spec.

Options:
- **[A]** Add to §VI: a "Meta contract" test block for each function:
  "- [ ] `meta(result)` has keys `design_type`, `n_respondents`, `conf_level`,
    `call`, `group`, `x`, `by` for `survey_t_test`; all keys in
    `T_TEST_META_KEYS` present; `by` entry includes `levels` key with the two
    factor levels in order."
  "- [ ] `meta(result)` for `survey_pairwise` includes additional `pval_adj`
    key matching the method passed."
  Effort: low, Risk: low, Impact: 98% coverage target, Maintenance: none
- **[C] Do nothing** — Meta structure is implicitly tested when the object is
  constructed.

**Recommendation: [A]** — Category 8 is a required test category per the
project testing standard. The spec must include it.

---

**Issue 13: Test plan doesn't explicitly mark N/A categories — categories 7, 9, 12**
Severity: SUGGESTION
Violates testing-standards.md (N/A must be stated and justified)

Per the Stage 3 review process, all 13 test categories must be applied to every
exported function. Categories that don't apply must be explicitly marked N/A
with a reason. The §VI test plan covers categories 1 (happy path), 3 (grouped
analysis), 5 (variance argument), 6 (label_values), 10 (error paths), 11 (edge
cases), 13 (print snapshot), and 2 (numerical oracle, covered in separate file).

Not mentioned at all:
- **Category 7 — `label_vars`**: N/A because these functions have no `label_vars`
  argument (see Issue 5 — may need to be added).
- **Category 9 — `name_style = "broom"`**: N/A for same reason (Issue 4).
- **Category 12 — Multi-variable**: N/A because `x` is a single column by
  design (`surveycore_error_wrong_variable_count` fires for >1).

The spec should add explicit N/A annotations for these three categories.

Options:
- **[A]** Add three N/A bullets to §VI: "- N/A: `label_vars` (no argument)",
  "- N/A: `name_style = 'broom'` (no argument)", "- N/A: Multi-variable `x`
  (single column enforced by design)." — Effort: low, Risk: low, Maintenance:
  none. *(NB: If Issues 4 and 5 are resolved by adding these arguments, remove
  the N/A annotations and add the corresponding test bullets.)*
- **[C] Do nothing** — Reviewers will infer N/A from the absence of these
  arguments.

**Recommendation: [A]** — Explicit N/A is required by the testing standard and
prevents future reviewers from flagging the same gaps.

---

**Issue 14: `by` argument documentation style inconsistent with rest of `get_*()` family**
Severity: SUGGESTION
Violates API Coherence (Lens 6) / surveycore-conventions.md naming patterns

§3.2 documents `by` as type "bare name." Every other NSE argument across the
`get_*()` family uses `<tidy-select>` markup in the roxygen `@param` (e.g.,
`get_diffs()` line 22 for `treats`). Using "bare name" in the spec will likely
produce inconsistent `@param` documentation at implementation time — one
function using tidy-select markup, two not.

Additionally, `x` is documented as "bare name" in §3.2 but the error class for
>1 column is `surveycore_error_wrong_variable_count`, which was introduced for
`get_diffs()` where `treats` uses tidy-select resolution. This implies `x`
*is* resolved via tidy-select (`tidyselect::eval_select()`), not just
`rlang::enquo()`. But `by` is resolved via `rlang::as_name(rlang::enquo(by))`
(§3.4 step 1) — a different mechanism. Two NSE arguments in the same function
using different resolution mechanisms is surprising.

Options:
- **[A]** Normalize: resolve both `x` and `by` via `rlang::enquo()` +
  `rlang::as_name()`. Document both as "bare name" consistently. For `x`,
  change the error class from `wrong_variable_count` to a new simpler check
  (or keep it but note that it fires only for the tidy-select case if `x`
  accepts expressions). — Effort: low, Risk: low, Impact: internally consistent,
  Maintenance: none
- **[B]** Normalize in the other direction: resolve both via tidy-select.
  Document both as `<tidy-select>`. This aligns with `get_diffs()` style but
  adds `tidyselect` complexity to the `by` resolution path. — Effort: medium,
  Risk: low, Maintenance: none
- **[C] Do nothing** — Mixed NSE mechanisms within one function are unusual but
  functional.

**Recommendation: [A]** — Using `rlang::enquo()` for both is simpler and
consistent. The `wrong_variable_count` error fires when the column can't be
found — that's compatible with `rlang::enquo()`-based resolution too.

---

**Issue 15: Print snapshot examples show header only — full snapshot not specified**
Severity: SUGGESTION
Violates testing-standards.md §3 (snapshot tests require exact output)

§3.9 and §4.8 show the print header format but say only "Followed by the tibble
body" — no complete example output is given. Snapshot tests (`expect_snapshot()`)
must capture the entire `print()` output, including the tibble body. The spec
cannot show this without a concrete dataset and result, but it should at minimum:

1. Confirm which `nhanes_2017` variable pair and design will be used for the
   snapshot (to make the snapshot reproducible and auditable).
2. Confirm that the snapshot includes the full tibble print (not just the header).

Options:
- **[A]** Add to §3.9 and §4.8: "The snapshot test should use `nhanes_design`
  with `x = bpxsy1, by = gender` (2 levels: 1 = Male, 2 = Female) and
  `decimals = 2`. The snapshot captures the full `print()` output including the
  tibble body." — Effort: low, Risk: low, Maintenance: none
- **[C] Do nothing** — The implementer will choose a representative example when
  writing the snapshot test; the header format is the more important contract.

**Recommendation: [A]** — The implementer will write snapshot tests anyway;
specifying the fixture ahead of time prevents silent snapshot drift between team
members.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 10 |
| SUGGESTION | 4 |

**Total issues:** 15

**Issue index:**

| # | Section | Title | Severity |
|---|---|---|---|
| 1 | §4.3 | `surveytidy::filter()` creates circular dependency | BLOCKING |
| 2 | §4.5 | NSE forwarding to `get_t_test()` — mechanism unspecified | REQUIRED |
| 3 | §4.5 | `by` re-leveling — target object not named | REQUIRED |
| 4 | §3.1/§4.1 | `name_style` absent; `.validate_shared_args()` requires it | REQUIRED |
| 5 | §3.1/§4.1 | `label_vars` absent — breaks `get_*()` API uniformity | REQUIRED |
| 6 | §V | `surveycore_error_empty_domain` absent from reused classes table | REQUIRED |
| 7 | §3.4 | `level_a`/`level_b` label-conversion mechanism not named | REQUIRED |
| 8 | §3.6 | Model matrix inspection method not specified | REQUIRED |
| 9 | §4.5 | Empty group strata after pair-subsetting — behavior undefined | REQUIRED |
| 10 | §4.5 | `na.rm = FALSE` active-level computation — NA `by` values ambiguous | REQUIRED |
| 11 | §3.6 | Empty-cell warning fires before error for same n=0 condition | REQUIRED |
| 12 | §VI | `.meta` contract not in test plan (test category 8 missing) | REQUIRED |
| 13 | §VI | N/A test categories 7, 9, 12 not stated explicitly | SUGGESTION |
| 14 | §3.2 | `by` and `x` use different NSE mechanisms without justification | SUGGESTION |
| 15 | §3.9/§4.8 | Print snapshot examples show header only | SUGGESTION |

**Overall assessment:** The spec is methodologically sound (Pass 1 resolved all
statistical issues) but has one blocking implementation-safety issue
(circular dependency via `surveytidy::filter()`) and ten required gaps spanning
implementation mechanics, API uniformity, and test coverage. The spec should not
be handed to an implementer until Issues 1–12 are resolved. Issues 1, 4, and 5
are the highest priority: Issue 1 is a package-level correctness issue, and
Issues 4–5 touch the calling convention of the shared `.validate_shared_args()`
helper used across the entire `get_*()` family.

---

## Spec Review: get-t-test-pairwise — Pass 2 (2026-04-14)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `surveytidy::filter()` creates circular dependency | ✅ Resolved |
| 2 | NSE forwarding to `get_t_test()` — mechanism unspecified | ✅ Resolved |
| 3 | `by` re-leveling — target object not named | ✅ Resolved |
| 4 | `name_style` absent; `.validate_shared_args()` requires it | ✅ Resolved |
| 5 | `label_vars` absent — breaks `get_*()` API uniformity | ✅ Resolved |
| 6 | `surveycore_error_empty_domain` absent from reused classes table | ✅ Resolved |
| 7 | `level_a`/`level_b` label-conversion mechanism not named | ✅ Resolved |
| 8 | Model matrix inspection method not specified | ✅ Resolved |
| 9 | Empty group strata after pair-subsetting — behavior undefined | ✅ Resolved |
| 10 | `na.rm = FALSE` active-level computation — NA `by` values ambiguous | ✅ Resolved |
| 11 | Empty-cell warning fires before error for same n=0 condition | ✅ Resolved |
| 12 | `.meta` contract not in test plan (test category 8 missing) | ✅ Resolved |
| 13 | N/A test categories 7, 9, 12 not stated explicitly | ✅ Resolved |
| 14 | `by` and `x` use different NSE mechanisms without justification | ✅ Resolved |
| 15 | Print snapshot examples show header only | ✅ Resolved |

All 15 Pass 1 issues are resolved in v0.3. The spec is substantially improved.

### New Issues

---

#### Section: III — `get_t_test()` Specification (§3.6)

**Issue 16: `broom` name_style — `df` → `parameter` rename undocumented; `t_stat` not addressed**
Severity: REQUIRED
Violates Contract Completeness (Lens 3) and API Coherence (Lens 6)

The existing `.apply_name_style()` broom map (confirmed in `R/analysis-helpers.R:718-730`)
includes `df = "parameter"`. In broom mode, the `survey_t_test` output will have `parameter`
where `df` was — but the spec test says only:

> "`name_style = 'broom'` renames columns to tidymodels conventions (`estimate`, `std.error`,
> `conf.low`, `conf.high`, `p.value`); surveycore column names (`se`, `ci_low`, `ci_high`) are absent."

Two problems:
1. `df` is also absent (renamed to `parameter`) but not mentioned — a test written from
   this description would not check for `parameter` and might not catch breakage.
2. `t_stat` is not in the broom map, so it stays as `t_stat` in broom mode. The standard
   broom name for a test statistic is `statistic`. The spec neither adds `t_stat` to the
   map nor explicitly states it remains unchanged. An implementer wanting full broom
   compatibility will add `t_stat = "statistic"` to the map; an implementer following the
   spec literally will leave `t_stat` as-is. The output differs silently.

Options:
- **[A]** Explicitly state that broom mode produces: `df` → `parameter` (via existing map)
  and `t_stat` remains `t_stat` (intentional, not a broom violation since broom's `htest`
  convention is package-specific). Update the §VI test to include `expect_false("df" %in% names(result))` and
  `expect_true("parameter" %in% names(result))`. — Effort: low, Risk: low, Impact: removes
  ambiguity for both the test writer and future `.apply_name_style()` maintainers, Maintenance: none
- **[B]** Add `t_stat = "statistic"` to `.apply_name_style()` broom map and document that
  broom mode produces `statistic` not `t_stat`. Update the §VI test accordingly. — Effort: low,
  Risk: low, Impact: fully broom-compatible output, but requires a shared-helper change,
  Maintenance: none
- **[C] Do nothing** — The implementer will discover the `df` → `parameter` rename when
  tests run; `t_stat` staying as-is is defensible.

**Recommendation: [A]** — Document the actual behavior; the existing map already decides the
outcome. Option B is worth considering if full broom compatibility is a goal, but that decision
should be made explicitly before implementation.

---

**Issue 17: `na.rm = FALSE` with NAs in `x` or `by` — `n_a`/`n_b` will over-count**
Severity: REQUIRED
Violates Edge Cases (Lens 4) and Contract Completeness (Lens 3)

§3.6 step 9.a says: "Build `active_mask`: rows in this group stratum with non-NA `x` and `by`
(when `na.rm = TRUE`)." When `na.rm = FALSE`, `active_mask` includes NA rows in `x` or `by`.

The problem: `survey_glm()` uses R's default `na.action = na.omit`, so it silently drops NA rows
regardless of `na.rm`. Then step 9.f computes `n_a`, `n_b` as "unweighted in-mask counts per
active level" — from `active_mask`, not from the GLM's effective rows. So `na.rm = FALSE` with
NAs in `x` will:
- Produce GLM estimates that exclude NA rows (via `na.omit`)
- Report `n_a`/`n_b` that include NA rows (inflated counts)
- Look identical to `na.rm = TRUE` for estimates but differ for cell counts

The §VI edge case only tests `na.rm = FALSE` when `x` has no NAs (safe case). The NA case is
not tested, so the over-count would go undetected.

Options:
- **[A]** Clarify in §3.6 step 9.a: "When `na.rm = FALSE`, `active_mask` still excludes rows
  where `x` or `by` is NA (NA outcome and NA group indicator are not meaningful for the GLM).
  `na.rm = FALSE` only affects NA rows in `group` variables (see §3.5). Step 9.f computes
  `n_a`/`n_b` from the same mask, so counts are always consistent with the GLM." Align the
  §VI edge case test to verify count consistency. — Effort: low, Risk: low, Impact: removes
  the over-count bug and aligns spec with actual GLM behavior, Maintenance: none
- **[B]** Accept that `na.rm = FALSE` allows NAs to reach `survey_glm()`, note that GLM
  drops them, and compute `n_a`/`n_b` from the GLM's model frame (i.e., after `na.omit`
  is applied) rather than from `active_mask`. — Effort: medium, Risk: low, Impact: accurate
  cell counts, Maintenance: requires accessing GLM's internal model frame
- **[C] Do nothing** — The tested case (`na.rm = FALSE`, no NAs) always passes; the edge
  case is unlikely.

**Recommendation: [A]** — Option A is the cleanest fix: `na.rm` for `x` and `by` is
effectively always `TRUE` (the GLM demands complete cases), and only `na.rm = FALSE` for
`group` variables has meaningful behavioral effect. Document this explicitly.

---

**Issue 18: `by` coercion warning scope — integer and logical columns not addressed**
Severity: REQUIRED
Violates Contract Completeness (Lens 3)

§3.4 step 2 says: "Integer and logical columns are also accepted and coerced to factor."
T-2 in §V is defined as: condition "by is character — coerced to factor", class
`surveycore_warning_by_coerced`, message "`{by_name}` coerced to factor. Level order: `{levels}`."

The spec describes two different coercions (character→factor with a warning; integer/logical→factor
without specifying a warning), but only one error table row. An implementer must guess:
- Does integer/logical coercion also trigger `surveycore_warning_by_coerced`? If yes, the T-2
  condition is wrong (should say "non-factor, non-ordered" not "character").
- If no, the spec should say so explicitly ("integer and logical are silently coerced").

Options:
- **[A]** Expand T-2 to cover all non-factor coercions: change condition to "by is character,
  integer, or logical — coerced to factor." Update §3.4 step 2 to say all three trigger T-2.
  — Effort: low, Risk: low, Impact: consistent warning behavior across input types, Maintenance: none
- **[B]** Keep T-2 as character-only. Add to §3.4 step 2: "Integer and logical columns are
  silently coerced to factor (no warning)." — Effort: low, Risk: low, Impact: reduces warning
  noise for structured factor-like inputs, Maintenance: none
- **[C] Do nothing** — Implementers will choose one of the two interpretations independently.

**Recommendation: [A]** — Warning the user when `by` is coerced is always safer; integer and
logical grouping variables are equally non-obvious choices. Silently coercing them would hide
potential mistakes (e.g., a user accidentally passing a numeric scale variable as `by`).

---

#### Section: IV — `get_pairwise()` Specification (§4.5)

**Issue 19: `domain_mask` used in §4.5 step 5 before it is defined in the execution flow**
Severity: REQUIRED
Violates Contract Completeness (Lens 3) and engineering-preferences.md §5 (explicit over clever)

§4.5 step 5 computes active levels as:
```r
levels(by_col)[tabulate(by_col[domain_mask]) > 0]
```

`domain_mask` is referenced here but no preceding step in §4.5 defines it. The pattern across
every other analysis function in the codebase (`get_means()`, `get_freqs()`, `get_diffs()`,
etc.) is to call `domain_mask <- .apply_domain(design)` as an early explicit step before the
loop. §4.3 mentions `.apply_domain(design)` in its pair-enumeration description, but the
execution flow (§4.5) does not have a corresponding step.

Without an explicit step, an implementer could:
- Forget to call `.apply_domain()` and use a bare `rep(TRUE, nrow(design@data))` instead
  (wrong for domain-filtered designs)
- Call it in the wrong place (inside the loop, recalculating it k(k−1)/2 times unnecessarily)

Options:
- **[A]** Insert a new step 5a in §4.5 (after step 4, before the active-level check):
  "Compute domain mask: `domain_mask <- .apply_domain(design)`." — Effort: low, Risk: low,
  Impact: consistent with all other analysis functions, Maintenance: none
- **[C] Do nothing** — `domain_mask` appears in §4.3 which a careful implementer will read.

**Recommendation: [A]** — One line; every other analysis function has this explicit step.

---

#### Section: III — `get_t_test()` Specification (§3.5) and §4.5

**Issue 20: NA group strata: §3.5 describes behavior that §3.6 does not implement**
Severity: REQUIRED
Violates Contract Completeness (Lens 3)

§3.5 states:
> "Stratum ordering: Group strata appear in ascending order of group variable values
> (non-NA first, NA strata last if `na.rm = FALSE`)."

This implies that when `na.rm = FALSE`, rows where `group` is NA form their own stratum and a
t-test is run for them. But §3.6 execution flow has no step that:
- Passes `na.rm` to `.build_group_combos()` to signal whether NA strata should be included
- Explains what the "NA stratum" t-test would mean (rows where `group` is `NA`, comparing `by` levels)
- Says whether NA group rows are excluded from all other strata when `na.rm = TRUE`

The execution flow is incomplete: the described behavior in §3.5 has no corresponding implementation
path in §3.6.

Options:
- **[A]** Simplify §3.5: replace "NA strata last if `na.rm = FALSE`" with "Rows where any
  `group` variable is NA are excluded from all strata regardless of `na.rm`." Align with
  the existing behavior of other `get_*()` functions (which exclude NA group rows). — Effort:
  low, Risk: low, Impact: removes an unimplemented feature from the spec, Maintenance: none
- **[B]** Implement NA group strata: update §3.6 to say that when `na.rm = FALSE`,
  `.build_group_combos()` includes an NA stratum, and document what `NA` group values mean
  in the output. — Effort: high, Risk: medium, Impact: feature completeness for panel data
  edge cases, Maintenance: requires NA-stratum handling in `.build_group_combos()`
- **[C] Do nothing** — The §3.5 sentence is descriptive flavor; implementers will follow §3.6.

**Recommendation: [A]** — The "NA strata" behavior appears nowhere else in the spec (no test
coverage, no error class, no output contract). Remove the implied feature and simplify.
Option B is a real feature that deserves its own spec section if wanted.

---

#### Section: VI — Testing Requirements

**Issue 21: Domain estimation (test category 4) absent from test plan**
Severity: REQUIRED
Violates testing-standards.md §2 (category 4: domain estimation)

§V explicitly references the domain-estimation scenario: "`surveycore_error_empty_domain`
propagates from `survey_glm()` when a `surveytidy::filter()`-narrowed design combined with
`active_mask` leaves 0 in-domain rows." The function is designed to work with domain-filtered
designs (§4.3 documents the domain-mask composition). Yet §VI has no test for domain estimation
— no test block runs `get_t_test()` or `get_pairwise()` on a design that has a prior domain
mask set via `surveytidy::filter()`.

This is test category 4 (domain estimation) per the project testing standard.

Options:
- **[A]** Add to §VI Edge Cases:
  "- [ ] Domain-filtered design: a design with a prior domain mask (from `surveytidy::filter()`)
  produces the same estimate as running on the physically subsetted data, for both
  `get_t_test()` and `get_pairwise()`."
  — Effort: low, Risk: low, Impact: closes category 4 gap, Maintenance: none
- **[C] Do nothing** — Domain behavior is inherited from `survey_glm()` and tested there.

**Recommendation: [A]** — The project standard requires category 4 coverage for every exported
analysis function that accepts design objects. The domain composition in `get_pairwise()` adds
a layer on top of `survey_glm()`'s domain handling that warrants its own test.

---

#### Section: III — `get_t_test()` Specification (§3.1) / VI — Testing

**Issue 22: `min_cell_n` not validated and acceptable range not defined**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle edge cases)

`min_cell_n` has no validation step in §3.6 and no error class in §V. The spec says
`min_cell_n = 0L` suppresses the small-cell warning (§VI edge case). But:
- `min_cell_n = -5L` also suppresses the warning (silently, since `n < -5` is never true)
- `min_cell_n = 1.5` (non-integer double) would produce a non-obvious comparison

No test covers `min_cell_n` with an out-of-range value, and no error fires.

Options:
- **[A]** Add a sentence to §3.6 step 2 (shared-args validation): "Validate `min_cell_n` is
  a non-negative integer (coerce to integer if double with no fractional part; error otherwise:
  `surveycore_error_invalid_min_cell_n`)." Add the error class to §V reused classes table or
  as a new row. — Effort: low, Risk: low, Maintenance: new error class to maintain
- **[B]** Document explicitly: "`min_cell_n` is not validated; negative values silently
  suppress the warning. Users should use `min_cell_n = 0L` to suppress." — Effort: low,
  Risk: low, Impact: removes ambiguity at the cost of not guarding a foot-gun, Maintenance: none
- **[C] Do nothing** — `min_cell_n = 0L` is the documented suppression mechanism; abusing
  negative values is an unlikely mistake.

**Recommendation: [B]** — Consistent with how some other optional threshold arguments work in
R. Documenting the intentional behavior is better than leaving it implicit, and adding a new
error class for a SUGGESTION-level issue adds maintenance overhead.

---

**Issue 23: `broom` test plan misses `df` → `parameter` rename**
Severity: SUGGESTION
Violates Test Completeness (Lens 2)

The existing `.apply_name_style()` broom map (confirmed) includes `df = "parameter"`. When
`name_style = "broom"`, the output column `df` is renamed to `parameter`. The §VI test for
broom mode says:

> "surveycore column names (`se`, `ci_low`, `ci_high`) are absent"

It does not check that `df` is absent and `parameter` is present. A test written from this
description would miss this rename and would not catch a regression if the `df` → `parameter`
mapping were removed from `.apply_name_style()`.

Options:
- **[A]** Update the §VI broom test bullet: "surveycore column names (`se`, `ci_low`, `ci_high`,
  `df`) are absent; broom names (`std.error`, `conf.low`, `conf.high`, `parameter`) are
  present." — Effort: low, Risk: low, Maintenance: none
- **[C] Do nothing** — The test will at least catch the `se`/`ci_low`/`ci_high` renames;
  the `df` → `parameter` rename is covered by `.apply_name_style()` unit tests elsewhere.

**Recommendation: [A]** — One additional clause; prevents silent regression.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 2 |

**Total new issues:** 8

**New issue index:**

| # | Section | Title | Severity |
|---|---|---|---|
| 16 | §3.6/§VI | `broom` name_style — `df`→`parameter` undocumented; `t_stat` fate unaddressed | REQUIRED |
| 17 | §3.6 | `na.rm = FALSE` with NAs in `x`/`by` — `n_a`/`n_b` over-count bug | REQUIRED |
| 18 | §3.4/§V | `by` coercion warning scope — integer/logical not addressed | REQUIRED |
| 19 | §4.5 | `domain_mask` used in step 5 before being defined | REQUIRED |
| 20 | §3.5/§3.6 | NA group strata: described in §3.5 but absent from §3.6 execution flow | REQUIRED |
| 21 | §VI | Domain estimation (test category 4) absent from test plan | REQUIRED |
| 22 | §3.1/§3.6 | `min_cell_n` not validated; acceptable range undefined | SUGGESTION |
| 23 | §VI | Broom test plan misses `df`→`parameter` rename | SUGGESTION |

**Overall assessment:** All 15 Pass 1 issues are cleanly resolved — the spec is significantly
stronger. The remaining 6 required issues are narrower in scope: two are execution-flow gaps
(Issues 19, 20), two are behavioral definition gaps (Issues 17, 18), one is an API-contract
gap in the shared `broom` mapping (Issue 16), and one is a missing test category (Issue 21).
None are blocking. The spec can proceed to Stage 4 resolution; Issues 19 and 20 are the
highest priority as they involve incomplete or contradictory execution-flow steps.
