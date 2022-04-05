
JPavel <- JPx %>% ungroup() %>% select(medchr,pos,marker)

lgfile <- JPavel
lgfile$Fpass <- "PASS"
args <- c(0, 10, 10)
QC_df <- lgfile %>% filter(Fpass == "raccoon")

for(i in 1:24){
  lgfile <- JPavel %>% filter(medchr == i)
  lgfile <- arrange(lgfile, 2)
  lgfile$Fpass <- "PASS"
  
  ##### Pruning the ends #####
  # if the percent threshold is given as an interger, convert it to a decimal
  dist_thresh <- as.numeric(args[2])
  if(dist_thresh >= 1){
    dist_thresh <- dist_thresh * .01
  }
  dist_thresh_f <- abs(max(lgfile$pos) - min(lgfile$pos)) * dist_thresh
  
  edge_length <- as.numeric(args[3])
  if(edge_length >= 1){
    edge_length <- edge_length * .01
  }
  
  n_markers <- length(lgfile$pos)
  front_edge <- round(n_markers * edge_length, digits = 0)
  back_edge <- round(n_markers - front_edge, digits = 0)
  
  dist_thresh <- dist_thresh_f
  # trim beginning
  for(a in front_edge:2){ #first n% of total markers from the beginning
    diff <- abs(lgfile[a,2]-lgfile[a-1,2]) # difference between two points
    if( diff > dist_thresh ){ # is the difference between the two points > distance argument?
      lgfile[(a-1):1, 4] <- "FAIL" # mark that marker and all markers BEFORE it as FAIL
      break()
    }
  }
  # trim end
  for(z in back_edge:(n_markers-1)){ #last n% total markers starting from the back edge going out
    diff <- abs(lgfile[z+1,2]-lgfile[z,2]) # difference between two points
    if( diff > dist_thresh ){ # is the difference between the two points > distance argument?
      lgfile[(z+1):n_markers,4] <- "FAIL" # mark that marker and all markers AFTER it as FAIL
      break()
    }
  }
  QC_df <- rbind(QC_df, lgfile)
}

# create new table of markers passing QC
cleaned_markers <- QC_df %>% filter(Fpass == "PASS")

# isolate bad markers
removed_markers <- QC_df %>% filter(Fpass == "FAIL")

# get simple counts
rm_female <- table(QC_df %>% filter(Fpass == "FAIL") %>% select(medchr))

rm_female

ggplot(data=QC_df)+
  geom_point(aes(x=marker, y=pos, color=Fpass)) +
  scale_color_manual(values=c("indianred2", "dodgerblue")) +
  theme(legend.position = "top") +
  labs(x = "Marker Number", y = "Position (cM)", color = "QA Status")+
  facet_wrap(~medchr, scales="free", ncol=4)
