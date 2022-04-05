library(tidyverse)

blast <- read_csv("~/Downloads/BLAST.csv")

blast <- read_csv("~/Downloads/10KW3UU8016-Alignment-Descriptions.csv")

myblast <- blast %>% mutate(source=case_when(
  str_detect(Description, "mRNA") ~ "mRNA", 
  str_detect(Description, "misc_RNA") ~ "mRNA",
  str_detect(Description, "genomic") ~ "genome assembly", 
  str_detect(Description, "genome") ~ "genome assembly", 
  str_detect(Description, "strain") ~ "genome assembly",
  str_detect(Description, "chromosome") ~ "genome assembly", 
  str_detect(Description, "genome assembly") ~ "genome assembly", 
  str_detect(Description, "complete") ~ "genome assembly", 
                 TRUE ~ "else"))


myblast2 <- myblast %>% 
  mutate(species=case_when(
    str_detect(`Common Name`, "fish") ~ "fish", 
    str_detect(`Scientific Name`, "Poecilia") ~ "fish",
    str_detect(`Scientific Name`, "Danio") ~ "fish",
    str_detect(`Common Name`, "capuchin") ~ "notfish",
    str_detect(`Common Name`, "whale") ~ "notfish",
    str_detect(`Common Name`, "bat") ~ "notfish",
    str_detect(`Common Name`, "nightjar") ~ "notfish",
    str_detect(`Common Name`, "mouse") ~ "notfish",
    str_detect(`Common Name`, "virus") ~ "notfish",
    str_detect(`Scientific Name`, "virus") ~ "notfish",
    str_detect(`Scientific Name`, "pneumoniae") ~ "notfish",
    str_detect(`Scientific Name`, "Siphoviridae") ~ "notfish",
    str_detect(`Scientific Name`, "primolecta") ~ "notfish",
    TRUE ~ "fish"))


myblast3 <- myblast2 %>% arrange(desc(`E value`),`Common Name`)

spcnt <- myblast2 %>% 
  group_by(species, source) %>% 
  summarise(min_E_value=min(`E value`),max_E_value=max(`E value`),
            min_perc_id=min(`Per. ident`),max_perc_id=max(`Per. ident`),sp_n=n())
a
write_csv(myblast3,"~/Desktop/newblast.csv")
