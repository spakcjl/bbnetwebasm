#' Bayesian Belief Network Prediction
#'
#' \code{bbn.predict} performs predictions using a Bayesian Belief Network \code{(BBN)} model,
#' accommodating multiple \code{priors} scenarios and allowing for \code{bootstrapping} to assess variability.
#'
#' \itemize{
#'   \item Supports input of multiple \code{priors} through \code{ellipsis()}.
#'   \item Allows \code{bootstrapping} with a specified number of maximum iterations to assess prediction variability.
#'   \item Generates \code{plots} for visual representation of the predictions.
#' }
#'
#' @param bbn.model  A matrix or dataframe of interactions between different model \code{nodes}.
#' @param ... An X by 2 array of initial changes to the system under investigation.
#' It requires at least 1 prior scenario (up to 12 priors).
#' The first column should be a -4 to 4 (including 0) integer value for each \code{node} in the network with negative values
#' indicating a decrease and positive values representing an increase. 0 represents no change.
#' Note, names included here are included as outputs in tables and figures.
#' Shortening these names can provide better figures.
#' @param boot_max The number of bootstraps to perform. Suggested range for exploratory analysis 1-1000.
#' For final analysis recommended size = 1000 - 10000 - note, this can take a long time to run.
#' Default value is 1, running with no \code{bootstrapping} - suitable for exploration of data and error checking.
#' @param values  This provides a numeric output of \code{posterior} values and any \code{confidence intervals}.
#' Default value 1. Set to 0 to hide this output.
#' @param figure Sets the figure options. Default value 1. 0 = no figures produced.
#' 1 = figure is saved in working directory as a PDF file (note, this is overwritten if the name is not changed, and no figure is produced if the existing PDF is open when the new one is generated).
#' 2 = figure is produced in a graphics window.
#' All figures are combined on a single plot where scenario 2 is below scenario 1 (i.e. scenarios work in columns then rows)
#' @param font.size Font size for the plot labels. Defaults to 5.
#'
#' @importFrom dplyr mutate recode "%>%"
#' @importFrom ggplot2 ggplot geom_point geom_errorbar geom_bar aes theme element_text coord_flip scale_y_continuous geom_smooth labs theme_classic scale_color_grey xlab ylab theme
#' @importFrom stats runif na.omit quantile
#' @importFrom grDevices dev.off pdf gray.colors
#' @importFrom igraph graph_from_data_frame
#' @importFrom grid pushViewport viewport grid.layout grid.newpage
#' @importFrom tibble tibble add_column
#'
#' @return Plots of the \code{(BBN)} predictions and optionally prints the predicted values.
#'
#' @examples
#' data(my_BBN, combined)
#'# Run the prediction
#' bbn.predict(bbn.model = my_BBN, priors1 = combined, boot_max=100, values=1, figure=1, font.size=5)
#'
#' @export
bbn.predict <- function(bbn.model, ..., boot_max=1, values = 1, figure = 1, font.size=5){
  # Collect all priors passed through '...'
  list <- list(...)
  plot.keep= list() # to display plots at the end of the function
  policyno = length(list)
  output.list <- list()  # will store summary + plot for each scenario


  if(length(list)>12){
    warning('Limit of 12 scenarios at once. Graphs may fail to print properly')
  }

  #print(list(...)[1])

  for(policy in 1:policyno){

    # if uploading priors

    node <- list[[policy]]

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



    node.x.increase.if.node.y.increase <- bbn.model #read.csv(bbn.model, header = T)  # bbn.model is matrix of interaction, read in from csv file

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


    ###################### to here  -see additional paramters to add to the input.params function


    rep2 <- 4 # number of repetitions of the standard model


    ## storage of probabilities over time

    #node.store <- array(NA, c(number.nodes,rep)) # time series model
    node.store2 <- array(NA, c(number.nodes,rep2)) # original model
    boot.node.store <- array(NA,c(number.nodes,rep2,boot_max))

    #for(aaa in 1:number.nodes){node.store[aaa,1] <- node[aaa,1]}
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

    ######################################## as per Stafford et al. 2015 Excel Calculations ########################################
    for(boot in 1:boot_max){
      node2 <- node
      node.x.increase.if.node.y.increase <- node.x.increase.if.node.y.increase2
      adjust.number <- round(sum(apply(node.x.increase.if.node.y.increase,  1, function(x.33) length(which(!is.na(x.33)))))/10) # adjusting 10th of the parameters  -this picks which parameters to adjust in each bootsrap run, but doesn't apply to first run


      adjust.count<-1
      size.adjust<-length(node.x.increase.if.node.y.increase)  ## changing some of the parameters by +/-0.1 to create bootstrapping
      while(adjust.count<adjust.number+1){
        x_a1 <- round(runif(1,1,size.adjust))
        y_a1 <- round(runif(1,1,size.adjust))
        if(!is.na(node.x.increase.if.node.y.increase[x_a1,y_a1])){
          ## get value, and randomly increase by +/-0.1]
          if(boot==1){
            node.x.increase.if.node.y.increase[x_a1,y_a1]<-node.x.increase.if.node.y.increase[x_a1,y_a1]} ## note if bootstrap size is set to 1, then no bootstrapping takes place
          if(boot > 1){
            node.x.increase.if.node.y.increase[x_a1,y_a1]<-node.x.increase.if.node.y.increase[x_a1,y_a1] + runif(1,-0.1,0.1)}
          adjust.count <- adjust.count+1
        }
      }

      post.node2 <- array(NA, c(number.nodes, number.nodes))

      for(x.rep in 2:rep2){

        for(bbb in 1:(number.nodes*number.nodes)){   ### main Bayes equation
          temp1 <- (node.x.increase.if.node.y.increase[(ord[1,yyy[bbb]]),ord[2,yyy[bbb]]] * node2[ord[1,yyy[bbb]],1]) + (node.x.increase.if.node.y.decrease[ord[1,yyy[bbb]],ord[2,yyy[bbb]]] * node2[ord[1,yyy[bbb]],2])
          post.node2[ord[2,yyy[bbb]],ord[1,yyy[bbb]]] <- temp1
        } # this multiples each value in the probability table by each prior to create 'posterior' probability table

        for (f in 1:number.nodes){ ## converted via Bayes equation at this point, but testing  whether multiple nodes are pulling in the same direction - if so, combining probabilities, rather than averaging - see Stafford et al. 2015 for details

          post.node.calc <- c(post.node2[f,1:number.nodes])
          post.node.calc <- na.omit(post.node.calc)

          if(isEmpty(post.node.calc)) {
            temp2<-node2[f,1]
            #print('empty')
            #print(temp2)
            #print(f)
          }
          else if(all(post.node.calc == 0.5) == T){
            temp2 <- 0.5#mean(post.node.calc) # if all calculations of prior are 0.5, then take mean (set at 0.5)
            #print('0.5')
            #print(temp2)
            #print(f)
          }
          else if(mean(post.node.calc) >= 0.5) {  ## if all 0.5 or above, then sort in descending order and combine
            post.node.calc <- sort(post.node.calc, decreasing = T)
            temp2 <- post.node.calc[1]
            if(length(post.node.calc)>1){
              for(cert in 2:length(post.node.calc)){
                temp2 <- temp2 + (post.node.calc[cert]-0.5)*(1-(temp2))
              }}
            #print('>0.5')
            #print(temp2)
            #print(f)
          }
          else if(mean(post.node.calc) <= 0.5) { ## if all 0.5 or below, then sort in ascending order and combine
            post.node.calc <- sort(post.node.calc, decreasing = F)
            temp2 <- post.node.calc[1]
            if(length(post.node.calc)>1){
              for(cert in 2:length(post.node.calc)){
                temp2 <- temp2 - (0.5-post.node.calc[cert])*((temp2))
              }}
            #print('<0.5')
            ##print(temp2)
            #print(f)
          }
          else{
            temp2 <- mean(post.node.calc)
            #print('none of above')
            #print(temp2)
            #print(f)
          }


          # if(all(is.na(post.node.calc))){
          #   post.node.calc <- 0.5
          #   print('all NA')
          #   print(f)
          # }
          #
          # if(is.na(temp2)){temp2<-mean(post.node.calc)}



          if(node2[f,1]>=0.5){q = 1}
          if(node2[f,1]<0.5){q=2}

          post.node1 <- (node2[f,q]) # if nothing further affecting it, then it will revert to prior - note in time series calc it is pulled towards 0.5 which is why values can differ
          post.node1.try2 <- temp2 # this section works out whether something is more certain if the prior is not used again
          #post.node1 <- mean(post.node.calc) # this one immediately reduces probability to post Bayes, so immediate changes, such as increasing reef, will only occur at intial time frame
          if(node2[f,1]> 0.5 & post.node1.try2 > post.node1) {post.node1 <- post.node1.try2}
          if(node2[f,1]< 0.5 & post.node1.try2 < post.node1) {post.node1 <- post.node1.try2}
          if(node2[f,1] == 0.5) {post.node1 <- post.node1.try2}
          node2[f,1:2]<- c(post.node1 , 1-post.node1)
          node.store2[f, x.rep] <- node2[f,1]

        }

      }
      boot.node.store[,,boot]<-node.store2
    }

    ## calculating bootstrap values - removing top and bottom 2.5% for 95% CI

    boot.node.mean <- apply(boot.node.store, c(1,2), mean)
    boot.node.upper<- apply(boot.node.store, c(1,2), quantile, probs=0.975)
    boot.node.lower<- apply(boot.node.store, c(1,2), quantile, probs=0.025)
    boot.node.actual <- boot.node.store[,,1] # note, this is the value from the first run, where no parameters were changed and forms the point on the final graph

    boot.node.upper.CI<- boot.node.upper - boot.node.mean
    boot.node.lower.CI <- boot.node.mean - boot.node.lower

    boot.node.actual.CI.upper <- boot.node.actual + boot.node.upper.CI
    boot.node.actual.CI.lower <- boot.node.actual - boot.node.lower.CI


    ########################################### end of Excel Version ######################################

    ##################### Calculation of values as per Stafford et al., 2015 and Excel model

    final.output <- node
    final.output.CI <- node
    colnames(final.output.CI)<-c('LowerCI','UpperCI','name')
    for(x in 1:dim(node)[1]){
      if((0.5 - min(boot.node.actual[x,]))>(max(boot.node.actual[x,])-0.5)){#if < 0.5 i.e. decreasing picks the lowest value across the four time steps
        final.output[x,1] <- min(boot.node.actual[x,])
        final.output[x,2] <- 1-final.output[x,1]
        final.output.CI[x,1] <- min(boot.node.actual.CI.lower[x,])
        final.output.CI[x,2] <- min(boot.node.actual.CI.upper[x,])

      }

      if((0.5 - min(boot.node.actual[x,]))<(max(boot.node.actual[x,])-0.5)){ #if>0.5 picks highest value across all time steps
        final.output[x,1] <- max(boot.node.actual[x,])
        final.output[x,2] <- 1-final.output[x,1]
        final.output.CI[x,1] <- max(boot.node.actual.CI.lower[x,])
        final.output.CI[x,2] <- max(boot.node.actual.CI.upper[x,])

      }
    }


    final.output <- cbind(final.output, final.output.CI[,1:2])



    final.output$name <- factor(final.output$name,levels=node$name)

    ### convert back to -4 to 4 scale


    final.output$Increase <- 10*(final.output$Increase - 0.5)
    #final.output$Decrease <- 8*(final.output$Decrease - 0.5) - no longer needed
    final.output$LowerCI <- 10*(final.output$LowerCI - 0.5)
    final.output$UpperCI <- 10*(final.output$UpperCI - 0.5)

    final.output <- subset(final.output, select = -Decrease)

    if(values==1){ ## print out outputs by scenario
      print(paste('Scenario number ', policy))
      print(final.output)
    }

    #### change extreme values so error bars print properly on figure

    ff <- function(a) {
      ifelse(a > 3.99, 3.99, a)
    }
    gg <- function(a) {
      ifelse(a < -3.99, -3.99, a)
    }


    final.output$Increase<-ff(final.output$Increase)
    final.output$Increase<-gg(final.output$Increase)
    final.output$LowerCI<-ff(final.output$LowerCI)
    final.output$LowerCI<-gg(final.output$LowerCI)
    final.output$UpperCI<-ff(final.output$UpperCI)
    final.output$UpperCI<-gg(final.output$UpperCI)





    p0<-ggplot(data=final.output, aes(x=name, y=Increase)) +
      geom_point(stat="identity", size=0.5) +
      geom_errorbar(aes(ymin = LowerCI, ymax = UpperCI), width=0.1) +
      xlab("") + ylab("Predicted change") +
      theme(text = element_text(size=font.size)) +  scale_y_continuous(limits = c(-4, 4))


    p0<-p0 + coord_flip()



    plot.keep[[policy]] <- p0

    output.list[[policy]] <- list(
      summary = final.output,
      plot = p0
    )


  }

  if(figure==1){## plot pdf figure to working directory

    pdf_file <- file.path(tempdir(), "BBN_Output_RenameMe.pdf")
    pdf(pdf_file)

    if(policyno==1){multiplot(plot.keep[[1]])}
    if(policyno==2){multiplot(plot.keep[[1]],plot.keep[[2]])}
    if(policyno==3){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], cols=2)}
    if(policyno==4){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]], cols=2)}
    if(policyno==5){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], cols=2)}
    if(policyno==6){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]], cols=2)}
    if(policyno==7){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]],plot.keep[[7]], cols=2)}
    if(policyno==8){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]], cols=2)}
    if(policyno==9){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],  plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],cols=2)}
    if(policyno==10){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],cols=2)}
    if(policyno==11){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],plot.keep[[11]],cols=3)}
    if(policyno==12){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],plot.keep[[11]], plot.keep[[12]],cols=3)}

    dev.off()
  }

  if(figure==2){ # plot figure to console
    if(policyno==1){multiplot(plot.keep[[1]])}
    if(policyno==2){multiplot(plot.keep[[1]],plot.keep[[2]])}
    if(policyno==3){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], cols=2)}
    if(policyno==4){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]], cols=2)}
    if(policyno==5){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], cols=2)}
    if(policyno==6){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]], cols=2)}
    if(policyno==7){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]],plot.keep[[7]], cols=2)}
    if(policyno==8){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]], cols=2)}
    if(policyno==9){multiplot(plot.keep[[1]],plot.keep[[2]], plot.keep[[3]], plot.keep[[4]],  plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],cols=2)}
    if(policyno==10){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],cols=2)}
    if(policyno==11){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],plot.keep[[11]],cols=3)}
    if(policyno==12){multiplot(plot.keep[[1]],plot.keep[[2]],plot.keep[[3]], plot.keep[[4]], plot.keep[[5]], plot.keep[[6]],plot.keep[[7]],plot.keep[[8]],plot.keep[[9]],plot.keep[[10]],plot.keep[[11]], plot.keep[[12]],cols=3)}
  }
  class(output.list) <- "bbnpredict"
  return(invisible(output.list))

}
