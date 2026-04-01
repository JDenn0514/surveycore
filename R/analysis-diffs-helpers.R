# R/analysis-diffs-helpers.R
#
# Internal helpers for get_diffs(). Single-use helpers specific to
# get_diffs() live here; shared helpers used by multiple analysis
# functions live in R/analysis-helpers.R.
#
# Contents:
#   .stars_pval() — significance stars from p-values

# -- .stars_pval() ------------------------------------------------------------
#
# Convert p-values to significance star annotations.
#
# Cutpoints (strict inequality — equals goes to the less-significant bucket):
#   p < 0.001  -> "***"
#   p < 0.01   -> "**"
#   p < 0.05   -> "*"
#   p < 0.1    -> "."
#   p >= 0.1   -> ""
#   NA         -> ""
#
# @param p Numeric vector of p-values.
# @return Character vector of the same length as p.
.stars_pval <- function(p) {
  ifelse(
    is.na(p),
    "",
    ifelse(
      p < 0.001,
      "***",
      ifelse(
        p < 0.01,
        "**",
        ifelse(
          p < 0.05,
          "*",
          ifelse(p < 0.1, ".", "")
        )
      )
    )
  )
}
