#' Multiplot function
#'
#' This function allows for the arrangement and display of multiple \code{ggplot2} plots on a single graphics page.
#'
#' \code{multiplot()} can take any number of plot objects as arguments, or if it can take a list of plot objects passed to plotlist.
#'
#' \code{multiplot()} is built under CC0 licence from:
#'
#' \url{http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/}
#'
#' \code{ggplot2} objects can be passed in ..., or to plotlist (as a list of \code{ggplot2} objects)
#'
#' Details:
#' \itemize{
#'   \item cols: Number of columns in layout.
#'   \item layout: A matrix specifying the layout.If present, \code{cols} is ignored.
#' }
#'
#' If the layout is something like \code{matrix(c(1,2,3,3), nrow=2, byrow=TRUE)}, then plot 1 will go in the upper left, 2 will go in the upper right, and 3 will go all the way across the bottom.
#'
#' @param ... One or more \code{ggplot2} objects to be plotted.
#' @param plotlist An optional list of \code{ggplot2} objects. This parameter can be used in conjunction with or instead of the direct plot arguments.
#' @param file A path to save the output file.
#' @param cols Specifies the number of columns in the grid layout if \code{layout} is not provided. Defaults to 1.
#' @param layout An optional matrix specifying the layout of plots. Overrides \code{cols} if provided.
#'
#' @importFrom dplyr mutate recode "%>%"
#' @importFrom stats runif na.omit quantile
#' @importFrom grDevices dev.off pdf gray.colors
#' @importFrom grid pushViewport viewport grid.layout grid.newpage
#' @importFrom tibble tibble add_column
#'
#' @return plot
#'
#' @examples
#' # Load necessary library
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   library(ggplot2)
#'
#'   # Create example ggplot objects
#'   plot1 <- ggplot(mtcars, aes(x = mpg, y = wt)) +
#'     geom_point()
#'   plot2 <- ggplot(mtcars, aes(x = mpg, y = cyl)) +
#'     geom_point()
#'   plot3 <- ggplot(mtcars, aes(x = gear, y = wt)) +
#'     geom_point()
#'
#'   # Plot all three plots in a single row
#'   multiplot(plot1, plot2, plot3, cols = 3)
#'
#'   # Plot using a custom layout
#'   layout_matrix <- matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE)
#'
#'   multiplot(plotlist = list(plot1, plot2, plot3), layout = layout_matrix)
#' }
#'
#' @export
multiplot <- function(..., plotlist = NULL, file, cols = 1, layout = NULL) {
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots <- length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots / cols)),
      ncol = cols, nrow = ceiling(numPlots / cols)
    )
  }

  if (numPlots == 1) {
    print(plots[[1]])
  } else {
    # Set up the page``
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(
        layout.pos.row = matchidx$row,
        layout.pos.col = matchidx$col
      ))
    }
  }
}
