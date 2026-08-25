# Test Spec: Dataset-Level Metadata

| Field | Value |
|---|---|
| Test-spec ID | `dataset-level-metadata` |
| Version | 2.4 (additive; every v2.3 row ID unchanged) |
| Date | 2026-08-20 |
| Status | **DRAFT** |
| Target release | surveycore 1.2.0 |

**v2.4 changelog:** additive bump authorized by plan-review Pass 4
(findings 4R10, 4S7) — adds row X15 (§6); extends row X10 (§6) with the
round-trip-failing string `"2026-2-1"`; extends row X3 (§6) snapshot scope
with `field_start = NA`. No row ID changed; no prior assertion removed.

**v2.3 changelog:** additive bump authorized by plan-review Pass 3
(findings 3R11, 3S11, 3S12, 3S13, 3J2) — adds rows X10, X11, X13 (§6);
X14 (§7); X12 (§8). No v2.2 row or contract changed.

**v2.2 changelog:** additive bump authorized by plan-review Pass 2
(findings 2R1/2R8/2R9) — adds rows SR1, X1, E23 (§7); SR2, X2–X6, SC1–SC5
(§6); X7, X8 (§8); X9 (§9). No v2.1 row or contract changed.

The feature under test: a closed six-key dataset-metadata vocabulary
(`survey_name`, `data_name`, `vendor`, `field_start`, `field_end`,
`field_period`), twelve exported functions (six setters, six extractors),
attribute promotion at construction, and print/summary additions.

---

## 1. Reference oracle

This feature computes no statistic. There is no external package oracle.

Ground truth comes from two sources:

1. **The behavioral contract itself.** The expected value of every extractor
   call, every setter round trip, and every print line is fixed by the
   feature's contract and asserted literally in the tests.
2. **Base R attribute round trips.** On plain data frames, the tests verify
   setter output with bare `attr(df, "key", exact = TRUE)` calls, and verify
   extractor input by writing attributes with bare `attr(df, "key") <- value`
   calls. The `attr()` functions are the independent check that the exported
   API and the raw attribute layer agree.

No test in this plan calls the `survey` or `srvyr` packages, except the one
conversion-import test that already carries `skip_if_not_installed("survey")`.

## 2. Datasets and shared fixtures

| Scenario | Data |
|---|---|
| All unit tests (setters, extractors, construction, validator, print) | `make_survey_data()` with an explicit `seed` |
| Replicate-design tests | `make_survey_data(design = "replicate", ...)` |
| Two-phase tests | `make_survey_data(design = "twophase", ...)` |
| Non-probability tests | `make_survey_data()` output passed to the nonprob constructor |
| Label coexistence | `make_survey_data(with_labels = TRUE)` |
| Old-object compatibility | Runtime-built stale object (see §10) |

No real dataset is needed. No test depends on specific survey values.

**Shared fixtures — all defined ONCE in `tests/testthat/helper-test-data.R`**
(so nothing is defined twice across the four test files). Each test row below
names the helper it uses.

```r
# The canonical six-key value set (the full closed vocabulary).
full_keys <- list(
  survey_name  = "Antisemitic Attitudes in America 2026",
  data_name    = "AAA Ipsos (February-March 2026)",
  vendor       = "Ipsos KnowledgePanel Omnibus",
  field_start  = as.Date("2026-02-10"),
  field_end    = as.Date("2026-03-04"),
  field_period = "February-March 2026"
)

# A make_survey_data() frame carrying the given keys as whole-object
# attributes (raw attr()<- writes; no exported setter involved).
make_dataset_df <- function(keys = full_keys, seed = 42, ...) { ... }

# A constructed design of the given class in the given metadata state:
# "none", "data_name" (data_name only), "survey_name" (survey_name only),
# or "full" (all six keys). "nonprob_rep" builds a survey_nonprob design
# WITH bootstrap replicate weights (the repweights print branch).
make_dataset_design <- function(
  design = c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep"),
  state = c("none", "data_name", "survey_name", "full"),
  seed = 42
) { ... }

# Round-trip expectation: sets `keys` on a data frame via the exported
# setter, constructs with `constructor`, and asserts
# extract_dataset_metadata(design) is identical to `keys` in canonical
# key order.
expect_dataset_roundtrip <- function(df, constructor, keys = full_keys) { ... }

# A design of the given class whose metadata object is built from a LOCALLY
# DEFINED S7 class carrying only the original eleven metadata properties
# (no dataset slot), simulating an object restored from a surveycore
# <= 1.1.0 file. Built at runtime; no committed .rds fixture.
make_stale_metadata_design <- function(
  design = c("taylor", "replicate", "twophase", "nonprob"),
  seed = 42
) { ... }
```

## 3. Test file placement and structural rules

Placement follows the documented source→test mapping:

| Test area | File |
|---|---|
| Class/validator/property rows (§5) | `tests/testthat/test-s7-classes.R` |
| The twelve exported functions (§6–§7) and old-object read/write behavior (§10) | `tests/testthat/test-dataset-metadata.R` — **new file**; a documented split, justified because the metadata-system test file is already very large and these twelve functions form one coherent unit |
| Construction promotion + the nonprob weighting-history fix (§8) | `tests/testthat/test-constructors.R` |
| Print and summary snapshots (§9) | `tests/testthat/test-methods-print.R`, beside the existing print snapshots |

**Structural rules:**

- **Rows are contracts, not blocks.** Each row below is one contract; it
  expands to one or more `test_that()` blocks, each asserting exactly one
  observable behavior with a present-tense description. Lettered sub-rows
  are separate blocks.
- **Mode default:** every §6 and §7 row runs in BOTH input modes — once on a
  survey design object (via `make_dataset_design()` or `as_survey()` on
  `make_survey_data()` output) and once on a plain data frame — unless the
  row names a mode.
- `test_invariants(design)` is the **first** assertion of every test block
  that constructs a survey object.
- Structural assertions use `expect_identical()` (names, strings, `NA`,
  `Date` values, list shapes, key order). No numeric computation occurs, so
  `expect_equal()` with tolerance is not needed anywhere in this plan.

## 4. Error-class coverage matrix

Dual pattern = `expect_error(class = ...)` **plus**
`expect_snapshot(error = TRUE, ...)`. Class-only = `expect_error(class = ...)`
with no snapshot (S7 validator messages are not CLI-formatted).

| Class | Layer(s) | Pattern | Trigger recipe |
|---|---|---|---|
| `surveycore_error_dataset_metadata_unnamed` | validator + setter | class-only via `survey_metadata(dataset_metadata = list("x"))`; dual via `set_dataset_metadata(d, key = c(""), value = list("v"))` (Convention 3 — the only path that reaches this check in the setter; blank names in Conventions 1–2 surface as `setter_mixed_dots`) | both paths tested |
| `surveycore_error_dataset_metadata_duplicate_key` | validator + setter | class-only via direct construction with a duplicated name; dual via `key = c("vendor", "vendor")` AND via duplicated named `...` args (reachable through any convention) | both paths tested |
| `surveycore_error_dataset_metadata_bad_type` | validator + setter | class-only via `survey_metadata(dataset_metadata = list(vendor = 1L))` and `list(vendor = NULL)`; dual via `set_vendor(d, 1L)` (snapshot must name `vendor`), `set_survey_name(d, 1L)` (snapshot must name `survey_name`), `set_dataset_metadata(d, survey_name = c("a", "b"))`, and zero-length values (§6 Z-rows) | both paths tested |
| `surveycore_error_field_dates_reversed` | validator + setter | class-only via direct construction with a reversed Date pair; dual via `set_field_dates()` one-call and cross-call recipes | both paths tested |
| `surveycore_error_dataset_key_unknown` | validator + setter + extractor | class-only via `survey_metadata(dataset_metadata = list(mode = "web"))`; dual via setter (`mode = "web"`, near-miss `Vendor`, legacy `dates = "x"`, column-name key `y1 = "x"`) and via an extractor request for `mode` | all paths tested |
| `surveycore_error_field_date_invalid` | validator + setter | class-only via `survey_metadata(dataset_metadata = list(field_start = "2026-02-10"))` (the class layer accepts `Date` only); dual via `set_field_dates(d, field_start = "not-a-date")` and `set_dataset_metadata(d, field_start = 20260210)` | both paths tested |
| `surveycore_error_dataset_metadata_unavailable` | setter (stale object) | dual | any setter on `make_stale_metadata_design()` output (§10) |
| `surveycore_error_dataset_key_not_name` | extractor | dual | `extract_dataset_metadata(d, all_of("vendor"))` |
| `surveycore_error_not_survey_or_df` | guard on all twelve exports | dual (one snapshot; class check for all twelve) | `1L`, `"a"`, and a `survey_collection` as `x` |
| `surveycore_error_setter_ambiguous` | setter + extractor | dual | `...` and `key` both supplied, in `set_dataset_metadata()` and in `extract_dataset_metadata()` |
| `surveycore_error_setter_empty` | setter | dual | `set_dataset_metadata(d)`; each convenience setter called with the value argument missing; `set_field_dates(d)` with both date arguments missing |
| `surveycore_error_setter_mismatched_lengths` | setter | dual | `key` length 2, `value` length 1 |
| `surveycore_error_setter_mixed_dots` | setter | dual | one named + one unnamed `...` element; also a Convention-2 list with a blank name |
| `surveycore_warning_setter_empty_variables` | setter | `expect_warning(class = ...)`; result unchanged | `key = character(0)` |
| `surveycore_warning_dataset_metadata_dropped` | construction | `expect_warning(class = ...)` + snapshot of the message; construction still succeeds; one row per message variant | (a) wrong type; (b) zero-length value; (c) reversed date pair; (d) invalid legacy `dates` value (message must point at `set_field_period()`) |
| `surveycore_error_format_invalid` | extractor | dual | `extract_dataset_metadata(d, format = "named_vector")` |
| `surveycore_error_fill_invalid` | extractor | dual | `extract_dataset_metadata(d, fill = TRUE)`; the message must list `NULL`, `NA`, and `NA_character_` |

Every class above appears in at least one test. The convention-message
snapshots must render the `key` / "key-value pair" wording (not
`variable` / "variable-label pair"). Warning tests capture the return value
separately and assert it (per testing-standards §3).

**Regression guard:** the existing snapshot files for the seven sibling
setters (`set_var_label()` etc.) and for the sibling extractors' `fill`
errors must not change — including the container-noun wording of the sibling
convention messages ("a named **vector** in `...`", "a fully named
**vector**"), which the dataset setter renders as "list". Two re-assertions
of existing sibling behavior: (1) `extract_var_label(d, fill = NA)` still
errors `surveycore_error_fill_invalid` with its existing message (plain `NA`
is widened for the dataset extractor only); (2) one sibling-setter
convention error (for example `set_var_label(d)`) still renders its existing
`variable`/"variable-label pair" message. These two re-assertions carry row
IDs: SR1 (§7) and SR2 (§6).

## 5. Class and validator tests (`test-s7-classes.R`)

| ID | Test | Assertions |
|---|---|---|
| C1 | Default metadata object | `survey_metadata()` yields dataset metadata `list()`; `expect_identical` |
| C2 | Full valid construction | `survey_metadata(dataset_metadata = full_keys)` succeeds; each key round-trips identical |
| C3 | Independence at construction | `survey_name = "Formal Name"` with `data_name = "Totally Unrelated (2020)"` constructs cleanly — no error, no warning |
| C4 | Unknown key rejected at the class layer | `list(mode = "web")` → class-only `surveycore_error_dataset_key_unknown`; also `list(dates = "x")` and `list(class = "x")` (each its own block) |
| C5a | Unnamed element rejected | `list("x")` → class-only, `_unnamed` |
| C5b | `NA` name rejected | class-only, `_unnamed` |
| C5c | `""` name rejected | class-only, `_unnamed` |
| C6 | Duplicate key rejected | class-only, `_duplicate_key` |
| C7a | `survey_name` bad type | non-character / length 2 / `NA`, each class-only `_bad_type` |
| C7b | `data_name` bad type | same three sub-cases |
| C7c | `vendor` bad type | same three sub-cases |
| C7d | `field_period` bad type | same three sub-cases |
| C7e | `field_start` / `field_end` bad value | non-Date, `as.Date(NA)`, length 2, and an ISO **string** (the class layer accepts `Date` only) → class-only `surveycore_error_field_date_invalid` |
| C7f | `NULL`-valued element rejected | `list(vendor = NULL)` → class-only `_bad_type` (deletion means removal, never a stored `NULL`) |
| C8 | Reversed dates rejected | class-only, `_field_dates_reversed` |
| C9 | Lone `field_start` valid | only one date present constructs cleanly ("present" = name membership; the reversed check needs both) |
| C10 | Assignment re-validates | assigning a bad list to the property of an existing metadata object errors with the matching class |
| C11 | Explicit empty-list assignment | `m@dataset_metadata <- list()` succeeds; subsequent reads are empty |

## 6. Setter tests (`test-dataset-metadata.R`)

Both input modes per §3 unless a mode is named. Survey-object rows use
`make_dataset_design()`; data-frame rows use `make_survey_data()` output or
`make_dataset_df()`.

Core conventions and writes:

| ID | Test | Assertions |
|---|---|---|
| S1a | Convention 1 | `set_dataset_metadata(x, vendor = "Ipsos", data_name = "AAA")`; extractor returns both; on the data frame, `attr(x, "vendor", exact = TRUE)` is `"Ipsos"` |
| S1b | Convention 2 | one unnamed named **list** sets the same keys; result identical to S1a |
| S1c | Convention 3 | `key = c("vendor", "data_name")`, `value = list("Ipsos", "AAA")`; identical result |
| S1d | Splicing | `!!!full_keys`; all six set |
| S1e | Convention 3 atomic `value` | `key = c("vendor", "data_name")`, `value = c("Ipsos", "AAA")` (atomic, coerced) — identical result |
| S1f | Convention 3 names on `value` ignored | a named `value` list whose names disagree with `key`: the `key` names win |
| S2 | Return visibility | setter returns the modified object invisibly (`expect_invisible`) |
| S3 | NULL deletes | set a key, then set it to `NULL`; extractor omits it; on the data frame the attribute is gone |
| S4 | Delete absent key | `NULL` for a never-set key is a silent no-op (no warning, object unchanged) |
| S5 | Set + delete in one call | `set_dataset_metadata(x, vendor = "Cint", data_name = NULL)`; both take effect |
| S6a | Replace value | second set of the same key overwrites the first |
| S6b | Canonical order | set keys in scrambled order across several calls; `extract_dataset_metadata(x)` names are in the canonical six-key order |
| S6c | Overwrite keeps position | overwriting a key does not move it in the extracted order |
| S7a | Convention-3 bulk deletion | `key = c("vendor", "data_name"), value = NULL` deletes both; the length check does not fire |
| S7b | Bulk deletion, mixed present/absent | one set key + one never-set key in `key`, `value = NULL`: set key deleted, absent key a silent no-op |
| S7c | Per-element `NULL` in a `value` list | `value = list("Cint", NULL)` sets the first key and deletes the second |
| S8 | Atomicity | one call with a valid key and an invalid value writes nothing; extractor shows the pre-call state |

Convenience setters:

| ID | Test | Assertions |
|---|---|---|
| S10 | Independence: `set_survey_name()` | set both names; `set_survey_name(x, "New Formal Name")`; `extract_data_name()` unchanged, `expect_identical` |
| S11 | Independence: `set_data_name()` | mirror of S10; `extract_survey_name()` unchanged |
| S12a | `set_vendor()` happy path | value stored |
| S12b | `set_vendor(x, NULL)` deletes | key removed |
| S12c | `set_survey_name()` / `set_data_name()` happy + `NULL` deletes | one block per function per behavior |
| S12d | Missing value argument → typed error | `set_vendor(d)`, `set_survey_name(d)`, `set_data_name(d)`, `set_field_period(d)` each raise `surveycore_error_setter_empty` (dual pattern once; class check each) — never an unclassed base missing-argument error |
| S13a | `set_field_period()` happy path | stored; `extract_field_period()` returns it |
| S13b | `set_field_period(x, NULL)` deletes | key removed |
| S13c | `set_field_period(x, 1L)` | dual, `_bad_type`; snapshot names `field_period` |
| S14a | `set_field_dates()` Date input | `Date` scalars stored as given; extractor returns them identical |
| S14b | `set_field_dates()` ISO string input | `"2026-02-10"` stored as `as.Date("2026-02-10")`; `expect_identical` on class and value |
| S14c | Strict ISO only | `"2026/02/10"` and `"2026-02-30"` each error `_field_date_invalid`; the raised condition is the typed surveycore error, never a base `as.Date()` error |
| S14d | Missing argument leaves stored key unchanged | store both dates; call `set_field_dates(x, field_start = <new>)`; `field_end` unchanged |
| S14e | Explicit `NULL` deletes | `set_field_dates(x, field_end = NULL)` removes `field_end` and leaves `field_start` |
| S14f | Both missing | `set_field_dates(x)` → `surveycore_error_setter_empty` (dual) |
| S14g | `set_field_dates()` never touches the period | set a period first; any `set_field_dates()` call leaves `extract_field_period()` identical |
| S15a | Reversed pair, one call | dual pattern, `_field_dates_reversed` |
| S15b | Reversed pair, cross-call | store `field_end`; a later call sets a `field_start` after it → same error; stored state unchanged (atomic) |
| S15c | Delete-one-set-other | store a pair; one call deletes `field_end` and sets a `field_start` later than the old end → succeeds (the deleted date is absent from the effective pair) |
| S15d | Delete both | one call deletes both dates → succeeds |
| S15e | Effective-pair rule via the general setter | `set_dataset_metadata(x, field_start = NULL, field_end = <earlier than stored start>)` succeeds |

Unknown keys (closed vocabulary):

| ID | Test | Assertions |
|---|---|---|
| S16a | Plain unknown key | `set_dataset_metadata(x, mode = "web")` → dual, `_dataset_key_unknown`; snapshot shows the six valid keys |
| S16b | Near-miss hint | `Vendor = "x"` and `vender = "x"` → same class; snapshot shows the "Did you mean" hint |
| S16c | No hint for a distant key | `zzz = "x"` → same class; message carries no hint line |
| S16d | Legacy `dates` with a value | `dates = "April-May 2024"` → same class; snapshot points at `field_period` / `set_field_period()` |
| S16e | Column-name key | data-frame mode: `set_dataset_metadata(df, y1 = "x")` errors `_dataset_key_unknown` and the `y1` column is byte-identical afterwards |
| S16f | `dates = NULL` alias | deletes the `field_period` key (survey mode) / removes both the `field_period` and legacy `dates` attributes (data-frame mode) |
| S16g | `field_period = NULL` removes the legacy attribute too | data-frame mode: write a raw `dates` attribute; `set_dataset_metadata(df, field_period = NULL)`; both attributes gone; constructing afterwards yields no `field_period` (deletion is idempotent — nothing resurrects) |

Zero-length values (all six keys are typed; `character(0)` is not a deletion):

| ID | Test | Assertions |
|---|---|---|
| Z1–Z4 | `survey_name`, `data_name`, `vendor`, `field_period` = `character(0)` | each errors `_bad_type` (one block per key) |
| Z5–Z6 | `field_start`, `field_end` = `as.Date(character(0))` | each errors `_field_date_invalid` |

Environment and side effects:

| ID | Test | Assertions |
|---|---|---|
| S20 | Zero-row data frame | setters work on a 0-row data frame; attributes present |
| S20b | Single-row data frame | setter and extractor work normally |
| S21a | Other metadata untouched | on a survey object with variable labels, setting dataset keys leaves the variable labels identical |
| S21b | `@weighting_history` untouched | same call leaves the weighting history identical |
| S22 | Data columns untouched | on a data frame, the setter changes no column, no `names`, no `row.names` |
| S23 | `@data` residue (documented behavior) | survey mode: construct from a data frame carrying a `vendor` attribute; `set_vendor(d, "Cint")`; `extract_vendor(d)` is `"Cint"` while `attr(d@data, "vendor", exact = TRUE)` still holds the original — the metadata slot wins on every read path |
| S24 | Old restored object: writes raise the typed error | each of the six setters on `make_stale_metadata_design()` output errors `surveycore_error_dataset_metadata_unavailable` (class check for all six; dual pattern once) |

Per-class round trips (one block per design class; `test_invariants` first):

| ID | Test | Assertions |
|---|---|---|
| S25a | `survey_replicate` | set all six keys via `!!!full_keys` on the design; extract-all identical in canonical order; one convenience pair (`set_vendor` / `extract_vendor`) |
| S25b | `survey_twophase` | same recipe |
| S25c | `survey_nonprob` | same recipe |

Rows added in v2.2 (contracts formerly carried in the implementation plan;
same file, same structural rules):

| ID | Test | Assertions |
|---|---|---|
| SR2 | Sibling setter regression (§4 regression guard) | `set_var_label(d)` still renders its existing `variable` / "variable-label pair" / "vector" convention message; all existing sibling-setter snapshot files are byte-identical |
| SC1 | Reused convention error: ambiguous | `...` and `key` both supplied to `set_dataset_metadata()` → dual pattern, `surveycore_error_setter_ambiguous`, `key`-register wording |
| SC2 | Reused convention error: empty | `set_dataset_metadata(d)` → dual pattern, `surveycore_error_setter_empty`, "key-value pair" wording |
| SC3 | Reused convention error: mismatched lengths | `key` length 2, `value` length 1 → dual pattern, `surveycore_error_setter_mismatched_lengths` |
| SC4 | Reused convention error: mixed dots | one named + one unnamed `...` element; also a Convention-2 list with a blank name → dual pattern, `surveycore_error_setter_mixed_dots`, "list" container noun |
| SC5 | Reused convention warning: empty variables | `key = character(0)` → `expect_warning(class = "surveycore_warning_setter_empty_variables")`; the return value is captured separately and asserted unchanged |
| X2 | Alias/duplicate worked example | `set_dataset_metadata(x, dates = NULL, field_period = "Feb 2026")` → dual pattern, `surveycore_error_dataset_metadata_duplicate_key` (the `dates` alias resolves to `field_period` before the duplicate check) |
| X3 | DM-6a register snapshot | `set_dataset_metadata(d, field_start = 20260210)` → dual pattern, `surveycore_error_field_date_invalid`; the snapshot locks the `{.val}` register naming the key as a value; extended in v2.4: `set_dataset_metadata(d, field_start = NA)` → a second snapshot in the same scope locks the `{.val}` register rendering for an `NA` value |
| X4 | DM-8 precedence, general setter | `set_dataset_metadata(old)` with no keys, on a stale object (`make_stale_metadata_design()` output), raises `surveycore_error_dataset_metadata_unavailable`, not `surveycore_error_setter_empty` |
| X5 | DM-6b register + NA bullet | `set_field_dates(d, field_start = "not-a-date")` → snapshot locks the `{.arg}` register reporting `set_field_dates()` as the caller; `set_field_dates(d, field_start = NA)` → snapshot locks the "The value is NA." bullet |
| X6 | DM-8 precedence, wrapper | `set_vendor(old)` with the value argument missing raises `surveycore_error_dataset_metadata_unavailable`, not `surveycore_error_setter_empty` |

Rows added in v2.3:

| ID | Test | Assertions |
|---|---|---|
| X10 | ISO strings through the general setter | `set_dataset_metadata(x, field_start = "2026-02-10")` stores `as.Date("2026-02-10")` (class and value asserted with `expect_identical`); `set_dataset_metadata(x, field_start = "2026/02/10")` errors `surveycore_error_field_date_invalid`; both modes; the raised condition is the typed surveycore error, never a base `as.Date()` condition; extended in v2.4: `set_dataset_metadata(x, field_start = "2026-2-1")` (parses under `%Y-%m-%d` but fails the round-trip check) also errors `surveycore_error_field_date_invalid` |
| X11 | Valid key equal to a column name | data-frame mode: on a frame with a column named `vendor`, `set_dataset_metadata(df, vendor = "Ipsos")` writes the whole-object attribute (`attr(df, "vendor", exact = TRUE)` is `"Ipsos"`) and the `vendor` column is byte-identical afterwards — the attribute namespace and the column namespace are distinct |
| X13 | DM-3b duals across the character-key wrappers | `set_vendor(d, 1L)`, `set_survey_name(d, 1L)`, and `set_data_name(d, 1L)` → each dual pattern, `surveycore_error_dataset_metadata_bad_type`; each snapshot names the delegated key (`vendor`, `survey_name`, `data_name`), mirroring the S13c treatment |

Rows added in v2.4:

| ID | Test | Assertions |
|---|---|---|
| X15 | Reversed pair via the general setter (the DM-4b dual) | store `field_end`; `set_dataset_metadata(x, field_start = <a date after the stored field_end>)` → dual pattern, `surveycore_error_field_dates_reversed`; both modes; the stored state is unchanged afterwards (writes are atomic) |

## 7. Extractor tests (`test-dataset-metadata.R`)

Both input modes per §3 unless a mode is named.

| ID | Test | Assertions |
|---|---|---|
| E1 | All keys, canonical order | after setting `full_keys`: `extract_dataset_metadata(x)` returns all six with identical values, AND `expect_identical(names(result), names(full_keys))` — the canonical key-order assertion, both modes |
| E2a | Requested subset, request order | request `c(vendor, survey_name)`; result has exactly those keys in request order |
| E2b | Duplicate request deduplicated | request `vendor, vendor`; one `vendor` entry, first position; holds in both formats (the `data_frame` `key` column stays unique) |
| E3 | `fill = NULL` omits | request one set and one unset key; unset key absent |
| E4a | `fill = NA` includes | same request; unset key present |
| E4b | `fill = NA_character_` also accepted | identical result to E4a |
| E4c | List fill is type-matched | unset `field_start` requested with `fill = NA`: the list entry is `as.Date(NA)` (class asserted); unset `vendor`: `NA_character_` |
| E4d | data_frame fill is always character | same request with `format = "data_frame"`: the `value` cell is `NA_character_` for every filled key, date keys included |
| E5 | `format = "data_frame"` | tibble with columns `key` (character) and `value` (character); Date rows render ISO (`"2026-02-10"`) |
| E6a | Empty result shapes | no keys set, `fill = NULL` → `list()` and a 0-row two-column tibble |
| E6b | Empty request + fill → full schema | no keys set, empty `...`, `fill = NA` → all six keys in canonical order, each filled (type-matched in list format) |
| E7 | Invalid `format` | dual pattern, `_format_invalid`; trigger `format = "named_vector"` |
| E8 | Invalid `fill` | dual pattern, `_fill_invalid`; message lists `NULL`, `NA`, `NA_character_` |
| E9a | Convenience extractors, set | each of the five returns the stored value, `expect_identical` |
| E9b | Convenience extractors, unset | `NA_character_` for `extract_survey_name()` / `extract_data_name()` / `extract_vendor()` / `extract_field_period()`; `extract_field_dates()` returns `list(field_start = as.Date(NA), field_end = as.Date(NA))` with names and types asserted |
| E10 | **Never composes** | set `survey_name`, `field_start`, `field_end`, `field_period`; leave `data_name` unset; `extract_data_name()` is exactly `NA_character_` |
| E11 | Visible return | extractors return visibly |
| E12a | `key =` argument | `extract_dataset_metadata(x, key = c("vendor", "survey_name"))` behaves exactly like the E2a bare-name request |
| E12b | String requests in `...` | `extract_dataset_metadata(x, "vendor", "survey_name")` behaves exactly like the E2a bare-name request |
| E12c | `!!!` splicing in `...` | `extract_dataset_metadata(x, !!!c("vendor", "survey_name"))` behaves exactly like the E2a bare-name request |
| E13 | `...` + `key` together | dual, `surveycore_error_setter_ambiguous` |
| E14 | Call in `...` | `extract_dataset_metadata(d, all_of("vendor"))` → dual, `surveycore_error_dataset_key_not_name` |
| E15 | Unknown requested key | `extract_dataset_metadata(d, mode)` → dual, `_dataset_key_unknown` (a typo errors; it does not return an empty list) |
| E16 | Unset requested valid key raises no warning | `expect_no_warning` |

Data-frame read path (raw attributes; extractors never warn — every drop
below is silent, asserted with `expect_no_warning`):

| ID | Test | Assertions |
|---|---|---|
| E17 | Raw recognized attributes read | write `attr(df, "vendor")` and `attr(df, "data_name")` with bare `attr()<-`; extractors read them (the pre-1.2.0 `adldata` shape needs no setter) |
| E18a | Bad-typed raw attribute dropped silently | `attr(df, "vendor") <- 1L`; `extract_vendor(df)` is `NA_character_`; no warning |
| E18b | ISO-string raw date coerced on read | `attr(df, "field_start") <- "2026-02-10"`; `extract_field_dates(df)$field_start` is `as.Date("2026-02-10")` (class asserted) |
| E18c | Zero-length raw attribute dropped silently | `attr(df, "vendor") <- character(0)`; key absent; no warning |
| E18d | Length-2 raw attribute dropped silently | `attr(df, "vendor") <- c("a", "b")`; key absent; no warning |
| E18e | Reversed raw date pair dropped silently | both dates read as `as.Date(NA)`; no warning |
| E19 | Legacy `dates` on read | `attr(df, "dates") <- "April-May 2024"`; `extract_field_period(df)` returns it; `extract_dataset_metadata(df)` shows the key as `field_period` (no key named `dates`) |
| E20a | Explicit `field_period` wins | both attributes present with different strings; the `field_period` value wins |
| E20b | Invalid `field_period` does NOT fall back to `dates` | `attr(df, "field_period") <- 1L` plus a valid `dates` string; `extract_field_period(df)` is `NA_character_` — the legacy fallback runs only when the `field_period` attribute is absent |
| E21 | Unrecognized attribute invisible | `attr(df, "mode") <- "web"`; `extract_dataset_metadata(df)` omits it entirely; no warning (surveycore claims only the seven recognized names) |
| E22 | 0-row data frame | attributes read normally on a 0-row frame |

Old-object extractor behavior is covered by **B1** in §10 (same test file);
no duplicate row here.

Rows added in v2.2:

| ID | Test | Assertions |
|---|---|---|
| SR1 | Sibling fill regression (§4 regression guard) | `extract_var_label(d, fill = NA)` still errors `surveycore_error_fill_invalid` with its existing two-value message (plain `NA` is widened for the dataset extractor only); `_snaps/metadata-system.md` is byte-identical |
| X1 | `exact = TRUE` on the attribute read | data-frame mode: `attr(df, "vend") <- "x"` and `attr(df, "field_st") <- "2026-02-10"`; `extract_dataset_metadata(df)` omits both — no partial attribute matching occurs |
| E23 | Invalid legacy `dates` dropped silently on read | `attr(df, "dates") <- 1L`, `character(0)`, and `c("a", "b")` (one block each): `extract_dataset_metadata(df)` omits `field_period`; `expect_no_warning` (extractors never warn; the invalid-legacy-`dates` classification runs on the silent path) |

Rows added in v2.3:

| ID | Test | Assertions |
|---|---|---|
| X14 | Completed unknown-key rendering through the extractor | `extract_dataset_metadata(d, Vendor)` → dual pattern, `surveycore_error_dataset_key_unknown`; the snapshot shows the "Did you mean" hint bullet together with the "Valid keys:" bullet — the extractor path renders the same completed message form as the setter path |

## 8. Construction promotion tests (`test-constructors.R`)

Each block constructs a design, so `test_invariants(design)` leads. The
observable contract: build a data frame with attributes (via
`make_dataset_df()` or bare `attr()<-`), construct, then assert on the
design's extractors and on the untouched input.

| ID | Test | Assertions |
|---|---|---|
| P1 | Six keys promote (`as_survey()`) | set all six attributes via the exported setter on the data frame; construct; all six extract from the design, values identical; `field_start`/`field_end` are `Date` |
| P2 | Legacy raw attributes promote | bare `attr(df, "data_name")` and `attr(df, "vendor")` (no setter); construct; both extract — the pre-1.2.0 `adldata` shape works with no edit |
| P3 | No derivation | `survey_name` attribute only; construct; `extract_data_name(d)` is `NA_character_` and `extract_survey_name(d)` is the value |
| P4 | No reverse derivation | `data_name` only; `extract_survey_name(d)` is `NA_character_` |
| P5 | Legacy `dates` → `field_period` | `attr(df, "dates") <- "April-May 2024"`; construct; `extract_field_period(d)` identical; no key named `dates` on the design |
| P6a | Explicit `field_period` beats `dates` | both attributes set with different strings; the `field_period` string wins; no warning |
| P6b | Invalid `field_period` blocks the fallback | `attr(df, "field_period") <- 1L` plus a valid `dates` string; construction warns (`_dropped`, wrong-type variant) and `extract_field_period(d)` is `NA_character_` — `dates` is NOT consulted when the `field_period` attribute is present |
| P7 | ISO string dates coerce at construction | `attr(df, "field_start") <- "2026-02-10"`; construct; extracted value is `as.Date("2026-02-10")` |
| P8 | Wrong type warns and skips | `attr(df, "vendor") <- 1L`; `expect_warning(class = "surveycore_warning_dataset_metadata_dropped")` wrapping construction + message snapshot; design valid (`test_invariants`); `extract_vendor(d)` is `NA_character_`; other attributes still promote |
| P9 | Unparseable date warns and skips | `attr(df, "field_start") <- "sometime"` and, in a second block, `"2026-02-30"`; warning class as P8; construction succeeds; no base date-parsing error surfaces |
| P10 | Reversed date pair warns, drops both | start attr after end attr; ONE warning (reversed-pair message variant, snapshot); construction succeeds; `extract_field_dates(d)` is the all-NA pair |
| P11 | Zero-length value warns and skips | `attr(df, "vendor") <- character(0)`; `expect_warning(class = "...dropped")` (zero-length message variant, snapshot); key absent after construction |
| P12 | Invalid legacy `dates` warns with the period remedy | `attr(df, "dates") <- 1L`, no `field_period` attribute; warning snapshot must point at `set_field_period()` |
| P13 | Full round trip | `expect_dataset_roundtrip(make_survey_data(seed = 1), as_survey)` — all six keys, identical values, canonical order |
| P14 | No attributes → no change | plain data frame; construct; `extract_dataset_metadata(d)` is `list()`; no warning |
| P15 | Unrecognized attribute ignored entirely | `attr(df, "mode") <- "web"` plus valid recognized attributes; construct with `expect_no_warning`; `mode` is neither promoted nor mentioned |
| P16 | Replicate constructor promotes | as P1 through the replicate constructor (`make_survey_data(design = "replicate")`) |
| P17a | Nonprob constructor promotes dataset metadata | as P1 through the nonprob constructor |
| P17b | Nonprob constructor now promotes weighting history | a non-empty `weighting_history` list attribute on the input appears in the design's weighting history — the previously missing promotion is fixed |
| P18 | Two-phase inherits | build phase-1 data with dataset attributes; construct the two-phase design; all keys extract from the two-phase object |
| P19a | `svydesign` import stays empty | `skip_if_not_installed("survey")`; convert a `svydesign` object in; `extract_dataset_metadata()` is `list()`; print succeeds |
| P19b | `tbl_svy` import stays empty | `skip_if_not_installed("srvyr")`; convert a `tbl_svy` object in via the tbl_svy converter; `extract_dataset_metadata()` is `list()`; print succeeds |
| P20 | Promotion is non-destructive; resurrection locked | construct from a frame with a `vendor` attribute; `attributes(d@data)` still carry the original value; then `set_vendor(d, "Cint")` and rebuild with `as_survey(d@data, ...)`: the rebuilt design's vendor is the ORIGINAL value — the documented resurrection behavior |
| P21 | Haven-label coexistence | `make_survey_data(with_labels = TRUE)` plus dataset attributes; construct; variable labels AND all dataset keys both promote; neither interferes with the other |
| P22 | Attribute loss on base subsetting (documented) | set dataset attributes, then `df[df$y3 == 1, ]`, then construct: no dataset metadata, no warning — locks the documented persistence limit |

Rows added in v2.2:

| ID | Test | Assertions |
|---|---|---|
| X7 | Zero-length legacy `dates` warns with the period remedy | `attr(df, "dates") <- character(0)`, no `field_period` attribute; construction warns `surveycore_warning_dataset_metadata_dropped` (DM-7d variant; snapshot points at `set_field_period()`); construction succeeds; return value captured and asserted |
| X8 | Length-2 legacy `dates` warns with the period remedy | `attr(df, "dates") <- c("a", "b")`; same class, same DM-7d variant; construction succeeds; return value captured and asserted |

Rows added in v2.3:

| ID | Test | Assertions |
|---|---|---|
| X12 | `as_tbl_svy()` leaves dataset metadata unchanged | `skip_if_not_installed("srvyr")`; on a design carrying `full_keys`, `as_tbl_svy(d)` raises no error, and `extract_dataset_metadata(d)` afterwards is identical to the pre-call result — the third named no-change conversion surface |

## 9. Print and summary snapshots (`test-methods-print.R`)

Fixed seed; small `n`; designs built with `make_dataset_design(design, state)`.

States: **(a)** no dataset metadata; **(b)** `data_name` only; **(c)**
`survey_name` only (no `data_name`).

**The grid.** Every cell below is a test. `S` = `expect_snapshot()` on the
full console output; `N` = `expect_no_error()` (behavior covered by an `S`
cell of another class, since the dataset lines are class-independent).

| Method × state | taylor | replicate | twophase | nonprob |
|---|---|---|---|---|
| `print(d)` (a) | S — byte-identical to the existing snapshot (file must not change) | S (existing) | S (existing) | S (existing) |
| `print(d)` (b) | S | S | S (line sits between the class line and `Phase 1 sample size:`) | S (no-repweights branch: line directly after the variance bullet, before `Sample size:`) |
| `print(d)` (c) | S (header shows `survey_name`) | N | N | N |
| `print(d, metadata_info = TRUE)` (a) | S — byte-identical to pre-feature output | N | N | N |
| `print(d, metadata_info = TRUE)` (b) | S | S | N | N |
| `print(d, metadata_info = TRUE)` (c) | S (no `Survey:` line in the block — the header already printed it) | N | N | N |
| `print(d, full = TRUE)` (a) | S — existing snapshot must not change | S (existing) | N | N |
| `print(d, full = TRUE)` (b) | S | N | N | S (the nonprob method wires `full` differently — must be exercised directly) |
| `print(d, full = TRUE)` (c) | S (fallback header inside the `full` layout) | N | N | N |
| `summary(d)` (a) | S (existing) | S (existing) | S (existing) | S (existing) |
| `summary(d)` (b) | S (`Dataset:` line after the blank line, directly above the `Metadata:` line) | S | S | N |
| `summary(d)` (c) | S (summary uses the same `survey_name` fallback) | N | N | N |

Additional snapshot blocks (all on `survey_taylor` unless named):

| ID | Test |
|---|---|
| PR1 | `print(d, metadata_info = TRUE)` with `full_keys`: block shows `Survey:`, `Vendor:`, and `Field dates: 2026-02-10 to 2026-03-04 (February-March 2026)` above the labeled-count line; header shows `data_name`; the survey name appears on exactly one line of the whole output |
| PR2 | `metadata_info = TRUE` with `field_period` only (no structured dates): `Field dates:` line shows the prose period alone |
| PR3 | `metadata_info = TRUE` with a lone `field_start`, no period: `Field dates: 2026-02-10 to ?` |
| PR4 | `metadata_info = TRUE` with a lone `field_end` plus a period: `Field dates: ? to 2026-03-04 (February-March 2026)` |
| PR5 | Drifted names: `survey_name` and `data_name` both set to unrelated strings; both visible (header + `Survey:` line); locks the drift-is-visible contract |
| PR6 | Identical names: `survey_name` and `data_name` set to the SAME string; the string appears on exactly one line (`Dataset:`); no `Survey:` line |
| PR7 | Nonprob WITH replicate weights (`make_dataset_design("nonprob_rep", "data_name")`): `Dataset:` line directly after the class line (no variance bullet in this branch), before `Sample size:` |
| PR8 | Hostile name snapshot: a `data_name` containing `{braces}`, an embedded newline, and > 60 characters — print succeeds; braces render literally; the newline renders as a space; the value truncates to 57 characters plus a trailing `...` (60 total) |
| PR9 | Old restored objects, all eight methods. For EACH of the four design classes, build `make_stale_metadata_design(design)` and run four calls: `print(old)`, `print(old, metadata_info = TRUE)`, `print(old, full = TRUE)`, `summary(old)` — 4 classes × 4 calls = 16 calls, reaching all four print methods and all four summary methods. Each succeeds with no dataset lines. Snapshot the taylor `print(old)` call; `expect_no_error` for the other fifteen |
| PR10 | Both dates set, NO period: `Field dates: 2026-02-10 to 2026-03-04` with no parenthetical — locks the composition without the period suffix |
| X9 | (added in v2.2) Hostile block values: a `vendor` and a `survey_name` each containing `{braces}`, `\n`, `\r`, and `\t`, rendered through `print(d, metadata_info = TRUE)` — print succeeds; braces render literally; each control character renders as a space; per-value truncation to 57 characters plus `...` applies on the block path as well as the header path |

Snapshot review policy per testing-standards: no blind acceptance; any state
(a) failure means the feature broke existing output, which blocks the PR.

## 10. Backward compatibility (old serialized objects)

Mechanism: `make_stale_metadata_design()` (§2) builds the stale object **at
runtime** from a locally defined S7 class carrying the original eleven
metadata properties. No committed `.rds` fixture is used, so the test cannot
rot when unrelated class internals change.

| ID | Test | Assertions |
|---|---|---|
| B0 | Fixture guard | the fixture's metadata object genuinely lacks the property: `"dataset_metadata" %in% S7::prop_names(old@metadata)` is `FALSE` — if this guard fails, every other §10 test is meaningless |
| B1 | Reads return empty | `extract_dataset_metadata()` returns `list()`; the four scalar extractors return `NA_character_`; `extract_field_dates()` returns the all-NA pair |
| B2 | Writes raise the typed error | `set_vendor(old, "x")` → dual pattern with class `surveycore_error_dataset_metadata_unavailable` (snapshot locks the rebuild-with-`as_survey()` remedy); class check for the other five setters |

Old-object print and summary behavior is covered ONLY by **PR9** in §9
(`tests/testthat/test-methods-print.R`); this section carries no print or
summary rows, so no stale-object console output is snapshotted in two files.

## 11. Tolerances

The default surveycore tolerance table (point `1e-10`, SE `1e-8`, CI bounds
`1e-6`) is retained for reference but **does not apply**: this feature
computes no estimand, so no test uses a numeric tolerance. All value
assertions are exact (`expect_identical`), including `Date` values, key
order, and ISO-formatted date strings.

## 12. Coverage and invariants

- Every error/warning class in §4 — including the reused convention,
  format, and fill classes — has at least one test; Layer-3 classes use the
  dual pattern; validator-path triggers are class-only. Every class in this
  plan must exist in the package's canonical error table.
- Assertions target observable contracts only: exported functions, exported
  attributes read with `attr()`, condition classes, and console output. No
  test reaches into internal helpers or asserts on internal storage shape
  beyond the exported extractors.
- Every edge case in the feature contract has a row above: empty list,
  0-row and single-row data frames, deletion of an absent key, bulk
  deletion, lone date, single-date print, unparseable and non-strict-ISO
  dates, reversed dates (set, stored, raw), zero-length values (write, raw
  read, promotion), unknown keys (plain, near-miss, legacy `dates`,
  column-name), drifted and identical names, hostile print values,
  unrecognized attributes, old objects, collection input.
- 98%+ line coverage on the new code; PRs blocked below 95%.
- `test_invariants(design)` first in every constructing block (§5–§10 as
  applicable).

## 13. Profile gates

All gates must pass before merge:

- [ ] `document` — `devtools::document()` clean; NAMESPACE and man/ in sync
- [ ] `test` — `devtools::test()` all passing, no skips except guarded
      `skip_if_not_installed()`
- [ ] `run_examples` — `devtools::run_examples()` clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `pkgcheck` — passing
- [ ] `pkgdown` — site builds; new functions appear in their reference
      sections
- [ ] `covr` — coverage at or above target; no uncommented `# nocov`
