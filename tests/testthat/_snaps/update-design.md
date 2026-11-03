# update_design() refuses repweights that select fewer replicate columns

    Code
      update_design(d, repweights = c(repwt_1, repwt_2, repwt_3))
    Condition
      Error in `update_design()`:
      x `repweights` selects 3 columns, but the design has 10 replicates.
      i The design's scale and rscales were set for 10 replicates and would no longer match.
      v Rebuild the design with `as_survey_replicate()` to change the number of replicates.

# update_design() warns when weight column changes on calibrated design [B-6]

    Code
      suppressMessages(update_design(d, weights = wt2))
    Condition
      Warning:
      ! Weight column changed on a calibrated design.
      i @calibration was built from the previous weight column.
      v Re-run calibration or set `design@calibration <- NULL` before analysing.

