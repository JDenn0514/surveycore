# dim() on a two-member survey_collection renders its message

    Code
      dim(cl)
    Condition
      Error in `dim()`:
      x A <survey_collection> has no single set of dimensions.
      i It holds 2 surveys, each with its own row and column counts.
      v Extract one member with `[[` and ask that survey instead, e.g. the member named "wave_one".

# dim() on a one-member survey_collection reads the singular noun

    Code
      dim(cl)
    Condition
      Error in `dim()`:
      x A <survey_collection> has no single set of dimensions.
      i It holds 1 survey, each with its own row and column counts.
      v Extract one member with `[[` and ask that survey instead, e.g. the member named "wave_one".

# nrow() on a survey_collection renders the same message as dim()

    Code
      nrow(cl)
    Condition
      Error in `dim()`:
      x A <survey_collection> has no single set of dimensions.
      i It holds 2 surveys, each with its own row and column counts.
      v Extract one member with `[[` and ask that survey instead, e.g. the member named "wave_one".

