# Documentation for Bacillales Genomes Figures

This repository documents the commands and scripts used for producing the figures for the manuscript *Expanding the genome information on Bacillales for biosynthetic gene cluster discovery*. Specifically it shows how the *BGCFlow* output, included here in the folder [bgcflow_output](data/bgcflow_output/), was processed for generating figures, including the identification of plasmids for decorating the phylogenetic tree.

## Setting Up Your System for Replicating the Analysis

*__If you do not have Conda and Mamba installed:__ visit [Miniconda](https://docs.anaconda.com/free/miniconda/), download the latest Linux installer and install it with:*
~~~bash
bash Miniconda3-latest-Linux-x86_64.sh
conda activate
~~~
*Then use conda to install Mamba:*

~~~bash
conda install mamba -c conda-forge
~~~
*For more information on Mamba, visit [Mamba's GitHub page](https://github.com/mamba-org/mamba?tab=readme-ov-file).*
___

__To run the workflow, two conda environments need to be created and the genomes in FASTA and GenBank format needs to be downloaded. This section will show how to set up this repository on your own machine, including how to download the genomes.__

### Cloning this Repository

To begin, clone this repository to your machine. This will give you the necessary input data, scripts and environment packages for this part of the analysis. The following command will clone this repository to your current directory:

~~~bash
git clone https://github.com/ljdnielsen/bacillales_genomes_figures
~~~

Change to the directory:

~~~bash
cd bacillales_genomes_figures
~~~

### Creating the Necessary Conda Environments

#### bacillales-genomes-data Environment:

Create a conda environment for downloading and manipulating data called __bacillales-genomes-data__ by running these commands:

~~~bash
conda deactivate
conda create -n bacillales-genomes-data
conda activate bacillales-genomes-data
mamba install -c bioconda -c conda-forge ncbi-datasets-cli
mamba install biopython
mamba install tqdm
pip install csvkit
mamba install -c conda-forge jupyterlab
mamba install seaborn
mamba install colorcet
~~~

This environment contains the NCBI Datasets client for downloading genomes from NCBI, the CSV manipulation tool 'csvkit', and the python libraries 'BioPython' and 'tqdm' needed for the custom python script that extracts the contig topologies from genbank files.

#### bacillales-genomes-rfplasmid Environment:
To avoid conflicts with other programs, create a separate environment for RFPlasmid. Deactivate the current environment and create an environment called bacillales-genomes-rfplasmid using the YAML file 'src/env/rfplasmid.yml', and initialize rfplasmid:

~~~bash
conda deactivate
mamba env create -f src/env/rfplasmid.yml
conda activate bacillales-genomes-rfplasmid
rfplasmid --initialize
~~~

This environment contains RFPlasmid v.0.0.18 and all its dependencies.

### Download Genomes of BioProject PRJNA960711 (2.0GB)
For downloading the genomes, activate the bacillales-genomes-data environment:

~~~bash
conda deactivate
conda activate bacillales-genomes-data
~~~

Use the datasets command from the NCBI Datasets client to download the genomes with the following command:
~~~bash
mkdir data/genomes
datasets download genome accession PRJNA960711 --assembly-source GenBank --include gbff,genome --filename data/genomes/PRJNA960711.zip
~~~

Unzip the folder to the data/genomes directory.

~~~bash
unzip data/genomes/PRJNA960711.zip -d data/genomes/
~~~

Organize the downloaded fasta and genbank files in designated directories with the 'organize_genomes.sh' script which creates a fasta and genbank directory in the output directory, moves fasta and genbank files from the input directory to those directories, and renames the files according to their accession numbers.

~~~bash
bash src/shell/organize_genomes.sh data/genomes/ncbi_dataset data/genomes
~~~

Remove the ncbi_dataset folder, the .zip-folder, and the NCBI README file:

~~~bash
rm -r data/genomes/ncbi_dataset data/genomes/PRJNA960711.zip data/genomes/README.md
~~~

## Documentation

The following section documents the use of RFPlasmid for finding plasmids and the manipulation of *BGCFlow* output files for generating figures.

### Plasmid Identification for Decorating Phylogenetic Tree

*__Resource Requirements__: RFPlasmid (v.0.0.18) can be resource intensive. On a basic laptop with 20GB of RAM and 4 processors, processing a batch of three genomes took approximately 4 minutes and 5 seconds. Extrapolating this linearly suggests that processing 121 genomes would take around 2 hours and 41 minutes on a similar system.*

#### Running RFPlasmid:

To perform the preliminary plasmid prediction (excluding topology) for each contig of each genome, we executed RFPlasmid on the [data/genomes/fasta](data/genomes/fasta/) directory containing the 121 assembled genomes in FASTA format using the following command:

~~~bash
rfplasmid --species Bacillus --input data/genomes/fasta --out data/plasmids/rfplasmid
~~~

The resulting [prediction.csv](data/plasmids/rfplasmid/prediction.csv) file contains the prediction made by RFPlasmid for each contig of the analysed genomes.

#### Extracting Topology from Genbank Files:
*To run the following commands, deactivate the current environment and activate the environment bacillales-genomes-data*:

~~~bash
conda deactivate
conda activate bacillales-genomes-data
~~~

We then extracted the topology (linear or circular) of each contig from the corresponding genbank files using the python script [get_shape.py](../../src/python/get_shape.py):

~~~bash
python3 src/python/get_shape.py data/genomes/genbank data/plasmids/topology/topology.csv
~~~

This resulted in the [topology.csv](data/plasmids/topology/topology.csv) file that states for each contig if it is linear or circular.

#### Joining Contig Topology Value with RFPlasmid Prediction:
To identify plasmids based on the rfplasmid prediction and contig topology we combined the results of 'prediction.csv' and 'topology.csv'. This invovled two steps:

1. **First we added a key column to rfplasmid output**: A "Record ID" column was added to 'prediction.csv' from RFPlasmid using the following 'awk' command, which adds "Record ID" at the front of the header row ("NR == 1 {print "Record ID", $0}"), and splits the fifth column value to isolate the Record ID from the "Contig Description" column and prints it at the front of each line under the "Record ID" header ("NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print a[1],$0}") :
~~~bash
awk -F, 'BEGIN {OFS=","} NR == 1 {print "Record ID", $0} NR > 1 {split($5,a," "); gsub(/"/, "", a[1]); print a[1],$0}' data/plasmids/rfplasmid/prediction.csv > data/plasmids/rfplasmid/prediction_withkey.csv
~~~
Resulting in the [prediction_withkey.csv](data/plasmids/rfplasmid/prediction_withkey.csv) file.

2. **Then we joined prediction_withkey.csv and topology.csv:** The two CSV files were joined on the key column using the **'csvjoin'** command from the csvkit package:
~~~bash
csvjoin -c "Record ID" data/plasmids/topology/topology.csv data/plasmids/rfplasmid/prediction_withkey.csv > data/plasmids/plasmid_predictions.csv
~~~

This resulted in the file [plasmid_prediction.csv](data/plasmids/plasmid_predictions.csv). The contigs that were both circular and predicted to be plasmid as indicated in this table were summed up for each strain, and the numbers used to decorate the phylogenetic tree [final.newick](data/bgcflow_output/final.newick) using [iToL](https://itol.embl.de/), to produce the final tree figure.

### Boxplot of antiSMASH Regions per Genus

#### Concatenation of antiSMASH Region Counts and Taxonomic Classifications Tables:

To summarize the distributions of antiSMASH regions by genus, we first concatenated the columns "genus" from the BGCFlow output-file [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv) and "bgcs_count" from [df_antismash_7.0.0_summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv), using the accession numbers of the first columns as keys. This was done in three steps.

1. First, we extracted the key column and genus column from [gtdbtk.bac120.summary.tsv](data/bgcflow_output/gtdbtk.bac120.summary.tsv), excluding the header row and sorting the ouput using "sort", and saved it to the temporary table [id_genus.csv](data/bgcflow_output/temp/id_genus_sorted.csv) using the following command:

~~~bash
mkdir data/bgcflow_output/temp
awk -F'[;\t]' 'NR>1 {print $1","$7}' data/bgcflow_output/gtdbtk.bac120.summary.tsv | sort > data/bgcflow_output/temp/id_genus.csv
~~~
2. Then, we extracted the key column and "bgc_count" column and sorted the output of [df_antismash_7.0.0.summary.csv](data/bgcflow_output/df_antismash_7.0.0_summary.csv) using the command:
~~~bash
awk -F, 'NR>1 {print $1","$9}' data/bgcflow_output/df_antismash_7.0.0_summary.csv | sort > data/bgcflow_output/temp/id_bgccount.csv
~~~
3. Finally, the tables were joined in the table [genus_bgccount.csv](data/bgcflow_output/temp/genus_bgccount.csv) with the command:

~~~bash
join -t ',' -1 1 -2 1 data/bgcflow_output/temp/id_genus.csv data/bgcflow_output/temp/id_bgccount.csv > data/bgcflow_output/genus_bgccount.csv
~~~

The resulting table [genus_bgccount.csv](data/bgcflow_output/genus_bgccount.csv) states the genus and number of antiSMASH regions for each genome.

#### Visualization of Counts in Boxplot:

The boxplot showing the distributions of antiSMASH regions by genus was made using the Jupyter notebook [bgc_counts_figure.ipynb](src/notebooks/bgc_counts_figure.ipynb). Either open the file src/notebooks/bgc_counts_figure.ipynb in Visual Studio Code and choose the bacillales-genomes-data environment as the kernel environment, or if you are using another development environment, run 'jupyter lab' and navigate to the src/notebooks/bgc_counts_figure.ipynb from jupyter in the browser that will open:
~~~bash
mkdir -p results/figures
jupyter lab
~~~
From the notebook in jupyter lab, run the cells to produce the boxplot showing the distribution of antiSMASH-regions by genus.

## Re-running BGCFlow
We have provided the necessary `BGCFlow` output in the `data` folder. Only run this section if you wanted to reproduce the `BGCFlow` run, or wanted to update the analysis with the latest version of `antiSMASH` or `BGCFlow`.

### Setting Up BGCFlow
In this section, we will download and set up BGCFlow:

```bash
# Set up BGCFlow version
BGCFLOW_VERSION="v0.7.1"

# Define the directory name for the unzipped BGCFlow folder
BGCFLOW_DIR="bgcflow-${BGCFLOW_VERSION/v/}" # The 'v' in the version number is removed because the unzipped folder does not include it

# Download the zip file for the specified BGCFlow version from GitHub
wget https://github.com/NBChub/bgcflow/archive/refs/tags/$BGCFLOW_VERSION.zip

# Unzip the downloaded file
unzip $BGCFLOW_VERSION.zip

# Create a symbolic link to the config directory
(cd $BGCFLOW_DIR/ && ln -s ../config/ config)
```

### Running BGCFlow
Then, we can run the script belo to run BGCFlow on the data. The -n flag is used for a dry-run, which means the command will only print what it would do without actually executing it.
```bash
(cd $BGCFLOW_DIR/ && bgcflow run -n) # remove the -n (dry-run)
```
