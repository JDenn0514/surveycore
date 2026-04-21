## Spec Review: sata-metadata — Pass 1 (2026-04-16)

### New Issues

#### Section: III — `sata` Property / Architecture

**Issue 1: `.get_data_for_select()` is introduced without being placed in the architecture**
Severity: REQUIRED
Violates code-style.md §4 (internal helper placement) and the DRY principle.

The spec introduces `.get_data_for_select()` in the tidy-select resolution subsection of Section IV, but it does not appear in the Architecture section (Section II) file organization table. More importantly, the codebase already has `.get_data_cols()` in `R/core-metadata.R` (line 58) that returns `names(x)` for data frames or `names(x@data)` for survey objects. For tidyselect, `eval_select()` needs the actual data frame, not just column names — but the inline form `if (is.data.frame(x)) x else x@data` is a one-liner that doesn't need a named helper. No helper should be introduced for a one-shot expression; two call sites are the threshold for extracting a helper (code-style.md §4).

Options:
- **[A]** Remove `.get_data_for_select()` from the spec. Inline `if (is.data.frame(x)) x else x@data` at the call site in `set_sata()`, and again in `extract_sata()` if it also needs tidyselect. Effort: low, Risk: low, Impact: cleaner architecture, Maintenance: none.
- **[B]** Add `.get_data_for_select()` to the architecture table in Section II, define it, and place it in `R/utils.R` (used by 2+ functions). Effort: low, Risk: low, Impact: consistent with helper-promotion rule, Maintenance: one more helper to track.
- **[C] Do nothing** — implementer invents the helper without guidance; duplication risk between files.

**Recommendation: A** — The expression is too short to justify a named helper; inline it.

---

#### Section: IV — `set_sata()`

**Issue 2: `sata = NA` is not caught by the existing error condition**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The error condition states: "`sata` is not scalar logical → error." But `is.logical(NA)` is `TRUE` and `length(NA) == 1L`, so `sata = NA` passes all checks and would silently store `NA` in `x@metadata@sata[[var_name]]`. The spec says the property is a logical flag — `TRUE` to mark, `FALSE`/`NULL` to unmark — so `NA` is semantically meaningless and should be rejected.

Options:
- **[A]** Extend the error condition to: "`sata` is not a non-NA scalar logical." Add `if (is.na(sata))` to the validation check. Update the error message: `"{.arg sata} must be {.code TRUE} or {.code FALSE}."` Effort: low, Risk: low, Impact: catches a realistic mistake, Maintenance: trivial.
- **[B]** Leave as-is and treat `NA` as equivalent to `FALSE` (unmark). Effort: zero, Risk: medium (silent behavior, confusing), Impact: wrong ergonomics, Maintenance: none.
- **[C] Do nothing** — `NA` silently ends up in the metadata list, corrupting downstream consumers.

**Recommendation: A** — Validate `!is.na(sata)` alongside the existing scalar logical check.

---

**Issue 3: `variable = character(0)` behavior is undefined**
Severity: REQUIRED
Violates contract completeness (no edge case behavior stated).

The spec says rule 5: "Neither `...` nor `variable` provided → error." But `variable = character(0)` technically provides the `variable` argument (a character vector of length 0). The spec does not say whether this is treated as "no variables" (error) or as a no-op (silently does nothing). The implementation will need to make this choice.

Options:
- **[A]** Treat `variable = character(0)` as equivalent to "neither provided" → error with `surveycore_error_sata_no_vars`. Effort: low, Risk: low, Impact: consistent with the "at least one variable required" intent, Maintenance: add one edge case test.
- **[B]** Treat `variable = character(0)` as a no-op (skip without error). Effort: low, Risk: low, Impact: permissive; mirrors how `for` loops over empty vectors are no-ops in R, Maintenance: add one edge case test.
- **[C] Do nothing** — implementer makes the choice without guidance; test plan will be incomplete.

**Recommendation: A** — An empty vector passed programmatically almost certainly means a bug in the calling code; fail fast.

---

#### Section: V — `extract_sata()`

**Issue 4: `.check_extractor_fill()` incompatibility is not addressed**
Severity: BLOCKING
Violates DRY (existing infrastructure); will cause a runtime error at validation if the existing helper is reused.

The existing `.check_extractor_fill()` (line 387 of `R/core-metadata.R`) only accepts `NULL` or `NA_character_`. It explicitly errors on any other value — including `FALSE` (a logical). `extract_sata()` uses `fill = FALSE` as its default. If the implementer naturally reaches for `.check_extractor_fill()` (as all other extractors do), the function will error on its own default argument. Similarly, `.format_scalar_result()` assumes character values and returns `character(0)` for empty results — `extract_sata()` needs logical values and `logical(0)`.

The spec must specify whether:
1. `.check_extractor_fill()` is extended to accept logicals (a shared change affecting all extractors)
2. `extract_sata()` uses its own inline fill validation (not `.check_extractor_fill()`)
3. A new `._check_logical_fill()` helper is introduced
4. `.format_scalar_result()` is extended or replaced for logical values

Options:
- **[A]** Specify that `extract_sata()` does NOT use `.check_extractor_fill()` or `.format_scalar_result()`. Define inline fill validation (`fill` must be `FALSE`, `TRUE`, or `NULL`) and a new format helper (`.format_logical_result()`) that handles logical values and returns `logical(0)` for empty named vectors. List both as new internal helpers in Section II. Effort: medium, Risk: low, Impact: clean infrastructure, Maintenance: one new helper.
- **[B]** Extend `.check_extractor_fill()` and `.format_scalar_result()` to handle the logical case. Effort: medium, Risk: medium (changes shared infrastructure; could break other extractors), Impact: unified infrastructure, Maintenance: higher complexity in shared helpers.
- **[C] Do nothing** — implementer will hit the incompatibility at test time and invent a solution without spec guidance.

**Recommendation: A** — `extract_sata()` works with logicals, which is genuinely different from character extractors. Separate helpers are cleaner than overloading shared ones.

---

**Issue 5: `fill = NULL` with explicit `...` and `format = "named_vector"` behavior is undefined**
Severity: BLOCKING
Violates contract completeness; an R logical vector cannot hold `NULL` values.

The spec defines `fill = NULL` as "omit variables with no SATA metadata." For the no-`...` case, this is unambiguous (only SATA-flagged variables appear in the result). For the explicit-`...` case, it means variables the user named but which are not SATA-flagged would be "omitted." In `format = "named_vector"`, omitted means absent from the returned vector. So `extract_sata(d, news_tv, news_online, fill = NULL)` where only `news_tv` is SATA would return `c(news_tv = TRUE)`, silently dropping `news_online` from the result.

This is confusing but possibly the intended behavior. The spec must state it explicitly, as it is:
- Not inferable from the fill documentation (which only describes the no-`...` case)
- Surprising (the user explicitly asked about `news_online`)
- Incompatible with `format = "named_vector"` for the `fill = NULL` + `TRUE` combo (can't put NULL in a logical vector, but omitting is possible)

Options:
- **[A]** Specify: "When specific variables are requested and `fill = NULL`: variables not marked SATA are omitted from the result, regardless of format." State this explicitly in behavior rule 1. Add a test. Effort: low, Risk: low, Impact: deterministic but surprising, Maintenance: one test.
- **[B]** Disallow `fill = NULL` when `...` are provided; error if the user tries to combine them. Force the user to either use `fill = FALSE` (include unlabeled vars) or not specify variables. Effort: low, Risk: low, Impact: more explicit, prevents confusion, Maintenance: one error + one test.
- **[C] Do nothing** — implementer chooses; behavior diverges from user mental model with no warning.

**Recommendation: A** — Clearly specify the omit-from-result behavior. The key fix is that the documentation must state it, not leave it implicit.

---

**Issue 6: `extract_sata()` `...` resolution mechanism is not specified**
Severity: REQUIRED
Violates contract completeness (Lens 6 — API coherence); creates inconsistency with `set_sata()`.

`set_sata()` explicitly uses `tidyselect::eval_select()` and supports `starts_with()`, `matches()`, `all_of()`. `extract_sata()` also has a `...` argument described as "bare variable names," but the spec is silent on whether tidyselect helpers are supported. All existing extractors in the codebase (`extract_var_label()`, `extract_val_labels()`, etc.) use `.resolve_vars()`, which resolves bare symbols and character expressions but does NOT support `starts_with()`. The implementer must choose, and the wrong choice creates an API surprise:

> "I can set SATA for `starts_with("news_")` but I can't extract it the same way?"

Options:
- **[A]** Match `set_sata()` and use `tidyselect::eval_select()` for `extract_sata()` `...` resolution. Update the spec with a resolution subsection identical in structure to the one in Section IV. Effort: low, Risk: low, Impact: consistent API; users can use the same selectors for get and set, Maintenance: slight complexity in implementation.
- **[B]** Use `.resolve_vars()` (bare names + character, no tidyselect helpers), matching all other extractors. Note this explicitly in the spec: "`extract_sata()` accepts bare names and character expressions only; tidyselect helpers are not supported." Effort: low, Risk: low, Impact: consistent with other extractors but inconsistent with `set_sata()`, Maintenance: simpler implementation.
- **[C] Do nothing** — implementer guesses; test plan will be incomplete for whichever choice is made.

**Recommendation: A** — Symmetry between `set_sata()` and `extract_sata()` produces a better user experience. Users who learn one learn the other.

---

#### Section: VI — `detect_question_type()`

**Issue 7: No programmatic (`variable =`) interface for `detect_question_type()`**
Severity: BLOCKING
Violates API coherence (Lens 6); the primary documented consumer (export functions) builds variable lists programmatically.

`detect_question_type()` only accepts variables via `...`. Section XI explicitly states that export functions (`export_topline()`, `export_crosstab()`) will call this function with computed variable lists. Calling a `...`-only function with a dynamic character vector requires `rlang::inject()` or `do.call()` contortions:

```r
# What export functions would have to write:
rlang::inject(detect_question_type(design, !!!rlang::syms(vars)))
```

This is the exact scenario `variable =` was designed for — and it's already provided in `set_sata()` and `extract_sata()`. The omission from `detect_question_type()` is inconsistent with the rest of the API and will produce awkward downstream code.

Options:
- **[A]** Add `variable = NULL` to `detect_question_type()`, mirroring the pattern from `set_sata()` and `extract_sata()`. Resolve via `...` (tidyselect) when present, via `variable` (character vector) otherwise; error if both provided. Effort: low, Risk: low, Impact: consistent API; export functions use it naturally, Maintenance: one more argument, one more error class.
- **[B]** Keep `...`-only but document the `rlang::inject()` pattern in the examples section explicitly. Effort: low, Risk: medium (downstream code is ugly; future maintainers will reinvent the wheel), Maintenance: low but misleading.
- **[C] Do nothing** — export function authors discover the friction at implementation time.

**Recommendation: A** — Add `variable = NULL` for programmatic use. This is a two-line addition to the argument table and a corresponding error class, with clear precedent from `set_sata()`.

---

**Issue 8: `detect_question_type()` data frame `question_preface` resolution not specified in the function contract**
Severity: REQUIRED
Violates contract completeness; the data frame code path is described only obliquely.

The spec says in the classification logic (step 1): "Extract `question_preface` from metadata (or column attribute for data frames)." Section III notes: "This parallels how `question_preface` uses `attr(col, 'question_preface')`." But neither statement appears in the `detect_question_type()` behavior rules or error table — only in passing. If a data frame input has question prefaces set via column attributes, the implementer needs explicit spec language confirming `attr(df[[var]], "question_preface", exact = TRUE)` is the access pattern. This is especially important because the function contract says it accepts data frames but the behavior rules (Section VI) all describe the metadata/survey-object path.

Options:
- **[A]** Add a behavior rule: "For data frames, `question_preface` is read from `attr(x[[var]], 'question_preface', exact = TRUE)` and `sata` from `attr(x[[var]], 'sata', exact = TRUE)`." Add a corresponding test (data frame input path). Effort: low, Risk: low, Impact: unambiguous, Maintenance: trivial.
- **[B]** Do nothing — parallel construction from Section III is sufficient for an experienced implementer.
- **[C] Do nothing** — implementer may pick a different attribute name or access pattern.

**Recommendation: A** — The spec already requires a test for data frame input; the implementation of that test depends on this being specified.

---

#### Section: IX — Testing

**Issue 9: Snapshot tests not specified for any error path**
Severity: REQUIRED
Violates testing-standards.md (dual pattern required for all user-facing `cli_abort()` errors).

The test plan in Section IX specifies `expect_error(class = ...)` for every error path but does not mention `expect_snapshot(error = TRUE)`. Per testing-standards.md: "User-facing input validation errors require two assertions: (1) typed class check and (2) snapshot — verifies the CLI message text." Every `cli_abort()` call in `set_sata()`, `extract_sata()`, and `detect_question_type()` is a user-facing error and requires the dual pattern.

Options:
- **[A]** Add `expect_snapshot(error = TRUE, ...)` alongside every existing `expect_error(class = ...)` entry in the test plan. Effort: low, Risk: low, Impact: complete test coverage; message regressions caught by CI, Maintenance: snapshot files need to be created and committed.
- **[B]** Do nothing — implementer will notice the testing-standards.md requirement during implementation.
- **[C] Do nothing** — snapshot gaps remain until CI catches them.

**Recommendation: A** — The test plan is the spec for tests; "see the testing standards" is not enough. Spell it out.

---

#### Section: II — Architecture / General

**Issue 10: `detect_question_type()` description says "classify" but the name says "detect"**
Severity: SUGGESTION
Minor naming inconsistency.

The spec describes `detect_question_type()` as "Classify variables into `'single'`, `'sata'`, or `'battery'`." The word "detect" implies automatic discovery (without explicit metadata), while "classify" implies applying a rule to known information. Given the function requires explicit `sata` metadata to classify correctly, `classify_question_type()` is arguably more precise. However, "detect" is an established prefix convention and the function does "detect" which type of question a variable is, so this is a style observation, not a correctness issue.

Options:
- **[A]** Rename to `classify_question_type()`. Effort: low, Risk: low, Impact: more precise naming, Maintenance: update all references in spec, plans, downstream contracts.
- **[B]** Keep `detect_question_type()` and update the description to use "detect" consistently ("Detects the question type for a set of variables"). Effort: low, Risk: none, Maintenance: trivial.
- **[C] Do nothing** — minor inconsistency between name and description remains.

**Recommendation: B** — "detect" is fine; align the description with the name rather than renaming the function.

---

**Issue 11: `.check_is_survey_or_df()` `call =` argument not mentioned when spec references it**
Severity: SUGGESTION
Minor documentation gap; the existing function signature includes `call = rlang::caller_env()` for error attribution.

The spec says `detect_question_type()` uses `.check_is_survey_or_df()` (Behavior rule 1) but doesn't mention passing `call =`. Every existing call site in `core-metadata.R` (lines 463, 512, 574...) passes `call = call` explicitly. If `detect_question_type()` forgets to pass `call =`, errors will point to the wrong stack frame.

Options:
- **[A]** Note in the behavior rule: "Use `.check_is_survey_or_df(x, call = rlang::caller_env())`." The `call =` pattern is standard across the file. Effort: trivial, Risk: none, Maintenance: none.
- **[B]** Do nothing — implementer will follow the existing call-site pattern.

**Recommendation: A** — Costs nothing to be explicit; prevents a debugging session if `call =` is accidentally omitted.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 6 |
| SUGGESTION | 2 |

**Total issues:** 11

**Overall assessment:** The spec has three blocking issues that must be resolved before implementation can begin: the `.check_extractor_fill()` incompatibility for `extract_sata()` (Issue 4), the undefined `fill = NULL` + explicit-vars behavior for `named_vector` format (Issue 5), and the missing programmatic `variable =` interface on `detect_question_type()` (Issue 7). The six REQUIRED issues are individually straightforward fixes but the snapshot test omission (Issue 9) affects every exported function's test plan. The spec is well-structured and nearly complete; resolving these 9 issues (3 blocking + 6 required) will make it implementation-ready.
