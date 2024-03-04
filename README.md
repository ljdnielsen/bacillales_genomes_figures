# Bacillales Genomes Figures
This repository shows how we made figures from the BGCFlow output-files to be used in the manuscript *121 de novo assembled Bacillales Genomes with varying biosynthetic potential*.

## antiSMASH Regions per Genus

### Concatenation of antiSMASH Region Counts and Taxonomic Classifications
To summarize the distributions of antiSMASH regions by genus in our newly assembled genomes, we first concatenated the columns "genus" from the BGCFlow output-file [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv) and "bgcs_count" from [df_antismash_7.0.0_summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv), using the accession numbers of the first columns, called "user_genome" and "genome_id" respectively, as keys. This was done in three steps.

First, we extracted the key column and genus column from [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv), excluding the header row and sorting the ouput using "sort", and saved it to the temporary table [id_genus.csv](data/processed/id_genus_sorted.csv) using the following command:
~~~bash
awk -F'[;\t]' 'NR>1 {print $1","$7}' data/bgcflow_output/gtdbtk.bac120.summary.tsv | sort > data/processed/id_genus.csv
~~~
Then, we extracted the key column and "bgc_count" column and sorted the output of [df_antismash_7.0.0.summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv) using the command:
~~~bash
awk -F, 'NR>1 {print $1","$9}' data/bgcflow_output/df_antismash_7.0.0_summary.csv | sort > data/processed/id_bgccount.csv
~~~
Finally, the tables were joined in the table [genus_bgccount.csv](data/processed/genus_bgccount.csv) with the command:

~~~bash
join -t ',' -1 1 -2 1 data/processed/id_genus.csv data/processed/id_bgccount.csv > data/processed/genus_bgccount.csv
~~~

### Visualization of Counts in Boxplot

The boxplot showing the distributions of antiSMASH regions by genus was made using the jupyter notebook [bgc_counts_figure.ipynb](src/notebooks/bgc_counts_figure.ipynb).

## Plasmid Identification
