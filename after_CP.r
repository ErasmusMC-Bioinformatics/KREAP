library(ggplot2)
library(reshape2)

args <- commandArgs(trailingOnly = TRUE)

inputfile = "D:/wd/wur/WellG07.cpout"
inputfile = args[1]
plot_file_names = unlist(strsplit(args[2], ","))
outputdir = args[3]

setwd(outputdir)

inputdata = read.table(inputfile, sep="\t", header=TRUE, fill=T, comment.char="")

cpout = inputdata[inputdata$ImageNumber == 1,]

# ---------------------- find biggest gap in first image ----------------------

y_freq = data.frame(table(cpout$AreaShape_Center_Y))
names(y_freq) = c("y", "freq")
y_freq$y = as.numeric(as.character(y_freq$y))
y_freq$freq = as.numeric(y_freq$freq)

biggest_gap_size = 0
biggest_gap_start = 0
biggest_gap_start_index = 0
biggest_gap_end = 0
biggest_gap_end_index = 0

#print(y_freq)

for(i in 1:(nrow(y_freq)-1)){
  gap_size = y_freq[i+1,]$y - y_freq[i,"y"]
  if(gap_size > biggest_gap_size){
    biggest_gap_size = gap_size
    biggest_gap_start = y_freq[i,"y"]
    biggest_gap_start_index = i
    
    biggest_gap_end_index = i+1
    biggest_gap_end = y_freq[i,"y"]
  }
}

#search up/down through the image for smaller gaps
while((y_freq[biggest_gap_start_index,"y"] - y_freq[biggest_gap_start_index-1, "y"]) > 1){
  biggest_gap_start_index = biggest_gap_start_index - 1
}
biggest_gap_start = y_freq[biggest_gap_start_index,"y"]


while(y_freq[biggest_gap_end_index + 1,"y"] - y_freq[biggest_gap_end_index,"y"] > 1){
  biggest_gap_end_index = biggest_gap_end_index + 1
}
biggest_gap_end = y_freq[biggest_gap_end_index,"y"]


# ---------- for every image, find how many are inside the gap, plot them ----------

image_numbers = unique(inputdata$ImageNumber)
number_of_images = length(image_numbers)
result = data.frame(image=1:number_of_images, inside=1:number_of_images, outside=1:number_of_images, total=1:number_of_images)
for(i in image_numbers){
  name = paste("Image_", i, ".cpout", sep="")
  cpout = inputdata[inputdata$ImageNumber == i,]
  inside_rows = cpout$AreaShape_Center_Y >= biggest_gap_start & cpout$AreaShape_Center_Y <= biggest_gap_end
  inside = sum(inside_rows)
  result[i,"inside"] = inside
  total = nrow(cpout)
  result[i,"total"] = total
  outside = total - inside
  result[i,"outside"] = outside
  
  cpout$col = factor(ifelse(cpout$AreaShape_Center_Y >= biggest_gap_start & cpout$AreaShape_Center_Y <= biggest_gap_end, paste("inside -", inside), paste("outside -", outside)))
  
  p = ggplot(cpout, aes(AreaShape_Center_X, AreaShape_Center_Y))
  p = p + geom_point(aes(colour = col)) #+ scale_colour_manual(values=c("red", "blue"))
  p = p + geom_rect(xmin = 0, xmax = Inf,   ymin = biggest_gap_start, ymax = biggest_gap_end,   fill = "red", alpha = 0.0002)
  p = p + ggtitle(paste("Nuclei_", plot_file_names[i], " - " , total, sep=""))

  

  png(paste("Nuclei_", plot_file_names[i], ".png", sep=""))
  print(p)
  dev.off()
	cpout$col = gsub(" - .*", "", cpout$col)
	write.table(cpout[,c("AreaShape_Center_X", "AreaShape_Center_Y", "col")], paste("Nuclei_", plot_file_names[i], ".txt", sep=""), sep="\t", row.names=F, col.names=T, quote=F)
}

test = melt(result, id.vars=c("image"))
png("bar.png")
ggplot(test, aes(x=image, y = value, fill=variable, colour=variable)) + geom_bar(stat='identity', position='dodge' )
dev.off()
png("line.png")
ggplot(test, aes(x=image, y = value, fill=variable, colour=variable)) + geom_line()
dev.off()

write.table(result, "numbers.txt", sep="\t", row.names=F, col.names=T, quote=F)
write.table(result, "numbers_no_header.txt", sep="\t", row.names=F, col.names=F, quote=F)

growth = data.frame(image=result$image[2:nrow(result)], inside_growth=diff(result$inside), outside_growth=diff(result$outside), total_growth=diff(result$total))

write.table(growth, "growth.txt", sep="\t", row.names=F, col.names=T, quote=F)

summ <- do.call(data.frame, 
               list(mean = apply(growth, 2, mean),
                    sd = apply(growth, 2, sd),
                    median = apply(growth, 2, median),
                    min = apply(growth, 2, min),
                    max = apply(growth, 2, max),
                    n = apply(growth, 2, length)))

summ_numeric_colls = sapply(summ, is.numeric)
summ[,summ_numeric_colls] = round(summ[,summ_numeric_colls], 2)
write.table(summ, "summary.txt", sep="\t", row.names=T, col.names=NA, quote=F)

# ---------- for follow up analysis ----------

result=result[,c("total", "inside")]
result$perc = round((result$inside / result$total) * 100, 2)

write.table(result, "in_out_perc.txt", sep="\t", row.names=F, col.names=F)


# ---------- csv for d3.js? ----------

write.table(inputdata[,c("ImageNumber", "ObjectNumber", "AreaShape_Center_X", "AreaShape_Center_Y")], file="objects.csv", quote=F, sep=",", row.names=F, col.names=T)





