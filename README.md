# Bacillales Genomes Figures
This repository shows how we identified plasmids and used the outputs from BGCFlow to make the figures for the manuscript *121 de novo assembled Bacillales Genomes with Varying Biosynthetic Potential*.

## Plasmid Identification

### Install and Run RFPlasmid
We first installed RFPlasmid in a new conda environment using mamba:
~~~bash
conda create --name rfplasmid
conda activate rfplasmid
mamba install -c bioconda rfplasmid
~~~
We then executed RFPlasmid on the directory [data/genomes/fasta](data/genomes/fasta) containing the 121 assembled genomes in FASTA-format using the following command resulting in a preliminary prediction for each contig of each genome:
~~~bash
rfplasmid --species Bacillus --input data/genomes/fasta --out data/rfplasmid
~~~

### Extract Topology from Genbank Files
We then extracted the topology (linear or circular) of each contig from the corresponding genbank files using the python script [get_shape.py](../../src/python/get_shape.py) and saved the result to [topology.csv](../../data/topology/topology.csv):
~~~bash
python3 get_shape.py data/genomes/genbank data/topology/topology.csv
~~~

### Join Contig Topology Value with RFPlasmid Prediction
The process of joining the CSV files containing the topology and plasmid predictions involved two steps:

1. **Adding key column to rfplasmid output**: A "Record ID" column was added to the **'prediction.csv'** file. This was achieved by copying the accession number from the "contigID" column to a new "Record ID" column using the following '**awk**' command:
~~~bash
awk -F, 'BEGIN {OFS=","} NR == 1 {print $0, "Record ID"} NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print $0,a[1]}' prediction.csv > modified_output/prediction.csv
~~~
Explanation:
- '**NR == 1 {print $0, "Record ID"}'**: Adds a new header in the first line. 1 ("NR == 1")
- **'NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print $0,a[1]}'**: Processes each line (excluding the first), extracts the first word from the 5th column, removes any double quotes, and appends it as a new column

2. **Joining the RFPlasmid output CSV with the topology CSV:**: The two csv files were joined using **'csvjoin'** command from the csvkit package was used to merge the files. csvkit can be installed installed via **'pip'**:
~~~bash
pip install csvkit
~~~
Following installation, the files were merged using the command:
~~~bash
csvjoin -c "Record ID" topology_output.csv prediction.csv > combined.csv
~~~

## antiSMASH Regions per Genus

### Concatenation of antiSMASH Region Counts and Taxonomic Classifications
To summarize the distributions of antiSMASH regions by genus in our newly assembled genomes, we first concatenated the columns "genus" from the BGCFlow output-file [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv) and "bgcs_count" from [df_antismash_7.0.0_summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv), using the accession numbers of the first columns, called "user_genome" and "genome_id" respectively, as keys. This was done in three steps.

First, we extracted the key column and genus column from [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv), excluding the header row and sorting the ouput using "sort", and saved it to the temporary table [id_genus.csv](data/antismash_regions/id_genus_sorted.csv) using the following command:
~~~bash
awk -F'[;\t]' 'NR>1 {print $1","$7}' data/bgcflow_output/gtdbtk.bac120.summary.tsv | sort > data/antismash_regions/id_genus.csv
~~~
Then, we extracted the key column and "bgc_count" column and sorted the output of [df_antismash_7.0.0.summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv) using the command:
~~~bash
awk -F, 'NR>1 {print $1","$9}' data/bgcflow_output/df_antismash_7.0.0_summary.csv | sort > data/antismash_regions/id_bgccount.csv
~~~
Finally, the tables were joined in the table [genus_bgccount.csv](data/antismash_regions/genus_bgccount.csv) with the command:

~~~bash
join -t ',' -1 1 -2 1 data/antismash_regions/id_genus.csv data/antismash_regions/id_bgccount.csv > data/antismash_regions/genus_bgccount.csv
~~~

### Visualization of Counts in Boxplot

The boxplot showing the distributions of antiSMASH regions by genus was made using the jupyter notebook [bgc_counts_figure.ipynb](src/notebooks/bgc_counts_figure.ipynb).

