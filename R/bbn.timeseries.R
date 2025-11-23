#' Time Series Prediction with Bayesian Belief Network
#'
#' \code{bbn.timeseries()} performs time series predictions using a Bayesian Belief Network (\code{BBN}) model based on a single \code{prior} scenario.
#' It generates figures illustrating how parameters change over time for all or selected \code{nodes}.
#'
#'
#' @param bbn.model  A matrix or dataframe of interactions between different model \code{nodes}.
#' @param priors1 An X by 2 array of initial changes to the system under investigation.
#' The first column should be a -4 to 4 (including 0) integer value for each \code{node} in the network with negative values
#' indicating a decrease and positive values representing an increase. 0 represents no change.
#' @param timesteps This is the number of \code{timesteps} the model performs. Default = 5.
#' Note, \code{timesteps} are arbitrary and non-linear. However, something occurring in \code{timestep 2}, should occur before \code{timestep 3}.
#' @param disturbance Default = 1.
#' 1 creates a prolonged or press \code{disturbance} as per \code{\link{bbn.predict}}.
#' Essentially \code{prior} values for each manipulated \code{node} are at least maintained (if not increased through reinforcement in the model) over all \code{timesteps}.
#' 2 shows a brief pulse \code{disturbance}, which can be useful to visualise changes as peaks and troughs in increase and decrease of \code{nodes} can propagate through the network.
#'
#' @importFrom dplyr mutate recode "%>%"
#' @importFrom ggplot2 ggplot geom_point geom_errorbar geom_bar aes theme element_text coord_flip scale_y_continuous geom_smooth labs theme_classic scale_color_grey xlab ylab theme
#' @importFrom stats runif na.omit quantile
#' @importFrom grDevices dev.off pdf gray.colors
#' @importFrom igraph graph_from_data_frame
#' @importFrom grid pushViewport viewport grid.layout grid.newpage
#' @importFrom tibble tibble add_column
#'
#' @return Plots for each \code{node} showing the predicted change over time.
#'
#' @examples
#' data(my_BBN, combined)
#' bbn.timeseries(bbn.model = my_BBN, priors1 = combined, timesteps=6, disturbance=1)
#'
#' @export
bbn.timeseries <- function(bbn.model, priors1, timesteps=5, disturbance = 1){ ### reads in a single scenario and makes figures of how parameters change over time for all or selected nodes

  node <- priors1 # read in single scenario

  # Check for expected structure in each prior
  if (!all(c("Increase", "Node") %in% colnames(node))) {
    stop("Each prior must contain 'Increase' and 'Node' columns.")
  }

  if (is.numeric(node[, 1]) == F) {stop("First column of priors values must contain numeric data")}

  colnames(node)<- c('Increase','name') # setting fixed column names as these are refered to later on

  ## Bayesian Belief network relies on values between 0 and 1, but -4 to 4 is much more intuitive, so converted at this stage
  node <- node %>%
    mutate(Increase = recode(Increase, '4' = '0.9', '3' = '0.8', '2' = '0.7', '1' ='0.6','-1'='0.4', '-2'='0.3', '-3'='0.2', '-4'='0.1', '0'='0.5'))

  node$Increase <- as.numeric(node$Increase)

  node$Decrease <- 1-node$Increase  # the decrease is 1- the increase once in probability format

  node <- node[,c('Increase','Decrease','name')]

  number.nodes <- dim(node)[1]

  #### edge strengths of the network, read in from the main csv file - again, converted from -4 to 4 into 0 to 1 format



  node.x.increase.if.node.y.increase <- bbn.model # input of bbm matrix

  if(identical(node[,2],node.x.increase.if.node.y.increase[,1] )==F){
    warning('Node names in priors are different to those in the interaction matrix - prior names will be used, but please check order of nodes is identical')
  }

  #### convert from +4 to -4 scale to 1 to 0 scale
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==4]<- 0.9
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==3]<- 0.8
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==2]<- 0.7
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==1]<- 0.6
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==-1]<- 0.4
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==-2]<- 0.3
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==-3]<- 0.2
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==-4]<- 0.1
  node.x.increase.if.node.y.increase[node.x.increase.if.node.y.increase==0]<- NA


  node.x.increase.if.node.y.increase <- node.x.increase.if.node.y.increase[,-1] # drops first column which was text

  node.x.increase.if.node.y.increase <- as.data.frame(node.x.increase.if.node.y.increase)

  node.x.increase.if.node.y.increase2 <- (0 + node.x.increase.if.node.y.increase) # force contents to act as numbers, as initially one column was text

  row.names(node.x.increase.if.node.y.increase)<-node$name # ensuring rows and columns in the model have the same names as the list of nodes
  colnames(node.x.increase.if.node.y.increase)<-node$name

  # create decrease matrix - for Bayes calculation
  node.x.increase.if.node.y.decrease <- (1 - node.x.increase.if.node.y.increase2)

  #fix(node.x.increase.if.node.y.decrease)


  rep <- timesteps # number of repititions of the time series model
  disturbancetype <- disturbance # prolonged pulse disturbance (1 = prolonged, 2 = pulse)

  ## storage of probabilities over time

  node.store <- array(NA, c(number.nodes,rep)) # time series model
  node.store2 <- array(NA, c(number.nodes,rep)) # original model
  #  boot.node.store <- array(NA,c(number.nodes,rep2,boot_max))

  for(aaa in 1:number.nodes){node.store[aaa,1] <- node[aaa,1]}
  for(aaa in 1:number.nodes){node.store2[aaa,1] <- node[aaa,1]}

  ### set up order to look at connections - specifies node 1 on node 2, node 1 on node 3 etc

  ord <- array(NA, dim=c(2,(number.nodes*number.nodes)))

  aaa <-1
  for(i in seq(1, (number.nodes*number.nodes), number.nodes)){
    ord[1,i:(i+number.nodes-1)]<-aaa
    aaa<-aaa+1
    ord[2,1:(i+number.nodes-1)] <- 1:number.nodes
  }

  yyy<- 1:(number.nodes*number.nodes)

  #### ordering complete

  ################################## Time series Calcs ##############################################

  post.node <- array(NA, c(number.nodes, number.nodes))

  for(x.rep in 2:rep){

    for(bbb in 1:(number.nodes*number.nodes)){
      temp1 <- (node.x.increase.if.node.y.increase[(ord[1,yyy[bbb]]),ord[2,yyy[bbb]]] * node[ord[1,yyy[bbb]],1]) + (node.x.increase.if.node.y.decrease[ord[1,yyy[bbb]],ord[2,yyy[bbb]]] * node[ord[1,yyy[bbb]],2])
      post.node[ord[2,yyy[bbb]],ord[1,yyy[bbb]]] <- temp1
    }

    for (f in 1:number.nodes){

      post.node.calc <- c(post.node[f,1:number.nodes])
      post.node.calc <- na.omit(post.node.calc)

      if(node[f,1]>=0.5){q = 1}
      if(node[f,1]<0.5){q=2}

      if(all(is.na(post.node.calc))){
        post.node.calc <- 0.5
      }

      if(disturbancetype == 1){
        post.node1 <- (node[f,q]) #### disturbance is prolonged and remains at prior value or greater throughout
      }
      if(disturbancetype == 2){
        post.node1 <- mean(post.node.calc) # pulse disturbance likely to dissipate rapidly
      }

      post.node1.try2 <- mean(post.node.calc) # this section works out whether something is more certain if the prior is not used
      if(node[f,1]> 0.5 & post.node1.try2 > post.node1) {post.node1 <- post.node1.try2}
      if(node[f,1]< 0.5 & post.node1.try2 < post.node1) {post.node1 <- post.node1.try2}
      if(node[f,1] == 0.5) {post.node1 <- post.node1.try2}
      node[f,1:2]<- c(post.node1 , 1-post.node1)
      node.store[f, x.rep] <- node[f,1]
    }

  }

  node.store<-(node.store-0.5)*10 # convert back to -4 to 4 scale

  for (graphmake in 1: number.nodes){

    # if(mean(node.store[graphmake,])>=0.5){
    #
    # y.vals <- node.store[graphmake,]/max(node.store[graphmake,])}
    #
    # if(mean(node.store[graphmake,])<0.5){
    #
    #   y.vals <- 1-(min(node.store[graphmake,])/node.store[graphmake,])}

    x.vals <- 1:dim(node.store)[2]

    y.vals <- node.store[graphmake,]

    vals <- cbind.data.frame(x.vals, y.vals)

    colnames(vals) <- c('x', 'y')

    name_y <- node[graphmake,3]


    p<-ggplot(vals, aes(x=x, y=y)) + geom_point(size=2, shape=23) + geom_smooth(se=F, method="loess") +
      labs(x="Time Step", y = name_y)+theme_classic() + scale_color_grey()

    print(p)


  }

}
