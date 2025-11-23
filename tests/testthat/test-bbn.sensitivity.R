# bbn.sensitivity ------------------------------------------------

context("Testing bbn.sensitivity Functionality")

# Use example data provided by the bbnetwebasm package.

# Test that bbn.sensitivity requires at least one key variable
test_that("bbn.sensitivity requires at least one key variable", {
  data("my_BBN") # Make sure the 'my_BBN' dataset is loaded or defined appropriately
  expect_error(
    bbn.sensitivity(bbn.model = my_BBN, boot_max = 100),
    "Need to input at least one key variable"
  )
})

# Test for warning on more than three key variables
test_that("Warns on more than three key variables", {
  data("my_BBN") # Ensure this dataset is correctly defined or loaded
  expect_warning(
    bbn.sensitivity(bbn.model = my_BBN, "Limpet", "Green Algae", "Periwinkle", "Biofilm", boot_max = 100),
    "Recommend a maximum of three key variables"
  )
})

# Test function runs without error with correct input
test_that("bbn.sensitivity runs correctly with valid inputs", {
  data("my_BBN") # Ensure 'my_BBN' is available
  expect_output(
    bbn.sensitivity(bbn.model = my_BBN, "Limpet", boot_max = 100)
  )
})

# Test handling of incorrect 'boot_max'
test_that("bbn.sensitivity handles incorrect boot_max value", {
  data("my_BBN") # Ensure 'my_BBN' is available
  expect_error(
    bbn.sensitivity(bbn.model = my_BBN, "Limpet", boot_max = -100),
    "'boot_max' must be a positive integer"
  )
})
