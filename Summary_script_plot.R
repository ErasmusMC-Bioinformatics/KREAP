library(ggplot2)

setwd("D:/PhD/BD Pathway/Wounding Assays/2015/OH13F15_Live bacteria screening 1/FCS Express_5 hours")
data <- read.csv("FCS Express_5 hours.csv", header=1)

## select parameters at single timepoint
data <- data[data$Time == 0,]

## remove row that contain NA
##data <- na.omit(data)

##remove treatments
## data <- data[!data$Treatment == "hTGF, 6", ]
## data <- data[!data$Treatment == "hTFG_inhibitors", ]

## do pairwise ttsst
Mu_m <- pairwise.t.test(data$Mu_m, data$Treatment, p.adjust.method ="none")
A <- pairwise.t.test(data$A, data$Treatment, p.adjust.method ="none")
Lambda <- pairwise.t.test(data$Lambda, data$Treatment, p.adjust.method ="none")


## write pairwise ttest to file
pwtt_Mu_m <- data.frame(Mu_m[["p.value"]])
write.csv(file="pairwise_t-test_Mu_m.csv", pwtt_Mu_m, row.names=T)

pwtt_A <- data.frame(A[["p.value"]])
write.csv(file="pairwise_t-test_A.csv", pwtt_A, row.names=T)

pwtt_Lambda <- data.frame(Lambda[["p.value"]])
write.csv(file="pairwise_t-test_Lambda.csv", pwtt_Lambda, row.names=T)


## signifance stars
A_df <- pwtt_A[1]
A_df$Treatment <- row.names(A_df)
colnames(A_df) <- c("Pval", "Treatment")
row.names(A_df) <- NULL
data_A <- merge(data, A_df, by="Treatment", all.x = T)

data_A$star <- ""
data_A$star[data_A$Pval <= .05]  <- "*"
data_A$star[data_A$Pval <= .01]  <- "**"
data_A$star[data_A$Pval <= .001]  <- "***"


## signifance stars
Mu_m_df <- pwtt_Mu_m[1]
Mu_m_df$Treatment <- row.names(Mu_m_df)
colnames(Mu_m_df) <- c("Pval", "Treatment")
row.names(Mu_m_df) <- NULL
data_Mu_m <- merge(data, Mu_m_df, by="Treatment", all.x = T)

data_Mu_m$star <- ""
data_Mu_m$star[data_Mu_m$Pval <= .05]  <- "*"
data_Mu_m$star[data_Mu_m$Pval <= .01]  <- "**"
data_Mu_m$star[data_Mu_m$Pval <= .001]  <- "***"


## signifance stars
Lambda_df <- pwtt_Lambda[1]
Lambda_df$Treatment <- row.names(Lambda_df)
colnames(Lambda_df) <- c("Pval", "Treatment")
row.names(Lambda_df) <- NULL
data_Lambda <- merge(data, Lambda_df, by="Treatment", all.x = T)

data_Lambda$star <- ""
data_Lambda$star[data_Lambda$Pval <= .05]  <- "*"
data_Lambda$star[data_Lambda$Pval <= .01]  <- "**"
data_Lambda$star[data_Lambda$Pval <= .001]  <- "***"

star_A <- data_A[!duplicated(data_A$Treatment),]
star_Mu_m <- data_Mu_m[!duplicated(data_Mu_m$Treatment),]
star_Lambda <- data_Lambda[!duplicated(data_Lambda$Treatment),]


## find position of significance stars
treatments <- unique(data$Treatment)
nmbr_of_treatments <- as.numeric(length(treatments))
treatments <- data.frame(treatments)

run <- 0
for(i in  1:nmbr_of_treatments){
  run <- run + 1
  Treatment <- as.character(treatments[run,1])
  star_lambda <- data_Lambda[data_Lambda$Treatment == Treatment,]
  star_Mu_m <- data_Mu_m[data_Mu_m$Treatment == Treatment,]
  star_A <- data_A[data_A$Treatment == Treatment,]
  
  star_Lambda_loc <- max(star_lambda$Lambda)
  star_Mu_m_loc <- max(star_Mu_m$Mu_m)
  star_A_loc <- max(star_A$A)
  
  star_Lambda <- max(star_lambda$star)
  star_Mu_m <- max(star_Mu_m$star)
  star_A <- max(star_A$star)
  
  df_Lambda <- data.frame(Treatment, star_Lambda_loc, star_Lambda)
  df_Mu_m <- data.frame(Treatment, star_Mu_m_loc, star_Mu_m)
  df_A <- data.frame(Treatment, star_A_loc, star_A)
  
  if(run == 1){
    stars_Lambda_df <- df_Lambda
    stars_Mu_m_df <- df_Mu_m
    stars_A_df <- df_A
  } else {
    stars_Lambda_df <- rbind(stars_Lambda_df, df_Lambda)
    stars_Mu_m_df <- rbind(stars_Mu_m_df, df_Mu_m)
    stars_A_df <- rbind(stars_A_df, df_A)
  } 
}



## make plots


## plot A
png(filename = "Maximun_number_of_cells.png", width = 300 + 300*nmbr_of_treatments, height = 3000, res=600)
q <- qplot(Treatment, A, data=data_A,geom="boxplot")
q <- q + theme(axis.text.x=element_text(angle = 90, vjust = 0.5, hjust = 1))
q <- q + theme_bw()
q <- q + xlab("Treatment") + theme(axis.title.x = element_text(size=14))
q <- q + ylab('A [cells]') + theme(axis.title.y = element_text(size=14))
q <- q + ggtitle("Maximum number of cells") + theme(plot.title = element_text(lineheight=.8, size=14, face="bold"))

q <- q + geom_text(aes(label=star_A, y=star_A_loc+50, ymax=star_A_loc), 
                   colour="red", 
                   position = position_dodge(0.9), na.rm=TRUE,
                   data = stars_A_df,
                   vjust = 0.5, 
                   hjust = 0.5)

q <- q + theme(axis.text.x = element_text(angle = 45, vjust= 1, hjust = 1))
q <- q + theme(axis.text=element_text(size=11))
q <- q + theme(axis.title=element_text(size=11))
q
dev.off()

## plot Mu_m
png(filename = "Repair_rate.png", width = 300 + 300*nmbr_of_treatments, height = 3000, res=600)
q <- qplot(Treatment,Mu_m,data=data,geom="boxplot")
q <- q + theme(axis.text.x=element_text(angle = 90, vjust = 0.5, hjust = 1))
q <- q + theme_bw()
q <- q + xlab("Treatment") + theme(axis.title.x = element_text(size=14))
q <- q + ylab(expression(paste(mu[m],' [cells / minute]'))) + theme(axis.title.y = element_text(size=14))
q <- q + ggtitle("Repair rate") + theme(plot.title = element_text(lineheight=.8, size=14, face="bold"))

q <- q + geom_text(aes(label=star_Mu_m, y=star_Mu_m_loc+0.3, ymax=star_Mu_m_loc), 
                   colour="red", 
                   position = position_dodge(0.9), na.rm=TRUE,
                   data = stars_Mu_m_df,
                   vjust = 0.5, 
                   hjust = 0.5)

q <- q + theme(axis.text.x = element_text(angle = 45, vjust= 1, hjust = 1))
q <- q + theme(axis.text=element_text(size=11))
q <- q + theme(axis.title=element_text(size=11))
q
dev.off()

## plot Lambda
png(filename = "Lag_time.png", width = 300 + 300*nmbr_of_treatments, height = 3000, res=600)
q <- qplot(Treatment, Lambda,data=data_Lambda,geom="boxplot")
q <- q + theme(axis.text.x=element_text(angle = 90, vjust = 0.5, hjust = 1))
q <- q + theme_bw()
q <- q + xlab("Treatment") + theme(axis.title.x = element_text(size=14))
q <- q + ylab('L [minutes]') + theme(axis.title.y = element_text(size=14))
q <- q + ylab(expression(paste(lambda,' [minutes]')))+ theme(axis.title.y = element_text(face="bold"))
q <- q + ggtitle("Lag time") + theme(plot.title = element_text(lineheight=.8, size=14, face="bold"))

q <- q + geom_text(aes(label=star_Lambda, y=star_Lambda_loc+3, ymax=star_Lambda_loc), 
                   colour="red", 
                   position = position_dodge(0.9), na.rm=TRUE,
                   data = stars_Lambda_df,
                   vjust = 0.5, 
                   hjust = 0.5)

q <- q + theme(axis.text.x = element_text(angle = 45, vjust= 1, hjust = 1))
q <- q + theme(axis.text=element_text(size=11))
q <- q + theme(axis.title=element_text(size=11))
q
dev.off()

## write stuff to file
write.csv(file="Significance_Mu_m.csv", data_Mu_m, row.names=T)
write.csv(file="Significance_A.csv", data_A, row.names=T)
write.csv(file="Significance_Lambda.csv", data_Lambda, row.names=T)