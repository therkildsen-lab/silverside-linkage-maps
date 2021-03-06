linkage mapping
================

## Linkage Mapping with Lep-Map3 (LM3)

#### *ParentCall2* (LM3)

**JP cross**  
`java -cp /programs/Lep-MAP3/bin/ ParentCall2 data=JP_ped.txt vcfFile=JP.vcf >out_JP.linkage`

<details>
<summary>
informative markers
</summary>
<p>

> Number of individuals = 140  
> Number of families = 1  
> Number of called markers = 60671 (52772 informative)

</p>
</details>

<br>

**PJ cross**  
`java -cp /programs/Lep-MAP3/bin/ ParentCall2 data=PJ_ped.txt vcfFile=PJ.vcf >out_PJ.linkage`

<details>
<summary>
informative markers
</summary>
<p>

> Number of individuals = 140  
> Number of families = 1  
> Number of called markers = 64389 (55648 informative)

</p>
</details>

<br>

**F2 cross**  
`java -cp /programs/Lep-MAP3/bin/ ParentCall2 data=F2_ped.txt vcfFile=F2.vcf > out_F2.linkage`

#### *Filtering2* (LM3)

Do for multi-family map (F2) only.

`java -cp /programs/Lep-MAP3/bin/ Filtering2 data=out_F2.linkage >F2.all`

#### *SeparateChromosomes2* (LM3)

Test a range of LOD limits.

<details>
<summary>
Show code and results
</summary>
<p>

``` bash
for lod in $(seq 8 1 22)
do
  java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=out_JP.linkage sizeLimit=5000 numThreads=35 distortionLod=1 lodLimit=${lod} >/dev/null 2>>JP_lod.log
done


for lod in $(seq 8 1 22)
do
  java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=out_PJ.linkage sizeLimit=5000 numThreads=35 distortionLod=1 lodLimit=${lod} >/dev/null 2>>PJ_lod.log
done


for lod in $(seq 30 1 44)
do
  java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=F2.all sizeLimit=10000 numThreads=35 lodLimit=${lod} >/dev/null 2>>F2_lod.log
done
```

</p>
</details>

<br>

Look at marker assignment to LGs based on range of LOD limits.  
`grep "number " lod.log | awk -F ',' '{print $1}'`

<br>

**JP cross**  
LOD scores between 14 and 21 all resolve 24 chromosomes, with little
variation in marker distribution. Proceed with LOD limit of 14 to retain
the most markers as higher values lead to extra parsing of linkage
groups.  
`java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=out_JP.linkage distortionLod=1 sizeLimit=20 lodLimit=14 numThreads=15 >JPmap14.txt 2>JPmap14.log`

**PJ cross**  
LOD scores between 19 and 22 all resolve 24 chromosomes, with little
variation in marker distribution. Proceed with LOD limit of 19 to retain
the most markers as higher values lead to extra parsing of linkage
groups.  
`java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=out_PJ.linkage distortionLod=1 sizeLimit=20 lodLimit=19 numThreads=25 >PJmap19.txt 2>PJmap19.log`

**F2 cross**

> *Note*: Tested range of LOD scores only resolved 22 LGs (including two
> very large clumped LGs) with three families combined. Repeat to split
> largest LGs.

`java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=F2.all lodLimit=21 numThreads=15 sizeLimit=6 >F2_21.txt`

`java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=F2.all lodLimit=31 numThreads=15 map=F2_21.txt lg=1 sizeLimit=23 > F2_21_31.txt`

`java -cp /programs/Lep-MAP3/bin/ SeparateChromosomes2 data=F2.all lodLimit=29 numThreads=15 map=F2_21_31.txt lg=1 sizeLimit=11 > F2_21_31_29.txt`

`java -cp /programs/Lep-MAP3/bin/ JoinSingles2All map=F2_21_31_29.txt data=F2.all lodLimit=15 iterate=1 >newmap.txt`

#### *OrderMarkers2* (LM3)

Order markers within each LG using markers with informative mother.
<details>
<summary>
Show code
</summary>
<p>

``` bash
#Run OrderMarkers2
for chr in $(seq 1 1 24) 
do 
  java -cp /programs/Lep-MAP3/bin/ OrderMarkers2 data=out_JP.linkage map=JPmap14.txt chromosome=$chr numThreads=20 informativeMask=2 >LG$chr 2>order$chr.err
done

#Edit output to include marker info

cat out_JP.linkage|cut -f 1,2|awk '(NR>=7)' >snps.txt

for chr in $(seq 1 1 24) 
do
awk -vFS="\t" -vOFS="\t" '(NR==FNR){s[NR-1]=$0}(NR!=FNR){if ($1 in s) $1=s[$1];print}' snps.txt LG$chr >mLG$chr
done

#Combine linkage groups
awk 'NR > 3 {print FILENAME OFS $0}' mLG* | awk '{print $1,$2,$5}' > JP14_LGs.txt
```

</p>
</details>
