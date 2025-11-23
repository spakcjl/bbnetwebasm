#' Create Network Diagram from Bayesian Belief Network Data
#'
#' \code{bbn.network.diagram()} generates a network diagram from a specified Bayesian Belief Network (\code{BBN}),
#' allowing for the visualization of the relationships and interactions between \code{nodes}.
#'
#' The diagram is created using \code{edge} and \code{node} data derived from the \code{BBN}, with \code{edges} representing
#' interactions (positive or negative) between \code{nodes}.
#'
#' \code{bbn.network.diagram()} visualises all \code{nodes} and interactions in a network, in a similar manner to \code{\link{bbn.visualise}}, other than this is the full network.
#'
#'
#' @param bbn.network A dataframe, with a first column called \code{id} that consists of an \code{s} and a 2 digit number relating to the \code{node} number.
#' The second column called \code{node.type} is an \code{integer} value from 1-4.
#' This sets the colour of the \code{node} in the network (sticking to a maximum of four colours).
#' The third column is the same as the first column in the standard \code{BBN} interaction matrix or dataframe, other than it is titled \code{node.name}.
#' It is important to use these column names (including capitals and dot notation).
#' The remainder of the columns are exactly as the standard \code{BBN} interaction matrix or dataframe.
#' @param font.size Changes the font in the figure produced. Default = 0.7.
#' The value here is a multiplier of the default font size used in the \code{igraph} package and does not correspond to the \code{font.size} argument in \code{\link{bbn.timeseries}}.
#' @param arrow.size  Changes the size of the arrows. Default = 4.
#' Note, sizes do vary based on interaction strength, so this is a multiplier for visualisation purposes.
#' Negative interactions are shown by red arrows, and positive interactions by black arrows.
#' @param arrange this describes how the final diagram looks.
#' Default is \code{layout_on_sphere} but \code{layout_on_grid} provides the same layout as in \code{\link{bbn.visualise}} and ensures \code{nodes} are structured in the order specified in the network.
#' Other layouts, including \code{layout_on_sphere} are more randomly determined, and better/clearer diagrams may occur if you run these multiple times.
#' Other options are from the igraph package:
#' \code{layout.sphere}
#' \code{layout.circle}
#' \code{layout.random}
#' \code{layout.fruchterman.reingold}
#'
#' @importFrom dplyr mutate recode "%>%"
#' @importFrom ggplot2 ggplot geom_point geom_errorbar geom_bar aes theme element_text coord_flip scale_y_continuous geom_smooth labs theme_classic scale_color_grey xlab ylab theme
#' @importFrom stats runif na.omit quantile
#' @importFrom grDevices dev.off pdf gray.colors
#' @importFrom igraph graph_from_data_frame
#' @importFrom grid pushViewport viewport grid.layout grid.newpage
#' @importFrom tibble tibble add_column
#'
#' @return A plot of the network diagram, illustrating the interactions (both positive and negative) between \code{nodes}.
#'
#' @examples
#' data(my_network)
#' bbn.network.diagram(bbn.network = my_network, font.size=0.7,
#'   arrow.size=4, arrange = layout_on_sphere)
#'
#' @export
bbn.network.diagram <- function(bbn.network, font.size=0.7, arrow.size=4, arrange = layout_on_sphere){

  dta <- bbn.network

  edges <-  data.frame(from=character(),to=character(),weight=integer(),type=integer(),stringsAsFactors=FALSE)

  nodes <- dta[,1:3]

  size.data <- dim(dta)[1]

  dta <- dta[,4:(size.data+3)]

  edge.count<-0

  for(x in 1:size.data){
    for(y in 1:size.data){
      if(is.na(dta[x,y])==F){
        edge.count <- edge.count+1
        edges[edge.count,1] <- as.character(nodes$id[x])
        edges[edge.count,2] <- as.character(nodes$id[y])
        if(dta[x,y]>0){
          edges[edge.count,3] <- dta[x,y]
          edges[edge.count,4] <- 1 # 1 = positive interaction, 2 = negative interaction

        }
        if(dta[x,y]<0){

          edges[edge.count,3] <- dta[x,y]*-1
          edges[edge.count,4] <- 2}


      }

    }
  }

  #write.csv(edges, 'EDGES_dept.csv')

  links <- edges

  net <- graph_from_data_frame(d=links, vertices=nodes, directed=T)

  # Generate colors based on node type:
  colrs <- c("gray50", "tomato", "gold", "white")
  V(net)$color <- colrs[V(net)$node.type]

  colrs2 <- c("black", "red")
  E(net)$color <- colrs2[E(net)$type]

  E(net)$width <- E(net)$weight*(arrow.size/4)
  V(net)$label.cex <-font.size
  V(net)$label.color <- 'blue'

  #l <- layout_on_sphere(net)

  print(plot(net, edge.arrow.size=0.3,vertex.label=nodes$node.name,edge.curved=.2, layout  =arrange))

}
