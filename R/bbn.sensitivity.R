#' Sensitivity Analysis for Bayesian Belief Network Models
#'
#' \code{bbn.sensitivity()} conducts a sensitivity analysis on a Bayesian Belief Network (\code{BBN}) model.
#' It evaluates the impact of varying key \code{node} on the network's outcomes using \code{bootstrapping}.
#' The analysis helps identify which \code{node} significantly influence the network, providing insights into the robustness and dependency of the network's structure.
#'
#'
#' @param bbn.model a matrix or dataframe of interactions between different model \code{nodes}.
#' One or more \code{nodes} (recommended no more than 3) which would be the main outcomes of interest in the model.
#' The spelling of these \code{nodes} needs to be identical (including capital letters) to that in the matrix or dataframe file.
#' (note, you should include spaces if these are in your matrix or dataframe file, rather than the dot notation used once imported into R).
#' @param boot_max The number of bootstraps to perform.
#' Suggested range for exploratory analysis 100-1000.
#' For final analysis recommended size = 1000 - 10000 - note, this can take a long time to run.
#' Default value is 1000.
#' @param ... Key \code{nodes} for sensitivity analysis.
#' The function is designed to handle up to three key \code{nodes}, beyond which it recommends limiting the analysis for clarity and efficiency.
#'
#' @importFrom dplyr mutate recode "%>%"
#' @importFrom ggplot2 ggplot geom_point geom_errorbar geom_bar aes theme element_text coord_flip scale_y_continuous geom_smooth labs theme_classic scale_color_grey xlab ylab theme
#' @importFrom stats runif na.omit quantile
#' @importFrom grDevices dev.off pdf gray.colors
#' @importFrom igraph graph_from_data_frame
#' @importFrom grid pushViewport viewport grid.layout grid.newpage
#' @importFrom tibble tibble add_column
#'
#' @return The function outputs a plot showing the \code{nodes} most influential to the network's outcomes, alongside a table ranking these variables by their impact.
#' The analysis highlights how changes in the key \code{nodes} can affect the network, offering valuable insights for model refinement and decision-making.
#'
#' @examples
#' data(my_BBN)
#' bbn.sensitivity(bbn.model = my_BBN, boot_max = 100, 'Limpet', 'Green Algae')
#'
#' @export
bbn.sensitivity <- function(bbn.model, boot_max = 1000, ...){

  x<-length(list(...))
  if(x < 1){stop('Need to input at least one key variable', call. = FALSE)}
  if(x > 3){warning('Recommend a maximum of three key variables', call. = FALSE)}

  # Validate boot_max
  if (!is.numeric(boot_max) || boot_max <= 0) {
    stop("'boot_max' must be a positive integer", call. = FALSE)
  }

  node.x.increase.if.node.y.increase <- bbn.model  # bbn.model is matrix of interaction, read in from csv file

  names_node <- node.x.increase.if.node.y.increase[,1]
  number.nodes <- length(names_node)

  node <- array(NA,c(number.nodes,3))  ### setting up the node variable  -set at 0.5 as will be used like this throughout
  node[,3]<-names_node
  node[1:number.nodes,1]<-0.5
  node[1:number.nodes,2]<-0.5
  colnames(node)<- c('Increase','Decrease','name')
  node<-as.data.frame(node)
  node[,1]<-as.numeric(node[,1])
  node[,2]<-as.numeric(node[,2])

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

  ######################################## Stafford et al. 2015 Excel Calculations ########################################
  node.x.increase.if.node.y.increase <- node.x.increase.if.node.y.increase2
  adjust.number <- round(sum(apply(node.x.increase.if.node.y.increase,  1, function(x.33) length(which(!is.na(x.33)))))/10) # adjusting 10th of the parameters

  sens.names <- node.x.increase.if.node.y.increase

  rownames(sens.names) <- colnames(sens.names) ## needs row and column names

  sens.store <- array(NA,c(adjust.number,(boot_max-1)))

  for(boot in 1:boot_max){
    node2 <- node

    for(x in 1:number.nodes){
      node2$Increase[x]<-node2$Increase[x]+runif(1,-0.1,0.1)
    }

    node2$Decrease <- 1-node2$Increase

    #### set up dataframe to store sensitivity values

    adjust.count<-1
    size.adjust<-length(node.x.increase.if.node.y.increase)  ## changing by +/-0.1
    while(adjust.count<adjust.number+1){
      x_a1 <- round(runif(1,1,size.adjust))
      y_a1 <- round(runif(1,1,size.adjust))
      if(!is.na(node.x.increase.if.node.y.increase[x_a1,y_a1])){
        ## get value, and randomly increase by +/-0.1]
        if(boot==1){
          node.x.increase.if.node.y.increase[x_a1,y_a1]<-node.x.increase.if.node.y.increase[x_a1,y_a1]} ## note if bootstrap size is set to 1, then no bootstrapping takes place
        if(boot > 1){
          node.x.increase.if.node.y.increase[x_a1,y_a1]<-node.x.increase.if.node.y.increase[x_a1,y_a1] + runif(1,-0.1,0.1)}
        sens.store[adjust.count,(boot-1)]<-paste(rownames(sens.names)[x_a1],colnames(sens.names)[y_a1],sep="->")
        adjust.count <- adjust.count+1
      }
    }

    post.node2 <- array(NA, c(number.nodes, number.nodes))

    for(x.rep in 2:rep2){

      for(bbb in 1:(number.nodes*number.nodes)){   ### main Bayes equation
        temp1 <- (node.x.increase.if.node.y.increase[(ord[1,yyy[bbb]]),ord[2,yyy[bbb]]] * node2[ord[1,yyy[bbb]],1]) + (node.x.increase.if.node.y.decrease[ord[1,yyy[bbb]],ord[2,yyy[bbb]]] * node2[ord[1,yyy[bbb]],2])
        post.node2[ord[2,yyy[bbb]],ord[1,yyy[bbb]]] <- temp1
      } # not sure how the 'ord' works, but basically this multiples each value in the probability table by each prior to create 'posterior' probability table

      for (f in 1:number.nodes){

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
        else if(mean(post.node.calc) >= 0.5) {  ## if all 0.5 or above, then sort in descending order
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
        else if(mean(post.node.calc) <= 0.5) { ## if all 0.5 or below, then sort in ascending order
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

        post.node1 <- (node2[f,q]) # if nothing further affecting it, then it will revert to prior - in time series it is pulled towards 0.5
        post.node1.try2 <- temp2 # this section works out whether something is more certain if the prior is not used again
        #post.node1 <- mean(post.node.calc) # this one immediately reduces probability to post Bayes, so immediate changes, such as increasing reef, will only occur at intial time frame
        if(node2[f,1]> 0.5 & post.node1.try2 > post.node1) {post.node1 <- post.node1.try2}
        if(node2[f,1]< 0.5 & post.node1.try2 < post.node1) {post.node1 <- post.node1.try2}
        if(node2[f,1] == 0.5) {post.node1 <- post.node1.try2}
        node2[f,1:2]<- c(post.node1 , 1-post.node1)
        node.store2[f, x.rep] <- node2[f,1]

      } ### going wrong here, as on 2nd and third run through, those lower than 0.5 are turning into NaN

    }
    boot.node.store[,,boot]<-node.store2
  }

  ### sensitivity analysis ######

  key.variable1 <- c(...)

  max.variable <- length(key.variable1)

  #### calculate which parameters changed in the top 25% of bootstrapped replications

  display.number <- round(boot_max*0.25)
  if(display.number<1){
    display.number=1
  }

  sens.output <- array(NA,c(adjust.number,display.number,max.variable))


  for(var1 in 1:max.variable){


    find.col <- which(node[,3]==key.variable1[var1])
    key.values1<-boot.node.store[find.col,rep2,]

    dif.val <- abs(key.values1 - key.values1[1])### work out the differences between actual and bootstrapped
    dif.val.adjust <- runif(boot_max,-0.0001, 0.0001) # to adjust the numbers to prevent ties
    dif.val <- dif.val+dif.val.adjust

    dif.val.rank <- rank(dif.val) # rank biggest



    for(output.param in 1:display.number){
      output.index <- boot_max - (output.param-1)
      output.save <- which(dif.val.rank==output.index)
      if (identical (output.save, integer(0)) == T) {print ("Key variable name cannot be found. Please, check spelling and white space")}
      sens.output[,output.param,max.variable] <- sens.store[,(output.save-1)] ### -1 as there is no storage of first set of parameters as these don't change
    }

  }

  tab<-table(sens.output)

  tab<-tab[order(tab)]

  tab<-as.data.frame(tab)

  p<- ggplot(tab,                                   # Draw barchart of table
             aes(x = sens.output,
                 y = Freq)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x=element_text(angle = -90, hjust = 0))

  print(p)

  print(tab)

}
