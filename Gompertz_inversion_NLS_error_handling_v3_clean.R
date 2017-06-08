#
# This script calculates the best fit of the gompertz equation through all
# individual wells for all treatments within an experiment using the Gompertz equation. 
# User should set the working_directory where the Experiment folder is located 
# and give the name of the experiment folder. In addition, the time interval
# (in minutes) between the measurements should be defined by the user.
# If the model cannot be fitted properly through a well, the parameter estimates 
# will be filled up with NA's
#
# the script outputs two dataframes in the Experiment folder, containing:
# 1 Best fit of the parameters: Mu_m,	Lambda,	A and their standard erros, the RMSE and	R2	
# 2 Measured vs modeld number of cells: Time,	Measured,	Modelled
#
# In addition, plots of the Measured vs modeld number of cells and statistics will be created
#

## load grofit and hydroGOF library
library(hydroGOF)
library(minpack.lm)
library(tools)

## create Gompertz equation
gompertz_eq <- function(A, mu, lambda) {
  fun <- (A*(exp(-exp((mu*exp(1)/A)*(lambda-time_points)+1))))
  return(fun)
}

### set some variables 
working_directory              <- "D:/PhD/BD Pathway/Wounding Assays/2016/OH15F16_Commensal MOI 500"
Experiment                     <- "FCS Express"
time_interval                  <- 20

args = commandArgs(trailingOnly = TRUE)

working_directory = args[1]
Experiment = "blah"
time_interval = as.numeric(args[2])

## set working directory
setwd(working_directory)

## suppress warning messages
#options(warn=-1)


### Main script ###

## list treatment folders in working directory
treatments <- dir()[file.info(dir())$isdir]
# treatments <- treatments[complete.cases(treatments),] ## remove NA's if they for some reason appear

## create empty dataframes to later store outputs
parameters_df <- NULL
simulations_df <- NULL
errors <- data.frame("Unable to retreive Gompertz parameters for:")
names(errors) <- "error"

## loop through treatments folders
for (treatment in treatments){
  
  ## set WD
  setwd(sprintf("%s/%s", working_directory, treatment))
  
  ## list text files (wells)
  wells <- file.info(list.files(pattern="*.txt"))
  wells <- row.names(wells)
  
  ## create empty dataframe
  outfile <- NULL
  
  ## read data
  for (well in wells) {
    
    # read data
    data <- read.table(well, skip=0)
    
    # select the column with the number of cells
    data <- data[, 2]
    
    ## normalize (t=0 --> 0 cells)
    data <- data - data[1]
    
    ## add all data columns to one table  
    outfile <- cbind(outfile, data)     
  }
  
  ## add column names
  colnames(outfile) <- wells
  outfile <- data.frame(outfile)
  
  ## get number of time points
  time_points <- as.numeric(nrow(outfile))
  time_points <- (c(1:time_points)*time_interval)-time_interval
  
  ## loop though wells and fit the Gompertz model
  for (well in wells){
    
    r.name.well = make.names(well)
    ## Get measured number of cells
    cells <- outfile[r.name.well]
    
    ## first estimate of parameters
    A <- max(cells)
    mu <- 1
    lambda <- 1
    
    ## create trainig dataset
    train_data <- data.frame(time_points, cells)
    colnames(train_data) <- c("time", "cells")
    
    ## try to fit the Gompertz model. If it feals fill it up with NA's
    out <- tryCatch({
      
      ## do NLS inversion
      fit <- nlsLM(cells~A*(exp(-exp((mu*exp(1)/A)*(lambda-time)+1))),
                   data=train_data,
                   start=list(A=A, mu=mu, lambda=lambda),
#                    upper=c(2000,   15,  Inf),
#                    lower=c(0, 0, -20),
                   trace = F)
    } , error=function(err) NA)
    
    ## fill row with NA NLS if fitting fails
    if(is.na(out)){
      
      ## fill parameters_stats ith NA's
      parameters_stats <- data.frame(treatment,file_path_sans_ext(well),NA,NA,NA,NA,NA,NA,NA,NA)
      colnames(parameters_stats) <- c("Treatment", "Well", "Mu_m", "StdErr_Mu_m", "Lambda", "StdErr_Lambda", "A", "StdErr_A", "RMSE", "R2")
      
      ## fill meas_mod ith NA's
      meas_mod <- data.frame(treatment,file_path_sans_ext(well),NA,NA,NA)
      colnames(meas_mod) <- c("Treatment", "Well", "Time", "Measured", "Modelled")
      
      ## create error message
      error_message <- data.frame(sprintf("Well %s of treatment %s", file_path_sans_ext(well), treatment))
      names(error_message) <- "error"
      errors <- rbind(errors, error_message)
      
      ## plot data points only
      png(sprintf("%s/%s/Infiltrating cells %s.png", working_directory, treatment, file_path_sans_ext(well)))
      plot(cells~time, train_data, xlab="Time [Minutes]", ylab="Cells",
           main=sprintf("%s \n%s", treatment, file_path_sans_ext(well)))
      dev.off()
      
    } else {
      
      ## get NLS inversion parameters
      parameters <- summary(out)
      parameters <- parameters$parameters
      
      ## get individual parameters
      A <- parameters[1]
      mu <- parameters[2]
      lambda <- parameters[3]
      
      ## get individual parameters erros
      A_err <- parameters[1,2]
      mu_err <- parameters[2,2]
      lambda_err <- parameters[3,2]
      
      ## simulate Gompertz based on NLS inversion
      sim <- gompertz_eq(A, mu, lambda)
      nls_data <- data.frame(time_points, sim)
      colnames(nls_data) <- c("time", "cells")
      
      ## calculate RMSE and R2
      rmse <- rmse(train_data$cells, nls_data$cells)
      r2 <- summary(lm(train_data$cells~nls_data$cells))$r.squared
      
      ## create plot of fit
      png(sprintf("%s/%s/Infiltrating cells %s.png", working_directory, treatment, file_path_sans_ext(well)))
      plot(cells~time, train_data, xlab="Time [Minutes]", ylab="Cells",
           main=sprintf("%s \n%s", treatment, file_path_sans_ext(well)))
      text(0,max(cells), labels=c(sprintf("\nRMSE = %s \nr2 = %s", round(rmse, 2), round(r2, 3) )), adj=0)
      text(max(time_points),0, labels=c(sprintf("A = %s±%s \nlambda = %s±%s \nmu = %s±%s \n \n \n", 
                                                round(A, 0), round(A_err, 0), 
                                                round(lambda, 2), round(lambda_err, 2), 
                                                round(mu, 2), round(mu_err, 2) )), adj=1)
      points(nls_data, type="l")
      dev.off()
      
      ## add all fitting statistics to a data frame
      parameters_stats <- data.frame(treatment, file_path_sans_ext(well), mu, mu_err, lambda, lambda_err, A, A_err, rmse, r2)
      colnames(parameters_stats) <- c("Treatment", "Well", "Mu_m", "StdErr_Mu_m", "Lambda", "StdErr_Lambda", "A", "StdErr_A", "RMSE", "R2")
      
      ## add all simulations to a data frame
      meas_mod <- data.frame(treatment, file_path_sans_ext(well), time_points, cells, sim)
      colnames(meas_mod) <- c("Treatment", "Well", "Time", "Measured", "Modelled")
    }
    
    ## add to file
    parameters_df <- rbind(parameters_df, parameters_stats)
    simulations_df <- rbind(simulations_df, meas_mod)
  }
}
setwd(working_directory)

write.table(file="simulations.txt", simulations_df, row.names=F, sep="\t", quote=F)
write.table(file="parameters.txt", parameters_df, row.names=F, sep="\t", quote=F)

## write to CSV-file
#write.csv(file=sprintf('%s/%s/%s_simulations.csv', working_directory, Experiment, Experiment), simulations_df, row.names=F)
#write.csv(file=sprintf('%s/%s/%s_parameters.csv', working_directory, Experiment, Experiment), parameters_df, row.names=F)




### Report ###

## turn warning messages back on
options(warn=0)

## show wells where the Gompertz model did not fit
if(nrow(errors) > 1){
  for(msg in 1:nrow(errors)){
    print(as.character(errors[msg,]))
  }
} else {
  print("All Gompertz parameters were succesfully retreived!")
}
