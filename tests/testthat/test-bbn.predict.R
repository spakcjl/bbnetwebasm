# bbn.predict ----------------------------------------------------

context("Testing bbn.predict Functionality")

# This use example data provided by the bbnetwebasm package.

test_that("bbn.predict works with a single scenario", {
  data("my_BBN")
  data("dogwhelk")

  expect_output(bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, figure = 0), NULL)
})

test_that("bbn.predict handles multiple scenarios", {
  data("my_BBN")
  data("dogwhelk")
  data("winkle")
  data("combined")

  expect_output(bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, priors2 = winkle, priors3 = combined, figure = 0), NULL)
})

test_that("bbn.predict generates no plot when figure is set to 0", {
  data("my_BBN")
  data("dogwhelk")

  expect_output(bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, figure = 0))
})

test_that("bbn.predict saves plot to PDF when figure is 1", {
  data("my_BBN")
  data("dogwhelk")

  # Define the path to the test plot in the temporary directory
  test_plot_path <- file.path(tempdir(), "BBN_Output_RenameMe.pdf")

  # Ensure any previous test file is removed
  if (file.exists(test_plot_path)) {
    file.remove(test_plot_path)
  }

  # Call the function with the correct parameters
  bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, figure = 1)

  # Check if the file now exists
  expect_true(file.exists(test_plot_path))

  # Cleanup: remove the test plot file after checking
  file.remove(test_plot_path)
})


test_that("bbn.predict runs without error for figure = 2", {
  data("my_BBN")
  data("dogwhelk")

  # This test ensures the function call does not result in an error. It does not validate the actual plot output.
  expect_output(bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, figure = 2))
})

test_that("bbn.predict handles bootstrapping with boot_max > 1", {
  data("my_BBN")
  data("dogwhelk")

  # Ensure it runs without error.
  expect_output(bbn.predict(bbn.model = my_BBN, priors1 = dogwhelk, boot_max = 10, figure = 0))
})
