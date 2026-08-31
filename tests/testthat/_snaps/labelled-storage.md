# S-21: a labelled weight column with a zero still raises

    Code
      as_survey(df, ids = psu, weights = wt, strata = strata)
    Condition
      Error in `.validate_weights()`:
      x Weight column wt has 1 non-positive value(s).
      i All non-NA weights must be strictly greater than 0.
      v Remove or replace rows where wt is 0 or negative.

# S-22: an all-zero labelled weight column still raises

    Code
      as_survey(df, ids = psu, weights = wt, strata = strata)
    Condition
      Error in `.validate_weights()`:
      x All values in weight column wt are zero or missing.
      i No valid (non-NA, positive) weights found.
      v Check wt for data issues or supply a different column.

# S-23: a labelled fpc column with a non-positive value raises

    Code
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    Condition
      Error in `as_survey()`:
      x `fpc` column fpc has 1 non-positive value(s). FPC values must be > 0.
      i FPC must be either population sizes (> 1) or sampling fractions (0 < f ≤ 1).

# S-23a: a labelled fpc column holding an NA raises

    Code
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    Condition
      Error in `.validate_fpc()`:
      x `fpc` column fpc contains 1 NA value(s). FPC must be fully observed.
      v Remove rows with missing FPC or set `fpc = NULL` to omit the correction.

# S-23f: as_survey_replicate() still raises on a zero weight

    Code
      as_survey_replicate(df, weights = wt, repweights = tidyselect::starts_with("rw"),
      type = "bootstrap")
    Condition
      Error in `.validate_weights()`:
      x Weight column wt has 1 non-positive value(s).
      i All non-NA weights must be strictly greater than 0.
      v Remove or replace rows where wt is 0 or negative.

# S-23g: as_survey_nonprob() still raises on a zero weight

    Code
      as_survey_nonprob(df, weights = wt, repweights = tidyselect::starts_with("rw"),
      type = "bootstrap")
    Condition
      Error in `.validate_weights()`:
      x Weight column wt has 1 non-positive value(s).
      i All non-NA weights must be strictly greater than 0.
      v Remove or replace rows where wt is 0 or negative.

# S-30: a labelled two-phase subset column still raises

    Code
      as_survey_twophase(phase1, subset = sub, method = "approx")
    Condition
      Error in `as_survey_twophase()`:
      x `subset` column sub must be logical, not <numeric>

# S-34: a labelled fpc column with a tagged NA still raises

    Code
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    Condition
      Error in `.validate_fpc()`:
      x `fpc` column fpc contains 1 NA value(s). FPC must be fully observed.
      v Remove rows with missing FPC or set `fpc = NULL` to omit the correction.

