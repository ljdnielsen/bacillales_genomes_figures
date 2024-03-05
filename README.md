# Bacillales Genomes Figures
This repository shows how we identified plasmids and used the outputs from BGCFlow to make the figures for the manuscript *121 de novo Assembled Bacillales Genomes with Varying Biosynthetic Potential*.
## Clone the Repository
To begin, clone this repository to your own machine. This will give you input data, scripts used, and environment packages allowing you to run the analysis. The following command will clone this repository to your current directory:
~~~bash
git clone https://github.com/ljdnielsen/bacillales_genomes_figures
~~~
change to the directory:
~~~bash
cd bacillales_genomes_figures
~~~

## Download Genomes
### Create Conda Environment for Data Manipulation
To avoid conflicts with other programs, create a conda environment for downloading and manipulating data called __bacillales-genomes-data__.
~~~bash
conda create -n bacillales-genomes-data
conda activate bacillales-genomes-data
mamba install -c bioconda -c conda-forge ncbi-datasets-cli
mamba install biopython
mamba install tqdm
pip install csvkit
~~~
### Download genomes of BioProject PRJNA960711 (2.0GB)
Use the datasets command to download the genomes with the following command:
~~~bash
datasets download genome accession PRJNA960711 --assembly-source GenBank --include gbff,genome --filename data/genomes/PRJNA960711.zip
~~~

Unzip the folder to the data/genomes directory.

~~~bash
unzip data/genomes/PRJNA960711.zip -d data/genomes/
~~~

Move .fna and .gbff files to a fasta and genbank directory respectively with the organize_genomes.sh script.

~~~bash
bash src/shell/organize_genomes.sh data/genomes/ncbi_dataset data/genomes
~~~

Remove .zip-folder, NCBI README and ncbi_dataset folder.

~~~bash
rm -r data/genomes/ncbi_datasets data/genomes/PRJNA960711.zip data/genomes/README.md
~~~

## Plasmid Identification
### Create Conda Environment for RFPlasmid
Deactivate the current environment and create a separate environment for rfplasmid called bacillales-genomes-rfplasmid using the YAML file __scr/env/rfplasmid.yml__, and initialize rfplasmid.
~~~bash
conda deactivate
mamba env create -f src/env/rfplasmid.yaml
conda activate bacillales-genomes-rfplasmid
rfplasmid --initialize
~~~
### Run RFPlasmid on FASTA Files

**Resource Requirements**: RFPlasmid (v.0.0.18) can be ressource intensive. On a basic laptop with 20GB of RAM and 4 processors, processing a batch of three genomes took approximately 4 minutes and 5 seconds. Extrapolating this linearly suggests that processing 121 genomes would take around 2 hours and 41 minutes on a similar system.
#### Executing RFPlasmid

To perform the preliminary plasmid prediction (excluding topology) for each contig of each genome, we executed RFPlasmid on the [data/genomes/fasta](data/genomes/fasta/) directory containing the 121 assembled genomes in FASTA format using the following command:

~~~bash
rfplasmid --species Bacillus --input data/genomes/fasta --out data/plasmids/rfplasmid
~~~

### Extract Topology from Genbank Files
We then extracted the topology (linear or circular) of each contig from the corresponding genbank files using the python script [get_shape.py](../../src/python/get_shape.py) and saved the result to [topology.csv](../../data/topology/topology.csv).

Deactivate the current environment and activate the environment bacillales-genomes-data:

~~~bash
conda deactivate
conda activate bacillales-genomes-data
~~~

#### Run get_shape.py to extract contig topologies
Contig topologies were extracted to a table by executing the custom python script get_shape.py with the following command:

~~~bash
mkdir -p data/plasmids/topology
python3 src/python/get_shape.py data/genomes/genbank data/plasmids/topology/topology.csv
~~~

### Join Contig Topology Value with RFPlasmid Prediction
To identify plasmids based on the rfplasmid prediction and contig topology we combined plasmid predictions of prediction.csv with the topologies of topology.csv. This invovled two steps:

1. **Added a key column to rfplasmid output**: A "Record ID" column was added to **'prediction.csv'** from RFPlasmid using the following '**awk**' command:
~~~bash
awk -F, 'BEGIN {OFS=","} NR == 1 {print "Record ID", $0} NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print a[1],$0}' data/plasmids/rfplasmid/prediction.csv > data/plasmids/rfplasmid/prediction_withkey.csv
~~~
For explanation of awk command see [^1].

2. **Joining prediction_withkey.csv and topology.csv:** The two CSV files were joined using the **'csvjoin'** command from the csvkit package:

Install csvkit in the current environment:
~~~bash
pip install csvkit
~~~
The files were merged with csvjoin using the following command:
~~~bash
csvjoin -c "Record ID" data/plasmids/topology/topology.csv data/plasmids/rfplasmid/prediction_withkey.csv > data/plasmids/plasmid_predictions.csv
~~~

The contigs in [plasmid_predictions.csv](data/plasmids/plasmid_predictions.csv) that were both circular and predicted to be plasmid by RFPlasmid were combined with the GTDB-Tk tree, final.newick, in [bgcflow_output](data/bgcflow_output/) for the decorated multi-locus tree figure.

## antiSMASH Regions per Genus

### Concatenation of antiSMASH Region Counts and Taxonomic Classifications
To summarize the distributions of antiSMASH regions by genus in our newly assembled genomes, we first concatenated the columns "genus" from the BGCFlow output-file [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv) and "bgcs_count" from [df_antismash_7.0.0_summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv), using the accession numbers of the first columns, called "user_genome" and "genome_id" respectively, as keys. This was done in three steps.

1. First, we extracted the key column and genus column from [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv), excluding the header row and sorting the ouput using "sort", and saved it to the temporary table [id_genus.csv](data/antismash_regions/id_genus_sorted.csv) using the following command:

~~~bash
awk -F'[;\t]' 'NR>1 {print $1","$7}' data/bgcflow_output/gtdbtk.bac120.summary.tsv | sort > data/bgcflow_output/temp/id_genus.csv
~~~
2. Then, we extracted the key column and "bgc_count" column and sorted the output of [df_antismash_7.0.0.summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv) using the command:
~~~bash
awk -F, 'NR>1 {print $1","$9}' data/bgcflow_output/df_antismash_7.0.0_summary.csv | sort > data/bgcflow_output/temp/id_bgccount.csv
~~~
3. Finally, the tables were joined in the table [genus_bgccount.csv](data/antismash_regions/genus_bgccount.csv) with the command:

~~~bash
join -t ',' -1 1 -2 1 data/bgcflow_output/temp/id_genus.csv data/bgcflow_output/temp/id_bgccount.csv > data/bgcflow_output/genus_bgccount.csv
~~~

### Visualization of Counts in Boxplot

The boxplot showing the distributions of antiSMASH regions by genus was made using the jupyter notebook [bgc_counts_figure.ipynb](src/notebooks/bgc_counts_figure.ipynb).


[^1]:'**NR == 1 {print $0, "Record ID"}'**: Adds a new header in the first line. 1 ("NR == 1"). **'NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print $0,a[1]}'**: Processes each line (excluding the first), extracts the first word from the 5th column, removes any double quotes, and appends it as a new column
