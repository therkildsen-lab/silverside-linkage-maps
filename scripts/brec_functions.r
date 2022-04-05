#### get_chrome_type ####
# this function applyes a test based on min(RR) to determine if a chromosome is telocentric (a chromosomal arm) or metacentric (a whole chromosome)
get_chromosome_type <- function(chromosome){
  # ======================================================
  ## the used will provide this infomation on the gui 
  # chr_type = 0 # arm
  # chr_type = 1 # whole chr
  # chr_type = 2 # don't know
  # ======================================================
  
  RR_object = estimate_recombination_rates(chromosome)
  minRRloess = min(RR_object$regDr)
  indexOfMinRRloess = match(minRRloess, RR_object$regDr)
  physPos_minRRloess = chromosome$mb[indexOfMinRRloess]
  #print(data.frame(physPos_minRRloess, minRRloess, indexOfMinRRloess))
  
  # minRRpoly --------------------------------------------------------------------
  RR_poly <- estimate_recombination_rates_third_degree_polynomial(chromosome)
  minRRpoly = min(RR_poly$regDr)
  indexOfMinRRpoly = match(minRRpoly, RR_poly$regDr)
  #minRRpoly = minRR_object$minRRpoly
  #indexOfMinRRpoly = minRR_object$indexOfMinRRpoly
  physPos_minRRpoly = chromosome$mb[indexOfMinRRpoly]
  # print(data.frame(chrID, physPos_minRRpoly,  minRRpoly, indexOfMinRRpoly)) # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  
  chrSize = chromosome$mb[nrow(chromosome)]
  pcg_df = data.frame(pcg40 =0.4*chrSize ,pcg60 =0.6*chrSize)
  # print(pcg_df)
  # print(data.frame(chrID, chrSize, physPos_minRRloess, physPos_minRRpoly))
  # chr_type = 0 # arm
  # chr_type = 1 # whole chr
  chr_type = 2 # don't know
  chr_sub_type = "Don't know!"
  if(physPos_minRRloess == chromosome$mb[1] | physPos_minRRloess == chrSize){
    if(physPos_minRRpoly == physPos_minRRloess){
      chr_type = 0  # arm
      chr_sub_type = "Telocentric"
    }
    else{
      #chr_type = 2
      # chr_sub_type = "Don't know"
      #print("Warning !! User decision might be required...")
    }
  }else{ # minRRloess is inside chr => whole (confirmed)
    if(physPos_minRRloess >= pcg_df$pcg40 & physPos_minRRloess <= pcg_df$pcg60){ # case 1 : metacentric
      chr_type = 1 # whole chr
      chr_sub_type = "Atelocentric - metacentric"
      # }else if((indexOfMinRRloess >= pcg_df$pcg90 | indexOfMinRRloess <= pcg_df$pcg10)){ # case 3 : acrocentric
      #     chr_sub_type = "acrocentric"
    }else{  # if(physPos_minRRloess >= pcg_df$pcg10 & physPos_minRRloess < pcg_df$pcg45) | (physPos_minRRloess >= pcg_df$pcg55 & physPos_minRRloess < pcg_df$pcg90)  # case  : submetacentric
      # chr_sub_type = "Atelocentric - not metacentric" #submetacentric
      chr_type = 2 # don't know
      chr_sub_type = "Don't know!"
    }
    
  }
  return(chr_type)
  #chrType_object = data.frame(chr_type, chr_sub_type)
  #print(chrType_object)
  #return(chrType_object)
}

#### recomb polynomial ####
estimate_recombination_rates_third_degree_polynomial <- function(chromosome){
  
  MB = chromosome$mb #physicalMap
  cM = chromosome$cm #geneticMap
  MB = as.numeric(MB)
  
  # regression function = 3rd degree polynomial
  model = glm(cM ~ poly(MB, 3, raw = T))
  #print(model)
  regFn = predict(model, data.frame(MB))
  #print(regFn)
  regDr = numericDeriv(quote(predict(model, data.frame(MB))), theta = "MB") # data.frame composed of regression function and its derivative values
  regDr = attr(regDr, "gradient") # aceess derivative values presented on the diagonal of attr object
  regDr = diag(regDr)
  regDr = as.numeric(regDr)
  
  # plot(MB, regDr, type = "l", col = "blue")
  # regFn[regFn < 0 ] = 0
  # regDr[regDr < 0 ] = 0
  
  # plot(MB, regDr, type="l", col="red")
  
  RR_object = data.frame(regFn, regDr) # data.frame composed of regression function and its derivative values
  
  return(RR_object)
}

#### estimate recomb ####
#Function from BREC with span 
estimate_recombination_rates <- function(chromosome){
  
  spanval <- 0.15
  MB = chromosome$mb #physicalMap
  cM = chromosome$cm #geneticMap
  MB = as.numeric(MB)
  
  # 2nd option : regression function = Loess using 2nd degree polynomial
  model2 = loess(cM ~ MB, span = spanval, degree = 2)#, na.action = na.exclude
  regFn2 = predict(model2, MB)  ## needed only for plotting
  MBplus1 = MB+1
  MBminus1 = MB-1
  cMplus1 = predict(model2, MBplus1)
  cMplus1 = na.replace(cMplus1, max(cMplus1, na.rm = TRUE))
  cMminus1 = predict(model2, MBminus1)
  cMminus1 = na.replace(cMminus1, min(cMminus1, na.rm = TRUE))
  regDr2 <- mapply(function(x1, x2, y1, y2) {round((y2-y1)/(x2-x1 ), 2)}, MBminus1, MBplus1, cMminus1, cMplus1)
  regDr2[regDr2 < 0] = 0
  regFn = regFn2
  regDr = regDr2
  
  RR_object = data.frame(regFn, regDr) # data.frame composed of regression function and its derivative values
  
  return(RR_object)
}

#### compute r_sq ####
compute_cumulated_R_squared_2directions <- function(chromosome){ # it's not the R2 which is cumulated, instead, it's the data points used for the computation of R2
  
  chrData = data.frame(chrCm = chromosome$cm, chrPos = chromosome$mb)
  
  # R-sequared for the 1st direction : forward
  R2Vect_dir1 = c()
  for(i in 1:nrow(chrData)){
    localMB_dir1 = chrData$chrPos[1:i]
    localCM_dir1 = chrData$chrCm[1:i]
    
    # if(i <= 5){
    #     print(c("i = ", i))
    #     print(data.frame(localMB_dir1, localCM_dir1))
    # }
    
    if ((chrData$chrCm[i]!= 0) & (length(localMB_dir1) > 4)){ # less than 3 points doesn't give correct cubic polynomial
      # localPolynomial_dir1 = summary(lm(localCM_dir1 ~ poly(localMB_dir1, 3, raw = T)))
      # R2Vect_dir1 = c(R2Vect_dir1,localPolynomial_dir1$r.squared)
      
      localPolynomial_dir1 = rsq(glm(localCM_dir1 ~ poly(localMB_dir1, 3, raw = T)))
      # R2Vect_dir1 = c(R2Vect_dir1, localPolynomial_dir1)
      
      if(!is.na(localPolynomial_dir1) & !is.infinite(localPolynomial_dir1)){
        R2Vect_dir1 = c(R2Vect_dir1, localPolynomial_dir1)
      }else{
        localPolynomial_dir1 = 0.99
        R2Vect_dir1 = c(R2Vect_dir1, localPolynomial_dir1)
      }
    }else{
      localPolynomial_dir1 = 0.99
      R2Vect_dir1 = c(R2Vect_dir1, localPolynomial_dir1)
    }
  }
  
  # R-sequared for the 2nd direction : backwards
  R2Vect_dir2 = c()
  lastElemIndex = nrow(chrData)
  for(j in lastElemIndex:1){
    localMB_dir2 = chrData$chrPos[j:lastElemIndex]
    localCM_dir2 = chrData$chrCm[j:lastElemIndex]
    
    # if(j >= lastElemIndex-5){
    #     print(c("j = ", j))
    #     print(data.frame(localMB_dir2, localCM_dir2))
    #     print(glm(localCM_dir2 ~ poly(localMB_dir2, 3, raw = T)))
    #     print(lm(localCM_dir2 ~ poly(localMB_dir2, 3, raw = T)))
    # }
    
    if ((chrData$chrCm[j]!= 0) & (length(localMB_dir2) > 4)){
      localPolynomial_dir2 = rsq(glm(localCM_dir2 ~ poly(localMB_dir2, 3, raw = T)))
      
      if(!is.na(localPolynomial_dir2) & !is.infinite(localPolynomial_dir2)){
        R2Vect_dir2 = c(localPolynomial_dir2, R2Vect_dir2)
      }else{
        localPolynomial_dir2 = 0.99
        R2Vect_dir2 = c(localPolynomial_dir2, R2Vect_dir2)
        # print("dir 2 --> 0.99 returned from 1st else -> if(!is.na(localPolynomial_dir2))")
      }
    }else{
      localPolynomial_dir2 = 0.99
      R2Vect_dir2 = c(localPolynomial_dir2, R2Vect_dir2)
      # print("dir 2 --> 0.99 returned from 2nd else ->  if ((chrData$chrCm[j]!= 0) & (length(localMB_dir2) > 3))")
    }
    if(j >= lastElemIndex-5){
      #print(data.frame(R2Vect_dir2))
    }
  }
  
  # print(R2Vect_dir1)
  # print(R2Vect_dir2)
  R2DataFrame2D = data.frame(R2Vect_dir1, R2Vect_dir2)
  
  return(R2DataFrame2D)
}

#### compute sliding window ####
compute_sliding_window_size <- function(chromosome){ # needed for extract_CB
  
  ecartsVector = c()
  for(k in 1:(nrow(chromosome)-1)){
    # print("k compute swsz")
    # print(k)
    # print(chromosome$mb[k+1])
    # print( chromosome$mb[k])
    # print(chromosome$mb[k+1] - chromosome$mb[k])
    ecartsVector = c(ecartsVector, chromosome$mb[k+1] - chromosome$mb[k])
  }
  # hist(ecartsVector)
  # print("from compute swsize : ecartsVector")
  # print(ecartsVector)
  maxEcarts = max(ecartsVector) # represents a chromosome-specefic sliding window size computed automatically
  return(maxEcarts)
}

#### extract chromatin ####
extract_CB <- function(chromosome, RR_object, R2DataFrame2D){
  # Remember : left corresponds to dirction 1 and right to direction 2
  chrType <- get_chromosome_type(chromosome)
  if(chrType == 1){   #whole chromosome : works on metacentric chromosomes ===========================================
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)
    
    # print(c("indexOfMinRR", indexOfMinRR))
    # get rn and ln the right and left neighbours of the central point which is the phy-pos of the minimum RR : mb(minRR)
    centralPt = chromosome$mb[indexOfMinRR]
    # print(centralPt)
    if(!is.na(chromosome$mb[indexOfMinRR+1])){
      rn = chromosome$mb[indexOfMinRR+1]
    }else{
      rn = centralPt
    }
    # print(rn)
    
    if(indexOfMinRR != 1){
      if(!is.na(chromosome$mb[indexOfMinRR-1])){
        ln = chromosome$mb[indexOfMinRR-1]
      }
    }else{
      ln = centralPt
    }
    # print(ln)
    ecartRnLn = abs(rn-ln)
    # cat("ecartRnLn", ecartRnLn, sep = " = ")
    # ecartRnLn = max(abs(centralPt-rn), abs(centralPt-ln))
    ecartsPhysVector = c()
    for(k in 2:(nrow(chromosome))){
      ecartsPhysVector = c(ecartsPhysVector, chromosome$mb[k] - chromosome$mb[k-1])
    }
    # print(ecartsPhysVector)
    b = boxplot.stats(ecartsPhysVector)
    # print(b)
    # boxplot(ecartsPhysVector)
    seuilMaxMoustache = b$stats[5] # in case of boxplot -> b$stats[5, ] because it's a matrix
    # cat("seuilMaxMoustache", seuilMaxMoustache, sep = " = ")
    
    # print("#############################################################")
    # print(paste("number of markers", nrow(chromosome)))
    # print(paste("markers density", nrow(chromosome)/ chromosome$mb[nrow(chromosome)]))
    # print(paste("ecartRnLn", ecartRnLn  ))
    # print(paste("seuilMaxMoustache " ,seuilMaxMoustache, "seuilMaxMoustache * 2 ", seuilMaxMoustache*2))
    # print(paste("ecartRnLn <= seuilMaxMoustache*2", ecartRnLn <= seuilMaxMoustache*2))
    #
    # print("#############################################################")
    
    
    if(ecartRnLn <= seuilMaxMoustache*2){
      cat("  Metacentric\n") # chromosome: extract_CB_with_no_centromeric_gap...\n")
      heteroChromatinBoundaries = extract_CB_with_no_centromeric_gap(chromosome, RR_object, R2DataFrame2D, chrType)
    }else{
      cat("  Metacentric\n") # chromosome: extract_CB_with_centromeric_gap...\n")
      heteroChromatinBoundaries = extract_CB_with_centromeric_gap(chromosome, RR_object, R2DataFrame2D, chrType)
    }
  }else if(chrType == 0){  #chromosomal arm : works on telocentric chromosomes =====================================================================
    cat("  Telocentric\n") #chromosome: extract_CB_with_no_centromeric_gap by default...\n")
    heteroChromatinBoundaries = extract_CB_with_no_centromeric_gap(chromosome, RR_object, R2DataFrame2D, chrType)
  } else if (chrType == 2){
    cat("  Unknown-centric\n")
    heteroChromatinBoundaries <- data.frame(heteroBoundLeft = NA, indexHBleft = NA, heteroBoundRight = NA, indexHBright = NA, swSize = NA)
  }
  
  return(heteroChromatinBoundaries)
}


#### with centromeric gap ####
#' extract chromatin boundaries when a chromosome has a centromeric gap
extract_CB_with_centromeric_gap <- function(chromosome, RR_object, R2DataFrame2D, chrType){
  # Remember : left corresponds to dirction 1 and right to direction 2
  
  if(chrType == 1){   #whole chromosome : works on metacentric chromosomes =======================================================================================
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)
    
    swStart1 = chromosome$mb[indexOfMinRR]
    swStart2 = chromosome$mb[indexOfMinRR]
    swSize = compute_sliding_window_size(chromosome)
    
    heteroBoundRight = chromosome$mb[indexOfMinRR]
    heteroBoundLeft = chromosome$mb[indexOfMinRR]
    
    #-- left boundary (red)
    found1 = FALSE
    indexOfswEnd1 = indexOfMinRR
    while(!found1 & indexOfswEnd1>1){
      swEnd1 = swStart1-swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest using the next line
      indexOfswEnd1 = which.min(abs(chromosome$mb-swEnd1))
      indexOfswStart1 = which.min(abs(chromosome$mb-swStart1)) # we also use this formula because its value will be updated with the value of indexOfswEnd1 which does not necessarly belong to chromosme$mb
      r2 = R2DataFrame2D$R2Vect_dir1[indexOfswEnd1 : indexOfswStart1] # vector of r2 values according to the sliding window elements
      mb = chromosome$mb[indexOfswEnd1 : indexOfswStart1]
      sw1 = data.frame(r2, mb)
      if(nrow(sw1)> 1){ # do this only if there are at least 2 points
        growthRates1 = c()
        for(k in 1:(nrow(sw1)-1)){ # for all points included in current sliding window (sw)
          if((sw1$mb[k+1]-sw1$mb[k]) != 0){
            growthRates1 = c(growthRates1, (sw1$r2[k+1]-sw1$r2[k]) / (sw1$mb[k+1]-sw1$mb[k]))
          }
        }
        meanGrowthRate1 = mean(growthRates1)
        # print(c("extract_CB_with_centromeric_gap - chrType meta - just before if(meanGrowthRate1 > 0) => meanGrowthRate1 =", meanGrowthRate1))
        if(meanGrowthRate1 > 0){ # the window stops here / now
          # IndexOfHeteroBoundLeft = indexOfswStart1  #max of this sw pts
          heteroBoundLeft = chromosome$mb[indexOfswEnd1] # initial value
          cummulatedSloaps1 = c()
          for(i in (2:nrow(sw1))){ # compute all sloaps corresponding to each 2 points
            if((sw1$mb[i]-sw1$mb[i-1]) != 0){
              cummulatedSloaps1 = c(cummulatedSloaps1, (sw1$r2[i]-sw1$r2[i-1]) / (sw1$mb[i]-sw1$mb[i-1]))
            }
          }
          j = length(cummulatedSloaps1)-1
          while(!found1 & j>0){
            localMean1 = mean(cummulatedSloaps1[1:j])
            if(localMean1 > 0 | j==1){
              heteroBoundLeft = sw1$mb[j]  # get the index here n not the mb value
              found1 = TRUE
            }
            j=j-1
          }
        }else{
          swStart1 = swEnd1
        }
      }else{
        swStart1 = swEnd1
      }
    }
    # right boundary (purple)____________________
    found2 = FALSE
    indexOfswEnd2 = indexOfMinRR
    while(!found2 & indexOfswEnd2<nrow(R2DataFrame2D)){
      swEnd2 = swStart2+swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest
      indexOfswStart2 = which.min(abs(chromosome$mb-swStart2))
      indexOfswEnd2 = which.min(abs(chromosome$mb-swEnd2))
      r2 = R2DataFrame2D$R2Vect_dir2[indexOfswStart2 : indexOfswEnd2]
      mb = chromosome$mb[indexOfswStart2 : indexOfswEnd2]
      sw2 = data.frame(r2, mb)
      if (nrow(sw2)> 1){
        growthRates2 = c()
        for(m in 1:(nrow(sw2)-1)){ # for all points included in current sliding window (sw)
          if((sw2$mb[m+1]-sw2$mb[m]) != 0){
            growthRates2 = c(growthRates2, (sw2$r2[m+1]-sw2$r2[m]) / (sw2$mb[m+1]-sw2$mb[m]))
          }
        }
        meanGrowthRate2 = mean(growthRates2)
        # print(c("extract_CB_with_centromeric_gap - chrType meta - just before if(meanGrowthRate2 > 0) => meanGrowthRate2 =", meanGrowthRate2))
        if(meanGrowthRate2 < 0){
          # IndexOfHeteroBoundRight = indexOfswStart2 #max of this sw pts
          heteroBoundRight = chromosome$mb[indexOfswEnd2] # initial value
          cummulatedSloaps2 = c()
          for(i in (2:nrow(sw2))){ # compute all sloaps corresponding to each consecutive 2 points
            if((sw2$mb[i]-sw2$mb[i-1]) != 0){
              cummulatedSloaps2 = c(cummulatedSloaps2, (sw2$r2[i]-sw2$r2[i-1]) / (sw2$mb[i]-sw2$mb[i-1]))
            }
          }
          j = length(cummulatedSloaps2)-1
          while(!found2 & j>0){
            localMean2 = mean(cummulatedSloaps2[1:j])
            if(localMean2 > 0 | j==1){
              heteroBoundRight = sw2$mb[j]  # get the index here n not the mb value
              found2 = TRUE
            }
            j = j-1
          }
        }else{
          swStart2 = swEnd2
        }
      }else{
        swStart2 = swEnd2
      }
    }
    
    indexHBleft = match(heteroBoundLeft  , chromosome$mb)
    indexHBright = match(heteroBoundRight  , chromosome$mb)
    
  }else{ #chromosomal arm : works on telocentric chromosomes =================================================================================
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)
    
    IndexOfHeteroBound = indexOfMinRR
    swStart = chromosome$mb[indexOfMinRR]
    swSize = compute_sliding_window_size(chromosome)
    found = FALSE
    indexOfswEnd = IndexOfHeteroBound
    while(!found & indexOfswEnd>1){
      swEnd = swStart-swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest using the next line
      indexOfswEnd = which.min(abs(chromosome$mb-swEnd))
      indexOfswStart = which.min(abs(chromosome$mb-swStart)) # we also use this formula because its value will be updated with the value of indexOfswEnd1 which does not necessarly belong to chromosme$mb
      r2 = R2DataFrame2D$R2Vect_dir2[indexOfswEnd : indexOfswStart]
      mb = chromosome$mb[indexOfswEnd : indexOfswStart]
      sw = data.frame(r2, mb)
      if(nrow(sw)> 1){ # do this only if there are at least 2 points
        growthRates = c()
        for(k in 1:(nrow(sw)-1)){ # for all points included in current sliding window (sw)
          if((sw$mb[k+1]-sw$mb[k]) != 0){
            growthRates = c(growthRates, (sw$r2[k+1]-sw$r2[k]) / (sw$mb[k+1]-sw$mb[k]))
          }
        }
        meanGrowthRate = mean(growthRates)
        # print(c("extract_CB_with_centromeric_gap - chrType telo - just before if(meanGrowthRate > 0) => meanGrowthRate =", meanGrowthRate))
        if(meanGrowthRate > 0){
          # IndexOfHeteroBound = indexOfswStart  #max of this sw pts
          heteroBoundRight = chromosome$mb[indexOfswEnd]  # initial value
          i = nrow(sw)
          while(!found & i>1){
            if((sw$mb[i]-sw$mb[i-1]) != 0){
              a = (sw$r2[i]-sw$r2[i-1]) / (sw$mb[i]-sw$mb[i-1])
              if(a <= 0){  # ------------------------------------------------------  <= ??
                heteroBoundRight = sw$mb[i]  # get the index here n not the mb value
                found = TRUE
              }
            }
            i=i-1
          }
        }else{
          swStart = swEnd
        }
      }else{
        swStart = swEnd
      }
    }
    
    indexHBright = match(heteroBoundRight  , chromosome$mb)
    heteroBoundLeft = 0
    indexHBleft = 0
  }
  
  heteroChromatinBoundaries = data.frame( heteroBoundLeft, indexHBleft, heteroBoundRight, indexHBright, swSize)
  heteroChromatinBoundaries_to_print = data.frame( heteroBoundLeft, heteroBoundRight, swSize)
  # cat("\n")
  # print(heteroChromatinBoundaries_to_print)
  return(heteroChromatinBoundaries)
}

#### extract with no centromeric gap ####
# extract chromatin boundaries when a chromosome has no centromeric gap
extract_CB_with_no_centromeric_gap <- function(chromosome, RR_object, R2DataFrame2D, chrType){
  # Remember : left corresponds to dirction 1 and right to direction 2
  if(chrType == 1){   #whole chromosome : works on metacentric chromosomes =======================================================================================
    
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)
    
    # print(indexOfMinRR)
    swStart1 = chromosome$mb[indexOfMinRR]
    swStart2 = chromosome$mb[indexOfMinRR]
    # print("--1---swStart1 and swStart2")
    # print(swStart1)
    # print(swStart2)
    swSize = compute_sliding_window_size(chromosome)
    # print("swSize is ")
    # print(swSize)
    heteroBoundRight = chromosome$mb[indexOfMinRR]
    heteroBoundLeft = chromosome$mb[indexOfMinRR]
    # print(c("initial HCB ", heteroBoundRight, heteroBoundRight))
    
    #-- left boundary (red)________________________
    found1 = FALSE
    indexOfswEnd1 = indexOfMinRR
    while(!found1 & indexOfswEnd1>1){
      # --to do : sliding window size must be a percentage of chromosome's length
      swEnd1 = swStart1-swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest using the next line
      indexOfswEnd1 = which.min(abs(chromosome$mb-swEnd1))
      indexOfswStart1 = which.min(abs(chromosome$mb-swStart1)) # we also use this formula because its value will be updated with the value of indexOfswEnd1 which does not necessarly belong to chromosme$mb
      r2 = R2DataFrame2D$R2Vect_dir1[indexOfswEnd1 : indexOfswStart1] # vector of r2 values according to the sliding window elements
      mb = chromosome$mb[indexOfswEnd1 : indexOfswStart1]
      sw1 = data.frame(r2, mb)
      if(nrow(sw1)> 1){ # do this only if there are at least 2 points
        
        growthRates1 = c() # les pentes locales entre chaque 2 points consécutives
        for(k in 1:(nrow(sw1)-1)){ # for all points included in current sliding window (sw)
          if((sw1$mb[k+1]-sw1$mb[k]) != 0){
            growthRates1 = c(growthRates1, (sw1$r2[k+1]-sw1$r2[k]) / (sw1$mb[k+1]-sw1$mb[k]))
            # print("from if")
          }
          # print("k")
          # print(k)
        }
        meanGrowthRate1 = mean(growthRates1)
        # print(c("extract_CB_with_no_centromeric_gap - chrType meta - just before if(meanGrowthRate1 > 0) => meanGrowthRate1 =", meanGrowthRate1))
        # print("meanGrowthRate1")
        # print(meanGrowthRate1)
        if(meanGrowthRate1 > 0){ # the window stops here / now
          # IndexOfHeteroBoundLeft = indexOfswStart1  #max of this sw pts
          heteroBoundLeft = chromosome$mb[indexOfswEnd1]
          found1 = TRUE
        }else{
          swStart1 = swEnd1
          # print("from else1")
        }
      }else{
        swStart1 = swEnd1
        # print("from else2")
      }
      # print("--2--swStart1 and swStart2")
      # print(swStart1)
      # print(swStart2)
    }
    indexHBleft = indexOfswEnd1
    # print(indexHBleft)
    # right boundary (purple)________________________
    found2 = FALSE
    indexOfswEnd2 = indexOfMinRR
    while(!found2 & indexOfswEnd2<nrow(R2DataFrame2D)){
      swEnd2 = swStart2+swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest
      indexOfswStart2 = which.min(abs(chromosome$mb-swStart2))
      indexOfswEnd2 = which.min(abs(chromosome$mb-swEnd2))
      r2 = R2DataFrame2D$R2Vect_dir2[indexOfswStart2 : indexOfswEnd2]
      mb = chromosome$mb[indexOfswStart2 : indexOfswEnd2]
      sw2 = data.frame(r2, mb)
      if (nrow(sw2)> 1){
        growthRates2 = c()
        for(m in 1:(nrow(sw2)-1)){ # for all points included in current sliding window (sw)
          if((sw2$mb[m+1]-sw2$mb[m]) != 0){
            growthRates2 = c(growthRates2, (sw2$r2[m+1]-sw2$r2[m]) / (sw2$mb[m+1]-sw2$mb[m]))
          }
        }
        meanGrowthRate2 = mean(growthRates2)
        # print(c("extract_CB_with_no_centromeric_gap - chrType meta - just before if(meanGrowthRate2 > 0) => meanGrowthRate2 =", meanGrowthRate2))
        if(meanGrowthRate2 < 0){
          # IndexOfHeteroBoundRight = indexOfswStart2 #max of this sw pts
          heteroBoundRight = chromosome$mb[indexOfswEnd2]
          found2 = TRUE
        }else{
          swStart2 = swEnd2
        }
      }else{
        swStart2 = swEnd2
      }
    }
    indexHBright = indexOfswEnd2
    # print(indexHBright)
    
    heteroChromatinBoundaries = data.frame(heteroBoundLeft, indexHBleft, heteroBoundRight, indexHBright, swSize) ## final result to return
    #heteroChromatinBoundaries_to_print = data.frame( heteroBoundLeft, heteroBoundRight, swSize)
    
  }else{  #chromosomal arm : works on telocentric chromosomes =================================================================================
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)
    
    IndexOfHeteroBound = indexOfMinRR
    swStart = chromosome$mb[indexOfMinRR]
    swSize = compute_sliding_window_size(chromosome)
    found = FALSE
    indexOfswEnd = IndexOfHeteroBound
    # print(c("minRR = ", minRR, "indexOfMinRR = ", indexOfMinRR,  "indexOfswEnd = ", indexOfswEnd))
    
    if(indexOfMinRR == nrow(chromosome)){ # this is a left ahromosomal arm (exp : 2L) => left boundary (red)
      while(!found & indexOfswEnd >= nrow(chromosome)/2){  ## before was & indexOfswEnd>1
        swEnd = swStart-swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest using the next line
        indexOfswEnd = which.min(abs(chromosome$mb-swEnd))
        indexOfswStart = which.min(abs(chromosome$mb-swStart)) # we also use this formula because its value will be updated with the value of indexOfswEnd1 which does not necessarly belong to chromosme$mb
        r2 = R2DataFrame2D$R2Vect_dir2[indexOfswEnd : indexOfswStart]
        mb = chromosome$mb[indexOfswEnd : indexOfswStart]
        sw = data.frame(r2, mb)
        if(nrow(sw)> 1){ # do this only if there are at least 2 points
          growthRates = c()
          for(k in 1:(nrow(sw)-1)){ # for all points included in current sliding window (sw)
            if((sw$mb[k+1]-sw$mb[k]) != 0){
              growthRates = c(growthRates, (sw$r2[k+1]-sw$r2[k]) / (sw$mb[k+1]-sw$mb[k]))
            }
          }
          meanGrowthRate = mean(growthRates)
          # print(c("extract_CB_with_no_centromeric_gap -left arm - just before if(meanGrowthRate > 0)", meanGrowthRate))
          if(meanGrowthRate > 0){
            # IndexOfHeteroBound = indexOfswStart  #max of this sw pts
            heteroBoundLeft = chromosome$mb[indexOfswEnd]  # initial value
            i = nrow(sw)
            while(!found & i>1){
              if((sw$mb[i]-sw$mb[i-1]) != 0){
                a = (sw$r2[i]-sw$r2[i-1]) / (sw$mb[i]-sw$mb[i-1])
                if(a > 0){
                  heteroBoundLeft = sw$mb[i]  # get the index here n not the mb value
                  found = TRUE
                }
              }
              i=i-1
            }
          }else{
            swStart = swEnd
            #print(c("from 1st else : swStart = swEnd ", swStart))
          }
        }else{
          swStart = swEnd
          #print(c("from 2nd else : swStart = swEnd", swStart))
        }
      }
      if(found){
        indexHBleft = match(heteroBoundLeft, chromosome$mb)
        heteroBoundArm = heteroBoundLeft
        indexHBArm = indexHBleft
      }else{ #  (nrow(chromosome)/2 is reached while !found)
        heteroBoundArm = 'na'
        indexHBArm = 'na'
      }
      
    }else if(indexOfMinRR == 1){ # this is a right chromosomal arm (exp : 2R) => right boundary (purple)
      while(!found & indexOfswEnd <= nrow(chromosome)/2){
        swEnd = swStart+swSize # unit here is Mb .. this value may not belong to chromosome$mb, so we find the closest using the next line
        # print(c("swEnd = swStart+swSize", swEnd, swStart, swSize))
        indexOfswEnd = which.min(abs(chromosome$mb-swEnd))
        indexOfswStart = which.min(abs(chromosome$mb-swStart)) # we also use this formula because its value will be updated with the value of indexOfswEnd1 which does not necessarly belong to chromosme$mb
        # print(c("indexOfswEnd = ", indexOfswEnd, "indexOfswStart = ", indexOfswStart))
        r2 = R2DataFrame2D$R2Vect_dir1[indexOfswStart : indexOfswEnd]
        mb = chromosome$mb[indexOfswStart : indexOfswEnd]
        sw = data.frame(r2, mb)
        if(nrow(sw)> 1){ # do this only if there are at least 2 points
          growthRates = c()
          for(k in 1:(nrow(sw)-1)){ # for all points included in current sliding window (sw)
            if((sw$mb[k+1]-sw$mb[k]) != 0){
              growthRates = c(growthRates, (sw$r2[k+1]-sw$r2[k]) / (sw$mb[k+1]-sw$mb[k]))
            }
          }
          meanGrowthRate = mean(growthRates)
          # print("extract_CB_with_no_centromeric_gap -right arm - just before if(meanGrowthRate > 0)")
          # print(meanGrowthRate)
          if(meanGrowthRate > 0){
            # IndexOfHeteroBound = indexOfswStart  #max of this sw pts
            heteroBoundRight = chromosome$mb[indexOfswEnd]  # initial value
            i = nrow(sw)
            while(!found & i>1){
              if((sw$mb[i]-sw$mb[i-1]) != 0){
                a = (sw$r2[i]-sw$r2[i-1]) / (sw$mb[i]-sw$mb[i-1])
                if(a > 0){ #--------------------it was strictly < then it wouldn't work for chr X R6 so I changed it to <= so it worked but needs to be verified with all other chrms and versions
                  heteroBoundRight = sw$mb[i]  # get the index here n not the mb value
                  found = TRUE
                }
              }
              i=i-1
            }
          }else{
            swStart = swEnd
          }
        }else{
          swStart = swEnd
        }
      }
      if(found){
        indexHBright = match(heteroBoundRight, chromosome$mb)
        heteroBoundArm = heteroBoundRight
        indexHBArm = indexHBright
      }else{ #  (nrow(chromosome)/2 is reached while !found)
        heteroBoundArm = NA
        indexHBArm = NA
      }
    }else{ # (indexOfMinRR != 1 and != nrow(chromosome) )
      heteroBoundArm = NA
      indexHBArm = NA
    }
    
    heteroChromatinBoundaries = data.frame(heteroBoundLeft = NA, indexHBleft = NA, heteroBoundRight = heteroBoundArm, indexHBright = indexHBArm, swSize)
    #heteroChromatinBoundaries = data.frame(heteroBoundArm, indexHBArm, swSize) ## final result to return
    #heteroChromatinBoundaries_to_print = data.frame(heteroBoundArm, swSize)
  }
  
  #print(heteroChromatinBoundaries_to_print)
  
  return(heteroChromatinBoundaries)
}

#### extract telomeres ####
extract_telomeres_boundaries <- function(chromosome, RR_object, R2DataFrame2D){
  chrType <- get_chromosome_type(chromosome)
  if(chrType == 1){   #whole chromosome : works on metacentric chromosomes =================================================
    
    minR2_right = min(R2DataFrame2D$R2Vect_dir2)
    minR2_left = min(R2DataFrame2D$R2Vect_dir1)
    index_minR2_right = match(minR2_right, R2DataFrame2D$R2Vect_dir2)
    index_minR2_left = match(minR2_left, R2DataFrame2D$R2Vect_dir1)
    
    #___________# needed only for display!!
    telo_right = chromosome$mb[index_minR2_right]
    telo_left = chromosome$mb[index_minR2_left]
    # print(c("telo_left=", telo_left, "telo_right=", telo_right, "index_minR2_left=", index_minR2_left, "index_minR2_right=", index_minR2_right))
    telomeres_boundaries = data.frame(index_minR2_left, telo_left, index_minR2_right, telo_right)
    
  }else{  #chromosomal arm : works on telocentric chromosomes ===============================================================
    
    middleChr_pos = nrow(chromosome)/2
    
    minRR = min(RR_object$regDr)
    indexOfMinRR = match(minRR, RR_object$regDr)
    #minRR = minRR_object$minRRpoly # min(RR_vector)
    #indexOfMinRR = minRR_object$indexOfMinRRpoly # match(minRR, RR_vector)

    if(indexOfMinRR == nrow(chromosome)){ # this is a left chromosomal arm (exp : 2L) => left boundary (red)
      minR2_arm = min(R2DataFrame2D$R2Vect_dir1)
      index_minR2_arm = match(minR2_arm, R2DataFrame2D$R2Vect_dir1)
      if(index_minR2_arm > middleChr_pos){  #this is to solve the issue: minR2_arm happens to be on the centro side and not the telo => solved by finding the min in the right half of the arm
        minR2_arm = min(R2DataFrame2D$R2Vect_dir1[1:middleChr_pos])
        index_minR2_arm =  match(minR2_arm, R2DataFrame2D$R2Vect_dir1[1:middleChr_pos])
      }
    }else if(indexOfMinRR == 1){ # this is a right chromosomal arm (exp : 2R) => right boundary (purple)
      minR2_arm = min(R2DataFrame2D$R2Vect_dir2)
      index_minR2_arm = match(minR2_arm, R2DataFrame2D$R2Vect_dir2)
      if(index_minR2_arm < middleChr_pos){ #this is to solve the issue: minR2_arm happens to be on the centro side and not the telo => solved by finding the min in the right half of the arm
        minR2_arm = min(R2DataFrame2D$R2Vect_dir2[middleChr_pos:1])
        index_minR2_arm =  match(minR2_arm, R2DataFrame2D$R2Vect_dir2[middleChr_pos:1])
      }
    } else {
      return(data.frame(index_minR2_left = NA, telo_left = NA, index_minR2_right = NA, telo_right = NA))
    }
    telo_arm = chromosome$mb[index_minR2_arm]
    telomeres_boundaries = data.frame(index_minR2_left = NA, telo_left = NA, index_minR2_right = index_minR2_arm, telo_right = telo_arm)
    #telomeres_boundaries = data.frame(index_minR2_arm, telo_arm)
  }
  
  return(telomeres_boundaries)
}
