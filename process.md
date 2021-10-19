*de novo* assembly and genome mapping
================

Part 1: [*de novo* assembly in
Stacks](https://github.com/therkildsen-lab/silverside-linkage-maps/blob/main/process.md#de-novo-assembly-in-stacks)  
Part 2: [Map to the reference
genome](https://github.com/therkildsen-lab/silverside-linkage-maps/blob/master/process.md#map-to-the-reference-genome)

## *de novo* assembly in Stacks

### Running the pipeline by hand

Because we have two F1 maps, we will manually run *Stacks* because we
want to have the same catalog loci in both maps to allow
cross-referencing of common loci between the maps. Thus, we will include
the four founding parents in *cstacks* to build the catalog, then match
the data with *sstacks* in three separate batches: once for each set of
parents and progeny for each F1 map, and once for the F2 map.

> See the [Stacks
> manual](https://catchenlab.life.illinois.edu/stacks/manual/#phand) for
> details on running the pipeline manually for more complex experimental
> designs.

### Build loci *de novo* with *ustacks*

> Fastq files for each individual are available for download under NCBI
> BioProject accession no. **PRJNA771889**

> Information for each family found in *input -&gt; popmaps*

Run *ustacks* on all samples with shell script `ustacks_wrap.sh`:  
<details>
<summary>
Show code
</summary>
<p>

``` bash
#!/bin/bash

src=/workdir/maria/ddrad/denovo

cd $src/processed
files=`ls -1 *.fq.gz | sed -E 's/\.fq\.gz$//'`
cd $src

# If using Cornell BioHPC cloud software
# must specify the library path and path to stacks:
export LD_LIBRARY_PATH=/usr/local/gcc-7.3.0/lib64:/usr/local/gcc-7.3.0/lib
export PATH=/programs/stacks-2.53/bin:$PATH

# Example command for running ustacks on each sample 
# Maximum distance [-M] of 4 allowed between stacks 
# Parallelized across 10 threads [-p]
##  ustacks -f ./processed/sample_01.fq.gz -o ./stacks -i 1 --name sample_01 -M 4 -p 10

id=1
for sample in $files
do
    ustacks -f $src/processed/${sample}.fq.gz -o $src/stacks -i $id --name $sample -M 4 -p 10
    let "id+=1"
done
```

</p>
</details>

Command: `nohup bash ustacks_wrap.sh &`

Note: *ustacks* is time-consuming. If you want to speed it up, run the
program in parallel – with each instance using 10 threads, or even
fewer. Instead of running one *ustacks* process with 40 threads, execute
it 5 times, with 8 threads each. If you use this approach, make sure to
edit the starting ID value in the bash script, as this assigns a unique
integer to each individual.

### Create Population Maps

With *cstacks*, we will build the catalog from only the parents in the
two reciprocal crosses. Then we run *sstacks*, *tsv2bam*, and *gstacks*
on all the samples, followed by *populations* once for each separate
cross.

Include **five** population maps, one with all samples, one for the
parents only, and one for each individual cross:  
<details>
<summary>
Show code
</summary>
<p>

``` r
# All individuals
popmap_all <- read_table2(file = "input/popmap_all", col_names = FALSE) 

# Founding parents
popmap_parent <- read_table2(file = "input/popmap_parents", col_names = FALSE) 

# PJ cross only with parents and offspring
popmap_PJ <- read_table2(file = "input/popmap_PJ", col_names = FALSE) 

# JP cross only with parents and offspring 
popmap_JP <- read_table2(file = "input/popmap_JP", col_names = FALSE) 

# F2 cross only with parents and offspring 
popmap_F2 <- read_table2(file = "input/popmap_F2", col_names = FALSE) 
```

</p>
</details>

### Assemble catalog with *cstacks*

Example command for building the catalog from only the parents in the
different crosses, with four mismatches \[-n\] allowed between sample
loci, parallelized across 25 threads \[-p\]:

`nohup cstacks -n 4 -P stacksid/ -M popmap/popmap_parents -p 25 &`

### Match to catalog with *sstacks*

Match all samples supplied in the population map against the catalog.

`nohup sstacks -P stacksid/ -M popmap/popmap_all -p 25 &`

### Run *tsv2bam*

Transpose the data so it is stored by locus, instead of by sample.

`nohup tsv2bam -P stacksid/ -M popmap/popmap_all -t 25 &`

### Run *gstacks*

Align reads per sample and call variant sites in the population and
genotypes in each individual.

`nohup gstacks -P stacksid/ -M popmap/popmap_all -t 25 &`

<details>
<summary>
gstacks results
</summary>
<p>

> Genotyped **236608** loci  
> Mean per-sample coverage: **19.1x**  
> stdev=4.1x, min=6.2x, max=31.2x

</p>
</details>

### Run *populations*

Generate genotypes with specified map type, and export mappable markers
in specified format, with the following data filtering parameters:

Filter data haplotype wise \[-H\] (unshared SNPs will be pruned to
reduce haplotype-wise missing data, including loci present in at least
80% of individuals in the cross).

Do this once for each separate cross:

`nohup populations -P stacksid/ -M popmap/popmap_PJ --out-path stacksid/cross_PJ -t 10 -H -r 0.8 --fasta-loci --vcf --map-type cp --map-format rqtl &`

<details>
<summary>
PJ cross results
</summary>
<p>

> Removed 180580 of 236608 loci. Kept 56028 loci with 64389 variant
> sites.  
> R/QTL marker export:  
> 26998 of 56028 loci were mappable (48.187%) for map type ‘CP’  
> 122.64 mean mappable progeny per locus (88.868%)

</p>
</details>

`nohup populations -P stacksid/ -M popmap/popmap_JP --out-path stacksid/cross_JP -t 10 -H -r 0.8 --fasta-loci --vcf --map-type cp --map-format rqtl &`

<details>
<summary>
JP cross results
</summary>
<p>

> Removed 181671 of 236608 loci. Kept 54937 loci with 60671 variant
> sites.  
> R/QTL marker export:  
> 25690 of 54937 loci were mappable (46.763%) for map type ‘CP’  
> 122.03 mean mappable progeny per locus (88.424%)

</p>
</details>

<br>

Use largest F2 family only (individuals in *popmap\_F2\_redo*)

`nohup populations -P stacksid/ -M popmap/popmap_F2_redo --out-path stacksid/cross_F2 -t 10 -H -r 0.8 --fasta-loci --vcf --map-type F2 --map-format rqtl &`

<details>
<summary>
F2 cross results
</summary>
<p>

> Removed 182082 of 236608 loci. Kept 54526 loci with 59926 variant
> sites.  
> R/QTL marker export:  
> 22477 of 54526 loci were mappable (41.223%) for map type ‘F2’  
> 254.42 mean mappable progeny per locus (88.34%)

</p>
</details>

## map to the reference genome

Map the catalog of RAD loci in the *gstacks* output file
**catalog.fa.gz** to the silverside reference genome.

> Genome assembly available in the Europen Nucleotide Archive under
> accession no. **GCA\_907169785.1**

Run *Bowtie2* to index the reference then map the RAD catalog to it,
piping to *Samtools* to generate a .BAM output:

`bowtie2-build menidia_menidia_tidy.filter1000.fasta --threads 15 meme`

`bowtie2 -f --very-sensitive -p 15 -x /workdir/maria/ddrad/denovo/reference/meme -U /workdir/maria/ddrad/denovo/stacksid/catalog.fa.gz | samtools view -bS - > catalog.bam`

### Generate table of coordinates for RAD loci mapped to genome

Use *Stacks* script *stacks\_integrate\_alignments* to integrate
alignments back into the *gstacks* files.

Download script, make it executable, then run it:  
`wget https://www.dropbox.com/s/h87079q4bt785pr/stacks-integrate-alignments`

`chmod ugo+x stacks-integrate-alignments`

`./scripts/stacks-integrate-alignments -P stacksid/ -B stacksid/catalog.bam -O integrated/`

The genome coordinates of the RAD loci in the catalog BAM file are
output into a table **locus\_coordinates.tsv**. This file includes the
marker IDs for RAD loci that mapped to the genome and their position.
Marker IDs are retained by the linkage mapping software, thus, the
genome coordinates for markers in the linkage map can later be extracted
from the **locus\_coordinates.tsv** table.

Note: If you want to conduct linkage mapping using only RAD loci that
mapped to the genome, you can re-run *populations* using the new catalog
with the integrated alignments.
