# bbn.network.diagram ----------------------------------------

context("Testing bbn.network.diagram Functionality")

# Use example data provided by the bbnetwebasm package.

# Ensure function runs without error with default parameters
test_that("bbn.network.diagram runs with default inputs", {
  data("my_network")
  expect_output(bbn.network.diagram(bbn.network = my_network))
})

# Ensure function runs without error for different font and arrow sizes
test_that("Function handles different font and arrow sizes", {
  data("my_network")
  expect_output(bbn.network.diagram(bbn.network = my_network, font.size = 1.2, arrow.size = 6))
})

# Test with different layout arrangements
test_that("Function handles different layout arrangements", {
  data("my_network")
  expect_output(bbn.network.diagram(bbn.network = my_network, arrange = layout_on_sphere))
})

test_that("Function handles different layout arrangements", {
  data("my_network")
  expect_output(bbn.network.diagram(bbn.network = my_network, arrange = layout_on_grid))
})
