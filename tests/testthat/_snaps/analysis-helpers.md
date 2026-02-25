# .validate_shared_args() rejects unknown variance values

    Code
      .validate_shared_args("bogus", 0.95, "surveycore")
    Condition
      Error:
      x `variance` values must be from "se", "ci", "var", "cv", "moe", or "deff".
      i Unknown value: "bogus".

# .validate_shared_args() rejects non-numeric conf_level

    Code
      .validate_shared_args(NULL, "high", "surveycore")
    Condition
      Error:
      x `conf_level` must be a single number strictly between 0 and 1.
      i Got "high".

# .validate_shared_args() rejects invalid name_style

    Code
      .validate_shared_args(NULL, 0.95, "tidy")
    Condition
      Error:
      x `name_style` must be "\"surveycore\"" or "\"broom\"".
      i Got "tidy".

# .build_meta() fallback throws surveycore_error_unsupported_class

    Code
      .build_meta(list(data = data.frame(x = 1)), list())
    Condition
      Error in `.build_meta()`:
      x Unrecognized design class <list>.

# .check_unsupported_class() throws for a plain data frame

    Code
      .check_unsupported_class(data.frame(x = 1), "get_means")
    Condition
      Error in `.check_unsupported_class()`:
      x `get_means()` requires a survey design object.
      i Got <data.frame>.

