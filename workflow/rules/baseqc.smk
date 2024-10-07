rule download_sra:
    output:
        temp(directory("data/interim/sra/fastq_{strain}"))
    conda:
        "../envs/base_qc.yaml"
    params:
        ont = lambda wildcards: df.loc[wildcards.strain, "SRA accession of Nanopore"],
        dnb = lambda wildcards: df.loc[wildcards.strain, "SRA accession of DNBSEQ"],
        tmpdir = "data/interim/sra/tmp/"
    log:
        "logs/download_sra/fastq_{strain}_download_sra.log"
    resources:
        tmpdir="data/interim/sra/tmp/",
    threads: 2
    shell:
        """
        echo "Downloading SRA for {wildcards.strain}: {params.ont} {params.dnb}" > {log}
        mkdir -p {params.tmpdir}
        fasterq-dump {params.ont} {params.dnb} -O {output} --split-files --threads {threads} -t {params.tmpdir} -v 2>> {log}
        """

rule download_assembly:
    output:
        zip = temp("data/interim/assembly/{strain}.zip"),
        directory = directory("data/interim/assembly/{strain}")
    conda:
        "../envs/base_qc.yaml"
    log:
        "logs/download_assembly/{strain}_download_assembly.log"
    shell:
        """
        datasets download genome accession {wildcards.strain} --filename {output.zip} 2>> {log}
        unzip {output.zip} -d {output.directory} &>> {log}
        """

rule yak:
    input:
        fastq_dir = "data/interim/sra/fastq_{strain}",
        assembly_dir = "data/interim/assembly/{strain}"
    output:
        hist = "data/processed/yak/{strain}/sr.hist.txt",
        asm_sr_qv = "data/processed/yak/{strain}/asm-sr.qv.txt",
        asm_sr_kqv = "data/processed/yak/{strain}/sr-asm.kqv.txt",
        ont_sr_qv = "data/processed/yak/{strain}/ont-sr.qv.txt",
        ont_sr_kqv = "data/processed/yak/{strain}/ont-sr.kqv.txt"
    conda:
        "../envs/base_qc.yaml"
    log:
        "logs/yak/yak_{strain}.log"
    params:
        yak_dir = "data/interim/yak_b31/{strain}",
        kcount = "16",
        b = "31",
        kqv = "6m",
        lqv = "100k",
        ont = lambda wildcards: df.loc[wildcards.strain, "SRA accession of Nanopore"],
        dnb = lambda wildcards: df.loc[wildcards.strain, "SRA accession of DNBSEQ"],
    threads: 4
    shell:
        """
        #set -e
        # Create output directory if it doesn't exist
        mkdir -p $(dirname {output.hist})
        mkdir -p {params.yak_dir}

        # Build k-mer hash table for assembly; count singletons
        echo "Building k-mer hash table for assembly" > {log}
        yak count -K{params.kcount} -t {threads} -o {params.yak_dir}/asm.yak {input.assembly_dir}/ncbi_dataset/data/{wildcards.strain}/{wildcards.strain}*.fna 2>> {log}

        # build k-mer hash tables for high-coverage reads; discard singletons
        echo "\nBuilding k-mer hash table for high-coverage reads" >> {log}
        yak count -b{params.b} -t{threads} -o {params.yak_dir}/ont.yak {input.fastq_dir}/{params.ont}.fastq 2>> {log}

        # For paired end: to provide two identical streams
        echo "\nBuilding k-mer hash table for paired end reads" >> {log}
        yak count -b{params.b} -t {threads} -o {params.yak_dir}/sr.yak <(cat {input.fastq_dir}/*_*.fastq) <(cat {input.fastq_dir}/*_*.fastq) 2>> {log}

        # Compute assembly or reads QV
        echo "\nComputing assembly QV" >> {log}
        yak qv -t {threads} -p -K{params.kqv} -l{params.lqv} {params.yak_dir}/sr.yak {input.assembly_dir}/ncbi_dataset/data/{wildcards.strain}/{wildcards.strain}*.fna > {output.asm_sr_qv} 2>> {log}
        yak qv -t {threads} -p {params.yak_dir}/sr.yak {input.fastq_dir}/{params.ont}.fastq > {output.ont_sr_qv} 2>> {log}

        # Compute k-mer QV for reads
        echo "\nComputing k-mer QV for reads" >> {log}
        yak inspect {params.yak_dir}/ont.yak {params.yak_dir}/sr.yak > {output.ont_sr_kqv} 2>> {log}

        # Evaluate the completeness of assembly
        echo "\nEvaluating the completeness of assembly" >> {log}
        mkdir -p $(dirname {output.asm_sr_kqv})
        yak inspect {params.yak_dir}/sr.yak {params.yak_dir}/asm.yak > {output.asm_sr_kqv} 2>> {log}

        # Print k-mer histogram
        echo "\nPrinting k-mer histogram" >> {log}
        yak inspect {params.yak_dir}/sr.yak > {output.hist} 2>> {log}
        """

rule meryl:
    input:
        fastq_dir = "data/interim/sra/fastq_{strain}",
        assembly_dir = "data/interim/assembly/{strain}"
    output:
        meryl_db = directory("data/interim/meryl/{strain}"),
    conda:
        "../envs/base_qc.yaml"
    log:
        "logs/meryl/meryl_{strain}.log"
    params:
        kmer = "16",
        dnb = lambda wildcards: df.loc[wildcards.strain, "SRA_accession_of_DNBSEQ"],
        memory = "16"
    threads: 16
    shell:
        """
        # Create output directory if it doesn't exist
        mkdir -p {output.meryl_db}

        # Temporary file to store meryl database paths
        meryl_db_list=$(mktemp)

        # Check for DNBSEQ reads and process if present
        if [ -n "{params.dnb}" ]; then
            for read_file in {input.fastq_dir}/{params.dnb}*; do
                meryl count k={params.kmer} threads={threads} memory={params.memory} output {output.meryl_db}/$(basename $read_file .fq.gz).meryl $read_file 2>> {log}
                echo {output.meryl_db}/$(basename $read_file .fq.gz).meryl >> $meryl_db_list 2>> {log}
            done
        fi

        # Merge all meryl databases using union-sum if any databases were created
        if [ -s $meryl_db_list ]; then
            meryl union-sum output {output.meryl_db}/merged.meryl $(cat $meryl_db_list) 2>> {log}
        fi

        # Clean up temporary file
        rm -rf $(cat $meryl_db_list)
        rm $meryl_db_list
        """

rule merqury:
    input:
        meryl_db = "data/interim/meryl/{strain}",
        assembly_dir = "data/interim/assembly/{strain}"
    output:
        merqury = directory("data/processed/merqury/{strain}/merqury")
    conda:
        "../envs/base_qc.yaml"
    log:
        "logs/merqury/merqury_{strain}.log"
    threads: 16
    shell:
        """
        # Create output directory if it doesn't exist
        mkdir -p $(dirname {output.merqury})
        mkdir -p logs/{output.merqury}

        # Run merqury
        merqury.sh {input.meryl_db}/merged.meryl {input.assembly_dir}/ncbi_dataset/data/{wildcards.strain}/{wildcards.strain}*.fna {output.merqury} &>> {log}
        """
