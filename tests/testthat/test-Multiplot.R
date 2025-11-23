# Multiplot ----------------------------------------

# Setup example plots
plot1 <- ggplot(mtcars, aes(x=mpg, y=wt)) + geom_point()
plot2 <- ggplot(mtcars, aes(x=mpg, y=cyl)) + geom_point()
plot3 <- ggplot(mtcars, aes(x=gear, y=wt)) + geom_point()

# Test plotting multiple plots in a single row
test_that("multiplot handles multiple plots in a single row", {
  expect_silent(multiplot(plot1, plot2, plot3, cols=3))
})

# Test plotting using a custom layout
test_that("multiplot handles custom layouts", {
  layout_matrix <- matrix(c(1,2,3,3), nrow=2, byrow=TRUE)
  expect_silent(multiplot(plotlist=list(plot1, plot2, plot3), layout=layout_matrix))
})

# Test plotting a single plot
test_that("multiplot handles a single plot", {
  expect_silent(multiplot(plot1))
})
