# Comprehension — haven-labelled (issue #175)

**Stage**: 0 (Deep Comprehension). No spec, no test-spec.
**Written**: 2026-08-27, against the worktree `haven-labelled` at `cf6f153`.
**Inputs treated as fact**: `audit-empirical.md`, `decisions.md` D1 and D2.
**Method**: source reading only. I had no Bash tool and ran no R. Every claim
about existing behaviour carries a file and line. Claims that need a running
R process sit under `## Open — needs measurement`.

This request is a type-dispatch defect, not a change to a statistical
formula. Section 2 replaces the template's "Formulas" section with a
mechanism and boundary analysis, as instructed.

---

## 1. Problem

A column read from SPSS, Stata or SAS through `haven` carries the class
`c("haven_labelled", "vctrs_vctr", "double")`. `surveycore` stores that
column unchanged in `@data`. The analysis layer then does ordinary
arithmetic, comparison and coercion on it. `vctrs` is always loaded, because
`tibble` and `dplyr` import it, so `vctrs` S3 methods intercept those
operations. The methods that make them work live in `haven`, and `haven` is
in `Suggests`, so it is usually absent. Twelve of seventeen entry points
therefore abort with a raw `vctrs` error
(`audit-empirical.md` §4). D1 removes the cause: the constructors drop the
`haven_labelled` class from `@data` columns and keep the `labels`
attribute, so `@data` holds only base types and no `vctrs` method can fire.
D2 fixes a second, independent defect that D1 does not reach: the
polychoric and polyserial gate classifies a value-labelled scale as
continuous and refuses it.

Two facts frame the whole design:

- **D1 is not a new policy.** Every bundled dataset already applies exactly
  this strip by hand in `data-raw/`, keeping `label` and `labels`
  (`data-raw/prepare-gss-2024.R:98-109`,
  `data-raw/prepare-anes-2024.R:95`, `data-raw/prepare-pew-npors-2025.R:91`,
  `data-raw/prepare-pew-jewish-2020.R:140`,
  `data-raw/prepare-nationscape-helpers.R:10`,
  `data-raw/download-nhanes.R:105`). D1 moves that convention from the data
  preparation scripts into the constructor.
- **D2 is a classification change only.** The threshold estimator already
  accepts a plain numeric ordinal vector
  (`R/analysis-corr-latent.R:225-227`, `match(ordinal_vec, all_levels)`).
  Nothing downstream of the gate needs new machinery.

---

## 2. Mechanism and boundaries

### 2.1 The class vectors in play

Confirmed from the upstream sources, not guessed:

| Constructor | Class vector |
|---|---|
| `haven::labelled()` | `c("haven_labelled", "vctrs_vctr", <base type>)` |
| `haven::labelled_spss()` | `c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", <base type>)` |

`haven/R/labelled.R` builds this with
`new_vctr(x, labels = labels, label = label, ..., class = c(class,
"haven_labelled"), inherit_base_type = TRUE)`. The
`inherit_base_type = TRUE` argument appends the base type, which is why the
audit's hand-built fixture is byte-identical to a `read_sav()` column
(`audit-empirical.md` §Method). `haven/R/labelled_spss.R` calls
`new_labelled(..., class = "haven_labelled_spss")`, so the SPSS variant is a
subclass.

`haven` itself defines `is.labelled <- function(x) inherits(x,
"haven_labelled")`. D1's proposed test is the same test the upstream package
uses.

### 2.2 The precondition, restated

Per `audit-empirical.md` §1 the failure needs `vctrs` loaded and `haven`
absent. Note that `vctrs` is **not** in `Imports`
(`DESCRIPTION:37-48`); it arrives through `tibble` and `dplyr`. That is a
transitive dependency the package does not control, so the precondition
cannot be removed from the other side.

### 2.3 What the strip does and does not touch

D1's form is `attr(x, "class") <- NULL`. It removes the class attribute and
leaves every other attribute in place: `label`, `labels`, `na_values`,
`na_range`, `format.spss`, `display_width`. That is stricter than the
`data-raw/` form, which calls `as.vector(x)` and then re-attaches only
`label` and `labels` (`data-raw/prepare-gss-2024.R:101-106`), losing the
rest. D1's form is the better of the two.

### 2.4 Where the failures actually sit — two worked examples

The audit's §3 asymmetry, verified by reading:

| File | Line | Expression | Class of the operand |
|---|---|---|---|
| `R/analysis-totals-helpers.R` | 36 | `y_safe <- ifelse(domain > 0, y_all, 0)` | `ifelse()` strips |
| `R/analysis-totals-helpers.R` | 96 | `y_domain <- y_safe[domain > 0]` | plain numeric — OK |
| `R/analysis-means-helpers.R` | 70 | `y_safe <- ifelse(domain > 0, y_all, 0)` | `ifelse()` strips |
| `R/analysis-means-helpers.R` | 115 | `y_domain <- y_all[domain > 0]` | still labelled — FAILS at `:117` |

`R/analysis-means-helpers.R:117` is `s2 <- sum((y_domain - ybar)^2) / (n_d -
1L)`. `R/analysis-totals-helpers.R:97-99` reaches the same subtraction with
a stripped operand. Confirmed: `get_totals()` is correct by accident, and
one edit to the variable name at `R/analysis-means-helpers.R:115` would move
the defect.

The `get_freqs()` route is `R/analysis-freqs.R:301` calling `.get_levels()`,
which at `R/analysis-freqs-helpers.R:39-41` runs
`sort(unique(x_col[!is.na(x_col)]))` and then `c(non_na, NA)`. Base `[`
keeps the class under `vctrs`, so both expressions see a labelled operand.

---

## 3. Every route that puts data into `@data`

### 3.1 Routes inside this repo

| # | Route | File:line | Writes `@data`? | Can introduce an unstripped column? |
|---|---|---|---|---|
| 1 | `as_survey()` | `R/core-constructors.R:171`; `survey_taylor(data = data, ...)` at `:557` | yes | **yes** — the `data` argument |
| 2 | `as_survey_replicate()` | `R/core-constructors.R:694`; `survey_replicate(data = data, ...)` at `:816` | yes | **yes** — the `data` argument |
| 3 | `as_survey_twophase()` | `R/core-constructors.R:925`; `data <- phase1@data` at `:955`; `survey_twophase(data = data, ...)` at `:1123` | yes | no, if route 1/2/4 stripped. `phase1` must be a `survey_base` (`:937-953`) |
| 4 | `as_survey_nonprob()` | `R/core-constructors.R:1339`; `survey_nonprob(data = data, ...)` at `:1625` | yes | **yes** — the `data` argument |
| 5 | `as_survey_collection()` | `R/core-constructors.R:1720` | no — writes `@surveys`; reads `first_member@data` at `:1767` and `member@data` at `:1795` | no |
| 6 | `add_survey()`, `remove_survey()` | `R/survey-collection.R:357`, `:484` | no — no `@data` write anywhere in that file | no |
| 7 | `update_design()` | `R/update-design.R:88` | no — writes `@variables` only, at `:163` and `:213` | no |
| 8 | `from_svydesign()` | `R/methods-conversion.R:345`; `.from_svydesign_taylor` at `:382` and `:416`; `.from_svydesign_replicate` at `:427` and `:450`; `.from_svydesign_twophase` at `:462` and `:502` | yes | **yes** — `as.data.frame(x$variables)` at `:382` and `:427`. Does not go through routes 1-4 |
| 9 | `from_tbl_svy()` | `R/methods-conversion.R:540`, delegates at `:575` | via route 8 | via route 8 |
| 10 | Post-construction `@data` writes in `R/` | `R/analysis-diffs.R:282`, `:360-367`; `R/analysis-t-test.R:210`, `:314`, `:315`, `:771`, `:810`, `:814`; `R/analysis-quantiles-helpers.R:187`; `R/analysis-ratios-helpers.R:106` | yes | no — every assigned value is a factor, a logical mask, or a computed numeric |
| 11 | Direct S7 construction | `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, `survey_base` are all exported (`NAMESPACE:104-113`) | yes | **yes** — `survey_taylor(data = labelled_df, ...)` bypasses routes 1-4 entirely |

**There is no single choke point among routes 1-11.** Routes 1, 2, 4, 8 and
11 each accept a caller-supplied data frame and each reaches an S7
constructor independently. A strip written only in `as_survey()` leaves four
routes open.

### 3.2 The route outside this repo

`surveytidy` (Suggests, `>= 0.5.0`) owns every dplyr verb for survey
objects. No `mutate`, `select`, `rename`, `filter`, `subset` or `bind_rows`
method exists in `R/`: the only `S7::method()` registrations are `print`,
`summary`, `names`, `length` and `[[`
(`R/methods-compat.R:23`, `R/methods-print.R:204-979`). `surveycore` exposes
`.get_design_vars_flat()` (`R/utils.R:251`), `SURVEYCORE_DOMAIN_COL`
(`R/utils.R:123-124`), `.get_design_vars()` (`R/utils.R:294`) and
`.delete_metadata_col()` (`R/core-validators.R:503`) for it.

`surveytidy::mutate()` can therefore write a labelled column into `@data`
after construction, and a strip inside `surveycore`'s constructors cannot
stop it. The same is true of route 11.

### 3.3 The one design that IS a choke point

An S7 property setter on `@data` covers routes 1-11 **and** the `surveytidy`
route, because every path must assign the property. The `data` property is
declared at `R/core-classes.R:305-308`:

```r
data = S7::new_property(
  S7::class_data.frame,
  default = quote(data.frame())
),
```

`S7::new_property()` accepts a `setter`, which runs before the class
validator. One `inherits()` test per column per assignment is cheap. Two
open questions decide whether this is viable, both under §8: whether an S7
setter runs during construction as well as on `@<-` assignment (M4), and
whether the extra setter call on the ten post-construction `@data` writes in
route 10 costs anything measurable.

If the setter route is not viable, the strip needs **five** call sites:
routes 1, 2, 4, 8 (three helper functions) and — if it is to be closed at
all — a documented normaliser that `surveytidy` calls. Per
`.claude/rules/code-style.md`, a helper used in two or more files belongs in
`R/utils.R`.

### 3.4 Ordering constraint inside the constructors

The strip must run **before** the first arithmetic or coercion on a design
column, not just before the S7 call. Sites that already fail today on a
labelled design column, found by reading:

| Site | Expression | Reached when |
|---|---|---|
| `R/core-constructors.R:247` | `computed_wt <- 1 / data[[probs_var]]` | `probs` and `weights` both given |
| `R/core-constructors.R:273` | `data[[weights_var]] <- 1 / data[[probs_var]]` | `probs` only |
| `R/core-validators.R:152` | `all(non_na == 0)` | always, via `.validate_weights()` |
| `R/core-validators.R:170` | `sum(non_na <= 0)` | always |
| `R/core-validators.R:346-347` | `as.character(data[[ids[[1L]]]])` | `ids` and `strata` set, `nest = FALSE` |
| `R/core-classes.R:470` | `sum(!is.na(wt_col) & wt_col <= 0)` | S7 validator, always |
| `R/core-classes.R:496-497` | `as.character(self@data[[ids_vars[[1L]]]])` | S7 validator, `nest = FALSE` |
| `R/methods-conversion.R:298` | `as.numeric(col)` inside `.find_col_by_value()` | `from_svydesign()` when the weight column must be found by value |

The audit did not probe a labelled **weight**, **PSU**, **stratum** or
**FPC** column — its fixture labelled only outcome columns
(`audit-empirical.md` §Method). These eight sites are therefore untested
failure paths. Items M5, M7 and M8 in §8 confirm them.

The earliest safe insertion point in `as_survey()` is immediately after
`.validate_data_frame(data)` at `R/core-constructors.R:184`. The same
position applies in `as_survey_replicate()` and `as_survey_nonprob()`
(`R/core-constructors.R:1353`).

The S7 validator cannot do the strip: a validator returns a message, it does
not mutate `self`.

---

## 4. Code that depends on the labelled class being present

### 4.1 Nothing in `R/` branches on the class

A grep for `haven_labelled`, `haven_labelled_spss`, `"labelled"` and
`vctrs_vctr` across the whole repository returns **zero hits in `R/`**. The
only hits are the six `data-raw/` strip helpers and one archive document
(`archive/phase-0/surveycore-phase0-formal-specification.md:1152`). No
`vctrs::vec_ptype` call exists in `R/`. So no explicit class test changes
its answer.

### 4.2 Type predicates — the answers that could change

| Predicate | Call sites that matter | Answer today (labelled double) | Answer after D1 | Changes? |
|---|---|---|---|---|
| `is.numeric()` | `R/analysis-corr.R:296` (pearson drop), `R/analysis-covariance.R:208`, `R/analysis-diffs.R:263`, `R/core-validators.R:139`, `:309`, `R/core-classes.R:457`, `R/methods-conversion.R:294` | **TRUE** — inferred, see below | TRUE | no |
| `is.double()` | `R/analysis-corr-latent.R:55`, `R/analysis-helpers.R:251`, `:264`, `:287` | TRUE (M2) | TRUE | no |
| `is.integer()` | `R/analysis-corr-latent.R:48`, `:225` | FALSE for a labelled double; TRUE for a labelled integer (M13) | same | no |
| `is.atomic()` | `R/core-classes.R:437`, `:641`, `R/core-validators.R:218` | TRUE (M2) | TRUE | no |
| `is.factor()` | `R/analysis-corr-latent.R:45`, `:222`, `:1707`, `:1724`, `R/analysis-diffs.R:276`, `R/analysis-freqs-helpers.R:27`, `R/analysis-helpers.R:157` | FALSE | FALSE | no |
| `is.ordered()` | `R/analysis-corr-latent.R:42`, `:1707`, `:1724` | FALSE | FALSE | no |
| `is.logical()` | `R/core-constructors.R:997`, `R/core-classes.R:788` | FALSE | FALSE | no |
| `class(col)[[1L]]` in messages | `R/analysis-corr-latent.R:1682`, `R/analysis-diffs.R:268`, `R/core-validators.R:316` | `"haven_labelled"` | `"numeric"` | **yes — message text only** |

**The `is.numeric()` answer, established by inference.** The audit measured
`get_diffs(inc7, gender)` failing with `vctrs_error_cast`, not with
`surveycore_error_non_numeric_variable` (`audit-empirical.md` §4).
`R/analysis-diffs.R:263` is `if (!is.numeric(x_col))` and raises
`surveycore_error_non_numeric_variable`. `inc7` passed that gate and failed
later, at `R/analysis-diffs.R:281` (`as.factor(treats_col)`) or `:286`
(`as.character(...)`). Therefore `is.numeric()` returned TRUE on the
labelled double, with `vctrs` loaded and `haven` absent. M1 confirms it
directly.

The last row is the only change, and it is an improvement: an error message
that today reads `<haven_labelled>` will read `<numeric>`. No test asserts
the old string, because no test builds a labelled-class column (§7.3).

### 4.3 `classify_question_type()` — passes for a reason unrelated to the class

`classify_question_type()` (`R/core-metadata.R:3473`) never reads a column
value or a column class. It reads `question_prefaces`
(`:3544-3548`) and `sata` (`:3560-3564`), from `@metadata` on a survey
object or from whole-column attributes on a data frame. It returns
`"single"`, `"sata"` or `"battery"`. D1 does not change its answer.

Consequence for D2: `classify_question_type()` carries **no** information
about whether a variable is an ordinal scale. It is not a usable signal.

### 4.4 `R/analysis-helpers.R:243` — what still needs `haven`

```r
haven_ok <- requireNamespace("haven", quietly = TRUE)
```

Inside `.apply_group_labels()`. It is used at three places:

- `:252` `haven::na_tag(lv)` — build the tag-to-label map from the value
  labels;
- `:266` `haven::na_tag(val)` — resolve a tagged NA in the group column to
  its label;
- `:290` `is.na(haven::na_tag(x))` — decide which label entries are plain
  NAs rather than tagged NAs.

All three read the NaN payload of a double. A tagged NA is a plain double
NaN with a payload; `decisions.md` measured the byte pattern and the tag as
identical before and after the strip. So all three **still need** `haven`
after D1, and all three still work on a stripped column.

What no longer needs `haven`: correctness anywhere else. The labels
themselves come from `design@metadata@value_labels[[gv]] %||% attr(src_col,
"labels", exact = TRUE)` (`:232-233`), which is base R. `src_col` is the
full column `design@data[[gv]]` (`:230`), never a subset, so the
attribute-drop rule in §5.4 does not bite.

The load-bearing side effect the audit found (`audit-empirical.md` §2)
disappears on its own: after D1 there is no labelled class left for
`haven`'s registered `vctrs` methods to act on.

### 4.5 The `labels` attribute readers, and where subsetting bites

Base R `[` drops the `labels` attribute on a subset. That is measured
(`decisions.md` §D1 consequences). Under `vctrs`, `[.vctrs_vctr` keeps it,
so D1 changes the behaviour of a subset. Every reader in `R/`, checked:

| Reader | Line | Reads from | Safe? |
|---|---|---|---|
| `.extract_var_meta()` | `R/analysis-helpers.R:150`, `:155` | `design@data[[var_name]]` — full column (`:147`) | yes |
| `.apply_group_labels()` | `R/analysis-helpers.R:233` | `design@data[[gv]]` — full column (`:230`) | yes |
| `.extract_haven_metadata()` | `R/core-metadata.R:3732`, `:3744` | `data[[col_name]]` — full column (`:3728`) | yes |
| `set_val_labels()` | `R/core-metadata.R:2424-2429` | `x@data[[var_name]]` — full column | yes |
| `extract_var_label()` | `R/core-metadata.R:517` | data-frame branch only | yes |
| `extract_val_labels()` | `R/core-metadata.R:581` | data-frame branch only | yes |
| `extract_metadata()` | `R/core-metadata.R:986-991` | data-frame branch only | yes |
| `infer_question_prefaces()` | `R/metadata-infer.R:25`, `:48` | `x@data[[col_name]]` / `x[[col_name]]` — full column | yes |
| covariance / variance group label | `R/analysis-covariance-helpers.R:652`, `R/analysis-variance.R:526` | `design@data[[nm]]` — full column | yes |

No reader in `R/` reads a label attribute off a subset. The subset sites
that exist — `R/glm.R:963` `design@data[domain_mask, , drop = FALSE]`,
`R/variance-twophase.R:240`, `R/analysis-quantiles-helpers.R:86`,
`R/analysis-helpers.R:1082` — feed model fitting and variance code, none of
which reads labels.

---

## 5. Observable contract changes and round trips

### 5.1 `survey_data()`

`survey_data()` returns `@data` unchanged (`R/utils.R:70-81`). The `data`
property is typed `S7::class_data.frame` (`R/core-classes.R:305-308`), so a
tibble passes and is stored as a tibble. A tibble prints a `<hvn_lbl>`
column header today and will print `<dbl>` after D1. That is the observable
change the audit names.

### 5.2 `as_svydesign()` and `as_tbl_svy()`

`.as_svydesign_taylor()` passes `data = x@data`
(`R/methods-conversion.R:110`); the replicate and two-phase variants do the
same (`:145`, `:187`). `survey::svydesign()` stores `$variables` as given.
So `as_svydesign(d)$variables` loses the labelled class after D1 and keeps
the `labels` attribute. `as_tbl_svy()` wraps `as_svydesign()`
(`R/methods-conversion.R:259`), so it inherits the change.

### 5.3 `from_svydesign()` and `from_tbl_svy()` — a pre-existing metadata loss

`.from_svydesign_taylor()` builds `data <- as.data.frame(x$variables)`
(`R/methods-conversion.R:382`) and then constructs with
`metadata = survey_metadata()` — an **empty** metadata object
(`:419`). `.from_svydesign_replicate()` does the same (`:453`), and
`.from_svydesign_twophase()` too (`:505`). None of the three calls
`.extract_haven_metadata()`.

Two consequences:

- Today, `from_svydesign()` on a design built from a haven-read frame keeps
  the labelled class in `@data` **and** loses every label out of
  `@metadata`. Both defects, at once, in one function.
- After D1's strip, the labels survive as column attributes, and the
  `.extract_var_meta()` fallback (`R/analysis-helpers.R:154-155`) still
  resolves them. So D1 partly repairs this route by accident.

Calling `.extract_haven_metadata(data)` in the three `from_svydesign`
helpers is the DRY fix and closes the gap properly. It is arguably a
separate bug; the spec should decide whether to take it here.

Round trip `as_survey(labelled_df) |> as_svydesign() |> from_svydesign()`:
labels survive on the columns in both directions, `@metadata` is empty on
the return leg. That is unchanged by D1 unless the previous paragraph is
adopted.

### 5.4 The metadata extractors

On a **survey object** every extractor reads `@metadata` only:

- `extract_var_label()` — `R/core-metadata.R:514-515`
- `extract_val_labels()` — `R/core-metadata.R:578-579`
- `extract_metadata()` — `R/core-metadata.R:973-983`
- `extract_missing_codes()` — `R/core-metadata.R:858`
- `extract_higher_is()` — `R/core-metadata.R:3191`

On a **data frame** each reads the column attribute
(`:517`, `:581`, `:986-991`, `:860`, `:3193`). D1 does not touch data
frames, only `@data` inside a constructed survey object. **No extractor
changes its output.** `.extract_haven_metadata()` already harvests
`attr(col, "labels")` at construction (`R/core-metadata.R:3744-3752`), so
`@metadata@value_labels` is populated before the strip matters.

One writer needs attention: `set_val_labels()` validates the new labels
against the stored column with `.validate_val_labels()`
(`R/core-metadata.R:2429`), which runs
`as.character(unique_vals)` at `R/core-metadata.R:3675`. On a labelled
column that is `as.character(<haven_labelled>)`, which the audit shows
raising `vctrs_error_cast` elsewhere. So `set_val_labels()` on a survey
design that holds a labelled column looks like an **unreported failing entry
point**. D1 removes it. M6 confirms.

### 5.5 Snapshot files that churn

The honest answer for D1 alone: **none**.

- No test in `tests/testthat/` builds a column with the `haven_labelled`
  class. The only labelled-looking fixtures set the attributes on a plain
  vector: `tests/testthat/helper-test-data.R:539-549`, and
  `tests/testthat/test-analysis-freqs.R:1455-1462` (a plain double plus
  `haven::tagged_na()`, which returns a plain double NaN). Same shape in
  `test-analysis-means.R:766-774`, `test-analysis-totals.R:578-586`,
  `test-analysis-ratios.R:995-1003`,
  `test-analysis-quantiles.R:1043-1051`,
  `test-analysis-corr.R:1180-1188`,
  `test-analysis-helpers.R:1343-1344`.
- No bundled dataset carries the class — `data-raw/` strips it (§1).

So `.strip_labelled_class()` is a no-op on every current test input, and no
committed snapshot output can move.

Snapshot files that churn **only if the spec adds a message**:

| Snapshot file | Churns when |
|---|---|
| `tests/testthat/_snaps/constructors.md` | a warning fires at construction when the strip runs |
| `tests/testthat/_snaps/methods-print.md` | a new labelled fixture is added to a print snapshot |
| `tests/testthat/_snaps/metadata-system.md` | `set_val_labels()` messages change |
| `tests/testthat/_snaps/utils.md` | a `survey_data()` snapshot gains a labelled fixture |

D2's PC-1 and PC-2 messages live in `test-analysis-corr-latent.R:617-620`
and `test-analysis-corr-latent-variance.R:482-485`.

**Corrected 2026-08-28.** An earlier version of this section said neither
snapshot file exists, and called that a hygiene finding. Both claims were
wrong, and the cause was mine.

Ground truth, from `git ls-tree` and `git grep` against `origin/develop`:

| File | Committed in `develop` | Carries the PC-1 / PC-2 message text |
|---|---|---|
| `_snaps/analysis-corr-latent.md` | **yes** | **yes** |
| `_snaps/analysis-corr-latent-variance.md` | **yes** | **yes** |
| `_snaps/analysis-corr-latent-primitives.md` | yes | yes |

The files were missing from the working tree when this section was drafted
because the fast baseline run had deleted them. `testthat` prunes snapshot
files whose tests did not run, and the fast run
(`NOT_CRAN=false Rscript -e "testthat::test_local()"`) skips the eleven
`skip_on_cran()` files, which includes both correlation files. They have
since been restored with `git checkout`.

**So a D2 message change produces a reviewable snapshot diff, not a "new
snapshot" warning.** The builder must run `testthat::snapshot_review()` on
these three files and inspect each diff. There is no hygiene finding here.

The real finding is the footgun: the documented fast run silently deletes
committed snapshot files for every file it skips. That is worth its own
issue — see `out-of-scope-findings.md`.

### 5.6 Vignettes and examples

No vignette and no roxygen `@examples` block builds a labelled column.
`vignettes/surveycore-vs-survey.Rmd` mentions haven labels at `:40`,
`:247`, `:270`, `:487` and `:619`, always about `ns_wave1`, a bundled
dataset whose class is already stripped. `R/data.R` documents
`attr(col, "labels")` on the bundled datasets at many lines
(`:62-90`, `:265-295`, `:394-424`, `:556-589`, `:806-836`, `:1196-1198`,
`:1302-1305`); every one of those attributes survives D1. Nothing to
update.

---

## 6. The `labelled` package class and `haven_labelled_spss`

### 6.1 What surveycore recognises today

Nothing. `R/` contains no reference to any of the three class names (§4.1).

### 6.2 Is `inherits(x, "haven_labelled")` the right test?

For `haven_labelled` and `haven_labelled_spss`: **yes**. The SPSS variant
lists `haven_labelled` second in its class vector (§2.1), so `inherits()`
catches it. `haven` uses the identical test for `is.labelled()`.

For the `labelled` package: **also yes, for the current version**. The
`labelled` package does not define its own class. Its `NAMESPACE` carries
`importFrom(haven, ..., labelled, labelled_spss, ...)` and re-exports both
(`export(labelled)`, `export(labelled_spss)`). So `labelled::labelled()`
returns a `haven_labelled` object. The package registers 16 S3 methods on
`haven_labelled` and 8 on `haven_labelled_spss`.

A bare `"labelled"` class does exist, but only as a legacy form. The
`labelled` NAMESPACE registers exactly one method on it —
`S3method(update_labelled, labelled)` — and `update_labelled()` is the
function whose job is upgrading pre-2.0 objects. Two properties follow:

- A legacy `"labelled"` vector has no `vctrs_vctr` in its class vector, so
  no `vctrs` S3 method intercepts arithmetic. Base R operates on the
  underlying double, which is the left column of `audit-empirical.md` §1 —
  everything works. So the legacy class probably does **not** trigger the
  26 failing forms.
- It may still change the answer of a type predicate through some other
  registered method. I cannot settle that by reading. M10.

Recommendation for the spec to consider, not a decision: test
`inherits(x, "haven_labelled")` as D1 states, and decide separately whether
to widen it. Widening to `"labelled"` risks catching `Hmisc`-style columns
whose semantics surveycore has never claimed to support.

### 6.3 Does the strip lose anything for `haven_labelled_spss`?

**No.** `attr(x, "class") <- NULL` leaves `na_values` and `na_range` in
place (§2.3, confirm at M9).

But nothing reads them, before or after.
`.extract_haven_metadata()` reads `label`, `labels`, `question_preface`,
`note`, `universe` and `missing_codes`
(`R/core-metadata.R:3732-3791`) — not `na_values`, not `na_range`.
`survey_metadata` has a `missing_codes` property
(`R/core-classes.R:123-126`) but no `missing_values` property.

The Phase 0 specification planned exactly this and it was never built:

> `archive/phase-0/surveycore-phase0-formal-specification.md:1152-1168` —
> "SPSS files read by haven may have additional attributes `na_values` ...
> and `na_range` ... Extract and store these under a new `missing_values`
> key in `@metadata` ... **Note:** This requires adding a `missing_values`
> property to `survey_metadata`."

So `haven_labelled_spss` declared-missing semantics are already ignored on
`develop`. D1 does not make that worse and does not fix it. Whether to build
the planned `missing_values` property here is a scope question for the spec.

---

## 7. D2 — ordinality detection

### 7.1 The current gate, quoted in full

`R/analysis-corr-latent.R:41-66`:

```r
.corr_detect_ordinal <- function(col, integer_cardinality_cutoff = 10L) {
  if (is.ordered(col)) {
    return("ordered")
  }
  if (is.factor(col)) {
    return("factor")
  }
  if (is.integer(col)) {
    n_distinct <- length(unique(col[!is.na(col)]))
    if (n_distinct <= integer_cardinality_cutoff) {
      return("integer_ordinal")
    }
    return("ambiguous")
  }
  if (is.double(col)) {
    non_na <- col[!is.na(col)]
    if (length(non_na) == 0L) {
      return("continuous")
    }
    # Integer-valued doubles with small cardinality are still continuous
    # under the spec's strict reading ("is.double" → "continuous").
    return("continuous")
  }
  # character, logical, complex, raw, list → ambiguous
  "ambiguous"
}
```

The polychoric gate calls it at `R/analysis-corr-latent.R:1671-1672` and
raises `surveycore_error_polychoric_requires_ordinal` at `:1696` when either
side is not in `c("ordered", "factor", "integer_ordinal")`.

Trace for a labelled **double**: `is.ordered` FALSE, `is.factor` FALSE,
`is.integer` FALSE (storage is double), `is.double` TRUE → `"continuous"` →
PC-1. After D1 the column is a plain double and the trace is identical. D1
does not repair D2, exactly as `decisions.md` states.

Trace for a labelled **integer** (`c("haven_labelled", "vctrs_vctr",
"integer")`): `is.integer` TRUE → `"integer_ordinal"` when the distinct
count is at most 10 → **passes today**. So the gap is specific to double
storage. `haven::read_sav()` yields doubles, which is why every real SPSS
file hits it. M13 confirms.

The comment at `:60-61` records that the current behaviour is deliberate
and traceable to `archive/polychoric-corr/spec-polychoric-corr.md:112`. D2
overturns a written earlier decision, so the spec must say so.

### 7.2 What the estimator actually needs

`.corr_estimate_thresholds()` already handles a plain numeric ordinal
vector: `R/analysis-corr-latent.R:225-227` runs
`all_levels <- sort(unique(ordinal_vec[!is.na(ordinal_vec)]))` and
`codes_all <- match(ordinal_vec, all_levels)`. It does not require whole
numbers; `match()` works on any set of distinct values, and `sort()` fixes
the threshold order. So **the whole of D2 is the gate**. No new estimation
code is needed. Any "whole number" test in a candidate rule below is a
guardrail choice, not a requirement of the estimator.

### 7.3 The signals that already exist, and what each one really tells you

| Signal | Source | What it tells you | What it does not |
|---|---|---|---|
| `@metadata@value_labels[[v]]` | harvested from `attr(col, "labels")` at `R/core-metadata.R:3744-3752`; read at `R/analysis-helpers.R:154` | which codes carry a label, and how many labels there are | nothing about order. Includes missing-reason codes (`8 = "Don't know"`) as ordinary entries. Includes nominal variables — race, region — which SPSS labels most heavily |
| `extract_higher_is()` | `R/core-metadata.R:3141`; set by `set_higher_is()` at `:3013`; values restricted to `"better"` / `"worse"` at `:3087` | the analyst treats the variable as directional, which implies ordinal | nothing when absent. Opt-in, and read by exactly one caller — `get_diffs(show_favorability = TRUE)` at `R/analysis-diffs.R:495-510` |
| `classify_question_type()` | `R/core-metadata.R:3473` | `"single"` / `"sata"` / `"battery"`, from `question_prefaces` and `sata` only (`:3544-3564`) | **nothing at all** about scale type. Not usable |
| `extract_missing_codes()` | `R/core-metadata.R:841`; set at `:2688`; harvested from `attr(col, "missing_codes")` at `:3785` | which codes are sentinels, per variable | nothing when absent. **No file in `R/analysis-*.R` reads it** — grep confirms. It is the only signal that could exclude "Don't know" from a scale, and it is opt-in and currently unread |
| `extract_reverse_coded()` | `NAMESPACE:61`; `@metadata@reverse_coded` at `R/core-classes.R:135-138` | direction is flipped | no reader in `R/analysis-*.R`. Also opt-in |
| `integer_cardinality_cutoff = 10L` | `R/analysis-corr-latent.R:41` | the existing ceiling for integer ordinals | — |

### 7.4 Four candidate rules

**R1 — storage-blind cardinality.** Classify any numeric column as
`"integer_ordinal"` when every non-NA value is a whole number and the
distinct count is at most `integer_cardinality_cutoff`. Delete the
`is.integer()` / `is.double()` split.

- False positive: a genuinely continuous count with few values — number of
  children, household size. Polychoric on it is wrong, and silent.
- False negative: a labelled scale with more than ten points — an eleven
  point feeling thermometer, a 0-10 agreement scale. Already a false
  negative for integers today.
- Blast radius: **widest**. It changes behaviour for plain doubles with no
  labels, so it can flip existing user code. The two committed PC-1 tests
  survive, because both use `stats::rnorm()`
  (`test-analysis-corr-latent-variance.R:477`, `:490`) or a character column
  (`test-analysis-corr-latent.R:609`).
- Needs no metadata at all, so it needs no user action.

**R2 — value-label rule.** Classify a numeric column as
`"integer_ordinal"` when it carries a value-label entry for every observed
non-NA code, the codes are whole numbers, and the distinct count is at most
the cutoff.

- False positive: **nominal labelled variables** — race, region, marital
  status, party ID. These are exactly the columns an SPSS file labels most
  thoroughly. Polychoric on race is meaningless and would produce a number
  with no error.
- False positive: labelled missing-reason codes enter as scale points and
  shift every threshold. `extract_missing_codes()` could exclude them, but
  it is opt-in and unread (§7.3).
- False negative: a labelled scale with some unlabelled codes present in
  the data. `.validate_val_labels()` already warns for that shape
  (`R/core-metadata.R:3687-3693`), so the condition is detectable.
- Precedent inside the package: `.apply_group_labels()` already uses
  "the column has labels" as its test for "treat as coded"
  (`R/analysis-helpers.R:232-235`).
- Blast radius: medium. Every bundled dataset carries `labels` on plain
  doubles, so bundled-data behaviour changes.

**R3 — explicit marker.** Classify as ordinal only when the analyst says
so. Two shapes:
  (a) reuse `higher_is` — presence of `"better"` or `"worse"` means ordinal;
  (b) add a new metadata key, for example `scale_type`, with a setter, an
      extractor and a `survey_metadata` property.

- False positive: near zero.
- False negative: **very high**. A real SPSS import marks nothing, so
  `get_corr(d, c(inc7, educ4), method = "polychoric")` still fails on the
  first try. That does not clear the acceptance criterion in
  `request.md` ("Every analysis function in the public API works on a
  `haven_labelled` column").
- (a) overloads `higher_is`, whose documented meaning is direction of
  improvement for `get_diffs()` (`R/core-metadata.R:2980-2984`).
  Overloading it breaks the one-word-one-meaning rule.
- (b) is the largest surface: a new property, two new exported functions,
  new error classes, new documentation.

**R4 — explicit argument on `get_corr()`.** Add an argument, for example
`ordinal = <tidy-select>`, naming the columns to treat as ordinal. Fall back
to `.corr_detect_ordinal()` when it is absent.

- False positive: zero. The user asserts it per call.
- False negative: zero for a user who reads the message. The PC-1 and PC-2
  messages can name the new argument, so the failure teaches the fix.
- Blast radius: **smallest**. One new argument on one exported function. No
  metadata change. No behaviour change for any existing call.
- But the bare call still fails, so R4 alone also does not clear the
  acceptance criterion as written.

**Combinations worth naming:** R1 + R4, or R2 + R4. The automatic rule
clears the acceptance criterion; the argument gives an escape hatch in both
directions, and the argument is what the error message can point at when the
automatic rule guesses wrong.

**This needs a user decision.** See the HOLD in §10. The trade-off is a
value judgment about silent wrong answers on nominal variables (R2) against
silent wrong answers on low-count continuous variables (R1) against a
function that still fails out of the box (R3, R4). No amount of source
reading settles it.

### 7.5 Does `polyserial` have the same gap?

**Yes, and it fires a different error.** `.corr_canonicalize_polyserial()`
calls the identical `.corr_detect_ordinal()` on both sides
(`R/analysis-corr-latent.R:85-92`), and the polyserial branch of the
dispatcher calls it at `:1666`.

For two labelled doubles: both classify `"continuous"`, so
`x_is_continuous && y_is_continuous` is TRUE at `:154` and the function
raises `surveycore_error_polyserial_requires_mixed_types` (PC-2) at `:171`.
For one labelled double plus one true continuous double: the same, because
the labelled side also reads `"continuous"`.

So the audit's §5 finding understates the scope: the ordinality gap blocks
`polyserial` too, and it surfaces as PC-2 rather than PC-1. Any D2 rule must
be applied inside `.corr_detect_ordinal()`, which fixes both gates at once.
Fixing only the PC-1 site at `:1671-1672` would leave `polyserial` broken.

---

## 8. Open — needs measurement

Each item names exactly what to run. All should run in a fresh `Rscript`
process with `library(surveycore)` and nothing else, so `vctrs` is loaded
and `haven` is absent, unless the item says otherwise.

Fixture for every item below:

```r
lbl <- structure(
  c(1, 2, 3, 2, 1),
  labels = c(Low = 1, Mid = 2, High = 3),
  class = c("haven_labelled", "vctrs_vctr", "double")
)
```

**M1 — `is.numeric()` on a labelled double.**
Run `is.numeric(lbl)`. Expected TRUE, inferred in §4.2. If FALSE, the
inference is wrong and several gates change their answer, which turns
several rows of §4.2 into required spec items.

**M2 — the other predicates.**
Run `is.double(lbl)`, `is.integer(lbl)`, `is.atomic(lbl)`,
`is.factor(lbl)`, `is.ordered(lbl)`, `is.logical(lbl)`. Then repeat the
whole set after `loadNamespace("haven")` in a second fresh process.
Any predicate whose answer differs between the two processes is a hidden
behaviour fork and becomes a spec item.

**M3 — coercion display, with `haven` PRESENT.**
In a process that has run `loadNamespace("haven")`, run
`as.character(lbl[[1L]])` and `as.numeric(lbl[[1L]])`. Report whether the
result is the code (`"1"`) or the label (`"Low"`).
Why it matters: `R/analysis-freqs.R:365` runs `key <- as.character(lvl)` and
`:371` runs `as.character(lvl)` for the display value. If `haven` returns
the label there, then `get_freqs()` output changes after D1 for any user who
has `haven` loaded, and that is an observable contract change the spec must
state.

**M4 — does an S7 property setter run at construction?**
Define a throwaway class and check both paths:

```r
Foo <- S7::new_class("Foo", properties = list(
  d = S7::new_property(
    S7::class_data.frame,
    setter = function(self, value) {
      message("setter fired")
      S7::prop(self, "d", check = FALSE) <- value
      self
    }
  )
))
f <- Foo(d = data.frame(a = 1:2))   # does it print "setter fired"?
f@d <- data.frame(a = 3:4)          # does it print again?
```

This decides §3.3 — whether one setter can be the single choke point for all
eleven internal routes plus `surveytidy`.

**M5 — `from_svydesign()` on a labelled design.**
Build `survey::svydesign(ids = ~1, weights = ~wt, data = df)` where `df`
holds a labelled outcome column and a plain `wt`, then call
`from_svydesign()`. Then repeat with a labelled `wt` column so that
`.find_col_by_value()` (`R/methods-conversion.R:287-306`) must call
`as.numeric(col)` at `:298`. Report the error class for each.

**M6 — `set_val_labels()` on a labelled column.**
`d <- as_survey(df, weights = wt)` where `df$q` is labelled, then
`set_val_labels(d, q = c(A = 1, B = 2, C = 3))`. Expected: abort from
`as.character(unique_vals)` at `R/core-metadata.R:3675`. Report the class.

**M7 — labelled weight column at construction.**
`as_survey(df, weights = lbl_wt)`. Expected: abort at
`R/core-validators.R:152` or `:170`. Report the class.

**M8 — labelled PSU and stratum at construction.**
`as_survey(df, ids = lbl_psu, strata = lbl_strata, nest = FALSE)`.
Expected: abort at `R/core-validators.R:346-347`. Then repeat with
`nest = TRUE`, which skips `.validate_psu_strata()` but still reaches the
S7 validator at `R/core-classes.R:496-497` only when `nest = FALSE`. Report
both.

**M9 — attribute survival on `haven_labelled_spss`.**
Build

```r
spss <- structure(
  c(1, 2, 9),
  labels = c(Low = 1, High = 2, Refused = 9),
  label = "Q1",
  na_values = 9,
  na_range = c(90, 99),
  class = c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", "double")
)
```

then `attr(spss, "class") <- NULL` and print `attributes(spss)`. Confirm
`labels`, `label`, `na_values`, `na_range` all survive and `class` is gone.

**M10 — the legacy `"labelled"` class.**
Build `structure(c(1, 2, 3), label = "Q1", labels = c(A = 1, B = 2, C = 3),
class = "labelled")`. Put it in a design and run the twelve failing entry
points from `audit-empirical.md` §4. Report which pass. Also run the M2
predicate set on it. This decides whether D1's test must widen beyond
`inherits(x, "haven_labelled")`.

**M11 — can a tagged NA be built without `haven`?**
A tagged NA is a double NaN with a payload. Try to build one with
`readBin(writeBin(...))` from the documented byte pattern, or from
`haven::tagged_na("a")` captured once and stored as raw bytes in the
helper. Report whether a haven-free construction is practical. If it is
not, the tagged-NA fixture must keep `skip_if_not_installed("haven")` and
must live in a different test file from any "haven must be absent"
assertion.

**M12 — labelled replicate weights.**
`as_survey_replicate(df, weights = wt, repweights = starts_with("repwt"))`
where the replicate columns are labelled, then `get_means(d, y)`. The
matrix build is `R/analysis-helpers.R:1077` plus `as.matrix()`. Report the
error class, or PASS.

**M13 — labelled integer under the polychoric gate.**
`ilbl <- structure(c(1L, 2L, 3L, 2L), labels = c(A = 1L, B = 2L, C = 3L),
class = c("haven_labelled", "vctrs_vctr", "integer"))`. Run
`surveycore:::.corr_detect_ordinal(ilbl)`. Expected `"integer_ordinal"`,
inferred in §7.1. This confirms the gap is specific to double storage.

---

## 9. Error and warning surface

### 9.1 What becomes unreachable after D1 + D2

All 26 failing call forms in `audit-empirical.md` §4 become unreachable
**through the four constructors and through `from_svydesign()`**, because
`@data` then holds no labelled column and no `vctrs` method can fire. The
four `vctrs` classes — `vctrs_error_ptype2`,
`vctrs_error_incompatible_op`, `vctrs_error_cast`,
`vctrs_error_subscript_oob` — stop appearing on that path.

D1 also removes the audit's §4 asymmetry as a side effect: `get_corr()`
pearson passed while `get_covariance()` on the same pair failed. Both are
correct by design afterwards, because both read plain doubles. That answers
the audit's open item ("worth resolving in the spec").

### 9.2 What stays reachable

Three routes, from §3:

1. `surveytidy::mutate()` writing a labelled column after construction. All
   26 forms remain reachable. Not fixable from inside `surveycore` unless
   the S7 setter route (§3.3, M4) works.
2. Direct S7 construction — `survey_taylor(data = labelled_df, ...)`. The
   class objects are exported (`NAMESPACE:104-113`). Same exposure. The S7
   validator only touches the weights column
   (`R/core-classes.R:454-481`) and the PSU/stratum columns when
   `nest = FALSE` (`:490-516`), so a labelled analysis column passes
   construction and fails later.
3. `d@data$q <- labelled_col` by a user. Same as 2.

### 9.3 Does a new typed error class help?

A typed error needs a check at a place the code reaches. There is no shared
column reader to hook: `decisions.md` counts 80 `design@data[[...]]` sites
across 20 files, and my grep in §"@data" confirms the order of magnitude.
Three shapes are possible, and the spec should pick one:

- **(a) Guard in `.extract_var_meta()`** (`R/analysis-helpers.R:146`).
  Every `get_*()` calls it for the focal variable and for each group
  variable — `R/analysis-corr.R:332`, `R/analysis-freqs.R:274`,
  `R/analysis-means.R` and the rest all build `x_meta_list` from it. That
  makes it the closest thing to a shared reader. A check there could raise a
  typed error naming the column and the fix. It is not a complete guard: it
  sees only the variables the caller named.
- **(b) The S7 setter** (§3.3). Then no error is ever needed, because the
  strip is total.
- **(c) Accept and document.** The failure is then a raw `vctrs` error, as
  today, but only on the three narrow routes in §9.2.

### 9.4 New classes needed

Read `plans/error-messages.md` in full for the relevant rows. Nothing in the
existing table covers a labelled column. The relevant existing rows are:

- row 32 `surveycore_error_weights_not_numeric` (`:64`)
- row 37 `surveycore_error_repweights_not_numeric` (`:69`)
- row 43 `surveycore_error_non_numeric_variable` (`:75`)
- row 51 `surveycore_warning_corr_non_numeric` (`:85`)
- PC-1 `surveycore_error_polychoric_requires_ordinal` (`:193`)
- PC-2 `surveycore_error_polyserial_requires_mixed_types` (`:194-195`)
- PC-3 `surveycore_error_polyserial_canonicalization_ambiguous`
- PC-13 `surveycore_warning_polychoric_unordered_factor` (`:205`)

Proposed names, all conditional on spec decisions:

| Condition | Proposed class | Needed when |
|---|---|---|
| The constructor stripped one or more labelled classes | `surveycore_warning_labelled_class_stripped` | only if the spec wants a warning — see §9.5 |
| A labelled column reached an analysis function through a route the strip does not cover | `surveycore_error_labelled_column_unsupported` | only if §9.3 option (a) is chosen |
| D2 inferred ordinality from a signal rather than from the class | `surveycore_inform_ordinal_inferred` | only if the spec wants the inference to be visible |
| A new `ordinal =` argument on `get_corr()` names a column that does not exist or cannot be treated as ordinal | reuse `surveycore_error_variable_not_found` (`R/utils.R:169`) and PC-1 | if R4 is chosen |
| A new `scale_type` metadata key receives an invalid value | `surveycore_error_scale_type_invalid` | only if R3(b) is chosen |

D2 does **not** need a new class for the common path. PC-1 and PC-2 keep
their names; only the condition under which they fire changes, plus
possibly the `"v"` bullet text.

Every new row must be added to `plans/error-messages.md` before it is used
in code, per `.claude/rules/code-style.md`.

### 9.5 Should the strip warn? — the case both ways

**Against a warning** (my reading):

- It would fire on every SPSS, Stata and SAS import, which is the normal
  path into the package. That is noise, not signal.
- No information is lost. `.extract_haven_metadata()` harvests the labels
  into `@metadata@value_labels` at the same moment
  (`R/core-metadata.R:3744-3752`), and D1's form keeps the `labels`
  attribute on the column as well (§2.3).
- The precedent inside the package is silent. All six `data-raw/` scripts do
  the same strip with no message.
- The constructors already emit up to four conditions on a normal call —
  `surveycore_warning_srs_no_weights`,
  `surveycore_inform_probs_weights_consistent`,
  `surveycore_warning_single_stratum` (`R/core-constructors.R:521-529`),
  `surveycore_warning_psu_multi_strata` (`R/core-validators.R:353-361`).
  A fifth on every import degrades all of them.

**For a warning:**

- `survey_data()` now returns something different from what the user passed
  in. `.claude/rules/engineering-preferences.md` §5 says explicit over
  clever, and a silent type change is not explicit.
- The house rule "Design variables are sacred — always warn when the weight
  column is modified" (`CLAUDE.md`) establishes that the package does warn
  when it changes what the user handed it.
- Round-trip users who feed `survey_data()` back to `haven::write_sav()`
  would notice the change only at the write.

A middle option the spec could take: no warning, but a documented note in
`@return` of each constructor and a line in `NEWS.md`. That satisfies the
explicitness argument at zero runtime cost. The spec decides; I do not.

---

## 10. Test surface

Not test cases — that is test-spec's job. What follows is the surface.

### 10.1 Existing test files that need new or changed blocks

| File | Why |
|---|---|
| `tests/testthat/test-constructors.R` | the strip fires; `labels` survives on the column; `@metadata@value_labels` populated; tagged NA byte pattern preserved; `haven_labelled_spss` attributes preserved; labelled weight / PSU / stratum / FPC / repweight columns now construct |
| `tests/testthat/test-utils.R` | `survey_data()` returns plain types |
| `tests/testthat/test-conversion.R` | `as_svydesign()`, `from_svydesign()`, `as_tbl_svy()`, `from_tbl_svy()` round trips; the `from_svydesign()` metadata gap if the spec closes it |
| `tests/testthat/test-metadata-system.R` | `set_val_labels()` on a labelled column; every extractor unchanged |
| `tests/testthat/test-analysis-freqs.R`, `-means.R`, `-totals.R`, `-quantiles.R`, `-ratios.R`, `-variance.R`, `-covariance.R`, `-diffs.R`, `-t-test.R`, `-corr.R`, `-effective-n.R` | the 26 call forms from `audit-empirical.md` §4 |
| `tests/testthat/test-glm.R`, `test-glm-anova.R`, `test-glm-clean.R` | `survey_glm()`, `get_anova()`, `clean()` on labelled input |
| `tests/testthat/test-analysis-corr-latent.R`, `test-analysis-corr-latent-variance.R` | D2 — the new gate, and the PC-1 / PC-2 boundaries |
| `tests/testthat/test-analysis-helpers.R` | `.apply_group_labels()` and `.extract_var_meta()` on stripped columns |
| `tests/testthat/helper-test-data.R` | the new fixture, §10.3 |

### 10.2 Snapshot churn

Covered in §5.5. For D1 alone: none, because no current test input carries
the class.

For D2: three committed snapshot files carry the PC-1 and PC-2 message text
and **will show a reviewable diff** —
`_snaps/analysis-corr-latent.md`,
`_snaps/analysis-corr-latent-variance.md` and
`_snaps/analysis-corr-latent-primitives.md`. See the correction in §5.5; an
earlier version of this section said they did not exist, which was an
artifact of a pruned working tree, not a fact about the repository.

### 10.3 The fixture — verified absent today

`make_survey_data(with_labels = TRUE)` sets only attributes, never a class:
`tests/testthat/helper-test-data.R:539-549` sets `label` on `y1`, `y2`,
`y3`, `group`, `wt` and `labels` on `y3` and `group`. **No labelled-class
fixture exists anywhere in `tests/`.** Confirmed.

A new fixture must produce, all without loading `haven`:

1. A labelled double with whole-number codes and a label for every observed
   code — the plain SPSS scale.
2. A labelled double with an unlabelled code present in the data — trips the
   `.validate_val_labels()` warning shape
   (`R/core-metadata.R:3687-3693`) and is a D2 false-negative case.
3. A labelled double with more than ten distinct codes — a 0-10 scale, the
   cardinality-ceiling boundary for R1 and R2.
4. A labelled **integer** — already passes the polychoric gate today
   (§7.1), so it is the control that proves the gap is storage-specific.
5. A labelled **nominal** variable — race or region, labelled, small
   cardinality, no meaningful order. The R2 false-positive case.
6. A `haven_labelled_spss` column with `na_values` and `na_range` —
   attribute survival (M9).
7. A tagged NA — subject to M11. If a haven-free construction is not
   practical, this case goes in a separate file that may load `haven`.
8. A labelled **design** column: weight, PSU, stratum, FPC, replicate
   weight. Five separate shapes, one per site in §3.4.

Construction form, per the audit and per `haven`'s own source (§2.1):

```r
structure(
  x,
  labels = c(Low = 1, Mid = 2, High = 3),
  label = "Question 1",
  class = c("haven_labelled", "vctrs_vctr", "double")
)
```

### 10.4 The `haven`-not-loaded constraint — and why it cannot be asserted

`request.md` asks for a regression test that runs with `haven` not loaded.
Seven test files load the `haven` namespace inside
`skip_if_not_installed("haven")` blocks, and `haven::` loads the namespace
for the rest of the process:

| File | Line |
|---|---|
| `tests/testthat/test-analysis-corr.R` | 1184, 1188 |
| `tests/testthat/test-analysis-freqs.R` | 1457, 1461 |
| `tests/testthat/test-analysis-helpers.R` | 1344 |
| `tests/testthat/test-analysis-means.R` | 770, 774 |
| `tests/testthat/test-analysis-quantiles.R` | 1047, 1051 |
| `tests/testthat/test-analysis-ratios.R` | 999, 1003 |
| `tests/testthat/test-analysis-totals.R` | 582, 586 |

**That is a finding.** `testthat` runs every file in one R process, in
alphabetical order. Every one of those files sorts before
`test-constructors.R`, so by the time the constructor tests run, `haven` is
loaded. An assertion of the form
`expect_false("haven" %in% loadedNamespaces())` is therefore
order-dependent and will fail wherever it is placed after those files. The
test suite reproduces the exact contamination the audit describes.

Three ways out, for the spec to choose:

- **(a) Assert the invariant, not the environment.** After D1,
  `expect_false(inherits(survey_data(d)$q, "haven_labelled"))` and
  `expect_type(survey_data(d)$q, "double")` are order-independent, and both
  fail on `develop` at `cf6f153`. That satisfies the acceptance criterion in
  `request.md` without needing `haven` absent, because the strip makes the
  bug unreachable whether `haven` is loaded or not. This is the cleanest
  option and needs no new dependency.
- **(b) Run the probe in a subprocess.** `callr` is **not** in `Suggests`
  (`DESCRIPTION:49-63`), so this adds a dependency. It gives a true
  haven-free assertion.
- **(c) Move the seven tagged-NA blocks into one dedicated file.** Reduces
  the contamination surface but does not remove it, because that file still
  loads `haven` for whatever runs after it.

I recommend the spec take (a) as the primary regression guard, and consider
(c) as separate test hygiene. A HOLD is not needed here — (a) clears the
stated criterion.

### 10.5 Profile gates

All six must pass, verbatim: `document`, `test`, `run_examples`,
`R CMD check --as-cran`, `pkgdown`, `covr`. Coverage floor 95%, target 98%.
Per `.claude/rules/testing-surveycore.md`, measure coverage with
`NOT_CRAN=true`, or the eleven `skip_on_cran()` files skip and the figure
reads about 93.7% instead of 96.09%.

---

## 11. Reference mapping

- `haven/R/labelled.R`, `new_vctr(..., class = c(class,
  "haven_labelled"), inherit_base_type = TRUE)` → the class vector D1 must
  match, and the reason the audit's hand-built fixture is valid (§2.1).
- `haven/R/labelled.R`, `is.labelled <- function(x) inherits(x,
  "haven_labelled")` → D1's test is the upstream test (§6.2).
- `haven/R/labelled_spss.R`, `new_labelled(..., class =
  "haven_labelled_spss")` → `inherits(x, "haven_labelled")` catches the SPSS
  variant (§6.2).
- `labelled` package `NAMESPACE`, `importFrom(haven, ..., labelled,
  labelled_spss, ...)` plus `export(labelled)` and `export(labelled_spss)`
  → the `labelled` package defines no class of its own; a bare `"labelled"`
  class is legacy only (§6.2).
- `data-raw/prepare-gss-2024.R:98-109` and the five sibling scripts → D1 is
  the existing bundled-data convention, moved into the constructor (§1).
- `archive/phase-0/surveycore-phase0-formal-specification.md:1152-1168` →
  the planned `missing_values` property for `na_values` and `na_range` was
  never built; D1 preserves both attributes but nothing reads them (§6.3).
- `archive/polychoric-corr/spec-polychoric-corr.md:112` and the comment at
  `R/analysis-corr-latent.R:60-61` → the current "`is.double` means
  continuous" rule is a deliberate earlier decision; D2 overturns it and the
  spec must say so (§7.1).
- `plans/error-messages.md:193` (PC-1) and `:194-195` (PC-2) → the two
  conditions D2 changes (§7.5, §9.4).
- `audit-empirical.md` §1 → the `vctrs`-loaded, `haven`-absent
  precondition; `vctrs` is transitive through `tibble` and `dplyr`
  (`DESCRIPTION:37-48`), so it cannot be removed (§2.2).
- `audit-empirical.md` §3 → verified line by line against
  `R/analysis-means-helpers.R:70`, `:115`, `:117` and
  `R/analysis-totals-helpers.R:36`, `:96` (§2.4).
- `decisions.md` D1 measurement table → the strip keeps `labels` and keeps
  the tagged-NA byte pattern and tag; this is what makes §4.4 and §5.4 safe.
- `.claude/rules/surveycore-conventions.md` §haven handling → `haven` stays
  in `Suggests`; read label attributes with base R. D1 honours both.
- `.claude/rules/code-style.md` §Function design → a helper used in two or
  more files goes in `R/utils.R`; that is where the strip helper belongs if
  the setter route (§3.3) is not taken.

---

## 12. Assumptions

Things the method assumes that `request.md` did not state.

1. **The `labels` attribute is a sufficient carrier for value labels.**
   D1 keeps the attribute and relies on `@metadata@value_labels` as the
   primary store. That holds because `.extract_haven_metadata()` runs at
   construction (`R/core-constructors.R:547`, `:805`, `:1386`), but **not**
   in `from_svydesign()` (§5.3). The assumption fails on that one route
   unless the spec closes it.
2. **Base R arithmetic on the underlying type is the correct semantics.**
   `haven`'s own `vctrs` methods may not be pure passthroughs. If
   `haven::Ops.haven_labelled` did something other than operate on the
   underlying double, then a user with `haven` loaded would see different
   numbers before and after D1. M2 and M3 test this.
3. **`@data` is the only place a labelled column can hide.**
   Verified for `R/`: `@metadata` holds only lists of labels and strings
   (`R/core-classes.R:100-157`), `@variables` holds column names,
   `@calibration` holds matrices. No other property holds a data column.
4. **The strip is idempotent and total per column.** A second call on a
   stripped column is a no-op, because `inherits()` is FALSE. Route 3
   (`as_survey_twophase()`) therefore costs nothing if the strip is applied
   there defensively.
5. **A labelled column has meaningful order in code space.** D2's whole
   premise. Every candidate rule in §7.4 assumes ascending code order is
   ascending scale order. A reverse-coded scale violates it.
   `@metadata@reverse_coded` exists (`R/core-classes.R:135-138`) and **no
   analysis code reads it**. Polychoric correlation is sign-sensitive, so a
   reverse-coded variable that D2 newly accepts will produce a correlation
   with the wrong sign, silently. This is a real risk and the spec should
   say something about it.
6. **The cardinality ceiling of 10 is the right ceiling.**
   `integer_cardinality_cutoff = 10L` (`R/analysis-corr-latent.R:41`) was
   set for integers. A 0-10 feeling thermometer has 11 codes and would fail
   under R1 and R2 at the current value. Whether D2 raises the ceiling is a
   spec decision.
7. **Missing-reason codes are the user's problem.**
   `extract_missing_codes()` exists and no analysis function reads it
   (§7.3). Under R2, `8 = "Don't know"` becomes a scale point and shifts
   every threshold. The spec must either read `missing_codes` in the D2 rule
   or state plainly that it does not.
8. **The `surveytidy` hole is acceptable, or it is not.** §3.2 and §9.2.
   The spec must say which. Saying nothing leaves the acceptance criterion
   in `request.md` — "Every analysis function in the public API works on a
   `haven_labelled` column" — true for the constructor path and false for
   the `surveytidy::mutate()` path.

---

## 13. Open questions for Stage 1

Beyond §8, which are measurements, these are judgment calls.

1. **Choke point.** S7 property setter (§3.3, pending M4) against five
   explicit call sites. The setter is total and DRY; the explicit sites are
   easier to read and to test in isolation.
2. **D2 rule.** R1, R2, R3, R4, or a combination (§7.4). **This is the
   HOLD** — see §14.
3. **Warning on strip.** No warning, warning, or documentation only
   (§9.5).
4. **`from_svydesign()` metadata.** Take the `.extract_haven_metadata()`
   fix here, or file it separately (§5.3).
5. **`missing_values` property.** Build the planned `na_values` /
   `na_range` harvest here, or leave the Phase 0 plan unbuilt (§6.3).
6. **Class breadth.** `haven_labelled` only, or also the legacy
   `"labelled"` class (§6.2, pending M10).
7. **Reverse-coded interaction.** Whether D2 must read
   `@metadata@reverse_coded`, or warn, or say nothing
   (§12 item 5).
8. **Missing-code interaction.** Whether the D2 rule excludes codes listed
   in `@metadata@missing_codes` (§12 item 7).

---

## 14. HOLD

**HOLD-1 — the D2 ordinality rule needs a user decision.**

**What is blocked**: the D2 half of `spec.md`. The D1 half can be drafted
now.

**Why it cannot be resolved by reading**: §7.4 lays out four rules. Each
trades one kind of silent wrong answer for another:

- R1 (cardinality only) can run polychoric on a low-count continuous
  variable and return a number with no warning.
- R2 (value labels) can run polychoric on a nominal variable — race,
  region, party — and return a number with no warning. Those are the columns
  SPSS files label most heavily, so this is the likely case, not the corner
  case.
- R3 (explicit metadata marker) and R4 (explicit `get_corr()` argument)
  both give near-zero false positives, and both leave
  `get_corr(d, c(inc7, educ4), method = "polychoric")` failing on the first
  try. That reading of the acceptance criterion in `request.md` is not met.

There is no source, paper or upstream package that settles which risk the
package should carry. `decisions.md` D2 lists the candidate signals and
explicitly defers: "The spec must decide how a labelled or previously
labelled column is recognised as ordinal."

**What I need from the user**: one of

- **A** — R1 alone: cardinality plus whole-number test, storage-blind.
- **B** — R2 alone: value labels plus cardinality plus whole-number test.
- **C** — R4 alone: a new `ordinal =` argument on `get_corr()`, no
  automatic change.
- **D** — R1 + R4, or R2 + R4: automatic rule plus escape hatch.
- **E** — R3(b): a new `scale_type` metadata key, with setter and
  extractor.

If the answer is B or D-with-R2, I also need a ruling on §12 item 7:
does the rule exclude codes listed in `@metadata@missing_codes`, and does it
warn when `missing_codes` is empty on a labelled column?

If the answer is D or C, I need the argument name. `ordinal` is the obvious
choice and does not collide with any existing `get_corr()` argument
(`R/analysis-corr.R:275-282` shows `variance`, `conf_level`, `name_style`,
`decimals`, `na.rm`, `format`, `method`, `x`, `group`).

**Not blocked by this HOLD**: everything in D1. Sections 3, 4, 5, 6, 9 and
10 are enough to draft the D1 contract as soon as §8 measurements land.
