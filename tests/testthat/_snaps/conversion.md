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

