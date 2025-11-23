# bbn.visualise ------------------------------------------------

context("Testing bbn.visualise Functionality")

# Use example data provided by the bbnetwebasm package.

# Basic functionality - Checking for no error
test_that("bbn.visualise runs without error for basic input", {
  data("my_BBN")
  data("combined")
  expect_output(bbn.visualise(bbn.model = my_BBN, priors1 = combined))
})
