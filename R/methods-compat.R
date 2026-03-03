# R/methods-compat.R
#
# S7 methods that enable IDE compatibility features.
#
# These methods make survey design objects behave like data frames for the
# purposes of column name autocomplete in RStudio and Positron. When a
# survey object is the left-hand side of a pipe, IDEs call names() to
# discover column names and offer them as completions in tidy-select
# arguments of analysis functions like get_means(), get_freqs(), etc.
#
# Class defined in R/core-classes.R


# names() for survey design objects
#
# Returns the column names of the underlying data frame, enabling IDE
# column name completion in analysis functions. IDEs inspect the first
# argument of a pipe chain via names() to build the completion list for
# tidy-select arguments in downstream calls like get_means() or get_freqs().
#
# @param x A survey design object.
# @return A character vector of column names from x@data.
# Class defined in R/core-classes.R
S7::method(names, survey_base) <- function(x) names(x@data)
