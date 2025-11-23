# isEmpty ----------------------------------------

# Test that the function correctly identifies empty vectors
test_that("isEmpty identifies empty vectors", {
  expect_true(isEmpty(c()))
})

# Test that the function correctly identifies non-empty vectors
test_that("isEmpty identifies non-empty vectors", {
  expect_false(isEmpty(c(1, 2, 3)))
})

# Test that the function correctly identifies empty lists
test_that("isEmpty identifies empty lists", {
  expect_true(isEmpty(list()))
})

# Test that the function correctly identifies non-empty lists
test_that("isEmpty identifies non-empty lists", {
  expect_false(isEmpty(list(a = 1, b = 2)))
})

# Test that the function correctly identifies empty data frames
test_that("isEmpty identifies empty data frames", {
  expect_true(isEmpty(data.frame()))
})

# Test that the function correctly identifies non-empty data frames
test_that("isEmpty identifies non-empty data frames", {
  expect_false(isEmpty(mtcars))
})
