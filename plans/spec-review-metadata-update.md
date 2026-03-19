## Spec Review: metadata-update — Pass 1 (2026-03-10)

### New Issues

#### Section: III. Architecture / Internal Helpers

---

**Issue 1: `.parse_setter_input()` cannot simultaneously detect the old positional form (requires quosures) and check Convention 2 content types (requires evaluated values)**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever); creates an unresolvable implementation ambiguity.

Section 8.3 specifies old positional form detection via:
```r
rlang::is_symbol(rlang::quo_get_expr(dots[[1L]]))
```
This requires `dots` to be a list of **unevaluated quosures** (captured with `rlang::enquos(...)`). But Convention 2 detection (Section 4.1) checks whether `dots[[1L]]` is a named character vector or named list — which requires **evaluated values** (captured with `rlang::list2(...)`). These two strategies are mutually exclusive: a quosure is not the evaluated value; an evaluated value has lost the symbol information needed for the old positional form check.

The spec says `.parse_setter_input()` handles both, but does not resolve how.

Options:
- **[A]** Move old positional form detection to the caller (each setter) before invoking `.parse_setter_input()`, using `rlang::enquos(...)` at the setter level. `.parse_setter_input()` receives only evaluated values via `rlang::list2(...)`. — Effort: low, Risk: low, Impact: cleaner separation of concerns, Maintenance: low
- **[B]** Pass both a quosures list AND an evaluated list to `.parse_setter_input()`, increasing its parameter count. — Effort: low, Risk: medium (complex signature), Impact: single entry point for all detection, Maintenance: medium
- **[C] Do nothing** — implementer must guess the capture strategy; whichever they choose silently breaks either Convention 2 or old-form detection.

**Recommendation: [A]** — separates NSE symbol detection (caller concern) from value parsing (shared helper concern). Clean, explicit, and keeps `.parse_setter_input()` free of quosure mechanics.

---

**Issue 2: `.parse_setter_input()` has no mechanism to discriminate Convention 2 content type between scalar-content and list-content setters**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

Convention 2 detection differs fundamentally by setter type:
- For `set_var_label()`, `set_question_preface()`, `set_var_note()`, `set_universe()`: Convention 2 is a single unnamed element in `...` that is a named **character vector**.
- For `set_val_labels()`, `set_missing_codes()`: Convention 2 is a single unnamed element in `...` that is a named **list**.

The spec calls `.parse_setter_input()` a "shared" helper for all six setters but provides no parameter to communicate which content type to expect. Without this, Convention 2 detection for `set_val_labels(svy, list(...))` is indistinguishable from a list accidentally passed to `set_var_label()`. The helper cannot correctly validate Convention 2 without knowing the expected content type.

Options:
- **[A]** Add a `content_type` parameter to `.parse_setter_input()` accepting `"scalar"` or `"vector"`. Convention 2 detection branches on this value. — Effort: low, Risk: low, Impact: fully specifies the helper's contract, Maintenance: low
- **[B]** Remove Convention 2 detection from `.parse_setter_input()` and handle it in each setter individually. `.parse_setter_input()` handles only Convention 1 and 3. — Effort: low, Risk: low, Impact: slightly less shared code, Maintenance: low
- **[C] Do nothing** — implementer guesses; Convention 2 for `set_val_labels()` likely broken or inconsistent.

**Recommendation: [A]** — minimal change, fixes the gap explicitly.

---

**Issue 3: `.resolve_vars_from_x()` in the helpers list (Section 3.2 opening) vs `.resolve_vars()` in the detailed spec below it — same helper, two different names**
Severity: REQUIRED
Violates contract completeness; creates ambiguity about which name to implement.

Section 3.2's opening table lists `.resolve_vars_from_x()`. The detailed spec block at the bottom of Section 3.2 defines `.resolve_vars()` with a different signature. These are the same helper. The implementation would have to pick one arbitrarily.

Options:
- **[A]** Fix the opening table to say `.resolve_vars()`, matching the detailed spec. — Effort: trivial, Risk: none
- **[C] Do nothing** — implementer names it one or the other; the other name ends up as a dead reference.

**Recommendation: [A]**

---

**Issue 4: `.resolve_vars()` takes both `x` and `all_cols` but `all_cols` is derivable from `x` via `.get_data_cols(x)` — redundant parameter**
Severity: REQUIRED
Violates DRY (engineering-preferences.md §1).

The spec defines `.get_data_cols(x)` which returns `names(x)` for data frames and `names(x@data)` for survey objects. Then `.resolve_vars()` takes both `x` (for "data-masking context") and `all_cols` (already computable from `x`). The spec does not explain why `x` is needed separately — if data-masking means evaluating bare names against the data, the data is in `x@data`, not in `x` directly. Passing `all_cols` as a pre-computed vector when `x` is also available is redundant.

Options:
- **[A]** Remove `all_cols` from `.resolve_vars()`; compute it internally via `.get_data_cols(x)`. — Effort: trivial, Risk: low
- **[B]** Remove `x` and keep `all_cols`; document that callers compute `all_cols = .get_data_cols(x)` before the call. — Effort: trivial, Risk: low
- **[C] Do nothing** — both parameters remain; implementations pass both redundantly.

**Recommendation: [A]** — `x` is already available; `.get_data_cols(x)` is a one-liner call.

---

#### Section: IV. Setter API

---

**Issue 5: `.check_is_survey()` becomes dead code in `core-metadata.R` but disposition is unresolved**
Severity: REQUIRED

Section 3.2 says: "The old `.check_is_survey()` is retained for functions that intentionally do NOT accept data frames (none in this spec — all functions gain data frame support). If `.check_is_survey()` is still referenced elsewhere in the codebase, it is not removed."

There are no such functions in this spec. The current `core-metadata.R` has 8 call sites for `.check_is_survey()`, all of which are being replaced. After this spec is implemented, `.check_is_survey()` in `core-metadata.R` will have zero callers within that file. The spec doesn't specify:
- Whether to remove it from `core-metadata.R` or keep a dead helper
- Whether it exists elsewhere in the codebase (it may be used by `infer_question_prefaces()` or other functions)

An implementer searching for other callers and finding none would be left guessing whether to delete it.

Options:
- **[A]** Add explicit instruction: "Search the codebase for other `.check_is_survey()` call sites before implementation. If none exist outside `core-metadata.R`, remove it from `core-metadata.R`. If call sites exist elsewhere, leave it in place." — Effort: trivial, Risk: none
- **[C] Do nothing** — dead helper likely remains; or implementer accidentally deletes it and breaks callers elsewhere.

**Recommendation: [A]**

---

**Issue 6: Convention 1 with mixed named and unnamed `...` args — no error class specified**
Severity: REQUIRED

Section 4.1 says Convention 1 requires all elements named ("`rlang::list2(...)` produces a non-empty named list (all elements named)"). But a call like `set_var_label(svy, age = "Age", "orphan string")` produces a partially-named list. This doesn't match Convention 1 (not all named), Convention 2 (not a single unnamed element), or Convention 3 (`variable` is NULL). The error table (Section IX) has no class for this case. Without an explicit error class, the implementer doesn't know whether to raise `surveycore_error_setter_empty` (wrong — some input is present), `surveycore_error_setter_ambiguous` (wrong — no `variable` was set), or a new class.

Options:
- **[A]** Treat mixed named/unnamed `...` as a new detectable case in `.parse_setter_input()` with its own error class `surveycore_error_setter_mixed_dots`. Add to Section IX and `plans/error-messages.md`. — Effort: low, Risk: low
- **[B]** Re-use `surveycore_error_setter_empty` with message: "All `...` arguments must be named when using Convention 1." Describe this in `.parse_setter_input()` spec. — Effort: trivial, Risk: low (slightly misleading class name)
- **[C] Do nothing** — implementer guesses; likely raises a confusing error or silently drops the unnamed element.

**Recommendation: [A]** — clean error class for an easily-triggerable misuse.

---

**Issue 7: `NULL` content in `.parse_setter_input()` return value is unspecified**
Severity: REQUIRED

Section 4.3 says "`NULL` label removes an existing label entry (same as deleting the key from the named list)." This requires `.parse_setter_input()` to pass `NULL` values through in the returned named list. But the helper spec says "Returns a named list where names are variable name strings and values are the content to set" without specifying what `NULL` content means or how it's represented. Questions:
- Does `list(age = NULL)` in the returned list mean "delete this key"?
- Can `.parse_setter_input()` return a list with NULL values from Convention 3 (`variable = c("age", "income"), label = c("Age", NULL)`)? — that's not a valid character vector in R anyway.
- What about Convention 1: `set_var_label(svy, age = NULL)`? Is this valid?

Options:
- **[A]** Specify explicitly: `.parse_setter_input()` allows `NULL` values in the returned list. Each setter iterates the result; a `NULL` value means "delete the key from the metadata list." Document this in the helper spec. — Effort: low, Risk: low
- **[C] Do nothing** — setter implementations differ on whether NULL deletes or errors.

**Recommendation: [A]**

---

#### Section: V. Extractor API

---

**Issue 8: The test plan contradicts the output contract: Section 10.6 claims single-variable calls return a scalar, but the output contract specifies named_vector format returning a named vector**
Severity: BLOCKING
Breaks backward compatibility and creates an unresolvable contradiction within the spec itself.

Section 10.6 test plan states:
> "Happy path — single variable (backward compatibility): `extract_var_label(svy, age)` returns the label string (or `NULL`)"

But Section 5.2 output contract states:
> "`\"named_vector\"`: `c(age = \"Age in years\", income = \"Annual income\")` — named character vector"

With `format = "named_vector"` (the default), `extract_var_label(svy, age)` returns `c(age = "Age in years")` — a named character vector of length 1. This is **not** the same as `"Age in years"` (a plain character scalar):
- `identical(c(age = "Age in years"), "Age in years")` → `FALSE`
- Code doing `if (extract_var_label(svy, age) == "Age in years")` still works (R coerces), but `switch()`, `match()`, and `identical()` calls break silently.

The same contradiction applies to `extract_val_labels()`: old API returns `c(Male = 1L, Female = 2L)` directly; new API with default `format = "list"` returns `list(sex = c(Male = 1L, Female = 2L))`. The test plan says "behavior identical to old API" — but a list is fundamentally not a named vector.

The spec cannot simultaneously claim backward compatibility AND return named-vector/list format by default. One must give.

Options:
- **[A]** Remove the backward compatibility claim from Section 10.6. Explicitly document these as breaking changes in NEWS.md (alongside the old positional setter form). Update Section 10.6 to test the new return types. — Effort: low, Risk: low (changes are well-defined), Impact: honest spec, Maintenance: low
- **[B]** Add a new format option `"scalar"` that returns a plain character scalar for single-variable calls when exactly one variable is requested. Set `format = "scalar"` as a fourth option, but keep `"named_vector"` as the default for multi-variable calls. — Effort: medium, Risk: medium (complex conditional), Maintenance: medium
- **[C] Do nothing** — test will fail; implementer is forced to choose. Backward compat is implicitly broken without a NEWS.md entry.

**Recommendation: [A]** — honest and simple. Both extractors are already changing signatures substantially; acknowledge the break, document it, and move on.

---

#### Section: VII. Data Frame Support

---

**Issue 9: Round-trip test in Section 7.5 and Section 10.5 missing two of the six metadata fields**
Severity: REQUIRED

Section 7.5 explicitly tests the round-trip guarantee for 4 of 6 fields: `variable_labels`, `value_labels`, `universe`, `missing_codes`. The `question_prefaces` and `notes` fields are omitted from:
- The round-trip code block in Section 7.5
- The "Round-trip" test bullets in Section 10.5 ("set on df → `as_survey()` → extract from survey object (one block per field)")

The spec says `.extract_haven_metadata()` already reads `"question_preface"` and the `"note"` attribute isn't listed in `.extract_haven_metadata()`'s current behavior (the code reads `"label"`, `"labels"`, `"question_preface"` but not `"note"`). If `note` round-trips are not tested, a silent failure in `.extract_haven_metadata()` won't be caught.

Options:
- **[A]** Add `set_var_note()` and `set_question_preface()` to the Section 7.5 round-trip code example and to Section 10.5's round-trip block list. Verify Section 7.3 specifies that `.extract_haven_metadata()` reads `"note"` attributes too. — Effort: trivial, Risk: none
- **[C] Do nothing** — round-trip for notes and prefaces is untested; silent regression is possible.

**Recommendation: [A]**

---

#### Section: VIII. Deprecations

---

**Issue 10: Existing tests use `surveycore_error_not_survey` but the new `.check_is_survey_or_df()` uses `surveycore_error_not_survey_or_df` — no test migration path specified**
Severity: REQUIRED

The existing `core-metadata.R` uses `.check_is_survey()` which raises `surveycore_error_not_survey`. The new spec replaces all call sites with `.check_is_survey_or_df()` which raises `surveycore_error_not_survey_or_df`. Any existing test in `test-metadata-system.R` that asserts `class = "surveycore_error_not_survey"` will fail after implementation.

The spec correctly identifies `surveycore_error_not_survey_or_df` as the class to use (confirmed in error-messages.md row 78) but does not mention that existing tests need to be updated.

Options:
- **[A]** Add a note in Section 10.3 or Section XI quality gates: "All existing `expect_error(class = \"surveycore_error_not_survey\")` assertions in `test-metadata-system.R` must be updated to `\"surveycore_error_not_survey_or_df\"`." — Effort: trivial, Risk: none
- **[C] Do nothing** — implementer discovers test failures; no guidance on what to do.

**Recommendation: [A]**

---

#### Section: X. Testing Plan

---

**Issue 11: No test specified for `NULL` content removing a metadata entry**
Severity: REQUIRED

Section 4.3 specifies: "`NULL` label removes an existing label entry (same as deleting the key from the named list)." The same behavior is specified for `set_val_labels()`, `set_question_preface()`, `set_var_note()`, `set_universe()`, and `set_missing_codes()`. However, Section 10.5 has no test block for "set content to NULL removes the entry." Without this test, the deletion behavior could silently store `NULL` in the metadata list instead of removing the key.

Options:
- **[A]** Add to Section 10.5 happy path blocks: "Setting `NULL` content removes the existing entry (verify with `is.null(x@metadata@variable_labels[['age']])` and `!('age' %in% names(x@metadata@variable_labels))`)." One block per setter type (scalar-content setters share a template; list-content setters share another). — Effort: low, Risk: none
- **[C] Do nothing** — deletion behavior is untested; NULL-stores-rather-than-deletes bugs survive.

**Recommendation: [A]**

---

#### Section: General / Cross-Cutting

---

**Issue 12: `fill = NA_character_` has three different runtime behaviors across formats — asymmetry is not prominently documented**
Severity: SUGGESTION
Violates API Coherence (Lens 6): same input, three different behaviors depending on `format`.

Section 5.1 says:
- `"named_vector"` + `fill = NA_character_` → value is `NA_character_`
- `"list"` + `fill = NA_character_` → value is `NULL` (not `NA_character_`)
- `"data_frame"` + `fill = NA_character_` → value is `NA` in the column

A user who reads `fill = NA_character_` as "include missing variables as NA" will be surprised to receive `NULL` in list format. This asymmetry is technically correct (NA is meaningless as a list entry for vector fields) but will cause user confusion.

Options:
- **[A]** Add a note box in Section 5.1 under the `fill` table: "Note: `fill = NA_character_` in `"list"` format yields `NULL` entries (not `NA`), because `NA` has no meaningful interpretation as a placeholder for a named vector field." — Effort: trivial
- **[C] Do nothing** — users discover the asymmetry from behavior or buried table row.

**Recommendation: [A]**

---

**Issue 13: `extract_metadata()` always returns all variables (no `fill` argument) while all other extractors filter by default — asymmetry is not justified in the spec**
Severity: SUGGESTION

Section 5.1 default for extractors: `fill = NULL` → omit variables with no metadata. Section 6.3 for `extract_metadata()`: always includes all variables, no `fill` argument. This means a survey object with 80 columns and 5 labeled variables produces:
- `extract_var_label(svy)` → 5-element result
- `extract_metadata(svy)` → 80-element result (75 with all-NULL fields)

The spec justifies this as "a complete inventory of the design's variables, not just those with metadata" (Section 6.3) — but doesn't explain why a user building a codebook would want to process 75 all-NULL entries. The design choice may be correct but should be justified explicitly to prevent an implementer from adding a `fill` argument "for consistency."

Options:
- **[A]** Add one sentence to Section 6.1 or 6.3: "The always-include design is intentional — `extract_metadata()` is a structural audit function, not a filtered view. Users who want only annotated variables should use individual extractors with `fill = NULL`." — Effort: trivial
- **[C] Do nothing** — the current spec is technically complete; this is a clarity improvement.

**Recommendation: [A]**

---

**Issue 14: Examples throughout the spec use `nhanes_2017`, violating the CLAUDE.md convention requiring GSS dataset**
Severity: SUGGESTION

`CLAUDE.md` states: "Use the GSS dataset (not NHANES or gss_2024) for examples and tests unless told otherwise." Section 6.5, the `make_labeled_design()` helper (Section 10.9), and several inline examples reference `nhanes_2017`. While the spec is a planning document (not the roxygen source), the Section 6.5 example will likely be copied verbatim into roxygen `@examples` blocks during implementation. The CLAUDE.md convention should be respected here.

Options:
- **[A]** Update Section 6.5 console output example to use `gss_2022` (or the canonical GSS dataset). Note in Section 10.9 that `make_labeled_design()` uses `make_survey_data()` (synthetic) rather than NHANES. — Effort: low
- **[C] Do nothing** — implementer must remember to swap datasets; easy to overlook under time pressure.

**Recommendation: [A]**

---

**Issue 15: Warning tests specified with `class + result check` but testing-standards.md requires dual pattern (class + snapshot) for user-facing warnings**
Severity: SUGGESTION

Section 10.5 specifies for `surveycore_warning_var_not_found`:
> "Variable not in data → `surveycore_warning_var_not_found` (class + result check)"

`testing-standards.md` states the dual pattern (class= + snapshot) is required for constructor errors and should apply to all user-facing diagnostic messages. The snapshot captures the exact warning text so unintentional message changes are caught in CI. The spec's "class + result check" omits the snapshot half. For a warning that will be triggered frequently in real workflows, snapshot coverage is appropriate.

Options:
- **[A]** Change to "class + snapshot" for all `surveycore_warning_var_not_found` tests, consistent with warning testing patterns for all other warning classes. — Effort: trivial
- **[C] Do nothing** — warning message text can change without failing tests; CI won't catch regressions.

**Recommendation: [A]**

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 7 |
| SUGGESTION | 4 |

**Total issues:** 15

**Overall assessment:** The spec is thorough and well-structured, but has four blocking issues that must be resolved before implementation: (1) a direct contradiction between the test plan's "backward compatible scalar return" claim and the output contract's named-vector/list formats for all four existing extractors; (2–3) two unresolved implementation ambiguities in the shared `.parse_setter_input()` helper around quosure capture strategy and Convention 2 content-type discrimination; and (4) a name inconsistency between helper spec entries. Resolving these will produce an implementable spec with no architectural guesses required.

---

## Spec Review: metadata-update — Pass 2 (2026-03-10)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.parse_setter_input()` quosure vs. evaluated list capture conflict | ✅ Resolved |
| 2 | `.parse_setter_input()` no `content_type` parameter for Convention 2 discrimination | ✅ Resolved |
| 3 | `.resolve_vars_from_x()` vs `.resolve_vars()` name inconsistency | ✅ Resolved |
| 4 | `.resolve_vars()` redundant `all_cols` parameter | ✅ Resolved |
| 5 | `.check_is_survey()` dead code disposition unresolved | ✅ Resolved |
| 6 | Convention 1 with mixed named/unnamed `...` — no error class | ✅ Resolved |
| 7 | `NULL` content in `.parse_setter_input()` return value unspecified | ✅ Resolved |
| 8 | Test plan contradicts output contract: scalar return vs. named-vector | ✅ Resolved |
| 9 | Round-trip test missing `question_prefaces` and `notes` fields | ✅ Resolved |
| 10 | Test migration: `surveycore_error_not_survey` → `surveycore_error_not_survey_or_df` not noted | ✅ Resolved |
| 11 | No test for `NULL` content removing a metadata entry | ✅ Resolved |
| 12 | `fill = NA_character_` asymmetry across formats undocumented | ✅ Resolved |
| 13 | `extract_metadata()` always-include vs. other extractors asymmetry unjustified | ✅ Resolved |
| 14 | Examples use `nhanes_2017`, violating CLAUDE.md GSS convention | ✅ Resolved |
| 15 | Warning tests missing snapshot half | ✅ Resolved |

All 15 Pass 1 issues are resolved. The spec has been substantially improved. Pass 2 finds the following new issues.

---

### New Issues

#### Section: III. Architecture / Internal Helpers

---

**Issue 16: Section 8.3 says "each setter" does enquos capture for old-positional-form detection, but only `set_var_label()` has the M-11 error — creates five setters with unnecessary quosure overhead and a cross-reference contradiction**
Severity: REQUIRED
Violates engineering-preferences.md §3 (right level of engineering) and contract completeness.

Section 8.3 states: "Each setter captures `...` as quosures via `rlang::enquos(...)` **before** evaluating them, and checks for the old positional form at the top of the function body." But M-11 in Section IX says "Function(s): `set_var_label()`" — not all setters. Section 10.5 confirms: "Old positional NSE form → `surveycore_error_old_positional_setter` (class + snapshot) [set_var_label only]."

The contradiction: if all six setters perform `rlang::enquos(...)` capture and then check for the old positional form, five of them will never trigger M-11 (the old form was specific to `set_var_label(svy, age, "label")`). The spec gives no reason why `set_val_labels()`, `set_question_preface()`, `set_var_note()`, `set_universe()`, and `set_missing_codes()` need quosure capture — none had an old positional form with a bare symbol + scalar string signature. An implementer reading Section 8.3 literally would add unnecessary `rlang::enquos()` calls and dead detection branches to five functions.

Additionally, Section 4.3 "Error / warning rows" lists M-1, M-3, M-4, M-5, M-7 but omits M-11, even though M-11 is specific to `set_var_label()`. This is a cross-reference bug.

Options:
- **[A]** Rewrite Section 8.3 to say: "Only `set_var_label()` performs the old positional form check using `rlang::enquos(...)`. The other five setters skip this check and evaluate `...` directly via `rlang::list2(...)`. The detection condition applies exclusively to `set_var_label()`." Add M-11 to Section 4.3's error row list. — Effort: trivial, Risk: none, Impact: removes ambiguity, Maintenance: low
- **[C] Do nothing** — five setters acquire needless quosure boilerplate; or implementer skips it for all setters and misses the detection in `set_var_label()` too.

**Recommendation: [A]**

---

**Issue 17: `.parse_setter_input()` is missing a `fn_name` parameter required for M-4 and M-12 error message interpolation**
Severity: REQUIRED
Violates contract completeness; M-4 and M-12 cannot be implemented without it.

M-4 template: `"x" = "{.fn {fn_name}} requires at least one variable-label pair."` M-12 template: `"v" = "Use {.code {fn_name}(x, age = 'Age', income = 'Annual income')} or a fully named vector."`

Both use `{fn_name}` — the name of the calling setter function (e.g., `"set_var_label"`, `"set_missing_codes"`). But the `.parse_setter_input()` signature is:
```r
.parse_setter_input(dots, variable, content, content_arg_name, content_type, call)
```
There is no `fn_name` parameter. The helper has no way to produce the correct message text for M-4 or M-12 unless the caller passes its name. `sys.call()` inside the helper would return `.parse_setter_input()` itself, not the setter's name.

Options:
- **[A]** Add `fn_name` as a parameter to `.parse_setter_input()`. Each setter passes its own name as a string: `fn_name = "set_var_label"`. — Effort: trivial, Risk: none
- **[B]** Use `rlang::caller_env()` plus `rlang::call_name(rlang::sys_call(-1L))` to recover the caller name dynamically. — Effort: low, Risk: medium (fragile with non-standard call stacks)
- **[C] Do nothing** — M-4 and M-12 messages either omit the function name (wrong) or fail to interpolate (runtime error).

**Recommendation: [A]** — explicit, zero risk, one extra parameter.

---

#### Section: IV. Setter API

---

**Issue 18: `set_var_note()` and `set_universe()` are missing content validation rules — non-character inputs have undefined behavior**
Severity: REQUIRED
Violates contract completeness; `code-style.md` §3 requires all edge case behaviors explicitly defined.

`set_var_label()` (Section 4.3) says: "Each label value must be a single character string. Non-character or length > 1 values are coerced with a warning (using `as.character()`)." `set_question_preface()` (Section 4.5) says: "Each preface value must be a single character string." But `set_var_note()` (Section 4.6) and `set_universe()` (Section 4.7) have no equivalent validation rule. Their behavior rules say only `NULL` removes the entry and missing-variable warns.

Without a rule, `set_var_note(svy, income = 42L)` or `set_universe(svy, age = c("Adults 18+", "Extra string"))` have undefined behavior. Will it error? Coerce silently? Store a non-character value in metadata?

Additionally, `set_question_preface()` (4.5) says "must be a single character string" but gives no behavior for violation (error? coerce?). This is inconsistent with `set_var_label()` which specifies coercion. All four scalar-content setters should have the same validation rule — the spec should state it once in Section 4.1 under unified calling convention, not per-function, or at minimum add it to Sections 4.5, 4.6, and 4.7.

Options:
- **[A]** Add a unified validation rule to Section 4.1: "For scalar-content setters (`set_var_label`, `set_question_preface`, `set_var_note`, `set_universe`): each content value must be a character scalar. Non-character values are coerced via `as.character()` with a `surveycore_warning_label_coerced` warning. Vectors of length > 1 are rejected with `surveycore_error_label_not_scalar`." Remove the per-function restatements. — Effort: low, Risk: low
- **[B]** Add the missing rule only to 4.6 and 4.7; leave 4.3 and 4.5 as-is. — Effort: trivial, Risk: low (duplication persists but gaps are closed)
- **[C] Do nothing** — `set_var_note()` and `set_universe()` have undefined behavior for non-character input; tests cannot assert on it.

**Recommendation: [A]** — DRY, complete, and fixes a latent ambiguity in 4.5 too.

---

**Issue 19: `set_var_label()` content coercion warning has no error class defined in Section IX — violates `code-style.md` §3**
Severity: REQUIRED
Violates code-style.md §3: "class= is required on every `cli_warn()` call — no exceptions."

Section 4.3 states: "Non-character or length > 1 values are coerced with a warning (using `as.character()`)." But Section IX has no warning class for this coercion. Without a class:
1. The `cli_warn()` call cannot be written (code-style.md requires `class=`)
2. No `expect_warning(class = ...)` test can be written (testing-standards.md requires class-matched assertions)
3. "length > 1 coerced" is semantically ambiguous — `as.character(c("label1", "label2"))` produces `c("label1", "label2")`, not a scalar. The spec doesn't say whether "coercion" means collapse (`paste0()`), take first (`[[1L]]`), or error.

Options:
- **[A]** Add two rows to Section IX: `surveycore_warning_label_content_coerced` (for non-character → character coercion) and `surveycore_error_label_not_scalar` (for length > 1 content — which cannot be meaningfully coerced to a single value). Add to Section 10.5 test blocks. Clarify that `as.character()` handles only non-character single values; length > 1 is an error. — Effort: low, Risk: none
- **[B]** Remove the coercion behavior entirely. All label content must be a character scalar; non-character or length > 1 always errors with a single error class `surveycore_error_label_not_scalar`. — Effort: trivial, Risk: low (more restrictive but simpler)
- **[C] Do nothing** — `cli_warn()` call cannot be written without a class; or implementer invents a class not in the spec.

**Recommendation: [B]** — coercion is a code smell for a metadata setter; failing loudly is better than silently accepting `42L` as a label.

---

**Issue 20: Single unnamed vector in `...` (e.g., `set_var_label(svy, c("Age", "Income"))`) — falls through all convention detection paths, no matching error class**
Severity: REQUIRED
Violates contract completeness; realistic user mistake with undefined behavior.

Consider: `set_var_label(svy, c("Age in years", "Annual income"))` — an unnamed character vector passed as a single `...` element. Detection paths:
- Convention 1: all elements named? No — `dots[[1L]]` has no element name. Fail.
- Convention 2: exactly one unnamed element that is itself a **named** vector? No — the vector has no names. Fail.
- Convention 3: `variable` is NULL. Fail.
- M-12 (mixed named/unnamed): is there a _mix_? No — the one element in `...` is unnamed. All are unnamed. M-12 fires only when some are named and some are not.
- M-4 (empty): `dots` is non-empty. Fail.

Result: no detection path matches. Behavior is undefined. The implementer must either invent a fifth case or crash with an uninformative error.

Options:
- **[A]** Extend M-4 (or add M-13) to cover "single unnamed non-named-vector element in `...`": "error with `surveycore_error_setter_unnamed_vector` — `{.arg ...} contains an unnamed vector; use named arguments (e.g., set_var_label(x, age = 'Age'))` or a named vector." — Effort: low, Risk: none
- **[B]** Extend M-12 to cover "all unnamed elements" in addition to "mixed": rename `surveycore_error_setter_mixed_dots` to `surveycore_error_setter_unnamed_dots` and fire it when any element in `...` has no name (either all unnamed or mixed). — Effort: trivial, Risk: low (slight semantic change to M-12)
- **[C] Do nothing** — user gets an uninformative R error about no matching detection branch.

**Recommendation: [B]** — simplest extension; "unnamed elements in `...`" is a single coherent concept regardless of whether some or all are unnamed.

---

**Issue 21: Convention 3 with `variable = character(0)` / `label = character(0)` — behavior unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

Section 4.1 says "Length mismatch (convention 3 only): If `length(variable) != length(content)`, error with `surveycore_error_setter_mismatched_lengths`." But `character(0)` and `character(0)` have equal length (both 0). So the length mismatch check passes. Then the setter iterates over the result (an empty named list). It would return `invisible(x)` unchanged — a silent no-op. Is this the intended behavior?

Section 4.1 says "Empty error: If `...` is empty AND `variable` is NULL, error with `surveycore_error_setter_empty`." Convention 3 with `variable = character(0)` is not "variable is NULL" — it is explicitly provided, just empty. The spec is silent on this case.

Options:
- **[A]** Specify: "Convention 3 with `length(variable) == 0` is a silent no-op: return `invisible(x)` unchanged. No warning is issued." — Effort: trivial
- **[B]** Specify: "Convention 3 with `length(variable) == 0` errors with `surveycore_error_setter_empty`." — Effort: trivial
- **[C] Do nothing** — implementer chooses; behavior varies between implementations.

**Recommendation: [A]** — an empty variable vector is a valid programmatic pattern when the vector was filtered down to zero entries. Silently returning unchanged is the least surprising behavior.

---

**Issue 22: `set_missing_codes()` Convention 3 bare atomic vector for `codes` — no exception noted; `set_val_labels()` allows this but `set_missing_codes()` doesn't specify**
Severity: REQUIRED
Violates contract completeness; creates inconsistent behavior between structurally parallel functions.

Section 4.4 (`set_val_labels()`) specifies: "A bare named vector (not wrapped in a list) for a single variable is accepted when `length(variable) == 1L`." This accommodates `set_val_labels(svy, variable = "sex", labels = c(Male = 1L, Female = 2L))` — where `labels` is a bare vector, not a list.

Section 4.8 (`set_missing_codes()`) has no equivalent exception. Its argument table says `codes | list or NULL`. An implementer applying the same logic would accept `set_missing_codes(svy, variable = "q5", codes = c(99L, 98L))` by analogy — but the spec prohibits it (type is "list"). A strict implementer would error; a lenient one would accept it. Behavior is undefined.

Options:
- **[A]** Add the same exception to Section 4.8: "A bare atomic vector (not wrapped in a list) for a single variable is accepted when `length(variable) == 1L`." — Effort: trivial, Risk: none
- **[B]** Explicitly exclude this exception from `set_missing_codes()`: "Unlike `set_val_labels()`, a bare vector for `codes` is NOT accepted; always wrap in a list: `codes = list(c(99L, 98L))`." — Effort: trivial, Risk: low
- **[C] Do nothing** — implementations diverge; one accepts `codes = c(99L, 98L)` for single-variable calls, another errors.

**Recommendation: [A]** — the parallel structure between `set_val_labels()` and `set_missing_codes()` means users will expect the same exception to apply; denying it without documentation is a trap.

---

#### Section: V. Extractor API

---

**Issue 23: `fill = NA_character_` in `"list"` format for scalar-content extractors — spec says `NULL` applies to "vector fields" but doesn't specify behavior for character-scalar fields**
Severity: REQUIRED
Violates contract completeness; implementer must guess.

Section 5.1 (fill argument table) says:
> "For `"list"` output: `NULL` (since `NA` is not a meaningful list value for **vector fields**)."

The phrase "vector fields" implies this applies only to `extract_val_labels()` and `extract_missing_codes()`. But `extract_var_label()`, `extract_question_preface()`, `extract_var_note()`, and `extract_universe()` also support `format = "list"`. For these functions, the list values are character scalars, not vectors — so `NA_character_` IS a meaningful list value for a scalar field. Two interpretations:

1. `extract_var_label(svy, fill = NA_character_, format = "list")` → `list(age = "Age in years", psu = NA_character_)` (NA is meaningful for scalars)
2. `extract_var_label(svy, fill = NA_character_, format = "list")` → `list(age = "Age in years", psu = NULL)` (consistent rule: list format always yields NULL)

Interpretation 1 is more consistent with the note box added in Pass 1 resolution (which says `NULL` for "vector fields" — implying scalar fields are different). But the spec doesn't confirm this.

Options:
- **[A]** Add to Section 5.1: "For scalar-content extractors (`extract_var_label`, `extract_question_preface`, `extract_var_note`, `extract_universe`): `fill = NA_character_` in `"list"` format yields `NA_character_` list entries (since `NA` is a valid scalar value). For vector-content extractors (`extract_val_labels`, `extract_missing_codes`): `fill = NA_character_` in `"list"` format yields `NULL` entries." — Effort: low, Risk: none
- **[B]** Unify the behavior: `"list"` format always yields `NULL` entries for any `fill` value, for all extractors. Update the note box accordingly. — Effort: low, Risk: medium (slightly surprising for scalar fields but consistent)
- **[C] Do nothing** — `.format_scalar_result()` and `.format_list_result()` will behave differently in ways not anticipated by the spec.

**Recommendation: [A]** — preserves intuitive behavior (`NA_character_` in a list of strings is fine) while maintaining the `NULL` rule for vector fields where it is justified.

---

#### Section: X. Testing Plan

---

**Issue 24: Section 10.5 has no test for `set_val_labels()` Convention 3 with bare named vector (the `length(variable) == 1L` exception from Section 4.4)**
Severity: REQUIRED
Violates testing-standards.md: every documented behavior exception must have a test.

Section 4.4 documents: "A bare named vector (not wrapped in a list) for a single variable is accepted when `length(variable) == 1L`." This is an explicit behavior exception that deviates from the type contract (`labels | list or NULL`). Section 10.5 has a "Convention 3 (explicit `variable` + content) sets correct metadata" block, but it would use the standard list form. The bare-vector exception is never tested. If an implementer forgets to implement the exception, no test catches it.

Options:
- **[A]** Add a test block to Section 10.5 under `set_val_labels()`: "Convention 3 — bare named vector accepted for single variable: `set_val_labels(svy, variable = 'sex', labels = c(Male = 1L, Female = 2L))` sets the labels correctly." — Effort: trivial, Risk: none
- **[C] Do nothing** — the exception is untested; regressions go undetected.

**Recommendation: [A]**

---

**Issue 25: `surveycore_warning_missing_labels` (M-9) — spec doesn't say whether the data-value comparison fires for data frame inputs**
Severity: REQUIRED
Violates contract completeness; `set_val_labels()` on data frames is a new capability, and M-9's condition requires reading column values.

M-9 fires when "Some observed data values have no corresponding label." For survey objects, `x@data[[var]]` provides the observed values to compare against. For data frames, `x[[var]]` provides them. The spec Section 4.4 says M-9 is retained "same as existing behavior" — but the existing behavior only runs for survey objects. The spec doesn't say whether `set_val_labels(df, sex = c(Male = 1L))` — when `df$sex` contains the value `2` — issues `surveycore_warning_missing_labels` or silently stores the partial labels.

Options:
- **[A]** Add to Section 4.4: "The `surveycore_warning_missing_labels` check applies for both survey objects (`x@data[[var]]`) and data frames (`x[[var]]`). The comparison reads observed unique values regardless of object type." — Effort: trivial, Risk: none
- **[B]** Restrict M-9 to survey objects only: "Data frames do not trigger `surveycore_warning_missing_labels` — the warning is deferred to when the data frame is passed to `as_survey()`." — Effort: trivial, Risk: low
- **[C] Do nothing** — implementations diverge; one warns for data frames, another doesn't.

**Recommendation: [A]** — the comparison is cheap, the information is available, and users annotating data frames deserve the same guard as users annotating survey objects.

---

#### Section: General / Cross-Cutting

---

**Issue 26: `fill` argument semantics differ between `extract_metadata()` (`NULL`/`"include"`) and individual extractors (`NULL`/`NA_character_`) — inconsistency not called out; invalid `fill` values unspecified for both**
Severity: SUGGESTION
Violates API Coherence (Lens 6): same argument name, different valid values, no user-facing note.

Individual extractors: `fill = NULL` (omit) or `fill = NA_character_` (include with NA). `extract_metadata()`: `fill = NULL` (omit) or `fill = "include"` (include all). A user reading the API would naturally try `extract_var_label(svy, fill = "include")` expecting the `extract_metadata()` semantics — but `"include"` is not `NA_character_`, so it would be treated as a non-NULL fill value and include variables with their fill value set to the string `"include"`. Similarly, `extract_metadata(svy, fill = NA_character_)` would silently do the wrong thing (since only `NULL` and `"include"` are meaningful for that function).

Additionally, neither the individual extractor specs nor the `extract_metadata()` spec defines what happens with invalid `fill` values — there's no `surveycore_error_fill_invalid` class.

Options:
- **[A]** Add to Section 6.3 a note: "Note: `extract_metadata()` uses `fill = "include"` rather than `fill = NA_character_` because the output is a structured list, not a typed vector. Passing `fill = NA_character_` to `extract_metadata()` is treated as an invalid value and errors with `surveycore_error_fill_invalid`." Similarly note for individual extractors that `fill = "include"` is not a valid value. Add `surveycore_error_fill_invalid` to Section IX. — Effort: low, Risk: low
- **[C] Do nothing** — inconsistency is discoverable by reading both sections carefully; no validation means silent misbehavior.

**Recommendation: [A]** — validation on fill values costs almost nothing and prevents a class of confusing bugs.

---

**Issue 27: `.format_list_result()` `fn_name` parameter purpose not explained in helper spec**
Severity: SUGGESTION
Minor contract incompleteness — low risk since the purpose is inferable.

Section 3.2 defines `.format_list_result(result_list, format, fn_name)` but provides no description of what `fn_name` does. Presumably it is used in the `surveycore_error_format_invalid` message (since invalid format is the only error `.format_list_result()` would raise). But an implementer might use it differently or omit it.

Options:
- **[A]** Add one sentence: "`fn_name`: used in the `surveycore_error_format_invalid` message body (`{.fn {fn_name}} does not support format = ...`)." — Effort: trivial
- **[C] Do nothing** — inferable; low risk.

**Recommendation: [A]** — trivial fix.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 10 |
| SUGGESTION | 2 |

**Total new issues:** 12

**Overall assessment:** All four blocking issues from Pass 1 are resolved and the spec is substantially stronger. No new blocking issues were found. The ten required issues are concentrated in three areas: (1) the old-positional-form detection scope (Section 8.3 says "each setter" but only `set_var_label()` needs it — Issues 16 and 17 on the missing `fn_name` parameter); (2) underspecified edge case behavior in setters (the unnamed-vector-in-`...` case, Convention 3 with empty vector, bare-atomic-vector for `set_missing_codes()`, content validation gaps in `set_var_note()` and `set_universe()`); (3) missing or incorrect test coverage (bare-vector exception for `set_val_labels()` Convention 3, M-9 for data frames). Resolving these leaves the spec fully implementable with no guesses required. The two suggestions (fill semantics inconsistency and `.format_list_result()` doc) are low-priority polish items.
