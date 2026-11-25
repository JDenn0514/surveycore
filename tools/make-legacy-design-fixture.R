# Run from the package root with surveycore 1.0.0 and S7 0.2.2 installed.
library(surveycore)
stopifnot(
  packageVersion("surveycore") == "1.0.0",
  packageVersion("S7") == "0.2.2"
)
source("tests/testthat/helper-test-data.R")

classes <- c("taylor", "replicate", "twophase", "nonprob")
designs <- lapply(setNames(classes, classes), make_dataset_design, state = "none")
saveRDS(designs, "tests/testthat/fixtures/surveycore-1.0.0-designs.rds", version = 3)
