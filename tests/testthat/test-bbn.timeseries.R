# bbn.timeseries ------------------------------------------------

context("Testing bbn.timeseries Functionality")

# Use example data provided by the bbnetwebasm package.

test_that("bbn.timeseries works with minimum required arguments and handles warnings", {
  data("my_BBN")
  data("combined")
  # Expected warnings when timesteps <= 5
  expect_warning(
    bbn.timeseries(bbn.model = my_BBN, priors1 = combined, timesteps = 5),
    regexp = "pseudoinverse used|neighborhood radius|reciprocal condition number|span too small",
    fixed = FALSE # Using regular expressions to match any part of the warnings
  )
})

test_that("bbn.timeseries handles different disturbance types with warnings up to 5 timesteps", {
  data("my_BBN")
  data("combined")
  # Expected warnings for timesteps <= 5
  expect_warning(
    bbn.timeseries(bbn.model = my_BBN, priors1 = combined, disturbance = 1, timesteps = 5),
    regexp = "pseudoinverse used|neighborhood radius|reciprocal condition number|span too small",
    fixed = FALSE
  )
  expect_warning(
    bbn.timeseries(bbn.model = my_BBN, priors1 = combined, disturbance = 2, timesteps = 5),
    regexp = "pseudoinverse used|neighborhood radius|reciprocal condition number|span too small",
    fixed = FALSE
  )
})

test_that("bbn.timeseries runs without errors for timesteps > 5, acknowledging warnings/messages", {
  data("my_BBN")
  data("combined")
  # Expect no errors, acknowledging that warnings and messages about geom_smooth or other conditions may occur
  expect_no_error(
    bbn.timeseries(bbn.model = my_BBN, priors1 = combined, timesteps = 10)
  )
})
