# surveycore 1.2.0

## New features

* Survey designs and data frames carry dataset-level metadata in six keys,
  `survey_name`, `data_name`, `vendor`, `field_start`, `field_end` and
  `field_period`, stored in the new `dataset_metadata` property. Use
  `set_dataset_metadata()` and `extract_dataset_metadata()`, or the pairs
  `set_survey_name()` / `extract_survey_name()`, `set_data_name()` /
  `extract_data_name()`, `set_vendor()` / `extract_vendor()`,
  `set_field_dates()` / `extract_field_dates()` and `set_field_period()` /
  `extract_field_period()`. Constructors copy the six data-frame attributes
  into the design (`dates` reads as `field_period`), and `print()` and
  `summary()` show them. (#162, #163, #164, #166, #168, #170, #171)

* The new `var_extra` property of `survey_metadata`, with `set_var_extra()`
  and `extract_var_extra()`, holds per-variable tags for other packages.
  (#176)

* `survey_data()` gains `haven_class`. With `TRUE` it rebuilds the
  `haven_labelled` class on labelled columns, for `haven::write_sav()`. (#175)

* `as_survey_replicate()` accepts a numeric `fpc` with `fpctype` and applies
  it to `rscales` for `"JK1"`, `"JKn"` and `"other"`, as `survey` does. Other
  types raise `surveycore_error_replicate_fpc_type_unsupported`, and a bad
  value raises `surveycore_error_replicate_fpc_invalid`. A design records the
  result in `@variables$fpc_applied` and `@variables$fpc_fraction`; a bad
  record raises `surveycore_error_replicate_fpc_record_invalid`. (#320)

* `as_survey_twophase()` and `from_svydesign()` warn with
  `surveycore_warning_twophase_full_no_fpc` for a `method = "full"` design
  with phase-1 weights and no `fpc`. The SE of a total can then run several
  times too large. (#339, #340)

* `get_totals()` accepts a factor or character `x` and returns one total per
  level. It used to raise `surveycore_error_non_numeric_variable`. An
  all-`NA` `x` warns with `surveycore_warning_all_na_totals` when
  `na.rm = TRUE` and raises `surveycore_error_all_na` otherwise. (#199, #342)

* `as_svydesign()` and `as_tbl_svy()` convert a `survey_nonprob` design. They
  used to raise `surveycore_error_not_survey_object`. A design without
  replicate weights warns with `surveycore_warning_nonprob_srs_conversion`,
  because its SEs use a simple random sample approximation. (#237)

## Breaking changes

* A write of 0 or 1 row to a design's `@data`, and `from_svydesign()` on a
  zero-row Taylor design, raise `surveycore_error_empty_data` or
  `surveycore_error_single_row`. (#248)

* `as_survey_twophase()` and `from_svydesign()` refuse a multi-stage phase 2
  with `surveycore_error_twophase_multistage_phase2`. Its SE was about 5.6%
  too small. (#338)

* `as_survey_replicate()` refuses an `fpc` column, or `fpctype` without
  `fpc`, with `surveycore_error_replicate_fpc_unsupported`. No SE moves. Pass
  a numeric `fpc`, or use `rscales = rscales * (1 - f)`. (#251, #320)

* `as_survey_replicate()` ignores a supplied `scale` for `"BRR"`, `"JK2"`,
  `"ACS"` and `"successive-difference"`, and `rscales` for the last three, as
  `survey` does. It warns with `surveycore_warning_replicate_arg_ignored`,
  which `surveycore_warning_rho_ignored` also carries. `type = "JKn"` refuses
  `rscales = NULL` with `surveycore_error_stratified_jk_rscales_unset`; pass
  one entry per replicate, for example `(n_h - 1) / n_h`, where `n_h` is the
  number of PSUs in the stratum the replicate drops a PSU from. (#255, #244)

* `as_survey_replicate()` gains `rho` after `type`, which `type = "Fay"`
  requires (`surveycore_error_fay_rho_missing`). The Fay scale is
  `1 / (R * (1 - rho)^2)`, not `1/R`, so Fay SEs rise by `1 / (1 - rho)`:
  1.43 times at `rho = 0.3`. Rebuild saved Fay designs. `rho` with another
  type warns with `surveycore_warning_rho_ignored`. `scale`, `rscales`,
  `fpc`, `fpctype`, `mse` and `calibration` move one place later, so name
  them in positional calls. (#243)

* `as_survey_twophase()` refuses a `survey_replicate` phase 1 with
  `surveycore_error_twophase_replicate_phase1`, which reverses #74. Build
  phase 1 with `as_survey()`. (#243, #74)

* A non-logical domain marker column (`SURVEYCORE_DOMAIN_COL`) raises
  `surveycore_error_domain_not_logical`. (#262)

* A design drops the whole class vector of a `haven_labelled` column, a class
  stacked above it included. It keeps the `label`, `labels`, `na_values` and
  `na_range` attributes. (#175)

* `get_corr(method = "polyserial")` raises
  `surveycore_error_polyserial_requires_mixed_types` for a whole-valued
  numeric column paired with an ordinal one. Use `"polychoric"`. (#175)

* `update_design(x, repweights = )` refuses a changed replicate count with
  `surveycore_error_repweights_count_changed`, because the scale went stale:
  a JK1 SE was 9.5% too large in one case. Rebuild the design with
  `as_survey_replicate()`. (#300, #324)

## Bug fixes

* `get_diffs()` keeps a comparison with an `NA` estimate, leaves it out of
  `pval_adj`, and warns with `surveycore_warning_diffs_na_estimate`.
  surveycore requires `marginaleffects (>= 0.24.0)`, up from 0.18.0.
  (#294, #361)

* `nrow()`, `ncol()`, `dim()`, `NROW()` and `NCOL()` on a design return the
  dimensions of its data, not `NULL`. `dim()` on a `survey_collection`
  raises `surveycore_error_collection_no_dim`. `print(x, full = TRUE)` shows
  every column when `@variables$visible_vars` is set.
  (#203, #234, #236, #238, #240)

* Design df counts only the PSUs and strata of the rows an estimate uses, as
  `survey::degf()` does. Intervals widen for filtered designs, grouped
  `get_quantiles()` and `survey_glm()` (`@degf`, p-values, `get_diffs()`,
  `get_t_test()`), and usually narrow on two-phase designs. `confint()` on
  Taylor and two-phase results of `get_means()`, `get_totals()`,
  `get_freqs()`, `get_ratios()` and `get_covariance()` uses `df = Inf`, as
  their CI columns do, so it narrows: 8% at df 15. (#271, #325, #326, #327)

* `vcov()` on `get_freqs()`, `get_totals()`, `get_means()` and `get_ratios()`
  results gives the full covariance matrix on Taylor and replicate designs.
  A result with no stored matrix gets `NA_real_` off the diagonal and
  `surveycore_warning_vcov_incomplete`.
  `surveycore_warning_vcov_diagonal_only` is retired. (#200, #344, #346)

* On a calibrated Taylor design, `get_freqs()` SEs include the calibration
  step, as `survey` does, and `get_totals()` and `get_ratios()` no longer
  warn with `surveycore_warning_zero_df_after_calibration`. (#343, #345)

* `get_freqs()` on a factor with number-like levels labels each row with its
  own level. (#342)

* `get_means()` SEs for a domain of a `survey_nonprob` design without
  replicate weights fall: `n/(n-1)` uses the full sample. They were 4.9% too
  large at 10 rows of 100. (#245, #263)

* `get_*()` functions read an `NA` domain marker as outside the domain, and
  no longer fail. `as_svydesign()` and `as_tbl_svy()` on a filtered design
  return the domain, not the full sample, for every design class.
  (#245, #262, #266, #267, #268, #269, #276)

* `as_survey_replicate(type = "JK2")` defaults `scale` to `1`, not `(R-1)/R`.
  **This moves published numbers:** SEs rise by `1/sqrt((R-1)/R)`; they ran
  6.5% low on 8 replicates. To reproduce the old numbers, use
  `type = "other"` and `scale = (R-1)/R`, and keep any `rscales` the old call
  passed. (#242)

* `as_survey_replicate()` defaults `scale` to `1` for `"JKn"` and `1/(R-1)`
  for `"bootstrap"`, not `(R-1)/R` and `1/R`. **This moves published
  numbers:** SEs rise by `1/sqrt((R-1)/R)`, 2.6% on 20 replicates. To
  reproduce the old numbers, pass `scale = (R-1)/R` for `"JKn"`, plus
  `rscales = rep(1, R)` if the old call passed none, or `scale = 1/R` for
  `"bootstrap"`. `as_survey_nonprob()` keeps `1/R`. (#253)

* Two-phase variance follows `survey`. `method = "simple"` uses the
  `"approx"` variance, so its SEs rise slightly;
  `surveycore_warning_simple_clustered` is retired. `"approx"` and `"simple"`
  SEs rise, from about 40% low, when phase 2 draws whole phase 1 units.
  `"full"` uses the double-expansion variance of `survey::twophase2()`: on
  the issue's fixture a mean's SE falls from 0.8881 to 0.8200 and a total's
  rises from 14,446 to 36,479. Under `ids2` without `probs2` or `fpc2`, totals
  move under every method. `get_quantiles()` uses phase 2 rows only.
  (#261, #328, #329, #330, #331, #332, #333, #334, #337)

* `from_svydesign()` keeps the phase 2 design of a `survey::twophase()` or
  `survey::twophase2()` object, so `"full"` no longer raises
  `surveycore_error_full_requires_phase2`. A generated column name that is
  taken raises `surveycore_error_phase2_name_collision`.
  `surveycore_warning_twophase_method_unknown` is retired. (#335, #336)

* `from_svydesign()` on a `survey::svrepdesign` object keeps the replicate
  weights, which it lost (`surveycore_error_all_replicates_na` followed), and
  folds in the base weight, which moved SEs by up to 35% either way. It
  raises `surveycore_error_replicate_type_unsupported`,
  `surveycore_error_empty_data`, `surveycore_error_repweights_names_lost` or
  `surveycore_error_repwt_name_collision` for a design it cannot carry.
  (#197, #239, #241, #247)

* `as_svydesign()` on a `survey_replicate` design no longer passes `scale`
  or `rscales` where `survey` computes its own, and succeeds with an FPC: it
  drops the column and warns with `surveycore_warning_replicate_fpc_dropped`
  only when the design does not record where the FPC went. No replicate
  column raises `surveycore_error_repweights_empty`. A Fay design with no
  stored `rho` raises `surveycore_error_fay_rho_unrecoverable`; rebuild it
  with `as_survey_replicate(type = "Fay", rho = )`.
  (#198, #243, #249, #250, #255, #320)

* `survey_data(x, haven_class = TRUE)` leaves a factor, `Date` or other
  classed column unchanged, and returns labels set on the design with
  `set_val_labels()` and `set_var_label()`. (#205, #206)

* `get_corr(method = "polychoric")` accepts a numeric column of at most 10
  distinct finite whole values; recode missing codes such as `8` and `9` to
  `NA` first. It runs about 30 times faster with identical results. An
  all-`NA` numeric column raises `surveycore_error_polychoric_requires_ordinal`
  for either storage type, and `"polyserial"` raises a typed error for an
  infinite continuous value. (#175, #177, #181, #208, #209)

* The four constructors, `from_svydesign()`, `from_tbl_svy()` and
  `set_val_labels()` accept `haven_labelled` columns, where `vctrs` aborted,
  so `surveycore_warning_missing_labels` can fire on them. `from_svydesign()`
  and `from_tbl_svy()` keep the source's labels for `extract_var_label()`
  and `extract_val_labels()`, and `from_svydesign(as_svydesign(d))` no longer
  raises `surveycore_error_design_var_missing`. (#175, #193, #195, #196)

* `as_survey_nonprob()` copies weighting history from the data frame, so
  `survey_weighting_history()` reports it. (#168)

* `get_predict.survey_glm_fit()` keeps a `rowid` column in `newdata`, so
  grouped `avg_slopes()` and `avg_predictions()` keep their groups. (#153)

## Notes

* **Reading objects saved under surveycore 1.1.0 or earlier.** `print()`,
  `summary()` and the six extractors report no dataset metadata. The six
  setters raise `surveycore_error_dataset_metadata_unavailable`; rebuild the
  object with `as_survey()`, `as_survey_replicate()`, `as_survey_nonprob()`
  or `as_survey_twophase()`.

* `extract_metadata()` is unchanged and never shows the six dataset-level
  keys, because they are not variables.

# surveycore 1.1.0

## New features

* `coef()`, `vcov()`, `SE()`, and `confint()` methods are now available for all
  `survey_result` objects produced by `get_*()` functions. The `.survey_result`
  attribute carrying degrees of freedom and parameter metadata is now wired into
  every estimation function. (#148, #149)

## Bug fixes

* `as_survey_replicate()` now uses the correct default scale factor for `"ACS"`
  and `"successive-difference"` replicate types (`4/R` per Ash (2014) / Fay &
  Train (1995)), fixing underestimated standard errors for these designs. (#150)

# surveycore 1.0.0

## First stable release

surveycore 1.0.0 is the first stable API release. The full set of survey
design types (Taylor series linearization, replicate weights, two-phase,
non-probability), variance estimators, analysis functions (means, totals,
frequencies, quantiles, ratios, correlations, regression, t-tests, ANOVA,
effective sample size), the metadata system, and calibration-adjusted variance
are now complete and stable.

## New features

* New `SE()` generic and `coef()`, `vcov()`, `SE()`, `confint()` S3 methods
  for all `survey_result` objects produced by `get_*()` functions. `SE()`
  masks `survey::SE`; `SE.default()` falls back to `sqrt(diag(vcov(...)))` for
  all other objects. `vcov.survey_result()` returns a named diagonal matrix
  (`se^2` on-diagonal, structural zeros off-diagonal). `confint.survey_result()`
  uses the t-distribution with per-parameter degrees of freedom stored in the
  `.survey_result` attribute. `coef()` follows variable-major, group-secondary
  naming matching `survey::coef.svyby()`. (#150)

* `as_survey_nonprob()` now accepts jackknife replicate schemes via
  `type = "JK1"`, `"JK2"`, and `"JKn"`. All `get_*()` estimation functions
  dispatch to jackknife variance when a `survey_nonprob` design carries
  jackknife replicate weights. `print()` displays the replicate type and count
  for jackknife designs. (#133–#136)

* `survey_glm()` now routes `survey_nonprob` designs that carry bootstrap
  replicate weights through the replicate-weight variance estimator, matching
  the behaviour of all other `get_*()` functions for such designs. (#138)

* New dataset `ca_api_2000`: the 2000 California Academic Performance Index
  (API) survey, structured as a simple random sample from California schools.
  Used as a primary example for `survey_taylor` SRS designs throughout the
  documentation and vignettes. (#146)

## Bug fixes

* `get_diffs()`: fixed a regex metacharacter injection when variable names
  contained special characters (`.`, `*`, `?`, etc.), and fixed `pct_change`
  returning `NA` for some group configurations. (#145)

* Fixed six print/dispatch/error bugs (B1–B6) uncovered during a documentation
  audit: `print.survey_nonprob` no longer errors on designs with no repweights
  set; dispatch errors now surface the correct class name in message text; three
  error classes that were raised but never registered have been registered.
  (#143)

## Documentation

* Corrected roxygen text, stale cross-references, contradictory `@tags`, and
  mismatched `@section` headings across 40+ R files (D1–D75). (#143–#144)

* The non-probability estimation vignette section has been rewritten with a
  complete bootstrap variance example using `as_survey_nonprob()` with
  `repweights`.

# surveycore 0.9.0

## New features

* Raking oracle in `test-calibration.R` replaced with
  `survey::calibrate(calfun = "raking")` combined-matrix approach, matching
  the Architecture A variance formula.

* `as_survey()` and `as_survey_replicate()` now validate the `calibration =`
  argument at construction time (errors CAL-15, CAL-16).

* `as_caldata()` constructs a calibration data element suitable for assignment
  to `design@calibration` on `survey_taylor` and `survey_replicate` objects.
  Both classes now carry a `@calibration` property (default `NULL`) that will
  be consumed by the Taylor-series variance path in the upcoming PR 2.

* `get_corr()` with `method = "polychoric"` or `method = "polyserial"` now
  supports `survey_nonprob` designs that supply bootstrap replicate weights
  via `as_survey_nonprob(..., repweights = ...)`. Previously these designs
  always raised `surveycore_error_polychoric_design_unsupported`.

* `set_higher_is()` and `extract_higher_is()` store and retrieve a
  direction-of-improvement attribute (`"better"` or `"worse"`) for survey
  variables. The attribute is used by `get_diffs(show_favorability = TRUE)`
  to classify differences as favorable or backlash. Supports all three
  calling conventions (named `...` args, named vector,
  `variable =` + `direction =`), data frames, and tidy-select.

* `set_reverse_coded()` and `extract_reverse_coded()` store and retrieve a
  reverse-coded flag for survey variables. Supports tidy-select `...` (bare
  names and selection helpers) and the `variable =` character-vector
  interface. Setting `reverse_coded = FALSE` removes the flag. Works on both
  survey design objects and plain data frames.

* `get_diffs()` gains `alpha` and `show_favorability` arguments.
  `show_favorability = TRUE` appends `favorable` and `backlash` logical
  columns to the result. A difference is classified as favorable when it is
  statistically significant (`p < alpha`, default `0.05`) and in the
  direction indicated by `higher_is` metadata set via `set_higher_is()`.
  When no `higher_is` metadata is set, both columns are all `FALSE`. The
  adjusted p-value (when `pval_adj` is supplied) is used for classification.

* `as_survey_nonprob()` gains replicate-weight (bootstrap) support via six
  new arguments: `repweights`, `type`, `scale`, `rscales`, `mse`, and
  `reference_sample`. When `repweights` is supplied, the constructor resolves
  and validates the replicate weight columns and stores them in `@variables`.
  A `reference_sample` property is also added to the `survey_nonprob` class
  for provenance tracking.

* All `get_*()` estimation functions now dispatch to the replicate-weight
  variance engine when a `survey_nonprob` object has `repweights` set.
  When no repweights are supplied, a warning is emitted and the SRS
  approximation is used as a fallback. Degrees of freedom for
  `survey_nonprob` estimates always use the normal approximation (`Inf`).

* `print()` for `survey_nonprob` now shows bootstrap replicate information
  (replicate count, type, and scale) when repweights are set.

# surveycore 0.8.4

## New features

* `get_effective_n()` computes the effective sample size of a survey design
  using the Kish (1965) weight approximation (`method = "kish"`) or the full
  design effect for a specified variable (`method = "deff"`). Supports all
  design types and `survey_collection`.

# surveycore 0.8.3

## CRAN preparation

* Resubmission addressing CRAN feedback on the 0.8.2 submission. Four
  changes: (1) Added DOI references to the package `Description`
  (Lumley 2004 for variance estimation; Mannan 2025 for weighted
  polychoric/polyserial correlation). (2) Uncommented three
  `as_survey()` calls in the `@examples` blocks of `anes_2024`,
  `gss_2024`, and `pew_npors_2025`, so they now run during
  `R CMD check`. The ANES and GSS examples (and the corresponding
  prose `@details` sketches) also gained `nest = TRUE`, which is
  required by those designs and silences a previously-emitted
  warning. (3) Replaced the `\section{Tidy-select}` `\preformatted{}`
  code sketch in `as_survey()` with prose, and added two runnable
  demonstrations to the `@examples` block (`c()` for multi-stage IDs
  on a synthetic frame, and `starts_with()` for tidyselect-helper
  weights on `gss_2024`). (4) Replaced `globalenv()` with `baseenv()`
  as the formula environment in `survey_glm()` to comply with CRAN
  policy on `.GlobalEnv` modification.

# surveycore 0.8.2

## CRAN preparation

* Resubmission addressing CRAN feedback on the 0.8.1 submission. Tagged
  numerical oracle and integration test files (comparisons against
  `survey`, `marginaleffects` integration, polychoric/polyserial MLE,
  vendored saddlepoint parity, and two-phase variance parity) with
  `skip_on_cran()`. Test runtime under `R CMD check --as-cran` drops
  from ~11 minutes to under 1 minute. The skipped tests continue to
  run on every push in CI and locally with `devtools::test()`.
* Single-quoted `'surveyverse'` in `Description` to match the
  convention used for other proper nouns (`'S7'`, `'tidyselect'`,
  `'haven'`) and silence the spell-checker NOTE.

# surveycore 0.8.1

## CRAN preparation

* Added Thomas Lumley to `Authors@R` as `[ctb, cph]` for the variance
  estimation code vendored from the `survey` package (R/variance-taylor.R,
  R/variance-replicate.R, R/variance-twophase.R,
  R/variance-vendored-saddlepoint.R). Vendoring is documented in
  `VENDORED.md`.
* Reworded the closing sentence of the package `Description` for grammatical
  completeness ("Automatically preserves..." instead of "Automatic
  preservation of...").
* Bumped `inst/CITATION` to track the upcoming release version.
* Removed the `\url{}` wrapper around `electionstudies.org` in the
  `anes_2024` data documentation. The URL is preserved as plain prose; the
  ANES homepage 403's automated requests, which previously triggered a
  `urlchecker::url_check()` failure under `R CMD check --as-cran`.

# surveycore 0.8.0

## Breaking changes

* Constructing a `survey_collection` from member surveys with divergent `@groups` now errors `surveycore_error_collection_group_divergent`. Previously, a mixed-grouping collection would dispatch analysis functions per-survey and stitch a patchwork of grouped and ungrouped rows together with `bind_rows()` — violating the pseudo-data.frame mental model. All members must either share `@groups` or the caller must supply `group =` explicitly.
* `as_survey_collection()`'s `.on_missing` argument has been replaced by `.if_missing_var`, and the previously silent no-op behaviour is fixed. `.if_missing_var` is now stored on the returned collection's `@if_missing_var` property and is honoured (rather than ignored) by every dispatched `get_*()`. Callers using the old name will see R's positional-argument-mismatch error.
* The `.on_missing` named-only argument on every collection-dispatching `get_*()` (`get_means()`, `get_totals()`, `get_freqs()`, `get_ratios()`, `get_diffs()`, `get_corr()`, `get_variance()`, `get_quantiles()`, `get_covariance()`, `get_t_test()`, `get_pairwise()`) has been renamed to `.if_missing_var`. The default flips from `"error"` to `NULL`; `NULL` resolves to the collection's stored `@if_missing_var` property, while a non-`NULL` value overrides it for that call. The `.id` argument similarly defaults to `NULL` and resolves to the collection's stored `@id`. Callers passing `.on_missing = ...` will silently have the value flow into `...` (no behaviour change at the analysis layer); update to `.if_missing_var = ...` to restore intent.

## New features

### `survey_collection` per-call dispatch defaults

* `survey_collection` gains two new properties:
  - `@id` (`character(1)`, default `".survey"`) — column name `.dispatch_over_collection()` uses when an analysis function is dispatched across the collection without an explicit per-call `.id`. Validated via the new shared helper; the existing `surveycore_error_collection_invalid_id` class fires on bad input.
  - `@if_missing_var` (`character(1)`, default `"error"`, must be one of `c("error", "skip")`) — controls how dispatched `get_*()` calls behave when a member survey is missing a requested variable. Validated via the new helper; raises the new `surveycore_error_collection_invalid_if_missing_var` error class on bad input.
* New exported setters `set_collection_id(x, id)` and `set_collection_if_missing_var(x, if_missing_var)` mutate the corresponding property and return the collection invisibly. Both validate via the same shared helpers; both raise `surveycore_error_not_survey_collection` on non-collection input.
* `add_survey()` and `remove_survey()` now propagate the source collection's `@id` and `@if_missing_var` onto the returned collection.
* `print(survey_collection)` renders `id:` and `if_missing_var:` lines on every print, regardless of whether they hold the default values.
* `.dispatch_over_collection()` resolves both `.id` and `.if_missing_var` via two-tier precedence: a non-`NULL` value at the analysis-function call site beats the value stored on the collection's property. The `surveycore_error_collection_id_collision` hint additionally surfaces `set_collection_id()` as a fix path when the collision was triggered by the stored `@id`.

### Uniform grouping on `survey_collection`

* `survey_collection` gains a `@groups` property (`character(0)` by default). Every member survey's `@groups` is asserted `identical()` to the collection's value by the class validator — a uniform-grouping invariant that guarantees dispatched `get_*()` results share a single grouping structure.
* `as_survey_collection()` gains a `group =` argument that accepts tidy-select column names (bare, `c()`, `all_of()`). Missing or empty-resolved `group =` (including `NULL`, `character(0)`, `c()`, `all_of(character(0))`) adopts the members' uniform `@groups` or errors on divergence; a supplied non-empty `group =` overrides any pre-existing member `@groups` and emits a typed `surveycore_warning_collection_group_overridden` per divergent member.
* `add_survey()` and `remove_survey()` now preserve `coll@groups` across mutation: a grouped collection propagates its `@groups` onto any empty-grouped new member and errors on divergent-grouped members (`surveycore_error_collection_group_conflict`); removal keeps the collection-level grouping.

### Polychoric and polyserial correlation via `get_corr(method = ...)`

* `get_corr()` gains a `method = "pearson"` argument. Setting `method = "polychoric"` fits a weighted two-step MLE for the correlation between two ordinal variables under a bivariate-normal latent model (Olsson 1979; Mannan 2025); `method = "polyserial"` fits the analogous MLE for one ordinal + one continuous variable (Cox 1974). Auto-detection of the ordinal / continuous side is handled internally; no new user-facing argument is required. Confidence intervals are constructed on the Fisher-z scale and back-transformed to `[-1, 1]`. Variance is design-based: Taylor linearization via a perturbation-based influence function on `survey_taylor`, and a full per-replicate re-fit of both thresholds and `rho` on `survey_replicate`. For `method != "pearson"`, `df = NA_integer_` and `statistic` is the z-scale Wald statistic referred to a standard normal distribution. `meta(result)$bivariate_normal_cdf` is `"pbivnorm"`, and `meta(result)$n_failed_replicates_total` carries the total count of non-converged replicates when the replicate path observed any. Agreement with `polycor::polychor()` / `polycor::polyserial()` on equal-weight fixtures is within `1e-4`.
* New package Import: `pbivnorm` (>= 0.6.0), used as the bivariate-normal CDF for the polychoric / polyserial likelihood.
* Fourteen new typed error / warning classes (PC-1 through PC-14) surface ordinal-type, optimizer, sparse-cell, boundary, and replicate-convergence conditions — see `plans/error-messages.md` for the full list.

## New functions

* `get_variance()` computes design-based finite-population variance estimates for one or more numeric variables in a survey design, matching `survey::svyvar()` at tolerance `1e-10` on point estimates and `1e-8` on SEs. Returns a `survey_variance` tibble with point estimate, SE, CI, CV, MOE, design effect (`deff`), and cell sizes. Supports grouping (via `group =` and `group_by()`), per-variable `na_handling = "pairwise"` (default) or `"listwise"`, `name_style = "broom"` renaming, and column-level `label` attributes for downstream gt integration. Dispatches over `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, and `survey_collection` designs.
* `get_covariance()` computes design-based finite-population covariance estimates for all unordered pairs drawn from one or more numeric variables in a survey design, matching the off-diagonal entries of `survey::svyvar()` at tolerance `1e-10` on point estimates and `1e-8` on SEs. Returns a `survey_covariance` tibble with covariance, SE, CI, CV, MOE, design effect (`deff`), and pairwise cell sizes. Pearson-only, pairwise-complete NA handling. Supports grouping (via `group =` and `group_by()`), `redundant = TRUE` to include both `(x, y)` and `(y, x)` orderings, `diagonal = TRUE` to include `(x, x)` self-pairs (which equal `get_variance(x)` exactly at `1e-10`), `name_style = "broom"` renaming, and column-level `label` attributes for downstream gt integration. Dispatches over `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, and `survey_collection` designs.

## New warning classes

* `surveycore_warning_variance_all_na` — fired when every row of the active domain is `NA` on the focal variable.
* `surveycore_warning_variance_insufficient_n` — fired when the focal variable has fewer than two non-`NA` observations in the active domain (variance is undefined).
* `surveycore_warning_covariance_all_na` — fired when every row of the active domain is `NA` on at least one variable in the pair.
* `surveycore_warning_covariance_insufficient_n` — fired when a pair has fewer than two pairwise-complete observations in the active domain (covariance is undefined).
* `surveycore_warning_covariance_non_numeric` — fired when one or more variables passed via `x` are non-numeric and silently dropped from the pair list.

# surveycore 0.7.1

## Documentation

* Trimmed the `Getting Started` vignette to remove dependencies on the sibling
  `surveytidy` package, which is not yet on CRAN. The correlation and ratio
  examples now clean data via `dplyr::filter()` on the underlying data frame
  before constructing the survey object. The standalone "Using surveytidy"
  section has been removed; those workflows are documented in the `surveytidy`
  package itself.

# surveycore 0.7.0

## Breaking changes

* `get_anova()`'s first argument is now `object` and dispatches on class. The former `model2` positional argument has been removed — `get_anova(fit1, fit2)` must now be written `get_anova(list(fit1, fit2))`. The S3 `anova(fit1, fit2)` interface is unchanged.

## New functions

### Design-based group comparisons

* `get_t_test()` performs a design-based two-sample t-test comparing group means for a numeric outcome across two levels of a `by` variable. Returns a `survey_t_test` tibble with estimate, per-group means and cell sizes, CI, t-statistic, df, p-value, and significance stars. Supports optional stratification via `group` (one row per stratum) and matches `survey::svyttest()` at tolerance 1e-10 for point estimates and test statistics.
* `get_pairwise()` computes all k(k−1)/2 pairwise t-tests across the levels of a factor, with multiple-comparison p-value adjustment via any `stats::p.adjust()` method (`"holm"` by default, or `"none"`). Adjustment is applied separately within each `group` stratum when stratified. Returns a `survey_pairwise` tibble with one row per pair.

### Design-based ANOVA

* `get_anova()` computes Rao-Scott design-based ANOVA for `survey_glm_fit` objects, supporting both Wald and LRT tests with F or Chi-squared reference distributions. Three dispatch branches:
  - `get_anova(<survey_glm_fit>)` — sequential term-by-term anova (matches `anova.svyglm()` semantics).
  - `get_anova(<list<survey_glm_fit>>)` — chained pairwise comparison across `k` nested fits, returning `k − 1` rows.
  - `get_anova(<survey_base>, formula = ...)` — fits the model internally via `survey_glm()` and runs sequential anova on the fit; extra `...` are forwarded to `survey_glm()`.
  Matches `survey::regTermTest()` at tolerance 1e-8 on statistics and 1e-6 on p-values.
* `anova(fit)` on a `survey_glm_fit` now dispatches to `get_anova()` via a registered S3 method.
* `plot()` on a `survey_glm_fit` produces a dot-and-whisker coefficient plot with design-based Wald confidence intervals.

### Select-all-that-apply (SATA) metadata

* `set_sata()` marks one or more variables on a survey design (or data frame) as select-all-that-apply. Accepts either tidy-select `...` or a `variable` character vector; setting `sata = FALSE` removes the flag. Idempotent on already-flagged variables.
* `extract_sata()` returns SATA status as a named logical vector (default), a list, or a data frame. `fill = FALSE` yields a dense view (unmarked variables reported as `FALSE`); `fill = NULL` returns only flagged variables.
* `classify_question_type()` classifies a set of requested variables into `"single"`, `"sata"`, or `"battery"` by grouping them on shared `question_preface` metadata and honoring per-variable SATA flags. Group numbers are assigned in order of first appearance. Warns when a lone SATA-flagged variable has no preface mate, or when a preface group has mixed SATA flags.

### Survey collections

* `survey_collection` is a new S7 container holding an ordered, uniquely-named list of `survey_base` objects — useful for wave-to-wave analyses, panel studies, or any workflow that compares estimates across multiple designs.
* `as_survey_collection()` constructs a collection from named (`wave1 = d1, wave2 = d2`) or bare (`d1, d2`) arguments; duplicate names are repaired by appending `_1`, `_2`, … with a warning showing the rename mapping.
* `add_survey()` and `remove_survey()` return new collections with surveys appended or removed; the original is unchanged.
* All nine `get_*()` analysis functions (`get_means()`, `get_totals()`, `get_freqs()`, `get_quantiles()`, `get_ratios()`, `get_corr()`, `get_diffs()`, `get_t_test()`, `get_pairwise()`) now dispatch over a `survey_collection`, iterating across surveys and returning a single combined tibble. Two new named-only control args on each function: `.id = ".survey"` names the identifier column, and `.on_missing = c("error", "skip")` controls behavior when a requested variable is absent from a survey. Regression functions (`survey_glm()`, `get_anova()`) do not support collection dispatch and raise an explicit error pointing users to `lapply()`.

## Other improvements

* `survey_glm()` gains a `quiet =` argument to suppress convergence warnings.
* `extract_*()` metadata functions now accept tidyselect helpers (`starts_with()`, `all_of()`, `any_of()`, `matches()`) in place of bare name lists.

## Bug fixes

* `get_diffs()` now correctly computes `pct_change` when `show_means = FALSE` is combined with grouped marginal effects and `show_pct_change = TRUE` (previously returned `NA`).

# surveycore 0.6.2

## Bug fixes

* Moved `dplyr` from Suggests to Imports (used unguarded in metadata
  functions).
* Fixed broken `vignette("estimation")` cross-reference in
  `creating-survey-objects` vignette.
* Fixed non-canonical CRAN URLs in `surveycore-vs-survey` vignette.

## Documentation

* Updated README to reflect current API: `as_survey_replicate()` (not
  `as_survey_rep()`), added `get_diffs()`, `survey_glm()`, and
  `survey_nonprob`.
* Added `@examples` to 12 exported functions and `@return` to
  `survey_base` for CRAN compliance.

# surveycore 0.6.1

## Bug fixes

* `survey_nonprob` validator now accepts zero weights when at least one positive
  weight exists, unblocking the surveywts `adjust_nonresponse()` workflow.
  Previously, any zero weight triggered an error. Negative weights are still
  rejected.

# surveycore 0.6.0

## Breaking changes

* `survey_srs` class and `as_survey_srs()` constructor have been removed. SRS
  designs are now created via `as_survey()` with no `ids` or `strata` — this
  produces a `survey_taylor` with no cluster/strata structure. All estimates are
  numerically identical.

## New features

* `get_diffs()` estimates treatment effects (differences from a reference group)
  via survey-weighted regression. Supports bivariate and multivariate models,
  Gaussian and non-Gaussian families, and optional subgroup analysis. Two
  estimation paths: direct coefficients for simple models, and
  `marginaleffects::avg_slopes()` / `avg_predictions()` for models with
  covariates or non-Gaussian AMEs. Returns a `survey_diffs` tibble with optional
  `mean`, `pct_change`, `n_weighted` columns, significance stars, and p-value
  adjustment. `marginaleffects` moved from Suggests to Imports.

* `as_survey()` now supports multi-column FPC for multi-stage designs
  (e.g., `fpc = c(fpc_stage1, fpc_stage2)`). Each FPC column corresponds to one
  ID stage. Per-stage FPC is validated for NAs, non-positive values, and
  within-cluster constancy.

* `print()` for `survey_taylor` now displays per-stage FPC bullets for
  multi-stage designs (e.g., `FPC (stage 1): fpc`, `FPC (stage 2): fpc2`).

## Bug fixes

* SRS variance estimation now uses Taylor (HT) linearization via
  `.build_cluster_matrices()`, correct for any weight structure. Previously used
  unweighted sample variance which was incorrect for non-proportional weights.

* `survey_glm()` now correctly indexes weights when `na.action = na.omit` drops
  non-contiguous rows.

* `get_freqs()` now routes `survey_nonprob` designs through the
  Horvitz-Thompson variance path, consistent with the other five analysis
  functions.

* `as_survey_twophase()` now accepts `survey_replicate` and SRS
  `survey_taylor` objects as the phase-1 design (previously restricted to
  stratified/clustered `survey_taylor` only).

* `as_survey()` SRS fallback downgraded from warning to message.

## Internal infrastructure

* `.build_cluster_matrices()` extracts multi-stage cluster, strata, and FPC
  matrix construction into a shared helper, used across the Taylor variance
  engine, analysis cell estimators, and GLM sandwich variance.

# surveycore 0.5.0

## Breaking changes

* `as_survey_replicate()` replaces `as_survey_repweights()`. The constructor
  name now matches the underlying `survey_replicate` class.

* `survey_nonprob` and `as_survey_nonprob()` replace `survey_calibrated` and
  `as_survey_calibrated()`. "Calibrated" implies a post-processing step on a
  probability sample; `nonprob` accurately reflects the design type.

* `survey_srs` and `as_survey_srs()` have been removed. SRS designs are now
  created via `as_survey()` with no `ids` or `strata` — this produces a
  `survey_taylor` with no cluster/strata structure. All estimates are
  numerically identical. Print output now says "Taylor series linearization"
  instead of "simple random sample".

* Single-row data frames are now rejected at construction time (previously
  a warning). This matches `survey::svydesign()` behavior.

* The positional setter form `set_var_label(svy, age, "label")` has been
  removed. Use the named form `set_var_label(svy, age = "label")` instead.

* `extract_var_label()`, `extract_question_preface()`, and `extract_var_note()`
  now return a named character vector. `extract_var_label(svy, age)` now
  returns `c(age = "Age in years")` rather than `"Age in years"`.

* `extract_val_labels()` now returns a named list. `extract_val_labels(svy, sex)`
  now returns `list(sex = c(Male = 1L, Female = 2L))` rather than
  `c(Male = 1L, Female = 2L)`.

* `set_variable_labels()`, `set_value_labels()`, `set_question_prefaces()`, and
  `set_variable_notes()` have been removed. Use `set_var_label()`,
  `set_val_labels()`, `set_question_preface()`, and `set_var_note()`
  respectively — all four now accept multiple variables via named `...`.

## New features

* `set_universe()` and `extract_universe()` set and retrieve universe
  (eligibility) annotations for survey variables.

* `set_missing_codes()` and `extract_missing_codes()` set and retrieve missing
  value code vectors for survey variables.

* `extract_metadata()` returns all metadata fields (`variable_label`,
  `value_labels`, `question_preface`, `note`, `universe`, `missing_codes`,
  `transformations`) for one or more variables as a named list.

## Enhancements

* All setter functions now support three call conventions: named `...`
  (e.g., `set_var_label(svy, age = "Age in years")`), a single named
  vector/list in `...`, or explicit `variable =` / content-argument pairs.
  All setters also now work on plain `data.frame`s.

* All extractor functions accept multiple variables via `...`, support three
  output formats (`"named_vector"`, `"list"`, `"data_frame"`), and accept a
  `fill` argument to include variables with no metadata in the output.

# surveycore 0.4.0

## New features

* `survey_glm()` fits survey-weighted generalized linear models for all four
  design classes (`survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`); returns a `survey_glm_fit` object
  with design-based (Binder 1983 sandwich) standard errors and degrees of
  freedom.

* `clean()` converts a `survey_glm_fit` to a tidy `survey_glm_tidy` tibble
  with one row per coefficient, design-based confidence intervals, structured
  metadata, and optional reference rows for factor predictors.

* `survey_glm_fit` objects support 20 S3 methods: `print()`, `summary()`,
  `coef()`, `vcov()`, `predict()`, `fitted()`, `residuals()`, `confint()`,
  `formula()`, `terms()`, `model.matrix()`, `model.frame()`, `deviance()`,
  `df.residual()`, `nobs()`, `hatvalues()`, `logLik()`, `AIC()`, `BIC()`, and
  `update()`.

* `survey_glm_fit` integrates with the `marginaleffects` package; when
  `marginaleffects` is installed, `avg_slopes()`, `avg_predictions()`, and the
  full marginaleffects API work directly on `survey_glm_fit` objects.

* `broom::tidy()` is supported for `survey_glm_fit` objects via a shim that
  delegates to `clean()`.

* `as_survey_rep()` has been renamed to `as_survey_replicate()` to avoid a
  namespace clash with the `srvyr` package.

## Bug fixes

* `as_survey_twophase()` variance estimation (`method = "approx"` and
  `"full"`) now uses the correct PSU-level Phase 2 stratum sampling fraction
  instead of a row-level fraction, resolving an approximately 2× variance
  underestimation.

# surveycore 0.3.3

## New features

* `print()` methods for all four survey design classes (`survey_taylor`,
  `survey_replicate`, `survey_twophase`, `survey_nonprob`)
  now display a `Domain: <n> of <N> rows` line when `surveytidy::filter()`
  has been applied. The line appears after the sample size line and before
  the `Groups:` line. For two-phase designs, domain counts reflect Phase 2
  rows only.

# surveycore 0.3.0

## New features

* `names()` now works on survey design objects, returning the column names of
  the underlying data frame. This enables IDE column-name autocomplete in
  RStudio and Positron when piping into analysis functions (e.g.,
  `design |> get_means(`).

# surveycore 0.2.0

## New features

* `get_freqs()` computes weighted frequency tables for categorical survey
  variables across all five design types, with domain estimation, value-label
  support, and AAPOR small-cell warnings.

* `get_means()` returns survey-weighted means with design-correct standard
  errors for all five design types, including grouped and domain estimation.

* `get_totals()` returns survey-weighted population totals (and population
  size when called without `x`) for all five design types.

* `get_corr()` computes survey-weighted Pearson correlation using the
  delta-method variance approach, with optional `group` parameter for
  per-group correlations and Fisher Z confidence intervals.

* `get_quantiles()` estimates survey-weighted quantiles using the Woodruff
  (1952) linearization method; supports multiple `probs` in a single call and
  five CI interval methods.

* `get_ratios()` estimates survey-weighted ratios (numerator total /
  denominator total) with design-correct SEs via the delta method (Taylor,
  SRS, calibrated, two-phase) or direct per-replicate computation (replicate
  designs).

* All six analysis functions gain a `decimals` argument to round numeric
  output columns to a fixed number of decimal places.

* `na.rm = FALSE` now includes rows where a grouping variable is `NA` as a
  separate group row in all six analysis functions' output.

* `infer_question_prefaces()` auto-detects shared battery prefaces from
  variable labels using separator-based and longest-common-prefix detection.

* `survey_weighting_history()` returns the weighting history stored in a
  survey design object's metadata; `as_survey()`, `as_survey_replicate()`, and
  `as_survey_nonprob()` now promote `"weighting_history"` attributes from the
  input data frame automatically.

* Two-phase variance estimation (`as_survey_twophase()`) is now fully
  supported in `get_means()` and `get_totals()`, using the `"full"`,
  `"approx"`, and `"simple"` methods vendored from the `survey` package.

## Bug fixes

* `get_freqs()` no longer crashes when the `group` variable contains `NA`
  values.

* `get_freqs()` now outputs `pct` as a proportion (0–1) rather than a
  percentage (0–100); `se` and `se_srs` are on the same scale.

# surveycore 0.1.0

## New features

* `as_survey()` creates `survey_taylor` objects with a tidy-select interface
  (`ids`, `weights`, `strata`, `fpc`, `probs`); supports Taylor linearization
  for stratified, clustered, and SRS designs.

* `as_survey_replicate()` creates `survey_replicate` objects; supports BRR, Fay BRR,
  JK1, JK2, JKn, bootstrap, ACS, and successive-difference replicate schemes.

* `as_survey_twophase()` creates `survey_twophase` objects; supports "full",
  "approx", and "simple" two-phase variance estimation methods.

* `update_design()` modifies design variables on an existing survey object
  without reconstructing from scratch; respects `validate = TRUE/FALSE`.

* `get_means()` returns a weighted mean and standard error via Taylor
  linearization or replicate weights; respects
  `getOption("survey.lonely.psu")` for single-PSU strata.

* `get_totals()` returns a weighted total and standard error using the same
  dispatch as `get_means()`.

* Metadata setters: `set_var_label()`, `set_variable_labels()`,
  `set_val_labels()`, `set_value_labels()`, `set_question_preface()`,
  `set_question_prefaces()`, `set_var_note()`, `set_variable_notes()`.
  Single-variable setters automatically import haven `"label"` / `"labels"`
  attributes from the data frame column.

* Metadata extractors: `extract_var_label()`, `extract_val_labels()`,
  `extract_question_preface()`, `extract_var_note()`.

* Conversion utilities: `as_svydesign()`, `from_svydesign()`, `as_tbl_svy()`,
  `from_tbl_svy()` — round-trip conversion between surveycore objects,
  `survey::svydesign` / `survey::svrepdesign`, and `srvyr::tbl_svy`.

* `print()` and `summary()` S7 methods for all survey design classes display
  design type, sample size, and a tibble-style data preview.

## Internal infrastructure

* S7 class hierarchy: abstract `survey_base` → `survey_taylor`,
  `survey_replicate`, `survey_twophase`; `survey_metadata` for label storage.

* Three-layer validation: S7 structural validators, Layer 2 input validators,
  Layer 3 constructor validators; all errors use typed `class=` for
  programmatic handling.

* Variance estimation vendored from the `survey` package (Thomas Lumley,
  GPL-2/GPL-3) — see `VENDORED.md` for full attribution.
