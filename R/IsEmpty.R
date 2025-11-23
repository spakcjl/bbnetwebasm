#' Check if an Object is Empty
#'
#' This function determines whether the provided object is empty.
#'
#' \code{isEmpty()} checks if the given object, \code{x}, has a length of 0,
#' indicating that it is empty. It can be used with various types of objects
#' in R, including vectors, lists, and data frames.
#'
#' @param x The object to check for emptiness.
#'
#' @return A logical value: \code{TRUE} if the object is empty, \code{FALSE} otherwise.
#'
#' @examples
#' # Check an empty vector
#' isEmpty(c())
#'
#' # Check a non-empty vector
#' isEmpty(c(1, 2, 3))
#'
#' # Check an empty list
#' isEmpty(list())
#'
#' # Check a non-empty list
#' isEmpty(list(a = 1, b = 2))
#'
#' # Check an empty data frame
#' isEmpty(data.frame())
#'
#' # Check a non-empty data frame
#' isEmpty(mtcars)
#'
#' @export
isEmpty <- function(x) {
  return(length(x)==0)
}
