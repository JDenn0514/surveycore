# survey_weighting_history() errors for non-survey-object input

    Code
      survey_weighting_history(42)
    Condition
      Error in `survey_weighting_history()`:
      x `x` must be a survey design object.
      i Got <numeric>.

# D-22: haven_class rejects anything but a length-one logical

    Code
      survey_data(d, haven_class = "yes")
    Condition
      Error in `survey_data()`:
      x `haven_class` must be `TRUE` or `FALSE`.
      i Got a string.

---

    Code
      survey_data(d, haven_class = NA)
    Condition
      Error in `survey_data()`:
      x `haven_class` must be `TRUE` or `FALSE`.
      i Got `NA`.

---

    Code
      survey_data(d, haven_class = c(TRUE, TRUE))
    Condition
      Error in `survey_data()`:
      x `haven_class` must be `TRUE` or `FALSE`.
      i Got a logical vector.

---

    Code
      survey_data(d, haven_class = NULL)
    Condition
      Error in `survey_data()`:
      x `haven_class` must be `TRUE` or `FALSE`.
      i Got NULL.

# D-23: survey_data() still rejects a non-survey object

    Code
      survey_data(42)
    Condition
      Error in `survey_data()`:
      x `x` must be a survey design object.
      i Got <numeric>.

