#! /usr/bin/env Rscript

suppressMessages(library(tidyverse))
suppressMessages(library(na.tools))
suppressMessages(library(rsq))

setwd(getwd())

source("brec_functions.r")

RALL <- suppressMessages(read_delim("input/newflip_RR.txt", delim = " ") %>% arrange(set,map,phys))

sets <- unique(RALL$set)

recomb_df <- data.frame(
  set = character(),
  map = numeric(),
  mb = numeric(),
  cm = numeric(),
  regFn = numeric(),
  regDr = numeric(),
  stringsAsFactors=TRUE
)

chromatin_df <- data.frame(
  set = character(),
  map = numeric(),
  heteroBoundLeft = numeric(),
  indexHBleft = numeric(),
  heteroBoundRight = numeric(),
  indexHBright = numeric(),
  swSize = numeric(),
  stringsAsFactors=TRUE
)

telomere_df <- data.frame(
  set = character(),
  map = numeric(),
  index_minR2_left = numeric(), 
  telo_left = numeric(), 
  index_minR2_right = numeric(),
  telo_right = numeric(),
  stringsAsFactors=TRUE
)
 

  
#### loop recomb over all maps ####
for(.set in sets){
  # pull out the set
  current_set <- RALL %>% filter(set==.set) %>% rename(mb=phys,cm=gen)
  # get unique map names
  chromosomes <- sort(unique(current_set$map))
  # iterate over maps (chromosomes)
  for(.chrom in chromosomes){
    cat(paste0("Set: ", .set, " Chromosome: ", .chrom, "\n"))
    # pull out the chromosome
    chrom_subset <- current_set %>% filter(map == .chrom) %>% select(mb,cm)
    # get recomb rates
    .out <- estimate_recombination_rates(chrom_subset)
    # merge results with physical and genetic position
    .out_merge <- bind_cols(chrom_subset, .out)
    # add set info column
    .out_merge$set <- .set
    # add map info column
    .out_merge$map <- .chrom
    # reorder .out to be more human-readable and match the recomb_df output
    recomb_df <- rbind(recomb_df, .out_merge[,c(5,6,1,2,3,4)])
    # create R2DF object
    r_sq <- compute_cumulated_R_squared_2directions(chrom_subset)
    # chromatin boundaries
    cat("  Chrom bounds  ")
    cat("   ... done!\n")
    .chrom_bounds <- extract_CB(chrom_subset, .out, r_sq)
    .chrom_bounds$set <- .set
    .chrom_bounds$map <- .chrom
    # populate chromatin bounds result dataframe
    chromatin_df <- rbind(chromatin_df, .chrom_bounds[, c(6,7,1,2,3,4,5)])
    # telomere bounds
    cat("  Telomere bounds ")
    .telomeres <- extract_telomeres_boundaries(chrom_subset, .out, r_sq)
    .telomeres$set <- .set
    .telomeres$map <- .chrom
    telomere_df <- rbind(telomere_df, .telomeres[,c(5,6,1,2,3,4)])
    cat(" ... done!\n")
  }
}

write.table(recomb_df, file = "recomb_df.txt", row.names =FALSE, quote = FALSE)
write.table(chromatin_df, file = "centromere_df.txt", row.names =FALSE, quote = FALSE)
write.table(telomere_df, file = "telomere_df.txt", row.names =FALSE, quote = FALSE)
#save.image()
