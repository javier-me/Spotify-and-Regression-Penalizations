####################################################################################### 
##################################### PART 2 ##########################################
####################################################################################### 

library(MASS)
library(faux)
#install.packages('MLmetrics')
library(MLmetrics)
library(plotly)
#install.packages('GMCM')
library(GMCM)

######################### Set Desired Directory for Saving Files ####################  
# In the last part of the script, we have several functions that run simulations
# with different parameters and output the results in .csv format. For that, we have
# this variable to set the desired directory to save the .csv file in at the beginning
# of this script, so different people can easily exchange the script and output the results
# and saving is easier

# By default, the lines where we run those functions that save the results in .csv are
# commented out because some have quite long computation times. each line for which one
# would like to see the results should be commented out.

directory = "/Users/javier/Desktop/LSE/ST443 Machine Learning & Data Mining/Group Project/"


############################## Define parameter variables ############################################################ 

# actual_beta as in outline:
actual_beta = c(3,1.5,0, 0, 2, 0, 0, 0)


sigma = 3 #The white noise is multiplied by a sigma constant.
#Create a blank matrix and assign to cor
cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
rownames(cor) <- c(1:nrow(cor))
colnames(cor) <- c(1:ncol(cor))
#Calculate correlation values between each variable as per question
for (i in 1:nrow(cor)){
  for (j in 1:ncol(cor)){
    cor[i,j] = 0.5^ abs(i-j)
  }
}


##########################  Data Creation ################################################### 
data_creation <- function(cor, n,  x = 0.5, sigma, actual_beta = actual_beta){
  # Put n number of rows as argument so later we can experiment with that
  #set.seed(42) # We comment this out for variability in dataset generation loop
  # Train, Validation & Test X
  train_size <- round(x*n, 0)
  #print(train_size)
  validation_size <- n - train_size
  train <- as.matrix(rnorm_multi(train_size, mu = 0, sd = 1, r = cor))
  validation <- as.matrix(rnorm_multi(validation_size, mu = 0, sd = 1, r = cor))
  test <- as.matrix(rnorm_multi(10*validation_size, mu = 0, sd = 1, r = cor))
  # Function guesses we have 8 variables through the covriance matrix
  # Noise
  noise_train = rnorm(nrow(train), 0, 1)
  noise_validation = rnorm(nrow(validation), 0, 1)
  noise_test = rnorm(nrow(test), 0, 1)
  # Train, Validation & Test Y
  Y_train = train %*% actual_beta + sigma * noise_train
  Y_validation = validation %*% actual_beta + sigma * noise_validation
  Y_test = test %*% actual_beta + sigma * noise_test
  #Create an empty vector to store the residuals
  vars = list(Y_train, Y_validation, Y_test, train, validation, test)
  assign("Y_train", Y_train, envir=.GlobalEnv)
  assign("Y_validation", Y_validation, envir=.GlobalEnv)
  assign("Y_test", Y_test, envir=.GlobalEnv)
  assign("train", train, envir=.GlobalEnv)
  assign("validation", validation, envir=.GlobalEnv)
  assign("test", test, envir=.GlobalEnv)
  #return(vars) 
}
#data_creation(cor, n = 40, x = 0.5, actual_beta = actual_beta, sigma = sigma)

##############  Coordinate Descent Algorithm for LASSO and Elastic Net ######################## 
coord_descent <- function(Y_train, train, lambda1, lambda2, actual_beta = actual_beta){
  initial_beta = rep(0, length(actual_beta))
  temp_beta = rep(0, length(actual_beta))
  previous_beta = rep(0, length(actual_beta))
  r <- matrix(data = 0, nrow = nrow(train), ncol = length(actual_beta))
  convergence = FALSE
  conv_loops = 0
  while(convergence == FALSE){
    conv_loops = conv_loops + 1
    for (j in 1:length(actual_beta)) {
      r[,j] = Y_train - (train[,-j] %*% initial_beta[-j])
      # One column of residuals for all lines
      temp_beta[j] = sum(train[,j] * r[,j]) / nrow(train)
      # Simple Least Squares Coefficients
      temp_beta[j] <- (1 + 2*lambda2)^-1 * sign(temp_beta[j]) *max((abs(temp_beta[j]) - lambda1),0)
      # Lambda2 is squared penalization (Ridge), Lambda1 is absolute value penalization (LASSO)
      initial_beta[j] = temp_beta[j]
    }
    if (all(round(previous_beta, 5) == round(temp_beta,5))){
      convergence = TRUE
    } else {
      previous_beta = temp_beta
    }
    if (conv_loops > 500) {
      return(temp_beta)
      break
    }
  }
  return(temp_beta)
}

################ Validation for LASSO and Elastic Net, with own function #################

LASSO_errors<- function(lambdas1, Y_train, train, Y_validation, validation, actual_beta = actual_beta){
  container = matrix(0, length(lambdas1), 2)
  for (lambda1 in lambdas1){
    betas = coord_descent(Y_train, train, lambda1 = lambda1, lambda2 = 0, actual_beta = actual_beta)
    error = MSE(validation %*% betas, Y_validation)
    container[which(lambdas1 == lambda1), 1] = lambda1
    container[which(lambdas1 == lambda1), 2] = error
  }
  min_error = min(container[,2], na.rm = TRUE)
  best_lambda = container[which.min(container[,2]),1]
  best_betas = coord_descent(Y_train, train, lambda1 = best_lambda, lambda2 = 0, actual_beta = actual_beta)
  #cat("results", best_lambda, min_error, best_betas)
  return(list(best_lambda, min_error, best_betas, container))
}

EN_errors<- function(lambdas1, lambdas2, Y_train, train, Y_validation, validation, actual_beta = actual_beta){
  container = matrix(0, length(lambdas1), length(lambdas2))
  for (lambda1 in lambdas1){
    for (lambda2 in lambdas2){
      betas = coord_descent(Y_train, train, lambda1 = lambda1, lambda2 = lambda2, actual_beta = actual_beta)
      error = MSE(validation %*% betas, Y_validation)
      container[which(lambdas1 == lambda1), which(lambdas2 == lambda2)] = error
    }
  }
  index = which(container == min(container), arr.ind = TRUE)
  min_error = container[index]
  best_lambda1 = lambdas1[index[1]]
  best_lambda2 = lambdas2[index[2]]
  best_betas = coord_descent(Y_train, train, lambda1 = best_lambda1, lambda2 = best_lambda2, actual_beta = actual_beta)
  #cat("results", best_lambda1, best_lambda2, min_error, best_betas)
  return(list(best_lambda1, best_lambda2, min_error, best_betas, container))
}

############################## LASSO Testing ####################################
Model_testing_LASSO <- function(datasets = 50, cor = cor, n = 20, x = x, sigma = sigma, actual_beta = actual_beta){
  dataset_errors_lambda= matrix(rep(0, datasets)*5, nrow = datasets, ncol = 5)
  # We'll store the error and the 2 lambdas here
  for (d in 1:datasets){
    data_creation(cor, n, x, sigma, actual_beta = actual_beta)
    validation_results <- LASSO_errors(lambdas1, Y_train, train, Y_validation, validation, actual_beta = actual_beta)
    dataset_errors_lambda[d,1] = validation_results[[1]] # Best lambda
    dataset_errors_lambda[d,2] = validation_results[[2]] # Validation Error for Best Lambda
    best_betas <- coord_descent(Y_train, train, lambda1 = validation_results[[1]], lambda2 = 0, actual_beta = actual_beta)
    dataset_errors_lambda[d,3] =  MSE(test %*% best_betas, Y_test) # Test Error with given lambda and betas
    dataset_errors_lambda[d,4] =  sum(best_betas != 0)
    dataset_errors_lambda[d,5] =  mean(best_betas[which(best_betas != 0)])
  }
  colnames(dataset_errors_lambda) = c("best_lambda", "Validation MSE", "Test MSE", "No. of non-zero betas", "Avg. of non-zero betas")
  return(dataset_errors_lambda)
}

lambdas1 = runif(40, min = 0, max = 4)
lambdas2 = c()

############################## Elastic Net Testing ####################################
Model_testing_EN <- function(datasets = 50, cor = cor, n = 20, x = x, sigma = sigma, actual_beta = actual_beta){
  dataset_errors_lambda= matrix(rep(0, datasets)*6, nrow = datasets, ncol = 6)
  # We'll store the error and the 2 lambdas here
  for (d in 1:datasets){
    data_creation(cor, n, x, sigma, actual_beta = actual_beta)
    validation_results <- EN_errors(lambdas1, lambdas2, Y_train, train, Y_validation, validation, actual_beta = actual_beta)
    dataset_errors_lambda[d,1] = validation_results[[1]] # Best lambda1
    dataset_errors_lambda[d,2] = validation_results[[2]] # Best Lambda 2
    dataset_errors_lambda[d,3] = validation_results[[3]] # Validation Error for Best Lambda
    best_betas <- coord_descent(Y_train, train, lambda1 = validation_results[[1]], lambda2 = validation_results[[2]], actual_beta = actual_beta)
    dataset_errors_lambda[d,4] =  MSE(test %*% best_betas, Y_test) # Test Error with given lambda and betas
    dataset_errors_lambda[d,5] =  sum(best_betas != 0)
    dataset_errors_lambda[d,6] =  mean(best_betas[which(best_betas != 0)])
  }
  colnames(dataset_errors_lambda) = c("best_lambda1","best_lambda2", "Validation MSE", "Test MSE", "No. of non-zero betas", "Avg. of non-zero betas")
  return(dataset_errors_lambda)
}

lambdas1 = runif(40, min = 0, max = 4)
lambdas2 = runif(40, min = 0, max = 4)

########################### Graphs lambda validation  ###########################
#Activate libraries, data creation, coordinate descent, lambda and LASSO_errors and EN_errors first
##### LASSO
actual_beta = c(3,1.5,0, 0, 2, 0, 0, 0)
sigma = 3
cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
rownames(cor) <- c(1:nrow(cor))
colnames(cor) <- c(1:ncol(cor))
for (i in 1:nrow(cor)){ #Calculate correlation values between each variable as per question
  for (j in 1:ncol(cor)){
    cor[i,j] = 0.5^ abs(i-j)
  }
}
data_creation(cor, n = 40, x = 0.5, sigma = sigma, actual_beta = actual_beta)
lambdas1 = seq(from = 0, to = 4, by = 0.1)

container <- LASSO_errors(lambdas1, Y_train, train, Y_validation, validation, actual_beta = actual_beta)
# container[[4]][,1] are the Lambdas, container[[4]][,2] are the Validation Errors
plot(container[[4]][,1], container[[4]][,2], main="MSE Lambda Scatterplot",
     xlab="Lambda ", ylab="Validation MSE ", pch=19)  

##### Elastic Net
lambdas2 = seq(from = 0, to = 4, by = 0.1) # Add lambdas2 for Elastic Net

container_EN <- EN_errors(lambdas1, lambdas2, Y_train, train, Y_validation, validation, actual_beta = actual_beta)
plot_ly(z = container_EN[[5]], type="surface")

########################### PARAMETER LOOPING ###########################
actual_beta = c(3,1.5,0, 0, 2, 0, 0, 0)
sigmas = c(0, 1, 2, 3, 4, 5, 6)
n = 40
## n is train + validation now, in base case it's 40
x = 0.5
# This decides what percentage of n goes to the training data, and the remaining one to the validation data
lambdas1 = runif(40, min = 0, max = 4)
datasets = 50

########## In each of the follwing functions, one .csv file will be outputted. In each,
########## the last two lines will be the mean and the standard dev. of the columns, respectively

####### LASSO
sigma_loop_L <- function(sigmas, actual_beta, n = 40, x = x, datasets = 50){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (sigma in sigmas) {
    ds_test_own_func_LASSO <- Model_testing_LASSO(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_LASSO <- as.data.frame(ds_test_own_func_LASSO)
    ds_test_own_func_LASSO <- ds_test_own_func_LASSO[is.finite(rowSums(ds_test_own_func_LASSO)),] # Remove possible NAs
    ds_test_own_func_LASSO = rbind(ds_test_own_func_LASSO, colMeans(ds_test_own_func_LASSO), apply(ds_test_own_func_LASSO, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_LASSO,paste(directory, "LASSO Testing", "sigma", sigma,".csv"), row.names = TRUE)
  }
}
x = 0.5
#sigma_loop_L(sigmas, actual_beta, n = 40, x = 0.5, datasets = 50)
# Saves on csv with results for each value of looped parameter on secified directory
# Last 2 rows of the csv table are the mean and the standard dev, respectively

sigma = 3
lambdas1 = runif(40, min = 0, max = 4)
split_values = c(0.25, 0.5, 0.75, 0.9) # Small values of x give problems, too little entries for training. 0.25 is ok as lowest value
# x determines how much of a % of n goes to the train data, the remaining % goes to validation
# For test we have 10*validation
split_loop_L <- function(datasets = 50, n = 40, split_values, sigma = sigma, actual_beta){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (split in split_values) {
    ds_test_own_func_LASSO <- Model_testing_LASSO(datasets = datasets, cor = cor, n = n, x = split, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_LASSO <- as.data.frame(ds_test_own_func_LASSO)
    ds_test_own_func_LASSO <- ds_test_own_func_LASSO[is.finite(rowSums(ds_test_own_func_LASSO)),] # Remove possible NAs
    ds_test_own_func_LASSO = rbind(ds_test_own_func_LASSO, colMeans(ds_test_own_func_LASSO), apply(ds_test_own_func_LASSO, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_LASSO,paste(directory, "LASSO Test", "split", split,".csv"), row.names = TRUE)
  }
}

#split_loop_L(datasets = 50, n = 40, split_values, sigma = sigma, actual_beta)
  

n_values = c(40, 200, 500, 1000, 2000, 4000)
n_loop_L <- function(n_values, actual_beta, datasets = 50, x = x, sigma = sigma){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (n in n_values) {
    ds_test_own_func_LASSO <- Model_testing_LASSO(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_LASSO <- as.data.frame(ds_test_own_func_LASSO)
    ds_test_own_func_LASSO <- ds_test_own_func_LASSO[is.finite(rowSums(ds_test_own_func_LASSO)),] # Remove possible NAs
    ds_test_own_func_LASSO = rbind(ds_test_own_func_LASSO, colMeans(ds_test_own_func_LASSO), apply(ds_test_own_func_LASSO, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_LASSO,paste(directory, "LASSO Test", "n", n,".csv"), row.names = TRUE)
  }
}
#n_loop_L(n_values, actual_beta, x = x, datasets = 50, sigma = 3)


dataset_values = c(10, 50, 100, 200, 400)
dataset_loop_L <- function(dataset_values, actual_beta, x = x, n = 40, sigma = sigma){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (datasets in dataset_values) {
    ds_test_own_func_LASSO <- Model_testing_LASSO(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_LASSO <- as.data.frame(ds_test_own_func_LASSO)
    ds_test_own_func_LASSO <- ds_test_own_func_LASSO[is.finite(rowSums(ds_test_own_func_LASSO)),] # Remove possible NAs
    ds_test_own_func_LASSO = rbind(ds_test_own_func_LASSO, colMeans(ds_test_own_func_LASSO), apply(ds_test_own_func_LASSO, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_LASSO,paste(directory, "LASSO Test", "datasets", datasets,".csv"), row.names = TRUE)
  }
}
#dataset_loop_L(dataset_values, actual_beta, x = x, n = 40, sigma = sigma)

# Here we'll try different options for predictor variables
# We go from more sparse to less sparse. Amount of non-zero variables in this order: 2, 3, 4, 5, 7 | 6, 5, 4, 3, 2, 1
sparsity_betas = list(c(3,0,0, 0, 2, 0, 0, 0), c(3,1.5,0, 0, 2, 0, 0, 0), c(3,1.5,0, 0, 2, 0, 0, 2.5),
                      c(3,1.5,0, 0, 2, 0.8, 0, 2.5), c(3,1.5,0, 4, 2, 0.8, 0, 2.5),
                      c(3,1.5,0, 4, 2, 0.8, 3, 2.5))

betas_L <- function(datasets = 50, actual_betas = sparsity_betas, x = x, n = 40, sigma = sigma){
  iter = 0
  for (actual_beta in actual_betas) {
    iter = iter + 1
    cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
    rownames(cor) <- c(1:nrow(cor))
    colnames(cor) <- c(1:ncol(cor))
    #Calculate correlation values between each variable as per question
    for (i in 1:nrow(cor)){
      for (j in 1:ncol(cor)){
        cor[i,j] = 0.5^ abs(i-j)
      }
    }
    ds_test_own_func_LASSO <- Model_testing_LASSO(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_LASSO <- as.data.frame(ds_test_own_func_LASSO)
    ds_test_own_func_LASSO <- ds_test_own_func_LASSO[is.finite(rowSums(ds_test_own_func_LASSO)),] # Remove possible NAs
    ds_test_own_func_LASSO = rbind(ds_test_own_func_LASSO, colMeans(ds_test_own_func_LASSO, na.rm = TRUE), apply(ds_test_own_func_LASSO, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_LASSO,paste(directory, "LASSO Test", "sparsity", iter,".csv"), row.names = TRUE)
  }
}

remove(actual_beta)
#betas_L(datasets = 50, actual_betas = sparsity_betas, x = x, n = 40, sigma = sigma)

### Now we use the same function for the special case of p>n
# We create 3 different combinations of 20 betas
betas_pn = list()
for (i in 1:3) {
  betas_pn[[i]] = sample(0:9, 20, replace=T)
}

# Make sure the n and x entered here make up for a training size lower than p
# We have 15 observations in train and validation each because n*x = 30*0.5 = 15, and 20 predictors
#betas_L(datasets = 50, actual_betas = betas_pn, x = x, n = 30, sigma = sigma)

####### ELASTIC NET
actual_beta = c(3,1.5,0, 0, 2, 0, 0, 0)
lambdas2 = runif(40, min = 0, max = 4) # Define lambdas2 as well for subsequent functions

sigmas = c(0, 1, 2, 3, 4, 5, 6)
sigma_loop_EN <- function(sigmas, actual_beta, n = 40, x = 0.5, datasets = 50){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (sigma in sigmas) {
    ds_test_own_func_EN <- Model_testing_EN(datasets = datasets, cor = cor, n, sigma, actual_beta = actual_beta) 
    ds_test_own_func_EN <- as.data.frame(ds_test_own_func_EN)
    ds_test_own_func_EN <- ds_test_own_func_EN[is.finite(rowSums(ds_test_own_func_EN)),] # Remove possible NAs
    ds_test_own_func_EN = rbind(ds_test_own_func_EN, colMeans(ds_test_own_func_EN), apply(ds_test_own_func_EN, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_EN,paste(directory, "EN Testing", "sigma", sigma,".csv"), row.names = TRUE)
  }
}
#sigma_loop_EN(sigmas, actual_beta, n = 40, x = 0.5, datasets = 50)

sigma = 3
split_values = c(0.25, 0.5, 0.75, 0.9) # Small values of x give problems, too little entries for training. 0.25 is ok as lowest value
# x determines how much of a % of n goes to the train data, the remaining % goes to validation
# For test we have 10*validation
split_loop_EN <- function(datasets = 50, n = 40, split_values, sigma = sigma, actual_beta){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (split in split_values) {
    ds_test_own_func_EN <- Model_testing_EN(datasets = datasets, cor = cor, n = n, x = split, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_EN <- as.data.frame(ds_test_own_func_EN)
    ds_test_own_func_EN <- ds_test_own_func_EN[is.finite(rowSums(ds_test_own_func_EN)),] # Remove possible NAs
    ds_test_own_func_EN = rbind(ds_test_own_func_EN, colMeans(ds_test_own_func_EN), apply(ds_test_own_func_EN, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_EN[(nrow(ds_test_own_func_EN)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_EN[nrow(ds_test_own_func_EN),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_EN,paste(directory, "EN Test", "split", split,".csv"), row.names = TRUE)
  }
}

#split_loop_EN(datasets = 50, n = 40, split_values, sigma = sigma, actual_beta)

n_loop_EN <- function(n_values, sigma, actual_beta, x = 0.5, datasets = 50){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (n in n_values) {
    ds_test_own_func_EN <- Model_testing_EN(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_EN <- as.data.frame(ds_test_own_func_EN)
    ds_test_own_func_EN <- ds_test_own_func_EN[is.finite(rowSums(ds_test_own_func_EN)),] # Remove possible NAs
    ds_test_own_func_EN = rbind(ds_test_own_func_EN, colMeans(ds_test_own_func_EN), apply(ds_test_own_func_EN, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_EN,paste(directory, "EN Testing", "n", n,".csv"), row.names = TRUE)
  }
}
n_values = c(40, 200, 500, 1000, 2000, 4000) 
#n_loop_EN(n_values, sigma = 3, actual_beta, x = 0.5, datasets = 50)

dataset_loop_EN <- function(dataset_values, sigma = 3, actual_beta, n = 40, x = 0.5){
  cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
  rownames(cor) <- c(1:nrow(cor))
  colnames(cor) <- c(1:ncol(cor))
  #Calculate correlation values between each variable as per question
  for (i in 1:nrow(cor)){
    for (j in 1:ncol(cor)){
      cor[i,j] = 0.5^ abs(i-j)
    }
  }
  for (datasets in dataset_values) {
    ds_test_own_func_EN <- Model_testing_EN(datasets = datasets, cor = cor, x = x, n = n, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_EN <- as.data.frame(ds_test_own_func_EN)
    ds_test_own_func_EN <- ds_test_own_func_EN[is.finite(rowSums(ds_test_own_func_EN)),] # Remove possible NAs
    ds_test_own_func_EN = rbind(ds_test_own_func_EN, colMeans(ds_test_own_func_EN), apply(ds_test_own_func_EN, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_LASSO[(nrow(ds_test_own_func_LASSO)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_LASSO[nrow(ds_test_own_func_LASSO),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_EN,paste(directory, "EN Testing", "datasets", datasets,".csv"), row.names = TRUE)
  }
}
n = 40
x = 0.5
dataset_values = c(10, 50, 100, 200, 400)
#dataset_loop_EN(dataset_values, sigma = 3, actual_beta = actual_beta, n = 40, x = 0.5)

# Here we'll try different options for predictor variables
# We go from more sparse to less sparse. Amomount of non-zero variables in this order: 2, 3, 4, 5, 7
sparsity_betas = list(c(3,0,0, 0, 2, 0, 0, 0), c(3,1.5,0, 0, 2, 0, 0, 0), c(3,1.5,0, 0, 2, 0, 0, 2.5),
                      c(3,1.5,0, 0, 2, 0.8, 0, 2.5), c(3,1.5,0, 4, 2, 0.8, 0, 2.5),
                      c(3,1.5,0, 4, 2, 0.8, 3, 2.5))
betas_EN <- function(datasets = 50, actual_betas = sparsity_betas, x = x, n = 40, sigma = sigma){
  iter = 0
  for (actual_beta in actual_betas) {
    iter = iter + 1
    cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
    rownames(cor) <- c(1:nrow(cor))
    colnames(cor) <- c(1:ncol(cor))
    #Calculate correlation values between each variable as per question
    for (i in 1:nrow(cor)){
      for (j in 1:ncol(cor)){
        cor[i,j] = 0.5^ abs(i-j)
      }
    }
    ds_test_own_func_EN <- Model_testing_EN(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_EN <- as.data.frame(ds_test_own_func_EN)
    ds_test_own_func_EN <- ds_test_own_func_EN[is.finite(rowSums(ds_test_own_func_EN)),] # Remove possible NAs
    ds_test_own_func_EN = rbind(ds_test_own_func_EN, colMeans(ds_test_own_func_EN, na.rm = TRUE), apply(ds_test_own_func_EN, 2, sd, na.rm = TRUE))
    write.csv(ds_test_own_func_EN,paste(directory, "EN Test", "sparsity p>n", iter,".csv"), row.names = TRUE)
  }
}
lambdas2
remove(actual_beta)
betas_EN(datasets = 50, actual_betas = sparsity_betas, x = x, n = 40, sigma = sigma)

### Now we use the same function for the special case of p>n
# We create 3 different combinations of 20 betas
betas_pn = list()
for (i in 1:3) {
  betas_pn[[i]] = sample(0:9, 20, replace=T)
}

# Make sure the n and x entered here make up for a training size lower than p
# We have 15 observations in train and validation each because n*x = 30*0.5 = 15, and 20 predictors
#betas_EN(datasets = 50, actual_betas = betas_pn, x = x, n = 30, sigma = sigma)

################## Worth adding comparison to Ridge at the end if possible ########################################## 
### We see that LASSO is unable to do this regression and has a massive error
### The Elastic Net can but the error is substantial
### We'll try Ridge Regression to see how the result compares to EN

Ridge_errors <- function(lambdas1, Y_train, train, Y_validation, validation, actual_beta = actual_beta){
  container = matrix(0, length(lambdas1), 2)
  for (lambda1 in lambdas1){
    betas = coord_descent(Y_train, train, lambda1 = 0, lambda2 = lambda1, actual_beta = actual_beta)
    error = MSE(validation %*% betas, Y_validation)
    container[which(lambdas1 == lambda1), 1] = lambda1
    container[which(lambdas1 == lambda1), 2] = error
  }
  min_error = min(container[,2], na.rm = TRUE)
  best_lambda = container[which.min(container[,2]),1]
  best_betas = coord_descent(Y_train, train, lambda1 = best_lambda, lambda2 = 0, actual_beta = actual_beta)
  #cat("results", best_lambda, min_error, best_betas)
  return(list(best_lambda, min_error, best_betas, container))
}

Model_testing_Ridge <- function(datasets = 50, cor = cor, n = 20, x = x, sigma = sigma, actual_beta = actual_beta){
  dataset_errors_lambda= matrix(rep(0, datasets)*5, nrow = datasets, ncol = 5) # We'll store the error and the 2 lambdas here
  for (d in 1:datasets){
    data_creation(cor, n, x, sigma, actual_beta = actual_beta)
    validation_results <- Ridge_errors(lambdas1, Y_train, train, Y_validation, validation, actual_beta = actual_beta)
    dataset_errors_lambda[d,1] = validation_results[[1]] # Best lambda
    dataset_errors_lambda[d,2] = validation_results[[2]] # Validation Error for Best Lambda
    best_betas <- coord_descent(Y_train, train, lambda1 = 0, lambda2 = validation_results[[1]], actual_beta = actual_beta)
    dataset_errors_lambda[d,3] =  MSE(test %*% best_betas, Y_test) # Test Error with given lambda and betas
    dataset_errors_lambda[d,4] =  sum(best_betas != 0)
    dataset_errors_lambda[d,5] =  mean(best_betas[which(best_betas != 0)])
  }
  colnames(dataset_errors_lambda) = c("best_lambda", "Validation MSE", "Test MSE", "No. of non-zero betas", "Avg. of non-zero betas")
  return(dataset_errors_lambda)
}

betas_R <- function(datasets = 50, actual_betas = sparsity_betas, x = x, n = 40, sigma = sigma){
  iter = 0
  for (actual_beta in actual_betas) {
    iter = iter + 1
    cor <- matrix(nrow = length(actual_beta), ncol = length(actual_beta))
    rownames(cor) <- c(1:nrow(cor))
    colnames(cor) <- c(1:ncol(cor))
    #Calculate correlation values between each variable as per question
    for (i in 1:nrow(cor)){
      for (j in 1:ncol(cor)){
        cor[i,j] = 0.5^ abs(i-j)
      }
    }
    ds_test_own_func_Ridge <- Model_testing_Ridge(datasets = datasets, cor = cor, n = n, x = x, sigma = sigma, actual_beta = actual_beta) 
    ds_test_own_func_Ridge <- as.data.frame(ds_test_own_func_Ridge)
    ds_test_own_func_Ridge <- ds_test_own_func_Ridge[is.finite(rowSums(ds_test_own_func_Ridge)),] # Remove possible NAs
    ds_test_own_func_Ridge = rbind(ds_test_own_func_Ridge, colMeans(ds_test_own_func_Ridge, na.rm = TRUE), apply(ds_test_own_func_Ridge, 2, sd, na.rm = TRUE))
    #row.names(ds_test_own_func_Ridge[(nrow(ds_test_own_func_Ridge)-1),]) <- c("Mean") # Index has to be dataset amount +1, +2, respectively
    #row.names(ds_test_own_func_Ridge[nrow(ds_test_own_func_Ridge),]) <- c("Standard Dev.") # Index has to be dataset amount +1, +2, respectively
    write.csv(ds_test_own_func_Ridge,paste(directory, "Ridge Test", "sparsity p>n", iter,".csv"), row.names = TRUE)
  }
}

#betas_R(datasets = 50, actual_betas = betas_pn, x = x, n = 30, sigma = sigma)
