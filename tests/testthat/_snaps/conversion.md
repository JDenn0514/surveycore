# from_svydesign() rejects a subbootstrap replicate design

    Code
      from_svydesign(sv)
    Condition
      Error in `.from_svydesign_replicate()`:
      x The survey design records replicate type "subbootstrap", which surveycore does not accept.
      i surveycore accepts "JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", "successive-difference", and "other".
      v Rebuild the design with `survey::as.svrepdesign()` and an accepted type, then convert it again.

# from_svydesign() rejects a zero-row replicate design

    Code
      from_svydesign(sv)
    Condition
      Error in `.from_svydesign_replicate()`:
      x The survey design has no rows.
      i `from_svydesign()` needs at least one row to build a <survey_replicate> design.
      v Convert a design built on data with at least one row.

# from_svydesign() rejects a partly named replicate matrix

    Code
      from_svydesign(sv)
    Condition
      Error in `.from_svydesign_replicate()`:
      x The survey design has 4 replicate weight columns but 2 usable column names.
      i `from_svydesign()` needs one name per replicate column to store the weights in the design data.
      v Rebuild the design with `survey::svrepdesign()` and pass `repweights` as a data frame with one named column per replicate.

# from_svydesign() rejects one generated name that already names a column

    Code
      from_svydesign(sv)
    Condition
      Error in `.from_svydesign_replicate()`:
      x `from_svydesign()` cannot store the replicate weights under generated names.
      i The design data already has a column named ..surveycore_repwt_2...
      i A generated name reaches the data when an earlier conversion left its replicate columns there.
      v Rename the conflicting column in the design data, then convert again.

# as_svydesign() warns and drops a recorded FPC, and still converts

    Code
      sv2 <- as_svydesign(d)
    Condition
      Warning:
      ! `as_svydesign()` dropped the finite population correction column fpc.
      i `survey::svrepdesign()` takes one FPC value per replicate, and a <survey_replicate> design records one value per row.
      i surveycore's replicate variance does not read the FPC, so the returned design reproduces surveycore's own standard errors.
      v Call `survey::svrepdesign()` directly with `fpc` to apply a per-replicate correction.

# as_svydesign() rejects a replicate design that names no replicate column

    Code
      as_svydesign(d)
    Condition
      Error in `.as_svydesign_replicate()`:
      x The design names no replicate weight column.
      i `survey::svrepdesign()` needs at least one replicate weight column, and fails with an untyped error without one.
      v Rebuild the design with `as_survey_replicate()` and name its replicate weight columns.

# as_svydesign() refuses a Fay design whose scale yields no rho

    Code
      as_svydesign(d)
    Condition
      Error in `.as_svydesign_replicate()`:
      x `as_svydesign()` cannot recover the "Fay" shrinkage factor for this design.
      i `survey::svrepdesign()` requires `rho` for `type = "Fay"`, and surveycore derives it from the recorded scale.
      i The recorded scale is "0.05" and yields no value in `[0, 1)`.
      v Rebuild the design with `as_survey_replicate()` and pass the `scale` the "Fay" replicates were built with.

# as_svydesign() refuses a Fay design that records no scale

    Code
      as_svydesign(d)
    Condition
      Error in `.as_svydesign_replicate()`:
      x `as_svydesign()` cannot recover the "Fay" shrinkage factor for this design.
      i `survey::svrepdesign()` requires `rho` for `type = "Fay"`, and surveycore derives it from the recorded scale.
      i The recorded scale is "none" and yields no value in `[0, 1)`.
      v Rebuild the design with `as_survey_replicate()` and pass the `scale` the "Fay" replicates were built with.

