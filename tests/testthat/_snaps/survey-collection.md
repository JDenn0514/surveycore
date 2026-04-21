# as_survey_collection() rejects unnamed non-symbol arguments

    Code
      as_survey_collection(suppressMessages(suppressWarnings(as_survey(df1, ids = psu,
        weights = wt, strata = strata, fpc = fpc))))
    Condition
      Error in `.resolve_caller_names()`:
      x Argument 1 passed to `as_survey_collection()` is unnamed and is not a bare symbol.
      i Collection elements must be named, or be supplied as bare variable names so they can be auto-named.
      v Name the argument explicitly, e.g. `as_survey_collection(wave1 = as_survey(df, ...))`.

# as_survey_collection() duplicate-name repair snapshot

    Code
      coll <- as_survey_collection(d1, d1)
    Condition
      Warning:
      ! Duplicate survey name in collection repaired.
      i Rename: `d1 -> d1_1`.

# remove_survey() errors on unknown name

    Code
      remove_survey(coll, "nope")
    Condition
      Error in `remove_survey()`:
      x Name not found in collection: "nope".
      i Available: "a" and "b".

