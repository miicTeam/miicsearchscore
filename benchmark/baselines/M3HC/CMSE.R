#libraries
library(pcalg)

# Function for computing the causal mean squared error (CMSE) metric
#
# Input
# originalGrap: an adjacency matrix representing the graph to be reconstructed
# reconstructedGraph: an adjacency matrix representing the reconstructed graph
# dataset: this dataset is generated from the original graph and 
#          it is used for building the reconstructed graph
# original.amat.type: the type of adjacency matrix for the original graph
#                     See amat.type in ?pcalg::adjustment for further information
# reconstructed.amat.type: the type of adjacency matrix for the reconstructed graph
#                          See amat.type in ?pcalg::adjustment for further information
# numVars: this is the number of randomly chosen nodes used in computing the cmse
#         if null (default), all nodes are used.
# seed: the seed for the random number generator, useful when numVars is specified
# verbose: boolean, if true information about the progress of the computation is displayed 
# 
# Output
# cmse: the cmse value
#
# Authors: Vincenzo Lagani, Sofia Triantafillou, Konstanstinos Tsirlis
#
# Contact: vincenzo.lagani@iliauni.edu.ge

CMSE <- function(originalGraph, reconstructedGraph, dataset, 
                         original.amat.type = 'pag', reconstructed.amat.type = 'pag',
                         numVars = NULL, seed = NULL, verbose = FALSE){
  
  #setting random seed
  if(!is.null(seed)){
    set.seed(seed)
  }
  
  #variables to check
  if(is.null(numVars)){
    numVars <- dim(originalGraph)[1]
    varsToCheck <- 1:numVars;
  }else{
    varsToCheck <- sample(1:(dim(originalGraph)[1]), numVars)
  }
  
  #initializing results
  numPairs <- numVars^2 - numVars
  originalGraphEE <- rep(NA, numPairs)
  reconstructedGraphEE <- rep(NA, numPairs)
  count <- 1
  
  #looping
  for(i in varsToCheck){
    for(j in varsToCheck){
      
      #skipping if the same variable
      if(i == j){
        next
      }

      #verbose? show information
      if(verbose){
        if(count %% 10 == 0){
          message(paste0('Iteration ', count, ' of ', numPairs))
        }
      }
      
      #causal effect on the original graph
      originalGraphEE[count] <- causalEffect(originalGraph, dataset, 
                                             original.amat.type, i, j)
            
      #causal effect on the reconstructed graph
      reconstructedGraphEE[count] <- causalEffect(reconstructedGraph, dataset, 
                                                  reconstructed.amat.type, i, j)
      
      #next iteration
      count <- count + 1;
      
    }
  }
  
  #computing cmse
  cmse <- mse(originalGraphEE, reconstructedGraphEE)

  #return
  return(cmse)
  
}

#causal effect computation
causalEffect <- function(graph, dataset, amat.type, i, j){
  
  #shall we transpose the graph?
  if(amat.type %in% c('dag', 'cpdag','pdag')){
    graph <- t(graph)
  }
  
  #adjustment set
  aSet <- adjustment(amat = graph, amat.type = amat.type, 
                     x = i, y = j, 'canonical')
  
  #checking if there is any adjustment set
  if(length(aSet) == 0){
    
    #if there is no adjustment set, then we (arbitrarily) set the causal effect to zero
    EE <- 0
    
  }else{
    
    #building the formula for the linear model used to estimate the causal effect
    if(length(aSet[[1]]) > 0){
      
      #in this case there is at least one element in the adjustement set (other than node i)
      tmp <- logical(dim(graph)[1])
      tmp[aSet[[1]]] <- TRUE;
      varSet <- paste('V', aSet[[1]], sep = '')
      f <- as.formula(paste(paste0('V', j), '~', paste0('V', i), 
                            '+', paste(varSet, collapse = '+'))) 
      
    }else{
      
      #no elements in the adjustement set, thus we only regress over node i
      f <- as.formula(paste(paste0('V', j), '~', paste0('V', i)))
      
    }
    
    #fitting the linear model and extracting the coefficient
    linearModel <- lm(formula = f, data = dataset)
    EE <- linearModel$coefficients[2] #magic number derived by how the formula is constructed.
    
  }
  
  #returning the estimate
  return(EE)
  
}

#mean square error function
mse <- function(es1, es2){
  mean((es1 - es2) ^ 2, na.rm = TRUE)
}
