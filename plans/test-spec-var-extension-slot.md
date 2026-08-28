# Test-spec — var-extension-slot

**Version**: 1.1
**Date**: 2026-08-28 (amended — added §Class/foundation table during
implementation-plan review resolution; no other change)

## Reference oracle

None. This feature is pure metadata storage (a per-variable, unvalidated
named-list slot). There is no numerical estimator, no formula, and no
upstream package (`survey`, `srvyr`) that provides a ground truth to
compare against. Every assertion in this test-spec is a structural or
round-trip check against the behavior stated in the spec, not a numerical
comparison.

## Datasets

- `make_survey_data(seed = N)` — for every test that needs a constructed
  survey design object (any of `design = "taylor"`, `"replicate"`,
  `"twophase"`). This feature does not touch variance estimation, so the
  specific design type used should not matter to most test outcomes; pick
  one design type as the file's default and stay consistent for those
  rows. Exception: across the test file as a whole (not necessarily every
  block), each of `survey_taylor`, `survey_replicate`, `survey_twophase`,
  and `survey_nonprob` must be constructed and exercised with
  `set_var_extra()`/`extract_var_extra()` at least once, so the spec's
  Class/design support matrix ("Yes" for all four classes) has actual
  test evidence rather than resting on S7-inheritance assertion alone.
  The `survey_nonprob` construction is also required for the
  `@reference_sample` independence row above.
- A plain in-line `data.frame` — for every test exercising the
  "`x` is a data frame" mode (not a survey design object).
- No real dataset (`nhanes_2017`, `acs_pums_wy`, `gss_2024`) is required.
  This feature has no numerical content to validate against real data,
  and no reference oracle exists for it.

## Per-function test plan

### Class/foundation

| Scenario | Assertion |
|---|---|
| `survey_metadata()` constructed with no arguments | `var_extra` property defaults to `list()`. |
| `survey_metadata(var_extra = list(age = list(role = "demographic")))` | Stored value is `identical()` to what was passed. |
| A survey design object built via `as_survey()`, `as_survey_replicate()`, `as_survey_twophase()`, or `as_survey_nonprob()`, with no `var_extra` payload set | `@metadata@var_extra` is present and equals `list()` — confirms the class default flows through every constructor path, not only direct `survey_metadata()` construction. |

### `set_var_extra()`

**Happy path**

| Scenario | Mode | Assertion |
|---|---|---|
| Convention 1: single named argument, payload is a flat named list (`age = list(role = "demographic")`) | survey object | Stored payload for `age` is `identical()` to the list passed in. |
| Convention 1: multiple named arguments in one call | survey object | Each variable's stored payload matches what was passed for that variable, independently. |
| Convention 2: single unnamed named list in `...` mapping multiple variables to payloads | survey object | Every variable named in the list has its payload stored correctly; order of arguments does not matter. |
| Convention 3: `variable = "age"`, `extra = list(list(role = "demographic"))` (single variable, outer-list-wrapped) | survey object | Stored payload for `age` is `identical()` to `list(role = "demographic")` — not `list(list(role = "demographic"))`. This specifically catches the "forgot to double-wrap" failure mode. |
| Convention 3: `variable = c("age", "q13_text")`, `extra = list(list(role = "demographic"), list(role = "free_text"))` | survey object | Each variable's payload matches its corresponding position in `extra`. |
| Payload with deeply nested structure (a list containing a list containing a numeric vector and a character scalar) | survey object | Round-trips through `set_var_extra()` then `extract_var_extra()` with `identical()` equality — nothing is flattened, coerced, or reordered. |
| Payload whose top-level entries are all named, but one entry's *value* is itself an unnamed list (e.g. `list(role = "free_text", tags = list("a", "b"))`) | survey object | Accepted without error; stored and returned exactly as given. Confirms validation applies only to the payload's own top-level names, never to nested structure. |
| Payload contains a value of an unusual type as one of its entries (e.g. a function, a data frame, or `NA`), with the top level fully named | survey object | Accepted without error; stored and returned exactly as given (identity check where feasible; for a function value, confirm `identical()` or `is.function()` on round-trip). |
| Setting a payload on a `data.frame` (not a survey object) | data frame | `attr(x[[var]], "var_extra")` equals the payload after the call. This is a both-modes row: the storage location differs by mode (S7 property vs. column attribute), so both modes are exercised. |
| Setting a payload on a `data.frame`, then constructing a survey object from that frame via `as_survey()` (or `as_survey_replicate()`/`as_survey_twophase()`/`as_survey_nonprob()`) | data frame → survey object | `extract_var_extra()` on the resulting survey object returns the same payload that was set on the data frame before construction — confirms promotion into `@metadata@var_extra` at construction time, the same path already used for `note`/`universe`/`missing_codes`. |
| Convention 3, `variable` supplied, `extra` omitted (left at its default `NULL`), for two or more variables that each already have a payload | survey object | Every listed variable's payload is cleared (removed as a key from `var_extra`); variables not listed are unaffected. |
| `variable`/`...` name matches a design variable (e.g. the survey's weight column) | survey object | `set_var_extra()` succeeds; the payload is stored under that name like any other variable; the design variable's own value/identity in `@data` and `@variables` is unchanged. |
| A payload value is a non-serializable object (e.g. an open `textConnection()` or an environment), with the top level fully named | survey object | `set_var_extra()` accepts it without error (top-level shape is fine); separately, `saveRDS()` then `readRDS()` of a design whose `var_extra` payload contains only plain R-serializable content (character/numeric/list, no connections/environments) round-trips with `identical()` equality on the extracted payload — this is the test that actually exercises the feature's stated motivation (surviving disk serialization). |
| `x` is a `survey_nonprob` object with a `@reference_sample`; a payload is set on the same variable name on both `x` and `x@reference_sample`, with different content | survey object (`survey_nonprob`) | `extract_var_extra(x, v)` and `extract_var_extra(x@reference_sample, v)` return their own independently-set payloads; neither call surfaces the other object's payload. |
| Setting `extra = NULL` for a variable that already has a payload | survey object | After the call, that variable's entry is fully absent from the stored `var_extra` list (not present as a `NULL`-valued entry — actually absent as a key), matching ordinary R list-assignment-with-`NULL` semantics. |
| Setting a payload of `list()` (empty, not `NULL`) | survey object | Stored payload for that variable is `list()`. Confirm via `extract_var_extra(..., format = "list")` that the variable is present (not omitted) with a `list()` value — distinguishes "explicitly emptied" from "never set." |
| Calling `set_var_extra()` twice on the same variable with different payloads | survey object | Second call's payload fully replaces the first (no merge). |

**Error paths** — one row per named error class, dual pattern
(`expect_error(class = ...)` AND `expect_snapshot(error = TRUE)`) for
every row below:

| Scenario | Error class |
|---|---|
| `x` is neither a survey object nor a data frame (e.g. a plain vector) | `surveycore_error_not_survey_or_df` |
| Both `...` and `variable` supplied in the same call | `surveycore_error_setter_ambiguous` |
| Neither `...` nor `variable` supplied | `surveycore_error_setter_empty` |
| `variable` has 2 elements but `extra` has 1 element (non-`NULL`) | `surveycore_error_setter_mismatched_lengths` |
| `...` contains a mix of one named and one unnamed argument | `surveycore_error_setter_mixed_dots` |
| Payload for a variable is a bare character string (not a list, not `NULL`) | `surveycore_error_var_extra_not_list` |
| Payload for a variable is a bare numeric vector | `surveycore_error_var_extra_not_list` |
| Payload for a variable is a bare atomic vector with names (e.g. `c(role = "x")`, which looks list-like but is not a list) | `surveycore_error_var_extra_not_list` |
| Payload is a non-empty list with one or more unnamed top-level elements (e.g. `list("free_text", 3)`) | `surveycore_error_var_extra_not_list` |
| Payload is a non-empty list with a duplicated top-level name (e.g. `list(role = "a", role = "b")`) | `surveycore_error_var_extra_not_list` |
| Payload is a non-empty list with an empty-string top-level name (e.g. `list("" = "x")`) | `surveycore_error_var_extra_not_list` |
| Convention 3, exactly one variable, `extra` is a named list of length 1 supplied directly instead of wrapped in an outer list (e.g. `variable = "age", extra = list(role = "demographic")`) | `surveycore_error_var_extra_ambiguous_wrap` |

**Warning paths**

| Scenario | Warning class |
|---|---|
| One of several named variables does not exist in `x`'s columns | `surveycore_warning_var_not_found`. Capture with `expect_warning(result <- set_var_extra(...), class = ...)`; assert from `result` that the variables which *do* exist still received their payloads, and the missing one was skipped (not present as a key). |
| `variable = character(0)` supplied explicitly | `surveycore_warning_setter_empty_variables`. Capture with `expect_warning()`; assert the returned object is unchanged (`identical()` to the input, or at least `var_extra` unchanged). |
| One variable absent from `x`'s columns AND has an invalid (non-list, or unnamed-top-level-list) payload, alongside a present variable with a valid payload, in one call | Only `surveycore_warning_var_not_found` fires for the absent variable (its payload's shape is never checked); the present variable's valid payload is stored; no error. Confirms existence is checked before shape validity, and that an invalid payload on an absent-and-skipped variable is not itself an error. |
| Two present variables in one call, both with invalid payloads, via Convention 1 (named `...` arguments) | `set_var_extra()` aborts with `surveycore_error_var_extra_not_list` on the first one in argument order; assert the call's `expect_error()` fires and, separately, that the *original* object passed in is unaffected (no partial write reaches the caller — check by capturing `x` before the call and confirming `identical(x, x_before)` after the error, since the failed call never reassigns `x`). |
| The same scenario via Convention 2 (a single unnamed named list in `...`) | Same outcome, but ordering is by the list's element order rather than argument order — assert the abort happens on the first invalid entry in the list, not necessarily the first argument textually. |

**Edge cases**

| Case | Assertion |
|---|---|
| Empty input: survey design built on a `make_survey_data()` frame reduced to 0 rows via a manual filter before calling `as_survey()` — or, if 0-row designs are not constructible, use `make_survey_data(n = 2)` (the package's stated minimum) as the smallest constructible design | `set_var_extra()` succeeds identically regardless of row count; assert the payload is stored correctly. |
| Single-row input is not separately constructible for survey designs (package minimum is 2 rows) — use a single-row **data frame** instead | `set_var_extra()` on a 1-row data frame succeeds; payload attribute is set on the correct column regardless of row count. |
| All-NA outcome column: the target variable's data column is entirely `NA` | `set_var_extra()` succeeds — it never reads the column's values, only its name. Assert the payload is set correctly despite the all-NA data. |
| Single-level grouping / zero-weight rows / degenerate strata | Not applicable to this function (it does not read weights, strata, or grouping). No test row — explicitly out of scope because the function operates on variable names only and never reads column values, weights, strata, or grouping structure. |
| Setting a payload for every column in `x` in one call (Convention 2, one entry per existing column) | All payloads stored correctly; no interaction between variables' payloads. |
| `variable`/`...` name is the internal sentinel column `..surveycore_wt..` (probability-derived SRS designs) | `set_var_extra()` succeeds with no special-casing; the payload is stored under that literal name like any other variable. |

**Invariants**

- `test_invariants(design)` — call once in this test file's first block
  that constructs a survey design object via `as_survey()` (or whichever
  constructor the file uses). Do not repeat it in every block.

### `extract_var_extra()`

**Happy path**

| Scenario | Mode | Assertion |
|---|---|---|
| `format = "list"` (default), one variable with a payload set | survey object | Returned list has one entry, keyed by variable name, value `identical()` to the stored payload. |
| `format = "list"`, no variables selected via `...` (default: all columns) | survey object | Returned list contains only the columns that have a payload set (default `fill = NULL` omits the rest). |
| `format = "list"`, `fill = NA_character_`, a variable with no payload included in the selection | survey object | That variable appears in the result with a `NULL` value. |
| `format = "data_frame"`, one variable with a 2-key payload | survey object | Returned tibble has exactly 2 rows for that variable, columns `variable`, `key`, `value`; `key` matches the payload's names; `value` (list-column) matches the payload's values positionally. |
| `format = "data_frame"`, a variable with payload `list()` (explicitly emptied) | survey object | Contributes zero rows (nothing to enumerate) — confirmed distinct from `format = "list"`, which would show the variable with an empty-list value. |
| `format = "data_frame"`, no variable has any payload | survey object | Zero-row tibble with columns `variable`, `key`, `value` present and correctly typed (test column names and count, not just `nrow() == 0`). |
| Reading a payload set via `set_var_extra()` on a `data.frame` | data frame | `extract_var_extra()` on the same data frame returns the payload from the `"var_extra"` attribute. Both-modes row: read path differs by mode (S7 property vs. attribute), matching the both-modes rule. |
| Payload value containing a nested list, retrieved via `format = "data_frame"` | survey object | The `value` list-column's corresponding element is `identical()` to the original nested list — not flattened or coerced to character. |
| `any_of()` used to select a mix of existing and non-existing variable names | survey object | Non-existing names are silently skipped; no warning, no error; result includes only the existing ones (matches `extract_var_note()`'s established behavior — confirm by testing the same pattern side-by-side is unnecessary, just confirm `extract_var_extra()` itself behaves this way). |

**Error paths** — dual pattern for every row:

| Scenario | Error class |
|---|---|
| `x` is neither a survey object nor a data frame | `surveycore_error_not_survey_or_df` |
| `format = "named_vector"` | `surveycore_error_format_invalid` |
| `format = "something_invalid"` | `surveycore_error_format_invalid` |
| `fill = "not_a_valid_value"` (e.g. `fill = TRUE`) | `surveycore_error_fill_invalid` |

**Edge cases**

| Case | Assertion |
|---|---|
| Empty input (smallest constructible design, per the package's row-count floor) | `extract_var_extra()` returns the appropriate empty/populated result identically regardless of row count. |
| All-NA outcome column for the queried variable | `extract_var_extra()` returns the stored payload (if any) unaffected by the column's data values — it never reads them. |
| A variable with a payload set to `list()` vs. a variable never given a payload, both queried with `format = "list"` and default `fill = NULL` | The `list()` variable is present with value `list()`; the never-set variable is absent. This is the key edge case distinguishing "empty but set" from "unset" — do not conflate them. |
| Single-level grouping / zero-weight rows / degenerate strata | Not applicable — no test row (function is read-only over variable-keyed metadata and never reads weights, strata, or grouping). |

**Invariants**

- No new invariant call needed if this test file already called
  `test_invariants()` for the constructor it uses (see rule: once per
  constructor per file, first block only).

### Lifecycle — rename and column removal

`var_extra` participates in the same rename/delete lifecycle as `notes`,
`variable_labels`, `value_labels`, `question_prefaces`, and
`transformations`: renaming a column carries its metadata to the new name,
and removing a column deletes it. Test via the package's public
rename/column-removal
entry points for survey design objects (however the package's own test
suite currently exercises the equivalent behavior for `set_var_note()` —
mirror that exact mechanism for `var_extra`, since both must be wired
into the same two internal lifecycle points and are expected to behave
identically).

| Scenario | Assertion |
|---|---|
| A variable with a payload set via `set_var_extra()` is renamed | The payload is now retrievable under the *new* variable name via `extract_var_extra()`, and is no longer retrievable under the old name. |
| A variable with a payload set via `set_var_extra()` is removed from the design | The payload no longer appears anywhere in the design's stored metadata — a subsequent `extract_var_extra()` call (with `any_of()` or over all remaining columns) does not surface it. |
| A variable with **no** payload set is renamed or removed | No error, no warning; other variables' payloads are unaffected. |
| Renaming one variable does not disturb another variable's stored payload | Confirm the untouched variable's payload is unchanged after the rename. |

## Tolerances

N/A — no numeric estimation is involved anywhere in this feature. All
assertions are structural (`expect_identical()` for list/NULL/character
equality) per `testing-standards.md`'s guidance to use
`expect_identical()` for structural comparisons rather than
`expect_equal()`.

Deviations: none.

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
