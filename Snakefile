dir = "/home/UTHSCSA/huelgasmoral/Documents"
SAMPLES= ["16B", "16T", "474B", "54B", "54T", "552B", '563B', "563T", "9B", "9T"]

rule bwa_mem:
    input:
        reads=["{dir}/WES/NGS-WES-BGI-Data-Nov2011/MZH11222_HUMkarX/{sample}/clean_data/{sample}.1.fq.gz",
        "{dir}/WES/NGS-WES-BGI-Data-Nov2011/MZH11222_HUMkarX/{sample}/clean_data/{sample}.2.fq.gz"],
    output:
        "{dir}/WES/Analysis/mapped/{sample}.bam",
    log:
        "{dir}/WES/Analysis/logs/bwa_mem/{sample}.log",
    params:
        index="{dir}/Reference/Homo_sapiens_assembly38.fasta",
        extra=r"-R '@RG\tID:{sample}\tSM:{sample}'",
        sorting="none",  # Can be 'none', 'samtools' or 'picard'.
        sort_order="queryname",  # Can be 'queryname' or 'coordinate'.
        sort_extra="",  # Extra args for samtools/picard.
        tmp_dir="/home/UTHSCSA/huelgasmoral/tmp",  # Path to temp dir. (optional)
    threads: 8
    wrapper:
        "0.80.2/bio/bwa/mem"


rule samtools_sort:
    input:
        "{dir}WES/Analysis/mapped/{sample}.bam"
    output:
        "{dir}WES/Analysis/mapped/{sample}.sorted.bam"
    params:
        extra = "-m 4G",
        tmp_dir = "/home/UTHSCSA/huelgasmoral/tmp"
    threads:  # Samtools takes additional threads through its option -@
        8     # This value - 1 will be sent to -@.
    wrapper:
        "0.80.2/bio/samtools/sort"

rule samtools_index:
    input:
        "{dir}WES/Analysis/mapped/{sample}.sorted.bam"
    output:
        "{dir}WES/Analysis/mapped/{sample}.sorted.bam.bai"
    #log:
    #    "logs/samtools_index/{sample}.log"
    params:
        "" # optional params string
    threads:  # Samtools takes additional threads through its option -@
        4     # This value - 1 will be sent to -@
    wrapper:
        "0.80.2/bio/samtools/index"


rule mark_duplicates:
    input:
        "{dir}WES/Analysis/mapped/{sample}.sorted.bam"
    # optional to specify a list of BAMs; this has the same effect
    # of marking duplicates on separate read groups for a sample
    # and then merging
    output:
        bam="{dir}WES/Analysis/dedup/{sample}.bam",
        metrics="{dir}WES/Analysis/dedup/{sample}.metrics.txt"
    log:
        "{dir}WES/Analysis/logs/picard/dedup/{sample}.log"
    #params:
    #    extra="REMOVE_DUPLICATES=true"
    # optional specification of memory usage of the JVM that snakemake will respect with global
    # resource restrictions (https://snakemake.readthedocs.io/en/latest/snakefiles/rules.html#resources)
    # and which can be used to request RAM during cluster job submission as `{resources.mem_mb}`:
    # https://snakemake.readthedocs.io/en/latest/executing/cluster.html#job-properties
    resources:
        mem_mb=1024
    wrapper:
        "0.80.2/bio/picard/markduplicates"

rule replace_rg:
    input:
        "{dir}WES/Analysis/dedup/{sample}.bam"
    output:
        "{dir}WES/Analysis/fixed-rg/{sample}.bam"
    log:
        "{dir}WES/Analysis/logs/picard/replace_rg/{sample}.log"
    params:
        "RGLB=lib1 RGPL=illumina RGPU={sample} RGSM={sample}"
    # optional specification of memory usage of the JVM that snakemake will respect with global
    # resource restrictions (https://snakemake.readthedocs.io/en/latest/snakefiles/rules.html#resources)
    # and which can be used to request RAM during cluster job submission as `{resources.mem_mb}`:
    # https://snakemake.readthedocs.io/en/latest/executing/cluster.html#job-properties
    resources:
        mem_mb=1024
    wrapper:
        "0.80.2/bio/picard/addorreplacereadgroups"


rule gatk_baserecalibrator:
    input:
        bam="{dir}WES/Analysis/fixed-rg/{sample}.bam",
        ref="{dir}Reference/Homo_sapiens_assembly38.fasta",
        dict="{dir}Reference/Homo_sapiens_assembly38.dict",
        known=["{dir}Reference/dpSNP/1000G_omni2.5.hg38.vcf.gz",
        "{dir}Reference/dpSNP/1000G_phase1.snps.high_confidence.hg38.vcf.gz",
        "{dir}Reference/dpSNP/Homo_sapiens_assembly38.dbsnp138.vcf",
        "{dir}Reference/dpSNP/Homo_sapiens_assembly38.known_indels.vcf.gz",
        "{dir}Reference/dpSNP/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"]  # optional known sites - single or a list
    output:
        recal_table="{dir}WES/Analysis/recal/{sample}.grp"
    log:
        "{dir}WES/Analysis/logs/gatk/baserecalibrator/{sample}.log"
    params:
        extra="",  # optional
        java_opts="", # optional
    # optional specification of memory usage of the JVM that snakemake will respect with global
    # resource restrictions (https://snakemake.readthedocs.io/en/latest/snakefiles/rules.html#resources)
    # and which can be used to request RAM during cluster job submission as `{resources.mem_mb}`:
    # https://snakemake.readthedocs.io/en/latest/executing/cluster.html#job-properties
    resources:
        mem_mb=1024
    wrapper:
        "0.80.2/bio/gatk/baserecalibrator"

rule gatk_applybqsr:
    input:
        bam="{dir}WES/Analysis/fixed-rg/{sample}.bam",
        ref="{dir}Reference/Homo_sapiens_assembly38.fasta",
        dict="{dir}Reference/Homo_sapiens_assembly38.dict",
        recal_table="{dir}WES/Analysis/recal/{sample}.grp"
    output:
        bam="{dir}WES/Analysis/recal/{sample}.bam"
    log:
        "{dir}WES/Analysis/logs/gatk/gatk_applybqsr/{sample}.log"
    params:
        extra="",  # optional
        java_opts="", # optional
    resources:
        mem_mb=1024
    wrapper:
        "0.80.2/bio/gatk/applybqsr"


rule haplotype_caller:
    input:
        # single or list of bam files
        bam="{dir}WES/Analysis/recal/{sample}.bam",
        ref="{dir}Reference/Homo_sapiens_assembly38.fasta"
        # known="dbsnp.vcf"  # optional
    output:
        gvcf="{dir}WES/Analysis/calls/{sample}.g.vcf",
#   bam="{sample}.assemb_haplo.bam",
    log:
        "{dir}WES/Analysis/logs/gatk/haplotypecaller/{sample}.log"
    params:
        extra="--tmp-dir /home/UTHSCSA/huelgasmoral/tmp",  # optional
        java_opts="", # optional
    resources:
        mem_mb=4000
    wrapper:
        "0.80.2/bio/gatk/haplotypecaller"
